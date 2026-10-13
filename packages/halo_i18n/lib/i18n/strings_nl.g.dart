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
class TranslationsNl extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsNl({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.nl,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <nl>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsNl _root = this; // ignore: unused_field

	@override 
	TranslationsNl $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsNl(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$nl common = _Translations$common$nl._(_root);
	@override late final _Translations$onboarding$nl onboarding = _Translations$onboarding$nl._(_root);
	@override late final _Translations$startScreen$nl startScreen = _Translations$startScreen$nl._(_root);
	@override late final _Translations$testerOverlay$nl testerOverlay = _Translations$testerOverlay$nl._(_root);
	@override late final _Translations$extensionsPanel$nl extensionsPanel = _Translations$extensionsPanel$nl._(_root);
	@override late final _Translations$home$nl home = _Translations$home$nl._(_root);
	@override late final _Translations$chase$nl chase = _Translations$chase$nl._(_root);
	@override late final _Translations$dialogs$nl dialogs = _Translations$dialogs$nl._(_root);
	@override late final _Translations$operation$nl operation = _Translations$operation$nl._(_root);
	@override late final _Translations$map$nl map = _Translations$map$nl._(_root);
	@override late final _Translations$mapsView$nl mapsView = _Translations$mapsView$nl._(_root);
	@override late final _Translations$activitiesView$nl activitiesView = _Translations$activitiesView$nl._(_root);
	@override late final _Translations$loggingControls$nl loggingControls = _Translations$loggingControls$nl._(_root);
	@override late final _Translations$formChrome$nl formChrome = _Translations$formChrome$nl._(_root);
	@override late final _Translations$qsoEditForm$nl qsoEditForm = _Translations$qsoEditForm$nl._(_root);
	@override late final _Translations$qsoList$nl qsoList = _Translations$qsoList$nl._(_root);
	@override late final _Translations$loggingPanel$nl loggingPanel = _Translations$loggingPanel$nl._(_root);
	@override late final _Translations$callInfo$nl callInfo = _Translations$callInfo$nl._(_root);
	@override late final _Translations$settings$nl settings = _Translations$settings$nl._(_root);
	@override late final _Translations$commands$nl commands = _Translations$commands$nl._(_root);
	@override late final _Translations$commandDialog$nl commandDialog = _Translations$commandDialog$nl._(_root);
	@override late final _Translations$expiredBuild$nl expiredBuild = _Translations$expiredBuild$nl._(_root);
	@override late final _Translations$staleness$nl staleness = _Translations$staleness$nl._(_root);
	@override late final _Translations$spotting$nl spotting = _Translations$spotting$nl._(_root);
	@override late final _Translations$dataFiles$nl dataFiles = _Translations$dataFiles$nl._(_root);
	@override late final _Translations$updates$nl updates = _Translations$updates$nl._(_root);
	@override late final _Translations$extensionService$nl extensionService = _Translations$extensionService$nl._(_root);
	@override late final _Translations$operationLocationScreen$nl operationLocationScreen = _Translations$operationLocationScreen$nl._(_root);
	@override late final _Translations$versionLabel$nl versionLabel = _Translations$versionLabel$nl._(_root);
	@override late final _Translations$notices$nl notices = _Translations$notices$nl._(_root);
	@override late final _Translations$syncAccount$nl syncAccount = _Translations$syncAccount$nl._(_root);
	@override late final _Translations$deepLink$nl deepLink = _Translations$deepLink$nl._(_root);
	@override late final _Translations$confirmDevice$nl confirmDevice = _Translations$confirmDevice$nl._(_root);
	@override late final _Translations$switchAccounts$nl switchAccounts = _Translations$switchAccounts$nl._(_root);
	@override late final _Translations$adifImport$nl adifImport = _Translations$adifImport$nl._(_root);
	@override late final _Translations$offline$nl offline = _Translations$offline$nl._(_root);
	@override late final _Translations$exportSettings$nl exportSettings = _Translations$exportSettings$nl._(_root);
	@override late final _Translations$templateEditor$nl templateEditor = _Translations$templateEditor$nl._(_root);
}

// Path: common
class _Translations$common$nl extends Translations$common$en {
	_Translations$common$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get save => 'Opslaan';
	@override String get ok => 'OK';
	@override String get cancel => 'Annuleren';
	@override String get delete => 'Verwijderen';
	@override String get create => 'Aanmaken';
	@override String get error => 'Fout';
	@override String get close => 'Sluiten';
	@override String get done => 'Klaar';
	@override String get callsign => 'Roepnaam';
	@override String get clear => 'Wissen';
	@override String get dismiss => 'Negeren';
	@override String get expand => 'Uitklappen';
	@override String get collapse => 'Inklappen';
}

// Path: onboarding
class _Translations$onboarding$nl extends Translations$onboarding$en {
	_Translations$onboarding$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Welkom bij Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Welkom bij Ham2K Power Logger!';
	@override String get welcomeBody => 'We hebben een paar vragen om beter op je wensen in te spelen.';
	@override String get skip => 'Overslaan';
	@override String get kContinue => 'Doorgaan';
	@override String get back => 'Terug';
	@override String get next => 'Volgende';
	@override String get done => 'Klaar';
	@override String get callsignTitle => 'Wat is je roepnaam?';
	@override String get callsignBody => 'Je hebt een zendmachtiging voor radioamateurs nodig om deze app nuttig te vinden';
	@override String get callsignLabel => 'Roepnaam van de operator';
	@override String get alreadyHaveAccount => 'Heb je al een account?';
	@override String get foundSiblingTitle => 'Een bestaand account koppelen?';
	@override String foundSiblingBody({required Object app}) => 'We hebben ${app} op dit apparaat gevonden. Koppel deze app aan hetzelfde account en je roepnaam en logboeken komen mee.';
	@override String get foundPoloBody => 'We hebben een oudere versie van Ham2K Portable Logger op dit apparaat gevonden. Koppel deze app aan hetzelfde account en je roepnaam en logboeken komen mee.';
	@override String get foundSiblingsBody => 'We hebben andere Ham2K-apps op dit apparaat gevonden. Koppel deze app aan een van hun accounts en je roepnaam en logboeken komen mee.';
	@override String linkWithApp({required Object app}) => 'Koppelen met ${app}';
	@override String get linkWithPolo => 'Koppelen met account in oudere versie';
	@override String get setUpFresh => 'Opnieuw beginnen';
	@override String get activitiesTitle => 'Favoriete activiteiten';
	@override String get activitiesBody => 'Ben je geïnteresseerd in een van deze populaire activatieprogramma\'s?';
	@override String get activitiesFooter => '(Meer opties vind je in de Instellingen)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Gegevens & privacy';
	@override String get consentUsageBody => 'Om de app te verbeteren willen we prestatie-, crash- en gebruiksgegevens verzamelen.';
	@override String get consentUsageLabel => 'Deel app-gebruiksgegevens';
	@override String get consentOperationBody => 'Sommige functies kunnen je activatiegegevens met andere gebruikers delen. Je kunt je op elk moment afmelden.';
	@override String get consentOperationLabel => 'Deel activatiegegevens';
	@override String get finishingSetup => 'Installatie afronden — referentiegegevens downloaden…';
}

// Path: startScreen
class _Translations$startScreen$nl extends Translations$startScreen$en {
	_Translations$startScreen$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get credits => 'door KI2D en vrienden';
}

// Path: testerOverlay
class _Translations$testerOverlay$nl extends Translations$testerOverlay$en {
	_Translations$testerOverlay$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get tape => 'LET OP: IN AANBOUW';
	@override String get warningTitle => 'Aan deze app wordt nog gewerkt';
	@override String get warningBody => 'De meeste functies hebben een oneffen ondergrond en overal liggen struikelgevaren. Kijk regelmatig of er updates zijn.';
	@override String whatsNew({required Object build}) => 'Nieuw in build ${build}';
	@override String get thanks => 'Bedankt dat je je logboek op het spel zet om ons te helpen deze app beter te maken!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$nl extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Activiteiten';
	@override String get categoryContest => 'Contests';
	@override String get categoryLookup => 'Roepnaam opzoeken';
	@override String get categorySpots => 'Spotbronnen';
	@override String get categoryDashboard => 'Dashboardpanelen';
	@override String get categoryOther => 'Andere extensies';
	@override String get searchHint => 'Extensies zoeken';
	@override String get applying => 'Extensiewijzigingen activeren, dit kan even duren…';
	@override String get noMatches => 'Geen extensies gevonden';
	@override String get installFromFile => 'Installeren uit bestand…';
	@override String installVersion({required Object version}) => 'Versie ${version}';
	@override String get canReach => 'Deze extensie kan contact maken met';
	@override String canHoldConnection({required Object host}) => '${host}, via een live verbinding';
	@override String get canHoldLocalConnection => 'Apparaten op je lokale netwerk, via een live verbinding';
	@override String get canUseLocation => 'Je locatie';
	@override String get canReadRadio => 'Je radio, om frequentie en mode uit te lezen';
	@override String get canControlRadio => 'Je radio, om hem te bedienen en ermee te zenden — afstemmen, vermogen, CW, spraakgeheugens en PTT';
	@override String get canSetUserAgent => 'Zich bij servers onder eigen naam identificeren';
	@override String get noCapabilities => 'Ze vraagt niets buiten de app.';
	@override String get sandboxNote => 'Extensies draaien in een sandbox: geen toegang tot je bestanden en geen netwerk buiten wat hier staat.';
	@override String get installAction => 'Installeren';
	@override String get updateAction => 'Bijwerken';
	@override String get installFailed => 'Die extensie kon niet worden geïnstalleerd';
	@override String get installedBadge => 'Geïnstalleerd';
	@override String get uninstallAction => 'Verwijderen';
	@override String uninstallTitle({required Object name}) => '${name} verwijderen?';
	@override String get uninstallBody => 'Deze extensie en haar instellingen worden verwijderd. Je logboeken blijven onaangetast.';
	@override String installedMessage({required Object name}) => '${name} geïnstalleerd';
	@override String get installDownloading => 'Downloaden…';
	@override String get installWaiting => 'Wachten op installatie…';
	@override String get installInstalling => 'Installeren…';
	@override String get installAwaitingApproval => 'Wachten op je goedkeuring…';
	@override String installAlreadyRunning({required Object name}) => '${name} wordt al geïnstalleerd.';
	@override String updatedTo({required Object version}) => 'Bijgewerkt naar ${version}';
	@override String installIncomplete({required Object name}) => 'Installatie van ${name} is niet voltooid. Mogelijk moet je hem opnieuw installeren.';
	@override String uninstallFailed({required Object name}) => 'Kon ${name} niet verwijderen';
	@override String installedFrom({required Object source}) => 'Gedownload van ${source}';
	@override String get dropHint => 'Sleep een .h2kext-extensie hierheen om te installeren';
	@override String get dropOneOnly => 'Sleep één extensie tegelijk.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} gaf ${status} terug voor die extensie.';
	@override String get downloadTooLarge => 'Die download is veel te groot voor een extensie.';
	@override String get downloadNotSecure => 'Die download werd doorgestuurd naar een onveilige locatie.';
	@override String get catalogSection => 'Catalogus';
	@override String get catalogLoading => 'Catalogus laden…';
	@override String get catalogUnreachable => 'Catalogus onbereikbaar';
	@override String get builtIn => 'Ingebouwd';
	@override String get updateAvailableBadge => 'Update beschikbaar';
	@override String get updatesAvailableTitle => 'Extensie-updates';
	@override String updateAvailableFor({required Object name}) => 'Er is een update beschikbaar voor ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} en ${count} andere moeten worden bijgewerkt.';
	@override String updatesAvailableFor({required Object names}) => '${names} moeten worden bijgewerkt.';
	@override String get pendingUpdatesSection => 'Wachtende updates';
	@override String get updateAllAction => 'Alles bijwerken';
	@override String get updatesUnderWay => 'Die updates zijn al bezig.';
	@override String get updatesNothingLeft => 'Je extensies zijn up-to-date.';
	@override String get updatesNoticeAction => 'Meer info';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} extensie bijwerken?',
		other: '${count} extensies bijwerken?',
	);
	@override String get upgradeDoneTitle => 'Je extensies zijn klaar';
	@override String get upgradeDoneBody => 'Ze komen nu uit de Ham2K-extensiecatalogus en kunnen dus worden bijgewerkt zonder op een nieuwe versie van de app te wachten.';
	@override String upgradeDoneUnserved({required Object names}) => 'Niet bijgewerkt: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Starten niet: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Ze zijn nog geïnstalleerd en gemarkeerd in Instellingen › Extensies — daar bijwerken brengt ze terug.';
	@override String get upgradeDoneUnservedHint => 'De catalogus heeft hiervoor geen directe vervanging; zoek daar naar extensies die dekken wat je gebruikte.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'State Parks-evenementen';
	@override String upgradeDoneMissing({required Object count}) => '${count} van je extensies zijn nog niet binnen. Ze worden gedownload zodra de extensiecatalogus weer bereikbaar is.';
	@override String get runtimeDeadBody => 'Je extensies wilden niet starten. Herstart de app om ze terug te krijgen.';
	@override String get refusedTitle => 'Sommige extensies wilden niet starten';
	@override String get upgradeBusyTitle => 'Nog bezig met instellen';
	@override String get upgradeRuntimeDeadTitle => 'Je extensies draaien niet';
	@override String get restoreTitle => 'Sommige van je extensies ontbreken';
	@override String get restoreBody => 'Deze extensies die je hebt geïnstalleerd staan niet op dit apparaat. We kunnen ze opnieuw downloaden uit de Ham2K-extensiecatalogus:';
	@override String get restoreFromFile => 'Geïnstalleerd uit een bestand. Installeer deze opnieuw uit hun bestanden, of vergeet ze:';
	@override String get restoreOtherCatalog => 'Geïnstalleerd uit een andere extensiecatalogus, dus hier niet beschikbaar:';
	@override String get restoreForget => 'Vergeten';
	@override String get restoreInstall => 'Installeren';
	@override String get restoreLater => 'Later';
	@override String get restoreInstalling => 'Je extensies installeren…';
	@override String get restoreDoneTitle => 'Je extensies zijn terug';
	@override String restoreDoneBody({required Object names}) => 'Opnieuw geïnstalleerd: ${names}.';
	@override String get restorePartialTitle => 'Sommige extensies konden niet worden geïnstalleerd';
	@override String restoreFailed({required Object names}) => 'Kon niet installeren: ${names}. We bieden ze opnieuw aan als je de app weer opent.';
	@override String get restoreBusyBody => 'De app is nog bezig je extensies in te stellen. We bieden deze opnieuw aan als je de app weer opent.';
	@override String get restoreRuntimeDeadBody => 'We hebben ze opnieuw geïnstalleerd, maar je extensies wilden niet starten. Herstart de app om ze terug te krijgen.';
	@override String revokedTitle({required Object name}) => '${name} is ingetrokken';
	@override String get revokedBody => 'De catalogus heeft deze versie ingetrokken, dus ze is uitgeschakeld.';
	@override String get downloadHashMismatch => 'Die download is niet de extensie die de catalogus beschreef.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'De catalogus heeft geen versie ${version} van ${key}.';
	@override String get catalogLinkUnknown => 'Die cataloguslink verwijst niet naar een extensieversie.';
	@override String catalogNoRelease({required Object key}) => 'De catalogus heeft geen release van ${key} op dat kanaal.';
	@override String get installFromLink => 'Installeren via link';
	@override String get unstableReleaseWarning => 'Dit is een onstabiele release die de uitgever nog niet af noemt. Ze kan zich vreemd gedragen en blijft onstabiele updates ontvangen.';
	@override String get bleedingReleaseWarning => 'Dit is een bleeding-edge release: werk in uitvoering dat kan breken of zijn instellingen kan verliezen. Ze blijft bleeding-edge updates ontvangen.';
	@override String get channelUnstable => 'Onstabiel';
	@override String get channelBleeding => 'Bleeding';
	@override String get followsUnstable => 'Ontvangt onstabiele en stabiele releases';
	@override String get followsBleeding => 'Ontvangt bleeding-edge, onstabiele en stabiele releases';
	@override String get followStableAction => 'Alleen stabiele releases volgen';
	@override String get revokedBadge => 'Ingetrokken';
	@override String get refusedBadge => 'Niet geladen';
	@override String get downloadNotHttps => 'Die download gaat niet via een beveiligde verbinding.';
	@override String downloadUnreachable({required Object source}) => '${source} was niet bereikbaar voor die extensie.';
	@override String get detailsAction => 'Details';
	@override String get installedFromFile => 'Geïnstalleerd uit een bestand';
	@override String get detailsWhatItDoes => 'Biedt ondersteuning voor';
	@override String get installedPreloaded => 'Voorgeïnstalleerd';
	@override String get hookAccount => 'Accountaanmelding';
	@override String get hookCallNotes => 'Roepnaamnotities';
	@override String get hookDataFile => 'Offline gegevens';
	@override String get hookExport => 'Exporteren';
	@override String get hookLookup => 'Roepnaam opzoeken';
	@override String get hookScoring => 'Puntentelling';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => '${program} jagen';
	@override String hookActivating({required Object program}) => '${program} activeren';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '… en ${count} andere extensie',
		other: '… en ${count} andere extensies',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} extensie beschikbaar',
		other: '${count} extensies beschikbaar',
	);
}

// Path: home
class _Translations$home$nl extends Translations$home$en {
	_Translations$home$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portable Logger';
	@override String get newOperation => 'Nieuwe activatie';
	@override String get stationCallsign => 'Station roepnaam';
	@override String get titleOptional => 'Titel (optioneel)';
	@override String get emptyList => 'Nog geen activaties. Maak er een aan om te beginnen met loggen.';
	@override String get quickLookup => 'Snel opzoeken';
	@override late final _Translations$home$nav$nl nav = _Translations$home$nav$nl._(_root);
	@override late final _Translations$home$panels$nl panels = _Translations$home$panels$nl._(_root);
	@override String get toggleNav => 'Navigatielabels tonen of verbergen';
	@override late final _Translations$home$logs$nl logs = _Translations$home$logs$nl._(_root);
}

// Path: chase
class _Translations$chase$nl extends Translations$chase$en {
	_Translations$chase$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'jaagt op';
	@override String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} & meer';
	@override late final _Translations$chase$station$nl station = _Translations$chase$station$nl._(_root);
	@override late final _Translations$chase$periodInline$nl periodInline = _Translations$chase$periodInline$nl._(_root);
	@override late final _Translations$chase$periodStats$nl periodStats = _Translations$chase$periodStats$nl._(_root);
	@override late final _Translations$chase$period$nl period = _Translations$chase$period$nl._(_root);
	@override late final _Translations$chase$goals$nl goals = _Translations$chase$goals$nl._(_root);
	@override late final _Translations$chase$panels$nl panels = _Translations$chase$panels$nl._(_root);
}

// Path: dialogs
class _Translations$dialogs$nl extends Translations$dialogs$en {
	_Translations$dialogs$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Activatiegegevens';
	@override String get activities => 'Activiteiten';
	@override String get stationCallsign => 'Station roepnaam';
	@override String get multiStationIdentifier => 'Multi-station identificatie (alleen cijfers)';
	@override String get notes => 'Notities';
	@override String get deleteOperationTitle => 'Activatie verwijderen';
	@override String get purgeTestsTitle => 'Testactivaties opruimen';
	@override String get purgeTestsBody => 'Dit verwijdert deze testactivaties en hun QSO\'s definitief. Dit kan niet ongedaan worden gemaakt.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Plus ${count} test-QSO dat bij geen enkele activatie hoort.',
		other: 'Plus ${count} test-QSO\'s die bij geen enkele activatie horen.',
	);
	@override String get purgeTestsAction => 'Opruimen';
	@override String get syncAllTitle => 'Het logboek van dit apparaat vervangen?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL maakt een back-up van ${qsos} op dit apparaat en wist ze, en downloadt daarna het logboek van het account opnieuw van de server. De back-up blijft in de database van dit apparaat.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${n} QSO is nog niet gesynchroniseerd — de server heeft het nooit ontvangen en het komt NIET terug.',
		other: '${n} QSO\'s zijn nog niet gesynchroniseerd — de server heeft ze nooit ontvangen en ze komen NIET terug.',
	);
	@override String get syncAllAction => 'Wissen en opnieuw synchroniseren';
	@override String get receivedPurgesTitle => 'Testactivaties elders verwijderd';
	@override String get receivedPurgesBody => 'Deze zijn op een ander apparaat als testactivaties verwijderd. Ook hier verwijderen? Dit verwijdert ze en hun QSO\'s definitief en kan niet ongedaan worden gemaakt.';
	@override String get receivedPurgesAction => 'Verwijderen';
	@override late final _Translations$dialogs$callChange$nl callChange = _Translations$dialogs$callChange$nl._(_root);
}

// Path: operation
class _Translations$operation$nl extends Translations$operation$en {
	_Translations$operation$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Deze activatie is verwijderd. Herstel haar om te loggen of iets te wijzigen.';
	@override late final _Translations$operation$tabs$nl tabs = _Translations$operation$tabs$nl._(_root);
	@override late final _Translations$operation$positions$nl positions = _Translations$operation$positions$nl._(_root);
	@override String get stationCallsignNone => 'Geen station roepnaam';
	@override String get titleNone => 'Geen titel';
	@override String get deleteOperation => 'Activatie verwijderen';
	@override String get loggingControlsStale => 'Activiteitsvelden zijn mogelijk verouderd — open de activatie opnieuw om ze te verversen';
	@override String get locationNone => 'Niet ingesteld';
	@override String get generalOperation => 'Algemene Activatie';
	@override String titleFor({required Object value}) => 'voor ${value}';
	@override String titleAt({required Object value}) => 'bij ${value}';
	@override String segmentNow({required Object description}) => 'Nu ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$nl menu = _Translations$operation$menu$nl._(_root);
	@override late final _Translations$operation$layout$nl layout = _Translations$operation$layout$nl._(_root);
	@override late final _Translations$operation$export$nl export = _Translations$operation$export$nl._(_root);
	@override late final _Translations$operation$spots$nl spots = _Translations$operation$spots$nl._(_root);
	@override late final _Translations$operation$import$nl import = _Translations$operation$import$nl._(_root);
}

// Path: map
class _Translations$map$nl extends Translations$map$en {
	_Translations$map$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$nl outlineIssue = _Translations$map$outlineIssue$nl._(_root);
	@override String get outlinesDisclaimer => 'Omtrekken zijn alleen ter referentie. Doe je eigen onderzoek!';
	@override String outlinesCredit({required Object sources}) => 'Omtrekken: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Grenzen: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Voorzieningen: ${sources}';
	@override String get fullCredits => 'Volledige bronvermelding';
	@override String get fewerCredits => 'Minder bronnen';
	@override String get emptyState => 'Nog geen QSO-locaties.\nQSO\'s met een grid square, staat of land verschijnen hier.';
	@override String get unavailable => 'De kaart is nu niet beschikbaar.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plat';
	@override String get globe => 'Globe';
	@override String get zoomIn => 'Inzoomen';
	@override String get zoomOut => 'Uitzoomen';
	@override late final _Translations$map$postcard$nl postcard = _Translations$map$postcard$nl._(_root);
}

// Path: mapsView
class _Translations$mapsView$nl extends Translations$mapsView$en {
	_Translations$mapsView$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kaarten';
	@override String get searchHint => 'Zoek parken, toppen en meer';
	@override String get activities => 'Activiteiten';
	@override String get layers => 'Lagen';
	@override String get baseMap => 'Basiskaart';
	@override String get satellite => 'Satelliet (Esri)';
	@override String get facilities => 'Parkvoorzieningen';
	@override String get boundaries => 'Grenzen';
	@override String get currentLocation => 'Huidige locatie';
	@override String noMatches({required Object text}) => 'Niets gevonden voor “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} referentie bij ${where}',
		other: '${count} referenties bij ${where}',
	);
	@override String get startOperation => 'Start een activatie met deze referenties';
}

// Path: activitiesView
class _Translations$activitiesView$nl extends Translations$activitiesView$en {
	_Translations$activitiesView$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activiteiten';
	@override String get activitiesCountZero => 'Geen activiteiten geselecteerd';
	@override String get activitiesCountOne => '1 activiteit';
	@override String activitiesCountOther({required Object count}) => '${count} activiteiten';
	@override String get empty => 'Nog geen activiteiten — gebruik Suggesties & zoeken hieronder om er een toe te voegen';
	@override String get removeActivity => 'Verwijderen';
	@override String openReferenceLink({required Object name}) => '${name} openen';
	@override String get editActivity => 'Activiteit bewerken';
	@override String get manageExtensions => 'Extensies beheren';
	@override String get manage => 'Beheren';
	@override String activitiesTitle1({required Object first}) => 'Activiteitstypen: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Activiteitstypen: ${first} en ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Activiteitstypen: ${first}, ${second} en ${more} meer';
	@override String get reference => 'Referentie';
	@override String get invalidReference => 'Ongeldig';
	@override String get duplicateReference => 'Al toegevoegd';
	@override String get searchHint => 'Zoek op naam, referentie of iets anders…';
	@override String get noSuggestions => 'Geen resultaten';
	@override String get noSuggestionsHint => 'Zoek hierboven op naam of nummer van de referentie';
	@override String get noSuggestionsExample => '(bijvoorbeeld \'trail\' of \'4556\')';
	@override String get allOptions => 'Activiteitstypen';
	@override String get determiningLocation => 'Huidige locatie bepalen…\nWachten op GPS-fix om referenties in de buurt te vinden';
	@override String get locationUnavailableTitle => 'Locatiegegevens niet beschikbaar';
	@override String get locationDeniedTitle => 'Locatietoestemming geweigerd';
	@override String get locationBlockedTitle => 'Locatietoestemming geblokkeerd';
	@override String get noNearbyReason => 'Kan referenties in de buurt niet bepalen';
	@override String locationManualHint({required Object icon}) => 'Tik op ${icon} om je locatie handmatig in te voeren,\nof zoek referenties gewoon op naam';
	@override String get locationGrantAction => 'Locatietoegang toestaan';
	@override String get locationSettingsAction => 'Instellingen openen';
	@override String get locationSettingsUnavailable => 'Sta locatietoegang toe in je systeeminstellingen';
	@override String get locationGrantRefused => 'Nog steeds geen locatie — het systeem weigerde opnieuw';
	@override String get searchUnavailableTitle => 'Activiteiten zoeken niet beschikbaar';
	@override String get searchUnavailableReason => 'Geen activiteitsextensie kon de zoekopdracht uitvoeren. Probeer het zo opnieuw.';
	@override String get emptySheet => 'Gebruik suggesties & zoeken hieronder om er een toe te voegen';
	@override String get exports => 'Exports';
	@override String get exportLogs => 'Logboeken exporteren';
	@override String get tools => 'Gereedschap';
	@override String get toolsTitle => 'Activatiegereedschap';
	@override String get operationDetails => 'Activatiegegevens';
	@override String get share => 'Delen';
	@override String get archive => 'Archiveren';
	@override String get deleteOperation => 'Activatie verwijderen';
	@override String get undeleteOperation => 'Activatie herstellen';
	@override String get alreadySelected => 'Al geselecteerd';
	@override String get selected => 'Geselecteerd';
	@override String pickPosition({required Object index, required Object count}) => '${index} van ${count}';
	@override String get previousPick => 'Vorig resultaat';
	@override String get nextPick => 'Volgend resultaat';
	@override String get retiredReference => 'Vervallen';
	@override String enableExtension({required Object name}) => '${name} inschakelen';
	@override String get enableExtensionHint => 'Deze extensie past bij je zoekopdracht, maar is momenteel niet ingeschakeld';
	@override String get enableExtensionForRefHint => 'Deze extensie behandelt een van de referenties van deze activatie, maar is momenteel niet ingeschakeld';
	@override String extensionNotRunning({required Object name}) => '${name} draait niet';
	@override String get extensionNotRunningHint => 'Deze extensie is uitgeschakeld; open Extensie-instellingen voor meer info';
	@override String installExtension({required Object name}) => '${name} installeren';
	@override String get installExtensionHint => 'Deze extensie past bij je zoekopdracht, maar is niet geïnstalleerd';
	@override String get onlyCatalogMatches => 'Geen resultaten\nSommige extensies in de catalogus hebben mogelijk resultaten.\nInstalleer ze hieronder bij Activiteitstypen.';
	@override String get setupUnavailable => 'Kon de instellingen van deze activiteit niet laden — probeer het opnieuw via Beheren';
	@override String get controlsUnavailableTitle => 'Activiteitsbediening niet beschikbaar';
	@override String get controlsUnavailableReason => 'Je referenties zijn veilig, maar ze bewerken is nu niet mogelijk.';
	@override String get controlsUnavailableRetry => 'Opnieuw proberen';
	@override String get onlyDisabledMatches => 'Geen resultaten\nSommige beschikbare extensies hebben mogelijk resultaten.\nSchakel ze hieronder in bij Activiteitstypen.';
	@override String get onlyNotRunningMatches => 'Geen resultaten\nSommige extensies die mogelijk resultaten hebben draaien niet.\nZie Activiteitstypen hieronder.';
	@override String get mapToggle => 'Kaart';
	@override String get searchToggle => 'Zoeken';
	@override String get addToOperation => 'Toevoegen aan activatie';
	@override String get addToOperationShort => 'Toevoegen';
	@override String get mapEmptyState => 'Geen resultaten om op de kaart te tonen';
	@override String get mapEmptyStateHint => 'Ga terug naar de lijst, of zoek iets anders';
	@override String get imports => 'Imports';
}

// Path: loggingControls
class _Translations$loggingControls$nl extends Translations$loggingControls$en {
	_Translations$loggingControls$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Tijd (UTC)';
	@override String get date => 'Datum';
	@override String get now => 'Nu';
	@override String get frequency => 'Frequentie';
	@override String get mode => 'Mode';
	@override String get theirCall => 'Hun roepnaam';
	@override String get noteField => 'Notitie';
	@override String get todoField => 'To-do';
	@override String get sent => 'Verzonden';
	@override String get rcvd => 'Ontvangen';
	@override String get more => 'Meer';
	@override String get revert => 'Herstellen';
	@override String get undoDelete => 'Verwijderen ongedaan maken';
	@override String get restore => 'Terugzetten';
	@override String get wipe => 'Wissen';
	@override String get undo => 'Ongedaan maken';
	@override String get pendingDeleteTapWarning => 'Tik nog een keer op de prullenbak om dit QSO te verwijderen';
	@override String get pendingDeleteClickWarning => 'Klik nog een keer op de prullenbak om dit QSO te verwijderen';
	@override String get deletedQsoWarning => 'Verwijderd QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Tik nog een keer op de prullenbak om deze ${kind} te verwijderen';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Klik nog een keer op de prullenbak om deze ${kind} te verwijderen';
	@override String deletedEventWarning({required Object kind}) => '${kind} verwijderd';
	@override String get timeControl => 'Tijd';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Vermogen';
	@override String get notesControl => 'Notities';
	@override String get power => 'Vermogen';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Logbediening';
	@override String get spottingControl => 'Spotten';
	@override String get spottingSelfControl => 'Zelfspotten';
	@override String spotSelfAt({required Object freq}) => 'Zelfspot op ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} op ${freq}';
	@override String spotTooLate({required Object call}) => 'Te laat om ${call} te spotten';
	@override String get spotNoFreq => 'Stel eerst een frequentie in om te spotten';
	@override String get spotComment => 'Opmerking';
	@override String get bandOrFreqRequired => 'Stel een frequentie of band in voordat je logt';
	@override String get missingBand => 'Geen band';
	@override String get missingMode => 'Geen mode';
	@override String saveFailed({required Object error}) => 'Kon niet opslaan: ${error}';
	@override String deleteFailed({required Object error}) => 'Kon niet verwijderen: ${error}';
	@override late final _Translations$loggingControls$info$nl info = _Translations$loggingControls$info$nl._(_root);
}

// Path: formChrome
class _Translations$formChrome$nl extends Translations$formChrome$en {
	_Translations$formChrome$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(zonder titel)';
	@override String get showMore => 'Meer tonen';
	@override String get showAll => 'Alles tonen';
	@override String get showFewer => 'Minder tonen';
	@override String get defaults => 'Standaardwaarden';
	@override String get search => 'Zoeken';
	@override String get clear => 'Wissen';
	@override String get openPage => 'Pagina openen';
	@override String get connected => 'Verbonden';
	@override String get notConnected => 'Niet verbonden';
	@override String get manage => 'Beheren';
	@override String get connect => 'Verbinden';
	@override String get formTitle => 'Formulier';
	@override String addItem({required Object label}) => '${label} toevoegen';
	@override String editItem({required Object label}) => '${label} bewerken';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => '${shown} van ${total} getoond (${selected} geselecteerd)';
	@override String validationError({required Object error}) => 'Validatiefout: ${error}';
	@override String transformationError({required Object error}) => 'Transformatiefout: ${error}';
	@override String actionError({required Object error}) => 'Fout: ${error}';
	@override String get removeItem => 'Verwijderen';
	@override String get storageUnavailable => 'Aanmeldgegevens niet beschikbaar';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$nl extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSO bewerken';
	@override String get operatorCall => 'Operator';
	@override String get position => 'Positie';
	@override String get theirName => 'Naam';
	@override String get theirGrid => 'Grid';
	@override String get theirState => 'Staat';
	@override String get band => 'Band';
	@override String get notes => 'Notities';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Hun info';
	@override String get sectionOur => 'Onze info';
	@override String get sectionNotes => 'Notities';
	@override String get theirCity => 'Stad';
	@override String get theirCounty => 'County';
	@override String get theirEntity => 'Entiteit';
	@override String get theirCqZone => 'CQ-zone';
	@override String get theirItuZone => 'ITU-zone';
	@override String get theirArrlSection => 'ARRL Sectie';
	@override String get theirLat => 'Breedtegraad';
	@override String get theirLon => 'Lengtegraad';
	@override String get theirPower => 'Hun vermogen';
}

// Path: qsoList
class _Translations$qsoList$nl extends Translations$qsoList$en {
	_Translations$qsoList$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nog geen QSO\'s — werk iemand!';
	@override String get bandOrModeWarning => 'Controleer of je band en mode kloppen';
	@override String get today => 'Vandaag';
	@override String get yesterday => 'Gisteren';
	@override String get tomorrow => 'Morgen';
}

// Path: loggingPanel
class _Translations$loggingPanel$nl extends Translations$loggingPanel$en {
	_Translations$loggingPanel$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Activatie statistieken';
	@override String get scoring => 'Puntentelling';
	@override String get dxccEntities => 'DXCC-entiteiten';
	@override String get statesWorked => 'Staten';
	@override String get provincesWorked => 'Provincies';
	@override String get duplicates => 'Dubbels';
}

// Path: callInfo
class _Translations$callInfo$nl extends Translations$callInfo$en {
	_Translations$callInfo$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Afbeelding tonen';
	@override String get imageUnavailable => 'Foto niet beschikbaar';
	@override String get photo => 'Foto';
	@override String get notes => 'Notities';
	@override String distanceTo({required Object distance}) => '${distance} naar';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) naar';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) naar';
	@override String distanceAway({required Object distance}) => '${distance} verwijderd';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verwijderd';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verwijderd';
	@override String get thisOpCountOne => '1 QSO in deze activatie';
	@override String thisOpCountOther({required Object count}) => '${count} QSO\'s in deze activatie';
	@override String get otherOpsCountOne => '1 QSO in andere activaties';
	@override String otherOpsCountOther({required Object count}) => '${count} QSO\'s in andere activaties';
	@override String andMore({required Object count}) => '… en ${count} meer';
	@override String withCall({required Object call}) => 'met ${call}';
	@override String fromOperation({required Object where}) => 'van ${where}';
	@override late final _Translations$callInfo$history$nl history = _Translations$callInfo$history$nl._(_root);
}

// Path: settings
class _Translations$settings$nl extends Translations$settings$en {
	_Translations$settings$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Instellingen';
	@override String get language => 'Taal';
	@override String languageSystem({required Object language}) => 'Systeeminstellingen volgen (${language})';
	@override late final _Translations$settings$theme$nl theme = _Translations$settings$theme$nl._(_root);
	@override late final _Translations$settings$themeDescription$nl themeDescription = _Translations$settings$themeDescription$nl._(_root);
	@override String get fontScale => 'Lettergrootte';
	@override late final _Translations$settings$fontScaleOpts$nl fontScaleOpts = _Translations$settings$fontScaleOpts$nl._(_root);
	@override late final _Translations$settings$keepDeviceAwake$nl keepDeviceAwake = _Translations$settings$keepDeviceAwake$nl._(_root);
	@override String get layoutDensity => 'Indelingsdichtheid';
	@override late final _Translations$settings$layoutDensityOpts$nl layoutDensityOpts = _Translations$settings$layoutDensityOpts$nl._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'het venster is te laag, ${effective} wordt gebruikt';
	@override String get layoutDensityAtLimit => 'maximaal';
	@override String get distanceUnits => 'Afstandseenheden';
	@override late final _Translations$settings$distanceUnitsOpts$nl distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$nl._(_root);
	@override String get userInterface => 'Gebruikersinterface';
	@override late final _Translations$settings$logging$nl logging = _Translations$settings$logging$nl._(_root);
	@override late final _Translations$settings$catServer$nl catServer = _Translations$settings$catServer$nl._(_root);
	@override late final _Translations$settings$radio$nl radio = _Translations$settings$radio$nl._(_root);
	@override late final _Translations$settings$help$nl help = _Translations$settings$help$nl._(_root);
	@override late final _Translations$settings$exports$nl exports = _Translations$settings$exports$nl._(_root);
	@override late final _Translations$settings$map$nl map = _Translations$settings$map$nl._(_root);
	@override late final _Translations$settings$privacy$nl privacy = _Translations$settings$privacy$nl._(_root);
	@override String get operatorCall => 'Roepnaam van de operator';
	@override late final _Translations$settings$sync$nl sync = _Translations$settings$sync$nl._(_root);
	@override late final _Translations$settings$peers$nl peers = _Translations$settings$peers$nl._(_root);
	@override String get developerMode => 'Ontwikkelaarsmodus';
	@override late final _Translations$settings$syncPanel$nl syncPanel = _Translations$settings$syncPanel$nl._(_root);
	@override late final _Translations$settings$accounts$nl accounts = _Translations$settings$accounts$nl._(_root);
	@override late final _Translations$settings$station$nl station = _Translations$settings$station$nl._(_root);
	@override late final _Translations$settings$offlineData$nl offlineData = _Translations$settings$offlineData$nl._(_root);
	@override late final _Translations$settings$profiles$nl profiles = _Translations$settings$profiles$nl._(_root);
	@override late final _Translations$settings$search$nl search = _Translations$settings$search$nl._(_root);
	@override late final _Translations$settings$developer$nl developer = _Translations$settings$developer$nl._(_root);
	@override late final _Translations$settings$about$nl about = _Translations$settings$about$nl._(_root);
	@override late final _Translations$settings$panels$nl panels = _Translations$settings$panels$nl._(_root);
	@override String get showMoreSettings => 'Meer instellingen tonen';
	@override String get numberFormat => 'Getalnotatie';
	@override late final _Translations$settings$numberFormatOpts$nl numberFormatOpts = _Translations$settings$numberFormatOpts$nl._(_root);
	@override late final _Translations$settings$numberFormatDescription$nl numberFormatDescription = _Translations$settings$numberFormatDescription$nl._(_root);
	@override late final _Translations$settings$numberFormatSeparators$nl numberFormatSeparators = _Translations$settings$numberFormatSeparators$nl._(_root);
	@override String get gridPrecision => 'Gridprecisie';
	@override late final _Translations$settings$gridPrecisionOpts$nl gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$nl._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$nl gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$nl._(_root);
}

// Path: commands
class _Translations$commands$nl extends Translations$commands$en {
	_Translations$commands$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Schakel eerst synchronisatie in bij Instellingen.';
	@override String get fullResyncStarted => 'Volledige hersynchronisatie gestart — lokale gegevens zijn eerst geback-upt.';
	@override String noDataFilesMatched({required Object target}) => 'Geen gegevensbestanden gevonden voor "${target}".';
	@override String reloadFailed({required Object error}) => 'Herladen mislukt: ${error}';
	@override String get reloadingAll => 'Alle gegevensbestanden herladen…';
	@override String reloadingTarget({required Object target}) => 'Gegevensbestanden van ${target} herladen…';
	@override String unknownExperiment({required Object token}) => 'Onbekend experiment "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} ingeschakeld';
	@override String experimentDisabled({required Object name}) => '${name} uitgeschakeld';
	@override String get sentryTestSent => 'Testfoutrapport naar Sentry verzonden';
	@override String get sentryTestLocalOnly => 'Sentry is uitgeschakeld in deze build — testfout alleen lokaal gelogd';
	@override String get noOperationOpen => 'Dat commando vereist een geopende activatie';
	@override String unknownSegmentKind({required Object kind}) => 'Weet niet hoe een \'${kind}\' te markeren';
	@override String get operationAlreadyStarted => 'Deze activatie heeft al een startmarkering';
	@override String get couldNotOpenLocation => 'Pauze toegevoegd, maar kon het locatiescherm niet openen';
	@override String get noTestOperations => 'Geen testactivaties om op te ruimen';
	@override String get purgeTestsUnavailable => 'PURGETESTS moet een bevestigingsvenster tonen, en dat is hier niet beschikbaar';
	@override String get syncAllUnavailable => 'SYNCALL moet een bevestigingsvenster tonen, en dat is hier niet beschikbaar';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} testactivatie opgeruimd',
		other: '${count} testactivaties opgeruimd',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '${purged} van ${total} testactivaties opgeruimd — de rest mislukte; probeer PURGETESTS opnieuw';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} test-QSO zonder activatie opgeruimd',
		other: '${count} test-QSO\'s zonder activatie opgeruimd',
	);
	@override String get purgeTestsContactsFailed => 'De testactivaties zijn opgeruimd, maar de test-QSO\'s zonder activatie mislukten; probeer PURGETESTS opnieuw';
	@override String get purgeTestsNothingToDo => 'Er is niets opgeruimd';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '${removed} van ${total} testactivaties verwijderd — de rest mislukte; probeer Bekijken opnieuw';
	@override String get receivedPurgesFailed => 'Kon die testactivaties niet verwijderen — probeer Bekijken opnieuw';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} testactivatie is op een ander apparaat verwijderd',
		other: '${count} testactivaties zijn op een ander apparaat verwijderd',
	);
	@override String get receivedPurgesReview => 'Bekijken';
	@override String get settingOn => 'Aan';
	@override String get settingOff => 'Uit';
	@override String get settingEmpty => '(leeg)';
	@override String get settingSecretSet => '(ingesteld)';
	@override String get settingSecretUnset => '(niet ingesteld)';
	@override String settingSelectedCount({required Object count}) => '${count} geselecteerd';
	@override String get settingExpectsOnOff => 'aan of uit';
	@override String settingExpectsOneOf({required Object choices}) => 'een van: ${choices}';
	@override String get settingExpectsNumber => 'een getal';
	@override String settingVanished({required Object label}) => '“${label}” is niet meer beschikbaar';
	@override String get noCwKeyer => 'Geen verbonden radio kan CW keyen';
	@override String get noKeyer => 'Geen verbonden radio kan CW keyen of spraakgeheugens afspelen';
	@override String get keyerNeedsOperation => 'Open een activatie om de CW-keyer te gebruiken';
	@override String get keyerExperimentOff => 'CW-keying staat uit — zet het aan met EXP KEYER';
	@override String get esmExperimentOff => 'Enter verstuurt berichten staat uit — zet het aan met EXP ESM';
	@override String cwSending({required Object text}) => 'CW verzenden: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW-bericht F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW-bericht F${n} is niet verzonden: de extensies zijn nog niet klaar';
	@override String settingNotStored({required Object label}) => '“${label}” accepteerde die waarde niet';
}

// Path: commandDialog
class _Translations$commandDialog$nl extends Translations$commandDialog$en {
	_Translations$commandDialog$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Zoek roepnamen of typ een commando';
	@override String noResults({required Object text}) => 'Niets gevonden voor “${text}”';
	@override String get sectionCommands => 'Commando\'s';
	@override String get sectionGoTo => 'Ga naar';
	@override String get sectionOperations => 'Activaties';
	@override String get goHome => 'Start';
	@override String get goSettings => 'Instellingen';
	@override String get goNewOperation => 'Nieuwe activatie';
	@override String runTyped({required Object text}) => '“${text}” uitvoeren';
	@override String get sectionSuggestions => 'Probeer';
	@override String get lookingUp => 'Roepnaam opzoeken…';
	@override String get blockedByPane => 'Kan geen commando\'s gebruiken zolang een paneel of venster open is';
}

// Path: expiredBuild
class _Translations$expiredBuild$nl extends Translations$expiredBuild$en {
	_Translations$expiredBuild$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Deze build is verlopen';
	@override String get body => 'Ga naar ham2k.com en haal een nieuwere versie.';
	@override String get visit => 'Naar ham2k.com';
	@override String get dismiss => 'Toch doorgaan';
}

// Path: staleness
class _Translations$staleness$nl extends Translations$staleness$en {
	_Translations$staleness$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Er wacht een belangrijke update';
	@override String get codePushFloorBody => 'Deze versie bevat een fix die je nog niet hebt.';
	@override String get restartToApply => 'Herstart de app om hem toe te passen.';
	@override String get quitAndReopen => 'Sluit de app af en open hem opnieuw om hem toe te passen.';
	@override String get reopenToApply => 'Sluit de app en open hem opnieuw om hem toe te passen.';
	@override String get ignoreForNow => 'Nu negeren';
}

// Path: spotting
class _Translations$spotting$nl extends Translations$spotting$en {
	_Translations$spotting$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Nog geen QSO gelogd om te spotten.';
	@override String get setFrequencyFirst => 'Stel eerst een frequentie in.';
	@override String get nothingToSpot => 'Niets te spotten — geen extensie biedt hier spotten aan.';
	@override String spotFailed({required Object source, required Object message}) => '${source} mislukt: ${message}';
	@override String get unknownError => 'onbekende fout';
	@override String get notSent => 'Spot niet verzonden.';
	@override String get notRefreshedOffline => 'Geen verbinding — spots zijn niet ververst';
}

// Path: dataFiles
class _Translations$dataFiles$nl extends Translations$dataFiles$en {
	_Translations$dataFiles$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Downloaden…';
	@override String downloadFailedTitle({required Object name}) => 'Kon ${name} niet downloaden';
	@override String get downloadFailedWebHint => 'Dit kan een netwerkprobleem zijn, of de host van deze link ondersteunt geen directe downloads vanuit een webbrowser. Probeer de desktop- of mobiele app, of een andere hostinglocatie.';
	@override String get downloadTimedOut => 'De server deed er te lang over om te reageren. Probeer het later opnieuw.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} reageerde met een fout (HTTP ${status}). Probeer het later opnieuw.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} kon dit bestand niet leveren (HTTP ${status}). Controleer of het adres nog klopt.';
	@override String processingFailedTitle({required Object name}) => 'Kon ${name} niet verwerken';
	@override String importTooSmall({required Object imported, required Object existing}) => 'De download had maar ${imported} van de ${existing} records op dit apparaat, dus de weggelaten records zijn behouden. Ververs hem in Instellingen › Offline gegevens om hem toch te accepteren.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} record geïmporteerd voor ${label}.',
		other: '${count} records geïmporteerd voor ${label}.',
	);
	@override String importedData({required Object label}) => 'Gegevens geïmporteerd voor ${label}.';
	@override String get cleanedUpTitle => 'Extensiegegevens opgeruimd';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Gegevens van ${count} gegevensbestand van uitgeschakelde extensies verwijderd.',
		other: 'Gegevens van ${count} gegevensbestanden van uitgeschakelde extensies verwijderd.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} records';
	@override String get definitionUnavailable => 'De bron van het bestand leverde geen definitie — de extensie is mogelijk aan het herstarten of verkeerd geconfigureerd. Probeer het zo opnieuw.';
}

// Path: updates
class _Translations$updates$nl extends Translations$updates$en {
	_Translations$updates$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Update beschikbaar';
	@override String newVersionAvailable({required Object version}) => 'Er is een nieuwe versie (${version}) beschikbaar.';
	@override String get getIt => 'Ophalen';
	@override String get ok => 'OK';
	@override String get updateReady => 'Update klaar';
	@override String get restartToApply => 'Er is een update gedownload. Herstart om hem toe te passen.';
	@override String get appliesNextLaunch => 'Er is een update gedownload. Die wordt toegepast als je de app de volgende keer opent.';
	@override String get restartNow => 'Nu herstarten';
	@override String get reloadToUpdate => 'Er is een nieuwere versie van deze pagina beschikbaar. Herlaad om hem te krijgen.';
	@override String get reloadNow => 'Nu herladen';
	@override String get checkForUpdates => 'Controleer op updates';
	@override String get checkingForUpdates => 'Controleren op updates…';
	@override String get upToDate => 'Up-to-date';
	@override String get automaticChecks => 'Automatisch controleren';
	@override String get automaticChecksDescription => 'Op de achtergrond naar nieuwe versies zoeken, vanaf de volgende keer dat je de app start';
}

// Path: extensionService
class _Translations$extensionService$nl extends Translations$extensionService$en {
	_Translations$extensionService$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Extensieomgeving niet klaar.';
	@override String testFailed({required Object error}) => 'Test mislukt: ${error}';
	@override String connectedAs({required Object identity}) => 'Verbonden als ${identity}';
	@override String get invalidFieldConfiguration => 'Ongeldige veldconfiguratie';
	@override String get invalidValue => 'Ongeldige waarde';
	@override String validationError({required Object error}) => 'Validatiefout: ${error}';
	@override String actionFailed({required Object error}) => 'Actie mislukt: ${error}';
	@override String get commandFailed => 'Het commando kon niet worden uitgevoerd';
	@override String get reportUnavailable => 'Meldingen kunnen nu niet worden verstuurd';
	@override String get stashUnavailable => 'Ham2K File Stash is nu niet bereikbaar';
	@override String timersSuspendedBudget({required Object name}) => '${name} besteedde te veel tijd in zijn timers. Ze zijn gestopt tot de extensies herstarten.';
	@override String timersSuspendedFailures({required Object name}) => 'De timers van ${name} bleven mislukken. Ze zijn gestopt tot de extensies herstarten.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} bleef hangen in een timer. De timers zijn gestopt tot de extensies herstarten.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$nl extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activatie locatie';
	@override String get selectedLocation => 'Geselecteerde locatie';
	@override String get gridSquare => 'Grid square';
	@override String get gridInvalid => 'Vereist 4, 6, 8 of 10 tekens, zoals FN31pr';
	@override String get suggestedLocations => 'Voorgestelde locaties';
	@override String get deviceGps => 'GPS van apparaat';
	@override String peerGps({required Object device}) => 'GPS van ${device}';
	@override String get locating => 'Plaatsen…';
	@override String get gpsUnavailable => 'Locatie niet beschikbaar';
	@override String get permissionDenied => 'Locatietoestemming geweigerd';
	@override String get permissionBlocked => 'Locatietoestemming geblokkeerd';
	@override String get moreDetails => 'Meer details';
	@override String get stateOrProvince => 'Staat of Provincie (optioneel)';
	@override String get controlsUnavailableTitle => 'Activiteitsbediening niet beschikbaar';
	@override String get controlsUnavailableReason => 'Deze referenties zijn nog bruikbaar; alleen hun activiteiten waren niet bereikbaar.';
	@override String get controlsUnavailableRetry => 'Opnieuw proberen';
	@override String get county => 'County (optioneel)';
}

// Path: versionLabel
class _Translations$versionLabel$nl extends Translations$versionLabel$en {
	_Translations$versionLabel$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versie ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$nl extends Translations$notices$en {
	_Translations$notices$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Nog geen mededelingen';
	@override String get webStorageInMemory => 'Deze browser kon geen permanente opslag bieden — het logboek staat alleen in het geheugen en gaat VERLOREN als dit tabblad sluit. Gebruik een recente Chrome, Firefox, Safari of Edge.';
	@override String get webStorageUnreliable => 'Deze browser gebruikt reserve-opslag die niet veilig is met meerdere tabbladen — houd één tabblad open, en laat synchronisatie aan.';
	@override String get logFromNewerBuildTitle => 'Dit logboek vereist een nieuwere versie';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Je logboek is geschreven door een nieuwere versie van HaLo (opslagversie ${storage}; deze begrijpt ${understood}), dus het kan niet worden geopend en nieuwe QSO\'s worden niet opgeslagen. Installeer de nieuwere versie opnieuw — of, als je deze build bewust draait, laat hem naar een andere gegevensmap wijzen. Het logboek staat in ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Je logboek is geschreven door een nieuwere versie van HaLo (opslagversie ${storage}; deze begrijpt ${understood}), dus het kan niet worden geopend en nieuwe QSO\'s worden niet opgeslagen. Open dit logboek in plaats daarvan met die nieuwere versie.';
	@override String get preferencesRestoredTitle => 'Instellingen hersteld uit een back-up';
	@override String get preferencesRestored => 'Het instellingenbestand kon niet worden gelezen, dus HaLo heeft de laatste goede kopie hersteld. Wat je in je vorige sessie hebt gewijzigd, moet je mogelijk opnieuw instellen. Het onleesbare bestand staat ernaast, met de naam shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Instellingen teruggezet';
	@override String get preferencesReset => 'Het instellingenbestand kon niet worden gelezen en er was geen back-up om op terug te vallen, dus HaLo is gestart met de standaardwaarden. Het onleesbare bestand staat in de gegevensmap van de app, met de naam shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} is niet automatisch verbonden';
	@override String autoConnectHeld({required Object name}) => 'HaLo reageerde niet meer de vorige keer dat het met ${name} begon te verbinden, dus deze keer is het overgeslagen om dat niet opnieuw te riskeren. Controleer of de radio aan staat en de kabel is aangesloten, en druk dan in Instellingen op Verbinden.';
}

// Path: syncAccount
class _Translations$syncAccount$nl extends Translations$syncAccount$en {
	_Translations$syncAccount$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anoniem account (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (wacht op bevestiging)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (wacht op bevestiging - #${id})';
}

// Path: deepLink
class _Translations$deepLink$nl extends Translations$deepLink$en {
	_Translations$deepLink$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Start eerst een activatie en stuur dat QSO dan opnieuw';
	@override String get waitingInOperation => 'Dat QSO wacht in de activatie achter dit scherm';
	@override String unknownActivities({required Object refs}) => 'Dit apparaat heeft geen activiteit voor ${refs}, dus die referenties zijn weggelaten';
	@override String activitiesUnavailable({required Object refs}) => 'Kon je activiteiten niet bereiken, dus ${refs} is weggelaten — probeer die link opnieuw';
}

// Path: confirmDevice
class _Translations$confirmDevice$nl extends Translations$confirmDevice$en {
	_Translations$confirmDevice$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Apparaat bevestigen';
	@override String get codePrompt => 'Voer de code in die wordt getoond op het apparaat dat zich bij dit account wil aansluiten.';
	@override String get code => 'Code';
	@override String get lookUp => 'Opzoeken';
	@override String get codeNotFound => 'Geen verzoek gevonden bij die code. Codes verlopen na 10 minuten — vraag het andere apparaat om een nieuwe.';
	@override String get linkExpired => 'Die link is verlopen. Laat het andere apparaat een nieuwe QR-code tonen.';
	@override String areYouSure({required Object device}) => '${device} aan dit account koppelen?';
	@override String get unnamedDevice => 'een naamloos apparaat';
	@override String get grantWarning => 'Het kan dan elke activatie en elk QSO in dit account lezen en wijzigen.';
	@override String get needsSyncTitle => 'Dit apparaat synchroniseert nog niet';
	@override String get needsSyncText => 'Zet synchronisatie met Ham2K Log Filer aan en koppel dit apparaat aan een account voordat het een ander apparaat kan toelaten.';
	@override String get malformedRequest => 'De synchronisatieserver stuurde een verzoek dat deze app niet kon lezen. Vraag het andere apparaat het opnieuw te proberen.';
	@override String get linkIt => 'Apparaat koppelen';
}

// Path: switchAccounts
class _Translations$switchAccounts$nl extends Translations$switchAccounts$en {
	_Translations$switchAccounts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Nog geen accountgegevens';
	@override String get currentAccount => 'Huidig account';
	@override String get otherAccounts => 'Andere accounts';
	@override String get linkToAnother => 'Koppelen aan een ander account';
	@override String get linkWithSibling => 'Koppelen met andere Ham2K-app';
	@override String get linkWithPolo => 'Koppelen met account in oudere versie';
	@override String get linkWithSiblingDescription => 'Je hebt een andere Ham2K-app geïnstalleerd. Koppel met het account dat daar in gebruik is.';
	@override String siblingPrompt({required Object app}) => 'Keur het verzoek goed in ${app} en kom dan hier terug.';
	@override String openSiblingAgain({required Object app}) => '${app} opnieuw openen';
	@override String get siblingNoGrant => 'Werkte het niet? Open het opnieuw, of ga terug en koppel op een andere manier.';
	@override String siblingOpenFailed({required Object app}) => 'Kon ${app} niet openen.';
	@override String siblingLinkRenewed({required Object app}) => 'De link was verlopen en er staat een nieuwe klaar — open ${app} opnieuw.';
	@override String get tryAgain => 'Opnieuw proberen';
	@override String get linkWithQr => 'Koppelen met een QR-code';
	@override String get linkWithQrDescription => 'Scan hem vanaf een apparaat dat het account al gebruikt';
	@override String get linkWithEmail => 'Koppelen met een e-mailadres';
	@override String get linkWithEmailDescription => 'Bevestigen met een code of een e-maillink';
	@override String get enterEmailPrompt => 'Voer het e-mailadres in van het account dat dit apparaat moet gebruiken.';
	@override String get emailAddress => 'E-mailadres';
	@override String get linkAccount => 'Account koppelen';
	@override String get copiedCode => 'Code naar klembord gekopieerd';
	@override String get copyCode => 'Code kopiëren';
	@override String codePrompt({required Object email}) => 'Open de Ham2K-app op een apparaat dat al gekoppeld is met ${email} en voer deze code in om het verzoek goed te keuren:';
	@override String get waitingForConfirmation => 'Wachten op bevestiging…';
	@override String get sendEmailInstead => 'In plaats daarvan een bevestigingsmail sturen';
	@override String emailSent({required Object email}) => 'Er is een e-mail verzonden naar ${email}. Open hem en bevestig het verzoek om dit apparaat te koppelen.';
	@override String get resendEmail => 'E-mail opnieuw verzenden';
	@override String get qrPrompt => 'Scan deze QR-code vanaf een apparaat dat al gekoppeld is aan het gewenste account — bijvoorbeeld met Ham2K Portable Logger op je telefoon.';
	@override String get serverUnreachable => 'Kon de synchronisatieserver niet bereiken. Probeer het later opnieuw.';
	@override String get emailRequired => 'Voer een e-mailadres in om te koppelen.';
	@override String noAccountForEmail({required Object email}) => 'Geen account gevonden voor ${email}.';
	@override String serverRejected({required Object error}) => 'De synchronisatieserver weigerde het verzoek: ${error}';
	@override String get noLinkCode => 'De synchronisatieserver gaf geen koppelcode terug. Probeer het later opnieuw.';
	@override String get noConfirmationCode => 'De synchronisatieserver stuurde geen bevestigingscode. Probeer het later opnieuw.';
	@override String get switchNotAccepted => 'Dat account accepteerde de wissel niet. Probeer het in plaats daarvan te koppelen met een e-mailadres.';
	@override String get requestFailed => 'Er ging iets mis in de communicatie met de synchronisatieserver. Probeer het later opnieuw.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} QSO',
		other: '${count} QSO\'s',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} activatie',
		other: '${count} activaties',
	);
}

// Path: adifImport
class _Translations$adifImport$nl extends Translations$adifImport$en {
	_Translations$adifImport$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSO\'s importeren uit ADIF';
	@override String reading({required Object filename}) => '${filename} lezen…';
	@override String get dropHint => 'Sleep een ADIF-bestand hierheen om te importeren';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} QSO in dit bestand',
		other: '${formatted} QSO\'s in dit bestand',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} staat al in je logboek',
		other: '${formatted} staan al in je logboek',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} wordt geïmporteerd',
		other: '${formatted} worden geïmporteerd',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} nieuw QSO',
		other: '${formatted} nieuwe QSO\'s',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} wordt samengevoegd met een bestaand QSO',
		other: '${formatted} worden samengevoegd met bestaande QSO\'s',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} kan niet worden geïmporteerd (geen roepnaam)',
		other: '${formatted} kunnen niet worden geïmporteerd (geen roepnaam)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} verdient een nadere blik',
		other: '${formatted} verdienen een nadere blik',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Referenties konden niet worden achterhaald voor ${count} QSO',
		other: 'Referenties konden niet worden achterhaald voor ${formatted} QSO\'s',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${programs}-referenties zijn mogelijk onvolledig voor ${count} QSO',
		other: '${programs}-referenties zijn mogelijk onvolledig voor ${formatted} QSO\'s',
	);
	@override String get stackingTypesUnknown => 'Samengevoegde QSO\'s kunnen een referentie verliezen — de activiteiten konden niet zeggen welke typen stapelen. Annuleer en probeer opnieuw om dit te voorkomen.';
	@override String get nothingToImport => 'Niets in dit bestand kan worden geïmporteerd';
	@override String get confirm => 'Importeren';
	@override String importing({required Object filename}) => '${filename} importeren…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} QSO geïmporteerd uit ${filename}',
		other: '${formatted} QSO\'s geïmporteerd uit ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Kon ${filename} niet importeren: ${error}';
	@override String notAdif({required Object filename}) => '${filename} lijkt geen ADIF-bestand';
	@override String stationWarning({required Object calls, required Object station}) => 'Waarschuwing: deze ADIF bevat QSO\'s van ${calls}, maar ze worden geïmporteerd als ${station} als je doorgaat.';
	@override String get stationCallJoin => ' en ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} heeft geen datum en kan niet worden geïmporteerd',
		other: '${formatted} hebben geen datum en kunnen niet worden geïmporteerd',
	);
	@override String activationFound({required Object refs}) => 'Dit bestand bevat een activatie van ${refs}.';
	@override String get addActivation => 'Toevoegen aan deze activatie';
	@override String shortfall({required Object written, required Object planned}) => 'Slechts ${written} van ${planned} konden worden toegepast — het logboek veranderde terwijl je besliste.';
	@override String get busy => 'Er loopt al een import. Wacht tot die klaar is voordat je een nieuwe start.';
	@override String get oneFileOnly => 'Sleep één ADIF-bestand tegelijk — de volgorde waarin bestanden worden geïmporteerd bepaalt welke gegevens winnen.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} heeft meer dan ${limit} QSO\'s, het maximum dat een activatie in één keer kan importeren.';
}

// Path: offline
class _Translations$offline$nl extends Translations$offline$en {
	_Translations$offline$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: verbonden';
	@override String get noRoute => 'Helemaal geen netwerkverbinding.';
	@override String get unreachable => 'Het netwerk werkt, maar geen enkele server reageert — vaak een teken van een inlogpagina die in een browser wacht.';
	@override String get reachable => 'Alle diensten reageren zoals verwacht.';
	@override String get whatStops => 'Opzoeken, spots en gegevensbestanden zijn gepauzeerd. Loggen en synchronisatie in de buurt niet.';
	@override String get servicesTitle => 'Diensten';
	@override String get noServices => 'Nog geen dienst heeft zich gemeld.';
	@override String lastSuccess({required Object when}) => 'Reageerde ${when} geleden voor het laatst';
	@override String get neverSucceeded => 'Heeft nog niet gereageerd';
	@override String nextAttempt({required Object when}) => 'Volgende poging over ${when}';
	@override String get nextAttemptNow => 'Volgende poging staat klaar';
	@override String get retry => 'Nu opnieuw proberen';
	@override String get retrying => 'Proberen…';
	@override String get retryReached => 'Weer online.';
	@override String get retryUnreachable => 'Nog steeds geen reactie.';
	@override String get retryNotAttempted => 'Nu niets te versturen.';
	@override String get retryThrottled => 'Net geprobeerd — even geduld.';
	@override String get retryDisabled => 'Synchronisatie staat uit, dus er is niets om mee te testen.';
	@override String get syncService => 'Ham2K LoFi-synchronisatie';
	@override String get retryInFlight => 'Al bezig — even geduld.';
}

// Path: exportSettings
class _Translations$exportSettings$nl extends Translations$exportSettings$en {
	_Translations$exportSettings$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Basisinstellingen voor alle exports, met aparte sjablonen voor bestandsnaam en titel voor referentieactiviteiten en andere activiteiten. Elk exporttype kan eigen standaardwaarden of aangepaste instellingen hebben.';
	@override String get referenceActivities => 'Referentieactiviteiten';
	@override String get otherActivities => 'Andere activiteiten';
	@override String get adifFields => 'ADIF-velden';
	@override String get loadFailed => 'Exportinstellingen konden niet worden geladen.';
	@override String get retry => 'Opnieuw proberen';
	@override String get compactFileNamesDescriptionOn => 'Compacte bestandsnamen, zoals N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Beschrijvende bestandsnamen, zoals 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Namen, adressen, e-mails, notities en precieze locaties worden in ADIF-bestanden opgenomen.';
	@override String get includePrivateDataDescriptionOff => 'Namen, adressen, e-mails en notities worden weggelaten; locaties beperkt tot grids van zes tekens.';
	@override String get includeLookupDataDescriptionOn => 'Informatie van roepnaam-opzoekdiensten wordt opgenomen.';
	@override String get includeLookupDataDescriptionOff => 'Informatie van roepnaam-opzoekdiensten wordt weggelaten; handmatig ingevoerde waarden blijven behouden.';
	@override String get customTemplatesDescriptionOn => 'Je aangepaste sjablonen zijn actief en kunnen hieronder worden bewerkt.';
	@override String get customTemplatesDescriptionOff => 'Standaardsjablonen zijn actief. Je aangepaste sjablonen worden bewaard voor later.';
	@override String get type => 'Exporttype';
	@override String get defaults => 'Standaardwaarden';
	@override String get includeLookupData => 'Opzoekgegevens opnemen';
	@override String get customTemplates => 'Aangepaste sjablonen';
	@override String get filenameTemplate => 'Bestandsnaam sjabloon';
	@override String get compactFilenameTemplate => 'Sjabloon compacte bestandsnaam';
	@override String get titleTemplate => 'Titel sjabloon';
	@override String get adifNotesTemplate => 'ADIF QSO Notities';
	@override String get adifCommentTemplate => 'ADIF QSO Opmerkingen';
	@override String get adifQslMessageTemplate => 'ADIF QSL Bericht';
	@override String get shared => 'Instellingen gelden voor elke extensie die dit exporttype gebruikt.';
	@override String get defaultTemplates => 'Zet Aangepaste sjablonen aan om de sjablonen van dit type te bewerken.';
}

// Path: templateEditor
class _Translations$templateEditor$nl extends Translations$templateEditor$en {
	_Translations$templateEditor$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Voorbeeld:';
	@override String get reset => 'Resetten';
	@override String get docs => 'Sjabloondocumentatie';
	@override String get preview => 'Voorbeeldweergave';
	@override String get reference => 'Sjabloonreferentie';
	@override String get attributes => 'Beschikbare attributen';
	@override String get filters => 'Filters';
	@override String get flowControl => 'Programmaverloop';
	@override String get unavailable => 'Voorbeeld is niet beschikbaar tot de extensies klaar zijn.';
	@override String get empty => '(lege uitvoer)';
}

// Path: home.nav
class _Translations$home$nav$nl extends Translations$home$nav$en {
	_Translations$home$nav$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Activaties';
	@override String get chase => 'Jagen';
	@override String get logs => 'Logboeken';
	@override String get maps => 'Kaarten';
	@override String get settings => 'Instellingen';
}

// Path: home.panels
class _Translations$home$panels$nl extends Translations$home$panels$en {
	_Translations$home$panels$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Activatielijst';
	@override String get operationsDescription => 'Je activaties, meest recente eerst.';
	@override String get version => 'Huidige versie';
	@override String get versionDescription => 'Het Ham2K-logo, de naam van deze app en welke build je gebruikt.';
}

// Path: home.logs
class _Translations$home$logs$nl extends Translations$home$logs$en {
	_Translations$home$logs$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logboeken';
	@override String get titleFor => 'Logboeken voor';
	@override String get emptyCallsigns => 'Nog geen QSO\'s gelogd';
	@override String emptyQsos({required Object call}) => 'Geen QSO\'s voor ${call}';
	@override String get mapNoSelection => 'Selecteer een QSO om het op de kaart te zien';
	@override String get searchHint => 'Zoek roepnaam of naam';
	@override String get noSearchMatches => 'Geen QSO\'s gevonden';
	@override String get titleAll => 'Alle logboeken';
	@override String get allCallsigns => 'Alle roepnamen';
	@override String get noOperation => 'Hoort niet bij een activatie';
	@override String get unsavedTitle => 'Niet-opgeslagen wijzigingen';
	@override String get unsavedBody => 'Dit QSO heeft wijzigingen die je niet hebt opgeslagen.';
	@override String get pendingDeleteBody => 'Dit QSO is gemarkeerd om te verwijderen.';
	@override String get editGone => 'Niet opgeslagen: dat QSO staat niet meer in dit logboek.';
	@override String get discard => 'Weggooien';
	@override late final _Translations$home$logs$columns$nl columns = _Translations$home$logs$columns$nl._(_root);
	@override late final _Translations$home$logs$panels$nl panels = _Translations$home$logs$panels$nl._(_root);
	@override late final _Translations$home$logs$import$nl import = _Translations$home$logs$import$nl._(_root);
}

// Path: chase.station
class _Translations$chase$station$nl extends Translations$chase$station$en {
	_Translations$chase$station$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jagend station';
	@override String get stationLabel => 'Station: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Geen locatie';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$nl extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get today => 'vandaag';
	@override String get thisWeek => 'deze week';
	@override String get last14Days => 'in de laatste 14 dagen';
	@override String get thisMonth => 'deze maand';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$nl extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistieken van vandaag';
	@override String get thisWeek => 'Statistieken van deze week';
	@override String get last14Days => 'Statistieken van de laatste 14 dagen';
	@override String get thisMonth => 'Statistieken van deze maand';
}

// Path: chase.period
class _Translations$chase$period$nl extends Translations$chase$period$en {
	_Translations$chase$period$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get today => 'Vandaag';
	@override String get thisWeek => 'Deze week';
	@override String get last14Days => 'Laatste 14 dagen';
	@override String get thisMonth => 'Deze maand';
}

// Path: chase.goals
class _Translations$chase$goals$nl extends Translations$chase$goals$en {
	_Translations$chase$goals$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jaagdoelen';
	@override String remove({required Object name}) => 'Stop met jagen op ${name}';
	@override String get extensionsTitle => 'Extensies met jaagdoelen';
}

// Path: chase.panels
class _Translations$chase$panels$nl extends Translations$chase$panels$en {
	_Translations$chase$panels$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO\'s';
	@override String get loggingDescription => 'Logbediening boven de QSO\'s die in de periode zijn gejaagd.';
	@override String get info => 'Info';
	@override String get infoDescription => 'De roepnaam die wordt gelogd, of de statistieken van de periode.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Gespotte stations in de lucht, klaar om te jagen.';
	@override String get map => 'Kaart';
	@override String get mapDescription => 'De QSO\'s van de periode en het station dat wordt gelogd.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$nl extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Ongeldige roepnaam: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Ongeldige roepnamen: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Tot nu toe was ${previous} operator. ${typed} wordt vastgelegd voor nieuwe QSO\'s.';
	@override String operatorNoneSoFar({required Object typed}) => 'Tot nu toe geen operator vastgelegd. ${typed} wordt vastgelegd voor nieuwe QSO\'s.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Deze activatie heeft al QSO\'s door ${calls}. ${typed} wordt alleen vastgelegd voor nieuwe QSO\'s.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Leg ${typed} ook vast als operator van het reeds gelogde QSO',
		other: 'Leg ${typed} ook vast als operator van alle ${count} reeds gelogde QSO\'s',
	);
	@override String get operatorSeveralStations => 'Bij gebruik van meerdere stationroepnamen in de lucht zijn aparte operators niet mogelijk';
	@override String get contactsUnreadable => 'De QSO\'s van deze activatie konden niet worden gelezen, dus een roepnaamwijziging hier biedt niet aan ze bij te werken';
	@override String restampFailed({required Object error}) => 'De reeds gelogde QSO\'s konden niet worden bijgewerkt, dus er is niets gewijzigd: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} van ${planned} QSO\'s zijn bijgewerkt — de rest hoort niet meer bij deze activatie';
}

// Path: operation.tabs
class _Translations$operation$tabs$nl extends Translations$operation$tabs$en {
	_Translations$operation$tabs$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO\'s';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'KAART';
	@override String get qsosPlain => 'QSO\'s';
	@override String get clock => 'Klok';
	@override String get weather => 'Weer';
	@override String get website => 'Website';
	@override String get remoteScreen => 'Extern scherm';
	@override String get solar => 'Zon';
	@override String get radio => 'Radio';
}

// Path: operation.positions
class _Translations$operation$positions$nl extends Translations$operation$positions$en {
	_Translations$operation$positions$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Nog geen andere operatorposities delen deze activatie.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Een andere positie';
	@override String get thisDevice => 'Onze operatorpositie';
	@override String get nameIn => ' in ';
	@override String get panelTitle => 'Posities';
	@override String get panelDescription => 'Wat elke operatorpositie die deze activatie deelt op dit moment logt.';
}

// Path: operation.menu
class _Translations$operation$menu$nl extends Translations$operation$menu$en {
	_Translations$operation$menu$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'RST-velden tonen';
	@override String get showStateField => 'Staatveld tonen';
	@override String get showGridField => 'Gridveld tonen';
	@override String get showDeletedQsos => 'Verwijderde QSO\'s tonen';
	@override String get showDeletedOps => 'Verwijderde activaties tonen';
	@override String get showQsoNumbers => 'QSO-nummers tonen';
	@override String get lookupAllQsos => 'Alle QSO\'s opzoeken';
	@override String get loggingSettingsTitle => 'Loginstellingen';
	@override String get mapSettingsTitle => 'Kaartinstellingen';
	@override String get actionsSection => 'Acties';
}

// Path: operation.layout
class _Translations$operation$layout$nl extends Translations$operation$layout$en {
	_Translations$operation$layout$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Paneel toevoegen';
	@override String get availableSection => 'Beschikbare panelen';
	@override String panelSettings({required Object panel}) => 'Instellingen ${panel}';
	@override String get panelSettingsAction => 'Paneelinstellingen';
	@override String get viewName => 'Activatieweergave';
	@override String get viewOptions => 'Opties voor weergave-indeling';
	@override String get viewTitleBuiltIn => 'Deze weergave is ingebouwd in de app, en de naam ook';
	@override String get resetOptions => 'Standaardwaarden herstellen';
	@override String get removePane => 'Verwijderen';
	@override String resetPaneConfirm({required Object panel}) => '${panel} terugzetten naar de standaardwaarden?';
	@override String get resetPaneConfirmBody => 'De titel, kop en grootte gaan terug naar de standaardwaarden. De rest van de indeling blijft zoals die is.';
	@override String get resetViewConfirm => 'Deze weergave terugzetten naar de standaardindeling?';
	@override String get resetViewConfirmBody => 'De panelen gaan terug naar hun standaardopstelling, en de opties van de weergave en van elk paneel gaan terug naar de standaardwaarden.';
	@override String paneOptionsTitle({required Object panel}) => 'Indelingsinstellingen ${panel}';
	@override String get paneTitle => 'Titel';
	@override String get paneShowHeader => 'Kop tonen';
	@override String get paneShowHeaderTabset => 'Altijd zichtbaar zolang dit paneel een groep deelt — via de kop bereik je de andere';
	@override String get paneInherit => 'Zelfde als de app';
	@override String get searchHint => 'Panelen zoeken';
	@override String get noPanelsMatch => 'Geen paneel gevonden.';
	@override String get nothingToAdd => 'Deze weergave heeft al alle mogelijke panelen';
	@override String addPanel({required Object panel}) => '${panel} toevoegen';
	@override String showPreview({required Object panel}) => 'Voorbeeld ${panel}';
	@override String missingExtension({required Object name}) => 'Extensie "${name}" ontbreekt';
	@override String get previewUnavailable => 'De voorbeeldafbeelding van dit paneel kon niet worden getoond.';
	@override String get nestedPaneTitle => 'Meer';
	@override String get editLayout => 'Indeling bewerken';
	@override String get saveLayout => 'Indeling opslaan';
	@override String get revertLayout => 'Indelingswijzigingen weggooien';
	@override String get done => 'Klaar';
	@override String get layoutUnreadableTitle => 'Indeling kon niet worden gelezen';
	@override String get layoutUnreadableBody => 'Je opgeslagen indeling kon niet worden gelezen, dus de standaardopstelling wordt getoond. Je origineel wordt pas overschreven als je ervoor kiest deze te houden.';
	@override String get layoutUnreadableAction => 'Deze indeling gebruiken';
	@override String panelRenderFailed({required Object panel}) => '${panel} kon niet worden weergegeven';
	@override String get panelRenderRetry => 'Opnieuw proberen';
	@override String get panelActionFailed => 'Die paneelactie is mislukt. Probeer het opnieuw.';
	@override late final _Translations$operation$layout$panels$nl panels = _Translations$operation$layout$panels$nl._(_root);
	@override String get htmlPanelUnsupported => 'Dit paneel heeft een webweergave nodig, die dit platform niet biedt';
	@override String get htmlPanelUnsupportedOnWeb => 'Dit paneel heeft een sandbox nodig die de webversie niet kan bieden';
}

// Path: operation.export
class _Translations$operation$export$nl extends Translations$operation$export$en {
	_Translations$operation$export$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activatie-exports';
	@override String get syncedOperation => 'Activatie is gesynchroniseerd';
	@override String get unsyncedOperation => 'Activatie heeft niet-gesynchroniseerde wijzigingen';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} QSO in deze activatie',
		other: '${count} QSO\'s in deze activatie',
	);
	@override String qsosSynced({required Object total}) => 'Alle ${total} QSO\'s zijn gesynchroniseerd';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} van ${total} QSO\'s wachten op synchronisatie';
	@override String eventsSynced({required Object total}) => '${total} gebeurtenismarkeringen gesynchroniseerd';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} van ${total} gebeurtenismarkeringen in afwachting';
	@override String get loading => 'Exportopties laden…';
	@override String get noOptions => 'Geen exportformaten beschikbaar (extensies nog aan het starten?)';
	@override String get nothingLogged => 'Nog niets te exporteren — deze activatie heeft geen QSO\'s.';
	@override String get share => 'Delen';
	@override String get nothingSelected => 'Niets geselecteerd';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand opslaan',
		other: '${count} bestanden opslaan',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand delen',
		other: '${count} bestanden delen',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand exporteren',
		other: '${count} bestanden exporteren',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand downloaden',
		other: '${count} bestanden downloaden',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} gecombineerd bestand opslaan',
		other: '${count} gecombineerde bestanden opslaan',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} gecombineerd bestand delen',
		other: '${count} gecombineerde bestanden delen',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} gecombineerd bestand exporteren',
		other: '${count} gecombineerde bestanden exporteren',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} gecombineerd bestand downloaden',
		other: '${count} gecombineerde bestanden downloaden',
	);
	@override String saveOne({required Object name}) => '${name} opslaan';
	@override String shareOne({required Object name}) => '${name} delen';
	@override String exportOne({required Object name}) => '${name} exporteren';
	@override String downloadOne({required Object name}) => '${name} downloaden';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand naar Stash',
		other: '${count} bestanden naar Stash',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} gecombineerd bestand naar Stash',
		other: '${count} gecombineerde bestanden naar Stash',
	);
	@override String get settingsButton => 'Exportinstellingen';
	@override String get settingsTitle => 'Exportinstellingen';
	@override late final _Translations$operation$export$compactFileNames$nl compactFileNames = _Translations$operation$export$compactFileNames$nl._(_root);
	@override late final _Translations$operation$export$includePrivateData$nl includePrivateData = _Translations$operation$export$includePrivateData$nl._(_root);
	@override String get resultTitle => 'Export voltooid';
	@override String get resultFailedTitle => 'Export mislukt';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand geëxporteerd naar ${path}',
		other: '${count} bestanden geëxporteerd naar ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand geëxporteerd: ${path}',
		other: '${count} bestanden geëxporteerd: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand gedeeld',
		other: '${count} bestanden gedeeld',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand gedownload',
		other: '${count} bestanden gedownload',
	);
	@override String exportFailed({required Object error}) => 'Export mislukt: ${error}';
	@override late final _Translations$operation$export$stash$nl stash = _Translations$operation$export$stash$nl._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$nl extends Translations$operation$spots$en {
	_Translations$operation$spots$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Geen spots die aan je filters voldoen';
	@override String error({required Object error}) => 'Spots laden mislukt: ${error}';
	@override String get unknownBand => 'Andere';
	@override String get auto => 'Automatisch';
	@override String autoValue({required Object value}) => 'Automatisch (momenteel ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Alle';
	@override String get allBands => 'Alle banden';
	@override String get allModes => 'Alle modes';
	@override String get phoneAndCw => 'SSB & CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => '${count} van ${total} spots getoond';
	@override String ageMinutes({required Object minutes}) => '${minutes} minuten';
	@override String get callsOfNote => 'Opmerkelijke roepnamen';
	@override String get yourSpots => 'Jouw spots';
	@override String get allSpots => 'Alle spots';
	@override late final _Translations$operation$spots$continents$nl continents = _Translations$operation$spots$continents$nl._(_root);
	@override late final _Translations$operation$spots$filters$nl filters = _Translations$operation$spots$filters$nl._(_root);
	@override String get unavailableTitle => 'Spots niet beschikbaar';
	@override String unavailableText({required Object sources}) => '${sources} reageerde niet.';
	@override String get failedTitle => 'Fout bij spotbron';
	@override String failedText({required Object sources}) => '${sources} gaf een fout terug.';
	@override String get slideLogIt => 'Loggen';
	@override String get slideIgnore => 'Negeren';
	@override String get slideRestore => 'Herstellen';
	@override late final _Translations$operation$spots$logConflict$nl logConflict = _Translations$operation$spots$logConflict$nl._(_root);
}

// Path: operation.import
class _Translations$operation$import$nl extends Translations$operation$import$en {
	_Translations$operation$import$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gegevens importeren in activatie';
	@override String get importAdifAction => 'QSO\'s importeren uit ADIF';
	@override String get settingsButton => 'Luisterinstellingen';
	@override String get settingsTitle => 'Luisteren naar andere apps';
	@override String get protocolAddressLabel => 'Adres';
	@override String get protocolPortLabel => 'Poort';
	@override String get protocolPortInvalid => 'Voer een poort in tussen 1 en 65535';
	@override String get protocolAddressInvalid => 'Voer een geldig IP-adres in (bijv. 127.0.0.1 of 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Gegevens worden ontvangen';
	@override String get protocolStatusNoData => 'Recent geen gegevens ontvangen';
	@override String protocolBindError({required Object error}) => 'Kon niet beginnen met luisteren: ${error}';
	@override String captureFailed({required Object error}) => 'Binnenkomende QSO\'s konden niet worden opgeslagen en worden opnieuw geprobeerd: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Alle (broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → tabblad Broadcast Data → vink "Enable Broadcasts" aan voor contact info. Stel het IP-adres in op 127.0.0.1 als het op deze computer draait, of 255.255.255.255 om op het huidige lokale netwerk uit te zenden.';
	@override String get helpWsjtxSetup => 'File → Settings → tabblad Reporting → sectie UDP Server → vink "Accept UDP requests" aan. Stel UDP Server in op 127.0.0.1 als het op deze computer draait, of op een multicastadres zoals 239.239.0.2, en gebruik hetzelfde adres in de configuratie hierboven in deze app.';
	@override String get listenTitle => 'Luisteren naar QSO\'s van andere apps';
	@override String get listenDescriptionOnN1mm => 'Luistert naar N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Luistert naar WSJT-X';
	@override String get listenDescriptionOnBoth => 'Luistert naar N1MM+ en WSJT-X';
	@override String get listenDescriptionOff => 'Uit';
	@override String get addToOperationTitle => 'Toevoegen aan deze activatie';
	@override String get addToOperationDescriptionOn => 'Ontvangen QSO\'s worden bij aankomst aan deze activatie toegevoegd';
	@override String get addToOperationDescriptionOff => 'Ontvangen QSO\'s worden vastgehouden tot je dit aanzet';
	@override String get pendingSectionTitle => 'Ontvangen QSO\'s';
	@override String get pendingEmpty => 'Nog niets ontvangen';
	@override String stationMismatch({required Object call}) => 'Gelogd als ${call}, niet het station van deze activatie';
	@override String get discardAction => 'Weggooien';
	@override String get gapDialogTitle => 'Eerdere ontvangsten meenemen?';
	@override String gapDialogBody({required Object count}) => 'Er zijn eerder nog ${count} QSO\'s ontvangen, vóór een onderbreking in de gegevens. Die ook meenemen?';
	@override String get gapDialogRecentOnly => 'Alleen de recente';
	@override String gapDialogIncludeAll({required Object count}) => 'Alle ${count} meenemen';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$nl extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problemen?';
	@override String get title => 'Probleem met een omtrek melden';
	@override String get reference => 'Welke omtrek';
	@override String get severity => 'Hoe erg is het?';
	@override String get minor => 'Klein detail';
	@override String get major => 'Groot probleem';
	@override String get explanation => 'Wat is er mis mee?';
	@override String get explanationHint => 'Wat de omtrek fout heeft, en waar';
	@override String get send => 'Versturen';
	@override String get sending => 'Je melding wordt verstuurd — bedankt';
	@override String get copy => 'Melding kopiëren';
	@override String get notSent => 'Kon de melding niet versturen';
	@override String get copied => 'Melding gekopieerd';
	@override String get notCopied => 'Kon de melding niet kopiëren';
}

// Path: map.postcard
class _Translations$map$postcard$nl extends Translations$map$postcard$en {
	_Translations$map$postcard$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get button => 'Activatie-ansichtkaart';
	@override String title({required Object title}) => 'Ansichtkaart voor ${title}';
	@override String get portrait => 'Staand';
	@override String get landscape => 'Liggend';
	@override String get square => 'Vierkant';
	@override String get save => 'Opslaan…';
	@override String get download => 'Downloaden';
	@override String get share => 'Delen';
	@override String get copy => 'Kopiëren';
	@override String get copied => 'Gekopieerd naar het klembord';
	@override String saved({required Object path}) => 'Opgeslagen in ${path}';
	@override String downloaded({required Object name}) => '${name} gedownload';
	@override String savedMany({required Object count, required Object path}) => '${count} afbeeldingen opgeslagen in ${path}';
	@override String savedFiles({required Object names}) => '${names} opgeslagen';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} was al opgeslagen';
	@override String downloadedMany({required Object count}) => '${count} afbeeldingen downloaden — sta ze toe als de browser erom vraagt';
	@override String get mapLeftOut => 'De kaart laadde niet en is weggelaten';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — de kaart laadde niet en is weggelaten';
	@override String continued({required Object title}) => '${title} (vervolg)';
	@override String get previousPage => 'Vorige pagina';
	@override String get nextPage => 'Volgende pagina';
	@override String pageOf({required Object page, required Object count}) => 'Pagina ${page} van ${count}';
	@override String get sections => 'Samenvattingssecties';
	@override String get sectionDays => 'Elke dag';
	@override String get reset => 'Resetten';
	@override String failed({required Object error}) => 'Kon de ansichtkaart niet maken: ${error}';
	@override String get mapNotReady => 'De kaart is niet volledig geladen. Controleer de verbinding en probeer het opnieuw.';
	@override String saveFailed({required Object error}) => 'Kon de ansichtkaart niet opslaan: ${error}';
	@override String get copyFailed => 'Het klembord nam de afbeelding niet aan. Probeer het opnieuw.';
	@override String get shareFailed => 'Kon de ansichtkaart niet delen. Probeer het opnieuw.';
	@override String get fileName => 'ansichtkaart';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$nl extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Nog geen QSO\'s… Laten we starten!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO\'s';
	@override String qsosInTime({required Object count, required Object time}) => '${count} in ${time}';
	@override String sinceLast({required Object time}) => '${time} sinds de laatste';
	@override String ratePer10({required Object rate}) => '${rate} Q/h voor de laatste 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h voor de laatste 100';
	@override String distanceTo({required Object distance}) => '${distance} naar';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) naar';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) naar';
	@override String distanceAway({required Object distance}) => '${distance} verwijderd';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verwijderd';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verwijderd';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Dupe!';
	@override String get noticeNewBand => 'Nieuwe band';
	@override String get noticeNewMode => 'Nieuwe mode';
	@override String get noticeNewDXCC => 'Nieuwe DXCC';
	@override String get noticeNewState => 'Nieuwe staat';
	@override String get noticeNewProvince => 'Nieuwe provincie';
	@override String get noticeNewDay => 'Nieuwe dag';
	@override String get noticeNewRef => 'Nieuwe ref';
	@override String get noticeNewMult => 'Nieuwe multiplier';
	@override String get noticeNewZone => 'Nieuwe zone';
	@override String get noticeInvalidMode => 'Verkeerde mode';
	@override String get noticeInvalidBand => 'Verkeerde band';
	@override String get noticeInvalidCategory => 'Niet werkbaar';
	@override String get noticeWorkedBefore => 'Eerder gewerkt';
	@override String get noticeNewPark => 'Nieuw park';
	@override String get noticeNewSection => 'Nieuwe sectie';
	@override String get noticeBonusStation => 'Bonusstation!';
	@override String get noticeMissingExchange => 'Geen uitwisseling';
	@override String get noticeInvalidExchange => 'Foute uitwisseling';
	@override String get noticeUnknownEvent => 'Onbekend evenement';
	@override String get noticeOurGrid => 'Stel ons grid in';
	@override String get noticeRareCounty => 'Zeldzame county!';
	@override String get noticeOurLocation => 'Stel onze county in';
	@override String get noticeShortGrid => 'Grid te kort';
}

// Path: callInfo.history
class _Translations$callInfo$history$nl extends Translations$callInfo$history$en {
	_Translations$callInfo$history$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} in de laatste 7 dagen';
	@override String today({required Object n}) => '${n} vandaag';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${n} QSO',
		other: '${n} QSO\'s',
	);
}

// Path: settings.theme
class _Translations$settings$theme$nl extends Translations$settings$theme$en {
	_Translations$settings$theme$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Thema';
	@override String get system => 'Systeeminstellingen volgen';
	@override String get light => 'Licht';
	@override String get dark => 'Donker';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$nl extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get system => 'Volgt de systeeminstellingen';
	@override String get light => 'Altijd in Lichte Modus';
	@override String get dark => 'Altijd in Donkere Modus';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$nl extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Kleinste--';
	@override String get smallestMinus => 'Kleinste-';
	@override String get smallest => 'Kleinste';
	@override String get smaller => 'Kleiner';
	@override String get normal => 'Normaal';
	@override String get larger => 'Groter';
	@override String get largest => 'Grootste';
	@override String get largestPlus => 'Grootste+';
	@override String get largestPlusPlus => 'Grootste++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$nl extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Houd apparaat actief';
	@override String get descriptionOn => 'Blijft wakker zolang je in de logweergave bent of er een synchronisatie loopt';
	@override String get descriptionOff => 'Slaapt zoals gewoonlijk';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$nl extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatisch';
	@override String get densest => 'Dichtst';
	@override String get dense => 'Dicht';
	@override String get normal => 'Normaal';
	@override String get sparse => 'Ruim';
	@override String get sparsest => 'Ruimst';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$nl extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometers';
	@override String get miles => 'Mijlen';
}

// Path: settings.logging
class _Translations$settings$logging$nl extends Translations$settings$logging$en {
	_Translations$settings$logging$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Loggen';
	@override late final _Translations$settings$logging$leftieMode$nl leftieMode = _Translations$settings$logging$leftieMode$nl._(_root);
	@override late final _Translations$settings$logging$countryFlags$nl countryFlags = _Translations$settings$logging$countryFlags$nl._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$nl countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$nl._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$nl suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$nl._(_root);
	@override late final _Translations$settings$logging$showBearing$nl showBearing = _Translations$settings$logging$showBearing$nl._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$nl showReverseBearing = _Translations$settings$logging$showReverseBearing$nl._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$nl switchSentRcvd = _Translations$settings$logging$switchSentRcvd$nl._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$nl jumpAfterRST = _Translations$settings$logging$jumpAfterRST$nl._(_root);
	@override late final _Translations$settings$logging$defaultReport$nl defaultReport = _Translations$settings$logging$defaultReport$nl._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$nl defaultReportCW = _Translations$settings$logging$defaultReportCW$nl._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$nl defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$nl._(_root);
	@override late final _Translations$settings$logging$numbersRow$nl numbersRow = _Translations$settings$logging$numbersRow$nl._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$nl numbersRowExtra = _Translations$settings$logging$numbersRowExtra$nl._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$nl numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$nl._(_root);
	@override String get bands => 'Voorkeursbanden';
	@override String get modes => 'Voorkeursmodes';
}

// Path: settings.catServer
class _Translations$settings$catServer$nl extends Translations$settings$catServer$en {
	_Translations$settings$catServer$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-server';
	@override String get description => 'Laat andere apps (WSJT-X, loggers, enz.) de radio bedienen via Ham2K Logger.';
	@override String get protocol => 'Protocol';
	@override late final _Translations$settings$catServer$protocolOpts$nl protocolOpts = _Translations$settings$catServer$protocolOpts$nl._(_root);
	@override String get port => 'Poort';
	@override String get openAccess => 'Open toegang';
	@override String get openAccessOn => 'Elke computer op het lokale netwerk kan verbinden.';
	@override String get openAccessOff => 'Alleen apps op deze computer kunnen verbinden.';
	@override String get off => 'Uit.';
	@override String starting({required Object protocol}) => '${protocol}, wordt gestart…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} op poort ${port}. Verbonden clients: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} op poort ${port}, maar er is geen Main VFO-radio verbonden.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} kan niet luisteren op poort ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} kan niet luisteren op poort ${port}: een ander programma gebruikt die, vaak ${protocol} zelf. Sluit dat programma of kies een andere poort.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} kan niet luisteren op poort ${port}: deze computer staat dat niet toe. Kies een poort boven 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} is gestopt met luisteren op poort ${port}. Nieuwe poging…';
}

// Path: settings.radio
class _Translations$settings$radio$nl extends Translations$settings$radio$en {
	_Translations$settings$radio$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-besturing';
	@override String get loggingAndCat => 'Loggen & CAT';
	@override String get tuningSection => 'Afstemmen';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Diensten';
	@override String get stationConfigurationSection => 'Stationsconfiguratie';
	@override String get moreSettings => 'Meer instellingen voor stationsconfiguratie';
	@override late final _Translations$settings$radio$units$nl units = _Translations$settings$radio$units$nl._(_root);
	@override late final _Translations$settings$radio$pttKey$nl pttKey = _Translations$settings$radio$pttKey$nl._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$nl smartVfoSnap = _Translations$settings$radio$smartVfoSnap$nl._(_root);
	@override late final _Translations$settings$radio$snapDebounce$nl snapDebounce = _Translations$settings$radio$snapDebounce$nl._(_root);
	@override late final _Translations$settings$radio$snapLongMove$nl snapLongMove = _Translations$settings$radio$snapLongMove$nl._(_root);
	@override late final _Translations$settings$radio$snapMinMove$nl snapMinMove = _Translations$settings$radio$snapMinMove$nl._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$nl snapMinSpeed = _Translations$settings$radio$snapMinSpeed$nl._(_root);
	@override late final _Translations$settings$radio$enterSends$nl enterSends = _Translations$settings$radio$enterSends$nl._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$nl keyerSpeed = _Translations$settings$radio$keyerSpeed$nl._(_root);
	@override late final _Translations$settings$radio$cwMessages$nl cwMessages = _Translations$settings$radio$cwMessages$nl._(_root);
	@override late final _Translations$settings$radio$voiceMessages$nl voiceMessages = _Translations$settings$radio$voiceMessages$nl._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$nl avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$nl._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$nl zeroBeatRange = _Translations$settings$radio$zeroBeatRange$nl._(_root);
}

// Path: settings.help
class _Translations$settings$help$nl extends Translations$settings$help$en {
	_Translations$settings$help$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hulp & bronnen';
	@override String get description => 'Community en ondersteuning';
	@override String get forums => 'Ham2K-forums';
	@override String get forumsDescription => 'Vind hulp, geef feedback, bespreek ideeën…';
	@override String get chat => 'Ham2K-chat';
	@override String get chatDescription => 'De Discord-server voor onze online community';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Video\'s en livestreams';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Omdat je nooit genoeg foto\'s kunt hebben…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Volg ons voor nieuws en updates';
	@override String get contact => 'Contacteer ons';
	@override String get contactDescription => 'help@ham2k.com — maar probeer eerst de forums of chat!';
}

// Path: settings.exports
class _Translations$settings$exports$nl extends Translations$settings$exports$en {
	_Translations$settings$exports$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exports';
}

// Path: settings.map
class _Translations$settings$map$nl extends Translations$settings$map$en {
	_Translations$settings$map$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kaarten';
	@override late final _Translations$settings$map$style$nl style = _Translations$settings$map$style$nl._(_root);
	@override late final _Translations$settings$map$styleOpts$nl styleOpts = _Translations$settings$map$styleOpts$nl._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$nl extends Translations$settings$privacy$en {
	_Translations$settings$privacy$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacy';
	@override late final _Translations$settings$privacy$shareAppData$nl shareAppData = _Translations$settings$privacy$shareAppData$nl._(_root);
	@override late final _Translations$settings$privacy$shareOpData$nl shareOpData = _Translations$settings$privacy$shareOpData$nl._(_root);
	@override String get privacyPolicy => 'Privacybeleid';
	@override String get termsOfService => 'Algemene Voorwaarden';
}

// Path: settings.sync
class _Translations$settings$sync$nl extends Translations$settings$sync$en {
	_Translations$settings$sync$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cloud-synchronisatie';
	@override String get moreSettings => 'Meer synchronisatie-instellingen';
	@override String get enable => 'Synchronisatie inschakelen';
	@override String get deviceKey => 'Apparaatsleutel';
}

// Path: settings.peers
class _Translations$settings$peers$nl extends Translations$settings$peers$en {
	_Translations$settings$peers$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Peer-apparaten';
	@override String get enable => 'Verbinden met andere apparaten';
	@override String get enableDescription => 'Activaties, loggen, CAT en GPS delen met andere apparaten via het lokale netwerk';
	@override String get bleEnable => 'Verbinden via Bluetooth';
	@override String get bleDescription => 'Bluetooth LE gebruiken om te verbinden, ook zonder lokaal netwerk';
	@override String get thisDevice => 'Dit apparaat';
	@override String get deviceName => 'Naam';
	@override String get deviceNameHint => 'Hoe andere apparaten dit apparaat zien';
	@override String get pairedDevices => 'Gekoppelde apparaten';
	@override String get noPairedDevices => 'Nog geen apparaten gekoppeld. Zet dit aan op een ander apparaat op dit netwerk om ze te koppelen.';
	@override String deviceListProblem({required Object error}) => 'Kan je gekoppelde apparaten niet lezen: ${error}';
	@override String get nearby => 'In de buurt';
	@override String get connected => 'Verbonden';
	@override String get viaBluetooth => 'via Bluetooth';
	@override String get connecting => 'Verbinden…';
	@override String get syncing => 'Synchroniseren…';
	@override String get waitingForThem => 'Wachten op het andere apparaat';
	@override String get notConnected => 'Niet verbonden';
	@override String get wantsToPair => 'wil deze activatie delen';
	@override String get allow => 'Toestaan';
	@override String get link => 'Koppelen';
	@override String get reject => 'Weigeren';
	@override String get forget => 'Vergeten';
	@override String forgetTitle({required Object name}) => '${name} vergeten?';
	@override String get forgetBody => 'Het stopt met synchroniseren met dit apparaat. Je kunt het later opnieuw toestaan, en reeds gelogde QSO\'s blijven bewaard.';
	@override String pairTitle({required Object name}) => 'Koppelen met ${name}';
	@override String get pairBody => 'Dit apparaat staat op je lokale netwerk en wil verbinden.';
	@override String get pairBodyBle => 'Dit apparaat is in de buurt en wil verbinden via Bluetooth LE.';
	@override String get pairIdLabel => 'Apparaat-ID';
	@override String get pairWarning => 'Koppel alleen met apparaten die je herkent. Elk apparaat op dit netwerk kan een verzoek sturen.';
	@override String get pairWarningBle => 'Koppel alleen met apparaten die je herkent. Elk apparaat in de buurt kan een verzoek sturen.';
	@override String problem({required Object error}) => 'Kan het lokale netwerk niet bereiken: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Verbonden met ${device}';
	@override String statusLost({required Object device}) => 'Verbinding met ${device} verbroken';
	@override String statusPerma({required Object connected, required Object linked}) => 'Peer-apparaten: ${connected} van ${linked} verbonden';
	@override String get screenEnable => 'Schermen en vensters delen';
	@override String get screenDescription => 'Andere apparaten schermen of vensters van deze computer laten tonen';
	@override String get screenSources => 'Schermen en vensters';
	@override String get screenRefresh => 'Lijst verversen';
	@override String get screenUnsupportedPlatform => 'Dit apparaat kan zijn scherm niet delen. macOS kan dat wel; elk apparaat kan een scherm tonen dat door een ander wordt gedeeld.';
	@override String get screenUnsupportedVersion => 'Scherm delen vereist macOS 12.3 of later. Dit apparaat kan nog steeds een scherm tonen dat door een ander wordt gedeeld.';
	@override String get screenNeedsPermission => 'macOS heeft je toestemming nodig om het scherm op te nemen voordat deze app er een kan delen.';
	@override String get screenGrantPermission => 'Toestemming vragen';
	@override String get screenRelaunchAfterGranting => 'Sta het toe in Systeeminstellingen onder Privacy en beveiliging → Schermopname, en sluit en heropen daarna deze app — macOS meldt de wijziging pas bij de volgende start van een app.';
	@override String screenProblem({required Object error}) => 'Scherm delen: ${error}';
	@override String get screenChooseTitle => 'Kies wat je deelt';
	@override String get screenChooseButton => 'Kies wat je deelt…';
	@override String get screenTabScreens => 'Schermen';
	@override String get screenTabApps => 'Apps';
	@override String get screenTabWindows => 'Vensters';
	@override String get screenTabEmpty => 'Niets van dit type gevonden.';
	@override String get screenSharedSummaryNone => 'Nog niets gekozen.';
	@override String get screenThisDevice => 'Dit apparaat';
	@override String screenSharedTo({required Object devices}) => 'Getoond op ${devices}';
	@override String get screenSharedToNobody => 'Wordt niet getoond';
	@override String screenStopSharing({required Object name}) => 'Stop met delen van ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$nl extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Synchronisatieconfiguratie';
	@override String get enableTitle => 'Synchroniseren met Ham2K Log Filer';
	@override String get enabledDescription => 'Je logboek wordt geback-upt en tussen apparaten gesynchroniseerd';
	@override String get disabledDescription => 'Uit — blijft alleen op dit apparaat';
	@override String get syncing => 'Synchroniseren';
	@override String get account => 'Account';
	@override String get refresh => 'Verversen';
	@override String get switchAccounts => 'Ander account';
	@override String get switchAccountsDescription => 'Koppel dit apparaat aan een ander account via een QR-code of e-mail';
	@override String get connectionRequests => 'Verbindingsverzoeken';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Een apparaat wacht om aan dit account te worden toegevoegd',
		other: '${n} apparaten wachten om aan dit account te worden toegevoegd',
	);
	@override String get accountEmailTitle => 'Account-e-mail';
	@override String accountEmailSent({required Object email}) => 'Bevestiging verzonden naar ${email}. Open de link daar om de wijziging af te ronden.';
	@override String get resendConfirmation => 'Bevestigingsmail opnieuw verzenden';
	@override String resendConfirmationDescription({required Object email}) => 'Wachten op ${email}';
	@override String accountEmailResent({required Object email}) => 'Opnieuw verzonden naar ${email}.';
	@override String get deviceLinked => 'Dat apparaat is nu aan dit account gekoppeld.';
	@override String get checking => 'Controleren…';
	@override String get notLinked => 'Nog niet gekoppeld';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Lokale gegevens vervangen?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${n} activatie',
		other: '${n} activaties',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${n} QSO',
		other: '${n} QSO\'s',
	);
	@override String get counts => 'Gesynchroniseerde gegevens';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Dit apparaat: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Wacht op upload: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Dit apparaat: controleren…';
	@override String get countsServerChecking => 'Server: controleren…';
	@override String get countsServerUnavailable => 'Server: niet beschikbaar';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Dit maakt een back-up van ${operations} en ${qsos} op dit apparaat en wist ze, en downloadt in plaats daarvan de gegevens van het account. De back-up blijft in de database van dit apparaat.';
	@override String get replace => 'Vervangen';
	@override String get pendingBannerTitle => 'Nieuw Ham2K Log Filer-account gedetecteerd';
	@override String get pendingBannerBody => 'Behoud de bestaande activaties en QSO\'s van dit apparaat en voeg ze samen met het account, of vervang ze door de gegevens van het account (in beide gevallen blijft er een back-up op dit apparaat).';
	@override String get combine => 'Samenvoegen';
	@override String get authIssueTitle => 'Synchronisatie kan niet verbinden';
	@override String get authIssueText => 'Ham2K Log Filer blijft dit apparaat weigeren. Controleer je roepnaam in de synchronisatie-instellingen.';
	@override String get openSettings => 'Synchronisatie-instellingen openen';
}

// Path: settings.accounts
class _Translations$settings$accounts$nl extends Translations$settings$accounts$en {
	_Translations$settings$accounts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Accounts, diensten & gegevensbronnen';
	@override String get none => 'Geen actieve extensies met accounts';
	@override String get notConfigured => 'Niet geconfigureerd';
	@override String get connected => 'Verbonden';
	@override String get cancelLogin => 'Aanmelden annuleren';
	@override String get openInBrowser => 'Openen in browser';
	@override String loggedInAs({required Object identity}) => 'Ingelogd als ${identity}';
	@override String get pressSaveToKeep => 'Druk op Opslaan om dit account verbonden te houden.';
	@override String connectedTo({required Object label}) => 'Verbonden met ${label}';
	@override String get connect => 'Verbinden';
	@override String get disconnect => 'Verbinding verbreken';
	@override String get connectedAs => 'Verbonden als';
	@override String get test => 'Testen';
	@override String saveFailed({required Object error}) => 'Opslaan mislukt: ${error}';
	@override String loginFailed({required Object error}) => 'Inloggen mislukt: ${error}';
	@override String get lookupFailed => 'Accounts zijn nu niet beschikbaar — probeer het zo opnieuw';
	@override String get browserLoginTitle => 'Rond het inloggen af in je webbrowser';
	@override String browserLoginSteps({required Object prefix}) => 'Als je klaar bent, probeert de browser een link te openen die begint met "${prefix}". Op je computer is waarschijnlijk niets ingesteld om die te openen, dus kopieer die link (uit de adresbalk, of van de foutpagina die de browser toont) en plak hem hier.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger kon je browser niet openen. Kopieer de inloglink hieronder en open hem zelf, kopieer dan de link waarnaar je wordt doorgestuurd (die begint met "${prefix}") en plak die hier.';
	@override String get copyLoginLink => 'Inloglink kopiëren';
	@override String get pastedLinkLabel => 'Plak de link hier';
	@override String get finishLogin => 'Inloggen afronden';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Dat is niet de inloglink — die moet beginnen met "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Die link hoort bij een andere inlogpoging. Sluit deze pagina en verbind opnieuw.';
	@override String get pastedLinkNoCode => 'Die link bevat geen inlogcode. Rond eerst het inloggen af en kopieer dan de link waarnaar je wordt doorgestuurd.';
	@override String get pastedLinkMalformed => 'Die link lijkt afgekapt. Kopieer hem helemaal en plak hem opnieuw.';
	@override String get relayLoginWaiting => 'Wachten tot je het inloggen afrondt — daarna gaat dit automatisch verder.';
	@override String get loginNoResponse => 'Dit apparaat heeft nog niets van het inloggen gehoord. Als je al klaar bent in je browser, annuleer en probeer opnieuw te verbinden.';
	@override String get relayLoginNotOpened => 'Ham2K Logger kon je browser niet automatisch openen. Gebruik de knop hieronder om de inlogpagina zelf te openen.';
	@override String get relayLoginUnavailable => 'Kon de synchronisatieserver die nodig is om dit inloggen af te ronden niet bereiken. Controleer je verbinding en probeer het opnieuw.';
	@override String get loginIncompleteResponse => 'Die inlogpoging is niet goed afgerond. Probeer opnieuw te verbinden.';
	@override String get noKeyringTitle => 'Accountgegevens kunnen niet worden opgeslagen';
	@override String get noKeyringText => 'Ham2K Logger kan geen keyring-dienst op deze computer bereiken, dus accountgegevens kunnen niet worden opgeslagen of gelezen — een account verbinden mislukt totdat dit is opgelost. Installeer en start **gnome-keyring**, **KWallet** of **KeePassXC**, of ontgrendel de keyring die je al hebt, en herstart. Loggen, exports en gegevensbestanden werken gewoon; logsynchronisatie blijft zolang uit.';
	@override String get noKeyringInline => 'Aanmeldgegevens kunnen niet worden opgeslagen: de keyring van deze computer is onbereikbaar. Installeer en start gnome-keyring, KWallet of KeePassXC, of ontgrendel de keyring die je hebt.';
	@override String get noSecureStorageInline => 'Aanmeldgegevens kunnen niet worden opgeslagen: de beveiligde opslag van deze computer is onbereikbaar.';
}

// Path: settings.station
class _Translations$settings$station$nl extends Translations$settings$station$en {
	_Translations$settings$station$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stationsconfiguratie & CAT-besturing';
	@override String get none => 'Geen apparatuur geconfigureerd';
	@override String get add => 'Toevoegen';
	@override String get addTitle => 'Apparatuur toevoegen';
	@override String get searchHint => 'Apparatuur zoeken';
	@override String get noMatches => 'Geen apparatuur gevonden';
	@override String get detectedEquipment => 'Gedetecteerde apparatuur';
	@override String discoveryUnavailable({required Object error}) => 'Kan niet naar radio\'s luisteren: ${error}';
	@override String get edit => 'Apparatuur bewerken';
	@override String get name => 'Naam';
	@override String get nameDescription => 'Hoe je het noemt — "Linker radio". Optioneel.';
	@override String get transport => 'Verbinding';
	@override String get host => 'Adres';
	@override String get hostDescription => 'De hostnaam of het IP-adres van de radio op je netwerk.';
	@override String get port => 'Poort';
	@override String get hostRequired => 'Een adres is verplicht';
	@override String get portInvalid => 'Poort moet tussen 1 en 65535 liggen';
	@override String get connect => 'Verbinden';
	@override String get disconnect => 'Verbinding verbreken';
	@override String get remove => 'Verwijderen';
	@override String removeTitle({required Object name}) => '${name} verwijderen?';
	@override String get removeMessage => 'Dit verwijdert het alleen uit de app. De instellingen van de apparatuur blijven zoals ze zijn.';
	@override String unknownType({required Object typeKey}) => 'Onbekend apparatuurtype "${typeKey}"';
	@override String get report => 'Melden';
	@override String get reportTitle => 'Deze radio melden';
	@override String get reportIntro => 'Vertel ons welke radio dit echt is en hoe het ging. Je melding wordt een kaart die het Ham2K-team leest, en wat je schrijft over hoe je het werkend kreeg kan de volgende operator met dezelfde rig helpen.';
	@override String get reportManufacturer => 'Fabrikant';
	@override String get reportManufacturerDescription => 'Wie maakt hem — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Een fabrikant is verplicht';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'Het model, zoals de radio zelf het noemt — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'Een model is verplicht';
	@override String get reportOutcome => 'Hoe ging het?';
	@override String get reportOutcomeWorks => 'Werkte goed';
	@override String get reportOutcomeIssues => 'Werkte, met problemen';
	@override String get reportOutcomeFails => 'Werkte helemaal niet';
	@override String get reportOutcomeRequired => 'Vertel ons hoe het ging';
	@override String get reportComments => 'Opmerkingen';
	@override String get reportCommentsPlaceholder => 'Wat werkte, wat niet, alles wat je verraste.';
	@override String get reportHints => 'Tips voor probleemoplossing';
	@override String get reportHintsPlaceholder => 'Wil je tips voor probleemoplossing voorstellen voor andere gebruikers?';
	@override String get reportSend => 'Melding versturen';
	@override String get reportSending => 'Je melding wordt verstuurd…';
	@override String reportSent({required Object ref}) => 'Bedankt — je melding is geregistreerd als ${ref}.';
	@override String get reportSentNoRef => 'Bedankt — je melding is verstuurd.';
	@override String reportFailed({required Object error}) => 'De melding is niet verstuurd: ${error}';
	@override String get troubleshootingNotes => 'Notities voor probleemoplossing';
	@override String get mainVfo => 'Hoofd-VFO';
	@override String get useAsMainVfo => 'Gebruiken als hoofd-VFO';
	@override String get serialPort => 'Seriële poort';
	@override String get serialPortDescription => 'De poort waarop de CAT-interface van de radio verschijnt.';
	@override String get serialPortNone => 'Geen seriële poorten gevonden';
	@override String get serialPortRequired => 'Kies een seriële poort';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'poort ${n} van ${total}';
	@override String get serialPortSuggested => 'voorgesteld';
	@override String get serialPortJustNow => 'Recent verbonden';
	@override String get serialDeviceRequest => 'USB-apparaat toevoegen…';
	@override String get baudRate => 'Snelheid (baud)';
	@override String get baudRateDescription => 'Moet overeenkomen met het CAT-menu van de radio. Bij een verschil stuurt de radio onzin terug, zonder foutmelding.';
	@override String get serialRtsHigh => 'RTS hoog houden';
	@override String get serialRtsHighDescription => 'Alleen voor een radio die op RTS wacht voordat hij reageert, zoals een Yaesu met CAT RTS aan. Op een Digirig, SignaLink en de meeste zelfgemaakte kabels is RTS de PTT, en hoog houden zet de zender aan.';
	@override String get serialDtrHigh => 'DTR hoog houden';
	@override String get serialDtrHighDescription => 'Alleen voor een CAT-interface die zijn voeding uit DTR haalt, zoals sommige RS-232-kabels voor de FT-817. Op veel kabels keyt DTR de CW of PTT, en hoog houden zet de zender aan.';
	@override String get civAddress => 'CI-V-adres van de radio';
	@override String get civAddressDescription => 'Hexadecimaal, zoals getoond in het CI-V-menu van de radio. De IC-705 wordt geleverd met A4.';
	@override String get civAddressInvalid => 'Een CI-V-adres bestaat uit twee hexcijfers, 01 tot FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Welke slice van de radio deze verbinding uitleest en afstemt.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Kies een van de slices van de radio, A tot en met H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} is niet in gebruik op deze radio — kies een andere slice, of maak hem aan in SmartSDR';
	@override String get channelNotInUse => 'niet in gebruik';
	@override String get channelHeldByUnknown => 'in gebruik door een ander programma';
	@override String get flexNoSlices => 'Deze radio heeft geen slices gemeld — controleer of SmartSDR draait en of deze client zich mag abonneren';
	@override String get spectrumUnsupported => 'Deze radio stuurt geen spectrum via CAT';
	@override String get spectrumRequiresBaud => 'Vereist CAT op 115200 bps';
	@override String get spectrumNoRadio => 'Geen radio verbonden';
	@override String get spectrumWaiting => 'Wachten op het spectrum van de radio…';
	@override String get spectrumUnavailable => 'Spectrumweergave is niet beschikbaar';
	@override String get spectrumNoDaxChannel => 'Elk DAX IQ-kanaal op deze radio is in gebruik';
	@override String get spectrumNoPanadapter => 'Deze slice heeft geen panadapter op de radio';
	@override String spectrumStreamRefused({required Object code}) => 'De radio weigerde een DAX IQ-stream (fout ${code})';
	@override String get spectrumNoUdp => 'De spectrumgegevens van de radio kunnen dit apparaat niet bereiken';
	@override String get spectrumScopeRefused => 'De radio weigerde zijn scope-commando\'s';
	@override String get spectrumOutOfRange => 'De scope van de radio staat buiten het bereik dat hij kan tonen';
	@override String get n3fjpNoRig => 'N3FJP heeft geen radio-interface ingesteld, dus dit volgt wat in N3FJP wordt getypt, niet een radio';
	@override String get winkeyerKeyPort => 'Key-uitgang';
	@override String get winkeyerKeyPortDescription => 'Op welke van de twee uitgangen van de keyer je radio is aangesloten.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Poort ${n}';
	@override String get winkeyerPtt => 'PTT van de keyer gebruiken';
	@override String get winkeyerPttDescription => 'Keyt de PTT-lijn op dezelfde aansluiting, voor een versterker of radio die dat nodig heeft. Laat uit voor een radio die via zijn key-aansluiting wordt gekeyd.';
	@override String get winkeyerNoAnswer => 'Geen WinKeyer reageerde op deze poort';
	@override String get winkeyerStoppedAnswering => 'De WinKeyer reageerde niet meer tijdens het verzenden; het bericht is vervallen';
	@override String get radioUser => 'Gebruikersnaam radio';
	@override String get radioPass => 'Wachtwoord radio';
	@override String get radioLoginDescription => 'De login onder Network → Remote van de radio, niet je wifi-wachtwoord.';
	@override String get radioUserRequired => 'De gebruikersnaam voor bediening op afstand van de radio is verplicht';
	@override String get connectFailedBusy => 'Apparaat is in gebruik';
	@override String get connectFailedDenied => 'Toegang geweigerd';
	@override String get connectFailedDevice => 'Apparaat niet gevonden';
	@override String get connectFailedLines => 'RTS/DTR konden niet worden gehouden zoals ingesteld, dus de poort is gesloten. Mogelijk heeft een ander programma hardware-handshaking aan laten staan — koppel de kabel los en weer aan.';
	@override String get connectFailedNetwork => 'Kan de radio niet vinden via het netwerk. Controleer het adres en of hij aan staat en bereikbaar is.';
	@override String get connectFailedTimeout => 'De radio reageerde niet op tijd. Controleer of hij aan staat en bereikbaar is.';
	@override late final _Translations$settings$station$models$nl models = _Translations$settings$station$models$nl._(_root);
	@override late final _Translations$settings$station$transports$nl transports = _Translations$settings$station$transports$nl._(_root);
	@override String get troubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get ft891Troubleshooting => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **CAT RTS moet UIT staan op de radio** (FT-891-menu **05-08**). Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt. Op een Digirig, SignaLink of de meeste zelfgebouwde kabels is diezelfde lijn de PTT, dus hoog zetten zou je zender aanzetten. Op de eigen USB-poort van de radio is **RTS hoog houden** onder Geavanceerde instellingen het alternatief.\n- **Snelheid moet overeenkomen** met de CAT RATE van de radio (menu **05-06**). Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get yaesuBinaryTroubleshooting => 'Deze radio spreekt het oudere vijf-byte CAT van Yaesu, en reageert helemaal niet als er iets niet klopt. Bijna altijd een van deze:\n\n- **De kabel moet niveaus omzetten.** De CAT-aansluiting achterop is geen RS-232 en geen USB; er is een CT-62 of gelijkwaardige adapter nodig. Een gewone audio- of datakabel werkt niet voor CAT.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio (**#14** op een FT-817, **#19** op een FT-857 of FT-897). Bij een verschil stuurt de radio niets terug, en nooit een foutmelding.\n- **Laat nooit iets RTS of DTR hoog zetten op deze poort.** Op de meeste kabels voor deze radio\'s zijn die lijnen PTT en keying. Een oudere interface die gevoed wordt uit DTR is de uitzondering: zet daarvoor **DTR hoog houden** aan onder Geavanceerde instellingen.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\nDeze driver is geschreven op basis van Yaesu\'s gepubliceerde CAT-overzicht en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.';
	@override String get guohetecTroubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get guohetecTroubleshooting => 'De Q900 heeft twee CAT-protocollen, en deze optie gebruikt het eigen protocol in plaats van de FT-817-imitatie. Kies hier **Guohetec Q900**, geen FT-817 — de imitatie ondersteunt minder commando\'s, en de radio meldt niet welke hij gebruikt.\n\n- **De USB-C-kabel is de CAT-verbinding**, en verbindt ook de geluidskaart. Snelheid maakt daarbij niet uit; de poort negeert wat er is ingesteld.\n- **Laat nooit iets RTS of DTR hoog zetten op deze poort.** Op een seriële kabel zijn die lijnen PTT en keying.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Een radio van de tweede generatie gedraagt zich anders** dan een van de eerste. Houd Menu lang ingedrukt, dan About: HW 2.0 is de tweede generatie.\n\nDeze driver is geschreven op basis van het gepubliceerde protocol van de fabrikant en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.';
	@override String get yaesuTroubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get yaesuTroubleshooting => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt. Op een Digirig, SignaLink of de meeste zelfgebouwde kabels is diezelfde lijn de PTT, dus hoog zetten zou je zender aanzetten. Op de eigen USB-poort van de radio is **RTS hoog houden** onder Geavanceerde instellingen het alternatief. Waar die instelling zit verschilt per model (menu **05-08** op een FT-891).\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Modes volgen de tabel van de FT-891.** De meeste Yaesu\'s komen daarmee overeen, maar een radio die zijn modes anders nummert toont en zet voor die modes de verkeerde. De frequentie blijft correct.';
	@override String get yaesuRs232Troubleshooting => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **De CAT-aansluiting is RS-232.** Er is een USB-naar-serieel-adapter en een rechte DB-9-kabel nodig — een null-modemkabel verwisselt de lijnen, en de radio hoort helemaal niets.\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt, tenzij **RTS hoog houden** aan staat onder Geavanceerde instellingen.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\nDeze optie is geschreven op basis van gepubliceerde CAT-documentatie en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.';
	@override String get yaesuUsbTroubleshooting => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **Gebruik de eerste van de twee USB-poorten van de radio.** CAT zit normaal op de eerste (de **Enhanced** COM-poort op Windows); de tweede (**Standard**) is voor PTT en keying. De keuzelijst wijst de eerste aan als hij de twee kan onderscheiden.\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt, tenzij **RTS hoog houden** aan staat onder Geavanceerde instellingen.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.';
	@override String get k4SerialNotes => 'Sluit de USB-B (PC)-aansluiting achterop de K4 aan. USB-PC1 en USB-PC2 werken allebei voor CAT; kies een ongebruikte poort en stel de bijbehorende Serial USB-PCn: Baud Rate op de radio gelijk in. HaLo vult 38400 vooraf in; wijzig dat zo nodig. Een andere applicatie moet de andere poort of Ethernet gebruiken.\n\nDeze verbinding bestuurt de radio en zijn keyers; ze stuurt geen audio naar HaLo.';
	@override String get k4TcpNotes => 'Sluit de Ethernet-aansluiting van de K4 aan op je lokale netwerk. Voer de hostnaam of het IP-adres in en CAT-poort 9200. Dit is CAT-besturing, niet de aparte remote-audioverbinding op poort 9204.\n\nHaLo bestuurt de radio en zijn keyers zonder audio of panadaptergegevens te streamen.';
	@override String get k4PowerTimeout => 'Het K4-vermogen is niet gewijzigd omdat de radio zijn uitgangsbereik niet bevestigde. Probeer het opnieuw.';
	@override String get k4PowerRange => 'K4-vermogen moet 0,1–110 W zijn, of 0,0001–0,01 W als de milliwatt-transverteruitgang actief is.';
	@override String get elecraftTroubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get elecraftTroubleshooting => 'Elecraft-rigs spreken Kenwood-CAT, en zowel een KX2 als een KX3 zijn zo gebruikt — VFO in beide richtingen, modewissel en CW zero-beat werken allemaal.\n\nAls de radio niet reageert, bijna altijd een van deze:\n\n- **Snelheid moet overeenkomen** met de snelheid onder **RS232** in het menu van de radio. Ze worden geleverd met 38400. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\n**Als de frequentie klopt maar de mode niet**, laat het ons weten. De KX2- en KX3-opties lezen de mode uit een positie in het statusantwoord van de radio die we hebben vastgesteld op basis van de rigs die we kennen, en firmware die hem ergens anders zet merken we alleen via een melding.\n\nVan de K3 is nog niets gemeld, dus laat weten wat er gebeurt als je er een gebruikt. Een K4 heeft een eigen optie.';
	@override String get kenwoodTroubleshootingTitle => 'Als de radio verbindt maar geen frequentie toont';
	@override String get kenwoodTroubleshooting => 'Deze driver is getest met de TS-590SG en TS-480 van Kenwood, de QMX en QCX-mini van QRP Labs, en de KX2 en KX3 van Elecraft. De rest van de reeks is geschreven op basis van gepubliceerde CAT-referenties, dus meld wat er gebeurt, hoe dan ook.\n\nAls de radio niet reageert, bijna altijd een van deze:\n\n- **Snelheid moet overeenkomen** met het CAT-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Sommige rigs hebben CAT ingeschakeld nodig** in het menu voordat ze überhaupt reageren.\n\n**Diverse SDR-front-ends spreken hetzelfde protocol**, dus het is de moeite waard deze optie ook daarvoor te proberen; Elecraft-rigs staan apart, onder Elecraft. Als de frequentie klopt maar de mode fout is of ontbreekt: dat is het enige deel dat binnen de reeks verschilt — de app leidt het af uit de radio en vraagt het anders direct op, dus de mode kan gewoon wat achterlopen.';
	@override String get statusConnected => 'Verbonden';
	@override String get statusLost => 'Verbinding verbroken';
	@override String get notConfigured => 'Niet geconfigureerd';
	@override String get currentConfiguration => 'Huidige configuratie';
	@override String get currentTransceiver => 'Huidige transceiver';
	@override String get radioMode => 'Radiomode';
	@override String get keyerNotSupported => 'Niet ondersteund door huidige radio';
	@override String get catControlPreferences => 'Voorkeuren CAT-besturing';
	@override String get chooseTransceiver => 'Kies transceiver';
	@override String get configurationSection => 'Configuratie';
	@override String get noTransceiverSelected => 'Geen transceiver geselecteerd';
	@override String makeMainVfo({required Object name}) => '${name} gebruiken voor de hoofd-VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		zero: 'Geen transceivers',
		one: '${count} transceiver',
		other: '${count} transceivers',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} antenne',
		other: '${count} antennes',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} ander apparaat',
		other: '${count} andere apparaten',
	);
	@override String get equipmentInventory => 'Apparatuuroverzicht';
	@override String get equipmentInUse => 'Transceiverbediening';
	@override String get noTransceiver => 'Geen';
	@override String get peerRadioNotAvailable => 'Niet beschikbaar';
	@override String peerRadioOnDevice({required Object device}) => 'Op ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} zit op een ander apparaat';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Deze radio is verbonden met ${device}. De verbinding en instellingen worden op dat apparaat geconfigureerd.';
	@override String get antennaInUse => 'Antenne in gebruik';
	@override String get keyInUse => 'Seinsleutel in gebruik';
	@override String get noneSelected => 'Geen';
	@override String get moreSettings => 'Meer instellingen';
	@override String get icomCivTroubleshootingTitle => 'Als er twee seriële poorten voor dezelfde radio verschijnen';
	@override String get icomCivTroubleshooting => 'Diverse Icom-radio\'s, waaronder de IC-705, tonen **twee** USB-seriële poorten tegelijk (Icom noemt ze Port A en Port B), beide standaard ingesteld op CI-V. Verder kunnen deze app en je besturingssysteem ze niet onderscheiden: dezelfde USB vendor/product-ID verschijnt gewoon twee keer, soms hier gemarkeerd met een achtervoegsel `#2`. **Port A is meestal de juiste** — normaal de eerste die je besturingssysteem of browser toont, en als deze app de twee poorten kan onderscheiden, markeert ze die als voorgesteld. Als er commando\'s uitgaan en de radio nooit reageert, probeer dan de andere poort.';
	@override String get civAddressTroubleshootingTitle => 'Als de radio nooit reageert';
	@override String get civAddressTroubleshooting => '- **Het CI-V-adres moet overeenkomen** met het menu van de radio. Deze optie vult het fabrieksadres van het model vooraf in, maar juist bij een rig op een gedeelde CI-V-bus wordt dat gewijzigd. Een frame naar het verkeerde adres wordt stil genegeerd, wat er precies uitziet als een defecte kabel.\n- **Snelheid moet overeenkomen** met de CI-V BAUD RATE van de radio (via USB: CI-V USB Baud Rate). Stel de radio in op hetzelfde getal als hier, **niet Auto**. Op Auto verbinden sommige radio\'s, waaronder de IC-7300, en reageren ze na een minuut of zo niet meer.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.';
	@override String get ic7300Mk2Note => '\n- De **IC-7300 MK2** wordt geleverd met adres `B6`, niet de hier ingevulde `94` — kies in plaats daarvan de optie IC-7300 MK2.';
	@override String get ic705PortNote => '\n- De **IC-705** toont twee USB-seriële poorten, beide vernoemd naar de radio. CI-V zit op de **eerste**, die de keuzelijst aanwijst als hij de twee kan onderscheiden.';
	@override String get ic7760PortNote => '\n- De **IC-7760** spreekt CI-V op **Port A** van de twee USB-seriële poorten die hij toont.';
	@override String get x6100PortNote => '\n- De **X6100** spreekt CI-V op zijn **DEV**-poort — de tweede van de twee seriële poorten die hij toont, en de poort die de keuzelijst aanwijst.';
	@override String get rigctldTroubleshootingTitle => 'Als de app geen verbinding kan maken';
	@override String get rigctldTroubleshooting => 'Dit verbindt met een **rigctld-daemon die je zelf draait**, niet direct met de radio — de backend van Hamlib praat met de radio en ondersteunt honderden modellen.\n\n- **De daemon moet al draaien**, bijv. `rigctld -m 1035 -r /dev/ttyUSB0`. Zoek het modelnummer van je radio op met `rigctl -l`.\n- **Vanaf een andere machine** start je hem met `-T 0.0.0.0`: standaard accepteert rigctld alleen verbindingen van de machine waarop hij draait.\n- **Poort** is 4532, tenzij je de daemon met `-t` hebt gestart.\n- Eenmaal verbonden betekent een ontbrekende frequentie meestal dat de daemon zelf de radio niet bereikt. Test het met `rigctl -m 2 f` op de machine van de daemon.';
	@override String get flrigTroubleshootingTitle => 'Als de app geen verbinding kan maken';
	@override String get flrigTroubleshooting => 'Dit verbindt met een **flrig-programma dat je zelf draait**, niet direct met de radio — flrig praat met de radio en ondersteunt de meeste merken en modellen.\n\n- **flrig moet al draaien**, met de transceiver geconfigureerd en verbonden.\n- **Poort** is 12345, tenzij je dat in de configuratie van flrig hebt gewijzigd (Config → Setup → Server).\n- **Vanaf een andere machine**: zorg dat de server van flrig bereikbaar is. Hij luistert op alle interfaces, maar je firewall is het daar misschien niet mee eens.\n- Eenmaal verbonden betekent een ontbrekende frequentie meestal dat flrig zelf de radio niet bereikt. Controleer of het display van flrig de afstemknop volgt.';
	@override String get hrdTroubleshootingTitle => 'Als de app geen verbinding kan maken';
	@override String get hrdTroubleshooting => 'Dit verbindt met **Rig Control van Ham Radio Deluxe, draaiend op je computer**, niet direct met de radio — HRD praat met de radio.\n\n- **Rig Control moet al draaien** en met de radio verbonden zijn.\n- **De IP-server ervan moet ingeschakeld zijn.** Rig Control praat alleen via die server met andere programma\'s.\n- **Poort** is 7809, tenzij je die in de instellingen van de IP-server hebt gewijzigd.\n- **Vanaf een andere machine**: zorg dat je firewall de verbinding doorlaat.\n\nDeze optie is geschreven op basis van gepubliceerde beschrijvingen van het HRD-protocol en is nog niet met HRD getest. Als hij half werkt, is dat het melden waard.';
	@override String get n3fjpTroubleshootingTitle => 'Als de app geen verbinding kan maken';
	@override String get n3fjpTroubleshooting => 'Dit verbindt met **een N3FJP-logprogramma dat op je computer draait**, niet direct met de radio — N3FJP praat met de radio.\n\n- **De API van het programma moet aan staan**: Settings → Application Program Interface, vink **TCP API Enabled** aan.\n- **Poort** is 1100, tenzij je die daar hebt gewijzigd.\n- **N3FJP moet een radio-interface ingesteld hebben** om de radio te volgen of af te stemmen. Zonder interface meldt het alleen wat in het invoervenster wordt getypt.\n- N3FJP meldt alleen band, mode en frequentie: geen vermogen, geen zendstatus.\n\nDeze optie is geschreven op basis van de gepubliceerde API van N3FJP en is nog niet met N3FJP getest. Als hij half werkt, is dat het melden waard.';
	@override String get commanderTroubleshootingTitle => 'Als de app geen verbinding kan maken';
	@override String get commanderTroubleshooting => 'Dit verbindt met **DXLab Commander, draaiend op je computer**, niet direct met de radio — Commander praat met de radio.\n\n- **Commander moet al draaien** en met de radio verbonden zijn.\n- **De netwerkdienst moet aan staan**: de knop **Net Serv** in het Radio-paneel van het Configuration-venster van Commander.\n- **Poort** is 52002, de derde poort van het blok dat begint bij de **Base Port** van Net Serv (52000, tenzij je die hebt gewijzigd).\n- **Vanaf een andere machine**: zorg dat je firewall de verbinding doorlaat.\n\nDeze optie is geschreven op basis van de gepubliceerde TCP-berichten van Commander en is nog niet met Commander getest. Als hij half werkt, is dat het melden waard.';
	@override String get ic705TroubleshootingTitle => 'Als de radio nooit reageert';
	@override String get ic705Troubleshooting => 'De radio heeft **één enkele** sessie voor bediening op afstand. Als de login wordt genegeerd, gebruikt bijna altijd iets anders die sessie.\n\n- **Sluit elke andere client.** wfview of RS-BA1 verbonden met dezelfde radio houdt die ene sessie bezet, en de login hier wordt zolang gewoon genegeerd.\n- **Controleer de netwerkinstellingen van de radio.** WLAN moet aan staan, de radio moet op hetzelfde netwerk zitten, en de functie voor bediening op afstand (Network) moet ingeschakeld zijn.\n- **Zet de WLAN van de radio uit en weer aan** als hij vast blijft zitten. Dat ruimt een vastgelopen sessie op de radio betrouwbaar op.\n\nEen **verkeerd wachtwoord wordt expliciet geweigerd**, niet met stilte beantwoord. Als je hier terechtkwam in plaats van bij een melding "geweigerd", is het wachtwoord niet het probleem.';
	@override String get statusStale => 'Reageert niet';
	@override String get statusDisconnected => 'Niet verbonden';
	@override String get statusConnecting => 'Verbinden…';
	@override String get statusDisconnecting => 'Verbinding verbreken…';
	@override String get statusError => 'Verbinding mislukt';
	@override String get currentRadioSettings => 'Huidige radio-instellingen';
	@override String get notSupportedByThisRadio => 'Niet ondersteund door deze radio';
	@override String get keyerRowLabel => 'Keyer';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Spraak';
	@override String voiceKeyerAvailable({required Object count}) => 'Spraakkeyer: ${count} geheugens in de radio';
	@override String get antennaBands => 'Banden';
	@override String get antennaType => 'Antennetype';
	@override String get antennaTypeRequired => 'Kies een antennetype';
	@override late final _Translations$settings$station$antennaTypes$nl antennaTypes = _Translations$settings$station$antennaTypes$nl._(_root);
	@override String get keyType => 'Type seinsleutel';
	@override String get keyTypeRequired => 'Kies een type seinsleutel';
	@override late final _Translations$settings$station$keyTypes$nl keyTypes = _Translations$settings$station$keyTypes$nl._(_root);
	@override String get softwareIntermediaries => 'Tussenliggende software';
	@override String get otherBrands => 'Andere merken';
	@override String get otherEquipment => 'Andere apparatuur (antennes, seinsleutels, enz.)';
	@override String get newAntenna => 'Nieuwe antenne';
	@override String get newKey => 'Nieuwe seinsleutel';
	@override String get newKeyer => 'WinKeyer (K1EL of compatibel)';
	@override String keyViaRadio({required Object radio}) => 'CAT-keyer in ${radio}';
	@override String keyOnDevice({required Object device}) => 'Seinsleutel op ${device}';
	@override String get cwKeyerArea => 'Keyergebied';
	@override String get trackStationInfo => 'Stationsinfo per QSO bijhouden';
	@override String get includeStationInfoInAdif => 'Opnemen in ADIF-exports';
	@override String get whatToTrack => 'Wat bijhouden?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Vermogen';
	@override String get watts => 'Watt';
	@override String get trackFieldAntenna => 'Antenne';
	@override String get trackFieldKey => 'CW-seinsleutel';
	@override String get placeholderConnectDelay => 'Verbindingsvertraging (ms)';
	@override String get placeholderConnectDelayDescription => 'Hoe lang de gesimuleerde handshake duurt. Leeg of 0 verbindt meteen.';
	@override String get placeholderDropAfter => 'Verbreken na (seconden)';
	@override String get placeholderDropAfterDescription => 'Verbreekt de verbinding vanzelf, om het opnieuw verbinden te testen. Leeg of 0 verbreekt nooit.';
	@override String get placeholderFailConnect => 'Verbinden altijd laten mislukken';
	@override String get placeholderConnectFailure => 'De tijdelijke radio is opgedragen deze verbinding te weigeren';
	@override String get placeholderFreq => 'Frequentie (kHz)';
	@override String get placeholderFreqDescription => 'Waar de tijdelijke radio begint. Daarna meldt hij terug waarop de app hem ook afstemt.';
	@override String get placeholderMode => 'Mode';
	@override String get placeholderModeDescription => 'De mode waarmee de tijdelijke radio begint, bijv. USB, CW, FT8.';
	@override String get placeholderPower => 'Vermogen (watt)';
	@override String get placeholderPurpose => 'Gebruik deze radio om bij te houden welke rig je gebruikt, voor je logboek';
	@override String get placeholderReplyDelay => 'Antwoordvertraging (ms)';
	@override String get placeholderReplyDelayDescription => 'Hoe lang de tijdelijke radio erover doet om een wijziging terug te melden. Leeg of 0 meldt meteen.';
	@override String get cwKeyerField => 'CAT CW-keyer';
	@override String get cwKeyerFieldDescription => 'Of deze radio CW keyt vanuit tekst via CAT. Uit voor een rig die de app niet kent.';
	@override String get voiceMemories => 'Spraakgeheugens';
	@override String get voiceMemoriesDescription => 'Hoeveel spraakgeheugens de radio via CAT afspeelt. 0 voor geen.';
	@override String get voiceMemoriesInvalid => 'Een geheel getal, 0 of meer';
	@override String get yaesuMeterCapture => 'Meteruitlezingen vastleggen';
	@override String get yaesuBinaryMeterCaptureDescription => 'Leest tijdens het zenden de vermogensmeter en de hoge-SWR-vlag van de radio uit en schrijft de ruwe waarden naar het log. Bedoeld om de schaal op te bouwen die Yaesu niet publiceert — de waarden worden niet als meters getoond.';
	@override String get yaesuMeterCaptureDescription => 'Leest tijdens het zenden de PO-, SWR- en ALC-meters van de radio uit en schrijft de ruwe waarden naar het log. Bedoeld om de schaal op te bouwen die Yaesu niet publiceert — de waarden worden niet als meters getoond.';
	@override String get telemetryInterval => 'Interval meteruitlezing (ms)';
	@override String get telemetryIntervalDescription => 'Hoe vaak de meters van de radio tijdens het zenden worden uitgelezen. Laat leeg voor het snelste wat deze verbinding aankan, tot 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Een geheel aantal milliseconden, ${min} tot ${max}';
	@override String get pollInterval => 'Pollinginterval in rust (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Hoe vaak de radio om frequentie en mode wordt gevraagd zolang geen van beide verandert. Laat leeg voor ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Een geheel aantal milliseconden, ${min} tot ${max}';
	@override String get advancedSettings => 'Geavanceerde instellingen';
	@override String get placeholderSwr => 'SWR-waarde';
	@override String get placeholderSwrDescription => 'Wat deze radio tijdens het zenden op zijn SWR-meter meldt. Boven 1,8 waarschuwt het paneel.';
	@override String get placeholderSwrInvalid => 'Een getal, 1 of meer';
	@override String get keyerNone => 'Geen';
	@override String get cwDialect => 'CW-keyingdialect';
	@override String get cwDialectDescription => 'Welke vorm van het KY-commando deze radio gebruikt. Geen betekent geen CW-keying via CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, aangevuld tot 24)';
	@override String get cwDialectElecraft => 'Elecraft (KY-tekst)';
	@override String get voiceDialect => 'Spraakkeyerdialect';
	@override String get voiceDialectDescription => 'Hoe deze radio zijn spraakgeheugens via CAT afspeelt. Geen betekent geen spraakgeheugens via CAT. Met een dialect en zonder aantal geldt het standaardaantal van het dialect.';
	@override String get voiceDialectPb => 'Kenwood (PB, TS-590-stijl)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB en DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (schakeltikken)';
	@override String get placeholderDiagnostic => 'Gesimuleerd';
	@override String get placeholderWholeNumberInvalid => 'Moet een geheel getal zijn, 0 of meer';
	@override String get placeholderFreqInvalid => 'Moet een frequentie in kHz zijn, groter dan nul';
	@override String get placeholderModeInvalid => 'Moet een modenaam zijn, bijv. USB, CW, FT8';
	@override String get switchLayout => 'Indeling';
	@override String get switchLayoutDescription => 'Op welke kant van de schakelaar je radio\'s zijn aangesloten.';
	@override String get switchLayoutRequired => 'Kies hoe de schakelaar is bedraad';
	@override String switchCommandRefused({required Object command, required Object code}) => 'De schakelaar weigerde "${command}" (fout ${code})';
	@override String get switchBusyTransmitting => 'Die poort is aan het zenden — antenne niet gewijzigd';
	@override String get switchNoAntenna => 'Geen';
	@override String switchAntennaFor({required Object port}) => 'Antenne op poort ${port}';
	@override String get switchAntennaForDescription => 'Welke van je antennes op deze poort van de schakelaar is aangesloten.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antennes, ${radios} radio\'s';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antennes, 1 radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antenne, ${radios} radio\'s';
	@override String get switchCommonPort => 'Gemeenschappelijk';
	@override String get dcnAddress => 'Apparaatadres';
	@override String get dcnAddressDescription => 'Het adres dat met de DIP-schakelaars van de module is ingesteld. Een coaxrelaismodule komt af fabriek op 2.';
	@override String get dcnAddressRequired => 'Moet een apparaatadres van 1 tot 99 zijn';
	@override String switchPortLabel({required Object port}) => 'Poort ${port}';
	@override String get switchPortAutoHint => 'volgt banddata';
	@override String get switchPortTransmittingHint => 'zendt — kan nu niet wijzigen';
	@override String get switchCurrentStateHeader => 'Huidige status';
	@override String get switchCurrentStateDescription => 'Op welke antenne elke radiopoort nu staat. Wijzigingen werken meteen.';
	@override String get switchWiringHeader => 'Bedrading';
	@override String get switchPortInhibitedHint => 'zenden geblokkeerd';
	@override String get configUnreadable => 'De opgeslagen instellingen van deze radio konden niet worden gelezen. Open de instellingen en voer ze opnieuw in, of verwijder de radio en voeg hem opnieuw toe.';
	@override String get autoConnectHeld => 'HaLo reageerde niet meer de vorige keer dat het met deze radio verbond, dus het heeft deze keer niet vanzelf verbonden. Druk op Verbinden om het opnieuw te proberen.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$nl extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Offline gegevens';
	@override String get noFiles => 'Geen gegevensbestanden';
	@override String get noFilesDescription => 'Schakel activiteits- of opzoekextensies in om hier hun offline gegevens te downloaden.';
	@override String get refresh => 'Verversen';
	@override String get refreshing => 'Verversen…';
	@override String get updateAll => 'Alles bijwerken';
	@override String get updatingAll => 'Alle gegevensbestanden bijwerken…';
	@override String get neverDownloaded => 'Nooit gedownload';
	@override String get updatedJustNow => 'Zojuist bijgewerkt';
	@override String updatedDaysAgo({required Object days}) => '${days}d geleden bijgewerkt';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '${days}d ${hours}u geleden bijgewerkt';
	@override String updatedHoursAgo({required Object hours}) => '${hours}u geleden bijgewerkt';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '${hours}u ${minutes}m geleden bijgewerkt';
	@override String updatedMinutesAgo({required Object minutes}) => '${minutes}m geleden bijgewerkt';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'De laatste download had maar ${imported} van ${existing} records en is niet gebruikt. Ververs om hem te accepteren.';
	@override String get extensionsSection => 'Extensies';
}

// Path: settings.profiles
class _Translations$settings$profiles$nl extends Translations$settings$profiles$en {
	_Translations$settings$profiles$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Niet ingesteld';
	@override String get personalInfo => 'Persoonlijke gegevens';
	@override String get personalInfoNote => 'Dit kan worden opgenomen in gegenereerde logboeken als het relevant is voor inzendingen';
	@override String get name => 'Naam';
	@override String get email => 'E-mail';
	@override String get club => 'Club';
	@override String get arrlSection => 'ARRL Sectie';
	@override String get racSection => 'RAC Sectie';
	@override String get section => 'Sectie';
}

// Path: settings.search
class _Translations$settings$search$nl extends Translations$settings$search$en {
	_Translations$settings$search$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Wissen';
	@override String get hint => 'Instellingen zoeken';
}

// Path: settings.developer
class _Translations$settings$developer$nl extends Translations$settings$developer$en {
	_Translations$settings$developer$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Ontwikkelaarswaarschuwingen, debuglogs en hulpmiddelen inschakelen.';
	@override String get experiments => 'Experimenten';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} ingeschakeld',
		other: '${count} ingeschakeld',
	);
	@override String get patchTrack => 'Code-push-kanaal';
	@override String get patchTrackDescription => 'Welk over-the-air code-push-kanaal dit apparaat volgt. Avontuurlijkere kanalen krijgen fixes eerder, minder getest. Code-pushes worden bij de volgende herstart toegepast.';
	@override String get trackStable => 'Stabiel';
	@override String get trackUnstable => 'Onstabiel';
	@override String get trackBleeding => 'Bleeding';
	@override String checkingTrack({required Object track}) => '"${track}" controleren op een code-push…';
	@override String get patchDownloaded => 'Code-push gedownload — herstart de app om hem toe te passen.';
	@override String noNewPatch({required Object track}) => 'Geen nieuwe code-push op "${track}".';
	@override String get noPatchInstalled => 'Geen code-push geïnstalleerd — de release-binary draait.';
	@override String runningPatch({required Object patch}) => 'Code-push #${patch} draait.';
	@override String get deepLinks => 'Deep links';
	@override String get registerUrlSchemes => 'URL-schema\'s registreren';
	@override String get registerUrlSchemesDescription => 'com.ham2k://-links deze kopie van de app laten openen';
	@override String get registerUrlSchemesDone => 'Deze kopie opent nu com.ham2k://-links';
	@override String registerUrlSchemesFailed({required Object error}) => 'Kon niet registreren: ${error}';
	@override String get systemInformation => 'Systeeminformatie';
	@override String get appVersion => 'App-versie';
	@override String get dataFolder => 'Gegevensmap';
	@override String get loading => '(laden…)';
	@override String get panelLoadFailed => 'Kon dit instellingenpaneel niet laden.';
	@override String get extDevServer => 'Extensie-devserver';
	@override String get extensionSettings => 'Extensie-instellingen';
	@override String get extDevServerDescription => 'Extensies laden van een devserver op je netwerk in plaats van de ingebouwde, en ze herladen als je opslaat.';
	@override String get extDevServerAddress => 'Serveradres';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Verbinden';
	@override String get extDevServerDisconnect => 'Verbinding verbreken';
	@override String get extDevServerConnecting => 'Verbinden…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Levert ${count} extensie: ${keys}',
		other: 'Levert ${count} extensies: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Niet verbonden';
	@override String get extDevServerReconnect => 'Opnieuw verbinden bij opstarten';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Laatst herladen: ${key} om ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} extensie bouwt niet',
		other: '${count} extensies bouwen niet',
	);
	@override String get catalog => 'Extensiecatalogus';
	@override String get catalogDescription => 'De catalogus van een andere server lezen — een lokale tijdens het werken aan de catalogus zelf. Leeg betekent catalog.ham2k.net.';
	@override String get catalogAddress => 'Catalogusadres';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Kanalen voor catalogus zoeken';
	@override String get catalogSearchStable => 'Alleen stabiel';
	@override String get catalogSearchUnstable => 'Onstabiel of beter';
	@override String get catalogSearchBleeding => 'Bleeding of beter';
}

// Path: settings.about
class _Translations$settings$about$nl extends Translations$settings$about$en {
	_Translations$settings$about$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Mededelingen & berichten';
	@override String get noticesDescription => 'Aankondigingen en statusberichten';
	@override String get releaseNotes => 'Release notes';
	@override String get copiedVersion => 'Versiegegevens naar klembord gekopieerd';
}

// Path: settings.panels
class _Translations$settings$panels$nl extends Translations$settings$panels$en {
	_Translations$settings$panels$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Applicatievoorkeuren';
	@override String get settingsDescription => 'Laat de app werken zoals jij wilt';
	@override String get commonSettings => 'Algemene voorkeuren';
	@override String get syncDescription => 'Back-up en synchronisatie van je logboeken tussen apparaten';
	@override String get accountsDescription => 'Inloggegevens van diensten, offline gegevens en meer';
	@override String get extensions => 'Extensies & functies';
	@override String get extensionsDescription => 'Activiteiten, contests, dashboardpanelen en meer functies';
	@override String get profilesDescription => 'Roepnaam van de operator en stationsprofiel';
	@override String get stationProfiles => 'Stationsprofielen';
	@override String get developerSettings => 'Ontwikkelaar Instellingen';
	@override String get developerSettingsDescription => 'Hulpmiddelen voor debuggen en ontwikkeling';
	@override String get about => 'Over';
	@override String get aboutDescription => 'Versie, credits en juridische informatie';
	@override String get unavailableTitle => 'Sommige instellingen zijn niet beschikbaar';
	@override String get unavailableText => 'De extensieomgeving kon niet starten, dus instellingen van extensies ontbreken.';
	@override String get station => 'Stationsconfiguratie';
	@override String get stationDescription => 'CAT-besturing en meer opties';
	@override String get peers => 'Peer-apparaten';
	@override String get peersDescription => 'Verbinden met andere apparaten in de buurt';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$nl extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Systeeminstellingen volgen';
	@override String get period => 'Altijd punt voor decimalen';
	@override String get comma => 'Altijd komma voor decimalen';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$nl extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => 'Systeeminstellingen (${separator} voor decimalen)';
	@override String get period => 'Altijd punt voor decimalen';
	@override String get comma => 'Altijd komma voor decimalen';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$nl extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get comma => 'komma';
	@override String get period => 'punt';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$nl extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get six => '6 tekens (FN31pr)';
	@override String get eight => '8 tekens (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$nl extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get six => '6 tekens';
	@override String get eight => '8 tekens';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$nl extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get date => 'Datum';
	@override String get time => 'Tijd';
	@override String get freq => 'Frequentie';
	@override String get mode => 'Mode';
	@override String get call => 'Roepnaam';
	@override String get name => 'Naam';
	@override String get station => 'Station';
	@override String get band => 'Band';
	@override String get sent => 'Verz.';
	@override String get rcvd => 'Ontv.';
	@override String get grid => 'Grid';
	@override String get state => 'Staat';
	@override String get country => 'Land';
	@override String get refs => 'Refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$nl extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO-logboek';
	@override String get qsosDescription => 'De QSO\'s van de geselecteerde roepnaam, over alle activaties heen.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Totaal aantal QSO\'s, of de opzoekgegevens van het geselecteerde QSO.';
	@override String get map => 'Kaart';
	@override String get mapDescription => 'De locatie van het geselecteerde QSO.';
}

// Path: home.logs.import
class _Translations$home$logs$import$nl extends Translations$home$logs$import$en {
	_Translations$home$logs$import$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Roepnamen: ${calls}';
	@override String get skippedOne => '1 record kon niet worden gelezen';
	@override String skippedOther({required Object count}) => '${count} records konden niet worden gelezen';
	@override String get readingTitle => 'ADIF-bestand lezen…';
	@override String get checkingTitle => 'Controleren op dubbels…';
	@override String get importingTitle => 'QSO\'s importeren…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} van ${total} gecontroleerd';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} van ${total} geïmporteerd';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$nl extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Het logboek en de invoervelden';
	@override String get infoDescription => 'Wat we weten over het gewerkte station';
	@override String get spotsDescription => 'Spots van de clusters en activiteitenprogramma\'s';
	@override String get mapDescription => 'Waar de QSO\'s zijn';
	@override String get clockDescription => 'Een klok, in elke tijdzone';
	@override String get clockFace => 'Wijzerplaat';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analoog';
	@override String get clockZone => 'Tijdzone';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Dit apparaat';
	@override String get clockShowSeconds => 'Seconden tonen';
	@override String get weatherDescription => 'Huidige omstandigheden en de komende acht uur, waar je actief bent';
	@override String get weatherUseOperationLocation => 'Locatie van de activatie gebruiken';
	@override String get weatherLocation => 'Locatie';
	@override String get weatherLocationDescription => 'Een grid square (FN31pr) of lat,lon. Genegeerd zolang \'Locatie van de activatie gebruiken\' is aangevinkt.';
	@override String get weatherNoLocation => 'Geen locatie ingesteld. Geef dit paneel een locatie in de instellingen, of plaats het in een activatie die er een heeft.';
	@override String weatherBadLocation({required Object location}) => 'Kon de locatie ${location} niet lezen. Gebruik een grid square zoals FN31pr, of 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo niet bereikbaar — geen netwerk? Straks nieuwe poging.';
	@override String get weatherUnreadable => 'Open-Meteo reageerde, maar met niets leesbaars. Straks nieuwe poging.';
	@override String weatherGusts({required Object speed}) => 'windstoten ${speed}';
	@override String get panelAgeNow => 'zojuist';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} min geleden',
		other: '${count} min geleden',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} uur geleden',
		other: '${count} uur geleden',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$nl weatherConditions = _Translations$operation$layout$panels$weatherConditions$nl._(_root);
	@override String get websiteDescription => 'Een webpagina naar keuze, in een paneel';
	@override String get websiteUrl => 'Adres';
	@override String get websiteRefresh => 'Verversen';
	@override String get websiteRefreshNever => 'Nooit';
	@override String get websiteRefresh1 => 'Elke minuut';
	@override String get websiteRefresh5 => 'Elke 5 minuten';
	@override String get websiteRefresh15 => 'Elke 15 minuten';
	@override String get websiteTitle => 'Paneelnaam';
	@override String get websiteRefreshNow => 'Nu verversen';
	@override String get websiteNoUrl => 'Nog geen adres. Open de instellingen van dit paneel om een pagina te kiezen.';
	@override String get websiteBadUrl => 'Dat lijkt geen webadres. Het moet beginnen met https://';
	@override String get websiteNotHttps => 'Hier kunnen alleen adressen met https:// worden getoond.';
	@override String get websiteUnsupported => 'Webpagina\'s kunnen op dit systeem niet in een paneel worden getoond.';
	@override String get websiteOpenExternally => 'Openen in browser';
	@override String websiteLoadFailed({required Object reason}) => 'Kon de pagina niet laden: ${reason}';
	@override String get remoteScreenDescription => 'Een scherm, app of venster gedeeld door een ander apparaat van jou.';
	@override String get remoteScreenTarget => 'Scherm';
	@override String get remoteScreenChoose => 'Kies een scherm…';
	@override String get remoteScreenPickerTitle => 'Gedeelde schermen';
	@override String get remoteScreenPickerEmpty => 'Geen van je apparaten deelt een scherm. Zet Schermen en vensters delen aan onder Instellingen → Peer-apparaten, op het apparaat dat je wilt zien.';
	@override String get remoteScreenUnset => 'Geen scherm gekozen. Open de instellingen van dit paneel om er een te kiezen dat je andere apparaten delen.';
	@override String get remoteScreenConnecting => 'Verbinden…';
	@override String get remoteScreenPeerAway => 'Dat apparaat is nu niet verbonden.';
	@override String get remoteScreenNotOffered => 'Dat apparaat deelt dit scherm niet meer.';
	@override String get remoteScreenNoListener => 'Dat apparaat kan geen verbindingen aannemen — controleer de firewall.';
	@override String get remoteScreenNoLan => 'Schermen worden alleen via het lokale netwerk gedeeld, niet via Bluetooth.';
	@override String get remoteScreenRefused => 'Dat apparaat weigerde dit scherm te delen.';
	@override String get remoteScreenSettings => 'Paneelinstellingen';
	@override String get remoteScreenAdjust => 'Weergave aanpassen';
	@override String get remoteScreenDetail => 'Detail';
	@override String get remoteScreenDetailStandard => 'Standaard';
	@override String get remoteScreenDetailHigh => 'Hoog';
	@override String get remoteScreenDetailMaximum => 'Maximaal';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Inzoomen';
	@override String get remoteScreenZoomOut => 'Uitzoomen';
	@override String get remoteScreenStopped => 'Dat scherm of venster wordt niet meer getoond.';
	@override String get remoteScreenCaptureFailed => 'Dat apparaat kon dat scherm niet vastleggen — mogelijk is toestemming voor schermopname nodig.';
	@override String get remoteScreenNoAnswer => 'Dat apparaat reageerde niet. Mogelijk staat scherm delen niet aan.';
	@override String get remoteScreenNoMedia => 'Kon geen verbinding openen voor het beeld. Controleer de firewall op dit apparaat.';
	@override String get solarDescription => 'Zonne- en geomagnetische omstandigheden, met propagatie per band';
	@override String get solarUnreachable => 'hamqsl.com niet bereikbaar — geen netwerk? Straks nieuwe poging.';
	@override String get solarUnreadable => 'hamqsl.com reageerde, maar niet met bruikbare gegevens. Straks nieuwe poging.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Dag';
	@override String get solarBandNight => 'Nacht';
	@override String get solarBandGood => 'Goed';
	@override String get solarBandFair => 'Redelijk';
	@override String get solarBandPoor => 'Slecht';
	@override String solarSources({required Object primary, required Object secondary}) => 'Bronnen: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'De verbinding heeft het moeilijk — frames worden overgeslagen.';
	@override String get remoteScreenStalled => 'Er komen geen frames meer door — deze verbinding is mogelijk te traag.';
	@override String get radioDescription => 'Het frontpaneel van een radio — frequentie, mode en vermogen, via CAT';
	@override String get radioStyle => 'Stijl';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Modern';
	@override String get radioRadio => 'Radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — geen radio aangewezen';
	@override String get radioNoRadio => 'Geen radio om te tonen. Kies er een in de instellingen van dit paneel, of voeg er een toe onder Stationsconfiguratie.';
	@override String get radioNotConfigured => 'Deze radio is nog niet geconfigureerd. Kies de poort of het adres onder Stationsconfiguratie.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radio niet verbonden';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Deze radio verbinden';
	@override String get radioDisconnect => 'Deze radio loskoppelen';
	@override String get radioStale => 'GEEN DATA';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'hoge SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$nl extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gebruik compacte bestandsnamen';
	@override String get descriptionOn => 'Korte namen voor uploaders, zoals N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Leesbare namen, zoals 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$nl extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privégegevens opnemen';
	@override String get descriptionOn => 'Namen, adressen, e-mails, grid squares en notities worden opgenomen';
	@override String get descriptionOff => 'Namen, adressen, e-mails, grid squares en notities worden weggelaten';
	@override String get note => 'De volledige ADIF-export bevat altijd alles';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$nl extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Voeg eerst een e-mailadres toe';
	@override String get needsEmailBody => 'Ham2K File Stash stuurt je bestanden naar het e-mailadres van je LoFi-account, en daarmee log je in op stash.ham2k.net. Je account heeft nog geen bevestigd adres — voeg het toe in Instellingen › Cloud-synchronisatie.';
	@override String get openSyncSettings => 'Cloud-synchronisatie openen';
	@override String get replaceTitle => 'Recente stash wordt vervangen';
	@override String replaceBody({required Object name}) => 'Je hebt “${name}” minder dan 6 uur geleden verzonden en het is nog niet gedownload. Gratis accounts bewaren één stash tegelijk, dus nu verzenden vervangt het.';
	@override String get replaceConfirm => 'Toch versturen';
	@override String get failedTitle => 'Kon niet versturen naar Ham2K File Stash';
	@override String get sentTitle => 'Verstuurd naar Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Je kunt dit bestand ophalen door **[stash.ham2k.net](https://stash.ham2k.net)** in een willekeurige browser te bezoeken.',
		other: 'Je kunt deze bestanden ophalen door **[stash.ham2k.net](https://stash.ham2k.net)** in een willekeurige browser te bezoeken.',
	);
	@override String get mayHaveArrived => 'Geen reactie van de stash — het bestand is mogelijk toch aangekomen. Kijk op stash.ham2k.net voordat je opnieuw verstuurt';
	@override String get notSent => 'niet verzonden';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: 'Dit bestand is niet aangekomen:',
		other: 'Deze ${count} bestanden zijn niet aangekomen:',
	);
	@override String get emailOffer => 'Of, voor je gemak, kunnen we je een e-mail met een directe link sturen.';
	@override String get emailMe => 'Stuur mij een link per e-mail';
	@override String get emailSent => 'We hebben je een downloadlink per e-mail gestuurd.';
	@override String emailFailed({required Object error}) => 'Kon de e-mail niet versturen: ${error}';
	@override String get freeTier => 'Gratis accounts kunnen maar één stash tegelijk bewaren. Abonnees kunnen er zoveel bewaren als ze willen.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count,
		one: '${count} bestand verstuurd naar Ham2K File Stash (stash.ham2k.net)',
		other: '${count} bestanden verstuurd naar Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$nl extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Azië';
	@override String get eu => 'Europa';
	@override String get na => 'Noord-Amerika';
	@override String get oc => 'Oceanië';
	@override String get sa => 'Zuid-Amerika';
	@override String get an => 'Antarctica';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$nl extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spots filteren';
	@override String get band => 'Band';
	@override String get mode => 'Mode';
	@override String get age => 'Leeftijd';
	@override String get sources => 'Bronnen';
	@override String get continent => 'Continent';
	@override String get sorting => 'Sortering';
	@override String get sortByTime => 'Op spottijd';
	@override String get sortByFrequency => 'Op frequentie';
	@override String get groupByBand => 'Groeperen per band';
	@override String get groupCallsWithNotes => 'Roepnamen met notities groeperen';
	@override String get sourceNoReply => 'Geen reactie';
	@override String get sourceError => 'Fout';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$nl extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logpaneel is bezet';
	@override String get editingBody => 'Je bewerkt een gelogd QSO. Deze spot in plaats daarvan loggen, of teruggaan en de bewerking afmaken?';
	@override String get composingBody => 'Je bent begonnen met het invoeren van een QSO. Deze spot in plaats daarvan loggen, of teruggaan en afmaken wat je aan het typen was?';
	@override String get goBack => 'Teruggaan';
	@override String get clearAndLog => 'Wissen en spot loggen';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$nl extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Linkshandige modus';
	@override String get descriptionOn => 'De linkshandige indeling gebruiken';
	@override String get descriptionOff => 'De rechtshandige indeling gebruiken';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$nl extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vlaggen van landen';
	@override String get dx => 'Alleen tonen voor DX-QSO\'s';
	@override String get all => 'Vlaggen tonen voor alle QSO\'s';
	@override String get none => 'Geen vlaggen tonen';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$nl extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Alleen vlaggen tonen voor DX-QSO\'s';
	@override String get all => 'Vlaggen tonen voor alle QSO\'s';
	@override String get none => 'Geen vlaggen tonen';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$nl extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operator voorstellen';
	@override String get descriptionOn => 'Je roepnaam wordt als operator voorgesteld als een activatie onder een andere stationroepnaam loopt';
	@override String get descriptionOff => 'De operator blijft leeg tenzij je hem invult';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$nl extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Toon azimut';
	@override String get descriptionOn => 'Geschatte peiling naar station tonen';
	@override String get descriptionOff => 'Geen peilingsinformatie tonen';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$nl extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ook tegenpeiling tonen';
	@override String get descriptionOn => 'Peiling vanaf het station ook tonen, zoals "45° / 225°"';
	@override String get descriptionOff => 'Alleen peiling naar station tonen';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$nl extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Wijzig volgorde signaalrapport';
	@override String get sentFirst => 'Verzonden eerst, ontvangen daarna';
	@override String get rcvdFirst => 'Ontvangen eerst, verzonden daarna';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$nl extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ga naar volgende veld bij RST-invoer';
	@override String get descriptionOn => 'Na RST naar het volgende veld springen';
	@override String get descriptionOff => 'Niet automatisch springen';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$nl extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standaardrapport — spraak';
	@override String get description => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij SSB, FM of AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$nl extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standaardrapport — CW en data';
	@override String get description => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij CW, RTTY en andere datamodes';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$nl extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standaardrapport — FT8 en FT4';
	@override String get description => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij de FT-modes';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$nl extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cijferrij';
	@override String get description => 'Toon een rij cijfertoetsen boven het toetsenbord tijdens het loggen';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$nl extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Schuine streep- en punttoets';
	@override String get description => 'Voegt een contextuele toets toe: “/” voor roepnamen, “.” voor getallen';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$nl extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Trillen bij toetsaanslag';
	@override String get description => 'Haptische feedback als je op een cijfertoets tikt';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$nl extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get off => 'Uitgeschakeld';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$nl extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$nl extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'PTT bedienen met [\']';
	@override String get descriptionOn => 'In spraakmodes zet [\'] de radio op zenden en [\'] nogmaals weer op ontvangen. Na een minuut gaat hij vanzelf terug op ontvangen.';
	@override String get descriptionOff => 'De [\']-toets zet de radio niet op zenden.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Zenden';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$nl extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Slimme VFO-afronding';
	@override String get descriptionOn => 'Als je stopt met draaien, wordt de frequentie afgerond op een zinnige stap. Alleen spraakmodes.';
	@override String get descriptionOff => 'Blijft precies waar je hebt afgestemd.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$nl extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Slimme afronding: wachttijd';
	@override String get description => 'Hoe lang de knop stil moet staan voordat de frequentie wordt afgerond. Korter voelt direct; langer laat ruimte voor een trage beweging.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$nl extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Slimme afronding: lange beweging';
	@override String get description => 'Draai minstens zo ver en de frequentie wordt afgerond op een hele kHz, hoe langzaam je ook eindigde.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$nl extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Slimme afronding: kleinste beweging';
	@override String get description => 'Draai minder dan dit en de frequentie wordt niet afgerond, zodat fijnafstemming blijft staan.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$nl extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Slimme afronding: traagste beweging';
	@override String get description => 'Draai langzamer dan dit en de frequentie wordt niet afgerond, tenzij het een lange beweging was.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$nl extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM uit';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter verstuurt berichten';
	@override String get off => 'Uit';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter verstuurt berichten: ${state}. Tik om te wijzigen.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$nl extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Keyersnelheid';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$nl extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW-keyerberichten';
	@override String get notSupported => 'De huidige radio ondersteunt geen CW-keying';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Bericht (${n})';
	@override String get labelField => 'Label';
	@override String labelKey({required Object n}) => 'Label F${n}';
	@override String get details => 'Details';
	@override String get empty => '(leeg)';
	@override String get sets => 'Berichtenset';
	@override String get newSet => 'Nieuwe set';
	@override String get renameSet => 'Set hernoemen';
	@override String get deleteSet => 'Set verwijderen';
	@override String get newSetName => 'Naam';
	@override String get setDefault => 'Standaard';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM-berichten';
	@override String get setSaved => 'Mijn berichten';
	@override String get repeat => 'Bericht #1 herhalen';
	@override String get repeatOff => 'Nee';
	@override String repeatAfter({required Object n}) => 'Na ${n} seconden';
	@override String get repeatWait => 'Herhalen';
	@override String get keyboard => 'Typ om te verzenden';
	@override String get keyboardField => 'Typ om te verzenden';
	@override String get closeArea => 'Keyergebied sluiten';
	@override String get help => 'Help';
	@override String get helpTitle => 'CW-berichten schrijven';
	@override String get helpIntro => 'Berichten kunnen sjablonen met de volgende waarden gebruiken:';
	@override String get helpOpCall => 'Je roepnaam';
	@override String get helpQsoCall => 'Hun roepnaam — in een //-stapel de roepnaam die gelogd wordt';
	@override String get helpQsoFullCall => 'Hun roepnaam, als er een geldige roepnaam is; leeg bij een gedeeltelijke';
	@override String get helpQsoPartial => 'Een gedeeltelijke roepnaam; leeg als er een volledige geldige roepnaam is';
	@override String get helpQsoNextCall => 'In een //-stapel de roepnaam die hierna voor het loggen wordt geselecteerd, als er een geldige volledige roepnaam is';
	@override String get helpQsoNextPartial => 'In een //-stapel de volgende gedeeltelijke roepnaam na het loggen van het huidige QSO';
	@override String get helpQsoName => 'Hun voornaam, zoals getypt of anders uit het opzoeken';
	@override String get helpQsoState => 'Hun staat, zoals getypt of anders uit het opzoeken';
	@override String get helpKeyerMsg => 'Bericht 1 zoals het verzonden zou worden, binnen een ander bericht. Geldig voor berichten 1 tot en met 8';
	@override String get helpQsoRst => 'Het rapport dat je verzendt';
	@override String get helpQsoSerial => 'Je volgnummer, in een contest die er een verzendt';
	@override String get helpPad => 'Vult aan met nullen tot zoveel cijfers: 7 wordt verzonden als 007';
	@override String get helpCut => 'Afgekorte cijfers, T voor 0 en N voor 9: 599 wordt verzonden als 5NN';
	@override String get helpCutDigits => 'Kiest de af te korten cijfers, tussen aanhalingstekens — 0 is T, 1 is A, 5 is E, 9 is N';
	@override String get helpFullExample => 'Volledig voorbeeld:';
	@override String get helpExample => 'Verzendt W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Met Enter verstuurt berichten aan verstuurt Enter berichten via hun functietoets, zoals N1MM doet. De set ESM-berichten begint met deze:';
	@override String get helpEsmCq => 'Bij Run roept Enter met een leeg roepnaamveld CQ';
	@override String get helpEsmExchange => 'Je uitwisseling: na hun roepnaam bij Run, nadat ze reageren bij S&P';
	@override String get helpEsmThanks => 'Bedankt, zodra het QSO gelogd is: de plaatshouders verwijzen naar het volgende QSO, niet naar dit';
	@override String get helpEsmMyCall => 'Bij S&P je roepnaam aan het station dat je beantwoordt';
	@override String get helpEsmHisCall => 'Bij Run hun roepnaam vóór je uitwisseling';
	@override String get helpEsmAgain => 'Vraagt opnieuw als er niets van hun uitwisseling is opgenomen';
	@override String get helpEsmStackThanks => 'Voorgestelde F3 voor //-stapels: TU gaat uit nadat het QSO gelogd is, dus het bedankt, roept dan het volgende gestapelde station en verstuurt je uitwisseling, of vraagt een gedeeltelijke roepnaam terug (TU KR?); als er niets over is, alleen TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$nl extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spraak-keyerberichten';
	@override String get notSupported => 'De huidige radio ondersteunt geen spraakberichten';
	@override String get description => 'Dit gebruikt de spraakgeheugens van de radio';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Spraakgeheugen (${n})';
	@override String get labelField => 'Label';
	@override String labelKey({required Object n}) => 'Label spraakgeheugen ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Leeg';
	@override String get notMeasured => 'Onbekende lengte';
	@override String get playButton => 'Afspelen';
	@override String get recordButton => 'Opnemen';
	@override String get stopButton => 'Stop';
	@override String get repeat => 'Bericht #1 herhalen';
	@override String get repeatOff => 'Nee';
	@override String repeatAfter({required Object n}) => 'Na ${n} seconden';
	@override String recordHelpTitle({required Object model}) => 'Opmerkingen bij ${model}:';
	@override String namedOnDevice({required Object device}) => 'Deze geheugens staan in de radio van ${device}. Hun namen en lengtes horen bij dat apparaat.';
	@override String get namedOnRadio => 'Opgeslagen in de radio, waar ook de andere clients het zien.';
	@override String get recordHelpYaesuDvs => 'Wacht op de [REC]-indicator op de radio, houd dan de PTT-knop ingedrukt en neem je bericht op. Beëindig het door hier in de app op STOP te drukken voordat je de PTT loslaat, om ongewenste klikken te voorkomen.';
	@override String get recordHelpFt891 => 'Wacht tot de [REC]-indicator minstens vier keer knippert, houd dan de PTT-knop ingedrukt en neem je bericht op. Beëindig het door hier in de app op STOP te drukken voordat je de PTT loslaat, om ongewenste klikken te voorkomen.';
	@override String get pill => 'Spraak';
	@override String play({required Object n}) => 'Geheugen ${n} afspelen';
	@override String get stop => 'Stop';
	@override String record({required Object n}) => 'Geheugen ${n} opnemen';
	@override String get stopRecording => 'Opname stoppen';
	@override String get playing => 'Afspelen…';
	@override String get recording => 'Opnemen…';
	@override String playingMemory({required Object label}) => '${label} afspelen';
	@override String recordingMemory({required Object label}) => '${label} opnemen';
	@override String get doubtful => 'Heeft de radio het afgespeeld? Hij meldde meteen dat hij inactief was.';
	@override String get recordOnRadio => 'Je moet de geheugens op de radio zelf opnemen.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$nl extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zero-beat op spots vermijden';
	@override String get descriptionOn => 'Met een verbonden radio een paar Hz naast een CW-spot afstemmen, zodat niet iedereen die reageert op dezelfde toon roept.';
	@override String get descriptionOff => 'Precies op de gespotte frequentie afstemmen.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$nl extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zero-beat: vermijdingsbereik';
	@override String get description => 'Hoe ver naast de gespotte frequentie, aan beide kanten. De afwijking is nooit bijna nul — dat zou weer een zero-beat zijn.';
}

// Path: settings.map.style
class _Translations$settings$map$style$nl extends Translations$settings$map$style$en {
	_Translations$settings$map$style$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kaartstijl';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$nl extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatisch';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$nl extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Deel app-gebruiksgegevens';
	@override String get descriptionOn => 'Help ons de app te verbeteren door gebruiks-, configuratie-, crash- en prestatiegegevens te delen';
	@override String get descriptionOff => 'Appgebruiksgegevens privé houden.\nHet Ham2K-team kan crashes of andere problemen niet detecteren.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$nl extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get title => 'Deel activatiegegevens';
	@override String get descriptionOn => 'Bepaalde activatiegegevens openbaar en met andere gebruikers delen';
	@override String get descriptionOff => 'Activatiegegevens privé houden';
}

// Path: settings.station.models
class _Translations$settings$station$models$nl extends Translations$settings$station$models$en {
	_Translations$settings$station$models$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Algemeen';
	@override String get icomGeneric => 'Icom - Algemeen';
	@override String get kenwoodGeneric => 'Kenwood - Algemeen';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Algemeen';
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
	@override String get rigctld => 'Radio bestuurd via rigctld';
	@override String get rigctldNodeName => 'Mijn radio (via rigctld)';
	@override String get flrig => 'Radio bestuurd via flrig';
	@override String get flrigNodeName => 'Mijn radio (via flrig)';
	@override String get hrd => 'Radio bestuurd via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Mijn radio (via HRD)';
	@override String get n3fjp => 'Radio bestuurd via N3FJP';
	@override String get n3fjpNodeName => 'Mijn radio (via N3FJP)';
	@override String get commander => 'Radio bestuurd via DXLab Commander';
	@override String get commanderNodeName => 'Mijn radio (via Commander)';
	@override String get antenna => 'Antenne';
	@override String get key => 'CW-seinsleutel';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Algemene radio (tijdelijk)';
	@override String get placeholderRadioNodeName => 'Mijn radio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$nl extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get network => 'Netwerk/wifi';
	@override String get usbSerial => 'USB-serieel';
	@override String get wifi => 'Netwerk/wifi';
	@override String get bluetoothSerial => 'Bluetooth-serieel';
	@override String get placeholder => 'Tijdelijk';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$nl extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipool';
	@override String get vertical => 'Verticaal';
	@override String get yagiBeam => 'Yagi / Beam';
	@override String get loop => 'Loop';
	@override String get longWire => 'Long Wire / EFHW';
	@override String get other => 'Andere';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$nl extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Rechte seinsleutel';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mechanisch halfautomatisch)';
	@override String get fullyAutomatic => 'Volautomatische keyer';
	@override String get singlePaddle => 'Enkele paddle';
	@override String get dualPaddle => 'Dubbele paddle';
	@override String get computerDriven => 'Computergestuurd';
	@override String get other => 'Andere';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$nl extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$nl._(TranslationsNl root) : this._root = root, super.internal(root);

	final TranslationsNl _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Onbekend';
	@override String get sunny => 'Zonnig';
	@override String get clear => 'Helder';
	@override String get mainlySunny => 'Overwegend zonnig';
	@override String get mainlyClear => 'Overwegend helder';
	@override String get partlyCloudy => 'Half bewolkt';
	@override String get cloudy => 'Bewolkt';
	@override String get foggy => 'Mist';
	@override String get rimeFog => 'Aanvriezende mist';
	@override String get lightDrizzle => 'Lichte motregen';
	@override String get drizzle => 'Motregen';
	@override String get heavyDrizzle => 'Zware motregen';
	@override String get lightFreezingDrizzle => 'Lichte aanvriezende motregen';
	@override String get freezingDrizzle => 'Aanvriezende motregen';
	@override String get lightRain => 'Lichte regen';
	@override String get rain => 'Regen';
	@override String get heavyRain => 'Zware regen';
	@override String get lightFreezingRain => 'Lichte ijzel';
	@override String get freezingRain => 'IJzel';
	@override String get lightSnow => 'Lichte sneeuw';
	@override String get snow => 'Sneeuw';
	@override String get heavySnow => 'Zware sneeuw';
	@override String get snowGrains => 'Motsneeuw';
	@override String get lightShowers => 'Lichte buien';
	@override String get showers => 'Buien';
	@override String get heavyShowers => 'Zware buien';
	@override String get lightSnowShowers => 'Lichte sneeuwbuien';
	@override String get snowShowers => 'Sneeuwbuien';
	@override String get thunderstorm => 'Onweer';
	@override String get lightThunderstormsWithHail => 'Licht onweer met hagel';
	@override String get thunderstormWithHail => 'Onweer met hagel';
}

/// The flat map containing all translations for locale <nl>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsNl {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Opslaan',
			'common.ok' => 'OK',
			'common.cancel' => 'Annuleren',
			'common.delete' => 'Verwijderen',
			'common.create' => 'Aanmaken',
			'common.error' => 'Fout',
			'common.close' => 'Sluiten',
			'common.done' => 'Klaar',
			'common.callsign' => 'Roepnaam',
			'common.clear' => 'Wissen',
			'common.dismiss' => 'Negeren',
			'common.expand' => 'Uitklappen',
			'common.collapse' => 'Inklappen',
			'onboarding.welcomeTitle' => 'Welkom bij Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Welkom bij Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'We hebben een paar vragen om beter op je wensen in te spelen.',
			'onboarding.skip' => 'Overslaan',
			'onboarding.kContinue' => 'Doorgaan',
			'onboarding.back' => 'Terug',
			'onboarding.next' => 'Volgende',
			'onboarding.done' => 'Klaar',
			'onboarding.callsignTitle' => 'Wat is je roepnaam?',
			'onboarding.callsignBody' => 'Je hebt een zendmachtiging voor radioamateurs nodig om deze app nuttig te vinden',
			'onboarding.callsignLabel' => 'Roepnaam van de operator',
			'onboarding.alreadyHaveAccount' => 'Heb je al een account?',
			'onboarding.foundSiblingTitle' => 'Een bestaand account koppelen?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'We hebben ${app} op dit apparaat gevonden. Koppel deze app aan hetzelfde account en je roepnaam en logboeken komen mee.',
			'onboarding.foundPoloBody' => 'We hebben een oudere versie van Ham2K Portable Logger op dit apparaat gevonden. Koppel deze app aan hetzelfde account en je roepnaam en logboeken komen mee.',
			'onboarding.foundSiblingsBody' => 'We hebben andere Ham2K-apps op dit apparaat gevonden. Koppel deze app aan een van hun accounts en je roepnaam en logboeken komen mee.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Koppelen met ${app}',
			'onboarding.linkWithPolo' => 'Koppelen met account in oudere versie',
			'onboarding.setUpFresh' => 'Opnieuw beginnen',
			'onboarding.activitiesTitle' => 'Favoriete activiteiten',
			'onboarding.activitiesBody' => 'Ben je geïnteresseerd in een van deze populaire activatieprogramma\'s?',
			'onboarding.activitiesFooter' => '(Meer opties vind je in de Instellingen)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Gegevens & privacy',
			'onboarding.consentUsageBody' => 'Om de app te verbeteren willen we prestatie-, crash- en gebruiksgegevens verzamelen.',
			'onboarding.consentUsageLabel' => 'Deel app-gebruiksgegevens',
			'onboarding.consentOperationBody' => 'Sommige functies kunnen je activatiegegevens met andere gebruikers delen. Je kunt je op elk moment afmelden.',
			'onboarding.consentOperationLabel' => 'Deel activatiegegevens',
			'onboarding.finishingSetup' => 'Installatie afronden — referentiegegevens downloaden…',
			'startScreen.credits' => 'door KI2D en vrienden',
			'testerOverlay.tape' => 'LET OP: IN AANBOUW',
			'testerOverlay.warningTitle' => 'Aan deze app wordt nog gewerkt',
			'testerOverlay.warningBody' => 'De meeste functies hebben een oneffen ondergrond en overal liggen struikelgevaren. Kijk regelmatig of er updates zijn.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Nieuw in build ${build}',
			'testerOverlay.thanks' => 'Bedankt dat je je logboek op het spel zet om ons te helpen deze app beter te maken!',
			'extensionsPanel.categoryActivity' => 'Activiteiten',
			'extensionsPanel.categoryContest' => 'Contests',
			'extensionsPanel.categoryLookup' => 'Roepnaam opzoeken',
			'extensionsPanel.categorySpots' => 'Spotbronnen',
			'extensionsPanel.categoryDashboard' => 'Dashboardpanelen',
			'extensionsPanel.categoryOther' => 'Andere extensies',
			'extensionsPanel.searchHint' => 'Extensies zoeken',
			'extensionsPanel.applying' => 'Extensiewijzigingen activeren, dit kan even duren…',
			'extensionsPanel.noMatches' => 'Geen extensies gevonden',
			'extensionsPanel.installFromFile' => 'Installeren uit bestand…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versie ${version}',
			'extensionsPanel.canReach' => 'Deze extensie kan contact maken met',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, via een live verbinding',
			'extensionsPanel.canHoldLocalConnection' => 'Apparaten op je lokale netwerk, via een live verbinding',
			'extensionsPanel.canUseLocation' => 'Je locatie',
			'extensionsPanel.canReadRadio' => 'Je radio, om frequentie en mode uit te lezen',
			'extensionsPanel.canControlRadio' => 'Je radio, om hem te bedienen en ermee te zenden — afstemmen, vermogen, CW, spraakgeheugens en PTT',
			'extensionsPanel.canSetUserAgent' => 'Zich bij servers onder eigen naam identificeren',
			'extensionsPanel.noCapabilities' => 'Ze vraagt niets buiten de app.',
			'extensionsPanel.sandboxNote' => 'Extensies draaien in een sandbox: geen toegang tot je bestanden en geen netwerk buiten wat hier staat.',
			'extensionsPanel.installAction' => 'Installeren',
			'extensionsPanel.updateAction' => 'Bijwerken',
			'extensionsPanel.installFailed' => 'Die extensie kon niet worden geïnstalleerd',
			'extensionsPanel.installedBadge' => 'Geïnstalleerd',
			'extensionsPanel.uninstallAction' => 'Verwijderen',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '${name} verwijderen?',
			'extensionsPanel.uninstallBody' => 'Deze extensie en haar instellingen worden verwijderd. Je logboeken blijven onaangetast.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} geïnstalleerd',
			'extensionsPanel.installDownloading' => 'Downloaden…',
			'extensionsPanel.installWaiting' => 'Wachten op installatie…',
			'extensionsPanel.installInstalling' => 'Installeren…',
			'extensionsPanel.installAwaitingApproval' => 'Wachten op je goedkeuring…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} wordt al geïnstalleerd.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Bijgewerkt naar ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Installatie van ${name} is niet voltooid. Mogelijk moet je hem opnieuw installeren.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Kon ${name} niet verwijderen',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Gedownload van ${source}',
			'extensionsPanel.dropHint' => 'Sleep een .h2kext-extensie hierheen om te installeren',
			'extensionsPanel.dropOneOnly' => 'Sleep één extensie tegelijk.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} gaf ${status} terug voor die extensie.',
			'extensionsPanel.downloadTooLarge' => 'Die download is veel te groot voor een extensie.',
			'extensionsPanel.downloadNotSecure' => 'Die download werd doorgestuurd naar een onveilige locatie.',
			'extensionsPanel.catalogSection' => 'Catalogus',
			'extensionsPanel.catalogLoading' => 'Catalogus laden…',
			'extensionsPanel.catalogUnreachable' => 'Catalogus onbereikbaar',
			'extensionsPanel.builtIn' => 'Ingebouwd',
			'extensionsPanel.updateAvailableBadge' => 'Update beschikbaar',
			'extensionsPanel.updatesAvailableTitle' => 'Extensie-updates',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Er is een update beschikbaar voor ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} en ${count} andere moeten worden bijgewerkt.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} moeten worden bijgewerkt.',
			'extensionsPanel.pendingUpdatesSection' => 'Wachtende updates',
			'extensionsPanel.updateAllAction' => 'Alles bijwerken',
			'extensionsPanel.updatesUnderWay' => 'Die updates zijn al bezig.',
			'extensionsPanel.updatesNothingLeft' => 'Je extensies zijn up-to-date.',
			'extensionsPanel.updatesNoticeAction' => 'Meer info',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} extensie bijwerken?', other: '${count} extensies bijwerken?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Je extensies zijn klaar',
			'extensionsPanel.upgradeDoneBody' => 'Ze komen nu uit de Ham2K-extensiecatalogus en kunnen dus worden bijgewerkt zonder op een nieuwe versie van de app te wachten.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Niet bijgewerkt: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Starten niet: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Ze zijn nog geïnstalleerd en gemarkeerd in Instellingen › Extensies — daar bijwerken brengt ze terug.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'De catalogus heeft hiervoor geen directe vervanging; zoek daar naar extensies die dekken wat je gebruikte.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'State Parks-evenementen',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} van je extensies zijn nog niet binnen. Ze worden gedownload zodra de extensiecatalogus weer bereikbaar is.',
			'extensionsPanel.runtimeDeadBody' => 'Je extensies wilden niet starten. Herstart de app om ze terug te krijgen.',
			'extensionsPanel.refusedTitle' => 'Sommige extensies wilden niet starten',
			'extensionsPanel.upgradeBusyTitle' => 'Nog bezig met instellen',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Je extensies draaien niet',
			'extensionsPanel.restoreTitle' => 'Sommige van je extensies ontbreken',
			'extensionsPanel.restoreBody' => 'Deze extensies die je hebt geïnstalleerd staan niet op dit apparaat. We kunnen ze opnieuw downloaden uit de Ham2K-extensiecatalogus:',
			'extensionsPanel.restoreFromFile' => 'Geïnstalleerd uit een bestand. Installeer deze opnieuw uit hun bestanden, of vergeet ze:',
			'extensionsPanel.restoreOtherCatalog' => 'Geïnstalleerd uit een andere extensiecatalogus, dus hier niet beschikbaar:',
			'extensionsPanel.restoreForget' => 'Vergeten',
			'extensionsPanel.restoreInstall' => 'Installeren',
			'extensionsPanel.restoreLater' => 'Later',
			'extensionsPanel.restoreInstalling' => 'Je extensies installeren…',
			'extensionsPanel.restoreDoneTitle' => 'Je extensies zijn terug',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Opnieuw geïnstalleerd: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Sommige extensies konden niet worden geïnstalleerd',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Kon niet installeren: ${names}. We bieden ze opnieuw aan als je de app weer opent.',
			'extensionsPanel.restoreBusyBody' => 'De app is nog bezig je extensies in te stellen. We bieden deze opnieuw aan als je de app weer opent.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'We hebben ze opnieuw geïnstalleerd, maar je extensies wilden niet starten. Herstart de app om ze terug te krijgen.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} is ingetrokken',
			'extensionsPanel.revokedBody' => 'De catalogus heeft deze versie ingetrokken, dus ze is uitgeschakeld.',
			'extensionsPanel.downloadHashMismatch' => 'Die download is niet de extensie die de catalogus beschreef.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'De catalogus heeft geen versie ${version} van ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Die cataloguslink verwijst niet naar een extensieversie.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'De catalogus heeft geen release van ${key} op dat kanaal.',
			'extensionsPanel.installFromLink' => 'Installeren via link',
			'extensionsPanel.unstableReleaseWarning' => 'Dit is een onstabiele release die de uitgever nog niet af noemt. Ze kan zich vreemd gedragen en blijft onstabiele updates ontvangen.',
			'extensionsPanel.bleedingReleaseWarning' => 'Dit is een bleeding-edge release: werk in uitvoering dat kan breken of zijn instellingen kan verliezen. Ze blijft bleeding-edge updates ontvangen.',
			'extensionsPanel.channelUnstable' => 'Onstabiel',
			'extensionsPanel.channelBleeding' => 'Bleeding',
			'extensionsPanel.followsUnstable' => 'Ontvangt onstabiele en stabiele releases',
			'extensionsPanel.followsBleeding' => 'Ontvangt bleeding-edge, onstabiele en stabiele releases',
			'extensionsPanel.followStableAction' => 'Alleen stabiele releases volgen',
			'extensionsPanel.revokedBadge' => 'Ingetrokken',
			'extensionsPanel.refusedBadge' => 'Niet geladen',
			'extensionsPanel.downloadNotHttps' => 'Die download gaat niet via een beveiligde verbinding.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} was niet bereikbaar voor die extensie.',
			'extensionsPanel.detailsAction' => 'Details',
			'extensionsPanel.installedFromFile' => 'Geïnstalleerd uit een bestand',
			'extensionsPanel.detailsWhatItDoes' => 'Biedt ondersteuning voor',
			'extensionsPanel.installedPreloaded' => 'Voorgeïnstalleerd',
			'extensionsPanel.hookAccount' => 'Accountaanmelding',
			'extensionsPanel.hookCallNotes' => 'Roepnaamnotities',
			'extensionsPanel.hookDataFile' => 'Offline gegevens',
			'extensionsPanel.hookExport' => 'Exporteren',
			'extensionsPanel.hookLookup' => 'Roepnaam opzoeken',
			'extensionsPanel.hookScoring' => 'Puntentelling',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => '${program} jagen',
			'extensionsPanel.hookActivating' => ({required Object program}) => '${program} activeren',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '… en ${count} andere extensie', other: '… en ${count} andere extensies', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} extensie beschikbaar', other: '${count} extensies beschikbaar', ), 
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'Nieuwe activatie',
			'home.stationCallsign' => 'Station roepnaam',
			'home.titleOptional' => 'Titel (optioneel)',
			'home.emptyList' => 'Nog geen activaties. Maak er een aan om te beginnen met loggen.',
			'home.quickLookup' => 'Snel opzoeken',
			'home.nav.operations' => 'Activaties',
			'home.nav.chase' => 'Jagen',
			'home.nav.logs' => 'Logboeken',
			'home.nav.maps' => 'Kaarten',
			'home.nav.settings' => 'Instellingen',
			'home.panels.operations' => 'Activatielijst',
			'home.panels.operationsDescription' => 'Je activaties, meest recente eerst.',
			'home.panels.version' => 'Huidige versie',
			'home.panels.versionDescription' => 'Het Ham2K-logo, de naam van deze app en welke build je gebruikt.',
			'home.toggleNav' => 'Navigatielabels tonen of verbergen',
			'home.logs.title' => 'Logboeken',
			'home.logs.titleFor' => 'Logboeken voor',
			'home.logs.emptyCallsigns' => 'Nog geen QSO\'s gelogd',
			'home.logs.emptyQsos' => ({required Object call}) => 'Geen QSO\'s voor ${call}',
			'home.logs.mapNoSelection' => 'Selecteer een QSO om het op de kaart te zien',
			'home.logs.searchHint' => 'Zoek roepnaam of naam',
			'home.logs.noSearchMatches' => 'Geen QSO\'s gevonden',
			'home.logs.titleAll' => 'Alle logboeken',
			'home.logs.allCallsigns' => 'Alle roepnamen',
			'home.logs.noOperation' => 'Hoort niet bij een activatie',
			'home.logs.unsavedTitle' => 'Niet-opgeslagen wijzigingen',
			'home.logs.unsavedBody' => 'Dit QSO heeft wijzigingen die je niet hebt opgeslagen.',
			'home.logs.pendingDeleteBody' => 'Dit QSO is gemarkeerd om te verwijderen.',
			'home.logs.editGone' => 'Niet opgeslagen: dat QSO staat niet meer in dit logboek.',
			'home.logs.discard' => 'Weggooien',
			'home.logs.columns.date' => 'Datum',
			'home.logs.columns.time' => 'Tijd',
			'home.logs.columns.freq' => 'Frequentie',
			'home.logs.columns.mode' => 'Mode',
			'home.logs.columns.call' => 'Roepnaam',
			'home.logs.columns.name' => 'Naam',
			'home.logs.columns.station' => 'Station',
			'home.logs.columns.band' => 'Band',
			'home.logs.columns.sent' => 'Verz.',
			'home.logs.columns.rcvd' => 'Ontv.',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'Staat',
			'home.logs.columns.country' => 'Land',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'QSO-logboek',
			'home.logs.panels.qsosDescription' => 'De QSO\'s van de geselecteerde roepnaam, over alle activaties heen.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Totaal aantal QSO\'s, of de opzoekgegevens van het geselecteerde QSO.',
			'home.logs.panels.map' => 'Kaart',
			'home.logs.panels.mapDescription' => 'De locatie van het geselecteerde QSO.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Roepnamen: ${calls}',
			'home.logs.import.skippedOne' => '1 record kon niet worden gelezen',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} records konden niet worden gelezen',
			'home.logs.import.readingTitle' => 'ADIF-bestand lezen…',
			'home.logs.import.checkingTitle' => 'Controleren op dubbels…',
			'home.logs.import.importingTitle' => 'QSO\'s importeren…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} van ${total} gecontroleerd',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} van ${total} geïmporteerd',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'jaagt op',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} & meer',
			'chase.station.title' => 'Jagend station',
			'chase.station.stationLabel' => 'Station: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Geen locatie',
			'chase.periodInline.today' => 'vandaag',
			'chase.periodInline.thisWeek' => 'deze week',
			'chase.periodInline.last14Days' => 'in de laatste 14 dagen',
			'chase.periodInline.thisMonth' => 'deze maand',
			'chase.periodStats.today' => 'Statistieken van vandaag',
			'chase.periodStats.thisWeek' => 'Statistieken van deze week',
			'chase.periodStats.last14Days' => 'Statistieken van de laatste 14 dagen',
			'chase.periodStats.thisMonth' => 'Statistieken van deze maand',
			'chase.period.today' => 'Vandaag',
			'chase.period.thisWeek' => 'Deze week',
			'chase.period.last14Days' => 'Laatste 14 dagen',
			'chase.period.thisMonth' => 'Deze maand',
			'chase.goals.title' => 'Jaagdoelen',
			'chase.goals.remove' => ({required Object name}) => 'Stop met jagen op ${name}',
			'chase.goals.extensionsTitle' => 'Extensies met jaagdoelen',
			'chase.panels.logging' => 'QSO\'s',
			'chase.panels.loggingDescription' => 'Logbediening boven de QSO\'s die in de periode zijn gejaagd.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'De roepnaam die wordt gelogd, of de statistieken van de periode.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Gespotte stations in de lucht, klaar om te jagen.',
			'chase.panels.map' => 'Kaart',
			'chase.panels.mapDescription' => 'De QSO\'s van de periode en het station dat wordt gelogd.',
			'dialogs.operationDetails' => 'Activatiegegevens',
			'dialogs.activities' => 'Activiteiten',
			'dialogs.stationCallsign' => 'Station roepnaam',
			'dialogs.multiStationIdentifier' => 'Multi-station identificatie (alleen cijfers)',
			'dialogs.notes' => 'Notities',
			'dialogs.deleteOperationTitle' => 'Activatie verwijderen',
			'dialogs.purgeTestsTitle' => 'Testactivaties opruimen',
			'dialogs.purgeTestsBody' => 'Dit verwijdert deze testactivaties en hun QSO\'s definitief. Dit kan niet ongedaan worden gemaakt.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Plus ${count} test-QSO dat bij geen enkele activatie hoort.', other: 'Plus ${count} test-QSO\'s die bij geen enkele activatie horen.', ), 
			'dialogs.purgeTestsAction' => 'Opruimen',
			'dialogs.syncAllTitle' => 'Het logboek van dit apparaat vervangen?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL maakt een back-up van ${qsos} op dit apparaat en wist ze, en downloadt daarna het logboek van het account opnieuw van de server. De back-up blijft in de database van dit apparaat.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${n} QSO is nog niet gesynchroniseerd — de server heeft het nooit ontvangen en het komt NIET terug.', other: '${n} QSO\'s zijn nog niet gesynchroniseerd — de server heeft ze nooit ontvangen en ze komen NIET terug.', ), 
			'dialogs.syncAllAction' => 'Wissen en opnieuw synchroniseren',
			'dialogs.receivedPurgesTitle' => 'Testactivaties elders verwijderd',
			'dialogs.receivedPurgesBody' => 'Deze zijn op een ander apparaat als testactivaties verwijderd. Ook hier verwijderen? Dit verwijdert ze en hun QSO\'s definitief en kan niet ongedaan worden gemaakt.',
			'dialogs.receivedPurgesAction' => 'Verwijderen',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Ongeldige roepnaam: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Ongeldige roepnamen: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Tot nu toe was ${previous} operator. ${typed} wordt vastgelegd voor nieuwe QSO\'s.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Tot nu toe geen operator vastgelegd. ${typed} wordt vastgelegd voor nieuwe QSO\'s.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Deze activatie heeft al QSO\'s door ${calls}. ${typed} wordt alleen vastgelegd voor nieuwe QSO\'s.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Leg ${typed} ook vast als operator van het reeds gelogde QSO', other: 'Leg ${typed} ook vast als operator van alle ${count} reeds gelogde QSO\'s', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Bij gebruik van meerdere stationroepnamen in de lucht zijn aparte operators niet mogelijk',
			'dialogs.callChange.contactsUnreadable' => 'De QSO\'s van deze activatie konden niet worden gelezen, dus een roepnaamwijziging hier biedt niet aan ze bij te werken',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'De reeds gelogde QSO\'s konden niet worden bijgewerkt, dus er is niets gewijzigd: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} van ${planned} QSO\'s zijn bijgewerkt — de rest hoort niet meer bij deze activatie',
			'operation.deletedReadOnly' => 'Deze activatie is verwijderd. Herstel haar om te loggen of iets te wijzigen.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO\'s',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'KAART',
			'operation.tabs.qsosPlain' => 'QSO\'s',
			'operation.tabs.clock' => 'Klok',
			'operation.tabs.weather' => 'Weer',
			'operation.tabs.website' => 'Website',
			'operation.tabs.remoteScreen' => 'Extern scherm',
			'operation.tabs.solar' => 'Zon',
			'operation.tabs.radio' => 'Radio',
			'operation.positions.nobodyYet' => 'Nog geen andere operatorposities delen deze activatie.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Een andere positie',
			'operation.positions.thisDevice' => 'Onze operatorpositie',
			'operation.positions.nameIn' => ' in ',
			'operation.positions.panelTitle' => 'Posities',
			'operation.positions.panelDescription' => 'Wat elke operatorpositie die deze activatie deelt op dit moment logt.',
			'operation.stationCallsignNone' => 'Geen station roepnaam',
			'operation.titleNone' => 'Geen titel',
			'operation.deleteOperation' => 'Activatie verwijderen',
			'operation.loggingControlsStale' => 'Activiteitsvelden zijn mogelijk verouderd — open de activatie opnieuw om ze te verversen',
			'operation.locationNone' => 'Niet ingesteld',
			'operation.generalOperation' => 'Algemene Activatie',
			'operation.titleFor' => ({required Object value}) => 'voor ${value}',
			'operation.titleAt' => ({required Object value}) => 'bij ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Nu ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'RST-velden tonen',
			'operation.menu.showStateField' => 'Staatveld tonen',
			'operation.menu.showGridField' => 'Gridveld tonen',
			'operation.menu.showDeletedQsos' => 'Verwijderde QSO\'s tonen',
			'operation.menu.showDeletedOps' => 'Verwijderde activaties tonen',
			'operation.menu.showQsoNumbers' => 'QSO-nummers tonen',
			'operation.menu.lookupAllQsos' => 'Alle QSO\'s opzoeken',
			'operation.menu.loggingSettingsTitle' => 'Loginstellingen',
			'operation.menu.mapSettingsTitle' => 'Kaartinstellingen',
			'operation.menu.actionsSection' => 'Acties',
			'operation.layout.title' => 'Paneel toevoegen',
			'operation.layout.availableSection' => 'Beschikbare panelen',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Instellingen ${panel}',
			'operation.layout.panelSettingsAction' => 'Paneelinstellingen',
			'operation.layout.viewName' => 'Activatieweergave',
			'operation.layout.viewOptions' => 'Opties voor weergave-indeling',
			'operation.layout.viewTitleBuiltIn' => 'Deze weergave is ingebouwd in de app, en de naam ook',
			'operation.layout.resetOptions' => 'Standaardwaarden herstellen',
			'operation.layout.removePane' => 'Verwijderen',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '${panel} terugzetten naar de standaardwaarden?',
			'operation.layout.resetPaneConfirmBody' => 'De titel, kop en grootte gaan terug naar de standaardwaarden. De rest van de indeling blijft zoals die is.',
			'operation.layout.resetViewConfirm' => 'Deze weergave terugzetten naar de standaardindeling?',
			'operation.layout.resetViewConfirmBody' => 'De panelen gaan terug naar hun standaardopstelling, en de opties van de weergave en van elk paneel gaan terug naar de standaardwaarden.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Indelingsinstellingen ${panel}',
			'operation.layout.paneTitle' => 'Titel',
			'operation.layout.paneShowHeader' => 'Kop tonen',
			'operation.layout.paneShowHeaderTabset' => 'Altijd zichtbaar zolang dit paneel een groep deelt — via de kop bereik je de andere',
			'operation.layout.paneInherit' => 'Zelfde als de app',
			'operation.layout.searchHint' => 'Panelen zoeken',
			'operation.layout.noPanelsMatch' => 'Geen paneel gevonden.',
			'operation.layout.nothingToAdd' => 'Deze weergave heeft al alle mogelijke panelen',
			'operation.layout.addPanel' => ({required Object panel}) => '${panel} toevoegen',
			'operation.layout.showPreview' => ({required Object panel}) => 'Voorbeeld ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Extensie "${name}" ontbreekt',
			'operation.layout.previewUnavailable' => 'De voorbeeldafbeelding van dit paneel kon niet worden getoond.',
			'operation.layout.nestedPaneTitle' => 'Meer',
			'operation.layout.editLayout' => 'Indeling bewerken',
			'operation.layout.saveLayout' => 'Indeling opslaan',
			'operation.layout.revertLayout' => 'Indelingswijzigingen weggooien',
			'operation.layout.done' => 'Klaar',
			'operation.layout.layoutUnreadableTitle' => 'Indeling kon niet worden gelezen',
			'operation.layout.layoutUnreadableBody' => 'Je opgeslagen indeling kon niet worden gelezen, dus de standaardopstelling wordt getoond. Je origineel wordt pas overschreven als je ervoor kiest deze te houden.',
			'operation.layout.layoutUnreadableAction' => 'Deze indeling gebruiken',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} kon niet worden weergegeven',
			'operation.layout.panelRenderRetry' => 'Opnieuw proberen',
			'operation.layout.panelActionFailed' => 'Die paneelactie is mislukt. Probeer het opnieuw.',
			'operation.layout.panels.loggingDescription' => 'Het logboek en de invoervelden',
			'operation.layout.panels.infoDescription' => 'Wat we weten over het gewerkte station',
			'operation.layout.panels.spotsDescription' => 'Spots van de clusters en activiteitenprogramma\'s',
			'operation.layout.panels.mapDescription' => 'Waar de QSO\'s zijn',
			'operation.layout.panels.clockDescription' => 'Een klok, in elke tijdzone',
			'operation.layout.panels.clockFace' => 'Wijzerplaat',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analoog',
			'operation.layout.panels.clockZone' => 'Tijdzone',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Dit apparaat',
			'operation.layout.panels.clockShowSeconds' => 'Seconden tonen',
			'operation.layout.panels.weatherDescription' => 'Huidige omstandigheden en de komende acht uur, waar je actief bent',
			'operation.layout.panels.weatherUseOperationLocation' => 'Locatie van de activatie gebruiken',
			'operation.layout.panels.weatherLocation' => 'Locatie',
			'operation.layout.panels.weatherLocationDescription' => 'Een grid square (FN31pr) of lat,lon. Genegeerd zolang \'Locatie van de activatie gebruiken\' is aangevinkt.',
			'operation.layout.panels.weatherNoLocation' => 'Geen locatie ingesteld. Geef dit paneel een locatie in de instellingen, of plaats het in een activatie die er een heeft.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Kon de locatie ${location} niet lezen. Gebruik een grid square zoals FN31pr, of 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo niet bereikbaar — geen netwerk? Straks nieuwe poging.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo reageerde, maar met niets leesbaars. Straks nieuwe poging.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'windstoten ${speed}',
			'operation.layout.panels.panelAgeNow' => 'zojuist',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} min geleden', other: '${count} min geleden', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} uur geleden', other: '${count} uur geleden', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Onbekend',
			'operation.layout.panels.weatherConditions.sunny' => 'Zonnig',
			'operation.layout.panels.weatherConditions.clear' => 'Helder',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Overwegend zonnig',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Overwegend helder',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Half bewolkt',
			'operation.layout.panels.weatherConditions.cloudy' => 'Bewolkt',
			'operation.layout.panels.weatherConditions.foggy' => 'Mist',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Aanvriezende mist',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Lichte motregen',
			'operation.layout.panels.weatherConditions.drizzle' => 'Motregen',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Zware motregen',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Lichte aanvriezende motregen',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Aanvriezende motregen',
			'operation.layout.panels.weatherConditions.lightRain' => 'Lichte regen',
			'operation.layout.panels.weatherConditions.rain' => 'Regen',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Zware regen',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Lichte ijzel',
			'operation.layout.panels.weatherConditions.freezingRain' => 'IJzel',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Lichte sneeuw',
			'operation.layout.panels.weatherConditions.snow' => 'Sneeuw',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Zware sneeuw',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Motsneeuw',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Lichte buien',
			'operation.layout.panels.weatherConditions.showers' => 'Buien',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Zware buien',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Lichte sneeuwbuien',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Sneeuwbuien',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Onweer',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Licht onweer met hagel',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Onweer met hagel',
			'operation.layout.panels.websiteDescription' => 'Een webpagina naar keuze, in een paneel',
			'operation.layout.panels.websiteUrl' => 'Adres',
			'operation.layout.panels.websiteRefresh' => 'Verversen',
			'operation.layout.panels.websiteRefreshNever' => 'Nooit',
			'operation.layout.panels.websiteRefresh1' => 'Elke minuut',
			'operation.layout.panels.websiteRefresh5' => 'Elke 5 minuten',
			'operation.layout.panels.websiteRefresh15' => 'Elke 15 minuten',
			'operation.layout.panels.websiteTitle' => 'Paneelnaam',
			'operation.layout.panels.websiteRefreshNow' => 'Nu verversen',
			'operation.layout.panels.websiteNoUrl' => 'Nog geen adres. Open de instellingen van dit paneel om een pagina te kiezen.',
			'operation.layout.panels.websiteBadUrl' => 'Dat lijkt geen webadres. Het moet beginnen met https://',
			'operation.layout.panels.websiteNotHttps' => 'Hier kunnen alleen adressen met https:// worden getoond.',
			'operation.layout.panels.websiteUnsupported' => 'Webpagina\'s kunnen op dit systeem niet in een paneel worden getoond.',
			'operation.layout.panels.websiteOpenExternally' => 'Openen in browser',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Kon de pagina niet laden: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Een scherm, app of venster gedeeld door een ander apparaat van jou.',
			'operation.layout.panels.remoteScreenTarget' => 'Scherm',
			'operation.layout.panels.remoteScreenChoose' => 'Kies een scherm…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Gedeelde schermen',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Geen van je apparaten deelt een scherm. Zet Schermen en vensters delen aan onder Instellingen → Peer-apparaten, op het apparaat dat je wilt zien.',
			'operation.layout.panels.remoteScreenUnset' => 'Geen scherm gekozen. Open de instellingen van dit paneel om er een te kiezen dat je andere apparaten delen.',
			'operation.layout.panels.remoteScreenConnecting' => 'Verbinden…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Dat apparaat is nu niet verbonden.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Dat apparaat deelt dit scherm niet meer.',
			'operation.layout.panels.remoteScreenNoListener' => 'Dat apparaat kan geen verbindingen aannemen — controleer de firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Schermen worden alleen via het lokale netwerk gedeeld, niet via Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Dat apparaat weigerde dit scherm te delen.',
			'operation.layout.panels.remoteScreenSettings' => 'Paneelinstellingen',
			'operation.layout.panels.remoteScreenAdjust' => 'Weergave aanpassen',
			'operation.layout.panels.remoteScreenDetail' => 'Detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standaard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Hoog',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximaal',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Inzoomen',
			'operation.layout.panels.remoteScreenZoomOut' => 'Uitzoomen',
			'operation.layout.panels.remoteScreenStopped' => 'Dat scherm of venster wordt niet meer getoond.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Dat apparaat kon dat scherm niet vastleggen — mogelijk is toestemming voor schermopname nodig.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Dat apparaat reageerde niet. Mogelijk staat scherm delen niet aan.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Kon geen verbinding openen voor het beeld. Controleer de firewall op dit apparaat.',
			'operation.layout.panels.solarDescription' => 'Zonne- en geomagnetische omstandigheden, met propagatie per band',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com niet bereikbaar — geen netwerk? Straks nieuwe poging.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com reageerde, maar niet met bruikbare gegevens. Straks nieuwe poging.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Dag',
			'operation.layout.panels.solarBandNight' => 'Nacht',
			'operation.layout.panels.solarBandGood' => 'Goed',
			'operation.layout.panels.solarBandFair' => 'Redelijk',
			'operation.layout.panels.solarBandPoor' => 'Slecht',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Bronnen: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'De verbinding heeft het moeilijk — frames worden overgeslagen.',
			'operation.layout.panels.remoteScreenStalled' => 'Er komen geen frames meer door — deze verbinding is mogelijk te traag.',
			'operation.layout.panels.radioDescription' => 'Het frontpaneel van een radio — frequentie, mode en vermogen, via CAT',
			'operation.layout.panels.radioStyle' => 'Stijl',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — geen radio aangewezen',
			'operation.layout.panels.radioNoRadio' => 'Geen radio om te tonen. Kies er een in de instellingen van dit paneel, of voeg er een toe onder Stationsconfiguratie.',
			'operation.layout.panels.radioNotConfigured' => 'Deze radio is nog niet geconfigureerd. Kies de poort of het adres onder Stationsconfiguratie.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio niet verbonden',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Deze radio verbinden',
			'operation.layout.panels.radioDisconnect' => 'Deze radio loskoppelen',
			'operation.layout.panels.radioStale' => 'GEEN DATA',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'hoge SWR',
			'operation.layout.htmlPanelUnsupported' => 'Dit paneel heeft een webweergave nodig, die dit platform niet biedt',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Dit paneel heeft een sandbox nodig die de webversie niet kan bieden',
			'operation.export.title' => 'Activatie-exports',
			'operation.export.syncedOperation' => 'Activatie is gesynchroniseerd',
			'operation.export.unsyncedOperation' => 'Activatie heeft niet-gesynchroniseerde wijzigingen',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} QSO in deze activatie', other: '${count} QSO\'s in deze activatie', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Alle ${total} QSO\'s zijn gesynchroniseerd',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} van ${total} QSO\'s wachten op synchronisatie',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} gebeurtenismarkeringen gesynchroniseerd',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} van ${total} gebeurtenismarkeringen in afwachting',
			'operation.export.loading' => 'Exportopties laden…',
			'operation.export.noOptions' => 'Geen exportformaten beschikbaar (extensies nog aan het starten?)',
			'operation.export.nothingLogged' => 'Nog niets te exporteren — deze activatie heeft geen QSO\'s.',
			'operation.export.share' => 'Delen',
			'operation.export.nothingSelected' => 'Niets geselecteerd',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand opslaan', other: '${count} bestanden opslaan', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand delen', other: '${count} bestanden delen', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand exporteren', other: '${count} bestanden exporteren', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand downloaden', other: '${count} bestanden downloaden', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} gecombineerd bestand opslaan', other: '${count} gecombineerde bestanden opslaan', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} gecombineerd bestand delen', other: '${count} gecombineerde bestanden delen', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} gecombineerd bestand exporteren', other: '${count} gecombineerde bestanden exporteren', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} gecombineerd bestand downloaden', other: '${count} gecombineerde bestanden downloaden', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => '${name} opslaan',
			'operation.export.shareOne' => ({required Object name}) => '${name} delen',
			'operation.export.exportOne' => ({required Object name}) => '${name} exporteren',
			'operation.export.downloadOne' => ({required Object name}) => '${name} downloaden',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand naar Stash', other: '${count} bestanden naar Stash', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} gecombineerd bestand naar Stash', other: '${count} gecombineerde bestanden naar Stash', ), 
			'operation.export.settingsButton' => 'Exportinstellingen',
			'operation.export.settingsTitle' => 'Exportinstellingen',
			'operation.export.compactFileNames.title' => 'Gebruik compacte bestandsnamen',
			'operation.export.compactFileNames.descriptionOn' => 'Korte namen voor uploaders, zoals N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Leesbare namen, zoals 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Privégegevens opnemen',
			'operation.export.includePrivateData.descriptionOn' => 'Namen, adressen, e-mails, grid squares en notities worden opgenomen',
			'operation.export.includePrivateData.descriptionOff' => 'Namen, adressen, e-mails, grid squares en notities worden weggelaten',
			'operation.export.includePrivateData.note' => 'De volledige ADIF-export bevat altijd alles',
			'operation.export.resultTitle' => 'Export voltooid',
			'operation.export.resultFailedTitle' => 'Export mislukt',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand geëxporteerd naar ${path}', other: '${count} bestanden geëxporteerd naar ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand geëxporteerd: ${path}', other: '${count} bestanden geëxporteerd: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand gedeeld', other: '${count} bestanden gedeeld', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand gedownload', other: '${count} bestanden gedownload', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export mislukt: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Voeg eerst een e-mailadres toe',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash stuurt je bestanden naar het e-mailadres van je LoFi-account, en daarmee log je in op stash.ham2k.net. Je account heeft nog geen bevestigd adres — voeg het toe in Instellingen › Cloud-synchronisatie.',
			'operation.export.stash.openSyncSettings' => 'Cloud-synchronisatie openen',
			'operation.export.stash.replaceTitle' => 'Recente stash wordt vervangen',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Je hebt “${name}” minder dan 6 uur geleden verzonden en het is nog niet gedownload. Gratis accounts bewaren één stash tegelijk, dus nu verzenden vervangt het.',
			'operation.export.stash.replaceConfirm' => 'Toch versturen',
			'operation.export.stash.failedTitle' => 'Kon niet versturen naar Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'Verstuurd naar Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Je kunt dit bestand ophalen door **[stash.ham2k.net](https://stash.ham2k.net)** in een willekeurige browser te bezoeken.', other: 'Je kunt deze bestanden ophalen door **[stash.ham2k.net](https://stash.ham2k.net)** in een willekeurige browser te bezoeken.', ), 
			'operation.export.stash.mayHaveArrived' => 'Geen reactie van de stash — het bestand is mogelijk toch aangekomen. Kijk op stash.ham2k.net voordat je opnieuw verstuurt',
			'operation.export.stash.notSent' => 'niet verzonden',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Dit bestand is niet aangekomen:', other: 'Deze ${count} bestanden zijn niet aangekomen:', ), 
			'operation.export.stash.emailOffer' => 'Of, voor je gemak, kunnen we je een e-mail met een directe link sturen.',
			'operation.export.stash.emailMe' => 'Stuur mij een link per e-mail',
			'operation.export.stash.emailSent' => 'We hebben je een downloadlink per e-mail gestuurd.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Kon de e-mail niet versturen: ${error}',
			'operation.export.stash.freeTier' => 'Gratis accounts kunnen maar één stash tegelijk bewaren. Abonnees kunnen er zoveel bewaren als ze willen.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} bestand verstuurd naar Ham2K File Stash (stash.ham2k.net)', other: '${count} bestanden verstuurd naar Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Geen spots die aan je filters voldoen',
			'operation.spots.error' => ({required Object error}) => 'Spots laden mislukt: ${error}',
			'operation.spots.unknownBand' => 'Andere',
			'operation.spots.auto' => 'Automatisch',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatisch (momenteel ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Alle',
			'operation.spots.allBands' => 'Alle banden',
			'operation.spots.allModes' => 'Alle modes',
			'operation.spots.phoneAndCw' => 'SSB & CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => '${count} van ${total} spots getoond',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minuten',
			'operation.spots.callsOfNote' => 'Opmerkelijke roepnamen',
			'operation.spots.yourSpots' => 'Jouw spots',
			'operation.spots.allSpots' => 'Alle spots',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Azië',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Noord-Amerika',
			'operation.spots.continents.oc' => 'Oceanië',
			'operation.spots.continents.sa' => 'Zuid-Amerika',
			'operation.spots.continents.an' => 'Antarctica',
			'operation.spots.filters.title' => 'Spots filteren',
			'operation.spots.filters.band' => 'Band',
			'operation.spots.filters.mode' => 'Mode',
			'operation.spots.filters.age' => 'Leeftijd',
			'operation.spots.filters.sources' => 'Bronnen',
			'operation.spots.filters.continent' => 'Continent',
			'operation.spots.filters.sorting' => 'Sortering',
			'operation.spots.filters.sortByTime' => 'Op spottijd',
			'operation.spots.filters.sortByFrequency' => 'Op frequentie',
			'operation.spots.filters.groupByBand' => 'Groeperen per band',
			'operation.spots.filters.groupCallsWithNotes' => 'Roepnamen met notities groeperen',
			'operation.spots.filters.sourceNoReply' => 'Geen reactie',
			'operation.spots.filters.sourceError' => 'Fout',
			'operation.spots.unavailableTitle' => 'Spots niet beschikbaar',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} reageerde niet.',
			'operation.spots.failedTitle' => 'Fout bij spotbron',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} gaf een fout terug.',
			'operation.spots.slideLogIt' => 'Loggen',
			'operation.spots.slideIgnore' => 'Negeren',
			'operation.spots.slideRestore' => 'Herstellen',
			'operation.spots.logConflict.title' => 'Logpaneel is bezet',
			'operation.spots.logConflict.editingBody' => 'Je bewerkt een gelogd QSO. Deze spot in plaats daarvan loggen, of teruggaan en de bewerking afmaken?',
			'operation.spots.logConflict.composingBody' => 'Je bent begonnen met het invoeren van een QSO. Deze spot in plaats daarvan loggen, of teruggaan en afmaken wat je aan het typen was?',
			'operation.spots.logConflict.goBack' => 'Teruggaan',
			'operation.spots.logConflict.clearAndLog' => 'Wissen en spot loggen',
			'operation.import.title' => 'Gegevens importeren in activatie',
			'operation.import.importAdifAction' => 'QSO\'s importeren uit ADIF',
			'operation.import.settingsButton' => 'Luisterinstellingen',
			'operation.import.settingsTitle' => 'Luisteren naar andere apps',
			'operation.import.protocolAddressLabel' => 'Adres',
			'operation.import.protocolPortLabel' => 'Poort',
			'operation.import.protocolPortInvalid' => 'Voer een poort in tussen 1 en 65535',
			'operation.import.protocolAddressInvalid' => 'Voer een geldig IP-adres in (bijv. 127.0.0.1 of 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Gegevens worden ontvangen',
			'operation.import.protocolStatusNoData' => 'Recent geen gegevens ontvangen',
			'operation.import.protocolBindError' => ({required Object error}) => 'Kon niet beginnen met luisteren: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Binnenkomende QSO\'s konden niet worden opgeslagen en worden opnieuw geprobeerd: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Alle (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → tabblad Broadcast Data → vink "Enable Broadcasts" aan voor contact info. Stel het IP-adres in op 127.0.0.1 als het op deze computer draait, of 255.255.255.255 om op het huidige lokale netwerk uit te zenden.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → tabblad Reporting → sectie UDP Server → vink "Accept UDP requests" aan. Stel UDP Server in op 127.0.0.1 als het op deze computer draait, of op een multicastadres zoals 239.239.0.2, en gebruik hetzelfde adres in de configuratie hierboven in deze app.',
			'operation.import.listenTitle' => 'Luisteren naar QSO\'s van andere apps',
			'operation.import.listenDescriptionOnN1mm' => 'Luistert naar N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Luistert naar WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Luistert naar N1MM+ en WSJT-X',
			'operation.import.listenDescriptionOff' => 'Uit',
			'operation.import.addToOperationTitle' => 'Toevoegen aan deze activatie',
			'operation.import.addToOperationDescriptionOn' => 'Ontvangen QSO\'s worden bij aankomst aan deze activatie toegevoegd',
			'operation.import.addToOperationDescriptionOff' => 'Ontvangen QSO\'s worden vastgehouden tot je dit aanzet',
			'operation.import.pendingSectionTitle' => 'Ontvangen QSO\'s',
			'operation.import.pendingEmpty' => 'Nog niets ontvangen',
			'operation.import.stationMismatch' => ({required Object call}) => 'Gelogd als ${call}, niet het station van deze activatie',
			'operation.import.discardAction' => 'Weggooien',
			'operation.import.gapDialogTitle' => 'Eerdere ontvangsten meenemen?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Er zijn eerder nog ${count} QSO\'s ontvangen, vóór een onderbreking in de gegevens. Die ook meenemen?',
			'operation.import.gapDialogRecentOnly' => 'Alleen de recente',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Alle ${count} meenemen',
			'map.outlineIssue.link' => 'Problemen?',
			'map.outlineIssue.title' => 'Probleem met een omtrek melden',
			'map.outlineIssue.reference' => 'Welke omtrek',
			'map.outlineIssue.severity' => 'Hoe erg is het?',
			'map.outlineIssue.minor' => 'Klein detail',
			'map.outlineIssue.major' => 'Groot probleem',
			'map.outlineIssue.explanation' => 'Wat is er mis mee?',
			'map.outlineIssue.explanationHint' => 'Wat de omtrek fout heeft, en waar',
			'map.outlineIssue.send' => 'Versturen',
			'map.outlineIssue.sending' => 'Je melding wordt verstuurd — bedankt',
			'map.outlineIssue.copy' => 'Melding kopiëren',
			'map.outlineIssue.notSent' => 'Kon de melding niet versturen',
			'map.outlineIssue.copied' => 'Melding gekopieerd',
			'map.outlineIssue.notCopied' => 'Kon de melding niet kopiëren',
			'map.outlinesDisclaimer' => 'Omtrekken zijn alleen ter referentie. Doe je eigen onderzoek!',
			'map.outlinesCredit' => ({required Object sources}) => 'Omtrekken: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Grenzen: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Voorzieningen: ${sources}',
			'map.fullCredits' => 'Volledige bronvermelding',
			'map.fewerCredits' => 'Minder bronnen',
			'map.emptyState' => 'Nog geen QSO-locaties.\nQSO\'s met een grid square, staat of land verschijnen hier.',
			'map.unavailable' => 'De kaart is nu niet beschikbaar.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plat',
			'map.globe' => 'Globe',
			'map.zoomIn' => 'Inzoomen',
			'map.zoomOut' => 'Uitzoomen',
			'map.postcard.button' => 'Activatie-ansichtkaart',
			'map.postcard.title' => ({required Object title}) => 'Ansichtkaart voor ${title}',
			'map.postcard.portrait' => 'Staand',
			'map.postcard.landscape' => 'Liggend',
			'map.postcard.square' => 'Vierkant',
			'map.postcard.save' => 'Opslaan…',
			'map.postcard.download' => 'Downloaden',
			'map.postcard.share' => 'Delen',
			'map.postcard.copy' => 'Kopiëren',
			'map.postcard.copied' => 'Gekopieerd naar het klembord',
			'map.postcard.saved' => ({required Object path}) => 'Opgeslagen in ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} gedownload',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} afbeeldingen opgeslagen in ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} opgeslagen',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} was al opgeslagen',
			'map.postcard.downloadedMany' => ({required Object count}) => '${count} afbeeldingen downloaden — sta ze toe als de browser erom vraagt',
			'map.postcard.mapLeftOut' => 'De kaart laadde niet en is weggelaten',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — de kaart laadde niet en is weggelaten',
			'map.postcard.continued' => ({required Object title}) => '${title} (vervolg)',
			'map.postcard.previousPage' => 'Vorige pagina',
			'map.postcard.nextPage' => 'Volgende pagina',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Pagina ${page} van ${count}',
			'map.postcard.sections' => 'Samenvattingssecties',
			'map.postcard.sectionDays' => 'Elke dag',
			'map.postcard.reset' => 'Resetten',
			'map.postcard.failed' => ({required Object error}) => 'Kon de ansichtkaart niet maken: ${error}',
			'map.postcard.mapNotReady' => 'De kaart is niet volledig geladen. Controleer de verbinding en probeer het opnieuw.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Kon de ansichtkaart niet opslaan: ${error}',
			'map.postcard.copyFailed' => 'Het klembord nam de afbeelding niet aan. Probeer het opnieuw.',
			'map.postcard.shareFailed' => 'Kon de ansichtkaart niet delen. Probeer het opnieuw.',
			'map.postcard.fileName' => 'ansichtkaart',
			'mapsView.title' => 'Kaarten',
			'mapsView.searchHint' => 'Zoek parken, toppen en meer',
			'mapsView.activities' => 'Activiteiten',
			'mapsView.layers' => 'Lagen',
			'mapsView.baseMap' => 'Basiskaart',
			'mapsView.satellite' => 'Satelliet (Esri)',
			'mapsView.facilities' => 'Parkvoorzieningen',
			'mapsView.boundaries' => 'Grenzen',
			'mapsView.currentLocation' => 'Huidige locatie',
			'mapsView.noMatches' => ({required Object text}) => 'Niets gevonden voor “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} referentie bij ${where}', other: '${count} referenties bij ${where}', ), 
			'mapsView.startOperation' => 'Start een activatie met deze referenties',
			'activitiesView.title' => 'Activiteiten',
			'activitiesView.activitiesCountZero' => 'Geen activiteiten geselecteerd',
			'activitiesView.activitiesCountOne' => '1 activiteit',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} activiteiten',
			'activitiesView.empty' => 'Nog geen activiteiten — gebruik Suggesties & zoeken hieronder om er een toe te voegen',
			'activitiesView.removeActivity' => 'Verwijderen',
			'activitiesView.openReferenceLink' => ({required Object name}) => '${name} openen',
			'activitiesView.editActivity' => 'Activiteit bewerken',
			'activitiesView.manageExtensions' => 'Extensies beheren',
			'activitiesView.manage' => 'Beheren',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Activiteitstypen: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Activiteitstypen: ${first} en ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Activiteitstypen: ${first}, ${second} en ${more} meer',
			'activitiesView.reference' => 'Referentie',
			'activitiesView.invalidReference' => 'Ongeldig',
			'activitiesView.duplicateReference' => 'Al toegevoegd',
			'activitiesView.searchHint' => 'Zoek op naam, referentie of iets anders…',
			'activitiesView.noSuggestions' => 'Geen resultaten',
			'activitiesView.noSuggestionsHint' => 'Zoek hierboven op naam of nummer van de referentie',
			'activitiesView.noSuggestionsExample' => '(bijvoorbeeld \'trail\' of \'4556\')',
			'activitiesView.allOptions' => 'Activiteitstypen',
			'activitiesView.determiningLocation' => 'Huidige locatie bepalen…\nWachten op GPS-fix om referenties in de buurt te vinden',
			'activitiesView.locationUnavailableTitle' => 'Locatiegegevens niet beschikbaar',
			'activitiesView.locationDeniedTitle' => 'Locatietoestemming geweigerd',
			'activitiesView.locationBlockedTitle' => 'Locatietoestemming geblokkeerd',
			'activitiesView.noNearbyReason' => 'Kan referenties in de buurt niet bepalen',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Tik op ${icon} om je locatie handmatig in te voeren,\nof zoek referenties gewoon op naam',
			'activitiesView.locationGrantAction' => 'Locatietoegang toestaan',
			'activitiesView.locationSettingsAction' => 'Instellingen openen',
			'activitiesView.locationSettingsUnavailable' => 'Sta locatietoegang toe in je systeeminstellingen',
			'activitiesView.locationGrantRefused' => 'Nog steeds geen locatie — het systeem weigerde opnieuw',
			'activitiesView.searchUnavailableTitle' => 'Activiteiten zoeken niet beschikbaar',
			'activitiesView.searchUnavailableReason' => 'Geen activiteitsextensie kon de zoekopdracht uitvoeren. Probeer het zo opnieuw.',
			'activitiesView.emptySheet' => 'Gebruik suggesties & zoeken hieronder om er een toe te voegen',
			'activitiesView.exports' => 'Exports',
			'activitiesView.exportLogs' => 'Logboeken exporteren',
			'activitiesView.tools' => 'Gereedschap',
			'activitiesView.toolsTitle' => 'Activatiegereedschap',
			'activitiesView.operationDetails' => 'Activatiegegevens',
			'activitiesView.share' => 'Delen',
			'activitiesView.archive' => 'Archiveren',
			'activitiesView.deleteOperation' => 'Activatie verwijderen',
			'activitiesView.undeleteOperation' => 'Activatie herstellen',
			'activitiesView.alreadySelected' => 'Al geselecteerd',
			'activitiesView.selected' => 'Geselecteerd',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} van ${count}',
			'activitiesView.previousPick' => 'Vorig resultaat',
			'activitiesView.nextPick' => 'Volgend resultaat',
			'activitiesView.retiredReference' => 'Vervallen',
			'activitiesView.enableExtension' => ({required Object name}) => '${name} inschakelen',
			'activitiesView.enableExtensionHint' => 'Deze extensie past bij je zoekopdracht, maar is momenteel niet ingeschakeld',
			'activitiesView.enableExtensionForRefHint' => 'Deze extensie behandelt een van de referenties van deze activatie, maar is momenteel niet ingeschakeld',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} draait niet',
			'activitiesView.extensionNotRunningHint' => 'Deze extensie is uitgeschakeld; open Extensie-instellingen voor meer info',
			'activitiesView.installExtension' => ({required Object name}) => '${name} installeren',
			'activitiesView.installExtensionHint' => 'Deze extensie past bij je zoekopdracht, maar is niet geïnstalleerd',
			'activitiesView.onlyCatalogMatches' => 'Geen resultaten\nSommige extensies in de catalogus hebben mogelijk resultaten.\nInstalleer ze hieronder bij Activiteitstypen.',
			'activitiesView.setupUnavailable' => 'Kon de instellingen van deze activiteit niet laden — probeer het opnieuw via Beheren',
			'activitiesView.controlsUnavailableTitle' => 'Activiteitsbediening niet beschikbaar',
			'activitiesView.controlsUnavailableReason' => 'Je referenties zijn veilig, maar ze bewerken is nu niet mogelijk.',
			'activitiesView.controlsUnavailableRetry' => 'Opnieuw proberen',
			'activitiesView.onlyDisabledMatches' => 'Geen resultaten\nSommige beschikbare extensies hebben mogelijk resultaten.\nSchakel ze hieronder in bij Activiteitstypen.',
			'activitiesView.onlyNotRunningMatches' => 'Geen resultaten\nSommige extensies die mogelijk resultaten hebben draaien niet.\nZie Activiteitstypen hieronder.',
			'activitiesView.mapToggle' => 'Kaart',
			'activitiesView.searchToggle' => 'Zoeken',
			'activitiesView.addToOperation' => 'Toevoegen aan activatie',
			'activitiesView.addToOperationShort' => 'Toevoegen',
			'activitiesView.mapEmptyState' => 'Geen resultaten om op de kaart te tonen',
			'activitiesView.mapEmptyStateHint' => 'Ga terug naar de lijst, of zoek iets anders',
			'activitiesView.imports' => 'Imports',
			'loggingControls.timeUtc' => 'Tijd (UTC)',
			'loggingControls.date' => 'Datum',
			'loggingControls.now' => 'Nu',
			'loggingControls.frequency' => 'Frequentie',
			'loggingControls.mode' => 'Mode',
			'loggingControls.theirCall' => 'Hun roepnaam',
			'loggingControls.noteField' => 'Notitie',
			'loggingControls.todoField' => 'To-do',
			'loggingControls.sent' => 'Verzonden',
			'loggingControls.rcvd' => 'Ontvangen',
			'loggingControls.more' => 'Meer',
			'loggingControls.revert' => 'Herstellen',
			'loggingControls.undoDelete' => 'Verwijderen ongedaan maken',
			'loggingControls.restore' => 'Terugzetten',
			'loggingControls.wipe' => 'Wissen',
			'loggingControls.undo' => 'Ongedaan maken',
			'loggingControls.pendingDeleteTapWarning' => 'Tik nog een keer op de prullenbak om dit QSO te verwijderen',
			'loggingControls.pendingDeleteClickWarning' => 'Klik nog een keer op de prullenbak om dit QSO te verwijderen',
			'loggingControls.deletedQsoWarning' => 'Verwijderd QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Tik nog een keer op de prullenbak om deze ${kind} te verwijderen',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Klik nog een keer op de prullenbak om deze ${kind} te verwijderen',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} verwijderd',
			'loggingControls.timeControl' => 'Tijd',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Vermogen',
			'loggingControls.notesControl' => 'Notities',
			'loggingControls.power' => 'Vermogen',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Logbediening',
			'loggingControls.spottingControl' => 'Spotten',
			'loggingControls.spottingSelfControl' => 'Zelfspotten',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Zelfspot op ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} op ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Te laat om ${call} te spotten',
			'loggingControls.spotNoFreq' => 'Stel eerst een frequentie in om te spotten',
			'loggingControls.spotComment' => 'Opmerking',
			'loggingControls.bandOrFreqRequired' => 'Stel een frequentie of band in voordat je logt',
			'loggingControls.missingBand' => 'Geen band',
			'loggingControls.missingMode' => 'Geen mode',
			'loggingControls.saveFailed' => ({required Object error}) => 'Kon niet opslaan: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Kon niet verwijderen: ${error}',
			'loggingControls.info.noQsos' => 'Nog geen QSO\'s… Laten we starten!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO\'s',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} sinds de laatste',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h voor de laatste 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h voor de laatste 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} naar',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) naar',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) naar',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} verwijderd',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verwijderd',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verwijderd',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Dupe!',
			'loggingControls.info.noticeNewBand' => 'Nieuwe band',
			'loggingControls.info.noticeNewMode' => 'Nieuwe mode',
			'loggingControls.info.noticeNewDXCC' => 'Nieuwe DXCC',
			'loggingControls.info.noticeNewState' => 'Nieuwe staat',
			'loggingControls.info.noticeNewProvince' => 'Nieuwe provincie',
			'loggingControls.info.noticeNewDay' => 'Nieuwe dag',
			'loggingControls.info.noticeNewRef' => 'Nieuwe ref',
			'loggingControls.info.noticeNewMult' => 'Nieuwe multiplier',
			'loggingControls.info.noticeNewZone' => 'Nieuwe zone',
			'loggingControls.info.noticeInvalidMode' => 'Verkeerde mode',
			'loggingControls.info.noticeInvalidBand' => 'Verkeerde band',
			'loggingControls.info.noticeInvalidCategory' => 'Niet werkbaar',
			'loggingControls.info.noticeWorkedBefore' => 'Eerder gewerkt',
			'loggingControls.info.noticeNewPark' => 'Nieuw park',
			'loggingControls.info.noticeNewSection' => 'Nieuwe sectie',
			'loggingControls.info.noticeBonusStation' => 'Bonusstation!',
			'loggingControls.info.noticeMissingExchange' => 'Geen uitwisseling',
			'loggingControls.info.noticeInvalidExchange' => 'Foute uitwisseling',
			'loggingControls.info.noticeUnknownEvent' => 'Onbekend evenement',
			'loggingControls.info.noticeOurGrid' => 'Stel ons grid in',
			'loggingControls.info.noticeRareCounty' => 'Zeldzame county!',
			'loggingControls.info.noticeOurLocation' => 'Stel onze county in',
			'loggingControls.info.noticeShortGrid' => 'Grid te kort',
			'formChrome.untitled' => '(zonder titel)',
			'formChrome.showMore' => 'Meer tonen',
			'formChrome.showAll' => 'Alles tonen',
			'formChrome.showFewer' => 'Minder tonen',
			'formChrome.defaults' => 'Standaardwaarden',
			'formChrome.search' => 'Zoeken',
			'formChrome.clear' => 'Wissen',
			'formChrome.openPage' => 'Pagina openen',
			'formChrome.connected' => 'Verbonden',
			'formChrome.notConnected' => 'Niet verbonden',
			'formChrome.manage' => 'Beheren',
			'formChrome.connect' => 'Verbinden',
			'formChrome.formTitle' => 'Formulier',
			'formChrome.addItem' => ({required Object label}) => '${label} toevoegen',
			'formChrome.editItem' => ({required Object label}) => '${label} bewerken',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => '${shown} van ${total} getoond (${selected} geselecteerd)',
			'formChrome.validationError' => ({required Object error}) => 'Validatiefout: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Transformatiefout: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Fout: ${error}',
			'formChrome.removeItem' => 'Verwijderen',
			'formChrome.storageUnavailable' => 'Aanmeldgegevens niet beschikbaar',
			'qsoEditForm.title' => 'QSO bewerken',
			'qsoEditForm.operatorCall' => 'Operator',
			'qsoEditForm.position' => 'Positie',
			'qsoEditForm.theirName' => 'Naam',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Staat',
			'qsoEditForm.band' => 'Band',
			'qsoEditForm.notes' => 'Notities',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Hun info',
			'qsoEditForm.sectionOur' => 'Onze info',
			'qsoEditForm.sectionNotes' => 'Notities',
			'qsoEditForm.theirCity' => 'Stad',
			'qsoEditForm.theirCounty' => 'County',
			'qsoEditForm.theirEntity' => 'Entiteit',
			'qsoEditForm.theirCqZone' => 'CQ-zone',
			'qsoEditForm.theirItuZone' => 'ITU-zone',
			'qsoEditForm.theirArrlSection' => 'ARRL Sectie',
			'qsoEditForm.theirLat' => 'Breedtegraad',
			'qsoEditForm.theirLon' => 'Lengtegraad',
			'qsoEditForm.theirPower' => 'Hun vermogen',
			'qsoList.empty' => 'Nog geen QSO\'s — werk iemand!',
			'qsoList.bandOrModeWarning' => 'Controleer of je band en mode kloppen',
			'qsoList.today' => 'Vandaag',
			'qsoList.yesterday' => 'Gisteren',
			'qsoList.tomorrow' => 'Morgen',
			'loggingPanel.stats' => 'Activatie statistieken',
			'loggingPanel.scoring' => 'Puntentelling',
			'loggingPanel.dxccEntities' => 'DXCC-entiteiten',
			'loggingPanel.statesWorked' => 'Staten',
			'loggingPanel.provincesWorked' => 'Provincies',
			'loggingPanel.duplicates' => 'Dubbels',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Afbeelding tonen',
			'callInfo.imageUnavailable' => 'Foto niet beschikbaar',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Notities',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} naar',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) naar',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) naar',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} verwijderd',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) verwijderd',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) verwijderd',
			'callInfo.thisOpCountOne' => '1 QSO in deze activatie',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSO\'s in deze activatie',
			'callInfo.otherOpsCountOne' => '1 QSO in andere activaties',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSO\'s in andere activaties',
			'callInfo.andMore' => ({required Object count}) => '… en ${count} meer',
			'callInfo.withCall' => ({required Object call}) => 'met ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'van ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} in de laatste 7 dagen',
			'callInfo.history.today' => ({required Object n}) => '${n} vandaag',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${n} QSO', other: '${n} QSO\'s', ), 
			'settings.title' => 'Instellingen',
			'settings.language' => 'Taal',
			'settings.languageSystem' => ({required Object language}) => 'Systeeminstellingen volgen (${language})',
			'settings.theme.title' => 'Thema',
			'settings.theme.system' => 'Systeeminstellingen volgen',
			'settings.theme.light' => 'Licht',
			'settings.theme.dark' => 'Donker',
			'settings.themeDescription.system' => 'Volgt de systeeminstellingen',
			'settings.themeDescription.light' => 'Altijd in Lichte Modus',
			'settings.themeDescription.dark' => 'Altijd in Donkere Modus',
			'settings.fontScale' => 'Lettergrootte',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Kleinste--',
			'settings.fontScaleOpts.smallestMinus' => 'Kleinste-',
			'settings.fontScaleOpts.smallest' => 'Kleinste',
			'settings.fontScaleOpts.smaller' => 'Kleiner',
			'settings.fontScaleOpts.normal' => 'Normaal',
			'settings.fontScaleOpts.larger' => 'Groter',
			'settings.fontScaleOpts.largest' => 'Grootste',
			'settings.fontScaleOpts.largestPlus' => 'Grootste+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Grootste++',
			'settings.keepDeviceAwake.title' => 'Houd apparaat actief',
			'settings.keepDeviceAwake.descriptionOn' => 'Blijft wakker zolang je in de logweergave bent of er een synchronisatie loopt',
			'settings.keepDeviceAwake.descriptionOff' => 'Slaapt zoals gewoonlijk',
			'settings.layoutDensity' => 'Indelingsdichtheid',
			'settings.layoutDensityOpts.auto' => 'Automatisch',
			'settings.layoutDensityOpts.densest' => 'Dichtst',
			'settings.layoutDensityOpts.dense' => 'Dicht',
			'settings.layoutDensityOpts.normal' => 'Normaal',
			'settings.layoutDensityOpts.sparse' => 'Ruim',
			'settings.layoutDensityOpts.sparsest' => 'Ruimst',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'het venster is te laag, ${effective} wordt gebruikt',
			'settings.layoutDensityAtLimit' => 'maximaal',
			'settings.distanceUnits' => 'Afstandseenheden',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometers',
			'settings.distanceUnitsOpts.miles' => 'Mijlen',
			'settings.userInterface' => 'Gebruikersinterface',
			'settings.logging.title' => 'Loggen',
			'settings.logging.leftieMode.title' => 'Linkshandige modus',
			'settings.logging.leftieMode.descriptionOn' => 'De linkshandige indeling gebruiken',
			'settings.logging.leftieMode.descriptionOff' => 'De rechtshandige indeling gebruiken',
			'settings.logging.countryFlags.title' => 'Vlaggen van landen',
			'settings.logging.countryFlags.dx' => 'Alleen tonen voor DX-QSO\'s',
			'settings.logging.countryFlags.all' => 'Vlaggen tonen voor alle QSO\'s',
			'settings.logging.countryFlags.none' => 'Geen vlaggen tonen',
			'settings.logging.countryFlagsDescription.dx' => 'Alleen vlaggen tonen voor DX-QSO\'s',
			'settings.logging.countryFlagsDescription.all' => 'Vlaggen tonen voor alle QSO\'s',
			'settings.logging.countryFlagsDescription.none' => 'Geen vlaggen tonen',
			'settings.logging.suggestDefaultOperator.title' => 'Operator voorstellen',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Je roepnaam wordt als operator voorgesteld als een activatie onder een andere stationroepnaam loopt',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'De operator blijft leeg tenzij je hem invult',
			'settings.logging.showBearing.title' => 'Toon azimut',
			'settings.logging.showBearing.descriptionOn' => 'Geschatte peiling naar station tonen',
			'settings.logging.showBearing.descriptionOff' => 'Geen peilingsinformatie tonen',
			'settings.logging.showReverseBearing.title' => 'Ook tegenpeiling tonen',
			'settings.logging.showReverseBearing.descriptionOn' => 'Peiling vanaf het station ook tonen, zoals "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Alleen peiling naar station tonen',
			'settings.logging.switchSentRcvd.title' => 'Wijzig volgorde signaalrapport',
			'settings.logging.switchSentRcvd.sentFirst' => 'Verzonden eerst, ontvangen daarna',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Ontvangen eerst, verzonden daarna',
			'settings.logging.jumpAfterRST.title' => 'Ga naar volgende veld bij RST-invoer',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Na RST naar het volgende veld springen',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Niet automatisch springen',
			'settings.logging.defaultReport.title' => 'Standaardrapport — spraak',
			'settings.logging.defaultReport.description' => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij SSB, FM of AM',
			'settings.logging.defaultReportCW.title' => 'Standaardrapport — CW en data',
			'settings.logging.defaultReportCW.description' => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij CW, RTTY en andere datamodes',
			'settings.logging.defaultReportFT8.title' => 'Standaardrapport — FT8 en FT4',
			'settings.logging.defaultReportFT8.description' => 'Gebruikt als Verzonden of Ontvangen leeg blijft bij de FT-modes',
			'settings.logging.numbersRow.title' => 'Cijferrij',
			'settings.logging.numbersRow.description' => 'Toon een rij cijfertoetsen boven het toetsenbord tijdens het loggen',
			'settings.logging.numbersRowExtra.title' => 'Schuine streep- en punttoets',
			'settings.logging.numbersRowExtra.description' => 'Voegt een contextuele toets toe: “/” voor roepnamen, “.” voor getallen',
			'settings.logging.numbersRowVibrate.title' => 'Trillen bij toetsaanslag',
			'settings.logging.numbersRowVibrate.description' => 'Haptische feedback als je op een cijfertoets tikt',
			'settings.logging.bands' => 'Voorkeursbanden',
			'settings.logging.modes' => 'Voorkeursmodes',
			'settings.catServer.title' => 'CAT-server',
			'settings.catServer.description' => 'Laat andere apps (WSJT-X, loggers, enz.) de radio bedienen via Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocol',
			'settings.catServer.protocolOpts.off' => 'Uitgeschakeld',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Poort',
			'settings.catServer.openAccess' => 'Open toegang',
			'settings.catServer.openAccessOn' => 'Elke computer op het lokale netwerk kan verbinden.',
			'settings.catServer.openAccessOff' => 'Alleen apps op deze computer kunnen verbinden.',
			'settings.catServer.off' => 'Uit.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, wordt gestart…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} op poort ${port}. Verbonden clients: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} op poort ${port}, maar er is geen Main VFO-radio verbonden.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} kan niet luisteren op poort ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} kan niet luisteren op poort ${port}: een ander programma gebruikt die, vaak ${protocol} zelf. Sluit dat programma of kies een andere poort.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} kan niet luisteren op poort ${port}: deze computer staat dat niet toe. Kies een poort boven 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} is gestopt met luisteren op poort ${port}. Nieuwe poging…',
			_ => null,
		} ?? switch (path) {
			'settings.radio.title' => 'CAT-besturing',
			'settings.radio.loggingAndCat' => 'Loggen & CAT',
			'settings.radio.tuningSection' => 'Afstemmen',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Diensten',
			'settings.radio.stationConfigurationSection' => 'Stationsconfiguratie',
			'settings.radio.moreSettings' => 'Meer instellingen voor stationsconfiguratie',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'PTT bedienen met [\']',
			'settings.radio.pttKey.descriptionOn' => 'In spraakmodes zet [\'] de radio op zenden en [\'] nogmaals weer op ontvangen. Na een minuut gaat hij vanzelf terug op ontvangen.',
			'settings.radio.pttKey.descriptionOff' => 'De [\']-toets zet de radio niet op zenden.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Zenden',
			'settings.radio.smartVfoSnap.title' => 'Slimme VFO-afronding',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Als je stopt met draaien, wordt de frequentie afgerond op een zinnige stap. Alleen spraakmodes.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Blijft precies waar je hebt afgestemd.',
			'settings.radio.snapDebounce.title' => 'Slimme afronding: wachttijd',
			'settings.radio.snapDebounce.description' => 'Hoe lang de knop stil moet staan voordat de frequentie wordt afgerond. Korter voelt direct; langer laat ruimte voor een trage beweging.',
			'settings.radio.snapLongMove.title' => 'Slimme afronding: lange beweging',
			'settings.radio.snapLongMove.description' => 'Draai minstens zo ver en de frequentie wordt afgerond op een hele kHz, hoe langzaam je ook eindigde.',
			'settings.radio.snapMinMove.title' => 'Slimme afronding: kleinste beweging',
			'settings.radio.snapMinMove.description' => 'Draai minder dan dit en de frequentie wordt niet afgerond, zodat fijnafstemming blijft staan.',
			'settings.radio.snapMinSpeed.title' => 'Slimme afronding: traagste beweging',
			'settings.radio.snapMinSpeed.description' => 'Draai langzamer dan dit en de frequentie wordt niet afgerond, tenzij het een lange beweging was.',
			'settings.radio.enterSends.pillOff' => 'ESM uit',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter verstuurt berichten',
			'settings.radio.enterSends.off' => 'Uit',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter verstuurt berichten: ${state}. Tik om te wijzigen.',
			'settings.radio.keyerSpeed.title' => 'Keyersnelheid',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW-keyerberichten',
			'settings.radio.cwMessages.notSupported' => 'De huidige radio ondersteunt geen CW-keying',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Bericht (${n})',
			'settings.radio.cwMessages.labelField' => 'Label',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Label F${n}',
			'settings.radio.cwMessages.details' => 'Details',
			'settings.radio.cwMessages.empty' => '(leeg)',
			'settings.radio.cwMessages.sets' => 'Berichtenset',
			'settings.radio.cwMessages.newSet' => 'Nieuwe set',
			'settings.radio.cwMessages.renameSet' => 'Set hernoemen',
			'settings.radio.cwMessages.deleteSet' => 'Set verwijderen',
			'settings.radio.cwMessages.newSetName' => 'Naam',
			'settings.radio.cwMessages.setDefault' => 'Standaard',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM-berichten',
			'settings.radio.cwMessages.setSaved' => 'Mijn berichten',
			'settings.radio.cwMessages.repeat' => 'Bericht #1 herhalen',
			'settings.radio.cwMessages.repeatOff' => 'Nee',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Na ${n} seconden',
			'settings.radio.cwMessages.repeatWait' => 'Herhalen',
			'settings.radio.cwMessages.keyboard' => 'Typ om te verzenden',
			'settings.radio.cwMessages.keyboardField' => 'Typ om te verzenden',
			'settings.radio.cwMessages.closeArea' => 'Keyergebied sluiten',
			'settings.radio.cwMessages.help' => 'Help',
			'settings.radio.cwMessages.helpTitle' => 'CW-berichten schrijven',
			'settings.radio.cwMessages.helpIntro' => 'Berichten kunnen sjablonen met de volgende waarden gebruiken:',
			'settings.radio.cwMessages.helpOpCall' => 'Je roepnaam',
			'settings.radio.cwMessages.helpQsoCall' => 'Hun roepnaam — in een //-stapel de roepnaam die gelogd wordt',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Hun roepnaam, als er een geldige roepnaam is; leeg bij een gedeeltelijke',
			'settings.radio.cwMessages.helpQsoPartial' => 'Een gedeeltelijke roepnaam; leeg als er een volledige geldige roepnaam is',
			'settings.radio.cwMessages.helpQsoNextCall' => 'In een //-stapel de roepnaam die hierna voor het loggen wordt geselecteerd, als er een geldige volledige roepnaam is',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'In een //-stapel de volgende gedeeltelijke roepnaam na het loggen van het huidige QSO',
			'settings.radio.cwMessages.helpQsoName' => 'Hun voornaam, zoals getypt of anders uit het opzoeken',
			'settings.radio.cwMessages.helpQsoState' => 'Hun staat, zoals getypt of anders uit het opzoeken',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Bericht 1 zoals het verzonden zou worden, binnen een ander bericht. Geldig voor berichten 1 tot en met 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Het rapport dat je verzendt',
			'settings.radio.cwMessages.helpQsoSerial' => 'Je volgnummer, in een contest die er een verzendt',
			'settings.radio.cwMessages.helpPad' => 'Vult aan met nullen tot zoveel cijfers: 7 wordt verzonden als 007',
			'settings.radio.cwMessages.helpCut' => 'Afgekorte cijfers, T voor 0 en N voor 9: 599 wordt verzonden als 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Kiest de af te korten cijfers, tussen aanhalingstekens — 0 is T, 1 is A, 5 is E, 9 is N',
			'settings.radio.cwMessages.helpFullExample' => 'Volledig voorbeeld:',
			'settings.radio.cwMessages.helpExample' => 'Verzendt W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Met Enter verstuurt berichten aan verstuurt Enter berichten via hun functietoets, zoals N1MM doet. De set ESM-berichten begint met deze:',
			'settings.radio.cwMessages.helpEsmCq' => 'Bij Run roept Enter met een leeg roepnaamveld CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Je uitwisseling: na hun roepnaam bij Run, nadat ze reageren bij S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Bedankt, zodra het QSO gelogd is: de plaatshouders verwijzen naar het volgende QSO, niet naar dit',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Bij S&P je roepnaam aan het station dat je beantwoordt',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Bij Run hun roepnaam vóór je uitwisseling',
			'settings.radio.cwMessages.helpEsmAgain' => 'Vraagt opnieuw als er niets van hun uitwisseling is opgenomen',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Voorgestelde F3 voor //-stapels: TU gaat uit nadat het QSO gelogd is, dus het bedankt, roept dan het volgende gestapelde station en verstuurt je uitwisseling, of vraagt een gedeeltelijke roepnaam terug (TU KR?); als er niets over is, alleen TU',
			'settings.radio.voiceMessages.title' => 'Spraak-keyerberichten',
			'settings.radio.voiceMessages.notSupported' => 'De huidige radio ondersteunt geen spraakberichten',
			'settings.radio.voiceMessages.description' => 'Dit gebruikt de spraakgeheugens van de radio',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Spraakgeheugen (${n})',
			'settings.radio.voiceMessages.labelField' => 'Label',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Label spraakgeheugen ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Leeg',
			'settings.radio.voiceMessages.notMeasured' => 'Onbekende lengte',
			'settings.radio.voiceMessages.playButton' => 'Afspelen',
			'settings.radio.voiceMessages.recordButton' => 'Opnemen',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Bericht #1 herhalen',
			'settings.radio.voiceMessages.repeatOff' => 'Nee',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Na ${n} seconden',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Opmerkingen bij ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Deze geheugens staan in de radio van ${device}. Hun namen en lengtes horen bij dat apparaat.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Opgeslagen in de radio, waar ook de andere clients het zien.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Wacht op de [REC]-indicator op de radio, houd dan de PTT-knop ingedrukt en neem je bericht op. Beëindig het door hier in de app op STOP te drukken voordat je de PTT loslaat, om ongewenste klikken te voorkomen.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Wacht tot de [REC]-indicator minstens vier keer knippert, houd dan de PTT-knop ingedrukt en neem je bericht op. Beëindig het door hier in de app op STOP te drukken voordat je de PTT loslaat, om ongewenste klikken te voorkomen.',
			'settings.radio.voiceMessages.pill' => 'Spraak',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Geheugen ${n} afspelen',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Geheugen ${n} opnemen',
			'settings.radio.voiceMessages.stopRecording' => 'Opname stoppen',
			'settings.radio.voiceMessages.playing' => 'Afspelen…',
			'settings.radio.voiceMessages.recording' => 'Opnemen…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '${label} afspelen',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '${label} opnemen',
			'settings.radio.voiceMessages.doubtful' => 'Heeft de radio het afgespeeld? Hij meldde meteen dat hij inactief was.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Je moet de geheugens op de radio zelf opnemen.',
			'settings.radio.avoidZeroBeat.title' => 'Zero-beat op spots vermijden',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Met een verbonden radio een paar Hz naast een CW-spot afstemmen, zodat niet iedereen die reageert op dezelfde toon roept.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Precies op de gespotte frequentie afstemmen.',
			'settings.radio.zeroBeatRange.title' => 'Zero-beat: vermijdingsbereik',
			'settings.radio.zeroBeatRange.description' => 'Hoe ver naast de gespotte frequentie, aan beide kanten. De afwijking is nooit bijna nul — dat zou weer een zero-beat zijn.',
			'settings.help.title' => 'Hulp & bronnen',
			'settings.help.description' => 'Community en ondersteuning',
			'settings.help.forums' => 'Ham2K-forums',
			'settings.help.forumsDescription' => 'Vind hulp, geef feedback, bespreek ideeën…',
			'settings.help.chat' => 'Ham2K-chat',
			'settings.help.chatDescription' => 'De Discord-server voor onze online community',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Video\'s en livestreams',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Omdat je nooit genoeg foto\'s kunt hebben…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Volg ons voor nieuws en updates',
			'settings.help.contact' => 'Contacteer ons',
			'settings.help.contactDescription' => 'help@ham2k.com — maar probeer eerst de forums of chat!',
			'settings.exports.title' => 'Exports',
			'settings.map.title' => 'Kaarten',
			'settings.map.style.title' => 'Kaartstijl',
			'settings.map.styleOpts.automatic' => 'Automatisch',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacy',
			'settings.privacy.shareAppData.title' => 'Deel app-gebruiksgegevens',
			'settings.privacy.shareAppData.descriptionOn' => 'Help ons de app te verbeteren door gebruiks-, configuratie-, crash- en prestatiegegevens te delen',
			'settings.privacy.shareAppData.descriptionOff' => 'Appgebruiksgegevens privé houden.\nHet Ham2K-team kan crashes of andere problemen niet detecteren.',
			'settings.privacy.shareOpData.title' => 'Deel activatiegegevens',
			'settings.privacy.shareOpData.descriptionOn' => 'Bepaalde activatiegegevens openbaar en met andere gebruikers delen',
			'settings.privacy.shareOpData.descriptionOff' => 'Activatiegegevens privé houden',
			'settings.privacy.privacyPolicy' => 'Privacybeleid',
			'settings.privacy.termsOfService' => 'Algemene Voorwaarden',
			'settings.operatorCall' => 'Roepnaam van de operator',
			'settings.sync.title' => 'Cloud-synchronisatie',
			'settings.sync.moreSettings' => 'Meer synchronisatie-instellingen',
			'settings.sync.enable' => 'Synchronisatie inschakelen',
			'settings.sync.deviceKey' => 'Apparaatsleutel',
			'settings.peers.title' => 'Peer-apparaten',
			'settings.peers.enable' => 'Verbinden met andere apparaten',
			'settings.peers.enableDescription' => 'Activaties, loggen, CAT en GPS delen met andere apparaten via het lokale netwerk',
			'settings.peers.bleEnable' => 'Verbinden via Bluetooth',
			'settings.peers.bleDescription' => 'Bluetooth LE gebruiken om te verbinden, ook zonder lokaal netwerk',
			'settings.peers.thisDevice' => 'Dit apparaat',
			'settings.peers.deviceName' => 'Naam',
			'settings.peers.deviceNameHint' => 'Hoe andere apparaten dit apparaat zien',
			'settings.peers.pairedDevices' => 'Gekoppelde apparaten',
			'settings.peers.noPairedDevices' => 'Nog geen apparaten gekoppeld. Zet dit aan op een ander apparaat op dit netwerk om ze te koppelen.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Kan je gekoppelde apparaten niet lezen: ${error}',
			'settings.peers.nearby' => 'In de buurt',
			'settings.peers.connected' => 'Verbonden',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Verbinden…',
			'settings.peers.syncing' => 'Synchroniseren…',
			'settings.peers.waitingForThem' => 'Wachten op het andere apparaat',
			'settings.peers.notConnected' => 'Niet verbonden',
			'settings.peers.wantsToPair' => 'wil deze activatie delen',
			'settings.peers.allow' => 'Toestaan',
			'settings.peers.link' => 'Koppelen',
			'settings.peers.reject' => 'Weigeren',
			'settings.peers.forget' => 'Vergeten',
			'settings.peers.forgetTitle' => ({required Object name}) => '${name} vergeten?',
			'settings.peers.forgetBody' => 'Het stopt met synchroniseren met dit apparaat. Je kunt het later opnieuw toestaan, en reeds gelogde QSO\'s blijven bewaard.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Koppelen met ${name}',
			'settings.peers.pairBody' => 'Dit apparaat staat op je lokale netwerk en wil verbinden.',
			'settings.peers.pairBodyBle' => 'Dit apparaat is in de buurt en wil verbinden via Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'Apparaat-ID',
			'settings.peers.pairWarning' => 'Koppel alleen met apparaten die je herkent. Elk apparaat op dit netwerk kan een verzoek sturen.',
			'settings.peers.pairWarningBle' => 'Koppel alleen met apparaten die je herkent. Elk apparaat in de buurt kan een verzoek sturen.',
			'settings.peers.problem' => ({required Object error}) => 'Kan het lokale netwerk niet bereiken: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Verbonden met ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Verbinding met ${device} verbroken',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Peer-apparaten: ${connected} van ${linked} verbonden',
			'settings.peers.screenEnable' => 'Schermen en vensters delen',
			'settings.peers.screenDescription' => 'Andere apparaten schermen of vensters van deze computer laten tonen',
			'settings.peers.screenSources' => 'Schermen en vensters',
			'settings.peers.screenRefresh' => 'Lijst verversen',
			'settings.peers.screenUnsupportedPlatform' => 'Dit apparaat kan zijn scherm niet delen. macOS kan dat wel; elk apparaat kan een scherm tonen dat door een ander wordt gedeeld.',
			'settings.peers.screenUnsupportedVersion' => 'Scherm delen vereist macOS 12.3 of later. Dit apparaat kan nog steeds een scherm tonen dat door een ander wordt gedeeld.',
			'settings.peers.screenNeedsPermission' => 'macOS heeft je toestemming nodig om het scherm op te nemen voordat deze app er een kan delen.',
			'settings.peers.screenGrantPermission' => 'Toestemming vragen',
			'settings.peers.screenRelaunchAfterGranting' => 'Sta het toe in Systeeminstellingen onder Privacy en beveiliging → Schermopname, en sluit en heropen daarna deze app — macOS meldt de wijziging pas bij de volgende start van een app.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Scherm delen: ${error}',
			'settings.peers.screenChooseTitle' => 'Kies wat je deelt',
			'settings.peers.screenChooseButton' => 'Kies wat je deelt…',
			'settings.peers.screenTabScreens' => 'Schermen',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Vensters',
			'settings.peers.screenTabEmpty' => 'Niets van dit type gevonden.',
			'settings.peers.screenSharedSummaryNone' => 'Nog niets gekozen.',
			'settings.peers.screenThisDevice' => 'Dit apparaat',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Getoond op ${devices}',
			'settings.peers.screenSharedToNobody' => 'Wordt niet getoond',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Stop met delen van ${name}',
			'settings.developerMode' => 'Ontwikkelaarsmodus',
			'settings.syncPanel.configuration' => 'Synchronisatieconfiguratie',
			'settings.syncPanel.enableTitle' => 'Synchroniseren met Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Je logboek wordt geback-upt en tussen apparaten gesynchroniseerd',
			'settings.syncPanel.disabledDescription' => 'Uit — blijft alleen op dit apparaat',
			'settings.syncPanel.syncing' => 'Synchroniseren',
			'settings.syncPanel.account' => 'Account',
			'settings.syncPanel.refresh' => 'Verversen',
			'settings.syncPanel.switchAccounts' => 'Ander account',
			'settings.syncPanel.switchAccountsDescription' => 'Koppel dit apparaat aan een ander account via een QR-code of e-mail',
			'settings.syncPanel.connectionRequests' => 'Verbindingsverzoeken',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Een apparaat wacht om aan dit account te worden toegevoegd', other: '${n} apparaten wachten om aan dit account te worden toegevoegd', ), 
			'settings.syncPanel.accountEmailTitle' => 'Account-e-mail',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Bevestiging verzonden naar ${email}. Open de link daar om de wijziging af te ronden.',
			'settings.syncPanel.resendConfirmation' => 'Bevestigingsmail opnieuw verzenden',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Wachten op ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Opnieuw verzonden naar ${email}.',
			'settings.syncPanel.deviceLinked' => 'Dat apparaat is nu aan dit account gekoppeld.',
			'settings.syncPanel.checking' => 'Controleren…',
			'settings.syncPanel.notLinked' => 'Nog niet gekoppeld',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Lokale gegevens vervangen?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${n} activatie', other: '${n} activaties', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${n} QSO', other: '${n} QSO\'s', ), 
			'settings.syncPanel.counts' => 'Gesynchroniseerde gegevens',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Dit apparaat: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Wacht op upload: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Dit apparaat: controleren…',
			'settings.syncPanel.countsServerChecking' => 'Server: controleren…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: niet beschikbaar',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Dit maakt een back-up van ${operations} en ${qsos} op dit apparaat en wist ze, en downloadt in plaats daarvan de gegevens van het account. De back-up blijft in de database van dit apparaat.',
			'settings.syncPanel.replace' => 'Vervangen',
			'settings.syncPanel.pendingBannerTitle' => 'Nieuw Ham2K Log Filer-account gedetecteerd',
			'settings.syncPanel.pendingBannerBody' => 'Behoud de bestaande activaties en QSO\'s van dit apparaat en voeg ze samen met het account, of vervang ze door de gegevens van het account (in beide gevallen blijft er een back-up op dit apparaat).',
			'settings.syncPanel.combine' => 'Samenvoegen',
			'settings.syncPanel.authIssueTitle' => 'Synchronisatie kan niet verbinden',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer blijft dit apparaat weigeren. Controleer je roepnaam in de synchronisatie-instellingen.',
			'settings.syncPanel.openSettings' => 'Synchronisatie-instellingen openen',
			'settings.accounts.title' => 'Accounts, diensten & gegevensbronnen',
			'settings.accounts.none' => 'Geen actieve extensies met accounts',
			'settings.accounts.notConfigured' => 'Niet geconfigureerd',
			'settings.accounts.connected' => 'Verbonden',
			'settings.accounts.cancelLogin' => 'Aanmelden annuleren',
			'settings.accounts.openInBrowser' => 'Openen in browser',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Ingelogd als ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Druk op Opslaan om dit account verbonden te houden.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Verbonden met ${label}',
			'settings.accounts.connect' => 'Verbinden',
			'settings.accounts.disconnect' => 'Verbinding verbreken',
			'settings.accounts.connectedAs' => 'Verbonden als',
			'settings.accounts.test' => 'Testen',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Opslaan mislukt: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Inloggen mislukt: ${error}',
			'settings.accounts.lookupFailed' => 'Accounts zijn nu niet beschikbaar — probeer het zo opnieuw',
			'settings.accounts.browserLoginTitle' => 'Rond het inloggen af in je webbrowser',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Als je klaar bent, probeert de browser een link te openen die begint met "${prefix}". Op je computer is waarschijnlijk niets ingesteld om die te openen, dus kopieer die link (uit de adresbalk, of van de foutpagina die de browser toont) en plak hem hier.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger kon je browser niet openen. Kopieer de inloglink hieronder en open hem zelf, kopieer dan de link waarnaar je wordt doorgestuurd (die begint met "${prefix}") en plak die hier.',
			'settings.accounts.copyLoginLink' => 'Inloglink kopiëren',
			'settings.accounts.pastedLinkLabel' => 'Plak de link hier',
			'settings.accounts.finishLogin' => 'Inloggen afronden',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Dat is niet de inloglink — die moet beginnen met "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Die link hoort bij een andere inlogpoging. Sluit deze pagina en verbind opnieuw.',
			'settings.accounts.pastedLinkNoCode' => 'Die link bevat geen inlogcode. Rond eerst het inloggen af en kopieer dan de link waarnaar je wordt doorgestuurd.',
			'settings.accounts.pastedLinkMalformed' => 'Die link lijkt afgekapt. Kopieer hem helemaal en plak hem opnieuw.',
			'settings.accounts.relayLoginWaiting' => 'Wachten tot je het inloggen afrondt — daarna gaat dit automatisch verder.',
			'settings.accounts.loginNoResponse' => 'Dit apparaat heeft nog niets van het inloggen gehoord. Als je al klaar bent in je browser, annuleer en probeer opnieuw te verbinden.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger kon je browser niet automatisch openen. Gebruik de knop hieronder om de inlogpagina zelf te openen.',
			'settings.accounts.relayLoginUnavailable' => 'Kon de synchronisatieserver die nodig is om dit inloggen af te ronden niet bereiken. Controleer je verbinding en probeer het opnieuw.',
			'settings.accounts.loginIncompleteResponse' => 'Die inlogpoging is niet goed afgerond. Probeer opnieuw te verbinden.',
			'settings.accounts.noKeyringTitle' => 'Accountgegevens kunnen niet worden opgeslagen',
			'settings.accounts.noKeyringText' => 'Ham2K Logger kan geen keyring-dienst op deze computer bereiken, dus accountgegevens kunnen niet worden opgeslagen of gelezen — een account verbinden mislukt totdat dit is opgelost. Installeer en start **gnome-keyring**, **KWallet** of **KeePassXC**, of ontgrendel de keyring die je al hebt, en herstart. Loggen, exports en gegevensbestanden werken gewoon; logsynchronisatie blijft zolang uit.',
			'settings.accounts.noKeyringInline' => 'Aanmeldgegevens kunnen niet worden opgeslagen: de keyring van deze computer is onbereikbaar. Installeer en start gnome-keyring, KWallet of KeePassXC, of ontgrendel de keyring die je hebt.',
			'settings.accounts.noSecureStorageInline' => 'Aanmeldgegevens kunnen niet worden opgeslagen: de beveiligde opslag van deze computer is onbereikbaar.',
			'settings.station.title' => 'Stationsconfiguratie & CAT-besturing',
			'settings.station.none' => 'Geen apparatuur geconfigureerd',
			'settings.station.add' => 'Toevoegen',
			'settings.station.addTitle' => 'Apparatuur toevoegen',
			'settings.station.searchHint' => 'Apparatuur zoeken',
			'settings.station.noMatches' => 'Geen apparatuur gevonden',
			'settings.station.detectedEquipment' => 'Gedetecteerde apparatuur',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Kan niet naar radio\'s luisteren: ${error}',
			'settings.station.edit' => 'Apparatuur bewerken',
			'settings.station.name' => 'Naam',
			'settings.station.nameDescription' => 'Hoe je het noemt — "Linker radio". Optioneel.',
			'settings.station.transport' => 'Verbinding',
			'settings.station.host' => 'Adres',
			'settings.station.hostDescription' => 'De hostnaam of het IP-adres van de radio op je netwerk.',
			'settings.station.port' => 'Poort',
			'settings.station.hostRequired' => 'Een adres is verplicht',
			'settings.station.portInvalid' => 'Poort moet tussen 1 en 65535 liggen',
			'settings.station.connect' => 'Verbinden',
			'settings.station.disconnect' => 'Verbinding verbreken',
			'settings.station.remove' => 'Verwijderen',
			'settings.station.removeTitle' => ({required Object name}) => '${name} verwijderen?',
			'settings.station.removeMessage' => 'Dit verwijdert het alleen uit de app. De instellingen van de apparatuur blijven zoals ze zijn.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Onbekend apparatuurtype "${typeKey}"',
			'settings.station.report' => 'Melden',
			'settings.station.reportTitle' => 'Deze radio melden',
			'settings.station.reportIntro' => 'Vertel ons welke radio dit echt is en hoe het ging. Je melding wordt een kaart die het Ham2K-team leest, en wat je schrijft over hoe je het werkend kreeg kan de volgende operator met dezelfde rig helpen.',
			'settings.station.reportManufacturer' => 'Fabrikant',
			'settings.station.reportManufacturerDescription' => 'Wie maakt hem — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Een fabrikant is verplicht',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'Het model, zoals de radio zelf het noemt — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'Een model is verplicht',
			'settings.station.reportOutcome' => 'Hoe ging het?',
			'settings.station.reportOutcomeWorks' => 'Werkte goed',
			'settings.station.reportOutcomeIssues' => 'Werkte, met problemen',
			'settings.station.reportOutcomeFails' => 'Werkte helemaal niet',
			'settings.station.reportOutcomeRequired' => 'Vertel ons hoe het ging',
			'settings.station.reportComments' => 'Opmerkingen',
			'settings.station.reportCommentsPlaceholder' => 'Wat werkte, wat niet, alles wat je verraste.',
			'settings.station.reportHints' => 'Tips voor probleemoplossing',
			'settings.station.reportHintsPlaceholder' => 'Wil je tips voor probleemoplossing voorstellen voor andere gebruikers?',
			'settings.station.reportSend' => 'Melding versturen',
			'settings.station.reportSending' => 'Je melding wordt verstuurd…',
			'settings.station.reportSent' => ({required Object ref}) => 'Bedankt — je melding is geregistreerd als ${ref}.',
			'settings.station.reportSentNoRef' => 'Bedankt — je melding is verstuurd.',
			'settings.station.reportFailed' => ({required Object error}) => 'De melding is niet verstuurd: ${error}',
			'settings.station.troubleshootingNotes' => 'Notities voor probleemoplossing',
			'settings.station.mainVfo' => 'Hoofd-VFO',
			'settings.station.useAsMainVfo' => 'Gebruiken als hoofd-VFO',
			'settings.station.serialPort' => 'Seriële poort',
			'settings.station.serialPortDescription' => 'De poort waarop de CAT-interface van de radio verschijnt.',
			'settings.station.serialPortNone' => 'Geen seriële poorten gevonden',
			'settings.station.serialPortRequired' => 'Kies een seriële poort',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'poort ${n} van ${total}',
			'settings.station.serialPortSuggested' => 'voorgesteld',
			'settings.station.serialPortJustNow' => 'Recent verbonden',
			'settings.station.serialDeviceRequest' => 'USB-apparaat toevoegen…',
			'settings.station.baudRate' => 'Snelheid (baud)',
			'settings.station.baudRateDescription' => 'Moet overeenkomen met het CAT-menu van de radio. Bij een verschil stuurt de radio onzin terug, zonder foutmelding.',
			'settings.station.serialRtsHigh' => 'RTS hoog houden',
			'settings.station.serialRtsHighDescription' => 'Alleen voor een radio die op RTS wacht voordat hij reageert, zoals een Yaesu met CAT RTS aan. Op een Digirig, SignaLink en de meeste zelfgemaakte kabels is RTS de PTT, en hoog houden zet de zender aan.',
			'settings.station.serialDtrHigh' => 'DTR hoog houden',
			'settings.station.serialDtrHighDescription' => 'Alleen voor een CAT-interface die zijn voeding uit DTR haalt, zoals sommige RS-232-kabels voor de FT-817. Op veel kabels keyt DTR de CW of PTT, en hoog houden zet de zender aan.',
			'settings.station.civAddress' => 'CI-V-adres van de radio',
			'settings.station.civAddressDescription' => 'Hexadecimaal, zoals getoond in het CI-V-menu van de radio. De IC-705 wordt geleverd met A4.',
			'settings.station.civAddressInvalid' => 'Een CI-V-adres bestaat uit twee hexcijfers, 01 tot FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Welke slice van de radio deze verbinding uitleest en afstemt.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Kies een van de slices van de radio, A tot en met H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} is niet in gebruik op deze radio — kies een andere slice, of maak hem aan in SmartSDR',
			'settings.station.channelNotInUse' => 'niet in gebruik',
			'settings.station.channelHeldByUnknown' => 'in gebruik door een ander programma',
			'settings.station.flexNoSlices' => 'Deze radio heeft geen slices gemeld — controleer of SmartSDR draait en of deze client zich mag abonneren',
			'settings.station.spectrumUnsupported' => 'Deze radio stuurt geen spectrum via CAT',
			'settings.station.spectrumRequiresBaud' => 'Vereist CAT op 115200 bps',
			'settings.station.spectrumNoRadio' => 'Geen radio verbonden',
			'settings.station.spectrumWaiting' => 'Wachten op het spectrum van de radio…',
			'settings.station.spectrumUnavailable' => 'Spectrumweergave is niet beschikbaar',
			'settings.station.spectrumNoDaxChannel' => 'Elk DAX IQ-kanaal op deze radio is in gebruik',
			'settings.station.spectrumNoPanadapter' => 'Deze slice heeft geen panadapter op de radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'De radio weigerde een DAX IQ-stream (fout ${code})',
			'settings.station.spectrumNoUdp' => 'De spectrumgegevens van de radio kunnen dit apparaat niet bereiken',
			'settings.station.spectrumScopeRefused' => 'De radio weigerde zijn scope-commando\'s',
			'settings.station.spectrumOutOfRange' => 'De scope van de radio staat buiten het bereik dat hij kan tonen',
			'settings.station.n3fjpNoRig' => 'N3FJP heeft geen radio-interface ingesteld, dus dit volgt wat in N3FJP wordt getypt, niet een radio',
			'settings.station.winkeyerKeyPort' => 'Key-uitgang',
			'settings.station.winkeyerKeyPortDescription' => 'Op welke van de twee uitgangen van de keyer je radio is aangesloten.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Poort ${n}',
			'settings.station.winkeyerPtt' => 'PTT van de keyer gebruiken',
			'settings.station.winkeyerPttDescription' => 'Keyt de PTT-lijn op dezelfde aansluiting, voor een versterker of radio die dat nodig heeft. Laat uit voor een radio die via zijn key-aansluiting wordt gekeyd.',
			'settings.station.winkeyerNoAnswer' => 'Geen WinKeyer reageerde op deze poort',
			'settings.station.winkeyerStoppedAnswering' => 'De WinKeyer reageerde niet meer tijdens het verzenden; het bericht is vervallen',
			'settings.station.radioUser' => 'Gebruikersnaam radio',
			'settings.station.radioPass' => 'Wachtwoord radio',
			'settings.station.radioLoginDescription' => 'De login onder Network → Remote van de radio, niet je wifi-wachtwoord.',
			'settings.station.radioUserRequired' => 'De gebruikersnaam voor bediening op afstand van de radio is verplicht',
			'settings.station.connectFailedBusy' => 'Apparaat is in gebruik',
			'settings.station.connectFailedDenied' => 'Toegang geweigerd',
			'settings.station.connectFailedDevice' => 'Apparaat niet gevonden',
			'settings.station.connectFailedLines' => 'RTS/DTR konden niet worden gehouden zoals ingesteld, dus de poort is gesloten. Mogelijk heeft een ander programma hardware-handshaking aan laten staan — koppel de kabel los en weer aan.',
			'settings.station.connectFailedNetwork' => 'Kan de radio niet vinden via het netwerk. Controleer het adres en of hij aan staat en bereikbaar is.',
			'settings.station.connectFailedTimeout' => 'De radio reageerde niet op tijd. Controleer of hij aan staat en bereikbaar is.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Algemeen',
			'settings.station.models.icomGeneric' => 'Icom - Algemeen',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Algemeen',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Algemeen',
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
			'settings.station.models.rigctld' => 'Radio bestuurd via rigctld',
			'settings.station.models.rigctldNodeName' => 'Mijn radio (via rigctld)',
			'settings.station.models.flrig' => 'Radio bestuurd via flrig',
			'settings.station.models.flrigNodeName' => 'Mijn radio (via flrig)',
			'settings.station.models.hrd' => 'Radio bestuurd via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Mijn radio (via HRD)',
			'settings.station.models.n3fjp' => 'Radio bestuurd via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Mijn radio (via N3FJP)',
			'settings.station.models.commander' => 'Radio bestuurd via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Mijn radio (via Commander)',
			'settings.station.models.antenna' => 'Antenne',
			'settings.station.models.key' => 'CW-seinsleutel',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Algemene radio (tijdelijk)',
			'settings.station.models.placeholderRadioNodeName' => 'Mijn radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.transports.network' => 'Netwerk/wifi',
			'settings.station.transports.usbSerial' => 'USB-serieel',
			'settings.station.transports.wifi' => 'Netwerk/wifi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth-serieel',
			'settings.station.transports.placeholder' => 'Tijdelijk',
			'settings.station.troubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.ft891Troubleshooting' => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **CAT RTS moet UIT staan op de radio** (FT-891-menu **05-08**). Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt. Op een Digirig, SignaLink of de meeste zelfgebouwde kabels is diezelfde lijn de PTT, dus hoog zetten zou je zender aanzetten. Op de eigen USB-poort van de radio is **RTS hoog houden** onder Geavanceerde instellingen het alternatief.\n- **Snelheid moet overeenkomen** met de CAT RATE van de radio (menu **05-06**). Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.yaesuBinaryTroubleshooting' => 'Deze radio spreekt het oudere vijf-byte CAT van Yaesu, en reageert helemaal niet als er iets niet klopt. Bijna altijd een van deze:\n\n- **De kabel moet niveaus omzetten.** De CAT-aansluiting achterop is geen RS-232 en geen USB; er is een CT-62 of gelijkwaardige adapter nodig. Een gewone audio- of datakabel werkt niet voor CAT.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio (**#14** op een FT-817, **#19** op een FT-857 of FT-897). Bij een verschil stuurt de radio niets terug, en nooit een foutmelding.\n- **Laat nooit iets RTS of DTR hoog zetten op deze poort.** Op de meeste kabels voor deze radio\'s zijn die lijnen PTT en keying. Een oudere interface die gevoed wordt uit DTR is de uitzondering: zet daarvoor **DTR hoog houden** aan onder Geavanceerde instellingen.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\nDeze driver is geschreven op basis van Yaesu\'s gepubliceerde CAT-overzicht en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.',
			'settings.station.guohetecTroubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.guohetecTroubleshooting' => 'De Q900 heeft twee CAT-protocollen, en deze optie gebruikt het eigen protocol in plaats van de FT-817-imitatie. Kies hier **Guohetec Q900**, geen FT-817 — de imitatie ondersteunt minder commando\'s, en de radio meldt niet welke hij gebruikt.\n\n- **De USB-C-kabel is de CAT-verbinding**, en verbindt ook de geluidskaart. Snelheid maakt daarbij niet uit; de poort negeert wat er is ingesteld.\n- **Laat nooit iets RTS of DTR hoog zetten op deze poort.** Op een seriële kabel zijn die lijnen PTT en keying.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Een radio van de tweede generatie gedraagt zich anders** dan een van de eerste. Houd Menu lang ingedrukt, dan About: HW 2.0 is de tweede generatie.\n\nDeze driver is geschreven op basis van het gepubliceerde protocol van de fabrikant en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.',
			'settings.station.yaesuTroubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.yaesuTroubleshooting' => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt. Op een Digirig, SignaLink of de meeste zelfgebouwde kabels is diezelfde lijn de PTT, dus hoog zetten zou je zender aanzetten. Op de eigen USB-poort van de radio is **RTS hoog houden** onder Geavanceerde instellingen het alternatief. Waar die instelling zit verschilt per model (menu **05-08** op een FT-891).\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Modes volgen de tabel van de FT-891.** De meeste Yaesu\'s komen daarmee overeen, maar een radio die zijn modes anders nummert toont en zet voor die modes de verkeerde. De frequentie blijft correct.',
			'settings.station.yaesuRs232Troubleshooting' => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **De CAT-aansluiting is RS-232.** Er is een USB-naar-serieel-adapter en een rechte DB-9-kabel nodig — een null-modemkabel verwisselt de lijnen, en de radio hoort helemaal niets.\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt, tenzij **RTS hoog houden** aan staat onder Geavanceerde instellingen.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\nDeze optie is geschreven op basis van gepubliceerde CAT-documentatie en is nog niet met een van deze radio\'s getest. Als hij half werkt, is dat het melden waard.',
			'settings.station.yaesuUsbTroubleshooting' => 'De radio ontvangt commando\'s maar reageert niet. Bijna altijd een van deze:\n\n- **Gebruik de eerste van de twee USB-poorten van de radio.** CAT zit normaal op de eerste (de **Enhanced** COM-poort op Windows); de tweede (**Standard**) is voor PTT en keying. De keuzelijst wijst de eerste aan als hij de twee kan onderscheiden.\n- **CAT RTS moet UIT staan op de radio.** Staat het aan, dan wacht de radio op een handshakelijn die de app laag houdt, tenzij **RTS hoog houden** aan staat onder Geavanceerde instellingen.\n- **Snelheid moet overeenkomen** met het CAT RATE-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.',
			'settings.station.k4SerialNotes' => 'Sluit de USB-B (PC)-aansluiting achterop de K4 aan. USB-PC1 en USB-PC2 werken allebei voor CAT; kies een ongebruikte poort en stel de bijbehorende Serial USB-PCn: Baud Rate op de radio gelijk in. HaLo vult 38400 vooraf in; wijzig dat zo nodig. Een andere applicatie moet de andere poort of Ethernet gebruiken.\n\nDeze verbinding bestuurt de radio en zijn keyers; ze stuurt geen audio naar HaLo.',
			'settings.station.k4TcpNotes' => 'Sluit de Ethernet-aansluiting van de K4 aan op je lokale netwerk. Voer de hostnaam of het IP-adres in en CAT-poort 9200. Dit is CAT-besturing, niet de aparte remote-audioverbinding op poort 9204.\n\nHaLo bestuurt de radio en zijn keyers zonder audio of panadaptergegevens te streamen.',
			'settings.station.k4PowerTimeout' => 'Het K4-vermogen is niet gewijzigd omdat de radio zijn uitgangsbereik niet bevestigde. Probeer het opnieuw.',
			'settings.station.k4PowerRange' => 'K4-vermogen moet 0,1–110 W zijn, of 0,0001–0,01 W als de milliwatt-transverteruitgang actief is.',
			'settings.station.elecraftTroubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.elecraftTroubleshooting' => 'Elecraft-rigs spreken Kenwood-CAT, en zowel een KX2 als een KX3 zijn zo gebruikt — VFO in beide richtingen, modewissel en CW zero-beat werken allemaal.\n\nAls de radio niet reageert, bijna altijd een van deze:\n\n- **Snelheid moet overeenkomen** met de snelheid onder **RS232** in het menu van de radio. Ze worden geleverd met 38400. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n\n**Als de frequentie klopt maar de mode niet**, laat het ons weten. De KX2- en KX3-opties lezen de mode uit een positie in het statusantwoord van de radio die we hebben vastgesteld op basis van de rigs die we kennen, en firmware die hem ergens anders zet merken we alleen via een melding.\n\nVan de K3 is nog niets gemeld, dus laat weten wat er gebeurt als je er een gebruikt. Een K4 heeft een eigen optie.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Als de radio verbindt maar geen frequentie toont',
			'settings.station.kenwoodTroubleshooting' => 'Deze driver is getest met de TS-590SG en TS-480 van Kenwood, de QMX en QCX-mini van QRP Labs, en de KX2 en KX3 van Elecraft. De rest van de reeks is geschreven op basis van gepubliceerde CAT-referenties, dus meld wat er gebeurt, hoe dan ook.\n\nAls de radio niet reageert, bijna altijd een van deze:\n\n- **Snelheid moet overeenkomen** met het CAT-menu van de radio. Bij een verschil stuurt de radio onzin of niets terug, en nooit een foutmelding.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.\n- **Sommige rigs hebben CAT ingeschakeld nodig** in het menu voordat ze überhaupt reageren.\n\n**Diverse SDR-front-ends spreken hetzelfde protocol**, dus het is de moeite waard deze optie ook daarvoor te proberen; Elecraft-rigs staan apart, onder Elecraft. Als de frequentie klopt maar de mode fout is of ontbreekt: dat is het enige deel dat binnen de reeks verschilt — de app leidt het af uit de radio en vraagt het anders direct op, dus de mode kan gewoon wat achterlopen.',
			'settings.station.statusConnected' => 'Verbonden',
			'settings.station.statusLost' => 'Verbinding verbroken',
			'settings.station.notConfigured' => 'Niet geconfigureerd',
			'settings.station.currentConfiguration' => 'Huidige configuratie',
			'settings.station.currentTransceiver' => 'Huidige transceiver',
			'settings.station.radioMode' => 'Radiomode',
			'settings.station.keyerNotSupported' => 'Niet ondersteund door huidige radio',
			'settings.station.catControlPreferences' => 'Voorkeuren CAT-besturing',
			'settings.station.chooseTransceiver' => 'Kies transceiver',
			'settings.station.configurationSection' => 'Configuratie',
			'settings.station.noTransceiverSelected' => 'Geen transceiver geselecteerd',
			'settings.station.makeMainVfo' => ({required Object name}) => '${name} gebruiken voor de hoofd-VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, zero: 'Geen transceivers', one: '${count} transceiver', other: '${count} transceivers', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} antenne', other: '${count} antennes', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} ander apparaat', other: '${count} andere apparaten', ), 
			'settings.station.equipmentInventory' => 'Apparatuuroverzicht',
			'settings.station.equipmentInUse' => 'Transceiverbediening',
			'settings.station.noTransceiver' => 'Geen',
			'settings.station.peerRadioNotAvailable' => 'Niet beschikbaar',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Op ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} zit op een ander apparaat',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Deze radio is verbonden met ${device}. De verbinding en instellingen worden op dat apparaat geconfigureerd.',
			'settings.station.antennaInUse' => 'Antenne in gebruik',
			'settings.station.keyInUse' => 'Seinsleutel in gebruik',
			'settings.station.noneSelected' => 'Geen',
			'settings.station.moreSettings' => 'Meer instellingen',
			'settings.station.icomCivTroubleshootingTitle' => 'Als er twee seriële poorten voor dezelfde radio verschijnen',
			'settings.station.icomCivTroubleshooting' => 'Diverse Icom-radio\'s, waaronder de IC-705, tonen **twee** USB-seriële poorten tegelijk (Icom noemt ze Port A en Port B), beide standaard ingesteld op CI-V. Verder kunnen deze app en je besturingssysteem ze niet onderscheiden: dezelfde USB vendor/product-ID verschijnt gewoon twee keer, soms hier gemarkeerd met een achtervoegsel `#2`. **Port A is meestal de juiste** — normaal de eerste die je besturingssysteem of browser toont, en als deze app de twee poorten kan onderscheiden, markeert ze die als voorgesteld. Als er commando\'s uitgaan en de radio nooit reageert, probeer dan de andere poort.',
			'settings.station.civAddressTroubleshootingTitle' => 'Als de radio nooit reageert',
			'settings.station.civAddressTroubleshooting' => '- **Het CI-V-adres moet overeenkomen** met het menu van de radio. Deze optie vult het fabrieksadres van het model vooraf in, maar juist bij een rig op een gedeelde CI-V-bus wordt dat gewijzigd. Een frame naar het verkeerde adres wordt stil genegeerd, wat er precies uitziet als een defecte kabel.\n- **Snelheid moet overeenkomen** met de CI-V BAUD RATE van de radio (via USB: CI-V USB Baud Rate). Stel de radio in op hetzelfde getal als hier, **niet Auto**. Op Auto verbinden sommige radio\'s, waaronder de IC-7300, en reageren ze na een minuut of zo niet meer.\n- **Een andere app houdt mogelijk de poort bezet**: WSJT-X, fldigi en rigctld houden hem allemaal open.',
			'settings.station.ic7300Mk2Note' => '\n- De **IC-7300 MK2** wordt geleverd met adres `B6`, niet de hier ingevulde `94` — kies in plaats daarvan de optie IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- De **IC-705** toont twee USB-seriële poorten, beide vernoemd naar de radio. CI-V zit op de **eerste**, die de keuzelijst aanwijst als hij de twee kan onderscheiden.',
			'settings.station.ic7760PortNote' => '\n- De **IC-7760** spreekt CI-V op **Port A** van de twee USB-seriële poorten die hij toont.',
			'settings.station.x6100PortNote' => '\n- De **X6100** spreekt CI-V op zijn **DEV**-poort — de tweede van de twee seriële poorten die hij toont, en de poort die de keuzelijst aanwijst.',
			'settings.station.rigctldTroubleshootingTitle' => 'Als de app geen verbinding kan maken',
			'settings.station.rigctldTroubleshooting' => 'Dit verbindt met een **rigctld-daemon die je zelf draait**, niet direct met de radio — de backend van Hamlib praat met de radio en ondersteunt honderden modellen.\n\n- **De daemon moet al draaien**, bijv. `rigctld -m 1035 -r /dev/ttyUSB0`. Zoek het modelnummer van je radio op met `rigctl -l`.\n- **Vanaf een andere machine** start je hem met `-T 0.0.0.0`: standaard accepteert rigctld alleen verbindingen van de machine waarop hij draait.\n- **Poort** is 4532, tenzij je de daemon met `-t` hebt gestart.\n- Eenmaal verbonden betekent een ontbrekende frequentie meestal dat de daemon zelf de radio niet bereikt. Test het met `rigctl -m 2 f` op de machine van de daemon.',
			'settings.station.flrigTroubleshootingTitle' => 'Als de app geen verbinding kan maken',
			'settings.station.flrigTroubleshooting' => 'Dit verbindt met een **flrig-programma dat je zelf draait**, niet direct met de radio — flrig praat met de radio en ondersteunt de meeste merken en modellen.\n\n- **flrig moet al draaien**, met de transceiver geconfigureerd en verbonden.\n- **Poort** is 12345, tenzij je dat in de configuratie van flrig hebt gewijzigd (Config → Setup → Server).\n- **Vanaf een andere machine**: zorg dat de server van flrig bereikbaar is. Hij luistert op alle interfaces, maar je firewall is het daar misschien niet mee eens.\n- Eenmaal verbonden betekent een ontbrekende frequentie meestal dat flrig zelf de radio niet bereikt. Controleer of het display van flrig de afstemknop volgt.',
			'settings.station.hrdTroubleshootingTitle' => 'Als de app geen verbinding kan maken',
			'settings.station.hrdTroubleshooting' => 'Dit verbindt met **Rig Control van Ham Radio Deluxe, draaiend op je computer**, niet direct met de radio — HRD praat met de radio.\n\n- **Rig Control moet al draaien** en met de radio verbonden zijn.\n- **De IP-server ervan moet ingeschakeld zijn.** Rig Control praat alleen via die server met andere programma\'s.\n- **Poort** is 7809, tenzij je die in de instellingen van de IP-server hebt gewijzigd.\n- **Vanaf een andere machine**: zorg dat je firewall de verbinding doorlaat.\n\nDeze optie is geschreven op basis van gepubliceerde beschrijvingen van het HRD-protocol en is nog niet met HRD getest. Als hij half werkt, is dat het melden waard.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Als de app geen verbinding kan maken',
			'settings.station.n3fjpTroubleshooting' => 'Dit verbindt met **een N3FJP-logprogramma dat op je computer draait**, niet direct met de radio — N3FJP praat met de radio.\n\n- **De API van het programma moet aan staan**: Settings → Application Program Interface, vink **TCP API Enabled** aan.\n- **Poort** is 1100, tenzij je die daar hebt gewijzigd.\n- **N3FJP moet een radio-interface ingesteld hebben** om de radio te volgen of af te stemmen. Zonder interface meldt het alleen wat in het invoervenster wordt getypt.\n- N3FJP meldt alleen band, mode en frequentie: geen vermogen, geen zendstatus.\n\nDeze optie is geschreven op basis van de gepubliceerde API van N3FJP en is nog niet met N3FJP getest. Als hij half werkt, is dat het melden waard.',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshootingTitle' => 'Als de app geen verbinding kan maken',
			'settings.station.commanderTroubleshooting' => 'Dit verbindt met **DXLab Commander, draaiend op je computer**, niet direct met de radio — Commander praat met de radio.\n\n- **Commander moet al draaien** en met de radio verbonden zijn.\n- **De netwerkdienst moet aan staan**: de knop **Net Serv** in het Radio-paneel van het Configuration-venster van Commander.\n- **Poort** is 52002, de derde poort van het blok dat begint bij de **Base Port** van Net Serv (52000, tenzij je die hebt gewijzigd).\n- **Vanaf een andere machine**: zorg dat je firewall de verbinding doorlaat.\n\nDeze optie is geschreven op basis van de gepubliceerde TCP-berichten van Commander en is nog niet met Commander getest. Als hij half werkt, is dat het melden waard.',
			'settings.station.ic705TroubleshootingTitle' => 'Als de radio nooit reageert',
			'settings.station.ic705Troubleshooting' => 'De radio heeft **één enkele** sessie voor bediening op afstand. Als de login wordt genegeerd, gebruikt bijna altijd iets anders die sessie.\n\n- **Sluit elke andere client.** wfview of RS-BA1 verbonden met dezelfde radio houdt die ene sessie bezet, en de login hier wordt zolang gewoon genegeerd.\n- **Controleer de netwerkinstellingen van de radio.** WLAN moet aan staan, de radio moet op hetzelfde netwerk zitten, en de functie voor bediening op afstand (Network) moet ingeschakeld zijn.\n- **Zet de WLAN van de radio uit en weer aan** als hij vast blijft zitten. Dat ruimt een vastgelopen sessie op de radio betrouwbaar op.\n\nEen **verkeerd wachtwoord wordt expliciet geweigerd**, niet met stilte beantwoord. Als je hier terechtkwam in plaats van bij een melding "geweigerd", is het wachtwoord niet het probleem.',
			'settings.station.statusStale' => 'Reageert niet',
			'settings.station.statusDisconnected' => 'Niet verbonden',
			'settings.station.statusConnecting' => 'Verbinden…',
			'settings.station.statusDisconnecting' => 'Verbinding verbreken…',
			'settings.station.statusError' => 'Verbinding mislukt',
			'settings.station.currentRadioSettings' => 'Huidige radio-instellingen',
			'settings.station.notSupportedByThisRadio' => 'Niet ondersteund door deze radio',
			'settings.station.keyerRowLabel' => 'Keyer',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Spraak',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Spraakkeyer: ${count} geheugens in de radio',
			'settings.station.antennaBands' => 'Banden',
			'settings.station.antennaType' => 'Antennetype',
			'settings.station.antennaTypeRequired' => 'Kies een antennetype',
			'settings.station.antennaTypes.dipole' => 'Dipool',
			'settings.station.antennaTypes.vertical' => 'Verticaal',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Long Wire / EFHW',
			'settings.station.antennaTypes.other' => 'Andere',
			'settings.station.keyType' => 'Type seinsleutel',
			'settings.station.keyTypeRequired' => 'Kies een type seinsleutel',
			'settings.station.keyTypes.straight' => 'Rechte seinsleutel',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mechanisch halfautomatisch)',
			'settings.station.keyTypes.fullyAutomatic' => 'Volautomatische keyer',
			'settings.station.keyTypes.singlePaddle' => 'Enkele paddle',
			'settings.station.keyTypes.dualPaddle' => 'Dubbele paddle',
			'settings.station.keyTypes.computerDriven' => 'Computergestuurd',
			'settings.station.keyTypes.other' => 'Andere',
			'settings.station.softwareIntermediaries' => 'Tussenliggende software',
			'settings.station.otherBrands' => 'Andere merken',
			'settings.station.otherEquipment' => 'Andere apparatuur (antennes, seinsleutels, enz.)',
			'settings.station.newAntenna' => 'Nieuwe antenne',
			'settings.station.newKey' => 'Nieuwe seinsleutel',
			'settings.station.newKeyer' => 'WinKeyer (K1EL of compatibel)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT-keyer in ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Seinsleutel op ${device}',
			'settings.station.cwKeyerArea' => 'Keyergebied',
			'settings.station.trackStationInfo' => 'Stationsinfo per QSO bijhouden',
			'settings.station.includeStationInfoInAdif' => 'Opnemen in ADIF-exports',
			'settings.station.whatToTrack' => 'Wat bijhouden?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Vermogen',
			'settings.station.watts' => 'Watt',
			'settings.station.trackFieldAntenna' => 'Antenne',
			'settings.station.trackFieldKey' => 'CW-seinsleutel',
			'settings.station.placeholderConnectDelay' => 'Verbindingsvertraging (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Hoe lang de gesimuleerde handshake duurt. Leeg of 0 verbindt meteen.',
			'settings.station.placeholderDropAfter' => 'Verbreken na (seconden)',
			'settings.station.placeholderDropAfterDescription' => 'Verbreekt de verbinding vanzelf, om het opnieuw verbinden te testen. Leeg of 0 verbreekt nooit.',
			'settings.station.placeholderFailConnect' => 'Verbinden altijd laten mislukken',
			'settings.station.placeholderConnectFailure' => 'De tijdelijke radio is opgedragen deze verbinding te weigeren',
			'settings.station.placeholderFreq' => 'Frequentie (kHz)',
			'settings.station.placeholderFreqDescription' => 'Waar de tijdelijke radio begint. Daarna meldt hij terug waarop de app hem ook afstemt.',
			'settings.station.placeholderMode' => 'Mode',
			'settings.station.placeholderModeDescription' => 'De mode waarmee de tijdelijke radio begint, bijv. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Vermogen (watt)',
			'settings.station.placeholderPurpose' => 'Gebruik deze radio om bij te houden welke rig je gebruikt, voor je logboek',
			'settings.station.placeholderReplyDelay' => 'Antwoordvertraging (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Hoe lang de tijdelijke radio erover doet om een wijziging terug te melden. Leeg of 0 meldt meteen.',
			'settings.station.cwKeyerField' => 'CAT CW-keyer',
			'settings.station.cwKeyerFieldDescription' => 'Of deze radio CW keyt vanuit tekst via CAT. Uit voor een rig die de app niet kent.',
			'settings.station.voiceMemories' => 'Spraakgeheugens',
			'settings.station.voiceMemoriesDescription' => 'Hoeveel spraakgeheugens de radio via CAT afspeelt. 0 voor geen.',
			'settings.station.voiceMemoriesInvalid' => 'Een geheel getal, 0 of meer',
			'settings.station.yaesuMeterCapture' => 'Meteruitlezingen vastleggen',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Leest tijdens het zenden de vermogensmeter en de hoge-SWR-vlag van de radio uit en schrijft de ruwe waarden naar het log. Bedoeld om de schaal op te bouwen die Yaesu niet publiceert — de waarden worden niet als meters getoond.',
			'settings.station.yaesuMeterCaptureDescription' => 'Leest tijdens het zenden de PO-, SWR- en ALC-meters van de radio uit en schrijft de ruwe waarden naar het log. Bedoeld om de schaal op te bouwen die Yaesu niet publiceert — de waarden worden niet als meters getoond.',
			'settings.station.telemetryInterval' => 'Interval meteruitlezing (ms)',
			'settings.station.telemetryIntervalDescription' => 'Hoe vaak de meters van de radio tijdens het zenden worden uitgelezen. Laat leeg voor het snelste wat deze verbinding aankan, tot 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Een geheel aantal milliseconden, ${min} tot ${max}',
			'settings.station.pollInterval' => 'Pollinginterval in rust (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Hoe vaak de radio om frequentie en mode wordt gevraagd zolang geen van beide verandert. Laat leeg voor ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Een geheel aantal milliseconden, ${min} tot ${max}',
			'settings.station.advancedSettings' => 'Geavanceerde instellingen',
			'settings.station.placeholderSwr' => 'SWR-waarde',
			'settings.station.placeholderSwrDescription' => 'Wat deze radio tijdens het zenden op zijn SWR-meter meldt. Boven 1,8 waarschuwt het paneel.',
			'settings.station.placeholderSwrInvalid' => 'Een getal, 1 of meer',
			'settings.station.keyerNone' => 'Geen',
			'settings.station.cwDialect' => 'CW-keyingdialect',
			'settings.station.cwDialectDescription' => 'Welke vorm van het KY-commando deze radio gebruikt. Geen betekent geen CW-keying via CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, aangevuld tot 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY-tekst)',
			'settings.station.voiceDialect' => 'Spraakkeyerdialect',
			'settings.station.voiceDialectDescription' => 'Hoe deze radio zijn spraakgeheugens via CAT afspeelt. Geen betekent geen spraakgeheugens via CAT. Met een dialect en zonder aantal geldt het standaardaantal van het dialect.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, TS-590-stijl)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB en DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (schakeltikken)',
			'settings.station.placeholderDiagnostic' => 'Gesimuleerd',
			'settings.station.placeholderWholeNumberInvalid' => 'Moet een geheel getal zijn, 0 of meer',
			'settings.station.placeholderFreqInvalid' => 'Moet een frequentie in kHz zijn, groter dan nul',
			'settings.station.placeholderModeInvalid' => 'Moet een modenaam zijn, bijv. USB, CW, FT8',
			'settings.station.switchLayout' => 'Indeling',
			'settings.station.switchLayoutDescription' => 'Op welke kant van de schakelaar je radio\'s zijn aangesloten.',
			'settings.station.switchLayoutRequired' => 'Kies hoe de schakelaar is bedraad',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'De schakelaar weigerde "${command}" (fout ${code})',
			'settings.station.switchBusyTransmitting' => 'Die poort is aan het zenden — antenne niet gewijzigd',
			'settings.station.switchNoAntenna' => 'Geen',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenne op poort ${port}',
			'settings.station.switchAntennaForDescription' => 'Welke van je antennes op deze poort van de schakelaar is aangesloten.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antennes, ${radios} radio\'s',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antennes, 1 radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antenne, ${radios} radio\'s',
			'settings.station.switchCommonPort' => 'Gemeenschappelijk',
			'settings.station.dcnAddress' => 'Apparaatadres',
			'settings.station.dcnAddressDescription' => 'Het adres dat met de DIP-schakelaars van de module is ingesteld. Een coaxrelaismodule komt af fabriek op 2.',
			'settings.station.dcnAddressRequired' => 'Moet een apparaatadres van 1 tot 99 zijn',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Poort ${port}',
			'settings.station.switchPortAutoHint' => 'volgt banddata',
			'settings.station.switchPortTransmittingHint' => 'zendt — kan nu niet wijzigen',
			'settings.station.switchCurrentStateHeader' => 'Huidige status',
			'settings.station.switchCurrentStateDescription' => 'Op welke antenne elke radiopoort nu staat. Wijzigingen werken meteen.',
			'settings.station.switchWiringHeader' => 'Bedrading',
			'settings.station.switchPortInhibitedHint' => 'zenden geblokkeerd',
			'settings.station.configUnreadable' => 'De opgeslagen instellingen van deze radio konden niet worden gelezen. Open de instellingen en voer ze opnieuw in, of verwijder de radio en voeg hem opnieuw toe.',
			'settings.station.autoConnectHeld' => 'HaLo reageerde niet meer de vorige keer dat het met deze radio verbond, dus het heeft deze keer niet vanzelf verbonden. Druk op Verbinden om het opnieuw te proberen.',
			'settings.offlineData.title' => 'Offline gegevens',
			'settings.offlineData.noFiles' => 'Geen gegevensbestanden',
			'settings.offlineData.noFilesDescription' => 'Schakel activiteits- of opzoekextensies in om hier hun offline gegevens te downloaden.',
			'settings.offlineData.refresh' => 'Verversen',
			'settings.offlineData.refreshing' => 'Verversen…',
			'settings.offlineData.updateAll' => 'Alles bijwerken',
			'settings.offlineData.updatingAll' => 'Alle gegevensbestanden bijwerken…',
			'settings.offlineData.neverDownloaded' => 'Nooit gedownload',
			'settings.offlineData.updatedJustNow' => 'Zojuist bijgewerkt',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '${days}d geleden bijgewerkt',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '${days}d ${hours}u geleden bijgewerkt',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '${hours}u geleden bijgewerkt',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '${hours}u ${minutes}m geleden bijgewerkt',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '${minutes}m geleden bijgewerkt',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'De laatste download had maar ${imported} van ${existing} records en is niet gebruikt. Ververs om hem te accepteren.',
			'settings.offlineData.extensionsSection' => 'Extensies',
			'settings.profiles.notSet' => 'Niet ingesteld',
			'settings.profiles.personalInfo' => 'Persoonlijke gegevens',
			'settings.profiles.personalInfoNote' => 'Dit kan worden opgenomen in gegenereerde logboeken als het relevant is voor inzendingen',
			'settings.profiles.name' => 'Naam',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'ARRL Sectie',
			'settings.profiles.racSection' => 'RAC Sectie',
			'settings.profiles.section' => 'Sectie',
			'settings.search.clear' => 'Wissen',
			'settings.search.hint' => 'Instellingen zoeken',
			'settings.developer.developerModeDescription' => 'Ontwikkelaarswaarschuwingen, debuglogs en hulpmiddelen inschakelen.',
			'settings.developer.experiments' => 'Experimenten',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} ingeschakeld', other: '${count} ingeschakeld', ), 
			'settings.developer.patchTrack' => 'Code-push-kanaal',
			'settings.developer.patchTrackDescription' => 'Welk over-the-air code-push-kanaal dit apparaat volgt. Avontuurlijkere kanalen krijgen fixes eerder, minder getest. Code-pushes worden bij de volgende herstart toegepast.',
			'settings.developer.trackStable' => 'Stabiel',
			'settings.developer.trackUnstable' => 'Onstabiel',
			'settings.developer.trackBleeding' => 'Bleeding',
			'settings.developer.checkingTrack' => ({required Object track}) => '"${track}" controleren op een code-push…',
			'settings.developer.patchDownloaded' => 'Code-push gedownload — herstart de app om hem toe te passen.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Geen nieuwe code-push op "${track}".',
			'settings.developer.noPatchInstalled' => 'Geen code-push geïnstalleerd — de release-binary draait.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Code-push #${patch} draait.',
			'settings.developer.deepLinks' => 'Deep links',
			'settings.developer.registerUrlSchemes' => 'URL-schema\'s registreren',
			'settings.developer.registerUrlSchemesDescription' => 'com.ham2k://-links deze kopie van de app laten openen',
			'settings.developer.registerUrlSchemesDone' => 'Deze kopie opent nu com.ham2k://-links',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Kon niet registreren: ${error}',
			'settings.developer.systemInformation' => 'Systeeminformatie',
			'settings.developer.appVersion' => 'App-versie',
			'settings.developer.dataFolder' => 'Gegevensmap',
			'settings.developer.loading' => '(laden…)',
			'settings.developer.panelLoadFailed' => 'Kon dit instellingenpaneel niet laden.',
			'settings.developer.extDevServer' => 'Extensie-devserver',
			'settings.developer.extensionSettings' => 'Extensie-instellingen',
			'settings.developer.extDevServerDescription' => 'Extensies laden van een devserver op je netwerk in plaats van de ingebouwde, en ze herladen als je opslaat.',
			'settings.developer.extDevServerAddress' => 'Serveradres',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Verbinden',
			'settings.developer.extDevServerDisconnect' => 'Verbinding verbreken',
			'settings.developer.extDevServerConnecting' => 'Verbinden…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Levert ${count} extensie: ${keys}', other: 'Levert ${count} extensies: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Niet verbonden',
			'settings.developer.extDevServerReconnect' => 'Opnieuw verbinden bij opstarten',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Laatst herladen: ${key} om ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} extensie bouwt niet', other: '${count} extensies bouwen niet', ), 
			'settings.developer.catalog' => 'Extensiecatalogus',
			'settings.developer.catalogDescription' => 'De catalogus van een andere server lezen — een lokale tijdens het werken aan de catalogus zelf. Leeg betekent catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Catalogusadres',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Kanalen voor catalogus zoeken',
			'settings.developer.catalogSearchStable' => 'Alleen stabiel',
			'settings.developer.catalogSearchUnstable' => 'Onstabiel of beter',
			'settings.developer.catalogSearchBleeding' => 'Bleeding of beter',
			'settings.about.notices' => 'Mededelingen & berichten',
			'settings.about.noticesDescription' => 'Aankondigingen en statusberichten',
			'settings.about.releaseNotes' => 'Release notes',
			'settings.about.copiedVersion' => 'Versiegegevens naar klembord gekopieerd',
			'settings.panels.settings' => 'Applicatievoorkeuren',
			'settings.panels.settingsDescription' => 'Laat de app werken zoals jij wilt',
			'settings.panels.commonSettings' => 'Algemene voorkeuren',
			'settings.panels.syncDescription' => 'Back-up en synchronisatie van je logboeken tussen apparaten',
			'settings.panels.accountsDescription' => 'Inloggegevens van diensten, offline gegevens en meer',
			'settings.panels.extensions' => 'Extensies & functies',
			'settings.panels.extensionsDescription' => 'Activiteiten, contests, dashboardpanelen en meer functies',
			'settings.panels.profilesDescription' => 'Roepnaam van de operator en stationsprofiel',
			'settings.panels.stationProfiles' => 'Stationsprofielen',
			'settings.panels.developerSettings' => 'Ontwikkelaar Instellingen',
			'settings.panels.developerSettingsDescription' => 'Hulpmiddelen voor debuggen en ontwikkeling',
			'settings.panels.about' => 'Over',
			'settings.panels.aboutDescription' => 'Versie, credits en juridische informatie',
			'settings.panels.unavailableTitle' => 'Sommige instellingen zijn niet beschikbaar',
			'settings.panels.unavailableText' => 'De extensieomgeving kon niet starten, dus instellingen van extensies ontbreken.',
			'settings.panels.station' => 'Stationsconfiguratie',
			'settings.panels.stationDescription' => 'CAT-besturing en meer opties',
			'settings.panels.peers' => 'Peer-apparaten',
			'settings.panels.peersDescription' => 'Verbinden met andere apparaten in de buurt',
			'settings.showMoreSettings' => 'Meer instellingen tonen',
			'settings.numberFormat' => 'Getalnotatie',
			'settings.numberFormatOpts.locale' => 'Systeeminstellingen volgen',
			'settings.numberFormatOpts.period' => 'Altijd punt voor decimalen',
			'settings.numberFormatOpts.comma' => 'Altijd komma voor decimalen',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => 'Systeeminstellingen (${separator} voor decimalen)',
			'settings.numberFormatDescription.period' => 'Altijd punt voor decimalen',
			'settings.numberFormatDescription.comma' => 'Altijd komma voor decimalen',
			'settings.numberFormatSeparators.comma' => 'komma',
			'settings.numberFormatSeparators.period' => 'punt',
			'settings.gridPrecision' => 'Gridprecisie',
			'settings.gridPrecisionOpts.six' => '6 tekens (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 tekens (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 tekens',
			'settings.gridPrecisionDescription.eight' => '8 tekens',
			'commands.enableSyncFirst' => 'Schakel eerst synchronisatie in bij Instellingen.',
			'commands.fullResyncStarted' => 'Volledige hersynchronisatie gestart — lokale gegevens zijn eerst geback-upt.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Geen gegevensbestanden gevonden voor "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Herladen mislukt: ${error}',
			'commands.reloadingAll' => 'Alle gegevensbestanden herladen…',
			'commands.reloadingTarget' => ({required Object target}) => 'Gegevensbestanden van ${target} herladen…',
			'commands.unknownExperiment' => ({required Object token}) => 'Onbekend experiment "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} ingeschakeld',
			'commands.experimentDisabled' => ({required Object name}) => '${name} uitgeschakeld',
			'commands.sentryTestSent' => 'Testfoutrapport naar Sentry verzonden',
			'commands.sentryTestLocalOnly' => 'Sentry is uitgeschakeld in deze build — testfout alleen lokaal gelogd',
			'commands.noOperationOpen' => 'Dat commando vereist een geopende activatie',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Weet niet hoe een \'${kind}\' te markeren',
			'commands.operationAlreadyStarted' => 'Deze activatie heeft al een startmarkering',
			'commands.couldNotOpenLocation' => 'Pauze toegevoegd, maar kon het locatiescherm niet openen',
			'commands.noTestOperations' => 'Geen testactivaties om op te ruimen',
			'commands.purgeTestsUnavailable' => 'PURGETESTS moet een bevestigingsvenster tonen, en dat is hier niet beschikbaar',
			'commands.syncAllUnavailable' => 'SYNCALL moet een bevestigingsvenster tonen, en dat is hier niet beschikbaar',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} testactivatie opgeruimd', other: '${count} testactivaties opgeruimd', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '${purged} van ${total} testactivaties opgeruimd — de rest mislukte; probeer PURGETESTS opnieuw',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} test-QSO zonder activatie opgeruimd', other: '${count} test-QSO\'s zonder activatie opgeruimd', ), 
			'commands.purgeTestsContactsFailed' => 'De testactivaties zijn opgeruimd, maar de test-QSO\'s zonder activatie mislukten; probeer PURGETESTS opnieuw',
			'commands.purgeTestsNothingToDo' => 'Er is niets opgeruimd',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '${removed} van ${total} testactivaties verwijderd — de rest mislukte; probeer Bekijken opnieuw',
			'commands.receivedPurgesFailed' => 'Kon die testactivaties niet verwijderen — probeer Bekijken opnieuw',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} testactivatie is op een ander apparaat verwijderd', other: '${count} testactivaties zijn op een ander apparaat verwijderd', ), 
			'commands.receivedPurgesReview' => 'Bekijken',
			'commands.settingOn' => 'Aan',
			'commands.settingOff' => 'Uit',
			'commands.settingEmpty' => '(leeg)',
			'commands.settingSecretSet' => '(ingesteld)',
			'commands.settingSecretUnset' => '(niet ingesteld)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} geselecteerd',
			'commands.settingExpectsOnOff' => 'aan of uit',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'een van: ${choices}',
			'commands.settingExpectsNumber' => 'een getal',
			'commands.settingVanished' => ({required Object label}) => '“${label}” is niet meer beschikbaar',
			'commands.noCwKeyer' => 'Geen verbonden radio kan CW keyen',
			'commands.noKeyer' => 'Geen verbonden radio kan CW keyen of spraakgeheugens afspelen',
			'commands.keyerNeedsOperation' => 'Open een activatie om de CW-keyer te gebruiken',
			'commands.keyerExperimentOff' => 'CW-keying staat uit — zet het aan met EXP KEYER',
			'commands.esmExperimentOff' => 'Enter verstuurt berichten staat uit — zet het aan met EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'CW verzenden: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW-bericht F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW-bericht F${n} is niet verzonden: de extensies zijn nog niet klaar',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” accepteerde die waarde niet',
			'commandDialog.hint' => 'Zoek roepnamen of typ een commando',
			'commandDialog.noResults' => ({required Object text}) => 'Niets gevonden voor “${text}”',
			'commandDialog.sectionCommands' => 'Commando\'s',
			'commandDialog.sectionGoTo' => 'Ga naar',
			'commandDialog.sectionOperations' => 'Activaties',
			'commandDialog.goHome' => 'Start',
			'commandDialog.goSettings' => 'Instellingen',
			'commandDialog.goNewOperation' => 'Nieuwe activatie',
			'commandDialog.runTyped' => ({required Object text}) => '“${text}” uitvoeren',
			'commandDialog.sectionSuggestions' => 'Probeer',
			'commandDialog.lookingUp' => 'Roepnaam opzoeken…',
			'commandDialog.blockedByPane' => 'Kan geen commando\'s gebruiken zolang een paneel of venster open is',
			'expiredBuild.title' => 'Deze build is verlopen',
			'expiredBuild.body' => 'Ga naar ham2k.com en haal een nieuwere versie.',
			'expiredBuild.visit' => 'Naar ham2k.com',
			'expiredBuild.dismiss' => 'Toch doorgaan',
			'staleness.codePushFloorTitle' => 'Er wacht een belangrijke update',
			'staleness.codePushFloorBody' => 'Deze versie bevat een fix die je nog niet hebt.',
			'staleness.restartToApply' => 'Herstart de app om hem toe te passen.',
			'staleness.quitAndReopen' => 'Sluit de app af en open hem opnieuw om hem toe te passen.',
			'staleness.reopenToApply' => 'Sluit de app en open hem opnieuw om hem toe te passen.',
			'staleness.ignoreForNow' => 'Nu negeren',
			'spotting.noQsoYet' => 'Nog geen QSO gelogd om te spotten.',
			'spotting.setFrequencyFirst' => 'Stel eerst een frequentie in.',
			'spotting.nothingToSpot' => 'Niets te spotten — geen extensie biedt hier spotten aan.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} mislukt: ${message}',
			'spotting.unknownError' => 'onbekende fout',
			'spotting.notSent' => 'Spot niet verzonden.',
			'spotting.notRefreshedOffline' => 'Geen verbinding — spots zijn niet ververst',
			'dataFiles.downloading' => 'Downloaden…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Kon ${name} niet downloaden',
			'dataFiles.downloadFailedWebHint' => 'Dit kan een netwerkprobleem zijn, of de host van deze link ondersteunt geen directe downloads vanuit een webbrowser. Probeer de desktop- of mobiele app, of een andere hostinglocatie.',
			'dataFiles.downloadTimedOut' => 'De server deed er te lang over om te reageren. Probeer het later opnieuw.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} reageerde met een fout (HTTP ${status}). Probeer het later opnieuw.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} kon dit bestand niet leveren (HTTP ${status}). Controleer of het adres nog klopt.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Kon ${name} niet verwerken',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'De download had maar ${imported} van de ${existing} records op dit apparaat, dus de weggelaten records zijn behouden. Ververs hem in Instellingen › Offline gegevens om hem toch te accepteren.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} record geïmporteerd voor ${label}.', other: '${count} records geïmporteerd voor ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Gegevens geïmporteerd voor ${label}.',
			'dataFiles.cleanedUpTitle' => 'Extensiegegevens opgeruimd',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Gegevens van ${count} gegevensbestand van uitgeschakelde extensies verwijderd.', other: 'Gegevens van ${count} gegevensbestanden van uitgeschakelde extensies verwijderd.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} records',
			'dataFiles.definitionUnavailable' => 'De bron van het bestand leverde geen definitie — de extensie is mogelijk aan het herstarten of verkeerd geconfigureerd. Probeer het zo opnieuw.',
			'updates.updateAvailable' => 'Update beschikbaar',
			'updates.newVersionAvailable' => ({required Object version}) => 'Er is een nieuwe versie (${version}) beschikbaar.',
			'updates.getIt' => 'Ophalen',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Update klaar',
			'updates.restartToApply' => 'Er is een update gedownload. Herstart om hem toe te passen.',
			'updates.appliesNextLaunch' => 'Er is een update gedownload. Die wordt toegepast als je de app de volgende keer opent.',
			'updates.restartNow' => 'Nu herstarten',
			'updates.reloadToUpdate' => 'Er is een nieuwere versie van deze pagina beschikbaar. Herlaad om hem te krijgen.',
			'updates.reloadNow' => 'Nu herladen',
			'updates.checkForUpdates' => 'Controleer op updates',
			'updates.checkingForUpdates' => 'Controleren op updates…',
			'updates.upToDate' => 'Up-to-date',
			'updates.automaticChecks' => 'Automatisch controleren',
			'updates.automaticChecksDescription' => 'Op de achtergrond naar nieuwe versies zoeken, vanaf de volgende keer dat je de app start',
			'extensionService.runtimeNotReady' => 'Extensieomgeving niet klaar.',
			'extensionService.testFailed' => ({required Object error}) => 'Test mislukt: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Verbonden als ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Ongeldige veldconfiguratie',
			'extensionService.invalidValue' => 'Ongeldige waarde',
			'extensionService.validationError' => ({required Object error}) => 'Validatiefout: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Actie mislukt: ${error}',
			'extensionService.commandFailed' => 'Het commando kon niet worden uitgevoerd',
			'extensionService.reportUnavailable' => 'Meldingen kunnen nu niet worden verstuurd',
			'extensionService.stashUnavailable' => 'Ham2K File Stash is nu niet bereikbaar',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} besteedde te veel tijd in zijn timers. Ze zijn gestopt tot de extensies herstarten.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'De timers van ${name} bleven mislukken. Ze zijn gestopt tot de extensies herstarten.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} bleef hangen in een timer. De timers zijn gestopt tot de extensies herstarten.',
			'operationLocationScreen.title' => 'Activatie locatie',
			'operationLocationScreen.selectedLocation' => 'Geselecteerde locatie',
			'operationLocationScreen.gridSquare' => 'Grid square',
			'operationLocationScreen.gridInvalid' => 'Vereist 4, 6, 8 of 10 tekens, zoals FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Voorgestelde locaties',
			'operationLocationScreen.deviceGps' => 'GPS van apparaat',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS van ${device}',
			'operationLocationScreen.locating' => 'Plaatsen…',
			'operationLocationScreen.gpsUnavailable' => 'Locatie niet beschikbaar',
			'operationLocationScreen.permissionDenied' => 'Locatietoestemming geweigerd',
			'operationLocationScreen.permissionBlocked' => 'Locatietoestemming geblokkeerd',
			'operationLocationScreen.moreDetails' => 'Meer details',
			'operationLocationScreen.stateOrProvince' => 'Staat of Provincie (optioneel)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Activiteitsbediening niet beschikbaar',
			'operationLocationScreen.controlsUnavailableReason' => 'Deze referenties zijn nog bruikbaar; alleen hun activiteiten waren niet bereikbaar.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Opnieuw proberen',
			'operationLocationScreen.county' => 'County (optioneel)',
			'versionLabel.version' => ({required Object version}) => 'Versie ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Nog geen mededelingen',
			'notices.webStorageInMemory' => 'Deze browser kon geen permanente opslag bieden — het logboek staat alleen in het geheugen en gaat VERLOREN als dit tabblad sluit. Gebruik een recente Chrome, Firefox, Safari of Edge.',
			'notices.webStorageUnreliable' => 'Deze browser gebruikt reserve-opslag die niet veilig is met meerdere tabbladen — houd één tabblad open, en laat synchronisatie aan.',
			'notices.logFromNewerBuildTitle' => 'Dit logboek vereist een nieuwere versie',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Je logboek is geschreven door een nieuwere versie van HaLo (opslagversie ${storage}; deze begrijpt ${understood}), dus het kan niet worden geopend en nieuwe QSO\'s worden niet opgeslagen. Installeer de nieuwere versie opnieuw — of, als je deze build bewust draait, laat hem naar een andere gegevensmap wijzen. Het logboek staat in ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Je logboek is geschreven door een nieuwere versie van HaLo (opslagversie ${storage}; deze begrijpt ${understood}), dus het kan niet worden geopend en nieuwe QSO\'s worden niet opgeslagen. Open dit logboek in plaats daarvan met die nieuwere versie.',
			'notices.preferencesRestoredTitle' => 'Instellingen hersteld uit een back-up',
			'notices.preferencesRestored' => 'Het instellingenbestand kon niet worden gelezen, dus HaLo heeft de laatste goede kopie hersteld. Wat je in je vorige sessie hebt gewijzigd, moet je mogelijk opnieuw instellen. Het onleesbare bestand staat ernaast, met de naam shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Instellingen teruggezet',
			'notices.preferencesReset' => 'Het instellingenbestand kon niet worden gelezen en er was geen back-up om op terug te vallen, dus HaLo is gestart met de standaardwaarden. Het onleesbare bestand staat in de gegevensmap van de app, met de naam shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} is niet automatisch verbonden',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo reageerde niet meer de vorige keer dat het met ${name} begon te verbinden, dus deze keer is het overgeslagen om dat niet opnieuw te riskeren. Controleer of de radio aan staat en de kabel is aangesloten, en druk dan in Instellingen op Verbinden.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anoniem account (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (wacht op bevestiging)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (wacht op bevestiging - #${id})',
			'deepLink.needsAnOperation' => 'Start eerst een activatie en stuur dat QSO dan opnieuw',
			'deepLink.waitingInOperation' => 'Dat QSO wacht in de activatie achter dit scherm',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Dit apparaat heeft geen activiteit voor ${refs}, dus die referenties zijn weggelaten',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Kon je activiteiten niet bereiken, dus ${refs} is weggelaten — probeer die link opnieuw',
			'confirmDevice.title' => 'Apparaat bevestigen',
			'confirmDevice.codePrompt' => 'Voer de code in die wordt getoond op het apparaat dat zich bij dit account wil aansluiten.',
			'confirmDevice.code' => 'Code',
			'confirmDevice.lookUp' => 'Opzoeken',
			'confirmDevice.codeNotFound' => 'Geen verzoek gevonden bij die code. Codes verlopen na 10 minuten — vraag het andere apparaat om een nieuwe.',
			'confirmDevice.linkExpired' => 'Die link is verlopen. Laat het andere apparaat een nieuwe QR-code tonen.',
			'confirmDevice.areYouSure' => ({required Object device}) => '${device} aan dit account koppelen?',
			'confirmDevice.unnamedDevice' => 'een naamloos apparaat',
			'confirmDevice.grantWarning' => 'Het kan dan elke activatie en elk QSO in dit account lezen en wijzigen.',
			'confirmDevice.needsSyncTitle' => 'Dit apparaat synchroniseert nog niet',
			'confirmDevice.needsSyncText' => 'Zet synchronisatie met Ham2K Log Filer aan en koppel dit apparaat aan een account voordat het een ander apparaat kan toelaten.',
			'confirmDevice.malformedRequest' => 'De synchronisatieserver stuurde een verzoek dat deze app niet kon lezen. Vraag het andere apparaat het opnieuw te proberen.',
			'confirmDevice.linkIt' => 'Apparaat koppelen',
			'switchAccounts.noAccountDetails' => 'Nog geen accountgegevens',
			'switchAccounts.currentAccount' => 'Huidig account',
			'switchAccounts.otherAccounts' => 'Andere accounts',
			'switchAccounts.linkToAnother' => 'Koppelen aan een ander account',
			'switchAccounts.linkWithSibling' => 'Koppelen met andere Ham2K-app',
			'switchAccounts.linkWithPolo' => 'Koppelen met account in oudere versie',
			'switchAccounts.linkWithSiblingDescription' => 'Je hebt een andere Ham2K-app geïnstalleerd. Koppel met het account dat daar in gebruik is.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Keur het verzoek goed in ${app} en kom dan hier terug.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '${app} opnieuw openen',
			'switchAccounts.siblingNoGrant' => 'Werkte het niet? Open het opnieuw, of ga terug en koppel op een andere manier.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Kon ${app} niet openen.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'De link was verlopen en er staat een nieuwe klaar — open ${app} opnieuw.',
			'switchAccounts.tryAgain' => 'Opnieuw proberen',
			'switchAccounts.linkWithQr' => 'Koppelen met een QR-code',
			'switchAccounts.linkWithQrDescription' => 'Scan hem vanaf een apparaat dat het account al gebruikt',
			'switchAccounts.linkWithEmail' => 'Koppelen met een e-mailadres',
			'switchAccounts.linkWithEmailDescription' => 'Bevestigen met een code of een e-maillink',
			'switchAccounts.enterEmailPrompt' => 'Voer het e-mailadres in van het account dat dit apparaat moet gebruiken.',
			'switchAccounts.emailAddress' => 'E-mailadres',
			'switchAccounts.linkAccount' => 'Account koppelen',
			'switchAccounts.copiedCode' => 'Code naar klembord gekopieerd',
			'switchAccounts.copyCode' => 'Code kopiëren',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Open de Ham2K-app op een apparaat dat al gekoppeld is met ${email} en voer deze code in om het verzoek goed te keuren:',
			'switchAccounts.waitingForConfirmation' => 'Wachten op bevestiging…',
			'switchAccounts.sendEmailInstead' => 'In plaats daarvan een bevestigingsmail sturen',
			'switchAccounts.emailSent' => ({required Object email}) => 'Er is een e-mail verzonden naar ${email}. Open hem en bevestig het verzoek om dit apparaat te koppelen.',
			'switchAccounts.resendEmail' => 'E-mail opnieuw verzenden',
			'switchAccounts.qrPrompt' => 'Scan deze QR-code vanaf een apparaat dat al gekoppeld is aan het gewenste account — bijvoorbeeld met Ham2K Portable Logger op je telefoon.',
			'switchAccounts.serverUnreachable' => 'Kon de synchronisatieserver niet bereiken. Probeer het later opnieuw.',
			'switchAccounts.emailRequired' => 'Voer een e-mailadres in om te koppelen.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Geen account gevonden voor ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'De synchronisatieserver weigerde het verzoek: ${error}',
			'switchAccounts.noLinkCode' => 'De synchronisatieserver gaf geen koppelcode terug. Probeer het later opnieuw.',
			'switchAccounts.noConfirmationCode' => 'De synchronisatieserver stuurde geen bevestigingscode. Probeer het later opnieuw.',
			'switchAccounts.switchNotAccepted' => 'Dat account accepteerde de wissel niet. Probeer het in plaats daarvan te koppelen met een e-mailadres.',
			'switchAccounts.requestFailed' => 'Er ging iets mis in de communicatie met de synchronisatieserver. Probeer het later opnieuw.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} QSO', other: '${count} QSO\'s', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} activatie', other: '${count} activaties', ), 
			'adifImport.title' => 'QSO\'s importeren uit ADIF',
			'adifImport.reading' => ({required Object filename}) => '${filename} lezen…',
			'adifImport.dropHint' => 'Sleep een ADIF-bestand hierheen om te importeren',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} QSO in dit bestand', other: '${formatted} QSO\'s in dit bestand', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} staat al in je logboek', other: '${formatted} staan al in je logboek', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} wordt geïmporteerd', other: '${formatted} worden geïmporteerd', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} nieuw QSO', other: '${formatted} nieuwe QSO\'s', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} wordt samengevoegd met een bestaand QSO', other: '${formatted} worden samengevoegd met bestaande QSO\'s', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} kan niet worden geïmporteerd (geen roepnaam)', other: '${formatted} kunnen niet worden geïmporteerd (geen roepnaam)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} verdient een nadere blik', other: '${formatted} verdienen een nadere blik', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: 'Referenties konden niet worden achterhaald voor ${count} QSO', other: 'Referenties konden niet worden achterhaald voor ${formatted} QSO\'s', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${programs}-referenties zijn mogelijk onvolledig voor ${count} QSO', other: '${programs}-referenties zijn mogelijk onvolledig voor ${formatted} QSO\'s', ), 
			'adifImport.stackingTypesUnknown' => 'Samengevoegde QSO\'s kunnen een referentie verliezen — de activiteiten konden niet zeggen welke typen stapelen. Annuleer en probeer opnieuw om dit te voorkomen.',
			'adifImport.nothingToImport' => 'Niets in dit bestand kan worden geïmporteerd',
			'adifImport.confirm' => 'Importeren',
			'adifImport.importing' => ({required Object filename}) => '${filename} importeren…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} QSO geïmporteerd uit ${filename}', other: '${formatted} QSO\'s geïmporteerd uit ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Kon ${filename} niet importeren: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} lijkt geen ADIF-bestand',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Waarschuwing: deze ADIF bevat QSO\'s van ${calls}, maar ze worden geïmporteerd als ${station} als je doorgaat.',
			'adifImport.stationCallJoin' => ' en ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('nl'))(count, one: '${count} heeft geen datum en kan niet worden geïmporteerd', other: '${formatted} hebben geen datum en kunnen niet worden geïmporteerd', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Dit bestand bevat een activatie van ${refs}.',
			'adifImport.addActivation' => 'Toevoegen aan deze activatie',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Slechts ${written} van ${planned} konden worden toegepast — het logboek veranderde terwijl je besliste.',
			'adifImport.busy' => 'Er loopt al een import. Wacht tot die klaar is voordat je een nieuwe start.',
			'adifImport.oneFileOnly' => 'Sleep één ADIF-bestand tegelijk — de volgorde waarin bestanden worden geïmporteerd bepaalt welke gegevens winnen.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} heeft meer dan ${limit} QSO\'s, het maximum dat een activatie in één keer kan importeren.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: verbonden',
			'offline.noRoute' => 'Helemaal geen netwerkverbinding.',
			'offline.unreachable' => 'Het netwerk werkt, maar geen enkele server reageert — vaak een teken van een inlogpagina die in een browser wacht.',
			'offline.reachable' => 'Alle diensten reageren zoals verwacht.',
			'offline.whatStops' => 'Opzoeken, spots en gegevensbestanden zijn gepauzeerd. Loggen en synchronisatie in de buurt niet.',
			'offline.servicesTitle' => 'Diensten',
			'offline.noServices' => 'Nog geen dienst heeft zich gemeld.',
			'offline.lastSuccess' => ({required Object when}) => 'Reageerde ${when} geleden voor het laatst',
			'offline.neverSucceeded' => 'Heeft nog niet gereageerd',
			'offline.nextAttempt' => ({required Object when}) => 'Volgende poging over ${when}',
			'offline.nextAttemptNow' => 'Volgende poging staat klaar',
			'offline.retry' => 'Nu opnieuw proberen',
			'offline.retrying' => 'Proberen…',
			'offline.retryReached' => 'Weer online.',
			'offline.retryUnreachable' => 'Nog steeds geen reactie.',
			'offline.retryNotAttempted' => 'Nu niets te versturen.',
			'offline.retryThrottled' => 'Net geprobeerd — even geduld.',
			'offline.retryDisabled' => 'Synchronisatie staat uit, dus er is niets om mee te testen.',
			'offline.syncService' => 'Ham2K LoFi-synchronisatie',
			'offline.retryInFlight' => 'Al bezig — even geduld.',
			'exportSettings.defaultsDescription' => 'Basisinstellingen voor alle exports, met aparte sjablonen voor bestandsnaam en titel voor referentieactiviteiten en andere activiteiten. Elk exporttype kan eigen standaardwaarden of aangepaste instellingen hebben.',
			'exportSettings.referenceActivities' => 'Referentieactiviteiten',
			'exportSettings.otherActivities' => 'Andere activiteiten',
			'exportSettings.adifFields' => 'ADIF-velden',
			'exportSettings.loadFailed' => 'Exportinstellingen konden niet worden geladen.',
			'exportSettings.retry' => 'Opnieuw proberen',
			'exportSettings.compactFileNamesDescriptionOn' => 'Compacte bestandsnamen, zoals N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Beschrijvende bestandsnamen, zoals 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Namen, adressen, e-mails, notities en precieze locaties worden in ADIF-bestanden opgenomen.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Namen, adressen, e-mails en notities worden weggelaten; locaties beperkt tot grids van zes tekens.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Informatie van roepnaam-opzoekdiensten wordt opgenomen.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Informatie van roepnaam-opzoekdiensten wordt weggelaten; handmatig ingevoerde waarden blijven behouden.',
			'exportSettings.customTemplatesDescriptionOn' => 'Je aangepaste sjablonen zijn actief en kunnen hieronder worden bewerkt.',
			'exportSettings.customTemplatesDescriptionOff' => 'Standaardsjablonen zijn actief. Je aangepaste sjablonen worden bewaard voor later.',
			'exportSettings.type' => 'Exporttype',
			'exportSettings.defaults' => 'Standaardwaarden',
			'exportSettings.includeLookupData' => 'Opzoekgegevens opnemen',
			'exportSettings.customTemplates' => 'Aangepaste sjablonen',
			'exportSettings.filenameTemplate' => 'Bestandsnaam sjabloon',
			'exportSettings.compactFilenameTemplate' => 'Sjabloon compacte bestandsnaam',
			'exportSettings.titleTemplate' => 'Titel sjabloon',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO Notities',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO Opmerkingen',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL Bericht',
			'exportSettings.shared' => 'Instellingen gelden voor elke extensie die dit exporttype gebruikt.',
			'exportSettings.defaultTemplates' => 'Zet Aangepaste sjablonen aan om de sjablonen van dit type te bewerken.',
			_ => null,
		} ?? switch (path) {
			'templateEditor.previewLabel' => 'Voorbeeld:',
			'templateEditor.reset' => 'Resetten',
			'templateEditor.docs' => 'Sjabloondocumentatie',
			'templateEditor.preview' => 'Voorbeeldweergave',
			'templateEditor.reference' => 'Sjabloonreferentie',
			'templateEditor.attributes' => 'Beschikbare attributen',
			'templateEditor.filters' => 'Filters',
			'templateEditor.flowControl' => 'Programmaverloop',
			'templateEditor.unavailable' => 'Voorbeeld is niet beschikbaar tot de extensies klaar zijn.',
			'templateEditor.empty' => '(lege uitvoer)',
			_ => null,
		};
	}
}
