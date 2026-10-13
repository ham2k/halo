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
class TranslationsDe extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsDe({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.de,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <de>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsDe _root = this; // ignore: unused_field

	@override 
	TranslationsDe $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsDe(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$de common = _Translations$common$de._(_root);
	@override late final _Translations$onboarding$de onboarding = _Translations$onboarding$de._(_root);
	@override late final _Translations$startScreen$de startScreen = _Translations$startScreen$de._(_root);
	@override late final _Translations$testerOverlay$de testerOverlay = _Translations$testerOverlay$de._(_root);
	@override late final _Translations$extensionsPanel$de extensionsPanel = _Translations$extensionsPanel$de._(_root);
	@override late final _Translations$home$de home = _Translations$home$de._(_root);
	@override late final _Translations$chase$de chase = _Translations$chase$de._(_root);
	@override late final _Translations$dialogs$de dialogs = _Translations$dialogs$de._(_root);
	@override late final _Translations$operation$de operation = _Translations$operation$de._(_root);
	@override late final _Translations$map$de map = _Translations$map$de._(_root);
	@override late final _Translations$mapsView$de mapsView = _Translations$mapsView$de._(_root);
	@override late final _Translations$activitiesView$de activitiesView = _Translations$activitiesView$de._(_root);
	@override late final _Translations$loggingControls$de loggingControls = _Translations$loggingControls$de._(_root);
	@override late final _Translations$formChrome$de formChrome = _Translations$formChrome$de._(_root);
	@override late final _Translations$qsoEditForm$de qsoEditForm = _Translations$qsoEditForm$de._(_root);
	@override late final _Translations$qsoList$de qsoList = _Translations$qsoList$de._(_root);
	@override late final _Translations$loggingPanel$de loggingPanel = _Translations$loggingPanel$de._(_root);
	@override late final _Translations$callInfo$de callInfo = _Translations$callInfo$de._(_root);
	@override late final _Translations$settings$de settings = _Translations$settings$de._(_root);
	@override late final _Translations$commands$de commands = _Translations$commands$de._(_root);
	@override late final _Translations$commandDialog$de commandDialog = _Translations$commandDialog$de._(_root);
	@override late final _Translations$expiredBuild$de expiredBuild = _Translations$expiredBuild$de._(_root);
	@override late final _Translations$staleness$de staleness = _Translations$staleness$de._(_root);
	@override late final _Translations$spotting$de spotting = _Translations$spotting$de._(_root);
	@override late final _Translations$dataFiles$de dataFiles = _Translations$dataFiles$de._(_root);
	@override late final _Translations$updates$de updates = _Translations$updates$de._(_root);
	@override late final _Translations$extensionService$de extensionService = _Translations$extensionService$de._(_root);
	@override late final _Translations$operationLocationScreen$de operationLocationScreen = _Translations$operationLocationScreen$de._(_root);
	@override late final _Translations$versionLabel$de versionLabel = _Translations$versionLabel$de._(_root);
	@override late final _Translations$notices$de notices = _Translations$notices$de._(_root);
	@override late final _Translations$syncAccount$de syncAccount = _Translations$syncAccount$de._(_root);
	@override late final _Translations$deepLink$de deepLink = _Translations$deepLink$de._(_root);
	@override late final _Translations$confirmDevice$de confirmDevice = _Translations$confirmDevice$de._(_root);
	@override late final _Translations$switchAccounts$de switchAccounts = _Translations$switchAccounts$de._(_root);
	@override late final _Translations$adifImport$de adifImport = _Translations$adifImport$de._(_root);
	@override late final _Translations$offline$de offline = _Translations$offline$de._(_root);
	@override late final _Translations$exportSettings$de exportSettings = _Translations$exportSettings$de._(_root);
	@override late final _Translations$templateEditor$de templateEditor = _Translations$templateEditor$de._(_root);
}

// Path: common
class _Translations$common$de extends Translations$common$en {
	_Translations$common$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get save => 'Speichern';
	@override String get ok => 'OK';
	@override String get cancel => 'Abbrechen';
	@override String get delete => 'Löschen';
	@override String get create => 'Erstellen';
	@override String get error => 'Fehler';
	@override String get close => 'Schließen';
	@override String get done => 'Fertig';
	@override String get callsign => 'Rufzeichen';
	@override String get clear => 'Leeren';
	@override String get dismiss => 'Ausblenden';
	@override String get expand => 'Ausklappen';
	@override String get collapse => 'Einklappen';
}

// Path: onboarding
class _Translations$onboarding$de extends Translations$onboarding$en {
	_Translations$onboarding$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Willkommen beim Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Willkommen beim Ham2K Power Logger!';
	@override String get welcomeBody => 'Wir haben ein paar Fragen, damit die App besser zu dir passt.';
	@override String get skip => 'Überspringen';
	@override String get kContinue => 'Weiter';
	@override String get back => 'Zurück';
	@override String get next => 'Weiter';
	@override String get done => 'Fertig';
	@override String get callsignTitle => 'Wie lautet dein Rufzeichen?';
	@override String get callsignBody => 'Diese App ist nur mit einer Amateurfunklizenz wirklich nützlich';
	@override String get callsignLabel => 'Rufzeichen des Betreibers';
	@override String get alreadyHaveAccount => 'Du hast schon ein Konto?';
	@override String get foundSiblingTitle => 'Bestehendes Konto verknüpfen?';
	@override String foundSiblingBody({required Object app}) => 'Wir haben ${app} auf diesem Gerät gefunden. Verknüpfe diese App mit demselben Konto, dann werden dein Rufzeichen und deine Logs übernommen.';
	@override String get foundPoloBody => 'Wir haben eine ältere Version des Ham2K Portable Logger auf diesem Gerät gefunden. Verknüpfe diese App mit demselben Konto, dann werden dein Rufzeichen und deine Logs übernommen.';
	@override String get foundSiblingsBody => 'Wir haben andere Ham2K-Apps auf diesem Gerät gefunden. Verknüpfe diese App mit einem ihrer Konten, dann werden dein Rufzeichen und deine Logs übernommen.';
	@override String linkWithApp({required Object app}) => 'Mit ${app} verknüpfen';
	@override String get linkWithPolo => 'Mit Konto der älteren Version verknüpfen';
	@override String get setUpFresh => 'Neu einrichten';
	@override String get activitiesTitle => 'Lieblingsaktivitäten';
	@override String get activitiesBody => 'Interessierst du dich für eines dieser beliebten Aktivierungsprogramme?';
	@override String get activitiesFooter => '(Weitere Optionen findest du in den Einstellungen)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Daten & Datenschutz';
	@override String get consentUsageBody => 'Um die App zu verbessern, würden wir gerne Leistungs-, Absturz- und Nutzungsdaten erfassen.';
	@override String get consentUsageLabel => 'App-Nutzungsdaten teilen';
	@override String get consentOperationBody => 'Einige Funktionen können deine Betriebsdaten mit anderen Nutzern teilen. Du kannst das jederzeit abschalten.';
	@override String get consentOperationLabel => 'Betriebsdaten teilen';
	@override String get finishingSetup => 'Einrichtung wird abgeschlossen — Referenzdaten werden heruntergeladen…';
}

// Path: startScreen
class _Translations$startScreen$de extends Translations$startScreen$en {
	_Translations$startScreen$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get credits => 'von KI2D und Freunden';
}

// Path: testerOverlay
class _Translations$testerOverlay$de extends Translations$testerOverlay$en {
	_Translations$testerOverlay$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get tape => 'ACHTUNG: BAUSTELLE';
	@override String get warningTitle => 'Diese App ist noch in Arbeit';
	@override String get warningBody => 'Die meisten Funktionen haben unebene Oberflächen und überall lauern Stolperfallen. Bitte prüfe regelmäßig auf Updates.';
	@override String whatsNew({required Object build}) => 'Neu in Build ${build}';
	@override String get thanks => 'Danke, dass du dein Log riskierst, um uns zu helfen, diese App besser zu machen!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$de extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Aktivitäten';
	@override String get categoryContest => 'Contests';
	@override String get categoryLookup => 'Rufzeichenabfragen';
	@override String get categorySpots => 'Spot-Quellen';
	@override String get categoryDashboard => 'Dashboard-Panels';
	@override String get categoryOther => 'Andere Erweiterungen';
	@override String get searchHint => 'Erweiterungen durchsuchen';
	@override String get applying => 'Änderungen an Erweiterungen werden aktiviert, dies kann einen Moment dauern…';
	@override String get noMatches => 'Keine Erweiterung passt zu deiner Suche';
	@override String get installFromFile => 'Aus Datei installieren…';
	@override String installVersion({required Object version}) => 'Version ${version}';
	@override String get canReach => 'Diese Erweiterung kann Folgendes kontaktieren';
	@override String canHoldConnection({required Object host}) => '${host}, über eine Live-Verbindung';
	@override String get canHoldLocalConnection => 'Geräte in deinem lokalen Netzwerk, über eine Live-Verbindung';
	@override String get canUseLocation => 'Deinen Standort';
	@override String get canReadRadio => 'Dein Funkgerät, um Frequenz und Modus zu lesen';
	@override String get canControlRadio => 'Dein Funkgerät, um es zu steuern und damit zu senden — Abstimmung, Leistung, CW, Sprachspeicher und PTT';
	@override String get canSetUserAgent => 'Sich gegenüber Servern unter eigenem Namen ausweisen';
	@override String get noCapabilities => 'Sie benötigt nichts außerhalb der App.';
	@override String get sandboxNote => 'Erweiterungen laufen in einer Sandbox: kein Zugriff auf deine Dateien und kein Netzwerk außer dem hier Aufgeführten.';
	@override String get installAction => 'Installieren';
	@override String get updateAction => 'Aktualisieren';
	@override String get installFailed => 'Diese Erweiterung konnte nicht installiert werden';
	@override String get installedBadge => 'Installiert';
	@override String get uninstallAction => 'Entfernen';
	@override String uninstallTitle({required Object name}) => '${name} entfernen?';
	@override String get uninstallBody => 'Diese Erweiterung und ihre Einstellungen werden entfernt. Deine Logs bleiben unverändert.';
	@override String installedMessage({required Object name}) => '${name} installiert';
	@override String get installDownloading => 'Lade herunter…';
	@override String get installWaiting => 'Warte auf Installation…';
	@override String get installInstalling => 'Installiere…';
	@override String get installAwaitingApproval => 'Warte auf deine Zustimmung…';
	@override String installAlreadyRunning({required Object name}) => '${name} wird bereits installiert.';
	@override String updatedTo({required Object version}) => 'Aktualisiert auf ${version}';
	@override String installIncomplete({required Object name}) => 'Die Installation von ${name} wurde nicht abgeschlossen. Sie muss eventuell wiederholt werden.';
	@override String uninstallFailed({required Object name}) => '${name} konnte nicht entfernt werden';
	@override String installedFrom({required Object source}) => 'Heruntergeladen von ${source}';
	@override String get dropHint => 'Lege eine .h2kext-Erweiterung hier ab, um sie zu installieren';
	@override String get dropOneOnly => 'Lege immer nur eine Erweiterung ab.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} lieferte ${status} für diese Erweiterung.';
	@override String get downloadTooLarge => 'Dieser Download ist viel zu groß für eine Erweiterung.';
	@override String get downloadNotSecure => 'Dieser Download wurde an eine unsichere Adresse umgeleitet.';
	@override String get catalogSection => 'Katalog';
	@override String get catalogLoading => 'Katalog wird geladen…';
	@override String get catalogUnreachable => 'Katalog nicht erreichbar';
	@override String get builtIn => 'Integriert';
	@override String get updateAvailableBadge => 'Update verfügbar';
	@override String get updatesAvailableTitle => 'Erweiterungs-Updates';
	@override String updateAvailableFor({required Object name}) => 'Für ${name} ist ein Update verfügbar.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} und ${count} weitere müssen aktualisiert werden.';
	@override String updatesAvailableFor({required Object names}) => '${names} müssen aktualisiert werden.';
	@override String get pendingUpdatesSection => 'Ausstehende Updates';
	@override String get updateAllAction => 'Alle aktualisieren';
	@override String get updatesUnderWay => 'Diese Updates laufen bereits.';
	@override String get updatesNothingLeft => 'Deine Erweiterungen sind auf dem neuesten Stand.';
	@override String get updatesNoticeAction => 'Mehr Infos';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Erweiterung aktualisieren?',
		other: '${count} Erweiterungen aktualisieren?',
	);
	@override String get upgradeDoneTitle => 'Deine Erweiterungen sind bereit';
	@override String get upgradeDoneBody => 'Sie kommen jetzt aus dem Ham2K-Erweiterungskatalog und können daher aktualisiert werden, ohne auf eine neue Version der App zu warten.';
	@override String upgradeDoneUnserved({required Object names}) => 'Nicht umgestellt: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Startet nicht: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Sie sind weiterhin installiert und unter Einstellungen › Erweiterungen markiert — ein Update dort bringt sie zurück.';
	@override String get upgradeDoneUnservedHint => 'Der Katalog hat keinen direkten Ersatz dafür, such dort nach Erweiterungen, die abdecken, was du genutzt hast.';
	@override String get retiredQp => 'QSO-Parties';
	@override String get retiredStateparks => 'State-Parks-Events';
	@override String upgradeDoneMissing({required Object count}) => '${count} deiner Erweiterungen sind noch nicht angekommen. Sie werden heruntergeladen, sobald der Erweiterungskatalog das nächste Mal erreichbar ist.';
	@override String get runtimeDeadBody => 'Deine Erweiterungen starten nicht. Ein Neustart der App sollte sie zurückbringen.';
	@override String get refusedTitle => 'Einige Erweiterungen starten nicht';
	@override String get upgradeBusyTitle => 'Einrichtung läuft noch';
	@override String get upgradeRuntimeDeadTitle => 'Deine Erweiterungen laufen nicht';
	@override String get restoreTitle => 'Einige deiner Erweiterungen fehlen';
	@override String get restoreBody => 'Diese von dir installierten Erweiterungen sind nicht auf diesem Gerät. Wir können sie erneut aus dem Ham2K-Erweiterungskatalog herunterladen:';
	@override String get restoreFromFile => 'Aus einer Datei installiert. Installiere sie erneut aus ihren Dateien oder vergiss sie:';
	@override String get restoreOtherCatalog => 'Aus einem anderen Erweiterungskatalog installiert, daher hier nicht verfügbar:';
	@override String get restoreForget => 'Vergessen';
	@override String get restoreInstall => 'Installieren';
	@override String get restoreLater => 'Später';
	@override String get restoreInstalling => 'Deine Erweiterungen werden installiert…';
	@override String get restoreDoneTitle => 'Deine Erweiterungen sind zurück';
	@override String restoreDoneBody({required Object names}) => 'Erneut installiert: ${names}.';
	@override String get restorePartialTitle => 'Einige Erweiterungen konnten nicht installiert werden';
	@override String restoreFailed({required Object names}) => 'Nicht installiert: ${names}. Wir bieten sie beim nächsten Öffnen der App erneut an.';
	@override String get restoreBusyBody => 'Die App richtet deine Erweiterungen noch ein. Wir bieten sie beim nächsten Öffnen der App erneut an.';
	@override String get restoreRuntimeDeadBody => 'Wir haben sie erneut installiert, aber deine Erweiterungen starten nicht. Ein Neustart der App sollte sie zurückbringen.';
	@override String revokedTitle({required Object name}) => '${name} wurde zurückgezogen';
	@override String get revokedBody => 'Der Katalog hat diese Version zurückgezogen, daher wurde sie deaktiviert.';
	@override String get downloadHashMismatch => 'Dieser Download ist nicht die Erweiterung, die der Katalog beschreibt.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Der Katalog hat keine Version ${version} von ${key}.';
	@override String get catalogLinkUnknown => 'Dieser Katalog-Link nennt keine Erweiterungsversion.';
	@override String catalogNoRelease({required Object key}) => 'Der Katalog hat kein Release von ${key} in diesem Zweig.';
	@override String get installFromLink => 'Über Link installieren';
	@override String get unstableReleaseWarning => 'Dies ist ein instabiles Release, das der Herausgeber noch nicht als fertig bezeichnet. Es kann sich fehlerhaft verhalten und erhält weiterhin instabile Updates.';
	@override String get bleedingReleaseWarning => 'Dies ist ein experimentelles Release: in Arbeit, kann fehlschlagen oder seine Einstellungen verlieren. Es erhält weiterhin experimentelle Updates.';
	@override String get channelUnstable => 'Instabil';
	@override String get channelBleeding => 'Experimentell';
	@override String get followsUnstable => 'Erhält instabile und stabile Releases';
	@override String get followsBleeding => 'Erhält experimentelle, instabile und stabile Releases';
	@override String get followStableAction => 'Nur stabile Releases verwenden';
	@override String get revokedBadge => 'Zurückgezogen';
	@override String get refusedBadge => 'Nicht geladen';
	@override String get downloadNotHttps => 'Dieser Download erfolgt nicht über eine sichere Verbindung.';
	@override String downloadUnreachable({required Object source}) => '${source} war für diese Erweiterung nicht erreichbar.';
	@override String get detailsAction => 'Details';
	@override String get installedFromFile => 'Aus einer Datei installiert';
	@override String get detailsWhatItDoes => 'Bietet Unterstützung für';
	@override String get installedPreloaded => 'Vorinstalliert';
	@override String get hookAccount => 'Konto-Anmeldung';
	@override String get hookCallNotes => 'Rufzeichennotizen';
	@override String get hookDataFile => 'Offline-Daten';
	@override String get hookExport => 'Export';
	@override String get hookLookup => 'Rufzeichenabfragen';
	@override String get hookScoring => 'Punktewertung';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => '${program} jagen';
	@override String hookActivating({required Object program}) => '${program} aktivieren';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '… und ${count} weitere Erweiterung',
		other: '… und ${count} weitere Erweiterungen',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Erweiterung verfügbar',
		other: '${count} Erweiterungen verfügbar',
	);
}

// Path: home
class _Translations$home$de extends Translations$home$en {
	_Translations$home$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portable Logger';
	@override String get newOperation => 'Neuer Betrieb';
	@override String get stationCallsign => 'Stationsrufzeichen';
	@override String get titleOptional => 'Titel (optional)';
	@override String get emptyList => 'Noch kein Betrieb. Erstelle einen, um mit dem Loggen zu beginnen.';
	@override String get quickLookup => 'Schnellabfrage';
	@override late final _Translations$home$nav$de nav = _Translations$home$nav$de._(_root);
	@override late final _Translations$home$panels$de panels = _Translations$home$panels$de._(_root);
	@override String get toggleNav => 'Navigationsbeschriftungen ein- oder ausblenden';
	@override late final _Translations$home$logs$de logs = _Translations$home$logs$de._(_root);
}

// Path: chase
class _Translations$chase$de extends Translations$chase$en {
	_Translations$chase$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'jagt';
	@override String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} & mehr';
	@override late final _Translations$chase$station$de station = _Translations$chase$station$de._(_root);
	@override late final _Translations$chase$periodInline$de periodInline = _Translations$chase$periodInline$de._(_root);
	@override late final _Translations$chase$periodStats$de periodStats = _Translations$chase$periodStats$de._(_root);
	@override late final _Translations$chase$period$de period = _Translations$chase$period$de._(_root);
	@override late final _Translations$chase$goals$de goals = _Translations$chase$goals$de._(_root);
	@override late final _Translations$chase$panels$de panels = _Translations$chase$panels$de._(_root);
}

// Path: dialogs
class _Translations$dialogs$de extends Translations$dialogs$en {
	_Translations$dialogs$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Betriebs-Details';
	@override String get activities => 'Aktivitäten';
	@override String get stationCallsign => 'Stationsrufzeichen';
	@override String get multiStationIdentifier => 'Kennung für Mehrfachstation (nur Zahlen)';
	@override String get notes => 'Notizen';
	@override String get deleteOperationTitle => 'Betrieb löschen';
	@override String get purgeTestsTitle => 'Testbetriebe endgültig löschen';
	@override String get purgeTestsBody => 'Dies löscht diese Testbetriebe und ihre QSOs dauerhaft. Das kann nicht rückgängig gemacht werden.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Dazu ${count} Testkontakt, der zu keinem Betrieb gehört.',
		other: 'Dazu ${count} Testkontakte, die zu keinem Betrieb gehören.',
	);
	@override String get purgeTestsAction => 'Endgültig löschen';
	@override String get syncAllTitle => 'Log dieses Geräts ersetzen?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL sichert und entfernt ${qsos} von diesem Gerät und lädt dann das Log des Kontos erneut vom Server herunter. Die Sicherung bleibt in der Datenbank dieses Geräts.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${n} QSO wurde noch nicht synchronisiert — der Server hat es nie erhalten, und es kommt NICHT zurück.',
		other: '${n} QSOs wurden noch nicht synchronisiert — der Server hat sie nie erhalten, und sie kommen NICHT zurück.',
	);
	@override String get syncAllAction => 'Löschen und neu synchronisieren';
	@override String get receivedPurgesTitle => 'Testbetriebe anderswo entfernt';
	@override String get receivedPurgesBody => 'Diese wurden auf einem anderen Gerät als Testbetriebe gelöscht. Auch hier entfernen? Das löscht sie und ihre QSOs dauerhaft und kann nicht rückgängig gemacht werden.';
	@override String get receivedPurgesAction => 'Entfernen';
	@override late final _Translations$dialogs$callChange$de callChange = _Translations$dialogs$callChange$de._(_root);
}

// Path: operation
class _Translations$operation$de extends Translations$operation$en {
	_Translations$operation$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Dieser Betrieb ist gelöscht. Stelle ihn wieder her, um zu loggen oder Änderungen vorzunehmen.';
	@override late final _Translations$operation$tabs$de tabs = _Translations$operation$tabs$de._(_root);
	@override late final _Translations$operation$positions$de positions = _Translations$operation$positions$de._(_root);
	@override String get stationCallsignNone => 'Kein Stationsrufzeichen';
	@override String get titleNone => 'Kein Titel';
	@override String get deleteOperation => 'Betrieb löschen';
	@override String get loggingControlsStale => 'Aktivitätsfelder sind evtl. veraltet — öffne den Betrieb erneut, um sie zu aktualisieren';
	@override String get locationNone => 'Nicht festgelegt';
	@override String get generalOperation => 'Allgemeiner Betrieb';
	@override String titleFor({required Object value}) => 'für ${value}';
	@override String titleAt({required Object value}) => 'bei ${value}';
	@override String segmentNow({required Object description}) => 'Jetzt ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$de menu = _Translations$operation$menu$de._(_root);
	@override late final _Translations$operation$layout$de layout = _Translations$operation$layout$de._(_root);
	@override late final _Translations$operation$export$de export = _Translations$operation$export$de._(_root);
	@override late final _Translations$operation$spots$de spots = _Translations$operation$spots$de._(_root);
	@override late final _Translations$operation$import$de import = _Translations$operation$import$de._(_root);
}

// Path: map
class _Translations$map$de extends Translations$map$en {
	_Translations$map$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$de outlineIssue = _Translations$map$outlineIssue$de._(_root);
	@override String get outlinesDisclaimer => 'Umrisse dienen nur zur Orientierung. Recherchiere selbst!';
	@override String outlinesCredit({required Object sources}) => 'Umrisse: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Grenzen: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Einrichtungen: ${sources}';
	@override String get fullCredits => 'Vollständige Datenquellen';
	@override String get fewerCredits => 'Weniger Quellen';
	@override String get emptyState => 'Noch keine QSO-Standorte.\nQSOs mit Grid, Staat oder Land werden hier angezeigt.';
	@override String get unavailable => 'Die Karte ist gerade nicht verfügbar.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Flach';
	@override String get globe => 'Globus';
	@override String get zoomIn => 'Vergrößern';
	@override String get zoomOut => 'Verkleinern';
	@override late final _Translations$map$postcard$de postcard = _Translations$map$postcard$de._(_root);
}

// Path: mapsView
class _Translations$mapsView$de extends Translations$mapsView$en {
	_Translations$mapsView$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Karten';
	@override String get searchHint => 'Parks, Gipfel und mehr suchen';
	@override String get activities => 'Aktivitäten';
	@override String get layers => 'Ebenen';
	@override String get baseMap => 'Basiskarte';
	@override String get satellite => 'Satellit (Esri)';
	@override String get facilities => 'Park-Einrichtungen';
	@override String get boundaries => 'Grenzen';
	@override String get currentLocation => 'Aktueller Standort';
	@override String noMatches({required Object text}) => 'Nichts passt zu „${text}“';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Referenz bei ${where}',
		other: '${count} Referenzen bei ${where}',
	);
	@override String get startOperation => 'Betrieb mit diesen Referenzen starten';
}

// Path: activitiesView
class _Translations$activitiesView$de extends Translations$activitiesView$en {
	_Translations$activitiesView$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aktivitäten';
	@override String get activitiesCountZero => 'Keine Aktivitäten ausgewählt';
	@override String get activitiesCountOne => '1 Aktivität';
	@override String activitiesCountOther({required Object count}) => '${count} Aktivitäten';
	@override String get empty => 'Noch keine Aktivitäten — füge über Vorschläge & Suche unten eine hinzu';
	@override String get removeActivity => 'Entfernen';
	@override String openReferenceLink({required Object name}) => '${name} öffnen';
	@override String get editActivity => 'Aktivität bearbeiten';
	@override String get manageExtensions => 'Erweiterungen verwalten';
	@override String get manage => 'Verwalten';
	@override String activitiesTitle1({required Object first}) => 'Aktivitätsarten: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Aktivitätsarten: ${first} und ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Aktivitätsarten: ${first}, ${second} und ${more} weitere';
	@override String get reference => 'Referenz';
	@override String get invalidReference => 'Ungültig';
	@override String get duplicateReference => 'Bereits hinzugefügt';
	@override String get searchHint => 'Nach Name, Referenz oder anderem suchen…';
	@override String get noSuggestions => 'Keine Treffer';
	@override String get noSuggestionsHint => 'Suche oben nach Name oder Nummer der Referenz';
	@override String get noSuggestionsExample => '(zum Beispiel \'trail\' oder \'4556\')';
	@override String get allOptions => 'Aktivitätsarten';
	@override String get determiningLocation => 'Aktueller Standort wird ermittelt…\nWarte auf GPS-Fix, um Referenzen in der Nähe zu finden';
	@override String get locationUnavailableTitle => 'Standortdaten nicht verfügbar';
	@override String get locationDeniedTitle => 'Standortberechtigung verweigert';
	@override String get locationBlockedTitle => 'Standortberechtigung blockiert';
	@override String get noNearbyReason => 'Referenzen in der Nähe können nicht ermittelt werden';
	@override String locationManualHint({required Object icon}) => 'Tippe auf ${icon}, um deinen Standort manuell einzugeben,\noder suche einfach nach Referenzen über den Namen';
	@override String get locationGrantAction => 'Standortzugriff erlauben';
	@override String get locationSettingsAction => 'Einstellungen öffnen';
	@override String get locationSettingsUnavailable => 'Erlaube den Standortzugriff in deinen Systemeinstellungen';
	@override String get locationGrantRefused => 'Immer noch kein Standort — das System hat wieder abgelehnt';
	@override String get searchUnavailableTitle => 'Aktivitätssuche nicht verfügbar';
	@override String get searchUnavailableReason => 'Keine Aktivitäts-Erweiterung konnte die Suche ausführen. Versuche es gleich noch einmal.';
	@override String get emptySheet => 'Füge über Vorschläge & Suche unten eine hinzu';
	@override String get exports => 'Exporte';
	@override String get exportLogs => 'Logs exportieren';
	@override String get tools => 'Werkzeuge';
	@override String get toolsTitle => 'Betriebswerkzeuge';
	@override String get operationDetails => 'Betriebs-Details';
	@override String get share => 'Teilen';
	@override String get archive => 'Archivieren';
	@override String get deleteOperation => 'Betrieb löschen';
	@override String get undeleteOperation => 'Betrieb wiederherstellen';
	@override String get alreadySelected => 'Bereits ausgewählt';
	@override String get selected => 'Ausgewählt';
	@override String pickPosition({required Object index, required Object count}) => '${index} von ${count}';
	@override String get previousPick => 'Vorheriger Treffer';
	@override String get nextPick => 'Nächster Treffer';
	@override String get retiredReference => 'Stillgelegt';
	@override String enableExtension({required Object name}) => '${name} aktivieren';
	@override String get enableExtensionHint => 'Diese Erweiterung passt zu deiner Suche, ist aber derzeit nicht aktiviert';
	@override String get enableExtensionForRefHint => 'Diese Erweiterung verarbeitet eine der Referenzen dieses Betriebs, ist aber derzeit nicht aktiviert';
	@override String extensionNotRunning({required Object name}) => '${name} läuft nicht';
	@override String get extensionNotRunningHint => 'Diese Erweiterung wurde deaktiviert, öffne die Erweiterungseinstellungen für mehr Infos';
	@override String installExtension({required Object name}) => '${name} installieren';
	@override String get installExtensionHint => 'Diese Erweiterung passt zu deiner Suche, ist aber nicht installiert';
	@override String get onlyCatalogMatches => 'Keine Treffer\nEinige Erweiterungen im Katalog könnten Ergebnisse haben.\nInstalliere sie unten unter Aktivitätsarten.';
	@override String get setupUnavailable => 'Die Einrichtung dieser Aktivität konnte nicht geladen werden — versuche es erneut über Verwalten';
	@override String get controlsUnavailableTitle => 'Aktivitätssteuerung nicht verfügbar';
	@override String get controlsUnavailableReason => 'Deine Referenzen sind sicher, können aber gerade nicht bearbeitet werden.';
	@override String get controlsUnavailableRetry => 'Erneut versuchen';
	@override String get onlyDisabledMatches => 'Keine Treffer\nEinige verfügbare Erweiterungen könnten Ergebnisse haben.\nAktiviere sie unten unter Aktivitätsarten.';
	@override String get onlyNotRunningMatches => 'Keine Treffer\nEinige Erweiterungen, die Ergebnisse haben könnten, laufen nicht.\nSiehe Aktivitätsarten unten.';
	@override String get mapToggle => 'Karte';
	@override String get searchToggle => 'Suche';
	@override String get addToOperation => 'Zum Betrieb hinzufügen';
	@override String get addToOperationShort => 'Hinzufügen';
	@override String get mapEmptyState => 'Keine Ergebnisse für die Karte';
	@override String get mapEmptyStateHint => 'Wechsle zurück zur Liste oder suche nach etwas anderem';
	@override String get imports => 'Importe';
}

// Path: loggingControls
class _Translations$loggingControls$de extends Translations$loggingControls$en {
	_Translations$loggingControls$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Zeit (UTC)';
	@override String get date => 'Datum';
	@override String get now => 'Jetzt';
	@override String get frequency => 'Frequenz';
	@override String get mode => 'Modus';
	@override String get theirCall => 'Deren Rufzeichen';
	@override String get noteField => 'Notiz';
	@override String get todoField => 'To-do';
	@override String get sent => 'Gesendet';
	@override String get rcvd => 'Empf.';
	@override String get more => 'Mehr';
	@override String get revert => 'Rückgängig';
	@override String get undoDelete => 'Löschen rückgängig';
	@override String get restore => 'Wiederherstellen';
	@override String get wipe => 'Leeren';
	@override String get undo => 'Rückgängig';
	@override String get pendingDeleteTapWarning => 'Tippe noch einmal auf den Papierkorb, um dieses QSO zu löschen';
	@override String get pendingDeleteClickWarning => 'Klicke noch einmal auf den Papierkorb, um dieses QSO zu löschen';
	@override String get deletedQsoWarning => 'Gelöschtes QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Tippe noch einmal auf den Papierkorb, um dies zu löschen: ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Klicke noch einmal auf den Papierkorb, um dies zu löschen: ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'Gelöscht: ${kind}';
	@override String get timeControl => 'Zeit';
	@override String get radioControl => 'Funkgerät';
	@override String get powerControl => 'Leistung';
	@override String get notesControl => 'Notizen';
	@override String get power => 'Leistung';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Logging-Steuerungen';
	@override String get spottingControl => 'Spot';
	@override String get spottingSelfControl => 'Selbst-Spot';
	@override String spotSelfAt({required Object freq}) => 'Selbst-Spot auf ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} auf ${freq}';
	@override String spotTooLate({required Object call}) => 'Zu spät, um ${call} zu spotten';
	@override String get spotNoFreq => 'Zuerst eine Frequenz zum Spotten einstellen';
	@override String get spotComment => 'Kommentar';
	@override String get bandOrFreqRequired => 'Vor dem Loggen eine Frequenz oder ein Band einstellen';
	@override String get missingBand => 'Kein Band';
	@override String get missingMode => 'Kein Modus';
	@override String saveFailed({required Object error}) => 'Speichern fehlgeschlagen: ${error}';
	@override String deleteFailed({required Object error}) => 'Löschen fehlgeschlagen: ${error}';
	@override late final _Translations$loggingControls$info$de info = _Translations$loggingControls$info$de._(_root);
}

// Path: formChrome
class _Translations$formChrome$de extends Translations$formChrome$en {
	_Translations$formChrome$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(ohne Titel)';
	@override String get showMore => 'Mehr anzeigen';
	@override String get showAll => 'Alle anzeigen';
	@override String get showFewer => 'Weniger anzeigen';
	@override String get defaults => 'Standardwerte';
	@override String get search => 'Suchen';
	@override String get clear => 'Leeren';
	@override String get openPage => 'Seite öffnen';
	@override String get connected => 'Verbunden';
	@override String get notConnected => 'Nicht verbunden';
	@override String get manage => 'Verwalten';
	@override String get connect => 'Verbinden';
	@override String get formTitle => 'Formular';
	@override String addItem({required Object label}) => '${label} hinzufügen';
	@override String editItem({required Object label}) => '${label} bearbeiten';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => '${shown} von ${total} angezeigt (${selected} ausgewählt)';
	@override String validationError({required Object error}) => 'Validierungsfehler: ${error}';
	@override String transformationError({required Object error}) => 'Umwandlungsfehler: ${error}';
	@override String actionError({required Object error}) => 'Fehler: ${error}';
	@override String get removeItem => 'Entfernen';
	@override String get storageUnavailable => 'Anmeldedaten nicht verfügbar';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$de extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSO bearbeiten';
	@override String get operatorCall => 'Operator';
	@override String get position => 'Funkplatz';
	@override String get theirName => 'Name';
	@override String get theirGrid => 'Grid';
	@override String get theirState => 'Staat';
	@override String get band => 'Band';
	@override String get notes => 'Notizen';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Deren Info';
	@override String get sectionOur => 'Unsere Info';
	@override String get sectionNotes => 'Notizen';
	@override String get theirCity => 'Stadt';
	@override String get theirCounty => 'Landkreis';
	@override String get theirEntity => 'Entität';
	@override String get theirCqZone => 'CQ-Zone';
	@override String get theirItuZone => 'ITU-Zone';
	@override String get theirArrlSection => 'ARRL-Sektion';
	@override String get theirLat => 'Breitengrad';
	@override String get theirLon => 'Längengrad';
	@override String get theirPower => 'Deren Leistung';
}

// Path: qsoList
class _Translations$qsoList$de extends Translations$qsoList$en {
	_Translations$qsoList$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Noch keine QSOs — arbeite jemanden!';
	@override String get bandOrModeWarning => 'Bitte prüfe, ob Band und Modus stimmen';
	@override String get today => 'Heute';
	@override String get yesterday => 'Gestern';
	@override String get tomorrow => 'Morgen';
}

// Path: loggingPanel
class _Translations$loggingPanel$de extends Translations$loggingPanel$en {
	_Translations$loggingPanel$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Betriebsstatistik';
	@override String get scoring => 'Punktewertung';
	@override String get dxccEntities => 'DXCC-Entitäten';
	@override String get statesWorked => 'Staaten';
	@override String get provincesWorked => 'Provinzen';
	@override String get duplicates => 'Duplikate';
}

// Path: callInfo
class _Translations$callInfo$de extends Translations$callInfo$en {
	_Translations$callInfo$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Bild anzeigen';
	@override String get imageUnavailable => 'Foto nicht verfügbar';
	@override String get photo => 'Foto';
	@override String get notes => 'Notizen';
	@override String distanceTo({required Object distance}) => '${distance} nach';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) nach';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) nach';
	@override String distanceAway({required Object distance}) => '${distance} entfernt';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) entfernt';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) entfernt';
	@override String get thisOpCountOne => '1 QSO in diesem Betrieb';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs in diesem Betrieb';
	@override String get otherOpsCountOne => '1 QSO in anderen Betrieben';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs in anderen Betrieben';
	@override String andMore({required Object count}) => '… und ${count} mehr';
	@override String withCall({required Object call}) => 'mit ${call}';
	@override String fromOperation({required Object where}) => 'aus ${where}';
	@override late final _Translations$callInfo$history$de history = _Translations$callInfo$history$de._(_root);
}

// Path: settings
class _Translations$settings$de extends Translations$settings$en {
	_Translations$settings$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Einstellungen';
	@override String get language => 'Sprache';
	@override String languageSystem({required Object language}) => 'Systemeinstellungen folgen (${language})';
	@override late final _Translations$settings$theme$de theme = _Translations$settings$theme$de._(_root);
	@override late final _Translations$settings$themeDescription$de themeDescription = _Translations$settings$themeDescription$de._(_root);
	@override String get fontScale => 'Schriftgröße';
	@override late final _Translations$settings$fontScaleOpts$de fontScaleOpts = _Translations$settings$fontScaleOpts$de._(_root);
	@override late final _Translations$settings$keepDeviceAwake$de keepDeviceAwake = _Translations$settings$keepDeviceAwake$de._(_root);
	@override String get layoutDensity => 'Layout-Dichte';
	@override late final _Translations$settings$layoutDensityOpts$de layoutDensityOpts = _Translations$settings$layoutDensityOpts$de._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'das Fenster ist zu niedrig, verwende ${effective}';
	@override String get layoutDensityAtLimit => 'am Anschlag';
	@override String get distanceUnits => 'Entfernungseinheiten';
	@override late final _Translations$settings$distanceUnitsOpts$de distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$de._(_root);
	@override String get userInterface => 'Benutzeroberfläche';
	@override late final _Translations$settings$logging$de logging = _Translations$settings$logging$de._(_root);
	@override late final _Translations$settings$catServer$de catServer = _Translations$settings$catServer$de._(_root);
	@override late final _Translations$settings$radio$de radio = _Translations$settings$radio$de._(_root);
	@override late final _Translations$settings$help$de help = _Translations$settings$help$de._(_root);
	@override late final _Translations$settings$exports$de exports = _Translations$settings$exports$de._(_root);
	@override late final _Translations$settings$map$de map = _Translations$settings$map$de._(_root);
	@override late final _Translations$settings$privacy$de privacy = _Translations$settings$privacy$de._(_root);
	@override String get operatorCall => 'Operator-Rufzeichen';
	@override late final _Translations$settings$sync$de sync = _Translations$settings$sync$de._(_root);
	@override late final _Translations$settings$peers$de peers = _Translations$settings$peers$de._(_root);
	@override String get developerMode => 'Entwicklermodus';
	@override late final _Translations$settings$syncPanel$de syncPanel = _Translations$settings$syncPanel$de._(_root);
	@override late final _Translations$settings$accounts$de accounts = _Translations$settings$accounts$de._(_root);
	@override late final _Translations$settings$station$de station = _Translations$settings$station$de._(_root);
	@override late final _Translations$settings$offlineData$de offlineData = _Translations$settings$offlineData$de._(_root);
	@override late final _Translations$settings$profiles$de profiles = _Translations$settings$profiles$de._(_root);
	@override late final _Translations$settings$search$de search = _Translations$settings$search$de._(_root);
	@override late final _Translations$settings$developer$de developer = _Translations$settings$developer$de._(_root);
	@override late final _Translations$settings$about$de about = _Translations$settings$about$de._(_root);
	@override late final _Translations$settings$panels$de panels = _Translations$settings$panels$de._(_root);
	@override String get showMoreSettings => 'Weitere Einstellungen anzeigen';
	@override String get numberFormat => 'Zahlenformat';
	@override late final _Translations$settings$numberFormatOpts$de numberFormatOpts = _Translations$settings$numberFormatOpts$de._(_root);
	@override late final _Translations$settings$numberFormatDescription$de numberFormatDescription = _Translations$settings$numberFormatDescription$de._(_root);
	@override late final _Translations$settings$numberFormatSeparators$de numberFormatSeparators = _Translations$settings$numberFormatSeparators$de._(_root);
	@override String get gridPrecision => 'Grid-Genauigkeit';
	@override late final _Translations$settings$gridPrecisionOpts$de gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$de._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$de gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$de._(_root);
}

// Path: commands
class _Translations$commands$de extends Translations$commands$en {
	_Translations$commands$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Aktiviere zuerst Sync in den Einstellungen.';
	@override String get fullResyncStarted => 'Vollständige Neusynchronisierung gestartet — lokale Daten wurden zuvor gesichert.';
	@override String noDataFilesMatched({required Object target}) => 'Keine Datendateien passen zu „${target}“.';
	@override String reloadFailed({required Object error}) => 'Neu laden fehlgeschlagen: ${error}';
	@override String get reloadingAll => 'Alle Datendateien werden neu geladen…';
	@override String reloadingTarget({required Object target}) => 'Datendateien für ${target} werden neu geladen…';
	@override String unknownExperiment({required Object token}) => 'Unbekanntes Experiment „${token}“';
	@override String experimentEnabled({required Object name}) => '${name} aktiviert';
	@override String experimentDisabled({required Object name}) => '${name} deaktiviert';
	@override String get sentryTestSent => 'Test-Fehlerbericht an Sentry gesendet';
	@override String get sentryTestLocalOnly => 'Sentry ist in diesem Build deaktiviert — Testfehler nur lokal protokolliert';
	@override String get noOperationOpen => 'Dieser Befehl braucht einen geöffneten Betrieb';
	@override String unknownSegmentKind({required Object kind}) => 'Weiß nicht, wie man ein \'${kind}\' markiert';
	@override String get operationAlreadyStarted => 'Dieser Betrieb hat bereits eine Startmarkierung';
	@override String get couldNotOpenLocation => 'Pause hinzugefügt, aber der Standortbildschirm konnte nicht geöffnet werden';
	@override String get noTestOperations => 'Keine Testbetriebe zum endgültigen Löschen';
	@override String get purgeTestsUnavailable => 'PURGETESTS muss einen Bestätigungsdialog anzeigen, der hier nicht verfügbar ist';
	@override String get syncAllUnavailable => 'SYNCALL muss einen Bestätigungsdialog anzeigen, der hier nicht verfügbar ist';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Testbetrieb endgültig gelöscht',
		other: '${count} Testbetriebe endgültig gelöscht',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '${purged} von ${total} Testbetrieben endgültig gelöscht — der Rest ist fehlgeschlagen; versuche PURGETESTS erneut';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Testkontakt ohne Betrieb endgültig gelöscht',
		other: '${count} Testkontakte ohne Betrieb endgültig gelöscht',
	);
	@override String get purgeTestsContactsFailed => 'Die Testbetriebe wurden gelöscht, aber die Testkontakte ohne Betrieb nicht; versuche PURGETESTS erneut';
	@override String get purgeTestsNothingToDo => 'Nichts wurde gelöscht';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '${removed} von ${total} Testbetrieben entfernt — der Rest ist fehlgeschlagen; versuche Prüfen erneut';
	@override String get receivedPurgesFailed => 'Diese Testbetriebe konnten nicht entfernt werden — versuche Prüfen erneut';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Testbetrieb wurde auf einem anderen Gerät entfernt',
		other: '${count} Testbetriebe wurden auf einem anderen Gerät entfernt',
	);
	@override String get receivedPurgesReview => 'Prüfen';
	@override String get settingOn => 'Ein';
	@override String get settingOff => 'Aus';
	@override String get settingEmpty => '(leer)';
	@override String get settingSecretSet => '(gesetzt)';
	@override String get settingSecretUnset => '(nicht gesetzt)';
	@override String settingSelectedCount({required Object count}) => '${count} ausgewählt';
	@override String get settingExpectsOnOff => 'on oder off';
	@override String settingExpectsOneOf({required Object choices}) => 'eines von: ${choices}';
	@override String get settingExpectsNumber => 'eine Zahl';
	@override String settingVanished({required Object label}) => '„${label}“ ist nicht mehr verfügbar';
	@override String get noCwKeyer => 'Kein verbundenes Funkgerät kann CW tasten';
	@override String get noKeyer => 'Kein verbundenes Funkgerät kann CW tasten oder Sprachspeicher abspielen';
	@override String get keyerNeedsOperation => 'Öffne einen Betrieb, um den CW-Keyer zu verwenden';
	@override String get keyerExperimentOff => 'CW-Tastung ist aus — schalte sie mit EXP KEYER ein';
	@override String get esmExperimentOff => 'Enter sendet Nachrichten ist aus — schalte es mit EXP ESM ein';
	@override String cwSending({required Object text}) => 'Sende CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW-Nachricht F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW-Nachricht F${n} wurde nicht gesendet: die Erweiterungen sind nicht bereit';
	@override String settingNotStored({required Object label}) => '„${label}“ hat diesen Wert nicht angenommen';
}

// Path: commandDialog
class _Translations$commandDialog$de extends Translations$commandDialog$en {
	_Translations$commandDialog$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Rufzeichen suchen oder Befehl eingeben';
	@override String noResults({required Object text}) => 'Nichts passt zu „${text}“';
	@override String get sectionCommands => 'Befehle';
	@override String get sectionGoTo => 'Gehe zu';
	@override String get sectionOperations => 'Betrieb';
	@override String get goHome => 'Start';
	@override String get goSettings => 'Einstellungen';
	@override String get goNewOperation => 'Neuer Betrieb';
	@override String runTyped({required Object text}) => '„${text}“ ausführen';
	@override String get sectionSuggestions => 'Probiere';
	@override String get lookingUp => 'Rufzeichen wird abgefragt…';
	@override String get blockedByPane => 'Befehle sind nicht möglich, solange ein Panel oder Dialog geöffnet ist';
}

// Path: expiredBuild
class _Translations$expiredBuild$de extends Translations$expiredBuild$en {
	_Translations$expiredBuild$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dieser Build ist abgelaufen';
	@override String get body => 'Bitte besuche ham2k.com und hole dir eine neuere Version.';
	@override String get visit => 'ham2k.com besuchen';
	@override String get dismiss => 'Trotzdem fortfahren';
}

// Path: staleness
class _Translations$staleness$de extends Translations$staleness$en {
	_Translations$staleness$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Ein wichtiges Update wartet';
	@override String get codePushFloorBody => 'Diese Version enthält eine Korrektur, die du noch nicht hast.';
	@override String get restartToApply => 'Starte die App neu, um es anzuwenden.';
	@override String get quitAndReopen => 'Beende die App und öffne sie erneut, um es anzuwenden.';
	@override String get reopenToApply => 'Schließe die App und öffne sie erneut, um es anzuwenden.';
	@override String get ignoreForNow => 'Vorerst ignorieren';
}

// Path: spotting
class _Translations$spotting$de extends Translations$spotting$en {
	_Translations$spotting$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Noch kein QSO zum Spotten geloggt.';
	@override String get setFrequencyFirst => 'Stelle zuerst eine Frequenz ein.';
	@override String get nothingToSpot => 'Kein Spot möglich — keine Erweiterung bietet hier Spotting an.';
	@override String spotFailed({required Object source, required Object message}) => '${source} fehlgeschlagen: ${message}';
	@override String get unknownError => 'unbekannter Fehler';
	@override String get notSent => 'Spot nicht gesendet.';
	@override String get notRefreshedOffline => 'Keine Verbindung — Spots wurden nicht aktualisiert';
}

// Path: dataFiles
class _Translations$dataFiles$de extends Translations$dataFiles$en {
	_Translations$dataFiles$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Lade herunter…';
	@override String downloadFailedTitle({required Object name}) => '${name} konnte nicht heruntergeladen werden';
	@override String get downloadFailedWebHint => 'Das kann ein Netzwerkproblem sein, oder der Host dieses Links unterstützt keine direkten Downloads aus einem Webbrowser. Versuche es mit der Desktop- oder Mobil-App oder einem anderen Speicherort.';
	@override String get downloadTimedOut => 'Der Server hat zu lange gebraucht. Versuche es später erneut.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} hat mit einem Fehler geantwortet (HTTP ${status}). Versuche es später erneut.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} konnte diese Datei nicht liefern (HTTP ${status}). Prüfe, ob ihre Adresse noch stimmt.';
	@override String processingFailedTitle({required Object name}) => '${name} konnte nicht verarbeitet werden';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Der Download hatte nur ${imported} der ${existing} Einträge auf diesem Gerät, daher wurden die fehlenden behalten. Eine Aktualisierung unter Einstellungen › Offline-Daten übernimmt ihn trotzdem.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Eintrag für ${label} importiert.',
		other: '${count} Einträge für ${label} importiert.',
	);
	@override String importedData({required Object label}) => 'Daten für ${label} importiert.';
	@override String get cleanedUpTitle => 'Erweiterungsdaten bereinigt';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Daten für ${count} Datendatei von deaktivierten Erweiterungen entfernt.',
		other: 'Daten für ${count} Datendateien von deaktivierten Erweiterungen entfernt.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} Einträge';
	@override String get definitionUnavailable => 'Die Quelle der Datei hat keine Definition geliefert — ihre Erweiterung startet evtl. gerade neu oder ist falsch konfiguriert. Versuche es gleich noch einmal.';
}

// Path: updates
class _Translations$updates$de extends Translations$updates$en {
	_Translations$updates$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Update verfügbar';
	@override String newVersionAvailable({required Object version}) => 'Eine neue Version (${version}) ist verfügbar.';
	@override String get getIt => 'Holen';
	@override String get ok => 'OK';
	@override String get updateReady => 'Update bereit';
	@override String get restartToApply => 'Ein Update wurde heruntergeladen. Starte neu, um es anzuwenden.';
	@override String get appliesNextLaunch => 'Ein Update wurde heruntergeladen. Es wird beim nächsten Öffnen der App angewendet.';
	@override String get restartNow => 'Jetzt neu starten';
	@override String get reloadToUpdate => 'Eine neuere Version dieser Seite ist verfügbar. Lade neu, um sie zu erhalten.';
	@override String get reloadNow => 'Jetzt neu laden';
	@override String get checkForUpdates => 'Nach Updates suchen';
	@override String get checkingForUpdates => 'Suche nach Updates…';
	@override String get upToDate => 'Auf dem neuesten Stand';
	@override String get automaticChecks => 'Automatisch prüfen';
	@override String get automaticChecksDescription => 'Ab dem nächsten Start der App im Hintergrund nach neuen Versionen suchen';
}

// Path: extensionService
class _Translations$extensionService$de extends Translations$extensionService$en {
	_Translations$extensionService$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Erweiterungs-Laufzeit nicht bereit.';
	@override String testFailed({required Object error}) => 'Test fehlgeschlagen: ${error}';
	@override String connectedAs({required Object identity}) => 'Verbunden als ${identity}';
	@override String get invalidFieldConfiguration => 'Ungültige Feldkonfiguration';
	@override String get invalidValue => 'Ungültiger Wert';
	@override String validationError({required Object error}) => 'Validierungsfehler: ${error}';
	@override String actionFailed({required Object error}) => 'Aktion fehlgeschlagen: ${error}';
	@override String get commandFailed => 'Der Befehl konnte nicht ausgeführt werden';
	@override String get reportUnavailable => 'Meldungen können gerade nicht gesendet werden';
	@override String get stashUnavailable => 'Ham2K File Stash ist gerade nicht erreichbar';
	@override String timersSuspendedBudget({required Object name}) => '${name} hat zu viel Zeit in seinen Timern verbracht. Sie sind angehalten, bis die Erweiterungen neu starten.';
	@override String timersSuspendedFailures({required Object name}) => 'Die Timer von ${name} sind wiederholt fehlgeschlagen. Sie sind angehalten, bis die Erweiterungen neu starten.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} ist in einem Timer hängen geblieben. Seine Timer sind angehalten, bis die Erweiterungen neu starten.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$de extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Betriebsort';
	@override String get selectedLocation => 'Ausgewählter Ort';
	@override String get gridSquare => 'Maidenhead-Locator';
	@override String get gridInvalid => 'Benötigt 4, 6, 8 oder 10 Zeichen, z. B. FN31pr';
	@override String get suggestedLocations => 'Vorgeschlagene Orte';
	@override String get deviceGps => 'Geräte-GPS';
	@override String peerGps({required Object device}) => 'GPS von ${device}';
	@override String get locating => 'Ermittle Standort…';
	@override String get gpsUnavailable => 'Standort nicht verfügbar';
	@override String get permissionDenied => 'Standortberechtigung verweigert';
	@override String get permissionBlocked => 'Standortberechtigung blockiert';
	@override String get moreDetails => 'Weitere Details';
	@override String get stateOrProvince => 'Bundesland oder Provinz (optional)';
	@override String get controlsUnavailableTitle => 'Aktivitätssteuerung nicht verfügbar';
	@override String get controlsUnavailableReason => 'Diese Referenzen sind weiterhin nutzbar; nur ihre Aktivitäten waren nicht erreichbar.';
	@override String get controlsUnavailableRetry => 'Erneut versuchen';
	@override String get county => 'Landkreis (optional)';
}

// Path: versionLabel
class _Translations$versionLabel$de extends Translations$versionLabel$en {
	_Translations$versionLabel$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Version ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'Build ${build}';
}

// Path: notices
class _Translations$notices$de extends Translations$notices$en {
	_Translations$notices$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Noch keine Hinweise';
	@override String get webStorageInMemory => 'Dieser Browser konnte keinen dauerhaften Speicher bereitstellen — das Log liegt nur im Arbeitsspeicher und geht VERLOREN, wenn dieser Tab geschlossen wird. Verwende ein aktuelles Chrome, Firefox, Safari oder Edge.';
	@override String get webStorageUnreliable => 'Dieser Browser verwendet einen Ersatzspeicher, der mit mehreren Tabs nicht sicher ist — lass nur einen Tab offen und Sync eingeschaltet.';
	@override String get logFromNewerBuildTitle => 'Dieses Log braucht eine neuere Version';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Dein Log wurde von einer neueren Version von HaLo geschrieben (Speicherversion ${storage}; diese versteht ${understood}), daher kann es nicht geöffnet werden, und neue Kontakte werden nicht gespeichert. Installiere die neuere Version erneut — oder, wenn du diesen Build starten wolltest, verweise ihn auf einen anderen Datenordner. Das Log liegt in ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Dein Log wurde von einer neueren Version von HaLo geschrieben (Speicherversion ${storage}; diese versteht ${understood}), daher kann es nicht geöffnet werden, und neue Kontakte werden nicht gespeichert. Öffne dieses Log stattdessen mit der neueren Version.';
	@override String get preferencesRestoredTitle => 'Einstellungen aus einer Sicherung wiederhergestellt';
	@override String get preferencesRestored => 'Die Einstellungsdatei konnte nicht gelesen werden, daher hat HaLo die letzte gute Kopie wiederhergestellt. Was du in deiner letzten Sitzung geändert hast, musst du evtl. erneut einstellen. Die unlesbare Datei wird daneben aufbewahrt, mit dem Namen shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Einstellungen zurückgesetzt';
	@override String get preferencesReset => 'Die Einstellungsdatei konnte nicht gelesen werden und es gab keine Sicherung, daher ist HaLo mit den Standardwerten gestartet. Die unlesbare Datei wird im Datenordner der App aufbewahrt, mit dem Namen shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} wurde nicht automatisch verbunden';
	@override String autoConnectHeld({required Object name}) => 'HaLo reagierte beim letzten Verbindungsaufbau mit ${name} nicht mehr, daher wurde es diesmal in Ruhe gelassen, statt es erneut zu riskieren. Prüfe, ob das Funkgerät eingeschaltet und das Kabel eingesteckt ist, und drücke dann in den Einstellungen bei ihm auf Verbinden.';
}

// Path: syncAccount
class _Translations$syncAccount$de extends Translations$syncAccount$en {
	_Translations$syncAccount$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anonymes Konto (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (Bestätigung ausstehend)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (Bestätigung ausstehend - #${id})';
}

// Path: deepLink
class _Translations$deepLink$de extends Translations$deepLink$en {
	_Translations$deepLink$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Starte zuerst einen Betrieb und sende den Kontakt dann erneut';
	@override String get waitingInOperation => 'Dieser Kontakt wartet im Betrieb hinter diesem Bildschirm';
	@override String unknownActivities({required Object refs}) => 'Dieses Gerät hat keine Aktivität für ${refs}, daher wurden diese Referenzen weggelassen';
	@override String activitiesUnavailable({required Object refs}) => 'Deine Aktivitäten waren nicht erreichbar, daher wurde ${refs} weggelassen — versuche den Link erneut';
}

// Path: confirmDevice
class _Translations$confirmDevice$de extends Translations$confirmDevice$en {
	_Translations$confirmDevice$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gerät bestätigen';
	@override String get codePrompt => 'Gib den Code ein, der auf dem Gerät angezeigt wird, das diesem Konto beitreten möchte.';
	@override String get code => 'Code';
	@override String get lookUp => 'Nachschlagen';
	@override String get codeNotFound => 'Keine Anfrage passt zu diesem Code. Codes laufen nach 10 Minuten ab — lass dir vom anderen Gerät einen neuen geben.';
	@override String get linkExpired => 'Dieser Link ist abgelaufen. Lass das andere Gerät einen neuen QR-Code anzeigen.';
	@override String areYouSure({required Object device}) => '${device} mit diesem Konto verknüpfen?';
	@override String get unnamedDevice => 'ein unbenanntes Gerät';
	@override String get grantWarning => 'Es kann jeden Betrieb und jedes QSO in diesem Konto lesen und ändern.';
	@override String get needsSyncTitle => 'Dieses Gerät synchronisiert noch nicht';
	@override String get needsSyncText => 'Schalte die Ham2K-Log-Filer-Synchronisierung ein und verknüpfe dieses Gerät mit einem Konto, bevor es ein anderes zulassen kann.';
	@override String get malformedRequest => 'Der Sync-Server hat eine Anfrage gesendet, die diese App nicht lesen konnte. Bitte das andere Gerät, es erneut zu versuchen.';
	@override String get linkIt => 'Gerät verknüpfen';
}

// Path: switchAccounts
class _Translations$switchAccounts$de extends Translations$switchAccounts$en {
	_Translations$switchAccounts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Noch keine Kontodetails';
	@override String get currentAccount => 'Aktuelles Konto';
	@override String get otherAccounts => 'Andere Konten';
	@override String get linkToAnother => 'Mit einem anderen Konto verknüpfen';
	@override String get linkWithSibling => 'Mit anderer Ham2K-App verknüpfen';
	@override String get linkWithPolo => 'Mit Konto der älteren Version verknüpfen';
	@override String get linkWithSiblingDescription => 'Du hast eine andere Ham2K-App installiert. Verknüpfe mit dem dort verwendeten Konto.';
	@override String siblingPrompt({required Object app}) => 'Bestätige die Anfrage in ${app} und komm dann hierher zurück.';
	@override String openSiblingAgain({required Object app}) => '${app} erneut öffnen';
	@override String get siblingNoGrant => 'Hat nicht geklappt? Öffne sie erneut oder geh zurück und verknüpfe auf andere Weise.';
	@override String siblingOpenFailed({required Object app}) => '${app} konnte nicht geöffnet werden.';
	@override String siblingLinkRenewed({required Object app}) => 'Der Link ist abgelaufen und ein neuer ist bereit — öffne ${app} erneut.';
	@override String get tryAgain => 'Erneut versuchen';
	@override String get linkWithQr => 'Mit QR-Code verknüpfen';
	@override String get linkWithQrDescription => 'Scanne ihn von einem Gerät, das das Konto bereits nutzt';
	@override String get linkWithEmail => 'Mit E-Mail-Adresse verknüpfen';
	@override String get linkWithEmailDescription => 'Mit einem Code oder einem E-Mail-Link bestätigen';
	@override String get enterEmailPrompt => 'Gib die E-Mail-Adresse des Kontos ein, das dieses Gerät verwenden soll.';
	@override String get emailAddress => 'E-Mail-Adresse';
	@override String get linkAccount => 'Konto verknüpfen';
	@override String get copiedCode => 'Code in die Zwischenablage kopiert';
	@override String get copyCode => 'Code kopieren';
	@override String codePrompt({required Object email}) => 'Öffne die Ham2K-App auf einem Gerät, das bereits mit ${email} verknüpft ist, und gib diesen Code ein, um die Anfrage zu bestätigen:';
	@override String get waitingForConfirmation => 'Warte auf Bestätigung…';
	@override String get sendEmailInstead => 'Stattdessen eine Bestätigungs-E-Mail senden';
	@override String emailSent({required Object email}) => 'Eine E-Mail wurde an ${email} gesendet. Öffne sie und bestätige die Anfrage, um dieses Gerät zu verknüpfen.';
	@override String get resendEmail => 'E-Mail erneut senden';
	@override String get qrPrompt => 'Scanne diesen QR-Code von einem Gerät, das bereits mit dem gewünschten Konto verknüpft ist — zum Beispiel mit Ham2K Portable Logger auf deinem Handy.';
	@override String get serverUnreachable => 'Der Sync-Server war nicht erreichbar. Versuche es später erneut.';
	@override String get emailRequired => 'Gib zum Verknüpfen eine E-Mail-Adresse ein.';
	@override String noAccountForEmail({required Object email}) => 'Kein Konto für ${email} gefunden.';
	@override String serverRejected({required Object error}) => 'Der Sync-Server hat die Anfrage abgelehnt: ${error}';
	@override String get noLinkCode => 'Der Sync-Server hat keinen Verknüpfungscode geliefert. Versuche es später erneut.';
	@override String get noConfirmationCode => 'Der Sync-Server hat keinen Bestätigungscode gesendet. Versuche es später erneut.';
	@override String get switchNotAccepted => 'Dieses Konto hat den Wechsel nicht angenommen. Versuche stattdessen, es mit einer E-Mail-Adresse zu verknüpfen.';
	@override String get requestFailed => 'Bei der Kommunikation mit dem Sync-Server ist etwas schiefgelaufen. Versuche es später erneut.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Betrieb',
		other: '${count} Betriebe',
	);
}

// Path: adifImport
class _Translations$adifImport$de extends Translations$adifImport$en {
	_Translations$adifImport$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSOs aus ADIF importieren';
	@override String reading({required Object filename}) => 'Lese ${filename}…';
	@override String get dropHint => 'ADIF-Datei zum Importieren hier ablegen';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} QSO in dieser Datei',
		other: '${formatted} QSOs in dieser Datei',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} bereits in deinem Log',
		other: '${formatted} bereits in deinem Log',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} wird importiert',
		other: '${formatted} werden importiert',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} neuer Kontakt',
		other: '${formatted} neue Kontakte',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} wird mit einem vorhandenen Kontakt zusammengeführt',
		other: '${formatted} werden mit vorhandenen Kontakten zusammengeführt',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kann nicht importiert werden (kein Rufzeichen)',
		other: '${formatted} können nicht importiert werden (kein Rufzeichen)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} sollte genauer geprüft werden',
		other: '${formatted} sollten genauer geprüft werden',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Referenzen konnten für ${count} Kontakt nicht wiederhergestellt werden',
		other: 'Referenzen konnten für ${formatted} Kontakte nicht wiederhergestellt werden',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${programs}-Referenzen sind für ${count} Kontakt evtl. unvollständig',
		other: '${programs}-Referenzen sind für ${formatted} Kontakte evtl. unvollständig',
	);
	@override String get stackingTypesUnknown => 'Zusammengeführte Kontakte können eine Referenz verlieren — die Aktivitäten konnten nicht sagen, welche Typen sich kombinieren lassen. Brich ab und versuche es erneut, um das zu vermeiden.';
	@override String get nothingToImport => 'Nichts in dieser Datei kann importiert werden';
	@override String get confirm => 'Importieren';
	@override String importing({required Object filename}) => 'Importiere ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Kontakt aus ${filename} importiert',
		other: '${formatted} Kontakte aus ${filename} importiert',
	);
	@override String failed({required Object filename, required Object error}) => '${filename} konnte nicht importiert werden: ${error}';
	@override String notAdif({required Object filename}) => '${filename} sieht nicht wie eine ADIF-Datei aus';
	@override String stationWarning({required Object calls, required Object station}) => 'Warnung: Diese ADIF enthält QSOs von ${calls}, sie werden aber als ${station} importiert, wenn du fortfährst.';
	@override String get stationCallJoin => ' und ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} hat kein Datum und kann nicht importiert werden',
		other: '${formatted} haben kein Datum und können nicht importiert werden',
	);
	@override String activationFound({required Object refs}) => 'Diese Datei enthält eine Aktivierung von ${refs}.';
	@override String get addActivation => 'Zu diesem Betrieb hinzufügen';
	@override String shortfall({required Object written, required Object planned}) => 'Nur ${written} von ${planned} konnten übernommen werden — das Log hat sich geändert, während du entschieden hast.';
	@override String get busy => 'Ein Import läuft bereits. Warte, bis er fertig ist, bevor du einen weiteren startest.';
	@override String get oneFileOnly => 'Lege immer nur eine ADIF-Datei ab — die Reihenfolge des Imports entscheidet, welche Daten gewinnen.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} hat mehr als ${limit} QSOs, das Maximum, das ein Betrieb auf einmal importieren kann.';
}

// Path: offline
class _Translations$offline$de extends Translations$offline$en {
	_Translations$offline$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: verbunden';
	@override String get noRoute => 'Überhaupt keine Netzwerkverbindung.';
	@override String get unreachable => 'Das Netzwerk ist da, aber kein Server reagiert — oft wartet eine Anmeldeseite in einem Browser.';
	@override String get reachable => 'Alle Dienste reagieren wie erwartet.';
	@override String get whatStops => 'Abfragen, Spots und Datendateien sind pausiert. Logging und Synchronisierung in der Nähe nicht.';
	@override String get servicesTitle => 'Dienste';
	@override String get noServices => 'Noch kein Dienst hat sich gemeldet.';
	@override String lastSuccess({required Object when}) => 'Zuletzt vor ${when} reagiert';
	@override String get neverSucceeded => 'Hat noch nicht reagiert';
	@override String nextAttempt({required Object when}) => 'Nächster Versuch in ${when}';
	@override String get nextAttemptNow => 'Nächster Versuch fällig';
	@override String get retry => 'Jetzt erneut versuchen';
	@override String get retrying => 'Versuche…';
	@override String get retryReached => 'Wieder online.';
	@override String get retryUnreachable => 'Immer noch keine Reaktion.';
	@override String get retryNotAttempted => 'Gerade nichts zu senden.';
	@override String get retryThrottled => 'Gerade erst versucht — einen Moment Geduld.';
	@override String get retryDisabled => 'Sync ist ausgeschaltet, daher gibt es nichts zum Prüfen.';
	@override String get syncService => 'Ham2K LoFi Sync';
	@override String get retryInFlight => 'Versuche bereits — einen Moment.';
}

// Path: exportSettings
class _Translations$exportSettings$de extends Translations$exportSettings$en {
	_Translations$exportSettings$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Grundeinstellungen für alle Exporte, mit getrennten Vorlagen für Dateiname und Titel für Referenzaktivitäten und andere Aktivitäten. Jede Exportart kann eigene Standardwerte oder benutzerdefinierte Einstellungen haben.';
	@override String get referenceActivities => 'Referenzaktivitäten';
	@override String get otherActivities => 'Andere Aktivitäten';
	@override String get adifFields => 'ADIF-Felder';
	@override String get loadFailed => 'Export-Einstellungen konnten nicht geladen werden.';
	@override String get retry => 'Erneut versuchen';
	@override String get compactFileNamesDescriptionOn => 'Kompakte Dateinamen, z. B. N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Beschreibende Dateinamen, z. B. 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Namen, Adressen, E-Mails, Notizen und genaue Standorte werden in ADIF-Dateien aufgenommen.';
	@override String get includePrivateDataDescriptionOff => 'Namen, Adressen, E-Mails und Notizen werden weggelassen; Standorte auf sechsstellige Grids begrenzt.';
	@override String get includeLookupDataDescriptionOn => 'Informationen aus Rufzeichen-Abfragediensten werden aufgenommen.';
	@override String get includeLookupDataDescriptionOff => 'Informationen aus Rufzeichen-Abfragediensten werden weggelassen; manuell eingegebene Werte bleiben erhalten.';
	@override String get customTemplatesDescriptionOn => 'Deine eigenen Vorlagen sind aktiv und können unten bearbeitet werden.';
	@override String get customTemplatesDescriptionOff => 'Standardvorlagen sind aktiv. Deine eigenen Vorlagen werden für später aufbewahrt.';
	@override String get type => 'Exportart';
	@override String get defaults => 'Standardwerte';
	@override String get includeLookupData => 'Abfragedaten einbeziehen';
	@override String get customTemplates => 'Eigene Vorlagen';
	@override String get filenameTemplate => 'Dateiname-Vorlage';
	@override String get compactFilenameTemplate => 'Vorlage für kompakten Dateinamen';
	@override String get titleTemplate => 'Titel-Vorlage';
	@override String get adifNotesTemplate => 'ADIF QSO Notizen';
	@override String get adifCommentTemplate => 'ADIF QSO Kommentare';
	@override String get adifQslMessageTemplate => 'ADIF QSL Nachricht';
	@override String get shared => 'Die Einstellungen gelten für jede Erweiterung, die diese Exportart verwendet.';
	@override String get defaultTemplates => 'Schalte „Eigene Vorlagen“ ein, um die Vorlagen dieser Art zu bearbeiten.';
}

// Path: templateEditor
class _Translations$templateEditor$de extends Translations$templateEditor$en {
	_Translations$templateEditor$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Vorschau:';
	@override String get reset => 'Zurücksetzen';
	@override String get docs => 'Vorlagen-Doku';
	@override String get preview => 'Beispielvorschau';
	@override String get reference => 'Vorlagen-Referenz';
	@override String get attributes => 'Verfügbare Attribute';
	@override String get filters => 'Filter';
	@override String get flowControl => 'Ablaufsteuerung';
	@override String get unavailable => 'Die Vorschau ist erst verfügbar, wenn die Erweiterungen bereit sind.';
	@override String get empty => '(leere Ausgabe)';
}

// Path: home.nav
class _Translations$home$nav$de extends Translations$home$nav$en {
	_Translations$home$nav$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Betrieb';
	@override String get chase => 'Jagd';
	@override String get logs => 'Logs';
	@override String get maps => 'Karten';
	@override String get settings => 'Einstellungen';
}

// Path: home.panels
class _Translations$home$panels$de extends Translations$home$panels$en {
	_Translations$home$panels$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Betriebsliste';
	@override String get operationsDescription => 'Dein Funkbetrieb, der neueste zuerst.';
	@override String get version => 'Aktuelle Version';
	@override String get versionDescription => 'Das Ham2K-Logo, der Name dieser App und welcher Build läuft.';
}

// Path: home.logs
class _Translations$home$logs$de extends Translations$home$logs$en {
	_Translations$home$logs$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logs';
	@override String get titleFor => 'Logs für';
	@override String get emptyCallsigns => 'Noch keine QSOs geloggt';
	@override String emptyQsos({required Object call}) => 'Keine QSOs für ${call}';
	@override String get mapNoSelection => 'Wähle ein QSO, um es auf der Karte zu sehen';
	@override String get searchHint => 'Rufzeichen oder Name suchen';
	@override String get noSearchMatches => 'Keine QSOs passen zu deiner Suche';
	@override String get titleAll => 'Alle Logs';
	@override String get allCallsigns => 'Alle Rufzeichen';
	@override String get noOperation => 'Gehört zu keinem Betrieb';
	@override String get unsavedTitle => 'Ungespeicherte Änderungen';
	@override String get unsavedBody => 'Dieses QSO hat Änderungen, die du nicht gespeichert hast.';
	@override String get pendingDeleteBody => 'Dieses QSO ist zum Löschen markiert.';
	@override String get editGone => 'Nicht gespeichert: Dieses QSO ist nicht mehr in diesem Log.';
	@override String get discard => 'Verwerfen';
	@override late final _Translations$home$logs$columns$de columns = _Translations$home$logs$columns$de._(_root);
	@override late final _Translations$home$logs$panels$de panels = _Translations$home$logs$panels$de._(_root);
	@override late final _Translations$home$logs$import$de import = _Translations$home$logs$import$de._(_root);
}

// Path: chase.station
class _Translations$chase$station$de extends Translations$chase$station$en {
	_Translations$chase$station$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jagende Station';
	@override String get stationLabel => 'Station: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Kein Standort';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$de extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get today => 'heute';
	@override String get thisWeek => 'diese Woche';
	@override String get last14Days => 'in den letzten 14 Tagen';
	@override String get thisMonth => 'diesen Monat';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$de extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistik für heute';
	@override String get thisWeek => 'Statistik für diese Woche';
	@override String get last14Days => 'Statistik der letzten 14 Tage';
	@override String get thisMonth => 'Statistik für diesen Monat';
}

// Path: chase.period
class _Translations$chase$period$de extends Translations$chase$period$en {
	_Translations$chase$period$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get today => 'Heute';
	@override String get thisWeek => 'Diese Woche';
	@override String get last14Days => 'Letzte 14 Tage';
	@override String get thisMonth => 'Dieser Monat';
}

// Path: chase.goals
class _Translations$chase$goals$de extends Translations$chase$goals$en {
	_Translations$chase$goals$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Jagdziele';
	@override String remove({required Object name}) => '${name} nicht mehr jagen';
	@override String get extensionsTitle => 'Erweiterungen mit Jagd-Funktion';
}

// Path: chase.panels
class _Translations$chase$panels$de extends Translations$chase$panels$en {
	_Translations$chase$panels$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Logging-Steuerungen über den im Zeitraum gejagten QSOs.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Das gerade geloggte Rufzeichen oder die Statistik des Zeitraums.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Gespottete Stationen in der Luft, bereit zum Jagen.';
	@override String get map => 'Karte';
	@override String get mapDescription => 'Die QSOs des Zeitraums und die gerade geloggte Station.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$de extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Ungültiges Rufzeichen: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Ungültige Rufzeichen: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Bisher hat ${previous} gefunkt. ${typed} wird für neue Kontakte eingetragen.';
	@override String operatorNoneSoFar({required Object typed}) => 'Bisher ist kein Operator eingetragen. ${typed} wird für neue Kontakte eingetragen.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Dieser Betrieb hat bereits Kontakte von ${calls}. ${typed} wird nur für neue eingetragen.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${typed} auch als Operator des bereits geloggten Kontakts eintragen',
		other: '${typed} auch als Operator aller ${count} bereits geloggten Kontakte eintragen',
	);
	@override String get operatorSeveralStations => 'Bei mehreren Stationsrufzeichen werden getrennte Operatoren nicht unterstützt';
	@override String get contactsUnreadable => 'Die Kontakte dieses Betriebs konnten nicht gelesen werden, daher wird beim Ändern eines Rufzeichens hier keine Aktualisierung angeboten';
	@override String restampFailed({required Object error}) => 'Die bereits geloggten Kontakte konnten nicht aktualisiert werden, daher wurde nichts geändert: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} von ${planned} Kontakten wurden aktualisiert — die übrigen sind nicht mehr in diesem Betrieb';
}

// Path: operation.tabs
class _Translations$operation$tabs$de extends Translations$operation$tabs$en {
	_Translations$operation$tabs$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'KARTE';
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Uhr';
	@override String get weather => 'Wetter';
	@override String get website => 'Webseite';
	@override String get remoteScreen => 'Entfernter Bildschirm';
	@override String get solar => 'Solar';
	@override String get radio => 'Funkgerät';
}

// Path: operation.positions
class _Translations$operation$positions$de extends Translations$operation$positions$en {
	_Translations$operation$positions$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Noch teilen keine anderen Funkplätze diesen Betrieb.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Anderer Funkplatz';
	@override String get thisDevice => 'Unser Funkplatz';
	@override String get nameIn => ' in ';
	@override String get panelTitle => 'Funkplätze';
	@override String get panelDescription => 'Was jeder Funkplatz, der diesen Betrieb teilt, gerade loggt.';
}

// Path: operation.menu
class _Translations$operation$menu$de extends Translations$operation$menu$en {
	_Translations$operation$menu$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'RST-Felder anzeigen';
	@override String get showStateField => 'Staat-Feld anzeigen';
	@override String get showGridField => 'Grid-Feld anzeigen';
	@override String get showDeletedQsos => 'Gelöschte QSOs anzeigen';
	@override String get showDeletedOps => 'Gelöschten Betrieb anzeigen';
	@override String get showQsoNumbers => 'QSO-Nummern anzeigen';
	@override String get lookupAllQsos => 'Alle QSOs nachschlagen';
	@override String get loggingSettingsTitle => 'Logging-Einstellungen';
	@override String get mapSettingsTitle => 'Karteneinstellungen';
	@override String get actionsSection => 'Aktionen';
}

// Path: operation.layout
class _Translations$operation$layout$de extends Translations$operation$layout$en {
	_Translations$operation$layout$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Panel hinzufügen';
	@override String get availableSection => 'Verfügbare Panels';
	@override String panelSettings({required Object panel}) => 'Einstellungen für ${panel}';
	@override String get panelSettingsAction => 'Panel-Einstellungen';
	@override String get viewName => 'Betriebsansicht';
	@override String get viewOptions => 'Optionen für das Ansichtslayout';
	@override String get viewTitleBuiltIn => 'Diese Ansicht ist in die App eingebaut, ebenso ihr Name';
	@override String get resetOptions => 'Standard wiederherstellen';
	@override String get removePane => 'Entfernen';
	@override String resetPaneConfirm({required Object panel}) => '${panel} auf Standard zurücksetzen?';
	@override String get resetPaneConfirmBody => 'Titel, Kopfzeile und Größe werden auf Standard zurückgesetzt. Der Rest des Layouts bleibt unverändert.';
	@override String get resetViewConfirm => 'Diese Ansicht auf ihr Standardlayout zurücksetzen?';
	@override String get resetViewConfirmBody => 'Die Panels kehren zu ihrer Standardanordnung zurück, und die Optionen der Ansicht und aller Panels werden auf Standard zurückgesetzt.';
	@override String paneOptionsTitle({required Object panel}) => 'Layout-Einstellungen für ${panel}';
	@override String get paneTitle => 'Titel';
	@override String get paneShowHeader => 'Kopfzeile anzeigen';
	@override String get paneShowHeaderTabset => 'Immer sichtbar, solange dieser Bereich eine Gruppe teilt — über die Kopfzeile erreicht man die anderen';
	@override String get paneInherit => 'Wie die App';
	@override String get searchHint => 'Panels durchsuchen';
	@override String get noPanelsMatch => 'Kein Panel passt zu deiner Suche.';
	@override String get nothingToAdd => 'Diese Ansicht hat bereits alle möglichen Panels';
	@override String addPanel({required Object panel}) => '${panel} hinzufügen';
	@override String showPreview({required Object panel}) => 'Vorschau von ${panel}';
	@override String missingExtension({required Object name}) => 'Erweiterung „${name}“ fehlt';
	@override String get previewUnavailable => 'Das Vorschaubild dieses Panels konnte nicht angezeigt werden.';
	@override String get nestedPaneTitle => 'Mehr';
	@override String get editLayout => 'Layout bearbeiten';
	@override String get saveLayout => 'Layout speichern';
	@override String get revertLayout => 'Layout-Änderungen verwerfen';
	@override String get done => 'Fertig';
	@override String get layoutUnreadableTitle => 'Layout konnte nicht gelesen werden';
	@override String get layoutUnreadableBody => 'Dein gespeichertes Layout konnte nicht gelesen werden, daher wird stattdessen die Standardanordnung angezeigt. Dein Original wird erst überschrieben, wenn du dich entscheidest, diese zu behalten.';
	@override String get layoutUnreadableAction => 'Dieses Layout verwenden';
	@override String panelRenderFailed({required Object panel}) => '${panel} konnte nicht angezeigt werden';
	@override String get panelRenderRetry => 'Erneut versuchen';
	@override String get panelActionFailed => 'Diese Panel-Aktion ist fehlgeschlagen. Versuche es erneut.';
	@override late final _Translations$operation$layout$panels$de panels = _Translations$operation$layout$panels$de._(_root);
	@override String get htmlPanelUnsupported => 'Dieses Panel benötigt eine Web-Ansicht, die diese Plattform nicht bietet';
	@override String get htmlPanelUnsupportedOnWeb => 'Dieses Panel benötigt eine Sandbox, die die Web-Version nicht bieten kann';
}

// Path: operation.export
class _Translations$operation$export$de extends Translations$operation$export$en {
	_Translations$operation$export$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Betriebs-Exporte';
	@override String get syncedOperation => 'Betrieb ist synchronisiert';
	@override String get unsyncedOperation => 'Betrieb hat nicht synchronisierte Änderungen';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} QSO in diesem Betrieb',
		other: '${count} QSOs in diesem Betrieb',
	);
	@override String qsosSynced({required Object total}) => 'Alle ${total} QSOs sind synchronisiert';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} von ${total} QSOs warten auf Synchronisierung';
	@override String eventsSynced({required Object total}) => '${total} Ereignismarkierungen synchronisiert';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} von ${total} Ereignismarkierungen ausstehend';
	@override String get loading => 'Exportoptionen werden geladen…';
	@override String get noOptions => 'Keine Exportformate verfügbar (Erweiterungen starten noch?)';
	@override String get nothingLogged => 'Noch nichts zu exportieren — dieser Betrieb hat keine QSOs.';
	@override String get share => 'Teilen';
	@override String get nothingSelected => 'Nichts ausgewählt';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei speichern',
		other: '${count} Dateien speichern',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei teilen',
		other: '${count} Dateien teilen',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei exportieren',
		other: '${count} Dateien exportieren',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei herunterladen',
		other: '${count} Dateien herunterladen',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kombinierte Datei speichern',
		other: '${count} kombinierte Dateien speichern',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kombinierte Datei teilen',
		other: '${count} kombinierte Dateien teilen',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kombinierte Datei exportieren',
		other: '${count} kombinierte Dateien exportieren',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kombinierte Datei herunterladen',
		other: '${count} kombinierte Dateien herunterladen',
	);
	@override String saveOne({required Object name}) => '${name} speichern';
	@override String shareOne({required Object name}) => '${name} teilen';
	@override String exportOne({required Object name}) => '${name} exportieren';
	@override String downloadOne({required Object name}) => '${name} herunterladen';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei ablegen',
		other: '${count} Dateien ablegen',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} kombinierte Datei ablegen',
		other: '${count} kombinierte Dateien ablegen',
	);
	@override String get settingsButton => 'Export-Einstellungen';
	@override String get settingsTitle => 'Export-Einstellungen';
	@override late final _Translations$operation$export$compactFileNames$de compactFileNames = _Translations$operation$export$compactFileNames$de._(_root);
	@override late final _Translations$operation$export$includePrivateData$de includePrivateData = _Translations$operation$export$includePrivateData$de._(_root);
	@override String get resultTitle => 'Export abgeschlossen';
	@override String get resultFailedTitle => 'Export fehlgeschlagen';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei nach ${path} exportiert',
		other: '${count} Dateien nach ${path} exportiert',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei exportiert: ${path}',
		other: '${count} Dateien exportiert: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei geteilt',
		other: '${count} Dateien geteilt',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei heruntergeladen',
		other: '${count} Dateien heruntergeladen',
	);
	@override String exportFailed({required Object error}) => 'Export fehlgeschlagen: ${error}';
	@override late final _Translations$operation$export$stash$de stash = _Translations$operation$export$stash$de._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$de extends Translations$operation$spots$en {
	_Translations$operation$spots$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Keine Spots passen zu deinen Filtern';
	@override String error({required Object error}) => 'Spots konnten nicht geladen werden: ${error}';
	@override String get unknownBand => 'Andere';
	@override String get auto => 'Automatisch';
	@override String autoValue({required Object value}) => 'Automatisch (Derzeit ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Alle';
	@override String get allBands => 'Alle Bänder';
	@override String get allModes => 'Alle Modi';
	@override String get phoneAndCw => 'Phone & CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Spot',
		other: '${count} Spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => '${count} von ${total} Spots werden angezeigt';
	@override String ageMinutes({required Object minutes}) => '${minutes} Minuten';
	@override String get callsOfNote => 'Bemerkenswerte Rufzeichen';
	@override String get yourSpots => 'Deine Spots';
	@override String get allSpots => 'Alle Spots';
	@override late final _Translations$operation$spots$continents$de continents = _Translations$operation$spots$continents$de._(_root);
	@override late final _Translations$operation$spots$filters$de filters = _Translations$operation$spots$filters$de._(_root);
	@override String get unavailableTitle => 'Spots nicht verfügbar';
	@override String unavailableText({required Object sources}) => '${sources} hat nicht reagiert.';
	@override String get failedTitle => 'Fehler der Spot-Quelle';
	@override String failedText({required Object sources}) => '${sources} meldete einen Fehler.';
	@override String get slideLogIt => 'Loggen';
	@override String get slideIgnore => 'Ignorieren';
	@override String get slideRestore => 'Wiederherstellen';
	@override late final _Translations$operation$spots$logConflict$de logConflict = _Translations$operation$spots$logConflict$de._(_root);
}

// Path: operation.import
class _Translations$operation$import$de extends Translations$operation$import$en {
	_Translations$operation$import$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Daten in Betrieb importieren';
	@override String get importAdifAction => 'QSOs aus ADIF importieren';
	@override String get settingsButton => 'Empfangseinstellungen';
	@override String get settingsTitle => 'Auf andere Apps lauschen';
	@override String get protocolAddressLabel => 'Adresse';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Gib einen Port zwischen 1 und 65535 ein';
	@override String get protocolAddressInvalid => 'Gib eine gültige IP-Adresse ein (z. B. 127.0.0.1 oder 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Empfange Daten';
	@override String get protocolStatusNoData => 'In letzter Zeit keine Daten empfangen';
	@override String protocolBindError({required Object error}) => 'Empfang konnte nicht gestartet werden: ${error}';
	@override String captureFailed({required Object error}) => 'Eingehende QSOs konnten nicht gespeichert werden, neuer Versuch läuft: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Beliebig (Broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Reiter Broadcast Data → "Enable Broadcasts" für Contact-Info aktivieren. IP-Adresse auf 127.0.0.1 setzen, wenn es auf diesem Computer läuft, oder auf 255.255.255.255, um im aktuellen lokalen Netzwerk zu senden.';
	@override String get helpWsjtxSetup => 'File → Settings → Reiter Reporting → Abschnitt UDP Server → "Accept UDP requests" aktivieren. UDP Server auf 127.0.0.1 setzen, wenn es auf diesem Computer läuft, oder auf eine Multicast-Adresse wie 239.239.0.2, und dieselbe Adresse oben in der Konfiguration dieser App verwenden.';
	@override String get listenTitle => 'Auf QSOs von anderen Apps lauschen';
	@override String get listenDescriptionOnN1mm => 'Lausche auf N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Lausche auf WSJT-X';
	@override String get listenDescriptionOnBoth => 'Lausche auf N1MM+ und WSJT-X';
	@override String get listenDescriptionOff => 'Aus';
	@override String get addToOperationTitle => 'Zu diesem Betrieb hinzufügen';
	@override String get addToOperationDescriptionOn => 'Empfangene QSOs werden bei Eingang zu diesem Betrieb hinzugefügt';
	@override String get addToOperationDescriptionOff => 'Empfangene QSOs werden zurückgehalten, bis du dies einschaltest';
	@override String get pendingSectionTitle => 'Empfangene QSOs';
	@override String get pendingEmpty => 'Noch nichts empfangen';
	@override String stationMismatch({required Object call}) => 'Als ${call} geloggt, nicht als Station dieses Betriebs';
	@override String get discardAction => 'Verwerfen';
	@override String get gapDialogTitle => 'Frühere Empfänge einbeziehen?';
	@override String gapDialogBody({required Object count}) => '${count} weitere QSOs wurden früher empfangen, vor einer Lücke in den Daten. Auch diese einbeziehen?';
	@override String get gapDialogRecentOnly => 'Nur die neuen';
	@override String gapDialogIncludeAll({required Object count}) => 'Alle ${count} einbeziehen';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$de extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get link => 'Probleme?';
	@override String get title => 'Problem mit Umriss melden';
	@override String get reference => 'Welcher Umriss';
	@override String get severity => 'Wie schlimm ist es?';
	@override String get minor => 'Kleinigkeit';
	@override String get major => 'Großes Problem';
	@override String get explanation => 'Was stimmt nicht?';
	@override String get explanationHint => 'Was der Umriss falsch darstellt, und wo';
	@override String get send => 'Senden';
	@override String get sending => 'Deine Meldung wird gesendet — danke';
	@override String get copy => 'Meldung kopieren';
	@override String get notSent => 'Meldung konnte nicht gesendet werden';
	@override String get copied => 'Meldung kopiert';
	@override String get notCopied => 'Meldung konnte nicht kopiert werden';
}

// Path: map.postcard
class _Translations$map$postcard$de extends Translations$map$postcard$en {
	_Translations$map$postcard$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get button => 'Betriebs-Postkarte';
	@override String title({required Object title}) => 'Postkarte für ${title}';
	@override String get portrait => 'Hochformat';
	@override String get landscape => 'Querformat';
	@override String get square => 'Quadratisch';
	@override String get save => 'Speichern…';
	@override String get download => 'Herunterladen';
	@override String get share => 'Teilen';
	@override String get copy => 'Kopieren';
	@override String get copied => 'In die Zwischenablage kopiert';
	@override String saved({required Object path}) => 'Gespeichert unter ${path}';
	@override String downloaded({required Object name}) => '${name} heruntergeladen';
	@override String savedMany({required Object count, required Object path}) => '${count} Bilder unter ${path} gespeichert';
	@override String savedFiles({required Object names}) => '${names} gespeichert';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} war bereits gespeichert';
	@override String downloadedMany({required Object count}) => '${count} Bilder werden heruntergeladen — erlaube sie, falls der Browser fragt';
	@override String get mapLeftOut => 'Die Karte wurde nicht geladen und daher weggelassen';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — die Karte wurde nicht geladen und daher weggelassen';
	@override String continued({required Object title}) => '${title} (Fortsetzung)';
	@override String get previousPage => 'Vorherige Seite';
	@override String get nextPage => 'Nächste Seite';
	@override String pageOf({required Object page, required Object count}) => 'Seite ${page} von ${count}';
	@override String get sections => 'Zusammenfassungsabschnitte';
	@override String get sectionDays => 'Jeder Tag';
	@override String get reset => 'Zurücksetzen';
	@override String failed({required Object error}) => 'Postkarte konnte nicht erstellt werden: ${error}';
	@override String get mapNotReady => 'Die Karte wurde nicht fertig geladen. Prüfe die Verbindung und versuche es erneut.';
	@override String saveFailed({required Object error}) => 'Postkarte konnte nicht gespeichert werden: ${error}';
	@override String get copyFailed => 'Die Zwischenablage hat das Bild nicht übernommen. Versuche es erneut.';
	@override String get shareFailed => 'Postkarte konnte nicht geteilt werden. Versuche es erneut.';
	@override String get fileName => 'postkarte';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$de extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Noch keine QSOs... Lass uns loslegen!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} in ${time}';
	@override String sinceLast({required Object time}) => '${time} seit dem letzten';
	@override String ratePer10({required Object rate}) => '${rate} Q/h für die letzten 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h für die letzten 100';
	@override String distanceTo({required Object distance}) => '${distance} nach';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) nach';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) nach';
	@override String distanceAway({required Object distance}) => '${distance} entfernt';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) entfernt';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) entfernt';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplikat!';
	@override String get noticeNewBand => 'Neues Band';
	@override String get noticeNewMode => 'Neuer Modus';
	@override String get noticeNewDXCC => 'Neues DXCC';
	@override String get noticeNewState => 'Neuer Staat';
	@override String get noticeNewProvince => 'Neue Provinz';
	@override String get noticeNewDay => 'Neuer Tag';
	@override String get noticeNewRef => 'Neue Ref';
	@override String get noticeNewMult => 'Neuer Multi';
	@override String get noticeNewZone => 'Neue Zone';
	@override String get noticeInvalidMode => 'Falscher Modus';
	@override String get noticeInvalidBand => 'Falsches Band';
	@override String get noticeInvalidCategory => 'Nicht arbeitbar';
	@override String get noticeWorkedBefore => 'Schon gearbeitet';
	@override String get noticeNewPark => 'Neuer Park';
	@override String get noticeNewSection => 'Neue Sektion';
	@override String get noticeBonusStation => 'Bonus-Station!';
	@override String get noticeMissingExchange => 'Kein Austausch';
	@override String get noticeInvalidExchange => 'Falscher Austausch';
	@override String get noticeUnknownEvent => 'Unbekanntes Event';
	@override String get noticeOurGrid => 'Unser Grid setzen';
	@override String get noticeRareCounty => 'Seltener County!';
	@override String get noticeOurLocation => 'Unseren County setzen';
	@override String get noticeShortGrid => 'Grid zu kurz';
}

// Path: callInfo.history
class _Translations$callInfo$history$de extends Translations$callInfo$history$en {
	_Translations$callInfo$history$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} in den letzten 7 Tagen';
	@override String today({required Object n}) => '${n} heute';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class _Translations$settings$theme$de extends Translations$settings$theme$en {
	_Translations$settings$theme$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Design';
	@override String get system => 'Systemeinstellungen folgen';
	@override String get light => 'Hell';
	@override String get dark => 'Dunkel';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$de extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get system => 'Folgt den Systemeinstellungen';
	@override String get light => 'Immer im Hellmodus';
	@override String get dark => 'Immer im Dunkelmodus';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$de extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Kleinste--';
	@override String get smallestMinus => 'Kleinste-';
	@override String get smallest => 'Kleinste';
	@override String get smaller => 'Kleiner';
	@override String get normal => 'Normal';
	@override String get larger => 'Größer';
	@override String get largest => 'Größte';
	@override String get largestPlus => 'Größte+';
	@override String get largestPlusPlus => 'Größte++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$de extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gerät wach halten';
	@override String get descriptionOn => 'Bleibt wach, solange du in der Logging-Ansicht bist oder eine Synchronisierung läuft';
	@override String get descriptionOff => 'Ruhezustand wie üblich';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$de extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatisch';
	@override String get densest => 'Am dichtesten';
	@override String get dense => 'Dicht';
	@override String get normal => 'Normal';
	@override String get sparse => 'Locker';
	@override String get sparsest => 'Am lockersten';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$de extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometer';
	@override String get miles => 'Meilen';
}

// Path: settings.logging
class _Translations$settings$logging$de extends Translations$settings$logging$en {
	_Translations$settings$logging$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logging';
	@override late final _Translations$settings$logging$leftieMode$de leftieMode = _Translations$settings$logging$leftieMode$de._(_root);
	@override late final _Translations$settings$logging$countryFlags$de countryFlags = _Translations$settings$logging$countryFlags$de._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$de countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$de._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$de suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$de._(_root);
	@override late final _Translations$settings$logging$showBearing$de showBearing = _Translations$settings$logging$showBearing$de._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$de showReverseBearing = _Translations$settings$logging$showReverseBearing$de._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$de switchSentRcvd = _Translations$settings$logging$switchSentRcvd$de._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$de jumpAfterRST = _Translations$settings$logging$jumpAfterRST$de._(_root);
	@override late final _Translations$settings$logging$defaultReport$de defaultReport = _Translations$settings$logging$defaultReport$de._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$de defaultReportCW = _Translations$settings$logging$defaultReportCW$de._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$de defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$de._(_root);
	@override late final _Translations$settings$logging$numbersRow$de numbersRow = _Translations$settings$logging$numbersRow$de._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$de numbersRowExtra = _Translations$settings$logging$numbersRowExtra$de._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$de numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$de._(_root);
	@override String get bands => 'Bevorzugte Bänder';
	@override String get modes => 'Bevorzugte Modi';
}

// Path: settings.catServer
class _Translations$settings$catServer$de extends Translations$settings$catServer$en {
	_Translations$settings$catServer$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-Server';
	@override String get description => 'Anderen Apps (WSJT-X, Logprogramme usw.) erlauben, das Funkgerät über Ham2K Logger zu steuern.';
	@override String get protocol => 'Protokoll';
	@override late final _Translations$settings$catServer$protocolOpts$de protocolOpts = _Translations$settings$catServer$protocolOpts$de._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Offener Zugriff';
	@override String get openAccessOn => 'Jeder Computer im lokalen Netzwerk kann sich verbinden.';
	@override String get openAccessOff => 'Nur Apps auf diesem Computer können sich verbinden.';
	@override String get off => 'Aus.';
	@override String starting({required Object protocol}) => '${protocol}, startet…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} auf Port ${port}. Verbundene Clients: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} auf Port ${port}, aber kein Funkgerät als Haupt-VFO verbunden.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} kann nicht auf Port ${port} lauschen: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} kann nicht auf Port ${port} lauschen: ein anderes Programm nutzt ihn, oft ${protocol} selbst. Schließe dieses Programm oder wähle einen anderen Port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} kann nicht auf Port ${port} lauschen: dieser Computer erlaubt es nicht. Wähle einen Port über 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} lauscht nicht mehr auf Port ${port}. Neuer Versuch…';
}

// Path: settings.radio
class _Translations$settings$radio$de extends Translations$settings$radio$en {
	_Translations$settings$radio$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT-Steuerung';
	@override String get loggingAndCat => 'Logging & CAT';
	@override String get tuningSection => 'Abstimmung';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Dienste';
	@override String get stationConfigurationSection => 'Stationskonfiguration';
	@override String get moreSettings => 'Weitere Einstellungen zur Stationskonfiguration';
	@override late final _Translations$settings$radio$units$de units = _Translations$settings$radio$units$de._(_root);
	@override late final _Translations$settings$radio$pttKey$de pttKey = _Translations$settings$radio$pttKey$de._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$de smartVfoSnap = _Translations$settings$radio$smartVfoSnap$de._(_root);
	@override late final _Translations$settings$radio$snapDebounce$de snapDebounce = _Translations$settings$radio$snapDebounce$de._(_root);
	@override late final _Translations$settings$radio$snapLongMove$de snapLongMove = _Translations$settings$radio$snapLongMove$de._(_root);
	@override late final _Translations$settings$radio$snapMinMove$de snapMinMove = _Translations$settings$radio$snapMinMove$de._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$de snapMinSpeed = _Translations$settings$radio$snapMinSpeed$de._(_root);
	@override late final _Translations$settings$radio$enterSends$de enterSends = _Translations$settings$radio$enterSends$de._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$de keyerSpeed = _Translations$settings$radio$keyerSpeed$de._(_root);
	@override late final _Translations$settings$radio$cwMessages$de cwMessages = _Translations$settings$radio$cwMessages$de._(_root);
	@override late final _Translations$settings$radio$voiceMessages$de voiceMessages = _Translations$settings$radio$voiceMessages$de._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$de avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$de._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$de zeroBeatRange = _Translations$settings$radio$zeroBeatRange$de._(_root);
}

// Path: settings.help
class _Translations$settings$help$de extends Translations$settings$help$en {
	_Translations$settings$help$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hilfe & Ressourcen';
	@override String get description => 'Community und Support';
	@override String get forums => 'Ham2K Foren';
	@override String get forumsDescription => 'Hilfe finden, Feedback geben, Ideen diskutieren…';
	@override String get chat => 'Ham2K Chat';
	@override String get chatDescription => 'Der Discord-Server für unsere Online-Community';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videos und Live-Streams';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Weil man nie genug Fotos haben kann…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Folge uns für Neuigkeiten und Updates';
	@override String get contact => 'Kontaktiere uns';
	@override String get contactDescription => 'help@ham2k.com — aber versuche es zuerst in den Foren oder im Chat!';
}

// Path: settings.exports
class _Translations$settings$exports$de extends Translations$settings$exports$en {
	_Translations$settings$exports$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporte';
}

// Path: settings.map
class _Translations$settings$map$de extends Translations$settings$map$en {
	_Translations$settings$map$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Karten';
	@override late final _Translations$settings$map$style$de style = _Translations$settings$map$style$de._(_root);
	@override late final _Translations$settings$map$styleOpts$de styleOpts = _Translations$settings$map$styleOpts$de._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$de extends Translations$settings$privacy$en {
	_Translations$settings$privacy$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Datenschutz';
	@override late final _Translations$settings$privacy$shareAppData$de shareAppData = _Translations$settings$privacy$shareAppData$de._(_root);
	@override late final _Translations$settings$privacy$shareOpData$de shareOpData = _Translations$settings$privacy$shareOpData$de._(_root);
	@override String get privacyPolicy => 'Datenschutzerklärung';
	@override String get termsOfService => 'Nutzungsbedingungen';
}

// Path: settings.sync
class _Translations$settings$sync$de extends Translations$settings$sync$en {
	_Translations$settings$sync$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cloud-Sync';
	@override String get moreSettings => 'Weitere Sync-Einstellungen';
	@override String get enable => 'Sync aktivieren';
	@override String get deviceKey => 'Geräteschlüssel';
}

// Path: settings.peers
class _Translations$settings$peers$de extends Translations$settings$peers$en {
	_Translations$settings$peers$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partnergeräte';
	@override String get enable => 'Mit anderen Geräten verbinden';
	@override String get enableDescription => 'Teilen von Betrieb, Logging, CAT und GPS mit anderen Geräten im lokalen Netzwerk erlauben';
	@override String get bleEnable => 'Über Bluetooth verbinden';
	@override String get bleDescription => 'Bluetooth LE verwenden, um auch ohne lokales Netzwerk zu verbinden';
	@override String get thisDevice => 'Dieses Gerät';
	@override String get deviceName => 'Name';
	@override String get deviceNameHint => 'So sehen andere Geräte dieses Gerät';
	@override String get pairedDevices => 'Verknüpfte Geräte';
	@override String get noPairedDevices => 'Noch keine Geräte verknüpft. Schalte dies auf einem anderen Gerät in diesem Netzwerk ein, um sie zu verknüpfen.';
	@override String deviceListProblem({required Object error}) => 'Deine verknüpften Geräte können nicht gelesen werden: ${error}';
	@override String get nearby => 'In der Nähe';
	@override String get connected => 'Verbunden';
	@override String get viaBluetooth => 'über Bluetooth';
	@override String get connecting => 'Verbinde…';
	@override String get syncing => 'Synchronisiere…';
	@override String get waitingForThem => 'Warte auf das andere Gerät';
	@override String get notConnected => 'Nicht verbunden';
	@override String get wantsToPair => 'möchte diesen Betrieb teilen';
	@override String get allow => 'Erlauben';
	@override String get link => 'Verknüpfen';
	@override String get reject => 'Ablehnen';
	@override String get forget => 'Vergessen';
	@override String forgetTitle({required Object name}) => '${name} vergessen?';
	@override String get forgetBody => 'Die Synchronisierung mit diesem Gerät wird beendet. Du kannst es später wieder erlauben, und bereits geloggte Kontakte bleiben erhalten.';
	@override String pairTitle({required Object name}) => 'Mit ${name} verknüpfen';
	@override String get pairBody => 'Dieses Gerät ist in deinem lokalen Netzwerk und möchte sich verbinden.';
	@override String get pairBodyBle => 'Dieses Gerät ist in der Nähe und möchte sich über Bluetooth LE verbinden.';
	@override String get pairIdLabel => 'Geräte-ID';
	@override String get pairWarning => 'Verknüpfe nur Geräte, die du kennst. Jedes Gerät in diesem Netzwerk kann eine Anfrage senden.';
	@override String get pairWarningBle => 'Verknüpfe nur Geräte, die du kennst. Jedes Gerät in der Nähe kann eine Anfrage senden.';
	@override String problem({required Object error}) => 'Lokales Netzwerk nicht erreichbar: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Verbunden mit ${device}';
	@override String statusLost({required Object device}) => 'Verbindung zu ${device} verloren';
	@override String statusPerma({required Object connected, required Object linked}) => 'Partnergeräte: ${connected} von ${linked} verbunden';
	@override String get screenEnable => 'Bildschirme und Fenster teilen';
	@override String get screenDescription => 'Anderen Geräten erlauben, Bildschirme oder Fenster dieses Computers anzuzeigen';
	@override String get screenSources => 'Bildschirme und Fenster';
	@override String get screenRefresh => 'Liste aktualisieren';
	@override String get screenUnsupportedPlatform => 'Dieses Gerät kann seinen Bildschirm nicht teilen. macOS kann das; jedes Gerät kann einen von einem anderen geteilten Bildschirm anzeigen.';
	@override String get screenUnsupportedVersion => 'Bildschirmfreigabe erfordert macOS 12.3 oder neuer. Dieses Gerät kann aber einen von einem anderen geteilten Bildschirm anzeigen.';
	@override String get screenNeedsPermission => 'macOS braucht deine Erlaubnis zur Bildschirmaufnahme, bevor diese App einen Bildschirm teilen kann.';
	@override String get screenGrantPermission => 'Um Erlaubnis bitten';
	@override String get screenRelaunchAfterGranting => 'Erlaube es in den Systemeinstellungen unter Datenschutz & Sicherheit → Bildschirmaufnahme, beende dann diese App und öffne sie neu — macOS teilt einer App die Änderung erst beim nächsten Start mit.';
	@override String screenProblem({required Object error}) => 'Bildschirmfreigabe: ${error}';
	@override String get screenChooseTitle => 'Auswählen, was geteilt wird';
	@override String get screenChooseButton => 'Auswählen, was geteilt wird…';
	@override String get screenTabScreens => 'Bildschirme';
	@override String get screenTabApps => 'Apps';
	@override String get screenTabWindows => 'Fenster';
	@override String get screenTabEmpty => 'Nichts dieser Art gefunden.';
	@override String get screenSharedSummaryNone => 'Noch nichts ausgewählt.';
	@override String get screenThisDevice => 'Dieses Gerät';
	@override String screenSharedTo({required Object devices}) => 'Angezeigt auf ${devices}';
	@override String get screenSharedToNobody => 'Wird nicht angezeigt';
	@override String screenStopSharing({required Object name}) => 'Teilen von ${name} beenden';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$de extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Sync-Konfiguration';
	@override String get enableTitle => 'Mit Ham2K Log Filer synchronisieren';
	@override String get enabledDescription => 'Dein Log wird gesichert und zwischen Geräten synchronisiert';
	@override String get disabledDescription => 'Aus — bleibt nur auf diesem Gerät';
	@override String get syncing => 'Synchronisiere';
	@override String get account => 'Konto';
	@override String get refresh => 'Aktualisieren';
	@override String get switchAccounts => 'Konto wechseln';
	@override String get switchAccountsDescription => 'Dieses Gerät per QR-Code oder E-Mail mit einem anderen Konto verknüpfen';
	@override String get connectionRequests => 'Verbindungsanfragen';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Ein Gerät wartet darauf, diesem Konto beizutreten',
		other: '${n} Geräte warten darauf, diesem Konto beizutreten',
	);
	@override String get accountEmailTitle => 'Konto-E-Mail';
	@override String accountEmailSent({required Object email}) => 'Bestätigung an ${email} gesendet. Öffne den Link dort, um die Änderung abzuschließen.';
	@override String get resendConfirmation => 'Bestätigungs-E-Mail erneut senden';
	@override String resendConfirmationDescription({required Object email}) => 'Warte auf ${email}';
	@override String accountEmailResent({required Object email}) => 'Erneut an ${email} gesendet.';
	@override String get deviceLinked => 'Dieses Gerät ist jetzt mit diesem Konto verknüpft.';
	@override String get checking => 'Prüfe…';
	@override String get notLinked => 'Noch nicht verknüpft';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Lokale Daten ersetzen?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${n} Betrieb',
		other: '${n} Betriebe',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Synchronisierte Daten';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Dieses Gerät: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Warten auf Upload: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Dieses Gerät: wird geprüft…';
	@override String get countsServerChecking => 'Server: wird geprüft…';
	@override String get countsServerUnavailable => 'Server: nicht verfügbar';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Dies sichert und entfernt ${operations} und ${qsos} von diesem Gerät und lädt stattdessen die Daten des Kontos herunter. Die Sicherung bleibt in der Datenbank dieses Geräts.';
	@override String get replace => 'Ersetzen';
	@override String get pendingBannerTitle => 'Neues Ham2K-Log-Filer-Konto erkannt';
	@override String get pendingBannerBody => 'Behalte den vorhandenen Betrieb und die QSOs dieses Geräts und führe sie mit dem Konto zusammen, oder ersetze sie durch die Daten des Kontos (in beiden Fällen bleibt eine Sicherung auf diesem Gerät).';
	@override String get combine => 'Kombinieren';
	@override String get authIssueTitle => 'Sync kann sich nicht verbinden';
	@override String get authIssueText => 'Ham2K Log Filer lehnt dieses Gerät wiederholt ab. Prüfe dein Rufzeichen in den Sync-Einstellungen.';
	@override String get openSettings => 'Sync-Einstellungen öffnen';
}

// Path: settings.accounts
class _Translations$settings$accounts$de extends Translations$settings$accounts$en {
	_Translations$settings$accounts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Konten, Dienste & Datenquellen';
	@override String get none => 'Keine aktiven Erweiterungen mit Konten';
	@override String get notConfigured => 'Nicht konfiguriert';
	@override String get connected => 'Verbunden';
	@override String get cancelLogin => 'Anmeldung abbrechen';
	@override String get openInBrowser => 'Im Browser öffnen';
	@override String loggedInAs({required Object identity}) => 'Angemeldet als ${identity}';
	@override String get pressSaveToKeep => 'Drücke Speichern, damit dieses Konto verbunden bleibt.';
	@override String connectedTo({required Object label}) => 'Verbunden mit ${label}';
	@override String get connect => 'Verbinden';
	@override String get disconnect => 'Trennen';
	@override String get connectedAs => 'Verbunden als';
	@override String get test => 'Testen';
	@override String saveFailed({required Object error}) => 'Speichern fehlgeschlagen: ${error}';
	@override String loginFailed({required Object error}) => 'Anmeldung fehlgeschlagen: ${error}';
	@override String get lookupFailed => 'Konten sind gerade nicht verfügbar — versuche es gleich noch einmal';
	@override String get browserLoginTitle => 'Schließe die Anmeldung in deinem Webbrowser ab';
	@override String browserLoginSteps({required Object prefix}) => 'Wenn du fertig bist, versucht der Browser einen Link zu öffnen, der mit „${prefix}“ beginnt. Auf deinem Desktop ist wahrscheinlich nichts registriert, um ihn zu öffnen, also kopiere diesen Link (aus der Adressleiste oder von der Fehlerseite, die der Browser anzeigt) und füge ihn hier ein.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger konnte deinen Browser nicht öffnen. Kopiere den Anmeldelink unten und öffne ihn selbst, kopiere dann den Link, zu dem du weitergeleitet wirst (er beginnt mit „${prefix}“), und füge ihn hier ein.';
	@override String get copyLoginLink => 'Anmeldelink kopieren';
	@override String get pastedLinkLabel => 'Link hier einfügen';
	@override String get finishLogin => 'Anmeldung abschließen';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Das ist nicht der Anmeldelink — er sollte mit „${prefix}“ beginnen.';
	@override String get pastedLinkWrongLogin => 'Dieser Link gehört zu einem anderen Anmeldeversuch. Schließe diese Seite und verbinde erneut.';
	@override String get pastedLinkNoCode => 'Dieser Link enthält keinen Anmeldecode. Schließe zuerst die Anmeldung ab und kopiere dann den Link, zu dem du weitergeleitet wirst.';
	@override String get pastedLinkMalformed => 'Dieser Link scheint abgeschnitten. Kopiere ihn vollständig und füge ihn erneut ein.';
	@override String get relayLoginWaiting => 'Warte, bis du die Anmeldung abgeschlossen hast — danach geht es automatisch weiter.';
	@override String get loginNoResponse => 'Dieses Gerät hat noch keine Rückmeldung von der Anmeldung erhalten. Wenn du im Browser schon fertig bist, brich ab und verbinde erneut.';
	@override String get relayLoginNotOpened => 'Ham2K Logger konnte deinen Browser nicht automatisch öffnen. Öffne die Anmeldeseite mit dem Button unten selbst.';
	@override String get relayLoginUnavailable => 'Der für diese Anmeldung nötige Sync-Server war nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';
	@override String get loginIncompleteResponse => 'Dieser Anmeldeversuch wurde nicht korrekt abgeschlossen. Bitte verbinde erneut.';
	@override String get noKeyringTitle => 'Konto-Anmeldungen können nicht gespeichert werden';
	@override String get noKeyringText => 'Ham2K Logger erreicht keinen Schlüsselbund-Dienst auf diesem Computer, daher können Konto-Anmeldungen weder gespeichert noch gelesen werden — das Verbinden eines Kontos schlägt fehl, bis das behoben ist. Installiere und starte **gnome-keyring**, **KWallet** oder **KeePassXC** oder entsperre deinen vorhandenen Schlüsselbund und starte dann neu. Logging, Exporte und Datendateien sind nicht betroffen; die Log-Synchronisierung bleibt solange aus.';
	@override String get noKeyringInline => 'Anmeldungen können nicht gespeichert werden: der Schlüsselbund dieses Computers ist nicht erreichbar. Installiere und starte gnome-keyring, KWallet oder KeePassXC oder entsperre deinen vorhandenen.';
	@override String get noSecureStorageInline => 'Anmeldungen können nicht gespeichert werden: der sichere Speicher dieses Computers ist nicht erreichbar.';
}

// Path: settings.station
class _Translations$settings$station$de extends Translations$settings$station$en {
	_Translations$settings$station$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Stationskonfiguration & CAT-Steuerung';
	@override String get none => 'Keine Geräte konfiguriert';
	@override String get add => 'Hinzufügen';
	@override String get addTitle => 'Gerät hinzufügen';
	@override String get searchHint => 'Geräte durchsuchen';
	@override String get noMatches => 'Kein passendes Gerät';
	@override String get detectedEquipment => 'Erkannte Geräte';
	@override String discoveryUnavailable({required Object error}) => 'Kann nicht nach Funkgeräten lauschen: ${error}';
	@override String get edit => 'Gerät bearbeiten';
	@override String get name => 'Name';
	@override String get nameDescription => 'Wie du es nennst — „Linkes Funkgerät“. Optional.';
	@override String get transport => 'Verbindung';
	@override String get host => 'Adresse';
	@override String get hostDescription => 'Hostname oder IP-Adresse des Funkgeräts in deinem Netzwerk.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Eine Adresse ist erforderlich';
	@override String get portInvalid => 'Der Port muss zwischen 1 und 65535 liegen';
	@override String get connect => 'Verbinden';
	@override String get disconnect => 'Trennen';
	@override String get remove => 'Entfernen';
	@override String removeTitle({required Object name}) => '${name} entfernen?';
	@override String get removeMessage => 'Es wird nur aus der App entfernt. Die Einstellungen des Geräts bleiben unverändert.';
	@override String unknownType({required Object typeKey}) => 'Unbekannter Gerätetyp „${typeKey}“';
	@override String get report => 'Melden';
	@override String get reportTitle => 'Dieses Funkgerät melden';
	@override String get reportIntro => 'Sag uns, welches Funkgerät das wirklich ist und wie es lief. Deine Meldung wird zu einer Karte, die das Ham2K-Team liest, und was du darüber schreibst, wie du es zum Laufen gebracht hast, kann dem nächsten Operator mit demselben Gerät helfen.';
	@override String get reportManufacturer => 'Hersteller';
	@override String get reportManufacturerDescription => 'Wer es herstellt — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Ein Hersteller ist erforderlich';
	@override String get reportModel => 'Modell';
	@override String get reportModelDescription => 'Das Modell, wie das Funkgerät selbst es nennt — „IC-7300“, „FT-991A“.';
	@override String get reportModelRequired => 'Ein Modell ist erforderlich';
	@override String get reportOutcome => 'Wie lief es?';
	@override String get reportOutcomeWorks => 'Hat gut funktioniert';
	@override String get reportOutcomeIssues => 'Hat funktioniert, mit Problemen';
	@override String get reportOutcomeFails => 'Hat gar nicht funktioniert';
	@override String get reportOutcomeRequired => 'Bitte sag uns, wie es lief';
	@override String get reportComments => 'Kommentare';
	@override String get reportCommentsPlaceholder => 'Was funktioniert hat, was nicht, alles, was dich überrascht hat.';
	@override String get reportHints => 'Tipps zur Fehlerbehebung';
	@override String get reportHintsPlaceholder => 'Möchtest du anderen Nutzern Tipps zur Fehlerbehebung geben?';
	@override String get reportSend => 'Meldung senden';
	@override String get reportSending => 'Deine Meldung wird gesendet…';
	@override String reportSent({required Object ref}) => 'Danke — deine Meldung wurde als ${ref} erfasst.';
	@override String get reportSentNoRef => 'Danke — deine Meldung wurde gesendet.';
	@override String reportFailed({required Object error}) => 'Die Meldung wurde nicht gesendet: ${error}';
	@override String get troubleshootingNotes => 'Hinweise zur Fehlerbehebung';
	@override String get mainVfo => 'Haupt-VFO';
	@override String get useAsMainVfo => 'Als Haupt-VFO verwenden';
	@override String get serialPort => 'Serieller Port';
	@override String get serialPortDescription => 'Der Port, an dem die CAT-Schnittstelle des Funkgeräts erscheint.';
	@override String get serialPortNone => 'Keine seriellen Ports gefunden';
	@override String get serialPortRequired => 'Wähle einen seriellen Port';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'Port ${n} von ${total}';
	@override String get serialPortSuggested => 'empfohlen';
	@override String get serialPortJustNow => 'Kürzlich verbunden';
	@override String get serialDeviceRequest => 'USB-Gerät hinzufügen…';
	@override String get baudRate => 'Geschwindigkeit (Baud)';
	@override String get baudRateDescription => 'Muss mit dem CAT-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll zurück und keinen Fehler.';
	@override String get serialRtsHigh => 'RTS hoch halten';
	@override String get serialRtsHighDescription => 'Nur für Funkgeräte, die vor einer Antwort auf RTS warten, z. B. ein Yaesu mit eingeschaltetem CAT RTS. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist RTS die PTT, und Hochhalten bedeutet Senden.';
	@override String get serialDtrHigh => 'DTR hoch halten';
	@override String get serialDtrHighDescription => 'Nur für CAT-Schnittstellen, die ihren Strom aus DTR beziehen, z. B. manche RS-232-Kabel für den FT-817. Bei vielen Kabeln tastet DTR CW oder PTT, und Hochhalten bedeutet Senden.';
	@override String get civAddress => 'CI-V-Adresse des Funkgeräts';
	@override String get civAddressDescription => 'Hexadezimal, wie im CI-V-Menü des Funkgeräts angezeigt. Der IC-705 wird mit A4 ausgeliefert.';
	@override String get civAddressInvalid => 'Eine CI-V-Adresse besteht aus zwei Hex-Ziffern, 01 bis FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Welchen Slice des Funkgeräts diese Verbindung liest und abstimmt.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Wähle einen der Slices des Funkgeräts, A bis H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} wird auf diesem Funkgerät nicht genutzt — wähle einen anderen Slice oder erstelle ihn in SmartSDR';
	@override String get channelNotInUse => 'nicht in Verwendung';
	@override String get channelHeldByUnknown => 'von einem anderen Programm belegt';
	@override String get flexNoSlices => 'Dieses Funkgerät hat keine Slices gemeldet — prüfe, ob SmartSDR läuft und dieser Client abonnieren darf';
	@override String get spectrumUnsupported => 'Dieses Funkgerät sendet kein Spektrum über CAT';
	@override String get spectrumRequiresBaud => 'Erfordert CAT mit 115200 bps';
	@override String get spectrumNoRadio => 'Kein Funkgerät verbunden';
	@override String get spectrumWaiting => 'Warte auf das Spektrum des Funkgeräts…';
	@override String get spectrumUnavailable => 'Spektrumanzeige nicht verfügbar';
	@override String get spectrumNoDaxChannel => 'Jeder DAX-IQ-Kanal dieses Funkgeräts ist belegt';
	@override String get spectrumNoPanadapter => 'Dieser Slice hat keinen Panadapter auf dem Funkgerät';
	@override String spectrumStreamRefused({required Object code}) => 'Das Funkgerät hat einen DAX-IQ-Stream abgelehnt (Fehler ${code})';
	@override String get spectrumNoUdp => 'Die Spektrumdaten des Funkgeräts erreichen dieses Gerät nicht';
	@override String get spectrumScopeRefused => 'Das Funkgerät hat seine Scope-Befehle abgelehnt';
	@override String get spectrumOutOfRange => 'Das Scope des Funkgeräts ist außerhalb des darstellbaren Bereichs eingestellt';
	@override String get n3fjpNoRig => 'In N3FJP ist keine Funkgeräteschnittstelle eingerichtet, daher folgt dies dem, was in N3FJP eingegeben wird, nicht einem Funkgerät';
	@override String get winkeyerKeyPort => 'Tastausgang';
	@override String get winkeyerKeyPortDescription => 'An welche der beiden Ausgangsbuchsen des Keyers dein Funkgerät angeschlossen ist.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'PTT des Keyers verwenden';
	@override String get winkeyerPttDescription => 'Die PTT-Leitung an derselben Buchse tasten, für eine Endstufe oder ein Funkgerät, das sie braucht. Aus lassen bei einem Funkgerät, das über seine Tastenbuchse getastet wird.';
	@override String get winkeyerNoAnswer => 'Kein WinKeyer hat an diesem Port reagiert';
	@override String get winkeyerStoppedAnswering => 'Der WinKeyer hat beim Senden aufgehört zu reagieren; die Nachricht wurde verworfen';
	@override String get radioUser => 'Benutzername des Funkgeräts';
	@override String get radioPass => 'Passwort des Funkgeräts';
	@override String get radioLoginDescription => 'Die Anmeldung unter Network → Remote des Funkgeräts, nicht dein WLAN-Passwort.';
	@override String get radioUserRequired => 'Der Benutzername für die Fernsteuerung des Funkgeräts ist erforderlich';
	@override String get connectFailedBusy => 'Gerät ist belegt';
	@override String get connectFailedDenied => 'Zugriff verweigert';
	@override String get connectFailedDevice => 'Gerät nicht gefunden';
	@override String get connectFailedLines => 'RTS/DTR konnten nicht wie eingestellt gehalten werden, daher wurde der Port geschlossen. Möglicherweise hat ein anderes Programm Hardware-Handshake eingeschaltet gelassen — Kabel abziehen und wieder einstecken.';
	@override String get connectFailedNetwork => 'Das Funkgerät ist im Netzwerk nicht zu finden. Prüfe die Adresse und ob es eingeschaltet und erreichbar ist.';
	@override String get connectFailedTimeout => 'Das Funkgerät hat nicht rechtzeitig reagiert. Prüfe, ob es eingeschaltet und erreichbar ist.';
	@override late final _Translations$settings$station$models$de models = _Translations$settings$station$models$de._(_root);
	@override late final _Translations$settings$station$transports$de transports = _Translations$settings$station$transports$de._(_root);
	@override String get troubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get ft891Troubleshooting => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **CAT RTS muss am Funkgerät AUS sein** (FT-891 Menü **05-08**). Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist dieselbe Leitung die PTT, ein Anheben würde also deinen Sender auftasten. Am eigenen USB-Port des Funkgeräts ist **RTS hoch halten** unter Erweiterte Einstellungen die Alternative.\n- **Die Geschwindigkeit muss** mit CAT RATE des Funkgeräts übereinstimmen (Menü **05-06**). Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get yaesuBinaryTroubleshooting => 'Dieses Funkgerät spricht Yaesus älteres Fünf-Byte-CAT und reagiert überhaupt nicht, wenn etwas nicht stimmt. Fast immer liegt es an einem dieser Punkte:\n\n- **Das Kabel muss die Pegel wandeln.** Die CAT-Buchse auf der Rückseite ist weder RS-232 noch USB; sie braucht ein CT-62 oder einen gleichwertigen Adapter. Ein einfaches Audio- oder Datenkabel funktioniert für CAT nicht.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen (**#14** beim FT-817, **#19** beim FT-857 oder FT-897). Bei Abweichung sendet das Funkgerät nichts zurück, aber nie einen Fehler.\n- **Lass nie etwas RTS oder DTR an diesem Port anheben.** Bei den meisten Kabeln für diese Funkgeräte sind diese Leitungen PTT und Tastung. Ausnahme ist eine ältere Schnittstelle, die über DTR versorgt wird: schalte dafür **DTR hoch halten** unter Erweiterte Einstellungen ein.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\nDieser Treiber wurde anhand von Yaesus veröffentlichter CAT-Tabelle geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get guohetecTroubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get guohetecTroubleshooting => 'Der Q900 hat zwei CAT-Protokolle, und dieser Eintrag nutzt das native statt der FT-817-Nachahmung. Wähle hier **Guohetec Q900**, nicht einen FT-817 — die Nachahmung unterstützt weniger Befehle, und das Funkgerät sagt nicht, welches es verwendet.\n\n- **Das USB-C-Kabel ist die CAT-Verbindung** und verbindet auch die Soundkarte. Die Geschwindigkeit spielt dort keine Rolle; der Port ignoriert die Einstellung.\n- **Lass nie etwas RTS oder DTR an diesem Port anheben.** Bei einem seriellen Kabel sind diese Leitungen PTT und Tastung.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Ein Gerät der zweiten Generation verhält sich anders** als eines der ersten. Lange auf Menu drücken, dann About: HW 2.0 ist die zweite Generation.\n\nDieser Treiber wurde anhand des veröffentlichten Protokolls des Herstellers geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get yaesuTroubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get yaesuTroubleshooting => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist dieselbe Leitung die PTT, ein Anheben würde also deinen Sender auftasten. Am eigenen USB-Port des Funkgeräts ist **RTS hoch halten** unter Erweiterte Einstellungen die Alternative. Wo diese Einstellung liegt, hängt vom Modell ab (Menü **05-08** beim FT-891).\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Die Modi folgen der Tabelle des FT-891.** Die meisten Yaesu-Geräte stimmen damit überein, aber bei einem Funkgerät, das seine Modi anders nummeriert, werden diese falsch angezeigt und gesetzt. Die Frequenz ist davon nicht betroffen.';
	@override String get yaesuRs232Troubleshooting => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **Die CAT-Buchse ist RS-232.** Sie braucht einen USB-Seriell-Adapter und ein 1:1-DB-9-Kabel — ein Nullmodemkabel vertauscht die Leitungen, und das Funkgerät hört nie etwas.\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält, außer **RTS hoch halten** ist unter Erweiterte Einstellungen eingeschaltet.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\nDieser Eintrag wurde anhand veröffentlichter CAT-Dokumentation geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get yaesuUsbTroubleshooting => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **Verwende den ersten der beiden USB-Ports des Funkgeräts.** CAT liegt normalerweise auf dem ersten (unter Windows der **Enhanced** COM-Port); der zweite (**Standard**) ist für PTT und Tastung. Die Auswahl zeigt auf den ersten, wo immer sie die beiden unterscheiden kann.\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält, außer **RTS hoch halten** ist unter Erweiterte Einstellungen eingeschaltet.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.';
	@override String get k4SerialNotes => 'Verbinde die hintere USB-B-Buchse (PC) des K4. Für CAT funktionieren sowohl USB-PC1 als auch USB-PC2; wähle einen freien Port und passe die Einstellung Serial USB-PCn: Baud Rate am Funkgerät an. HaLo trägt 38400 vor; ändere es bei Bedarf. Eine andere Anwendung muss den anderen Port oder Ethernet nutzen.\n\nDiese Verbindung steuert das Funkgerät und seine Keyer; sie sendet kein Audio an HaLo.';
	@override String get k4TcpNotes => 'Verbinde die Ethernet-Buchse des K4 mit deinem lokalen Netzwerk. Gib Hostname oder IP-Adresse und den CAT-Port 9200 ein. Das ist die CAT-Steuerung, nicht die separate Remote-Audio-Verbindung auf Port 9204.\n\nHaLo steuert das Funkgerät und seine Keyer, ohne Audio oder Panadapter-Daten zu übertragen.';
	@override String get k4PowerTimeout => 'Die Leistung des K4 wurde nicht geändert, weil das Funkgerät seinen Ausgangsbereich nicht bestätigt hat. Versuche es erneut.';
	@override String get k4PowerRange => 'Die Leistung des K4 muss 0,1–110 W betragen, oder 0,0001–0,01 W, wenn der Milliwatt-Ausgang für Transverter aktiv ist.';
	@override String get elecraftTroubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get elecraftTroubleshooting => 'Elecraft-Geräte sprechen Kenwood-CAT, und sowohl ein KX2 als auch ein KX3 wurden so betrieben — VFO in beide Richtungen, Moduswechsel und CW-Zero-Beat funktionieren alle.\n\nWenn das Funkgerät nicht reagiert, liegt es fast immer an einem dieser Punkte:\n\n- **Die Geschwindigkeit muss** mit der unter **RS232** im Menü des Funkgeräts eingestellten Rate übereinstimmen. Ab Werk ist 38400 eingestellt. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\n**Wenn die Frequenz stimmt, aber der Modus falsch ist**, sag uns Bescheid. Die Einträge für KX2 und KX3 lesen den Modus an einer Stelle der Statusantwort des Funkgeräts, die wir anhand der uns bekannten Geräte festgelegt haben, und eine Firmware, die ihn woanders ablegt, erfahren wir nur durch eine Meldung.\n\nZum K3 gibt es noch keine Meldung, bitte sag uns, was passiert, wenn du einen betreibst. Der K4 hat einen eigenen Eintrag.';
	@override String get kenwoodTroubleshootingTitle => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt';
	@override String get kenwoodTroubleshooting => 'Dieser Treiber ist mit Kenwoods TS-590SG und TS-480, QRP Labs\' QMX und QCX-mini sowie Elecrafts KX2 und KX3 erprobt. Der Rest der Reihe wurde anhand veröffentlichter CAT-Referenzen geschrieben, bitte melde also in jedem Fall, was passiert.\n\nWenn das Funkgerät nicht reagiert, liegt es fast immer an einem dieser Punkte:\n\n- **Die Geschwindigkeit muss** mit dem CAT-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Manche Geräte brauchen aktiviertes CAT** im Menü, bevor sie überhaupt reagieren.\n\n**Mehrere SDR-Frontends sprechen dasselbe Protokoll**, daher lohnt es sich, diesen Eintrag auch für diese auszuprobieren; Elecraft-Geräte sind separat unter Elecraft aufgeführt. Wenn die Frequenz stimmt, aber der Modus falsch ist oder fehlt, ist das der eine Teil, der sich innerhalb der Reihe unterscheidet — die App ermittelt ihn aus dem Funkgerät und fragt ersatzweise direkt nach, der Modus kann also einfach verzögert erscheinen.';
	@override String get statusConnected => 'Verbunden';
	@override String get statusLost => 'Getrennt';
	@override String get notConfigured => 'Nicht konfiguriert';
	@override String get currentConfiguration => 'Aktuelle Konfiguration';
	@override String get currentTransceiver => 'Aktueller Transceiver';
	@override String get radioMode => 'Modus des Funkgeräts';
	@override String get keyerNotSupported => 'Vom aktuellen Funkgerät nicht unterstützt';
	@override String get catControlPreferences => 'Einstellungen für CAT-Steuerung';
	@override String get chooseTransceiver => 'Transceiver wählen';
	@override String get configurationSection => 'Konfiguration';
	@override String get noTransceiverSelected => 'Kein Transceiver ausgewählt';
	@override String makeMainVfo({required Object name}) => '${name} als Haupt-VFO verwenden';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		zero: 'Keine Transceiver',
		one: '${count} Transceiver',
		other: '${count} Transceiver',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Antenne',
		other: '${count} Antennen',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} weiteres Gerät',
		other: '${count} weitere Geräte',
	);
	@override String get equipmentInventory => 'Geräteinventar';
	@override String get equipmentInUse => 'Transceiver-Steuerung';
	@override String get noTransceiver => 'Keiner';
	@override String get peerRadioNotAvailable => 'Nicht verfügbar';
	@override String peerRadioOnDevice({required Object device}) => 'Auf ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} ist an einem anderen Gerät';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Dieses Funkgerät ist mit ${device} verbunden. Verbindung und Einstellungen werden auf jenem Gerät konfiguriert.';
	@override String get antennaInUse => 'Verwendete Antenne';
	@override String get keyInUse => 'Verwendete Taste';
	@override String get noneSelected => 'Keine';
	@override String get moreSettings => 'Weitere Einstellungen';
	@override String get icomCivTroubleshootingTitle => 'Wenn für dasselbe Funkgerät zwei serielle Ports erscheinen';
	@override String get icomCivTroubleshooting => 'Mehrere Icom-Funkgeräte, darunter der IC-705, stellen **zwei** USB-Seriell-Ports gleichzeitig bereit (Icom nennt sie Port A und Port B), beide standardmäßig auf CI-V eingestellt. Weder diese App noch dein Betriebssystem kann sie darüber hinaus unterscheiden: dieselbe USB-Vendor-/Product-ID erscheint einfach zweimal, hier manchmal mit dem Suffix `#2` markiert. **Port A ist meist der richtige** — normalerweise der erste, den dein Betriebssystem oder Browser auflistet, und wo diese App die beiden Ports unterscheiden kann, markiert sie ihn als empfohlen. Wenn Befehle rausgehen und das Funkgerät nie reagiert, probiere als Nächstes den anderen Port.';
	@override String get civAddressTroubleshootingTitle => 'Wenn das Funkgerät nie reagiert';
	@override String get civAddressTroubleshooting => '- **Die CI-V-Adresse muss** mit dem Menü des Funkgeräts übereinstimmen. Dieser Eintrag trägt die Werksadresse des Modells vor, aber gerade bei einem Gerät an einem gemeinsamen CI-V-Bus wird sie geändert. Ein an die falsche Adresse gesendeter Frame wird stillschweigend ignoriert, was genau wie ein defektes Kabel aussieht.\n- **Die Geschwindigkeit muss** mit CI-V BAUD RATE des Funkgeräts übereinstimmen (bei USB: CI-V USB Baud Rate). Stelle am Funkgerät denselben Wert wie hier ein, **nicht Auto**. Auf Auto verbinden sich manche Funkgeräte, darunter der IC-7300, und reagieren nach etwa einer Minute nicht mehr.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.';
	@override String get ic7300Mk2Note => '\n- Der **IC-7300 MK2** wird mit Adresse `B6` ausgeliefert, nicht mit der hier vorgetragenen `94` — wähle stattdessen den Eintrag IC-7300 MK2.';
	@override String get ic705PortNote => '\n- Der **IC-705** stellt zwei USB-Seriell-Ports bereit, beide nach dem Funkgerät benannt. CI-V liegt auf dem **ersten** davon, auf den die Auswahl zeigt, wo immer sie die beiden unterscheiden kann.';
	@override String get ic7760PortNote => '\n- Der **IC-7760** spricht CI-V auf **Port A** der beiden USB-Seriell-Ports, die er bereitstellt.';
	@override String get x6100PortNote => '\n- Der **X6100** spricht CI-V auf seinem **DEV**-Port — dem zweiten der beiden seriellen Ports, die er bereitstellt, und dem, auf den die Auswahl zeigt.';
	@override String get rigctldTroubleshootingTitle => 'Wenn die App sich nicht verbinden kann';
	@override String get rigctldTroubleshooting => 'Dies verbindet sich mit einem **rigctld-Daemon, den du selbst startest**, nicht direkt mit dem Funkgerät — das Hamlib-Backend spricht mit dem Funkgerät und unterstützt Hunderte von Modellen.\n\n- **Der Daemon muss bereits laufen**, z. B. `rigctld -m 1035 -r /dev/ttyUSB0`. Die Modellnummer deines Funkgeräts findest du mit `rigctl -l`.\n- **Von einem anderen Rechner aus** starte ihn mit `-T 0.0.0.0`: standardmäßig nimmt rigctld nur Verbindungen vom eigenen Rechner an.\n- **Port** ist 4532, außer du hast den Daemon mit `-t` gestartet.\n- Fehlt nach dem Verbinden die Frequenz, kann meist der Daemon selbst das Funkgerät nicht erreichen. Teste es mit `rigctl -m 2 f` auf dem Rechner des Daemons.';
	@override String get flrigTroubleshootingTitle => 'Wenn die App sich nicht verbinden kann';
	@override String get flrigTroubleshooting => 'Dies verbindet sich mit einem **flrig-Programm, das du selbst startest**, nicht direkt mit dem Funkgerät — flrig spricht mit dem Funkgerät und unterstützt die meisten Hersteller und Modelle.\n\n- **flrig muss bereits laufen**, mit konfiguriertem und verbundenem Transceiver.\n- **Port** ist 12345, außer du hast ihn in der flrig-Konfiguration geändert (Config → Setup → Server).\n- **Von einem anderen Rechner aus** stelle sicher, dass der flrig-Server erreichbar ist. Er lauscht auf allen Schnittstellen, aber deine Firewall sieht das evtl. anders.\n- Fehlt nach dem Verbinden die Frequenz, kann meist flrig selbst das Funkgerät nicht erreichen. Prüfe, ob die Anzeige von flrig dem Abstimmknopf folgt.';
	@override String get hrdTroubleshootingTitle => 'Wenn die App sich nicht verbinden kann';
	@override String get hrdTroubleshooting => 'Dies verbindet sich mit **Rig Control von Ham Radio Deluxe auf deinem Computer**, nicht direkt mit dem Funkgerät — HRD spricht mit dem Funkgerät.\n\n- **Rig Control muss bereits laufen** und mit dem Funkgerät verbunden sein.\n- **Sein IP-Server muss aktiviert sein.** Nur darüber spricht Rig Control mit anderen Programmen.\n- **Port** ist 7809, außer du hast ihn in den Einstellungen des IP-Servers geändert.\n- **Von einem anderen Rechner aus** stelle sicher, dass deine Firewall die Verbindung durchlässt.\n\nDieser Eintrag wurde anhand veröffentlichter Beschreibungen des HRD-Protokolls geschrieben und noch nicht mit HRD getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get n3fjpTroubleshootingTitle => 'Wenn die App sich nicht verbinden kann';
	@override String get n3fjpTroubleshooting => 'Dies verbindet sich mit **einem N3FJP-Logprogramm auf deinem Computer**, nicht direkt mit dem Funkgerät — N3FJP spricht mit dem Funkgerät.\n\n- **Die API des Programms muss eingeschaltet sein**: Settings → Application Program Interface, **TCP API Enabled** aktivieren.\n- **Port** ist 1100, außer du hast ihn dort geändert.\n- **In N3FJP muss eine Funkgeräteschnittstelle eingerichtet sein**, um dem Funkgerät zu folgen oder es abzustimmen. Ohne sie meldet es nur, was in sein Eingabefenster getippt wird.\n- N3FJP meldet nur Band, Modus und Frequenz: keine Leistung, keinen Sendezustand.\n\nDieser Eintrag wurde anhand der veröffentlichten API von N3FJP geschrieben und noch nicht mit N3FJP getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get commanderTroubleshootingTitle => 'Wenn die App sich nicht verbinden kann';
	@override String get commanderTroubleshooting => 'Dies verbindet sich mit **DXLab Commander auf deinem Computer**, nicht direkt mit dem Funkgerät — Commander spricht mit dem Funkgerät.\n\n- **Commander muss bereits laufen** und mit dem Funkgerät verbunden sein.\n- **Sein Netzwerkdienst muss eingeschaltet sein**: der Button **Net Serv** im Radio-Bereich des Configuration-Fensters von Commander.\n- **Port** ist 52002, der dritte Port des Blocks ab dem **Base Port** von Net Serv (52000, außer du hast ihn geändert).\n- **Von einem anderen Rechner aus** stelle sicher, dass deine Firewall die Verbindung durchlässt.\n\nDieser Eintrag wurde anhand der veröffentlichten TCP-Nachrichten von Commander geschrieben und noch nicht mit Commander getestet. Wenn er halb funktioniert, ist das eine Meldung wert.';
	@override String get ic705TroubleshootingTitle => 'Wenn das Funkgerät nie reagiert';
	@override String get ic705Troubleshooting => 'Das Funkgerät hat eine **einzige** Fernsteuerungssitzung. Wird die Anmeldung ignoriert, nutzt fast immer etwas anderes sie.\n\n- **Schließe alle anderen Clients.** wfview oder RS-BA1, mit demselben Funkgerät verbunden, belegen diese eine Sitzung, und die Anmeldung hier wird solange einfach ignoriert.\n- **Prüfe die Netzwerkeinstellungen des Funkgeräts.** WLAN muss an sein, das Funkgerät muss im selben Netzwerk sein und seine Fernsteuerungsfunktion (Network) muss aktiviert sein.\n- **Schalte das WLAN des Funkgeräts aus und wieder ein**, wenn es hängen bleibt. Das löst zuverlässig eine auf dem Funkgerät hängende Sitzung.\n\nEin **falsches Passwort wird ausdrücklich abgelehnt**, nicht mit Schweigen beantwortet. Wenn du hier gelandet bist statt bei einer Meldung „abgelehnt“, ist das Passwort nicht das Problem.';
	@override String get statusStale => 'Reagiert nicht';
	@override String get statusDisconnected => 'Nicht verbunden';
	@override String get statusConnecting => 'Verbinde…';
	@override String get statusDisconnecting => 'Trenne…';
	@override String get statusError => 'Verbindung fehlgeschlagen';
	@override String get currentRadioSettings => 'Aktuelle Funkgeräteeinstellungen';
	@override String get notSupportedByThisRadio => 'Von diesem Funkgerät nicht unterstützt';
	@override String get keyerRowLabel => 'Keyer';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Phone';
	@override String voiceKeyerAvailable({required Object count}) => 'Sprach-Keyer: ${count} Speicher im Funkgerät';
	@override String get antennaBands => 'Bänder';
	@override String get antennaType => 'Antennentyp';
	@override String get antennaTypeRequired => 'Wähle einen Antennentyp';
	@override late final _Translations$settings$station$antennaTypes$de antennaTypes = _Translations$settings$station$antennaTypes$de._(_root);
	@override String get keyType => 'Tastentyp';
	@override String get keyTypeRequired => 'Wähle einen Tastentyp';
	@override late final _Translations$settings$station$keyTypes$de keyTypes = _Translations$settings$station$keyTypes$de._(_root);
	@override String get softwareIntermediaries => 'Software-Vermittler';
	@override String get otherBrands => 'Andere Marken';
	@override String get otherEquipment => 'Andere Geräte (Antennen, Tasten usw.)';
	@override String get newAntenna => 'Neue Antenne';
	@override String get newKey => 'Neue Taste';
	@override String get newKeyer => 'WinKeyer (K1EL oder kompatibel)';
	@override String keyViaRadio({required Object radio}) => 'CAT-Keyer in ${radio}';
	@override String keyOnDevice({required Object device}) => 'Taste an ${device}';
	@override String get cwKeyerArea => 'Keyer-Bereich';
	@override String get trackStationInfo => 'Stationsinfo für jedes QSO erfassen';
	@override String get includeStationInfoInAdif => 'In ADIF-Exporte aufnehmen';
	@override String get whatToTrack => 'Was erfassen?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Leistung';
	@override String get watts => 'Watt';
	@override String get trackFieldAntenna => 'Antenne';
	@override String get trackFieldKey => 'CW-Taste';
	@override String get placeholderConnectDelay => 'Verbindungsverzögerung (ms)';
	@override String get placeholderConnectDelayDescription => 'Wie lange der simulierte Handshake dauert. Leer oder 0 verbindet sofort.';
	@override String get placeholderDropAfter => 'Trennen nach (Sekunden)';
	@override String get placeholderDropAfterDescription => 'Die Verbindung von selbst schließen, um das Wiederverbinden zu testen. Leer oder 0 trennt nie.';
	@override String get placeholderFailConnect => 'Verbindung immer fehlschlagen lassen';
	@override String get placeholderConnectFailure => 'Das Platzhalter-Funkgerät wurde angewiesen, diese Verbindung abzulehnen';
	@override String get placeholderFreq => 'Frequenz (kHz)';
	@override String get placeholderFreqDescription => 'Wo das Platzhalter-Funkgerät startet. Danach meldet es zurück, worauf die App es abstimmt.';
	@override String get placeholderMode => 'Modus';
	@override String get placeholderModeDescription => 'Der Modus, mit dem das Platzhalter-Funkgerät startet, z. B. USB, CW, FT8.';
	@override String get placeholderPower => 'Leistung (Watt)';
	@override String get placeholderPurpose => 'Verwende dieses Funkgerät, um für das Log festzuhalten, welches Gerät du benutzt';
	@override String get placeholderReplyDelay => 'Antwortverzögerung (ms)';
	@override String get placeholderReplyDelayDescription => 'Wie lange das Platzhalter-Funkgerät braucht, um eine Änderung zurückzumelden. Leer oder 0 antwortet sofort.';
	@override String get cwKeyerField => 'CAT-CW-Keyer';
	@override String get cwKeyerFieldDescription => 'Ob dieses Funkgerät CW aus Text über CAT tastet. Aus bei einem Gerät, das die App nicht kennt.';
	@override String get voiceMemories => 'Sprachspeicher';
	@override String get voiceMemoriesDescription => 'Wie viele Sprachspeicher das Funkgerät über CAT abspielt. 0 für keine.';
	@override String get voiceMemoriesInvalid => 'Eine ganze Zahl, 0 oder mehr';
	@override String get yaesuMeterCapture => 'Messwerte aufzeichnen';
	@override String get yaesuBinaryMeterCaptureDescription => 'Liest beim Senden das Ausgangsleistungs-Meter und das High-SWR-Flag des Funkgeräts und schreibt die Rohwerte ins Protokoll. Dient zum Erstellen der Skala, die Yaesu nicht veröffentlicht — die Werte werden nicht als Anzeigen dargestellt.';
	@override String get yaesuMeterCaptureDescription => 'Liest beim Senden die PO-, SWR- und ALC-Meter des Funkgeräts und schreibt die Rohwerte ins Protokoll. Dient zum Erstellen der Skala, die Yaesu nicht veröffentlicht — die Werte werden nicht als Anzeigen dargestellt.';
	@override String get telemetryInterval => 'Intervall für Messwerte (ms)';
	@override String get telemetryIntervalDescription => 'Wie oft die Meter des Funkgeräts beim Senden gelesen werden. Leer lassen für das Schnellste, was diese Verbindung schafft, bis 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Eine ganze Zahl in Millisekunden, ${min} bis ${max}';
	@override String get pollInterval => 'Abfrageintervall im Leerlauf (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Wie oft das Funkgerät nach Frequenz und Modus gefragt wird, solange sich keines davon ändert. Leer lassen für ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Eine ganze Zahl in Millisekunden, ${min} bis ${max}';
	@override String get advancedSettings => 'Erweiterte Einstellungen';
	@override String get placeholderSwr => 'SWR-Wert';
	@override String get placeholderSwrDescription => 'Was dieses Funkgerät beim Senden auf seinem SWR-Meter meldet. Über 1,8 warnt das Panel.';
	@override String get placeholderSwrInvalid => 'Eine Zahl, 1 oder mehr';
	@override String get keyerNone => 'Keiner';
	@override String get cwDialect => 'CW-Tastungsdialekt';
	@override String get cwDialectDescription => 'Welche Form des KY-Befehls dieses Funkgerät erwartet. Keiner bedeutet keine CW-Tastung über CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, auf 24 aufgefüllt)';
	@override String get cwDialectElecraft => 'Elecraft (KY-Text)';
	@override String get voiceDialect => 'Sprach-Keyer-Dialekt';
	@override String get voiceDialectDescription => 'Wie dieses Funkgerät seine Sprachspeicher über CAT abspielt. Keiner bedeutet keine Sprachspeicher über CAT. Mit Dialekt und ohne Anzahl gilt die Standardanzahl des Dialekts.';
	@override String get voiceDialectPb => 'Kenwood (PB, wie TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB und DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (Schalter-Tipps)';
	@override String get placeholderDiagnostic => 'Simuliert';
	@override String get placeholderWholeNumberInvalid => 'Muss eine ganze Zahl sein, 0 oder mehr';
	@override String get placeholderFreqInvalid => 'Muss eine Frequenz in kHz sein, größer als null';
	@override String get placeholderModeInvalid => 'Muss ein Modusname sein, z. B. USB, CW, FT8';
	@override String get switchLayout => 'Belegung';
	@override String get switchLayoutDescription => 'An welcher Seite des Schalters deine Funkgeräte angeschlossen sind.';
	@override String get switchLayoutRequired => 'Wähle, wie der Schalter verkabelt ist';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Der Schalter hat „${command}“ abgelehnt (Fehler ${code})';
	@override String get switchBusyTransmitting => 'Dieser Port sendet — Antenne nicht geändert';
	@override String get switchNoAntenna => 'Keine';
	@override String switchAntennaFor({required Object port}) => 'Antenne an Port ${port}';
	@override String get switchAntennaForDescription => 'Welche deiner Antennen an diesem Port des Schalters angeschlossen ist.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} Antennen, ${radios} Funkgeräte';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} Antennen, 1 Funkgerät';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 Antenne, ${radios} Funkgeräte';
	@override String get switchCommonPort => 'Gemeinsam';
	@override String get dcnAddress => 'Geräteadresse';
	@override String get dcnAddressDescription => 'Die an den DIP-Schaltern des Moduls eingestellte Adresse. Ein Koax-Relaismodul ist ab Werk auf 2 eingestellt.';
	@override String get dcnAddressRequired => 'Muss eine Geräteadresse von 1 bis 99 sein';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'folgt den Banddaten';
	@override String get switchPortTransmittingHint => 'sendet — jetzt nicht änderbar';
	@override String get switchCurrentStateHeader => 'Aktueller Zustand';
	@override String get switchCurrentStateDescription => 'An welcher Antenne jeder Funkgeräte-Port gerade ist. Änderungen wirken sofort.';
	@override String get switchWiringHeader => 'Verkabelung';
	@override String get switchPortInhibitedHint => 'Senden gesperrt';
	@override String get configUnreadable => 'Die gespeicherten Einstellungen dieses Funkgeräts konnten nicht gelesen werden. Öffne seine Einstellungen und gib sie erneut ein, oder entferne es und füge es wieder hinzu.';
	@override String get autoConnectHeld => 'HaLo reagierte beim letzten Verbinden mit diesem Funkgerät nicht mehr, daher wurde diesmal nicht automatisch verbunden. Drücke Verbinden, um es erneut zu versuchen.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$de extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Offline-Daten';
	@override String get noFiles => 'Keine Datendateien';
	@override String get noFilesDescription => 'Aktiviere Aktivitäts- oder Abfrage-Erweiterungen, um ihre Offline-Daten hier herunterzuladen.';
	@override String get refresh => 'Aktualisieren';
	@override String get refreshing => 'Aktualisiere…';
	@override String get updateAll => 'Alle aktualisieren';
	@override String get updatingAll => 'Alle Datendateien werden aktualisiert…';
	@override String get neverDownloaded => 'Nie heruntergeladen';
	@override String get updatedJustNow => 'Gerade eben aktualisiert';
	@override String updatedDaysAgo({required Object days}) => 'Vor ${days} T aktualisiert';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Vor ${days} T ${hours} Std. aktualisiert';
	@override String updatedHoursAgo({required Object hours}) => 'Vor ${hours} Std. aktualisiert';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Vor ${hours} Std. ${minutes} Min. aktualisiert';
	@override String updatedMinutesAgo({required Object minutes}) => 'Vor ${minutes} Min. aktualisiert';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Der letzte Download hatte nur ${imported} von ${existing} Einträgen und wurde nicht verwendet. Aktualisiere, um ihn zu übernehmen.';
	@override String get extensionsSection => 'Erweiterungen';
}

// Path: settings.profiles
class _Translations$settings$profiles$de extends Translations$settings$profiles$en {
	_Translations$settings$profiles$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Nicht festgelegt';
	@override String get personalInfo => 'Persönliche Daten';
	@override String get personalInfoNote => 'Kann in erzeugte Logs aufgenommen werden, wenn es für Einreichungen relevant ist';
	@override String get name => 'Name';
	@override String get email => 'E-Mail';
	@override String get club => 'Club';
	@override String get arrlSection => 'ARRL-Sektion';
	@override String get racSection => 'RAC-Sektion';
	@override String get section => 'Sektion';
}

// Path: settings.search
class _Translations$settings$search$de extends Translations$settings$search$en {
	_Translations$settings$search$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Leeren';
	@override String get hint => 'Einstellungen durchsuchen';
}

// Path: settings.developer
class _Translations$settings$developer$de extends Translations$settings$developer$en {
	_Translations$settings$developer$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Entwicklerwarnungen, Debug-Logs und Werkzeuge aktivieren.';
	@override String get experiments => 'Experimente';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} aktiviert',
		other: '${count} aktiviert',
	);
	@override String get patchTrack => 'Code-Push-Zweig';
	@override String get patchTrackDescription => 'Welchem Over-the-Air-Code-Push-Ring dieses Gerät folgt. Experimentellere Ringe erhalten Korrekturen früher, aber weniger getestet. Code-Pushes werden beim nächsten Neustart angewendet.';
	@override String get trackStable => 'Stabil';
	@override String get trackUnstable => 'Instabil';
	@override String get trackBleeding => 'Experimentell';
	@override String checkingTrack({required Object track}) => 'Prüfe „${track}“ auf einen Code-Push…';
	@override String get patchDownloaded => 'Code-Push heruntergeladen — starte die App neu, um ihn anzuwenden.';
	@override String noNewPatch({required Object track}) => 'Kein neuer Code-Push auf „${track}“.';
	@override String get noPatchInstalled => 'Kein Code-Push installiert — das Release-Binary läuft.';
	@override String runningPatch({required Object patch}) => 'Code-Push #${patch} läuft.';
	@override String get deepLinks => 'Deep Links';
	@override String get registerUrlSchemes => 'URL-Schemata registrieren';
	@override String get registerUrlSchemesDescription => 'com.ham2k://-Links mit dieser Kopie der App öffnen';
	@override String get registerUrlSchemesDone => 'Diese Kopie öffnet jetzt com.ham2k://-Links';
	@override String registerUrlSchemesFailed({required Object error}) => 'Registrierung fehlgeschlagen: ${error}';
	@override String get systemInformation => 'Systeminformationen';
	@override String get appVersion => 'App-Version';
	@override String get dataFolder => 'Datenordner';
	@override String get loading => '(lädt…)';
	@override String get panelLoadFailed => 'Dieses Einstellungs-Panel konnte nicht geladen werden.';
	@override String get extDevServer => 'Erweiterungs-Dev-Server';
	@override String get extensionSettings => 'Erweiterungseinstellungen';
	@override String get extDevServerDescription => 'Erweiterungen von einem Dev-Server in deinem Netzwerk statt der in die App eingebauten laden und beim Speichern neu laden.';
	@override String get extDevServerAddress => 'Serveradresse';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Verbinden';
	@override String get extDevServerDisconnect => 'Trennen';
	@override String get extDevServerConnecting => 'Verbinde…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Liefert ${count} Erweiterung: ${keys}',
		other: 'Liefert ${count} Erweiterungen: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Nicht verbunden';
	@override String get extDevServerReconnect => 'Beim Start neu verbinden';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Zuletzt neu geladen: ${key} um ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Erweiterung lässt sich nicht bauen',
		other: '${count} Erweiterungen lassen sich nicht bauen',
	);
	@override String get catalog => 'Erweiterungskatalog';
	@override String get catalogDescription => 'Den Katalog von einem anderen Server lesen — einem lokalen, während am Katalog selbst gearbeitet wird. Leer bedeutet catalog.ham2k.net.';
	@override String get catalogAddress => 'Katalogadresse';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Zweige für Katalogsuche';
	@override String get catalogSearchStable => 'Nur stabil';
	@override String get catalogSearchUnstable => 'Instabil oder besser';
	@override String get catalogSearchBleeding => 'Experimentell oder besser';
}

// Path: settings.about
class _Translations$settings$about$de extends Translations$settings$about$en {
	_Translations$settings$about$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Hinweise & Nachrichten';
	@override String get noticesDescription => 'Ankündigungen und Statusmeldungen';
	@override String get releaseNotes => 'Versionshinweise';
	@override String get copiedVersion => 'Versionsdetails in die Zwischenablage kopiert';
}

// Path: settings.panels
class _Translations$settings$panels$de extends Translations$settings$panels$en {
	_Translations$settings$panels$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get settings => 'App-Einstellungen';
	@override String get settingsDescription => 'Richte die App so ein, wie du sie willst';
	@override String get commonSettings => 'Allgemeine Einstellungen';
	@override String get syncDescription => 'Deine Logs sichern und zwischen Geräten synchronisieren';
	@override String get accountsDescription => 'Dienst-Anmeldedaten, Offline-Daten und mehr';
	@override String get extensions => 'Erweiterungen & Funktionen';
	@override String get extensionsDescription => 'Aktivitäten, Contests, Dashboard-Panels und weitere Funktionen';
	@override String get profilesDescription => 'Operator-Rufzeichen und Stationsprofil';
	@override String get stationProfiles => 'Stationsprofile';
	@override String get developerSettings => 'Entwicklereinstellungen';
	@override String get developerSettingsDescription => 'Debugging- und Entwicklungswerkzeuge';
	@override String get about => 'Über';
	@override String get aboutDescription => 'Version, Danksagungen und rechtliche Informationen';
	@override String get unavailableTitle => 'Einige Einstellungen sind nicht verfügbar';
	@override String get unavailableText => 'Die Erweiterungs-Laufzeit konnte nicht starten, daher fehlen Einstellungen von Erweiterungen.';
	@override String get station => 'Stationskonfiguration';
	@override String get stationDescription => 'CAT-Steuerung und weitere Optionen';
	@override String get peers => 'Partnergeräte';
	@override String get peersDescription => 'Mit anderen Geräten in der Nähe verbinden';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$de extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get locale => 'Systemeinstellungen folgen';
	@override String get period => 'Immer Punkt als Dezimaltrennzeichen';
	@override String get comma => 'Immer Komma als Dezimaltrennzeichen';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$de extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => 'Systemeinstellungen (${separator} als Dezimaltrennzeichen)';
	@override String get period => 'Immer Punkt als Dezimaltrennzeichen';
	@override String get comma => 'Immer Komma als Dezimaltrennzeichen';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$de extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get comma => 'Komma';
	@override String get period => 'Punkt';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$de extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get six => '6 Stellen (FN31pr)';
	@override String get eight => '8 Stellen (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$de extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get six => '6 Stellen';
	@override String get eight => '8 Stellen';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$de extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get date => 'Datum';
	@override String get time => 'Zeit';
	@override String get freq => 'Frequenz';
	@override String get mode => 'Modus';
	@override String get call => 'Rufzeichen';
	@override String get name => 'Name';
	@override String get station => 'Station';
	@override String get band => 'Band';
	@override String get sent => 'Gesendet';
	@override String get rcvd => 'Empf.';
	@override String get grid => 'Grid';
	@override String get state => 'Staat';
	@override String get country => 'Land';
	@override String get refs => 'Refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$de extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO-Log';
	@override String get qsosDescription => 'Die QSOs des ausgewählten Rufzeichens, über alle Betriebe hinweg.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Gesamtzahl der QSOs oder die Rufzeichenabfrage des ausgewählten QSOs.';
	@override String get map => 'Karte';
	@override String get mapDescription => 'Der Standort des ausgewählten QSOs.';
}

// Path: home.logs.import
class _Translations$home$logs$import$de extends Translations$home$logs$import$en {
	_Translations$home$logs$import$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Rufzeichen: ${calls}';
	@override String get skippedOne => '1 Eintrag konnte nicht gelesen werden';
	@override String skippedOther({required Object count}) => '${count} Einträge konnten nicht gelesen werden';
	@override String get readingTitle => 'ADIF-Datei wird gelesen…';
	@override String get checkingTitle => 'Suche nach Duplikaten…';
	@override String get importingTitle => 'QSOs werden importiert…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} von ${total} geprüft';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} von ${total} importiert';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$de extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Das Log und die Eingabefelder';
	@override String get infoDescription => 'Was wir über die gearbeitete Station wissen';
	@override String get spotsDescription => 'Spots von Clustern und Aktivitätsprogrammen';
	@override String get mapDescription => 'Wo die Kontakte sind';
	@override String get clockDescription => 'Ein Zifferblatt, in beliebiger Zeitzone';
	@override String get clockFace => 'Anzeige';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analog';
	@override String get clockZone => 'Zeitzone';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Dieses Gerät';
	@override String get clockShowSeconds => 'Sekunden anzeigen';
	@override String get weatherDescription => 'Aktuelle Bedingungen und die nächsten acht Stunden, dort wo du funkst';
	@override String get weatherUseOperationLocation => 'Standort des Betriebs verwenden';
	@override String get weatherLocation => 'Standort';
	@override String get weatherLocationDescription => 'Ein Grid (FN31pr) oder Breite,Länge. Wird ignoriert, solange „Standort des Betriebs verwenden“ aktiviert ist.';
	@override String get weatherNoLocation => 'Kein Standort festgelegt. Gib diesem Panel in seinen Einstellungen einen Standort oder platziere es in einem Betrieb, der einen hat.';
	@override String weatherBadLocation({required Object location}) => 'Der Standort ${location} konnte nicht gelesen werden. Verwende ein Grid wie FN31pr oder 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo nicht erreichbar — kein Netzwerk? Neuer Versuch in Kürze.';
	@override String get weatherUnreadable => 'Open-Meteo hat geantwortet, aber nichts Lesbares geliefert. Neuer Versuch in Kürze.';
	@override String weatherGusts({required Object speed}) => 'Böen ${speed}';
	@override String get panelAgeNow => 'gerade eben';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'vor ${count} Min.',
		other: 'vor ${count} Min.',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'vor ${count} Std.',
		other: 'vor ${count} Std.',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$de weatherConditions = _Translations$operation$layout$panels$weatherConditions$de._(_root);
	@override String get websiteDescription => 'Eine Webseite deiner Wahl in einem Bereich';
	@override String get websiteUrl => 'Adresse';
	@override String get websiteRefresh => 'Aktualisieren';
	@override String get websiteRefreshNever => 'Nie';
	@override String get websiteRefresh1 => 'Jede Minute';
	@override String get websiteRefresh5 => 'Alle 5 Minuten';
	@override String get websiteRefresh15 => 'Alle 15 Minuten';
	@override String get websiteTitle => 'Panel-Name';
	@override String get websiteRefreshNow => 'Jetzt aktualisieren';
	@override String get websiteNoUrl => 'Noch keine Adresse. Öffne die Einstellungen dieses Panels, um eine Seite auszuwählen.';
	@override String get websiteBadUrl => 'Das sieht nicht wie eine Webadresse aus. Sie muss mit https:// beginnen';
	@override String get websiteNotHttps => 'Hier können nur Adressen mit https:// angezeigt werden.';
	@override String get websiteUnsupported => 'Webseiten können auf diesem System nicht in einem Panel angezeigt werden.';
	@override String get websiteOpenExternally => 'Im Browser öffnen';
	@override String websiteLoadFailed({required Object reason}) => 'Die Seite konnte nicht geladen werden: ${reason}';
	@override String get remoteScreenDescription => 'Ein Bildschirm, eine App oder ein Fenster, das ein anderes deiner Geräte teilt.';
	@override String get remoteScreenTarget => 'Bildschirm';
	@override String get remoteScreenChoose => 'Bildschirm wählen…';
	@override String get remoteScreenPickerTitle => 'Geteilte Bildschirme';
	@override String get remoteScreenPickerEmpty => 'Keines deiner Geräte teilt einen Bildschirm. Schalte „Bildschirme und Fenster teilen“ unter Einstellungen → Partnergeräte auf dem Gerät ein, das du sehen möchtest.';
	@override String get remoteScreenUnset => 'Kein Bildschirm gewählt. Öffne die Einstellungen dieses Panels, um einen auszuwählen, den deine anderen Geräte teilen.';
	@override String get remoteScreenConnecting => 'Verbinde…';
	@override String get remoteScreenPeerAway => 'Dieses Gerät ist gerade nicht verbunden.';
	@override String get remoteScreenNotOffered => 'Dieses Gerät teilt diesen Bildschirm nicht mehr.';
	@override String get remoteScreenNoListener => 'Dieses Gerät kann keine Verbindungen annehmen — prüfe seine Firewall.';
	@override String get remoteScreenNoLan => 'Bildschirme werden nur über das lokale Netzwerk geteilt, nicht über Bluetooth.';
	@override String get remoteScreenRefused => 'Dieses Gerät hat das Teilen dieses Bildschirms abgelehnt.';
	@override String get remoteScreenSettings => 'Panel-Einstellungen';
	@override String get remoteScreenAdjust => 'Ansicht anpassen';
	@override String get remoteScreenDetail => 'Detail';
	@override String get remoteScreenDetailStandard => 'Standard';
	@override String get remoteScreenDetailHigh => 'Hoch';
	@override String get remoteScreenDetailMaximum => 'Maximal';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Vergrößern';
	@override String get remoteScreenZoomOut => 'Verkleinern';
	@override String get remoteScreenStopped => 'Dieser Bildschirm oder dieses Fenster wird nicht mehr angezeigt.';
	@override String get remoteScreenCaptureFailed => 'Dieses Gerät konnte den Bildschirm nicht aufnehmen — evtl. fehlt die Berechtigung zur Bildschirmaufnahme.';
	@override String get remoteScreenNoAnswer => 'Dieses Gerät hat nicht reagiert. Möglicherweise ist die Bildschirmfreigabe nicht eingeschaltet.';
	@override String get remoteScreenNoMedia => 'Für das Bild konnte keine Verbindung geöffnet werden. Prüfe die Firewall auf diesem Gerät.';
	@override String get solarDescription => 'Solare und geomagnetische Bedingungen mit Ausbreitung pro Band';
	@override String get solarUnreachable => 'hamqsl.com nicht erreichbar — kein Netzwerk? Neuer Versuch in Kürze.';
	@override String get solarUnreadable => 'hamqsl.com hat geantwortet, aber keine verwendbaren Werte geliefert. Neuer Versuch in Kürze.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Tag';
	@override String get solarBandNight => 'Nacht';
	@override String get solarBandGood => 'Gut';
	@override String get solarBandFair => 'Mittel';
	@override String get solarBandPoor => 'Schlecht';
	@override String solarSources({required Object primary, required Object secondary}) => 'Quellen: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Die Verbindung hat Mühe — Frames werden übersprungen.';
	@override String get remoteScreenStalled => 'Es kommen keine Frames mehr an — diese Verbindung ist evtl. zu langsam.';
	@override String get radioDescription => 'Die Frontplatte eines Funkgeräts — Frequenz, Modus und Leistung, per CAT gesteuert';
	@override String get radioStyle => 'Stil';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Modern';
	@override String get radioRadio => 'Funkgerät';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — kein Funkgerät festgelegt';
	@override String get radioNoRadio => 'Kein Funkgerät zum Anzeigen. Wähle eines in den Einstellungen dieses Panels oder füge eines unter Stationskonfiguration hinzu.';
	@override String get radioNotConfigured => 'Dieses Funkgerät ist noch nicht konfiguriert. Wähle seinen Port oder seine Adresse unter Stationskonfiguration.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Funkgerät nicht verbunden';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Dieses Funkgerät verbinden';
	@override String get radioDisconnect => 'Dieses Funkgerät trennen';
	@override String get radioStale => 'KEINE DATEN';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'hohes SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$de extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kompakte Dateinamen verwenden';
	@override String get descriptionOn => 'Kurze Namen für Upload-Tools, z. B. N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Lesbare Namen, z. B. 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$de extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Private Daten einbeziehen';
	@override String get descriptionOn => 'Namen, Adressen, E-Mails, Grids und Notizen werden einbezogen';
	@override String get descriptionOff => 'Namen, Adressen, E-Mails, Grids und Notizen werden weggelassen';
	@override String get note => 'Der vollständige ADIF-Export enthält immer alles';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$de extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Zuerst eine E-Mail-Adresse hinzufügen';
	@override String get needsEmailBody => 'Ham2K File Stash sendet deine Dateien an die E-Mail-Adresse deines LoFi-Kontos, und du meldest dich damit auf stash.ham2k.net an. Dein Konto hat noch keine bestätigte Adresse — füge sie unter Einstellungen › Cloud-Sync hinzu.';
	@override String get openSyncSettings => 'Cloud-Sync öffnen';
	@override String get replaceTitle => 'Letzter Stash wird ersetzt';
	@override String replaceBody({required Object name}) => 'Du hast „${name}“ vor weniger als 6 Stunden gesendet und es wurde noch nicht heruntergeladen. Kostenlose Konten behalten immer nur einen Stash, daher wird er beim Senden jetzt ersetzt.';
	@override String get replaceConfirm => 'Trotzdem senden';
	@override String get failedTitle => 'Senden an Ham2K File Stash fehlgeschlagen';
	@override String get sentTitle => 'An Ham2K File Stash gesendet';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Du kannst diese Datei abrufen, indem du **[stash.ham2k.net](https://stash.ham2k.net)** in einem beliebigen Browser aufrufst.',
		other: 'Du kannst diese Dateien abrufen, indem du **[stash.ham2k.net](https://stash.ham2k.net)** in einem beliebigen Browser aufrufst.',
	);
	@override String get mayHaveArrived => 'Keine Antwort vom Stash — die Datei ist vielleicht trotzdem angekommen. Prüfe stash.ham2k.net, bevor du erneut sendest';
	@override String get notSent => 'nicht gesendet';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: 'Diese Datei ist nicht angekommen:',
		other: 'Diese ${count} Dateien sind nicht angekommen:',
	);
	@override String get emailOffer => 'Oder wir können dir der Einfachheit halber eine E-Mail mit einem direkten Link senden.';
	@override String get emailMe => 'Link per E-Mail senden';
	@override String get emailSent => 'Wir haben dir einen Download-Link per E-Mail gesendet.';
	@override String emailFailed({required Object error}) => 'E-Mail konnte nicht gesendet werden: ${error}';
	@override String get freeTier => 'Kostenlose Konten können immer nur einen Stash gleichzeitig behalten. Abonnenten können so viele behalten, wie sie möchten.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count,
		one: '${count} Datei an Ham2K File Stash gesendet (stash.ham2k.net)',
		other: '${count} Dateien an Ham2K File Stash gesendet (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$de extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Asien';
	@override String get eu => 'Europa';
	@override String get na => 'Nordamerika';
	@override String get oc => 'Ozeanien';
	@override String get sa => 'Südamerika';
	@override String get an => 'Antarktis';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$de extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spots filtern';
	@override String get band => 'Band';
	@override String get mode => 'Modus';
	@override String get age => 'Alter';
	@override String get sources => 'Quellen';
	@override String get continent => 'Kontinent';
	@override String get sorting => 'Sortierung';
	@override String get sortByTime => 'Nach Spot-Zeit';
	@override String get sortByFrequency => 'Nach Frequenz';
	@override String get groupByBand => 'Nach Band gruppieren';
	@override String get groupCallsWithNotes => 'Rufzeichen mit Notizen gruppieren';
	@override String get sourceNoReply => 'Keine Antwort';
	@override String get sourceError => 'Fehler';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$de extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logging-Panel ist belegt';
	@override String get editingBody => 'Du bearbeitest gerade einen geloggten Kontakt. Stattdessen diesen Spot loggen oder zurückgehen und die Bearbeitung abschließen?';
	@override String get composingBody => 'Du hast begonnen, einen Kontakt einzugeben. Stattdessen diesen Spot loggen oder zurückgehen und die Eingabe abschließen?';
	@override String get goBack => 'Zurück';
	@override String get clearAndLog => 'Leeren und Spot loggen';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$de extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Linkshänder-Modus';
	@override String get descriptionOn => 'Das Layout für Linkshänder wird verwendet';
	@override String get descriptionOff => 'Das Layout für Rechtshänder wird verwendet';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$de extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Länderflaggen';
	@override String get dx => 'Nur für DX-Kontakte anzeigen';
	@override String get all => 'Flaggen für alle Kontakte anzeigen';
	@override String get none => 'Keine Flaggen anzeigen';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$de extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Flaggen werden nur für DX-Kontakte angezeigt';
	@override String get all => 'Flaggen werden für alle Kontakte angezeigt';
	@override String get none => 'Es werden keine Flaggen angezeigt';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$de extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operator vorschlagen';
	@override String get descriptionOn => 'Dein Rufzeichen wird als Operator vorgeschlagen, wenn ein Betrieb unter einem anderen Stationsrufzeichen läuft';
	@override String get descriptionOff => 'Operator bleibt leer, solange du ihn nicht ausfüllst';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$de extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Peilung anzeigen';
	@override String get descriptionOn => 'Geschätzte Peilung zur Station wird angezeigt';
	@override String get descriptionOff => 'Peilungsinformationen werden nicht angezeigt';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$de extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Auch Gegenpeilung anzeigen';
	@override String get descriptionOn => 'Peilung von der Station wird ebenfalls angezeigt, z. B. „45° / 225°“';
	@override String get descriptionOff => 'Nur die Peilung zur Station wird angezeigt';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$de extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rapport-Reihenfolge wechseln';
	@override String get sentFirst => 'Gesendet zuerst, Empfangen als zweites';
	@override String get rcvdFirst => 'Empfangen zuerst, Gesendet als zweites';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$de extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spring weiter bei RST-Eingabe';
	@override String get descriptionOn => 'Nach RST-Eingabe wird zum nächsten Feld gesprungen';
	@override String get descriptionOff => 'Es wird nicht automatisch gesprungen';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$de extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standard-Rapport — Phone';
	@override String get description => 'Wird verwendet, wenn Gesendet oder Empfangen bei SSB, FM oder AM leer bleibt';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$de extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standard-Rapport — CW und Digital';
	@override String get description => 'Wird verwendet, wenn Gesendet oder Empfangen bei CW, RTTY und anderen Digitalmodi leer bleibt';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$de extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Standard-Rapport — FT8 und FT4';
	@override String get description => 'Wird verwendet, wenn Gesendet oder Empfangen bei den FT-Modi leer bleibt';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$de extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zahlenreihe';
	@override String get description => 'Beim Loggen eine Reihe Zifferntasten über der Tastatur anzeigen';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$de extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Schrägstrich- und Punkttaste';
	@override String get description => 'Fügt eine kontextabhängige Taste hinzu: „/“ für Rufzeichen, „.“ für Zahlen';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$de extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibration bei Tastendruck';
	@override String get description => 'Haptisches Feedback beim Tippen auf eine Zifferntaste';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$de extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get off => 'Deaktiviert';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$de extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$de extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'PTT mit [\'] steuern';
	@override String get descriptionOn => 'In Phone-Modi tastet [\'] das Funkgerät auf und [\'] erneut wieder ab. Nach einer Minute tastet es von selbst ab.';
	@override String get descriptionOff => 'Die Taste [\'] tastet das Funkgerät nicht auf.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Sende';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$de extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart VFO Snap';
	@override String get descriptionOn => 'Wenn du aufhörst, am Knopf zu drehen, wird die Frequenz auf einen sinnvollen Schritt gerundet. Nur Sprachmodi.';
	@override String get descriptionOff => 'Bleibt genau dort, wo du abgestimmt hast.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$de extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart Snap: Wartezeit';
	@override String get description => 'Wie lange der Knopf stillstehen muss, bevor die Frequenz gerundet wird. Kürzer wirkt sofort; länger lässt Raum für eine langsame Bewegung.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$de extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart Snap: Lange Bewegung';
	@override String get description => 'Ab dieser Strecke wird die Frequenz auf ein ganzes kHz gerundet, egal wie langsam du zuletzt gedreht hast.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$de extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart Snap: Kleinste Bewegung';
	@override String get description => 'Unterhalb dieser Strecke wird die Frequenz nicht gerundet, damit Feinabstimmung unberührt bleibt.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$de extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Smart Snap: Langsamste Bewegung';
	@override String get description => 'Langsamer gedreht wird die Frequenz nicht gerundet, außer es war eine lange Bewegung.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$de extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Aus';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter sendet Nachrichten';
	@override String get off => 'Aus';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter sendet Nachrichten: ${state}. Tippen zum Ändern.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$de extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Keyer-Geschwindigkeit';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$de extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW-Keyer-Nachrichten';
	@override String get notSupported => 'Das aktuelle Funkgerät unterstützt keine CW-Tastung';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Nachricht (${n})';
	@override String get labelField => 'Beschriftung';
	@override String labelKey({required Object n}) => 'Beschriftung F${n}';
	@override String get details => 'Details';
	@override String get empty => '(leer)';
	@override String get sets => 'Nachrichtensatz';
	@override String get newSet => 'Neuer Satz';
	@override String get renameSet => 'Satz umbenennen';
	@override String get deleteSet => 'Satz löschen';
	@override String get newSetName => 'Name';
	@override String get setDefault => 'Standard';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM-Nachrichten';
	@override String get setSaved => 'Meine Nachrichten';
	@override String get repeat => 'Nachricht #1 wiederholen';
	@override String get repeatOff => 'Nein';
	@override String repeatAfter({required Object n}) => 'Nach ${n} Sekunden';
	@override String get repeatWait => 'Wiederholt';
	@override String get keyboard => 'Tippen zum Senden';
	@override String get keyboardField => 'Tippen zum Senden';
	@override String get closeArea => 'Keyer-Bereich schließen';
	@override String get help => 'Hilfe';
	@override String get helpTitle => 'CW-Nachrichten schreiben';
	@override String get helpIntro => 'Nachrichten können Vorlagen mit folgenden Werten verwenden:';
	@override String get helpOpCall => 'Dein Rufzeichen';
	@override String get helpQsoCall => 'Deren Rufzeichen — in einem //-Stapel das Rufzeichen, das geloggt wird';
	@override String get helpQsoFullCall => 'Deren Rufzeichen, wenn es ein gültiges ist; leer bei einem Teilrufzeichen';
	@override String get helpQsoPartial => 'Ein Teilrufzeichen; leer, wenn ein vollständiges gültiges Rufzeichen vorliegt';
	@override String get helpQsoNextCall => 'In einem //-Stapel das Rufzeichen, das als nächstes zum Loggen ausgewählt wird, wenn es ein gültiges vollständiges ist';
	@override String get helpQsoNextPartial => 'In einem //-Stapel das nächste Teilrufzeichen nach dem Loggen des aktuellen Kontakts';
	@override String get helpQsoName => 'Deren Vorname, wie eingegeben oder sonst aus der Abfrage';
	@override String get helpQsoState => 'Deren Staat, wie eingegeben oder sonst aus der Abfrage';
	@override String get helpKeyerMsg => 'Nachricht 1, wie sie gesendet würde, innerhalb einer anderen Nachricht. Gültig für Nachrichten 1 bis 8';
	@override String get helpQsoRst => 'Der Rapport, den du sendest';
	@override String get helpQsoSerial => 'Deine Seriennummer, in einem Contest, der eine sendet';
	@override String get helpPad => 'Füllt mit Nullen auf so viele Stellen auf: 7 wird als 007 gesendet';
	@override String get helpCut => 'Abgekürzte Zahlen, T für 0 und N für 9: 599 wird als 5NN gesendet';
	@override String get helpCutDigits => 'Wählt die abzukürzenden Ziffern, in Anführungszeichen — 0 ist T, 1 ist A, 5 ist E, 9 ist N';
	@override String get helpFullExample => 'Vollständiges Beispiel:';
	@override String get helpExample => 'Sendet W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Mit „Enter sendet Nachrichten“ sendet Enter Nachrichten über ihre Funktionstaste, wie bei N1MM. Der Satz ESM-Nachrichten beginnt mit diesen:';
	@override String get helpEsmCq => 'Im Run ruft Enter bei leerem Rufzeichenfeld CQ';
	@override String get helpEsmExchange => 'Dein Austausch: im Run nach deren Rufzeichen, bei S&P nachdem sie antworten';
	@override String get helpEsmThanks => 'Dank, sobald der Kontakt geloggt ist: die Platzhalter beziehen sich auf den nächsten Kontakt, nicht auf diesen';
	@override String get helpEsmMyCall => 'Bei S&P dein Rufzeichen an die Station, die du anrufst';
	@override String get helpEsmHisCall => 'Im Run deren Rufzeichen vor deinem Austausch';
	@override String get helpEsmAgain => 'Fragt erneut, wenn nichts von deren Austausch aufgenommen wurde';
	@override String get helpEsmStackThanks => 'Vorschlag für F3 bei //-Stapeln: TU geht raus, nachdem der Kontakt geloggt ist, also bedankt es sich, ruft dann die nächste gestapelte Station und sendet deinen Austausch oder fragt ein Teilrufzeichen zurück (TU KR?); ist nichts mehr übrig, nur TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$de extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Phone-Keyer-Nachrichten';
	@override String get notSupported => 'Das aktuelle Funkgerät unterstützt keine Phone-Nachrichten';
	@override String get description => 'Dies nutzt die Sprachspeicher des Funkgeräts';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Sprachspeicher (${n})';
	@override String get labelField => 'Beschriftung';
	@override String labelKey({required Object n}) => 'Beschriftung Sprachspeicher ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Leer';
	@override String get notMeasured => 'Länge unbekannt';
	@override String get playButton => 'Abspielen';
	@override String get recordButton => 'Aufnehmen';
	@override String get stopButton => 'Stopp';
	@override String get repeat => 'Nachricht #1 wiederholen';
	@override String get repeatOff => 'Nein';
	@override String repeatAfter({required Object n}) => 'Nach ${n} Sekunden';
	@override String recordHelpTitle({required Object model}) => 'Hinweise zum ${model}:';
	@override String namedOnDevice({required Object device}) => 'Diese Speicher sind im Funkgerät von ${device}. Ihre Namen und Längen gehören zu diesem Gerät.';
	@override String get namedOnRadio => 'Im Funkgerät gespeichert, wo auch seine anderen Clients es sehen.';
	@override String get recordHelpYaesuDvs => 'Warte auf die Anzeige [REC] am Funkgerät, halte dann die PTT-Taste und sprich deine Nachricht. Beende sie mit der STOP-Taste hier in der App, bevor du die PTT loslässt, um unerwünschte Klicks zu vermeiden.';
	@override String get recordHelpFt891 => 'Warte, bis die Anzeige [REC] mindestens viermal blinkt, halte dann die PTT-Taste und sprich deine Nachricht. Beende sie mit der STOP-Taste hier in der App, bevor du die PTT loslässt, um unerwünschte Klicks zu vermeiden.';
	@override String get pill => 'Sprache';
	@override String play({required Object n}) => 'Speicher ${n} abspielen';
	@override String get stop => 'Stopp';
	@override String record({required Object n}) => 'Speicher ${n} aufnehmen';
	@override String get stopRecording => 'Aufnahme beenden';
	@override String get playing => 'Spielt ab…';
	@override String get recording => 'Nimmt auf…';
	@override String playingMemory({required Object label}) => '${label} wird abgespielt';
	@override String recordingMemory({required Object label}) => '${label} wird aufgenommen';
	@override String get doubtful => 'Hat das Funkgerät es abgespielt? Es meldete sofort Leerlauf.';
	@override String get recordOnRadio => 'Die Speicher müssen direkt am Funkgerät aufgenommen werden.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$de extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zero-Beat bei Spots vermeiden';
	@override String get descriptionOn => 'Bei verbundenem Funkgerät wird ein paar Hz neben einem CW-Spot abgestimmt, damit nicht alle Anrufer auf demselben Ton rufen.';
	@override String get descriptionOff => 'Genau auf die gespottete Frequenz abstimmen.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$de extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zero-Beat: Ausweichbereich';
	@override String get description => 'Wie weit neben der gespotteten Frequenz, zu beiden Seiten, abgestimmt wird. Der Versatz ist nie nahe null — das wäre wieder Zero-Beat.';
}

// Path: settings.map.style
class _Translations$settings$map$style$de extends Translations$settings$map$style$en {
	_Translations$settings$map$style$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kartenstil';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$de extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatisch';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$de extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'App-Nutzungsdaten teilen';
	@override String get descriptionOn => 'Du hilfst uns, die App zu verbessern, indem du Nutzungs-, Konfigurations-, Absturz- und Leistungsdaten teilst';
	@override String get descriptionOff => 'App-Nutzungsdaten bleiben privat.\nDas Ham2K-Team kann Abstürze oder andere Probleme nicht erkennen.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$de extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get title => 'Betriebsdaten teilen';
	@override String get descriptionOn => 'Einige Betriebsdaten werden öffentlich und mit anderen Nutzern geteilt';
	@override String get descriptionOff => 'Betriebsdaten bleiben privat';
}

// Path: settings.station.models
class _Translations$settings$station$models$de extends Translations$settings$station$models$en {
	_Translations$settings$station$models$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Generisch';
	@override String get icomGeneric => 'Icom - Generisch';
	@override String get kenwoodGeneric => 'Kenwood - Generisch';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Generisch';
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
	@override String get rigctld => 'Funkgerät über rigctld gesteuert';
	@override String get rigctldNodeName => 'Mein Funkgerät (über rigctld)';
	@override String get flrig => 'Funkgerät über flrig gesteuert';
	@override String get flrigNodeName => 'Mein Funkgerät (über flrig)';
	@override String get hrd => 'Funkgerät über Ham Radio Deluxe® gesteuert';
	@override String get hrdNodeName => 'Mein Funkgerät (über HRD)';
	@override String get n3fjp => 'Funkgerät über N3FJP gesteuert';
	@override String get n3fjpNodeName => 'Mein Funkgerät (über N3FJP)';
	@override String get commander => 'Funkgerät über DXLab Commander gesteuert';
	@override String get commanderNodeName => 'Mein Funkgerät (über Commander)';
	@override String get antenna => 'Antenne';
	@override String get key => 'CW-Taste';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Generisches Funkgerät (Platzhalter)';
	@override String get placeholderRadioNodeName => 'Mein Funkgerät';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Koaxschalter';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$de extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get network => 'Netzwerk/WLAN';
	@override String get usbSerial => 'USB Seriell';
	@override String get wifi => 'Netzwerk/WLAN';
	@override String get bluetoothSerial => 'Bluetooth Seriell';
	@override String get placeholder => 'Platzhalter';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$de extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipol';
	@override String get vertical => 'Vertikal';
	@override String get yagiBeam => 'Yagi / Beam';
	@override String get loop => 'Loop';
	@override String get longWire => 'Langdraht / EFHW';
	@override String get other => 'Andere';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$de extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Handtaste';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mechanische halbautomatische Taste)';
	@override String get fullyAutomatic => 'Vollautomatischer Keyer';
	@override String get singlePaddle => 'Einhebel-Paddle';
	@override String get dualPaddle => 'Doppelhebel-Paddle';
	@override String get computerDriven => 'Computergesteuert';
	@override String get other => 'Andere';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$de extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$de._(TranslationsDe root) : this._root = root, super.internal(root);

	final TranslationsDe _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Unbekannt';
	@override String get sunny => 'Sonnig';
	@override String get clear => 'Klar';
	@override String get mainlySunny => 'Überwiegend sonnig';
	@override String get mainlyClear => 'Überwiegend klar';
	@override String get partlyCloudy => 'Teilweise bewölkt';
	@override String get cloudy => 'Bewölkt';
	@override String get foggy => 'Neblig';
	@override String get rimeFog => 'Reifnebel';
	@override String get lightDrizzle => 'Leichter Nieselregen';
	@override String get drizzle => 'Nieselregen';
	@override String get heavyDrizzle => 'Starker Nieselregen';
	@override String get lightFreezingDrizzle => 'Leichter gefrierender Nieselregen';
	@override String get freezingDrizzle => 'Gefrierender Nieselregen';
	@override String get lightRain => 'Leichter Regen';
	@override String get rain => 'Regen';
	@override String get heavyRain => 'Starker Regen';
	@override String get lightFreezingRain => 'Leichter gefrierender Regen';
	@override String get freezingRain => 'Gefrierender Regen';
	@override String get lightSnow => 'Leichter Schneefall';
	@override String get snow => 'Schneefall';
	@override String get heavySnow => 'Starker Schneefall';
	@override String get snowGrains => 'Schneegriesel';
	@override String get lightShowers => 'Leichte Schauer';
	@override String get showers => 'Schauer';
	@override String get heavyShowers => 'Starke Schauer';
	@override String get lightSnowShowers => 'Leichte Schneeschauer';
	@override String get snowShowers => 'Schneeschauer';
	@override String get thunderstorm => 'Gewitter';
	@override String get lightThunderstormsWithHail => 'Leichte Gewitter mit Hagel';
	@override String get thunderstormWithHail => 'Gewitter mit Hagel';
}

/// The flat map containing all translations for locale <de>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsDe {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Speichern',
			'common.ok' => 'OK',
			'common.cancel' => 'Abbrechen',
			'common.delete' => 'Löschen',
			'common.create' => 'Erstellen',
			'common.error' => 'Fehler',
			'common.close' => 'Schließen',
			'common.done' => 'Fertig',
			'common.callsign' => 'Rufzeichen',
			'common.clear' => 'Leeren',
			'common.dismiss' => 'Ausblenden',
			'common.expand' => 'Ausklappen',
			'common.collapse' => 'Einklappen',
			'onboarding.welcomeTitle' => 'Willkommen beim Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Willkommen beim Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Wir haben ein paar Fragen, damit die App besser zu dir passt.',
			'onboarding.skip' => 'Überspringen',
			'onboarding.kContinue' => 'Weiter',
			'onboarding.back' => 'Zurück',
			'onboarding.next' => 'Weiter',
			'onboarding.done' => 'Fertig',
			'onboarding.callsignTitle' => 'Wie lautet dein Rufzeichen?',
			'onboarding.callsignBody' => 'Diese App ist nur mit einer Amateurfunklizenz wirklich nützlich',
			'onboarding.callsignLabel' => 'Rufzeichen des Betreibers',
			'onboarding.alreadyHaveAccount' => 'Du hast schon ein Konto?',
			'onboarding.foundSiblingTitle' => 'Bestehendes Konto verknüpfen?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Wir haben ${app} auf diesem Gerät gefunden. Verknüpfe diese App mit demselben Konto, dann werden dein Rufzeichen und deine Logs übernommen.',
			'onboarding.foundPoloBody' => 'Wir haben eine ältere Version des Ham2K Portable Logger auf diesem Gerät gefunden. Verknüpfe diese App mit demselben Konto, dann werden dein Rufzeichen und deine Logs übernommen.',
			'onboarding.foundSiblingsBody' => 'Wir haben andere Ham2K-Apps auf diesem Gerät gefunden. Verknüpfe diese App mit einem ihrer Konten, dann werden dein Rufzeichen und deine Logs übernommen.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Mit ${app} verknüpfen',
			'onboarding.linkWithPolo' => 'Mit Konto der älteren Version verknüpfen',
			'onboarding.setUpFresh' => 'Neu einrichten',
			'onboarding.activitiesTitle' => 'Lieblingsaktivitäten',
			'onboarding.activitiesBody' => 'Interessierst du dich für eines dieser beliebten Aktivierungsprogramme?',
			'onboarding.activitiesFooter' => '(Weitere Optionen findest du in den Einstellungen)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Daten & Datenschutz',
			'onboarding.consentUsageBody' => 'Um die App zu verbessern, würden wir gerne Leistungs-, Absturz- und Nutzungsdaten erfassen.',
			'onboarding.consentUsageLabel' => 'App-Nutzungsdaten teilen',
			'onboarding.consentOperationBody' => 'Einige Funktionen können deine Betriebsdaten mit anderen Nutzern teilen. Du kannst das jederzeit abschalten.',
			'onboarding.consentOperationLabel' => 'Betriebsdaten teilen',
			'onboarding.finishingSetup' => 'Einrichtung wird abgeschlossen — Referenzdaten werden heruntergeladen…',
			'startScreen.credits' => 'von KI2D und Freunden',
			'testerOverlay.tape' => 'ACHTUNG: BAUSTELLE',
			'testerOverlay.warningTitle' => 'Diese App ist noch in Arbeit',
			'testerOverlay.warningBody' => 'Die meisten Funktionen haben unebene Oberflächen und überall lauern Stolperfallen. Bitte prüfe regelmäßig auf Updates.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Neu in Build ${build}',
			'testerOverlay.thanks' => 'Danke, dass du dein Log riskierst, um uns zu helfen, diese App besser zu machen!',
			'extensionsPanel.categoryActivity' => 'Aktivitäten',
			'extensionsPanel.categoryContest' => 'Contests',
			'extensionsPanel.categoryLookup' => 'Rufzeichenabfragen',
			'extensionsPanel.categorySpots' => 'Spot-Quellen',
			'extensionsPanel.categoryDashboard' => 'Dashboard-Panels',
			'extensionsPanel.categoryOther' => 'Andere Erweiterungen',
			'extensionsPanel.searchHint' => 'Erweiterungen durchsuchen',
			'extensionsPanel.applying' => 'Änderungen an Erweiterungen werden aktiviert, dies kann einen Moment dauern…',
			'extensionsPanel.noMatches' => 'Keine Erweiterung passt zu deiner Suche',
			'extensionsPanel.installFromFile' => 'Aus Datei installieren…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Version ${version}',
			'extensionsPanel.canReach' => 'Diese Erweiterung kann Folgendes kontaktieren',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, über eine Live-Verbindung',
			'extensionsPanel.canHoldLocalConnection' => 'Geräte in deinem lokalen Netzwerk, über eine Live-Verbindung',
			'extensionsPanel.canUseLocation' => 'Deinen Standort',
			'extensionsPanel.canReadRadio' => 'Dein Funkgerät, um Frequenz und Modus zu lesen',
			'extensionsPanel.canControlRadio' => 'Dein Funkgerät, um es zu steuern und damit zu senden — Abstimmung, Leistung, CW, Sprachspeicher und PTT',
			'extensionsPanel.canSetUserAgent' => 'Sich gegenüber Servern unter eigenem Namen ausweisen',
			'extensionsPanel.noCapabilities' => 'Sie benötigt nichts außerhalb der App.',
			'extensionsPanel.sandboxNote' => 'Erweiterungen laufen in einer Sandbox: kein Zugriff auf deine Dateien und kein Netzwerk außer dem hier Aufgeführten.',
			'extensionsPanel.installAction' => 'Installieren',
			'extensionsPanel.updateAction' => 'Aktualisieren',
			'extensionsPanel.installFailed' => 'Diese Erweiterung konnte nicht installiert werden',
			'extensionsPanel.installedBadge' => 'Installiert',
			'extensionsPanel.uninstallAction' => 'Entfernen',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '${name} entfernen?',
			'extensionsPanel.uninstallBody' => 'Diese Erweiterung und ihre Einstellungen werden entfernt. Deine Logs bleiben unverändert.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} installiert',
			'extensionsPanel.installDownloading' => 'Lade herunter…',
			'extensionsPanel.installWaiting' => 'Warte auf Installation…',
			'extensionsPanel.installInstalling' => 'Installiere…',
			'extensionsPanel.installAwaitingApproval' => 'Warte auf deine Zustimmung…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} wird bereits installiert.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Aktualisiert auf ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Die Installation von ${name} wurde nicht abgeschlossen. Sie muss eventuell wiederholt werden.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name} konnte nicht entfernt werden',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Heruntergeladen von ${source}',
			'extensionsPanel.dropHint' => 'Lege eine .h2kext-Erweiterung hier ab, um sie zu installieren',
			'extensionsPanel.dropOneOnly' => 'Lege immer nur eine Erweiterung ab.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} lieferte ${status} für diese Erweiterung.',
			'extensionsPanel.downloadTooLarge' => 'Dieser Download ist viel zu groß für eine Erweiterung.',
			'extensionsPanel.downloadNotSecure' => 'Dieser Download wurde an eine unsichere Adresse umgeleitet.',
			'extensionsPanel.catalogSection' => 'Katalog',
			'extensionsPanel.catalogLoading' => 'Katalog wird geladen…',
			'extensionsPanel.catalogUnreachable' => 'Katalog nicht erreichbar',
			'extensionsPanel.builtIn' => 'Integriert',
			'extensionsPanel.updateAvailableBadge' => 'Update verfügbar',
			'extensionsPanel.updatesAvailableTitle' => 'Erweiterungs-Updates',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Für ${name} ist ein Update verfügbar.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} und ${count} weitere müssen aktualisiert werden.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} müssen aktualisiert werden.',
			'extensionsPanel.pendingUpdatesSection' => 'Ausstehende Updates',
			'extensionsPanel.updateAllAction' => 'Alle aktualisieren',
			'extensionsPanel.updatesUnderWay' => 'Diese Updates laufen bereits.',
			'extensionsPanel.updatesNothingLeft' => 'Deine Erweiterungen sind auf dem neuesten Stand.',
			'extensionsPanel.updatesNoticeAction' => 'Mehr Infos',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Erweiterung aktualisieren?', other: '${count} Erweiterungen aktualisieren?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Deine Erweiterungen sind bereit',
			'extensionsPanel.upgradeDoneBody' => 'Sie kommen jetzt aus dem Ham2K-Erweiterungskatalog und können daher aktualisiert werden, ohne auf eine neue Version der App zu warten.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Nicht umgestellt: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Startet nicht: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Sie sind weiterhin installiert und unter Einstellungen › Erweiterungen markiert — ein Update dort bringt sie zurück.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Der Katalog hat keinen direkten Ersatz dafür, such dort nach Erweiterungen, die abdecken, was du genutzt hast.',
			'extensionsPanel.retiredQp' => 'QSO-Parties',
			'extensionsPanel.retiredStateparks' => 'State-Parks-Events',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} deiner Erweiterungen sind noch nicht angekommen. Sie werden heruntergeladen, sobald der Erweiterungskatalog das nächste Mal erreichbar ist.',
			'extensionsPanel.runtimeDeadBody' => 'Deine Erweiterungen starten nicht. Ein Neustart der App sollte sie zurückbringen.',
			'extensionsPanel.refusedTitle' => 'Einige Erweiterungen starten nicht',
			'extensionsPanel.upgradeBusyTitle' => 'Einrichtung läuft noch',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Deine Erweiterungen laufen nicht',
			'extensionsPanel.restoreTitle' => 'Einige deiner Erweiterungen fehlen',
			'extensionsPanel.restoreBody' => 'Diese von dir installierten Erweiterungen sind nicht auf diesem Gerät. Wir können sie erneut aus dem Ham2K-Erweiterungskatalog herunterladen:',
			'extensionsPanel.restoreFromFile' => 'Aus einer Datei installiert. Installiere sie erneut aus ihren Dateien oder vergiss sie:',
			'extensionsPanel.restoreOtherCatalog' => 'Aus einem anderen Erweiterungskatalog installiert, daher hier nicht verfügbar:',
			'extensionsPanel.restoreForget' => 'Vergessen',
			'extensionsPanel.restoreInstall' => 'Installieren',
			'extensionsPanel.restoreLater' => 'Später',
			'extensionsPanel.restoreInstalling' => 'Deine Erweiterungen werden installiert…',
			'extensionsPanel.restoreDoneTitle' => 'Deine Erweiterungen sind zurück',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Erneut installiert: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Einige Erweiterungen konnten nicht installiert werden',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Nicht installiert: ${names}. Wir bieten sie beim nächsten Öffnen der App erneut an.',
			'extensionsPanel.restoreBusyBody' => 'Die App richtet deine Erweiterungen noch ein. Wir bieten sie beim nächsten Öffnen der App erneut an.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Wir haben sie erneut installiert, aber deine Erweiterungen starten nicht. Ein Neustart der App sollte sie zurückbringen.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} wurde zurückgezogen',
			'extensionsPanel.revokedBody' => 'Der Katalog hat diese Version zurückgezogen, daher wurde sie deaktiviert.',
			'extensionsPanel.downloadHashMismatch' => 'Dieser Download ist nicht die Erweiterung, die der Katalog beschreibt.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Der Katalog hat keine Version ${version} von ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Dieser Katalog-Link nennt keine Erweiterungsversion.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Der Katalog hat kein Release von ${key} in diesem Zweig.',
			'extensionsPanel.installFromLink' => 'Über Link installieren',
			'extensionsPanel.unstableReleaseWarning' => 'Dies ist ein instabiles Release, das der Herausgeber noch nicht als fertig bezeichnet. Es kann sich fehlerhaft verhalten und erhält weiterhin instabile Updates.',
			'extensionsPanel.bleedingReleaseWarning' => 'Dies ist ein experimentelles Release: in Arbeit, kann fehlschlagen oder seine Einstellungen verlieren. Es erhält weiterhin experimentelle Updates.',
			'extensionsPanel.channelUnstable' => 'Instabil',
			'extensionsPanel.channelBleeding' => 'Experimentell',
			'extensionsPanel.followsUnstable' => 'Erhält instabile und stabile Releases',
			'extensionsPanel.followsBleeding' => 'Erhält experimentelle, instabile und stabile Releases',
			'extensionsPanel.followStableAction' => 'Nur stabile Releases verwenden',
			'extensionsPanel.revokedBadge' => 'Zurückgezogen',
			'extensionsPanel.refusedBadge' => 'Nicht geladen',
			'extensionsPanel.downloadNotHttps' => 'Dieser Download erfolgt nicht über eine sichere Verbindung.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} war für diese Erweiterung nicht erreichbar.',
			'extensionsPanel.detailsAction' => 'Details',
			'extensionsPanel.installedFromFile' => 'Aus einer Datei installiert',
			'extensionsPanel.detailsWhatItDoes' => 'Bietet Unterstützung für',
			'extensionsPanel.installedPreloaded' => 'Vorinstalliert',
			'extensionsPanel.hookAccount' => 'Konto-Anmeldung',
			'extensionsPanel.hookCallNotes' => 'Rufzeichennotizen',
			'extensionsPanel.hookDataFile' => 'Offline-Daten',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Rufzeichenabfragen',
			'extensionsPanel.hookScoring' => 'Punktewertung',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => '${program} jagen',
			'extensionsPanel.hookActivating' => ({required Object program}) => '${program} aktivieren',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '… und ${count} weitere Erweiterung', other: '… und ${count} weitere Erweiterungen', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Erweiterung verfügbar', other: '${count} Erweiterungen verfügbar', ), 
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'Neuer Betrieb',
			'home.stationCallsign' => 'Stationsrufzeichen',
			'home.titleOptional' => 'Titel (optional)',
			'home.emptyList' => 'Noch kein Betrieb. Erstelle einen, um mit dem Loggen zu beginnen.',
			'home.quickLookup' => 'Schnellabfrage',
			'home.nav.operations' => 'Betrieb',
			'home.nav.chase' => 'Jagd',
			'home.nav.logs' => 'Logs',
			'home.nav.maps' => 'Karten',
			'home.nav.settings' => 'Einstellungen',
			'home.panels.operations' => 'Betriebsliste',
			'home.panels.operationsDescription' => 'Dein Funkbetrieb, der neueste zuerst.',
			'home.panels.version' => 'Aktuelle Version',
			'home.panels.versionDescription' => 'Das Ham2K-Logo, der Name dieser App und welcher Build läuft.',
			'home.toggleNav' => 'Navigationsbeschriftungen ein- oder ausblenden',
			'home.logs.title' => 'Logs',
			'home.logs.titleFor' => 'Logs für',
			'home.logs.emptyCallsigns' => 'Noch keine QSOs geloggt',
			'home.logs.emptyQsos' => ({required Object call}) => 'Keine QSOs für ${call}',
			'home.logs.mapNoSelection' => 'Wähle ein QSO, um es auf der Karte zu sehen',
			'home.logs.searchHint' => 'Rufzeichen oder Name suchen',
			'home.logs.noSearchMatches' => 'Keine QSOs passen zu deiner Suche',
			'home.logs.titleAll' => 'Alle Logs',
			'home.logs.allCallsigns' => 'Alle Rufzeichen',
			'home.logs.noOperation' => 'Gehört zu keinem Betrieb',
			'home.logs.unsavedTitle' => 'Ungespeicherte Änderungen',
			'home.logs.unsavedBody' => 'Dieses QSO hat Änderungen, die du nicht gespeichert hast.',
			'home.logs.pendingDeleteBody' => 'Dieses QSO ist zum Löschen markiert.',
			'home.logs.editGone' => 'Nicht gespeichert: Dieses QSO ist nicht mehr in diesem Log.',
			'home.logs.discard' => 'Verwerfen',
			'home.logs.columns.date' => 'Datum',
			'home.logs.columns.time' => 'Zeit',
			'home.logs.columns.freq' => 'Frequenz',
			'home.logs.columns.mode' => 'Modus',
			'home.logs.columns.call' => 'Rufzeichen',
			'home.logs.columns.name' => 'Name',
			'home.logs.columns.station' => 'Station',
			'home.logs.columns.band' => 'Band',
			'home.logs.columns.sent' => 'Gesendet',
			'home.logs.columns.rcvd' => 'Empf.',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'Staat',
			'home.logs.columns.country' => 'Land',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'QSO-Log',
			'home.logs.panels.qsosDescription' => 'Die QSOs des ausgewählten Rufzeichens, über alle Betriebe hinweg.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Gesamtzahl der QSOs oder die Rufzeichenabfrage des ausgewählten QSOs.',
			'home.logs.panels.map' => 'Karte',
			'home.logs.panels.mapDescription' => 'Der Standort des ausgewählten QSOs.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Rufzeichen: ${calls}',
			'home.logs.import.skippedOne' => '1 Eintrag konnte nicht gelesen werden',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} Einträge konnten nicht gelesen werden',
			'home.logs.import.readingTitle' => 'ADIF-Datei wird gelesen…',
			'home.logs.import.checkingTitle' => 'Suche nach Duplikaten…',
			'home.logs.import.importingTitle' => 'QSOs werden importiert…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} von ${total} geprüft',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} von ${total} importiert',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'jagt',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} & mehr',
			'chase.station.title' => 'Jagende Station',
			'chase.station.stationLabel' => 'Station: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Kein Standort',
			'chase.periodInline.today' => 'heute',
			'chase.periodInline.thisWeek' => 'diese Woche',
			'chase.periodInline.last14Days' => 'in den letzten 14 Tagen',
			'chase.periodInline.thisMonth' => 'diesen Monat',
			'chase.periodStats.today' => 'Statistik für heute',
			'chase.periodStats.thisWeek' => 'Statistik für diese Woche',
			'chase.periodStats.last14Days' => 'Statistik der letzten 14 Tage',
			'chase.periodStats.thisMonth' => 'Statistik für diesen Monat',
			'chase.period.today' => 'Heute',
			'chase.period.thisWeek' => 'Diese Woche',
			'chase.period.last14Days' => 'Letzte 14 Tage',
			'chase.period.thisMonth' => 'Dieser Monat',
			'chase.goals.title' => 'Jagdziele',
			'chase.goals.remove' => ({required Object name}) => '${name} nicht mehr jagen',
			'chase.goals.extensionsTitle' => 'Erweiterungen mit Jagd-Funktion',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Logging-Steuerungen über den im Zeitraum gejagten QSOs.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Das gerade geloggte Rufzeichen oder die Statistik des Zeitraums.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Gespottete Stationen in der Luft, bereit zum Jagen.',
			'chase.panels.map' => 'Karte',
			'chase.panels.mapDescription' => 'Die QSOs des Zeitraums und die gerade geloggte Station.',
			'dialogs.operationDetails' => 'Betriebs-Details',
			'dialogs.activities' => 'Aktivitäten',
			'dialogs.stationCallsign' => 'Stationsrufzeichen',
			'dialogs.multiStationIdentifier' => 'Kennung für Mehrfachstation (nur Zahlen)',
			'dialogs.notes' => 'Notizen',
			'dialogs.deleteOperationTitle' => 'Betrieb löschen',
			'dialogs.purgeTestsTitle' => 'Testbetriebe endgültig löschen',
			'dialogs.purgeTestsBody' => 'Dies löscht diese Testbetriebe und ihre QSOs dauerhaft. Das kann nicht rückgängig gemacht werden.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Dazu ${count} Testkontakt, der zu keinem Betrieb gehört.', other: 'Dazu ${count} Testkontakte, die zu keinem Betrieb gehören.', ), 
			'dialogs.purgeTestsAction' => 'Endgültig löschen',
			'dialogs.syncAllTitle' => 'Log dieses Geräts ersetzen?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL sichert und entfernt ${qsos} von diesem Gerät und lädt dann das Log des Kontos erneut vom Server herunter. Die Sicherung bleibt in der Datenbank dieses Geräts.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${n} QSO wurde noch nicht synchronisiert — der Server hat es nie erhalten, und es kommt NICHT zurück.', other: '${n} QSOs wurden noch nicht synchronisiert — der Server hat sie nie erhalten, und sie kommen NICHT zurück.', ), 
			'dialogs.syncAllAction' => 'Löschen und neu synchronisieren',
			'dialogs.receivedPurgesTitle' => 'Testbetriebe anderswo entfernt',
			'dialogs.receivedPurgesBody' => 'Diese wurden auf einem anderen Gerät als Testbetriebe gelöscht. Auch hier entfernen? Das löscht sie und ihre QSOs dauerhaft und kann nicht rückgängig gemacht werden.',
			'dialogs.receivedPurgesAction' => 'Entfernen',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Ungültiges Rufzeichen: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Ungültige Rufzeichen: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Bisher hat ${previous} gefunkt. ${typed} wird für neue Kontakte eingetragen.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Bisher ist kein Operator eingetragen. ${typed} wird für neue Kontakte eingetragen.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Dieser Betrieb hat bereits Kontakte von ${calls}. ${typed} wird nur für neue eingetragen.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${typed} auch als Operator des bereits geloggten Kontakts eintragen', other: '${typed} auch als Operator aller ${count} bereits geloggten Kontakte eintragen', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Bei mehreren Stationsrufzeichen werden getrennte Operatoren nicht unterstützt',
			'dialogs.callChange.contactsUnreadable' => 'Die Kontakte dieses Betriebs konnten nicht gelesen werden, daher wird beim Ändern eines Rufzeichens hier keine Aktualisierung angeboten',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Die bereits geloggten Kontakte konnten nicht aktualisiert werden, daher wurde nichts geändert: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} von ${planned} Kontakten wurden aktualisiert — die übrigen sind nicht mehr in diesem Betrieb',
			'operation.deletedReadOnly' => 'Dieser Betrieb ist gelöscht. Stelle ihn wieder her, um zu loggen oder Änderungen vorzunehmen.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'KARTE',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Uhr',
			'operation.tabs.weather' => 'Wetter',
			'operation.tabs.website' => 'Webseite',
			'operation.tabs.remoteScreen' => 'Entfernter Bildschirm',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Funkgerät',
			'operation.positions.nobodyYet' => 'Noch teilen keine anderen Funkplätze diesen Betrieb.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Anderer Funkplatz',
			'operation.positions.thisDevice' => 'Unser Funkplatz',
			'operation.positions.nameIn' => ' in ',
			'operation.positions.panelTitle' => 'Funkplätze',
			'operation.positions.panelDescription' => 'Was jeder Funkplatz, der diesen Betrieb teilt, gerade loggt.',
			'operation.stationCallsignNone' => 'Kein Stationsrufzeichen',
			'operation.titleNone' => 'Kein Titel',
			'operation.deleteOperation' => 'Betrieb löschen',
			'operation.loggingControlsStale' => 'Aktivitätsfelder sind evtl. veraltet — öffne den Betrieb erneut, um sie zu aktualisieren',
			'operation.locationNone' => 'Nicht festgelegt',
			'operation.generalOperation' => 'Allgemeiner Betrieb',
			'operation.titleFor' => ({required Object value}) => 'für ${value}',
			'operation.titleAt' => ({required Object value}) => 'bei ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Jetzt ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'RST-Felder anzeigen',
			'operation.menu.showStateField' => 'Staat-Feld anzeigen',
			'operation.menu.showGridField' => 'Grid-Feld anzeigen',
			'operation.menu.showDeletedQsos' => 'Gelöschte QSOs anzeigen',
			'operation.menu.showDeletedOps' => 'Gelöschten Betrieb anzeigen',
			'operation.menu.showQsoNumbers' => 'QSO-Nummern anzeigen',
			'operation.menu.lookupAllQsos' => 'Alle QSOs nachschlagen',
			'operation.menu.loggingSettingsTitle' => 'Logging-Einstellungen',
			'operation.menu.mapSettingsTitle' => 'Karteneinstellungen',
			'operation.menu.actionsSection' => 'Aktionen',
			'operation.layout.title' => 'Panel hinzufügen',
			'operation.layout.availableSection' => 'Verfügbare Panels',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Einstellungen für ${panel}',
			'operation.layout.panelSettingsAction' => 'Panel-Einstellungen',
			'operation.layout.viewName' => 'Betriebsansicht',
			'operation.layout.viewOptions' => 'Optionen für das Ansichtslayout',
			'operation.layout.viewTitleBuiltIn' => 'Diese Ansicht ist in die App eingebaut, ebenso ihr Name',
			'operation.layout.resetOptions' => 'Standard wiederherstellen',
			'operation.layout.removePane' => 'Entfernen',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '${panel} auf Standard zurücksetzen?',
			'operation.layout.resetPaneConfirmBody' => 'Titel, Kopfzeile und Größe werden auf Standard zurückgesetzt. Der Rest des Layouts bleibt unverändert.',
			'operation.layout.resetViewConfirm' => 'Diese Ansicht auf ihr Standardlayout zurücksetzen?',
			'operation.layout.resetViewConfirmBody' => 'Die Panels kehren zu ihrer Standardanordnung zurück, und die Optionen der Ansicht und aller Panels werden auf Standard zurückgesetzt.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Layout-Einstellungen für ${panel}',
			'operation.layout.paneTitle' => 'Titel',
			'operation.layout.paneShowHeader' => 'Kopfzeile anzeigen',
			'operation.layout.paneShowHeaderTabset' => 'Immer sichtbar, solange dieser Bereich eine Gruppe teilt — über die Kopfzeile erreicht man die anderen',
			'operation.layout.paneInherit' => 'Wie die App',
			'operation.layout.searchHint' => 'Panels durchsuchen',
			'operation.layout.noPanelsMatch' => 'Kein Panel passt zu deiner Suche.',
			'operation.layout.nothingToAdd' => 'Diese Ansicht hat bereits alle möglichen Panels',
			'operation.layout.addPanel' => ({required Object panel}) => '${panel} hinzufügen',
			'operation.layout.showPreview' => ({required Object panel}) => 'Vorschau von ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Erweiterung „${name}“ fehlt',
			'operation.layout.previewUnavailable' => 'Das Vorschaubild dieses Panels konnte nicht angezeigt werden.',
			'operation.layout.nestedPaneTitle' => 'Mehr',
			'operation.layout.editLayout' => 'Layout bearbeiten',
			'operation.layout.saveLayout' => 'Layout speichern',
			'operation.layout.revertLayout' => 'Layout-Änderungen verwerfen',
			'operation.layout.done' => 'Fertig',
			'operation.layout.layoutUnreadableTitle' => 'Layout konnte nicht gelesen werden',
			'operation.layout.layoutUnreadableBody' => 'Dein gespeichertes Layout konnte nicht gelesen werden, daher wird stattdessen die Standardanordnung angezeigt. Dein Original wird erst überschrieben, wenn du dich entscheidest, diese zu behalten.',
			'operation.layout.layoutUnreadableAction' => 'Dieses Layout verwenden',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} konnte nicht angezeigt werden',
			'operation.layout.panelRenderRetry' => 'Erneut versuchen',
			'operation.layout.panelActionFailed' => 'Diese Panel-Aktion ist fehlgeschlagen. Versuche es erneut.',
			'operation.layout.panels.loggingDescription' => 'Das Log und die Eingabefelder',
			'operation.layout.panels.infoDescription' => 'Was wir über die gearbeitete Station wissen',
			'operation.layout.panels.spotsDescription' => 'Spots von Clustern und Aktivitätsprogrammen',
			'operation.layout.panels.mapDescription' => 'Wo die Kontakte sind',
			'operation.layout.panels.clockDescription' => 'Ein Zifferblatt, in beliebiger Zeitzone',
			'operation.layout.panels.clockFace' => 'Anzeige',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analog',
			'operation.layout.panels.clockZone' => 'Zeitzone',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Dieses Gerät',
			'operation.layout.panels.clockShowSeconds' => 'Sekunden anzeigen',
			'operation.layout.panels.weatherDescription' => 'Aktuelle Bedingungen und die nächsten acht Stunden, dort wo du funkst',
			'operation.layout.panels.weatherUseOperationLocation' => 'Standort des Betriebs verwenden',
			'operation.layout.panels.weatherLocation' => 'Standort',
			'operation.layout.panels.weatherLocationDescription' => 'Ein Grid (FN31pr) oder Breite,Länge. Wird ignoriert, solange „Standort des Betriebs verwenden“ aktiviert ist.',
			'operation.layout.panels.weatherNoLocation' => 'Kein Standort festgelegt. Gib diesem Panel in seinen Einstellungen einen Standort oder platziere es in einem Betrieb, der einen hat.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Der Standort ${location} konnte nicht gelesen werden. Verwende ein Grid wie FN31pr oder 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo nicht erreichbar — kein Netzwerk? Neuer Versuch in Kürze.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo hat geantwortet, aber nichts Lesbares geliefert. Neuer Versuch in Kürze.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'Böen ${speed}',
			'operation.layout.panels.panelAgeNow' => 'gerade eben',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'vor ${count} Min.', other: 'vor ${count} Min.', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'vor ${count} Std.', other: 'vor ${count} Std.', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Unbekannt',
			'operation.layout.panels.weatherConditions.sunny' => 'Sonnig',
			'operation.layout.panels.weatherConditions.clear' => 'Klar',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Überwiegend sonnig',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Überwiegend klar',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Teilweise bewölkt',
			'operation.layout.panels.weatherConditions.cloudy' => 'Bewölkt',
			'operation.layout.panels.weatherConditions.foggy' => 'Neblig',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Reifnebel',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Leichter Nieselregen',
			'operation.layout.panels.weatherConditions.drizzle' => 'Nieselregen',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Starker Nieselregen',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Leichter gefrierender Nieselregen',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Gefrierender Nieselregen',
			'operation.layout.panels.weatherConditions.lightRain' => 'Leichter Regen',
			'operation.layout.panels.weatherConditions.rain' => 'Regen',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Starker Regen',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Leichter gefrierender Regen',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Gefrierender Regen',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Leichter Schneefall',
			'operation.layout.panels.weatherConditions.snow' => 'Schneefall',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Starker Schneefall',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Schneegriesel',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Leichte Schauer',
			'operation.layout.panels.weatherConditions.showers' => 'Schauer',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Starke Schauer',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Leichte Schneeschauer',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Schneeschauer',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Gewitter',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Leichte Gewitter mit Hagel',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Gewitter mit Hagel',
			'operation.layout.panels.websiteDescription' => 'Eine Webseite deiner Wahl in einem Bereich',
			'operation.layout.panels.websiteUrl' => 'Adresse',
			'operation.layout.panels.websiteRefresh' => 'Aktualisieren',
			'operation.layout.panels.websiteRefreshNever' => 'Nie',
			'operation.layout.panels.websiteRefresh1' => 'Jede Minute',
			'operation.layout.panels.websiteRefresh5' => 'Alle 5 Minuten',
			'operation.layout.panels.websiteRefresh15' => 'Alle 15 Minuten',
			'operation.layout.panels.websiteTitle' => 'Panel-Name',
			'operation.layout.panels.websiteRefreshNow' => 'Jetzt aktualisieren',
			'operation.layout.panels.websiteNoUrl' => 'Noch keine Adresse. Öffne die Einstellungen dieses Panels, um eine Seite auszuwählen.',
			'operation.layout.panels.websiteBadUrl' => 'Das sieht nicht wie eine Webadresse aus. Sie muss mit https:// beginnen',
			'operation.layout.panels.websiteNotHttps' => 'Hier können nur Adressen mit https:// angezeigt werden.',
			'operation.layout.panels.websiteUnsupported' => 'Webseiten können auf diesem System nicht in einem Panel angezeigt werden.',
			'operation.layout.panels.websiteOpenExternally' => 'Im Browser öffnen',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Die Seite konnte nicht geladen werden: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Ein Bildschirm, eine App oder ein Fenster, das ein anderes deiner Geräte teilt.',
			'operation.layout.panels.remoteScreenTarget' => 'Bildschirm',
			'operation.layout.panels.remoteScreenChoose' => 'Bildschirm wählen…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Geteilte Bildschirme',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Keines deiner Geräte teilt einen Bildschirm. Schalte „Bildschirme und Fenster teilen“ unter Einstellungen → Partnergeräte auf dem Gerät ein, das du sehen möchtest.',
			'operation.layout.panels.remoteScreenUnset' => 'Kein Bildschirm gewählt. Öffne die Einstellungen dieses Panels, um einen auszuwählen, den deine anderen Geräte teilen.',
			'operation.layout.panels.remoteScreenConnecting' => 'Verbinde…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Dieses Gerät ist gerade nicht verbunden.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Dieses Gerät teilt diesen Bildschirm nicht mehr.',
			'operation.layout.panels.remoteScreenNoListener' => 'Dieses Gerät kann keine Verbindungen annehmen — prüfe seine Firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Bildschirme werden nur über das lokale Netzwerk geteilt, nicht über Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Dieses Gerät hat das Teilen dieses Bildschirms abgelehnt.',
			'operation.layout.panels.remoteScreenSettings' => 'Panel-Einstellungen',
			'operation.layout.panels.remoteScreenAdjust' => 'Ansicht anpassen',
			'operation.layout.panels.remoteScreenDetail' => 'Detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Hoch',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximal',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Vergrößern',
			'operation.layout.panels.remoteScreenZoomOut' => 'Verkleinern',
			'operation.layout.panels.remoteScreenStopped' => 'Dieser Bildschirm oder dieses Fenster wird nicht mehr angezeigt.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Dieses Gerät konnte den Bildschirm nicht aufnehmen — evtl. fehlt die Berechtigung zur Bildschirmaufnahme.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Dieses Gerät hat nicht reagiert. Möglicherweise ist die Bildschirmfreigabe nicht eingeschaltet.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Für das Bild konnte keine Verbindung geöffnet werden. Prüfe die Firewall auf diesem Gerät.',
			'operation.layout.panels.solarDescription' => 'Solare und geomagnetische Bedingungen mit Ausbreitung pro Band',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com nicht erreichbar — kein Netzwerk? Neuer Versuch in Kürze.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com hat geantwortet, aber keine verwendbaren Werte geliefert. Neuer Versuch in Kürze.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Tag',
			'operation.layout.panels.solarBandNight' => 'Nacht',
			'operation.layout.panels.solarBandGood' => 'Gut',
			'operation.layout.panels.solarBandFair' => 'Mittel',
			'operation.layout.panels.solarBandPoor' => 'Schlecht',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Quellen: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Die Verbindung hat Mühe — Frames werden übersprungen.',
			'operation.layout.panels.remoteScreenStalled' => 'Es kommen keine Frames mehr an — diese Verbindung ist evtl. zu langsam.',
			'operation.layout.panels.radioDescription' => 'Die Frontplatte eines Funkgeräts — Frequenz, Modus und Leistung, per CAT gesteuert',
			'operation.layout.panels.radioStyle' => 'Stil',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Funkgerät',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — kein Funkgerät festgelegt',
			'operation.layout.panels.radioNoRadio' => 'Kein Funkgerät zum Anzeigen. Wähle eines in den Einstellungen dieses Panels oder füge eines unter Stationskonfiguration hinzu.',
			'operation.layout.panels.radioNotConfigured' => 'Dieses Funkgerät ist noch nicht konfiguriert. Wähle seinen Port oder seine Adresse unter Stationskonfiguration.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Funkgerät nicht verbunden',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Dieses Funkgerät verbinden',
			'operation.layout.panels.radioDisconnect' => 'Dieses Funkgerät trennen',
			'operation.layout.panels.radioStale' => 'KEINE DATEN',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'hohes SWR',
			'operation.layout.htmlPanelUnsupported' => 'Dieses Panel benötigt eine Web-Ansicht, die diese Plattform nicht bietet',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Dieses Panel benötigt eine Sandbox, die die Web-Version nicht bieten kann',
			'operation.export.title' => 'Betriebs-Exporte',
			'operation.export.syncedOperation' => 'Betrieb ist synchronisiert',
			'operation.export.unsyncedOperation' => 'Betrieb hat nicht synchronisierte Änderungen',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} QSO in diesem Betrieb', other: '${count} QSOs in diesem Betrieb', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Alle ${total} QSOs sind synchronisiert',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} von ${total} QSOs warten auf Synchronisierung',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} Ereignismarkierungen synchronisiert',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} von ${total} Ereignismarkierungen ausstehend',
			'operation.export.loading' => 'Exportoptionen werden geladen…',
			'operation.export.noOptions' => 'Keine Exportformate verfügbar (Erweiterungen starten noch?)',
			'operation.export.nothingLogged' => 'Noch nichts zu exportieren — dieser Betrieb hat keine QSOs.',
			'operation.export.share' => 'Teilen',
			'operation.export.nothingSelected' => 'Nichts ausgewählt',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei speichern', other: '${count} Dateien speichern', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei teilen', other: '${count} Dateien teilen', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei exportieren', other: '${count} Dateien exportieren', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei herunterladen', other: '${count} Dateien herunterladen', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kombinierte Datei speichern', other: '${count} kombinierte Dateien speichern', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kombinierte Datei teilen', other: '${count} kombinierte Dateien teilen', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kombinierte Datei exportieren', other: '${count} kombinierte Dateien exportieren', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kombinierte Datei herunterladen', other: '${count} kombinierte Dateien herunterladen', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => '${name} speichern',
			'operation.export.shareOne' => ({required Object name}) => '${name} teilen',
			'operation.export.exportOne' => ({required Object name}) => '${name} exportieren',
			'operation.export.downloadOne' => ({required Object name}) => '${name} herunterladen',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei ablegen', other: '${count} Dateien ablegen', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kombinierte Datei ablegen', other: '${count} kombinierte Dateien ablegen', ), 
			'operation.export.settingsButton' => 'Export-Einstellungen',
			'operation.export.settingsTitle' => 'Export-Einstellungen',
			'operation.export.compactFileNames.title' => 'Kompakte Dateinamen verwenden',
			'operation.export.compactFileNames.descriptionOn' => 'Kurze Namen für Upload-Tools, z. B. N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Lesbare Namen, z. B. 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Private Daten einbeziehen',
			'operation.export.includePrivateData.descriptionOn' => 'Namen, Adressen, E-Mails, Grids und Notizen werden einbezogen',
			'operation.export.includePrivateData.descriptionOff' => 'Namen, Adressen, E-Mails, Grids und Notizen werden weggelassen',
			'operation.export.includePrivateData.note' => 'Der vollständige ADIF-Export enthält immer alles',
			'operation.export.resultTitle' => 'Export abgeschlossen',
			'operation.export.resultFailedTitle' => 'Export fehlgeschlagen',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei nach ${path} exportiert', other: '${count} Dateien nach ${path} exportiert', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei exportiert: ${path}', other: '${count} Dateien exportiert: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei geteilt', other: '${count} Dateien geteilt', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei heruntergeladen', other: '${count} Dateien heruntergeladen', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export fehlgeschlagen: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Zuerst eine E-Mail-Adresse hinzufügen',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash sendet deine Dateien an die E-Mail-Adresse deines LoFi-Kontos, und du meldest dich damit auf stash.ham2k.net an. Dein Konto hat noch keine bestätigte Adresse — füge sie unter Einstellungen › Cloud-Sync hinzu.',
			'operation.export.stash.openSyncSettings' => 'Cloud-Sync öffnen',
			'operation.export.stash.replaceTitle' => 'Letzter Stash wird ersetzt',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Du hast „${name}“ vor weniger als 6 Stunden gesendet und es wurde noch nicht heruntergeladen. Kostenlose Konten behalten immer nur einen Stash, daher wird er beim Senden jetzt ersetzt.',
			'operation.export.stash.replaceConfirm' => 'Trotzdem senden',
			'operation.export.stash.failedTitle' => 'Senden an Ham2K File Stash fehlgeschlagen',
			'operation.export.stash.sentTitle' => 'An Ham2K File Stash gesendet',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Du kannst diese Datei abrufen, indem du **[stash.ham2k.net](https://stash.ham2k.net)** in einem beliebigen Browser aufrufst.', other: 'Du kannst diese Dateien abrufen, indem du **[stash.ham2k.net](https://stash.ham2k.net)** in einem beliebigen Browser aufrufst.', ), 
			'operation.export.stash.mayHaveArrived' => 'Keine Antwort vom Stash — die Datei ist vielleicht trotzdem angekommen. Prüfe stash.ham2k.net, bevor du erneut sendest',
			'operation.export.stash.notSent' => 'nicht gesendet',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Diese Datei ist nicht angekommen:', other: 'Diese ${count} Dateien sind nicht angekommen:', ), 
			'operation.export.stash.emailOffer' => 'Oder wir können dir der Einfachheit halber eine E-Mail mit einem direkten Link senden.',
			'operation.export.stash.emailMe' => 'Link per E-Mail senden',
			'operation.export.stash.emailSent' => 'Wir haben dir einen Download-Link per E-Mail gesendet.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'E-Mail konnte nicht gesendet werden: ${error}',
			'operation.export.stash.freeTier' => 'Kostenlose Konten können immer nur einen Stash gleichzeitig behalten. Abonnenten können so viele behalten, wie sie möchten.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Datei an Ham2K File Stash gesendet (stash.ham2k.net)', other: '${count} Dateien an Ham2K File Stash gesendet (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Keine Spots passen zu deinen Filtern',
			'operation.spots.error' => ({required Object error}) => 'Spots konnten nicht geladen werden: ${error}',
			'operation.spots.unknownBand' => 'Andere',
			'operation.spots.auto' => 'Automatisch',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatisch (Derzeit ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Alle',
			'operation.spots.allBands' => 'Alle Bänder',
			'operation.spots.allModes' => 'Alle Modi',
			'operation.spots.phoneAndCw' => 'Phone & CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Spot', other: '${count} Spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => '${count} von ${total} Spots werden angezeigt',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} Minuten',
			'operation.spots.callsOfNote' => 'Bemerkenswerte Rufzeichen',
			'operation.spots.yourSpots' => 'Deine Spots',
			'operation.spots.allSpots' => 'Alle Spots',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Asien',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'Nordamerika',
			'operation.spots.continents.oc' => 'Ozeanien',
			'operation.spots.continents.sa' => 'Südamerika',
			'operation.spots.continents.an' => 'Antarktis',
			'operation.spots.filters.title' => 'Spots filtern',
			'operation.spots.filters.band' => 'Band',
			'operation.spots.filters.mode' => 'Modus',
			'operation.spots.filters.age' => 'Alter',
			'operation.spots.filters.sources' => 'Quellen',
			'operation.spots.filters.continent' => 'Kontinent',
			'operation.spots.filters.sorting' => 'Sortierung',
			'operation.spots.filters.sortByTime' => 'Nach Spot-Zeit',
			'operation.spots.filters.sortByFrequency' => 'Nach Frequenz',
			'operation.spots.filters.groupByBand' => 'Nach Band gruppieren',
			'operation.spots.filters.groupCallsWithNotes' => 'Rufzeichen mit Notizen gruppieren',
			'operation.spots.filters.sourceNoReply' => 'Keine Antwort',
			'operation.spots.filters.sourceError' => 'Fehler',
			'operation.spots.unavailableTitle' => 'Spots nicht verfügbar',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} hat nicht reagiert.',
			'operation.spots.failedTitle' => 'Fehler der Spot-Quelle',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} meldete einen Fehler.',
			'operation.spots.slideLogIt' => 'Loggen',
			'operation.spots.slideIgnore' => 'Ignorieren',
			'operation.spots.slideRestore' => 'Wiederherstellen',
			'operation.spots.logConflict.title' => 'Logging-Panel ist belegt',
			'operation.spots.logConflict.editingBody' => 'Du bearbeitest gerade einen geloggten Kontakt. Stattdessen diesen Spot loggen oder zurückgehen und die Bearbeitung abschließen?',
			'operation.spots.logConflict.composingBody' => 'Du hast begonnen, einen Kontakt einzugeben. Stattdessen diesen Spot loggen oder zurückgehen und die Eingabe abschließen?',
			'operation.spots.logConflict.goBack' => 'Zurück',
			'operation.spots.logConflict.clearAndLog' => 'Leeren und Spot loggen',
			'operation.import.title' => 'Daten in Betrieb importieren',
			'operation.import.importAdifAction' => 'QSOs aus ADIF importieren',
			'operation.import.settingsButton' => 'Empfangseinstellungen',
			'operation.import.settingsTitle' => 'Auf andere Apps lauschen',
			'operation.import.protocolAddressLabel' => 'Adresse',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Gib einen Port zwischen 1 und 65535 ein',
			'operation.import.protocolAddressInvalid' => 'Gib eine gültige IP-Adresse ein (z. B. 127.0.0.1 oder 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Empfange Daten',
			'operation.import.protocolStatusNoData' => 'In letzter Zeit keine Daten empfangen',
			'operation.import.protocolBindError' => ({required Object error}) => 'Empfang konnte nicht gestartet werden: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Eingehende QSOs konnten nicht gespeichert werden, neuer Versuch läuft: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Beliebig (Broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Reiter Broadcast Data → "Enable Broadcasts" für Contact-Info aktivieren. IP-Adresse auf 127.0.0.1 setzen, wenn es auf diesem Computer läuft, oder auf 255.255.255.255, um im aktuellen lokalen Netzwerk zu senden.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reiter Reporting → Abschnitt UDP Server → "Accept UDP requests" aktivieren. UDP Server auf 127.0.0.1 setzen, wenn es auf diesem Computer läuft, oder auf eine Multicast-Adresse wie 239.239.0.2, und dieselbe Adresse oben in der Konfiguration dieser App verwenden.',
			'operation.import.listenTitle' => 'Auf QSOs von anderen Apps lauschen',
			'operation.import.listenDescriptionOnN1mm' => 'Lausche auf N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Lausche auf WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Lausche auf N1MM+ und WSJT-X',
			'operation.import.listenDescriptionOff' => 'Aus',
			'operation.import.addToOperationTitle' => 'Zu diesem Betrieb hinzufügen',
			'operation.import.addToOperationDescriptionOn' => 'Empfangene QSOs werden bei Eingang zu diesem Betrieb hinzugefügt',
			'operation.import.addToOperationDescriptionOff' => 'Empfangene QSOs werden zurückgehalten, bis du dies einschaltest',
			'operation.import.pendingSectionTitle' => 'Empfangene QSOs',
			'operation.import.pendingEmpty' => 'Noch nichts empfangen',
			'operation.import.stationMismatch' => ({required Object call}) => 'Als ${call} geloggt, nicht als Station dieses Betriebs',
			'operation.import.discardAction' => 'Verwerfen',
			'operation.import.gapDialogTitle' => 'Frühere Empfänge einbeziehen?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} weitere QSOs wurden früher empfangen, vor einer Lücke in den Daten. Auch diese einbeziehen?',
			'operation.import.gapDialogRecentOnly' => 'Nur die neuen',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Alle ${count} einbeziehen',
			'map.outlineIssue.link' => 'Probleme?',
			'map.outlineIssue.title' => 'Problem mit Umriss melden',
			'map.outlineIssue.reference' => 'Welcher Umriss',
			'map.outlineIssue.severity' => 'Wie schlimm ist es?',
			'map.outlineIssue.minor' => 'Kleinigkeit',
			'map.outlineIssue.major' => 'Großes Problem',
			'map.outlineIssue.explanation' => 'Was stimmt nicht?',
			'map.outlineIssue.explanationHint' => 'Was der Umriss falsch darstellt, und wo',
			'map.outlineIssue.send' => 'Senden',
			'map.outlineIssue.sending' => 'Deine Meldung wird gesendet — danke',
			'map.outlineIssue.copy' => 'Meldung kopieren',
			'map.outlineIssue.notSent' => 'Meldung konnte nicht gesendet werden',
			'map.outlineIssue.copied' => 'Meldung kopiert',
			'map.outlineIssue.notCopied' => 'Meldung konnte nicht kopiert werden',
			'map.outlinesDisclaimer' => 'Umrisse dienen nur zur Orientierung. Recherchiere selbst!',
			'map.outlinesCredit' => ({required Object sources}) => 'Umrisse: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Grenzen: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Einrichtungen: ${sources}',
			'map.fullCredits' => 'Vollständige Datenquellen',
			'map.fewerCredits' => 'Weniger Quellen',
			'map.emptyState' => 'Noch keine QSO-Standorte.\nQSOs mit Grid, Staat oder Land werden hier angezeigt.',
			'map.unavailable' => 'Die Karte ist gerade nicht verfügbar.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Flach',
			'map.globe' => 'Globus',
			'map.zoomIn' => 'Vergrößern',
			'map.zoomOut' => 'Verkleinern',
			'map.postcard.button' => 'Betriebs-Postkarte',
			'map.postcard.title' => ({required Object title}) => 'Postkarte für ${title}',
			'map.postcard.portrait' => 'Hochformat',
			'map.postcard.landscape' => 'Querformat',
			'map.postcard.square' => 'Quadratisch',
			'map.postcard.save' => 'Speichern…',
			'map.postcard.download' => 'Herunterladen',
			'map.postcard.share' => 'Teilen',
			'map.postcard.copy' => 'Kopieren',
			'map.postcard.copied' => 'In die Zwischenablage kopiert',
			'map.postcard.saved' => ({required Object path}) => 'Gespeichert unter ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} heruntergeladen',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} Bilder unter ${path} gespeichert',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} gespeichert',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} war bereits gespeichert',
			'map.postcard.downloadedMany' => ({required Object count}) => '${count} Bilder werden heruntergeladen — erlaube sie, falls der Browser fragt',
			'map.postcard.mapLeftOut' => 'Die Karte wurde nicht geladen und daher weggelassen',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — die Karte wurde nicht geladen und daher weggelassen',
			'map.postcard.continued' => ({required Object title}) => '${title} (Fortsetzung)',
			'map.postcard.previousPage' => 'Vorherige Seite',
			'map.postcard.nextPage' => 'Nächste Seite',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Seite ${page} von ${count}',
			'map.postcard.sections' => 'Zusammenfassungsabschnitte',
			'map.postcard.sectionDays' => 'Jeder Tag',
			'map.postcard.reset' => 'Zurücksetzen',
			'map.postcard.failed' => ({required Object error}) => 'Postkarte konnte nicht erstellt werden: ${error}',
			'map.postcard.mapNotReady' => 'Die Karte wurde nicht fertig geladen. Prüfe die Verbindung und versuche es erneut.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Postkarte konnte nicht gespeichert werden: ${error}',
			'map.postcard.copyFailed' => 'Die Zwischenablage hat das Bild nicht übernommen. Versuche es erneut.',
			'map.postcard.shareFailed' => 'Postkarte konnte nicht geteilt werden. Versuche es erneut.',
			'map.postcard.fileName' => 'postkarte',
			'mapsView.title' => 'Karten',
			'mapsView.searchHint' => 'Parks, Gipfel und mehr suchen',
			'mapsView.activities' => 'Aktivitäten',
			'mapsView.layers' => 'Ebenen',
			'mapsView.baseMap' => 'Basiskarte',
			'mapsView.satellite' => 'Satellit (Esri)',
			'mapsView.facilities' => 'Park-Einrichtungen',
			'mapsView.boundaries' => 'Grenzen',
			'mapsView.currentLocation' => 'Aktueller Standort',
			'mapsView.noMatches' => ({required Object text}) => 'Nichts passt zu „${text}“',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Referenz bei ${where}', other: '${count} Referenzen bei ${where}', ), 
			'mapsView.startOperation' => 'Betrieb mit diesen Referenzen starten',
			'activitiesView.title' => 'Aktivitäten',
			'activitiesView.activitiesCountZero' => 'Keine Aktivitäten ausgewählt',
			'activitiesView.activitiesCountOne' => '1 Aktivität',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Aktivitäten',
			'activitiesView.empty' => 'Noch keine Aktivitäten — füge über Vorschläge & Suche unten eine hinzu',
			'activitiesView.removeActivity' => 'Entfernen',
			'activitiesView.openReferenceLink' => ({required Object name}) => '${name} öffnen',
			'activitiesView.editActivity' => 'Aktivität bearbeiten',
			'activitiesView.manageExtensions' => 'Erweiterungen verwalten',
			'activitiesView.manage' => 'Verwalten',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Aktivitätsarten: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Aktivitätsarten: ${first} und ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Aktivitätsarten: ${first}, ${second} und ${more} weitere',
			'activitiesView.reference' => 'Referenz',
			'activitiesView.invalidReference' => 'Ungültig',
			'activitiesView.duplicateReference' => 'Bereits hinzugefügt',
			'activitiesView.searchHint' => 'Nach Name, Referenz oder anderem suchen…',
			'activitiesView.noSuggestions' => 'Keine Treffer',
			'activitiesView.noSuggestionsHint' => 'Suche oben nach Name oder Nummer der Referenz',
			'activitiesView.noSuggestionsExample' => '(zum Beispiel \'trail\' oder \'4556\')',
			'activitiesView.allOptions' => 'Aktivitätsarten',
			'activitiesView.determiningLocation' => 'Aktueller Standort wird ermittelt…\nWarte auf GPS-Fix, um Referenzen in der Nähe zu finden',
			'activitiesView.locationUnavailableTitle' => 'Standortdaten nicht verfügbar',
			'activitiesView.locationDeniedTitle' => 'Standortberechtigung verweigert',
			'activitiesView.locationBlockedTitle' => 'Standortberechtigung blockiert',
			'activitiesView.noNearbyReason' => 'Referenzen in der Nähe können nicht ermittelt werden',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Tippe auf ${icon}, um deinen Standort manuell einzugeben,\noder suche einfach nach Referenzen über den Namen',
			'activitiesView.locationGrantAction' => 'Standortzugriff erlauben',
			'activitiesView.locationSettingsAction' => 'Einstellungen öffnen',
			'activitiesView.locationSettingsUnavailable' => 'Erlaube den Standortzugriff in deinen Systemeinstellungen',
			'activitiesView.locationGrantRefused' => 'Immer noch kein Standort — das System hat wieder abgelehnt',
			'activitiesView.searchUnavailableTitle' => 'Aktivitätssuche nicht verfügbar',
			'activitiesView.searchUnavailableReason' => 'Keine Aktivitäts-Erweiterung konnte die Suche ausführen. Versuche es gleich noch einmal.',
			'activitiesView.emptySheet' => 'Füge über Vorschläge & Suche unten eine hinzu',
			'activitiesView.exports' => 'Exporte',
			'activitiesView.exportLogs' => 'Logs exportieren',
			'activitiesView.tools' => 'Werkzeuge',
			'activitiesView.toolsTitle' => 'Betriebswerkzeuge',
			'activitiesView.operationDetails' => 'Betriebs-Details',
			'activitiesView.share' => 'Teilen',
			'activitiesView.archive' => 'Archivieren',
			'activitiesView.deleteOperation' => 'Betrieb löschen',
			'activitiesView.undeleteOperation' => 'Betrieb wiederherstellen',
			'activitiesView.alreadySelected' => 'Bereits ausgewählt',
			'activitiesView.selected' => 'Ausgewählt',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} von ${count}',
			'activitiesView.previousPick' => 'Vorheriger Treffer',
			'activitiesView.nextPick' => 'Nächster Treffer',
			'activitiesView.retiredReference' => 'Stillgelegt',
			'activitiesView.enableExtension' => ({required Object name}) => '${name} aktivieren',
			'activitiesView.enableExtensionHint' => 'Diese Erweiterung passt zu deiner Suche, ist aber derzeit nicht aktiviert',
			'activitiesView.enableExtensionForRefHint' => 'Diese Erweiterung verarbeitet eine der Referenzen dieses Betriebs, ist aber derzeit nicht aktiviert',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} läuft nicht',
			'activitiesView.extensionNotRunningHint' => 'Diese Erweiterung wurde deaktiviert, öffne die Erweiterungseinstellungen für mehr Infos',
			'activitiesView.installExtension' => ({required Object name}) => '${name} installieren',
			'activitiesView.installExtensionHint' => 'Diese Erweiterung passt zu deiner Suche, ist aber nicht installiert',
			'activitiesView.onlyCatalogMatches' => 'Keine Treffer\nEinige Erweiterungen im Katalog könnten Ergebnisse haben.\nInstalliere sie unten unter Aktivitätsarten.',
			'activitiesView.setupUnavailable' => 'Die Einrichtung dieser Aktivität konnte nicht geladen werden — versuche es erneut über Verwalten',
			'activitiesView.controlsUnavailableTitle' => 'Aktivitätssteuerung nicht verfügbar',
			'activitiesView.controlsUnavailableReason' => 'Deine Referenzen sind sicher, können aber gerade nicht bearbeitet werden.',
			'activitiesView.controlsUnavailableRetry' => 'Erneut versuchen',
			'activitiesView.onlyDisabledMatches' => 'Keine Treffer\nEinige verfügbare Erweiterungen könnten Ergebnisse haben.\nAktiviere sie unten unter Aktivitätsarten.',
			'activitiesView.onlyNotRunningMatches' => 'Keine Treffer\nEinige Erweiterungen, die Ergebnisse haben könnten, laufen nicht.\nSiehe Aktivitätsarten unten.',
			'activitiesView.mapToggle' => 'Karte',
			'activitiesView.searchToggle' => 'Suche',
			'activitiesView.addToOperation' => 'Zum Betrieb hinzufügen',
			'activitiesView.addToOperationShort' => 'Hinzufügen',
			'activitiesView.mapEmptyState' => 'Keine Ergebnisse für die Karte',
			'activitiesView.mapEmptyStateHint' => 'Wechsle zurück zur Liste oder suche nach etwas anderem',
			'activitiesView.imports' => 'Importe',
			'loggingControls.timeUtc' => 'Zeit (UTC)',
			'loggingControls.date' => 'Datum',
			'loggingControls.now' => 'Jetzt',
			'loggingControls.frequency' => 'Frequenz',
			'loggingControls.mode' => 'Modus',
			'loggingControls.theirCall' => 'Deren Rufzeichen',
			'loggingControls.noteField' => 'Notiz',
			'loggingControls.todoField' => 'To-do',
			'loggingControls.sent' => 'Gesendet',
			'loggingControls.rcvd' => 'Empf.',
			'loggingControls.more' => 'Mehr',
			'loggingControls.revert' => 'Rückgängig',
			'loggingControls.undoDelete' => 'Löschen rückgängig',
			'loggingControls.restore' => 'Wiederherstellen',
			'loggingControls.wipe' => 'Leeren',
			'loggingControls.undo' => 'Rückgängig',
			'loggingControls.pendingDeleteTapWarning' => 'Tippe noch einmal auf den Papierkorb, um dieses QSO zu löschen',
			'loggingControls.pendingDeleteClickWarning' => 'Klicke noch einmal auf den Papierkorb, um dieses QSO zu löschen',
			'loggingControls.deletedQsoWarning' => 'Gelöschtes QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Tippe noch einmal auf den Papierkorb, um dies zu löschen: ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Klicke noch einmal auf den Papierkorb, um dies zu löschen: ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Gelöscht: ${kind}',
			'loggingControls.timeControl' => 'Zeit',
			'loggingControls.radioControl' => 'Funkgerät',
			'loggingControls.powerControl' => 'Leistung',
			'loggingControls.notesControl' => 'Notizen',
			'loggingControls.power' => 'Leistung',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Logging-Steuerungen',
			'loggingControls.spottingControl' => 'Spot',
			'loggingControls.spottingSelfControl' => 'Selbst-Spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Selbst-Spot auf ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} auf ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Zu spät, um ${call} zu spotten',
			'loggingControls.spotNoFreq' => 'Zuerst eine Frequenz zum Spotten einstellen',
			'loggingControls.spotComment' => 'Kommentar',
			'loggingControls.bandOrFreqRequired' => 'Vor dem Loggen eine Frequenz oder ein Band einstellen',
			'loggingControls.missingBand' => 'Kein Band',
			'loggingControls.missingMode' => 'Kein Modus',
			'loggingControls.saveFailed' => ({required Object error}) => 'Speichern fehlgeschlagen: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Löschen fehlgeschlagen: ${error}',
			'loggingControls.info.noQsos' => 'Noch keine QSOs... Lass uns loslegen!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} in ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} seit dem letzten',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h für die letzten 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h für die letzten 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} nach',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) nach',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) nach',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} entfernt',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) entfernt',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) entfernt',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplikat!',
			'loggingControls.info.noticeNewBand' => 'Neues Band',
			'loggingControls.info.noticeNewMode' => 'Neuer Modus',
			'loggingControls.info.noticeNewDXCC' => 'Neues DXCC',
			'loggingControls.info.noticeNewState' => 'Neuer Staat',
			'loggingControls.info.noticeNewProvince' => 'Neue Provinz',
			'loggingControls.info.noticeNewDay' => 'Neuer Tag',
			'loggingControls.info.noticeNewRef' => 'Neue Ref',
			'loggingControls.info.noticeNewMult' => 'Neuer Multi',
			'loggingControls.info.noticeNewZone' => 'Neue Zone',
			'loggingControls.info.noticeInvalidMode' => 'Falscher Modus',
			'loggingControls.info.noticeInvalidBand' => 'Falsches Band',
			'loggingControls.info.noticeInvalidCategory' => 'Nicht arbeitbar',
			'loggingControls.info.noticeWorkedBefore' => 'Schon gearbeitet',
			'loggingControls.info.noticeNewPark' => 'Neuer Park',
			'loggingControls.info.noticeNewSection' => 'Neue Sektion',
			'loggingControls.info.noticeBonusStation' => 'Bonus-Station!',
			'loggingControls.info.noticeMissingExchange' => 'Kein Austausch',
			'loggingControls.info.noticeInvalidExchange' => 'Falscher Austausch',
			'loggingControls.info.noticeUnknownEvent' => 'Unbekanntes Event',
			'loggingControls.info.noticeOurGrid' => 'Unser Grid setzen',
			'loggingControls.info.noticeRareCounty' => 'Seltener County!',
			'loggingControls.info.noticeOurLocation' => 'Unseren County setzen',
			'loggingControls.info.noticeShortGrid' => 'Grid zu kurz',
			'formChrome.untitled' => '(ohne Titel)',
			'formChrome.showMore' => 'Mehr anzeigen',
			'formChrome.showAll' => 'Alle anzeigen',
			'formChrome.showFewer' => 'Weniger anzeigen',
			'formChrome.defaults' => 'Standardwerte',
			'formChrome.search' => 'Suchen',
			'formChrome.clear' => 'Leeren',
			'formChrome.openPage' => 'Seite öffnen',
			'formChrome.connected' => 'Verbunden',
			'formChrome.notConnected' => 'Nicht verbunden',
			'formChrome.manage' => 'Verwalten',
			'formChrome.connect' => 'Verbinden',
			'formChrome.formTitle' => 'Formular',
			'formChrome.addItem' => ({required Object label}) => '${label} hinzufügen',
			'formChrome.editItem' => ({required Object label}) => '${label} bearbeiten',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => '${shown} von ${total} angezeigt (${selected} ausgewählt)',
			'formChrome.validationError' => ({required Object error}) => 'Validierungsfehler: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Umwandlungsfehler: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Fehler: ${error}',
			'formChrome.removeItem' => 'Entfernen',
			'formChrome.storageUnavailable' => 'Anmeldedaten nicht verfügbar',
			'qsoEditForm.title' => 'QSO bearbeiten',
			'qsoEditForm.operatorCall' => 'Operator',
			'qsoEditForm.position' => 'Funkplatz',
			'qsoEditForm.theirName' => 'Name',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Staat',
			'qsoEditForm.band' => 'Band',
			'qsoEditForm.notes' => 'Notizen',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Deren Info',
			'qsoEditForm.sectionOur' => 'Unsere Info',
			'qsoEditForm.sectionNotes' => 'Notizen',
			'qsoEditForm.theirCity' => 'Stadt',
			'qsoEditForm.theirCounty' => 'Landkreis',
			'qsoEditForm.theirEntity' => 'Entität',
			'qsoEditForm.theirCqZone' => 'CQ-Zone',
			'qsoEditForm.theirItuZone' => 'ITU-Zone',
			'qsoEditForm.theirArrlSection' => 'ARRL-Sektion',
			'qsoEditForm.theirLat' => 'Breitengrad',
			'qsoEditForm.theirLon' => 'Längengrad',
			'qsoEditForm.theirPower' => 'Deren Leistung',
			'qsoList.empty' => 'Noch keine QSOs — arbeite jemanden!',
			'qsoList.bandOrModeWarning' => 'Bitte prüfe, ob Band und Modus stimmen',
			'qsoList.today' => 'Heute',
			'qsoList.yesterday' => 'Gestern',
			'qsoList.tomorrow' => 'Morgen',
			'loggingPanel.stats' => 'Betriebsstatistik',
			'loggingPanel.scoring' => 'Punktewertung',
			'loggingPanel.dxccEntities' => 'DXCC-Entitäten',
			'loggingPanel.statesWorked' => 'Staaten',
			'loggingPanel.provincesWorked' => 'Provinzen',
			'loggingPanel.duplicates' => 'Duplikate',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Bild anzeigen',
			'callInfo.imageUnavailable' => 'Foto nicht verfügbar',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Notizen',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} nach',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) nach',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) nach',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} entfernt',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) entfernt',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) entfernt',
			'callInfo.thisOpCountOne' => '1 QSO in diesem Betrieb',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs in diesem Betrieb',
			'callInfo.otherOpsCountOne' => '1 QSO in anderen Betrieben',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs in anderen Betrieben',
			'callInfo.andMore' => ({required Object count}) => '… und ${count} mehr',
			'callInfo.withCall' => ({required Object call}) => 'mit ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'aus ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} in den letzten 7 Tagen',
			'callInfo.history.today' => ({required Object n}) => '${n} heute',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Einstellungen',
			'settings.language' => 'Sprache',
			'settings.languageSystem' => ({required Object language}) => 'Systemeinstellungen folgen (${language})',
			'settings.theme.title' => 'Design',
			'settings.theme.system' => 'Systemeinstellungen folgen',
			'settings.theme.light' => 'Hell',
			'settings.theme.dark' => 'Dunkel',
			'settings.themeDescription.system' => 'Folgt den Systemeinstellungen',
			'settings.themeDescription.light' => 'Immer im Hellmodus',
			'settings.themeDescription.dark' => 'Immer im Dunkelmodus',
			'settings.fontScale' => 'Schriftgröße',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Kleinste--',
			'settings.fontScaleOpts.smallestMinus' => 'Kleinste-',
			'settings.fontScaleOpts.smallest' => 'Kleinste',
			'settings.fontScaleOpts.smaller' => 'Kleiner',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Größer',
			'settings.fontScaleOpts.largest' => 'Größte',
			'settings.fontScaleOpts.largestPlus' => 'Größte+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Größte++',
			'settings.keepDeviceAwake.title' => 'Gerät wach halten',
			'settings.keepDeviceAwake.descriptionOn' => 'Bleibt wach, solange du in der Logging-Ansicht bist oder eine Synchronisierung läuft',
			'settings.keepDeviceAwake.descriptionOff' => 'Ruhezustand wie üblich',
			'settings.layoutDensity' => 'Layout-Dichte',
			'settings.layoutDensityOpts.auto' => 'Automatisch',
			'settings.layoutDensityOpts.densest' => 'Am dichtesten',
			'settings.layoutDensityOpts.dense' => 'Dicht',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Locker',
			'settings.layoutDensityOpts.sparsest' => 'Am lockersten',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'das Fenster ist zu niedrig, verwende ${effective}',
			'settings.layoutDensityAtLimit' => 'am Anschlag',
			'settings.distanceUnits' => 'Entfernungseinheiten',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometer',
			'settings.distanceUnitsOpts.miles' => 'Meilen',
			'settings.userInterface' => 'Benutzeroberfläche',
			'settings.logging.title' => 'Logging',
			'settings.logging.leftieMode.title' => 'Linkshänder-Modus',
			'settings.logging.leftieMode.descriptionOn' => 'Das Layout für Linkshänder wird verwendet',
			'settings.logging.leftieMode.descriptionOff' => 'Das Layout für Rechtshänder wird verwendet',
			'settings.logging.countryFlags.title' => 'Länderflaggen',
			'settings.logging.countryFlags.dx' => 'Nur für DX-Kontakte anzeigen',
			'settings.logging.countryFlags.all' => 'Flaggen für alle Kontakte anzeigen',
			'settings.logging.countryFlags.none' => 'Keine Flaggen anzeigen',
			'settings.logging.countryFlagsDescription.dx' => 'Flaggen werden nur für DX-Kontakte angezeigt',
			'settings.logging.countryFlagsDescription.all' => 'Flaggen werden für alle Kontakte angezeigt',
			'settings.logging.countryFlagsDescription.none' => 'Es werden keine Flaggen angezeigt',
			'settings.logging.suggestDefaultOperator.title' => 'Operator vorschlagen',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Dein Rufzeichen wird als Operator vorgeschlagen, wenn ein Betrieb unter einem anderen Stationsrufzeichen läuft',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Operator bleibt leer, solange du ihn nicht ausfüllst',
			'settings.logging.showBearing.title' => 'Peilung anzeigen',
			'settings.logging.showBearing.descriptionOn' => 'Geschätzte Peilung zur Station wird angezeigt',
			'settings.logging.showBearing.descriptionOff' => 'Peilungsinformationen werden nicht angezeigt',
			'settings.logging.showReverseBearing.title' => 'Auch Gegenpeilung anzeigen',
			'settings.logging.showReverseBearing.descriptionOn' => 'Peilung von der Station wird ebenfalls angezeigt, z. B. „45° / 225°“',
			'settings.logging.showReverseBearing.descriptionOff' => 'Nur die Peilung zur Station wird angezeigt',
			'settings.logging.switchSentRcvd.title' => 'Rapport-Reihenfolge wechseln',
			'settings.logging.switchSentRcvd.sentFirst' => 'Gesendet zuerst, Empfangen als zweites',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Empfangen zuerst, Gesendet als zweites',
			'settings.logging.jumpAfterRST.title' => 'Spring weiter bei RST-Eingabe',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Nach RST-Eingabe wird zum nächsten Feld gesprungen',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Es wird nicht automatisch gesprungen',
			'settings.logging.defaultReport.title' => 'Standard-Rapport — Phone',
			'settings.logging.defaultReport.description' => 'Wird verwendet, wenn Gesendet oder Empfangen bei SSB, FM oder AM leer bleibt',
			'settings.logging.defaultReportCW.title' => 'Standard-Rapport — CW und Digital',
			'settings.logging.defaultReportCW.description' => 'Wird verwendet, wenn Gesendet oder Empfangen bei CW, RTTY und anderen Digitalmodi leer bleibt',
			'settings.logging.defaultReportFT8.title' => 'Standard-Rapport — FT8 und FT4',
			'settings.logging.defaultReportFT8.description' => 'Wird verwendet, wenn Gesendet oder Empfangen bei den FT-Modi leer bleibt',
			'settings.logging.numbersRow.title' => 'Zahlenreihe',
			'settings.logging.numbersRow.description' => 'Beim Loggen eine Reihe Zifferntasten über der Tastatur anzeigen',
			'settings.logging.numbersRowExtra.title' => 'Schrägstrich- und Punkttaste',
			'settings.logging.numbersRowExtra.description' => 'Fügt eine kontextabhängige Taste hinzu: „/“ für Rufzeichen, „.“ für Zahlen',
			'settings.logging.numbersRowVibrate.title' => 'Vibration bei Tastendruck',
			'settings.logging.numbersRowVibrate.description' => 'Haptisches Feedback beim Tippen auf eine Zifferntaste',
			'settings.logging.bands' => 'Bevorzugte Bänder',
			'settings.logging.modes' => 'Bevorzugte Modi',
			'settings.catServer.title' => 'CAT-Server',
			'settings.catServer.description' => 'Anderen Apps (WSJT-X, Logprogramme usw.) erlauben, das Funkgerät über Ham2K Logger zu steuern.',
			'settings.catServer.protocol' => 'Protokoll',
			'settings.catServer.protocolOpts.off' => 'Deaktiviert',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Offener Zugriff',
			'settings.catServer.openAccessOn' => 'Jeder Computer im lokalen Netzwerk kann sich verbinden.',
			'settings.catServer.openAccessOff' => 'Nur Apps auf diesem Computer können sich verbinden.',
			'settings.catServer.off' => 'Aus.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, startet…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} auf Port ${port}. Verbundene Clients: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} auf Port ${port}, aber kein Funkgerät als Haupt-VFO verbunden.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} kann nicht auf Port ${port} lauschen: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} kann nicht auf Port ${port} lauschen: ein anderes Programm nutzt ihn, oft ${protocol} selbst. Schließe dieses Programm oder wähle einen anderen Port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} kann nicht auf Port ${port} lauschen: dieser Computer erlaubt es nicht. Wähle einen Port über 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} lauscht nicht mehr auf Port ${port}. Neuer Versuch…',
			_ => null,
		} ?? switch (path) {
			'settings.radio.title' => 'CAT-Steuerung',
			'settings.radio.loggingAndCat' => 'Logging & CAT',
			'settings.radio.tuningSection' => 'Abstimmung',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Dienste',
			'settings.radio.stationConfigurationSection' => 'Stationskonfiguration',
			'settings.radio.moreSettings' => 'Weitere Einstellungen zur Stationskonfiguration',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'PTT mit [\'] steuern',
			'settings.radio.pttKey.descriptionOn' => 'In Phone-Modi tastet [\'] das Funkgerät auf und [\'] erneut wieder ab. Nach einer Minute tastet es von selbst ab.',
			'settings.radio.pttKey.descriptionOff' => 'Die Taste [\'] tastet das Funkgerät nicht auf.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Sende',
			'settings.radio.smartVfoSnap.title' => 'Smart VFO Snap',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Wenn du aufhörst, am Knopf zu drehen, wird die Frequenz auf einen sinnvollen Schritt gerundet. Nur Sprachmodi.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Bleibt genau dort, wo du abgestimmt hast.',
			'settings.radio.snapDebounce.title' => 'Smart Snap: Wartezeit',
			'settings.radio.snapDebounce.description' => 'Wie lange der Knopf stillstehen muss, bevor die Frequenz gerundet wird. Kürzer wirkt sofort; länger lässt Raum für eine langsame Bewegung.',
			'settings.radio.snapLongMove.title' => 'Smart Snap: Lange Bewegung',
			'settings.radio.snapLongMove.description' => 'Ab dieser Strecke wird die Frequenz auf ein ganzes kHz gerundet, egal wie langsam du zuletzt gedreht hast.',
			'settings.radio.snapMinMove.title' => 'Smart Snap: Kleinste Bewegung',
			'settings.radio.snapMinMove.description' => 'Unterhalb dieser Strecke wird die Frequenz nicht gerundet, damit Feinabstimmung unberührt bleibt.',
			'settings.radio.snapMinSpeed.title' => 'Smart Snap: Langsamste Bewegung',
			'settings.radio.snapMinSpeed.description' => 'Langsamer gedreht wird die Frequenz nicht gerundet, außer es war eine lange Bewegung.',
			'settings.radio.enterSends.pillOff' => 'ESM Aus',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter sendet Nachrichten',
			'settings.radio.enterSends.off' => 'Aus',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter sendet Nachrichten: ${state}. Tippen zum Ändern.',
			'settings.radio.keyerSpeed.title' => 'Keyer-Geschwindigkeit',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW-Keyer-Nachrichten',
			'settings.radio.cwMessages.notSupported' => 'Das aktuelle Funkgerät unterstützt keine CW-Tastung',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Nachricht (${n})',
			'settings.radio.cwMessages.labelField' => 'Beschriftung',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Beschriftung F${n}',
			'settings.radio.cwMessages.details' => 'Details',
			'settings.radio.cwMessages.empty' => '(leer)',
			'settings.radio.cwMessages.sets' => 'Nachrichtensatz',
			'settings.radio.cwMessages.newSet' => 'Neuer Satz',
			'settings.radio.cwMessages.renameSet' => 'Satz umbenennen',
			'settings.radio.cwMessages.deleteSet' => 'Satz löschen',
			'settings.radio.cwMessages.newSetName' => 'Name',
			'settings.radio.cwMessages.setDefault' => 'Standard',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM-Nachrichten',
			'settings.radio.cwMessages.setSaved' => 'Meine Nachrichten',
			'settings.radio.cwMessages.repeat' => 'Nachricht #1 wiederholen',
			'settings.radio.cwMessages.repeatOff' => 'Nein',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Nach ${n} Sekunden',
			'settings.radio.cwMessages.repeatWait' => 'Wiederholt',
			'settings.radio.cwMessages.keyboard' => 'Tippen zum Senden',
			'settings.radio.cwMessages.keyboardField' => 'Tippen zum Senden',
			'settings.radio.cwMessages.closeArea' => 'Keyer-Bereich schließen',
			'settings.radio.cwMessages.help' => 'Hilfe',
			'settings.radio.cwMessages.helpTitle' => 'CW-Nachrichten schreiben',
			'settings.radio.cwMessages.helpIntro' => 'Nachrichten können Vorlagen mit folgenden Werten verwenden:',
			'settings.radio.cwMessages.helpOpCall' => 'Dein Rufzeichen',
			'settings.radio.cwMessages.helpQsoCall' => 'Deren Rufzeichen — in einem //-Stapel das Rufzeichen, das geloggt wird',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Deren Rufzeichen, wenn es ein gültiges ist; leer bei einem Teilrufzeichen',
			'settings.radio.cwMessages.helpQsoPartial' => 'Ein Teilrufzeichen; leer, wenn ein vollständiges gültiges Rufzeichen vorliegt',
			'settings.radio.cwMessages.helpQsoNextCall' => 'In einem //-Stapel das Rufzeichen, das als nächstes zum Loggen ausgewählt wird, wenn es ein gültiges vollständiges ist',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'In einem //-Stapel das nächste Teilrufzeichen nach dem Loggen des aktuellen Kontakts',
			'settings.radio.cwMessages.helpQsoName' => 'Deren Vorname, wie eingegeben oder sonst aus der Abfrage',
			'settings.radio.cwMessages.helpQsoState' => 'Deren Staat, wie eingegeben oder sonst aus der Abfrage',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Nachricht 1, wie sie gesendet würde, innerhalb einer anderen Nachricht. Gültig für Nachrichten 1 bis 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Der Rapport, den du sendest',
			'settings.radio.cwMessages.helpQsoSerial' => 'Deine Seriennummer, in einem Contest, der eine sendet',
			'settings.radio.cwMessages.helpPad' => 'Füllt mit Nullen auf so viele Stellen auf: 7 wird als 007 gesendet',
			'settings.radio.cwMessages.helpCut' => 'Abgekürzte Zahlen, T für 0 und N für 9: 599 wird als 5NN gesendet',
			'settings.radio.cwMessages.helpCutDigits' => 'Wählt die abzukürzenden Ziffern, in Anführungszeichen — 0 ist T, 1 ist A, 5 ist E, 9 ist N',
			'settings.radio.cwMessages.helpFullExample' => 'Vollständiges Beispiel:',
			'settings.radio.cwMessages.helpExample' => 'Sendet W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Mit „Enter sendet Nachrichten“ sendet Enter Nachrichten über ihre Funktionstaste, wie bei N1MM. Der Satz ESM-Nachrichten beginnt mit diesen:',
			'settings.radio.cwMessages.helpEsmCq' => 'Im Run ruft Enter bei leerem Rufzeichenfeld CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Dein Austausch: im Run nach deren Rufzeichen, bei S&P nachdem sie antworten',
			'settings.radio.cwMessages.helpEsmThanks' => 'Dank, sobald der Kontakt geloggt ist: die Platzhalter beziehen sich auf den nächsten Kontakt, nicht auf diesen',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Bei S&P dein Rufzeichen an die Station, die du anrufst',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Im Run deren Rufzeichen vor deinem Austausch',
			'settings.radio.cwMessages.helpEsmAgain' => 'Fragt erneut, wenn nichts von deren Austausch aufgenommen wurde',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Vorschlag für F3 bei //-Stapeln: TU geht raus, nachdem der Kontakt geloggt ist, also bedankt es sich, ruft dann die nächste gestapelte Station und sendet deinen Austausch oder fragt ein Teilrufzeichen zurück (TU KR?); ist nichts mehr übrig, nur TU',
			'settings.radio.voiceMessages.title' => 'Phone-Keyer-Nachrichten',
			'settings.radio.voiceMessages.notSupported' => 'Das aktuelle Funkgerät unterstützt keine Phone-Nachrichten',
			'settings.radio.voiceMessages.description' => 'Dies nutzt die Sprachspeicher des Funkgeräts',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Sprachspeicher (${n})',
			'settings.radio.voiceMessages.labelField' => 'Beschriftung',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Beschriftung Sprachspeicher ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Leer',
			'settings.radio.voiceMessages.notMeasured' => 'Länge unbekannt',
			'settings.radio.voiceMessages.playButton' => 'Abspielen',
			'settings.radio.voiceMessages.recordButton' => 'Aufnehmen',
			'settings.radio.voiceMessages.stopButton' => 'Stopp',
			'settings.radio.voiceMessages.repeat' => 'Nachricht #1 wiederholen',
			'settings.radio.voiceMessages.repeatOff' => 'Nein',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Nach ${n} Sekunden',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Hinweise zum ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Diese Speicher sind im Funkgerät von ${device}. Ihre Namen und Längen gehören zu diesem Gerät.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Im Funkgerät gespeichert, wo auch seine anderen Clients es sehen.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Warte auf die Anzeige [REC] am Funkgerät, halte dann die PTT-Taste und sprich deine Nachricht. Beende sie mit der STOP-Taste hier in der App, bevor du die PTT loslässt, um unerwünschte Klicks zu vermeiden.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Warte, bis die Anzeige [REC] mindestens viermal blinkt, halte dann die PTT-Taste und sprich deine Nachricht. Beende sie mit der STOP-Taste hier in der App, bevor du die PTT loslässt, um unerwünschte Klicks zu vermeiden.',
			'settings.radio.voiceMessages.pill' => 'Sprache',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Speicher ${n} abspielen',
			'settings.radio.voiceMessages.stop' => 'Stopp',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Speicher ${n} aufnehmen',
			'settings.radio.voiceMessages.stopRecording' => 'Aufnahme beenden',
			'settings.radio.voiceMessages.playing' => 'Spielt ab…',
			'settings.radio.voiceMessages.recording' => 'Nimmt auf…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '${label} wird abgespielt',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '${label} wird aufgenommen',
			'settings.radio.voiceMessages.doubtful' => 'Hat das Funkgerät es abgespielt? Es meldete sofort Leerlauf.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Die Speicher müssen direkt am Funkgerät aufgenommen werden.',
			'settings.radio.avoidZeroBeat.title' => 'Zero-Beat bei Spots vermeiden',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Bei verbundenem Funkgerät wird ein paar Hz neben einem CW-Spot abgestimmt, damit nicht alle Anrufer auf demselben Ton rufen.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Genau auf die gespottete Frequenz abstimmen.',
			'settings.radio.zeroBeatRange.title' => 'Zero-Beat: Ausweichbereich',
			'settings.radio.zeroBeatRange.description' => 'Wie weit neben der gespotteten Frequenz, zu beiden Seiten, abgestimmt wird. Der Versatz ist nie nahe null — das wäre wieder Zero-Beat.',
			'settings.help.title' => 'Hilfe & Ressourcen',
			'settings.help.description' => 'Community und Support',
			'settings.help.forums' => 'Ham2K Foren',
			'settings.help.forumsDescription' => 'Hilfe finden, Feedback geben, Ideen diskutieren…',
			'settings.help.chat' => 'Ham2K Chat',
			'settings.help.chatDescription' => 'Der Discord-Server für unsere Online-Community',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videos und Live-Streams',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Weil man nie genug Fotos haben kann…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Folge uns für Neuigkeiten und Updates',
			'settings.help.contact' => 'Kontaktiere uns',
			'settings.help.contactDescription' => 'help@ham2k.com — aber versuche es zuerst in den Foren oder im Chat!',
			'settings.exports.title' => 'Exporte',
			'settings.map.title' => 'Karten',
			'settings.map.style.title' => 'Kartenstil',
			'settings.map.styleOpts.automatic' => 'Automatisch',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Datenschutz',
			'settings.privacy.shareAppData.title' => 'App-Nutzungsdaten teilen',
			'settings.privacy.shareAppData.descriptionOn' => 'Du hilfst uns, die App zu verbessern, indem du Nutzungs-, Konfigurations-, Absturz- und Leistungsdaten teilst',
			'settings.privacy.shareAppData.descriptionOff' => 'App-Nutzungsdaten bleiben privat.\nDas Ham2K-Team kann Abstürze oder andere Probleme nicht erkennen.',
			'settings.privacy.shareOpData.title' => 'Betriebsdaten teilen',
			'settings.privacy.shareOpData.descriptionOn' => 'Einige Betriebsdaten werden öffentlich und mit anderen Nutzern geteilt',
			'settings.privacy.shareOpData.descriptionOff' => 'Betriebsdaten bleiben privat',
			'settings.privacy.privacyPolicy' => 'Datenschutzerklärung',
			'settings.privacy.termsOfService' => 'Nutzungsbedingungen',
			'settings.operatorCall' => 'Operator-Rufzeichen',
			'settings.sync.title' => 'Cloud-Sync',
			'settings.sync.moreSettings' => 'Weitere Sync-Einstellungen',
			'settings.sync.enable' => 'Sync aktivieren',
			'settings.sync.deviceKey' => 'Geräteschlüssel',
			'settings.peers.title' => 'Partnergeräte',
			'settings.peers.enable' => 'Mit anderen Geräten verbinden',
			'settings.peers.enableDescription' => 'Teilen von Betrieb, Logging, CAT und GPS mit anderen Geräten im lokalen Netzwerk erlauben',
			'settings.peers.bleEnable' => 'Über Bluetooth verbinden',
			'settings.peers.bleDescription' => 'Bluetooth LE verwenden, um auch ohne lokales Netzwerk zu verbinden',
			'settings.peers.thisDevice' => 'Dieses Gerät',
			'settings.peers.deviceName' => 'Name',
			'settings.peers.deviceNameHint' => 'So sehen andere Geräte dieses Gerät',
			'settings.peers.pairedDevices' => 'Verknüpfte Geräte',
			'settings.peers.noPairedDevices' => 'Noch keine Geräte verknüpft. Schalte dies auf einem anderen Gerät in diesem Netzwerk ein, um sie zu verknüpfen.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Deine verknüpften Geräte können nicht gelesen werden: ${error}',
			'settings.peers.nearby' => 'In der Nähe',
			'settings.peers.connected' => 'Verbunden',
			'settings.peers.viaBluetooth' => 'über Bluetooth',
			'settings.peers.connecting' => 'Verbinde…',
			'settings.peers.syncing' => 'Synchronisiere…',
			'settings.peers.waitingForThem' => 'Warte auf das andere Gerät',
			'settings.peers.notConnected' => 'Nicht verbunden',
			'settings.peers.wantsToPair' => 'möchte diesen Betrieb teilen',
			'settings.peers.allow' => 'Erlauben',
			'settings.peers.link' => 'Verknüpfen',
			'settings.peers.reject' => 'Ablehnen',
			'settings.peers.forget' => 'Vergessen',
			'settings.peers.forgetTitle' => ({required Object name}) => '${name} vergessen?',
			'settings.peers.forgetBody' => 'Die Synchronisierung mit diesem Gerät wird beendet. Du kannst es später wieder erlauben, und bereits geloggte Kontakte bleiben erhalten.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Mit ${name} verknüpfen',
			'settings.peers.pairBody' => 'Dieses Gerät ist in deinem lokalen Netzwerk und möchte sich verbinden.',
			'settings.peers.pairBodyBle' => 'Dieses Gerät ist in der Nähe und möchte sich über Bluetooth LE verbinden.',
			'settings.peers.pairIdLabel' => 'Geräte-ID',
			'settings.peers.pairWarning' => 'Verknüpfe nur Geräte, die du kennst. Jedes Gerät in diesem Netzwerk kann eine Anfrage senden.',
			'settings.peers.pairWarningBle' => 'Verknüpfe nur Geräte, die du kennst. Jedes Gerät in der Nähe kann eine Anfrage senden.',
			'settings.peers.problem' => ({required Object error}) => 'Lokales Netzwerk nicht erreichbar: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Verbunden mit ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Verbindung zu ${device} verloren',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Partnergeräte: ${connected} von ${linked} verbunden',
			'settings.peers.screenEnable' => 'Bildschirme und Fenster teilen',
			'settings.peers.screenDescription' => 'Anderen Geräten erlauben, Bildschirme oder Fenster dieses Computers anzuzeigen',
			'settings.peers.screenSources' => 'Bildschirme und Fenster',
			'settings.peers.screenRefresh' => 'Liste aktualisieren',
			'settings.peers.screenUnsupportedPlatform' => 'Dieses Gerät kann seinen Bildschirm nicht teilen. macOS kann das; jedes Gerät kann einen von einem anderen geteilten Bildschirm anzeigen.',
			'settings.peers.screenUnsupportedVersion' => 'Bildschirmfreigabe erfordert macOS 12.3 oder neuer. Dieses Gerät kann aber einen von einem anderen geteilten Bildschirm anzeigen.',
			'settings.peers.screenNeedsPermission' => 'macOS braucht deine Erlaubnis zur Bildschirmaufnahme, bevor diese App einen Bildschirm teilen kann.',
			'settings.peers.screenGrantPermission' => 'Um Erlaubnis bitten',
			'settings.peers.screenRelaunchAfterGranting' => 'Erlaube es in den Systemeinstellungen unter Datenschutz & Sicherheit → Bildschirmaufnahme, beende dann diese App und öffne sie neu — macOS teilt einer App die Änderung erst beim nächsten Start mit.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Bildschirmfreigabe: ${error}',
			'settings.peers.screenChooseTitle' => 'Auswählen, was geteilt wird',
			'settings.peers.screenChooseButton' => 'Auswählen, was geteilt wird…',
			'settings.peers.screenTabScreens' => 'Bildschirme',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Fenster',
			'settings.peers.screenTabEmpty' => 'Nichts dieser Art gefunden.',
			'settings.peers.screenSharedSummaryNone' => 'Noch nichts ausgewählt.',
			'settings.peers.screenThisDevice' => 'Dieses Gerät',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Angezeigt auf ${devices}',
			'settings.peers.screenSharedToNobody' => 'Wird nicht angezeigt',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Teilen von ${name} beenden',
			'settings.developerMode' => 'Entwicklermodus',
			'settings.syncPanel.configuration' => 'Sync-Konfiguration',
			'settings.syncPanel.enableTitle' => 'Mit Ham2K Log Filer synchronisieren',
			'settings.syncPanel.enabledDescription' => 'Dein Log wird gesichert und zwischen Geräten synchronisiert',
			'settings.syncPanel.disabledDescription' => 'Aus — bleibt nur auf diesem Gerät',
			'settings.syncPanel.syncing' => 'Synchronisiere',
			'settings.syncPanel.account' => 'Konto',
			'settings.syncPanel.refresh' => 'Aktualisieren',
			'settings.syncPanel.switchAccounts' => 'Konto wechseln',
			'settings.syncPanel.switchAccountsDescription' => 'Dieses Gerät per QR-Code oder E-Mail mit einem anderen Konto verknüpfen',
			'settings.syncPanel.connectionRequests' => 'Verbindungsanfragen',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Ein Gerät wartet darauf, diesem Konto beizutreten', other: '${n} Geräte warten darauf, diesem Konto beizutreten', ), 
			'settings.syncPanel.accountEmailTitle' => 'Konto-E-Mail',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Bestätigung an ${email} gesendet. Öffne den Link dort, um die Änderung abzuschließen.',
			'settings.syncPanel.resendConfirmation' => 'Bestätigungs-E-Mail erneut senden',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Warte auf ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Erneut an ${email} gesendet.',
			'settings.syncPanel.deviceLinked' => 'Dieses Gerät ist jetzt mit diesem Konto verknüpft.',
			'settings.syncPanel.checking' => 'Prüfe…',
			'settings.syncPanel.notLinked' => 'Noch nicht verknüpft',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Lokale Daten ersetzen?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${n} Betrieb', other: '${n} Betriebe', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Synchronisierte Daten',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Dieses Gerät: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Warten auf Upload: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Dieses Gerät: wird geprüft…',
			'settings.syncPanel.countsServerChecking' => 'Server: wird geprüft…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: nicht verfügbar',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Dies sichert und entfernt ${operations} und ${qsos} von diesem Gerät und lädt stattdessen die Daten des Kontos herunter. Die Sicherung bleibt in der Datenbank dieses Geräts.',
			'settings.syncPanel.replace' => 'Ersetzen',
			'settings.syncPanel.pendingBannerTitle' => 'Neues Ham2K-Log-Filer-Konto erkannt',
			'settings.syncPanel.pendingBannerBody' => 'Behalte den vorhandenen Betrieb und die QSOs dieses Geräts und führe sie mit dem Konto zusammen, oder ersetze sie durch die Daten des Kontos (in beiden Fällen bleibt eine Sicherung auf diesem Gerät).',
			'settings.syncPanel.combine' => 'Kombinieren',
			'settings.syncPanel.authIssueTitle' => 'Sync kann sich nicht verbinden',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer lehnt dieses Gerät wiederholt ab. Prüfe dein Rufzeichen in den Sync-Einstellungen.',
			'settings.syncPanel.openSettings' => 'Sync-Einstellungen öffnen',
			'settings.accounts.title' => 'Konten, Dienste & Datenquellen',
			'settings.accounts.none' => 'Keine aktiven Erweiterungen mit Konten',
			'settings.accounts.notConfigured' => 'Nicht konfiguriert',
			'settings.accounts.connected' => 'Verbunden',
			'settings.accounts.cancelLogin' => 'Anmeldung abbrechen',
			'settings.accounts.openInBrowser' => 'Im Browser öffnen',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Angemeldet als ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Drücke Speichern, damit dieses Konto verbunden bleibt.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Verbunden mit ${label}',
			'settings.accounts.connect' => 'Verbinden',
			'settings.accounts.disconnect' => 'Trennen',
			'settings.accounts.connectedAs' => 'Verbunden als',
			'settings.accounts.test' => 'Testen',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Speichern fehlgeschlagen: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Anmeldung fehlgeschlagen: ${error}',
			'settings.accounts.lookupFailed' => 'Konten sind gerade nicht verfügbar — versuche es gleich noch einmal',
			'settings.accounts.browserLoginTitle' => 'Schließe die Anmeldung in deinem Webbrowser ab',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Wenn du fertig bist, versucht der Browser einen Link zu öffnen, der mit „${prefix}“ beginnt. Auf deinem Desktop ist wahrscheinlich nichts registriert, um ihn zu öffnen, also kopiere diesen Link (aus der Adressleiste oder von der Fehlerseite, die der Browser anzeigt) und füge ihn hier ein.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger konnte deinen Browser nicht öffnen. Kopiere den Anmeldelink unten und öffne ihn selbst, kopiere dann den Link, zu dem du weitergeleitet wirst (er beginnt mit „${prefix}“), und füge ihn hier ein.',
			'settings.accounts.copyLoginLink' => 'Anmeldelink kopieren',
			'settings.accounts.pastedLinkLabel' => 'Link hier einfügen',
			'settings.accounts.finishLogin' => 'Anmeldung abschließen',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Das ist nicht der Anmeldelink — er sollte mit „${prefix}“ beginnen.',
			'settings.accounts.pastedLinkWrongLogin' => 'Dieser Link gehört zu einem anderen Anmeldeversuch. Schließe diese Seite und verbinde erneut.',
			'settings.accounts.pastedLinkNoCode' => 'Dieser Link enthält keinen Anmeldecode. Schließe zuerst die Anmeldung ab und kopiere dann den Link, zu dem du weitergeleitet wirst.',
			'settings.accounts.pastedLinkMalformed' => 'Dieser Link scheint abgeschnitten. Kopiere ihn vollständig und füge ihn erneut ein.',
			'settings.accounts.relayLoginWaiting' => 'Warte, bis du die Anmeldung abgeschlossen hast — danach geht es automatisch weiter.',
			'settings.accounts.loginNoResponse' => 'Dieses Gerät hat noch keine Rückmeldung von der Anmeldung erhalten. Wenn du im Browser schon fertig bist, brich ab und verbinde erneut.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger konnte deinen Browser nicht automatisch öffnen. Öffne die Anmeldeseite mit dem Button unten selbst.',
			'settings.accounts.relayLoginUnavailable' => 'Der für diese Anmeldung nötige Sync-Server war nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.',
			'settings.accounts.loginIncompleteResponse' => 'Dieser Anmeldeversuch wurde nicht korrekt abgeschlossen. Bitte verbinde erneut.',
			'settings.accounts.noKeyringTitle' => 'Konto-Anmeldungen können nicht gespeichert werden',
			'settings.accounts.noKeyringText' => 'Ham2K Logger erreicht keinen Schlüsselbund-Dienst auf diesem Computer, daher können Konto-Anmeldungen weder gespeichert noch gelesen werden — das Verbinden eines Kontos schlägt fehl, bis das behoben ist. Installiere und starte **gnome-keyring**, **KWallet** oder **KeePassXC** oder entsperre deinen vorhandenen Schlüsselbund und starte dann neu. Logging, Exporte und Datendateien sind nicht betroffen; die Log-Synchronisierung bleibt solange aus.',
			'settings.accounts.noKeyringInline' => 'Anmeldungen können nicht gespeichert werden: der Schlüsselbund dieses Computers ist nicht erreichbar. Installiere und starte gnome-keyring, KWallet oder KeePassXC oder entsperre deinen vorhandenen.',
			'settings.accounts.noSecureStorageInline' => 'Anmeldungen können nicht gespeichert werden: der sichere Speicher dieses Computers ist nicht erreichbar.',
			'settings.station.title' => 'Stationskonfiguration & CAT-Steuerung',
			'settings.station.none' => 'Keine Geräte konfiguriert',
			'settings.station.add' => 'Hinzufügen',
			'settings.station.addTitle' => 'Gerät hinzufügen',
			'settings.station.searchHint' => 'Geräte durchsuchen',
			'settings.station.noMatches' => 'Kein passendes Gerät',
			'settings.station.detectedEquipment' => 'Erkannte Geräte',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Kann nicht nach Funkgeräten lauschen: ${error}',
			'settings.station.edit' => 'Gerät bearbeiten',
			'settings.station.name' => 'Name',
			'settings.station.nameDescription' => 'Wie du es nennst — „Linkes Funkgerät“. Optional.',
			'settings.station.transport' => 'Verbindung',
			'settings.station.host' => 'Adresse',
			'settings.station.hostDescription' => 'Hostname oder IP-Adresse des Funkgeräts in deinem Netzwerk.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Eine Adresse ist erforderlich',
			'settings.station.portInvalid' => 'Der Port muss zwischen 1 und 65535 liegen',
			'settings.station.connect' => 'Verbinden',
			'settings.station.disconnect' => 'Trennen',
			'settings.station.remove' => 'Entfernen',
			'settings.station.removeTitle' => ({required Object name}) => '${name} entfernen?',
			'settings.station.removeMessage' => 'Es wird nur aus der App entfernt. Die Einstellungen des Geräts bleiben unverändert.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Unbekannter Gerätetyp „${typeKey}“',
			'settings.station.report' => 'Melden',
			'settings.station.reportTitle' => 'Dieses Funkgerät melden',
			'settings.station.reportIntro' => 'Sag uns, welches Funkgerät das wirklich ist und wie es lief. Deine Meldung wird zu einer Karte, die das Ham2K-Team liest, und was du darüber schreibst, wie du es zum Laufen gebracht hast, kann dem nächsten Operator mit demselben Gerät helfen.',
			'settings.station.reportManufacturer' => 'Hersteller',
			'settings.station.reportManufacturerDescription' => 'Wer es herstellt — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Ein Hersteller ist erforderlich',
			'settings.station.reportModel' => 'Modell',
			'settings.station.reportModelDescription' => 'Das Modell, wie das Funkgerät selbst es nennt — „IC-7300“, „FT-991A“.',
			'settings.station.reportModelRequired' => 'Ein Modell ist erforderlich',
			'settings.station.reportOutcome' => 'Wie lief es?',
			'settings.station.reportOutcomeWorks' => 'Hat gut funktioniert',
			'settings.station.reportOutcomeIssues' => 'Hat funktioniert, mit Problemen',
			'settings.station.reportOutcomeFails' => 'Hat gar nicht funktioniert',
			'settings.station.reportOutcomeRequired' => 'Bitte sag uns, wie es lief',
			'settings.station.reportComments' => 'Kommentare',
			'settings.station.reportCommentsPlaceholder' => 'Was funktioniert hat, was nicht, alles, was dich überrascht hat.',
			'settings.station.reportHints' => 'Tipps zur Fehlerbehebung',
			'settings.station.reportHintsPlaceholder' => 'Möchtest du anderen Nutzern Tipps zur Fehlerbehebung geben?',
			'settings.station.reportSend' => 'Meldung senden',
			'settings.station.reportSending' => 'Deine Meldung wird gesendet…',
			'settings.station.reportSent' => ({required Object ref}) => 'Danke — deine Meldung wurde als ${ref} erfasst.',
			'settings.station.reportSentNoRef' => 'Danke — deine Meldung wurde gesendet.',
			'settings.station.reportFailed' => ({required Object error}) => 'Die Meldung wurde nicht gesendet: ${error}',
			'settings.station.troubleshootingNotes' => 'Hinweise zur Fehlerbehebung',
			'settings.station.mainVfo' => 'Haupt-VFO',
			'settings.station.useAsMainVfo' => 'Als Haupt-VFO verwenden',
			'settings.station.serialPort' => 'Serieller Port',
			'settings.station.serialPortDescription' => 'Der Port, an dem die CAT-Schnittstelle des Funkgeräts erscheint.',
			'settings.station.serialPortNone' => 'Keine seriellen Ports gefunden',
			'settings.station.serialPortRequired' => 'Wähle einen seriellen Port',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'Port ${n} von ${total}',
			'settings.station.serialPortSuggested' => 'empfohlen',
			'settings.station.serialPortJustNow' => 'Kürzlich verbunden',
			'settings.station.serialDeviceRequest' => 'USB-Gerät hinzufügen…',
			'settings.station.baudRate' => 'Geschwindigkeit (Baud)',
			'settings.station.baudRateDescription' => 'Muss mit dem CAT-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll zurück und keinen Fehler.',
			'settings.station.serialRtsHigh' => 'RTS hoch halten',
			'settings.station.serialRtsHighDescription' => 'Nur für Funkgeräte, die vor einer Antwort auf RTS warten, z. B. ein Yaesu mit eingeschaltetem CAT RTS. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist RTS die PTT, und Hochhalten bedeutet Senden.',
			'settings.station.serialDtrHigh' => 'DTR hoch halten',
			'settings.station.serialDtrHighDescription' => 'Nur für CAT-Schnittstellen, die ihren Strom aus DTR beziehen, z. B. manche RS-232-Kabel für den FT-817. Bei vielen Kabeln tastet DTR CW oder PTT, und Hochhalten bedeutet Senden.',
			'settings.station.civAddress' => 'CI-V-Adresse des Funkgeräts',
			'settings.station.civAddressDescription' => 'Hexadezimal, wie im CI-V-Menü des Funkgeräts angezeigt. Der IC-705 wird mit A4 ausgeliefert.',
			'settings.station.civAddressInvalid' => 'Eine CI-V-Adresse besteht aus zwei Hex-Ziffern, 01 bis FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Welchen Slice des Funkgeräts diese Verbindung liest und abstimmt.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Wähle einen der Slices des Funkgeräts, A bis H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} wird auf diesem Funkgerät nicht genutzt — wähle einen anderen Slice oder erstelle ihn in SmartSDR',
			'settings.station.channelNotInUse' => 'nicht in Verwendung',
			'settings.station.channelHeldByUnknown' => 'von einem anderen Programm belegt',
			'settings.station.flexNoSlices' => 'Dieses Funkgerät hat keine Slices gemeldet — prüfe, ob SmartSDR läuft und dieser Client abonnieren darf',
			'settings.station.spectrumUnsupported' => 'Dieses Funkgerät sendet kein Spektrum über CAT',
			'settings.station.spectrumRequiresBaud' => 'Erfordert CAT mit 115200 bps',
			'settings.station.spectrumNoRadio' => 'Kein Funkgerät verbunden',
			'settings.station.spectrumWaiting' => 'Warte auf das Spektrum des Funkgeräts…',
			'settings.station.spectrumUnavailable' => 'Spektrumanzeige nicht verfügbar',
			'settings.station.spectrumNoDaxChannel' => 'Jeder DAX-IQ-Kanal dieses Funkgeräts ist belegt',
			'settings.station.spectrumNoPanadapter' => 'Dieser Slice hat keinen Panadapter auf dem Funkgerät',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Das Funkgerät hat einen DAX-IQ-Stream abgelehnt (Fehler ${code})',
			'settings.station.spectrumNoUdp' => 'Die Spektrumdaten des Funkgeräts erreichen dieses Gerät nicht',
			'settings.station.spectrumScopeRefused' => 'Das Funkgerät hat seine Scope-Befehle abgelehnt',
			'settings.station.spectrumOutOfRange' => 'Das Scope des Funkgeräts ist außerhalb des darstellbaren Bereichs eingestellt',
			'settings.station.n3fjpNoRig' => 'In N3FJP ist keine Funkgeräteschnittstelle eingerichtet, daher folgt dies dem, was in N3FJP eingegeben wird, nicht einem Funkgerät',
			'settings.station.winkeyerKeyPort' => 'Tastausgang',
			'settings.station.winkeyerKeyPortDescription' => 'An welche der beiden Ausgangsbuchsen des Keyers dein Funkgerät angeschlossen ist.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'PTT des Keyers verwenden',
			'settings.station.winkeyerPttDescription' => 'Die PTT-Leitung an derselben Buchse tasten, für eine Endstufe oder ein Funkgerät, das sie braucht. Aus lassen bei einem Funkgerät, das über seine Tastenbuchse getastet wird.',
			'settings.station.winkeyerNoAnswer' => 'Kein WinKeyer hat an diesem Port reagiert',
			'settings.station.winkeyerStoppedAnswering' => 'Der WinKeyer hat beim Senden aufgehört zu reagieren; die Nachricht wurde verworfen',
			'settings.station.radioUser' => 'Benutzername des Funkgeräts',
			'settings.station.radioPass' => 'Passwort des Funkgeräts',
			'settings.station.radioLoginDescription' => 'Die Anmeldung unter Network → Remote des Funkgeräts, nicht dein WLAN-Passwort.',
			'settings.station.radioUserRequired' => 'Der Benutzername für die Fernsteuerung des Funkgeräts ist erforderlich',
			'settings.station.connectFailedBusy' => 'Gerät ist belegt',
			'settings.station.connectFailedDenied' => 'Zugriff verweigert',
			'settings.station.connectFailedDevice' => 'Gerät nicht gefunden',
			'settings.station.connectFailedLines' => 'RTS/DTR konnten nicht wie eingestellt gehalten werden, daher wurde der Port geschlossen. Möglicherweise hat ein anderes Programm Hardware-Handshake eingeschaltet gelassen — Kabel abziehen und wieder einstecken.',
			'settings.station.connectFailedNetwork' => 'Das Funkgerät ist im Netzwerk nicht zu finden. Prüfe die Adresse und ob es eingeschaltet und erreichbar ist.',
			'settings.station.connectFailedTimeout' => 'Das Funkgerät hat nicht rechtzeitig reagiert. Prüfe, ob es eingeschaltet und erreichbar ist.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Generisch',
			'settings.station.models.icomGeneric' => 'Icom - Generisch',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Generisch',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Generisch',
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
			'settings.station.models.rigctld' => 'Funkgerät über rigctld gesteuert',
			'settings.station.models.rigctldNodeName' => 'Mein Funkgerät (über rigctld)',
			'settings.station.models.flrig' => 'Funkgerät über flrig gesteuert',
			'settings.station.models.flrigNodeName' => 'Mein Funkgerät (über flrig)',
			'settings.station.models.hrd' => 'Funkgerät über Ham Radio Deluxe® gesteuert',
			'settings.station.models.hrdNodeName' => 'Mein Funkgerät (über HRD)',
			'settings.station.models.n3fjp' => 'Funkgerät über N3FJP gesteuert',
			'settings.station.models.n3fjpNodeName' => 'Mein Funkgerät (über N3FJP)',
			'settings.station.models.commander' => 'Funkgerät über DXLab Commander gesteuert',
			'settings.station.models.commanderNodeName' => 'Mein Funkgerät (über Commander)',
			'settings.station.models.antenna' => 'Antenne',
			'settings.station.models.key' => 'CW-Taste',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Generisches Funkgerät (Platzhalter)',
			'settings.station.models.placeholderRadioNodeName' => 'Mein Funkgerät',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Koaxschalter',
			'settings.station.transports.network' => 'Netzwerk/WLAN',
			'settings.station.transports.usbSerial' => 'USB Seriell',
			'settings.station.transports.wifi' => 'Netzwerk/WLAN',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth Seriell',
			'settings.station.transports.placeholder' => 'Platzhalter',
			'settings.station.troubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.ft891Troubleshooting' => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **CAT RTS muss am Funkgerät AUS sein** (FT-891 Menü **05-08**). Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist dieselbe Leitung die PTT, ein Anheben würde also deinen Sender auftasten. Am eigenen USB-Port des Funkgeräts ist **RTS hoch halten** unter Erweiterte Einstellungen die Alternative.\n- **Die Geschwindigkeit muss** mit CAT RATE des Funkgeräts übereinstimmen (Menü **05-06**). Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.yaesuBinaryTroubleshooting' => 'Dieses Funkgerät spricht Yaesus älteres Fünf-Byte-CAT und reagiert überhaupt nicht, wenn etwas nicht stimmt. Fast immer liegt es an einem dieser Punkte:\n\n- **Das Kabel muss die Pegel wandeln.** Die CAT-Buchse auf der Rückseite ist weder RS-232 noch USB; sie braucht ein CT-62 oder einen gleichwertigen Adapter. Ein einfaches Audio- oder Datenkabel funktioniert für CAT nicht.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen (**#14** beim FT-817, **#19** beim FT-857 oder FT-897). Bei Abweichung sendet das Funkgerät nichts zurück, aber nie einen Fehler.\n- **Lass nie etwas RTS oder DTR an diesem Port anheben.** Bei den meisten Kabeln für diese Funkgeräte sind diese Leitungen PTT und Tastung. Ausnahme ist eine ältere Schnittstelle, die über DTR versorgt wird: schalte dafür **DTR hoch halten** unter Erweiterte Einstellungen ein.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\nDieser Treiber wurde anhand von Yaesus veröffentlichter CAT-Tabelle geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			'settings.station.guohetecTroubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.guohetecTroubleshooting' => 'Der Q900 hat zwei CAT-Protokolle, und dieser Eintrag nutzt das native statt der FT-817-Nachahmung. Wähle hier **Guohetec Q900**, nicht einen FT-817 — die Nachahmung unterstützt weniger Befehle, und das Funkgerät sagt nicht, welches es verwendet.\n\n- **Das USB-C-Kabel ist die CAT-Verbindung** und verbindet auch die Soundkarte. Die Geschwindigkeit spielt dort keine Rolle; der Port ignoriert die Einstellung.\n- **Lass nie etwas RTS oder DTR an diesem Port anheben.** Bei einem seriellen Kabel sind diese Leitungen PTT und Tastung.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Ein Gerät der zweiten Generation verhält sich anders** als eines der ersten. Lange auf Menu drücken, dann About: HW 2.0 ist die zweite Generation.\n\nDieser Treiber wurde anhand des veröffentlichten Protokolls des Herstellers geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			'settings.station.yaesuTroubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.yaesuTroubleshooting' => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält. Bei Digirig, SignaLink und den meisten selbstgebauten Kabeln ist dieselbe Leitung die PTT, ein Anheben würde also deinen Sender auftasten. Am eigenen USB-Port des Funkgeräts ist **RTS hoch halten** unter Erweiterte Einstellungen die Alternative. Wo diese Einstellung liegt, hängt vom Modell ab (Menü **05-08** beim FT-891).\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Die Modi folgen der Tabelle des FT-891.** Die meisten Yaesu-Geräte stimmen damit überein, aber bei einem Funkgerät, das seine Modi anders nummeriert, werden diese falsch angezeigt und gesetzt. Die Frequenz ist davon nicht betroffen.',
			'settings.station.yaesuRs232Troubleshooting' => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **Die CAT-Buchse ist RS-232.** Sie braucht einen USB-Seriell-Adapter und ein 1:1-DB-9-Kabel — ein Nullmodemkabel vertauscht die Leitungen, und das Funkgerät hört nie etwas.\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält, außer **RTS hoch halten** ist unter Erweiterte Einstellungen eingeschaltet.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\nDieser Eintrag wurde anhand veröffentlichter CAT-Dokumentation geschrieben und noch nicht mit einem dieser Funkgeräte getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			'settings.station.yaesuUsbTroubleshooting' => 'Das Funkgerät empfängt Befehle, antwortet aber nicht. Fast immer liegt es an einem dieser Punkte:\n\n- **Verwende den ersten der beiden USB-Ports des Funkgeräts.** CAT liegt normalerweise auf dem ersten (unter Windows der **Enhanced** COM-Port); der zweite (**Standard**) ist für PTT und Tastung. Die Auswahl zeigt auf den ersten, wo immer sie die beiden unterscheiden kann.\n- **CAT RTS muss am Funkgerät AUS sein.** Ist es an, wartet das Funkgerät auf eine Handshake-Leitung, die die App niedrig hält, außer **RTS hoch halten** ist unter Erweiterte Einstellungen eingeschaltet.\n- **Die Geschwindigkeit muss** mit dem CAT-RATE-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.',
			'settings.station.k4SerialNotes' => 'Verbinde die hintere USB-B-Buchse (PC) des K4. Für CAT funktionieren sowohl USB-PC1 als auch USB-PC2; wähle einen freien Port und passe die Einstellung Serial USB-PCn: Baud Rate am Funkgerät an. HaLo trägt 38400 vor; ändere es bei Bedarf. Eine andere Anwendung muss den anderen Port oder Ethernet nutzen.\n\nDiese Verbindung steuert das Funkgerät und seine Keyer; sie sendet kein Audio an HaLo.',
			'settings.station.k4TcpNotes' => 'Verbinde die Ethernet-Buchse des K4 mit deinem lokalen Netzwerk. Gib Hostname oder IP-Adresse und den CAT-Port 9200 ein. Das ist die CAT-Steuerung, nicht die separate Remote-Audio-Verbindung auf Port 9204.\n\nHaLo steuert das Funkgerät und seine Keyer, ohne Audio oder Panadapter-Daten zu übertragen.',
			'settings.station.k4PowerTimeout' => 'Die Leistung des K4 wurde nicht geändert, weil das Funkgerät seinen Ausgangsbereich nicht bestätigt hat. Versuche es erneut.',
			'settings.station.k4PowerRange' => 'Die Leistung des K4 muss 0,1–110 W betragen, oder 0,0001–0,01 W, wenn der Milliwatt-Ausgang für Transverter aktiv ist.',
			'settings.station.elecraftTroubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.elecraftTroubleshooting' => 'Elecraft-Geräte sprechen Kenwood-CAT, und sowohl ein KX2 als auch ein KX3 wurden so betrieben — VFO in beide Richtungen, Moduswechsel und CW-Zero-Beat funktionieren alle.\n\nWenn das Funkgerät nicht reagiert, liegt es fast immer an einem dieser Punkte:\n\n- **Die Geschwindigkeit muss** mit der unter **RS232** im Menü des Funkgeräts eingestellten Rate übereinstimmen. Ab Werk ist 38400 eingestellt. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n\n**Wenn die Frequenz stimmt, aber der Modus falsch ist**, sag uns Bescheid. Die Einträge für KX2 und KX3 lesen den Modus an einer Stelle der Statusantwort des Funkgeräts, die wir anhand der uns bekannten Geräte festgelegt haben, und eine Firmware, die ihn woanders ablegt, erfahren wir nur durch eine Meldung.\n\nZum K3 gibt es noch keine Meldung, bitte sag uns, was passiert, wenn du einen betreibst. Der K4 hat einen eigenen Eintrag.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Wenn das Funkgerät verbindet, aber keine Frequenz anzeigt',
			'settings.station.kenwoodTroubleshooting' => 'Dieser Treiber ist mit Kenwoods TS-590SG und TS-480, QRP Labs\' QMX und QCX-mini sowie Elecrafts KX2 und KX3 erprobt. Der Rest der Reihe wurde anhand veröffentlichter CAT-Referenzen geschrieben, bitte melde also in jedem Fall, was passiert.\n\nWenn das Funkgerät nicht reagiert, liegt es fast immer an einem dieser Punkte:\n\n- **Die Geschwindigkeit muss** mit dem CAT-Menü des Funkgeräts übereinstimmen. Bei Abweichung sendet das Funkgerät Datenmüll oder nichts zurück, aber nie einen Fehler.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.\n- **Manche Geräte brauchen aktiviertes CAT** im Menü, bevor sie überhaupt reagieren.\n\n**Mehrere SDR-Frontends sprechen dasselbe Protokoll**, daher lohnt es sich, diesen Eintrag auch für diese auszuprobieren; Elecraft-Geräte sind separat unter Elecraft aufgeführt. Wenn die Frequenz stimmt, aber der Modus falsch ist oder fehlt, ist das der eine Teil, der sich innerhalb der Reihe unterscheidet — die App ermittelt ihn aus dem Funkgerät und fragt ersatzweise direkt nach, der Modus kann also einfach verzögert erscheinen.',
			'settings.station.statusConnected' => 'Verbunden',
			'settings.station.statusLost' => 'Getrennt',
			'settings.station.notConfigured' => 'Nicht konfiguriert',
			'settings.station.currentConfiguration' => 'Aktuelle Konfiguration',
			'settings.station.currentTransceiver' => 'Aktueller Transceiver',
			'settings.station.radioMode' => 'Modus des Funkgeräts',
			'settings.station.keyerNotSupported' => 'Vom aktuellen Funkgerät nicht unterstützt',
			'settings.station.catControlPreferences' => 'Einstellungen für CAT-Steuerung',
			'settings.station.chooseTransceiver' => 'Transceiver wählen',
			'settings.station.configurationSection' => 'Konfiguration',
			'settings.station.noTransceiverSelected' => 'Kein Transceiver ausgewählt',
			'settings.station.makeMainVfo' => ({required Object name}) => '${name} als Haupt-VFO verwenden',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, zero: 'Keine Transceiver', one: '${count} Transceiver', other: '${count} Transceiver', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Antenne', other: '${count} Antennen', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} weiteres Gerät', other: '${count} weitere Geräte', ), 
			'settings.station.equipmentInventory' => 'Geräteinventar',
			'settings.station.equipmentInUse' => 'Transceiver-Steuerung',
			'settings.station.noTransceiver' => 'Keiner',
			'settings.station.peerRadioNotAvailable' => 'Nicht verfügbar',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Auf ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} ist an einem anderen Gerät',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Dieses Funkgerät ist mit ${device} verbunden. Verbindung und Einstellungen werden auf jenem Gerät konfiguriert.',
			'settings.station.antennaInUse' => 'Verwendete Antenne',
			'settings.station.keyInUse' => 'Verwendete Taste',
			'settings.station.noneSelected' => 'Keine',
			'settings.station.moreSettings' => 'Weitere Einstellungen',
			'settings.station.icomCivTroubleshootingTitle' => 'Wenn für dasselbe Funkgerät zwei serielle Ports erscheinen',
			'settings.station.icomCivTroubleshooting' => 'Mehrere Icom-Funkgeräte, darunter der IC-705, stellen **zwei** USB-Seriell-Ports gleichzeitig bereit (Icom nennt sie Port A und Port B), beide standardmäßig auf CI-V eingestellt. Weder diese App noch dein Betriebssystem kann sie darüber hinaus unterscheiden: dieselbe USB-Vendor-/Product-ID erscheint einfach zweimal, hier manchmal mit dem Suffix `#2` markiert. **Port A ist meist der richtige** — normalerweise der erste, den dein Betriebssystem oder Browser auflistet, und wo diese App die beiden Ports unterscheiden kann, markiert sie ihn als empfohlen. Wenn Befehle rausgehen und das Funkgerät nie reagiert, probiere als Nächstes den anderen Port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Wenn das Funkgerät nie reagiert',
			'settings.station.civAddressTroubleshooting' => '- **Die CI-V-Adresse muss** mit dem Menü des Funkgeräts übereinstimmen. Dieser Eintrag trägt die Werksadresse des Modells vor, aber gerade bei einem Gerät an einem gemeinsamen CI-V-Bus wird sie geändert. Ein an die falsche Adresse gesendeter Frame wird stillschweigend ignoriert, was genau wie ein defektes Kabel aussieht.\n- **Die Geschwindigkeit muss** mit CI-V BAUD RATE des Funkgeräts übereinstimmen (bei USB: CI-V USB Baud Rate). Stelle am Funkgerät denselben Wert wie hier ein, **nicht Auto**. Auf Auto verbinden sich manche Funkgeräte, darunter der IC-7300, und reagieren nach etwa einer Minute nicht mehr.\n- **Eine andere App blockiert evtl. den Port**: WSJT-X, fldigi und rigctld halten ihn alle offen.',
			'settings.station.ic7300Mk2Note' => '\n- Der **IC-7300 MK2** wird mit Adresse `B6` ausgeliefert, nicht mit der hier vorgetragenen `94` — wähle stattdessen den Eintrag IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- Der **IC-705** stellt zwei USB-Seriell-Ports bereit, beide nach dem Funkgerät benannt. CI-V liegt auf dem **ersten** davon, auf den die Auswahl zeigt, wo immer sie die beiden unterscheiden kann.',
			'settings.station.ic7760PortNote' => '\n- Der **IC-7760** spricht CI-V auf **Port A** der beiden USB-Seriell-Ports, die er bereitstellt.',
			'settings.station.x6100PortNote' => '\n- Der **X6100** spricht CI-V auf seinem **DEV**-Port — dem zweiten der beiden seriellen Ports, die er bereitstellt, und dem, auf den die Auswahl zeigt.',
			'settings.station.rigctldTroubleshootingTitle' => 'Wenn die App sich nicht verbinden kann',
			'settings.station.rigctldTroubleshooting' => 'Dies verbindet sich mit einem **rigctld-Daemon, den du selbst startest**, nicht direkt mit dem Funkgerät — das Hamlib-Backend spricht mit dem Funkgerät und unterstützt Hunderte von Modellen.\n\n- **Der Daemon muss bereits laufen**, z. B. `rigctld -m 1035 -r /dev/ttyUSB0`. Die Modellnummer deines Funkgeräts findest du mit `rigctl -l`.\n- **Von einem anderen Rechner aus** starte ihn mit `-T 0.0.0.0`: standardmäßig nimmt rigctld nur Verbindungen vom eigenen Rechner an.\n- **Port** ist 4532, außer du hast den Daemon mit `-t` gestartet.\n- Fehlt nach dem Verbinden die Frequenz, kann meist der Daemon selbst das Funkgerät nicht erreichen. Teste es mit `rigctl -m 2 f` auf dem Rechner des Daemons.',
			'settings.station.flrigTroubleshootingTitle' => 'Wenn die App sich nicht verbinden kann',
			'settings.station.flrigTroubleshooting' => 'Dies verbindet sich mit einem **flrig-Programm, das du selbst startest**, nicht direkt mit dem Funkgerät — flrig spricht mit dem Funkgerät und unterstützt die meisten Hersteller und Modelle.\n\n- **flrig muss bereits laufen**, mit konfiguriertem und verbundenem Transceiver.\n- **Port** ist 12345, außer du hast ihn in der flrig-Konfiguration geändert (Config → Setup → Server).\n- **Von einem anderen Rechner aus** stelle sicher, dass der flrig-Server erreichbar ist. Er lauscht auf allen Schnittstellen, aber deine Firewall sieht das evtl. anders.\n- Fehlt nach dem Verbinden die Frequenz, kann meist flrig selbst das Funkgerät nicht erreichen. Prüfe, ob die Anzeige von flrig dem Abstimmknopf folgt.',
			'settings.station.hrdTroubleshootingTitle' => 'Wenn die App sich nicht verbinden kann',
			'settings.station.hrdTroubleshooting' => 'Dies verbindet sich mit **Rig Control von Ham Radio Deluxe auf deinem Computer**, nicht direkt mit dem Funkgerät — HRD spricht mit dem Funkgerät.\n\n- **Rig Control muss bereits laufen** und mit dem Funkgerät verbunden sein.\n- **Sein IP-Server muss aktiviert sein.** Nur darüber spricht Rig Control mit anderen Programmen.\n- **Port** ist 7809, außer du hast ihn in den Einstellungen des IP-Servers geändert.\n- **Von einem anderen Rechner aus** stelle sicher, dass deine Firewall die Verbindung durchlässt.\n\nDieser Eintrag wurde anhand veröffentlichter Beschreibungen des HRD-Protokolls geschrieben und noch nicht mit HRD getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Wenn die App sich nicht verbinden kann',
			'settings.station.n3fjpTroubleshooting' => 'Dies verbindet sich mit **einem N3FJP-Logprogramm auf deinem Computer**, nicht direkt mit dem Funkgerät — N3FJP spricht mit dem Funkgerät.\n\n- **Die API des Programms muss eingeschaltet sein**: Settings → Application Program Interface, **TCP API Enabled** aktivieren.\n- **Port** ist 1100, außer du hast ihn dort geändert.\n- **In N3FJP muss eine Funkgeräteschnittstelle eingerichtet sein**, um dem Funkgerät zu folgen oder es abzustimmen. Ohne sie meldet es nur, was in sein Eingabefenster getippt wird.\n- N3FJP meldet nur Band, Modus und Frequenz: keine Leistung, keinen Sendezustand.\n\nDieser Eintrag wurde anhand der veröffentlichten API von N3FJP geschrieben und noch nicht mit N3FJP getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshootingTitle' => 'Wenn die App sich nicht verbinden kann',
			'settings.station.commanderTroubleshooting' => 'Dies verbindet sich mit **DXLab Commander auf deinem Computer**, nicht direkt mit dem Funkgerät — Commander spricht mit dem Funkgerät.\n\n- **Commander muss bereits laufen** und mit dem Funkgerät verbunden sein.\n- **Sein Netzwerkdienst muss eingeschaltet sein**: der Button **Net Serv** im Radio-Bereich des Configuration-Fensters von Commander.\n- **Port** ist 52002, der dritte Port des Blocks ab dem **Base Port** von Net Serv (52000, außer du hast ihn geändert).\n- **Von einem anderen Rechner aus** stelle sicher, dass deine Firewall die Verbindung durchlässt.\n\nDieser Eintrag wurde anhand der veröffentlichten TCP-Nachrichten von Commander geschrieben und noch nicht mit Commander getestet. Wenn er halb funktioniert, ist das eine Meldung wert.',
			'settings.station.ic705TroubleshootingTitle' => 'Wenn das Funkgerät nie reagiert',
			'settings.station.ic705Troubleshooting' => 'Das Funkgerät hat eine **einzige** Fernsteuerungssitzung. Wird die Anmeldung ignoriert, nutzt fast immer etwas anderes sie.\n\n- **Schließe alle anderen Clients.** wfview oder RS-BA1, mit demselben Funkgerät verbunden, belegen diese eine Sitzung, und die Anmeldung hier wird solange einfach ignoriert.\n- **Prüfe die Netzwerkeinstellungen des Funkgeräts.** WLAN muss an sein, das Funkgerät muss im selben Netzwerk sein und seine Fernsteuerungsfunktion (Network) muss aktiviert sein.\n- **Schalte das WLAN des Funkgeräts aus und wieder ein**, wenn es hängen bleibt. Das löst zuverlässig eine auf dem Funkgerät hängende Sitzung.\n\nEin **falsches Passwort wird ausdrücklich abgelehnt**, nicht mit Schweigen beantwortet. Wenn du hier gelandet bist statt bei einer Meldung „abgelehnt“, ist das Passwort nicht das Problem.',
			'settings.station.statusStale' => 'Reagiert nicht',
			'settings.station.statusDisconnected' => 'Nicht verbunden',
			'settings.station.statusConnecting' => 'Verbinde…',
			'settings.station.statusDisconnecting' => 'Trenne…',
			'settings.station.statusError' => 'Verbindung fehlgeschlagen',
			'settings.station.currentRadioSettings' => 'Aktuelle Funkgeräteeinstellungen',
			'settings.station.notSupportedByThisRadio' => 'Von diesem Funkgerät nicht unterstützt',
			'settings.station.keyerRowLabel' => 'Keyer',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Phone',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Sprach-Keyer: ${count} Speicher im Funkgerät',
			'settings.station.antennaBands' => 'Bänder',
			'settings.station.antennaType' => 'Antennentyp',
			'settings.station.antennaTypeRequired' => 'Wähle einen Antennentyp',
			'settings.station.antennaTypes.dipole' => 'Dipol',
			'settings.station.antennaTypes.vertical' => 'Vertikal',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Langdraht / EFHW',
			'settings.station.antennaTypes.other' => 'Andere',
			'settings.station.keyType' => 'Tastentyp',
			'settings.station.keyTypeRequired' => 'Wähle einen Tastentyp',
			'settings.station.keyTypes.straight' => 'Handtaste',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mechanische halbautomatische Taste)',
			'settings.station.keyTypes.fullyAutomatic' => 'Vollautomatischer Keyer',
			'settings.station.keyTypes.singlePaddle' => 'Einhebel-Paddle',
			'settings.station.keyTypes.dualPaddle' => 'Doppelhebel-Paddle',
			'settings.station.keyTypes.computerDriven' => 'Computergesteuert',
			'settings.station.keyTypes.other' => 'Andere',
			'settings.station.softwareIntermediaries' => 'Software-Vermittler',
			'settings.station.otherBrands' => 'Andere Marken',
			'settings.station.otherEquipment' => 'Andere Geräte (Antennen, Tasten usw.)',
			'settings.station.newAntenna' => 'Neue Antenne',
			'settings.station.newKey' => 'Neue Taste',
			'settings.station.newKeyer' => 'WinKeyer (K1EL oder kompatibel)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT-Keyer in ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Taste an ${device}',
			'settings.station.cwKeyerArea' => 'Keyer-Bereich',
			'settings.station.trackStationInfo' => 'Stationsinfo für jedes QSO erfassen',
			'settings.station.includeStationInfoInAdif' => 'In ADIF-Exporte aufnehmen',
			'settings.station.whatToTrack' => 'Was erfassen?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Leistung',
			'settings.station.watts' => 'Watt',
			'settings.station.trackFieldAntenna' => 'Antenne',
			'settings.station.trackFieldKey' => 'CW-Taste',
			'settings.station.placeholderConnectDelay' => 'Verbindungsverzögerung (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Wie lange der simulierte Handshake dauert. Leer oder 0 verbindet sofort.',
			'settings.station.placeholderDropAfter' => 'Trennen nach (Sekunden)',
			'settings.station.placeholderDropAfterDescription' => 'Die Verbindung von selbst schließen, um das Wiederverbinden zu testen. Leer oder 0 trennt nie.',
			'settings.station.placeholderFailConnect' => 'Verbindung immer fehlschlagen lassen',
			'settings.station.placeholderConnectFailure' => 'Das Platzhalter-Funkgerät wurde angewiesen, diese Verbindung abzulehnen',
			'settings.station.placeholderFreq' => 'Frequenz (kHz)',
			'settings.station.placeholderFreqDescription' => 'Wo das Platzhalter-Funkgerät startet. Danach meldet es zurück, worauf die App es abstimmt.',
			'settings.station.placeholderMode' => 'Modus',
			'settings.station.placeholderModeDescription' => 'Der Modus, mit dem das Platzhalter-Funkgerät startet, z. B. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Leistung (Watt)',
			'settings.station.placeholderPurpose' => 'Verwende dieses Funkgerät, um für das Log festzuhalten, welches Gerät du benutzt',
			'settings.station.placeholderReplyDelay' => 'Antwortverzögerung (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Wie lange das Platzhalter-Funkgerät braucht, um eine Änderung zurückzumelden. Leer oder 0 antwortet sofort.',
			'settings.station.cwKeyerField' => 'CAT-CW-Keyer',
			'settings.station.cwKeyerFieldDescription' => 'Ob dieses Funkgerät CW aus Text über CAT tastet. Aus bei einem Gerät, das die App nicht kennt.',
			'settings.station.voiceMemories' => 'Sprachspeicher',
			'settings.station.voiceMemoriesDescription' => 'Wie viele Sprachspeicher das Funkgerät über CAT abspielt. 0 für keine.',
			'settings.station.voiceMemoriesInvalid' => 'Eine ganze Zahl, 0 oder mehr',
			'settings.station.yaesuMeterCapture' => 'Messwerte aufzeichnen',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Liest beim Senden das Ausgangsleistungs-Meter und das High-SWR-Flag des Funkgeräts und schreibt die Rohwerte ins Protokoll. Dient zum Erstellen der Skala, die Yaesu nicht veröffentlicht — die Werte werden nicht als Anzeigen dargestellt.',
			'settings.station.yaesuMeterCaptureDescription' => 'Liest beim Senden die PO-, SWR- und ALC-Meter des Funkgeräts und schreibt die Rohwerte ins Protokoll. Dient zum Erstellen der Skala, die Yaesu nicht veröffentlicht — die Werte werden nicht als Anzeigen dargestellt.',
			'settings.station.telemetryInterval' => 'Intervall für Messwerte (ms)',
			'settings.station.telemetryIntervalDescription' => 'Wie oft die Meter des Funkgeräts beim Senden gelesen werden. Leer lassen für das Schnellste, was diese Verbindung schafft, bis 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Eine ganze Zahl in Millisekunden, ${min} bis ${max}',
			'settings.station.pollInterval' => 'Abfrageintervall im Leerlauf (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Wie oft das Funkgerät nach Frequenz und Modus gefragt wird, solange sich keines davon ändert. Leer lassen für ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Eine ganze Zahl in Millisekunden, ${min} bis ${max}',
			'settings.station.advancedSettings' => 'Erweiterte Einstellungen',
			'settings.station.placeholderSwr' => 'SWR-Wert',
			'settings.station.placeholderSwrDescription' => 'Was dieses Funkgerät beim Senden auf seinem SWR-Meter meldet. Über 1,8 warnt das Panel.',
			'settings.station.placeholderSwrInvalid' => 'Eine Zahl, 1 oder mehr',
			'settings.station.keyerNone' => 'Keiner',
			'settings.station.cwDialect' => 'CW-Tastungsdialekt',
			'settings.station.cwDialectDescription' => 'Welche Form des KY-Befehls dieses Funkgerät erwartet. Keiner bedeutet keine CW-Tastung über CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, auf 24 aufgefüllt)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY-Text)',
			'settings.station.voiceDialect' => 'Sprach-Keyer-Dialekt',
			'settings.station.voiceDialectDescription' => 'Wie dieses Funkgerät seine Sprachspeicher über CAT abspielt. Keiner bedeutet keine Sprachspeicher über CAT. Mit Dialekt und ohne Anzahl gilt die Standardanzahl des Dialekts.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, wie TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB und DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (Schalter-Tipps)',
			'settings.station.placeholderDiagnostic' => 'Simuliert',
			'settings.station.placeholderWholeNumberInvalid' => 'Muss eine ganze Zahl sein, 0 oder mehr',
			'settings.station.placeholderFreqInvalid' => 'Muss eine Frequenz in kHz sein, größer als null',
			'settings.station.placeholderModeInvalid' => 'Muss ein Modusname sein, z. B. USB, CW, FT8',
			'settings.station.switchLayout' => 'Belegung',
			'settings.station.switchLayoutDescription' => 'An welcher Seite des Schalters deine Funkgeräte angeschlossen sind.',
			'settings.station.switchLayoutRequired' => 'Wähle, wie der Schalter verkabelt ist',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Der Schalter hat „${command}“ abgelehnt (Fehler ${code})',
			'settings.station.switchBusyTransmitting' => 'Dieser Port sendet — Antenne nicht geändert',
			'settings.station.switchNoAntenna' => 'Keine',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenne an Port ${port}',
			'settings.station.switchAntennaForDescription' => 'Welche deiner Antennen an diesem Port des Schalters angeschlossen ist.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} Antennen, ${radios} Funkgeräte',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} Antennen, 1 Funkgerät',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 Antenne, ${radios} Funkgeräte',
			'settings.station.switchCommonPort' => 'Gemeinsam',
			'settings.station.dcnAddress' => 'Geräteadresse',
			'settings.station.dcnAddressDescription' => 'Die an den DIP-Schaltern des Moduls eingestellte Adresse. Ein Koax-Relaismodul ist ab Werk auf 2 eingestellt.',
			'settings.station.dcnAddressRequired' => 'Muss eine Geräteadresse von 1 bis 99 sein',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'folgt den Banddaten',
			'settings.station.switchPortTransmittingHint' => 'sendet — jetzt nicht änderbar',
			'settings.station.switchCurrentStateHeader' => 'Aktueller Zustand',
			'settings.station.switchCurrentStateDescription' => 'An welcher Antenne jeder Funkgeräte-Port gerade ist. Änderungen wirken sofort.',
			'settings.station.switchWiringHeader' => 'Verkabelung',
			'settings.station.switchPortInhibitedHint' => 'Senden gesperrt',
			'settings.station.configUnreadable' => 'Die gespeicherten Einstellungen dieses Funkgeräts konnten nicht gelesen werden. Öffne seine Einstellungen und gib sie erneut ein, oder entferne es und füge es wieder hinzu.',
			'settings.station.autoConnectHeld' => 'HaLo reagierte beim letzten Verbinden mit diesem Funkgerät nicht mehr, daher wurde diesmal nicht automatisch verbunden. Drücke Verbinden, um es erneut zu versuchen.',
			'settings.offlineData.title' => 'Offline-Daten',
			'settings.offlineData.noFiles' => 'Keine Datendateien',
			'settings.offlineData.noFilesDescription' => 'Aktiviere Aktivitäts- oder Abfrage-Erweiterungen, um ihre Offline-Daten hier herunterzuladen.',
			'settings.offlineData.refresh' => 'Aktualisieren',
			'settings.offlineData.refreshing' => 'Aktualisiere…',
			'settings.offlineData.updateAll' => 'Alle aktualisieren',
			'settings.offlineData.updatingAll' => 'Alle Datendateien werden aktualisiert…',
			'settings.offlineData.neverDownloaded' => 'Nie heruntergeladen',
			'settings.offlineData.updatedJustNow' => 'Gerade eben aktualisiert',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Vor ${days} T aktualisiert',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Vor ${days} T ${hours} Std. aktualisiert',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Vor ${hours} Std. aktualisiert',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Vor ${hours} Std. ${minutes} Min. aktualisiert',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Vor ${minutes} Min. aktualisiert',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Der letzte Download hatte nur ${imported} von ${existing} Einträgen und wurde nicht verwendet. Aktualisiere, um ihn zu übernehmen.',
			'settings.offlineData.extensionsSection' => 'Erweiterungen',
			'settings.profiles.notSet' => 'Nicht festgelegt',
			'settings.profiles.personalInfo' => 'Persönliche Daten',
			'settings.profiles.personalInfoNote' => 'Kann in erzeugte Logs aufgenommen werden, wenn es für Einreichungen relevant ist',
			'settings.profiles.name' => 'Name',
			'settings.profiles.email' => 'E-Mail',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'ARRL-Sektion',
			'settings.profiles.racSection' => 'RAC-Sektion',
			'settings.profiles.section' => 'Sektion',
			'settings.search.clear' => 'Leeren',
			'settings.search.hint' => 'Einstellungen durchsuchen',
			'settings.developer.developerModeDescription' => 'Entwicklerwarnungen, Debug-Logs und Werkzeuge aktivieren.',
			'settings.developer.experiments' => 'Experimente',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} aktiviert', other: '${count} aktiviert', ), 
			'settings.developer.patchTrack' => 'Code-Push-Zweig',
			'settings.developer.patchTrackDescription' => 'Welchem Over-the-Air-Code-Push-Ring dieses Gerät folgt. Experimentellere Ringe erhalten Korrekturen früher, aber weniger getestet. Code-Pushes werden beim nächsten Neustart angewendet.',
			'settings.developer.trackStable' => 'Stabil',
			'settings.developer.trackUnstable' => 'Instabil',
			'settings.developer.trackBleeding' => 'Experimentell',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Prüfe „${track}“ auf einen Code-Push…',
			'settings.developer.patchDownloaded' => 'Code-Push heruntergeladen — starte die App neu, um ihn anzuwenden.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Kein neuer Code-Push auf „${track}“.',
			'settings.developer.noPatchInstalled' => 'Kein Code-Push installiert — das Release-Binary läuft.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Code-Push #${patch} läuft.',
			'settings.developer.deepLinks' => 'Deep Links',
			'settings.developer.registerUrlSchemes' => 'URL-Schemata registrieren',
			'settings.developer.registerUrlSchemesDescription' => 'com.ham2k://-Links mit dieser Kopie der App öffnen',
			'settings.developer.registerUrlSchemesDone' => 'Diese Kopie öffnet jetzt com.ham2k://-Links',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Registrierung fehlgeschlagen: ${error}',
			'settings.developer.systemInformation' => 'Systeminformationen',
			'settings.developer.appVersion' => 'App-Version',
			'settings.developer.dataFolder' => 'Datenordner',
			'settings.developer.loading' => '(lädt…)',
			'settings.developer.panelLoadFailed' => 'Dieses Einstellungs-Panel konnte nicht geladen werden.',
			'settings.developer.extDevServer' => 'Erweiterungs-Dev-Server',
			'settings.developer.extensionSettings' => 'Erweiterungseinstellungen',
			'settings.developer.extDevServerDescription' => 'Erweiterungen von einem Dev-Server in deinem Netzwerk statt der in die App eingebauten laden und beim Speichern neu laden.',
			'settings.developer.extDevServerAddress' => 'Serveradresse',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Verbinden',
			'settings.developer.extDevServerDisconnect' => 'Trennen',
			'settings.developer.extDevServerConnecting' => 'Verbinde…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Liefert ${count} Erweiterung: ${keys}', other: 'Liefert ${count} Erweiterungen: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Nicht verbunden',
			'settings.developer.extDevServerReconnect' => 'Beim Start neu verbinden',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Zuletzt neu geladen: ${key} um ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Erweiterung lässt sich nicht bauen', other: '${count} Erweiterungen lassen sich nicht bauen', ), 
			'settings.developer.catalog' => 'Erweiterungskatalog',
			'settings.developer.catalogDescription' => 'Den Katalog von einem anderen Server lesen — einem lokalen, während am Katalog selbst gearbeitet wird. Leer bedeutet catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Katalogadresse',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Zweige für Katalogsuche',
			'settings.developer.catalogSearchStable' => 'Nur stabil',
			'settings.developer.catalogSearchUnstable' => 'Instabil oder besser',
			'settings.developer.catalogSearchBleeding' => 'Experimentell oder besser',
			'settings.about.notices' => 'Hinweise & Nachrichten',
			'settings.about.noticesDescription' => 'Ankündigungen und Statusmeldungen',
			'settings.about.releaseNotes' => 'Versionshinweise',
			'settings.about.copiedVersion' => 'Versionsdetails in die Zwischenablage kopiert',
			'settings.panels.settings' => 'App-Einstellungen',
			'settings.panels.settingsDescription' => 'Richte die App so ein, wie du sie willst',
			'settings.panels.commonSettings' => 'Allgemeine Einstellungen',
			'settings.panels.syncDescription' => 'Deine Logs sichern und zwischen Geräten synchronisieren',
			'settings.panels.accountsDescription' => 'Dienst-Anmeldedaten, Offline-Daten und mehr',
			'settings.panels.extensions' => 'Erweiterungen & Funktionen',
			'settings.panels.extensionsDescription' => 'Aktivitäten, Contests, Dashboard-Panels und weitere Funktionen',
			'settings.panels.profilesDescription' => 'Operator-Rufzeichen und Stationsprofil',
			'settings.panels.stationProfiles' => 'Stationsprofile',
			'settings.panels.developerSettings' => 'Entwicklereinstellungen',
			'settings.panels.developerSettingsDescription' => 'Debugging- und Entwicklungswerkzeuge',
			'settings.panels.about' => 'Über',
			'settings.panels.aboutDescription' => 'Version, Danksagungen und rechtliche Informationen',
			'settings.panels.unavailableTitle' => 'Einige Einstellungen sind nicht verfügbar',
			'settings.panels.unavailableText' => 'Die Erweiterungs-Laufzeit konnte nicht starten, daher fehlen Einstellungen von Erweiterungen.',
			'settings.panels.station' => 'Stationskonfiguration',
			'settings.panels.stationDescription' => 'CAT-Steuerung und weitere Optionen',
			'settings.panels.peers' => 'Partnergeräte',
			'settings.panels.peersDescription' => 'Mit anderen Geräten in der Nähe verbinden',
			'settings.showMoreSettings' => 'Weitere Einstellungen anzeigen',
			'settings.numberFormat' => 'Zahlenformat',
			'settings.numberFormatOpts.locale' => 'Systemeinstellungen folgen',
			'settings.numberFormatOpts.period' => 'Immer Punkt als Dezimaltrennzeichen',
			'settings.numberFormatOpts.comma' => 'Immer Komma als Dezimaltrennzeichen',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => 'Systemeinstellungen (${separator} als Dezimaltrennzeichen)',
			'settings.numberFormatDescription.period' => 'Immer Punkt als Dezimaltrennzeichen',
			'settings.numberFormatDescription.comma' => 'Immer Komma als Dezimaltrennzeichen',
			'settings.numberFormatSeparators.comma' => 'Komma',
			'settings.numberFormatSeparators.period' => 'Punkt',
			'settings.gridPrecision' => 'Grid-Genauigkeit',
			'settings.gridPrecisionOpts.six' => '6 Stellen (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 Stellen (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 Stellen',
			'settings.gridPrecisionDescription.eight' => '8 Stellen',
			'commands.enableSyncFirst' => 'Aktiviere zuerst Sync in den Einstellungen.',
			'commands.fullResyncStarted' => 'Vollständige Neusynchronisierung gestartet — lokale Daten wurden zuvor gesichert.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Keine Datendateien passen zu „${target}“.',
			'commands.reloadFailed' => ({required Object error}) => 'Neu laden fehlgeschlagen: ${error}',
			'commands.reloadingAll' => 'Alle Datendateien werden neu geladen…',
			'commands.reloadingTarget' => ({required Object target}) => 'Datendateien für ${target} werden neu geladen…',
			'commands.unknownExperiment' => ({required Object token}) => 'Unbekanntes Experiment „${token}“',
			'commands.experimentEnabled' => ({required Object name}) => '${name} aktiviert',
			'commands.experimentDisabled' => ({required Object name}) => '${name} deaktiviert',
			'commands.sentryTestSent' => 'Test-Fehlerbericht an Sentry gesendet',
			'commands.sentryTestLocalOnly' => 'Sentry ist in diesem Build deaktiviert — Testfehler nur lokal protokolliert',
			'commands.noOperationOpen' => 'Dieser Befehl braucht einen geöffneten Betrieb',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Weiß nicht, wie man ein \'${kind}\' markiert',
			'commands.operationAlreadyStarted' => 'Dieser Betrieb hat bereits eine Startmarkierung',
			'commands.couldNotOpenLocation' => 'Pause hinzugefügt, aber der Standortbildschirm konnte nicht geöffnet werden',
			'commands.noTestOperations' => 'Keine Testbetriebe zum endgültigen Löschen',
			'commands.purgeTestsUnavailable' => 'PURGETESTS muss einen Bestätigungsdialog anzeigen, der hier nicht verfügbar ist',
			'commands.syncAllUnavailable' => 'SYNCALL muss einen Bestätigungsdialog anzeigen, der hier nicht verfügbar ist',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Testbetrieb endgültig gelöscht', other: '${count} Testbetriebe endgültig gelöscht', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '${purged} von ${total} Testbetrieben endgültig gelöscht — der Rest ist fehlgeschlagen; versuche PURGETESTS erneut',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Testkontakt ohne Betrieb endgültig gelöscht', other: '${count} Testkontakte ohne Betrieb endgültig gelöscht', ), 
			'commands.purgeTestsContactsFailed' => 'Die Testbetriebe wurden gelöscht, aber die Testkontakte ohne Betrieb nicht; versuche PURGETESTS erneut',
			'commands.purgeTestsNothingToDo' => 'Nichts wurde gelöscht',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '${removed} von ${total} Testbetrieben entfernt — der Rest ist fehlgeschlagen; versuche Prüfen erneut',
			'commands.receivedPurgesFailed' => 'Diese Testbetriebe konnten nicht entfernt werden — versuche Prüfen erneut',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Testbetrieb wurde auf einem anderen Gerät entfernt', other: '${count} Testbetriebe wurden auf einem anderen Gerät entfernt', ), 
			'commands.receivedPurgesReview' => 'Prüfen',
			'commands.settingOn' => 'Ein',
			'commands.settingOff' => 'Aus',
			'commands.settingEmpty' => '(leer)',
			'commands.settingSecretSet' => '(gesetzt)',
			'commands.settingSecretUnset' => '(nicht gesetzt)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} ausgewählt',
			'commands.settingExpectsOnOff' => 'on oder off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'eines von: ${choices}',
			'commands.settingExpectsNumber' => 'eine Zahl',
			'commands.settingVanished' => ({required Object label}) => '„${label}“ ist nicht mehr verfügbar',
			'commands.noCwKeyer' => 'Kein verbundenes Funkgerät kann CW tasten',
			'commands.noKeyer' => 'Kein verbundenes Funkgerät kann CW tasten oder Sprachspeicher abspielen',
			'commands.keyerNeedsOperation' => 'Öffne einen Betrieb, um den CW-Keyer zu verwenden',
			'commands.keyerExperimentOff' => 'CW-Tastung ist aus — schalte sie mit EXP KEYER ein',
			'commands.esmExperimentOff' => 'Enter sendet Nachrichten ist aus — schalte es mit EXP ESM ein',
			'commands.cwSending' => ({required Object text}) => 'Sende CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW-Nachricht F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW-Nachricht F${n} wurde nicht gesendet: die Erweiterungen sind nicht bereit',
			'commands.settingNotStored' => ({required Object label}) => '„${label}“ hat diesen Wert nicht angenommen',
			'commandDialog.hint' => 'Rufzeichen suchen oder Befehl eingeben',
			'commandDialog.noResults' => ({required Object text}) => 'Nichts passt zu „${text}“',
			'commandDialog.sectionCommands' => 'Befehle',
			'commandDialog.sectionGoTo' => 'Gehe zu',
			'commandDialog.sectionOperations' => 'Betrieb',
			'commandDialog.goHome' => 'Start',
			'commandDialog.goSettings' => 'Einstellungen',
			'commandDialog.goNewOperation' => 'Neuer Betrieb',
			'commandDialog.runTyped' => ({required Object text}) => '„${text}“ ausführen',
			'commandDialog.sectionSuggestions' => 'Probiere',
			'commandDialog.lookingUp' => 'Rufzeichen wird abgefragt…',
			'commandDialog.blockedByPane' => 'Befehle sind nicht möglich, solange ein Panel oder Dialog geöffnet ist',
			'expiredBuild.title' => 'Dieser Build ist abgelaufen',
			'expiredBuild.body' => 'Bitte besuche ham2k.com und hole dir eine neuere Version.',
			'expiredBuild.visit' => 'ham2k.com besuchen',
			'expiredBuild.dismiss' => 'Trotzdem fortfahren',
			'staleness.codePushFloorTitle' => 'Ein wichtiges Update wartet',
			'staleness.codePushFloorBody' => 'Diese Version enthält eine Korrektur, die du noch nicht hast.',
			'staleness.restartToApply' => 'Starte die App neu, um es anzuwenden.',
			'staleness.quitAndReopen' => 'Beende die App und öffne sie erneut, um es anzuwenden.',
			'staleness.reopenToApply' => 'Schließe die App und öffne sie erneut, um es anzuwenden.',
			'staleness.ignoreForNow' => 'Vorerst ignorieren',
			'spotting.noQsoYet' => 'Noch kein QSO zum Spotten geloggt.',
			'spotting.setFrequencyFirst' => 'Stelle zuerst eine Frequenz ein.',
			'spotting.nothingToSpot' => 'Kein Spot möglich — keine Erweiterung bietet hier Spotting an.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} fehlgeschlagen: ${message}',
			'spotting.unknownError' => 'unbekannter Fehler',
			'spotting.notSent' => 'Spot nicht gesendet.',
			'spotting.notRefreshedOffline' => 'Keine Verbindung — Spots wurden nicht aktualisiert',
			'dataFiles.downloading' => 'Lade herunter…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name} konnte nicht heruntergeladen werden',
			'dataFiles.downloadFailedWebHint' => 'Das kann ein Netzwerkproblem sein, oder der Host dieses Links unterstützt keine direkten Downloads aus einem Webbrowser. Versuche es mit der Desktop- oder Mobil-App oder einem anderen Speicherort.',
			'dataFiles.downloadTimedOut' => 'Der Server hat zu lange gebraucht. Versuche es später erneut.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} hat mit einem Fehler geantwortet (HTTP ${status}). Versuche es später erneut.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} konnte diese Datei nicht liefern (HTTP ${status}). Prüfe, ob ihre Adresse noch stimmt.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name} konnte nicht verarbeitet werden',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Der Download hatte nur ${imported} der ${existing} Einträge auf diesem Gerät, daher wurden die fehlenden behalten. Eine Aktualisierung unter Einstellungen › Offline-Daten übernimmt ihn trotzdem.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Eintrag für ${label} importiert.', other: '${count} Einträge für ${label} importiert.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Daten für ${label} importiert.',
			'dataFiles.cleanedUpTitle' => 'Erweiterungsdaten bereinigt',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Daten für ${count} Datendatei von deaktivierten Erweiterungen entfernt.', other: 'Daten für ${count} Datendateien von deaktivierten Erweiterungen entfernt.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} Einträge',
			'dataFiles.definitionUnavailable' => 'Die Quelle der Datei hat keine Definition geliefert — ihre Erweiterung startet evtl. gerade neu oder ist falsch konfiguriert. Versuche es gleich noch einmal.',
			'updates.updateAvailable' => 'Update verfügbar',
			'updates.newVersionAvailable' => ({required Object version}) => 'Eine neue Version (${version}) ist verfügbar.',
			'updates.getIt' => 'Holen',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Update bereit',
			'updates.restartToApply' => 'Ein Update wurde heruntergeladen. Starte neu, um es anzuwenden.',
			'updates.appliesNextLaunch' => 'Ein Update wurde heruntergeladen. Es wird beim nächsten Öffnen der App angewendet.',
			'updates.restartNow' => 'Jetzt neu starten',
			'updates.reloadToUpdate' => 'Eine neuere Version dieser Seite ist verfügbar. Lade neu, um sie zu erhalten.',
			'updates.reloadNow' => 'Jetzt neu laden',
			'updates.checkForUpdates' => 'Nach Updates suchen',
			'updates.checkingForUpdates' => 'Suche nach Updates…',
			'updates.upToDate' => 'Auf dem neuesten Stand',
			'updates.automaticChecks' => 'Automatisch prüfen',
			'updates.automaticChecksDescription' => 'Ab dem nächsten Start der App im Hintergrund nach neuen Versionen suchen',
			'extensionService.runtimeNotReady' => 'Erweiterungs-Laufzeit nicht bereit.',
			'extensionService.testFailed' => ({required Object error}) => 'Test fehlgeschlagen: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Verbunden als ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Ungültige Feldkonfiguration',
			'extensionService.invalidValue' => 'Ungültiger Wert',
			'extensionService.validationError' => ({required Object error}) => 'Validierungsfehler: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Aktion fehlgeschlagen: ${error}',
			'extensionService.commandFailed' => 'Der Befehl konnte nicht ausgeführt werden',
			'extensionService.reportUnavailable' => 'Meldungen können gerade nicht gesendet werden',
			'extensionService.stashUnavailable' => 'Ham2K File Stash ist gerade nicht erreichbar',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} hat zu viel Zeit in seinen Timern verbracht. Sie sind angehalten, bis die Erweiterungen neu starten.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Die Timer von ${name} sind wiederholt fehlgeschlagen. Sie sind angehalten, bis die Erweiterungen neu starten.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} ist in einem Timer hängen geblieben. Seine Timer sind angehalten, bis die Erweiterungen neu starten.',
			'operationLocationScreen.title' => 'Betriebsort',
			'operationLocationScreen.selectedLocation' => 'Ausgewählter Ort',
			'operationLocationScreen.gridSquare' => 'Maidenhead-Locator',
			'operationLocationScreen.gridInvalid' => 'Benötigt 4, 6, 8 oder 10 Zeichen, z. B. FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Vorgeschlagene Orte',
			'operationLocationScreen.deviceGps' => 'Geräte-GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS von ${device}',
			'operationLocationScreen.locating' => 'Ermittle Standort…',
			'operationLocationScreen.gpsUnavailable' => 'Standort nicht verfügbar',
			'operationLocationScreen.permissionDenied' => 'Standortberechtigung verweigert',
			'operationLocationScreen.permissionBlocked' => 'Standortberechtigung blockiert',
			'operationLocationScreen.moreDetails' => 'Weitere Details',
			'operationLocationScreen.stateOrProvince' => 'Bundesland oder Provinz (optional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Aktivitätssteuerung nicht verfügbar',
			'operationLocationScreen.controlsUnavailableReason' => 'Diese Referenzen sind weiterhin nutzbar; nur ihre Aktivitäten waren nicht erreichbar.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Erneut versuchen',
			'operationLocationScreen.county' => 'Landkreis (optional)',
			'versionLabel.version' => ({required Object version}) => 'Version ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'Build ${build}',
			'notices.emptyHistory' => 'Noch keine Hinweise',
			'notices.webStorageInMemory' => 'Dieser Browser konnte keinen dauerhaften Speicher bereitstellen — das Log liegt nur im Arbeitsspeicher und geht VERLOREN, wenn dieser Tab geschlossen wird. Verwende ein aktuelles Chrome, Firefox, Safari oder Edge.',
			'notices.webStorageUnreliable' => 'Dieser Browser verwendet einen Ersatzspeicher, der mit mehreren Tabs nicht sicher ist — lass nur einen Tab offen und Sync eingeschaltet.',
			'notices.logFromNewerBuildTitle' => 'Dieses Log braucht eine neuere Version',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Dein Log wurde von einer neueren Version von HaLo geschrieben (Speicherversion ${storage}; diese versteht ${understood}), daher kann es nicht geöffnet werden, und neue Kontakte werden nicht gespeichert. Installiere die neuere Version erneut — oder, wenn du diesen Build starten wolltest, verweise ihn auf einen anderen Datenordner. Das Log liegt in ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Dein Log wurde von einer neueren Version von HaLo geschrieben (Speicherversion ${storage}; diese versteht ${understood}), daher kann es nicht geöffnet werden, und neue Kontakte werden nicht gespeichert. Öffne dieses Log stattdessen mit der neueren Version.',
			'notices.preferencesRestoredTitle' => 'Einstellungen aus einer Sicherung wiederhergestellt',
			'notices.preferencesRestored' => 'Die Einstellungsdatei konnte nicht gelesen werden, daher hat HaLo die letzte gute Kopie wiederhergestellt. Was du in deiner letzten Sitzung geändert hast, musst du evtl. erneut einstellen. Die unlesbare Datei wird daneben aufbewahrt, mit dem Namen shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Einstellungen zurückgesetzt',
			'notices.preferencesReset' => 'Die Einstellungsdatei konnte nicht gelesen werden und es gab keine Sicherung, daher ist HaLo mit den Standardwerten gestartet. Die unlesbare Datei wird im Datenordner der App aufbewahrt, mit dem Namen shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} wurde nicht automatisch verbunden',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo reagierte beim letzten Verbindungsaufbau mit ${name} nicht mehr, daher wurde es diesmal in Ruhe gelassen, statt es erneut zu riskieren. Prüfe, ob das Funkgerät eingeschaltet und das Kabel eingesteckt ist, und drücke dann in den Einstellungen bei ihm auf Verbinden.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonymes Konto (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (Bestätigung ausstehend)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (Bestätigung ausstehend - #${id})',
			'deepLink.needsAnOperation' => 'Starte zuerst einen Betrieb und sende den Kontakt dann erneut',
			'deepLink.waitingInOperation' => 'Dieser Kontakt wartet im Betrieb hinter diesem Bildschirm',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Dieses Gerät hat keine Aktivität für ${refs}, daher wurden diese Referenzen weggelassen',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Deine Aktivitäten waren nicht erreichbar, daher wurde ${refs} weggelassen — versuche den Link erneut',
			'confirmDevice.title' => 'Gerät bestätigen',
			'confirmDevice.codePrompt' => 'Gib den Code ein, der auf dem Gerät angezeigt wird, das diesem Konto beitreten möchte.',
			'confirmDevice.code' => 'Code',
			'confirmDevice.lookUp' => 'Nachschlagen',
			'confirmDevice.codeNotFound' => 'Keine Anfrage passt zu diesem Code. Codes laufen nach 10 Minuten ab — lass dir vom anderen Gerät einen neuen geben.',
			'confirmDevice.linkExpired' => 'Dieser Link ist abgelaufen. Lass das andere Gerät einen neuen QR-Code anzeigen.',
			'confirmDevice.areYouSure' => ({required Object device}) => '${device} mit diesem Konto verknüpfen?',
			'confirmDevice.unnamedDevice' => 'ein unbenanntes Gerät',
			'confirmDevice.grantWarning' => 'Es kann jeden Betrieb und jedes QSO in diesem Konto lesen und ändern.',
			'confirmDevice.needsSyncTitle' => 'Dieses Gerät synchronisiert noch nicht',
			'confirmDevice.needsSyncText' => 'Schalte die Ham2K-Log-Filer-Synchronisierung ein und verknüpfe dieses Gerät mit einem Konto, bevor es ein anderes zulassen kann.',
			'confirmDevice.malformedRequest' => 'Der Sync-Server hat eine Anfrage gesendet, die diese App nicht lesen konnte. Bitte das andere Gerät, es erneut zu versuchen.',
			'confirmDevice.linkIt' => 'Gerät verknüpfen',
			'switchAccounts.noAccountDetails' => 'Noch keine Kontodetails',
			'switchAccounts.currentAccount' => 'Aktuelles Konto',
			'switchAccounts.otherAccounts' => 'Andere Konten',
			'switchAccounts.linkToAnother' => 'Mit einem anderen Konto verknüpfen',
			'switchAccounts.linkWithSibling' => 'Mit anderer Ham2K-App verknüpfen',
			'switchAccounts.linkWithPolo' => 'Mit Konto der älteren Version verknüpfen',
			'switchAccounts.linkWithSiblingDescription' => 'Du hast eine andere Ham2K-App installiert. Verknüpfe mit dem dort verwendeten Konto.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Bestätige die Anfrage in ${app} und komm dann hierher zurück.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '${app} erneut öffnen',
			'switchAccounts.siblingNoGrant' => 'Hat nicht geklappt? Öffne sie erneut oder geh zurück und verknüpfe auf andere Weise.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app} konnte nicht geöffnet werden.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Der Link ist abgelaufen und ein neuer ist bereit — öffne ${app} erneut.',
			'switchAccounts.tryAgain' => 'Erneut versuchen',
			'switchAccounts.linkWithQr' => 'Mit QR-Code verknüpfen',
			'switchAccounts.linkWithQrDescription' => 'Scanne ihn von einem Gerät, das das Konto bereits nutzt',
			'switchAccounts.linkWithEmail' => 'Mit E-Mail-Adresse verknüpfen',
			'switchAccounts.linkWithEmailDescription' => 'Mit einem Code oder einem E-Mail-Link bestätigen',
			'switchAccounts.enterEmailPrompt' => 'Gib die E-Mail-Adresse des Kontos ein, das dieses Gerät verwenden soll.',
			'switchAccounts.emailAddress' => 'E-Mail-Adresse',
			'switchAccounts.linkAccount' => 'Konto verknüpfen',
			'switchAccounts.copiedCode' => 'Code in die Zwischenablage kopiert',
			'switchAccounts.copyCode' => 'Code kopieren',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Öffne die Ham2K-App auf einem Gerät, das bereits mit ${email} verknüpft ist, und gib diesen Code ein, um die Anfrage zu bestätigen:',
			'switchAccounts.waitingForConfirmation' => 'Warte auf Bestätigung…',
			'switchAccounts.sendEmailInstead' => 'Stattdessen eine Bestätigungs-E-Mail senden',
			'switchAccounts.emailSent' => ({required Object email}) => 'Eine E-Mail wurde an ${email} gesendet. Öffne sie und bestätige die Anfrage, um dieses Gerät zu verknüpfen.',
			'switchAccounts.resendEmail' => 'E-Mail erneut senden',
			'switchAccounts.qrPrompt' => 'Scanne diesen QR-Code von einem Gerät, das bereits mit dem gewünschten Konto verknüpft ist — zum Beispiel mit Ham2K Portable Logger auf deinem Handy.',
			'switchAccounts.serverUnreachable' => 'Der Sync-Server war nicht erreichbar. Versuche es später erneut.',
			'switchAccounts.emailRequired' => 'Gib zum Verknüpfen eine E-Mail-Adresse ein.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Kein Konto für ${email} gefunden.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Der Sync-Server hat die Anfrage abgelehnt: ${error}',
			'switchAccounts.noLinkCode' => 'Der Sync-Server hat keinen Verknüpfungscode geliefert. Versuche es später erneut.',
			'switchAccounts.noConfirmationCode' => 'Der Sync-Server hat keinen Bestätigungscode gesendet. Versuche es später erneut.',
			'switchAccounts.switchNotAccepted' => 'Dieses Konto hat den Wechsel nicht angenommen. Versuche stattdessen, es mit einer E-Mail-Adresse zu verknüpfen.',
			'switchAccounts.requestFailed' => 'Bei der Kommunikation mit dem Sync-Server ist etwas schiefgelaufen. Versuche es später erneut.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Betrieb', other: '${count} Betriebe', ), 
			'adifImport.title' => 'QSOs aus ADIF importieren',
			'adifImport.reading' => ({required Object filename}) => 'Lese ${filename}…',
			'adifImport.dropHint' => 'ADIF-Datei zum Importieren hier ablegen',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} QSO in dieser Datei', other: '${formatted} QSOs in dieser Datei', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} bereits in deinem Log', other: '${formatted} bereits in deinem Log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} wird importiert', other: '${formatted} werden importiert', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} neuer Kontakt', other: '${formatted} neue Kontakte', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} wird mit einem vorhandenen Kontakt zusammengeführt', other: '${formatted} werden mit vorhandenen Kontakten zusammengeführt', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} kann nicht importiert werden (kein Rufzeichen)', other: '${formatted} können nicht importiert werden (kein Rufzeichen)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} sollte genauer geprüft werden', other: '${formatted} sollten genauer geprüft werden', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: 'Referenzen konnten für ${count} Kontakt nicht wiederhergestellt werden', other: 'Referenzen konnten für ${formatted} Kontakte nicht wiederhergestellt werden', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${programs}-Referenzen sind für ${count} Kontakt evtl. unvollständig', other: '${programs}-Referenzen sind für ${formatted} Kontakte evtl. unvollständig', ), 
			'adifImport.stackingTypesUnknown' => 'Zusammengeführte Kontakte können eine Referenz verlieren — die Aktivitäten konnten nicht sagen, welche Typen sich kombinieren lassen. Brich ab und versuche es erneut, um das zu vermeiden.',
			'adifImport.nothingToImport' => 'Nichts in dieser Datei kann importiert werden',
			'adifImport.confirm' => 'Importieren',
			'adifImport.importing' => ({required Object filename}) => 'Importiere ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} Kontakt aus ${filename} importiert', other: '${formatted} Kontakte aus ${filename} importiert', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename} konnte nicht importiert werden: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} sieht nicht wie eine ADIF-Datei aus',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Warnung: Diese ADIF enthält QSOs von ${calls}, sie werden aber als ${station} importiert, wenn du fortfährst.',
			'adifImport.stationCallJoin' => ' und ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('de'))(count, one: '${count} hat kein Datum und kann nicht importiert werden', other: '${formatted} haben kein Datum und können nicht importiert werden', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Diese Datei enthält eine Aktivierung von ${refs}.',
			'adifImport.addActivation' => 'Zu diesem Betrieb hinzufügen',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Nur ${written} von ${planned} konnten übernommen werden — das Log hat sich geändert, während du entschieden hast.',
			'adifImport.busy' => 'Ein Import läuft bereits. Warte, bis er fertig ist, bevor du einen weiteren startest.',
			'adifImport.oneFileOnly' => 'Lege immer nur eine ADIF-Datei ab — die Reihenfolge des Imports entscheidet, welche Daten gewinnen.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} hat mehr als ${limit} QSOs, das Maximum, das ein Betrieb auf einmal importieren kann.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: verbunden',
			'offline.noRoute' => 'Überhaupt keine Netzwerkverbindung.',
			'offline.unreachable' => 'Das Netzwerk ist da, aber kein Server reagiert — oft wartet eine Anmeldeseite in einem Browser.',
			'offline.reachable' => 'Alle Dienste reagieren wie erwartet.',
			'offline.whatStops' => 'Abfragen, Spots und Datendateien sind pausiert. Logging und Synchronisierung in der Nähe nicht.',
			'offline.servicesTitle' => 'Dienste',
			'offline.noServices' => 'Noch kein Dienst hat sich gemeldet.',
			'offline.lastSuccess' => ({required Object when}) => 'Zuletzt vor ${when} reagiert',
			'offline.neverSucceeded' => 'Hat noch nicht reagiert',
			'offline.nextAttempt' => ({required Object when}) => 'Nächster Versuch in ${when}',
			'offline.nextAttemptNow' => 'Nächster Versuch fällig',
			'offline.retry' => 'Jetzt erneut versuchen',
			'offline.retrying' => 'Versuche…',
			'offline.retryReached' => 'Wieder online.',
			'offline.retryUnreachable' => 'Immer noch keine Reaktion.',
			'offline.retryNotAttempted' => 'Gerade nichts zu senden.',
			'offline.retryThrottled' => 'Gerade erst versucht — einen Moment Geduld.',
			'offline.retryDisabled' => 'Sync ist ausgeschaltet, daher gibt es nichts zum Prüfen.',
			'offline.syncService' => 'Ham2K LoFi Sync',
			'offline.retryInFlight' => 'Versuche bereits — einen Moment.',
			'exportSettings.defaultsDescription' => 'Grundeinstellungen für alle Exporte, mit getrennten Vorlagen für Dateiname und Titel für Referenzaktivitäten und andere Aktivitäten. Jede Exportart kann eigene Standardwerte oder benutzerdefinierte Einstellungen haben.',
			'exportSettings.referenceActivities' => 'Referenzaktivitäten',
			'exportSettings.otherActivities' => 'Andere Aktivitäten',
			'exportSettings.adifFields' => 'ADIF-Felder',
			'exportSettings.loadFailed' => 'Export-Einstellungen konnten nicht geladen werden.',
			'exportSettings.retry' => 'Erneut versuchen',
			'exportSettings.compactFileNamesDescriptionOn' => 'Kompakte Dateinamen, z. B. N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Beschreibende Dateinamen, z. B. 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Namen, Adressen, E-Mails, Notizen und genaue Standorte werden in ADIF-Dateien aufgenommen.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Namen, Adressen, E-Mails und Notizen werden weggelassen; Standorte auf sechsstellige Grids begrenzt.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Informationen aus Rufzeichen-Abfragediensten werden aufgenommen.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Informationen aus Rufzeichen-Abfragediensten werden weggelassen; manuell eingegebene Werte bleiben erhalten.',
			'exportSettings.customTemplatesDescriptionOn' => 'Deine eigenen Vorlagen sind aktiv und können unten bearbeitet werden.',
			'exportSettings.customTemplatesDescriptionOff' => 'Standardvorlagen sind aktiv. Deine eigenen Vorlagen werden für später aufbewahrt.',
			'exportSettings.type' => 'Exportart',
			'exportSettings.defaults' => 'Standardwerte',
			'exportSettings.includeLookupData' => 'Abfragedaten einbeziehen',
			'exportSettings.customTemplates' => 'Eigene Vorlagen',
			'exportSettings.filenameTemplate' => 'Dateiname-Vorlage',
			'exportSettings.compactFilenameTemplate' => 'Vorlage für kompakten Dateinamen',
			'exportSettings.titleTemplate' => 'Titel-Vorlage',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO Notizen',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO Kommentare',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL Nachricht',
			'exportSettings.shared' => 'Die Einstellungen gelten für jede Erweiterung, die diese Exportart verwendet.',
			'exportSettings.defaultTemplates' => 'Schalte „Eigene Vorlagen“ ein, um die Vorlagen dieser Art zu bearbeiten.',
			_ => null,
		} ?? switch (path) {
			'templateEditor.previewLabel' => 'Vorschau:',
			'templateEditor.reset' => 'Zurücksetzen',
			'templateEditor.docs' => 'Vorlagen-Doku',
			'templateEditor.preview' => 'Beispielvorschau',
			'templateEditor.reference' => 'Vorlagen-Referenz',
			'templateEditor.attributes' => 'Verfügbare Attribute',
			'templateEditor.filters' => 'Filter',
			'templateEditor.flowControl' => 'Ablaufsteuerung',
			'templateEditor.unavailable' => 'Die Vorschau ist erst verfügbar, wenn die Erweiterungen bereit sind.',
			'templateEditor.empty' => '(leere Ausgabe)',
			_ => null,
		};
	}
}
