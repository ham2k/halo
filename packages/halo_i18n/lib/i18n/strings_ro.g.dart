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
class TranslationsRo extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsRo({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ro,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ro>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsRo _root = this; // ignore: unused_field

	@override 
	TranslationsRo $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsRo(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ro common = _Translations$common$ro._(_root);
	@override late final _Translations$onboarding$ro onboarding = _Translations$onboarding$ro._(_root);
	@override late final _Translations$startScreen$ro startScreen = _Translations$startScreen$ro._(_root);
	@override late final _Translations$testerOverlay$ro testerOverlay = _Translations$testerOverlay$ro._(_root);
	@override late final _Translations$extensionsPanel$ro extensionsPanel = _Translations$extensionsPanel$ro._(_root);
	@override late final _Translations$home$ro home = _Translations$home$ro._(_root);
	@override late final _Translations$chase$ro chase = _Translations$chase$ro._(_root);
	@override late final _Translations$dialogs$ro dialogs = _Translations$dialogs$ro._(_root);
	@override late final _Translations$operation$ro operation = _Translations$operation$ro._(_root);
	@override late final _Translations$map$ro map = _Translations$map$ro._(_root);
	@override late final _Translations$mapsView$ro mapsView = _Translations$mapsView$ro._(_root);
	@override late final _Translations$activitiesView$ro activitiesView = _Translations$activitiesView$ro._(_root);
	@override late final _Translations$loggingControls$ro loggingControls = _Translations$loggingControls$ro._(_root);
	@override late final _Translations$formChrome$ro formChrome = _Translations$formChrome$ro._(_root);
	@override late final _Translations$qsoEditForm$ro qsoEditForm = _Translations$qsoEditForm$ro._(_root);
	@override late final _Translations$qsoList$ro qsoList = _Translations$qsoList$ro._(_root);
	@override late final _Translations$loggingPanel$ro loggingPanel = _Translations$loggingPanel$ro._(_root);
	@override late final _Translations$callInfo$ro callInfo = _Translations$callInfo$ro._(_root);
	@override late final _Translations$settings$ro settings = _Translations$settings$ro._(_root);
	@override late final _Translations$commands$ro commands = _Translations$commands$ro._(_root);
	@override late final _Translations$commandDialog$ro commandDialog = _Translations$commandDialog$ro._(_root);
	@override late final _Translations$keyboardShortcuts$ro keyboardShortcuts = _Translations$keyboardShortcuts$ro._(_root);
	@override late final _Translations$expiredBuild$ro expiredBuild = _Translations$expiredBuild$ro._(_root);
	@override late final _Translations$staleness$ro staleness = _Translations$staleness$ro._(_root);
	@override late final _Translations$spotting$ro spotting = _Translations$spotting$ro._(_root);
	@override late final _Translations$dataFiles$ro dataFiles = _Translations$dataFiles$ro._(_root);
	@override late final _Translations$updates$ro updates = _Translations$updates$ro._(_root);
	@override late final _Translations$extensionService$ro extensionService = _Translations$extensionService$ro._(_root);
	@override late final _Translations$operationLocationScreen$ro operationLocationScreen = _Translations$operationLocationScreen$ro._(_root);
	@override late final _Translations$versionLabel$ro versionLabel = _Translations$versionLabel$ro._(_root);
	@override late final _Translations$notices$ro notices = _Translations$notices$ro._(_root);
	@override late final _Translations$syncAccount$ro syncAccount = _Translations$syncAccount$ro._(_root);
	@override late final _Translations$deepLink$ro deepLink = _Translations$deepLink$ro._(_root);
	@override late final _Translations$confirmDevice$ro confirmDevice = _Translations$confirmDevice$ro._(_root);
	@override late final _Translations$switchAccounts$ro switchAccounts = _Translations$switchAccounts$ro._(_root);
	@override late final _Translations$qsonImport$ro qsonImport = _Translations$qsonImport$ro._(_root);
	@override late final _Translations$adifImport$ro adifImport = _Translations$adifImport$ro._(_root);
	@override late final _Translations$offline$ro offline = _Translations$offline$ro._(_root);
	@override late final _Translations$exportSettings$ro exportSettings = _Translations$exportSettings$ro._(_root);
	@override late final _Translations$templateEditor$ro templateEditor = _Translations$templateEditor$ro._(_root);
}

// Path: common
class _Translations$common$ro extends Translations$common$en {
	_Translations$common$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get save => 'Salvează';
	@override String get ok => 'OK';
	@override String get cancel => 'Anulare';
	@override String get delete => 'Șterge';
	@override String get create => 'Creează';
	@override String get error => 'Eroare';
	@override String get close => 'Închide';
	@override String get done => 'Gata';
	@override String get callsign => 'Indicativ';
	@override String get clear => 'Golește';
	@override String get dismiss => 'Închide';
	@override String get copyDetails => 'Copiază detaliile';
	@override String get expand => 'Extinde';
	@override String get collapse => 'Restrânge';
}

// Path: onboarding
class _Translations$onboarding$ro extends Translations$onboarding$en {
	_Translations$onboarding$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Bun venit în Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Bun venit în Ham2K Power Logger!';
	@override String get welcomeBody => 'Avem câteva întrebări care ne ajută să ne adaptăm mai bine nevoilor dvs.';
	@override String get skip => 'Omite';
	@override String get kContinue => 'Continuă';
	@override String get back => 'Înapoi';
	@override String get next => 'Următorul';
	@override String get done => 'Gata';
	@override String get callsignTitle => 'Care este indicativul dvs.?';
	@override String get callsignBody => 'Aveți nevoie de o licență de radioamator pentru ca această aplicație să vă fie utilă';
	@override String get callsignLabel => 'Indicativul operatorului';
	@override String get alreadyHaveAccount => 'Aveți deja un cont?';
	@override String get foundSiblingTitle => 'Conectați un cont existent?';
	@override String foundSiblingBody({required Object app}) => 'Am găsit ${app} pe acest dispozitiv. Conectați această aplicație la același cont și indicativul și jurnalele dvs. vor fi preluate.';
	@override String get foundPoloBody => 'Am găsit o versiune mai veche de Ham2K Portable Logger pe acest dispozitiv. Conectați această aplicație la același cont și indicativul și jurnalele dvs. vor fi preluate.';
	@override String get foundSiblingsBody => 'Am găsit alte aplicații Ham2K pe acest dispozitiv. Conectați această aplicație la unul dintre conturile lor și indicativul și jurnalele dvs. vor fi preluate.';
	@override String linkWithApp({required Object app}) => 'Conectare cu ${app}';
	@override String get linkWithPolo => 'Conectare cu contul din versiunea veche';
	@override String get setUpFresh => 'Configurare de la zero';
	@override String get activitiesTitle => 'Activități preferate';
	@override String get activitiesBody => 'Vă interesează vreunul dintre aceste programe de activare populare?';
	@override String get activitiesFooter => '(Găsiți mai multe opțiuni în Setări)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'Sincronizare în cloud';
	@override String get syncBody => 'Ham2K Log Filer păstrează o copie de rezervă a jurnalelor dvs. în cloud și le sincronizează pe toate dispozitivele pe care folosiți aplicații Ham2K.';
	@override String get syncPricing => 'Este gratuit! Dar un abonament plătit îl face mai rapid.';
	@override String get syncLabel => 'Activează sincronizarea în cloud';
	@override String get syncOffWarning => 'ATENȚIE: astfel cresc șansele de a pierde datele operațiunilor, de exemplu dacă dispozitivul se strică sau se pierde.';
	@override String get notNow => 'Nu acum';
	@override String get consentTitle => 'Date și confidențialitate';
	@override String get consentUsageBody => 'Pentru a ne ajuta să îmbunătățim aplicația, am dori să colectăm date despre performanță, blocări și utilizarea aplicației.';
	@override String get consentUsageLabel => 'Partajează datele de utilizare a aplicației';
	@override String get consentOperationBody => 'Unele funcții pot implica partajarea datelor operațiunilor dvs. cu alți utilizatori. Puteți renunța oricând.';
	@override String get consentOperationLabel => 'Partajează datele operațiunilor';
	@override String get finishingSetup => 'Se finalizează configurarea — se descarcă datele de referință…';
}

// Path: startScreen
class _Translations$startScreen$ro extends Translations$startScreen$en {
	_Translations$startScreen$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get credits => 'de către KI2D și prietenii';
}

// Path: testerOverlay
class _Translations$testerOverlay$ro extends Translations$testerOverlay$en {
	_Translations$testerOverlay$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get tape => 'ATENȚIE: ÎN CONSTRUCȚIE';
	@override String get warningTitle => 'Această aplicație este în lucru';
	@override String get warningBody => 'Majoritatea funcțiilor au suprafețe denivelate și peste tot sunt pericole de împiedicare. Verificați regulat dacă există actualizări.';
	@override String whatsNew({required Object build}) => 'Ce este nou în versiunea ${build}';
	@override String get thanks => 'Vă mulțumim că vă puneți jurnalul în pericol pentru a ne ajuta să îmbunătățim această aplicație!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$ro extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Activități';
	@override String get categoryAward => 'Diplome';
	@override String get categoryContest => 'Concursuri';
	@override String get categoryLookup => 'Căutări de indicative';
	@override String get categorySpots => 'Surse de spoturi';
	@override String get categoryDashboard => 'Panouri de bord';
	@override String get categoryOther => 'Alte extensii';
	@override String get searchHint => 'Căutați extensii';
	@override String get applying => 'Se aplică modificările extensiilor, poate dura un moment…';
	@override String get noMatches => 'Nicio extensie nu corespunde căutării';
	@override String get installFromFile => 'Instalare din fișier…';
	@override String installVersion({required Object version}) => 'Versiunea ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'Captura de ecran ${n} din ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'Captura anterioară';
	@override String get nextScreenshot => 'Captura următoare';
	@override String get screenshotUnavailable => 'Captură indisponibilă';
	@override String get canReach => 'Această extensie poate contacta';
	@override String canHoldConnection({required Object host}) => '${host}, printr-o conexiune activă';
	@override String get canHoldLocalConnection => 'Dispozitive din rețeaua dvs. locală, printr-o conexiune activă';
	@override String get canUseLocation => 'Locația dvs.';
	@override String get canReadRadio => 'Stația dvs. radio, pentru a-i citi frecvența și modul';
	@override String get canControlRadio => 'Stația dvs. radio, pentru a o controla și a emite cu ea — acord, putere, CW, memorii vocale și PTT';
	@override String get canCommandRadioRaw => 'Stația dvs. radio, pentru a-i trimite orice comandă în propriul ei protocol — inclusiv comenzi care emit sau îi schimbă setările';
	@override String get canReadCluster => 'Clusterul DX, autentificat ca dvs., pentru a citi ce trimite acesta';
	@override String get canSpotCluster => 'Clusterul DX, autentificat ca dvs., pentru a posta spoturi în numele dvs.';
	@override String get canCommandCluster => 'Clusterul DX, autentificat ca dvs., pentru a-i trimite orice comandă în numele dvs.';
	@override String get canSetUserAgent => 'Se identifică la servere sub propriul nume';
	@override String get canChangeSettings => 'Setările dvs., pentru a le schimba prin comenzile sale: orice setare, modul dezvoltator și experimentele';
	@override String get noCapabilities => 'Nu solicită nimic în afara aplicației.';
	@override String get sandboxNote => 'Extensiile rulează izolat: fără acces la fișierele dvs. și fără rețea în afara celor enumerate aici.';
	@override String get installAction => 'Instalează';
	@override String get updateAction => 'Actualizează';
	@override String get installFailed => 'Extensia nu a putut fi instalată';
	@override String get installedBadge => 'Instalată';
	@override String get uninstallAction => 'Elimină';
	@override String uninstallTitle({required Object name}) => 'Eliminați ${name}?';
	@override String get uninstallBody => 'Această extensie și setările ei vor fi eliminate. Jurnalele dvs. rămân neatinse.';
	@override String installedMessage({required Object name}) => '${name} a fost instalată';
	@override String get installDownloading => 'Se descarcă…';
	@override String get installWaiting => 'Se așteaptă instalarea…';
	@override String get installInstalling => 'Se instalează…';
	@override String get installAwaitingApproval => 'Se așteaptă aprobarea dvs.…';
	@override String installAlreadyRunning({required Object name}) => '${name} se instalează deja.';
	@override String updatedTo({required Object version}) => 'Actualizată la ${version}';
	@override String installIncomplete({required Object name}) => 'Instalarea ${name} nu s-a finalizat. Poate fi necesară reinstalarea.';
	@override String uninstallFailed({required Object name}) => '${name} nu a putut fi eliminată';
	@override String installedFrom({required Object source}) => 'Descărcată de la ${source}';
	@override String get dropHint => 'Plasați aici o extensie .h2kext pentru a o instala';
	@override String get dropOneOnly => 'Plasați câte o singură extensie.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} a returnat ${status} pentru această extensie.';
	@override String get downloadTooLarge => 'Descărcarea este mult prea mare pentru a fi o extensie.';
	@override String get downloadNotSecure => 'Descărcarea a fost redirecționată către o adresă nesigură.';
	@override String get catalogSection => 'Catalog';
	@override String get catalogLoading => 'Se încarcă catalogul…';
	@override String get catalogUnreachable => 'Catalogul nu poate fi accesat';
	@override String get builtIn => 'Integrată';
	@override String get updateAvailableBadge => 'Actualizare disponibilă';
	@override String get updatesAvailableTitle => 'Actualizări de extensii';
	@override String updateAvailableFor({required Object name}) => 'Este disponibilă o actualizare pentru ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} și încă ${count} trebuie actualizate.';
	@override String updatesAvailableFor({required Object names}) => '${names} trebuie actualizate.';
	@override String get pendingUpdatesSection => 'Actualizări în așteptare';
	@override String get updateAllAction => 'Actualizează tot';
	@override String get updatesUnderWay => 'Aceste actualizări sunt deja în curs.';
	@override String get updatesNothingLeft => 'Extensiile dvs. sunt la zi.';
	@override String get updatesNoticeAction => 'Mai multe informații';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Actualizați ${count} extensie?',
		other: 'Actualizați ${count} extensii?',
	);
	@override String get upgradeDoneTitle => 'Extensiile dvs. sunt pregătite';
	@override String get upgradeDoneBody => 'Acum provin din catalogul de extensii Ham2K, deci pot fi actualizate fără a aștepta o nouă versiune a aplicației.';
	@override String upgradeDoneUnserved({required Object names}) => 'Neactualizate: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Nu au pornit: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Sunt încă instalate și marcate în Setări › Extensii — actualizarea lor acolo le va readuce.';
	@override String get upgradeDoneUnservedHint => 'Catalogul nu are înlocuitori direcți pentru acestea, așa că căutați acolo extensii care acoperă ce foloseați.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Evenimente State Parks';
	@override String upgradeDoneMissing({required Object count}) => '${count} dintre extensiile dvs. nu au sosit încă. Vor fi descărcate data viitoare când catalogul de extensii este accesibil.';
	@override String get runtimeDeadBody => 'Extensiile dvs. nu au pornit. Repornirea aplicației ar trebui să le readucă.';
	@override String get refusedTitle => 'Unele extensii nu au pornit';
	@override String get upgradeBusyTitle => 'Configurarea este încă în curs';
	@override String get upgradeRuntimeDeadTitle => 'Extensiile dvs. nu rulează';
	@override String get restoreTitle => 'Unele dintre extensiile dvs. lipsesc';
	@override String get restoreBody => 'Aceste extensii instalate de dvs. nu se află pe acest dispozitiv. Le putem descărca din nou din catalogul de extensii Ham2K:';
	@override String get restoreFromFile => 'Instalate dintr-un fișier. Instalați-le din nou din fișierele lor sau uitați-le:';
	@override String get restoreOtherCatalog => 'Instalate dintr-un alt catalog de extensii, deci nu sunt disponibile aici:';
	@override String get restoreForget => 'Uită';
	@override String get restoreInstall => 'Instalează';
	@override String get restoreLater => 'Mai târziu';
	@override String get restoreInstalling => 'Se instalează extensiile dvs.…';
	@override String get restoreDoneTitle => 'Extensiile dvs. au revenit';
	@override String restoreDoneBody({required Object names}) => 'Reinstalate: ${names}.';
	@override String get restorePartialTitle => 'Unele extensii nu au putut fi instalate';
	@override String restoreFailed({required Object names}) => 'Nu s-au putut instala: ${names}. Vi le vom oferi din nou la următoarea deschidere a aplicației.';
	@override String get restoreBusyBody => 'Aplicația încă vă configurează extensiile. Vi le vom oferi din nou la următoarea deschidere a aplicației.';
	@override String get restoreRuntimeDeadBody => 'Le-am reinstalat, dar extensiile dvs. nu au pornit. Repornirea aplicației ar trebui să le readucă.';
	@override String revokedTitle({required Object name}) => '${name} a fost retrasă';
	@override String get revokedBody => 'Catalogul a retras această versiune, așa că a fost dezactivată.';
	@override String forceDisabledTitle({required Object name}) => '${name} a fost dezactivată';
	@override String get forceDisabledBody => 'Ham2K a dezactivat deocamdată această extensie.';
	@override String replacedTitle({required Object name}) => '${name} a fost înlocuită';
	@override String replacedBody({required Object replacement}) => '${replacement} îi ia locul. Puteți trece la ea din Extensii.';
	@override String replacedBy({required Object name}) => 'Înlocuită de ${name}';
	@override String replacedByInstalled({required Object name}) => 'Înlocuită de ${name}, pe care o aveți deja';
	@override String get replaceAction => 'Înlocuiește';
	@override String replaceInstalledBody({required Object replacement}) => 'Setările ei trec la ${replacement}, pe care o aveți deja. Jurnalele dvs. rămân neatinse.';
	@override String get downloadHashMismatch => 'Descărcarea nu este extensia descrisă de catalog.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Catalogul nu are versiunea ${version} a ${key}.';
	@override String get catalogLinkUnknown => 'Linkul de catalog nu indică o versiune de extensie.';
	@override String catalogNoRelease({required Object key}) => 'Catalogul nu are nicio lansare a ${key} pe acest canal.';
	@override String get installFromLink => 'Instalare din link';
	@override String get unstableReleaseWarning => 'Aceasta este o versiune instabilă, pe care editorul ei nu a declarat-o finalizată. Poate funcționa greșit și va primi în continuare actualizări instabile.';
	@override String get bleedingReleaseWarning => 'Aceasta este o versiune în dezvoltare: lucru în curs care se poate strica sau își poate pierde setările. Va primi în continuare actualizări în dezvoltare.';
	@override String get channelUnstable => 'Instabil';
	@override String get channelBleeding => 'În dezvoltare';
	@override String get followsUnstable => 'Primește versiuni instabile și stabile';
	@override String get followsBleeding => 'Primește versiuni în dezvoltare, instabile și stabile';
	@override String get followStableAction => 'Urmărește doar versiunile stabile';
	@override String get revokedBadge => 'Retrasă';
	@override String get forceDisabledBadge => 'Dezactivată de Ham2K';
	@override String get refusedBadge => 'Nu s-a încărcat';
	@override String get downloadNotHttps => 'Descărcarea nu se face printr-o conexiune securizată.';
	@override String downloadUnreachable({required Object source}) => '${source} nu a putut fi accesat pentru această extensie.';
	@override String get detailsAction => 'Detalii';
	@override String get installedFromFile => 'Instalată dintr-un fișier';
	@override String get detailsWhatItDoes => 'Oferă suport pentru';
	@override String get installedPreloaded => 'Preinstalată';
	@override String get hookAccount => 'Autentificare în cont';
	@override String get hookCallNotes => 'Note de indicativ';
	@override String get hookDataFile => 'Date offline';
	@override String get hookExport => 'Export';
	@override String get hookLookup => 'Căutări de indicative';
	@override String get hookScoring => 'Punctaj';
	@override String get hookSpots => 'Spoturi';
	@override String hookHunting({required Object program}) => 'Vânătoare ${program}';
	@override String hookActivating({required Object program}) => 'Activare ${program}';
	@override String get suggestedSection => 'Sugerate';
	@override String moreAvailableSection({required Object count}) => 'Mai multe disponibile (${count})';
}

// Path: home
class _Translations$home$ro extends Translations$home$en {
	_Translations$home$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jurnal Portabil';
	@override String get newOperation => 'Operațiune nouă';
	@override String get stationCallsign => 'Indicativul stației';
	@override String get titleOptional => 'Titlu (opțional)';
	@override String get emptyList => 'Nicio operațiune încă. Creați una pentru a începe să înregistrați.';
	@override String get quickLookup => 'Căutare rapidă';
	@override late final _Translations$home$nav$ro nav = _Translations$home$nav$ro._(_root);
	@override late final _Translations$home$panels$ro panels = _Translations$home$panels$ro._(_root);
	@override String get toggleNav => 'Afișează sau ascunde etichetele de navigare';
	@override late final _Translations$home$logs$ro logs = _Translations$home$logs$ro._(_root);
}

// Path: chase
class _Translations$chase$ro extends Translations$chase$en {
	_Translations$chase$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'vânătoare';
	@override String goalsTwo({required Object first, required Object second}) => '${first} și ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} și altele';
	@override late final _Translations$chase$station$ro station = _Translations$chase$station$ro._(_root);
	@override late final _Translations$chase$periodInline$ro periodInline = _Translations$chase$periodInline$ro._(_root);
	@override late final _Translations$chase$periodStats$ro periodStats = _Translations$chase$periodStats$ro._(_root);
	@override late final _Translations$chase$period$ro period = _Translations$chase$period$ro._(_root);
	@override late final _Translations$chase$goals$ro goals = _Translations$chase$goals$ro._(_root);
	@override late final _Translations$chase$panels$ro panels = _Translations$chase$panels$ro._(_root);
	@override late final _Translations$chase$claims$ro claims = _Translations$chase$claims$ro._(_root);
	@override late final _Translations$chase$notice$ro notice = _Translations$chase$notice$ro._(_root);
	@override late final _Translations$chase$alerts$ro alerts = _Translations$chase$alerts$ro._(_root);
	@override String get checklists => 'Progres vânătoare';
	@override late final _Translations$chase$imports$ro imports = _Translations$chase$imports$ro._(_root);
}

// Path: dialogs
class _Translations$dialogs$ro extends Translations$dialogs$en {
	_Translations$dialogs$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Detalii operațiune';
	@override String get activities => 'Activități';
	@override String get stationCallsign => 'Indicativul stației';
	@override String get advanced => 'Avansat';
	@override String get operatingPosition => 'Poziție de operare (multi-stație)';
	@override String get assistance => 'Asistență';
	@override String get assistanceDescription => 'Folosește servicii de spotare și alte surse de informații';
	@override String get selfSpotting => 'Auto-spotare';
	@override String get selfSpottingDescription => 'Permite funcțiile care raportează propria dvs. frecvență';
	@override String disabledByRules({required Object rules}) => 'Dezactivat pentru a respecta regulile ${rules}';
	@override late final _Translations$dialogs$lookupDespiteAssistance$ro lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$ro._(_root);
	@override String get notes => 'Notițe';
	@override String get deleteOperationTitle => 'Șterge operațiunea';
	@override String get purgeTestsTitle => 'Elimină operațiunile de test';
	@override String get purgeTestsBody => 'Aceasta șterge definitiv aceste operațiuni de test și QSO-urile lor. Acțiunea nu poate fi anulată.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Plus ${count} contact de test care nu aparține niciunei operațiuni.',
		other: 'Plus ${count} contacte de test care nu aparțin niciunei operațiuni.',
	);
	@override String get purgeTestsAction => 'Elimină';
	@override String get syncAllTitle => 'Înlocuiți jurnalul acestui dispozitiv?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL salvează și șterge ${qsos} de pe acest dispozitiv, apoi descarcă din nou jurnalul contului de pe server. Copia de rezervă rămâne în baza de date a acestui dispozitiv.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${n} QSO nu a fost încă sincronizat — serverul nu l-a primit niciodată și NU va mai reveni.',
		other: '${n} QSO-uri nu au fost încă sincronizate — serverul nu le-a primit niciodată și NU vor mai reveni.',
	);
	@override String get syncAllAction => 'Șterge și resincronizează';
	@override String get receivedPurgesTitle => 'Operațiuni de test eliminate în altă parte';
	@override String get receivedPurgesBody => 'Acestea au fost șterse ca operațiuni de test pe alt dispozitiv. Le eliminați și aici? Aceasta le șterge definitiv, împreună cu QSO-urile lor, și nu poate fi anulată.';
	@override String get receivedPurgesAction => 'Elimină';
	@override late final _Translations$dialogs$callChange$ro callChange = _Translations$dialogs$callChange$ro._(_root);
}

// Path: operation
class _Translations$operation$ro extends Translations$operation$en {
	_Translations$operation$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Această operațiune este ștearsă. Restaurați-o pentru a înregistra sau a face modificări.';
	@override late final _Translations$operation$tabs$ro tabs = _Translations$operation$tabs$ro._(_root);
	@override late final _Translations$operation$positions$ro positions = _Translations$operation$positions$ro._(_root);
	@override String get stationCallsignNone => 'Fără indicativ de stație';
	@override String get titleNone => 'Fără titlu';
	@override String get deleteOperation => 'Șterge operațiunea';
	@override String get loggingControlsStale => 'Câmpurile activităților pot fi neactualizate — redeschideți operațiunea pentru a le reîmprospăta';
	@override String get locationNone => 'Nesetată';
	@override String get generalOperation => 'Operațiune generală';
	@override String titleFor({required Object value}) => 'pentru ${value}';
	@override String titleAt({required Object value}) => 'la ${value}';
	@override String segmentNow({required Object description}) => 'Acum ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$ro menu = _Translations$operation$menu$ro._(_root);
	@override late final _Translations$operation$layout$ro layout = _Translations$operation$layout$ro._(_root);
	@override late final _Translations$operation$export$ro export = _Translations$operation$export$ro._(_root);
	@override late final _Translations$operation$spots$ro spots = _Translations$operation$spots$ro._(_root);
	@override late final _Translations$operation$import$ro import = _Translations$operation$import$ro._(_root);
}

// Path: map
class _Translations$map$ro extends Translations$map$en {
	_Translations$map$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$ro outlineIssue = _Translations$map$outlineIssue$ro._(_root);
	@override String get outlinesDisclaimer => 'Contururile sunt doar orientative. Verificați și singuri!';
	@override String outlinesCredit({required Object sources}) => 'Contururi: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Limite: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Facilități: ${sources}';
	@override String get fullCredits => 'Toate sursele datelor';
	@override String get fewerCredits => 'Mai puține surse';
	@override String get emptyState => 'Nicio locație de QSO încă.\nQSO-urile cu grilă, stat sau țară vor apărea aici.';
	@override String get unavailable => 'Harta nu este disponibilă acum.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plană';
	@override String get globe => 'Glob';
	@override String get zoomIn => 'Mărire';
	@override String get zoomOut => 'Micșorare';
	@override String get resetNorth => 'Orientează cu nordul în sus';
	@override late final _Translations$map$postcard$ro postcard = _Translations$map$postcard$ro._(_root);
}

// Path: mapsView
class _Translations$mapsView$ro extends Translations$mapsView$en {
	_Translations$mapsView$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hărți';
	@override String get searchHint => 'Căutați parcuri, vârfuri și altele';
	@override String get activities => 'Activități';
	@override String get layers => 'Straturi';
	@override String get baseMap => 'Hartă de bază';
	@override String get satellite => 'Satelit (Esri)';
	@override String get facilities => 'Facilitățile parcurilor';
	@override String get boundaries => 'Limite';
	@override String get currentLocation => 'Locația actuală';
	@override String noMatches({required Object text}) => 'Nimic nu corespunde cu „${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} referință la ${where}',
		other: '${count} referințe la ${where}',
	);
	@override String get startOperation => 'Porniți o operațiune cu aceste referințe';
}

// Path: activitiesView
class _Translations$activitiesView$ro extends Translations$activitiesView$en {
	_Translations$activitiesView$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activități';
	@override String get activitiesCountZero => 'Nicio activitate selectată';
	@override String get activitiesCountOne => '1 activitate';
	@override String activitiesCountOther({required Object count}) => '${count} activități';
	@override String get empty => 'Nicio activitate încă — folosiți Sugestii și căutare de mai jos pentru a adăuga una';
	@override String get removeActivity => 'Elimină';
	@override String openReferenceLink({required Object name}) => 'Deschide ${name}';
	@override String get editActivity => 'Editează activitatea';
	@override String get manageExtensions => 'Gestionează extensiile';
	@override String get manage => 'Gestionează';
	@override String activitiesTitle1({required Object first}) => 'Tipuri de activitate: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipuri de activitate: ${first} și ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipuri de activitate: ${first}, ${second} și încă ${more}';
	@override String get reference => 'Referință';
	@override String get invalidReference => 'Invalidă';
	@override String get duplicateReference => 'Deja adăugată';
	@override String get searchHint => 'Căutați după nume, referință sau orice altceva…';
	@override String get noSuggestions => 'Nicio potrivire';
	@override String get noSuggestionsHint => 'Căutați mai sus după numele sau numărul referinței';
	@override String get noSuggestionsExample => '(de exemplu „trail” sau „4556”)';
	@override String get allOptions => 'Tipuri de activitate';
	@override String get determiningLocation => 'Se determină locația curentă…\nSe așteaptă semnalul GPS pentru a găsi referințe din apropiere';
	@override String get locationUnavailableTitle => 'Datele de locație nu sunt disponibile';
	@override String get locationDeniedTitle => 'Permisiunea de locație a fost refuzată';
	@override String get locationBlockedTitle => 'Permisiunea de locație este blocată';
	@override String get noNearbyReason => 'Nu se pot determina referințele din apropiere';
	@override String locationManualHint({required Object icon}) => 'Atingeți ${icon} pentru a introduce manual locația,\nsau căutați referințe după nume';
	@override String get locationGrantAction => 'Permite accesul la locație';
	@override String get locationSettingsAction => 'Deschide Setări';
	@override String get locationSettingsUnavailable => 'Permiteți accesul la locație din setările sistemului';
	@override String get locationGrantRefused => 'Tot nicio locație — sistemul a refuzat din nou';
	@override String get searchUnavailableTitle => 'Căutarea de activități nu este disponibilă';
	@override String get searchUnavailableReason => 'O extensie de activitate nu a putut răspunde la căutare. Încercați din nou peste un moment.';
	@override String get emptySheet => 'Folosiți sugestiile și căutarea de mai jos pentru a adăuga una';
	@override String get exports => 'Exporturi';
	@override String get exportLogs => 'Exportă jurnalele';
	@override String get tools => 'Instrumente';
	@override String get toolsTitle => 'Instrumente operațiune';
	@override String get operationDetails => 'Detalii operațiune';
	@override String get share => 'Partajează';
	@override String get archive => 'Arhivează';
	@override String get deleteOperation => 'Șterge operațiunea';
	@override String get undeleteOperation => 'Restaurează operațiunea';
	@override String get alreadySelected => 'Deja selectată';
	@override String get selected => 'Selectată';
	@override String pickPosition({required Object index, required Object count}) => '${index} din ${count}';
	@override String get previousPick => 'Potrivirea anterioară';
	@override String get nextPick => 'Potrivirea următoare';
	@override String get retiredReference => 'Retrasă';
	@override String enableExtension({required Object name}) => 'Activează ${name}';
	@override String get enableExtensionHint => 'Această extensie corespunde căutării, dar nu este activată acum';
	@override String get enableExtensionForRefHint => 'Această extensie gestionează una dintre referințele acestei operațiuni, dar nu este activată acum';
	@override String extensionNotRunning({required Object name}) => '${name} nu rulează';
	@override String get extensionNotRunningHint => 'Această extensie a fost dezactivată, deschideți Setări extensii pentru mai multe informații';
	@override String installExtension({required Object name}) => 'Instalează ${name}';
	@override String get installExtensionHint => 'Această extensie corespunde căutării, dar nu este instalată';
	@override String get onlyCatalogMatches => 'Nicio potrivire\nUnele extensii din catalog ar putea avea rezultate.\nInstalați-le din Tipuri de activitate de mai jos.';
	@override String get setupUnavailable => 'Configurarea acestei activități nu a putut fi încărcată — încercați din nou din Gestionează';
	@override String get controlsUnavailableTitle => 'Controalele activității nu sunt disponibile';
	@override String get controlsUnavailableReason => 'Referințele dvs. sunt în siguranță, dar editarea lor nu este disponibilă acum.';
	@override String get controlsUnavailableRetry => 'Reîncearcă';
	@override String get onlyDisabledMatches => 'Nicio potrivire\nUnele extensii disponibile ar putea avea rezultate.\nActivați-le din Tipuri de activitate de mai jos.';
	@override String get onlyNotRunningMatches => 'Nicio potrivire\nUnele extensii care ar putea avea rezultate nu rulează.\nVedeți Tipuri de activitate de mai jos.';
	@override String get mapToggle => 'Hartă';
	@override String get searchToggle => 'Căutare';
	@override String get addToOperation => 'Adaugă la operațiune';
	@override String get addToOperationShort => 'Adaugă la op.';
	@override String get mapEmptyState => 'Niciun rezultat de afișat pe hartă';
	@override String get mapEmptyStateHint => 'Reveniți la listă sau căutați altceva';
	@override String get imports => 'Importuri';
}

// Path: loggingControls
class _Translations$loggingControls$ro extends Translations$loggingControls$en {
	_Translations$loggingControls$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Ora (UTC)';
	@override String get date => 'Dată';
	@override String get now => 'Acum';
	@override String get manualTimeSettings => 'Oră manuală';
	@override String get manualTimeIncrement => 'Increment per QSO';
	@override String get manualTimeIncrementNone => 'Niciunul';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} minut',
		other: '${count} minute',
	);
	@override String get frequency => 'Frecvență';
	@override String get mode => 'Mod';
	@override String get theirCall => 'Interlocutor';
	@override String get noteField => 'Notiță';
	@override String get todoField => 'De făcut';
	@override String get sent => 'Trimis';
	@override String get rcvd => 'Primit';
	@override String get more => 'Mai multe';
	@override String get revert => 'Anulează';
	@override String get undoDelete => 'Anulează ștergerea';
	@override String get restore => 'Restaurează';
	@override String get wipe => 'Golește';
	@override String get undo => 'Anulează';
	@override String get pendingDeleteTapWarning => 'Atingeți coșul încă o dată pentru a șterge acest QSO';
	@override String get pendingDeleteClickWarning => 'Faceți clic pe coș încă o dată pentru a șterge acest QSO';
	@override String get deletedQsoWarning => 'QSO șters';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Atingeți coșul încă o dată pentru a șterge acest ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Faceți clic pe coș încă o dată pentru a șterge acest ${kind}';
	@override String deletedEventWarning({required Object kind}) => '${kind} șters';
	@override String get timeControl => 'Ora';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Putere';
	@override String get notesControl => 'Notițe';
	@override String get power => 'Putere';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controale de înregistrare';
	@override String get spottingControl => 'Spotare';
	@override String get spottingSelfControl => 'Auto-spotare';
	@override String spotSelfAt({required Object freq}) => 'Auto-spotare la ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} la ${freq}';
	@override String spotTooLate({required Object call}) => 'Prea târziu pentru a spota ${call}';
	@override String get spotNoFreq => 'Mai întâi setați o frecvență pentru spotare';
	@override String get selfSpotDisabled => 'Auto-spotare dezactivată';
	@override String get spotComment => 'Comentariu';
	@override String get spottingAutoControl => 'Auto-respotare';
	@override String spotAutoEvery({required Object minutes}) => 'Respotare la fiecare ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'Auto în ${time}. Opriți?';
	@override String spotAutoInMinutes({required Object minutes}) => 'Auto în ${minutes}m';
	@override String spotAutoInSeconds({required Object seconds}) => 'Auto în ${seconds}s';
	@override String spotAutoInCount({required Object seconds}) => 'Auto în ${seconds}';
	@override String get spotAutoNotStarted => 'Auto-respotarea nu a pornit: spotul nu a trecut';
	@override String get spotAutoMoved => 'Auto-respotarea nu a pornit: frecvența s-a schimbat în timpul spotării';
	@override String get spotAutoStopped => 'Auto-respotarea s-a oprit';
	@override String get spotAutoLeftFreq => 'Auto-respotarea s-a oprit: frecvența s-a schimbat';
	@override String get spotAutoNoFreq => 'Auto-respotarea s-a oprit: stația radio nu raportează nicio frecvență';
	@override String get spotBusy => 'Un alt spot este încă în curs de trimitere';
	@override String get bandOrFreqRequired => 'Setați o frecvență sau o bandă înainte de înregistrare';
	@override String get missingBand => 'Fără bandă';
	@override String get missingMode => 'Fără mod';
	@override String saveFailed({required Object error}) => 'Nu s-a putut salva: ${error}';
	@override String deleteFailed({required Object error}) => 'Nu s-a putut șterge: ${error}';
	@override late final _Translations$loggingControls$info$ro info = _Translations$loggingControls$info$ro._(_root);
}

// Path: formChrome
class _Translations$formChrome$ro extends Translations$formChrome$en {
	_Translations$formChrome$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(fără titlu)';
	@override String get showMore => 'Arată mai multe';
	@override String get showAll => 'Afișează tot';
	@override String get showFewer => 'Arată mai puține';
	@override String get defaults => 'Setări implicite';
	@override String get search => 'Căutare';
	@override String get clear => 'Golește';
	@override String get openPage => 'Deschide pagina';
	@override String get connected => 'Conectat';
	@override String get notConnected => 'Neconectat';
	@override String get manage => 'Gestionează';
	@override String get connect => 'Conectează';
	@override String get formTitle => 'Formular';
	@override String addItem({required Object label}) => 'Adaugă ${label}';
	@override String editItem({required Object label}) => 'Editează ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Se afișează ${shown} din ${total} (${selected} selectate)';
	@override String validationError({required Object error}) => 'Eroare de validare: ${error}';
	@override String transformationError({required Object error}) => 'Eroare de transformare: ${error}';
	@override String actionError({required Object error}) => 'Eroare: ${error}';
	@override String get removeItem => 'Șterge';
	@override String deleteItemTitle({required Object name}) => 'Ștergeți ${name}?';
	@override String get storageUnavailable => 'Autentificări indisponibile';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$ro extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editează QSO';
	@override String get operatorCall => 'Operator';
	@override String get position => 'Poziție';
	@override String get theirName => 'Nume';
	@override String get theirGrid => 'Grilă';
	@override String get theirState => 'Stat';
	@override String get band => 'Bandă';
	@override String get notes => 'Notițe';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Informațiile interlocutorului';
	@override String get sectionOur => 'Informațiile noastre';
	@override String get sectionNotes => 'Notițe';
	@override String get theirCity => 'Oraș';
	@override String get theirCounty => 'Județ';
	@override String get theirEntity => 'Entitate';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Secțiune ARRL';
	@override String get theirLat => 'Latitudine';
	@override String get theirLon => 'Longitudine';
	@override String get theirPower => 'Puterea lor';
}

// Path: qsoList
class _Translations$qsoList$ro extends Translations$qsoList$en {
	_Translations$qsoList$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Niciun QSO încă — lucrați pe cineva!';
	@override String get bandOrModeWarning => 'Verificați dacă banda și modul sunt corecte';
	@override String get today => 'Astăzi';
	@override String get yesterday => 'Ieri';
	@override String get tomorrow => 'Mâine';
	@override late final _Translations$qsoList$find$ro find = _Translations$qsoList$find$ro._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$ro extends Translations$loggingPanel$en {
	_Translations$loggingPanel$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Statistici operațiune';
	@override String get scoring => 'Punctaj';
	@override String get dxccEntities => 'Entități DXCC';
	@override String get statesWorked => 'State';
	@override String get provincesWorked => 'Provincii';
	@override String get duplicates => 'Duplicate';
}

// Path: callInfo
class _Translations$callInfo$ro extends Translations$callInfo$en {
	_Translations$callInfo$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Arată imaginea';
	@override String get imageUnavailable => 'Fotografie indisponibilă';
	@override String get photo => 'Fotografie';
	@override String get notes => 'Notițe';
	@override String distanceTo({required Object distance}) => '${distance} până la';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) până la';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) până la';
	@override String distanceAway({required Object distance}) => 'la ${distance} depărtare';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'la ${distance} (${bearing}°) depărtare';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'la ${distance} (${bearing}° / ${reverse}°) depărtare';
	@override String get thisOpCountOne => '1 QSO în această operațiune';
	@override String thisOpCountOther({required Object count}) => '${count} QSO-uri în această operațiune';
	@override String get otherOpsCountOne => '1 QSO în alte operațiuni';
	@override String otherOpsCountOther({required Object count}) => '${count} QSO-uri în alte operațiuni';
	@override String andMore({required Object count}) => '… și încă ${count}';
	@override String withCall({required Object call}) => 'cu ${call}';
	@override String fromOperation({required Object where}) => 'din ${where}';
	@override late final _Translations$callInfo$history$ro history = _Translations$callInfo$history$ro._(_root);
}

// Path: settings
class _Translations$settings$ro extends Translations$settings$en {
	_Translations$settings$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Setări';
	@override String get language => 'Limbă';
	@override String languageSystem({required Object language}) => 'Urmează setările sistemului (${language})';
	@override late final _Translations$settings$theme$ro theme = _Translations$settings$theme$ro._(_root);
	@override late final _Translations$settings$themeDescription$ro themeDescription = _Translations$settings$themeDescription$ro._(_root);
	@override String get fontScale => 'Scară fonturi';
	@override late final _Translations$settings$fontScaleOpts$ro fontScaleOpts = _Translations$settings$fontScaleOpts$ro._(_root);
	@override late final _Translations$settings$keepDeviceAwake$ro keepDeviceAwake = _Translations$settings$keepDeviceAwake$ro._(_root);
	@override String get layoutDensity => 'Densitatea aranjamentului';
	@override late final _Translations$settings$layoutDensityOpts$ro layoutDensityOpts = _Translations$settings$layoutDensityOpts$ro._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'fereastra este prea scundă, se folosește ${effective}';
	@override String get layoutDensityAtLimit => 'la limită';
	@override String get distanceUnits => 'Unități de distanță';
	@override late final _Translations$settings$distanceUnitsOpts$ro distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$ro._(_root);
	@override String get userInterface => 'Interfață';
	@override late final _Translations$settings$logging$ro logging = _Translations$settings$logging$ro._(_root);
	@override late final _Translations$settings$catServer$ro catServer = _Translations$settings$catServer$ro._(_root);
	@override late final _Translations$settings$cluster$ro cluster = _Translations$settings$cluster$ro._(_root);
	@override late final _Translations$settings$spotting$ro spotting = _Translations$settings$spotting$ro._(_root);
	@override late final _Translations$settings$radio$ro radio = _Translations$settings$radio$ro._(_root);
	@override late final _Translations$settings$help$ro help = _Translations$settings$help$ro._(_root);
	@override late final _Translations$settings$exports$ro exports = _Translations$settings$exports$ro._(_root);
	@override late final _Translations$settings$extensionSections$ro extensionSections = _Translations$settings$extensionSections$ro._(_root);
	@override late final _Translations$settings$map$ro map = _Translations$settings$map$ro._(_root);
	@override late final _Translations$settings$privacy$ro privacy = _Translations$settings$privacy$ro._(_root);
	@override String get operatorCall => 'Indicativul operatorului';
	@override late final _Translations$settings$sync$ro sync = _Translations$settings$sync$ro._(_root);
	@override late final _Translations$settings$peers$ro peers = _Translations$settings$peers$ro._(_root);
	@override String get developerMode => 'Mod dezvoltator';
	@override late final _Translations$settings$syncPanel$ro syncPanel = _Translations$settings$syncPanel$ro._(_root);
	@override late final _Translations$settings$accounts$ro accounts = _Translations$settings$accounts$ro._(_root);
	@override late final _Translations$settings$station$ro station = _Translations$settings$station$ro._(_root);
	@override late final _Translations$settings$offlineData$ro offlineData = _Translations$settings$offlineData$ro._(_root);
	@override late final _Translations$settings$profiles$ro profiles = _Translations$settings$profiles$ro._(_root);
	@override late final _Translations$settings$search$ro search = _Translations$settings$search$ro._(_root);
	@override late final _Translations$settings$developer$ro developer = _Translations$settings$developer$ro._(_root);
	@override late final _Translations$settings$about$ro about = _Translations$settings$about$ro._(_root);
	@override late final _Translations$settings$panels$ro panels = _Translations$settings$panels$ro._(_root);
	@override String get showMoreSettings => 'Afișează mai multe setări';
	@override String get gridPrecision => 'Precizia grilei';
	@override late final _Translations$settings$gridPrecisionOpts$ro gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$ro._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$ro gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$ro._(_root);
}

// Path: commands
class _Translations$commands$ro extends Translations$commands$en {
	_Translations$commands$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Activați mai întâi sincronizarea în Setări.';
	@override String get fullResyncStarted => 'Resincronizarea completă a început — mai întâi s-a făcut o copie de rezervă a datelor locale.';
	@override String noDataFilesMatched({required Object target}) => 'Niciun fișier de date nu corespunde cu „${target}”.';
	@override String reloadFailed({required Object error}) => 'Reîncărcarea a eșuat: ${error}';
	@override String get reloadingAll => 'Se reîncarcă toate fișierele de date…';
	@override String reloadingTarget({required Object target}) => 'Se reîncarcă fișierele de date ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experiment necunoscut „${token}”';
	@override String experimentEnabled({required Object name}) => '${name} activat';
	@override String experimentDisabled({required Object name}) => '${name} dezactivat';
	@override String get sentryTestSent => 'Raportul de eroare de test a fost trimis la Sentry';
	@override String get idleMetricsEnabled => 'Metricile de inactivitate sunt activate în bara de stare';
	@override String get idleMetricsDisabled => 'Metricile de inactivitate sunt dezactivate';
	@override String get sentryTestLocalOnly => 'Sentry este dezactivat în această versiune — eroarea de test a fost înregistrată doar local';
	@override String get noOperationOpen => 'Această comandă necesită o operațiune deschisă';
	@override String unknownSegmentKind({required Object kind}) => 'Nu se știe cum se marchează „${kind}”';
	@override String goUnavailable({required Object place}) => 'Funcția ${place} nu este activată în această aplicație';
	@override String goUnknown({required Object to}) => 'Nu se știe cum se ajunge la „${to}”';
	@override String get goBlocked => 'Închideți mai întâi dialogul deschis';
	@override String get operationAlreadyStarted => 'Această operațiune are deja un marcaj de început';
	@override String get couldNotOpenLocation => 'Pauza a fost adăugată, dar ecranul de locație nu a putut fi deschis';
	@override String get noTestOperations => 'Nicio operațiune de test de eliminat';
	@override String get purgeTestsUnavailable => 'PURGETESTS trebuie să afișeze un dialog de confirmare, care nu este disponibil aici';
	@override String get syncAllUnavailable => 'SYNCALL trebuie să afișeze un dialog de confirmare, care nu este disponibil aici';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'A fost eliminată ${count} operațiune de test',
		other: 'Au fost eliminate ${count} operațiuni de test',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Au fost eliminate ${purged} din ${total} operațiuni de test — restul au eșuat; încercați din nou PURGETESTS';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'A fost eliminat ${count} contact de test fără operațiune',
		other: 'Au fost eliminate ${count} contacte de test fără operațiune',
	);
	@override String get purgeTestsContactsFailed => 'Operațiunile de test au fost eliminate, dar contactele de test fără operațiune au eșuat; încercați din nou PURGETESTS';
	@override String get purgeTestsNothingToDo => 'Nu a fost eliminat nimic';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Au fost eliminate ${removed} din ${total} operațiuni de test — restul au eșuat; încercați din nou Revizuiește';
	@override String get receivedPurgesFailed => 'Acele operațiuni de test nu au putut fi eliminate — încercați din nou Revizuiește';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} operațiune de test a fost eliminată pe alt dispozitiv',
		other: '${count} operațiuni de test au fost eliminate pe alt dispozitiv',
	);
	@override String get receivedPurgesReview => 'Revizuiește';
	@override String get settingOn => 'Pornit';
	@override String get settingOff => 'Oprit';
	@override String get settingEmpty => '(gol)';
	@override String get settingSecretSet => '(setat)';
	@override String get settingSecretUnset => '(nesetat)';
	@override String settingSelectedCount({required Object count}) => '${count} selectate';
	@override String get settingExpectsOnOff => 'pornit sau oprit';
	@override String settingExpectsOneOf({required Object choices}) => 'una dintre: ${choices}';
	@override String get settingExpectsNumber => 'un număr';
	@override String settingVanished({required Object label}) => '„${label}” nu mai este disponibil';
	@override String get noCwKeyer => 'Nicio stație radio conectată nu poate manipula CW';
	@override String get noKeyer => 'Nicio stație radio conectată nu poate manipula CW sau reda memorii vocale';
	@override String get keyerNeedsOperation => 'Deschideți o operațiune pentru a folosi keyer-ul CW';
	@override String get keyerExperimentOff => 'Manipularea CW este oprită — activați-o cu EXP KEYER';
	@override String get esmExperimentOff => '„Enter trimite mesaje” este oprit — activați-l cu EXP ESM';
	@override String cwSending({required Object text}) => 'Se transmite CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Mesaj CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'Mesajul CW F${n} nu a fost trimis: extensiile nu sunt pregătite';
	@override String voiceMessageError({required Object n, required Object error}) => 'Mesaj fonie M${n}: ${error}';
	@override String get voiceMessageNotRendered => 'extensiile nu sunt pregătite';
	@override String so2rRadioCannotKey({required Object radio}) => 'Nu s-a trimis nimic: Radio ${radio} nu poate transmite asta';
	@override String get so2rNoRadioB => 'Nu s-a trimis nimic: alegeți un Radio B în Configurația stației pentru a transmite din acest set';
	@override String settingNotStored({required Object label}) => '„${label}” nu a acceptat această valoare';
}

// Path: commandDialog
class _Translations$commandDialog$ro extends Translations$commandDialog$en {
	_Translations$commandDialog$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Căutați indicative sau tastați o comandă';
	@override String noResults({required Object text}) => 'Nimic nu corespunde cu „${text}”';
	@override String get sectionCommands => 'Comenzi';
	@override String get sectionGoTo => 'Mergi la';
	@override String get sectionOperations => 'Operațiuni';
	@override String get goHome => 'Acasă';
	@override String get goSettings => 'Setări';
	@override String get goNewOperation => 'Operațiune nouă';
	@override String runTyped({required Object text}) => 'Rulează „${text}”';
	@override String get sectionSuggestions => 'Încercați';
	@override String get lookingUp => 'Se caută indicativul…';
	@override String get blockedByPane => 'Comenzile nu pot fi folosite cât timp un panou sau un dialog este deschis';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$ro extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Scurtături de tastatură';
	@override String get description => 'Personalizați asocierile tastelor';
	@override String get search => 'Căutați comenzi și taste';
	@override String get import => 'Importă…';
	@override String get export => 'Exportă…';
	@override String get resetAll => 'Resetează tot';
	@override String get resetAllTitle => 'Resetați toate scurtăturile?';
	@override String get resetAllBody => 'Fiecare comandă revine la tastele ei implicite, iar tastele asociate comenzilor tastate sunt eliminate.';
	@override String get reset => 'Resetează';
	@override String get noKey => 'Nicio tastă';
	@override String get changed => 'Modificat';
	@override String conflict({required Object keys, required Object commands}) => '${keys} este asociată și cu ${commands}';
	@override String get groupApp => 'Aplicație';
	@override String get groupKeying => 'Manipulare';
	@override String get groupLogging => 'Înregistrare';
	@override String get groupCommands => 'Comenzi';
	@override String get groupFixed => 'Taste fixe';
	@override String get contextApp => 'Oriunde';
	@override String get contextLogView => 'Vizualizările Operațiune, Vânătoare și Jurnale';
	@override String get contextOperation => 'Vizualizarea Operațiune, la manipularea unei stații radio prin CAT';
	@override String get contextLogging => 'În panoul de înregistrare';
	@override String get addCommand => 'Adaugă o comandă…';
	@override String unknownCommand({required Object command}) => 'Comandă necunoscută: ${command}';
	@override late final _Translations$keyboardShortcuts$command$ro command = _Translations$keyboardShortcuts$command$ro._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$ro fixed = _Translations$keyboardShortcuts$fixed$ro._(_root);
	@override late final _Translations$keyboardShortcuts$editor$ro editor = _Translations$keyboardShortcuts$editor$ro._(_root);
	@override late final _Translations$keyboardShortcuts$file$ro file = _Translations$keyboardShortcuts$file$ro._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$ro modifier = _Translations$keyboardShortcuts$modifier$ro._(_root);
	@override late final _Translations$keyboardShortcuts$platform$ro platform = _Translations$keyboardShortcuts$platform$ro._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$ro extends Translations$expiredBuild$en {
	_Translations$expiredBuild$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Această versiune a expirat';
	@override String get body => 'Vizitați ham2k.com și obțineți o versiune mai nouă.';
	@override String get visit => 'Vizitează ham2k.com';
	@override String get dismiss => 'Continuă oricum';
}

// Path: staleness
class _Translations$staleness$ro extends Translations$staleness$en {
	_Translations$staleness$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'O actualizare importantă așteaptă';
	@override String get codePushFloorBody => 'Această versiune are o remediere pe care nu o aveți încă.';
	@override String get restartToApply => 'Reporniți aplicația pentru a o aplica.';
	@override String get quitAndReopen => 'Ieșiți din aplicație și deschideți-o din nou pentru a o aplica.';
	@override String get reopenToApply => 'Închideți aplicația și deschideți-o din nou pentru a o aplica.';
	@override String get ignoreForNow => 'Ignoră deocamdată';
}

// Path: spotting
class _Translations$spotting$ro extends Translations$spotting$en {
	_Translations$spotting$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Niciun QSO înregistrat încă pentru spotare.';
	@override String get setFrequencyFirst => 'Setați mai întâi o frecvență.';
	@override String get nothingToSpot => 'Nimic de spotat — nicio extensie nu oferă spotare aici.';
	@override String get incompleteCall => 'Nu se poate spota un indicativ incomplet — completați mai întâi indicativul.';
	@override String spotFailed({required Object source, required Object message}) => '${source} a eșuat: ${message}';
	@override String get unknownError => 'eroare necunoscută';
	@override String get notSent => 'Spotul nu a fost trimis.';
	@override String get allSkipped => 'Spotul nu a fost trimis: toate sursele de spoturi l-au omis.';
	@override String get notRefreshedOffline => 'Fără conexiune — spoturile nu au fost reîmprospătate';
}

// Path: dataFiles
class _Translations$dataFiles$ro extends Translations$dataFiles$en {
	_Translations$dataFiles$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Se descarcă…';
	@override String downloadFailedTitle({required Object name}) => '${name} nu a putut fi descărcat';
	@override String get downloadFailedWebHint => 'Poate fi o problemă de rețea sau gazda acestui link poate să nu permită descărcări directe dintr-un browser web. Încercați aplicația desktop sau mobilă ori o altă locație de găzduire.';
	@override String get downloadTimedOut => 'Serverul a întârziat prea mult să răspundă. Încercați din nou mai târziu.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} a răspuns cu o eroare (HTTP ${status}). Încercați din nou mai târziu.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} nu a putut furniza acest fișier (HTTP ${status}). Verificați dacă adresa este încă corectă.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM nu are niciun fișier Call History pentru ${stem}.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'Descărcarea fișierului Call History de la N1MM pentru ${stem} nu a reușit. Încercați din nou mai târziu.';
	@override String processingFailedTitle({required Object name}) => '${name} nu a putut fi procesat';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Descărcarea avea doar ${imported} din cele ${existing} înregistrări de pe acest dispozitiv, așa că cele omise au fost păstrate. Reîmprospătarea din Setări › Date offline o acceptă totuși.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'S-a importat ${count} înregistrare pentru ${label}.',
		other: 'S-au importat ${count} înregistrări pentru ${label}.',
	);
	@override String importedData({required Object label}) => 'S-au importat date pentru ${label}.';
	@override String get cleanedUpTitle => 'Datele extensiilor au fost curățate';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Au fost eliminate datele pentru ${count} fișier de date al extensiilor dezactivate.',
		other: 'Au fost eliminate datele pentru ${count} fișiere de date ale extensiilor dezactivate.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} înregistrări';
	@override String get definitionUnavailable => 'Sursa fișierului nu a furnizat o definiție — extensia ei poate fi în curs de repornire sau configurată greșit. Încercați din nou peste un moment.';
}

// Path: updates
class _Translations$updates$ro extends Translations$updates$en {
	_Translations$updates$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Actualizare disponibilă';
	@override String newVersionAvailable({required Object version}) => 'O versiune nouă (${version}) este disponibilă.';
	@override String get getIt => 'Obține';
	@override String get ok => 'OK';
	@override String get updateReady => 'Actualizare pregătită';
	@override String get restartToApply => 'O actualizare a fost descărcată. Reporniți pentru a o aplica.';
	@override String get appliesNextLaunch => 'O actualizare a fost descărcată. Se va aplica la următoarea deschidere a aplicației.';
	@override String get restartNow => 'Repornește acum';
	@override String get reloadToUpdate => 'O versiune mai nouă a acestei pagini este disponibilă. Reîncărcați pentru a o obține.';
	@override String get reloadNow => 'Reîncarcă acum';
	@override String get checkForUpdates => 'Caută actualizări';
	@override String get checkingForUpdates => 'Se caută actualizări…';
	@override String get upToDate => 'La zi';
	@override String get automaticChecks => 'Verifică automat';
	@override String get automaticChecksDescription => 'Caută versiuni noi în fundal, începând de la următoarea pornire a aplicației';
}

// Path: extensionService
class _Translations$extensionService$ro extends Translations$extensionService$en {
	_Translations$extensionService$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Mediul de rulare a extensiilor nu este pregătit.';
	@override String testFailed({required Object error}) => 'Testul a eșuat: ${error}';
	@override String connectedAs({required Object identity}) => 'Conectat ca ${identity}';
	@override String get invalidFieldConfiguration => 'Configurație de câmp invalidă';
	@override String get invalidValue => 'Valoare invalidă';
	@override String validationError({required Object error}) => 'Eroare de validare: ${error}';
	@override String actionFailed({required Object error}) => 'Acțiunea a eșuat: ${error}';
	@override String get commandFailed => 'Comanda nu a putut rula';
	@override String commandMayNotChangeSettings({required Object name}) => '${name} nu poate schimba setările: nu a cerut acest drept la instalare';
	@override String commandMayNotControlRadio({required Object name}) => '${name} nu poate controla stația radio: nu a cerut acest drept la instalare';
	@override String commandDeveloperOnly({required Object name}) => '${name} nu poate rula asta: este una dintre comenzile pentru dezvoltatori ale aplicației';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => 'Rapoartele nu pot fi trimise acum';
	@override String get stashUnavailable => 'Ham2K File Stash nu poate fi accesat acum';
	@override String activitySearchSourcesFailed({required Object names}) => 'Niciun răspuns la căutarea de activități de la ${names}, așa că unele rezultate pot lipsi.';
	@override String get activitySearchSomeSourcesFailed => 'Unele extensii de activitate nu au răspuns la căutare, așa că unele rezultate pot lipsi.';
	@override String timersSuspendedBudget({required Object name}) => '${name} a petrecut prea mult timp în temporizatoarele sale. Acestea sunt oprite până la repornirea extensiilor.';
	@override String timersSuspendedFailures({required Object name}) => 'Temporizatoarele ${name} au eșuat repetat. Sunt oprite până la repornirea extensiilor.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} s-a blocat într-un temporizator. Temporizatoarele sale sunt oprite până la repornirea extensiilor.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$ro extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Locația operațiunii';
	@override String get selectedLocation => 'Locație selectată';
	@override String get gridSquare => 'Localizator al grilei Maidenhead';
	@override String get gridInvalid => 'Necesită 4, 6, 8 sau 10 caractere, ca FN31pr';
	@override String get suggestedLocations => 'Locații sugerate';
	@override String get deviceGps => 'GPS-ul dispozitivului';
	@override String peerGps({required Object device}) => 'GPS de la ${device}';
	@override String get locating => 'Se localizează…';
	@override String get gpsUnavailable => 'Locație indisponibilă';
	@override String get permissionDenied => 'Permisiunea de locație a fost refuzată';
	@override String get permissionBlocked => 'Permisiunea de locație este blocată';
	@override String get moreDetails => 'Mai multe detalii';
	@override String get stateOrProvince => 'Stat sau provincie (opțional)';
	@override String get controlsUnavailableTitle => 'Controalele activității nu sunt disponibile';
	@override String get controlsUnavailableReason => 'Aceste referințe pot fi folosite în continuare; doar activitățile lor nu au putut fi accesate.';
	@override String get controlsUnavailableRetry => 'Reîncearcă';
	@override String get county => 'Județ (opțional)';
}

// Path: versionLabel
class _Translations$versionLabel$ro extends Translations$versionLabel$en {
	_Translations$versionLabel$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versiunea ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$ro extends Translations$notices$en {
	_Translations$notices$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Nicio notificare încă';
	@override String get webStorageInMemory => 'Acest browser nu a putut oferi stocare persistentă — jurnalul există doar în memorie și va fi PIERDUT când se închide această filă. Folosiți o versiune actuală de Chrome, Firefox, Safari sau Edge.';
	@override String get webStorageUnreliable => 'Acest browser folosește o stocare de rezervă care nu este sigură cu mai multe file — păstrați o singură filă deschisă și lăsați sincronizarea activă.';
	@override String get logFromNewerBuildTitle => 'Acest jurnal necesită o versiune mai nouă';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Jurnalul dvs. a fost scris de o versiune mai nouă de HaLo (versiunea de stocare ${storage}; aceasta înțelege ${understood}), deci nu poate fi deschis, iar contactele noi nu vor fi salvate. Instalați din nou versiunea mai nouă — sau, dacă intenționați să rulați această versiune, indicați-i un alt dosar de date. Jurnalul se află în ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Jurnalul dvs. a fost scris de o versiune mai nouă de HaLo (versiunea de stocare ${storage}; aceasta înțelege ${understood}), deci nu poate fi deschis, iar contactele noi nu vor fi salvate. Deschideți jurnalul cu acea versiune mai nouă.';
	@override String get preferencesRestoredTitle => 'Setările au fost restaurate dintr-o copie de rezervă';
	@override String get preferencesRestored => 'Fișierul de setări nu a putut fi citit, așa că HaLo a restaurat ultima copie bună a acestuia. Este posibil să trebuiască să setați din nou ce ați schimbat în sesiunea anterioară. Fișierul ilizibil este păstrat alături, cu numele shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Setările au fost resetate';
	@override String get preferencesReset => 'Fișierul de setări nu a putut fi citit și nu exista nicio copie de rezervă, așa că HaLo a pornit cu valorile implicite. Fișierul ilizibil este păstrat în dosarul de date al aplicației, cu numele shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} nu a fost conectat automat';
	@override String autoConnectHeld({required Object name}) => 'HaLo a încetat să răspundă ultima dată când a început să se conecteze la ${name}, așa că de data aceasta nu a mai încercat, pentru a nu risca să se repete. Verificați că stația radio este pornită și cablul este conectat, apoi apăsați Conectează pe ea în Setări.';
}

// Path: syncAccount
class _Translations$syncAccount$ro extends Translations$syncAccount$en {
	_Translations$syncAccount$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Cont anonim (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (confirmare în așteptare)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (confirmare în așteptare - #${id})';
}

// Path: deepLink
class _Translations$deepLink$ro extends Translations$deepLink$en {
	_Translations$deepLink$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Porniți mai întâi o operațiune, apoi trimiteți din nou acel contact';
	@override String get waitingInOperation => 'Acel contact așteaptă în operațiunea din spatele acestui ecran';
	@override String unknownActivities({required Object refs}) => 'Acest dispozitiv nu are nicio activitate pentru ${refs}, așa că acele referințe au fost omise';
	@override String activitiesUnavailable({required Object refs}) => 'Activitățile dvs. nu au putut fi accesate, așa că ${refs} a fost omis — încercați din nou acel link';
}

// Path: confirmDevice
class _Translations$confirmDevice$ro extends Translations$confirmDevice$en {
	_Translations$confirmDevice$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirmați un dispozitiv';
	@override String get codePrompt => 'Introduceți codul afișat pe dispozitivul care vrea să se alăture acestui cont.';
	@override String get code => 'Cod';
	@override String get lookUp => 'Caută';
	@override String get codeNotFound => 'Nicio cerere nu corespunde acestui cod. Codurile expiră după 10 minute — cereți celuilalt dispozitiv unul nou.';
	@override String get linkExpired => 'Linkul a expirat. Cereți celuilalt dispozitiv să afișeze un cod QR nou.';
	@override String areYouSure({required Object device}) => 'Conectați ${device} la acest cont?';
	@override String get unnamedDevice => 'un dispozitiv fără nume';
	@override String get grantWarning => 'Va putea citi și modifica fiecare operațiune și QSO din acest cont.';
	@override String get needsSyncTitle => 'Acest dispozitiv nu se sincronizează încă';
	@override String get needsSyncText => 'Activați sincronizarea Ham2K Log Filer și conectați acest dispozitiv la un cont înainte de a putea admite altul.';
	@override String get malformedRequest => 'Serverul de sincronizare a trimis o cerere pe care această aplicație nu a putut-o citi. Cereți celuilalt dispozitiv să încerce din nou.';
	@override String get linkIt => 'Conectează dispozitivul';
}

// Path: switchAccounts
class _Translations$switchAccounts$ro extends Translations$switchAccounts$en {
	_Translations$switchAccounts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Încă nu există detalii despre cont';
	@override String get currentAccount => 'Contul curent';
	@override String get otherAccounts => 'Alte conturi';
	@override String get linkToAnother => 'Conectare la alt cont';
	@override String get linkWithSibling => 'Conectare cu altă aplicație Ham2K';
	@override String get linkWithPolo => 'Conectare cu contul din versiunea veche';
	@override String get linkWithSiblingDescription => 'Aveți instalată o altă aplicație Ham2K. Conectați-vă cu contul folosit acolo.';
	@override String siblingPrompt({required Object app}) => 'Aprobați cererea în ${app}, apoi reveniți aici.';
	@override String openSiblingAgain({required Object app}) => 'Deschide din nou ${app}';
	@override String get siblingNoGrant => 'Nu a funcționat? Deschideți-o din nou sau reveniți și conectați-vă în alt mod.';
	@override String siblingOpenFailed({required Object app}) => '${app} nu a putut fi deschisă.';
	@override String siblingLinkRenewed({required Object app}) => 'Linkul a expirat și unul nou este pregătit — deschideți din nou ${app}.';
	@override String get tryAgain => 'Încercați din nou';
	@override String get linkWithQr => 'Conectare cu un cod QR';
	@override String get linkWithQrDescription => 'Scanați-l de pe un dispozitiv care folosește deja contul';
	@override String get linkWithEmail => 'Conectare cu o adresă de e-mail';
	@override String get linkWithEmailDescription => 'Confirmați cu un cod sau cu un link din e-mail';
	@override String get enterEmailPrompt => 'Introduceți adresa de e-mail a contului pe care doriți să-l folosească acest dispozitiv.';
	@override String get emailAddress => 'Adresă de e-mail';
	@override String get linkAccount => 'Conectează contul';
	@override String get copiedCode => 'Codul a fost copiat în clipboard';
	@override String get copyCode => 'Copiază codul';
	@override String codePrompt({required Object email}) => 'Deschideți aplicația Ham2K pe un dispozitiv deja conectat cu ${email} și introduceți acest cod pentru a aproba cererea:';
	@override String get waitingForConfirmation => 'Se așteaptă confirmarea…';
	@override String get sendEmailInstead => 'Trimite în schimb un e-mail de confirmare';
	@override String emailSent({required Object email}) => 'A fost trimis un e-mail la ${email}. Deschideți-l și confirmați cererea pentru a conecta acest dispozitiv.';
	@override String get resendEmail => 'Retrimite e-mailul';
	@override String get qrPrompt => 'Scanați acest cod QR de pe un dispozitiv deja conectat la contul dorit — de exemplu cu Ham2K Portable Logger pe telefon.';
	@override String get serverUnreachable => 'Serverul de sincronizare nu a putut fi accesat. Încercați din nou mai târziu.';
	@override String get emailRequired => 'Introduceți o adresă de e-mail pentru conectare.';
	@override String noAccountForEmail({required Object email}) => 'Nu s-a găsit niciun cont pentru ${email}.';
	@override String serverRejected({required Object error}) => 'Serverul de sincronizare a respins cererea: ${error}';
	@override String get noLinkCode => 'Serverul de sincronizare nu a returnat un cod de conectare. Încercați din nou mai târziu.';
	@override String get noConfirmationCode => 'Serverul de sincronizare nu a trimis un cod de confirmare. Încercați din nou mai târziu.';
	@override String get switchNotAccepted => 'Acel cont nu a acceptat schimbarea. Încercați în schimb conectarea cu o adresă de e-mail.';
	@override String get requestFailed => 'Ceva n-a mers bine în comunicarea cu serverul de sincronizare. Încercați din nou mai târziu.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} QSO',
		other: '${count} QSO-uri',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} operațiune',
		other: '${count} operațiuni',
	);
}

// Path: qsonImport
class _Translations$qsonImport$ro extends Translations$qsonImport$en {
	_Translations$qsonImport$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importă operațiune QSON';
	@override String get description => 'Creează o operațiune nouă dintr-un fișier QSON, așa cum exportă Modul dezvoltator aici sau în PoLo.';
	@override String get dropHint => 'Plasați aici un fișier QSON pentru a-l importa ca operațiune nouă';
	@override String importing({required Object filename}) => 'Se importă ${filename}…';
	@override String failed({required Object filename, required Object error}) => '${filename} nu a putut fi importat: ${error}';
	@override String pickerFailed({required Object error}) => 'Nu s-a putut deschide un fișier pentru import: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} nu este text UTF-8, deci nu este un fișier QSON';
	@override String notJson({required Object filename}) => '${filename} nu este un fișier JSON, deci nu este un fișier QSON';
	@override String notOperation({required Object filename}) => '${filename} nu conține o operațiune QSON';
	@override String get busy => 'Un import rulează deja. Așteptați să se termine înainte de a porni altul.';
	@override String get oneFileOnly => 'Plasați câte un singur fișier QSON — fiecare se deschide ca operațiune separată.';
}

// Path: adifImport
class _Translations$adifImport$ro extends Translations$adifImport$en {
	_Translations$adifImport$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importă QSO-uri din ADIF';
	@override String reading({required Object filename}) => 'Se citește ${filename}…';
	@override String get dropHint => 'Plasați aici un fișier ADIF pentru import';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} QSO în acest fișier',
		other: '${formatted} QSO-uri în acest fișier',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} se află deja în jurnal',
		other: '${formatted} se află deja în jurnal',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} va fi importat',
		other: '${formatted} vor fi importate',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} contact nou',
		other: '${formatted} contacte noi',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} va fi combinat cu un contact existent',
		other: '${formatted} vor fi combinate cu contacte existente',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} nu poate fi importat (fără indicativ)',
		other: '${formatted} nu pot fi importate (fără indicativ)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} necesită o verificare atentă',
		other: '${formatted} necesită o verificare atentă',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Referințele nu au putut fi recuperate pentru ${count} contact',
		other: 'Referințele nu au putut fi recuperate pentru ${formatted} contacte',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Referințele ${programs} pot fi incomplete pentru ${count} contact',
		other: 'Referințele ${programs} pot fi incomplete pentru ${formatted} contacte',
	);
	@override String get stackingTypesUnknown => 'Contactele combinate pot pierde o referință — activitățile nu au putut indica ce tipuri se cumulează. Anulați și reîncercați pentru a evita acest lucru.';
	@override String get nothingToImport => 'Nimic din acest fișier nu poate fi importat';
	@override String get confirm => 'Importă';
	@override String importing({required Object filename}) => 'Se importă ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'S-a importat ${count} contact din ${filename}',
		other: 'S-au importat ${formatted} contacte din ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => '${filename} nu a putut fi importat: ${error}';
	@override String notAdif({required Object filename}) => '${filename} nu pare a fi un fișier ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Atenție: acest ADIF are QSO-uri de la ${calls}, dar vor fi importate ca ${station} dacă continuați.';
	@override String get stationCallJoin => ' și ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} nu are dată și nu poate fi importat',
		other: '${formatted} nu au dată și nu pot fi importate',
	);
	@override String activationFound({required Object refs}) => 'Acest fișier înregistrează o activare a ${refs}.';
	@override String get addActivation => 'Adaugă la această operațiune';
	@override String shortfall({required Object written, required Object planned}) => 'Doar ${written} din ${planned} au putut fi aplicate — jurnalul s-a schimbat cât timp decideați.';
	@override String get busy => 'Un import rulează deja. Așteptați să se termine înainte de a porni altul.';
	@override String get oneFileOnly => 'Plasați câte un singur fișier ADIF — ordinea în care se importă fișierele decide ce date câștigă.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} are mai mult de ${limit} QSO-uri, maximul pe care o operațiune îl poate importa deodată.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename} are mai mult de ${limit} QSO-uri. Importul unui ADIF într-o operațiune este menit să adauge câteva QSO-uri, nu să aducă un jurnal mare — folosiți pentru asta vizualizarea Jurnale. Modul dezvoltator vă permite totuși să îl importați, dacă sunteți sigur.';
	@override String get importAnyway => 'Importă oricum';
}

// Path: offline
class _Translations$offline$ro extends Translations$offline$en {
	_Translations$offline$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: conectat';
	@override String get noRoute => 'Nicio conexiune la rețea.';
	@override String get unreachable => 'Rețeaua funcționează, dar niciun server nu răspunde — adesea semn că o pagină de autentificare așteaptă într-un browser.';
	@override String get reachable => 'Toate serviciile răspund normal.';
	@override String get whatStops => 'Căutările, spoturile și fișierele de date sunt în pauză. Înregistrarea și sincronizarea din apropiere nu.';
	@override String get servicesTitle => 'Servicii';
	@override String get noServices => 'Niciun serviciu nu a raportat încă.';
	@override String lastSuccess({required Object when}) => 'A răspuns ultima dată acum ${when}';
	@override String get neverSucceeded => 'Nu a răspuns încă';
	@override String nextAttempt({required Object when}) => 'Următoarea încercare peste ${when}';
	@override String get nextAttemptNow => 'Următoarea încercare urmează';
	@override String get retry => 'Reîncearcă acum';
	@override String get retrying => 'Se încearcă…';
	@override String get retryReached => 'Din nou online.';
	@override String get retryUnreachable => 'Tot niciun răspuns.';
	@override String get retryNotAttempted => 'Nimic de trimis acum.';
	@override String get retryThrottled => 'Tocmai s-a încercat — mai așteptați puțin.';
	@override String get retryDisabled => 'Sincronizarea este oprită, deci nu există nimic cu care să se testeze.';
	@override String get syncService => 'Sincronizare Ham2K LoFi';
	@override String get retryInFlight => 'Se încearcă deja — așteptați.';
}

// Path: exportSettings
class _Translations$exportSettings$ro extends Translations$exportSettings$en {
	_Translations$exportSettings$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Setări de bază pentru toate exporturile, cu șabloane separate de nume de fișier și titlu pentru activitățile de referință și alte activități. Fiecare tip de export poate avea propriile valori implicite sau setări personalizate.';
	@override String get referenceActivities => 'Activități de referință';
	@override String get otherActivities => 'Alte activități';
	@override String get adifFields => 'Câmpuri ADIF';
	@override String get loadFailed => 'Setările de export nu au putut fi încărcate.';
	@override String get retry => 'Reîncearcă';
	@override String get compactFileNamesDescriptionOn => 'Nume de fișiere compacte, ca N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Nume de fișiere descriptive, ca 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Se includ nume, adrese, e-mailuri, note și locații precise în fișierele ADIF.';
	@override String get includePrivateDataDescriptionOff => 'Se omit nume, adrese, e-mailuri și note; locațiile se limitează la grile de șase caractere.';
	@override String get includeLookupDataDescriptionOn => 'Se includ informații de la serviciile de căutare a indicativelor.';
	@override String get includeLookupDataDescriptionOff => 'Se omit informațiile de la serviciile de căutare a indicativelor; se păstrează valorile introduse manual.';
	@override String get customTemplatesDescriptionOn => 'Șabloanele dvs. personalizate sunt active și pot fi editate mai jos.';
	@override String get customTemplatesDescriptionOff => 'Șabloanele implicite sunt active. Șabloanele dvs. personalizate sunt păstrate pentru mai târziu.';
	@override String get type => 'Tip de export';
	@override String get defaults => 'Setări implicite';
	@override String get includeLookupData => 'Include datele de căutare';
	@override String get customTemplates => 'Șabloane personalizate';
	@override String get filenameTemplate => 'Șablon nume fișier';
	@override String get compactFilenameTemplate => 'Șablon nume fișier compact';
	@override String get titleTemplate => 'Șablon titlu';
	@override String get adifNotesTemplate => 'Notițe ADIF QSO';
	@override String get adifCommentTemplate => 'Comentarii ADIF QSO';
	@override String get adifQslMessageTemplate => 'Mesaj ADIF QSL';
	@override String get shared => 'Setările se aplică fiecărei extensii care folosește acest tip de export.';
	@override String get defaultTemplates => 'Activați Șabloane personalizate pentru a edita șabloanele acestui tip.';
}

// Path: templateEditor
class _Translations$templateEditor$ro extends Translations$templateEditor$en {
	_Translations$templateEditor$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Previzualizare:';
	@override String get reset => 'Resetează';
	@override String get docs => 'Documentație șabloane';
	@override String get preview => 'Previzualizare exemplu';
	@override String get reference => 'Referință șabloane';
	@override String get attributes => 'Atribute disponibile';
	@override String get filters => 'Filtre';
	@override String get flowControl => 'Controlul fluxului';
	@override String get unavailable => 'Previzualizarea nu este disponibilă până când extensiile sunt pregătite.';
	@override String get empty => '(rezultat gol)';
}

// Path: home.nav
class _Translations$home$nav$ro extends Translations$home$nav$en {
	_Translations$home$nav$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operațiuni';
	@override String get chase => 'Vânătoare';
	@override String get logs => 'Jurnale';
	@override String get maps => 'Hărți';
	@override String get settings => 'Setări';
}

// Path: home.panels
class _Translations$home$panels$ro extends Translations$home$panels$en {
	_Translations$home$panels$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Listă de operațiuni';
	@override String get operationsDescription => 'Operațiunile dvs., cele mai recente primele.';
	@override String get version => 'Versiunea curentă';
	@override String get versionDescription => 'Sigla Ham2K, numele acestei aplicații și versiunea pe care o rulați.';
}

// Path: home.logs
class _Translations$home$logs$ro extends Translations$home$logs$en {
	_Translations$home$logs$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jurnale';
	@override String get titleFor => 'Jurnale pentru';
	@override String get emptyCallsigns => 'Niciun QSO înregistrat încă';
	@override String emptyQsos({required Object call}) => 'Niciun QSO pentru ${call}';
	@override String get mapNoSelection => 'Selectați un QSO pentru a-l vedea pe hartă';
	@override String get searchHint => 'Căutați indicativ sau nume';
	@override String get noSearchMatches => 'Niciun QSO nu corespunde căutării';
	@override String get titleAll => 'Toate jurnalele';
	@override String get allCallsigns => 'Toate indicativele';
	@override String get noOperation => 'Nu face parte dintr-o operațiune';
	@override String get unsavedTitle => 'Modificări nesalvate';
	@override String get unsavedBody => 'Acest QSO are modificări pe care nu le-ați salvat.';
	@override String get pendingDeleteBody => 'Acest QSO este marcat pentru ștergere.';
	@override String get editGone => 'Nesalvat: acest QSO nu mai este în jurnal.';
	@override String get discard => 'Renunță';
	@override late final _Translations$home$logs$sheet$ro sheet = _Translations$home$logs$sheet$ro._(_root);
	@override late final _Translations$home$logs$groupBy$ro groupBy = _Translations$home$logs$groupBy$ro._(_root);
	@override late final _Translations$home$logs$period$ro period = _Translations$home$logs$period$ro._(_root);
	@override late final _Translations$home$logs$periodTitle$ro periodTitle = _Translations$home$logs$periodTitle$ro._(_root);
	@override late final _Translations$home$logs$columns$ro columns = _Translations$home$logs$columns$ro._(_root);
	@override late final _Translations$home$logs$panels$ro panels = _Translations$home$logs$panels$ro._(_root);
	@override late final _Translations$home$logs$import$ro import = _Translations$home$logs$import$ro._(_root);
}

// Path: chase.station
class _Translations$chase$station$ro extends Translations$chase$station$en {
	_Translations$chase$station$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stația de vânătoare';
	@override String get stationLabel => 'Stație: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Fără locație';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$ro extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get today => 'astăzi';
	@override String get thisWeek => 'săptămâna aceasta';
	@override String get last14Days => 'în ultimele 14 zile';
	@override String get thisMonth => 'luna aceasta';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$ro extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistici pentru astăzi';
	@override String get thisWeek => 'Statistici pentru săptămâna aceasta';
	@override String get last14Days => 'Statistici pentru ultimele 14 zile';
	@override String get thisMonth => 'Statistici pentru luna aceasta';
}

// Path: chase.period
class _Translations$chase$period$ro extends Translations$chase$period$en {
	_Translations$chase$period$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get today => 'Astăzi';
	@override String get thisWeek => 'Săptămâna aceasta';
	@override String get last14Days => 'Ultimele 14 zile';
	@override String get thisMonth => 'Luna aceasta';
}

// Path: chase.goals
class _Translations$chase$goals$ro extends Translations$chase$goals$en {
	_Translations$chase$goals$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Obiective de vânătoare';
	@override String remove({required Object name}) => 'Opriți vânarea ${name}';
	@override String get extensionsTitle => 'Mai multe programe de vânătoare';
}

// Path: chase.panels
class _Translations$chase$panels$ro extends Translations$chase$panels$en {
	_Translations$chase$panels$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO-uri';
	@override String get loggingDescription => 'Controalele de înregistrare deasupra QSO-urilor vânate în perioada respectivă.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Indicativul care se înregistrează sau statisticile perioadei.';
	@override String get spots => 'Spoturi';
	@override String get spotsDescription => 'Stații spotate în eter, gata de vânat.';
	@override String get map => 'Hartă';
	@override String get mapDescription => 'QSO-urile perioadei și stația care se înregistrează.';
}

// Path: chase.claims
class _Translations$chase$claims$ro extends Translations$chase$claims$en {
	_Translations$chase$claims$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get checking => 'Se verifică QSO-urile pentru vânătoare';
	@override String rebuilding({required Object program}) => 'Se verifică jurnalul pentru ${program}';
	@override String progress({required Object done, required Object total}) => '${done} din ${total} QSO-uri';
}

// Path: chase.notice
class _Translations$chase$notice$ro extends Translations$chase$notice$en {
	_Translations$chase$notice$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => '${program} nou';
	@override String newRefGuess({required Object program}) => 'Probabil ${program} nou';
	@override String newBand({required Object program}) => 'Bandă nouă ${program}';
	@override String newBandGuess({required Object program}) => 'Probabil bandă nouă ${program}';
	@override String newMode({required Object program}) => 'Mod nou ${program}';
	@override String newModeGuess({required Object program}) => 'Probabil mod nou ${program}';
	@override String unconfirmed({required Object program}) => '${program} neconfirmat';
	@override String programGuess({required Object notice}) => 'Probabil ${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$ro extends Translations$chase$alerts$en {
	_Translations$chase$alerts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Alerte';
	@override String get newRef => 'Referință nouă';
	@override String get newBand => 'Bandă nouă';
	@override String get newMode => 'Mod nou';
	@override String get unconfirmed => 'Neconfirmat';
}

// Path: chase.imports
class _Translations$chase$imports$ro extends Translations$chase$imports$en {
	_Translations$chase$imports$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'Importă ${label}';
	@override String pickTitle({required Object file}) => 'Importă ${file} ca';
	@override String get dropHint => 'Plasați aici un fișier pentru a-l importa într-un program de vânătoare';
	@override String done({required Object count, required Object program, required Object file}) => 'S-au importat ${count} intrări ${program} din ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'S-au importat ${count} intrări ${program} din ${file}; ${skipped} nu au putut fi citite și au fost omise';
	@override String nothing({required Object file, required Object program}) => '${file} nu conține nimic ce ${program} poate importa';
	@override String failed({required Object program, required Object file}) => '${program} nu a putut citi ${file}';
	@override String unreadable({required Object program, required Object skipped, required Object file}) => '${program} nu a putut citi niciuna dintre cele ${skipped} înregistrări din ${file}';
	@override String noProgram({required Object file}) => 'Niciun program de vânătoare nu importă ${file}';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$ro extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Căutați online?';
	@override String get body => 'Asistența este dezactivată pentru această operațiune. Căutarea tuturor QSO-urilor va folosi servicii online precum QRZ doar de această dată.';
	@override String bodyRules({required Object rules}) => 'Asistența este dezactivată pentru această operațiune, pentru a respecta regulile ${rules}. Căutarea tuturor QSO-urilor va folosi servicii online precum QRZ doar de această dată.';
	@override String get action => 'Caută online';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$ro extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicativ invalid: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicative invalide: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Până acum a operat ${previous}. ${typed} va fi înregistrat pentru contactele noi.';
	@override String operatorNoneSoFar({required Object typed}) => 'Niciun operator înregistrat până acum. ${typed} va fi înregistrat pentru contactele noi.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Această operațiune are deja contacte făcute de ${calls}. ${typed} va fi înregistrat doar pentru cele noi.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Înregistrați ${typed} și ca operator al contactului deja înregistrat',
		other: 'Înregistrați ${typed} și ca operator al tuturor celor ${count} contacte deja înregistrate',
	);
	@override String get operatorSeveralStations => 'Când se folosesc mai multe stații în eter, operatorii separați nu sunt acceptați';
	@override String get contactsUnreadable => 'Contactele acestei operațiuni nu au putut fi citite, deci schimbarea unui indicativ aici nu va oferi actualizarea lor';
	@override String restampFailed({required Object error}) => 'Contactele deja înregistrate nu au putut fi actualizate, deci nu s-a făcut nicio modificare: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} din ${planned} contacte au fost actualizate — restul nu mai sunt în această operațiune';
}

// Path: operation.tabs
class _Translations$operation$tabs$ro extends Translations$operation$tabs$en {
	_Translations$operation$tabs$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO-uri';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTURI';
	@override String get map => 'HARTĂ';
	@override String get qsosPlain => 'QSO-uri';
	@override String get clock => 'Ceas';
	@override String get weather => 'Vreme';
	@override String get website => 'Site web';
	@override String get remoteScreen => 'Ecran la distanță';
	@override String get solar => 'Solar';
	@override String get radio => 'Radio';
	@override String get rotator => 'Rotor';
	@override String get summaries => 'Rezumate operațiune';
}

// Path: operation.positions
class _Translations$operation$positions$ro extends Translations$operation$positions$en {
	_Translations$operation$positions$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Nicio altă poziție de operare nu partajează încă această operațiune.';
	@override String positionLabel({required Object number}) => 'Poz: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Altă poziție';
	@override String get thisDevice => 'Poziția noastră de operare';
	@override String get nameIn => ' în ';
	@override String get panelTitle => 'Poziții';
	@override String get panelDescription => 'Ce înregistrează chiar acum fiecare poziție de operare care partajează această operațiune.';
}

// Path: operation.menu
class _Translations$operation$menu$ro extends Translations$operation$menu$en {
	_Translations$operation$menu$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Afișează câmpurile RST';
	@override String get showStateField => 'Afișează câmpul Stat';
	@override String get showGridField => 'Afișează câmpul Grilă';
	@override String get showDeletedQsos => 'Afișează QSO-urile șterse';
	@override String get showDeletedOps => 'Afișează operațiunile șterse';
	@override String get showQsoNumbers => 'Afișează numerele QSO';
	@override String get lookupAllQsos => 'Caută toate QSO-urile';
	@override String get loggingSettingsTitle => 'Setări de înregistrare';
	@override String get mapSettingsTitle => 'Setări hartă';
	@override String get actionsSection => 'Acțiuni';
}

// Path: operation.layout
class _Translations$operation$layout$ro extends Translations$operation$layout$en {
	_Translations$operation$layout$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Adaugă un panou';
	@override String get availableSection => 'Panouri disponibile';
	@override String panelSettings({required Object panel}) => 'Setări ${panel}';
	@override String get panelSettingsAction => 'Setări panou';
	@override String get viewName => 'Vizualizare operațiune';
	@override String get viewOptions => 'Opțiuni de aranjare a vizualizării';
	@override String get viewTitleBuiltIn => 'Această vizualizare este integrată în aplicație, la fel și numele ei';
	@override String get resetOptions => 'Restabilește valorile implicite';
	@override String get removePane => 'Elimină';
	@override String resetPaneConfirm({required Object panel}) => 'Restabiliți ${panel} la valorile implicite?';
	@override String get resetPaneConfirmBody => 'Titlul, antetul și dimensiunea revin la valorile implicite. Restul aranjamentului rămâne neschimbat.';
	@override String get resetViewConfirm => 'Restabiliți această vizualizare la aranjamentul implicit?';
	@override String get resetViewConfirmBody => 'Panourile revin la aranjamentul implicit, iar opțiunile vizualizării și ale fiecărui panou revin la valorile implicite.';
	@override String paneOptionsTitle({required Object panel}) => 'Setări de aranjare ${panel}';
	@override String get paneTitle => 'Titlu';
	@override String get paneShowHeader => 'Afișează antetul';
	@override String get paneShowHeaderTabset => 'Afișat mereu cât timp acest panou face parte dintr-un grup — antetul este calea către celelalte';
	@override String get paneInherit => 'La fel ca aplicația';
	@override String get searchHint => 'Căutați panouri';
	@override String get noPanelsMatch => 'Niciun panou nu corespunde căutării.';
	@override String get nothingToAdd => 'Această vizualizare are deja toate panourile posibile';
	@override String addPanel({required Object panel}) => 'Adaugă ${panel}';
	@override String showPreview({required Object panel}) => 'Previzualizare ${panel}';
	@override String missingExtension({required Object name}) => 'Extensia „${name}” lipsește';
	@override String get missingExtensionEnable => 'Activează';
	@override String get missingExtensionInstall => 'Instalează…';
	@override String get missingExtensionWontRun => 'Această versiune nu va porni. Actualizați-o din Setări › Extensii.';
	@override String get missingExtensionUnavailable => 'Nu este disponibilă în această aplicație';
	@override String get missingExtensionNotInCatalog => 'Nu este în catalog';
	@override String get missingExtensionCatalogUnreachable => 'Catalogul nu a putut fi accesat. Încercați din nou';
	@override String get missingExtensionFailed => 'Nu a mers. Încercați din nou';
	@override String get previewUnavailable => 'Imaginea de previzualizare a acestui panou nu a putut fi afișată.';
	@override String get nestedPaneTitle => 'Mai multe';
	@override late final _Translations$operation$layout$layouts$ro layouts = _Translations$operation$layout$layouts$ro._(_root);
	@override String get editLayout => 'Editează aranjamentul';
	@override String get saveLayout => 'Salvează aranjamentul';
	@override String get revertLayout => 'Renunță la modificările de aranjament';
	@override String get done => 'Gata';
	@override String get layoutUnreadableTitle => 'Aranjamentul nu a putut fi citit';
	@override String get layoutUnreadableBody => 'Aranjamentul salvat nu a putut fi citit, așa că se afișează aranjamentul implicit. Originalul nu va fi suprascris până nu alegeți să-l păstrați pe acesta.';
	@override String get layoutUnreadableAction => 'Folosește acest aranjament';
	@override String panelRenderFailed({required Object panel}) => '${panel} nu a putut fi afișat';
	@override String panelOverCharacters({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: a trimis mai mult de ${max} caractere';
	@override String panelOverElements({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: grafica lui are mai mult de ${max} elemente';
	@override String panelOverDepth({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: grafica lui are mai mult de ${max} niveluri de imbricare';
	@override String panelNotArtwork({required Object panel}) => '${panel} nu a putut fi afișat: grafica lui nu este de sine stătătoare';
	@override String panelOverLayers({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: scena lui are mai mult de ${max} straturi';
	@override String panelOverControls({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: scena lui are mai mult de ${max} controale';
	@override String panelOverItems({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: o parte a scenei lui are mai mult de ${max} intrări';
	@override String panelOverStringLength({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: un text din scenă depășește ${max} caractere';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: aranjamentul lui are mai mult de ${max} niveluri de imbricare';
	@override String get panelRenderRetry => 'Încercați din nou';
	@override String get panelActionFailed => 'Acțiunea panoului a eșuat. Încercați din nou.';
	@override late final _Translations$operation$layout$panels$ro panels = _Translations$operation$layout$panels$ro._(_root);
	@override String get htmlPanelUnsupported => 'Acest panou necesită o vizualizare web, pe care această platformă nu o oferă';
	@override String get htmlPanelUnsupportedOnWeb => 'Acest panou necesită un mediu izolat pe care versiunea web nu îl poate oferi';
}

// Path: operation.export
class _Translations$operation$export$ro extends Translations$operation$export$en {
	_Translations$operation$export$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporturi operațiune';
	@override String get syncedOperation => 'Operațiunea este sincronizată';
	@override String get unsyncedOperation => 'Operațiunea are modificări nesincronizate';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} QSO în această operațiune',
		other: '${count} QSO-uri în această operațiune',
	);
	@override String qsosSynced({required Object total}) => 'Toate cele ${total} QSO-uri sunt sincronizate';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} din ${total} QSO-uri așteaptă sincronizarea';
	@override String eventsSynced({required Object total}) => '${total} marcaje de eveniment sincronizate';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} din ${total} marcaje de eveniment în așteptare';
	@override String get loading => 'Se încarcă opțiunile de export…';
	@override String get noOptions => 'Niciun format de export disponibil (mediul de extensii încă pornește?)';
	@override String get nothingLogged => 'Nimic de exportat încă — această operațiune nu are QSO-uri.';
	@override String get share => 'Partajează';
	@override String get nothingSelected => 'Nimic selectat';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Salvează ${count} fișier',
		other: 'Salvează ${count} fișiere',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Partajează ${count} fișier',
		other: 'Partajează ${count} fișiere',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Exportă ${count} fișier',
		other: 'Exportă ${count} fișiere',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Descarcă ${count} fișier',
		other: 'Descarcă ${count} fișiere',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Salvează ${count} fișier combinat',
		other: 'Salvează ${count} fișiere combinate',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Partajează ${count} fișier combinat',
		other: 'Partajează ${count} fișiere combinate',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Exportă ${count} fișier combinat',
		other: 'Exportă ${count} fișiere combinate',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Descarcă ${count} fișier combinat',
		other: 'Descarcă ${count} fișiere combinate',
	);
	@override String saveOne({required Object name}) => 'Salvează ${name}';
	@override String shareOne({required Object name}) => 'Partajează ${name}';
	@override String exportOne({required Object name}) => 'Exportă ${name}';
	@override String downloadOne({required Object name}) => 'Descarcă ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Trimite ${count} fișier în Stash',
		other: 'Trimite ${count} fișiere în Stash',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Trimite ${count} fișier combinat în Stash',
		other: 'Trimite ${count} fișiere combinate în Stash',
	);
	@override String get settingsButton => 'Setări export';
	@override String get settingsTitle => 'Setări export';
	@override late final _Translations$operation$export$compactFileNames$ro compactFileNames = _Translations$operation$export$compactFileNames$ro._(_root);
	@override late final _Translations$operation$export$includePrivateData$ro includePrivateData = _Translations$operation$export$includePrivateData$ro._(_root);
	@override String get resultTitle => 'Export finalizat';
	@override String get resultFailedTitle => 'Exportul a eșuat';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} fișier exportat în ${path}',
		other: '${count} fișiere exportate în ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} fișier exportat: ${path}',
		other: '${count} fișiere exportate: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} fișier partajat',
		other: '${count} fișiere partajate',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} fișier descărcat',
		other: '${count} fișiere descărcate',
	);
	@override String exportFailed({required Object error}) => 'Exportul a eșuat: ${error}';
	@override late final _Translations$operation$export$stash$ro stash = _Translations$operation$export$stash$ro._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$ro extends Translations$operation$spots$en {
	_Translations$operation$spots$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Niciun spot nu corespunde filtrelor';
	@override String error({required Object error}) => 'Spoturile nu au putut fi încărcate: ${error}';
	@override String get unknownBand => 'Altele';
	@override String get auto => 'Automat';
	@override String autoValue({required Object value}) => 'Automat (acum ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Oricare';
	@override String get allBands => 'Toate benzile';
	@override String get allModes => 'Toate modurile';
	@override String get phoneAndCw => 'Fonie și CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} spot',
		other: '${count} spoturi',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Se afișează ${count} din ${total} spoturi';
	@override String get spotsDisabled => 'Spoturile sunt dezactivate pentru această operațiune';
	@override String ageMinutes({required Object minutes}) => '${minutes} minute';
	@override String get callsOfNote => 'Indicative notabile';
	@override String get yourSpots => 'Spoturile dvs.';
	@override String get allSpots => 'Toate spoturile';
	@override late final _Translations$operation$spots$continents$ro continents = _Translations$operation$spots$continents$ro._(_root);
	@override late final _Translations$operation$spots$filters$ro filters = _Translations$operation$spots$filters$ro._(_root);
	@override String get unavailableTitle => 'Spoturi indisponibile';
	@override String unavailableText({required Object sources}) => '${sources} nu a răspuns.';
	@override String get failedTitle => 'Eroare la sursa de spoturi';
	@override String failedText({required Object sources}) => '${sources} a returnat o eroare.';
	@override String get slideLogIt => 'Înregistrează';
	@override String get slideIgnore => 'Ignoră';
	@override String get slideRestore => 'Restaurează';
	@override late final _Translations$operation$spots$logConflict$ro logConflict = _Translations$operation$spots$logConflict$ro._(_root);
}

// Path: operation.import
class _Translations$operation$import$ro extends Translations$operation$import$en {
	_Translations$operation$import$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importă date în operațiune';
	@override String get importAdifAction => 'Importă QSO-uri din ADIF';
	@override String get settingsButton => 'Setări de ascultare';
	@override String get settingsTitle => 'Ascultare pentru alte aplicații';
	@override String get protocolAddressLabel => 'Adresă';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Introduceți un port între 1 și 65535';
	@override String get protocolAddressInvalid => 'Introduceți o adresă IP validă (de ex. 127.0.0.1 sau 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Se primesc date';
	@override String get protocolStatusNoData => 'Nicio dată primită recent';
	@override String protocolBindError({required Object error}) => 'Ascultarea nu a putut porni: ${error}';
	@override String captureFailed({required Object error}) => 'QSO-urile primite nu au putut fi salvate și se reîncearcă: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Oricare (broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → fila Broadcast Data → bifați "Enable Broadcasts" pentru informațiile de contact. Setați adresa IP la 127.0.0.1 dacă rulează pe același calculator sau 255.255.255.255 pentru broadcast în rețeaua locală curentă.';
	@override String get helpWsjtxSetup => 'File → Settings → fila Reporting → secțiunea UDP Server → bifați "Accept UDP requests". Setați UDP Server la 127.0.0.1 dacă rulează pe același calculator sau la o adresă multicast precum 239.239.0.2 și folosiți aceeași adresă în configurația de mai sus din această aplicație.';
	@override String get listenTitle => 'Ascultă QSO-uri de la alte aplicații';
	@override String get listenDescriptionOnN1mm => 'Se ascultă N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Se ascultă WSJT-X';
	@override String get listenDescriptionOnBoth => 'Se ascultă N1MM+ și WSJT-X';
	@override String get listenDescriptionOff => 'Oprit';
	@override String get addToOperationTitle => 'Adaugă la această operațiune';
	@override String get addToOperationDescriptionOn => 'QSO-urile capturate sunt adăugate la această operațiune pe măsură ce sosesc';
	@override String get addToOperationDescriptionOff => 'QSO-urile capturate sunt reținute până activați această opțiune';
	@override String get pendingSectionTitle => 'QSO-uri capturate';
	@override String get pendingEmpty => 'Nimic capturat încă';
	@override String stationMismatch({required Object call}) => 'Înregistrat ca ${call}, nu ca stația acestei operațiuni';
	@override String get discardAction => 'Renunță';
	@override String get gapDialogTitle => 'Includeți capturile anterioare?';
	@override String gapDialogBody({required Object count}) => 'Încă ${count} QSO-uri au fost capturate mai devreme, înaintea unei întreruperi în date. Le includeți și pe ele?';
	@override String get gapDialogRecentOnly => 'Doar cele recente';
	@override String gapDialogIncludeAll({required Object count}) => 'Include toate cele ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$ro extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get link => 'Probleme?';
	@override String get title => 'Raportați o problemă de contur';
	@override String get reference => 'Care contur';
	@override String get severity => 'Cât de grav este?';
	@override String get minor => 'Detaliu minor';
	@override String get major => 'Problemă serioasă';
	@override String get explanation => 'Ce este greșit?';
	@override String get explanationHint => 'Ce greșește conturul și unde';
	@override String get send => 'Trimite';
	@override String get sending => 'Se trimite raportul — mulțumim';
	@override String get copy => 'Copiază raportul';
	@override String get notSent => 'Raportul nu a putut fi trimis';
	@override String get copied => 'Raport copiat';
	@override String get notCopied => 'Raportul nu a putut fi copiat';
}

// Path: map.postcard
class _Translations$map$postcard$ro extends Translations$map$postcard$en {
	_Translations$map$postcard$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get button => 'Carte poștală a operațiunii';
	@override String title({required Object title}) => 'Carte poștală pentru ${title}';
	@override String get portrait => 'Portret';
	@override String get landscape => 'Peisaj';
	@override String get square => 'Pătrat';
	@override String get save => 'Salvează…';
	@override String get download => 'Descarcă';
	@override String get share => 'Partajează';
	@override String get copy => 'Copiază';
	@override String get copied => 'Copiat în clipboard';
	@override String saved({required Object path}) => 'Salvat în ${path}';
	@override String downloaded({required Object name}) => '${name} descărcat';
	@override String savedMany({required Object count, required Object path}) => '${count} imagini salvate în ${path}';
	@override String savedFiles({required Object names}) => 'Salvate: ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} fuseseră deja salvate';
	@override String downloadedMany({required Object count}) => 'Se descarcă ${count} imagini — permiteți-le dacă browserul întreabă';
	@override String get mapLeftOut => 'Harta nu s-a încărcat, așa că a fost omisă';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — harta nu s-a încărcat, așa că a fost omisă';
	@override String continued({required Object title}) => '${title} (continuare)';
	@override String get previousPage => 'Pagina anterioară';
	@override String get nextPage => 'Pagina următoare';
	@override String pageOf({required Object page, required Object count}) => 'Pagina ${page} din ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} Q',
		other: '${count} Q-uri',
	);
	@override String get options => 'Opțiuni carte poștală';
	@override String get bandLegend => 'Afișează legenda benzilor';
	@override String get grayline => 'Afișează linia gri';
	@override String get sectionsAndOrder => 'Secțiuni de rezumat și ordine';
	@override String get sectionDays => 'Fiecare zi';
	@override String get reset => 'Resetează';
	@override String failed({required Object error}) => 'Cartea poștală nu a putut fi creată: ${error}';
	@override String get mapNotReady => 'Harta nu s-a încărcat complet. Verificați conexiunea și încercați din nou.';
	@override String saveFailed({required Object error}) => 'Cartea poștală nu a putut fi salvată: ${error}';
	@override String get copyFailed => 'Clipboardul nu a acceptat imaginea. Încercați din nou.';
	@override String get shareFailed => 'Cartea poștală nu a putut fi partajată. Încercați din nou.';
	@override String get fileName => 'carte-postala';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$ro extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Niciun QSO încă... hai să operăm!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO-uri';
	@override String qsosInTime({required Object count, required Object time}) => '${count} în ${time}';
	@override String sinceLast({required Object time}) => '${time} de la ultimul';
	@override String ratePer10({required Object rate}) => '${rate} Q/h pentru ultimele 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h pentru ultimele 100';
	@override String distanceTo({required Object distance}) => '${distance} până la';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) până la';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) până la';
	@override String distanceAway({required Object distance}) => 'la ${distance} depărtare';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => 'la ${distance} (${bearing}°) depărtare';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => 'la ${distance} (${bearing}° / ${reverse}°) depărtare';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplicat!';
	@override String get noticeNewBand => 'Bandă nouă';
	@override String get noticeNewMode => 'Mod nou';
	@override String get noticeNewDXCC => 'DXCC nou';
	@override String get noticeNewState => 'Stat nou';
	@override String get noticeNewProvince => 'Provincie nouă';
	@override String get noticeNewDay => 'Zi nouă';
	@override String get noticeNewRef => 'Ref. nouă';
	@override String get noticeNewMult => 'Mult nou';
	@override String get noticeNewZone => 'Zonă nouă';
	@override String get noticeInvalidMode => 'Mod greșit';
	@override String get noticeInvalidBand => 'Bandă greșită';
	@override String get noticeInvalidCategory => 'Nu se poate lucra';
	@override String get noticeOverTime => 'Timp expirat';
	@override String get noticeWorkedBefore => 'Lucrat anterior';
	@override String get noticeNewPark => 'Parc nou';
	@override String get noticeNewSection => 'Secțiune nouă';
	@override String get noticeBonusStation => 'Stație bonus!';
	@override String get noticeMissingExchange => 'Fără schimb';
	@override String get noticeInvalidExchange => 'Schimb greșit';
	@override String get noticeUnknownEvent => 'Eveniment necunoscut';
	@override String get noticeIncompleteCall => 'Indicativ incomplet — nepunctat';
	@override String get noticeOurGrid => 'Setați grila noastră';
	@override String get noticeRareCounty => 'Județ rar!';
	@override String get noticeOurLocation => 'Setați județul nostru';
	@override String get noticeShortGrid => 'Grila e prea scurtă';
}

// Path: qsoList.find
class _Translations$qsoList$find$ro extends Translations$qsoList$find$en {
	_Translations$qsoList$find$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'Caută în jurnal (${shortcut})';
	@override String get menuItemNoShortcut => 'Caută în jurnal';
	@override String get hint => 'Număr QSO sau indicativ';
	@override String get noMatches => 'Nicio potrivire';
	@override String get noOperationQsos => 'Niciun QSO în această operațiune';
	@override String get noPeriodQsos => 'Niciun QSO în această perioadă';
	@override String get outsideQsosOne => '1 QSO în afara acestei operațiuni';
	@override String outsideQsosOther({required Object count}) => '${count} QSO-uri în afara acestei operațiuni';
	@override String get pastQsosOne => '1 QSO anterior';
	@override String pastQsosOther({required Object count}) => '${count} QSO-uri anterioare';
}

// Path: callInfo.history
class _Translations$callInfo$history$ro extends Translations$callInfo$history$en {
	_Translations$callInfo$history$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} în ultimele 7 zile';
	@override String today({required Object n}) => '${n} astăzi';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${n} QSO',
		other: '${n} QSO-uri',
	);
}

// Path: settings.theme
class _Translations$settings$theme$ro extends Translations$settings$theme$en {
	_Translations$settings$theme$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Temă';
	@override String get system => 'Urmează setările sistemului';
	@override String get light => 'Luminos';
	@override String get dark => 'Întunecat';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$ro extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get system => 'Se urmează setările sistemului';
	@override String get light => 'Întotdeauna în modul luminos';
	@override String get dark => 'Întotdeauna în modul întunecat';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$ro extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Cele mai mici--';
	@override String get smallestMinus => 'Cele mai mici-';
	@override String get smallest => 'Cele mai mici';
	@override String get smaller => 'Mai mici';
	@override String get normal => 'Normale';
	@override String get larger => 'Mai mari';
	@override String get largest => 'Cele mai mari';
	@override String get largestPlus => 'Cele mai mari+';
	@override String get largestPlusPlus => 'Cele mai mari++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$ro extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Păstrează dispozitivul treaz';
	@override String get descriptionOn => 'Rămâne treaz cât timp sunteți în vizualizarea de înregistrare sau o sincronizare este în curs';
	@override String get descriptionOff => 'Intră în repaus ca de obicei';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$ro extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automat';
	@override String get densest => 'Cel mai dens';
	@override String get dense => 'Dens';
	@override String get normal => 'Normal';
	@override String get sparse => 'Aerisit';
	@override String get sparsest => 'Cel mai aerisit';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$ro extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometri';
	@override String get miles => 'Mile';
}

// Path: settings.logging
class _Translations$settings$logging$ro extends Translations$settings$logging$en {
	_Translations$settings$logging$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Înregistrare';
	@override late final _Translations$settings$logging$leftieMode$ro leftieMode = _Translations$settings$logging$leftieMode$ro._(_root);
	@override late final _Translations$settings$logging$countryFlags$ro countryFlags = _Translations$settings$logging$countryFlags$ro._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$ro countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$ro._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$ro suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$ro._(_root);
	@override late final _Translations$settings$logging$showBearing$ro showBearing = _Translations$settings$logging$showBearing$ro._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$ro showReverseBearing = _Translations$settings$logging$showReverseBearing$ro._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$ro switchSentRcvd = _Translations$settings$logging$switchSentRcvd$ro._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$ro jumpAfterRST = _Translations$settings$logging$jumpAfterRST$ro._(_root);
	@override late final _Translations$settings$logging$defaultReport$ro defaultReport = _Translations$settings$logging$defaultReport$ro._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$ro defaultReportCW = _Translations$settings$logging$defaultReportCW$ro._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$ro defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$ro._(_root);
	@override late final _Translations$settings$logging$numbersRow$ro numbersRow = _Translations$settings$logging$numbersRow$ro._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$ro numbersRowExtra = _Translations$settings$logging$numbersRowExtra$ro._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$ro numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$ro._(_root);
	@override String get bands => 'Benzi preferate';
	@override String get modes => 'Moduri preferate';
}

// Path: settings.catServer
class _Translations$settings$catServer$ro extends Translations$settings$catServer$en {
	_Translations$settings$catServer$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Server CAT';
	@override String get description => 'Permite altor aplicații (WSJT-X, programe de log etc.) să controleze stația radio prin Ham2K Logger.';
	@override String get protocol => 'Protocol';
	@override late final _Translations$settings$catServer$protocolOpts$ro protocolOpts = _Translations$settings$catServer$protocolOpts$ro._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Acces deschis';
	@override String get openAccessOn => 'Orice calculator din rețeaua locală se poate conecta.';
	@override String get openAccessOff => 'Doar aplicațiile de pe acest calculator se pot conecta.';
	@override String get allowTransmit => 'Permite aplicațiilor să emită';
	@override String allowTransmitOn({required Object minutes}) => 'Aplicațiile pot comanda PTT-ul stației radio, cel mult ${minutes} minute odată.';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'Aplicațiile de pe orice calculator din rețeaua locală pot comanda PTT-ul stației radio, cel mult ${minutes} minute odată.';
	@override String get allowTransmitOff => 'Aplicațiile nu pot comanda emisia stației radio. Folosiți VOX sau propria lor configurație PTT.';
	@override String get allowTransmitUnsupported => 'Stația radio de pe VFO principal nu poate fi trecută pe emisie din Ham2K Logger, deci aplicațiile nu pot emite prin ea.';
	@override String get off => 'Oprit.';
	@override String starting({required Object protocol}) => '${protocol}, pornește…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} pe portul ${port}. Clienți conectați: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} pe portul ${port}, dar nicio stație radio nu este conectată ca VFO principal.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} nu poate asculta pe portul ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} nu poate asculta pe portul ${port}: un alt program îl folosește, adesea chiar ${protocol}. Închideți acel program sau alegeți alt port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} nu poate asculta pe portul ${port}: acest calculator nu permite. Alegeți un port peste 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} a oprit ascultarea pe portul ${port}. Se reîncearcă…';
}

// Path: settings.cluster
class _Translations$settings$cluster$ro extends Translations$settings$cluster$en {
	_Translations$settings$cluster$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cluster DX';
	@override String get description => 'Serverul la care extensiile postează spoturi și de la care le citesc, autentificate ca operator.';
	@override String get connect => 'Conectare la cluster';
	@override String get connectOn => 'Extensiile se conectează la cluster când au nevoie';
	@override String get connectOff => 'Nimic nu se conectează la cluster';
	@override String get console => 'Afișează consola';
	@override String get consoleDescription => 'Ce trimite clusterul și un loc unde puteți tasta comenzi';
	@override String get consoleTitle => 'Consolă cluster';
	@override String get consoleConnect => 'Conectează';
	@override String get consoleDisconnect => 'Deconectează';
	@override String get consoleCommand => 'Comandă';
	@override String get consoleEmpty => 'Nimic încă. Conectați-vă sau așteptați ca o extensie să folosească clusterul.';
	@override String consoleRetry({required Object command}) => 'Se trimite din nou: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => 'Netrimis: ${command} (${reason})';
	@override String get server => 'Server cluster';
	@override String get selectServer => 'Selectează serverul';
	@override String get serverOther => 'Altul';
	@override String serverOtherIncomplete({required Object node}) => 'Niciun server introdus încă, așa că spoturile merg la ${node}';
	@override String get customHost => 'Server';
	@override String get customPort => 'Port';
	@override String get password => 'Parolă';
	@override String get passwordDescription => 'Doar dacă este necesară';
	@override String passwordStored({required Object node}) => 'Parolă salvată pentru ${node}';
	@override String get scrollback => 'Linii păstrate';
	@override String scrollbackOpt({required Object count}) => '${count} linii';
	@override String get connection => 'Conexiune';
	@override String get statusIdle => 'Neconectat. Se conectează când o extensie are nevoie. Atingeți pentru a testa.';
	@override String statusConnecting({required Object node}) => 'Se conectează la ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'Conectat la ${node} ca ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'Nu s-a putut conecta la ${node}: ${reason}';
	@override String get statusUnsupported => 'Nu este disponibil în versiunea web.';
	@override String get statusOff => 'Oprit. Activați „Conectare la cluster” pentru a-l folosi.';
	@override late final _Translations$settings$cluster$errors$ro errors = _Translations$settings$cluster$errors$ro._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$ro extends Translations$settings$spotting$en {
	_Translations$settings$spotting$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotare';
	@override String get respotInterval => 'Auto-respotare la fiecare';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'Auto-respotare implicită';
	@override String get autoRespotByDefaultOn => 'Activează auto-respotarea după orice spot postat';
	@override String get autoRespotByDefaultOff => 'Auto-respotarea se activează doar la cererea dvs.';
	@override String get pulseBeforeRespot => 'Pulsează înaintea fiecărei auto-respotări';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'Controlul Spotare pulsează albastru în cele ${seconds} secunde dinaintea fiecărei respotări';
	@override String get pulseBeforeRespotOff => 'Fără pulsare înaintea unei auto-respotări';
}

// Path: settings.radio
class _Translations$settings$radio$ro extends Translations$settings$radio$en {
	_Translations$settings$radio$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Control CAT';
	@override String get loggingAndCat => 'Înregistrare și CAT';
	@override String get tuningSection => 'Acord';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Servicii';
	@override String get stationConfigurationSection => 'Configurația stației';
	@override String get moreSettings => 'Mai multe setări de configurare a stației';
	@override late final _Translations$settings$radio$units$ro units = _Translations$settings$radio$units$ro._(_root);
	@override late final _Translations$settings$radio$pttKey$ro pttKey = _Translations$settings$radio$pttKey$ro._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$ro smartVfoSnap = _Translations$settings$radio$smartVfoSnap$ro._(_root);
	@override late final _Translations$settings$radio$snapDebounce$ro snapDebounce = _Translations$settings$radio$snapDebounce$ro._(_root);
	@override late final _Translations$settings$radio$snapLongMove$ro snapLongMove = _Translations$settings$radio$snapLongMove$ro._(_root);
	@override late final _Translations$settings$radio$snapMinMove$ro snapMinMove = _Translations$settings$radio$snapMinMove$ro._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$ro snapMinSpeed = _Translations$settings$radio$snapMinSpeed$ro._(_root);
	@override late final _Translations$settings$radio$enterSends$ro enterSends = _Translations$settings$radio$enterSends$ro._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$ro keyerSpeed = _Translations$settings$radio$keyerSpeed$ro._(_root);
	@override late final _Translations$settings$radio$cwMessages$ro cwMessages = _Translations$settings$radio$cwMessages$ro._(_root);
	@override late final _Translations$settings$radio$keyerControl$ro keyerControl = _Translations$settings$radio$keyerControl$ro._(_root);
	@override late final _Translations$settings$radio$voiceMessages$ro voiceMessages = _Translations$settings$radio$voiceMessages$ro._(_root);
	@override late final _Translations$settings$radio$voiceWords$ro voiceWords = _Translations$settings$radio$voiceWords$ro._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$ro avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$ro._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$ro zeroBeatRange = _Translations$settings$radio$zeroBeatRange$ro._(_root);
}

// Path: settings.help
class _Translations$settings$help$ro extends Translations$settings$help$en {
	_Translations$settings$help$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajutor și resurse';
	@override String get description => 'Comunitate și suport';
	@override String get forums => 'Forumurile Ham2K';
	@override String get forumsDescription => 'Găsiți ajutor, oferiți feedback, discutați idei…';
	@override String get chat => 'Chat Ham2K';
	@override String get chatDescription => 'Serverul Discord al comunității noastre online';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videoclipuri și transmisiuni live';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Pentru că nu puteți avea niciodată prea multe fotografii…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Urmăriți-ne pentru noutăți și actualizări';
	@override String get contact => 'Contactați-ne';
	@override String get contactDescription => 'help@ham2k.com — dar încercați mai întâi Forumurile sau Chat-ul!';
}

// Path: settings.exports
class _Translations$settings$exports$ro extends Translations$settings$exports$en {
	_Translations$settings$exports$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporturi';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$ro extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get activities => 'Activități';
	@override String get hunting => 'Vânătoare';
	@override String get contests => 'Concursuri';
	@override String get lookups => 'Căutări';
	@override String get dashboard => 'Panou de bord';
}

// Path: settings.map
class _Translations$settings$map$ro extends Translations$settings$map$en {
	_Translations$settings$map$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hărți';
	@override late final _Translations$settings$map$style$ro style = _Translations$settings$map$style$ro._(_root);
	@override late final _Translations$settings$map$showCallsigns$ro showCallsigns = _Translations$settings$map$showCallsigns$ro._(_root);
	@override late final _Translations$settings$map$showGrayline$ro showGrayline = _Translations$settings$map$showGrayline$ro._(_root);
	@override late final _Translations$settings$map$styleOpts$ro styleOpts = _Translations$settings$map$styleOpts$ro._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$ro extends Translations$settings$privacy$en {
	_Translations$settings$privacy$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confidențialitate';
	@override late final _Translations$settings$privacy$shareAppData$ro shareAppData = _Translations$settings$privacy$shareAppData$ro._(_root);
	@override late final _Translations$settings$privacy$shareOpData$ro shareOpData = _Translations$settings$privacy$shareOpData$ro._(_root);
	@override String get privacyPolicy => 'Politica de confidențialitate';
	@override String get termsOfService => 'Termeni și condiții';
}

// Path: settings.sync
class _Translations$settings$sync$ro extends Translations$settings$sync$en {
	_Translations$settings$sync$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronizare în cloud';
	@override String get moreSettings => 'Mai multe setări de sincronizare';
	@override String get enable => 'Activează sincronizarea';
	@override String get deviceKey => 'Cheia dispozitivului';
}

// Path: settings.peers
class _Translations$settings$peers$ro extends Translations$settings$peers$en {
	_Translations$settings$peers$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispozitive pereche';
	@override String get enable => 'Conectare la alte dispozitive';
	@override String get enableDescription => 'Permite partajarea operațiunilor, înregistrării, CAT și GPS cu alte dispozitive prin rețeaua locală';
	@override String get bleEnable => 'Conectare prin Bluetooth';
	@override String get bleDescription => 'Folosește Bluetooth LE pentru conectare chiar și fără rețea locală';
	@override String get thisDevice => 'Acest dispozitiv';
	@override String get deviceName => 'Nume';
	@override String get deviceNameHint => 'Cum este văzut acest dispozitiv de celelalte dispozitive';
	@override String get pairedDevices => 'Dispozitive asociate';
	@override String get noPairedDevices => 'Niciun dispozitiv asociat încă. Activați această opțiune și pe un alt dispozitiv din această rețea pentru a le asocia.';
	@override String deviceListProblem({required Object error}) => 'Dispozitivele asociate nu pot fi citite: ${error}';
	@override String get nearby => 'În apropiere';
	@override String get connected => 'Conectat';
	@override String get viaBluetooth => 'prin Bluetooth';
	@override String get connecting => 'Se conectează…';
	@override String get syncing => 'Se sincronizează…';
	@override String get waitingForThem => 'Se așteaptă celălalt dispozitiv';
	@override String get notConnected => 'Neconectat';
	@override String get wantsToPair => 'vrea să partajeze această operațiune';
	@override String get allow => 'Permite';
	@override String get link => 'Asociază';
	@override String get reject => 'Respinge';
	@override String get forget => 'Uită';
	@override String forgetTitle({required Object name}) => 'Uitați ${name}?';
	@override String get forgetBody => 'Nu se va mai sincroniza cu acest dispozitiv. Îl puteți permite din nou mai târziu, iar contactele deja înregistrate se păstrează.';
	@override String pairTitle({required Object name}) => 'Asociere cu ${name}';
	@override String get pairBody => 'Acest dispozitiv este în rețeaua dvs. locală și vrea să se conecteze.';
	@override String get pairBodyBle => 'Acest dispozitiv este în apropiere și vrea să se conecteze prin Bluetooth LE.';
	@override String get pairIdLabel => 'ID dispozitiv';
	@override String get pairWarning => 'Asociați doar dispozitive pe care le recunoașteți. Orice dispozitiv din această rețea poate trimite o cerere.';
	@override String get pairWarningBle => 'Asociați doar dispozitive pe care le recunoașteți. Orice dispozitiv din apropiere poate trimite o cerere.';
	@override String problem({required Object error}) => 'Rețeaua locală nu poate fi accesată: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Conectat la ${device}';
	@override String statusLost({required Object device}) => 'Conexiunea cu ${device} s-a pierdut';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispozitive pereche: ${connected} din ${linked} conectate';
	@override String get screenEnable => 'Partajare ecrane și ferestre';
	@override String get screenDescription => 'Permite altor dispozitive să afișeze ecrane sau ferestre de pe acest calculator';
	@override String get screenSources => 'Ecrane și ferestre';
	@override String get screenRefresh => 'Reîmprospătează lista';
	@override String get screenUnsupportedPlatform => 'Acest dispozitiv nu își poate partaja ecranul. macOS poate; orice dispozitiv poate afișa un ecran partajat de altul.';
	@override String get screenUnsupportedVersion => 'Partajarea ecranului necesită macOS 12.3 sau mai nou. Acest dispozitiv poate totuși afișa un ecran partajat de altul.';
	@override String get screenNeedsPermission => 'macOS are nevoie de permisiunea dvs. de înregistrare a ecranului înainte ca această aplicație să poată partaja unul.';
	@override String get screenGrantPermission => 'Cere permisiunea';
	@override String get screenRelaunchAfterGranting => 'Permiteți-o în System Settings la Privacy & Security → Screen Recording, apoi închideți și redeschideți aplicația — macOS anunță aplicația despre schimbare abia la următoarea pornire.';
	@override String screenProblem({required Object error}) => 'Partajare ecran: ${error}';
	@override String get screenChooseTitle => 'Alegeți ce partajați';
	@override String get screenChooseButton => 'Alegeți ce partajați…';
	@override String get screenTabScreens => 'Ecrane';
	@override String get screenTabApps => 'Aplicații';
	@override String get screenTabWindows => 'Ferestre';
	@override String get screenTabEmpty => 'Nu s-a găsit nimic de acest tip.';
	@override String get screenSharedSummaryNone => 'Nimic ales încă.';
	@override String get screenThisDevice => 'Acest dispozitiv';
	@override String screenSharedTo({required Object devices}) => 'Afișat pe ${devices}';
	@override String get screenSharedToNobody => 'Nu este afișat';
	@override String screenStopSharing({required Object name}) => 'Oprește partajarea ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$ro extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configurarea sincronizării';
	@override String get enableTitle => 'Sincronizare cu Ham2K Log Filer';
	@override String get enabledDescription => 'Se face backup și se sincronizează jurnalul pe toate dispozitivele';
	@override String get disabledDescription => 'Oprit — datele rămân doar pe acest dispozitiv';
	@override String get syncing => 'Se sincronizează';
	@override String get account => 'Cont';
	@override String get refresh => 'Reîmprospătează';
	@override String get switchAccounts => 'Schimbă contul';
	@override String get switchAccountsDescription => 'Conectați acest dispozitiv la alt cont cu un cod QR sau prin e-mail';
	@override String get connectionRequests => 'Cereri de conexiune';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Un dispozitiv așteaptă să se alăture acestui cont',
		other: '${n} dispozitive așteaptă să se alăture acestui cont',
	);
	@override String get accountEmailTitle => 'E-mailul contului';
	@override String accountEmailSent({required Object email}) => 'Confirmarea a fost trimisă la ${email}. Deschideți linkul de acolo pentru a finaliza schimbarea.';
	@override String get resendConfirmation => 'Retrimite e-mailul de confirmare';
	@override String resendConfirmationDescription({required Object email}) => 'Se așteaptă confirmarea pentru ${email}';
	@override String accountEmailResent({required Object email}) => 'Retrimis la ${email}.';
	@override String get deviceLinked => 'Acel dispozitiv este acum conectat la acest cont.';
	@override String get checking => 'Se verifică…';
	@override String get notLinked => 'Neconectat încă';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Înlocuiți datele locale?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${n} operațiune',
		other: '${n} operațiuni',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${n} QSO',
		other: '${n} QSO-uri',
	);
	@override String get counts => 'Date sincronizate';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Acest dispozitiv: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Așteaptă încărcarea: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Acest dispozitiv: se verifică…';
	@override String get countsServerChecking => 'Server: se verifică…';
	@override String get countsServerUnavailable => 'Server: indisponibil';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Aceasta salvează și șterge ${operations} și ${qsos} de pe acest dispozitiv, apoi descarcă în locul lor datele contului. Copia de rezervă rămâne în baza de date a acestui dispozitiv.';
	@override String get replace => 'Înlocuiește';
	@override String get pendingBannerTitle => 'A fost detectat un cont Ham2K Log Filer nou';
	@override String get pendingBannerBody => 'Păstrați operațiunile și QSO-urile existente pe acest dispozitiv și combinați-le în cont, sau înlocuiți-le cu datele contului (oricum rămâne o copie de rezervă pe acest dispozitiv).';
	@override String get combine => 'Combină';
	@override String get authIssueTitle => 'Sincronizarea nu se poate conecta';
	@override String get authIssueText => 'Ham2K Log Filer respinge în continuare acest dispozitiv. Verificați indicativul în setările de sincronizare.';
	@override String get openSettings => 'Deschide setările de sincronizare';
}

// Path: settings.accounts
class _Translations$settings$accounts$ro extends Translations$settings$accounts$en {
	_Translations$settings$accounts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Conturi, servicii și surse de date';
	@override String get none => 'Nicio extensie activă cu conturi';
	@override String get notConfigured => 'Neconfigurat';
	@override String get connected => 'Conectat';
	@override String get cancelLogin => 'Anulează autentificarea';
	@override String get openInBrowser => 'Deschide în browser';
	@override String loggedInAs({required Object identity}) => 'Autentificat ca ${identity}';
	@override String get pressSaveToKeep => 'Apăsați Salvează pentru a păstra acest cont conectat.';
	@override String connectedTo({required Object label}) => 'Conectat la ${label}';
	@override String get connect => 'Conectează';
	@override String get disconnect => 'Deconectează';
	@override String get connectedAs => 'Conectat ca';
	@override String get test => 'Testează';
	@override String saveFailed({required Object error}) => 'Salvarea a eșuat: ${error}';
	@override String loginFailed({required Object error}) => 'Autentificarea a eșuat: ${error}';
	@override String get lookupFailed => 'Conturile nu sunt disponibile acum — încercați din nou peste un moment';
	@override String get browserLoginTitle => 'Finalizați autentificarea în browser';
	@override String browserLoginSteps({required Object prefix}) => 'Când terminați, browserul va încerca să deschidă un link care începe cu "${prefix}". Cel mai probabil calculatorul dvs. nu are nimic înregistrat pentru a-l deschide, așa că copiați acel link (din bara de adrese sau din pagina de eroare afișată de browser) și lipiți-l aici.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger nu a putut deschide browserul. Copiați linkul de autentificare de mai jos și deschideți-l singuri, apoi copiați linkul către care vă trimite (începe cu "${prefix}") și lipiți-l aici.';
	@override String get copyLoginLink => 'Copiază linkul de autentificare';
	@override String get pastedLinkLabel => 'Lipiți linkul aici';
	@override String get finishLogin => 'Finalizează autentificarea';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Acesta nu este linkul de autentificare — ar trebui să înceapă cu "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Acest link aparține altei încercări de autentificare. Închideți această pagină și conectați-vă din nou.';
	@override String get pastedLinkNoCode => 'Acest link nu are cod de autentificare. Finalizați mai întâi autentificarea, apoi copiați linkul către care vă trimite.';
	@override String get pastedLinkMalformed => 'Linkul pare trunchiat. Copiați-l integral și lipiți-l din nou.';
	@override String get relayLoginWaiting => 'Se așteaptă finalizarea autentificării — procesul continuă automat după aceea.';
	@override String get loginNoResponse => 'Acest dispozitiv nu a primit încă răspuns de la autentificare. Dacă ați terminat deja în browser, anulați și încercați din nou conectarea.';
	@override String get relayLoginNotOpened => 'Ham2K Logger nu a putut deschide automat browserul. Folosiți butonul de mai jos pentru a deschide singuri pagina de autentificare.';
	@override String get relayLoginUnavailable => 'Serverul de sincronizare necesar pentru această autentificare nu a putut fi accesat. Verificați conexiunea și încercați din nou.';
	@override String get loginIncompleteResponse => 'Încercarea de autentificare nu s-a finalizat corect. Încercați din nou conectarea.';
	@override String get noKeyringTitle => 'Autentificările conturilor nu pot fi salvate';
	@override String get noKeyringText => 'Ham2K Logger nu poate accesa un serviciu keyring pe acest calculator, deci autentificările conturilor nu pot fi stocate sau citite — conectarea unui cont va eșua până la rezolvare. Instalați și porniți **gnome-keyring**, **KWallet** sau **KeePassXC** ori deblocați keyring-ul existent, apoi reporniți. Înregistrarea, exporturile și fișierele de date nu sunt afectate; sincronizarea jurnalului rămâne oprită între timp.';
	@override String get noKeyringInline => 'Autentificările nu pot fi salvate: keyring-ul acestui calculator nu poate fi accesat. Instalați și porniți gnome-keyring, KWallet sau KeePassXC ori deblocați-l pe cel existent.';
	@override String get noSecureStorageInline => 'Autentificările nu pot fi salvate: stocarea securizată a acestui calculator nu poate fi accesată.';
}

// Path: settings.station
class _Translations$settings$station$ro extends Translations$settings$station$en {
	_Translations$settings$station$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurația stației și control CAT';
	@override String get none => 'Niciun echipament configurat';
	@override String get add => 'Adaugă';
	@override String get addTitle => 'Adaugă echipament';
	@override String get searchHint => 'Căutați echipament';
	@override String get noMatches => 'Niciun echipament nu corespunde';
	@override String get detectedEquipment => 'Echipament detectat';
	@override String discoveryUnavailable({required Object error}) => 'Nu se pot căuta stații radio: ${error}';
	@override String get edit => 'Editează echipamentul';
	@override String get name => 'Nume';
	@override String get nameDescription => 'Cum îl numiți — „Stația din stânga”. Opțional.';
	@override String get transport => 'Conexiune';
	@override String get host => 'Adresă';
	@override String get hostDescription => 'Numele de gazdă sau adresa IP a stației radio în rețeaua dvs.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Adresa este obligatorie';
	@override String get portInvalid => 'Portul trebuie să fie între 1 și 65535';
	@override String get connect => 'Conectează';
	@override String get disconnect => 'Deconectează';
	@override String get remove => 'Elimină';
	@override String removeTitle({required Object name}) => 'Eliminați ${name}?';
	@override String get removeMessage => 'Aceasta îl elimină doar din aplicație. Setările echipamentului rămân neschimbate.';
	@override String unknownType({required Object typeKey}) => 'Tip de echipament nerecunoscut „${typeKey}”';
	@override String get report => 'Raportează';
	@override String get reportTitle => 'Raportați această stație radio';
	@override String get reportIntro => 'Spuneți-ne ce stație radio este de fapt și cum a funcționat. Raportul dvs. devine un card citit de echipa Ham2K, iar ce scrieți despre punerea ei în funcțiune poate ajuta următorul operator cu același aparat.';
	@override String get reportManufacturer => 'Producător';
	@override String get reportManufacturerDescription => 'Cine o produce — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Producătorul este obligatoriu';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'Modelul, așa cum îl numește stația însăși — „IC-7300”, „FT-991A”.';
	@override String get reportModelRequired => 'Modelul este obligatoriu';
	@override String get reportOutcome => 'Cum a funcționat?';
	@override String get reportOutcomeWorks => 'A funcționat bine';
	@override String get reportOutcomeIssues => 'A funcționat, cu probleme';
	@override String get reportOutcomeFails => 'Nu a funcționat deloc';
	@override String get reportOutcomeRequired => 'Spuneți-ne cum a funcționat';
	@override String get reportComments => 'Comentarii';
	@override String get reportCommentsPlaceholder => 'Ce a mers, ce nu, orice v-a surprins.';
	@override String get reportHints => 'Sfaturi de depanare';
	@override String get reportHintsPlaceholder => 'Doriți să sugerați sfaturi de depanare pentru alți utilizatori?';
	@override String get reportSend => 'Trimite raportul';
	@override String get reportSending => 'Se trimite raportul…';
	@override String reportSent({required Object ref}) => 'Mulțumim — raportul dvs. a fost înregistrat ca ${ref}.';
	@override String get reportSentNoRef => 'Mulțumim — raportul dvs. a fost trimis.';
	@override String reportFailed({required Object error}) => 'Raportul nu a fost trimis: ${error}';
	@override String get troubleshootingNotes => 'Note de depanare';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Folosește ca VFO principal';
	@override String get serialPort => 'Port serial';
	@override String get serialPortDescription => 'Portul pe care apare interfața CAT a stației radio.';
	@override String get serialPortNone => 'Nu s-au găsit porturi seriale';
	@override String get serialPortRequired => 'Alegeți un port serial';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'portul ${n} din ${total}';
	@override String get serialPortSuggested => 'sugerat';
	@override String get serialPortJustNow => 'Conectat recent';
	@override String get serialPortNoDriver => 'fără driver';
	@override String get serialDeviceRequest => 'Adaugă un dispozitiv USB…';
	@override String get bleDevice => 'Dispozitiv Bluetooth LE';
	@override String get bleDeviceDescription => 'Puntea serială prin care este conectată stația radio, cum ar fi un LiNK500MP în Mode 4 sau un adaptor serial BLE.';
	@override String get bleScan => 'Caută dispozitive Bluetooth LE…';
	@override String get bleScanNoneFound => 'Nu s-a găsit niciun dispozitiv Bluetooth LE. Verificați că puntea este pornită, în apropiere și în modul ei Bluetooth LE (Mode 4 pe un LiNK500MP).';
	@override String bleScanFailed({required Object reason}) => 'Scanarea Bluetooth LE nu a putut rula: ${reason}';
	@override String get bleOff => 'Bluetooth este oprit.';
	@override String get bleDenied => 'Permisiunea Bluetooth nu a fost acordată. Permiteți-o în setările sistemului, apoi încercați din nou.';
	@override String get bleUnsupported => 'Acest dispozitiv nu are Bluetooth LE.';
	@override String get bleStarting => 'Bluetooth încă pornește. Încercați din nou peste un moment.';
	@override String get bleConnectFailed => 'Dispozitivul Bluetooth LE nu poate fi accesat. Verificați că este pornit, în apropiere și neconectat la altă aplicație.';
	@override String bleNoSerialService({required Object services}) => 'Acest dispozitiv Bluetooth LE nu are niciun serviciu serial pe care aplicația să-l recunoască. Raportați-l împreună cu serviciile lui: ${services}';
	@override String get baudRate => 'Viteză (baud)';
	@override String get baudRateDescription => 'Trebuie să corespundă meniului CAT al stației radio. La nepotrivire, stația trimite înapoi date fără sens și nicio eroare.';
	@override String get serialRtsHigh => 'Menține RTS activ';
	@override String get serialRtsHighDescription => 'Doar pentru o stație radio care așteaptă RTS înainte de a răspunde, cum ar fi un Yaesu cu CAT RTS activat. Pe un Digirig, SignaLink și majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă trece pe emisie.';
	@override String get serialDtrHigh => 'Menține DTR activ';
	@override String get serialDtrHighDescription => 'Doar pentru o interfață CAT alimentată din DTR, cum ar fi unele cabluri RS-232 pentru FT-817. Pe multe cabluri DTR manipulează CW sau PTT, iar menținerea lui activă trece pe emisie.';
	@override String get serialUsbDriver => 'Driver cip USB';
	@override String get serialUsbDriverDescription => 'Automat recunoaște majoritatea adaptoarelor. Alegeți cipul doar pentru unul la care lista de porturi spune că nu are driver — îl indică ambalajul sau o listă de dispozitive USB.';
	@override String get serialUsbDriverAuto => 'Automat';
	@override String get civAddress => 'Adresa CI-V a stației radio';
	@override String get civAddressDescription => 'Hex, așa cum apare în meniul CI-V al stației radio. IC-705 vine setat pe A4.';
	@override String get civAddressInvalid => 'O adresă CI-V are două cifre hex, de la 01 la FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Din care slice al stației radio citește și pe care îl acordă această conexiune.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Alegeți unul dintre slice-urile stației radio, de la A la H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} nu este folosit pe această stație radio — alegeți alt slice sau creați-l în SmartSDR';
	@override String get channelNotInUse => 'nefolosit';
	@override String get channelHeldByUnknown => 'folosit de alt program';
	@override String get flexNoSlices => 'Această stație radio nu a raportat niciun slice — verificați că SmartSDR rulează și că acest client se poate abona';
	@override String get spectrumUnsupported => 'Această stație radio nu trimite spectru prin CAT';
	@override String get spectrumRequiresBaud => 'Necesită CAT la 115200 bps';
	@override String get spectrumNoRadio => 'Nicio stație radio conectată';
	@override String get spectrumWaiting => 'Se așteaptă spectrul stației radio…';
	@override String get spectrumUnavailable => 'Afișarea spectrului nu este disponibilă';
	@override String get spectrumNoDaxChannel => 'Toate canalele DAX IQ ale acestei stații radio sunt ocupate';
	@override String get spectrumNoPanadapter => 'Acest slice nu are panadapter pe stația radio';
	@override String spectrumStreamRefused({required Object code}) => 'Stația radio a refuzat un flux DAX IQ (eroare ${code})';
	@override String get spectrumNoUdp => 'Datele de spectru ale stației radio nu pot ajunge la acest dispozitiv';
	@override String get spectrumK4Unavailable => 'Spectrul LAN al K4 nu poate fi recepționat. Se reîncearcă…';
	@override String get spectrumK4RemoteUnavailable => 'Spectrul la distanță al K4 nu poate fi recepționat';
	@override String get spectrumScopeRefused => 'Stația radio a refuzat comenzile de scope';
	@override String get spectrumOutOfRange => 'Scope-ul stației radio este setat în afara intervalului pe care îl poate afișa';
	@override String get spectrumBandUnsupported => 'Scope-ul stației radio nu poate fi afișat pe această bandă';
	@override String get spectrumSdrNoRadio => 'Se așteaptă frecvența stației radio asociate…';
	@override String get spectrumSdrNotConnected => 'SDR-ul nu este conectat';
	@override String get spectrumSdrNoIf => 'Setați frecvența IF a stației radio în setările acestui SDR';
	@override String get sdrRadio => 'Afișează spectrul pentru';
	@override String get sdrRadioDescription => 'O afișare de spectru pe această stație radio folosește acest receptor în locul scope-ului propriu al stației.';
	@override String get sdrRadioMain => 'Stația radio principală';
	@override String get sdrTuning => 'Intrare de antenă';
	@override String get sdrTuningDescription => 'De unde vine semnalul receptorului. Pe propria antenă se acordă singur pentru a urmări stația radio; pe ieșirea IF a stației rămâne pe IF.';
	@override String get sdrTuningIndependent => 'Propria antenă';
	@override String get sdrTuningIfTap => 'Ieșirea IF a stației radio';
	@override String get sdrIfHz => 'Frecvența IF (Hz)';
	@override String get sdrIfHzDescription => 'Doar pentru o ieșire IF: frecvența la care se află scala stației radio pe IF-ul ei, cum ar fi 68330000 pe un FT-817.';
	@override String get sdrIfInverted => 'IF inversat';
	@override String get sdrGainDb => 'Amplificare (dB)';
	@override String get sdrGainDbDescription => 'Lăsați gol pentru amplificarea automată a receptorului.';
	@override String get sdrOffsetHz => 'Decalaj de frecvență (Hz)';
	@override String get sdrOffsetHzDescription => 'Se adaugă la fiecare frecvență trimisă receptorului, pentru un upconverter: 125000000 pentru un Ham It Up.';
	@override String get sdrPpm => 'Corecție de frecvență (ppm)';
	@override String get rtlDirectSampling => 'Eșantionare directă';
	@override String get rtlDirectSamplingDescription => 'Pentru HF pe un RTL-SDR V3 fără upconverter. Un RTL-SDR V4 ajunge în HF fără ea.';
	@override String get rtlDirectSamplingOff => 'Oprit';
	@override String get rtlDirectSamplingI => 'Ramura I';
	@override String get rtlDirectSamplingQ => 'Ramura Q';
	@override String get rtlTcpNotAServer => 'Acesta nu este un server rtl_tcp';
	@override String get rtlTcpNotes => 'Aceasta se conectează la un **server rtl_tcp pe care îl rulați dvs.** pe calculatorul în care este conectat dongle-ul.\n\n- **Porniți-l** cu `rtl_tcp -a 0.0.0.0` ca să poată fi accesat de alte mașini; pe aceeași mașină ajunge `rtl_tcp` simplu.\n- **Portul** este 1234 dacă nu l-ați pornit cu `-p`.\n- **Un singur program odată:** rtl_tcp servește un singur client. Aplicația se conectează doar cât timp este afișat un spectru și eliberează conexiunea câteva secunde după închiderea lui.\n- **Pe Android**, aplicația *SDR driver* rulează același server pe telefon.';
	@override String get rspTcpNotes => 'Aceasta se conectează la un **server rsp_tcp pe care îl rulați dvs.** pe calculatorul în care este conectat RSP-ul, cu API-ul SDRplay instalat acolo.\n\n- **Porniți-l** cu `rsp_tcp -a 0.0.0.0`.\n- **Portul** este 1234 dacă nu l-ați pornit cu `-p`.\n- **Un singur program odată:** serverul acceptă un singur client. Aplicația se conectează doar cât timp este afișat un spectru.';
	@override String get n3fjpNoRig => 'N3FJP nu are configurată o interfață radio, deci aceasta urmează ce se tastează în N3FJP, nu o stație radio';
	@override String get winkeyerKeyPort => 'Ieșire de manipulare';
	@override String get winkeyerKeyPortDescription => 'În care dintre cele două mufe de ieșire ale keyer-ului este conectată stația radio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Portul ${n}';
	@override String get winkeyerPtt => 'Folosește PTT-ul keyer-ului';
	@override String get winkeyerPttDescription => 'Activează linia PTT pe aceeași mufă, pentru un amplificator sau o stație radio care o necesită. Lăsați dezactivat pentru o stație manipulată prin mufa de manipulator.';
	@override String get winkeyerNoAnswer => 'Niciun WinKeyer nu a răspuns pe acest port';
	@override String get winkeyerStoppedAnswering => 'WinKeyer a încetat să răspundă în timpul transmisiei; mesajul a fost abandonat';
	@override String get icomControlPort => 'Port de control (UDP)';
	@override String get icomControlPortDescription => 'Portul de control (UDP) al stației radio — 50001 dacă nu a fost schimbat în setările ei de rețea sau redirecționat către altul.';
	@override String get icomSerialPort => 'Port serial (UDP)';
	@override String get icomSerialPortDescription => 'Portul serial (UDP) al stației radio — 50002 dacă nu a fost schimbat în setările ei de rețea sau redirecționat către altul.';
	@override String get icomPortsDiffer => 'Portul de control și cel serial trebuie să difere';
	@override String get radioUser => 'Utilizator stație radio';
	@override String get radioPass => 'Parolă stație radio';
	@override String get radioLoginDescription => 'Autentificarea Network → Remote a stației radio, nu parola WiFi.';
	@override String get radioUserRequired => 'Utilizatorul pentru controlul la distanță al stației radio este obligatoriu';
	@override String get connectFailedBusy => 'Dispozitivul este ocupat';
	@override String get connectFailedDenied => 'Acces refuzat';
	@override String get connectFailedDevice => 'Dispozitivul nu a fost găsit';
	@override String get connectFailedUnsupported => 'Niciun driver nu recunoaște cipul acestui adaptor USB. Dacă știți ce cip este, alegeți-l la „Driver cip USB” din Setări avansate.';
	@override String get connectFailedLines => 'RTS/DTR nu au putut fi menținute cum au fost setate, așa că portul a fost închis. Alt program poate să fi lăsat activat handshaking-ul hardware — deconectați și reconectați cablul.';
	@override String get connectFailedNetwork => 'Stația radio nu poate fi găsită în rețea. Verificați adresa și că este pornită și accesibilă.';
	@override String connectFailedReplyPort({required Object port}) => 'Portul ${port} de pe acest dispozitiv este deja folosit, iar răspunsurile sosesc acolo. Închideți orice altceva ascultă pe el — inclusiv alt nod PstRotator — sau schimbați portul.';
	@override String get connectFailedTimeout => 'Stația radio nu a răspuns la timp. Verificați că este pornită și accesibilă.';
	@override late final _Translations$settings$station$models$ro models = _Translations$settings$station$models$ro._(_root);
	@override late final _Translations$settings$station$transports$ro transports = _Translations$settings$station$transports$ro._(_root);
	@override String get troubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get ft891Troubleshooting => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **CAT RTS dezactivat pe stația radio sau „Menține RTS activ” pornit.** Cu **CAT RTS** activat (meniul FT-891 **05-08**), stația tace cât timp RTS este jos — poate răspunde o dată la deschiderea portului, apoi nimic. Alegerea portului USB propriu al stației pornește **Menține RTS activ** în Setări avansate. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă vă trece emițătorul pe emisie: în acest caz dezactivați CAT RTS pe stație.\n- **Viteza trebuie să corespundă** cu CAT RATE al stației (meniul **05-06**). La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get yaesuBinaryTroubleshooting => 'Această stație radio folosește vechiul CAT Yaesu de cinci octeți și nu răspunde deloc când ceva nu e în regulă. Aproape întotdeauna este una dintre:\n\n- **Cablul trebuie să convertească nivelurile.** Mufa CAT din spate nu este RS-232 și nici USB; necesită un CT-62 sau un adaptor echivalent. Un simplu cablu audio sau de date nu funcționează pentru CAT.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației (**#14** pe un FT-817, **#19** pe un FT-857 sau FT-897). La nepotrivire, stația nu trimite nimic înapoi, niciodată o eroare.\n- **Nu lăsați nimic să ridice RTS sau DTR pe acest port.** Pe majoritatea cablurilor pentru aceste stații, acele linii sunt PTT și manipulare. Excepția este o interfață mai veche alimentată din DTR: pentru aceasta activați **Menține DTR activ** din Setări avansate.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAcest driver a fost scris după tabelul CAT publicat de Yaesu și nu a fost testat pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.';
	@override String get tenTecTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get tenTecEagleTroubleshooting => '- **Portul USB-B din spate este legătura CAT.** Stația apare ca un port serial USB; pe Windows are nevoie de driverul USB to UART de la Ten-Tec, care apare în Device Manager ca „USB to UART (COMx)”.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis, la fel și programul de actualizare a firmware-ului de la Ten-Tec.\n- **Setarea lățimii filtrului din aplicație o ia de sub controlul butonului BW** până când stația este oprită și repornită. Așa funcționează stația.\n\nAcest driver a fost scris după ghidul de referință pentru programatori de la Ten-Tec. Dacă funcționează pe jumătate, merită raportat, împreună cu versiunea de firmware din meniul stației.';
	@override String get tenTecOrionTroubleshooting => '- **Folosiți un cablu serial DB-9 direct** la portul SERIAL DATA, nu unul null-modem.\n- **Această intrare menține RTS activ**, deoarece Orion folosește RTS și CTS ca handshake. Pe o interfață care comandă PTT din RTS, cum ar fi un Digirig, dezactivați „Menține RTS activ” din Setări avansate, altfel stația emite imediat ce aplicația se conectează.\n- **CW din aplicație necesită keyer-ul intern al stației pornit.** Cu el oprit, stația ignoră ce trimite aplicația.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAcest driver a fost scris după ghidul de referință pentru programatori de la Ten-Tec și nu a fost testat pe un Orion. Dacă funcționează pe jumătate, merită raportat, împreună cu versiunea de firmware din meniul stației.';
	@override String get tenTecNoCw => 'Firmware-ul acestei stații radio nu acceptă CW din aplicație. Ten-Tec l-a adăugat în firmware-ul Orion 1.366.';
	@override String get tenTecKeyerOff => 'Keyer-ul intern al stației radio este oprit, așa că ignoră CW-ul trimis din aplicație. Porniți keyer-ul din meniul stației.';
	@override String get guohetecTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get guohetecTroubleshooting => 'Q900 are două protocoale CAT, iar această intrare folosește protocolul nativ, nu imitația FT-817. Alegeți aici **Guohetec Q900**, nu un FT-817 — imitația acceptă mai puține comenzi, iar stația nu spune pe care îl folosește.\n\n- **Cablul USB-C este legătura CAT** și conectează și placa de sunet. Viteza nu contează pe el; portul ignoră valoarea setată.\n- **Nu lăsați nimic să ridice RTS sau DTR pe acest port.** Pe un cablu serial, acele linii sunt PTT și manipulare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **O stație de a doua generație se comportă diferit** față de prima. Apăsați lung Menu, apoi About: HW 2.0 este a doua generație.\n\nAcest driver a fost scris după protocolul publicat de producător și nu a fost testat pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.';
	@override String get yaesuTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get yaesuTroubleshooting => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **CAT RTS trebuie să fie OFF pe stația radio.** Când este activat, stația așteaptă o linie de handshake pe care aplicația o ține jos. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, aceeași linie este PTT, deci ridicarea ei v-ar trece emițătorul pe emisie. Pe portul USB propriu al stației, alternativa este **Menține RTS activ** din Setări avansate. Locul acestei setări diferă de la model la model (meniul **05-08** pe un FT-891).\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **Modurile urmează tabelul FT-891.** Majoritatea gamei Yaesu corespunde, dar o stație care își numerotează modurile altfel va afișa și va seta modul greșit pentru acestea. Frecvența nu este afectată.';
	@override String get ftdx3000Troubleshooting => '**Meniul 037 CAT SELECT trebuie să fie USB** pentru CAT prin portul USB al stației; setat pe RS232C, CAT este pe mufa din spate.\n\nAceastă intrare a fost scrisă după documentația CAT publicată și nu a fost testată pe un FTDX3000. Dacă funcționează pe jumătate, merită raportat.';
	@override String get yaesuRs232Troubleshooting => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **Mufa CAT este RS-232.** Necesită un adaptor USB-serial și un cablu DB-9 direct — un cablu null-modem inversează liniile, iar stația nu aude nimic.\n- **CAT RTS trebuie să fie OFF pe stația radio.** Când este activat, stația așteaptă o linie de handshake pe care aplicația o ține jos, cu excepția cazului în care **Menține RTS activ** este pornit în Setări avansate.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAceastă intrare a fost scrisă după documentația CAT publicată și nu a fost testată pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.';
	@override String get yaesuUsbTroubleshooting => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **Folosiți primul dintre cele două porturi USB ale stației.** CAT este de obicei pe primul (portul COM **Enhanced** pe Windows); al doilea (**Standard**) este pentru PTT și manipulare. Selectorul indică primul port ori de câte ori le poate deosebi.\n- **CAT RTS dezactivat pe stația radio sau „Menține RTS activ” pornit.** Cu meniul **CAT RTS** al stației activat, aceasta tace cât timp RTS este jos — poate răspunde o dată la deschiderea portului, apoi nimic. Alegerea portului USB propriu al stației pornește **Menține RTS activ** în Setări avansate. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă vă trece emițătorul pe emisie: în acest caz dezactivați CAT RTS pe stație.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.';
	@override String get k4SerialNotes => 'Conectați mufa USB-B (PC) din spatele K4. Atât USB-PC1, cât și USB-PC2 funcționează pentru CAT; alegeți un port nefolosit și potriviți setarea Serial USB-PCn: Baud Rate de pe stație. HaLo completează 38400; schimbați dacă e nevoie. O altă aplicație trebuie să folosească celălalt port sau Ethernet.\n\nAceastă conexiune controlează stația și keyer-ele ei; nu trimite audio către HaLo.';
	@override String get k4TcpNotes => 'Conectați mufa Ethernet a K4 la rețeaua locală. Introduceți numele de gazdă sau adresa IP și portul CAT 9200. HaLo folosește același host pe portul fix 9201 când este vizibil un panadapter sau un waterfall; schimbarea portului CAT nu schimbă portul de spectru.\n\nSpectrul arată receptorul principal. Controalele lui de zoom, de ajustare a referinței și de viteză afectează doar afișarea din HaLo. Transmisia audio nu este acceptată.';
	@override String get k4PowerTimeout => 'Puterea K4 nu a fost schimbată deoarece stația nu a confirmat intervalul de ieșire. Încercați din nou.';
	@override String get k4RemoteNotes => 'Activați accesul la distanță pe K4 și introduceți parola lui de rețea. Main și Sub folosesc o singură conexiune criptată pentru controlul stației și spectru. Portul implicit este 9204; introduceți portul redirecționat când vă conectați de la distanță.\n\nRedarea audio și transmisia microfonului nu sunt acceptate.';
	@override String get k4Receiver => 'Receptor';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'Alegeți Main sau Sub';
	@override String get k4ReceiverAlreadyConfigured => 'Acel receptor este deja configurat pentru acest K4';
	@override String get k4SubReceiverOff => 'Receptorul Sub al K4 este oprit';
	@override String get k4RemotePasswordRequired => 'Introduceți parola de rețea a K4 pentru o conexiune securizată.';
	@override String get k4RemoteHandshakeFailed => 'K4 nu a putut stabili o conexiune securizată. Verificați parola de rețea și setările de acces la distanță.';
	@override String get k4RemoteUnreachable => 'Conexiunea securizată a K4 nu a putut fi accesată. Verificați adresa, portul și setările de acces la distanță.';
	@override String get k4PowerRange => 'Puterea K4 trebuie să fie 0.1–110 W sau 0.0001–0.01 W când ieșirea de miliwați a transverterului este activă.';
	@override String get elecraftTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get elecraftTroubleshooting => 'Stațiile Elecraft folosesc CAT Kenwood, iar un KX2 și un KX3 au fost ambele testate astfel — VFO în ambele direcții, schimbarea modului și zero-beat CW funcționează toate.\n\nDacă stația nu răspunde, aproape întotdeauna este una dintre:\n\n- **Viteza trebuie să corespundă** cu rata setată la **RS232** în meniul stației. Acestea vin setate pe 38400. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\n**Dacă frecvența este corectă, dar modul este greșit**, spuneți-ne. Intrările KX2 și KX3 citesc modul dintr-o poziție a răspunsului de stare pe care am fixat-o după stațiile văzute, iar un firmware care îl pune în altă parte ajunge la noi doar printr-un raport.\n\nK3 nu a fost raportat încă în niciun sens, așa că spuneți-ne ce se întâmplă dacă folosiți unul. K4 are propria intrare.';
	@override String get lab599TroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get lab599Troubleshooting => 'Gama TX-500 folosește CAT Kenwood. Frecvența și modul au fost testate printr-un LiNK500MP; puterea și instrumentele sunt scrise după referința CAT de la Lab599, așa că raportați ce se întâmplă în orice caz.\n\n- **Viteza trebuie să corespundă** cu setarea CAT a stației, 9600 dacă nu ați schimbat-o. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Alegeți protocolul CAT pe stație.** TS-2000 acoperă frecvența, modul și puterea. LAB599 permite în plus aplicației să treacă stația pe DIG, să vadă că emite în DIG și să citească tensiunea de alimentare.\n- **Printr-un LiNK500MP**, apăsați lung butonul VFO cam trei secunde pentru a preda controlul CAT interfeței.\n- **Setați modul LiNK500MP potrivit conexiunii**: Mode 3 pentru Bluetooth, Mode 4 pentru Bluetooth LE. În orice alt mod, o scanare Bluetooth LE nu îl găsește.\n- **Prin Bluetooth**, LiNK500MP se asociază ca două porturi seriale și doar unul transportă CAT. Dacă stația tace, alegeți-l pe celălalt.';
	@override String get lab599TroubleshootingIos => 'Gama TX-500 folosește CAT Kenwood. Frecvența și modul au fost testate printr-un LiNK500MP; puterea și instrumentele sunt scrise după referința CAT de la Lab599, așa că raportați ce se întâmplă în orice caz.\n\n- **Setați LiNK500MP pe Mode 4**, modul lui Bluetooth LE, înainte de a-l căuta. În orice alt mod, un iPhone sau iPad nu îl poate găsi.\n- **Predați controlul CAT către LiNK500MP**: apăsați lung butonul VFO al stației cam trei secunde.\n- **Alegeți protocolul CAT pe stație.** TS-2000 acoperă frecvența, modul și puterea. LAB599 permite în plus aplicației să treacă stația pe DIG, să vadă că emite în DIG și să citească tensiunea de alimentare.';
	@override String get kenwoodTroubleshootingTitle => 'Dacă stația radio se conectează, dar nu afișează frecvența';
	@override String get kenwoodTroubleshooting => 'Acest driver este verificat pe TS-590SG și TS-480 de la Kenwood, QMX și QCX-mini de la QRP Labs și KX2 și KX3 de la Elecraft. Restul gamei este scris după referințe CAT publicate, așa că raportați ce se întâmplă în orice caz.\n\nDacă stația nu răspunde, aproape întotdeauna este una dintre:\n\n- **Viteza trebuie să corespundă** cu meniul CAT al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **Unele stații necesită activarea CAT** în meniu înainte de a răspunde.\n- **Stațiile Kenwood așteaptă RTS**: portul lor CAT îl folosește ca handshake, așa că „Menține RTS activ” (din Setări avansate) trebuie să fie pornit. O conexiune configurată înainte ca această opțiune să fie pornită implicit poate să o aibă oprită. Pe un Digirig sau alt cablu care comandă PTT din RTS, opriți-o, altfel stația emite.\n\n**Mai multe front-end-uri SDR folosesc același protocol**, deci merită încercată această intrare și pentru ele; stațiile Elecraft sunt listate separat, la Elecraft. Dacă frecvența este corectă, dar modul este greșit sau lipsește, aceasta este singura parte care diferă în gamă — aplicația îl deduce din stație și revine la o interogare directă, deci modul poate doar să apară cu întârziere.';
	@override String get statusConnected => 'Conectat';
	@override String get statusLost => 'Deconectat';
	@override String get notConfigured => 'Neconfigurat';
	@override String get currentConfiguration => 'Configurația curentă';
	@override String get currentTransceiver => 'Transceiver curent';
	@override String get currentTransceivers => 'Transceivere curente';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => 'Mesajele se pun în coadă în loc să întrerupă';
	@override String get noRadioBSelected => 'Niciun Radio B selectat';
	@override String get radioMode => 'Modul stației';
	@override String get keyerNotSupported => 'Nu este acceptat de stația curentă';
	@override String get catControlPreferences => 'Preferințe control CAT';
	@override String get chooseTransceiver => 'Alegeți transceiverul';
	@override String get configurationSection => 'Configurație';
	@override String get noTransceiverSelected => 'Niciun transceiver selectat';
	@override String makeMainVfo({required Object name}) => 'Folosește ${name} pentru VFO principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		zero: 'Niciun transceiver',
		one: '${count} transceiver',
		other: '${count} transceivere',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} antenă',
		other: '${count} antene',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} alt dispozitiv',
		other: '${count} alte dispozitive',
	);
	@override String get equipmentInventory => 'Inventar echipamente';
	@override String get equipmentInUse => 'Controale transceiver';
	@override String get noTransceiver => 'Niciunul';
	@override String get peerRadioNotAvailable => 'Indisponibil';
	@override String peerRadioOnDevice({required Object device}) => 'Pe ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} este pe alt dispozitiv';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Această stație radio este conectată la ${device}. Conexiunea și setările ei se configurează pe acel dispozitiv.';
	@override String get antennaInUse => 'Antena folosită';
	@override String get keyInUse => 'Manipulare CW';
	@override String get phoneKeying => 'Keyer fonie';
	@override String get phoneKeyingNone => 'Niciunul';
	@override String phoneKeyingRadio({required Object radio}) => 'Memoriile din ${radio}';
	@override String get phoneKeyingComputer => 'Audio din acest calculator';
	@override String get phoneKeyingOff => 'Keyer-ul fonie este oprit';
	@override String get computerVoiceSettings => 'Audio calculator';
	@override String get cwKeyingOptions => 'Opțiuni manipulare CW';
	@override String get noneSelected => 'Niciunul';
	@override String get moreSettings => 'Mai multe setări';
	@override String get icomCivTroubleshootingTitle => 'Dacă apar două porturi seriale pentru aceeași stație';
	@override String get icomCivTroubleshooting => 'Mai multe stații Icom, printre care IC-705, prezintă **două** porturi seriale USB simultan (Icom le numește Port A și Port B), ambele setate implicit pe CI-V. Nici aplicația, nici sistemul de operare nu le pot deosebi altfel: același ID USB de producător/produs apare de două ori, uneori marcat aici cu sufixul `#2`. **Port A este de obicei cel corect** — în mod normal primul listat de sistem sau de browser, iar acolo unde aplicația poate deosebi cele două porturi îl marchează ca sugerat. Dacă comenzile pleacă și stația nu răspunde niciodată, încercați celălalt port.';
	@override String get civAddressTroubleshootingTitle => 'Dacă stația radio nu răspunde niciodată';
	@override String get civAddressTroubleshooting => '- **Adresa CI-V trebuie să corespundă** cu meniul stației. Această intrare completează adresa cu care vine modelul, dar o stație care împarte o magistrală CI-V este exact cazul în care aceasta se schimbă. Un cadru trimis la adresa greșită este ignorat în tăcere, ceea ce arată exact ca un cablu defect.\n- **Viteza trebuie să corespundă** cu CI-V BAUD RATE al stației (pe USB, CI-V USB Baud Rate). Setați stația la același număr afișat aici, **nu pe Auto**. Pe Auto, unele stații, printre care IC-7300, se conectează și apoi nu mai răspund după aproximativ un minut.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **Adresa CI-V trebuie să corespundă** cu meniul stației. Această intrare completează adresa cu care vine modelul, dar o stație care împarte o magistrală CI-V este exact cazul în care aceasta se schimbă. Un cadru trimis la adresa greșită este ignorat în tăcere, ceea ce arată exact ca un cablu defect.\n${speed}\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.';
	@override String get icomUsbSpeedFollows => '- **Nu există o viteză de setat.** Prin USB, această stație vorbește la viteza folosită de calculator, iar această intrare folosește întotdeauna 115200, viteza de care are nevoie scope-ul.';
	@override String get ic7610UsbSpeed => '- **Setați CI-V USB Baud Rate la 115200**, viteza pe care această intrare o folosește întotdeauna, deoarece scope-ul are nevoie de ea — **nu pe Auto**. O stație setată pe orice altă viteză răspunde cu tăcere.';
	@override String get civTransceiveTitle => 'Dacă aplicația urmărește stația radio cu întârziere';
	@override String get civTransceive => 'Dacă aplicației îi iau câteva secunde să afișeze o schimbare de frecvență sau de mod făcută pe stație, porniți setarea **CI-V Transceive** a stației (pe majoritatea modelelor actuale, la SET > Connectors > CI-V). Cu ea pornită, stația raportează fiecare schimbare în momentul în care are loc. Cu ea oprită, aplicația vede o schimbare doar la următoarea interogare, la câteva secunde.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** vine cu adresa `B6`, nu `94` completată aici — alegeți în schimb intrarea IC-7300 MK2.';
	@override String get ic705PortNote => '\n- **IC-705** prezintă două porturi seriale USB, ambele numite după stație. CI-V este pe **primul** dintre ele, pe care selectorul îl indică ori de câte ori le poate deosebi.';
	@override String get ic7760PortNote => '\n- **IC-7760** folosește CI-V pe **Port A** dintre cele două porturi seriale USB pe care le prezintă.';
	@override String get x6100PortNote => '\n- **X6100** folosește CI-V pe portul **DEV** — al doilea dintre cele două porturi seriale pe care le prezintă și cel indicat de selector.';
	@override String get rigctldTroubleshootingTitle => 'Dacă aplicația nu se poate conecta';
	@override String get rigctldTroubleshooting => 'Aceasta se conectează la un **daemon rigctld pe care îl rulați singuri**, nu direct la stația radio — backend-ul Hamlib comunică cu stația și acceptă sute de modele.\n\n- **Daemonul trebuie să ruleze deja**, de ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Aflați numărul de model al stației cu `rigctl -l`.\n- **De pe alt calculator**, porniți-l cu `-T 0.0.0.0`: implicit rigctld acceptă conexiuni doar de pe calculatorul pe care rulează.\n- **Portul** este 4532, dacă nu ați pornit daemonul cu `-t`.\n- După conectare, o frecvență lipsă înseamnă de obicei că daemonul însuși nu poate accesa stația. Testați-l cu `rigctl -m 2 f` pe calculatorul daemonului.';
	@override String get flrigTroubleshootingTitle => 'Dacă aplicația nu se poate conecta';
	@override String get flrigTroubleshooting => 'Aceasta se conectează la un **program flrig pe care îl rulați singuri**, nu direct la stația radio — flrig comunică cu stația și acceptă majoritatea mărcilor și modelelor.\n\n- **flrig trebuie să ruleze deja**, cu transceiverul configurat și conectat.\n- **Portul** este 12345, dacă nu l-ați schimbat în configurația flrig (Config → Setup → Server).\n- **De pe alt calculator**, asigurați-vă că serverul flrig este accesibil. Ascultă pe toate interfețele, dar firewall-ul poate să nu fie de acord.\n- După conectare, o frecvență lipsă înseamnă de obicei că flrig însuși nu poate accesa stația. Verificați că afișajul flrig urmărește butonul de acord.';
	@override String get hrdTroubleshootingTitle => 'Dacă aplicația nu se poate conecta';
	@override String get hrdTroubleshooting => 'Aceasta se conectează la **Rig Control din Ham Radio Deluxe, care rulează pe calculatorul dvs.**, nu direct la stația radio — HRD comunică cu stația.\n\n- **Rig Control trebuie să ruleze deja** și să fie conectat la stație.\n- **Serverul IP al acestuia trebuie să fie activat.** Rig Control comunică cu alte programe doar prin el.\n- **Portul** este 7809, dacă nu l-ați schimbat în setările serverului IP.\n- **De pe alt calculator**, asigurați-vă că firewall-ul permite conexiunea.\n\nAceastă intrare a fost scrisă după descrieri publicate ale protocolului HRD și nu a fost testată cu HRD. Dacă funcționează pe jumătate, merită raportat.';
	@override String get n3fjpTroubleshootingTitle => 'Dacă aplicația nu se poate conecta';
	@override String get n3fjpTroubleshooting => 'Aceasta se conectează la **un program de log N3FJP care rulează pe calculatorul dvs.**, nu direct la stația radio — N3FJP comunică cu stația.\n\n- **API-ul programului trebuie să fie activ**: Settings → Application Program Interface, bifați **TCP API Enabled**.\n- **Portul** este 1100, dacă nu l-ați schimbat acolo.\n- **N3FJP trebuie să aibă configurată o interfață radio** pentru a urmări sau acorda stația. Fără una, raportează doar ce se tastează în fereastra de introducere.\n- N3FJP raportează doar banda, modul și frecvența: fără putere, fără starea de emisie.\n\nAceastă intrare a fost scrisă după API-ul publicat de N3FJP și nu a fost testată cu N3FJP. Dacă funcționează pe jumătate, merită raportat.';
	@override String get commanderTroubleshootingTitle => 'Dacă aplicația nu se poate conecta';
	@override String get commanderTroubleshooting => 'Aceasta se conectează la **DXLab Commander, care rulează pe calculatorul dvs.**, nu direct la stația radio — Commander comunică cu stația.\n\n- **Commander trebuie să ruleze deja** și să fie conectat la stație.\n- **Serviciul de rețea trebuie să fie activ**: butonul **Net Serv** din panoul Radio al ferestrei Configuration din Commander.\n- **Portul** este 52002, al treilea port din blocul care începe la **Base Port** din Net Serv (52000, dacă nu l-ați schimbat).\n- **De pe alt calculator**, asigurați-vă că firewall-ul permite conexiunea.\n\nAceastă intrare a fost scrisă după mesajele TCP publicate de Commander și nu a fost testată cu Commander. Dacă funcționează pe jumătate, merită raportat.';
	@override String get ic705TroubleshootingTitle => 'Dacă stația radio nu răspunde niciodată';
	@override String get ic705Troubleshooting => 'Stația are o **singură** sesiune de control la distanță. Când autentificarea este ignorată, aproape întotdeauna altceva o folosește.\n\n- **Închideți orice alt client.** wfview sau RS-BA1 conectat la aceeași stație ocupă acea sesiune, iar autentificarea de aici este pur și simplu ignorată cât timp o face.\n- **Verificați setările de rețea ale stației.** WLAN trebuie să fie activ, stația trebuie să fie în aceeași rețea, iar funcția de control la distanță (Network) trebuie să fie activată.\n- **Porturile trebuie să corespundă** cu Control Port și Serial Port (UDP) ale stației sau cu porturile redirecționate către ele. Un port greșit este întâmpinat cu tăcere, la fel ca o stație oprită.\n- **Reporniți WLAN-ul stației** dacă rămâne blocată. Aceasta eliberează sigur o sesiune blocată pe stație.\n\nO **parolă greșită este refuzată explicit**, nu întâmpinată cu tăcere. Dacă ați ajuns aici în loc de un mesaj „respins”, parola nu este problema.';
	@override String get icomLanTroubleshooting => 'Stația are o **singură** sesiune de control la distanță. Când autentificarea este ignorată, aproape întotdeauna altceva o folosește.\n\n- **Închideți orice alt client.** wfview, RS-BA1 sau Remote Utility de la Icom conectat la aceeași stație ocupă acea sesiune, iar autentificarea de aici este pur și simplu ignorată cât timp o face.\n- **Verificați setările de rețea ale stației.** Portul ei LAN trebuie să fie conectat la aceeași rețea ca acest dispozitiv, **Network Control** trebuie să fie activat, iar numele de utilizator și parola trebuie să fie configurate ca utilizator de rețea pe stație.\n- **Porturile trebuie să corespundă** cu Control Port și Serial Port (UDP) ale stației sau cu porturile redirecționate către ele. Un port greșit este întâmpinat cu tăcere, la fel ca o stație oprită.\n- **Dacă se conectează, dar nu răspunde niciodată**, adresa CI-V de aici trebuie să corespundă cu meniul CI-V ADDRESS al stației. Această intrare completează adresa cu care vine modelul.\n- **Opriți și reporniți stația** dacă rămâne blocată.';
	@override String get statusStale => 'Nu răspunde';
	@override String get statusDisconnected => 'Neconectat';
	@override String get statusConnecting => 'Se conectează…';
	@override String get statusDisconnecting => 'Se deconectează…';
	@override String get statusError => 'Conectarea a eșuat';
	@override String get currentRadioSettings => 'Setările curente ale stației';
	@override String get notSupportedByThisRadio => 'Nu este acceptat de această stație';
	@override String get cwMessagesButton => 'Mesaje CW';
	@override String get voiceMessagesButton => 'Mesaje fonie';
	@override String voiceKeyerAvailable({required Object count}) => 'Keyer vocal: ${count} memorii în stație';
	@override String get antennaBands => 'Benzi';
	@override String get antennaType => 'Tip de antenă';
	@override String get antennaTypeRequired => 'Alegeți un tip de antenă';
	@override late final _Translations$settings$station$antennaTypes$ro antennaTypes = _Translations$settings$station$antennaTypes$ro._(_root);
	@override String get keyType => 'Tip de manipulator';
	@override String get keyTypeRequired => 'Alegeți un tip de manipulator';
	@override late final _Translations$settings$station$keyTypes$ro keyTypes = _Translations$settings$station$keyTypes$ro._(_root);
	@override String get softwareIntermediaries => 'Intermediari software';
	@override String get otherBrands => 'Alte mărci';
	@override String get otherEquipment => 'Alte echipamente (antene, manipulatoare etc.)';
	@override String get newAntenna => 'Antenă nouă';
	@override String get newKey => 'Manipulator nou';
	@override String get newKeyer => 'WinKeyer (K1EL sau compatibil)';
	@override String keyViaRadio({required Object radio}) => 'Keyer CAT în ${radio}';
	@override String keyOnDevice({required Object device}) => 'Manipulator pe ${device}';
	@override String get trackStationInfo => 'Înregistrează informațiile stației la fiecare QSO';
	@override String get includeStationInfoInAdif => 'Include în exporturile ADIF';
	@override String get whatToTrack => 'Ce se înregistrează?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Putere';
	@override String get watts => 'Wați';
	@override String get trackFieldAntenna => 'Antenă';
	@override String get trackFieldKey => 'Manipulator CW';
	@override String get placeholderConnectDelay => 'Întârziere la conectare (ms)';
	@override String get placeholderConnectDelayDescription => 'Cât durează handshake-ul simulat. Gol sau 0 se conectează instantaneu.';
	@override String get placeholderDropAfter => 'Deconectare după (secunde)';
	@override String get placeholderDropAfterDescription => 'Închide conexiunea singură, pentru a testa reconectarea. Gol sau 0 nu deconectează niciodată.';
	@override String get placeholderFailConnect => 'Eșuează mereu la conectare';
	@override String get placeholderConnectFailure => 'Stația substituent a fost instruită să refuze această conexiune';
	@override String get placeholderFreq => 'Frecvență (kHz)';
	@override String get placeholderFreqDescription => 'Unde pornește stația substituent. Ulterior raportează orice frecvență setează aplicația.';
	@override String get placeholderMode => 'Mod';
	@override String get placeholderModeDescription => 'Modul în care pornește stația substituent, de ex. USB, CW, FT8.';
	@override String get placeholderPower => 'Putere (wați)';
	@override String get placeholderPurpose => 'Folosiți această stație pentru a ține evidența aparatului folosit, în scopul înregistrării';
	@override String get placeholderReplyDelay => 'Întârziere la răspuns (ms)';
	@override String get placeholderReplyDelayDescription => 'Cât îi ia stației substituent să raporteze o schimbare. Gol sau 0 răspunde imediat.';
	@override String get cwKeyerField => 'Keyer CW prin CAT';
	@override String get cwKeyerFieldDescription => 'Dacă această stație manipulează CW din text prin CAT. Dezactivat pentru o stație pe care aplicația nu o cunoaște.';
	@override String get voiceMemories => 'Memorii vocale';
	@override String get voiceMemoriesDescription => 'Câte memorii vocale redă stația prin CAT. 0 pentru niciuna.';
	@override String get voiceMemoriesInvalid => 'Un număr întreg, 0 sau mai mare';
	@override String get yaesuMeterCapture => 'Capturează citirile instrumentelor';
	@override String get yaesuBinaryMeterCaptureDescription => 'Citește instrumentul de putere de ieșire și indicatorul de SWR ridicat în timpul emisiei și scrie valorile brute în jurnalul de diagnostic. Pentru construirea scalei pe care Yaesu nu o publică — valorile nu sunt afișate ca instrumente.';
	@override String get yaesuMeterCaptureDescription => 'Citește instrumentele PO, SWR și ALC ale stației în timpul emisiei și scrie valorile brute în jurnalul de diagnostic. Pentru construirea scalei pe care Yaesu nu o publică — valorile nu sunt afișate ca instrumente.';
	@override String get telemetryInterval => 'Interval de citire a instrumentelor (ms)';
	@override String get telemetryIntervalDescription => 'Cât de des se citesc instrumentele stației în timpul emisiei. Lăsați gol pentru cea mai mare viteză suportată de conexiune, până la 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Un număr întreg de milisecunde, de la ${min} la ${max}';
	@override String get pollInterval => 'Interval de interogare în repaus (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Cât de des se cer stației frecvența și modul cât timp niciunul nu se schimbă. Lăsați gol pentru ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Un număr întreg de milisecunde, de la ${min} la ${max}';
	@override String get advancedSettings => 'Setări avansate';
	@override String get placeholderSwr => 'Valoare SWR';
	@override String get placeholderSwrDescription => 'Ce raportează această stație pe instrumentul SWR în timpul emisiei. Peste 1.8 panoul avertizează.';
	@override String get placeholderSwrInvalid => 'Un număr, 1 sau mai mare';
	@override String get keyerNone => 'Niciunul';
	@override String get cwDialect => 'Dialect de manipulare CW';
	@override String get cwDialectDescription => 'Ce formă a comenzii KY acceptă această stație. Niciunul înseamnă fără manipulare CW prin CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, completat la 24)';
	@override String get cwDialectElecraft => 'Elecraft (text KY)';
	@override String get voiceDialect => 'Dialect de keyer vocal';
	@override String get voiceDialectDescription => 'Cum redă această stație memoriile vocale prin CAT. Niciunul înseamnă fără memorii vocale prin CAT. Cu un dialect și fără număr, se aplică numărul implicit al dialectului.';
	@override String get voiceDialectPb => 'Kenwood (PB, stil TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB și DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (apăsări de butoane)';
	@override String get placeholderDiagnostic => 'Simulat';
	@override String get placeholderWholeNumberInvalid => 'Trebuie să fie un număr întreg, 0 sau mai mare';
	@override String get placeholderFreqInvalid => 'Trebuie să fie o frecvență în kHz, mai mare decât zero';
	@override String get placeholderModeInvalid => 'Trebuie să fie un nume de mod, de ex. USB, CW, FT8';
	@override String get switchLayout => 'Configurație';
	@override String get switchLayoutDescription => 'Pe ce parte a comutatorului sunt conectate stațiile radio.';
	@override String get switchLayoutRequired => 'Alegeți cum este cablat comutatorul';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Comutatorul a refuzat "${command}" (eroare ${code})';
	@override String get switchBusyTransmitting => 'Acel port este pe emisie — antena nu a fost schimbată';
	@override String get switchNoAntenna => 'Niciuna';
	@override String switchAntennaFor({required Object port}) => 'Antena de pe portul ${port}';
	@override String get switchAntennaForDescription => 'Care dintre antenele dvs. este conectată la acest port al comutatorului.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antene, ${radios} stații radio';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antene, 1 stație radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antenă, ${radios} stații radio';
	@override String get switchCommonPort => 'Comun';
	@override String get dcnAddress => 'Adresa dispozitivului';
	@override String get dcnAddressDescription => 'Adresa setată pe comutatoarele DIP ale modulului. Un modul releu coaxial vine din fabrică setat pe 2.';
	@override String get dcnAddressRequired => 'Trebuie să fie o adresă de dispozitiv între 1 și 99';
	@override String switchPortLabel({required Object port}) => 'Portul ${port}';
	@override String get switchPortAutoHint => 'urmează datele de bandă';
	@override String get switchPortTransmittingHint => 'pe emisie — nu se poate schimba acum';
	@override String get switchCurrentStateHeader => 'Starea curentă';
	@override String get switchCurrentStateDescription => 'Pe ce antenă este acum fiecare port de stație. Modificările se aplică imediat.';
	@override String get switchWiringHeader => 'Cablare';
	@override String get switchPortInhibitedHint => 'emisie blocată';
	@override String get rotatorAxes => 'Axe';
	@override String get rotatorAxesDescription => 'Dacă rotorul se rotește doar în azimut sau și în elevație (un G-5500 sau similar).';
	@override String get rotatorAxesAzimuth => 'Doar azimut';
	@override String get rotatorAxesAzimuthElevation => 'Azimut și elevație';
	@override String get rotatorAzimuthOffset => 'Decalaj de azimut';
	@override String get rotatorAzimuthOffsetDescription => 'Grade de adăugat la ce citește controlerul, când zeroul lui nu este nordul adevărat. Rotirile sunt corectate corespunzător.';
	@override String get rotatorElevationOffset => 'Decalaj de elevație';
	@override String get rotatorAzimuthMin => 'Azimut minim';
	@override String get rotatorAzimuthMax => 'Azimut maxim';
	@override String get rotatorAzimuthMaxDescription => 'În gradele proprii ale controlerului. Peste 360 pentru un rotor cu suprapunere, care alege apoi rotirea mai scurtă.';
	@override String get rotatorElevationMin => 'Elevație minimă';
	@override String get rotatorElevationMax => 'Elevație maximă';
	@override String get rotatorElevationMaxDescription => 'În gradele proprii ale controlerului. Peste 90 pentru un rotor care poate trece peste zenit.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => 'Grade întregi, de la ${min} la ${max}';
	@override String get rotatorLimitsInvalid => 'Limita minimă trebuie să fie sub cea maximă';
	@override String get rotatorPollInterval => 'Interval de interogare (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'Cât de des se întreabă rotorul încotro arată. Lăsați gol pentru ${fallback} ms.';
	@override String get rotatorAxesRequired => 'Alegeți pe ce axe se rotește rotorul';
	@override String get rotatorRefused => 'Controlerul a refuzat o comandă. Verificați că este setat în modul GS-232.';
	@override String get pstRotatorTroubleshooting => 'PstRotator răspunde doar după ce este configurat pentru asta, altfel nu spune absolut nimic:\n\n- **Activați UDP Control** din meniul Setup al PstRotator.\n- **Potriviți portul**: Communication → UDP Control Port, 12000 dacă nu a fost schimbat. PstRotator răspunde pe portul imediat următor (12001), care trebuie să fie liber pe acest dispozitiv.\n- **Conectați PstRotator la controlerul lui.** Până atunci, nu răspunde nimic prin UDP.\n- **Permiteți-l prin firewall** pe PC-ul care rulează PstRotator și pe acest dispozitiv, care ascultă răspunsurile.\n- **Pe un Mac, iPhone sau iPad**, Ham2K Logger are nevoie de acces la rețeaua locală (Settings → Privacy & Security → Local Network).';
	@override String rotatorCurrentStateHeader({required Object position}) => 'Starea curentă: ${position}';
	@override String get rotatorDisconnected => 'deconectat';
	@override String rotatorAzimuthReading({required Object degrees}) => '${degrees}° azimut';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '${degrees}° az';
	@override String rotatorElevationReading({required Object degrees}) => '${degrees}° elevație';
	@override String rotatorElevationReadingShort({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNoReading => 'Se așteaptă ca controlerul să raporteze poziția…';
	@override String get rotatorNotResponding => 'nu răspunde';
	@override String rotatorHeldAtLimit({required Object heading}) => 'Se rotește spre ${heading}, cât permit limitele acestui rotor';
	@override String get rotatorTargetAzimuth => 'Rotește la azimutul';
	@override String get rotatorTargetAzimuthShort => 'Rotește la az';
	@override String get rotatorTargetElevation => 'Rotește la elevația';
	@override String get rotatorTargetElevationShort => 'Rotește la el';
	@override String get rotatorAzimuthInvalid => 'Trebuie să fie între 0 și 360';
	@override String get rotatorElevationInvalid => 'Trebuie să fie între 0 și 180';
	@override String get rotatorTurn => 'Rotește';
	@override String get rotatorStop => 'Stop';
	@override String get configUnreadable => 'Setările salvate ale acestei stații nu au putut fi citite. Deschideți setările și introduceți-le din nou sau eliminați-o și adăugați-o din nou.';
	@override String get autoConnectHeld => 'HaLo a încetat să răspundă ultima dată când s-a conectat la această stație, așa că de data aceasta nu s-a conectat singur. Apăsați Conectează pentru a încerca din nou.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$ro extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Date offline';
	@override String get noFiles => 'Niciun fișier de date';
	@override String get noFilesDescription => 'Activați extensii de activitate sau de căutare pentru a le descărca aici datele offline.';
	@override String get refresh => 'Reîmprospătează';
	@override String get refreshing => 'Se reîmprospătează…';
	@override String get updateAll => 'Actualizează tot';
	@override String get updatingAll => 'Se actualizează toate fișierele de date…';
	@override String get neverDownloaded => 'Nedescărcat niciodată';
	@override String get updatedJustNow => 'Actualizat chiar acum';
	@override String updatedDaysAgo({required Object days}) => 'Actualizat acum ${days}z';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Actualizat acum ${days}z ${hours}h';
	@override String updatedHoursAgo({required Object hours}) => 'Actualizat acum ${hours}h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Actualizat acum ${hours}h ${minutes}min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Actualizat acum ${minutes}min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Ultima descărcare avea doar ${imported} din ${existing} înregistrări și nu a fost folosită. Reîmprospătați pentru a o accepta.';
	@override String get extensionsSection => 'Extensii';
}

// Path: settings.profiles
class _Translations$settings$profiles$ro extends Translations$settings$profiles$en {
	_Translations$settings$profiles$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Nesetat';
	@override String get personalInfo => 'Informații personale';
	@override String get personalInfoNote => 'Acestea pot fi incluse în jurnalele generate când sunt relevante pentru trimiteri';
	@override String get name => 'Nume';
	@override String get email => 'E-mail';
	@override String get club => 'Club';
	@override String get arrlSection => 'Secțiune ARRL';
	@override String get racSection => 'Secțiune RAC';
	@override String get section => 'Secțiune';
}

// Path: settings.search
class _Translations$settings$search$ro extends Translations$settings$search$en {
	_Translations$settings$search$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Golește';
	@override String get hint => 'Căutați în preferințe';
}

// Path: settings.developer
class _Translations$settings$developer$ro extends Translations$settings$developer$en {
	_Translations$settings$developer$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Activează avertismentele pentru dezvoltatori, jurnalele de depanare și instrumentele.';
	@override String get experiments => 'Experimente';
	@override String get showIdleMetrics => 'Afișează metricile de inactivitate';
	@override String get showIdleMetricsDescription => 'Afișează în bara de stare cât de inactiv a fost motorul de extensii în ultima secundă. Atingeți pentru mediile pe 10 și 60 de secunde.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% inactiv';
	@override String get idleMetricsAverages => 'Medie inactivitate:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} activat',
		other: '${count} activate',
	);
	@override String get patchTrack => 'Canal Code Push';
	@override String get patchTrackDescription => 'Ce canal de actualizări de cod over-the-air urmează acest dispozitiv. Canalele mai îndrăznețe primesc remedieri mai devreme, mai puțin testate. Actualizările de cod se aplică la următoarea repornire.';
	@override String get trackStable => 'Stabil';
	@override String get trackUnstable => 'Instabil';
	@override String get trackBleeding => 'În dezvoltare';
	@override String checkingTrack({required Object track}) => 'Se caută o actualizare de cod pe „${track}”…';
	@override String get patchDownloaded => 'Actualizarea de cod a fost descărcată — reporniți aplicația pentru a o aplica.';
	@override String noNewPatch({required Object track}) => 'Nicio actualizare de cod nouă pe „${track}”.';
	@override String get noPatchInstalled => 'Nicio actualizare de cod instalată — rulează binarul lansat.';
	@override String runningPatch({required Object patch}) => 'Rulează actualizarea de cod #${patch}.';
	@override String get deepLinks => 'Linkuri directe';
	@override String get registerUrlSchemes => 'Înregistrează schemele URL';
	@override String get registerUrlSchemesDescription => 'Permite linkurilor com.ham2k:// să deschidă această copie a aplicației';
	@override String get registerUrlSchemesDone => 'Această copie deschide acum linkurile com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Înregistrarea nu a reușit: ${error}';
	@override String get systemInformation => 'Informații sistem';
	@override String get appVersion => 'Versiunea aplicației';
	@override String get dataFolder => 'Dosarul de date';
	@override String get loading => '(se încarcă…)';
	@override String get panelLoadFailed => 'Acest panou de setări nu a putut fi încărcat.';
	@override String get extDevServer => 'Server de dezvoltare extensii';
	@override String get extensionSettings => 'Setări extensii';
	@override String get extDevServerDescription => 'Încarcă extensiile de pe un server de dezvoltare din rețeaua dvs. în locul celor integrate în aplicație și le reîncarcă la fiecare salvare.';
	@override String get extDevServerAddress => 'Adresa serverului';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Conectează';
	@override String get extDevServerDisconnect => 'Deconectează';
	@override String get extDevServerConnecting => 'Se conectează…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Se servește ${count} extensie: ${keys}',
		other: 'Se servesc ${count} extensii: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Neconectat';
	@override String get extDevServerReconnect => 'Reconectare la pornire';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Ultima reîncărcare: ${key} la ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} extensie nu se compilează',
		other: '${count} extensii nu se compilează',
	);
	@override String get catalog => 'Catalog de extensii';
	@override String get catalogDescription => 'Citește catalogul de pe alt server — unul local în timp ce lucrați la catalogul însuși. Gol înseamnă catalog.ham2k.net.';
	@override String get catalogAddress => 'Adresa catalogului';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Canale de căutare în catalog';
	@override String get catalogSearchStable => 'Doar stabile';
	@override String get catalogSearchUnstable => 'Instabile sau mai bune';
	@override String get catalogSearchBleeding => 'În dezvoltare sau mai bune';
}

// Path: settings.about
class _Translations$settings$about$ro extends Translations$settings$about$en {
	_Translations$settings$about$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Notificări și mesaje';
	@override String get noticesDescription => 'Anunțuri și mesaje de stare';
	@override String get releaseNotes => 'Note de versiune';
	@override String get copiedVersion => 'Detaliile versiunii au fost copiate în clipboard';
}

// Path: settings.panels
class _Translations$settings$panels$ro extends Translations$settings$panels$en {
	_Translations$settings$panels$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Preferințele aplicației';
	@override String get settingsDescription => 'Faceți aplicația să funcționeze cum doriți';
	@override String get commonSettings => 'Preferințe comune';
	@override String get syncDescription => 'Backup și sincronizarea jurnalelor pe toate dispozitivele';
	@override String get accountsDescription => 'Date de acces la servicii, date offline și altele';
	@override String get extensions => 'Extensii și funcții';
	@override String get extensionsDescription => 'Activități, concursuri, panouri de bord și alte funcții';
	@override String get profilesDescription => 'Indicativul operatorului și profilul stației';
	@override String get stationProfiles => 'Profiluri de stație';
	@override String get developerSettings => 'Setări pentru dezvoltatori';
	@override String get developerSettingsDescription => 'Instrumente de depanare și dezvoltare';
	@override String get about => 'Despre';
	@override String get aboutDescription => 'Versiune, credite și informații legale';
	@override String get unavailableTitle => 'Unele setări nu sunt disponibile';
	@override String get unavailableText => 'Mediul de rulare a extensiilor nu a pornit, deci setările oferite de extensii lipsesc.';
	@override String get station => 'Configurația stației';
	@override String get stationDescription => 'Control CAT și alte opțiuni';
	@override String get peers => 'Dispozitive pereche';
	@override String get peersDescription => 'Conectare la alte dispozitive din apropiere';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$ro extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caractere (FN31pr)';
	@override String get eight => '8 caractere (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$ro extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caractere';
	@override String get eight => '8 caractere';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$ro extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'Deschide dialogul de comenzi';
	@override String get toggleTheme => 'Comută între luminos și întunecat';
	@override String get toggleLanguage => 'Comută între engleză și spaniolă';
	@override String get fontScaleUp => 'Text mai mare';
	@override String get fontScaleDown => 'Text mai mic';
	@override String get fontScaleReset => 'Dimensiune normală a textului';
	@override String get densityLooser => 'Aranjament mai aerisit';
	@override String get densityDenser => 'Aranjament mai dens';
	@override String get densityAuto => 'Densitate automată a aranjamentului';
	@override String get find => 'Caută în jurnal';
	@override String keyerMessage({required Object n}) => 'Trimite mesajul ${n}';
	@override String get keyboardMode => 'Modul tastatură pornit sau oprit';
	@override String get ptt => 'PTT (apasă pentru a vorbi)';
	@override String get wipe => 'Golește contactul în curs de înregistrare';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$ro extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'Tastarea indicativelor';
	@override String get escape => 'Oprește transmisia, revino un pas sau închide';
	@override String get enter => 'Înregistrează contactul';
	@override String get space => 'Câmpul următor';
	@override String get tab => 'Câmpul următor sau anterior';
	@override String get arrows => 'Deplasare între câmpuri, controale și jurnal';
	@override String get walk => 'Parcurge jurnalul pagină cu pagină sau sari la capetele lui';
	@override String get undo => 'Anulează o golire sau o ștergere';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$ro extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'Adaugă scurtătură';
	@override String get listening => 'Apăsați tastele pentru scurtătură…';
	@override String get listeningHint => 'Esc oprește ascultarea';
	@override String get add => 'Adaugă';
	@override String refusedFixed({required Object keys}) => '${keys} aparține câmpurilor de înregistrare sau unui dialog și nu poate fi schimbată.';
	@override String refusedCallsign({required Object keys}) => 'Cu ${keys} se tastează indicativele. Țineți apăsat Cmd, Ctrl sau Alt împreună cu ea.';
	@override String reserved({required Object keys}) => 'Sistemul poate prelua ${keys} înainte ca aplicația să o vadă.';
	@override String already({required Object keys}) => '${keys} este deja una dintre tastele acestei comenzi.';
	@override String takeIt({required Object keys, required Object command}) => 'Ia ${keys} de la „${command}”';
	@override String get resetDefault => 'Resetează la implicit';
	@override String get remove => 'Elimină';
	@override String get commandLabel => 'Comandă';
	@override String get commandHint => 'Introduceți orice comandă validă sau mai multe comenzi separate prin „;”';
	@override String get removeCommand => 'Elimină comanda';
	@override String commandUnknown({required Object text}) => 'Nicio comandă nu recunoaște „${text}”';
	@override String get noShortcuts => 'Nicio tastă încă';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$ro extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'Scurtăturile au fost salvate în ${location}';
	@override String exportFailed({required Object error}) => 'Scurtăturile nu au putut fi exportate: ${error}';
	@override String importPickerFailed({required Object error}) => 'Fișierul nu a putut fi deschis: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} nu este un fișier de scurtături pe care aplicația îl poate citi: ${problem}';
	@override String problemNotYaml({required Object line}) => 'textul nu este YAML valid (linia ${line})';
	@override String get problemNotKeysFile => 'nu este un fișier de scurtături de tastatură Ham2K';
	@override String get problemNewerVersion => 'a fost scris de o versiune mai nouă a aplicației';
	@override String get problemMalformed => 'o parte din el nu respectă formatul de scurtături';
	@override String get problemTooLarge => 'este prea mare';
	@override String get importTitle => 'Importă scurtături';
	@override String writtenOn({required Object platform}) => 'Scris pe ${platform}.';
	@override String get writtenOnUnknown => 'Fișierul nu spune pe ce tastatură a fost scris.';
	@override String get translate => 'Ce ar trebui să fie fiecare dintre aceste taste pe această tastatură?';
	@override String get leaveOut => 'Lasă deoparte acele scurtături';
	@override String get replace => 'Înlocuiește configurația acestui dispozitiv';
	@override String get replaceHint => 'Fiecare scurtătură care nu e în fișier revine la valoarea ei implicită.';
	@override String get merge => 'Adaugă la configurația acestui dispozitiv';
	@override String get mergeHint => 'Scurtăturile din fișier le înlocuiesc pe cele ale acestui dispozitiv pentru aceleași comenzi, iar restul rămân.';
	@override String unknown({required Object commands}) => 'Necunoscute în această versiune, deci omise: ${commands}';
	@override String unreadableChords({required Object chords}) => 'Nu sunt scurtături, deci omise: ${chords}';
	@override String refusedChords({required Object chords}) => 'Taste pe care aplicația le păstrează pentru sine, deci omise: ${chords}';
	@override String conflicts({required Object keys}) => 'Asociate mai multor comenzi după import: ${keys}';
	@override String get importAction => 'Importă';
	@override String get imported => 'Scurtăturile au fost importate';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$ro extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$ro extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$ro extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'Indicative de stație';
	@override String get groupBy => 'Grupare';
	@override String get period => 'Perioadă';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$ro extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get none => 'Negrupat';
	@override String get date => 'Dată';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'Continent necunoscut';
	@override String get unknownEntity => 'Entitate necunoscută';
	@override String get unknownDate => 'Fără dată';
}

// Path: home.logs.period
class _Translations$home$logs$period$ro extends Translations$home$logs$period$en {
	_Translations$home$logs$period$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'Luna aceasta';
	@override String get last3Months => 'Ultimele 3 luni';
	@override String get thisYear => 'Anul acesta';
	@override String get lastYear => 'Anul trecut';
	@override String get allTime => 'Dintotdeauna';
	@override String get custom => 'Interval personalizat';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$ro extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => 'în ${span}';
	@override String get custom => 'Interval personalizat';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$ro extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get date => 'Dată';
	@override String get time => 'Ora';
	@override String get freq => 'Frecvență';
	@override String get mode => 'Mod';
	@override String get call => 'Indicativ';
	@override String get name => 'Nume';
	@override String get station => 'Stație';
	@override String get band => 'Bandă';
	@override String get sent => 'Trimis';
	@override String get rcvd => 'Primit';
	@override String get grid => 'Grilă';
	@override String get state => 'Stat';
	@override String get country => 'Țară';
	@override String get refs => 'Ref.';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$ro extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Jurnal QSO';
	@override String get qsosDescription => 'QSO-urile indicativului selectat, din toate operațiunile.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Numărul total de QSO-uri sau căutarea indicativului QSO-ului selectat.';
	@override String get map => 'Hartă';
	@override String get mapDescription => 'Locația QSO-ului selectat.';
}

// Path: home.logs.import
class _Translations$home$logs$import$ro extends Translations$home$logs$import$en {
	_Translations$home$logs$import$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicative: ${calls}';
	@override String get skippedOne => '1 înregistrare nu a putut fi citită';
	@override String skippedOther({required Object count}) => '${count} înregistrări nu au putut fi citite';
	@override String get readingTitle => 'Se citește fișierul ADIF…';
	@override String get checkingTitle => 'Se verifică duplicatele…';
	@override String get importingTitle => 'Se importă QSO-urile…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} din ${total} verificate';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importate, din ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$ro extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'Implicit';
	@override String untitledName({required Object number}) => 'Aranjamentul ${number}';
	@override String switcherLabel({required Object name}) => 'Aranjament: ${name}';
	@override String get menuNew => 'Nou…';
	@override String get menuExport => 'Exportă…';
	@override String get menuImport => 'Importă…';
	@override String get menuTitle => 'Aranjamente';
	@override String get newTitle => 'Aranjament nou';
	@override String get editTitle => 'Editează aranjamentul';
	@override String get edit => 'Editează';
	@override String get duplicateCurrent => 'Duplică aranjamentul curent';
	@override String get startFromDefault => 'Pornește de la aranjamentul implicit';
	@override String get nameLabel => 'Nume';
	@override String get descriptionLabel => 'Descriere';
	@override String get create => 'Creează';
	@override String leaveEditTitle({required Object name}) => 'Salvați modificările la „${name}”?';
	@override String get leaveEditBody => 'Acest aranjament are modificări pe care nu le-ați salvat.';
	@override String get discard => 'Renunță';
	@override String get deleteTitle => 'Ștergeți acest aranjament?';
	@override String deleteBody({required Object name}) => 'Sigur doriți să ștergeți aranjamentul „${name}”?';
	@override String get exportTitle => 'Exportă aranjamentul';
	@override String get exportPick => 'Panouri de exportat';
	@override String get tabSet => 'Grup de file';
	@override String get exportAction => 'Exportă';
	@override String exported({required Object location}) => 'Aranjament salvat în ${location}';
	@override String exportFailed({required Object error}) => 'Aranjamentul nu a putut fi exportat: ${error}';
	@override String get importTitle => 'Importă aranjament';
	@override String importFromOtherView({required Object view}) => 'Făcut pentru vizualizarea ${view}: panourile pe care le are doar acea vizualizare sunt omise.';
	@override String get viewHome => 'Acasă';
	@override String get viewOperation => 'Operațiune';
	@override String get viewLogs => 'Jurnale';
	@override String get viewChase => 'Vânătoare';
	@override String get importAsNew => 'Ca aranjament nou';
	@override String get importReplace => 'În locul acestui aranjament';
	@override String get importAdd => 'Adăugate la acest aranjament';
	@override String get importAddHint => 'Panourile sosesc într-o coloană nouă, în dreapta.';
	@override String get importPick => 'Panouri de importat';
	@override String get importReplaceSettings => 'Înlocuiește setările panourilor deja configurate aici';
	@override String get importAction => 'Importă';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} nu este un aranjament pe care aplicația îl poate citi: ${problem}';
	@override String problemNotYaml({required Object line}) => 'textul nu este YAML valid (linia ${line})';
	@override String get problemNotLayoutFile => 'nu este un fișier de aranjament Ham2K';
	@override String get problemNewerVersion => 'a fost scris de o versiune mai nouă a aplicației';
	@override String get problemNoArrangement => 'nu conține niciun aranjament';
	@override String get problemMalformed => 'o parte din el nu respectă formatul de aranjament';
	@override String get problemTooLarge => 'este prea mare';
	@override String importPickerFailed({required Object error}) => 'Fișierul nu a putut fi deschis: ${error}';
	@override String importFailed({required Object error}) => 'Aranjamentul nu a putut fi importat: ${error}';
	@override String duplicateFailed({required Object error}) => 'Aranjamentul nu a putut fi copiat: ${error}';
	@override String get importNothing => 'Niciun panou ales, așa că nu s-a importat nimic.';
	@override String importSkipped({required Object panels}) => 'Omise: ${panels}';
	@override String importKeptPinned({required Object panels}) => 'Păstrat ${panels}: aranjamentul pentru ecrane mici nu se poate lipsi de el.';
	@override String get notOffered => 'Nu este disponibil în această vizualizare';
	@override String get alreadyPlaced => 'Deja în acest aranjament';
	@override String needsExtension({required Object name}) => 'Necesită ${name}';
	@override String get listRecoveredTitle => 'Numele aranjamentelor nu au putut fi citite';
	@override String get listRecoveredBody => 'Lista de aranjamente a acestei vizualizări nu a putut fi citită. Toate aranjamentele sunt încă aici, numerotate în locul numelui.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$ro extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Jurnalul și câmpurile de introducere';
	@override String get infoDescription => 'Ce știm despre stația lucrată';
	@override String get spotsDescription => 'Spoturi din clustere și programe de activitate';
	@override String get mapDescription => 'Unde se află contactele';
	@override String get summariesDescription => 'Statisticile și punctajele operațiunii, în secțiunile și ordinea alese de dvs.';
	@override String get summariesSections => 'Secțiuni și ordine';
	@override String get summariesDays => 'Fiecare zi';
	@override String get summariesReset => 'Afișează tot';
	@override String get summariesAllHidden => 'Toate secțiunile sunt ascunse. Alegeți-le pe cele de afișat în setările acestui panou.';
	@override String get clockDescription => 'Un cadran de ceas, în orice fus orar';
	@override String get clockFace => 'Cadran';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analogic';
	@override String get clockZone => 'Fus orar';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Acest dispozitiv';
	@override String get clockShowSeconds => 'Afișează secundele';
	@override String get weatherDescription => 'Condițiile actuale și pentru următoarele opt ore, acolo unde operați';
	@override String get weatherUseOperationLocation => 'Folosește locația operațiunii';
	@override String get weatherLocation => 'Locație';
	@override String get weatherLocationDescription => 'O grilă (FN31pr) sau lat,lon. Ignorată cât timp „Folosește locația operațiunii” este bifat.';
	@override String get weatherNoLocation => 'Nicio locație setată. Dați acestui panou o locație în setările lui sau plasați-l într-o operațiune care are una.';
	@override String weatherBadLocation({required Object location}) => 'Locația ${location} nu a putut fi citită. Folosiți o grilă precum FN31pr sau 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo nu a putut fi accesat — lipsește rețeaua? Se va reîncerca în curând.';
	@override String get weatherUnreadable => 'Open-Meteo a răspuns, dar nu cu ceva lizibil. Se va reîncerca în curând.';
	@override String weatherGusts({required Object speed}) => 'rafale ${speed}';
	@override String get panelAgeNow => 'chiar acum';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'acum ${count} min',
		other: 'acum ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'acum ${count} oră',
		other: 'acum ${count} ore',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$ro weatherConditions = _Translations$operation$layout$panels$weatherConditions$ro._(_root);
	@override String get websiteDescription => 'O pagină web aleasă de dvs., într-un panou';
	@override String get websiteUrl => 'Adresă';
	@override String get websiteRefresh => 'Reîmprospătare';
	@override String get websiteRefreshNever => 'Niciodată';
	@override String get websiteRefresh1 => 'În fiecare minut';
	@override String get websiteRefresh5 => 'La fiecare 5 minute';
	@override String get websiteRefresh15 => 'La fiecare 15 minute';
	@override String get websiteTitle => 'Numele panoului';
	@override String get websiteRefreshNow => 'Reîmprospătează acum';
	@override String get websiteNoUrl => 'Nicio adresă încă. Deschideți setările acestui panou pentru a alege o pagină.';
	@override String get websiteBadUrl => 'Nu pare a fi o adresă web. Trebuie să înceapă cu https://';
	@override String get websiteNotHttps => 'Doar adresele https:// pot fi afișate aici.';
	@override String get websiteUnsupported => 'Paginile web nu pot fi afișate într-un panou pe acest sistem.';
	@override String get websiteOpenExternally => 'Deschide în browser';
	@override String websiteLoadFailed({required Object reason}) => 'Pagina nu a putut fi încărcată: ${reason}';
	@override String get remoteScreenDescription => 'Un ecran, o aplicație sau o fereastră partajată de un alt dispozitiv al dvs.';
	@override String get remoteScreenTarget => 'Ecran';
	@override String get remoteScreenChoose => 'Alegeți un ecran…';
	@override String get remoteScreenPickerTitle => 'Ecrane partajate';
	@override String get remoteScreenPickerEmpty => 'Niciunul dintre dispozitivele dvs. nu partajează un ecran. Activați Partajare ecrane și ferestre din Setări → Dispozitive pereche, pe dispozitivul pe care doriți să-l vedeți.';
	@override String get remoteScreenUnset => 'Niciun ecran ales. Deschideți setările acestui panou pentru a alege unul partajat de celelalte dispozitive.';
	@override String get remoteScreenConnecting => 'Se conectează…';
	@override String get remoteScreenPeerAway => 'Acel dispozitiv nu este conectat acum.';
	@override String get remoteScreenNotOffered => 'Acel dispozitiv a oprit partajarea acestui ecran.';
	@override String get remoteScreenNoListener => 'Acel dispozitiv nu poate accepta conexiuni — verificați-i firewall-ul.';
	@override String get remoteScreenNoLan => 'Ecranele se partajează doar prin rețeaua locală, nu prin Bluetooth.';
	@override String get remoteScreenRefused => 'Acel dispozitiv a refuzat să partajeze acest ecran.';
	@override String get remoteScreenSettings => 'Setări panou';
	@override String get remoteScreenAdjust => 'Ajustare vizualizare';
	@override String get remoteScreenDetail => 'Detaliu';
	@override String get remoteScreenDetailStandard => 'Standard';
	@override String get remoteScreenDetailHigh => 'Ridicat';
	@override String get remoteScreenDetailMaximum => 'Maxim';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Mărire';
	@override String get remoteScreenZoomOut => 'Micșorare';
	@override String get remoteScreenStopped => 'Acel ecran sau fereastră nu mai este afișat.';
	@override String get remoteScreenCaptureFailed => 'Acel dispozitiv nu a putut captura ecranul — poate necesita permisiunea de înregistrare a ecranului.';
	@override String get remoteScreenNoAnswer => 'Acel dispozitiv nu a răspuns. Poate nu are partajarea ecranului activată.';
	@override String get remoteScreenNoMedia => 'Nu s-a putut deschide o conexiune pentru imagine. Verificați firewall-ul acestui dispozitiv.';
	@override String get solarDescription => 'Condiții solare și geomagnetice, cu propagarea pe fiecare bandă';
	@override String get solarUnreachable => 'hamqsl.com nu a putut fi accesat — lipsește rețeaua? Se va reîncerca în curând.';
	@override String get solarUnreadable => 'hamqsl.com a răspuns, dar nu cu o citire utilizabilă. Se va reîncerca în curând.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Zi';
	@override String get solarBandNight => 'Noapte';
	@override String get solarBandGood => 'Bună';
	@override String get solarBandFair => 'Medie';
	@override String get solarBandPoor => 'Slabă';
	@override String solarSources({required Object primary, required Object secondary}) => 'Surse: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Conexiunea are dificultăți — se omit cadre.';
	@override String get remoteScreenStalled => 'Cadrele nu mai ajung — conexiunea poate fi prea lentă.';
	@override String get radioDescription => 'Panoul frontal al unei stații radio — frecvență, mod și putere, sub control CAT';
	@override String get radioStyle => 'Stil';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Modern';
	@override String get radioRadio => 'Stație radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — nicio stație radio desemnată';
	@override String get radioNoRadio => 'Nicio stație radio de afișat. Alegeți una în setările acestui panou sau adăugați una în Configurația stației.';
	@override String get radioNotConfigured => 'Această stație radio nu este încă configurată. Alegeți portul sau adresa în Configurația stației.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Stația radio nu este conectată';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Conectează această stație radio';
	@override String get radioDisconnect => 'Deconectează această stație radio';
	@override String get radioStale => 'FĂRĂ DATE';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR ridicat';
	@override String get rotatorDescription => 'Încotro arată antena, pe o hartă centrată pe stație. Atingeți harta pentru a o roti.';
	@override String get rotatorRotator => 'Rotor';
	@override String rotatorAutoNamed({required Object name}) => 'Automat — ${name}';
	@override String get rotatorAutoNone => 'Automat — încă niciun rotor';
	@override String get rotatorBeamWidth => 'Lățimea fasciculului';
	@override String get rotatorBeamWidthDescription => 'În grade, desenată în jurul direcției. 0 nu desenează nimic.';
	@override String get rotatorLocation => 'Locație';
	@override String get rotatorLocationDescription => 'O grilă sau o latitudine și o longitudine pe care să se centreze harta. Lăsată goală, folosește locația operațiunii.';
	@override String get rotatorTheme => 'Temă';
	@override String get rotatorThemeColor => 'Color';
	@override String get rotatorThemeGray => 'Gri';
	@override String get rotatorThemeMuted => 'Estompat';
	@override String get rotatorGrayline => 'Afișează linia gri';
	@override String get rotatorNoRotator => 'Niciun rotor de afișat. Alegeți unul în setările acestui panou sau adăugați unul în Configurația stației.';
	@override String get rotatorNoLocation => 'Nicio locație pe care să se centreze harta. Setați una în setările acestui panou.';
	@override String get rotatorDisconnected => 'deconectat';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => 'nu răspunde';
	@override String get rotatorLocationInvalid => 'Locația din setările acestui panou nu poate fi citită. Folosiți o grilă sau o latitudine și o longitudine, ca 40.7, -74.0.';
	@override String rotatorElevation({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'V';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$ro extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Folosește nume de fișiere compacte';
	@override String get descriptionOn => 'Nume scurte pentru programele de încărcare, ca N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nume lizibile, ca 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$ro extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Include informații private';
	@override String get descriptionOn => 'Numele, adresele, e-mailurile, grilele și notițele sunt incluse';
	@override String get descriptionOff => 'Numele, adresele, e-mailurile, grilele și notițele sunt omise';
	@override String get note => 'Exportul ADIF complet include întotdeauna tot';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$ro extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Adăugați mai întâi o adresă de e-mail';
	@override String get needsEmailBody => 'Ham2K File Stash trimite fișierele dvs. la adresa de e-mail a contului LoFi, iar cu ea vă autentificați la stash.ham2k.net. Contul dvs. nu are încă una confirmată — adăugați-o în Setări › Sincronizare în cloud.';
	@override String get openSyncSettings => 'Deschide Sincronizare în cloud';
	@override String get replaceTitle => 'Stash-ul recent va fi înlocuit';
	@override String replaceBody({required Object name}) => 'Ați trimis „${name}” cu mai puțin de 6 ore în urmă și încă nu a fost descărcat. Conturile gratuite păstrează un singur stash o dată, deci trimiterea acum îl înlocuiește.';
	@override String get replaceConfirm => 'Trimite oricum';
	@override String get failedTitle => 'Nu s-a putut trimite la Ham2K File Stash';
	@override String get sentTitle => 'Trimis la Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Puteți recupera acest fișier vizitând **[stash.ham2k.net](https://stash.ham2k.net)** în orice browser.',
		other: 'Puteți recupera aceste fișiere vizitând **[stash.ham2k.net](https://stash.ham2k.net)** în orice browser.',
	);
	@override String get mayHaveArrived => 'Niciun răspuns de la stash — fișierul poate să fi ajuns totuși. Verificați stash.ham2k.net înainte de a trimite din nou';
	@override String get notSent => 'netrimis';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: 'Acest fișier nu a ajuns:',
		other: 'Aceste ${count} fișiere nu au ajuns:',
	);
	@override String get emailOffer => 'Sau, pentru confortul dvs., vă putem trimite un e-mail cu un link direct.';
	@override String get emailMe => 'Trimite-mi un link prin e-mail';
	@override String get emailSent => 'V-am trimis prin e-mail un link de descărcare.';
	@override String emailFailed({required Object error}) => 'Nu s-a putut trimite e-mailul: ${error}';
	@override String get freeTier => 'Conturile gratuite pot păstra un singur stash o dată. Abonații pot păstra câte doresc.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count,
		one: '${count} fișier trimis la Ham2K File Stash (stash.ham2k.net)',
		other: '${count} fișiere trimise la Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$ro extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get af => 'Africa';
	@override String get as => 'Asia';
	@override String get eu => 'Europa';
	@override String get na => 'America de Nord';
	@override String get oc => 'Oceania';
	@override String get sa => 'America de Sud';
	@override String get an => 'Antarctica';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$ro extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrare spoturi';
	@override String get band => 'Bandă';
	@override String get mode => 'Mod';
	@override String get age => 'Vechime';
	@override String get sources => 'Surse';
	@override String get continent => 'Continent';
	@override String get sorting => 'Sortare';
	@override String get sortByTime => 'După ora spotului';
	@override String get sortByFrequency => 'După frecvență';
	@override String get sortByWanted => 'Cele mai dorite';
	@override String get groupByBand => 'Grupare după bandă';
	@override String get groupCallsWithNotes => 'Grupează indicativele cu notițe';
	@override String get alertingOnly => 'Doar spoturile cu alerte';
	@override String get sourceNoReply => 'Fără răspuns';
	@override String get sourceError => 'Eroare';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$ro extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Panoul de înregistrare este ocupat';
	@override String get editingBody => 'Editați un contact înregistrat. Înregistrați acest spot în schimb sau reveniți și terminați editarea?';
	@override String get composingBody => 'Ați început să introduceți un contact. Înregistrați acest spot în schimb sau reveniți și terminați ce scriați?';
	@override String get goBack => 'Înapoi';
	@override String get clearAndLog => 'Golește și înregistrează spotul';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$ro extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mod pentru stângaci';
	@override String get descriptionOn => 'Se folosește aspectul pentru stângaci';
	@override String get descriptionOff => 'Se folosește aspectul pentru dreptaci';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$ro extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Steaguri țări';
	@override String get dx => 'Doar pentru contactele DX';
	@override String get all => 'Steaguri pentru toate contactele';
	@override String get none => 'Fără steaguri';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$ro extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Se afișează steaguri doar pentru contactele DX';
	@override String get all => 'Se afișează steaguri pentru toate contactele';
	@override String get none => 'Nu se afișează niciun steag';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$ro extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sugerează operatorul';
	@override String get descriptionOn => 'Se oferă indicativul dvs. ca operator când o operațiune folosește un alt indicativ de stație';
	@override String get descriptionOff => 'Operatorul rămâne gol dacă nu îl completați';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$ro extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afișează azimutul';
	@override String get descriptionOn => 'Se afișează azimutul estimat către stație';
	@override String get descriptionOff => 'Nu se afișează informații despre azimut';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$ro extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afișează și azimutul invers';
	@override String get descriptionOn => 'Se afișează și azimutul de la stație, ca „45° / 225°”';
	@override String get descriptionOff => 'Se afișează doar azimutul către stație';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$ro extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Schimbă ordinea rapoartelor de semnal';
	@override String get sentFirst => 'Întâi Trimis, apoi Primit';
	@override String get rcvdFirst => 'Întâi Primit, apoi Trimis';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$ro extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Treci la câmpul următor după RST';
	@override String get descriptionOn => 'Se trece mai departe după introducerea RST';
	@override String get descriptionOff => 'Nu se trece automat';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$ro extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Raport implicit — Fonie';
	@override String get description => 'Folosit când Trimis sau Primit rămâne gol în SSB, FM sau AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$ro extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Raport implicit — CW și date';
	@override String get description => 'Folosit când Trimis sau Primit rămâne gol în CW, RTTY și alte moduri digitale';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$ro extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Raport implicit — FT8 și FT4';
	@override String get description => 'Folosit când Trimis sau Primit rămâne gol în modurile FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$ro extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rând de numere';
	@override String get description => 'Afișează un rând de taste numerice deasupra tastaturii în timpul înregistrării';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$ro extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tastă bară oblică și punct';
	@override String get description => 'Adaugă o tastă contextuală: „/” pentru indicative, „.” pentru numere';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$ro extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrează la apăsarea tastelor';
	@override String get description => 'Răspuns haptic când atingeți o tastă numerică';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$ro extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get off => 'Dezactivat';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$ro extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'niciun indicativ de operator cu care să se autentifice';
	@override String get connectFailed => 'nodul nu a putut fi accesat';
	@override String get needsPassword => 'nodul cere o parolă și niciuna nu este salvată';
	@override String get loginFailed => 'nodul nu a acceptat autentificarea';
	@override String get disconnected => 'nodul a închis conexiunea';
	@override String get timeout => 'nodul nu a răspuns';
	@override String get off => '„Conectare la cluster” este oprită';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$ro extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$ro extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlează PTT de la tastatură';
	@override late final _Translations$settings$radio$pttKey$modes$ro modes = _Translations$settings$radio$pttKey$modes$ro._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$ro descriptions = _Translations$settings$radio$pttKey$descriptions$ro._(_root);
	@override String get key => 'Tastă PTT';
	@override String get pill => 'TX';
	@override String get transmitting => 'Emisie';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$ro extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rotunjire inteligentă VFO';
	@override String get descriptionOn => 'După ce opriți rotirea butonului, frecvența se rotunjește la un pas rezonabil. Doar în modurile de fonie.';
	@override String get descriptionOff => 'Rămâne exact unde ați acordat.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$ro extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rotunjire inteligentă: întârziere de stabilizare';
	@override String get description => 'Cât timp trebuie să stea butonul nemișcat înainte de rotunjirea frecvenței. Mai scurt pare imediat; mai lung lasă loc unei mișcări lente.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$ro extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rotunjire inteligentă: mișcare lungă';
	@override String get description => 'La o mișcare de cel puțin atât, frecvența se rotunjește la un kHz întreg, oricât de încet ați terminat.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$ro extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rotunjire inteligentă: cea mai mică mișcare';
	@override String get description => 'La o mișcare mai mică decât atât, frecvența nu se rotunjește, astfel acordul fin rămâne neatins.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$ro extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rotunjire inteligentă: cea mai lentă mișcare';
	@override String get description => 'Dacă rotiți butonul mai încet decât atât, frecvența nu se rotunjește, cu excepția unei mișcări lungi.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$ro extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM oprit';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter trimite mesaje';
	@override String get off => 'Oprit';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter trimite mesaje: ${state}. Atingeți pentru a schimba.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$ro extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Viteza keyer-ului';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$ro extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mesaje keyer CW';
	@override String get notSupported => 'Stația radio curentă nu acceptă manipulare CW';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Mesaj ${n}';
	@override String get labelField => 'Etichetă';
	@override String labelKey({required Object n}) => 'Eticheta F${n}';
	@override String get details => 'Detalii';
	@override String get empty => '(gol)';
	@override String get sets => 'Set de mesaje';
	@override String get newSet => 'Set nou';
	@override String get renameSet => 'Redenumește setul';
	@override String get deleteSet => 'Șterge setul';
	@override String get newSetName => 'Nume';
	@override String get setDefault => 'Implicit';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Mesaje ESM';
	@override String get setSaved => 'Mesajele mele';
	@override String get repeat => 'Repetă mesajul 1';
	@override String get repeatShort => 'Repetă M1';
	@override String get cooldown => 'Pauză înainte de repetare';
	@override String cooldownSeconds({required Object n}) => '${n} secunde';
	@override String get repeatWait => 'Se repetă';
	@override String get keyboard => 'Tastați pentru a trimite';
	@override String get keyboardField => 'Tastați pentru a trimite';
	@override String get help => 'Ajutor';
	@override String get helpTitle => 'Scrierea mesajelor CW';
	@override String get helpIntro => 'Mesajele pot folosi șabloane cu următoarele valori:';
	@override String get helpOpCall => 'Indicativul dvs.';
	@override String get helpQsoCall => 'Indicativul lor — într-o stivă //, indicativul care va fi înregistrat';
	@override String get helpQsoFullCall => 'Indicativul lor, dacă este un indicativ valid; gol pentru unul parțial';
	@override String get helpQsoPartial => 'Un indicativ parțial; gol dacă există un indicativ complet valid';
	@override String get helpQsoNextCall => 'Într-o stivă //, indicativul care va fi selectat următorul pentru înregistrare, dacă este un indicativ complet valid';
	@override String get helpQsoNextPartial => 'Într-o stivă //, următorul parțial după înregistrarea contactului curent';
	@override String get helpQsoName => 'Prenumele lor, așa cum a fost tastat sau, altfel, din căutare';
	@override String get helpQsoState => 'Statul lor, așa cum a fost tastat sau, altfel, din căutare';
	@override String get helpKeyerMsg => 'Mesajul 1 așa cum ar fi trimis, în interiorul altui mesaj. Valabil pentru mesajele 1 până la 8';
	@override String get helpQsoRst => 'Raportul pe care îl trimiteți';
	@override String get helpQsoSerial => 'Numărul dvs. de serie, într-un concurs care trimite unul';
	@override String get helpPad => 'Completează cu zerouri până la atâtea cifre: 7 se trimite ca 007';
	@override String get helpCut => 'Cifre prescurtate, T pentru 0 și N pentru 9: 599 se trimite ca 5NN';
	@override String get helpCutDigits => 'Alege cifrele de prescurtat, între ghilimele — 0 este T, 1 este A, 5 este E, 9 este N';
	@override String get helpFullExample => 'Exemplu complet:';
	@override String get helpExample => 'Trimite W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Cu Enter trimite mesaje activat, Enter transmite mesajele după tasta lor funcțională, ca în N1MM. Setul Mesaje ESM începe cu acestea:';
	@override String get helpEsmCq => 'În Run, Enter cu câmpul de indicativ gol cheamă CQ';
	@override String get helpEsmExchange => 'Schimbul dvs.: după indicativul lor în Run, după ce vă răspund în S&P';
	@override String get helpEsmThanks => 'Mulțumiri, după înregistrarea contactului: qso este contactul așa cum a fost înregistrat, next cel care urmează';
	@override String get helpEsmMyCall => 'În S&P, indicativul dvs. către stația căreia îi răspundeți';
	@override String get helpEsmHisCall => 'În Run, indicativul lor înaintea schimbului dvs.';
	@override String get helpEsmAgain => 'Cere din nou când nimic din schimbul lor nu a fost recepționat';
	@override String get helpEsmStackThanks => 'F3 sugerat pentru stive //: mulțumește, apoi cheamă următoarea stație din stivă și trimite schimbul dvs. sau cere înapoi un parțial (TU KR?); dacă nu mai rămâne nimic, doar TU';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$ro extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get label => 'Keyer';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => 'Voce';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$ro extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mesaje keyer fonie';
	@override String get notSupported => 'Stația radio curentă nu acceptă mesaje de fonie';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memorie vocală ${n}';
	@override String get labelField => 'Etichetă';
	@override String labelKey({required Object n}) => 'Eticheta memoriei vocale ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Goală';
	@override String get notMeasured => 'Durată necunoscută';
	@override String get playButton => 'Redă';
	@override String get recordButton => 'Înregistrează';
	@override String get stopButton => 'Stop';
	@override String get repeat => 'Repetă mesajul 1';
	@override String recordHelpTitle({required Object model}) => 'Note ${model}:';
	@override String namedOnDevice({required Object device}) => 'Aceste memorii se află în stația radio a dispozitivului ${device}. Numele și duratele lor aparțin acelui dispozitiv.';
	@override String get namedOnRadio => 'Salvat în stația radio, unde îl văd și ceilalți clienți ai ei.';
	@override String get recordHelpYaesuDvs => 'Așteptați indicatorul [REC] pe stația radio, apoi țineți apăsat butonul PTT și înregistrați mesajul. Încheiați-l apăsând butonul STOP aici în aplicație înainte de a elibera PTT, pentru a evita clicurile nedorite.';
	@override String get recordHelpFt891 => 'Așteptați ca indicatorul [REC] să clipească de cel puțin patru ori, apoi țineți apăsat butonul PTT și înregistrați mesajul. Încheiați-l apăsând butonul STOP aici în aplicație înainte de a elibera PTT, pentru a evita clicurile nedorite.';
	@override String get pill => 'Voce';
	@override String play({required Object n}) => 'Redă memoria ${n}';
	@override String get stop => 'Stop';
	@override String record({required Object n}) => 'Înregistrează memoria ${n}';
	@override String get stopRecording => 'Oprește înregistrarea';
	@override String get playing => 'Se redă…';
	@override String get recording => 'Se înregistrează…';
	@override String recordingMemory({required Object label}) => 'Se înregistrează ${label}';
	@override String get doubtful => 'A redat-o stația radio? A raportat imediat că este inactivă.';
	@override String get recordOnRadio => 'Memoriile trebuie înregistrate direct pe stația radio.';
	@override String get sets => 'Set de mesaje';
	@override String get soundFilesSet => 'Fișiere audio de pe acest calculator';
	@override String get openFileButton => 'Deschide fișier';
	@override String get newSet => 'Set nou';
	@override String get renameSet => 'Redenumește setul';
	@override String get deleteSet => 'Șterge setul';
	@override String get newSetName => 'Nume';
	@override String deleteSetConfirm({required Object name}) => 'Ștergeți ${name} și înregistrările lui? Acțiunea nu poate fi anulată.';
	@override String get output => 'Trimite audio către';
	@override String get input => 'Înregistrează de la';
	@override String get outputRadio => 'Trimite către stația radio prin rețea';
	@override String get inputDefault => 'Implicit sistem';
	@override String get pickDevice => 'Alegeți un dispozitiv audio';
	@override String deviceMissing({required Object name}) => '${name} (neconectat)';
	@override String get lead => 'Întârziere la trecerea pe emisie';
	@override String get tail => 'Întârziere la revenirea pe recepție';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => 'Ascultă';
	@override String get notRecorded => 'Neînregistrat';
	@override String get unplayable => 'Fișierul nu poate fi redat';
	@override String get problemNoOutput => 'Alegeți dispozitivul audio care alimentează stația radio înainte de a reda un mesaj.';
	@override String get problemOutputMissing => 'Dispozitivul audio care alimentează stația radio nu este conectat.';
	@override String get problemInputMissing => 'Dispozitivul de înregistrare nu este conectat.';
	@override String get problemDeviceFailed => 'Dispozitivul audio nu a putut fi deschis.';
	@override String get problemNotRecorded => 'Acel mesaj nu are încă nicio înregistrare.';
	@override String get problemRecordingSilent => 'Nu s-a auzit nimic de la dispozitivul de înregistrare, așa că mesajul a rămas neschimbat. Verificați intrarea și dacă aplicația are permisiunea de a folosi microfonul.';
	@override String get problemRadioAudioUnavailable => 'Stația radio nu preia acum audio de la aplicație. Este nevoie de o conexiune prin rețea la stație.';
	@override String get problemSourceRefused => 'Stația radio nu a vrut să comute audio-ul de emisie pe aplicație, așa că mesajul s-a oprit. Setați stația să emită audio-ul aplicației.';
	@override String get problemCannotKey => 'Această stație radio nu poate fi trecută pe emisie prin CAT, deci calculatorul nu poate reda mesaje în ea.';
	@override String get problemUnplayable => 'Fișierul acelui mesaj nu este un fișier audio pe care aplicația îl poate reda. Folosiți un fișier WAV, FLAC sau MP3, sau înregistrați-l din nou.';
	@override String get problemRecordingFailed => 'Înregistrarea s-a întrerupt, așa că mesajul a rămas neschimbat. Verificați dacă dispozitivul de înregistrare este încă conectat și dacă există spațiu pe disc.';
	@override String get problemFileFailed => 'Înregistrarea nu a putut fi salvată în locul mesajului, așa că mesajul a rămas neschimbat.';
	@override String problemWordsMissing({required Object words}) => 'Acel mesaj are nevoie de cuvinte pe care nu le-ați înregistrat: ${words}.';
	@override String problemTemplateFailed({required Object error}) => 'Șablonul acelui mesaj are o problemă: ${error}';
	@override String get problemNoOperation => 'Mesajele spuse cu cuvintele dvs. se redau într-o operațiune, unde există un contact pentru care să fie spuse.';
	@override String get problemNothingSaid => 'Acel mesaj nu spune nimic pentru acest contact.';
	@override String get templateField => 'Spune cu cuvintele mele';
	@override String get templateHelp => 'Lăsați gol pentru a reda înregistrarea. Altfel, mesajul este spus cu cuvintele înregistrate de dvs., completate pentru fiecare contact, folosind aceste valori:';
	@override String get help => 'Ajutor';
	@override String get helpTitle => 'Mesaje spuse cu cuvintele dvs.';
	@override String get helpFullExample => 'Un mesaj întreg:';
	@override String get helpExample => 'Indicativul lor, raportul lor și înregistrarea dvs. cu „QSL?”';
	@override String get playOnRadio => 'Redă pe stația radio';
	@override String get templateHelpCall => 'Indicativul lor';
	@override String get templateHelpReport => 'Raportul pe care li-l dați';
	@override String get templateHelpMessage => 'Înregistrarea mesajului 2, redată ca atare';
	@override String get voiced => 'Spus cu cuvintele dvs.';
	@override String willSay({required Object words}) => 'Spune: ${words}';
	@override String willSayMissing({required Object words}) => 'Neînregistrate încă: ${words}';
	@override String get previewNoOperation => 'Deschideți o operațiune pentru a vedea ce va spune.';
	@override String get wordsDescription => 'Folosiți propria voce pentru indicative, numere și altele.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$ro extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Înregistrări de cuvinte';
	@override String get callField => 'Cuvintele operatorului';
	@override String get intro => 'Înregistrați fiecare cuvânt sau număr de trei ori, legat și repede, așa cum l-ați spune într-un indicativ. Frazele mai lungi se înregistrează o singură dată.';
	@override String get recordAll => 'Înregistrează tot';
	@override String get recordAllGuide => 'Citiți fiecare cuvânt de trei ori, legat, iar o frază de mai multe cuvinte o singură dată, cu o respirație între rânduri. Apăsați Stop după ultimul.';
	@override String recordingOne({required Object word}) => 'Spuneți „${word} ${word} ${word}”, apoi apăsați Stop.';
	@override String recordingOnce({required Object words}) => 'Spuneți „${words}”, apoi apăsați Stop.';
	@override String get recorded => 'Înregistrat';
	@override String get notRecorded => 'Neînregistrat';
	@override String get addPhrase => 'Adaugă frază';
	@override String get phraseField => 'Fraza, așa cum o scrieți într-un mesaj';
	@override String get deletePhrase => 'Șterge fraza';
	@override String get tryField => 'Încercați să spuneți';
	@override String get pauseLetters => 'Pauză între litere';
	@override String get pauseWords => 'Pauză între cuvinte';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => 'Viteză';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => 'Setări avansate';
	@override String get splitSilent => 'Nu s-a auzit nimic în înregistrare.';
	@override String get splitNotThreeTakes => 'Nu s-au găsit trei repetări. Spuneți cuvântul de trei ori, legat, și încercați din nou.';
	@override String get splitLineCount => 'Nu s-au găsit toate cuvintele în citire. Citiți fiecare cuvânt de trei ori, cu o respirație între cuvinte.';
	@override String get splitLinesTooClose => 'Cuvintele nu au putut fi deosebite. Lăsați o respirație mai lungă între cuvinte.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$ro extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evită bătăile zero pe spoturi';
	@override String get descriptionOn => 'Cu o stație radio conectată, acordul se face la câțiva Hz de un spot CW, ca nu toți cei care îi răspund să cheme pe aceeași notă.';
	@override String get descriptionOff => 'Acordul se face exact pe frecvența spotului.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$ro extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bătăi zero: interval de evitare';
	@override String get description => 'Cât de departe de frecvența spotului, de o parte sau de alta. Decalajul nu este niciodată aproape de zero — ar fi din nou bătăi zero.';
}

// Path: settings.map.style
class _Translations$settings$map$style$ro extends Translations$settings$map$style$en {
	_Translations$settings$map$style$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stilul hărții';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$ro extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afișează indicativele';
	@override String get description => 'Fiecare contact este o etichetă cu indicativul lui, în culoarea benzii';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$ro extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afișează linia gri';
	@override String get description => 'Umbrește partea de noapte a Pământului, cu crepusculul ca gradient';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$ro extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automat';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$ro extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partajează datele de utilizare a aplicației';
	@override String get descriptionOn => 'Ne ajutați să îmbunătățim aplicația partajând date despre utilizare, configurare, blocări și performanță';
	@override String get descriptionOff => 'Datele de utilizare ale aplicației rămân private.\nEchipa Ham2K nu va putea detecta blocări sau alte probleme.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$ro extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partajează datele operațiunilor';
	@override String get descriptionOn => 'Se partajează public și cu alți utilizatori unele date despre operațiuni';
	@override String get descriptionOff => 'Datele despre operațiuni rămân private';
}

// Path: settings.station.models
class _Translations$settings$station$models$ro extends Translations$settings$station$models$en {
	_Translations$settings$station$models$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Generic';
	@override String get icomGeneric => 'Icom - Generic';
	@override String get kenwoodGeneric => 'Kenwood - Generic';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Generic';
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
	@override String get rigctld => 'Stație radio controlată prin rigctld';
	@override String get rigctldNodeName => 'Stația mea (prin rigctld)';
	@override String get flrig => 'Stație radio controlată prin flrig';
	@override String get flrigNodeName => 'Stația mea (prin flrig)';
	@override String get hrd => 'Stație radio controlată prin Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Stația mea (prin HRD)';
	@override String get n3fjp => 'Stație radio controlată prin N3FJP';
	@override String get n3fjpNodeName => 'Stația mea (prin N3FJP)';
	@override String get commander => 'Stație radio controlată prin DXLab Commander';
	@override String get commanderNodeName => 'Stația mea (prin Commander)';
	@override String get antenna => 'Antenă';
	@override String get key => 'Manipulator CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Stație radio generică (substituent)';
	@override String get placeholderRadioNodeName => 'Stația mea';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';
	@override String get gs232a => 'Interfață de rotor Yaesu GS-232A';
	@override String get pstRotator => 'PstRotator (control UDP)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$ro extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get network => 'Rețea/WiFi';
	@override String get secureNetwork => 'Rețea/WiFi securizată';
	@override String get usbSerial => 'Serial USB';
	@override String get wifi => 'Rețea/WiFi';
	@override String get bluetoothSerial => 'Serial Bluetooth';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'Substituent';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$ro extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipol';
	@override String get vertical => 'Verticală';
	@override String get yagiBeam => 'Yagi / Beam';
	@override String get loop => 'Buclă';
	@override String get longWire => 'Long Wire / EFHW';
	@override String get other => 'Alta';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$ro extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Manipulator clasic';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semiautomat mecanic)';
	@override String get fullyAutomatic => 'Keyer complet automat';
	@override String get singlePaddle => 'Paletă simplă';
	@override String get dualPaddle => 'Paletă dublă';
	@override String get computerDriven => 'Comandat de calculator';
	@override String get other => 'Altul';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$ro extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Necunoscut';
	@override String get sunny => 'Însorit';
	@override String get clear => 'Senin';
	@override String get mainlySunny => 'Predominant însorit';
	@override String get mainlyClear => 'Predominant senin';
	@override String get partlyCloudy => 'Parțial noros';
	@override String get cloudy => 'Noros';
	@override String get foggy => 'Ceață';
	@override String get rimeFog => 'Ceață cu chiciură';
	@override String get lightDrizzle => 'Burniță slabă';
	@override String get drizzle => 'Burniță';
	@override String get heavyDrizzle => 'Burniță puternică';
	@override String get lightFreezingDrizzle => 'Burniță slabă care îngheață';
	@override String get freezingDrizzle => 'Burniță care îngheață';
	@override String get lightRain => 'Ploaie slabă';
	@override String get rain => 'Ploaie';
	@override String get heavyRain => 'Ploaie puternică';
	@override String get lightFreezingRain => 'Ploaie slabă care îngheață';
	@override String get freezingRain => 'Ploaie care îngheață';
	@override String get lightSnow => 'Ninsoare slabă';
	@override String get snow => 'Ninsoare';
	@override String get heavySnow => 'Ninsoare puternică';
	@override String get snowGrains => 'Grăunțe de zăpadă';
	@override String get lightShowers => 'Averse slabe';
	@override String get showers => 'Averse';
	@override String get heavyShowers => 'Averse puternice';
	@override String get lightSnowShowers => 'Averse slabe de ninsoare';
	@override String get snowShowers => 'Averse de ninsoare';
	@override String get thunderstorm => 'Furtună';
	@override String get lightThunderstormsWithHail => 'Furtuni slabe cu grindină';
	@override String get thunderstormWithHail => 'Furtună cu grindină';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$ro extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get off => 'Nu';
	@override String get toggle => 'Comutare';
	@override String get hold => 'Menținere';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$ro extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$ro._(TranslationsRo root) : this._root = root, super.internal(root);

	final TranslationsRo _root; // ignore: unused_field

	// Translations
	@override String get off => 'Tastatura nu comandă emisia stației radio.';
	@override String get toggle => 'În modurile de fonie, tasta PTT trece stația pe emisie, iar o nouă apăsare o readuce pe recepție. Revine singură pe recepție după un minut.';
	@override String get hold => 'În modurile de fonie, stația emite cât timp tasta PTT este ținută apăsată, cel mult un minut.';
}

/// The flat map containing all translations for locale <ro>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsRo {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Salvează',
			'common.ok' => 'OK',
			'common.cancel' => 'Anulare',
			'common.delete' => 'Șterge',
			'common.create' => 'Creează',
			'common.error' => 'Eroare',
			'common.close' => 'Închide',
			'common.done' => 'Gata',
			'common.callsign' => 'Indicativ',
			'common.clear' => 'Golește',
			'common.dismiss' => 'Închide',
			'common.copyDetails' => 'Copiază detaliile',
			'common.expand' => 'Extinde',
			'common.collapse' => 'Restrânge',
			'onboarding.welcomeTitle' => 'Bun venit în Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Bun venit în Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Avem câteva întrebări care ne ajută să ne adaptăm mai bine nevoilor dvs.',
			'onboarding.skip' => 'Omite',
			'onboarding.kContinue' => 'Continuă',
			'onboarding.back' => 'Înapoi',
			'onboarding.next' => 'Următorul',
			'onboarding.done' => 'Gata',
			'onboarding.callsignTitle' => 'Care este indicativul dvs.?',
			'onboarding.callsignBody' => 'Aveți nevoie de o licență de radioamator pentru ca această aplicație să vă fie utilă',
			'onboarding.callsignLabel' => 'Indicativul operatorului',
			'onboarding.alreadyHaveAccount' => 'Aveți deja un cont?',
			'onboarding.foundSiblingTitle' => 'Conectați un cont existent?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Am găsit ${app} pe acest dispozitiv. Conectați această aplicație la același cont și indicativul și jurnalele dvs. vor fi preluate.',
			'onboarding.foundPoloBody' => 'Am găsit o versiune mai veche de Ham2K Portable Logger pe acest dispozitiv. Conectați această aplicație la același cont și indicativul și jurnalele dvs. vor fi preluate.',
			'onboarding.foundSiblingsBody' => 'Am găsit alte aplicații Ham2K pe acest dispozitiv. Conectați această aplicație la unul dintre conturile lor și indicativul și jurnalele dvs. vor fi preluate.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Conectare cu ${app}',
			'onboarding.linkWithPolo' => 'Conectare cu contul din versiunea veche',
			'onboarding.setUpFresh' => 'Configurare de la zero',
			'onboarding.activitiesTitle' => 'Activități preferate',
			'onboarding.activitiesBody' => 'Vă interesează vreunul dintre aceste programe de activare populare?',
			'onboarding.activitiesFooter' => '(Găsiți mai multe opțiuni în Setări)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'Sincronizare în cloud',
			'onboarding.syncBody' => 'Ham2K Log Filer păstrează o copie de rezervă a jurnalelor dvs. în cloud și le sincronizează pe toate dispozitivele pe care folosiți aplicații Ham2K.',
			'onboarding.syncPricing' => 'Este gratuit! Dar un abonament plătit îl face mai rapid.',
			'onboarding.syncLabel' => 'Activează sincronizarea în cloud',
			'onboarding.syncOffWarning' => 'ATENȚIE: astfel cresc șansele de a pierde datele operațiunilor, de exemplu dacă dispozitivul se strică sau se pierde.',
			'onboarding.notNow' => 'Nu acum',
			'onboarding.consentTitle' => 'Date și confidențialitate',
			'onboarding.consentUsageBody' => 'Pentru a ne ajuta să îmbunătățim aplicația, am dori să colectăm date despre performanță, blocări și utilizarea aplicației.',
			'onboarding.consentUsageLabel' => 'Partajează datele de utilizare a aplicației',
			'onboarding.consentOperationBody' => 'Unele funcții pot implica partajarea datelor operațiunilor dvs. cu alți utilizatori. Puteți renunța oricând.',
			'onboarding.consentOperationLabel' => 'Partajează datele operațiunilor',
			'onboarding.finishingSetup' => 'Se finalizează configurarea — se descarcă datele de referință…',
			'startScreen.credits' => 'de către KI2D și prietenii',
			'testerOverlay.tape' => 'ATENȚIE: ÎN CONSTRUCȚIE',
			'testerOverlay.warningTitle' => 'Această aplicație este în lucru',
			'testerOverlay.warningBody' => 'Majoritatea funcțiilor au suprafețe denivelate și peste tot sunt pericole de împiedicare. Verificați regulat dacă există actualizări.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Ce este nou în versiunea ${build}',
			'testerOverlay.thanks' => 'Vă mulțumim că vă puneți jurnalul în pericol pentru a ne ajuta să îmbunătățim această aplicație!',
			'extensionsPanel.categoryActivity' => 'Activități',
			'extensionsPanel.categoryAward' => 'Diplome',
			'extensionsPanel.categoryContest' => 'Concursuri',
			'extensionsPanel.categoryLookup' => 'Căutări de indicative',
			'extensionsPanel.categorySpots' => 'Surse de spoturi',
			'extensionsPanel.categoryDashboard' => 'Panouri de bord',
			'extensionsPanel.categoryOther' => 'Alte extensii',
			'extensionsPanel.searchHint' => 'Căutați extensii',
			'extensionsPanel.applying' => 'Se aplică modificările extensiilor, poate dura un moment…',
			'extensionsPanel.noMatches' => 'Nicio extensie nu corespunde căutării',
			'extensionsPanel.installFromFile' => 'Instalare din fișier…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versiunea ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Captura de ecran ${n} din ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Captura anterioară',
			'extensionsPanel.nextScreenshot' => 'Captura următoare',
			'extensionsPanel.screenshotUnavailable' => 'Captură indisponibilă',
			'extensionsPanel.canReach' => 'Această extensie poate contacta',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, printr-o conexiune activă',
			'extensionsPanel.canHoldLocalConnection' => 'Dispozitive din rețeaua dvs. locală, printr-o conexiune activă',
			'extensionsPanel.canUseLocation' => 'Locația dvs.',
			'extensionsPanel.canReadRadio' => 'Stația dvs. radio, pentru a-i citi frecvența și modul',
			'extensionsPanel.canControlRadio' => 'Stația dvs. radio, pentru a o controla și a emite cu ea — acord, putere, CW, memorii vocale și PTT',
			'extensionsPanel.canCommandRadioRaw' => 'Stația dvs. radio, pentru a-i trimite orice comandă în propriul ei protocol — inclusiv comenzi care emit sau îi schimbă setările',
			'extensionsPanel.canReadCluster' => 'Clusterul DX, autentificat ca dvs., pentru a citi ce trimite acesta',
			'extensionsPanel.canSpotCluster' => 'Clusterul DX, autentificat ca dvs., pentru a posta spoturi în numele dvs.',
			'extensionsPanel.canCommandCluster' => 'Clusterul DX, autentificat ca dvs., pentru a-i trimite orice comandă în numele dvs.',
			'extensionsPanel.canSetUserAgent' => 'Se identifică la servere sub propriul nume',
			'extensionsPanel.canChangeSettings' => 'Setările dvs., pentru a le schimba prin comenzile sale: orice setare, modul dezvoltator și experimentele',
			'extensionsPanel.noCapabilities' => 'Nu solicită nimic în afara aplicației.',
			'extensionsPanel.sandboxNote' => 'Extensiile rulează izolat: fără acces la fișierele dvs. și fără rețea în afara celor enumerate aici.',
			'extensionsPanel.installAction' => 'Instalează',
			'extensionsPanel.updateAction' => 'Actualizează',
			'extensionsPanel.installFailed' => 'Extensia nu a putut fi instalată',
			'extensionsPanel.installedBadge' => 'Instalată',
			'extensionsPanel.uninstallAction' => 'Elimină',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Eliminați ${name}?',
			'extensionsPanel.uninstallBody' => 'Această extensie și setările ei vor fi eliminate. Jurnalele dvs. rămân neatinse.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} a fost instalată',
			'extensionsPanel.installDownloading' => 'Se descarcă…',
			'extensionsPanel.installWaiting' => 'Se așteaptă instalarea…',
			'extensionsPanel.installInstalling' => 'Se instalează…',
			'extensionsPanel.installAwaitingApproval' => 'Se așteaptă aprobarea dvs.…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} se instalează deja.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Actualizată la ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Instalarea ${name} nu s-a finalizat. Poate fi necesară reinstalarea.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name} nu a putut fi eliminată',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Descărcată de la ${source}',
			'extensionsPanel.dropHint' => 'Plasați aici o extensie .h2kext pentru a o instala',
			'extensionsPanel.dropOneOnly' => 'Plasați câte o singură extensie.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} a returnat ${status} pentru această extensie.',
			'extensionsPanel.downloadTooLarge' => 'Descărcarea este mult prea mare pentru a fi o extensie.',
			'extensionsPanel.downloadNotSecure' => 'Descărcarea a fost redirecționată către o adresă nesigură.',
			'extensionsPanel.catalogSection' => 'Catalog',
			'extensionsPanel.catalogLoading' => 'Se încarcă catalogul…',
			'extensionsPanel.catalogUnreachable' => 'Catalogul nu poate fi accesat',
			'extensionsPanel.builtIn' => 'Integrată',
			'extensionsPanel.updateAvailableBadge' => 'Actualizare disponibilă',
			'extensionsPanel.updatesAvailableTitle' => 'Actualizări de extensii',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Este disponibilă o actualizare pentru ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} și încă ${count} trebuie actualizate.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} trebuie actualizate.',
			'extensionsPanel.pendingUpdatesSection' => 'Actualizări în așteptare',
			'extensionsPanel.updateAllAction' => 'Actualizează tot',
			'extensionsPanel.updatesUnderWay' => 'Aceste actualizări sunt deja în curs.',
			'extensionsPanel.updatesNothingLeft' => 'Extensiile dvs. sunt la zi.',
			'extensionsPanel.updatesNoticeAction' => 'Mai multe informații',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Actualizați ${count} extensie?', other: 'Actualizați ${count} extensii?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Extensiile dvs. sunt pregătite',
			'extensionsPanel.upgradeDoneBody' => 'Acum provin din catalogul de extensii Ham2K, deci pot fi actualizate fără a aștepta o nouă versiune a aplicației.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Neactualizate: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Nu au pornit: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Sunt încă instalate și marcate în Setări › Extensii — actualizarea lor acolo le va readuce.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Catalogul nu are înlocuitori direcți pentru acestea, așa că căutați acolo extensii care acoperă ce foloseați.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Evenimente State Parks',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} dintre extensiile dvs. nu au sosit încă. Vor fi descărcate data viitoare când catalogul de extensii este accesibil.',
			'extensionsPanel.runtimeDeadBody' => 'Extensiile dvs. nu au pornit. Repornirea aplicației ar trebui să le readucă.',
			'extensionsPanel.refusedTitle' => 'Unele extensii nu au pornit',
			'extensionsPanel.upgradeBusyTitle' => 'Configurarea este încă în curs',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Extensiile dvs. nu rulează',
			'extensionsPanel.restoreTitle' => 'Unele dintre extensiile dvs. lipsesc',
			'extensionsPanel.restoreBody' => 'Aceste extensii instalate de dvs. nu se află pe acest dispozitiv. Le putem descărca din nou din catalogul de extensii Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Instalate dintr-un fișier. Instalați-le din nou din fișierele lor sau uitați-le:',
			'extensionsPanel.restoreOtherCatalog' => 'Instalate dintr-un alt catalog de extensii, deci nu sunt disponibile aici:',
			'extensionsPanel.restoreForget' => 'Uită',
			'extensionsPanel.restoreInstall' => 'Instalează',
			'extensionsPanel.restoreLater' => 'Mai târziu',
			'extensionsPanel.restoreInstalling' => 'Se instalează extensiile dvs.…',
			'extensionsPanel.restoreDoneTitle' => 'Extensiile dvs. au revenit',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Reinstalate: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Unele extensii nu au putut fi instalate',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Nu s-au putut instala: ${names}. Vi le vom oferi din nou la următoarea deschidere a aplicației.',
			'extensionsPanel.restoreBusyBody' => 'Aplicația încă vă configurează extensiile. Vi le vom oferi din nou la următoarea deschidere a aplicației.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Le-am reinstalat, dar extensiile dvs. nu au pornit. Repornirea aplicației ar trebui să le readucă.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} a fost retrasă',
			'extensionsPanel.revokedBody' => 'Catalogul a retras această versiune, așa că a fost dezactivată.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => '${name} a fost dezactivată',
			'extensionsPanel.forceDisabledBody' => 'Ham2K a dezactivat deocamdată această extensie.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name} a fost înlocuită',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => '${replacement} îi ia locul. Puteți trece la ea din Extensii.',
			'extensionsPanel.replacedBy' => ({required Object name}) => 'Înlocuită de ${name}',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'Înlocuită de ${name}, pe care o aveți deja',
			'extensionsPanel.replaceAction' => 'Înlocuiește',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => 'Setările ei trec la ${replacement}, pe care o aveți deja. Jurnalele dvs. rămân neatinse.',
			'extensionsPanel.downloadHashMismatch' => 'Descărcarea nu este extensia descrisă de catalog.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Catalogul nu are versiunea ${version} a ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Linkul de catalog nu indică o versiune de extensie.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Catalogul nu are nicio lansare a ${key} pe acest canal.',
			'extensionsPanel.installFromLink' => 'Instalare din link',
			'extensionsPanel.unstableReleaseWarning' => 'Aceasta este o versiune instabilă, pe care editorul ei nu a declarat-o finalizată. Poate funcționa greșit și va primi în continuare actualizări instabile.',
			'extensionsPanel.bleedingReleaseWarning' => 'Aceasta este o versiune în dezvoltare: lucru în curs care se poate strica sau își poate pierde setările. Va primi în continuare actualizări în dezvoltare.',
			'extensionsPanel.channelUnstable' => 'Instabil',
			'extensionsPanel.channelBleeding' => 'În dezvoltare',
			'extensionsPanel.followsUnstable' => 'Primește versiuni instabile și stabile',
			'extensionsPanel.followsBleeding' => 'Primește versiuni în dezvoltare, instabile și stabile',
			'extensionsPanel.followStableAction' => 'Urmărește doar versiunile stabile',
			'extensionsPanel.revokedBadge' => 'Retrasă',
			'extensionsPanel.forceDisabledBadge' => 'Dezactivată de Ham2K',
			'extensionsPanel.refusedBadge' => 'Nu s-a încărcat',
			'extensionsPanel.downloadNotHttps' => 'Descărcarea nu se face printr-o conexiune securizată.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} nu a putut fi accesat pentru această extensie.',
			'extensionsPanel.detailsAction' => 'Detalii',
			'extensionsPanel.installedFromFile' => 'Instalată dintr-un fișier',
			'extensionsPanel.detailsWhatItDoes' => 'Oferă suport pentru',
			'extensionsPanel.installedPreloaded' => 'Preinstalată',
			'extensionsPanel.hookAccount' => 'Autentificare în cont',
			'extensionsPanel.hookCallNotes' => 'Note de indicativ',
			'extensionsPanel.hookDataFile' => 'Date offline',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Căutări de indicative',
			'extensionsPanel.hookScoring' => 'Punctaj',
			'extensionsPanel.hookSpots' => 'Spoturi',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Vânătoare ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Activare ${program}',
			'extensionsPanel.suggestedSection' => 'Sugerate',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => 'Mai multe disponibile (${count})',
			'home.title' => 'Jurnal Portabil',
			'home.newOperation' => 'Operațiune nouă',
			'home.stationCallsign' => 'Indicativul stației',
			'home.titleOptional' => 'Titlu (opțional)',
			'home.emptyList' => 'Nicio operațiune încă. Creați una pentru a începe să înregistrați.',
			'home.quickLookup' => 'Căutare rapidă',
			'home.nav.operations' => 'Operațiuni',
			'home.nav.chase' => 'Vânătoare',
			'home.nav.logs' => 'Jurnale',
			'home.nav.maps' => 'Hărți',
			'home.nav.settings' => 'Setări',
			'home.panels.operations' => 'Listă de operațiuni',
			'home.panels.operationsDescription' => 'Operațiunile dvs., cele mai recente primele.',
			'home.panels.version' => 'Versiunea curentă',
			'home.panels.versionDescription' => 'Sigla Ham2K, numele acestei aplicații și versiunea pe care o rulați.',
			'home.toggleNav' => 'Afișează sau ascunde etichetele de navigare',
			'home.logs.title' => 'Jurnale',
			'home.logs.titleFor' => 'Jurnale pentru',
			'home.logs.emptyCallsigns' => 'Niciun QSO înregistrat încă',
			'home.logs.emptyQsos' => ({required Object call}) => 'Niciun QSO pentru ${call}',
			'home.logs.mapNoSelection' => 'Selectați un QSO pentru a-l vedea pe hartă',
			'home.logs.searchHint' => 'Căutați indicativ sau nume',
			'home.logs.noSearchMatches' => 'Niciun QSO nu corespunde căutării',
			'home.logs.titleAll' => 'Toate jurnalele',
			'home.logs.allCallsigns' => 'Toate indicativele',
			'home.logs.noOperation' => 'Nu face parte dintr-o operațiune',
			'home.logs.unsavedTitle' => 'Modificări nesalvate',
			'home.logs.unsavedBody' => 'Acest QSO are modificări pe care nu le-ați salvat.',
			'home.logs.pendingDeleteBody' => 'Acest QSO este marcat pentru ștergere.',
			'home.logs.editGone' => 'Nesalvat: acest QSO nu mai este în jurnal.',
			'home.logs.discard' => 'Renunță',
			'home.logs.sheet.callsigns' => 'Indicative de stație',
			'home.logs.sheet.groupBy' => 'Grupare',
			'home.logs.sheet.period' => 'Perioadă',
			'home.logs.groupBy.none' => 'Negrupat',
			'home.logs.groupBy.date' => 'Dată',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Continent necunoscut',
			'home.logs.groupBy.unknownEntity' => 'Entitate necunoscută',
			'home.logs.groupBy.unknownDate' => 'Fără dată',
			'home.logs.period.thisMonth' => 'Luna aceasta',
			'home.logs.period.last3Months' => 'Ultimele 3 luni',
			'home.logs.period.thisYear' => 'Anul acesta',
			'home.logs.period.lastYear' => 'Anul trecut',
			'home.logs.period.allTime' => 'Dintotdeauna',
			'home.logs.period.custom' => 'Interval personalizat',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => 'în ${span}',
			'home.logs.periodTitle.custom' => 'Interval personalizat',
			'home.logs.columns.date' => 'Dată',
			'home.logs.columns.time' => 'Ora',
			'home.logs.columns.freq' => 'Frecvență',
			'home.logs.columns.mode' => 'Mod',
			'home.logs.columns.call' => 'Indicativ',
			'home.logs.columns.name' => 'Nume',
			'home.logs.columns.station' => 'Stație',
			'home.logs.columns.band' => 'Bandă',
			'home.logs.columns.sent' => 'Trimis',
			'home.logs.columns.rcvd' => 'Primit',
			'home.logs.columns.grid' => 'Grilă',
			'home.logs.columns.state' => 'Stat',
			'home.logs.columns.country' => 'Țară',
			'home.logs.columns.refs' => 'Ref.',
			'home.logs.panels.qsos' => 'Jurnal QSO',
			'home.logs.panels.qsosDescription' => 'QSO-urile indicativului selectat, din toate operațiunile.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Numărul total de QSO-uri sau căutarea indicativului QSO-ului selectat.',
			'home.logs.panels.map' => 'Hartă',
			'home.logs.panels.mapDescription' => 'Locația QSO-ului selectat.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicative: ${calls}',
			'home.logs.import.skippedOne' => '1 înregistrare nu a putut fi citită',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} înregistrări nu au putut fi citite',
			'home.logs.import.readingTitle' => 'Se citește fișierul ADIF…',
			'home.logs.import.checkingTitle' => 'Se verifică duplicatele…',
			'home.logs.import.importingTitle' => 'Se importă QSO-urile…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} din ${total} verificate',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importate, din ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'vânătoare',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} și ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} și altele',
			'chase.station.title' => 'Stația de vânătoare',
			'chase.station.stationLabel' => 'Stație: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Fără locație',
			'chase.periodInline.today' => 'astăzi',
			'chase.periodInline.thisWeek' => 'săptămâna aceasta',
			'chase.periodInline.last14Days' => 'în ultimele 14 zile',
			'chase.periodInline.thisMonth' => 'luna aceasta',
			'chase.periodStats.today' => 'Statistici pentru astăzi',
			'chase.periodStats.thisWeek' => 'Statistici pentru săptămâna aceasta',
			'chase.periodStats.last14Days' => 'Statistici pentru ultimele 14 zile',
			'chase.periodStats.thisMonth' => 'Statistici pentru luna aceasta',
			'chase.period.today' => 'Astăzi',
			'chase.period.thisWeek' => 'Săptămâna aceasta',
			'chase.period.last14Days' => 'Ultimele 14 zile',
			'chase.period.thisMonth' => 'Luna aceasta',
			'chase.goals.title' => 'Obiective de vânătoare',
			'chase.goals.remove' => ({required Object name}) => 'Opriți vânarea ${name}',
			'chase.goals.extensionsTitle' => 'Mai multe programe de vânătoare',
			'chase.panels.logging' => 'QSO-uri',
			'chase.panels.loggingDescription' => 'Controalele de înregistrare deasupra QSO-urilor vânate în perioada respectivă.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Indicativul care se înregistrează sau statisticile perioadei.',
			'chase.panels.spots' => 'Spoturi',
			'chase.panels.spotsDescription' => 'Stații spotate în eter, gata de vânat.',
			'chase.panels.map' => 'Hartă',
			'chase.panels.mapDescription' => 'QSO-urile perioadei și stația care se înregistrează.',
			'chase.claims.checking' => 'Se verifică QSO-urile pentru vânătoare',
			'chase.claims.rebuilding' => ({required Object program}) => 'Se verifică jurnalul pentru ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} din ${total} QSO-uri',
			'chase.notice.newRef' => ({required Object program}) => '${program} nou',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Probabil ${program} nou',
			'chase.notice.newBand' => ({required Object program}) => 'Bandă nouă ${program}',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Probabil bandă nouă ${program}',
			'chase.notice.newMode' => ({required Object program}) => 'Mod nou ${program}',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Probabil mod nou ${program}',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} neconfirmat',
			'chase.notice.programGuess' => ({required Object notice}) => 'Probabil ${notice}',
			'chase.alerts.title' => 'Alerte',
			'chase.alerts.newRef' => 'Referință nouă',
			'chase.alerts.newBand' => 'Bandă nouă',
			'chase.alerts.newMode' => 'Mod nou',
			'chase.alerts.unconfirmed' => 'Neconfirmat',
			'chase.checklists' => 'Progres vânătoare',
			'chase.imports.importFrom' => ({required Object label}) => 'Importă ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Importă ${file} ca',
			'chase.imports.dropHint' => 'Plasați aici un fișier pentru a-l importa într-un program de vânătoare',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'S-au importat ${count} intrări ${program} din ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'S-au importat ${count} intrări ${program} din ${file}; ${skipped} nu au putut fi citite și au fost omise',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} nu conține nimic ce ${program} poate importa',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program} nu a putut citi ${file}',
			'chase.imports.unreadable' => ({required Object program, required Object skipped, required Object file}) => '${program} nu a putut citi niciuna dintre cele ${skipped} înregistrări din ${file}',
			'chase.imports.noProgram' => ({required Object file}) => 'Niciun program de vânătoare nu importă ${file}',
			'dialogs.operationDetails' => 'Detalii operațiune',
			'dialogs.activities' => 'Activități',
			'dialogs.stationCallsign' => 'Indicativul stației',
			'dialogs.advanced' => 'Avansat',
			'dialogs.operatingPosition' => 'Poziție de operare (multi-stație)',
			'dialogs.assistance' => 'Asistență',
			'dialogs.assistanceDescription' => 'Folosește servicii de spotare și alte surse de informații',
			'dialogs.selfSpotting' => 'Auto-spotare',
			'dialogs.selfSpottingDescription' => 'Permite funcțiile care raportează propria dvs. frecvență',
			'dialogs.disabledByRules' => ({required Object rules}) => 'Dezactivat pentru a respecta regulile ${rules}',
			'dialogs.lookupDespiteAssistance.title' => 'Căutați online?',
			'dialogs.lookupDespiteAssistance.body' => 'Asistența este dezactivată pentru această operațiune. Căutarea tuturor QSO-urilor va folosi servicii online precum QRZ doar de această dată.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'Asistența este dezactivată pentru această operațiune, pentru a respecta regulile ${rules}. Căutarea tuturor QSO-urilor va folosi servicii online precum QRZ doar de această dată.',
			'dialogs.lookupDespiteAssistance.action' => 'Caută online',
			'dialogs.notes' => 'Notițe',
			'dialogs.deleteOperationTitle' => 'Șterge operațiunea',
			'dialogs.purgeTestsTitle' => 'Elimină operațiunile de test',
			'dialogs.purgeTestsBody' => 'Aceasta șterge definitiv aceste operațiuni de test și QSO-urile lor. Acțiunea nu poate fi anulată.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Plus ${count} contact de test care nu aparține niciunei operațiuni.', other: 'Plus ${count} contacte de test care nu aparțin niciunei operațiuni.', ), 
			'dialogs.purgeTestsAction' => 'Elimină',
			'dialogs.syncAllTitle' => 'Înlocuiți jurnalul acestui dispozitiv?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL salvează și șterge ${qsos} de pe acest dispozitiv, apoi descarcă din nou jurnalul contului de pe server. Copia de rezervă rămâne în baza de date a acestui dispozitiv.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${n} QSO nu a fost încă sincronizat — serverul nu l-a primit niciodată și NU va mai reveni.', other: '${n} QSO-uri nu au fost încă sincronizate — serverul nu le-a primit niciodată și NU vor mai reveni.', ), 
			'dialogs.syncAllAction' => 'Șterge și resincronizează',
			'dialogs.receivedPurgesTitle' => 'Operațiuni de test eliminate în altă parte',
			'dialogs.receivedPurgesBody' => 'Acestea au fost șterse ca operațiuni de test pe alt dispozitiv. Le eliminați și aici? Aceasta le șterge definitiv, împreună cu QSO-urile lor, și nu poate fi anulată.',
			'dialogs.receivedPurgesAction' => 'Elimină',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicativ invalid: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicative invalide: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Până acum a operat ${previous}. ${typed} va fi înregistrat pentru contactele noi.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Niciun operator înregistrat până acum. ${typed} va fi înregistrat pentru contactele noi.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Această operațiune are deja contacte făcute de ${calls}. ${typed} va fi înregistrat doar pentru cele noi.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Înregistrați ${typed} și ca operator al contactului deja înregistrat', other: 'Înregistrați ${typed} și ca operator al tuturor celor ${count} contacte deja înregistrate', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Când se folosesc mai multe stații în eter, operatorii separați nu sunt acceptați',
			'dialogs.callChange.contactsUnreadable' => 'Contactele acestei operațiuni nu au putut fi citite, deci schimbarea unui indicativ aici nu va oferi actualizarea lor',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Contactele deja înregistrate nu au putut fi actualizate, deci nu s-a făcut nicio modificare: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} din ${planned} contacte au fost actualizate — restul nu mai sunt în această operațiune',
			'operation.deletedReadOnly' => 'Această operațiune este ștearsă. Restaurați-o pentru a înregistra sau a face modificări.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO-uri',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTURI',
			'operation.tabs.map' => 'HARTĂ',
			'operation.tabs.qsosPlain' => 'QSO-uri',
			'operation.tabs.clock' => 'Ceas',
			'operation.tabs.weather' => 'Vreme',
			'operation.tabs.website' => 'Site web',
			'operation.tabs.remoteScreen' => 'Ecran la distanță',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Radio',
			'operation.tabs.rotator' => 'Rotor',
			'operation.tabs.summaries' => 'Rezumate operațiune',
			'operation.positions.nobodyYet' => 'Nicio altă poziție de operare nu partajează încă această operațiune.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Poz: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Altă poziție',
			'operation.positions.thisDevice' => 'Poziția noastră de operare',
			'operation.positions.nameIn' => ' în ',
			'operation.positions.panelTitle' => 'Poziții',
			'operation.positions.panelDescription' => 'Ce înregistrează chiar acum fiecare poziție de operare care partajează această operațiune.',
			'operation.stationCallsignNone' => 'Fără indicativ de stație',
			'operation.titleNone' => 'Fără titlu',
			'operation.deleteOperation' => 'Șterge operațiunea',
			'operation.loggingControlsStale' => 'Câmpurile activităților pot fi neactualizate — redeschideți operațiunea pentru a le reîmprospăta',
			'operation.locationNone' => 'Nesetată',
			'operation.generalOperation' => 'Operațiune generală',
			'operation.titleFor' => ({required Object value}) => 'pentru ${value}',
			'operation.titleAt' => ({required Object value}) => 'la ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Acum ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'Afișează câmpurile RST',
			'operation.menu.showStateField' => 'Afișează câmpul Stat',
			'operation.menu.showGridField' => 'Afișează câmpul Grilă',
			'operation.menu.showDeletedQsos' => 'Afișează QSO-urile șterse',
			'operation.menu.showDeletedOps' => 'Afișează operațiunile șterse',
			'operation.menu.showQsoNumbers' => 'Afișează numerele QSO',
			'operation.menu.lookupAllQsos' => 'Caută toate QSO-urile',
			'operation.menu.loggingSettingsTitle' => 'Setări de înregistrare',
			'operation.menu.mapSettingsTitle' => 'Setări hartă',
			'operation.menu.actionsSection' => 'Acțiuni',
			'operation.layout.title' => 'Adaugă un panou',
			'operation.layout.availableSection' => 'Panouri disponibile',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Setări ${panel}',
			'operation.layout.panelSettingsAction' => 'Setări panou',
			'operation.layout.viewName' => 'Vizualizare operațiune',
			'operation.layout.viewOptions' => 'Opțiuni de aranjare a vizualizării',
			'operation.layout.viewTitleBuiltIn' => 'Această vizualizare este integrată în aplicație, la fel și numele ei',
			'operation.layout.resetOptions' => 'Restabilește valorile implicite',
			'operation.layout.removePane' => 'Elimină',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Restabiliți ${panel} la valorile implicite?',
			'operation.layout.resetPaneConfirmBody' => 'Titlul, antetul și dimensiunea revin la valorile implicite. Restul aranjamentului rămâne neschimbat.',
			'operation.layout.resetViewConfirm' => 'Restabiliți această vizualizare la aranjamentul implicit?',
			'operation.layout.resetViewConfirmBody' => 'Panourile revin la aranjamentul implicit, iar opțiunile vizualizării și ale fiecărui panou revin la valorile implicite.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Setări de aranjare ${panel}',
			'operation.layout.paneTitle' => 'Titlu',
			'operation.layout.paneShowHeader' => 'Afișează antetul',
			'operation.layout.paneShowHeaderTabset' => 'Afișat mereu cât timp acest panou face parte dintr-un grup — antetul este calea către celelalte',
			'operation.layout.paneInherit' => 'La fel ca aplicația',
			'operation.layout.searchHint' => 'Căutați panouri',
			'operation.layout.noPanelsMatch' => 'Niciun panou nu corespunde căutării.',
			'operation.layout.nothingToAdd' => 'Această vizualizare are deja toate panourile posibile',
			'operation.layout.addPanel' => ({required Object panel}) => 'Adaugă ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Previzualizare ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Extensia „${name}” lipsește',
			'operation.layout.missingExtensionEnable' => 'Activează',
			'operation.layout.missingExtensionInstall' => 'Instalează…',
			'operation.layout.missingExtensionWontRun' => 'Această versiune nu va porni. Actualizați-o din Setări › Extensii.',
			'operation.layout.missingExtensionUnavailable' => 'Nu este disponibilă în această aplicație',
			'operation.layout.missingExtensionNotInCatalog' => 'Nu este în catalog',
			'operation.layout.missingExtensionCatalogUnreachable' => 'Catalogul nu a putut fi accesat. Încercați din nou',
			'operation.layout.missingExtensionFailed' => 'Nu a mers. Încercați din nou',
			'operation.layout.previewUnavailable' => 'Imaginea de previzualizare a acestui panou nu a putut fi afișată.',
			'operation.layout.nestedPaneTitle' => 'Mai multe',
			'operation.layout.layouts.defaultName' => 'Implicit',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Aranjamentul ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Aranjament: ${name}',
			'operation.layout.layouts.menuNew' => 'Nou…',
			'operation.layout.layouts.menuExport' => 'Exportă…',
			'operation.layout.layouts.menuImport' => 'Importă…',
			'operation.layout.layouts.menuTitle' => 'Aranjamente',
			'operation.layout.layouts.newTitle' => 'Aranjament nou',
			'operation.layout.layouts.editTitle' => 'Editează aranjamentul',
			'operation.layout.layouts.edit' => 'Editează',
			'operation.layout.layouts.duplicateCurrent' => 'Duplică aranjamentul curent',
			'operation.layout.layouts.startFromDefault' => 'Pornește de la aranjamentul implicit',
			'operation.layout.layouts.nameLabel' => 'Nume',
			'operation.layout.layouts.descriptionLabel' => 'Descriere',
			'operation.layout.layouts.create' => 'Creează',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'Salvați modificările la „${name}”?',
			'operation.layout.layouts.leaveEditBody' => 'Acest aranjament are modificări pe care nu le-ați salvat.',
			'operation.layout.layouts.discard' => 'Renunță',
			'operation.layout.layouts.deleteTitle' => 'Ștergeți acest aranjament?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'Sigur doriți să ștergeți aranjamentul „${name}”?',
			'operation.layout.layouts.exportTitle' => 'Exportă aranjamentul',
			'operation.layout.layouts.exportPick' => 'Panouri de exportat',
			'operation.layout.layouts.tabSet' => 'Grup de file',
			'operation.layout.layouts.exportAction' => 'Exportă',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Aranjament salvat în ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'Aranjamentul nu a putut fi exportat: ${error}',
			'operation.layout.layouts.importTitle' => 'Importă aranjament',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Făcut pentru vizualizarea ${view}: panourile pe care le are doar acea vizualizare sunt omise.',
			'operation.layout.layouts.viewHome' => 'Acasă',
			'operation.layout.layouts.viewOperation' => 'Operațiune',
			'operation.layout.layouts.viewLogs' => 'Jurnale',
			'operation.layout.layouts.viewChase' => 'Vânătoare',
			'operation.layout.layouts.importAsNew' => 'Ca aranjament nou',
			'operation.layout.layouts.importReplace' => 'În locul acestui aranjament',
			'operation.layout.layouts.importAdd' => 'Adăugate la acest aranjament',
			'operation.layout.layouts.importAddHint' => 'Panourile sosesc într-o coloană nouă, în dreapta.',
			'operation.layout.layouts.importPick' => 'Panouri de importat',
			'operation.layout.layouts.importReplaceSettings' => 'Înlocuiește setările panourilor deja configurate aici',
			'operation.layout.layouts.importAction' => 'Importă',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} nu este un aranjament pe care aplicația îl poate citi: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'textul nu este YAML valid (linia ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'nu este un fișier de aranjament Ham2K',
			'operation.layout.layouts.problemNewerVersion' => 'a fost scris de o versiune mai nouă a aplicației',
			'operation.layout.layouts.problemNoArrangement' => 'nu conține niciun aranjament',
			'operation.layout.layouts.problemMalformed' => 'o parte din el nu respectă formatul de aranjament',
			'operation.layout.layouts.problemTooLarge' => 'este prea mare',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'Fișierul nu a putut fi deschis: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'Aranjamentul nu a putut fi importat: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'Aranjamentul nu a putut fi copiat: ${error}',
			'operation.layout.layouts.importNothing' => 'Niciun panou ales, așa că nu s-a importat nimic.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'Omise: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => 'Păstrat ${panels}: aranjamentul pentru ecrane mici nu se poate lipsi de el.',
			'operation.layout.layouts.notOffered' => 'Nu este disponibil în această vizualizare',
			'operation.layout.layouts.alreadyPlaced' => 'Deja în acest aranjament',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Necesită ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'Numele aranjamentelor nu au putut fi citite',
			'operation.layout.layouts.listRecoveredBody' => 'Lista de aranjamente a acestei vizualizări nu a putut fi citită. Toate aranjamentele sunt încă aici, numerotate în locul numelui.',
			'operation.layout.editLayout' => 'Editează aranjamentul',
			'operation.layout.saveLayout' => 'Salvează aranjamentul',
			'operation.layout.revertLayout' => 'Renunță la modificările de aranjament',
			'operation.layout.done' => 'Gata',
			'operation.layout.layoutUnreadableTitle' => 'Aranjamentul nu a putut fi citit',
			'operation.layout.layoutUnreadableBody' => 'Aranjamentul salvat nu a putut fi citit, așa că se afișează aranjamentul implicit. Originalul nu va fi suprascris până nu alegeți să-l păstrați pe acesta.',
			'operation.layout.layoutUnreadableAction' => 'Folosește acest aranjament',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} nu a putut fi afișat',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: a trimis mai mult de ${max} caractere',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: grafica lui are mai mult de ${max} elemente',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: grafica lui are mai mult de ${max} niveluri de imbricare',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => '${panel} nu a putut fi afișat: grafica lui nu este de sine stătătoare',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: scena lui are mai mult de ${max} straturi',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: scena lui are mai mult de ${max} controale',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: o parte a scenei lui are mai mult de ${max} intrări',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: un text din scenă depășește ${max} caractere',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => '${panel} nu a putut fi afișat: aranjamentul lui are mai mult de ${max} niveluri de imbricare',
			'operation.layout.panelRenderRetry' => 'Încercați din nou',
			'operation.layout.panelActionFailed' => 'Acțiunea panoului a eșuat. Încercați din nou.',
			'operation.layout.panels.loggingDescription' => 'Jurnalul și câmpurile de introducere',
			'operation.layout.panels.infoDescription' => 'Ce știm despre stația lucrată',
			'operation.layout.panels.spotsDescription' => 'Spoturi din clustere și programe de activitate',
			'operation.layout.panels.mapDescription' => 'Unde se află contactele',
			'operation.layout.panels.summariesDescription' => 'Statisticile și punctajele operațiunii, în secțiunile și ordinea alese de dvs.',
			'operation.layout.panels.summariesSections' => 'Secțiuni și ordine',
			'operation.layout.panels.summariesDays' => 'Fiecare zi',
			'operation.layout.panels.summariesReset' => 'Afișează tot',
			'operation.layout.panels.summariesAllHidden' => 'Toate secțiunile sunt ascunse. Alegeți-le pe cele de afișat în setările acestui panou.',
			'operation.layout.panels.clockDescription' => 'Un cadran de ceas, în orice fus orar',
			'operation.layout.panels.clockFace' => 'Cadran',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analogic',
			'operation.layout.panels.clockZone' => 'Fus orar',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Acest dispozitiv',
			'operation.layout.panels.clockShowSeconds' => 'Afișează secundele',
			'operation.layout.panels.weatherDescription' => 'Condițiile actuale și pentru următoarele opt ore, acolo unde operați',
			'operation.layout.panels.weatherUseOperationLocation' => 'Folosește locația operațiunii',
			'operation.layout.panels.weatherLocation' => 'Locație',
			'operation.layout.panels.weatherLocationDescription' => 'O grilă (FN31pr) sau lat,lon. Ignorată cât timp „Folosește locația operațiunii” este bifat.',
			'operation.layout.panels.weatherNoLocation' => 'Nicio locație setată. Dați acestui panou o locație în setările lui sau plasați-l într-o operațiune care are una.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Locația ${location} nu a putut fi citită. Folosiți o grilă precum FN31pr sau 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo nu a putut fi accesat — lipsește rețeaua? Se va reîncerca în curând.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo a răspuns, dar nu cu ceva lizibil. Se va reîncerca în curând.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'rafale ${speed}',
			'operation.layout.panels.panelAgeNow' => 'chiar acum',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'acum ${count} min', other: 'acum ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'acum ${count} oră', other: 'acum ${count} ore', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Necunoscut',
			'operation.layout.panels.weatherConditions.sunny' => 'Însorit',
			'operation.layout.panels.weatherConditions.clear' => 'Senin',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Predominant însorit',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Predominant senin',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parțial noros',
			'operation.layout.panels.weatherConditions.cloudy' => 'Noros',
			'operation.layout.panels.weatherConditions.foggy' => 'Ceață',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Ceață cu chiciură',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Burniță slabă',
			'operation.layout.panels.weatherConditions.drizzle' => 'Burniță',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Burniță puternică',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Burniță slabă care îngheață',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Burniță care îngheață',
			'operation.layout.panels.weatherConditions.lightRain' => 'Ploaie slabă',
			'operation.layout.panels.weatherConditions.rain' => 'Ploaie',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Ploaie puternică',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Ploaie slabă care îngheață',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Ploaie care îngheață',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Ninsoare slabă',
			'operation.layout.panels.weatherConditions.snow' => 'Ninsoare',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Ninsoare puternică',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Grăunțe de zăpadă',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Averse slabe',
			'operation.layout.panels.weatherConditions.showers' => 'Averse',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Averse puternice',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Averse slabe de ninsoare',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Averse de ninsoare',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Furtună',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Furtuni slabe cu grindină',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Furtună cu grindină',
			'operation.layout.panels.websiteDescription' => 'O pagină web aleasă de dvs., într-un panou',
			'operation.layout.panels.websiteUrl' => 'Adresă',
			'operation.layout.panels.websiteRefresh' => 'Reîmprospătare',
			'operation.layout.panels.websiteRefreshNever' => 'Niciodată',
			'operation.layout.panels.websiteRefresh1' => 'În fiecare minut',
			'operation.layout.panels.websiteRefresh5' => 'La fiecare 5 minute',
			'operation.layout.panels.websiteRefresh15' => 'La fiecare 15 minute',
			'operation.layout.panels.websiteTitle' => 'Numele panoului',
			'operation.layout.panels.websiteRefreshNow' => 'Reîmprospătează acum',
			'operation.layout.panels.websiteNoUrl' => 'Nicio adresă încă. Deschideți setările acestui panou pentru a alege o pagină.',
			'operation.layout.panels.websiteBadUrl' => 'Nu pare a fi o adresă web. Trebuie să înceapă cu https://',
			'operation.layout.panels.websiteNotHttps' => 'Doar adresele https:// pot fi afișate aici.',
			'operation.layout.panels.websiteUnsupported' => 'Paginile web nu pot fi afișate într-un panou pe acest sistem.',
			'operation.layout.panels.websiteOpenExternally' => 'Deschide în browser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Pagina nu a putut fi încărcată: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Un ecran, o aplicație sau o fereastră partajată de un alt dispozitiv al dvs.',
			'operation.layout.panels.remoteScreenTarget' => 'Ecran',
			'operation.layout.panels.remoteScreenChoose' => 'Alegeți un ecran…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Ecrane partajate',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Niciunul dintre dispozitivele dvs. nu partajează un ecran. Activați Partajare ecrane și ferestre din Setări → Dispozitive pereche, pe dispozitivul pe care doriți să-l vedeți.',
			'operation.layout.panels.remoteScreenUnset' => 'Niciun ecran ales. Deschideți setările acestui panou pentru a alege unul partajat de celelalte dispozitive.',
			'operation.layout.panels.remoteScreenConnecting' => 'Se conectează…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Acel dispozitiv nu este conectat acum.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Acel dispozitiv a oprit partajarea acestui ecran.',
			'operation.layout.panels.remoteScreenNoListener' => 'Acel dispozitiv nu poate accepta conexiuni — verificați-i firewall-ul.',
			'operation.layout.panels.remoteScreenNoLan' => 'Ecranele se partajează doar prin rețeaua locală, nu prin Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Acel dispozitiv a refuzat să partajeze acest ecran.',
			'operation.layout.panels.remoteScreenSettings' => 'Setări panou',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajustare vizualizare',
			'operation.layout.panels.remoteScreenDetail' => 'Detaliu',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Ridicat',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maxim',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Mărire',
			'operation.layout.panels.remoteScreenZoomOut' => 'Micșorare',
			'operation.layout.panels.remoteScreenStopped' => 'Acel ecran sau fereastră nu mai este afișat.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Acel dispozitiv nu a putut captura ecranul — poate necesita permisiunea de înregistrare a ecranului.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Acel dispozitiv nu a răspuns. Poate nu are partajarea ecranului activată.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Nu s-a putut deschide o conexiune pentru imagine. Verificați firewall-ul acestui dispozitiv.',
			'operation.layout.panels.solarDescription' => 'Condiții solare și geomagnetice, cu propagarea pe fiecare bandă',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com nu a putut fi accesat — lipsește rețeaua? Se va reîncerca în curând.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com a răspuns, dar nu cu o citire utilizabilă. Se va reîncerca în curând.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Zi',
			'operation.layout.panels.solarBandNight' => 'Noapte',
			'operation.layout.panels.solarBandGood' => 'Bună',
			'operation.layout.panels.solarBandFair' => 'Medie',
			'operation.layout.panels.solarBandPoor' => 'Slabă',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Surse: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Conexiunea are dificultăți — se omit cadre.',
			'operation.layout.panels.remoteScreenStalled' => 'Cadrele nu mai ajung — conexiunea poate fi prea lentă.',
			'operation.layout.panels.radioDescription' => 'Panoul frontal al unei stații radio — frecvență, mod și putere, sub control CAT',
			'operation.layout.panels.radioStyle' => 'Stil',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Stație radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — nicio stație radio desemnată',
			'operation.layout.panels.radioNoRadio' => 'Nicio stație radio de afișat. Alegeți una în setările acestui panou sau adăugați una în Configurația stației.',
			'operation.layout.panels.radioNotConfigured' => 'Această stație radio nu este încă configurată. Alegeți portul sau adresa în Configurația stației.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Stația radio nu este conectată',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Conectează această stație radio',
			'operation.layout.panels.radioDisconnect' => 'Deconectează această stație radio',
			'operation.layout.panels.radioStale' => 'FĂRĂ DATE',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR ridicat',
			'operation.layout.panels.rotatorDescription' => 'Încotro arată antena, pe o hartă centrată pe stație. Atingeți harta pentru a o roti.',
			'operation.layout.panels.rotatorRotator' => 'Rotor',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => 'Automat — ${name}',
			'operation.layout.panels.rotatorAutoNone' => 'Automat — încă niciun rotor',
			'operation.layout.panels.rotatorBeamWidth' => 'Lățimea fasciculului',
			'operation.layout.panels.rotatorBeamWidthDescription' => 'În grade, desenată în jurul direcției. 0 nu desenează nimic.',
			'operation.layout.panels.rotatorLocation' => 'Locație',
			'operation.layout.panels.rotatorLocationDescription' => 'O grilă sau o latitudine și o longitudine pe care să se centreze harta. Lăsată goală, folosește locația operațiunii.',
			'operation.layout.panels.rotatorTheme' => 'Temă',
			'operation.layout.panels.rotatorThemeColor' => 'Color',
			'operation.layout.panels.rotatorThemeGray' => 'Gri',
			'operation.layout.panels.rotatorThemeMuted' => 'Estompat',
			'operation.layout.panels.rotatorGrayline' => 'Afișează linia gri',
			'operation.layout.panels.rotatorNoRotator' => 'Niciun rotor de afișat. Alegeți unul în setările acestui panou sau adăugați unul în Configurația stației.',
			'operation.layout.panels.rotatorNoLocation' => 'Nicio locație pe care să se centreze harta. Setați una în setările acestui panou.',
			'operation.layout.panels.rotatorDisconnected' => 'deconectat',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => 'nu răspunde',
			'operation.layout.panels.rotatorLocationInvalid' => 'Locația din setările acestui panou nu poate fi citită. Folosiți o grilă sau o latitudine și o longitudine, ca 40.7, -74.0.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '${degrees}° el',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'V',
			'operation.layout.htmlPanelUnsupported' => 'Acest panou necesită o vizualizare web, pe care această platformă nu o oferă',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Acest panou necesită un mediu izolat pe care versiunea web nu îl poate oferi',
			'operation.export.title' => 'Exporturi operațiune',
			'operation.export.syncedOperation' => 'Operațiunea este sincronizată',
			'operation.export.unsyncedOperation' => 'Operațiunea are modificări nesincronizate',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} QSO în această operațiune', other: '${count} QSO-uri în această operațiune', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Toate cele ${total} QSO-uri sunt sincronizate',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} din ${total} QSO-uri așteaptă sincronizarea',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcaje de eveniment sincronizate',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} din ${total} marcaje de eveniment în așteptare',
			'operation.export.loading' => 'Se încarcă opțiunile de export…',
			'operation.export.noOptions' => 'Niciun format de export disponibil (mediul de extensii încă pornește?)',
			'operation.export.nothingLogged' => 'Nimic de exportat încă — această operațiune nu are QSO-uri.',
			'operation.export.share' => 'Partajează',
			'operation.export.nothingSelected' => 'Nimic selectat',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Salvează ${count} fișier', other: 'Salvează ${count} fișiere', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Partajează ${count} fișier', other: 'Partajează ${count} fișiere', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Exportă ${count} fișier', other: 'Exportă ${count} fișiere', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Descarcă ${count} fișier', other: 'Descarcă ${count} fișiere', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Salvează ${count} fișier combinat', other: 'Salvează ${count} fișiere combinate', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Partajează ${count} fișier combinat', other: 'Partajează ${count} fișiere combinate', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Exportă ${count} fișier combinat', other: 'Exportă ${count} fișiere combinate', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Descarcă ${count} fișier combinat', other: 'Descarcă ${count} fișiere combinate', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Salvează ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Partajează ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportă ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Descarcă ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Trimite ${count} fișier în Stash', other: 'Trimite ${count} fișiere în Stash', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Trimite ${count} fișier combinat în Stash', other: 'Trimite ${count} fișiere combinate în Stash', ), 
			'operation.export.settingsButton' => 'Setări export',
			'operation.export.settingsTitle' => 'Setări export',
			'operation.export.compactFileNames.title' => 'Folosește nume de fișiere compacte',
			'operation.export.compactFileNames.descriptionOn' => 'Nume scurte pentru programele de încărcare, ca N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nume lizibile, ca 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Include informații private',
			'operation.export.includePrivateData.descriptionOn' => 'Numele, adresele, e-mailurile, grilele și notițele sunt incluse',
			'operation.export.includePrivateData.descriptionOff' => 'Numele, adresele, e-mailurile, grilele și notițele sunt omise',
			'operation.export.includePrivateData.note' => 'Exportul ADIF complet include întotdeauna tot',
			'operation.export.resultTitle' => 'Export finalizat',
			'operation.export.resultFailedTitle' => 'Exportul a eșuat',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} fișier exportat în ${path}', other: '${count} fișiere exportate în ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} fișier exportat: ${path}', other: '${count} fișiere exportate: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} fișier partajat', other: '${count} fișiere partajate', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} fișier descărcat', other: '${count} fișiere descărcate', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Exportul a eșuat: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Adăugați mai întâi o adresă de e-mail',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash trimite fișierele dvs. la adresa de e-mail a contului LoFi, iar cu ea vă autentificați la stash.ham2k.net. Contul dvs. nu are încă una confirmată — adăugați-o în Setări › Sincronizare în cloud.',
			'operation.export.stash.openSyncSettings' => 'Deschide Sincronizare în cloud',
			'operation.export.stash.replaceTitle' => 'Stash-ul recent va fi înlocuit',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Ați trimis „${name}” cu mai puțin de 6 ore în urmă și încă nu a fost descărcat. Conturile gratuite păstrează un singur stash o dată, deci trimiterea acum îl înlocuiește.',
			'operation.export.stash.replaceConfirm' => 'Trimite oricum',
			'operation.export.stash.failedTitle' => 'Nu s-a putut trimite la Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'Trimis la Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Puteți recupera acest fișier vizitând **[stash.ham2k.net](https://stash.ham2k.net)** în orice browser.', other: 'Puteți recupera aceste fișiere vizitând **[stash.ham2k.net](https://stash.ham2k.net)** în orice browser.', ), 
			'operation.export.stash.mayHaveArrived' => 'Niciun răspuns de la stash — fișierul poate să fi ajuns totuși. Verificați stash.ham2k.net înainte de a trimite din nou',
			'operation.export.stash.notSent' => 'netrimis',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Acest fișier nu a ajuns:', other: 'Aceste ${count} fișiere nu au ajuns:', ), 
			'operation.export.stash.emailOffer' => 'Sau, pentru confortul dvs., vă putem trimite un e-mail cu un link direct.',
			'operation.export.stash.emailMe' => 'Trimite-mi un link prin e-mail',
			'operation.export.stash.emailSent' => 'V-am trimis prin e-mail un link de descărcare.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Nu s-a putut trimite e-mailul: ${error}',
			'operation.export.stash.freeTier' => 'Conturile gratuite pot păstra un singur stash o dată. Abonații pot păstra câte doresc.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} fișier trimis la Ham2K File Stash (stash.ham2k.net)', other: '${count} fișiere trimise la Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Niciun spot nu corespunde filtrelor',
			'operation.spots.error' => ({required Object error}) => 'Spoturile nu au putut fi încărcate: ${error}',
			'operation.spots.unknownBand' => 'Altele',
			'operation.spots.auto' => 'Automat',
			'operation.spots.autoValue' => ({required Object value}) => 'Automat (acum ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Oricare',
			'operation.spots.allBands' => 'Toate benzile',
			'operation.spots.allModes' => 'Toate modurile',
			'operation.spots.phoneAndCw' => 'Fonie și CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} spot', other: '${count} spoturi', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Se afișează ${count} din ${total} spoturi',
			'operation.spots.spotsDisabled' => 'Spoturile sunt dezactivate pentru această operațiune',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minute',
			'operation.spots.callsOfNote' => 'Indicative notabile',
			'operation.spots.yourSpots' => 'Spoturile dvs.',
			'operation.spots.allSpots' => 'Toate spoturile',
			'operation.spots.continents.af' => 'Africa',
			'operation.spots.continents.as' => 'Asia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'America de Nord',
			'operation.spots.continents.oc' => 'Oceania',
			'operation.spots.continents.sa' => 'America de Sud',
			'operation.spots.continents.an' => 'Antarctica',
			'operation.spots.filters.title' => 'Filtrare spoturi',
			'operation.spots.filters.band' => 'Bandă',
			'operation.spots.filters.mode' => 'Mod',
			'operation.spots.filters.age' => 'Vechime',
			'operation.spots.filters.sources' => 'Surse',
			'operation.spots.filters.continent' => 'Continent',
			'operation.spots.filters.sorting' => 'Sortare',
			'operation.spots.filters.sortByTime' => 'După ora spotului',
			'operation.spots.filters.sortByFrequency' => 'După frecvență',
			'operation.spots.filters.sortByWanted' => 'Cele mai dorite',
			'operation.spots.filters.groupByBand' => 'Grupare după bandă',
			'operation.spots.filters.groupCallsWithNotes' => 'Grupează indicativele cu notițe',
			'operation.spots.filters.alertingOnly' => 'Doar spoturile cu alerte',
			'operation.spots.filters.sourceNoReply' => 'Fără răspuns',
			'operation.spots.filters.sourceError' => 'Eroare',
			'operation.spots.unavailableTitle' => 'Spoturi indisponibile',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} nu a răspuns.',
			'operation.spots.failedTitle' => 'Eroare la sursa de spoturi',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} a returnat o eroare.',
			'operation.spots.slideLogIt' => 'Înregistrează',
			'operation.spots.slideIgnore' => 'Ignoră',
			'operation.spots.slideRestore' => 'Restaurează',
			'operation.spots.logConflict.title' => 'Panoul de înregistrare este ocupat',
			'operation.spots.logConflict.editingBody' => 'Editați un contact înregistrat. Înregistrați acest spot în schimb sau reveniți și terminați editarea?',
			'operation.spots.logConflict.composingBody' => 'Ați început să introduceți un contact. Înregistrați acest spot în schimb sau reveniți și terminați ce scriați?',
			'operation.spots.logConflict.goBack' => 'Înapoi',
			'operation.spots.logConflict.clearAndLog' => 'Golește și înregistrează spotul',
			'operation.import.title' => 'Importă date în operațiune',
			'operation.import.importAdifAction' => 'Importă QSO-uri din ADIF',
			'operation.import.settingsButton' => 'Setări de ascultare',
			'operation.import.settingsTitle' => 'Ascultare pentru alte aplicații',
			'operation.import.protocolAddressLabel' => 'Adresă',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Introduceți un port între 1 și 65535',
			'operation.import.protocolAddressInvalid' => 'Introduceți o adresă IP validă (de ex. 127.0.0.1 sau 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Se primesc date',
			'operation.import.protocolStatusNoData' => 'Nicio dată primită recent',
			'operation.import.protocolBindError' => ({required Object error}) => 'Ascultarea nu a putut porni: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'QSO-urile primite nu au putut fi salvate și se reîncearcă: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Oricare (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → fila Broadcast Data → bifați "Enable Broadcasts" pentru informațiile de contact. Setați adresa IP la 127.0.0.1 dacă rulează pe același calculator sau 255.255.255.255 pentru broadcast în rețeaua locală curentă.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → fila Reporting → secțiunea UDP Server → bifați "Accept UDP requests". Setați UDP Server la 127.0.0.1 dacă rulează pe același calculator sau la o adresă multicast precum 239.239.0.2 și folosiți aceeași adresă în configurația de mai sus din această aplicație.',
			'operation.import.listenTitle' => 'Ascultă QSO-uri de la alte aplicații',
			'operation.import.listenDescriptionOnN1mm' => 'Se ascultă N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Se ascultă WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Se ascultă N1MM+ și WSJT-X',
			'operation.import.listenDescriptionOff' => 'Oprit',
			'operation.import.addToOperationTitle' => 'Adaugă la această operațiune',
			'operation.import.addToOperationDescriptionOn' => 'QSO-urile capturate sunt adăugate la această operațiune pe măsură ce sosesc',
			'operation.import.addToOperationDescriptionOff' => 'QSO-urile capturate sunt reținute până activați această opțiune',
			'operation.import.pendingSectionTitle' => 'QSO-uri capturate',
			'operation.import.pendingEmpty' => 'Nimic capturat încă',
			'operation.import.stationMismatch' => ({required Object call}) => 'Înregistrat ca ${call}, nu ca stația acestei operațiuni',
			'operation.import.discardAction' => 'Renunță',
			'operation.import.gapDialogTitle' => 'Includeți capturile anterioare?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Încă ${count} QSO-uri au fost capturate mai devreme, înaintea unei întreruperi în date. Le includeți și pe ele?',
			'operation.import.gapDialogRecentOnly' => 'Doar cele recente',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Include toate cele ${count}',
			'map.outlineIssue.link' => 'Probleme?',
			'map.outlineIssue.title' => 'Raportați o problemă de contur',
			'map.outlineIssue.reference' => 'Care contur',
			'map.outlineIssue.severity' => 'Cât de grav este?',
			'map.outlineIssue.minor' => 'Detaliu minor',
			'map.outlineIssue.major' => 'Problemă serioasă',
			'map.outlineIssue.explanation' => 'Ce este greșit?',
			'map.outlineIssue.explanationHint' => 'Ce greșește conturul și unde',
			'map.outlineIssue.send' => 'Trimite',
			'map.outlineIssue.sending' => 'Se trimite raportul — mulțumim',
			'map.outlineIssue.copy' => 'Copiază raportul',
			'map.outlineIssue.notSent' => 'Raportul nu a putut fi trimis',
			'map.outlineIssue.copied' => 'Raport copiat',
			'map.outlineIssue.notCopied' => 'Raportul nu a putut fi copiat',
			'map.outlinesDisclaimer' => 'Contururile sunt doar orientative. Verificați și singuri!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contururi: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Limite: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Facilități: ${sources}',
			'map.fullCredits' => 'Toate sursele datelor',
			'map.fewerCredits' => 'Mai puține surse',
			'map.emptyState' => 'Nicio locație de QSO încă.\nQSO-urile cu grilă, stat sau țară vor apărea aici.',
			'map.unavailable' => 'Harta nu este disponibilă acum.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plană',
			'map.globe' => 'Glob',
			'map.zoomIn' => 'Mărire',
			'map.zoomOut' => 'Micșorare',
			'map.resetNorth' => 'Orientează cu nordul în sus',
			'map.postcard.button' => 'Carte poștală a operațiunii',
			'map.postcard.title' => ({required Object title}) => 'Carte poștală pentru ${title}',
			'map.postcard.portrait' => 'Portret',
			'map.postcard.landscape' => 'Peisaj',
			'map.postcard.square' => 'Pătrat',
			'map.postcard.save' => 'Salvează…',
			'map.postcard.download' => 'Descarcă',
			'map.postcard.share' => 'Partajează',
			'map.postcard.copy' => 'Copiază',
			'map.postcard.copied' => 'Copiat în clipboard',
			'map.postcard.saved' => ({required Object path}) => 'Salvat în ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} descărcat',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} imagini salvate în ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Salvate: ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} fuseseră deja salvate',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Se descarcă ${count} imagini — permiteți-le dacă browserul întreabă',
			'map.postcard.mapLeftOut' => 'Harta nu s-a încărcat, așa că a fost omisă',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — harta nu s-a încărcat, așa că a fost omisă',
			'map.postcard.continued' => ({required Object title}) => '${title} (continuare)',
			'map.postcard.previousPage' => 'Pagina anterioară',
			'map.postcard.nextPage' => 'Pagina următoare',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Pagina ${page} din ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} Q', other: '${count} Q-uri', ), 
			'map.postcard.options' => 'Opțiuni carte poștală',
			'map.postcard.bandLegend' => 'Afișează legenda benzilor',
			'map.postcard.grayline' => 'Afișează linia gri',
			'map.postcard.sectionsAndOrder' => 'Secțiuni de rezumat și ordine',
			'map.postcard.sectionDays' => 'Fiecare zi',
			'map.postcard.reset' => 'Resetează',
			'map.postcard.failed' => ({required Object error}) => 'Cartea poștală nu a putut fi creată: ${error}',
			'map.postcard.mapNotReady' => 'Harta nu s-a încărcat complet. Verificați conexiunea și încercați din nou.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Cartea poștală nu a putut fi salvată: ${error}',
			'map.postcard.copyFailed' => 'Clipboardul nu a acceptat imaginea. Încercați din nou.',
			'map.postcard.shareFailed' => 'Cartea poștală nu a putut fi partajată. Încercați din nou.',
			'map.postcard.fileName' => 'carte-postala',
			'mapsView.title' => 'Hărți',
			'mapsView.searchHint' => 'Căutați parcuri, vârfuri și altele',
			'mapsView.activities' => 'Activități',
			'mapsView.layers' => 'Straturi',
			'mapsView.baseMap' => 'Hartă de bază',
			'mapsView.satellite' => 'Satelit (Esri)',
			'mapsView.facilities' => 'Facilitățile parcurilor',
			'mapsView.boundaries' => 'Limite',
			'mapsView.currentLocation' => 'Locația actuală',
			'mapsView.noMatches' => ({required Object text}) => 'Nimic nu corespunde cu „${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} referință la ${where}', other: '${count} referințe la ${where}', ), 
			'mapsView.startOperation' => 'Porniți o operațiune cu aceste referințe',
			'activitiesView.title' => 'Activități',
			'activitiesView.activitiesCountZero' => 'Nicio activitate selectată',
			'activitiesView.activitiesCountOne' => '1 activitate',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} activități',
			'activitiesView.empty' => 'Nicio activitate încă — folosiți Sugestii și căutare de mai jos pentru a adăuga una',
			'activitiesView.removeActivity' => 'Elimină',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Deschide ${name}',
			'activitiesView.editActivity' => 'Editează activitatea',
			'activitiesView.manageExtensions' => 'Gestionează extensiile',
			'activitiesView.manage' => 'Gestionează',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipuri de activitate: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipuri de activitate: ${first} și ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipuri de activitate: ${first}, ${second} și încă ${more}',
			'activitiesView.reference' => 'Referință',
			'activitiesView.invalidReference' => 'Invalidă',
			'activitiesView.duplicateReference' => 'Deja adăugată',
			'activitiesView.searchHint' => 'Căutați după nume, referință sau orice altceva…',
			'activitiesView.noSuggestions' => 'Nicio potrivire',
			'activitiesView.noSuggestionsHint' => 'Căutați mai sus după numele sau numărul referinței',
			'activitiesView.noSuggestionsExample' => '(de exemplu „trail” sau „4556”)',
			'activitiesView.allOptions' => 'Tipuri de activitate',
			'activitiesView.determiningLocation' => 'Se determină locația curentă…\nSe așteaptă semnalul GPS pentru a găsi referințe din apropiere',
			'activitiesView.locationUnavailableTitle' => 'Datele de locație nu sunt disponibile',
			'activitiesView.locationDeniedTitle' => 'Permisiunea de locație a fost refuzată',
			'activitiesView.locationBlockedTitle' => 'Permisiunea de locație este blocată',
			'activitiesView.noNearbyReason' => 'Nu se pot determina referințele din apropiere',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Atingeți ${icon} pentru a introduce manual locația,\nsau căutați referințe după nume',
			'activitiesView.locationGrantAction' => 'Permite accesul la locație',
			'activitiesView.locationSettingsAction' => 'Deschide Setări',
			'activitiesView.locationSettingsUnavailable' => 'Permiteți accesul la locație din setările sistemului',
			'activitiesView.locationGrantRefused' => 'Tot nicio locație — sistemul a refuzat din nou',
			'activitiesView.searchUnavailableTitle' => 'Căutarea de activități nu este disponibilă',
			'activitiesView.searchUnavailableReason' => 'O extensie de activitate nu a putut răspunde la căutare. Încercați din nou peste un moment.',
			'activitiesView.emptySheet' => 'Folosiți sugestiile și căutarea de mai jos pentru a adăuga una',
			'activitiesView.exports' => 'Exporturi',
			'activitiesView.exportLogs' => 'Exportă jurnalele',
			'activitiesView.tools' => 'Instrumente',
			'activitiesView.toolsTitle' => 'Instrumente operațiune',
			'activitiesView.operationDetails' => 'Detalii operațiune',
			'activitiesView.share' => 'Partajează',
			'activitiesView.archive' => 'Arhivează',
			'activitiesView.deleteOperation' => 'Șterge operațiunea',
			'activitiesView.undeleteOperation' => 'Restaurează operațiunea',
			'activitiesView.alreadySelected' => 'Deja selectată',
			'activitiesView.selected' => 'Selectată',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} din ${count}',
			'activitiesView.previousPick' => 'Potrivirea anterioară',
			'activitiesView.nextPick' => 'Potrivirea următoare',
			'activitiesView.retiredReference' => 'Retrasă',
			'activitiesView.enableExtension' => ({required Object name}) => 'Activează ${name}',
			'activitiesView.enableExtensionHint' => 'Această extensie corespunde căutării, dar nu este activată acum',
			'activitiesView.enableExtensionForRefHint' => 'Această extensie gestionează una dintre referințele acestei operațiuni, dar nu este activată acum',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} nu rulează',
			'activitiesView.extensionNotRunningHint' => 'Această extensie a fost dezactivată, deschideți Setări extensii pentru mai multe informații',
			'activitiesView.installExtension' => ({required Object name}) => 'Instalează ${name}',
			'activitiesView.installExtensionHint' => 'Această extensie corespunde căutării, dar nu este instalată',
			'activitiesView.onlyCatalogMatches' => 'Nicio potrivire\nUnele extensii din catalog ar putea avea rezultate.\nInstalați-le din Tipuri de activitate de mai jos.',
			'activitiesView.setupUnavailable' => 'Configurarea acestei activități nu a putut fi încărcată — încercați din nou din Gestionează',
			'activitiesView.controlsUnavailableTitle' => 'Controalele activității nu sunt disponibile',
			'activitiesView.controlsUnavailableReason' => 'Referințele dvs. sunt în siguranță, dar editarea lor nu este disponibilă acum.',
			'activitiesView.controlsUnavailableRetry' => 'Reîncearcă',
			'activitiesView.onlyDisabledMatches' => 'Nicio potrivire\nUnele extensii disponibile ar putea avea rezultate.\nActivați-le din Tipuri de activitate de mai jos.',
			'activitiesView.onlyNotRunningMatches' => 'Nicio potrivire\nUnele extensii care ar putea avea rezultate nu rulează.\nVedeți Tipuri de activitate de mai jos.',
			'activitiesView.mapToggle' => 'Hartă',
			'activitiesView.searchToggle' => 'Căutare',
			'activitiesView.addToOperation' => 'Adaugă la operațiune',
			'activitiesView.addToOperationShort' => 'Adaugă la op.',
			'activitiesView.mapEmptyState' => 'Niciun rezultat de afișat pe hartă',
			'activitiesView.mapEmptyStateHint' => 'Reveniți la listă sau căutați altceva',
			'activitiesView.imports' => 'Importuri',
			'loggingControls.timeUtc' => 'Ora (UTC)',
			'loggingControls.date' => 'Dată',
			'loggingControls.now' => 'Acum',
			'loggingControls.manualTimeSettings' => 'Oră manuală',
			'loggingControls.manualTimeIncrement' => 'Increment per QSO',
			'loggingControls.manualTimeIncrementNone' => 'Niciunul',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} minut', other: '${count} minute', ), 
			'loggingControls.frequency' => 'Frecvență',
			'loggingControls.mode' => 'Mod',
			'loggingControls.theirCall' => 'Interlocutor',
			'loggingControls.noteField' => 'Notiță',
			'loggingControls.todoField' => 'De făcut',
			'loggingControls.sent' => 'Trimis',
			'loggingControls.rcvd' => 'Primit',
			'loggingControls.more' => 'Mai multe',
			'loggingControls.revert' => 'Anulează',
			'loggingControls.undoDelete' => 'Anulează ștergerea',
			'loggingControls.restore' => 'Restaurează',
			'loggingControls.wipe' => 'Golește',
			'loggingControls.undo' => 'Anulează',
			'loggingControls.pendingDeleteTapWarning' => 'Atingeți coșul încă o dată pentru a șterge acest QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Faceți clic pe coș încă o dată pentru a șterge acest QSO',
			'loggingControls.deletedQsoWarning' => 'QSO șters',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Atingeți coșul încă o dată pentru a șterge acest ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Faceți clic pe coș încă o dată pentru a șterge acest ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} șters',
			'loggingControls.timeControl' => 'Ora',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Putere',
			'loggingControls.notesControl' => 'Notițe',
			'loggingControls.power' => 'Putere',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controale de înregistrare',
			'loggingControls.spottingControl' => 'Spotare',
			'loggingControls.spottingSelfControl' => 'Auto-spotare',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Auto-spotare la ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} la ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Prea târziu pentru a spota ${call}',
			'loggingControls.spotNoFreq' => 'Mai întâi setați o frecvență pentru spotare',
			'loggingControls.selfSpotDisabled' => 'Auto-spotare dezactivată',
			'loggingControls.spotComment' => 'Comentariu',
			'loggingControls.spottingAutoControl' => 'Auto-respotare',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Respotare la fiecare ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Auto în ${time}. Opriți?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto în ${minutes}m',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto în ${seconds}s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto în ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Auto-respotarea nu a pornit: spotul nu a trecut',
			'loggingControls.spotAutoMoved' => 'Auto-respotarea nu a pornit: frecvența s-a schimbat în timpul spotării',
			'loggingControls.spotAutoStopped' => 'Auto-respotarea s-a oprit',
			'loggingControls.spotAutoLeftFreq' => 'Auto-respotarea s-a oprit: frecvența s-a schimbat',
			'loggingControls.spotAutoNoFreq' => 'Auto-respotarea s-a oprit: stația radio nu raportează nicio frecvență',
			'loggingControls.spotBusy' => 'Un alt spot este încă în curs de trimitere',
			'loggingControls.bandOrFreqRequired' => 'Setați o frecvență sau o bandă înainte de înregistrare',
			'loggingControls.missingBand' => 'Fără bandă',
			'loggingControls.missingMode' => 'Fără mod',
			'loggingControls.saveFailed' => ({required Object error}) => 'Nu s-a putut salva: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => 'Nu s-a putut șterge: ${error}',
			'loggingControls.info.noQsos' => 'Niciun QSO încă... hai să operăm!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO-uri',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} în ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} de la ultimul',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h pentru ultimele 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h pentru ultimele 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} până la',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) până la',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) până la',
			'loggingControls.info.distanceAway' => ({required Object distance}) => 'la ${distance} depărtare',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'la ${distance} (${bearing}°) depărtare',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'la ${distance} (${bearing}° / ${reverse}°) depărtare',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplicat!',
			'loggingControls.info.noticeNewBand' => 'Bandă nouă',
			'loggingControls.info.noticeNewMode' => 'Mod nou',
			'loggingControls.info.noticeNewDXCC' => 'DXCC nou',
			'loggingControls.info.noticeNewState' => 'Stat nou',
			'loggingControls.info.noticeNewProvince' => 'Provincie nouă',
			'loggingControls.info.noticeNewDay' => 'Zi nouă',
			'loggingControls.info.noticeNewRef' => 'Ref. nouă',
			'loggingControls.info.noticeNewMult' => 'Mult nou',
			'loggingControls.info.noticeNewZone' => 'Zonă nouă',
			'loggingControls.info.noticeInvalidMode' => 'Mod greșit',
			'loggingControls.info.noticeInvalidBand' => 'Bandă greșită',
			'loggingControls.info.noticeInvalidCategory' => 'Nu se poate lucra',
			'loggingControls.info.noticeOverTime' => 'Timp expirat',
			'loggingControls.info.noticeWorkedBefore' => 'Lucrat anterior',
			'loggingControls.info.noticeNewPark' => 'Parc nou',
			'loggingControls.info.noticeNewSection' => 'Secțiune nouă',
			'loggingControls.info.noticeBonusStation' => 'Stație bonus!',
			'loggingControls.info.noticeMissingExchange' => 'Fără schimb',
			'loggingControls.info.noticeInvalidExchange' => 'Schimb greșit',
			'loggingControls.info.noticeUnknownEvent' => 'Eveniment necunoscut',
			'loggingControls.info.noticeIncompleteCall' => 'Indicativ incomplet — nepunctat',
			'loggingControls.info.noticeOurGrid' => 'Setați grila noastră',
			'loggingControls.info.noticeRareCounty' => 'Județ rar!',
			'loggingControls.info.noticeOurLocation' => 'Setați județul nostru',
			'loggingControls.info.noticeShortGrid' => 'Grila e prea scurtă',
			'formChrome.untitled' => '(fără titlu)',
			'formChrome.showMore' => 'Arată mai multe',
			'formChrome.showAll' => 'Afișează tot',
			'formChrome.showFewer' => 'Arată mai puține',
			'formChrome.defaults' => 'Setări implicite',
			'formChrome.search' => 'Căutare',
			'formChrome.clear' => 'Golește',
			'formChrome.openPage' => 'Deschide pagina',
			'formChrome.connected' => 'Conectat',
			'formChrome.notConnected' => 'Neconectat',
			'formChrome.manage' => 'Gestionează',
			'formChrome.connect' => 'Conectează',
			'formChrome.formTitle' => 'Formular',
			'formChrome.addItem' => ({required Object label}) => 'Adaugă ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Editează ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Se afișează ${shown} din ${total} (${selected} selectate)',
			'formChrome.validationError' => ({required Object error}) => 'Eroare de validare: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Eroare de transformare: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Eroare: ${error}',
			'formChrome.removeItem' => 'Șterge',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'Ștergeți ${name}?',
			'formChrome.storageUnavailable' => 'Autentificări indisponibile',
			'qsoEditForm.title' => 'Editează QSO',
			'qsoEditForm.operatorCall' => 'Operator',
			'qsoEditForm.position' => 'Poziție',
			'qsoEditForm.theirName' => 'Nume',
			'qsoEditForm.theirGrid' => 'Grilă',
			'qsoEditForm.theirState' => 'Stat',
			'qsoEditForm.band' => 'Bandă',
			'qsoEditForm.notes' => 'Notițe',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Informațiile interlocutorului',
			'qsoEditForm.sectionOur' => 'Informațiile noastre',
			'qsoEditForm.sectionNotes' => 'Notițe',
			'qsoEditForm.theirCity' => 'Oraș',
			'qsoEditForm.theirCounty' => 'Județ',
			'qsoEditForm.theirEntity' => 'Entitate',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Secțiune ARRL',
			'qsoEditForm.theirLat' => 'Latitudine',
			'qsoEditForm.theirLon' => 'Longitudine',
			'qsoEditForm.theirPower' => 'Puterea lor',
			'qsoList.empty' => 'Niciun QSO încă — lucrați pe cineva!',
			'qsoList.bandOrModeWarning' => 'Verificați dacă banda și modul sunt corecte',
			'qsoList.today' => 'Astăzi',
			'qsoList.yesterday' => 'Ieri',
			'qsoList.tomorrow' => 'Mâine',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Caută în jurnal (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Caută în jurnal',
			'qsoList.find.hint' => 'Număr QSO sau indicativ',
			'qsoList.find.noMatches' => 'Nicio potrivire',
			'qsoList.find.noOperationQsos' => 'Niciun QSO în această operațiune',
			'qsoList.find.noPeriodQsos' => 'Niciun QSO în această perioadă',
			'qsoList.find.outsideQsosOne' => '1 QSO în afara acestei operațiuni',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSO-uri în afara acestei operațiuni',
			'qsoList.find.pastQsosOne' => '1 QSO anterior',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} QSO-uri anterioare',
			'loggingPanel.stats' => 'Statistici operațiune',
			'loggingPanel.scoring' => 'Punctaj',
			'loggingPanel.dxccEntities' => 'Entități DXCC',
			'loggingPanel.statesWorked' => 'State',
			'loggingPanel.provincesWorked' => 'Provincii',
			'loggingPanel.duplicates' => 'Duplicate',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Arată imaginea',
			'callInfo.imageUnavailable' => 'Fotografie indisponibilă',
			'callInfo.photo' => 'Fotografie',
			'callInfo.notes' => 'Notițe',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} până la',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) până la',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) până la',
			'callInfo.distanceAway' => ({required Object distance}) => 'la ${distance} depărtare',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => 'la ${distance} (${bearing}°) depărtare',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => 'la ${distance} (${bearing}° / ${reverse}°) depărtare',
			'callInfo.thisOpCountOne' => '1 QSO în această operațiune',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSO-uri în această operațiune',
			'callInfo.otherOpsCountOne' => '1 QSO în alte operațiuni',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSO-uri în alte operațiuni',
			'callInfo.andMore' => ({required Object count}) => '… și încă ${count}',
			'callInfo.withCall' => ({required Object call}) => 'cu ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'din ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} în ultimele 7 zile',
			'callInfo.history.today' => ({required Object n}) => '${n} astăzi',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${n} QSO', other: '${n} QSO-uri', ), 
			'settings.title' => 'Setări',
			'settings.language' => 'Limbă',
			'settings.languageSystem' => ({required Object language}) => 'Urmează setările sistemului (${language})',
			'settings.theme.title' => 'Temă',
			'settings.theme.system' => 'Urmează setările sistemului',
			'settings.theme.light' => 'Luminos',
			'settings.theme.dark' => 'Întunecat',
			'settings.themeDescription.system' => 'Se urmează setările sistemului',
			'settings.themeDescription.light' => 'Întotdeauna în modul luminos',
			'settings.themeDescription.dark' => 'Întotdeauna în modul întunecat',
			'settings.fontScale' => 'Scară fonturi',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Cele mai mici--',
			'settings.fontScaleOpts.smallestMinus' => 'Cele mai mici-',
			'settings.fontScaleOpts.smallest' => 'Cele mai mici',
			'settings.fontScaleOpts.smaller' => 'Mai mici',
			'settings.fontScaleOpts.normal' => 'Normale',
			'settings.fontScaleOpts.larger' => 'Mai mari',
			'settings.fontScaleOpts.largest' => 'Cele mai mari',
			'settings.fontScaleOpts.largestPlus' => 'Cele mai mari+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Cele mai mari++',
			'settings.keepDeviceAwake.title' => 'Păstrează dispozitivul treaz',
			'settings.keepDeviceAwake.descriptionOn' => 'Rămâne treaz cât timp sunteți în vizualizarea de înregistrare sau o sincronizare este în curs',
			'settings.keepDeviceAwake.descriptionOff' => 'Intră în repaus ca de obicei',
			'settings.layoutDensity' => 'Densitatea aranjamentului',
			'settings.layoutDensityOpts.auto' => 'Automat',
			'settings.layoutDensityOpts.densest' => 'Cel mai dens',
			'settings.layoutDensityOpts.dense' => 'Dens',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Aerisit',
			'settings.layoutDensityOpts.sparsest' => 'Cel mai aerisit',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'fereastra este prea scundă, se folosește ${effective}',
			'settings.layoutDensityAtLimit' => 'la limită',
			'settings.distanceUnits' => 'Unități de distanță',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometri',
			'settings.distanceUnitsOpts.miles' => 'Mile',
			'settings.userInterface' => 'Interfață',
			'settings.logging.title' => 'Înregistrare',
			'settings.logging.leftieMode.title' => 'Mod pentru stângaci',
			'settings.logging.leftieMode.descriptionOn' => 'Se folosește aspectul pentru stângaci',
			'settings.logging.leftieMode.descriptionOff' => 'Se folosește aspectul pentru dreptaci',
			'settings.logging.countryFlags.title' => 'Steaguri țări',
			'settings.logging.countryFlags.dx' => 'Doar pentru contactele DX',
			'settings.logging.countryFlags.all' => 'Steaguri pentru toate contactele',
			'settings.logging.countryFlags.none' => 'Fără steaguri',
			'settings.logging.countryFlagsDescription.dx' => 'Se afișează steaguri doar pentru contactele DX',
			'settings.logging.countryFlagsDescription.all' => 'Se afișează steaguri pentru toate contactele',
			'settings.logging.countryFlagsDescription.none' => 'Nu se afișează niciun steag',
			'settings.logging.suggestDefaultOperator.title' => 'Sugerează operatorul',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Se oferă indicativul dvs. ca operator când o operațiune folosește un alt indicativ de stație',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Operatorul rămâne gol dacă nu îl completați',
			'settings.logging.showBearing.title' => 'Afișează azimutul',
			'settings.logging.showBearing.descriptionOn' => 'Se afișează azimutul estimat către stație',
			'settings.logging.showBearing.descriptionOff' => 'Nu se afișează informații despre azimut',
			'settings.logging.showReverseBearing.title' => 'Afișează și azimutul invers',
			'settings.logging.showReverseBearing.descriptionOn' => 'Se afișează și azimutul de la stație, ca „45° / 225°”',
			'settings.logging.showReverseBearing.descriptionOff' => 'Se afișează doar azimutul către stație',
			'settings.logging.switchSentRcvd.title' => 'Schimbă ordinea rapoartelor de semnal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Întâi Trimis, apoi Primit',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Întâi Primit, apoi Trimis',
			'settings.logging.jumpAfterRST.title' => 'Treci la câmpul următor după RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Se trece mai departe după introducerea RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Nu se trece automat',
			'settings.logging.defaultReport.title' => 'Raport implicit — Fonie',
			'settings.logging.defaultReport.description' => 'Folosit când Trimis sau Primit rămâne gol în SSB, FM sau AM',
			'settings.logging.defaultReportCW.title' => 'Raport implicit — CW și date',
			'settings.logging.defaultReportCW.description' => 'Folosit când Trimis sau Primit rămâne gol în CW, RTTY și alte moduri digitale',
			'settings.logging.defaultReportFT8.title' => 'Raport implicit — FT8 și FT4',
			'settings.logging.defaultReportFT8.description' => 'Folosit când Trimis sau Primit rămâne gol în modurile FT',
			'settings.logging.numbersRow.title' => 'Rând de numere',
			'settings.logging.numbersRow.description' => 'Afișează un rând de taste numerice deasupra tastaturii în timpul înregistrării',
			'settings.logging.numbersRowExtra.title' => 'Tastă bară oblică și punct',
			'settings.logging.numbersRowExtra.description' => 'Adaugă o tastă contextuală: „/” pentru indicative, „.” pentru numere',
			'settings.logging.numbersRowVibrate.title' => 'Vibrează la apăsarea tastelor',
			'settings.logging.numbersRowVibrate.description' => 'Răspuns haptic când atingeți o tastă numerică',
			'settings.logging.bands' => 'Benzi preferate',
			'settings.logging.modes' => 'Moduri preferate',
			'settings.catServer.title' => 'Server CAT',
			'settings.catServer.description' => 'Permite altor aplicații (WSJT-X, programe de log etc.) să controleze stația radio prin Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocol',
			'settings.catServer.protocolOpts.off' => 'Dezactivat',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Acces deschis',
			'settings.catServer.openAccessOn' => 'Orice calculator din rețeaua locală se poate conecta.',
			'settings.catServer.openAccessOff' => 'Doar aplicațiile de pe acest calculator se pot conecta.',
			'settings.catServer.allowTransmit' => 'Permite aplicațiilor să emită',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'Aplicațiile pot comanda PTT-ul stației radio, cel mult ${minutes} minute odată.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'Aplicațiile de pe orice calculator din rețeaua locală pot comanda PTT-ul stației radio, cel mult ${minutes} minute odată.',
			'settings.catServer.allowTransmitOff' => 'Aplicațiile nu pot comanda emisia stației radio. Folosiți VOX sau propria lor configurație PTT.',
			'settings.catServer.allowTransmitUnsupported' => 'Stația radio de pe VFO principal nu poate fi trecută pe emisie din Ham2K Logger, deci aplicațiile nu pot emite prin ea.',
			'settings.catServer.off' => 'Oprit.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, pornește…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} pe portul ${port}. Clienți conectați: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} pe portul ${port}, dar nicio stație radio nu este conectată ca VFO principal.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} nu poate asculta pe portul ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} nu poate asculta pe portul ${port}: un alt program îl folosește, adesea chiar ${protocol}. Închideți acel program sau alegeți alt port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} nu poate asculta pe portul ${port}: acest calculator nu permite. Alegeți un port peste 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} a oprit ascultarea pe portul ${port}. Se reîncearcă…',
			'settings.cluster.title' => 'Cluster DX',
			'settings.cluster.description' => 'Serverul la care extensiile postează spoturi și de la care le citesc, autentificate ca operator.',
			'settings.cluster.connect' => 'Conectare la cluster',
			'settings.cluster.connectOn' => 'Extensiile se conectează la cluster când au nevoie',
			'settings.cluster.connectOff' => 'Nimic nu se conectează la cluster',
			'settings.cluster.console' => 'Afișează consola',
			'settings.cluster.consoleDescription' => 'Ce trimite clusterul și un loc unde puteți tasta comenzi',
			'settings.cluster.consoleTitle' => 'Consolă cluster',
			'settings.cluster.consoleConnect' => 'Conectează',
			'settings.cluster.consoleDisconnect' => 'Deconectează',
			'settings.cluster.consoleCommand' => 'Comandă',
			'settings.cluster.consoleEmpty' => 'Nimic încă. Conectați-vă sau așteptați ca o extensie să folosească clusterul.',
			'settings.cluster.consoleRetry' => ({required Object command}) => 'Se trimite din nou: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => 'Netrimis: ${command} (${reason})',
			'settings.cluster.server' => 'Server cluster',
			'settings.cluster.selectServer' => 'Selectează serverul',
			'settings.cluster.serverOther' => 'Altul',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'Niciun server introdus încă, așa că spoturile merg la ${node}',
			'settings.cluster.customHost' => 'Server',
			'settings.cluster.customPort' => 'Port',
			'settings.cluster.password' => 'Parolă',
			'settings.cluster.passwordDescription' => 'Doar dacă este necesară',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Parolă salvată pentru ${node}',
			'settings.cluster.scrollback' => 'Linii păstrate',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} linii',
			'settings.cluster.connection' => 'Conexiune',
			'settings.cluster.statusIdle' => 'Neconectat. Se conectează când o extensie are nevoie. Atingeți pentru a testa.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Se conectează la ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Conectat la ${node} ca ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'Nu s-a putut conecta la ${node}: ${reason}',
			'settings.cluster.statusUnsupported' => 'Nu este disponibil în versiunea web.',
			'settings.cluster.statusOff' => 'Oprit. Activați „Conectare la cluster” pentru a-l folosi.',
			'settings.cluster.errors.noCall' => 'niciun indicativ de operator cu care să se autentifice',
			'settings.cluster.errors.connectFailed' => 'nodul nu a putut fi accesat',
			'settings.cluster.errors.needsPassword' => 'nodul cere o parolă și niciuna nu este salvată',
			'settings.cluster.errors.loginFailed' => 'nodul nu a acceptat autentificarea',
			'settings.cluster.errors.disconnected' => 'nodul a închis conexiunea',
			'settings.cluster.errors.timeout' => 'nodul nu a răspuns',
			'settings.cluster.errors.off' => '„Conectare la cluster” este oprită',
			'settings.spotting.title' => 'Spotare',
			'settings.spotting.respotInterval' => 'Auto-respotare la fiecare',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Auto-respotare implicită',
			'settings.spotting.autoRespotByDefaultOn' => 'Activează auto-respotarea după orice spot postat',
			'settings.spotting.autoRespotByDefaultOff' => 'Auto-respotarea se activează doar la cererea dvs.',
			'settings.spotting.pulseBeforeRespot' => 'Pulsează înaintea fiecărei auto-respotări',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'Controlul Spotare pulsează albastru în cele ${seconds} secunde dinaintea fiecărei respotări',
			'settings.spotting.pulseBeforeRespotOff' => 'Fără pulsare înaintea unei auto-respotări',
			'settings.radio.title' => 'Control CAT',
			'settings.radio.loggingAndCat' => 'Înregistrare și CAT',
			'settings.radio.tuningSection' => 'Acord',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Servicii',
			'settings.radio.stationConfigurationSection' => 'Configurația stației',
			'settings.radio.moreSettings' => 'Mai multe setări de configurare a stației',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controlează PTT de la tastatură',
			'settings.radio.pttKey.modes.off' => 'Nu',
			'settings.radio.pttKey.modes.toggle' => 'Comutare',
			'settings.radio.pttKey.modes.hold' => 'Menținere',
			'settings.radio.pttKey.descriptions.off' => 'Tastatura nu comandă emisia stației radio.',
			'settings.radio.pttKey.descriptions.toggle' => 'În modurile de fonie, tasta PTT trece stația pe emisie, iar o nouă apăsare o readuce pe recepție. Revine singură pe recepție după un minut.',
			'settings.radio.pttKey.descriptions.hold' => 'În modurile de fonie, stația emite cât timp tasta PTT este ținută apăsată, cel mult un minut.',
			'settings.radio.pttKey.key' => 'Tastă PTT',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Emisie',
			'settings.radio.smartVfoSnap.title' => 'Rotunjire inteligentă VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'După ce opriți rotirea butonului, frecvența se rotunjește la un pas rezonabil. Doar în modurile de fonie.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Rămâne exact unde ați acordat.',
			'settings.radio.snapDebounce.title' => 'Rotunjire inteligentă: întârziere de stabilizare',
			'settings.radio.snapDebounce.description' => 'Cât timp trebuie să stea butonul nemișcat înainte de rotunjirea frecvenței. Mai scurt pare imediat; mai lung lasă loc unei mișcări lente.',
			'settings.radio.snapLongMove.title' => 'Rotunjire inteligentă: mișcare lungă',
			'settings.radio.snapLongMove.description' => 'La o mișcare de cel puțin atât, frecvența se rotunjește la un kHz întreg, oricât de încet ați terminat.',
			'settings.radio.snapMinMove.title' => 'Rotunjire inteligentă: cea mai mică mișcare',
			'settings.radio.snapMinMove.description' => 'La o mișcare mai mică decât atât, frecvența nu se rotunjește, astfel acordul fin rămâne neatins.',
			'settings.radio.snapMinSpeed.title' => 'Rotunjire inteligentă: cea mai lentă mișcare',
			'settings.radio.snapMinSpeed.description' => 'Dacă rotiți butonul mai încet decât atât, frecvența nu se rotunjește, cu excepția unei mișcări lungi.',
			'settings.radio.enterSends.pillOff' => 'ESM oprit',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter trimite mesaje',
			'settings.radio.enterSends.off' => 'Oprit',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter trimite mesaje: ${state}. Atingeți pentru a schimba.',
			'settings.radio.keyerSpeed.title' => 'Viteza keyer-ului',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Mesaje keyer CW',
			'settings.radio.cwMessages.notSupported' => 'Stația radio curentă nu acceptă manipulare CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Mesaj ${n}',
			'settings.radio.cwMessages.labelField' => 'Etichetă',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Eticheta F${n}',
			'settings.radio.cwMessages.details' => 'Detalii',
			'settings.radio.cwMessages.empty' => '(gol)',
			'settings.radio.cwMessages.sets' => 'Set de mesaje',
			'settings.radio.cwMessages.newSet' => 'Set nou',
			'settings.radio.cwMessages.renameSet' => 'Redenumește setul',
			'settings.radio.cwMessages.deleteSet' => 'Șterge setul',
			'settings.radio.cwMessages.newSetName' => 'Nume',
			'settings.radio.cwMessages.setDefault' => 'Implicit',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Mesaje ESM',
			'settings.radio.cwMessages.setSaved' => 'Mesajele mele',
			'settings.radio.cwMessages.repeat' => 'Repetă mesajul 1',
			'settings.radio.cwMessages.repeatShort' => 'Repetă M1',
			'settings.radio.cwMessages.cooldown' => 'Pauză înainte de repetare',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n} secunde',
			'settings.radio.cwMessages.repeatWait' => 'Se repetă',
			'settings.radio.cwMessages.keyboard' => 'Tastați pentru a trimite',
			'settings.radio.cwMessages.keyboardField' => 'Tastați pentru a trimite',
			'settings.radio.cwMessages.help' => 'Ajutor',
			'settings.radio.cwMessages.helpTitle' => 'Scrierea mesajelor CW',
			'settings.radio.cwMessages.helpIntro' => 'Mesajele pot folosi șabloane cu următoarele valori:',
			'settings.radio.cwMessages.helpOpCall' => 'Indicativul dvs.',
			'settings.radio.cwMessages.helpQsoCall' => 'Indicativul lor — într-o stivă //, indicativul care va fi înregistrat',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Indicativul lor, dacă este un indicativ valid; gol pentru unul parțial',
			'settings.radio.cwMessages.helpQsoPartial' => 'Un indicativ parțial; gol dacă există un indicativ complet valid',
			'settings.radio.cwMessages.helpQsoNextCall' => 'Într-o stivă //, indicativul care va fi selectat următorul pentru înregistrare, dacă este un indicativ complet valid',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'Într-o stivă //, următorul parțial după înregistrarea contactului curent',
			'settings.radio.cwMessages.helpQsoName' => 'Prenumele lor, așa cum a fost tastat sau, altfel, din căutare',
			'settings.radio.cwMessages.helpQsoState' => 'Statul lor, așa cum a fost tastat sau, altfel, din căutare',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Mesajul 1 așa cum ar fi trimis, în interiorul altui mesaj. Valabil pentru mesajele 1 până la 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Raportul pe care îl trimiteți',
			'settings.radio.cwMessages.helpQsoSerial' => 'Numărul dvs. de serie, într-un concurs care trimite unul',
			'settings.radio.cwMessages.helpPad' => 'Completează cu zerouri până la atâtea cifre: 7 se trimite ca 007',
			'settings.radio.cwMessages.helpCut' => 'Cifre prescurtate, T pentru 0 și N pentru 9: 599 se trimite ca 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Alege cifrele de prescurtat, între ghilimele — 0 este T, 1 este A, 5 este E, 9 este N',
			'settings.radio.cwMessages.helpFullExample' => 'Exemplu complet:',
			'settings.radio.cwMessages.helpExample' => 'Trimite W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Cu Enter trimite mesaje activat, Enter transmite mesajele după tasta lor funcțională, ca în N1MM. Setul Mesaje ESM începe cu acestea:',
			'settings.radio.cwMessages.helpEsmCq' => 'În Run, Enter cu câmpul de indicativ gol cheamă CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Schimbul dvs.: după indicativul lor în Run, după ce vă răspund în S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Mulțumiri, după înregistrarea contactului: qso este contactul așa cum a fost înregistrat, next cel care urmează',
			'settings.radio.cwMessages.helpEsmMyCall' => 'În S&P, indicativul dvs. către stația căreia îi răspundeți',
			'settings.radio.cwMessages.helpEsmHisCall' => 'În Run, indicativul lor înaintea schimbului dvs.',
			'settings.radio.cwMessages.helpEsmAgain' => 'Cere din nou când nimic din schimbul lor nu a fost recepționat',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 sugerat pentru stive //: mulțumește, apoi cheamă următoarea stație din stivă și trimite schimbul dvs. sau cere înapoi un parțial (TU KR?); dacă nu mai rămâne nimic, doar TU',
			'settings.radio.keyerControl.label' => 'Keyer',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => 'Voce',
			'settings.radio.voiceMessages.title' => 'Mesaje keyer fonie',
			'settings.radio.voiceMessages.notSupported' => 'Stația radio curentă nu acceptă mesaje de fonie',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memorie vocală ${n}',
			'settings.radio.voiceMessages.labelField' => 'Etichetă',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Eticheta memoriei vocale ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Goală',
			'settings.radio.voiceMessages.notMeasured' => 'Durată necunoscută',
			'settings.radio.voiceMessages.playButton' => 'Redă',
			'settings.radio.voiceMessages.recordButton' => 'Înregistrează',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Repetă mesajul 1',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Note ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Aceste memorii se află în stația radio a dispozitivului ${device}. Numele și duratele lor aparțin acelui dispozitiv.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Salvat în stația radio, unde îl văd și ceilalți clienți ai ei.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Așteptați indicatorul [REC] pe stația radio, apoi țineți apăsat butonul PTT și înregistrați mesajul. Încheiați-l apăsând butonul STOP aici în aplicație înainte de a elibera PTT, pentru a evita clicurile nedorite.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Așteptați ca indicatorul [REC] să clipească de cel puțin patru ori, apoi țineți apăsat butonul PTT și înregistrați mesajul. Încheiați-l apăsând butonul STOP aici în aplicație înainte de a elibera PTT, pentru a evita clicurile nedorite.',
			'settings.radio.voiceMessages.pill' => 'Voce',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Redă memoria ${n}',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Înregistrează memoria ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Oprește înregistrarea',
			'settings.radio.voiceMessages.playing' => 'Se redă…',
			'settings.radio.voiceMessages.recording' => 'Se înregistrează…',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Se înregistrează ${label}',
			'settings.radio.voiceMessages.doubtful' => 'A redat-o stația radio? A raportat imediat că este inactivă.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Memoriile trebuie înregistrate direct pe stația radio.',
			'settings.radio.voiceMessages.sets' => 'Set de mesaje',
			'settings.radio.voiceMessages.soundFilesSet' => 'Fișiere audio de pe acest calculator',
			'settings.radio.voiceMessages.openFileButton' => 'Deschide fișier',
			'settings.radio.voiceMessages.newSet' => 'Set nou',
			'settings.radio.voiceMessages.renameSet' => 'Redenumește setul',
			'settings.radio.voiceMessages.deleteSet' => 'Șterge setul',
			'settings.radio.voiceMessages.newSetName' => 'Nume',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => 'Ștergeți ${name} și înregistrările lui? Acțiunea nu poate fi anulată.',
			'settings.radio.voiceMessages.output' => 'Trimite audio către',
			'settings.radio.voiceMessages.input' => 'Înregistrează de la',
			'settings.radio.voiceMessages.outputRadio' => 'Trimite către stația radio prin rețea',
			'settings.radio.voiceMessages.inputDefault' => 'Implicit sistem',
			'settings.radio.voiceMessages.pickDevice' => 'Alegeți un dispozitiv audio',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (neconectat)',
			'settings.radio.voiceMessages.lead' => 'Întârziere la trecerea pe emisie',
			'settings.radio.voiceMessages.tail' => 'Întârziere la revenirea pe recepție',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => 'Ascultă',
			'settings.radio.voiceMessages.notRecorded' => 'Neînregistrat',
			'settings.radio.voiceMessages.unplayable' => 'Fișierul nu poate fi redat',
			'settings.radio.voiceMessages.problemNoOutput' => 'Alegeți dispozitivul audio care alimentează stația radio înainte de a reda un mesaj.',
			'settings.radio.voiceMessages.problemOutputMissing' => 'Dispozitivul audio care alimentează stația radio nu este conectat.',
			'settings.radio.voiceMessages.problemInputMissing' => 'Dispozitivul de înregistrare nu este conectat.',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'Dispozitivul audio nu a putut fi deschis.',
			'settings.radio.voiceMessages.problemNotRecorded' => 'Acel mesaj nu are încă nicio înregistrare.',
			'settings.radio.voiceMessages.problemRecordingSilent' => 'Nu s-a auzit nimic de la dispozitivul de înregistrare, așa că mesajul a rămas neschimbat. Verificați intrarea și dacă aplicația are permisiunea de a folosi microfonul.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => 'Stația radio nu preia acum audio de la aplicație. Este nevoie de o conexiune prin rețea la stație.',
			'settings.radio.voiceMessages.problemSourceRefused' => 'Stația radio nu a vrut să comute audio-ul de emisie pe aplicație, așa că mesajul s-a oprit. Setați stația să emită audio-ul aplicației.',
			'settings.radio.voiceMessages.problemCannotKey' => 'Această stație radio nu poate fi trecută pe emisie prin CAT, deci calculatorul nu poate reda mesaje în ea.',
			'settings.radio.voiceMessages.problemUnplayable' => 'Fișierul acelui mesaj nu este un fișier audio pe care aplicația îl poate reda. Folosiți un fișier WAV, FLAC sau MP3, sau înregistrați-l din nou.',
			'settings.radio.voiceMessages.problemRecordingFailed' => 'Înregistrarea s-a întrerupt, așa că mesajul a rămas neschimbat. Verificați dacă dispozitivul de înregistrare este încă conectat și dacă există spațiu pe disc.',
			'settings.radio.voiceMessages.problemFileFailed' => 'Înregistrarea nu a putut fi salvată în locul mesajului, așa că mesajul a rămas neschimbat.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'Acel mesaj are nevoie de cuvinte pe care nu le-ați înregistrat: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'Șablonul acelui mesaj are o problemă: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => 'Mesajele spuse cu cuvintele dvs. se redau într-o operațiune, unde există un contact pentru care să fie spuse.',
			'settings.radio.voiceMessages.problemNothingSaid' => 'Acel mesaj nu spune nimic pentru acest contact.',
			'settings.radio.voiceMessages.templateField' => 'Spune cu cuvintele mele',
			'settings.radio.voiceMessages.templateHelp' => 'Lăsați gol pentru a reda înregistrarea. Altfel, mesajul este spus cu cuvintele înregistrate de dvs., completate pentru fiecare contact, folosind aceste valori:',
			'settings.radio.voiceMessages.help' => 'Ajutor',
			'settings.radio.voiceMessages.helpTitle' => 'Mesaje spuse cu cuvintele dvs.',
			'settings.radio.voiceMessages.helpFullExample' => 'Un mesaj întreg:',
			'settings.radio.voiceMessages.helpExample' => 'Indicativul lor, raportul lor și înregistrarea dvs. cu „QSL?”',
			'settings.radio.voiceMessages.playOnRadio' => 'Redă pe stația radio',
			'settings.radio.voiceMessages.templateHelpCall' => 'Indicativul lor',
			'settings.radio.voiceMessages.templateHelpReport' => 'Raportul pe care li-l dați',
			'settings.radio.voiceMessages.templateHelpMessage' => 'Înregistrarea mesajului 2, redată ca atare',
			'settings.radio.voiceMessages.voiced' => 'Spus cu cuvintele dvs.',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => 'Spune: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => 'Neînregistrate încă: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => 'Deschideți o operațiune pentru a vedea ce va spune.',
			'settings.radio.voiceMessages.wordsDescription' => 'Folosiți propria voce pentru indicative, numere și altele.',
			'settings.radio.voiceWords.title' => 'Înregistrări de cuvinte',
			'settings.radio.voiceWords.callField' => 'Cuvintele operatorului',
			'settings.radio.voiceWords.intro' => 'Înregistrați fiecare cuvânt sau număr de trei ori, legat și repede, așa cum l-ați spune într-un indicativ. Frazele mai lungi se înregistrează o singură dată.',
			'settings.radio.voiceWords.recordAll' => 'Înregistrează tot',
			'settings.radio.voiceWords.recordAllGuide' => 'Citiți fiecare cuvânt de trei ori, legat, iar o frază de mai multe cuvinte o singură dată, cu o respirație între rânduri. Apăsați Stop după ultimul.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => 'Spuneți „${word} ${word} ${word}”, apoi apăsați Stop.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => 'Spuneți „${words}”, apoi apăsați Stop.',
			'settings.radio.voiceWords.recorded' => 'Înregistrat',
			'settings.radio.voiceWords.notRecorded' => 'Neînregistrat',
			'settings.radio.voiceWords.addPhrase' => 'Adaugă frază',
			'settings.radio.voiceWords.phraseField' => 'Fraza, așa cum o scrieți într-un mesaj',
			'settings.radio.voiceWords.deletePhrase' => 'Șterge fraza',
			'settings.radio.voiceWords.tryField' => 'Încercați să spuneți',
			'settings.radio.voiceWords.pauseLetters' => 'Pauză între litere',
			'settings.radio.voiceWords.pauseWords' => 'Pauză între cuvinte',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => 'Viteză',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => 'Setări avansate',
			'settings.radio.voiceWords.splitSilent' => 'Nu s-a auzit nimic în înregistrare.',
			'settings.radio.voiceWords.splitNotThreeTakes' => 'Nu s-au găsit trei repetări. Spuneți cuvântul de trei ori, legat, și încercați din nou.',
			'settings.radio.voiceWords.splitLineCount' => 'Nu s-au găsit toate cuvintele în citire. Citiți fiecare cuvânt de trei ori, cu o respirație între cuvinte.',
			'settings.radio.voiceWords.splitLinesTooClose' => 'Cuvintele nu au putut fi deosebite. Lăsați o respirație mai lungă între cuvinte.',
			'settings.radio.avoidZeroBeat.title' => 'Evită bătăile zero pe spoturi',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Cu o stație radio conectată, acordul se face la câțiva Hz de un spot CW, ca nu toți cei care îi răspund să cheme pe aceeași notă.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Acordul se face exact pe frecvența spotului.',
			'settings.radio.zeroBeatRange.title' => 'Bătăi zero: interval de evitare',
			'settings.radio.zeroBeatRange.description' => 'Cât de departe de frecvența spotului, de o parte sau de alta. Decalajul nu este niciodată aproape de zero — ar fi din nou bătăi zero.',
			'settings.help.title' => 'Ajutor și resurse',
			'settings.help.description' => 'Comunitate și suport',
			'settings.help.forums' => 'Forumurile Ham2K',
			'settings.help.forumsDescription' => 'Găsiți ajutor, oferiți feedback, discutați idei…',
			'settings.help.chat' => 'Chat Ham2K',
			'settings.help.chatDescription' => 'Serverul Discord al comunității noastre online',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videoclipuri și transmisiuni live',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Pentru că nu puteți avea niciodată prea multe fotografii…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Urmăriți-ne pentru noutăți și actualizări',
			'settings.help.contact' => 'Contactați-ne',
			'settings.help.contactDescription' => 'help@ham2k.com — dar încercați mai întâi Forumurile sau Chat-ul!',
			'settings.exports.title' => 'Exporturi',
			'settings.extensionSections.activities' => 'Activități',
			'settings.extensionSections.hunting' => 'Vânătoare',
			'settings.extensionSections.contests' => 'Concursuri',
			'settings.extensionSections.lookups' => 'Căutări',
			'settings.extensionSections.dashboard' => 'Panou de bord',
			'settings.map.title' => 'Hărți',
			'settings.map.style.title' => 'Stilul hărții',
			'settings.map.showCallsigns.title' => 'Afișează indicativele',
			'settings.map.showCallsigns.description' => 'Fiecare contact este o etichetă cu indicativul lui, în culoarea benzii',
			'settings.map.showGrayline.title' => 'Afișează linia gri',
			'settings.map.showGrayline.description' => 'Umbrește partea de noapte a Pământului, cu crepusculul ca gradient',
			'settings.map.styleOpts.automatic' => 'Automat',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Confidențialitate',
			'settings.privacy.shareAppData.title' => 'Partajează datele de utilizare a aplicației',
			'settings.privacy.shareAppData.descriptionOn' => 'Ne ajutați să îmbunătățim aplicația partajând date despre utilizare, configurare, blocări și performanță',
			'settings.privacy.shareAppData.descriptionOff' => 'Datele de utilizare ale aplicației rămân private.\nEchipa Ham2K nu va putea detecta blocări sau alte probleme.',
			'settings.privacy.shareOpData.title' => 'Partajează datele operațiunilor',
			'settings.privacy.shareOpData.descriptionOn' => 'Se partajează public și cu alți utilizatori unele date despre operațiuni',
			'settings.privacy.shareOpData.descriptionOff' => 'Datele despre operațiuni rămân private',
			'settings.privacy.privacyPolicy' => 'Politica de confidențialitate',
			'settings.privacy.termsOfService' => 'Termeni și condiții',
			'settings.operatorCall' => 'Indicativul operatorului',
			'settings.sync.title' => 'Sincronizare în cloud',
			'settings.sync.moreSettings' => 'Mai multe setări de sincronizare',
			'settings.sync.enable' => 'Activează sincronizarea',
			'settings.sync.deviceKey' => 'Cheia dispozitivului',
			'settings.peers.title' => 'Dispozitive pereche',
			'settings.peers.enable' => 'Conectare la alte dispozitive',
			'settings.peers.enableDescription' => 'Permite partajarea operațiunilor, înregistrării, CAT și GPS cu alte dispozitive prin rețeaua locală',
			'settings.peers.bleEnable' => 'Conectare prin Bluetooth',
			'settings.peers.bleDescription' => 'Folosește Bluetooth LE pentru conectare chiar și fără rețea locală',
			'settings.peers.thisDevice' => 'Acest dispozitiv',
			'settings.peers.deviceName' => 'Nume',
			'settings.peers.deviceNameHint' => 'Cum este văzut acest dispozitiv de celelalte dispozitive',
			'settings.peers.pairedDevices' => 'Dispozitive asociate',
			'settings.peers.noPairedDevices' => 'Niciun dispozitiv asociat încă. Activați această opțiune și pe un alt dispozitiv din această rețea pentru a le asocia.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Dispozitivele asociate nu pot fi citite: ${error}',
			'settings.peers.nearby' => 'În apropiere',
			'settings.peers.connected' => 'Conectat',
			'settings.peers.viaBluetooth' => 'prin Bluetooth',
			'settings.peers.connecting' => 'Se conectează…',
			'settings.peers.syncing' => 'Se sincronizează…',
			'settings.peers.waitingForThem' => 'Se așteaptă celălalt dispozitiv',
			'settings.peers.notConnected' => 'Neconectat',
			'settings.peers.wantsToPair' => 'vrea să partajeze această operațiune',
			'settings.peers.allow' => 'Permite',
			'settings.peers.link' => 'Asociază',
			'settings.peers.reject' => 'Respinge',
			'settings.peers.forget' => 'Uită',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Uitați ${name}?',
			'settings.peers.forgetBody' => 'Nu se va mai sincroniza cu acest dispozitiv. Îl puteți permite din nou mai târziu, iar contactele deja înregistrate se păstrează.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Asociere cu ${name}',
			'settings.peers.pairBody' => 'Acest dispozitiv este în rețeaua dvs. locală și vrea să se conecteze.',
			'settings.peers.pairBodyBle' => 'Acest dispozitiv este în apropiere și vrea să se conecteze prin Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID dispozitiv',
			'settings.peers.pairWarning' => 'Asociați doar dispozitive pe care le recunoașteți. Orice dispozitiv din această rețea poate trimite o cerere.',
			'settings.peers.pairWarningBle' => 'Asociați doar dispozitive pe care le recunoașteți. Orice dispozitiv din apropiere poate trimite o cerere.',
			'settings.peers.problem' => ({required Object error}) => 'Rețeaua locală nu poate fi accesată: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Conectat la ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Conexiunea cu ${device} s-a pierdut',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispozitive pereche: ${connected} din ${linked} conectate',
			'settings.peers.screenEnable' => 'Partajare ecrane și ferestre',
			'settings.peers.screenDescription' => 'Permite altor dispozitive să afișeze ecrane sau ferestre de pe acest calculator',
			'settings.peers.screenSources' => 'Ecrane și ferestre',
			'settings.peers.screenRefresh' => 'Reîmprospătează lista',
			'settings.peers.screenUnsupportedPlatform' => 'Acest dispozitiv nu își poate partaja ecranul. macOS poate; orice dispozitiv poate afișa un ecran partajat de altul.',
			'settings.peers.screenUnsupportedVersion' => 'Partajarea ecranului necesită macOS 12.3 sau mai nou. Acest dispozitiv poate totuși afișa un ecran partajat de altul.',
			'settings.peers.screenNeedsPermission' => 'macOS are nevoie de permisiunea dvs. de înregistrare a ecranului înainte ca această aplicație să poată partaja unul.',
			'settings.peers.screenGrantPermission' => 'Cere permisiunea',
			'settings.peers.screenRelaunchAfterGranting' => 'Permiteți-o în System Settings la Privacy & Security → Screen Recording, apoi închideți și redeschideți aplicația — macOS anunță aplicația despre schimbare abia la următoarea pornire.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Partajare ecran: ${error}',
			'settings.peers.screenChooseTitle' => 'Alegeți ce partajați',
			'settings.peers.screenChooseButton' => 'Alegeți ce partajați…',
			'settings.peers.screenTabScreens' => 'Ecrane',
			'settings.peers.screenTabApps' => 'Aplicații',
			'settings.peers.screenTabWindows' => 'Ferestre',
			'settings.peers.screenTabEmpty' => 'Nu s-a găsit nimic de acest tip.',
			'settings.peers.screenSharedSummaryNone' => 'Nimic ales încă.',
			'settings.peers.screenThisDevice' => 'Acest dispozitiv',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Afișat pe ${devices}',
			'settings.peers.screenSharedToNobody' => 'Nu este afișat',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Oprește partajarea ${name}',
			'settings.developerMode' => 'Mod dezvoltator',
			'settings.syncPanel.configuration' => 'Configurarea sincronizării',
			'settings.syncPanel.enableTitle' => 'Sincronizare cu Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Se face backup și se sincronizează jurnalul pe toate dispozitivele',
			'settings.syncPanel.disabledDescription' => 'Oprit — datele rămân doar pe acest dispozitiv',
			'settings.syncPanel.syncing' => 'Se sincronizează',
			'settings.syncPanel.account' => 'Cont',
			'settings.syncPanel.refresh' => 'Reîmprospătează',
			'settings.syncPanel.switchAccounts' => 'Schimbă contul',
			'settings.syncPanel.switchAccountsDescription' => 'Conectați acest dispozitiv la alt cont cu un cod QR sau prin e-mail',
			'settings.syncPanel.connectionRequests' => 'Cereri de conexiune',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Un dispozitiv așteaptă să se alăture acestui cont', other: '${n} dispozitive așteaptă să se alăture acestui cont', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mailul contului',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmarea a fost trimisă la ${email}. Deschideți linkul de acolo pentru a finaliza schimbarea.',
			'settings.syncPanel.resendConfirmation' => 'Retrimite e-mailul de confirmare',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Se așteaptă confirmarea pentru ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Retrimis la ${email}.',
			'settings.syncPanel.deviceLinked' => 'Acel dispozitiv este acum conectat la acest cont.',
			'settings.syncPanel.checking' => 'Se verifică…',
			'settings.syncPanel.notLinked' => 'Neconectat încă',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Înlocuiți datele locale?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${n} operațiune', other: '${n} operațiuni', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${n} QSO', other: '${n} QSO-uri', ), 
			'settings.syncPanel.counts' => 'Date sincronizate',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Acest dispozitiv: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Așteaptă încărcarea: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Acest dispozitiv: se verifică…',
			'settings.syncPanel.countsServerChecking' => 'Server: se verifică…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: indisponibil',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Aceasta salvează și șterge ${operations} și ${qsos} de pe acest dispozitiv, apoi descarcă în locul lor datele contului. Copia de rezervă rămâne în baza de date a acestui dispozitiv.',
			'settings.syncPanel.replace' => 'Înlocuiește',
			'settings.syncPanel.pendingBannerTitle' => 'A fost detectat un cont Ham2K Log Filer nou',
			'settings.syncPanel.pendingBannerBody' => 'Păstrați operațiunile și QSO-urile existente pe acest dispozitiv și combinați-le în cont, sau înlocuiți-le cu datele contului (oricum rămâne o copie de rezervă pe acest dispozitiv).',
			'settings.syncPanel.combine' => 'Combină',
			'settings.syncPanel.authIssueTitle' => 'Sincronizarea nu se poate conecta',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer respinge în continuare acest dispozitiv. Verificați indicativul în setările de sincronizare.',
			'settings.syncPanel.openSettings' => 'Deschide setările de sincronizare',
			'settings.accounts.title' => 'Conturi, servicii și surse de date',
			'settings.accounts.none' => 'Nicio extensie activă cu conturi',
			'settings.accounts.notConfigured' => 'Neconfigurat',
			'settings.accounts.connected' => 'Conectat',
			'settings.accounts.cancelLogin' => 'Anulează autentificarea',
			'settings.accounts.openInBrowser' => 'Deschide în browser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Autentificat ca ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Apăsați Salvează pentru a păstra acest cont conectat.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Conectat la ${label}',
			'settings.accounts.connect' => 'Conectează',
			'settings.accounts.disconnect' => 'Deconectează',
			'settings.accounts.connectedAs' => 'Conectat ca',
			'settings.accounts.test' => 'Testează',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Salvarea a eșuat: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Autentificarea a eșuat: ${error}',
			'settings.accounts.lookupFailed' => 'Conturile nu sunt disponibile acum — încercați din nou peste un moment',
			'settings.accounts.browserLoginTitle' => 'Finalizați autentificarea în browser',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Când terminați, browserul va încerca să deschidă un link care începe cu "${prefix}". Cel mai probabil calculatorul dvs. nu are nimic înregistrat pentru a-l deschide, așa că copiați acel link (din bara de adrese sau din pagina de eroare afișată de browser) și lipiți-l aici.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger nu a putut deschide browserul. Copiați linkul de autentificare de mai jos și deschideți-l singuri, apoi copiați linkul către care vă trimite (începe cu "${prefix}") și lipiți-l aici.',
			'settings.accounts.copyLoginLink' => 'Copiază linkul de autentificare',
			'settings.accounts.pastedLinkLabel' => 'Lipiți linkul aici',
			'settings.accounts.finishLogin' => 'Finalizează autentificarea',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Acesta nu este linkul de autentificare — ar trebui să înceapă cu "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Acest link aparține altei încercări de autentificare. Închideți această pagină și conectați-vă din nou.',
			'settings.accounts.pastedLinkNoCode' => 'Acest link nu are cod de autentificare. Finalizați mai întâi autentificarea, apoi copiați linkul către care vă trimite.',
			'settings.accounts.pastedLinkMalformed' => 'Linkul pare trunchiat. Copiați-l integral și lipiți-l din nou.',
			'settings.accounts.relayLoginWaiting' => 'Se așteaptă finalizarea autentificării — procesul continuă automat după aceea.',
			'settings.accounts.loginNoResponse' => 'Acest dispozitiv nu a primit încă răspuns de la autentificare. Dacă ați terminat deja în browser, anulați și încercați din nou conectarea.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger nu a putut deschide automat browserul. Folosiți butonul de mai jos pentru a deschide singuri pagina de autentificare.',
			'settings.accounts.relayLoginUnavailable' => 'Serverul de sincronizare necesar pentru această autentificare nu a putut fi accesat. Verificați conexiunea și încercați din nou.',
			'settings.accounts.loginIncompleteResponse' => 'Încercarea de autentificare nu s-a finalizat corect. Încercați din nou conectarea.',
			'settings.accounts.noKeyringTitle' => 'Autentificările conturilor nu pot fi salvate',
			'settings.accounts.noKeyringText' => 'Ham2K Logger nu poate accesa un serviciu keyring pe acest calculator, deci autentificările conturilor nu pot fi stocate sau citite — conectarea unui cont va eșua până la rezolvare. Instalați și porniți **gnome-keyring**, **KWallet** sau **KeePassXC** ori deblocați keyring-ul existent, apoi reporniți. Înregistrarea, exporturile și fișierele de date nu sunt afectate; sincronizarea jurnalului rămâne oprită între timp.',
			'settings.accounts.noKeyringInline' => 'Autentificările nu pot fi salvate: keyring-ul acestui calculator nu poate fi accesat. Instalați și porniți gnome-keyring, KWallet sau KeePassXC ori deblocați-l pe cel existent.',
			'settings.accounts.noSecureStorageInline' => 'Autentificările nu pot fi salvate: stocarea securizată a acestui calculator nu poate fi accesată.',
			'settings.station.title' => 'Configurația stației și control CAT',
			'settings.station.none' => 'Niciun echipament configurat',
			'settings.station.add' => 'Adaugă',
			'settings.station.addTitle' => 'Adaugă echipament',
			'settings.station.searchHint' => 'Căutați echipament',
			'settings.station.noMatches' => 'Niciun echipament nu corespunde',
			'settings.station.detectedEquipment' => 'Echipament detectat',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Nu se pot căuta stații radio: ${error}',
			'settings.station.edit' => 'Editează echipamentul',
			'settings.station.name' => 'Nume',
			'settings.station.nameDescription' => 'Cum îl numiți — „Stația din stânga”. Opțional.',
			'settings.station.transport' => 'Conexiune',
			'settings.station.host' => 'Adresă',
			'settings.station.hostDescription' => 'Numele de gazdă sau adresa IP a stației radio în rețeaua dvs.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Adresa este obligatorie',
			'settings.station.portInvalid' => 'Portul trebuie să fie între 1 și 65535',
			'settings.station.connect' => 'Conectează',
			'settings.station.disconnect' => 'Deconectează',
			'settings.station.remove' => 'Elimină',
			'settings.station.removeTitle' => ({required Object name}) => 'Eliminați ${name}?',
			'settings.station.removeMessage' => 'Aceasta îl elimină doar din aplicație. Setările echipamentului rămân neschimbate.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tip de echipament nerecunoscut „${typeKey}”',
			'settings.station.report' => 'Raportează',
			'settings.station.reportTitle' => 'Raportați această stație radio',
			'settings.station.reportIntro' => 'Spuneți-ne ce stație radio este de fapt și cum a funcționat. Raportul dvs. devine un card citit de echipa Ham2K, iar ce scrieți despre punerea ei în funcțiune poate ajuta următorul operator cu același aparat.',
			'settings.station.reportManufacturer' => 'Producător',
			'settings.station.reportManufacturerDescription' => 'Cine o produce — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Producătorul este obligatoriu',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'Modelul, așa cum îl numește stația însăși — „IC-7300”, „FT-991A”.',
			'settings.station.reportModelRequired' => 'Modelul este obligatoriu',
			'settings.station.reportOutcome' => 'Cum a funcționat?',
			'settings.station.reportOutcomeWorks' => 'A funcționat bine',
			'settings.station.reportOutcomeIssues' => 'A funcționat, cu probleme',
			'settings.station.reportOutcomeFails' => 'Nu a funcționat deloc',
			'settings.station.reportOutcomeRequired' => 'Spuneți-ne cum a funcționat',
			'settings.station.reportComments' => 'Comentarii',
			'settings.station.reportCommentsPlaceholder' => 'Ce a mers, ce nu, orice v-a surprins.',
			'settings.station.reportHints' => 'Sfaturi de depanare',
			'settings.station.reportHintsPlaceholder' => 'Doriți să sugerați sfaturi de depanare pentru alți utilizatori?',
			'settings.station.reportSend' => 'Trimite raportul',
			'settings.station.reportSending' => 'Se trimite raportul…',
			'settings.station.reportSent' => ({required Object ref}) => 'Mulțumim — raportul dvs. a fost înregistrat ca ${ref}.',
			'settings.station.reportSentNoRef' => 'Mulțumim — raportul dvs. a fost trimis.',
			'settings.station.reportFailed' => ({required Object error}) => 'Raportul nu a fost trimis: ${error}',
			'settings.station.troubleshootingNotes' => 'Note de depanare',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Folosește ca VFO principal',
			'settings.station.serialPort' => 'Port serial',
			'settings.station.serialPortDescription' => 'Portul pe care apare interfața CAT a stației radio.',
			'settings.station.serialPortNone' => 'Nu s-au găsit porturi seriale',
			'settings.station.serialPortRequired' => 'Alegeți un port serial',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'portul ${n} din ${total}',
			'settings.station.serialPortSuggested' => 'sugerat',
			'settings.station.serialPortJustNow' => 'Conectat recent',
			'settings.station.serialPortNoDriver' => 'fără driver',
			'settings.station.serialDeviceRequest' => 'Adaugă un dispozitiv USB…',
			'settings.station.bleDevice' => 'Dispozitiv Bluetooth LE',
			'settings.station.bleDeviceDescription' => 'Puntea serială prin care este conectată stația radio, cum ar fi un LiNK500MP în Mode 4 sau un adaptor serial BLE.',
			'settings.station.bleScan' => 'Caută dispozitive Bluetooth LE…',
			'settings.station.bleScanNoneFound' => 'Nu s-a găsit niciun dispozitiv Bluetooth LE. Verificați că puntea este pornită, în apropiere și în modul ei Bluetooth LE (Mode 4 pe un LiNK500MP).',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'Scanarea Bluetooth LE nu a putut rula: ${reason}',
			'settings.station.bleOff' => 'Bluetooth este oprit.',
			'settings.station.bleDenied' => 'Permisiunea Bluetooth nu a fost acordată. Permiteți-o în setările sistemului, apoi încercați din nou.',
			'settings.station.bleUnsupported' => 'Acest dispozitiv nu are Bluetooth LE.',
			'settings.station.bleStarting' => 'Bluetooth încă pornește. Încercați din nou peste un moment.',
			'settings.station.bleConnectFailed' => 'Dispozitivul Bluetooth LE nu poate fi accesat. Verificați că este pornit, în apropiere și neconectat la altă aplicație.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'Acest dispozitiv Bluetooth LE nu are niciun serviciu serial pe care aplicația să-l recunoască. Raportați-l împreună cu serviciile lui: ${services}',
			'settings.station.baudRate' => 'Viteză (baud)',
			'settings.station.baudRateDescription' => 'Trebuie să corespundă meniului CAT al stației radio. La nepotrivire, stația trimite înapoi date fără sens și nicio eroare.',
			'settings.station.serialRtsHigh' => 'Menține RTS activ',
			'settings.station.serialRtsHighDescription' => 'Doar pentru o stație radio care așteaptă RTS înainte de a răspunde, cum ar fi un Yaesu cu CAT RTS activat. Pe un Digirig, SignaLink și majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă trece pe emisie.',
			'settings.station.serialDtrHigh' => 'Menține DTR activ',
			'settings.station.serialDtrHighDescription' => 'Doar pentru o interfață CAT alimentată din DTR, cum ar fi unele cabluri RS-232 pentru FT-817. Pe multe cabluri DTR manipulează CW sau PTT, iar menținerea lui activă trece pe emisie.',
			'settings.station.serialUsbDriver' => 'Driver cip USB',
			'settings.station.serialUsbDriverDescription' => 'Automat recunoaște majoritatea adaptoarelor. Alegeți cipul doar pentru unul la care lista de porturi spune că nu are driver — îl indică ambalajul sau o listă de dispozitive USB.',
			'settings.station.serialUsbDriverAuto' => 'Automat',
			'settings.station.civAddress' => 'Adresa CI-V a stației radio',
			'settings.station.civAddressDescription' => 'Hex, așa cum apare în meniul CI-V al stației radio. IC-705 vine setat pe A4.',
			'settings.station.civAddressInvalid' => 'O adresă CI-V are două cifre hex, de la 01 la FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Din care slice al stației radio citește și pe care îl acordă această conexiune.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Alegeți unul dintre slice-urile stației radio, de la A la H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} nu este folosit pe această stație radio — alegeți alt slice sau creați-l în SmartSDR',
			'settings.station.channelNotInUse' => 'nefolosit',
			'settings.station.channelHeldByUnknown' => 'folosit de alt program',
			'settings.station.flexNoSlices' => 'Această stație radio nu a raportat niciun slice — verificați că SmartSDR rulează și că acest client se poate abona',
			'settings.station.spectrumUnsupported' => 'Această stație radio nu trimite spectru prin CAT',
			'settings.station.spectrumRequiresBaud' => 'Necesită CAT la 115200 bps',
			'settings.station.spectrumNoRadio' => 'Nicio stație radio conectată',
			'settings.station.spectrumWaiting' => 'Se așteaptă spectrul stației radio…',
			'settings.station.spectrumUnavailable' => 'Afișarea spectrului nu este disponibilă',
			'settings.station.spectrumNoDaxChannel' => 'Toate canalele DAX IQ ale acestei stații radio sunt ocupate',
			'settings.station.spectrumNoPanadapter' => 'Acest slice nu are panadapter pe stația radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Stația radio a refuzat un flux DAX IQ (eroare ${code})',
			'settings.station.spectrumNoUdp' => 'Datele de spectru ale stației radio nu pot ajunge la acest dispozitiv',
			'settings.station.spectrumK4Unavailable' => 'Spectrul LAN al K4 nu poate fi recepționat. Se reîncearcă…',
			'settings.station.spectrumK4RemoteUnavailable' => 'Spectrul la distanță al K4 nu poate fi recepționat',
			'settings.station.spectrumScopeRefused' => 'Stația radio a refuzat comenzile de scope',
			'settings.station.spectrumOutOfRange' => 'Scope-ul stației radio este setat în afara intervalului pe care îl poate afișa',
			'settings.station.spectrumBandUnsupported' => 'Scope-ul stației radio nu poate fi afișat pe această bandă',
			'settings.station.spectrumSdrNoRadio' => 'Se așteaptă frecvența stației radio asociate…',
			'settings.station.spectrumSdrNotConnected' => 'SDR-ul nu este conectat',
			'settings.station.spectrumSdrNoIf' => 'Setați frecvența IF a stației radio în setările acestui SDR',
			'settings.station.sdrRadio' => 'Afișează spectrul pentru',
			'settings.station.sdrRadioDescription' => 'O afișare de spectru pe această stație radio folosește acest receptor în locul scope-ului propriu al stației.',
			'settings.station.sdrRadioMain' => 'Stația radio principală',
			'settings.station.sdrTuning' => 'Intrare de antenă',
			'settings.station.sdrTuningDescription' => 'De unde vine semnalul receptorului. Pe propria antenă se acordă singur pentru a urmări stația radio; pe ieșirea IF a stației rămâne pe IF.',
			'settings.station.sdrTuningIndependent' => 'Propria antenă',
			'settings.station.sdrTuningIfTap' => 'Ieșirea IF a stației radio',
			'settings.station.sdrIfHz' => 'Frecvența IF (Hz)',
			'settings.station.sdrIfHzDescription' => 'Doar pentru o ieșire IF: frecvența la care se află scala stației radio pe IF-ul ei, cum ar fi 68330000 pe un FT-817.',
			'settings.station.sdrIfInverted' => 'IF inversat',
			'settings.station.sdrGainDb' => 'Amplificare (dB)',
			'settings.station.sdrGainDbDescription' => 'Lăsați gol pentru amplificarea automată a receptorului.',
			'settings.station.sdrOffsetHz' => 'Decalaj de frecvență (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'Se adaugă la fiecare frecvență trimisă receptorului, pentru un upconverter: 125000000 pentru un Ham It Up.',
			'settings.station.sdrPpm' => 'Corecție de frecvență (ppm)',
			'settings.station.rtlDirectSampling' => 'Eșantionare directă',
			'settings.station.rtlDirectSamplingDescription' => 'Pentru HF pe un RTL-SDR V3 fără upconverter. Un RTL-SDR V4 ajunge în HF fără ea.',
			'settings.station.rtlDirectSamplingOff' => 'Oprit',
			'settings.station.rtlDirectSamplingI' => 'Ramura I',
			'settings.station.rtlDirectSamplingQ' => 'Ramura Q',
			'settings.station.rtlTcpNotAServer' => 'Acesta nu este un server rtl_tcp',
			'settings.station.rtlTcpNotes' => 'Aceasta se conectează la un **server rtl_tcp pe care îl rulați dvs.** pe calculatorul în care este conectat dongle-ul.\n\n- **Porniți-l** cu `rtl_tcp -a 0.0.0.0` ca să poată fi accesat de alte mașini; pe aceeași mașină ajunge `rtl_tcp` simplu.\n- **Portul** este 1234 dacă nu l-ați pornit cu `-p`.\n- **Un singur program odată:** rtl_tcp servește un singur client. Aplicația se conectează doar cât timp este afișat un spectru și eliberează conexiunea câteva secunde după închiderea lui.\n- **Pe Android**, aplicația *SDR driver* rulează același server pe telefon.',
			'settings.station.rspTcpNotes' => 'Aceasta se conectează la un **server rsp_tcp pe care îl rulați dvs.** pe calculatorul în care este conectat RSP-ul, cu API-ul SDRplay instalat acolo.\n\n- **Porniți-l** cu `rsp_tcp -a 0.0.0.0`.\n- **Portul** este 1234 dacă nu l-ați pornit cu `-p`.\n- **Un singur program odată:** serverul acceptă un singur client. Aplicația se conectează doar cât timp este afișat un spectru.',
			'settings.station.n3fjpNoRig' => 'N3FJP nu are configurată o interfață radio, deci aceasta urmează ce se tastează în N3FJP, nu o stație radio',
			'settings.station.winkeyerKeyPort' => 'Ieșire de manipulare',
			'settings.station.winkeyerKeyPortDescription' => 'În care dintre cele două mufe de ieșire ale keyer-ului este conectată stația radio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Portul ${n}',
			'settings.station.winkeyerPtt' => 'Folosește PTT-ul keyer-ului',
			'settings.station.winkeyerPttDescription' => 'Activează linia PTT pe aceeași mufă, pentru un amplificator sau o stație radio care o necesită. Lăsați dezactivat pentru o stație manipulată prin mufa de manipulator.',
			'settings.station.winkeyerNoAnswer' => 'Niciun WinKeyer nu a răspuns pe acest port',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer a încetat să răspundă în timpul transmisiei; mesajul a fost abandonat',
			'settings.station.icomControlPort' => 'Port de control (UDP)',
			'settings.station.icomControlPortDescription' => 'Portul de control (UDP) al stației radio — 50001 dacă nu a fost schimbat în setările ei de rețea sau redirecționat către altul.',
			'settings.station.icomSerialPort' => 'Port serial (UDP)',
			'settings.station.icomSerialPortDescription' => 'Portul serial (UDP) al stației radio — 50002 dacă nu a fost schimbat în setările ei de rețea sau redirecționat către altul.',
			'settings.station.icomPortsDiffer' => 'Portul de control și cel serial trebuie să difere',
			'settings.station.radioUser' => 'Utilizator stație radio',
			'settings.station.radioPass' => 'Parolă stație radio',
			'settings.station.radioLoginDescription' => 'Autentificarea Network → Remote a stației radio, nu parola WiFi.',
			'settings.station.radioUserRequired' => 'Utilizatorul pentru controlul la distanță al stației radio este obligatoriu',
			'settings.station.connectFailedBusy' => 'Dispozitivul este ocupat',
			'settings.station.connectFailedDenied' => 'Acces refuzat',
			'settings.station.connectFailedDevice' => 'Dispozitivul nu a fost găsit',
			'settings.station.connectFailedUnsupported' => 'Niciun driver nu recunoaște cipul acestui adaptor USB. Dacă știți ce cip este, alegeți-l la „Driver cip USB” din Setări avansate.',
			'settings.station.connectFailedLines' => 'RTS/DTR nu au putut fi menținute cum au fost setate, așa că portul a fost închis. Alt program poate să fi lăsat activat handshaking-ul hardware — deconectați și reconectați cablul.',
			'settings.station.connectFailedNetwork' => 'Stația radio nu poate fi găsită în rețea. Verificați adresa și că este pornită și accesibilă.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'Portul ${port} de pe acest dispozitiv este deja folosit, iar răspunsurile sosesc acolo. Închideți orice altceva ascultă pe el — inclusiv alt nod PstRotator — sau schimbați portul.',
			'settings.station.connectFailedTimeout' => 'Stația radio nu a răspuns la timp. Verificați că este pornită și accesibilă.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Generic',
			'settings.station.models.icomGeneric' => 'Icom - Generic',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Generic',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Generic',
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
			'settings.station.models.rigctld' => 'Stație radio controlată prin rigctld',
			'settings.station.models.rigctldNodeName' => 'Stația mea (prin rigctld)',
			'settings.station.models.flrig' => 'Stație radio controlată prin flrig',
			'settings.station.models.flrigNodeName' => 'Stația mea (prin flrig)',
			'settings.station.models.hrd' => 'Stație radio controlată prin Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Stația mea (prin HRD)',
			'settings.station.models.n3fjp' => 'Stație radio controlată prin N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Stația mea (prin N3FJP)',
			'settings.station.models.commander' => 'Stație radio controlată prin DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Stația mea (prin Commander)',
			'settings.station.models.antenna' => 'Antenă',
			'settings.station.models.key' => 'Manipulator CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Stație radio generică (substituent)',
			'settings.station.models.placeholderRadioNodeName' => 'Stația mea',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.models.gs232a' => 'Interfață de rotor Yaesu GS-232A',
			'settings.station.models.pstRotator' => 'PstRotator (control UDP)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Rețea/WiFi',
			'settings.station.transports.secureNetwork' => 'Rețea/WiFi securizată',
			'settings.station.transports.usbSerial' => 'Serial USB',
			'settings.station.transports.wifi' => 'Rețea/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Serial Bluetooth',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Substituent',
			'settings.station.troubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.ft891Troubleshooting' => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **CAT RTS dezactivat pe stația radio sau „Menține RTS activ” pornit.** Cu **CAT RTS** activat (meniul FT-891 **05-08**), stația tace cât timp RTS este jos — poate răspunde o dată la deschiderea portului, apoi nimic. Alegerea portului USB propriu al stației pornește **Menține RTS activ** în Setări avansate. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă vă trece emițătorul pe emisie: în acest caz dezactivați CAT RTS pe stație.\n- **Viteza trebuie să corespundă** cu CAT RATE al stației (meniul **05-06**). La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.yaesuBinaryTroubleshooting' => 'Această stație radio folosește vechiul CAT Yaesu de cinci octeți și nu răspunde deloc când ceva nu e în regulă. Aproape întotdeauna este una dintre:\n\n- **Cablul trebuie să convertească nivelurile.** Mufa CAT din spate nu este RS-232 și nici USB; necesită un CT-62 sau un adaptor echivalent. Un simplu cablu audio sau de date nu funcționează pentru CAT.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației (**#14** pe un FT-817, **#19** pe un FT-857 sau FT-897). La nepotrivire, stația nu trimite nimic înapoi, niciodată o eroare.\n- **Nu lăsați nimic să ridice RTS sau DTR pe acest port.** Pe majoritatea cablurilor pentru aceste stații, acele linii sunt PTT și manipulare. Excepția este o interfață mai veche alimentată din DTR: pentru aceasta activați **Menține DTR activ** din Setări avansate.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAcest driver a fost scris după tabelul CAT publicat de Yaesu și nu a fost testat pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.tenTecTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.tenTecEagleTroubleshooting' => '- **Portul USB-B din spate este legătura CAT.** Stația apare ca un port serial USB; pe Windows are nevoie de driverul USB to UART de la Ten-Tec, care apare în Device Manager ca „USB to UART (COMx)”.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis, la fel și programul de actualizare a firmware-ului de la Ten-Tec.\n- **Setarea lățimii filtrului din aplicație o ia de sub controlul butonului BW** până când stația este oprită și repornită. Așa funcționează stația.\n\nAcest driver a fost scris după ghidul de referință pentru programatori de la Ten-Tec. Dacă funcționează pe jumătate, merită raportat, împreună cu versiunea de firmware din meniul stației.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Folosiți un cablu serial DB-9 direct** la portul SERIAL DATA, nu unul null-modem.\n- **Această intrare menține RTS activ**, deoarece Orion folosește RTS și CTS ca handshake. Pe o interfață care comandă PTT din RTS, cum ar fi un Digirig, dezactivați „Menține RTS activ” din Setări avansate, altfel stația emite imediat ce aplicația se conectează.\n- **CW din aplicație necesită keyer-ul intern al stației pornit.** Cu el oprit, stația ignoră ce trimite aplicația.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAcest driver a fost scris după ghidul de referință pentru programatori de la Ten-Tec și nu a fost testat pe un Orion. Dacă funcționează pe jumătate, merită raportat, împreună cu versiunea de firmware din meniul stației.',
			'settings.station.tenTecNoCw' => 'Firmware-ul acestei stații radio nu acceptă CW din aplicație. Ten-Tec l-a adăugat în firmware-ul Orion 1.366.',
			'settings.station.tenTecKeyerOff' => 'Keyer-ul intern al stației radio este oprit, așa că ignoră CW-ul trimis din aplicație. Porniți keyer-ul din meniul stației.',
			'settings.station.guohetecTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.guohetecTroubleshooting' => 'Q900 are două protocoale CAT, iar această intrare folosește protocolul nativ, nu imitația FT-817. Alegeți aici **Guohetec Q900**, nu un FT-817 — imitația acceptă mai puține comenzi, iar stația nu spune pe care îl folosește.\n\n- **Cablul USB-C este legătura CAT** și conectează și placa de sunet. Viteza nu contează pe el; portul ignoră valoarea setată.\n- **Nu lăsați nimic să ridice RTS sau DTR pe acest port.** Pe un cablu serial, acele linii sunt PTT și manipulare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **O stație de a doua generație se comportă diferit** față de prima. Apăsați lung Menu, apoi About: HW 2.0 este a doua generație.\n\nAcest driver a fost scris după protocolul publicat de producător și nu a fost testat pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.yaesuTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.yaesuTroubleshooting' => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **CAT RTS trebuie să fie OFF pe stația radio.** Când este activat, stația așteaptă o linie de handshake pe care aplicația o ține jos. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, aceeași linie este PTT, deci ridicarea ei v-ar trece emițătorul pe emisie. Pe portul USB propriu al stației, alternativa este **Menține RTS activ** din Setări avansate. Locul acestei setări diferă de la model la model (meniul **05-08** pe un FT-891).\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **Modurile urmează tabelul FT-891.** Majoritatea gamei Yaesu corespunde, dar o stație care își numerotează modurile altfel va afișa și va seta modul greșit pentru acestea. Frecvența nu este afectată.',
			'settings.station.ftdx3000Troubleshooting' => '**Meniul 037 CAT SELECT trebuie să fie USB** pentru CAT prin portul USB al stației; setat pe RS232C, CAT este pe mufa din spate.\n\nAceastă intrare a fost scrisă după documentația CAT publicată și nu a fost testată pe un FTDX3000. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.yaesuRs232Troubleshooting' => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **Mufa CAT este RS-232.** Necesită un adaptor USB-serial și un cablu DB-9 direct — un cablu null-modem inversează liniile, iar stația nu aude nimic.\n- **CAT RTS trebuie să fie OFF pe stația radio.** Când este activat, stația așteaptă o linie de handshake pe care aplicația o ține jos, cu excepția cazului în care **Menține RTS activ** este pornit în Setări avansate.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\nAceastă intrare a fost scrisă după documentația CAT publicată și nu a fost testată pe una dintre aceste stații. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.yaesuUsbTroubleshooting' => 'Stația radio primește comenzi, dar nu răspunde. Aproape întotdeauna este una dintre:\n\n- **Folosiți primul dintre cele două porturi USB ale stației.** CAT este de obicei pe primul (portul COM **Enhanced** pe Windows); al doilea (**Standard**) este pentru PTT și manipulare. Selectorul indică primul port ori de câte ori le poate deosebi.\n- **CAT RTS dezactivat pe stația radio sau „Menține RTS activ” pornit.** Cu meniul **CAT RTS** al stației activat, aceasta tace cât timp RTS este jos — poate răspunde o dată la deschiderea portului, apoi nimic. Alegerea portului USB propriu al stației pornește **Menține RTS activ** în Setări avansate. Pe un Digirig, SignaLink sau majoritatea cablurilor făcute în casă, RTS este PTT, iar menținerea lui activă vă trece emițătorul pe emisie: în acest caz dezactivați CAT RTS pe stație.\n- **Viteza trebuie să corespundă** cu meniul CAT RATE al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.',
			'settings.station.k4SerialNotes' => 'Conectați mufa USB-B (PC) din spatele K4. Atât USB-PC1, cât și USB-PC2 funcționează pentru CAT; alegeți un port nefolosit și potriviți setarea Serial USB-PCn: Baud Rate de pe stație. HaLo completează 38400; schimbați dacă e nevoie. O altă aplicație trebuie să folosească celălalt port sau Ethernet.\n\nAceastă conexiune controlează stația și keyer-ele ei; nu trimite audio către HaLo.',
			'settings.station.k4TcpNotes' => 'Conectați mufa Ethernet a K4 la rețeaua locală. Introduceți numele de gazdă sau adresa IP și portul CAT 9200. HaLo folosește același host pe portul fix 9201 când este vizibil un panadapter sau un waterfall; schimbarea portului CAT nu schimbă portul de spectru.\n\nSpectrul arată receptorul principal. Controalele lui de zoom, de ajustare a referinței și de viteză afectează doar afișarea din HaLo. Transmisia audio nu este acceptată.',
			'settings.station.k4PowerTimeout' => 'Puterea K4 nu a fost schimbată deoarece stația nu a confirmat intervalul de ieșire. Încercați din nou.',
			'settings.station.k4RemoteNotes' => 'Activați accesul la distanță pe K4 și introduceți parola lui de rețea. Main și Sub folosesc o singură conexiune criptată pentru controlul stației și spectru. Portul implicit este 9204; introduceți portul redirecționat când vă conectați de la distanță.\n\nRedarea audio și transmisia microfonului nu sunt acceptate.',
			'settings.station.k4Receiver' => 'Receptor',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Alegeți Main sau Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'Acel receptor este deja configurat pentru acest K4',
			'settings.station.k4SubReceiverOff' => 'Receptorul Sub al K4 este oprit',
			'settings.station.k4RemotePasswordRequired' => 'Introduceți parola de rețea a K4 pentru o conexiune securizată.',
			'settings.station.k4RemoteHandshakeFailed' => 'K4 nu a putut stabili o conexiune securizată. Verificați parola de rețea și setările de acces la distanță.',
			'settings.station.k4RemoteUnreachable' => 'Conexiunea securizată a K4 nu a putut fi accesată. Verificați adresa, portul și setările de acces la distanță.',
			'settings.station.k4PowerRange' => 'Puterea K4 trebuie să fie 0.1–110 W sau 0.0001–0.01 W când ieșirea de miliwați a transverterului este activă.',
			'settings.station.elecraftTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.elecraftTroubleshooting' => 'Stațiile Elecraft folosesc CAT Kenwood, iar un KX2 și un KX3 au fost ambele testate astfel — VFO în ambele direcții, schimbarea modului și zero-beat CW funcționează toate.\n\nDacă stația nu răspunde, aproape întotdeauna este una dintre:\n\n- **Viteza trebuie să corespundă** cu rata setată la **RS232** în meniul stației. Acestea vin setate pe 38400. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n\n**Dacă frecvența este corectă, dar modul este greșit**, spuneți-ne. Intrările KX2 și KX3 citesc modul dintr-o poziție a răspunsului de stare pe care am fixat-o după stațiile văzute, iar un firmware care îl pune în altă parte ajunge la noi doar printr-un raport.\n\nK3 nu a fost raportat încă în niciun sens, așa că spuneți-ne ce se întâmplă dacă folosiți unul. K4 are propria intrare.',
			'settings.station.lab599TroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.lab599Troubleshooting' => 'Gama TX-500 folosește CAT Kenwood. Frecvența și modul au fost testate printr-un LiNK500MP; puterea și instrumentele sunt scrise după referința CAT de la Lab599, așa că raportați ce se întâmplă în orice caz.\n\n- **Viteza trebuie să corespundă** cu setarea CAT a stației, 9600 dacă nu ați schimbat-o. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Alegeți protocolul CAT pe stație.** TS-2000 acoperă frecvența, modul și puterea. LAB599 permite în plus aplicației să treacă stația pe DIG, să vadă că emite în DIG și să citească tensiunea de alimentare.\n- **Printr-un LiNK500MP**, apăsați lung butonul VFO cam trei secunde pentru a preda controlul CAT interfeței.\n- **Setați modul LiNK500MP potrivit conexiunii**: Mode 3 pentru Bluetooth, Mode 4 pentru Bluetooth LE. În orice alt mod, o scanare Bluetooth LE nu îl găsește.\n- **Prin Bluetooth**, LiNK500MP se asociază ca două porturi seriale și doar unul transportă CAT. Dacă stația tace, alegeți-l pe celălalt.',
			'settings.station.lab599TroubleshootingIos' => 'Gama TX-500 folosește CAT Kenwood. Frecvența și modul au fost testate printr-un LiNK500MP; puterea și instrumentele sunt scrise după referința CAT de la Lab599, așa că raportați ce se întâmplă în orice caz.\n\n- **Setați LiNK500MP pe Mode 4**, modul lui Bluetooth LE, înainte de a-l căuta. În orice alt mod, un iPhone sau iPad nu îl poate găsi.\n- **Predați controlul CAT către LiNK500MP**: apăsați lung butonul VFO al stației cam trei secunde.\n- **Alegeți protocolul CAT pe stație.** TS-2000 acoperă frecvența, modul și puterea. LAB599 permite în plus aplicației să treacă stația pe DIG, să vadă că emite în DIG și să citească tensiunea de alimentare.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Dacă stația radio se conectează, dar nu afișează frecvența',
			'settings.station.kenwoodTroubleshooting' => 'Acest driver este verificat pe TS-590SG și TS-480 de la Kenwood, QMX și QCX-mini de la QRP Labs și KX2 și KX3 de la Elecraft. Restul gamei este scris după referințe CAT publicate, așa că raportați ce se întâmplă în orice caz.\n\nDacă stația nu răspunde, aproape întotdeauna este una dintre:\n\n- **Viteza trebuie să corespundă** cu meniul CAT al stației. La nepotrivire, stația trimite înapoi date fără sens sau nimic, niciodată o eroare.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.\n- **Unele stații necesită activarea CAT** în meniu înainte de a răspunde.\n- **Stațiile Kenwood așteaptă RTS**: portul lor CAT îl folosește ca handshake, așa că „Menține RTS activ” (din Setări avansate) trebuie să fie pornit. O conexiune configurată înainte ca această opțiune să fie pornită implicit poate să o aibă oprită. Pe un Digirig sau alt cablu care comandă PTT din RTS, opriți-o, altfel stația emite.\n\n**Mai multe front-end-uri SDR folosesc același protocol**, deci merită încercată această intrare și pentru ele; stațiile Elecraft sunt listate separat, la Elecraft. Dacă frecvența este corectă, dar modul este greșit sau lipsește, aceasta este singura parte care diferă în gamă — aplicația îl deduce din stație și revine la o interogare directă, deci modul poate doar să apară cu întârziere.',
			'settings.station.statusConnected' => 'Conectat',
			'settings.station.statusLost' => 'Deconectat',
			'settings.station.notConfigured' => 'Neconfigurat',
			'settings.station.currentConfiguration' => 'Configurația curentă',
			'settings.station.currentTransceiver' => 'Transceiver curent',
			'settings.station.currentTransceivers' => 'Transceivere curente',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => 'Mesajele se pun în coadă în loc să întrerupă',
			'settings.station.noRadioBSelected' => 'Niciun Radio B selectat',
			'settings.station.radioMode' => 'Modul stației',
			'settings.station.keyerNotSupported' => 'Nu este acceptat de stația curentă',
			'settings.station.catControlPreferences' => 'Preferințe control CAT',
			'settings.station.chooseTransceiver' => 'Alegeți transceiverul',
			'settings.station.configurationSection' => 'Configurație',
			'settings.station.noTransceiverSelected' => 'Niciun transceiver selectat',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Folosește ${name} pentru VFO principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, zero: 'Niciun transceiver', one: '${count} transceiver', other: '${count} transceivere', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} antenă', other: '${count} antene', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} alt dispozitiv', other: '${count} alte dispozitive', ), 
			'settings.station.equipmentInventory' => 'Inventar echipamente',
			'settings.station.equipmentInUse' => 'Controale transceiver',
			'settings.station.noTransceiver' => 'Niciunul',
			'settings.station.peerRadioNotAvailable' => 'Indisponibil',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Pe ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} este pe alt dispozitiv',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Această stație radio este conectată la ${device}. Conexiunea și setările ei se configurează pe acel dispozitiv.',
			'settings.station.antennaInUse' => 'Antena folosită',
			'settings.station.keyInUse' => 'Manipulare CW',
			'settings.station.phoneKeying' => 'Keyer fonie',
			'settings.station.phoneKeyingNone' => 'Niciunul',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => 'Memoriile din ${radio}',
			'settings.station.phoneKeyingComputer' => 'Audio din acest calculator',
			'settings.station.phoneKeyingOff' => 'Keyer-ul fonie este oprit',
			'settings.station.computerVoiceSettings' => 'Audio calculator',
			'settings.station.cwKeyingOptions' => 'Opțiuni manipulare CW',
			'settings.station.noneSelected' => 'Niciunul',
			'settings.station.moreSettings' => 'Mai multe setări',
			'settings.station.icomCivTroubleshootingTitle' => 'Dacă apar două porturi seriale pentru aceeași stație',
			'settings.station.icomCivTroubleshooting' => 'Mai multe stații Icom, printre care IC-705, prezintă **două** porturi seriale USB simultan (Icom le numește Port A și Port B), ambele setate implicit pe CI-V. Nici aplicația, nici sistemul de operare nu le pot deosebi altfel: același ID USB de producător/produs apare de două ori, uneori marcat aici cu sufixul `#2`. **Port A este de obicei cel corect** — în mod normal primul listat de sistem sau de browser, iar acolo unde aplicația poate deosebi cele două porturi îl marchează ca sugerat. Dacă comenzile pleacă și stația nu răspunde niciodată, încercați celălalt port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Dacă stația radio nu răspunde niciodată',
			'settings.station.civAddressTroubleshooting' => '- **Adresa CI-V trebuie să corespundă** cu meniul stației. Această intrare completează adresa cu care vine modelul, dar o stație care împarte o magistrală CI-V este exact cazul în care aceasta se schimbă. Un cadru trimis la adresa greșită este ignorat în tăcere, ceea ce arată exact ca un cablu defect.\n- **Viteza trebuie să corespundă** cu CI-V BAUD RATE al stației (pe USB, CI-V USB Baud Rate). Setați stația la același număr afișat aici, **nu pe Auto**. Pe Auto, unele stații, printre care IC-7300, se conectează și apoi nu mai răspund după aproximativ un minut.\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **Adresa CI-V trebuie să corespundă** cu meniul stației. Această intrare completează adresa cu care vine modelul, dar o stație care împarte o magistrală CI-V este exact cazul în care aceasta se schimbă. Un cadru trimis la adresa greșită este ignorat în tăcere, ceea ce arată exact ca un cablu defect.\n${speed}\n- **Altă aplicație poate ține portul ocupat**: WSJT-X, fldigi și rigctld îl țin toate deschis.',
			'settings.station.icomUsbSpeedFollows' => '- **Nu există o viteză de setat.** Prin USB, această stație vorbește la viteza folosită de calculator, iar această intrare folosește întotdeauna 115200, viteza de care are nevoie scope-ul.',
			'settings.station.ic7610UsbSpeed' => '- **Setați CI-V USB Baud Rate la 115200**, viteza pe care această intrare o folosește întotdeauna, deoarece scope-ul are nevoie de ea — **nu pe Auto**. O stație setată pe orice altă viteză răspunde cu tăcere.',
			'settings.station.civTransceiveTitle' => 'Dacă aplicația urmărește stația radio cu întârziere',
			'settings.station.civTransceive' => 'Dacă aplicației îi iau câteva secunde să afișeze o schimbare de frecvență sau de mod făcută pe stație, porniți setarea **CI-V Transceive** a stației (pe majoritatea modelelor actuale, la SET > Connectors > CI-V). Cu ea pornită, stația raportează fiecare schimbare în momentul în care are loc. Cu ea oprită, aplicația vede o schimbare doar la următoarea interogare, la câteva secunde.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** vine cu adresa `B6`, nu `94` completată aici — alegeți în schimb intrarea IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- **IC-705** prezintă două porturi seriale USB, ambele numite după stație. CI-V este pe **primul** dintre ele, pe care selectorul îl indică ori de câte ori le poate deosebi.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** folosește CI-V pe **Port A** dintre cele două porturi seriale USB pe care le prezintă.',
			'settings.station.x6100PortNote' => '\n- **X6100** folosește CI-V pe portul **DEV** — al doilea dintre cele două porturi seriale pe care le prezintă și cel indicat de selector.',
			'settings.station.rigctldTroubleshootingTitle' => 'Dacă aplicația nu se poate conecta',
			'settings.station.rigctldTroubleshooting' => 'Aceasta se conectează la un **daemon rigctld pe care îl rulați singuri**, nu direct la stația radio — backend-ul Hamlib comunică cu stația și acceptă sute de modele.\n\n- **Daemonul trebuie să ruleze deja**, de ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Aflați numărul de model al stației cu `rigctl -l`.\n- **De pe alt calculator**, porniți-l cu `-T 0.0.0.0`: implicit rigctld acceptă conexiuni doar de pe calculatorul pe care rulează.\n- **Portul** este 4532, dacă nu ați pornit daemonul cu `-t`.\n- După conectare, o frecvență lipsă înseamnă de obicei că daemonul însuși nu poate accesa stația. Testați-l cu `rigctl -m 2 f` pe calculatorul daemonului.',
			'settings.station.flrigTroubleshootingTitle' => 'Dacă aplicația nu se poate conecta',
			'settings.station.flrigTroubleshooting' => 'Aceasta se conectează la un **program flrig pe care îl rulați singuri**, nu direct la stația radio — flrig comunică cu stația și acceptă majoritatea mărcilor și modelelor.\n\n- **flrig trebuie să ruleze deja**, cu transceiverul configurat și conectat.\n- **Portul** este 12345, dacă nu l-ați schimbat în configurația flrig (Config → Setup → Server).\n- **De pe alt calculator**, asigurați-vă că serverul flrig este accesibil. Ascultă pe toate interfețele, dar firewall-ul poate să nu fie de acord.\n- După conectare, o frecvență lipsă înseamnă de obicei că flrig însuși nu poate accesa stația. Verificați că afișajul flrig urmărește butonul de acord.',
			'settings.station.hrdTroubleshootingTitle' => 'Dacă aplicația nu se poate conecta',
			'settings.station.hrdTroubleshooting' => 'Aceasta se conectează la **Rig Control din Ham Radio Deluxe, care rulează pe calculatorul dvs.**, nu direct la stația radio — HRD comunică cu stația.\n\n- **Rig Control trebuie să ruleze deja** și să fie conectat la stație.\n- **Serverul IP al acestuia trebuie să fie activat.** Rig Control comunică cu alte programe doar prin el.\n- **Portul** este 7809, dacă nu l-ați schimbat în setările serverului IP.\n- **De pe alt calculator**, asigurați-vă că firewall-ul permite conexiunea.\n\nAceastă intrare a fost scrisă după descrieri publicate ale protocolului HRD și nu a fost testată cu HRD. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Dacă aplicația nu se poate conecta',
			'settings.station.n3fjpTroubleshooting' => 'Aceasta se conectează la **un program de log N3FJP care rulează pe calculatorul dvs.**, nu direct la stația radio — N3FJP comunică cu stația.\n\n- **API-ul programului trebuie să fie activ**: Settings → Application Program Interface, bifați **TCP API Enabled**.\n- **Portul** este 1100, dacă nu l-ați schimbat acolo.\n- **N3FJP trebuie să aibă configurată o interfață radio** pentru a urmări sau acorda stația. Fără una, raportează doar ce se tastează în fereastra de introducere.\n- N3FJP raportează doar banda, modul și frecvența: fără putere, fără starea de emisie.\n\nAceastă intrare a fost scrisă după API-ul publicat de N3FJP și nu a fost testată cu N3FJP. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.commanderTroubleshootingTitle' => 'Dacă aplicația nu se poate conecta',
			'settings.station.commanderTroubleshooting' => 'Aceasta se conectează la **DXLab Commander, care rulează pe calculatorul dvs.**, nu direct la stația radio — Commander comunică cu stația.\n\n- **Commander trebuie să ruleze deja** și să fie conectat la stație.\n- **Serviciul de rețea trebuie să fie activ**: butonul **Net Serv** din panoul Radio al ferestrei Configuration din Commander.\n- **Portul** este 52002, al treilea port din blocul care începe la **Base Port** din Net Serv (52000, dacă nu l-ați schimbat).\n- **De pe alt calculator**, asigurați-vă că firewall-ul permite conexiunea.\n\nAceastă intrare a fost scrisă după mesajele TCP publicate de Commander și nu a fost testată cu Commander. Dacă funcționează pe jumătate, merită raportat.',
			'settings.station.ic705TroubleshootingTitle' => 'Dacă stația radio nu răspunde niciodată',
			'settings.station.ic705Troubleshooting' => 'Stația are o **singură** sesiune de control la distanță. Când autentificarea este ignorată, aproape întotdeauna altceva o folosește.\n\n- **Închideți orice alt client.** wfview sau RS-BA1 conectat la aceeași stație ocupă acea sesiune, iar autentificarea de aici este pur și simplu ignorată cât timp o face.\n- **Verificați setările de rețea ale stației.** WLAN trebuie să fie activ, stația trebuie să fie în aceeași rețea, iar funcția de control la distanță (Network) trebuie să fie activată.\n- **Porturile trebuie să corespundă** cu Control Port și Serial Port (UDP) ale stației sau cu porturile redirecționate către ele. Un port greșit este întâmpinat cu tăcere, la fel ca o stație oprită.\n- **Reporniți WLAN-ul stației** dacă rămâne blocată. Aceasta eliberează sigur o sesiune blocată pe stație.\n\nO **parolă greșită este refuzată explicit**, nu întâmpinată cu tăcere. Dacă ați ajuns aici în loc de un mesaj „respins”, parola nu este problema.',
			'settings.station.icomLanTroubleshooting' => 'Stația are o **singură** sesiune de control la distanță. Când autentificarea este ignorată, aproape întotdeauna altceva o folosește.\n\n- **Închideți orice alt client.** wfview, RS-BA1 sau Remote Utility de la Icom conectat la aceeași stație ocupă acea sesiune, iar autentificarea de aici este pur și simplu ignorată cât timp o face.\n- **Verificați setările de rețea ale stației.** Portul ei LAN trebuie să fie conectat la aceeași rețea ca acest dispozitiv, **Network Control** trebuie să fie activat, iar numele de utilizator și parola trebuie să fie configurate ca utilizator de rețea pe stație.\n- **Porturile trebuie să corespundă** cu Control Port și Serial Port (UDP) ale stației sau cu porturile redirecționate către ele. Un port greșit este întâmpinat cu tăcere, la fel ca o stație oprită.\n- **Dacă se conectează, dar nu răspunde niciodată**, adresa CI-V de aici trebuie să corespundă cu meniul CI-V ADDRESS al stației. Această intrare completează adresa cu care vine modelul.\n- **Opriți și reporniți stația** dacă rămâne blocată.',
			'settings.station.statusStale' => 'Nu răspunde',
			'settings.station.statusDisconnected' => 'Neconectat',
			'settings.station.statusConnecting' => 'Se conectează…',
			'settings.station.statusDisconnecting' => 'Se deconectează…',
			'settings.station.statusError' => 'Conectarea a eșuat',
			'settings.station.currentRadioSettings' => 'Setările curente ale stației',
			'settings.station.notSupportedByThisRadio' => 'Nu este acceptat de această stație',
			'settings.station.cwMessagesButton' => 'Mesaje CW',
			'settings.station.voiceMessagesButton' => 'Mesaje fonie',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Keyer vocal: ${count} memorii în stație',
			'settings.station.antennaBands' => 'Benzi',
			'settings.station.antennaType' => 'Tip de antenă',
			'settings.station.antennaTypeRequired' => 'Alegeți un tip de antenă',
			'settings.station.antennaTypes.dipole' => 'Dipol',
			'settings.station.antennaTypes.vertical' => 'Verticală',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Buclă',
			'settings.station.antennaTypes.longWire' => 'Long Wire / EFHW',
			'settings.station.antennaTypes.other' => 'Alta',
			'settings.station.keyType' => 'Tip de manipulator',
			'settings.station.keyTypeRequired' => 'Alegeți un tip de manipulator',
			'settings.station.keyTypes.straight' => 'Manipulator clasic',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semiautomat mecanic)',
			'settings.station.keyTypes.fullyAutomatic' => 'Keyer complet automat',
			'settings.station.keyTypes.singlePaddle' => 'Paletă simplă',
			'settings.station.keyTypes.dualPaddle' => 'Paletă dublă',
			'settings.station.keyTypes.computerDriven' => 'Comandat de calculator',
			'settings.station.keyTypes.other' => 'Altul',
			'settings.station.softwareIntermediaries' => 'Intermediari software',
			'settings.station.otherBrands' => 'Alte mărci',
			'settings.station.otherEquipment' => 'Alte echipamente (antene, manipulatoare etc.)',
			'settings.station.newAntenna' => 'Antenă nouă',
			'settings.station.newKey' => 'Manipulator nou',
			'settings.station.newKeyer' => 'WinKeyer (K1EL sau compatibil)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Keyer CAT în ${radio}',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyOnDevice' => ({required Object device}) => 'Manipulator pe ${device}',
			'settings.station.trackStationInfo' => 'Înregistrează informațiile stației la fiecare QSO',
			'settings.station.includeStationInfoInAdif' => 'Include în exporturile ADIF',
			'settings.station.whatToTrack' => 'Ce se înregistrează?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Putere',
			'settings.station.watts' => 'Wați',
			'settings.station.trackFieldAntenna' => 'Antenă',
			'settings.station.trackFieldKey' => 'Manipulator CW',
			'settings.station.placeholderConnectDelay' => 'Întârziere la conectare (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Cât durează handshake-ul simulat. Gol sau 0 se conectează instantaneu.',
			'settings.station.placeholderDropAfter' => 'Deconectare după (secunde)',
			'settings.station.placeholderDropAfterDescription' => 'Închide conexiunea singură, pentru a testa reconectarea. Gol sau 0 nu deconectează niciodată.',
			'settings.station.placeholderFailConnect' => 'Eșuează mereu la conectare',
			'settings.station.placeholderConnectFailure' => 'Stația substituent a fost instruită să refuze această conexiune',
			'settings.station.placeholderFreq' => 'Frecvență (kHz)',
			'settings.station.placeholderFreqDescription' => 'Unde pornește stația substituent. Ulterior raportează orice frecvență setează aplicația.',
			'settings.station.placeholderMode' => 'Mod',
			'settings.station.placeholderModeDescription' => 'Modul în care pornește stația substituent, de ex. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Putere (wați)',
			'settings.station.placeholderPurpose' => 'Folosiți această stație pentru a ține evidența aparatului folosit, în scopul înregistrării',
			'settings.station.placeholderReplyDelay' => 'Întârziere la răspuns (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Cât îi ia stației substituent să raporteze o schimbare. Gol sau 0 răspunde imediat.',
			'settings.station.cwKeyerField' => 'Keyer CW prin CAT',
			'settings.station.cwKeyerFieldDescription' => 'Dacă această stație manipulează CW din text prin CAT. Dezactivat pentru o stație pe care aplicația nu o cunoaște.',
			'settings.station.voiceMemories' => 'Memorii vocale',
			'settings.station.voiceMemoriesDescription' => 'Câte memorii vocale redă stația prin CAT. 0 pentru niciuna.',
			'settings.station.voiceMemoriesInvalid' => 'Un număr întreg, 0 sau mai mare',
			'settings.station.yaesuMeterCapture' => 'Capturează citirile instrumentelor',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Citește instrumentul de putere de ieșire și indicatorul de SWR ridicat în timpul emisiei și scrie valorile brute în jurnalul de diagnostic. Pentru construirea scalei pe care Yaesu nu o publică — valorile nu sunt afișate ca instrumente.',
			'settings.station.yaesuMeterCaptureDescription' => 'Citește instrumentele PO, SWR și ALC ale stației în timpul emisiei și scrie valorile brute în jurnalul de diagnostic. Pentru construirea scalei pe care Yaesu nu o publică — valorile nu sunt afișate ca instrumente.',
			'settings.station.telemetryInterval' => 'Interval de citire a instrumentelor (ms)',
			'settings.station.telemetryIntervalDescription' => 'Cât de des se citesc instrumentele stației în timpul emisiei. Lăsați gol pentru cea mai mare viteză suportată de conexiune, până la 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Un număr întreg de milisecunde, de la ${min} la ${max}',
			'settings.station.pollInterval' => 'Interval de interogare în repaus (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Cât de des se cer stației frecvența și modul cât timp niciunul nu se schimbă. Lăsați gol pentru ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Un număr întreg de milisecunde, de la ${min} la ${max}',
			'settings.station.advancedSettings' => 'Setări avansate',
			'settings.station.placeholderSwr' => 'Valoare SWR',
			'settings.station.placeholderSwrDescription' => 'Ce raportează această stație pe instrumentul SWR în timpul emisiei. Peste 1.8 panoul avertizează.',
			'settings.station.placeholderSwrInvalid' => 'Un număr, 1 sau mai mare',
			'settings.station.keyerNone' => 'Niciunul',
			'settings.station.cwDialect' => 'Dialect de manipulare CW',
			'settings.station.cwDialectDescription' => 'Ce formă a comenzii KY acceptă această stație. Niciunul înseamnă fără manipulare CW prin CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, completat la 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (text KY)',
			'settings.station.voiceDialect' => 'Dialect de keyer vocal',
			'settings.station.voiceDialectDescription' => 'Cum redă această stație memoriile vocale prin CAT. Niciunul înseamnă fără memorii vocale prin CAT. Cu un dialect și fără număr, se aplică numărul implicit al dialectului.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, stil TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB și DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (apăsări de butoane)',
			'settings.station.placeholderDiagnostic' => 'Simulat',
			'settings.station.placeholderWholeNumberInvalid' => 'Trebuie să fie un număr întreg, 0 sau mai mare',
			'settings.station.placeholderFreqInvalid' => 'Trebuie să fie o frecvență în kHz, mai mare decât zero',
			'settings.station.placeholderModeInvalid' => 'Trebuie să fie un nume de mod, de ex. USB, CW, FT8',
			'settings.station.switchLayout' => 'Configurație',
			'settings.station.switchLayoutDescription' => 'Pe ce parte a comutatorului sunt conectate stațiile radio.',
			'settings.station.switchLayoutRequired' => 'Alegeți cum este cablat comutatorul',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Comutatorul a refuzat "${command}" (eroare ${code})',
			'settings.station.switchBusyTransmitting' => 'Acel port este pe emisie — antena nu a fost schimbată',
			'settings.station.switchNoAntenna' => 'Niciuna',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antena de pe portul ${port}',
			'settings.station.switchAntennaForDescription' => 'Care dintre antenele dvs. este conectată la acest port al comutatorului.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antene, ${radios} stații radio',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antene, 1 stație radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antenă, ${radios} stații radio',
			'settings.station.switchCommonPort' => 'Comun',
			'settings.station.dcnAddress' => 'Adresa dispozitivului',
			'settings.station.dcnAddressDescription' => 'Adresa setată pe comutatoarele DIP ale modulului. Un modul releu coaxial vine din fabrică setat pe 2.',
			'settings.station.dcnAddressRequired' => 'Trebuie să fie o adresă de dispozitiv între 1 și 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Portul ${port}',
			'settings.station.switchPortAutoHint' => 'urmează datele de bandă',
			'settings.station.switchPortTransmittingHint' => 'pe emisie — nu se poate schimba acum',
			'settings.station.switchCurrentStateHeader' => 'Starea curentă',
			'settings.station.switchCurrentStateDescription' => 'Pe ce antenă este acum fiecare port de stație. Modificările se aplică imediat.',
			'settings.station.switchWiringHeader' => 'Cablare',
			'settings.station.switchPortInhibitedHint' => 'emisie blocată',
			'settings.station.rotatorAxes' => 'Axe',
			'settings.station.rotatorAxesDescription' => 'Dacă rotorul se rotește doar în azimut sau și în elevație (un G-5500 sau similar).',
			'settings.station.rotatorAxesAzimuth' => 'Doar azimut',
			'settings.station.rotatorAxesAzimuthElevation' => 'Azimut și elevație',
			'settings.station.rotatorAzimuthOffset' => 'Decalaj de azimut',
			'settings.station.rotatorAzimuthOffsetDescription' => 'Grade de adăugat la ce citește controlerul, când zeroul lui nu este nordul adevărat. Rotirile sunt corectate corespunzător.',
			'settings.station.rotatorElevationOffset' => 'Decalaj de elevație',
			'settings.station.rotatorAzimuthMin' => 'Azimut minim',
			'settings.station.rotatorAzimuthMax' => 'Azimut maxim',
			'settings.station.rotatorAzimuthMaxDescription' => 'În gradele proprii ale controlerului. Peste 360 pentru un rotor cu suprapunere, care alege apoi rotirea mai scurtă.',
			'settings.station.rotatorElevationMin' => 'Elevație minimă',
			'settings.station.rotatorElevationMax' => 'Elevație maximă',
			'settings.station.rotatorElevationMaxDescription' => 'În gradele proprii ale controlerului. Peste 90 pentru un rotor care poate trece peste zenit.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => 'Grade întregi, de la ${min} la ${max}',
			'settings.station.rotatorLimitsInvalid' => 'Limita minimă trebuie să fie sub cea maximă',
			'settings.station.rotatorPollInterval' => 'Interval de interogare (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'Cât de des se întreabă rotorul încotro arată. Lăsați gol pentru ${fallback} ms.',
			'settings.station.rotatorAxesRequired' => 'Alegeți pe ce axe se rotește rotorul',
			'settings.station.rotatorRefused' => 'Controlerul a refuzat o comandă. Verificați că este setat în modul GS-232.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator răspunde doar după ce este configurat pentru asta, altfel nu spune absolut nimic:\n\n- **Activați UDP Control** din meniul Setup al PstRotator.\n- **Potriviți portul**: Communication → UDP Control Port, 12000 dacă nu a fost schimbat. PstRotator răspunde pe portul imediat următor (12001), care trebuie să fie liber pe acest dispozitiv.\n- **Conectați PstRotator la controlerul lui.** Până atunci, nu răspunde nimic prin UDP.\n- **Permiteți-l prin firewall** pe PC-ul care rulează PstRotator și pe acest dispozitiv, care ascultă răspunsurile.\n- **Pe un Mac, iPhone sau iPad**, Ham2K Logger are nevoie de acces la rețeaua locală (Settings → Privacy & Security → Local Network).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => 'Starea curentă: ${position}',
			'settings.station.rotatorDisconnected' => 'deconectat',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '${degrees}° azimut',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '${degrees}° az',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '${degrees}° elevație',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '${degrees}° el',
			'settings.station.rotatorNoReading' => 'Se așteaptă ca controlerul să raporteze poziția…',
			'settings.station.rotatorNotResponding' => 'nu răspunde',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => 'Se rotește spre ${heading}, cât permit limitele acestui rotor',
			'settings.station.rotatorTargetAzimuth' => 'Rotește la azimutul',
			'settings.station.rotatorTargetAzimuthShort' => 'Rotește la az',
			'settings.station.rotatorTargetElevation' => 'Rotește la elevația',
			'settings.station.rotatorTargetElevationShort' => 'Rotește la el',
			'settings.station.rotatorAzimuthInvalid' => 'Trebuie să fie între 0 și 360',
			'settings.station.rotatorElevationInvalid' => 'Trebuie să fie între 0 și 180',
			'settings.station.rotatorTurn' => 'Rotește',
			'settings.station.rotatorStop' => 'Stop',
			'settings.station.configUnreadable' => 'Setările salvate ale acestei stații nu au putut fi citite. Deschideți setările și introduceți-le din nou sau eliminați-o și adăugați-o din nou.',
			'settings.station.autoConnectHeld' => 'HaLo a încetat să răspundă ultima dată când s-a conectat la această stație, așa că de data aceasta nu s-a conectat singur. Apăsați Conectează pentru a încerca din nou.',
			'settings.offlineData.title' => 'Date offline',
			'settings.offlineData.noFiles' => 'Niciun fișier de date',
			'settings.offlineData.noFilesDescription' => 'Activați extensii de activitate sau de căutare pentru a le descărca aici datele offline.',
			'settings.offlineData.refresh' => 'Reîmprospătează',
			'settings.offlineData.refreshing' => 'Se reîmprospătează…',
			'settings.offlineData.updateAll' => 'Actualizează tot',
			'settings.offlineData.updatingAll' => 'Se actualizează toate fișierele de date…',
			'settings.offlineData.neverDownloaded' => 'Nedescărcat niciodată',
			'settings.offlineData.updatedJustNow' => 'Actualizat chiar acum',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Actualizat acum ${days}z',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Actualizat acum ${days}z ${hours}h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Actualizat acum ${hours}h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Actualizat acum ${hours}h ${minutes}min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Actualizat acum ${minutes}min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Ultima descărcare avea doar ${imported} din ${existing} înregistrări și nu a fost folosită. Reîmprospătați pentru a o accepta.',
			'settings.offlineData.extensionsSection' => 'Extensii',
			'settings.profiles.notSet' => 'Nesetat',
			'settings.profiles.personalInfo' => 'Informații personale',
			'settings.profiles.personalInfoNote' => 'Acestea pot fi incluse în jurnalele generate când sunt relevante pentru trimiteri',
			'settings.profiles.name' => 'Nume',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'Secțiune ARRL',
			'settings.profiles.racSection' => 'Secțiune RAC',
			'settings.profiles.section' => 'Secțiune',
			'settings.search.clear' => 'Golește',
			'settings.search.hint' => 'Căutați în preferințe',
			'settings.developer.developerModeDescription' => 'Activează avertismentele pentru dezvoltatori, jurnalele de depanare și instrumentele.',
			'settings.developer.experiments' => 'Experimente',
			'settings.developer.showIdleMetrics' => 'Afișează metricile de inactivitate',
			'settings.developer.showIdleMetricsDescription' => 'Afișează în bara de stare cât de inactiv a fost motorul de extensii în ultima secundă. Atingeți pentru mediile pe 10 și 60 de secunde.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% inactiv',
			'settings.developer.idleMetricsAverages' => 'Medie inactivitate:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} activat', other: '${count} activate', ), 
			'settings.developer.patchTrack' => 'Canal Code Push',
			'settings.developer.patchTrackDescription' => 'Ce canal de actualizări de cod over-the-air urmează acest dispozitiv. Canalele mai îndrăznețe primesc remedieri mai devreme, mai puțin testate. Actualizările de cod se aplică la următoarea repornire.',
			'settings.developer.trackStable' => 'Stabil',
			'settings.developer.trackUnstable' => 'Instabil',
			'settings.developer.trackBleeding' => 'În dezvoltare',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Se caută o actualizare de cod pe „${track}”…',
			'settings.developer.patchDownloaded' => 'Actualizarea de cod a fost descărcată — reporniți aplicația pentru a o aplica.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Nicio actualizare de cod nouă pe „${track}”.',
			'settings.developer.noPatchInstalled' => 'Nicio actualizare de cod instalată — rulează binarul lansat.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Rulează actualizarea de cod #${patch}.',
			'settings.developer.deepLinks' => 'Linkuri directe',
			'settings.developer.registerUrlSchemes' => 'Înregistrează schemele URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permite linkurilor com.ham2k:// să deschidă această copie a aplicației',
			'settings.developer.registerUrlSchemesDone' => 'Această copie deschide acum linkurile com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Înregistrarea nu a reușit: ${error}',
			'settings.developer.systemInformation' => 'Informații sistem',
			'settings.developer.appVersion' => 'Versiunea aplicației',
			'settings.developer.dataFolder' => 'Dosarul de date',
			'settings.developer.loading' => '(se încarcă…)',
			'settings.developer.panelLoadFailed' => 'Acest panou de setări nu a putut fi încărcat.',
			'settings.developer.extDevServer' => 'Server de dezvoltare extensii',
			'settings.developer.extensionSettings' => 'Setări extensii',
			'settings.developer.extDevServerDescription' => 'Încarcă extensiile de pe un server de dezvoltare din rețeaua dvs. în locul celor integrate în aplicație și le reîncarcă la fiecare salvare.',
			'settings.developer.extDevServerAddress' => 'Adresa serverului',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Conectează',
			'settings.developer.extDevServerDisconnect' => 'Deconectează',
			'settings.developer.extDevServerConnecting' => 'Se conectează…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Se servește ${count} extensie: ${keys}', other: 'Se servesc ${count} extensii: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Neconectat',
			'settings.developer.extDevServerReconnect' => 'Reconectare la pornire',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Ultima reîncărcare: ${key} la ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} extensie nu se compilează', other: '${count} extensii nu se compilează', ), 
			'settings.developer.catalog' => 'Catalog de extensii',
			'settings.developer.catalogDescription' => 'Citește catalogul de pe alt server — unul local în timp ce lucrați la catalogul însuși. Gol înseamnă catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Adresa catalogului',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Canale de căutare în catalog',
			'settings.developer.catalogSearchStable' => 'Doar stabile',
			'settings.developer.catalogSearchUnstable' => 'Instabile sau mai bune',
			'settings.developer.catalogSearchBleeding' => 'În dezvoltare sau mai bune',
			'settings.about.notices' => 'Notificări și mesaje',
			'settings.about.noticesDescription' => 'Anunțuri și mesaje de stare',
			'settings.about.releaseNotes' => 'Note de versiune',
			'settings.about.copiedVersion' => 'Detaliile versiunii au fost copiate în clipboard',
			'settings.panels.settings' => 'Preferințele aplicației',
			'settings.panels.settingsDescription' => 'Faceți aplicația să funcționeze cum doriți',
			'settings.panels.commonSettings' => 'Preferințe comune',
			'settings.panels.syncDescription' => 'Backup și sincronizarea jurnalelor pe toate dispozitivele',
			'settings.panels.accountsDescription' => 'Date de acces la servicii, date offline și altele',
			'settings.panels.extensions' => 'Extensii și funcții',
			'settings.panels.extensionsDescription' => 'Activități, concursuri, panouri de bord și alte funcții',
			'settings.panels.profilesDescription' => 'Indicativul operatorului și profilul stației',
			'settings.panels.stationProfiles' => 'Profiluri de stație',
			'settings.panels.developerSettings' => 'Setări pentru dezvoltatori',
			'settings.panels.developerSettingsDescription' => 'Instrumente de depanare și dezvoltare',
			'settings.panels.about' => 'Despre',
			'settings.panels.aboutDescription' => 'Versiune, credite și informații legale',
			'settings.panels.unavailableTitle' => 'Unele setări nu sunt disponibile',
			'settings.panels.unavailableText' => 'Mediul de rulare a extensiilor nu a pornit, deci setările oferite de extensii lipsesc.',
			'settings.panels.station' => 'Configurația stației',
			'settings.panels.stationDescription' => 'Control CAT și alte opțiuni',
			'settings.panels.peers' => 'Dispozitive pereche',
			'settings.panels.peersDescription' => 'Conectare la alte dispozitive din apropiere',
			'settings.showMoreSettings' => 'Afișează mai multe setări',
			'settings.gridPrecision' => 'Precizia grilei',
			'settings.gridPrecisionOpts.six' => '6 caractere (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 caractere (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 caractere',
			'settings.gridPrecisionDescription.eight' => '8 caractere',
			'commands.enableSyncFirst' => 'Activați mai întâi sincronizarea în Setări.',
			'commands.fullResyncStarted' => 'Resincronizarea completă a început — mai întâi s-a făcut o copie de rezervă a datelor locale.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Niciun fișier de date nu corespunde cu „${target}”.',
			'commands.reloadFailed' => ({required Object error}) => 'Reîncărcarea a eșuat: ${error}',
			'commands.reloadingAll' => 'Se reîncarcă toate fișierele de date…',
			'commands.reloadingTarget' => ({required Object target}) => 'Se reîncarcă fișierele de date ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experiment necunoscut „${token}”',
			'commands.experimentEnabled' => ({required Object name}) => '${name} activat',
			'commands.experimentDisabled' => ({required Object name}) => '${name} dezactivat',
			'commands.sentryTestSent' => 'Raportul de eroare de test a fost trimis la Sentry',
			'commands.idleMetricsEnabled' => 'Metricile de inactivitate sunt activate în bara de stare',
			'commands.idleMetricsDisabled' => 'Metricile de inactivitate sunt dezactivate',
			'commands.sentryTestLocalOnly' => 'Sentry este dezactivat în această versiune — eroarea de test a fost înregistrată doar local',
			'commands.noOperationOpen' => 'Această comandă necesită o operațiune deschisă',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Nu se știe cum se marchează „${kind}”',
			'commands.goUnavailable' => ({required Object place}) => 'Funcția ${place} nu este activată în această aplicație',
			'commands.goUnknown' => ({required Object to}) => 'Nu se știe cum se ajunge la „${to}”',
			'commands.goBlocked' => 'Închideți mai întâi dialogul deschis',
			'commands.operationAlreadyStarted' => 'Această operațiune are deja un marcaj de început',
			'commands.couldNotOpenLocation' => 'Pauza a fost adăugată, dar ecranul de locație nu a putut fi deschis',
			'commands.noTestOperations' => 'Nicio operațiune de test de eliminat',
			'commands.purgeTestsUnavailable' => 'PURGETESTS trebuie să afișeze un dialog de confirmare, care nu este disponibil aici',
			'commands.syncAllUnavailable' => 'SYNCALL trebuie să afișeze un dialog de confirmare, care nu este disponibil aici',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'A fost eliminată ${count} operațiune de test', other: 'Au fost eliminate ${count} operațiuni de test', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Au fost eliminate ${purged} din ${total} operațiuni de test — restul au eșuat; încercați din nou PURGETESTS',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'A fost eliminat ${count} contact de test fără operațiune', other: 'Au fost eliminate ${count} contacte de test fără operațiune', ), 
			'commands.purgeTestsContactsFailed' => 'Operațiunile de test au fost eliminate, dar contactele de test fără operațiune au eșuat; încercați din nou PURGETESTS',
			'commands.purgeTestsNothingToDo' => 'Nu a fost eliminat nimic',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Au fost eliminate ${removed} din ${total} operațiuni de test — restul au eșuat; încercați din nou Revizuiește',
			'commands.receivedPurgesFailed' => 'Acele operațiuni de test nu au putut fi eliminate — încercați din nou Revizuiește',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} operațiune de test a fost eliminată pe alt dispozitiv', other: '${count} operațiuni de test au fost eliminate pe alt dispozitiv', ), 
			'commands.receivedPurgesReview' => 'Revizuiește',
			'commands.settingOn' => 'Pornit',
			'commands.settingOff' => 'Oprit',
			'commands.settingEmpty' => '(gol)',
			'commands.settingSecretSet' => '(setat)',
			'commands.settingSecretUnset' => '(nesetat)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selectate',
			'commands.settingExpectsOnOff' => 'pornit sau oprit',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'una dintre: ${choices}',
			'commands.settingExpectsNumber' => 'un număr',
			'commands.settingVanished' => ({required Object label}) => '„${label}” nu mai este disponibil',
			'commands.noCwKeyer' => 'Nicio stație radio conectată nu poate manipula CW',
			'commands.noKeyer' => 'Nicio stație radio conectată nu poate manipula CW sau reda memorii vocale',
			'commands.keyerNeedsOperation' => 'Deschideți o operațiune pentru a folosi keyer-ul CW',
			'commands.keyerExperimentOff' => 'Manipularea CW este oprită — activați-o cu EXP KEYER',
			'commands.esmExperimentOff' => '„Enter trimite mesaje” este oprit — activați-l cu EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Se transmite CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Mesaj CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'Mesajul CW F${n} nu a fost trimis: extensiile nu sunt pregătite',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => 'Mesaj fonie M${n}: ${error}',
			'commands.voiceMessageNotRendered' => 'extensiile nu sunt pregătite',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => 'Nu s-a trimis nimic: Radio ${radio} nu poate transmite asta',
			'commands.so2rNoRadioB' => 'Nu s-a trimis nimic: alegeți un Radio B în Configurația stației pentru a transmite din acest set',
			'commands.settingNotStored' => ({required Object label}) => '„${label}” nu a acceptat această valoare',
			'commandDialog.hint' => 'Căutați indicative sau tastați o comandă',
			'commandDialog.noResults' => ({required Object text}) => 'Nimic nu corespunde cu „${text}”',
			'commandDialog.sectionCommands' => 'Comenzi',
			'commandDialog.sectionGoTo' => 'Mergi la',
			'commandDialog.sectionOperations' => 'Operațiuni',
			'commandDialog.goHome' => 'Acasă',
			'commandDialog.goSettings' => 'Setări',
			'commandDialog.goNewOperation' => 'Operațiune nouă',
			'commandDialog.runTyped' => ({required Object text}) => 'Rulează „${text}”',
			'commandDialog.sectionSuggestions' => 'Încercați',
			'commandDialog.lookingUp' => 'Se caută indicativul…',
			'commandDialog.blockedByPane' => 'Comenzile nu pot fi folosite cât timp un panou sau un dialog este deschis',
			'keyboardShortcuts.title' => 'Scurtături de tastatură',
			'keyboardShortcuts.description' => 'Personalizați asocierile tastelor',
			'keyboardShortcuts.search' => 'Căutați comenzi și taste',
			'keyboardShortcuts.import' => 'Importă…',
			'keyboardShortcuts.export' => 'Exportă…',
			'keyboardShortcuts.resetAll' => 'Resetează tot',
			'keyboardShortcuts.resetAllTitle' => 'Resetați toate scurtăturile?',
			'keyboardShortcuts.resetAllBody' => 'Fiecare comandă revine la tastele ei implicite, iar tastele asociate comenzilor tastate sunt eliminate.',
			'keyboardShortcuts.reset' => 'Resetează',
			'keyboardShortcuts.noKey' => 'Nicio tastă',
			'keyboardShortcuts.changed' => 'Modificat',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} este asociată și cu ${commands}',
			'keyboardShortcuts.groupApp' => 'Aplicație',
			'keyboardShortcuts.groupKeying' => 'Manipulare',
			'keyboardShortcuts.groupLogging' => 'Înregistrare',
			'keyboardShortcuts.groupCommands' => 'Comenzi',
			'keyboardShortcuts.groupFixed' => 'Taste fixe',
			'keyboardShortcuts.contextApp' => 'Oriunde',
			'keyboardShortcuts.contextLogView' => 'Vizualizările Operațiune, Vânătoare și Jurnale',
			'keyboardShortcuts.contextOperation' => 'Vizualizarea Operațiune, la manipularea unei stații radio prin CAT',
			'keyboardShortcuts.contextLogging' => 'În panoul de înregistrare',
			'keyboardShortcuts.addCommand' => 'Adaugă o comandă…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Comandă necunoscută: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Deschide dialogul de comenzi',
			'keyboardShortcuts.command.toggleTheme' => 'Comută între luminos și întunecat',
			'keyboardShortcuts.command.toggleLanguage' => 'Comută între engleză și spaniolă',
			'keyboardShortcuts.command.fontScaleUp' => 'Text mai mare',
			'keyboardShortcuts.command.fontScaleDown' => 'Text mai mic',
			'keyboardShortcuts.command.fontScaleReset' => 'Dimensiune normală a textului',
			'keyboardShortcuts.command.densityLooser' => 'Aranjament mai aerisit',
			'keyboardShortcuts.command.densityDenser' => 'Aranjament mai dens',
			'keyboardShortcuts.command.densityAuto' => 'Densitate automată a aranjamentului',
			'keyboardShortcuts.command.find' => 'Caută în jurnal',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Trimite mesajul ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Modul tastatură pornit sau oprit',
			'keyboardShortcuts.command.ptt' => 'PTT (apasă pentru a vorbi)',
			'keyboardShortcuts.command.wipe' => 'Golește contactul în curs de înregistrare',
			'keyboardShortcuts.fixed.callsign' => 'Tastarea indicativelor',
			'keyboardShortcuts.fixed.escape' => 'Oprește transmisia, revino un pas sau închide',
			'keyboardShortcuts.fixed.enter' => 'Înregistrează contactul',
			'keyboardShortcuts.fixed.space' => 'Câmpul următor',
			'keyboardShortcuts.fixed.tab' => 'Câmpul următor sau anterior',
			'keyboardShortcuts.fixed.arrows' => 'Deplasare între câmpuri, controale și jurnal',
			'keyboardShortcuts.fixed.walk' => 'Parcurge jurnalul pagină cu pagină sau sari la capetele lui',
			'keyboardShortcuts.fixed.undo' => 'Anulează o golire sau o ștergere',
			'keyboardShortcuts.editor.addShortcut' => 'Adaugă scurtătură',
			'keyboardShortcuts.editor.listening' => 'Apăsați tastele pentru scurtătură…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc oprește ascultarea',
			'keyboardShortcuts.editor.add' => 'Adaugă',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} aparține câmpurilor de înregistrare sau unui dialog și nu poate fi schimbată.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => 'Cu ${keys} se tastează indicativele. Țineți apăsat Cmd, Ctrl sau Alt împreună cu ea.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'Sistemul poate prelua ${keys} înainte ca aplicația să o vadă.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} este deja una dintre tastele acestei comenzi.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Ia ${keys} de la „${command}”',
			'keyboardShortcuts.editor.resetDefault' => 'Resetează la implicit',
			'keyboardShortcuts.editor.remove' => 'Elimină',
			'keyboardShortcuts.editor.commandLabel' => 'Comandă',
			'keyboardShortcuts.editor.commandHint' => 'Introduceți orice comandă validă sau mai multe comenzi separate prin „;”',
			'keyboardShortcuts.editor.removeCommand' => 'Elimină comanda',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'Nicio comandă nu recunoaște „${text}”',
			'keyboardShortcuts.editor.noShortcuts' => 'Nicio tastă încă',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Scurtăturile au fost salvate în ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'Scurtăturile nu au putut fi exportate: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'Fișierul nu a putut fi deschis: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} nu este un fișier de scurtături pe care aplicația îl poate citi: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'textul nu este YAML valid (linia ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'nu este un fișier de scurtături de tastatură Ham2K',
			'keyboardShortcuts.file.problemNewerVersion' => 'a fost scris de o versiune mai nouă a aplicației',
			'keyboardShortcuts.file.problemMalformed' => 'o parte din el nu respectă formatul de scurtături',
			'keyboardShortcuts.file.problemTooLarge' => 'este prea mare',
			'keyboardShortcuts.file.importTitle' => 'Importă scurtături',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Scris pe ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'Fișierul nu spune pe ce tastatură a fost scris.',
			'keyboardShortcuts.file.translate' => 'Ce ar trebui să fie fiecare dintre aceste taste pe această tastatură?',
			'keyboardShortcuts.file.leaveOut' => 'Lasă deoparte acele scurtături',
			'keyboardShortcuts.file.replace' => 'Înlocuiește configurația acestui dispozitiv',
			'keyboardShortcuts.file.replaceHint' => 'Fiecare scurtătură care nu e în fișier revine la valoarea ei implicită.',
			'keyboardShortcuts.file.merge' => 'Adaugă la configurația acestui dispozitiv',
			'keyboardShortcuts.file.mergeHint' => 'Scurtăturile din fișier le înlocuiesc pe cele ale acestui dispozitiv pentru aceleași comenzi, iar restul rămân.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'Necunoscute în această versiune, deci omise: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'Nu sunt scurtături, deci omise: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Taste pe care aplicația le păstrează pentru sine, deci omise: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Asociate mai multor comenzi după import: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Importă',
			'keyboardShortcuts.file.imported' => 'Scurtăturile au fost importate',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'Această versiune a expirat',
			'expiredBuild.body' => 'Vizitați ham2k.com și obțineți o versiune mai nouă.',
			'expiredBuild.visit' => 'Vizitează ham2k.com',
			'expiredBuild.dismiss' => 'Continuă oricum',
			'staleness.codePushFloorTitle' => 'O actualizare importantă așteaptă',
			'staleness.codePushFloorBody' => 'Această versiune are o remediere pe care nu o aveți încă.',
			'staleness.restartToApply' => 'Reporniți aplicația pentru a o aplica.',
			'staleness.quitAndReopen' => 'Ieșiți din aplicație și deschideți-o din nou pentru a o aplica.',
			'staleness.reopenToApply' => 'Închideți aplicația și deschideți-o din nou pentru a o aplica.',
			'staleness.ignoreForNow' => 'Ignoră deocamdată',
			'spotting.noQsoYet' => 'Niciun QSO înregistrat încă pentru spotare.',
			'spotting.setFrequencyFirst' => 'Setați mai întâi o frecvență.',
			'spotting.nothingToSpot' => 'Nimic de spotat — nicio extensie nu oferă spotare aici.',
			'spotting.incompleteCall' => 'Nu se poate spota un indicativ incomplet — completați mai întâi indicativul.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} a eșuat: ${message}',
			'spotting.unknownError' => 'eroare necunoscută',
			'spotting.notSent' => 'Spotul nu a fost trimis.',
			'spotting.allSkipped' => 'Spotul nu a fost trimis: toate sursele de spoturi l-au omis.',
			'spotting.notRefreshedOffline' => 'Fără conexiune — spoturile nu au fost reîmprospătate',
			'dataFiles.downloading' => 'Se descarcă…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name} nu a putut fi descărcat',
			'dataFiles.downloadFailedWebHint' => 'Poate fi o problemă de rețea sau gazda acestui link poate să nu permită descărcări directe dintr-un browser web. Încercați aplicația desktop sau mobilă ori o altă locație de găzduire.',
			'dataFiles.downloadTimedOut' => 'Serverul a întârziat prea mult să răspundă. Încercați din nou mai târziu.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} a răspuns cu o eroare (HTTP ${status}). Încercați din nou mai târziu.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} nu a putut furniza acest fișier (HTTP ${status}). Verificați dacă adresa este încă corectă.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM nu are niciun fișier Call History pentru ${stem}.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'Descărcarea fișierului Call History de la N1MM pentru ${stem} nu a reușit. Încercați din nou mai târziu.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name} nu a putut fi procesat',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Descărcarea avea doar ${imported} din cele ${existing} înregistrări de pe acest dispozitiv, așa că cele omise au fost păstrate. Reîmprospătarea din Setări › Date offline o acceptă totuși.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'S-a importat ${count} înregistrare pentru ${label}.', other: 'S-au importat ${count} înregistrări pentru ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'S-au importat date pentru ${label}.',
			'dataFiles.cleanedUpTitle' => 'Datele extensiilor au fost curățate',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Au fost eliminate datele pentru ${count} fișier de date al extensiilor dezactivate.', other: 'Au fost eliminate datele pentru ${count} fișiere de date ale extensiilor dezactivate.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} înregistrări',
			'dataFiles.definitionUnavailable' => 'Sursa fișierului nu a furnizat o definiție — extensia ei poate fi în curs de repornire sau configurată greșit. Încercați din nou peste un moment.',
			'updates.updateAvailable' => 'Actualizare disponibilă',
			'updates.newVersionAvailable' => ({required Object version}) => 'O versiune nouă (${version}) este disponibilă.',
			'updates.getIt' => 'Obține',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Actualizare pregătită',
			'updates.restartToApply' => 'O actualizare a fost descărcată. Reporniți pentru a o aplica.',
			'updates.appliesNextLaunch' => 'O actualizare a fost descărcată. Se va aplica la următoarea deschidere a aplicației.',
			'updates.restartNow' => 'Repornește acum',
			'updates.reloadToUpdate' => 'O versiune mai nouă a acestei pagini este disponibilă. Reîncărcați pentru a o obține.',
			'updates.reloadNow' => 'Reîncarcă acum',
			'updates.checkForUpdates' => 'Caută actualizări',
			'updates.checkingForUpdates' => 'Se caută actualizări…',
			'updates.upToDate' => 'La zi',
			'updates.automaticChecks' => 'Verifică automat',
			'updates.automaticChecksDescription' => 'Caută versiuni noi în fundal, începând de la următoarea pornire a aplicației',
			'extensionService.runtimeNotReady' => 'Mediul de rulare a extensiilor nu este pregătit.',
			'extensionService.testFailed' => ({required Object error}) => 'Testul a eșuat: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Conectat ca ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configurație de câmp invalidă',
			'extensionService.invalidValue' => 'Valoare invalidă',
			'extensionService.validationError' => ({required Object error}) => 'Eroare de validare: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Acțiunea a eșuat: ${error}',
			'extensionService.commandFailed' => 'Comanda nu a putut rula',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name} nu poate schimba setările: nu a cerut acest drept la instalare',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name} nu poate controla stația radio: nu a cerut acest drept la instalare',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name} nu poate rula asta: este una dintre comenzile pentru dezvoltatori ale aplicației',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => 'Rapoartele nu pot fi trimise acum',
			'extensionService.stashUnavailable' => 'Ham2K File Stash nu poate fi accesat acum',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => 'Niciun răspuns la căutarea de activități de la ${names}, așa că unele rezultate pot lipsi.',
			'extensionService.activitySearchSomeSourcesFailed' => 'Unele extensii de activitate nu au răspuns la căutare, așa că unele rezultate pot lipsi.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} a petrecut prea mult timp în temporizatoarele sale. Acestea sunt oprite până la repornirea extensiilor.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Temporizatoarele ${name} au eșuat repetat. Sunt oprite până la repornirea extensiilor.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} s-a blocat într-un temporizator. Temporizatoarele sale sunt oprite până la repornirea extensiilor.',
			'operationLocationScreen.title' => 'Locația operațiunii',
			'operationLocationScreen.selectedLocation' => 'Locație selectată',
			'operationLocationScreen.gridSquare' => 'Localizator al grilei Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Necesită 4, 6, 8 sau 10 caractere, ca FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Locații sugerate',
			'operationLocationScreen.deviceGps' => 'GPS-ul dispozitivului',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de la ${device}',
			'operationLocationScreen.locating' => 'Se localizează…',
			'operationLocationScreen.gpsUnavailable' => 'Locație indisponibilă',
			'operationLocationScreen.permissionDenied' => 'Permisiunea de locație a fost refuzată',
			'operationLocationScreen.permissionBlocked' => 'Permisiunea de locație este blocată',
			'operationLocationScreen.moreDetails' => 'Mai multe detalii',
			'operationLocationScreen.stateOrProvince' => 'Stat sau provincie (opțional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controalele activității nu sunt disponibile',
			'operationLocationScreen.controlsUnavailableReason' => 'Aceste referințe pot fi folosite în continuare; doar activitățile lor nu au putut fi accesate.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Reîncearcă',
			'operationLocationScreen.county' => 'Județ (opțional)',
			'versionLabel.version' => ({required Object version}) => 'Versiunea ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Nicio notificare încă',
			'notices.webStorageInMemory' => 'Acest browser nu a putut oferi stocare persistentă — jurnalul există doar în memorie și va fi PIERDUT când se închide această filă. Folosiți o versiune actuală de Chrome, Firefox, Safari sau Edge.',
			'notices.webStorageUnreliable' => 'Acest browser folosește o stocare de rezervă care nu este sigură cu mai multe file — păstrați o singură filă deschisă și lăsați sincronizarea activă.',
			'notices.logFromNewerBuildTitle' => 'Acest jurnal necesită o versiune mai nouă',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Jurnalul dvs. a fost scris de o versiune mai nouă de HaLo (versiunea de stocare ${storage}; aceasta înțelege ${understood}), deci nu poate fi deschis, iar contactele noi nu vor fi salvate. Instalați din nou versiunea mai nouă — sau, dacă intenționați să rulați această versiune, indicați-i un alt dosar de date. Jurnalul se află în ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Jurnalul dvs. a fost scris de o versiune mai nouă de HaLo (versiunea de stocare ${storage}; aceasta înțelege ${understood}), deci nu poate fi deschis, iar contactele noi nu vor fi salvate. Deschideți jurnalul cu acea versiune mai nouă.',
			'notices.preferencesRestoredTitle' => 'Setările au fost restaurate dintr-o copie de rezervă',
			'notices.preferencesRestored' => 'Fișierul de setări nu a putut fi citit, așa că HaLo a restaurat ultima copie bună a acestuia. Este posibil să trebuiască să setați din nou ce ați schimbat în sesiunea anterioară. Fișierul ilizibil este păstrat alături, cu numele shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Setările au fost resetate',
			'notices.preferencesReset' => 'Fișierul de setări nu a putut fi citit și nu exista nicio copie de rezervă, așa că HaLo a pornit cu valorile implicite. Fișierul ilizibil este păstrat în dosarul de date al aplicației, cu numele shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} nu a fost conectat automat',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo a încetat să răspundă ultima dată când a început să se conecteze la ${name}, așa că de data aceasta nu a mai încercat, pentru a nu risca să se repete. Verificați că stația radio este pornită și cablul este conectat, apoi apăsați Conectează pe ea în Setări.',
			'syncAccount.anonymous' => ({required Object id}) => 'Cont anonim (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (confirmare în așteptare)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (confirmare în așteptare - #${id})',
			'deepLink.needsAnOperation' => 'Porniți mai întâi o operațiune, apoi trimiteți din nou acel contact',
			'deepLink.waitingInOperation' => 'Acel contact așteaptă în operațiunea din spatele acestui ecran',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Acest dispozitiv nu are nicio activitate pentru ${refs}, așa că acele referințe au fost omise',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Activitățile dvs. nu au putut fi accesate, așa că ${refs} a fost omis — încercați din nou acel link',
			'confirmDevice.title' => 'Confirmați un dispozitiv',
			'confirmDevice.codePrompt' => 'Introduceți codul afișat pe dispozitivul care vrea să se alăture acestui cont.',
			'confirmDevice.code' => 'Cod',
			'confirmDevice.lookUp' => 'Caută',
			'confirmDevice.codeNotFound' => 'Nicio cerere nu corespunde acestui cod. Codurile expiră după 10 minute — cereți celuilalt dispozitiv unul nou.',
			'confirmDevice.linkExpired' => 'Linkul a expirat. Cereți celuilalt dispozitiv să afișeze un cod QR nou.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Conectați ${device} la acest cont?',
			'confirmDevice.unnamedDevice' => 'un dispozitiv fără nume',
			'confirmDevice.grantWarning' => 'Va putea citi și modifica fiecare operațiune și QSO din acest cont.',
			'confirmDevice.needsSyncTitle' => 'Acest dispozitiv nu se sincronizează încă',
			'confirmDevice.needsSyncText' => 'Activați sincronizarea Ham2K Log Filer și conectați acest dispozitiv la un cont înainte de a putea admite altul.',
			'confirmDevice.malformedRequest' => 'Serverul de sincronizare a trimis o cerere pe care această aplicație nu a putut-o citi. Cereți celuilalt dispozitiv să încerce din nou.',
			'confirmDevice.linkIt' => 'Conectează dispozitivul',
			'switchAccounts.noAccountDetails' => 'Încă nu există detalii despre cont',
			'switchAccounts.currentAccount' => 'Contul curent',
			'switchAccounts.otherAccounts' => 'Alte conturi',
			'switchAccounts.linkToAnother' => 'Conectare la alt cont',
			'switchAccounts.linkWithSibling' => 'Conectare cu altă aplicație Ham2K',
			'switchAccounts.linkWithPolo' => 'Conectare cu contul din versiunea veche',
			'switchAccounts.linkWithSiblingDescription' => 'Aveți instalată o altă aplicație Ham2K. Conectați-vă cu contul folosit acolo.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Aprobați cererea în ${app}, apoi reveniți aici.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Deschide din nou ${app}',
			'switchAccounts.siblingNoGrant' => 'Nu a funcționat? Deschideți-o din nou sau reveniți și conectați-vă în alt mod.',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app} nu a putut fi deschisă.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Linkul a expirat și unul nou este pregătit — deschideți din nou ${app}.',
			'switchAccounts.tryAgain' => 'Încercați din nou',
			'switchAccounts.linkWithQr' => 'Conectare cu un cod QR',
			'switchAccounts.linkWithQrDescription' => 'Scanați-l de pe un dispozitiv care folosește deja contul',
			'switchAccounts.linkWithEmail' => 'Conectare cu o adresă de e-mail',
			'switchAccounts.linkWithEmailDescription' => 'Confirmați cu un cod sau cu un link din e-mail',
			'switchAccounts.enterEmailPrompt' => 'Introduceți adresa de e-mail a contului pe care doriți să-l folosească acest dispozitiv.',
			'switchAccounts.emailAddress' => 'Adresă de e-mail',
			'switchAccounts.linkAccount' => 'Conectează contul',
			'switchAccounts.copiedCode' => 'Codul a fost copiat în clipboard',
			'switchAccounts.copyCode' => 'Copiază codul',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Deschideți aplicația Ham2K pe un dispozitiv deja conectat cu ${email} și introduceți acest cod pentru a aproba cererea:',
			'switchAccounts.waitingForConfirmation' => 'Se așteaptă confirmarea…',
			'switchAccounts.sendEmailInstead' => 'Trimite în schimb un e-mail de confirmare',
			'switchAccounts.emailSent' => ({required Object email}) => 'A fost trimis un e-mail la ${email}. Deschideți-l și confirmați cererea pentru a conecta acest dispozitiv.',
			'switchAccounts.resendEmail' => 'Retrimite e-mailul',
			'switchAccounts.qrPrompt' => 'Scanați acest cod QR de pe un dispozitiv deja conectat la contul dorit — de exemplu cu Ham2K Portable Logger pe telefon.',
			'switchAccounts.serverUnreachable' => 'Serverul de sincronizare nu a putut fi accesat. Încercați din nou mai târziu.',
			'switchAccounts.emailRequired' => 'Introduceți o adresă de e-mail pentru conectare.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Nu s-a găsit niciun cont pentru ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Serverul de sincronizare a respins cererea: ${error}',
			'switchAccounts.noLinkCode' => 'Serverul de sincronizare nu a returnat un cod de conectare. Încercați din nou mai târziu.',
			'switchAccounts.noConfirmationCode' => 'Serverul de sincronizare nu a trimis un cod de confirmare. Încercați din nou mai târziu.',
			'switchAccounts.switchNotAccepted' => 'Acel cont nu a acceptat schimbarea. Încercați în schimb conectarea cu o adresă de e-mail.',
			'switchAccounts.requestFailed' => 'Ceva n-a mers bine în comunicarea cu serverul de sincronizare. Încercați din nou mai târziu.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} QSO', other: '${count} QSO-uri', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} operațiune', other: '${count} operațiuni', ), 
			'qsonImport.title' => 'Importă operațiune QSON',
			'qsonImport.description' => 'Creează o operațiune nouă dintr-un fișier QSON, așa cum exportă Modul dezvoltator aici sau în PoLo.',
			'qsonImport.dropHint' => 'Plasați aici un fișier QSON pentru a-l importa ca operațiune nouă',
			'qsonImport.importing' => ({required Object filename}) => 'Se importă ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => '${filename} nu a putut fi importat: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'Nu s-a putut deschide un fișier pentru import: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} nu este text UTF-8, deci nu este un fișier QSON',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} nu este un fișier JSON, deci nu este un fișier QSON',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} nu conține o operațiune QSON',
			'qsonImport.busy' => 'Un import rulează deja. Așteptați să se termine înainte de a porni altul.',
			'qsonImport.oneFileOnly' => 'Plasați câte un singur fișier QSON — fiecare se deschide ca operațiune separată.',
			'adifImport.title' => 'Importă QSO-uri din ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Se citește ${filename}…',
			'adifImport.dropHint' => 'Plasați aici un fișier ADIF pentru import',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} QSO în acest fișier', other: '${formatted} QSO-uri în acest fișier', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} se află deja în jurnal', other: '${formatted} se află deja în jurnal', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} va fi importat', other: '${formatted} vor fi importate', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} contact nou', other: '${formatted} contacte noi', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} va fi combinat cu un contact existent', other: '${formatted} vor fi combinate cu contacte existente', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} nu poate fi importat (fără indicativ)', other: '${formatted} nu pot fi importate (fără indicativ)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} necesită o verificare atentă', other: '${formatted} necesită o verificare atentă', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Referințele nu au putut fi recuperate pentru ${count} contact', other: 'Referințele nu au putut fi recuperate pentru ${formatted} contacte', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'Referințele ${programs} pot fi incomplete pentru ${count} contact', other: 'Referințele ${programs} pot fi incomplete pentru ${formatted} contacte', ), 
			'adifImport.stackingTypesUnknown' => 'Contactele combinate pot pierde o referință — activitățile nu au putut indica ce tipuri se cumulează. Anulați și reîncercați pentru a evita acest lucru.',
			'adifImport.nothingToImport' => 'Nimic din acest fișier nu poate fi importat',
			'adifImport.confirm' => 'Importă',
			'adifImport.importing' => ({required Object filename}) => 'Se importă ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: 'S-a importat ${count} contact din ${filename}', other: 'S-au importat ${formatted} contacte din ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename} nu a putut fi importat: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} nu pare a fi un fișier ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Atenție: acest ADIF are QSO-uri de la ${calls}, dar vor fi importate ca ${station} dacă continuați.',
			'adifImport.stationCallJoin' => ' și ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ro'))(count, one: '${count} nu are dată și nu poate fi importat', other: '${formatted} nu au dată și nu pot fi importate', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Acest fișier înregistrează o activare a ${refs}.',
			'adifImport.addActivation' => 'Adaugă la această operațiune',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Doar ${written} din ${planned} au putut fi aplicate — jurnalul s-a schimbat cât timp decideați.',
			'adifImport.busy' => 'Un import rulează deja. Așteptați să se termine înainte de a porni altul.',
			'adifImport.oneFileOnly' => 'Plasați câte un singur fișier ADIF — ordinea în care se importă fișierele decide ce date câștigă.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} are mai mult de ${limit} QSO-uri, maximul pe care o operațiune îl poate importa deodată.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename} are mai mult de ${limit} QSO-uri. Importul unui ADIF într-o operațiune este menit să adauge câteva QSO-uri, nu să aducă un jurnal mare — folosiți pentru asta vizualizarea Jurnale. Modul dezvoltator vă permite totuși să îl importați, dacă sunteți sigur.',
			'adifImport.importAnyway' => 'Importă oricum',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: conectat',
			'offline.noRoute' => 'Nicio conexiune la rețea.',
			'offline.unreachable' => 'Rețeaua funcționează, dar niciun server nu răspunde — adesea semn că o pagină de autentificare așteaptă într-un browser.',
			'offline.reachable' => 'Toate serviciile răspund normal.',
			'offline.whatStops' => 'Căutările, spoturile și fișierele de date sunt în pauză. Înregistrarea și sincronizarea din apropiere nu.',
			'offline.servicesTitle' => 'Servicii',
			'offline.noServices' => 'Niciun serviciu nu a raportat încă.',
			'offline.lastSuccess' => ({required Object when}) => 'A răspuns ultima dată acum ${when}',
			'offline.neverSucceeded' => 'Nu a răspuns încă',
			'offline.nextAttempt' => ({required Object when}) => 'Următoarea încercare peste ${when}',
			'offline.nextAttemptNow' => 'Următoarea încercare urmează',
			'offline.retry' => 'Reîncearcă acum',
			'offline.retrying' => 'Se încearcă…',
			'offline.retryReached' => 'Din nou online.',
			'offline.retryUnreachable' => 'Tot niciun răspuns.',
			'offline.retryNotAttempted' => 'Nimic de trimis acum.',
			'offline.retryThrottled' => 'Tocmai s-a încercat — mai așteptați puțin.',
			'offline.retryDisabled' => 'Sincronizarea este oprită, deci nu există nimic cu care să se testeze.',
			'offline.syncService' => 'Sincronizare Ham2K LoFi',
			'offline.retryInFlight' => 'Se încearcă deja — așteptați.',
			'exportSettings.defaultsDescription' => 'Setări de bază pentru toate exporturile, cu șabloane separate de nume de fișier și titlu pentru activitățile de referință și alte activități. Fiecare tip de export poate avea propriile valori implicite sau setări personalizate.',
			'exportSettings.referenceActivities' => 'Activități de referință',
			'exportSettings.otherActivities' => 'Alte activități',
			'exportSettings.adifFields' => 'Câmpuri ADIF',
			'exportSettings.loadFailed' => 'Setările de export nu au putut fi încărcate.',
			'exportSettings.retry' => 'Reîncearcă',
			'exportSettings.compactFileNamesDescriptionOn' => 'Nume de fișiere compacte, ca N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Nume de fișiere descriptive, ca 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Se includ nume, adrese, e-mailuri, note și locații precise în fișierele ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Se omit nume, adrese, e-mailuri și note; locațiile se limitează la grile de șase caractere.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Se includ informații de la serviciile de căutare a indicativelor.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Se omit informațiile de la serviciile de căutare a indicativelor; se păstrează valorile introduse manual.',
			'exportSettings.customTemplatesDescriptionOn' => 'Șabloanele dvs. personalizate sunt active și pot fi editate mai jos.',
			'exportSettings.customTemplatesDescriptionOff' => 'Șabloanele implicite sunt active. Șabloanele dvs. personalizate sunt păstrate pentru mai târziu.',
			'exportSettings.type' => 'Tip de export',
			'exportSettings.defaults' => 'Setări implicite',
			'exportSettings.includeLookupData' => 'Include datele de căutare',
			'exportSettings.customTemplates' => 'Șabloane personalizate',
			'exportSettings.filenameTemplate' => 'Șablon nume fișier',
			'exportSettings.compactFilenameTemplate' => 'Șablon nume fișier compact',
			'exportSettings.titleTemplate' => 'Șablon titlu',
			'exportSettings.adifNotesTemplate' => 'Notițe ADIF QSO',
			'exportSettings.adifCommentTemplate' => 'Comentarii ADIF QSO',
			'exportSettings.adifQslMessageTemplate' => 'Mesaj ADIF QSL',
			'exportSettings.shared' => 'Setările se aplică fiecărei extensii care folosește acest tip de export.',
			'exportSettings.defaultTemplates' => 'Activați Șabloane personalizate pentru a edita șabloanele acestui tip.',
			'templateEditor.previewLabel' => 'Previzualizare:',
			'templateEditor.reset' => 'Resetează',
			'templateEditor.docs' => 'Documentație șabloane',
			'templateEditor.preview' => 'Previzualizare exemplu',
			'templateEditor.reference' => 'Referință șabloane',
			'templateEditor.attributes' => 'Atribute disponibile',
			'templateEditor.filters' => 'Filtre',
			'templateEditor.flowControl' => 'Controlul fluxului',
			'templateEditor.unavailable' => 'Previzualizarea nu este disponibilă până când extensiile sunt pregătite.',
			'templateEditor.empty' => '(rezultat gol)',
			_ => null,
		};
	}
}
