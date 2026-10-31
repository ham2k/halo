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
class TranslationsIt extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsIt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.it,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <it>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsIt _root = this; // ignore: unused_field

	@override 
	TranslationsIt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsIt(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$it common = _Translations$common$it._(_root);
	@override late final _Translations$onboarding$it onboarding = _Translations$onboarding$it._(_root);
	@override late final _Translations$startScreen$it startScreen = _Translations$startScreen$it._(_root);
	@override late final _Translations$testerOverlay$it testerOverlay = _Translations$testerOverlay$it._(_root);
	@override late final _Translations$extensionsPanel$it extensionsPanel = _Translations$extensionsPanel$it._(_root);
	@override late final _Translations$home$it home = _Translations$home$it._(_root);
	@override late final _Translations$chase$it chase = _Translations$chase$it._(_root);
	@override late final _Translations$dialogs$it dialogs = _Translations$dialogs$it._(_root);
	@override late final _Translations$operation$it operation = _Translations$operation$it._(_root);
	@override late final _Translations$map$it map = _Translations$map$it._(_root);
	@override late final _Translations$mapsView$it mapsView = _Translations$mapsView$it._(_root);
	@override late final _Translations$activitiesView$it activitiesView = _Translations$activitiesView$it._(_root);
	@override late final _Translations$loggingControls$it loggingControls = _Translations$loggingControls$it._(_root);
	@override late final _Translations$formChrome$it formChrome = _Translations$formChrome$it._(_root);
	@override late final _Translations$qsoEditForm$it qsoEditForm = _Translations$qsoEditForm$it._(_root);
	@override late final _Translations$qsoList$it qsoList = _Translations$qsoList$it._(_root);
	@override late final _Translations$loggingPanel$it loggingPanel = _Translations$loggingPanel$it._(_root);
	@override late final _Translations$callInfo$it callInfo = _Translations$callInfo$it._(_root);
	@override late final _Translations$settings$it settings = _Translations$settings$it._(_root);
	@override late final _Translations$commands$it commands = _Translations$commands$it._(_root);
	@override late final _Translations$commandDialog$it commandDialog = _Translations$commandDialog$it._(_root);
	@override late final _Translations$keyboardShortcuts$it keyboardShortcuts = _Translations$keyboardShortcuts$it._(_root);
	@override late final _Translations$expiredBuild$it expiredBuild = _Translations$expiredBuild$it._(_root);
	@override late final _Translations$staleness$it staleness = _Translations$staleness$it._(_root);
	@override late final _Translations$spotting$it spotting = _Translations$spotting$it._(_root);
	@override late final _Translations$dataFiles$it dataFiles = _Translations$dataFiles$it._(_root);
	@override late final _Translations$updates$it updates = _Translations$updates$it._(_root);
	@override late final _Translations$extensionService$it extensionService = _Translations$extensionService$it._(_root);
	@override late final _Translations$operationLocationScreen$it operationLocationScreen = _Translations$operationLocationScreen$it._(_root);
	@override late final _Translations$versionLabel$it versionLabel = _Translations$versionLabel$it._(_root);
	@override late final _Translations$notices$it notices = _Translations$notices$it._(_root);
	@override late final _Translations$syncAccount$it syncAccount = _Translations$syncAccount$it._(_root);
	@override late final _Translations$deepLink$it deepLink = _Translations$deepLink$it._(_root);
	@override late final _Translations$confirmDevice$it confirmDevice = _Translations$confirmDevice$it._(_root);
	@override late final _Translations$switchAccounts$it switchAccounts = _Translations$switchAccounts$it._(_root);
	@override late final _Translations$qsonImport$it qsonImport = _Translations$qsonImport$it._(_root);
	@override late final _Translations$adifImport$it adifImport = _Translations$adifImport$it._(_root);
	@override late final _Translations$offline$it offline = _Translations$offline$it._(_root);
	@override late final _Translations$exportSettings$it exportSettings = _Translations$exportSettings$it._(_root);
	@override late final _Translations$templateEditor$it templateEditor = _Translations$templateEditor$it._(_root);
}

// Path: common
class _Translations$common$it extends Translations$common$en {
	_Translations$common$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get save => 'Salva';
	@override String get ok => 'OK';
	@override String get cancel => 'Annulla';
	@override String get delete => 'Elimina';
	@override String get create => 'Crea';
	@override String get error => 'Errore';
	@override String get close => 'Chiudi';
	@override String get done => 'Fatto';
	@override String get callsign => 'Nominativo';
	@override String get clear => 'Cancella';
	@override String get dismiss => 'Ignora';
	@override String get copyDetails => 'Copia dettagli';
	@override String get expand => 'Espandi';
	@override String get collapse => 'Comprimi';
}

// Path: onboarding
class _Translations$onboarding$it extends Translations$onboarding$en {
	_Translations$onboarding$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Benvenuto in Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Benvenuto in Ham2K Power Logger!';
	@override String get welcomeBody => 'Abbiamo alcune domande per adattarci meglio alle tue esigenze.';
	@override String get skip => 'Salta';
	@override String get kContinue => 'Continua';
	@override String get back => 'Indietro';
	@override String get next => 'Avanti';
	@override String get done => 'Fatto';
	@override String get callsignTitle => 'Qual è il tuo nominativo?';
	@override String get callsignBody => 'Per trovare utile questa app ti serve una licenza di radioamatore';
	@override String get callsignLabel => 'Nominativo Operatore';
	@override String get alreadyHaveAccount => 'Hai già un account?';
	@override String get foundSiblingTitle => 'Collegare un account esistente?';
	@override String foundSiblingBody({required Object app}) => 'Abbiamo trovato ${app} su questo dispositivo. Collega questa app allo stesso account e il tuo nominativo e i tuoi log verranno trasferiti.';
	@override String get foundPoloBody => 'Abbiamo trovato una versione precedente di Ham2K Portable Logger su questo dispositivo. Collega questa app allo stesso account e il tuo nominativo e i tuoi log verranno trasferiti.';
	@override String get foundSiblingsBody => 'Abbiamo trovato altre app Ham2K su questo dispositivo. Collega questa app a uno dei loro account e il tuo nominativo e i tuoi log verranno trasferiti.';
	@override String linkWithApp({required Object app}) => 'Collega con ${app}';
	@override String get linkWithPolo => 'Collega con l\'account della versione precedente';
	@override String get setUpFresh => 'Configura da zero';
	@override String get activitiesTitle => 'Attività preferite';
	@override String get activitiesBody => 'Ti interessa qualcuno di questi popolari programmi di attivazione?';
	@override String get activitiesFooter => '(Trovi altre opzioni nelle Impostazioni)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'Sincronizzazione Cloud';
	@override String get syncBody => 'Ham2K Log Filer conserva una copia di backup dei tuoi log nel cloud e li sincronizza su tutti i dispositivi in cui usi le app Ham2K.';
	@override String get syncPricing => 'È gratis! Ma con un abbonamento a pagamento sarà più veloce.';
	@override String get syncLabel => 'Abilita la sincronizzazione cloud';
	@override String get syncOffWarning => 'ATTENZIONE: così aumentano le probabilità di perdere i dati delle operazioni, ad esempio se il dispositivo si blocca o viene smarrito.';
	@override String get notNow => 'Non ora';
	@override String get consentTitle => 'Dati e Privacy';
	@override String get consentUsageBody => 'Per aiutarci a migliorare l\'app, vorremmo raccogliere dati su prestazioni, arresti anomali e utilizzo dell\'app.';
	@override String get consentUsageLabel => 'Condividi i dati di utilizzo dell\'app';
	@override String get consentOperationBody => 'Alcune funzioni potrebbero comportare la condivisione dei dati delle tue operazioni con altri utenti. Puoi rinunciare in qualsiasi momento.';
	@override String get consentOperationLabel => 'Condividi i dati dell\'operazione';
	@override String get finishingSetup => 'Completamento configurazione — download dei dati delle referenze…';
}

// Path: startScreen
class _Translations$startScreen$it extends Translations$startScreen$en {
	_Translations$startScreen$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get credits => 'da KI2D e amici';
}

// Path: testerOverlay
class _Translations$testerOverlay$it extends Translations$testerOverlay$en {
	_Translations$testerOverlay$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get tape => 'ATTENZIONE: LAVORI IN CORSO';
	@override String get warningTitle => 'Questa app è in fase di sviluppo';
	@override String get warningBody => 'La maggior parte delle funzioni ha superfici irregolari e ci sono ostacoli ovunque. Controlla regolarmente gli aggiornamenti.';
	@override String whatsNew({required Object build}) => 'Novità della build ${build}';
	@override String get thanks => 'Grazie per aver messo a rischio il tuo log per aiutarci a migliorare questa app!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$it extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Attività';
	@override String get categoryAward => 'Diplomi';
	@override String get categoryContest => 'Contest';
	@override String get categoryLookup => 'Ricerca Nominativi';
	@override String get categorySpots => 'Fonti Spot';
	@override String get categoryDashboard => 'Pannelli Dashboard';
	@override String get categoryOther => 'Altre Estensioni';
	@override String get searchHint => 'Cerca estensioni';
	@override String get applying => 'Attivazione delle modifiche alle estensioni, potrebbe richiedere un momento…';
	@override String get noMatches => 'Nessuna estensione corrisponde alla ricerca';
	@override String get installFromFile => 'Installa da file…';
	@override String installVersion({required Object version}) => 'Versione ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'Screenshot ${n} di ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'Screenshot precedente';
	@override String get nextScreenshot => 'Screenshot successivo';
	@override String get screenshotUnavailable => 'Screenshot non disponibile';
	@override String get canReach => 'Questa estensione può contattare';
	@override String canHoldConnection({required Object host}) => '${host}, tramite una connessione attiva';
	@override String get canHoldLocalConnection => 'Dispositivi sulla tua rete locale, tramite una connessione attiva';
	@override String get canUseLocation => 'La tua posizione';
	@override String get canReadRadio => 'La tua radio, per leggerne frequenza e modo';
	@override String get canControlRadio => 'La tua radio, per controllarla e trasmettere con essa — sintonia, potenza, CW, memorie vocali e PTT';
	@override String get canCommandRadioRaw => 'La tua radio, per inviarle qualsiasi comando nel suo protocollo — compresi quelli che trasmettono o ne cambiano le impostazioni';
	@override String get canReadCluster => 'Il DX cluster, connesso come te, per leggere ciò che invia';
	@override String get canSpotCluster => 'Il DX cluster, connesso come te, per pubblicare spot a tuo nome';
	@override String get canCommandCluster => 'Il DX cluster, connesso come te, per inviargli qualsiasi comando a tuo nome';
	@override String get canSetUserAgent => 'Identificarsi presso i server con il proprio nome';
	@override String get canChangeSettings => 'Le tue impostazioni, per modificarle tramite i suoi comandi: qualsiasi impostazione, la modalità sviluppatore e gli esperimenti';
	@override String get noCapabilities => 'Non richiede nulla al di fuori dell\'app.';
	@override String get sandboxNote => 'Le estensioni sono eseguite in sandbox: nessun accesso ai tuoi file e nessuna rete oltre a quanto elencato qui.';
	@override String get installAction => 'Installa';
	@override String get updateAction => 'Aggiorna';
	@override String get installFailed => 'Impossibile installare l\'estensione';
	@override String get installedBadge => 'Installata';
	@override String get uninstallAction => 'Rimuovi';
	@override String uninstallTitle({required Object name}) => 'Rimuovere ${name}?';
	@override String get uninstallBody => 'Questa estensione e le sue impostazioni verranno rimosse. I tuoi log resteranno intatti.';
	@override String installedMessage({required Object name}) => '${name} installata';
	@override String get installDownloading => 'Download in corso…';
	@override String get installWaiting => 'In attesa di installazione…';
	@override String get installInstalling => 'Installazione in corso…';
	@override String get installAwaitingApproval => 'In attesa della tua approvazione…';
	@override String installAlreadyRunning({required Object name}) => '${name} è già in fase di installazione.';
	@override String updatedTo({required Object version}) => 'Aggiornata a ${version}';
	@override String installIncomplete({required Object name}) => 'L\'installazione di ${name} non è stata completata. Potrebbe essere necessario reinstallarla.';
	@override String uninstallFailed({required Object name}) => 'Impossibile rimuovere ${name}';
	@override String installedFrom({required Object source}) => 'Scaricata da ${source}';
	@override String get dropHint => 'Trascina qui un\'estensione .h2kext per installarla';
	@override String get dropOneOnly => 'Trascina un\'estensione alla volta.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} ha risposto ${status} per questa estensione.';
	@override String get downloadTooLarge => 'Il download è troppo grande per essere un\'estensione.';
	@override String get downloadNotSecure => 'Il download è stato reindirizzato a un indirizzo non sicuro.';
	@override String get catalogSection => 'Catalogo';
	@override String get catalogLoading => 'Caricamento del catalogo…';
	@override String get catalogUnreachable => 'Catalogo non raggiungibile';
	@override String get builtIn => 'Integrata';
	@override String get updateAvailableBadge => 'Aggiornamento disponibile';
	@override String get updatesAvailableTitle => 'Aggiornamenti estensioni';
	@override String updateAvailableFor({required Object name}) => 'È disponibile un aggiornamento per ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} e altre ${count} devono essere aggiornate.';
	@override String updatesAvailableFor({required Object names}) => '${names} devono essere aggiornate.';
	@override String get pendingUpdatesSection => 'Aggiornamenti in sospeso';
	@override String get updateAllAction => 'Aggiorna tutto';
	@override String get updatesUnderWay => 'Questi aggiornamenti sono già in corso.';
	@override String get updatesNothingLeft => 'Le tue estensioni sono aggiornate.';
	@override String get updatesNoticeAction => 'Maggiori info';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Aggiornare ${count} estensione?',
		other: 'Aggiornare ${count} estensioni?',
	);
	@override String get upgradeDoneTitle => 'Le tue estensioni sono pronte';
	@override String get upgradeDoneBody => 'Ora provengono dal catalogo estensioni di Ham2K, quindi possono essere aggiornate senza attendere una nuova versione dell\'app.';
	@override String upgradeDoneUnserved({required Object names}) => 'Non aggiornate: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Non avviate: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Sono ancora installate e segnalate in Impostazioni › Estensioni — aggiornarle da lì le ripristinerà.';
	@override String get upgradeDoneUnservedHint => 'Il catalogo non ha un sostituto diretto per queste, quindi cerca lì estensioni che coprano ciò che usavi.';
	@override String get retiredQp => 'QSO Party';
	@override String get retiredStateparks => 'Eventi State Parks';
	@override String upgradeDoneMissing({required Object count}) => '${count} delle tue estensioni non sono ancora arrivate. Verranno scaricate la prossima volta che il catalogo estensioni sarà raggiungibile.';
	@override String get runtimeDeadBody => 'Le tue estensioni non si sono avviate. Riavviare l\'app dovrebbe ripristinarle.';
	@override String get refusedTitle => 'Alcune estensioni non si sono avviate';
	@override String get upgradeBusyTitle => 'Configurazione ancora in corso';
	@override String get upgradeRuntimeDeadTitle => 'Le tue estensioni non sono in esecuzione';
	@override String get restoreTitle => 'Mancano alcune delle tue estensioni';
	@override String get restoreBody => 'Queste estensioni che hai installato non sono su questo dispositivo. Possiamo scaricarle di nuovo dal catalogo estensioni di Ham2K:';
	@override String get restoreFromFile => 'Installate da un file. Reinstallale dai loro file, oppure dimenticale:';
	@override String get restoreOtherCatalog => 'Installate da un altro catalogo estensioni, quindi non sono disponibili qui:';
	@override String get restoreForget => 'Dimentica';
	@override String get restoreInstall => 'Installa';
	@override String get restoreLater => 'Più tardi';
	@override String get restoreInstalling => 'Installazione delle tue estensioni…';
	@override String get restoreDoneTitle => 'Le tue estensioni sono tornate';
	@override String restoreDoneBody({required Object names}) => 'Reinstallate: ${names}.';
	@override String get restorePartialTitle => 'Alcune estensioni non sono state installate';
	@override String restoreFailed({required Object names}) => 'Impossibile installare: ${names}. Te le riproporremo la prossima volta che apri l\'app.';
	@override String get restoreBusyBody => 'L\'app sta ancora configurando le tue estensioni. Te le riproporremo la prossima volta che apri l\'app.';
	@override String get restoreRuntimeDeadBody => 'Le abbiamo reinstallate, ma le tue estensioni non si sono avviate. Riavviare l\'app dovrebbe ripristinarle.';
	@override String revokedTitle({required Object name}) => '${name} è stata ritirata';
	@override String get revokedBody => 'Il catalogo ha ritirato questa versione, quindi è stata disattivata.';
	@override String forceDisabledTitle({required Object name}) => '${name} è stata disattivata';
	@override String get forceDisabledBody => 'Ham2K ha disattivato questa estensione per il momento.';
	@override String replacedTitle({required Object name}) => '${name} è stata sostituita';
	@override String replacedBody({required Object replacement}) => 'Al suo posto c\'è ${replacement}. Puoi passare alla nuova in Estensioni.';
	@override String replacedBy({required Object name}) => 'Sostituita da ${name}';
	@override String replacedByInstalled({required Object name}) => 'Sostituita da ${name}, che hai già';
	@override String get replaceAction => 'Sostituisci';
	@override String replaceInstalledBody({required Object replacement}) => 'Le sue impostazioni passano a ${replacement}, che hai già. I tuoi log resteranno intatti.';
	@override String get downloadHashMismatch => 'Il download non è l\'estensione descritta dal catalogo.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Il catalogo non ha la versione ${version} di ${key}.';
	@override String get catalogLinkUnknown => 'Il link al catalogo non indica una versione di estensione.';
	@override String catalogNoRelease({required Object key}) => 'Il catalogo non ha alcuna release di ${key} su quel canale.';
	@override String get installFromLink => 'Installa da link';
	@override String get unstableReleaseWarning => 'Questa è una release instabile, che il suo autore non considera completa. Potrebbe funzionare male e continuerà a ricevere aggiornamenti instabili.';
	@override String get bleedingReleaseWarning => 'Questa è una release bleeding-edge: lavoro in corso che potrebbe rompersi o perdere le sue impostazioni. Continuerà a ricevere aggiornamenti bleeding-edge.';
	@override String get channelUnstable => 'Instabile';
	@override String get channelBleeding => 'Bleeding';
	@override String get followsUnstable => 'Riceve release instabili e stabili';
	@override String get followsBleeding => 'Riceve release bleeding-edge, instabili e stabili';
	@override String get followStableAction => 'Segui solo le release stabili';
	@override String get revokedBadge => 'Ritirata';
	@override String get forceDisabledBadge => 'Disattivata da Ham2K';
	@override String get refusedBadge => 'Non caricata';
	@override String get downloadNotHttps => 'Il download non avviene su una connessione sicura.';
	@override String downloadUnreachable({required Object source}) => 'Impossibile raggiungere ${source} per questa estensione.';
	@override String get detailsAction => 'Dettagli';
	@override String get installedFromFile => 'Installata da un file';
	@override String get detailsWhatItDoes => 'Fornisce supporto per';
	@override String get installedPreloaded => 'Preinstallata';
	@override String get hookAccount => 'Accesso all\'account';
	@override String get hookCallNotes => 'Note sui nominativi';
	@override String get hookDataFile => 'Dati fuori rete';
	@override String get hookExport => 'Esportazione';
	@override String get hookLookup => 'Ricerca nominativi';
	@override String get hookScoring => 'Punteggio';
	@override String get hookSpots => 'Spot';
	@override String hookHunting({required Object program}) => 'Caccia ${program}';
	@override String hookActivating({required Object program}) => 'Attivazione ${program}';
	@override String get suggestedSection => 'Suggerite';
	@override String moreAvailableSection({required Object count}) => 'Altre disponibili (${count})';
}

// Path: home
class _Translations$home$it extends Translations$home$en {
	_Translations$home$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logger Portatile';
	@override String get newOperation => 'Nuova operazione';
	@override String get stationCallsign => 'Nominativo di stazione';
	@override String get titleOptional => 'Titolo (opzionale)';
	@override String get emptyList => 'Ancora nessuna operazione. Creane una per iniziare a registrare.';
	@override String get quickLookup => 'Ricerca Rapida';
	@override late final _Translations$home$nav$it nav = _Translations$home$nav$it._(_root);
	@override late final _Translations$home$panels$it panels = _Translations$home$panels$it._(_root);
	@override String get toggleNav => 'Mostra o nascondi le etichette di navigazione';
	@override late final _Translations$home$logs$it logs = _Translations$home$logs$it._(_root);
}

// Path: chase
class _Translations$chase$it extends Translations$chase$en {
	_Translations$chase$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'a caccia di';
	@override String goalsTwo({required Object first, required Object second}) => '${first} e ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} e altro';
	@override late final _Translations$chase$station$it station = _Translations$chase$station$it._(_root);
	@override late final _Translations$chase$periodInline$it periodInline = _Translations$chase$periodInline$it._(_root);
	@override late final _Translations$chase$periodStats$it periodStats = _Translations$chase$periodStats$it._(_root);
	@override late final _Translations$chase$period$it period = _Translations$chase$period$it._(_root);
	@override late final _Translations$chase$goals$it goals = _Translations$chase$goals$it._(_root);
	@override late final _Translations$chase$panels$it panels = _Translations$chase$panels$it._(_root);
	@override late final _Translations$chase$claims$it claims = _Translations$chase$claims$it._(_root);
	@override late final _Translations$chase$notice$it notice = _Translations$chase$notice$it._(_root);
	@override late final _Translations$chase$alerts$it alerts = _Translations$chase$alerts$it._(_root);
	@override String get checklists => 'Progressi di caccia';
	@override late final _Translations$chase$imports$it imports = _Translations$chase$imports$it._(_root);
}

// Path: dialogs
class _Translations$dialogs$it extends Translations$dialogs$en {
	_Translations$dialogs$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Dettagli operazione';
	@override String get activities => 'Attività';
	@override String get stationCallsign => 'Nominativo di Stazione';
	@override String get advanced => 'Avanzate';
	@override String get operatingPosition => 'Postazione operativa (multi-stazione)';
	@override String get assistance => 'Assistenza';
	@override String get assistanceDescription => 'Usa i servizi di spotting e altre fonti di informazioni';
	@override String get selfSpotting => 'Auto-spot';
	@override String get selfSpottingDescription => 'Consenti le funzioni che comunicano la tua frequenza';
	@override String disabledByRules({required Object rules}) => 'Disattivato per rispettare il regolamento ${rules}';
	@override late final _Translations$dialogs$lookupDespiteAssistance$it lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$it._(_root);
	@override String get notes => 'Note';
	@override String get deleteOperationTitle => 'Elimina Operazione';
	@override String get purgeTestsTitle => 'Elimina le Operazioni di Test';
	@override String get purgeTestsBody => 'Questo elimina definitivamente queste Operazioni di Test e i loro QSO. Non può essere annullato.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Più ${count} contatto di test che non appartiene ad alcuna operazione.',
		other: 'Più ${count} contatti di test che non appartengono ad alcuna operazione.',
	);
	@override String get purgeTestsAction => 'Elimina';
	@override String get syncAllTitle => 'Sostituire il log di questo dispositivo?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL esegue il backup e rimuove ${qsos} da questo dispositivo, poi scarica di nuovo il log dell\'account dal server. Il backup resta nel database di questo dispositivo.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${n} QSO non è ancora stato sincronizzato — il server non l\'ha mai ricevuto e NON tornerà.',
		other: '${n} QSO non sono ancora stati sincronizzati — il server non li ha mai ricevuti e NON torneranno.',
	);
	@override String get syncAllAction => 'Cancella e risincronizza';
	@override String get receivedPurgesTitle => 'Operazioni di Test rimosse altrove';
	@override String get receivedPurgesBody => 'Queste sono state eliminate come Operazioni di Test su un altro dispositivo. Rimuoverle anche qui? Questo le elimina definitivamente insieme ai loro QSO e non può essere annullato.';
	@override String get receivedPurgesAction => 'Rimuovi';
	@override late final _Translations$dialogs$callChange$it callChange = _Translations$dialogs$callChange$it._(_root);
}

// Path: operation
class _Translations$operation$it extends Translations$operation$en {
	_Translations$operation$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Questa operazione è eliminata. Ripristinala per registrare o apportare modifiche.';
	@override late final _Translations$operation$tabs$it tabs = _Translations$operation$tabs$it._(_root);
	@override late final _Translations$operation$positions$it positions = _Translations$operation$positions$it._(_root);
	@override String get stationCallsignNone => 'Nessun nominativo di stazione';
	@override String get titleNone => 'Nessun titolo';
	@override String get deleteOperation => 'Elimina operazione';
	@override String get loggingControlsStale => 'I campi dell\'attività potrebbero non essere aggiornati — riapri l\'operazione per aggiornarli';
	@override String get locationNone => 'Non impostata';
	@override String get generalOperation => 'Operazione Generale';
	@override String titleFor({required Object value}) => 'per ${value}';
	@override String titleAt({required Object value}) => 'a ${value}';
	@override String segmentNow({required Object description}) => 'Adesso ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$it menu = _Translations$operation$menu$it._(_root);
	@override late final _Translations$operation$layout$it layout = _Translations$operation$layout$it._(_root);
	@override late final _Translations$operation$export$it export = _Translations$operation$export$it._(_root);
	@override late final _Translations$operation$spots$it spots = _Translations$operation$spots$it._(_root);
	@override late final _Translations$operation$import$it import = _Translations$operation$import$it._(_root);
}

// Path: map
class _Translations$map$it extends Translations$map$en {
	_Translations$map$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$it outlineIssue = _Translations$map$outlineIssue$it._(_root);
	@override String get outlinesDisclaimer => 'I contorni sono solo indicativi. Verifica sempre per conto tuo!';
	@override String outlinesCredit({required Object sources}) => 'Contorni: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Confini: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Strutture: ${sources}';
	@override String get fullCredits => 'Crediti completi dei dati';
	@override String get fewerCredits => 'Meno crediti';
	@override String get emptyState => 'Ancora nessuna posizione dei QSO.\nI QSO con locatore, stato o paese appariranno qui.';
	@override String get unavailable => 'La mappa non è disponibile al momento.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Piatta';
	@override String get globe => 'Globo';
	@override String get zoomIn => 'Ingrandisci';
	@override String get zoomOut => 'Riduci';
	@override String get resetNorth => 'Riporta il nord in alto';
	@override late final _Translations$map$postcard$it postcard = _Translations$map$postcard$it._(_root);
}

// Path: mapsView
class _Translations$mapsView$it extends Translations$mapsView$en {
	_Translations$mapsView$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mappe';
	@override String get searchHint => 'Cerca parchi, vette e altro';
	@override String get activities => 'Attività';
	@override String get layers => 'Livelli';
	@override String get baseMap => 'Mappa di base';
	@override String get satellite => 'Satellite (Esri)';
	@override String get facilities => 'Strutture dei parchi';
	@override String get boundaries => 'Confini';
	@override String get currentLocation => 'Posizione attuale';
	@override String noMatches({required Object text}) => 'Nessun risultato per “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} referenza a ${where}',
		other: '${count} referenze a ${where}',
	);
	@override String get startOperation => 'Avvia un\'operazione con queste referenze';
}

// Path: activitiesView
class _Translations$activitiesView$it extends Translations$activitiesView$en {
	_Translations$activitiesView$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Attività';
	@override String get activitiesCountZero => 'Nessuna attività selezionata';
	@override String get activitiesCountOne => '1 Attività';
	@override String activitiesCountOther({required Object count}) => '${count} Attività';
	@override String get empty => 'Ancora nessuna attività — usa Suggerimenti e Ricerca qui sotto per aggiungerne una';
	@override String get removeActivity => 'Rimuovi';
	@override String openReferenceLink({required Object name}) => 'Apri ${name}';
	@override String get editActivity => 'Modifica attività';
	@override String get manageExtensions => 'Gestisci Estensioni';
	@override String get manage => 'Gestisci';
	@override String activitiesTitle1({required Object first}) => 'Tipi di attività: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipi di attività: ${first} e ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipi di attività: ${first}, ${second} e altri ${more}';
	@override String get reference => 'Referenza';
	@override String get invalidReference => 'Non valida';
	@override String get duplicateReference => 'Già aggiunta';
	@override String get searchHint => 'Cerca per nome, referenza o altro…';
	@override String get noSuggestions => 'Nessun risultato';
	@override String get noSuggestionsHint => 'Cerca sopra per nome o numero di referenza';
	@override String get noSuggestionsExample => '(per esempio \'trail\' o \'4556\')';
	@override String get allOptions => 'Tipi di attività';
	@override String get determiningLocation => 'Rilevamento della posizione attuale…\nIn attesa del fix GPS per trovare le referenze vicine';
	@override String get locationUnavailableTitle => 'Dati di posizione non disponibili';
	@override String get locationDeniedTitle => 'Permesso di posizione negato';
	@override String get locationBlockedTitle => 'Permesso di posizione bloccato';
	@override String get noNearbyReason => 'Impossibile determinare le referenze vicine';
	@override String locationManualHint({required Object icon}) => 'Tocca ${icon} per inserire manualmente la tua posizione,\no cerca semplicemente le referenze per nome';
	@override String get locationGrantAction => 'Consenti l\'accesso alla posizione';
	@override String get locationSettingsAction => 'Apri Impostazioni';
	@override String get locationSettingsUnavailable => 'Consenti l\'accesso alla posizione nelle impostazioni di sistema';
	@override String get locationGrantRefused => 'Ancora nessuna posizione — il sistema ha di nuovo negato il permesso';
	@override String get searchUnavailableTitle => 'Ricerca attività non disponibile';
	@override String get searchUnavailableReason => 'Un\'estensione di attività non ha potuto rispondere alla ricerca. Riprova tra un momento.';
	@override String get emptySheet => 'Usa suggerimenti e ricerca qui sotto per aggiungerne una';
	@override String get exports => 'Esportazioni';
	@override String get exportLogs => 'Esporta Log';
	@override String get tools => 'Strumenti';
	@override String get toolsTitle => 'Strumenti dell\'operazione';
	@override String get operationDetails => 'Dettagli operazione';
	@override String get share => 'Condividi';
	@override String get archive => 'Archivia';
	@override String get deleteOperation => 'Elimina Operazione';
	@override String get undeleteOperation => 'Ripristina Operazione';
	@override String get alreadySelected => 'Già selezionata';
	@override String get selected => 'Selezionata';
	@override String pickPosition({required Object index, required Object count}) => '${index} di ${count}';
	@override String get previousPick => 'Risultato precedente';
	@override String get nextPick => 'Risultato successivo';
	@override String get retiredReference => 'Ritirata';
	@override String enableExtension({required Object name}) => 'Abilita ${name}';
	@override String get enableExtensionHint => 'Questa estensione corrisponde alla ricerca, ma al momento non è abilitata';
	@override String get enableExtensionForRefHint => 'Questa estensione gestisce una delle referenze di questa operazione, ma al momento non è abilitata';
	@override String extensionNotRunning({required Object name}) => '${name} non è in esecuzione';
	@override String get extensionNotRunningHint => 'Questa estensione è stata disattivata, apri Impostazioni Estensioni per maggiori informazioni';
	@override String installExtension({required Object name}) => 'Installa ${name}';
	@override String get installExtensionHint => 'Questa estensione corrisponde alla ricerca, ma non è installata';
	@override String get onlyCatalogMatches => 'Nessun risultato\nAlcune estensioni nel catalogo potrebbero avere risultati.\nInstallale in Tipi di attività qui sotto.';
	@override String get setupUnavailable => 'Impossibile caricare la configurazione di questa attività — riprova da Gestisci';
	@override String get controlsUnavailableTitle => 'Controlli attività non disponibili';
	@override String get controlsUnavailableReason => 'Le tue referenze sono al sicuro, ma al momento non è possibile modificarle.';
	@override String get controlsUnavailableRetry => 'Riprova';
	@override String get onlyDisabledMatches => 'Nessun risultato\nAlcune estensioni disponibili potrebbero avere risultati.\nAbilitale in Tipi di attività qui sotto.';
	@override String get onlyNotRunningMatches => 'Nessun risultato\nAlcune estensioni che potrebbero avere risultati non sono in esecuzione.\nVedi Tipi di attività qui sotto.';
	@override String get mapToggle => 'Mappa';
	@override String get searchToggle => 'Cerca';
	@override String get addToOperation => 'Aggiungi all\'Operazione';
	@override String get addToOperationShort => 'Aggiungi all\'Op.';
	@override String get mapEmptyState => 'Nessun risultato da mostrare sulla mappa';
	@override String get mapEmptyStateHint => 'Torna all\'elenco, o cerca qualcos\'altro';
	@override String get imports => 'Importazioni';
}

// Path: loggingControls
class _Translations$loggingControls$it extends Translations$loggingControls$en {
	_Translations$loggingControls$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Ora (UTC)';
	@override String get date => 'Data';
	@override String get now => 'Adesso';
	@override String get manualTimeSettings => 'Ora manuale';
	@override String get manualTimeIncrement => 'Incremento per QSO';
	@override String get manualTimeIncrementNone => 'Nessuno';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} minuto',
		other: '${count} minuti',
	);
	@override String get frequency => 'Frequenza';
	@override String get mode => 'Modo';
	@override String get theirCall => 'Nominativo';
	@override String get noteField => 'Nota';
	@override String get todoField => 'Da fare';
	@override String get sent => 'Inviato';
	@override String get rcvd => 'Ricev';
	@override String get more => 'Altro';
	@override String get revert => 'Ripristina';
	@override String get undoDelete => 'Annulla eliminazione';
	@override String get restore => 'Ripristina';
	@override String get wipe => 'Cancella';
	@override String get undo => 'Annulla';
	@override String get pendingDeleteTapWarning => 'Tocca ancora una volta il cestino per eliminare questo QSO';
	@override String get pendingDeleteClickWarning => 'Fai clic ancora una volta sul cestino per eliminare questo QSO';
	@override String get deletedQsoWarning => 'QSO eliminato';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Tocca ancora una volta il cestino per eliminare questo ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Fai clic ancora una volta sul cestino per eliminare questo ${kind}';
	@override String deletedEventWarning({required Object kind}) => '${kind} eliminato';
	@override String get timeControl => 'Ora';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Potenza';
	@override String get notesControl => 'Note';
	@override String get power => 'Potenza';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controlli di Logging';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Auto-spot';
	@override String spotSelfAt({required Object freq}) => 'Auto-spot a ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} a ${freq}';
	@override String spotTooLate({required Object call}) => 'Troppo tardi per spottare ${call}';
	@override String get spotNoFreq => 'Prima imposta una frequenza per lo spot';
	@override String get selfSpotDisabled => 'Auto-spot disattivato';
	@override String get spotComment => 'Commento';
	@override String get spottingAutoControl => 'Re-spot automatico';
	@override String spotAutoEvery({required Object minutes}) => 'Re-spot ogni ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'Auto tra ${time}. Fermare?';
	@override String spotAutoInMinutes({required Object minutes}) => 'Auto tra ${minutes}m';
	@override String spotAutoInSeconds({required Object seconds}) => 'Auto tra ${seconds}s';
	@override String spotAutoInCount({required Object seconds}) => 'Auto tra ${seconds}';
	@override String get spotAutoNotStarted => 'Re-spot automatico non avviato: lo spot non è andato a buon fine';
	@override String get spotAutoMoved => 'Re-spot automatico non avviato: la frequenza è cambiata durante lo spot';
	@override String get spotAutoStopped => 'Re-spot automatico fermato';
	@override String get spotAutoLeftFreq => 'Re-spot automatico fermato: la frequenza è cambiata';
	@override String get spotAutoNoFreq => 'Re-spot automatico fermato: la radio non riporta alcuna frequenza';
	@override String get spotBusy => 'Un altro spot è ancora in invio';
	@override String get bandOrFreqRequired => 'Imposta una frequenza o una banda prima di registrare';
	@override String get missingBand => 'Nessuna Banda';
	@override String get missingMode => 'Nessun Modo';
	@override String saveFailed({required Object error}) => 'Impossibile salvare: ${error}';
	@override String deleteFailed({required Object error}) => 'Impossibile eliminare: ${error}';
	@override late final _Translations$loggingControls$info$it info = _Translations$loggingControls$info$it._(_root);
}

// Path: formChrome
class _Translations$formChrome$it extends Translations$formChrome$en {
	_Translations$formChrome$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(senza titolo)';
	@override String get showMore => 'Mostra altro';
	@override String get showAll => 'Mostra tutto';
	@override String get showFewer => 'Mostra meno';
	@override String get defaults => 'Predefiniti';
	@override String get search => 'Cerca';
	@override String get clear => 'Cancella';
	@override String get openPage => 'Apri pagina';
	@override String get connected => 'Connesso';
	@override String get notConnected => 'Non connesso';
	@override String get manage => 'Gestisci';
	@override String get connect => 'Connetti';
	@override String get formTitle => 'Modulo';
	@override String addItem({required Object label}) => 'Aggiungi ${label}';
	@override String editItem({required Object label}) => 'Modifica ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => '${shown} visualizzati su ${total} (${selected} selezionati)';
	@override String validationError({required Object error}) => 'Errore di validazione: ${error}';
	@override String transformationError({required Object error}) => 'Errore di trasformazione: ${error}';
	@override String actionError({required Object error}) => 'Errore: ${error}';
	@override String get removeItem => 'Elimina';
	@override String deleteItemTitle({required Object name}) => 'Eliminare ${name}?';
	@override String get storageUnavailable => 'Credenziali non disponibili';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$it extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modifica QSO';
	@override String get operatorCall => 'Operatore';
	@override String get position => 'Postazione';
	@override String get theirName => 'Nome';
	@override String get theirGrid => 'Locatore';
	@override String get theirState => 'Stato';
	@override String get band => 'Banda';
	@override String get notes => 'Note';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Le loro informazioni';
	@override String get sectionOur => 'Le nostre informazioni';
	@override String get sectionNotes => 'Note';
	@override String get theirCity => 'Città';
	@override String get theirCounty => 'Contea';
	@override String get theirEntity => 'Entità';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Sezione ARRL';
	@override String get theirLat => 'Latitudine';
	@override String get theirLon => 'Longitudine';
	@override String get theirPower => 'La loro potenza';
}

// Path: qsoList
class _Translations$qsoList$it extends Translations$qsoList$en {
	_Translations$qsoList$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ancora nessun QSO — collega qualcuno!';
	@override String get bandOrModeWarning => 'Assicurati che banda e modo siano corretti';
	@override String get today => 'Oggi';
	@override String get yesterday => 'Ieri';
	@override String get tomorrow => 'Domani';
	@override late final _Translations$qsoList$find$it find = _Translations$qsoList$find$it._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$it extends Translations$loggingPanel$en {
	_Translations$loggingPanel$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Statistiche dell\'operazione';
	@override String get scoring => 'Punteggio';
	@override String get dxccEntities => 'Entità DXCC';
	@override String get statesWorked => 'Stati';
	@override String get provincesWorked => 'Province';
	@override String get duplicates => 'Duplicati';
}

// Path: callInfo
class _Translations$callInfo$it extends Translations$callInfo$en {
	_Translations$callInfo$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostra immagine';
	@override String get imageUnavailable => 'Foto non disponibile';
	@override String get photo => 'Foto';
	@override String get notes => 'Note';
	@override String distanceTo({required Object distance}) => '${distance} verso';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verso';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verso';
	@override String distanceAway({required Object distance}) => '${distance} di distanza';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) di distanza';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) di distanza';
	@override String get thisOpCountOne => '1 QSO in questa operazione';
	@override String thisOpCountOther({required Object count}) => '${count} QSO in questa operazione';
	@override String get otherOpsCountOne => '1 QSO in altre operazioni';
	@override String otherOpsCountOther({required Object count}) => '${count} QSO in altre operazioni';
	@override String andMore({required Object count}) => '… e altri ${count}';
	@override String withCall({required Object call}) => 'con ${call}';
	@override String fromOperation({required Object where}) => 'da ${where}';
	@override late final _Translations$callInfo$history$it history = _Translations$callInfo$history$it._(_root);
}

// Path: settings
class _Translations$settings$it extends Translations$settings$en {
	_Translations$settings$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Impostazioni';
	@override String get language => 'Lingua';
	@override String languageSystem({required Object language}) => 'Segui le impostazioni di sistema (${language})';
	@override late final _Translations$settings$theme$it theme = _Translations$settings$theme$it._(_root);
	@override late final _Translations$settings$themeDescription$it themeDescription = _Translations$settings$themeDescription$it._(_root);
	@override String get fontScale => 'Dimensione del Carattere';
	@override late final _Translations$settings$fontScaleOpts$it fontScaleOpts = _Translations$settings$fontScaleOpts$it._(_root);
	@override late final _Translations$settings$keepDeviceAwake$it keepDeviceAwake = _Translations$settings$keepDeviceAwake$it._(_root);
	@override String get layoutDensity => 'Densità del layout';
	@override late final _Translations$settings$layoutDensityOpts$it layoutDensityOpts = _Translations$settings$layoutDensityOpts$it._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'la finestra è troppo bassa, viene usata ${effective}';
	@override String get layoutDensityAtLimit => 'al limite';
	@override String get distanceUnits => 'Unità di distanza';
	@override late final _Translations$settings$distanceUnitsOpts$it distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$it._(_root);
	@override String get userInterface => 'Interfaccia utente';
	@override late final _Translations$settings$logging$it logging = _Translations$settings$logging$it._(_root);
	@override late final _Translations$settings$catServer$it catServer = _Translations$settings$catServer$it._(_root);
	@override late final _Translations$settings$cluster$it cluster = _Translations$settings$cluster$it._(_root);
	@override late final _Translations$settings$spotting$it spotting = _Translations$settings$spotting$it._(_root);
	@override late final _Translations$settings$radio$it radio = _Translations$settings$radio$it._(_root);
	@override late final _Translations$settings$help$it help = _Translations$settings$help$it._(_root);
	@override late final _Translations$settings$exports$it exports = _Translations$settings$exports$it._(_root);
	@override late final _Translations$settings$extensionSections$it extensionSections = _Translations$settings$extensionSections$it._(_root);
	@override late final _Translations$settings$map$it map = _Translations$settings$map$it._(_root);
	@override late final _Translations$settings$privacy$it privacy = _Translations$settings$privacy$it._(_root);
	@override String get operatorCall => 'Nominativo Operatore';
	@override late final _Translations$settings$sync$it sync = _Translations$settings$sync$it._(_root);
	@override late final _Translations$settings$peers$it peers = _Translations$settings$peers$it._(_root);
	@override String get developerMode => 'Modalità Sviluppatore';
	@override late final _Translations$settings$syncPanel$it syncPanel = _Translations$settings$syncPanel$it._(_root);
	@override late final _Translations$settings$accounts$it accounts = _Translations$settings$accounts$it._(_root);
	@override late final _Translations$settings$station$it station = _Translations$settings$station$it._(_root);
	@override late final _Translations$settings$offlineData$it offlineData = _Translations$settings$offlineData$it._(_root);
	@override late final _Translations$settings$profiles$it profiles = _Translations$settings$profiles$it._(_root);
	@override late final _Translations$settings$search$it search = _Translations$settings$search$it._(_root);
	@override late final _Translations$settings$developer$it developer = _Translations$settings$developer$it._(_root);
	@override late final _Translations$settings$about$it about = _Translations$settings$about$it._(_root);
	@override late final _Translations$settings$panels$it panels = _Translations$settings$panels$it._(_root);
	@override String get showMoreSettings => 'Mostra altre impostazioni';
	@override String get gridPrecision => 'Precisione del locatore';
	@override late final _Translations$settings$gridPrecisionOpts$it gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$it._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$it gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$it._(_root);
}

// Path: commands
class _Translations$commands$it extends Translations$commands$en {
	_Translations$commands$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Prima abilita la sincronizzazione nelle Impostazioni.';
	@override String get fullResyncStarted => 'Risincronizzazione completa avviata — prima è stato fatto un backup dei dati locali.';
	@override String noDataFilesMatched({required Object target}) => 'Nessun file di dati corrisponde a "${target}".';
	@override String reloadFailed({required Object error}) => 'Ricaricamento non riuscito: ${error}';
	@override String get reloadingAll => 'Ricaricamento di tutti i file di dati…';
	@override String reloadingTarget({required Object target}) => 'Ricaricamento dei file di dati ${target}…';
	@override String unknownExperiment({required Object token}) => 'Esperimento sconosciuto "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} abilitato';
	@override String experimentDisabled({required Object name}) => '${name} disabilitato';
	@override String get sentryTestSent => 'Segnalazione di errore di prova inviata a Sentry';
	@override String get idleMetricsEnabled => 'Metriche di inattività abilitate nella barra di stato';
	@override String get idleMetricsDisabled => 'Metriche di inattività disabilitate';
	@override String get sentryTestLocalOnly => 'Sentry è disabilitato in questa build — errore di prova registrato solo localmente';
	@override String get noOperationOpen => 'Questo comando richiede un\'operazione aperta';
	@override String unknownSegmentKind({required Object kind}) => 'Non so come contrassegnare un \'${kind}\'';
	@override String goUnavailable({required Object place}) => '${place} non è attivo in questa app';
	@override String goUnknown({required Object to}) => 'Non so come andare a \'${to}\'';
	@override String get goBlocked => 'Prima chiudi la finestra di dialogo aperta';
	@override String get operationAlreadyStarted => 'Questa operazione ha già un marcatore di inizio';
	@override String get couldNotOpenLocation => 'Pausa aggiunta, ma impossibile aprire la schermata della posizione';
	@override String get noTestOperations => 'Nessuna Operazione di Test da eliminare';
	@override String get purgeTestsUnavailable => 'PURGETESTS deve mostrare una finestra di conferma, che qui non è disponibile';
	@override String get syncAllUnavailable => 'SYNCALL deve mostrare una finestra di conferma, che qui non è disponibile';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Eliminata ${count} Operazione di Test',
		other: 'Eliminate ${count} Operazioni di Test',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Eliminate ${purged} Operazioni di Test su ${total} — le altre non sono riuscite; riprova PURGETESTS';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Eliminato ${count} contatto di test senza operazione',
		other: 'Eliminati ${count} contatti di test senza operazione',
	);
	@override String get purgeTestsContactsFailed => 'Operazioni di Test eliminate, ma l\'eliminazione dei contatti di test senza operazione non è riuscita; riprova PURGETESTS';
	@override String get purgeTestsNothingToDo => 'Non è stato eliminato nulla';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Rimosse ${removed} Operazioni di Test su ${total} — le altre non sono riuscite; riprova con Rivedi';
	@override String get receivedPurgesFailed => 'Impossibile rimuovere quelle Operazioni di Test — riprova con Rivedi';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} Operazione di Test è stata rimossa su un altro dispositivo',
		other: '${count} Operazioni di Test sono state rimosse su un altro dispositivo',
	);
	@override String get receivedPurgesReview => 'Rivedi';
	@override String get settingOn => 'On';
	@override String get settingOff => 'Off';
	@override String get settingEmpty => '(vuoto)';
	@override String get settingSecretSet => '(impostato)';
	@override String get settingSecretUnset => '(non impostato)';
	@override String settingSelectedCount({required Object count}) => '${count} selezionati';
	@override String get settingExpectsOnOff => 'on o off';
	@override String settingExpectsOneOf({required Object choices}) => 'uno tra: ${choices}';
	@override String get settingExpectsNumber => 'un numero';
	@override String settingVanished({required Object label}) => '“${label}” non è più disponibile';
	@override String get noCwKeyer => 'Nessuna radio connessa può trasmettere in CW';
	@override String get noKeyer => 'Nessuna radio connessa può trasmettere in CW o riprodurre memorie vocali';
	@override String get keyerNeedsOperation => 'Apri un\'operazione per usare il keyer CW';
	@override String get keyerExperimentOff => 'La manipolazione CW è disattivata — attivala con EXP KEYER';
	@override String get esmExperimentOff => 'Invio trasmette i messaggi è disattivato — attivalo con EXP ESM';
	@override String cwSending({required Object text}) => 'Trasmissione CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Messaggio CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'Il messaggio CW F${n} non è stato trasmesso: le estensioni non sono pronte';
	@override String voiceMessageError({required Object n, required Object error}) => 'Messaggio in fonia M${n}: ${error}';
	@override String get voiceMessageNotRendered => 'le estensioni non sono pronte';
	@override String so2rRadioCannotKey({required Object radio}) => 'Nulla trasmesso: la Radio ${radio} non può trasmetterlo';
	@override String get so2rNoRadioB => 'Nulla trasmesso: scegli una Radio B in Configurazione Stazione per trasmettere da questo set';
	@override String settingNotStored({required Object label}) => '“${label}” non ha accettato quel valore';
}

// Path: commandDialog
class _Translations$commandDialog$it extends Translations$commandDialog$en {
	_Translations$commandDialog$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Cerca nominativi o digita un comando';
	@override String noResults({required Object text}) => 'Nessun risultato per “${text}”';
	@override String get sectionCommands => 'Comandi';
	@override String get sectionGoTo => 'Vai a';
	@override String get sectionOperations => 'Operazioni';
	@override String get goHome => 'Home';
	@override String get goSettings => 'Impostazioni';
	@override String get goNewOperation => 'Nuova operazione';
	@override String runTyped({required Object text}) => 'Esegui “${text}”';
	@override String get sectionSuggestions => 'Prova';
	@override String get lookingUp => 'Ricerca del nominativo in corso…';
	@override String get blockedByPane => 'Impossibile usare i comandi mentre è aperto un pannello o una finestra di dialogo';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$it extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Scorciatoie da Tastiera';
	@override String get description => 'Personalizza le combinazioni di tasti';
	@override String get search => 'Cerca comandi e tasti';
	@override String get import => 'Importa…';
	@override String get export => 'Esporta…';
	@override String get resetAll => 'Ripristina Tutto';
	@override String get resetAllTitle => 'Ripristinare tutte le scorciatoie?';
	@override String get resetAllBody => 'Ogni comando torna ai suoi tasti predefiniti, e i tasti assegnati ai comandi digitati vengono rimossi.';
	@override String get reset => 'Ripristina';
	@override String get noKey => 'Nessun tasto';
	@override String get changed => 'Modificata';
	@override String conflict({required Object keys, required Object commands}) => '${keys} è assegnato anche a ${commands}';
	@override String get groupApp => 'App';
	@override String get groupKeying => 'Manipolazione';
	@override String get groupLogging => 'Logging';
	@override String get groupCommands => 'Comandi';
	@override String get groupFixed => 'Tasti fissi';
	@override String get contextApp => 'Ovunque';
	@override String get contextLogView => 'Viste Operazione, Caccia e Log';
	@override String get contextOperation => 'Vista Operazione, manipolando una radio CAT';
	@override String get contextLogging => 'Nel pannello di logging';
	@override String get addCommand => 'Aggiungi un Comando…';
	@override String unknownCommand({required Object command}) => 'Comando sconosciuto: ${command}';
	@override late final _Translations$keyboardShortcuts$command$it command = _Translations$keyboardShortcuts$command$it._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$it fixed = _Translations$keyboardShortcuts$fixed$it._(_root);
	@override late final _Translations$keyboardShortcuts$editor$it editor = _Translations$keyboardShortcuts$editor$it._(_root);
	@override late final _Translations$keyboardShortcuts$file$it file = _Translations$keyboardShortcuts$file$it._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$it modifier = _Translations$keyboardShortcuts$modifier$it._(_root);
	@override late final _Translations$keyboardShortcuts$platform$it platform = _Translations$keyboardShortcuts$platform$it._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$it extends Translations$expiredBuild$en {
	_Translations$expiredBuild$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Questa build è scaduta';
	@override String get body => 'Visita ham2k.com e scarica una versione più recente.';
	@override String get visit => 'Visita ham2k.com';
	@override String get dismiss => 'Continua comunque';
}

// Path: staleness
class _Translations$staleness$it extends Translations$staleness$en {
	_Translations$staleness$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Un aggiornamento importante è in attesa';
	@override String get codePushFloorBody => 'Questa versione ha una correzione che non hai ancora.';
	@override String get restartToApply => 'Riavvia l\'app per applicarla.';
	@override String get quitAndReopen => 'Esci dall\'app e riaprila per applicarla.';
	@override String get reopenToApply => 'Chiudi l\'app e riaprila per applicarla.';
	@override String get ignoreForNow => 'Ignora per ora';
}

// Path: spotting
class _Translations$spotting$it extends Translations$spotting$en {
	_Translations$spotting$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Nessun QSO ancora registrato da spottare.';
	@override String get setFrequencyFirst => 'Prima imposta una frequenza.';
	@override String get nothingToSpot => 'Niente da spottare — nessuna estensione offre lo spotting qui.';
	@override String get incompleteCall => 'Impossibile spottare un nominativo incompleto — prima completa il nominativo.';
	@override String spotFailed({required Object source, required Object message}) => '${source} non riuscito: ${message}';
	@override String get unknownError => 'errore sconosciuto';
	@override String get notSent => 'Spot non inviato.';
	@override String get allSkipped => 'Spot non inviato: tutte le fonti spot lo hanno saltato.';
	@override String get notRefreshedOffline => 'Nessuna connessione — gli spot non sono stati aggiornati';
}

// Path: dataFiles
class _Translations$dataFiles$it extends Translations$dataFiles$en {
	_Translations$dataFiles$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Download in corso…';
	@override String downloadFailedTitle({required Object name}) => 'Impossibile scaricare ${name}';
	@override String get downloadFailedWebHint => 'Potrebbe essere un problema di rete, oppure l\'host di questo link potrebbe non supportare i download diretti da un browser web. Prova l\'app desktop o mobile, o un altro servizio di hosting.';
	@override String get downloadTimedOut => 'Il server ha impiegato troppo tempo a rispondere. Riprova più tardi.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} ha risposto con un errore (HTTP ${status}). Riprova più tardi.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} non ha potuto fornire questo file (HTTP ${status}). Controlla che il suo indirizzo sia ancora corretto.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM non ha un file di call history per ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'Il download della call history di N1MM per ${stem} non ha funzionato. Riprova più tardi.';
	@override String processingFailedTitle({required Object name}) => 'Impossibile elaborare ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Il download conteneva solo ${imported} dei ${existing} record presenti su questo dispositivo, quindi quelli mancanti sono stati mantenuti. Aggiornarlo in Impostazioni › Dati Fuori Rete lo accetta comunque.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Importato ${count} record per ${label}.',
		other: 'Importati ${count} record per ${label}.',
	);
	@override String importedData({required Object label}) => 'Dati importati per ${label}.';
	@override String get cleanedUpTitle => 'Dati delle estensioni ripuliti';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Rimossi i dati di ${count} file di dati da estensioni disabilitate.',
		other: 'Rimossi i dati di ${count} file di dati da estensioni disabilitate.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} record';
	@override String get definitionUnavailable => 'La fonte del file non ha fornito una definizione — la sua estensione potrebbe essere in fase di riavvio o mal configurata. Riprova tra un momento.';
}

// Path: updates
class _Translations$updates$it extends Translations$updates$en {
	_Translations$updates$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Aggiornamento disponibile';
	@override String newVersionAvailable({required Object version}) => 'È disponibile una nuova versione (${version}).';
	@override String get getIt => 'Scaricala';
	@override String get ok => 'OK';
	@override String get updateReady => 'Aggiornamento pronto';
	@override String get restartToApply => 'È stato scaricato un aggiornamento. Riavvia per applicarlo.';
	@override String get appliesNextLaunch => 'È stato scaricato un aggiornamento. Verrà applicato la prossima volta che apri l\'app.';
	@override String get restartNow => 'Riavvia ora';
	@override String get reloadToUpdate => 'È disponibile una versione più recente di questa pagina. Ricarica per ottenerla.';
	@override String get reloadNow => 'Ricarica ora';
	@override String get checkForUpdates => 'Controlla aggiornamenti';
	@override String get checkingForUpdates => 'Controllo degli aggiornamenti…';
	@override String get upToDate => 'Aggiornato';
	@override String get automaticChecks => 'Controlla automaticamente';
	@override String get automaticChecksDescription => 'Cerca nuove versioni in background, dal prossimo avvio dell\'app';
}

// Path: extensionService
class _Translations$extensionService$it extends Translations$extensionService$en {
	_Translations$extensionService$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'L\'ambiente delle estensioni non è pronto.';
	@override String testFailed({required Object error}) => 'Prova non riuscita: ${error}';
	@override String connectedAs({required Object identity}) => 'Connesso come ${identity}';
	@override String get invalidFieldConfiguration => 'Configurazione del campo non valida';
	@override String get invalidValue => 'Valore non valido';
	@override String validationError({required Object error}) => 'Errore di validazione: ${error}';
	@override String actionFailed({required Object error}) => 'Azione non riuscita: ${error}';
	@override String get commandFailed => 'Il comando non è stato eseguito';
	@override String commandMayNotChangeSettings({required Object name}) => '${name} non può modificare le impostazioni: non l\'ha chiesto all\'installazione';
	@override String commandMayNotControlRadio({required Object name}) => '${name} non può controllare la radio: non l\'ha chiesto all\'installazione';
	@override String commandDeveloperOnly({required Object name}) => '${name} non può eseguirlo: è uno dei comandi per sviluppatori dell\'app stessa';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => 'Al momento non è possibile inviare segnalazioni';
	@override String get stashUnavailable => 'L\'Archivio File di Ham2K non è raggiungibile al momento';
	@override String activitySearchSourcesFailed({required Object names}) => 'Nessuna risposta da ${names} alla ricerca delle attività, quindi alcuni risultati potrebbero mancare.';
	@override String get activitySearchSomeSourcesFailed => 'Alcune estensioni di attività non hanno risposto alla ricerca, quindi alcuni risultati potrebbero mancare.';
	@override String timersSuspendedBudget({required Object name}) => '${name} ha impiegato troppo tempo nei suoi timer. Sono fermi finché le estensioni non si riavviano.';
	@override String timersSuspendedFailures({required Object name}) => 'I timer di ${name} continuavano a fallire. Sono fermi finché le estensioni non si riavviano.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} si è bloccata in un timer. I suoi timer sono fermi finché le estensioni non si riavviano.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$it extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Posizione dell\'Operazione';
	@override String get selectedLocation => 'Posizione Selezionata';
	@override String get gridSquare => 'Locatore del quadrato della griglia di Maidenhead';
	@override String get gridInvalid => 'Servono 4, 6, 8 o 10 caratteri, come FN31pr';
	@override String get suggestedLocations => 'Posizioni Suggerite';
	@override String get deviceGps => 'GPS Dispositivo';
	@override String peerGps({required Object device}) => 'GPS da ${device}';
	@override String get locating => 'Localizzazione…';
	@override String get gpsUnavailable => 'Posizione non disponibile';
	@override String get permissionDenied => 'Permesso di posizione negato';
	@override String get permissionBlocked => 'Permesso di posizione bloccato';
	@override String get moreDetails => 'Altri dettagli';
	@override String get stateOrProvince => 'Stato o Provincia (opzionale)';
	@override String get controlsUnavailableTitle => 'Controlli attività non disponibili';
	@override String get controlsUnavailableReason => 'Queste referenze sono ancora utilizzabili; semplicemente non è stato possibile raggiungere le loro attività.';
	@override String get controlsUnavailableRetry => 'Riprova';
	@override String get county => 'Contea (opzionale)';
}

// Path: versionLabel
class _Translations$versionLabel$it extends Translations$versionLabel$en {
	_Translations$versionLabel$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versione ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$it extends Translations$notices$en {
	_Translations$notices$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Ancora nessun avviso';
	@override String get webStorageInMemory => 'Questo browser non ha potuto fornire un archivio persistente — il log è solo in memoria e andrà PERSO alla chiusura di questa scheda. Usa una versione recente di Chrome, Firefox, Safari o Edge.';
	@override String get webStorageUnreliable => 'Questo browser usa un archivio di riserva che non è sicuro con più schede — tieni aperta una sola scheda e lascia attiva la sincronizzazione.';
	@override String get logFromNewerBuildTitle => 'Questo log richiede una versione più recente';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Il tuo log è stato scritto da una versione più recente di HaLo (versione di archiviazione ${storage}; questa comprende la ${understood}), quindi non può essere aperto e i nuovi contatti non verranno salvati. Reinstalla la versione più recente — oppure, se intendevi usare questa build, indicale una cartella dei dati diversa. Il log si trova in ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Il tuo log è stato scritto da una versione più recente di HaLo (versione di archiviazione ${storage}; questa comprende la ${understood}), quindi non può essere aperto e i nuovi contatti non verranno salvati. Apri invece questo log con quella versione più recente.';
	@override String get preferencesRestoredTitle => 'Impostazioni ripristinate da un backup';
	@override String get preferencesRestored => 'Il file delle impostazioni non era leggibile, quindi HaLo ha ripristinato la sua ultima copia valida. Le modifiche fatte nella sessione precedente potrebbero dover essere reimpostate. Il file illeggibile è conservato accanto, con il nome shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Impostazioni reimpostate';
	@override String get preferencesReset => 'Il file delle impostazioni non era leggibile e non c\'era un backup a cui ricorrere, quindi HaLo è partito con i valori predefiniti. Il file illeggibile è conservato nella cartella dei dati dell\'app, con il nome shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} non è stata connessa automaticamente';
	@override String autoConnectHeld({required Object name}) => 'HaLo ha smesso di rispondere l\'ultima volta che ha iniziato a connettersi a ${name}, quindi questa volta non l\'ha toccata per non rischiare che succeda di nuovo. Controlla che la radio sia accesa e il cavo collegato, poi premi Connetti su di essa nelle Impostazioni.';
}

// Path: syncAccount
class _Translations$syncAccount$it extends Translations$syncAccount$en {
	_Translations$syncAccount$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Account Anonimo (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (conferma in sospeso)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (conferma in sospeso - #${id})';
}

// Path: deepLink
class _Translations$deepLink$it extends Translations$deepLink$en {
	_Translations$deepLink$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Prima avvia un\'operazione, poi invia di nuovo quel contatto';
	@override String get waitingInOperation => 'Quel contatto è in attesa nell\'operazione dietro questa schermata';
	@override String unknownActivities({required Object refs}) => 'Questo dispositivo non ha alcuna attività per ${refs}, quindi quelle referenze sono state omesse';
	@override String activitiesUnavailable({required Object refs}) => 'Impossibile raggiungere le tue attività, quindi ${refs} è stata omessa — riprova quel link';
}

// Path: confirmDevice
class _Translations$confirmDevice$it extends Translations$confirmDevice$en {
	_Translations$confirmDevice$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Conferma un Dispositivo';
	@override String get codePrompt => 'Inserisci il codice mostrato sul dispositivo che vuole unirsi a questo account.';
	@override String get code => 'Codice';
	@override String get lookUp => 'Cerca';
	@override String get codeNotFound => 'Nessuna richiesta corrisponde a quel codice. I codici scadono dopo 10 minuti — chiedine uno nuovo all\'altro dispositivo.';
	@override String get linkExpired => 'Quel link è scaduto. Chiedi all\'altro dispositivo di mostrare un nuovo codice QR.';
	@override String areYouSure({required Object device}) => 'Collegare ${device} a questo account?';
	@override String get unnamedDevice => 'un dispositivo senza nome';
	@override String get grantWarning => 'Potrà leggere e modificare ogni operazione e QSO di questo account.';
	@override String get needsSyncTitle => 'La sincronizzazione non è ancora attiva su questo dispositivo';
	@override String get needsSyncText => 'Attiva la sincronizzazione Ham2K Log Filer e collega questo dispositivo a un account: solo allora potrà ammetterne un altro.';
	@override String get malformedRequest => 'Il server di sincronizzazione ha inviato una richiesta che questa app non riesce a leggere. Chiedi all\'altro dispositivo di riprovare.';
	@override String get linkIt => 'Collega Dispositivo';
}

// Path: switchAccounts
class _Translations$switchAccounts$it extends Translations$switchAccounts$en {
	_Translations$switchAccounts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Ancora nessun dettaglio dell\'account';
	@override String get currentAccount => 'Account attuale';
	@override String get otherAccounts => 'Altri account';
	@override String get linkToAnother => 'Collega a un altro account';
	@override String get linkWithSibling => 'Collega con un\'altra app Ham2K';
	@override String get linkWithPolo => 'Collega con l\'account della versione precedente';
	@override String get linkWithSiblingDescription => 'Hai installato un\'altra app Ham2K. Collegati con l\'account usato lì.';
	@override String siblingPrompt({required Object app}) => 'Approva la richiesta in ${app}, poi torna qui.';
	@override String openSiblingAgain({required Object app}) => 'Apri di nuovo ${app}';
	@override String get siblingNoGrant => 'Non ha funzionato? Aprila di nuovo, o torna indietro e collegati in un altro modo.';
	@override String siblingOpenFailed({required Object app}) => 'Impossibile aprire ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'Il link è scaduto e ne è pronto uno nuovo — apri di nuovo ${app}.';
	@override String get tryAgain => 'Riprova';
	@override String get linkWithQr => 'Collega con un codice QR';
	@override String get linkWithQrDescription => 'Scansionalo da un dispositivo che usa già l\'account';
	@override String get linkWithEmail => 'Collega con un indirizzo email';
	@override String get linkWithEmailDescription => 'Conferma con un codice o un link via email';
	@override String get enterEmailPrompt => 'Inserisci l\'indirizzo email dell\'account che vuoi far usare a questo dispositivo.';
	@override String get emailAddress => 'Indirizzo email';
	@override String get linkAccount => 'Collega account';
	@override String get copiedCode => 'Codice copiato negli appunti';
	@override String get copyCode => 'Copia codice';
	@override String codePrompt({required Object email}) => 'Apri l\'app Ham2K su un dispositivo già collegato con ${email} e inserisci questo codice per approvare la richiesta:';
	@override String get waitingForConfirmation => 'In attesa di conferma…';
	@override String get sendEmailInstead => 'Invia invece un\'email di conferma';
	@override String emailSent({required Object email}) => 'È stata inviata un\'email a ${email}. Aprila e conferma la richiesta per collegare questo dispositivo.';
	@override String get resendEmail => 'Invia di nuovo l\'email';
	@override String get qrPrompt => 'Scansiona questo codice QR da un dispositivo già collegato all\'account che vuoi — ad esempio con Ham2K Portable Logger sul tuo telefono.';
	@override String get serverUnreachable => 'Impossibile raggiungere il server di sincronizzazione. Riprova più tardi.';
	@override String get emailRequired => 'Inserisci un indirizzo email da collegare.';
	@override String noAccountForEmail({required Object email}) => 'Nessun account trovato per ${email}.';
	@override String serverRejected({required Object error}) => 'Il server di sincronizzazione ha rifiutato la richiesta: ${error}';
	@override String get noLinkCode => 'Il server di sincronizzazione non ha restituito un codice di collegamento. Riprova più tardi.';
	@override String get noConfirmationCode => 'Il server di sincronizzazione non ha inviato un codice di conferma. Riprova più tardi.';
	@override String get switchNotAccepted => 'Quell\'account non ha accettato il cambio. Prova invece a collegarlo con un indirizzo email.';
	@override String get requestFailed => 'Qualcosa è andato storto nella comunicazione con il server di sincronizzazione. Riprova più tardi.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} QSO',
		other: '${count} QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} operazione',
		other: '${count} operazioni',
	);
}

// Path: qsonImport
class _Translations$qsonImport$it extends Translations$qsonImport$en {
	_Translations$qsonImport$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa operazione QSON';
	@override String get description => 'Crea una nuova operazione da un file QSON, come quelli che la Modalità Sviluppatore esporta qui o in PoLo.';
	@override String get dropHint => 'Trascina qui un file QSON per importarlo come nuova operazione';
	@override String importing({required Object filename}) => 'Importazione di ${filename}…';
	@override String failed({required Object filename, required Object error}) => 'Impossibile importare ${filename}: ${error}';
	@override String pickerFailed({required Object error}) => 'Impossibile aprire un file da importare: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} non è testo UTF-8, quindi non è un file QSON';
	@override String notJson({required Object filename}) => '${filename} non è un file JSON, quindi non è un file QSON';
	@override String notOperation({required Object filename}) => '${filename} non contiene un\'operazione QSON';
	@override String get busy => 'È già in corso un\'importazione. Attendi che finisca prima di avviarne un\'altra.';
	@override String get oneFileOnly => 'Trascina un file QSON alla volta — ognuno diventa un\'operazione a sé.';
}

// Path: adifImport
class _Translations$adifImport$it extends Translations$adifImport$en {
	_Translations$adifImport$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa QSO da ADIF';
	@override String reading({required Object filename}) => 'Lettura di ${filename}…';
	@override String get dropHint => 'Trascina qui un file ADIF da importare';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} QSO in questo file',
		other: '${formatted} QSO in questo file',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} già nel tuo log',
		other: '${formatted} già nel tuo log',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} verrà importato',
		other: '${formatted} verranno importati',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} nuovo contatto',
		other: '${formatted} nuovi contatti',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} verrà unito a un contatto esistente',
		other: '${formatted} verranno uniti a contatti esistenti',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} non può essere importato (nessun nominativo)',
		other: '${formatted} non possono essere importati (nessun nominativo)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} richiede un controllo più attento',
		other: '${formatted} richiedono un controllo più attento',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Impossibile recuperare le referenze per ${count} contatto',
		other: 'Impossibile recuperare le referenze per ${formatted} contatti',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Le referenze ${programs} potrebbero essere incomplete per ${count} contatto',
		other: 'Le referenze ${programs} potrebbero essere incomplete per ${formatted} contatti',
	);
	@override String get stackingTypesUnknown => 'I contatti combinati potrebbero perdere una referenza — le attività non hanno potuto indicare quali tipi si sommano. Annulla e riprova per evitarlo.';
	@override String get nothingToImport => 'Non c\'è niente da importare in questo file';
	@override String get confirm => 'Importa';
	@override String importing({required Object filename}) => 'Importazione di ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Importato ${count} contatto da ${filename}',
		other: 'Importati ${formatted} contatti da ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Impossibile importare ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} non sembra un file ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Attenzione: questo ADIF contiene QSO di ${calls}, ma se continui verranno importati come ${station}.';
	@override String get stationCallJoin => ' e ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} non ha data e non può essere importato',
		other: '${formatted} non hanno data e non possono essere importati',
	);
	@override String activationFound({required Object refs}) => 'Questo file registra un\'attivazione di ${refs}.';
	@override String get addActivation => 'Aggiungila a questa operazione';
	@override String shortfall({required Object written, required Object planned}) => 'Solo ${written} su ${planned} sono stati applicati — il log è cambiato mentre decidevi.';
	@override String get busy => 'È già in corso un\'importazione. Attendi che finisca prima di avviarne un\'altra.';
	@override String get oneFileOnly => 'Trascina un file ADIF alla volta — l\'ordine in cui i file vengono importati decide quali dati prevalgono.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} ha più di ${limit} QSO, il massimo che un\'operazione può importare alla volta.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename} ha più di ${limit} QSO. L\'importazione di un ADIF in un\'operazione serve ad aggiungere pochi QSO, non a caricare un log intero — per quello usa la vista Log. La modalità sviluppatore permette comunque di importarlo, se sei sicuro.';
	@override String get importAnyway => 'Importa comunque';
}

// Path: offline
class _Translations$offline$it extends Translations$offline$en {
	_Translations$offline$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: connesso';
	@override String get noRoute => 'Nessuna connessione di rete.';
	@override String get unreachable => 'La rete è attiva, ma nessun server risponde — spesso è una pagina di accesso rimasta in attesa in un browser.';
	@override String get reachable => 'Tutti i servizi rispondono come previsto.';
	@override String get whatStops => 'Ricerche, spot e file di dati sono in pausa. Il logging e la sincronizzazione tra dispositivi peer no.';
	@override String get servicesTitle => 'Servizi';
	@override String get noServices => 'Nessun servizio ha ancora risposto.';
	@override String lastSuccess({required Object when}) => 'Ultima risposta ${when} fa';
	@override String get neverSucceeded => 'Non ha ancora risposto';
	@override String nextAttempt({required Object when}) => 'Prossimo tentativo tra ${when}';
	@override String get nextAttemptNow => 'Prossimo tentativo imminente';
	@override String get retry => 'Riprova ora';
	@override String get retrying => 'Tentativo in corso…';
	@override String get retryReached => 'Di nuovo online.';
	@override String get retryUnreachable => 'Ancora nessuna risposta.';
	@override String get retryNotAttempted => 'Niente da inviare al momento.';
	@override String get retryThrottled => 'Appena tentato — attendi un momento.';
	@override String get retryDisabled => 'La sincronizzazione è disattivata, quindi non c\'è nulla con cui verificare.';
	@override String get syncService => 'Sincronizzazione Ham2K LoFi';
	@override String get retryInFlight => 'Tentativo già in corso — attendi.';
}

// Path: exportSettings
class _Translations$exportSettings$it extends Translations$exportSettings$en {
	_Translations$exportSettings$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Impostazioni di base per tutte le esportazioni, con modelli separati di nome file e titolo per le attività con referenze e le altre attività. Ogni tipo di esportazione può fornire i propri valori predefiniti o impostazioni personalizzate.';
	@override String get referenceActivities => 'Attività con referenze';
	@override String get otherActivities => 'Altre attività';
	@override String get adifFields => 'Campi ADIF';
	@override String get loadFailed => 'Impossibile caricare le impostazioni di esportazione.';
	@override String get retry => 'Riprova';
	@override String get compactFileNamesDescriptionOn => 'Nomi di file compatti, come N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Nomi di file descrittivi, come 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Include nomi, indirizzi, email, note e posizioni precise nei file ADIF.';
	@override String get includePrivateDataDescriptionOff => 'Omette nomi, indirizzi, email e note; limita le posizioni a locatori di sei caratteri.';
	@override String get includeLookupDataDescriptionOn => 'Include le informazioni dei servizi di ricerca nominativi.';
	@override String get includeLookupDataDescriptionOff => 'Omette le informazioni dei servizi di ricerca nominativi; mantiene i valori inseriti manualmente.';
	@override String get customTemplatesDescriptionOn => 'I tuoi modelli personalizzati sono attivi e possono essere modificati qui sotto.';
	@override String get customTemplatesDescriptionOff => 'Sono attivi i modelli predefiniti. I tuoi modelli personalizzati vengono conservati per dopo.';
	@override String get type => 'Tipo di esportazione';
	@override String get defaults => 'Predefiniti';
	@override String get includeLookupData => 'Includi dati di ricerca';
	@override String get customTemplates => 'Modelli personalizzati';
	@override String get filenameTemplate => 'Modello del nome file';
	@override String get compactFilenameTemplate => 'Modello del nome file compatto';
	@override String get titleTemplate => 'Modello del titolo';
	@override String get adifNotesTemplate => 'Note ADIF QSO';
	@override String get adifCommentTemplate => 'Commenti ADIF QSO';
	@override String get adifQslMessageTemplate => 'Messaggio QSL ADIF';
	@override String get shared => 'Le impostazioni si applicano a ogni estensione che usa questo tipo di esportazione.';
	@override String get defaultTemplates => 'Attiva Modelli personalizzati per modificare i modelli di questo tipo.';
}

// Path: templateEditor
class _Translations$templateEditor$it extends Translations$templateEditor$en {
	_Translations$templateEditor$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Anteprima:';
	@override String get reset => 'Ripristina';
	@override String get docs => 'Documentazione dei modelli';
	@override String get preview => 'Anteprima di esempio';
	@override String get reference => 'Riferimento dei modelli';
	@override String get attributes => 'Attributi disponibili';
	@override String get filters => 'Filtri';
	@override String get flowControl => 'Controllo di flusso';
	@override String get unavailable => 'L\'anteprima non è disponibile finché le estensioni non sono pronte.';
	@override String get empty => '(output vuoto)';
}

// Path: home.nav
class _Translations$home$nav$it extends Translations$home$nav$en {
	_Translations$home$nav$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operazioni';
	@override String get chase => 'Caccia';
	@override String get logs => 'Log';
	@override String get maps => 'Mappe';
	@override String get settings => 'Impostazioni';
}

// Path: home.panels
class _Translations$home$panels$it extends Translations$home$panels$en {
	_Translations$home$panels$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Elenco delle operazioni';
	@override String get operationsDescription => 'Le tue operazioni, dalla più recente.';
	@override String get version => 'Versione attuale';
	@override String get versionDescription => 'Il marchio Ham2K, il nome di questa app e la build in esecuzione.';
}

// Path: home.logs
class _Translations$home$logs$it extends Translations$home$logs$en {
	_Translations$home$logs$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Log';
	@override String get titleFor => 'Log per';
	@override String get emptyCallsigns => 'Ancora nessun QSO registrato';
	@override String emptyQsos({required Object call}) => 'Nessun QSO per ${call}';
	@override String get mapNoSelection => 'Seleziona un QSO per vederlo sulla mappa';
	@override String get searchHint => 'Cerca nominativo o nome';
	@override String get noSearchMatches => 'Nessun QSO corrisponde alla ricerca';
	@override String get titleAll => 'Tutti i log';
	@override String get allCallsigns => 'Tutti i nominativi';
	@override String get noOperation => 'Non fa parte di un\'operazione';
	@override String get unsavedTitle => 'Modifiche non salvate';
	@override String get unsavedBody => 'Questo QSO ha modifiche che non hai salvato.';
	@override String get pendingDeleteBody => 'Questo QSO è contrassegnato per l\'eliminazione.';
	@override String get editGone => 'Non salvato: quel QSO non è più in questo log.';
	@override String get discard => 'Scarta';
	@override late final _Translations$home$logs$sheet$it sheet = _Translations$home$logs$sheet$it._(_root);
	@override late final _Translations$home$logs$groupBy$it groupBy = _Translations$home$logs$groupBy$it._(_root);
	@override late final _Translations$home$logs$period$it period = _Translations$home$logs$period$it._(_root);
	@override late final _Translations$home$logs$periodTitle$it periodTitle = _Translations$home$logs$periodTitle$it._(_root);
	@override late final _Translations$home$logs$columns$it columns = _Translations$home$logs$columns$it._(_root);
	@override late final _Translations$home$logs$panels$it panels = _Translations$home$logs$panels$it._(_root);
	@override late final _Translations$home$logs$import$it import = _Translations$home$logs$import$it._(_root);
}

// Path: chase.station
class _Translations$chase$station$it extends Translations$chase$station$en {
	_Translations$chase$station$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stazione di caccia';
	@override String get stationLabel => 'Stazione: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Nessuna posizione';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$it extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get today => 'oggi';
	@override String get thisWeek => 'questa settimana';
	@override String get last14Days => 'negli ultimi 14 giorni';
	@override String get thisMonth => 'questo mese';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$it extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistiche di oggi';
	@override String get thisWeek => 'Statistiche di questa settimana';
	@override String get last14Days => 'Statistiche degli ultimi 14 giorni';
	@override String get thisMonth => 'Statistiche di questo mese';
}

// Path: chase.period
class _Translations$chase$period$it extends Translations$chase$period$en {
	_Translations$chase$period$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get today => 'Oggi';
	@override String get thisWeek => 'Questa settimana';
	@override String get last14Days => 'Ultimi 14 giorni';
	@override String get thisMonth => 'Questo mese';
}

// Path: chase.goals
class _Translations$chase$goals$it extends Translations$chase$goals$en {
	_Translations$chase$goals$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Obiettivi di caccia';
	@override String remove({required Object name}) => 'Smetti di cacciare ${name}';
	@override String get extensionsTitle => 'Altri programmi di caccia';
}

// Path: chase.panels
class _Translations$chase$panels$it extends Translations$chase$panels$en {
	_Translations$chase$panels$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => 'Controlli di logging sopra i QSO cacciati nel periodo.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Il nominativo in fase di registrazione, o le statistiche del periodo.';
	@override String get spots => 'Spot';
	@override String get spotsDescription => 'Stazioni spottate on the air, pronte da cacciare.';
	@override String get map => 'Mappa';
	@override String get mapDescription => 'I QSO del periodo e la stazione in fase di registrazione.';
}

// Path: chase.claims
class _Translations$chase$claims$it extends Translations$chase$claims$en {
	_Translations$chase$claims$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get checking => 'Verifica dei QSO per la caccia';
	@override String rebuilding({required Object program}) => 'Verifica del log per ${program}';
	@override String progress({required Object done, required Object total}) => '${done} di ${total} QSO';
}

// Path: chase.notice
class _Translations$chase$notice$it extends Translations$chase$notice$en {
	_Translations$chase$notice$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'Nuovo ${program}';
	@override String newRefGuess({required Object program}) => 'Probabilmente nuovo ${program}';
	@override String newBand({required Object program}) => 'Nuova banda ${program}';
	@override String newBandGuess({required Object program}) => 'Probabilmente nuova banda ${program}';
	@override String newMode({required Object program}) => 'Nuovo modo ${program}';
	@override String newModeGuess({required Object program}) => 'Probabilmente nuovo modo ${program}';
	@override String unconfirmed({required Object program}) => '${program} non confermato';
	@override String programGuess({required Object notice}) => 'Probabilmente ${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$it extends Translations$chase$alerts$en {
	_Translations$chase$alerts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Avvisi';
	@override String get newRef => 'Nuova referenza';
	@override String get newBand => 'Nuova banda';
	@override String get newMode => 'Nuovo modo';
	@override String get unconfirmed => 'Non confermato';
}

// Path: chase.imports
class _Translations$chase$imports$it extends Translations$chase$imports$en {
	_Translations$chase$imports$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'Importa ${label}';
	@override String pickTitle({required Object file}) => 'Importa ${file} come';
	@override String get dropHint => 'Trascina qui un file per importarlo in un programma di caccia';
	@override String done({required Object count, required Object program, required Object file}) => 'Importate ${count} voci ${program} da ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'Importate ${count} voci ${program} da ${file}, saltate ${skipped} non leggibili';
	@override String nothing({required Object file, required Object program}) => '${file} non contiene nulla che ${program} possa importare';
	@override String failed({required Object program, required Object file}) => '${program} non è riuscito a leggere ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} non è riuscito a leggere nessuno dei ${skipped} record in ${file}';
	@override String noProgram({required Object file}) => 'Nessun programma di caccia importa ${file}';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$it extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cercare online?';
	@override String get body => 'L\'assistenza è disattivata per questa operazione. La ricerca di tutti i QSO userà servizi online come QRZ solo per questa volta.';
	@override String bodyRules({required Object rules}) => 'L\'assistenza è disattivata per questa operazione, per rispettare il regolamento ${rules}. La ricerca di tutti i QSO userà servizi online come QRZ solo per questa volta.';
	@override String get action => 'Cerca Online';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$it extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Nominativo non valido: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Nominativi non validi: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Finora ha operato ${previous}. ${typed} verrà registrato per i nuovi contatti.';
	@override String operatorNoneSoFar({required Object typed}) => 'Finora nessun operatore registrato. ${typed} verrà registrato per i nuovi contatti.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Questa operazione ha già contatti di ${calls}. ${typed} verrà registrato solo per i nuovi.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Registra ${typed} come operatore anche del contatto già registrato',
		other: 'Registra ${typed} come operatore anche di tutti i ${count} contatti già registrati',
	);
	@override String get operatorSeveralStations => 'Quando si usano più stazioni on the air, non sono supportati operatori separati';
	@override String get contactsUnreadable => 'Impossibile leggere i contatti di questa operazione, quindi cambiare qui un nominativo non proporrà di aggiornarli';
	@override String restampFailed({required Object error}) => 'Impossibile aggiornare i contatti già registrati, quindi non è stata fatta alcuna modifica: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} contatti su ${planned} sono stati aggiornati — gli altri non sono più in questa operazione';
}

// Path: operation.tabs
class _Translations$operation$tabs$it extends Translations$operation$tabs$en {
	_Translations$operation$tabs$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => 'INFO';
	@override String get spots => 'SPOT';
	@override String get map => 'MAPPA';
	@override String get qsosPlain => 'QSO';
	@override String get clock => 'Orologio';
	@override String get weather => 'Meteo';
	@override String get website => 'Sito Web';
	@override String get remoteScreen => 'Schermo Remoto';
	@override String get solar => 'Solare';
	@override String get radio => 'Radio';
	@override String get rotator => 'Rotore';
	@override String get summaries => 'Riepiloghi Operazione';
}

// Path: operation.positions
class _Translations$operation$positions$it extends Translations$operation$positions$en {
	_Translations$operation$positions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Nessun\'altra postazione operativa condivide ancora questa operazione.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Un\'altra postazione';
	@override String get thisDevice => 'La nostra postazione operativa';
	@override String get nameIn => ' in ';
	@override String get panelTitle => 'Postazioni';
	@override String get panelDescription => 'Cosa sta registrando in questo momento ogni postazione operativa che condivide questa operazione.';
}

// Path: operation.menu
class _Translations$operation$menu$it extends Translations$operation$menu$en {
	_Translations$operation$menu$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostra campi RST';
	@override String get showStateField => 'Mostra campo Stato';
	@override String get showGridField => 'Mostra campo Locatore';
	@override String get showDeletedQsos => 'Mostra QSO eliminati';
	@override String get showDeletedOps => 'Mostra operazioni eliminate';
	@override String get showQsoNumbers => 'Mostra numeri QSO';
	@override String get lookupAllQsos => 'Cerca tutti i QSO';
	@override String get loggingSettingsTitle => 'Impostazioni di Logging';
	@override String get mapSettingsTitle => 'Impostazioni Mappa';
	@override String get actionsSection => 'Azioni';
}

// Path: operation.layout
class _Translations$operation$layout$it extends Translations$operation$layout$en {
	_Translations$operation$layout$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggiungi un Pannello';
	@override String get availableSection => 'Pannelli disponibili';
	@override String panelSettings({required Object panel}) => 'Impostazioni di ${panel}';
	@override String get panelSettingsAction => 'Impostazioni Pannello';
	@override String get viewName => 'Vista Operazione';
	@override String get viewOptions => 'Opzioni di layout della vista';
	@override String get viewTitleBuiltIn => 'Questa vista è integrata nell\'app, così come il suo nome';
	@override String get resetOptions => 'Ripristina Predefiniti';
	@override String get removePane => 'Rimuovi';
	@override String resetPaneConfirm({required Object panel}) => 'Ripristinare ${panel} ai valori predefiniti?';
	@override String get resetPaneConfirmBody => 'Titolo, intestazione e dimensione tornano ai valori predefiniti. Il resto del layout rimane com\'è.';
	@override String get resetViewConfirm => 'Ripristinare il layout predefinito di questa vista?';
	@override String get resetViewConfirmBody => 'I pannelli tornano alla disposizione predefinita, e le opzioni della vista e di ogni pannello tornano ai valori predefiniti.';
	@override String paneOptionsTitle({required Object panel}) => 'Impostazioni di layout di ${panel}';
	@override String get paneTitle => 'Titolo';
	@override String get paneShowHeader => 'Mostra intestazione';
	@override String get paneShowHeaderTabset => 'Sempre visibile finché questo riquadro condivide un gruppo — l\'intestazione è il modo per raggiungere gli altri';
	@override String get paneInherit => 'Come l\'app';
	@override String get searchHint => 'Cerca pannelli';
	@override String get noPanelsMatch => 'Nessun pannello corrisponde alla ricerca.';
	@override String get nothingToAdd => 'Questa vista ha già tutti i pannelli possibili';
	@override String addPanel({required Object panel}) => 'Aggiungi ${panel}';
	@override String showPreview({required Object panel}) => 'Anteprima di ${panel}';
	@override String missingExtension({required Object name}) => 'Manca l\'estensione "${name}"';
	@override String get missingExtensionEnable => 'Abilita';
	@override String get missingExtensionInstall => 'Installa…';
	@override String get missingExtensionWontRun => 'Questa versione non si avvia. Aggiornala in Impostazioni › Estensioni.';
	@override String get missingExtensionUnavailable => 'Non disponibile in questa app';
	@override String get missingExtensionNotInCatalog => 'Non presente nel catalogo';
	@override String get missingExtensionCatalogUnreachable => 'Impossibile raggiungere il catalogo. Riprova';
	@override String get missingExtensionFailed => 'Non ha funzionato. Riprova';
	@override String get previewUnavailable => 'Impossibile mostrare l\'immagine di anteprima di questo pannello.';
	@override String get nestedPaneTitle => 'Altro';
	@override late final _Translations$operation$layout$layouts$it layouts = _Translations$operation$layout$layouts$it._(_root);
	@override String get editLayout => 'Modifica Layout';
	@override String get saveLayout => 'Salva Layout';
	@override String get revertLayout => 'Scarta le modifiche al layout';
	@override String get done => 'Fatto';
	@override String get layoutUnreadableTitle => 'Impossibile leggere il layout';
	@override String get layoutUnreadableBody => 'Il layout salvato non è leggibile, quindi viene mostrata la disposizione predefinita. Non sovrascriverà l\'originale finché non scegli di mantenerla.';
	@override String get layoutUnreadableAction => 'Usa questo layout';
	@override String panelRenderFailed({required Object panel}) => 'Impossibile visualizzare ${panel}';
	@override String panelOverCharacters({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: ha inviato più di ${max} caratteri';
	@override String panelOverElements({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua grafica ha più di ${max} elementi';
	@override String panelOverDepth({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua grafica è annidata a più di ${max} livelli di profondità';
	@override String panelNotArtwork({required Object panel}) => 'Impossibile visualizzare ${panel}: la sua grafica non è autonoma';
	@override String panelOverLayers({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua scena ha più di ${max} livelli';
	@override String panelOverControls({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua scena ha più di ${max} controlli';
	@override String panelOverItems({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: una parte della sua scena ha più di ${max} voci';
	@override String panelOverStringLength({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: una stringa della scena supera i ${max} caratteri';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: il suo layout è annidato a più di ${max} livelli di profondità';
	@override String get panelRenderRetry => 'Riprova';
	@override String get panelActionFailed => 'L\'azione del pannello non è riuscita. Riprova.';
	@override late final _Translations$operation$layout$panels$it panels = _Translations$operation$layout$panels$it._(_root);
	@override String get htmlPanelUnsupported => 'Questo pannello richiede una web view, che questa piattaforma non fornisce';
	@override String get htmlPanelUnsupportedOnWeb => 'Questo pannello richiede una sandbox che la versione web non può fornire';
}

// Path: operation.export
class _Translations$operation$export$it extends Translations$operation$export$en {
	_Translations$operation$export$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esportazioni dell\'operazione';
	@override String get syncedOperation => 'L\'operazione è sincronizzata';
	@override String get unsyncedOperation => 'L\'operazione ha modifiche non sincronizzate';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} QSO in questa operazione',
		other: '${count} QSO in questa operazione',
	);
	@override String qsosSynced({required Object total}) => 'Tutti i ${total} QSO sono sincronizzati';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} QSO su ${total} in attesa di sincronizzazione';
	@override String eventsSynced({required Object total}) => '${total} marcatori di evento sincronizzati';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} marcatori di evento su ${total} in attesa';
	@override String get loading => 'Caricamento delle opzioni di esportazione…';
	@override String get noOptions => 'Nessun formato di esportazione disponibile (le estensioni si stanno ancora avviando?)';
	@override String get nothingLogged => 'Ancora niente da esportare — questa operazione non ha QSO.';
	@override String get share => 'Condividi';
	@override String get nothingSelected => 'Nessuna selezione';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Salva ${count} file',
		other: 'Salva ${count} file',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Condividi ${count} file',
		other: 'Condividi ${count} file',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Esporta ${count} file',
		other: 'Esporta ${count} file',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Scarica ${count} file',
		other: 'Scarica ${count} file',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Salva ${count} file combinato',
		other: 'Salva ${count} file combinati',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Condividi ${count} file combinato',
		other: 'Condividi ${count} file combinati',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Esporta ${count} file combinato',
		other: 'Esporta ${count} file combinati',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Scarica ${count} file combinato',
		other: 'Scarica ${count} file combinati',
	);
	@override String saveOne({required Object name}) => 'Salva ${name}';
	@override String shareOne({required Object name}) => 'Condividi ${name}';
	@override String exportOne({required Object name}) => 'Esporta ${name}';
	@override String downloadOne({required Object name}) => 'Scarica ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Archivia ${count} file',
		other: 'Archivia ${count} file',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Archivia ${count} file combinato',
		other: 'Archivia ${count} file combinati',
	);
	@override String get settingsButton => 'Impostazioni di esportazione';
	@override String get settingsTitle => 'Impostazioni di Esportazione';
	@override late final _Translations$operation$export$compactFileNames$it compactFileNames = _Translations$operation$export$compactFileNames$it._(_root);
	@override late final _Translations$operation$export$includePrivateData$it includePrivateData = _Translations$operation$export$includePrivateData$it._(_root);
	@override String get resultTitle => 'Esportazione completata';
	@override String get resultFailedTitle => 'Esportazione non riuscita';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Esportato ${count} file in ${path}',
		other: 'Esportati ${count} file in ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Esportato ${count} file: ${path}',
		other: 'Esportati ${count} file: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Condiviso ${count} file',
		other: 'Condivisi ${count} file',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Scaricato ${count} file',
		other: 'Scaricati ${count} file',
	);
	@override String exportFailed({required Object error}) => 'Esportazione non riuscita: ${error}';
	@override late final _Translations$operation$export$stash$it stash = _Translations$operation$export$stash$it._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$it extends Translations$operation$spots$en {
	_Translations$operation$spots$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nessuno spot corrisponde ai filtri';
	@override String error({required Object error}) => 'Impossibile caricare gli spot: ${error}';
	@override String get unknownBand => 'Altro';
	@override String get auto => 'Automatico';
	@override String autoValue({required Object value}) => 'Automatico (Attualmente ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Qualsiasi';
	@override String get allBands => 'Tutte le Bande';
	@override String get allModes => 'Tutti i Modi';
	@override String get phoneAndCw => 'Fonia e CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} spot',
		other: '${count} spot',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => '${count} spot visualizzati su ${total}';
	@override String get spotsDisabled => 'Spot disattivati per questa operazione';
	@override String ageMinutes({required Object minutes}) => '${minutes} minuti';
	@override String get callsOfNote => 'Nominativi di rilievo';
	@override String get yourSpots => 'I tuoi Spot';
	@override String get allSpots => 'Tutti gli Spot';
	@override late final _Translations$operation$spots$continents$it continents = _Translations$operation$spots$continents$it._(_root);
	@override late final _Translations$operation$spots$filters$it filters = _Translations$operation$spots$filters$it._(_root);
	@override String get unavailableTitle => 'Spot non disponibili';
	@override String unavailableText({required Object sources}) => '${sources} non ha risposto.';
	@override String get failedTitle => 'Errore della fonte spot';
	@override String failedText({required Object sources}) => '${sources} ha restituito un errore.';
	@override String get slideLogIt => 'Registra';
	@override String get slideIgnore => 'Ignora';
	@override String get slideRestore => 'Ripristina';
	@override late final _Translations$operation$spots$logConflict$it logConflict = _Translations$operation$spots$logConflict$it._(_root);
}

// Path: operation.import
class _Translations$operation$import$it extends Translations$operation$import$en {
	_Translations$operation$import$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importa Dati nell\'Operazione';
	@override String get importAdifAction => 'Importa QSO da ADIF';
	@override String get settingsButton => 'Impostazioni di ascolto';
	@override String get settingsTitle => 'Ascolta altre app';
	@override String get protocolAddressLabel => 'Indirizzo';
	@override String get protocolPortLabel => 'Porta';
	@override String get protocolPortInvalid => 'Inserisci una porta tra 1 e 65535';
	@override String get protocolAddressInvalid => 'Inserisci un indirizzo IP valido (es. 127.0.0.1 o 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Ricezione dati';
	@override String get protocolStatusNoData => 'Nessun dato ricevuto di recente';
	@override String protocolBindError({required Object error}) => 'Impossibile avviare l\'ascolto: ${error}';
	@override String captureFailed({required Object error}) => 'Impossibile salvare i QSO in arrivo, nuovo tentativo in corso: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Qualsiasi (broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → scheda Broadcast Data → seleziona "Enable Broadcasts" per i contatti. Imposta l\'indirizzo IP a 127.0.0.1 se in esecuzione su questo stesso computer, o 255.255.255.255 per trasmettere in broadcast sulla rete locale attuale.';
	@override String get helpWsjtxSetup => 'File → Settings → scheda Reporting → sezione UDP Server → seleziona "Accept UDP requests". Imposta UDP Server a 127.0.0.1 se in esecuzione su questo stesso computer, o un indirizzo multicast come 239.239.0.2, e usa lo stesso indirizzo nella configurazione qui sopra in questa app.';
	@override String get listenTitle => 'Ascolta i QSO da altre app';
	@override String get listenDescriptionOnN1mm => 'In ascolto di N1MM+';
	@override String get listenDescriptionOnWsjtx => 'In ascolto di WSJT-X';
	@override String get listenDescriptionOnBoth => 'In ascolto di N1MM+ e WSJT-X';
	@override String get listenDescriptionOff => 'Disattivato';
	@override String get addToOperationTitle => 'Aggiungi a questa operazione';
	@override String get addToOperationDescriptionOn => 'I QSO catturati vengono aggiunti a questa operazione appena arrivano';
	@override String get addToOperationDescriptionOff => 'I QSO catturati vengono trattenuti finché non attivi questa opzione';
	@override String get pendingSectionTitle => 'QSO catturati';
	@override String get pendingEmpty => 'Ancora nessuna cattura';
	@override String stationMismatch({required Object call}) => 'Registrato come ${call}, non la stazione di questa operazione';
	@override String get discardAction => 'Scarta';
	@override String get gapDialogTitle => 'Includere le catture precedenti?';
	@override String gapDialogBody({required Object count}) => 'Altri ${count} QSO erano stati catturati in precedenza, prima di un\'interruzione nei dati. Includere anche quelli?';
	@override String get gapDialogRecentOnly => 'Solo i recenti';
	@override String gapDialogIncludeAll({required Object count}) => 'Includi tutti i ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$it extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problemi?';
	@override String get title => 'Segnala un problema del contorno';
	@override String get reference => 'Quale contorno';
	@override String get severity => 'Quanto è grave?';
	@override String get minor => 'Dettaglio minore';
	@override String get major => 'Problema serio';
	@override String get explanation => 'Cosa c\'è che non va?';
	@override String get explanationHint => 'Cosa sbaglia il contorno, e dove';
	@override String get send => 'Invia';
	@override String get sending => 'Invio della segnalazione — grazie';
	@override String get copy => 'Copia segnalazione';
	@override String get notSent => 'Impossibile inviare la segnalazione';
	@override String get copied => 'Segnalazione copiata';
	@override String get notCopied => 'Impossibile copiare la segnalazione';
}

// Path: map.postcard
class _Translations$map$postcard$it extends Translations$map$postcard$en {
	_Translations$map$postcard$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get button => 'Cartolina dell\'Operazione';
	@override String title({required Object title}) => 'Cartolina per ${title}';
	@override String get portrait => 'Verticale';
	@override String get landscape => 'Orizzontale';
	@override String get square => 'Quadrata';
	@override String get save => 'Salva…';
	@override String get download => 'Scarica';
	@override String get share => 'Condividi';
	@override String get copy => 'Copia';
	@override String get copied => 'Copiata negli appunti';
	@override String saved({required Object path}) => 'Salvata in ${path}';
	@override String downloaded({required Object name}) => 'Scaricato ${name}';
	@override String savedMany({required Object count, required Object path}) => 'Salvate ${count} immagini in ${path}';
	@override String savedFiles({required Object names}) => 'Salvati ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} erano già stati salvati';
	@override String downloadedMany({required Object count}) => 'Download di ${count} immagini — consentilo se il browser lo chiede';
	@override String get mapLeftOut => 'La mappa non si è caricata, quindi è stata omessa';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — la mappa non si è caricata, quindi è stata omessa';
	@override String continued({required Object title}) => '${title} (continua)';
	@override String get previousPage => 'Pagina precedente';
	@override String get nextPage => 'Pagina successiva';
	@override String pageOf({required Object page, required Object count}) => 'Pagina ${page} di ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} Q',
		other: '${count} Q',
	);
	@override String get options => 'Opzioni Cartolina';
	@override String get bandLegend => 'Mostra la legenda delle bande';
	@override String get grayline => 'Mostra la grayline';
	@override String get sectionsAndOrder => 'Sezioni del riepilogo e ordine';
	@override String get sectionDays => 'Ogni giorno';
	@override String get reset => 'Ripristina';
	@override String failed({required Object error}) => 'Impossibile creare la cartolina: ${error}';
	@override String get mapNotReady => 'La mappa non ha finito di caricarsi. Controlla la connessione e riprova.';
	@override String saveFailed({required Object error}) => 'Impossibile salvare la cartolina: ${error}';
	@override String get copyFailed => 'Gli appunti non hanno accettato l\'immagine. Riprova.';
	@override String get shareFailed => 'Impossibile condividere la cartolina. Riprova.';
	@override String get fileName => 'cartolina';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$it extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Ancora nessun QSO... andiamo in aria!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object count, required Object time}) => '${count} in ${time}';
	@override String sinceLast({required Object time}) => '${time} dall\'ultimo';
	@override String ratePer10({required Object rate}) => '${rate} Q/h per gli ultimi 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h per gli ultimi 100';
	@override String distanceTo({required Object distance}) => '${distance} verso';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verso';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verso';
	@override String distanceAway({required Object distance}) => '${distance} di distanza';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) di distanza';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) di distanza';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplicato!';
	@override String get noticeNewBand => 'Nuova Banda';
	@override String get noticeNewMode => 'Nuovo Modo';
	@override String get noticeNewDXCC => 'Nuovo DXCC';
	@override String get noticeNewState => 'Nuovo Stato';
	@override String get noticeNewProvince => 'Nuova Provincia';
	@override String get noticeNewDay => 'Nuovo giorno';
	@override String get noticeNewRef => 'Nuova Ref';
	@override String get noticeNewMult => 'Nuovo Molt';
	@override String get noticeNewZone => 'Nuova Zona';
	@override String get noticeInvalidMode => 'Modo errato';
	@override String get noticeInvalidBand => 'Banda errata';
	@override String get noticeInvalidCategory => 'Non collegabile';
	@override String get noticeOverTime => 'Tempo scaduto';
	@override String get noticeWorkedBefore => 'Già collegato';
	@override String get noticeNewPark => 'Nuovo Parco';
	@override String get noticeNewSection => 'Nuova Sezione';
	@override String get noticeBonusStation => 'Stazione Bonus!';
	@override String get noticeMissingExchange => 'Nessuno Scambio';
	@override String get noticeInvalidExchange => 'Scambio errato';
	@override String get noticeUnknownEvent => 'Evento sconosciuto';
	@override String get noticeIncompleteCall => 'Nominativo incompleto — Non conteggiato';
	@override String get noticeOurGrid => 'Imposta il nostro Locatore';
	@override String get noticeRareCounty => 'Contea rara!';
	@override String get noticeOurLocation => 'Imposta la nostra Contea';
	@override String get noticeShortGrid => 'Locatore troppo corto';
}

// Path: qsoList.find
class _Translations$qsoList$find$it extends Translations$qsoList$find$en {
	_Translations$qsoList$find$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'Trova nel log (${shortcut})';
	@override String get menuItemNoShortcut => 'Trova nel log';
	@override String get hint => 'Numero QSO o nominativo';
	@override String get noMatches => 'Nessun risultato';
	@override String get noOperationQsos => 'Nessun QSO in questa operazione';
	@override String get noPeriodQsos => 'Nessun QSO in questo periodo';
	@override String get outsideQsosOne => '1 QSO fuori da questa operazione';
	@override String outsideQsosOther({required Object count}) => '${count} QSO fuori da questa operazione';
	@override String get pastQsosOne => '1 QSO precedente';
	@override String pastQsosOther({required Object count}) => '${count} QSO precedenti';
}

// Path: callInfo.history
class _Translations$callInfo$history$it extends Translations$callInfo$history$en {
	_Translations$callInfo$history$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} negli ultimi 7 giorni';
	@override String today({required Object n}) => '${n} oggi';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$it extends Translations$settings$theme$en {
	_Translations$settings$theme$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tema';
	@override String get system => 'Segui le impostazioni di sistema';
	@override String get light => 'Chiaro';
	@override String get dark => 'Scuro';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$it extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get system => 'Segue le impostazioni di sistema';
	@override String get light => 'Sempre in Modalità Chiara';
	@override String get dark => 'Sempre in Modalità Scura';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$it extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Più Piccolo--';
	@override String get smallestMinus => 'Più Piccolo-';
	@override String get smallest => 'Più Piccolo';
	@override String get smaller => 'Piccolo';
	@override String get normal => 'Normale';
	@override String get larger => 'Grande';
	@override String get largest => 'Più Grande';
	@override String get largestPlus => 'Più Grande+';
	@override String get largestPlusPlus => 'Più Grande++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$it extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mantieni il dispositivo attivo';
	@override String get descriptionOn => 'Resta attivo mentre sei nella vista di logging o è in corso una sincronizzazione';
	@override String get descriptionOff => 'Va in standby come di consueto';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$it extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatica';
	@override String get densest => 'Massima';
	@override String get dense => 'Densa';
	@override String get normal => 'Normale';
	@override String get sparse => 'Ampia';
	@override String get sparsest => 'Più ampia';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$it extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Chilometri';
	@override String get miles => 'Miglia';
}

// Path: settings.logging
class _Translations$settings$logging$it extends Translations$settings$logging$en {
	_Translations$settings$logging$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logging';
	@override late final _Translations$settings$logging$leftieMode$it leftieMode = _Translations$settings$logging$leftieMode$it._(_root);
	@override late final _Translations$settings$logging$countryFlags$it countryFlags = _Translations$settings$logging$countryFlags$it._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$it countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$it._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$it suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$it._(_root);
	@override late final _Translations$settings$logging$showBearing$it showBearing = _Translations$settings$logging$showBearing$it._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$it showReverseBearing = _Translations$settings$logging$showReverseBearing$it._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$it switchSentRcvd = _Translations$settings$logging$switchSentRcvd$it._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$it jumpAfterRST = _Translations$settings$logging$jumpAfterRST$it._(_root);
	@override late final _Translations$settings$logging$defaultReport$it defaultReport = _Translations$settings$logging$defaultReport$it._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$it defaultReportCW = _Translations$settings$logging$defaultReportCW$it._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$it defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$it._(_root);
	@override late final _Translations$settings$logging$numbersRow$it numbersRow = _Translations$settings$logging$numbersRow$it._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$it numbersRowExtra = _Translations$settings$logging$numbersRowExtra$it._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$it numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$it._(_root);
	@override String get bands => 'Bande preferite';
	@override String get modes => 'Modi preferiti';
}

// Path: settings.catServer
class _Translations$settings$catServer$it extends Translations$settings$catServer$en {
	_Translations$settings$catServer$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Server CAT';
	@override String get description => 'Consenti ad altre app (WSJT-X, logger, ecc.) di controllare la radio tramite Ham2K Logger.';
	@override String get protocol => 'Protocollo';
	@override late final _Translations$settings$catServer$protocolOpts$it protocolOpts = _Translations$settings$catServer$protocolOpts$it._(_root);
	@override String get port => 'Porta';
	@override String get openAccess => 'Accesso aperto';
	@override String get openAccessOn => 'Qualsiasi computer sulla rete locale può connettersi.';
	@override String get openAccessOff => 'Solo le app su questo computer possono connettersi.';
	@override String get allowTransmit => 'Consenti alle app di trasmettere';
	@override String allowTransmitOn({required Object minutes}) => 'Le app possono attivare il PTT della radio, per un massimo di ${minutes} minuti alla volta.';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'Le app su qualsiasi computer della rete locale possono attivare il PTT della radio, per un massimo di ${minutes} minuti alla volta.';
	@override String get allowTransmitOff => 'Le app non possono mettere in trasmissione la radio. Usa il VOX o il loro PTT.';
	@override String get allowTransmitUnsupported => 'La radio del VFO principale non può essere messa in trasmissione da Ham2K Logger, quindi le app non possono trasmettere attraverso di essa.';
	@override String get off => 'Disattivato.';
	@override String starting({required Object protocol}) => '${protocol}, avvio in corso…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} sulla porta ${port}. Client connessi: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} sulla porta ${port}, ma non è connessa nessuna radio sul VFO principale.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} non può ascoltare sulla porta ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} non può ascoltare sulla porta ${port}: un altro programma la sta usando, spesso ${protocol} stesso. Chiudi quel programma o scegli un\'altra porta.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} non può ascoltare sulla porta ${port}: questo computer non lo consente. Scegli una porta superiore a 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} ha smesso di ascoltare sulla porta ${port}. Nuovo tentativo…';
}

// Path: settings.cluster
class _Translations$settings$cluster$it extends Translations$settings$cluster$en {
	_Translations$settings$cluster$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'DX Cluster';
	@override String get description => 'Il server a cui le estensioni inviano gli spot e da cui li leggono, connesse con il nominativo dell\'operatore.';
	@override String get connect => 'Connetti al cluster';
	@override String get connectOn => 'Le estensioni si connettono al cluster quando ne hanno bisogno';
	@override String get connectOff => 'Niente si connette al cluster';
	@override String get console => 'Mostra Console';
	@override String get consoleDescription => 'Ciò che il cluster invia, e un posto dove digitare comandi';
	@override String get consoleTitle => 'Console del Cluster';
	@override String get consoleConnect => 'Connetti';
	@override String get consoleDisconnect => 'Disconnetti';
	@override String get consoleCommand => 'Comando';
	@override String get consoleEmpty => 'Ancora niente. Connettiti, o aspetta che un\'estensione usi il cluster.';
	@override String consoleRetry({required Object command}) => 'Nuovo invio: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => 'Non inviato: ${command} (${reason})';
	@override String get server => 'Server del Cluster';
	@override String get selectServer => 'Seleziona Server';
	@override String get serverOther => 'Altro';
	@override String serverOtherIncomplete({required Object node}) => 'Nessun host inserito, quindi gli spot vanno a ${node}';
	@override String get customHost => 'Server';
	@override String get customPort => 'Porta';
	@override String get password => 'Password';
	@override String get passwordDescription => 'Solo se necessaria';
	@override String passwordStored({required Object node}) => 'Password memorizzata per ${node}';
	@override String get scrollback => 'Righe conservate';
	@override String scrollbackOpt({required Object count}) => '${count} righe';
	@override String get connection => 'Connessione';
	@override String get statusIdle => 'Non connesso. Si connette quando un\'estensione ne ha bisogno. Tocca per provare.';
	@override String statusConnecting({required Object node}) => 'Connessione a ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'Connesso a ${node} come ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'Impossibile connettersi a ${node}: ${reason}';
	@override String get statusUnsupported => 'Non disponibile nella versione web.';
	@override String get statusOff => 'Disattivato. Attiva Connetti al cluster per usarlo.';
	@override late final _Translations$settings$cluster$errors$it errors = _Translations$settings$cluster$errors$it._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$it extends Translations$settings$spotting$en {
	_Translations$settings$spotting$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotting';
	@override String get respotInterval => 'Re-spot automatico ogni';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'Re-spot automatico predefinito';
	@override String get autoRespotByDefaultOn => 'Attiva il re-spot automatico dopo ogni spot inviato';
	@override String get autoRespotByDefaultOff => 'Richiede un\'azione dell\'utente per attivare il re-spot automatico';
	@override String get pulseBeforeRespot => 'Pulsazione prima di ogni re-spot automatico';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'Il controllo Spotting pulsa in blu nei ${seconds} secondi prima di ogni re-spot';
	@override String get pulseBeforeRespotOff => 'Nessuna pulsazione prima di un re-spot automatico';
}

// Path: settings.radio
class _Translations$settings$radio$it extends Translations$settings$radio$en {
	_Translations$settings$radio$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controllo CAT';
	@override String get loggingAndCat => 'Logging e CAT';
	@override String get tuningSection => 'Sintonia';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Servizi';
	@override String get stationConfigurationSection => 'Configurazione Stazione';
	@override String get moreSettings => 'Altre impostazioni di configurazione della stazione';
	@override late final _Translations$settings$radio$units$it units = _Translations$settings$radio$units$it._(_root);
	@override late final _Translations$settings$radio$pttKey$it pttKey = _Translations$settings$radio$pttKey$it._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$it smartVfoSnap = _Translations$settings$radio$smartVfoSnap$it._(_root);
	@override late final _Translations$settings$radio$snapDebounce$it snapDebounce = _Translations$settings$radio$snapDebounce$it._(_root);
	@override late final _Translations$settings$radio$snapLongMove$it snapLongMove = _Translations$settings$radio$snapLongMove$it._(_root);
	@override late final _Translations$settings$radio$snapMinMove$it snapMinMove = _Translations$settings$radio$snapMinMove$it._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$it snapMinSpeed = _Translations$settings$radio$snapMinSpeed$it._(_root);
	@override late final _Translations$settings$radio$enterSends$it enterSends = _Translations$settings$radio$enterSends$it._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$it keyerSpeed = _Translations$settings$radio$keyerSpeed$it._(_root);
	@override late final _Translations$settings$radio$cwMessages$it cwMessages = _Translations$settings$radio$cwMessages$it._(_root);
	@override late final _Translations$settings$radio$keyerControl$it keyerControl = _Translations$settings$radio$keyerControl$it._(_root);
	@override late final _Translations$settings$radio$voiceMessages$it voiceMessages = _Translations$settings$radio$voiceMessages$it._(_root);
	@override late final _Translations$settings$radio$voiceWords$it voiceWords = _Translations$settings$radio$voiceWords$it._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$it avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$it._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$it zeroBeatRange = _Translations$settings$radio$zeroBeatRange$it._(_root);
}

// Path: settings.help
class _Translations$settings$help$it extends Translations$settings$help$en {
	_Translations$settings$help$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aiuto e Risorse';
	@override String get description => 'Comunità e supporto';
	@override String get forums => 'Forum Ham2K';
	@override String get forumsDescription => 'Trova aiuto, dai feedback, discuti idee…';
	@override String get chat => 'Chat di Ham2K';
	@override String get chatDescription => 'Il server Discord per la nostra comunità online';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Video e live stream';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Perché non puoi avere troppe foto…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Seguici per notizie e aggiornamenti';
	@override String get contact => 'Contattaci';
	@override String get contactDescription => 'help@ham2k.com — ma prova prima i Forum o la Chat!';
}

// Path: settings.exports
class _Translations$settings$exports$it extends Translations$settings$exports$en {
	_Translations$settings$exports$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esportazioni';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$it extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get activities => 'Attività';
	@override String get hunting => 'Caccia';
	@override String get contests => 'Contest';
	@override String get lookups => 'Ricerche';
	@override String get dashboard => 'Dashboard';
}

// Path: settings.map
class _Translations$settings$map$it extends Translations$settings$map$en {
	_Translations$settings$map$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mappe';
	@override late final _Translations$settings$map$style$it style = _Translations$settings$map$style$it._(_root);
	@override late final _Translations$settings$map$showCallsigns$it showCallsigns = _Translations$settings$map$showCallsigns$it._(_root);
	@override late final _Translations$settings$map$showGrayline$it showGrayline = _Translations$settings$map$showGrayline$it._(_root);
	@override late final _Translations$settings$map$styleOpts$it styleOpts = _Translations$settings$map$styleOpts$it._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$it extends Translations$settings$privacy$en {
	_Translations$settings$privacy$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacy';
	@override late final _Translations$settings$privacy$shareAppData$it shareAppData = _Translations$settings$privacy$shareAppData$it._(_root);
	@override late final _Translations$settings$privacy$shareOpData$it shareOpData = _Translations$settings$privacy$shareOpData$it._(_root);
	@override String get privacyPolicy => 'Informativa sulla Privacy';
	@override String get termsOfService => 'Termini di Servizio';
}

// Path: settings.sync
class _Translations$settings$sync$it extends Translations$settings$sync$en {
	_Translations$settings$sync$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronizzazione Cloud';
	@override String get moreSettings => 'Altre impostazioni di sincronizzazione';
	@override String get enable => 'Abilita Sincronizzazione';
	@override String get deviceKey => 'Chiave del dispositivo';
}

// Path: settings.peers
class _Translations$settings$peers$it extends Translations$settings$peers$en {
	_Translations$settings$peers$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispositivi Peer';
	@override String get enable => 'Connetti ad altri dispositivi';
	@override String get enableDescription => 'Consenti la condivisione di operazioni, logging, CAT e GPS con altri dispositivi sulla rete locale';
	@override String get bleEnable => 'Connetti via Bluetooth';
	@override String get bleDescription => 'Usa il Bluetooth LE per connetterti anche senza rete locale';
	@override String get thisDevice => 'Questo Dispositivo';
	@override String get deviceName => 'Nome';
	@override String get deviceNameHint => 'Come questo dispositivo viene visto dagli altri dispositivi';
	@override String get pairedDevices => 'Dispositivi collegati';
	@override String get noPairedDevices => 'Ancora nessun dispositivo collegato. Attiva questa opzione su un altro dispositivo di questa rete per collegarli.';
	@override String deviceListProblem({required Object error}) => 'Impossibile leggere i dispositivi collegati: ${error}';
	@override String get nearby => 'Nelle vicinanze';
	@override String get connected => 'Connesso';
	@override String get viaBluetooth => 'via Bluetooth';
	@override String get connecting => 'Connessione in corso…';
	@override String get syncing => 'Sincronizzazione in corso…';
	@override String get waitingForThem => 'In attesa dell\'altro dispositivo';
	@override String get notConnected => 'Non connesso';
	@override String get wantsToPair => 'vuole condividere questa operazione';
	@override String get allow => 'Consenti';
	@override String get link => 'Collega';
	@override String get reject => 'Rifiuta';
	@override String get forget => 'Dimentica';
	@override String forgetTitle({required Object name}) => 'Dimenticare ${name}?';
	@override String get forgetBody => 'Smetterà di sincronizzarsi con questo dispositivo. Potrai consentirlo di nuovo in seguito, e i contatti già registrati vengono mantenuti.';
	@override String pairTitle({required Object name}) => 'Collega con ${name}';
	@override String get pairBody => 'Questo dispositivo è sulla tua rete locale e vuole connettersi.';
	@override String get pairBodyBle => 'Questo dispositivo è nelle vicinanze e vuole connettersi via Bluetooth LE.';
	@override String get pairIdLabel => 'ID dispositivo';
	@override String get pairWarning => 'Collega solo dispositivi che riconosci. Qualsiasi dispositivo su questa rete può inviare una richiesta.';
	@override String get pairWarningBle => 'Collega solo dispositivi che riconosci. Qualsiasi dispositivo nelle vicinanze può inviare una richiesta.';
	@override String problem({required Object error}) => 'Impossibile raggiungere la rete locale: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Connesso a ${device}';
	@override String statusLost({required Object device}) => 'Connessione persa con ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispositivi Peer: ${connected} di ${linked} connessi';
	@override String get screenEnable => 'Condividi schermi e finestre';
	@override String get screenDescription => 'Consenti ad altri dispositivi di mostrare schermi o finestre di questo computer';
	@override String get screenSources => 'Schermi e Finestre';
	@override String get screenRefresh => 'Aggiorna l\'elenco';
	@override String get screenUnsupportedPlatform => 'Questo dispositivo non può condividere il suo schermo. macOS può farlo; ogni dispositivo può mostrare uno schermo condiviso da un altro.';
	@override String get screenUnsupportedVersion => 'Per condividere uno schermo serve macOS 12.3 o successivo. Questo dispositivo può comunque mostrare uno schermo condiviso da un altro.';
	@override String get screenNeedsPermission => 'macOS richiede il tuo permesso per registrare lo schermo prima che questa app possa condividerne uno.';
	@override String get screenGrantPermission => 'Richiedi il permesso';
	@override String get screenRelaunchAfterGranting => 'Consentilo in Impostazioni di Sistema in Privacy e sicurezza → Registrazione schermo, poi chiudi e riapri questa app — macOS comunica la modifica a un\'app solo al suo avvio successivo.';
	@override String screenProblem({required Object error}) => 'Condivisione schermo: ${error}';
	@override String get screenChooseTitle => 'Scegli cosa condividere';
	@override String get screenChooseButton => 'Scegli cosa condividere…';
	@override String get screenTabScreens => 'Schermi';
	@override String get screenTabApps => 'App';
	@override String get screenTabWindows => 'Finestre';
	@override String get screenTabEmpty => 'Non è stato trovato nulla di questo tipo.';
	@override String get screenSharedSummaryNone => 'Ancora niente scelto.';
	@override String get screenThisDevice => 'Questo dispositivo';
	@override String screenSharedTo({required Object devices}) => 'Mostrato su ${devices}';
	@override String get screenSharedToNobody => 'Non mostrato';
	@override String screenStopSharing({required Object name}) => 'Smetti di condividere ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$it extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configurazione Sincronizzazione';
	@override String get enableTitle => 'Sincronizza con Ham2K Log Filer';
	@override String get enabledDescription => 'Backup e sincronizzazione del tuo log tra i dispositivi';
	@override String get disabledDescription => 'Disattivata — resta solo su questo dispositivo';
	@override String get syncing => 'Sincronizzazione in corso';
	@override String get account => 'Account';
	@override String get refresh => 'Aggiorna';
	@override String get switchAccounts => 'Cambia Account';
	@override String get switchAccountsDescription => 'Collega questo dispositivo a un altro account con un codice QR o via email';
	@override String get connectionRequests => 'Richieste di collegamento';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Un dispositivo è in attesa di unirsi a questo account',
		other: '${n} dispositivi sono in attesa di unirsi a questo account',
	);
	@override String get accountEmailTitle => 'Email dell\'account';
	@override String accountEmailSent({required Object email}) => 'Conferma inviata a ${email}. Apri il link ricevuto per completare la modifica.';
	@override String get resendConfirmation => 'Invia di nuovo l\'email di conferma';
	@override String resendConfirmationDescription({required Object email}) => 'In attesa di ${email}';
	@override String accountEmailResent({required Object email}) => 'Inviata di nuovo a ${email}.';
	@override String get deviceLinked => 'Quel dispositivo è ora collegato a questo account.';
	@override String get checking => 'Verifica in corso…';
	@override String get notLinked => 'Non ancora collegato';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Sostituire i dati locali?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${n} operazione',
		other: '${n} operazioni',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
	@override String get counts => 'Dati sincronizzati';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Questo dispositivo: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'In attesa di caricamento: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Questo dispositivo: verifica in corso…';
	@override String get countsServerChecking => 'Server: verifica in corso…';
	@override String get countsServerUnavailable => 'Server: non disponibile';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Questo esegue il backup e rimuove ${operations} e ${qsos} da questo dispositivo, poi scarica al loro posto i dati dell\'account. Il backup resta nel database di questo dispositivo.';
	@override String get replace => 'Sostituisci';
	@override String get pendingBannerTitle => 'Rilevato un nuovo account Ham2K Log Filer';
	@override String get pendingBannerBody => 'Mantieni le operazioni e i QSO esistenti su questo dispositivo e uniscili all\'account, oppure sostituiscili con i dati dell\'account (in entrambi i casi un backup resta su questo dispositivo).';
	@override String get combine => 'Combina';
	@override String get authIssueTitle => 'La sincronizzazione non riesce a connettersi';
	@override String get authIssueText => 'Ham2K Log Filer continua a rifiutare questo dispositivo. Controlla il tuo nominativo nelle impostazioni di Sincronizzazione.';
	@override String get openSettings => 'Apri le impostazioni di Sincronizzazione';
}

// Path: settings.accounts
class _Translations$settings$accounts$it extends Translations$settings$accounts$en {
	_Translations$settings$accounts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Account, Servizi e Fonti di Dati';
	@override String get none => 'Nessuna estensione attiva con account';
	@override String get notConfigured => 'Non configurato';
	@override String get connected => 'Connesso';
	@override String get cancelLogin => 'Annulla accesso';
	@override String get openInBrowser => 'Apri nel Browser';
	@override String loggedInAs({required Object identity}) => 'Accesso effettuato come ${identity}';
	@override String get pressSaveToKeep => 'Premi Salva per mantenere connesso questo account.';
	@override String connectedTo({required Object label}) => 'Connesso a ${label}';
	@override String get connect => 'Connetti';
	@override String get disconnect => 'Disconnetti';
	@override String get connectedAs => 'Connesso come';
	@override String get test => 'Prova';
	@override String saveFailed({required Object error}) => 'Salvataggio non riuscito: ${error}';
	@override String loginFailed({required Object error}) => 'Accesso non riuscito: ${error}';
	@override String get lookupFailed => 'Gli account non sono disponibili al momento — riprova tra un momento';
	@override String get browserLoginTitle => 'Completa l\'accesso con il tuo browser web';
	@override String browserLoginSteps({required Object prefix}) => 'Al termine, il browser proverà ad aprire un link che inizia con "${prefix}". Probabilmente sul tuo computer non c\'è nulla registrato per aprirlo, quindi copia quel link (dalla barra degli indirizzi, o dalla pagina di errore mostrata dal browser) e incollalo qui.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger non è riuscito ad aprire il browser. Copia il link di accesso qui sotto e aprilo tu, poi copia il link a cui ti rimanda (inizia con "${prefix}") e incollalo qui.';
	@override String get copyLoginLink => 'Copia link di accesso';
	@override String get pastedLinkLabel => 'Incolla qui il link';
	@override String get finishLogin => 'Completa l\'accesso';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Non è il link di accesso — dovrebbe iniziare con "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Quel link appartiene a un altro tentativo di accesso. Chiudi questa pagina e connettiti di nuovo.';
	@override String get pastedLinkNoCode => 'Quel link non contiene un codice di accesso. Completa prima l\'accesso, poi copia il link a cui ti rimanda.';
	@override String get pastedLinkMalformed => 'Quel link sembra troncato. Copialo per intero e incollalo di nuovo.';
	@override String get relayLoginWaiting => 'In attesa che tu completi l\'accesso — proseguirà automaticamente quando avrai finito.';
	@override String get loginNoResponse => 'Questo dispositivo non ha ancora ricevuto risposta dall\'accesso. Se hai già completato nel browser, annulla e prova a connetterti di nuovo.';
	@override String get relayLoginNotOpened => 'Ham2K Logger non è riuscito ad aprire il browser automaticamente. Usa il pulsante qui sotto per aprire tu la pagina di accesso.';
	@override String get relayLoginUnavailable => 'Impossibile raggiungere il server di sincronizzazione necessario per completare l\'accesso. Controlla la connessione e riprova.';
	@override String get loginIncompleteResponse => 'Quel tentativo di accesso non è stato completato correttamente. Prova a connetterti di nuovo.';
	@override String get noKeyringTitle => 'Impossibile salvare gli accessi agli account';
	@override String get noKeyringText => 'Ham2K Logger non riesce a raggiungere un servizio portachiavi su questo computer, quindi gli accessi agli account non possono essere salvati né letti — collegare un account fallirà finché il problema non sarà risolto. Installa e avvia **gnome-keyring**, **KWallet** o **KeePassXC**, oppure sblocca il portachiavi che hai già, poi riavvia. Logging, esportazioni e file di dati non sono interessati; la sincronizzazione del log resta disattivata nel frattempo.';
	@override String get noKeyringInline => 'Impossibile salvare gli accessi: il portachiavi di questo computer non è raggiungibile. Installa e avvia gnome-keyring, KWallet o KeePassXC, oppure sblocca quello che hai.';
	@override String get noSecureStorageInline => 'Impossibile salvare gli accessi: l\'archivio sicuro di questo computer non è raggiungibile.';
}

// Path: settings.station
class _Translations$settings$station$it extends Translations$settings$station$en {
	_Translations$settings$station$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurazione Stazione e Controllo CAT';
	@override String get none => 'Nessun apparato configurato';
	@override String get add => 'Aggiungi';
	@override String get addTitle => 'Aggiungi apparato';
	@override String get searchHint => 'Cerca apparati';
	@override String get noMatches => 'Nessun apparato corrispondente';
	@override String get detectedEquipment => 'Apparati rilevati';
	@override String discoveryUnavailable({required Object error}) => 'Impossibile rilevare le radio: ${error}';
	@override String get edit => 'Modifica apparato';
	@override String get name => 'Nome';
	@override String get nameDescription => 'Come la chiami tu — "Radio sinistra". Opzionale.';
	@override String get transport => 'Connessione';
	@override String get host => 'Indirizzo';
	@override String get hostDescription => 'L\'hostname o l\'indirizzo IP della radio sulla tua rete.';
	@override String get port => 'Porta';
	@override String get hostRequired => 'L\'indirizzo è obbligatorio';
	@override String get portInvalid => 'La porta deve essere tra 1 e 65535';
	@override String get connect => 'Connetti';
	@override String get disconnect => 'Disconnetti';
	@override String get remove => 'Rimuovi';
	@override String removeTitle({required Object name}) => 'Rimuovere ${name}?';
	@override String get removeMessage => 'Lo rimuove solo dall\'app. Le impostazioni dell\'apparato restano invariate.';
	@override String unknownType({required Object typeKey}) => 'Tipo di apparato non riconosciuto "${typeKey}"';
	@override String get report => 'Segnala';
	@override String get reportTitle => 'Segnala questa radio';
	@override String get reportIntro => 'Dicci quale radio è davvero e com\'è andata. La tua segnalazione diventa una scheda letta dal team Ham2K, e ciò che scrivi su come l\'hai fatta funzionare potrebbe aiutare il prossimo operatore con lo stesso apparato.';
	@override String get reportManufacturer => 'Produttore';
	@override String get reportManufacturerDescription => 'Chi la produce — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Il produttore è obbligatorio';
	@override String get reportModel => 'Modello';
	@override String get reportModelDescription => 'Il modello, come lo chiama la radio stessa — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'Il modello è obbligatorio';
	@override String get reportOutcome => 'Com\'è andata?';
	@override String get reportOutcomeWorks => 'Ha funzionato bene';
	@override String get reportOutcomeIssues => 'Ha funzionato, con problemi';
	@override String get reportOutcomeFails => 'Non ha funzionato per niente';
	@override String get reportOutcomeRequired => 'Dicci com\'è andata';
	@override String get reportComments => 'Commenti';
	@override String get reportCommentsPlaceholder => 'Cosa ha funzionato, cosa no, qualsiasi cosa ti abbia sorpreso.';
	@override String get reportHints => 'Suggerimenti per la risoluzione dei problemi';
	@override String get reportHintsPlaceholder => 'Vuoi suggerire qualche consiglio per la risoluzione dei problemi ad altri utenti?';
	@override String get reportSend => 'Invia segnalazione';
	@override String get reportSending => 'Invio della segnalazione…';
	@override String reportSent({required Object ref}) => 'Grazie — la tua segnalazione è stata registrata come ${ref}.';
	@override String get reportSentNoRef => 'Grazie — la tua segnalazione è stata inviata.';
	@override String reportFailed({required Object error}) => 'La segnalazione non è stata inviata: ${error}';
	@override String get troubleshootingNotes => 'Note per la risoluzione dei problemi';
	@override String get mainVfo => 'VFO principale';
	@override String get useAsMainVfo => 'Usa come VFO principale';
	@override String get serialPort => 'Porta seriale';
	@override String get serialPortDescription => 'La porta su cui appare l\'interfaccia CAT della radio.';
	@override String get serialPortNone => 'Nessuna porta seriale trovata';
	@override String get serialPortRequired => 'Scegli una porta seriale';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'porta ${n} di ${total}';
	@override String get serialPortSuggested => 'suggerita';
	@override String get serialPortJustNow => 'Connessa di recente';
	@override String get serialPortNoDriver => 'nessun driver';
	@override String get serialDeviceRequest => 'Aggiungi un dispositivo USB…';
	@override String get bleDevice => 'Dispositivo Bluetooth LE';
	@override String get bleDeviceDescription => 'Il bridge seriale attraverso cui è collegata la radio, come un LiNK500MP in Mode 4 o un adattatore seriale BLE.';
	@override String get bleScan => 'Cerca dispositivi Bluetooth LE…';
	@override String get bleScanNoneFound => 'Nessun dispositivo Bluetooth LE trovato. Controlla che il bridge sia acceso, nelle vicinanze e nella sua modalità Bluetooth LE (Mode 4 su un LiNK500MP).';
	@override String bleScanFailed({required Object reason}) => 'Impossibile eseguire la scansione Bluetooth LE: ${reason}';
	@override String get bleOff => 'Il Bluetooth è spento.';
	@override String get bleDenied => 'Il permesso Bluetooth non è stato concesso. Consentilo nelle impostazioni di sistema, poi riprova.';
	@override String get bleUnsupported => 'Questo dispositivo non ha il Bluetooth LE.';
	@override String get bleStarting => 'Il Bluetooth si sta ancora avviando. Riprova tra un momento.';
	@override String get bleConnectFailed => 'Impossibile raggiungere il dispositivo Bluetooth LE. Controlla che sia acceso, nelle vicinanze e non connesso a un\'altra app.';
	@override String bleNoSerialService({required Object services}) => 'Questo dispositivo Bluetooth LE non ha un servizio seriale che l\'app riconosca. Segnalalo indicando i suoi servizi: ${services}';
	@override String get baudRate => 'Velocità (baud)';
	@override String get baudRateDescription => 'Deve corrispondere al menu CAT della radio. Se non corrisponde, la radio restituisce dati senza senso e nessun errore.';
	@override String get serialRtsHigh => 'Mantieni RTS alto';
	@override String get serialRtsHighDescription => 'Solo per una radio che attende RTS prima di rispondere, come una Yaesu con CAT RTS attivo. Su Digirig, SignaLink e la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione.';
	@override String get serialDtrHigh => 'Mantieni DTR alto';
	@override String get serialDtrHighDescription => 'Solo per un\'interfaccia CAT alimentata dal DTR, come alcuni cavi RS-232 per l\'FT-817. Su molti cavi DTR manipola il CW o il PTT, e mantenerlo alto manda in trasmissione.';
	@override String get serialUsbDriver => 'Driver del chip USB';
	@override String get serialUsbDriverDescription => 'Automatico riconosce la maggior parte degli adattatori. Scegli il chip solo per un adattatore che l\'elenco delle porte indica senza driver — il nome è sulla confezione o in un elenco dei dispositivi USB.';
	@override String get serialUsbDriverAuto => 'Automatico';
	@override String get civAddress => 'Indirizzo CI-V della radio';
	@override String get civAddressDescription => 'Esadecimale, come mostrato nel menu CI-V della radio. L\'IC-705 esce di fabbrica con A4.';
	@override String get civAddressInvalid => 'Un indirizzo CI-V è di due cifre esadecimali, da 01 a FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Quale slice della radio questa connessione legge e sintonizza.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Scegli una delle slice della radio, da A a H';
	@override String flexSliceMissing({required Object letter}) => 'La slice ${letter} non è in uso su questa radio — scegli un\'altra slice, o creala in SmartSDR';
	@override String get channelNotInUse => 'non in uso';
	@override String get channelHeldByUnknown => 'in uso da un altro programma';
	@override String get flexNoSlices => 'Questa radio non ha segnalato alcuna slice — controlla che SmartSDR sia in esecuzione e che questo client possa abbonarsi';
	@override String get spectrumUnsupported => 'Questa radio non invia lo spettro via CAT';
	@override String get spectrumRequiresBaud => 'Richiede il CAT a 115200 bps';
	@override String get spectrumNoRadio => 'Nessuna radio connessa';
	@override String get spectrumWaiting => 'In attesa dello spettro della radio…';
	@override String get spectrumUnavailable => 'La visualizzazione dello spettro non è disponibile';
	@override String get spectrumNoDaxChannel => 'Tutti i canali DAX IQ di questa radio sono in uso';
	@override String get spectrumNoPanadapter => 'Questa slice non ha un panadapter sulla radio';
	@override String spectrumStreamRefused({required Object code}) => 'La radio ha rifiutato uno stream DAX IQ (errore ${code})';
	@override String get spectrumNoUdp => 'I dati dello spettro della radio non raggiungono questo dispositivo';
	@override String get spectrumK4Unavailable => 'Impossibile ricevere lo spettro LAN del K4. Nuovo tentativo…';
	@override String get spectrumK4RemoteUnavailable => 'Impossibile ricevere lo spettro remoto del K4';
	@override String get spectrumScopeRefused => 'La radio ha rifiutato i comandi dello scope';
	@override String get spectrumOutOfRange => 'Lo scope della radio è impostato fuori dall\'intervallo che può mostrare';
	@override String get spectrumBandUnsupported => 'Lo scope della radio non può essere mostrato su questa banda';
	@override String get spectrumSdrNoRadio => 'In attesa della frequenza della radio collegata…';
	@override String get spectrumSdrNotConnected => 'L\'SDR non è connesso';
	@override String get spectrumSdrNoIf => 'Imposta la frequenza IF della radio nelle impostazioni di questo SDR';
	@override String get sdrRadio => 'Mostra lo spettro di';
	@override String get sdrRadioDescription => 'Una visualizzazione dello spettro su questa radio usa questo ricevitore invece dello scope della radio stessa.';
	@override String get sdrRadioMain => 'La radio principale';
	@override String get sdrTuning => 'Ingresso antenna';
	@override String get sdrTuningDescription => 'Da dove arriva il segnale del ricevitore. Con la propria antenna si sintonizza da solo per seguire la radio; sull\'uscita IF della radio resta sulla IF.';
	@override String get sdrTuningIndependent => 'La propria antenna';
	@override String get sdrTuningIfTap => 'L\'uscita IF della radio';
	@override String get sdrIfHz => 'Frequenza IF (Hz)';
	@override String get sdrIfHzDescription => 'Solo per un\'uscita IF: la frequenza a cui la sintonia della radio si trova sulla sua IF, ad esempio 68330000 su un FT-817.';
	@override String get sdrIfInverted => 'IF invertita';
	@override String get sdrGainDb => 'Guadagno (dB)';
	@override String get sdrGainDbDescription => 'Lascia vuoto per il guadagno automatico del ricevitore.';
	@override String get sdrOffsetHz => 'Offset di frequenza (Hz)';
	@override String get sdrOffsetHzDescription => 'Aggiunto a ogni frequenza inviata al ricevitore, per un upconverter: 125000000 per un Ham It Up.';
	@override String get sdrPpm => 'Correzione di frequenza (ppm)';
	@override String get rtlDirectSampling => 'Campionamento diretto';
	@override String get rtlDirectSamplingDescription => 'Per le HF su un RTL-SDR V3 senza upconverter. Un RTL-SDR V4 arriva alle HF senza.';
	@override String get rtlDirectSamplingOff => 'Off';
	@override String get rtlDirectSamplingI => 'Ramo I';
	@override String get rtlDirectSamplingQ => 'Ramo Q';
	@override String get rtlTcpNotAServer => 'Questo non è un server rtl_tcp';
	@override String get rtlTcpNotes => 'Questo si connette a un **server rtl_tcp che avvii tu stesso** sul computer a cui è collegato il dongle.\n\n- **Avvialo** con `rtl_tcp -a 0.0.0.0` così che le altre macchine possano raggiungerlo; sulla stessa macchina basta `rtl_tcp` da solo.\n- **La porta** è 1234 a meno che non l\'abbia avviato con `-p`.\n- **Un programma alla volta:** rtl_tcp serve un solo client. L\'app si connette solo mentre è visibile una visualizzazione dello spettro, e la rilascia qualche secondo dopo la chiusura.\n- **Su Android**, l\'app *SDR driver* esegue lo stesso server sul telefono.';
	@override String get rspTcpNotes => 'Questo si connette a un **server rsp_tcp che avvii tu stesso** sul computer a cui è collegato l\'RSP, con l\'API di SDRplay installata lì.\n\n- **Avvialo** con `rsp_tcp -a 0.0.0.0`.\n- **La porta** è 1234 a meno che non l\'abbia avviato con `-p`.\n- **Un programma alla volta:** il server accetta un solo client. L\'app si connette solo mentre è visibile una visualizzazione dello spettro.';
	@override String get n3fjpNoRig => 'N3FJP non ha un\'interfaccia radio configurata, quindi questo segue ciò che viene digitato in N3FJP, non una radio';
	@override String get winkeyerKeyPort => 'Uscita di manipolazione';
	@override String get winkeyerKeyPortDescription => 'In quale delle due uscite del keyer è collegata la tua radio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Porta ${n}';
	@override String get winkeyerPtt => 'Usa il PTT del keyer';
	@override String get winkeyerPttDescription => 'Attiva la linea PTT sullo stesso jack, per un amplificatore o una radio che lo richiede. Lascia disattivato per una radio manipolata dal suo jack del tasto.';
	@override String get winkeyerNoAnswer => 'Nessun WinKeyer ha risposto su questa porta';
	@override String get winkeyerStoppedAnswering => 'Il WinKeyer ha smesso di rispondere durante la trasmissione; il messaggio è stato scartato';
	@override String get icomControlPort => 'Porta di controllo (UDP)';
	@override String get icomControlPortDescription => 'La Control Port (UDP) della radio — 50001 a meno che non sia stata cambiata nelle sue impostazioni di rete, o reindirizzata su un\'altra.';
	@override String get icomSerialPort => 'Porta seriale (UDP)';
	@override String get icomSerialPortDescription => 'La Serial Port (UDP) della radio — 50002 a meno che non sia stata cambiata nelle sue impostazioni di rete, o reindirizzata su un\'altra.';
	@override String get icomPortsDiffer => 'Le porte di controllo e seriale devono essere diverse';
	@override String get radioUser => 'Nome utente della radio';
	@override String get radioPass => 'Password della radio';
	@override String get radioLoginDescription => 'L\'accesso Network → Remote della radio, non la password del WiFi.';
	@override String get radioUserRequired => 'Il nome utente per il controllo remoto della radio è obbligatorio';
	@override String get connectFailedBusy => 'Il dispositivo è in uso';
	@override String get connectFailedDenied => 'Accesso negato';
	@override String get connectFailedDevice => 'Dispositivo non trovato';
	@override String get connectFailedUnsupported => 'Nessun driver riconosce il chip di questo adattatore USB. Se sai quale chip è, sceglilo in Driver del chip USB nelle Impostazioni avanzate.';
	@override String get connectFailedLines => 'Impossibile mantenere RTS/DTR come impostati, quindi la porta è stata chiusa. Un altro programma potrebbe aver lasciato attivo l\'handshake hardware — scollega e ricollega il cavo.';
	@override String get connectFailedNetwork => 'Impossibile trovare la radio sulla rete. Controlla il suo indirizzo e che sia accesa e raggiungibile.';
	@override String connectFailedReplyPort({required Object port}) => 'La porta ${port} su questo dispositivo è già in uso, e le risposte arrivano lì. Chiudi qualsiasi altra cosa in ascolto su quella porta — compreso un altro nodo PstRotator — oppure cambia porta.';
	@override String get connectFailedTimeout => 'La radio non ha risposto in tempo. Controlla che sia accesa e raggiungibile.';
	@override late final _Translations$settings$station$models$it models = _Translations$settings$station$models$it._(_root);
	@override late final _Translations$settings$station$transports$it transports = _Translations$settings$station$transports$it._(_root);
	@override String get troubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get ft891Troubleshooting => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **CAT RTS disattivato sulla radio, oppure Mantieni RTS alto attivo.** Con **CAT RTS** attivo (menu FT-891 **05-08**), la radio resta muta finché RTS è basso — può rispondere una volta all\'apertura della porta, poi più nulla. Scegliendo la porta USB della radio stessa si attiva **Mantieni RTS alto** nelle Impostazioni avanzate. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione il tuo trasmettitore: in quel caso disattiva invece CAT RTS sulla radio.\n- **La velocità deve corrispondere** al CAT RATE della radio (menu **05-06**). Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get yaesuBinaryTroubleshooting => 'Questa radio usa il vecchio CAT Yaesu a cinque byte, e non risponde affatto quando qualcosa non va. Quasi sempre è uno di questi casi:\n\n- **Il cavo deve convertire i livelli.** Il jack CAT sul retro non è RS-232 né USB; serve un CT-62 o un adattatore equivalente. Un semplice cavo audio o dati non funziona per il CAT.\n- **La velocità deve corrispondere** al menu CAT RATE della radio (**#14** su un FT-817, **#19** su un FT-857 o FT-897). Se non corrisponde, la radio non restituisce nulla, e mai un errore.\n- **Non lasciare mai che qualcosa alzi RTS o DTR su questa porta.** Sulla maggior parte dei cavi per queste radio quelle linee sono PTT e manipolazione. L\'eccezione è una vecchia interfaccia alimentata dal DTR: per quella attiva **Mantieni DTR alto** nelle Impostazioni avanzate.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesto driver è stato scritto a partire dalla tabella CAT pubblicata da Yaesu e non è stato provato su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get tenTecTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get tenTecEagleTroubleshooting => '- **La porta USB-B sul retro è il collegamento CAT.** La radio appare come porta seriale USB; su Windows serve il driver USB to UART di Ten-Tec, che in Gestione dispositivi appare come "USB to UART (COMx)".\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta, e così anche il programma di aggiornamento firmware di Ten-Tec.\n- **Impostare la larghezza del filtro dall\'app la toglie alla manopola BW** finché la radio non viene spenta e riaccesa. La radio funziona così.\n\nQuesto driver è stato scritto a partire dalla guida di riferimento per programmatori di Ten-Tec. Se funziona solo in parte, vale la pena segnalarlo, indicando la versione del firmware dal menu della radio.';
	@override String get tenTecOrionTroubleshooting => '- **Usa un cavo seriale DB-9 diritto** verso la porta SERIAL DATA, non un null-modem.\n- **Questa voce mantiene RTS alto**, perché l\'Orion usa RTS e CTS come handshake. Su un\'interfaccia che attiva il PTT da RTS, come un Digirig, disattiva Mantieni RTS alto nelle Impostazioni avanzate, altrimenti la radio trasmette appena l\'app si connette.\n- **Il CW dall\'app richiede il keyer interno della radio attivo.** Se è disattivato, la radio ignora ciò che l\'app invia.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesto driver è stato scritto a partire dalla guida di riferimento per programmatori di Ten-Tec e non è stato provato su un Orion. Se funziona solo in parte, vale la pena segnalarlo, indicando la versione del firmware dal menu della radio.';
	@override String get tenTecNoCw => 'Il firmware di questa radio non accetta il CW dall\'app. Ten-Tec lo ha aggiunto nel firmware Orion 1.366.';
	@override String get tenTecKeyerOff => 'Il keyer interno della radio è disattivato, quindi ignora il CW inviato dall\'app. Attiva il keyer nel menu della radio.';
	@override String get guohetecTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get guohetecTroubleshooting => 'La Q900 ha due protocolli CAT, e questa voce usa quello nativo invece dell\'imitazione dell\'FT-817. Scegli qui **Guohetec Q900**, non un FT-817 — l\'imitazione supporta meno comandi, e la radio non dice quale sta usando.\n\n- **Il cavo USB-C è il collegamento CAT**, e collega anche la scheda audio. La velocità non conta su di esso; la porta ignora qualunque valore impostato.\n- **Non lasciare mai che qualcosa alzi RTS o DTR su questa porta.** Su un cavo seriale quelle linee sono PTT e manipolazione.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **Una radio di seconda generazione si comporta diversamente** da una di prima. Premi a lungo Menu, poi About: HW 2.0 è la seconda generazione.\n\nQuesto driver è stato scritto a partire dal protocollo pubblicato dal produttore e non è stato provato su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get yaesuTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get yaesuTroubleshooting => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **CAT RTS deve essere OFF sulla radio.** Se è attivo, la radio attende una linea di handshake che l\'app mantiene bassa. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti quella stessa linea è il PTT, quindi alzarla manderebbe in trasmissione il trasmettitore. Sulla porta USB della radio stessa, l\'alternativa è **Mantieni RTS alto** nelle Impostazioni avanzate. La posizione di questa impostazione varia a seconda del modello (menu **05-08** su un FT-891).\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **I modi seguono la tabella dell\'FT-891.** La maggior parte della gamma Yaesu vi corrisponde, ma una radio che numera i modi in modo diverso mostrerà e imposterà quello sbagliato per quei modi. La frequenza non ne risente.';
	@override String get ftdx3000Troubleshooting => '**Il menu 037 CAT SELECT deve essere su USB** per il CAT tramite la porta USB della radio; impostato su RS232C, il CAT è sul jack sul retro.\n\nQuesta voce è stata scritta a partire dalla documentazione CAT pubblicata e non è stata provata su un FTDX3000. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get yaesuRs232Troubleshooting => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **Il jack CAT è RS-232.** Serve un adattatore USB-seriale e un cavo DB-9 diritto — un cavo null-modem inverte le linee, e la radio non sente nulla.\n- **CAT RTS deve essere OFF sulla radio.** Se è attivo, la radio attende una linea di handshake che l\'app mantiene bassa, a meno che **Mantieni RTS alto** non sia attivo nelle Impostazioni avanzate.\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesta voce è stata scritta a partire dalla documentazione CAT pubblicata e non è stata provata su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get yaesuUsbTroubleshooting => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **Usa la prima delle due porte USB della radio.** Il CAT è normalmente sulla prima (la porta COM **Enhanced** su Windows); la seconda (**Standard**) è per PTT e manipolazione. Il selettore indica la prima ogni volta che riesce a distinguerle.\n- **CAT RTS disattivato sulla radio, oppure Mantieni RTS alto attivo.** Con il menu **CAT RTS** della radio attivo, questa resta muta finché RTS è basso — può rispondere una volta all\'apertura della porta, poi più nulla. Scegliendo la porta USB della radio stessa si attiva **Mantieni RTS alto** nelle Impostazioni avanzate. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione il tuo trasmettitore: in quel caso disattiva invece CAT RTS sulla radio.\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.';
	@override String get k4SerialNotes => 'Collega la presa USB-B (PC) posteriore del K4. Per il CAT funziona sia USB-PC1 sia USB-PC2; scegli una porta libera e fai corrispondere l\'impostazione Serial USB-PCn: Baud Rate sulla radio. HaLo precompila 38400; cambialo se necessario. Un\'altra applicazione deve usare l\'altra porta o l\'Ethernet.\n\nQuesta connessione controlla la radio e i suoi keyer; non invia audio a HaLo.';
	@override String get k4TcpNotes => 'Collega la presa Ethernet del K4 alla tua rete locale. Inserisci il suo hostname o indirizzo IP e la porta CAT 9200. HaLo usa lo stesso host sulla porta fissa 9201 quando è visibile un panadapter o un waterfall; cambiare la porta CAT non cambia la porta dello spettro.\n\nLo spettro mostra il ricevitore principale. I suoi controlli di zoom, regolazione del riferimento e velocità influiscono solo sulla visualizzazione di HaLo. Lo streaming audio non è supportato.';
	@override String get k4PowerTimeout => 'La potenza del K4 non è stata cambiata perché la radio non ha confermato il suo intervallo di uscita. Riprova.';
	@override String get k4RemoteNotes => 'Abilita l\'accesso remoto sul tuo K4 e inserisci la sua password di rete. Main e Sub condividono un\'unica connessione cifrata per il controllo della radio e lo spettro. La porta predefinita è 9204; inserisci la porta reindirizzata quando ti connetti da remoto.\n\nLa riproduzione audio e lo streaming del microfono non sono supportati.';
	@override String get k4Receiver => 'Ricevitore';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'Scegli Main o Sub';
	@override String get k4ReceiverAlreadyConfigured => 'Quel ricevitore è già configurato per questo K4';
	@override String get k4SubReceiverOff => 'Il ricevitore Sub del K4 è spento';
	@override String get k4RemotePasswordRequired => 'Inserisci la password di rete del K4 per connetterti in modo sicuro.';
	@override String get k4RemoteHandshakeFailed => 'Il K4 non è riuscito a stabilire una connessione sicura. Controlla la sua password di rete e le impostazioni di accesso remoto.';
	@override String get k4RemoteUnreachable => 'Impossibile raggiungere la connessione sicura del K4. Controlla indirizzo, porta e impostazioni di accesso remoto.';
	@override String get k4PowerRange => 'La potenza del K4 deve essere tra 0,1 e 110 W, o tra 0,0001 e 0,01 W quando è attiva l\'uscita in milliwatt del transverter.';
	@override String get elecraftTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get elecraftTroubleshooting => 'Le radio Elecraft usano il CAT Kenwood, e sia un KX2 sia un KX3 sono stati provati così — VFO in entrambe le direzioni, cambio di modo e zero-beat CW tutti funzionanti.\n\nSe la radio non risponde, quasi sempre è uno di questi casi:\n\n- **La velocità deve corrispondere** a quella impostata in **RS232** nel menu della radio. Escono di fabbrica con 38400. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\n**Se la frequenza è giusta ma il modo è sbagliato**, faccelo sapere. Le voci KX2 e KX3 leggono il modo da una posizione nella risposta di stato della radio che abbiamo fissato in base alle radio viste finora, e un firmware che lo mette altrove ci arriva solo tramite una segnalazione.\n\nNessuno ha ancora segnalato il K3, quindi se ne usi uno facci sapere cosa succede. Il K4 ha una voce propria.';
	@override String get lab599TroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get lab599Troubleshooting => 'La serie TX-500 usa il CAT Kenwood. Frequenza e modo sono stati provati tramite un LiNK500MP; potenza e strumenti sono scritti a partire dal riferimento CAT di Lab599, quindi segnala cosa succede in ogni caso.\n\n- **La velocità deve corrispondere** all\'impostazione CAT della radio, 9600 se non l\'hai cambiata. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Scegli il protocollo CAT sulla radio.** TS-2000 copre frequenza, modo e potenza. LAB599 permette all\'app anche di mettere la radio in DIG, di vederla trasmettere in DIG e di leggere la tensione di alimentazione.\n- **Tramite un LiNK500MP**, tieni premuta la manopola del VFO per circa tre secondi per passare il controllo CAT all\'interfaccia.\n- **Imposta la modalità del LiNK500MP per la connessione**: Mode 3 per il Bluetooth, Mode 4 per il Bluetooth LE. In qualsiasi altra modalità una scansione Bluetooth LE non lo trova.\n- **Via Bluetooth**, il LiNK500MP si accoppia come due porte seriali e solo una porta il CAT. Se la radio resta muta, scegli l\'altra.';
	@override String get lab599TroubleshootingIos => 'La serie TX-500 usa il CAT Kenwood. Frequenza e modo sono stati provati tramite un LiNK500MP; potenza e strumenti sono scritti a partire dal riferimento CAT di Lab599, quindi segnala cosa succede in ogni caso.\n\n- **Imposta il LiNK500MP su Mode 4**, la sua modalità Bluetooth LE, prima di cercarlo. In qualsiasi altra modalità un iPhone o iPad non riesce a trovarlo.\n- **Passa il controllo CAT al LiNK500MP**: tieni premuta la manopola del VFO della radio per circa tre secondi.\n- **Scegli il protocollo CAT sulla radio.** TS-2000 copre frequenza, modo e potenza. LAB599 permette all\'app anche di mettere la radio in DIG, di vederla trasmettere in DIG e di leggere la tensione di alimentazione.';
	@override String get kenwoodTroubleshootingTitle => 'Se la radio si connette ma non mostra la frequenza';
	@override String get kenwoodTroubleshooting => 'Questo driver è stato provato con i Kenwood TS-590SG e TS-480, i QRP Labs QMX e QCX-mini e gli Elecraft KX2 e KX3. Il resto della gamma è scritto a partire dai riferimenti CAT pubblicati, quindi segnala cosa succede in ogni caso.\n\nSe la radio non risponde, quasi sempre è uno di questi casi:\n\n- **La velocità deve corrispondere** al menu CAT della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **Alcune radio richiedono di abilitare il CAT** nel menu prima di rispondere.\n- **Le radio Kenwood attendono RTS**: la loro porta CAT lo usa come handshake, quindi Mantieni RTS alto (nelle Impostazioni avanzate) deve essere attivo. Una connessione configurata prima che fosse attivo per impostazione predefinita potrebbe averlo disattivato. Su un Digirig o un altro cavo che attiva il PTT da RTS, disattivalo, altrimenti la radio trasmette.\n\n**Diversi front-end SDR usano questo stesso protocollo**, quindi vale la pena provare questa voce anche per quelli; le radio Elecraft sono elencate a parte, sotto Elecraft. Se la frequenza è giusta ma il modo è sbagliato o manca, è l\'unica parte che varia nella gamma — l\'app lo ricava dalla radio e in alternativa lo chiede direttamente, quindi il modo potrebbe semplicemente arrivare in ritardo.';
	@override String get statusConnected => 'Connesso';
	@override String get statusLost => 'Disconnesso';
	@override String get notConfigured => 'Non configurato';
	@override String get currentConfiguration => 'Configurazione attuale';
	@override String get currentTransceiver => 'Ricetrasmettitore attuale';
	@override String get currentTransceivers => 'Ricetrasmettitori attuali';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => 'Messaggi in coda invece di interrompere';
	@override String get noRadioBSelected => 'Nessuna Radio B selezionata';
	@override String get radioMode => 'Modo della radio';
	@override String get keyerNotSupported => 'Non supportato dalla radio attuale';
	@override String get catControlPreferences => 'Preferenze del Controllo CAT';
	@override String get chooseTransceiver => 'Scegli il ricetrasmettitore';
	@override String get configurationSection => 'Configurazione';
	@override String get noTransceiverSelected => 'Nessun ricetrasmettitore selezionato';
	@override String makeMainVfo({required Object name}) => 'Usa ${name} per il VFO principale';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		zero: 'Nessun ricetrasmettitore',
		one: '${count} ricetrasmettitore',
		other: '${count} ricetrasmettitori',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} antenna',
		other: '${count} antenne',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} altro dispositivo',
		other: '${count} altri dispositivi',
	);
	@override String get equipmentInventory => 'Inventario apparati';
	@override String get equipmentInUse => 'Controlli del ricetrasmettitore';
	@override String get noTransceiver => 'Nessuno';
	@override String get peerRadioNotAvailable => 'Non disponibile';
	@override String peerRadioOnDevice({required Object device}) => 'Su ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} è su un altro dispositivo';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Questa radio è connessa a ${device}. La sua connessione e le sue impostazioni sono configurate su quel dispositivo.';
	@override String get antennaInUse => 'Antenna in uso';
	@override String get keyInUse => 'Manipolazione CW';
	@override String get phoneKeying => 'Keyer in fonia';
	@override String get phoneKeyingNone => 'Nessuno';
	@override String phoneKeyingRadio({required Object radio}) => 'Memorie in ${radio}';
	@override String get phoneKeyingComputer => 'Audio da questo computer';
	@override String get phoneKeyingOff => 'Il keyer in fonia è disattivato';
	@override String get computerVoiceSettings => 'Audio del Computer';
	@override String get cwKeyingOptions => 'Opzioni di manipolazione CW';
	@override String get noneSelected => 'Nessuno';
	@override String get moreSettings => 'Altre impostazioni';
	@override String get icomCivTroubleshootingTitle => 'Se appaiono due porte seriali per la stessa radio';
	@override String get icomCivTroubleshooting => 'Diverse radio Icom, tra cui l\'IC-705, presentano **due** porte seriali USB contemporaneamente (Icom le chiama Port A e Port B), entrambe impostate su CI-V per impostazione predefinita. Né questa app né il tuo sistema operativo possono distinguerle oltre questo: lo stesso ID vendor/prodotto USB appare semplicemente due volte, a volte qui contrassegnato con il suffisso `#2`. **Port A di solito è quella giusta** — normalmente la prima elencata dal sistema operativo o dal browser, e dove questa app riesce a distinguere le due porte la segna come suggerita. Se i comandi partono e la radio non risponde mai, prova l\'altra porta.';
	@override String get civAddressTroubleshootingTitle => 'Se la radio non risponde mai';
	@override String get civAddressTroubleshooting => '- **L\'indirizzo CI-V deve corrispondere** al menu della radio. Questa voce precompila l\'indirizzo di fabbrica del modello, ma una radio che condivide un bus CI-V è proprio il caso in cui viene cambiato. Un frame inviato all\'indirizzo sbagliato viene ignorato in silenzio, esattamente come con un cavo guasto.\n- **La velocità deve corrispondere** al CI-V BAUD RATE della radio (su USB, CI-V USB Baud Rate). Imposta sulla radio lo stesso valore mostrato qui, **non Auto**. Con Auto alcune radio, tra cui l\'IC-7300, si connettono e poi smettono di rispondere dopo circa un minuto.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **L\'indirizzo CI-V deve corrispondere** al menu della radio. Questa voce precompila l\'indirizzo di fabbrica del modello, ma una radio che condivide un bus CI-V è proprio il caso in cui viene cambiato. Un frame inviato all\'indirizzo sbagliato viene ignorato in silenzio, esattamente come con un cavo guasto.\n${speed}\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.';
	@override String get icomUsbSpeedFollows => '- **Non c\'è alcuna velocità da impostare.** Via USB questa radio comunica alla velocità usata dal computer, e questa voce usa sempre 115200, la velocità che serve allo scope.';
	@override String get ic7610UsbSpeed => '- **Imposta CI-V USB Baud Rate su 115200**, la velocità che questa voce usa sempre perché serve allo scope — **non Auto**. Una radio impostata su qualsiasi altra velocità risponde con il silenzio.';
	@override String get civTransceiveTitle => 'Se l\'app è lenta a seguire la radio';
	@override String get civTransceive => 'Se l\'app impiega diversi secondi a mostrare un cambio di frequenza o di modo fatto sulla radio, attiva l\'impostazione **CI-V Transceive** della radio (sulla maggior parte dei modelli attuali, in SET > Connectors > CI-V). Con l\'impostazione attiva, la radio comunica ogni cambiamento nel momento in cui avviene. Con l\'impostazione disattivata, l\'app vede un cambiamento solo la volta successiva in cui lo chiede, ogni pochi secondi.';
	@override String get ic7300Mk2Note => '\n- L\'**IC-7300 MK2** esce di fabbrica con l\'indirizzo `B6`, non il `94` precompilato qui — scegli invece la voce IC-7300 MK2.';
	@override String get ic705PortNote => '\n- L\'**IC-705** presenta due porte seriali USB, entrambe con il nome della radio. Il CI-V è sulla **prima**, che il selettore indica ogni volta che riesce a distinguerle.';
	@override String get ic7760PortNote => '\n- L\'**IC-7760** usa il CI-V sulla **Port A** delle due porte seriali USB che presenta.';
	@override String get x6100PortNote => '\n- L\'**X6100** usa il CI-V sulla sua porta **DEV** — la seconda delle due porte seriali che presenta, ed è quella indicata dal selettore.';
	@override String get rigctldTroubleshootingTitle => 'Se l\'app non riesce a connettersi';
	@override String get rigctldTroubleshooting => 'Questa voce si connette a un **demone rigctld che avvii tu**, non direttamente alla radio — il backend di Hamlib comunica con la radio e supporta centinaia di modelli.\n\n- **Il demone deve essere già in esecuzione**, ad es. `rigctld -m 1035 -r /dev/ttyUSB0`. Trova il numero di modello della tua radio con `rigctl -l`.\n- **Da un\'altra macchina**, avvialo con `-T 0.0.0.0`: per impostazione predefinita rigctld accetta connessioni solo dalla macchina su cui è in esecuzione.\n- **La porta** è 4532 a meno che tu non abbia avviato il demone con `-t`.\n- Una volta connesso, se manca la frequenza di solito è il demone stesso che non riesce a raggiungere la radio. Provalo con `rigctl -m 2 f` sulla macchina del demone.';
	@override String get flrigTroubleshootingTitle => 'Se l\'app non riesce a connettersi';
	@override String get flrigTroubleshooting => 'Questa voce si connette a un **programma flrig che avvii tu**, non direttamente alla radio — flrig comunica con la radio e supporta la maggior parte di marche e modelli.\n\n- **flrig deve essere già in esecuzione**, con il ricetrasmettitore configurato e connesso.\n- **La porta** è 12345 a meno che tu non l\'abbia cambiata nella configurazione di flrig (Config → Setup → Server).\n- **Da un\'altra macchina**, assicurati che il server di flrig sia raggiungibile. Ascolta su tutte le interfacce, ma il tuo firewall potrebbe non essere d\'accordo.\n- Una volta connesso, se manca la frequenza di solito è flrig stesso che non riesce a raggiungere la radio. Controlla che il display di flrig segua la manopola.';
	@override String get hrdTroubleshootingTitle => 'Se l\'app non riesce a connettersi';
	@override String get hrdTroubleshooting => 'Questa voce si connette a **Rig Control di Ham Radio Deluxe, in esecuzione sul tuo computer**, non direttamente alla radio — HRD comunica con la radio.\n\n- **Rig Control deve essere già in esecuzione** e connesso alla radio.\n- **Il suo IP server deve essere abilitato.** Rig Control comunica con gli altri programmi solo tramite questo.\n- **La porta** è 7809 a meno che tu non l\'abbia cambiata nelle impostazioni dell\'IP server.\n- **Da un\'altra macchina**, assicurati che il firewall lasci passare la connessione.\n\nQuesta voce è stata scritta a partire dalle descrizioni pubblicate del protocollo di HRD e non è stata provata con HRD. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get n3fjpTroubleshootingTitle => 'Se l\'app non riesce a connettersi';
	@override String get n3fjpTroubleshooting => 'Questa voce si connette a **un programma di logging N3FJP in esecuzione sul tuo computer**, non direttamente alla radio — N3FJP comunica con la radio.\n\n- **L\'API del programma deve essere attiva**: Settings → Application Program Interface, seleziona **TCP API Enabled**.\n- **La porta** è 1100 a meno che tu non l\'abbia cambiata lì.\n- **N3FJP deve avere un\'interfaccia radio configurata** per seguire o sintonizzare la radio. Senza, segnala solo ciò che viene digitato nella sua finestra di inserimento.\n- N3FJP segnala solo banda, modo e frequenza: niente potenza, niente stato di trasmissione.\n\nQuesta voce è stata scritta a partire dall\'API pubblicata di N3FJP e non è stata provata con N3FJP. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get commanderTroubleshootingTitle => 'Se l\'app non riesce a connettersi';
	@override String get commanderTroubleshooting => 'Questa voce si connette a **DXLab Commander, in esecuzione sul tuo computer**, non direttamente alla radio — Commander comunica con la radio.\n\n- **Commander deve essere già in esecuzione** e connesso alla radio.\n- **Il suo servizio di rete deve essere attivo**: il pulsante **Net Serv** nel pannello Radio della finestra Configuration di Commander.\n- **La porta** è 52002, la terza porta del blocco che inizia dalla **Base Port** di Net Serv (52000 a meno che tu non l\'abbia cambiata).\n- **Da un\'altra macchina**, assicurati che il firewall lasci passare la connessione.\n\nQuesta voce è stata scritta a partire dai messaggi TCP pubblicati di Commander e non è stata provata con Commander. Se funziona solo in parte, vale la pena segnalarlo.';
	@override String get ic705TroubleshootingTitle => 'Se la radio non risponde mai';
	@override String get ic705Troubleshooting => 'La radio ha una **sola** sessione di controllo remoto. Quando l\'accesso viene ignorato, quasi sempre qualcos\'altro la sta usando.\n\n- **Chiudi qualsiasi altro client.** wfview o RS-BA1 connessi alla stessa radio occupano quell\'unica sessione, e nel frattempo l\'accesso da qui viene semplicemente ignorato.\n- **Controlla le impostazioni di rete della radio.** La WLAN deve essere attiva, la radio deve essere sulla stessa rete e la sua funzione di controllo remoto (Network) deve essere abilitata.\n- **Le porte devono corrispondere** alla Control Port e alla Serial Port (UDP) della radio, o alle porte reindirizzate verso di esse. Una porta sbagliata viene accolta dal silenzio, come una radio spenta.\n- **Spegni e riaccendi la WLAN della radio** se resta bloccata. Questo libera in modo affidabile una sessione bloccata sulla radio.\n\nUna **password errata viene rifiutata esplicitamente**, non accolta dal silenzio. Se sei arrivato qui invece di vedere un messaggio di "rifiuto", il problema non è la password.';
	@override String get icomLanTroubleshooting => 'La radio ha una **sola** sessione di controllo remoto. Quando l\'accesso viene ignorato, quasi sempre qualcos\'altro la sta usando.\n\n- **Chiudi qualsiasi altro client.** wfview, RS-BA1 o la Remote Utility di Icom connessi alla stessa radio occupano quell\'unica sessione, e nel frattempo l\'accesso da qui viene semplicemente ignorato.\n- **Controlla le impostazioni di rete della radio.** La sua porta LAN deve essere collegata alla stessa rete di questo dispositivo, il suo **Network Control** deve essere attivo, e nome utente e password devono essere configurati come utente di rete sulla radio.\n- **Le porte devono corrispondere** alla Control Port e alla Serial Port (UDP) della radio, o alle porte reindirizzate verso di esse. Una porta sbagliata viene accolta dal silenzio, come una radio spenta.\n- **Se si connette ma non risponde mai**, l\'indirizzo CI-V qui deve corrispondere al menu CI-V ADDRESS della radio. Questa voce precompila l\'indirizzo di fabbrica del modello.\n- **Spegni e riaccendi la radio** se resta bloccata.';
	@override String get statusStale => 'Non risponde';
	@override String get statusDisconnected => 'Non connesso';
	@override String get statusConnecting => 'Connessione in corso…';
	@override String get statusDisconnecting => 'Disconnessione in corso…';
	@override String get statusError => 'Connessione non riuscita';
	@override String get currentRadioSettings => 'Impostazioni attuali della radio';
	@override String get notSupportedByThisRadio => 'Non supportato da questa radio';
	@override String get cwMessagesButton => 'Messaggi CW';
	@override String get voiceMessagesButton => 'Messaggi in Fonia';
	@override String voiceKeyerAvailable({required Object count}) => 'Keyer vocale: ${count} memorie nella radio';
	@override String get antennaBands => 'Bande';
	@override String get antennaType => 'Tipo di antenna';
	@override String get antennaTypeRequired => 'Scegli un tipo di antenna';
	@override late final _Translations$settings$station$antennaTypes$it antennaTypes = _Translations$settings$station$antennaTypes$it._(_root);
	@override String get keyType => 'Tipo di tasto';
	@override String get keyTypeRequired => 'Scegli un tipo di tasto';
	@override late final _Translations$settings$station$keyTypes$it keyTypes = _Translations$settings$station$keyTypes$it._(_root);
	@override String get softwareIntermediaries => 'Software intermediari';
	@override String get otherBrands => 'Altre marche';
	@override String get otherEquipment => 'Altri apparati (antenne, tasti, ecc.)';
	@override String get newAntenna => 'Nuova antenna';
	@override String get newKey => 'Nuovo tasto';
	@override String get newKeyer => 'WinKeyer (K1EL o compatibile)';
	@override String keyViaRadio({required Object radio}) => 'Keyer CAT in ${radio}';
	@override String keyOnDevice({required Object device}) => 'Tasto su ${device}';
	@override String get trackStationInfo => 'Registra le informazioni di stazione per ogni QSO';
	@override String get includeStationInfoInAdif => 'Includi nelle esportazioni ADIF';
	@override String get whatToTrack => 'Cosa registrare?';
	@override String get trackFieldRig => 'Ricetrasmettitore';
	@override String get trackFieldPower => 'Potenza';
	@override String get watts => 'Watt';
	@override String get trackFieldAntenna => 'Antenna';
	@override String get trackFieldKey => 'Tasto CW';
	@override String get placeholderConnectDelay => 'Ritardo di connessione (ms)';
	@override String get placeholderConnectDelayDescription => 'Quanto dura l\'handshake simulato. Vuoto o 0 si connette all\'istante.';
	@override String get placeholderDropAfter => 'Disconnetti dopo (secondi)';
	@override String get placeholderDropAfterDescription => 'Chiude la connessione da sola, per provare il percorso di riconnessione. Vuoto o 0 non si disconnette mai.';
	@override String get placeholderFailConnect => 'Fallisci sempre la connessione';
	@override String get placeholderConnectFailure => 'Alla radio segnaposto è stato detto di rifiutare questa connessione';
	@override String get placeholderFreq => 'Frequenza (kHz)';
	@override String get placeholderFreqDescription => 'Dove parte la radio segnaposto. In seguito riporta qualunque frequenza l\'app imposti.';
	@override String get placeholderMode => 'Modo';
	@override String get placeholderModeDescription => 'Il modo con cui parte la radio segnaposto, ad es. USB, CW, FT8.';
	@override String get placeholderPower => 'Potenza (watt)';
	@override String get placeholderPurpose => 'Usa questa radio per tenere traccia di quale apparato stai usando ai fini del logging';
	@override String get placeholderReplyDelay => 'Ritardo di risposta (ms)';
	@override String get placeholderReplyDelayDescription => 'Quanto impiega la radio segnaposto a riportare una modifica. Vuoto o 0 risponde subito.';
	@override String get cwKeyerField => 'Keyer CW via CAT';
	@override String get cwKeyerFieldDescription => 'Se questa radio trasmette CW da testo via CAT. Disattivato per un apparato che l\'app non conosce.';
	@override String get voiceMemories => 'Memorie vocali';
	@override String get voiceMemoriesDescription => 'Quante memorie vocali la radio riproduce via CAT. 0 per nessuna.';
	@override String get voiceMemoriesInvalid => 'Un numero intero, 0 o più';
	@override String get yaesuMeterCapture => 'Cattura le letture degli strumenti';
	@override String get yaesuBinaryMeterCaptureDescription => 'Legge lo strumento della potenza in uscita e l\'indicatore di SWR alto della radio durante la trasmissione e scrive i valori grezzi nel log. Serve a costruire la scala che Yaesu non pubblica — i valori non vengono mostrati come strumenti.';
	@override String get yaesuMeterCaptureDescription => 'Legge gli strumenti PO, SWR e ALC della radio durante la trasmissione e scrive i valori grezzi nel log. Serve a costruire la scala che Yaesu non pubblica — i valori non vengono mostrati come strumenti.';
	@override String get telemetryInterval => 'Intervallo di lettura degli strumenti (ms)';
	@override String get telemetryIntervalDescription => 'Ogni quanto leggere gli strumenti della radio durante la trasmissione. Lascia vuoto per la velocità massima che questa connessione può gestire, fino a 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Un numero intero di millisecondi, da ${min} a ${max}';
	@override String get pollInterval => 'Intervallo di interrogazione a riposo (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Ogni quanto chiedere alla radio frequenza e modo quando nessuno dei due cambia. Lascia vuoto per ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Un numero intero di millisecondi, da ${min} a ${max}';
	@override String get advancedSettings => 'Impostazioni avanzate';
	@override String get placeholderSwr => 'Lettura dell\'SWR';
	@override String get placeholderSwrDescription => 'Cosa riporta questa radio sul suo strumento dell\'SWR durante la trasmissione. Sopra 1,8 il pannello avvisa.';
	@override String get placeholderSwrInvalid => 'Un numero, 1 o più';
	@override String get keyerNone => 'Nessuno';
	@override String get cwDialect => 'Dialetto di manipolazione CW';
	@override String get cwDialectDescription => 'Quale forma del comando KY accetta questa radio. Nessuno significa nessuna manipolazione CW via CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, riempito a 24)';
	@override String get cwDialectElecraft => 'Elecraft (testo KY)';
	@override String get voiceDialect => 'Dialetto del keyer vocale';
	@override String get voiceDialectDescription => 'Come questa radio riproduce le sue memorie vocali via CAT. Nessuno significa nessuna memoria vocale via CAT. Con un dialetto e nessun numero, si applica il numero predefinito del dialetto.';
	@override String get voiceDialectPb => 'Kenwood (PB, stile TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB e DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (pressioni di tasti)';
	@override String get placeholderDiagnostic => 'Simulato';
	@override String get placeholderWholeNumberInvalid => 'Deve essere un numero intero, 0 o più';
	@override String get placeholderFreqInvalid => 'Deve essere una frequenza in kHz, maggiore di zero';
	@override String get placeholderModeInvalid => 'Deve essere il nome di un modo, ad es. USB, CW, FT8';
	@override String get switchLayout => 'Disposizione';
	@override String get switchLayoutDescription => 'Su quale lato del commutatore sono collegate le tue radio.';
	@override String get switchLayoutRequired => 'Scegli come è cablato il commutatore';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Il commutatore ha rifiutato "${command}" (errore ${code})';
	@override String get switchBusyTransmitting => 'Quella porta è in trasmissione — antenna non cambiata';
	@override String get switchNoAntenna => 'Nessuna';
	@override String switchAntennaFor({required Object port}) => 'Antenna sulla porta ${port}';
	@override String get switchAntennaForDescription => 'Quale delle tue antenne è collegata a questa porta del commutatore.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} Antenne, ${radios} Radio';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} Antenne, 1 Radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 Antenna, ${radios} Radio';
	@override String get switchCommonPort => 'Comune';
	@override String get dcnAddress => 'Indirizzo del dispositivo';
	@override String get dcnAddressDescription => 'L\'indirizzo impostato sui DIP switch del modulo. Un modulo relè coassiale esce di fabbrica con 2.';
	@override String get dcnAddressRequired => 'Deve essere un indirizzo di dispositivo da 1 a 99';
	@override String switchPortLabel({required Object port}) => 'Porta ${port}';
	@override String get switchPortAutoHint => 'segue i dati di banda';
	@override String get switchPortTransmittingHint => 'in trasmissione — impossibile cambiare ora';
	@override String get switchCurrentStateHeader => 'Stato attuale';
	@override String get switchCurrentStateDescription => 'Su quale antenna si trova ogni porta radio in questo momento. Le modifiche hanno effetto immediato.';
	@override String get switchWiringHeader => 'Cablaggio';
	@override String get switchPortInhibitedHint => 'trasmissione inibita';
	@override String get rotatorAxes => 'Assi';
	@override String get rotatorAxesDescription => 'Se il rotore ruota solo in azimut, o anche in elevazione (un G-5500 o simile).';
	@override String get rotatorAxesAzimuth => 'Solo azimut';
	@override String get rotatorAxesAzimuthElevation => 'Azimut ed elevazione';
	@override String get rotatorAzimuthOffset => 'Offset di azimut';
	@override String get rotatorAzimuthOffsetDescription => 'Gradi da aggiungere a ciò che legge il controller, quando il suo zero non è il nord vero. Le rotazioni vengono corrette di conseguenza.';
	@override String get rotatorElevationOffset => 'Offset di elevazione';
	@override String get rotatorAzimuthMin => 'Azimut minimo';
	@override String get rotatorAzimuthMax => 'Azimut massimo';
	@override String get rotatorAzimuthMaxDescription => 'Nei gradi del controller stesso. Sopra 360 per un rotore con sovrapposizione, che così compie la rotazione più breve.';
	@override String get rotatorElevationMin => 'Elevazione minima';
	@override String get rotatorElevationMax => 'Elevazione massima';
	@override String get rotatorElevationMaxDescription => 'Nei gradi del controller stesso. Sopra 90 per un rotore che si ribalta.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => 'Gradi interi, da ${min} a ${max}';
	@override String get rotatorLimitsInvalid => 'Il limite minimo deve essere inferiore al massimo';
	@override String get rotatorPollInterval => 'Intervallo di interrogazione (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'Ogni quanto chiedere al rotore dove punta. Lascia vuoto per ${fallback} ms.';
	@override String get rotatorAxesRequired => 'Scegli su quali assi ruota il rotore';
	@override String get rotatorRefused => 'Il controller ha rifiutato un comando. Controlla che sia impostato in modalità GS-232.';
	@override String get pstRotatorTroubleshooting => 'PstRotator risponde solo una volta configurato per farlo, altrimenti non dice assolutamente nulla:\n\n- **Attiva UDP Control** nel menu Setup di PstRotator.\n- **Fai corrispondere la porta**: Communication → UDP Control Port, 12000 se non cambiata. PstRotator risponde sulla porta successiva (12001), che deve essere libera su questo dispositivo.\n- **Collega PstRotator al suo controller.** Finché non lo è, non risponde nulla via UDP.\n- **Consentilo nel firewall** sul PC che esegue PstRotator, e su questo dispositivo, che ascolta le risposte.\n- **Su Mac, iPhone o iPad**, Ham2K Logger ha bisogno dell\'accesso alla Rete locale (Impostazioni → Privacy e sicurezza → Rete locale).';
	@override String rotatorCurrentStateHeader({required Object position}) => 'Stato attuale: ${position}';
	@override String get rotatorDisconnected => 'disconnesso';
	@override String rotatorAzimuthReading({required Object degrees}) => '${degrees}° azimut';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '${degrees}° az';
	@override String rotatorElevationReading({required Object degrees}) => '${degrees}° elevazione';
	@override String rotatorElevationReadingShort({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNoReading => 'In attesa che il controller comunichi la sua posizione…';
	@override String get rotatorNotResponding => 'non risponde';
	@override String rotatorHeldAtLimit({required Object heading}) => 'Rotazione verso ${heading}, fin dove i limiti di questo rotore lo consentono';
	@override String get rotatorTargetAzimuth => 'Ruota ad azimut';
	@override String get rotatorTargetAzimuthShort => 'Ruota ad az';
	@override String get rotatorTargetElevation => 'Ruota a elevazione';
	@override String get rotatorTargetElevationShort => 'Ruota a el';
	@override String get rotatorAzimuthInvalid => 'Deve essere da 0 a 360';
	@override String get rotatorElevationInvalid => 'Deve essere da 0 a 180';
	@override String get rotatorTurn => 'Ruota';
	@override String get rotatorStop => 'Stop';
	@override String get configUnreadable => 'Impossibile leggere le impostazioni salvate di questa radio. Apri le sue impostazioni e inseriscile di nuovo, oppure rimuovila e aggiungila di nuovo.';
	@override String get autoConnectHeld => 'HaLo ha smesso di rispondere l\'ultima volta che si è connesso a questa radio, quindi questa volta non si è connesso da solo. Premi Connetti per riprovare.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$it extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dati Fuori Rete';
	@override String get noFiles => 'Nessun file di dati';
	@override String get noFilesDescription => 'Abilita le estensioni di attività o di ricerca per scaricare qui i loro dati fuori rete.';
	@override String get refresh => 'Aggiorna';
	@override String get refreshing => 'Aggiornamento in corso…';
	@override String get updateAll => 'Aggiorna tutto';
	@override String get updatingAll => 'Aggiornamento di tutti i file di dati…';
	@override String get neverDownloaded => 'Mai scaricato';
	@override String get updatedJustNow => 'Aggiornato adesso';
	@override String updatedDaysAgo({required Object days}) => 'Aggiornato ${days}g fa';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Aggiornato ${days}g ${hours}h fa';
	@override String updatedHoursAgo({required Object hours}) => 'Aggiornato ${hours}h fa';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Aggiornato ${hours}h ${minutes}m fa';
	@override String updatedMinutesAgo({required Object minutes}) => 'Aggiornato ${minutes}m fa';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'L\'ultimo download conteneva solo ${imported} record su ${existing} e non è stato usato. Aggiorna per accettarlo.';
	@override String get extensionsSection => 'Estensioni';
}

// Path: settings.profiles
class _Translations$settings$profiles$it extends Translations$settings$profiles$en {
	_Translations$settings$profiles$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Non impostato';
	@override String get personalInfo => 'Informazioni personali';
	@override String get personalInfoNote => 'Queste informazioni potrebbero essere incluse nei log generati quando rilevanti per l\'invio';
	@override String get name => 'Nome';
	@override String get email => 'Email';
	@override String get club => 'Club';
	@override String get arrlSection => 'Sezione ARRL';
	@override String get racSection => 'Sezione RAC';
	@override String get section => 'Sezione';
}

// Path: settings.search
class _Translations$settings$search$it extends Translations$settings$search$en {
	_Translations$settings$search$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Cancella';
	@override String get hint => 'Cerca nelle preferenze';
}

// Path: settings.developer
class _Translations$settings$developer$it extends Translations$settings$developer$en {
	_Translations$settings$developer$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Abilita avvisi per sviluppatori, log di debug e strumenti.';
	@override String get experiments => 'Esperimenti';
	@override String get showIdleMetrics => 'Mostra metriche di inattività';
	@override String get showIdleMetricsDescription => 'Mostra nella barra di stato quanto è rimasto inattivo il motore delle estensioni nell\'ultimo secondo. Toccalo per le medie a 10 e 60 secondi.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% inattivo';
	@override String get idleMetricsAverages => 'Media inattività:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} abilitato',
		other: '${count} abilitati',
	);
	@override String get patchTrack => 'Canale Code Push';
	@override String get patchTrackDescription => 'Quale canale di code push over-the-air segue questo dispositivo. I canali più avventurosi ricevono le correzioni prima, ma meno testate. I code push si applicano al riavvio successivo.';
	@override String get trackStable => 'Stabile';
	@override String get trackUnstable => 'Instabile';
	@override String get trackBleeding => 'Bleeding';
	@override String checkingTrack({required Object track}) => 'Ricerca di un code push su "${track}"…';
	@override String get patchDownloaded => 'Code push scaricato — riavvia l\'app per applicarlo.';
	@override String noNewPatch({required Object track}) => 'Nessun nuovo code push su "${track}".';
	@override String get noPatchInstalled => 'Nessun code push installato — in esecuzione il binario della release.';
	@override String runningPatch({required Object patch}) => 'In esecuzione il code push #${patch}.';
	@override String get deepLinks => 'Deep link';
	@override String get registerUrlSchemes => 'Registra gli schemi URL';
	@override String get registerUrlSchemesDescription => 'Consenti ai link com.ham2k:// di aprire questa copia dell\'app';
	@override String get registerUrlSchemesDone => 'Questa copia ora apre i link com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Impossibile registrare: ${error}';
	@override String get systemInformation => 'Informazioni di Sistema';
	@override String get appVersion => 'Versione dell\'app';
	@override String get dataFolder => 'Cartella dei dati';
	@override String get loading => '(caricamento…)';
	@override String get panelLoadFailed => 'Impossibile caricare questo pannello delle impostazioni.';
	@override String get extDevServer => 'Server di sviluppo estensioni';
	@override String get extensionSettings => 'Impostazioni Estensioni';
	@override String get extDevServerDescription => 'Carica le estensioni da un server di sviluppo sulla tua rete invece di quelle integrate nell\'app, e ricaricale quando salvi.';
	@override String get extDevServerAddress => 'Indirizzo del server';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Connetti';
	@override String get extDevServerDisconnect => 'Disconnetti';
	@override String get extDevServerConnecting => 'Connessione in corso…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Fornisce ${count} estensione: ${keys}',
		other: 'Fornisce ${count} estensioni: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Non connesso';
	@override String get extDevServerReconnect => 'Riconnetti all\'avvio';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Ultimo ricaricamento: ${key} alle ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} estensione con errori di build',
		other: '${count} estensioni con errori di build',
	);
	@override String get catalog => 'Catalogo Estensioni';
	@override String get catalogDescription => 'Leggi il catalogo da un altro server — uno locale mentre lavori sul catalogo stesso. Vuoto significa catalog.ham2k.net.';
	@override String get catalogAddress => 'Indirizzo del catalogo';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Canali di ricerca del catalogo';
	@override String get catalogSearchStable => 'Solo Stabile';
	@override String get catalogSearchUnstable => 'Instabile o superiore';
	@override String get catalogSearchBleeding => 'Bleeding o superiore';
}

// Path: settings.about
class _Translations$settings$about$it extends Translations$settings$about$en {
	_Translations$settings$about$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Avvisi e Messaggi';
	@override String get noticesDescription => 'Annunci e messaggi di stato';
	@override String get releaseNotes => 'Note di rilascio';
	@override String get copiedVersion => 'Dettagli della versione copiati negli appunti';
}

// Path: settings.panels
class _Translations$settings$panels$it extends Translations$settings$panels$en {
	_Translations$settings$panels$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Preferenze dell\'applicazione';
	@override String get settingsDescription => 'Fai funzionare l\'app come vuoi tu';
	@override String get commonSettings => 'Preferenze comuni';
	@override String get syncDescription => 'Backup e sincronizzazione dei tuoi log tra i dispositivi';
	@override String get accountsDescription => 'Credenziali dei servizi, dati fuori rete e altro';
	@override String get extensions => 'Estensioni e Funzionalità';
	@override String get extensionsDescription => 'Attività, Contest, Pannelli Dashboard e altre funzionalità';
	@override String get profilesDescription => 'Nominativo operatore e profilo di stazione';
	@override String get stationProfiles => 'Profili di stazione';
	@override String get developerSettings => 'Impostazioni Sviluppatore';
	@override String get developerSettingsDescription => 'Strumenti di debug e sviluppo';
	@override String get about => 'Informazioni';
	@override String get aboutDescription => 'Versione, crediti e informazioni legali';
	@override String get unavailableTitle => 'Alcune impostazioni non sono disponibili';
	@override String get unavailableText => 'L\'ambiente delle estensioni non si è avviato, quindi mancano le impostazioni fornite dalle estensioni.';
	@override String get station => 'Configurazione Stazione';
	@override String get stationDescription => 'Controllo CAT e altre opzioni';
	@override String get peers => 'Dispositivi Peer';
	@override String get peersDescription => 'Connettiti ad altri dispositivi nelle vicinanze';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$it extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caratteri (FN31pr)';
	@override String get eight => '8 caratteri (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$it extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caratteri';
	@override String get eight => '8 caratteri';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$it extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'Apri la finestra dei comandi';
	@override String get toggleTheme => 'Passa da chiaro a scuro e viceversa';
	@override String get toggleLanguage => 'Passa da inglese a spagnolo e viceversa';
	@override String get fontScaleUp => 'Testo più grande';
	@override String get fontScaleDown => 'Testo più piccolo';
	@override String get fontScaleReset => 'Testo a dimensione normale';
	@override String get densityLooser => 'Layout più ampio';
	@override String get densityDenser => 'Layout più denso';
	@override String get densityAuto => 'Densità del layout automatica';
	@override String get find => 'Trova nel log';
	@override String keyerMessage({required Object n}) => 'Trasmetti il messaggio ${n}';
	@override String get keyboardMode => 'Attiva o disattiva la modalità tastiera';
	@override String get ptt => 'Push to talk';
	@override String get wipe => 'Cancella il contatto in inserimento';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$it extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'Digitare i nominativi';
	@override String get escape => 'Ferma la trasmissione, torna indietro di un passo o chiudi';
	@override String get enter => 'Registra il contatto';
	@override String get space => 'Campo successivo';
	@override String get tab => 'Campo successivo o precedente';
	@override String get arrows => 'Spostati tra campi, controlli e log';
	@override String get walk => 'Scorri il log pagina per pagina, o vai alle sue estremità';
	@override String get undo => 'Annulla una cancellazione o un\'eliminazione';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$it extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'Aggiungi Scorciatoia';
	@override String get listening => 'Premi i tasti per la scorciatoia…';
	@override String get listeningHint => 'Esc interrompe l\'ascolto';
	@override String get add => 'Aggiungi';
	@override String refusedFixed({required Object keys}) => '${keys} appartiene ai campi di logging o a una finestra di dialogo, e non può essere cambiato.';
	@override String refusedCallsign({required Object keys}) => '${keys} serve per digitare i nominativi. Tienilo premuto insieme a Cmd, Ctrl o Alt.';
	@override String reserved({required Object keys}) => 'Il sistema potrebbe intercettare ${keys} prima che l\'app lo veda.';
	@override String already({required Object keys}) => '${keys} è già uno dei tasti di questo comando.';
	@override String takeIt({required Object keys, required Object command}) => 'Togli ${keys} a “${command}”';
	@override String get resetDefault => 'Ripristina Predefinito';
	@override String get remove => 'Rimuovi';
	@override String get commandLabel => 'Comando';
	@override String get commandHint => 'Inserisci un comando valido, o più comandi separati da ";"';
	@override String get removeCommand => 'Rimuovi Comando';
	@override String commandUnknown({required Object text}) => 'Nessun comando interpreta “${text}”';
	@override String get noShortcuts => 'Ancora nessun tasto';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$it extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'Scorciatoie salvate in ${location}';
	@override String exportFailed({required Object error}) => 'Impossibile esportare le scorciatoie: ${error}';
	@override String importPickerFailed({required Object error}) => 'Impossibile aprire il file: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} non è un file di scorciatoie che questa app possa leggere: ${problem}';
	@override String problemNotYaml({required Object line}) => 'il testo non è YAML valido (riga ${line})';
	@override String get problemNotKeysFile => 'non è un file di scorciatoie da tastiera Ham2K';
	@override String get problemNewerVersion => 'è stato scritto da una versione più recente dell\'app';
	@override String get problemMalformed => 'una parte non rispetta il formato delle scorciatoie';
	@override String get problemTooLarge => 'è troppo grande';
	@override String get importTitle => 'Importa Scorciatoie';
	@override String writtenOn({required Object platform}) => 'Scritto su ${platform}.';
	@override String get writtenOnUnknown => 'Il file non dice su quale tastiera è stato scritto.';
	@override String get translate => 'A cosa deve corrispondere ciascuno di questi tasti su questa tastiera?';
	@override String get leaveOut => 'Escludi quelle scorciatoie';
	@override String get replace => 'Sostituisci la configurazione di questo dispositivo';
	@override String get replaceHint => 'Ogni scorciatoia non presente nel file torna al valore predefinito.';
	@override String get merge => 'Aggiungi alla configurazione di questo dispositivo';
	@override String get mergeHint => 'Le scorciatoie del file sostituiscono quelle di questo dispositivo per gli stessi comandi, e le altre restano.';
	@override String unknown({required Object commands}) => 'Sconosciuti in questa versione, quindi esclusi: ${commands}';
	@override String unreadableChords({required Object chords}) => 'Non sono scorciatoie, quindi esclusi: ${chords}';
	@override String refusedChords({required Object chords}) => 'Tasti che l\'app riserva a sé, quindi esclusi: ${chords}';
	@override String conflicts({required Object keys}) => 'Assegnati a più di un comando dopo l\'importazione: ${keys}';
	@override String get importAction => 'Importa';
	@override String get imported => 'Scorciatoie importate';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$it extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$it extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$it extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'Nominativi di stazione';
	@override String get groupBy => 'Raggruppa per';
	@override String get period => 'Periodo';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$it extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get none => 'Senza raggruppamento';
	@override String get date => 'Data';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'Continente sconosciuto';
	@override String get unknownEntity => 'Entità sconosciuta';
	@override String get unknownDate => 'Senza data';
}

// Path: home.logs.period
class _Translations$home$logs$period$it extends Translations$home$logs$period$en {
	_Translations$home$logs$period$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'Questo mese';
	@override String get last3Months => 'Ultimi 3 mesi';
	@override String get thisYear => 'Quest\'anno';
	@override String get lastYear => 'Anno scorso';
	@override String get allTime => 'Da sempre';
	@override String get custom => 'Intervallo personalizzato';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$it extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => '(${span})';
	@override String get custom => 'Intervallo personalizzato';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$it extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get date => 'Data';
	@override String get time => 'Ora';
	@override String get freq => 'Frequenza';
	@override String get mode => 'Modo';
	@override String get call => 'Nominativo';
	@override String get name => 'Nome';
	@override String get station => 'Stazione';
	@override String get band => 'Banda';
	@override String get sent => 'Inviato';
	@override String get rcvd => 'Ricev';
	@override String get grid => 'Locatore';
	@override String get state => 'Stato';
	@override String get country => 'Paese';
	@override String get refs => 'Ref';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$it extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Log QSO';
	@override String get qsosDescription => 'I QSO del nominativo selezionato, in tutte le operazioni.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Totale dei QSO, o la ricerca del nominativo del QSO selezionato.';
	@override String get map => 'Mappa';
	@override String get mapDescription => 'La posizione del QSO selezionato.';
}

// Path: home.logs.import
class _Translations$home$logs$import$it extends Translations$home$logs$import$en {
	_Translations$home$logs$import$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Nominativi: ${calls}';
	@override String get skippedOne => '1 record non leggibile';
	@override String skippedOther({required Object count}) => '${count} record non leggibili';
	@override String get readingTitle => 'Lettura del file ADIF…';
	@override String get checkingTitle => 'Verifica dei duplicati…';
	@override String get importingTitle => 'Importazione dei QSO…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} di ${total} verificati';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importati su ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$it extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'Predefinito';
	@override String untitledName({required Object number}) => 'Layout ${number}';
	@override String switcherLabel({required Object name}) => 'Layout: ${name}';
	@override String get menuNew => 'Nuovo…';
	@override String get menuExport => 'Esporta…';
	@override String get menuImport => 'Importa…';
	@override String get menuTitle => 'Layout';
	@override String get newTitle => 'Nuovo Layout';
	@override String get editTitle => 'Modifica Layout';
	@override String get edit => 'Modifica';
	@override String get duplicateCurrent => 'Duplica il layout attuale';
	@override String get startFromDefault => 'Parti dal layout predefinito';
	@override String get nameLabel => 'Nome';
	@override String get descriptionLabel => 'Descrizione';
	@override String get create => 'Crea';
	@override String leaveEditTitle({required Object name}) => 'Salvare le modifiche a "${name}"?';
	@override String get leaveEditBody => 'Questo layout ha modifiche che non hai salvato.';
	@override String get discard => 'Scarta';
	@override String get deleteTitle => 'Eliminare questo layout?';
	@override String deleteBody({required Object name}) => 'Sei sicuro di voler eliminare il layout "${name}"?';
	@override String get exportTitle => 'Esporta Layout';
	@override String get exportPick => 'Pannelli da esportare';
	@override String get tabSet => 'Gruppo di schede';
	@override String get exportAction => 'Esporta';
	@override String exported({required Object location}) => 'Layout salvato in ${location}';
	@override String exportFailed({required Object error}) => 'Impossibile esportare il layout: ${error}';
	@override String get importTitle => 'Importa Layout';
	@override String importFromOtherView({required Object view}) => 'Creato per la vista ${view}: i pannelli presenti solo in quella vista vengono esclusi.';
	@override String get viewHome => 'Home';
	@override String get viewOperation => 'Operazione';
	@override String get viewLogs => 'Log';
	@override String get viewChase => 'Caccia';
	@override String get importAsNew => 'Come nuovo layout';
	@override String get importReplace => 'Al posto di questo layout';
	@override String get importAdd => 'Aggiunto a questo layout';
	@override String get importAddHint => 'I pannelli vengono aggiunti in una nuova colonna a destra.';
	@override String get importPick => 'Pannelli da importare';
	@override String get importReplaceSettings => 'Sostituisci le impostazioni dei pannelli già configurati qui';
	@override String get importAction => 'Importa';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} non è un layout che questa app possa leggere: ${problem}';
	@override String problemNotYaml({required Object line}) => 'il testo non è YAML valido (riga ${line})';
	@override String get problemNotLayoutFile => 'non è un file di layout Ham2K';
	@override String get problemNewerVersion => 'è stato scritto da una versione più recente dell\'app';
	@override String get problemNoArrangement => 'non contiene alcuna disposizione';
	@override String get problemMalformed => 'una parte non rispetta il formato dei layout';
	@override String get problemTooLarge => 'è troppo grande';
	@override String importPickerFailed({required Object error}) => 'Impossibile aprire il file: ${error}';
	@override String importFailed({required Object error}) => 'Impossibile importare il layout: ${error}';
	@override String duplicateFailed({required Object error}) => 'Impossibile copiare il layout: ${error}';
	@override String get importNothing => 'Nessun pannello selezionato, quindi non è stato importato nulla.';
	@override String importSkipped({required Object panels}) => 'Esclusi: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'Mantenuto ${panels}: la disposizione per schermi piccoli non può farne a meno.';
	@override String get notOffered => 'Non disponibile in questa vista';
	@override String get alreadyPlaced => 'Già in questo layout';
	@override String needsExtension({required Object name}) => 'Richiede ${name}';
	@override String get listRecoveredTitle => 'Impossibile leggere i nomi dei layout';
	@override String get listRecoveredBody => 'Impossibile leggere l\'elenco dei layout di questa vista. Tutti i layout sono ancora qui, numerati al posto del nome.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$it extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Il log e i campi di inserimento';
	@override String get infoDescription => 'Cosa sappiamo della stazione collegata';
	@override String get spotsDescription => 'Spot dai cluster e dai programmi di attività';
	@override String get mapDescription => 'Dove si trovano i contatti';
	@override String get summariesDescription => 'Statistiche e punteggi dell\'operazione, nelle sezioni e nell\'ordine che scegli';
	@override String get summariesSections => 'Sezioni e Ordine';
	@override String get summariesDays => 'Ogni giorno';
	@override String get summariesReset => 'Mostra tutto';
	@override String get summariesAllHidden => 'Tutte le sezioni sono nascoste. Scegli quelle da mostrare nelle impostazioni di questo pannello.';
	@override String get clockDescription => 'Un orologio, in qualsiasi fuso orario';
	@override String get clockFace => 'Quadrante';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analogico';
	@override String get clockZone => 'Fuso orario';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Questo dispositivo';
	@override String get clockShowSeconds => 'Mostra secondi';
	@override String get weatherDescription => 'Condizioni attuali e delle prossime otto ore, dove stai operando';
	@override String get weatherUseOperationLocation => 'Usa la posizione dell\'operazione';
	@override String get weatherLocation => 'Posizione';
	@override String get weatherLocationDescription => 'Un locatore (FN31pr) o lat,lon. Ignorato quando \'Usa la posizione dell\'operazione\' è selezionato.';
	@override String get weatherNoLocation => 'Nessuna posizione impostata. Assegna una posizione a questo pannello nelle sue impostazioni, o mettilo in un\'operazione che ne ha una.';
	@override String weatherBadLocation({required Object location}) => 'Impossibile leggere la posizione ${location}. Usa un locatore come FN31pr, o 42.36,-71.06.';
	@override String get weatherUnreachable => 'Impossibile raggiungere Open-Meteo — nessuna rete? Nuovo tentativo a breve.';
	@override String get weatherUnreadable => 'Open-Meteo ha risposto, ma con dati non leggibili. Nuovo tentativo a breve.';
	@override String weatherGusts({required Object speed}) => 'raffiche ${speed}';
	@override String get panelAgeNow => 'adesso';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} min fa',
		other: '${count} min fa',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: '${count} ora fa',
		other: '${count} ore fa',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$it weatherConditions = _Translations$operation$layout$panels$weatherConditions$it._(_root);
	@override String get websiteDescription => 'Una pagina web a tua scelta, in un riquadro';
	@override String get websiteUrl => 'Indirizzo';
	@override String get websiteRefresh => 'Aggiorna';
	@override String get websiteRefreshNever => 'Mai';
	@override String get websiteRefresh1 => 'Ogni minuto';
	@override String get websiteRefresh5 => 'Ogni 5 minuti';
	@override String get websiteRefresh15 => 'Ogni 15 minuti';
	@override String get websiteTitle => 'Nome Pannello';
	@override String get websiteRefreshNow => 'Aggiorna ora';
	@override String get websiteNoUrl => 'Nessun indirizzo. Apri le impostazioni di questo pannello per scegliere una pagina.';
	@override String get websiteBadUrl => 'Non sembra un indirizzo web. Deve iniziare con https://';
	@override String get websiteNotHttps => 'Solo gli indirizzi https:// possono essere mostrati qui.';
	@override String get websiteUnsupported => 'Su questo sistema non si possono mostrare pagine web in un pannello.';
	@override String get websiteOpenExternally => 'Apri nel Browser';
	@override String websiteLoadFailed({required Object reason}) => 'Impossibile caricare la pagina: ${reason}';
	@override String get remoteScreenDescription => 'Uno schermo, un\'app o una finestra condivisi da un altro dei tuoi dispositivi.';
	@override String get remoteScreenTarget => 'Schermo';
	@override String get remoteScreenChoose => 'Scegli uno schermo…';
	@override String get remoteScreenPickerTitle => 'Schermi Condivisi';
	@override String get remoteScreenPickerEmpty => 'Nessuno dei tuoi dispositivi sta condividendo uno schermo. Attiva Condividi schermi e finestre in Impostazioni → Dispositivi Peer, sul dispositivo che vuoi vedere.';
	@override String get remoteScreenUnset => 'Nessuno schermo scelto. Apri le impostazioni di questo pannello per sceglierne uno condiviso dagli altri tuoi dispositivi.';
	@override String get remoteScreenConnecting => 'Connessione in corso…';
	@override String get remoteScreenPeerAway => 'Quel dispositivo non è connesso in questo momento.';
	@override String get remoteScreenNotOffered => 'Quel dispositivo ha smesso di condividere questo schermo.';
	@override String get remoteScreenNoListener => 'Quel dispositivo non accetta connessioni — controlla il suo firewall.';
	@override String get remoteScreenNoLan => 'Gli schermi sono condivisi solo sulla rete locale, non via Bluetooth.';
	@override String get remoteScreenRefused => 'Quel dispositivo non ha voluto condividere questo schermo.';
	@override String get remoteScreenSettings => 'Impostazioni pannello';
	@override String get remoteScreenAdjust => 'Regola Vista';
	@override String get remoteScreenDetail => 'Dettaglio';
	@override String get remoteScreenDetailStandard => 'Standard';
	@override String get remoteScreenDetailHigh => 'Alto';
	@override String get remoteScreenDetailMaximum => 'Massimo';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Ingrandisci';
	@override String get remoteScreenZoomOut => 'Riduci';
	@override String get remoteScreenStopped => 'Quello schermo o quella finestra non viene più mostrato.';
	@override String get remoteScreenCaptureFailed => 'Quel dispositivo non è riuscito a catturare lo schermo — potrebbe servire il permesso di Registrazione Schermo.';
	@override String get remoteScreenNoAnswer => 'Quel dispositivo non ha risposto. Potrebbe non avere la condivisione schermo attiva.';
	@override String get remoteScreenNoMedia => 'Impossibile aprire una connessione per l\'immagine. Controlla il firewall su questo dispositivo.';
	@override String get solarDescription => 'Condizioni solari e geomagnetiche, con la propagazione banda per banda';
	@override String get solarUnreachable => 'Impossibile raggiungere hamqsl.com — nessuna rete? Nuovo tentativo a breve.';
	@override String get solarUnreadable => 'hamqsl.com ha risposto, ma non con dati utilizzabili. Nuovo tentativo a breve.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Giorno';
	@override String get solarBandNight => 'Notte';
	@override String get solarBandGood => 'Buona';
	@override String get solarBandFair => 'Discreta';
	@override String get solarBandPoor => 'Scarsa';
	@override String solarSources({required Object primary, required Object secondary}) => 'Fonti: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'La connessione è in difficoltà — alcuni fotogrammi vengono saltati.';
	@override String get remoteScreenStalled => 'I fotogrammi non arrivano più — questa connessione potrebbe essere troppo lenta.';
	@override String get radioDescription => 'Il pannello frontale di una radio — frequenza, modo e potenza, sotto controllo CAT';
	@override String get radioStyle => 'Stile';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderno';
	@override String get radioRadio => 'Radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — nessuna radio designata';
	@override String get radioNoRadio => 'Nessuna radio da mostrare. Scegline una nelle impostazioni di questo pannello, o aggiungine una in Configurazione Stazione.';
	@override String get radioNotConfigured => 'Questa radio non è ancora configurata. Scegli la sua porta o indirizzo in Configurazione Stazione.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radio non connessa';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Connetti questa radio';
	@override String get radioDisconnect => 'Disconnetti questa radio';
	@override String get radioStale => 'NESSUN DATO';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR alto';
	@override String get rotatorDescription => 'Dove punta l\'antenna, su una mappa centrata sulla stazione. Tocca la mappa per ruotare l\'antenna.';
	@override String get rotatorRotator => 'Rotore';
	@override String rotatorAutoNamed({required Object name}) => 'Automatico — ${name}';
	@override String get rotatorAutoNone => 'Automatico — ancora nessun rotore';
	@override String get rotatorBeamWidth => 'Apertura del fascio';
	@override String get rotatorBeamWidthDescription => 'In gradi, disegnata attorno alla direzione. Con 0 non viene disegnata.';
	@override String get rotatorLocation => 'Posizione';
	@override String get rotatorLocationDescription => 'Un locatore, o latitudine e longitudine, su cui centrare la mappa. Vuoto usa la posizione dell\'operazione.';
	@override String get rotatorTheme => 'Tema';
	@override String get rotatorThemeColor => 'Colore';
	@override String get rotatorThemeGray => 'Grigio';
	@override String get rotatorThemeMuted => 'Attenuato';
	@override String get rotatorGrayline => 'Mostra la grayline';
	@override String get rotatorNoRotator => 'Nessun rotore da mostrare. Scegline uno nelle impostazioni di questo pannello, o aggiungine uno in Configurazione Stazione.';
	@override String get rotatorNoLocation => 'Nessuna posizione su cui centrare la mappa. Impostane una nelle impostazioni di questo pannello.';
	@override String get rotatorDisconnected => 'disconnesso';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => 'non risponde';
	@override String get rotatorLocationInvalid => 'Impossibile leggere la posizione nelle impostazioni di questo pannello. Usa un locatore, o latitudine e longitudine come 40.7, -74.0.';
	@override String rotatorElevation({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'W';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$it extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usa nomi di file compatti';
	@override String get descriptionOn => 'Nomi brevi pensati per i sistemi di caricamento, come N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nomi leggibili, come 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$it extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Includi informazioni private';
	@override String get descriptionOn => 'Nomi, indirizzi, email, locatori e note sono inclusi';
	@override String get descriptionOff => 'Nomi, indirizzi, email, locatori e note sono esclusi';
	@override String get note => 'L\'esportazione ADIF completa include sempre tutto';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$it extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Prima aggiungi un indirizzo email';
	@override String get needsEmailBody => 'L\'Archivio File di Ham2K invia i tuoi file all\'indirizzo email del tuo account LoFi, con cui accedi a stash.ham2k.net. Il tuo account non ne ha ancora uno confermato — aggiungilo in Impostazioni › Sincronizzazione Cloud.';
	@override String get openSyncSettings => 'Apri Sincronizzazione Cloud';
	@override String get replaceTitle => 'L\'archivio recente verrà sostituito';
	@override String replaceBody({required Object name}) => 'Hai inviato “${name}” meno di 6 ore fa e non è stato ancora scaricato. Gli account gratuiti conservano un solo archivio alla volta, quindi inviare ora lo sostituisce.';
	@override String get replaceConfirm => 'Invia lo stesso';
	@override String get failedTitle => 'Impossibile inviare all\'Archivio File di Ham2K';
	@override String get sentTitle => 'Inviato all\'Archivio File di Ham2K';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Puoi recuperare questo file visitando **[stash.ham2k.net](https://stash.ham2k.net)** da qualsiasi browser.',
		other: 'Puoi recuperare questi file visitando **[stash.ham2k.net](https://stash.ham2k.net)** da qualsiasi browser.',
	);
	@override String get mayHaveArrived => 'Nessuna risposta dall\'archivio — il file potrebbe essere arrivato comunque. Controlla stash.ham2k.net prima di inviare di nuovo';
	@override String get notSent => 'non inviato';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Questo file non è arrivato:',
		other: 'Questi ${count} file non sono arrivati:',
	);
	@override String get emailOffer => 'Oppure, per tua comodità, possiamo inviarti un\'email con un link diretto.';
	@override String get emailMe => 'Inviami un link via email';
	@override String get emailSent => 'Ti abbiamo inviato un link per il download.';
	@override String emailFailed({required Object error}) => 'Impossibile inviare l\'email: ${error}';
	@override String get freeTier => 'Gli account gratuiti possono conservare un solo archivio alla volta. Gli abbonati possono conservarne quanti ne vogliono.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count,
		one: 'Inviato ${count} file all\'Archivio File di Ham2K (stash.ham2k.net)',
		other: 'Inviati ${count} file all\'Archivio File di Ham2K (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$it extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get af => 'Africa';
	@override String get as => 'Asia';
	@override String get eu => 'Europa';
	@override String get na => 'Nord America';
	@override String get oc => 'Oceania';
	@override String get sa => 'Sud America';
	@override String get an => 'Antartide';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$it extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtra Spot';
	@override String get band => 'Banda';
	@override String get mode => 'Modo';
	@override String get age => 'Durata';
	@override String get sources => 'Fonti';
	@override String get continent => 'Continente';
	@override String get sorting => 'Ordinamento';
	@override String get sortByTime => 'Per orario spot';
	@override String get sortByFrequency => 'Per frequenza';
	@override String get sortByWanted => 'Più ricercati';
	@override String get groupByBand => 'Raggruppa per Banda';
	@override String get groupCallsWithNotes => 'Raggruppa i Nominativi con annotazioni';
	@override String get alertingOnly => 'Solo Spot con avvisi';
	@override String get sourceNoReply => 'Nessuna risposta';
	@override String get sourceError => 'Errore';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$it extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Il pannello di logging è occupato';
	@override String get editingBody => 'Stai modificando un contatto registrato. Registrare invece questo spot, o tornare indietro e finire la modifica?';
	@override String get composingBody => 'Hai iniziato a inserire un contatto. Registrare invece questo spot, o tornare indietro e finire quello che stavi scrivendo?';
	@override String get goBack => 'Torna indietro';
	@override String get clearAndLog => 'Cancella e registra lo spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$it extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modalità Mancina';
	@override String get descriptionOn => 'Usa il layout per mancini';
	@override String get descriptionOff => 'Usa il layout per destrimani';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$it extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bandiere dei Paesi';
	@override String get dx => 'Mostra solo per i contatti DX';
	@override String get all => 'Mostra le bandiere per tutti i contatti';
	@override String get none => 'Non mostrare alcuna bandiera';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$it extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Mostra le bandiere solo per i contatti DX';
	@override String get all => 'Mostra le bandiere per tutti i contatti';
	@override String get none => 'Non mostra alcuna bandiera';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$it extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Suggerisci Operatore';
	@override String get descriptionOn => 'Propone il tuo nominativo come operatore quando un\'operazione usa un nominativo di stazione diverso';
	@override String get descriptionOff => 'Lascia vuoto l\'operatore se non lo compili tu';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$it extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra Direzione';
	@override String get descriptionOn => 'Mostra la direzione stimata verso la stazione';
	@override String get descriptionOff => 'Non mostra informazioni sulla direzione';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$it extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra anche la direzione inversa';
	@override String get descriptionOn => 'Mostra anche la direzione dalla stazione, come "45° / 225°"';
	@override String get descriptionOff => 'Mostra solo la direzione verso la stazione';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$it extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inverti ordine del rapporto (RST)';
	@override String get sentFirst => 'Inviato prima, Ricevuto dopo';
	@override String get rcvdFirst => 'Ricevuto prima, Inviato dopo';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$it extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Salta al campo successivo dopo l\'RST';
	@override String get descriptionOn => 'Passa al campo successivo dopo l\'inserimento dell\'RST';
	@override String get descriptionOff => 'Non passa automaticamente';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$it extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rapporto predefinito — Fonia';
	@override String get description => 'Usato quando Inviato o Ricevuto è vuoto in SSB, FM o AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$it extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rapporto predefinito — CW e digitali';
	@override String get description => 'Usato quando Inviato o Ricevuto è vuoto in CW, RTTY e altri modi digitali';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$it extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rapporto predefinito — FT8 e FT4';
	@override String get description => 'Usato quando Inviato o Ricevuto è vuoto nei modi FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$it extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Riga numerata';
	@override String get description => 'Mostra una riga di tasti numerici sopra la tastiera durante il logging';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$it extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tasto barra e punto';
	@override String get description => 'Aggiunge un tasto contestuale: “/” per i nominativi, “.” per i numeri';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$it extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibra alla pressione dei tasti';
	@override String get description => 'Feedback aptico quando tocchi un tasto numerico';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$it extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get off => 'Disabilitato';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$it extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'nessun nominativo operatore con cui accedere';
	@override String get connectFailed => 'impossibile raggiungere il nodo';
	@override String get needsPassword => 'il nodo chiede una password, e non ne è memorizzata nessuna';
	@override String get loginFailed => 'il nodo non ha accettato il login';
	@override String get disconnected => 'il nodo ha chiuso la connessione';
	@override String get timeout => 'il nodo non ha risposto';
	@override String get off => 'Connetti al cluster è disattivato';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$it extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$it extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlla il PTT con la tastiera';
	@override late final _Translations$settings$radio$pttKey$modes$it modes = _Translations$settings$radio$pttKey$modes$it._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$it descriptions = _Translations$settings$radio$pttKey$descriptions$it._(_root);
	@override String get key => 'Tasto PTT';
	@override String get pill => 'TX';
	@override String get transmitting => 'In trasmissione';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$it extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggancio VFO intelligente';
	@override String get descriptionOn => 'Quando smetti di girare la manopola, arrotonda la frequenza a un passo sensato. Solo modi in fonia.';
	@override String get descriptionOff => 'Resta esattamente dove hai sintonizzato.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$it extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggancio: ritardo di assestamento';
	@override String get description => 'Quanto deve restare ferma la manopola prima che la frequenza venga arrotondata. Più breve è immediato; più lungo lascia spazio a un movimento lento.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$it extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggancio: movimento lungo';
	@override String get description => 'Spostandosi almeno di questa quantità la frequenza si arrotonda a un kHz intero, per quanto lentamente tu abbia finito.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$it extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggancio: movimento minimo';
	@override String get description => 'Spostandosi meno di questa quantità la frequenza non viene arrotondata, così la sintonia fine non viene toccata.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$it extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aggancio: movimento più lento';
	@override String get description => 'Girando la manopola più lentamente di così la frequenza non viene arrotondata, a meno che non sia un movimento lungo.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$it extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Off';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Invio trasmette i messaggi';
	@override String get off => 'Off';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Invio trasmette i messaggi: ${state}. Tocca per cambiare.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$it extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Velocità del keyer';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$it extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Messaggi del Keyer CW';
	@override String get notSupported => 'La radio attuale non supporta la manipolazione CW';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Messaggio ${n}';
	@override String get labelField => 'Etichetta';
	@override String labelKey({required Object n}) => 'Etichetta F${n}';
	@override String get details => 'Dettagli';
	@override String get empty => '(vuoto)';
	@override String get sets => 'Set di messaggi';
	@override String get newSet => 'Nuovo Set';
	@override String get renameSet => 'Rinomina Set';
	@override String get deleteSet => 'Elimina Set';
	@override String get newSetName => 'Nome';
	@override String get setDefault => 'Predefinito';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Messaggi ESM';
	@override String get setSaved => 'I miei messaggi';
	@override String get repeat => 'Ripeti Messaggio 1';
	@override String get repeatShort => 'Ripeti M1';
	@override String get cooldown => 'Pausa prima della ripetizione';
	@override String cooldownSeconds({required Object n}) => '${n} secondi';
	@override String get repeatWait => 'In ripetizione';
	@override String get keyboard => 'Scrivi per trasmettere';
	@override String get keyboardField => 'Scrivi per trasmettere';
	@override String get help => 'Aiuto';
	@override String get helpTitle => 'Scrivere i messaggi CW';
	@override String get helpIntro => 'I messaggi possono usare modelli con i seguenti valori:';
	@override String get helpOpCall => 'Il tuo nominativo';
	@override String get helpQsoCall => 'Il loro nominativo — in uno stack //, il nominativo che verrà registrato';
	@override String get helpQsoFullCall => 'Il loro nominativo, se è un nominativo valido; vuoto se parziale';
	@override String get helpQsoPartial => 'Un nominativo parziale; vuoto se c\'è un nominativo completo valido';
	@override String get helpQsoNextCall => 'In uno stack //, il nominativo che verrà selezionato per la prossima registrazione, se è un nominativo completo valido';
	@override String get helpQsoNextPartial => 'In uno stack //, il prossimo parziale dopo aver registrato il contatto attuale';
	@override String get helpQsoName => 'Il loro nome, come digitato o altrimenti dalla ricerca';
	@override String get helpQsoState => 'Il loro stato, come digitato o altrimenti dalla ricerca';
	@override String get helpKeyerMsg => 'Il messaggio 1 come verrebbe trasmesso, dentro un altro messaggio. Valido per i messaggi da 1 a 8';
	@override String get helpQsoRst => 'Il rapporto che stai inviando';
	@override String get helpQsoSerial => 'Il tuo numero progressivo, in un contest che lo prevede';
	@override String get helpPad => 'Riempie con zeri fino a quel numero di cifre: 7 viene trasmesso come 007';
	@override String get helpCut => 'Numeri abbreviati, T per 0 e N per 9: 599 viene trasmesso come 5NN';
	@override String get helpCutDigits => 'Sceglie le cifre da abbreviare, tra virgolette — 0 è T, 1 è A, 5 è E, 9 è N';
	@override String get helpFullExample => 'Esempio completo:';
	@override String get helpExample => 'Trasmette W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Con Invio trasmette i messaggi attivo, Invio trasmette i messaggi in base al loro tasto funzione, come fa N1MM. Il set Messaggi ESM parte con questi:';
	@override String get helpEsmCq => 'In Run, Invio con il campo nominativo vuoto chiama CQ';
	@override String get helpEsmExchange => 'Il tuo scambio: dopo il loro nominativo in Run, dopo la loro risposta in S&P';
	@override String get helpEsmThanks => 'Ringraziamento, una volta registrato il contatto: qso è il contatto appena registrato, next quello successivo';
	@override String get helpEsmMyCall => 'In S&P, il tuo nominativo verso la stazione a cui rispondi';
	@override String get helpEsmHisCall => 'In Run, il loro nominativo prima del tuo scambio';
	@override String get helpEsmAgain => 'Chiede di ripetere quando non è stato copiato nulla del loro scambio';
	@override String get helpEsmStackThanks => 'F3 suggerito per gli stack //: ringrazia, poi chiama la stazione successiva nello stack e trasmette il tuo scambio, o chiede di ripetere un parziale (TU KR?); se non resta nulla, solo TU';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$it extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get label => 'Keyer';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => 'Voce';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$it extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Messaggi del Keyer in Fonia';
	@override String get notSupported => 'La radio attuale non supporta i messaggi in fonia';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memoria vocale ${n}';
	@override String get labelField => 'Etichetta';
	@override String labelKey({required Object n}) => 'Etichetta memoria vocale ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Vuota';
	@override String get notMeasured => 'Durata sconosciuta';
	@override String get playButton => 'Riproduci';
	@override String get recordButton => 'Registra';
	@override String get stopButton => 'Stop';
	@override String get repeat => 'Ripeti Messaggio 1';
	@override String recordHelpTitle({required Object model}) => 'Note su ${model}:';
	@override String namedOnDevice({required Object device}) => 'Queste memorie sono nella radio di ${device}. I loro nomi e durate appartengono a quel dispositivo.';
	@override String get namedOnRadio => 'Salvato nella radio, dove lo vedono anche gli altri suoi client.';
	@override String get recordHelpYaesuDvs => 'Attendi l\'indicatore [REC] sulla radio, poi tieni premuto il PTT e registra il messaggio. Terminalo premendo il pulsante STOP qui nell\'app prima di rilasciare il PTT per evitare click indesiderati.';
	@override String get recordHelpFt891 => 'Attendi che l\'indicatore [REC] lampeggi almeno quattro volte, poi tieni premuto il PTT e registra il messaggio. Terminalo premendo il pulsante STOP qui nell\'app prima di rilasciare il PTT per evitare click indesiderati.';
	@override String get pill => 'Voce';
	@override String play({required Object n}) => 'Riproduci memoria ${n}';
	@override String get stop => 'Stop';
	@override String record({required Object n}) => 'Registra memoria ${n}';
	@override String get stopRecording => 'Ferma registrazione';
	@override String get playing => 'Riproduzione…';
	@override String get recording => 'Registrazione…';
	@override String recordingMemory({required Object label}) => 'Registrazione di ${label}';
	@override String get doubtful => 'La radio l\'ha riprodotto? Ha segnalato subito di essere inattiva.';
	@override String get recordOnRadio => 'Le memorie vanno registrate sulla radio stessa.';
	@override String get sets => 'Set di messaggi';
	@override String get soundFilesSet => 'File audio su questo computer';
	@override String get openFileButton => 'Apri File';
	@override String get newSet => 'Nuovo Set';
	@override String get renameSet => 'Rinomina Set';
	@override String get deleteSet => 'Elimina Set';
	@override String get newSetName => 'Nome';
	@override String deleteSetConfirm({required Object name}) => 'Eliminare ${name} e le sue registrazioni? Non può essere annullato.';
	@override String get output => 'Invia l\'audio a';
	@override String get input => 'Registra da';
	@override String get outputRadio => 'Invia alla radio via rete';
	@override String get inputDefault => 'Predefinito di sistema';
	@override String get pickDevice => 'Scegli un dispositivo audio';
	@override String deviceMissing({required Object name}) => '${name} (non connesso)';
	@override String get lead => 'Ritardo dopo il PTT';
	@override String get tail => 'Ritardo prima del rilascio';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => 'Ascolta';
	@override String get notRecorded => 'Non registrato';
	@override String get unplayable => 'Impossibile riprodurre questo file';
	@override String get problemNoOutput => 'Scegli il dispositivo audio che alimenta la radio prima di riprodurre un messaggio.';
	@override String get problemOutputMissing => 'Il dispositivo audio che alimenta la radio non è connesso.';
	@override String get problemInputMissing => 'Il dispositivo di registrazione non è connesso.';
	@override String get problemDeviceFailed => 'Il dispositivo audio non si è aperto.';
	@override String get problemNotRecorded => 'Quel messaggio non ha ancora una registrazione.';
	@override String get problemRecordingSilent => 'Dal dispositivo di registrazione non è arrivato nulla, quindi il messaggio è rimasto com\'era. Controlla l\'ingresso, e che l\'app sia autorizzata a usare il microfono.';
	@override String get problemRadioAudioUnavailable => 'Al momento la radio non riceve audio dall\'app. Serve una connessione di rete alla radio.';
	@override String get problemSourceRefused => 'La radio non ha commutato l\'audio di trasmissione sull\'app, quindi il messaggio si è fermato. Imposta la radio per trasmettere l\'audio dell\'app.';
	@override String get problemCannotKey => 'Questa radio non può essere messa in trasmissione via CAT, quindi il computer non può riprodurle i messaggi.';
	@override String get problemUnplayable => 'Il file di quel messaggio non è un file audio che l\'app possa riprodurre. Usa un file WAV, FLAC o MP3, oppure registralo di nuovo.';
	@override String get problemRecordingFailed => 'La registrazione si è interrotta, quindi il messaggio è rimasto com\'era. Controlla che il dispositivo di registrazione sia ancora connesso e che ci sia spazio sul disco.';
	@override String get problemFileFailed => 'Impossibile salvare la registrazione al posto del messaggio, che è rimasto com\'era.';
	@override String problemWordsMissing({required Object words}) => 'Quel messaggio richiede parole che non hai registrato: ${words}.';
	@override String problemTemplateFailed({required Object error}) => 'Il modello di quel messaggio ha un problema: ${error}';
	@override String get problemNoOperation => 'I messaggi detti con le tue parole si riproducono in un\'operazione, dove c\'è un contatto per cui dirli.';
	@override String get problemNothingSaid => 'Quel messaggio non dice nulla per questo contatto.';
	@override String get templateField => 'Pronuncia con le mie parole';
	@override String get templateHelp => 'Lascia vuoto per riprodurre la registrazione. Altrimenti il messaggio viene detto con le parole che hai registrato, compilato per ogni contatto, usando questi valori:';
	@override String get help => 'Aiuto';
	@override String get helpTitle => 'Dire i messaggi con le tue parole';
	@override String get helpFullExample => 'Un messaggio completo:';
	@override String get helpExample => 'Il loro nominativo, il loro rapporto e la tua registrazione di “QSL?”';
	@override String get playOnRadio => 'Riproduci sulla Radio';
	@override String get templateHelpCall => 'Il loro nominativo';
	@override String get templateHelpReport => 'Il rapporto che gli dai';
	@override String get templateHelpMessage => 'La registrazione del messaggio 2, riprodotta così com\'è';
	@override String get voiced => 'Detto con le tue parole';
	@override String willSay({required Object words}) => 'Dice: ${words}';
	@override String willSayMissing({required Object words}) => 'Non ancora registrate: ${words}';
	@override String get previewNoOperation => 'Apri un\'operazione per vedere cosa dirà.';
	@override String get wordsDescription => 'Usa la tua voce per nominativi, numeri e altro.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$it extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registrazioni delle parole';
	@override String get callField => 'Parole per l\'operatore';
	@override String get intro => 'Registra ogni parola o numero tre volte, di seguito e velocemente, come lo diresti in un nominativo. Le frasi più lunghe si registrano una volta sola.';
	@override String get recordAll => 'Registra Tutto';
	@override String get recordAllGuide => 'Leggi ogni parola tre volte, di seguito, e una frase di più parole una volta sola, con una pausa di respiro tra le righe. Premi Stop dopo l\'ultima.';
	@override String recordingOne({required Object word}) => 'Di\' “${word} ${word} ${word}”, poi premi Stop.';
	@override String recordingOnce({required Object words}) => 'Di\' “${words}”, poi premi Stop.';
	@override String get recorded => 'Registrata';
	@override String get notRecorded => 'Non registrata';
	@override String get addPhrase => 'Aggiungi Frase';
	@override String get phraseField => 'Frase, come la scrivi in un messaggio';
	@override String get deletePhrase => 'Elimina frase';
	@override String get tryField => 'Prova a dire';
	@override String get pauseLetters => 'Pausa tra le lettere';
	@override String get pauseWords => 'Pausa tra le parole';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => 'Velocità';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => 'Impostazioni avanzate';
	@override String get splitSilent => 'Nella registrazione non si sente nulla.';
	@override String get splitNotThreeTakes => 'Impossibile trovare tre ripetizioni. Di\' la parola tre volte, di seguito, e riprova.';
	@override String get splitLineCount => 'Impossibile trovare tutte le parole nella lettura. Leggi ognuna tre volte, con una pausa di respiro tra le parole.';
	@override String get splitLinesTooClose => 'Impossibile distinguere le parole. Lascia una pausa più lunga tra le parole.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$it extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evita lo zero-beat sugli spot';
	@override String get descriptionOn => 'Con una radio connessa, sintonizza qualche Hz fuori da uno spot CW, così chi risponde non chiama tutto sulla stessa nota.';
	@override String get descriptionOff => 'Sintonizza esattamente sulla frequenza dello spot.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$it extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zero-beat: intervallo di scostamento';
	@override String get description => 'Quanto lontano dalla frequenza dello spot posizionarsi, da entrambi i lati. Lo scostamento non è mai vicino a zero — sarebbe di nuovo uno zero beat.';
}

// Path: settings.map.style
class _Translations$settings$map$style$it extends Translations$settings$map$style$en {
	_Translations$settings$map$style$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stile della mappa';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$it extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra Nominativi';
	@override String get description => 'Ogni contatto è un\'etichetta con il suo nominativo, nel colore della sua banda';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$it extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostra Grayline';
	@override String get description => 'Ombreggia il lato notturno della Terra, con il crepuscolo come gradiente';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$it extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatico';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$it extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Condividi i dati di utilizzo dell\'app';
	@override String get descriptionOn => 'Ci aiuta a migliorare l\'app condividendo dati di utilizzo, configurazione, arresti anomali e prestazioni';
	@override String get descriptionOff => 'Mantiene privati i dati sull\'utilizzo dell\'app.\nIl team Ham2K non sarà in grado di rilevare arresti anomali o altri problemi.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$it extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Condividi i dati dell\'operazione';
	@override String get descriptionOn => 'Condivide alcuni dati dell\'operazione pubblicamente e con altri utenti';
	@override String get descriptionOff => 'Mantiene privati i dati dell\'operazione';
}

// Path: settings.station.models
class _Translations$settings$station$models$it extends Translations$settings$station$models$en {
	_Translations$settings$station$models$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Generica';
	@override String get icomGeneric => 'Icom - Generica';
	@override String get kenwoodGeneric => 'Kenwood - Generica';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Generica';
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
	@override String get rigctld => 'Radio controllata via rigctld';
	@override String get rigctldNodeName => 'La mia radio (via rigctld)';
	@override String get flrig => 'Radio controllata via flrig';
	@override String get flrigNodeName => 'La mia radio (via flrig)';
	@override String get hrd => 'Radio controllata via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'La mia radio (via HRD)';
	@override String get n3fjp => 'Radio controllata via N3FJP';
	@override String get n3fjpNodeName => 'La mia radio (via N3FJP)';
	@override String get commander => 'Radio controllata via DXLab Commander';
	@override String get commanderNodeName => 'La mia radio (via Commander)';
	@override String get antenna => 'Antenna';
	@override String get key => 'Tasto CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Radio generica (segnaposto)';
	@override String get placeholderRadioNodeName => 'La mia radio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Commutatore coassiale Sierra Radio CX-1';
	@override String get gs232a => 'Interfaccia rotore Yaesu GS-232A';
	@override String get pstRotator => 'PstRotator (controllo UDP)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$it extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get network => 'Rete/WiFi';
	@override String get secureNetwork => 'Rete/WiFi sicura';
	@override String get usbSerial => 'Seriale USB';
	@override String get wifi => 'Rete/WiFi';
	@override String get bluetoothSerial => 'Seriale Bluetooth';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'Segnaposto';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$it extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipolo';
	@override String get vertical => 'Verticale';
	@override String get yagiBeam => 'Yagi / Direttiva';
	@override String get loop => 'Loop';
	@override String get longWire => 'Filare / EFHW';
	@override String get other => 'Altro';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$it extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Tasto verticale';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semiautomatico meccanico)';
	@override String get fullyAutomatic => 'Keyer completamente automatico';
	@override String get singlePaddle => 'Paddle singolo';
	@override String get dualPaddle => 'Paddle doppio';
	@override String get computerDriven => 'Gestito da computer';
	@override String get other => 'Altro';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$it extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Sconosciuto';
	@override String get sunny => 'Soleggiato';
	@override String get clear => 'Sereno';
	@override String get mainlySunny => 'Prevalentemente soleggiato';
	@override String get mainlyClear => 'Prevalentemente sereno';
	@override String get partlyCloudy => 'Parzialmente nuvoloso';
	@override String get cloudy => 'Nuvoloso';
	@override String get foggy => 'Nebbia';
	@override String get rimeFog => 'Nebbia con brina';
	@override String get lightDrizzle => 'Pioviggine leggera';
	@override String get drizzle => 'Pioviggine';
	@override String get heavyDrizzle => 'Pioviggine intensa';
	@override String get lightFreezingDrizzle => 'Pioviggine gelata leggera';
	@override String get freezingDrizzle => 'Pioviggine gelata';
	@override String get lightRain => 'Pioggia leggera';
	@override String get rain => 'Pioggia';
	@override String get heavyRain => 'Pioggia intensa';
	@override String get lightFreezingRain => 'Pioggia gelata leggera';
	@override String get freezingRain => 'Pioggia gelata';
	@override String get lightSnow => 'Neve leggera';
	@override String get snow => 'Neve';
	@override String get heavySnow => 'Neve intensa';
	@override String get snowGrains => 'Neve granulosa';
	@override String get lightShowers => 'Rovesci leggeri';
	@override String get showers => 'Rovesci';
	@override String get heavyShowers => 'Rovesci intensi';
	@override String get lightSnowShowers => 'Rovesci di neve leggeri';
	@override String get snowShowers => 'Rovesci di neve';
	@override String get thunderstorm => 'Temporale';
	@override String get lightThunderstormsWithHail => 'Temporali leggeri con grandine';
	@override String get thunderstormWithHail => 'Temporale con grandine';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$it extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get off => 'No';
	@override String get toggle => 'Alterna';
	@override String get hold => 'Tieni premuto';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$it extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$it._(TranslationsIt root) : this._root = root, super.internal(root);

	final TranslationsIt _root; // ignore: unused_field

	// Translations
	@override String get off => 'La tastiera non mette in trasmissione la radio.';
	@override String get toggle => 'Nei modi in fonia, il tasto PTT mette in trasmissione la radio e premendolo di nuovo la rimette in ricezione. Torna in ricezione da sola dopo un minuto.';
	@override String get hold => 'Nei modi in fonia, la radio trasmette finché il tasto PTT resta premuto, per al massimo un minuto.';
}

/// The flat map containing all translations for locale <it>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsIt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Salva',
			'common.ok' => 'OK',
			'common.cancel' => 'Annulla',
			'common.delete' => 'Elimina',
			'common.create' => 'Crea',
			'common.error' => 'Errore',
			'common.close' => 'Chiudi',
			'common.done' => 'Fatto',
			'common.callsign' => 'Nominativo',
			'common.clear' => 'Cancella',
			'common.dismiss' => 'Ignora',
			'common.copyDetails' => 'Copia dettagli',
			'common.expand' => 'Espandi',
			'common.collapse' => 'Comprimi',
			'onboarding.welcomeTitle' => 'Benvenuto in Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Benvenuto in Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Abbiamo alcune domande per adattarci meglio alle tue esigenze.',
			'onboarding.skip' => 'Salta',
			'onboarding.kContinue' => 'Continua',
			'onboarding.back' => 'Indietro',
			'onboarding.next' => 'Avanti',
			'onboarding.done' => 'Fatto',
			'onboarding.callsignTitle' => 'Qual è il tuo nominativo?',
			'onboarding.callsignBody' => 'Per trovare utile questa app ti serve una licenza di radioamatore',
			'onboarding.callsignLabel' => 'Nominativo Operatore',
			'onboarding.alreadyHaveAccount' => 'Hai già un account?',
			'onboarding.foundSiblingTitle' => 'Collegare un account esistente?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Abbiamo trovato ${app} su questo dispositivo. Collega questa app allo stesso account e il tuo nominativo e i tuoi log verranno trasferiti.',
			'onboarding.foundPoloBody' => 'Abbiamo trovato una versione precedente di Ham2K Portable Logger su questo dispositivo. Collega questa app allo stesso account e il tuo nominativo e i tuoi log verranno trasferiti.',
			'onboarding.foundSiblingsBody' => 'Abbiamo trovato altre app Ham2K su questo dispositivo. Collega questa app a uno dei loro account e il tuo nominativo e i tuoi log verranno trasferiti.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Collega con ${app}',
			'onboarding.linkWithPolo' => 'Collega con l\'account della versione precedente',
			'onboarding.setUpFresh' => 'Configura da zero',
			'onboarding.activitiesTitle' => 'Attività preferite',
			'onboarding.activitiesBody' => 'Ti interessa qualcuno di questi popolari programmi di attivazione?',
			'onboarding.activitiesFooter' => '(Trovi altre opzioni nelle Impostazioni)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'Sincronizzazione Cloud',
			'onboarding.syncBody' => 'Ham2K Log Filer conserva una copia di backup dei tuoi log nel cloud e li sincronizza su tutti i dispositivi in cui usi le app Ham2K.',
			'onboarding.syncPricing' => 'È gratis! Ma con un abbonamento a pagamento sarà più veloce.',
			'onboarding.syncLabel' => 'Abilita la sincronizzazione cloud',
			'onboarding.syncOffWarning' => 'ATTENZIONE: così aumentano le probabilità di perdere i dati delle operazioni, ad esempio se il dispositivo si blocca o viene smarrito.',
			'onboarding.notNow' => 'Non ora',
			'onboarding.consentTitle' => 'Dati e Privacy',
			'onboarding.consentUsageBody' => 'Per aiutarci a migliorare l\'app, vorremmo raccogliere dati su prestazioni, arresti anomali e utilizzo dell\'app.',
			'onboarding.consentUsageLabel' => 'Condividi i dati di utilizzo dell\'app',
			'onboarding.consentOperationBody' => 'Alcune funzioni potrebbero comportare la condivisione dei dati delle tue operazioni con altri utenti. Puoi rinunciare in qualsiasi momento.',
			'onboarding.consentOperationLabel' => 'Condividi i dati dell\'operazione',
			'onboarding.finishingSetup' => 'Completamento configurazione — download dei dati delle referenze…',
			'startScreen.credits' => 'da KI2D e amici',
			'testerOverlay.tape' => 'ATTENZIONE: LAVORI IN CORSO',
			'testerOverlay.warningTitle' => 'Questa app è in fase di sviluppo',
			'testerOverlay.warningBody' => 'La maggior parte delle funzioni ha superfici irregolari e ci sono ostacoli ovunque. Controlla regolarmente gli aggiornamenti.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novità della build ${build}',
			'testerOverlay.thanks' => 'Grazie per aver messo a rischio il tuo log per aiutarci a migliorare questa app!',
			'extensionsPanel.categoryActivity' => 'Attività',
			'extensionsPanel.categoryAward' => 'Diplomi',
			'extensionsPanel.categoryContest' => 'Contest',
			'extensionsPanel.categoryLookup' => 'Ricerca Nominativi',
			'extensionsPanel.categorySpots' => 'Fonti Spot',
			'extensionsPanel.categoryDashboard' => 'Pannelli Dashboard',
			'extensionsPanel.categoryOther' => 'Altre Estensioni',
			'extensionsPanel.searchHint' => 'Cerca estensioni',
			'extensionsPanel.applying' => 'Attivazione delle modifiche alle estensioni, potrebbe richiedere un momento…',
			'extensionsPanel.noMatches' => 'Nessuna estensione corrisponde alla ricerca',
			'extensionsPanel.installFromFile' => 'Installa da file…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versione ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Screenshot ${n} di ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Screenshot precedente',
			'extensionsPanel.nextScreenshot' => 'Screenshot successivo',
			'extensionsPanel.screenshotUnavailable' => 'Screenshot non disponibile',
			'extensionsPanel.canReach' => 'Questa estensione può contattare',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, tramite una connessione attiva',
			'extensionsPanel.canHoldLocalConnection' => 'Dispositivi sulla tua rete locale, tramite una connessione attiva',
			'extensionsPanel.canUseLocation' => 'La tua posizione',
			'extensionsPanel.canReadRadio' => 'La tua radio, per leggerne frequenza e modo',
			'extensionsPanel.canControlRadio' => 'La tua radio, per controllarla e trasmettere con essa — sintonia, potenza, CW, memorie vocali e PTT',
			'extensionsPanel.canCommandRadioRaw' => 'La tua radio, per inviarle qualsiasi comando nel suo protocollo — compresi quelli che trasmettono o ne cambiano le impostazioni',
			'extensionsPanel.canReadCluster' => 'Il DX cluster, connesso come te, per leggere ciò che invia',
			'extensionsPanel.canSpotCluster' => 'Il DX cluster, connesso come te, per pubblicare spot a tuo nome',
			'extensionsPanel.canCommandCluster' => 'Il DX cluster, connesso come te, per inviargli qualsiasi comando a tuo nome',
			'extensionsPanel.canSetUserAgent' => 'Identificarsi presso i server con il proprio nome',
			'extensionsPanel.canChangeSettings' => 'Le tue impostazioni, per modificarle tramite i suoi comandi: qualsiasi impostazione, la modalità sviluppatore e gli esperimenti',
			'extensionsPanel.noCapabilities' => 'Non richiede nulla al di fuori dell\'app.',
			'extensionsPanel.sandboxNote' => 'Le estensioni sono eseguite in sandbox: nessun accesso ai tuoi file e nessuna rete oltre a quanto elencato qui.',
			'extensionsPanel.installAction' => 'Installa',
			'extensionsPanel.updateAction' => 'Aggiorna',
			'extensionsPanel.installFailed' => 'Impossibile installare l\'estensione',
			'extensionsPanel.installedBadge' => 'Installata',
			'extensionsPanel.uninstallAction' => 'Rimuovi',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Rimuovere ${name}?',
			'extensionsPanel.uninstallBody' => 'Questa estensione e le sue impostazioni verranno rimosse. I tuoi log resteranno intatti.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} installata',
			'extensionsPanel.installDownloading' => 'Download in corso…',
			'extensionsPanel.installWaiting' => 'In attesa di installazione…',
			'extensionsPanel.installInstalling' => 'Installazione in corso…',
			'extensionsPanel.installAwaitingApproval' => 'In attesa della tua approvazione…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} è già in fase di installazione.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Aggiornata a ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'L\'installazione di ${name} non è stata completata. Potrebbe essere necessario reinstallarla.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Impossibile rimuovere ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Scaricata da ${source}',
			'extensionsPanel.dropHint' => 'Trascina qui un\'estensione .h2kext per installarla',
			'extensionsPanel.dropOneOnly' => 'Trascina un\'estensione alla volta.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} ha risposto ${status} per questa estensione.',
			'extensionsPanel.downloadTooLarge' => 'Il download è troppo grande per essere un\'estensione.',
			'extensionsPanel.downloadNotSecure' => 'Il download è stato reindirizzato a un indirizzo non sicuro.',
			'extensionsPanel.catalogSection' => 'Catalogo',
			'extensionsPanel.catalogLoading' => 'Caricamento del catalogo…',
			'extensionsPanel.catalogUnreachable' => 'Catalogo non raggiungibile',
			'extensionsPanel.builtIn' => 'Integrata',
			'extensionsPanel.updateAvailableBadge' => 'Aggiornamento disponibile',
			'extensionsPanel.updatesAvailableTitle' => 'Aggiornamenti estensioni',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'È disponibile un aggiornamento per ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} e altre ${count} devono essere aggiornate.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} devono essere aggiornate.',
			'extensionsPanel.pendingUpdatesSection' => 'Aggiornamenti in sospeso',
			'extensionsPanel.updateAllAction' => 'Aggiorna tutto',
			'extensionsPanel.updatesUnderWay' => 'Questi aggiornamenti sono già in corso.',
			'extensionsPanel.updatesNothingLeft' => 'Le tue estensioni sono aggiornate.',
			'extensionsPanel.updatesNoticeAction' => 'Maggiori info',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Aggiornare ${count} estensione?', other: 'Aggiornare ${count} estensioni?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Le tue estensioni sono pronte',
			'extensionsPanel.upgradeDoneBody' => 'Ora provengono dal catalogo estensioni di Ham2K, quindi possono essere aggiornate senza attendere una nuova versione dell\'app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Non aggiornate: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Non avviate: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Sono ancora installate e segnalate in Impostazioni › Estensioni — aggiornarle da lì le ripristinerà.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Il catalogo non ha un sostituto diretto per queste, quindi cerca lì estensioni che coprano ciò che usavi.',
			'extensionsPanel.retiredQp' => 'QSO Party',
			'extensionsPanel.retiredStateparks' => 'Eventi State Parks',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} delle tue estensioni non sono ancora arrivate. Verranno scaricate la prossima volta che il catalogo estensioni sarà raggiungibile.',
			'extensionsPanel.runtimeDeadBody' => 'Le tue estensioni non si sono avviate. Riavviare l\'app dovrebbe ripristinarle.',
			'extensionsPanel.refusedTitle' => 'Alcune estensioni non si sono avviate',
			'extensionsPanel.upgradeBusyTitle' => 'Configurazione ancora in corso',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Le tue estensioni non sono in esecuzione',
			'extensionsPanel.restoreTitle' => 'Mancano alcune delle tue estensioni',
			'extensionsPanel.restoreBody' => 'Queste estensioni che hai installato non sono su questo dispositivo. Possiamo scaricarle di nuovo dal catalogo estensioni di Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Installate da un file. Reinstallale dai loro file, oppure dimenticale:',
			'extensionsPanel.restoreOtherCatalog' => 'Installate da un altro catalogo estensioni, quindi non sono disponibili qui:',
			'extensionsPanel.restoreForget' => 'Dimentica',
			'extensionsPanel.restoreInstall' => 'Installa',
			'extensionsPanel.restoreLater' => 'Più tardi',
			'extensionsPanel.restoreInstalling' => 'Installazione delle tue estensioni…',
			'extensionsPanel.restoreDoneTitle' => 'Le tue estensioni sono tornate',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Reinstallate: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Alcune estensioni non sono state installate',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Impossibile installare: ${names}. Te le riproporremo la prossima volta che apri l\'app.',
			'extensionsPanel.restoreBusyBody' => 'L\'app sta ancora configurando le tue estensioni. Te le riproporremo la prossima volta che apri l\'app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Le abbiamo reinstallate, ma le tue estensioni non si sono avviate. Riavviare l\'app dovrebbe ripristinarle.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} è stata ritirata',
			'extensionsPanel.revokedBody' => 'Il catalogo ha ritirato questa versione, quindi è stata disattivata.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => '${name} è stata disattivata',
			'extensionsPanel.forceDisabledBody' => 'Ham2K ha disattivato questa estensione per il momento.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name} è stata sostituita',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => 'Al suo posto c\'è ${replacement}. Puoi passare alla nuova in Estensioni.',
			'extensionsPanel.replacedBy' => ({required Object name}) => 'Sostituita da ${name}',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'Sostituita da ${name}, che hai già',
			'extensionsPanel.replaceAction' => 'Sostituisci',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => 'Le sue impostazioni passano a ${replacement}, che hai già. I tuoi log resteranno intatti.',
			'extensionsPanel.downloadHashMismatch' => 'Il download non è l\'estensione descritta dal catalogo.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Il catalogo non ha la versione ${version} di ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Il link al catalogo non indica una versione di estensione.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Il catalogo non ha alcuna release di ${key} su quel canale.',
			'extensionsPanel.installFromLink' => 'Installa da link',
			'extensionsPanel.unstableReleaseWarning' => 'Questa è una release instabile, che il suo autore non considera completa. Potrebbe funzionare male e continuerà a ricevere aggiornamenti instabili.',
			'extensionsPanel.bleedingReleaseWarning' => 'Questa è una release bleeding-edge: lavoro in corso che potrebbe rompersi o perdere le sue impostazioni. Continuerà a ricevere aggiornamenti bleeding-edge.',
			'extensionsPanel.channelUnstable' => 'Instabile',
			'extensionsPanel.channelBleeding' => 'Bleeding',
			'extensionsPanel.followsUnstable' => 'Riceve release instabili e stabili',
			'extensionsPanel.followsBleeding' => 'Riceve release bleeding-edge, instabili e stabili',
			'extensionsPanel.followStableAction' => 'Segui solo le release stabili',
			'extensionsPanel.revokedBadge' => 'Ritirata',
			'extensionsPanel.forceDisabledBadge' => 'Disattivata da Ham2K',
			'extensionsPanel.refusedBadge' => 'Non caricata',
			'extensionsPanel.downloadNotHttps' => 'Il download non avviene su una connessione sicura.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'Impossibile raggiungere ${source} per questa estensione.',
			'extensionsPanel.detailsAction' => 'Dettagli',
			'extensionsPanel.installedFromFile' => 'Installata da un file',
			'extensionsPanel.detailsWhatItDoes' => 'Fornisce supporto per',
			'extensionsPanel.installedPreloaded' => 'Preinstallata',
			'extensionsPanel.hookAccount' => 'Accesso all\'account',
			'extensionsPanel.hookCallNotes' => 'Note sui nominativi',
			'extensionsPanel.hookDataFile' => 'Dati fuori rete',
			'extensionsPanel.hookExport' => 'Esportazione',
			'extensionsPanel.hookLookup' => 'Ricerca nominativi',
			'extensionsPanel.hookScoring' => 'Punteggio',
			'extensionsPanel.hookSpots' => 'Spot',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Caccia ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Attivazione ${program}',
			'extensionsPanel.suggestedSection' => 'Suggerite',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => 'Altre disponibili (${count})',
			'home.title' => 'Logger Portatile',
			'home.newOperation' => 'Nuova operazione',
			'home.stationCallsign' => 'Nominativo di stazione',
			'home.titleOptional' => 'Titolo (opzionale)',
			'home.emptyList' => 'Ancora nessuna operazione. Creane una per iniziare a registrare.',
			'home.quickLookup' => 'Ricerca Rapida',
			'home.nav.operations' => 'Operazioni',
			'home.nav.chase' => 'Caccia',
			'home.nav.logs' => 'Log',
			'home.nav.maps' => 'Mappe',
			'home.nav.settings' => 'Impostazioni',
			'home.panels.operations' => 'Elenco delle operazioni',
			'home.panels.operationsDescription' => 'Le tue operazioni, dalla più recente.',
			'home.panels.version' => 'Versione attuale',
			'home.panels.versionDescription' => 'Il marchio Ham2K, il nome di questa app e la build in esecuzione.',
			'home.toggleNav' => 'Mostra o nascondi le etichette di navigazione',
			'home.logs.title' => 'Log',
			'home.logs.titleFor' => 'Log per',
			'home.logs.emptyCallsigns' => 'Ancora nessun QSO registrato',
			'home.logs.emptyQsos' => ({required Object call}) => 'Nessun QSO per ${call}',
			'home.logs.mapNoSelection' => 'Seleziona un QSO per vederlo sulla mappa',
			'home.logs.searchHint' => 'Cerca nominativo o nome',
			'home.logs.noSearchMatches' => 'Nessun QSO corrisponde alla ricerca',
			'home.logs.titleAll' => 'Tutti i log',
			'home.logs.allCallsigns' => 'Tutti i nominativi',
			'home.logs.noOperation' => 'Non fa parte di un\'operazione',
			'home.logs.unsavedTitle' => 'Modifiche non salvate',
			'home.logs.unsavedBody' => 'Questo QSO ha modifiche che non hai salvato.',
			'home.logs.pendingDeleteBody' => 'Questo QSO è contrassegnato per l\'eliminazione.',
			'home.logs.editGone' => 'Non salvato: quel QSO non è più in questo log.',
			'home.logs.discard' => 'Scarta',
			'home.logs.sheet.callsigns' => 'Nominativi di stazione',
			'home.logs.sheet.groupBy' => 'Raggruppa per',
			'home.logs.sheet.period' => 'Periodo',
			'home.logs.groupBy.none' => 'Senza raggruppamento',
			'home.logs.groupBy.date' => 'Data',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Continente sconosciuto',
			'home.logs.groupBy.unknownEntity' => 'Entità sconosciuta',
			'home.logs.groupBy.unknownDate' => 'Senza data',
			'home.logs.period.thisMonth' => 'Questo mese',
			'home.logs.period.last3Months' => 'Ultimi 3 mesi',
			'home.logs.period.thisYear' => 'Quest\'anno',
			'home.logs.period.lastYear' => 'Anno scorso',
			'home.logs.period.allTime' => 'Da sempre',
			'home.logs.period.custom' => 'Intervallo personalizzato',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => '(${span})',
			'home.logs.periodTitle.custom' => 'Intervallo personalizzato',
			'home.logs.columns.date' => 'Data',
			'home.logs.columns.time' => 'Ora',
			'home.logs.columns.freq' => 'Frequenza',
			'home.logs.columns.mode' => 'Modo',
			'home.logs.columns.call' => 'Nominativo',
			'home.logs.columns.name' => 'Nome',
			'home.logs.columns.station' => 'Stazione',
			'home.logs.columns.band' => 'Banda',
			'home.logs.columns.sent' => 'Inviato',
			'home.logs.columns.rcvd' => 'Ricev',
			'home.logs.columns.grid' => 'Locatore',
			'home.logs.columns.state' => 'Stato',
			'home.logs.columns.country' => 'Paese',
			'home.logs.columns.refs' => 'Ref',
			'home.logs.panels.qsos' => 'Log QSO',
			'home.logs.panels.qsosDescription' => 'I QSO del nominativo selezionato, in tutte le operazioni.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Totale dei QSO, o la ricerca del nominativo del QSO selezionato.',
			'home.logs.panels.map' => 'Mappa',
			'home.logs.panels.mapDescription' => 'La posizione del QSO selezionato.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Nominativi: ${calls}',
			'home.logs.import.skippedOne' => '1 record non leggibile',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} record non leggibili',
			'home.logs.import.readingTitle' => 'Lettura del file ADIF…',
			'home.logs.import.checkingTitle' => 'Verifica dei duplicati…',
			'home.logs.import.importingTitle' => 'Importazione dei QSO…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} di ${total} verificati',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importati su ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'a caccia di',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} e ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} e altro',
			'chase.station.title' => 'Stazione di caccia',
			'chase.station.stationLabel' => 'Stazione: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Nessuna posizione',
			'chase.periodInline.today' => 'oggi',
			'chase.periodInline.thisWeek' => 'questa settimana',
			'chase.periodInline.last14Days' => 'negli ultimi 14 giorni',
			'chase.periodInline.thisMonth' => 'questo mese',
			'chase.periodStats.today' => 'Statistiche di oggi',
			'chase.periodStats.thisWeek' => 'Statistiche di questa settimana',
			'chase.periodStats.last14Days' => 'Statistiche degli ultimi 14 giorni',
			'chase.periodStats.thisMonth' => 'Statistiche di questo mese',
			'chase.period.today' => 'Oggi',
			'chase.period.thisWeek' => 'Questa settimana',
			'chase.period.last14Days' => 'Ultimi 14 giorni',
			'chase.period.thisMonth' => 'Questo mese',
			'chase.goals.title' => 'Obiettivi di caccia',
			'chase.goals.remove' => ({required Object name}) => 'Smetti di cacciare ${name}',
			'chase.goals.extensionsTitle' => 'Altri programmi di caccia',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => 'Controlli di logging sopra i QSO cacciati nel periodo.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Il nominativo in fase di registrazione, o le statistiche del periodo.',
			'chase.panels.spots' => 'Spot',
			'chase.panels.spotsDescription' => 'Stazioni spottate on the air, pronte da cacciare.',
			'chase.panels.map' => 'Mappa',
			'chase.panels.mapDescription' => 'I QSO del periodo e la stazione in fase di registrazione.',
			'chase.claims.checking' => 'Verifica dei QSO per la caccia',
			'chase.claims.rebuilding' => ({required Object program}) => 'Verifica del log per ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} di ${total} QSO',
			'chase.notice.newRef' => ({required Object program}) => 'Nuovo ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Probabilmente nuovo ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'Nuova banda ${program}',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Probabilmente nuova banda ${program}',
			'chase.notice.newMode' => ({required Object program}) => 'Nuovo modo ${program}',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Probabilmente nuovo modo ${program}',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} non confermato',
			'chase.notice.programGuess' => ({required Object notice}) => 'Probabilmente ${notice}',
			'chase.alerts.title' => 'Avvisi',
			'chase.alerts.newRef' => 'Nuova referenza',
			'chase.alerts.newBand' => 'Nuova banda',
			'chase.alerts.newMode' => 'Nuovo modo',
			'chase.alerts.unconfirmed' => 'Non confermato',
			'chase.checklists' => 'Progressi di caccia',
			'chase.imports.importFrom' => ({required Object label}) => 'Importa ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Importa ${file} come',
			'chase.imports.dropHint' => 'Trascina qui un file per importarlo in un programma di caccia',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'Importate ${count} voci ${program} da ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'Importate ${count} voci ${program} da ${file}, saltate ${skipped} non leggibili',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} non contiene nulla che ${program} possa importare',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} non è riuscito a leggere ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} non è riuscito a leggere nessuno dei ${skipped} record in ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'Nessun programma di caccia importa ${file}',
			'dialogs.operationDetails' => 'Dettagli operazione',
			'dialogs.activities' => 'Attività',
			'dialogs.stationCallsign' => 'Nominativo di Stazione',
			'dialogs.advanced' => 'Avanzate',
			'dialogs.operatingPosition' => 'Postazione operativa (multi-stazione)',
			'dialogs.assistance' => 'Assistenza',
			'dialogs.assistanceDescription' => 'Usa i servizi di spotting e altre fonti di informazioni',
			'dialogs.selfSpotting' => 'Auto-spot',
			'dialogs.selfSpottingDescription' => 'Consenti le funzioni che comunicano la tua frequenza',
			'dialogs.disabledByRules' => ({required Object rules}) => 'Disattivato per rispettare il regolamento ${rules}',
			'dialogs.lookupDespiteAssistance.title' => 'Cercare online?',
			'dialogs.lookupDespiteAssistance.body' => 'L\'assistenza è disattivata per questa operazione. La ricerca di tutti i QSO userà servizi online come QRZ solo per questa volta.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'L\'assistenza è disattivata per questa operazione, per rispettare il regolamento ${rules}. La ricerca di tutti i QSO userà servizi online come QRZ solo per questa volta.',
			'dialogs.lookupDespiteAssistance.action' => 'Cerca Online',
			'dialogs.notes' => 'Note',
			'dialogs.deleteOperationTitle' => 'Elimina Operazione',
			'dialogs.purgeTestsTitle' => 'Elimina le Operazioni di Test',
			'dialogs.purgeTestsBody' => 'Questo elimina definitivamente queste Operazioni di Test e i loro QSO. Non può essere annullato.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Più ${count} contatto di test che non appartiene ad alcuna operazione.', other: 'Più ${count} contatti di test che non appartengono ad alcuna operazione.', ), 
			'dialogs.purgeTestsAction' => 'Elimina',
			'dialogs.syncAllTitle' => 'Sostituire il log di questo dispositivo?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL esegue il backup e rimuove ${qsos} da questo dispositivo, poi scarica di nuovo il log dell\'account dal server. Il backup resta nel database di questo dispositivo.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${n} QSO non è ancora stato sincronizzato — il server non l\'ha mai ricevuto e NON tornerà.', other: '${n} QSO non sono ancora stati sincronizzati — il server non li ha mai ricevuti e NON torneranno.', ), 
			'dialogs.syncAllAction' => 'Cancella e risincronizza',
			'dialogs.receivedPurgesTitle' => 'Operazioni di Test rimosse altrove',
			'dialogs.receivedPurgesBody' => 'Queste sono state eliminate come Operazioni di Test su un altro dispositivo. Rimuoverle anche qui? Questo le elimina definitivamente insieme ai loro QSO e non può essere annullato.',
			'dialogs.receivedPurgesAction' => 'Rimuovi',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Nominativo non valido: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Nominativi non validi: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Finora ha operato ${previous}. ${typed} verrà registrato per i nuovi contatti.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Finora nessun operatore registrato. ${typed} verrà registrato per i nuovi contatti.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Questa operazione ha già contatti di ${calls}. ${typed} verrà registrato solo per i nuovi.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Registra ${typed} come operatore anche del contatto già registrato', other: 'Registra ${typed} come operatore anche di tutti i ${count} contatti già registrati', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Quando si usano più stazioni on the air, non sono supportati operatori separati',
			'dialogs.callChange.contactsUnreadable' => 'Impossibile leggere i contatti di questa operazione, quindi cambiare qui un nominativo non proporrà di aggiornarli',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Impossibile aggiornare i contatti già registrati, quindi non è stata fatta alcuna modifica: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} contatti su ${planned} sono stati aggiornati — gli altri non sono più in questa operazione',
			'operation.deletedReadOnly' => 'Questa operazione è eliminata. Ripristinala per registrare o apportare modifiche.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOT',
			'operation.tabs.map' => 'MAPPA',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => 'Orologio',
			'operation.tabs.weather' => 'Meteo',
			'operation.tabs.website' => 'Sito Web',
			'operation.tabs.remoteScreen' => 'Schermo Remoto',
			'operation.tabs.solar' => 'Solare',
			'operation.tabs.radio' => 'Radio',
			'operation.tabs.rotator' => 'Rotore',
			'operation.tabs.summaries' => 'Riepiloghi Operazione',
			'operation.positions.nobodyYet' => 'Nessun\'altra postazione operativa condivide ancora questa operazione.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Un\'altra postazione',
			'operation.positions.thisDevice' => 'La nostra postazione operativa',
			'operation.positions.nameIn' => ' in ',
			'operation.positions.panelTitle' => 'Postazioni',
			'operation.positions.panelDescription' => 'Cosa sta registrando in questo momento ogni postazione operativa che condivide questa operazione.',
			'operation.stationCallsignNone' => 'Nessun nominativo di stazione',
			'operation.titleNone' => 'Nessun titolo',
			'operation.deleteOperation' => 'Elimina operazione',
			'operation.loggingControlsStale' => 'I campi dell\'attività potrebbero non essere aggiornati — riapri l\'operazione per aggiornarli',
			'operation.locationNone' => 'Non impostata',
			'operation.generalOperation' => 'Operazione Generale',
			'operation.titleFor' => ({required Object value}) => 'per ${value}',
			'operation.titleAt' => ({required Object value}) => 'a ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Adesso ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'Mostra campi RST',
			'operation.menu.showStateField' => 'Mostra campo Stato',
			'operation.menu.showGridField' => 'Mostra campo Locatore',
			'operation.menu.showDeletedQsos' => 'Mostra QSO eliminati',
			'operation.menu.showDeletedOps' => 'Mostra operazioni eliminate',
			'operation.menu.showQsoNumbers' => 'Mostra numeri QSO',
			'operation.menu.lookupAllQsos' => 'Cerca tutti i QSO',
			'operation.menu.loggingSettingsTitle' => 'Impostazioni di Logging',
			'operation.menu.mapSettingsTitle' => 'Impostazioni Mappa',
			'operation.menu.actionsSection' => 'Azioni',
			'operation.layout.title' => 'Aggiungi un Pannello',
			'operation.layout.availableSection' => 'Pannelli disponibili',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Impostazioni di ${panel}',
			'operation.layout.panelSettingsAction' => 'Impostazioni Pannello',
			'operation.layout.viewName' => 'Vista Operazione',
			'operation.layout.viewOptions' => 'Opzioni di layout della vista',
			'operation.layout.viewTitleBuiltIn' => 'Questa vista è integrata nell\'app, così come il suo nome',
			'operation.layout.resetOptions' => 'Ripristina Predefiniti',
			'operation.layout.removePane' => 'Rimuovi',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Ripristinare ${panel} ai valori predefiniti?',
			'operation.layout.resetPaneConfirmBody' => 'Titolo, intestazione e dimensione tornano ai valori predefiniti. Il resto del layout rimane com\'è.',
			'operation.layout.resetViewConfirm' => 'Ripristinare il layout predefinito di questa vista?',
			'operation.layout.resetViewConfirmBody' => 'I pannelli tornano alla disposizione predefinita, e le opzioni della vista e di ogni pannello tornano ai valori predefiniti.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Impostazioni di layout di ${panel}',
			'operation.layout.paneTitle' => 'Titolo',
			'operation.layout.paneShowHeader' => 'Mostra intestazione',
			'operation.layout.paneShowHeaderTabset' => 'Sempre visibile finché questo riquadro condivide un gruppo — l\'intestazione è il modo per raggiungere gli altri',
			'operation.layout.paneInherit' => 'Come l\'app',
			'operation.layout.searchHint' => 'Cerca pannelli',
			'operation.layout.noPanelsMatch' => 'Nessun pannello corrisponde alla ricerca.',
			'operation.layout.nothingToAdd' => 'Questa vista ha già tutti i pannelli possibili',
			'operation.layout.addPanel' => ({required Object panel}) => 'Aggiungi ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Anteprima di ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Manca l\'estensione "${name}"',
			'operation.layout.missingExtensionEnable' => 'Abilita',
			'operation.layout.missingExtensionInstall' => 'Installa…',
			'operation.layout.missingExtensionWontRun' => 'Questa versione non si avvia. Aggiornala in Impostazioni › Estensioni.',
			'operation.layout.missingExtensionUnavailable' => 'Non disponibile in questa app',
			'operation.layout.missingExtensionNotInCatalog' => 'Non presente nel catalogo',
			'operation.layout.missingExtensionCatalogUnreachable' => 'Impossibile raggiungere il catalogo. Riprova',
			'operation.layout.missingExtensionFailed' => 'Non ha funzionato. Riprova',
			'operation.layout.previewUnavailable' => 'Impossibile mostrare l\'immagine di anteprima di questo pannello.',
			'operation.layout.nestedPaneTitle' => 'Altro',
			'operation.layout.layouts.defaultName' => 'Predefinito',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Layout ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Layout: ${name}',
			'operation.layout.layouts.menuNew' => 'Nuovo…',
			'operation.layout.layouts.menuExport' => 'Esporta…',
			'operation.layout.layouts.menuImport' => 'Importa…',
			'operation.layout.layouts.menuTitle' => 'Layout',
			'operation.layout.layouts.newTitle' => 'Nuovo Layout',
			'operation.layout.layouts.editTitle' => 'Modifica Layout',
			'operation.layout.layouts.edit' => 'Modifica',
			'operation.layout.layouts.duplicateCurrent' => 'Duplica il layout attuale',
			'operation.layout.layouts.startFromDefault' => 'Parti dal layout predefinito',
			'operation.layout.layouts.nameLabel' => 'Nome',
			'operation.layout.layouts.descriptionLabel' => 'Descrizione',
			'operation.layout.layouts.create' => 'Crea',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'Salvare le modifiche a "${name}"?',
			'operation.layout.layouts.leaveEditBody' => 'Questo layout ha modifiche che non hai salvato.',
			'operation.layout.layouts.discard' => 'Scarta',
			'operation.layout.layouts.deleteTitle' => 'Eliminare questo layout?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'Sei sicuro di voler eliminare il layout "${name}"?',
			'operation.layout.layouts.exportTitle' => 'Esporta Layout',
			'operation.layout.layouts.exportPick' => 'Pannelli da esportare',
			'operation.layout.layouts.tabSet' => 'Gruppo di schede',
			'operation.layout.layouts.exportAction' => 'Esporta',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Layout salvato in ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'Impossibile esportare il layout: ${error}',
			'operation.layout.layouts.importTitle' => 'Importa Layout',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Creato per la vista ${view}: i pannelli presenti solo in quella vista vengono esclusi.',
			'operation.layout.layouts.viewHome' => 'Home',
			'operation.layout.layouts.viewOperation' => 'Operazione',
			'operation.layout.layouts.viewLogs' => 'Log',
			'operation.layout.layouts.viewChase' => 'Caccia',
			'operation.layout.layouts.importAsNew' => 'Come nuovo layout',
			'operation.layout.layouts.importReplace' => 'Al posto di questo layout',
			'operation.layout.layouts.importAdd' => 'Aggiunto a questo layout',
			'operation.layout.layouts.importAddHint' => 'I pannelli vengono aggiunti in una nuova colonna a destra.',
			'operation.layout.layouts.importPick' => 'Pannelli da importare',
			'operation.layout.layouts.importReplaceSettings' => 'Sostituisci le impostazioni dei pannelli già configurati qui',
			'operation.layout.layouts.importAction' => 'Importa',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} non è un layout che questa app possa leggere: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'il testo non è YAML valido (riga ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'non è un file di layout Ham2K',
			'operation.layout.layouts.problemNewerVersion' => 'è stato scritto da una versione più recente dell\'app',
			'operation.layout.layouts.problemNoArrangement' => 'non contiene alcuna disposizione',
			'operation.layout.layouts.problemMalformed' => 'una parte non rispetta il formato dei layout',
			'operation.layout.layouts.problemTooLarge' => 'è troppo grande',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'Impossibile aprire il file: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'Impossibile importare il layout: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'Impossibile copiare il layout: ${error}',
			'operation.layout.layouts.importNothing' => 'Nessun pannello selezionato, quindi non è stato importato nulla.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'Esclusi: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'Mantenuto ${panels}: la disposizione per schermi piccoli non può farne a meno.',
			'operation.layout.layouts.notOffered' => 'Non disponibile in questa vista',
			'operation.layout.layouts.alreadyPlaced' => 'Già in questo layout',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Richiede ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'Impossibile leggere i nomi dei layout',
			'operation.layout.layouts.listRecoveredBody' => 'Impossibile leggere l\'elenco dei layout di questa vista. Tutti i layout sono ancora qui, numerati al posto del nome.',
			'operation.layout.editLayout' => 'Modifica Layout',
			'operation.layout.saveLayout' => 'Salva Layout',
			'operation.layout.revertLayout' => 'Scarta le modifiche al layout',
			'operation.layout.done' => 'Fatto',
			'operation.layout.layoutUnreadableTitle' => 'Impossibile leggere il layout',
			'operation.layout.layoutUnreadableBody' => 'Il layout salvato non è leggibile, quindi viene mostrata la disposizione predefinita. Non sovrascriverà l\'originale finché non scegli di mantenerla.',
			'operation.layout.layoutUnreadableAction' => 'Usa questo layout',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => 'Impossibile visualizzare ${panel}',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: ha inviato più di ${max} caratteri',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua grafica ha più di ${max} elementi',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua grafica è annidata a più di ${max} livelli di profondità',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => 'Impossibile visualizzare ${panel}: la sua grafica non è autonoma',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua scena ha più di ${max} livelli',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: la sua scena ha più di ${max} controlli',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: una parte della sua scena ha più di ${max} voci',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: una stringa della scena supera i ${max} caratteri',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => 'Impossibile visualizzare ${panel}: il suo layout è annidato a più di ${max} livelli di profondità',
			'operation.layout.panelRenderRetry' => 'Riprova',
			'operation.layout.panelActionFailed' => 'L\'azione del pannello non è riuscita. Riprova.',
			'operation.layout.panels.loggingDescription' => 'Il log e i campi di inserimento',
			'operation.layout.panels.infoDescription' => 'Cosa sappiamo della stazione collegata',
			'operation.layout.panels.spotsDescription' => 'Spot dai cluster e dai programmi di attività',
			'operation.layout.panels.mapDescription' => 'Dove si trovano i contatti',
			'operation.layout.panels.summariesDescription' => 'Statistiche e punteggi dell\'operazione, nelle sezioni e nell\'ordine che scegli',
			'operation.layout.panels.summariesSections' => 'Sezioni e Ordine',
			'operation.layout.panels.summariesDays' => 'Ogni giorno',
			'operation.layout.panels.summariesReset' => 'Mostra tutto',
			'operation.layout.panels.summariesAllHidden' => 'Tutte le sezioni sono nascoste. Scegli quelle da mostrare nelle impostazioni di questo pannello.',
			'operation.layout.panels.clockDescription' => 'Un orologio, in qualsiasi fuso orario',
			'operation.layout.panels.clockFace' => 'Quadrante',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analogico',
			'operation.layout.panels.clockZone' => 'Fuso orario',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Questo dispositivo',
			'operation.layout.panels.clockShowSeconds' => 'Mostra secondi',
			'operation.layout.panels.weatherDescription' => 'Condizioni attuali e delle prossime otto ore, dove stai operando',
			'operation.layout.panels.weatherUseOperationLocation' => 'Usa la posizione dell\'operazione',
			'operation.layout.panels.weatherLocation' => 'Posizione',
			'operation.layout.panels.weatherLocationDescription' => 'Un locatore (FN31pr) o lat,lon. Ignorato quando \'Usa la posizione dell\'operazione\' è selezionato.',
			'operation.layout.panels.weatherNoLocation' => 'Nessuna posizione impostata. Assegna una posizione a questo pannello nelle sue impostazioni, o mettilo in un\'operazione che ne ha una.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Impossibile leggere la posizione ${location}. Usa un locatore come FN31pr, o 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Impossibile raggiungere Open-Meteo — nessuna rete? Nuovo tentativo a breve.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo ha risposto, ma con dati non leggibili. Nuovo tentativo a breve.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'raffiche ${speed}',
			'operation.layout.panels.panelAgeNow' => 'adesso',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} min fa', other: '${count} min fa', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} ora fa', other: '${count} ore fa', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Sconosciuto',
			'operation.layout.panels.weatherConditions.sunny' => 'Soleggiato',
			'operation.layout.panels.weatherConditions.clear' => 'Sereno',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Prevalentemente soleggiato',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Prevalentemente sereno',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parzialmente nuvoloso',
			'operation.layout.panels.weatherConditions.cloudy' => 'Nuvoloso',
			'operation.layout.panels.weatherConditions.foggy' => 'Nebbia',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Nebbia con brina',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Pioviggine leggera',
			'operation.layout.panels.weatherConditions.drizzle' => 'Pioviggine',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Pioviggine intensa',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Pioviggine gelata leggera',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Pioviggine gelata',
			'operation.layout.panels.weatherConditions.lightRain' => 'Pioggia leggera',
			'operation.layout.panels.weatherConditions.rain' => 'Pioggia',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Pioggia intensa',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Pioggia gelata leggera',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Pioggia gelata',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Neve leggera',
			'operation.layout.panels.weatherConditions.snow' => 'Neve',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Neve intensa',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Neve granulosa',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Rovesci leggeri',
			'operation.layout.panels.weatherConditions.showers' => 'Rovesci',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Rovesci intensi',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Rovesci di neve leggeri',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Rovesci di neve',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Temporale',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Temporali leggeri con grandine',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Temporale con grandine',
			'operation.layout.panels.websiteDescription' => 'Una pagina web a tua scelta, in un riquadro',
			'operation.layout.panels.websiteUrl' => 'Indirizzo',
			'operation.layout.panels.websiteRefresh' => 'Aggiorna',
			'operation.layout.panels.websiteRefreshNever' => 'Mai',
			'operation.layout.panels.websiteRefresh1' => 'Ogni minuto',
			'operation.layout.panels.websiteRefresh5' => 'Ogni 5 minuti',
			'operation.layout.panels.websiteRefresh15' => 'Ogni 15 minuti',
			'operation.layout.panels.websiteTitle' => 'Nome Pannello',
			'operation.layout.panels.websiteRefreshNow' => 'Aggiorna ora',
			'operation.layout.panels.websiteNoUrl' => 'Nessun indirizzo. Apri le impostazioni di questo pannello per scegliere una pagina.',
			'operation.layout.panels.websiteBadUrl' => 'Non sembra un indirizzo web. Deve iniziare con https://',
			'operation.layout.panels.websiteNotHttps' => 'Solo gli indirizzi https:// possono essere mostrati qui.',
			'operation.layout.panels.websiteUnsupported' => 'Su questo sistema non si possono mostrare pagine web in un pannello.',
			'operation.layout.panels.websiteOpenExternally' => 'Apri nel Browser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Impossibile caricare la pagina: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Uno schermo, un\'app o una finestra condivisi da un altro dei tuoi dispositivi.',
			'operation.layout.panels.remoteScreenTarget' => 'Schermo',
			'operation.layout.panels.remoteScreenChoose' => 'Scegli uno schermo…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Schermi Condivisi',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Nessuno dei tuoi dispositivi sta condividendo uno schermo. Attiva Condividi schermi e finestre in Impostazioni → Dispositivi Peer, sul dispositivo che vuoi vedere.',
			'operation.layout.panels.remoteScreenUnset' => 'Nessuno schermo scelto. Apri le impostazioni di questo pannello per sceglierne uno condiviso dagli altri tuoi dispositivi.',
			'operation.layout.panels.remoteScreenConnecting' => 'Connessione in corso…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Quel dispositivo non è connesso in questo momento.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Quel dispositivo ha smesso di condividere questo schermo.',
			'operation.layout.panels.remoteScreenNoListener' => 'Quel dispositivo non accetta connessioni — controlla il suo firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Gli schermi sono condivisi solo sulla rete locale, non via Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Quel dispositivo non ha voluto condividere questo schermo.',
			'operation.layout.panels.remoteScreenSettings' => 'Impostazioni pannello',
			'operation.layout.panels.remoteScreenAdjust' => 'Regola Vista',
			'operation.layout.panels.remoteScreenDetail' => 'Dettaglio',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Alto',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Massimo',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Ingrandisci',
			'operation.layout.panels.remoteScreenZoomOut' => 'Riduci',
			'operation.layout.panels.remoteScreenStopped' => 'Quello schermo o quella finestra non viene più mostrato.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Quel dispositivo non è riuscito a catturare lo schermo — potrebbe servire il permesso di Registrazione Schermo.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Quel dispositivo non ha risposto. Potrebbe non avere la condivisione schermo attiva.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Impossibile aprire una connessione per l\'immagine. Controlla il firewall su questo dispositivo.',
			'operation.layout.panels.solarDescription' => 'Condizioni solari e geomagnetiche, con la propagazione banda per banda',
			'operation.layout.panels.solarUnreachable' => 'Impossibile raggiungere hamqsl.com — nessuna rete? Nuovo tentativo a breve.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com ha risposto, ma non con dati utilizzabili. Nuovo tentativo a breve.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Giorno',
			'operation.layout.panels.solarBandNight' => 'Notte',
			'operation.layout.panels.solarBandGood' => 'Buona',
			'operation.layout.panels.solarBandFair' => 'Discreta',
			'operation.layout.panels.solarBandPoor' => 'Scarsa',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Fonti: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'La connessione è in difficoltà — alcuni fotogrammi vengono saltati.',
			'operation.layout.panels.remoteScreenStalled' => 'I fotogrammi non arrivano più — questa connessione potrebbe essere troppo lenta.',
			'operation.layout.panels.radioDescription' => 'Il pannello frontale di una radio — frequenza, modo e potenza, sotto controllo CAT',
			'operation.layout.panels.radioStyle' => 'Stile',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderno',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — nessuna radio designata',
			'operation.layout.panels.radioNoRadio' => 'Nessuna radio da mostrare. Scegline una nelle impostazioni di questo pannello, o aggiungine una in Configurazione Stazione.',
			'operation.layout.panels.radioNotConfigured' => 'Questa radio non è ancora configurata. Scegli la sua porta o indirizzo in Configurazione Stazione.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio non connessa',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Connetti questa radio',
			'operation.layout.panels.radioDisconnect' => 'Disconnetti questa radio',
			'operation.layout.panels.radioStale' => 'NESSUN DATO',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR alto',
			'operation.layout.panels.rotatorDescription' => 'Dove punta l\'antenna, su una mappa centrata sulla stazione. Tocca la mappa per ruotare l\'antenna.',
			'operation.layout.panels.rotatorRotator' => 'Rotore',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => 'Automatico — ${name}',
			'operation.layout.panels.rotatorAutoNone' => 'Automatico — ancora nessun rotore',
			'operation.layout.panels.rotatorBeamWidth' => 'Apertura del fascio',
			'operation.layout.panels.rotatorBeamWidthDescription' => 'In gradi, disegnata attorno alla direzione. Con 0 non viene disegnata.',
			'operation.layout.panels.rotatorLocation' => 'Posizione',
			'operation.layout.panels.rotatorLocationDescription' => 'Un locatore, o latitudine e longitudine, su cui centrare la mappa. Vuoto usa la posizione dell\'operazione.',
			'operation.layout.panels.rotatorTheme' => 'Tema',
			'operation.layout.panels.rotatorThemeColor' => 'Colore',
			'operation.layout.panels.rotatorThemeGray' => 'Grigio',
			'operation.layout.panels.rotatorThemeMuted' => 'Attenuato',
			'operation.layout.panels.rotatorGrayline' => 'Mostra la grayline',
			'operation.layout.panels.rotatorNoRotator' => 'Nessun rotore da mostrare. Scegline uno nelle impostazioni di questo pannello, o aggiungine uno in Configurazione Stazione.',
			'operation.layout.panels.rotatorNoLocation' => 'Nessuna posizione su cui centrare la mappa. Impostane una nelle impostazioni di questo pannello.',
			'operation.layout.panels.rotatorDisconnected' => 'disconnesso',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => 'non risponde',
			'operation.layout.panels.rotatorLocationInvalid' => 'Impossibile leggere la posizione nelle impostazioni di questo pannello. Usa un locatore, o latitudine e longitudine come 40.7, -74.0.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '${degrees}° el',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'W',
			'operation.layout.htmlPanelUnsupported' => 'Questo pannello richiede una web view, che questa piattaforma non fornisce',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Questo pannello richiede una sandbox che la versione web non può fornire',
			'operation.export.title' => 'Esportazioni dell\'operazione',
			'operation.export.syncedOperation' => 'L\'operazione è sincronizzata',
			'operation.export.unsyncedOperation' => 'L\'operazione ha modifiche non sincronizzate',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} QSO in questa operazione', other: '${count} QSO in questa operazione', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Tutti i ${total} QSO sono sincronizzati',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} QSO su ${total} in attesa di sincronizzazione',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcatori di evento sincronizzati',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} marcatori di evento su ${total} in attesa',
			'operation.export.loading' => 'Caricamento delle opzioni di esportazione…',
			'operation.export.noOptions' => 'Nessun formato di esportazione disponibile (le estensioni si stanno ancora avviando?)',
			'operation.export.nothingLogged' => 'Ancora niente da esportare — questa operazione non ha QSO.',
			'operation.export.share' => 'Condividi',
			'operation.export.nothingSelected' => 'Nessuna selezione',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Salva ${count} file', other: 'Salva ${count} file', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Condividi ${count} file', other: 'Condividi ${count} file', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Esporta ${count} file', other: 'Esporta ${count} file', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Scarica ${count} file', other: 'Scarica ${count} file', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Salva ${count} file combinato', other: 'Salva ${count} file combinati', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Condividi ${count} file combinato', other: 'Condividi ${count} file combinati', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Esporta ${count} file combinato', other: 'Esporta ${count} file combinati', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Scarica ${count} file combinato', other: 'Scarica ${count} file combinati', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Salva ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Condividi ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Esporta ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Scarica ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Archivia ${count} file', other: 'Archivia ${count} file', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Archivia ${count} file combinato', other: 'Archivia ${count} file combinati', ), 
			'operation.export.settingsButton' => 'Impostazioni di esportazione',
			'operation.export.settingsTitle' => 'Impostazioni di Esportazione',
			'operation.export.compactFileNames.title' => 'Usa nomi di file compatti',
			'operation.export.compactFileNames.descriptionOn' => 'Nomi brevi pensati per i sistemi di caricamento, come N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nomi leggibili, come 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Includi informazioni private',
			'operation.export.includePrivateData.descriptionOn' => 'Nomi, indirizzi, email, locatori e note sono inclusi',
			'operation.export.includePrivateData.descriptionOff' => 'Nomi, indirizzi, email, locatori e note sono esclusi',
			'operation.export.includePrivateData.note' => 'L\'esportazione ADIF completa include sempre tutto',
			'operation.export.resultTitle' => 'Esportazione completata',
			'operation.export.resultFailedTitle' => 'Esportazione non riuscita',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Esportato ${count} file in ${path}', other: 'Esportati ${count} file in ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Esportato ${count} file: ${path}', other: 'Esportati ${count} file: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Condiviso ${count} file', other: 'Condivisi ${count} file', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Scaricato ${count} file', other: 'Scaricati ${count} file', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Esportazione non riuscita: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Prima aggiungi un indirizzo email',
			'operation.export.stash.needsEmailBody' => 'L\'Archivio File di Ham2K invia i tuoi file all\'indirizzo email del tuo account LoFi, con cui accedi a stash.ham2k.net. Il tuo account non ne ha ancora uno confermato — aggiungilo in Impostazioni › Sincronizzazione Cloud.',
			'operation.export.stash.openSyncSettings' => 'Apri Sincronizzazione Cloud',
			'operation.export.stash.replaceTitle' => 'L\'archivio recente verrà sostituito',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Hai inviato “${name}” meno di 6 ore fa e non è stato ancora scaricato. Gli account gratuiti conservano un solo archivio alla volta, quindi inviare ora lo sostituisce.',
			'operation.export.stash.replaceConfirm' => 'Invia lo stesso',
			'operation.export.stash.failedTitle' => 'Impossibile inviare all\'Archivio File di Ham2K',
			'operation.export.stash.sentTitle' => 'Inviato all\'Archivio File di Ham2K',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Puoi recuperare questo file visitando **[stash.ham2k.net](https://stash.ham2k.net)** da qualsiasi browser.', other: 'Puoi recuperare questi file visitando **[stash.ham2k.net](https://stash.ham2k.net)** da qualsiasi browser.', ), 
			'operation.export.stash.mayHaveArrived' => 'Nessuna risposta dall\'archivio — il file potrebbe essere arrivato comunque. Controlla stash.ham2k.net prima di inviare di nuovo',
			'operation.export.stash.notSent' => 'non inviato',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Questo file non è arrivato:', other: 'Questi ${count} file non sono arrivati:', ), 
			'operation.export.stash.emailOffer' => 'Oppure, per tua comodità, possiamo inviarti un\'email con un link diretto.',
			'operation.export.stash.emailMe' => 'Inviami un link via email',
			'operation.export.stash.emailSent' => 'Ti abbiamo inviato un link per il download.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Impossibile inviare l\'email: ${error}',
			'operation.export.stash.freeTier' => 'Gli account gratuiti possono conservare un solo archivio alla volta. Gli abbonati possono conservarne quanti ne vogliono.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Inviato ${count} file all\'Archivio File di Ham2K (stash.ham2k.net)', other: 'Inviati ${count} file all\'Archivio File di Ham2K (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Nessuno spot corrisponde ai filtri',
			'operation.spots.error' => ({required Object error}) => 'Impossibile caricare gli spot: ${error}',
			'operation.spots.unknownBand' => 'Altro',
			'operation.spots.auto' => 'Automatico',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatico (Attualmente ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Qualsiasi',
			'operation.spots.allBands' => 'Tutte le Bande',
			'operation.spots.allModes' => 'Tutti i Modi',
			'operation.spots.phoneAndCw' => 'Fonia e CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} spot', other: '${count} spot', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => '${count} spot visualizzati su ${total}',
			'operation.spots.spotsDisabled' => 'Spot disattivati per questa operazione',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minuti',
			'operation.spots.callsOfNote' => 'Nominativi di rilievo',
			'operation.spots.yourSpots' => 'I tuoi Spot',
			'operation.spots.allSpots' => 'Tutti gli Spot',
			'operation.spots.continents.af' => 'Africa',
			'operation.spots.continents.as' => 'Asia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Nord America',
			'operation.spots.continents.oc' => 'Oceania',
			'operation.spots.continents.sa' => 'Sud America',
			'operation.spots.continents.an' => 'Antartide',
			'operation.spots.filters.title' => 'Filtra Spot',
			'operation.spots.filters.band' => 'Banda',
			'operation.spots.filters.mode' => 'Modo',
			'operation.spots.filters.age' => 'Durata',
			'operation.spots.filters.sources' => 'Fonti',
			'operation.spots.filters.continent' => 'Continente',
			'operation.spots.filters.sorting' => 'Ordinamento',
			'operation.spots.filters.sortByTime' => 'Per orario spot',
			'operation.spots.filters.sortByFrequency' => 'Per frequenza',
			'operation.spots.filters.sortByWanted' => 'Più ricercati',
			'operation.spots.filters.groupByBand' => 'Raggruppa per Banda',
			'operation.spots.filters.groupCallsWithNotes' => 'Raggruppa i Nominativi con annotazioni',
			'operation.spots.filters.alertingOnly' => 'Solo Spot con avvisi',
			'operation.spots.filters.sourceNoReply' => 'Nessuna risposta',
			'operation.spots.filters.sourceError' => 'Errore',
			'operation.spots.unavailableTitle' => 'Spot non disponibili',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} non ha risposto.',
			'operation.spots.failedTitle' => 'Errore della fonte spot',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} ha restituito un errore.',
			'operation.spots.slideLogIt' => 'Registra',
			'operation.spots.slideIgnore' => 'Ignora',
			'operation.spots.slideRestore' => 'Ripristina',
			'operation.spots.logConflict.title' => 'Il pannello di logging è occupato',
			'operation.spots.logConflict.editingBody' => 'Stai modificando un contatto registrato. Registrare invece questo spot, o tornare indietro e finire la modifica?',
			'operation.spots.logConflict.composingBody' => 'Hai iniziato a inserire un contatto. Registrare invece questo spot, o tornare indietro e finire quello che stavi scrivendo?',
			'operation.spots.logConflict.goBack' => 'Torna indietro',
			'operation.spots.logConflict.clearAndLog' => 'Cancella e registra lo spot',
			'operation.import.title' => 'Importa Dati nell\'Operazione',
			'operation.import.importAdifAction' => 'Importa QSO da ADIF',
			'operation.import.settingsButton' => 'Impostazioni di ascolto',
			'operation.import.settingsTitle' => 'Ascolta altre app',
			'operation.import.protocolAddressLabel' => 'Indirizzo',
			'operation.import.protocolPortLabel' => 'Porta',
			'operation.import.protocolPortInvalid' => 'Inserisci una porta tra 1 e 65535',
			'operation.import.protocolAddressInvalid' => 'Inserisci un indirizzo IP valido (es. 127.0.0.1 o 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Ricezione dati',
			'operation.import.protocolStatusNoData' => 'Nessun dato ricevuto di recente',
			'operation.import.protocolBindError' => ({required Object error}) => 'Impossibile avviare l\'ascolto: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Impossibile salvare i QSO in arrivo, nuovo tentativo in corso: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Qualsiasi (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → scheda Broadcast Data → seleziona "Enable Broadcasts" per i contatti. Imposta l\'indirizzo IP a 127.0.0.1 se in esecuzione su questo stesso computer, o 255.255.255.255 per trasmettere in broadcast sulla rete locale attuale.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → scheda Reporting → sezione UDP Server → seleziona "Accept UDP requests". Imposta UDP Server a 127.0.0.1 se in esecuzione su questo stesso computer, o un indirizzo multicast come 239.239.0.2, e usa lo stesso indirizzo nella configurazione qui sopra in questa app.',
			'operation.import.listenTitle' => 'Ascolta i QSO da altre app',
			'operation.import.listenDescriptionOnN1mm' => 'In ascolto di N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'In ascolto di WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'In ascolto di N1MM+ e WSJT-X',
			'operation.import.listenDescriptionOff' => 'Disattivato',
			'operation.import.addToOperationTitle' => 'Aggiungi a questa operazione',
			'operation.import.addToOperationDescriptionOn' => 'I QSO catturati vengono aggiunti a questa operazione appena arrivano',
			'operation.import.addToOperationDescriptionOff' => 'I QSO catturati vengono trattenuti finché non attivi questa opzione',
			'operation.import.pendingSectionTitle' => 'QSO catturati',
			'operation.import.pendingEmpty' => 'Ancora nessuna cattura',
			'operation.import.stationMismatch' => ({required Object call}) => 'Registrato come ${call}, non la stazione di questa operazione',
			'operation.import.discardAction' => 'Scarta',
			'operation.import.gapDialogTitle' => 'Includere le catture precedenti?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Altri ${count} QSO erano stati catturati in precedenza, prima di un\'interruzione nei dati. Includere anche quelli?',
			'operation.import.gapDialogRecentOnly' => 'Solo i recenti',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Includi tutti i ${count}',
			'map.outlineIssue.link' => 'Problemi?',
			'map.outlineIssue.title' => 'Segnala un problema del contorno',
			'map.outlineIssue.reference' => 'Quale contorno',
			'map.outlineIssue.severity' => 'Quanto è grave?',
			'map.outlineIssue.minor' => 'Dettaglio minore',
			'map.outlineIssue.major' => 'Problema serio',
			'map.outlineIssue.explanation' => 'Cosa c\'è che non va?',
			'map.outlineIssue.explanationHint' => 'Cosa sbaglia il contorno, e dove',
			'map.outlineIssue.send' => 'Invia',
			'map.outlineIssue.sending' => 'Invio della segnalazione — grazie',
			'map.outlineIssue.copy' => 'Copia segnalazione',
			'map.outlineIssue.notSent' => 'Impossibile inviare la segnalazione',
			'map.outlineIssue.copied' => 'Segnalazione copiata',
			'map.outlineIssue.notCopied' => 'Impossibile copiare la segnalazione',
			'map.outlinesDisclaimer' => 'I contorni sono solo indicativi. Verifica sempre per conto tuo!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contorni: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Confini: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Strutture: ${sources}',
			'map.fullCredits' => 'Crediti completi dei dati',
			'map.fewerCredits' => 'Meno crediti',
			'map.emptyState' => 'Ancora nessuna posizione dei QSO.\nI QSO con locatore, stato o paese appariranno qui.',
			'map.unavailable' => 'La mappa non è disponibile al momento.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Piatta',
			'map.globe' => 'Globo',
			'map.zoomIn' => 'Ingrandisci',
			'map.zoomOut' => 'Riduci',
			'map.resetNorth' => 'Riporta il nord in alto',
			'map.postcard.button' => 'Cartolina dell\'Operazione',
			'map.postcard.title' => ({required Object title}) => 'Cartolina per ${title}',
			'map.postcard.portrait' => 'Verticale',
			'map.postcard.landscape' => 'Orizzontale',
			'map.postcard.square' => 'Quadrata',
			'map.postcard.save' => 'Salva…',
			'map.postcard.download' => 'Scarica',
			'map.postcard.share' => 'Condividi',
			'map.postcard.copy' => 'Copia',
			'map.postcard.copied' => 'Copiata negli appunti',
			'map.postcard.saved' => ({required Object path}) => 'Salvata in ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Scaricato ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Salvate ${count} immagini in ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Salvati ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} erano già stati salvati',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Download di ${count} immagini — consentilo se il browser lo chiede',
			'map.postcard.mapLeftOut' => 'La mappa non si è caricata, quindi è stata omessa',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — la mappa non si è caricata, quindi è stata omessa',
			'map.postcard.continued' => ({required Object title}) => '${title} (continua)',
			'map.postcard.previousPage' => 'Pagina precedente',
			'map.postcard.nextPage' => 'Pagina successiva',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Pagina ${page} di ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} Q', other: '${count} Q', ), 
			'map.postcard.options' => 'Opzioni Cartolina',
			'map.postcard.bandLegend' => 'Mostra la legenda delle bande',
			'map.postcard.grayline' => 'Mostra la grayline',
			'map.postcard.sectionsAndOrder' => 'Sezioni del riepilogo e ordine',
			'map.postcard.sectionDays' => 'Ogni giorno',
			'map.postcard.reset' => 'Ripristina',
			'map.postcard.failed' => ({required Object error}) => 'Impossibile creare la cartolina: ${error}',
			'map.postcard.mapNotReady' => 'La mappa non ha finito di caricarsi. Controlla la connessione e riprova.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Impossibile salvare la cartolina: ${error}',
			'map.postcard.copyFailed' => 'Gli appunti non hanno accettato l\'immagine. Riprova.',
			'map.postcard.shareFailed' => 'Impossibile condividere la cartolina. Riprova.',
			'map.postcard.fileName' => 'cartolina',
			'mapsView.title' => 'Mappe',
			'mapsView.searchHint' => 'Cerca parchi, vette e altro',
			'mapsView.activities' => 'Attività',
			'mapsView.layers' => 'Livelli',
			'mapsView.baseMap' => 'Mappa di base',
			'mapsView.satellite' => 'Satellite (Esri)',
			'mapsView.facilities' => 'Strutture dei parchi',
			'mapsView.boundaries' => 'Confini',
			'mapsView.currentLocation' => 'Posizione attuale',
			'mapsView.noMatches' => ({required Object text}) => 'Nessun risultato per “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} referenza a ${where}', other: '${count} referenze a ${where}', ), 
			'mapsView.startOperation' => 'Avvia un\'operazione con queste referenze',
			'activitiesView.title' => 'Attività',
			'activitiesView.activitiesCountZero' => 'Nessuna attività selezionata',
			'activitiesView.activitiesCountOne' => '1 Attività',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Attività',
			'activitiesView.empty' => 'Ancora nessuna attività — usa Suggerimenti e Ricerca qui sotto per aggiungerne una',
			'activitiesView.removeActivity' => 'Rimuovi',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Apri ${name}',
			'activitiesView.editActivity' => 'Modifica attività',
			'activitiesView.manageExtensions' => 'Gestisci Estensioni',
			'activitiesView.manage' => 'Gestisci',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipi di attività: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipi di attività: ${first} e ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipi di attività: ${first}, ${second} e altri ${more}',
			'activitiesView.reference' => 'Referenza',
			'activitiesView.invalidReference' => 'Non valida',
			'activitiesView.duplicateReference' => 'Già aggiunta',
			'activitiesView.searchHint' => 'Cerca per nome, referenza o altro…',
			'activitiesView.noSuggestions' => 'Nessun risultato',
			'activitiesView.noSuggestionsHint' => 'Cerca sopra per nome o numero di referenza',
			'activitiesView.noSuggestionsExample' => '(per esempio \'trail\' o \'4556\')',
			'activitiesView.allOptions' => 'Tipi di attività',
			'activitiesView.determiningLocation' => 'Rilevamento della posizione attuale…\nIn attesa del fix GPS per trovare le referenze vicine',
			'activitiesView.locationUnavailableTitle' => 'Dati di posizione non disponibili',
			'activitiesView.locationDeniedTitle' => 'Permesso di posizione negato',
			'activitiesView.locationBlockedTitle' => 'Permesso di posizione bloccato',
			'activitiesView.noNearbyReason' => 'Impossibile determinare le referenze vicine',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Tocca ${icon} per inserire manualmente la tua posizione,\no cerca semplicemente le referenze per nome',
			'activitiesView.locationGrantAction' => 'Consenti l\'accesso alla posizione',
			'activitiesView.locationSettingsAction' => 'Apri Impostazioni',
			'activitiesView.locationSettingsUnavailable' => 'Consenti l\'accesso alla posizione nelle impostazioni di sistema',
			'activitiesView.locationGrantRefused' => 'Ancora nessuna posizione — il sistema ha di nuovo negato il permesso',
			'activitiesView.searchUnavailableTitle' => 'Ricerca attività non disponibile',
			'activitiesView.searchUnavailableReason' => 'Un\'estensione di attività non ha potuto rispondere alla ricerca. Riprova tra un momento.',
			'activitiesView.emptySheet' => 'Usa suggerimenti e ricerca qui sotto per aggiungerne una',
			'activitiesView.exports' => 'Esportazioni',
			'activitiesView.exportLogs' => 'Esporta Log',
			'activitiesView.tools' => 'Strumenti',
			'activitiesView.toolsTitle' => 'Strumenti dell\'operazione',
			'activitiesView.operationDetails' => 'Dettagli operazione',
			'activitiesView.share' => 'Condividi',
			'activitiesView.archive' => 'Archivia',
			'activitiesView.deleteOperation' => 'Elimina Operazione',
			'activitiesView.undeleteOperation' => 'Ripristina Operazione',
			'activitiesView.alreadySelected' => 'Già selezionata',
			'activitiesView.selected' => 'Selezionata',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} di ${count}',
			'activitiesView.previousPick' => 'Risultato precedente',
			'activitiesView.nextPick' => 'Risultato successivo',
			'activitiesView.retiredReference' => 'Ritirata',
			'activitiesView.enableExtension' => ({required Object name}) => 'Abilita ${name}',
			'activitiesView.enableExtensionHint' => 'Questa estensione corrisponde alla ricerca, ma al momento non è abilitata',
			'activitiesView.enableExtensionForRefHint' => 'Questa estensione gestisce una delle referenze di questa operazione, ma al momento non è abilitata',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} non è in esecuzione',
			'activitiesView.extensionNotRunningHint' => 'Questa estensione è stata disattivata, apri Impostazioni Estensioni per maggiori informazioni',
			'activitiesView.installExtension' => ({required Object name}) => 'Installa ${name}',
			'activitiesView.installExtensionHint' => 'Questa estensione corrisponde alla ricerca, ma non è installata',
			'activitiesView.onlyCatalogMatches' => 'Nessun risultato\nAlcune estensioni nel catalogo potrebbero avere risultati.\nInstallale in Tipi di attività qui sotto.',
			'activitiesView.setupUnavailable' => 'Impossibile caricare la configurazione di questa attività — riprova da Gestisci',
			'activitiesView.controlsUnavailableTitle' => 'Controlli attività non disponibili',
			'activitiesView.controlsUnavailableReason' => 'Le tue referenze sono al sicuro, ma al momento non è possibile modificarle.',
			'activitiesView.controlsUnavailableRetry' => 'Riprova',
			'activitiesView.onlyDisabledMatches' => 'Nessun risultato\nAlcune estensioni disponibili potrebbero avere risultati.\nAbilitale in Tipi di attività qui sotto.',
			'activitiesView.onlyNotRunningMatches' => 'Nessun risultato\nAlcune estensioni che potrebbero avere risultati non sono in esecuzione.\nVedi Tipi di attività qui sotto.',
			'activitiesView.mapToggle' => 'Mappa',
			'activitiesView.searchToggle' => 'Cerca',
			'activitiesView.addToOperation' => 'Aggiungi all\'Operazione',
			'activitiesView.addToOperationShort' => 'Aggiungi all\'Op.',
			'activitiesView.mapEmptyState' => 'Nessun risultato da mostrare sulla mappa',
			'activitiesView.mapEmptyStateHint' => 'Torna all\'elenco, o cerca qualcos\'altro',
			'activitiesView.imports' => 'Importazioni',
			'loggingControls.timeUtc' => 'Ora (UTC)',
			'loggingControls.date' => 'Data',
			'loggingControls.now' => 'Adesso',
			'loggingControls.manualTimeSettings' => 'Ora manuale',
			'loggingControls.manualTimeIncrement' => 'Incremento per QSO',
			'loggingControls.manualTimeIncrementNone' => 'Nessuno',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} minuto', other: '${count} minuti', ), 
			'loggingControls.frequency' => 'Frequenza',
			'loggingControls.mode' => 'Modo',
			'loggingControls.theirCall' => 'Nominativo',
			'loggingControls.noteField' => 'Nota',
			'loggingControls.todoField' => 'Da fare',
			'loggingControls.sent' => 'Inviato',
			'loggingControls.rcvd' => 'Ricev',
			'loggingControls.more' => 'Altro',
			'loggingControls.revert' => 'Ripristina',
			'loggingControls.undoDelete' => 'Annulla eliminazione',
			'loggingControls.restore' => 'Ripristina',
			'loggingControls.wipe' => 'Cancella',
			'loggingControls.undo' => 'Annulla',
			'loggingControls.pendingDeleteTapWarning' => 'Tocca ancora una volta il cestino per eliminare questo QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Fai clic ancora una volta sul cestino per eliminare questo QSO',
			'loggingControls.deletedQsoWarning' => 'QSO eliminato',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Tocca ancora una volta il cestino per eliminare questo ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Fai clic ancora una volta sul cestino per eliminare questo ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} eliminato',
			'loggingControls.timeControl' => 'Ora',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Potenza',
			'loggingControls.notesControl' => 'Note',
			'loggingControls.power' => 'Potenza',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controlli di Logging',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Auto-spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Auto-spot a ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} a ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Troppo tardi per spottare ${call}',
			'loggingControls.spotNoFreq' => 'Prima imposta una frequenza per lo spot',
			'loggingControls.selfSpotDisabled' => 'Auto-spot disattivato',
			'loggingControls.spotComment' => 'Commento',
			'loggingControls.spottingAutoControl' => 'Re-spot automatico',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Re-spot ogni ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Auto tra ${time}. Fermare?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto tra ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto tra ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto tra ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Re-spot automatico non avviato: lo spot non è andato a buon fine',
			'loggingControls.spotAutoMoved' => 'Re-spot automatico non avviato: la frequenza è cambiata durante lo spot',
			'loggingControls.spotAutoStopped' => 'Re-spot automatico fermato',
			'loggingControls.spotAutoLeftFreq' => 'Re-spot automatico fermato: la frequenza è cambiata',
			'loggingControls.spotAutoNoFreq' => 'Re-spot automatico fermato: la radio non riporta alcuna frequenza',
			'loggingControls.spotBusy' => 'Un altro spot è ancora in invio',
			'loggingControls.bandOrFreqRequired' => 'Imposta una frequenza o una banda prima di registrare',
			'loggingControls.missingBand' => 'Nessuna Banda',
			'loggingControls.missingMode' => 'Nessun Modo',
			'loggingControls.saveFailed' => ({required Object error}) => 'Impossibile salvare: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => 'Impossibile eliminare: ${error}',
			'loggingControls.info.noQsos' => 'Ancora nessun QSO... andiamo in aria!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} dall\'ultimo',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h per gli ultimi 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h per gli ultimi 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} verso',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verso',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verso',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} di distanza',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) di distanza',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) di distanza',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplicato!',
			'loggingControls.info.noticeNewBand' => 'Nuova Banda',
			'loggingControls.info.noticeNewMode' => 'Nuovo Modo',
			'loggingControls.info.noticeNewDXCC' => 'Nuovo DXCC',
			'loggingControls.info.noticeNewState' => 'Nuovo Stato',
			'loggingControls.info.noticeNewProvince' => 'Nuova Provincia',
			'loggingControls.info.noticeNewDay' => 'Nuovo giorno',
			'loggingControls.info.noticeNewRef' => 'Nuova Ref',
			'loggingControls.info.noticeNewMult' => 'Nuovo Molt',
			'loggingControls.info.noticeNewZone' => 'Nuova Zona',
			'loggingControls.info.noticeInvalidMode' => 'Modo errato',
			'loggingControls.info.noticeInvalidBand' => 'Banda errata',
			'loggingControls.info.noticeInvalidCategory' => 'Non collegabile',
			'loggingControls.info.noticeOverTime' => 'Tempo scaduto',
			'loggingControls.info.noticeWorkedBefore' => 'Già collegato',
			'loggingControls.info.noticeNewPark' => 'Nuovo Parco',
			'loggingControls.info.noticeNewSection' => 'Nuova Sezione',
			'loggingControls.info.noticeBonusStation' => 'Stazione Bonus!',
			'loggingControls.info.noticeMissingExchange' => 'Nessuno Scambio',
			'loggingControls.info.noticeInvalidExchange' => 'Scambio errato',
			'loggingControls.info.noticeUnknownEvent' => 'Evento sconosciuto',
			'loggingControls.info.noticeIncompleteCall' => 'Nominativo incompleto — Non conteggiato',
			'loggingControls.info.noticeOurGrid' => 'Imposta il nostro Locatore',
			'loggingControls.info.noticeRareCounty' => 'Contea rara!',
			'loggingControls.info.noticeOurLocation' => 'Imposta la nostra Contea',
			'loggingControls.info.noticeShortGrid' => 'Locatore troppo corto',
			'formChrome.untitled' => '(senza titolo)',
			'formChrome.showMore' => 'Mostra altro',
			'formChrome.showAll' => 'Mostra tutto',
			'formChrome.showFewer' => 'Mostra meno',
			'formChrome.defaults' => 'Predefiniti',
			'formChrome.search' => 'Cerca',
			'formChrome.clear' => 'Cancella',
			'formChrome.openPage' => 'Apri pagina',
			'formChrome.connected' => 'Connesso',
			'formChrome.notConnected' => 'Non connesso',
			'formChrome.manage' => 'Gestisci',
			'formChrome.connect' => 'Connetti',
			'formChrome.formTitle' => 'Modulo',
			'formChrome.addItem' => ({required Object label}) => 'Aggiungi ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Modifica ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => '${shown} visualizzati su ${total} (${selected} selezionati)',
			'formChrome.validationError' => ({required Object error}) => 'Errore di validazione: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Errore di trasformazione: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Errore: ${error}',
			'formChrome.removeItem' => 'Elimina',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'Eliminare ${name}?',
			'formChrome.storageUnavailable' => 'Credenziali non disponibili',
			'qsoEditForm.title' => 'Modifica QSO',
			'qsoEditForm.operatorCall' => 'Operatore',
			'qsoEditForm.position' => 'Postazione',
			'qsoEditForm.theirName' => 'Nome',
			'qsoEditForm.theirGrid' => 'Locatore',
			'qsoEditForm.theirState' => 'Stato',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Note',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Le loro informazioni',
			'qsoEditForm.sectionOur' => 'Le nostre informazioni',
			'qsoEditForm.sectionNotes' => 'Note',
			'qsoEditForm.theirCity' => 'Città',
			'qsoEditForm.theirCounty' => 'Contea',
			'qsoEditForm.theirEntity' => 'Entità',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Sezione ARRL',
			'qsoEditForm.theirLat' => 'Latitudine',
			'qsoEditForm.theirLon' => 'Longitudine',
			'qsoEditForm.theirPower' => 'La loro potenza',
			'qsoList.empty' => 'Ancora nessun QSO — collega qualcuno!',
			'qsoList.bandOrModeWarning' => 'Assicurati che banda e modo siano corretti',
			'qsoList.today' => 'Oggi',
			'qsoList.yesterday' => 'Ieri',
			'qsoList.tomorrow' => 'Domani',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Trova nel log (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Trova nel log',
			'qsoList.find.hint' => 'Numero QSO o nominativo',
			'qsoList.find.noMatches' => 'Nessun risultato',
			'qsoList.find.noOperationQsos' => 'Nessun QSO in questa operazione',
			'qsoList.find.noPeriodQsos' => 'Nessun QSO in questo periodo',
			'qsoList.find.outsideQsosOne' => '1 QSO fuori da questa operazione',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSO fuori da questa operazione',
			'qsoList.find.pastQsosOne' => '1 QSO precedente',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} QSO precedenti',
			'loggingPanel.stats' => 'Statistiche dell\'operazione',
			'loggingPanel.scoring' => 'Punteggio',
			'loggingPanel.dxccEntities' => 'Entità DXCC',
			'loggingPanel.statesWorked' => 'Stati',
			'loggingPanel.provincesWorked' => 'Province',
			'loggingPanel.duplicates' => 'Duplicati',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostra immagine',
			'callInfo.imageUnavailable' => 'Foto non disponibile',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Note',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} verso',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verso',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verso',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} di distanza',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) di distanza',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) di distanza',
			'callInfo.thisOpCountOne' => '1 QSO in questa operazione',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSO in questa operazione',
			'callInfo.otherOpsCountOne' => '1 QSO in altre operazioni',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSO in altre operazioni',
			'callInfo.andMore' => ({required Object count}) => '… e altri ${count}',
			'callInfo.withCall' => ({required Object call}) => 'con ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'da ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} negli ultimi 7 giorni',
			'callInfo.history.today' => ({required Object n}) => '${n} oggi',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => 'Impostazioni',
			'settings.language' => 'Lingua',
			'settings.languageSystem' => ({required Object language}) => 'Segui le impostazioni di sistema (${language})',
			'settings.theme.title' => 'Tema',
			'settings.theme.system' => 'Segui le impostazioni di sistema',
			'settings.theme.light' => 'Chiaro',
			'settings.theme.dark' => 'Scuro',
			'settings.themeDescription.system' => 'Segue le impostazioni di sistema',
			'settings.themeDescription.light' => 'Sempre in Modalità Chiara',
			'settings.themeDescription.dark' => 'Sempre in Modalità Scura',
			'settings.fontScale' => 'Dimensione del Carattere',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Più Piccolo--',
			'settings.fontScaleOpts.smallestMinus' => 'Più Piccolo-',
			'settings.fontScaleOpts.smallest' => 'Più Piccolo',
			'settings.fontScaleOpts.smaller' => 'Piccolo',
			'settings.fontScaleOpts.normal' => 'Normale',
			'settings.fontScaleOpts.larger' => 'Grande',
			'settings.fontScaleOpts.largest' => 'Più Grande',
			'settings.fontScaleOpts.largestPlus' => 'Più Grande+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Più Grande++',
			'settings.keepDeviceAwake.title' => 'Mantieni il dispositivo attivo',
			'settings.keepDeviceAwake.descriptionOn' => 'Resta attivo mentre sei nella vista di logging o è in corso una sincronizzazione',
			'settings.keepDeviceAwake.descriptionOff' => 'Va in standby come di consueto',
			'settings.layoutDensity' => 'Densità del layout',
			'settings.layoutDensityOpts.auto' => 'Automatica',
			'settings.layoutDensityOpts.densest' => 'Massima',
			'settings.layoutDensityOpts.dense' => 'Densa',
			'settings.layoutDensityOpts.normal' => 'Normale',
			'settings.layoutDensityOpts.sparse' => 'Ampia',
			'settings.layoutDensityOpts.sparsest' => 'Più ampia',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'la finestra è troppo bassa, viene usata ${effective}',
			'settings.layoutDensityAtLimit' => 'al limite',
			'settings.distanceUnits' => 'Unità di distanza',
			'settings.distanceUnitsOpts.kilometers' => 'Chilometri',
			'settings.distanceUnitsOpts.miles' => 'Miglia',
			'settings.userInterface' => 'Interfaccia utente',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Modalità Mancina',
			'settings.logging.leftieMode.descriptionOn' => 'Usa il layout per mancini',
			'settings.logging.leftieMode.descriptionOff' => 'Usa il layout per destrimani',
			'settings.logging.countryFlags.title' => 'Bandiere dei Paesi',
			'settings.logging.countryFlags.dx' => 'Mostra solo per i contatti DX',
			'settings.logging.countryFlags.all' => 'Mostra le bandiere per tutti i contatti',
			'settings.logging.countryFlags.none' => 'Non mostrare alcuna bandiera',
			'settings.logging.countryFlagsDescription.dx' => 'Mostra le bandiere solo per i contatti DX',
			'settings.logging.countryFlagsDescription.all' => 'Mostra le bandiere per tutti i contatti',
			'settings.logging.countryFlagsDescription.none' => 'Non mostra alcuna bandiera',
			'settings.logging.suggestDefaultOperator.title' => 'Suggerisci Operatore',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Propone il tuo nominativo come operatore quando un\'operazione usa un nominativo di stazione diverso',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Lascia vuoto l\'operatore se non lo compili tu',
			'settings.logging.showBearing.title' => 'Mostra Direzione',
			'settings.logging.showBearing.descriptionOn' => 'Mostra la direzione stimata verso la stazione',
			'settings.logging.showBearing.descriptionOff' => 'Non mostra informazioni sulla direzione',
			'settings.logging.showReverseBearing.title' => 'Mostra anche la direzione inversa',
			'settings.logging.showReverseBearing.descriptionOn' => 'Mostra anche la direzione dalla stazione, come "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Mostra solo la direzione verso la stazione',
			'settings.logging.switchSentRcvd.title' => 'Inverti ordine del rapporto (RST)',
			'settings.logging.switchSentRcvd.sentFirst' => 'Inviato prima, Ricevuto dopo',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Ricevuto prima, Inviato dopo',
			'settings.logging.jumpAfterRST.title' => 'Salta al campo successivo dopo l\'RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Passa al campo successivo dopo l\'inserimento dell\'RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Non passa automaticamente',
			'settings.logging.defaultReport.title' => 'Rapporto predefinito — Fonia',
			'settings.logging.defaultReport.description' => 'Usato quando Inviato o Ricevuto è vuoto in SSB, FM o AM',
			'settings.logging.defaultReportCW.title' => 'Rapporto predefinito — CW e digitali',
			'settings.logging.defaultReportCW.description' => 'Usato quando Inviato o Ricevuto è vuoto in CW, RTTY e altri modi digitali',
			'settings.logging.defaultReportFT8.title' => 'Rapporto predefinito — FT8 e FT4',
			'settings.logging.defaultReportFT8.description' => 'Usato quando Inviato o Ricevuto è vuoto nei modi FT',
			'settings.logging.numbersRow.title' => 'Riga numerata',
			'settings.logging.numbersRow.description' => 'Mostra una riga di tasti numerici sopra la tastiera durante il logging',
			'settings.logging.numbersRowExtra.title' => 'Tasto barra e punto',
			'settings.logging.numbersRowExtra.description' => 'Aggiunge un tasto contestuale: “/” per i nominativi, “.” per i numeri',
			'settings.logging.numbersRowVibrate.title' => 'Vibra alla pressione dei tasti',
			'settings.logging.numbersRowVibrate.description' => 'Feedback aptico quando tocchi un tasto numerico',
			'settings.logging.bands' => 'Bande preferite',
			'settings.logging.modes' => 'Modi preferiti',
			'settings.catServer.title' => 'Server CAT',
			'settings.catServer.description' => 'Consenti ad altre app (WSJT-X, logger, ecc.) di controllare la radio tramite Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocollo',
			'settings.catServer.protocolOpts.off' => 'Disabilitato',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Porta',
			'settings.catServer.openAccess' => 'Accesso aperto',
			'settings.catServer.openAccessOn' => 'Qualsiasi computer sulla rete locale può connettersi.',
			'settings.catServer.openAccessOff' => 'Solo le app su questo computer possono connettersi.',
			'settings.catServer.allowTransmit' => 'Consenti alle app di trasmettere',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'Le app possono attivare il PTT della radio, per un massimo di ${minutes} minuti alla volta.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'Le app su qualsiasi computer della rete locale possono attivare il PTT della radio, per un massimo di ${minutes} minuti alla volta.',
			'settings.catServer.allowTransmitOff' => 'Le app non possono mettere in trasmissione la radio. Usa il VOX o il loro PTT.',
			'settings.catServer.allowTransmitUnsupported' => 'La radio del VFO principale non può essere messa in trasmissione da Ham2K Logger, quindi le app non possono trasmettere attraverso di essa.',
			'settings.catServer.off' => 'Disattivato.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, avvio in corso…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} sulla porta ${port}. Client connessi: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} sulla porta ${port}, ma non è connessa nessuna radio sul VFO principale.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} non può ascoltare sulla porta ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} non può ascoltare sulla porta ${port}: un altro programma la sta usando, spesso ${protocol} stesso. Chiudi quel programma o scegli un\'altra porta.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} non può ascoltare sulla porta ${port}: questo computer non lo consente. Scegli una porta superiore a 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} ha smesso di ascoltare sulla porta ${port}. Nuovo tentativo…',
			'settings.cluster.title' => 'DX Cluster',
			'settings.cluster.description' => 'Il server a cui le estensioni inviano gli spot e da cui li leggono, connesse con il nominativo dell\'operatore.',
			'settings.cluster.connect' => 'Connetti al cluster',
			'settings.cluster.connectOn' => 'Le estensioni si connettono al cluster quando ne hanno bisogno',
			'settings.cluster.connectOff' => 'Niente si connette al cluster',
			'settings.cluster.console' => 'Mostra Console',
			'settings.cluster.consoleDescription' => 'Ciò che il cluster invia, e un posto dove digitare comandi',
			'settings.cluster.consoleTitle' => 'Console del Cluster',
			'settings.cluster.consoleConnect' => 'Connetti',
			'settings.cluster.consoleDisconnect' => 'Disconnetti',
			'settings.cluster.consoleCommand' => 'Comando',
			'settings.cluster.consoleEmpty' => 'Ancora niente. Connettiti, o aspetta che un\'estensione usi il cluster.',
			'settings.cluster.consoleRetry' => ({required Object command}) => 'Nuovo invio: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => 'Non inviato: ${command} (${reason})',
			'settings.cluster.server' => 'Server del Cluster',
			'settings.cluster.selectServer' => 'Seleziona Server',
			'settings.cluster.serverOther' => 'Altro',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'Nessun host inserito, quindi gli spot vanno a ${node}',
			'settings.cluster.customHost' => 'Server',
			'settings.cluster.customPort' => 'Porta',
			'settings.cluster.password' => 'Password',
			'settings.cluster.passwordDescription' => 'Solo se necessaria',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Password memorizzata per ${node}',
			'settings.cluster.scrollback' => 'Righe conservate',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} righe',
			'settings.cluster.connection' => 'Connessione',
			'settings.cluster.statusIdle' => 'Non connesso. Si connette quando un\'estensione ne ha bisogno. Tocca per provare.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Connessione a ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Connesso a ${node} come ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'Impossibile connettersi a ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'Non disponibile nella versione web.',
			'settings.cluster.statusOff' => 'Disattivato. Attiva Connetti al cluster per usarlo.',
			'settings.cluster.errors.noCall' => 'nessun nominativo operatore con cui accedere',
			'settings.cluster.errors.connectFailed' => 'impossibile raggiungere il nodo',
			'settings.cluster.errors.needsPassword' => 'il nodo chiede una password, e non ne è memorizzata nessuna',
			'settings.cluster.errors.loginFailed' => 'il nodo non ha accettato il login',
			'settings.cluster.errors.disconnected' => 'il nodo ha chiuso la connessione',
			'settings.cluster.errors.timeout' => 'il nodo non ha risposto',
			'settings.cluster.errors.off' => 'Connetti al cluster è disattivato',
			'settings.spotting.title' => 'Spotting',
			'settings.spotting.respotInterval' => 'Re-spot automatico ogni',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Re-spot automatico predefinito',
			'settings.spotting.autoRespotByDefaultOn' => 'Attiva il re-spot automatico dopo ogni spot inviato',
			'settings.spotting.autoRespotByDefaultOff' => 'Richiede un\'azione dell\'utente per attivare il re-spot automatico',
			'settings.spotting.pulseBeforeRespot' => 'Pulsazione prima di ogni re-spot automatico',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'Il controllo Spotting pulsa in blu nei ${seconds} secondi prima di ogni re-spot',
			'settings.spotting.pulseBeforeRespotOff' => 'Nessuna pulsazione prima di un re-spot automatico',
			'settings.radio.title' => 'Controllo CAT',
			'settings.radio.loggingAndCat' => 'Logging e CAT',
			'settings.radio.tuningSection' => 'Sintonia',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Servizi',
			'settings.radio.stationConfigurationSection' => 'Configurazione Stazione',
			'settings.radio.moreSettings' => 'Altre impostazioni di configurazione della stazione',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controlla il PTT con la tastiera',
			'settings.radio.pttKey.modes.off' => 'No',
			'settings.radio.pttKey.modes.toggle' => 'Alterna',
			'settings.radio.pttKey.modes.hold' => 'Tieni premuto',
			'settings.radio.pttKey.descriptions.off' => 'La tastiera non mette in trasmissione la radio.',
			'settings.radio.pttKey.descriptions.toggle' => 'Nei modi in fonia, il tasto PTT mette in trasmissione la radio e premendolo di nuovo la rimette in ricezione. Torna in ricezione da sola dopo un minuto.',
			'settings.radio.pttKey.descriptions.hold' => 'Nei modi in fonia, la radio trasmette finché il tasto PTT resta premuto, per al massimo un minuto.',
			'settings.radio.pttKey.key' => 'Tasto PTT',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'In trasmissione',
			'settings.radio.smartVfoSnap.title' => 'Aggancio VFO intelligente',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Quando smetti di girare la manopola, arrotonda la frequenza a un passo sensato. Solo modi in fonia.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Resta esattamente dove hai sintonizzato.',
			'settings.radio.snapDebounce.title' => 'Aggancio: ritardo di assestamento',
			'settings.radio.snapDebounce.description' => 'Quanto deve restare ferma la manopola prima che la frequenza venga arrotondata. Più breve è immediato; più lungo lascia spazio a un movimento lento.',
			'settings.radio.snapLongMove.title' => 'Aggancio: movimento lungo',
			'settings.radio.snapLongMove.description' => 'Spostandosi almeno di questa quantità la frequenza si arrotonda a un kHz intero, per quanto lentamente tu abbia finito.',
			'settings.radio.snapMinMove.title' => 'Aggancio: movimento minimo',
			'settings.radio.snapMinMove.description' => 'Spostandosi meno di questa quantità la frequenza non viene arrotondata, così la sintonia fine non viene toccata.',
			'settings.radio.snapMinSpeed.title' => 'Aggancio: movimento più lento',
			'settings.radio.snapMinSpeed.description' => 'Girando la manopola più lentamente di così la frequenza non viene arrotondata, a meno che non sia un movimento lungo.',
			'settings.radio.enterSends.pillOff' => 'ESM Off',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Invio trasmette i messaggi',
			'settings.radio.enterSends.off' => 'Off',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Invio trasmette i messaggi: ${state}. Tocca per cambiare.',
			'settings.radio.keyerSpeed.title' => 'Velocità del keyer',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Messaggi del Keyer CW',
			'settings.radio.cwMessages.notSupported' => 'La radio attuale non supporta la manipolazione CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Messaggio ${n}',
			'settings.radio.cwMessages.labelField' => 'Etichetta',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Etichetta F${n}',
			'settings.radio.cwMessages.details' => 'Dettagli',
			'settings.radio.cwMessages.empty' => '(vuoto)',
			'settings.radio.cwMessages.sets' => 'Set di messaggi',
			'settings.radio.cwMessages.newSet' => 'Nuovo Set',
			'settings.radio.cwMessages.renameSet' => 'Rinomina Set',
			'settings.radio.cwMessages.deleteSet' => 'Elimina Set',
			'settings.radio.cwMessages.newSetName' => 'Nome',
			'settings.radio.cwMessages.setDefault' => 'Predefinito',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Messaggi ESM',
			'settings.radio.cwMessages.setSaved' => 'I miei messaggi',
			'settings.radio.cwMessages.repeat' => 'Ripeti Messaggio 1',
			'settings.radio.cwMessages.repeatShort' => 'Ripeti M1',
			'settings.radio.cwMessages.cooldown' => 'Pausa prima della ripetizione',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n} secondi',
			'settings.radio.cwMessages.repeatWait' => 'In ripetizione',
			'settings.radio.cwMessages.keyboard' => 'Scrivi per trasmettere',
			'settings.radio.cwMessages.keyboardField' => 'Scrivi per trasmettere',
			'settings.radio.cwMessages.help' => 'Aiuto',
			'settings.radio.cwMessages.helpTitle' => 'Scrivere i messaggi CW',
			'settings.radio.cwMessages.helpIntro' => 'I messaggi possono usare modelli con i seguenti valori:',
			'settings.radio.cwMessages.helpOpCall' => 'Il tuo nominativo',
			'settings.radio.cwMessages.helpQsoCall' => 'Il loro nominativo — in uno stack //, il nominativo che verrà registrato',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Il loro nominativo, se è un nominativo valido; vuoto se parziale',
			'settings.radio.cwMessages.helpQsoPartial' => 'Un nominativo parziale; vuoto se c\'è un nominativo completo valido',
			'settings.radio.cwMessages.helpQsoNextCall' => 'In uno stack //, il nominativo che verrà selezionato per la prossima registrazione, se è un nominativo completo valido',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'In uno stack //, il prossimo parziale dopo aver registrato il contatto attuale',
			'settings.radio.cwMessages.helpQsoName' => 'Il loro nome, come digitato o altrimenti dalla ricerca',
			'settings.radio.cwMessages.helpQsoState' => 'Il loro stato, come digitato o altrimenti dalla ricerca',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Il messaggio 1 come verrebbe trasmesso, dentro un altro messaggio. Valido per i messaggi da 1 a 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Il rapporto che stai inviando',
			'settings.radio.cwMessages.helpQsoSerial' => 'Il tuo numero progressivo, in un contest che lo prevede',
			'settings.radio.cwMessages.helpPad' => 'Riempie con zeri fino a quel numero di cifre: 7 viene trasmesso come 007',
			'settings.radio.cwMessages.helpCut' => 'Numeri abbreviati, T per 0 e N per 9: 599 viene trasmesso come 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Sceglie le cifre da abbreviare, tra virgolette — 0 è T, 1 è A, 5 è E, 9 è N',
			'settings.radio.cwMessages.helpFullExample' => 'Esempio completo:',
			'settings.radio.cwMessages.helpExample' => 'Trasmette W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Con Invio trasmette i messaggi attivo, Invio trasmette i messaggi in base al loro tasto funzione, come fa N1MM. Il set Messaggi ESM parte con questi:',
			'settings.radio.cwMessages.helpEsmCq' => 'In Run, Invio con il campo nominativo vuoto chiama CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Il tuo scambio: dopo il loro nominativo in Run, dopo la loro risposta in S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Ringraziamento, una volta registrato il contatto: qso è il contatto appena registrato, next quello successivo',
			'settings.radio.cwMessages.helpEsmMyCall' => 'In S&P, il tuo nominativo verso la stazione a cui rispondi',
			'settings.radio.cwMessages.helpEsmHisCall' => 'In Run, il loro nominativo prima del tuo scambio',
			'settings.radio.cwMessages.helpEsmAgain' => 'Chiede di ripetere quando non è stato copiato nulla del loro scambio',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 suggerito per gli stack //: ringrazia, poi chiama la stazione successiva nello stack e trasmette il tuo scambio, o chiede di ripetere un parziale (TU KR?); se non resta nulla, solo TU',
			'settings.radio.keyerControl.label' => 'Keyer',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => 'Voce',
			'settings.radio.voiceMessages.title' => 'Messaggi del Keyer in Fonia',
			'settings.radio.voiceMessages.notSupported' => 'La radio attuale non supporta i messaggi in fonia',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memoria vocale ${n}',
			'settings.radio.voiceMessages.labelField' => 'Etichetta',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Etichetta memoria vocale ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Vuota',
			'settings.radio.voiceMessages.notMeasured' => 'Durata sconosciuta',
			'settings.radio.voiceMessages.playButton' => 'Riproduci',
			'settings.radio.voiceMessages.recordButton' => 'Registra',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Ripeti Messaggio 1',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Note su ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Queste memorie sono nella radio di ${device}. I loro nomi e durate appartengono a quel dispositivo.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Salvato nella radio, dove lo vedono anche gli altri suoi client.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Attendi l\'indicatore [REC] sulla radio, poi tieni premuto il PTT e registra il messaggio. Terminalo premendo il pulsante STOP qui nell\'app prima di rilasciare il PTT per evitare click indesiderati.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Attendi che l\'indicatore [REC] lampeggi almeno quattro volte, poi tieni premuto il PTT e registra il messaggio. Terminalo premendo il pulsante STOP qui nell\'app prima di rilasciare il PTT per evitare click indesiderati.',
			'settings.radio.voiceMessages.pill' => 'Voce',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Riproduci memoria ${n}',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Registra memoria ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Ferma registrazione',
			'settings.radio.voiceMessages.playing' => 'Riproduzione…',
			'settings.radio.voiceMessages.recording' => 'Registrazione…',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Registrazione di ${label}',
			'settings.radio.voiceMessages.doubtful' => 'La radio l\'ha riprodotto? Ha segnalato subito di essere inattiva.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Le memorie vanno registrate sulla radio stessa.',
			'settings.radio.voiceMessages.sets' => 'Set di messaggi',
			'settings.radio.voiceMessages.soundFilesSet' => 'File audio su questo computer',
			'settings.radio.voiceMessages.openFileButton' => 'Apri File',
			'settings.radio.voiceMessages.newSet' => 'Nuovo Set',
			'settings.radio.voiceMessages.renameSet' => 'Rinomina Set',
			'settings.radio.voiceMessages.deleteSet' => 'Elimina Set',
			'settings.radio.voiceMessages.newSetName' => 'Nome',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => 'Eliminare ${name} e le sue registrazioni? Non può essere annullato.',
			'settings.radio.voiceMessages.output' => 'Invia l\'audio a',
			'settings.radio.voiceMessages.input' => 'Registra da',
			'settings.radio.voiceMessages.outputRadio' => 'Invia alla radio via rete',
			'settings.radio.voiceMessages.inputDefault' => 'Predefinito di sistema',
			'settings.radio.voiceMessages.pickDevice' => 'Scegli un dispositivo audio',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (non connesso)',
			'settings.radio.voiceMessages.lead' => 'Ritardo dopo il PTT',
			'settings.radio.voiceMessages.tail' => 'Ritardo prima del rilascio',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => 'Ascolta',
			'settings.radio.voiceMessages.notRecorded' => 'Non registrato',
			'settings.radio.voiceMessages.unplayable' => 'Impossibile riprodurre questo file',
			'settings.radio.voiceMessages.problemNoOutput' => 'Scegli il dispositivo audio che alimenta la radio prima di riprodurre un messaggio.',
			'settings.radio.voiceMessages.problemOutputMissing' => 'Il dispositivo audio che alimenta la radio non è connesso.',
			'settings.radio.voiceMessages.problemInputMissing' => 'Il dispositivo di registrazione non è connesso.',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'Il dispositivo audio non si è aperto.',
			'settings.radio.voiceMessages.problemNotRecorded' => 'Quel messaggio non ha ancora una registrazione.',
			'settings.radio.voiceMessages.problemRecordingSilent' => 'Dal dispositivo di registrazione non è arrivato nulla, quindi il messaggio è rimasto com\'era. Controlla l\'ingresso, e che l\'app sia autorizzata a usare il microfono.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => 'Al momento la radio non riceve audio dall\'app. Serve una connessione di rete alla radio.',
			'settings.radio.voiceMessages.problemSourceRefused' => 'La radio non ha commutato l\'audio di trasmissione sull\'app, quindi il messaggio si è fermato. Imposta la radio per trasmettere l\'audio dell\'app.',
			'settings.radio.voiceMessages.problemCannotKey' => 'Questa radio non può essere messa in trasmissione via CAT, quindi il computer non può riprodurle i messaggi.',
			'settings.radio.voiceMessages.problemUnplayable' => 'Il file di quel messaggio non è un file audio che l\'app possa riprodurre. Usa un file WAV, FLAC o MP3, oppure registralo di nuovo.',
			'settings.radio.voiceMessages.problemRecordingFailed' => 'La registrazione si è interrotta, quindi il messaggio è rimasto com\'era. Controlla che il dispositivo di registrazione sia ancora connesso e che ci sia spazio sul disco.',
			'settings.radio.voiceMessages.problemFileFailed' => 'Impossibile salvare la registrazione al posto del messaggio, che è rimasto com\'era.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'Quel messaggio richiede parole che non hai registrato: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'Il modello di quel messaggio ha un problema: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => 'I messaggi detti con le tue parole si riproducono in un\'operazione, dove c\'è un contatto per cui dirli.',
			'settings.radio.voiceMessages.problemNothingSaid' => 'Quel messaggio non dice nulla per questo contatto.',
			'settings.radio.voiceMessages.templateField' => 'Pronuncia con le mie parole',
			'settings.radio.voiceMessages.templateHelp' => 'Lascia vuoto per riprodurre la registrazione. Altrimenti il messaggio viene detto con le parole che hai registrato, compilato per ogni contatto, usando questi valori:',
			'settings.radio.voiceMessages.help' => 'Aiuto',
			'settings.radio.voiceMessages.helpTitle' => 'Dire i messaggi con le tue parole',
			'settings.radio.voiceMessages.helpFullExample' => 'Un messaggio completo:',
			'settings.radio.voiceMessages.helpExample' => 'Il loro nominativo, il loro rapporto e la tua registrazione di “QSL?”',
			'settings.radio.voiceMessages.playOnRadio' => 'Riproduci sulla Radio',
			'settings.radio.voiceMessages.templateHelpCall' => 'Il loro nominativo',
			'settings.radio.voiceMessages.templateHelpReport' => 'Il rapporto che gli dai',
			'settings.radio.voiceMessages.templateHelpMessage' => 'La registrazione del messaggio 2, riprodotta così com\'è',
			'settings.radio.voiceMessages.voiced' => 'Detto con le tue parole',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => 'Dice: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => 'Non ancora registrate: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => 'Apri un\'operazione per vedere cosa dirà.',
			'settings.radio.voiceMessages.wordsDescription' => 'Usa la tua voce per nominativi, numeri e altro.',
			'settings.radio.voiceWords.title' => 'Registrazioni delle parole',
			'settings.radio.voiceWords.callField' => 'Parole per l\'operatore',
			'settings.radio.voiceWords.intro' => 'Registra ogni parola o numero tre volte, di seguito e velocemente, come lo diresti in un nominativo. Le frasi più lunghe si registrano una volta sola.',
			'settings.radio.voiceWords.recordAll' => 'Registra Tutto',
			'settings.radio.voiceWords.recordAllGuide' => 'Leggi ogni parola tre volte, di seguito, e una frase di più parole una volta sola, con una pausa di respiro tra le righe. Premi Stop dopo l\'ultima.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => 'Di\' “${word} ${word} ${word}”, poi premi Stop.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => 'Di\' “${words}”, poi premi Stop.',
			'settings.radio.voiceWords.recorded' => 'Registrata',
			'settings.radio.voiceWords.notRecorded' => 'Non registrata',
			'settings.radio.voiceWords.addPhrase' => 'Aggiungi Frase',
			'settings.radio.voiceWords.phraseField' => 'Frase, come la scrivi in un messaggio',
			'settings.radio.voiceWords.deletePhrase' => 'Elimina frase',
			'settings.radio.voiceWords.tryField' => 'Prova a dire',
			'settings.radio.voiceWords.pauseLetters' => 'Pausa tra le lettere',
			'settings.radio.voiceWords.pauseWords' => 'Pausa tra le parole',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => 'Velocità',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => 'Impostazioni avanzate',
			'settings.radio.voiceWords.splitSilent' => 'Nella registrazione non si sente nulla.',
			'settings.radio.voiceWords.splitNotThreeTakes' => 'Impossibile trovare tre ripetizioni. Di\' la parola tre volte, di seguito, e riprova.',
			'settings.radio.voiceWords.splitLineCount' => 'Impossibile trovare tutte le parole nella lettura. Leggi ognuna tre volte, con una pausa di respiro tra le parole.',
			'settings.radio.voiceWords.splitLinesTooClose' => 'Impossibile distinguere le parole. Lascia una pausa più lunga tra le parole.',
			'settings.radio.avoidZeroBeat.title' => 'Evita lo zero-beat sugli spot',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Con una radio connessa, sintonizza qualche Hz fuori da uno spot CW, così chi risponde non chiama tutto sulla stessa nota.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Sintonizza esattamente sulla frequenza dello spot.',
			'settings.radio.zeroBeatRange.title' => 'Zero-beat: intervallo di scostamento',
			'settings.radio.zeroBeatRange.description' => 'Quanto lontano dalla frequenza dello spot posizionarsi, da entrambi i lati. Lo scostamento non è mai vicino a zero — sarebbe di nuovo uno zero beat.',
			'settings.help.title' => 'Aiuto e Risorse',
			'settings.help.description' => 'Comunità e supporto',
			'settings.help.forums' => 'Forum Ham2K',
			'settings.help.forumsDescription' => 'Trova aiuto, dai feedback, discuti idee…',
			'settings.help.chat' => 'Chat di Ham2K',
			'settings.help.chatDescription' => 'Il server Discord per la nostra comunità online',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Video e live stream',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Perché non puoi avere troppe foto…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Seguici per notizie e aggiornamenti',
			'settings.help.contact' => 'Contattaci',
			'settings.help.contactDescription' => 'help@ham2k.com — ma prova prima i Forum o la Chat!',
			'settings.exports.title' => 'Esportazioni',
			'settings.extensionSections.activities' => 'Attività',
			'settings.extensionSections.hunting' => 'Caccia',
			'settings.extensionSections.contests' => 'Contest',
			'settings.extensionSections.lookups' => 'Ricerche',
			'settings.extensionSections.dashboard' => 'Dashboard',
			'settings.map.title' => 'Mappe',
			'settings.map.style.title' => 'Stile della mappa',
			'settings.map.showCallsigns.title' => 'Mostra Nominativi',
			'settings.map.showCallsigns.description' => 'Ogni contatto è un\'etichetta con il suo nominativo, nel colore della sua banda',
			'settings.map.showGrayline.title' => 'Mostra Grayline',
			'settings.map.showGrayline.description' => 'Ombreggia il lato notturno della Terra, con il crepuscolo come gradiente',
			'settings.map.styleOpts.automatic' => 'Automatico',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacy',
			'settings.privacy.shareAppData.title' => 'Condividi i dati di utilizzo dell\'app',
			'settings.privacy.shareAppData.descriptionOn' => 'Ci aiuta a migliorare l\'app condividendo dati di utilizzo, configurazione, arresti anomali e prestazioni',
			'settings.privacy.shareAppData.descriptionOff' => 'Mantiene privati i dati sull\'utilizzo dell\'app.\nIl team Ham2K non sarà in grado di rilevare arresti anomali o altri problemi.',
			'settings.privacy.shareOpData.title' => 'Condividi i dati dell\'operazione',
			'settings.privacy.shareOpData.descriptionOn' => 'Condivide alcuni dati dell\'operazione pubblicamente e con altri utenti',
			'settings.privacy.shareOpData.descriptionOff' => 'Mantiene privati i dati dell\'operazione',
			'settings.privacy.privacyPolicy' => 'Informativa sulla Privacy',
			'settings.privacy.termsOfService' => 'Termini di Servizio',
			'settings.operatorCall' => 'Nominativo Operatore',
			'settings.sync.title' => 'Sincronizzazione Cloud',
			'settings.sync.moreSettings' => 'Altre impostazioni di sincronizzazione',
			'settings.sync.enable' => 'Abilita Sincronizzazione',
			'settings.sync.deviceKey' => 'Chiave del dispositivo',
			'settings.peers.title' => 'Dispositivi Peer',
			'settings.peers.enable' => 'Connetti ad altri dispositivi',
			'settings.peers.enableDescription' => 'Consenti la condivisione di operazioni, logging, CAT e GPS con altri dispositivi sulla rete locale',
			'settings.peers.bleEnable' => 'Connetti via Bluetooth',
			'settings.peers.bleDescription' => 'Usa il Bluetooth LE per connetterti anche senza rete locale',
			'settings.peers.thisDevice' => 'Questo Dispositivo',
			'settings.peers.deviceName' => 'Nome',
			'settings.peers.deviceNameHint' => 'Come questo dispositivo viene visto dagli altri dispositivi',
			'settings.peers.pairedDevices' => 'Dispositivi collegati',
			'settings.peers.noPairedDevices' => 'Ancora nessun dispositivo collegato. Attiva questa opzione su un altro dispositivo di questa rete per collegarli.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Impossibile leggere i dispositivi collegati: ${error}',
			'settings.peers.nearby' => 'Nelle vicinanze',
			'settings.peers.connected' => 'Connesso',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Connessione in corso…',
			'settings.peers.syncing' => 'Sincronizzazione in corso…',
			'settings.peers.waitingForThem' => 'In attesa dell\'altro dispositivo',
			'settings.peers.notConnected' => 'Non connesso',
			'settings.peers.wantsToPair' => 'vuole condividere questa operazione',
			'settings.peers.allow' => 'Consenti',
			'settings.peers.link' => 'Collega',
			'settings.peers.reject' => 'Rifiuta',
			'settings.peers.forget' => 'Dimentica',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Dimenticare ${name}?',
			'settings.peers.forgetBody' => 'Smetterà di sincronizzarsi con questo dispositivo. Potrai consentirlo di nuovo in seguito, e i contatti già registrati vengono mantenuti.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Collega con ${name}',
			'settings.peers.pairBody' => 'Questo dispositivo è sulla tua rete locale e vuole connettersi.',
			'settings.peers.pairBodyBle' => 'Questo dispositivo è nelle vicinanze e vuole connettersi via Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID dispositivo',
			'settings.peers.pairWarning' => 'Collega solo dispositivi che riconosci. Qualsiasi dispositivo su questa rete può inviare una richiesta.',
			'settings.peers.pairWarningBle' => 'Collega solo dispositivi che riconosci. Qualsiasi dispositivo nelle vicinanze può inviare una richiesta.',
			'settings.peers.problem' => ({required Object error}) => 'Impossibile raggiungere la rete locale: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Connesso a ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Connessione persa con ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispositivi Peer: ${connected} di ${linked} connessi',
			'settings.peers.screenEnable' => 'Condividi schermi e finestre',
			'settings.peers.screenDescription' => 'Consenti ad altri dispositivi di mostrare schermi o finestre di questo computer',
			'settings.peers.screenSources' => 'Schermi e Finestre',
			'settings.peers.screenRefresh' => 'Aggiorna l\'elenco',
			'settings.peers.screenUnsupportedPlatform' => 'Questo dispositivo non può condividere il suo schermo. macOS può farlo; ogni dispositivo può mostrare uno schermo condiviso da un altro.',
			'settings.peers.screenUnsupportedVersion' => 'Per condividere uno schermo serve macOS 12.3 o successivo. Questo dispositivo può comunque mostrare uno schermo condiviso da un altro.',
			'settings.peers.screenNeedsPermission' => 'macOS richiede il tuo permesso per registrare lo schermo prima che questa app possa condividerne uno.',
			'settings.peers.screenGrantPermission' => 'Richiedi il permesso',
			'settings.peers.screenRelaunchAfterGranting' => 'Consentilo in Impostazioni di Sistema in Privacy e sicurezza → Registrazione schermo, poi chiudi e riapri questa app — macOS comunica la modifica a un\'app solo al suo avvio successivo.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Condivisione schermo: ${error}',
			'settings.peers.screenChooseTitle' => 'Scegli cosa condividere',
			'settings.peers.screenChooseButton' => 'Scegli cosa condividere…',
			'settings.peers.screenTabScreens' => 'Schermi',
			'settings.peers.screenTabApps' => 'App',
			'settings.peers.screenTabWindows' => 'Finestre',
			'settings.peers.screenTabEmpty' => 'Non è stato trovato nulla di questo tipo.',
			'settings.peers.screenSharedSummaryNone' => 'Ancora niente scelto.',
			'settings.peers.screenThisDevice' => 'Questo dispositivo',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Mostrato su ${devices}',
			'settings.peers.screenSharedToNobody' => 'Non mostrato',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Smetti di condividere ${name}',
			'settings.developerMode' => 'Modalità Sviluppatore',
			'settings.syncPanel.configuration' => 'Configurazione Sincronizzazione',
			'settings.syncPanel.enableTitle' => 'Sincronizza con Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Backup e sincronizzazione del tuo log tra i dispositivi',
			'settings.syncPanel.disabledDescription' => 'Disattivata — resta solo su questo dispositivo',
			'settings.syncPanel.syncing' => 'Sincronizzazione in corso',
			'settings.syncPanel.account' => 'Account',
			'settings.syncPanel.refresh' => 'Aggiorna',
			'settings.syncPanel.switchAccounts' => 'Cambia Account',
			'settings.syncPanel.switchAccountsDescription' => 'Collega questo dispositivo a un altro account con un codice QR o via email',
			'settings.syncPanel.connectionRequests' => 'Richieste di collegamento',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Un dispositivo è in attesa di unirsi a questo account', other: '${n} dispositivi sono in attesa di unirsi a questo account', ), 
			'settings.syncPanel.accountEmailTitle' => 'Email dell\'account',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Conferma inviata a ${email}. Apri il link ricevuto per completare la modifica.',
			'settings.syncPanel.resendConfirmation' => 'Invia di nuovo l\'email di conferma',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'In attesa di ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Inviata di nuovo a ${email}.',
			'settings.syncPanel.deviceLinked' => 'Quel dispositivo è ora collegato a questo account.',
			'settings.syncPanel.checking' => 'Verifica in corso…',
			'settings.syncPanel.notLinked' => 'Non ancora collegato',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Sostituire i dati locali?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${n} operazione', other: '${n} operazioni', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.syncPanel.counts' => 'Dati sincronizzati',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Questo dispositivo: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'In attesa di caricamento: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Questo dispositivo: verifica in corso…',
			'settings.syncPanel.countsServerChecking' => 'Server: verifica in corso…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: non disponibile',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Questo esegue il backup e rimuove ${operations} e ${qsos} da questo dispositivo, poi scarica al loro posto i dati dell\'account. Il backup resta nel database di questo dispositivo.',
			'settings.syncPanel.replace' => 'Sostituisci',
			'settings.syncPanel.pendingBannerTitle' => 'Rilevato un nuovo account Ham2K Log Filer',
			'settings.syncPanel.pendingBannerBody' => 'Mantieni le operazioni e i QSO esistenti su questo dispositivo e uniscili all\'account, oppure sostituiscili con i dati dell\'account (in entrambi i casi un backup resta su questo dispositivo).',
			'settings.syncPanel.combine' => 'Combina',
			'settings.syncPanel.authIssueTitle' => 'La sincronizzazione non riesce a connettersi',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer continua a rifiutare questo dispositivo. Controlla il tuo nominativo nelle impostazioni di Sincronizzazione.',
			'settings.syncPanel.openSettings' => 'Apri le impostazioni di Sincronizzazione',
			'settings.accounts.title' => 'Account, Servizi e Fonti di Dati',
			'settings.accounts.none' => 'Nessuna estensione attiva con account',
			'settings.accounts.notConfigured' => 'Non configurato',
			'settings.accounts.connected' => 'Connesso',
			'settings.accounts.cancelLogin' => 'Annulla accesso',
			'settings.accounts.openInBrowser' => 'Apri nel Browser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Accesso effettuato come ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Premi Salva per mantenere connesso questo account.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Connesso a ${label}',
			'settings.accounts.connect' => 'Connetti',
			'settings.accounts.disconnect' => 'Disconnetti',
			'settings.accounts.connectedAs' => 'Connesso come',
			'settings.accounts.test' => 'Prova',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Salvataggio non riuscito: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Accesso non riuscito: ${error}',
			'settings.accounts.lookupFailed' => 'Gli account non sono disponibili al momento — riprova tra un momento',
			'settings.accounts.browserLoginTitle' => 'Completa l\'accesso con il tuo browser web',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Al termine, il browser proverà ad aprire un link che inizia con "${prefix}". Probabilmente sul tuo computer non c\'è nulla registrato per aprirlo, quindi copia quel link (dalla barra degli indirizzi, o dalla pagina di errore mostrata dal browser) e incollalo qui.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger non è riuscito ad aprire il browser. Copia il link di accesso qui sotto e aprilo tu, poi copia il link a cui ti rimanda (inizia con "${prefix}") e incollalo qui.',
			'settings.accounts.copyLoginLink' => 'Copia link di accesso',
			'settings.accounts.pastedLinkLabel' => 'Incolla qui il link',
			'settings.accounts.finishLogin' => 'Completa l\'accesso',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Non è il link di accesso — dovrebbe iniziare con "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Quel link appartiene a un altro tentativo di accesso. Chiudi questa pagina e connettiti di nuovo.',
			'settings.accounts.pastedLinkNoCode' => 'Quel link non contiene un codice di accesso. Completa prima l\'accesso, poi copia il link a cui ti rimanda.',
			'settings.accounts.pastedLinkMalformed' => 'Quel link sembra troncato. Copialo per intero e incollalo di nuovo.',
			'settings.accounts.relayLoginWaiting' => 'In attesa che tu completi l\'accesso — proseguirà automaticamente quando avrai finito.',
			'settings.accounts.loginNoResponse' => 'Questo dispositivo non ha ancora ricevuto risposta dall\'accesso. Se hai già completato nel browser, annulla e prova a connetterti di nuovo.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger non è riuscito ad aprire il browser automaticamente. Usa il pulsante qui sotto per aprire tu la pagina di accesso.',
			'settings.accounts.relayLoginUnavailable' => 'Impossibile raggiungere il server di sincronizzazione necessario per completare l\'accesso. Controlla la connessione e riprova.',
			'settings.accounts.loginIncompleteResponse' => 'Quel tentativo di accesso non è stato completato correttamente. Prova a connetterti di nuovo.',
			'settings.accounts.noKeyringTitle' => 'Impossibile salvare gli accessi agli account',
			'settings.accounts.noKeyringText' => 'Ham2K Logger non riesce a raggiungere un servizio portachiavi su questo computer, quindi gli accessi agli account non possono essere salvati né letti — collegare un account fallirà finché il problema non sarà risolto. Installa e avvia **gnome-keyring**, **KWallet** o **KeePassXC**, oppure sblocca il portachiavi che hai già, poi riavvia. Logging, esportazioni e file di dati non sono interessati; la sincronizzazione del log resta disattivata nel frattempo.',
			'settings.accounts.noKeyringInline' => 'Impossibile salvare gli accessi: il portachiavi di questo computer non è raggiungibile. Installa e avvia gnome-keyring, KWallet o KeePassXC, oppure sblocca quello che hai.',
			'settings.accounts.noSecureStorageInline' => 'Impossibile salvare gli accessi: l\'archivio sicuro di questo computer non è raggiungibile.',
			'settings.station.title' => 'Configurazione Stazione e Controllo CAT',
			'settings.station.none' => 'Nessun apparato configurato',
			'settings.station.add' => 'Aggiungi',
			'settings.station.addTitle' => 'Aggiungi apparato',
			'settings.station.searchHint' => 'Cerca apparati',
			'settings.station.noMatches' => 'Nessun apparato corrispondente',
			'settings.station.detectedEquipment' => 'Apparati rilevati',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Impossibile rilevare le radio: ${error}',
			'settings.station.edit' => 'Modifica apparato',
			'settings.station.name' => 'Nome',
			'settings.station.nameDescription' => 'Come la chiami tu — "Radio sinistra". Opzionale.',
			'settings.station.transport' => 'Connessione',
			'settings.station.host' => 'Indirizzo',
			'settings.station.hostDescription' => 'L\'hostname o l\'indirizzo IP della radio sulla tua rete.',
			'settings.station.port' => 'Porta',
			'settings.station.hostRequired' => 'L\'indirizzo è obbligatorio',
			'settings.station.portInvalid' => 'La porta deve essere tra 1 e 65535',
			'settings.station.connect' => 'Connetti',
			'settings.station.disconnect' => 'Disconnetti',
			'settings.station.remove' => 'Rimuovi',
			'settings.station.removeTitle' => ({required Object name}) => 'Rimuovere ${name}?',
			'settings.station.removeMessage' => 'Lo rimuove solo dall\'app. Le impostazioni dell\'apparato restano invariate.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipo di apparato non riconosciuto "${typeKey}"',
			'settings.station.report' => 'Segnala',
			'settings.station.reportTitle' => 'Segnala questa radio',
			'settings.station.reportIntro' => 'Dicci quale radio è davvero e com\'è andata. La tua segnalazione diventa una scheda letta dal team Ham2K, e ciò che scrivi su come l\'hai fatta funzionare potrebbe aiutare il prossimo operatore con lo stesso apparato.',
			'settings.station.reportManufacturer' => 'Produttore',
			'settings.station.reportManufacturerDescription' => 'Chi la produce — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Il produttore è obbligatorio',
			'settings.station.reportModel' => 'Modello',
			'settings.station.reportModelDescription' => 'Il modello, come lo chiama la radio stessa — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'Il modello è obbligatorio',
			'settings.station.reportOutcome' => 'Com\'è andata?',
			'settings.station.reportOutcomeWorks' => 'Ha funzionato bene',
			'settings.station.reportOutcomeIssues' => 'Ha funzionato, con problemi',
			'settings.station.reportOutcomeFails' => 'Non ha funzionato per niente',
			'settings.station.reportOutcomeRequired' => 'Dicci com\'è andata',
			'settings.station.reportComments' => 'Commenti',
			'settings.station.reportCommentsPlaceholder' => 'Cosa ha funzionato, cosa no, qualsiasi cosa ti abbia sorpreso.',
			'settings.station.reportHints' => 'Suggerimenti per la risoluzione dei problemi',
			'settings.station.reportHintsPlaceholder' => 'Vuoi suggerire qualche consiglio per la risoluzione dei problemi ad altri utenti?',
			'settings.station.reportSend' => 'Invia segnalazione',
			'settings.station.reportSending' => 'Invio della segnalazione…',
			'settings.station.reportSent' => ({required Object ref}) => 'Grazie — la tua segnalazione è stata registrata come ${ref}.',
			'settings.station.reportSentNoRef' => 'Grazie — la tua segnalazione è stata inviata.',
			'settings.station.reportFailed' => ({required Object error}) => 'La segnalazione non è stata inviata: ${error}',
			'settings.station.troubleshootingNotes' => 'Note per la risoluzione dei problemi',
			'settings.station.mainVfo' => 'VFO principale',
			'settings.station.useAsMainVfo' => 'Usa come VFO principale',
			'settings.station.serialPort' => 'Porta seriale',
			'settings.station.serialPortDescription' => 'La porta su cui appare l\'interfaccia CAT della radio.',
			'settings.station.serialPortNone' => 'Nessuna porta seriale trovata',
			'settings.station.serialPortRequired' => 'Scegli una porta seriale',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'porta ${n} di ${total}',
			'settings.station.serialPortSuggested' => 'suggerita',
			'settings.station.serialPortJustNow' => 'Connessa di recente',
			'settings.station.serialPortNoDriver' => 'nessun driver',
			'settings.station.serialDeviceRequest' => 'Aggiungi un dispositivo USB…',
			'settings.station.bleDevice' => 'Dispositivo Bluetooth LE',
			'settings.station.bleDeviceDescription' => 'Il bridge seriale attraverso cui è collegata la radio, come un LiNK500MP in Mode 4 o un adattatore seriale BLE.',
			'settings.station.bleScan' => 'Cerca dispositivi Bluetooth LE…',
			'settings.station.bleScanNoneFound' => 'Nessun dispositivo Bluetooth LE trovato. Controlla che il bridge sia acceso, nelle vicinanze e nella sua modalità Bluetooth LE (Mode 4 su un LiNK500MP).',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'Impossibile eseguire la scansione Bluetooth LE: ${reason}',
			'settings.station.bleOff' => 'Il Bluetooth è spento.',
			'settings.station.bleDenied' => 'Il permesso Bluetooth non è stato concesso. Consentilo nelle impostazioni di sistema, poi riprova.',
			'settings.station.bleUnsupported' => 'Questo dispositivo non ha il Bluetooth LE.',
			'settings.station.bleStarting' => 'Il Bluetooth si sta ancora avviando. Riprova tra un momento.',
			'settings.station.bleConnectFailed' => 'Impossibile raggiungere il dispositivo Bluetooth LE. Controlla che sia acceso, nelle vicinanze e non connesso a un\'altra app.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'Questo dispositivo Bluetooth LE non ha un servizio seriale che l\'app riconosca. Segnalalo indicando i suoi servizi: ${services}',
			'settings.station.baudRate' => 'Velocità (baud)',
			'settings.station.baudRateDescription' => 'Deve corrispondere al menu CAT della radio. Se non corrisponde, la radio restituisce dati senza senso e nessun errore.',
			'settings.station.serialRtsHigh' => 'Mantieni RTS alto',
			'settings.station.serialRtsHighDescription' => 'Solo per una radio che attende RTS prima di rispondere, come una Yaesu con CAT RTS attivo. Su Digirig, SignaLink e la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione.',
			'settings.station.serialDtrHigh' => 'Mantieni DTR alto',
			'settings.station.serialDtrHighDescription' => 'Solo per un\'interfaccia CAT alimentata dal DTR, come alcuni cavi RS-232 per l\'FT-817. Su molti cavi DTR manipola il CW o il PTT, e mantenerlo alto manda in trasmissione.',
			'settings.station.serialUsbDriver' => 'Driver del chip USB',
			'settings.station.serialUsbDriverDescription' => 'Automatico riconosce la maggior parte degli adattatori. Scegli il chip solo per un adattatore che l\'elenco delle porte indica senza driver — il nome è sulla confezione o in un elenco dei dispositivi USB.',
			'settings.station.serialUsbDriverAuto' => 'Automatico',
			'settings.station.civAddress' => 'Indirizzo CI-V della radio',
			'settings.station.civAddressDescription' => 'Esadecimale, come mostrato nel menu CI-V della radio. L\'IC-705 esce di fabbrica con A4.',
			'settings.station.civAddressInvalid' => 'Un indirizzo CI-V è di due cifre esadecimali, da 01 a FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Quale slice della radio questa connessione legge e sintonizza.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Scegli una delle slice della radio, da A a H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'La slice ${letter} non è in uso su questa radio — scegli un\'altra slice, o creala in SmartSDR',
			'settings.station.channelNotInUse' => 'non in uso',
			'settings.station.channelHeldByUnknown' => 'in uso da un altro programma',
			'settings.station.flexNoSlices' => 'Questa radio non ha segnalato alcuna slice — controlla che SmartSDR sia in esecuzione e che questo client possa abbonarsi',
			'settings.station.spectrumUnsupported' => 'Questa radio non invia lo spettro via CAT',
			'settings.station.spectrumRequiresBaud' => 'Richiede il CAT a 115200 bps',
			'settings.station.spectrumNoRadio' => 'Nessuna radio connessa',
			'settings.station.spectrumWaiting' => 'In attesa dello spettro della radio…',
			'settings.station.spectrumUnavailable' => 'La visualizzazione dello spettro non è disponibile',
			'settings.station.spectrumNoDaxChannel' => 'Tutti i canali DAX IQ di questa radio sono in uso',
			'settings.station.spectrumNoPanadapter' => 'Questa slice non ha un panadapter sulla radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'La radio ha rifiutato uno stream DAX IQ (errore ${code})',
			'settings.station.spectrumNoUdp' => 'I dati dello spettro della radio non raggiungono questo dispositivo',
			'settings.station.spectrumK4Unavailable' => 'Impossibile ricevere lo spettro LAN del K4. Nuovo tentativo…',
			'settings.station.spectrumK4RemoteUnavailable' => 'Impossibile ricevere lo spettro remoto del K4',
			'settings.station.spectrumScopeRefused' => 'La radio ha rifiutato i comandi dello scope',
			'settings.station.spectrumOutOfRange' => 'Lo scope della radio è impostato fuori dall\'intervallo che può mostrare',
			'settings.station.spectrumBandUnsupported' => 'Lo scope della radio non può essere mostrato su questa banda',
			'settings.station.spectrumSdrNoRadio' => 'In attesa della frequenza della radio collegata…',
			'settings.station.spectrumSdrNotConnected' => 'L\'SDR non è connesso',
			'settings.station.spectrumSdrNoIf' => 'Imposta la frequenza IF della radio nelle impostazioni di questo SDR',
			'settings.station.sdrRadio' => 'Mostra lo spettro di',
			'settings.station.sdrRadioDescription' => 'Una visualizzazione dello spettro su questa radio usa questo ricevitore invece dello scope della radio stessa.',
			'settings.station.sdrRadioMain' => 'La radio principale',
			'settings.station.sdrTuning' => 'Ingresso antenna',
			'settings.station.sdrTuningDescription' => 'Da dove arriva il segnale del ricevitore. Con la propria antenna si sintonizza da solo per seguire la radio; sull\'uscita IF della radio resta sulla IF.',
			'settings.station.sdrTuningIndependent' => 'La propria antenna',
			'settings.station.sdrTuningIfTap' => 'L\'uscita IF della radio',
			'settings.station.sdrIfHz' => 'Frequenza IF (Hz)',
			'settings.station.sdrIfHzDescription' => 'Solo per un\'uscita IF: la frequenza a cui la sintonia della radio si trova sulla sua IF, ad esempio 68330000 su un FT-817.',
			'settings.station.sdrIfInverted' => 'IF invertita',
			'settings.station.sdrGainDb' => 'Guadagno (dB)',
			'settings.station.sdrGainDbDescription' => 'Lascia vuoto per il guadagno automatico del ricevitore.',
			'settings.station.sdrOffsetHz' => 'Offset di frequenza (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'Aggiunto a ogni frequenza inviata al ricevitore, per un upconverter: 125000000 per un Ham It Up.',
			'settings.station.sdrPpm' => 'Correzione di frequenza (ppm)',
			'settings.station.rtlDirectSampling' => 'Campionamento diretto',
			'settings.station.rtlDirectSamplingDescription' => 'Per le HF su un RTL-SDR V3 senza upconverter. Un RTL-SDR V4 arriva alle HF senza.',
			'settings.station.rtlDirectSamplingOff' => 'Off',
			'settings.station.rtlDirectSamplingI' => 'Ramo I',
			'settings.station.rtlDirectSamplingQ' => 'Ramo Q',
			'settings.station.rtlTcpNotAServer' => 'Questo non è un server rtl_tcp',
			'settings.station.rtlTcpNotes' => 'Questo si connette a un **server rtl_tcp che avvii tu stesso** sul computer a cui è collegato il dongle.\n\n- **Avvialo** con `rtl_tcp -a 0.0.0.0` così che le altre macchine possano raggiungerlo; sulla stessa macchina basta `rtl_tcp` da solo.\n- **La porta** è 1234 a meno che non l\'abbia avviato con `-p`.\n- **Un programma alla volta:** rtl_tcp serve un solo client. L\'app si connette solo mentre è visibile una visualizzazione dello spettro, e la rilascia qualche secondo dopo la chiusura.\n- **Su Android**, l\'app *SDR driver* esegue lo stesso server sul telefono.',
			'settings.station.rspTcpNotes' => 'Questo si connette a un **server rsp_tcp che avvii tu stesso** sul computer a cui è collegato l\'RSP, con l\'API di SDRplay installata lì.\n\n- **Avvialo** con `rsp_tcp -a 0.0.0.0`.\n- **La porta** è 1234 a meno che non l\'abbia avviato con `-p`.\n- **Un programma alla volta:** il server accetta un solo client. L\'app si connette solo mentre è visibile una visualizzazione dello spettro.',
			'settings.station.n3fjpNoRig' => 'N3FJP non ha un\'interfaccia radio configurata, quindi questo segue ciò che viene digitato in N3FJP, non una radio',
			'settings.station.winkeyerKeyPort' => 'Uscita di manipolazione',
			'settings.station.winkeyerKeyPortDescription' => 'In quale delle due uscite del keyer è collegata la tua radio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Porta ${n}',
			'settings.station.winkeyerPtt' => 'Usa il PTT del keyer',
			'settings.station.winkeyerPttDescription' => 'Attiva la linea PTT sullo stesso jack, per un amplificatore o una radio che lo richiede. Lascia disattivato per una radio manipolata dal suo jack del tasto.',
			'settings.station.winkeyerNoAnswer' => 'Nessun WinKeyer ha risposto su questa porta',
			'settings.station.winkeyerStoppedAnswering' => 'Il WinKeyer ha smesso di rispondere durante la trasmissione; il messaggio è stato scartato',
			'settings.station.icomControlPort' => 'Porta di controllo (UDP)',
			'settings.station.icomControlPortDescription' => 'La Control Port (UDP) della radio — 50001 a meno che non sia stata cambiata nelle sue impostazioni di rete, o reindirizzata su un\'altra.',
			'settings.station.icomSerialPort' => 'Porta seriale (UDP)',
			'settings.station.icomSerialPortDescription' => 'La Serial Port (UDP) della radio — 50002 a meno che non sia stata cambiata nelle sue impostazioni di rete, o reindirizzata su un\'altra.',
			'settings.station.icomPortsDiffer' => 'Le porte di controllo e seriale devono essere diverse',
			'settings.station.radioUser' => 'Nome utente della radio',
			'settings.station.radioPass' => 'Password della radio',
			'settings.station.radioLoginDescription' => 'L\'accesso Network → Remote della radio, non la password del WiFi.',
			'settings.station.radioUserRequired' => 'Il nome utente per il controllo remoto della radio è obbligatorio',
			'settings.station.connectFailedBusy' => 'Il dispositivo è in uso',
			'settings.station.connectFailedDenied' => 'Accesso negato',
			'settings.station.connectFailedDevice' => 'Dispositivo non trovato',
			'settings.station.connectFailedUnsupported' => 'Nessun driver riconosce il chip di questo adattatore USB. Se sai quale chip è, sceglilo in Driver del chip USB nelle Impostazioni avanzate.',
			'settings.station.connectFailedLines' => 'Impossibile mantenere RTS/DTR come impostati, quindi la porta è stata chiusa. Un altro programma potrebbe aver lasciato attivo l\'handshake hardware — scollega e ricollega il cavo.',
			'settings.station.connectFailedNetwork' => 'Impossibile trovare la radio sulla rete. Controlla il suo indirizzo e che sia accesa e raggiungibile.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'La porta ${port} su questo dispositivo è già in uso, e le risposte arrivano lì. Chiudi qualsiasi altra cosa in ascolto su quella porta — compreso un altro nodo PstRotator — oppure cambia porta.',
			'settings.station.connectFailedTimeout' => 'La radio non ha risposto in tempo. Controlla che sia accesa e raggiungibile.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Generica',
			'settings.station.models.icomGeneric' => 'Icom - Generica',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Generica',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Generica',
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
			'settings.station.models.rigctld' => 'Radio controllata via rigctld',
			'settings.station.models.rigctldNodeName' => 'La mia radio (via rigctld)',
			'settings.station.models.flrig' => 'Radio controllata via flrig',
			'settings.station.models.flrigNodeName' => 'La mia radio (via flrig)',
			'settings.station.models.hrd' => 'Radio controllata via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'La mia radio (via HRD)',
			'settings.station.models.n3fjp' => 'Radio controllata via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'La mia radio (via N3FJP)',
			'settings.station.models.commander' => 'Radio controllata via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'La mia radio (via Commander)',
			'settings.station.models.antenna' => 'Antenna',
			'settings.station.models.key' => 'Tasto CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Radio generica (segnaposto)',
			'settings.station.models.placeholderRadioNodeName' => 'La mia radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Commutatore coassiale Sierra Radio CX-1',
			'settings.station.models.gs232a' => 'Interfaccia rotore Yaesu GS-232A',
			'settings.station.models.pstRotator' => 'PstRotator (controllo UDP)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Rete/WiFi',
			'settings.station.transports.secureNetwork' => 'Rete/WiFi sicura',
			'settings.station.transports.usbSerial' => 'Seriale USB',
			'settings.station.transports.wifi' => 'Rete/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Seriale Bluetooth',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Segnaposto',
			'settings.station.troubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.ft891Troubleshooting' => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **CAT RTS disattivato sulla radio, oppure Mantieni RTS alto attivo.** Con **CAT RTS** attivo (menu FT-891 **05-08**), la radio resta muta finché RTS è basso — può rispondere una volta all\'apertura della porta, poi più nulla. Scegliendo la porta USB della radio stessa si attiva **Mantieni RTS alto** nelle Impostazioni avanzate. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione il tuo trasmettitore: in quel caso disattiva invece CAT RTS sulla radio.\n- **La velocità deve corrispondere** al CAT RATE della radio (menu **05-06**). Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.yaesuBinaryTroubleshooting' => 'Questa radio usa il vecchio CAT Yaesu a cinque byte, e non risponde affatto quando qualcosa non va. Quasi sempre è uno di questi casi:\n\n- **Il cavo deve convertire i livelli.** Il jack CAT sul retro non è RS-232 né USB; serve un CT-62 o un adattatore equivalente. Un semplice cavo audio o dati non funziona per il CAT.\n- **La velocità deve corrispondere** al menu CAT RATE della radio (**#14** su un FT-817, **#19** su un FT-857 o FT-897). Se non corrisponde, la radio non restituisce nulla, e mai un errore.\n- **Non lasciare mai che qualcosa alzi RTS o DTR su questa porta.** Sulla maggior parte dei cavi per queste radio quelle linee sono PTT e manipolazione. L\'eccezione è una vecchia interfaccia alimentata dal DTR: per quella attiva **Mantieni DTR alto** nelle Impostazioni avanzate.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesto driver è stato scritto a partire dalla tabella CAT pubblicata da Yaesu e non è stato provato su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.tenTecTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.tenTecEagleTroubleshooting' => '- **La porta USB-B sul retro è il collegamento CAT.** La radio appare come porta seriale USB; su Windows serve il driver USB to UART di Ten-Tec, che in Gestione dispositivi appare come "USB to UART (COMx)".\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta, e così anche il programma di aggiornamento firmware di Ten-Tec.\n- **Impostare la larghezza del filtro dall\'app la toglie alla manopola BW** finché la radio non viene spenta e riaccesa. La radio funziona così.\n\nQuesto driver è stato scritto a partire dalla guida di riferimento per programmatori di Ten-Tec. Se funziona solo in parte, vale la pena segnalarlo, indicando la versione del firmware dal menu della radio.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Usa un cavo seriale DB-9 diritto** verso la porta SERIAL DATA, non un null-modem.\n- **Questa voce mantiene RTS alto**, perché l\'Orion usa RTS e CTS come handshake. Su un\'interfaccia che attiva il PTT da RTS, come un Digirig, disattiva Mantieni RTS alto nelle Impostazioni avanzate, altrimenti la radio trasmette appena l\'app si connette.\n- **Il CW dall\'app richiede il keyer interno della radio attivo.** Se è disattivato, la radio ignora ciò che l\'app invia.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesto driver è stato scritto a partire dalla guida di riferimento per programmatori di Ten-Tec e non è stato provato su un Orion. Se funziona solo in parte, vale la pena segnalarlo, indicando la versione del firmware dal menu della radio.',
			'settings.station.tenTecNoCw' => 'Il firmware di questa radio non accetta il CW dall\'app. Ten-Tec lo ha aggiunto nel firmware Orion 1.366.',
			'settings.station.tenTecKeyerOff' => 'Il keyer interno della radio è disattivato, quindi ignora il CW inviato dall\'app. Attiva il keyer nel menu della radio.',
			'settings.station.guohetecTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.guohetecTroubleshooting' => 'La Q900 ha due protocolli CAT, e questa voce usa quello nativo invece dell\'imitazione dell\'FT-817. Scegli qui **Guohetec Q900**, non un FT-817 — l\'imitazione supporta meno comandi, e la radio non dice quale sta usando.\n\n- **Il cavo USB-C è il collegamento CAT**, e collega anche la scheda audio. La velocità non conta su di esso; la porta ignora qualunque valore impostato.\n- **Non lasciare mai che qualcosa alzi RTS o DTR su questa porta.** Su un cavo seriale quelle linee sono PTT e manipolazione.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **Una radio di seconda generazione si comporta diversamente** da una di prima. Premi a lungo Menu, poi About: HW 2.0 è la seconda generazione.\n\nQuesto driver è stato scritto a partire dal protocollo pubblicato dal produttore e non è stato provato su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.yaesuTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.yaesuTroubleshooting' => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **CAT RTS deve essere OFF sulla radio.** Se è attivo, la radio attende una linea di handshake che l\'app mantiene bassa. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti quella stessa linea è il PTT, quindi alzarla manderebbe in trasmissione il trasmettitore. Sulla porta USB della radio stessa, l\'alternativa è **Mantieni RTS alto** nelle Impostazioni avanzate. La posizione di questa impostazione varia a seconda del modello (menu **05-08** su un FT-891).\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **I modi seguono la tabella dell\'FT-891.** La maggior parte della gamma Yaesu vi corrisponde, ma una radio che numera i modi in modo diverso mostrerà e imposterà quello sbagliato per quei modi. La frequenza non ne risente.',
			'settings.station.ftdx3000Troubleshooting' => '**Il menu 037 CAT SELECT deve essere su USB** per il CAT tramite la porta USB della radio; impostato su RS232C, il CAT è sul jack sul retro.\n\nQuesta voce è stata scritta a partire dalla documentazione CAT pubblicata e non è stata provata su un FTDX3000. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.yaesuRs232Troubleshooting' => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **Il jack CAT è RS-232.** Serve un adattatore USB-seriale e un cavo DB-9 diritto — un cavo null-modem inverte le linee, e la radio non sente nulla.\n- **CAT RTS deve essere OFF sulla radio.** Se è attivo, la radio attende una linea di handshake che l\'app mantiene bassa, a meno che **Mantieni RTS alto** non sia attivo nelle Impostazioni avanzate.\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\nQuesta voce è stata scritta a partire dalla documentazione CAT pubblicata e non è stata provata su nessuna di queste radio. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.yaesuUsbTroubleshooting' => 'La radio riceve i comandi ma non risponde. Quasi sempre è uno di questi casi:\n\n- **Usa la prima delle due porte USB della radio.** Il CAT è normalmente sulla prima (la porta COM **Enhanced** su Windows); la seconda (**Standard**) è per PTT e manipolazione. Il selettore indica la prima ogni volta che riesce a distinguerle.\n- **CAT RTS disattivato sulla radio, oppure Mantieni RTS alto attivo.** Con il menu **CAT RTS** della radio attivo, questa resta muta finché RTS è basso — può rispondere una volta all\'apertura della porta, poi più nulla. Scegliendo la porta USB della radio stessa si attiva **Mantieni RTS alto** nelle Impostazioni avanzate. Su Digirig, SignaLink o la maggior parte dei cavi autocostruiti RTS è il PTT, e mantenerlo alto manda in trasmissione il tuo trasmettitore: in quel caso disattiva invece CAT RTS sulla radio.\n- **La velocità deve corrispondere** al menu CAT RATE della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.',
			'settings.station.k4SerialNotes' => 'Collega la presa USB-B (PC) posteriore del K4. Per il CAT funziona sia USB-PC1 sia USB-PC2; scegli una porta libera e fai corrispondere l\'impostazione Serial USB-PCn: Baud Rate sulla radio. HaLo precompila 38400; cambialo se necessario. Un\'altra applicazione deve usare l\'altra porta o l\'Ethernet.\n\nQuesta connessione controlla la radio e i suoi keyer; non invia audio a HaLo.',
			'settings.station.k4TcpNotes' => 'Collega la presa Ethernet del K4 alla tua rete locale. Inserisci il suo hostname o indirizzo IP e la porta CAT 9200. HaLo usa lo stesso host sulla porta fissa 9201 quando è visibile un panadapter o un waterfall; cambiare la porta CAT non cambia la porta dello spettro.\n\nLo spettro mostra il ricevitore principale. I suoi controlli di zoom, regolazione del riferimento e velocità influiscono solo sulla visualizzazione di HaLo. Lo streaming audio non è supportato.',
			'settings.station.k4PowerTimeout' => 'La potenza del K4 non è stata cambiata perché la radio non ha confermato il suo intervallo di uscita. Riprova.',
			'settings.station.k4RemoteNotes' => 'Abilita l\'accesso remoto sul tuo K4 e inserisci la sua password di rete. Main e Sub condividono un\'unica connessione cifrata per il controllo della radio e lo spettro. La porta predefinita è 9204; inserisci la porta reindirizzata quando ti connetti da remoto.\n\nLa riproduzione audio e lo streaming del microfono non sono supportati.',
			'settings.station.k4Receiver' => 'Ricevitore',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Scegli Main o Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'Quel ricevitore è già configurato per questo K4',
			'settings.station.k4SubReceiverOff' => 'Il ricevitore Sub del K4 è spento',
			'settings.station.k4RemotePasswordRequired' => 'Inserisci la password di rete del K4 per connetterti in modo sicuro.',
			'settings.station.k4RemoteHandshakeFailed' => 'Il K4 non è riuscito a stabilire una connessione sicura. Controlla la sua password di rete e le impostazioni di accesso remoto.',
			'settings.station.k4RemoteUnreachable' => 'Impossibile raggiungere la connessione sicura del K4. Controlla indirizzo, porta e impostazioni di accesso remoto.',
			'settings.station.k4PowerRange' => 'La potenza del K4 deve essere tra 0,1 e 110 W, o tra 0,0001 e 0,01 W quando è attiva l\'uscita in milliwatt del transverter.',
			'settings.station.elecraftTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.elecraftTroubleshooting' => 'Le radio Elecraft usano il CAT Kenwood, e sia un KX2 sia un KX3 sono stati provati così — VFO in entrambe le direzioni, cambio di modo e zero-beat CW tutti funzionanti.\n\nSe la radio non risponde, quasi sempre è uno di questi casi:\n\n- **La velocità deve corrispondere** a quella impostata in **RS232** nel menu della radio. Escono di fabbrica con 38400. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n\n**Se la frequenza è giusta ma il modo è sbagliato**, faccelo sapere. Le voci KX2 e KX3 leggono il modo da una posizione nella risposta di stato della radio che abbiamo fissato in base alle radio viste finora, e un firmware che lo mette altrove ci arriva solo tramite una segnalazione.\n\nNessuno ha ancora segnalato il K3, quindi se ne usi uno facci sapere cosa succede. Il K4 ha una voce propria.',
			'settings.station.lab599TroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.lab599Troubleshooting' => 'La serie TX-500 usa il CAT Kenwood. Frequenza e modo sono stati provati tramite un LiNK500MP; potenza e strumenti sono scritti a partire dal riferimento CAT di Lab599, quindi segnala cosa succede in ogni caso.\n\n- **La velocità deve corrispondere** all\'impostazione CAT della radio, 9600 se non l\'hai cambiata. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Scegli il protocollo CAT sulla radio.** TS-2000 copre frequenza, modo e potenza. LAB599 permette all\'app anche di mettere la radio in DIG, di vederla trasmettere in DIG e di leggere la tensione di alimentazione.\n- **Tramite un LiNK500MP**, tieni premuta la manopola del VFO per circa tre secondi per passare il controllo CAT all\'interfaccia.\n- **Imposta la modalità del LiNK500MP per la connessione**: Mode 3 per il Bluetooth, Mode 4 per il Bluetooth LE. In qualsiasi altra modalità una scansione Bluetooth LE non lo trova.\n- **Via Bluetooth**, il LiNK500MP si accoppia come due porte seriali e solo una porta il CAT. Se la radio resta muta, scegli l\'altra.',
			'settings.station.lab599TroubleshootingIos' => 'La serie TX-500 usa il CAT Kenwood. Frequenza e modo sono stati provati tramite un LiNK500MP; potenza e strumenti sono scritti a partire dal riferimento CAT di Lab599, quindi segnala cosa succede in ogni caso.\n\n- **Imposta il LiNK500MP su Mode 4**, la sua modalità Bluetooth LE, prima di cercarlo. In qualsiasi altra modalità un iPhone o iPad non riesce a trovarlo.\n- **Passa il controllo CAT al LiNK500MP**: tieni premuta la manopola del VFO della radio per circa tre secondi.\n- **Scegli il protocollo CAT sulla radio.** TS-2000 copre frequenza, modo e potenza. LAB599 permette all\'app anche di mettere la radio in DIG, di vederla trasmettere in DIG e di leggere la tensione di alimentazione.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Se la radio si connette ma non mostra la frequenza',
			'settings.station.kenwoodTroubleshooting' => 'Questo driver è stato provato con i Kenwood TS-590SG e TS-480, i QRP Labs QMX e QCX-mini e gli Elecraft KX2 e KX3. Il resto della gamma è scritto a partire dai riferimenti CAT pubblicati, quindi segnala cosa succede in ogni caso.\n\nSe la radio non risponde, quasi sempre è uno di questi casi:\n\n- **La velocità deve corrispondere** al menu CAT della radio. Se non corrisponde, la radio restituisce dati senza senso o niente, e mai un errore.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.\n- **Alcune radio richiedono di abilitare il CAT** nel menu prima di rispondere.\n- **Le radio Kenwood attendono RTS**: la loro porta CAT lo usa come handshake, quindi Mantieni RTS alto (nelle Impostazioni avanzate) deve essere attivo. Una connessione configurata prima che fosse attivo per impostazione predefinita potrebbe averlo disattivato. Su un Digirig o un altro cavo che attiva il PTT da RTS, disattivalo, altrimenti la radio trasmette.\n\n**Diversi front-end SDR usano questo stesso protocollo**, quindi vale la pena provare questa voce anche per quelli; le radio Elecraft sono elencate a parte, sotto Elecraft. Se la frequenza è giusta ma il modo è sbagliato o manca, è l\'unica parte che varia nella gamma — l\'app lo ricava dalla radio e in alternativa lo chiede direttamente, quindi il modo potrebbe semplicemente arrivare in ritardo.',
			'settings.station.statusConnected' => 'Connesso',
			'settings.station.statusLost' => 'Disconnesso',
			'settings.station.notConfigured' => 'Non configurato',
			'settings.station.currentConfiguration' => 'Configurazione attuale',
			'settings.station.currentTransceiver' => 'Ricetrasmettitore attuale',
			'settings.station.currentTransceivers' => 'Ricetrasmettitori attuali',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => 'Messaggi in coda invece di interrompere',
			'settings.station.noRadioBSelected' => 'Nessuna Radio B selezionata',
			'settings.station.radioMode' => 'Modo della radio',
			'settings.station.keyerNotSupported' => 'Non supportato dalla radio attuale',
			'settings.station.catControlPreferences' => 'Preferenze del Controllo CAT',
			'settings.station.chooseTransceiver' => 'Scegli il ricetrasmettitore',
			'settings.station.configurationSection' => 'Configurazione',
			'settings.station.noTransceiverSelected' => 'Nessun ricetrasmettitore selezionato',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Usa ${name} per il VFO principale',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, zero: 'Nessun ricetrasmettitore', one: '${count} ricetrasmettitore', other: '${count} ricetrasmettitori', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} antenna', other: '${count} antenne', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} altro dispositivo', other: '${count} altri dispositivi', ), 
			'settings.station.equipmentInventory' => 'Inventario apparati',
			'settings.station.equipmentInUse' => 'Controlli del ricetrasmettitore',
			'settings.station.noTransceiver' => 'Nessuno',
			'settings.station.peerRadioNotAvailable' => 'Non disponibile',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Su ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} è su un altro dispositivo',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Questa radio è connessa a ${device}. La sua connessione e le sue impostazioni sono configurate su quel dispositivo.',
			'settings.station.antennaInUse' => 'Antenna in uso',
			'settings.station.keyInUse' => 'Manipolazione CW',
			'settings.station.phoneKeying' => 'Keyer in fonia',
			'settings.station.phoneKeyingNone' => 'Nessuno',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => 'Memorie in ${radio}',
			'settings.station.phoneKeyingComputer' => 'Audio da questo computer',
			'settings.station.phoneKeyingOff' => 'Il keyer in fonia è disattivato',
			'settings.station.computerVoiceSettings' => 'Audio del Computer',
			'settings.station.cwKeyingOptions' => 'Opzioni di manipolazione CW',
			'settings.station.noneSelected' => 'Nessuno',
			'settings.station.moreSettings' => 'Altre impostazioni',
			'settings.station.icomCivTroubleshootingTitle' => 'Se appaiono due porte seriali per la stessa radio',
			'settings.station.icomCivTroubleshooting' => 'Diverse radio Icom, tra cui l\'IC-705, presentano **due** porte seriali USB contemporaneamente (Icom le chiama Port A e Port B), entrambe impostate su CI-V per impostazione predefinita. Né questa app né il tuo sistema operativo possono distinguerle oltre questo: lo stesso ID vendor/prodotto USB appare semplicemente due volte, a volte qui contrassegnato con il suffisso `#2`. **Port A di solito è quella giusta** — normalmente la prima elencata dal sistema operativo o dal browser, e dove questa app riesce a distinguere le due porte la segna come suggerita. Se i comandi partono e la radio non risponde mai, prova l\'altra porta.',
			'settings.station.civAddressTroubleshootingTitle' => 'Se la radio non risponde mai',
			'settings.station.civAddressTroubleshooting' => '- **L\'indirizzo CI-V deve corrispondere** al menu della radio. Questa voce precompila l\'indirizzo di fabbrica del modello, ma una radio che condivide un bus CI-V è proprio il caso in cui viene cambiato. Un frame inviato all\'indirizzo sbagliato viene ignorato in silenzio, esattamente come con un cavo guasto.\n- **La velocità deve corrispondere** al CI-V BAUD RATE della radio (su USB, CI-V USB Baud Rate). Imposta sulla radio lo stesso valore mostrato qui, **non Auto**. Con Auto alcune radio, tra cui l\'IC-7300, si connettono e poi smettono di rispondere dopo circa un minuto.\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **L\'indirizzo CI-V deve corrispondere** al menu della radio. Questa voce precompila l\'indirizzo di fabbrica del modello, ma una radio che condivide un bus CI-V è proprio il caso in cui viene cambiato. Un frame inviato all\'indirizzo sbagliato viene ignorato in silenzio, esattamente come con un cavo guasto.\n${speed}\n- **Un\'altra app potrebbe occupare la porta**: WSJT-X, fldigi e rigctld la tengono tutti aperta.',
			'settings.station.icomUsbSpeedFollows' => '- **Non c\'è alcuna velocità da impostare.** Via USB questa radio comunica alla velocità usata dal computer, e questa voce usa sempre 115200, la velocità che serve allo scope.',
			'settings.station.ic7610UsbSpeed' => '- **Imposta CI-V USB Baud Rate su 115200**, la velocità che questa voce usa sempre perché serve allo scope — **non Auto**. Una radio impostata su qualsiasi altra velocità risponde con il silenzio.',
			'settings.station.civTransceiveTitle' => 'Se l\'app è lenta a seguire la radio',
			'settings.station.civTransceive' => 'Se l\'app impiega diversi secondi a mostrare un cambio di frequenza o di modo fatto sulla radio, attiva l\'impostazione **CI-V Transceive** della radio (sulla maggior parte dei modelli attuali, in SET > Connectors > CI-V). Con l\'impostazione attiva, la radio comunica ogni cambiamento nel momento in cui avviene. Con l\'impostazione disattivata, l\'app vede un cambiamento solo la volta successiva in cui lo chiede, ogni pochi secondi.',
			'settings.station.ic7300Mk2Note' => '\n- L\'**IC-7300 MK2** esce di fabbrica con l\'indirizzo `B6`, non il `94` precompilato qui — scegli invece la voce IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- L\'**IC-705** presenta due porte seriali USB, entrambe con il nome della radio. Il CI-V è sulla **prima**, che il selettore indica ogni volta che riesce a distinguerle.',
			'settings.station.ic7760PortNote' => '\n- L\'**IC-7760** usa il CI-V sulla **Port A** delle due porte seriali USB che presenta.',
			'settings.station.x6100PortNote' => '\n- L\'**X6100** usa il CI-V sulla sua porta **DEV** — la seconda delle due porte seriali che presenta, ed è quella indicata dal selettore.',
			'settings.station.rigctldTroubleshootingTitle' => 'Se l\'app non riesce a connettersi',
			'settings.station.rigctldTroubleshooting' => 'Questa voce si connette a un **demone rigctld che avvii tu**, non direttamente alla radio — il backend di Hamlib comunica con la radio e supporta centinaia di modelli.\n\n- **Il demone deve essere già in esecuzione**, ad es. `rigctld -m 1035 -r /dev/ttyUSB0`. Trova il numero di modello della tua radio con `rigctl -l`.\n- **Da un\'altra macchina**, avvialo con `-T 0.0.0.0`: per impostazione predefinita rigctld accetta connessioni solo dalla macchina su cui è in esecuzione.\n- **La porta** è 4532 a meno che tu non abbia avviato il demone con `-t`.\n- Una volta connesso, se manca la frequenza di solito è il demone stesso che non riesce a raggiungere la radio. Provalo con `rigctl -m 2 f` sulla macchina del demone.',
			'settings.station.flrigTroubleshootingTitle' => 'Se l\'app non riesce a connettersi',
			'settings.station.flrigTroubleshooting' => 'Questa voce si connette a un **programma flrig che avvii tu**, non direttamente alla radio — flrig comunica con la radio e supporta la maggior parte di marche e modelli.\n\n- **flrig deve essere già in esecuzione**, con il ricetrasmettitore configurato e connesso.\n- **La porta** è 12345 a meno che tu non l\'abbia cambiata nella configurazione di flrig (Config → Setup → Server).\n- **Da un\'altra macchina**, assicurati che il server di flrig sia raggiungibile. Ascolta su tutte le interfacce, ma il tuo firewall potrebbe non essere d\'accordo.\n- Una volta connesso, se manca la frequenza di solito è flrig stesso che non riesce a raggiungere la radio. Controlla che il display di flrig segua la manopola.',
			'settings.station.hrdTroubleshootingTitle' => 'Se l\'app non riesce a connettersi',
			'settings.station.hrdTroubleshooting' => 'Questa voce si connette a **Rig Control di Ham Radio Deluxe, in esecuzione sul tuo computer**, non direttamente alla radio — HRD comunica con la radio.\n\n- **Rig Control deve essere già in esecuzione** e connesso alla radio.\n- **Il suo IP server deve essere abilitato.** Rig Control comunica con gli altri programmi solo tramite questo.\n- **La porta** è 7809 a meno che tu non l\'abbia cambiata nelle impostazioni dell\'IP server.\n- **Da un\'altra macchina**, assicurati che il firewall lasci passare la connessione.\n\nQuesta voce è stata scritta a partire dalle descrizioni pubblicate del protocollo di HRD e non è stata provata con HRD. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Se l\'app non riesce a connettersi',
			'settings.station.n3fjpTroubleshooting' => 'Questa voce si connette a **un programma di logging N3FJP in esecuzione sul tuo computer**, non direttamente alla radio — N3FJP comunica con la radio.\n\n- **L\'API del programma deve essere attiva**: Settings → Application Program Interface, seleziona **TCP API Enabled**.\n- **La porta** è 1100 a meno che tu non l\'abbia cambiata lì.\n- **N3FJP deve avere un\'interfaccia radio configurata** per seguire o sintonizzare la radio. Senza, segnala solo ciò che viene digitato nella sua finestra di inserimento.\n- N3FJP segnala solo banda, modo e frequenza: niente potenza, niente stato di trasmissione.\n\nQuesta voce è stata scritta a partire dall\'API pubblicata di N3FJP e non è stata provata con N3FJP. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.commanderTroubleshootingTitle' => 'Se l\'app non riesce a connettersi',
			'settings.station.commanderTroubleshooting' => 'Questa voce si connette a **DXLab Commander, in esecuzione sul tuo computer**, non direttamente alla radio — Commander comunica con la radio.\n\n- **Commander deve essere già in esecuzione** e connesso alla radio.\n- **Il suo servizio di rete deve essere attivo**: il pulsante **Net Serv** nel pannello Radio della finestra Configuration di Commander.\n- **La porta** è 52002, la terza porta del blocco che inizia dalla **Base Port** di Net Serv (52000 a meno che tu non l\'abbia cambiata).\n- **Da un\'altra macchina**, assicurati che il firewall lasci passare la connessione.\n\nQuesta voce è stata scritta a partire dai messaggi TCP pubblicati di Commander e non è stata provata con Commander. Se funziona solo in parte, vale la pena segnalarlo.',
			'settings.station.ic705TroubleshootingTitle' => 'Se la radio non risponde mai',
			'settings.station.ic705Troubleshooting' => 'La radio ha una **sola** sessione di controllo remoto. Quando l\'accesso viene ignorato, quasi sempre qualcos\'altro la sta usando.\n\n- **Chiudi qualsiasi altro client.** wfview o RS-BA1 connessi alla stessa radio occupano quell\'unica sessione, e nel frattempo l\'accesso da qui viene semplicemente ignorato.\n- **Controlla le impostazioni di rete della radio.** La WLAN deve essere attiva, la radio deve essere sulla stessa rete e la sua funzione di controllo remoto (Network) deve essere abilitata.\n- **Le porte devono corrispondere** alla Control Port e alla Serial Port (UDP) della radio, o alle porte reindirizzate verso di esse. Una porta sbagliata viene accolta dal silenzio, come una radio spenta.\n- **Spegni e riaccendi la WLAN della radio** se resta bloccata. Questo libera in modo affidabile una sessione bloccata sulla radio.\n\nUna **password errata viene rifiutata esplicitamente**, non accolta dal silenzio. Se sei arrivato qui invece di vedere un messaggio di "rifiuto", il problema non è la password.',
			'settings.station.icomLanTroubleshooting' => 'La radio ha una **sola** sessione di controllo remoto. Quando l\'accesso viene ignorato, quasi sempre qualcos\'altro la sta usando.\n\n- **Chiudi qualsiasi altro client.** wfview, RS-BA1 o la Remote Utility di Icom connessi alla stessa radio occupano quell\'unica sessione, e nel frattempo l\'accesso da qui viene semplicemente ignorato.\n- **Controlla le impostazioni di rete della radio.** La sua porta LAN deve essere collegata alla stessa rete di questo dispositivo, il suo **Network Control** deve essere attivo, e nome utente e password devono essere configurati come utente di rete sulla radio.\n- **Le porte devono corrispondere** alla Control Port e alla Serial Port (UDP) della radio, o alle porte reindirizzate verso di esse. Una porta sbagliata viene accolta dal silenzio, come una radio spenta.\n- **Se si connette ma non risponde mai**, l\'indirizzo CI-V qui deve corrispondere al menu CI-V ADDRESS della radio. Questa voce precompila l\'indirizzo di fabbrica del modello.\n- **Spegni e riaccendi la radio** se resta bloccata.',
			'settings.station.statusStale' => 'Non risponde',
			'settings.station.statusDisconnected' => 'Non connesso',
			'settings.station.statusConnecting' => 'Connessione in corso…',
			'settings.station.statusDisconnecting' => 'Disconnessione in corso…',
			'settings.station.statusError' => 'Connessione non riuscita',
			'settings.station.currentRadioSettings' => 'Impostazioni attuali della radio',
			'settings.station.notSupportedByThisRadio' => 'Non supportato da questa radio',
			'settings.station.cwMessagesButton' => 'Messaggi CW',
			'settings.station.voiceMessagesButton' => 'Messaggi in Fonia',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Keyer vocale: ${count} memorie nella radio',
			'settings.station.antennaBands' => 'Bande',
			'settings.station.antennaType' => 'Tipo di antenna',
			'settings.station.antennaTypeRequired' => 'Scegli un tipo di antenna',
			'settings.station.antennaTypes.dipole' => 'Dipolo',
			'settings.station.antennaTypes.vertical' => 'Verticale',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Direttiva',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Filare / EFHW',
			'settings.station.antennaTypes.other' => 'Altro',
			'settings.station.keyType' => 'Tipo di tasto',
			'settings.station.keyTypeRequired' => 'Scegli un tipo di tasto',
			'settings.station.keyTypes.straight' => 'Tasto verticale',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semiautomatico meccanico)',
			'settings.station.keyTypes.fullyAutomatic' => 'Keyer completamente automatico',
			'settings.station.keyTypes.singlePaddle' => 'Paddle singolo',
			'settings.station.keyTypes.dualPaddle' => 'Paddle doppio',
			'settings.station.keyTypes.computerDriven' => 'Gestito da computer',
			'settings.station.keyTypes.other' => 'Altro',
			'settings.station.softwareIntermediaries' => 'Software intermediari',
			'settings.station.otherBrands' => 'Altre marche',
			'settings.station.otherEquipment' => 'Altri apparati (antenne, tasti, ecc.)',
			'settings.station.newAntenna' => 'Nuova antenna',
			'settings.station.newKey' => 'Nuovo tasto',
			'settings.station.newKeyer' => 'WinKeyer (K1EL o compatibile)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Keyer CAT in ${radio}',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyOnDevice' => ({required Object device}) => 'Tasto su ${device}',
			'settings.station.trackStationInfo' => 'Registra le informazioni di stazione per ogni QSO',
			'settings.station.includeStationInfoInAdif' => 'Includi nelle esportazioni ADIF',
			'settings.station.whatToTrack' => 'Cosa registrare?',
			'settings.station.trackFieldRig' => 'Ricetrasmettitore',
			'settings.station.trackFieldPower' => 'Potenza',
			'settings.station.watts' => 'Watt',
			'settings.station.trackFieldAntenna' => 'Antenna',
			'settings.station.trackFieldKey' => 'Tasto CW',
			'settings.station.placeholderConnectDelay' => 'Ritardo di connessione (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Quanto dura l\'handshake simulato. Vuoto o 0 si connette all\'istante.',
			'settings.station.placeholderDropAfter' => 'Disconnetti dopo (secondi)',
			'settings.station.placeholderDropAfterDescription' => 'Chiude la connessione da sola, per provare il percorso di riconnessione. Vuoto o 0 non si disconnette mai.',
			'settings.station.placeholderFailConnect' => 'Fallisci sempre la connessione',
			'settings.station.placeholderConnectFailure' => 'Alla radio segnaposto è stato detto di rifiutare questa connessione',
			'settings.station.placeholderFreq' => 'Frequenza (kHz)',
			'settings.station.placeholderFreqDescription' => 'Dove parte la radio segnaposto. In seguito riporta qualunque frequenza l\'app imposti.',
			'settings.station.placeholderMode' => 'Modo',
			'settings.station.placeholderModeDescription' => 'Il modo con cui parte la radio segnaposto, ad es. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Potenza (watt)',
			'settings.station.placeholderPurpose' => 'Usa questa radio per tenere traccia di quale apparato stai usando ai fini del logging',
			'settings.station.placeholderReplyDelay' => 'Ritardo di risposta (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Quanto impiega la radio segnaposto a riportare una modifica. Vuoto o 0 risponde subito.',
			'settings.station.cwKeyerField' => 'Keyer CW via CAT',
			'settings.station.cwKeyerFieldDescription' => 'Se questa radio trasmette CW da testo via CAT. Disattivato per un apparato che l\'app non conosce.',
			'settings.station.voiceMemories' => 'Memorie vocali',
			'settings.station.voiceMemoriesDescription' => 'Quante memorie vocali la radio riproduce via CAT. 0 per nessuna.',
			'settings.station.voiceMemoriesInvalid' => 'Un numero intero, 0 o più',
			'settings.station.yaesuMeterCapture' => 'Cattura le letture degli strumenti',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Legge lo strumento della potenza in uscita e l\'indicatore di SWR alto della radio durante la trasmissione e scrive i valori grezzi nel log. Serve a costruire la scala che Yaesu non pubblica — i valori non vengono mostrati come strumenti.',
			'settings.station.yaesuMeterCaptureDescription' => 'Legge gli strumenti PO, SWR e ALC della radio durante la trasmissione e scrive i valori grezzi nel log. Serve a costruire la scala che Yaesu non pubblica — i valori non vengono mostrati come strumenti.',
			'settings.station.telemetryInterval' => 'Intervallo di lettura degli strumenti (ms)',
			'settings.station.telemetryIntervalDescription' => 'Ogni quanto leggere gli strumenti della radio durante la trasmissione. Lascia vuoto per la velocità massima che questa connessione può gestire, fino a 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Un numero intero di millisecondi, da ${min} a ${max}',
			'settings.station.pollInterval' => 'Intervallo di interrogazione a riposo (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Ogni quanto chiedere alla radio frequenza e modo quando nessuno dei due cambia. Lascia vuoto per ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Un numero intero di millisecondi, da ${min} a ${max}',
			'settings.station.advancedSettings' => 'Impostazioni avanzate',
			'settings.station.placeholderSwr' => 'Lettura dell\'SWR',
			'settings.station.placeholderSwrDescription' => 'Cosa riporta questa radio sul suo strumento dell\'SWR durante la trasmissione. Sopra 1,8 il pannello avvisa.',
			'settings.station.placeholderSwrInvalid' => 'Un numero, 1 o più',
			'settings.station.keyerNone' => 'Nessuno',
			'settings.station.cwDialect' => 'Dialetto di manipolazione CW',
			'settings.station.cwDialectDescription' => 'Quale forma del comando KY accetta questa radio. Nessuno significa nessuna manipolazione CW via CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, riempito a 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (testo KY)',
			'settings.station.voiceDialect' => 'Dialetto del keyer vocale',
			'settings.station.voiceDialectDescription' => 'Come questa radio riproduce le sue memorie vocali via CAT. Nessuno significa nessuna memoria vocale via CAT. Con un dialetto e nessun numero, si applica il numero predefinito del dialetto.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, stile TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB e DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (pressioni di tasti)',
			'settings.station.placeholderDiagnostic' => 'Simulato',
			'settings.station.placeholderWholeNumberInvalid' => 'Deve essere un numero intero, 0 o più',
			'settings.station.placeholderFreqInvalid' => 'Deve essere una frequenza in kHz, maggiore di zero',
			'settings.station.placeholderModeInvalid' => 'Deve essere il nome di un modo, ad es. USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposizione',
			'settings.station.switchLayoutDescription' => 'Su quale lato del commutatore sono collegate le tue radio.',
			'settings.station.switchLayoutRequired' => 'Scegli come è cablato il commutatore',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Il commutatore ha rifiutato "${command}" (errore ${code})',
			'settings.station.switchBusyTransmitting' => 'Quella porta è in trasmissione — antenna non cambiata',
			'settings.station.switchNoAntenna' => 'Nessuna',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenna sulla porta ${port}',
			'settings.station.switchAntennaForDescription' => 'Quale delle tue antenne è collegata a questa porta del commutatore.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} Antenne, ${radios} Radio',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} Antenne, 1 Radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 Antenna, ${radios} Radio',
			'settings.station.switchCommonPort' => 'Comune',
			'settings.station.dcnAddress' => 'Indirizzo del dispositivo',
			'settings.station.dcnAddressDescription' => 'L\'indirizzo impostato sui DIP switch del modulo. Un modulo relè coassiale esce di fabbrica con 2.',
			'settings.station.dcnAddressRequired' => 'Deve essere un indirizzo di dispositivo da 1 a 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Porta ${port}',
			'settings.station.switchPortAutoHint' => 'segue i dati di banda',
			'settings.station.switchPortTransmittingHint' => 'in trasmissione — impossibile cambiare ora',
			'settings.station.switchCurrentStateHeader' => 'Stato attuale',
			'settings.station.switchCurrentStateDescription' => 'Su quale antenna si trova ogni porta radio in questo momento. Le modifiche hanno effetto immediato.',
			'settings.station.switchWiringHeader' => 'Cablaggio',
			'settings.station.switchPortInhibitedHint' => 'trasmissione inibita',
			'settings.station.rotatorAxes' => 'Assi',
			'settings.station.rotatorAxesDescription' => 'Se il rotore ruota solo in azimut, o anche in elevazione (un G-5500 o simile).',
			'settings.station.rotatorAxesAzimuth' => 'Solo azimut',
			'settings.station.rotatorAxesAzimuthElevation' => 'Azimut ed elevazione',
			'settings.station.rotatorAzimuthOffset' => 'Offset di azimut',
			'settings.station.rotatorAzimuthOffsetDescription' => 'Gradi da aggiungere a ciò che legge il controller, quando il suo zero non è il nord vero. Le rotazioni vengono corrette di conseguenza.',
			'settings.station.rotatorElevationOffset' => 'Offset di elevazione',
			'settings.station.rotatorAzimuthMin' => 'Azimut minimo',
			'settings.station.rotatorAzimuthMax' => 'Azimut massimo',
			'settings.station.rotatorAzimuthMaxDescription' => 'Nei gradi del controller stesso. Sopra 360 per un rotore con sovrapposizione, che così compie la rotazione più breve.',
			'settings.station.rotatorElevationMin' => 'Elevazione minima',
			'settings.station.rotatorElevationMax' => 'Elevazione massima',
			'settings.station.rotatorElevationMaxDescription' => 'Nei gradi del controller stesso. Sopra 90 per un rotore che si ribalta.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => 'Gradi interi, da ${min} a ${max}',
			'settings.station.rotatorLimitsInvalid' => 'Il limite minimo deve essere inferiore al massimo',
			'settings.station.rotatorPollInterval' => 'Intervallo di interrogazione (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'Ogni quanto chiedere al rotore dove punta. Lascia vuoto per ${fallback} ms.',
			'settings.station.rotatorAxesRequired' => 'Scegli su quali assi ruota il rotore',
			'settings.station.rotatorRefused' => 'Il controller ha rifiutato un comando. Controlla che sia impostato in modalità GS-232.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator risponde solo una volta configurato per farlo, altrimenti non dice assolutamente nulla:\n\n- **Attiva UDP Control** nel menu Setup di PstRotator.\n- **Fai corrispondere la porta**: Communication → UDP Control Port, 12000 se non cambiata. PstRotator risponde sulla porta successiva (12001), che deve essere libera su questo dispositivo.\n- **Collega PstRotator al suo controller.** Finché non lo è, non risponde nulla via UDP.\n- **Consentilo nel firewall** sul PC che esegue PstRotator, e su questo dispositivo, che ascolta le risposte.\n- **Su Mac, iPhone o iPad**, Ham2K Logger ha bisogno dell\'accesso alla Rete locale (Impostazioni → Privacy e sicurezza → Rete locale).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => 'Stato attuale: ${position}',
			'settings.station.rotatorDisconnected' => 'disconnesso',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '${degrees}° azimut',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '${degrees}° az',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '${degrees}° elevazione',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '${degrees}° el',
			'settings.station.rotatorNoReading' => 'In attesa che il controller comunichi la sua posizione…',
			'settings.station.rotatorNotResponding' => 'non risponde',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => 'Rotazione verso ${heading}, fin dove i limiti di questo rotore lo consentono',
			'settings.station.rotatorTargetAzimuth' => 'Ruota ad azimut',
			'settings.station.rotatorTargetAzimuthShort' => 'Ruota ad az',
			'settings.station.rotatorTargetElevation' => 'Ruota a elevazione',
			'settings.station.rotatorTargetElevationShort' => 'Ruota a el',
			'settings.station.rotatorAzimuthInvalid' => 'Deve essere da 0 a 360',
			'settings.station.rotatorElevationInvalid' => 'Deve essere da 0 a 180',
			'settings.station.rotatorTurn' => 'Ruota',
			'settings.station.rotatorStop' => 'Stop',
			'settings.station.configUnreadable' => 'Impossibile leggere le impostazioni salvate di questa radio. Apri le sue impostazioni e inseriscile di nuovo, oppure rimuovila e aggiungila di nuovo.',
			'settings.station.autoConnectHeld' => 'HaLo ha smesso di rispondere l\'ultima volta che si è connesso a questa radio, quindi questa volta non si è connesso da solo. Premi Connetti per riprovare.',
			'settings.offlineData.title' => 'Dati Fuori Rete',
			'settings.offlineData.noFiles' => 'Nessun file di dati',
			'settings.offlineData.noFilesDescription' => 'Abilita le estensioni di attività o di ricerca per scaricare qui i loro dati fuori rete.',
			'settings.offlineData.refresh' => 'Aggiorna',
			'settings.offlineData.refreshing' => 'Aggiornamento in corso…',
			'settings.offlineData.updateAll' => 'Aggiorna tutto',
			'settings.offlineData.updatingAll' => 'Aggiornamento di tutti i file di dati…',
			'settings.offlineData.neverDownloaded' => 'Mai scaricato',
			'settings.offlineData.updatedJustNow' => 'Aggiornato adesso',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Aggiornato ${days}g fa',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Aggiornato ${days}g ${hours}h fa',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Aggiornato ${hours}h fa',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Aggiornato ${hours}h ${minutes}m fa',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Aggiornato ${minutes}m fa',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'L\'ultimo download conteneva solo ${imported} record su ${existing} e non è stato usato. Aggiorna per accettarlo.',
			'settings.offlineData.extensionsSection' => 'Estensioni',
			'settings.profiles.notSet' => 'Non impostato',
			'settings.profiles.personalInfo' => 'Informazioni personali',
			'settings.profiles.personalInfoNote' => 'Queste informazioni potrebbero essere incluse nei log generati quando rilevanti per l\'invio',
			'settings.profiles.name' => 'Nome',
			'settings.profiles.email' => 'Email',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'Sezione ARRL',
			'settings.profiles.racSection' => 'Sezione RAC',
			'settings.profiles.section' => 'Sezione',
			'settings.search.clear' => 'Cancella',
			'settings.search.hint' => 'Cerca nelle preferenze',
			'settings.developer.developerModeDescription' => 'Abilita avvisi per sviluppatori, log di debug e strumenti.',
			'settings.developer.experiments' => 'Esperimenti',
			'settings.developer.showIdleMetrics' => 'Mostra metriche di inattività',
			'settings.developer.showIdleMetricsDescription' => 'Mostra nella barra di stato quanto è rimasto inattivo il motore delle estensioni nell\'ultimo secondo. Toccalo per le medie a 10 e 60 secondi.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% inattivo',
			'settings.developer.idleMetricsAverages' => 'Media inattività:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} abilitato', other: '${count} abilitati', ), 
			'settings.developer.patchTrack' => 'Canale Code Push',
			'settings.developer.patchTrackDescription' => 'Quale canale di code push over-the-air segue questo dispositivo. I canali più avventurosi ricevono le correzioni prima, ma meno testate. I code push si applicano al riavvio successivo.',
			'settings.developer.trackStable' => 'Stabile',
			'settings.developer.trackUnstable' => 'Instabile',
			'settings.developer.trackBleeding' => 'Bleeding',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Ricerca di un code push su "${track}"…',
			'settings.developer.patchDownloaded' => 'Code push scaricato — riavvia l\'app per applicarlo.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Nessun nuovo code push su "${track}".',
			'settings.developer.noPatchInstalled' => 'Nessun code push installato — in esecuzione il binario della release.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'In esecuzione il code push #${patch}.',
			'settings.developer.deepLinks' => 'Deep link',
			'settings.developer.registerUrlSchemes' => 'Registra gli schemi URL',
			'settings.developer.registerUrlSchemesDescription' => 'Consenti ai link com.ham2k:// di aprire questa copia dell\'app',
			'settings.developer.registerUrlSchemesDone' => 'Questa copia ora apre i link com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Impossibile registrare: ${error}',
			'settings.developer.systemInformation' => 'Informazioni di Sistema',
			'settings.developer.appVersion' => 'Versione dell\'app',
			'settings.developer.dataFolder' => 'Cartella dei dati',
			'settings.developer.loading' => '(caricamento…)',
			'settings.developer.panelLoadFailed' => 'Impossibile caricare questo pannello delle impostazioni.',
			'settings.developer.extDevServer' => 'Server di sviluppo estensioni',
			'settings.developer.extensionSettings' => 'Impostazioni Estensioni',
			'settings.developer.extDevServerDescription' => 'Carica le estensioni da un server di sviluppo sulla tua rete invece di quelle integrate nell\'app, e ricaricale quando salvi.',
			'settings.developer.extDevServerAddress' => 'Indirizzo del server',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Connetti',
			'settings.developer.extDevServerDisconnect' => 'Disconnetti',
			'settings.developer.extDevServerConnecting' => 'Connessione in corso…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Fornisce ${count} estensione: ${keys}', other: 'Fornisce ${count} estensioni: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Non connesso',
			'settings.developer.extDevServerReconnect' => 'Riconnetti all\'avvio',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Ultimo ricaricamento: ${key} alle ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} estensione con errori di build', other: '${count} estensioni con errori di build', ), 
			'settings.developer.catalog' => 'Catalogo Estensioni',
			'settings.developer.catalogDescription' => 'Leggi il catalogo da un altro server — uno locale mentre lavori sul catalogo stesso. Vuoto significa catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Indirizzo del catalogo',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Canali di ricerca del catalogo',
			'settings.developer.catalogSearchStable' => 'Solo Stabile',
			'settings.developer.catalogSearchUnstable' => 'Instabile o superiore',
			'settings.developer.catalogSearchBleeding' => 'Bleeding o superiore',
			'settings.about.notices' => 'Avvisi e Messaggi',
			'settings.about.noticesDescription' => 'Annunci e messaggi di stato',
			'settings.about.releaseNotes' => 'Note di rilascio',
			'settings.about.copiedVersion' => 'Dettagli della versione copiati negli appunti',
			'settings.panels.settings' => 'Preferenze dell\'applicazione',
			'settings.panels.settingsDescription' => 'Fai funzionare l\'app come vuoi tu',
			'settings.panels.commonSettings' => 'Preferenze comuni',
			'settings.panels.syncDescription' => 'Backup e sincronizzazione dei tuoi log tra i dispositivi',
			'settings.panels.accountsDescription' => 'Credenziali dei servizi, dati fuori rete e altro',
			'settings.panels.extensions' => 'Estensioni e Funzionalità',
			'settings.panels.extensionsDescription' => 'Attività, Contest, Pannelli Dashboard e altre funzionalità',
			'settings.panels.profilesDescription' => 'Nominativo operatore e profilo di stazione',
			'settings.panels.stationProfiles' => 'Profili di stazione',
			'settings.panels.developerSettings' => 'Impostazioni Sviluppatore',
			'settings.panels.developerSettingsDescription' => 'Strumenti di debug e sviluppo',
			'settings.panels.about' => 'Informazioni',
			'settings.panels.aboutDescription' => 'Versione, crediti e informazioni legali',
			'settings.panels.unavailableTitle' => 'Alcune impostazioni non sono disponibili',
			'settings.panels.unavailableText' => 'L\'ambiente delle estensioni non si è avviato, quindi mancano le impostazioni fornite dalle estensioni.',
			'settings.panels.station' => 'Configurazione Stazione',
			'settings.panels.stationDescription' => 'Controllo CAT e altre opzioni',
			'settings.panels.peers' => 'Dispositivi Peer',
			'settings.panels.peersDescription' => 'Connettiti ad altri dispositivi nelle vicinanze',
			'settings.showMoreSettings' => 'Mostra altre impostazioni',
			'settings.gridPrecision' => 'Precisione del locatore',
			'settings.gridPrecisionOpts.six' => '6 caratteri (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 caratteri (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 caratteri',
			'settings.gridPrecisionDescription.eight' => '8 caratteri',
			'commands.enableSyncFirst' => 'Prima abilita la sincronizzazione nelle Impostazioni.',
			'commands.fullResyncStarted' => 'Risincronizzazione completa avviata — prima è stato fatto un backup dei dati locali.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Nessun file di dati corrisponde a "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Ricaricamento non riuscito: ${error}',
			'commands.reloadingAll' => 'Ricaricamento di tutti i file di dati…',
			'commands.reloadingTarget' => ({required Object target}) => 'Ricaricamento dei file di dati ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Esperimento sconosciuto "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} abilitato',
			'commands.experimentDisabled' => ({required Object name}) => '${name} disabilitato',
			'commands.sentryTestSent' => 'Segnalazione di errore di prova inviata a Sentry',
			'commands.idleMetricsEnabled' => 'Metriche di inattività abilitate nella barra di stato',
			'commands.idleMetricsDisabled' => 'Metriche di inattività disabilitate',
			'commands.sentryTestLocalOnly' => 'Sentry è disabilitato in questa build — errore di prova registrato solo localmente',
			'commands.noOperationOpen' => 'Questo comando richiede un\'operazione aperta',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Non so come contrassegnare un \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => '${place} non è attivo in questa app',
			'commands.goUnknown' => ({required Object to}) => 'Non so come andare a \'${to}\'',
			'commands.goBlocked' => 'Prima chiudi la finestra di dialogo aperta',
			'commands.operationAlreadyStarted' => 'Questa operazione ha già un marcatore di inizio',
			'commands.couldNotOpenLocation' => 'Pausa aggiunta, ma impossibile aprire la schermata della posizione',
			'commands.noTestOperations' => 'Nessuna Operazione di Test da eliminare',
			'commands.purgeTestsUnavailable' => 'PURGETESTS deve mostrare una finestra di conferma, che qui non è disponibile',
			'commands.syncAllUnavailable' => 'SYNCALL deve mostrare una finestra di conferma, che qui non è disponibile',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Eliminata ${count} Operazione di Test', other: 'Eliminate ${count} Operazioni di Test', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Eliminate ${purged} Operazioni di Test su ${total} — le altre non sono riuscite; riprova PURGETESTS',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Eliminato ${count} contatto di test senza operazione', other: 'Eliminati ${count} contatti di test senza operazione', ), 
			'commands.purgeTestsContactsFailed' => 'Operazioni di Test eliminate, ma l\'eliminazione dei contatti di test senza operazione non è riuscita; riprova PURGETESTS',
			'commands.purgeTestsNothingToDo' => 'Non è stato eliminato nulla',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Rimosse ${removed} Operazioni di Test su ${total} — le altre non sono riuscite; riprova con Rivedi',
			'commands.receivedPurgesFailed' => 'Impossibile rimuovere quelle Operazioni di Test — riprova con Rivedi',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} Operazione di Test è stata rimossa su un altro dispositivo', other: '${count} Operazioni di Test sono state rimosse su un altro dispositivo', ), 
			'commands.receivedPurgesReview' => 'Rivedi',
			'commands.settingOn' => 'On',
			'commands.settingOff' => 'Off',
			'commands.settingEmpty' => '(vuoto)',
			'commands.settingSecretSet' => '(impostato)',
			'commands.settingSecretUnset' => '(non impostato)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selezionati',
			'commands.settingExpectsOnOff' => 'on o off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'uno tra: ${choices}',
			'commands.settingExpectsNumber' => 'un numero',
			'commands.settingVanished' => ({required Object label}) => '“${label}” non è più disponibile',
			'commands.noCwKeyer' => 'Nessuna radio connessa può trasmettere in CW',
			'commands.noKeyer' => 'Nessuna radio connessa può trasmettere in CW o riprodurre memorie vocali',
			'commands.keyerNeedsOperation' => 'Apri un\'operazione per usare il keyer CW',
			'commands.keyerExperimentOff' => 'La manipolazione CW è disattivata — attivala con EXP KEYER',
			'commands.esmExperimentOff' => 'Invio trasmette i messaggi è disattivato — attivalo con EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Trasmissione CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Messaggio CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'Il messaggio CW F${n} non è stato trasmesso: le estensioni non sono pronte',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => 'Messaggio in fonia M${n}: ${error}',
			'commands.voiceMessageNotRendered' => 'le estensioni non sono pronte',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => 'Nulla trasmesso: la Radio ${radio} non può trasmetterlo',
			'commands.so2rNoRadioB' => 'Nulla trasmesso: scegli una Radio B in Configurazione Stazione per trasmettere da questo set',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” non ha accettato quel valore',
			'commandDialog.hint' => 'Cerca nominativi o digita un comando',
			'commandDialog.noResults' => ({required Object text}) => 'Nessun risultato per “${text}”',
			'commandDialog.sectionCommands' => 'Comandi',
			'commandDialog.sectionGoTo' => 'Vai a',
			'commandDialog.sectionOperations' => 'Operazioni',
			'commandDialog.goHome' => 'Home',
			'commandDialog.goSettings' => 'Impostazioni',
			'commandDialog.goNewOperation' => 'Nuova operazione',
			'commandDialog.runTyped' => ({required Object text}) => 'Esegui “${text}”',
			'commandDialog.sectionSuggestions' => 'Prova',
			'commandDialog.lookingUp' => 'Ricerca del nominativo in corso…',
			'commandDialog.blockedByPane' => 'Impossibile usare i comandi mentre è aperto un pannello o una finestra di dialogo',
			'keyboardShortcuts.title' => 'Scorciatoie da Tastiera',
			'keyboardShortcuts.description' => 'Personalizza le combinazioni di tasti',
			'keyboardShortcuts.search' => 'Cerca comandi e tasti',
			'keyboardShortcuts.import' => 'Importa…',
			'keyboardShortcuts.export' => 'Esporta…',
			'keyboardShortcuts.resetAll' => 'Ripristina Tutto',
			'keyboardShortcuts.resetAllTitle' => 'Ripristinare tutte le scorciatoie?',
			'keyboardShortcuts.resetAllBody' => 'Ogni comando torna ai suoi tasti predefiniti, e i tasti assegnati ai comandi digitati vengono rimossi.',
			'keyboardShortcuts.reset' => 'Ripristina',
			'keyboardShortcuts.noKey' => 'Nessun tasto',
			'keyboardShortcuts.changed' => 'Modificata',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} è assegnato anche a ${commands}',
			'keyboardShortcuts.groupApp' => 'App',
			'keyboardShortcuts.groupKeying' => 'Manipolazione',
			'keyboardShortcuts.groupLogging' => 'Logging',
			'keyboardShortcuts.groupCommands' => 'Comandi',
			'keyboardShortcuts.groupFixed' => 'Tasti fissi',
			'keyboardShortcuts.contextApp' => 'Ovunque',
			'keyboardShortcuts.contextLogView' => 'Viste Operazione, Caccia e Log',
			'keyboardShortcuts.contextOperation' => 'Vista Operazione, manipolando una radio CAT',
			'keyboardShortcuts.contextLogging' => 'Nel pannello di logging',
			'keyboardShortcuts.addCommand' => 'Aggiungi un Comando…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Comando sconosciuto: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Apri la finestra dei comandi',
			'keyboardShortcuts.command.toggleTheme' => 'Passa da chiaro a scuro e viceversa',
			'keyboardShortcuts.command.toggleLanguage' => 'Passa da inglese a spagnolo e viceversa',
			'keyboardShortcuts.command.fontScaleUp' => 'Testo più grande',
			'keyboardShortcuts.command.fontScaleDown' => 'Testo più piccolo',
			'keyboardShortcuts.command.fontScaleReset' => 'Testo a dimensione normale',
			'keyboardShortcuts.command.densityLooser' => 'Layout più ampio',
			'keyboardShortcuts.command.densityDenser' => 'Layout più denso',
			'keyboardShortcuts.command.densityAuto' => 'Densità del layout automatica',
			'keyboardShortcuts.command.find' => 'Trova nel log',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Trasmetti il messaggio ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Attiva o disattiva la modalità tastiera',
			'keyboardShortcuts.command.ptt' => 'Push to talk',
			'keyboardShortcuts.command.wipe' => 'Cancella il contatto in inserimento',
			'keyboardShortcuts.fixed.callsign' => 'Digitare i nominativi',
			'keyboardShortcuts.fixed.escape' => 'Ferma la trasmissione, torna indietro di un passo o chiudi',
			'keyboardShortcuts.fixed.enter' => 'Registra il contatto',
			'keyboardShortcuts.fixed.space' => 'Campo successivo',
			'keyboardShortcuts.fixed.tab' => 'Campo successivo o precedente',
			'keyboardShortcuts.fixed.arrows' => 'Spostati tra campi, controlli e log',
			'keyboardShortcuts.fixed.walk' => 'Scorri il log pagina per pagina, o vai alle sue estremità',
			'keyboardShortcuts.fixed.undo' => 'Annulla una cancellazione o un\'eliminazione',
			'keyboardShortcuts.editor.addShortcut' => 'Aggiungi Scorciatoia',
			'keyboardShortcuts.editor.listening' => 'Premi i tasti per la scorciatoia…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc interrompe l\'ascolto',
			'keyboardShortcuts.editor.add' => 'Aggiungi',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} appartiene ai campi di logging o a una finestra di dialogo, e non può essere cambiato.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} serve per digitare i nominativi. Tienilo premuto insieme a Cmd, Ctrl o Alt.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'Il sistema potrebbe intercettare ${keys} prima che l\'app lo veda.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} è già uno dei tasti di questo comando.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Togli ${keys} a “${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'Ripristina Predefinito',
			'keyboardShortcuts.editor.remove' => 'Rimuovi',
			'keyboardShortcuts.editor.commandLabel' => 'Comando',
			'keyboardShortcuts.editor.commandHint' => 'Inserisci un comando valido, o più comandi separati da ";"',
			'keyboardShortcuts.editor.removeCommand' => 'Rimuovi Comando',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'Nessun comando interpreta “${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'Ancora nessun tasto',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Scorciatoie salvate in ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'Impossibile esportare le scorciatoie: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'Impossibile aprire il file: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} non è un file di scorciatoie che questa app possa leggere: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'il testo non è YAML valido (riga ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'non è un file di scorciatoie da tastiera Ham2K',
			'keyboardShortcuts.file.problemNewerVersion' => 'è stato scritto da una versione più recente dell\'app',
			'keyboardShortcuts.file.problemMalformed' => 'una parte non rispetta il formato delle scorciatoie',
			'keyboardShortcuts.file.problemTooLarge' => 'è troppo grande',
			'keyboardShortcuts.file.importTitle' => 'Importa Scorciatoie',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Scritto su ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'Il file non dice su quale tastiera è stato scritto.',
			'keyboardShortcuts.file.translate' => 'A cosa deve corrispondere ciascuno di questi tasti su questa tastiera?',
			'keyboardShortcuts.file.leaveOut' => 'Escludi quelle scorciatoie',
			'keyboardShortcuts.file.replace' => 'Sostituisci la configurazione di questo dispositivo',
			'keyboardShortcuts.file.replaceHint' => 'Ogni scorciatoia non presente nel file torna al valore predefinito.',
			'keyboardShortcuts.file.merge' => 'Aggiungi alla configurazione di questo dispositivo',
			'keyboardShortcuts.file.mergeHint' => 'Le scorciatoie del file sostituiscono quelle di questo dispositivo per gli stessi comandi, e le altre restano.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'Sconosciuti in questa versione, quindi esclusi: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'Non sono scorciatoie, quindi esclusi: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Tasti che l\'app riserva a sé, quindi esclusi: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Assegnati a più di un comando dopo l\'importazione: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Importa',
			'keyboardShortcuts.file.imported' => 'Scorciatoie importate',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'Questa build è scaduta',
			'expiredBuild.body' => 'Visita ham2k.com e scarica una versione più recente.',
			'expiredBuild.visit' => 'Visita ham2k.com',
			'expiredBuild.dismiss' => 'Continua comunque',
			'staleness.codePushFloorTitle' => 'Un aggiornamento importante è in attesa',
			'staleness.codePushFloorBody' => 'Questa versione ha una correzione che non hai ancora.',
			'staleness.restartToApply' => 'Riavvia l\'app per applicarla.',
			'staleness.quitAndReopen' => 'Esci dall\'app e riaprila per applicarla.',
			'staleness.reopenToApply' => 'Chiudi l\'app e riaprila per applicarla.',
			'staleness.ignoreForNow' => 'Ignora per ora',
			'spotting.noQsoYet' => 'Nessun QSO ancora registrato da spottare.',
			'spotting.setFrequencyFirst' => 'Prima imposta una frequenza.',
			'spotting.nothingToSpot' => 'Niente da spottare — nessuna estensione offre lo spotting qui.',
			'spotting.incompleteCall' => 'Impossibile spottare un nominativo incompleto — prima completa il nominativo.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} non riuscito: ${message}',
			'spotting.unknownError' => 'errore sconosciuto',
			'spotting.notSent' => 'Spot non inviato.',
			'spotting.allSkipped' => 'Spot non inviato: tutte le fonti spot lo hanno saltato.',
			'spotting.notRefreshedOffline' => 'Nessuna connessione — gli spot non sono stati aggiornati',
			'dataFiles.downloading' => 'Download in corso…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Impossibile scaricare ${name}',
			'dataFiles.downloadFailedWebHint' => 'Potrebbe essere un problema di rete, oppure l\'host di questo link potrebbe non supportare i download diretti da un browser web. Prova l\'app desktop o mobile, o un altro servizio di hosting.',
			'dataFiles.downloadTimedOut' => 'Il server ha impiegato troppo tempo a rispondere. Riprova più tardi.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} ha risposto con un errore (HTTP ${status}). Riprova più tardi.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} non ha potuto fornire questo file (HTTP ${status}). Controlla che il suo indirizzo sia ancora corretto.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM non ha un file di call history per ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'Il download della call history di N1MM per ${stem} non ha funzionato. Riprova più tardi.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Impossibile elaborare ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Il download conteneva solo ${imported} dei ${existing} record presenti su questo dispositivo, quindi quelli mancanti sono stati mantenuti. Aggiornarlo in Impostazioni › Dati Fuori Rete lo accetta comunque.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Importato ${count} record per ${label}.', other: 'Importati ${count} record per ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Dati importati per ${label}.',
			'dataFiles.cleanedUpTitle' => 'Dati delle estensioni ripuliti',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Rimossi i dati di ${count} file di dati da estensioni disabilitate.', other: 'Rimossi i dati di ${count} file di dati da estensioni disabilitate.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} record',
			'dataFiles.definitionUnavailable' => 'La fonte del file non ha fornito una definizione — la sua estensione potrebbe essere in fase di riavvio o mal configurata. Riprova tra un momento.',
			'updates.updateAvailable' => 'Aggiornamento disponibile',
			'updates.newVersionAvailable' => ({required Object version}) => 'È disponibile una nuova versione (${version}).',
			'updates.getIt' => 'Scaricala',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Aggiornamento pronto',
			'updates.restartToApply' => 'È stato scaricato un aggiornamento. Riavvia per applicarlo.',
			'updates.appliesNextLaunch' => 'È stato scaricato un aggiornamento. Verrà applicato la prossima volta che apri l\'app.',
			'updates.restartNow' => 'Riavvia ora',
			'updates.reloadToUpdate' => 'È disponibile una versione più recente di questa pagina. Ricarica per ottenerla.',
			'updates.reloadNow' => 'Ricarica ora',
			'updates.checkForUpdates' => 'Controlla aggiornamenti',
			'updates.checkingForUpdates' => 'Controllo degli aggiornamenti…',
			'updates.upToDate' => 'Aggiornato',
			'updates.automaticChecks' => 'Controlla automaticamente',
			'updates.automaticChecksDescription' => 'Cerca nuove versioni in background, dal prossimo avvio dell\'app',
			'extensionService.runtimeNotReady' => 'L\'ambiente delle estensioni non è pronto.',
			'extensionService.testFailed' => ({required Object error}) => 'Prova non riuscita: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Connesso come ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configurazione del campo non valida',
			'extensionService.invalidValue' => 'Valore non valido',
			'extensionService.validationError' => ({required Object error}) => 'Errore di validazione: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Azione non riuscita: ${error}',
			'extensionService.commandFailed' => 'Il comando non è stato eseguito',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name} non può modificare le impostazioni: non l\'ha chiesto all\'installazione',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name} non può controllare la radio: non l\'ha chiesto all\'installazione',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name} non può eseguirlo: è uno dei comandi per sviluppatori dell\'app stessa',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => 'Al momento non è possibile inviare segnalazioni',
			'extensionService.stashUnavailable' => 'L\'Archivio File di Ham2K non è raggiungibile al momento',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => 'Nessuna risposta da ${names} alla ricerca delle attività, quindi alcuni risultati potrebbero mancare.',
			'extensionService.activitySearchSomeSourcesFailed' => 'Alcune estensioni di attività non hanno risposto alla ricerca, quindi alcuni risultati potrebbero mancare.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} ha impiegato troppo tempo nei suoi timer. Sono fermi finché le estensioni non si riavviano.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'I timer di ${name} continuavano a fallire. Sono fermi finché le estensioni non si riavviano.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} si è bloccata in un timer. I suoi timer sono fermi finché le estensioni non si riavviano.',
			'operationLocationScreen.title' => 'Posizione dell\'Operazione',
			'operationLocationScreen.selectedLocation' => 'Posizione Selezionata',
			'operationLocationScreen.gridSquare' => 'Locatore del quadrato della griglia di Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Servono 4, 6, 8 o 10 caratteri, come FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Posizioni Suggerite',
			'operationLocationScreen.deviceGps' => 'GPS Dispositivo',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS da ${device}',
			'operationLocationScreen.locating' => 'Localizzazione…',
			'operationLocationScreen.gpsUnavailable' => 'Posizione non disponibile',
			'operationLocationScreen.permissionDenied' => 'Permesso di posizione negato',
			'operationLocationScreen.permissionBlocked' => 'Permesso di posizione bloccato',
			'operationLocationScreen.moreDetails' => 'Altri dettagli',
			'operationLocationScreen.stateOrProvince' => 'Stato o Provincia (opzionale)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controlli attività non disponibili',
			'operationLocationScreen.controlsUnavailableReason' => 'Queste referenze sono ancora utilizzabili; semplicemente non è stato possibile raggiungere le loro attività.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Riprova',
			'operationLocationScreen.county' => 'Contea (opzionale)',
			'versionLabel.version' => ({required Object version}) => 'Versione ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Ancora nessun avviso',
			'notices.webStorageInMemory' => 'Questo browser non ha potuto fornire un archivio persistente — il log è solo in memoria e andrà PERSO alla chiusura di questa scheda. Usa una versione recente di Chrome, Firefox, Safari o Edge.',
			'notices.webStorageUnreliable' => 'Questo browser usa un archivio di riserva che non è sicuro con più schede — tieni aperta una sola scheda e lascia attiva la sincronizzazione.',
			'notices.logFromNewerBuildTitle' => 'Questo log richiede una versione più recente',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Il tuo log è stato scritto da una versione più recente di HaLo (versione di archiviazione ${storage}; questa comprende la ${understood}), quindi non può essere aperto e i nuovi contatti non verranno salvati. Reinstalla la versione più recente — oppure, se intendevi usare questa build, indicale una cartella dei dati diversa. Il log si trova in ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Il tuo log è stato scritto da una versione più recente di HaLo (versione di archiviazione ${storage}; questa comprende la ${understood}), quindi non può essere aperto e i nuovi contatti non verranno salvati. Apri invece questo log con quella versione più recente.',
			'notices.preferencesRestoredTitle' => 'Impostazioni ripristinate da un backup',
			'notices.preferencesRestored' => 'Il file delle impostazioni non era leggibile, quindi HaLo ha ripristinato la sua ultima copia valida. Le modifiche fatte nella sessione precedente potrebbero dover essere reimpostate. Il file illeggibile è conservato accanto, con il nome shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Impostazioni reimpostate',
			'notices.preferencesReset' => 'Il file delle impostazioni non era leggibile e non c\'era un backup a cui ricorrere, quindi HaLo è partito con i valori predefiniti. Il file illeggibile è conservato nella cartella dei dati dell\'app, con il nome shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} non è stata connessa automaticamente',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo ha smesso di rispondere l\'ultima volta che ha iniziato a connettersi a ${name}, quindi questa volta non l\'ha toccata per non rischiare che succeda di nuovo. Controlla che la radio sia accesa e il cavo collegato, poi premi Connetti su di essa nelle Impostazioni.',
			'syncAccount.anonymous' => ({required Object id}) => 'Account Anonimo (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (conferma in sospeso)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (conferma in sospeso - #${id})',
			'deepLink.needsAnOperation' => 'Prima avvia un\'operazione, poi invia di nuovo quel contatto',
			'deepLink.waitingInOperation' => 'Quel contatto è in attesa nell\'operazione dietro questa schermata',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Questo dispositivo non ha alcuna attività per ${refs}, quindi quelle referenze sono state omesse',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Impossibile raggiungere le tue attività, quindi ${refs} è stata omessa — riprova quel link',
			'confirmDevice.title' => 'Conferma un Dispositivo',
			'confirmDevice.codePrompt' => 'Inserisci il codice mostrato sul dispositivo che vuole unirsi a questo account.',
			'confirmDevice.code' => 'Codice',
			'confirmDevice.lookUp' => 'Cerca',
			'confirmDevice.codeNotFound' => 'Nessuna richiesta corrisponde a quel codice. I codici scadono dopo 10 minuti — chiedine uno nuovo all\'altro dispositivo.',
			'confirmDevice.linkExpired' => 'Quel link è scaduto. Chiedi all\'altro dispositivo di mostrare un nuovo codice QR.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Collegare ${device} a questo account?',
			'confirmDevice.unnamedDevice' => 'un dispositivo senza nome',
			'confirmDevice.grantWarning' => 'Potrà leggere e modificare ogni operazione e QSO di questo account.',
			'confirmDevice.needsSyncTitle' => 'La sincronizzazione non è ancora attiva su questo dispositivo',
			'confirmDevice.needsSyncText' => 'Attiva la sincronizzazione Ham2K Log Filer e collega questo dispositivo a un account: solo allora potrà ammetterne un altro.',
			'confirmDevice.malformedRequest' => 'Il server di sincronizzazione ha inviato una richiesta che questa app non riesce a leggere. Chiedi all\'altro dispositivo di riprovare.',
			'confirmDevice.linkIt' => 'Collega Dispositivo',
			'switchAccounts.noAccountDetails' => 'Ancora nessun dettaglio dell\'account',
			'switchAccounts.currentAccount' => 'Account attuale',
			'switchAccounts.otherAccounts' => 'Altri account',
			'switchAccounts.linkToAnother' => 'Collega a un altro account',
			'switchAccounts.linkWithSibling' => 'Collega con un\'altra app Ham2K',
			'switchAccounts.linkWithPolo' => 'Collega con l\'account della versione precedente',
			'switchAccounts.linkWithSiblingDescription' => 'Hai installato un\'altra app Ham2K. Collegati con l\'account usato lì.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Approva la richiesta in ${app}, poi torna qui.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Apri di nuovo ${app}',
			'switchAccounts.siblingNoGrant' => 'Non ha funzionato? Aprila di nuovo, o torna indietro e collegati in un altro modo.',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Impossibile aprire ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Il link è scaduto e ne è pronto uno nuovo — apri di nuovo ${app}.',
			'switchAccounts.tryAgain' => 'Riprova',
			'switchAccounts.linkWithQr' => 'Collega con un codice QR',
			'switchAccounts.linkWithQrDescription' => 'Scansionalo da un dispositivo che usa già l\'account',
			'switchAccounts.linkWithEmail' => 'Collega con un indirizzo email',
			'switchAccounts.linkWithEmailDescription' => 'Conferma con un codice o un link via email',
			'switchAccounts.enterEmailPrompt' => 'Inserisci l\'indirizzo email dell\'account che vuoi far usare a questo dispositivo.',
			'switchAccounts.emailAddress' => 'Indirizzo email',
			'switchAccounts.linkAccount' => 'Collega account',
			'switchAccounts.copiedCode' => 'Codice copiato negli appunti',
			'switchAccounts.copyCode' => 'Copia codice',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Apri l\'app Ham2K su un dispositivo già collegato con ${email} e inserisci questo codice per approvare la richiesta:',
			'switchAccounts.waitingForConfirmation' => 'In attesa di conferma…',
			'switchAccounts.sendEmailInstead' => 'Invia invece un\'email di conferma',
			'switchAccounts.emailSent' => ({required Object email}) => 'È stata inviata un\'email a ${email}. Aprila e conferma la richiesta per collegare questo dispositivo.',
			'switchAccounts.resendEmail' => 'Invia di nuovo l\'email',
			'switchAccounts.qrPrompt' => 'Scansiona questo codice QR da un dispositivo già collegato all\'account che vuoi — ad esempio con Ham2K Portable Logger sul tuo telefono.',
			'switchAccounts.serverUnreachable' => 'Impossibile raggiungere il server di sincronizzazione. Riprova più tardi.',
			'switchAccounts.emailRequired' => 'Inserisci un indirizzo email da collegare.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Nessun account trovato per ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Il server di sincronizzazione ha rifiutato la richiesta: ${error}',
			'switchAccounts.noLinkCode' => 'Il server di sincronizzazione non ha restituito un codice di collegamento. Riprova più tardi.',
			'switchAccounts.noConfirmationCode' => 'Il server di sincronizzazione non ha inviato un codice di conferma. Riprova più tardi.',
			'switchAccounts.switchNotAccepted' => 'Quell\'account non ha accettato il cambio. Prova invece a collegarlo con un indirizzo email.',
			'switchAccounts.requestFailed' => 'Qualcosa è andato storto nella comunicazione con il server di sincronizzazione. Riprova più tardi.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} QSO', other: '${count} QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} operazione', other: '${count} operazioni', ), 
			'qsonImport.title' => 'Importa operazione QSON',
			'qsonImport.description' => 'Crea una nuova operazione da un file QSON, come quelli che la Modalità Sviluppatore esporta qui o in PoLo.',
			'qsonImport.dropHint' => 'Trascina qui un file QSON per importarlo come nuova operazione',
			'qsonImport.importing' => ({required Object filename}) => 'Importazione di ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => 'Impossibile importare ${filename}: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'Impossibile aprire un file da importare: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} non è testo UTF-8, quindi non è un file QSON',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} non è un file JSON, quindi non è un file QSON',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} non contiene un\'operazione QSON',
			'qsonImport.busy' => 'È già in corso un\'importazione. Attendi che finisca prima di avviarne un\'altra.',
			'qsonImport.oneFileOnly' => 'Trascina un file QSON alla volta — ognuno diventa un\'operazione a sé.',
			'adifImport.title' => 'Importa QSO da ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Lettura di ${filename}…',
			'adifImport.dropHint' => 'Trascina qui un file ADIF da importare',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} QSO in questo file', other: '${formatted} QSO in questo file', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} già nel tuo log', other: '${formatted} già nel tuo log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} verrà importato', other: '${formatted} verranno importati', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} nuovo contatto', other: '${formatted} nuovi contatti', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} verrà unito a un contatto esistente', other: '${formatted} verranno uniti a contatti esistenti', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} non può essere importato (nessun nominativo)', other: '${formatted} non possono essere importati (nessun nominativo)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} richiede un controllo più attento', other: '${formatted} richiedono un controllo più attento', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Impossibile recuperare le referenze per ${count} contatto', other: 'Impossibile recuperare le referenze per ${formatted} contatti', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Le referenze ${programs} potrebbero essere incomplete per ${count} contatto', other: 'Le referenze ${programs} potrebbero essere incomplete per ${formatted} contatti', ), 
			'adifImport.stackingTypesUnknown' => 'I contatti combinati potrebbero perdere una referenza — le attività non hanno potuto indicare quali tipi si sommano. Annulla e riprova per evitarlo.',
			'adifImport.nothingToImport' => 'Non c\'è niente da importare in questo file',
			'adifImport.confirm' => 'Importa',
			'adifImport.importing' => ({required Object filename}) => 'Importazione di ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: 'Importato ${count} contatto da ${filename}', other: 'Importati ${formatted} contatti da ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Impossibile importare ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} non sembra un file ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Attenzione: questo ADIF contiene QSO di ${calls}, ma se continui verranno importati come ${station}.',
			'adifImport.stationCallJoin' => ' e ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('it'))(count, one: '${count} non ha data e non può essere importato', other: '${formatted} non hanno data e non possono essere importati', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Questo file registra un\'attivazione di ${refs}.',
			'adifImport.addActivation' => 'Aggiungila a questa operazione',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Solo ${written} su ${planned} sono stati applicati — il log è cambiato mentre decidevi.',
			'adifImport.busy' => 'È già in corso un\'importazione. Attendi che finisca prima di avviarne un\'altra.',
			'adifImport.oneFileOnly' => 'Trascina un file ADIF alla volta — l\'ordine in cui i file vengono importati decide quali dati prevalgono.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} ha più di ${limit} QSO, il massimo che un\'operazione può importare alla volta.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename} ha più di ${limit} QSO. L\'importazione di un ADIF in un\'operazione serve ad aggiungere pochi QSO, non a caricare un log intero — per quello usa la vista Log. La modalità sviluppatore permette comunque di importarlo, se sei sicuro.',
			'adifImport.importAnyway' => 'Importa comunque',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: connesso',
			'offline.noRoute' => 'Nessuna connessione di rete.',
			'offline.unreachable' => 'La rete è attiva, ma nessun server risponde — spesso è una pagina di accesso rimasta in attesa in un browser.',
			'offline.reachable' => 'Tutti i servizi rispondono come previsto.',
			'offline.whatStops' => 'Ricerche, spot e file di dati sono in pausa. Il logging e la sincronizzazione tra dispositivi peer no.',
			'offline.servicesTitle' => 'Servizi',
			'offline.noServices' => 'Nessun servizio ha ancora risposto.',
			'offline.lastSuccess' => ({required Object when}) => 'Ultima risposta ${when} fa',
			'offline.neverSucceeded' => 'Non ha ancora risposto',
			'offline.nextAttempt' => ({required Object when}) => 'Prossimo tentativo tra ${when}',
			'offline.nextAttemptNow' => 'Prossimo tentativo imminente',
			'offline.retry' => 'Riprova ora',
			'offline.retrying' => 'Tentativo in corso…',
			'offline.retryReached' => 'Di nuovo online.',
			'offline.retryUnreachable' => 'Ancora nessuna risposta.',
			'offline.retryNotAttempted' => 'Niente da inviare al momento.',
			'offline.retryThrottled' => 'Appena tentato — attendi un momento.',
			'offline.retryDisabled' => 'La sincronizzazione è disattivata, quindi non c\'è nulla con cui verificare.',
			'offline.syncService' => 'Sincronizzazione Ham2K LoFi',
			'offline.retryInFlight' => 'Tentativo già in corso — attendi.',
			'exportSettings.defaultsDescription' => 'Impostazioni di base per tutte le esportazioni, con modelli separati di nome file e titolo per le attività con referenze e le altre attività. Ogni tipo di esportazione può fornire i propri valori predefiniti o impostazioni personalizzate.',
			'exportSettings.referenceActivities' => 'Attività con referenze',
			'exportSettings.otherActivities' => 'Altre attività',
			'exportSettings.adifFields' => 'Campi ADIF',
			'exportSettings.loadFailed' => 'Impossibile caricare le impostazioni di esportazione.',
			'exportSettings.retry' => 'Riprova',
			'exportSettings.compactFileNamesDescriptionOn' => 'Nomi di file compatti, come N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Nomi di file descrittivi, come 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Include nomi, indirizzi, email, note e posizioni precise nei file ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Omette nomi, indirizzi, email e note; limita le posizioni a locatori di sei caratteri.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Include le informazioni dei servizi di ricerca nominativi.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Omette le informazioni dei servizi di ricerca nominativi; mantiene i valori inseriti manualmente.',
			'exportSettings.customTemplatesDescriptionOn' => 'I tuoi modelli personalizzati sono attivi e possono essere modificati qui sotto.',
			'exportSettings.customTemplatesDescriptionOff' => 'Sono attivi i modelli predefiniti. I tuoi modelli personalizzati vengono conservati per dopo.',
			'exportSettings.type' => 'Tipo di esportazione',
			'exportSettings.defaults' => 'Predefiniti',
			'exportSettings.includeLookupData' => 'Includi dati di ricerca',
			'exportSettings.customTemplates' => 'Modelli personalizzati',
			'exportSettings.filenameTemplate' => 'Modello del nome file',
			'exportSettings.compactFilenameTemplate' => 'Modello del nome file compatto',
			'exportSettings.titleTemplate' => 'Modello del titolo',
			'exportSettings.adifNotesTemplate' => 'Note ADIF QSO',
			'exportSettings.adifCommentTemplate' => 'Commenti ADIF QSO',
			'exportSettings.adifQslMessageTemplate' => 'Messaggio QSL ADIF',
			'exportSettings.shared' => 'Le impostazioni si applicano a ogni estensione che usa questo tipo di esportazione.',
			'exportSettings.defaultTemplates' => 'Attiva Modelli personalizzati per modificare i modelli di questo tipo.',
			'templateEditor.previewLabel' => 'Anteprima:',
			'templateEditor.reset' => 'Ripristina',
			'templateEditor.docs' => 'Documentazione dei modelli',
			'templateEditor.preview' => 'Anteprima di esempio',
			'templateEditor.reference' => 'Riferimento dei modelli',
			'templateEditor.attributes' => 'Attributi disponibili',
			'templateEditor.filters' => 'Filtri',
			'templateEditor.flowControl' => 'Controllo di flusso',
			'templateEditor.unavailable' => 'L\'anteprima non è disponibile finché le estensioni non sono pronte.',
			'templateEditor.empty' => '(output vuoto)',
			_ => null,
		};
	}
}
