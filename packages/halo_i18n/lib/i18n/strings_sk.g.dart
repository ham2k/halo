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
class TranslationsSk extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsSk({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.sk,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <sk>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsSk _root = this; // ignore: unused_field

	@override 
	TranslationsSk $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsSk(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$sk common = _Translations$common$sk._(_root);
	@override late final _Translations$onboarding$sk onboarding = _Translations$onboarding$sk._(_root);
	@override late final _Translations$startScreen$sk startScreen = _Translations$startScreen$sk._(_root);
	@override late final _Translations$testerOverlay$sk testerOverlay = _Translations$testerOverlay$sk._(_root);
	@override late final _Translations$extensionsPanel$sk extensionsPanel = _Translations$extensionsPanel$sk._(_root);
	@override late final _Translations$home$sk home = _Translations$home$sk._(_root);
	@override late final _Translations$chase$sk chase = _Translations$chase$sk._(_root);
	@override late final _Translations$dialogs$sk dialogs = _Translations$dialogs$sk._(_root);
	@override late final _Translations$operation$sk operation = _Translations$operation$sk._(_root);
	@override late final _Translations$map$sk map = _Translations$map$sk._(_root);
	@override late final _Translations$mapsView$sk mapsView = _Translations$mapsView$sk._(_root);
	@override late final _Translations$activitiesView$sk activitiesView = _Translations$activitiesView$sk._(_root);
	@override late final _Translations$loggingControls$sk loggingControls = _Translations$loggingControls$sk._(_root);
	@override late final _Translations$formChrome$sk formChrome = _Translations$formChrome$sk._(_root);
	@override late final _Translations$qsoEditForm$sk qsoEditForm = _Translations$qsoEditForm$sk._(_root);
	@override late final _Translations$qsoList$sk qsoList = _Translations$qsoList$sk._(_root);
	@override late final _Translations$loggingPanel$sk loggingPanel = _Translations$loggingPanel$sk._(_root);
	@override late final _Translations$callInfo$sk callInfo = _Translations$callInfo$sk._(_root);
	@override late final _Translations$settings$sk settings = _Translations$settings$sk._(_root);
	@override late final _Translations$commands$sk commands = _Translations$commands$sk._(_root);
	@override late final _Translations$commandDialog$sk commandDialog = _Translations$commandDialog$sk._(_root);
	@override late final _Translations$expiredBuild$sk expiredBuild = _Translations$expiredBuild$sk._(_root);
	@override late final _Translations$staleness$sk staleness = _Translations$staleness$sk._(_root);
	@override late final _Translations$spotting$sk spotting = _Translations$spotting$sk._(_root);
	@override late final _Translations$dataFiles$sk dataFiles = _Translations$dataFiles$sk._(_root);
	@override late final _Translations$updates$sk updates = _Translations$updates$sk._(_root);
	@override late final _Translations$extensionService$sk extensionService = _Translations$extensionService$sk._(_root);
	@override late final _Translations$operationLocationScreen$sk operationLocationScreen = _Translations$operationLocationScreen$sk._(_root);
	@override late final _Translations$versionLabel$sk versionLabel = _Translations$versionLabel$sk._(_root);
	@override late final _Translations$notices$sk notices = _Translations$notices$sk._(_root);
	@override late final _Translations$syncAccount$sk syncAccount = _Translations$syncAccount$sk._(_root);
	@override late final _Translations$deepLink$sk deepLink = _Translations$deepLink$sk._(_root);
	@override late final _Translations$confirmDevice$sk confirmDevice = _Translations$confirmDevice$sk._(_root);
	@override late final _Translations$switchAccounts$sk switchAccounts = _Translations$switchAccounts$sk._(_root);
	@override late final _Translations$adifImport$sk adifImport = _Translations$adifImport$sk._(_root);
	@override late final _Translations$offline$sk offline = _Translations$offline$sk._(_root);
	@override late final _Translations$exportSettings$sk exportSettings = _Translations$exportSettings$sk._(_root);
	@override late final _Translations$templateEditor$sk templateEditor = _Translations$templateEditor$sk._(_root);
}

// Path: common
class _Translations$common$sk extends Translations$common$en {
	_Translations$common$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get save => 'Uložiť';
	@override String get ok => 'OK';
	@override String get cancel => 'Zrušiť';
	@override String get delete => 'Odstrániť';
	@override String get create => 'Vytvoriť';
	@override String get error => 'Chyba';
	@override String get close => 'Zatvoriť';
	@override String get done => 'Hotovo';
	@override String get callsign => 'Volací znak';
	@override String get clear => 'Vymazať';
	@override String get dismiss => 'Zavrieť';
	@override String get expand => 'Rozbaliť';
	@override String get collapse => 'Zbaliť';
}

// Path: onboarding
class _Translations$onboarding$sk extends Translations$onboarding$en {
	_Translations$onboarding$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Vitajte v Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Vitajte v Ham2K Power Logger!';
	@override String get welcomeBody => 'Máme pre vás niekoľko otázok, aby sme aplikáciu lepšie prispôsobili vašim potrebám.';
	@override String get skip => 'Preskočiť';
	@override String get kContinue => 'Pokračovať';
	@override String get back => 'Späť';
	@override String get next => 'Ďalej';
	@override String get done => 'Hotovo';
	@override String get callsignTitle => 'Aký je váš volací znak?';
	@override String get callsignBody => 'Aby vám bola táto aplikácia užitočná, potrebujete licenciu rádioamatéra';
	@override String get callsignLabel => 'Volací znak operátora';
	@override String get alreadyHaveAccount => 'Už máte účet?';
	@override String get foundSiblingTitle => 'Prepojiť existujúci účet?';
	@override String foundSiblingBody({required Object app}) => 'Na tomto zariadení sme našli ${app}. Prepojte túto aplikáciu s rovnakým účtom a prenesú sa váš volací znak aj denníky.';
	@override String get foundPoloBody => 'Na tomto zariadení sme našli staršiu verziu Ham2K Portable Logger. Prepojte túto aplikáciu s rovnakým účtom a prenesú sa váš volací znak aj denníky.';
	@override String get foundSiblingsBody => 'Na tomto zariadení sme našli iné aplikácie Ham2K. Prepojte túto aplikáciu s účtom jednej z nich a prenesú sa váš volací znak aj denníky.';
	@override String linkWithApp({required Object app}) => 'Prepojiť s ${app}';
	@override String get linkWithPolo => 'Prepojiť s účtom zo staršej verzie';
	@override String get setUpFresh => 'Nastaviť od začiatku';
	@override String get activitiesTitle => 'Obľúbené aktivity';
	@override String get activitiesBody => 'Zaujímajú vás niektoré z týchto populárnych aktivačných programov?';
	@override String get activitiesFooter => '(Ďalšie možnosti nájdete v Nastaveniach)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Údaje a súkromie';
	@override String get consentUsageBody => 'Aby sme mohli aplikáciu zlepšovať, radi by sme zbierali údaje o výkone, zlyhaniach a používaní aplikácie.';
	@override String get consentUsageLabel => 'Zdieľať údaje o používaní aplikácie';
	@override String get consentOperationBody => 'Niektoré funkcie môžu zahŕňať zdieľanie údajov o vašej prevádzke s inými používateľmi. Kedykoľvek to môžete vypnúť.';
	@override String get consentOperationLabel => 'Zdieľať údaje o prevádzke';
	@override String get finishingSetup => 'Dokončuje sa nastavenie — sťahujú sa referenčné údaje…';
}

// Path: startScreen
class _Translations$startScreen$sk extends Translations$startScreen$en {
	_Translations$startScreen$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get credits => 'od KI2D a priateľov';
}

// Path: testerOverlay
class _Translations$testerOverlay$sk extends Translations$testerOverlay$en {
	_Translations$testerOverlay$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get tape => 'POZOR: STAVENISKO';
	@override String get warningTitle => 'Táto aplikácia je rozpracovaná';
	@override String get warningBody => 'Väčšina funkcií má nerovný povrch a všade hrozí zakopnutie. Pravidelne kontrolujte aktualizácie.';
	@override String whatsNew({required Object build}) => 'Novinky v zostave ${build}';
	@override String get thanks => 'Ďakujeme, že riskujete svoj denník, aby ste nám pomohli túto aplikáciu zlepšiť!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$sk extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Aktivity';
	@override String get categoryContest => 'Súťaže';
	@override String get categoryLookup => 'Vyhľadávanie volacích znakov';
	@override String get categorySpots => 'Zdroje spotov';
	@override String get categoryDashboard => 'Panely prehľadu';
	@override String get categoryOther => 'Ostatné rozšírenia';
	@override String get searchHint => 'Hľadať rozšírenia';
	@override String get applying => 'Aktivujú sa zmeny rozšírení, môže to chvíľu trvať…';
	@override String get noMatches => 'Hľadaniu nezodpovedajú žiadne rozšírenia';
	@override String get installFromFile => 'Inštalovať zo súboru…';
	@override String installVersion({required Object version}) => 'Verzia ${version}';
	@override String get canReach => 'Toto rozšírenie môže kontaktovať';
	@override String canHoldConnection({required Object host}) => '${host}, cez trvalé spojenie';
	@override String get canHoldLocalConnection => 'Zariadenia vo vašej lokálnej sieti, cez trvalé spojenie';
	@override String get canUseLocation => 'Vašu polohu';
	@override String get canReadRadio => 'Vašu rádiostanicu, na čítanie frekvencie a módu';
	@override String get canControlRadio => 'Vašu rádiostanicu, na jej ovládanie a vysielanie — ladenie, výkon, CW, hlasové pamäte a PTT';
	@override String get canSetUserAgent => 'Predstaviť sa serverom pod vlastným menom';
	@override String get noCapabilities => 'Nepožaduje nič mimo aplikácie.';
	@override String get sandboxNote => 'Rozšírenia bežia v izolovanom prostredí: bez prístupu k vašim súborom a bez siete okrem toho, čo je tu uvedené.';
	@override String get installAction => 'Inštalovať';
	@override String get updateAction => 'Aktualizovať';
	@override String get installFailed => 'Toto rozšírenie sa nepodarilo nainštalovať';
	@override String get installedBadge => 'Nainštalované';
	@override String get uninstallAction => 'Odstrániť';
	@override String uninstallTitle({required Object name}) => 'Odstrániť ${name}?';
	@override String get uninstallBody => 'Toto rozšírenie a jeho nastavenia budú odstránené. Vaše denníky zostanú nedotknuté.';
	@override String installedMessage({required Object name}) => 'Nainštalované ${name}';
	@override String get installDownloading => 'Sťahovanie…';
	@override String get installWaiting => 'Čaká sa na inštaláciu…';
	@override String get installInstalling => 'Inštalácia…';
	@override String get installAwaitingApproval => 'Čaká sa na vaše schválenie…';
	@override String installAlreadyRunning({required Object name}) => '${name} sa už inštaluje.';
	@override String updatedTo({required Object version}) => 'Aktualizované na ${version}';
	@override String installIncomplete({required Object name}) => 'Inštalácia ${name} sa nedokončila. Možno bude potrebné nainštalovať ho znova.';
	@override String uninstallFailed({required Object name}) => '${name} sa nepodarilo odstrániť';
	@override String installedFrom({required Object source}) => 'Stiahnuté z ${source}';
	@override String get dropHint => 'Pustite sem rozšírenie .h2kext a nainštaluje sa';
	@override String get dropOneOnly => 'Pustite naraz iba jedno rozšírenie.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} pre toto rozšírenie vrátil ${status}.';
	@override String get downloadTooLarge => 'Toto sťahovanie je príliš veľké na to, aby to bolo rozšírenie.';
	@override String get downloadNotSecure => 'Toto sťahovanie bolo presmerované na nezabezpečené miesto.';
	@override String get catalogSection => 'Katalóg';
	@override String get catalogLoading => 'Načítava sa katalóg…';
	@override String get catalogUnreachable => 'Katalóg je nedostupný';
	@override String get builtIn => 'Vstavané';
	@override String get updateAvailableBadge => 'Aktualizácia dostupná';
	@override String get updatesAvailableTitle => 'Aktualizácie rozšírení';
	@override String updateAvailableFor({required Object name}) => 'Pre ${name} je dostupná aktualizácia.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} a ďalšie (${count}) potrebujú aktualizáciu.';
	@override String updatesAvailableFor({required Object names}) => '${names} potrebujú aktualizáciu.';
	@override String get pendingUpdatesSection => 'Čakajúce aktualizácie';
	@override String get updateAllAction => 'Aktualizovať všetko';
	@override String get updatesUnderWay => 'Tieto aktualizácie už prebiehajú.';
	@override String get updatesNothingLeft => 'Vaše rozšírenia sú aktuálne.';
	@override String get updatesNoticeAction => 'Viac informácií';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Aktualizovať ${count} rozšírenie?',
		other: 'Aktualizovať ${count} rozšírení?',
	);
	@override String get upgradeDoneTitle => 'Vaše rozšírenia sú pripravené';
	@override String get upgradeDoneBody => 'Teraz pochádzajú z katalógu rozšírení Ham2K, takže sa môžu aktualizovať bez čakania na novú verziu aplikácie.';
	@override String upgradeDoneUnserved({required Object names}) => 'Neaktualizované: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Nespustili sa: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Stále sú nainštalované a označené v Nastavenia › Rozšírenia — ich aktualizáciou tam ich obnovíte.';
	@override String get upgradeDoneUnservedHint => 'Katalóg za ne nemá priamu náhradu, preto v ňom hľadajte rozšírenia, ktoré pokrývajú to, čo ste používali.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Podujatia State Parks';
	@override String upgradeDoneMissing({required Object count}) => 'Niektoré vaše rozšírenia (${count}) ešte nedorazili. Stiahnu sa, keď bude katalóg rozšírení nabudúce dostupný.';
	@override String get runtimeDeadBody => 'Vaše rozšírenia sa nespustili. Reštart aplikácie by ich mal obnoviť.';
	@override String get refusedTitle => 'Niektoré rozšírenia sa nespustili';
	@override String get upgradeBusyTitle => 'Nastavenie stále prebieha';
	@override String get upgradeRuntimeDeadTitle => 'Vaše rozšírenia nebežia';
	@override String get restoreTitle => 'Niektoré vaše rozšírenia chýbajú';
	@override String get restoreBody => 'Tieto rozšírenia, ktoré ste nainštalovali, nie sú na tomto zariadení. Môžeme ich znova stiahnuť z katalógu rozšírení Ham2K:';
	@override String get restoreFromFile => 'Nainštalované zo súboru. Nainštalujte ich znova z ich súborov alebo ich zabudnite:';
	@override String get restoreOtherCatalog => 'Nainštalované z iného katalógu rozšírení, preto tu nie sú dostupné:';
	@override String get restoreForget => 'Zabudnúť';
	@override String get restoreInstall => 'Inštalovať';
	@override String get restoreLater => 'Neskôr';
	@override String get restoreInstalling => 'Inštalujú sa vaše rozšírenia…';
	@override String get restoreDoneTitle => 'Vaše rozšírenia sú späť';
	@override String restoreDoneBody({required Object names}) => 'Znova nainštalované: ${names}.';
	@override String get restorePartialTitle => 'Niektoré rozšírenia sa nepodarilo nainštalovať';
	@override String restoreFailed({required Object names}) => 'Nepodarilo sa nainštalovať: ${names}. Ponúkneme ich znova pri ďalšom otvorení aplikácie.';
	@override String get restoreBusyBody => 'Aplikácia stále nastavuje vaše rozšírenia. Ponúkneme ich znova pri ďalšom otvorení aplikácie.';
	@override String get restoreRuntimeDeadBody => 'Znova sme ich nainštalovali, ale vaše rozšírenia sa nespustili. Reštart aplikácie by ich mal obnoviť.';
	@override String revokedTitle({required Object name}) => '${name} bolo stiahnuté';
	@override String get revokedBody => 'Katalóg túto verziu stiahol, preto bola vypnutá.';
	@override String get downloadHashMismatch => 'Toto sťahovanie nie je rozšírenie, ktoré opísal katalóg.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Katalóg nemá verziu ${version} rozšírenia ${key}.';
	@override String get catalogLinkUnknown => 'Tento odkaz do katalógu neurčuje verziu rozšírenia.';
	@override String catalogNoRelease({required Object key}) => 'Katalóg nemá na tejto vetve žiadne vydanie ${key}.';
	@override String get installFromLink => 'Inštalovať z odkazu';
	@override String get unstableReleaseWarning => 'Toto je nestabilné vydanie, ktoré jeho vydavateľ neoznačil za hotové. Môže sa správať nesprávne a bude naďalej dostávať nestabilné aktualizácie.';
	@override String get bleedingReleaseWarning => 'Toto je najnovšie vývojové vydanie: rozpracovaná práca, ktorá sa môže pokaziť alebo stratiť nastavenia. Bude naďalej dostávať najnovšie vývojové aktualizácie.';
	@override String get channelUnstable => 'Nestabilné';
	@override String get channelBleeding => 'Vývojové';
	@override String get followsUnstable => 'Dostáva nestabilné a stabilné vydania';
	@override String get followsBleeding => 'Dostáva vývojové, nestabilné a stabilné vydania';
	@override String get followStableAction => 'Sledovať iba stabilné vydania';
	@override String get revokedBadge => 'Stiahnuté';
	@override String get refusedBadge => 'Nenačítalo sa';
	@override String get downloadNotHttps => 'Toto sťahovanie neprebieha cez zabezpečené spojenie.';
	@override String downloadUnreachable({required Object source}) => '${source} pre toto rozšírenie nie je dostupný.';
	@override String get detailsAction => 'Podrobnosti';
	@override String get installedFromFile => 'Nainštalované zo súboru';
	@override String get detailsWhatItDoes => 'Poskytuje podporu pre';
	@override String get installedPreloaded => 'Predinštalované';
	@override String get hookAccount => 'Prihlásenie do účtu';
	@override String get hookCallNotes => 'Poznámky k volacím znakom';
	@override String get hookDataFile => 'Offline údaje';
	@override String get hookExport => 'Export';
	@override String get hookLookup => 'Vyhľadávanie volacích znakov';
	@override String get hookScoring => 'Bodovanie';
	@override String get hookSpots => 'Spoty';
	@override String hookHunting({required Object program}) => 'Lov ${program}';
	@override String hookActivating({required Object program}) => 'Aktivácia ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '… a ${count} ďalšie rozšírenie',
		other: '… a ${count} ďalších rozšírení',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} dostupné rozšírenie',
		other: '${count} dostupných rozšírení',
	);
}

// Path: home
class _Translations$home$sk extends Translations$home$en {
	_Translations$home$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portable Logger';
	@override String get newOperation => 'Nová prevádzka';
	@override String get stationCallsign => 'Volací znak stanice';
	@override String get titleOptional => 'Názov (nepovinné)';
	@override String get emptyList => 'Zatiaľ žiadne prevádzky. Vytvorte jednu a začnite logovať.';
	@override String get quickLookup => 'Rýchle vyhľadávanie';
	@override late final _Translations$home$nav$sk nav = _Translations$home$nav$sk._(_root);
	@override late final _Translations$home$panels$sk panels = _Translations$home$panels$sk._(_root);
	@override String get toggleNav => 'Zobraziť alebo skryť popisy navigácie';
	@override late final _Translations$home$logs$sk logs = _Translations$home$logs$sk._(_root);
}

// Path: chase
class _Translations$chase$sk extends Translations$chase$en {
	_Translations$chase$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'loví';
	@override String goalsTwo({required Object first, required Object second}) => '${first} a ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} a ďalšie';
	@override late final _Translations$chase$station$sk station = _Translations$chase$station$sk._(_root);
	@override late final _Translations$chase$periodInline$sk periodInline = _Translations$chase$periodInline$sk._(_root);
	@override late final _Translations$chase$periodStats$sk periodStats = _Translations$chase$periodStats$sk._(_root);
	@override late final _Translations$chase$period$sk period = _Translations$chase$period$sk._(_root);
	@override late final _Translations$chase$goals$sk goals = _Translations$chase$goals$sk._(_root);
	@override late final _Translations$chase$panels$sk panels = _Translations$chase$panels$sk._(_root);
}

// Path: dialogs
class _Translations$dialogs$sk extends Translations$dialogs$en {
	_Translations$dialogs$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Podrobnosti o prevádzke';
	@override String get activities => 'Aktivity';
	@override String get stationCallsign => 'Volací znak stanice';
	@override String get multiStationIdentifier => 'Identifikátor pre viac staníc (iba čísla)';
	@override String get notes => 'Poznámky';
	@override String get deleteOperationTitle => 'Odstrániť prevádzku';
	@override String get purgeTestsTitle => 'Vyčistiť testovacie prevádzky';
	@override String get purgeTestsBody => 'Týmto sa natrvalo vymažú tieto testovacie prevádzky a ich QSO. Nedá sa to vrátiť späť.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Plus ${count} testovacie spojenie, ktoré nepatrí do žiadnej prevádzky.',
		other: 'Plus ${count} testovacích spojení, ktoré nepatria do žiadnej prevádzky.',
	);
	@override String get purgeTestsAction => 'Vyčistiť';
	@override String get syncAllTitle => 'Nahradiť denník tohto zariadenia?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL zálohuje a vymaže ${qsos} z tohto zariadenia a potom znova stiahne denník účtu zo servera. Záloha zostane v databáze tohto zariadenia.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${n} QSO ešte nie je synchronizované — server ho nikdy neprijal a NEVRÁTI sa.',
		other: '${n} QSO ešte nie je synchronizovaných — server ich nikdy neprijal a NEVRÁTIA sa.',
	);
	@override String get syncAllAction => 'Vymazať a znova synchronizovať';
	@override String get receivedPurgesTitle => 'Testovacie prevádzky odstránené inde';
	@override String get receivedPurgesBody => 'Tieto boli vymazané ako testovacie prevádzky na inom zariadení. Odstrániť ich aj tu? Týmto sa natrvalo vymažú spolu s ich QSO a nedá sa to vrátiť späť.';
	@override String get receivedPurgesAction => 'Odstrániť';
	@override late final _Translations$dialogs$callChange$sk callChange = _Translations$dialogs$callChange$sk._(_root);
}

// Path: operation
class _Translations$operation$sk extends Translations$operation$en {
	_Translations$operation$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Táto prevádzka je vymazaná. Obnovte ju, ak chcete logovať alebo robiť zmeny.';
	@override late final _Translations$operation$tabs$sk tabs = _Translations$operation$tabs$sk._(_root);
	@override late final _Translations$operation$positions$sk positions = _Translations$operation$positions$sk._(_root);
	@override String get stationCallsignNone => 'Bez volacieho znaku stanice';
	@override String get titleNone => 'Bez názvu';
	@override String get deleteOperation => 'Odstrániť prevádzku';
	@override String get loggingControlsStale => 'Polia aktivít môžu byť neaktuálne — znova otvorte prevádzku a obnovia sa';
	@override String get locationNone => 'Nenastavené';
	@override String get generalOperation => 'Všeobecná prevádzka';
	@override String titleFor({required Object value}) => 'pre ${value}';
	@override String titleAt({required Object value}) => 'na ${value}';
	@override String segmentNow({required Object description}) => 'Teraz ${description}';
	@override String get testOperationSuffix => 'Testovanie';
	@override late final _Translations$operation$menu$sk menu = _Translations$operation$menu$sk._(_root);
	@override late final _Translations$operation$layout$sk layout = _Translations$operation$layout$sk._(_root);
	@override late final _Translations$operation$export$sk export = _Translations$operation$export$sk._(_root);
	@override late final _Translations$operation$spots$sk spots = _Translations$operation$spots$sk._(_root);
	@override late final _Translations$operation$import$sk import = _Translations$operation$import$sk._(_root);
}

// Path: map
class _Translations$map$sk extends Translations$map$en {
	_Translations$map$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$sk outlineIssue = _Translations$map$outlineIssue$sk._(_root);
	@override String get outlinesDisclaimer => 'Obrysy sú iba orientačné. Overte si to sami!';
	@override String outlinesCredit({required Object sources}) => 'Obrysy: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Hranice: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Zariadenia: ${sources}';
	@override String get fullCredits => 'Úplné zdroje údajov';
	@override String get fewerCredits => 'Menej zdrojov';
	@override String get emptyState => 'Zatiaľ žiadne polohy QSO.\nTu sa zobrazia QSO s lokátorom, štátom alebo krajinou.';
	@override String get unavailable => 'Mapa momentálne nie je dostupná.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plochá';
	@override String get globe => 'Glóbus';
	@override String get zoomIn => 'Priblížiť';
	@override String get zoomOut => 'Oddialiť';
	@override late final _Translations$map$postcard$sk postcard = _Translations$map$postcard$sk._(_root);
}

// Path: mapsView
class _Translations$mapsView$sk extends Translations$mapsView$en {
	_Translations$mapsView$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapy';
	@override String get searchHint => 'Hľadať parky, vrcholy a ďalšie';
	@override String get activities => 'Aktivity';
	@override String get layers => 'Vrstvy';
	@override String get baseMap => 'Podkladová mapa';
	@override String get satellite => 'Satelit (Esri)';
	@override String get facilities => 'Zariadenia parkov';
	@override String get boundaries => 'Hranice';
	@override String get currentLocation => 'Aktuálna poloha';
	@override String noMatches({required Object text}) => '„${text}“ nič nezodpovedá';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} referencia na ${where}',
		other: '${count} referencií na ${where}',
	);
	@override String get startOperation => 'Začať prevádzku s týmito referenciami';
}

// Path: activitiesView
class _Translations$activitiesView$sk extends Translations$activitiesView$en {
	_Translations$activitiesView$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aktivity';
	@override String get activitiesCountZero => 'Nie sú vybrané žiadne aktivity';
	@override String get activitiesCountOne => '1 aktivita';
	@override String activitiesCountOther({required Object count}) => 'Aktivity: ${count}';
	@override String get empty => 'Zatiaľ žiadne aktivity — pridajte ju pomocou Návrhy a vyhľadávanie nižšie';
	@override String get removeActivity => 'Odstrániť';
	@override String openReferenceLink({required Object name}) => 'Otvoriť ${name}';
	@override String get editActivity => 'Upraviť aktivitu';
	@override String get manageExtensions => 'Spravovať rozšírenia';
	@override String get manage => 'Spravovať';
	@override String activitiesTitle1({required Object first}) => 'Typy aktivít: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Typy aktivít: ${first} a ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Typy aktivít: ${first}, ${second} a ďalšie (${more})';
	@override String get reference => 'Referencia';
	@override String get invalidReference => 'Neplatná';
	@override String get duplicateReference => 'Už pridaná';
	@override String get searchHint => 'Hľadať podľa názvu, referencie alebo čohokoľvek iného…';
	@override String get noSuggestions => 'Žiadne zhody';
	@override String get noSuggestionsHint => 'Hľadajte vyššie podľa názvu alebo čísla referencie';
	@override String get noSuggestionsExample => '(napríklad \'trail\' alebo \'4556\')';
	@override String get allOptions => 'Typy aktivít';
	@override String get determiningLocation => 'Zisťuje sa aktuálna poloha…\nČaká sa na GPS na nájdenie referencií v blízkosti';
	@override String get locationUnavailableTitle => 'Údaje o polohe nie sú dostupné';
	@override String get locationDeniedTitle => 'Prístup k polohe bol zamietnutý';
	@override String get locationBlockedTitle => 'Prístup k polohe je zablokovaný';
	@override String get noNearbyReason => 'Nedajú sa určiť referencie v blízkosti';
	@override String locationManualHint({required Object icon}) => 'Ťuknite na ${icon} a zadajte polohu ručne,\nalebo jednoducho hľadajte referencie podľa názvu';
	@override String get locationGrantAction => 'Povoliť prístup k polohe';
	@override String get locationSettingsAction => 'Otvoriť nastavenia';
	@override String get locationSettingsUnavailable => 'Povoľte prístup k polohe v systémových nastaveniach';
	@override String get locationGrantRefused => 'Stále bez polohy — systém to znova zamietol';
	@override String get searchUnavailableTitle => 'Vyhľadávanie aktivít nie je dostupné';
	@override String get searchUnavailableReason => 'Žiadne rozšírenie aktivít nedokázalo vyhľadávanie spustiť. Skúste to o chvíľu znova.';
	@override String get emptySheet => 'Pridajte ju pomocou návrhov a vyhľadávania nižšie';
	@override String get exports => 'Exporty';
	@override String get exportLogs => 'Exportovať denníky';
	@override String get tools => 'Nástroje';
	@override String get toolsTitle => 'Nástroje prevádzky';
	@override String get operationDetails => 'Podrobnosti o prevádzke';
	@override String get share => 'Zdieľať';
	@override String get archive => 'Archivovať';
	@override String get deleteOperation => 'Odstrániť prevádzku';
	@override String get undeleteOperation => 'Obnoviť prevádzku';
	@override String get alreadySelected => 'Už vybrané';
	@override String get selected => 'Vybrané';
	@override String pickPosition({required Object index, required Object count}) => '${index} z ${count}';
	@override String get previousPick => 'Predchádzajúca zhoda';
	@override String get nextPick => 'Ďalšia zhoda';
	@override String get retiredReference => 'Zrušená';
	@override String enableExtension({required Object name}) => 'Povoliť ${name}';
	@override String get enableExtensionHint => 'Toto rozšírenie zodpovedá vášmu hľadaniu, ale momentálne nie je povolené';
	@override String get enableExtensionForRefHint => 'Toto rozšírenie spracúva jednu z referencií tejto prevádzky, ale momentálne nie je povolené';
	@override String extensionNotRunning({required Object name}) => '${name} nebeží';
	@override String get extensionNotRunningHint => 'Toto rozšírenie bolo vypnuté, viac informácií nájdete v nastaveniach rozšírení';
	@override String installExtension({required Object name}) => 'Inštalovať ${name}';
	@override String get installExtensionHint => 'Toto rozšírenie zodpovedá vášmu hľadaniu, ale nie je nainštalované';
	@override String get onlyCatalogMatches => 'Žiadne zhody\nNiektoré rozšírenia v katalógu môžu mať výsledky.\nNainštalujte ich v časti Typy aktivít nižšie.';
	@override String get setupUnavailable => 'Nastavenie tejto aktivity sa nepodarilo načítať — skúste to znova cez Spravovať';
	@override String get controlsUnavailableTitle => 'Ovládanie aktivity nie je dostupné';
	@override String get controlsUnavailableReason => 'Vaše referencie sú v bezpečí, ale ich úprava momentálne nie je dostupná.';
	@override String get controlsUnavailableRetry => 'Skúsiť znova';
	@override String get onlyDisabledMatches => 'Žiadne zhody\nNiektoré dostupné rozšírenia môžu mať výsledky.\nPovoľte ich v časti Typy aktivít nižšie.';
	@override String get onlyNotRunningMatches => 'Žiadne zhody\nNiektoré rozšírenia, ktoré môžu mať výsledky, nebežia.\nPozrite si Typy aktivít nižšie.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Hľadať';
	@override String get addToOperation => 'Pridať do prevádzky';
	@override String get addToOperationShort => 'Pridať';
	@override String get mapEmptyState => 'Žiadne výsledky na zobrazenie na mape';
	@override String get mapEmptyStateHint => 'Prepnite späť na zoznam alebo hľadajte niečo iné';
	@override String get imports => 'Importy';
}

// Path: loggingControls
class _Translations$loggingControls$sk extends Translations$loggingControls$en {
	_Translations$loggingControls$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Čas (UTC)';
	@override String get date => 'Dátum';
	@override String get now => 'Teraz';
	@override String get frequency => 'Frekvencia';
	@override String get mode => 'Mód';
	@override String get theirCall => 'Ich volací znak';
	@override String get noteField => 'Poznámka';
	@override String get todoField => 'Úloha';
	@override String get sent => 'Odoslané';
	@override String get rcvd => 'Prijaté';
	@override String get more => 'Viac';
	@override String get revert => 'Vrátiť späť';
	@override String get undoDelete => 'Zrušiť vymazanie';
	@override String get restore => 'Obnoviť';
	@override String get wipe => 'Vymazať';
	@override String get undo => 'Späť';
	@override String get pendingDeleteTapWarning => 'Ťuknite na kôš ešte raz a toto QSO sa vymaže';
	@override String get pendingDeleteClickWarning => 'Kliknite na kôš ešte raz a toto QSO sa vymaže';
	@override String get deletedQsoWarning => 'Vymazané QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Ťuknite na kôš ešte raz a vymaže sa: ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Kliknite na kôš ešte raz a vymaže sa: ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'Vymazané: ${kind}';
	@override String get timeControl => 'Čas';
	@override String get radioControl => 'Rádio';
	@override String get powerControl => 'Výkon';
	@override String get notesControl => 'Poznámky';
	@override String get power => 'Výkon';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Ovládanie logovania';
	@override String get spottingControl => 'Spotovanie';
	@override String get spottingSelfControl => 'Self-spotovanie';
	@override String spotSelfAt({required Object freq}) => 'Self-spot na ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} na ${freq}';
	@override String spotTooLate({required Object call}) => 'Príliš neskoro na spot ${call}';
	@override String get spotNoFreq => 'Najprv nastavte frekvenciu pre spot';
	@override String get spotComment => 'Komentár';
	@override String get bandOrFreqRequired => 'Pred zápisom nastavte frekvenciu alebo pásmo';
	@override String get missingBand => 'Bez pásma';
	@override String get missingMode => 'Bez módu';
	@override String saveFailed({required Object error}) => 'Nepodarilo sa uložiť: ${error}';
	@override String deleteFailed({required Object error}) => 'Nepodarilo sa vymazať: ${error}';
	@override late final _Translations$loggingControls$info$sk info = _Translations$loggingControls$info$sk._(_root);
}

// Path: formChrome
class _Translations$formChrome$sk extends Translations$formChrome$en {
	_Translations$formChrome$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(bez názvu)';
	@override String get showMore => 'Zobraziť viac';
	@override String get showAll => 'Zobraziť všetko';
	@override String get showFewer => 'Zobraziť menej';
	@override String get defaults => 'Predvolené';
	@override String get search => 'Hľadať';
	@override String get clear => 'Vymazať';
	@override String get openPage => 'Otvoriť stránku';
	@override String get connected => 'Pripojené';
	@override String get notConnected => 'Nepripojené';
	@override String get manage => 'Spravovať';
	@override String get connect => 'Pripojiť';
	@override String get formTitle => 'Formulár';
	@override String addItem({required Object label}) => 'Pridať ${label}';
	@override String editItem({required Object label}) => 'Upraviť ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Zobrazuje sa ${shown} z ${total} (vybrané: ${selected})';
	@override String validationError({required Object error}) => 'Chyba overenia: ${error}';
	@override String transformationError({required Object error}) => 'Chyba transformácie: ${error}';
	@override String actionError({required Object error}) => 'Chyba: ${error}';
	@override String get removeItem => 'Odstrániť';
	@override String get storageUnavailable => 'Prihlasovacie údaje nie sú dostupné';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$sk extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Upraviť QSO';
	@override String get operatorCall => 'Operátor';
	@override String get position => 'Pracovisko';
	@override String get theirName => 'Meno';
	@override String get theirGrid => 'Lokátor';
	@override String get theirState => 'Štát';
	@override String get band => 'Pásmo';
	@override String get notes => 'Poznámky';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Ich informácie';
	@override String get sectionOur => 'Naše informácie';
	@override String get sectionNotes => 'Poznámky';
	@override String get theirCity => 'Mesto';
	@override String get theirCounty => 'Kraj';
	@override String get theirEntity => 'Entita';
	@override String get theirCqZone => 'CQ zóna';
	@override String get theirItuZone => 'ITU zóna';
	@override String get theirArrlSection => 'ARRL sekcia';
	@override String get theirLat => 'Zemepisná šírka';
	@override String get theirLon => 'Zemepisná dĺžka';
	@override String get theirPower => 'Ich výkon';
}

// Path: qsoList
class _Translations$qsoList$sk extends Translations$qsoList$en {
	_Translations$qsoList$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Zatiaľ žiadne QSO — urobte s niekým spojenie!';
	@override String get bandOrModeWarning => 'Skontrolujte, či máte správne pásmo a mód';
	@override String get today => 'Dnes';
	@override String get yesterday => 'Včera';
	@override String get tomorrow => 'Zajtra';
}

// Path: loggingPanel
class _Translations$loggingPanel$sk extends Translations$loggingPanel$en {
	_Translations$loggingPanel$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Štatistiky prevádzky';
	@override String get scoring => 'Bodovanie';
	@override String get dxccEntities => 'Entity DXCC';
	@override String get statesWorked => 'Štáty';
	@override String get provincesWorked => 'Provincie';
	@override String get duplicates => 'Duplikáty';
}

// Path: callInfo
class _Translations$callInfo$sk extends Translations$callInfo$en {
	_Translations$callInfo$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Zobraziť obrázok';
	@override String get imageUnavailable => 'Fotografia nie je dostupná';
	@override String get photo => 'Fotografia';
	@override String get notes => 'Poznámky';
	@override String distanceTo({required Object distance}) => '${distance} do';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) do';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) do';
	@override String distanceAway({required Object distance}) => '${distance} ďaleko';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) ďaleko';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) ďaleko';
	@override String get thisOpCountOne => '1 QSO v tejto prevádzke';
	@override String thisOpCountOther({required Object count}) => '${count} QSO v tejto prevádzke';
	@override String get otherOpsCountOne => '1 QSO v iných prevádzkach';
	@override String otherOpsCountOther({required Object count}) => '${count} QSO v iných prevádzkach';
	@override String andMore({required Object count}) => '… a ${count} ďalších';
	@override String withCall({required Object call}) => 's ${call}';
	@override String fromOperation({required Object where}) => 'z ${where}';
	@override late final _Translations$callInfo$history$sk history = _Translations$callInfo$history$sk._(_root);
}

// Path: settings
class _Translations$settings$sk extends Translations$settings$en {
	_Translations$settings$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nastavenia';
	@override String get language => 'Jazyk';
	@override String languageSystem({required Object language}) => 'Podľa nastavení systému (${language})';
	@override late final _Translations$settings$theme$sk theme = _Translations$settings$theme$sk._(_root);
	@override late final _Translations$settings$themeDescription$sk themeDescription = _Translations$settings$themeDescription$sk._(_root);
	@override String get fontScale => 'Veľkosť písma';
	@override late final _Translations$settings$fontScaleOpts$sk fontScaleOpts = _Translations$settings$fontScaleOpts$sk._(_root);
	@override late final _Translations$settings$keepDeviceAwake$sk keepDeviceAwake = _Translations$settings$keepDeviceAwake$sk._(_root);
	@override String get layoutDensity => 'Hustota rozloženia';
	@override late final _Translations$settings$layoutDensityOpts$sk layoutDensityOpts = _Translations$settings$layoutDensityOpts$sk._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'okno je príliš nízke, používa sa ${effective}';
	@override String get layoutDensityAtLimit => 'na maximum';
	@override String get distanceUnits => 'Jednotky vzdialenosti';
	@override late final _Translations$settings$distanceUnitsOpts$sk distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$sk._(_root);
	@override String get userInterface => 'Používateľské rozhranie';
	@override late final _Translations$settings$logging$sk logging = _Translations$settings$logging$sk._(_root);
	@override late final _Translations$settings$catServer$sk catServer = _Translations$settings$catServer$sk._(_root);
	@override late final _Translations$settings$radio$sk radio = _Translations$settings$radio$sk._(_root);
	@override late final _Translations$settings$help$sk help = _Translations$settings$help$sk._(_root);
	@override late final _Translations$settings$exports$sk exports = _Translations$settings$exports$sk._(_root);
	@override late final _Translations$settings$map$sk map = _Translations$settings$map$sk._(_root);
	@override late final _Translations$settings$privacy$sk privacy = _Translations$settings$privacy$sk._(_root);
	@override String get operatorCall => 'Volací znak operátora';
	@override late final _Translations$settings$sync$sk sync = _Translations$settings$sync$sk._(_root);
	@override late final _Translations$settings$peers$sk peers = _Translations$settings$peers$sk._(_root);
	@override String get developerMode => 'Režim vývojára';
	@override late final _Translations$settings$syncPanel$sk syncPanel = _Translations$settings$syncPanel$sk._(_root);
	@override late final _Translations$settings$accounts$sk accounts = _Translations$settings$accounts$sk._(_root);
	@override late final _Translations$settings$station$sk station = _Translations$settings$station$sk._(_root);
	@override late final _Translations$settings$offlineData$sk offlineData = _Translations$settings$offlineData$sk._(_root);
	@override late final _Translations$settings$profiles$sk profiles = _Translations$settings$profiles$sk._(_root);
	@override late final _Translations$settings$search$sk search = _Translations$settings$search$sk._(_root);
	@override late final _Translations$settings$developer$sk developer = _Translations$settings$developer$sk._(_root);
	@override late final _Translations$settings$about$sk about = _Translations$settings$about$sk._(_root);
	@override late final _Translations$settings$panels$sk panels = _Translations$settings$panels$sk._(_root);
	@override String get showMoreSettings => 'Zobraziť ďalšie nastavenia';
	@override String get gridPrecision => 'Presnosť lokátora';
	@override late final _Translations$settings$gridPrecisionOpts$sk gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$sk._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$sk gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$sk._(_root);
}

// Path: commands
class _Translations$commands$sk extends Translations$commands$en {
	_Translations$commands$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Najprv povoľte synchronizáciu v Nastaveniach.';
	@override String get fullResyncStarted => 'Úplná opätovná synchronizácia sa začala — lokálne údaje boli najprv zálohované.';
	@override String noDataFilesMatched({required Object target}) => '„${target}“ nezodpovedajú žiadne dátové súbory.';
	@override String reloadFailed({required Object error}) => 'Opätovné načítanie zlyhalo: ${error}';
	@override String get reloadingAll => 'Znova sa načítavajú všetky dátové súbory…';
	@override String reloadingTarget({required Object target}) => 'Znova sa načítavajú dátové súbory ${target}…';
	@override String unknownExperiment({required Object token}) => 'Neznámy experiment „${token}“';
	@override String experimentEnabled({required Object name}) => '${name} povolený';
	@override String experimentDisabled({required Object name}) => '${name} vypnutý';
	@override String get sentryTestSent => 'Testovacie hlásenie chyby odoslané do Sentry';
	@override String get sentryTestLocalOnly => 'Sentry je v tejto zostave vypnuté — testovacia chyba bola zaznamenaná iba lokálne';
	@override String get noOperationOpen => 'Tento príkaz potrebuje otvorenú prevádzku';
	@override String unknownSegmentKind({required Object kind}) => 'Nie je známe, ako označiť „${kind}“';
	@override String get operationAlreadyStarted => 'Táto prevádzka už má značku začiatku';
	@override String get couldNotOpenLocation => 'Prestávka bola pridaná, ale obrazovku polohy sa nepodarilo otvoriť';
	@override String get noTestOperations => 'Žiadne testovacie prevádzky na vyčistenie';
	@override String get purgeTestsUnavailable => 'PURGETESTS potrebuje zobraziť potvrdzovacie okno, ktoré tu nie je dostupné';
	@override String get syncAllUnavailable => 'SYNCALL potrebuje zobraziť potvrdzovacie okno, ktoré tu nie je dostupné';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Vyčistená ${count} testovacia prevádzka',
		other: 'Vyčistených ${count} testovacích prevádzok',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Vyčistených ${purged} z ${total} testovacích prevádzok — zvyšok zlyhal; skúste PURGETESTS znova';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Vyčistené ${count} testovacie spojenie bez prevádzky',
		other: 'Vyčistených ${count} testovacích spojení bez prevádzky',
	);
	@override String get purgeTestsContactsFailed => 'Testovacie prevádzky boli vyčistené, ale testovacie spojenia bez prevádzky zlyhali; skúste PURGETESTS znova';
	@override String get purgeTestsNothingToDo => 'Nič nebolo vyčistené';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Odstránených ${removed} z ${total} testovacích prevádzok — zvyšok zlyhal; skúste Skontrolovať znova';
	@override String get receivedPurgesFailed => 'Tieto testovacie prevádzky sa nepodarilo odstrániť — skúste Skontrolovať znova';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} testovacia prevádzka bola odstránená na inom zariadení',
		other: '${count} testovacích prevádzok bolo odstránených na inom zariadení',
	);
	@override String get receivedPurgesReview => 'Skontrolovať';
	@override String get settingOn => 'Zap.';
	@override String get settingOff => 'Vyp.';
	@override String get settingEmpty => '(prázdne)';
	@override String get settingSecretSet => '(nastavené)';
	@override String get settingSecretUnset => '(nenastavené)';
	@override String settingSelectedCount({required Object count}) => 'Vybrané: ${count}';
	@override String get settingExpectsOnOff => 'on alebo off';
	@override String settingExpectsOneOf({required Object choices}) => 'jedno z: ${choices}';
	@override String get settingExpectsNumber => 'číslo';
	@override String settingVanished({required Object label}) => '„${label}“ už nie je dostupné';
	@override String get noCwKeyer => 'Žiadna pripojená rádiostanica nedokáže kľúčovať CW';
	@override String get noKeyer => 'Žiadna pripojená rádiostanica nedokáže kľúčovať CW ani prehrávať hlasové pamäte';
	@override String get keyerNeedsOperation => 'Na použitie CW kľúčovača otvorte prevádzku';
	@override String get keyerExperimentOff => 'Kľúčovanie CW je vypnuté — zapnite ho pomocou EXP KEYER';
	@override String get esmExperimentOff => 'Enter odosiela správy je vypnuté — zapnite ho pomocou EXP ESM';
	@override String cwSending({required Object text}) => 'Odosiela sa CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW správa F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW správa F${n} nebola odoslaná: rozšírenia nie sú pripravené';
	@override String settingNotStored({required Object label}) => '„${label}“ túto hodnotu neprijalo';
}

// Path: commandDialog
class _Translations$commandDialog$sk extends Translations$commandDialog$en {
	_Translations$commandDialog$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Hľadajte volacie znaky alebo zadajte príkaz';
	@override String noResults({required Object text}) => '„${text}“ nič nezodpovedá';
	@override String get sectionCommands => 'Príkazy';
	@override String get sectionGoTo => 'Prejsť na';
	@override String get sectionOperations => 'Prevádzky';
	@override String get goHome => 'Domov';
	@override String get goSettings => 'Nastavenia';
	@override String get goNewOperation => 'Nová prevádzka';
	@override String runTyped({required Object text}) => 'Spustiť „${text}“';
	@override String get sectionSuggestions => 'Skúste';
	@override String get lookingUp => 'Vyhľadáva sa volací znak…';
	@override String get blockedByPane => 'Príkazy sa nedajú použiť, kým je otvorený panel alebo dialóg';
}

// Path: expiredBuild
class _Translations$expiredBuild$sk extends Translations$expiredBuild$en {
	_Translations$expiredBuild$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Platnosť tejto zostavy vypršala';
	@override String get body => 'Navštívte ham2k.com a stiahnite si novšiu verziu.';
	@override String get visit => 'Navštíviť ham2k.com';
	@override String get dismiss => 'Napriek tomu pokračovať';
}

// Path: staleness
class _Translations$staleness$sk extends Translations$staleness$en {
	_Translations$staleness$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Čaká dôležitá aktualizácia';
	@override String get codePushFloorBody => 'Táto verzia obsahuje opravu, ktorú ešte nemáte.';
	@override String get restartToApply => 'Reštartujte aplikáciu a uplatní sa.';
	@override String get quitAndReopen => 'Ukončite aplikáciu a znova ju otvorte, aby sa uplatnila.';
	@override String get reopenToApply => 'Zatvorte aplikáciu a znova ju otvorte, aby sa uplatnila.';
	@override String get ignoreForNow => 'Zatiaľ ignorovať';
}

// Path: spotting
class _Translations$spotting$sk extends Translations$spotting$en {
	_Translations$spotting$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Zatiaľ nie je zapísané žiadne QSO na spotovanie.';
	@override String get setFrequencyFirst => 'Najprv nastavte frekvenciu.';
	@override String get nothingToSpot => 'Nie je čo spotovať — žiadne rozšírenie tu neponúka spotovanie.';
	@override String spotFailed({required Object source, required Object message}) => '${source} zlyhal: ${message}';
	@override String get unknownError => 'neznáma chyba';
	@override String get notSent => 'Spot nebol odoslaný.';
	@override String get notRefreshedOffline => 'Bez pripojenia — spoty neboli obnovené';
}

// Path: dataFiles
class _Translations$dataFiles$sk extends Translations$dataFiles$en {
	_Translations$dataFiles$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Sťahuje sa…';
	@override String downloadFailedTitle({required Object name}) => '${name} sa nepodarilo stiahnuť';
	@override String get downloadFailedWebHint => 'Môže ísť o problém so sieťou alebo hostiteľ tohto odkazu nemusí podporovať priame sťahovanie z webového prehliadača. Skúste desktopovú alebo mobilnú aplikáciu, alebo iné umiestnenie súboru.';
	@override String get downloadTimedOut => 'Server odpovedal príliš pomaly. Skúste to neskôr.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} odpovedal chybou (HTTP ${status}). Skúste to neskôr.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} nedokázal poskytnúť tento súbor (HTTP ${status}). Skontrolujte, či je jeho adresa stále správna.';
	@override String processingFailedTitle({required Object name}) => '${name} sa nepodarilo spracovať';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Sťahovanie malo iba ${imported} z ${existing} záznamov na tomto zariadení, preto boli vynechané záznamy ponechané. Obnovením v Nastavenia › Offline údaje ho napriek tomu prijmete.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Importovaný ${count} záznam pre ${label}.',
		other: 'Importovaných ${count} záznamov pre ${label}.',
	);
	@override String importedData({required Object label}) => 'Importované údaje pre ${label}.';
	@override String get cleanedUpTitle => 'Údaje rozšírení vyčistené';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Odstránené údaje ${count} dátového súboru z vypnutých rozšírení.',
		other: 'Odstránené údaje ${count} dátových súborov z vypnutých rozšírení.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} záznamov';
	@override String get definitionUnavailable => 'Zdroj súboru neposkytol definíciu — jeho rozšírenie sa možno práve reštartuje alebo je nesprávne nakonfigurované. Skúste to o chvíľu znova.';
}

// Path: updates
class _Translations$updates$sk extends Translations$updates$en {
	_Translations$updates$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Aktualizácia dostupná';
	@override String newVersionAvailable({required Object version}) => 'Je dostupná nová verzia (${version}).';
	@override String get getIt => 'Stiahnuť';
	@override String get ok => 'OK';
	@override String get updateReady => 'Aktualizácia pripravená';
	@override String get restartToApply => 'Aktualizácia bola stiahnutá. Reštartujte a uplatní sa.';
	@override String get appliesNextLaunch => 'Aktualizácia bola stiahnutá. Uplatní sa pri ďalšom otvorení aplikácie.';
	@override String get restartNow => 'Reštartovať teraz';
	@override String get reloadToUpdate => 'Je dostupná novšia verzia tejto stránky. Načítajte ju znova.';
	@override String get reloadNow => 'Znova načítať';
	@override String get checkForUpdates => 'Skontrolovať aktualizácie';
	@override String get checkingForUpdates => 'Kontrola aktualizácií…';
	@override String get upToDate => 'Aktuálne';
	@override String get automaticChecks => 'Kontrolovať automaticky';
	@override String get automaticChecksDescription => 'Hľadať nové verzie na pozadí, od ďalšieho spustenia aplikácie';
}

// Path: extensionService
class _Translations$extensionService$sk extends Translations$extensionService$en {
	_Translations$extensionService$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Prostredie rozšírení nie je pripravené.';
	@override String testFailed({required Object error}) => 'Test zlyhal: ${error}';
	@override String connectedAs({required Object identity}) => 'Pripojený ako ${identity}';
	@override String get invalidFieldConfiguration => 'Neplatná konfigurácia poľa';
	@override String get invalidValue => 'Neplatná hodnota';
	@override String validationError({required Object error}) => 'Chyba overenia: ${error}';
	@override String actionFailed({required Object error}) => 'Akcia zlyhala: ${error}';
	@override String get commandFailed => 'Príkaz sa nepodarilo spustiť';
	@override String get reportUnavailable => 'Hlásenia sa momentálne nedajú odoslať';
	@override String get stashUnavailable => 'Ham2K úschovňa súborov je momentálne nedostupná';
	@override String timersSuspendedBudget({required Object name}) => '${name} strávilo príliš veľa času v časovačoch. Sú zastavené, kým sa rozšírenia nereštartujú.';
	@override String timersSuspendedFailures({required Object name}) => 'Časovače ${name} opakovane zlyhávali. Sú zastavené, kým sa rozšírenia nereštartujú.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} uviazlo v časovači. Jeho časovače sú zastavené, kým sa rozšírenia nereštartujú.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$sk extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Poloha prevádzky';
	@override String get selectedLocation => 'Vybraná lokalita';
	@override String get gridSquare => 'Lokátor';
	@override String get gridInvalid => 'Potrebuje 4, 6, 8 alebo 10 znakov, napr. FN31pr';
	@override String get suggestedLocations => 'Odporúčané lokality';
	@override String get deviceGps => 'GPS zariadenia';
	@override String peerGps({required Object device}) => 'GPS z ${device}';
	@override String get locating => 'Lokalizácia…';
	@override String get gpsUnavailable => 'Poloha nie je dostupná';
	@override String get permissionDenied => 'Prístup k polohe bol zamietnutý';
	@override String get permissionBlocked => 'Prístup k polohe je zablokovaný';
	@override String get moreDetails => 'Ďalšie podrobnosti';
	@override String get stateOrProvince => 'Štát alebo provincia (nepovinné)';
	@override String get controlsUnavailableTitle => 'Ovládanie aktivity nie je dostupné';
	@override String get controlsUnavailableReason => 'Tieto referencie sa dajú stále použiť; len ich aktivity neboli dostupné.';
	@override String get controlsUnavailableRetry => 'Skúsiť znova';
	@override String get county => 'Kraj (nepovinné)';
}

// Path: versionLabel
class _Translations$versionLabel$sk extends Translations$versionLabel$en {
	_Translations$versionLabel$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Verzia ${version}';
	@override String patch({required Object patch}) => 'Oprava ${patch}';
	@override String build({required Object build}) => 'zostava ${build}';
}

// Path: notices
class _Translations$notices$sk extends Translations$notices$en {
	_Translations$notices$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Zatiaľ žiadne oznámenia';
	@override String get webStorageInMemory => 'Tento prehliadač nedokázal poskytnúť trvalé úložisko — denník je iba v pamäti a po zatvorení tejto karty sa STRATÍ. Použite aktuálny Chrome, Firefox, Safari alebo Edge.';
	@override String get webStorageUnreliable => 'Tento prehliadač používa náhradné úložisko, ktoré nie je bezpečné pri viacerých kartách — nechajte otvorenú iba jednu kartu a nechajte zapnutú synchronizáciu.';
	@override String get logFromNewerBuildTitle => 'Tento denník potrebuje novšiu verziu';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Váš denník zapísala novšia verzia HaLo (verzia úložiska ${storage}; táto rozumie ${understood}), preto sa nedá otvoriť a nové spojenia sa neuložia. Znova nainštalujte novšiu verziu — alebo, ak ste chceli spustiť túto zostavu, nasmerujte ju na iný priečinok s údajmi. Denník je v ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Váš denník zapísala novšia verzia HaLo (verzia úložiska ${storage}; táto rozumie ${understood}), preto sa nedá otvoriť a nové spojenia sa neuložia. Otvorte tento denník radšej touto novšou verziou.';
	@override String get preferencesRestoredTitle => 'Nastavenia obnovené zo zálohy';
	@override String get preferencesRestored => 'Súbor nastavení sa nepodarilo prečítať, preto HaLo obnovil jeho poslednú dobrú kópiu. Čokoľvek ste zmenili v predchádzajúcej relácii, možno bude treba nastaviť znova. Nečitateľný súbor je uložený vedľa neho pod názvom shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Nastavenia obnovené na predvolené';
	@override String get preferencesReset => 'Súbor nastavení sa nepodarilo prečítať a nebola k dispozícii žiadna záloha, preto HaLo začal s predvolenými hodnotami. Nečitateľný súbor je uložený v priečinku s údajmi aplikácie pod názvom shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} sa nepripojila automaticky';
	@override String autoConnectHeld({required Object name}) => 'HaLo prestal odpovedať, keď sa naposledy začal pripájať k ${name}, preto ju tentoraz nechal tak, aby to neriskoval znova. Skontrolujte, či je rádiostanica zapnutá a kábel pripojený, potom pre ňu stlačte Pripojiť v Nastaveniach.';
}

// Path: syncAccount
class _Translations$syncAccount$sk extends Translations$syncAccount$en {
	_Translations$syncAccount$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anonymný účet (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (čaká na potvrdenie)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (čaká na potvrdenie - #${id})';
}

// Path: deepLink
class _Translations$deepLink$sk extends Translations$deepLink$en {
	_Translations$deepLink$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Najprv začnite prevádzku a potom toto spojenie pošlite znova';
	@override String get waitingInOperation => 'Toto spojenie čaká v prevádzke za touto obrazovkou';
	@override String unknownActivities({required Object refs}) => 'Toto zariadenie nemá žiadnu aktivitu pre ${refs}, preto boli tieto referencie vynechané';
	@override String activitiesUnavailable({required Object refs}) => 'Vaše aktivity neboli dostupné, preto bolo ${refs} vynechané — skúste tento odkaz znova';
}

// Path: confirmDevice
class _Translations$confirmDevice$sk extends Translations$confirmDevice$en {
	_Translations$confirmDevice$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Potvrdiť zariadenie';
	@override String get codePrompt => 'Zadajte kód zobrazený na zariadení, ktoré sa chce pripojiť k tomuto účtu.';
	@override String get code => 'Kód';
	@override String get lookUp => 'Vyhľadať';
	@override String get codeNotFound => 'Tomuto kódu nezodpovedá žiadna žiadosť. Kódy vypršia po 10 minútach — požiadajte druhé zariadenie o nový.';
	@override String get linkExpired => 'Platnosť tohto odkazu vypršala. Požiadajte druhé zariadenie, aby zobrazilo nový QR kód.';
	@override String areYouSure({required Object device}) => 'Prepojiť ${device} s týmto účtom?';
	@override String get unnamedDevice => 'nepomenované zariadenie';
	@override String get grantWarning => 'Bude môcť čítať a meniť každú prevádzku a QSO v tomto účte.';
	@override String get needsSyncTitle => 'Toto zariadenie sa ešte nesynchronizuje';
	@override String get needsSyncText => 'Zapnite synchronizáciu Ham2K Log Filer a prepojte toto zariadenie s účtom, až potom môže pridať ďalšie.';
	@override String get malformedRequest => 'Synchronizačný server poslal žiadosť, ktorú táto aplikácia nedokázala prečítať. Požiadajte druhé zariadenie, aby to skúsilo znova.';
	@override String get linkIt => 'Prepojiť zariadenie';
}

// Path: switchAccounts
class _Translations$switchAccounts$sk extends Translations$switchAccounts$en {
	_Translations$switchAccounts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Zatiaľ žiadne podrobnosti o účte';
	@override String get currentAccount => 'Aktuálny účet';
	@override String get otherAccounts => 'Iné účty';
	@override String get linkToAnother => 'Prepojiť s iným účtom';
	@override String get linkWithSibling => 'Prepojiť s inou aplikáciou Ham2K';
	@override String get linkWithPolo => 'Prepojiť s účtom zo staršej verzie';
	@override String get linkWithSiblingDescription => 'Máte nainštalovanú inú aplikáciu Ham2K. Prepojte sa s účtom, ktorý sa používa tam.';
	@override String siblingPrompt({required Object app}) => 'Schváľte žiadosť v ${app} a potom sa vráťte sem.';
	@override String openSiblingAgain({required Object app}) => 'Znova otvoriť ${app}';
	@override String get siblingNoGrant => 'Nefungovalo to? Otvorte ju znova alebo sa vráťte a prepojte sa inak.';
	@override String siblingOpenFailed({required Object app}) => '${app} sa nepodarilo otvoriť.';
	@override String siblingLinkRenewed({required Object app}) => 'Platnosť odkazu vypršala a nový je pripravený — znova otvorte ${app}.';
	@override String get tryAgain => 'Skúsiť znova';
	@override String get linkWithQr => 'Prepojiť pomocou QR kódu';
	@override String get linkWithQrDescription => 'Naskenujte ho zo zariadenia, ktoré už účet používa';
	@override String get linkWithEmail => 'Prepojiť pomocou e-mailovej adresy';
	@override String get linkWithEmailDescription => 'Potvrďte kódom alebo odkazom v e-maile';
	@override String get enterEmailPrompt => 'Zadajte e-mailovú adresu účtu, ktorý má toto zariadenie používať.';
	@override String get emailAddress => 'E-mailová adresa';
	@override String get linkAccount => 'Prepojiť účet';
	@override String get copiedCode => 'Kód skopírovaný do schránky';
	@override String get copyCode => 'Kopírovať kód';
	@override String codePrompt({required Object email}) => 'Otvorte aplikáciu Ham2K na zariadení, ktoré je už prepojené s ${email}, a zadajte tento kód na schválenie žiadosti:';
	@override String get waitingForConfirmation => 'Čaká sa na potvrdenie…';
	@override String get sendEmailInstead => 'Namiesto toho poslať potvrdzovací e-mail';
	@override String emailSent({required Object email}) => 'Na ${email} bol odoslaný e-mail. Otvorte ho a potvrďte žiadosť o prepojenie tohto zariadenia.';
	@override String get resendEmail => 'Znova odoslať e-mail';
	@override String get qrPrompt => 'Naskenujte tento QR kód zo zariadenia, ktoré je už prepojené s požadovaným účtom — napríklad pomocou Ham2K Portable Logger vo vašom telefóne.';
	@override String get serverUnreachable => 'Synchronizačný server je nedostupný. Skúste to neskôr.';
	@override String get emailRequired => 'Zadajte e-mailovú adresu na prepojenie.';
	@override String noAccountForEmail({required Object email}) => 'Pre ${email} sa nenašiel žiadny účet.';
	@override String serverRejected({required Object error}) => 'Synchronizačný server žiadosť odmietol: ${error}';
	@override String get noLinkCode => 'Synchronizačný server nevrátil kód na prepojenie. Skúste to neskôr.';
	@override String get noConfirmationCode => 'Synchronizačný server neposlal potvrdzovací kód. Skúste to neskôr.';
	@override String get switchNotAccepted => 'Tento účet prepnutie neprijal. Skúste ho namiesto toho prepojiť pomocou e-mailovej adresy.';
	@override String get requestFailed => 'Pri komunikácii so synchronizačným serverom sa niečo pokazilo. Skúste to neskôr.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} QSO',
		other: '${count} QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} prevádzka',
		other: '${count} prevádzok',
	);
}

// Path: adifImport
class _Translations$adifImport$sk extends Translations$adifImport$en {
	_Translations$adifImport$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importovať QSO z ADIF';
	@override String reading({required Object filename}) => 'Číta sa ${filename}…';
	@override String get dropHint => 'Pustite sem súbor ADIF a importuje sa';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} QSO v tomto súbore',
		other: '${formatted} QSO v tomto súbore',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} už je vo vašom denníku',
		other: '${formatted} už je vo vašom denníku',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} sa importuje',
		other: '${formatted} sa importuje',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} nové spojenie',
		other: '${formatted} nových spojení',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} sa zlúči s existujúcim spojením',
		other: '${formatted} sa zlúči s existujúcimi spojeniami',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} sa nedá importovať (bez volacieho znaku)',
		other: '${formatted} sa nedá importovať (bez volacieho znaku)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} si vyžaduje bližšiu kontrolu',
		other: '${formatted} si vyžaduje bližšiu kontrolu',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Referencie sa nepodarilo obnoviť pre ${count} spojenie',
		other: 'Referencie sa nepodarilo obnoviť pre ${formatted} spojení',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Referencie ${programs} môžu byť neúplné pre ${count} spojenie',
		other: 'Referencie ${programs} môžu byť neúplné pre ${formatted} spojení',
	);
	@override String get stackingTypesUnknown => 'Zlúčené spojenia môžu prísť o referenciu — aktivity nedokázali určiť, ktoré typy sa dajú kombinovať. Ak tomu chcete predísť, zrušte to a skúste znova.';
	@override String get nothingToImport => 'Z tohto súboru sa nedá nič importovať';
	@override String get confirm => 'Importovať';
	@override String importing({required Object filename}) => 'Importuje sa ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Importované ${count} spojenie z ${filename}',
		other: 'Importovaných ${formatted} spojení z ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => '${filename} sa nepodarilo importovať: ${error}';
	@override String notAdif({required Object filename}) => '${filename} nevyzerá ako súbor ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Upozornenie: tento ADIF obsahuje QSO od ${calls}, ale ak budete pokračovať, importujú sa ako ${station}.';
	@override String get stationCallJoin => ' a ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} nemá dátum a nedá sa importovať',
		other: '${formatted} nemá dátum a nedá sa importovať',
	);
	@override String activationFound({required Object refs}) => 'Tento súbor zaznamenáva aktiváciu ${refs}.';
	@override String get addActivation => 'Pridať ju do tejto prevádzky';
	@override String shortfall({required Object written, required Object planned}) => 'Uplatniť sa dalo iba ${written} z ${planned} — denník sa zmenil, kým ste sa rozhodovali.';
	@override String get busy => 'Import už prebieha. Pred spustením ďalšieho počkajte, kým sa dokončí.';
	@override String get oneFileOnly => 'Pustite naraz iba jeden súbor ADIF — poradie importu súborov rozhoduje, ktoré údaje majú prednosť.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} má viac ako ${limit} QSO, čo je maximum, ktoré prevádzka dokáže naraz importovať.';
}

// Path: offline
class _Translations$offline$sk extends Translations$offline$en {
	_Translations$offline$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: pripojené';
	@override String get noRoute => 'Žiadne sieťové pripojenie.';
	@override String get unreachable => 'Sieť funguje, ale žiadny server neodpovedá — často to znamená prihlasovaciu stránku čakajúcu v prehliadači.';
	@override String get reachable => 'Všetky služby odpovedajú podľa očakávania.';
	@override String get whatStops => 'Vyhľadávanie, spoty a dátové súbory sú pozastavené. Logovanie a synchronizácia v blízkosti nie.';
	@override String get servicesTitle => 'Služby';
	@override String get noServices => 'Zatiaľ sa neozvala žiadna služba.';
	@override String lastSuccess({required Object when}) => 'Naposledy odpovedala pred ${when}';
	@override String get neverSucceeded => 'Zatiaľ neodpovedala';
	@override String nextAttempt({required Object when}) => 'Ďalší pokus o ${when}';
	@override String get nextAttemptNow => 'Ďalší pokus na rade';
	@override String get retry => 'Skúsiť teraz';
	@override String get retrying => 'Skúša sa…';
	@override String get retryReached => 'Opäť online.';
	@override String get retryUnreachable => 'Stále bez odpovede.';
	@override String get retryNotAttempted => 'Momentálne nie je čo odoslať.';
	@override String get retryThrottled => 'Práve sa to skúšalo — chvíľu počkajte.';
	@override String get retryDisabled => 'Synchronizácia je vypnutá, takže nie je čím otestovať.';
	@override String get syncService => 'Synchronizácia Ham2K LoFi';
	@override String get retryInFlight => 'Už sa to skúša — vydržte.';
}

// Path: exportSettings
class _Translations$exportSettings$sk extends Translations$exportSettings$en {
	_Translations$exportSettings$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Základné nastavenia pre všetky exporty so samostatnými šablónami názvu súboru a titulu pre referenčné aktivity a ostatné aktivity. Každý typ exportu môže mať vlastné predvolené alebo vlastné nastavenia.';
	@override String get referenceActivities => 'Referenčné aktivity';
	@override String get otherActivities => 'Ostatné aktivity';
	@override String get adifFields => 'Polia ADIF';
	@override String get loadFailed => 'Nastavenia exportu sa nepodarilo načítať.';
	@override String get retry => 'Skúsiť znova';
	@override String get compactFileNamesDescriptionOn => 'Krátke názvy súborov, napríklad N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Popisné názvy súborov, napríklad 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Do súborov ADIF sa zahŕňajú mená, adresy, e-maily, poznámky a presné polohy.';
	@override String get includePrivateDataDescriptionOff => 'Vynechávajú sa mená, adresy, e-maily a poznámky; polohy sú obmedzené na 6-miestne lokátory.';
	@override String get includeLookupDataDescriptionOn => 'Zahŕňajú sa informácie zo služieb vyhľadávania volacích znakov.';
	@override String get includeLookupDataDescriptionOff => 'Vynechávajú sa informácie zo služieb vyhľadávania volacích znakov; ručne zadané hodnoty zostávajú.';
	@override String get customTemplatesDescriptionOn => 'Vaše vlastné šablóny sú aktívne a dajú sa upraviť nižšie.';
	@override String get customTemplatesDescriptionOff => 'Aktívne sú predvolené šablóny. Vaše vlastné šablóny zostávajú uložené na neskôr.';
	@override String get type => 'Typ exportu';
	@override String get defaults => 'Predvolené';
	@override String get includeLookupData => 'Zahrnúť údaje z vyhľadávania';
	@override String get customTemplates => 'Vlastné šablóny';
	@override String get filenameTemplate => 'Šablóna názvu súboru';
	@override String get compactFilenameTemplate => 'Šablóna krátkeho názvu súboru';
	@override String get titleTemplate => 'Šablóna titulu';
	@override String get adifNotesTemplate => 'ADIF QSO poznámky';
	@override String get adifCommentTemplate => 'ADIF QSO komentáre';
	@override String get adifQslMessageTemplate => 'ADIF QSL správa';
	@override String get shared => 'Nastavenia platia pre každé rozšírenie, ktoré používa tento typ exportu.';
	@override String get defaultTemplates => 'Ak chcete upraviť šablóny tohto typu, zapnite Vlastné šablóny.';
}

// Path: templateEditor
class _Translations$templateEditor$sk extends Translations$templateEditor$en {
	_Translations$templateEditor$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Náhľad:';
	@override String get reset => 'Obnoviť';
	@override String get docs => 'Dokumentácia šablón';
	@override String get preview => 'Ukážkový náhľad';
	@override String get reference => 'Referencia šablón';
	@override String get attributes => 'Dostupné atribúty';
	@override String get filters => 'Filtre';
	@override String get flowControl => 'Riadenie toku';
	@override String get unavailable => 'Náhľad nie je dostupný, kým nie sú rozšírenia pripravené.';
	@override String get empty => '(prázdny výstup)';
}

// Path: home.nav
class _Translations$home$nav$sk extends Translations$home$nav$en {
	_Translations$home$nav$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Prevádzky';
	@override String get chase => 'Lov';
	@override String get logs => 'Denníky';
	@override String get maps => 'Mapy';
	@override String get settings => 'Nastavenia';
}

// Path: home.panels
class _Translations$home$panels$sk extends Translations$home$panels$en {
	_Translations$home$panels$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Zoznam prevádzok';
	@override String get operationsDescription => 'Vaše prevádzky, najnovšie ako prvé.';
	@override String get version => 'Aktuálna verzia';
	@override String get versionDescription => 'Logo Ham2K, názov tejto aplikácie a zostava, ktorú používate.';
}

// Path: home.logs
class _Translations$home$logs$sk extends Translations$home$logs$en {
	_Translations$home$logs$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Denníky';
	@override String get titleFor => 'Denníky pre';
	@override String get emptyCallsigns => 'Zatiaľ žiadne zapísané QSO';
	@override String emptyQsos({required Object call}) => 'Žiadne QSO pre ${call}';
	@override String get mapNoSelection => 'Vyberte QSO a zobrazí sa na mape';
	@override String get searchHint => 'Hľadať volací znak alebo meno';
	@override String get noSearchMatches => 'Hľadaniu nezodpovedajú žiadne QSO';
	@override String get titleAll => 'Všetky denníky';
	@override String get allCallsigns => 'Všetky volacie znaky';
	@override String get noOperation => 'Nie je súčasťou prevádzky';
	@override String get unsavedTitle => 'Neuložené zmeny';
	@override String get unsavedBody => 'Toto QSO má zmeny, ktoré ste neuložili.';
	@override String get pendingDeleteBody => 'Toto QSO je označené na vymazanie.';
	@override String get editGone => 'Neuložené: toto QSO už nie je v tomto denníku.';
	@override String get discard => 'Zahodiť';
	@override late final _Translations$home$logs$columns$sk columns = _Translations$home$logs$columns$sk._(_root);
	@override late final _Translations$home$logs$panels$sk panels = _Translations$home$logs$panels$sk._(_root);
	@override late final _Translations$home$logs$import$sk import = _Translations$home$logs$import$sk._(_root);
}

// Path: chase.station
class _Translations$chase$station$sk extends Translations$chase$station$en {
	_Translations$chase$station$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Loviaca stanica';
	@override String get stationLabel => 'Stanica: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Bez polohy';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$sk extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get today => 'dnes';
	@override String get thisWeek => 'tento týždeň';
	@override String get last14Days => 'za posledných 14 dní';
	@override String get thisMonth => 'tento mesiac';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$sk extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get today => 'Štatistiky za dnes';
	@override String get thisWeek => 'Štatistiky za tento týždeň';
	@override String get last14Days => 'Štatistiky za posledných 14 dní';
	@override String get thisMonth => 'Štatistiky za tento mesiac';
}

// Path: chase.period
class _Translations$chase$period$sk extends Translations$chase$period$en {
	_Translations$chase$period$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get today => 'Dnes';
	@override String get thisWeek => 'Tento týždeň';
	@override String get last14Days => 'Posledných 14 dní';
	@override String get thisMonth => 'Tento mesiac';
}

// Path: chase.goals
class _Translations$chase$goals$sk extends Translations$chase$goals$en {
	_Translations$chase$goals$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ciele lovu';
	@override String remove({required Object name}) => 'Prestať loviť ${name}';
	@override String get extensionsTitle => 'Rozšírenia, ktoré zahŕňajú lov';
}

// Path: chase.panels
class _Translations$chase$panels$sk extends Translations$chase$panels$en {
	_Translations$chase$panels$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => 'Ovládanie logovania nad QSO ulovenými v danom období.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Logovaný volací znak alebo štatistiky za obdobie.';
	@override String get spots => 'Spoty';
	@override String get spotsDescription => 'Stanice spotované v éteri, pripravené na lov.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'QSO za obdobie a logovaná stanica.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$sk extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Neplatný volací znak: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Neplatné volacie znaky: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Doteraz vysielal ${previous}. Pre nové spojenia sa zapíše ${typed}.';
	@override String operatorNoneSoFar({required Object typed}) => 'Doteraz nie je zapísaný žiadny operátor. Pre nové spojenia sa zapíše ${typed}.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Táto prevádzka už má spojenia od ${calls}. ${typed} sa zapíše iba pre nové.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Zapísať ${typed} ako operátora aj pre už zapísané spojenie',
		other: 'Zapísať ${typed} ako operátora aj pre všetkých ${count} už zapísaných spojení',
	);
	@override String get operatorSeveralStations => 'Pri použití viacerých staníc v éteri nie sú samostatní operátori podporovaní';
	@override String get contactsUnreadable => 'Spojenia tejto prevádzky sa nepodarilo prečítať, preto zmena volacieho znaku tu neponúkne ich aktualizáciu';
	@override String restampFailed({required Object error}) => 'Už zapísané spojenia sa nepodarilo aktualizovať, preto sa nič nezmenilo: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => 'Aktualizovaných bolo ${written} z ${planned} spojení — ostatné už nie sú v tejto prevádzke';
}

// Path: operation.tabs
class _Translations$operation$tabs$sk extends Translations$operation$tabs$en {
	_Translations$operation$tabs$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTY';
	@override String get map => 'MAPA';
	@override String get qsosPlain => 'QSO';
	@override String get clock => 'Hodiny';
	@override String get weather => 'Počasie';
	@override String get website => 'Webová stránka';
	@override String get remoteScreen => 'Vzdialená obrazovka';
	@override String get solar => 'Slnko';
	@override String get radio => 'Rádio';
}

// Path: operation.positions
class _Translations$operation$positions$sk extends Translations$operation$positions$en {
	_Translations$operation$positions$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Túto prevádzku zatiaľ nezdieľajú žiadne iné operátorské pracoviská.';
	@override String positionLabel({required Object number}) => 'Prac.: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Iné pracovisko';
	@override String get thisDevice => 'Naše pracovisko';
	@override String get nameIn => ' v ';
	@override String get panelTitle => 'Pracoviská';
	@override String get panelDescription => 'Čo práve loguje každé pracovisko, ktoré zdieľa túto prevádzku.';
}

// Path: operation.menu
class _Translations$operation$menu$sk extends Translations$operation$menu$en {
	_Translations$operation$menu$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Zobraziť polia RST';
	@override String get showStateField => 'Zobraziť pole Štát';
	@override String get showGridField => 'Zobraziť pole Lokátor';
	@override String get showDeletedQsos => 'Zobraziť vymazané QSO';
	@override String get showDeletedOps => 'Zobraziť vymazané prevádzky';
	@override String get showQsoNumbers => 'Zobraziť čísla QSO';
	@override String get lookupAllQsos => 'Vyhľadať všetky QSO';
	@override String get loggingSettingsTitle => 'Nastavenia logovania';
	@override String get mapSettingsTitle => 'Nastavenia mapy';
	@override String get actionsSection => 'Akcie';
}

// Path: operation.layout
class _Translations$operation$layout$sk extends Translations$operation$layout$en {
	_Translations$operation$layout$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pridať panel';
	@override String get availableSection => 'Dostupné panely';
	@override String panelSettings({required Object panel}) => 'Nastavenia ${panel}';
	@override String get panelSettingsAction => 'Nastavenia panelu';
	@override String get viewName => 'Zobrazenie prevádzky';
	@override String get viewOptions => 'Možnosti rozloženia zobrazenia';
	@override String get viewTitleBuiltIn => 'Toto zobrazenie je vstavané v aplikácii, rovnako ako jeho názov';
	@override String get resetOptions => 'Obnoviť predvolené';
	@override String get removePane => 'Odstrániť';
	@override String resetPaneConfirm({required Object panel}) => 'Obnoviť predvolené nastavenia ${panel}?';
	@override String get resetPaneConfirmBody => 'Jeho názov, hlavička a veľkosť sa vrátia na predvolené. Zvyšok rozloženia zostane nezmenený.';
	@override String get resetViewConfirm => 'Obnoviť predvolené rozloženie tohto zobrazenia?';
	@override String get resetViewConfirmBody => 'Panely sa vrátia do predvoleného usporiadania a možnosti zobrazenia aj všetkých panelov sa vrátia na predvolené.';
	@override String paneOptionsTitle({required Object panel}) => 'Nastavenia rozloženia ${panel}';
	@override String get paneTitle => 'Názov';
	@override String get paneShowHeader => 'Zobraziť hlavičku';
	@override String get paneShowHeaderTabset => 'Vždy zobrazená, kým tento panel zdieľa skupinu — cez hlavičku sa dostanete k ostatným';
	@override String get paneInherit => 'Rovnako ako aplikácia';
	@override String get searchHint => 'Hľadať panely';
	@override String get noPanelsMatch => 'Hľadaniu nezodpovedá žiadny panel.';
	@override String get nothingToAdd => 'Toto zobrazenie už má všetky možné panely';
	@override String addPanel({required Object panel}) => 'Pridať ${panel}';
	@override String showPreview({required Object panel}) => 'Náhľad ${panel}';
	@override String missingExtension({required Object name}) => 'Chýba rozšírenie „${name}“';
	@override String get previewUnavailable => 'Obrázok náhľadu tohto panelu sa nepodarilo zobraziť.';
	@override String get nestedPaneTitle => 'Viac';
	@override String get editLayout => 'Upraviť rozloženie';
	@override String get saveLayout => 'Uložiť rozloženie';
	@override String get revertLayout => 'Zahodiť zmeny rozloženia';
	@override String get done => 'Hotovo';
	@override String get layoutUnreadableTitle => 'Rozloženie sa nepodarilo prečítať';
	@override String get layoutUnreadableBody => 'Vaše uložené rozloženie sa nepodarilo prečítať, preto sa namiesto neho zobrazuje predvolené usporiadanie. Pôvodné rozloženie sa neprepíše, kým sa nerozhodnete toto ponechať.';
	@override String get layoutUnreadableAction => 'Použiť toto rozloženie';
	@override String panelRenderFailed({required Object panel}) => '${panel} sa nepodarilo zobraziť';
	@override String get panelRenderRetry => 'Skúsiť znova';
	@override String get panelActionFailed => 'Akcia panelu zlyhala. Skúste to znova.';
	@override late final _Translations$operation$layout$panels$sk panels = _Translations$operation$layout$panels$sk._(_root);
	@override String get htmlPanelUnsupported => 'Tento panel potrebuje webové zobrazenie, ktoré táto platforma neposkytuje';
	@override String get htmlPanelUnsupportedOnWeb => 'Tento panel potrebuje izolované prostredie, ktoré webová verzia nedokáže poskytnúť';
}

// Path: operation.export
class _Translations$operation$export$sk extends Translations$operation$export$en {
	_Translations$operation$export$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporty prevádzky';
	@override String get syncedOperation => 'Prevádzka je synchronizovaná';
	@override String get unsyncedOperation => 'Prevádzka má nesynchronizované zmeny';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} QSO v tejto prevádzke',
		other: '${count} QSO v tejto prevádzke',
	);
	@override String qsosSynced({required Object total}) => 'Všetky QSO (${total}) sú synchronizované';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} z ${total} QSO čaká na synchronizáciu';
	@override String eventsSynced({required Object total}) => 'Synchronizované značky udalostí: ${total}';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} z ${total} značiek udalostí čaká';
	@override String get loading => 'Načítavajú sa možnosti exportu…';
	@override String get noOptions => 'Nie sú dostupné žiadne formáty exportu (prostredie rozšírení sa ešte spúšťa?)';
	@override String get nothingLogged => 'Zatiaľ nie je čo exportovať — táto prevádzka nemá žiadne QSO.';
	@override String get share => 'Zdieľať';
	@override String get nothingSelected => 'Nič nie je vybrané';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Uložiť ${count} súbor',
		other: 'Uložiť ${count} súborov',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Zdieľať ${count} súbor',
		other: 'Zdieľať ${count} súborov',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Exportovať ${count} súbor',
		other: 'Exportovať ${count} súborov',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Stiahnuť ${count} súbor',
		other: 'Stiahnuť ${count} súborov',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Uložiť ${count} zlúčený súbor',
		other: 'Uložiť ${count} zlúčených súborov',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Zdieľať ${count} zlúčený súbor',
		other: 'Zdieľať ${count} zlúčených súborov',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Exportovať ${count} zlúčený súbor',
		other: 'Exportovať ${count} zlúčených súborov',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Stiahnuť ${count} zlúčený súbor',
		other: 'Stiahnuť ${count} zlúčených súborov',
	);
	@override String saveOne({required Object name}) => 'Uložiť ${name}';
	@override String shareOne({required Object name}) => 'Zdieľať ${name}';
	@override String exportOne({required Object name}) => 'Exportovať ${name}';
	@override String downloadOne({required Object name}) => 'Stiahnuť ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Uschovať ${count} súbor',
		other: 'Uschovať ${count} súborov',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Uschovať ${count} zlúčený súbor',
		other: 'Uschovať ${count} zlúčených súborov',
	);
	@override String get settingsButton => 'Nastavenia exportu';
	@override String get settingsTitle => 'Nastavenia exportu';
	@override late final _Translations$operation$export$compactFileNames$sk compactFileNames = _Translations$operation$export$compactFileNames$sk._(_root);
	@override late final _Translations$operation$export$includePrivateData$sk includePrivateData = _Translations$operation$export$includePrivateData$sk._(_root);
	@override String get resultTitle => 'Export dokončený';
	@override String get resultFailedTitle => 'Export zlyhal';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Exportovaný ${count} súbor do ${path}',
		other: 'Exportovaných ${count} súborov do ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Exportovaný ${count} súbor: ${path}',
		other: 'Exportovaných ${count} súborov: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Zdieľaný ${count} súbor',
		other: 'Zdieľaných ${count} súborov',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Stiahnutý ${count} súbor',
		other: 'Stiahnutých ${count} súborov',
	);
	@override String exportFailed({required Object error}) => 'Export zlyhal: ${error}';
	@override late final _Translations$operation$export$stash$sk stash = _Translations$operation$export$stash$sk._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$sk extends Translations$operation$spots$en {
	_Translations$operation$spots$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Vašim filtrom nezodpovedajú žiadne spoty';
	@override String error({required Object error}) => 'Spoty sa nepodarilo načítať: ${error}';
	@override String get unknownBand => 'Iné';
	@override String get auto => 'Automaticky';
	@override String autoValue({required Object value}) => 'Automaticky (momentálne ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Akékoľvek';
	@override String get allBands => 'Všetky pásma';
	@override String get allModes => 'Všetky módy';
	@override String get phoneAndCw => 'Phone a CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} spot',
		other: '${count} spotov',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Zobrazuje sa ${count} z ${total} spotov';
	@override String ageMinutes({required Object minutes}) => '${minutes} minút';
	@override String get callsOfNote => 'Poznámky k volacím znakom';
	@override String get yourSpots => 'Vaše spoty';
	@override String get allSpots => 'Všetky spoty';
	@override late final _Translations$operation$spots$continents$sk continents = _Translations$operation$spots$continents$sk._(_root);
	@override late final _Translations$operation$spots$filters$sk filters = _Translations$operation$spots$filters$sk._(_root);
	@override String get unavailableTitle => 'Spoty nie sú dostupné';
	@override String unavailableText({required Object sources}) => '${sources} neodpovedali.';
	@override String get failedTitle => 'Chyba zdroja spotov';
	@override String failedText({required Object sources}) => '${sources} vrátili chybu.';
	@override String get slideLogIt => 'Zapísať';
	@override String get slideIgnore => 'Ignorovať';
	@override String get slideRestore => 'Obnoviť';
	@override late final _Translations$operation$spots$logConflict$sk logConflict = _Translations$operation$spots$logConflict$sk._(_root);
}

// Path: operation.import
class _Translations$operation$import$sk extends Translations$operation$import$en {
	_Translations$operation$import$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importovať údaje do prevádzky';
	@override String get importAdifAction => 'Importovať QSO z ADIF';
	@override String get settingsButton => 'Nastavenia počúvania';
	@override String get settingsTitle => 'Počúvať iné aplikácie';
	@override String get protocolAddressLabel => 'Adresa';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Zadajte port od 1 do 65535';
	@override String get protocolAddressInvalid => 'Zadajte platnú IP adresu (napr. 127.0.0.1 alebo 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Prijímajú sa údaje';
	@override String get protocolStatusNoData => 'V poslednom čase neprišli žiadne údaje';
	@override String protocolBindError({required Object error}) => 'Počúvanie sa nepodarilo spustiť: ${error}';
	@override String captureFailed({required Object error}) => 'Prichádzajúce QSO sa nepodarilo uložiť a skúša sa to znova: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Akákoľvek (broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → karta Broadcast Data → zaškrtnite "Enable Broadcasts" pre informácie o spojeniach. Nastavte IP adresu na 127.0.0.1, ak beží na tom istom počítači, alebo na 255.255.255.255 pre broadcast v aktuálnej lokálnej sieti.';
	@override String get helpWsjtxSetup => 'File → Settings → karta Reporting → sekcia UDP Server → zaškrtnite "Accept UDP requests". Nastavte UDP Server na 127.0.0.1, ak beží na tom istom počítači, alebo na multicastovú adresu, napr. 239.239.0.2, a rovnakú adresu použite v konfigurácii vyššie v tejto aplikácii.';
	@override String get listenTitle => 'Počúvať QSO z iných aplikácií';
	@override String get listenDescriptionOnN1mm => 'Počúva sa N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Počúva sa WSJT-X';
	@override String get listenDescriptionOnBoth => 'Počúva sa N1MM+ a WSJT-X';
	@override String get listenDescriptionOff => 'Vypnuté';
	@override String get addToOperationTitle => 'Pridať do tejto prevádzky';
	@override String get addToOperationDescriptionOn => 'Zachytené QSO sa pridávajú do tejto prevádzky hneď, ako prídu';
	@override String get addToOperationDescriptionOff => 'Zachytené QSO sa podržia, kým toto nezapnete';
	@override String get pendingSectionTitle => 'Zachytené QSO';
	@override String get pendingEmpty => 'Zatiaľ nič nezachytené';
	@override String stationMismatch({required Object call}) => 'Zapísané ako ${call}, nie stanica tejto prevádzky';
	@override String get discardAction => 'Zahodiť';
	@override String get gapDialogTitle => 'Zahrnúť staršie záznamy?';
	@override String gapDialogBody({required Object count}) => 'Pred medzerou v údajoch bolo zachytených ešte ${count} QSO. Zahrnúť aj tie?';
	@override String get gapDialogRecentOnly => 'Iba nedávne';
	@override String gapDialogIncludeAll({required Object count}) => 'Zahrnúť všetky (${count})';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$sk extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problémy?';
	@override String get title => 'Nahlásiť problém s obrysom';
	@override String get reference => 'Ktorý obrys';
	@override String get severity => 'Aké vážne to je?';
	@override String get minor => 'Drobnosť';
	@override String get major => 'Vážny problém';
	@override String get explanation => 'Čo je na ňom zlé?';
	@override String get explanationHint => 'Čo obrys zobrazuje nesprávne a kde';
	@override String get send => 'Odoslať';
	@override String get sending => 'Odosiela sa vaše hlásenie — ďakujeme';
	@override String get copy => 'Kopírovať hlásenie';
	@override String get notSent => 'Hlásenie sa nepodarilo odoslať';
	@override String get copied => 'Hlásenie skopírované';
	@override String get notCopied => 'Hlásenie sa nepodarilo skopírovať';
}

// Path: map.postcard
class _Translations$map$postcard$sk extends Translations$map$postcard$en {
	_Translations$map$postcard$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get button => 'Pohľadnica z prevádzky';
	@override String title({required Object title}) => 'Pohľadnica pre ${title}';
	@override String get portrait => 'Na výšku';
	@override String get landscape => 'Na šírku';
	@override String get square => 'Štvorec';
	@override String get save => 'Uložiť…';
	@override String get download => 'Stiahnuť';
	@override String get share => 'Zdieľať';
	@override String get copy => 'Kopírovať';
	@override String get copied => 'Skopírované do schránky';
	@override String saved({required Object path}) => 'Uložené do ${path}';
	@override String downloaded({required Object name}) => 'Stiahnuté ${name}';
	@override String savedMany({required Object count, required Object path}) => 'Obrázky (${count}) uložené do ${path}';
	@override String savedFiles({required Object names}) => 'Uložené ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} už boli uložené';
	@override String downloadedMany({required Object count}) => 'Sťahuje sa ${count} obrázkov — povoľte ich, ak sa prehliadač opýta';
	@override String get mapLeftOut => 'Mapa sa nenačítala, preto bola vynechaná';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — mapa sa nenačítala, preto bola vynechaná';
	@override String continued({required Object title}) => '${title} (pokračovanie)';
	@override String get previousPage => 'Predchádzajúca strana';
	@override String get nextPage => 'Ďalšia strana';
	@override String pageOf({required Object page, required Object count}) => 'Strana ${page} z ${count}';
	@override String get sectionDays => 'Každý deň';
	@override String get reset => 'Obnoviť';
	@override String failed({required Object error}) => 'Pohľadnicu sa nepodarilo vytvoriť: ${error}';
	@override String get mapNotReady => 'Mapa sa nestihla načítať. Skontrolujte pripojenie a skúste to znova.';
	@override String saveFailed({required Object error}) => 'Pohľadnicu sa nepodarilo uložiť: ${error}';
	@override String get copyFailed => 'Schránka obrázok neprijala. Skúste to znova.';
	@override String get shareFailed => 'Pohľadnicu sa nepodarilo zdieľať. Skúste to znova.';
	@override String get fileName => 'pohladnica';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$sk extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Zatiaľ žiadne QSO... poďme do éteru!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object count, required Object time}) => '${count} za ${time}';
	@override String sinceLast({required Object time}) => '${time} od posledného';
	@override String ratePer10({required Object rate}) => '${rate} Q/h pre posledných 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h pre posledných 100';
	@override String distanceTo({required Object distance}) => '${distance} do';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) do';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) do';
	@override String distanceAway({required Object distance}) => '${distance} ďaleko';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) ďaleko';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) ďaleko';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplikát!';
	@override String get noticeNewBand => 'Nové pásmo';
	@override String get noticeNewMode => 'Nový mód';
	@override String get noticeNewDXCC => 'Nové DXCC';
	@override String get noticeNewState => 'Nový štát';
	@override String get noticeNewProvince => 'Nová provincia';
	@override String get noticeNewDay => 'Nový deň';
	@override String get noticeNewRef => 'Nová ref.';
	@override String get noticeNewMult => 'Nový násobič';
	@override String get noticeNewZone => 'Nová zóna';
	@override String get noticeInvalidMode => 'Zlý mód';
	@override String get noticeInvalidBand => 'Zlé pásmo';
	@override String get noticeInvalidCategory => 'Nedá sa pracovať';
	@override String get noticeWorkedBefore => 'Už robené';
	@override String get noticeNewPark => 'Nový park';
	@override String get noticeNewSection => 'Nová sekcia';
	@override String get noticeBonusStation => 'Bonusová stanica!';
	@override String get noticeMissingExchange => 'Bez výmeny';
	@override String get noticeInvalidExchange => 'Zlá výmena';
	@override String get noticeUnknownEvent => 'Neznáma udalosť';
	@override String get noticeOurGrid => 'Nastavte náš lokátor';
	@override String get noticeRareCounty => 'Vzácny kraj!';
	@override String get noticeOurLocation => 'Nastavte náš kraj';
	@override String get noticeShortGrid => 'Lokátor je príliš krátky';
}

// Path: callInfo.history
class _Translations$callInfo$history$sk extends Translations$callInfo$history$en {
	_Translations$callInfo$history$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} za posledných 7 dní';
	@override String today({required Object n}) => '${n} dnes';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$sk extends Translations$settings$theme$en {
	_Translations$settings$theme$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Režim témy';
	@override String get system => 'Podľa nastavení systému';
	@override String get light => 'Svetlý';
	@override String get dark => 'Tmavý';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$sk extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get system => 'Podľa nastavení systému';
	@override String get light => 'Vždy v svetlom režime';
	@override String get dark => 'Vždy v tmavom režime';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$sk extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Najmenšia--';
	@override String get smallestMinus => 'Najmenšia-';
	@override String get smallest => 'Najmenšia';
	@override String get smaller => 'Menšia';
	@override String get normal => 'Normálna';
	@override String get larger => 'Väčšia';
	@override String get largest => 'Najväčšia';
	@override String get largestPlus => 'Najväčšia+';
	@override String get largestPlusPlus => 'Najväčšia++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$sk extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Udržiavať zariadenie aktívne';
	@override String get descriptionOn => 'Zariadenie zostáva aktívne, kým ste v zobrazení logovania alebo prebieha synchronizácia';
	@override String get descriptionOff => 'Zariadenie sa uspáva ako zvyčajne';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$sk extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatická';
	@override String get densest => 'Najhustejšia';
	@override String get dense => 'Hustá';
	@override String get normal => 'Normálna';
	@override String get sparse => 'Riedka';
	@override String get sparsest => 'Najriedkejšia';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$sk extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometre';
	@override String get miles => 'Míle';
}

// Path: settings.logging
class _Translations$settings$logging$sk extends Translations$settings$logging$en {
	_Translations$settings$logging$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logovanie';
	@override late final _Translations$settings$logging$leftieMode$sk leftieMode = _Translations$settings$logging$leftieMode$sk._(_root);
	@override late final _Translations$settings$logging$countryFlags$sk countryFlags = _Translations$settings$logging$countryFlags$sk._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$sk countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$sk._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$sk suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$sk._(_root);
	@override late final _Translations$settings$logging$showBearing$sk showBearing = _Translations$settings$logging$showBearing$sk._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$sk showReverseBearing = _Translations$settings$logging$showReverseBearing$sk._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$sk switchSentRcvd = _Translations$settings$logging$switchSentRcvd$sk._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$sk jumpAfterRST = _Translations$settings$logging$jumpAfterRST$sk._(_root);
	@override late final _Translations$settings$logging$defaultReport$sk defaultReport = _Translations$settings$logging$defaultReport$sk._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$sk defaultReportCW = _Translations$settings$logging$defaultReportCW$sk._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$sk defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$sk._(_root);
	@override late final _Translations$settings$logging$numbersRow$sk numbersRow = _Translations$settings$logging$numbersRow$sk._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$sk numbersRowExtra = _Translations$settings$logging$numbersRowExtra$sk._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$sk numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$sk._(_root);
	@override String get bands => 'Preferované pásma';
	@override String get modes => 'Preferované módy';
}

// Path: settings.catServer
class _Translations$settings$catServer$sk extends Translations$settings$catServer$en {
	_Translations$settings$catServer$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT server';
	@override String get description => 'Umožniť iným aplikáciám (WSJT-X, logovacie programy atď.) ovládať rádiostanicu cez Ham2K Logger.';
	@override String get protocol => 'Protokol';
	@override late final _Translations$settings$catServer$protocolOpts$sk protocolOpts = _Translations$settings$catServer$protocolOpts$sk._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Otvorený prístup';
	@override String get openAccessOn => 'Pripojiť sa môže ľubovoľný počítač v lokálnej sieti.';
	@override String get openAccessOff => 'Pripojiť sa môžu iba aplikácie na tomto počítači.';
	@override String get off => 'Vypnuté.';
	@override String starting({required Object protocol}) => '${protocol}, spúšťa sa…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} na porte ${port}. Pripojení klienti: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} na porte ${port}, ale nie je pripojená žiadna rádiostanica Hlavného VFO.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} nemôže počúvať na porte ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} nemôže počúvať na porte ${port}: používa ho iný program, často samotný ${protocol}. Zatvorte tento program alebo vyberte iný port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} nemôže počúvať na porte ${port}: tento počítač to nepovoľuje. Vyberte port nad 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} prestal počúvať na porte ${port}. Skúša sa znova…';
}

// Path: settings.radio
class _Translations$settings$radio$sk extends Translations$settings$radio$en {
	_Translations$settings$radio$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ovládanie CAT';
	@override String get loggingAndCat => 'Logovanie a CAT';
	@override String get tuningSection => 'Ladenie';
	@override String get keyerSection => 'Kľúčovač';
	@override String get servicesSection => 'Služby';
	@override String get stationConfigurationSection => 'Konfigurácia stanice';
	@override String get moreSettings => 'Ďalšie nastavenia konfigurácie stanice';
	@override late final _Translations$settings$radio$units$sk units = _Translations$settings$radio$units$sk._(_root);
	@override late final _Translations$settings$radio$pttKey$sk pttKey = _Translations$settings$radio$pttKey$sk._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$sk smartVfoSnap = _Translations$settings$radio$smartVfoSnap$sk._(_root);
	@override late final _Translations$settings$radio$snapDebounce$sk snapDebounce = _Translations$settings$radio$snapDebounce$sk._(_root);
	@override late final _Translations$settings$radio$snapLongMove$sk snapLongMove = _Translations$settings$radio$snapLongMove$sk._(_root);
	@override late final _Translations$settings$radio$snapMinMove$sk snapMinMove = _Translations$settings$radio$snapMinMove$sk._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$sk snapMinSpeed = _Translations$settings$radio$snapMinSpeed$sk._(_root);
	@override late final _Translations$settings$radio$enterSends$sk enterSends = _Translations$settings$radio$enterSends$sk._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$sk keyerSpeed = _Translations$settings$radio$keyerSpeed$sk._(_root);
	@override late final _Translations$settings$radio$cwMessages$sk cwMessages = _Translations$settings$radio$cwMessages$sk._(_root);
	@override late final _Translations$settings$radio$voiceMessages$sk voiceMessages = _Translations$settings$radio$voiceMessages$sk._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$sk avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$sk._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$sk zeroBeatRange = _Translations$settings$radio$zeroBeatRange$sk._(_root);
}

// Path: settings.help
class _Translations$settings$help$sk extends Translations$settings$help$en {
	_Translations$settings$help$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pomoc a zdroje';
	@override String get description => 'Komunita a podpora';
	@override String get forums => 'Fóra Ham2K';
	@override String get forumsDescription => 'Nájdite pomoc, dajte spätnú väzbu, diskutujte o nápadoch…';
	@override String get chat => 'Ham2K Chat';
	@override String get chatDescription => 'Discord server pre našu online komunitu';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videá a živé vysielania';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Pretože nikdy nemôžete mať príliš veľa fotiek…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Sledujte nás pre novinky a aktualizácie';
	@override String get contact => 'Kontaktujte nás';
	@override String get contactDescription => 'help@ham2k.com — ale najprv skúste Fóra alebo Chat!';
}

// Path: settings.exports
class _Translations$settings$exports$sk extends Translations$settings$exports$en {
	_Translations$settings$exports$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporty';
}

// Path: settings.map
class _Translations$settings$map$sk extends Translations$settings$map$en {
	_Translations$settings$map$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapy';
	@override late final _Translations$settings$map$style$sk style = _Translations$settings$map$style$sk._(_root);
	@override late final _Translations$settings$map$styleOpts$sk styleOpts = _Translations$settings$map$styleOpts$sk._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$sk extends Translations$settings$privacy$en {
	_Translations$settings$privacy$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Súkromie';
	@override late final _Translations$settings$privacy$shareAppData$sk shareAppData = _Translations$settings$privacy$shareAppData$sk._(_root);
	@override late final _Translations$settings$privacy$shareOpData$sk shareOpData = _Translations$settings$privacy$shareOpData$sk._(_root);
	@override String get privacyPolicy => 'Zásady ochrany osobných údajov';
	@override String get termsOfService => 'Podmienky služby';
}

// Path: settings.sync
class _Translations$settings$sync$sk extends Translations$settings$sync$en {
	_Translations$settings$sync$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cloudová synchronizácia';
	@override String get moreSettings => 'Ďalšie nastavenia synchronizácie';
	@override String get enable => 'Povoliť synchronizáciu';
	@override String get deviceKey => 'Kľúč zariadenia';
}

// Path: settings.peers
class _Translations$settings$peers$sk extends Translations$settings$peers$en {
	_Translations$settings$peers$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partnerské zariadenia';
	@override String get enable => 'Pripájať sa k iným zariadeniam';
	@override String get enableDescription => 'Povoliť zdieľanie prevádzok, logovania, CAT a GPS s inými zariadeniami cez lokálnu sieť';
	@override String get bleEnable => 'Pripájať sa cez Bluetooth';
	@override String get bleDescription => 'Použiť Bluetooth LE na pripojenie, aj keď nie je dostupná lokálna sieť';
	@override String get thisDevice => 'Toto zariadenie';
	@override String get deviceName => 'Názov';
	@override String get deviceNameHint => 'Ako toto zariadenie vidia iné zariadenia';
	@override String get pairedDevices => 'Prepojené zariadenia';
	@override String get noPairedDevices => 'Zatiaľ žiadne prepojené zariadenia. Zapnite túto funkciu na inom zariadení v tejto sieti a prepojte ich.';
	@override String deviceListProblem({required Object error}) => 'Prepojené zariadenia sa nedajú načítať: ${error}';
	@override String get nearby => 'V blízkosti';
	@override String get connected => 'Pripojené';
	@override String get viaBluetooth => 'cez Bluetooth';
	@override String get connecting => 'Pripája sa…';
	@override String get syncing => 'Synchronizuje sa…';
	@override String get waitingForThem => 'Čaká sa na druhé zariadenie';
	@override String get notConnected => 'Nepripojené';
	@override String get wantsToPair => 'chce zdieľať túto prevádzku';
	@override String get allow => 'Povoliť';
	@override String get link => 'Prepojiť';
	@override String get reject => 'Odmietnuť';
	@override String get forget => 'Zabudnúť';
	@override String forgetTitle({required Object name}) => 'Zabudnúť ${name}?';
	@override String get forgetBody => 'Prestane sa synchronizovať s týmto zariadením. Neskôr ho môžete znova povoliť a už zapísané spojenia zostanú zachované.';
	@override String pairTitle({required Object name}) => 'Prepojiť s ${name}';
	@override String get pairBody => 'Toto zariadenie je vo vašej lokálnej sieti a chce sa pripojiť.';
	@override String get pairBodyBle => 'Toto zariadenie je v blízkosti a chce sa pripojiť cez Bluetooth LE.';
	@override String get pairIdLabel => 'ID zariadenia';
	@override String get pairWarning => 'Prepájajte iba so zariadeniami, ktoré poznáte. Žiadosť môže poslať ľubovoľné zariadenie v tejto sieti.';
	@override String get pairWarningBle => 'Prepájajte iba so zariadeniami, ktoré poznáte. Žiadosť môže poslať ľubovoľné zariadenie v blízkosti.';
	@override String problem({required Object error}) => 'Lokálna sieť je nedostupná: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Pripojené k ${device}';
	@override String statusLost({required Object device}) => 'Stratené spojenie s ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Partnerské zariadenia: pripojené ${connected} z ${linked}';
	@override String get screenEnable => 'Zdieľať obrazovky a okná';
	@override String get screenDescription => 'Povoliť iným zariadeniam zobrazovať obrazovky alebo okná z tohto počítača';
	@override String get screenSources => 'Obrazovky a okná';
	@override String get screenRefresh => 'Obnoviť zoznam';
	@override String get screenUnsupportedPlatform => 'Toto zariadenie nemôže zdieľať svoju obrazovku. macOS to dokáže; každé zariadenie môže zobraziť obrazovku zdieľanú iným.';
	@override String get screenUnsupportedVersion => 'Zdieľanie obrazovky vyžaduje macOS 12.3 alebo novší. Toto zariadenie môže stále zobraziť obrazovku zdieľanú iným.';
	@override String get screenNeedsPermission => 'macOS potrebuje vaše povolenie na nahrávanie obrazovky, aby ju táto aplikácia mohla zdieľať.';
	@override String get screenGrantPermission => 'Požiadať o povolenie';
	@override String get screenRelaunchAfterGranting => 'Povoľte to v Systémových nastaveniach v časti Súkromie a bezpečnosť → Nahrávanie obrazovky, potom túto aplikáciu ukončite a znova otvorte — macOS informuje aplikáciu o zmene až pri ďalšom spustení.';
	@override String screenProblem({required Object error}) => 'Zdieľanie obrazovky: ${error}';
	@override String get screenChooseTitle => 'Vyberte, čo zdieľať';
	@override String get screenChooseButton => 'Vybrať, čo zdieľať…';
	@override String get screenTabScreens => 'Obrazovky';
	@override String get screenTabApps => 'Aplikácie';
	@override String get screenTabWindows => 'Okná';
	@override String get screenTabEmpty => 'Nič také sa nenašlo.';
	@override String get screenSharedSummaryNone => 'Zatiaľ nič nie je vybrané.';
	@override String get screenThisDevice => 'Toto zariadenie';
	@override String screenSharedTo({required Object devices}) => 'Zobrazené na ${devices}';
	@override String get screenSharedToNobody => 'Nezobrazuje sa';
	@override String screenStopSharing({required Object name}) => 'Prestať zdieľať ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$sk extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Konfigurácia synchronizácie';
	@override String get enableTitle => 'Synchronizovať s Ham2K Log Filer';
	@override String get enabledDescription => 'Váš denník sa zálohuje a synchronizuje medzi zariadeniami';
	@override String get disabledDescription => 'Vypnuté — zostáva iba na tomto zariadení';
	@override String get syncing => 'Synchronizácia';
	@override String get account => 'Účet';
	@override String get refresh => 'Obnoviť';
	@override String get switchAccounts => 'Prepnúť účty';
	@override String get switchAccountsDescription => 'Prepojiť toto zariadenie s iným účtom pomocou QR kódu alebo e-mailu';
	@override String get connectionRequests => 'Žiadosti o pripojenie';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Jedno zariadenie čaká na pripojenie k tomuto účtu',
		other: '${n} zariadení čaká na pripojenie k tomuto účtu',
	);
	@override String get accountEmailTitle => 'E-mail účtu';
	@override String accountEmailSent({required Object email}) => 'Potvrdenie bolo odoslané na ${email}. Zmenu dokončíte otvorením odkazu v ňom.';
	@override String get resendConfirmation => 'Znova odoslať potvrdzovací e-mail';
	@override String resendConfirmationDescription({required Object email}) => 'Čaká sa na ${email}';
	@override String accountEmailResent({required Object email}) => 'Znova odoslané na ${email}.';
	@override String get deviceLinked => 'Toto zariadenie je teraz prepojené s týmto účtom.';
	@override String get checking => 'Kontroluje sa…';
	@override String get notLinked => 'Zatiaľ neprepojené';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Nahradiť lokálne údaje?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${n} prevádzka',
		other: '${n} prevádzok',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
	@override String get counts => 'Synchronizované údaje';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Toto zariadenie: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Čaká na nahratie: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Toto zariadenie: kontroluje sa…';
	@override String get countsServerChecking => 'Server: kontroluje sa…';
	@override String get countsServerUnavailable => 'Server: nedostupný';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Týmto sa zálohuje a vymaže ${operations} a ${qsos} z tohto zariadenia a namiesto toho sa stiahnu údaje účtu. Záloha zostane v databáze tohto zariadenia.';
	@override String get replace => 'Nahradiť';
	@override String get pendingBannerTitle => 'Zistený nový účet Ham2K Log Filer';
	@override String get pendingBannerBody => 'Ponechajte existujúce prevádzky a QSO tohto zariadenia a zlúčte ich do účtu, alebo ich nahraďte údajmi účtu (záloha zostane na tomto zariadení v oboch prípadoch).';
	@override String get combine => 'Skombinovať';
	@override String get authIssueTitle => 'Synchronizácia sa nemôže pripojiť';
	@override String get authIssueText => 'Ham2K Log Filer stále odmieta toto zariadenie. Skontrolujte svoj volací znak v nastaveniach synchronizácie.';
	@override String get openSettings => 'Otvoriť nastavenia synchronizácie';
}

// Path: settings.accounts
class _Translations$settings$accounts$sk extends Translations$settings$accounts$en {
	_Translations$settings$accounts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Účty, služby a zdroje údajov';
	@override String get none => 'Žiadne aktívne rozšírenia s účtami';
	@override String get notConfigured => 'Nenakonfigurované';
	@override String get connected => 'Pripojené';
	@override String get cancelLogin => 'Zrušiť prihlásenie';
	@override String get openInBrowser => 'Otvoriť v prehliadači';
	@override String loggedInAs({required Object identity}) => 'Prihlásený ako ${identity}';
	@override String get pressSaveToKeep => 'Stlačte Uložiť, aby tento účet zostal pripojený.';
	@override String connectedTo({required Object label}) => 'Pripojené k ${label}';
	@override String get connect => 'Pripojiť';
	@override String get disconnect => 'Odpojiť';
	@override String get connectedAs => 'Pripojený ako';
	@override String get test => 'Test';
	@override String saveFailed({required Object error}) => 'Uloženie zlyhalo: ${error}';
	@override String loginFailed({required Object error}) => 'Prihlásenie zlyhalo: ${error}';
	@override String get lookupFailed => 'Účty momentálne nie sú dostupné — skúste to o chvíľu znova';
	@override String get browserLoginTitle => 'Dokončite prihlásenie vo webovom prehliadači';
	@override String browserLoginSteps({required Object prefix}) => 'Keď skončíte, prehliadač sa pokúsi otvoriť odkaz začínajúci na "${prefix}". Váš počítač ho pravdepodobne nemá čím otvoriť, preto tento odkaz skopírujte (z panela s adresou alebo z chybovej stránky, ktorú prehliadač zobrazí) a vložte ho sem.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger nedokázal otvoriť váš prehliadač. Skopírujte prihlasovací odkaz nižšie a otvorte ho sami, potom skopírujte odkaz, na ktorý vás presmeruje (začína na "${prefix}"), a vložte ho sem.';
	@override String get copyLoginLink => 'Kopírovať prihlasovací odkaz';
	@override String get pastedLinkLabel => 'Sem vložte odkaz';
	@override String get finishLogin => 'Dokončiť prihlásenie';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Toto nie je prihlasovací odkaz — mal by začínať na "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Tento odkaz patrí k inému pokusu o prihlásenie. Zatvorte túto stránku a pripojte sa znova.';
	@override String get pastedLinkNoCode => 'Tento odkaz neobsahuje prihlasovací kód. Najprv dokončite prihlásenie a potom skopírujte odkaz, na ktorý vás presmeruje.';
	@override String get pastedLinkMalformed => 'Tento odkaz vyzerá orezaný. Skopírujte ho celý a vložte znova.';
	@override String get relayLoginWaiting => 'Čaká sa, kým dokončíte prihlásenie — potom sa automaticky pokračuje.';
	@override String get loginNoResponse => 'Toto zariadenie zatiaľ nedostalo odpoveď z prihlásenia. Ak ste ho už v prehliadači dokončili, zrušte to a skúste sa pripojiť znova.';
	@override String get relayLoginNotOpened => 'Ham2K Logger nedokázal automaticky otvoriť váš prehliadač. Prihlasovaciu stránku otvorte sami tlačidlom nižšie.';
	@override String get relayLoginUnavailable => 'Synchronizačný server potrebný na dokončenie prihlásenia je nedostupný. Skontrolujte pripojenie a skúste to znova.';
	@override String get loginIncompleteResponse => 'Tento pokus o prihlásenie sa správne nedokončil. Skúste sa pripojiť znova.';
	@override String get noKeyringTitle => 'Prihlásenia k účtom sa nedajú uložiť';
	@override String get noKeyringText => 'Ham2K Logger nemá prístup k službe kľúčenky na tomto počítači, takže prihlásenia k účtom sa nedajú uložiť ani načítať — pripojenie účtu zlyhá, kým sa to nevyrieši. Nainštalujte a spustite **gnome-keyring**, **KWallet** alebo **KeePassXC**, alebo odomknite kľúčenku, ktorú už máte, a potom reštartujte. Logovanie, exporty a dátové súbory nie sú ovplyvnené; synchronizácia denníka zostane počas tejto doby vypnutá.';
	@override String get noKeyringInline => 'Prihlásenia sa nedajú uložiť: kľúčenka tohto počítača je nedostupná. Nainštalujte a spustite gnome-keyring, KWallet alebo KeePassXC, alebo odomknite tú, ktorú máte.';
	@override String get noSecureStorageInline => 'Prihlásenia sa nedajú uložiť: zabezpečené úložisko tohto počítača je nedostupné.';
}

// Path: settings.station
class _Translations$settings$station$sk extends Translations$settings$station$en {
	_Translations$settings$station$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Konfigurácia stanice a ovládanie CAT';
	@override String get none => 'Nie je nakonfigurované žiadne vybavenie';
	@override String get add => 'Pridať';
	@override String get addTitle => 'Pridať vybavenie';
	@override String get searchHint => 'Hľadať vybavenie';
	@override String get noMatches => 'Žiadne zodpovedajúce vybavenie';
	@override String get detectedEquipment => 'Zistené vybavenie';
	@override String discoveryUnavailable({required Object error}) => 'Nedá sa vyhľadávať rádiostanice: ${error}';
	@override String get edit => 'Upraviť vybavenie';
	@override String get name => 'Názov';
	@override String get nameDescription => 'Ako ho nazývate — „Ľavá rádiostanica“. Nepovinné.';
	@override String get transport => 'Pripojenie';
	@override String get host => 'Adresa';
	@override String get hostDescription => 'Názov hostiteľa alebo IP adresa rádiostanice vo vašej sieti.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Adresa je povinná';
	@override String get portInvalid => 'Port musí byť od 1 do 65535';
	@override String get connect => 'Pripojiť';
	@override String get disconnect => 'Odpojiť';
	@override String get remove => 'Odstrániť';
	@override String removeTitle({required Object name}) => 'Odstrániť ${name}?';
	@override String get removeMessage => 'Odstráni sa iba z aplikácie. Nastavenia vybavenia zostanú nezmenené.';
	@override String unknownType({required Object typeKey}) => 'Nerozpoznaný typ vybavenia „${typeKey}“';
	@override String get report => 'Nahlásiť';
	@override String get reportTitle => 'Nahlásiť túto rádiostanicu';
	@override String get reportIntro => 'Povedzte nám, o akú rádiostanicu ide a ako to dopadlo. Z vášho hlásenia vznikne karta, ktorú číta tím Ham2K, a to, čo napíšete o jej sprevádzkovaní, môže pomôcť ďalšiemu operátorovi s rovnakou rádiostanicou.';
	@override String get reportManufacturer => 'Výrobca';
	@override String get reportManufacturerDescription => 'Kto ju vyrába — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Výrobca je povinný';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'Model tak, ako ho uvádza samotná rádiostanica — „IC-7300“, „FT-991A“.';
	@override String get reportModelRequired => 'Model je povinný';
	@override String get reportOutcome => 'Ako to dopadlo?';
	@override String get reportOutcomeWorks => 'Fungovala dobre';
	@override String get reportOutcomeIssues => 'Fungovala, ale s problémami';
	@override String get reportOutcomeFails => 'Vôbec nefungovala';
	@override String get reportOutcomeRequired => 'Povedzte nám, ako to dopadlo';
	@override String get reportComments => 'Komentáre';
	@override String get reportCommentsPlaceholder => 'Čo fungovalo, čo nie, čokoľvek, čo vás prekvapilo.';
	@override String get reportHints => 'Tipy na riešenie problémov';
	@override String get reportHintsPlaceholder => 'Chcete navrhnúť tipy na riešenie problémov pre ostatných používateľov?';
	@override String get reportSend => 'Odoslať hlásenie';
	@override String get reportSending => 'Odosiela sa vaše hlásenie…';
	@override String reportSent({required Object ref}) => 'Ďakujeme — vaše hlásenie bolo zaevidované ako ${ref}.';
	@override String get reportSentNoRef => 'Ďakujeme — vaše hlásenie bolo odoslané.';
	@override String reportFailed({required Object error}) => 'Hlásenie sa neodoslalo: ${error}';
	@override String get troubleshootingNotes => 'Poznámky k riešeniu problémov';
	@override String get mainVfo => 'Hlavné VFO';
	@override String get useAsMainVfo => 'Použiť ako hlavné VFO';
	@override String get serialPort => 'Sériový port';
	@override String get serialPortDescription => 'Port, na ktorom sa zobrazuje rozhranie CAT rádiostanice.';
	@override String get serialPortNone => 'Nenašli sa žiadne sériové porty';
	@override String get serialPortRequired => 'Vyberte sériový port';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} z ${total}';
	@override String get serialPortSuggested => 'odporúčaný';
	@override String get serialPortJustNow => 'Nedávno pripojený';
	@override String get serialDeviceRequest => 'Pridať USB zariadenie…';
	@override String get baudRate => 'Rýchlosť (baud)';
	@override String get baudRateDescription => 'Musí zodpovedať menu CAT rádiostanice. Pri nezhode rádiostanica posiela nezmysly a žiadnu chybu.';
	@override String get serialRtsHigh => 'Držať RTS vo vysokej úrovni';
	@override String get serialRtsHighDescription => 'Iba pre rádiostanicu, ktorá pred odpoveďou čaká na RTS, napríklad Yaesu so zapnutým CAT RTS. Na Digirig, SignaLink a väčšine domácky vyrobených káblov je RTS signál PTT a jeho držanie vo vysokej úrovni spustí vysielanie.';
	@override String get serialDtrHigh => 'Držať DTR vo vysokej úrovni';
	@override String get serialDtrHighDescription => 'Iba pre rozhranie CAT, ktoré sa napája z DTR, napríklad niektoré káble RS-232 pre FT-817. Na mnohých kábloch DTR kľúčuje CW alebo PTT a jeho držanie vo vysokej úrovni spustí vysielanie.';
	@override String get civAddress => 'Adresa CI-V rádiostanice';
	@override String get civAddressDescription => 'Hexadecimálne, ako ju zobrazuje menu CI-V rádiostanice. IC-705 sa dodáva s A4.';
	@override String get civAddressInvalid => 'Adresa CI-V sú dve hexadecimálne číslice, 01 až FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Z ktorého slice rádiostanice toto pripojenie číta a ktorý ladí.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Vyberte jeden zo slice rádiostanice, A až H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} sa na tejto rádiostanici nepoužíva — vyberte iný slice alebo ho vytvorte v SmartSDR';
	@override String get channelNotInUse => 'nepoužíva sa';
	@override String get channelHeldByUnknown => 'používa ho iný program';
	@override String get flexNoSlices => 'Táto rádiostanica nehlási žiadne slice — skontrolujte, či beží SmartSDR a či sa tento klient môže prihlásiť na odber';
	@override String get spectrumUnsupported => 'Táto rádiostanica cez CAT neposiela spektrum';
	@override String get spectrumRequiresBaud => 'Vyžaduje CAT s rýchlosťou 115200 bps';
	@override String get spectrumNoRadio => 'Nie je pripojená žiadna rádiostanica';
	@override String get spectrumWaiting => 'Čaká sa na spektrum rádiostanice…';
	@override String get spectrumUnavailable => 'Zobrazenie spektra nie je dostupné';
	@override String get spectrumNoDaxChannel => 'Všetky kanály DAX IQ na tejto rádiostanici sú obsadené';
	@override String get spectrumNoPanadapter => 'Tento slice nemá na rádiostanici panadapter';
	@override String spectrumStreamRefused({required Object code}) => 'Rádiostanica odmietla stream DAX IQ (chyba ${code})';
	@override String get spectrumNoUdp => 'Údaje o spektre z rádiostanice sa nedostanú k tomuto zariadeniu';
	@override String get spectrumScopeRefused => 'Rádiostanica odmietla príkazy pre scope';
	@override String get spectrumOutOfRange => 'Scope rádiostanice je nastavený mimo rozsahu, ktorý dokáže zobraziť';
	@override String get n3fjpNoRig => 'N3FJP nemá nastavené rozhranie rádiostanice, takže toto sleduje to, čo sa zadá do N3FJP, nie rádiostanicu';
	@override String get winkeyerKeyPort => 'Výstup kľúča';
	@override String get winkeyerKeyPortDescription => 'Do ktorého z dvoch výstupných konektorov kľúčovača je pripojená vaša rádiostanica.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Použiť PTT kľúčovača';
	@override String get winkeyerPttDescription => 'Kľúčovať linku PTT na tom istom konektore, pre zosilňovač alebo rádiostanicu, ktorá to potrebuje. Nechajte vypnuté pre rádiostanicu kľúčovanú cez konektor kľúča.';
	@override String get winkeyerNoAnswer => 'Na tomto porte neodpovedal žiadny WinKeyer';
	@override String get winkeyerStoppedAnswering => 'WinKeyer počas vysielania prestal odpovedať; správa bola zahodená';
	@override String get radioUser => 'Používateľské meno rádiostanice';
	@override String get radioPass => 'Heslo rádiostanice';
	@override String get radioLoginDescription => 'Prihlásenie z menu Network → Remote rádiostanice, nie vaše heslo k WiFi.';
	@override String get radioUserRequired => 'Používateľské meno pre diaľkové ovládanie rádiostanice je povinné';
	@override String get connectFailedBusy => 'Zariadenie sa používa';
	@override String get connectFailedDenied => 'Prístup zamietnutý';
	@override String get connectFailedDevice => 'Zariadenie sa nenašlo';
	@override String get connectFailedLines => 'RTS/DTR sa nepodarilo udržať podľa nastavenia, preto bol port zatvorený. Iný program mohol nechať zapnuté hardvérové riadenie toku — odpojte a znova pripojte kábel.';
	@override String get connectFailedNetwork => 'Rádiostanicu sa nedarí nájsť v sieti. Skontrolujte jej adresu a či je zapnutá a dostupná.';
	@override String get connectFailedTimeout => 'Rádiostanica neodpovedala včas. Skontrolujte, či je zapnutá a dostupná.';
	@override late final _Translations$settings$station$models$sk models = _Translations$settings$station$models$sk._(_root);
	@override late final _Translations$settings$station$transports$sk transports = _Translations$settings$station$transports$sk._(_root);
	@override String get troubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get ft891Troubleshooting => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ** (menu FT-891 **05-08**). Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni. Na Digirig, SignaLink alebo väčšine domácky vyrobených káblov je ten istý signál PTT, takže jeho zdvihnutie by spustilo vysielanie. Na vlastnom USB porte rádiostanice je alternatívou **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** nastaveniu CAT RATE rádiostanice (menu **05-06**). Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get yaesuBinaryTroubleshooting => 'Táto rádiostanica používa starší päťbajtový CAT od Yaesu a keď niečo nie je v poriadku, vôbec neodpovedá. Takmer vždy ide o jedno z:\n\n- **Kábel musí prevádzať úrovne.** Konektor CAT vzadu nie je RS-232 ani USB; potrebuje CT-62 alebo rovnocenný adaptér. Obyčajný audio alebo dátový kábel pre CAT nefunguje.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice (**#14** na FT-817, **#19** na FT-857 alebo FT-897). Pri nezhode rádiostanica nič neposiela, a nikdy chybu.\n- **Nikdy nedovoľte, aby niečo zdvihlo RTS alebo DTR na tomto porte.** Na väčšine káblov pre tieto rádiostanice sú tieto linky PTT a kľúčovanie. Výnimkou je staršie rozhranie napájané z DTR: preň zapnite **Držať DTR vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\nTento ovládač bol napísaný podľa zverejnenej tabuľky CAT od Yaesu a na žiadnej z týchto rádiostaníc ešte nebežal. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get guohetecTroubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get guohetecTroubleshooting => 'Q900 má dva protokoly CAT a táto položka používa jeho natívny namiesto napodobeniny FT-817. Vyberte tu **Guohetec Q900**, nie FT-817 — napodobenina podporuje menej príkazov a rádiostanica neoznamuje, ktorý používa.\n\n- **Kábel USB-C je linka CAT** a pripája aj zvukovú kartu. Rýchlosť na ňom nezáleží; port ignoruje, na čo je nastavený.\n- **Nikdy nedovoľte, aby niečo zdvihlo RTS alebo DTR na tomto porte.** Na sériovom kábli sú tieto linky PTT a kľúčovanie.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Rádiostanica druhej generácie sa správa inak** ako prvej. Dlho stlačte Menu, potom About: HW 2.0 je druhá generácia.\n\nTento ovládač bol napísaný podľa zverejneného protokolu výrobcu a na žiadnej z týchto rádiostaníc ešte nebežal. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get yaesuTroubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get yaesuTroubleshooting => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni. Na Digirig, SignaLink alebo väčšine domácky vyrobených káblov je ten istý signál PTT, takže jeho zdvihnutie by spustilo vysielanie. Na vlastnom USB porte rádiostanice je alternatívou **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“. Kde sa toto nastavenie nachádza, závisí od modelu (menu **05-08** na FT-891).\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Módy sa riadia tabuľkou FT-891.** Väčšina rádiostaníc Yaesu jej zodpovedá, ale rádiostanica, ktorá čísluje módy inak, pri nich zobrazí a nastaví nesprávny mód. Frekvencia tým nie je ovplyvnená.';
	@override String get yaesuRs232Troubleshooting => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **Konektor CAT je RS-232.** Potrebuje prevodník USB na sériový port a priamy kábel DB-9 — kábel null-modem prehadzuje linky a rádiostanica nič nepočuje.\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni, pokiaľ nie je zapnuté **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\nTáto položka bola napísaná podľa zverejnenej dokumentácie CAT a na žiadnej z týchto rádiostaníc ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get yaesuUsbTroubleshooting => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **Použite prvý z dvoch USB portov rádiostanice.** CAT je zvyčajne na prvom (vo Windows port COM **Enhanced**); druhý (**Standard**) slúži na PTT a kľúčovanie. Výber ukazuje na prvý všade, kde ich dokáže rozlíšiť.\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni, pokiaľ nie je zapnuté **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.';
	@override String get k4SerialNotes => 'Pripojte zadný konektor USB-B (PC) na K4. Pre CAT funguje USB-PC1 aj USB-PC2; vyberte nepoužívaný port a nastavte na rádiostanici zodpovedajúce Serial USB-PCn: Baud Rate. HaLo predvyplní 38400; v prípade potreby to zmeňte. Iná aplikácia musí používať druhý port alebo Ethernet.\n\nToto pripojenie ovláda rádiostanicu a jej kľúčovače; neposiela zvuk do HaLo.';
	@override String get k4TcpNotes => 'Pripojte ethernetový konektor K4 do lokálnej siete. Zadajte jeho názov hostiteľa alebo IP adresu a port CAT 9200. Ide o ovládanie CAT, nie o samostatné pripojenie vzdialeného zvuku na porte 9204.\n\nHaLo ovláda rádiostanicu a jej kľúčovače bez streamovania zvuku alebo údajov panadaptera.';
	@override String get k4PowerTimeout => 'Výkon K4 sa nezmenil, pretože rádiostanica nepotvrdila svoj výstupný rozsah. Skúste to znova.';
	@override String get k4PowerRange => 'Výkon K4 musí byť 0,1–110 W, alebo 0,0001–0,01 W, keď je aktívny miliwattový výstup transvertora.';
	@override String get elecraftTroubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get elecraftTroubleshooting => 'Rádiostanice Elecraft používajú Kenwood CAT a KX2 aj KX3 boli takto vyskúšané — VFO v oboch smeroch, prepínanie módov aj CW záznej fungujú.\n\nAk rádiostanica neodpovedá, takmer vždy ide o jedno z:\n\n- **Rýchlosť musí zodpovedať** hodnote nastavenej v **RS232** v menu rádiostanice. Z výroby je to 38400. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\n**Ak je frekvencia správna, ale mód nie**, dajte nám vedieť. Položky KX2 a KX3 čítajú mód z pozície v stavovej odpovedi rádiostanice, ktorú sme určili podľa rádiostaníc, ktoré sme videli, a firmvér, ktorý ho dáva inam, sa k nám dostane iba cez hlásenie.\n\nO K3 zatiaľ nemáme žiadne hlásenie, preto ak ju používate, dajte nám vedieť, čo sa stane. K4 má vlastnú položku.';
	@override String get kenwoodTroubleshootingTitle => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu';
	@override String get kenwoodTroubleshooting => 'Tento ovládač je overený na Kenwood TS-590SG a TS-480, QRP Labs QMX a QCX-mini a Elecraft KX2 a KX3. Zvyšok radu je napísaný podľa zverejnených referencií CAT, preto nahláste, čo sa stane, v každom prípade.\n\nAk rádiostanica neodpovedá, takmer vždy ide o jedno z:\n\n- **Rýchlosť musí zodpovedať** menu CAT rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Niektoré rádiostanice potrebujú povoliť CAT** v menu, inak vôbec neodpovedajú.\n\n**Viaceré SDR rozhrania používajú rovnaký protokol**, takže sa oplatí vyskúšať túto položku aj pre ne; rádiostanice Elecraft sú uvedené samostatne, pod Elecraft. Ak je frekvencia správna, ale mód je nesprávny alebo chýba, je to jediná časť, ktorá sa v rade líši — aplikácia ho zisťuje z rádiostanice a v náhradnom prípade sa pýta priamo, takže mód môže jednoducho meškať.';
	@override String get statusConnected => 'Pripojené';
	@override String get statusLost => 'Odpojené';
	@override String get notConfigured => 'Nenakonfigurované';
	@override String get currentConfiguration => 'Aktuálna konfigurácia';
	@override String get currentTransceiver => 'Aktuálny transceiver';
	@override String get radioMode => 'Mód rádiostanice';
	@override String get keyerNotSupported => 'Aktuálna rádiostanica nepodporuje';
	@override String get catControlPreferences => 'Predvoľby ovládania CAT';
	@override String get chooseTransceiver => 'Vybrať transceiver';
	@override String get configurationSection => 'Konfigurácia';
	@override String get noTransceiverSelected => 'Nie je vybraný žiadny transceiver';
	@override String makeMainVfo({required Object name}) => 'Použiť ${name} pre hlavné VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		zero: 'Žiadne transceivery',
		one: '${count} transceiver',
		other: '${count} transceiverov',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} anténa',
		other: '${count} antén',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} iné zariadenie',
		other: '${count} iných zariadení',
	);
	@override String get equipmentInventory => 'Inventár vybavenia';
	@override String get equipmentInUse => 'Ovládanie transceivera';
	@override String get noTransceiver => 'Žiadny';
	@override String get peerRadioNotAvailable => 'Nedostupné';
	@override String peerRadioOnDevice({required Object device}) => 'Na ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} je na inom zariadení';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Táto rádiostanica je pripojená k ${device}. Jej pripojenie a nastavenia sa konfigurujú na tom zariadení.';
	@override String get antennaInUse => 'Používaná anténa';
	@override String get keyInUse => 'Používaný kľúč';
	@override String get noneSelected => 'Žiadny';
	@override String get moreSettings => 'Ďalšie nastavenia';
	@override String get icomCivTroubleshootingTitle => 'Ak sa pre tú istú rádiostanicu zobrazia dva sériové porty';
	@override String get icomCivTroubleshooting => 'Viaceré rádiostanice Icom, vrátane IC-705, poskytujú naraz **dva** sériové USB porty (Icom ich nazýva Port A a Port B), oba predvolene nastavené na CI-V. Ani táto aplikácia, ani váš OS ich inak nerozlíšia: rovnaké USB vendor/product ID sa jednoducho zobrazí dvakrát, niekedy tu s príponou `#2`. **Správny je zvyčajne Port A** — obvykle prvý, ktorý váš OS alebo prehliadač uvádza, a kde táto aplikácia dokáže porty rozlíšiť, označí ho ako odporúčaný. Ak príkazy odchádzajú a rádiostanica nikdy neodpovie, skúste potom druhý port.';
	@override String get civAddressTroubleshootingTitle => 'Ak rádiostanica nikdy neodpovie';
	@override String get civAddressTroubleshooting => '- **Adresa CI-V musí zodpovedať** menu rádiostanice. Táto položka predvyplní adresu, s ktorou sa model dodáva, ale práve pri rádiostanici zdieľajúcej zbernicu CI-V sa mení. Rámec odoslaný na nesprávnu adresu sa potichu ignoruje, čo vyzerá presne ako nefunkčný kábel.\n- **Rýchlosť musí zodpovedať** CI-V BAUD RATE rádiostanice (pri USB CI-V USB Baud Rate). Nastavte na rádiostanici rovnaké číslo, aké je zobrazené tu, **nie Auto**. Pri Auto sa niektoré rádiostanice, vrátane IC-7300, pripoja a asi po minúte prestanú odpovedať.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** sa dodáva s adresou `B6`, nie `94` predvyplnenou tu — namiesto toho vyberte položku IC-7300 MK2.';
	@override String get ic705PortNote => '\n- **IC-705** poskytuje dva sériové USB porty, oba pomenované podľa rádiostanice. CI-V je na **prvom** z nich, na ktorý výber ukazuje všade, kde ich dokáže rozlíšiť.';
	@override String get ic7760PortNote => '\n- **IC-7760** používa CI-V na **Port A** z dvoch sériových USB portov, ktoré poskytuje.';
	@override String get x6100PortNote => '\n- **X6100** používa CI-V na svojom porte **DEV** — druhom z dvoch sériových portov, ktoré poskytuje, a na ktorý výber ukazuje.';
	@override String get rigctldTroubleshootingTitle => 'Ak sa aplikácia nemôže pripojiť';
	@override String get rigctldTroubleshooting => 'Toto sa pripája k **démonu rigctld, ktorý spúšťate sami**, nie priamo k rádiostanici — backend Hamlib komunikuje s rádiostanicou a podporuje stovky modelov.\n\n- **Démon už musí bežať**, napr. `rigctld -m 1035 -r /dev/ttyUSB0`. Číslo modelu vašej rádiostanice nájdete pomocou `rigctl -l`.\n- **Z iného počítača** ho spustite s `-T 0.0.0.0`: predvolene rigctld prijíma pripojenia iba z počítača, na ktorom beží.\n- **Port** je 4532, pokiaľ ste démona nespustili s `-t`.\n- Po pripojení chýbajúca frekvencia zvyčajne znamená, že samotný démon sa nedostane k rádiostanici. Otestujte ho pomocou `rigctl -m 2 f` na počítači s démonom.';
	@override String get flrigTroubleshootingTitle => 'Ak sa aplikácia nemôže pripojiť';
	@override String get flrigTroubleshooting => 'Toto sa pripája k **programu flrig, ktorý spúšťate sami**, nie priamo k rádiostanici — flrig komunikuje s rádiostanicou a podporuje väčšinu značiek a modelov.\n\n- **flrig už musí bežať** s nakonfigurovaným a pripojeným transceiverom.\n- **Port** je 12345, pokiaľ ste ho nezmenili v konfigurácii flrig (Config → Setup → Server).\n- **Z iného počítača** sa uistite, že server flrig je dostupný. Počúva na všetkých rozhraniach, ale váš firewall s tým nemusí súhlasiť.\n- Po pripojení chýbajúca frekvencia zvyčajne znamená, že samotný flrig sa nedostane k rádiostanici. Skontrolujte, či displej flrig sleduje ladenie.';
	@override String get hrdTroubleshootingTitle => 'Ak sa aplikácia nemôže pripojiť';
	@override String get hrdTroubleshooting => 'Toto sa pripája k **Rig Control z Ham Radio Deluxe, ktorý beží na vašom počítači**, nie priamo k rádiostanici — HRD komunikuje s rádiostanicou.\n\n- **Rig Control už musí bežať** a byť pripojený k rádiostanici.\n- **Jeho IP server musí byť povolený.** Rig Control komunikuje s inými programami iba cez neho.\n- **Port** je 7809, pokiaľ ste ho nezmenili v nastaveniach IP servera.\n- **Z iného počítača** sa uistite, že váš firewall pripojenie prepustí.\n\nTáto položka bola napísaná podľa zverejnených popisov protokolu HRD a s HRD ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get n3fjpTroubleshootingTitle => 'Ak sa aplikácia nemôže pripojiť';
	@override String get n3fjpTroubleshooting => 'Toto sa pripája k **logovaciemu programu N3FJP, ktorý beží na vašom počítači**, nie priamo k rádiostanici — N3FJP komunikuje s rádiostanicou.\n\n- **API programu musí byť zapnuté**: Settings → Application Program Interface, zaškrtnite **TCP API Enabled**.\n- **Port** je 1100, pokiaľ ste ho tam nezmenili.\n- **N3FJP musí mať nastavené rozhranie rádiostanice**, aby mohol sledovať alebo ladiť rádiostanicu. Bez neho hlási iba to, čo sa zadá do jeho vstupného okna.\n- N3FJP hlási iba pásmo, mód a frekvenciu: žiadny výkon, žiadny stav vysielania.\n\nTáto položka bola napísaná podľa zverejneného API N3FJP a s N3FJP ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get commanderTroubleshootingTitle => 'Ak sa aplikácia nemôže pripojiť';
	@override String get commanderTroubleshooting => 'Toto sa pripája k **DXLab Commander, ktorý beží na vašom počítači**, nie priamo k rádiostanici — Commander komunikuje s rádiostanicou.\n\n- **Commander už musí bežať** a byť pripojený k rádiostanici.\n- **Jeho sieťová služba musí byť zapnutá**: tlačidlo **Net Serv** na paneli Radio v okne Configuration programu Commander.\n- **Port** je 52002, tretí port bloku začínajúceho na **Base Port** v Net Serv (52000, pokiaľ ste ho nezmenili).\n- **Z iného počítača** sa uistite, že váš firewall pripojenie prepustí.\n\nTáto položka bola napísaná podľa zverejnených TCP správ programu Commander a s Commanderom ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.';
	@override String get ic705TroubleshootingTitle => 'Ak rádiostanica nikdy neodpovie';
	@override String get ic705Troubleshooting => 'Rádiostanica má **jedinú** reláciu diaľkového ovládania. Keď sa prihlásenie ignoruje, takmer vždy ju používa niečo iné.\n\n- **Zatvorte všetkých ostatných klientov.** wfview alebo RS-BA1 pripojený k tej istej rádiostanici drží túto jedinú reláciu a prihlásenie tu sa medzitým jednoducho ignoruje.\n- **Skontrolujte sieťové nastavenia rádiostanice.** WLAN musí byť zapnutá, rádiostanica musí byť v tej istej sieti a jej funkcia diaľkového ovládania (Network) musí byť povolená.\n- **Vypnite a zapnite WLAN rádiostanice**, ak zostane zaseknutá. Spoľahlivo to uvoľní reláciu zaseknutú na rádiostanici.\n\n**Nesprávne heslo je výslovne odmietnuté**, nie prijaté mlčaním. Ak ste sa dostali sem a nie k správe „odmietnuté“, problém nie je v hesle.';
	@override String get statusStale => 'Neodpovedá';
	@override String get statusDisconnected => 'Nepripojené';
	@override String get statusConnecting => 'Pripája sa…';
	@override String get statusDisconnecting => 'Odpája sa…';
	@override String get statusError => 'Pripojenie zlyhalo';
	@override String get currentRadioSettings => 'Aktuálne nastavenia rádiostanice';
	@override String get notSupportedByThisRadio => 'Táto rádiostanica nepodporuje';
	@override String get keyerRowLabel => 'Kľúčovač';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Fónia';
	@override String voiceKeyerAvailable({required Object count}) => 'Hlasový kľúčovač: pamäte v rádiostanici (${count})';
	@override String get antennaBands => 'Pásma';
	@override String get antennaType => 'Typ antény';
	@override String get antennaTypeRequired => 'Vyberte typ antény';
	@override late final _Translations$settings$station$antennaTypes$sk antennaTypes = _Translations$settings$station$antennaTypes$sk._(_root);
	@override String get keyType => 'Typ kľúča';
	@override String get keyTypeRequired => 'Vyberte typ kľúča';
	@override late final _Translations$settings$station$keyTypes$sk keyTypes = _Translations$settings$station$keyTypes$sk._(_root);
	@override String get softwareIntermediaries => 'Softvéroví sprostredkovatelia';
	@override String get otherBrands => 'Iné značky';
	@override String get otherEquipment => 'Iné vybavenie (antény, kľúče atď.)';
	@override String get newAntenna => 'Nová anténa';
	@override String get newKey => 'Nový kľúč';
	@override String get newKeyer => 'WinKeyer (K1EL alebo kompatibilný)';
	@override String keyViaRadio({required Object radio}) => 'CAT kľúčovač v ${radio}';
	@override String keyOnDevice({required Object device}) => 'Kľúč na ${device}';
	@override String get cwKeyerArea => 'Oblasť kľúčovača';
	@override String get trackStationInfo => 'Zaznamenávať informácie o stanici pre každé QSO';
	@override String get includeStationInfoInAdif => 'Zahrnúť do exportov ADIF';
	@override String get whatToTrack => 'Čo zaznamenávať?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Výkon';
	@override String get watts => 'Watty';
	@override String get trackFieldAntenna => 'Anténa';
	@override String get trackFieldKey => 'CW kľúč';
	@override String get placeholderConnectDelay => 'Oneskorenie pripojenia (ms)';
	@override String get placeholderConnectDelayDescription => 'Ako dlho trvá simulovaný handshake. Prázdne alebo 0 sa pripojí okamžite.';
	@override String get placeholderDropAfter => 'Odpojiť po (sekundy)';
	@override String get placeholderDropAfterDescription => 'Samo zatvorí pripojenie, aby sa vyskúšalo opätovné pripojenie. Prázdne alebo 0 sa nikdy neodpojí.';
	@override String get placeholderFailConnect => 'Vždy zlyhať pri pripájaní';
	@override String get placeholderConnectFailure => 'Zástupná rádiostanica má nastavené toto pripojenie odmietnuť';
	@override String get placeholderFreq => 'Frekvencia (kHz)';
	@override String get placeholderFreqDescription => 'Kde zástupná rádiostanica začína. Potom hlási to, na čo ju aplikácia naladí.';
	@override String get placeholderMode => 'Mód';
	@override String get placeholderModeDescription => 'Mód, na ktorom zástupná rádiostanica začína, napr. USB, CW, FT8.';
	@override String get placeholderPower => 'Výkon (watty)';
	@override String get placeholderPurpose => 'Použite túto rádiostanicu na zaznamenávanie, ktorú rádiostanicu používate, na účely logovania';
	@override String get placeholderReplyDelay => 'Oneskorenie odpovede (ms)';
	@override String get placeholderReplyDelayDescription => 'Ako dlho trvá zástupnej rádiostanici nahlásiť zmenu. Prázdne alebo 0 odpovie okamžite.';
	@override String get cwKeyerField => 'CAT CW kľúčovač';
	@override String get cwKeyerFieldDescription => 'Či táto rádiostanica kľúčuje CW z textu cez CAT. Vypnuté pre rádiostanicu, ktorú aplikácia nepozná.';
	@override String get voiceMemories => 'Hlasové pamäte';
	@override String get voiceMemoriesDescription => 'Koľko hlasových pamätí rádiostanica prehráva cez CAT. 0 pre žiadne.';
	@override String get voiceMemoriesInvalid => 'Celé číslo, 0 alebo viac';
	@override String get yaesuMeterCapture => 'Zaznamenávať hodnoty meračov';
	@override String get yaesuBinaryMeterCaptureDescription => 'Počas vysielania číta merač výstupného výkonu a príznak vysokého SWR rádiostanice a vypisuje surové hodnoty do logu. Slúži na zostavenie stupnice, ktorú Yaesu nezverejňuje — hodnoty sa nezobrazujú ako merače.';
	@override String get yaesuMeterCaptureDescription => 'Počas vysielania číta merače PO, SWR a ALC rádiostanice a vypisuje surové hodnoty do logu. Slúži na zostavenie stupnice, ktorú Yaesu nezverejňuje — hodnoty sa nezobrazujú ako merače.';
	@override String get telemetryInterval => 'Interval čítania meračov (ms)';
	@override String get telemetryIntervalDescription => 'Ako často čítať merače rádiostanice počas vysielania. Nechajte prázdne pre najrýchlejšie, čo toto pripojenie zvládne, až do 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Celý počet milisekúnd, ${min} až ${max}';
	@override String get pollInterval => 'Interval dopytovania v nečinnosti (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Ako často sa pýtať rádiostanice na frekvenciu a mód, keď sa nemenia. Nechajte prázdne pre ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Celý počet milisekúnd, ${min} až ${max}';
	@override String get advancedSettings => 'Rozšírené nastavenia';
	@override String get placeholderSwr => 'Hodnota SWR';
	@override String get placeholderSwrDescription => 'Čo táto rádiostanica hlási na merači SWR počas vysielania. Nad 1,8 panel upozorní.';
	@override String get placeholderSwrInvalid => 'Číslo, 1 alebo viac';
	@override String get keyerNone => 'Žiadny';
	@override String get cwDialect => 'Dialekt kľúčovania CW';
	@override String get cwDialectDescription => 'Akú podobu príkazu KY táto rádiostanica prijíma. Žiadny znamená bez kľúčovania CW cez CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, doplnené na 24)';
	@override String get cwDialectElecraft => 'Elecraft (KY text)';
	@override String get voiceDialect => 'Dialekt hlasového kľúčovača';
	@override String get voiceDialectDescription => 'Ako táto rádiostanica prehráva hlasové pamäte cez CAT. Žiadny znamená bez hlasových pamätí cez CAT. S dialektom a bez počtu platí predvolený počet dialektu.';
	@override String get voiceDialectPb => 'Kenwood (PB, štýl TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB a DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (stlačenia prepínačov)';
	@override String get placeholderDiagnostic => 'Simulované';
	@override String get placeholderWholeNumberInvalid => 'Musí byť celé číslo, 0 alebo viac';
	@override String get placeholderFreqInvalid => 'Musí byť frekvencia v kHz, väčšia ako nula';
	@override String get placeholderModeInvalid => 'Musí byť názov módu, napr. USB, CW, FT8';
	@override String get switchLayout => 'Rozloženie';
	@override String get switchLayoutDescription => 'Na ktorú stranu prepínača sú pripojené vaše rádiostanice.';
	@override String get switchLayoutRequired => 'Vyberte, ako je prepínač zapojený';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Prepínač odmietol „${command}“ (chyba ${code})';
	@override String get switchBusyTransmitting => 'Tento port vysiela — anténa sa nezmenila';
	@override String get switchNoAntenna => 'Žiadna';
	@override String switchAntennaFor({required Object port}) => 'Anténa na porte ${port}';
	@override String get switchAntennaForDescription => 'Ktorá z vašich antén je pripojená k tomuto portu prepínača.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => 'Antény: ${antennas}, rádiostanice: ${radios}';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => 'Antény: ${antennas}, 1 rádiostanica';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 anténa, rádiostanice: ${radios}';
	@override String get switchCommonPort => 'Spoločný';
	@override String get dcnAddress => 'Adresa zariadenia';
	@override String get dcnAddressDescription => 'Adresa nastavená na DIP prepínačoch modulu. Modul koaxiálneho relé sa z výroby dodáva s adresou 2.';
	@override String get dcnAddressRequired => 'Musí byť adresa zariadenia od 1 do 99';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'sleduje údaje o pásme';
	@override String get switchPortTransmittingHint => 'vysiela — teraz sa nedá zmeniť';
	@override String get switchCurrentStateHeader => 'Aktuálny stav';
	@override String get switchCurrentStateDescription => 'Na ktorej anténe je práve každý port rádiostanice. Zmeny sa prejavia okamžite.';
	@override String get switchWiringHeader => 'Zapojenie';
	@override String get switchPortInhibitedHint => 'vysielanie zablokované';
	@override String get configUnreadable => 'Uložené nastavenia tejto rádiostanice sa nepodarilo prečítať. Otvorte jej nastavenia a zadajte ich znova, alebo ju odstráňte a pridajte späť.';
	@override String get autoConnectHeld => 'HaLo prestal odpovedať, keď sa naposledy pripájal k tejto rádiostanici, preto sa tentoraz nepripojil sám. Stlačte Pripojiť a skúste to znova.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$sk extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Offline údaje';
	@override String get noFiles => 'Žiadne dátové súbory';
	@override String get noFilesDescription => 'Povoľte rozšírenia aktivít alebo vyhľadávania a ich offline údaje sa budú sťahovať sem.';
	@override String get refresh => 'Obnoviť';
	@override String get refreshing => 'Obnovuje sa…';
	@override String get updateAll => 'Aktualizovať všetko';
	@override String get updatingAll => 'Aktualizujú sa všetky dátové súbory…';
	@override String get neverDownloaded => 'Nikdy nestiahnuté';
	@override String get updatedJustNow => 'Aktualizované práve teraz';
	@override String updatedDaysAgo({required Object days}) => 'Aktualizované pred ${days} d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Aktualizované pred ${days} d ${hours} h';
	@override String updatedHoursAgo({required Object hours}) => 'Aktualizované pred ${hours} h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Aktualizované pred ${hours} h ${minutes} min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Aktualizované pred ${minutes} min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Posledné sťahovanie malo iba ${imported} z ${existing} záznamov a nebolo použité. Obnovením ho prijmete.';
	@override String get extensionsSection => 'Rozšírenia';
}

// Path: settings.profiles
class _Translations$settings$profiles$sk extends Translations$settings$profiles$en {
	_Translations$settings$profiles$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Nenastavené';
	@override String get personalInfo => 'Osobné údaje';
	@override String get personalInfoNote => 'Môžu byť zahrnuté do vygenerovaných denníkov, ak sú potrebné na odoslanie';
	@override String get name => 'Meno';
	@override String get email => 'E-mail';
	@override String get club => 'Klub';
	@override String get arrlSection => 'ARRL sekcia';
	@override String get racSection => 'RAC sekcia';
	@override String get section => 'Sekcia';
}

// Path: settings.search
class _Translations$settings$search$sk extends Translations$settings$search$en {
	_Translations$settings$search$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Vymazať';
	@override String get hint => 'Hľadať v nastaveniach';
}

// Path: settings.developer
class _Translations$settings$developer$sk extends Translations$settings$developer$en {
	_Translations$settings$developer$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Povoliť upozornenia pre vývojárov, ladiace logy a nástroje.';
	@override String get experiments => 'Experimenty';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} povolený',
		other: '${count} povolených',
	);
	@override String get patchTrack => 'Vetva Code Push';
	@override String get patchTrackDescription => 'Ktorý okruh aktualizácií kódu cez internet toto zariadenie sleduje. Odvážnejšie okruhy dostávajú opravy skôr, ale menej otestované. Aktualizácie kódu sa uplatnia pri ďalšom reštarte.';
	@override String get trackStable => 'Stabilná';
	@override String get trackUnstable => 'Nestabilná';
	@override String get trackBleeding => 'Vývojová';
	@override String checkingTrack({required Object track}) => 'Kontroluje sa aktualizácia kódu na „${track}“…';
	@override String get patchDownloaded => 'Aktualizácia kódu stiahnutá — reštartujte aplikáciu a uplatní sa.';
	@override String noNewPatch({required Object track}) => 'Žiadna nová aktualizácia kódu na „${track}“.';
	@override String get noPatchInstalled => 'Nie je nainštalovaná žiadna aktualizácia kódu — beží vydaná binárka.';
	@override String runningPatch({required Object patch}) => 'Beží aktualizácia kódu č. ${patch}.';
	@override String get deepLinks => 'Priame odkazy';
	@override String get registerUrlSchemes => 'Registrovať schémy URL';
	@override String get registerUrlSchemesDescription => 'Odkazy com.ham2k:// budú otvárať túto kópiu aplikácie';
	@override String get registerUrlSchemesDone => 'Táto kópia teraz otvára odkazy com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Registrácia zlyhala: ${error}';
	@override String get systemInformation => 'Informácie o systéme';
	@override String get appVersion => 'Verzia aplikácie';
	@override String get dataFolder => 'Priečinok s údajmi';
	@override String get loading => '(načítava sa…)';
	@override String get panelLoadFailed => 'Tento panel nastavení sa nepodarilo načítať.';
	@override String get extDevServer => 'Vývojový server rozšírení';
	@override String get extensionSettings => 'Nastavenia rozšírení';
	@override String get extDevServerDescription => 'Načítavať rozšírenia z vývojového servera vo vašej sieti namiesto vstavaných v aplikácii a znova ich načítať pri každom uložení.';
	@override String get extDevServerAddress => 'Adresa servera';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Pripojiť';
	@override String get extDevServerDisconnect => 'Odpojiť';
	@override String get extDevServerConnecting => 'Pripája sa…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Poskytuje sa ${count} rozšírenie: ${keys}',
		other: 'Poskytuje sa ${count} rozšírení: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Nepripojené';
	@override String get extDevServerReconnect => 'Znova pripojiť pri spustení';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Posledné načítanie: ${key} o ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: '${count} rozšírenie sa nedá zostaviť',
		other: '${count} rozšírení sa nedá zostaviť',
	);
	@override String get catalog => 'Katalóg rozšírení';
	@override String get catalogDescription => 'Čítať katalóg z iného servera — lokálneho pri práci na samotnom katalógu. Prázdne znamená catalog.ham2k.net.';
	@override String get catalogAddress => 'Adresa katalógu';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Vetvy pri hľadaní v katalógu';
	@override String get catalogSearchStable => 'Iba stabilné';
	@override String get catalogSearchUnstable => 'Nestabilné alebo lepšie';
	@override String get catalogSearchBleeding => 'Vývojové alebo lepšie';
}

// Path: settings.about
class _Translations$settings$about$sk extends Translations$settings$about$en {
	_Translations$settings$about$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Oznámenia a správy';
	@override String get noticesDescription => 'Oznámenia a stavové správy';
	@override String get releaseNotes => 'Poznámky k vydaniu';
	@override String get copiedVersion => 'Podrobnosti o verzii skopírované do schránky';
}

// Path: settings.panels
class _Translations$settings$panels$sk extends Translations$settings$panels$en {
	_Translations$settings$panels$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Predvoľby aplikácie';
	@override String get settingsDescription => 'Prispôsobte si aplikáciu podľa seba';
	@override String get commonSettings => 'Bežné predvoľby';
	@override String get syncDescription => 'Zálohujte a synchronizujte svoje denníky medzi zariadeniami';
	@override String get accountsDescription => 'Prihlasovacie údaje k službám, offline údaje a ďalšie';
	@override String get extensions => 'Rozšírenia a funkcie';
	@override String get extensionsDescription => 'Aktivity, súťaže, panely prehľadu a ďalšie funkcie';
	@override String get profilesDescription => 'Volací znak operátora a profil stanice';
	@override String get stationProfiles => 'Profily stanice';
	@override String get developerSettings => 'Nastavenia pre vývojárov';
	@override String get developerSettingsDescription => 'Nástroje na ladenie a vývoj';
	@override String get about => 'O aplikácii';
	@override String get aboutDescription => 'Verzia, autori a právne informácie';
	@override String get unavailableTitle => 'Niektoré nastavenia nie sú dostupné';
	@override String get unavailableText => 'Prostredie rozšírení sa nepodarilo spustiť, preto chýbajú nastavenia pridané rozšíreniami.';
	@override String get station => 'Konfigurácia stanice';
	@override String get stationDescription => 'Ovládanie CAT a ďalšie možnosti';
	@override String get peers => 'Partnerské zariadenia';
	@override String get peersDescription => 'Pripojiť sa k iným zariadeniam v blízkosti';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$sk extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get six => '6 miest (FN31pr)';
	@override String get eight => '8 miest (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$sk extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get six => '6 miest';
	@override String get eight => '8 miest';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$sk extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get date => 'Dátum';
	@override String get time => 'Čas';
	@override String get freq => 'Frekvencia';
	@override String get mode => 'Mód';
	@override String get call => 'Značka';
	@override String get name => 'Meno';
	@override String get station => 'Stanica';
	@override String get band => 'Pásmo';
	@override String get sent => 'Odoslané';
	@override String get rcvd => 'Prijaté';
	@override String get grid => 'Lokátor';
	@override String get state => 'Štát';
	@override String get country => 'Krajina';
	@override String get refs => 'Ref.';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$sk extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Denník QSO';
	@override String get qsosDescription => 'QSO vybraného volacieho znaku zo všetkých prevádzok.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Celkový počet QSO alebo vyhľadanie volacieho znaku vybraného QSO.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Poloha vybraného QSO.';
}

// Path: home.logs.import
class _Translations$home$logs$import$sk extends Translations$home$logs$import$en {
	_Translations$home$logs$import$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Volacie znaky: ${calls}';
	@override String get skippedOne => '1 záznam sa nepodarilo prečítať';
	@override String skippedOther({required Object count}) => 'Nepodarilo sa prečítať záznamy: ${count}';
	@override String get readingTitle => 'Číta sa súbor ADIF…';
	@override String get checkingTitle => 'Kontrolujú sa duplikáty…';
	@override String get importingTitle => 'Importujú sa QSO…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => 'Skontrolované ${done} z ${total}';
	@override String importingDetail({required Object imported, required Object total}) => 'Importované ${imported} z ${total}';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$sk extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Denník a vstupné polia';
	@override String get infoDescription => 'Čo vieme o stanici, s ktorou pracujeme';
	@override String get spotsDescription => 'Spoty z clustrov a aktivačných programov';
	@override String get mapDescription => 'Kde sú protistanice';
	@override String get clockDescription => 'Hodiny v ľubovoľnom časovom pásme';
	@override String get clockFace => 'Ciferník';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analógový';
	@override String get clockZone => 'Časové pásmo';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Toto zariadenie';
	@override String get clockShowSeconds => 'Zobraziť sekundy';
	@override String get weatherDescription => 'Aktuálne podmienky a predpoveď na ďalších osem hodín tam, kde vysielate';
	@override String get weatherUseOperationLocation => 'Použiť polohu prevádzky';
	@override String get weatherLocation => 'Poloha';
	@override String get weatherLocationDescription => 'Lokátor (FN31pr) alebo šírka,dĺžka. Ignoruje sa, kým je zaškrtnuté „Použiť polohu prevádzky“.';
	@override String get weatherNoLocation => 'Poloha nie je nastavená. Zadajte polohu v nastaveniach tohto panelu alebo ho umiestnite do prevádzky, ktorá polohu má.';
	@override String weatherBadLocation({required Object location}) => 'Polohu ${location} sa nepodarilo prečítať. Použite lokátor ako FN31pr alebo 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo je nedostupné — nie je sieť? Čoskoro to skúsime znova.';
	@override String get weatherUnreadable => 'Open-Meteo odpovedalo, ale nič čitateľné. Čoskoro to skúsime znova.';
	@override String weatherGusts({required Object speed}) => 'nárazy ${speed}';
	@override String get panelAgeNow => 'práve teraz';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'pred ${count} min',
		other: 'pred ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'pred ${count} h',
		other: 'pred ${count} h',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$sk weatherConditions = _Translations$operation$layout$panels$weatherConditions$sk._(_root);
	@override String get websiteDescription => 'Webová stránka podľa vášho výberu v paneli';
	@override String get websiteUrl => 'Adresa';
	@override String get websiteRefresh => 'Obnovovanie';
	@override String get websiteRefreshNever => 'Nikdy';
	@override String get websiteRefresh1 => 'Každú minútu';
	@override String get websiteRefresh5 => 'Každých 5 minút';
	@override String get websiteRefresh15 => 'Každých 15 minút';
	@override String get websiteTitle => 'Názov panelu';
	@override String get websiteRefreshNow => 'Obnoviť teraz';
	@override String get websiteNoUrl => 'Zatiaľ bez adresy. Otvorte nastavenia tohto panelu a vyberte stránku.';
	@override String get websiteBadUrl => 'Toto nevyzerá ako webová adresa. Musí začínať na https://';
	@override String get websiteNotHttps => 'Zobraziť sa tu dajú iba https:// adresy.';
	@override String get websiteUnsupported => 'Na tomto systéme sa webové stránky v paneli zobraziť nedajú.';
	@override String get websiteOpenExternally => 'Otvoriť v prehliadači';
	@override String websiteLoadFailed({required Object reason}) => 'Stránku sa nepodarilo načítať: ${reason}';
	@override String get remoteScreenDescription => 'Obrazovka, aplikácia alebo okno zdieľané iným z vašich zariadení.';
	@override String get remoteScreenTarget => 'Obrazovka';
	@override String get remoteScreenChoose => 'Vybrať obrazovku…';
	@override String get remoteScreenPickerTitle => 'Zdieľané obrazovky';
	@override String get remoteScreenPickerEmpty => 'Žiadne z vašich zariadení nezdieľa obrazovku. Na zariadení, ktoré chcete vidieť, zapnite Zdieľať obrazovky a okná v Nastavenia → Partnerské zariadenia.';
	@override String get remoteScreenUnset => 'Nie je vybraná žiadna obrazovka. Otvorte nastavenia tohto panelu a vyberte jednu, ktorú zdieľajú vaše iné zariadenia.';
	@override String get remoteScreenConnecting => 'Pripája sa…';
	@override String get remoteScreenPeerAway => 'Toto zariadenie práve nie je pripojené.';
	@override String get remoteScreenNotOffered => 'Toto zariadenie prestalo zdieľať túto obrazovku.';
	@override String get remoteScreenNoListener => 'Toto zariadenie nemôže prijímať pripojenia — skontrolujte jeho firewall.';
	@override String get remoteScreenNoLan => 'Obrazovky sa zdieľajú iba cez lokálnu sieť, nie cez Bluetooth.';
	@override String get remoteScreenRefused => 'Toto zariadenie odmietlo zdieľať túto obrazovku.';
	@override String get remoteScreenSettings => 'Nastavenia panelu';
	@override String get remoteScreenAdjust => 'Upraviť zobrazenie';
	@override String get remoteScreenDetail => 'Detail';
	@override String get remoteScreenDetailStandard => 'Štandardný';
	@override String get remoteScreenDetailHigh => 'Vysoký';
	@override String get remoteScreenDetailMaximum => 'Maximálny';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Priblížiť';
	@override String get remoteScreenZoomOut => 'Oddialiť';
	@override String get remoteScreenStopped => 'Táto obrazovka alebo okno sa už nezobrazuje.';
	@override String get remoteScreenCaptureFailed => 'Toto zariadenie nedokázalo zachytiť obrazovku — možno potrebuje povolenie na nahrávanie obrazovky.';
	@override String get remoteScreenNoAnswer => 'Toto zariadenie neodpovedalo. Možno nemá zapnuté zdieľanie obrazovky.';
	@override String get remoteScreenNoMedia => 'Nepodarilo sa otvoriť spojenie pre obraz. Skontrolujte firewall na tomto zariadení.';
	@override String get solarDescription => 'Slnečné a geomagnetické podmienky so šírením na jednotlivých pásmach';
	@override String get solarUnreachable => 'hamqsl.com je nedostupné — nie je sieť? Čoskoro to skúsime znova.';
	@override String get solarUnreadable => 'hamqsl.com odpovedalo, ale nie údajmi, ktoré by sme mohli použiť. Čoskoro to skúsime znova.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Deň';
	@override String get solarBandNight => 'Noc';
	@override String get solarBandGood => 'Dobré';
	@override String get solarBandFair => 'Priemerné';
	@override String get solarBandPoor => 'Slabé';
	@override String solarSources({required Object primary, required Object secondary}) => 'Zdroje: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Spojenie má problémy — vynechávajú sa snímky.';
	@override String get remoteScreenStalled => 'Snímky prestali prichádzať — toto spojenie môže byť príliš pomalé.';
	@override String get radioDescription => 'Predný panel rádiostanice — frekvencia, mód a výkon, cez ovládanie CAT';
	@override String get radioStyle => 'Štýl';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderný';
	@override String get radioRadio => 'Rádiostanica';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — nie je určená rádiostanica';
	@override String get radioNoRadio => 'Žiadna rádiostanica na zobrazenie. Vyberte ju v nastaveniach tohto panelu alebo ju pridajte v Konfigurácii stanice.';
	@override String get radioNotConfigured => 'Táto rádiostanica ešte nie je nakonfigurovaná. Vyberte jej port alebo adresu v Konfigurácii stanice.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Rádiostanica nie je pripojená';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Pripojiť túto rádiostanicu';
	@override String get radioDisconnect => 'Odpojiť túto rádiostanicu';
	@override String get radioStale => 'BEZ DÁT';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'vysoké SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$sk extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Použiť krátke názvy súborov';
	@override String get descriptionOn => 'Krátke názvy pre nahrávacie nástroje, napr. N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Čitateľné názvy, napr. 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$sk extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zahrnúť súkromné údaje';
	@override String get descriptionOn => 'Mená, adresy, e-maily, lokátory a poznámky sú zahrnuté';
	@override String get descriptionOff => 'Mená, adresy, e-maily, lokátory a poznámky sú vynechané';
	@override String get note => 'Úplný export ADIF vždy obsahuje všetko';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$sk extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Najprv pridajte e-mailovú adresu';
	@override String get needsEmailBody => 'Ham2K úschovňa súborov posiela vaše súbory na e-mailovú adresu vášho účtu LoFi a pomocou nej sa prihlasujete na stash.ham2k.net. Váš účet ešte nemá potvrdenú adresu — pridajte ju v Nastavenia › Cloudová synchronizácia.';
	@override String get openSyncSettings => 'Otvoriť cloudovú synchronizáciu';
	@override String get replaceTitle => 'Nedávna úschova bude nahradená';
	@override String replaceBody({required Object name}) => '„${name}“ ste odoslali pred menej ako 6 hodinami a ešte nebol stiahnutý. Bezplatné účty môžu mať naraz iba jednu úschovu, takže odoslanie teraz ju nahradí.';
	@override String get replaceConfirm => 'Napriek tomu odoslať';
	@override String get failedTitle => 'Nepodarilo sa odoslať do Ham2K úschovne súborov';
	@override String get sentTitle => 'Odoslané do Ham2K úschovne súborov';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Tento súbor si môžete prevziať návštevou **[stash.ham2k.net](https://stash.ham2k.net)** v ľubovoľnom prehliadači.',
		other: 'Tieto súbory si môžete prevziať návštevou **[stash.ham2k.net](https://stash.ham2k.net)** v ľubovoľnom prehliadači.',
	);
	@override String get mayHaveArrived => 'Úschovňa neodpovedá — súbor mohol aj tak doraziť. Pred ďalším odoslaním skontrolujte stash.ham2k.net';
	@override String get notSent => 'neodoslané';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Tento súbor nedorazil:',
		other: 'Týchto ${count} súborov nedorazilo:',
	);
	@override String get emailOffer => 'Alebo vám pre pohodlie môžeme poslať e-mail s priamym odkazom.';
	@override String get emailMe => 'Poslať mi odkaz e-mailom';
	@override String get emailSent => 'Poslali sme vám e-mailom odkaz na stiahnutie.';
	@override String emailFailed({required Object error}) => 'E-mail sa nepodarilo odoslať: ${error}';
	@override String get freeTier => 'Bezplatné účty môžu mať naraz uloženú iba jednu úschovu. Predplatitelia ich môžu mať toľko, koľko chcú.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count,
		one: 'Odoslaný ${count} súbor do Ham2K úschovne súborov (stash.ham2k.net)',
		other: 'Odoslaných ${count} súborov do Ham2K úschovne súborov (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$sk extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Ázia';
	@override String get eu => 'Európa';
	@override String get na => 'Severná Amerika';
	@override String get oc => 'Oceánia';
	@override String get sa => 'Južná Amerika';
	@override String get an => 'Antarktída';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$sk extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrovať spoty';
	@override String get band => 'Pásmo';
	@override String get mode => 'Mód';
	@override String get age => 'Vek';
	@override String get sources => 'Zdroje';
	@override String get continent => 'Kontinent';
	@override String get sorting => 'Triedenie';
	@override String get sortByTime => 'Podľa času spotu';
	@override String get sortByFrequency => 'Podľa frekvencie';
	@override String get groupByBand => 'Zoskupiť podľa pásma';
	@override String get groupCallsWithNotes => 'Zoskupiť volacie znaky s poznámkami';
	@override String get sourceNoReply => 'Bez odpovede';
	@override String get sourceError => 'Chyba';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$sk extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Panel logovania je obsadený';
	@override String get editingBody => 'Upravujete zapísané spojenie. Zapísať namiesto toho tento spot, alebo sa vrátiť a dokončiť úpravu?';
	@override String get composingBody => 'Začali ste zadávať spojenie. Zapísať namiesto toho tento spot, alebo sa vrátiť a dokončiť, čo ste písali?';
	@override String get goBack => 'Vrátiť sa';
	@override String get clearAndLog => 'Vymazať a zapísať spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$sk extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mód pre ľavákov';
	@override String get descriptionOn => 'Používa sa rozloženie pre ľavákov';
	@override String get descriptionOff => 'Používa sa rozloženie pre pravákov';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$sk extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vlajky krajín';
	@override String get dx => 'Zobraziť iba pre DX spojenia';
	@override String get all => 'Zobraziť vlajky pre všetky spojenia';
	@override String get none => 'Nezobrazovať žiadne vlajky';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$sk extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Zobrazujú sa vlajky iba pre DX spojenia';
	@override String get all => 'Zobrazujú sa vlajky pre všetky spojenia';
	@override String get none => 'Nezobrazujú sa žiadne vlajky';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$sk extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Navrhnúť operátora';
	@override String get descriptionOn => 'Váš volací znak sa ponúka ako operátor, keď prevádzka beží pod iným volacím znakom stanice';
	@override String get descriptionOff => 'Operátor zostane prázdny, kým ho nevyplníte';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$sk extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobrazovať azimut';
	@override String get descriptionOn => 'Zobrazuje sa odhadovaný azimut k stanici';
	@override String get descriptionOff => 'Informácie o azimute sa nezobrazujú';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$sk extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobraziť aj spätný azimut';
	@override String get descriptionOn => 'Zobrazuje sa aj azimut od stanice, napríklad „45° / 225°“';
	@override String get descriptionOff => 'Zobrazuje sa iba azimut k stanici';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$sk extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Prepnúť poradie reportov signálu';
	@override String get sentFirst => 'Odoslaný ako prvý, prijatý ako druhý';
	@override String get rcvdFirst => 'Prijatý ako prvý, odoslaný ako druhý';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$sk extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Prejsť na ďalšie pole po zadaní RST';
	@override String get descriptionOn => 'Po zadaní RST sa prechádza ďalej';
	@override String get descriptionOff => 'Automaticky sa neprechádza ďalej';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$sk extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Predvolený report — fónia';
	@override String get description => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri SSB, FM alebo AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$sk extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Predvolený report — CW a dáta';
	@override String get description => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri CW, RTTY a iných dátových módoch';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$sk extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Predvolený report — FT8 a FT4';
	@override String get description => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri módoch FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$sk extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Riadok s číslami';
	@override String get description => 'Pri logovaní zobraziť nad klávesnicou riadok s číselnými klávesmi';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$sk extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kláves lomky a bodky';
	@override String get description => 'Pridá kontextový kláves: „/“ pre volacie znaky, „.“ pre čísla';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$sk extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrovať pri stlačení';
	@override String get description => 'Hmatová odozva pri ťuknutí na číselný kláves';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$sk extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get off => 'Vypnuté';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$sk extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$sk extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ovládať PTT klávesom [\']';
	@override String get descriptionOn => 'Vo fóniových módoch [\'] zaklúčuje rádiostanicu a ďalšie [\'] ju odkľúčuje. Po minúte sa odkľúčuje sama.';
	@override String get descriptionOff => 'Kláves [\'] rádiostanicu nezaklúčuje.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Vysiela sa';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$sk extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inteligentné zaokrúhľovanie VFO';
	@override String get descriptionOn => 'Keď prestanete otáčať ladiacim gombíkom, frekvencia sa zaokrúhli na rozumný krok. Iba hlasové módy.';
	@override String get descriptionOff => 'Frekvencia zostane presne tam, kam ste naladili.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$sk extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zaokrúhľovanie: oneskorenie ustálenia';
	@override String get description => 'Ako dlho musí gombík stáť, kým sa frekvencia zaokrúhli. Kratšie pôsobí okamžite, dlhšie nechá priestor na pomalý pohyb.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$sk extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zaokrúhľovanie: dlhý pohyb';
	@override String get description => 'Pri pohybe aspoň o túto hodnotu sa frekvencia zaokrúhli na celé kHz, nech ste skončili akokoľvek pomaly.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$sk extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zaokrúhľovanie: najmenší pohyb';
	@override String get description => 'Pri pohybe menšom ako táto hodnota sa frekvencia nezaokrúhli, takže jemné ladenie zostane nedotknuté.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$sk extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zaokrúhľovanie: najpomalší pohyb';
	@override String get description => 'Ak otáčate gombíkom pomalšie, frekvencia sa nezaokrúhli, pokiaľ nešlo o dlhý pohyb.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$sk extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM vyp.';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter odosiela správy';
	@override String get off => 'Vyp.';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter odosiela správy: ${state}. Ťuknutím zmeníte.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$sk extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rýchlosť kľúčovača';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$sk extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Správy CW kľúčovača';
	@override String get notSupported => 'Aktuálna rádiostanica nepodporuje kľúčovanie CW';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Správa (${n})';
	@override String get labelField => 'Popis';
	@override String labelKey({required Object n}) => 'Popis F${n}';
	@override String get details => 'Podrobnosti';
	@override String get empty => '(prázdne)';
	@override String get sets => 'Sada správ';
	@override String get newSet => 'Nová sada';
	@override String get renameSet => 'Premenovať sadu';
	@override String get deleteSet => 'Odstrániť sadu';
	@override String get newSetName => 'Názov';
	@override String get setDefault => 'Predvolená';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Správy ESM';
	@override String get setSaved => 'Moje správy';
	@override String get repeat => 'Opakovať správu č. 1';
	@override String get repeatOff => 'Nie';
	@override String repeatAfter({required Object n}) => 'Po ${n} sekundách';
	@override String get repeatWait => 'Opakuje sa';
	@override String get keyboard => 'Píšte a odošle sa';
	@override String get keyboardField => 'Píšte a odošle sa';
	@override String get closeArea => 'Zatvoriť oblasť kľúčovača';
	@override String get help => 'Pomocník';
	@override String get helpTitle => 'Písanie CW správ';
	@override String get helpIntro => 'Správy môžu používať šablóny s týmito hodnotami:';
	@override String get helpOpCall => 'Váš volací znak';
	@override String get helpQsoCall => 'Ich volací znak — v zásobníku // značka, ktorá sa zapíše';
	@override String get helpQsoFullCall => 'Ich volací znak, ak je platný; prázdne pri čiastočnom';
	@override String get helpQsoPartial => 'Čiastočný volací znak; prázdne, ak je úplný platný znak';
	@override String get helpQsoNextCall => 'V zásobníku // značka, ktorá sa vyberie na zápis ako ďalšia, ak je platná a úplná';
	@override String get helpQsoNextPartial => 'V zásobníku // ďalší čiastočný znak po zápise aktuálneho spojenia';
	@override String get helpQsoName => 'Ich krstné meno, ako bolo zadané, inak z vyhľadávania';
	@override String get helpQsoState => 'Ich štát, ako bol zadaný, inak z vyhľadávania';
	@override String get helpKeyerMsg => 'Správa 1 tak, ako by sa odoslala, vo vnútri inej správy. Platí pre správy 1 až 8';
	@override String get helpQsoRst => 'Report, ktorý odosielate';
	@override String get helpQsoSerial => 'Vaše poradové číslo v súťaži, ktorá ho posiela';
	@override String get helpPad => 'Doplní nulami na daný počet číslic: 7 sa odošle ako 007';
	@override String get helpCut => 'Skrátené číslice, T pre 0 a N pre 9: 599 sa odošle ako 5NN';
	@override String get helpCutDigits => 'Vyberá číslice na skrátenie, v úvodzovkách — 0 je T, 1 je A, 5 je E, 9 je N';
	@override String get helpFullExample => 'Úplný príklad:';
	@override String get helpExample => 'Odošle W1AW 5NN TT7';
	@override String get helpEsmIntro => 'So zapnutým Enter odosiela správy kláves Enter vysiela správy podľa ich funkčného klávesu, ako v N1MM. Sada Správy ESM začína týmito:';
	@override String get helpEsmCq => 'Pri Run Enter s prázdnym poľom volacieho znaku volá CQ';
	@override String get helpEsmExchange => 'Vaša výmena: pri Run po ich volacom znaku, pri S&P potom, ako odpovedia';
	@override String get helpEsmThanks => 'Poďakovanie po zapísaní spojenia: jeho zástupné symboly označujú ďalšie spojenie, nie toto';
	@override String get helpEsmMyCall => 'Pri S&P váš volací znak pre stanicu, ktorej odpovedáte';
	@override String get helpEsmHisCall => 'Pri Run ich volací znak pred vašou výmenou';
	@override String get helpEsmAgain => 'Opýta sa znova, keď z ich výmeny nebolo nič prijaté';
	@override String get helpEsmStackThanks => 'Navrhované F3 pre zásobníky //: TU sa odošle po zapísaní spojenia, takže poďakuje, potom zavolá ďalšiu stanicu v zásobníku a odošle vašu výmenu, alebo sa opýta na čiastočný znak (TU KR?); ak už nič nezostáva, iba TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$sk extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Správy fóniového kľúčovača';
	@override String get notSupported => 'Aktuálna rádiostanica nepodporuje fóniové správy';
	@override String get description => 'Používa hlasové pamäte rádiostanice';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Hlasová pamäť (${n})';
	@override String get labelField => 'Popis';
	@override String labelKey({required Object n}) => 'Popis hlasovej pamäte ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Prázdna';
	@override String get notMeasured => 'Neznáma dĺžka';
	@override String get playButton => 'Prehrať';
	@override String get recordButton => 'Nahrať';
	@override String get stopButton => 'Stop';
	@override String get repeat => 'Opakovať správu č. 1';
	@override String get repeatOff => 'Nie';
	@override String repeatAfter({required Object n}) => 'Po ${n} sekundách';
	@override String recordHelpTitle({required Object model}) => 'Poznámky k ${model}:';
	@override String namedOnDevice({required Object device}) => 'Tieto pamäte sú v rádiostanici zariadenia ${device}. Ich názvy a dĺžky patria tomuto zariadeniu.';
	@override String get namedOnRadio => 'Uložené v rádiostanici, kde ich vidia aj jej ostatní klienti.';
	@override String get recordHelpYaesuDvs => 'Počkajte na indikátor [REC] na rádiostanici, potom podržte tlačidlo PTT a nahrajte správu. Ukončite ju stlačením tlačidla STOP tu v aplikácii ešte pred uvoľnením PTT, aby ste predišli nechceným cvaknutiam.';
	@override String get recordHelpFt891 => 'Počkajte, kým indikátor [REC] blikne aspoň štyrikrát, potom podržte tlačidlo PTT a nahrajte správu. Ukončite ju stlačením tlačidla STOP tu v aplikácii ešte pred uvoľnením PTT, aby ste predišli nechceným cvaknutiam.';
	@override String get pill => 'Hlas';
	@override String play({required Object n}) => 'Prehrať pamäť ${n}';
	@override String get stop => 'Stop';
	@override String record({required Object n}) => 'Nahrať pamäť ${n}';
	@override String get stopRecording => 'Zastaviť nahrávanie';
	@override String get playing => 'Prehráva sa…';
	@override String get recording => 'Nahráva sa…';
	@override String playingMemory({required Object label}) => 'Prehráva sa ${label}';
	@override String recordingMemory({required Object label}) => 'Nahráva sa ${label}';
	@override String get doubtful => 'Prehrala ju rádiostanica? Hneď hlásila, že je nečinná.';
	@override String get recordOnRadio => 'Pamäte musíte nahrať priamo na rádiostanici.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$sk extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vyhnúť sa zázneju na spotoch';
	@override String get descriptionOn => 'S pripojenou rádiostanicou sa ladí o pár Hz vedľa CW spotu, aby všetci, ktorí naň odpovedajú, nevolali na rovnakom tóne.';
	@override String get descriptionOff => 'Ladí sa presne na spotovanú frekvenciu.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$sk extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Záznej: rozsah vyhýbania';
	@override String get description => 'Ako ďaleko od spotovanej frekvencie pristáť, na ktorúkoľvek stranu. Posun nikdy nie je blízko nuly — to by bol opäť nulový záznej.';
}

// Path: settings.map.style
class _Translations$settings$map$style$sk extends Translations$settings$map$style$en {
	_Translations$settings$map$style$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Štýl mapy';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$sk extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatický';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$sk extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zdieľať údaje o používaní aplikácie';
	@override String get descriptionOn => 'Pomáhate nám zlepšovať aplikáciu zdieľaním údajov o používaní, konfigurácii, zlyhaniach a výkone';
	@override String get descriptionOff => 'Údaje o používaní aplikácie zostávajú súkromné.\nTím Ham2K nebude môcť zistiť zlyhania ani iné problémy.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$sk extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zdieľať údaje o prevádzke';
	@override String get descriptionOn => 'Niektoré údaje o prevádzke sa zdieľajú verejne a s inými používateľmi';
	@override String get descriptionOff => 'Údaje o prevádzke zostávajú súkromné';
}

// Path: settings.station.models
class _Translations$settings$station$models$sk extends Translations$settings$station$models$en {
	_Translations$settings$station$models$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - všeobecná';
	@override String get icomGeneric => 'Icom - všeobecná';
	@override String get kenwoodGeneric => 'Kenwood - všeobecná';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - všeobecná';
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
	@override String get rigctld => 'Rádiostanica ovládaná cez rigctld';
	@override String get rigctldNodeName => 'Moja rádiostanica (cez rigctld)';
	@override String get flrig => 'Rádiostanica ovládaná cez flrig';
	@override String get flrigNodeName => 'Moja rádiostanica (cez flrig)';
	@override String get hrd => 'Rádiostanica ovládaná cez Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Moja rádiostanica (cez HRD)';
	@override String get n3fjp => 'Rádiostanica ovládaná cez N3FJP';
	@override String get n3fjpNodeName => 'Moja rádiostanica (cez N3FJP)';
	@override String get commander => 'Rádiostanica ovládaná cez DXLab Commander';
	@override String get commanderNodeName => 'Moja rádiostanica (cez Commander)';
	@override String get antenna => 'Anténa';
	@override String get key => 'CW kľúč';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Všeobecná rádiostanica (zástupná)';
	@override String get placeholderRadioNodeName => 'Moja rádiostanica';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$sk extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get network => 'Sieť/WiFi';
	@override String get usbSerial => 'USB sériový';
	@override String get wifi => 'Sieť/WiFi';
	@override String get bluetoothSerial => 'Bluetooth sériový';
	@override String get placeholder => 'Zástupné';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$sk extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipól';
	@override String get vertical => 'Vertikál';
	@override String get yagiBeam => 'Yagi / smerovka';
	@override String get loop => 'Slučka';
	@override String get longWire => 'Dlhý drôt / EFHW';
	@override String get other => 'Iná';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$sk extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Ručný kľúč';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mechanický poloautomat)';
	@override String get fullyAutomatic => 'Plne automatický kľúčovač';
	@override String get singlePaddle => 'Jednopádlový kľúč';
	@override String get dualPaddle => 'Dvojpádlový kľúč';
	@override String get computerDriven => 'Riadený počítačom';
	@override String get other => 'Iný';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$sk extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$sk._(TranslationsSk root) : this._root = root, super.internal(root);

	final TranslationsSk _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Neznáme';
	@override String get sunny => 'Slnečno';
	@override String get clear => 'Jasno';
	@override String get mainlySunny => 'Prevažne slnečno';
	@override String get mainlyClear => 'Prevažne jasno';
	@override String get partlyCloudy => 'Polojasno';
	@override String get cloudy => 'Zamračené';
	@override String get foggy => 'Hmla';
	@override String get rimeFog => 'Mrznúca hmla';
	@override String get lightDrizzle => 'Slabé mrholenie';
	@override String get drizzle => 'Mrholenie';
	@override String get heavyDrizzle => 'Silné mrholenie';
	@override String get lightFreezingDrizzle => 'Slabé mrznúce mrholenie';
	@override String get freezingDrizzle => 'Mrznúce mrholenie';
	@override String get lightRain => 'Slabý dážď';
	@override String get rain => 'Dážď';
	@override String get heavyRain => 'Silný dážď';
	@override String get lightFreezingRain => 'Slabý mrznúci dážď';
	@override String get freezingRain => 'Mrznúci dážď';
	@override String get lightSnow => 'Slabé sneženie';
	@override String get snow => 'Sneženie';
	@override String get heavySnow => 'Silné sneženie';
	@override String get snowGrains => 'Snehové zrná';
	@override String get lightShowers => 'Slabé prehánky';
	@override String get showers => 'Prehánky';
	@override String get heavyShowers => 'Silné prehánky';
	@override String get lightSnowShowers => 'Slabé snehové prehánky';
	@override String get snowShowers => 'Snehové prehánky';
	@override String get thunderstorm => 'Búrka';
	@override String get lightThunderstormsWithHail => 'Slabé búrky s krupobitím';
	@override String get thunderstormWithHail => 'Búrka s krupobitím';
}

/// The flat map containing all translations for locale <sk>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsSk {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Uložiť',
			'common.ok' => 'OK',
			'common.cancel' => 'Zrušiť',
			'common.delete' => 'Odstrániť',
			'common.create' => 'Vytvoriť',
			'common.error' => 'Chyba',
			'common.close' => 'Zatvoriť',
			'common.done' => 'Hotovo',
			'common.callsign' => 'Volací znak',
			'common.clear' => 'Vymazať',
			'common.dismiss' => 'Zavrieť',
			'common.expand' => 'Rozbaliť',
			'common.collapse' => 'Zbaliť',
			'onboarding.welcomeTitle' => 'Vitajte v Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Vitajte v Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Máme pre vás niekoľko otázok, aby sme aplikáciu lepšie prispôsobili vašim potrebám.',
			'onboarding.skip' => 'Preskočiť',
			'onboarding.kContinue' => 'Pokračovať',
			'onboarding.back' => 'Späť',
			'onboarding.next' => 'Ďalej',
			'onboarding.done' => 'Hotovo',
			'onboarding.callsignTitle' => 'Aký je váš volací znak?',
			'onboarding.callsignBody' => 'Aby vám bola táto aplikácia užitočná, potrebujete licenciu rádioamatéra',
			'onboarding.callsignLabel' => 'Volací znak operátora',
			'onboarding.alreadyHaveAccount' => 'Už máte účet?',
			'onboarding.foundSiblingTitle' => 'Prepojiť existujúci účet?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Na tomto zariadení sme našli ${app}. Prepojte túto aplikáciu s rovnakým účtom a prenesú sa váš volací znak aj denníky.',
			'onboarding.foundPoloBody' => 'Na tomto zariadení sme našli staršiu verziu Ham2K Portable Logger. Prepojte túto aplikáciu s rovnakým účtom a prenesú sa váš volací znak aj denníky.',
			'onboarding.foundSiblingsBody' => 'Na tomto zariadení sme našli iné aplikácie Ham2K. Prepojte túto aplikáciu s účtom jednej z nich a prenesú sa váš volací znak aj denníky.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Prepojiť s ${app}',
			'onboarding.linkWithPolo' => 'Prepojiť s účtom zo staršej verzie',
			'onboarding.setUpFresh' => 'Nastaviť od začiatku',
			'onboarding.activitiesTitle' => 'Obľúbené aktivity',
			'onboarding.activitiesBody' => 'Zaujímajú vás niektoré z týchto populárnych aktivačných programov?',
			'onboarding.activitiesFooter' => '(Ďalšie možnosti nájdete v Nastaveniach)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Údaje a súkromie',
			'onboarding.consentUsageBody' => 'Aby sme mohli aplikáciu zlepšovať, radi by sme zbierali údaje o výkone, zlyhaniach a používaní aplikácie.',
			'onboarding.consentUsageLabel' => 'Zdieľať údaje o používaní aplikácie',
			'onboarding.consentOperationBody' => 'Niektoré funkcie môžu zahŕňať zdieľanie údajov o vašej prevádzke s inými používateľmi. Kedykoľvek to môžete vypnúť.',
			'onboarding.consentOperationLabel' => 'Zdieľať údaje o prevádzke',
			'onboarding.finishingSetup' => 'Dokončuje sa nastavenie — sťahujú sa referenčné údaje…',
			'startScreen.credits' => 'od KI2D a priateľov',
			'testerOverlay.tape' => 'POZOR: STAVENISKO',
			'testerOverlay.warningTitle' => 'Táto aplikácia je rozpracovaná',
			'testerOverlay.warningBody' => 'Väčšina funkcií má nerovný povrch a všade hrozí zakopnutie. Pravidelne kontrolujte aktualizácie.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novinky v zostave ${build}',
			'testerOverlay.thanks' => 'Ďakujeme, že riskujete svoj denník, aby ste nám pomohli túto aplikáciu zlepšiť!',
			'extensionsPanel.categoryActivity' => 'Aktivity',
			'extensionsPanel.categoryContest' => 'Súťaže',
			'extensionsPanel.categoryLookup' => 'Vyhľadávanie volacích znakov',
			'extensionsPanel.categorySpots' => 'Zdroje spotov',
			'extensionsPanel.categoryDashboard' => 'Panely prehľadu',
			'extensionsPanel.categoryOther' => 'Ostatné rozšírenia',
			'extensionsPanel.searchHint' => 'Hľadať rozšírenia',
			'extensionsPanel.applying' => 'Aktivujú sa zmeny rozšírení, môže to chvíľu trvať…',
			'extensionsPanel.noMatches' => 'Hľadaniu nezodpovedajú žiadne rozšírenia',
			'extensionsPanel.installFromFile' => 'Inštalovať zo súboru…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Verzia ${version}',
			'extensionsPanel.canReach' => 'Toto rozšírenie môže kontaktovať',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, cez trvalé spojenie',
			'extensionsPanel.canHoldLocalConnection' => 'Zariadenia vo vašej lokálnej sieti, cez trvalé spojenie',
			'extensionsPanel.canUseLocation' => 'Vašu polohu',
			'extensionsPanel.canReadRadio' => 'Vašu rádiostanicu, na čítanie frekvencie a módu',
			'extensionsPanel.canControlRadio' => 'Vašu rádiostanicu, na jej ovládanie a vysielanie — ladenie, výkon, CW, hlasové pamäte a PTT',
			'extensionsPanel.canSetUserAgent' => 'Predstaviť sa serverom pod vlastným menom',
			'extensionsPanel.noCapabilities' => 'Nepožaduje nič mimo aplikácie.',
			'extensionsPanel.sandboxNote' => 'Rozšírenia bežia v izolovanom prostredí: bez prístupu k vašim súborom a bez siete okrem toho, čo je tu uvedené.',
			'extensionsPanel.installAction' => 'Inštalovať',
			'extensionsPanel.updateAction' => 'Aktualizovať',
			'extensionsPanel.installFailed' => 'Toto rozšírenie sa nepodarilo nainštalovať',
			'extensionsPanel.installedBadge' => 'Nainštalované',
			'extensionsPanel.uninstallAction' => 'Odstrániť',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Odstrániť ${name}?',
			'extensionsPanel.uninstallBody' => 'Toto rozšírenie a jeho nastavenia budú odstránené. Vaše denníky zostanú nedotknuté.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'Nainštalované ${name}',
			'extensionsPanel.installDownloading' => 'Sťahovanie…',
			'extensionsPanel.installWaiting' => 'Čaká sa na inštaláciu…',
			'extensionsPanel.installInstalling' => 'Inštalácia…',
			'extensionsPanel.installAwaitingApproval' => 'Čaká sa na vaše schválenie…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} sa už inštaluje.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Aktualizované na ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Inštalácia ${name} sa nedokončila. Možno bude potrebné nainštalovať ho znova.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name} sa nepodarilo odstrániť',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Stiahnuté z ${source}',
			'extensionsPanel.dropHint' => 'Pustite sem rozšírenie .h2kext a nainštaluje sa',
			'extensionsPanel.dropOneOnly' => 'Pustite naraz iba jedno rozšírenie.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} pre toto rozšírenie vrátil ${status}.',
			'extensionsPanel.downloadTooLarge' => 'Toto sťahovanie je príliš veľké na to, aby to bolo rozšírenie.',
			'extensionsPanel.downloadNotSecure' => 'Toto sťahovanie bolo presmerované na nezabezpečené miesto.',
			'extensionsPanel.catalogSection' => 'Katalóg',
			'extensionsPanel.catalogLoading' => 'Načítava sa katalóg…',
			'extensionsPanel.catalogUnreachable' => 'Katalóg je nedostupný',
			'extensionsPanel.builtIn' => 'Vstavané',
			'extensionsPanel.updateAvailableBadge' => 'Aktualizácia dostupná',
			'extensionsPanel.updatesAvailableTitle' => 'Aktualizácie rozšírení',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Pre ${name} je dostupná aktualizácia.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} a ďalšie (${count}) potrebujú aktualizáciu.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} potrebujú aktualizáciu.',
			'extensionsPanel.pendingUpdatesSection' => 'Čakajúce aktualizácie',
			'extensionsPanel.updateAllAction' => 'Aktualizovať všetko',
			'extensionsPanel.updatesUnderWay' => 'Tieto aktualizácie už prebiehajú.',
			'extensionsPanel.updatesNothingLeft' => 'Vaše rozšírenia sú aktuálne.',
			'extensionsPanel.updatesNoticeAction' => 'Viac informácií',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Aktualizovať ${count} rozšírenie?', other: 'Aktualizovať ${count} rozšírení?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Vaše rozšírenia sú pripravené',
			'extensionsPanel.upgradeDoneBody' => 'Teraz pochádzajú z katalógu rozšírení Ham2K, takže sa môžu aktualizovať bez čakania na novú verziu aplikácie.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Neaktualizované: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Nespustili sa: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Stále sú nainštalované a označené v Nastavenia › Rozšírenia — ich aktualizáciou tam ich obnovíte.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Katalóg za ne nemá priamu náhradu, preto v ňom hľadajte rozšírenia, ktoré pokrývajú to, čo ste používali.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Podujatia State Parks',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => 'Niektoré vaše rozšírenia (${count}) ešte nedorazili. Stiahnu sa, keď bude katalóg rozšírení nabudúce dostupný.',
			'extensionsPanel.runtimeDeadBody' => 'Vaše rozšírenia sa nespustili. Reštart aplikácie by ich mal obnoviť.',
			'extensionsPanel.refusedTitle' => 'Niektoré rozšírenia sa nespustili',
			'extensionsPanel.upgradeBusyTitle' => 'Nastavenie stále prebieha',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Vaše rozšírenia nebežia',
			'extensionsPanel.restoreTitle' => 'Niektoré vaše rozšírenia chýbajú',
			'extensionsPanel.restoreBody' => 'Tieto rozšírenia, ktoré ste nainštalovali, nie sú na tomto zariadení. Môžeme ich znova stiahnuť z katalógu rozšírení Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Nainštalované zo súboru. Nainštalujte ich znova z ich súborov alebo ich zabudnite:',
			'extensionsPanel.restoreOtherCatalog' => 'Nainštalované z iného katalógu rozšírení, preto tu nie sú dostupné:',
			'extensionsPanel.restoreForget' => 'Zabudnúť',
			'extensionsPanel.restoreInstall' => 'Inštalovať',
			'extensionsPanel.restoreLater' => 'Neskôr',
			'extensionsPanel.restoreInstalling' => 'Inštalujú sa vaše rozšírenia…',
			'extensionsPanel.restoreDoneTitle' => 'Vaše rozšírenia sú späť',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Znova nainštalované: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Niektoré rozšírenia sa nepodarilo nainštalovať',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Nepodarilo sa nainštalovať: ${names}. Ponúkneme ich znova pri ďalšom otvorení aplikácie.',
			'extensionsPanel.restoreBusyBody' => 'Aplikácia stále nastavuje vaše rozšírenia. Ponúkneme ich znova pri ďalšom otvorení aplikácie.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Znova sme ich nainštalovali, ale vaše rozšírenia sa nespustili. Reštart aplikácie by ich mal obnoviť.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} bolo stiahnuté',
			'extensionsPanel.revokedBody' => 'Katalóg túto verziu stiahol, preto bola vypnutá.',
			'extensionsPanel.downloadHashMismatch' => 'Toto sťahovanie nie je rozšírenie, ktoré opísal katalóg.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Katalóg nemá verziu ${version} rozšírenia ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Tento odkaz do katalógu neurčuje verziu rozšírenia.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Katalóg nemá na tejto vetve žiadne vydanie ${key}.',
			'extensionsPanel.installFromLink' => 'Inštalovať z odkazu',
			'extensionsPanel.unstableReleaseWarning' => 'Toto je nestabilné vydanie, ktoré jeho vydavateľ neoznačil za hotové. Môže sa správať nesprávne a bude naďalej dostávať nestabilné aktualizácie.',
			'extensionsPanel.bleedingReleaseWarning' => 'Toto je najnovšie vývojové vydanie: rozpracovaná práca, ktorá sa môže pokaziť alebo stratiť nastavenia. Bude naďalej dostávať najnovšie vývojové aktualizácie.',
			'extensionsPanel.channelUnstable' => 'Nestabilné',
			'extensionsPanel.channelBleeding' => 'Vývojové',
			'extensionsPanel.followsUnstable' => 'Dostáva nestabilné a stabilné vydania',
			'extensionsPanel.followsBleeding' => 'Dostáva vývojové, nestabilné a stabilné vydania',
			'extensionsPanel.followStableAction' => 'Sledovať iba stabilné vydania',
			'extensionsPanel.revokedBadge' => 'Stiahnuté',
			'extensionsPanel.refusedBadge' => 'Nenačítalo sa',
			'extensionsPanel.downloadNotHttps' => 'Toto sťahovanie neprebieha cez zabezpečené spojenie.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} pre toto rozšírenie nie je dostupný.',
			'extensionsPanel.detailsAction' => 'Podrobnosti',
			'extensionsPanel.installedFromFile' => 'Nainštalované zo súboru',
			'extensionsPanel.detailsWhatItDoes' => 'Poskytuje podporu pre',
			'extensionsPanel.installedPreloaded' => 'Predinštalované',
			'extensionsPanel.hookAccount' => 'Prihlásenie do účtu',
			'extensionsPanel.hookCallNotes' => 'Poznámky k volacím znakom',
			'extensionsPanel.hookDataFile' => 'Offline údaje',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Vyhľadávanie volacích znakov',
			'extensionsPanel.hookScoring' => 'Bodovanie',
			'extensionsPanel.hookSpots' => 'Spoty',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Lov ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Aktivácia ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '… a ${count} ďalšie rozšírenie', other: '… a ${count} ďalších rozšírení', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} dostupné rozšírenie', other: '${count} dostupných rozšírení', ), 
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'Nová prevádzka',
			'home.stationCallsign' => 'Volací znak stanice',
			'home.titleOptional' => 'Názov (nepovinné)',
			'home.emptyList' => 'Zatiaľ žiadne prevádzky. Vytvorte jednu a začnite logovať.',
			'home.quickLookup' => 'Rýchle vyhľadávanie',
			'home.nav.operations' => 'Prevádzky',
			'home.nav.chase' => 'Lov',
			'home.nav.logs' => 'Denníky',
			'home.nav.maps' => 'Mapy',
			'home.nav.settings' => 'Nastavenia',
			'home.panels.operations' => 'Zoznam prevádzok',
			'home.panels.operationsDescription' => 'Vaše prevádzky, najnovšie ako prvé.',
			'home.panels.version' => 'Aktuálna verzia',
			'home.panels.versionDescription' => 'Logo Ham2K, názov tejto aplikácie a zostava, ktorú používate.',
			'home.toggleNav' => 'Zobraziť alebo skryť popisy navigácie',
			'home.logs.title' => 'Denníky',
			'home.logs.titleFor' => 'Denníky pre',
			'home.logs.emptyCallsigns' => 'Zatiaľ žiadne zapísané QSO',
			'home.logs.emptyQsos' => ({required Object call}) => 'Žiadne QSO pre ${call}',
			'home.logs.mapNoSelection' => 'Vyberte QSO a zobrazí sa na mape',
			'home.logs.searchHint' => 'Hľadať volací znak alebo meno',
			'home.logs.noSearchMatches' => 'Hľadaniu nezodpovedajú žiadne QSO',
			'home.logs.titleAll' => 'Všetky denníky',
			'home.logs.allCallsigns' => 'Všetky volacie znaky',
			'home.logs.noOperation' => 'Nie je súčasťou prevádzky',
			'home.logs.unsavedTitle' => 'Neuložené zmeny',
			'home.logs.unsavedBody' => 'Toto QSO má zmeny, ktoré ste neuložili.',
			'home.logs.pendingDeleteBody' => 'Toto QSO je označené na vymazanie.',
			'home.logs.editGone' => 'Neuložené: toto QSO už nie je v tomto denníku.',
			'home.logs.discard' => 'Zahodiť',
			'home.logs.columns.date' => 'Dátum',
			'home.logs.columns.time' => 'Čas',
			'home.logs.columns.freq' => 'Frekvencia',
			'home.logs.columns.mode' => 'Mód',
			'home.logs.columns.call' => 'Značka',
			'home.logs.columns.name' => 'Meno',
			'home.logs.columns.station' => 'Stanica',
			'home.logs.columns.band' => 'Pásmo',
			'home.logs.columns.sent' => 'Odoslané',
			'home.logs.columns.rcvd' => 'Prijaté',
			'home.logs.columns.grid' => 'Lokátor',
			'home.logs.columns.state' => 'Štát',
			'home.logs.columns.country' => 'Krajina',
			'home.logs.columns.refs' => 'Ref.',
			'home.logs.panels.qsos' => 'Denník QSO',
			'home.logs.panels.qsosDescription' => 'QSO vybraného volacieho znaku zo všetkých prevádzok.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Celkový počet QSO alebo vyhľadanie volacieho znaku vybraného QSO.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'Poloha vybraného QSO.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Volacie znaky: ${calls}',
			'home.logs.import.skippedOne' => '1 záznam sa nepodarilo prečítať',
			'home.logs.import.skippedOther' => ({required Object count}) => 'Nepodarilo sa prečítať záznamy: ${count}',
			'home.logs.import.readingTitle' => 'Číta sa súbor ADIF…',
			'home.logs.import.checkingTitle' => 'Kontrolujú sa duplikáty…',
			'home.logs.import.importingTitle' => 'Importujú sa QSO…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => 'Skontrolované ${done} z ${total}',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => 'Importované ${imported} z ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'loví',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} a ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} a ďalšie',
			'chase.station.title' => 'Loviaca stanica',
			'chase.station.stationLabel' => 'Stanica: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Bez polohy',
			'chase.periodInline.today' => 'dnes',
			'chase.periodInline.thisWeek' => 'tento týždeň',
			'chase.periodInline.last14Days' => 'za posledných 14 dní',
			'chase.periodInline.thisMonth' => 'tento mesiac',
			'chase.periodStats.today' => 'Štatistiky za dnes',
			'chase.periodStats.thisWeek' => 'Štatistiky za tento týždeň',
			'chase.periodStats.last14Days' => 'Štatistiky za posledných 14 dní',
			'chase.periodStats.thisMonth' => 'Štatistiky za tento mesiac',
			'chase.period.today' => 'Dnes',
			'chase.period.thisWeek' => 'Tento týždeň',
			'chase.period.last14Days' => 'Posledných 14 dní',
			'chase.period.thisMonth' => 'Tento mesiac',
			'chase.goals.title' => 'Ciele lovu',
			'chase.goals.remove' => ({required Object name}) => 'Prestať loviť ${name}',
			'chase.goals.extensionsTitle' => 'Rozšírenia, ktoré zahŕňajú lov',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => 'Ovládanie logovania nad QSO ulovenými v danom období.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Logovaný volací znak alebo štatistiky za obdobie.',
			'chase.panels.spots' => 'Spoty',
			'chase.panels.spotsDescription' => 'Stanice spotované v éteri, pripravené na lov.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'QSO za obdobie a logovaná stanica.',
			'dialogs.operationDetails' => 'Podrobnosti o prevádzke',
			'dialogs.activities' => 'Aktivity',
			'dialogs.stationCallsign' => 'Volací znak stanice',
			'dialogs.multiStationIdentifier' => 'Identifikátor pre viac staníc (iba čísla)',
			'dialogs.notes' => 'Poznámky',
			'dialogs.deleteOperationTitle' => 'Odstrániť prevádzku',
			'dialogs.purgeTestsTitle' => 'Vyčistiť testovacie prevádzky',
			'dialogs.purgeTestsBody' => 'Týmto sa natrvalo vymažú tieto testovacie prevádzky a ich QSO. Nedá sa to vrátiť späť.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Plus ${count} testovacie spojenie, ktoré nepatrí do žiadnej prevádzky.', other: 'Plus ${count} testovacích spojení, ktoré nepatria do žiadnej prevádzky.', ), 
			'dialogs.purgeTestsAction' => 'Vyčistiť',
			'dialogs.syncAllTitle' => 'Nahradiť denník tohto zariadenia?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL zálohuje a vymaže ${qsos} z tohto zariadenia a potom znova stiahne denník účtu zo servera. Záloha zostane v databáze tohto zariadenia.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${n} QSO ešte nie je synchronizované — server ho nikdy neprijal a NEVRÁTI sa.', other: '${n} QSO ešte nie je synchronizovaných — server ich nikdy neprijal a NEVRÁTIA sa.', ), 
			'dialogs.syncAllAction' => 'Vymazať a znova synchronizovať',
			'dialogs.receivedPurgesTitle' => 'Testovacie prevádzky odstránené inde',
			'dialogs.receivedPurgesBody' => 'Tieto boli vymazané ako testovacie prevádzky na inom zariadení. Odstrániť ich aj tu? Týmto sa natrvalo vymažú spolu s ich QSO a nedá sa to vrátiť späť.',
			'dialogs.receivedPurgesAction' => 'Odstrániť',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Neplatný volací znak: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Neplatné volacie znaky: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Doteraz vysielal ${previous}. Pre nové spojenia sa zapíše ${typed}.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Doteraz nie je zapísaný žiadny operátor. Pre nové spojenia sa zapíše ${typed}.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Táto prevádzka už má spojenia od ${calls}. ${typed} sa zapíše iba pre nové.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Zapísať ${typed} ako operátora aj pre už zapísané spojenie', other: 'Zapísať ${typed} ako operátora aj pre všetkých ${count} už zapísaných spojení', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Pri použití viacerých staníc v éteri nie sú samostatní operátori podporovaní',
			'dialogs.callChange.contactsUnreadable' => 'Spojenia tejto prevádzky sa nepodarilo prečítať, preto zmena volacieho znaku tu neponúkne ich aktualizáciu',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Už zapísané spojenia sa nepodarilo aktualizovať, preto sa nič nezmenilo: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => 'Aktualizovaných bolo ${written} z ${planned} spojení — ostatné už nie sú v tejto prevádzke',
			'operation.deletedReadOnly' => 'Táto prevádzka je vymazaná. Obnovte ju, ak chcete logovať alebo robiť zmeny.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTY',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => 'Hodiny',
			'operation.tabs.weather' => 'Počasie',
			'operation.tabs.website' => 'Webová stránka',
			'operation.tabs.remoteScreen' => 'Vzdialená obrazovka',
			'operation.tabs.solar' => 'Slnko',
			'operation.tabs.radio' => 'Rádio',
			'operation.positions.nobodyYet' => 'Túto prevádzku zatiaľ nezdieľajú žiadne iné operátorské pracoviská.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Prac.: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Iné pracovisko',
			'operation.positions.thisDevice' => 'Naše pracovisko',
			'operation.positions.nameIn' => ' v ',
			'operation.positions.panelTitle' => 'Pracoviská',
			'operation.positions.panelDescription' => 'Čo práve loguje každé pracovisko, ktoré zdieľa túto prevádzku.',
			'operation.stationCallsignNone' => 'Bez volacieho znaku stanice',
			'operation.titleNone' => 'Bez názvu',
			'operation.deleteOperation' => 'Odstrániť prevádzku',
			'operation.loggingControlsStale' => 'Polia aktivít môžu byť neaktuálne — znova otvorte prevádzku a obnovia sa',
			'operation.locationNone' => 'Nenastavené',
			'operation.generalOperation' => 'Všeobecná prevádzka',
			'operation.titleFor' => ({required Object value}) => 'pre ${value}',
			'operation.titleAt' => ({required Object value}) => 'na ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Teraz ${description}',
			'operation.testOperationSuffix' => 'Testovanie',
			'operation.menu.showRstFields' => 'Zobraziť polia RST',
			'operation.menu.showStateField' => 'Zobraziť pole Štát',
			'operation.menu.showGridField' => 'Zobraziť pole Lokátor',
			'operation.menu.showDeletedQsos' => 'Zobraziť vymazané QSO',
			'operation.menu.showDeletedOps' => 'Zobraziť vymazané prevádzky',
			'operation.menu.showQsoNumbers' => 'Zobraziť čísla QSO',
			'operation.menu.lookupAllQsos' => 'Vyhľadať všetky QSO',
			'operation.menu.loggingSettingsTitle' => 'Nastavenia logovania',
			'operation.menu.mapSettingsTitle' => 'Nastavenia mapy',
			'operation.menu.actionsSection' => 'Akcie',
			'operation.layout.title' => 'Pridať panel',
			'operation.layout.availableSection' => 'Dostupné panely',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Nastavenia ${panel}',
			'operation.layout.panelSettingsAction' => 'Nastavenia panelu',
			'operation.layout.viewName' => 'Zobrazenie prevádzky',
			'operation.layout.viewOptions' => 'Možnosti rozloženia zobrazenia',
			'operation.layout.viewTitleBuiltIn' => 'Toto zobrazenie je vstavané v aplikácii, rovnako ako jeho názov',
			'operation.layout.resetOptions' => 'Obnoviť predvolené',
			'operation.layout.removePane' => 'Odstrániť',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Obnoviť predvolené nastavenia ${panel}?',
			'operation.layout.resetPaneConfirmBody' => 'Jeho názov, hlavička a veľkosť sa vrátia na predvolené. Zvyšok rozloženia zostane nezmenený.',
			'operation.layout.resetViewConfirm' => 'Obnoviť predvolené rozloženie tohto zobrazenia?',
			'operation.layout.resetViewConfirmBody' => 'Panely sa vrátia do predvoleného usporiadania a možnosti zobrazenia aj všetkých panelov sa vrátia na predvolené.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Nastavenia rozloženia ${panel}',
			'operation.layout.paneTitle' => 'Názov',
			'operation.layout.paneShowHeader' => 'Zobraziť hlavičku',
			'operation.layout.paneShowHeaderTabset' => 'Vždy zobrazená, kým tento panel zdieľa skupinu — cez hlavičku sa dostanete k ostatným',
			'operation.layout.paneInherit' => 'Rovnako ako aplikácia',
			'operation.layout.searchHint' => 'Hľadať panely',
			'operation.layout.noPanelsMatch' => 'Hľadaniu nezodpovedá žiadny panel.',
			'operation.layout.nothingToAdd' => 'Toto zobrazenie už má všetky možné panely',
			'operation.layout.addPanel' => ({required Object panel}) => 'Pridať ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Náhľad ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Chýba rozšírenie „${name}“',
			'operation.layout.previewUnavailable' => 'Obrázok náhľadu tohto panelu sa nepodarilo zobraziť.',
			'operation.layout.nestedPaneTitle' => 'Viac',
			'operation.layout.editLayout' => 'Upraviť rozloženie',
			'operation.layout.saveLayout' => 'Uložiť rozloženie',
			'operation.layout.revertLayout' => 'Zahodiť zmeny rozloženia',
			'operation.layout.done' => 'Hotovo',
			'operation.layout.layoutUnreadableTitle' => 'Rozloženie sa nepodarilo prečítať',
			'operation.layout.layoutUnreadableBody' => 'Vaše uložené rozloženie sa nepodarilo prečítať, preto sa namiesto neho zobrazuje predvolené usporiadanie. Pôvodné rozloženie sa neprepíše, kým sa nerozhodnete toto ponechať.',
			'operation.layout.layoutUnreadableAction' => 'Použiť toto rozloženie',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} sa nepodarilo zobraziť',
			'operation.layout.panelRenderRetry' => 'Skúsiť znova',
			'operation.layout.panelActionFailed' => 'Akcia panelu zlyhala. Skúste to znova.',
			'operation.layout.panels.loggingDescription' => 'Denník a vstupné polia',
			'operation.layout.panels.infoDescription' => 'Čo vieme o stanici, s ktorou pracujeme',
			'operation.layout.panels.spotsDescription' => 'Spoty z clustrov a aktivačných programov',
			'operation.layout.panels.mapDescription' => 'Kde sú protistanice',
			'operation.layout.panels.clockDescription' => 'Hodiny v ľubovoľnom časovom pásme',
			'operation.layout.panels.clockFace' => 'Ciferník',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analógový',
			'operation.layout.panels.clockZone' => 'Časové pásmo',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Toto zariadenie',
			'operation.layout.panels.clockShowSeconds' => 'Zobraziť sekundy',
			'operation.layout.panels.weatherDescription' => 'Aktuálne podmienky a predpoveď na ďalších osem hodín tam, kde vysielate',
			'operation.layout.panels.weatherUseOperationLocation' => 'Použiť polohu prevádzky',
			'operation.layout.panels.weatherLocation' => 'Poloha',
			'operation.layout.panels.weatherLocationDescription' => 'Lokátor (FN31pr) alebo šírka,dĺžka. Ignoruje sa, kým je zaškrtnuté „Použiť polohu prevádzky“.',
			'operation.layout.panels.weatherNoLocation' => 'Poloha nie je nastavená. Zadajte polohu v nastaveniach tohto panelu alebo ho umiestnite do prevádzky, ktorá polohu má.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Polohu ${location} sa nepodarilo prečítať. Použite lokátor ako FN31pr alebo 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo je nedostupné — nie je sieť? Čoskoro to skúsime znova.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo odpovedalo, ale nič čitateľné. Čoskoro to skúsime znova.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'nárazy ${speed}',
			'operation.layout.panels.panelAgeNow' => 'práve teraz',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'pred ${count} min', other: 'pred ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'pred ${count} h', other: 'pred ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Neznáme',
			'operation.layout.panels.weatherConditions.sunny' => 'Slnečno',
			'operation.layout.panels.weatherConditions.clear' => 'Jasno',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Prevažne slnečno',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Prevažne jasno',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Polojasno',
			'operation.layout.panels.weatherConditions.cloudy' => 'Zamračené',
			'operation.layout.panels.weatherConditions.foggy' => 'Hmla',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Mrznúca hmla',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Slabé mrholenie',
			'operation.layout.panels.weatherConditions.drizzle' => 'Mrholenie',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Silné mrholenie',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Slabé mrznúce mrholenie',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Mrznúce mrholenie',
			'operation.layout.panels.weatherConditions.lightRain' => 'Slabý dážď',
			'operation.layout.panels.weatherConditions.rain' => 'Dážď',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Silný dážď',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Slabý mrznúci dážď',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Mrznúci dážď',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Slabé sneženie',
			'operation.layout.panels.weatherConditions.snow' => 'Sneženie',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Silné sneženie',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Snehové zrná',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Slabé prehánky',
			'operation.layout.panels.weatherConditions.showers' => 'Prehánky',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Silné prehánky',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Slabé snehové prehánky',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Snehové prehánky',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Búrka',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Slabé búrky s krupobitím',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Búrka s krupobitím',
			'operation.layout.panels.websiteDescription' => 'Webová stránka podľa vášho výberu v paneli',
			'operation.layout.panels.websiteUrl' => 'Adresa',
			'operation.layout.panels.websiteRefresh' => 'Obnovovanie',
			'operation.layout.panels.websiteRefreshNever' => 'Nikdy',
			'operation.layout.panels.websiteRefresh1' => 'Každú minútu',
			'operation.layout.panels.websiteRefresh5' => 'Každých 5 minút',
			'operation.layout.panels.websiteRefresh15' => 'Každých 15 minút',
			'operation.layout.panels.websiteTitle' => 'Názov panelu',
			'operation.layout.panels.websiteRefreshNow' => 'Obnoviť teraz',
			'operation.layout.panels.websiteNoUrl' => 'Zatiaľ bez adresy. Otvorte nastavenia tohto panelu a vyberte stránku.',
			'operation.layout.panels.websiteBadUrl' => 'Toto nevyzerá ako webová adresa. Musí začínať na https://',
			'operation.layout.panels.websiteNotHttps' => 'Zobraziť sa tu dajú iba https:// adresy.',
			'operation.layout.panels.websiteUnsupported' => 'Na tomto systéme sa webové stránky v paneli zobraziť nedajú.',
			'operation.layout.panels.websiteOpenExternally' => 'Otvoriť v prehliadači',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Stránku sa nepodarilo načítať: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Obrazovka, aplikácia alebo okno zdieľané iným z vašich zariadení.',
			'operation.layout.panels.remoteScreenTarget' => 'Obrazovka',
			'operation.layout.panels.remoteScreenChoose' => 'Vybrať obrazovku…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Zdieľané obrazovky',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Žiadne z vašich zariadení nezdieľa obrazovku. Na zariadení, ktoré chcete vidieť, zapnite Zdieľať obrazovky a okná v Nastavenia → Partnerské zariadenia.',
			'operation.layout.panels.remoteScreenUnset' => 'Nie je vybraná žiadna obrazovka. Otvorte nastavenia tohto panelu a vyberte jednu, ktorú zdieľajú vaše iné zariadenia.',
			'operation.layout.panels.remoteScreenConnecting' => 'Pripája sa…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Toto zariadenie práve nie je pripojené.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Toto zariadenie prestalo zdieľať túto obrazovku.',
			'operation.layout.panels.remoteScreenNoListener' => 'Toto zariadenie nemôže prijímať pripojenia — skontrolujte jeho firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Obrazovky sa zdieľajú iba cez lokálnu sieť, nie cez Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Toto zariadenie odmietlo zdieľať túto obrazovku.',
			'operation.layout.panels.remoteScreenSettings' => 'Nastavenia panelu',
			'operation.layout.panels.remoteScreenAdjust' => 'Upraviť zobrazenie',
			'operation.layout.panels.remoteScreenDetail' => 'Detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Štandardný',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Vysoký',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximálny',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Priblížiť',
			'operation.layout.panels.remoteScreenZoomOut' => 'Oddialiť',
			'operation.layout.panels.remoteScreenStopped' => 'Táto obrazovka alebo okno sa už nezobrazuje.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Toto zariadenie nedokázalo zachytiť obrazovku — možno potrebuje povolenie na nahrávanie obrazovky.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Toto zariadenie neodpovedalo. Možno nemá zapnuté zdieľanie obrazovky.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Nepodarilo sa otvoriť spojenie pre obraz. Skontrolujte firewall na tomto zariadení.',
			'operation.layout.panels.solarDescription' => 'Slnečné a geomagnetické podmienky so šírením na jednotlivých pásmach',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com je nedostupné — nie je sieť? Čoskoro to skúsime znova.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com odpovedalo, ale nie údajmi, ktoré by sme mohli použiť. Čoskoro to skúsime znova.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Deň',
			'operation.layout.panels.solarBandNight' => 'Noc',
			'operation.layout.panels.solarBandGood' => 'Dobré',
			'operation.layout.panels.solarBandFair' => 'Priemerné',
			'operation.layout.panels.solarBandPoor' => 'Slabé',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Zdroje: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Spojenie má problémy — vynechávajú sa snímky.',
			'operation.layout.panels.remoteScreenStalled' => 'Snímky prestali prichádzať — toto spojenie môže byť príliš pomalé.',
			'operation.layout.panels.radioDescription' => 'Predný panel rádiostanice — frekvencia, mód a výkon, cez ovládanie CAT',
			'operation.layout.panels.radioStyle' => 'Štýl',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderný',
			'operation.layout.panels.radioRadio' => 'Rádiostanica',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — nie je určená rádiostanica',
			'operation.layout.panels.radioNoRadio' => 'Žiadna rádiostanica na zobrazenie. Vyberte ju v nastaveniach tohto panelu alebo ju pridajte v Konfigurácii stanice.',
			'operation.layout.panels.radioNotConfigured' => 'Táto rádiostanica ešte nie je nakonfigurovaná. Vyberte jej port alebo adresu v Konfigurácii stanice.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Rádiostanica nie je pripojená',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Pripojiť túto rádiostanicu',
			'operation.layout.panels.radioDisconnect' => 'Odpojiť túto rádiostanicu',
			'operation.layout.panels.radioStale' => 'BEZ DÁT',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'vysoké SWR',
			'operation.layout.htmlPanelUnsupported' => 'Tento panel potrebuje webové zobrazenie, ktoré táto platforma neposkytuje',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Tento panel potrebuje izolované prostredie, ktoré webová verzia nedokáže poskytnúť',
			'operation.export.title' => 'Exporty prevádzky',
			'operation.export.syncedOperation' => 'Prevádzka je synchronizovaná',
			'operation.export.unsyncedOperation' => 'Prevádzka má nesynchronizované zmeny',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} QSO v tejto prevádzke', other: '${count} QSO v tejto prevádzke', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Všetky QSO (${total}) sú synchronizované',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} z ${total} QSO čaká na synchronizáciu',
			'operation.export.eventsSynced' => ({required Object total}) => 'Synchronizované značky udalostí: ${total}',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} z ${total} značiek udalostí čaká',
			'operation.export.loading' => 'Načítavajú sa možnosti exportu…',
			'operation.export.noOptions' => 'Nie sú dostupné žiadne formáty exportu (prostredie rozšírení sa ešte spúšťa?)',
			'operation.export.nothingLogged' => 'Zatiaľ nie je čo exportovať — táto prevádzka nemá žiadne QSO.',
			'operation.export.share' => 'Zdieľať',
			'operation.export.nothingSelected' => 'Nič nie je vybrané',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Uložiť ${count} súbor', other: 'Uložiť ${count} súborov', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Zdieľať ${count} súbor', other: 'Zdieľať ${count} súborov', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Exportovať ${count} súbor', other: 'Exportovať ${count} súborov', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Stiahnuť ${count} súbor', other: 'Stiahnuť ${count} súborov', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Uložiť ${count} zlúčený súbor', other: 'Uložiť ${count} zlúčených súborov', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Zdieľať ${count} zlúčený súbor', other: 'Zdieľať ${count} zlúčených súborov', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Exportovať ${count} zlúčený súbor', other: 'Exportovať ${count} zlúčených súborov', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Stiahnuť ${count} zlúčený súbor', other: 'Stiahnuť ${count} zlúčených súborov', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => 'Uložiť ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Zdieľať ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportovať ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Stiahnuť ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Uschovať ${count} súbor', other: 'Uschovať ${count} súborov', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Uschovať ${count} zlúčený súbor', other: 'Uschovať ${count} zlúčených súborov', ), 
			'operation.export.settingsButton' => 'Nastavenia exportu',
			'operation.export.settingsTitle' => 'Nastavenia exportu',
			'operation.export.compactFileNames.title' => 'Použiť krátke názvy súborov',
			'operation.export.compactFileNames.descriptionOn' => 'Krátke názvy pre nahrávacie nástroje, napr. N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Čitateľné názvy, napr. 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Zahrnúť súkromné údaje',
			'operation.export.includePrivateData.descriptionOn' => 'Mená, adresy, e-maily, lokátory a poznámky sú zahrnuté',
			'operation.export.includePrivateData.descriptionOff' => 'Mená, adresy, e-maily, lokátory a poznámky sú vynechané',
			'operation.export.includePrivateData.note' => 'Úplný export ADIF vždy obsahuje všetko',
			'operation.export.resultTitle' => 'Export dokončený',
			'operation.export.resultFailedTitle' => 'Export zlyhal',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Exportovaný ${count} súbor do ${path}', other: 'Exportovaných ${count} súborov do ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Exportovaný ${count} súbor: ${path}', other: 'Exportovaných ${count} súborov: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Zdieľaný ${count} súbor', other: 'Zdieľaných ${count} súborov', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Stiahnutý ${count} súbor', other: 'Stiahnutých ${count} súborov', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export zlyhal: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Najprv pridajte e-mailovú adresu',
			'operation.export.stash.needsEmailBody' => 'Ham2K úschovňa súborov posiela vaše súbory na e-mailovú adresu vášho účtu LoFi a pomocou nej sa prihlasujete na stash.ham2k.net. Váš účet ešte nemá potvrdenú adresu — pridajte ju v Nastavenia › Cloudová synchronizácia.',
			'operation.export.stash.openSyncSettings' => 'Otvoriť cloudovú synchronizáciu',
			'operation.export.stash.replaceTitle' => 'Nedávna úschova bude nahradená',
			'operation.export.stash.replaceBody' => ({required Object name}) => '„${name}“ ste odoslali pred menej ako 6 hodinami a ešte nebol stiahnutý. Bezplatné účty môžu mať naraz iba jednu úschovu, takže odoslanie teraz ju nahradí.',
			'operation.export.stash.replaceConfirm' => 'Napriek tomu odoslať',
			'operation.export.stash.failedTitle' => 'Nepodarilo sa odoslať do Ham2K úschovne súborov',
			'operation.export.stash.sentTitle' => 'Odoslané do Ham2K úschovne súborov',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Tento súbor si môžete prevziať návštevou **[stash.ham2k.net](https://stash.ham2k.net)** v ľubovoľnom prehliadači.', other: 'Tieto súbory si môžete prevziať návštevou **[stash.ham2k.net](https://stash.ham2k.net)** v ľubovoľnom prehliadači.', ), 
			'operation.export.stash.mayHaveArrived' => 'Úschovňa neodpovedá — súbor mohol aj tak doraziť. Pred ďalším odoslaním skontrolujte stash.ham2k.net',
			'operation.export.stash.notSent' => 'neodoslané',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Tento súbor nedorazil:', other: 'Týchto ${count} súborov nedorazilo:', ), 
			'operation.export.stash.emailOffer' => 'Alebo vám pre pohodlie môžeme poslať e-mail s priamym odkazom.',
			'operation.export.stash.emailMe' => 'Poslať mi odkaz e-mailom',
			'operation.export.stash.emailSent' => 'Poslali sme vám e-mailom odkaz na stiahnutie.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'E-mail sa nepodarilo odoslať: ${error}',
			'operation.export.stash.freeTier' => 'Bezplatné účty môžu mať naraz uloženú iba jednu úschovu. Predplatitelia ich môžu mať toľko, koľko chcú.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Odoslaný ${count} súbor do Ham2K úschovne súborov (stash.ham2k.net)', other: 'Odoslaných ${count} súborov do Ham2K úschovne súborov (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Vašim filtrom nezodpovedajú žiadne spoty',
			'operation.spots.error' => ({required Object error}) => 'Spoty sa nepodarilo načítať: ${error}',
			'operation.spots.unknownBand' => 'Iné',
			'operation.spots.auto' => 'Automaticky',
			'operation.spots.autoValue' => ({required Object value}) => 'Automaticky (momentálne ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Akékoľvek',
			'operation.spots.allBands' => 'Všetky pásma',
			'operation.spots.allModes' => 'Všetky módy',
			'operation.spots.phoneAndCw' => 'Phone a CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} spot', other: '${count} spotov', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Zobrazuje sa ${count} z ${total} spotov',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minút',
			'operation.spots.callsOfNote' => 'Poznámky k volacím znakom',
			'operation.spots.yourSpots' => 'Vaše spoty',
			'operation.spots.allSpots' => 'Všetky spoty',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Ázia',
			'operation.spots.continents.eu' => 'Európa',
			'operation.spots.continents.na' => 'Severná Amerika',
			'operation.spots.continents.oc' => 'Oceánia',
			'operation.spots.continents.sa' => 'Južná Amerika',
			'operation.spots.continents.an' => 'Antarktída',
			'operation.spots.filters.title' => 'Filtrovať spoty',
			'operation.spots.filters.band' => 'Pásmo',
			'operation.spots.filters.mode' => 'Mód',
			'operation.spots.filters.age' => 'Vek',
			'operation.spots.filters.sources' => 'Zdroje',
			'operation.spots.filters.continent' => 'Kontinent',
			'operation.spots.filters.sorting' => 'Triedenie',
			'operation.spots.filters.sortByTime' => 'Podľa času spotu',
			'operation.spots.filters.sortByFrequency' => 'Podľa frekvencie',
			'operation.spots.filters.groupByBand' => 'Zoskupiť podľa pásma',
			'operation.spots.filters.groupCallsWithNotes' => 'Zoskupiť volacie znaky s poznámkami',
			'operation.spots.filters.sourceNoReply' => 'Bez odpovede',
			'operation.spots.filters.sourceError' => 'Chyba',
			'operation.spots.unavailableTitle' => 'Spoty nie sú dostupné',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} neodpovedali.',
			'operation.spots.failedTitle' => 'Chyba zdroja spotov',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} vrátili chybu.',
			'operation.spots.slideLogIt' => 'Zapísať',
			'operation.spots.slideIgnore' => 'Ignorovať',
			'operation.spots.slideRestore' => 'Obnoviť',
			'operation.spots.logConflict.title' => 'Panel logovania je obsadený',
			'operation.spots.logConflict.editingBody' => 'Upravujete zapísané spojenie. Zapísať namiesto toho tento spot, alebo sa vrátiť a dokončiť úpravu?',
			'operation.spots.logConflict.composingBody' => 'Začali ste zadávať spojenie. Zapísať namiesto toho tento spot, alebo sa vrátiť a dokončiť, čo ste písali?',
			'operation.spots.logConflict.goBack' => 'Vrátiť sa',
			'operation.spots.logConflict.clearAndLog' => 'Vymazať a zapísať spot',
			'operation.import.title' => 'Importovať údaje do prevádzky',
			'operation.import.importAdifAction' => 'Importovať QSO z ADIF',
			'operation.import.settingsButton' => 'Nastavenia počúvania',
			'operation.import.settingsTitle' => 'Počúvať iné aplikácie',
			'operation.import.protocolAddressLabel' => 'Adresa',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Zadajte port od 1 do 65535',
			'operation.import.protocolAddressInvalid' => 'Zadajte platnú IP adresu (napr. 127.0.0.1 alebo 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Prijímajú sa údaje',
			'operation.import.protocolStatusNoData' => 'V poslednom čase neprišli žiadne údaje',
			'operation.import.protocolBindError' => ({required Object error}) => 'Počúvanie sa nepodarilo spustiť: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Prichádzajúce QSO sa nepodarilo uložiť a skúša sa to znova: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Akákoľvek (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → karta Broadcast Data → zaškrtnite "Enable Broadcasts" pre informácie o spojeniach. Nastavte IP adresu na 127.0.0.1, ak beží na tom istom počítači, alebo na 255.255.255.255 pre broadcast v aktuálnej lokálnej sieti.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → karta Reporting → sekcia UDP Server → zaškrtnite "Accept UDP requests". Nastavte UDP Server na 127.0.0.1, ak beží na tom istom počítači, alebo na multicastovú adresu, napr. 239.239.0.2, a rovnakú adresu použite v konfigurácii vyššie v tejto aplikácii.',
			'operation.import.listenTitle' => 'Počúvať QSO z iných aplikácií',
			'operation.import.listenDescriptionOnN1mm' => 'Počúva sa N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Počúva sa WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Počúva sa N1MM+ a WSJT-X',
			'operation.import.listenDescriptionOff' => 'Vypnuté',
			'operation.import.addToOperationTitle' => 'Pridať do tejto prevádzky',
			'operation.import.addToOperationDescriptionOn' => 'Zachytené QSO sa pridávajú do tejto prevádzky hneď, ako prídu',
			'operation.import.addToOperationDescriptionOff' => 'Zachytené QSO sa podržia, kým toto nezapnete',
			'operation.import.pendingSectionTitle' => 'Zachytené QSO',
			'operation.import.pendingEmpty' => 'Zatiaľ nič nezachytené',
			'operation.import.stationMismatch' => ({required Object call}) => 'Zapísané ako ${call}, nie stanica tejto prevádzky',
			'operation.import.discardAction' => 'Zahodiť',
			'operation.import.gapDialogTitle' => 'Zahrnúť staršie záznamy?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Pred medzerou v údajoch bolo zachytených ešte ${count} QSO. Zahrnúť aj tie?',
			'operation.import.gapDialogRecentOnly' => 'Iba nedávne',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Zahrnúť všetky (${count})',
			'map.outlineIssue.link' => 'Problémy?',
			'map.outlineIssue.title' => 'Nahlásiť problém s obrysom',
			'map.outlineIssue.reference' => 'Ktorý obrys',
			'map.outlineIssue.severity' => 'Aké vážne to je?',
			'map.outlineIssue.minor' => 'Drobnosť',
			'map.outlineIssue.major' => 'Vážny problém',
			'map.outlineIssue.explanation' => 'Čo je na ňom zlé?',
			'map.outlineIssue.explanationHint' => 'Čo obrys zobrazuje nesprávne a kde',
			'map.outlineIssue.send' => 'Odoslať',
			'map.outlineIssue.sending' => 'Odosiela sa vaše hlásenie — ďakujeme',
			'map.outlineIssue.copy' => 'Kopírovať hlásenie',
			'map.outlineIssue.notSent' => 'Hlásenie sa nepodarilo odoslať',
			'map.outlineIssue.copied' => 'Hlásenie skopírované',
			'map.outlineIssue.notCopied' => 'Hlásenie sa nepodarilo skopírovať',
			'map.outlinesDisclaimer' => 'Obrysy sú iba orientačné. Overte si to sami!',
			'map.outlinesCredit' => ({required Object sources}) => 'Obrysy: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Hranice: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Zariadenia: ${sources}',
			'map.fullCredits' => 'Úplné zdroje údajov',
			'map.fewerCredits' => 'Menej zdrojov',
			'map.emptyState' => 'Zatiaľ žiadne polohy QSO.\nTu sa zobrazia QSO s lokátorom, štátom alebo krajinou.',
			'map.unavailable' => 'Mapa momentálne nie je dostupná.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plochá',
			'map.globe' => 'Glóbus',
			'map.zoomIn' => 'Priblížiť',
			'map.zoomOut' => 'Oddialiť',
			'map.postcard.button' => 'Pohľadnica z prevádzky',
			'map.postcard.title' => ({required Object title}) => 'Pohľadnica pre ${title}',
			'map.postcard.portrait' => 'Na výšku',
			'map.postcard.landscape' => 'Na šírku',
			'map.postcard.square' => 'Štvorec',
			'map.postcard.save' => 'Uložiť…',
			'map.postcard.download' => 'Stiahnuť',
			'map.postcard.share' => 'Zdieľať',
			'map.postcard.copy' => 'Kopírovať',
			'map.postcard.copied' => 'Skopírované do schránky',
			'map.postcard.saved' => ({required Object path}) => 'Uložené do ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Stiahnuté ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Obrázky (${count}) uložené do ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Uložené ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} už boli uložené',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Sťahuje sa ${count} obrázkov — povoľte ich, ak sa prehliadač opýta',
			'map.postcard.mapLeftOut' => 'Mapa sa nenačítala, preto bola vynechaná',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — mapa sa nenačítala, preto bola vynechaná',
			'map.postcard.continued' => ({required Object title}) => '${title} (pokračovanie)',
			'map.postcard.previousPage' => 'Predchádzajúca strana',
			'map.postcard.nextPage' => 'Ďalšia strana',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Strana ${page} z ${count}',
			'map.postcard.sectionDays' => 'Každý deň',
			'map.postcard.reset' => 'Obnoviť',
			'map.postcard.failed' => ({required Object error}) => 'Pohľadnicu sa nepodarilo vytvoriť: ${error}',
			'map.postcard.mapNotReady' => 'Mapa sa nestihla načítať. Skontrolujte pripojenie a skúste to znova.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Pohľadnicu sa nepodarilo uložiť: ${error}',
			'map.postcard.copyFailed' => 'Schránka obrázok neprijala. Skúste to znova.',
			'map.postcard.shareFailed' => 'Pohľadnicu sa nepodarilo zdieľať. Skúste to znova.',
			'map.postcard.fileName' => 'pohladnica',
			'mapsView.title' => 'Mapy',
			'mapsView.searchHint' => 'Hľadať parky, vrcholy a ďalšie',
			'mapsView.activities' => 'Aktivity',
			'mapsView.layers' => 'Vrstvy',
			'mapsView.baseMap' => 'Podkladová mapa',
			'mapsView.satellite' => 'Satelit (Esri)',
			'mapsView.facilities' => 'Zariadenia parkov',
			'mapsView.boundaries' => 'Hranice',
			'mapsView.currentLocation' => 'Aktuálna poloha',
			'mapsView.noMatches' => ({required Object text}) => '„${text}“ nič nezodpovedá',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} referencia na ${where}', other: '${count} referencií na ${where}', ), 
			'mapsView.startOperation' => 'Začať prevádzku s týmito referenciami',
			'activitiesView.title' => 'Aktivity',
			'activitiesView.activitiesCountZero' => 'Nie sú vybrané žiadne aktivity',
			'activitiesView.activitiesCountOne' => '1 aktivita',
			'activitiesView.activitiesCountOther' => ({required Object count}) => 'Aktivity: ${count}',
			'activitiesView.empty' => 'Zatiaľ žiadne aktivity — pridajte ju pomocou Návrhy a vyhľadávanie nižšie',
			'activitiesView.removeActivity' => 'Odstrániť',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Otvoriť ${name}',
			'activitiesView.editActivity' => 'Upraviť aktivitu',
			'activitiesView.manageExtensions' => 'Spravovať rozšírenia',
			'activitiesView.manage' => 'Spravovať',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Typy aktivít: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Typy aktivít: ${first} a ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Typy aktivít: ${first}, ${second} a ďalšie (${more})',
			'activitiesView.reference' => 'Referencia',
			'activitiesView.invalidReference' => 'Neplatná',
			'activitiesView.duplicateReference' => 'Už pridaná',
			'activitiesView.searchHint' => 'Hľadať podľa názvu, referencie alebo čohokoľvek iného…',
			'activitiesView.noSuggestions' => 'Žiadne zhody',
			'activitiesView.noSuggestionsHint' => 'Hľadajte vyššie podľa názvu alebo čísla referencie',
			'activitiesView.noSuggestionsExample' => '(napríklad \'trail\' alebo \'4556\')',
			'activitiesView.allOptions' => 'Typy aktivít',
			'activitiesView.determiningLocation' => 'Zisťuje sa aktuálna poloha…\nČaká sa na GPS na nájdenie referencií v blízkosti',
			'activitiesView.locationUnavailableTitle' => 'Údaje o polohe nie sú dostupné',
			'activitiesView.locationDeniedTitle' => 'Prístup k polohe bol zamietnutý',
			'activitiesView.locationBlockedTitle' => 'Prístup k polohe je zablokovaný',
			'activitiesView.noNearbyReason' => 'Nedajú sa určiť referencie v blízkosti',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Ťuknite na ${icon} a zadajte polohu ručne,\nalebo jednoducho hľadajte referencie podľa názvu',
			'activitiesView.locationGrantAction' => 'Povoliť prístup k polohe',
			'activitiesView.locationSettingsAction' => 'Otvoriť nastavenia',
			'activitiesView.locationSettingsUnavailable' => 'Povoľte prístup k polohe v systémových nastaveniach',
			'activitiesView.locationGrantRefused' => 'Stále bez polohy — systém to znova zamietol',
			'activitiesView.searchUnavailableTitle' => 'Vyhľadávanie aktivít nie je dostupné',
			'activitiesView.searchUnavailableReason' => 'Žiadne rozšírenie aktivít nedokázalo vyhľadávanie spustiť. Skúste to o chvíľu znova.',
			'activitiesView.emptySheet' => 'Pridajte ju pomocou návrhov a vyhľadávania nižšie',
			'activitiesView.exports' => 'Exporty',
			'activitiesView.exportLogs' => 'Exportovať denníky',
			'activitiesView.tools' => 'Nástroje',
			'activitiesView.toolsTitle' => 'Nástroje prevádzky',
			'activitiesView.operationDetails' => 'Podrobnosti o prevádzke',
			'activitiesView.share' => 'Zdieľať',
			'activitiesView.archive' => 'Archivovať',
			'activitiesView.deleteOperation' => 'Odstrániť prevádzku',
			'activitiesView.undeleteOperation' => 'Obnoviť prevádzku',
			'activitiesView.alreadySelected' => 'Už vybrané',
			'activitiesView.selected' => 'Vybrané',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} z ${count}',
			'activitiesView.previousPick' => 'Predchádzajúca zhoda',
			'activitiesView.nextPick' => 'Ďalšia zhoda',
			'activitiesView.retiredReference' => 'Zrušená',
			'activitiesView.enableExtension' => ({required Object name}) => 'Povoliť ${name}',
			'activitiesView.enableExtensionHint' => 'Toto rozšírenie zodpovedá vášmu hľadaniu, ale momentálne nie je povolené',
			'activitiesView.enableExtensionForRefHint' => 'Toto rozšírenie spracúva jednu z referencií tejto prevádzky, ale momentálne nie je povolené',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} nebeží',
			'activitiesView.extensionNotRunningHint' => 'Toto rozšírenie bolo vypnuté, viac informácií nájdete v nastaveniach rozšírení',
			'activitiesView.installExtension' => ({required Object name}) => 'Inštalovať ${name}',
			'activitiesView.installExtensionHint' => 'Toto rozšírenie zodpovedá vášmu hľadaniu, ale nie je nainštalované',
			'activitiesView.onlyCatalogMatches' => 'Žiadne zhody\nNiektoré rozšírenia v katalógu môžu mať výsledky.\nNainštalujte ich v časti Typy aktivít nižšie.',
			'activitiesView.setupUnavailable' => 'Nastavenie tejto aktivity sa nepodarilo načítať — skúste to znova cez Spravovať',
			'activitiesView.controlsUnavailableTitle' => 'Ovládanie aktivity nie je dostupné',
			'activitiesView.controlsUnavailableReason' => 'Vaše referencie sú v bezpečí, ale ich úprava momentálne nie je dostupná.',
			'activitiesView.controlsUnavailableRetry' => 'Skúsiť znova',
			'activitiesView.onlyDisabledMatches' => 'Žiadne zhody\nNiektoré dostupné rozšírenia môžu mať výsledky.\nPovoľte ich v časti Typy aktivít nižšie.',
			'activitiesView.onlyNotRunningMatches' => 'Žiadne zhody\nNiektoré rozšírenia, ktoré môžu mať výsledky, nebežia.\nPozrite si Typy aktivít nižšie.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Hľadať',
			'activitiesView.addToOperation' => 'Pridať do prevádzky',
			'activitiesView.addToOperationShort' => 'Pridať',
			'activitiesView.mapEmptyState' => 'Žiadne výsledky na zobrazenie na mape',
			'activitiesView.mapEmptyStateHint' => 'Prepnite späť na zoznam alebo hľadajte niečo iné',
			'activitiesView.imports' => 'Importy',
			'loggingControls.timeUtc' => 'Čas (UTC)',
			'loggingControls.date' => 'Dátum',
			'loggingControls.now' => 'Teraz',
			'loggingControls.frequency' => 'Frekvencia',
			'loggingControls.mode' => 'Mód',
			'loggingControls.theirCall' => 'Ich volací znak',
			'loggingControls.noteField' => 'Poznámka',
			'loggingControls.todoField' => 'Úloha',
			'loggingControls.sent' => 'Odoslané',
			'loggingControls.rcvd' => 'Prijaté',
			'loggingControls.more' => 'Viac',
			'loggingControls.revert' => 'Vrátiť späť',
			'loggingControls.undoDelete' => 'Zrušiť vymazanie',
			'loggingControls.restore' => 'Obnoviť',
			'loggingControls.wipe' => 'Vymazať',
			'loggingControls.undo' => 'Späť',
			'loggingControls.pendingDeleteTapWarning' => 'Ťuknite na kôš ešte raz a toto QSO sa vymaže',
			'loggingControls.pendingDeleteClickWarning' => 'Kliknite na kôš ešte raz a toto QSO sa vymaže',
			'loggingControls.deletedQsoWarning' => 'Vymazané QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Ťuknite na kôš ešte raz a vymaže sa: ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Kliknite na kôš ešte raz a vymaže sa: ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Vymazané: ${kind}',
			'loggingControls.timeControl' => 'Čas',
			'loggingControls.radioControl' => 'Rádio',
			'loggingControls.powerControl' => 'Výkon',
			'loggingControls.notesControl' => 'Poznámky',
			'loggingControls.power' => 'Výkon',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Ovládanie logovania',
			'loggingControls.spottingControl' => 'Spotovanie',
			'loggingControls.spottingSelfControl' => 'Self-spotovanie',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot na ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} na ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Príliš neskoro na spot ${call}',
			'loggingControls.spotNoFreq' => 'Najprv nastavte frekvenciu pre spot',
			'loggingControls.spotComment' => 'Komentár',
			'loggingControls.bandOrFreqRequired' => 'Pred zápisom nastavte frekvenciu alebo pásmo',
			'loggingControls.missingBand' => 'Bez pásma',
			'loggingControls.missingMode' => 'Bez módu',
			'loggingControls.saveFailed' => ({required Object error}) => 'Nepodarilo sa uložiť: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Nepodarilo sa vymazať: ${error}',
			'loggingControls.info.noQsos' => 'Zatiaľ žiadne QSO... poďme do éteru!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} za ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} od posledného',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h pre posledných 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h pre posledných 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} do',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) do',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) do',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} ďaleko',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) ďaleko',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) ďaleko',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplikát!',
			'loggingControls.info.noticeNewBand' => 'Nové pásmo',
			'loggingControls.info.noticeNewMode' => 'Nový mód',
			'loggingControls.info.noticeNewDXCC' => 'Nové DXCC',
			'loggingControls.info.noticeNewState' => 'Nový štát',
			'loggingControls.info.noticeNewProvince' => 'Nová provincia',
			'loggingControls.info.noticeNewDay' => 'Nový deň',
			'loggingControls.info.noticeNewRef' => 'Nová ref.',
			'loggingControls.info.noticeNewMult' => 'Nový násobič',
			'loggingControls.info.noticeNewZone' => 'Nová zóna',
			'loggingControls.info.noticeInvalidMode' => 'Zlý mód',
			'loggingControls.info.noticeInvalidBand' => 'Zlé pásmo',
			'loggingControls.info.noticeInvalidCategory' => 'Nedá sa pracovať',
			'loggingControls.info.noticeWorkedBefore' => 'Už robené',
			'loggingControls.info.noticeNewPark' => 'Nový park',
			'loggingControls.info.noticeNewSection' => 'Nová sekcia',
			'loggingControls.info.noticeBonusStation' => 'Bonusová stanica!',
			'loggingControls.info.noticeMissingExchange' => 'Bez výmeny',
			'loggingControls.info.noticeInvalidExchange' => 'Zlá výmena',
			'loggingControls.info.noticeUnknownEvent' => 'Neznáma udalosť',
			'loggingControls.info.noticeOurGrid' => 'Nastavte náš lokátor',
			'loggingControls.info.noticeRareCounty' => 'Vzácny kraj!',
			'loggingControls.info.noticeOurLocation' => 'Nastavte náš kraj',
			'loggingControls.info.noticeShortGrid' => 'Lokátor je príliš krátky',
			'formChrome.untitled' => '(bez názvu)',
			'formChrome.showMore' => 'Zobraziť viac',
			'formChrome.showAll' => 'Zobraziť všetko',
			'formChrome.showFewer' => 'Zobraziť menej',
			'formChrome.defaults' => 'Predvolené',
			'formChrome.search' => 'Hľadať',
			'formChrome.clear' => 'Vymazať',
			'formChrome.openPage' => 'Otvoriť stránku',
			'formChrome.connected' => 'Pripojené',
			'formChrome.notConnected' => 'Nepripojené',
			'formChrome.manage' => 'Spravovať',
			'formChrome.connect' => 'Pripojiť',
			'formChrome.formTitle' => 'Formulár',
			'formChrome.addItem' => ({required Object label}) => 'Pridať ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Upraviť ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Zobrazuje sa ${shown} z ${total} (vybrané: ${selected})',
			'formChrome.validationError' => ({required Object error}) => 'Chyba overenia: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Chyba transformácie: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Chyba: ${error}',
			'formChrome.removeItem' => 'Odstrániť',
			'formChrome.storageUnavailable' => 'Prihlasovacie údaje nie sú dostupné',
			'qsoEditForm.title' => 'Upraviť QSO',
			'qsoEditForm.operatorCall' => 'Operátor',
			'qsoEditForm.position' => 'Pracovisko',
			'qsoEditForm.theirName' => 'Meno',
			'qsoEditForm.theirGrid' => 'Lokátor',
			'qsoEditForm.theirState' => 'Štát',
			'qsoEditForm.band' => 'Pásmo',
			'qsoEditForm.notes' => 'Poznámky',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Ich informácie',
			'qsoEditForm.sectionOur' => 'Naše informácie',
			'qsoEditForm.sectionNotes' => 'Poznámky',
			'qsoEditForm.theirCity' => 'Mesto',
			'qsoEditForm.theirCounty' => 'Kraj',
			'qsoEditForm.theirEntity' => 'Entita',
			'qsoEditForm.theirCqZone' => 'CQ zóna',
			'qsoEditForm.theirItuZone' => 'ITU zóna',
			'qsoEditForm.theirArrlSection' => 'ARRL sekcia',
			'qsoEditForm.theirLat' => 'Zemepisná šírka',
			'qsoEditForm.theirLon' => 'Zemepisná dĺžka',
			'qsoEditForm.theirPower' => 'Ich výkon',
			'qsoList.empty' => 'Zatiaľ žiadne QSO — urobte s niekým spojenie!',
			'qsoList.bandOrModeWarning' => 'Skontrolujte, či máte správne pásmo a mód',
			'qsoList.today' => 'Dnes',
			'qsoList.yesterday' => 'Včera',
			'qsoList.tomorrow' => 'Zajtra',
			'loggingPanel.stats' => 'Štatistiky prevádzky',
			'loggingPanel.scoring' => 'Bodovanie',
			'loggingPanel.dxccEntities' => 'Entity DXCC',
			'loggingPanel.statesWorked' => 'Štáty',
			'loggingPanel.provincesWorked' => 'Provincie',
			'loggingPanel.duplicates' => 'Duplikáty',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Zobraziť obrázok',
			'callInfo.imageUnavailable' => 'Fotografia nie je dostupná',
			'callInfo.photo' => 'Fotografia',
			'callInfo.notes' => 'Poznámky',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} do',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) do',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) do',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} ďaleko',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) ďaleko',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) ďaleko',
			'callInfo.thisOpCountOne' => '1 QSO v tejto prevádzke',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSO v tejto prevádzke',
			'callInfo.otherOpsCountOne' => '1 QSO v iných prevádzkach',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSO v iných prevádzkach',
			'callInfo.andMore' => ({required Object count}) => '… a ${count} ďalších',
			'callInfo.withCall' => ({required Object call}) => 's ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'z ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} za posledných 7 dní',
			'callInfo.history.today' => ({required Object n}) => '${n} dnes',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => 'Nastavenia',
			'settings.language' => 'Jazyk',
			'settings.languageSystem' => ({required Object language}) => 'Podľa nastavení systému (${language})',
			'settings.theme.title' => 'Režim témy',
			'settings.theme.system' => 'Podľa nastavení systému',
			'settings.theme.light' => 'Svetlý',
			'settings.theme.dark' => 'Tmavý',
			'settings.themeDescription.system' => 'Podľa nastavení systému',
			'settings.themeDescription.light' => 'Vždy v svetlom režime',
			'settings.themeDescription.dark' => 'Vždy v tmavom režime',
			'settings.fontScale' => 'Veľkosť písma',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Najmenšia--',
			'settings.fontScaleOpts.smallestMinus' => 'Najmenšia-',
			'settings.fontScaleOpts.smallest' => 'Najmenšia',
			'settings.fontScaleOpts.smaller' => 'Menšia',
			'settings.fontScaleOpts.normal' => 'Normálna',
			'settings.fontScaleOpts.larger' => 'Väčšia',
			'settings.fontScaleOpts.largest' => 'Najväčšia',
			'settings.fontScaleOpts.largestPlus' => 'Najväčšia+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Najväčšia++',
			'settings.keepDeviceAwake.title' => 'Udržiavať zariadenie aktívne',
			'settings.keepDeviceAwake.descriptionOn' => 'Zariadenie zostáva aktívne, kým ste v zobrazení logovania alebo prebieha synchronizácia',
			'settings.keepDeviceAwake.descriptionOff' => 'Zariadenie sa uspáva ako zvyčajne',
			'settings.layoutDensity' => 'Hustota rozloženia',
			'settings.layoutDensityOpts.auto' => 'Automatická',
			'settings.layoutDensityOpts.densest' => 'Najhustejšia',
			'settings.layoutDensityOpts.dense' => 'Hustá',
			'settings.layoutDensityOpts.normal' => 'Normálna',
			'settings.layoutDensityOpts.sparse' => 'Riedka',
			'settings.layoutDensityOpts.sparsest' => 'Najriedkejšia',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'okno je príliš nízke, používa sa ${effective}',
			'settings.layoutDensityAtLimit' => 'na maximum',
			'settings.distanceUnits' => 'Jednotky vzdialenosti',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometre',
			'settings.distanceUnitsOpts.miles' => 'Míle',
			'settings.userInterface' => 'Používateľské rozhranie',
			'settings.logging.title' => 'Logovanie',
			'settings.logging.leftieMode.title' => 'Mód pre ľavákov',
			'settings.logging.leftieMode.descriptionOn' => 'Používa sa rozloženie pre ľavákov',
			'settings.logging.leftieMode.descriptionOff' => 'Používa sa rozloženie pre pravákov',
			'settings.logging.countryFlags.title' => 'Vlajky krajín',
			'settings.logging.countryFlags.dx' => 'Zobraziť iba pre DX spojenia',
			'settings.logging.countryFlags.all' => 'Zobraziť vlajky pre všetky spojenia',
			'settings.logging.countryFlags.none' => 'Nezobrazovať žiadne vlajky',
			'settings.logging.countryFlagsDescription.dx' => 'Zobrazujú sa vlajky iba pre DX spojenia',
			'settings.logging.countryFlagsDescription.all' => 'Zobrazujú sa vlajky pre všetky spojenia',
			'settings.logging.countryFlagsDescription.none' => 'Nezobrazujú sa žiadne vlajky',
			'settings.logging.suggestDefaultOperator.title' => 'Navrhnúť operátora',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Váš volací znak sa ponúka ako operátor, keď prevádzka beží pod iným volacím znakom stanice',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Operátor zostane prázdny, kým ho nevyplníte',
			'settings.logging.showBearing.title' => 'Zobrazovať azimut',
			'settings.logging.showBearing.descriptionOn' => 'Zobrazuje sa odhadovaný azimut k stanici',
			'settings.logging.showBearing.descriptionOff' => 'Informácie o azimute sa nezobrazujú',
			'settings.logging.showReverseBearing.title' => 'Zobraziť aj spätný azimut',
			'settings.logging.showReverseBearing.descriptionOn' => 'Zobrazuje sa aj azimut od stanice, napríklad „45° / 225°“',
			'settings.logging.showReverseBearing.descriptionOff' => 'Zobrazuje sa iba azimut k stanici',
			'settings.logging.switchSentRcvd.title' => 'Prepnúť poradie reportov signálu',
			'settings.logging.switchSentRcvd.sentFirst' => 'Odoslaný ako prvý, prijatý ako druhý',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Prijatý ako prvý, odoslaný ako druhý',
			'settings.logging.jumpAfterRST.title' => 'Prejsť na ďalšie pole po zadaní RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Po zadaní RST sa prechádza ďalej',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Automaticky sa neprechádza ďalej',
			'settings.logging.defaultReport.title' => 'Predvolený report — fónia',
			'settings.logging.defaultReport.description' => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri SSB, FM alebo AM',
			'settings.logging.defaultReportCW.title' => 'Predvolený report — CW a dáta',
			'settings.logging.defaultReportCW.description' => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri CW, RTTY a iných dátových módoch',
			'settings.logging.defaultReportFT8.title' => 'Predvolený report — FT8 a FT4',
			'settings.logging.defaultReportFT8.description' => 'Použije sa, keď Odoslané alebo Prijaté zostane prázdne pri módoch FT',
			'settings.logging.numbersRow.title' => 'Riadok s číslami',
			'settings.logging.numbersRow.description' => 'Pri logovaní zobraziť nad klávesnicou riadok s číselnými klávesmi',
			'settings.logging.numbersRowExtra.title' => 'Kláves lomky a bodky',
			'settings.logging.numbersRowExtra.description' => 'Pridá kontextový kláves: „/“ pre volacie znaky, „.“ pre čísla',
			'settings.logging.numbersRowVibrate.title' => 'Vibrovať pri stlačení',
			'settings.logging.numbersRowVibrate.description' => 'Hmatová odozva pri ťuknutí na číselný kláves',
			'settings.logging.bands' => 'Preferované pásma',
			'settings.logging.modes' => 'Preferované módy',
			'settings.catServer.title' => 'CAT server',
			'settings.catServer.description' => 'Umožniť iným aplikáciám (WSJT-X, logovacie programy atď.) ovládať rádiostanicu cez Ham2K Logger.',
			'settings.catServer.protocol' => 'Protokol',
			'settings.catServer.protocolOpts.off' => 'Vypnuté',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Otvorený prístup',
			'settings.catServer.openAccessOn' => 'Pripojiť sa môže ľubovoľný počítač v lokálnej sieti.',
			'settings.catServer.openAccessOff' => 'Pripojiť sa môžu iba aplikácie na tomto počítači.',
			'settings.catServer.off' => 'Vypnuté.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, spúšťa sa…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} na porte ${port}. Pripojení klienti: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} na porte ${port}, ale nie je pripojená žiadna rádiostanica Hlavného VFO.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} nemôže počúvať na porte ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} nemôže počúvať na porte ${port}: používa ho iný program, často samotný ${protocol}. Zatvorte tento program alebo vyberte iný port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} nemôže počúvať na porte ${port}: tento počítač to nepovoľuje. Vyberte port nad 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} prestal počúvať na porte ${port}. Skúša sa znova…',
			'settings.radio.title' => 'Ovládanie CAT',
			_ => null,
		} ?? switch (path) {
			'settings.radio.loggingAndCat' => 'Logovanie a CAT',
			'settings.radio.tuningSection' => 'Ladenie',
			'settings.radio.keyerSection' => 'Kľúčovač',
			'settings.radio.servicesSection' => 'Služby',
			'settings.radio.stationConfigurationSection' => 'Konfigurácia stanice',
			'settings.radio.moreSettings' => 'Ďalšie nastavenia konfigurácie stanice',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Ovládať PTT klávesom [\']',
			'settings.radio.pttKey.descriptionOn' => 'Vo fóniových módoch [\'] zaklúčuje rádiostanicu a ďalšie [\'] ju odkľúčuje. Po minúte sa odkľúčuje sama.',
			'settings.radio.pttKey.descriptionOff' => 'Kláves [\'] rádiostanicu nezaklúčuje.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Vysiela sa',
			'settings.radio.smartVfoSnap.title' => 'Inteligentné zaokrúhľovanie VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Keď prestanete otáčať ladiacim gombíkom, frekvencia sa zaokrúhli na rozumný krok. Iba hlasové módy.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Frekvencia zostane presne tam, kam ste naladili.',
			'settings.radio.snapDebounce.title' => 'Zaokrúhľovanie: oneskorenie ustálenia',
			'settings.radio.snapDebounce.description' => 'Ako dlho musí gombík stáť, kým sa frekvencia zaokrúhli. Kratšie pôsobí okamžite, dlhšie nechá priestor na pomalý pohyb.',
			'settings.radio.snapLongMove.title' => 'Zaokrúhľovanie: dlhý pohyb',
			'settings.radio.snapLongMove.description' => 'Pri pohybe aspoň o túto hodnotu sa frekvencia zaokrúhli na celé kHz, nech ste skončili akokoľvek pomaly.',
			'settings.radio.snapMinMove.title' => 'Zaokrúhľovanie: najmenší pohyb',
			'settings.radio.snapMinMove.description' => 'Pri pohybe menšom ako táto hodnota sa frekvencia nezaokrúhli, takže jemné ladenie zostane nedotknuté.',
			'settings.radio.snapMinSpeed.title' => 'Zaokrúhľovanie: najpomalší pohyb',
			'settings.radio.snapMinSpeed.description' => 'Ak otáčate gombíkom pomalšie, frekvencia sa nezaokrúhli, pokiaľ nešlo o dlhý pohyb.',
			'settings.radio.enterSends.pillOff' => 'ESM vyp.',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter odosiela správy',
			'settings.radio.enterSends.off' => 'Vyp.',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter odosiela správy: ${state}. Ťuknutím zmeníte.',
			'settings.radio.keyerSpeed.title' => 'Rýchlosť kľúčovača',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Správy CW kľúčovača',
			'settings.radio.cwMessages.notSupported' => 'Aktuálna rádiostanica nepodporuje kľúčovanie CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Správa (${n})',
			'settings.radio.cwMessages.labelField' => 'Popis',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Popis F${n}',
			'settings.radio.cwMessages.details' => 'Podrobnosti',
			'settings.radio.cwMessages.empty' => '(prázdne)',
			'settings.radio.cwMessages.sets' => 'Sada správ',
			'settings.radio.cwMessages.newSet' => 'Nová sada',
			'settings.radio.cwMessages.renameSet' => 'Premenovať sadu',
			'settings.radio.cwMessages.deleteSet' => 'Odstrániť sadu',
			'settings.radio.cwMessages.newSetName' => 'Názov',
			'settings.radio.cwMessages.setDefault' => 'Predvolená',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Správy ESM',
			'settings.radio.cwMessages.setSaved' => 'Moje správy',
			'settings.radio.cwMessages.repeat' => 'Opakovať správu č. 1',
			'settings.radio.cwMessages.repeatOff' => 'Nie',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Po ${n} sekundách',
			'settings.radio.cwMessages.repeatWait' => 'Opakuje sa',
			'settings.radio.cwMessages.keyboard' => 'Píšte a odošle sa',
			'settings.radio.cwMessages.keyboardField' => 'Píšte a odošle sa',
			'settings.radio.cwMessages.closeArea' => 'Zatvoriť oblasť kľúčovača',
			'settings.radio.cwMessages.help' => 'Pomocník',
			'settings.radio.cwMessages.helpTitle' => 'Písanie CW správ',
			'settings.radio.cwMessages.helpIntro' => 'Správy môžu používať šablóny s týmito hodnotami:',
			'settings.radio.cwMessages.helpOpCall' => 'Váš volací znak',
			'settings.radio.cwMessages.helpQsoCall' => 'Ich volací znak — v zásobníku // značka, ktorá sa zapíše',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Ich volací znak, ak je platný; prázdne pri čiastočnom',
			'settings.radio.cwMessages.helpQsoPartial' => 'Čiastočný volací znak; prázdne, ak je úplný platný znak',
			'settings.radio.cwMessages.helpQsoNextCall' => 'V zásobníku // značka, ktorá sa vyberie na zápis ako ďalšia, ak je platná a úplná',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'V zásobníku // ďalší čiastočný znak po zápise aktuálneho spojenia',
			'settings.radio.cwMessages.helpQsoName' => 'Ich krstné meno, ako bolo zadané, inak z vyhľadávania',
			'settings.radio.cwMessages.helpQsoState' => 'Ich štát, ako bol zadaný, inak z vyhľadávania',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Správa 1 tak, ako by sa odoslala, vo vnútri inej správy. Platí pre správy 1 až 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Report, ktorý odosielate',
			'settings.radio.cwMessages.helpQsoSerial' => 'Vaše poradové číslo v súťaži, ktorá ho posiela',
			'settings.radio.cwMessages.helpPad' => 'Doplní nulami na daný počet číslic: 7 sa odošle ako 007',
			'settings.radio.cwMessages.helpCut' => 'Skrátené číslice, T pre 0 a N pre 9: 599 sa odošle ako 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Vyberá číslice na skrátenie, v úvodzovkách — 0 je T, 1 je A, 5 je E, 9 je N',
			'settings.radio.cwMessages.helpFullExample' => 'Úplný príklad:',
			'settings.radio.cwMessages.helpExample' => 'Odošle W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'So zapnutým Enter odosiela správy kláves Enter vysiela správy podľa ich funkčného klávesu, ako v N1MM. Sada Správy ESM začína týmito:',
			'settings.radio.cwMessages.helpEsmCq' => 'Pri Run Enter s prázdnym poľom volacieho znaku volá CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Vaša výmena: pri Run po ich volacom znaku, pri S&P potom, ako odpovedia',
			'settings.radio.cwMessages.helpEsmThanks' => 'Poďakovanie po zapísaní spojenia: jeho zástupné symboly označujú ďalšie spojenie, nie toto',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Pri S&P váš volací znak pre stanicu, ktorej odpovedáte',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Pri Run ich volací znak pred vašou výmenou',
			'settings.radio.cwMessages.helpEsmAgain' => 'Opýta sa znova, keď z ich výmeny nebolo nič prijaté',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Navrhované F3 pre zásobníky //: TU sa odošle po zapísaní spojenia, takže poďakuje, potom zavolá ďalšiu stanicu v zásobníku a odošle vašu výmenu, alebo sa opýta na čiastočný znak (TU KR?); ak už nič nezostáva, iba TU',
			'settings.radio.voiceMessages.title' => 'Správy fóniového kľúčovača',
			'settings.radio.voiceMessages.notSupported' => 'Aktuálna rádiostanica nepodporuje fóniové správy',
			'settings.radio.voiceMessages.description' => 'Používa hlasové pamäte rádiostanice',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Hlasová pamäť (${n})',
			'settings.radio.voiceMessages.labelField' => 'Popis',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Popis hlasovej pamäte ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Prázdna',
			'settings.radio.voiceMessages.notMeasured' => 'Neznáma dĺžka',
			'settings.radio.voiceMessages.playButton' => 'Prehrať',
			'settings.radio.voiceMessages.recordButton' => 'Nahrať',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Opakovať správu č. 1',
			'settings.radio.voiceMessages.repeatOff' => 'Nie',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Po ${n} sekundách',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Poznámky k ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Tieto pamäte sú v rádiostanici zariadenia ${device}. Ich názvy a dĺžky patria tomuto zariadeniu.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Uložené v rádiostanici, kde ich vidia aj jej ostatní klienti.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Počkajte na indikátor [REC] na rádiostanici, potom podržte tlačidlo PTT a nahrajte správu. Ukončite ju stlačením tlačidla STOP tu v aplikácii ešte pred uvoľnením PTT, aby ste predišli nechceným cvaknutiam.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Počkajte, kým indikátor [REC] blikne aspoň štyrikrát, potom podržte tlačidlo PTT a nahrajte správu. Ukončite ju stlačením tlačidla STOP tu v aplikácii ešte pred uvoľnením PTT, aby ste predišli nechceným cvaknutiam.',
			'settings.radio.voiceMessages.pill' => 'Hlas',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Prehrať pamäť ${n}',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Nahrať pamäť ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Zastaviť nahrávanie',
			'settings.radio.voiceMessages.playing' => 'Prehráva sa…',
			'settings.radio.voiceMessages.recording' => 'Nahráva sa…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Prehráva sa ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Nahráva sa ${label}',
			'settings.radio.voiceMessages.doubtful' => 'Prehrala ju rádiostanica? Hneď hlásila, že je nečinná.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Pamäte musíte nahrať priamo na rádiostanici.',
			'settings.radio.avoidZeroBeat.title' => 'Vyhnúť sa zázneju na spotoch',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'S pripojenou rádiostanicou sa ladí o pár Hz vedľa CW spotu, aby všetci, ktorí naň odpovedajú, nevolali na rovnakom tóne.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Ladí sa presne na spotovanú frekvenciu.',
			'settings.radio.zeroBeatRange.title' => 'Záznej: rozsah vyhýbania',
			'settings.radio.zeroBeatRange.description' => 'Ako ďaleko od spotovanej frekvencie pristáť, na ktorúkoľvek stranu. Posun nikdy nie je blízko nuly — to by bol opäť nulový záznej.',
			'settings.help.title' => 'Pomoc a zdroje',
			'settings.help.description' => 'Komunita a podpora',
			'settings.help.forums' => 'Fóra Ham2K',
			'settings.help.forumsDescription' => 'Nájdite pomoc, dajte spätnú väzbu, diskutujte o nápadoch…',
			'settings.help.chat' => 'Ham2K Chat',
			'settings.help.chatDescription' => 'Discord server pre našu online komunitu',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videá a živé vysielania',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Pretože nikdy nemôžete mať príliš veľa fotiek…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Sledujte nás pre novinky a aktualizácie',
			'settings.help.contact' => 'Kontaktujte nás',
			'settings.help.contactDescription' => 'help@ham2k.com — ale najprv skúste Fóra alebo Chat!',
			'settings.exports.title' => 'Exporty',
			'settings.map.title' => 'Mapy',
			'settings.map.style.title' => 'Štýl mapy',
			'settings.map.styleOpts.automatic' => 'Automatický',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Súkromie',
			'settings.privacy.shareAppData.title' => 'Zdieľať údaje o používaní aplikácie',
			'settings.privacy.shareAppData.descriptionOn' => 'Pomáhate nám zlepšovať aplikáciu zdieľaním údajov o používaní, konfigurácii, zlyhaniach a výkone',
			'settings.privacy.shareAppData.descriptionOff' => 'Údaje o používaní aplikácie zostávajú súkromné.\nTím Ham2K nebude môcť zistiť zlyhania ani iné problémy.',
			'settings.privacy.shareOpData.title' => 'Zdieľať údaje o prevádzke',
			'settings.privacy.shareOpData.descriptionOn' => 'Niektoré údaje o prevádzke sa zdieľajú verejne a s inými používateľmi',
			'settings.privacy.shareOpData.descriptionOff' => 'Údaje o prevádzke zostávajú súkromné',
			'settings.privacy.privacyPolicy' => 'Zásady ochrany osobných údajov',
			'settings.privacy.termsOfService' => 'Podmienky služby',
			'settings.operatorCall' => 'Volací znak operátora',
			'settings.sync.title' => 'Cloudová synchronizácia',
			'settings.sync.moreSettings' => 'Ďalšie nastavenia synchronizácie',
			'settings.sync.enable' => 'Povoliť synchronizáciu',
			'settings.sync.deviceKey' => 'Kľúč zariadenia',
			'settings.peers.title' => 'Partnerské zariadenia',
			'settings.peers.enable' => 'Pripájať sa k iným zariadeniam',
			'settings.peers.enableDescription' => 'Povoliť zdieľanie prevádzok, logovania, CAT a GPS s inými zariadeniami cez lokálnu sieť',
			'settings.peers.bleEnable' => 'Pripájať sa cez Bluetooth',
			'settings.peers.bleDescription' => 'Použiť Bluetooth LE na pripojenie, aj keď nie je dostupná lokálna sieť',
			'settings.peers.thisDevice' => 'Toto zariadenie',
			'settings.peers.deviceName' => 'Názov',
			'settings.peers.deviceNameHint' => 'Ako toto zariadenie vidia iné zariadenia',
			'settings.peers.pairedDevices' => 'Prepojené zariadenia',
			'settings.peers.noPairedDevices' => 'Zatiaľ žiadne prepojené zariadenia. Zapnite túto funkciu na inom zariadení v tejto sieti a prepojte ich.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Prepojené zariadenia sa nedajú načítať: ${error}',
			'settings.peers.nearby' => 'V blízkosti',
			'settings.peers.connected' => 'Pripojené',
			'settings.peers.viaBluetooth' => 'cez Bluetooth',
			'settings.peers.connecting' => 'Pripája sa…',
			'settings.peers.syncing' => 'Synchronizuje sa…',
			'settings.peers.waitingForThem' => 'Čaká sa na druhé zariadenie',
			'settings.peers.notConnected' => 'Nepripojené',
			'settings.peers.wantsToPair' => 'chce zdieľať túto prevádzku',
			'settings.peers.allow' => 'Povoliť',
			'settings.peers.link' => 'Prepojiť',
			'settings.peers.reject' => 'Odmietnuť',
			'settings.peers.forget' => 'Zabudnúť',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Zabudnúť ${name}?',
			'settings.peers.forgetBody' => 'Prestane sa synchronizovať s týmto zariadením. Neskôr ho môžete znova povoliť a už zapísané spojenia zostanú zachované.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Prepojiť s ${name}',
			'settings.peers.pairBody' => 'Toto zariadenie je vo vašej lokálnej sieti a chce sa pripojiť.',
			'settings.peers.pairBodyBle' => 'Toto zariadenie je v blízkosti a chce sa pripojiť cez Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID zariadenia',
			'settings.peers.pairWarning' => 'Prepájajte iba so zariadeniami, ktoré poznáte. Žiadosť môže poslať ľubovoľné zariadenie v tejto sieti.',
			'settings.peers.pairWarningBle' => 'Prepájajte iba so zariadeniami, ktoré poznáte. Žiadosť môže poslať ľubovoľné zariadenie v blízkosti.',
			'settings.peers.problem' => ({required Object error}) => 'Lokálna sieť je nedostupná: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Pripojené k ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Stratené spojenie s ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Partnerské zariadenia: pripojené ${connected} z ${linked}',
			'settings.peers.screenEnable' => 'Zdieľať obrazovky a okná',
			'settings.peers.screenDescription' => 'Povoliť iným zariadeniam zobrazovať obrazovky alebo okná z tohto počítača',
			'settings.peers.screenSources' => 'Obrazovky a okná',
			'settings.peers.screenRefresh' => 'Obnoviť zoznam',
			'settings.peers.screenUnsupportedPlatform' => 'Toto zariadenie nemôže zdieľať svoju obrazovku. macOS to dokáže; každé zariadenie môže zobraziť obrazovku zdieľanú iným.',
			'settings.peers.screenUnsupportedVersion' => 'Zdieľanie obrazovky vyžaduje macOS 12.3 alebo novší. Toto zariadenie môže stále zobraziť obrazovku zdieľanú iným.',
			'settings.peers.screenNeedsPermission' => 'macOS potrebuje vaše povolenie na nahrávanie obrazovky, aby ju táto aplikácia mohla zdieľať.',
			'settings.peers.screenGrantPermission' => 'Požiadať o povolenie',
			'settings.peers.screenRelaunchAfterGranting' => 'Povoľte to v Systémových nastaveniach v časti Súkromie a bezpečnosť → Nahrávanie obrazovky, potom túto aplikáciu ukončite a znova otvorte — macOS informuje aplikáciu o zmene až pri ďalšom spustení.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Zdieľanie obrazovky: ${error}',
			'settings.peers.screenChooseTitle' => 'Vyberte, čo zdieľať',
			'settings.peers.screenChooseButton' => 'Vybrať, čo zdieľať…',
			'settings.peers.screenTabScreens' => 'Obrazovky',
			'settings.peers.screenTabApps' => 'Aplikácie',
			'settings.peers.screenTabWindows' => 'Okná',
			'settings.peers.screenTabEmpty' => 'Nič také sa nenašlo.',
			'settings.peers.screenSharedSummaryNone' => 'Zatiaľ nič nie je vybrané.',
			'settings.peers.screenThisDevice' => 'Toto zariadenie',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Zobrazené na ${devices}',
			'settings.peers.screenSharedToNobody' => 'Nezobrazuje sa',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Prestať zdieľať ${name}',
			'settings.developerMode' => 'Režim vývojára',
			'settings.syncPanel.configuration' => 'Konfigurácia synchronizácie',
			'settings.syncPanel.enableTitle' => 'Synchronizovať s Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Váš denník sa zálohuje a synchronizuje medzi zariadeniami',
			'settings.syncPanel.disabledDescription' => 'Vypnuté — zostáva iba na tomto zariadení',
			'settings.syncPanel.syncing' => 'Synchronizácia',
			'settings.syncPanel.account' => 'Účet',
			'settings.syncPanel.refresh' => 'Obnoviť',
			'settings.syncPanel.switchAccounts' => 'Prepnúť účty',
			'settings.syncPanel.switchAccountsDescription' => 'Prepojiť toto zariadenie s iným účtom pomocou QR kódu alebo e-mailu',
			'settings.syncPanel.connectionRequests' => 'Žiadosti o pripojenie',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Jedno zariadenie čaká na pripojenie k tomuto účtu', other: '${n} zariadení čaká na pripojenie k tomuto účtu', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mail účtu',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Potvrdenie bolo odoslané na ${email}. Zmenu dokončíte otvorením odkazu v ňom.',
			'settings.syncPanel.resendConfirmation' => 'Znova odoslať potvrdzovací e-mail',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Čaká sa na ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Znova odoslané na ${email}.',
			'settings.syncPanel.deviceLinked' => 'Toto zariadenie je teraz prepojené s týmto účtom.',
			'settings.syncPanel.checking' => 'Kontroluje sa…',
			'settings.syncPanel.notLinked' => 'Zatiaľ neprepojené',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Nahradiť lokálne údaje?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${n} prevádzka', other: '${n} prevádzok', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.syncPanel.counts' => 'Synchronizované údaje',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Toto zariadenie: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Čaká na nahratie: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Toto zariadenie: kontroluje sa…',
			'settings.syncPanel.countsServerChecking' => 'Server: kontroluje sa…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: nedostupný',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Týmto sa zálohuje a vymaže ${operations} a ${qsos} z tohto zariadenia a namiesto toho sa stiahnu údaje účtu. Záloha zostane v databáze tohto zariadenia.',
			'settings.syncPanel.replace' => 'Nahradiť',
			'settings.syncPanel.pendingBannerTitle' => 'Zistený nový účet Ham2K Log Filer',
			'settings.syncPanel.pendingBannerBody' => 'Ponechajte existujúce prevádzky a QSO tohto zariadenia a zlúčte ich do účtu, alebo ich nahraďte údajmi účtu (záloha zostane na tomto zariadení v oboch prípadoch).',
			'settings.syncPanel.combine' => 'Skombinovať',
			'settings.syncPanel.authIssueTitle' => 'Synchronizácia sa nemôže pripojiť',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer stále odmieta toto zariadenie. Skontrolujte svoj volací znak v nastaveniach synchronizácie.',
			'settings.syncPanel.openSettings' => 'Otvoriť nastavenia synchronizácie',
			'settings.accounts.title' => 'Účty, služby a zdroje údajov',
			'settings.accounts.none' => 'Žiadne aktívne rozšírenia s účtami',
			'settings.accounts.notConfigured' => 'Nenakonfigurované',
			'settings.accounts.connected' => 'Pripojené',
			'settings.accounts.cancelLogin' => 'Zrušiť prihlásenie',
			'settings.accounts.openInBrowser' => 'Otvoriť v prehliadači',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Prihlásený ako ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Stlačte Uložiť, aby tento účet zostal pripojený.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Pripojené k ${label}',
			'settings.accounts.connect' => 'Pripojiť',
			'settings.accounts.disconnect' => 'Odpojiť',
			'settings.accounts.connectedAs' => 'Pripojený ako',
			'settings.accounts.test' => 'Test',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Uloženie zlyhalo: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Prihlásenie zlyhalo: ${error}',
			'settings.accounts.lookupFailed' => 'Účty momentálne nie sú dostupné — skúste to o chvíľu znova',
			'settings.accounts.browserLoginTitle' => 'Dokončite prihlásenie vo webovom prehliadači',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Keď skončíte, prehliadač sa pokúsi otvoriť odkaz začínajúci na "${prefix}". Váš počítač ho pravdepodobne nemá čím otvoriť, preto tento odkaz skopírujte (z panela s adresou alebo z chybovej stránky, ktorú prehliadač zobrazí) a vložte ho sem.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger nedokázal otvoriť váš prehliadač. Skopírujte prihlasovací odkaz nižšie a otvorte ho sami, potom skopírujte odkaz, na ktorý vás presmeruje (začína na "${prefix}"), a vložte ho sem.',
			'settings.accounts.copyLoginLink' => 'Kopírovať prihlasovací odkaz',
			'settings.accounts.pastedLinkLabel' => 'Sem vložte odkaz',
			'settings.accounts.finishLogin' => 'Dokončiť prihlásenie',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Toto nie je prihlasovací odkaz — mal by začínať na "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Tento odkaz patrí k inému pokusu o prihlásenie. Zatvorte túto stránku a pripojte sa znova.',
			'settings.accounts.pastedLinkNoCode' => 'Tento odkaz neobsahuje prihlasovací kód. Najprv dokončite prihlásenie a potom skopírujte odkaz, na ktorý vás presmeruje.',
			'settings.accounts.pastedLinkMalformed' => 'Tento odkaz vyzerá orezaný. Skopírujte ho celý a vložte znova.',
			'settings.accounts.relayLoginWaiting' => 'Čaká sa, kým dokončíte prihlásenie — potom sa automaticky pokračuje.',
			'settings.accounts.loginNoResponse' => 'Toto zariadenie zatiaľ nedostalo odpoveď z prihlásenia. Ak ste ho už v prehliadači dokončili, zrušte to a skúste sa pripojiť znova.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger nedokázal automaticky otvoriť váš prehliadač. Prihlasovaciu stránku otvorte sami tlačidlom nižšie.',
			'settings.accounts.relayLoginUnavailable' => 'Synchronizačný server potrebný na dokončenie prihlásenia je nedostupný. Skontrolujte pripojenie a skúste to znova.',
			'settings.accounts.loginIncompleteResponse' => 'Tento pokus o prihlásenie sa správne nedokončil. Skúste sa pripojiť znova.',
			'settings.accounts.noKeyringTitle' => 'Prihlásenia k účtom sa nedajú uložiť',
			'settings.accounts.noKeyringText' => 'Ham2K Logger nemá prístup k službe kľúčenky na tomto počítači, takže prihlásenia k účtom sa nedajú uložiť ani načítať — pripojenie účtu zlyhá, kým sa to nevyrieši. Nainštalujte a spustite **gnome-keyring**, **KWallet** alebo **KeePassXC**, alebo odomknite kľúčenku, ktorú už máte, a potom reštartujte. Logovanie, exporty a dátové súbory nie sú ovplyvnené; synchronizácia denníka zostane počas tejto doby vypnutá.',
			'settings.accounts.noKeyringInline' => 'Prihlásenia sa nedajú uložiť: kľúčenka tohto počítača je nedostupná. Nainštalujte a spustite gnome-keyring, KWallet alebo KeePassXC, alebo odomknite tú, ktorú máte.',
			'settings.accounts.noSecureStorageInline' => 'Prihlásenia sa nedajú uložiť: zabezpečené úložisko tohto počítača je nedostupné.',
			'settings.station.title' => 'Konfigurácia stanice a ovládanie CAT',
			'settings.station.none' => 'Nie je nakonfigurované žiadne vybavenie',
			'settings.station.add' => 'Pridať',
			'settings.station.addTitle' => 'Pridať vybavenie',
			'settings.station.searchHint' => 'Hľadať vybavenie',
			'settings.station.noMatches' => 'Žiadne zodpovedajúce vybavenie',
			'settings.station.detectedEquipment' => 'Zistené vybavenie',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Nedá sa vyhľadávať rádiostanice: ${error}',
			'settings.station.edit' => 'Upraviť vybavenie',
			'settings.station.name' => 'Názov',
			'settings.station.nameDescription' => 'Ako ho nazývate — „Ľavá rádiostanica“. Nepovinné.',
			'settings.station.transport' => 'Pripojenie',
			'settings.station.host' => 'Adresa',
			'settings.station.hostDescription' => 'Názov hostiteľa alebo IP adresa rádiostanice vo vašej sieti.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Adresa je povinná',
			'settings.station.portInvalid' => 'Port musí byť od 1 do 65535',
			'settings.station.connect' => 'Pripojiť',
			'settings.station.disconnect' => 'Odpojiť',
			'settings.station.remove' => 'Odstrániť',
			'settings.station.removeTitle' => ({required Object name}) => 'Odstrániť ${name}?',
			'settings.station.removeMessage' => 'Odstráni sa iba z aplikácie. Nastavenia vybavenia zostanú nezmenené.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Nerozpoznaný typ vybavenia „${typeKey}“',
			'settings.station.report' => 'Nahlásiť',
			'settings.station.reportTitle' => 'Nahlásiť túto rádiostanicu',
			'settings.station.reportIntro' => 'Povedzte nám, o akú rádiostanicu ide a ako to dopadlo. Z vášho hlásenia vznikne karta, ktorú číta tím Ham2K, a to, čo napíšete o jej sprevádzkovaní, môže pomôcť ďalšiemu operátorovi s rovnakou rádiostanicou.',
			'settings.station.reportManufacturer' => 'Výrobca',
			'settings.station.reportManufacturerDescription' => 'Kto ju vyrába — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Výrobca je povinný',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'Model tak, ako ho uvádza samotná rádiostanica — „IC-7300“, „FT-991A“.',
			'settings.station.reportModelRequired' => 'Model je povinný',
			'settings.station.reportOutcome' => 'Ako to dopadlo?',
			'settings.station.reportOutcomeWorks' => 'Fungovala dobre',
			'settings.station.reportOutcomeIssues' => 'Fungovala, ale s problémami',
			'settings.station.reportOutcomeFails' => 'Vôbec nefungovala',
			'settings.station.reportOutcomeRequired' => 'Povedzte nám, ako to dopadlo',
			'settings.station.reportComments' => 'Komentáre',
			'settings.station.reportCommentsPlaceholder' => 'Čo fungovalo, čo nie, čokoľvek, čo vás prekvapilo.',
			'settings.station.reportHints' => 'Tipy na riešenie problémov',
			'settings.station.reportHintsPlaceholder' => 'Chcete navrhnúť tipy na riešenie problémov pre ostatných používateľov?',
			'settings.station.reportSend' => 'Odoslať hlásenie',
			'settings.station.reportSending' => 'Odosiela sa vaše hlásenie…',
			'settings.station.reportSent' => ({required Object ref}) => 'Ďakujeme — vaše hlásenie bolo zaevidované ako ${ref}.',
			'settings.station.reportSentNoRef' => 'Ďakujeme — vaše hlásenie bolo odoslané.',
			'settings.station.reportFailed' => ({required Object error}) => 'Hlásenie sa neodoslalo: ${error}',
			'settings.station.troubleshootingNotes' => 'Poznámky k riešeniu problémov',
			'settings.station.mainVfo' => 'Hlavné VFO',
			'settings.station.useAsMainVfo' => 'Použiť ako hlavné VFO',
			'settings.station.serialPort' => 'Sériový port',
			'settings.station.serialPortDescription' => 'Port, na ktorom sa zobrazuje rozhranie CAT rádiostanice.',
			'settings.station.serialPortNone' => 'Nenašli sa žiadne sériové porty',
			'settings.station.serialPortRequired' => 'Vyberte sériový port',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} z ${total}',
			'settings.station.serialPortSuggested' => 'odporúčaný',
			'settings.station.serialPortJustNow' => 'Nedávno pripojený',
			'settings.station.serialDeviceRequest' => 'Pridať USB zariadenie…',
			'settings.station.baudRate' => 'Rýchlosť (baud)',
			'settings.station.baudRateDescription' => 'Musí zodpovedať menu CAT rádiostanice. Pri nezhode rádiostanica posiela nezmysly a žiadnu chybu.',
			'settings.station.serialRtsHigh' => 'Držať RTS vo vysokej úrovni',
			'settings.station.serialRtsHighDescription' => 'Iba pre rádiostanicu, ktorá pred odpoveďou čaká na RTS, napríklad Yaesu so zapnutým CAT RTS. Na Digirig, SignaLink a väčšine domácky vyrobených káblov je RTS signál PTT a jeho držanie vo vysokej úrovni spustí vysielanie.',
			'settings.station.serialDtrHigh' => 'Držať DTR vo vysokej úrovni',
			'settings.station.serialDtrHighDescription' => 'Iba pre rozhranie CAT, ktoré sa napája z DTR, napríklad niektoré káble RS-232 pre FT-817. Na mnohých kábloch DTR kľúčuje CW alebo PTT a jeho držanie vo vysokej úrovni spustí vysielanie.',
			'settings.station.civAddress' => 'Adresa CI-V rádiostanice',
			'settings.station.civAddressDescription' => 'Hexadecimálne, ako ju zobrazuje menu CI-V rádiostanice. IC-705 sa dodáva s A4.',
			'settings.station.civAddressInvalid' => 'Adresa CI-V sú dve hexadecimálne číslice, 01 až FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Z ktorého slice rádiostanice toto pripojenie číta a ktorý ladí.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Vyberte jeden zo slice rádiostanice, A až H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} sa na tejto rádiostanici nepoužíva — vyberte iný slice alebo ho vytvorte v SmartSDR',
			'settings.station.channelNotInUse' => 'nepoužíva sa',
			'settings.station.channelHeldByUnknown' => 'používa ho iný program',
			'settings.station.flexNoSlices' => 'Táto rádiostanica nehlási žiadne slice — skontrolujte, či beží SmartSDR a či sa tento klient môže prihlásiť na odber',
			'settings.station.spectrumUnsupported' => 'Táto rádiostanica cez CAT neposiela spektrum',
			'settings.station.spectrumRequiresBaud' => 'Vyžaduje CAT s rýchlosťou 115200 bps',
			'settings.station.spectrumNoRadio' => 'Nie je pripojená žiadna rádiostanica',
			'settings.station.spectrumWaiting' => 'Čaká sa na spektrum rádiostanice…',
			'settings.station.spectrumUnavailable' => 'Zobrazenie spektra nie je dostupné',
			'settings.station.spectrumNoDaxChannel' => 'Všetky kanály DAX IQ na tejto rádiostanici sú obsadené',
			'settings.station.spectrumNoPanadapter' => 'Tento slice nemá na rádiostanici panadapter',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Rádiostanica odmietla stream DAX IQ (chyba ${code})',
			'settings.station.spectrumNoUdp' => 'Údaje o spektre z rádiostanice sa nedostanú k tomuto zariadeniu',
			'settings.station.spectrumScopeRefused' => 'Rádiostanica odmietla príkazy pre scope',
			'settings.station.spectrumOutOfRange' => 'Scope rádiostanice je nastavený mimo rozsahu, ktorý dokáže zobraziť',
			'settings.station.n3fjpNoRig' => 'N3FJP nemá nastavené rozhranie rádiostanice, takže toto sleduje to, čo sa zadá do N3FJP, nie rádiostanicu',
			'settings.station.winkeyerKeyPort' => 'Výstup kľúča',
			'settings.station.winkeyerKeyPortDescription' => 'Do ktorého z dvoch výstupných konektorov kľúčovača je pripojená vaša rádiostanica.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Použiť PTT kľúčovača',
			'settings.station.winkeyerPttDescription' => 'Kľúčovať linku PTT na tom istom konektore, pre zosilňovač alebo rádiostanicu, ktorá to potrebuje. Nechajte vypnuté pre rádiostanicu kľúčovanú cez konektor kľúča.',
			'settings.station.winkeyerNoAnswer' => 'Na tomto porte neodpovedal žiadny WinKeyer',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer počas vysielania prestal odpovedať; správa bola zahodená',
			'settings.station.radioUser' => 'Používateľské meno rádiostanice',
			'settings.station.radioPass' => 'Heslo rádiostanice',
			'settings.station.radioLoginDescription' => 'Prihlásenie z menu Network → Remote rádiostanice, nie vaše heslo k WiFi.',
			'settings.station.radioUserRequired' => 'Používateľské meno pre diaľkové ovládanie rádiostanice je povinné',
			'settings.station.connectFailedBusy' => 'Zariadenie sa používa',
			'settings.station.connectFailedDenied' => 'Prístup zamietnutý',
			'settings.station.connectFailedDevice' => 'Zariadenie sa nenašlo',
			'settings.station.connectFailedLines' => 'RTS/DTR sa nepodarilo udržať podľa nastavenia, preto bol port zatvorený. Iný program mohol nechať zapnuté hardvérové riadenie toku — odpojte a znova pripojte kábel.',
			'settings.station.connectFailedNetwork' => 'Rádiostanicu sa nedarí nájsť v sieti. Skontrolujte jej adresu a či je zapnutá a dostupná.',
			'settings.station.connectFailedTimeout' => 'Rádiostanica neodpovedala včas. Skontrolujte, či je zapnutá a dostupná.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - všeobecná',
			'settings.station.models.icomGeneric' => 'Icom - všeobecná',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - všeobecná',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - všeobecná',
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
			'settings.station.models.rigctld' => 'Rádiostanica ovládaná cez rigctld',
			'settings.station.models.rigctldNodeName' => 'Moja rádiostanica (cez rigctld)',
			'settings.station.models.flrig' => 'Rádiostanica ovládaná cez flrig',
			'settings.station.models.flrigNodeName' => 'Moja rádiostanica (cez flrig)',
			'settings.station.models.hrd' => 'Rádiostanica ovládaná cez Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Moja rádiostanica (cez HRD)',
			'settings.station.models.n3fjp' => 'Rádiostanica ovládaná cez N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Moja rádiostanica (cez N3FJP)',
			'settings.station.models.commander' => 'Rádiostanica ovládaná cez DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Moja rádiostanica (cez Commander)',
			'settings.station.models.antenna' => 'Anténa',
			'settings.station.models.key' => 'CW kľúč',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Všeobecná rádiostanica (zástupná)',
			'settings.station.models.placeholderRadioNodeName' => 'Moja rádiostanica',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.transports.network' => 'Sieť/WiFi',
			'settings.station.transports.usbSerial' => 'USB sériový',
			'settings.station.transports.wifi' => 'Sieť/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth sériový',
			'settings.station.transports.placeholder' => 'Zástupné',
			'settings.station.troubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.ft891Troubleshooting' => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ** (menu FT-891 **05-08**). Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni. Na Digirig, SignaLink alebo väčšine domácky vyrobených káblov je ten istý signál PTT, takže jeho zdvihnutie by spustilo vysielanie. Na vlastnom USB porte rádiostanice je alternatívou **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** nastaveniu CAT RATE rádiostanice (menu **05-06**). Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.yaesuBinaryTroubleshooting' => 'Táto rádiostanica používa starší päťbajtový CAT od Yaesu a keď niečo nie je v poriadku, vôbec neodpovedá. Takmer vždy ide o jedno z:\n\n- **Kábel musí prevádzať úrovne.** Konektor CAT vzadu nie je RS-232 ani USB; potrebuje CT-62 alebo rovnocenný adaptér. Obyčajný audio alebo dátový kábel pre CAT nefunguje.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice (**#14** na FT-817, **#19** na FT-857 alebo FT-897). Pri nezhode rádiostanica nič neposiela, a nikdy chybu.\n- **Nikdy nedovoľte, aby niečo zdvihlo RTS alebo DTR na tomto porte.** Na väčšine káblov pre tieto rádiostanice sú tieto linky PTT a kľúčovanie. Výnimkou je staršie rozhranie napájané z DTR: preň zapnite **Držať DTR vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\nTento ovládač bol napísaný podľa zverejnenej tabuľky CAT od Yaesu a na žiadnej z týchto rádiostaníc ešte nebežal. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.guohetecTroubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.guohetecTroubleshooting' => 'Q900 má dva protokoly CAT a táto položka používa jeho natívny namiesto napodobeniny FT-817. Vyberte tu **Guohetec Q900**, nie FT-817 — napodobenina podporuje menej príkazov a rádiostanica neoznamuje, ktorý používa.\n\n- **Kábel USB-C je linka CAT** a pripája aj zvukovú kartu. Rýchlosť na ňom nezáleží; port ignoruje, na čo je nastavený.\n- **Nikdy nedovoľte, aby niečo zdvihlo RTS alebo DTR na tomto porte.** Na sériovom kábli sú tieto linky PTT a kľúčovanie.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Rádiostanica druhej generácie sa správa inak** ako prvej. Dlho stlačte Menu, potom About: HW 2.0 je druhá generácia.\n\nTento ovládač bol napísaný podľa zverejneného protokolu výrobcu a na žiadnej z týchto rádiostaníc ešte nebežal. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.yaesuTroubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.yaesuTroubleshooting' => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni. Na Digirig, SignaLink alebo väčšine domácky vyrobených káblov je ten istý signál PTT, takže jeho zdvihnutie by spustilo vysielanie. Na vlastnom USB porte rádiostanice je alternatívou **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“. Kde sa toto nastavenie nachádza, závisí od modelu (menu **05-08** na FT-891).\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Módy sa riadia tabuľkou FT-891.** Väčšina rádiostaníc Yaesu jej zodpovedá, ale rádiostanica, ktorá čísluje módy inak, pri nich zobrazí a nastaví nesprávny mód. Frekvencia tým nie je ovplyvnená.',
			'settings.station.yaesuRs232Troubleshooting' => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **Konektor CAT je RS-232.** Potrebuje prevodník USB na sériový port a priamy kábel DB-9 — kábel null-modem prehadzuje linky a rádiostanica nič nepočuje.\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni, pokiaľ nie je zapnuté **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\nTáto položka bola napísaná podľa zverejnenej dokumentácie CAT a na žiadnej z týchto rádiostaníc ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.yaesuUsbTroubleshooting' => 'Rádiostanica prijíma príkazy, ale neodpovedá. Takmer vždy ide o jedno z:\n\n- **Použite prvý z dvoch USB portov rádiostanice.** CAT je zvyčajne na prvom (vo Windows port COM **Enhanced**); druhý (**Standard**) slúži na PTT a kľúčovanie. Výber ukazuje na prvý všade, kde ich dokáže rozlíšiť.\n- **CAT RTS musí byť na rádiostanici VYPNUTÉ.** Ak je zapnuté, rádiostanica čaká na signál handshake, ktorý aplikácia drží v nízkej úrovni, pokiaľ nie je zapnuté **Držať RTS vo vysokej úrovni** v sekcii „Rozšírené nastavenia“.\n- **Rýchlosť musí zodpovedať** menu CAT RATE rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.',
			'settings.station.k4SerialNotes' => 'Pripojte zadný konektor USB-B (PC) na K4. Pre CAT funguje USB-PC1 aj USB-PC2; vyberte nepoužívaný port a nastavte na rádiostanici zodpovedajúce Serial USB-PCn: Baud Rate. HaLo predvyplní 38400; v prípade potreby to zmeňte. Iná aplikácia musí používať druhý port alebo Ethernet.\n\nToto pripojenie ovláda rádiostanicu a jej kľúčovače; neposiela zvuk do HaLo.',
			'settings.station.k4TcpNotes' => 'Pripojte ethernetový konektor K4 do lokálnej siete. Zadajte jeho názov hostiteľa alebo IP adresu a port CAT 9200. Ide o ovládanie CAT, nie o samostatné pripojenie vzdialeného zvuku na porte 9204.\n\nHaLo ovláda rádiostanicu a jej kľúčovače bez streamovania zvuku alebo údajov panadaptera.',
			'settings.station.k4PowerTimeout' => 'Výkon K4 sa nezmenil, pretože rádiostanica nepotvrdila svoj výstupný rozsah. Skúste to znova.',
			'settings.station.k4PowerRange' => 'Výkon K4 musí byť 0,1–110 W, alebo 0,0001–0,01 W, keď je aktívny miliwattový výstup transvertora.',
			'settings.station.elecraftTroubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.elecraftTroubleshooting' => 'Rádiostanice Elecraft používajú Kenwood CAT a KX2 aj KX3 boli takto vyskúšané — VFO v oboch smeroch, prepínanie módov aj CW záznej fungujú.\n\nAk rádiostanica neodpovedá, takmer vždy ide o jedno z:\n\n- **Rýchlosť musí zodpovedať** hodnote nastavenej v **RS232** v menu rádiostanice. Z výroby je to 38400. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n\n**Ak je frekvencia správna, ale mód nie**, dajte nám vedieť. Položky KX2 a KX3 čítajú mód z pozície v stavovej odpovedi rádiostanice, ktorú sme určili podľa rádiostaníc, ktoré sme videli, a firmvér, ktorý ho dáva inam, sa k nám dostane iba cez hlásenie.\n\nO K3 zatiaľ nemáme žiadne hlásenie, preto ak ju používate, dajte nám vedieť, čo sa stane. K4 má vlastnú položku.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Ak sa rádiostanica pripojí, ale nezobrazuje frekvenciu',
			'settings.station.kenwoodTroubleshooting' => 'Tento ovládač je overený na Kenwood TS-590SG a TS-480, QRP Labs QMX a QCX-mini a Elecraft KX2 a KX3. Zvyšok radu je napísaný podľa zverejnených referencií CAT, preto nahláste, čo sa stane, v každom prípade.\n\nAk rádiostanica neodpovedá, takmer vždy ide o jedno z:\n\n- **Rýchlosť musí zodpovedať** menu CAT rádiostanice. Pri nezhode rádiostanica posiela nezmysly alebo nič, a nikdy chybu.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.\n- **Niektoré rádiostanice potrebujú povoliť CAT** v menu, inak vôbec neodpovedajú.\n\n**Viaceré SDR rozhrania používajú rovnaký protokol**, takže sa oplatí vyskúšať túto položku aj pre ne; rádiostanice Elecraft sú uvedené samostatne, pod Elecraft. Ak je frekvencia správna, ale mód je nesprávny alebo chýba, je to jediná časť, ktorá sa v rade líši — aplikácia ho zisťuje z rádiostanice a v náhradnom prípade sa pýta priamo, takže mód môže jednoducho meškať.',
			'settings.station.statusConnected' => 'Pripojené',
			'settings.station.statusLost' => 'Odpojené',
			'settings.station.notConfigured' => 'Nenakonfigurované',
			'settings.station.currentConfiguration' => 'Aktuálna konfigurácia',
			'settings.station.currentTransceiver' => 'Aktuálny transceiver',
			'settings.station.radioMode' => 'Mód rádiostanice',
			'settings.station.keyerNotSupported' => 'Aktuálna rádiostanica nepodporuje',
			'settings.station.catControlPreferences' => 'Predvoľby ovládania CAT',
			'settings.station.chooseTransceiver' => 'Vybrať transceiver',
			'settings.station.configurationSection' => 'Konfigurácia',
			'settings.station.noTransceiverSelected' => 'Nie je vybraný žiadny transceiver',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Použiť ${name} pre hlavné VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, zero: 'Žiadne transceivery', one: '${count} transceiver', other: '${count} transceiverov', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} anténa', other: '${count} antén', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} iné zariadenie', other: '${count} iných zariadení', ), 
			'settings.station.equipmentInventory' => 'Inventár vybavenia',
			'settings.station.equipmentInUse' => 'Ovládanie transceivera',
			'settings.station.noTransceiver' => 'Žiadny',
			'settings.station.peerRadioNotAvailable' => 'Nedostupné',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Na ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} je na inom zariadení',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Táto rádiostanica je pripojená k ${device}. Jej pripojenie a nastavenia sa konfigurujú na tom zariadení.',
			'settings.station.antennaInUse' => 'Používaná anténa',
			'settings.station.keyInUse' => 'Používaný kľúč',
			'settings.station.noneSelected' => 'Žiadny',
			'settings.station.moreSettings' => 'Ďalšie nastavenia',
			'settings.station.icomCivTroubleshootingTitle' => 'Ak sa pre tú istú rádiostanicu zobrazia dva sériové porty',
			'settings.station.icomCivTroubleshooting' => 'Viaceré rádiostanice Icom, vrátane IC-705, poskytujú naraz **dva** sériové USB porty (Icom ich nazýva Port A a Port B), oba predvolene nastavené na CI-V. Ani táto aplikácia, ani váš OS ich inak nerozlíšia: rovnaké USB vendor/product ID sa jednoducho zobrazí dvakrát, niekedy tu s príponou `#2`. **Správny je zvyčajne Port A** — obvykle prvý, ktorý váš OS alebo prehliadač uvádza, a kde táto aplikácia dokáže porty rozlíšiť, označí ho ako odporúčaný. Ak príkazy odchádzajú a rádiostanica nikdy neodpovie, skúste potom druhý port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Ak rádiostanica nikdy neodpovie',
			'settings.station.civAddressTroubleshooting' => '- **Adresa CI-V musí zodpovedať** menu rádiostanice. Táto položka predvyplní adresu, s ktorou sa model dodáva, ale práve pri rádiostanici zdieľajúcej zbernicu CI-V sa mení. Rámec odoslaný na nesprávnu adresu sa potichu ignoruje, čo vyzerá presne ako nefunkčný kábel.\n- **Rýchlosť musí zodpovedať** CI-V BAUD RATE rádiostanice (pri USB CI-V USB Baud Rate). Nastavte na rádiostanici rovnaké číslo, aké je zobrazené tu, **nie Auto**. Pri Auto sa niektoré rádiostanice, vrátane IC-7300, pripoja a asi po minúte prestanú odpovedať.\n- **Port môže držať iná aplikácia**: WSJT-X, fldigi aj rigctld ho nechávajú otvorený.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** sa dodáva s adresou `B6`, nie `94` predvyplnenou tu — namiesto toho vyberte položku IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- **IC-705** poskytuje dva sériové USB porty, oba pomenované podľa rádiostanice. CI-V je na **prvom** z nich, na ktorý výber ukazuje všade, kde ich dokáže rozlíšiť.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** používa CI-V na **Port A** z dvoch sériových USB portov, ktoré poskytuje.',
			'settings.station.x6100PortNote' => '\n- **X6100** používa CI-V na svojom porte **DEV** — druhom z dvoch sériových portov, ktoré poskytuje, a na ktorý výber ukazuje.',
			'settings.station.rigctldTroubleshootingTitle' => 'Ak sa aplikácia nemôže pripojiť',
			'settings.station.rigctldTroubleshooting' => 'Toto sa pripája k **démonu rigctld, ktorý spúšťate sami**, nie priamo k rádiostanici — backend Hamlib komunikuje s rádiostanicou a podporuje stovky modelov.\n\n- **Démon už musí bežať**, napr. `rigctld -m 1035 -r /dev/ttyUSB0`. Číslo modelu vašej rádiostanice nájdete pomocou `rigctl -l`.\n- **Z iného počítača** ho spustite s `-T 0.0.0.0`: predvolene rigctld prijíma pripojenia iba z počítača, na ktorom beží.\n- **Port** je 4532, pokiaľ ste démona nespustili s `-t`.\n- Po pripojení chýbajúca frekvencia zvyčajne znamená, že samotný démon sa nedostane k rádiostanici. Otestujte ho pomocou `rigctl -m 2 f` na počítači s démonom.',
			'settings.station.flrigTroubleshootingTitle' => 'Ak sa aplikácia nemôže pripojiť',
			'settings.station.flrigTroubleshooting' => 'Toto sa pripája k **programu flrig, ktorý spúšťate sami**, nie priamo k rádiostanici — flrig komunikuje s rádiostanicou a podporuje väčšinu značiek a modelov.\n\n- **flrig už musí bežať** s nakonfigurovaným a pripojeným transceiverom.\n- **Port** je 12345, pokiaľ ste ho nezmenili v konfigurácii flrig (Config → Setup → Server).\n- **Z iného počítača** sa uistite, že server flrig je dostupný. Počúva na všetkých rozhraniach, ale váš firewall s tým nemusí súhlasiť.\n- Po pripojení chýbajúca frekvencia zvyčajne znamená, že samotný flrig sa nedostane k rádiostanici. Skontrolujte, či displej flrig sleduje ladenie.',
			'settings.station.hrdTroubleshootingTitle' => 'Ak sa aplikácia nemôže pripojiť',
			'settings.station.hrdTroubleshooting' => 'Toto sa pripája k **Rig Control z Ham Radio Deluxe, ktorý beží na vašom počítači**, nie priamo k rádiostanici — HRD komunikuje s rádiostanicou.\n\n- **Rig Control už musí bežať** a byť pripojený k rádiostanici.\n- **Jeho IP server musí byť povolený.** Rig Control komunikuje s inými programami iba cez neho.\n- **Port** je 7809, pokiaľ ste ho nezmenili v nastaveniach IP servera.\n- **Z iného počítača** sa uistite, že váš firewall pripojenie prepustí.\n\nTáto položka bola napísaná podľa zverejnených popisov protokolu HRD a s HRD ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Ak sa aplikácia nemôže pripojiť',
			'settings.station.n3fjpTroubleshooting' => 'Toto sa pripája k **logovaciemu programu N3FJP, ktorý beží na vašom počítači**, nie priamo k rádiostanici — N3FJP komunikuje s rádiostanicou.\n\n- **API programu musí byť zapnuté**: Settings → Application Program Interface, zaškrtnite **TCP API Enabled**.\n- **Port** je 1100, pokiaľ ste ho tam nezmenili.\n- **N3FJP musí mať nastavené rozhranie rádiostanice**, aby mohol sledovať alebo ladiť rádiostanicu. Bez neho hlási iba to, čo sa zadá do jeho vstupného okna.\n- N3FJP hlási iba pásmo, mód a frekvenciu: žiadny výkon, žiadny stav vysielania.\n\nTáto položka bola napísaná podľa zverejneného API N3FJP a s N3FJP ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.commanderTroubleshootingTitle' => 'Ak sa aplikácia nemôže pripojiť',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshooting' => 'Toto sa pripája k **DXLab Commander, ktorý beží na vašom počítači**, nie priamo k rádiostanici — Commander komunikuje s rádiostanicou.\n\n- **Commander už musí bežať** a byť pripojený k rádiostanici.\n- **Jeho sieťová služba musí byť zapnutá**: tlačidlo **Net Serv** na paneli Radio v okne Configuration programu Commander.\n- **Port** je 52002, tretí port bloku začínajúceho na **Base Port** v Net Serv (52000, pokiaľ ste ho nezmenili).\n- **Z iného počítača** sa uistite, že váš firewall pripojenie prepustí.\n\nTáto položka bola napísaná podľa zverejnených TCP správ programu Commander a s Commanderom ešte nebežala. Ak funguje len napoly, oplatí sa to nahlásiť.',
			'settings.station.ic705TroubleshootingTitle' => 'Ak rádiostanica nikdy neodpovie',
			'settings.station.ic705Troubleshooting' => 'Rádiostanica má **jedinú** reláciu diaľkového ovládania. Keď sa prihlásenie ignoruje, takmer vždy ju používa niečo iné.\n\n- **Zatvorte všetkých ostatných klientov.** wfview alebo RS-BA1 pripojený k tej istej rádiostanici drží túto jedinú reláciu a prihlásenie tu sa medzitým jednoducho ignoruje.\n- **Skontrolujte sieťové nastavenia rádiostanice.** WLAN musí byť zapnutá, rádiostanica musí byť v tej istej sieti a jej funkcia diaľkového ovládania (Network) musí byť povolená.\n- **Vypnite a zapnite WLAN rádiostanice**, ak zostane zaseknutá. Spoľahlivo to uvoľní reláciu zaseknutú na rádiostanici.\n\n**Nesprávne heslo je výslovne odmietnuté**, nie prijaté mlčaním. Ak ste sa dostali sem a nie k správe „odmietnuté“, problém nie je v hesle.',
			'settings.station.statusStale' => 'Neodpovedá',
			'settings.station.statusDisconnected' => 'Nepripojené',
			'settings.station.statusConnecting' => 'Pripája sa…',
			'settings.station.statusDisconnecting' => 'Odpája sa…',
			'settings.station.statusError' => 'Pripojenie zlyhalo',
			'settings.station.currentRadioSettings' => 'Aktuálne nastavenia rádiostanice',
			'settings.station.notSupportedByThisRadio' => 'Táto rádiostanica nepodporuje',
			'settings.station.keyerRowLabel' => 'Kľúčovač',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Fónia',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Hlasový kľúčovač: pamäte v rádiostanici (${count})',
			'settings.station.antennaBands' => 'Pásma',
			'settings.station.antennaType' => 'Typ antény',
			'settings.station.antennaTypeRequired' => 'Vyberte typ antény',
			'settings.station.antennaTypes.dipole' => 'Dipól',
			'settings.station.antennaTypes.vertical' => 'Vertikál',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / smerovka',
			'settings.station.antennaTypes.loop' => 'Slučka',
			'settings.station.antennaTypes.longWire' => 'Dlhý drôt / EFHW',
			'settings.station.antennaTypes.other' => 'Iná',
			'settings.station.keyType' => 'Typ kľúča',
			'settings.station.keyTypeRequired' => 'Vyberte typ kľúča',
			'settings.station.keyTypes.straight' => 'Ručný kľúč',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mechanický poloautomat)',
			'settings.station.keyTypes.fullyAutomatic' => 'Plne automatický kľúčovač',
			'settings.station.keyTypes.singlePaddle' => 'Jednopádlový kľúč',
			'settings.station.keyTypes.dualPaddle' => 'Dvojpádlový kľúč',
			'settings.station.keyTypes.computerDriven' => 'Riadený počítačom',
			'settings.station.keyTypes.other' => 'Iný',
			'settings.station.softwareIntermediaries' => 'Softvéroví sprostredkovatelia',
			'settings.station.otherBrands' => 'Iné značky',
			'settings.station.otherEquipment' => 'Iné vybavenie (antény, kľúče atď.)',
			'settings.station.newAntenna' => 'Nová anténa',
			'settings.station.newKey' => 'Nový kľúč',
			'settings.station.newKeyer' => 'WinKeyer (K1EL alebo kompatibilný)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT kľúčovač v ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Kľúč na ${device}',
			'settings.station.cwKeyerArea' => 'Oblasť kľúčovača',
			'settings.station.trackStationInfo' => 'Zaznamenávať informácie o stanici pre každé QSO',
			'settings.station.includeStationInfoInAdif' => 'Zahrnúť do exportov ADIF',
			'settings.station.whatToTrack' => 'Čo zaznamenávať?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Výkon',
			'settings.station.watts' => 'Watty',
			'settings.station.trackFieldAntenna' => 'Anténa',
			'settings.station.trackFieldKey' => 'CW kľúč',
			'settings.station.placeholderConnectDelay' => 'Oneskorenie pripojenia (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Ako dlho trvá simulovaný handshake. Prázdne alebo 0 sa pripojí okamžite.',
			'settings.station.placeholderDropAfter' => 'Odpojiť po (sekundy)',
			'settings.station.placeholderDropAfterDescription' => 'Samo zatvorí pripojenie, aby sa vyskúšalo opätovné pripojenie. Prázdne alebo 0 sa nikdy neodpojí.',
			'settings.station.placeholderFailConnect' => 'Vždy zlyhať pri pripájaní',
			'settings.station.placeholderConnectFailure' => 'Zástupná rádiostanica má nastavené toto pripojenie odmietnuť',
			'settings.station.placeholderFreq' => 'Frekvencia (kHz)',
			'settings.station.placeholderFreqDescription' => 'Kde zástupná rádiostanica začína. Potom hlási to, na čo ju aplikácia naladí.',
			'settings.station.placeholderMode' => 'Mód',
			'settings.station.placeholderModeDescription' => 'Mód, na ktorom zástupná rádiostanica začína, napr. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Výkon (watty)',
			'settings.station.placeholderPurpose' => 'Použite túto rádiostanicu na zaznamenávanie, ktorú rádiostanicu používate, na účely logovania',
			'settings.station.placeholderReplyDelay' => 'Oneskorenie odpovede (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Ako dlho trvá zástupnej rádiostanici nahlásiť zmenu. Prázdne alebo 0 odpovie okamžite.',
			'settings.station.cwKeyerField' => 'CAT CW kľúčovač',
			'settings.station.cwKeyerFieldDescription' => 'Či táto rádiostanica kľúčuje CW z textu cez CAT. Vypnuté pre rádiostanicu, ktorú aplikácia nepozná.',
			'settings.station.voiceMemories' => 'Hlasové pamäte',
			'settings.station.voiceMemoriesDescription' => 'Koľko hlasových pamätí rádiostanica prehráva cez CAT. 0 pre žiadne.',
			'settings.station.voiceMemoriesInvalid' => 'Celé číslo, 0 alebo viac',
			'settings.station.yaesuMeterCapture' => 'Zaznamenávať hodnoty meračov',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Počas vysielania číta merač výstupného výkonu a príznak vysokého SWR rádiostanice a vypisuje surové hodnoty do logu. Slúži na zostavenie stupnice, ktorú Yaesu nezverejňuje — hodnoty sa nezobrazujú ako merače.',
			'settings.station.yaesuMeterCaptureDescription' => 'Počas vysielania číta merače PO, SWR a ALC rádiostanice a vypisuje surové hodnoty do logu. Slúži na zostavenie stupnice, ktorú Yaesu nezverejňuje — hodnoty sa nezobrazujú ako merače.',
			'settings.station.telemetryInterval' => 'Interval čítania meračov (ms)',
			'settings.station.telemetryIntervalDescription' => 'Ako často čítať merače rádiostanice počas vysielania. Nechajte prázdne pre najrýchlejšie, čo toto pripojenie zvládne, až do 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Celý počet milisekúnd, ${min} až ${max}',
			'settings.station.pollInterval' => 'Interval dopytovania v nečinnosti (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Ako často sa pýtať rádiostanice na frekvenciu a mód, keď sa nemenia. Nechajte prázdne pre ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Celý počet milisekúnd, ${min} až ${max}',
			'settings.station.advancedSettings' => 'Rozšírené nastavenia',
			'settings.station.placeholderSwr' => 'Hodnota SWR',
			'settings.station.placeholderSwrDescription' => 'Čo táto rádiostanica hlási na merači SWR počas vysielania. Nad 1,8 panel upozorní.',
			'settings.station.placeholderSwrInvalid' => 'Číslo, 1 alebo viac',
			'settings.station.keyerNone' => 'Žiadny',
			'settings.station.cwDialect' => 'Dialekt kľúčovania CW',
			'settings.station.cwDialectDescription' => 'Akú podobu príkazu KY táto rádiostanica prijíma. Žiadny znamená bez kľúčovania CW cez CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, doplnené na 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY text)',
			'settings.station.voiceDialect' => 'Dialekt hlasového kľúčovača',
			'settings.station.voiceDialectDescription' => 'Ako táto rádiostanica prehráva hlasové pamäte cez CAT. Žiadny znamená bez hlasových pamätí cez CAT. S dialektom a bez počtu platí predvolený počet dialektu.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, štýl TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB a DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (stlačenia prepínačov)',
			'settings.station.placeholderDiagnostic' => 'Simulované',
			'settings.station.placeholderWholeNumberInvalid' => 'Musí byť celé číslo, 0 alebo viac',
			'settings.station.placeholderFreqInvalid' => 'Musí byť frekvencia v kHz, väčšia ako nula',
			'settings.station.placeholderModeInvalid' => 'Musí byť názov módu, napr. USB, CW, FT8',
			'settings.station.switchLayout' => 'Rozloženie',
			'settings.station.switchLayoutDescription' => 'Na ktorú stranu prepínača sú pripojené vaše rádiostanice.',
			'settings.station.switchLayoutRequired' => 'Vyberte, ako je prepínač zapojený',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Prepínač odmietol „${command}“ (chyba ${code})',
			'settings.station.switchBusyTransmitting' => 'Tento port vysiela — anténa sa nezmenila',
			'settings.station.switchNoAntenna' => 'Žiadna',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Anténa na porte ${port}',
			'settings.station.switchAntennaForDescription' => 'Ktorá z vašich antén je pripojená k tomuto portu prepínača.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => 'Antény: ${antennas}, rádiostanice: ${radios}',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => 'Antény: ${antennas}, 1 rádiostanica',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 anténa, rádiostanice: ${radios}',
			'settings.station.switchCommonPort' => 'Spoločný',
			'settings.station.dcnAddress' => 'Adresa zariadenia',
			'settings.station.dcnAddressDescription' => 'Adresa nastavená na DIP prepínačoch modulu. Modul koaxiálneho relé sa z výroby dodáva s adresou 2.',
			'settings.station.dcnAddressRequired' => 'Musí byť adresa zariadenia od 1 do 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'sleduje údaje o pásme',
			'settings.station.switchPortTransmittingHint' => 'vysiela — teraz sa nedá zmeniť',
			'settings.station.switchCurrentStateHeader' => 'Aktuálny stav',
			'settings.station.switchCurrentStateDescription' => 'Na ktorej anténe je práve každý port rádiostanice. Zmeny sa prejavia okamžite.',
			'settings.station.switchWiringHeader' => 'Zapojenie',
			'settings.station.switchPortInhibitedHint' => 'vysielanie zablokované',
			'settings.station.configUnreadable' => 'Uložené nastavenia tejto rádiostanice sa nepodarilo prečítať. Otvorte jej nastavenia a zadajte ich znova, alebo ju odstráňte a pridajte späť.',
			'settings.station.autoConnectHeld' => 'HaLo prestal odpovedať, keď sa naposledy pripájal k tejto rádiostanici, preto sa tentoraz nepripojil sám. Stlačte Pripojiť a skúste to znova.',
			'settings.offlineData.title' => 'Offline údaje',
			'settings.offlineData.noFiles' => 'Žiadne dátové súbory',
			'settings.offlineData.noFilesDescription' => 'Povoľte rozšírenia aktivít alebo vyhľadávania a ich offline údaje sa budú sťahovať sem.',
			'settings.offlineData.refresh' => 'Obnoviť',
			'settings.offlineData.refreshing' => 'Obnovuje sa…',
			'settings.offlineData.updateAll' => 'Aktualizovať všetko',
			'settings.offlineData.updatingAll' => 'Aktualizujú sa všetky dátové súbory…',
			'settings.offlineData.neverDownloaded' => 'Nikdy nestiahnuté',
			'settings.offlineData.updatedJustNow' => 'Aktualizované práve teraz',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Aktualizované pred ${days} d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Aktualizované pred ${days} d ${hours} h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Aktualizované pred ${hours} h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Aktualizované pred ${hours} h ${minutes} min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Aktualizované pred ${minutes} min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Posledné sťahovanie malo iba ${imported} z ${existing} záznamov a nebolo použité. Obnovením ho prijmete.',
			'settings.offlineData.extensionsSection' => 'Rozšírenia',
			'settings.profiles.notSet' => 'Nenastavené',
			'settings.profiles.personalInfo' => 'Osobné údaje',
			'settings.profiles.personalInfoNote' => 'Môžu byť zahrnuté do vygenerovaných denníkov, ak sú potrebné na odoslanie',
			'settings.profiles.name' => 'Meno',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Klub',
			'settings.profiles.arrlSection' => 'ARRL sekcia',
			'settings.profiles.racSection' => 'RAC sekcia',
			'settings.profiles.section' => 'Sekcia',
			'settings.search.clear' => 'Vymazať',
			'settings.search.hint' => 'Hľadať v nastaveniach',
			'settings.developer.developerModeDescription' => 'Povoliť upozornenia pre vývojárov, ladiace logy a nástroje.',
			'settings.developer.experiments' => 'Experimenty',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} povolený', other: '${count} povolených', ), 
			'settings.developer.patchTrack' => 'Vetva Code Push',
			'settings.developer.patchTrackDescription' => 'Ktorý okruh aktualizácií kódu cez internet toto zariadenie sleduje. Odvážnejšie okruhy dostávajú opravy skôr, ale menej otestované. Aktualizácie kódu sa uplatnia pri ďalšom reštarte.',
			'settings.developer.trackStable' => 'Stabilná',
			'settings.developer.trackUnstable' => 'Nestabilná',
			'settings.developer.trackBleeding' => 'Vývojová',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Kontroluje sa aktualizácia kódu na „${track}“…',
			'settings.developer.patchDownloaded' => 'Aktualizácia kódu stiahnutá — reštartujte aplikáciu a uplatní sa.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Žiadna nová aktualizácia kódu na „${track}“.',
			'settings.developer.noPatchInstalled' => 'Nie je nainštalovaná žiadna aktualizácia kódu — beží vydaná binárka.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Beží aktualizácia kódu č. ${patch}.',
			'settings.developer.deepLinks' => 'Priame odkazy',
			'settings.developer.registerUrlSchemes' => 'Registrovať schémy URL',
			'settings.developer.registerUrlSchemesDescription' => 'Odkazy com.ham2k:// budú otvárať túto kópiu aplikácie',
			'settings.developer.registerUrlSchemesDone' => 'Táto kópia teraz otvára odkazy com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Registrácia zlyhala: ${error}',
			'settings.developer.systemInformation' => 'Informácie o systéme',
			'settings.developer.appVersion' => 'Verzia aplikácie',
			'settings.developer.dataFolder' => 'Priečinok s údajmi',
			'settings.developer.loading' => '(načítava sa…)',
			'settings.developer.panelLoadFailed' => 'Tento panel nastavení sa nepodarilo načítať.',
			'settings.developer.extDevServer' => 'Vývojový server rozšírení',
			'settings.developer.extensionSettings' => 'Nastavenia rozšírení',
			'settings.developer.extDevServerDescription' => 'Načítavať rozšírenia z vývojového servera vo vašej sieti namiesto vstavaných v aplikácii a znova ich načítať pri každom uložení.',
			'settings.developer.extDevServerAddress' => 'Adresa servera',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Pripojiť',
			'settings.developer.extDevServerDisconnect' => 'Odpojiť',
			'settings.developer.extDevServerConnecting' => 'Pripája sa…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Poskytuje sa ${count} rozšírenie: ${keys}', other: 'Poskytuje sa ${count} rozšírení: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Nepripojené',
			'settings.developer.extDevServerReconnect' => 'Znova pripojiť pri spustení',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Posledné načítanie: ${key} o ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} rozšírenie sa nedá zostaviť', other: '${count} rozšírení sa nedá zostaviť', ), 
			'settings.developer.catalog' => 'Katalóg rozšírení',
			'settings.developer.catalogDescription' => 'Čítať katalóg z iného servera — lokálneho pri práci na samotnom katalógu. Prázdne znamená catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Adresa katalógu',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Vetvy pri hľadaní v katalógu',
			'settings.developer.catalogSearchStable' => 'Iba stabilné',
			'settings.developer.catalogSearchUnstable' => 'Nestabilné alebo lepšie',
			'settings.developer.catalogSearchBleeding' => 'Vývojové alebo lepšie',
			'settings.about.notices' => 'Oznámenia a správy',
			'settings.about.noticesDescription' => 'Oznámenia a stavové správy',
			'settings.about.releaseNotes' => 'Poznámky k vydaniu',
			'settings.about.copiedVersion' => 'Podrobnosti o verzii skopírované do schránky',
			'settings.panels.settings' => 'Predvoľby aplikácie',
			'settings.panels.settingsDescription' => 'Prispôsobte si aplikáciu podľa seba',
			'settings.panels.commonSettings' => 'Bežné predvoľby',
			'settings.panels.syncDescription' => 'Zálohujte a synchronizujte svoje denníky medzi zariadeniami',
			'settings.panels.accountsDescription' => 'Prihlasovacie údaje k službám, offline údaje a ďalšie',
			'settings.panels.extensions' => 'Rozšírenia a funkcie',
			'settings.panels.extensionsDescription' => 'Aktivity, súťaže, panely prehľadu a ďalšie funkcie',
			'settings.panels.profilesDescription' => 'Volací znak operátora a profil stanice',
			'settings.panels.stationProfiles' => 'Profily stanice',
			'settings.panels.developerSettings' => 'Nastavenia pre vývojárov',
			'settings.panels.developerSettingsDescription' => 'Nástroje na ladenie a vývoj',
			'settings.panels.about' => 'O aplikácii',
			'settings.panels.aboutDescription' => 'Verzia, autori a právne informácie',
			'settings.panels.unavailableTitle' => 'Niektoré nastavenia nie sú dostupné',
			'settings.panels.unavailableText' => 'Prostredie rozšírení sa nepodarilo spustiť, preto chýbajú nastavenia pridané rozšíreniami.',
			'settings.panels.station' => 'Konfigurácia stanice',
			'settings.panels.stationDescription' => 'Ovládanie CAT a ďalšie možnosti',
			'settings.panels.peers' => 'Partnerské zariadenia',
			'settings.panels.peersDescription' => 'Pripojiť sa k iným zariadeniam v blízkosti',
			'settings.showMoreSettings' => 'Zobraziť ďalšie nastavenia',
			'settings.gridPrecision' => 'Presnosť lokátora',
			'settings.gridPrecisionOpts.six' => '6 miest (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 miest (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 miest',
			'settings.gridPrecisionDescription.eight' => '8 miest',
			'commands.enableSyncFirst' => 'Najprv povoľte synchronizáciu v Nastaveniach.',
			'commands.fullResyncStarted' => 'Úplná opätovná synchronizácia sa začala — lokálne údaje boli najprv zálohované.',
			'commands.noDataFilesMatched' => ({required Object target}) => '„${target}“ nezodpovedajú žiadne dátové súbory.',
			'commands.reloadFailed' => ({required Object error}) => 'Opätovné načítanie zlyhalo: ${error}',
			'commands.reloadingAll' => 'Znova sa načítavajú všetky dátové súbory…',
			'commands.reloadingTarget' => ({required Object target}) => 'Znova sa načítavajú dátové súbory ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Neznámy experiment „${token}“',
			'commands.experimentEnabled' => ({required Object name}) => '${name} povolený',
			'commands.experimentDisabled' => ({required Object name}) => '${name} vypnutý',
			'commands.sentryTestSent' => 'Testovacie hlásenie chyby odoslané do Sentry',
			'commands.sentryTestLocalOnly' => 'Sentry je v tejto zostave vypnuté — testovacia chyba bola zaznamenaná iba lokálne',
			'commands.noOperationOpen' => 'Tento príkaz potrebuje otvorenú prevádzku',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Nie je známe, ako označiť „${kind}“',
			'commands.operationAlreadyStarted' => 'Táto prevádzka už má značku začiatku',
			'commands.couldNotOpenLocation' => 'Prestávka bola pridaná, ale obrazovku polohy sa nepodarilo otvoriť',
			'commands.noTestOperations' => 'Žiadne testovacie prevádzky na vyčistenie',
			'commands.purgeTestsUnavailable' => 'PURGETESTS potrebuje zobraziť potvrdzovacie okno, ktoré tu nie je dostupné',
			'commands.syncAllUnavailable' => 'SYNCALL potrebuje zobraziť potvrdzovacie okno, ktoré tu nie je dostupné',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Vyčistená ${count} testovacia prevádzka', other: 'Vyčistených ${count} testovacích prevádzok', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Vyčistených ${purged} z ${total} testovacích prevádzok — zvyšok zlyhal; skúste PURGETESTS znova',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Vyčistené ${count} testovacie spojenie bez prevádzky', other: 'Vyčistených ${count} testovacích spojení bez prevádzky', ), 
			'commands.purgeTestsContactsFailed' => 'Testovacie prevádzky boli vyčistené, ale testovacie spojenia bez prevádzky zlyhali; skúste PURGETESTS znova',
			'commands.purgeTestsNothingToDo' => 'Nič nebolo vyčistené',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Odstránených ${removed} z ${total} testovacích prevádzok — zvyšok zlyhal; skúste Skontrolovať znova',
			'commands.receivedPurgesFailed' => 'Tieto testovacie prevádzky sa nepodarilo odstrániť — skúste Skontrolovať znova',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} testovacia prevádzka bola odstránená na inom zariadení', other: '${count} testovacích prevádzok bolo odstránených na inom zariadení', ), 
			'commands.receivedPurgesReview' => 'Skontrolovať',
			'commands.settingOn' => 'Zap.',
			'commands.settingOff' => 'Vyp.',
			'commands.settingEmpty' => '(prázdne)',
			'commands.settingSecretSet' => '(nastavené)',
			'commands.settingSecretUnset' => '(nenastavené)',
			'commands.settingSelectedCount' => ({required Object count}) => 'Vybrané: ${count}',
			'commands.settingExpectsOnOff' => 'on alebo off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'jedno z: ${choices}',
			'commands.settingExpectsNumber' => 'číslo',
			'commands.settingVanished' => ({required Object label}) => '„${label}“ už nie je dostupné',
			'commands.noCwKeyer' => 'Žiadna pripojená rádiostanica nedokáže kľúčovať CW',
			'commands.noKeyer' => 'Žiadna pripojená rádiostanica nedokáže kľúčovať CW ani prehrávať hlasové pamäte',
			'commands.keyerNeedsOperation' => 'Na použitie CW kľúčovača otvorte prevádzku',
			'commands.keyerExperimentOff' => 'Kľúčovanie CW je vypnuté — zapnite ho pomocou EXP KEYER',
			'commands.esmExperimentOff' => 'Enter odosiela správy je vypnuté — zapnite ho pomocou EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Odosiela sa CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW správa F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW správa F${n} nebola odoslaná: rozšírenia nie sú pripravené',
			'commands.settingNotStored' => ({required Object label}) => '„${label}“ túto hodnotu neprijalo',
			'commandDialog.hint' => 'Hľadajte volacie znaky alebo zadajte príkaz',
			'commandDialog.noResults' => ({required Object text}) => '„${text}“ nič nezodpovedá',
			'commandDialog.sectionCommands' => 'Príkazy',
			'commandDialog.sectionGoTo' => 'Prejsť na',
			'commandDialog.sectionOperations' => 'Prevádzky',
			'commandDialog.goHome' => 'Domov',
			'commandDialog.goSettings' => 'Nastavenia',
			'commandDialog.goNewOperation' => 'Nová prevádzka',
			'commandDialog.runTyped' => ({required Object text}) => 'Spustiť „${text}“',
			'commandDialog.sectionSuggestions' => 'Skúste',
			'commandDialog.lookingUp' => 'Vyhľadáva sa volací znak…',
			'commandDialog.blockedByPane' => 'Príkazy sa nedajú použiť, kým je otvorený panel alebo dialóg',
			'expiredBuild.title' => 'Platnosť tejto zostavy vypršala',
			'expiredBuild.body' => 'Navštívte ham2k.com a stiahnite si novšiu verziu.',
			'expiredBuild.visit' => 'Navštíviť ham2k.com',
			'expiredBuild.dismiss' => 'Napriek tomu pokračovať',
			'staleness.codePushFloorTitle' => 'Čaká dôležitá aktualizácia',
			'staleness.codePushFloorBody' => 'Táto verzia obsahuje opravu, ktorú ešte nemáte.',
			'staleness.restartToApply' => 'Reštartujte aplikáciu a uplatní sa.',
			'staleness.quitAndReopen' => 'Ukončite aplikáciu a znova ju otvorte, aby sa uplatnila.',
			'staleness.reopenToApply' => 'Zatvorte aplikáciu a znova ju otvorte, aby sa uplatnila.',
			'staleness.ignoreForNow' => 'Zatiaľ ignorovať',
			'spotting.noQsoYet' => 'Zatiaľ nie je zapísané žiadne QSO na spotovanie.',
			'spotting.setFrequencyFirst' => 'Najprv nastavte frekvenciu.',
			'spotting.nothingToSpot' => 'Nie je čo spotovať — žiadne rozšírenie tu neponúka spotovanie.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} zlyhal: ${message}',
			'spotting.unknownError' => 'neznáma chyba',
			'spotting.notSent' => 'Spot nebol odoslaný.',
			'spotting.notRefreshedOffline' => 'Bez pripojenia — spoty neboli obnovené',
			'dataFiles.downloading' => 'Sťahuje sa…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name} sa nepodarilo stiahnuť',
			'dataFiles.downloadFailedWebHint' => 'Môže ísť o problém so sieťou alebo hostiteľ tohto odkazu nemusí podporovať priame sťahovanie z webového prehliadača. Skúste desktopovú alebo mobilnú aplikáciu, alebo iné umiestnenie súboru.',
			'dataFiles.downloadTimedOut' => 'Server odpovedal príliš pomaly. Skúste to neskôr.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} odpovedal chybou (HTTP ${status}). Skúste to neskôr.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} nedokázal poskytnúť tento súbor (HTTP ${status}). Skontrolujte, či je jeho adresa stále správna.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name} sa nepodarilo spracovať',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Sťahovanie malo iba ${imported} z ${existing} záznamov na tomto zariadení, preto boli vynechané záznamy ponechané. Obnovením v Nastavenia › Offline údaje ho napriek tomu prijmete.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Importovaný ${count} záznam pre ${label}.', other: 'Importovaných ${count} záznamov pre ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Importované údaje pre ${label}.',
			'dataFiles.cleanedUpTitle' => 'Údaje rozšírení vyčistené',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Odstránené údaje ${count} dátového súboru z vypnutých rozšírení.', other: 'Odstránené údaje ${count} dátových súborov z vypnutých rozšírení.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} záznamov',
			'dataFiles.definitionUnavailable' => 'Zdroj súboru neposkytol definíciu — jeho rozšírenie sa možno práve reštartuje alebo je nesprávne nakonfigurované. Skúste to o chvíľu znova.',
			'updates.updateAvailable' => 'Aktualizácia dostupná',
			'updates.newVersionAvailable' => ({required Object version}) => 'Je dostupná nová verzia (${version}).',
			'updates.getIt' => 'Stiahnuť',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Aktualizácia pripravená',
			'updates.restartToApply' => 'Aktualizácia bola stiahnutá. Reštartujte a uplatní sa.',
			'updates.appliesNextLaunch' => 'Aktualizácia bola stiahnutá. Uplatní sa pri ďalšom otvorení aplikácie.',
			'updates.restartNow' => 'Reštartovať teraz',
			'updates.reloadToUpdate' => 'Je dostupná novšia verzia tejto stránky. Načítajte ju znova.',
			'updates.reloadNow' => 'Znova načítať',
			'updates.checkForUpdates' => 'Skontrolovať aktualizácie',
			'updates.checkingForUpdates' => 'Kontrola aktualizácií…',
			'updates.upToDate' => 'Aktuálne',
			'updates.automaticChecks' => 'Kontrolovať automaticky',
			'updates.automaticChecksDescription' => 'Hľadať nové verzie na pozadí, od ďalšieho spustenia aplikácie',
			'extensionService.runtimeNotReady' => 'Prostredie rozšírení nie je pripravené.',
			'extensionService.testFailed' => ({required Object error}) => 'Test zlyhal: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Pripojený ako ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Neplatná konfigurácia poľa',
			'extensionService.invalidValue' => 'Neplatná hodnota',
			'extensionService.validationError' => ({required Object error}) => 'Chyba overenia: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Akcia zlyhala: ${error}',
			'extensionService.commandFailed' => 'Príkaz sa nepodarilo spustiť',
			'extensionService.reportUnavailable' => 'Hlásenia sa momentálne nedajú odoslať',
			'extensionService.stashUnavailable' => 'Ham2K úschovňa súborov je momentálne nedostupná',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} strávilo príliš veľa času v časovačoch. Sú zastavené, kým sa rozšírenia nereštartujú.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Časovače ${name} opakovane zlyhávali. Sú zastavené, kým sa rozšírenia nereštartujú.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} uviazlo v časovači. Jeho časovače sú zastavené, kým sa rozšírenia nereštartujú.',
			'operationLocationScreen.title' => 'Poloha prevádzky',
			'operationLocationScreen.selectedLocation' => 'Vybraná lokalita',
			'operationLocationScreen.gridSquare' => 'Lokátor',
			'operationLocationScreen.gridInvalid' => 'Potrebuje 4, 6, 8 alebo 10 znakov, napr. FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Odporúčané lokality',
			'operationLocationScreen.deviceGps' => 'GPS zariadenia',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS z ${device}',
			'operationLocationScreen.locating' => 'Lokalizácia…',
			'operationLocationScreen.gpsUnavailable' => 'Poloha nie je dostupná',
			'operationLocationScreen.permissionDenied' => 'Prístup k polohe bol zamietnutý',
			'operationLocationScreen.permissionBlocked' => 'Prístup k polohe je zablokovaný',
			'operationLocationScreen.moreDetails' => 'Ďalšie podrobnosti',
			'operationLocationScreen.stateOrProvince' => 'Štát alebo provincia (nepovinné)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Ovládanie aktivity nie je dostupné',
			'operationLocationScreen.controlsUnavailableReason' => 'Tieto referencie sa dajú stále použiť; len ich aktivity neboli dostupné.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Skúsiť znova',
			'operationLocationScreen.county' => 'Kraj (nepovinné)',
			'versionLabel.version' => ({required Object version}) => 'Verzia ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Oprava ${patch}',
			'versionLabel.build' => ({required Object build}) => 'zostava ${build}',
			'notices.emptyHistory' => 'Zatiaľ žiadne oznámenia',
			'notices.webStorageInMemory' => 'Tento prehliadač nedokázal poskytnúť trvalé úložisko — denník je iba v pamäti a po zatvorení tejto karty sa STRATÍ. Použite aktuálny Chrome, Firefox, Safari alebo Edge.',
			'notices.webStorageUnreliable' => 'Tento prehliadač používa náhradné úložisko, ktoré nie je bezpečné pri viacerých kartách — nechajte otvorenú iba jednu kartu a nechajte zapnutú synchronizáciu.',
			'notices.logFromNewerBuildTitle' => 'Tento denník potrebuje novšiu verziu',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Váš denník zapísala novšia verzia HaLo (verzia úložiska ${storage}; táto rozumie ${understood}), preto sa nedá otvoriť a nové spojenia sa neuložia. Znova nainštalujte novšiu verziu — alebo, ak ste chceli spustiť túto zostavu, nasmerujte ju na iný priečinok s údajmi. Denník je v ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Váš denník zapísala novšia verzia HaLo (verzia úložiska ${storage}; táto rozumie ${understood}), preto sa nedá otvoriť a nové spojenia sa neuložia. Otvorte tento denník radšej touto novšou verziou.',
			'notices.preferencesRestoredTitle' => 'Nastavenia obnovené zo zálohy',
			'notices.preferencesRestored' => 'Súbor nastavení sa nepodarilo prečítať, preto HaLo obnovil jeho poslednú dobrú kópiu. Čokoľvek ste zmenili v predchádzajúcej relácii, možno bude treba nastaviť znova. Nečitateľný súbor je uložený vedľa neho pod názvom shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Nastavenia obnovené na predvolené',
			'notices.preferencesReset' => 'Súbor nastavení sa nepodarilo prečítať a nebola k dispozícii žiadna záloha, preto HaLo začal s predvolenými hodnotami. Nečitateľný súbor je uložený v priečinku s údajmi aplikácie pod názvom shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} sa nepripojila automaticky',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo prestal odpovedať, keď sa naposledy začal pripájať k ${name}, preto ju tentoraz nechal tak, aby to neriskoval znova. Skontrolujte, či je rádiostanica zapnutá a kábel pripojený, potom pre ňu stlačte Pripojiť v Nastaveniach.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonymný účet (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (čaká na potvrdenie)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (čaká na potvrdenie - #${id})',
			'deepLink.needsAnOperation' => 'Najprv začnite prevádzku a potom toto spojenie pošlite znova',
			'deepLink.waitingInOperation' => 'Toto spojenie čaká v prevádzke za touto obrazovkou',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Toto zariadenie nemá žiadnu aktivitu pre ${refs}, preto boli tieto referencie vynechané',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Vaše aktivity neboli dostupné, preto bolo ${refs} vynechané — skúste tento odkaz znova',
			'confirmDevice.title' => 'Potvrdiť zariadenie',
			'confirmDevice.codePrompt' => 'Zadajte kód zobrazený na zariadení, ktoré sa chce pripojiť k tomuto účtu.',
			'confirmDevice.code' => 'Kód',
			'confirmDevice.lookUp' => 'Vyhľadať',
			'confirmDevice.codeNotFound' => 'Tomuto kódu nezodpovedá žiadna žiadosť. Kódy vypršia po 10 minútach — požiadajte druhé zariadenie o nový.',
			'confirmDevice.linkExpired' => 'Platnosť tohto odkazu vypršala. Požiadajte druhé zariadenie, aby zobrazilo nový QR kód.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Prepojiť ${device} s týmto účtom?',
			'confirmDevice.unnamedDevice' => 'nepomenované zariadenie',
			'confirmDevice.grantWarning' => 'Bude môcť čítať a meniť každú prevádzku a QSO v tomto účte.',
			'confirmDevice.needsSyncTitle' => 'Toto zariadenie sa ešte nesynchronizuje',
			'confirmDevice.needsSyncText' => 'Zapnite synchronizáciu Ham2K Log Filer a prepojte toto zariadenie s účtom, až potom môže pridať ďalšie.',
			'confirmDevice.malformedRequest' => 'Synchronizačný server poslal žiadosť, ktorú táto aplikácia nedokázala prečítať. Požiadajte druhé zariadenie, aby to skúsilo znova.',
			'confirmDevice.linkIt' => 'Prepojiť zariadenie',
			'switchAccounts.noAccountDetails' => 'Zatiaľ žiadne podrobnosti o účte',
			'switchAccounts.currentAccount' => 'Aktuálny účet',
			'switchAccounts.otherAccounts' => 'Iné účty',
			'switchAccounts.linkToAnother' => 'Prepojiť s iným účtom',
			'switchAccounts.linkWithSibling' => 'Prepojiť s inou aplikáciou Ham2K',
			'switchAccounts.linkWithPolo' => 'Prepojiť s účtom zo staršej verzie',
			'switchAccounts.linkWithSiblingDescription' => 'Máte nainštalovanú inú aplikáciu Ham2K. Prepojte sa s účtom, ktorý sa používa tam.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Schváľte žiadosť v ${app} a potom sa vráťte sem.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Znova otvoriť ${app}',
			'switchAccounts.siblingNoGrant' => 'Nefungovalo to? Otvorte ju znova alebo sa vráťte a prepojte sa inak.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app} sa nepodarilo otvoriť.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Platnosť odkazu vypršala a nový je pripravený — znova otvorte ${app}.',
			'switchAccounts.tryAgain' => 'Skúsiť znova',
			'switchAccounts.linkWithQr' => 'Prepojiť pomocou QR kódu',
			'switchAccounts.linkWithQrDescription' => 'Naskenujte ho zo zariadenia, ktoré už účet používa',
			'switchAccounts.linkWithEmail' => 'Prepojiť pomocou e-mailovej adresy',
			'switchAccounts.linkWithEmailDescription' => 'Potvrďte kódom alebo odkazom v e-maile',
			'switchAccounts.enterEmailPrompt' => 'Zadajte e-mailovú adresu účtu, ktorý má toto zariadenie používať.',
			'switchAccounts.emailAddress' => 'E-mailová adresa',
			'switchAccounts.linkAccount' => 'Prepojiť účet',
			'switchAccounts.copiedCode' => 'Kód skopírovaný do schránky',
			'switchAccounts.copyCode' => 'Kopírovať kód',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Otvorte aplikáciu Ham2K na zariadení, ktoré je už prepojené s ${email}, a zadajte tento kód na schválenie žiadosti:',
			'switchAccounts.waitingForConfirmation' => 'Čaká sa na potvrdenie…',
			'switchAccounts.sendEmailInstead' => 'Namiesto toho poslať potvrdzovací e-mail',
			'switchAccounts.emailSent' => ({required Object email}) => 'Na ${email} bol odoslaný e-mail. Otvorte ho a potvrďte žiadosť o prepojenie tohto zariadenia.',
			'switchAccounts.resendEmail' => 'Znova odoslať e-mail',
			'switchAccounts.qrPrompt' => 'Naskenujte tento QR kód zo zariadenia, ktoré je už prepojené s požadovaným účtom — napríklad pomocou Ham2K Portable Logger vo vašom telefóne.',
			'switchAccounts.serverUnreachable' => 'Synchronizačný server je nedostupný. Skúste to neskôr.',
			'switchAccounts.emailRequired' => 'Zadajte e-mailovú adresu na prepojenie.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Pre ${email} sa nenašiel žiadny účet.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Synchronizačný server žiadosť odmietol: ${error}',
			'switchAccounts.noLinkCode' => 'Synchronizačný server nevrátil kód na prepojenie. Skúste to neskôr.',
			'switchAccounts.noConfirmationCode' => 'Synchronizačný server neposlal potvrdzovací kód. Skúste to neskôr.',
			'switchAccounts.switchNotAccepted' => 'Tento účet prepnutie neprijal. Skúste ho namiesto toho prepojiť pomocou e-mailovej adresy.',
			'switchAccounts.requestFailed' => 'Pri komunikácii so synchronizačným serverom sa niečo pokazilo. Skúste to neskôr.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} QSO', other: '${count} QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} prevádzka', other: '${count} prevádzok', ), 
			'adifImport.title' => 'Importovať QSO z ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Číta sa ${filename}…',
			'adifImport.dropHint' => 'Pustite sem súbor ADIF a importuje sa',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} QSO v tomto súbore', other: '${formatted} QSO v tomto súbore', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} už je vo vašom denníku', other: '${formatted} už je vo vašom denníku', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} sa importuje', other: '${formatted} sa importuje', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} nové spojenie', other: '${formatted} nových spojení', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} sa zlúči s existujúcim spojením', other: '${formatted} sa zlúči s existujúcimi spojeniami', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} sa nedá importovať (bez volacieho znaku)', other: '${formatted} sa nedá importovať (bez volacieho znaku)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} si vyžaduje bližšiu kontrolu', other: '${formatted} si vyžaduje bližšiu kontrolu', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Referencie sa nepodarilo obnoviť pre ${count} spojenie', other: 'Referencie sa nepodarilo obnoviť pre ${formatted} spojení', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Referencie ${programs} môžu byť neúplné pre ${count} spojenie', other: 'Referencie ${programs} môžu byť neúplné pre ${formatted} spojení', ), 
			'adifImport.stackingTypesUnknown' => 'Zlúčené spojenia môžu prísť o referenciu — aktivity nedokázali určiť, ktoré typy sa dajú kombinovať. Ak tomu chcete predísť, zrušte to a skúste znova.',
			'adifImport.nothingToImport' => 'Z tohto súboru sa nedá nič importovať',
			'adifImport.confirm' => 'Importovať',
			'adifImport.importing' => ({required Object filename}) => 'Importuje sa ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: 'Importované ${count} spojenie z ${filename}', other: 'Importovaných ${formatted} spojení z ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename} sa nepodarilo importovať: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} nevyzerá ako súbor ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Upozornenie: tento ADIF obsahuje QSO od ${calls}, ale ak budete pokračovať, importujú sa ako ${station}.',
			'adifImport.stationCallJoin' => ' a ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('sk'))(count, one: '${count} nemá dátum a nedá sa importovať', other: '${formatted} nemá dátum a nedá sa importovať', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Tento súbor zaznamenáva aktiváciu ${refs}.',
			'adifImport.addActivation' => 'Pridať ju do tejto prevádzky',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Uplatniť sa dalo iba ${written} z ${planned} — denník sa zmenil, kým ste sa rozhodovali.',
			'adifImport.busy' => 'Import už prebieha. Pred spustením ďalšieho počkajte, kým sa dokončí.',
			'adifImport.oneFileOnly' => 'Pustite naraz iba jeden súbor ADIF — poradie importu súborov rozhoduje, ktoré údaje majú prednosť.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} má viac ako ${limit} QSO, čo je maximum, ktoré prevádzka dokáže naraz importovať.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: pripojené',
			'offline.noRoute' => 'Žiadne sieťové pripojenie.',
			'offline.unreachable' => 'Sieť funguje, ale žiadny server neodpovedá — často to znamená prihlasovaciu stránku čakajúcu v prehliadači.',
			'offline.reachable' => 'Všetky služby odpovedajú podľa očakávania.',
			'offline.whatStops' => 'Vyhľadávanie, spoty a dátové súbory sú pozastavené. Logovanie a synchronizácia v blízkosti nie.',
			'offline.servicesTitle' => 'Služby',
			'offline.noServices' => 'Zatiaľ sa neozvala žiadna služba.',
			'offline.lastSuccess' => ({required Object when}) => 'Naposledy odpovedala pred ${when}',
			'offline.neverSucceeded' => 'Zatiaľ neodpovedala',
			'offline.nextAttempt' => ({required Object when}) => 'Ďalší pokus o ${when}',
			'offline.nextAttemptNow' => 'Ďalší pokus na rade',
			'offline.retry' => 'Skúsiť teraz',
			'offline.retrying' => 'Skúša sa…',
			'offline.retryReached' => 'Opäť online.',
			'offline.retryUnreachable' => 'Stále bez odpovede.',
			'offline.retryNotAttempted' => 'Momentálne nie je čo odoslať.',
			'offline.retryThrottled' => 'Práve sa to skúšalo — chvíľu počkajte.',
			'offline.retryDisabled' => 'Synchronizácia je vypnutá, takže nie je čím otestovať.',
			'offline.syncService' => 'Synchronizácia Ham2K LoFi',
			'offline.retryInFlight' => 'Už sa to skúša — vydržte.',
			'exportSettings.defaultsDescription' => 'Základné nastavenia pre všetky exporty so samostatnými šablónami názvu súboru a titulu pre referenčné aktivity a ostatné aktivity. Každý typ exportu môže mať vlastné predvolené alebo vlastné nastavenia.',
			'exportSettings.referenceActivities' => 'Referenčné aktivity',
			'exportSettings.otherActivities' => 'Ostatné aktivity',
			'exportSettings.adifFields' => 'Polia ADIF',
			'exportSettings.loadFailed' => 'Nastavenia exportu sa nepodarilo načítať.',
			'exportSettings.retry' => 'Skúsiť znova',
			'exportSettings.compactFileNamesDescriptionOn' => 'Krátke názvy súborov, napríklad N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Popisné názvy súborov, napríklad 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Do súborov ADIF sa zahŕňajú mená, adresy, e-maily, poznámky a presné polohy.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Vynechávajú sa mená, adresy, e-maily a poznámky; polohy sú obmedzené na 6-miestne lokátory.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Zahŕňajú sa informácie zo služieb vyhľadávania volacích znakov.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Vynechávajú sa informácie zo služieb vyhľadávania volacích znakov; ručne zadané hodnoty zostávajú.',
			'exportSettings.customTemplatesDescriptionOn' => 'Vaše vlastné šablóny sú aktívne a dajú sa upraviť nižšie.',
			'exportSettings.customTemplatesDescriptionOff' => 'Aktívne sú predvolené šablóny. Vaše vlastné šablóny zostávajú uložené na neskôr.',
			'exportSettings.type' => 'Typ exportu',
			'exportSettings.defaults' => 'Predvolené',
			'exportSettings.includeLookupData' => 'Zahrnúť údaje z vyhľadávania',
			'exportSettings.customTemplates' => 'Vlastné šablóny',
			'exportSettings.filenameTemplate' => 'Šablóna názvu súboru',
			'exportSettings.compactFilenameTemplate' => 'Šablóna krátkeho názvu súboru',
			'exportSettings.titleTemplate' => 'Šablóna titulu',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO poznámky',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO komentáre',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL správa',
			'exportSettings.shared' => 'Nastavenia platia pre každé rozšírenie, ktoré používa tento typ exportu.',
			'exportSettings.defaultTemplates' => 'Ak chcete upraviť šablóny tohto typu, zapnite Vlastné šablóny.',
			'templateEditor.previewLabel' => 'Náhľad:',
			'templateEditor.reset' => 'Obnoviť',
			'templateEditor.docs' => 'Dokumentácia šablón',
			'templateEditor.preview' => 'Ukážkový náhľad',
			'templateEditor.reference' => 'Referencia šablón',
			'templateEditor.attributes' => 'Dostupné atribúty',
			'templateEditor.filters' => 'Filtre',
			'templateEditor.flowControl' => 'Riadenie toku',
			'templateEditor.unavailable' => 'Náhľad nie je dostupný, kým nie sú rozšírenia pripravené.',
			'templateEditor.empty' => '(prázdny výstup)',
			_ => null,
		};
	}
}
