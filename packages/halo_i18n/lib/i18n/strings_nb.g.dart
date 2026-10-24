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
class TranslationsNb extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsNb({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.nb,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <nb>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsNb _root = this; // ignore: unused_field

	@override 
	TranslationsNb $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsNb(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$nb common = _Translations$common$nb._(_root);
	@override late final _Translations$onboarding$nb onboarding = _Translations$onboarding$nb._(_root);
	@override late final _Translations$startScreen$nb startScreen = _Translations$startScreen$nb._(_root);
	@override late final _Translations$testerOverlay$nb testerOverlay = _Translations$testerOverlay$nb._(_root);
	@override late final _Translations$extensionsPanel$nb extensionsPanel = _Translations$extensionsPanel$nb._(_root);
	@override late final _Translations$home$nb home = _Translations$home$nb._(_root);
	@override late final _Translations$chase$nb chase = _Translations$chase$nb._(_root);
	@override late final _Translations$dialogs$nb dialogs = _Translations$dialogs$nb._(_root);
	@override late final _Translations$operation$nb operation = _Translations$operation$nb._(_root);
	@override late final _Translations$map$nb map = _Translations$map$nb._(_root);
	@override late final _Translations$mapsView$nb mapsView = _Translations$mapsView$nb._(_root);
	@override late final _Translations$activitiesView$nb activitiesView = _Translations$activitiesView$nb._(_root);
	@override late final _Translations$loggingControls$nb loggingControls = _Translations$loggingControls$nb._(_root);
	@override late final _Translations$formChrome$nb formChrome = _Translations$formChrome$nb._(_root);
	@override late final _Translations$qsoEditForm$nb qsoEditForm = _Translations$qsoEditForm$nb._(_root);
	@override late final _Translations$qsoList$nb qsoList = _Translations$qsoList$nb._(_root);
	@override late final _Translations$loggingPanel$nb loggingPanel = _Translations$loggingPanel$nb._(_root);
	@override late final _Translations$callInfo$nb callInfo = _Translations$callInfo$nb._(_root);
	@override late final _Translations$settings$nb settings = _Translations$settings$nb._(_root);
	@override late final _Translations$commands$nb commands = _Translations$commands$nb._(_root);
	@override late final _Translations$commandDialog$nb commandDialog = _Translations$commandDialog$nb._(_root);
	@override late final _Translations$expiredBuild$nb expiredBuild = _Translations$expiredBuild$nb._(_root);
	@override late final _Translations$staleness$nb staleness = _Translations$staleness$nb._(_root);
	@override late final _Translations$spotting$nb spotting = _Translations$spotting$nb._(_root);
	@override late final _Translations$dataFiles$nb dataFiles = _Translations$dataFiles$nb._(_root);
	@override late final _Translations$updates$nb updates = _Translations$updates$nb._(_root);
	@override late final _Translations$extensionService$nb extensionService = _Translations$extensionService$nb._(_root);
	@override late final _Translations$operationLocationScreen$nb operationLocationScreen = _Translations$operationLocationScreen$nb._(_root);
	@override late final _Translations$versionLabel$nb versionLabel = _Translations$versionLabel$nb._(_root);
	@override late final _Translations$notices$nb notices = _Translations$notices$nb._(_root);
	@override late final _Translations$syncAccount$nb syncAccount = _Translations$syncAccount$nb._(_root);
	@override late final _Translations$deepLink$nb deepLink = _Translations$deepLink$nb._(_root);
	@override late final _Translations$confirmDevice$nb confirmDevice = _Translations$confirmDevice$nb._(_root);
	@override late final _Translations$switchAccounts$nb switchAccounts = _Translations$switchAccounts$nb._(_root);
	@override late final _Translations$adifImport$nb adifImport = _Translations$adifImport$nb._(_root);
	@override late final _Translations$offline$nb offline = _Translations$offline$nb._(_root);
	@override late final _Translations$exportSettings$nb exportSettings = _Translations$exportSettings$nb._(_root);
	@override late final _Translations$templateEditor$nb templateEditor = _Translations$templateEditor$nb._(_root);
}

// Path: common
class _Translations$common$nb extends Translations$common$en {
	_Translations$common$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get save => 'Lagre';
	@override String get ok => 'OK';
	@override String get cancel => 'Avbryt';
	@override String get delete => 'Slett';
	@override String get create => 'Opprett';
	@override String get error => 'Feil';
	@override String get close => 'Lukk';
	@override String get done => 'Ferdig';
	@override String get callsign => 'Kallesignal';
	@override String get clear => 'Tøm';
	@override String get dismiss => 'Lukk';
	@override String get expand => 'Utvid';
	@override String get collapse => 'Skjul';
}

// Path: onboarding
class _Translations$onboarding$nb extends Translations$onboarding$en {
	_Translations$onboarding$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Velkommen til Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Velkommen til Ham2K Power Logger!';
	@override String get welcomeBody => 'Vi har noen spørsmål som hjelper oss å tilpasse appen til dine behov.';
	@override String get skip => 'Hopp over';
	@override String get kContinue => 'Fortsett';
	@override String get back => 'Tilbake';
	@override String get next => 'Neste';
	@override String get done => 'Ferdig';
	@override String get callsignTitle => 'Hva er kallesignalet ditt?';
	@override String get callsignBody => 'Du trenger en lisens som radioamatør for at denne appen skal være nyttig';
	@override String get callsignLabel => 'Operatørens kallesignal';
	@override String get alreadyHaveAccount => 'Har du allerede en konto?';
	@override String get foundSiblingTitle => 'Koble til en eksisterende konto?';
	@override String foundSiblingBody({required Object app}) => 'Vi fant ${app} på denne enheten. Koble denne appen til samme konto, så følger kallesignalet og loggene dine med.';
	@override String get foundPoloBody => 'Vi fant en eldre versjon av Ham2K Portable Logger på denne enheten. Koble denne appen til samme konto, så følger kallesignalet og loggene dine med.';
	@override String get foundSiblingsBody => 'Vi fant andre Ham2K-apper på denne enheten. Koble denne appen til en av kontoene deres, så følger kallesignalet og loggene dine med.';
	@override String linkWithApp({required Object app}) => 'Koble til ${app}';
	@override String get linkWithPolo => 'Koble til kontoen i den eldre versjonen';
	@override String get setUpFresh => 'Start på nytt';
	@override String get activitiesTitle => 'Favorittaktiviteter';
	@override String get activitiesBody => 'Er du interessert i noen av disse populære aktiveringsprogrammene?';
	@override String get activitiesFooter => '(Du finner flere alternativer i Innstillinger)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Data og personvern';
	@override String get consentUsageBody => 'For å hjelpe oss å gjøre appen bedre vil vi gjerne samle inn ytelses-, krasj- og bruksdata.';
	@override String get consentUsageLabel => 'Del data om appbruk';
	@override String get consentOperationBody => 'Noen funksjoner kan innebære at operasjonsdataene dine deles med andre brukere. Du kan reservere deg når som helst.';
	@override String get consentOperationLabel => 'Del operasjonsdata';
	@override String get finishingSetup => 'Fullfører oppsettet — laster ned referansedata…';
}

// Path: startScreen
class _Translations$startScreen$nb extends Translations$startScreen$en {
	_Translations$startScreen$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get credits => 'av KI2D og venner';
}

// Path: testerOverlay
class _Translations$testerOverlay$nb extends Translations$testerOverlay$en {
	_Translations$testerOverlay$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get tape => 'FORSIKTIG: UNDER ARBEID';
	@override String get warningTitle => 'Denne appen er under utvikling';
	@override String get warningBody => 'De fleste funksjonene har ujevnt underlag og snublefeller overalt. Se jevnlig etter oppdateringer.';
	@override String whatsNew({required Object build}) => 'Nytt i build ${build}';
	@override String get thanks => 'Takk for at du setter loggen din på spill for å hjelpe oss å gjøre denne appen bedre!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$nb extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Aktiviteter';
	@override String get categoryContest => 'Konkurranser';
	@override String get categoryLookup => 'Kallesignaloppslag';
	@override String get categorySpots => 'Spot-kilder';
	@override String get categoryDashboard => 'Dashbordpaneler';
	@override String get categoryOther => 'Andre utvidelser';
	@override String get searchHint => 'Søk i utvidelser';
	@override String get applying => 'Aktiverer endringer i utvidelser, dette kan ta et øyeblikk…';
	@override String get noMatches => 'Ingen utvidelser samsvarer med søket';
	@override String get installFromFile => 'Installer fra fil…';
	@override String installVersion({required Object version}) => 'Versjon ${version}';
	@override String get canReach => 'Denne utvidelsen kan kontakte';
	@override String canHoldConnection({required Object host}) => '${host}, over en åpen tilkobling';
	@override String get canHoldLocalConnection => 'Enheter på det lokale nettverket ditt, over en åpen tilkobling';
	@override String get canUseLocation => 'Posisjonen din';
	@override String get canReadRadio => 'Radioen din, for å lese frekvens og modus';
	@override String get canControlRadio => 'Radioen din, for å styre den og sende med den — avstemming, effekt, CW, talememorier og PTT';
	@override String get canSetUserAgent => 'Identifisere seg overfor servere med sitt eget navn';
	@override String get noCapabilities => 'Den ber ikke om noe utenfor appen.';
	@override String get sandboxNote => 'Utvidelser kjører i sandkasse: ingen tilgang til filene dine, og ikke noe nettverk utover det som står her.';
	@override String get installAction => 'Installer';
	@override String get updateAction => 'Oppdater';
	@override String get installFailed => 'Utvidelsen kunne ikke installeres';
	@override String get installedBadge => 'Installert';
	@override String get uninstallAction => 'Fjern';
	@override String uninstallTitle({required Object name}) => 'Fjerne ${name}?';
	@override String get uninstallBody => 'Denne utvidelsen og innstillingene dens blir fjernet. Loggene dine forblir urørt.';
	@override String installedMessage({required Object name}) => 'Installerte ${name}';
	@override String get installDownloading => 'Laster ned…';
	@override String get installWaiting => 'Venter på å installere…';
	@override String get installInstalling => 'Installerer…';
	@override String get installAwaitingApproval => 'Venter på godkjenningen din…';
	@override String installAlreadyRunning({required Object name}) => '${name} installeres allerede.';
	@override String updatedTo({required Object version}) => 'Oppdatert til ${version}';
	@override String installIncomplete({required Object name}) => 'Installasjonen av ${name} ble ikke fullført. Den må kanskje installeres på nytt.';
	@override String uninstallFailed({required Object name}) => 'Kunne ikke fjerne ${name}';
	@override String installedFrom({required Object source}) => 'Lastet ned fra ${source}';
	@override String get dropHint => 'Slipp en .h2kext-utvidelse her for å installere den';
	@override String get dropOneOnly => 'Slipp én utvidelse om gangen.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} svarte med ${status} for den utvidelsen.';
	@override String get downloadTooLarge => 'Den nedlastingen er altfor stor til å være en utvidelse.';
	@override String get downloadNotSecure => 'Den nedlastingen ble omdirigert til et usikkert sted.';
	@override String get catalogSection => 'Katalog';
	@override String get catalogLoading => 'Laster katalogen…';
	@override String get catalogUnreachable => 'Katalogen kan ikke nås';
	@override String get builtIn => 'Innebygd';
	@override String get updateAvailableBadge => 'Oppdatering tilgjengelig';
	@override String get updatesAvailableTitle => 'Oppdateringer for utvidelser';
	@override String updateAvailableFor({required Object name}) => 'En oppdatering er tilgjengelig for ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} og ${count} til må oppdateres.';
	@override String updatesAvailableFor({required Object names}) => '${names} må oppdateres.';
	@override String get pendingUpdatesSection => 'Ventende oppdateringer';
	@override String get updateAllAction => 'Oppdater alle';
	@override String get updatesUnderWay => 'Disse oppdateringene pågår allerede.';
	@override String get updatesNothingLeft => 'Utvidelsene dine er oppdatert.';
	@override String get updatesNoticeAction => 'Mer info';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Oppdatere ${count} utvidelse?',
		other: 'Oppdatere ${count} utvidelser?',
	);
	@override String get upgradeDoneTitle => 'Utvidelsene dine er klare';
	@override String get upgradeDoneBody => 'De kommer nå fra Ham2Ks utvidelseskatalog, så de kan oppdateres uten å vente på en ny versjon av appen.';
	@override String upgradeDoneUnserved({required Object names}) => 'Ikke oppgradert: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Ville ikke kjøre: ${names}.';
	@override String get upgradeDoneRefusedHint => 'De er fortsatt installert og merket i Innstillinger › Utvidelser — hvis du oppdaterer dem der, kommer de tilbake.';
	@override String get upgradeDoneUnservedHint => 'Katalogen har ingen direkte erstatning for disse, så se der etter utvidelser som dekker det du brukte.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'State Parks-arrangementer';
	@override String upgradeDoneMissing({required Object count}) => '${count} av utvidelsene dine har ikke kommet ennå. De lastes ned neste gang utvidelseskatalogen kan nås.';
	@override String get runtimeDeadBody => 'Utvidelsene dine ville ikke starte. En omstart av appen bør få dem tilbake.';
	@override String get refusedTitle => 'Noen utvidelser ville ikke kjøre';
	@override String get upgradeBusyTitle => 'Setter fortsatt opp';
	@override String get upgradeRuntimeDeadTitle => 'Utvidelsene dine kjører ikke';
	@override String get restoreTitle => 'Noen av utvidelsene dine mangler';
	@override String get restoreBody => 'Disse utvidelsene du installerte, finnes ikke på denne enheten. Vi kan laste dem ned igjen fra Ham2Ks utvidelseskatalog:';
	@override String get restoreFromFile => 'Installert fra en fil. Installer disse på nytt fra filene deres, eller glem dem:';
	@override String get restoreOtherCatalog => 'Installert fra en annen utvidelseskatalog, så de er ikke tilgjengelige her:';
	@override String get restoreForget => 'Glem';
	@override String get restoreInstall => 'Installer';
	@override String get restoreLater => 'Senere';
	@override String get restoreInstalling => 'Installerer utvidelsene dine…';
	@override String get restoreDoneTitle => 'Utvidelsene dine er tilbake';
	@override String restoreDoneBody({required Object names}) => 'Installert på nytt: ${names}.';
	@override String get restorePartialTitle => 'Noen utvidelser kunne ikke installeres';
	@override String restoreFailed({required Object names}) => 'Kunne ikke installere: ${names}. Vi tilbyr dem igjen neste gang du åpner appen.';
	@override String get restoreBusyBody => 'Appen setter fortsatt opp utvidelsene dine. Vi tilbyr disse igjen neste gang du åpner appen.';
	@override String get restoreRuntimeDeadBody => 'Vi installerte dem på nytt, men utvidelsene dine ville ikke starte. En omstart av appen bør få dem tilbake.';
	@override String revokedTitle({required Object name}) => '${name} ble trukket tilbake';
	@override String get revokedBody => 'Katalogen trakk tilbake denne versjonen, så den er deaktivert.';
	@override String get downloadHashMismatch => 'Den nedlastingen er ikke utvidelsen katalogen beskrev.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Katalogen har ingen versjon ${version} av ${key}.';
	@override String get catalogLinkUnknown => 'Den kataloglenken peker ikke på en versjon av en utvidelse.';
	@override String catalogNoRelease({required Object key}) => 'Katalogen har ingen utgivelse av ${key} på det sporet.';
	@override String get installFromLink => 'Installer fra lenke';
	@override String get unstableReleaseWarning => 'Dette er en ustabil utgivelse som utgiveren ikke har erklært ferdig. Den kan oppføre seg feil, og den vil fortsette å få ustabile oppdateringer.';
	@override String get bleedingReleaseWarning => 'Dette er en dagsfersk utgivelse: arbeid som pågår, og som kan slutte å virke eller miste innstillingene sine. Den vil fortsette å få dagsferske oppdateringer.';
	@override String get channelUnstable => 'Ustabil';
	@override String get channelBleeding => 'Dagsfersk';
	@override String get followsUnstable => 'Får ustabile og stabile utgivelser';
	@override String get followsBleeding => 'Får dagsferske, ustabile og stabile utgivelser';
	@override String get followStableAction => 'Følg bare stabile utgivelser';
	@override String get revokedBadge => 'Trukket tilbake';
	@override String get refusedBadge => 'Ble ikke lastet';
	@override String get downloadNotHttps => 'Den nedlastingen går ikke over en sikker tilkobling.';
	@override String downloadUnreachable({required Object source}) => '${source} kunne ikke nås for den utvidelsen.';
	@override String get detailsAction => 'Detaljer';
	@override String get installedFromFile => 'Installert fra en fil';
	@override String get detailsWhatItDoes => 'Gir støtte for';
	@override String get installedPreloaded => 'Forhåndsinstallert';
	@override String get hookAccount => 'Kontoinnlogging';
	@override String get hookCallNotes => 'Kallesignalnotater';
	@override String get hookDataFile => 'Offlinedata';
	@override String get hookExport => 'Eksport';
	@override String get hookLookup => 'Kallesignaloppslag';
	@override String get hookScoring => 'Poengberegning';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => 'Jakter ${program}';
	@override String hookActivating({required Object program}) => 'Aktiverer ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '… og ${count} annen utvidelse',
		other: '… og ${count} andre utvidelser',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} utvidelse tilgjengelig',
		other: '${count} utvidelser tilgjengelig',
	);
}

// Path: home
class _Translations$home$nb extends Translations$home$en {
	_Translations$home$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portabel logger';
	@override String get newOperation => 'Ny operasjon';
	@override String get stationCallsign => 'Stasjonskallesignal';
	@override String get titleOptional => 'Tittel (valgfritt)';
	@override String get emptyList => 'Ingen operasjoner ennå. Opprett en for å begynne å logge.';
	@override String get quickLookup => 'Hurtigoppslag';
	@override late final _Translations$home$nav$nb nav = _Translations$home$nav$nb._(_root);
	@override late final _Translations$home$panels$nb panels = _Translations$home$panels$nb._(_root);
	@override String get toggleNav => 'Vis eller skjul navigasjonsetikettene';
	@override late final _Translations$home$logs$nb logs = _Translations$home$logs$nb._(_root);
}

// Path: chase
class _Translations$chase$nb extends Translations$chase$en {
	_Translations$chase$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'jakter';
	@override String goalsTwo({required Object first, required Object second}) => '${first} og ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} og flere';
	@override late final _Translations$chase$station$nb station = _Translations$chase$station$nb._(_root);
	@override late final _Translations$chase$periodInline$nb periodInline = _Translations$chase$periodInline$nb._(_root);
	@override late final _Translations$chase$periodStats$nb periodStats = _Translations$chase$periodStats$nb._(_root);
	@override late final _Translations$chase$period$nb period = _Translations$chase$period$nb._(_root);
	@override late final _Translations$chase$goals$nb goals = _Translations$chase$goals$nb._(_root);
	@override late final _Translations$chase$panels$nb panels = _Translations$chase$panels$nb._(_root);
}

// Path: dialogs
class _Translations$dialogs$nb extends Translations$dialogs$en {
	_Translations$dialogs$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Operasjonsdetaljer';
	@override String get activities => 'Aktiviteter';
	@override String get stationCallsign => 'Stasjonskallesignal';
	@override String get multiStationIdentifier => 'Identifikator for multistasjon (kun tall)';
	@override String get notes => 'Notater';
	@override String get deleteOperationTitle => 'Slett operasjon';
	@override String get purgeTestsTitle => 'Fjern testoperasjoner';
	@override String get purgeTestsBody => 'Dette sletter disse testoperasjonene og QSOene deres permanent. Det kan ikke angres.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Pluss ${count} testkontakt som ikke hører til noen operasjon.',
		other: 'Pluss ${count} testkontakter som ikke hører til noen operasjon.',
	);
	@override String get purgeTestsAction => 'Fjern';
	@override String get syncAllTitle => 'Erstatte loggen på denne enheten?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL tar sikkerhetskopi av og fjerner ${qsos} fra denne enheten, og laster deretter ned kontoens logg på nytt fra serveren. Sikkerhetskopien blir liggende i databasen på denne enheten.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${n} QSO er ikke synkronisert ennå — serveren har aldri mottatt den, og den kommer IKKE tilbake.',
		other: '${n} QSOer er ikke synkronisert ennå — serveren har aldri mottatt dem, og de kommer IKKE tilbake.',
	);
	@override String get syncAllAction => 'Tøm og synkroniser på nytt';
	@override String get receivedPurgesTitle => 'Testoperasjoner fjernet et annet sted';
	@override String get receivedPurgesBody => 'Disse ble slettet som testoperasjoner på en annen enhet. Fjerne dem her også? Dette sletter dem og QSOene deres permanent, og kan ikke angres.';
	@override String get receivedPurgesAction => 'Fjern';
	@override late final _Translations$dialogs$callChange$nb callChange = _Translations$dialogs$callChange$nb._(_root);
}

// Path: operation
class _Translations$operation$nb extends Translations$operation$en {
	_Translations$operation$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Denne operasjonen er slettet. Gjenopprett den for å logge eller gjøre endringer.';
	@override late final _Translations$operation$tabs$nb tabs = _Translations$operation$tabs$nb._(_root);
	@override late final _Translations$operation$positions$nb positions = _Translations$operation$positions$nb._(_root);
	@override String get stationCallsignNone => 'Ingen stasjonskallesignal';
	@override String get titleNone => 'Ingen tittel';
	@override String get deleteOperation => 'Slett operasjon';
	@override String get loggingControlsStale => 'Aktivitetsfeltene kan være utdatert — åpne operasjonen på nytt for å oppdatere dem';
	@override String get locationNone => 'Ikke satt';
	@override String get generalOperation => 'Vanlig operasjon';
	@override String titleFor({required Object value}) => 'for ${value}';
	@override String titleAt({required Object value}) => 'på ${value}';
	@override String segmentNow({required Object description}) => 'Nå ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$nb menu = _Translations$operation$menu$nb._(_root);
	@override late final _Translations$operation$layout$nb layout = _Translations$operation$layout$nb._(_root);
	@override late final _Translations$operation$export$nb export = _Translations$operation$export$nb._(_root);
	@override late final _Translations$operation$spots$nb spots = _Translations$operation$spots$nb._(_root);
	@override late final _Translations$operation$import$nb import = _Translations$operation$import$nb._(_root);
}

// Path: map
class _Translations$map$nb extends Translations$map$en {
	_Translations$map$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$nb outlineIssue = _Translations$map$outlineIssue$nb._(_root);
	@override String get outlinesDisclaimer => 'Omrissene er bare til veiledning. Gjør dine egne undersøkelser!';
	@override String outlinesCredit({required Object sources}) => 'Omriss: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Grenser: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Fasiliteter: ${sources}';
	@override String get fullCredits => 'Fullstendige datakilder';
	@override String get fewerCredits => 'Færre kilder';
	@override String get emptyState => 'Ingen QSO-posisjoner ennå.\nQSOer med grid-rute, stat eller land vises her.';
	@override String get unavailable => 'Kartet er ikke tilgjengelig akkurat nå.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Flatt';
	@override String get globe => 'Globus';
	@override String get zoomIn => 'Zoom inn';
	@override String get zoomOut => 'Zoom ut';
	@override late final _Translations$map$postcard$nb postcard = _Translations$map$postcard$nb._(_root);
}

// Path: mapsView
class _Translations$mapsView$nb extends Translations$mapsView$en {
	_Translations$mapsView$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kart';
	@override String get searchHint => 'Søk etter parker, toppunkter og mer';
	@override String get activities => 'Aktiviteter';
	@override String get layers => 'Lag';
	@override String get baseMap => 'Grunnkart';
	@override String get satellite => 'Satellitt (Esri)';
	@override String get facilities => 'Parkfasiliteter';
	@override String get boundaries => 'Grenser';
	@override String get currentLocation => 'Nåværende posisjon';
	@override String noMatches({required Object text}) => 'Ingenting samsvarer med «${text}»';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} referanse ved ${where}',
		other: '${count} referanser ved ${where}',
	);
	@override String get startOperation => 'Start en operasjon med disse referansene';
}

// Path: activitiesView
class _Translations$activitiesView$nb extends Translations$activitiesView$en {
	_Translations$activitiesView$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aktiviteter';
	@override String get activitiesCountZero => 'Ingen aktiviteter valgt';
	@override String get activitiesCountOne => '1 aktivitet';
	@override String activitiesCountOther({required Object count}) => '${count} aktiviteter';
	@override String get empty => 'Ingen aktiviteter ennå — bruk Forslag og søk nedenfor for å legge til en';
	@override String get removeActivity => 'Fjern';
	@override String openReferenceLink({required Object name}) => 'Åpne ${name}';
	@override String get editActivity => 'Rediger aktivitet';
	@override String get manageExtensions => 'Administrer utvidelser';
	@override String get manage => 'Administrer';
	@override String activitiesTitle1({required Object first}) => 'Aktivitetstyper: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Aktivitetstyper: ${first} og ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Aktivitetstyper: ${first}, ${second} og ${more} til';
	@override String get reference => 'Referanse';
	@override String get invalidReference => 'Ugyldig';
	@override String get duplicateReference => 'Allerede lagt til';
	@override String get searchHint => 'Søk etter navn, referanse eller noe annet…';
	@override String get noSuggestions => 'Ingen treff';
	@override String get noSuggestionsHint => 'Søk etter referansenavn eller -nummer ovenfor';
	@override String get noSuggestionsExample => '(for eksempel \'trail\' eller \'4556\')';
	@override String get allOptions => 'Aktivitetstyper';
	@override String get determiningLocation => 'Finner gjeldende posisjon…\nVenter på GPS-posisjon for å finne referanser i nærheten';
	@override String get locationUnavailableTitle => 'Posisjonsdata er ikke tilgjengelig';
	@override String get locationDeniedTitle => 'Tilgang til posisjon avslått';
	@override String get locationBlockedTitle => 'Tilgang til posisjon blokkert';
	@override String get noNearbyReason => 'Kan ikke finne referanser i nærheten';
	@override String locationManualHint({required Object icon}) => 'Trykk på ${icon} for å angi posisjonen din manuelt,\neller bare søk etter referanser med navn';
	@override String get locationGrantAction => 'Gi tilgang til posisjon';
	@override String get locationSettingsAction => 'Åpne Innstillinger';
	@override String get locationSettingsUnavailable => 'Gi tilgang til posisjon i systeminnstillingene';
	@override String get locationGrantRefused => 'Fortsatt ingen posisjon — systemet sa nei igjen';
	@override String get searchUnavailableTitle => 'Aktivitetssøk utilgjengelig';
	@override String get searchUnavailableReason => 'Ingen aktivitetsutvidelse kunne kjøre søket. Prøv igjen om et øyeblikk.';
	@override String get emptySheet => 'Bruk forslag og søk nedenfor for å legge til en';
	@override String get exports => 'Eksporter';
	@override String get exportLogs => 'Eksporter logger';
	@override String get tools => 'Verktøy';
	@override String get toolsTitle => 'Operasjonsverktøy';
	@override String get operationDetails => 'Operasjonsdetaljer';
	@override String get share => 'Del';
	@override String get archive => 'Arkiver';
	@override String get deleteOperation => 'Slett operasjon';
	@override String get undeleteOperation => 'Gjenopprett operasjon';
	@override String get alreadySelected => 'Allerede valgt';
	@override String get selected => 'Valgt';
	@override String pickPosition({required Object index, required Object count}) => '${index} av ${count}';
	@override String get previousPick => 'Forrige treff';
	@override String get nextPick => 'Neste treff';
	@override String get retiredReference => 'Utgått';
	@override String enableExtension({required Object name}) => 'Aktiver ${name}';
	@override String get enableExtensionHint => 'Denne utvidelsen samsvarer med søket ditt, men den er ikke aktivert';
	@override String get enableExtensionForRefHint => 'Denne utvidelsen håndterer en av referansene i denne operasjonen, men den er ikke aktivert';
	@override String extensionNotRunning({required Object name}) => '${name} kjører ikke';
	@override String get extensionNotRunningHint => 'Denne utvidelsen er deaktivert, åpne Utvidelsesinnstillinger for mer info';
	@override String installExtension({required Object name}) => 'Installer ${name}';
	@override String get installExtensionHint => 'Denne utvidelsen samsvarer med søket ditt, men den er ikke installert';
	@override String get onlyCatalogMatches => 'Ingen treff\nNoen utvidelser i katalogen kan ha resultater.\nInstaller dem under Aktivitetstyper nedenfor.';
	@override String get setupUnavailable => 'Kunne ikke laste oppsettet for denne aktiviteten — prøv igjen fra Administrer';
	@override String get controlsUnavailableTitle => 'Aktivitetskontroller utilgjengelige';
	@override String get controlsUnavailableReason => 'Referansene dine er trygge, men de kan ikke redigeres akkurat nå.';
	@override String get controlsUnavailableRetry => 'Prøv igjen';
	@override String get onlyDisabledMatches => 'Ingen treff\nNoen tilgjengelige utvidelser kan ha resultater.\nAktiver dem under Aktivitetstyper nedenfor.';
	@override String get onlyNotRunningMatches => 'Ingen treff\nNoen utvidelser som kan ha resultater, kjører ikke.\nSe Aktivitetstyper nedenfor.';
	@override String get mapToggle => 'Kart';
	@override String get searchToggle => 'Søk';
	@override String get addToOperation => 'Legg til i operasjonen';
	@override String get addToOperationShort => 'Legg til';
	@override String get mapEmptyState => 'Ingen resultater å vise på kartet';
	@override String get mapEmptyStateHint => 'Gå tilbake til listen, eller søk etter noe annet';
	@override String get imports => 'Importer';
}

// Path: loggingControls
class _Translations$loggingControls$nb extends Translations$loggingControls$en {
	_Translations$loggingControls$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Tid (UTC)';
	@override String get date => 'Dato';
	@override String get now => 'Nå';
	@override String get frequency => 'Frekvens';
	@override String get mode => 'Modus';
	@override String get theirCall => 'Deres kallesignal';
	@override String get noteField => 'Notat';
	@override String get todoField => 'Gjøremål';
	@override String get sent => 'Sendt';
	@override String get rcvd => 'Mottatt';
	@override String get more => 'Mer';
	@override String get revert => 'Tilbakestill';
	@override String get undoDelete => 'Angre sletting';
	@override String get restore => 'Gjenopprett';
	@override String get wipe => 'Tøm';
	@override String get undo => 'Angre';
	@override String get pendingDeleteTapWarning => 'Trykk på søppelbøtten én gang til for å slette denne QSOen';
	@override String get pendingDeleteClickWarning => 'Klikk på søppelbøtten én gang til for å slette denne QSOen';
	@override String get deletedQsoWarning => 'Slettet QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Trykk på søppelbøtten én gang til for å slette denne ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Klikk på søppelbøtten én gang til for å slette denne ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'Slettet ${kind}';
	@override String get timeControl => 'Tid';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Effekt';
	@override String get notesControl => 'Notater';
	@override String get power => 'Effekt';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Loggekontroller';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Selvspotting';
	@override String spotSelfAt({required Object freq}) => 'Selvspot på ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} på ${freq}';
	@override String spotTooLate({required Object call}) => 'For sent å spotte ${call}';
	@override String get spotNoFreq => 'Angi en frekvens å spotte først';
	@override String get spotComment => 'Kommentar';
	@override String get bandOrFreqRequired => 'Angi frekvens eller bånd før du logger';
	@override String get missingBand => 'Ingen bånd';
	@override String get missingMode => 'Ingen modus';
	@override String saveFailed({required Object error}) => 'Kunne ikke lagre: ${error}';
	@override String deleteFailed({required Object error}) => 'Kunne ikke slette: ${error}';
	@override late final _Translations$loggingControls$info$nb info = _Translations$loggingControls$info$nb._(_root);
}

// Path: formChrome
class _Translations$formChrome$nb extends Translations$formChrome$en {
	_Translations$formChrome$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(uten tittel)';
	@override String get showMore => 'Vis mer';
	@override String get showAll => 'Vis alle';
	@override String get showFewer => 'Vis færre';
	@override String get defaults => 'Standard';
	@override String get search => 'Søk';
	@override String get clear => 'Tøm';
	@override String get openPage => 'Åpne side';
	@override String get connected => 'Tilkoblet';
	@override String get notConnected => 'Ikke tilkoblet';
	@override String get manage => 'Administrer';
	@override String get connect => 'Koble til';
	@override String get formTitle => 'Skjema';
	@override String addItem({required Object label}) => 'Legg til ${label}';
	@override String editItem({required Object label}) => 'Rediger ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Viser ${shown} av ${total} (${selected} valgt)';
	@override String validationError({required Object error}) => 'Valideringsfeil: ${error}';
	@override String transformationError({required Object error}) => 'Transformasjonsfeil: ${error}';
	@override String actionError({required Object error}) => 'Feil: ${error}';
	@override String get removeItem => 'Fjern';
	@override String get storageUnavailable => 'Innlogginger utilgjengelige';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$nb extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rediger QSO';
	@override String get operatorCall => 'Operatør';
	@override String get position => 'Operatørplass';
	@override String get theirName => 'Navn';
	@override String get theirGrid => 'Grid';
	@override String get theirState => 'Stat';
	@override String get band => 'Bånd';
	@override String get notes => 'Notater';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Deres info';
	@override String get sectionOur => 'Vår info';
	@override String get sectionNotes => 'Notater';
	@override String get theirCity => 'By';
	@override String get theirCounty => 'Fylke';
	@override String get theirEntity => 'Entitet';
	@override String get theirCqZone => 'CQ-sone';
	@override String get theirItuZone => 'ITU-sone';
	@override String get theirArrlSection => 'ARRL-seksjon';
	@override String get theirLat => 'Breddegrad';
	@override String get theirLon => 'Lengdegrad';
	@override String get theirPower => 'Deres effekt';
}

// Path: qsoList
class _Translations$qsoList$nb extends Translations$qsoList$en {
	_Translations$qsoList$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ingen QSOer ennå — kjør noen!';
	@override String get bandOrModeWarning => 'Kontroller at bånd og modus er riktige';
	@override String get today => 'I dag';
	@override String get yesterday => 'I går';
	@override String get tomorrow => 'I morgen';
}

// Path: loggingPanel
class _Translations$loggingPanel$nb extends Translations$loggingPanel$en {
	_Translations$loggingPanel$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Operasjonsstatistikk';
	@override String get scoring => 'Poengberegning';
	@override String get dxccEntities => 'DXCC-entiteter';
	@override String get statesWorked => 'Stater';
	@override String get provincesWorked => 'Provinser';
	@override String get duplicates => 'Duplikater';
}

// Path: callInfo
class _Translations$callInfo$nb extends Translations$callInfo$en {
	_Translations$callInfo$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Vis bilde';
	@override String get imageUnavailable => 'Bilde utilgjengelig';
	@override String get photo => 'Bilde';
	@override String get notes => 'Notater';
	@override String distanceTo({required Object distance}) => '${distance} til';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) til';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) til';
	@override String distanceAway({required Object distance}) => '${distance} unna';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) unna';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) unna';
	@override String get thisOpCountOne => '1 QSO i denne operasjonen';
	@override String thisOpCountOther({required Object count}) => '${count} QSOer i denne operasjonen';
	@override String get otherOpsCountOne => '1 QSO i andre operasjoner';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOer i andre operasjoner';
	@override String andMore({required Object count}) => '… og ${count} flere';
	@override String withCall({required Object call}) => 'med ${call}';
	@override String fromOperation({required Object where}) => 'fra ${where}';
	@override late final _Translations$callInfo$history$nb history = _Translations$callInfo$history$nb._(_root);
}

// Path: settings
class _Translations$settings$nb extends Translations$settings$en {
	_Translations$settings$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Innstillinger';
	@override String get language => 'Språk';
	@override String languageSystem({required Object language}) => 'Følg systeminnstillingene (${language})';
	@override late final _Translations$settings$theme$nb theme = _Translations$settings$theme$nb._(_root);
	@override late final _Translations$settings$themeDescription$nb themeDescription = _Translations$settings$themeDescription$nb._(_root);
	@override String get fontScale => 'Skriftstørrelse';
	@override late final _Translations$settings$fontScaleOpts$nb fontScaleOpts = _Translations$settings$fontScaleOpts$nb._(_root);
	@override late final _Translations$settings$keepDeviceAwake$nb keepDeviceAwake = _Translations$settings$keepDeviceAwake$nb._(_root);
	@override String get layoutDensity => 'Tetthet i oppsettet';
	@override late final _Translations$settings$layoutDensityOpts$nb layoutDensityOpts = _Translations$settings$layoutDensityOpts$nb._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'vinduet er for lavt, bruker ${effective}';
	@override String get layoutDensityAtLimit => 'så langt det går';
	@override String get distanceUnits => 'Avstandsenheter';
	@override late final _Translations$settings$distanceUnitsOpts$nb distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$nb._(_root);
	@override String get userInterface => 'Brukergrensesnitt';
	@override late final _Translations$settings$logging$nb logging = _Translations$settings$logging$nb._(_root);
	@override late final _Translations$settings$catServer$nb catServer = _Translations$settings$catServer$nb._(_root);
	@override late final _Translations$settings$radio$nb radio = _Translations$settings$radio$nb._(_root);
	@override late final _Translations$settings$help$nb help = _Translations$settings$help$nb._(_root);
	@override late final _Translations$settings$exports$nb exports = _Translations$settings$exports$nb._(_root);
	@override late final _Translations$settings$map$nb map = _Translations$settings$map$nb._(_root);
	@override late final _Translations$settings$privacy$nb privacy = _Translations$settings$privacy$nb._(_root);
	@override String get operatorCall => 'Operatørkallesignal';
	@override late final _Translations$settings$sync$nb sync = _Translations$settings$sync$nb._(_root);
	@override late final _Translations$settings$peers$nb peers = _Translations$settings$peers$nb._(_root);
	@override String get developerMode => 'Utviklermodus';
	@override late final _Translations$settings$syncPanel$nb syncPanel = _Translations$settings$syncPanel$nb._(_root);
	@override late final _Translations$settings$accounts$nb accounts = _Translations$settings$accounts$nb._(_root);
	@override late final _Translations$settings$station$nb station = _Translations$settings$station$nb._(_root);
	@override late final _Translations$settings$offlineData$nb offlineData = _Translations$settings$offlineData$nb._(_root);
	@override late final _Translations$settings$profiles$nb profiles = _Translations$settings$profiles$nb._(_root);
	@override late final _Translations$settings$search$nb search = _Translations$settings$search$nb._(_root);
	@override late final _Translations$settings$developer$nb developer = _Translations$settings$developer$nb._(_root);
	@override late final _Translations$settings$about$nb about = _Translations$settings$about$nb._(_root);
	@override late final _Translations$settings$panels$nb panels = _Translations$settings$panels$nb._(_root);
	@override String get showMoreSettings => 'Vis flere innstillinger';
	@override String get gridPrecision => 'Grid-presisjon';
	@override late final _Translations$settings$gridPrecisionOpts$nb gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$nb._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$nb gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$nb._(_root);
}

// Path: commands
class _Translations$commands$nb extends Translations$commands$en {
	_Translations$commands$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Aktiver synkronisering i Innstillinger først.';
	@override String get fullResyncStarted => 'Full ny synkronisering startet — lokale data ble sikkerhetskopiert først.';
	@override String noDataFilesMatched({required Object target}) => 'Ingen datafiler samsvarte med "${target}".';
	@override String reloadFailed({required Object error}) => 'Ny innlasting mislyktes: ${error}';
	@override String get reloadingAll => 'Laster inn alle datafiler på nytt…';
	@override String reloadingTarget({required Object target}) => 'Laster inn datafiler for ${target} på nytt…';
	@override String unknownExperiment({required Object token}) => 'Ukjent eksperiment "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} aktivert';
	@override String experimentDisabled({required Object name}) => '${name} deaktivert';
	@override String get sentryTestSent => 'Testfeilrapport sendt til Sentry';
	@override String get sentryTestLocalOnly => 'Sentry er deaktivert i denne versjonen — testfeilen ble bare logget lokalt';
	@override String get noOperationOpen => 'Den kommandoen krever en åpen operasjon';
	@override String unknownSegmentKind({required Object kind}) => 'Vet ikke hvordan en \'${kind}\' skal markeres';
	@override String get operationAlreadyStarted => 'Denne operasjonen har allerede en startmarkør';
	@override String get couldNotOpenLocation => 'La til pausen, men kunne ikke åpne posisjonsskjermen';
	@override String get noTestOperations => 'Ingen testoperasjoner å fjerne';
	@override String get purgeTestsUnavailable => 'PURGETESTS må vise en bekreftelsesdialog, og det er ikke mulig her';
	@override String get syncAllUnavailable => 'SYNCALL må vise en bekreftelsesdialog, og det er ikke mulig her';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Fjernet ${count} testoperasjon',
		other: 'Fjernet ${count} testoperasjoner',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Fjernet ${purged} av ${total} testoperasjoner — resten mislyktes; prøv PURGETESTS igjen';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Fjernet ${count} testkontakt uten operasjon',
		other: 'Fjernet ${count} testkontakter uten operasjon',
	);
	@override String get purgeTestsContactsFailed => 'Fjernet testoperasjonene, men testkontaktene uten operasjon mislyktes; prøv PURGETESTS igjen';
	@override String get purgeTestsNothingToDo => 'Ingenting ble fjernet';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Fjernet ${removed} av ${total} testoperasjoner — resten mislyktes; prøv Gjennomgå igjen';
	@override String get receivedPurgesFailed => 'Kunne ikke fjerne disse testoperasjonene — prøv Gjennomgå igjen';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} testoperasjon ble fjernet på en annen enhet',
		other: '${count} testoperasjoner ble fjernet på en annen enhet',
	);
	@override String get receivedPurgesReview => 'Gjennomgå';
	@override String get settingOn => 'På';
	@override String get settingOff => 'Av';
	@override String get settingEmpty => '(tom)';
	@override String get settingSecretSet => '(satt)';
	@override String get settingSecretUnset => '(ikke satt)';
	@override String settingSelectedCount({required Object count}) => '${count} valgt';
	@override String get settingExpectsOnOff => 'på eller av';
	@override String settingExpectsOneOf({required Object choices}) => 'en av: ${choices}';
	@override String get settingExpectsNumber => 'et tall';
	@override String settingVanished({required Object label}) => '«${label}» er ikke lenger tilgjengelig';
	@override String get noCwKeyer => 'Ingen tilkoblet radio kan sende CW';
	@override String get noKeyer => 'Ingen tilkoblet radio kan sende CW eller spille av talememorier';
	@override String get keyerNeedsOperation => 'Åpne en operasjon for å bruke CW-keyeren';
	@override String get keyerExperimentOff => 'CW-nøkling er av — slå det på med EXP KEYER';
	@override String get esmExperimentOff => 'Enter sender meldinger er av — slå det på med EXP ESM';
	@override String cwSending({required Object text}) => 'Sender CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW-melding F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW-melding F${n} ble ikke sendt: utvidelsene er ikke klare';
	@override String settingNotStored({required Object label}) => '«${label}» godtok ikke den verdien';
}

// Path: commandDialog
class _Translations$commandDialog$nb extends Translations$commandDialog$en {
	_Translations$commandDialog$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Søk etter kallesignaler eller skriv en kommando';
	@override String noResults({required Object text}) => 'Ingenting samsvarer med «${text}»';
	@override String get sectionCommands => 'Kommandoer';
	@override String get sectionGoTo => 'Gå til';
	@override String get sectionOperations => 'Operasjoner';
	@override String get goHome => 'Hjem';
	@override String get goSettings => 'Innstillinger';
	@override String get goNewOperation => 'Ny operasjon';
	@override String runTyped({required Object text}) => 'Kjør «${text}»';
	@override String get sectionSuggestions => 'Prøv';
	@override String get lookingUp => 'Slår opp kallesignal…';
	@override String get blockedByPane => 'Kan ikke bruke kommandoer mens et panel eller en dialog er åpen';
}

// Path: expiredBuild
class _Translations$expiredBuild$nb extends Translations$expiredBuild$en {
	_Translations$expiredBuild$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Denne versjonen er utløpt';
	@override String get body => 'Gå til ham2k.com og hent en nyere versjon.';
	@override String get visit => 'Gå til ham2k.com';
	@override String get dismiss => 'Fortsett likevel';
}

// Path: staleness
class _Translations$staleness$nb extends Translations$staleness$en {
	_Translations$staleness$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'En viktig oppdatering venter';
	@override String get codePushFloorBody => 'Denne versjonen har en rettelse du ikke har ennå.';
	@override String get restartToApply => 'Start appen på nytt for å ta den i bruk.';
	@override String get quitAndReopen => 'Avslutt appen og åpne den igjen for å ta den i bruk.';
	@override String get reopenToApply => 'Lukk appen og åpne den igjen for å ta den i bruk.';
	@override String get ignoreForNow => 'Ignorer foreløpig';
}

// Path: spotting
class _Translations$spotting$nb extends Translations$spotting$en {
	_Translations$spotting$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Ingen QSO logget ennå å spotte.';
	@override String get setFrequencyFirst => 'Angi en frekvens først.';
	@override String get nothingToSpot => 'Ingenting å spotte — ingen utvidelse tilbyr spotting her.';
	@override String spotFailed({required Object source, required Object message}) => '${source} mislyktes: ${message}';
	@override String get unknownError => 'ukjent feil';
	@override String get notSent => 'Spot ikke sendt.';
	@override String get notRefreshedOffline => 'Ingen forbindelse — spots ble ikke oppdatert';
}

// Path: dataFiles
class _Translations$dataFiles$nb extends Translations$dataFiles$en {
	_Translations$dataFiles$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Laster ned…';
	@override String downloadFailedTitle({required Object name}) => 'Kunne ikke laste ned ${name}';
	@override String get downloadFailedWebHint => 'Dette kan være et nettverksproblem, eller verten for denne lenken støtter kanskje ikke direkte nedlasting fra en nettleser. Prøv skrivebords- eller mobilappen, eller et annet lagringssted.';
	@override String get downloadTimedOut => 'Serveren brukte for lang tid på å svare. Prøv igjen senere.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} svarte med en feil (HTTP ${status}). Prøv igjen senere.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} kunne ikke levere denne filen (HTTP ${status}). Sjekk at adressen fortsatt er riktig.';
	@override String processingFailedTitle({required Object name}) => 'Kunne ikke behandle ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Nedlastingen hadde bare ${imported} av de ${existing} postene på denne enheten, så de som manglet, ble beholdt. Oppdater den i Innstillinger › Offlinedata for å godta den likevel.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Importerte ${count} post for ${label}.',
		other: 'Importerte ${count} poster for ${label}.',
	);
	@override String importedData({required Object label}) => 'Importerte data for ${label}.';
	@override String get cleanedUpTitle => 'Ryddet opp i utvidelsesdata';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Fjernet data for ${count} datafil fra deaktiverte utvidelser.',
		other: 'Fjernet data for ${count} datafiler fra deaktiverte utvidelser.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} poster';
	@override String get definitionUnavailable => 'Kilden for filen leverte ingen definisjon — utvidelsen kan være midt i en omstart eller feil satt opp. Prøv igjen om et øyeblikk.';
}

// Path: updates
class _Translations$updates$nb extends Translations$updates$en {
	_Translations$updates$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Oppdatering tilgjengelig';
	@override String newVersionAvailable({required Object version}) => 'En ny versjon (${version}) er tilgjengelig.';
	@override String get getIt => 'Hent den';
	@override String get ok => 'OK';
	@override String get updateReady => 'Oppdatering klar';
	@override String get restartToApply => 'En oppdatering er lastet ned. Start på nytt for å ta den i bruk.';
	@override String get appliesNextLaunch => 'En oppdatering er lastet ned. Den tas i bruk neste gang du åpner appen.';
	@override String get restartNow => 'Start på nytt nå';
	@override String get reloadToUpdate => 'En nyere versjon av denne siden er tilgjengelig. Last inn på nytt for å få den.';
	@override String get reloadNow => 'Last inn på nytt nå';
	@override String get checkForUpdates => 'Se etter oppdateringer';
	@override String get checkingForUpdates => 'Ser etter oppdateringer…';
	@override String get upToDate => 'Oppdatert';
	@override String get automaticChecks => 'Se etter automatisk';
	@override String get automaticChecksDescription => 'Se etter nye versjoner i bakgrunnen, fra neste gang du starter appen';
}

// Path: extensionService
class _Translations$extensionService$nb extends Translations$extensionService$en {
	_Translations$extensionService$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Kjøremiljøet for utvidelser er ikke klart.';
	@override String testFailed({required Object error}) => 'Testen mislyktes: ${error}';
	@override String connectedAs({required Object identity}) => 'Tilkoblet som ${identity}';
	@override String get invalidFieldConfiguration => 'Ugyldig feltoppsett';
	@override String get invalidValue => 'Ugyldig verdi';
	@override String validationError({required Object error}) => 'Valideringsfeil: ${error}';
	@override String actionFailed({required Object error}) => 'Handlingen mislyktes: ${error}';
	@override String get commandFailed => 'Kommandoen kunne ikke kjøres';
	@override String get reportUnavailable => 'Rapporter kan ikke sendes akkurat nå';
	@override String get stashUnavailable => 'Ham2K File Stash kan ikke nås akkurat nå';
	@override String timersSuspendedBudget({required Object name}) => '${name} brukte for mye tid i tidtakerne sine. De er stoppet til utvidelsene starter på nytt.';
	@override String timersSuspendedFailures({required Object name}) => 'Tidtakerne til ${name} feilet gang på gang. De er stoppet til utvidelsene starter på nytt.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} ble sittende fast i en tidtaker. Tidtakerne er stoppet til utvidelsene starter på nytt.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$nb extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Plassering';
	@override String get selectedLocation => 'Valgt plassering';
	@override String get gridSquare => 'Maidenhead-lokator';
	@override String get gridInvalid => 'Trenger 4, 6, 8 eller 10 tegn, som FN31pr';
	@override String get suggestedLocations => 'Foreslåtte plasseringer';
	@override String get deviceGps => 'Enhetens GPS';
	@override String peerGps({required Object device}) => 'GPS fra ${device}';
	@override String get locating => 'Lokaliserer…';
	@override String get gpsUnavailable => 'Posisjon utilgjengelig';
	@override String get permissionDenied => 'Tilgang til posisjon avslått';
	@override String get permissionBlocked => 'Tilgang til posisjon blokkert';
	@override String get moreDetails => 'Flere detaljer';
	@override String get stateOrProvince => 'Delstat eller provins (valgfritt)';
	@override String get controlsUnavailableTitle => 'Aktivitetskontroller utilgjengelige';
	@override String get controlsUnavailableReason => 'Disse referansene kan fortsatt brukes; aktivitetene deres kunne bare ikke nås.';
	@override String get controlsUnavailableRetry => 'Prøv igjen';
	@override String get county => 'Fylke (valgfritt)';
}

// Path: versionLabel
class _Translations$versionLabel$nb extends Translations$versionLabel$en {
	_Translations$versionLabel$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versjon ${version}';
	@override String patch({required Object patch}) => 'Oppdatering ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$nb extends Translations$notices$en {
	_Translations$notices$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Ingen varsler ennå';
	@override String get webStorageInMemory => 'Denne nettleseren kunne ikke tilby varig lagring — loggen finnes bare i minnet og GÅR TAPT når denne fanen lukkes. Bruk en oppdatert Chrome, Firefox, Safari eller Edge.';
	@override String get webStorageUnreliable => 'Denne nettleseren bruker reservelagring som ikke er trygg med flere faner — hold bare én fane åpen, og la synkroniseringen være på.';
	@override String get logFromNewerBuildTitle => 'Denne loggen krever en nyere versjon';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Loggen din ble skrevet av en nyere versjon av HaLo (lagringsversjon ${storage}; denne forstår ${understood}), så den kan ikke åpnes, og nye kontakter blir ikke lagret. Installer den nyere versjonen igjen — eller, hvis du mente å kjøre denne versjonen, pek den mot en annen datamappe. Loggen ligger i ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Loggen din ble skrevet av en nyere versjon av HaLo (lagringsversjon ${storage}; denne forstår ${understood}), så den kan ikke åpnes, og nye kontakter blir ikke lagret. Åpne loggen med den nyere versjonen i stedet.';
	@override String get preferencesRestoredTitle => 'Innstillinger gjenopprettet fra sikkerhetskopi';
	@override String get preferencesRestored => 'Innstillingsfilen kunne ikke leses, så HaLo gjenopprettet den siste gode kopien. Det du endret i forrige økt, må kanskje settes på nytt. Den uleselige filen er beholdt ved siden av, med navnet shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Innstillinger tilbakestilt';
	@override String get preferencesReset => 'Innstillingsfilen kunne ikke leses, og det fantes ingen sikkerhetskopi å falle tilbake på, så HaLo startet med standardinnstillingene. Den uleselige filen er beholdt i appens datamappe, med navnet shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} ble ikke koblet til automatisk';
	@override String autoConnectHeld({required Object name}) => 'HaLo sluttet å svare forrige gang den begynte å koble til ${name}, så den lot den være denne gangen i stedet for å risikere det igjen. Sjekk at radioen er slått på og at kabelen er koblet til, og trykk så Koble til på den i Innstillinger.';
}

// Path: syncAccount
class _Translations$syncAccount$nb extends Translations$syncAccount$en {
	_Translations$syncAccount$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anonym konto (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (venter på bekreftelse)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (venter på bekreftelse - #${id})';
}

// Path: deepLink
class _Translations$deepLink$nb extends Translations$deepLink$en {
	_Translations$deepLink$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Start en operasjon først, og send så den kontakten igjen';
	@override String get waitingInOperation => 'Den kontakten venter i operasjonen bak denne skjermen';
	@override String unknownActivities({required Object refs}) => 'Denne enheten har ingen aktivitet for ${refs}, så disse referansene ble utelatt';
	@override String activitiesUnavailable({required Object refs}) => 'Kunne ikke nå aktivitetene dine, så ${refs} ble utelatt — prøv lenken igjen';
}

// Path: confirmDevice
class _Translations$confirmDevice$nb extends Translations$confirmDevice$en {
	_Translations$confirmDevice$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bekreft en enhet';
	@override String get codePrompt => 'Skriv inn koden som vises på enheten som vil bli med i denne kontoen.';
	@override String get code => 'Kode';
	@override String get lookUp => 'Slå opp';
	@override String get codeNotFound => 'Ingen forespørsel samsvarer med den koden. Koder utløper etter 10 minutter — be den andre enheten om en ny.';
	@override String get linkExpired => 'Den lenken har utløpt. Be den andre enheten om å vise en ny QR-kode.';
	@override String areYouSure({required Object device}) => 'Koble ${device} til denne kontoen?';
	@override String get unnamedDevice => 'en enhet uten navn';
	@override String get grantWarning => 'Den vil kunne lese og endre alle operasjoner og QSOer i denne kontoen.';
	@override String get needsSyncTitle => 'Denne enheten synkroniserer ikke ennå';
	@override String get needsSyncText => 'Slå på Ham2K Log Filer-synkronisering og koble denne enheten til en konto før den kan slippe inn en annen.';
	@override String get malformedRequest => 'Synkroniseringsserveren sendte en forespørsel denne appen ikke kunne lese. Be den andre enheten om å prøve igjen.';
	@override String get linkIt => 'Koble enhet';
}

// Path: switchAccounts
class _Translations$switchAccounts$nb extends Translations$switchAccounts$en {
	_Translations$switchAccounts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Ingen kontodetaljer ennå';
	@override String get currentAccount => 'Gjeldende konto';
	@override String get otherAccounts => 'Andre kontoer';
	@override String get linkToAnother => 'Koble til en annen konto';
	@override String get linkWithSibling => 'Koble til en annen Ham2K-app';
	@override String get linkWithPolo => 'Koble til kontoen i den eldre versjonen';
	@override String get linkWithSiblingDescription => 'Du har en annen Ham2K-app installert. Koble til kontoen som brukes der.';
	@override String siblingPrompt({required Object app}) => 'Godkjenn forespørselen i ${app}, og kom så tilbake hit.';
	@override String openSiblingAgain({required Object app}) => 'Åpne ${app} igjen';
	@override String get siblingNoGrant => 'Virket det ikke? Åpne den igjen, eller gå tilbake og koble til på en annen måte.';
	@override String siblingOpenFailed({required Object app}) => 'Kunne ikke åpne ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'Lenken utløp, og en ny er klar — åpne ${app} igjen.';
	@override String get tryAgain => 'Prøv igjen';
	@override String get linkWithQr => 'Koble til med en QR-kode';
	@override String get linkWithQrDescription => 'Skann den fra en enhet som allerede bruker kontoen';
	@override String get linkWithEmail => 'Koble til med en e-postadresse';
	@override String get linkWithEmailDescription => 'Bekreft med en kode eller en lenke i e-post';
	@override String get enterEmailPrompt => 'Oppgi e-postadressen til kontoen du vil at denne enheten skal bruke.';
	@override String get emailAddress => 'E-postadresse';
	@override String get linkAccount => 'Koble til konto';
	@override String get copiedCode => 'Koden er kopiert til utklippstavlen';
	@override String get copyCode => 'Kopier kode';
	@override String codePrompt({required Object email}) => 'Åpne Ham2K-appen på en enhet som allerede er koblet til ${email}, og skriv inn denne koden for å godkjenne forespørselen:';
	@override String get waitingForConfirmation => 'Venter på bekreftelse…';
	@override String get sendEmailInstead => 'Send en bekreftelses-e-post i stedet';
	@override String emailSent({required Object email}) => 'En e-post ble sendt til ${email}. Åpne den og bekreft forespørselen for å koble til denne enheten.';
	@override String get resendEmail => 'Send e-post på nytt';
	@override String get qrPrompt => 'Skann denne QR-koden fra en enhet som allerede er koblet til kontoen du vil bruke — for eksempel med Ham2K Portable Logger på telefonen din.';
	@override String get serverUnreachable => 'Kunne ikke nå synkroniseringsserveren. Prøv igjen senere.';
	@override String get emailRequired => 'Oppgi en e-postadresse å koble til.';
	@override String noAccountForEmail({required Object email}) => 'Fant ingen konto for ${email}.';
	@override String serverRejected({required Object error}) => 'Synkroniseringsserveren avviste forespørselen: ${error}';
	@override String get noLinkCode => 'Synkroniseringsserveren returnerte ingen tilkoblingskode. Prøv igjen senere.';
	@override String get noConfirmationCode => 'Synkroniseringsserveren sendte ingen bekreftelseskode. Prøv igjen senere.';
	@override String get switchNotAccepted => 'Den kontoen godtok ikke byttet. Prøv å koble den til med en e-postadresse i stedet.';
	@override String get requestFailed => 'Noe gikk galt i kommunikasjonen med synkroniseringsserveren. Prøv igjen senere.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} QSO',
		other: '${count} QSOer',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} operasjon',
		other: '${count} operasjoner',
	);
}

// Path: adifImport
class _Translations$adifImport$nb extends Translations$adifImport$en {
	_Translations$adifImport$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importer QSOer fra ADIF';
	@override String reading({required Object filename}) => 'Leser ${filename}…';
	@override String get dropHint => 'Slipp en ADIF-fil her for å importere';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} QSO i denne filen',
		other: '${formatted} QSOer i denne filen',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} finnes allerede i loggen din',
		other: '${formatted} finnes allerede i loggen din',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} blir importert',
		other: '${formatted} blir importert',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} ny kontakt',
		other: '${formatted} nye kontakter',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} blir slått sammen med en eksisterende kontakt',
		other: '${formatted} blir slått sammen med eksisterende kontakter',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} kan ikke importeres (mangler kallesignal)',
		other: '${formatted} kan ikke importeres (mangler kallesignal)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} bør sees nærmere på',
		other: '${formatted} bør sees nærmere på',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Referanser kunne ikke gjenopprettes for ${count} kontakt',
		other: 'Referanser kunne ikke gjenopprettes for ${formatted} kontakter',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${programs}-referanser kan være ufullstendige for ${count} kontakt',
		other: '${programs}-referanser kan være ufullstendige for ${formatted} kontakter',
	);
	@override String get stackingTypesUnknown => 'Sammenslåtte kontakter kan miste en referanse — aktivitetene kunne ikke si hvilke typer som kan kombineres. Avbryt og prøv igjen for å unngå dette.';
	@override String get nothingToImport => 'Ingenting i denne filen kan importeres';
	@override String get confirm => 'Importer';
	@override String importing({required Object filename}) => 'Importerer ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Importerte ${count} kontakt fra ${filename}',
		other: 'Importerte ${formatted} kontakter fra ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Kunne ikke importere ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} ser ikke ut som en ADIF-fil';
	@override String stationWarning({required Object calls, required Object station}) => 'Advarsel: denne ADIF-filen har QSOer fra ${calls}, men de blir importert som ${station} hvis du fortsetter.';
	@override String get stationCallJoin => ' og ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} mangler dato og kan ikke importeres',
		other: '${formatted} mangler dato og kan ikke importeres',
	);
	@override String activationFound({required Object refs}) => 'Denne filen registrerer en aktivering av ${refs}.';
	@override String get addActivation => 'Legg den til i denne operasjonen';
	@override String shortfall({required Object written, required Object planned}) => 'Bare ${written} av ${planned} kunne tas i bruk — loggen ble endret mens du bestemte deg.';
	@override String get busy => 'En import pågår allerede. Vent til den er ferdig før du starter en ny.';
	@override String get oneFileOnly => 'Slipp én ADIF-fil om gangen — rekkefølgen filene importeres i, avgjør hvilke data som vinner.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} har mer enn ${limit} QSOer, som er det meste en operasjon kan importere om gangen.';
}

// Path: offline
class _Translations$offline$nb extends Translations$offline$en {
	_Translations$offline$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internett: FRAKOBLET';
	@override String get statusOnline => 'Internett: tilkoblet';
	@override String get noRoute => 'Ingen nettverkstilkobling i det hele tatt.';
	@override String get unreachable => 'Nettverket er oppe, men ingen server svarer — ofte et tegn på at en innloggingsside venter i en nettleser.';
	@override String get reachable => 'Alle tjenester svarer som forventet.';
	@override String get whatStops => 'Oppslag, spots og datafiler er satt på pause. Logging og synkronisering i nærheten er det ikke.';
	@override String get servicesTitle => 'Tjenester';
	@override String get noServices => 'Ingen tjeneste har rapportert inn ennå.';
	@override String lastSuccess({required Object when}) => 'Svarte sist for ${when} siden';
	@override String get neverSucceeded => 'Har ikke svart ennå';
	@override String nextAttempt({required Object when}) => 'Neste forsøk om ${when}';
	@override String get nextAttemptNow => 'Neste forsøk står for tur';
	@override String get retry => 'Prøv igjen nå';
	@override String get retrying => 'Prøver…';
	@override String get retryReached => 'Tilkoblet igjen.';
	@override String get retryUnreachable => 'Fortsatt ikke noe svar.';
	@override String get retryNotAttempted => 'Ingenting å sende akkurat nå.';
	@override String get retryThrottled => 'Prøvde akkurat — vent litt.';
	@override String get retryDisabled => 'Synkronisering er slått av, så det finnes ingenting å teste med.';
	@override String get syncService => 'Ham2K LoFi-synkronisering';
	@override String get retryInFlight => 'Prøver allerede — vent litt.';
}

// Path: exportSettings
class _Translations$exportSettings$nb extends Translations$exportSettings$en {
	_Translations$exportSettings$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Grunninnstillinger for alle eksporter, med egne maler for filnavn og tittel for referanseaktiviteter og andre aktiviteter. Hver eksporttype kan ha sine egne standarder eller tilpassede innstillinger.';
	@override String get referenceActivities => 'Referanseaktiviteter';
	@override String get otherActivities => 'Andre aktiviteter';
	@override String get adifFields => 'ADIF-felt';
	@override String get loadFailed => 'Eksportinnstillingene kunne ikke lastes.';
	@override String get retry => 'Prøv igjen';
	@override String get compactFileNamesDescriptionOn => 'Kompakte filnavn, som N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Beskrivende filnavn, som 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Tar med navn, adresser, e-poster, notater og nøyaktige posisjoner i ADIF-filer.';
	@override String get includePrivateDataDescriptionOff => 'Utelater navn, adresser, e-poster og notater; begrenser posisjoner til grid med seks tegn.';
	@override String get includeLookupDataDescriptionOn => 'Tar med informasjon fra tjenester for kallesignaloppslag.';
	@override String get includeLookupDataDescriptionOff => 'Utelater informasjon fra tjenester for kallesignaloppslag; beholder manuelt inntastede verdier.';
	@override String get customTemplatesDescriptionOn => 'De egendefinerte malene dine er aktive og kan redigeres nedenfor.';
	@override String get customTemplatesDescriptionOff => 'Standardmalene er aktive. De egendefinerte malene dine beholdes til senere.';
	@override String get type => 'Eksporttype';
	@override String get defaults => 'Standardinnstillinger';
	@override String get includeLookupData => 'Ta med oppslagsdata';
	@override String get customTemplates => 'Egendefinerte maler';
	@override String get filenameTemplate => 'Filnavnsmal';
	@override String get compactFilenameTemplate => 'Mal for kompakt filnavn';
	@override String get titleTemplate => 'Tittelmal';
	@override String get adifNotesTemplate => 'ADIF QSO-notater';
	@override String get adifCommentTemplate => 'ADIF QSO-kommentarer';
	@override String get adifQslMessageTemplate => 'ADIF QSL-melding';
	@override String get shared => 'Innstillingene gjelder for alle utvidelser som bruker denne eksporttypen.';
	@override String get defaultTemplates => 'Slå på Egendefinerte maler for å redigere malene for denne typen.';
}

// Path: templateEditor
class _Translations$templateEditor$nb extends Translations$templateEditor$en {
	_Translations$templateEditor$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Forhåndsvisning:';
	@override String get reset => 'Tilbakestill';
	@override String get docs => 'Dokumentasjon for maler';
	@override String get preview => 'Eksempelvisning';
	@override String get reference => 'Malreferanse';
	@override String get attributes => 'Tilgjengelige attributter';
	@override String get filters => 'Filtre';
	@override String get flowControl => 'Flytkontroll';
	@override String get unavailable => 'Forhåndsvisning er utilgjengelig til utvidelsene er klare.';
	@override String get empty => '(tomt resultat)';
}

// Path: home.nav
class _Translations$home$nav$nb extends Translations$home$nav$en {
	_Translations$home$nav$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operasjoner';
	@override String get chase => 'Jakt';
	@override String get logs => 'Logger';
	@override String get maps => 'Kart';
	@override String get settings => 'Innstillinger';
}

// Path: home.panels
class _Translations$home$panels$nb extends Translations$home$panels$en {
	_Translations$home$panels$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operasjonsliste';
	@override String get operationsDescription => 'Operasjonene dine, nyeste først.';
	@override String get version => 'Gjeldende versjon';
	@override String get versionDescription => 'Ham2K-merket, navnet på denne appen og hvilken build du kjører.';
}

// Path: home.logs
class _Translations$home$logs$nb extends Translations$home$logs$en {
	_Translations$home$logs$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logger';
	@override String get titleFor => 'Logger for';
	@override String get emptyCallsigns => 'Ingen QSOer logget ennå';
	@override String emptyQsos({required Object call}) => 'Ingen QSOer for ${call}';
	@override String get mapNoSelection => 'Velg en QSO for å se den på kartet';
	@override String get searchHint => 'Søk etter kallesignal eller navn';
	@override String get noSearchMatches => 'Ingen QSOer samsvarer med søket';
	@override String get titleAll => 'Alle logger';
	@override String get allCallsigns => 'Alle kallesignaler';
	@override String get noOperation => 'Ikke del av en operasjon';
	@override String get unsavedTitle => 'Ulagrede endringer';
	@override String get unsavedBody => 'Denne QSOen har endringer du ikke har lagret.';
	@override String get pendingDeleteBody => 'Denne QSOen er merket for sletting.';
	@override String get editGone => 'Ikke lagret: den QSOen finnes ikke lenger i denne loggen.';
	@override String get discard => 'Forkast';
	@override late final _Translations$home$logs$columns$nb columns = _Translations$home$logs$columns$nb._(_root);
	@override late final _Translations$home$logs$panels$nb panels = _Translations$home$logs$panels$nb._(_root);
	@override late final _Translations$home$logs$import$nb import = _Translations$home$logs$import$nb._(_root);
}

// Path: chase.station
class _Translations$chase$station$nb extends Translations$chase$station$en {
	_Translations$chase$station$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jaktstasjon';
	@override String get stationLabel => 'Stasjon: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Ingen posisjon';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$nb extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get today => 'i dag';
	@override String get thisWeek => 'denne uken';
	@override String get last14Days => 'de siste 14 dagene';
	@override String get thisMonth => 'denne måneden';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$nb extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistikk for i dag';
	@override String get thisWeek => 'Statistikk for denne uken';
	@override String get last14Days => 'Statistikk for de siste 14 dagene';
	@override String get thisMonth => 'Statistikk for denne måneden';
}

// Path: chase.period
class _Translations$chase$period$nb extends Translations$chase$period$en {
	_Translations$chase$period$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get today => 'I dag';
	@override String get thisWeek => 'Denne uken';
	@override String get last14Days => 'Siste 14 dager';
	@override String get thisMonth => 'Denne måneden';
}

// Path: chase.goals
class _Translations$chase$goals$nb extends Translations$chase$goals$en {
	_Translations$chase$goals$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jaktmål';
	@override String remove({required Object name}) => 'Slutt å jakte ${name}';
	@override String get extensionsTitle => 'Utvidelser som støtter jakt';
}

// Path: chase.panels
class _Translations$chase$panels$nb extends Translations$chase$panels$en {
	_Translations$chase$panels$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOer';
	@override String get loggingDescription => 'Loggekontroller over QSOene jaktet i perioden.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Kallesignalet som logges, eller statistikken for perioden.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Stasjoner spottet på lufta, klare til å jaktes.';
	@override String get map => 'Kart';
	@override String get mapDescription => 'Periodens QSOer og stasjonen som logges.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$nb extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Ugyldig kallesignal: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Ugyldige kallesignaler: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} har vært operatør så langt. ${typed} blir registrert for nye kontakter.';
	@override String operatorNoneSoFar({required Object typed}) => 'Ingen operatør registrert så langt. ${typed} blir registrert for nye kontakter.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Denne operasjonen har allerede kontakter av ${calls}. ${typed} blir bare registrert for nye.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Registrer også ${typed} som operatør for kontakten som allerede er logget',
		other: 'Registrer også ${typed} som operatør for alle ${count} kontaktene som allerede er logget',
	);
	@override String get operatorSeveralStations => 'Når flere stasjonskallesignaler brukes på lufta, støttes ikke egne operatører';
	@override String get contactsUnreadable => 'Kontaktene i denne operasjonen kunne ikke leses, så en endring av kallesignal her tilbyr ikke å oppdatere dem';
	@override String restampFailed({required Object error}) => 'Kontaktene som allerede er logget, kunne ikke oppdateres, så ingen endringer ble gjort: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} av ${planned} kontakter ble oppdatert — resten finnes ikke lenger i denne operasjonen';
}

// Path: operation.tabs
class _Translations$operation$tabs$nb extends Translations$operation$tabs$en {
	_Translations$operation$tabs$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOer';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'KART';
	@override String get qsosPlain => 'QSOer';
	@override String get clock => 'Klokke';
	@override String get weather => 'Vær';
	@override String get website => 'Nettsted';
	@override String get remoteScreen => 'Fjernskjerm';
	@override String get solar => 'Sol';
	@override String get radio => 'Radio';
}

// Path: operation.positions
class _Translations$operation$positions$nb extends Translations$operation$positions$en {
	_Translations$operation$positions$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Ingen andre operatørplasser deler denne operasjonen ennå.';
	@override String positionLabel({required Object number}) => 'Plass: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'En annen plass';
	@override String get thisDevice => 'Vår operatørplass';
	@override String get nameIn => ' i ';
	@override String get panelTitle => 'Operatørplasser';
	@override String get panelDescription => 'Hva hver operatørplass som deler denne operasjonen, logger akkurat nå.';
}

// Path: operation.menu
class _Translations$operation$menu$nb extends Translations$operation$menu$en {
	_Translations$operation$menu$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Vis RST-felt';
	@override String get showStateField => 'Vis stat-felt';
	@override String get showGridField => 'Vis grid-felt';
	@override String get showDeletedQsos => 'Vis slettede QSOer';
	@override String get showDeletedOps => 'Vis slettede operasjoner';
	@override String get showQsoNumbers => 'Vis QSO-nummer';
	@override String get lookupAllQsos => 'Slå opp alle QSOer';
	@override String get loggingSettingsTitle => 'Loggingsinnstillinger';
	@override String get mapSettingsTitle => 'Kartinnstillinger';
	@override String get actionsSection => 'Handlinger';
}

// Path: operation.layout
class _Translations$operation$layout$nb extends Translations$operation$layout$en {
	_Translations$operation$layout$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Legg til et panel';
	@override String get availableSection => 'Tilgjengelige paneler';
	@override String panelSettings({required Object panel}) => 'Innstillinger for ${panel}';
	@override String get panelSettingsAction => 'Panelinnstillinger';
	@override String get viewName => 'Operasjonsvisning';
	@override String get viewOptions => 'Alternativer for visningsoppsett';
	@override String get viewTitleBuiltIn => 'Denne visningen er innebygd i appen, og det er navnet også';
	@override String get resetOptions => 'Gjenopprett standard';
	@override String get removePane => 'Fjern';
	@override String resetPaneConfirm({required Object panel}) => 'Gjenopprette standardinnstillingene for ${panel}?';
	@override String get resetPaneConfirmBody => 'Tittelen, toppteksten og størrelsen går tilbake til standard. Resten av oppsettet blir som det er.';
	@override String get resetViewConfirm => 'Gjenopprette standardoppsettet for denne visningen?';
	@override String get resetViewConfirmBody => 'Panelene går tilbake til standardplasseringen, og alternativene for visningen og hvert panel går tilbake til standard.';
	@override String paneOptionsTitle({required Object panel}) => 'Oppsettinnstillinger for ${panel}';
	@override String get paneTitle => 'Tittel';
	@override String get paneShowHeader => 'Vis topptekst';
	@override String get paneShowHeaderTabset => 'Vises alltid mens dette panelet deler en gruppe — toppteksten er veien til de andre';
	@override String get paneInherit => 'Samme som appen';
	@override String get searchHint => 'Søk i paneler';
	@override String get noPanelsMatch => 'Ingen paneler samsvarer med søket.';
	@override String get nothingToAdd => 'Denne visningen har allerede alle mulige paneler';
	@override String addPanel({required Object panel}) => 'Legg til ${panel}';
	@override String showPreview({required Object panel}) => 'Forhåndsvis ${panel}';
	@override String missingExtension({required Object name}) => 'Utvidelsen "${name}" mangler';
	@override String get previewUnavailable => 'Forhåndsvisningen av dette panelet kunne ikke vises.';
	@override String get nestedPaneTitle => 'Mer';
	@override String get editLayout => 'Rediger oppsett';
	@override String get saveLayout => 'Lagre oppsett';
	@override String get revertLayout => 'Forkast endringer i oppsettet';
	@override String get done => 'Ferdig';
	@override String get layoutUnreadableTitle => 'Oppsettet kunne ikke leses';
	@override String get layoutUnreadableBody => 'Det lagrede oppsettet ditt kunne ikke leses, så standardoppsettet vises i stedet. Originalen blir ikke overskrevet før du velger å beholde dette.';
	@override String get layoutUnreadableAction => 'Bruk dette oppsettet';
	@override String panelRenderFailed({required Object panel}) => '${panel} kunne ikke vises';
	@override String get panelRenderRetry => 'Prøv igjen';
	@override String get panelActionFailed => 'Panelhandlingen mislyktes. Prøv igjen.';
	@override late final _Translations$operation$layout$panels$nb panels = _Translations$operation$layout$panels$nb._(_root);
	@override String get htmlPanelUnsupported => 'Dette panelet trenger en nettvisning, som denne plattformen ikke har';
	@override String get htmlPanelUnsupportedOnWeb => 'Dette panelet trenger en sandkasse som nettversjonen ikke kan tilby';
}

// Path: operation.export
class _Translations$operation$export$nb extends Translations$operation$export$en {
	_Translations$operation$export$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Eksport av operasjon';
	@override String get syncedOperation => 'Operasjonen er synkronisert';
	@override String get unsyncedOperation => 'Operasjonen har endringer som ikke er synkronisert';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} QSO i denne operasjonen',
		other: '${count} QSOer i denne operasjonen',
	);
	@override String qsosSynced({required Object total}) => 'Alle ${total} QSOer er synkronisert';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} av ${total} QSOer venter på synkronisering';
	@override String eventsSynced({required Object total}) => '${total} hendelsesmarkører synkronisert';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} av ${total} hendelsesmarkører venter';
	@override String get loading => 'Laster eksportalternativer…';
	@override String get noOptions => 'Ingen eksportformater tilgjengelig (starter utvidelsene fortsatt?)';
	@override String get nothingLogged => 'Ingenting å eksportere ennå — denne operasjonen har ingen QSOer.';
	@override String get share => 'Del';
	@override String get nothingSelected => 'Ingenting valgt';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Lagre ${count} fil',
		other: 'Lagre ${count} filer',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Del ${count} fil',
		other: 'Del ${count} filer',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Eksporter ${count} fil',
		other: 'Eksporter ${count} filer',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Last ned ${count} fil',
		other: 'Last ned ${count} filer',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Lagre ${count} samlet fil',
		other: 'Lagre ${count} samlede filer',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Del ${count} samlet fil',
		other: 'Del ${count} samlede filer',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Eksporter ${count} samlet fil',
		other: 'Eksporter ${count} samlede filer',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Last ned ${count} samlet fil',
		other: 'Last ned ${count} samlede filer',
	);
	@override String saveOne({required Object name}) => 'Lagre ${name}';
	@override String shareOne({required Object name}) => 'Del ${name}';
	@override String exportOne({required Object name}) => 'Eksporter ${name}';
	@override String downloadOne({required Object name}) => 'Last ned ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Legg ${count} fil i Stash',
		other: 'Legg ${count} filer i Stash',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Legg ${count} samlet fil i Stash',
		other: 'Legg ${count} samlede filer i Stash',
	);
	@override String get settingsButton => 'Eksportinnstillinger';
	@override String get settingsTitle => 'Eksportinnstillinger';
	@override late final _Translations$operation$export$compactFileNames$nb compactFileNames = _Translations$operation$export$compactFileNames$nb._(_root);
	@override late final _Translations$operation$export$includePrivateData$nb includePrivateData = _Translations$operation$export$includePrivateData$nb._(_root);
	@override String get resultTitle => 'Eksport fullført';
	@override String get resultFailedTitle => 'Eksport mislyktes';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Eksporterte ${count} fil til ${path}',
		other: 'Eksporterte ${count} filer til ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Eksporterte ${count} fil: ${path}',
		other: 'Eksporterte ${count} filer: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Delte ${count} fil',
		other: 'Delte ${count} filer',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Lastet ned ${count} fil',
		other: 'Lastet ned ${count} filer',
	);
	@override String exportFailed({required Object error}) => 'Eksport mislyktes: ${error}';
	@override late final _Translations$operation$export$stash$nb stash = _Translations$operation$export$stash$nb._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$nb extends Translations$operation$spots$en {
	_Translations$operation$spots$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ingen spots samsvarer med filtrene dine';
	@override String error({required Object error}) => 'Kunne ikke laste spots: ${error}';
	@override String get unknownBand => 'Annet';
	@override String get auto => 'Automatisk';
	@override String autoValue({required Object value}) => 'Automatisk (for øyeblikket ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Alle';
	@override String get allBands => 'Alle bånd';
	@override String get allModes => 'Alle moduser';
	@override String get phoneAndCw => 'Telefoni og CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Viser ${count} av ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutter';
	@override String get callsOfNote => 'Kjente kallesignaler';
	@override String get yourSpots => 'Dine spots';
	@override String get allSpots => 'Alle spots';
	@override late final _Translations$operation$spots$continents$nb continents = _Translations$operation$spots$continents$nb._(_root);
	@override late final _Translations$operation$spots$filters$nb filters = _Translations$operation$spots$filters$nb._(_root);
	@override String get unavailableTitle => 'Spots utilgjengelige';
	@override String unavailableText({required Object sources}) => '${sources} svarte ikke.';
	@override String get failedTitle => 'Feil fra spot-kilde';
	@override String failedText({required Object sources}) => '${sources} returnerte en feil.';
	@override String get slideLogIt => 'Logg den';
	@override String get slideIgnore => 'Ignorer';
	@override String get slideRestore => 'Gjenopprett';
	@override late final _Translations$operation$spots$logConflict$nb logConflict = _Translations$operation$spots$logConflict$nb._(_root);
}

// Path: operation.import
class _Translations$operation$import$nb extends Translations$operation$import$en {
	_Translations$operation$import$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importer data til operasjonen';
	@override String get importAdifAction => 'Importer QSOer fra ADIF';
	@override String get settingsButton => 'Lytteinnstillinger';
	@override String get settingsTitle => 'Lytt etter andre apper';
	@override String get protocolAddressLabel => 'Adresse';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Oppgi en port mellom 1 og 65535';
	@override String get protocolAddressInvalid => 'Oppgi en gyldig IP-adresse (f.eks. 127.0.0.1 eller 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Mottar data';
	@override String get protocolStatusNoData => 'Ingen data mottatt nylig';
	@override String protocolBindError({required Object error}) => 'Kunne ikke begynne å lytte: ${error}';
	@override String captureFailed({required Object error}) => 'Innkommende QSOer kunne ikke lagres og forsøkes på nytt: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Alle (kringkasting)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → fanen Broadcast Data → kryss av for "Enable Broadcasts" for kontaktinfo. Sett IP-adressen til 127.0.0.1 hvis programmet kjører på samme datamaskin, eller 255.255.255.255 for å kringkaste på det lokale nettverket.';
	@override String get helpWsjtxSetup => 'File → Settings → fanen Reporting → seksjonen UDP Server → kryss av for "Accept UDP requests". Sett UDP Server til 127.0.0.1 hvis programmet kjører på samme datamaskin, eller en multicast-adresse som 239.239.0.2, og bruk samme adresse i oppsettet ovenfor i denne appen.';
	@override String get listenTitle => 'Lytt etter QSOer fra andre apper';
	@override String get listenDescriptionOnN1mm => 'Lytter etter N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Lytter etter WSJT-X';
	@override String get listenDescriptionOnBoth => 'Lytter etter N1MM+ og WSJT-X';
	@override String get listenDescriptionOff => 'Av';
	@override String get addToOperationTitle => 'Legg til i denne operasjonen';
	@override String get addToOperationDescriptionOn => 'Mottatte QSOer legges til i denne operasjonen etter hvert som de kommer';
	@override String get addToOperationDescriptionOff => 'Mottatte QSOer holdes tilbake til du slår på dette';
	@override String get pendingSectionTitle => 'Mottatte QSOer';
	@override String get pendingEmpty => 'Ingenting mottatt ennå';
	@override String stationMismatch({required Object call}) => 'Logget som ${call}, ikke stasjonen til denne operasjonen';
	@override String get discardAction => 'Forkast';
	@override String get gapDialogTitle => 'Ta med tidligere mottatte?';
	@override String gapDialogBody({required Object count}) => '${count} QSOer til ble mottatt tidligere, før et opphold i dataene. Ta med dem også?';
	@override String get gapDialogRecentOnly => 'Bare de nyeste';
	@override String gapDialogIncludeAll({required Object count}) => 'Ta med alle ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$nb extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get link => 'Feil?';
	@override String get title => 'Rapporter en feil i et omriss';
	@override String get reference => 'Hvilket omriss';
	@override String get severity => 'Hvor ille er det?';
	@override String get minor => 'Liten detalj';
	@override String get major => 'Stor feil';
	@override String get explanation => 'Hva er galt med det?';
	@override String get explanationHint => 'Hva omrisset har feil, og hvor';
	@override String get send => 'Send';
	@override String get sending => 'Sender rapporten din — takk';
	@override String get copy => 'Kopier rapport';
	@override String get notSent => 'Kunne ikke sende rapporten';
	@override String get copied => 'Rapporten er kopiert';
	@override String get notCopied => 'Kunne ikke kopiere rapporten';
}

// Path: map.postcard
class _Translations$map$postcard$nb extends Translations$map$postcard$en {
	_Translations$map$postcard$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get button => 'Operasjonspostkort';
	@override String title({required Object title}) => 'Postkort for ${title}';
	@override String get portrait => 'Stående';
	@override String get landscape => 'Liggende';
	@override String get square => 'Kvadratisk';
	@override String get save => 'Lagre…';
	@override String get download => 'Last ned';
	@override String get share => 'Del';
	@override String get copy => 'Kopier';
	@override String get copied => 'Kopiert til utklippstavlen';
	@override String saved({required Object path}) => 'Lagret i ${path}';
	@override String downloaded({required Object name}) => 'Lastet ned ${name}';
	@override String savedMany({required Object count, required Object path}) => 'Lagret ${count} bilder i ${path}';
	@override String savedFiles({required Object names}) => 'Lagret ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} var allerede lagret';
	@override String downloadedMany({required Object count}) => 'Laster ned ${count} bilder — tillat dem hvis nettleseren spør';
	@override String get mapLeftOut => 'Kartet ble ikke lastet, så det ble utelatt';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — kartet ble ikke lastet, så det ble utelatt';
	@override String continued({required Object title}) => '${title} (fortsettelse)';
	@override String get previousPage => 'Forrige side';
	@override String get nextPage => 'Neste side';
	@override String pageOf({required Object page, required Object count}) => 'Side ${page} av ${count}';
	@override String get sectionDays => 'Hver dag';
	@override String get reset => 'Tilbakestill';
	@override String failed({required Object error}) => 'Kunne ikke lage postkortet: ${error}';
	@override String get mapNotReady => 'Kartet ble ikke ferdig lastet. Sjekk tilkoblingen og prøv igjen.';
	@override String saveFailed({required Object error}) => 'Kunne ikke lagre postkortet: ${error}';
	@override String get copyFailed => 'Utklippstavlen tok ikke imot bildet. Prøv igjen.';
	@override String get shareFailed => 'Kunne ikke dele postkortet. Prøv igjen.';
	@override String get fileName => 'postkort';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$nb extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Ingen QSOer ennå... la oss gå på lufta!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOer';
	@override String qsosInTime({required Object count, required Object time}) => '${count} på ${time}';
	@override String sinceLast({required Object time}) => '${time} siden sist';
	@override String ratePer10({required Object rate}) => '${rate} Q/t for siste 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/t for siste 100';
	@override String distanceTo({required Object distance}) => '${distance} til';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) til';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) til';
	@override String distanceAway({required Object distance}) => '${distance} unna';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) unna';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) unna';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplikat!';
	@override String get noticeNewBand => 'Nytt bånd';
	@override String get noticeNewMode => 'Ny modus';
	@override String get noticeNewDXCC => 'Ny DXCC';
	@override String get noticeNewState => 'Ny stat';
	@override String get noticeNewProvince => 'Ny provins';
	@override String get noticeNewDay => 'Ny dag';
	@override String get noticeNewRef => 'Ny ref.';
	@override String get noticeNewMult => 'Ny mult';
	@override String get noticeNewZone => 'Ny sone';
	@override String get noticeInvalidMode => 'Feil modus';
	@override String get noticeInvalidBand => 'Feil bånd';
	@override String get noticeInvalidCategory => 'Kan ikke kjøres';
	@override String get noticeWorkedBefore => 'Kjørt før';
	@override String get noticeNewPark => 'Ny park';
	@override String get noticeNewSection => 'Ny seksjon';
	@override String get noticeBonusStation => 'Bonusstasjon!';
	@override String get noticeMissingExchange => 'Ingen utveksling';
	@override String get noticeInvalidExchange => 'Ugyldig utveksling';
	@override String get noticeUnknownEvent => 'Ukjent arrangement';
	@override String get noticeOurGrid => 'Angi vår grid';
	@override String get noticeRareCounty => 'Sjeldent fylke!';
	@override String get noticeOurLocation => 'Angi vårt fylke';
	@override String get noticeShortGrid => 'Grid for kort';
}

// Path: callInfo.history
class _Translations$callInfo$history$nb extends Translations$callInfo$history$en {
	_Translations$callInfo$history$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} i løpet av de siste 7 dagene';
	@override String today({required Object n}) => '${n} i dag';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${n} QSO',
		other: '${n} QSOer',
	);
}

// Path: settings.theme
class _Translations$settings$theme$nb extends Translations$settings$theme$en {
	_Translations$settings$theme$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tema';
	@override String get system => 'Følg systeminnstillingene';
	@override String get light => 'Lyst';
	@override String get dark => 'Mørkt';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$nb extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get system => 'Følger systeminnstillingene';
	@override String get light => 'Alltid i lys modus';
	@override String get dark => 'Alltid i mørk modus';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$nb extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Minste--';
	@override String get smallestMinus => 'Minste-';
	@override String get smallest => 'Minste';
	@override String get smaller => 'Mindre';
	@override String get normal => 'Normal';
	@override String get larger => 'Større';
	@override String get largest => 'Største';
	@override String get largestPlus => 'Største+';
	@override String get largestPlusPlus => 'Største++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$nb extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hold enheten våken';
	@override String get descriptionOn => 'Holder seg våken mens du er i loggevisningen eller en synkronisering pågår';
	@override String get descriptionOff => 'Går i dvale som vanlig';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$nb extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatisk';
	@override String get densest => 'Tettest';
	@override String get dense => 'Tett';
	@override String get normal => 'Normal';
	@override String get sparse => 'Luftig';
	@override String get sparsest => 'Luftigst';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$nb extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometer';
	@override String get miles => 'Miles';
}

// Path: settings.logging
class _Translations$settings$logging$nb extends Translations$settings$logging$en {
	_Translations$settings$logging$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logging';
	@override late final _Translations$settings$logging$leftieMode$nb leftieMode = _Translations$settings$logging$leftieMode$nb._(_root);
	@override late final _Translations$settings$logging$countryFlags$nb countryFlags = _Translations$settings$logging$countryFlags$nb._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$nb countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$nb._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$nb suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$nb._(_root);
	@override late final _Translations$settings$logging$showBearing$nb showBearing = _Translations$settings$logging$showBearing$nb._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$nb showReverseBearing = _Translations$settings$logging$showReverseBearing$nb._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$nb switchSentRcvd = _Translations$settings$logging$switchSentRcvd$nb._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$nb jumpAfterRST = _Translations$settings$logging$jumpAfterRST$nb._(_root);
	@override late final _Translations$settings$logging$defaultReport$nb defaultReport = _Translations$settings$logging$defaultReport$nb._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$nb defaultReportCW = _Translations$settings$logging$defaultReportCW$nb._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$nb defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$nb._(_root);
	@override late final _Translations$settings$logging$numbersRow$nb numbersRow = _Translations$settings$logging$numbersRow$nb._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$nb numbersRowExtra = _Translations$settings$logging$numbersRowExtra$nb._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$nb numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$nb._(_root);
	@override String get bands => 'Foretrukne bånd';
	@override String get modes => 'Foretrukne moduser';
}

// Path: settings.catServer
class _Translations$settings$catServer$nb extends Translations$settings$catServer$en {
	_Translations$settings$catServer$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-server';
	@override String get description => 'La andre apper (WSJT-X, loggeprogrammer osv.) styre radioen gjennom Ham2K Logger.';
	@override String get protocol => 'Protokoll';
	@override late final _Translations$settings$catServer$protocolOpts$nb protocolOpts = _Translations$settings$catServer$protocolOpts$nb._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Åpen tilgang';
	@override String get openAccessOn => 'Alle datamaskiner på det lokale nettverket kan koble til.';
	@override String get openAccessOff => 'Bare apper på denne datamaskinen kan koble til.';
	@override String get off => 'Av.';
	@override String starting({required Object protocol}) => '${protocol}, starter…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} på port ${port}. Tilkoblede klienter: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} på port ${port}, men ingen Main VFO-radio er tilkoblet.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} kan ikke lytte på port ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} kan ikke lytte på port ${port}: et annet program bruker den, ofte ${protocol} selv. Lukk det programmet eller velg en annen port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} kan ikke lytte på port ${port}: denne datamaskinen tillater det ikke. Velg en port over 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} sluttet å lytte på port ${port}. Prøver igjen…';
}

// Path: settings.radio
class _Translations$settings$radio$nb extends Translations$settings$radio$en {
	_Translations$settings$radio$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-styring';
	@override String get loggingAndCat => 'Logging og CAT';
	@override String get tuningSection => 'Avstemming';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Tjenester';
	@override String get stationConfigurationSection => 'Stasjonsoppsett';
	@override String get moreSettings => 'Flere innstillinger for stasjonsoppsett';
	@override late final _Translations$settings$radio$units$nb units = _Translations$settings$radio$units$nb._(_root);
	@override late final _Translations$settings$radio$pttKey$nb pttKey = _Translations$settings$radio$pttKey$nb._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$nb smartVfoSnap = _Translations$settings$radio$smartVfoSnap$nb._(_root);
	@override late final _Translations$settings$radio$snapDebounce$nb snapDebounce = _Translations$settings$radio$snapDebounce$nb._(_root);
	@override late final _Translations$settings$radio$snapLongMove$nb snapLongMove = _Translations$settings$radio$snapLongMove$nb._(_root);
	@override late final _Translations$settings$radio$snapMinMove$nb snapMinMove = _Translations$settings$radio$snapMinMove$nb._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$nb snapMinSpeed = _Translations$settings$radio$snapMinSpeed$nb._(_root);
	@override late final _Translations$settings$radio$enterSends$nb enterSends = _Translations$settings$radio$enterSends$nb._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$nb keyerSpeed = _Translations$settings$radio$keyerSpeed$nb._(_root);
	@override late final _Translations$settings$radio$cwMessages$nb cwMessages = _Translations$settings$radio$cwMessages$nb._(_root);
	@override late final _Translations$settings$radio$voiceMessages$nb voiceMessages = _Translations$settings$radio$voiceMessages$nb._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$nb avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$nb._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$nb zeroBeatRange = _Translations$settings$radio$zeroBeatRange$nb._(_root);
}

// Path: settings.help
class _Translations$settings$help$nb extends Translations$settings$help$en {
	_Translations$settings$help$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hjelp og ressurser';
	@override String get description => 'Fellesskap og brukerstøtte';
	@override String get forums => 'Ham2K-forum';
	@override String get forumsDescription => 'Finn hjelp, gi tilbakemelding, diskuter ideer…';
	@override String get chat => 'Ham2K-chat';
	@override String get chatDescription => 'Discord-serveren for nettfellesskapet vårt';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videoer og direktesendinger';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Fordi du ikke kan ha for mange bilder…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Følg oss for nyheter og oppdateringer';
	@override String get contact => 'Kontakt oss';
	@override String get contactDescription => 'help@ham2k.com — men prøv forumet eller chatten først!';
}

// Path: settings.exports
class _Translations$settings$exports$nb extends Translations$settings$exports$en {
	_Translations$settings$exports$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Eksport';
}

// Path: settings.map
class _Translations$settings$map$nb extends Translations$settings$map$en {
	_Translations$settings$map$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kart';
	@override late final _Translations$settings$map$style$nb style = _Translations$settings$map$style$nb._(_root);
	@override late final _Translations$settings$map$styleOpts$nb styleOpts = _Translations$settings$map$styleOpts$nb._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$nb extends Translations$settings$privacy$en {
	_Translations$settings$privacy$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Personvern';
	@override late final _Translations$settings$privacy$shareAppData$nb shareAppData = _Translations$settings$privacy$shareAppData$nb._(_root);
	@override late final _Translations$settings$privacy$shareOpData$nb shareOpData = _Translations$settings$privacy$shareOpData$nb._(_root);
	@override String get privacyPolicy => 'Personvernpolicy';
	@override String get termsOfService => 'Tjenestevilkår';
}

// Path: settings.sync
class _Translations$settings$sync$nb extends Translations$settings$sync$en {
	_Translations$settings$sync$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Skysynkronisering';
	@override String get moreSettings => 'Flere synkroniseringsinnstillinger';
	@override String get enable => 'Aktiver synkronisering';
	@override String get deviceKey => 'Enhetsnøkkel';
}

// Path: settings.peers
class _Translations$settings$peers$nb extends Translations$settings$peers$en {
	_Translations$settings$peers$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Andre enheter';
	@override String get enable => 'Koble til andre enheter';
	@override String get enableDescription => 'Tillat deling av operasjoner, logging, CAT og GPS med andre enheter over det lokale nettverket';
	@override String get bleEnable => 'Koble til over Bluetooth';
	@override String get bleDescription => 'Bruk Bluetooth LE for å koble til selv om det ikke finnes noe lokalt nettverk';
	@override String get thisDevice => 'Denne enheten';
	@override String get deviceName => 'Navn';
	@override String get deviceNameHint => 'Hvordan denne enheten vises for andre enheter';
	@override String get pairedDevices => 'Koblede enheter';
	@override String get noPairedDevices => 'Ingen enheter koblet ennå. Slå på dette på en annen enhet på dette nettverket for å koble dem sammen.';
	@override String deviceListProblem({required Object error}) => 'Kan ikke lese de koblede enhetene dine: ${error}';
	@override String get nearby => 'I nærheten';
	@override String get connected => 'Tilkoblet';
	@override String get viaBluetooth => 'via Bluetooth';
	@override String get connecting => 'Kobler til…';
	@override String get syncing => 'Synkroniserer…';
	@override String get waitingForThem => 'Venter på den andre enheten';
	@override String get notConnected => 'Ikke tilkoblet';
	@override String get wantsToPair => 'vil dele denne operasjonen';
	@override String get allow => 'Tillat';
	@override String get link => 'Koble';
	@override String get reject => 'Avvis';
	@override String get forget => 'Glem';
	@override String forgetTitle({required Object name}) => 'Glemme ${name}?';
	@override String get forgetBody => 'Den slutter å synkronisere med denne enheten. Du kan tillate den igjen senere, og kontakter som allerede er logget, beholdes.';
	@override String pairTitle({required Object name}) => 'Koble til ${name}';
	@override String get pairBody => 'Denne enheten er på det lokale nettverket ditt og vil koble til.';
	@override String get pairBodyBle => 'Denne enheten er i nærheten og vil koble til over Bluetooth LE.';
	@override String get pairIdLabel => 'Enhets-ID';
	@override String get pairWarning => 'Koble bare til enheter du kjenner igjen. Alle enheter på dette nettverket kan sende en forespørsel.';
	@override String get pairWarningBle => 'Koble bare til enheter du kjenner igjen. Alle enheter i nærheten kan sende en forespørsel.';
	@override String problem({required Object error}) => 'Kan ikke nå det lokale nettverket: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Koblet til ${device}';
	@override String statusLost({required Object device}) => 'Mistet forbindelsen til ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Andre enheter: ${connected} av ${linked} tilkoblet';
	@override String get screenEnable => 'Del skjermer og vinduer';
	@override String get screenDescription => 'Tillat andre enheter å vise skjermer eller vinduer fra denne datamaskinen';
	@override String get screenSources => 'Skjermer og vinduer';
	@override String get screenRefresh => 'Oppdater listen';
	@override String get screenUnsupportedPlatform => 'Denne enheten kan ikke dele skjermen sin. macOS kan det; alle enheter kan vise en skjerm som deles av en annen.';
	@override String get screenUnsupportedVersion => 'Skjermdeling krever macOS 12.3 eller nyere. Denne enheten kan likevel vise en skjerm som deles av en annen.';
	@override String get screenNeedsPermission => 'macOS trenger tillatelsen din til å ta opp skjermen før denne appen kan dele en.';
	@override String get screenGrantPermission => 'Be om tillatelse';
	@override String get screenRelaunchAfterGranting => 'Tillat det i Systeminnstillinger under Personvern og sikkerhet → Skjermopptak, og avslutt og åpne denne appen på nytt — macOS forteller bare en app om endringen neste gang den starter.';
	@override String screenProblem({required Object error}) => 'Skjermdeling: ${error}';
	@override String get screenChooseTitle => 'Velg hva som skal deles';
	@override String get screenChooseButton => 'Velg hva som skal deles…';
	@override String get screenTabScreens => 'Skjermer';
	@override String get screenTabApps => 'Apper';
	@override String get screenTabWindows => 'Vinduer';
	@override String get screenTabEmpty => 'Fant ingenting av denne typen.';
	@override String get screenSharedSummaryNone => 'Ingenting valgt ennå.';
	@override String get screenThisDevice => 'Denne enheten';
	@override String screenSharedTo({required Object devices}) => 'Vises på ${devices}';
	@override String get screenSharedToNobody => 'Vises ikke';
	@override String screenStopSharing({required Object name}) => 'Slutt å dele ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$nb extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Synkroniseringsoppsett';
	@override String get enableTitle => 'Synkroniser med Ham2K Log Filer';
	@override String get enabledDescription => 'Tar sikkerhetskopi av og synkroniserer loggen din mellom enheter';
	@override String get disabledDescription => 'Av — blir bare på denne enheten';
	@override String get syncing => 'Synkroniserer';
	@override String get account => 'Konto';
	@override String get refresh => 'Oppdater';
	@override String get switchAccounts => 'Bytt konto';
	@override String get switchAccountsDescription => 'Koble denne enheten til en annen konto med en QR-kode eller e-post';
	@override String get connectionRequests => 'Tilkoblingsforespørsler';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'En enhet venter på å bli med i denne kontoen',
		other: '${n} enheter venter på å bli med i denne kontoen',
	);
	@override String get accountEmailTitle => 'E-post for kontoen';
	@override String accountEmailSent({required Object email}) => 'Bekreftelse sendt til ${email}. Åpne lenken der for å fullføre endringen.';
	@override String get resendConfirmation => 'Send bekreftelses-e-post på nytt';
	@override String resendConfirmationDescription({required Object email}) => 'Venter på ${email}';
	@override String accountEmailResent({required Object email}) => 'Sendt på nytt til ${email}.';
	@override String get deviceLinked => 'Den enheten er nå koblet til denne kontoen.';
	@override String get checking => 'Sjekker…';
	@override String get notLinked => 'Ikke koblet ennå';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Erstatte lokale data?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${n} operasjon',
		other: '${n} operasjoner',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${n} QSO',
		other: '${n} QSOer',
	);
	@override String get counts => 'Synkroniserte data';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Denne enheten: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Venter på opplasting: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Denne enheten: sjekker…';
	@override String get countsServerChecking => 'Server: sjekker…';
	@override String get countsServerUnavailable => 'Server: ikke tilgjengelig';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Dette tar sikkerhetskopi av og fjerner ${operations} og ${qsos} fra denne enheten, og laster ned kontoens data i stedet. Sikkerhetskopien blir liggende i databasen på denne enheten.';
	@override String get replace => 'Erstatt';
	@override String get pendingBannerTitle => 'Ny Ham2K Log Filer-konto oppdaget';
	@override String get pendingBannerBody => 'Behold de eksisterende operasjonene og QSOene på denne enheten og slå dem sammen med kontoen, eller erstatt dem med kontoens data (en sikkerhetskopi blir liggende på denne enheten uansett).';
	@override String get combine => 'Kombiner';
	@override String get authIssueTitle => 'Synkroniseringen får ikke koblet til';
	@override String get authIssueText => 'Ham2K Log Filer avviser stadig denne enheten. Sjekk kallesignalet ditt i synkroniseringsinnstillingene.';
	@override String get openSettings => 'Åpne synkroniseringsinnstillinger';
}

// Path: settings.accounts
class _Translations$settings$accounts$nb extends Translations$settings$accounts$en {
	_Translations$settings$accounts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kontoer, tjenester og datakilder';
	@override String get none => 'Ingen aktive utvidelser med kontoer';
	@override String get notConfigured => 'Ikke satt opp';
	@override String get connected => 'Tilkoblet';
	@override String get cancelLogin => 'Avbryt innlogging';
	@override String get openInBrowser => 'Åpne i nettleser';
	@override String loggedInAs({required Object identity}) => 'Logget inn som ${identity}';
	@override String get pressSaveToKeep => 'Trykk Lagre for å beholde denne kontoen tilkoblet.';
	@override String connectedTo({required Object label}) => 'Koblet til ${label}';
	@override String get connect => 'Koble til';
	@override String get disconnect => 'Koble fra';
	@override String get connectedAs => 'Tilkoblet som';
	@override String get test => 'Test';
	@override String saveFailed({required Object error}) => 'Lagring mislyktes: ${error}';
	@override String loginFailed({required Object error}) => 'Innlogging mislyktes: ${error}';
	@override String get lookupFailed => 'Kontoer er utilgjengelige akkurat nå — prøv igjen om et øyeblikk';
	@override String get browserLoginTitle => 'Fullfør innloggingen i nettleseren';
	@override String browserLoginSteps({required Object prefix}) => 'Når du er ferdig, prøver nettleseren å åpne en lenke som begynner med "${prefix}". Datamaskinen din har mest sannsynlig ikke noe registrert for å åpne den, så kopier lenken (fra adressefeltet, eller fra feilsiden nettleseren viser) og lim den inn her.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger kunne ikke åpne nettleseren din. Kopier innloggingslenken nedenfor og åpne den selv, kopier deretter lenken den sender deg til (den begynner med "${prefix}") og lim den inn her.';
	@override String get copyLoginLink => 'Kopier innloggingslenke';
	@override String get pastedLinkLabel => 'Lim inn lenken her';
	@override String get finishLogin => 'Fullfør innlogging';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Det er ikke innloggingslenken — den skal begynne med "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Den lenken hører til et annet innloggingsforsøk. Lukk denne siden og koble til på nytt.';
	@override String get pastedLinkNoCode => 'Den lenken har ingen innloggingskode. Fullfør innloggingen først, og kopier så lenken den sender deg til.';
	@override String get pastedLinkMalformed => 'Den lenken ser ut til å være avkortet. Kopier hele lenken og lim den inn på nytt.';
	@override String get relayLoginWaiting => 'Venter på at du fullfører innloggingen — dette fortsetter automatisk når du gjør det.';
	@override String get loginNoResponse => 'Denne enheten har ikke fått svar fra innloggingen ennå. Hvis du allerede er ferdig i nettleseren, avbryt og prøv å koble til på nytt.';
	@override String get relayLoginNotOpened => 'Ham2K Logger kunne ikke åpne nettleseren automatisk. Bruk knappen nedenfor for å åpne innloggingssiden selv.';
	@override String get relayLoginUnavailable => 'Kunne ikke nå synkroniseringsserveren som trengs for å fullføre denne innloggingen. Sjekk tilkoblingen og prøv igjen.';
	@override String get loginIncompleteResponse => 'Det innloggingsforsøket ble ikke fullført riktig. Prøv å koble til på nytt.';
	@override String get noKeyringTitle => 'Kontoinnlogginger kan ikke lagres';
	@override String get noKeyringText => 'Ham2K Logger får ikke kontakt med en nøkkelringtjeneste på denne datamaskinen, så kontoinnlogginger kan ikke lagres eller leses — tilkobling av kontoer vil mislykkes til dette er ordnet. Installer og start **gnome-keyring**, **KWallet** eller **KeePassXC**, eller lås opp nøkkelringen du allerede har, og start på nytt. Logging, eksport og datafiler påvirkes ikke; loggsynkronisering er av så lenge dette varer.';
	@override String get noKeyringInline => 'Innlogginger kan ikke lagres: nøkkelringen på denne datamaskinen kan ikke nås. Installer og start gnome-keyring, KWallet eller KeePassXC, eller lås opp den du har.';
	@override String get noSecureStorageInline => 'Innlogginger kan ikke lagres: den sikre lagringen på denne datamaskinen kan ikke nås.';
}

// Path: settings.station
class _Translations$settings$station$nb extends Translations$settings$station$en {
	_Translations$settings$station$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stasjonsoppsett og CAT-styring';
	@override String get none => 'Ikke noe utstyr satt opp';
	@override String get add => 'Legg til';
	@override String get addTitle => 'Legg til utstyr';
	@override String get searchHint => 'Søk etter utstyr';
	@override String get noMatches => 'Ikke noe utstyr samsvarer';
	@override String get detectedEquipment => 'Oppdaget utstyr';
	@override String discoveryUnavailable({required Object error}) => 'Kan ikke lytte etter radioer: ${error}';
	@override String get edit => 'Rediger utstyr';
	@override String get name => 'Navn';
	@override String get nameDescription => 'Hva du kaller det — «Venstre radio». Valgfritt.';
	@override String get transport => 'Tilkobling';
	@override String get host => 'Adresse';
	@override String get hostDescription => 'Vertsnavnet eller IP-adressen til radioen på nettverket ditt.';
	@override String get port => 'Port';
	@override String get hostRequired => 'En adresse er påkrevd';
	@override String get portInvalid => 'Porten må være mellom 1 og 65535';
	@override String get connect => 'Koble til';
	@override String get disconnect => 'Koble fra';
	@override String get remove => 'Fjern';
	@override String removeTitle({required Object name}) => 'Fjerne ${name}?';
	@override String get removeMessage => 'Dette fjerner det bare fra appen. Innstillingene i utstyret forblir som de er.';
	@override String unknownType({required Object typeKey}) => 'Ukjent utstyrstype "${typeKey}"';
	@override String get report => 'Rapporter';
	@override String get reportTitle => 'Rapporter denne radioen';
	@override String get reportIntro => 'Fortell oss hvilken radio dette egentlig er, og hvordan det gikk. Rapporten din blir et kort som Ham2K-teamet leser, og det du skriver om hvordan du fikk den til å virke, kan komme til å hjelpe neste operatør med samme rigg.';
	@override String get reportManufacturer => 'Produsent';
	@override String get reportManufacturerDescription => 'Hvem som lager den — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'En produsent er påkrevd';
	@override String get reportModel => 'Modell';
	@override String get reportModelDescription => 'Modellen, slik radioen selv kaller den — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'En modell er påkrevd';
	@override String get reportOutcome => 'Hvordan gikk det?';
	@override String get reportOutcomeWorks => 'Virket bra';
	@override String get reportOutcomeIssues => 'Virket, med problemer';
	@override String get reportOutcomeFails => 'Virket ikke i det hele tatt';
	@override String get reportOutcomeRequired => 'Fortell oss hvordan det gikk';
	@override String get reportComments => 'Kommentarer';
	@override String get reportCommentsPlaceholder => 'Hva som virket, hva som ikke gjorde det, alt som overrasket deg.';
	@override String get reportHints => 'Feilsøkingstips';
	@override String get reportHintsPlaceholder => 'Vil du foreslå noen feilsøkingstips for andre brukere?';
	@override String get reportSend => 'Send rapport';
	@override String get reportSending => 'Sender rapporten din…';
	@override String reportSent({required Object ref}) => 'Takk — rapporten din ble registrert som ${ref}.';
	@override String get reportSentNoRef => 'Takk — rapporten din ble sendt.';
	@override String reportFailed({required Object error}) => 'Rapporten ble ikke sendt: ${error}';
	@override String get troubleshootingNotes => 'Feilsøkingsnotater';
	@override String get mainVfo => 'Hoved-VFO';
	@override String get useAsMainVfo => 'Bruk som hoved-VFO';
	@override String get serialPort => 'Seriellport';
	@override String get serialPortDescription => 'Porten der radioens CAT-grensesnitt vises.';
	@override String get serialPortNone => 'Fant ingen seriellporter';
	@override String get serialPortRequired => 'Velg en seriellport';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} av ${total}';
	@override String get serialPortSuggested => 'foreslått';
	@override String get serialPortJustNow => 'Nylig tilkoblet';
	@override String get serialDeviceRequest => 'Legg til en USB-enhet…';
	@override String get baudRate => 'Hastighet (baud)';
	@override String get baudRateDescription => 'Må samsvare med radioens CAT-meny. Ved avvik sender radioen tilbake søppel og ingen feilmelding.';
	@override String get serialRtsHigh => 'Hold RTS høy';
	@override String get serialRtsHighDescription => 'Bare for en radio som venter på RTS før den svarer, som en Yaesu med CAT RTS slått på. På Digirig, SignaLink og de fleste hjemmelagde kabler er RTS PTT, og å holde den høy gir sending.';
	@override String get serialDtrHigh => 'Hold DTR høy';
	@override String get serialDtrHighDescription => 'Bare for et CAT-grensesnitt som henter strøm fra DTR, som enkelte RS-232-kabler for FT-817. På mange kabler nøkler DTR CW eller PTT, og å holde den høy gir sending.';
	@override String get civAddress => 'Radioens CI-V-adresse';
	@override String get civAddressDescription => 'Heksadesimal, slik den vises i radioens CI-V-meny. IC-705 leveres med A4.';
	@override String get civAddressInvalid => 'En CI-V-adresse er to heksadesimale sifre, 01 til FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Hvilken av radioens slicer denne tilkoblingen leser fra og stiller inn.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Velg en av radioens slicer, A til H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} er ikke i bruk på denne radioen — velg en annen slice, eller opprett den i SmartSDR';
	@override String get channelNotInUse => 'ikke i bruk';
	@override String get channelHeldByUnknown => 'i bruk av et annet program';
	@override String get flexNoSlices => 'Denne radioen har ikke rapportert noen slicer — sjekk at SmartSDR kjører og at denne klienten får abonnere';
	@override String get spectrumUnsupported => 'Denne radioen sender ikke spektrum over CAT';
	@override String get spectrumRequiresBaud => 'Krever CAT på 115200 bps';
	@override String get spectrumNoRadio => 'Ingen radio tilkoblet';
	@override String get spectrumWaiting => 'Venter på spekteret fra radioen…';
	@override String get spectrumUnavailable => 'Spektrumvisning er ikke tilgjengelig';
	@override String get spectrumNoDaxChannel => 'Alle DAX IQ-kanaler på denne radioen er i bruk';
	@override String get spectrumNoPanadapter => 'Denne slicen har ingen panadapter på radioen';
	@override String spectrumStreamRefused({required Object code}) => 'Radioen avviste en DAX IQ-strøm (feil ${code})';
	@override String get spectrumNoUdp => 'Spektrumdataene fra radioen når ikke fram til denne enheten';
	@override String get spectrumScopeRefused => 'Radioen avviste scope-kommandoene';
	@override String get spectrumOutOfRange => 'Radioens scope er satt utenfor området den kan vise';
	@override String get n3fjpNoRig => 'N3FJP har ikke satt opp noe radiogrensesnitt, så dette følger det som skrives inn i N3FJP, ikke en radio';
	@override String get winkeyerKeyPort => 'Nøkleutgang';
	@override String get winkeyerKeyPortDescription => 'Hvilken av keyerens to utganger radioen din er koblet til.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Bruk keyerens PTT';
	@override String get winkeyerPttDescription => 'Nøkle PTT-linjen på samme kontakt, for et forsterkertrinn eller en radio som trenger det. La være av for en radio som nøkles på nøkkelkontakten.';
	@override String get winkeyerNoAnswer => 'Ingen WinKeyer svarte på denne porten';
	@override String get winkeyerStoppedAnswering => 'WinKeyer sluttet å svare under sending; meldingen ble forkastet';
	@override String get radioUser => 'Brukernavn på radioen';
	@override String get radioPass => 'Passord på radioen';
	@override String get radioLoginDescription => 'Radioens Network → Remote-innlogging, ikke WiFi-passordet ditt.';
	@override String get radioUserRequired => 'Brukernavnet for fjernstyring av radioen er påkrevd';
	@override String get connectFailedBusy => 'Enheten er i bruk';
	@override String get connectFailedDenied => 'Ingen tilgang';
	@override String get connectFailedDevice => 'Fant ikke enheten';
	@override String get connectFailedLines => 'RTS/DTR kunne ikke holdes som angitt, så porten ble lukket. Et annet program kan ha latt maskinvare-handshake stå på — koble kabelen fra og til igjen.';
	@override String get connectFailedNetwork => 'Finner ikke radioen på nettverket. Sjekk adressen, og at den er slått på og kan nås.';
	@override String get connectFailedTimeout => 'Radioen svarte ikke i tide. Sjekk at den er slått på og kan nås.';
	@override late final _Translations$settings$station$models$nb models = _Translations$settings$station$models$nb._(_root);
	@override late final _Translations$settings$station$transports$nb transports = _Translations$settings$station$transports$nb._(_root);
	@override String get troubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get ft891Troubleshooting => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT RTS må være AV på radioen** (FT-891-meny **05-08**). Når den er på, venter radioen på en handshake-linje som appen holder lav. På Digirig, SignaLink og de fleste hjemmelagde kabler er den samme linjen PTT, så å heve den ville nøkle senderen. På radioens egen USB-port er **Hold RTS høy** under Avanserte innstillinger alternativet.\n- **Hastigheten må samsvare** med radioens CAT RATE (meny **05-06**). Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get yaesuBinaryTroubleshooting => 'Denne radioen bruker Yaesus eldre CAT med fem byte, og den svarer ikke i det hele tatt når noe er feil. Nesten alltid en av disse:\n\n- **Kabelen må konvertere nivåer.** CAT-kontakten bak er verken RS-232 eller USB; den trenger en CT-62 eller en tilsvarende adapter. En vanlig lyd- eller datakabel virker ikke for CAT.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny (**#14** på FT-817, **#19** på FT-857 eller FT-897). Ved avvik sender radioen ingenting tilbake, og aldri en feilmelding.\n- **La aldri noe heve RTS eller DTR på denne porten.** På de fleste kabler for disse radioene er de linjene PTT og nøkling. Et eldre grensesnitt som får strøm fra DTR, er unntaket: slå på **Hold DTR høy** under Avanserte innstillinger for det.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\nDenne driveren er skrevet etter Yaesus publiserte CAT-tabell og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get guohetecTroubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get guohetecTroubleshooting => 'Q900 har to CAT-protokoller, og denne oppføringen bruker den opprinnelige i stedet for FT-817-etterligningen. Velg **Guohetec Q900** her, ikke en FT-817 — etterligningen støtter færre kommandoer, og radioen sier ikke hvilken den bruker.\n\n- **USB-C-kabelen er CAT-forbindelsen**, og den kobler til lydkortet også. Hastigheten spiller ingen rolle på den; porten ignorerer hva den er satt til.\n- **La aldri noe heve RTS eller DTR på denne porten.** På en seriellkabel er de linjene PTT og nøkling.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **En radio av andre generasjon oppfører seg annerledes** enn en av første. Trykk lenge på Menu, deretter About: HW 2.0 er andre generasjon.\n\nDenne driveren er skrevet etter produsentens publiserte protokoll og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get yaesuTroubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get yaesuTroubleshooting => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav. På Digirig, SignaLink og de fleste hjemmelagde kabler er den samme linjen PTT, så å heve den ville nøkle senderen. På radioens egen USB-port er **Hold RTS høy** under Avanserte innstillinger alternativet. Hvor den innstillingen ligger, varierer mellom modeller (meny **05-08** på FT-891).\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **Modusene følger tabellen for FT-891.** Det meste av Yaesu-serien samsvarer med den, men en radio som nummererer modusene sine annerledes, vil vise og sette feil modus for disse. Frekvensen påvirkes ikke.';
	@override String get yaesuRs232Troubleshooting => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT-kontakten er RS-232.** Den trenger en USB-til-seriell-adapter og en rett DB-9-kabel — en nullmodemkabel bytter om linjene, og radioen hører aldri noe.\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav, med mindre **Hold RTS høy** er slått på under Avanserte innstillinger.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\nDenne oppføringen er skrevet etter publisert CAT-dokumentasjon og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get yaesuUsbTroubleshooting => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **Bruk den første av radioens to USB-porter.** CAT ligger normalt på den første (**Enhanced** COM-porten på Windows); den andre (**Standard**) er for PTT og nøkling. Velgeren peker på den første der den kan skille de to fra hverandre.\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav, med mindre **Hold RTS høy** er slått på under Avanserte innstillinger.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.';
	@override String get k4SerialNotes => 'Koble til K4-ens USB-B-kontakt (PC) bak. Både USB-PC1 og USB-PC2 virker for CAT; velg en ledig port og sett Serial USB-PCn: Baud Rate på radioen til samme verdi. HaLo fyller inn 38400; endre ved behov. Et annet program må bruke den andre porten eller Ethernet.\n\nDenne tilkoblingen styrer radioen og keyerne dens; den sender ikke lyd til HaLo.';
	@override String get k4TcpNotes => 'Koble K4-ens Ethernet-kontakt til det lokale nettverket. Oppgi vertsnavnet eller IP-adressen og CAT-port 9200. Dette er CAT-styring, ikke den separate tilkoblingen for fjernlyd på port 9204.\n\nHaLo styrer radioen og keyerne dens uten å strømme lyd eller panadapterdata.';
	@override String get k4PowerTimeout => 'K4-effekten ble ikke endret fordi radioen ikke bekreftet utgangsområdet sitt. Prøv igjen.';
	@override String get k4PowerRange => 'K4-effekten må være 0,1–110 W, eller 0,0001–0,01 W når transverterens milliwatt-utgang er aktiv.';
	@override String get elecraftTroubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get elecraftTroubleshooting => 'Elecraft-rigger bruker Kenwood CAT, og både en KX2 og en KX3 har blitt kjørt på denne måten — VFO i begge retninger, modusbytte og CW-nullsvevning virker.\n\nHvis radioen ikke svarer, er det nesten alltid en av disse:\n\n- **Hastigheten må samsvare** med verdien under **RS232** i radioens meny. 38400 er det de leveres med. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\n**Hvis frekvensen er riktig, men modusen feil**, si fra til oss. Oppføringene for KX2 og KX3 leser modusen fra en posisjon i radioens statussvar som vi har fastsatt ut fra riggene vi har sett, og fastvare som legger den et annet sted, får vi bare vite om gjennom en rapport.\n\nK3 har ikke blitt rapportert verken den ene eller andre veien, så fortell hva som skjer hvis du bruker en. K4 har sin egen oppføring.';
	@override String get kenwoodTroubleshootingTitle => 'Hvis radioen kobler til, men ikke viser noen frekvens';
	@override String get kenwoodTroubleshooting => 'Denne driveren er bekreftet mot Kenwoods TS-590SG og TS-480, QRP Labs\' QMX og QCX-mini, og Elecrafts KX2 og KX3. Resten av serien er skrevet etter publiserte CAT-referanser, så rapporter hva som skjer uansett utfall.\n\nHvis radioen ikke svarer, er det nesten alltid en av disse:\n\n- **Hastigheten må samsvare** med radioens CAT-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **Noen rigger må ha CAT aktivert** i menyen før de svarer i det hele tatt.\n\n**Flere SDR-programmer bruker den samme protokollen**, så denne oppføringen er verdt å prøve for dem også; Elecraft-rigger står for seg selv, under Elecraft. Hvis frekvensen er riktig, men modusen er feil eller mangler, er det den ene delen som varierer i serien — appen finner den ut fra radioen og spør direkte som reserve, så modusen kan rett og slett komme litt etter.';
	@override String get statusConnected => 'Tilkoblet';
	@override String get statusLost => 'Frakoblet';
	@override String get notConfigured => 'Ikke satt opp';
	@override String get currentConfiguration => 'Gjeldende oppsett';
	@override String get currentTransceiver => 'Gjeldende transceiver';
	@override String get radioMode => 'Radiomodus';
	@override String get keyerNotSupported => 'Støttes ikke av gjeldende radio';
	@override String get catControlPreferences => 'Innstillinger for CAT-styring';
	@override String get chooseTransceiver => 'Velg transceiver';
	@override String get configurationSection => 'Oppsett';
	@override String get noTransceiverSelected => 'Ingen transceiver valgt';
	@override String makeMainVfo({required Object name}) => 'Bruk ${name} som hoved-VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		zero: 'Ingen transceivere',
		one: '${count} transceiver',
		other: '${count} transceivere',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} antenne',
		other: '${count} antenner',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} annen enhet',
		other: '${count} andre enheter',
	);
	@override String get equipmentInventory => 'Utstyrsliste';
	@override String get equipmentInUse => 'Transceiverkontroller';
	@override String get noTransceiver => 'Ingen';
	@override String get peerRadioNotAvailable => 'Ikke tilgjengelig';
	@override String peerRadioOnDevice({required Object device}) => 'På ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} er på en annen enhet';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Denne radioen er koblet til ${device}. Tilkoblingen og innstillingene settes opp på den enheten.';
	@override String get antennaInUse => 'Antenne i bruk';
	@override String get keyInUse => 'Nøkkel i bruk';
	@override String get noneSelected => 'Ingen';
	@override String get moreSettings => 'Flere innstillinger';
	@override String get icomCivTroubleshootingTitle => 'Hvis to seriellporter vises for samme radio';
	@override String get icomCivTroubleshooting => 'Flere Icom-radioer, blant dem IC-705, viser **to** USB-seriellporter samtidig (Icom kaller dem Port A og Port B), begge satt til CI-V som standard. Verken denne appen eller operativsystemet kan skille dem fra hverandre utover det: samme USB-leverandør-/produkt-ID vises bare to ganger, noen ganger merket med et `#2`-suffiks her. **Port A er vanligvis den riktige** — normalt den første som operativsystemet eller nettleseren lister opp, og der denne appen kan skille de to portene, merker den den som foreslått. Hvis kommandoer går ut og radioen aldri svarer, prøv den andre porten.';
	@override String get civAddressTroubleshootingTitle => 'Hvis radioen aldri svarer';
	@override String get civAddressTroubleshooting => '- **CI-V-adressen må samsvare** med radioens meny. Denne oppføringen fyller inn adressen modellen leveres med, men en rigg som deler en CI-V-buss, er nettopp der den blir endret. En ramme sendt til feil adresse ignoreres i stillhet, noe som ser akkurat ut som en død kabel.\n- **Hastigheten må samsvare** med radioens CI-V BAUD RATE (på USB, CI-V USB Baud Rate). Sett radioen til samme tall som vises her, **ikke Auto**. På Auto kobler noen radioer, blant dem IC-7300, til og slutter så å svare etter et minutt eller så.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** leveres med adresse `B6`, ikke `94` som fylles inn her — velg oppføringen for IC-7300 MK2 i stedet.';
	@override String get ic705PortNote => '\n- **IC-705** viser to USB-seriellporter, begge oppkalt etter radioen. CI-V ligger på den **første** av dem, som velgeren peker på der den kan skille de to fra hverandre.';
	@override String get ic7760PortNote => '\n- **IC-7760** bruker CI-V på **Port A** av de to USB-seriellportene den viser.';
	@override String get x6100PortNote => '\n- **X6100** bruker CI-V på **DEV**-porten — den andre av de to seriellportene den viser, og den velgeren peker på.';
	@override String get rigctldTroubleshootingTitle => 'Hvis appen ikke kan koble til';
	@override String get rigctldTroubleshooting => 'Dette kobler til en **rigctld-daemon du kjører selv**, ikke direkte til radioen — Hamlibs backend snakker med radioen og støtter hundrevis av modeller.\n\n- **Daemonen må allerede kjøre**, f.eks. `rigctld -m 1035 -r /dev/ttyUSB0`. Finn modellnummeret til radioen din med `rigctl -l`.\n- **Fra en annen maskin** starter du den med `-T 0.0.0.0`: som standard tar rigctld bare imot tilkoblinger fra maskinen den kjører på.\n- **Porten** er 4532 med mindre du startet daemonen med `-t`.\n- Når den er tilkoblet, betyr manglende frekvens vanligvis at daemonen selv ikke når radioen. Test den med `rigctl -m 2 f` på daemonens maskin.';
	@override String get flrigTroubleshootingTitle => 'Hvis appen ikke kan koble til';
	@override String get flrigTroubleshooting => 'Dette kobler til et **flrig-program du kjører selv**, ikke direkte til radioen — flrig snakker med radioen og støtter de fleste merker og modeller.\n\n- **flrig må allerede kjøre**, med transceiveren satt opp og tilkoblet.\n- **Porten** er 12345 med mindre du har endret den i flrig-oppsettet (Config → Setup → Server).\n- **Fra en annen maskin** må du sørge for at flrig-serveren kan nås. Den lytter på alle grensesnitt, men brannmuren din er kanskje ikke enig.\n- Når den er tilkoblet, betyr manglende frekvens vanligvis at flrig selv ikke når radioen. Sjekk at flrig-skjermen følger med på hjulet.';
	@override String get hrdTroubleshootingTitle => 'Hvis appen ikke kan koble til';
	@override String get hrdTroubleshooting => 'Dette kobler til **Ham Radio Deluxes Rig Control, som kjører på datamaskinen din**, ikke direkte til radioen — HRD snakker med radioen.\n\n- **Rig Control må allerede kjøre** og være koblet til radioen.\n- **IP-serveren må være aktivert.** Rig Control snakker bare med andre programmer gjennom den.\n- **Porten** er 7809 med mindre du har endret den i innstillingene for IP-serveren.\n- **Fra en annen maskin** må du sørge for at brannmuren slipper tilkoblingen gjennom.\n\nDenne oppføringen er skrevet etter publiserte beskrivelser av HRDs protokoll og har ikke blitt kjørt mot HRD. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get n3fjpTroubleshootingTitle => 'Hvis appen ikke kan koble til';
	@override String get n3fjpTroubleshooting => 'Dette kobler til **et N3FJP-loggeprogram som kjører på datamaskinen din**, ikke direkte til radioen — N3FJP snakker med radioen.\n\n- **Programmets API må være på**: Settings → Application Program Interface, kryss av for **TCP API Enabled**.\n- **Porten** er 1100 med mindre du har endret den der.\n- **N3FJP må ha et radiogrensesnitt satt opp** for å følge eller stille inn radioen. Uten det rapporterer den bare det som skrives inn i registreringsvinduet.\n- N3FJP rapporterer bare bånd, modus og frekvens: ingen effekt, ingen sendestatus.\n\nDenne oppføringen er skrevet etter N3FJPs publiserte API og har ikke blitt kjørt mot N3FJP. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get commanderTroubleshootingTitle => 'Hvis appen ikke kan koble til';
	@override String get commanderTroubleshooting => 'Dette kobler til **DXLab Commander, som kjører på datamaskinen din**, ikke direkte til radioen — Commander snakker med radioen.\n\n- **Commander må allerede kjøre** og være koblet til radioen.\n- **Nettverkstjenesten må være på**: **Net Serv**-knappen i Radio-panelet i Commanders Configuration-vindu.\n- **Porten** er 52002, den tredje porten i blokken som starter på Net Servs **Base Port** (52000 med mindre du har endret den).\n- **Fra en annen maskin** må du sørge for at brannmuren slipper tilkoblingen gjennom.\n\nDenne oppføringen er skrevet etter Commanders publiserte TCP-meldinger og har ikke blitt kjørt mot Commander. Hvis den halvveis virker, er det verdt å rapportere.';
	@override String get ic705TroubleshootingTitle => 'Hvis radioen aldri svarer';
	@override String get ic705Troubleshooting => 'Radioen har **én enkelt** fjernstyringsøkt. Når innloggingen ignoreres, er det nesten alltid noe annet som bruker den.\n\n- **Lukk alle andre klienter.** wfview eller RS-BA1 koblet til samme radio holder den ene økten, og innloggingen her blir rett og slett ignorert så lenge.\n- **Sjekk radioens nettverksinnstillinger.** WLAN må være på, radioen må være på samme nettverk, og fjernstyringsfunksjonen (Network) må være aktivert.\n- **Slå radioens WLAN av og på** hvis den blir hengende. Det fjerner pålitelig en økt som har hengt seg opp på radioen.\n\nEt **feil passord blir eksplisitt avvist**, ikke møtt med stillhet. Hvis du havnet her i stedet for å få en melding om at det ble avvist, er ikke passordet problemet.';
	@override String get statusStale => 'Svarer ikke';
	@override String get statusDisconnected => 'Ikke tilkoblet';
	@override String get statusConnecting => 'Kobler til…';
	@override String get statusDisconnecting => 'Kobler fra…';
	@override String get statusError => 'Tilkoblingen mislyktes';
	@override String get currentRadioSettings => 'Gjeldende radioinnstillinger';
	@override String get notSupportedByThisRadio => 'Støttes ikke av denne radioen';
	@override String get keyerRowLabel => 'Keyer';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Telefoni';
	@override String voiceKeyerAvailable({required Object count}) => 'Talekeyer: ${count} memorier i radioen';
	@override String get antennaBands => 'Bånd';
	@override String get antennaType => 'Antennetype';
	@override String get antennaTypeRequired => 'Velg en antennetype';
	@override late final _Translations$settings$station$antennaTypes$nb antennaTypes = _Translations$settings$station$antennaTypes$nb._(_root);
	@override String get keyType => 'Nøkkeltype';
	@override String get keyTypeRequired => 'Velg en nøkkeltype';
	@override late final _Translations$settings$station$keyTypes$nb keyTypes = _Translations$settings$station$keyTypes$nb._(_root);
	@override String get softwareIntermediaries => 'Mellomliggende programvare';
	@override String get otherBrands => 'Andre merker';
	@override String get otherEquipment => 'Annet utstyr (antenner, nøkler osv.)';
	@override String get newAntenna => 'Ny antenne';
	@override String get newKey => 'Ny nøkkel';
	@override String get newKeyer => 'WinKeyer (K1EL eller kompatibel)';
	@override String keyViaRadio({required Object radio}) => 'CAT-keyer i ${radio}';
	@override String keyOnDevice({required Object device}) => 'Nøkkel på ${device}';
	@override String get cwKeyerArea => 'Keyer-område';
	@override String get trackStationInfo => 'Registrer stasjonsinfo for hver QSO';
	@override String get includeStationInfoInAdif => 'Ta med i ADIF-eksport';
	@override String get whatToTrack => 'Hva skal registreres?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Effekt';
	@override String get watts => 'Watt';
	@override String get trackFieldAntenna => 'Antenne';
	@override String get trackFieldKey => 'CW-nøkkel';
	@override String get placeholderConnectDelay => 'Tilkoblingsforsinkelse (ms)';
	@override String get placeholderConnectDelayDescription => 'Hvor lang tid det simulerte handshaket tar. Tomt eller 0 kobler til umiddelbart.';
	@override String get placeholderDropAfter => 'Bryt etter (sekunder)';
	@override String get placeholderDropAfterDescription => 'Lukk tilkoblingen av seg selv, for å teste gjenoppkoblingen. Tomt eller 0 bryter aldri.';
	@override String get placeholderFailConnect => 'Mislykkes alltid med å koble til';
	@override String get placeholderConnectFailure => 'Plassholderradioen ble bedt om å avvise denne tilkoblingen';
	@override String get placeholderFreq => 'Frekvens (kHz)';
	@override String get placeholderFreqDescription => 'Hvor plassholderradioen starter. Etterpå rapporterer den tilbake det appen stiller den inn på.';
	@override String get placeholderMode => 'Modus';
	@override String get placeholderModeDescription => 'Modusen plassholderradioen starter på, f.eks. USB, CW, FT8.';
	@override String get placeholderPower => 'Effekt (watt)';
	@override String get placeholderPurpose => 'Bruk denne radioen til å holde rede på hvilken rigg du bruker, for loggformål';
	@override String get placeholderReplyDelay => 'Svarforsinkelse (ms)';
	@override String get placeholderReplyDelayDescription => 'Hvor lang tid plassholderradioen bruker på å rapportere en endring tilbake. Tomt eller 0 svarer umiddelbart.';
	@override String get cwKeyerField => 'CAT CW-keyer';
	@override String get cwKeyerFieldDescription => 'Om denne radioen sender CW fra tekst over CAT. Av for en rigg appen ikke kjenner.';
	@override String get voiceMemories => 'Talememorier';
	@override String get voiceMemoriesDescription => 'Hvor mange talememorier radioen spiller av over CAT. 0 for ingen.';
	@override String get voiceMemoriesInvalid => 'Et heltall, 0 eller mer';
	@override String get yaesuMeterCapture => 'Registrer måleravlesninger';
	@override String get yaesuBinaryMeterCaptureDescription => 'Leser radioens måler for utgangseffekt og flagg for høy SWR under sending og skriver råverdiene til loggen. For å bygge skalaen Yaesu ikke publiserer — verdiene vises ikke som målere.';
	@override String get yaesuMeterCaptureDescription => 'Leser radioens PO-, SWR- og ALC-målere under sending og skriver råverdiene til loggen. For å bygge skalaen Yaesu ikke publiserer — verdiene vises ikke som målere.';
	@override String get telemetryInterval => 'Intervall for måleravlesning (ms)';
	@override String get telemetryIntervalDescription => 'Hvor ofte radioens målere leses mens den sender. La stå tomt for det raskeste denne tilkoblingen klarer, opptil 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Et helt antall millisekunder, ${min} til ${max}';
	@override String get pollInterval => 'Spørreintervall i hvile (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Hvor ofte radioen spørres om frekvens og modus når ingen av dem endres. La stå tomt for ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Et helt antall millisekunder, ${min} til ${max}';
	@override String get advancedSettings => 'Avanserte innstillinger';
	@override String get placeholderSwr => 'SWR-verdi';
	@override String get placeholderSwrDescription => 'Hva denne radioen rapporterer på SWR-måleren under sending. Over 1,8 gir panelet en advarsel.';
	@override String get placeholderSwrInvalid => 'Et tall, 1 eller mer';
	@override String get keyerNone => 'Ingen';
	@override String get cwDialect => 'Dialekt for CW-nøkling';
	@override String get cwDialectDescription => 'Hvilken form av KY-kommandoen denne radioen tar. Ingen betyr ingen CW-nøkling over CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, fylt ut til 24)';
	@override String get cwDialectElecraft => 'Elecraft (KY-tekst)';
	@override String get voiceDialect => 'Dialekt for talekeyer';
	@override String get voiceDialectDescription => 'Hvordan denne radioen spiller av talememoriene over CAT. Ingen betyr ingen talememorier over CAT. Med en dialekt og uten antall gjelder dialektens standardantall.';
	@override String get voiceDialectPb => 'Kenwood (PB, TS-590-stil)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB og DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (bryterklikk)';
	@override String get placeholderDiagnostic => 'Simulert';
	@override String get placeholderWholeNumberInvalid => 'Må være et heltall, 0 eller mer';
	@override String get placeholderFreqInvalid => 'Må være en frekvens i kHz, større enn null';
	@override String get placeholderModeInvalid => 'Må være et modusnavn, f.eks. USB, CW, FT8';
	@override String get switchLayout => 'Oppsett';
	@override String get switchLayoutDescription => 'Hvilken side av bryteren radioene dine er koblet til.';
	@override String get switchLayoutRequired => 'Velg hvordan bryteren er koblet';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Bryteren avviste "${command}" (feil ${code})';
	@override String get switchBusyTransmitting => 'Den porten sender — antennen ble ikke byttet';
	@override String get switchNoAntenna => 'Ingen';
	@override String switchAntennaFor({required Object port}) => 'Antenne på port ${port}';
	@override String get switchAntennaForDescription => 'Hvilken av antennene dine som er koblet til denne porten på bryteren.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antenner, ${radios} radioer';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antenner, 1 radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antenne, ${radios} radioer';
	@override String get switchCommonPort => 'Felles';
	@override String get dcnAddress => 'Enhetsadresse';
	@override String get dcnAddressDescription => 'Adressen som er satt med DIP-bryterne på modulen. En koaksrelémodul leveres fra fabrikken med 2.';
	@override String get dcnAddressRequired => 'Må være en enhetsadresse fra 1 til 99';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'følger bånddata';
	@override String get switchPortTransmittingHint => 'sender — kan ikke endres nå';
	@override String get switchCurrentStateHeader => 'Gjeldende tilstand';
	@override String get switchCurrentStateDescription => 'Hvilken antenne hver radioport er på akkurat nå. Endringer trer i kraft umiddelbart.';
	@override String get switchWiringHeader => 'Kabling';
	@override String get switchPortInhibitedHint => 'sending sperret';
	@override String get configUnreadable => 'De lagrede innstillingene for denne radioen kunne ikke leses. Åpne innstillingene og legg dem inn på nytt, eller fjern radioen og legg den til igjen.';
	@override String get autoConnectHeld => 'HaLo sluttet å svare forrige gang den koblet til denne radioen, så den koblet ikke til av seg selv denne gangen. Trykk Koble til for å prøve igjen.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$nb extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Offlinedata';
	@override String get noFiles => 'Ingen datafiler';
	@override String get noFilesDescription => 'Aktiver aktivitets- eller oppslagsutvidelser for å laste ned offlinedataene deres her.';
	@override String get refresh => 'Oppdater';
	@override String get refreshing => 'Oppdaterer…';
	@override String get updateAll => 'Oppdater alle';
	@override String get updatingAll => 'Oppdaterer alle datafiler…';
	@override String get neverDownloaded => 'Aldri lastet ned';
	@override String get updatedJustNow => 'Oppdatert akkurat nå';
	@override String updatedDaysAgo({required Object days}) => 'Oppdatert for ${days}d siden';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Oppdatert for ${days}d ${hours}t siden';
	@override String updatedHoursAgo({required Object hours}) => 'Oppdatert for ${hours}t siden';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Oppdatert for ${hours}t ${minutes}m siden';
	@override String updatedMinutesAgo({required Object minutes}) => 'Oppdatert for ${minutes}m siden';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Den siste nedlastingen hadde bare ${imported} av ${existing} poster og ble ikke brukt. Oppdater for å godta den.';
	@override String get extensionsSection => 'Utvidelser';
}

// Path: settings.profiles
class _Translations$settings$profiles$nb extends Translations$settings$profiles$en {
	_Translations$settings$profiles$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Ikke satt';
	@override String get personalInfo => 'Personlig info';
	@override String get personalInfoNote => 'Dette kan bli tatt med i genererte logger når det er relevant for innsending';
	@override String get name => 'Navn';
	@override String get email => 'E-post';
	@override String get club => 'Klubb';
	@override String get arrlSection => 'ARRL-seksjon';
	@override String get racSection => 'RAC-seksjon';
	@override String get section => 'Seksjon';
}

// Path: settings.search
class _Translations$settings$search$nb extends Translations$settings$search$en {
	_Translations$settings$search$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Tøm';
	@override String get hint => 'Søk i innstillinger';
}

// Path: settings.developer
class _Translations$settings$developer$nb extends Translations$settings$developer$en {
	_Translations$settings$developer$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Aktiver utvikleradvarsler, feilsøkingslogger og verktøy.';
	@override String get experiments => 'Eksperimenter';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} aktivert',
		other: '${count} aktivert',
	);
	@override String get patchTrack => 'Spor for kodeoppdateringer';
	@override String get patchTrackDescription => 'Hvilken ring for trådløse kodeoppdateringer denne enheten følger. Mer eventyrlystne ringer får rettelser tidligere, men mindre testet. Kodeoppdateringer tas i bruk ved neste omstart.';
	@override String get trackStable => 'Stabil';
	@override String get trackUnstable => 'Ustabil';
	@override String get trackBleeding => 'Dagsfersk';
	@override String checkingTrack({required Object track}) => 'Ser etter kodeoppdatering på "${track}"…';
	@override String get patchDownloaded => 'Kodeoppdatering lastet ned — start appen på nytt for å ta den i bruk.';
	@override String noNewPatch({required Object track}) => 'Ingen ny kodeoppdatering på "${track}".';
	@override String get noPatchInstalled => 'Ingen kodeoppdatering installert — kjører utgivelsesversjonen.';
	@override String runningPatch({required Object patch}) => 'Kjører kodeoppdatering #${patch}.';
	@override String get deepLinks => 'Dyplenker';
	@override String get registerUrlSchemes => 'Registrer URL-skjemaer';
	@override String get registerUrlSchemesDescription => 'La com.ham2k://-lenker åpne denne kopien av appen';
	@override String get registerUrlSchemesDone => 'Denne kopien åpner nå com.ham2k://-lenker';
	@override String registerUrlSchemesFailed({required Object error}) => 'Kunne ikke registrere: ${error}';
	@override String get systemInformation => 'Systeminformasjon';
	@override String get appVersion => 'Appversjon';
	@override String get dataFolder => 'Datamappe';
	@override String get loading => '(laster…)';
	@override String get panelLoadFailed => 'Kunne ikke laste dette innstillingspanelet.';
	@override String get extDevServer => 'Utviklingsserver for utvidelser';
	@override String get extensionSettings => 'Utvidelsesinnstillinger';
	@override String get extDevServerDescription => 'Last inn utvidelser fra en utviklingsserver på nettverket ditt i stedet for de som er innebygd i appen, og last dem inn på nytt når du lagrer.';
	@override String get extDevServerAddress => 'Serveradresse';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Koble til';
	@override String get extDevServerDisconnect => 'Koble fra';
	@override String get extDevServerConnecting => 'Kobler til…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Leverer ${count} utvidelse: ${keys}',
		other: 'Leverer ${count} utvidelser: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Ikke tilkoblet';
	@override String get extDevServerReconnect => 'Koble til på nytt ved oppstart';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Sist lastet inn på nytt: ${key} kl. ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} utvidelse feiler under bygging',
		other: '${count} utvidelser feiler under bygging',
	);
	@override String get catalog => 'Utvidelseskatalog';
	@override String get catalogDescription => 'Les katalogen fra en annen server — en lokal en mens du jobber med selve katalogen. Tomt betyr catalog.ham2k.net.';
	@override String get catalogAddress => 'Katalogadresse';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Spor for katalogsøk';
	@override String get catalogSearchStable => 'Bare stabile';
	@override String get catalogSearchUnstable => 'Ustabile eller bedre';
	@override String get catalogSearchBleeding => 'Dagsferske eller bedre';
}

// Path: settings.about
class _Translations$settings$about$nb extends Translations$settings$about$en {
	_Translations$settings$about$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Varsler og meldinger';
	@override String get noticesDescription => 'Kunngjøringer og statusmeldinger';
	@override String get releaseNotes => 'Versjonsmerknader';
	@override String get copiedVersion => 'Versjonsdetaljer kopiert til utklippstavlen';
}

// Path: settings.panels
class _Translations$settings$panels$nb extends Translations$settings$panels$en {
	_Translations$settings$panels$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Appinnstillinger';
	@override String get settingsDescription => 'Få appen til å virke slik du vil';
	@override String get commonSettings => 'Vanlige innstillinger';
	@override String get syncDescription => 'Ta sikkerhetskopi av og synkroniser loggene dine mellom enheter';
	@override String get accountsDescription => 'Tjenesteinnlogginger, offlinedata og mer';
	@override String get extensions => 'Utvidelser og funksjoner';
	@override String get extensionsDescription => 'Aktiviteter, konkurranser, dashbordpaneler og flere funksjoner';
	@override String get profilesDescription => 'Operatørkallesignal og stasjonsprofil';
	@override String get stationProfiles => 'Stasjonsprofiler';
	@override String get developerSettings => 'Utviklerinnstillinger';
	@override String get developerSettingsDescription => 'Feilsøkings- og utviklingsverktøy';
	@override String get about => 'Om';
	@override String get aboutDescription => 'Versjon, krediteringer og juridisk informasjon';
	@override String get unavailableTitle => 'Noen innstillinger er utilgjengelige';
	@override String get unavailableText => 'Kjøremiljøet for utvidelser startet ikke, så innstillinger fra utvidelser mangler.';
	@override String get station => 'Stasjonsoppsett';
	@override String get stationDescription => 'CAT-styring og flere alternativer';
	@override String get peers => 'Andre enheter';
	@override String get peersDescription => 'Koble til andre enheter i nærheten';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$nb extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get six => '6 tegn (FN31pr)';
	@override String get eight => '8 tegn (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$nb extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get six => '6 tegn';
	@override String get eight => '8 tegn';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$nb extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get date => 'Dato';
	@override String get time => 'Tid';
	@override String get freq => 'Frekvens';
	@override String get mode => 'Modus';
	@override String get call => 'Kallesignal';
	@override String get name => 'Navn';
	@override String get station => 'Stasjon';
	@override String get band => 'Bånd';
	@override String get sent => 'Sendt';
	@override String get rcvd => 'Mottatt';
	@override String get grid => 'Grid';
	@override String get state => 'Stat';
	@override String get country => 'Land';
	@override String get refs => 'Ref.';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$nb extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO-logg';
	@override String get qsosDescription => 'QSOene til det valgte kallesignalet, på tvers av alle operasjoner.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Totalt antall QSOer, eller kallesignaloppslaget for den valgte QSOen.';
	@override String get map => 'Kart';
	@override String get mapDescription => 'Posisjonen til den valgte QSOen.';
}

// Path: home.logs.import
class _Translations$home$logs$import$nb extends Translations$home$logs$import$en {
	_Translations$home$logs$import$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Kallesignaler: ${calls}';
	@override String get skippedOne => '1 post kunne ikke leses';
	@override String skippedOther({required Object count}) => '${count} poster kunne ikke leses';
	@override String get readingTitle => 'Leser ADIF-fil…';
	@override String get checkingTitle => 'Ser etter duplikater…';
	@override String get importingTitle => 'Importerer QSOer…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} av ${total} kontrollert';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importert, av ${total}';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$nb extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Loggen og registreringsfeltene';
	@override String get infoDescription => 'Det vi vet om stasjonen vi har kontakt med';
	@override String get spotsDescription => 'Spots fra clusterne og aktivitetsprogrammene';
	@override String get mapDescription => 'Hvor kontaktene er';
	@override String get clockDescription => 'En klokke, i hvilken som helst tidssone';
	@override String get clockFace => 'Urskive';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analog';
	@override String get clockZone => 'Tidssone';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Denne enheten';
	@override String get clockShowSeconds => 'Vis sekunder';
	@override String get weatherDescription => 'Forholdene nå og de neste åtte timene, der du er QRV';
	@override String get weatherUseOperationLocation => 'Bruk posisjonen til operasjonen';
	@override String get weatherLocation => 'Posisjon';
	@override String get weatherLocationDescription => 'En grid-rute (FN31pr) eller lat,lon. Ignoreres mens «Bruk posisjonen til operasjonen» er avkrysset.';
	@override String get weatherNoLocation => 'Ingen posisjon satt. Gi dette panelet en posisjon i innstillingene, eller plasser det i en operasjon som har en.';
	@override String weatherBadLocation({required Object location}) => 'Kunne ikke lese posisjonen ${location}. Bruk en grid-rute som FN31pr, eller 42.36,-71.06.';
	@override String get weatherUnreachable => 'Kunne ikke nå Open-Meteo — ikke noe nettverk? Prøver igjen snart.';
	@override String get weatherUnreadable => 'Open-Meteo svarte, men ikke med noe som kunne leses. Prøver igjen snart.';
	@override String weatherGusts({required Object speed}) => 'kast ${speed}';
	@override String get panelAgeNow => 'akkurat nå';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} min siden',
		other: '${count} min siden',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: '${count} t siden',
		other: '${count} t siden',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$nb weatherConditions = _Translations$operation$layout$panels$weatherConditions$nb._(_root);
	@override String get websiteDescription => 'En nettside du velger selv, i et panel';
	@override String get websiteUrl => 'Adresse';
	@override String get websiteRefresh => 'Oppdater';
	@override String get websiteRefreshNever => 'Aldri';
	@override String get websiteRefresh1 => 'Hvert minutt';
	@override String get websiteRefresh5 => 'Hvert 5. minutt';
	@override String get websiteRefresh15 => 'Hvert 15. minutt';
	@override String get websiteTitle => 'Panelnavn';
	@override String get websiteRefreshNow => 'Oppdater nå';
	@override String get websiteNoUrl => 'Ingen adresse ennå. Åpne innstillingene for dette panelet for å velge en side.';
	@override String get websiteBadUrl => 'Det ser ikke ut som en nettadresse. Den må begynne med https://';
	@override String get websiteNotHttps => 'Bare adresser med https:// kan vises her.';
	@override String get websiteUnsupported => 'Nettsider kan ikke vises i et panel på dette systemet.';
	@override String get websiteOpenExternally => 'Åpne i nettleser';
	@override String websiteLoadFailed({required Object reason}) => 'Kunne ikke laste siden: ${reason}';
	@override String get remoteScreenDescription => 'En skjerm, app eller et vindu som deles av en annen av enhetene dine.';
	@override String get remoteScreenTarget => 'Skjerm';
	@override String get remoteScreenChoose => 'Velg en skjerm…';
	@override String get remoteScreenPickerTitle => 'Delte skjermer';
	@override String get remoteScreenPickerEmpty => 'Ingen av enhetene dine deler en skjerm. Slå på Del skjermer og vinduer under Innstillinger → Andre enheter, på enheten du vil se.';
	@override String get remoteScreenUnset => 'Ingen skjerm valgt. Åpne innstillingene for dette panelet for å velge en som de andre enhetene dine deler.';
	@override String get remoteScreenConnecting => 'Kobler til…';
	@override String get remoteScreenPeerAway => 'Den enheten er ikke tilkoblet akkurat nå.';
	@override String get remoteScreenNotOffered => 'Den enheten sluttet å dele denne skjermen.';
	@override String get remoteScreenNoListener => 'Den enheten kan ikke ta imot tilkoblinger — sjekk brannmuren på den.';
	@override String get remoteScreenNoLan => 'Skjermer deles bare over det lokale nettverket, ikke over Bluetooth.';
	@override String get remoteScreenRefused => 'Den enheten ville ikke dele denne skjermen.';
	@override String get remoteScreenSettings => 'Panelinnstillinger';
	@override String get remoteScreenAdjust => 'Juster visning';
	@override String get remoteScreenDetail => 'Detaljnivå';
	@override String get remoteScreenDetailStandard => 'Standard';
	@override String get remoteScreenDetailHigh => 'Høyt';
	@override String get remoteScreenDetailMaximum => 'Maksimalt';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Zoom inn';
	@override String get remoteScreenZoomOut => 'Zoom ut';
	@override String get remoteScreenStopped => 'Den skjermen eller det vinduet vises ikke lenger.';
	@override String get remoteScreenCaptureFailed => 'Den enheten kunne ikke ta opp den skjermen — den trenger kanskje tillatelse til skjermopptak.';
	@override String get remoteScreenNoAnswer => 'Den enheten svarte ikke. Kanskje skjermdeling ikke er slått på.';
	@override String get remoteScreenNoMedia => 'Kunne ikke åpne en tilkobling for bildet. Sjekk brannmuren på denne enheten.';
	@override String get solarDescription => 'Sol- og geomagnetiske forhold, med forplantning bånd for bånd';
	@override String get solarUnreachable => 'Kunne ikke nå hamqsl.com — ikke noe nettverk? Prøver igjen snart.';
	@override String get solarUnreadable => 'hamqsl.com svarte, men ikke med en måling vi kunne bruke. Prøver igjen snart.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Dag';
	@override String get solarBandNight => 'Natt';
	@override String get solarBandGood => 'Gode';
	@override String get solarBandFair => 'Middels';
	@override String get solarBandPoor => 'Dårlige';
	@override String solarSources({required Object primary, required Object secondary}) => 'Kilder: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Tilkoblingen sliter — hopper over bilder.';
	@override String get remoteScreenStalled => 'Bildene kommer ikke lenger fram — denne tilkoblingen kan være for treg.';
	@override String get radioDescription => 'En radios frontpanel — frekvens, modus og effekt, styrt via CAT';
	@override String get radioStyle => 'Stil';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderne';
	@override String get radioRadio => 'Radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — ingen radio angitt';
	@override String get radioNoRadio => 'Ingen radio å vise. Velg en i innstillingene for dette panelet, eller legg til en under Stasjonsoppsett.';
	@override String get radioNotConfigured => 'Denne radioen er ikke satt opp ennå. Velg port eller adresse under Stasjonsoppsett.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radio ikke tilkoblet';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Koble til denne radioen';
	@override String get radioDisconnect => 'Koble fra denne radioen';
	@override String get radioStale => 'INGEN DATA';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'høy SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$nb extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bruk kompakte filnavn';
	@override String get descriptionOn => 'Korte navn laget for opplastingsverktøy, som N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Lesbare navn, som 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$nb extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inkluder privat info';
	@override String get descriptionOn => 'Navn, adresser, e-poster, grid-ruter og notater tas med';
	@override String get descriptionOff => 'Navn, adresser, e-poster, grid-ruter og notater utelates';
	@override String get note => 'Full ADIF-eksport tar alltid med alt';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$nb extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Legg til en e-postadresse først';
	@override String get needsEmailBody => 'Ham2K File Stash sender filene dine til e-postadressen på LoFi-kontoen din, og du logger inn med den på stash.ham2k.net. Kontoen din har ikke en bekreftet adresse ennå — legg den til i Innstillinger › Skysynkronisering.';
	@override String get openSyncSettings => 'Åpne Skysynkronisering';
	@override String get replaceTitle => 'Nylig stash blir erstattet';
	@override String replaceBody({required Object name}) => 'Du sendte «${name}» for mindre enn 6 timer siden, og den er ikke lastet ned ennå. Gratiskontoer beholder én stash om gangen, så hvis du sender nå, blir den erstattet.';
	@override String get replaceConfirm => 'Send likevel';
	@override String get failedTitle => 'Kunne ikke sende til Ham2K File Stash';
	@override String get sentTitle => 'Sendt til Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Du kan hente denne filen ved å gå til **[stash.ham2k.net](https://stash.ham2k.net)** i hvilken som helst nettleser.',
		other: 'Du kan hente disse filene ved å gå til **[stash.ham2k.net](https://stash.ham2k.net)** i hvilken som helst nettleser.',
	);
	@override String get mayHaveArrived => 'Ikke noe svar fra Stash — filen kan ha kommet fram likevel. Sjekk stash.ham2k.net før du sender på nytt';
	@override String get notSent => 'ikke sendt';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Denne filen kom ikke fram:',
		other: 'Disse ${count} filene kom ikke fram:',
	);
	@override String get emailOffer => 'Eller for enkelhets skyld kan vi sende deg en e-post med en direkte lenke.';
	@override String get emailMe => 'Send meg en lenke på e-post';
	@override String get emailSent => 'Vi har sendt deg en nedlastingslenke på e-post.';
	@override String emailFailed({required Object error}) => 'Kunne ikke sende e-posten: ${error}';
	@override String get freeTier => 'Gratiskontoer kan bare beholde én stash om gangen. Abonnenter kan beholde så mange de vil.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count,
		one: 'Sendte ${count} fil til Ham2K File Stash (stash.ham2k.net)',
		other: 'Sendte ${count} filer til Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$nb extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Asia';
	@override String get eu => 'Europa';
	@override String get na => 'Nord-Amerika';
	@override String get oc => 'Oseania';
	@override String get sa => 'Sør-Amerika';
	@override String get an => 'Antarktis';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$nb extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrer spots';
	@override String get band => 'Bånd';
	@override String get mode => 'Modus';
	@override String get age => 'Alder';
	@override String get sources => 'Kilder';
	@override String get continent => 'Kontinent';
	@override String get sorting => 'Sortering';
	@override String get sortByTime => 'Etter spot-tid';
	@override String get sortByFrequency => 'Etter frekvens';
	@override String get groupByBand => 'Grupper etter bånd';
	@override String get groupCallsWithNotes => 'Grupper kallesignaler med notater';
	@override String get sourceNoReply => 'Ikke noe svar';
	@override String get sourceError => 'Feil';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$nb extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Loggepanelet er opptatt';
	@override String get editingBody => 'Du redigerer en logget kontakt. Logge denne spoten i stedet, eller gå tilbake og fullføre redigeringen?';
	@override String get composingBody => 'Du har begynt å registrere en kontakt. Logge denne spoten i stedet, eller gå tilbake og fullføre det du skrev?';
	@override String get goBack => 'Gå tilbake';
	@override String get clearAndLog => 'Tøm og logg spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$nb extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Venstrehåndsmodus';
	@override String get descriptionOn => 'Bruker oppsett for venstrehendte';
	@override String get descriptionOff => 'Bruker oppsett for høyrehendte';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$nb extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Landsflagg';
	@override String get dx => 'Vis bare for DX-kontakter';
	@override String get all => 'Vis flagg for alle kontakter';
	@override String get none => 'Ikke vis flagg';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$nb extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Viser flagg bare for DX-kontakter';
	@override String get all => 'Viser flagg for alle kontakter';
	@override String get none => 'Viser ingen flagg';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$nb extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Foreslå operatør';
	@override String get descriptionOn => 'Foreslår kallesignalet ditt som operatør når en operasjon bruker et annet stasjonskallesignal';
	@override String get descriptionOff => 'Lar operatør stå tomt med mindre du fyller det ut';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$nb extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vis retning';
	@override String get descriptionOn => 'Viser estimert retning til stasjon';
	@override String get descriptionOff => 'Viser ikke retningsinformasjon';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$nb extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vis også motsatt retning';
	@override String get descriptionOn => 'Viser også retningen fra stasjonen, som "45° / 225°"';
	@override String get descriptionOff => 'Viser bare retningen til stasjonen';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$nb extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bytt rekkefølge for signalrapport';
	@override String get sentFirst => 'Sendt først, mottatt andre';
	@override String get rcvdFirst => 'Mottatt først, sendt andre';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$nb extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hopp til neste felt ved RST-oppføring';
	@override String get descriptionOn => 'Hopper videre når RST er skrevet inn';
	@override String get descriptionOff => 'Hopper ikke automatisk';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$nb extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standardrapport — telefoni';
	@override String get description => 'Brukes når Sendt eller Mottatt står tomt på SSB, FM eller AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$nb extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standardrapport — CW og data';
	@override String get description => 'Brukes når Sendt eller Mottatt står tomt på CW, RTTY og andre datamoduser';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$nb extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standardrapport — FT8 og FT4';
	@override String get description => 'Brukes når Sendt eller Mottatt står tomt på FT-modusene';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$nb extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tallrad';
	@override String get description => 'Vis en rad med talltaster over tastaturet under logging';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$nb extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Skråstrek- og punktumtast';
	@override String get description => 'Legger til en kontekstavhengig tast: «/» for kallesignaler, «.» for tall';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$nb extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrer ved tastetrykk';
	@override String get description => 'Haptisk tilbakemelding når du trykker på en talltast';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$nb extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get off => 'Deaktivert';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$nb extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$nb extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Styr PTT med [\']';
	@override String get descriptionOn => 'I telefonimoduser nøkler [\'] radioen, og [\'] igjen slipper den. Den slipper av seg selv etter ett minutt.';
	@override String get descriptionOff => '[\']-tasten nøkler ikke radioen.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Sender';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$nb extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart VFO-avrunding';
	@override String get descriptionOn => 'Når du slutter å vri på hjulet, rundes frekvensen av til et fornuftig steg. Bare talemoduser.';
	@override String get descriptionOff => 'Blir stående nøyaktig der du stilte inn.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$nb extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart avrunding: Ventetid';
	@override String get description => 'Hvor lenge hjulet må stå stille før frekvensen rundes av. Kortere føles umiddelbart; lengre gir rom for en langsom bevegelse.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$nb extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart avrunding: Lang bevegelse';
	@override String get description => 'Flytt minst så langt, så rundes frekvensen av til en hel kHz, uansett hvor sakte du avsluttet.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$nb extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart avrunding: Minste bevegelse';
	@override String get description => 'Flytt mindre enn dette, så rundes ikke frekvensen av, og finjustering får være i fred.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$nb extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart avrunding: Saktest bevegelse';
	@override String get description => 'Vri hjulet saktere enn dette, så rundes ikke frekvensen av, med mindre det var en lang bevegelse.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$nb extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM av';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter sender meldinger';
	@override String get off => 'Av';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter sender meldinger: ${state}. Trykk for å endre.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$nb extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Keyer-hastighet';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$nb extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW-keyermeldinger';
	@override String get notSupported => 'Gjeldende radio støtter ikke CW-nøkling';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Melding (${n})';
	@override String get labelField => 'Etikett';
	@override String labelKey({required Object n}) => 'Etikett for F${n}';
	@override String get details => 'Detaljer';
	@override String get empty => '(tom)';
	@override String get sets => 'Meldingssett';
	@override String get newSet => 'Nytt sett';
	@override String get renameSet => 'Gi nytt navn til sett';
	@override String get deleteSet => 'Slett sett';
	@override String get newSetName => 'Navn';
	@override String get setDefault => 'Standard';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM-meldinger';
	@override String get setSaved => 'Mine meldinger';
	@override String get repeat => 'Gjenta melding #1';
	@override String get repeatOff => 'Nei';
	@override String repeatAfter({required Object n}) => 'Etter ${n} sekunder';
	@override String get repeatWait => 'Gjentar';
	@override String get keyboard => 'Skriv for å sende';
	@override String get keyboardField => 'Skriv for å sende';
	@override String get closeArea => 'Lukk keyer-området';
	@override String get help => 'Hjelp';
	@override String get helpTitle => 'Skrive CW-meldinger';
	@override String get helpIntro => 'Meldinger kan bruke maler med følgende verdier:';
	@override String get helpOpCall => 'Kallesignalet ditt';
	@override String get helpQsoCall => 'Deres kallesignal — i en //-stabel, kallesignalet som blir logget';
	@override String get helpQsoFullCall => 'Deres kallesignal, hvis det er et gyldig kallesignal; tomt for et delvis';
	@override String get helpQsoPartial => 'Et delvis kallesignal; tomt hvis det finnes et fullstendig gyldig kallesignal';
	@override String get helpQsoNextCall => 'I en //-stabel, kallesignalet som blir valgt for logging neste gang, hvis det er et gyldig fullstendig kallesignal';
	@override String get helpQsoNextPartial => 'I en //-stabel, neste delvise kallesignal etter at gjeldende kontakt er logget';
	@override String get helpQsoName => 'Fornavnet deres, slik det er skrevet, ellers fra oppslaget';
	@override String get helpQsoState => 'Staten deres, slik den er skrevet, ellers fra oppslaget';
	@override String get helpKeyerMsg => 'Melding 1 slik den ville blitt sendt, inne i en annen melding. Gyldig for melding 1 til 8';
	@override String get helpQsoRst => 'Rapporten du sender';
	@override String get helpQsoSerial => 'Serienummeret ditt, i en konkurranse som sender et';
	@override String get helpPad => 'Fyller ut med nuller til så mange sifre: 7 sendes som 007';
	@override String get helpCut => 'Forkortede tall, T for 0 og N for 9: 599 sendes som 5NN';
	@override String get helpCutDigits => 'Velger sifrene som forkortes, i anførselstegn — 0 er T, 1 er A, 5 er E, 9 er N';
	@override String get helpFullExample => 'Fullstendig eksempel:';
	@override String get helpExample => 'Sender W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Med Enter sender meldinger på, sender Enter meldinger etter funksjonstasten deres, slik N1MM gjør. Meldingssettet ESM-meldinger starter med disse:';
	@override String get helpEsmCq => 'Ved Run roper Enter CQ når kallesignalfeltet er tomt';
	@override String get helpEsmExchange => 'Utvekslingen din: etter kallesignalet deres ved Run, etter at de svarer ved S&P';
	@override String get helpEsmThanks => 'Takk, når kontakten er logget: plassholderne gjelder neste kontakt, ikke denne';
	@override String get helpEsmMyCall => 'Ved S&P, kallesignalet ditt til stasjonen du svarer';
	@override String get helpEsmHisCall => 'Ved Run, kallesignalet deres foran utvekslingen din';
	@override String get helpEsmAgain => 'Spør igjen når ingenting av utvekslingen deres ble mottatt';
	@override String get helpEsmStackThanks => 'Foreslått F3 for //-stabler: TU sendes etter at kontakten er logget, så den takker, roper så neste stasjon i stabelen og sender utvekslingen din, eller spør tilbake etter et delvis kallesignal (TU KR?); når ingenting er igjen, bare TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$nb extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Talemeldinger';
	@override String get notSupported => 'Gjeldende radio støtter ikke talemeldinger';
	@override String get description => 'Dette bruker talememoriene i radioen';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Talememori (${n})';
	@override String get labelField => 'Etikett';
	@override String labelKey({required Object n}) => 'Etikett for talememori ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Tom';
	@override String get notMeasured => 'Ukjent lengde';
	@override String get playButton => 'Spill av';
	@override String get recordButton => 'Ta opp';
	@override String get stopButton => 'Stopp';
	@override String get repeat => 'Gjenta melding #1';
	@override String get repeatOff => 'Nei';
	@override String repeatAfter({required Object n}) => 'Etter ${n} sekunder';
	@override String recordHelpTitle({required Object model}) => 'Merknader for ${model}:';
	@override String namedOnDevice({required Object device}) => 'Disse memoriene ligger i radioen til ${device}. Navnene og lengdene hører til den enheten.';
	@override String get namedOnRadio => 'Lagret i radioen, der de andre klientene også ser det.';
	@override String get recordHelpYaesuDvs => 'Vent på [REC]-indikatoren på radioen, hold så inne PTT-knappen og ta opp meldingen. Avslutt ved å trykke på STOPP-knappen her i appen før du slipper PTT, for å unngå uønskede klikk.';
	@override String get recordHelpFt891 => 'Vent til [REC]-indikatoren har blinket minst fire ganger, hold så inne PTT-knappen og ta opp meldingen. Avslutt ved å trykke på STOPP-knappen her i appen før du slipper PTT, for å unngå uønskede klikk.';
	@override String get pill => 'Tale';
	@override String play({required Object n}) => 'Spill av memori ${n}';
	@override String get stop => 'Stopp';
	@override String record({required Object n}) => 'Ta opp memori ${n}';
	@override String get stopRecording => 'Stopp opptak';
	@override String get playing => 'Spiller av…';
	@override String get recording => 'Tar opp…';
	@override String playingMemory({required Object label}) => 'Spiller av ${label}';
	@override String recordingMemory({required Object label}) => 'Tar opp ${label}';
	@override String get doubtful => 'Spilte radioen den av? Den meldte at den var ledig med en gang.';
	@override String get recordOnRadio => 'Du må ta opp memoriene på selve radioen.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$nb extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Unngå nullsvevning på spots';
	@override String get descriptionOn => 'Med en radio tilkoblet stilles det inn noen Hz ved siden av en CW-spot, så ikke alle som svarer, roper på samme tone.';
	@override String get descriptionOff => 'Stiller inn nøyaktig på den spottede frekvensen.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$nb extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nullsvevning: Avviksområde';
	@override String get description => 'Hvor langt fra den spottede frekvensen du havner, på begge sider. Avviket er aldri nær null — da ville det vært nullsvevning igjen.';
}

// Path: settings.map.style
class _Translations$settings$map$style$nb extends Translations$settings$map$style$en {
	_Translations$settings$map$style$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kartstil';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$nb extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatisk';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$nb extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Del data om appbruk';
	@override String get descriptionOn => 'Hjelper oss å forbedre appen ved å dele bruks-, oppsett-, krasj- og ytelsesdata';
	@override String get descriptionOff => 'Holder appbruksdata private.\nHam2K-teamet vil ikke kunne oppdage krasj eller andre problemer.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$nb extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get title => 'Del operasjonsdata';
	@override String get descriptionOn => 'Deler noen operasjonsdata offentlig og med andre brukere';
	@override String get descriptionOff => 'Holder operasjonsdata private';
}

// Path: settings.station.models
class _Translations$settings$station$models$nb extends Translations$settings$station$models$en {
	_Translations$settings$station$models$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

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
	@override String get q900 => 'Guohetec Q900';
	@override String get yaesuGeneric => 'Yaesu - Generell';
	@override String get icomGeneric => 'Icom - Generell';
	@override String get kenwoodGeneric => 'Kenwood - Generell';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Generell';
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
	@override String get x6100 => 'Xiegu X6100';
	@override String get g90 => 'Xiegu G90';
	@override String get rigctld => 'Radio styrt via rigctld';
	@override String get rigctldNodeName => 'Min radio (via rigctld)';
	@override String get flrig => 'Radio styrt via flrig';
	@override String get flrigNodeName => 'Min radio (via flrig)';
	@override String get hrd => 'Radio styrt via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Min radio (via HRD)';
	@override String get n3fjp => 'Radio styrt via N3FJP';
	@override String get n3fjpNodeName => 'Min radio (via N3FJP)';
	@override String get commander => 'Radio styrt via DXLab Commander';
	@override String get commanderNodeName => 'Min radio (via Commander)';
	@override String get antenna => 'Antenne';
	@override String get key => 'CW-nøkkel';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Generell radio (plassholder)';
	@override String get placeholderRadioNodeName => 'Min radio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 koaksbryter';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$nb extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get network => 'Nettverk/WiFi';
	@override String get usbSerial => 'USB-seriell';
	@override String get wifi => 'Nettverk/WiFi';
	@override String get bluetoothSerial => 'Bluetooth-seriell';
	@override String get placeholder => 'Plassholder';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$nb extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipol';
	@override String get vertical => 'Vertikal';
	@override String get yagiBeam => 'Yagi / beam';
	@override String get loop => 'Loop';
	@override String get longWire => 'Langtråd / EFHW';
	@override String get other => 'Annen';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$nb extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Pumpenøkkel';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mekanisk halvautomatisk)';
	@override String get fullyAutomatic => 'Helautomatisk keyer';
	@override String get singlePaddle => 'Enkel paddle';
	@override String get dualPaddle => 'Dobbel paddle';
	@override String get computerDriven => 'Datamaskinstyrt';
	@override String get other => 'Annen';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$nb extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$nb._(TranslationsNb root) : this._root = root, super.internal(root);

	final TranslationsNb _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Ukjent';
	@override String get sunny => 'Sol';
	@override String get clear => 'Klart';
	@override String get mainlySunny => 'Stort sett sol';
	@override String get mainlyClear => 'Stort sett klart';
	@override String get partlyCloudy => 'Delvis skyet';
	@override String get cloudy => 'Skyet';
	@override String get foggy => 'Tåke';
	@override String get rimeFog => 'Rimtåke';
	@override String get lightDrizzle => 'Lett yr';
	@override String get drizzle => 'Yr';
	@override String get heavyDrizzle => 'Kraftig yr';
	@override String get lightFreezingDrizzle => 'Lett underkjølt yr';
	@override String get freezingDrizzle => 'Underkjølt yr';
	@override String get lightRain => 'Lett regn';
	@override String get rain => 'Regn';
	@override String get heavyRain => 'Kraftig regn';
	@override String get lightFreezingRain => 'Lett underkjølt regn';
	@override String get freezingRain => 'Underkjølt regn';
	@override String get lightSnow => 'Lett snø';
	@override String get snow => 'Snø';
	@override String get heavySnow => 'Kraftig snø';
	@override String get snowGrains => 'Kornsnø';
	@override String get lightShowers => 'Lette byger';
	@override String get showers => 'Byger';
	@override String get heavyShowers => 'Kraftige byger';
	@override String get lightSnowShowers => 'Lette snøbyger';
	@override String get snowShowers => 'Snøbyger';
	@override String get thunderstorm => 'Tordenvær';
	@override String get lightThunderstormsWithHail => 'Lett tordenvær med hagl';
	@override String get thunderstormWithHail => 'Tordenvær med hagl';
}

/// The flat map containing all translations for locale <nb>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsNb {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Lagre',
			'common.ok' => 'OK',
			'common.cancel' => 'Avbryt',
			'common.delete' => 'Slett',
			'common.create' => 'Opprett',
			'common.error' => 'Feil',
			'common.close' => 'Lukk',
			'common.done' => 'Ferdig',
			'common.callsign' => 'Kallesignal',
			'common.clear' => 'Tøm',
			'common.dismiss' => 'Lukk',
			'common.expand' => 'Utvid',
			'common.collapse' => 'Skjul',
			'onboarding.welcomeTitle' => 'Velkommen til Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Velkommen til Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Vi har noen spørsmål som hjelper oss å tilpasse appen til dine behov.',
			'onboarding.skip' => 'Hopp over',
			'onboarding.kContinue' => 'Fortsett',
			'onboarding.back' => 'Tilbake',
			'onboarding.next' => 'Neste',
			'onboarding.done' => 'Ferdig',
			'onboarding.callsignTitle' => 'Hva er kallesignalet ditt?',
			'onboarding.callsignBody' => 'Du trenger en lisens som radioamatør for at denne appen skal være nyttig',
			'onboarding.callsignLabel' => 'Operatørens kallesignal',
			'onboarding.alreadyHaveAccount' => 'Har du allerede en konto?',
			'onboarding.foundSiblingTitle' => 'Koble til en eksisterende konto?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Vi fant ${app} på denne enheten. Koble denne appen til samme konto, så følger kallesignalet og loggene dine med.',
			'onboarding.foundPoloBody' => 'Vi fant en eldre versjon av Ham2K Portable Logger på denne enheten. Koble denne appen til samme konto, så følger kallesignalet og loggene dine med.',
			'onboarding.foundSiblingsBody' => 'Vi fant andre Ham2K-apper på denne enheten. Koble denne appen til en av kontoene deres, så følger kallesignalet og loggene dine med.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Koble til ${app}',
			'onboarding.linkWithPolo' => 'Koble til kontoen i den eldre versjonen',
			'onboarding.setUpFresh' => 'Start på nytt',
			'onboarding.activitiesTitle' => 'Favorittaktiviteter',
			'onboarding.activitiesBody' => 'Er du interessert i noen av disse populære aktiveringsprogrammene?',
			'onboarding.activitiesFooter' => '(Du finner flere alternativer i Innstillinger)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Data og personvern',
			'onboarding.consentUsageBody' => 'For å hjelpe oss å gjøre appen bedre vil vi gjerne samle inn ytelses-, krasj- og bruksdata.',
			'onboarding.consentUsageLabel' => 'Del data om appbruk',
			'onboarding.consentOperationBody' => 'Noen funksjoner kan innebære at operasjonsdataene dine deles med andre brukere. Du kan reservere deg når som helst.',
			'onboarding.consentOperationLabel' => 'Del operasjonsdata',
			'onboarding.finishingSetup' => 'Fullfører oppsettet — laster ned referansedata…',
			'startScreen.credits' => 'av KI2D og venner',
			'testerOverlay.tape' => 'FORSIKTIG: UNDER ARBEID',
			'testerOverlay.warningTitle' => 'Denne appen er under utvikling',
			'testerOverlay.warningBody' => 'De fleste funksjonene har ujevnt underlag og snublefeller overalt. Se jevnlig etter oppdateringer.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Nytt i build ${build}',
			'testerOverlay.thanks' => 'Takk for at du setter loggen din på spill for å hjelpe oss å gjøre denne appen bedre!',
			'extensionsPanel.categoryActivity' => 'Aktiviteter',
			'extensionsPanel.categoryContest' => 'Konkurranser',
			'extensionsPanel.categoryLookup' => 'Kallesignaloppslag',
			'extensionsPanel.categorySpots' => 'Spot-kilder',
			'extensionsPanel.categoryDashboard' => 'Dashbordpaneler',
			'extensionsPanel.categoryOther' => 'Andre utvidelser',
			'extensionsPanel.searchHint' => 'Søk i utvidelser',
			'extensionsPanel.applying' => 'Aktiverer endringer i utvidelser, dette kan ta et øyeblikk…',
			'extensionsPanel.noMatches' => 'Ingen utvidelser samsvarer med søket',
			'extensionsPanel.installFromFile' => 'Installer fra fil…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versjon ${version}',
			'extensionsPanel.canReach' => 'Denne utvidelsen kan kontakte',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, over en åpen tilkobling',
			'extensionsPanel.canHoldLocalConnection' => 'Enheter på det lokale nettverket ditt, over en åpen tilkobling',
			'extensionsPanel.canUseLocation' => 'Posisjonen din',
			'extensionsPanel.canReadRadio' => 'Radioen din, for å lese frekvens og modus',
			'extensionsPanel.canControlRadio' => 'Radioen din, for å styre den og sende med den — avstemming, effekt, CW, talememorier og PTT',
			'extensionsPanel.canSetUserAgent' => 'Identifisere seg overfor servere med sitt eget navn',
			'extensionsPanel.noCapabilities' => 'Den ber ikke om noe utenfor appen.',
			'extensionsPanel.sandboxNote' => 'Utvidelser kjører i sandkasse: ingen tilgang til filene dine, og ikke noe nettverk utover det som står her.',
			'extensionsPanel.installAction' => 'Installer',
			'extensionsPanel.updateAction' => 'Oppdater',
			'extensionsPanel.installFailed' => 'Utvidelsen kunne ikke installeres',
			'extensionsPanel.installedBadge' => 'Installert',
			'extensionsPanel.uninstallAction' => 'Fjern',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Fjerne ${name}?',
			'extensionsPanel.uninstallBody' => 'Denne utvidelsen og innstillingene dens blir fjernet. Loggene dine forblir urørt.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'Installerte ${name}',
			'extensionsPanel.installDownloading' => 'Laster ned…',
			'extensionsPanel.installWaiting' => 'Venter på å installere…',
			'extensionsPanel.installInstalling' => 'Installerer…',
			'extensionsPanel.installAwaitingApproval' => 'Venter på godkjenningen din…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} installeres allerede.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Oppdatert til ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Installasjonen av ${name} ble ikke fullført. Den må kanskje installeres på nytt.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Kunne ikke fjerne ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Lastet ned fra ${source}',
			'extensionsPanel.dropHint' => 'Slipp en .h2kext-utvidelse her for å installere den',
			'extensionsPanel.dropOneOnly' => 'Slipp én utvidelse om gangen.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} svarte med ${status} for den utvidelsen.',
			'extensionsPanel.downloadTooLarge' => 'Den nedlastingen er altfor stor til å være en utvidelse.',
			'extensionsPanel.downloadNotSecure' => 'Den nedlastingen ble omdirigert til et usikkert sted.',
			'extensionsPanel.catalogSection' => 'Katalog',
			'extensionsPanel.catalogLoading' => 'Laster katalogen…',
			'extensionsPanel.catalogUnreachable' => 'Katalogen kan ikke nås',
			'extensionsPanel.builtIn' => 'Innebygd',
			'extensionsPanel.updateAvailableBadge' => 'Oppdatering tilgjengelig',
			'extensionsPanel.updatesAvailableTitle' => 'Oppdateringer for utvidelser',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'En oppdatering er tilgjengelig for ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} og ${count} til må oppdateres.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} må oppdateres.',
			'extensionsPanel.pendingUpdatesSection' => 'Ventende oppdateringer',
			'extensionsPanel.updateAllAction' => 'Oppdater alle',
			'extensionsPanel.updatesUnderWay' => 'Disse oppdateringene pågår allerede.',
			'extensionsPanel.updatesNothingLeft' => 'Utvidelsene dine er oppdatert.',
			'extensionsPanel.updatesNoticeAction' => 'Mer info',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Oppdatere ${count} utvidelse?', other: 'Oppdatere ${count} utvidelser?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Utvidelsene dine er klare',
			'extensionsPanel.upgradeDoneBody' => 'De kommer nå fra Ham2Ks utvidelseskatalog, så de kan oppdateres uten å vente på en ny versjon av appen.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Ikke oppgradert: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Ville ikke kjøre: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'De er fortsatt installert og merket i Innstillinger › Utvidelser — hvis du oppdaterer dem der, kommer de tilbake.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Katalogen har ingen direkte erstatning for disse, så se der etter utvidelser som dekker det du brukte.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'State Parks-arrangementer',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} av utvidelsene dine har ikke kommet ennå. De lastes ned neste gang utvidelseskatalogen kan nås.',
			'extensionsPanel.runtimeDeadBody' => 'Utvidelsene dine ville ikke starte. En omstart av appen bør få dem tilbake.',
			'extensionsPanel.refusedTitle' => 'Noen utvidelser ville ikke kjøre',
			'extensionsPanel.upgradeBusyTitle' => 'Setter fortsatt opp',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Utvidelsene dine kjører ikke',
			'extensionsPanel.restoreTitle' => 'Noen av utvidelsene dine mangler',
			'extensionsPanel.restoreBody' => 'Disse utvidelsene du installerte, finnes ikke på denne enheten. Vi kan laste dem ned igjen fra Ham2Ks utvidelseskatalog:',
			'extensionsPanel.restoreFromFile' => 'Installert fra en fil. Installer disse på nytt fra filene deres, eller glem dem:',
			'extensionsPanel.restoreOtherCatalog' => 'Installert fra en annen utvidelseskatalog, så de er ikke tilgjengelige her:',
			'extensionsPanel.restoreForget' => 'Glem',
			'extensionsPanel.restoreInstall' => 'Installer',
			'extensionsPanel.restoreLater' => 'Senere',
			'extensionsPanel.restoreInstalling' => 'Installerer utvidelsene dine…',
			'extensionsPanel.restoreDoneTitle' => 'Utvidelsene dine er tilbake',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Installert på nytt: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Noen utvidelser kunne ikke installeres',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Kunne ikke installere: ${names}. Vi tilbyr dem igjen neste gang du åpner appen.',
			'extensionsPanel.restoreBusyBody' => 'Appen setter fortsatt opp utvidelsene dine. Vi tilbyr disse igjen neste gang du åpner appen.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Vi installerte dem på nytt, men utvidelsene dine ville ikke starte. En omstart av appen bør få dem tilbake.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} ble trukket tilbake',
			'extensionsPanel.revokedBody' => 'Katalogen trakk tilbake denne versjonen, så den er deaktivert.',
			'extensionsPanel.downloadHashMismatch' => 'Den nedlastingen er ikke utvidelsen katalogen beskrev.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Katalogen har ingen versjon ${version} av ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Den kataloglenken peker ikke på en versjon av en utvidelse.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Katalogen har ingen utgivelse av ${key} på det sporet.',
			'extensionsPanel.installFromLink' => 'Installer fra lenke',
			'extensionsPanel.unstableReleaseWarning' => 'Dette er en ustabil utgivelse som utgiveren ikke har erklært ferdig. Den kan oppføre seg feil, og den vil fortsette å få ustabile oppdateringer.',
			'extensionsPanel.bleedingReleaseWarning' => 'Dette er en dagsfersk utgivelse: arbeid som pågår, og som kan slutte å virke eller miste innstillingene sine. Den vil fortsette å få dagsferske oppdateringer.',
			'extensionsPanel.channelUnstable' => 'Ustabil',
			'extensionsPanel.channelBleeding' => 'Dagsfersk',
			'extensionsPanel.followsUnstable' => 'Får ustabile og stabile utgivelser',
			'extensionsPanel.followsBleeding' => 'Får dagsferske, ustabile og stabile utgivelser',
			'extensionsPanel.followStableAction' => 'Følg bare stabile utgivelser',
			'extensionsPanel.revokedBadge' => 'Trukket tilbake',
			'extensionsPanel.refusedBadge' => 'Ble ikke lastet',
			'extensionsPanel.downloadNotHttps' => 'Den nedlastingen går ikke over en sikker tilkobling.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} kunne ikke nås for den utvidelsen.',
			'extensionsPanel.detailsAction' => 'Detaljer',
			'extensionsPanel.installedFromFile' => 'Installert fra en fil',
			'extensionsPanel.detailsWhatItDoes' => 'Gir støtte for',
			'extensionsPanel.installedPreloaded' => 'Forhåndsinstallert',
			'extensionsPanel.hookAccount' => 'Kontoinnlogging',
			'extensionsPanel.hookCallNotes' => 'Kallesignalnotater',
			'extensionsPanel.hookDataFile' => 'Offlinedata',
			'extensionsPanel.hookExport' => 'Eksport',
			'extensionsPanel.hookLookup' => 'Kallesignaloppslag',
			'extensionsPanel.hookScoring' => 'Poengberegning',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Jakter ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Aktiverer ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '… og ${count} annen utvidelse', other: '… og ${count} andre utvidelser', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} utvidelse tilgjengelig', other: '${count} utvidelser tilgjengelig', ), 
			'home.title' => 'Portabel logger',
			'home.newOperation' => 'Ny operasjon',
			'home.stationCallsign' => 'Stasjonskallesignal',
			'home.titleOptional' => 'Tittel (valgfritt)',
			'home.emptyList' => 'Ingen operasjoner ennå. Opprett en for å begynne å logge.',
			'home.quickLookup' => 'Hurtigoppslag',
			'home.nav.operations' => 'Operasjoner',
			'home.nav.chase' => 'Jakt',
			'home.nav.logs' => 'Logger',
			'home.nav.maps' => 'Kart',
			'home.nav.settings' => 'Innstillinger',
			'home.panels.operations' => 'Operasjonsliste',
			'home.panels.operationsDescription' => 'Operasjonene dine, nyeste først.',
			'home.panels.version' => 'Gjeldende versjon',
			'home.panels.versionDescription' => 'Ham2K-merket, navnet på denne appen og hvilken build du kjører.',
			'home.toggleNav' => 'Vis eller skjul navigasjonsetikettene',
			'home.logs.title' => 'Logger',
			'home.logs.titleFor' => 'Logger for',
			'home.logs.emptyCallsigns' => 'Ingen QSOer logget ennå',
			'home.logs.emptyQsos' => ({required Object call}) => 'Ingen QSOer for ${call}',
			'home.logs.mapNoSelection' => 'Velg en QSO for å se den på kartet',
			'home.logs.searchHint' => 'Søk etter kallesignal eller navn',
			'home.logs.noSearchMatches' => 'Ingen QSOer samsvarer med søket',
			'home.logs.titleAll' => 'Alle logger',
			'home.logs.allCallsigns' => 'Alle kallesignaler',
			'home.logs.noOperation' => 'Ikke del av en operasjon',
			'home.logs.unsavedTitle' => 'Ulagrede endringer',
			'home.logs.unsavedBody' => 'Denne QSOen har endringer du ikke har lagret.',
			'home.logs.pendingDeleteBody' => 'Denne QSOen er merket for sletting.',
			'home.logs.editGone' => 'Ikke lagret: den QSOen finnes ikke lenger i denne loggen.',
			'home.logs.discard' => 'Forkast',
			'home.logs.columns.date' => 'Dato',
			'home.logs.columns.time' => 'Tid',
			'home.logs.columns.freq' => 'Frekvens',
			'home.logs.columns.mode' => 'Modus',
			'home.logs.columns.call' => 'Kallesignal',
			'home.logs.columns.name' => 'Navn',
			'home.logs.columns.station' => 'Stasjon',
			'home.logs.columns.band' => 'Bånd',
			'home.logs.columns.sent' => 'Sendt',
			'home.logs.columns.rcvd' => 'Mottatt',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'Stat',
			'home.logs.columns.country' => 'Land',
			'home.logs.columns.refs' => 'Ref.',
			'home.logs.panels.qsos' => 'QSO-logg',
			'home.logs.panels.qsosDescription' => 'QSOene til det valgte kallesignalet, på tvers av alle operasjoner.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Totalt antall QSOer, eller kallesignaloppslaget for den valgte QSOen.',
			'home.logs.panels.map' => 'Kart',
			'home.logs.panels.mapDescription' => 'Posisjonen til den valgte QSOen.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Kallesignaler: ${calls}',
			'home.logs.import.skippedOne' => '1 post kunne ikke leses',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} poster kunne ikke leses',
			'home.logs.import.readingTitle' => 'Leser ADIF-fil…',
			'home.logs.import.checkingTitle' => 'Ser etter duplikater…',
			'home.logs.import.importingTitle' => 'Importerer QSOer…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} av ${total} kontrollert',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importert, av ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'jakter',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} og ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} og flere',
			'chase.station.title' => 'Jaktstasjon',
			'chase.station.stationLabel' => 'Stasjon: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Ingen posisjon',
			'chase.periodInline.today' => 'i dag',
			'chase.periodInline.thisWeek' => 'denne uken',
			'chase.periodInline.last14Days' => 'de siste 14 dagene',
			'chase.periodInline.thisMonth' => 'denne måneden',
			'chase.periodStats.today' => 'Statistikk for i dag',
			'chase.periodStats.thisWeek' => 'Statistikk for denne uken',
			'chase.periodStats.last14Days' => 'Statistikk for de siste 14 dagene',
			'chase.periodStats.thisMonth' => 'Statistikk for denne måneden',
			'chase.period.today' => 'I dag',
			'chase.period.thisWeek' => 'Denne uken',
			'chase.period.last14Days' => 'Siste 14 dager',
			'chase.period.thisMonth' => 'Denne måneden',
			'chase.goals.title' => 'Jaktmål',
			'chase.goals.remove' => ({required Object name}) => 'Slutt å jakte ${name}',
			'chase.goals.extensionsTitle' => 'Utvidelser som støtter jakt',
			'chase.panels.logging' => 'QSOer',
			'chase.panels.loggingDescription' => 'Loggekontroller over QSOene jaktet i perioden.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Kallesignalet som logges, eller statistikken for perioden.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Stasjoner spottet på lufta, klare til å jaktes.',
			'chase.panels.map' => 'Kart',
			'chase.panels.mapDescription' => 'Periodens QSOer og stasjonen som logges.',
			'dialogs.operationDetails' => 'Operasjonsdetaljer',
			'dialogs.activities' => 'Aktiviteter',
			'dialogs.stationCallsign' => 'Stasjonskallesignal',
			'dialogs.multiStationIdentifier' => 'Identifikator for multistasjon (kun tall)',
			'dialogs.notes' => 'Notater',
			'dialogs.deleteOperationTitle' => 'Slett operasjon',
			'dialogs.purgeTestsTitle' => 'Fjern testoperasjoner',
			'dialogs.purgeTestsBody' => 'Dette sletter disse testoperasjonene og QSOene deres permanent. Det kan ikke angres.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Pluss ${count} testkontakt som ikke hører til noen operasjon.', other: 'Pluss ${count} testkontakter som ikke hører til noen operasjon.', ), 
			'dialogs.purgeTestsAction' => 'Fjern',
			'dialogs.syncAllTitle' => 'Erstatte loggen på denne enheten?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL tar sikkerhetskopi av og fjerner ${qsos} fra denne enheten, og laster deretter ned kontoens logg på nytt fra serveren. Sikkerhetskopien blir liggende i databasen på denne enheten.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${n} QSO er ikke synkronisert ennå — serveren har aldri mottatt den, og den kommer IKKE tilbake.', other: '${n} QSOer er ikke synkronisert ennå — serveren har aldri mottatt dem, og de kommer IKKE tilbake.', ), 
			'dialogs.syncAllAction' => 'Tøm og synkroniser på nytt',
			'dialogs.receivedPurgesTitle' => 'Testoperasjoner fjernet et annet sted',
			'dialogs.receivedPurgesBody' => 'Disse ble slettet som testoperasjoner på en annen enhet. Fjerne dem her også? Dette sletter dem og QSOene deres permanent, og kan ikke angres.',
			'dialogs.receivedPurgesAction' => 'Fjern',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Ugyldig kallesignal: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Ugyldige kallesignaler: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} har vært operatør så langt. ${typed} blir registrert for nye kontakter.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Ingen operatør registrert så langt. ${typed} blir registrert for nye kontakter.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Denne operasjonen har allerede kontakter av ${calls}. ${typed} blir bare registrert for nye.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Registrer også ${typed} som operatør for kontakten som allerede er logget', other: 'Registrer også ${typed} som operatør for alle ${count} kontaktene som allerede er logget', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Når flere stasjonskallesignaler brukes på lufta, støttes ikke egne operatører',
			'dialogs.callChange.contactsUnreadable' => 'Kontaktene i denne operasjonen kunne ikke leses, så en endring av kallesignal her tilbyr ikke å oppdatere dem',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Kontaktene som allerede er logget, kunne ikke oppdateres, så ingen endringer ble gjort: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} av ${planned} kontakter ble oppdatert — resten finnes ikke lenger i denne operasjonen',
			'operation.deletedReadOnly' => 'Denne operasjonen er slettet. Gjenopprett den for å logge eller gjøre endringer.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOer',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'KART',
			'operation.tabs.qsosPlain' => 'QSOer',
			'operation.tabs.clock' => 'Klokke',
			'operation.tabs.weather' => 'Vær',
			'operation.tabs.website' => 'Nettsted',
			'operation.tabs.remoteScreen' => 'Fjernskjerm',
			'operation.tabs.solar' => 'Sol',
			'operation.tabs.radio' => 'Radio',
			'operation.positions.nobodyYet' => 'Ingen andre operatørplasser deler denne operasjonen ennå.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Plass: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'En annen plass',
			'operation.positions.thisDevice' => 'Vår operatørplass',
			'operation.positions.nameIn' => ' i ',
			'operation.positions.panelTitle' => 'Operatørplasser',
			'operation.positions.panelDescription' => 'Hva hver operatørplass som deler denne operasjonen, logger akkurat nå.',
			'operation.stationCallsignNone' => 'Ingen stasjonskallesignal',
			'operation.titleNone' => 'Ingen tittel',
			'operation.deleteOperation' => 'Slett operasjon',
			'operation.loggingControlsStale' => 'Aktivitetsfeltene kan være utdatert — åpne operasjonen på nytt for å oppdatere dem',
			'operation.locationNone' => 'Ikke satt',
			'operation.generalOperation' => 'Vanlig operasjon',
			'operation.titleFor' => ({required Object value}) => 'for ${value}',
			'operation.titleAt' => ({required Object value}) => 'på ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Nå ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'Vis RST-felt',
			'operation.menu.showStateField' => 'Vis stat-felt',
			'operation.menu.showGridField' => 'Vis grid-felt',
			'operation.menu.showDeletedQsos' => 'Vis slettede QSOer',
			'operation.menu.showDeletedOps' => 'Vis slettede operasjoner',
			'operation.menu.showQsoNumbers' => 'Vis QSO-nummer',
			'operation.menu.lookupAllQsos' => 'Slå opp alle QSOer',
			'operation.menu.loggingSettingsTitle' => 'Loggingsinnstillinger',
			'operation.menu.mapSettingsTitle' => 'Kartinnstillinger',
			'operation.menu.actionsSection' => 'Handlinger',
			'operation.layout.title' => 'Legg til et panel',
			'operation.layout.availableSection' => 'Tilgjengelige paneler',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Innstillinger for ${panel}',
			'operation.layout.panelSettingsAction' => 'Panelinnstillinger',
			'operation.layout.viewName' => 'Operasjonsvisning',
			'operation.layout.viewOptions' => 'Alternativer for visningsoppsett',
			'operation.layout.viewTitleBuiltIn' => 'Denne visningen er innebygd i appen, og det er navnet også',
			'operation.layout.resetOptions' => 'Gjenopprett standard',
			'operation.layout.removePane' => 'Fjern',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Gjenopprette standardinnstillingene for ${panel}?',
			'operation.layout.resetPaneConfirmBody' => 'Tittelen, toppteksten og størrelsen går tilbake til standard. Resten av oppsettet blir som det er.',
			'operation.layout.resetViewConfirm' => 'Gjenopprette standardoppsettet for denne visningen?',
			'operation.layout.resetViewConfirmBody' => 'Panelene går tilbake til standardplasseringen, og alternativene for visningen og hvert panel går tilbake til standard.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Oppsettinnstillinger for ${panel}',
			'operation.layout.paneTitle' => 'Tittel',
			'operation.layout.paneShowHeader' => 'Vis topptekst',
			'operation.layout.paneShowHeaderTabset' => 'Vises alltid mens dette panelet deler en gruppe — toppteksten er veien til de andre',
			'operation.layout.paneInherit' => 'Samme som appen',
			'operation.layout.searchHint' => 'Søk i paneler',
			'operation.layout.noPanelsMatch' => 'Ingen paneler samsvarer med søket.',
			'operation.layout.nothingToAdd' => 'Denne visningen har allerede alle mulige paneler',
			'operation.layout.addPanel' => ({required Object panel}) => 'Legg til ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Forhåndsvis ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Utvidelsen "${name}" mangler',
			'operation.layout.previewUnavailable' => 'Forhåndsvisningen av dette panelet kunne ikke vises.',
			'operation.layout.nestedPaneTitle' => 'Mer',
			'operation.layout.editLayout' => 'Rediger oppsett',
			'operation.layout.saveLayout' => 'Lagre oppsett',
			'operation.layout.revertLayout' => 'Forkast endringer i oppsettet',
			'operation.layout.done' => 'Ferdig',
			'operation.layout.layoutUnreadableTitle' => 'Oppsettet kunne ikke leses',
			'operation.layout.layoutUnreadableBody' => 'Det lagrede oppsettet ditt kunne ikke leses, så standardoppsettet vises i stedet. Originalen blir ikke overskrevet før du velger å beholde dette.',
			'operation.layout.layoutUnreadableAction' => 'Bruk dette oppsettet',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} kunne ikke vises',
			'operation.layout.panelRenderRetry' => 'Prøv igjen',
			'operation.layout.panelActionFailed' => 'Panelhandlingen mislyktes. Prøv igjen.',
			'operation.layout.panels.loggingDescription' => 'Loggen og registreringsfeltene',
			'operation.layout.panels.infoDescription' => 'Det vi vet om stasjonen vi har kontakt med',
			'operation.layout.panels.spotsDescription' => 'Spots fra clusterne og aktivitetsprogrammene',
			'operation.layout.panels.mapDescription' => 'Hvor kontaktene er',
			'operation.layout.panels.clockDescription' => 'En klokke, i hvilken som helst tidssone',
			'operation.layout.panels.clockFace' => 'Urskive',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analog',
			'operation.layout.panels.clockZone' => 'Tidssone',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Denne enheten',
			'operation.layout.panels.clockShowSeconds' => 'Vis sekunder',
			'operation.layout.panels.weatherDescription' => 'Forholdene nå og de neste åtte timene, der du er QRV',
			'operation.layout.panels.weatherUseOperationLocation' => 'Bruk posisjonen til operasjonen',
			'operation.layout.panels.weatherLocation' => 'Posisjon',
			'operation.layout.panels.weatherLocationDescription' => 'En grid-rute (FN31pr) eller lat,lon. Ignoreres mens «Bruk posisjonen til operasjonen» er avkrysset.',
			'operation.layout.panels.weatherNoLocation' => 'Ingen posisjon satt. Gi dette panelet en posisjon i innstillingene, eller plasser det i en operasjon som har en.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Kunne ikke lese posisjonen ${location}. Bruk en grid-rute som FN31pr, eller 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Kunne ikke nå Open-Meteo — ikke noe nettverk? Prøver igjen snart.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo svarte, men ikke med noe som kunne leses. Prøver igjen snart.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'kast ${speed}',
			'operation.layout.panels.panelAgeNow' => 'akkurat nå',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} min siden', other: '${count} min siden', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} t siden', other: '${count} t siden', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Ukjent',
			'operation.layout.panels.weatherConditions.sunny' => 'Sol',
			'operation.layout.panels.weatherConditions.clear' => 'Klart',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Stort sett sol',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Stort sett klart',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Delvis skyet',
			'operation.layout.panels.weatherConditions.cloudy' => 'Skyet',
			'operation.layout.panels.weatherConditions.foggy' => 'Tåke',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Rimtåke',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Lett yr',
			'operation.layout.panels.weatherConditions.drizzle' => 'Yr',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Kraftig yr',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Lett underkjølt yr',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Underkjølt yr',
			'operation.layout.panels.weatherConditions.lightRain' => 'Lett regn',
			'operation.layout.panels.weatherConditions.rain' => 'Regn',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Kraftig regn',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Lett underkjølt regn',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Underkjølt regn',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Lett snø',
			'operation.layout.panels.weatherConditions.snow' => 'Snø',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Kraftig snø',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Kornsnø',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Lette byger',
			'operation.layout.panels.weatherConditions.showers' => 'Byger',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Kraftige byger',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Lette snøbyger',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Snøbyger',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Tordenvær',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Lett tordenvær med hagl',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Tordenvær med hagl',
			'operation.layout.panels.websiteDescription' => 'En nettside du velger selv, i et panel',
			'operation.layout.panels.websiteUrl' => 'Adresse',
			'operation.layout.panels.websiteRefresh' => 'Oppdater',
			'operation.layout.panels.websiteRefreshNever' => 'Aldri',
			'operation.layout.panels.websiteRefresh1' => 'Hvert minutt',
			'operation.layout.panels.websiteRefresh5' => 'Hvert 5. minutt',
			'operation.layout.panels.websiteRefresh15' => 'Hvert 15. minutt',
			'operation.layout.panels.websiteTitle' => 'Panelnavn',
			'operation.layout.panels.websiteRefreshNow' => 'Oppdater nå',
			'operation.layout.panels.websiteNoUrl' => 'Ingen adresse ennå. Åpne innstillingene for dette panelet for å velge en side.',
			'operation.layout.panels.websiteBadUrl' => 'Det ser ikke ut som en nettadresse. Den må begynne med https://',
			'operation.layout.panels.websiteNotHttps' => 'Bare adresser med https:// kan vises her.',
			'operation.layout.panels.websiteUnsupported' => 'Nettsider kan ikke vises i et panel på dette systemet.',
			'operation.layout.panels.websiteOpenExternally' => 'Åpne i nettleser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Kunne ikke laste siden: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'En skjerm, app eller et vindu som deles av en annen av enhetene dine.',
			'operation.layout.panels.remoteScreenTarget' => 'Skjerm',
			'operation.layout.panels.remoteScreenChoose' => 'Velg en skjerm…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Delte skjermer',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Ingen av enhetene dine deler en skjerm. Slå på Del skjermer og vinduer under Innstillinger → Andre enheter, på enheten du vil se.',
			'operation.layout.panels.remoteScreenUnset' => 'Ingen skjerm valgt. Åpne innstillingene for dette panelet for å velge en som de andre enhetene dine deler.',
			'operation.layout.panels.remoteScreenConnecting' => 'Kobler til…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Den enheten er ikke tilkoblet akkurat nå.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Den enheten sluttet å dele denne skjermen.',
			'operation.layout.panels.remoteScreenNoListener' => 'Den enheten kan ikke ta imot tilkoblinger — sjekk brannmuren på den.',
			'operation.layout.panels.remoteScreenNoLan' => 'Skjermer deles bare over det lokale nettverket, ikke over Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Den enheten ville ikke dele denne skjermen.',
			'operation.layout.panels.remoteScreenSettings' => 'Panelinnstillinger',
			'operation.layout.panels.remoteScreenAdjust' => 'Juster visning',
			'operation.layout.panels.remoteScreenDetail' => 'Detaljnivå',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Høyt',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maksimalt',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Zoom inn',
			'operation.layout.panels.remoteScreenZoomOut' => 'Zoom ut',
			'operation.layout.panels.remoteScreenStopped' => 'Den skjermen eller det vinduet vises ikke lenger.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Den enheten kunne ikke ta opp den skjermen — den trenger kanskje tillatelse til skjermopptak.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Den enheten svarte ikke. Kanskje skjermdeling ikke er slått på.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Kunne ikke åpne en tilkobling for bildet. Sjekk brannmuren på denne enheten.',
			'operation.layout.panels.solarDescription' => 'Sol- og geomagnetiske forhold, med forplantning bånd for bånd',
			'operation.layout.panels.solarUnreachable' => 'Kunne ikke nå hamqsl.com — ikke noe nettverk? Prøver igjen snart.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com svarte, men ikke med en måling vi kunne bruke. Prøver igjen snart.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Dag',
			'operation.layout.panels.solarBandNight' => 'Natt',
			'operation.layout.panels.solarBandGood' => 'Gode',
			'operation.layout.panels.solarBandFair' => 'Middels',
			'operation.layout.panels.solarBandPoor' => 'Dårlige',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Kilder: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Tilkoblingen sliter — hopper over bilder.',
			'operation.layout.panels.remoteScreenStalled' => 'Bildene kommer ikke lenger fram — denne tilkoblingen kan være for treg.',
			'operation.layout.panels.radioDescription' => 'En radios frontpanel — frekvens, modus og effekt, styrt via CAT',
			'operation.layout.panels.radioStyle' => 'Stil',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderne',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — ingen radio angitt',
			'operation.layout.panels.radioNoRadio' => 'Ingen radio å vise. Velg en i innstillingene for dette panelet, eller legg til en under Stasjonsoppsett.',
			'operation.layout.panels.radioNotConfigured' => 'Denne radioen er ikke satt opp ennå. Velg port eller adresse under Stasjonsoppsett.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio ikke tilkoblet',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Koble til denne radioen',
			'operation.layout.panels.radioDisconnect' => 'Koble fra denne radioen',
			'operation.layout.panels.radioStale' => 'INGEN DATA',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'høy SWR',
			'operation.layout.htmlPanelUnsupported' => 'Dette panelet trenger en nettvisning, som denne plattformen ikke har',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Dette panelet trenger en sandkasse som nettversjonen ikke kan tilby',
			'operation.export.title' => 'Eksport av operasjon',
			'operation.export.syncedOperation' => 'Operasjonen er synkronisert',
			'operation.export.unsyncedOperation' => 'Operasjonen har endringer som ikke er synkronisert',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} QSO i denne operasjonen', other: '${count} QSOer i denne operasjonen', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Alle ${total} QSOer er synkronisert',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} av ${total} QSOer venter på synkronisering',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} hendelsesmarkører synkronisert',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} av ${total} hendelsesmarkører venter',
			'operation.export.loading' => 'Laster eksportalternativer…',
			'operation.export.noOptions' => 'Ingen eksportformater tilgjengelig (starter utvidelsene fortsatt?)',
			'operation.export.nothingLogged' => 'Ingenting å eksportere ennå — denne operasjonen har ingen QSOer.',
			'operation.export.share' => 'Del',
			'operation.export.nothingSelected' => 'Ingenting valgt',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Lagre ${count} fil', other: 'Lagre ${count} filer', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Del ${count} fil', other: 'Del ${count} filer', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Eksporter ${count} fil', other: 'Eksporter ${count} filer', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Last ned ${count} fil', other: 'Last ned ${count} filer', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Lagre ${count} samlet fil', other: 'Lagre ${count} samlede filer', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Del ${count} samlet fil', other: 'Del ${count} samlede filer', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Eksporter ${count} samlet fil', other: 'Eksporter ${count} samlede filer', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Last ned ${count} samlet fil', other: 'Last ned ${count} samlede filer', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => 'Lagre ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Del ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Eksporter ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Last ned ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Legg ${count} fil i Stash', other: 'Legg ${count} filer i Stash', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Legg ${count} samlet fil i Stash', other: 'Legg ${count} samlede filer i Stash', ), 
			'operation.export.settingsButton' => 'Eksportinnstillinger',
			'operation.export.settingsTitle' => 'Eksportinnstillinger',
			'operation.export.compactFileNames.title' => 'Bruk kompakte filnavn',
			'operation.export.compactFileNames.descriptionOn' => 'Korte navn laget for opplastingsverktøy, som N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Lesbare navn, som 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Inkluder privat info',
			'operation.export.includePrivateData.descriptionOn' => 'Navn, adresser, e-poster, grid-ruter og notater tas med',
			'operation.export.includePrivateData.descriptionOff' => 'Navn, adresser, e-poster, grid-ruter og notater utelates',
			'operation.export.includePrivateData.note' => 'Full ADIF-eksport tar alltid med alt',
			'operation.export.resultTitle' => 'Eksport fullført',
			'operation.export.resultFailedTitle' => 'Eksport mislyktes',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Eksporterte ${count} fil til ${path}', other: 'Eksporterte ${count} filer til ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Eksporterte ${count} fil: ${path}', other: 'Eksporterte ${count} filer: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Delte ${count} fil', other: 'Delte ${count} filer', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Lastet ned ${count} fil', other: 'Lastet ned ${count} filer', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Eksport mislyktes: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Legg til en e-postadresse først',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash sender filene dine til e-postadressen på LoFi-kontoen din, og du logger inn med den på stash.ham2k.net. Kontoen din har ikke en bekreftet adresse ennå — legg den til i Innstillinger › Skysynkronisering.',
			'operation.export.stash.openSyncSettings' => 'Åpne Skysynkronisering',
			'operation.export.stash.replaceTitle' => 'Nylig stash blir erstattet',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Du sendte «${name}» for mindre enn 6 timer siden, og den er ikke lastet ned ennå. Gratiskontoer beholder én stash om gangen, så hvis du sender nå, blir den erstattet.',
			'operation.export.stash.replaceConfirm' => 'Send likevel',
			'operation.export.stash.failedTitle' => 'Kunne ikke sende til Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'Sendt til Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Du kan hente denne filen ved å gå til **[stash.ham2k.net](https://stash.ham2k.net)** i hvilken som helst nettleser.', other: 'Du kan hente disse filene ved å gå til **[stash.ham2k.net](https://stash.ham2k.net)** i hvilken som helst nettleser.', ), 
			'operation.export.stash.mayHaveArrived' => 'Ikke noe svar fra Stash — filen kan ha kommet fram likevel. Sjekk stash.ham2k.net før du sender på nytt',
			'operation.export.stash.notSent' => 'ikke sendt',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Denne filen kom ikke fram:', other: 'Disse ${count} filene kom ikke fram:', ), 
			'operation.export.stash.emailOffer' => 'Eller for enkelhets skyld kan vi sende deg en e-post med en direkte lenke.',
			'operation.export.stash.emailMe' => 'Send meg en lenke på e-post',
			'operation.export.stash.emailSent' => 'Vi har sendt deg en nedlastingslenke på e-post.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Kunne ikke sende e-posten: ${error}',
			'operation.export.stash.freeTier' => 'Gratiskontoer kan bare beholde én stash om gangen. Abonnenter kan beholde så mange de vil.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Sendte ${count} fil til Ham2K File Stash (stash.ham2k.net)', other: 'Sendte ${count} filer til Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Ingen spots samsvarer med filtrene dine',
			'operation.spots.error' => ({required Object error}) => 'Kunne ikke laste spots: ${error}',
			'operation.spots.unknownBand' => 'Annet',
			'operation.spots.auto' => 'Automatisk',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatisk (for øyeblikket ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Alle',
			'operation.spots.allBands' => 'Alle bånd',
			'operation.spots.allModes' => 'Alle moduser',
			'operation.spots.phoneAndCw' => 'Telefoni og CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Viser ${count} av ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutter',
			'operation.spots.callsOfNote' => 'Kjente kallesignaler',
			'operation.spots.yourSpots' => 'Dine spots',
			'operation.spots.allSpots' => 'Alle spots',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Asia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Nord-Amerika',
			'operation.spots.continents.oc' => 'Oseania',
			'operation.spots.continents.sa' => 'Sør-Amerika',
			'operation.spots.continents.an' => 'Antarktis',
			'operation.spots.filters.title' => 'Filtrer spots',
			'operation.spots.filters.band' => 'Bånd',
			'operation.spots.filters.mode' => 'Modus',
			'operation.spots.filters.age' => 'Alder',
			'operation.spots.filters.sources' => 'Kilder',
			'operation.spots.filters.continent' => 'Kontinent',
			'operation.spots.filters.sorting' => 'Sortering',
			'operation.spots.filters.sortByTime' => 'Etter spot-tid',
			'operation.spots.filters.sortByFrequency' => 'Etter frekvens',
			'operation.spots.filters.groupByBand' => 'Grupper etter bånd',
			'operation.spots.filters.groupCallsWithNotes' => 'Grupper kallesignaler med notater',
			'operation.spots.filters.sourceNoReply' => 'Ikke noe svar',
			'operation.spots.filters.sourceError' => 'Feil',
			'operation.spots.unavailableTitle' => 'Spots utilgjengelige',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} svarte ikke.',
			'operation.spots.failedTitle' => 'Feil fra spot-kilde',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} returnerte en feil.',
			'operation.spots.slideLogIt' => 'Logg den',
			'operation.spots.slideIgnore' => 'Ignorer',
			'operation.spots.slideRestore' => 'Gjenopprett',
			'operation.spots.logConflict.title' => 'Loggepanelet er opptatt',
			'operation.spots.logConflict.editingBody' => 'Du redigerer en logget kontakt. Logge denne spoten i stedet, eller gå tilbake og fullføre redigeringen?',
			'operation.spots.logConflict.composingBody' => 'Du har begynt å registrere en kontakt. Logge denne spoten i stedet, eller gå tilbake og fullføre det du skrev?',
			'operation.spots.logConflict.goBack' => 'Gå tilbake',
			'operation.spots.logConflict.clearAndLog' => 'Tøm og logg spot',
			'operation.import.title' => 'Importer data til operasjonen',
			'operation.import.importAdifAction' => 'Importer QSOer fra ADIF',
			'operation.import.settingsButton' => 'Lytteinnstillinger',
			'operation.import.settingsTitle' => 'Lytt etter andre apper',
			'operation.import.protocolAddressLabel' => 'Adresse',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Oppgi en port mellom 1 og 65535',
			'operation.import.protocolAddressInvalid' => 'Oppgi en gyldig IP-adresse (f.eks. 127.0.0.1 eller 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Mottar data',
			'operation.import.protocolStatusNoData' => 'Ingen data mottatt nylig',
			'operation.import.protocolBindError' => ({required Object error}) => 'Kunne ikke begynne å lytte: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Innkommende QSOer kunne ikke lagres og forsøkes på nytt: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Alle (kringkasting)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → fanen Broadcast Data → kryss av for "Enable Broadcasts" for kontaktinfo. Sett IP-adressen til 127.0.0.1 hvis programmet kjører på samme datamaskin, eller 255.255.255.255 for å kringkaste på det lokale nettverket.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → fanen Reporting → seksjonen UDP Server → kryss av for "Accept UDP requests". Sett UDP Server til 127.0.0.1 hvis programmet kjører på samme datamaskin, eller en multicast-adresse som 239.239.0.2, og bruk samme adresse i oppsettet ovenfor i denne appen.',
			'operation.import.listenTitle' => 'Lytt etter QSOer fra andre apper',
			'operation.import.listenDescriptionOnN1mm' => 'Lytter etter N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Lytter etter WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Lytter etter N1MM+ og WSJT-X',
			'operation.import.listenDescriptionOff' => 'Av',
			'operation.import.addToOperationTitle' => 'Legg til i denne operasjonen',
			'operation.import.addToOperationDescriptionOn' => 'Mottatte QSOer legges til i denne operasjonen etter hvert som de kommer',
			'operation.import.addToOperationDescriptionOff' => 'Mottatte QSOer holdes tilbake til du slår på dette',
			'operation.import.pendingSectionTitle' => 'Mottatte QSOer',
			'operation.import.pendingEmpty' => 'Ingenting mottatt ennå',
			'operation.import.stationMismatch' => ({required Object call}) => 'Logget som ${call}, ikke stasjonen til denne operasjonen',
			'operation.import.discardAction' => 'Forkast',
			'operation.import.gapDialogTitle' => 'Ta med tidligere mottatte?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} QSOer til ble mottatt tidligere, før et opphold i dataene. Ta med dem også?',
			'operation.import.gapDialogRecentOnly' => 'Bare de nyeste',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Ta med alle ${count}',
			'map.outlineIssue.link' => 'Feil?',
			'map.outlineIssue.title' => 'Rapporter en feil i et omriss',
			'map.outlineIssue.reference' => 'Hvilket omriss',
			'map.outlineIssue.severity' => 'Hvor ille er det?',
			'map.outlineIssue.minor' => 'Liten detalj',
			'map.outlineIssue.major' => 'Stor feil',
			'map.outlineIssue.explanation' => 'Hva er galt med det?',
			'map.outlineIssue.explanationHint' => 'Hva omrisset har feil, og hvor',
			'map.outlineIssue.send' => 'Send',
			'map.outlineIssue.sending' => 'Sender rapporten din — takk',
			'map.outlineIssue.copy' => 'Kopier rapport',
			'map.outlineIssue.notSent' => 'Kunne ikke sende rapporten',
			'map.outlineIssue.copied' => 'Rapporten er kopiert',
			'map.outlineIssue.notCopied' => 'Kunne ikke kopiere rapporten',
			'map.outlinesDisclaimer' => 'Omrissene er bare til veiledning. Gjør dine egne undersøkelser!',
			'map.outlinesCredit' => ({required Object sources}) => 'Omriss: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Grenser: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Fasiliteter: ${sources}',
			'map.fullCredits' => 'Fullstendige datakilder',
			'map.fewerCredits' => 'Færre kilder',
			'map.emptyState' => 'Ingen QSO-posisjoner ennå.\nQSOer med grid-rute, stat eller land vises her.',
			'map.unavailable' => 'Kartet er ikke tilgjengelig akkurat nå.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Flatt',
			'map.globe' => 'Globus',
			'map.zoomIn' => 'Zoom inn',
			'map.zoomOut' => 'Zoom ut',
			'map.postcard.button' => 'Operasjonspostkort',
			'map.postcard.title' => ({required Object title}) => 'Postkort for ${title}',
			'map.postcard.portrait' => 'Stående',
			'map.postcard.landscape' => 'Liggende',
			'map.postcard.square' => 'Kvadratisk',
			'map.postcard.save' => 'Lagre…',
			'map.postcard.download' => 'Last ned',
			'map.postcard.share' => 'Del',
			'map.postcard.copy' => 'Kopier',
			'map.postcard.copied' => 'Kopiert til utklippstavlen',
			'map.postcard.saved' => ({required Object path}) => 'Lagret i ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Lastet ned ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Lagret ${count} bilder i ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Lagret ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} var allerede lagret',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Laster ned ${count} bilder — tillat dem hvis nettleseren spør',
			'map.postcard.mapLeftOut' => 'Kartet ble ikke lastet, så det ble utelatt',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — kartet ble ikke lastet, så det ble utelatt',
			'map.postcard.continued' => ({required Object title}) => '${title} (fortsettelse)',
			'map.postcard.previousPage' => 'Forrige side',
			'map.postcard.nextPage' => 'Neste side',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Side ${page} av ${count}',
			'map.postcard.sectionDays' => 'Hver dag',
			'map.postcard.reset' => 'Tilbakestill',
			'map.postcard.failed' => ({required Object error}) => 'Kunne ikke lage postkortet: ${error}',
			'map.postcard.mapNotReady' => 'Kartet ble ikke ferdig lastet. Sjekk tilkoblingen og prøv igjen.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Kunne ikke lagre postkortet: ${error}',
			'map.postcard.copyFailed' => 'Utklippstavlen tok ikke imot bildet. Prøv igjen.',
			'map.postcard.shareFailed' => 'Kunne ikke dele postkortet. Prøv igjen.',
			'map.postcard.fileName' => 'postkort',
			'mapsView.title' => 'Kart',
			'mapsView.searchHint' => 'Søk etter parker, toppunkter og mer',
			'mapsView.activities' => 'Aktiviteter',
			'mapsView.layers' => 'Lag',
			'mapsView.baseMap' => 'Grunnkart',
			'mapsView.satellite' => 'Satellitt (Esri)',
			'mapsView.facilities' => 'Parkfasiliteter',
			'mapsView.boundaries' => 'Grenser',
			'mapsView.currentLocation' => 'Nåværende posisjon',
			'mapsView.noMatches' => ({required Object text}) => 'Ingenting samsvarer med «${text}»',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} referanse ved ${where}', other: '${count} referanser ved ${where}', ), 
			'mapsView.startOperation' => 'Start en operasjon med disse referansene',
			'activitiesView.title' => 'Aktiviteter',
			'activitiesView.activitiesCountZero' => 'Ingen aktiviteter valgt',
			'activitiesView.activitiesCountOne' => '1 aktivitet',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} aktiviteter',
			'activitiesView.empty' => 'Ingen aktiviteter ennå — bruk Forslag og søk nedenfor for å legge til en',
			'activitiesView.removeActivity' => 'Fjern',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Åpne ${name}',
			'activitiesView.editActivity' => 'Rediger aktivitet',
			'activitiesView.manageExtensions' => 'Administrer utvidelser',
			'activitiesView.manage' => 'Administrer',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Aktivitetstyper: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Aktivitetstyper: ${first} og ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Aktivitetstyper: ${first}, ${second} og ${more} til',
			'activitiesView.reference' => 'Referanse',
			'activitiesView.invalidReference' => 'Ugyldig',
			'activitiesView.duplicateReference' => 'Allerede lagt til',
			'activitiesView.searchHint' => 'Søk etter navn, referanse eller noe annet…',
			'activitiesView.noSuggestions' => 'Ingen treff',
			'activitiesView.noSuggestionsHint' => 'Søk etter referansenavn eller -nummer ovenfor',
			'activitiesView.noSuggestionsExample' => '(for eksempel \'trail\' eller \'4556\')',
			'activitiesView.allOptions' => 'Aktivitetstyper',
			'activitiesView.determiningLocation' => 'Finner gjeldende posisjon…\nVenter på GPS-posisjon for å finne referanser i nærheten',
			'activitiesView.locationUnavailableTitle' => 'Posisjonsdata er ikke tilgjengelig',
			'activitiesView.locationDeniedTitle' => 'Tilgang til posisjon avslått',
			'activitiesView.locationBlockedTitle' => 'Tilgang til posisjon blokkert',
			'activitiesView.noNearbyReason' => 'Kan ikke finne referanser i nærheten',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Trykk på ${icon} for å angi posisjonen din manuelt,\neller bare søk etter referanser med navn',
			'activitiesView.locationGrantAction' => 'Gi tilgang til posisjon',
			'activitiesView.locationSettingsAction' => 'Åpne Innstillinger',
			'activitiesView.locationSettingsUnavailable' => 'Gi tilgang til posisjon i systeminnstillingene',
			'activitiesView.locationGrantRefused' => 'Fortsatt ingen posisjon — systemet sa nei igjen',
			'activitiesView.searchUnavailableTitle' => 'Aktivitetssøk utilgjengelig',
			'activitiesView.searchUnavailableReason' => 'Ingen aktivitetsutvidelse kunne kjøre søket. Prøv igjen om et øyeblikk.',
			'activitiesView.emptySheet' => 'Bruk forslag og søk nedenfor for å legge til en',
			'activitiesView.exports' => 'Eksporter',
			'activitiesView.exportLogs' => 'Eksporter logger',
			'activitiesView.tools' => 'Verktøy',
			'activitiesView.toolsTitle' => 'Operasjonsverktøy',
			'activitiesView.operationDetails' => 'Operasjonsdetaljer',
			'activitiesView.share' => 'Del',
			'activitiesView.archive' => 'Arkiver',
			'activitiesView.deleteOperation' => 'Slett operasjon',
			'activitiesView.undeleteOperation' => 'Gjenopprett operasjon',
			'activitiesView.alreadySelected' => 'Allerede valgt',
			'activitiesView.selected' => 'Valgt',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} av ${count}',
			'activitiesView.previousPick' => 'Forrige treff',
			'activitiesView.nextPick' => 'Neste treff',
			'activitiesView.retiredReference' => 'Utgått',
			'activitiesView.enableExtension' => ({required Object name}) => 'Aktiver ${name}',
			'activitiesView.enableExtensionHint' => 'Denne utvidelsen samsvarer med søket ditt, men den er ikke aktivert',
			'activitiesView.enableExtensionForRefHint' => 'Denne utvidelsen håndterer en av referansene i denne operasjonen, men den er ikke aktivert',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} kjører ikke',
			'activitiesView.extensionNotRunningHint' => 'Denne utvidelsen er deaktivert, åpne Utvidelsesinnstillinger for mer info',
			'activitiesView.installExtension' => ({required Object name}) => 'Installer ${name}',
			'activitiesView.installExtensionHint' => 'Denne utvidelsen samsvarer med søket ditt, men den er ikke installert',
			'activitiesView.onlyCatalogMatches' => 'Ingen treff\nNoen utvidelser i katalogen kan ha resultater.\nInstaller dem under Aktivitetstyper nedenfor.',
			'activitiesView.setupUnavailable' => 'Kunne ikke laste oppsettet for denne aktiviteten — prøv igjen fra Administrer',
			'activitiesView.controlsUnavailableTitle' => 'Aktivitetskontroller utilgjengelige',
			'activitiesView.controlsUnavailableReason' => 'Referansene dine er trygge, men de kan ikke redigeres akkurat nå.',
			'activitiesView.controlsUnavailableRetry' => 'Prøv igjen',
			'activitiesView.onlyDisabledMatches' => 'Ingen treff\nNoen tilgjengelige utvidelser kan ha resultater.\nAktiver dem under Aktivitetstyper nedenfor.',
			'activitiesView.onlyNotRunningMatches' => 'Ingen treff\nNoen utvidelser som kan ha resultater, kjører ikke.\nSe Aktivitetstyper nedenfor.',
			'activitiesView.mapToggle' => 'Kart',
			'activitiesView.searchToggle' => 'Søk',
			'activitiesView.addToOperation' => 'Legg til i operasjonen',
			'activitiesView.addToOperationShort' => 'Legg til',
			'activitiesView.mapEmptyState' => 'Ingen resultater å vise på kartet',
			'activitiesView.mapEmptyStateHint' => 'Gå tilbake til listen, eller søk etter noe annet',
			'activitiesView.imports' => 'Importer',
			'loggingControls.timeUtc' => 'Tid (UTC)',
			'loggingControls.date' => 'Dato',
			'loggingControls.now' => 'Nå',
			'loggingControls.frequency' => 'Frekvens',
			'loggingControls.mode' => 'Modus',
			'loggingControls.theirCall' => 'Deres kallesignal',
			'loggingControls.noteField' => 'Notat',
			'loggingControls.todoField' => 'Gjøremål',
			'loggingControls.sent' => 'Sendt',
			'loggingControls.rcvd' => 'Mottatt',
			'loggingControls.more' => 'Mer',
			'loggingControls.revert' => 'Tilbakestill',
			'loggingControls.undoDelete' => 'Angre sletting',
			'loggingControls.restore' => 'Gjenopprett',
			'loggingControls.wipe' => 'Tøm',
			'loggingControls.undo' => 'Angre',
			'loggingControls.pendingDeleteTapWarning' => 'Trykk på søppelbøtten én gang til for å slette denne QSOen',
			'loggingControls.pendingDeleteClickWarning' => 'Klikk på søppelbøtten én gang til for å slette denne QSOen',
			'loggingControls.deletedQsoWarning' => 'Slettet QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Trykk på søppelbøtten én gang til for å slette denne ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Klikk på søppelbøtten én gang til for å slette denne ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Slettet ${kind}',
			'loggingControls.timeControl' => 'Tid',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Effekt',
			'loggingControls.notesControl' => 'Notater',
			'loggingControls.power' => 'Effekt',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Loggekontroller',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Selvspotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Selvspot på ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} på ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'For sent å spotte ${call}',
			'loggingControls.spotNoFreq' => 'Angi en frekvens å spotte først',
			'loggingControls.spotComment' => 'Kommentar',
			'loggingControls.bandOrFreqRequired' => 'Angi frekvens eller bånd før du logger',
			'loggingControls.missingBand' => 'Ingen bånd',
			'loggingControls.missingMode' => 'Ingen modus',
			'loggingControls.saveFailed' => ({required Object error}) => 'Kunne ikke lagre: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Kunne ikke slette: ${error}',
			'loggingControls.info.noQsos' => 'Ingen QSOer ennå... la oss gå på lufta!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOer',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} på ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} siden sist',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/t for siste 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/t for siste 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} til',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) til',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) til',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} unna',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) unna',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) unna',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplikat!',
			'loggingControls.info.noticeNewBand' => 'Nytt bånd',
			'loggingControls.info.noticeNewMode' => 'Ny modus',
			'loggingControls.info.noticeNewDXCC' => 'Ny DXCC',
			'loggingControls.info.noticeNewState' => 'Ny stat',
			'loggingControls.info.noticeNewProvince' => 'Ny provins',
			'loggingControls.info.noticeNewDay' => 'Ny dag',
			'loggingControls.info.noticeNewRef' => 'Ny ref.',
			'loggingControls.info.noticeNewMult' => 'Ny mult',
			'loggingControls.info.noticeNewZone' => 'Ny sone',
			'loggingControls.info.noticeInvalidMode' => 'Feil modus',
			'loggingControls.info.noticeInvalidBand' => 'Feil bånd',
			'loggingControls.info.noticeInvalidCategory' => 'Kan ikke kjøres',
			'loggingControls.info.noticeWorkedBefore' => 'Kjørt før',
			'loggingControls.info.noticeNewPark' => 'Ny park',
			'loggingControls.info.noticeNewSection' => 'Ny seksjon',
			'loggingControls.info.noticeBonusStation' => 'Bonusstasjon!',
			'loggingControls.info.noticeMissingExchange' => 'Ingen utveksling',
			'loggingControls.info.noticeInvalidExchange' => 'Ugyldig utveksling',
			'loggingControls.info.noticeUnknownEvent' => 'Ukjent arrangement',
			'loggingControls.info.noticeOurGrid' => 'Angi vår grid',
			'loggingControls.info.noticeRareCounty' => 'Sjeldent fylke!',
			'loggingControls.info.noticeOurLocation' => 'Angi vårt fylke',
			'loggingControls.info.noticeShortGrid' => 'Grid for kort',
			'formChrome.untitled' => '(uten tittel)',
			'formChrome.showMore' => 'Vis mer',
			'formChrome.showAll' => 'Vis alle',
			'formChrome.showFewer' => 'Vis færre',
			'formChrome.defaults' => 'Standard',
			'formChrome.search' => 'Søk',
			'formChrome.clear' => 'Tøm',
			'formChrome.openPage' => 'Åpne side',
			'formChrome.connected' => 'Tilkoblet',
			'formChrome.notConnected' => 'Ikke tilkoblet',
			'formChrome.manage' => 'Administrer',
			'formChrome.connect' => 'Koble til',
			'formChrome.formTitle' => 'Skjema',
			'formChrome.addItem' => ({required Object label}) => 'Legg til ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Rediger ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Viser ${shown} av ${total} (${selected} valgt)',
			'formChrome.validationError' => ({required Object error}) => 'Valideringsfeil: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Transformasjonsfeil: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Feil: ${error}',
			'formChrome.removeItem' => 'Fjern',
			'formChrome.storageUnavailable' => 'Innlogginger utilgjengelige',
			'qsoEditForm.title' => 'Rediger QSO',
			'qsoEditForm.operatorCall' => 'Operatør',
			'qsoEditForm.position' => 'Operatørplass',
			'qsoEditForm.theirName' => 'Navn',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Stat',
			'qsoEditForm.band' => 'Bånd',
			'qsoEditForm.notes' => 'Notater',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Deres info',
			'qsoEditForm.sectionOur' => 'Vår info',
			'qsoEditForm.sectionNotes' => 'Notater',
			'qsoEditForm.theirCity' => 'By',
			'qsoEditForm.theirCounty' => 'Fylke',
			'qsoEditForm.theirEntity' => 'Entitet',
			'qsoEditForm.theirCqZone' => 'CQ-sone',
			'qsoEditForm.theirItuZone' => 'ITU-sone',
			'qsoEditForm.theirArrlSection' => 'ARRL-seksjon',
			'qsoEditForm.theirLat' => 'Breddegrad',
			'qsoEditForm.theirLon' => 'Lengdegrad',
			'qsoEditForm.theirPower' => 'Deres effekt',
			'qsoList.empty' => 'Ingen QSOer ennå — kjør noen!',
			'qsoList.bandOrModeWarning' => 'Kontroller at bånd og modus er riktige',
			'qsoList.today' => 'I dag',
			'qsoList.yesterday' => 'I går',
			'qsoList.tomorrow' => 'I morgen',
			'loggingPanel.stats' => 'Operasjonsstatistikk',
			'loggingPanel.scoring' => 'Poengberegning',
			'loggingPanel.dxccEntities' => 'DXCC-entiteter',
			'loggingPanel.statesWorked' => 'Stater',
			'loggingPanel.provincesWorked' => 'Provinser',
			'loggingPanel.duplicates' => 'Duplikater',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Vis bilde',
			'callInfo.imageUnavailable' => 'Bilde utilgjengelig',
			'callInfo.photo' => 'Bilde',
			'callInfo.notes' => 'Notater',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} til',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) til',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) til',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} unna',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) unna',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) unna',
			'callInfo.thisOpCountOne' => '1 QSO i denne operasjonen',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOer i denne operasjonen',
			'callInfo.otherOpsCountOne' => '1 QSO i andre operasjoner',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOer i andre operasjoner',
			'callInfo.andMore' => ({required Object count}) => '… og ${count} flere',
			'callInfo.withCall' => ({required Object call}) => 'med ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'fra ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} i løpet av de siste 7 dagene',
			'callInfo.history.today' => ({required Object n}) => '${n} i dag',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${n} QSO', other: '${n} QSOer', ), 
			'settings.title' => 'Innstillinger',
			'settings.language' => 'Språk',
			'settings.languageSystem' => ({required Object language}) => 'Følg systeminnstillingene (${language})',
			'settings.theme.title' => 'Tema',
			'settings.theme.system' => 'Følg systeminnstillingene',
			'settings.theme.light' => 'Lyst',
			'settings.theme.dark' => 'Mørkt',
			'settings.themeDescription.system' => 'Følger systeminnstillingene',
			'settings.themeDescription.light' => 'Alltid i lys modus',
			'settings.themeDescription.dark' => 'Alltid i mørk modus',
			'settings.fontScale' => 'Skriftstørrelse',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Minste--',
			'settings.fontScaleOpts.smallestMinus' => 'Minste-',
			'settings.fontScaleOpts.smallest' => 'Minste',
			'settings.fontScaleOpts.smaller' => 'Mindre',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Større',
			'settings.fontScaleOpts.largest' => 'Største',
			'settings.fontScaleOpts.largestPlus' => 'Største+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Største++',
			'settings.keepDeviceAwake.title' => 'Hold enheten våken',
			'settings.keepDeviceAwake.descriptionOn' => 'Holder seg våken mens du er i loggevisningen eller en synkronisering pågår',
			'settings.keepDeviceAwake.descriptionOff' => 'Går i dvale som vanlig',
			'settings.layoutDensity' => 'Tetthet i oppsettet',
			'settings.layoutDensityOpts.auto' => 'Automatisk',
			'settings.layoutDensityOpts.densest' => 'Tettest',
			'settings.layoutDensityOpts.dense' => 'Tett',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Luftig',
			'settings.layoutDensityOpts.sparsest' => 'Luftigst',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'vinduet er for lavt, bruker ${effective}',
			'settings.layoutDensityAtLimit' => 'så langt det går',
			'settings.distanceUnits' => 'Avstandsenheter',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometer',
			'settings.distanceUnitsOpts.miles' => 'Miles',
			'settings.userInterface' => 'Brukergrensesnitt',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Venstrehåndsmodus',
			'settings.logging.leftieMode.descriptionOn' => 'Bruker oppsett for venstrehendte',
			'settings.logging.leftieMode.descriptionOff' => 'Bruker oppsett for høyrehendte',
			'settings.logging.countryFlags.title' => 'Landsflagg',
			'settings.logging.countryFlags.dx' => 'Vis bare for DX-kontakter',
			'settings.logging.countryFlags.all' => 'Vis flagg for alle kontakter',
			'settings.logging.countryFlags.none' => 'Ikke vis flagg',
			'settings.logging.countryFlagsDescription.dx' => 'Viser flagg bare for DX-kontakter',
			'settings.logging.countryFlagsDescription.all' => 'Viser flagg for alle kontakter',
			'settings.logging.countryFlagsDescription.none' => 'Viser ingen flagg',
			'settings.logging.suggestDefaultOperator.title' => 'Foreslå operatør',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Foreslår kallesignalet ditt som operatør når en operasjon bruker et annet stasjonskallesignal',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Lar operatør stå tomt med mindre du fyller det ut',
			'settings.logging.showBearing.title' => 'Vis retning',
			'settings.logging.showBearing.descriptionOn' => 'Viser estimert retning til stasjon',
			'settings.logging.showBearing.descriptionOff' => 'Viser ikke retningsinformasjon',
			'settings.logging.showReverseBearing.title' => 'Vis også motsatt retning',
			'settings.logging.showReverseBearing.descriptionOn' => 'Viser også retningen fra stasjonen, som "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Viser bare retningen til stasjonen',
			'settings.logging.switchSentRcvd.title' => 'Bytt rekkefølge for signalrapport',
			'settings.logging.switchSentRcvd.sentFirst' => 'Sendt først, mottatt andre',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Mottatt først, sendt andre',
			'settings.logging.jumpAfterRST.title' => 'Hopp til neste felt ved RST-oppføring',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Hopper videre når RST er skrevet inn',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Hopper ikke automatisk',
			'settings.logging.defaultReport.title' => 'Standardrapport — telefoni',
			'settings.logging.defaultReport.description' => 'Brukes når Sendt eller Mottatt står tomt på SSB, FM eller AM',
			'settings.logging.defaultReportCW.title' => 'Standardrapport — CW og data',
			'settings.logging.defaultReportCW.description' => 'Brukes når Sendt eller Mottatt står tomt på CW, RTTY og andre datamoduser',
			'settings.logging.defaultReportFT8.title' => 'Standardrapport — FT8 og FT4',
			'settings.logging.defaultReportFT8.description' => 'Brukes når Sendt eller Mottatt står tomt på FT-modusene',
			'settings.logging.numbersRow.title' => 'Tallrad',
			'settings.logging.numbersRow.description' => 'Vis en rad med talltaster over tastaturet under logging',
			'settings.logging.numbersRowExtra.title' => 'Skråstrek- og punktumtast',
			'settings.logging.numbersRowExtra.description' => 'Legger til en kontekstavhengig tast: «/» for kallesignaler, «.» for tall',
			'settings.logging.numbersRowVibrate.title' => 'Vibrer ved tastetrykk',
			'settings.logging.numbersRowVibrate.description' => 'Haptisk tilbakemelding når du trykker på en talltast',
			'settings.logging.bands' => 'Foretrukne bånd',
			'settings.logging.modes' => 'Foretrukne moduser',
			'settings.catServer.title' => 'CAT-server',
			'settings.catServer.description' => 'La andre apper (WSJT-X, loggeprogrammer osv.) styre radioen gjennom Ham2K Logger.',
			'settings.catServer.protocol' => 'Protokoll',
			'settings.catServer.protocolOpts.off' => 'Deaktivert',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Åpen tilgang',
			'settings.catServer.openAccessOn' => 'Alle datamaskiner på det lokale nettverket kan koble til.',
			'settings.catServer.openAccessOff' => 'Bare apper på denne datamaskinen kan koble til.',
			'settings.catServer.off' => 'Av.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, starter…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} på port ${port}. Tilkoblede klienter: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} på port ${port}, men ingen Main VFO-radio er tilkoblet.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} kan ikke lytte på port ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} kan ikke lytte på port ${port}: et annet program bruker den, ofte ${protocol} selv. Lukk det programmet eller velg en annen port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} kan ikke lytte på port ${port}: denne datamaskinen tillater det ikke. Velg en port over 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} sluttet å lytte på port ${port}. Prøver igjen…',
			'settings.radio.title' => 'CAT-styring',
			_ => null,
		} ?? switch (path) {
			'settings.radio.loggingAndCat' => 'Logging og CAT',
			'settings.radio.tuningSection' => 'Avstemming',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Tjenester',
			'settings.radio.stationConfigurationSection' => 'Stasjonsoppsett',
			'settings.radio.moreSettings' => 'Flere innstillinger for stasjonsoppsett',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Styr PTT med [\']',
			'settings.radio.pttKey.descriptionOn' => 'I telefonimoduser nøkler [\'] radioen, og [\'] igjen slipper den. Den slipper av seg selv etter ett minutt.',
			'settings.radio.pttKey.descriptionOff' => '[\']-tasten nøkler ikke radioen.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Sender',
			'settings.radio.smartVfoSnap.title' => 'Smart VFO-avrunding',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Når du slutter å vri på hjulet, rundes frekvensen av til et fornuftig steg. Bare talemoduser.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Blir stående nøyaktig der du stilte inn.',
			'settings.radio.snapDebounce.title' => 'Smart avrunding: Ventetid',
			'settings.radio.snapDebounce.description' => 'Hvor lenge hjulet må stå stille før frekvensen rundes av. Kortere føles umiddelbart; lengre gir rom for en langsom bevegelse.',
			'settings.radio.snapLongMove.title' => 'Smart avrunding: Lang bevegelse',
			'settings.radio.snapLongMove.description' => 'Flytt minst så langt, så rundes frekvensen av til en hel kHz, uansett hvor sakte du avsluttet.',
			'settings.radio.snapMinMove.title' => 'Smart avrunding: Minste bevegelse',
			'settings.radio.snapMinMove.description' => 'Flytt mindre enn dette, så rundes ikke frekvensen av, og finjustering får være i fred.',
			'settings.radio.snapMinSpeed.title' => 'Smart avrunding: Saktest bevegelse',
			'settings.radio.snapMinSpeed.description' => 'Vri hjulet saktere enn dette, så rundes ikke frekvensen av, med mindre det var en lang bevegelse.',
			'settings.radio.enterSends.pillOff' => 'ESM av',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter sender meldinger',
			'settings.radio.enterSends.off' => 'Av',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter sender meldinger: ${state}. Trykk for å endre.',
			'settings.radio.keyerSpeed.title' => 'Keyer-hastighet',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW-keyermeldinger',
			'settings.radio.cwMessages.notSupported' => 'Gjeldende radio støtter ikke CW-nøkling',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Melding (${n})',
			'settings.radio.cwMessages.labelField' => 'Etikett',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Etikett for F${n}',
			'settings.radio.cwMessages.details' => 'Detaljer',
			'settings.radio.cwMessages.empty' => '(tom)',
			'settings.radio.cwMessages.sets' => 'Meldingssett',
			'settings.radio.cwMessages.newSet' => 'Nytt sett',
			'settings.radio.cwMessages.renameSet' => 'Gi nytt navn til sett',
			'settings.radio.cwMessages.deleteSet' => 'Slett sett',
			'settings.radio.cwMessages.newSetName' => 'Navn',
			'settings.radio.cwMessages.setDefault' => 'Standard',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM-meldinger',
			'settings.radio.cwMessages.setSaved' => 'Mine meldinger',
			'settings.radio.cwMessages.repeat' => 'Gjenta melding #1',
			'settings.radio.cwMessages.repeatOff' => 'Nei',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Etter ${n} sekunder',
			'settings.radio.cwMessages.repeatWait' => 'Gjentar',
			'settings.radio.cwMessages.keyboard' => 'Skriv for å sende',
			'settings.radio.cwMessages.keyboardField' => 'Skriv for å sende',
			'settings.radio.cwMessages.closeArea' => 'Lukk keyer-området',
			'settings.radio.cwMessages.help' => 'Hjelp',
			'settings.radio.cwMessages.helpTitle' => 'Skrive CW-meldinger',
			'settings.radio.cwMessages.helpIntro' => 'Meldinger kan bruke maler med følgende verdier:',
			'settings.radio.cwMessages.helpOpCall' => 'Kallesignalet ditt',
			'settings.radio.cwMessages.helpQsoCall' => 'Deres kallesignal — i en //-stabel, kallesignalet som blir logget',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Deres kallesignal, hvis det er et gyldig kallesignal; tomt for et delvis',
			'settings.radio.cwMessages.helpQsoPartial' => 'Et delvis kallesignal; tomt hvis det finnes et fullstendig gyldig kallesignal',
			'settings.radio.cwMessages.helpQsoNextCall' => 'I en //-stabel, kallesignalet som blir valgt for logging neste gang, hvis det er et gyldig fullstendig kallesignal',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'I en //-stabel, neste delvise kallesignal etter at gjeldende kontakt er logget',
			'settings.radio.cwMessages.helpQsoName' => 'Fornavnet deres, slik det er skrevet, ellers fra oppslaget',
			'settings.radio.cwMessages.helpQsoState' => 'Staten deres, slik den er skrevet, ellers fra oppslaget',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Melding 1 slik den ville blitt sendt, inne i en annen melding. Gyldig for melding 1 til 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Rapporten du sender',
			'settings.radio.cwMessages.helpQsoSerial' => 'Serienummeret ditt, i en konkurranse som sender et',
			'settings.radio.cwMessages.helpPad' => 'Fyller ut med nuller til så mange sifre: 7 sendes som 007',
			'settings.radio.cwMessages.helpCut' => 'Forkortede tall, T for 0 og N for 9: 599 sendes som 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Velger sifrene som forkortes, i anførselstegn — 0 er T, 1 er A, 5 er E, 9 er N',
			'settings.radio.cwMessages.helpFullExample' => 'Fullstendig eksempel:',
			'settings.radio.cwMessages.helpExample' => 'Sender W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Med Enter sender meldinger på, sender Enter meldinger etter funksjonstasten deres, slik N1MM gjør. Meldingssettet ESM-meldinger starter med disse:',
			'settings.radio.cwMessages.helpEsmCq' => 'Ved Run roper Enter CQ når kallesignalfeltet er tomt',
			'settings.radio.cwMessages.helpEsmExchange' => 'Utvekslingen din: etter kallesignalet deres ved Run, etter at de svarer ved S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Takk, når kontakten er logget: plassholderne gjelder neste kontakt, ikke denne',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Ved S&P, kallesignalet ditt til stasjonen du svarer',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Ved Run, kallesignalet deres foran utvekslingen din',
			'settings.radio.cwMessages.helpEsmAgain' => 'Spør igjen når ingenting av utvekslingen deres ble mottatt',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Foreslått F3 for //-stabler: TU sendes etter at kontakten er logget, så den takker, roper så neste stasjon i stabelen og sender utvekslingen din, eller spør tilbake etter et delvis kallesignal (TU KR?); når ingenting er igjen, bare TU',
			'settings.radio.voiceMessages.title' => 'Talemeldinger',
			'settings.radio.voiceMessages.notSupported' => 'Gjeldende radio støtter ikke talemeldinger',
			'settings.radio.voiceMessages.description' => 'Dette bruker talememoriene i radioen',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Talememori (${n})',
			'settings.radio.voiceMessages.labelField' => 'Etikett',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Etikett for talememori ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Tom',
			'settings.radio.voiceMessages.notMeasured' => 'Ukjent lengde',
			'settings.radio.voiceMessages.playButton' => 'Spill av',
			'settings.radio.voiceMessages.recordButton' => 'Ta opp',
			'settings.radio.voiceMessages.stopButton' => 'Stopp',
			'settings.radio.voiceMessages.repeat' => 'Gjenta melding #1',
			'settings.radio.voiceMessages.repeatOff' => 'Nei',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Etter ${n} sekunder',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Merknader for ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Disse memoriene ligger i radioen til ${device}. Navnene og lengdene hører til den enheten.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Lagret i radioen, der de andre klientene også ser det.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Vent på [REC]-indikatoren på radioen, hold så inne PTT-knappen og ta opp meldingen. Avslutt ved å trykke på STOPP-knappen her i appen før du slipper PTT, for å unngå uønskede klikk.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Vent til [REC]-indikatoren har blinket minst fire ganger, hold så inne PTT-knappen og ta opp meldingen. Avslutt ved å trykke på STOPP-knappen her i appen før du slipper PTT, for å unngå uønskede klikk.',
			'settings.radio.voiceMessages.pill' => 'Tale',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Spill av memori ${n}',
			'settings.radio.voiceMessages.stop' => 'Stopp',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Ta opp memori ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Stopp opptak',
			'settings.radio.voiceMessages.playing' => 'Spiller av…',
			'settings.radio.voiceMessages.recording' => 'Tar opp…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Spiller av ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Tar opp ${label}',
			'settings.radio.voiceMessages.doubtful' => 'Spilte radioen den av? Den meldte at den var ledig med en gang.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Du må ta opp memoriene på selve radioen.',
			'settings.radio.avoidZeroBeat.title' => 'Unngå nullsvevning på spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Med en radio tilkoblet stilles det inn noen Hz ved siden av en CW-spot, så ikke alle som svarer, roper på samme tone.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Stiller inn nøyaktig på den spottede frekvensen.',
			'settings.radio.zeroBeatRange.title' => 'Nullsvevning: Avviksområde',
			'settings.radio.zeroBeatRange.description' => 'Hvor langt fra den spottede frekvensen du havner, på begge sider. Avviket er aldri nær null — da ville det vært nullsvevning igjen.',
			'settings.help.title' => 'Hjelp og ressurser',
			'settings.help.description' => 'Fellesskap og brukerstøtte',
			'settings.help.forums' => 'Ham2K-forum',
			'settings.help.forumsDescription' => 'Finn hjelp, gi tilbakemelding, diskuter ideer…',
			'settings.help.chat' => 'Ham2K-chat',
			'settings.help.chatDescription' => 'Discord-serveren for nettfellesskapet vårt',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videoer og direktesendinger',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Fordi du ikke kan ha for mange bilder…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Følg oss for nyheter og oppdateringer',
			'settings.help.contact' => 'Kontakt oss',
			'settings.help.contactDescription' => 'help@ham2k.com — men prøv forumet eller chatten først!',
			'settings.exports.title' => 'Eksport',
			'settings.map.title' => 'Kart',
			'settings.map.style.title' => 'Kartstil',
			'settings.map.styleOpts.automatic' => 'Automatisk',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Personvern',
			'settings.privacy.shareAppData.title' => 'Del data om appbruk',
			'settings.privacy.shareAppData.descriptionOn' => 'Hjelper oss å forbedre appen ved å dele bruks-, oppsett-, krasj- og ytelsesdata',
			'settings.privacy.shareAppData.descriptionOff' => 'Holder appbruksdata private.\nHam2K-teamet vil ikke kunne oppdage krasj eller andre problemer.',
			'settings.privacy.shareOpData.title' => 'Del operasjonsdata',
			'settings.privacy.shareOpData.descriptionOn' => 'Deler noen operasjonsdata offentlig og med andre brukere',
			'settings.privacy.shareOpData.descriptionOff' => 'Holder operasjonsdata private',
			'settings.privacy.privacyPolicy' => 'Personvernpolicy',
			'settings.privacy.termsOfService' => 'Tjenestevilkår',
			'settings.operatorCall' => 'Operatørkallesignal',
			'settings.sync.title' => 'Skysynkronisering',
			'settings.sync.moreSettings' => 'Flere synkroniseringsinnstillinger',
			'settings.sync.enable' => 'Aktiver synkronisering',
			'settings.sync.deviceKey' => 'Enhetsnøkkel',
			'settings.peers.title' => 'Andre enheter',
			'settings.peers.enable' => 'Koble til andre enheter',
			'settings.peers.enableDescription' => 'Tillat deling av operasjoner, logging, CAT og GPS med andre enheter over det lokale nettverket',
			'settings.peers.bleEnable' => 'Koble til over Bluetooth',
			'settings.peers.bleDescription' => 'Bruk Bluetooth LE for å koble til selv om det ikke finnes noe lokalt nettverk',
			'settings.peers.thisDevice' => 'Denne enheten',
			'settings.peers.deviceName' => 'Navn',
			'settings.peers.deviceNameHint' => 'Hvordan denne enheten vises for andre enheter',
			'settings.peers.pairedDevices' => 'Koblede enheter',
			'settings.peers.noPairedDevices' => 'Ingen enheter koblet ennå. Slå på dette på en annen enhet på dette nettverket for å koble dem sammen.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Kan ikke lese de koblede enhetene dine: ${error}',
			'settings.peers.nearby' => 'I nærheten',
			'settings.peers.connected' => 'Tilkoblet',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Kobler til…',
			'settings.peers.syncing' => 'Synkroniserer…',
			'settings.peers.waitingForThem' => 'Venter på den andre enheten',
			'settings.peers.notConnected' => 'Ikke tilkoblet',
			'settings.peers.wantsToPair' => 'vil dele denne operasjonen',
			'settings.peers.allow' => 'Tillat',
			'settings.peers.link' => 'Koble',
			'settings.peers.reject' => 'Avvis',
			'settings.peers.forget' => 'Glem',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Glemme ${name}?',
			'settings.peers.forgetBody' => 'Den slutter å synkronisere med denne enheten. Du kan tillate den igjen senere, og kontakter som allerede er logget, beholdes.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Koble til ${name}',
			'settings.peers.pairBody' => 'Denne enheten er på det lokale nettverket ditt og vil koble til.',
			'settings.peers.pairBodyBle' => 'Denne enheten er i nærheten og vil koble til over Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'Enhets-ID',
			'settings.peers.pairWarning' => 'Koble bare til enheter du kjenner igjen. Alle enheter på dette nettverket kan sende en forespørsel.',
			'settings.peers.pairWarningBle' => 'Koble bare til enheter du kjenner igjen. Alle enheter i nærheten kan sende en forespørsel.',
			'settings.peers.problem' => ({required Object error}) => 'Kan ikke nå det lokale nettverket: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Koblet til ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Mistet forbindelsen til ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Andre enheter: ${connected} av ${linked} tilkoblet',
			'settings.peers.screenEnable' => 'Del skjermer og vinduer',
			'settings.peers.screenDescription' => 'Tillat andre enheter å vise skjermer eller vinduer fra denne datamaskinen',
			'settings.peers.screenSources' => 'Skjermer og vinduer',
			'settings.peers.screenRefresh' => 'Oppdater listen',
			'settings.peers.screenUnsupportedPlatform' => 'Denne enheten kan ikke dele skjermen sin. macOS kan det; alle enheter kan vise en skjerm som deles av en annen.',
			'settings.peers.screenUnsupportedVersion' => 'Skjermdeling krever macOS 12.3 eller nyere. Denne enheten kan likevel vise en skjerm som deles av en annen.',
			'settings.peers.screenNeedsPermission' => 'macOS trenger tillatelsen din til å ta opp skjermen før denne appen kan dele en.',
			'settings.peers.screenGrantPermission' => 'Be om tillatelse',
			'settings.peers.screenRelaunchAfterGranting' => 'Tillat det i Systeminnstillinger under Personvern og sikkerhet → Skjermopptak, og avslutt og åpne denne appen på nytt — macOS forteller bare en app om endringen neste gang den starter.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Skjermdeling: ${error}',
			'settings.peers.screenChooseTitle' => 'Velg hva som skal deles',
			'settings.peers.screenChooseButton' => 'Velg hva som skal deles…',
			'settings.peers.screenTabScreens' => 'Skjermer',
			'settings.peers.screenTabApps' => 'Apper',
			'settings.peers.screenTabWindows' => 'Vinduer',
			'settings.peers.screenTabEmpty' => 'Fant ingenting av denne typen.',
			'settings.peers.screenSharedSummaryNone' => 'Ingenting valgt ennå.',
			'settings.peers.screenThisDevice' => 'Denne enheten',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Vises på ${devices}',
			'settings.peers.screenSharedToNobody' => 'Vises ikke',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Slutt å dele ${name}',
			'settings.developerMode' => 'Utviklermodus',
			'settings.syncPanel.configuration' => 'Synkroniseringsoppsett',
			'settings.syncPanel.enableTitle' => 'Synkroniser med Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Tar sikkerhetskopi av og synkroniserer loggen din mellom enheter',
			'settings.syncPanel.disabledDescription' => 'Av — blir bare på denne enheten',
			'settings.syncPanel.syncing' => 'Synkroniserer',
			'settings.syncPanel.account' => 'Konto',
			'settings.syncPanel.refresh' => 'Oppdater',
			'settings.syncPanel.switchAccounts' => 'Bytt konto',
			'settings.syncPanel.switchAccountsDescription' => 'Koble denne enheten til en annen konto med en QR-kode eller e-post',
			'settings.syncPanel.connectionRequests' => 'Tilkoblingsforespørsler',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'En enhet venter på å bli med i denne kontoen', other: '${n} enheter venter på å bli med i denne kontoen', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-post for kontoen',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Bekreftelse sendt til ${email}. Åpne lenken der for å fullføre endringen.',
			'settings.syncPanel.resendConfirmation' => 'Send bekreftelses-e-post på nytt',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Venter på ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Sendt på nytt til ${email}.',
			'settings.syncPanel.deviceLinked' => 'Den enheten er nå koblet til denne kontoen.',
			'settings.syncPanel.checking' => 'Sjekker…',
			'settings.syncPanel.notLinked' => 'Ikke koblet ennå',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Erstatte lokale data?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${n} operasjon', other: '${n} operasjoner', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${n} QSO', other: '${n} QSOer', ), 
			'settings.syncPanel.counts' => 'Synkroniserte data',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Denne enheten: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Venter på opplasting: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Denne enheten: sjekker…',
			'settings.syncPanel.countsServerChecking' => 'Server: sjekker…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: ikke tilgjengelig',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Dette tar sikkerhetskopi av og fjerner ${operations} og ${qsos} fra denne enheten, og laster ned kontoens data i stedet. Sikkerhetskopien blir liggende i databasen på denne enheten.',
			'settings.syncPanel.replace' => 'Erstatt',
			'settings.syncPanel.pendingBannerTitle' => 'Ny Ham2K Log Filer-konto oppdaget',
			'settings.syncPanel.pendingBannerBody' => 'Behold de eksisterende operasjonene og QSOene på denne enheten og slå dem sammen med kontoen, eller erstatt dem med kontoens data (en sikkerhetskopi blir liggende på denne enheten uansett).',
			'settings.syncPanel.combine' => 'Kombiner',
			'settings.syncPanel.authIssueTitle' => 'Synkroniseringen får ikke koblet til',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer avviser stadig denne enheten. Sjekk kallesignalet ditt i synkroniseringsinnstillingene.',
			'settings.syncPanel.openSettings' => 'Åpne synkroniseringsinnstillinger',
			'settings.accounts.title' => 'Kontoer, tjenester og datakilder',
			'settings.accounts.none' => 'Ingen aktive utvidelser med kontoer',
			'settings.accounts.notConfigured' => 'Ikke satt opp',
			'settings.accounts.connected' => 'Tilkoblet',
			'settings.accounts.cancelLogin' => 'Avbryt innlogging',
			'settings.accounts.openInBrowser' => 'Åpne i nettleser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Logget inn som ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Trykk Lagre for å beholde denne kontoen tilkoblet.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Koblet til ${label}',
			'settings.accounts.connect' => 'Koble til',
			'settings.accounts.disconnect' => 'Koble fra',
			'settings.accounts.connectedAs' => 'Tilkoblet som',
			'settings.accounts.test' => 'Test',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Lagring mislyktes: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Innlogging mislyktes: ${error}',
			'settings.accounts.lookupFailed' => 'Kontoer er utilgjengelige akkurat nå — prøv igjen om et øyeblikk',
			'settings.accounts.browserLoginTitle' => 'Fullfør innloggingen i nettleseren',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Når du er ferdig, prøver nettleseren å åpne en lenke som begynner med "${prefix}". Datamaskinen din har mest sannsynlig ikke noe registrert for å åpne den, så kopier lenken (fra adressefeltet, eller fra feilsiden nettleseren viser) og lim den inn her.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger kunne ikke åpne nettleseren din. Kopier innloggingslenken nedenfor og åpne den selv, kopier deretter lenken den sender deg til (den begynner med "${prefix}") og lim den inn her.',
			'settings.accounts.copyLoginLink' => 'Kopier innloggingslenke',
			'settings.accounts.pastedLinkLabel' => 'Lim inn lenken her',
			'settings.accounts.finishLogin' => 'Fullfør innlogging',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Det er ikke innloggingslenken — den skal begynne med "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Den lenken hører til et annet innloggingsforsøk. Lukk denne siden og koble til på nytt.',
			'settings.accounts.pastedLinkNoCode' => 'Den lenken har ingen innloggingskode. Fullfør innloggingen først, og kopier så lenken den sender deg til.',
			'settings.accounts.pastedLinkMalformed' => 'Den lenken ser ut til å være avkortet. Kopier hele lenken og lim den inn på nytt.',
			'settings.accounts.relayLoginWaiting' => 'Venter på at du fullfører innloggingen — dette fortsetter automatisk når du gjør det.',
			'settings.accounts.loginNoResponse' => 'Denne enheten har ikke fått svar fra innloggingen ennå. Hvis du allerede er ferdig i nettleseren, avbryt og prøv å koble til på nytt.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger kunne ikke åpne nettleseren automatisk. Bruk knappen nedenfor for å åpne innloggingssiden selv.',
			'settings.accounts.relayLoginUnavailable' => 'Kunne ikke nå synkroniseringsserveren som trengs for å fullføre denne innloggingen. Sjekk tilkoblingen og prøv igjen.',
			'settings.accounts.loginIncompleteResponse' => 'Det innloggingsforsøket ble ikke fullført riktig. Prøv å koble til på nytt.',
			'settings.accounts.noKeyringTitle' => 'Kontoinnlogginger kan ikke lagres',
			'settings.accounts.noKeyringText' => 'Ham2K Logger får ikke kontakt med en nøkkelringtjeneste på denne datamaskinen, så kontoinnlogginger kan ikke lagres eller leses — tilkobling av kontoer vil mislykkes til dette er ordnet. Installer og start **gnome-keyring**, **KWallet** eller **KeePassXC**, eller lås opp nøkkelringen du allerede har, og start på nytt. Logging, eksport og datafiler påvirkes ikke; loggsynkronisering er av så lenge dette varer.',
			'settings.accounts.noKeyringInline' => 'Innlogginger kan ikke lagres: nøkkelringen på denne datamaskinen kan ikke nås. Installer og start gnome-keyring, KWallet eller KeePassXC, eller lås opp den du har.',
			'settings.accounts.noSecureStorageInline' => 'Innlogginger kan ikke lagres: den sikre lagringen på denne datamaskinen kan ikke nås.',
			'settings.station.title' => 'Stasjonsoppsett og CAT-styring',
			'settings.station.none' => 'Ikke noe utstyr satt opp',
			'settings.station.add' => 'Legg til',
			'settings.station.addTitle' => 'Legg til utstyr',
			'settings.station.searchHint' => 'Søk etter utstyr',
			'settings.station.noMatches' => 'Ikke noe utstyr samsvarer',
			'settings.station.detectedEquipment' => 'Oppdaget utstyr',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Kan ikke lytte etter radioer: ${error}',
			'settings.station.edit' => 'Rediger utstyr',
			'settings.station.name' => 'Navn',
			'settings.station.nameDescription' => 'Hva du kaller det — «Venstre radio». Valgfritt.',
			'settings.station.transport' => 'Tilkobling',
			'settings.station.host' => 'Adresse',
			'settings.station.hostDescription' => 'Vertsnavnet eller IP-adressen til radioen på nettverket ditt.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'En adresse er påkrevd',
			'settings.station.portInvalid' => 'Porten må være mellom 1 og 65535',
			'settings.station.connect' => 'Koble til',
			'settings.station.disconnect' => 'Koble fra',
			'settings.station.remove' => 'Fjern',
			'settings.station.removeTitle' => ({required Object name}) => 'Fjerne ${name}?',
			'settings.station.removeMessage' => 'Dette fjerner det bare fra appen. Innstillingene i utstyret forblir som de er.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Ukjent utstyrstype "${typeKey}"',
			'settings.station.report' => 'Rapporter',
			'settings.station.reportTitle' => 'Rapporter denne radioen',
			'settings.station.reportIntro' => 'Fortell oss hvilken radio dette egentlig er, og hvordan det gikk. Rapporten din blir et kort som Ham2K-teamet leser, og det du skriver om hvordan du fikk den til å virke, kan komme til å hjelpe neste operatør med samme rigg.',
			'settings.station.reportManufacturer' => 'Produsent',
			'settings.station.reportManufacturerDescription' => 'Hvem som lager den — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'En produsent er påkrevd',
			'settings.station.reportModel' => 'Modell',
			'settings.station.reportModelDescription' => 'Modellen, slik radioen selv kaller den — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'En modell er påkrevd',
			'settings.station.reportOutcome' => 'Hvordan gikk det?',
			'settings.station.reportOutcomeWorks' => 'Virket bra',
			'settings.station.reportOutcomeIssues' => 'Virket, med problemer',
			'settings.station.reportOutcomeFails' => 'Virket ikke i det hele tatt',
			'settings.station.reportOutcomeRequired' => 'Fortell oss hvordan det gikk',
			'settings.station.reportComments' => 'Kommentarer',
			'settings.station.reportCommentsPlaceholder' => 'Hva som virket, hva som ikke gjorde det, alt som overrasket deg.',
			'settings.station.reportHints' => 'Feilsøkingstips',
			'settings.station.reportHintsPlaceholder' => 'Vil du foreslå noen feilsøkingstips for andre brukere?',
			'settings.station.reportSend' => 'Send rapport',
			'settings.station.reportSending' => 'Sender rapporten din…',
			'settings.station.reportSent' => ({required Object ref}) => 'Takk — rapporten din ble registrert som ${ref}.',
			'settings.station.reportSentNoRef' => 'Takk — rapporten din ble sendt.',
			'settings.station.reportFailed' => ({required Object error}) => 'Rapporten ble ikke sendt: ${error}',
			'settings.station.troubleshootingNotes' => 'Feilsøkingsnotater',
			'settings.station.mainVfo' => 'Hoved-VFO',
			'settings.station.useAsMainVfo' => 'Bruk som hoved-VFO',
			'settings.station.serialPort' => 'Seriellport',
			'settings.station.serialPortDescription' => 'Porten der radioens CAT-grensesnitt vises.',
			'settings.station.serialPortNone' => 'Fant ingen seriellporter',
			'settings.station.serialPortRequired' => 'Velg en seriellport',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} av ${total}',
			'settings.station.serialPortSuggested' => 'foreslått',
			'settings.station.serialPortJustNow' => 'Nylig tilkoblet',
			'settings.station.serialDeviceRequest' => 'Legg til en USB-enhet…',
			'settings.station.baudRate' => 'Hastighet (baud)',
			'settings.station.baudRateDescription' => 'Må samsvare med radioens CAT-meny. Ved avvik sender radioen tilbake søppel og ingen feilmelding.',
			'settings.station.serialRtsHigh' => 'Hold RTS høy',
			'settings.station.serialRtsHighDescription' => 'Bare for en radio som venter på RTS før den svarer, som en Yaesu med CAT RTS slått på. På Digirig, SignaLink og de fleste hjemmelagde kabler er RTS PTT, og å holde den høy gir sending.',
			'settings.station.serialDtrHigh' => 'Hold DTR høy',
			'settings.station.serialDtrHighDescription' => 'Bare for et CAT-grensesnitt som henter strøm fra DTR, som enkelte RS-232-kabler for FT-817. På mange kabler nøkler DTR CW eller PTT, og å holde den høy gir sending.',
			'settings.station.civAddress' => 'Radioens CI-V-adresse',
			'settings.station.civAddressDescription' => 'Heksadesimal, slik den vises i radioens CI-V-meny. IC-705 leveres med A4.',
			'settings.station.civAddressInvalid' => 'En CI-V-adresse er to heksadesimale sifre, 01 til FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Hvilken av radioens slicer denne tilkoblingen leser fra og stiller inn.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Velg en av radioens slicer, A til H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} er ikke i bruk på denne radioen — velg en annen slice, eller opprett den i SmartSDR',
			'settings.station.channelNotInUse' => 'ikke i bruk',
			'settings.station.channelHeldByUnknown' => 'i bruk av et annet program',
			'settings.station.flexNoSlices' => 'Denne radioen har ikke rapportert noen slicer — sjekk at SmartSDR kjører og at denne klienten får abonnere',
			'settings.station.spectrumUnsupported' => 'Denne radioen sender ikke spektrum over CAT',
			'settings.station.spectrumRequiresBaud' => 'Krever CAT på 115200 bps',
			'settings.station.spectrumNoRadio' => 'Ingen radio tilkoblet',
			'settings.station.spectrumWaiting' => 'Venter på spekteret fra radioen…',
			'settings.station.spectrumUnavailable' => 'Spektrumvisning er ikke tilgjengelig',
			'settings.station.spectrumNoDaxChannel' => 'Alle DAX IQ-kanaler på denne radioen er i bruk',
			'settings.station.spectrumNoPanadapter' => 'Denne slicen har ingen panadapter på radioen',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Radioen avviste en DAX IQ-strøm (feil ${code})',
			'settings.station.spectrumNoUdp' => 'Spektrumdataene fra radioen når ikke fram til denne enheten',
			'settings.station.spectrumScopeRefused' => 'Radioen avviste scope-kommandoene',
			'settings.station.spectrumOutOfRange' => 'Radioens scope er satt utenfor området den kan vise',
			'settings.station.n3fjpNoRig' => 'N3FJP har ikke satt opp noe radiogrensesnitt, så dette følger det som skrives inn i N3FJP, ikke en radio',
			'settings.station.winkeyerKeyPort' => 'Nøkleutgang',
			'settings.station.winkeyerKeyPortDescription' => 'Hvilken av keyerens to utganger radioen din er koblet til.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Bruk keyerens PTT',
			'settings.station.winkeyerPttDescription' => 'Nøkle PTT-linjen på samme kontakt, for et forsterkertrinn eller en radio som trenger det. La være av for en radio som nøkles på nøkkelkontakten.',
			'settings.station.winkeyerNoAnswer' => 'Ingen WinKeyer svarte på denne porten',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer sluttet å svare under sending; meldingen ble forkastet',
			'settings.station.radioUser' => 'Brukernavn på radioen',
			'settings.station.radioPass' => 'Passord på radioen',
			'settings.station.radioLoginDescription' => 'Radioens Network → Remote-innlogging, ikke WiFi-passordet ditt.',
			'settings.station.radioUserRequired' => 'Brukernavnet for fjernstyring av radioen er påkrevd',
			'settings.station.connectFailedBusy' => 'Enheten er i bruk',
			'settings.station.connectFailedDenied' => 'Ingen tilgang',
			'settings.station.connectFailedDevice' => 'Fant ikke enheten',
			'settings.station.connectFailedLines' => 'RTS/DTR kunne ikke holdes som angitt, så porten ble lukket. Et annet program kan ha latt maskinvare-handshake stå på — koble kabelen fra og til igjen.',
			'settings.station.connectFailedNetwork' => 'Finner ikke radioen på nettverket. Sjekk adressen, og at den er slått på og kan nås.',
			'settings.station.connectFailedTimeout' => 'Radioen svarte ikke i tide. Sjekk at den er slått på og kan nås.',
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
			'settings.station.models.q900' => 'Guohetec Q900',
			'settings.station.models.yaesuGeneric' => 'Yaesu - Generell',
			'settings.station.models.icomGeneric' => 'Icom - Generell',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Generell',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Generell',
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
			'settings.station.models.x6100' => 'Xiegu X6100',
			'settings.station.models.g90' => 'Xiegu G90',
			'settings.station.models.rigctld' => 'Radio styrt via rigctld',
			'settings.station.models.rigctldNodeName' => 'Min radio (via rigctld)',
			'settings.station.models.flrig' => 'Radio styrt via flrig',
			'settings.station.models.flrigNodeName' => 'Min radio (via flrig)',
			'settings.station.models.hrd' => 'Radio styrt via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Min radio (via HRD)',
			'settings.station.models.n3fjp' => 'Radio styrt via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Min radio (via N3FJP)',
			'settings.station.models.commander' => 'Radio styrt via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Min radio (via Commander)',
			'settings.station.models.antenna' => 'Antenne',
			'settings.station.models.key' => 'CW-nøkkel',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Generell radio (plassholder)',
			'settings.station.models.placeholderRadioNodeName' => 'Min radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 koaksbryter',
			'settings.station.transports.network' => 'Nettverk/WiFi',
			'settings.station.transports.usbSerial' => 'USB-seriell',
			'settings.station.transports.wifi' => 'Nettverk/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth-seriell',
			'settings.station.transports.placeholder' => 'Plassholder',
			'settings.station.troubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.ft891Troubleshooting' => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT RTS må være AV på radioen** (FT-891-meny **05-08**). Når den er på, venter radioen på en handshake-linje som appen holder lav. På Digirig, SignaLink og de fleste hjemmelagde kabler er den samme linjen PTT, så å heve den ville nøkle senderen. På radioens egen USB-port er **Hold RTS høy** under Avanserte innstillinger alternativet.\n- **Hastigheten må samsvare** med radioens CAT RATE (meny **05-06**). Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.yaesuBinaryTroubleshooting' => 'Denne radioen bruker Yaesus eldre CAT med fem byte, og den svarer ikke i det hele tatt når noe er feil. Nesten alltid en av disse:\n\n- **Kabelen må konvertere nivåer.** CAT-kontakten bak er verken RS-232 eller USB; den trenger en CT-62 eller en tilsvarende adapter. En vanlig lyd- eller datakabel virker ikke for CAT.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny (**#14** på FT-817, **#19** på FT-857 eller FT-897). Ved avvik sender radioen ingenting tilbake, og aldri en feilmelding.\n- **La aldri noe heve RTS eller DTR på denne porten.** På de fleste kabler for disse radioene er de linjene PTT og nøkling. Et eldre grensesnitt som får strøm fra DTR, er unntaket: slå på **Hold DTR høy** under Avanserte innstillinger for det.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\nDenne driveren er skrevet etter Yaesus publiserte CAT-tabell og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.guohetecTroubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.guohetecTroubleshooting' => 'Q900 har to CAT-protokoller, og denne oppføringen bruker den opprinnelige i stedet for FT-817-etterligningen. Velg **Guohetec Q900** her, ikke en FT-817 — etterligningen støtter færre kommandoer, og radioen sier ikke hvilken den bruker.\n\n- **USB-C-kabelen er CAT-forbindelsen**, og den kobler til lydkortet også. Hastigheten spiller ingen rolle på den; porten ignorerer hva den er satt til.\n- **La aldri noe heve RTS eller DTR på denne porten.** På en seriellkabel er de linjene PTT og nøkling.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **En radio av andre generasjon oppfører seg annerledes** enn en av første. Trykk lenge på Menu, deretter About: HW 2.0 er andre generasjon.\n\nDenne driveren er skrevet etter produsentens publiserte protokoll og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.yaesuTroubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.yaesuTroubleshooting' => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav. På Digirig, SignaLink og de fleste hjemmelagde kabler er den samme linjen PTT, så å heve den ville nøkle senderen. På radioens egen USB-port er **Hold RTS høy** under Avanserte innstillinger alternativet. Hvor den innstillingen ligger, varierer mellom modeller (meny **05-08** på FT-891).\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **Modusene følger tabellen for FT-891.** Det meste av Yaesu-serien samsvarer med den, men en radio som nummererer modusene sine annerledes, vil vise og sette feil modus for disse. Frekvensen påvirkes ikke.',
			'settings.station.yaesuRs232Troubleshooting' => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **CAT-kontakten er RS-232.** Den trenger en USB-til-seriell-adapter og en rett DB-9-kabel — en nullmodemkabel bytter om linjene, og radioen hører aldri noe.\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav, med mindre **Hold RTS høy** er slått på under Avanserte innstillinger.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\nDenne oppføringen er skrevet etter publisert CAT-dokumentasjon og har ikke blitt kjørt mot en av disse radioene. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.yaesuUsbTroubleshooting' => 'Radioen mottar kommandoer, men svarer ikke. Nesten alltid en av disse:\n\n- **Bruk den første av radioens to USB-porter.** CAT ligger normalt på den første (**Enhanced** COM-porten på Windows); den andre (**Standard**) er for PTT og nøkling. Velgeren peker på den første der den kan skille de to fra hverandre.\n- **CAT RTS må være AV på radioen.** Når den er på, venter radioen på en handshake-linje som appen holder lav, med mindre **Hold RTS høy** er slått på under Avanserte innstillinger.\n- **Hastigheten må samsvare** med radioens CAT RATE-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.',
			'settings.station.k4SerialNotes' => 'Koble til K4-ens USB-B-kontakt (PC) bak. Både USB-PC1 og USB-PC2 virker for CAT; velg en ledig port og sett Serial USB-PCn: Baud Rate på radioen til samme verdi. HaLo fyller inn 38400; endre ved behov. Et annet program må bruke den andre porten eller Ethernet.\n\nDenne tilkoblingen styrer radioen og keyerne dens; den sender ikke lyd til HaLo.',
			'settings.station.k4TcpNotes' => 'Koble K4-ens Ethernet-kontakt til det lokale nettverket. Oppgi vertsnavnet eller IP-adressen og CAT-port 9200. Dette er CAT-styring, ikke den separate tilkoblingen for fjernlyd på port 9204.\n\nHaLo styrer radioen og keyerne dens uten å strømme lyd eller panadapterdata.',
			'settings.station.k4PowerTimeout' => 'K4-effekten ble ikke endret fordi radioen ikke bekreftet utgangsområdet sitt. Prøv igjen.',
			'settings.station.k4PowerRange' => 'K4-effekten må være 0,1–110 W, eller 0,0001–0,01 W når transverterens milliwatt-utgang er aktiv.',
			'settings.station.elecraftTroubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.elecraftTroubleshooting' => 'Elecraft-rigger bruker Kenwood CAT, og både en KX2 og en KX3 har blitt kjørt på denne måten — VFO i begge retninger, modusbytte og CW-nullsvevning virker.\n\nHvis radioen ikke svarer, er det nesten alltid en av disse:\n\n- **Hastigheten må samsvare** med verdien under **RS232** i radioens meny. 38400 er det de leveres med. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n\n**Hvis frekvensen er riktig, men modusen feil**, si fra til oss. Oppføringene for KX2 og KX3 leser modusen fra en posisjon i radioens statussvar som vi har fastsatt ut fra riggene vi har sett, og fastvare som legger den et annet sted, får vi bare vite om gjennom en rapport.\n\nK3 har ikke blitt rapportert verken den ene eller andre veien, så fortell hva som skjer hvis du bruker en. K4 har sin egen oppføring.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Hvis radioen kobler til, men ikke viser noen frekvens',
			'settings.station.kenwoodTroubleshooting' => 'Denne driveren er bekreftet mot Kenwoods TS-590SG og TS-480, QRP Labs\' QMX og QCX-mini, og Elecrafts KX2 og KX3. Resten av serien er skrevet etter publiserte CAT-referanser, så rapporter hva som skjer uansett utfall.\n\nHvis radioen ikke svarer, er det nesten alltid en av disse:\n\n- **Hastigheten må samsvare** med radioens CAT-meny. Ved avvik sender radioen tilbake søppel eller ingenting, og aldri en feilmelding.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.\n- **Noen rigger må ha CAT aktivert** i menyen før de svarer i det hele tatt.\n\n**Flere SDR-programmer bruker den samme protokollen**, så denne oppføringen er verdt å prøve for dem også; Elecraft-rigger står for seg selv, under Elecraft. Hvis frekvensen er riktig, men modusen er feil eller mangler, er det den ene delen som varierer i serien — appen finner den ut fra radioen og spør direkte som reserve, så modusen kan rett og slett komme litt etter.',
			'settings.station.statusConnected' => 'Tilkoblet',
			'settings.station.statusLost' => 'Frakoblet',
			'settings.station.notConfigured' => 'Ikke satt opp',
			'settings.station.currentConfiguration' => 'Gjeldende oppsett',
			'settings.station.currentTransceiver' => 'Gjeldende transceiver',
			'settings.station.radioMode' => 'Radiomodus',
			'settings.station.keyerNotSupported' => 'Støttes ikke av gjeldende radio',
			'settings.station.catControlPreferences' => 'Innstillinger for CAT-styring',
			'settings.station.chooseTransceiver' => 'Velg transceiver',
			'settings.station.configurationSection' => 'Oppsett',
			'settings.station.noTransceiverSelected' => 'Ingen transceiver valgt',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Bruk ${name} som hoved-VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, zero: 'Ingen transceivere', one: '${count} transceiver', other: '${count} transceivere', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} antenne', other: '${count} antenner', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} annen enhet', other: '${count} andre enheter', ), 
			'settings.station.equipmentInventory' => 'Utstyrsliste',
			'settings.station.equipmentInUse' => 'Transceiverkontroller',
			'settings.station.noTransceiver' => 'Ingen',
			'settings.station.peerRadioNotAvailable' => 'Ikke tilgjengelig',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'På ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} er på en annen enhet',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Denne radioen er koblet til ${device}. Tilkoblingen og innstillingene settes opp på den enheten.',
			'settings.station.antennaInUse' => 'Antenne i bruk',
			'settings.station.keyInUse' => 'Nøkkel i bruk',
			'settings.station.noneSelected' => 'Ingen',
			'settings.station.moreSettings' => 'Flere innstillinger',
			'settings.station.icomCivTroubleshootingTitle' => 'Hvis to seriellporter vises for samme radio',
			'settings.station.icomCivTroubleshooting' => 'Flere Icom-radioer, blant dem IC-705, viser **to** USB-seriellporter samtidig (Icom kaller dem Port A og Port B), begge satt til CI-V som standard. Verken denne appen eller operativsystemet kan skille dem fra hverandre utover det: samme USB-leverandør-/produkt-ID vises bare to ganger, noen ganger merket med et `#2`-suffiks her. **Port A er vanligvis den riktige** — normalt den første som operativsystemet eller nettleseren lister opp, og der denne appen kan skille de to portene, merker den den som foreslått. Hvis kommandoer går ut og radioen aldri svarer, prøv den andre porten.',
			'settings.station.civAddressTroubleshootingTitle' => 'Hvis radioen aldri svarer',
			'settings.station.civAddressTroubleshooting' => '- **CI-V-adressen må samsvare** med radioens meny. Denne oppføringen fyller inn adressen modellen leveres med, men en rigg som deler en CI-V-buss, er nettopp der den blir endret. En ramme sendt til feil adresse ignoreres i stillhet, noe som ser akkurat ut som en død kabel.\n- **Hastigheten må samsvare** med radioens CI-V BAUD RATE (på USB, CI-V USB Baud Rate). Sett radioen til samme tall som vises her, **ikke Auto**. På Auto kobler noen radioer, blant dem IC-7300, til og slutter så å svare etter et minutt eller så.\n- **En annen app kan holde porten**: WSJT-X, fldigi og rigctld holder den alle åpen.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** leveres med adresse `B6`, ikke `94` som fylles inn her — velg oppføringen for IC-7300 MK2 i stedet.',
			'settings.station.ic705PortNote' => '\n- **IC-705** viser to USB-seriellporter, begge oppkalt etter radioen. CI-V ligger på den **første** av dem, som velgeren peker på der den kan skille de to fra hverandre.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** bruker CI-V på **Port A** av de to USB-seriellportene den viser.',
			'settings.station.x6100PortNote' => '\n- **X6100** bruker CI-V på **DEV**-porten — den andre av de to seriellportene den viser, og den velgeren peker på.',
			'settings.station.rigctldTroubleshootingTitle' => 'Hvis appen ikke kan koble til',
			'settings.station.rigctldTroubleshooting' => 'Dette kobler til en **rigctld-daemon du kjører selv**, ikke direkte til radioen — Hamlibs backend snakker med radioen og støtter hundrevis av modeller.\n\n- **Daemonen må allerede kjøre**, f.eks. `rigctld -m 1035 -r /dev/ttyUSB0`. Finn modellnummeret til radioen din med `rigctl -l`.\n- **Fra en annen maskin** starter du den med `-T 0.0.0.0`: som standard tar rigctld bare imot tilkoblinger fra maskinen den kjører på.\n- **Porten** er 4532 med mindre du startet daemonen med `-t`.\n- Når den er tilkoblet, betyr manglende frekvens vanligvis at daemonen selv ikke når radioen. Test den med `rigctl -m 2 f` på daemonens maskin.',
			'settings.station.flrigTroubleshootingTitle' => 'Hvis appen ikke kan koble til',
			'settings.station.flrigTroubleshooting' => 'Dette kobler til et **flrig-program du kjører selv**, ikke direkte til radioen — flrig snakker med radioen og støtter de fleste merker og modeller.\n\n- **flrig må allerede kjøre**, med transceiveren satt opp og tilkoblet.\n- **Porten** er 12345 med mindre du har endret den i flrig-oppsettet (Config → Setup → Server).\n- **Fra en annen maskin** må du sørge for at flrig-serveren kan nås. Den lytter på alle grensesnitt, men brannmuren din er kanskje ikke enig.\n- Når den er tilkoblet, betyr manglende frekvens vanligvis at flrig selv ikke når radioen. Sjekk at flrig-skjermen følger med på hjulet.',
			'settings.station.hrdTroubleshootingTitle' => 'Hvis appen ikke kan koble til',
			'settings.station.hrdTroubleshooting' => 'Dette kobler til **Ham Radio Deluxes Rig Control, som kjører på datamaskinen din**, ikke direkte til radioen — HRD snakker med radioen.\n\n- **Rig Control må allerede kjøre** og være koblet til radioen.\n- **IP-serveren må være aktivert.** Rig Control snakker bare med andre programmer gjennom den.\n- **Porten** er 7809 med mindre du har endret den i innstillingene for IP-serveren.\n- **Fra en annen maskin** må du sørge for at brannmuren slipper tilkoblingen gjennom.\n\nDenne oppføringen er skrevet etter publiserte beskrivelser av HRDs protokoll og har ikke blitt kjørt mot HRD. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Hvis appen ikke kan koble til',
			'settings.station.n3fjpTroubleshooting' => 'Dette kobler til **et N3FJP-loggeprogram som kjører på datamaskinen din**, ikke direkte til radioen — N3FJP snakker med radioen.\n\n- **Programmets API må være på**: Settings → Application Program Interface, kryss av for **TCP API Enabled**.\n- **Porten** er 1100 med mindre du har endret den der.\n- **N3FJP må ha et radiogrensesnitt satt opp** for å følge eller stille inn radioen. Uten det rapporterer den bare det som skrives inn i registreringsvinduet.\n- N3FJP rapporterer bare bånd, modus og frekvens: ingen effekt, ingen sendestatus.\n\nDenne oppføringen er skrevet etter N3FJPs publiserte API og har ikke blitt kjørt mot N3FJP. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.commanderTroubleshootingTitle' => 'Hvis appen ikke kan koble til',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshooting' => 'Dette kobler til **DXLab Commander, som kjører på datamaskinen din**, ikke direkte til radioen — Commander snakker med radioen.\n\n- **Commander må allerede kjøre** og være koblet til radioen.\n- **Nettverkstjenesten må være på**: **Net Serv**-knappen i Radio-panelet i Commanders Configuration-vindu.\n- **Porten** er 52002, den tredje porten i blokken som starter på Net Servs **Base Port** (52000 med mindre du har endret den).\n- **Fra en annen maskin** må du sørge for at brannmuren slipper tilkoblingen gjennom.\n\nDenne oppføringen er skrevet etter Commanders publiserte TCP-meldinger og har ikke blitt kjørt mot Commander. Hvis den halvveis virker, er det verdt å rapportere.',
			'settings.station.ic705TroubleshootingTitle' => 'Hvis radioen aldri svarer',
			'settings.station.ic705Troubleshooting' => 'Radioen har **én enkelt** fjernstyringsøkt. Når innloggingen ignoreres, er det nesten alltid noe annet som bruker den.\n\n- **Lukk alle andre klienter.** wfview eller RS-BA1 koblet til samme radio holder den ene økten, og innloggingen her blir rett og slett ignorert så lenge.\n- **Sjekk radioens nettverksinnstillinger.** WLAN må være på, radioen må være på samme nettverk, og fjernstyringsfunksjonen (Network) må være aktivert.\n- **Slå radioens WLAN av og på** hvis den blir hengende. Det fjerner pålitelig en økt som har hengt seg opp på radioen.\n\nEt **feil passord blir eksplisitt avvist**, ikke møtt med stillhet. Hvis du havnet her i stedet for å få en melding om at det ble avvist, er ikke passordet problemet.',
			'settings.station.statusStale' => 'Svarer ikke',
			'settings.station.statusDisconnected' => 'Ikke tilkoblet',
			'settings.station.statusConnecting' => 'Kobler til…',
			'settings.station.statusDisconnecting' => 'Kobler fra…',
			'settings.station.statusError' => 'Tilkoblingen mislyktes',
			'settings.station.currentRadioSettings' => 'Gjeldende radioinnstillinger',
			'settings.station.notSupportedByThisRadio' => 'Støttes ikke av denne radioen',
			'settings.station.keyerRowLabel' => 'Keyer',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Telefoni',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Talekeyer: ${count} memorier i radioen',
			'settings.station.antennaBands' => 'Bånd',
			'settings.station.antennaType' => 'Antennetype',
			'settings.station.antennaTypeRequired' => 'Velg en antennetype',
			'settings.station.antennaTypes.dipole' => 'Dipol',
			'settings.station.antennaTypes.vertical' => 'Vertikal',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / beam',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Langtråd / EFHW',
			'settings.station.antennaTypes.other' => 'Annen',
			'settings.station.keyType' => 'Nøkkeltype',
			'settings.station.keyTypeRequired' => 'Velg en nøkkeltype',
			'settings.station.keyTypes.straight' => 'Pumpenøkkel',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mekanisk halvautomatisk)',
			'settings.station.keyTypes.fullyAutomatic' => 'Helautomatisk keyer',
			'settings.station.keyTypes.singlePaddle' => 'Enkel paddle',
			'settings.station.keyTypes.dualPaddle' => 'Dobbel paddle',
			'settings.station.keyTypes.computerDriven' => 'Datamaskinstyrt',
			'settings.station.keyTypes.other' => 'Annen',
			'settings.station.softwareIntermediaries' => 'Mellomliggende programvare',
			'settings.station.otherBrands' => 'Andre merker',
			'settings.station.otherEquipment' => 'Annet utstyr (antenner, nøkler osv.)',
			'settings.station.newAntenna' => 'Ny antenne',
			'settings.station.newKey' => 'Ny nøkkel',
			'settings.station.newKeyer' => 'WinKeyer (K1EL eller kompatibel)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT-keyer i ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Nøkkel på ${device}',
			'settings.station.cwKeyerArea' => 'Keyer-område',
			'settings.station.trackStationInfo' => 'Registrer stasjonsinfo for hver QSO',
			'settings.station.includeStationInfoInAdif' => 'Ta med i ADIF-eksport',
			'settings.station.whatToTrack' => 'Hva skal registreres?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Effekt',
			'settings.station.watts' => 'Watt',
			'settings.station.trackFieldAntenna' => 'Antenne',
			'settings.station.trackFieldKey' => 'CW-nøkkel',
			'settings.station.placeholderConnectDelay' => 'Tilkoblingsforsinkelse (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Hvor lang tid det simulerte handshaket tar. Tomt eller 0 kobler til umiddelbart.',
			'settings.station.placeholderDropAfter' => 'Bryt etter (sekunder)',
			'settings.station.placeholderDropAfterDescription' => 'Lukk tilkoblingen av seg selv, for å teste gjenoppkoblingen. Tomt eller 0 bryter aldri.',
			'settings.station.placeholderFailConnect' => 'Mislykkes alltid med å koble til',
			'settings.station.placeholderConnectFailure' => 'Plassholderradioen ble bedt om å avvise denne tilkoblingen',
			'settings.station.placeholderFreq' => 'Frekvens (kHz)',
			'settings.station.placeholderFreqDescription' => 'Hvor plassholderradioen starter. Etterpå rapporterer den tilbake det appen stiller den inn på.',
			'settings.station.placeholderMode' => 'Modus',
			'settings.station.placeholderModeDescription' => 'Modusen plassholderradioen starter på, f.eks. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Effekt (watt)',
			'settings.station.placeholderPurpose' => 'Bruk denne radioen til å holde rede på hvilken rigg du bruker, for loggformål',
			'settings.station.placeholderReplyDelay' => 'Svarforsinkelse (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Hvor lang tid plassholderradioen bruker på å rapportere en endring tilbake. Tomt eller 0 svarer umiddelbart.',
			'settings.station.cwKeyerField' => 'CAT CW-keyer',
			'settings.station.cwKeyerFieldDescription' => 'Om denne radioen sender CW fra tekst over CAT. Av for en rigg appen ikke kjenner.',
			'settings.station.voiceMemories' => 'Talememorier',
			'settings.station.voiceMemoriesDescription' => 'Hvor mange talememorier radioen spiller av over CAT. 0 for ingen.',
			'settings.station.voiceMemoriesInvalid' => 'Et heltall, 0 eller mer',
			'settings.station.yaesuMeterCapture' => 'Registrer måleravlesninger',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Leser radioens måler for utgangseffekt og flagg for høy SWR under sending og skriver råverdiene til loggen. For å bygge skalaen Yaesu ikke publiserer — verdiene vises ikke som målere.',
			'settings.station.yaesuMeterCaptureDescription' => 'Leser radioens PO-, SWR- og ALC-målere under sending og skriver råverdiene til loggen. For å bygge skalaen Yaesu ikke publiserer — verdiene vises ikke som målere.',
			'settings.station.telemetryInterval' => 'Intervall for måleravlesning (ms)',
			'settings.station.telemetryIntervalDescription' => 'Hvor ofte radioens målere leses mens den sender. La stå tomt for det raskeste denne tilkoblingen klarer, opptil 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Et helt antall millisekunder, ${min} til ${max}',
			'settings.station.pollInterval' => 'Spørreintervall i hvile (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Hvor ofte radioen spørres om frekvens og modus når ingen av dem endres. La stå tomt for ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Et helt antall millisekunder, ${min} til ${max}',
			'settings.station.advancedSettings' => 'Avanserte innstillinger',
			'settings.station.placeholderSwr' => 'SWR-verdi',
			'settings.station.placeholderSwrDescription' => 'Hva denne radioen rapporterer på SWR-måleren under sending. Over 1,8 gir panelet en advarsel.',
			'settings.station.placeholderSwrInvalid' => 'Et tall, 1 eller mer',
			'settings.station.keyerNone' => 'Ingen',
			'settings.station.cwDialect' => 'Dialekt for CW-nøkling',
			'settings.station.cwDialectDescription' => 'Hvilken form av KY-kommandoen denne radioen tar. Ingen betyr ingen CW-nøkling over CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, fylt ut til 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY-tekst)',
			'settings.station.voiceDialect' => 'Dialekt for talekeyer',
			'settings.station.voiceDialectDescription' => 'Hvordan denne radioen spiller av talememoriene over CAT. Ingen betyr ingen talememorier over CAT. Med en dialekt og uten antall gjelder dialektens standardantall.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, TS-590-stil)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB og DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (bryterklikk)',
			'settings.station.placeholderDiagnostic' => 'Simulert',
			'settings.station.placeholderWholeNumberInvalid' => 'Må være et heltall, 0 eller mer',
			'settings.station.placeholderFreqInvalid' => 'Må være en frekvens i kHz, større enn null',
			'settings.station.placeholderModeInvalid' => 'Må være et modusnavn, f.eks. USB, CW, FT8',
			'settings.station.switchLayout' => 'Oppsett',
			'settings.station.switchLayoutDescription' => 'Hvilken side av bryteren radioene dine er koblet til.',
			'settings.station.switchLayoutRequired' => 'Velg hvordan bryteren er koblet',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Bryteren avviste "${command}" (feil ${code})',
			'settings.station.switchBusyTransmitting' => 'Den porten sender — antennen ble ikke byttet',
			'settings.station.switchNoAntenna' => 'Ingen',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenne på port ${port}',
			'settings.station.switchAntennaForDescription' => 'Hvilken av antennene dine som er koblet til denne porten på bryteren.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antenner, ${radios} radioer',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antenner, 1 radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antenne, ${radios} radioer',
			'settings.station.switchCommonPort' => 'Felles',
			'settings.station.dcnAddress' => 'Enhetsadresse',
			'settings.station.dcnAddressDescription' => 'Adressen som er satt med DIP-bryterne på modulen. En koaksrelémodul leveres fra fabrikken med 2.',
			'settings.station.dcnAddressRequired' => 'Må være en enhetsadresse fra 1 til 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'følger bånddata',
			'settings.station.switchPortTransmittingHint' => 'sender — kan ikke endres nå',
			'settings.station.switchCurrentStateHeader' => 'Gjeldende tilstand',
			'settings.station.switchCurrentStateDescription' => 'Hvilken antenne hver radioport er på akkurat nå. Endringer trer i kraft umiddelbart.',
			'settings.station.switchWiringHeader' => 'Kabling',
			'settings.station.switchPortInhibitedHint' => 'sending sperret',
			'settings.station.configUnreadable' => 'De lagrede innstillingene for denne radioen kunne ikke leses. Åpne innstillingene og legg dem inn på nytt, eller fjern radioen og legg den til igjen.',
			'settings.station.autoConnectHeld' => 'HaLo sluttet å svare forrige gang den koblet til denne radioen, så den koblet ikke til av seg selv denne gangen. Trykk Koble til for å prøve igjen.',
			'settings.offlineData.title' => 'Offlinedata',
			'settings.offlineData.noFiles' => 'Ingen datafiler',
			'settings.offlineData.noFilesDescription' => 'Aktiver aktivitets- eller oppslagsutvidelser for å laste ned offlinedataene deres her.',
			'settings.offlineData.refresh' => 'Oppdater',
			'settings.offlineData.refreshing' => 'Oppdaterer…',
			'settings.offlineData.updateAll' => 'Oppdater alle',
			'settings.offlineData.updatingAll' => 'Oppdaterer alle datafiler…',
			'settings.offlineData.neverDownloaded' => 'Aldri lastet ned',
			'settings.offlineData.updatedJustNow' => 'Oppdatert akkurat nå',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Oppdatert for ${days}d siden',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Oppdatert for ${days}d ${hours}t siden',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Oppdatert for ${hours}t siden',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Oppdatert for ${hours}t ${minutes}m siden',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Oppdatert for ${minutes}m siden',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Den siste nedlastingen hadde bare ${imported} av ${existing} poster og ble ikke brukt. Oppdater for å godta den.',
			'settings.offlineData.extensionsSection' => 'Utvidelser',
			'settings.profiles.notSet' => 'Ikke satt',
			'settings.profiles.personalInfo' => 'Personlig info',
			'settings.profiles.personalInfoNote' => 'Dette kan bli tatt med i genererte logger når det er relevant for innsending',
			'settings.profiles.name' => 'Navn',
			'settings.profiles.email' => 'E-post',
			'settings.profiles.club' => 'Klubb',
			'settings.profiles.arrlSection' => 'ARRL-seksjon',
			'settings.profiles.racSection' => 'RAC-seksjon',
			'settings.profiles.section' => 'Seksjon',
			'settings.search.clear' => 'Tøm',
			'settings.search.hint' => 'Søk i innstillinger',
			'settings.developer.developerModeDescription' => 'Aktiver utvikleradvarsler, feilsøkingslogger og verktøy.',
			'settings.developer.experiments' => 'Eksperimenter',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} aktivert', other: '${count} aktivert', ), 
			'settings.developer.patchTrack' => 'Spor for kodeoppdateringer',
			'settings.developer.patchTrackDescription' => 'Hvilken ring for trådløse kodeoppdateringer denne enheten følger. Mer eventyrlystne ringer får rettelser tidligere, men mindre testet. Kodeoppdateringer tas i bruk ved neste omstart.',
			'settings.developer.trackStable' => 'Stabil',
			'settings.developer.trackUnstable' => 'Ustabil',
			'settings.developer.trackBleeding' => 'Dagsfersk',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Ser etter kodeoppdatering på "${track}"…',
			'settings.developer.patchDownloaded' => 'Kodeoppdatering lastet ned — start appen på nytt for å ta den i bruk.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Ingen ny kodeoppdatering på "${track}".',
			'settings.developer.noPatchInstalled' => 'Ingen kodeoppdatering installert — kjører utgivelsesversjonen.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Kjører kodeoppdatering #${patch}.',
			'settings.developer.deepLinks' => 'Dyplenker',
			'settings.developer.registerUrlSchemes' => 'Registrer URL-skjemaer',
			'settings.developer.registerUrlSchemesDescription' => 'La com.ham2k://-lenker åpne denne kopien av appen',
			'settings.developer.registerUrlSchemesDone' => 'Denne kopien åpner nå com.ham2k://-lenker',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Kunne ikke registrere: ${error}',
			'settings.developer.systemInformation' => 'Systeminformasjon',
			'settings.developer.appVersion' => 'Appversjon',
			'settings.developer.dataFolder' => 'Datamappe',
			'settings.developer.loading' => '(laster…)',
			'settings.developer.panelLoadFailed' => 'Kunne ikke laste dette innstillingspanelet.',
			'settings.developer.extDevServer' => 'Utviklingsserver for utvidelser',
			'settings.developer.extensionSettings' => 'Utvidelsesinnstillinger',
			'settings.developer.extDevServerDescription' => 'Last inn utvidelser fra en utviklingsserver på nettverket ditt i stedet for de som er innebygd i appen, og last dem inn på nytt når du lagrer.',
			'settings.developer.extDevServerAddress' => 'Serveradresse',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Koble til',
			'settings.developer.extDevServerDisconnect' => 'Koble fra',
			'settings.developer.extDevServerConnecting' => 'Kobler til…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Leverer ${count} utvidelse: ${keys}', other: 'Leverer ${count} utvidelser: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Ikke tilkoblet',
			'settings.developer.extDevServerReconnect' => 'Koble til på nytt ved oppstart',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Sist lastet inn på nytt: ${key} kl. ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} utvidelse feiler under bygging', other: '${count} utvidelser feiler under bygging', ), 
			'settings.developer.catalog' => 'Utvidelseskatalog',
			'settings.developer.catalogDescription' => 'Les katalogen fra en annen server — en lokal en mens du jobber med selve katalogen. Tomt betyr catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Katalogadresse',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Spor for katalogsøk',
			'settings.developer.catalogSearchStable' => 'Bare stabile',
			'settings.developer.catalogSearchUnstable' => 'Ustabile eller bedre',
			'settings.developer.catalogSearchBleeding' => 'Dagsferske eller bedre',
			'settings.about.notices' => 'Varsler og meldinger',
			'settings.about.noticesDescription' => 'Kunngjøringer og statusmeldinger',
			'settings.about.releaseNotes' => 'Versjonsmerknader',
			'settings.about.copiedVersion' => 'Versjonsdetaljer kopiert til utklippstavlen',
			'settings.panels.settings' => 'Appinnstillinger',
			'settings.panels.settingsDescription' => 'Få appen til å virke slik du vil',
			'settings.panels.commonSettings' => 'Vanlige innstillinger',
			'settings.panels.syncDescription' => 'Ta sikkerhetskopi av og synkroniser loggene dine mellom enheter',
			'settings.panels.accountsDescription' => 'Tjenesteinnlogginger, offlinedata og mer',
			'settings.panels.extensions' => 'Utvidelser og funksjoner',
			'settings.panels.extensionsDescription' => 'Aktiviteter, konkurranser, dashbordpaneler og flere funksjoner',
			'settings.panels.profilesDescription' => 'Operatørkallesignal og stasjonsprofil',
			'settings.panels.stationProfiles' => 'Stasjonsprofiler',
			'settings.panels.developerSettings' => 'Utviklerinnstillinger',
			'settings.panels.developerSettingsDescription' => 'Feilsøkings- og utviklingsverktøy',
			'settings.panels.about' => 'Om',
			'settings.panels.aboutDescription' => 'Versjon, krediteringer og juridisk informasjon',
			'settings.panels.unavailableTitle' => 'Noen innstillinger er utilgjengelige',
			'settings.panels.unavailableText' => 'Kjøremiljøet for utvidelser startet ikke, så innstillinger fra utvidelser mangler.',
			'settings.panels.station' => 'Stasjonsoppsett',
			'settings.panels.stationDescription' => 'CAT-styring og flere alternativer',
			'settings.panels.peers' => 'Andre enheter',
			'settings.panels.peersDescription' => 'Koble til andre enheter i nærheten',
			'settings.showMoreSettings' => 'Vis flere innstillinger',
			'settings.gridPrecision' => 'Grid-presisjon',
			'settings.gridPrecisionOpts.six' => '6 tegn (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 tegn (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 tegn',
			'settings.gridPrecisionDescription.eight' => '8 tegn',
			'commands.enableSyncFirst' => 'Aktiver synkronisering i Innstillinger først.',
			'commands.fullResyncStarted' => 'Full ny synkronisering startet — lokale data ble sikkerhetskopiert først.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Ingen datafiler samsvarte med "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Ny innlasting mislyktes: ${error}',
			'commands.reloadingAll' => 'Laster inn alle datafiler på nytt…',
			'commands.reloadingTarget' => ({required Object target}) => 'Laster inn datafiler for ${target} på nytt…',
			'commands.unknownExperiment' => ({required Object token}) => 'Ukjent eksperiment "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} aktivert',
			'commands.experimentDisabled' => ({required Object name}) => '${name} deaktivert',
			'commands.sentryTestSent' => 'Testfeilrapport sendt til Sentry',
			'commands.sentryTestLocalOnly' => 'Sentry er deaktivert i denne versjonen — testfeilen ble bare logget lokalt',
			'commands.noOperationOpen' => 'Den kommandoen krever en åpen operasjon',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Vet ikke hvordan en \'${kind}\' skal markeres',
			'commands.operationAlreadyStarted' => 'Denne operasjonen har allerede en startmarkør',
			'commands.couldNotOpenLocation' => 'La til pausen, men kunne ikke åpne posisjonsskjermen',
			'commands.noTestOperations' => 'Ingen testoperasjoner å fjerne',
			'commands.purgeTestsUnavailable' => 'PURGETESTS må vise en bekreftelsesdialog, og det er ikke mulig her',
			'commands.syncAllUnavailable' => 'SYNCALL må vise en bekreftelsesdialog, og det er ikke mulig her',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Fjernet ${count} testoperasjon', other: 'Fjernet ${count} testoperasjoner', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Fjernet ${purged} av ${total} testoperasjoner — resten mislyktes; prøv PURGETESTS igjen',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Fjernet ${count} testkontakt uten operasjon', other: 'Fjernet ${count} testkontakter uten operasjon', ), 
			'commands.purgeTestsContactsFailed' => 'Fjernet testoperasjonene, men testkontaktene uten operasjon mislyktes; prøv PURGETESTS igjen',
			'commands.purgeTestsNothingToDo' => 'Ingenting ble fjernet',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Fjernet ${removed} av ${total} testoperasjoner — resten mislyktes; prøv Gjennomgå igjen',
			'commands.receivedPurgesFailed' => 'Kunne ikke fjerne disse testoperasjonene — prøv Gjennomgå igjen',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} testoperasjon ble fjernet på en annen enhet', other: '${count} testoperasjoner ble fjernet på en annen enhet', ), 
			'commands.receivedPurgesReview' => 'Gjennomgå',
			'commands.settingOn' => 'På',
			'commands.settingOff' => 'Av',
			'commands.settingEmpty' => '(tom)',
			'commands.settingSecretSet' => '(satt)',
			'commands.settingSecretUnset' => '(ikke satt)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} valgt',
			'commands.settingExpectsOnOff' => 'på eller av',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'en av: ${choices}',
			'commands.settingExpectsNumber' => 'et tall',
			'commands.settingVanished' => ({required Object label}) => '«${label}» er ikke lenger tilgjengelig',
			'commands.noCwKeyer' => 'Ingen tilkoblet radio kan sende CW',
			'commands.noKeyer' => 'Ingen tilkoblet radio kan sende CW eller spille av talememorier',
			'commands.keyerNeedsOperation' => 'Åpne en operasjon for å bruke CW-keyeren',
			'commands.keyerExperimentOff' => 'CW-nøkling er av — slå det på med EXP KEYER',
			'commands.esmExperimentOff' => 'Enter sender meldinger er av — slå det på med EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Sender CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW-melding F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW-melding F${n} ble ikke sendt: utvidelsene er ikke klare',
			'commands.settingNotStored' => ({required Object label}) => '«${label}» godtok ikke den verdien',
			'commandDialog.hint' => 'Søk etter kallesignaler eller skriv en kommando',
			'commandDialog.noResults' => ({required Object text}) => 'Ingenting samsvarer med «${text}»',
			'commandDialog.sectionCommands' => 'Kommandoer',
			'commandDialog.sectionGoTo' => 'Gå til',
			'commandDialog.sectionOperations' => 'Operasjoner',
			'commandDialog.goHome' => 'Hjem',
			'commandDialog.goSettings' => 'Innstillinger',
			'commandDialog.goNewOperation' => 'Ny operasjon',
			'commandDialog.runTyped' => ({required Object text}) => 'Kjør «${text}»',
			'commandDialog.sectionSuggestions' => 'Prøv',
			'commandDialog.lookingUp' => 'Slår opp kallesignal…',
			'commandDialog.blockedByPane' => 'Kan ikke bruke kommandoer mens et panel eller en dialog er åpen',
			'expiredBuild.title' => 'Denne versjonen er utløpt',
			'expiredBuild.body' => 'Gå til ham2k.com og hent en nyere versjon.',
			'expiredBuild.visit' => 'Gå til ham2k.com',
			'expiredBuild.dismiss' => 'Fortsett likevel',
			'staleness.codePushFloorTitle' => 'En viktig oppdatering venter',
			'staleness.codePushFloorBody' => 'Denne versjonen har en rettelse du ikke har ennå.',
			'staleness.restartToApply' => 'Start appen på nytt for å ta den i bruk.',
			'staleness.quitAndReopen' => 'Avslutt appen og åpne den igjen for å ta den i bruk.',
			'staleness.reopenToApply' => 'Lukk appen og åpne den igjen for å ta den i bruk.',
			'staleness.ignoreForNow' => 'Ignorer foreløpig',
			'spotting.noQsoYet' => 'Ingen QSO logget ennå å spotte.',
			'spotting.setFrequencyFirst' => 'Angi en frekvens først.',
			'spotting.nothingToSpot' => 'Ingenting å spotte — ingen utvidelse tilbyr spotting her.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} mislyktes: ${message}',
			'spotting.unknownError' => 'ukjent feil',
			'spotting.notSent' => 'Spot ikke sendt.',
			'spotting.notRefreshedOffline' => 'Ingen forbindelse — spots ble ikke oppdatert',
			'dataFiles.downloading' => 'Laster ned…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Kunne ikke laste ned ${name}',
			'dataFiles.downloadFailedWebHint' => 'Dette kan være et nettverksproblem, eller verten for denne lenken støtter kanskje ikke direkte nedlasting fra en nettleser. Prøv skrivebords- eller mobilappen, eller et annet lagringssted.',
			'dataFiles.downloadTimedOut' => 'Serveren brukte for lang tid på å svare. Prøv igjen senere.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} svarte med en feil (HTTP ${status}). Prøv igjen senere.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} kunne ikke levere denne filen (HTTP ${status}). Sjekk at adressen fortsatt er riktig.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Kunne ikke behandle ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Nedlastingen hadde bare ${imported} av de ${existing} postene på denne enheten, så de som manglet, ble beholdt. Oppdater den i Innstillinger › Offlinedata for å godta den likevel.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Importerte ${count} post for ${label}.', other: 'Importerte ${count} poster for ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Importerte data for ${label}.',
			'dataFiles.cleanedUpTitle' => 'Ryddet opp i utvidelsesdata',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Fjernet data for ${count} datafil fra deaktiverte utvidelser.', other: 'Fjernet data for ${count} datafiler fra deaktiverte utvidelser.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} poster',
			'dataFiles.definitionUnavailable' => 'Kilden for filen leverte ingen definisjon — utvidelsen kan være midt i en omstart eller feil satt opp. Prøv igjen om et øyeblikk.',
			'updates.updateAvailable' => 'Oppdatering tilgjengelig',
			'updates.newVersionAvailable' => ({required Object version}) => 'En ny versjon (${version}) er tilgjengelig.',
			'updates.getIt' => 'Hent den',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Oppdatering klar',
			'updates.restartToApply' => 'En oppdatering er lastet ned. Start på nytt for å ta den i bruk.',
			'updates.appliesNextLaunch' => 'En oppdatering er lastet ned. Den tas i bruk neste gang du åpner appen.',
			'updates.restartNow' => 'Start på nytt nå',
			'updates.reloadToUpdate' => 'En nyere versjon av denne siden er tilgjengelig. Last inn på nytt for å få den.',
			'updates.reloadNow' => 'Last inn på nytt nå',
			'updates.checkForUpdates' => 'Se etter oppdateringer',
			'updates.checkingForUpdates' => 'Ser etter oppdateringer…',
			'updates.upToDate' => 'Oppdatert',
			'updates.automaticChecks' => 'Se etter automatisk',
			'updates.automaticChecksDescription' => 'Se etter nye versjoner i bakgrunnen, fra neste gang du starter appen',
			'extensionService.runtimeNotReady' => 'Kjøremiljøet for utvidelser er ikke klart.',
			'extensionService.testFailed' => ({required Object error}) => 'Testen mislyktes: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Tilkoblet som ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Ugyldig feltoppsett',
			'extensionService.invalidValue' => 'Ugyldig verdi',
			'extensionService.validationError' => ({required Object error}) => 'Valideringsfeil: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Handlingen mislyktes: ${error}',
			'extensionService.commandFailed' => 'Kommandoen kunne ikke kjøres',
			'extensionService.reportUnavailable' => 'Rapporter kan ikke sendes akkurat nå',
			'extensionService.stashUnavailable' => 'Ham2K File Stash kan ikke nås akkurat nå',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} brukte for mye tid i tidtakerne sine. De er stoppet til utvidelsene starter på nytt.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Tidtakerne til ${name} feilet gang på gang. De er stoppet til utvidelsene starter på nytt.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} ble sittende fast i en tidtaker. Tidtakerne er stoppet til utvidelsene starter på nytt.',
			'operationLocationScreen.title' => 'Plassering',
			'operationLocationScreen.selectedLocation' => 'Valgt plassering',
			'operationLocationScreen.gridSquare' => 'Maidenhead-lokator',
			'operationLocationScreen.gridInvalid' => 'Trenger 4, 6, 8 eller 10 tegn, som FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Foreslåtte plasseringer',
			'operationLocationScreen.deviceGps' => 'Enhetens GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS fra ${device}',
			'operationLocationScreen.locating' => 'Lokaliserer…',
			'operationLocationScreen.gpsUnavailable' => 'Posisjon utilgjengelig',
			'operationLocationScreen.permissionDenied' => 'Tilgang til posisjon avslått',
			'operationLocationScreen.permissionBlocked' => 'Tilgang til posisjon blokkert',
			'operationLocationScreen.moreDetails' => 'Flere detaljer',
			'operationLocationScreen.stateOrProvince' => 'Delstat eller provins (valgfritt)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Aktivitetskontroller utilgjengelige',
			'operationLocationScreen.controlsUnavailableReason' => 'Disse referansene kan fortsatt brukes; aktivitetene deres kunne bare ikke nås.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Prøv igjen',
			'operationLocationScreen.county' => 'Fylke (valgfritt)',
			'versionLabel.version' => ({required Object version}) => 'Versjon ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Oppdatering ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Ingen varsler ennå',
			'notices.webStorageInMemory' => 'Denne nettleseren kunne ikke tilby varig lagring — loggen finnes bare i minnet og GÅR TAPT når denne fanen lukkes. Bruk en oppdatert Chrome, Firefox, Safari eller Edge.',
			'notices.webStorageUnreliable' => 'Denne nettleseren bruker reservelagring som ikke er trygg med flere faner — hold bare én fane åpen, og la synkroniseringen være på.',
			'notices.logFromNewerBuildTitle' => 'Denne loggen krever en nyere versjon',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Loggen din ble skrevet av en nyere versjon av HaLo (lagringsversjon ${storage}; denne forstår ${understood}), så den kan ikke åpnes, og nye kontakter blir ikke lagret. Installer den nyere versjonen igjen — eller, hvis du mente å kjøre denne versjonen, pek den mot en annen datamappe. Loggen ligger i ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Loggen din ble skrevet av en nyere versjon av HaLo (lagringsversjon ${storage}; denne forstår ${understood}), så den kan ikke åpnes, og nye kontakter blir ikke lagret. Åpne loggen med den nyere versjonen i stedet.',
			'notices.preferencesRestoredTitle' => 'Innstillinger gjenopprettet fra sikkerhetskopi',
			'notices.preferencesRestored' => 'Innstillingsfilen kunne ikke leses, så HaLo gjenopprettet den siste gode kopien. Det du endret i forrige økt, må kanskje settes på nytt. Den uleselige filen er beholdt ved siden av, med navnet shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Innstillinger tilbakestilt',
			'notices.preferencesReset' => 'Innstillingsfilen kunne ikke leses, og det fantes ingen sikkerhetskopi å falle tilbake på, så HaLo startet med standardinnstillingene. Den uleselige filen er beholdt i appens datamappe, med navnet shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} ble ikke koblet til automatisk',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo sluttet å svare forrige gang den begynte å koble til ${name}, så den lot den være denne gangen i stedet for å risikere det igjen. Sjekk at radioen er slått på og at kabelen er koblet til, og trykk så Koble til på den i Innstillinger.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonym konto (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (venter på bekreftelse)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (venter på bekreftelse - #${id})',
			'deepLink.needsAnOperation' => 'Start en operasjon først, og send så den kontakten igjen',
			'deepLink.waitingInOperation' => 'Den kontakten venter i operasjonen bak denne skjermen',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Denne enheten har ingen aktivitet for ${refs}, så disse referansene ble utelatt',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Kunne ikke nå aktivitetene dine, så ${refs} ble utelatt — prøv lenken igjen',
			'confirmDevice.title' => 'Bekreft en enhet',
			'confirmDevice.codePrompt' => 'Skriv inn koden som vises på enheten som vil bli med i denne kontoen.',
			'confirmDevice.code' => 'Kode',
			'confirmDevice.lookUp' => 'Slå opp',
			'confirmDevice.codeNotFound' => 'Ingen forespørsel samsvarer med den koden. Koder utløper etter 10 minutter — be den andre enheten om en ny.',
			'confirmDevice.linkExpired' => 'Den lenken har utløpt. Be den andre enheten om å vise en ny QR-kode.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Koble ${device} til denne kontoen?',
			'confirmDevice.unnamedDevice' => 'en enhet uten navn',
			'confirmDevice.grantWarning' => 'Den vil kunne lese og endre alle operasjoner og QSOer i denne kontoen.',
			'confirmDevice.needsSyncTitle' => 'Denne enheten synkroniserer ikke ennå',
			'confirmDevice.needsSyncText' => 'Slå på Ham2K Log Filer-synkronisering og koble denne enheten til en konto før den kan slippe inn en annen.',
			'confirmDevice.malformedRequest' => 'Synkroniseringsserveren sendte en forespørsel denne appen ikke kunne lese. Be den andre enheten om å prøve igjen.',
			'confirmDevice.linkIt' => 'Koble enhet',
			'switchAccounts.noAccountDetails' => 'Ingen kontodetaljer ennå',
			'switchAccounts.currentAccount' => 'Gjeldende konto',
			'switchAccounts.otherAccounts' => 'Andre kontoer',
			'switchAccounts.linkToAnother' => 'Koble til en annen konto',
			'switchAccounts.linkWithSibling' => 'Koble til en annen Ham2K-app',
			'switchAccounts.linkWithPolo' => 'Koble til kontoen i den eldre versjonen',
			'switchAccounts.linkWithSiblingDescription' => 'Du har en annen Ham2K-app installert. Koble til kontoen som brukes der.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Godkjenn forespørselen i ${app}, og kom så tilbake hit.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Åpne ${app} igjen',
			'switchAccounts.siblingNoGrant' => 'Virket det ikke? Åpne den igjen, eller gå tilbake og koble til på en annen måte.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Kunne ikke åpne ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Lenken utløp, og en ny er klar — åpne ${app} igjen.',
			'switchAccounts.tryAgain' => 'Prøv igjen',
			'switchAccounts.linkWithQr' => 'Koble til med en QR-kode',
			'switchAccounts.linkWithQrDescription' => 'Skann den fra en enhet som allerede bruker kontoen',
			'switchAccounts.linkWithEmail' => 'Koble til med en e-postadresse',
			'switchAccounts.linkWithEmailDescription' => 'Bekreft med en kode eller en lenke i e-post',
			'switchAccounts.enterEmailPrompt' => 'Oppgi e-postadressen til kontoen du vil at denne enheten skal bruke.',
			'switchAccounts.emailAddress' => 'E-postadresse',
			'switchAccounts.linkAccount' => 'Koble til konto',
			'switchAccounts.copiedCode' => 'Koden er kopiert til utklippstavlen',
			'switchAccounts.copyCode' => 'Kopier kode',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Åpne Ham2K-appen på en enhet som allerede er koblet til ${email}, og skriv inn denne koden for å godkjenne forespørselen:',
			'switchAccounts.waitingForConfirmation' => 'Venter på bekreftelse…',
			'switchAccounts.sendEmailInstead' => 'Send en bekreftelses-e-post i stedet',
			'switchAccounts.emailSent' => ({required Object email}) => 'En e-post ble sendt til ${email}. Åpne den og bekreft forespørselen for å koble til denne enheten.',
			'switchAccounts.resendEmail' => 'Send e-post på nytt',
			'switchAccounts.qrPrompt' => 'Skann denne QR-koden fra en enhet som allerede er koblet til kontoen du vil bruke — for eksempel med Ham2K Portable Logger på telefonen din.',
			'switchAccounts.serverUnreachable' => 'Kunne ikke nå synkroniseringsserveren. Prøv igjen senere.',
			'switchAccounts.emailRequired' => 'Oppgi en e-postadresse å koble til.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Fant ingen konto for ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Synkroniseringsserveren avviste forespørselen: ${error}',
			'switchAccounts.noLinkCode' => 'Synkroniseringsserveren returnerte ingen tilkoblingskode. Prøv igjen senere.',
			'switchAccounts.noConfirmationCode' => 'Synkroniseringsserveren sendte ingen bekreftelseskode. Prøv igjen senere.',
			'switchAccounts.switchNotAccepted' => 'Den kontoen godtok ikke byttet. Prøv å koble den til med en e-postadresse i stedet.',
			'switchAccounts.requestFailed' => 'Noe gikk galt i kommunikasjonen med synkroniseringsserveren. Prøv igjen senere.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} QSO', other: '${count} QSOer', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} operasjon', other: '${count} operasjoner', ), 
			'adifImport.title' => 'Importer QSOer fra ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Leser ${filename}…',
			'adifImport.dropHint' => 'Slipp en ADIF-fil her for å importere',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} QSO i denne filen', other: '${formatted} QSOer i denne filen', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} finnes allerede i loggen din', other: '${formatted} finnes allerede i loggen din', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} blir importert', other: '${formatted} blir importert', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} ny kontakt', other: '${formatted} nye kontakter', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} blir slått sammen med en eksisterende kontakt', other: '${formatted} blir slått sammen med eksisterende kontakter', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} kan ikke importeres (mangler kallesignal)', other: '${formatted} kan ikke importeres (mangler kallesignal)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} bør sees nærmere på', other: '${formatted} bør sees nærmere på', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Referanser kunne ikke gjenopprettes for ${count} kontakt', other: 'Referanser kunne ikke gjenopprettes for ${formatted} kontakter', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${programs}-referanser kan være ufullstendige for ${count} kontakt', other: '${programs}-referanser kan være ufullstendige for ${formatted} kontakter', ), 
			'adifImport.stackingTypesUnknown' => 'Sammenslåtte kontakter kan miste en referanse — aktivitetene kunne ikke si hvilke typer som kan kombineres. Avbryt og prøv igjen for å unngå dette.',
			'adifImport.nothingToImport' => 'Ingenting i denne filen kan importeres',
			'adifImport.confirm' => 'Importer',
			'adifImport.importing' => ({required Object filename}) => 'Importerer ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: 'Importerte ${count} kontakt fra ${filename}', other: 'Importerte ${formatted} kontakter fra ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Kunne ikke importere ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} ser ikke ut som en ADIF-fil',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Advarsel: denne ADIF-filen har QSOer fra ${calls}, men de blir importert som ${station} hvis du fortsetter.',
			'adifImport.stationCallJoin' => ' og ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nb'))(count, one: '${count} mangler dato og kan ikke importeres', other: '${formatted} mangler dato og kan ikke importeres', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Denne filen registrerer en aktivering av ${refs}.',
			'adifImport.addActivation' => 'Legg den til i denne operasjonen',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Bare ${written} av ${planned} kunne tas i bruk — loggen ble endret mens du bestemte deg.',
			'adifImport.busy' => 'En import pågår allerede. Vent til den er ferdig før du starter en ny.',
			'adifImport.oneFileOnly' => 'Slipp én ADIF-fil om gangen — rekkefølgen filene importeres i, avgjør hvilke data som vinner.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} har mer enn ${limit} QSOer, som er det meste en operasjon kan importere om gangen.',
			'offline.statusOffline' => 'Internett: FRAKOBLET',
			'offline.statusOnline' => 'Internett: tilkoblet',
			'offline.noRoute' => 'Ingen nettverkstilkobling i det hele tatt.',
			'offline.unreachable' => 'Nettverket er oppe, men ingen server svarer — ofte et tegn på at en innloggingsside venter i en nettleser.',
			'offline.reachable' => 'Alle tjenester svarer som forventet.',
			'offline.whatStops' => 'Oppslag, spots og datafiler er satt på pause. Logging og synkronisering i nærheten er det ikke.',
			'offline.servicesTitle' => 'Tjenester',
			'offline.noServices' => 'Ingen tjeneste har rapportert inn ennå.',
			'offline.lastSuccess' => ({required Object when}) => 'Svarte sist for ${when} siden',
			'offline.neverSucceeded' => 'Har ikke svart ennå',
			'offline.nextAttempt' => ({required Object when}) => 'Neste forsøk om ${when}',
			'offline.nextAttemptNow' => 'Neste forsøk står for tur',
			'offline.retry' => 'Prøv igjen nå',
			'offline.retrying' => 'Prøver…',
			'offline.retryReached' => 'Tilkoblet igjen.',
			'offline.retryUnreachable' => 'Fortsatt ikke noe svar.',
			'offline.retryNotAttempted' => 'Ingenting å sende akkurat nå.',
			'offline.retryThrottled' => 'Prøvde akkurat — vent litt.',
			'offline.retryDisabled' => 'Synkronisering er slått av, så det finnes ingenting å teste med.',
			'offline.syncService' => 'Ham2K LoFi-synkronisering',
			'offline.retryInFlight' => 'Prøver allerede — vent litt.',
			'exportSettings.defaultsDescription' => 'Grunninnstillinger for alle eksporter, med egne maler for filnavn og tittel for referanseaktiviteter og andre aktiviteter. Hver eksporttype kan ha sine egne standarder eller tilpassede innstillinger.',
			'exportSettings.referenceActivities' => 'Referanseaktiviteter',
			'exportSettings.otherActivities' => 'Andre aktiviteter',
			'exportSettings.adifFields' => 'ADIF-felt',
			'exportSettings.loadFailed' => 'Eksportinnstillingene kunne ikke lastes.',
			'exportSettings.retry' => 'Prøv igjen',
			'exportSettings.compactFileNamesDescriptionOn' => 'Kompakte filnavn, som N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Beskrivende filnavn, som 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Tar med navn, adresser, e-poster, notater og nøyaktige posisjoner i ADIF-filer.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Utelater navn, adresser, e-poster og notater; begrenser posisjoner til grid med seks tegn.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Tar med informasjon fra tjenester for kallesignaloppslag.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Utelater informasjon fra tjenester for kallesignaloppslag; beholder manuelt inntastede verdier.',
			'exportSettings.customTemplatesDescriptionOn' => 'De egendefinerte malene dine er aktive og kan redigeres nedenfor.',
			'exportSettings.customTemplatesDescriptionOff' => 'Standardmalene er aktive. De egendefinerte malene dine beholdes til senere.',
			'exportSettings.type' => 'Eksporttype',
			'exportSettings.defaults' => 'Standardinnstillinger',
			'exportSettings.includeLookupData' => 'Ta med oppslagsdata',
			'exportSettings.customTemplates' => 'Egendefinerte maler',
			'exportSettings.filenameTemplate' => 'Filnavnsmal',
			'exportSettings.compactFilenameTemplate' => 'Mal for kompakt filnavn',
			'exportSettings.titleTemplate' => 'Tittelmal',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO-notater',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO-kommentarer',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL-melding',
			'exportSettings.shared' => 'Innstillingene gjelder for alle utvidelser som bruker denne eksporttypen.',
			'exportSettings.defaultTemplates' => 'Slå på Egendefinerte maler for å redigere malene for denne typen.',
			'templateEditor.previewLabel' => 'Forhåndsvisning:',
			'templateEditor.reset' => 'Tilbakestill',
			'templateEditor.docs' => 'Dokumentasjon for maler',
			'templateEditor.preview' => 'Eksempelvisning',
			'templateEditor.reference' => 'Malreferanse',
			'templateEditor.attributes' => 'Tilgjengelige attributter',
			'templateEditor.filters' => 'Filtre',
			'templateEditor.flowControl' => 'Flytkontroll',
			'templateEditor.unavailable' => 'Forhåndsvisning er utilgjengelig til utvidelsene er klare.',
			'templateEditor.empty' => '(tomt resultat)',
			_ => null,
		};
	}
}
