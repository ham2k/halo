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
class TranslationsCs extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsCs({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.cs,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <cs>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsCs _root = this; // ignore: unused_field

	@override 
	TranslationsCs $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsCs(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$cs common = _Translations$common$cs._(_root);
	@override late final _Translations$onboarding$cs onboarding = _Translations$onboarding$cs._(_root);
	@override late final _Translations$startScreen$cs startScreen = _Translations$startScreen$cs._(_root);
	@override late final _Translations$testerOverlay$cs testerOverlay = _Translations$testerOverlay$cs._(_root);
	@override late final _Translations$extensionsPanel$cs extensionsPanel = _Translations$extensionsPanel$cs._(_root);
	@override late final _Translations$home$cs home = _Translations$home$cs._(_root);
	@override late final _Translations$chase$cs chase = _Translations$chase$cs._(_root);
	@override late final _Translations$dialogs$cs dialogs = _Translations$dialogs$cs._(_root);
	@override late final _Translations$operation$cs operation = _Translations$operation$cs._(_root);
	@override late final _Translations$map$cs map = _Translations$map$cs._(_root);
	@override late final _Translations$mapsView$cs mapsView = _Translations$mapsView$cs._(_root);
	@override late final _Translations$activitiesView$cs activitiesView = _Translations$activitiesView$cs._(_root);
	@override late final _Translations$loggingControls$cs loggingControls = _Translations$loggingControls$cs._(_root);
	@override late final _Translations$formChrome$cs formChrome = _Translations$formChrome$cs._(_root);
	@override late final _Translations$qsoEditForm$cs qsoEditForm = _Translations$qsoEditForm$cs._(_root);
	@override late final _Translations$qsoList$cs qsoList = _Translations$qsoList$cs._(_root);
	@override late final _Translations$loggingPanel$cs loggingPanel = _Translations$loggingPanel$cs._(_root);
	@override late final _Translations$callInfo$cs callInfo = _Translations$callInfo$cs._(_root);
	@override late final _Translations$settings$cs settings = _Translations$settings$cs._(_root);
	@override late final _Translations$commands$cs commands = _Translations$commands$cs._(_root);
	@override late final _Translations$commandDialog$cs commandDialog = _Translations$commandDialog$cs._(_root);
	@override late final _Translations$keyboardShortcuts$cs keyboardShortcuts = _Translations$keyboardShortcuts$cs._(_root);
	@override late final _Translations$expiredBuild$cs expiredBuild = _Translations$expiredBuild$cs._(_root);
	@override late final _Translations$staleness$cs staleness = _Translations$staleness$cs._(_root);
	@override late final _Translations$spotting$cs spotting = _Translations$spotting$cs._(_root);
	@override late final _Translations$dataFiles$cs dataFiles = _Translations$dataFiles$cs._(_root);
	@override late final _Translations$updates$cs updates = _Translations$updates$cs._(_root);
	@override late final _Translations$extensionService$cs extensionService = _Translations$extensionService$cs._(_root);
	@override late final _Translations$operationLocationScreen$cs operationLocationScreen = _Translations$operationLocationScreen$cs._(_root);
	@override late final _Translations$versionLabel$cs versionLabel = _Translations$versionLabel$cs._(_root);
	@override late final _Translations$notices$cs notices = _Translations$notices$cs._(_root);
	@override late final _Translations$syncAccount$cs syncAccount = _Translations$syncAccount$cs._(_root);
	@override late final _Translations$deepLink$cs deepLink = _Translations$deepLink$cs._(_root);
	@override late final _Translations$confirmDevice$cs confirmDevice = _Translations$confirmDevice$cs._(_root);
	@override late final _Translations$switchAccounts$cs switchAccounts = _Translations$switchAccounts$cs._(_root);
	@override late final _Translations$qsonImport$cs qsonImport = _Translations$qsonImport$cs._(_root);
	@override late final _Translations$adifImport$cs adifImport = _Translations$adifImport$cs._(_root);
	@override late final _Translations$offline$cs offline = _Translations$offline$cs._(_root);
	@override late final _Translations$exportSettings$cs exportSettings = _Translations$exportSettings$cs._(_root);
	@override late final _Translations$templateEditor$cs templateEditor = _Translations$templateEditor$cs._(_root);
}

// Path: common
class _Translations$common$cs extends Translations$common$en {
	_Translations$common$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get save => 'Uložit';
	@override String get ok => 'OK';
	@override String get cancel => 'Zrušit';
	@override String get delete => 'Smazat';
	@override String get create => 'Vytvořit';
	@override String get error => 'Chyba';
	@override String get close => 'Zavřít';
	@override String get done => 'Hotovo';
	@override String get callsign => 'Volací značka';
	@override String get clear => 'Vymazat';
	@override String get dismiss => 'Zavřít';
	@override String get copyDetails => 'Kopírovat podrobnosti';
	@override String get expand => 'Rozbalit';
	@override String get collapse => 'Sbalit';
}

// Path: onboarding
class _Translations$onboarding$cs extends Translations$onboarding$en {
	_Translations$onboarding$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Vítá vás Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Vítá vás Ham2K Power Logger!';
	@override String get welcomeBody => 'Máme několik otázek, které nám pomohou aplikaci přizpůsobit vašim potřebám.';
	@override String get skip => 'Přeskočit';
	@override String get kContinue => 'Pokračovat';
	@override String get back => 'Zpět';
	@override String get next => 'Další';
	@override String get done => 'Hotovo';
	@override String get callsignTitle => 'Jaká je vaše volací značka?';
	@override String get callsignBody => 'Aby pro vás byla tato aplikace užitečná, potřebujete radioamatérskou licenci';
	@override String get callsignLabel => 'Volací značka operátora';
	@override String get alreadyHaveAccount => 'Už máte účet?';
	@override String get foundSiblingTitle => 'Propojit existující účet?';
	@override String foundSiblingBody({required Object app}) => 'Na tomto zařízení jsme našli ${app}. Propojte tuto aplikaci se stejným účtem a vaše volací značka i logy se přenesou.';
	@override String get foundPoloBody => 'Na tomto zařízení jsme našli starší verzi Ham2K Portable Logger. Propojte tuto aplikaci se stejným účtem a vaše volací značka i logy se přenesou.';
	@override String get foundSiblingsBody => 'Na tomto zařízení jsme našli další aplikace Ham2K. Propojte tuto aplikaci s účtem některé z nich a vaše volací značka i logy se přenesou.';
	@override String linkWithApp({required Object app}) => 'Propojit s ${app}';
	@override String get linkWithPolo => 'Propojit s účtem ve starší verzi';
	@override String get setUpFresh => 'Začít načisto';
	@override String get activitiesTitle => 'Oblíbené aktivity';
	@override String get activitiesBody => 'Zajímá vás některý z těchto populárních aktivačních programů?';
	@override String get activitiesFooter => '(Další možnosti najdete v Nastavení)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'Synchronizace v cloudu';
	@override String get syncBody => 'Ham2K Log Filer uchovává zálohu vašich logů v cloudu a synchronizuje je mezi všemi zařízeními, kde používáte aplikace Ham2K.';
	@override String get syncPricing => 'Je to zdarma! S placeným předplatným to ale bude rychlejší.';
	@override String get syncLabel => 'Zapnout synchronizaci v cloudu';
	@override String get syncOffWarning => 'VAROVÁNÍ: zvyšuje to riziko ztráty dat aktivit, například když se zařízení porouchá nebo ho ztratíte.';
	@override String get notNow => 'Teď ne';
	@override String get consentTitle => 'Data a soukromí';
	@override String get consentUsageBody => 'Abychom mohli aplikaci vylepšovat, rádi bychom sbírali údaje o výkonu, pádech a používání aplikace.';
	@override String get consentUsageLabel => 'Sdílet údaje o používání aplikace';
	@override String get consentOperationBody => 'Některé funkce mohou sdílet údaje o vašich aktivitách s ostatními uživateli. Kdykoli to můžete vypnout.';
	@override String get consentOperationLabel => 'Sdílet údaje o aktivitách';
	@override String get finishingSetup => 'Dokončování nastavení — stahování referenčních dat…';
}

// Path: startScreen
class _Translations$startScreen$cs extends Translations$startScreen$en {
	_Translations$startScreen$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get credits => 'od KI2D a přátel';
}

// Path: testerOverlay
class _Translations$testerOverlay$cs extends Translations$testerOverlay$en {
	_Translations$testerOverlay$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get tape => 'POZOR: VE VÝSTAVBĚ';
	@override String get warningTitle => 'Tato aplikace je rozpracovaná';
	@override String get warningBody => 'Většina funkcí má nerovný povrch a všude hrozí zakopnutí. Pravidelně kontrolujte aktualizace.';
	@override String whatsNew({required Object build}) => 'Co je nového v sestavení ${build}';
	@override String get thanks => 'Děkujeme, že riskujete svůj log, abyste nám pomohli tuto aplikaci vylepšit!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$cs extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Aktivity';
	@override String get categoryAward => 'Diplomy';
	@override String get categoryContest => 'Závody';
	@override String get categoryLookup => 'Vyhledávání značek';
	@override String get categorySpots => 'Zdroje spotů';
	@override String get categoryDashboard => 'Panely přehledu';
	@override String get categoryOther => 'Další rozšíření';
	@override String get searchHint => 'Hledat rozšíření';
	@override String get applying => 'Aktivace změn rozšíření, chvíli to potrvá…';
	@override String get noMatches => 'Žádné rozšíření neodpovídá hledání';
	@override String get installFromFile => 'Instalovat ze souboru…';
	@override String installVersion({required Object version}) => 'Verze ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'Snímek obrazovky ${n} z ${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => 'Předchozí snímek';
	@override String get nextScreenshot => 'Další snímek';
	@override String get screenshotUnavailable => 'Snímek není k dispozici';
	@override String get canReach => 'Toto rozšíření se může spojit s';
	@override String canHoldConnection({required Object host}) => '${host}, přes trvalé spojení';
	@override String get canHoldLocalConnection => 'Zařízeními ve vaší místní síti, přes trvalé spojení';
	@override String get canUseLocation => 'Vaší polohou';
	@override String get canReadRadio => 'Vaším rádiem, pro čtení frekvence a módu';
	@override String get canControlRadio => 'Vaším rádiem, pro jeho ovládání a vysílání — ladění, výkon, CW, hlasové paměti a PTT';
	@override String get canCommandRadioRaw => 'Vaším rádiem, pro odesílání libovolného příkazu v jeho vlastním protokolu — včetně těch, které vysílají nebo mění jeho nastavení';
	@override String get canReadCluster => 'DX clusterem, přihlášené jako vy, pro čtení toho, co posílá';
	@override String get canSpotCluster => 'DX clusterem, přihlášené jako vy, pro odesílání spotů vaším jménem';
	@override String get canCommandCluster => 'DX clusterem, přihlášené jako vy, pro odesílání libovolného příkazu vaším jménem';
	@override String get canSetUserAgent => 'Představovat se serverům vlastním jménem';
	@override String get canChangeSettings => 'Vaším nastavením, aby ho měnilo svými příkazy: libovolné nastavení, režim vývojáře a experimenty';
	@override String get noCapabilities => 'Nepožaduje nic mimo aplikaci.';
	@override String get sandboxNote => 'Rozšíření běží v izolovaném prostředí: bez přístupu k vašim souborům a bez sítě nad rámec zde uvedeného.';
	@override String get installAction => 'Instalovat';
	@override String get updateAction => 'Aktualizovat';
	@override String get installFailed => 'Toto rozšíření se nepodařilo nainstalovat';
	@override String get installedBadge => 'Nainstalováno';
	@override String get uninstallAction => 'Odebrat';
	@override String uninstallTitle({required Object name}) => 'Odebrat ${name}?';
	@override String get uninstallBody => 'Toto rozšíření a jeho nastavení budou odebrány. Vaše logy zůstanou nedotčené.';
	@override String installedMessage({required Object name}) => 'Nainstalováno ${name}';
	@override String get installDownloading => 'Stahování…';
	@override String get installWaiting => 'Čeká na instalaci…';
	@override String get installInstalling => 'Instalace…';
	@override String get installAwaitingApproval => 'Čeká na vaše schválení…';
	@override String installAlreadyRunning({required Object name}) => '${name} se už instaluje.';
	@override String updatedTo({required Object version}) => 'Aktualizováno na ${version}';
	@override String installIncomplete({required Object name}) => 'Instalace ${name} nebyla dokončena. Možná bude nutné ji zopakovat.';
	@override String uninstallFailed({required Object name}) => '${name} se nepodařilo odebrat';
	@override String installedFrom({required Object source}) => 'Staženo z ${source}';
	@override String get dropHint => 'Přetáhněte sem rozšíření .h2kext a nainstalujte ho';
	@override String get dropOneOnly => 'Přetahujte vždy jen jedno rozšíření.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} vrátil pro toto rozšíření ${status}.';
	@override String get downloadTooLarge => 'Stažený soubor je příliš velký na to, aby byl rozšířením.';
	@override String get downloadNotSecure => 'Stahování bylo přesměrováno na nezabezpečené místo.';
	@override String get catalogSection => 'Katalog';
	@override String get catalogLoading => 'Načítání katalogu…';
	@override String get catalogUnreachable => 'Katalog je nedostupný';
	@override String get builtIn => 'Vestavěné';
	@override String get updateAvailableBadge => 'Aktualizace k dispozici';
	@override String get updatesAvailableTitle => 'Aktualizace rozšíření';
	@override String updateAvailableFor({required Object name}) => 'Pro ${name} je k dispozici aktualizace.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} a ${count} dalších je třeba aktualizovat.';
	@override String updatesAvailableFor({required Object names}) => '${names} je třeba aktualizovat.';
	@override String get pendingUpdatesSection => 'Čekající aktualizace';
	@override String get updateAllAction => 'Aktualizovat vše';
	@override String get updatesUnderWay => 'Tyto aktualizace už probíhají.';
	@override String get updatesNothingLeft => 'Vaše rozšíření jsou aktuální.';
	@override String get updatesNoticeAction => 'Více informací';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Aktualizovat ${count} rozšíření?',
		other: 'Aktualizovat ${count} rozšíření?',
	);
	@override String get upgradeDoneTitle => 'Vaše rozšíření jsou připravena';
	@override String get upgradeDoneBody => 'Nyní pocházejí z katalogu rozšíření Ham2K, takže je lze aktualizovat bez čekání na novou verzi aplikace.';
	@override String upgradeDoneUnserved({required Object names}) => 'Nepřevedeno: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Nespustila se: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Jsou stále nainstalována a označena v Nastavení › Rozšíření — když je tam aktualizujete, vrátí se.';
	@override String get upgradeDoneUnservedHint => 'Katalog za ně nemá přímou náhradu, najděte v něm rozšíření, která pokrývají to, co jste používali.';
	@override String get retiredQp => 'QSO Party';
	@override String get retiredStateparks => 'Akce State Parks';
	@override String upgradeDoneMissing({required Object count}) => '${count} z vašich rozšíření ještě nedorazilo. Stáhnou se, až bude katalog rozšíření příště dostupný.';
	@override String get runtimeDeadBody => 'Vaše rozšíření se nespustila. Restart aplikace by je měl vrátit.';
	@override String get refusedTitle => 'Některá rozšíření se nespustila';
	@override String get upgradeBusyTitle => 'Nastavení stále probíhá';
	@override String get upgradeRuntimeDeadTitle => 'Vaše rozšíření neběží';
	@override String get restoreTitle => 'Některá vaše rozšíření chybí';
	@override String get restoreBody => 'Tato rozšíření, která jste nainstalovali, nejsou na tomto zařízení. Můžeme je znovu stáhnout z katalogu rozšíření Ham2K:';
	@override String get restoreFromFile => 'Nainstalováno ze souboru. Nainstalujte je znovu z jejich souborů, nebo je zapomeňte:';
	@override String get restoreOtherCatalog => 'Nainstalováno z jiného katalogu rozšíření, proto tu nejsou k dispozici:';
	@override String get restoreForget => 'Zapomenout';
	@override String get restoreInstall => 'Instalovat';
	@override String get restoreLater => 'Později';
	@override String get restoreInstalling => 'Instalace vašich rozšíření…';
	@override String get restoreDoneTitle => 'Vaše rozšíření jsou zpět';
	@override String restoreDoneBody({required Object names}) => 'Znovu nainstalováno: ${names}.';
	@override String get restorePartialTitle => 'Některá rozšíření se nepodařilo nainstalovat';
	@override String restoreFailed({required Object names}) => 'Nepodařilo se nainstalovat: ${names}. Nabídneme je znovu při příštím otevření aplikace.';
	@override String get restoreBusyBody => 'Aplikace stále nastavuje vaše rozšíření. Nabídneme je znovu při příštím otevření aplikace.';
	@override String get restoreRuntimeDeadBody => 'Znovu jsme je nainstalovali, ale vaše rozšíření se nespustila. Restart aplikace by je měl vrátit.';
	@override String revokedTitle({required Object name}) => 'Rozšíření ${name} bylo staženo';
	@override String get revokedBody => 'Katalog tuto verzi stáhl, proto byla vypnuta.';
	@override String forceDisabledTitle({required Object name}) => 'Rozšíření ${name} bylo vypnuto';
	@override String get forceDisabledBody => 'Ham2K toto rozšíření prozatím vypnul.';
	@override String replacedTitle({required Object name}) => 'Rozšíření ${name} bylo nahrazeno';
	@override String replacedBody({required Object replacement}) => 'Nahrazuje ho ${replacement}. Přepnout můžete v Rozšířeních.';
	@override String replacedBy({required Object name}) => 'Nahrazeno rozšířením ${name}';
	@override String replacedByInstalled({required Object name}) => 'Nahrazeno rozšířením ${name}, které už máte';
	@override String get replaceAction => 'Nahradit';
	@override String replaceInstalledBody({required Object replacement}) => 'Jeho nastavení se přenese do ${replacement}, které už máte. Vaše logy zůstanou nedotčené.';
	@override String get downloadHashMismatch => 'Stažený soubor není rozšíření, které katalog popisuje.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Katalog nemá verzi ${version} rozšíření ${key}.';
	@override String get catalogLinkUnknown => 'Tento odkaz z katalogu neurčuje verzi rozšíření.';
	@override String catalogNoRelease({required Object key}) => 'Katalog nemá žádné vydání ${key} v této větvi.';
	@override String get installFromLink => 'Instalovat z odkazu';
	@override String get unstableReleaseWarning => 'Toto je nestabilní vydání, které jeho autor zatím nepovažuje za hotové. Může se chovat chybně a bude dál dostávat nestabilní aktualizace.';
	@override String get bleedingReleaseWarning => 'Toto je experimentální vydání: rozpracovaná verze, která se může rozbít nebo přijít o nastavení. Bude dál dostávat experimentální aktualizace.';
	@override String get channelUnstable => 'Nestabilní';
	@override String get channelBleeding => 'Experimentální';
	@override String get followsUnstable => 'Dostává nestabilní a stabilní vydání';
	@override String get followsBleeding => 'Dostává experimentální, nestabilní a stabilní vydání';
	@override String get followStableAction => 'Sledovat jen stabilní vydání';
	@override String get revokedBadge => 'Staženo';
	@override String get forceDisabledBadge => 'Vypnuto Ham2K';
	@override String get refusedBadge => 'Nenačteno';
	@override String get downloadNotHttps => 'Stahování neprobíhá přes zabezpečené spojení.';
	@override String downloadUnreachable({required Object source}) => '${source} pro toto rozšíření není dostupný.';
	@override String get detailsAction => 'Podrobnosti';
	@override String get installedFromFile => 'Nainstalováno ze souboru';
	@override String get detailsWhatItDoes => 'Poskytuje podporu pro';
	@override String get installedPreloaded => 'Předinstalováno';
	@override String get hookAccount => 'Přihlášení k účtu';
	@override String get hookCallNotes => 'Poznámky ke značkám';
	@override String get hookDataFile => 'Offline data';
	@override String get hookExport => 'Export';
	@override String get hookLookup => 'Vyhledávání značek';
	@override String get hookScoring => 'Bodování';
	@override String get hookSpots => 'Spoty';
	@override String hookHunting({required Object program}) => 'Lovení ${program}';
	@override String hookActivating({required Object program}) => 'Aktivace ${program}';
	@override String get suggestedSection => 'Doporučené';
	@override String moreAvailableSection({required Object count}) => 'Další dostupná (${count})';
}

// Path: home
class _Translations$home$cs extends Translations$home$en {
	_Translations$home$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portable Logger';
	@override String get newOperation => 'Nová aktivita';
	@override String get stationCallsign => 'Volací značka stanice';
	@override String get titleOptional => 'Název (nepovinné)';
	@override String get emptyList => 'Zatím žádné aktivity. Vytvořte jednu a začněte logovat.';
	@override String get quickLookup => 'Rychlé vyhledání';
	@override late final _Translations$home$nav$cs nav = _Translations$home$nav$cs._(_root);
	@override late final _Translations$home$panels$cs panels = _Translations$home$panels$cs._(_root);
	@override String get toggleNav => 'Zobrazit nebo skrýt popisky navigace';
	@override late final _Translations$home$logs$cs logs = _Translations$home$logs$cs._(_root);
}

// Path: chase
class _Translations$chase$cs extends Translations$chase$en {
	_Translations$chase$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'loví';
	@override String goalsTwo({required Object first, required Object second}) => '${first} a ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} a další';
	@override late final _Translations$chase$station$cs station = _Translations$chase$station$cs._(_root);
	@override late final _Translations$chase$periodInline$cs periodInline = _Translations$chase$periodInline$cs._(_root);
	@override late final _Translations$chase$periodStats$cs periodStats = _Translations$chase$periodStats$cs._(_root);
	@override late final _Translations$chase$period$cs period = _Translations$chase$period$cs._(_root);
	@override late final _Translations$chase$goals$cs goals = _Translations$chase$goals$cs._(_root);
	@override late final _Translations$chase$panels$cs panels = _Translations$chase$panels$cs._(_root);
	@override late final _Translations$chase$claims$cs claims = _Translations$chase$claims$cs._(_root);
	@override late final _Translations$chase$notice$cs notice = _Translations$chase$notice$cs._(_root);
	@override late final _Translations$chase$alerts$cs alerts = _Translations$chase$alerts$cs._(_root);
	@override String get checklists => 'Postup lovení';
	@override late final _Translations$chase$imports$cs imports = _Translations$chase$imports$cs._(_root);
}

// Path: dialogs
class _Translations$dialogs$cs extends Translations$dialogs$en {
	_Translations$dialogs$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Podrobnosti aktivity';
	@override String get activities => 'Aktivity';
	@override String get stationCallsign => 'Volací značka stanice';
	@override String get advanced => 'Pokročilé';
	@override String get operatingPosition => 'Pracoviště (více stanic)';
	@override String get assistance => 'Asistence';
	@override String get assistanceDescription => 'Používat spotovací služby a další zdroje informací';
	@override String get selfSpotting => 'Self-spotting';
	@override String get selfSpottingDescription => 'Povolit funkce, které hlásí informace o vaší frekvenci';
	@override String disabledByRules({required Object rules}) => 'Vypnuto kvůli souladu s pravidly ${rules}';
	@override late final _Translations$dialogs$lookupDespiteAssistance$cs lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$cs._(_root);
	@override String get notes => 'Poznámky';
	@override String get deleteOperationTitle => 'Smazat aktivitu';
	@override String get purgeTestsTitle => 'Vyčistit testovací aktivity';
	@override String get purgeTestsBody => 'Tímto trvale smažete tyto testovací aktivity a jejich QSO. Nelze to vrátit zpět.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Navíc ${count} testovací spojení, které nepatří k žádné aktivitě.',
		other: 'Navíc ${count} testovacích spojení, která nepatří k žádné aktivitě.',
	);
	@override String get purgeTestsAction => 'Vyčistit';
	@override String get syncAllTitle => 'Nahradit log tohoto zařízení?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL zálohuje a vymaže z tohoto zařízení ${qsos} a pak znovu stáhne log účtu ze serveru. Záloha zůstane v databázi tohoto zařízení.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${n} QSO ještě nebylo synchronizováno — server ho nikdy nepřijal a NEVRÁTÍ se.',
		other: '${n} QSO ještě nebylo synchronizováno — server je nikdy nepřijal a NEVRÁTÍ se.',
	);
	@override String get syncAllAction => 'Vymazat a znovu synchronizovat';
	@override String get receivedPurgesTitle => 'Testovací aktivity odebrané jinde';
	@override String get receivedPurgesBody => 'Tyto aktivity byly smazány jako testovací na jiném zařízení. Odebrat je i zde? Tímto je trvale smažete i s jejich QSO a nelze to vrátit zpět.';
	@override String get receivedPurgesAction => 'Odebrat';
	@override late final _Translations$dialogs$callChange$cs callChange = _Translations$dialogs$callChange$cs._(_root);
}

// Path: operation
class _Translations$operation$cs extends Translations$operation$en {
	_Translations$operation$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Tato aktivita je smazaná. Chcete-li logovat nebo provádět změny, obnovte ji.';
	@override late final _Translations$operation$tabs$cs tabs = _Translations$operation$tabs$cs._(_root);
	@override late final _Translations$operation$positions$cs positions = _Translations$operation$positions$cs._(_root);
	@override String get stationCallsignNone => 'Bez volací značky stanice';
	@override String get titleNone => 'Bez názvu';
	@override String get deleteOperation => 'Smazat aktivitu';
	@override String get loggingControlsStale => 'Pole aktivačních programů mohou být zastaralá — obnovíte je znovuotevřením aktivity';
	@override String get locationNone => 'Nenastaveno';
	@override String get generalOperation => 'Obecná aktivita';
	@override String titleFor({required Object value}) => 'pro ${value}';
	@override String titleAt({required Object value}) => 'v ${value}';
	@override String segmentNow({required Object description}) => 'Nyní ${description}';
	@override String get testOperationSuffix => 'Testování';
	@override late final _Translations$operation$menu$cs menu = _Translations$operation$menu$cs._(_root);
	@override late final _Translations$operation$layout$cs layout = _Translations$operation$layout$cs._(_root);
	@override late final _Translations$operation$export$cs export = _Translations$operation$export$cs._(_root);
	@override late final _Translations$operation$spots$cs spots = _Translations$operation$spots$cs._(_root);
	@override late final _Translations$operation$import$cs import = _Translations$operation$import$cs._(_root);
}

// Path: map
class _Translations$map$cs extends Translations$map$en {
	_Translations$map$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$cs outlineIssue = _Translations$map$outlineIssue$cs._(_root);
	@override String get outlinesDisclaimer => 'Obrysy jsou pouze orientační. Ověřte si vše sami!';
	@override String outlinesCredit({required Object sources}) => 'Obrysy: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Hranice: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Zařízení: ${sources}';
	@override String get fullCredits => 'Úplné zdroje dat';
	@override String get fewerCredits => 'Méně zdrojů';
	@override String get emptyState => 'Zatím žádné polohy QSO.\nZde se zobrazí QSO s lokátorem, státem nebo zemí.';
	@override String get unavailable => 'Mapa teď není k dispozici.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plochá';
	@override String get globe => 'Glóbus';
	@override String get zoomIn => 'Přiblížit';
	@override String get zoomOut => 'Oddálit';
	@override String get resetNorth => 'Otočit severem nahoru';
	@override late final _Translations$map$postcard$cs postcard = _Translations$map$postcard$cs._(_root);
}

// Path: mapsView
class _Translations$mapsView$cs extends Translations$mapsView$en {
	_Translations$mapsView$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapy';
	@override String get searchHint => 'Hledat parky, vrcholy a další';
	@override String get activities => 'Aktivity';
	@override String get layers => 'Vrstvy';
	@override String get baseMap => 'Podkladová mapa';
	@override String get satellite => 'Satelit (Esri)';
	@override String get facilities => 'Zařízení parků';
	@override String get boundaries => 'Hranice';
	@override String get currentLocation => 'Aktuální poloha';
	@override String noMatches({required Object text}) => 'Výrazu „${text}“ nic neodpovídá';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} reference na ${where}',
		other: '${count} referencí na ${where}',
	);
	@override String get startOperation => 'Zahájit aktivitu s těmito referencemi';
}

// Path: activitiesView
class _Translations$activitiesView$cs extends Translations$activitiesView$en {
	_Translations$activitiesView$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aktivity';
	@override String get activitiesCountZero => 'Nevybrány žádné aktivity';
	@override String get activitiesCountOne => '1 aktivita';
	@override String activitiesCountOther({required Object count}) => '${count} aktivit';
	@override String get empty => 'Zatím žádné aktivity — přidejte je pomocí Návrhů a hledání níže';
	@override String get removeActivity => 'Odebrat';
	@override String openReferenceLink({required Object name}) => 'Otevřít ${name}';
	@override String get editActivity => 'Upravit aktivitu';
	@override String get manageExtensions => 'Spravovat rozšíření';
	@override String get manage => 'Spravovat';
	@override String activitiesTitle1({required Object first}) => 'Typy aktivit: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Typy aktivit: ${first} a ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Typy aktivit: ${first}, ${second} a ${more} další';
	@override String get reference => 'Reference';
	@override String get invalidReference => 'Neplatná';
	@override String get duplicateReference => 'Už přidáno';
	@override String get searchHint => 'Hledat podle názvu, reference nebo čehokoli jiného…';
	@override String get noSuggestions => 'Žádné shody';
	@override String get noSuggestionsHint => 'Hledejte výše podle názvu nebo čísla reference';
	@override String get noSuggestionsExample => '(například \'trail\' nebo \'4556\')';
	@override String get allOptions => 'Typy aktivit';
	@override String get determiningLocation => 'Zjišťování aktuální polohy…\nČeká se na GPS pro nalezení referencí v okolí';
	@override String get locationUnavailableTitle => 'Údaje o poloze nejsou k dispozici';
	@override String get locationDeniedTitle => 'Oprávnění k poloze zamítnuto';
	@override String get locationBlockedTitle => 'Oprávnění k poloze zablokováno';
	@override String get noNearbyReason => 'Nelze určit reference v okolí';
	@override String locationManualHint({required Object icon}) => 'Klepněte na ${icon} a zadejte polohu ručně,\nnebo hledejte reference podle názvu';
	@override String get locationGrantAction => 'Povolit přístup k poloze';
	@override String get locationSettingsAction => 'Otevřít Nastavení';
	@override String get locationSettingsUnavailable => 'Povolte přístup k poloze v nastavení systému';
	@override String get locationGrantRefused => 'Stále bez polohy — systém to znovu odmítl';
	@override String get searchUnavailableTitle => 'Hledání aktivit není k dispozici';
	@override String get searchUnavailableReason => 'Některé rozšíření aktivit nedokázalo na hledání odpovědět. Za chvíli to zkuste znovu.';
	@override String get emptySheet => 'Přidejte je pomocí návrhů a hledání níže';
	@override String get exports => 'Exporty';
	@override String get exportLogs => 'Exportovat logy';
	@override String get tools => 'Nástroje';
	@override String get toolsTitle => 'Nástroje aktivity';
	@override String get operationDetails => 'Podrobnosti aktivity';
	@override String get share => 'Sdílet';
	@override String get archive => 'Archivovat';
	@override String get deleteOperation => 'Smazat aktivitu';
	@override String get undeleteOperation => 'Obnovit aktivitu';
	@override String get alreadySelected => 'Už vybráno';
	@override String get selected => 'Vybráno';
	@override String pickPosition({required Object index, required Object count}) => '${index} z ${count}';
	@override String get previousPick => 'Předchozí shoda';
	@override String get nextPick => 'Další shoda';
	@override String get retiredReference => 'Vyřazeno';
	@override String enableExtension({required Object name}) => 'Zapnout ${name}';
	@override String get enableExtensionHint => 'Toto rozšíření odpovídá vašemu hledání, ale není zapnuté';
	@override String get enableExtensionForRefHint => 'Toto rozšíření obsluhuje jednu z referencí této aktivity, ale není zapnuté';
	@override String extensionNotRunning({required Object name}) => '${name} neběží';
	@override String get extensionNotRunningHint => 'Toto rozšíření bylo vypnuto, více informací najdete v Nastavení rozšíření';
	@override String installExtension({required Object name}) => 'Instalovat ${name}';
	@override String get installExtensionHint => 'Toto rozšíření odpovídá vašemu hledání, ale není nainstalováno';
	@override String get onlyCatalogMatches => 'Žádné shody\nNěkterá rozšíření v katalogu mohou mít výsledky.\nNainstalujte je v Typech aktivit níže.';
	@override String get setupUnavailable => 'Nastavení této aktivity nelze načíst — zkuste to znovu přes Spravovat';
	@override String get controlsUnavailableTitle => 'Ovládání aktivity není k dispozici';
	@override String get controlsUnavailableReason => 'Vaše reference jsou v bezpečí, ale jejich úprava teď není k dispozici.';
	@override String get controlsUnavailableRetry => 'Zkusit znovu';
	@override String get onlyDisabledMatches => 'Žádné shody\nNěkterá dostupná rozšíření mohou mít výsledky.\nZapněte je v Typech aktivit níže.';
	@override String get onlyNotRunningMatches => 'Žádné shody\nNěkterá rozšíření, která mohou mít výsledky, neběží.\nViz Typy aktivit níže.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Hledat';
	@override String get addToOperation => 'Přidat do aktivity';
	@override String get addToOperationShort => 'Přidat';
	@override String get mapEmptyState => 'Žádné výsledky k zobrazení na mapě';
	@override String get mapEmptyStateHint => 'Přepněte zpět na seznam, nebo hledejte něco jiného';
	@override String get imports => 'Importy';
}

// Path: loggingControls
class _Translations$loggingControls$cs extends Translations$loggingControls$en {
	_Translations$loggingControls$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Čas (UTC)';
	@override String get date => 'Datum';
	@override String get now => 'Nyní';
	@override String get manualTimeSettings => 'Ruční čas';
	@override String get manualTimeIncrement => 'Přírůstek na QSO';
	@override String get manualTimeIncrementNone => 'Žádný';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} minuta',
		other: '${count} min',
	);
	@override String get frequency => 'Frekvence';
	@override String get mode => 'Mód';
	@override String get theirCall => 'Značka protistanice';
	@override String get noteField => 'Poznámka';
	@override String get todoField => 'Úkol';
	@override String get sent => 'Odesl.';
	@override String get rcvd => 'Přij.';
	@override String get more => 'Více';
	@override String get revert => 'Vrátit zpět';
	@override String get undoDelete => 'Vrátit smazání';
	@override String get restore => 'Obnovit';
	@override String get wipe => 'Vymazat';
	@override String get undo => 'Zpět';
	@override String get pendingDeleteTapWarning => 'Klepněte na koš ještě jednou a QSO se smaže';
	@override String get pendingDeleteClickWarning => 'Klikněte na koš ještě jednou a QSO se smaže';
	@override String get deletedQsoWarning => 'Smazané QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Klepněte na koš ještě jednou a smažete tuto položku (${kind})';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Klikněte na koš ještě jednou a smažete tuto položku (${kind})';
	@override String deletedEventWarning({required Object kind}) => 'Smazáno: ${kind}';
	@override String get timeControl => 'Čas';
	@override String get radioControl => 'Rádio';
	@override String get powerControl => 'Výkon';
	@override String get notesControl => 'Poznámky';
	@override String get power => 'Výkon';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Ovládání logování';
	@override String get spottingControl => 'Spotování';
	@override String get spottingSelfControl => 'Self-spotting';
	@override String spotSelfAt({required Object freq}) => 'Self-spot na ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spotnout ${call} na ${freq}';
	@override String spotTooLate({required Object call}) => 'Příliš pozdě ke spotnutí ${call}';
	@override String get spotNoFreq => 'Nejprve nastavte frekvenci ke spotnutí';
	@override String get selfSpotDisabled => 'Self-spot vypnut';
	@override String get spotComment => 'Komentář';
	@override String get spottingAutoControl => 'Automatický respot';
	@override String spotAutoEvery({required Object minutes}) => 'Znovu spotnout každých ${minutes} min';
	@override String spotAutoNext({required Object time}) => 'Auto za ${time}. Zastavit?';
	@override String spotAutoInMinutes({required Object minutes}) => 'Auto za ${minutes} min';
	@override String spotAutoInSeconds({required Object seconds}) => 'Auto za ${seconds} s';
	@override String spotAutoInCount({required Object seconds}) => 'Auto za ${seconds}';
	@override String get spotAutoNotStarted => 'Automatický respot nespuštěn: spot neprošel';
	@override String get spotAutoMoved => 'Automatický respot nespuštěn: frekvence se během spotování změnila';
	@override String get spotAutoStopped => 'Automatický respot zastaven';
	@override String get spotAutoLeftFreq => 'Automatický respot zastaven: frekvence se změnila';
	@override String get spotAutoNoFreq => 'Automatický respot zastaven: rádio nehlásí žádnou frekvenci';
	@override String get spotBusy => 'Ještě se odesílá jiný spot';
	@override String get bandOrFreqRequired => 'Před logováním nastavte frekvenci nebo pásmo';
	@override String get missingBand => 'Bez pásma';
	@override String get missingMode => 'Bez módu';
	@override String saveFailed({required Object error}) => 'Nelze uložit: ${error}';
	@override String deleteFailed({required Object error}) => 'Nelze smazat: ${error}';
	@override late final _Translations$loggingControls$info$cs info = _Translations$loggingControls$info$cs._(_root);
}

// Path: formChrome
class _Translations$formChrome$cs extends Translations$formChrome$en {
	_Translations$formChrome$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(bez názvu)';
	@override String get showMore => 'Zobrazit více';
	@override String get showAll => 'Zobrazit vše';
	@override String get showFewer => 'Zobrazit méně';
	@override String get defaults => 'Výchozí';
	@override String get search => 'Hledat';
	@override String get clear => 'Vymazat';
	@override String get openPage => 'Otevřít stránku';
	@override String get connected => 'Připojeno';
	@override String get notConnected => 'Nepřipojeno';
	@override String get manage => 'Spravovat';
	@override String get connect => 'Připojit';
	@override String get formTitle => 'Formulář';
	@override String addItem({required Object label}) => 'Přidat ${label}';
	@override String editItem({required Object label}) => 'Upravit ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Zobrazeno ${shown} z ${total} (vybráno ${selected})';
	@override String validationError({required Object error}) => 'Chyba ověření: ${error}';
	@override String transformationError({required Object error}) => 'Chyba transformace: ${error}';
	@override String actionError({required Object error}) => 'Chyba: ${error}';
	@override String get removeItem => 'Smazat';
	@override String deleteItemTitle({required Object name}) => 'Smazat ${name}?';
	@override String get storageUnavailable => 'Přihlašovací údaje nejsou k dispozici';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$cs extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Upravit QSO';
	@override String get operatorCall => 'Operátor';
	@override String get position => 'Pracoviště';
	@override String get theirName => 'Jméno';
	@override String get theirGrid => 'Lokátor';
	@override String get theirState => 'Stát';
	@override String get band => 'Pásmo';
	@override String get notes => 'Poznámky';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Info protistanice';
	@override String get sectionOur => 'Naše info';
	@override String get sectionNotes => 'Poznámky';
	@override String get theirCity => 'Město';
	@override String get theirCounty => 'Okres';
	@override String get theirEntity => 'Entita';
	@override String get theirCqZone => 'CQ zóna';
	@override String get theirItuZone => 'ITU zóna';
	@override String get theirArrlSection => 'Sekce ARRL';
	@override String get theirLat => 'Zeměpisná šířka';
	@override String get theirLon => 'Zeměpisná délka';
	@override String get theirPower => 'Výkon protistanice';
}

// Path: qsoList
class _Translations$qsoList$cs extends Translations$qsoList$en {
	_Translations$qsoList$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Zatím žádná QSO — navažte nějaké spojení!';
	@override String get bandOrModeWarning => 'Ověřte prosím, že máte správné pásmo a mód';
	@override String get today => 'Dnes';
	@override String get yesterday => 'Včera';
	@override String get tomorrow => 'Zítra';
	@override late final _Translations$qsoList$find$cs find = _Translations$qsoList$find$cs._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$cs extends Translations$loggingPanel$en {
	_Translations$loggingPanel$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Statistiky aktivity';
	@override String get scoring => 'Bodování';
	@override String get dxccEntities => 'Entity DXCC';
	@override String get statesWorked => 'Státy';
	@override String get provincesWorked => 'Provincie';
	@override String get duplicates => 'Duplicity';
}

// Path: callInfo
class _Translations$callInfo$cs extends Translations$callInfo$en {
	_Translations$callInfo$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Zobrazit obrázek';
	@override String get imageUnavailable => 'Fotografie není k dispozici';
	@override String get photo => 'Fotografie';
	@override String get notes => 'Poznámky';
	@override String distanceTo({required Object distance}) => '${distance} k';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) k';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) k';
	@override String distanceAway({required Object distance}) => '${distance} daleko';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) daleko';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) daleko';
	@override String get thisOpCountOne => '1 QSO v této aktivitě';
	@override String thisOpCountOther({required Object count}) => '${count} QSO v této aktivitě';
	@override String get otherOpsCountOne => '1 QSO v jiných aktivitách';
	@override String otherOpsCountOther({required Object count}) => '${count} QSO v jiných aktivitách';
	@override String andMore({required Object count}) => '… a ${count} další';
	@override String withCall({required Object call}) => 's ${call}';
	@override String fromOperation({required Object where}) => 'z ${where}';
	@override late final _Translations$callInfo$history$cs history = _Translations$callInfo$history$cs._(_root);
}

// Path: settings
class _Translations$settings$cs extends Translations$settings$en {
	_Translations$settings$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nastavení';
	@override String get language => 'Jazyk';
	@override String languageSystem({required Object language}) => 'Podle nastavení systému (${language})';
	@override late final _Translations$settings$theme$cs theme = _Translations$settings$theme$cs._(_root);
	@override late final _Translations$settings$themeDescription$cs themeDescription = _Translations$settings$themeDescription$cs._(_root);
	@override String get fontScale => 'Velikost písma';
	@override late final _Translations$settings$fontScaleOpts$cs fontScaleOpts = _Translations$settings$fontScaleOpts$cs._(_root);
	@override late final _Translations$settings$keepDeviceAwake$cs keepDeviceAwake = _Translations$settings$keepDeviceAwake$cs._(_root);
	@override String get layoutDensity => 'Hustota rozložení';
	@override late final _Translations$settings$layoutDensityOpts$cs layoutDensityOpts = _Translations$settings$layoutDensityOpts$cs._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'okno je příliš nízké, používá se ${effective}';
	@override String get layoutDensityAtLimit => 'na maximum';
	@override String get distanceUnits => 'Jednotky vzdálenosti';
	@override late final _Translations$settings$distanceUnitsOpts$cs distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$cs._(_root);
	@override String get userInterface => 'Uživatelské rozhraní';
	@override late final _Translations$settings$logging$cs logging = _Translations$settings$logging$cs._(_root);
	@override late final _Translations$settings$catServer$cs catServer = _Translations$settings$catServer$cs._(_root);
	@override late final _Translations$settings$cluster$cs cluster = _Translations$settings$cluster$cs._(_root);
	@override late final _Translations$settings$spotting$cs spotting = _Translations$settings$spotting$cs._(_root);
	@override late final _Translations$settings$radio$cs radio = _Translations$settings$radio$cs._(_root);
	@override late final _Translations$settings$help$cs help = _Translations$settings$help$cs._(_root);
	@override late final _Translations$settings$exports$cs exports = _Translations$settings$exports$cs._(_root);
	@override late final _Translations$settings$extensionSections$cs extensionSections = _Translations$settings$extensionSections$cs._(_root);
	@override late final _Translations$settings$map$cs map = _Translations$settings$map$cs._(_root);
	@override late final _Translations$settings$privacy$cs privacy = _Translations$settings$privacy$cs._(_root);
	@override String get operatorCall => 'Volací značka operátora';
	@override late final _Translations$settings$sync$cs sync = _Translations$settings$sync$cs._(_root);
	@override late final _Translations$settings$peers$cs peers = _Translations$settings$peers$cs._(_root);
	@override String get developerMode => 'Režim vývojáře';
	@override late final _Translations$settings$syncPanel$cs syncPanel = _Translations$settings$syncPanel$cs._(_root);
	@override late final _Translations$settings$accounts$cs accounts = _Translations$settings$accounts$cs._(_root);
	@override late final _Translations$settings$station$cs station = _Translations$settings$station$cs._(_root);
	@override late final _Translations$settings$offlineData$cs offlineData = _Translations$settings$offlineData$cs._(_root);
	@override late final _Translations$settings$profiles$cs profiles = _Translations$settings$profiles$cs._(_root);
	@override late final _Translations$settings$search$cs search = _Translations$settings$search$cs._(_root);
	@override late final _Translations$settings$developer$cs developer = _Translations$settings$developer$cs._(_root);
	@override late final _Translations$settings$about$cs about = _Translations$settings$about$cs._(_root);
	@override late final _Translations$settings$panels$cs panels = _Translations$settings$panels$cs._(_root);
	@override String get showMoreSettings => 'Zobrazit další nastavení';
	@override String get gridPrecision => 'Přesnost lokátoru';
	@override late final _Translations$settings$gridPrecisionOpts$cs gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$cs._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$cs gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$cs._(_root);
}

// Path: commands
class _Translations$commands$cs extends Translations$commands$en {
	_Translations$commands$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Nejprve zapněte synchronizaci v Nastavení.';
	@override String get fullResyncStarted => 'Spuštěna úplná resynchronizace — místní data byla nejprve zálohována.';
	@override String noDataFilesMatched({required Object target}) => 'Žádné datové soubory neodpovídají "${target}".';
	@override String reloadFailed({required Object error}) => 'Opětovné načtení selhalo: ${error}';
	@override String get reloadingAll => 'Opětovné načítání všech datových souborů…';
	@override String reloadingTarget({required Object target}) => 'Opětovné načítání datových souborů ${target}…';
	@override String unknownExperiment({required Object token}) => 'Neznámý experiment "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} zapnuto';
	@override String experimentDisabled({required Object name}) => '${name} vypnuto';
	@override String get sentryTestSent => 'Testovací hlášení chyby odesláno do Sentry';
	@override String get idleMetricsEnabled => 'Metriky nečinnosti zapnuty ve stavovém řádku';
	@override String get idleMetricsDisabled => 'Metriky nečinnosti vypnuty';
	@override String get sentryTestLocalOnly => 'Sentry je v tomto sestavení vypnuté — testovací chyba zaznamenána jen místně';
	@override String get noOperationOpen => 'Tento příkaz potřebuje otevřenou aktivitu';
	@override String unknownSegmentKind({required Object kind}) => 'Nevím, jak označit \'${kind}\'';
	@override String goUnavailable({required Object place}) => 'Funkce ${place} není v této aplikaci zapnutá';
	@override String goUnknown({required Object to}) => 'Nevím, jak přejít na \'${to}\'';
	@override String get goBlocked => 'Nejprve zavřete otevřený dialog';
	@override String get operationAlreadyStarted => 'Tato aktivita už má značku začátku';
	@override String get couldNotOpenLocation => 'Přestávka přidána, ale obrazovku polohy nelze otevřít';
	@override String get noTestOperations => 'Žádné testovací aktivity k vyčištění';
	@override String get purgeTestsUnavailable => 'PURGETESTS potřebuje zobrazit potvrzovací dialog, který zde není k dispozici';
	@override String get syncAllUnavailable => 'SYNCALL potřebuje zobrazit potvrzovací dialog, který zde není k dispozici';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Vyčištěna ${count} testovací aktivita',
		other: 'Vyčištěno ${count} testovacích aktivit',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => 'Vyčištěno ${purged} z ${total} testovacích aktivit — zbytek selhal; zkuste PURGETESTS znovu';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Vyčištěno ${count} testovací spojení bez aktivity',
		other: 'Vyčištěno ${count} testovacích spojení bez aktivity',
	);
	@override String get purgeTestsContactsFailed => 'Testovací aktivity vyčištěny, ale testovací spojení bez aktivity selhala; zkuste PURGETESTS znovu';
	@override String get purgeTestsNothingToDo => 'Nic nebylo vyčištěno';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => 'Odebráno ${removed} z ${total} testovacích aktivit — zbytek selhal; zkuste Zkontrolovat znovu';
	@override String get receivedPurgesFailed => 'Tyto testovací aktivity nelze odebrat — zkuste Zkontrolovat znovu';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} testovací aktivita byla odebrána na jiném zařízení',
		other: '${count} testovacích aktivit bylo odebráno na jiném zařízení',
	);
	@override String get receivedPurgesReview => 'Zkontrolovat';
	@override String get settingOn => 'Zapnuto';
	@override String get settingOff => 'Vypnuto';
	@override String get settingEmpty => '(prázdné)';
	@override String get settingSecretSet => '(nastaveno)';
	@override String get settingSecretUnset => '(nenastaveno)';
	@override String settingSelectedCount({required Object count}) => 'Vybráno: ${count}';
	@override String get settingExpectsOnOff => 'zapnuto nebo vypnuto';
	@override String settingExpectsOneOf({required Object choices}) => 'jedno z: ${choices}';
	@override String get settingExpectsNumber => 'číslo';
	@override String settingVanished({required Object label}) => '„${label}“ už není k dispozici';
	@override String get noCwKeyer => 'Žádné připojené rádio neumí klíčovat CW';
	@override String get noKeyer => 'Žádné připojené rádio neumí klíčovat CW ani přehrávat hlasové paměti';
	@override String get keyerNeedsOperation => 'Pro použití CW klíčovače otevřete aktivitu';
	@override String get keyerExperimentOff => 'Klíčování CW je vypnuté — zapněte ho pomocí EXP KEYER';
	@override String get esmExperimentOff => 'Funkce Enter odesílá zprávy je vypnutá — zapněte ji pomocí EXP ESM';
	@override String cwSending({required Object text}) => 'Vysílání CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Zpráva CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'Zpráva CW F${n} nebyla odeslána: rozšíření nejsou připravena';
	@override String voiceMessageError({required Object n, required Object error}) => 'Hlasová zpráva M${n}: ${error}';
	@override String get voiceMessageNotRendered => 'rozšíření nejsou připravena';
	@override String so2rRadioCannotKey({required Object radio}) => 'Nic neodesláno: rádio ${radio} to neumí klíčovat';
	@override String get so2rNoRadioB => 'Nic neodesláno: pro klíčování z této sady vyberte rádio B v Konfiguraci stanice';
	@override String settingNotStored({required Object label}) => '„${label}“ tuto hodnotu nepřijalo';
}

// Path: commandDialog
class _Translations$commandDialog$cs extends Translations$commandDialog$en {
	_Translations$commandDialog$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Hledejte značky nebo zadejte příkaz';
	@override String noResults({required Object text}) => 'Výrazu „${text}“ nic neodpovídá';
	@override String get sectionCommands => 'Příkazy';
	@override String get sectionGoTo => 'Přejít na';
	@override String get sectionOperations => 'Aktivity';
	@override String get goHome => 'Domů';
	@override String get goSettings => 'Nastavení';
	@override String get goNewOperation => 'Nová aktivita';
	@override String runTyped({required Object text}) => 'Spustit „${text}“';
	@override String get sectionSuggestions => 'Zkuste';
	@override String get lookingUp => 'Vyhledávání značky…';
	@override String get blockedByPane => 'Příkazy nelze používat, když je otevřený panel nebo dialog';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$cs extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Klávesové zkratky';
	@override String get description => 'Přizpůsobte si přiřazení kláves';
	@override String get search => 'Hledat příkazy a klávesy';
	@override String get import => 'Importovat…';
	@override String get export => 'Exportovat…';
	@override String get resetAll => 'Obnovit vše na výchozí';
	@override String get resetAllTitle => 'Obnovit výchozí u všech zkratek?';
	@override String get resetAllBody => 'Každý příkaz se vrátí ke svým výchozím klávesám a klávesy přiřazené příkazům zadaným jako text se odeberou.';
	@override String get reset => 'Obnovit výchozí';
	@override String get noKey => 'Bez klávesy';
	@override String get changed => 'Změněno';
	@override String conflict({required Object keys, required Object commands}) => '${keys} je přiřazeno také: ${commands}';
	@override String get groupApp => 'Aplikace';
	@override String get groupKeying => 'Klíčování';
	@override String get groupLogging => 'Logování';
	@override String get groupCommands => 'Příkazy';
	@override String get groupFixed => 'Pevné klávesy';
	@override String get contextApp => 'Kdekoli';
	@override String get contextLogView => 'Zobrazení Aktivita, Lovení a Logy';
	@override String get contextOperation => 'Zobrazení Aktivita, při klíčování rádia přes CAT';
	@override String get contextLogging => 'V panelu logování';
	@override String get addCommand => 'Přidat příkaz…';
	@override String unknownCommand({required Object command}) => 'Neznámý příkaz: ${command}';
	@override late final _Translations$keyboardShortcuts$command$cs command = _Translations$keyboardShortcuts$command$cs._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$cs fixed = _Translations$keyboardShortcuts$fixed$cs._(_root);
	@override late final _Translations$keyboardShortcuts$editor$cs editor = _Translations$keyboardShortcuts$editor$cs._(_root);
	@override late final _Translations$keyboardShortcuts$file$cs file = _Translations$keyboardShortcuts$file$cs._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$cs modifier = _Translations$keyboardShortcuts$modifier$cs._(_root);
	@override late final _Translations$keyboardShortcuts$platform$cs platform = _Translations$keyboardShortcuts$platform$cs._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$cs extends Translations$expiredBuild$en {
	_Translations$expiredBuild$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Platnost tohoto sestavení vypršela';
	@override String get body => 'Navštivte prosím ham2k.com a stáhněte si novější verzi.';
	@override String get visit => 'Navštívit ham2k.com';
	@override String get dismiss => 'Přesto pokračovat';
}

// Path: staleness
class _Translations$staleness$cs extends Translations$staleness$en {
	_Translations$staleness$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Čeká na vás důležitá aktualizace';
	@override String get codePushFloorBody => 'Tato verze obsahuje opravu, kterou ještě nemáte.';
	@override String get restartToApply => 'Restartujte aplikaci, aby se použila.';
	@override String get quitAndReopen => 'Ukončete aplikaci a znovu ji otevřete, aby se použila.';
	@override String get reopenToApply => 'Zavřete aplikaci a znovu ji otevřete, aby se použila.';
	@override String get ignoreForNow => 'Zatím ignorovat';
}

// Path: spotting
class _Translations$spotting$cs extends Translations$spotting$en {
	_Translations$spotting$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Zatím není zalogováno žádné QSO ke spotnutí.';
	@override String get setFrequencyFirst => 'Nejprve nastavte frekvenci.';
	@override String get nothingToSpot => 'Nic ke spotování — žádné rozšíření zde spotování nenabízí.';
	@override String get incompleteCall => 'Neúplnou značku nelze spotnout — nejprve ji dopište.';
	@override String spotFailed({required Object source, required Object message}) => 'Chyba ${source}: ${message}';
	@override String get unknownError => 'neznámá chyba';
	@override String get notSent => 'Spot nebyl odeslán.';
	@override String get allSkipped => 'Spot nebyl odeslán: všechny zdroje spotů ho přeskočily.';
	@override String get notRefreshedOffline => 'Bez připojení — spoty nebyly obnoveny';
}

// Path: dataFiles
class _Translations$dataFiles$cs extends Translations$dataFiles$en {
	_Translations$dataFiles$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Stahování…';
	@override String downloadFailedTitle({required Object name}) => '${name} nelze stáhnout';
	@override String get downloadFailedWebHint => 'Může jít o problém se sítí, nebo hostitel tohoto odkazu nepodporuje přímé stahování z webového prohlížeče. Zkuste desktopovou nebo mobilní aplikaci, nebo jiné umístění souboru.';
	@override String get downloadTimedOut => 'Server neodpověděl včas. Zkuste to později.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} odpověděl chybou (HTTP ${status}). Zkuste to později.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} nemohl tento soubor poskytnout (HTTP ${status}). Zkontrolujte, zda je jeho adresa stále správná.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM nemá pro ${stem} žádný soubor Call History.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'Stažení souboru Call History z N1MM pro ${stem} se nezdařilo. Zkuste to později.';
	@override String processingFailedTitle({required Object name}) => '${name} nelze zpracovat';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Stažený soubor obsahoval jen ${imported} z ${existing} záznamů na tomto zařízení, proto byly vynechané záznamy ponechány. Obnovením v Nastavení › Offline data ho přesto přijmete.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Importován ${count} záznam pro ${label}.',
		other: 'Importováno ${count} záznamů pro ${label}.',
	);
	@override String importedData({required Object label}) => 'Importována data pro ${label}.';
	@override String get cleanedUpTitle => 'Data rozšíření vyčištěna';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Odebrána data ${count} datového souboru z vypnutých rozšíření.',
		other: 'Odebrána data ${count} datových souborů z vypnutých rozšíření.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} záznamů';
	@override String get definitionUnavailable => 'Zdroj souboru neposkytl definici — jeho rozšíření se možná právě restartuje nebo je špatně nakonfigurované. Za chvíli to zkuste znovu.';
}

// Path: updates
class _Translations$updates$cs extends Translations$updates$en {
	_Translations$updates$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Aktualizace k dispozici';
	@override String newVersionAvailable({required Object version}) => 'Je k dispozici nová verze (${version}).';
	@override String get getIt => 'Stáhnout';
	@override String get ok => 'OK';
	@override String get updateReady => 'Aktualizace připravena';
	@override String get restartToApply => 'Aktualizace byla stažena. Restartujte, aby se použila.';
	@override String get appliesNextLaunch => 'Aktualizace byla stažena. Použije se při příštím otevření aplikace.';
	@override String get restartNow => 'Restartovat nyní';
	@override String get reloadToUpdate => 'Je k dispozici novější verze této stránky. Načtěte ji znovu.';
	@override String get reloadNow => 'Načíst znovu';
	@override String get checkForUpdates => 'Zkontrolovat aktualizace';
	@override String get checkingForUpdates => 'Kontrola aktualizací…';
	@override String get upToDate => 'Aktuální';
	@override String get automaticChecks => 'Kontrolovat automaticky';
	@override String get automaticChecksDescription => 'Hledat nové verze na pozadí, od příštího spuštění aplikace';
}

// Path: extensionService
class _Translations$extensionService$cs extends Translations$extensionService$en {
	_Translations$extensionService$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Běhové prostředí rozšíření není připraveno.';
	@override String testFailed({required Object error}) => 'Test selhal: ${error}';
	@override String connectedAs({required Object identity}) => 'Připojeno jako ${identity}';
	@override String get invalidFieldConfiguration => 'Neplatná konfigurace pole';
	@override String get invalidValue => 'Neplatná hodnota';
	@override String validationError({required Object error}) => 'Chyba ověření: ${error}';
	@override String actionFailed({required Object error}) => 'Akce selhala: ${error}';
	@override String get commandFailed => 'Příkaz se nepodařilo spustit';
	@override String commandMayNotChangeSettings({required Object name}) => '${name} nemůže měnit nastavení: při instalaci o to nepožádalo';
	@override String commandMayNotControlRadio({required Object name}) => '${name} nemůže ovládat rádio: při instalaci o to nepožádalo';
	@override String commandDeveloperOnly({required Object name}) => '${name} to nemůže spustit: je to jeden z vývojářských příkazů samotné aplikace';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => 'Hlášení teď nelze odeslat';
	@override String get stashUnavailable => 'Ham2K File Stash je teď nedostupný';
	@override String activitySearchSourcesFailed({required Object names}) => 'Bez odpovědi na hledání aktivit: ${names}. Některé výsledky mohou chybět.';
	@override String get activitySearchSomeSourcesFailed => 'Některá rozšíření aktivit na hledání neodpověděla, takže některé výsledky mohou chybět.';
	@override String timersSuspendedBudget({required Object name}) => '${name} strávilo ve svých časovačích příliš mnoho času. Jsou zastaveny, dokud se rozšíření nerestartují.';
	@override String timersSuspendedFailures({required Object name}) => 'Časovače ${name} opakovaně selhávaly. Jsou zastaveny, dokud se rozšíření nerestartují.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} se zaseklo v časovači. Jeho časovače jsou zastaveny, dokud se rozšíření nerestartují.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$cs extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Poloha aktivity';
	@override String get selectedLocation => 'Vybraná poloha';
	@override String get gridSquare => 'Lokátor Maidenhead';
	@override String get gridInvalid => 'Potřebuje 4, 6, 8 nebo 10 znaků, např. FN31pr';
	@override String get suggestedLocations => 'Navrhované polohy';
	@override String get deviceGps => 'GPS zařízení';
	@override String peerGps({required Object device}) => 'GPS z ${device}';
	@override String get locating => 'Hledání polohy…';
	@override String get gpsUnavailable => 'Poloha není k dispozici';
	@override String get permissionDenied => 'Oprávnění k poloze zamítnuto';
	@override String get permissionBlocked => 'Oprávnění k poloze zablokováno';
	@override String get moreDetails => 'Další podrobnosti';
	@override String get stateOrProvince => 'Stát nebo provincie (nepovinné)';
	@override String get controlsUnavailableTitle => 'Ovládání aktivity není k dispozici';
	@override String get controlsUnavailableReason => 'Tyto reference jsou stále použitelné; jen se nepodařilo spojit s jejich aktivitami.';
	@override String get controlsUnavailableRetry => 'Zkusit znovu';
	@override String get county => 'Okres (nepovinné)';
}

// Path: versionLabel
class _Translations$versionLabel$cs extends Translations$versionLabel$en {
	_Translations$versionLabel$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Verze ${version}';
	@override String patch({required Object patch}) => 'Oprava ${patch}';
	@override String build({required Object build}) => 'sestavení ${build}';
}

// Path: notices
class _Translations$notices$cs extends Translations$notices$en {
	_Translations$notices$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Zatím žádná oznámení';
	@override String get webStorageInMemory => 'Tento prohlížeč nemohl poskytnout trvalé úložiště — log je jen v paměti a po zavření této karty bude ZTRACEN. Použijte aktuální Chrome, Firefox, Safari nebo Edge.';
	@override String get webStorageUnreliable => 'Tento prohlížeč používá náhradní úložiště, které není bezpečné při více kartách — mějte otevřenou jen jednu kartu a nechte zapnutou synchronizaci.';
	@override String get logFromNewerBuildTitle => 'Tento log vyžaduje novější verzi';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Váš log byl zapsán novější verzí HaLo (verze úložiště ${storage}; tato rozumí ${understood}), proto ho nelze otevřít a nová spojení nebudou uložena. Nainstalujte znovu novější verzi — nebo, pokud jste chtěli spustit toto sestavení, nasměrujte ho na jinou složku dat. Log je v ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Váš log byl zapsán novější verzí HaLo (verze úložiště ${storage}; tato rozumí ${understood}), proto ho nelze otevřít a nová spojení nebudou uložena. Otevřete tento log raději tou novější verzí.';
	@override String get preferencesRestoredTitle => 'Nastavení obnoveno ze zálohy';
	@override String get preferencesRestored => 'Soubor nastavení nelze přečíst, proto HaLo obnovil jeho poslední dobrou kopii. Cokoli jste změnili v předchozí relaci, možná bude nutné nastavit znovu. Nečitelný soubor je uložen vedle, pod názvem shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Nastavení obnoveno na výchozí';
	@override String get preferencesReset => 'Soubor nastavení nelze přečíst a nebyla k dispozici žádná záloha, proto HaLo začal s výchozím nastavením. Nečitelný soubor je uložen ve složce dat aplikace pod názvem shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} nebylo připojeno automaticky';
	@override String autoConnectHeld({required Object name}) => 'HaLo přestal odpovídat, když se naposledy začal připojovat k ${name}, proto ho tentokrát nechal být, aby to neriskoval znovu. Zkontrolujte, že je rádio zapnuté a kabel zapojený, pak u něj v Nastavení stiskněte Připojit.';
}

// Path: syncAccount
class _Translations$syncAccount$cs extends Translations$syncAccount$en {
	_Translations$syncAccount$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anonymní účet (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (čeká na potvrzení)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (čeká na potvrzení - #${id})';
}

// Path: deepLink
class _Translations$deepLink$cs extends Translations$deepLink$en {
	_Translations$deepLink$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Nejprve zahajte aktivitu, pak toto spojení pošlete znovu';
	@override String get waitingInOperation => 'Toto spojení čeká v aktivitě za touto obrazovkou';
	@override String unknownActivities({required Object refs}) => 'Toto zařízení nemá aktivitu pro ${refs}, proto byly tyto reference vynechány';
	@override String activitiesUnavailable({required Object refs}) => 'Vaše aktivity nejsou dostupné, proto bylo ${refs} vynecháno — zkuste ten odkaz znovu';
}

// Path: confirmDevice
class _Translations$confirmDevice$cs extends Translations$confirmDevice$en {
	_Translations$confirmDevice$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Potvrdit zařízení';
	@override String get codePrompt => 'Zadejte kód zobrazený na zařízení, které se chce připojit k tomuto účtu.';
	@override String get code => 'Kód';
	@override String get lookUp => 'Vyhledat';
	@override String get codeNotFound => 'Tomuto kódu neodpovídá žádná žádost. Kódy vyprší po 10 minutách — požádejte druhé zařízení o nový.';
	@override String get linkExpired => 'Platnost odkazu vypršela. Požádejte druhé zařízení, aby zobrazilo nový QR kód.';
	@override String areYouSure({required Object device}) => 'Propojit ${device} s tímto účtem?';
	@override String get unnamedDevice => 'nepojmenované zařízení';
	@override String get grantWarning => 'Bude moci číst a měnit každou aktivitu a každé QSO v tomto účtu.';
	@override String get needsSyncTitle => 'Toto zařízení se zatím nesynchronizuje';
	@override String get needsSyncText => 'Zapněte synchronizaci Ham2K Log Filer a propojte toto zařízení s účtem, než bude moci přijmout další.';
	@override String get malformedRequest => 'Synchronizační server poslal žádost, kterou tato aplikace nedokáže přečíst. Požádejte druhé zařízení, aby to zkusilo znovu.';
	@override String get linkIt => 'Propojit zařízení';
}

// Path: switchAccounts
class _Translations$switchAccounts$cs extends Translations$switchAccounts$en {
	_Translations$switchAccounts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Zatím žádné údaje o účtu';
	@override String get currentAccount => 'Aktuální účet';
	@override String get otherAccounts => 'Jiné účty';
	@override String get linkToAnother => 'Propojit s jiným účtem';
	@override String get linkWithSibling => 'Propojit s jinou aplikací Ham2K';
	@override String get linkWithPolo => 'Propojit s účtem ve starší verzi';
	@override String get linkWithSiblingDescription => 'Máte nainstalovanou jinou aplikaci Ham2K. Propojte se s účtem, který se používá tam.';
	@override String siblingPrompt({required Object app}) => 'Schvalte žádost v ${app} a pak se vraťte sem.';
	@override String openSiblingAgain({required Object app}) => 'Znovu otevřít ${app}';
	@override String get siblingNoGrant => 'Nefungovalo to? Otevřete ji znovu, nebo se vraťte a propojte jiným způsobem.';
	@override String siblingOpenFailed({required Object app}) => '${app} nelze otevřít.';
	@override String siblingLinkRenewed({required Object app}) => 'Odkaz vypršel a je připraven nový — znovu otevřete ${app}.';
	@override String get tryAgain => 'Zkusit znovu';
	@override String get linkWithQr => 'Propojit pomocí QR kódu';
	@override String get linkWithQrDescription => 'Naskenujte ho ze zařízení, které už účet používá';
	@override String get linkWithEmail => 'Propojit pomocí e-mailové adresy';
	@override String get linkWithEmailDescription => 'Potvrďte kódem nebo odkazem v e-mailu';
	@override String get enterEmailPrompt => 'Zadejte e-mailovou adresu účtu, který má toto zařízení používat.';
	@override String get emailAddress => 'E-mailová adresa';
	@override String get linkAccount => 'Propojit účet';
	@override String get copiedCode => 'Kód zkopírován do schránky';
	@override String get copyCode => 'Kopírovat kód';
	@override String codePrompt({required Object email}) => 'Otevřete aplikaci Ham2K na zařízení, které už je propojeno s ${email}, a zadejte tento kód pro schválení žádosti:';
	@override String get waitingForConfirmation => 'Čeká se na potvrzení…';
	@override String get sendEmailInstead => 'Místo toho poslat potvrzovací e-mail';
	@override String emailSent({required Object email}) => 'Na ${email} byl odeslán e-mail. Otevřete ho a potvrďte žádost o propojení tohoto zařízení.';
	@override String get resendEmail => 'Znovu odeslat e-mail';
	@override String get qrPrompt => 'Naskenujte tento QR kód ze zařízení, které už je propojeno s požadovaným účtem — například pomocí Ham2K Portable Logger v telefonu.';
	@override String get serverUnreachable => 'Synchronizační server je nedostupný. Zkuste to později.';
	@override String get emailRequired => 'Zadejte e-mailovou adresu pro propojení.';
	@override String noAccountForEmail({required Object email}) => 'Pro ${email} nebyl nalezen žádný účet.';
	@override String serverRejected({required Object error}) => 'Synchronizační server žádost odmítl: ${error}';
	@override String get noLinkCode => 'Synchronizační server nevrátil kód pro propojení. Zkuste to později.';
	@override String get noConfirmationCode => 'Synchronizační server neposlal potvrzovací kód. Zkuste to později.';
	@override String get switchNotAccepted => 'Tento účet přepnutí nepřijal. Zkuste ho místo toho propojit pomocí e-mailové adresy.';
	@override String get requestFailed => 'Při komunikaci se synchronizačním serverem se něco pokazilo. Zkuste to později.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} QSO',
		other: '${count} QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} aktivita',
		other: '${count} aktivit',
	);
}

// Path: qsonImport
class _Translations$qsonImport$cs extends Translations$qsonImport$en {
	_Translations$qsonImport$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importovat aktivitu QSON';
	@override String get description => 'Vytvořte novou aktivitu ze souboru QSON, jaký exportuje Režim vývojáře zde nebo v PoLo.';
	@override String get dropHint => 'Přetáhněte sem soubor QSON a importujte ho jako novou aktivitu';
	@override String importing({required Object filename}) => 'Importování ${filename}…';
	@override String failed({required Object filename, required Object error}) => '${filename} nelze importovat: ${error}';
	@override String pickerFailed({required Object error}) => 'Soubor k importu nelze otevřít: ${error}';
	@override String notUtf8({required Object filename}) => '${filename} není text v UTF-8, takže to není soubor QSON';
	@override String notJson({required Object filename}) => '${filename} není soubor JSON, takže to není soubor QSON';
	@override String notOperation({required Object filename}) => '${filename} neobsahuje aktivitu QSON';
	@override String get busy => 'Import už probíhá. Než spustíte další, počkejte, až skončí.';
	@override String get oneFileOnly => 'Přetahujte vždy jen jeden soubor QSON — každý se otevře jako samostatná aktivita.';
}

// Path: adifImport
class _Translations$adifImport$cs extends Translations$adifImport$en {
	_Translations$adifImport$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importovat QSO z ADIF';
	@override String reading({required Object filename}) => 'Čtení ${filename}…';
	@override String get dropHint => 'Přetáhněte sem soubor ADIF k importu';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} QSO v tomto souboru',
		other: '${formatted} QSO v tomto souboru',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} už je ve vašem logu',
		other: '${formatted} už je ve vašem logu',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} bude importováno',
		other: '${formatted} bude importováno',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} nové spojení',
		other: '${formatted} nových spojení',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} se sloučí s existujícím spojením',
		other: '${formatted} se sloučí s existujícími spojeními',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} nelze importovat (bez značky)',
		other: '${formatted} nelze importovat (bez značky)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} je třeba zkontrolovat',
		other: '${formatted} je třeba zkontrolovat',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Reference nelze obnovit u ${count} spojení',
		other: 'Reference nelze obnovit u ${formatted} spojení',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Reference ${programs} mohou být neúplné u ${count} spojení',
		other: 'Reference ${programs} mohou být neúplné u ${formatted} spojení',
	);
	@override String get stackingTypesUnknown => 'Sloučená spojení mohou přijít o referenci — aktivity nedokázaly říct, které typy se kombinují. Abyste tomu předešli, zrušte a zkuste to znovu.';
	@override String get nothingToImport => 'Z tohoto souboru nelze nic importovat';
	@override String get confirm => 'Importovat';
	@override String importing({required Object filename}) => 'Importování ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Importováno ${count} spojení z ${filename}',
		other: 'Importováno ${formatted} spojení z ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => '${filename} nelze importovat: ${error}';
	@override String notAdif({required Object filename}) => '${filename} nevypadá jako soubor ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Upozornění: tento ADIF obsahuje QSO od ${calls}, ale pokud budete pokračovat, budou importována jako ${station}.';
	@override String get stationCallJoin => ' a ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} nemá datum a nelze ho importovat',
		other: '${formatted} nemá datum a nelze je importovat',
	);
	@override String activationFound({required Object refs}) => 'Tento soubor zaznamenává aktivaci ${refs}.';
	@override String get addActivation => 'Přidat ji do této aktivity';
	@override String shortfall({required Object written, required Object planned}) => 'Použít se podařilo jen ${written} z ${planned} — log se změnil, zatímco jste se rozhodovali.';
	@override String get busy => 'Import už probíhá. Než spustíte další, počkejte, až skončí.';
	@override String get oneFileOnly => 'Přetahujte vždy jen jeden soubor ADIF — pořadí importu souborů rozhoduje, která data mají přednost.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} má více než ${limit} QSO, což je maximum, které aktivita může importovat najednou.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename} má více než ${limit} QSO. Import ADIF do aktivity je určen k přidání několika QSO, ne k nahrání velkého logu — na to použijte zobrazení Logy. Režim vývojáře vám ho přesto dovolí importovat, pokud jste si jistí.';
	@override String get importAnyway => 'Přesto importovat';
}

// Path: offline
class _Translations$offline$cs extends Translations$offline$en {
	_Translations$offline$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: připojeno';
	@override String get noRoute => 'Vůbec žádné připojení k síti.';
	@override String get unreachable => 'Síť funguje, ale žádný server neodpovídá — často to znamená přihlašovací stránku čekající v prohlížeči.';
	@override String get reachable => 'Všechny služby odpovídají podle očekávání.';
	@override String get whatStops => 'Vyhledávání, spoty a datové soubory jsou pozastaveny. Logování a synchronizace v okolí ne.';
	@override String get servicesTitle => 'Služby';
	@override String get noServices => 'Zatím se neozvala žádná služba.';
	@override String lastSuccess({required Object when}) => 'Naposledy odpověděla před ${when}';
	@override String get neverSucceeded => 'Zatím neodpověděla';
	@override String nextAttempt({required Object when}) => 'Další pokus za ${when}';
	@override String get nextAttemptNow => 'Další pokus je na řadě';
	@override String get retry => 'Zkusit nyní';
	@override String get retrying => 'Zkouší se…';
	@override String get retryReached => 'Opět online.';
	@override String get retryUnreachable => 'Stále bez odpovědi.';
	@override String get retryNotAttempted => 'Teď není co odeslat.';
	@override String get retryThrottled => 'Právě jsme to zkusili — chvíli počkejte.';
	@override String get retryDisabled => 'Synchronizace je vypnutá, takže není čím testovat.';
	@override String get syncService => 'Synchronizace Ham2K LoFi';
	@override String get retryInFlight => 'Už se zkouší — vydržte.';
}

// Path: exportSettings
class _Translations$exportSettings$cs extends Translations$exportSettings$en {
	_Translations$exportSettings$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Základní nastavení pro všechny exporty, se samostatnými šablonami názvu souboru a titulku pro aktivity s referencemi a ostatní aktivity. Každý typ exportu může mít své vlastní výchozí hodnoty nebo vlastní nastavení.';
	@override String get referenceActivities => 'Aktivity s referencemi';
	@override String get otherActivities => 'Ostatní aktivity';
	@override String get adifFields => 'Pole ADIF';
	@override String get loadFailed => 'Nastavení exportu nelze načíst.';
	@override String get retry => 'Zkusit znovu';
	@override String get compactFileNamesDescriptionOn => 'Kompaktní názvy souborů, např. N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Popisné názvy souborů, např. 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Do souborů ADIF se zahrnují jména, adresy, e-maily, poznámky a přesné polohy.';
	@override String get includePrivateDataDescriptionOff => 'Vynechávají se jména, adresy, e-maily a poznámky; polohy jsou omezeny na šestiznakové lokátory.';
	@override String get includeLookupDataDescriptionOn => 'Zahrnují se informace ze služeb vyhledávání značek.';
	@override String get includeLookupDataDescriptionOff => 'Vynechávají se informace ze služeb vyhledávání značek; ručně zadané hodnoty zůstávají.';
	@override String get customTemplatesDescriptionOn => 'Vaše vlastní šablony jsou aktivní a lze je upravit níže.';
	@override String get customTemplatesDescriptionOff => 'Aktivní jsou výchozí šablony. Vaše vlastní šablony zůstávají uloženy na později.';
	@override String get type => 'Typ exportu';
	@override String get defaults => 'Výchozí';
	@override String get includeLookupData => 'Zahrnout data z vyhledávání';
	@override String get customTemplates => 'Vlastní šablony';
	@override String get filenameTemplate => 'Šablona názvu souboru';
	@override String get compactFilenameTemplate => 'Šablona kompaktního názvu souboru';
	@override String get titleTemplate => 'Šablona titulku';
	@override String get adifNotesTemplate => 'ADIF QSO poznámky';
	@override String get adifCommentTemplate => 'ADIF QSO komentáře';
	@override String get adifQslMessageTemplate => 'ADIF QSL zpráva';
	@override String get shared => 'Nastavení platí pro všechna rozšíření, která používají tento typ exportu.';
	@override String get defaultTemplates => 'Pro úpravu šablon tohoto typu zapněte Vlastní šablony.';
}

// Path: templateEditor
class _Translations$templateEditor$cs extends Translations$templateEditor$en {
	_Translations$templateEditor$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Náhled:';
	@override String get reset => 'Obnovit výchozí';
	@override String get docs => 'Dokumentace šablon';
	@override String get preview => 'Ukázkový náhled';
	@override String get reference => 'Nápověda k šablonám';
	@override String get attributes => 'Dostupné atributy';
	@override String get filters => 'Filtry';
	@override String get flowControl => 'Řízení toku';
	@override String get unavailable => 'Náhled není k dispozici, dokud nejsou rozšíření připravena.';
	@override String get empty => '(prázdný výstup)';
}

// Path: home.nav
class _Translations$home$nav$cs extends Translations$home$nav$en {
	_Translations$home$nav$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Aktivity';
	@override String get chase => 'Lovení';
	@override String get logs => 'Logy';
	@override String get maps => 'Mapy';
	@override String get settings => 'Nastavení';
}

// Path: home.panels
class _Translations$home$panels$cs extends Translations$home$panels$en {
	_Translations$home$panels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Seznam aktivit';
	@override String get operationsDescription => 'Vaše aktivity, nejnovější první.';
	@override String get version => 'Aktuální verze';
	@override String get versionDescription => 'Logo Ham2K, název této aplikace a sestavení, které používáte.';
}

// Path: home.logs
class _Translations$home$logs$cs extends Translations$home$logs$en {
	_Translations$home$logs$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logy';
	@override String get titleFor => 'Logy pro';
	@override String get emptyCallsigns => 'Zatím žádná zalogovaná QSO';
	@override String emptyQsos({required Object call}) => 'Žádná QSO pro ${call}';
	@override String get mapNoSelection => 'Vyberte QSO, aby se zobrazilo na mapě';
	@override String get searchHint => 'Hledat značku nebo jméno';
	@override String get noSearchMatches => 'Žádné QSO neodpovídá hledání';
	@override String get titleAll => 'Všechny logy';
	@override String get allCallsigns => 'Všechny značky';
	@override String get noOperation => 'Není součástí aktivity';
	@override String get unsavedTitle => 'Neuložené změny';
	@override String get unsavedBody => 'Toto QSO má neuložené změny.';
	@override String get pendingDeleteBody => 'Toto QSO je označeno ke smazání.';
	@override String get editGone => 'Neuloženo: toto QSO už v tomto logu není.';
	@override String get discard => 'Zahodit';
	@override late final _Translations$home$logs$sheet$cs sheet = _Translations$home$logs$sheet$cs._(_root);
	@override late final _Translations$home$logs$groupBy$cs groupBy = _Translations$home$logs$groupBy$cs._(_root);
	@override late final _Translations$home$logs$period$cs period = _Translations$home$logs$period$cs._(_root);
	@override late final _Translations$home$logs$periodTitle$cs periodTitle = _Translations$home$logs$periodTitle$cs._(_root);
	@override late final _Translations$home$logs$columns$cs columns = _Translations$home$logs$columns$cs._(_root);
	@override late final _Translations$home$logs$panels$cs panels = _Translations$home$logs$panels$cs._(_root);
	@override late final _Translations$home$logs$import$cs import = _Translations$home$logs$import$cs._(_root);
}

// Path: chase.station
class _Translations$chase$station$cs extends Translations$chase$station$en {
	_Translations$chase$station$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Lovící stanice';
	@override String get stationLabel => 'Stanice: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Bez polohy';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$cs extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get today => 'dnes';
	@override String get thisWeek => 'tento týden';
	@override String get last14Days => 'za posledních 14 dní';
	@override String get thisMonth => 'tento měsíc';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$cs extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistiky za dnešek';
	@override String get thisWeek => 'Statistiky za tento týden';
	@override String get last14Days => 'Statistiky za posledních 14 dní';
	@override String get thisMonth => 'Statistiky za tento měsíc';
}

// Path: chase.period
class _Translations$chase$period$cs extends Translations$chase$period$en {
	_Translations$chase$period$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get today => 'Dnes';
	@override String get thisWeek => 'Tento týden';
	@override String get last14Days => 'Posledních 14 dní';
	@override String get thisMonth => 'Tento měsíc';
}

// Path: chase.goals
class _Translations$chase$goals$cs extends Translations$chase$goals$en {
	_Translations$chase$goals$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cíle lovení';
	@override String remove({required Object name}) => 'Přestat lovit ${name}';
	@override String get extensionsTitle => 'Další programy k lovení';
}

// Path: chase.panels
class _Translations$chase$panels$cs extends Translations$chase$panels$en {
	_Translations$chase$panels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => 'Ovládání logování nad QSO ulovenými v daném období.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Logovaná značka, nebo statistiky za období.';
	@override String get spots => 'Spoty';
	@override String get spotsDescription => 'Stanice spotované v éteru, připravené k lovu.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'QSO z daného období a logovaná stanice.';
}

// Path: chase.claims
class _Translations$chase$claims$cs extends Translations$chase$claims$en {
	_Translations$chase$claims$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get checking => 'Kontrola QSO pro lovení';
	@override String rebuilding({required Object program}) => 'Kontrola logu pro ${program}';
	@override String progress({required Object done, required Object total}) => '${done} z ${total} QSO';
}

// Path: chase.notice
class _Translations$chase$notice$cs extends Translations$chase$notice$en {
	_Translations$chase$notice$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => 'Nové ${program}';
	@override String newRefGuess({required Object program}) => 'Pravděpodobně nové ${program}';
	@override String newBand({required Object program}) => 'Nové pásmo ${program}';
	@override String newBandGuess({required Object program}) => 'Pravděpodobně nové pásmo ${program}';
	@override String newMode({required Object program}) => 'Nový mód ${program}';
	@override String newModeGuess({required Object program}) => 'Pravděpodobně nový mód ${program}';
	@override String unconfirmed({required Object program}) => '${program} nepotvrzeno';
	@override String programGuess({required Object notice}) => 'Pravděpodobně ${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$cs extends Translations$chase$alerts$en {
	_Translations$chase$alerts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Upozornění';
	@override String get newRef => 'Nová reference';
	@override String get newBand => 'Nové pásmo';
	@override String get newMode => 'Nový mód';
	@override String get unconfirmed => 'Nepotvrzeno';
}

// Path: chase.imports
class _Translations$chase$imports$cs extends Translations$chase$imports$en {
	_Translations$chase$imports$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => 'Importovat ${label}';
	@override String pickTitle({required Object file}) => 'Importovat ${file} jako';
	@override String get dropHint => 'Přetáhněte sem soubor a importujte ho do programu k lovení';
	@override String done({required Object count, required Object program, required Object file}) => 'Importováno ${count} položek ${program} ze souboru ${file}';
	@override String doneSkipped({required Object count, required Object program, required Object file, required Object skipped}) => 'Importováno ${count} položek ${program} ze souboru ${file}, přeskočeno ${skipped} nečitelných';
	@override String nothing({required Object file, required Object program}) => '${file} neobsahuje nic, co by šlo importovat do ${program}';
	@override String failed({required Object file, required Object program}) => '${file} se pro ${program} nepodařilo přečíst';
	@override String unreadable({required Object skipped, required Object file, required Object program}) => 'Žádný z ${skipped} záznamů v ${file} se pro ${program} nepodařilo přečíst';
	@override String noProgram({required Object file}) => 'Žádný program k lovení neimportuje ${file}';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$cs extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vyhledat online?';
	@override String get body => 'Asistence je pro tuto aktivitu vypnutá. Vyhledání všech QSO tentokrát jednorázově použije online služby jako QRZ.';
	@override String bodyRules({required Object rules}) => 'Asistence je pro tuto aktivitu vypnutá kvůli souladu s pravidly ${rules}. Vyhledání všech QSO tentokrát jednorázově použije online služby jako QRZ.';
	@override String get action => 'Vyhledat online';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$cs extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Neplatná volací značka: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Neplatné volací značky: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Dosud vysílal ${previous}. Pro nová spojení bude zaznamenán ${typed}.';
	@override String operatorNoneSoFar({required Object typed}) => 'Dosud nebyl zaznamenán žádný operátor. Pro nová spojení bude zaznamenán ${typed}.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Tato aktivita už má spojení od ${calls}. ${typed} bude zaznamenán jen pro nová spojení.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Zaznamenat ${typed} jako operátora i u již zalogovaného spojení',
		other: 'Zaznamenat ${typed} jako operátora i u všech ${count} již zalogovaných spojení',
	);
	@override String get operatorSeveralStations => 'Při vysílání z více stanic nejsou samostatní operátoři podporováni';
	@override String get contactsUnreadable => 'Spojení této aktivity nelze přečíst, proto změna značky zde nenabídne jejich aktualizaci';
	@override String restampFailed({required Object error}) => 'Již zalogovaná spojení nelze aktualizovat, proto nebyly provedeny žádné změny: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => 'Aktualizováno ${written} z ${planned} spojení — ostatní už v této aktivitě nejsou';
}

// Path: operation.tabs
class _Translations$operation$tabs$cs extends Translations$operation$tabs$en {
	_Translations$operation$tabs$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTY';
	@override String get map => 'MAPA';
	@override String get qsosPlain => 'QSO';
	@override String get clock => 'Hodiny';
	@override String get weather => 'Počasí';
	@override String get website => 'Web';
	@override String get remoteScreen => 'Vzdálená obrazovka';
	@override String get solar => 'Sluneční aktivita';
	@override String get radio => 'Rádio';
	@override String get rotator => 'Rotátor';
	@override String get summaries => 'Souhrny aktivity';
}

// Path: operation.positions
class _Translations$operation$positions$cs extends Translations$operation$positions$en {
	_Translations$operation$positions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Tuto aktivitu zatím nesdílí žádná další operátorská pracoviště.';
	@override String positionLabel({required Object number}) => 'Prac.: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Jiné pracoviště';
	@override String get thisDevice => 'Naše pracoviště';
	@override String get nameIn => ' v ';
	@override String get panelTitle => 'Pracoviště';
	@override String get panelDescription => 'Co právě loguje každé pracoviště, které sdílí tuto aktivitu.';
}

// Path: operation.menu
class _Translations$operation$menu$cs extends Translations$operation$menu$en {
	_Translations$operation$menu$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Zobrazit pole RST';
	@override String get showStateField => 'Zobrazit pole Stát';
	@override String get showGridField => 'Zobrazit pole Lokátor';
	@override String get showDeletedQsos => 'Zobrazit smazaná QSO';
	@override String get showDeletedOps => 'Zobrazit smazané aktivity';
	@override String get showQsoNumbers => 'Zobrazit čísla QSO';
	@override String get lookupAllQsos => 'Vyhledat všechna QSO';
	@override String get loggingSettingsTitle => 'Nastavení logování';
	@override String get mapSettingsTitle => 'Nastavení mapy';
	@override String get actionsSection => 'Akce';
}

// Path: operation.layout
class _Translations$operation$layout$cs extends Translations$operation$layout$en {
	_Translations$operation$layout$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Přidat panel';
	@override String get availableSection => 'Dostupné panely';
	@override String panelSettings({required Object panel}) => 'Nastavení panelu ${panel}';
	@override String get panelSettingsAction => 'Nastavení panelu';
	@override String get viewName => 'Zobrazení aktivity';
	@override String get viewOptions => 'Možnosti rozložení zobrazení';
	@override String get viewTitleBuiltIn => 'Toto zobrazení je součástí aplikace, stejně jako jeho název';
	@override String get resetOptions => 'Obnovit výchozí';
	@override String get removePane => 'Odebrat';
	@override String resetPaneConfirm({required Object panel}) => 'Obnovit výchozí nastavení panelu ${panel}?';
	@override String get resetPaneConfirmBody => 'Jeho název, záhlaví a velikost se vrátí na výchozí. Zbytek rozložení zůstane beze změny.';
	@override String get resetViewConfirm => 'Obnovit výchozí rozložení tohoto zobrazení?';
	@override String get resetViewConfirmBody => 'Panely se vrátí do výchozího uspořádání a možnosti zobrazení i všech panelů se vrátí na výchozí.';
	@override String paneOptionsTitle({required Object panel}) => 'Nastavení rozložení ${panel}';
	@override String get paneTitle => 'Název';
	@override String get paneShowHeader => 'Zobrazit záhlaví';
	@override String get paneShowHeaderTabset => 'Zobrazeno vždy, když panel sdílí skupinu — přes záhlaví se dostanete k ostatním';
	@override String get paneInherit => 'Stejně jako aplikace';
	@override String get searchHint => 'Hledat panely';
	@override String get noPanelsMatch => 'Žádný panel neodpovídá hledání.';
	@override String get nothingToAdd => 'Toto zobrazení už obsahuje všechny možné panely';
	@override String addPanel({required Object panel}) => 'Přidat ${panel}';
	@override String showPreview({required Object panel}) => 'Náhled ${panel}';
	@override String missingExtension({required Object name}) => 'Chybí rozšíření "${name}"';
	@override String get missingExtensionEnable => 'Zapnout';
	@override String get missingExtensionInstall => 'Instalovat…';
	@override String get missingExtensionWontRun => 'Tato verze se nespustí. Aktualizujte ji v Nastavení › Rozšíření.';
	@override String get missingExtensionUnavailable => 'V této aplikaci není k dispozici';
	@override String get missingExtensionNotInCatalog => 'Není v katalogu';
	@override String get missingExtensionCatalogUnreachable => 'Katalog je nedostupný. Zkuste to znovu';
	@override String get missingExtensionFailed => 'Nepovedlo se. Zkuste to znovu';
	@override String get previewUnavailable => 'Náhled tohoto panelu nelze zobrazit.';
	@override String get nestedPaneTitle => 'Více';
	@override late final _Translations$operation$layout$layouts$cs layouts = _Translations$operation$layout$layouts$cs._(_root);
	@override String get editLayout => 'Upravit rozložení';
	@override String get saveLayout => 'Uložit rozložení';
	@override String get revertLayout => 'Zahodit změny rozložení';
	@override String get done => 'Hotovo';
	@override String get layoutUnreadableTitle => 'Rozložení nelze přečíst';
	@override String get layoutUnreadableBody => 'Vaše uložené rozložení nelze přečíst, proto se zobrazuje výchozí uspořádání. Původní rozložení nebude přepsáno, dokud se nerozhodnete toto ponechat.';
	@override String get layoutUnreadableAction => 'Použít toto rozložení';
	@override String panelRenderFailed({required Object panel}) => '${panel} nelze zobrazit';
	@override String panelOverCharacters({required Object panel, required Object max}) => '${panel} nelze zobrazit: odeslal více než ${max} znaků';
	@override String panelOverElements({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho grafika má více než ${max} prvků';
	@override String panelOverDepth({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho grafika je vnořená do více než ${max} úrovní';
	@override String panelNotArtwork({required Object panel}) => '${panel} nelze zobrazit: jeho grafika není samostatný celek';
	@override String panelOverLayers({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho scéna má více než ${max} vrstev';
	@override String panelOverControls({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho scéna má více než ${max} ovládacích prvků';
	@override String panelOverItems({required Object panel, required Object max}) => '${panel} nelze zobrazit: část jeho scény má více než ${max} položek';
	@override String panelOverStringLength({required Object panel, required Object max}) => '${panel} nelze zobrazit: řetězec ve scéně je delší než ${max} znaků';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho rozložení je vnořené do více než ${max} úrovní';
	@override String get panelRenderRetry => 'Zkusit znovu';
	@override String get panelActionFailed => 'Akce panelu selhala. Zkuste to znovu.';
	@override late final _Translations$operation$layout$panels$cs panels = _Translations$operation$layout$panels$cs._(_root);
	@override String get htmlPanelUnsupported => 'Tento panel potřebuje webové zobrazení, které tato platforma neposkytuje';
	@override String get htmlPanelUnsupportedOnWeb => 'Tento panel potřebuje izolované prostředí, které webová verze nemůže poskytnout';
}

// Path: operation.export
class _Translations$operation$export$cs extends Translations$operation$export$en {
	_Translations$operation$export$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporty aktivity';
	@override String get syncedOperation => 'Aktivita je synchronizována';
	@override String get unsyncedOperation => 'Aktivita má nesynchronizované změny';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} QSO v této aktivitě',
		other: '${count} QSO v této aktivitě',
	);
	@override String qsosSynced({required Object total}) => 'Všech ${total} QSO je synchronizováno';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} z ${total} QSO čeká na synchronizaci';
	@override String eventsSynced({required Object total}) => 'Synchronizováno ${total} značek událostí';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} z ${total} značek událostí čeká';
	@override String get loading => 'Načítání možností exportu…';
	@override String get noOptions => 'Nejsou k dispozici žádné formáty exportu (rozšíření se ještě spouštějí?)';
	@override String get nothingLogged => 'Zatím není co exportovat — tato aktivita nemá žádná QSO.';
	@override String get share => 'Sdílet';
	@override String get nothingSelected => 'Nic není vybráno';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Uložit ${count} soubor',
		other: 'Uložit ${count} souborů',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Sdílet ${count} soubor',
		other: 'Sdílet ${count} souborů',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Exportovat ${count} soubor',
		other: 'Exportovat ${count} souborů',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Stáhnout ${count} soubor',
		other: 'Stáhnout ${count} souborů',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Uložit ${count} sloučený soubor',
		other: 'Uložit ${count} sloučených souborů',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Sdílet ${count} sloučený soubor',
		other: 'Sdílet ${count} sloučených souborů',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Exportovat ${count} sloučený soubor',
		other: 'Exportovat ${count} sloučených souborů',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Stáhnout ${count} sloučený soubor',
		other: 'Stáhnout ${count} sloučených souborů',
	);
	@override String saveOne({required Object name}) => 'Uložit ${name}';
	@override String shareOne({required Object name}) => 'Sdílet ${name}';
	@override String exportOne({required Object name}) => 'Exportovat ${name}';
	@override String downloadOne({required Object name}) => 'Stáhnout ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Uschovat ${count} soubor',
		other: 'Uschovat ${count} souborů',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Uschovat ${count} sloučený soubor',
		other: 'Uschovat ${count} sloučených souborů',
	);
	@override String get settingsButton => 'Nastavení exportu';
	@override String get settingsTitle => 'Nastavení exportu';
	@override late final _Translations$operation$export$compactFileNames$cs compactFileNames = _Translations$operation$export$compactFileNames$cs._(_root);
	@override late final _Translations$operation$export$includePrivateData$cs includePrivateData = _Translations$operation$export$includePrivateData$cs._(_root);
	@override String get resultTitle => 'Export dokončen';
	@override String get resultFailedTitle => 'Export selhal';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Exportován ${count} soubor do ${path}',
		other: 'Exportováno ${count} souborů do ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Exportován ${count} soubor: ${path}',
		other: 'Exportováno ${count} souborů: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Sdílen ${count} soubor',
		other: 'Sdíleno ${count} souborů',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Stažen ${count} soubor',
		other: 'Staženo ${count} souborů',
	);
	@override String exportFailed({required Object error}) => 'Export selhal: ${error}';
	@override late final _Translations$operation$export$stash$cs stash = _Translations$operation$export$stash$cs._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$cs extends Translations$operation$spots$en {
	_Translations$operation$spots$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Vašim filtrům neodpovídají žádné spoty';
	@override String error({required Object error}) => 'Načtení spotů selhalo: ${error}';
	@override String get unknownBand => 'Jiné';
	@override String get auto => 'Automaticky';
	@override String autoValue({required Object value}) => 'Automaticky (nyní ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Libovolné';
	@override String get allBands => 'Všechna pásma';
	@override String get allModes => 'Všechny módy';
	@override String get phoneAndCw => 'Fónie a CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} spot',
		other: '${count} spotů',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Zobrazeno ${count} z ${total} spotů';
	@override String get spotsDisabled => 'Spoty jsou pro tuto aktivitu vypnuté';
	@override String ageMinutes({required Object minutes}) => '${minutes} minut';
	@override String get callsOfNote => 'Zajímavé značky';
	@override String get yourSpots => 'Vaše spoty';
	@override String get allSpots => 'Všechny spoty';
	@override late final _Translations$operation$spots$continents$cs continents = _Translations$operation$spots$continents$cs._(_root);
	@override late final _Translations$operation$spots$filters$cs filters = _Translations$operation$spots$filters$cs._(_root);
	@override String get unavailableTitle => 'Spoty nejsou k dispozici';
	@override String unavailableText({required Object sources}) => 'Bez odpovědi od ${sources}.';
	@override String get failedTitle => 'Chyba zdroje spotů';
	@override String failedText({required Object sources}) => 'Chyba od ${sources}.';
	@override String get slideLogIt => 'Zalogovat';
	@override String get slideIgnore => 'Ignorovat';
	@override String get slideRestore => 'Obnovit';
	@override late final _Translations$operation$spots$logConflict$cs logConflict = _Translations$operation$spots$logConflict$cs._(_root);
}

// Path: operation.import
class _Translations$operation$import$cs extends Translations$operation$import$en {
	_Translations$operation$import$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Import dat do aktivity';
	@override String get importAdifAction => 'Importovat QSO z ADIF';
	@override String get settingsButton => 'Nastavení naslouchání';
	@override String get settingsTitle => 'Naslouchat jiným aplikacím';
	@override String get protocolAddressLabel => 'Adresa';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Zadejte port mezi 1 a 65535';
	@override String get protocolAddressInvalid => 'Zadejte platnou IP adresu (např. 127.0.0.1 nebo 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Data se přijímají';
	@override String get protocolStatusNoData => 'V poslední době nepřišla žádná data';
	@override String protocolBindError({required Object error}) => 'Naslouchání nelze spustit: ${error}';
	@override String captureFailed({required Object error}) => 'Příchozí QSO nelze uložit, ukládání se opakuje: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Libovolná (broadcast)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → karta Broadcast Data → zaškrtněte "Enable Broadcasts" pro informace o spojeních. Nastavte IP adresu na 127.0.0.1, pokud běží na tomto počítači, nebo na 255.255.255.255 pro vysílání do aktuální místní sítě.';
	@override String get helpWsjtxSetup => 'File → Settings → karta Reporting → sekce UDP Server → zaškrtněte "Accept UDP requests". Nastavte UDP Server na 127.0.0.1, pokud běží na tomto počítači, nebo na multicastovou adresu, např. 239.239.0.2, a stejnou adresu použijte ve výše uvedené konfiguraci této aplikace.';
	@override String get listenTitle => 'Naslouchat QSO z jiných aplikací';
	@override String get listenDescriptionOnN1mm => 'Naslouchá se N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Naslouchá se WSJT-X';
	@override String get listenDescriptionOnBoth => 'Naslouchá se N1MM+ a WSJT-X';
	@override String get listenDescriptionOff => 'Vypnuto';
	@override String get addToOperationTitle => 'Přidávat do této aktivity';
	@override String get addToOperationDescriptionOn => 'Zachycená QSO se přidávají do této aktivity, jakmile dorazí';
	@override String get addToOperationDescriptionOff => 'Zachycená QSO se drží, dokud toto nezapnete';
	@override String get pendingSectionTitle => 'Zachycená QSO';
	@override String get pendingEmpty => 'Zatím nic nezachyceno';
	@override String stationMismatch({required Object call}) => 'Zalogováno jako ${call}, ne jako stanice této aktivity';
	@override String get discardAction => 'Zahodit';
	@override String get gapDialogTitle => 'Zahrnout dřívější záznamy?';
	@override String gapDialogBody({required Object count}) => 'Dříve, před výpadkem dat, bylo zachyceno ještě ${count} QSO. Zahrnout i je?';
	@override String get gapDialogRecentOnly => 'Jen ty nedávné';
	@override String gapDialogIncludeAll({required Object count}) => 'Zahrnout všech ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$cs extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problémy?';
	@override String get title => 'Nahlásit problém s obrysem';
	@override String get reference => 'Který obrys';
	@override String get severity => 'Jak vážné to je?';
	@override String get minor => 'Drobnost';
	@override String get major => 'Velký problém';
	@override String get explanation => 'Co je na něm špatně?';
	@override String get explanationHint => 'Co obrys zachycuje špatně a kde';
	@override String get send => 'Odeslat';
	@override String get sending => 'Odesílání hlášení — děkujeme';
	@override String get copy => 'Kopírovat hlášení';
	@override String get notSent => 'Hlášení se nepodařilo odeslat';
	@override String get copied => 'Hlášení zkopírováno';
	@override String get notCopied => 'Hlášení se nepodařilo zkopírovat';
}

// Path: map.postcard
class _Translations$map$postcard$cs extends Translations$map$postcard$en {
	_Translations$map$postcard$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get button => 'Pohlednice aktivity';
	@override String title({required Object title}) => 'Pohlednice pro ${title}';
	@override String get portrait => 'Na výšku';
	@override String get landscape => 'Na šířku';
	@override String get square => 'Čtverec';
	@override String get save => 'Uložit…';
	@override String get download => 'Stáhnout';
	@override String get share => 'Sdílet';
	@override String get copy => 'Kopírovat';
	@override String get copied => 'Zkopírováno do schránky';
	@override String saved({required Object path}) => 'Uloženo do ${path}';
	@override String downloaded({required Object name}) => 'Staženo ${name}';
	@override String savedMany({required Object count, required Object path}) => 'Uloženo ${count} obrázků do ${path}';
	@override String savedFiles({required Object names}) => 'Uloženo ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} už bylo uloženo';
	@override String downloadedMany({required Object count}) => 'Stahování ${count} obrázků — pokud se prohlížeč zeptá, povolte to';
	@override String get mapLeftOut => 'Mapa se nenačetla, proto byla vynechána';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — mapa se nenačetla, proto byla vynechána';
	@override String continued({required Object title}) => '${title} (pokračování)';
	@override String get previousPage => 'Předchozí strana';
	@override String get nextPage => 'Další strana';
	@override String pageOf({required Object page, required Object count}) => 'Strana ${page} z ${count}';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} Q',
		other: '${count} Q',
	);
	@override String get options => 'Možnosti pohlednice';
	@override String get bandLegend => 'Zobrazit legendu pásem';
	@override String get grayline => 'Zobrazit šedou linii';
	@override String get sectionsAndOrder => 'Sekce souhrnu a pořadí';
	@override String get sectionDays => 'Každý den';
	@override String get reset => 'Obnovit výchozí';
	@override String failed({required Object error}) => 'Pohlednici nelze vytvořit: ${error}';
	@override String get mapNotReady => 'Mapa se nedonačetla. Zkontrolujte připojení a zkuste to znovu.';
	@override String saveFailed({required Object error}) => 'Pohlednici nelze uložit: ${error}';
	@override String get copyFailed => 'Schránka obrázek nepřijala. Zkuste to znovu.';
	@override String get shareFailed => 'Pohlednici nelze sdílet. Zkuste to znovu.';
	@override String get fileName => 'pohlednice';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$cs extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Zatím žádná QSO… Vzhůru do éteru!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object count, required Object time}) => '${count} za ${time}';
	@override String sinceLast({required Object time}) => '${time} od posledního';
	@override String ratePer10({required Object rate}) => '${rate} Q/h za posledních 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h za posledních 100';
	@override String distanceTo({required Object distance}) => '${distance} k';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) k';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) k';
	@override String distanceAway({required Object distance}) => '${distance} daleko';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) daleko';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) daleko';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplicita!';
	@override String get noticeNewBand => 'Nové pásmo';
	@override String get noticeNewMode => 'Nový mód';
	@override String get noticeNewDXCC => 'Nové DXCC';
	@override String get noticeNewState => 'Nový stát';
	@override String get noticeNewProvince => 'Nová provincie';
	@override String get noticeNewDay => 'Nový den';
	@override String get noticeNewRef => 'Nová ref.';
	@override String get noticeNewMult => 'Nový násobič';
	@override String get noticeNewZone => 'Nová zóna';
	@override String get noticeInvalidMode => 'Špatný mód';
	@override String get noticeInvalidBand => 'Špatné pásmo';
	@override String get noticeInvalidCategory => 'Nelze navázat';
	@override String get noticeOverTime => 'Mimo čas';
	@override String get noticeWorkedBefore => 'Už v logu';
	@override String get noticeNewPark => 'Nový park';
	@override String get noticeNewSection => 'Nová sekce';
	@override String get noticeBonusStation => 'Bonusová stanice!';
	@override String get noticeMissingExchange => 'Chybí výměna';
	@override String get noticeInvalidExchange => 'Chybná výměna';
	@override String get noticeUnknownEvent => 'Neznámá událost';
	@override String get noticeIncompleteCall => 'Neúplná značka — nebodováno';
	@override String get noticeOurGrid => 'Nastavte náš lokátor';
	@override String get noticeRareCounty => 'Vzácný okres!';
	@override String get noticeOurLocation => 'Nastavte náš okres';
	@override String get noticeShortGrid => 'Krátký lokátor';
}

// Path: qsoList.find
class _Translations$qsoList$find$cs extends Translations$qsoList$find$en {
	_Translations$qsoList$find$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'Najít v logu (${shortcut})';
	@override String get menuItemNoShortcut => 'Najít v logu';
	@override String get hint => 'Číslo QSO nebo značka';
	@override String get noMatches => 'Žádná shoda';
	@override String get noOperationQsos => 'Žádná QSO v této aktivitě';
	@override String get noPeriodQsos => 'Žádná QSO v tomto období';
	@override String get outsideQsosOne => '1 QSO mimo tuto aktivitu';
	@override String outsideQsosOther({required Object count}) => '${count} QSO mimo tuto aktivitu';
	@override String get pastQsosOne => '1 dřívější QSO';
	@override String pastQsosOther({required Object count}) => '${count} dřívějších QSO';
}

// Path: callInfo.history
class _Translations$callInfo$history$cs extends Translations$callInfo$history$en {
	_Translations$callInfo$history$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} za posledních 7 dní';
	@override String today({required Object n}) => '${n} dnes';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$cs extends Translations$settings$theme$en {
	_Translations$settings$theme$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Téma';
	@override String get system => 'Podle nastavení systému';
	@override String get light => 'Světlý';
	@override String get dark => 'Tmavý';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$cs extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get system => 'Podle nastavení systému';
	@override String get light => 'Vždy ve světlém režimu';
	@override String get dark => 'Vždy v tmavém režimu';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$cs extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Nejmenší--';
	@override String get smallestMinus => 'Nejmenší-';
	@override String get smallest => 'Nejmenší';
	@override String get smaller => 'Menší';
	@override String get normal => 'Normální';
	@override String get larger => 'Větší';
	@override String get largest => 'Největší';
	@override String get largestPlus => 'Největší+';
	@override String get largestPlusPlus => 'Největší++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$cs extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Udržovat zařízení aktivní';
	@override String get descriptionOn => 'Zůstává aktivní, když jste v zobrazení logování nebo probíhá synchronizace';
	@override String get descriptionOff => 'Usíná jako obvykle';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$cs extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automaticky';
	@override String get densest => 'Nejhustší';
	@override String get dense => 'Hustá';
	@override String get normal => 'Normální';
	@override String get sparse => 'Řídká';
	@override String get sparsest => 'Nejřidší';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$cs extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometry';
	@override String get miles => 'Míle';
}

// Path: settings.logging
class _Translations$settings$logging$cs extends Translations$settings$logging$en {
	_Translations$settings$logging$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logování';
	@override late final _Translations$settings$logging$leftieMode$cs leftieMode = _Translations$settings$logging$leftieMode$cs._(_root);
	@override late final _Translations$settings$logging$countryFlags$cs countryFlags = _Translations$settings$logging$countryFlags$cs._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$cs countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$cs._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$cs suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$cs._(_root);
	@override late final _Translations$settings$logging$showBearing$cs showBearing = _Translations$settings$logging$showBearing$cs._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$cs showReverseBearing = _Translations$settings$logging$showReverseBearing$cs._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$cs switchSentRcvd = _Translations$settings$logging$switchSentRcvd$cs._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$cs jumpAfterRST = _Translations$settings$logging$jumpAfterRST$cs._(_root);
	@override late final _Translations$settings$logging$defaultReport$cs defaultReport = _Translations$settings$logging$defaultReport$cs._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$cs defaultReportCW = _Translations$settings$logging$defaultReportCW$cs._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$cs defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$cs._(_root);
	@override late final _Translations$settings$logging$numbersRow$cs numbersRow = _Translations$settings$logging$numbersRow$cs._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$cs numbersRowExtra = _Translations$settings$logging$numbersRowExtra$cs._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$cs numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$cs._(_root);
	@override String get bands => 'Preferovaná pásma';
	@override String get modes => 'Preferované módy';
}

// Path: settings.catServer
class _Translations$settings$catServer$cs extends Translations$settings$catServer$en {
	_Translations$settings$catServer$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT server';
	@override String get description => 'Umožní jiným aplikacím (WSJT-X, deníky atd.) ovládat rádio přes Ham2K Logger.';
	@override String get protocol => 'Protokol';
	@override late final _Translations$settings$catServer$protocolOpts$cs protocolOpts = _Translations$settings$catServer$protocolOpts$cs._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Otevřený přístup';
	@override String get openAccessOn => 'Připojit se může libovolný počítač v místní síti.';
	@override String get openAccessOff => 'Připojit se mohou pouze aplikace na tomto počítači.';
	@override String get allowTransmit => 'Povolit aplikacím vysílat';
	@override String allowTransmitOn({required Object minutes}) => 'Aplikace mohou klíčovat PTT rádia, vždy nejvýše ${minutes} minut v kuse.';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'Aplikace na libovolném počítači v místní síti mohou klíčovat PTT rádia, vždy nejvýše ${minutes} minut v kuse.';
	@override String get allowTransmitOff => 'Aplikace nemohou rádio klíčovat. Použijte VOX nebo jejich vlastní nastavení PTT.';
	@override String get allowTransmitUnsupported => 'Rádio hlavního VFO nelze z aplikace Ham2K Logger klíčovat, aplikace přes něj tedy nemohou vysílat.';
	@override String get off => 'Vypnuto.';
	@override String starting({required Object protocol}) => '${protocol}, spouštění…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} na portu ${port}. Připojení klienti: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} na portu ${port}, ale není připojeno žádné rádio hlavního VFO.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} nemůže naslouchat na portu ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} nemůže naslouchat na portu ${port}: používá ho jiný program, často samotný ${protocol}. Zavřete ten program nebo zvolte jiný port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} nemůže naslouchat na portu ${port}: tento počítač to nepovoluje. Zvolte port nad 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} přestal naslouchat na portu ${port}. Zkouší se znovu…';
}

// Path: settings.cluster
class _Translations$settings$cluster$cs extends Translations$settings$cluster$en {
	_Translations$settings$cluster$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'DX cluster';
	@override String get description => 'Server, na který rozšíření posílají spoty a ze kterého je čtou, přihlášená jako operátor.';
	@override String get connect => 'Připojovat se ke clusteru';
	@override String get connectOn => 'Rozšíření se ke clusteru připojí, když ho potřebují';
	@override String get connectOff => 'Ke clusteru se nic nepřipojuje';
	@override String get console => 'Zobrazit konzoli';
	@override String get consoleDescription => 'Co cluster posílá, a místo pro zadávání příkazů';
	@override String get consoleTitle => 'Konzole clusteru';
	@override String get consoleConnect => 'Připojit';
	@override String get consoleDisconnect => 'Odpojit';
	@override String get consoleCommand => 'Příkaz';
	@override String get consoleEmpty => 'Zatím nic. Připojte se, nebo počkejte, až cluster použije některé rozšíření.';
	@override String consoleRetry({required Object command}) => 'Odesílá se znovu: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => 'Neodesláno: ${command} (${reason})';
	@override String get server => 'Server clusteru';
	@override String get selectServer => 'Vybrat server';
	@override String get serverOther => 'Jiný';
	@override String serverOtherIncomplete({required Object node}) => 'Zatím není zadán žádný server, spoty tedy jdou na ${node}';
	@override String get customHost => 'Server';
	@override String get customPort => 'Port';
	@override String get password => 'Heslo';
	@override String get passwordDescription => 'Jen pokud je potřeba';
	@override String passwordStored({required Object node}) => 'Heslo pro ${node} je uloženo';
	@override String get scrollback => 'Uchovávané řádky';
	@override String scrollbackOpt({required Object count}) => '${count} řádků';
	@override String get connection => 'Připojení';
	@override String get statusIdle => 'Nepřipojeno. Připojí se, když to některé rozšíření potřebuje. Klepnutím otestujete.';
	@override String statusConnecting({required Object node}) => 'Připojování k ${node}…';
	@override String statusConnected({required Object node, required Object call}) => 'Připojeno k ${node} jako ${call}.';
	@override String statusFailed({required Object node, required Object reason}) => 'K ${node} se nelze připojit: ${reason}';
	@override String get statusUnsupported => 'Ve webové verzi není k dispozici.';
	@override String get statusOff => 'Vypnuto. Chcete-li ho používat, zapněte Připojovat se ke clusteru.';
	@override late final _Translations$settings$cluster$errors$cs errors = _Translations$settings$cluster$errors$cs._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$cs extends Translations$settings$spotting$en {
	_Translations$settings$spotting$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotování';
	@override String get respotInterval => 'Automatický respot každých';
	@override String minutes({required Object minutes}) => '${minutes} min';
	@override String get autoRespotByDefault => 'Automatický respot ve výchozím stavu';
	@override String get autoRespotByDefaultOn => 'Zapnout automatický respot po každém odeslaném spotu';
	@override String get autoRespotByDefaultOff => 'Automatický respot se zapíná jen ručně';
	@override String get pulseBeforeRespot => 'Pulzovat před každým automatickým respotem';
	@override String pulseBeforeRespotOn({required Object seconds}) => 'Štítek Spotování pulzuje modře ${seconds} sekund před každým respotem';
	@override String get pulseBeforeRespotOff => 'Před automatickým respotem se nepulzuje';
}

// Path: settings.radio
class _Translations$settings$radio$cs extends Translations$settings$radio$en {
	_Translations$settings$radio$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ovládání CAT';
	@override String get loggingAndCat => 'Logování a CAT';
	@override String get tuningSection => 'Ladění';
	@override String get keyerSection => 'Klíčovač';
	@override String get servicesSection => 'Služby';
	@override String get stationConfigurationSection => 'Konfigurace stanice';
	@override String get moreSettings => 'Další nastavení konfigurace stanice';
	@override late final _Translations$settings$radio$units$cs units = _Translations$settings$radio$units$cs._(_root);
	@override late final _Translations$settings$radio$pttKey$cs pttKey = _Translations$settings$radio$pttKey$cs._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$cs smartVfoSnap = _Translations$settings$radio$smartVfoSnap$cs._(_root);
	@override late final _Translations$settings$radio$snapDebounce$cs snapDebounce = _Translations$settings$radio$snapDebounce$cs._(_root);
	@override late final _Translations$settings$radio$snapLongMove$cs snapLongMove = _Translations$settings$radio$snapLongMove$cs._(_root);
	@override late final _Translations$settings$radio$snapMinMove$cs snapMinMove = _Translations$settings$radio$snapMinMove$cs._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$cs snapMinSpeed = _Translations$settings$radio$snapMinSpeed$cs._(_root);
	@override late final _Translations$settings$radio$enterSends$cs enterSends = _Translations$settings$radio$enterSends$cs._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$cs keyerSpeed = _Translations$settings$radio$keyerSpeed$cs._(_root);
	@override late final _Translations$settings$radio$cwMessages$cs cwMessages = _Translations$settings$radio$cwMessages$cs._(_root);
	@override late final _Translations$settings$radio$keyerControl$cs keyerControl = _Translations$settings$radio$keyerControl$cs._(_root);
	@override late final _Translations$settings$radio$voiceMessages$cs voiceMessages = _Translations$settings$radio$voiceMessages$cs._(_root);
	@override late final _Translations$settings$radio$voiceWords$cs voiceWords = _Translations$settings$radio$voiceWords$cs._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$cs avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$cs._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$cs zeroBeatRange = _Translations$settings$radio$zeroBeatRange$cs._(_root);
}

// Path: settings.help
class _Translations$settings$help$cs extends Translations$settings$help$en {
	_Translations$settings$help$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nápověda a zdroje';
	@override String get description => 'Komunita a podpora';
	@override String get forums => 'Ham2K Fóra';
	@override String get forumsDescription => 'Najděte pomoc, dejte zpětnou vazbu, diskutujte o nápadech…';
	@override String get chat => 'Ham2K Chat';
	@override String get chatDescription => 'Discord server pro naši online komunitu';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videa a živé vysílání';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Protože fotografií nikdy není dost…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Sledujte nás pro novinky a aktualizace';
	@override String get contact => 'Kontaktujte nás';
	@override String get contactDescription => 'help@ham2k.com — ale nejprve zkuste Fóra nebo Chat!';
}

// Path: settings.exports
class _Translations$settings$exports$cs extends Translations$settings$exports$en {
	_Translations$settings$exports$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exporty';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$cs extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get activities => 'Aktivity';
	@override String get hunting => 'Lovení';
	@override String get contests => 'Závody';
	@override String get lookups => 'Vyhledávání';
	@override String get dashboard => 'Přehled';
}

// Path: settings.map
class _Translations$settings$map$cs extends Translations$settings$map$en {
	_Translations$settings$map$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapy';
	@override late final _Translations$settings$map$style$cs style = _Translations$settings$map$style$cs._(_root);
	@override late final _Translations$settings$map$showCallsigns$cs showCallsigns = _Translations$settings$map$showCallsigns$cs._(_root);
	@override late final _Translations$settings$map$showGrayline$cs showGrayline = _Translations$settings$map$showGrayline$cs._(_root);
	@override late final _Translations$settings$map$styleOpts$cs styleOpts = _Translations$settings$map$styleOpts$cs._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$cs extends Translations$settings$privacy$en {
	_Translations$settings$privacy$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Soukromí';
	@override late final _Translations$settings$privacy$shareAppData$cs shareAppData = _Translations$settings$privacy$shareAppData$cs._(_root);
	@override late final _Translations$settings$privacy$shareOpData$cs shareOpData = _Translations$settings$privacy$shareOpData$cs._(_root);
	@override String get privacyPolicy => 'Zásady ochrany osobních údajů';
	@override String get termsOfService => 'Podmínky používání služby';
}

// Path: settings.sync
class _Translations$settings$sync$cs extends Translations$settings$sync$en {
	_Translations$settings$sync$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Synchronizace v cloudu';
	@override String get moreSettings => 'Další nastavení synchronizace';
	@override String get enable => 'Zapnout synchronizaci';
	@override String get deviceKey => 'Klíč zařízení';
}

// Path: settings.peers
class _Translations$settings$peers$cs extends Translations$settings$peers$en {
	_Translations$settings$peers$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spárovaná zařízení';
	@override String get enable => 'Připojovat se k jiným zařízením';
	@override String get enableDescription => 'Povolit sdílení aktivit, logování, CAT a GPS s jinými zařízeními v místní síti';
	@override String get bleEnable => 'Připojit přes Bluetooth';
	@override String get bleDescription => 'Použít Bluetooth LE k připojení i bez místní sítě';
	@override String get thisDevice => 'Toto zařízení';
	@override String get deviceName => 'Název';
	@override String get deviceNameHint => 'Jak toto zařízení vidí ostatní zařízení';
	@override String get pairedDevices => 'Propojená zařízení';
	@override String get noPairedDevices => 'Zatím žádná propojená zařízení. Pro propojení zapněte tuto volbu na jiném zařízení v této síti.';
	@override String deviceListProblem({required Object error}) => 'Propojená zařízení nelze načíst: ${error}';
	@override String get nearby => 'V okolí';
	@override String get connected => 'Připojeno';
	@override String get viaBluetooth => 'přes Bluetooth';
	@override String get connecting => 'Připojování…';
	@override String get syncing => 'Synchronizace…';
	@override String get waitingForThem => 'Čeká se na druhé zařízení';
	@override String get notConnected => 'Nepřipojeno';
	@override String get wantsToPair => 'chce sdílet tuto aktivitu';
	@override String get allow => 'Povolit';
	@override String get link => 'Propojit';
	@override String get reject => 'Odmítnout';
	@override String get forget => 'Zapomenout';
	@override String forgetTitle({required Object name}) => 'Zapomenout ${name}?';
	@override String get forgetBody => 'Přestane se synchronizovat s tímto zařízením. Později ho můžete znovu povolit a již zalogovaná spojení zůstanou zachována.';
	@override String pairTitle({required Object name}) => 'Propojit s ${name}';
	@override String get pairBody => 'Toto zařízení je ve vaší místní síti a chce se připojit.';
	@override String get pairBodyBle => 'Toto zařízení je v okolí a chce se připojit přes Bluetooth LE.';
	@override String get pairIdLabel => 'ID zařízení';
	@override String get pairWarning => 'Propojujte jen se zařízeními, která znáte. Žádost může poslat jakékoli zařízení v této síti.';
	@override String get pairWarningBle => 'Propojujte jen se zařízeními, která znáte. Žádost může poslat jakékoli zařízení v okolí.';
	@override String problem({required Object error}) => 'Místní síť je nedostupná: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Připojeno k ${device}';
	@override String statusLost({required Object device}) => 'Ztraceno spojení s ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Spárovaná zařízení: připojeno ${connected} z ${linked}';
	@override String get screenEnable => 'Sdílet obrazovky a okna';
	@override String get screenDescription => 'Povolit jiným zařízením zobrazovat obrazovky nebo okna z tohoto počítače';
	@override String get screenSources => 'Obrazovky a okna';
	@override String get screenRefresh => 'Obnovit seznam';
	@override String get screenUnsupportedPlatform => 'Toto zařízení nemůže sdílet svou obrazovku. macOS to umí; každé zařízení ale může zobrazit obrazovku sdílenou jiným.';
	@override String get screenUnsupportedVersion => 'Sdílení obrazovky vyžaduje macOS 12.3 nebo novější. Toto zařízení stále může zobrazit obrazovku sdílenou jiným.';
	@override String get screenNeedsPermission => 'macOS potřebuje vaše oprávnění k nahrávání obrazovky, než ji tato aplikace bude moci sdílet.';
	@override String get screenGrantPermission => 'Požádat o oprávnění';
	@override String get screenRelaunchAfterGranting => 'Povolte to v Nastavení systému v části Soukromí a zabezpečení → Nahrávání obrazovky, pak tuto aplikaci ukončete a znovu otevřete — macOS aplikaci o změně informuje až při dalším spuštění.';
	@override String screenProblem({required Object error}) => 'Sdílení obrazovky: ${error}';
	@override String get screenChooseTitle => 'Vyberte, co sdílet';
	@override String get screenChooseButton => 'Vybrat, co sdílet…';
	@override String get screenTabScreens => 'Obrazovky';
	@override String get screenTabApps => 'Aplikace';
	@override String get screenTabWindows => 'Okna';
	@override String get screenTabEmpty => 'Nic takového nebylo nalezeno.';
	@override String get screenSharedSummaryNone => 'Zatím nic nevybráno.';
	@override String get screenThisDevice => 'Toto zařízení';
	@override String screenSharedTo({required Object devices}) => 'Zobrazeno na ${devices}';
	@override String get screenSharedToNobody => 'Nikde se nezobrazuje';
	@override String screenStopSharing({required Object name}) => 'Přestat sdílet ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$cs extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Konfigurace synchronizace';
	@override String get enableTitle => 'Synchronizovat s Ham2K Log Filer';
	@override String get enabledDescription => 'Zálohuje a synchronizuje váš log mezi zařízeními';
	@override String get disabledDescription => 'Vypnuto — data zůstávají jen na tomto zařízení';
	@override String get syncing => 'Synchronizace';
	@override String get account => 'Účet';
	@override String get refresh => 'Obnovit';
	@override String get switchAccounts => 'Přepnout účet';
	@override String get switchAccountsDescription => 'Propojit toto zařízení s jiným účtem pomocí QR kódu nebo e-mailu';
	@override String get connectionRequests => 'Žádosti o připojení';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Jedno zařízení čeká na připojení k tomuto účtu',
		other: '${n} zařízení čeká na připojení k tomuto účtu',
	);
	@override String get accountEmailTitle => 'E-mail účtu';
	@override String accountEmailSent({required Object email}) => 'Potvrzení odesláno na ${email}. Změnu dokončíte otevřením odkazu v e-mailu.';
	@override String get resendConfirmation => 'Znovu odeslat potvrzovací e-mail';
	@override String resendConfirmationDescription({required Object email}) => 'Čeká se na ${email}';
	@override String accountEmailResent({required Object email}) => 'Znovu odesláno na ${email}.';
	@override String get deviceLinked => 'Toto zařízení je nyní propojeno s tímto účtem.';
	@override String get checking => 'Kontrola…';
	@override String get notLinked => 'Zatím nepropojeno';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Nahradit místní data?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${n} aktivita',
		other: '${n} aktivit',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
	@override String get counts => 'Synchronizovaná data';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Toto zařízení: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Čeká na nahrání: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Toto zařízení: kontrola…';
	@override String get countsServerChecking => 'Server: kontrola…';
	@override String get countsServerUnavailable => 'Server: není k dispozici';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Tímto se zálohuje a z tohoto zařízení vymaže ${operations} a ${qsos} a místo nich se stáhnou data účtu. Záloha zůstane v databázi tohoto zařízení.';
	@override String get replace => 'Nahradit';
	@override String get pendingBannerTitle => 'Zjištěn nový účet Ham2K Log Filer';
	@override String get pendingBannerBody => 'Ponechte stávající aktivity a QSO tohoto zařízení a slučte je do účtu, nebo je nahraďte daty účtu (záloha zůstane na tomto zařízení v obou případech).';
	@override String get combine => 'Sloučit';
	@override String get authIssueTitle => 'Synchronizace se nemůže připojit';
	@override String get authIssueText => 'Ham2K Log Filer toto zařízení opakovaně odmítá. Zkontrolujte volací značku v nastavení synchronizace.';
	@override String get openSettings => 'Otevřít nastavení synchronizace';
}

// Path: settings.accounts
class _Translations$settings$accounts$cs extends Translations$settings$accounts$en {
	_Translations$settings$accounts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Účty, služby a zdroje dat';
	@override String get none => 'Žádná aktivní rozšíření s účty';
	@override String get notConfigured => 'Nenakonfigurováno';
	@override String get connected => 'Připojeno';
	@override String get cancelLogin => 'Zrušit přihlášení';
	@override String get openInBrowser => 'Otevřít v prohlížeči';
	@override String loggedInAs({required Object identity}) => 'Přihlášeno jako ${identity}';
	@override String get pressSaveToKeep => 'Stiskněte Uložit, aby účet zůstal připojený.';
	@override String connectedTo({required Object label}) => 'Připojeno k ${label}';
	@override String get connect => 'Připojit';
	@override String get disconnect => 'Odpojit';
	@override String get connectedAs => 'Připojeno jako';
	@override String get test => 'Otestovat';
	@override String saveFailed({required Object error}) => 'Uložení selhalo: ${error}';
	@override String loginFailed({required Object error}) => 'Přihlášení selhalo: ${error}';
	@override String get lookupFailed => 'Účty teď nejsou k dispozici — za chvíli to zkuste znovu';
	@override String get browserLoginTitle => 'Dokončete přihlášení ve webovém prohlížeči';
	@override String browserLoginSteps({required Object prefix}) => 'Až budete hotovi, prohlížeč se pokusí otevřít odkaz začínající „${prefix}“. Váš počítač pro něj nejspíš nemá nic zaregistrováno, proto tento odkaz zkopírujte (z adresního řádku nebo z chybové stránky, kterou prohlížeč zobrazí) a vložte ho sem.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger nemohl otevřít váš prohlížeč. Zkopírujte níže uvedený přihlašovací odkaz a otevřete ho sami, pak zkopírujte odkaz, na který vás přesměruje (začíná „${prefix}“), a vložte ho sem.';
	@override String get copyLoginLink => 'Kopírovat přihlašovací odkaz';
	@override String get pastedLinkLabel => 'Vložte odkaz sem';
	@override String get finishLogin => 'Dokončit přihlášení';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Toto není přihlašovací odkaz — měl by začínat „${prefix}“.';
	@override String get pastedLinkWrongLogin => 'Tento odkaz patří k jinému pokusu o přihlášení. Zavřete tuto stránku a připojte se znovu.';
	@override String get pastedLinkNoCode => 'Tento odkaz neobsahuje přihlašovací kód. Nejprve dokončete přihlášení, pak zkopírujte odkaz, na který vás přesměruje.';
	@override String get pastedLinkMalformed => 'Odkaz vypadá useknutý. Zkopírujte ho celý a vložte znovu.';
	@override String get relayLoginWaiting => 'Čeká se, až dokončíte přihlášení — pak se automaticky pokračuje.';
	@override String get loginNoResponse => 'Toto zařízení zatím nedostalo odpověď z přihlášení. Pokud jste už v prohlížeči skončili, zrušte to a zkuste se připojit znovu.';
	@override String get relayLoginNotOpened => 'Ham2K Logger nemohl automaticky otevřít váš prohlížeč. Přihlašovací stránku otevřete sami tlačítkem níže.';
	@override String get relayLoginUnavailable => 'Synchronizační server potřebný k dokončení přihlášení je nedostupný. Zkontrolujte připojení a zkuste to znovu.';
	@override String get loginIncompleteResponse => 'Tento pokus o přihlášení se nedokončil správně. Zkuste se prosím připojit znovu.';
	@override String get noKeyringTitle => 'Přihlašovací údaje k účtům nelze uložit';
	@override String get noKeyringText => 'Ham2K Logger nemůže na tomto počítači najít službu klíčenky, takže přihlašovací údaje k účtům nelze ukládat ani číst — připojení účtu selže, dokud se to nevyřeší. Nainstalujte a spusťte **gnome-keyring**, **KWallet** nebo **KeePassXC**, nebo odemkněte klíčenku, kterou už máte, a restartujte. Logování, exporty a datové soubory to neovlivní; synchronizace logu zůstane po tu dobu vypnutá.';
	@override String get noKeyringInline => 'Přihlašovací údaje nelze uložit: klíčenka tohoto počítače je nedostupná. Nainstalujte a spusťte gnome-keyring, KWallet nebo KeePassXC, nebo odemkněte tu, kterou máte.';
	@override String get noSecureStorageInline => 'Přihlašovací údaje nelze uložit: zabezpečené úložiště tohoto počítače je nedostupné.';
}

// Path: settings.station
class _Translations$settings$station$cs extends Translations$settings$station$en {
	_Translations$settings$station$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Konfigurace stanice a ovládání CAT';
	@override String get none => 'Není nakonfigurováno žádné vybavení';
	@override String get add => 'Přidat';
	@override String get addTitle => 'Přidat vybavení';
	@override String get searchHint => 'Hledat vybavení';
	@override String get noMatches => 'Žádné odpovídající vybavení';
	@override String get detectedEquipment => 'Nalezené vybavení';
	@override String discoveryUnavailable({required Object error}) => 'Nelze naslouchat rádiím: ${error}';
	@override String get edit => 'Upravit vybavení';
	@override String get name => 'Název';
	@override String get nameDescription => 'Jak mu říkáte — „Levé rádio“. Nepovinné.';
	@override String get transport => 'Připojení';
	@override String get host => 'Adresa';
	@override String get hostDescription => 'Název hostitele nebo IP adresa rádia ve vaší síti.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Adresa je povinná';
	@override String get portInvalid => 'Port musí být mezi 1 a 65535';
	@override String get connect => 'Připojit';
	@override String get disconnect => 'Odpojit';
	@override String get remove => 'Odebrat';
	@override String removeTitle({required Object name}) => 'Odebrat ${name}?';
	@override String get removeMessage => 'Odebere se pouze z aplikace. Nastavení vybavení zůstane beze změny.';
	@override String unknownType({required Object typeKey}) => 'Nerozpoznaný typ vybavení „${typeKey}“';
	@override String get report => 'Nahlásit';
	@override String get reportTitle => 'Nahlásit toto rádio';
	@override String get reportIntro => 'Napište nám, o jaké rádio skutečně jde a jak to dopadlo. Z vašeho hlášení vznikne karta, kterou čte tým Ham2K, a to, co napíšete o zprovoznění, může pomoci dalšímu operátorovi se stejným rádiem.';
	@override String get reportManufacturer => 'Výrobce';
	@override String get reportManufacturerDescription => 'Kdo ho vyrábí — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Výrobce je povinný';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'Model tak, jak ho uvádí samotné rádio — „IC-7300“, „FT-991A“.';
	@override String get reportModelRequired => 'Model je povinný';
	@override String get reportOutcome => 'Jak to dopadlo?';
	@override String get reportOutcomeWorks => 'Fungovalo dobře';
	@override String get reportOutcomeIssues => 'Fungovalo, s problémy';
	@override String get reportOutcomeFails => 'Vůbec nefungovalo';
	@override String get reportOutcomeRequired => 'Napište nám prosím, jak to dopadlo';
	@override String get reportComments => 'Komentáře';
	@override String get reportCommentsPlaceholder => 'Co fungovalo, co ne, cokoli, co vás překvapilo.';
	@override String get reportHints => 'Rady k řešení potíží';
	@override String get reportHintsPlaceholder => 'Chcete navrhnout rady k řešení potíží pro ostatní uživatele?';
	@override String get reportSend => 'Odeslat hlášení';
	@override String get reportSending => 'Odesílání hlášení…';
	@override String reportSent({required Object ref}) => 'Děkujeme — vaše hlášení bylo zaevidováno jako ${ref}.';
	@override String get reportSentNoRef => 'Děkujeme — vaše hlášení bylo odesláno.';
	@override String reportFailed({required Object error}) => 'Hlášení nebylo odesláno: ${error}';
	@override String get troubleshootingNotes => 'Poznámky k řešení potíží';
	@override String get mainVfo => 'Hlavní VFO';
	@override String get useAsMainVfo => 'Použít jako hlavní VFO';
	@override String get serialPort => 'Sériový port';
	@override String get serialPortDescription => 'Port, na kterém se objevuje CAT rozhraní rádia.';
	@override String get serialPortNone => 'Nebyly nalezeny žádné sériové porty';
	@override String get serialPortRequired => 'Vyberte sériový port';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} z ${total}';
	@override String get serialPortSuggested => 'doporučeno';
	@override String get serialPortJustNow => 'Nedávno připojeno';
	@override String get serialPortNoDriver => 'bez ovladače';
	@override String get serialDeviceRequest => 'Přidat zařízení USB…';
	@override String get bleDevice => 'Zařízení Bluetooth LE';
	@override String get bleDeviceDescription => 'Sériový most, přes který je vaše rádio připojeno, například LiNK500MP v Mode 4 nebo sériový adaptér BLE.';
	@override String get bleScan => 'Vyhledat zařízení Bluetooth LE…';
	@override String get bleScanNoneFound => 'Nebyla nalezena žádná zařízení Bluetooth LE. Zkontrolujte, že je most zapnutý, v dosahu a v režimu Bluetooth LE (Mode 4 na LiNK500MP).';
	@override String bleScanFailed({required Object reason}) => 'Vyhledávání Bluetooth LE se nepodařilo spustit: ${reason}';
	@override String get bleOff => 'Bluetooth je vypnuté.';
	@override String get bleDenied => 'Oprávnění pro Bluetooth nebylo uděleno. Povolte ho v nastavení systému a zkuste to znovu.';
	@override String get bleUnsupported => 'Toto zařízení nemá Bluetooth LE.';
	@override String get bleStarting => 'Bluetooth se ještě spouští. Za chvíli to zkuste znovu.';
	@override String get bleConnectFailed => 'Zařízení Bluetooth LE je nedostupné. Zkontrolujte, že je zapnuté, v dosahu a není připojené k jiné aplikaci.';
	@override String bleNoSerialService({required Object services}) => 'Toto zařízení Bluetooth LE nemá žádnou sériovou službu, kterou aplikace zná. Nahlaste ho prosím i s jeho službami: ${services}';
	@override String get baudRate => 'Rychlost (baud)';
	@override String get baudRateDescription => 'Musí odpovídat menu CAT rádia. Při neshodě rádio vrací nesmysly a žádnou chybu.';
	@override String get serialRtsHigh => 'Držet RTS v úrovni high';
	@override String get serialRtsHighDescription => 'Pouze pro rádio, které před odpovědí čeká na RTS, například Yaesu se zapnutým CAT RTS. U Digirig, SignaLink a většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high spustí vysílání.';
	@override String get serialDtrHigh => 'Držet DTR v úrovni high';
	@override String get serialDtrHighDescription => 'Pouze pro CAT rozhraní napájené z DTR, například některé kabely RS-232 pro FT-817. U mnoha kabelů DTR klíčuje CW nebo PTT a jeho držení v úrovni high spustí vysílání.';
	@override String get serialUsbDriver => 'Ovladač čipu USB';
	@override String get serialUsbDriverDescription => 'Automaticky rozpozná většinu adaptérů. Čip vybírejte jen u adaptéru, u kterého seznam portů hlásí „bez ovladače“ — jeho název najdete na obalu nebo v seznamu zařízení USB.';
	@override String get serialUsbDriverAuto => 'Automaticky';
	@override String get civAddress => 'CI-V adresa rádia';
	@override String get civAddressDescription => 'Hexadecimálně, jak ji ukazuje menu CI-V rádia. IC-705 má z výroby A4.';
	@override String get civAddressInvalid => 'CI-V adresa jsou dvě hexadecimální číslice, 01 až FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Ze kterého slice rádia toto připojení čte a který ladí.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Vyberte jeden ze slice rádia, A až H';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} se na tomto rádiu nepoužívá — vyberte jiný slice, nebo ho vytvořte v SmartSDR';
	@override String get channelNotInUse => 'nepoužívá se';
	@override String get channelHeldByUnknown => 'používá ho jiný program';
	@override String get flexNoSlices => 'Toto rádio nenahlásilo žádné slice — zkontrolujte, že běží SmartSDR a že se tento klient smí přihlásit k odběru';
	@override String get spectrumUnsupported => 'Toto rádio přes CAT neposílá spektrum';
	@override String get spectrumRequiresBaud => 'Vyžaduje CAT na 115200 bps';
	@override String get spectrumNoRadio => 'Není připojeno žádné rádio';
	@override String get spectrumWaiting => 'Čeká se na spektrum z rádia…';
	@override String get spectrumUnavailable => 'Zobrazení spektra není k dispozici';
	@override String get spectrumNoDaxChannel => 'Všechny kanály DAX IQ na tomto rádiu se používají';
	@override String get spectrumNoPanadapter => 'Tento slice nemá na rádiu žádný panadaptér';
	@override String spectrumStreamRefused({required Object code}) => 'Rádio odmítlo stream DAX IQ (chyba ${code})';
	@override String get spectrumNoUdp => 'Data spektra z rádia se nedostanou k tomuto zařízení';
	@override String get spectrumK4Unavailable => 'Spektrum K4 přes LAN nelze přijímat. Zkouší se znovu…';
	@override String get spectrumK4RemoteUnavailable => 'Vzdálené spektrum K4 nelze přijímat';
	@override String get spectrumScopeRefused => 'Rádio odmítlo příkazy pro scope';
	@override String get spectrumOutOfRange => 'Scope rádia je nastaven mimo rozsah, který dokáže zobrazit';
	@override String get spectrumBandUnsupported => 'Scope rádia nelze na tomto pásmu zobrazit';
	@override String get spectrumSdrNoRadio => 'Čeká se na frekvenci propojeného rádia…';
	@override String get spectrumSdrNotConnected => 'SDR není připojeno';
	@override String get spectrumSdrNoIf => 'Nastavte mezifrekvenci rádia v nastavení tohoto SDR';
	@override String get sdrRadio => 'Zobrazuje spektrum pro';
	@override String get sdrRadioDescription => 'Zobrazení spektra u tohoto rádia čerpá z tohoto přijímače místo z vlastního scope rádia.';
	@override String get sdrRadioMain => 'Hlavní rádio';
	@override String get sdrTuning => 'Anténní vstup';
	@override String get sdrTuningDescription => 'Odkud přijímač bere signál. Na vlastní anténě se ladí sám podle rádia; na mezifrekvenčním výstupu rádia zůstává na mezifrekvenci.';
	@override String get sdrTuningIndependent => 'Vlastní anténa';
	@override String get sdrTuningIfTap => 'Mezifrekvenční výstup rádia';
	@override String get sdrIfHz => 'Mezifrekvence (Hz)';
	@override String get sdrIfHzDescription => 'Jen pro mezifrekvenční výstup: frekvence, na které na mezifrekvenci leží naladěná frekvence rádia, například 68330000 u FT-817.';
	@override String get sdrIfInverted => 'Mezifrekvence je invertovaná';
	@override String get sdrGainDb => 'Zisk (dB)';
	@override String get sdrGainDbDescription => 'Pro automatický zisk přijímače nechte prázdné.';
	@override String get sdrOffsetHz => 'Posun frekvence (Hz)';
	@override String get sdrOffsetHzDescription => 'Přičte se ke každé frekvenci poslané do přijímače, pro upkonvertor: 125000000 u Ham It Up.';
	@override String get sdrPpm => 'Korekce frekvence (ppm)';
	@override String get rtlDirectSampling => 'Přímé vzorkování';
	@override String get rtlDirectSamplingDescription => 'Pro KV na RTL-SDR V3 bez upkonvertoru. RTL-SDR V4 dosáhne na KV i bez něj.';
	@override String get rtlDirectSamplingOff => 'Vypnuto';
	@override String get rtlDirectSamplingI => 'Větev I';
	@override String get rtlDirectSamplingQ => 'Větev Q';
	@override String get rtlTcpNotAServer => 'Toto není server rtl_tcp';
	@override String get rtlTcpNotes => 'Připojuje se k **serveru rtl_tcp, který si sami spustíte** na počítači, do kterého je dongle zapojený.\n\n- **Spusťte ho** příkazem `rtl_tcp -a 0.0.0.0`, aby se k němu dostaly i ostatní počítače; na stejném počítači stačí samotné `rtl_tcp`.\n- **Port** je 1234, pokud jste ho nespustili s `-p`.\n- **Jeden program najednou:** rtl_tcp obsluhuje jediného klienta. Aplikace se připojí jen tehdy, když je zobrazeno spektrum, a pár sekund po jeho zavření se odpojí.\n- **Na Androidu** stejný server na telefonu spouští aplikace *SDR driver*.';
	@override String get rspTcpNotes => 'Připojuje se k **serveru rsp_tcp, který si sami spustíte** na počítači, do kterého je RSP zapojené a kde je nainstalované API od SDRplay.\n\n- **Spusťte ho** příkazem `rsp_tcp -a 0.0.0.0`.\n- **Port** je 1234, pokud jste ho nespustili s `-p`.\n- **Jeden program najednou:** server přijme jediného klienta. Aplikace se připojí jen tehdy, když je zobrazeno spektrum.';
	@override String get n3fjpNoRig => 'N3FJP nemá nastavené rozhraní rádia, takže se sleduje to, co je zadáno v N3FJP, ne rádio';
	@override String get winkeyerKeyPort => 'Výstup klíčování';
	@override String get winkeyerKeyPortDescription => 'Do kterého ze dvou výstupních konektorů klíčovače je zapojeno vaše rádio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Použít PTT klíčovače';
	@override String get winkeyerPttDescription => 'Klíčovat linku PTT na stejném konektoru, pro zesilovač nebo rádio, které to potřebuje. Pro rádio klíčované přes konektor klíče nechte vypnuté.';
	@override String get winkeyerNoAnswer => 'Na tomto portu neodpověděl žádný WinKeyer';
	@override String get winkeyerStoppedAnswering => 'WinKeyer během vysílání přestal odpovídat; zpráva byla zahozena';
	@override String get icomControlPort => 'Řídicí port (UDP)';
	@override String get icomControlPortDescription => 'Control Port (UDP) rádia — 50001, pokud nebyl změněn v jeho síťovém nastavení nebo přesměrován na jiný.';
	@override String get icomSerialPort => 'Sériový port (UDP)';
	@override String get icomSerialPortDescription => 'Serial Port (UDP) rádia — 50002, pokud nebyl změněn v jeho síťovém nastavení nebo přesměrován na jiný.';
	@override String get icomPortsDiffer => 'Řídicí a sériový port se musí lišit';
	@override String get radioUser => 'Uživatelské jméno rádia';
	@override String get radioPass => 'Heslo rádia';
	@override String get radioLoginDescription => 'Přihlášení rádia v Network → Remote, ne vaše heslo k WiFi.';
	@override String get radioUserRequired => 'Uživatelské jméno pro vzdálené ovládání rádia je povinné';
	@override String get connectFailedBusy => 'Zařízení se používá';
	@override String get connectFailedDenied => 'Přístup odepřen';
	@override String get connectFailedDevice => 'Zařízení nenalezeno';
	@override String get connectFailedUnsupported => 'Čip tohoto adaptéru USB nerozpoznal žádný ovladač. Pokud víte, o který čip jde, vyberte ho v sekci „Pokročilé nastavení“ pod Ovladač čipu USB.';
	@override String get connectFailedLines => 'RTS/DTR nebylo možné udržet podle nastavení, proto byl port zavřen. Jiný program mohl nechat zapnuté hardwarové řízení toku — odpojte a znovu připojte kabel.';
	@override String get connectFailedNetwork => 'Rádio nelze v síti najít. Zkontrolujte jeho adresu a že je zapnuté a dostupné.';
	@override String connectFailedReplyPort({required Object port}) => 'Port ${port} na tomto zařízení se už používá, a právě na něj přicházejí odpovědi. Zavřete cokoli jiného, co na něm naslouchá — včetně dalšího uzlu PstRotator — nebo port změňte.';
	@override String get connectFailedTimeout => 'Rádio neodpovědělo včas. Zkontrolujte, že je zapnuté a dostupné.';
	@override late final _Translations$settings$station$models$cs models = _Translations$settings$station$models$cs._(_root);
	@override late final _Translations$settings$station$transports$cs transports = _Translations$settings$station$transports$cs._(_root);
	@override String get troubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get ft891Troubleshooting => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **CAT RTS vypnuté na rádiu, nebo zapnuté Držet RTS v úrovni high.** Se zapnutým **CAT RTS** (menu FT-891 **05-08**) rádio mlčí, dokud je RTS v úrovni low — může jednou odpovědět při otevření portu, pak už nic. Výběr vlastního USB portu rádia zapne **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high klíčuje váš vysílač: místo toho vypněte CAT RTS na rádiu.\n- **Rychlost musí odpovídat** CAT RATE rádia (menu **05-06**). Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get yaesuBinaryTroubleshooting => 'Toto rádio používá starší pětibajtový CAT od Yaesu a když něco nesedí, vůbec neodpovídá. Téměř vždy jde o jedno z:\n\n- **Kabel musí převádět úrovně.** Konektor CAT vzadu není RS-232 ani USB; potřebuje CT-62 nebo ekvivalentní adaptér. Obyčejný audio nebo datový kabel pro CAT fungovat nebude.\n- **Rychlost musí odpovídat** menu CAT RATE rádia (**#14** na FT-817, **#19** na FT-857 nebo FT-897). Při neshodě rádio nic nevrací, a nikdy chybu.\n- **Nikdy nedovolte nic, co by na tomto portu zvedlo RTS nebo DTR.** U většiny kabelů pro tato rádia jsou tyto linky PTT a klíčování. Výjimkou je starší rozhraní napájené z DTR: pro ně zapněte **Držet DTR v úrovni high** v sekci „Pokročilé nastavení“.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTento ovladač byl napsán podle publikované tabulky CAT od Yaesu a s žádným z těchto rádií zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get tenTecTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get tenTecEagleTroubleshooting => '- **Port USB-B vzadu je linka CAT.** Rádio se hlásí jako sériový port USB; ve Windows potřebuje ovladač USB to UART od Ten-Tec, který se ve Správci zařízení objeví jako „USB to UART (COMx)“.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený, a stejně tak aktualizátor firmwaru od Ten-Tec.\n- **Nastavení šířky filtru z aplikace ho odebere knoflíku BW**, dokud rádio nevypnete a znovu nezapnete. Tak to rádio funguje.\n\nTento ovladač byl napsán podle programátorské referenční příručky Ten-Tec. Pokud funguje jen napůl, stojí za to to nahlásit, i s verzí firmwaru z menu rádia.';
	@override String get tenTecOrionTroubleshooting => '- **Použijte přímý sériový kabel DB-9** do portu SERIAL DATA, ne křížený (null-modem).\n- **Tato položka drží RTS v úrovni high**, protože Orion používá RTS a CTS jako handshake. U rozhraní, které klíčuje PTT z RTS, například Digirig, vypněte Držet RTS v úrovni high v sekci „Pokročilé nastavení“, jinak rádio začne vysílat, jakmile se aplikace připojí.\n- **CW z aplikace vyžaduje zapnutý interní klíčovač rádia.** Když je vypnutý, rádio ignoruje, co aplikace posílá.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTento ovladač byl napsán podle programátorské referenční příručky Ten-Tec a s Orionem zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit, i s verzí firmwaru z menu rádia.';
	@override String get tenTecNoCw => 'Firmware tohoto rádia nepřijímá CW z aplikace. Ten-Tec ho přidal ve firmwaru Orionu 1.366.';
	@override String get tenTecKeyerOff => 'Interní klíčovač rádia je vypnutý, rádio proto ignoruje CW posílané z aplikace. Zapněte klíčovač v menu rádia.';
	@override String get guohetecTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get guohetecTroubleshooting => 'Q900 má dva protokoly CAT a tato položka používá jeho nativní protokol místo napodobeniny FT-817. Vyberte zde **Guohetec Q900**, ne FT-817 — napodobenina podporuje méně příkazů a rádio neříká, který z nich používá.\n\n- **Kabel USB-C je linka CAT** a připojuje i zvukovou kartu. Rychlost na něm nehraje roli; port ignoruje, na co je nastaven.\n- **Nikdy nedovolte nic, co by na tomto portu zvedlo RTS nebo DTR.** U sériového kabelu jsou tyto linky PTT a klíčování.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Rádio druhé generace se chová jinak** než první. Dlouze stiskněte Menu, pak About: HW 2.0 je druhá generace.\n\nTento ovladač byl napsán podle protokolu publikovaného výrobcem a s žádným z těchto rádií zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get yaesuTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get yaesuTroubleshooting => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **CAT RTS musí být na rádiu VYPNUTO.** Když je zapnuté, rádio čeká na linku handshake, kterou aplikace drží v úrovni low. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je tatáž linka PTT, takže její zvednutí by klíčovalo váš vysílač. Na vlastním USB portu rádia je alternativou **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. Kde se toto nastavení nachází, se liší podle modelu (menu **05-08** na FT-891).\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Módy se řídí tabulkou FT-891.** Většina řady Yaesu jí odpovídá, ale rádio, které čísluje módy jinak, u nich zobrazí a nastaví nesprávný mód. Frekvence tím není ovlivněna.';
	@override String get ftdx3000Troubleshooting => '**Menu 037 CAT SELECT musí být USB** pro CAT přes USB port rádia; při nastavení RS232C je CAT na konektoru vzadu.\n\nTato položka byla napsána podle publikované dokumentace CAT a s FTDX3000 zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get yaesuRs232Troubleshooting => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **Konektor CAT je RS-232.** Potřebuje převodník USB na sériový port a přímý kabel DB-9 — křížený (null-modem) kabel prohodí linky a rádio nic neuslyší.\n- **CAT RTS musí být na rádiu VYPNUTO.** Když je zapnuté, rádio čeká na linku handshake, kterou aplikace drží v úrovni low, pokud není v sekci „Pokročilé nastavení“ zapnuto **Držet RTS v úrovni high**.\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTato položka byla napsána podle publikované dokumentace CAT a s žádným z těchto rádií zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get yaesuUsbTroubleshooting => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **Použijte první ze dvou USB portů rádia.** CAT je obvykle na prvním (ve Windows port COM **Enhanced**); druhý (**Standard**) slouží pro PTT a klíčování. Výběr ukazuje na první, kdekoli je dokáže rozlišit.\n- **CAT RTS vypnuté na rádiu, nebo zapnuté Držet RTS v úrovni high.** Se zapnutým menu **CAT RTS** rádio mlčí, dokud je RTS v úrovni low — může jednou odpovědět při otevření portu, pak už nic. Výběr vlastního USB portu rádia zapne **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high klíčuje váš vysílač: místo toho vypněte CAT RTS na rádiu.\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.';
	@override String get k4SerialNotes => 'Připojte zadní konektor USB-B (PC) na K4. Pro CAT funguje USB-PC1 i USB-PC2; zvolte nepoužívaný port a nastavte na rádiu odpovídající Serial USB-PCn: Baud Rate. HaLo předvyplní 38400; v případě potřeby to změňte. Jiná aplikace musí použít druhý port nebo Ethernet.\n\nToto připojení ovládá rádio a jeho klíčovače; do HaLo neposílá zvuk.';
	@override String get k4TcpNotes => 'Připojte ethernetový konektor K4 do místní sítě. Zadejte jeho název hostitele nebo IP adresu a CAT port 9200. Když je zobrazen panadaptér nebo vodopád, HaLo používá stejného hostitele na pevném portu 9201; změna CAT portu port spektra nemění.\n\nSpektrum ukazuje hlavní přijímač. Jeho ovládání zoomu, referenční úrovně a rychlosti ovlivňuje jen zobrazení v HaLo. Streamování zvuku není podporováno.';
	@override String get k4PowerTimeout => 'Výkon K4 nebyl změněn, protože rádio nepotvrdilo svůj výstupní rozsah. Zkuste to znovu.';
	@override String get k4RemoteNotes => 'Zapněte na K4 vzdálený přístup a zadejte jeho síťové heslo. Main a Sub sdílejí jedno šifrované připojení pro ovládání rádia i spektrum. Výchozí port je 9204; při vzdáleném připojení zadejte svůj přesměrovaný port.\n\nPřehrávání zvuku a streamování mikrofonu nejsou podporovány.';
	@override String get k4Receiver => 'Přijímač';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'Vyberte Main nebo Sub';
	@override String get k4ReceiverAlreadyConfigured => 'Tento přijímač je u tohoto K4 už nakonfigurován';
	@override String get k4SubReceiverOff => 'Sub přijímač K4 je vypnutý';
	@override String get k4RemotePasswordRequired => 'Pro zabezpečené připojení zadejte síťové heslo K4.';
	@override String get k4RemoteHandshakeFailed => 'Rádio K4 nedokázalo navázat zabezpečené připojení. Zkontrolujte jeho síťové heslo a nastavení vzdáleného přístupu.';
	@override String get k4RemoteUnreachable => 'Zabezpečené připojení K4 je nedostupné. Zkontrolujte adresu, port a nastavení vzdáleného přístupu.';
	@override String get k4PowerRange => 'Výkon K4 musí být 0,1–110 W, nebo 0,0001–0,01 W, když je aktivní miliwattový výstup transvertoru.';
	@override String get elecraftTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get elecraftTroubleshooting => 'Rádia Elecraft používají Kenwood CAT a KX2 i KX3 byly takto vyzkoušeny — VFO oběma směry, přepínání módů i CW zero-beat fungují.\n\nPokud rádio neodpovídá, téměř vždy jde o jedno z:\n\n- **Rychlost musí odpovídat** rychlosti nastavené v **RS232** v menu rádia. Z výroby je nastaveno 38400. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\n**Pokud je frekvence správně, ale mód špatně**, dejte nám vědět. Položky KX2 a KX3 čtou mód z pozice ve stavové odpovědi rádia, kterou jsme určili podle rádií, která jsme viděli, a firmware, který ho dává jinam, odhalí jen hlášení od vás.\n\nK3 zatím nikdo nenahlásil, takže pokud ho používáte, napište, co se stane. K4 má vlastní položku.';
	@override String get lab599TroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get lab599Troubleshooting => 'Řada TX-500 používá Kenwood CAT. Frekvence a mód byly vyzkoušeny přes LiNK500MP; výkon a měřiče jsou napsány podle referenční příručky CAT od Lab599, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\n- **Rychlost musí odpovídat** nastavení CAT rádia, 9600, pokud jste ho nezměnili. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Vyberte na rádiu protokol CAT.** TS-2000 pokrývá frekvenci, mód a výkon. LAB599 navíc aplikaci umožní přepnout rádio do DIG, vidět jeho vysílání v DIG a číst napájecí napětí.\n- **Přes LiNK500MP** podržte knoflík VFO asi tři sekundy, tím předáte ovládání CAT rozhraní.\n- **Nastavte na LiNK500MP režim podle připojení**: Mode 3 pro Bluetooth, Mode 4 pro Bluetooth LE. V jiném režimu ho vyhledávání Bluetooth LE nenajde.\n- **Přes Bluetooth** se LiNK500MP páruje jako dva sériové porty a CAT nese jen jeden. Pokud rádio mlčí, vyberte druhý.';
	@override String get lab599TroubleshootingIos => 'Řada TX-500 používá Kenwood CAT. Frekvence a mód byly vyzkoušeny přes LiNK500MP; výkon a měřiče jsou napsány podle referenční příručky CAT od Lab599, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\n- **Nastavte LiNK500MP do Mode 4**, jeho režimu Bluetooth LE, než ho začnete vyhledávat. V jiném režimu ho iPhone ani iPad nenajde.\n- **Předejte ovládání CAT rozhraní LiNK500MP**: podržte knoflík VFO rádia asi tři sekundy.\n- **Vyberte na rádiu protokol CAT.** TS-2000 pokrývá frekvenci, mód a výkon. LAB599 navíc aplikaci umožní přepnout rádio do DIG, vidět jeho vysílání v DIG a číst napájecí napětí.';
	@override String get kenwoodTroubleshootingTitle => 'Pokud se rádio připojí, ale neukazuje frekvenci';
	@override String get kenwoodTroubleshooting => 'Tento ovladač je ověřen s Kenwood TS-590SG a TS-480, QRP Labs QMX a QCX-mini a Elecraft KX2 a KX3. Zbytek řady je napsán podle publikovaných referencí CAT, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\nPokud rádio neodpovídá, téměř vždy jde o jedno z:\n\n- **Rychlost musí odpovídat** menu CAT rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Některá rádia potřebují zapnout CAT** v menu, než vůbec začnou odpovídat.\n- **Rádia Kenwood čekají na RTS**: jejich port CAT ho používá jako handshake, proto musí být zapnuto Držet RTS v úrovni high (v sekci „Pokročilé nastavení“). Připojení nastavené dříve, než bylo ve výchozím stavu zapnuté, ho může mít vypnuté. U Digirig nebo jiného kabelu, který klíčuje PTT z RTS, ho vypněte, jinak rádio vysílá.\n\n**Stejný protokol používá několik SDR front-endů**, takže tuto položku stojí za to vyzkoušet i pro ně; rádia Elecraft jsou uvedena zvlášť, pod Elecraft. Pokud je frekvence správně, ale mód je špatně nebo chybí, je to ta jediná část, která se v řadě liší — aplikace ho zjišťuje z rádia a v nouzi se ptá přímo, takže mód se může jen opožďovat.';
	@override String get statusConnected => 'Připojeno';
	@override String get statusLost => 'Odpojeno';
	@override String get notConfigured => 'Nenakonfigurováno';
	@override String get currentConfiguration => 'Aktuální konfigurace';
	@override String get currentTransceiver => 'Aktuální transceiver';
	@override String get currentTransceivers => 'Aktuální transceivery';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => 'Zprávy se řadí do fronty místo přerušování';
	@override String get noRadioBSelected => 'Není vybráno rádio B';
	@override String get radioMode => 'Mód rádia';
	@override String get keyerNotSupported => 'Aktuální rádio nepodporuje';
	@override String get catControlPreferences => 'Předvolby ovládání CAT';
	@override String get chooseTransceiver => 'Vyberte transceiver';
	@override String get configurationSection => 'Konfigurace';
	@override String get noTransceiverSelected => 'Není vybrán žádný transceiver';
	@override String makeMainVfo({required Object name}) => 'Použít ${name} pro hlavní VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		zero: 'Žádné transceivery',
		one: '${count} transceiver',
		other: '${count} transceiverů',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} anténa',
		other: '${count} antén',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} další zařízení',
		other: '${count} dalších zařízení',
	);
	@override String get equipmentInventory => 'Přehled vybavení';
	@override String get equipmentInUse => 'Ovládání transceiveru';
	@override String get noTransceiver => 'Žádný';
	@override String get peerRadioNotAvailable => 'Není k dispozici';
	@override String peerRadioOnDevice({required Object device}) => 'Na ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} je na jiném zařízení';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Toto rádio je připojeno k ${device}. Jeho připojení a nastavení se konfiguruje na tom zařízení.';
	@override String get antennaInUse => 'Používaná anténa';
	@override String get keyInUse => 'Klíčování CW';
	@override String get phoneKeying => 'Hlasové klíčování';
	@override String get phoneKeyingNone => 'Žádné';
	@override String phoneKeyingRadio({required Object radio}) => 'Paměti v ${radio}';
	@override String get phoneKeyingComputer => 'Zvuk v tomto počítači';
	@override String get phoneKeyingOff => 'Hlasové klíčování je vypnuté';
	@override String get computerVoiceSettings => 'Zvuk počítače';
	@override String get cwKeyingOptions => 'Možnosti klíčování CW';
	@override String get noneSelected => 'Žádný';
	@override String get moreSettings => 'Další nastavení';
	@override String get icomCivTroubleshootingTitle => 'Pokud se pro stejné rádio objeví dva sériové porty';
	@override String get icomCivTroubleshooting => 'Několik rádií Icom, mezi nimi IC-705, nabízí najednou **dva** sériové porty USB (Icom je nazývá Port A a Port B), oba výchozí nastavené na CI-V. Tato aplikace ani váš operační systém je kromě toho nedokážou rozlišit: stejné USB vendor/product ID se prostě objeví dvakrát, zde někdy označené příponou `#2`. **Správný je obvykle Port A** — normálně ten, který váš systém nebo prohlížeč uvádí jako první, a kde to aplikace dokáže rozlišit, označí ho jako doporučený. Pokud příkazy odcházejí a rádio nikdy neodpoví, zkuste druhý port.';
	@override String get civAddressTroubleshootingTitle => 'Pokud rádio nikdy neodpoví';
	@override String get civAddressTroubleshooting => '- **CI-V adresa musí odpovídat** menu rádia. Tato položka předvyplní adresu, se kterou se model dodává, ale rádio sdílející sběrnici CI-V je přesně místo, kde se mění. Rámec odeslaný na špatnou adresu je tiše ignorován, což vypadá přesně jako vadný kabel.\n- **Rychlost musí odpovídat** CI-V BAUD RATE rádia (na USB CI-V USB Baud Rate). Nastavte rádio na stejné číslo, jaké je zde, **ne na Auto**. Na Auto se některá rádia, mezi nimi IC-7300, připojí a asi po minutě přestanou odpovídat.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **CI-V adresa musí odpovídat** menu rádia. Tato položka předvyplní adresu, se kterou se model dodává, ale rádio sdílející sběrnici CI-V je přesně místo, kde se mění. Rámec odeslaný na špatnou adresu je tiše ignorován, což vypadá přesně jako vadný kabel.\n${speed}\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.';
	@override String get icomUsbSpeedFollows => '- **Žádná rychlost se nenastavuje.** Přes USB toto rádio komunikuje rychlostí, kterou používá počítač, a tato položka vždy používá 115200, rychlost, kterou potřebuje scope.';
	@override String get ic7610UsbSpeed => '- **Nastavte CI-V USB Baud Rate na 115200**, rychlost, kterou tato položka vždy používá, protože ji potřebuje scope — **ne Auto**. Rádio nastavené na jinou rychlost odpoví mlčením.';
	@override String get civTransceiveTitle => 'Pokud aplikace sleduje rádio se zpožděním';
	@override String get civTransceive => 'Pokud aplikaci trvá několik sekund, než ukáže změnu frekvence nebo módu provedenou na rádiu, zapněte na rádiu nastavení **CI-V Transceive** (u většiny současných modelů v SET > Connectors > CI-V). Když je zapnuté, rádio hlásí každou změnu v okamžiku, kdy nastane. Když je vypnuté, aplikace změnu uvidí až při dalším dotazu, každých několik sekund.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** se dodává s adresou `B6`, ne `94` předvyplněnou zde — vyberte místo toho položku IC-7300 MK2.';
	@override String get ic705PortNote => '\n- **IC-705** nabízí dva sériové porty USB, oba pojmenované po rádiu. CI-V je na **prvním** z nich, na který výběr ukazuje, kdekoli je dokáže rozlišit.';
	@override String get ic7760PortNote => '\n- **IC-7760** používá CI-V na **Port A** ze dvou sériových portů USB, které nabízí.';
	@override String get x6100PortNote => '\n- **X6100** používá CI-V na portu **DEV** — druhém ze dvou sériových portů, které nabízí, a na ten výběr ukazuje.';
	@override String get rigctldTroubleshootingTitle => 'Pokud se aplikace nemůže připojit';
	@override String get rigctldTroubleshooting => 'Toto se připojuje k **démonu rigctld, který spouštíte sami**, ne přímo k rádiu — s rádiem komunikuje backend Hamlib, který podporuje stovky modelů.\n\n- **Démon už musí běžet**, např. `rigctld -m 1035 -r /dev/ttyUSB0`. Číslo modelu vašeho rádia zjistíte pomocí `rigctl -l`.\n- **Z jiného počítače** ho spusťte s `-T 0.0.0.0`: ve výchozím stavu rigctld přijímá připojení jen z počítače, na kterém běží.\n- **Port** je 4532, pokud jste démona nespustili s `-t`.\n- Když po připojení chybí frekvence, obvykle to znamená, že se k rádiu nemůže dostat samotný démon. Otestujte to pomocí `rigctl -m 2 f` na počítači s démonem.';
	@override String get flrigTroubleshootingTitle => 'Pokud se aplikace nemůže připojit';
	@override String get flrigTroubleshooting => 'Toto se připojuje k **programu flrig, který spouštíte sami**, ne přímo k rádiu — s rádiem komunikuje flrig, který podporuje většinu značek a modelů.\n\n- **flrig už musí běžet** s nakonfigurovaným a připojeným transceiverem.\n- **Port** je 12345, pokud jste ho nezměnili v konfiguraci flrig (Config → Setup → Server).\n- **Z jiného počítače** se ujistěte, že je server flrig dostupný. Naslouchá na všech rozhraních, ale váš firewall s tím nemusí souhlasit.\n- Když po připojení chybí frekvence, obvykle to znamená, že se k rádiu nemůže dostat samotný flrig. Zkontrolujte, že displej flrig sleduje ladění.';
	@override String get hrdTroubleshootingTitle => 'Pokud se aplikace nemůže připojit';
	@override String get hrdTroubleshooting => 'Toto se připojuje k **Rig Control z Ham Radio Deluxe, běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje HRD.\n\n- **Rig Control už musí běžet** a být připojený k rádiu.\n- **Jeho IP server musí být zapnutý.** Rig Control komunikuje s jinými programy jen přes něj.\n- **Port** je 7809, pokud jste ho nezměnili v nastavení IP serveru.\n- **Z jiného počítače** se ujistěte, že váš firewall spojení propustí.\n\nTato položka byla napsána podle publikovaných popisů protokolu HRD a s HRD zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get n3fjpTroubleshootingTitle => 'Pokud se aplikace nemůže připojit';
	@override String get n3fjpTroubleshooting => 'Toto se připojuje k **logovacímu programu N3FJP běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje N3FJP.\n\n- **API programu musí být zapnuté**: Settings → Application Program Interface, zaškrtněte **TCP API Enabled**.\n- **Port** je 1100, pokud jste ho tam nezměnili.\n- **N3FJP musí mít nastavené rozhraní rádia**, aby mohl rádio sledovat nebo ladit. Bez něj hlásí jen to, co je zadáno v jeho vstupním okně.\n- N3FJP hlásí pouze pásmo, mód a frekvenci: žádný výkon, žádný stav vysílání.\n\nTato položka byla napsána podle publikovaného API N3FJP a s N3FJP zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get commanderTroubleshootingTitle => 'Pokud se aplikace nemůže připojit';
	@override String get commanderTroubleshooting => 'Toto se připojuje k **DXLab Commander, běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje Commander.\n\n- **Commander už musí běžet** a být připojený k rádiu.\n- **Jeho síťová služba musí být zapnutá**: tlačítko **Net Serv** v panelu Radio v okně Configuration programu Commander.\n- **Port** je 52002, třetí port bloku začínajícího na **Base Port** v Net Serv (52000, pokud jste ho nezměnili).\n- **Z jiného počítače** se ujistěte, že váš firewall spojení propustí.\n\nTato položka byla napsána podle publikovaných TCP zpráv Commanderu a s Commanderem zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.';
	@override String get ic705TroubleshootingTitle => 'Pokud rádio nikdy neodpoví';
	@override String get ic705Troubleshooting => 'Rádio má **jedinou** relaci vzdáleného ovládání. Když je přihlášení ignorováno, téměř vždy ji používá něco jiného.\n\n- **Zavřete všechny ostatní klienty.** wfview nebo RS-BA1 připojené ke stejnému rádiu drží tuto jedinou relaci a přihlášení zde je po tu dobu prostě ignorováno.\n- **Zkontrolujte síťové nastavení rádia.** WLAN musí být zapnutá, rádio musí být ve stejné síti a jeho funkce vzdáleného ovládání (Network) musí být povolená.\n- **Porty musí odpovídat** Control Port a Serial Port (UDP) rádia, nebo portům na ně přesměrovaným. Špatný port se setká s mlčením, stejně jako vypnuté rádio.\n- **Vypněte a zapněte WLAN rádia**, pokud zůstává zaseknuté. To spolehlivě uvolní relaci zaseknutou v rádiu.\n\n**Špatné heslo je výslovně odmítnuto**, ne přejito mlčením. Pokud jste se dostali sem, a ne ke zprávě „odmítnuto“, heslo problémem není.';
	@override String get icomLanTroubleshooting => 'Rádio má **jedinou** relaci vzdáleného ovládání. Když je přihlášení ignorováno, téměř vždy ji používá něco jiného.\n\n- **Zavřete všechny ostatní klienty.** wfview, RS-BA1 nebo Remote Utility od Icomu připojené ke stejnému rádiu drží tuto jedinou relaci a přihlášení zde je po tu dobu prostě ignorováno.\n- **Zkontrolujte síťové nastavení rádia.** Jeho port LAN musí být připojen do stejné sítě jako toto zařízení, musí být zapnuté **Network Control** a uživatelské jméno a heslo musí být na rádiu nastaveny jako síťový uživatel.\n- **Porty musí odpovídat** Control Port a Serial Port (UDP) rádia, nebo portům na ně přesměrovaným. Špatný port se setká s mlčením, stejně jako vypnuté rádio.\n- **Pokud se připojí, ale nikdy neodpoví**, CI-V adresa zde musí odpovídat menu CI-V ADDRESS rádia. Tato položka předvyplní adresu, se kterou se model dodává.\n- **Rádio vypněte a zapněte**, pokud zůstává zaseknuté.';
	@override String get statusStale => 'Neodpovídá';
	@override String get statusDisconnected => 'Nepřipojeno';
	@override String get statusConnecting => 'Připojování…';
	@override String get statusDisconnecting => 'Odpojování…';
	@override String get statusError => 'Připojení selhalo';
	@override String get currentRadioSettings => 'Aktuální nastavení rádia';
	@override String get notSupportedByThisRadio => 'Toto rádio nepodporuje';
	@override String get cwMessagesButton => 'Zprávy CW';
	@override String get voiceMessagesButton => 'Hlasové zprávy';
	@override String voiceKeyerAvailable({required Object count}) => 'Hlasový klíčovač: ${count} pamětí v rádiu';
	@override String get antennaBands => 'Pásma';
	@override String get antennaType => 'Typ antény';
	@override String get antennaTypeRequired => 'Vyberte typ antény';
	@override late final _Translations$settings$station$antennaTypes$cs antennaTypes = _Translations$settings$station$antennaTypes$cs._(_root);
	@override String get keyType => 'Typ klíče';
	@override String get keyTypeRequired => 'Vyberte typ klíče';
	@override late final _Translations$settings$station$keyTypes$cs keyTypes = _Translations$settings$station$keyTypes$cs._(_root);
	@override String get softwareIntermediaries => 'Softwaroví prostředníci';
	@override String get otherBrands => 'Jiné značky';
	@override String get otherEquipment => 'Další vybavení (antény, klíče atd.)';
	@override String get newAntenna => 'Nová anténa';
	@override String get newKey => 'Nový klíč';
	@override String get newKeyer => 'WinKeyer (K1EL nebo kompatibilní)';
	@override String keyViaRadio({required Object radio}) => 'CAT klíčovač v ${radio}';
	@override String keyOnDevice({required Object device}) => 'Klíč na ${device}';
	@override String get trackStationInfo => 'Zaznamenávat informace o stanici u každého QSO';
	@override String get includeStationInfoInAdif => 'Zahrnout do exportů ADIF';
	@override String get whatToTrack => 'Co zaznamenávat?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Výkon';
	@override String get watts => 'Watty';
	@override String get trackFieldAntenna => 'Anténa';
	@override String get trackFieldKey => 'CW klíč';
	@override String get placeholderConnectDelay => 'Zpoždění připojení (ms)';
	@override String get placeholderConnectDelayDescription => 'Jak dlouho trvá simulovaný handshake. Prázdné nebo 0 připojí okamžitě.';
	@override String get placeholderDropAfter => 'Odpojit po (sekundách)';
	@override String get placeholderDropAfterDescription => 'Samo ukončí spojení, aby se otestovalo opětovné připojení. Prázdné nebo 0 nikdy neodpojí.';
	@override String get placeholderFailConnect => 'Vždy selhat při připojení';
	@override String get placeholderConnectFailure => 'Zástupné rádio má nastaveno toto připojení odmítnout';
	@override String get placeholderFreq => 'Frekvence (kHz)';
	@override String get placeholderFreqDescription => 'Kde zástupné rádio začíná. Poté hlásí cokoli, na co ho aplikace naladí.';
	@override String get placeholderMode => 'Mód';
	@override String get placeholderModeDescription => 'Mód, ve kterém zástupné rádio začíná, např. USB, CW, FT8.';
	@override String get placeholderPower => 'Výkon (watty)';
	@override String get placeholderPurpose => 'Toto rádio použijte k evidenci, který transceiver používáte, pro účely logování';
	@override String get placeholderReplyDelay => 'Zpoždění odpovědi (ms)';
	@override String get placeholderReplyDelayDescription => 'Jak dlouho zástupnému rádiu trvá nahlásit změnu. Prázdné nebo 0 odpoví ihned.';
	@override String get cwKeyerField => 'CAT CW klíčovač';
	@override String get cwKeyerFieldDescription => 'Zda toto rádio klíčuje CW z textu přes CAT. Vypnuto pro rádio, které aplikace nezná.';
	@override String get voiceMemories => 'Hlasové paměti';
	@override String get voiceMemoriesDescription => 'Kolik hlasových pamětí rádio přehrává přes CAT. 0 pro žádné.';
	@override String get voiceMemoriesInvalid => 'Celé číslo, 0 nebo více';
	@override String get yaesuMeterCapture => 'Zachytávat hodnoty měřidel';
	@override String get yaesuBinaryMeterCaptureDescription => 'Při vysílání čte měřidlo výstupního výkonu rádia a příznak vysokého PSV a zapisuje surové hodnoty do logu. Slouží k sestavení stupnice, kterou Yaesu nepublikuje — hodnoty se nezobrazují jako měřidla.';
	@override String get yaesuMeterCaptureDescription => 'Při vysílání čte měřidla PO, SWR a ALC rádia a zapisuje surové hodnoty do logu. Slouží k sestavení stupnice, kterou Yaesu nepublikuje — hodnoty se nezobrazují jako měřidla.';
	@override String get telemetryInterval => 'Interval čtení měřidel (ms)';
	@override String get telemetryIntervalDescription => 'Jak často číst měřidla rádia během vysílání. Ponechte prázdné pro nejrychlejší, co toto připojení zvládne, až 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Celé číslo milisekund, ${min} až ${max}';
	@override String get pollInterval => 'Interval dotazování v klidu (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Jak často se ptát rádia na frekvenci a mód, když se ani jedno nemění. Ponechte prázdné pro ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Celé číslo milisekund, ${min} až ${max}';
	@override String get advancedSettings => 'Pokročilé nastavení';
	@override String get placeholderSwr => 'Hodnota PSV';
	@override String get placeholderSwrDescription => 'Co toto rádio hlásí na měřidle PSV během vysílání. Nad 1,8 panel varuje.';
	@override String get placeholderSwrInvalid => 'Číslo, 1 nebo více';
	@override String get keyerNone => 'Žádný';
	@override String get cwDialect => 'Dialekt klíčování CW';
	@override String get cwDialectDescription => 'Jakou podobu příkazu KY toto rádio přijímá. Žádný znamená bez klíčování CW přes CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, doplněno na 24)';
	@override String get cwDialectElecraft => 'Elecraft (KY text)';
	@override String get voiceDialect => 'Dialekt hlasového klíčovače';
	@override String get voiceDialectDescription => 'Jak toto rádio přehrává své hlasové paměti přes CAT. Žádný znamená bez hlasových pamětí přes CAT. S dialektem a bez počtu platí výchozí počet dialektu.';
	@override String get voiceDialectPb => 'Kenwood (PB, styl TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB a DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (stisky tlačítek)';
	@override String get placeholderDiagnostic => 'Simulováno';
	@override String get placeholderWholeNumberInvalid => 'Musí být celé číslo, 0 nebo více';
	@override String get placeholderFreqInvalid => 'Musí být frekvence v kHz, větší než nula';
	@override String get placeholderModeInvalid => 'Musí být název módu, např. USB, CW, FT8';
	@override String get switchLayout => 'Rozložení';
	@override String get switchLayoutDescription => 'Na kterou stranu přepínače jsou zapojena vaše rádia.';
	@override String get switchLayoutRequired => 'Vyberte, jak je přepínač zapojen';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Přepínač odmítl „${command}“ (chyba ${code})';
	@override String get switchBusyTransmitting => 'Tento port vysílá — anténa nebyla změněna';
	@override String get switchNoAntenna => 'Žádná';
	@override String switchAntennaFor({required Object port}) => 'Anténa na portu ${port}';
	@override String get switchAntennaForDescription => 'Která z vašich antén je připojena k tomuto portu přepínače.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => 'Antény: ${antennas}, rádia: ${radios}';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => 'Antény: ${antennas}, 1 rádio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 anténa, rádia: ${radios}';
	@override String get switchCommonPort => 'Společný';
	@override String get dcnAddress => 'Adresa zařízení';
	@override String get dcnAddressDescription => 'Adresa nastavená na DIP přepínačích modulu. Modul koaxiálního relé má z výroby 2.';
	@override String get dcnAddressRequired => 'Musí být adresa zařízení od 1 do 99';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'řídí se daty o pásmu';
	@override String get switchPortTransmittingHint => 'vysílá — nyní nelze změnit';
	@override String get switchCurrentStateHeader => 'Aktuální stav';
	@override String get switchCurrentStateDescription => 'Na které anténě je právě každý port rádia. Změny se projeví okamžitě.';
	@override String get switchWiringHeader => 'Zapojení';
	@override String get switchPortInhibitedHint => 'vysílání zablokováno';
	@override String get rotatorAxes => 'Osy';
	@override String get rotatorAxesDescription => 'Zda se rotátor otáčí jen v azimutu, nebo i v elevaci (G-5500 a podobné).';
	@override String get rotatorAxesAzimuth => 'Jen azimut';
	@override String get rotatorAxesAzimuthElevation => 'Azimut a elevace';
	@override String get rotatorAzimuthOffset => 'Posun azimutu';
	@override String get rotatorAzimuthOffsetDescription => 'Stupně, které se přičtou k údaji ovladače, když jeho nula není skutečný sever. Otáčení se odpovídajícím způsobem opraví.';
	@override String get rotatorElevationOffset => 'Posun elevace';
	@override String get rotatorAzimuthMin => 'Nejnižší azimut';
	@override String get rotatorAzimuthMax => 'Nejvyšší azimut';
	@override String get rotatorAzimuthMaxDescription => 'Ve vlastních stupních ovladače. Nad 360 pro rotátor s přesahem, který pak volí kratší otočení.';
	@override String get rotatorElevationMin => 'Nejnižší elevace';
	@override String get rotatorElevationMax => 'Nejvyšší elevace';
	@override String get rotatorElevationMaxDescription => 'Ve vlastních stupních ovladače. Nad 90 pro rotátor, který se překlápí.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => 'Celé stupně, ${min} až ${max}';
	@override String get rotatorLimitsInvalid => 'Dolní mez musí být nižší než horní';
	@override String get rotatorPollInterval => 'Interval dotazování (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'Jak často se ptát rotátoru, kam míří. Ponechte prázdné pro ${fallback} ms.';
	@override String get rotatorAxesRequired => 'Vyberte, ve kterých osách se rotátor otáčí';
	@override String get rotatorRefused => 'Ovladač odmítl příkaz. Zkontrolujte, že je nastaven do režimu GS-232.';
	@override String get pstRotatorTroubleshooting => 'PstRotator odpovídá, až když je na to nastavený, jinak neříká vůbec nic:\n\n- **Zapněte UDP Control** v menu Setup programu PstRotator.\n- **Sjednoťte port**: Communication → UDP Control Port, 12000, pokud nebyl změněn. PstRotator odpovídá na následujícím portu (12001), který musí být na tomto zařízení volný.\n- **Připojte PstRotator k jeho ovladači.** Dokud není připojený, přes UDP neodpovídá nic.\n- **Povolte ho ve firewallu** na PC s PstRotatorem i na tomto zařízení, které naslouchá odpovědím.\n- **Na Macu, iPhonu nebo iPadu** potřebuje Ham2K Logger přístup k místní síti (Nastavení → Soukromí a zabezpečení → Místní síť).';
	@override String rotatorCurrentStateHeader({required Object position}) => 'Aktuální stav: ${position}';
	@override String get rotatorDisconnected => 'odpojeno';
	@override String rotatorAzimuthReading({required Object degrees}) => '${degrees}° azimut';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '${degrees}° az';
	@override String rotatorElevationReading({required Object degrees}) => '${degrees}° elevace';
	@override String rotatorElevationReadingShort({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNoReading => 'Čeká se, až ovladač nahlásí svou polohu…';
	@override String get rotatorNotResponding => 'neodpovídá';
	@override String rotatorHeldAtLimit({required Object heading}) => 'Otáčí se na ${heading}, kam až meze tohoto rotátoru dovolí';
	@override String get rotatorTargetAzimuth => 'Otočit na azimut';
	@override String get rotatorTargetAzimuthShort => 'Otočit na az';
	@override String get rotatorTargetElevation => 'Otočit na elevaci';
	@override String get rotatorTargetElevationShort => 'Otočit na el';
	@override String get rotatorAzimuthInvalid => 'Musí být 0 až 360';
	@override String get rotatorElevationInvalid => 'Musí být 0 až 180';
	@override String get rotatorTurn => 'Otočit';
	@override String get rotatorStop => 'Stop';
	@override String get configUnreadable => 'Uložené nastavení tohoto rádia nelze přečíst. Otevřete jeho nastavení a zadejte je znovu, nebo ho odeberte a přidejte zpět.';
	@override String get autoConnectHeld => 'HaLo přestal odpovídat, když se k tomuto rádiu naposledy připojoval, proto se tentokrát nepřipojil sám. Stiskněte Připojit a zkuste to znovu.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$cs extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Offline data';
	@override String get noFiles => 'Žádné datové soubory';
	@override String get noFilesDescription => 'Zapněte rozšíření aktivit nebo vyhledávání, abyste sem mohli stáhnout jejich offline data.';
	@override String get refresh => 'Obnovit';
	@override String get refreshing => 'Obnovování…';
	@override String get updateAll => 'Aktualizovat vše';
	@override String get updatingAll => 'Aktualizace všech datových souborů…';
	@override String get neverDownloaded => 'Nikdy nestaženo';
	@override String get updatedJustNow => 'Aktualizováno právě teď';
	@override String updatedDaysAgo({required Object days}) => 'Aktualizováno před ${days} d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Aktualizováno před ${days} d ${hours} h';
	@override String updatedHoursAgo({required Object hours}) => 'Aktualizováno před ${hours} h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Aktualizováno před ${hours} h ${minutes} min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Aktualizováno před ${minutes} min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Poslední stažení obsahovalo jen ${imported} z ${existing} záznamů a nebylo použito. Obnovením ho přijmete.';
	@override String get extensionsSection => 'Rozšíření';
}

// Path: settings.profiles
class _Translations$settings$profiles$cs extends Translations$settings$profiles$en {
	_Translations$settings$profiles$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Nenastaveno';
	@override String get personalInfo => 'Osobní údaje';
	@override String get personalInfoNote => 'Mohou být zahrnuty do vygenerovaných logů, pokud je to pro odeslání relevantní';
	@override String get name => 'Jméno';
	@override String get email => 'E-mail';
	@override String get club => 'Klub';
	@override String get arrlSection => 'Sekce ARRL';
	@override String get racSection => 'Sekce RAC';
	@override String get section => 'Sekce';
}

// Path: settings.search
class _Translations$settings$search$cs extends Translations$settings$search$en {
	_Translations$settings$search$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Vymazat';
	@override String get hint => 'Hledat v předvolbách';
}

// Path: settings.developer
class _Translations$settings$developer$cs extends Translations$settings$developer$en {
	_Translations$settings$developer$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Zapnout varování pro vývojáře, ladicí logy a nástroje.';
	@override String get experiments => 'Experimenty';
	@override String get showIdleMetrics => 'Zobrazit metriky nečinnosti';
	@override String get showIdleMetricsDescription => 'Zobrazit ve stavovém řádku, jak byl engine rozšíření za poslední sekundu nečinný. Klepnutím zobrazíte průměry za 10 a 60 sekund.';
	@override String idleMetricsReadout({required Object percent}) => '${percent}% nečinný';
	@override String get idleMetricsAverages => 'Prům. nečinnost:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}s ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} zapnutý',
		other: '${count} zapnutých',
	);
	@override String get patchTrack => 'Větev Code Push';
	@override String get patchTrackDescription => 'Který okruh aktualizací kódu přes internet toto zařízení sleduje. Odvážnější okruhy dostávají opravy dříve, ale méně otestované. Aktualizace kódu se použijí při příštím restartu.';
	@override String get trackStable => 'Stabilní';
	@override String get trackUnstable => 'Nestabilní';
	@override String get trackBleeding => 'Experimentální';
	@override String checkingTrack({required Object track}) => 'Kontrola aktualizace kódu ve větvi „${track}“…';
	@override String get patchDownloaded => 'Aktualizace kódu stažena — restartujte aplikaci, aby se použila.';
	@override String noNewPatch({required Object track}) => 'Ve větvi „${track}“ není žádná nová aktualizace kódu.';
	@override String get noPatchInstalled => 'Není nainstalována žádná aktualizace kódu — běží binárka vydání.';
	@override String runningPatch({required Object patch}) => 'Běží aktualizace kódu č. ${patch}.';
	@override String get deepLinks => 'Přímé odkazy';
	@override String get registerUrlSchemes => 'Registrovat URL schémata';
	@override String get registerUrlSchemesDescription => 'Nechat odkazy com.ham2k:// otevírat tuto kopii aplikace';
	@override String get registerUrlSchemesDone => 'Tato kopie nyní otevírá odkazy com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Registrace se nezdařila: ${error}';
	@override String get systemInformation => 'Informace o systému';
	@override String get appVersion => 'Verze aplikace';
	@override String get dataFolder => 'Složka dat';
	@override String get loading => '(načítání…)';
	@override String get panelLoadFailed => 'Tento panel nastavení nelze načíst.';
	@override String get extDevServer => 'Vývojový server rozšíření';
	@override String get extensionSettings => 'Nastavení rozšíření';
	@override String get extDevServerDescription => 'Načítat rozšíření z vývojového serveru ve vaší síti místo těch vestavěných v aplikaci a znovu je načíst při každém uložení.';
	@override String get extDevServerAddress => 'Adresa serveru';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Připojit';
	@override String get extDevServerDisconnect => 'Odpojit';
	@override String get extDevServerConnecting => 'Připojování…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Poskytuje ${count} rozšíření: ${keys}',
		other: 'Poskytuje ${count} rozšíření: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Nepřipojeno';
	@override String get extDevServerReconnect => 'Znovu připojit při spuštění';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Poslední načtení: ${key} v ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} rozšíření se nedaří sestavit',
		other: '${count} rozšíření se nedaří sestavit',
	);
	@override String get catalog => 'Katalog rozšíření';
	@override String get catalogDescription => 'Číst katalog z jiného serveru — místního při práci na samotném katalogu. Prázdné znamená catalog.ham2k.net.';
	@override String get catalogAddress => 'Adresa katalogu';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Větve hledání v katalogu';
	@override String get catalogSearchStable => 'Pouze stabilní';
	@override String get catalogSearchUnstable => 'Nestabilní nebo lepší';
	@override String get catalogSearchBleeding => 'Experimentální nebo lepší';
}

// Path: settings.about
class _Translations$settings$about$cs extends Translations$settings$about$en {
	_Translations$settings$about$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Oznámení a zprávy';
	@override String get noticesDescription => 'Oznámení a stavové zprávy';
	@override String get releaseNotes => 'Poznámky k vydání';
	@override String get copiedVersion => 'Podrobnosti o verzi zkopírovány do schránky';
}

// Path: settings.panels
class _Translations$settings$panels$cs extends Translations$settings$panels$en {
	_Translations$settings$panels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Předvolby aplikace';
	@override String get settingsDescription => 'Nastavte si aplikaci podle sebe';
	@override String get commonSettings => 'Běžné předvolby';
	@override String get syncDescription => 'Zálohujte a synchronizujte své logy mezi zařízeními';
	@override String get accountsDescription => 'Přihlašovací údaje ke službám, offline data a další';
	@override String get extensions => 'Rozšíření a funkce';
	@override String get extensionsDescription => 'Aktivity, závody, panely přehledu a další funkce';
	@override String get profilesDescription => 'Volací značka operátora a profil stanice';
	@override String get stationProfiles => 'Profily stanice';
	@override String get developerSettings => 'Nastavení pro vývojáře';
	@override String get developerSettingsDescription => 'Ladicí a vývojové nástroje';
	@override String get about => 'O aplikaci';
	@override String get aboutDescription => 'Verze, autoři a právní informace';
	@override String get unavailableTitle => 'Některá nastavení nejsou k dispozici';
	@override String get unavailableText => 'Běhové prostředí rozšíření se nespustilo, proto chybí nastavení poskytovaná rozšířeními.';
	@override String get station => 'Konfigurace stanice';
	@override String get stationDescription => 'Ovládání CAT a další možnosti';
	@override String get peers => 'Spárovaná zařízení';
	@override String get peersDescription => 'Připojte se k dalším zařízením v okolí';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$cs extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get six => '6 znaků (FN31pr)';
	@override String get eight => '8 znaků (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$cs extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get six => '6 znaků';
	@override String get eight => '8 znaků';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$cs extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'Otevřít dialog příkazů';
	@override String get toggleTheme => 'Přepnout mezi světlým a tmavým režimem';
	@override String get toggleLanguage => 'Přepnout mezi angličtinou a španělštinou';
	@override String get fontScaleUp => 'Větší písmo';
	@override String get fontScaleDown => 'Menší písmo';
	@override String get fontScaleReset => 'Normální velikost písma';
	@override String get densityLooser => 'Volnější rozložení';
	@override String get densityDenser => 'Hustší rozložení';
	@override String get densityAuto => 'Automatická hustota rozložení';
	@override String get find => 'Najít v logu';
	@override String keyerMessage({required Object n}) => 'Odeslat zprávu ${n}';
	@override String get keyboardMode => 'Zapnout nebo vypnout režim klávesnice';
	@override String get ptt => 'PTT (push to talk)';
	@override String get wipe => 'Vymazat zadávané spojení';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$cs extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'Psaní značek';
	@override String get escape => 'Zastavit vysílání, vrátit se o krok, nebo zavřít';
	@override String get enter => 'Zalogovat spojení';
	@override String get space => 'Další pole';
	@override String get tab => 'Další nebo předchozí pole';
	@override String get arrows => 'Pohyb mezi poli, ovládacími prvky a logem';
	@override String get walk => 'Listovat logem, nebo přejít na jeho začátek či konec';
	@override String get undo => 'Vrátit zpět vymazání nebo smazání';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$cs extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'Přidat zkratku';
	@override String get listening => 'Stiskněte klávesy zkratky…';
	@override String get listeningHint => 'Esc ukončí zadávání';
	@override String get add => 'Přidat';
	@override String refusedFixed({required Object keys}) => '${keys} patří polím logování nebo dialogu a nelze to změnit.';
	@override String refusedCallsign({required Object keys}) => '${keys} slouží k psaní značek. Přidejte k tomu Cmd, Ctrl nebo Alt.';
	@override String reserved({required Object keys}) => 'Systém může ${keys} zachytit dřív, než se dostane k aplikaci.';
	@override String already({required Object keys}) => '${keys} už je jednou z kláves tohoto příkazu.';
	@override String takeIt({required Object keys, required Object command}) => 'Vzít ${keys} příkazu „${command}“';
	@override String get resetDefault => 'Obnovit výchozí';
	@override String get remove => 'Odebrat';
	@override String get commandLabel => 'Příkaz';
	@override String get commandHint => 'Zadejte libovolný platný příkaz, nebo více příkazů oddělených ";"';
	@override String get removeCommand => 'Odebrat příkaz';
	@override String commandUnknown({required Object text}) => 'Žádný příkaz se nejmenuje „${text}“';
	@override String get noShortcuts => 'Zatím bez klávesy';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$cs extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'Zkratky uloženy do ${location}';
	@override String exportFailed({required Object error}) => 'Zkratky se nepodařilo exportovat: ${error}';
	@override String importPickerFailed({required Object error}) => 'Soubor se nepodařilo otevřít: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} není soubor zkratek, který tato aplikace umí přečíst: ${problem}';
	@override String problemNotYaml({required Object line}) => 'text není platný YAML (řádek ${line})';
	@override String get problemNotKeysFile => 'není to soubor klávesových zkratek Ham2K';
	@override String get problemNewerVersion => 'zapsala ho novější verze aplikace';
	@override String get problemMalformed => 'část z něj neodpovídá formátu zkratek';
	@override String get problemTooLarge => 'je příliš velký';
	@override String get importTitle => 'Importovat zkratky';
	@override String writtenOn({required Object platform}) => 'Zapsáno na ${platform}.';
	@override String get writtenOnUnknown => 'Soubor neuvádí, na jaké klávesnici byl zapsán.';
	@override String get translate => 'Čemu má každá z těchto kláves odpovídat na této klávesnici?';
	@override String get leaveOut => 'Tyto zkratky vynechat';
	@override String get replace => 'Nahradit nastavení tohoto zařízení';
	@override String get replaceHint => 'Každá zkratka, která v souboru není, se vrátí na výchozí.';
	@override String get merge => 'Přidat k nastavení tohoto zařízení';
	@override String get mergeHint => 'Zkratky ze souboru nahradí zkratky tohoto zařízení u stejných příkazů, ostatní zůstanou.';
	@override String unknown({required Object commands}) => 'V této verzi neznámé, proto vynechány: ${commands}';
	@override String unreadableChords({required Object chords}) => 'Nejsou to zkratky, proto vynechány: ${chords}';
	@override String refusedChords({required Object chords}) => 'Klávesy, které si aplikace vyhrazuje, proto vynechány: ${chords}';
	@override String conflicts({required Object keys}) => 'Po importu přiřazeny více než jednomu příkazu: ${keys}';
	@override String get importAction => 'Importovat';
	@override String get imported => 'Zkratky importovány';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$cs extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$cs extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$cs extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'Volací značky stanic';
	@override String get groupBy => 'Seskupit podle';
	@override String get period => 'Období';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$cs extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get none => 'Neseskupeno';
	@override String get date => 'Datum';
	@override String get dx => 'DX';
	@override String get unknownContinent => 'Neznámý kontinent';
	@override String get unknownEntity => 'Neznámá entita';
	@override String get unknownDate => 'Bez data';
}

// Path: home.logs.period
class _Translations$home$logs$period$cs extends Translations$home$logs$period$en {
	_Translations$home$logs$period$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => 'Tento měsíc';
	@override String get last3Months => 'Poslední 3 měsíce';
	@override String get thisYear => 'Tento rok';
	@override String get lastYear => 'Minulý rok';
	@override String get allTime => 'Za celou dobu';
	@override String get custom => 'Vlastní rozsah';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$cs extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => '– ${span}';
	@override String get custom => 'Vlastní rozsah';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$cs extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get date => 'Datum';
	@override String get time => 'Čas';
	@override String get freq => 'Frekvence';
	@override String get mode => 'Mód';
	@override String get call => 'Značka';
	@override String get name => 'Jméno';
	@override String get station => 'Stanice';
	@override String get band => 'Pásmo';
	@override String get sent => 'Odesl.';
	@override String get rcvd => 'Přij.';
	@override String get grid => 'Lokátor';
	@override String get state => 'Stát';
	@override String get country => 'Země';
	@override String get refs => 'Ref.';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$cs extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Log QSO';
	@override String get qsosDescription => 'QSO vybrané značky napříč všemi aktivitami.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Celkový počet QSO, nebo vyhledání značky vybraného QSO.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Poloha vybraného QSO.';
}

// Path: home.logs.import
class _Translations$home$logs$import$cs extends Translations$home$logs$import$en {
	_Translations$home$logs$import$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Značky: ${calls}';
	@override String get skippedOne => '1 záznam se nepodařilo přečíst';
	@override String skippedOther({required Object count}) => '${count} záznamů se nepodařilo přečíst';
	@override String get readingTitle => 'Čtení souboru ADIF…';
	@override String get checkingTitle => 'Kontrola duplicit…';
	@override String get importingTitle => 'Import QSO…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => 'Zkontrolováno ${done} z ${total}';
	@override String importingDetail({required Object imported, required Object total}) => 'Importováno ${imported} z ${total}';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$cs extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'Výchozí';
	@override String untitledName({required Object number}) => 'Rozložení ${number}';
	@override String switcherLabel({required Object name}) => 'Rozložení: ${name}';
	@override String get menuNew => 'Nové…';
	@override String get menuExport => 'Exportovat…';
	@override String get menuImport => 'Importovat…';
	@override String get menuTitle => 'Rozložení';
	@override String get newTitle => 'Nové rozložení';
	@override String get editTitle => 'Upravit rozložení';
	@override String get edit => 'Upravit';
	@override String get duplicateCurrent => 'Duplikovat aktuální rozložení';
	@override String get startFromDefault => 'Začít z výchozího rozložení';
	@override String get nameLabel => 'Název';
	@override String get descriptionLabel => 'Popis';
	@override String get create => 'Vytvořit';
	@override String leaveEditTitle({required Object name}) => 'Uložit změny v „${name}“?';
	@override String get leaveEditBody => 'Toto rozložení má neuložené změny.';
	@override String get discard => 'Zahodit';
	@override String get deleteTitle => 'Smazat toto rozložení?';
	@override String deleteBody({required Object name}) => 'Opravdu chcete smazat rozložení „${name}“?';
	@override String get exportTitle => 'Exportovat rozložení';
	@override String get exportPick => 'Panely k exportu';
	@override String get tabSet => 'Sada záložek';
	@override String get exportAction => 'Exportovat';
	@override String exported({required Object location}) => 'Rozložení uloženo do ${location}';
	@override String exportFailed({required Object error}) => 'Rozložení se nepodařilo exportovat: ${error}';
	@override String get importTitle => 'Importovat rozložení';
	@override String importFromOtherView({required Object view}) => 'Vytvořeno pro zobrazení ${view}: panely, které má jen toto zobrazení, jsou vynechány.';
	@override String get viewHome => 'Domů';
	@override String get viewOperation => 'Aktivita';
	@override String get viewLogs => 'Logy';
	@override String get viewChase => 'Lovení';
	@override String get importAsNew => 'Jako nové rozložení';
	@override String get importReplace => 'Místo tohoto rozložení';
	@override String get importAdd => 'Přidáno do tohoto rozložení';
	@override String get importAddHint => 'Panely se objeví v novém sloupci vpravo.';
	@override String get importPick => 'Panely k importu';
	@override String get importReplaceSettings => 'Nahradit nastavení panelů, které už jsou zde nastavené';
	@override String get importAction => 'Importovat';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename} není rozložení, které tato aplikace umí přečíst: ${problem}';
	@override String problemNotYaml({required Object line}) => 'text není platný YAML (řádek ${line})';
	@override String get problemNotLayoutFile => 'není to soubor rozložení Ham2K';
	@override String get problemNewerVersion => 'zapsala ho novější verze aplikace';
	@override String get problemNoArrangement => 'neobsahuje žádné uspořádání';
	@override String get problemMalformed => 'část z něj neodpovídá formátu rozložení';
	@override String get problemTooLarge => 'je příliš velký';
	@override String importPickerFailed({required Object error}) => 'Soubor se nepodařilo otevřít: ${error}';
	@override String importFailed({required Object error}) => 'Rozložení se nepodařilo importovat: ${error}';
	@override String duplicateFailed({required Object error}) => 'Rozložení se nepodařilo zkopírovat: ${error}';
	@override String get importNothing => 'Nebyl vybrán žádný panel, nic se tedy neimportovalo.';
	@override String importSkipped({required Object panels}) => 'Vynecháno: ${panels}';
	@override String importKeptPinned({required Object panels}) => '${panels} ponecháno: uspořádání pro malé obrazovky se bez něj neobejde.';
	@override String get notOffered => 'V tomto zobrazení není k dispozici';
	@override String get alreadyPlaced => 'Už je v tomto rozložení';
	@override String needsExtension({required Object name}) => 'Vyžaduje ${name}';
	@override String get listRecoveredTitle => 'Názvy rozložení nelze přečíst';
	@override String get listRecoveredBody => 'Seznam rozložení tohoto zobrazení nelze přečíst. Všechna rozložení jsou stále k dispozici, místo názvu mají číslo.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$cs extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Log a vstupní pole';
	@override String get infoDescription => 'Co víme o protistanici';
	@override String get spotsDescription => 'Spoty z clusterů a aktivačních programů';
	@override String get mapDescription => 'Kde jsou spojení';
	@override String get summariesDescription => 'Statistiky a bodování aktivity, v sekcích a pořadí podle vašeho výběru';
	@override String get summariesSections => 'Sekce a pořadí';
	@override String get summariesDays => 'Každý den';
	@override String get summariesReset => 'Zobrazit vše';
	@override String get summariesAllHidden => 'Všechny sekce jsou skryté. Které zobrazit, vyberte v nastavení tohoto panelu.';
	@override String get clockDescription => 'Ciferník v libovolném časovém pásmu';
	@override String get clockFace => 'Ciferník';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analogový';
	@override String get clockZone => 'Časové pásmo';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Toto zařízení';
	@override String get clockShowSeconds => 'Zobrazit sekundy';
	@override String get weatherDescription => 'Aktuální podmínky a předpověď na příštích osm hodin v místě provozu';
	@override String get weatherUseOperationLocation => 'Použít polohu aktivity';
	@override String get weatherLocation => 'Poloha';
	@override String get weatherLocationDescription => 'Lokátor (FN31pr) nebo šířka,délka. Ignoruje se, když je zaškrtnuto „Použít polohu aktivity“.';
	@override String get weatherNoLocation => 'Poloha není nastavena. Zadejte polohu v nastavení panelu, nebo panel umístěte do aktivity, která ji má.';
	@override String weatherBadLocation({required Object location}) => 'Polohu ${location} nelze přečíst. Použijte lokátor jako FN31pr, nebo 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo je nedostupné — chybí síť? Brzy to zkusíme znovu.';
	@override String get weatherUnreadable => 'Open-Meteo odpovědělo, ale ničím čitelným. Brzy to zkusíme znovu.';
	@override String weatherGusts({required Object speed}) => 'nárazy ${speed}';
	@override String get panelAgeNow => 'právě teď';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'před ${count} min',
		other: 'před ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'před ${count} hod',
		other: 'před ${count} hod',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$cs weatherConditions = _Translations$operation$layout$panels$weatherConditions$cs._(_root);
	@override String get websiteDescription => 'Webová stránka dle vašeho výběru v panelu';
	@override String get websiteUrl => 'Adresa';
	@override String get websiteRefresh => 'Obnovování';
	@override String get websiteRefreshNever => 'Nikdy';
	@override String get websiteRefresh1 => 'Každou minutu';
	@override String get websiteRefresh5 => 'Každých 5 minut';
	@override String get websiteRefresh15 => 'Každých 15 minut';
	@override String get websiteTitle => 'Název panelu';
	@override String get websiteRefreshNow => 'Obnovit nyní';
	@override String get websiteNoUrl => 'Zatím bez adresy. Stránku vyberte v nastavení tohoto panelu.';
	@override String get websiteBadUrl => 'Toto nevypadá jako webová adresa. Musí začínat https://';
	@override String get websiteNotHttps => 'Zde lze zobrazit pouze https:// adresy.';
	@override String get websiteUnsupported => 'Na tomto systému nelze webové stránky zobrazit v panelu.';
	@override String get websiteOpenExternally => 'Otevřít v prohlížeči';
	@override String websiteLoadFailed({required Object reason}) => 'Stránku nelze načíst: ${reason}';
	@override String get remoteScreenDescription => 'Obrazovka, aplikace nebo okno sdílené jiným z vašich zařízení.';
	@override String get remoteScreenTarget => 'Obrazovka';
	@override String get remoteScreenChoose => 'Vyberte obrazovku…';
	@override String get remoteScreenPickerTitle => 'Sdílené obrazovky';
	@override String get remoteScreenPickerEmpty => 'Žádné z vašich zařízení nesdílí obrazovku. Zapněte Sdílet obrazovky a okna v Nastavení → Spárovaná zařízení na zařízení, které chcete vidět.';
	@override String get remoteScreenUnset => 'Není vybrána žádná obrazovka. V nastavení tohoto panelu vyberte jednu z těch, které sdílejí vaše další zařízení.';
	@override String get remoteScreenConnecting => 'Připojování…';
	@override String get remoteScreenPeerAway => 'Toto zařízení teď není připojeno.';
	@override String get remoteScreenNotOffered => 'Toto zařízení přestalo tuto obrazovku sdílet.';
	@override String get remoteScreenNoListener => 'Toto zařízení nepřijímá připojení — zkontrolujte jeho firewall.';
	@override String get remoteScreenNoLan => 'Obrazovky se sdílejí jen přes místní síť, ne přes Bluetooth.';
	@override String get remoteScreenRefused => 'Toto zařízení odmítlo tuto obrazovku sdílet.';
	@override String get remoteScreenSettings => 'Nastavení panelu';
	@override String get remoteScreenAdjust => 'Upravit zobrazení';
	@override String get remoteScreenDetail => 'Detail';
	@override String get remoteScreenDetailStandard => 'Standardní';
	@override String get remoteScreenDetailHigh => 'Vysoký';
	@override String get remoteScreenDetailMaximum => 'Maximální';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Přiblížit';
	@override String get remoteScreenZoomOut => 'Oddálit';
	@override String get remoteScreenStopped => 'Tato obrazovka nebo okno se už nezobrazuje.';
	@override String get remoteScreenCaptureFailed => 'Toto zařízení nemohlo obrazovku zachytit — možná potřebuje oprávnění k nahrávání obrazovky.';
	@override String get remoteScreenNoAnswer => 'Toto zařízení neodpovědělo. Možná nemá zapnuté sdílení obrazovky.';
	@override String get remoteScreenNoMedia => 'Nelze otevřít spojení pro obraz. Zkontrolujte firewall na tomto zařízení.';
	@override String get solarDescription => 'Sluneční a geomagnetické podmínky se šířením pro jednotlivá pásma';
	@override String get solarUnreachable => 'hamqsl.com je nedostupné — chybí síť? Brzy to zkusíme znovu.';
	@override String get solarUnreadable => 'hamqsl.com odpovědělo, ale ne údaji, které bychom mohli použít. Brzy to zkusíme znovu.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Den';
	@override String get solarBandNight => 'Noc';
	@override String get solarBandGood => 'Dobré';
	@override String get solarBandFair => 'Průměrné';
	@override String get solarBandPoor => 'Špatné';
	@override String solarSources({required Object primary, required Object secondary}) => 'Zdroje: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Spojení má potíže — vynechávají se snímky.';
	@override String get remoteScreenStalled => 'Snímky přestaly procházet — spojení může být příliš pomalé.';
	@override String get radioDescription => 'Přední panel rádia — frekvence, mód a výkon, ovládané přes CAT';
	@override String get radioStyle => 'Styl';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderní';
	@override String get radioRadio => 'Rádio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — není určeno žádné rádio';
	@override String get radioNoRadio => 'Žádné rádio k zobrazení. Vyberte ho v nastavení tohoto panelu, nebo ho přidejte v Konfiguraci stanice.';
	@override String get radioNotConfigured => 'Toto rádio zatím není nakonfigurováno. Vyberte jeho port nebo adresu v Konfiguraci stanice.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Rádio není připojeno';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Připojit toto rádio';
	@override String get radioDisconnect => 'Odpojit toto rádio';
	@override String get radioStale => 'BEZ DAT';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'PSV';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'vysoké PSV';
	@override String get rotatorDescription => 'Kam míří anténa, na mapě se středem ve stanici. Klepnutím na mapu ji otočíte.';
	@override String get rotatorRotator => 'Rotátor';
	@override String rotatorAutoNamed({required Object name}) => 'Automaticky — ${name}';
	@override String get rotatorAutoNone => 'Automaticky — zatím žádný rotátor';
	@override String get rotatorBeamWidth => 'Šířka svazku';
	@override String get rotatorBeamWidthDescription => 'Ve stupních, vykreslí se kolem směru. 0 nevykreslí nic.';
	@override String get rotatorLocation => 'Poloha';
	@override String get rotatorLocationDescription => 'Lokátor nebo zeměpisná šířka a délka, na které se mapa vystředí. Prázdné použije polohu aktivity.';
	@override String get rotatorTheme => 'Téma';
	@override String get rotatorThemeColor => 'Barevné';
	@override String get rotatorThemeGray => 'Šedé';
	@override String get rotatorThemeMuted => 'Tlumené';
	@override String get rotatorGrayline => 'Zobrazit šedou linii';
	@override String get rotatorNoRotator => 'Žádný rotátor k zobrazení. Vyberte ho v nastavení tohoto panelu, nebo ho přidejte v Konfiguraci stanice.';
	@override String get rotatorNoLocation => 'Není poloha, na kterou mapu vystředit. Nastavte ji v nastavení tohoto panelu.';
	@override String get rotatorDisconnected => 'odpojeno';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => 'neodpovídá';
	@override String get rotatorLocationInvalid => 'Polohu v nastavení tohoto panelu nelze přečíst. Použijte lokátor, nebo zeměpisnou šířku a délku jako 40.7, -74.0.';
	@override String rotatorElevation({required Object degrees}) => '${degrees}° el';
	@override String get rotatorNorth => 'S';
	@override String get rotatorEast => 'V';
	@override String get rotatorSouth => 'J';
	@override String get rotatorWest => 'Z';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$cs extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Použít kompaktní názvy souborů';
	@override String get descriptionOn => 'Krátké názvy pro nahrávací nástroje, např. N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Čitelné názvy, např. 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$cs extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zahrnout soukromé údaje';
	@override String get descriptionOn => 'Jména, adresy, e-maily, lokátory a poznámky jsou zahrnuty';
	@override String get descriptionOff => 'Jména, adresy, e-maily, lokátory a poznámky jsou vynechány';
	@override String get note => 'Úplný export ADIF vždy zahrnuje vše';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$cs extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Nejprve přidejte e-mailovou adresu';
	@override String get needsEmailBody => 'Ham2K File Stash posílá vaše soubory na e-mailovou adresu vašeho účtu LoFi a stejnou adresou se přihlašujete na stash.ham2k.net. Váš účet zatím nemá potvrzenou adresu — přidejte ji v Nastavení › Synchronizace v cloudu.';
	@override String get openSyncSettings => 'Otevřít synchronizaci v cloudu';
	@override String get replaceTitle => 'Nedávná úschova bude nahrazena';
	@override String replaceBody({required Object name}) => '„${name}“ jste odeslali před méně než 6 hodinami a ještě nebyl stažen. Bezplatné účty mají najednou jen jednu úschovu, takže odeslání nyní ji nahradí.';
	@override String get replaceConfirm => 'Přesto odeslat';
	@override String get failedTitle => 'Nepodařilo se odeslat do Ham2K File Stash';
	@override String get sentTitle => 'Odesláno do Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Tento soubor můžete získat návštěvou **[stash.ham2k.net](https://stash.ham2k.net)** v libovolném prohlížeči.',
		other: 'Tyto soubory můžete získat návštěvou **[stash.ham2k.net](https://stash.ham2k.net)** v libovolném prohlížeči.',
	);
	@override String get mayHaveArrived => 'Úschovna neodpověděla — soubor možná přesto dorazil. Než ho pošlete znovu, zkontrolujte stash.ham2k.net';
	@override String get notSent => 'neodesláno';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: 'Tento soubor nedorazil:',
		other: 'Těchto ${count} souborů nedorazilo:',
	);
	@override String get emailOffer => 'Nebo vám pro vaše pohodlí můžeme poslat e-mail s přímým odkazem.';
	@override String get emailMe => 'Poslat mi odkaz e-mailem';
	@override String get emailSent => 'Poslali jsme vám e-mailem odkaz ke stažení.';
	@override String emailFailed({required Object error}) => 'E-mail se nepodařilo odeslat: ${error}';
	@override String get freeTier => 'Bezplatné účty mohou mít najednou pouze jednu úschovu. Předplatitelé jich mohou mít, kolik chtějí.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count,
		one: '${count} soubor odeslán do Ham2K File Stash (stash.ham2k.net)',
		other: '${count} souborů odesláno do Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$cs extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Asie';
	@override String get eu => 'Evropa';
	@override String get na => 'Severní Amerika';
	@override String get oc => 'Oceánie';
	@override String get sa => 'Jižní Amerika';
	@override String get an => 'Antarktida';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$cs extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrovat spoty';
	@override String get band => 'Pásmo';
	@override String get mode => 'Mód';
	@override String get age => 'Stáří';
	@override String get sources => 'Zdroje';
	@override String get continent => 'Kontinent';
	@override String get sorting => 'Řazení';
	@override String get sortByTime => 'Podle času spotu';
	@override String get sortByFrequency => 'Podle frekvence';
	@override String get sortByWanted => 'Nejžádanější';
	@override String get groupByBand => 'Seskupit podle pásma';
	@override String get groupCallsWithNotes => 'Seskupit značky s poznámkami';
	@override String get alertingOnly => 'Jen spoty s upozorněním';
	@override String get sourceNoReply => 'Bez odpovědi';
	@override String get sourceError => 'Chyba';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$cs extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Panel logování je zaneprázdněný';
	@override String get editingBody => 'Upravujete zalogované spojení. Zalogovat místo toho tento spot, nebo se vrátit a dokončit úpravu?';
	@override String get composingBody => 'Začali jste zadávat spojení. Zalogovat místo toho tento spot, nebo se vrátit a dokončit, co jste psali?';
	@override String get goBack => 'Vrátit se';
	@override String get clearAndLog => 'Vymazat a zalogovat spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$cs extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Režim pro leváky';
	@override String get descriptionOn => 'Používá se rozložení pro leváky';
	@override String get descriptionOff => 'Používá se rozložení pro praváky';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$cs extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vlajky zemí';
	@override String get dx => 'Zobrazit pouze pro DX spojení';
	@override String get all => 'Zobrazit vlajky pro všechna spojení';
	@override String get none => 'Nezobrazovat žádné vlajky';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$cs extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Vlajky se zobrazují pouze pro DX spojení';
	@override String get all => 'Zobrazují se vlajky pro všechna spojení';
	@override String get none => 'Nezobrazují se žádné vlajky';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$cs extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Navrhovat operátora';
	@override String get descriptionOn => 'Nabízí vaši značku jako operátora, když aktivita probíhá pod jinou značkou stanice';
	@override String get descriptionOff => 'Operátor zůstává prázdný, dokud ho nevyplníte';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$cs extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobrazit azimut';
	@override String get descriptionOn => 'Zobrazuje se odhadovaný azimut k protistanici';
	@override String get descriptionOff => 'Informace o azimutu se nezobrazují';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$cs extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobrazit také zpětný azimut';
	@override String get descriptionOn => 'Zobrazuje se také azimut od protistanice, jako "45° / 225°"';
	@override String get descriptionOff => 'Zobrazuje se pouze azimut k protistanici';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$cs extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Přepnout pořadí reportu';
	@override String get sentFirst => 'Odeslaný první, přijatý druhý';
	@override String get rcvdFirst => 'Přijatý první, odeslaný druhý';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$cs extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Přejít na další pole po zadání RST';
	@override String get descriptionOn => 'Po zadání RST se přechází dál';
	@override String get descriptionOff => 'Automaticky se nepřechází';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$cs extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Výchozí report — fónie';
	@override String get description => 'Použije se, když je Odesl. nebo Přij. prázdné u SSB, FM nebo AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$cs extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Výchozí report — CW a data';
	@override String get description => 'Použije se, když je Odesl. nebo Přij. prázdné u CW, RTTY a dalších datových módů';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$cs extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Výchozí report — FT8 a FT4';
	@override String get description => 'Použije se, když je Odesl. nebo Přij. prázdné u módů FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$cs extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Řádek čísel';
	@override String get description => 'Při logování zobrazit nad klávesnicí řádek číselných kláves';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$cs extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Klávesa lomítka a tečky';
	@override String get description => 'Přidá kontextovou klávesu: „/“ pro značky, „.“ pro čísla';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$cs extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrovat při stisku klávesy';
	@override String get description => 'Hmatová odezva při klepnutí na číselnou klávesu';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$cs extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get off => 'Vypnuto';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$cs extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'chybí volací značka operátora pro přihlášení';
	@override String get connectFailed => 'uzel je nedostupný';
	@override String get needsPassword => 'uzel vyžaduje heslo a žádné není uloženo';
	@override String get loginFailed => 'uzel přihlášení nepřijal';
	@override String get disconnected => 'uzel ukončil spojení';
	@override String get timeout => 'uzel neodpověděl';
	@override String get off => 'Připojovat se ke clusteru je vypnuto';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$cs extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$cs extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ovládat PTT klávesnicí';
	@override late final _Translations$settings$radio$pttKey$modes$cs modes = _Translations$settings$radio$pttKey$modes$cs._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$cs descriptions = _Translations$settings$radio$pttKey$descriptions$cs._(_root);
	@override String get key => 'Klávesa PTT';
	@override String get pill => 'TX';
	@override String get transmitting => 'Vysílání';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$cs extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chytré zaokrouhlení VFO';
	@override String get descriptionOn => 'Když přestanete otáčet knoflíkem, frekvence se zaokrouhlí na rozumný krok. Pouze hlasové módy.';
	@override String get descriptionOff => 'Zůstává přesně tam, kam jste naladili.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$cs extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chytré zaokrouhlení: Prodleva ustálení';
	@override String get description => 'Jak dlouho musí knoflík stát, než se frekvence zaokrouhlí. Kratší působí okamžitě, delší nechává prostor pro pomalý pohyb.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$cs extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chytré zaokrouhlení: Dlouhý posun';
	@override String get description => 'Při posunu alespoň o tolik se frekvence zaokrouhlí na celé kHz, ať jste skončili jakkoli pomalu.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$cs extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chytré zaokrouhlení: Nejmenší posun';
	@override String get description => 'Při posunu o méně než tolik se frekvence nezaokrouhlí, takže jemné ladění zůstane beze změny.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$cs extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Chytré zaokrouhlení: Nejpomalejší posun';
	@override String get description => 'Při otáčení knoflíkem pomaleji než tolik se frekvence nezaokrouhlí, pokud nešlo o dlouhý posun.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$cs extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM vyp.';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter odesílá zprávy';
	@override String get off => 'Vypnuto';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter odesílá zprávy: ${state}. Klepnutím změníte.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$cs extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Rychlost klíčovače';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$cs extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zprávy CW klíčovače';
	@override String get notSupported => 'Aktuální rádio nepodporuje klíčování CW';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Zpráva ${n}';
	@override String get labelField => 'Popisek';
	@override String labelKey({required Object n}) => 'Popisek F${n}';
	@override String get details => 'Podrobnosti';
	@override String get empty => '(prázdné)';
	@override String get sets => 'Sada zpráv';
	@override String get newSet => 'Nová sada';
	@override String get renameSet => 'Přejmenovat sadu';
	@override String get deleteSet => 'Smazat sadu';
	@override String get newSetName => 'Název';
	@override String get setDefault => 'Výchozí';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Zprávy ESM';
	@override String get setSaved => 'Moje zprávy';
	@override String get repeat => 'Opakovat zprávu 1';
	@override String get repeatShort => 'Opakovat M1';
	@override String get cooldown => 'Prodleva před opakováním';
	@override String cooldownSeconds({required Object n}) => '${n} sekund';
	@override String get repeatWait => 'Opakování';
	@override String get keyboard => 'Pište a odesílejte';
	@override String get keyboardField => 'Pište a odesílejte';
	@override String get help => 'Nápověda';
	@override String get helpTitle => 'Psaní CW zpráv';
	@override String get helpIntro => 'Zprávy mohou používat šablony s těmito hodnotami:';
	@override String get helpOpCall => 'Vaše volací značka';
	@override String get helpQsoCall => 'Značka protistanice — v zásobníku // značka, která bude zalogována';
	@override String get helpQsoFullCall => 'Značka protistanice, pokud je platná; prázdné pro částečnou';
	@override String get helpQsoPartial => 'Částečná značka; prázdné, pokud je zadána úplná platná značka';
	@override String get helpQsoNextCall => 'V zásobníku // značka, která bude vybrána k zalogování jako další, pokud je platná a úplná';
	@override String get helpQsoNextPartial => 'V zásobníku // další částečná značka po zalogování aktuálního spojení';
	@override String get helpQsoName => 'Křestní jméno protistanice, jak bylo zadáno, jinak z vyhledávání';
	@override String get helpQsoState => 'Stát protistanice, jak byl zadán, jinak z vyhledávání';
	@override String get helpKeyerMsg => 'Zpráva 1 tak, jak by byla odeslána, uvnitř jiné zprávy. Platí pro zprávy 1 až 8';
	@override String get helpQsoRst => 'Report, který odesíláte';
	@override String get helpQsoSerial => 'Vaše pořadové číslo v závodě, kde se odesílá';
	@override String get helpPad => 'Doplní nulami na daný počet číslic: 7 se odešle jako 007';
	@override String get helpCut => 'Zkrácená čísla, T za 0 a N za 9: 599 se odešle jako 5NN';
	@override String get helpCutDigits => 'Určí číslice ke zkrácení, v uvozovkách — 0 je T, 1 je A, 5 je E, 9 je N';
	@override String get helpFullExample => 'Úplný příklad:';
	@override String get helpExample => 'Odešle W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Když je zapnuto Enter odesílá zprávy, klávesa Enter vysílá zprávy podle jejich funkční klávesy, stejně jako N1MM. Sada Zprávy ESM začíná těmito:';
	@override String get helpEsmCq => 'Při Run zavolá Enter s prázdným polem značky výzvu CQ';
	@override String get helpEsmExchange => 'Vaše výměna: po jejich značce při Run, po jejich odpovědi při S&P';
	@override String get helpEsmThanks => 'Poděkování po zalogování spojení: qso je zalogované spojení, next to následující';
	@override String get helpEsmMyCall => 'Při S&P vaše značka pro stanici, které odpovídáte';
	@override String get helpEsmHisCall => 'Při Run jejich značka před vaší výměnou';
	@override String get helpEsmAgain => 'Žádá o opakování, když z jejich výměny nebylo nic přijato';
	@override String get helpEsmStackThanks => 'Doporučené F3 pro zásobníky //: poděkuje, pak zavolá další stanici v zásobníku a odešle vaši výměnu, nebo se zeptá na částečnou značku (TU KR?); když už nic nezbývá, jen TU';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$cs extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get label => 'Klíčovač';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => 'Hlas';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$cs extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zprávy hlasového klíčovače';
	@override String get notSupported => 'Aktuální rádio nepodporuje hlasové zprávy';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Hlasová paměť ${n}';
	@override String get labelField => 'Popisek';
	@override String labelKey({required Object n}) => 'Popisek hlasové paměti ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Prázdná';
	@override String get notMeasured => 'Neznámá délka';
	@override String get playButton => 'Přehrát';
	@override String get recordButton => 'Nahrát';
	@override String get stopButton => 'Stop';
	@override String get repeat => 'Opakovat zprávu 1';
	@override String recordHelpTitle({required Object model}) => 'Poznámky k ${model}:';
	@override String namedOnDevice({required Object device}) => 'Tyto paměti jsou v rádiu zařízení ${device}. Jejich názvy a délky patří tomuto zařízení.';
	@override String get namedOnRadio => 'Uloženo v rádiu, kde to vidí i jeho další klienti.';
	@override String get recordHelpYaesuDvs => 'Počkejte na indikátor [REC] na rádiu, pak podržte tlačítko PTT a nahrajte zprávu. Ukončete ji stisknutím tlačítka STOP zde v aplikaci ještě před uvolněním PTT, abyste se vyhnuli nechtěným cvaknutím.';
	@override String get recordHelpFt891 => 'Počkejte, až indikátor [REC] alespoň čtyřikrát blikne, pak podržte tlačítko PTT a nahrajte zprávu. Ukončete ji stisknutím tlačítka STOP zde v aplikaci ještě před uvolněním PTT, abyste se vyhnuli nechtěným cvaknutím.';
	@override String get pill => 'Hlas';
	@override String play({required Object n}) => 'Přehrát paměť ${n}';
	@override String get stop => 'Stop';
	@override String record({required Object n}) => 'Nahrát paměť ${n}';
	@override String get stopRecording => 'Zastavit nahrávání';
	@override String get playing => 'Přehrávání…';
	@override String get recording => 'Nahrávání…';
	@override String recordingMemory({required Object label}) => 'Nahrává se ${label}';
	@override String get doubtful => 'Přehrálo to rádio? Hned hlásilo, že je nečinné.';
	@override String get recordOnRadio => 'Paměti musíte nahrát přímo na rádiu.';
	@override String get sets => 'Sada zpráv';
	@override String get soundFilesSet => 'Zvukové soubory na tomto počítači';
	@override String get openFileButton => 'Otevřít soubor';
	@override String get newSet => 'Nová sada';
	@override String get renameSet => 'Přejmenovat sadu';
	@override String get deleteSet => 'Smazat sadu';
	@override String get newSetName => 'Název';
	@override String deleteSetConfirm({required Object name}) => 'Smazat ${name} a její nahrávky? Nelze to vrátit zpět.';
	@override String get output => 'Odesílat zvuk do';
	@override String get input => 'Nahrávat z';
	@override String get outputRadio => 'Odesílat do rádia přes síť';
	@override String get inputDefault => 'Výchozí systému';
	@override String get pickDevice => 'Vyberte zvukové zařízení';
	@override String deviceMissing({required Object name}) => '${name} (nepřipojeno)';
	@override String get lead => 'Prodleva po zaklíčování';
	@override String get tail => 'Prodleva před odklíčováním';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => 'Poslechnout';
	@override String get notRecorded => 'Nenahráno';
	@override String get unplayable => 'Tento soubor nelze přehrát';
	@override String get problemNoOutput => 'Před přehráním zprávy vyberte zvukové zařízení, které vede do rádia.';
	@override String get problemOutputMissing => 'Zvukové zařízení, které vede do rádia, není připojeno.';
	@override String get problemInputMissing => 'Nahrávací zařízení není připojeno.';
	@override String get problemDeviceFailed => 'Zvukové zařízení se nepodařilo otevřít.';
	@override String get problemNotRecorded => 'Tato zpráva zatím nemá nahrávku.';
	@override String get problemRecordingSilent => 'Z nahrávacího zařízení nebylo nic slyšet, zpráva proto zůstala beze změny. Zkontrolujte vstup a to, že aplikace smí používat mikrofon.';
	@override String get problemRadioAudioUnavailable => 'Rádio teď nebere zvuk z aplikace. Je potřeba síťové připojení k rádiu.';
	@override String get problemSourceRefused => 'Rádio nepřepnulo vysílaný zvuk na aplikaci, zpráva se proto zastavila. Nastavte rádio tak, aby vysílalo zvuk z aplikace.';
	@override String get problemCannotKey => 'Toto rádio nelze klíčovat přes CAT, počítač do něj tedy nemůže přehrávat zprávy.';
	@override String get problemUnplayable => 'Soubor této zprávy není zvukový soubor, který aplikace umí přehrát. Použijte soubor WAV, FLAC nebo MP3, nebo ji nahrajte znovu.';
	@override String get problemRecordingFailed => 'Nahrávání bylo předčasně ukončeno, zpráva proto zůstala beze změny. Zkontrolujte, že je nahrávací zařízení stále připojeno a že je na disku místo.';
	@override String get problemFileFailed => 'Nahrávku se nepodařilo uložit na místo zprávy, zpráva proto zůstala beze změny.';
	@override String problemWordsMissing({required Object words}) => 'Tato zpráva potřebuje slova, která jste nenahráli: ${words}.';
	@override String problemTemplateFailed({required Object error}) => 'Šablona této zprávy má problém: ${error}';
	@override String get problemNoOperation => 'Zprávy namluvené vašimi slovy se přehrávají v aktivitě, kde je spojení, pro které je říct.';
	@override String get problemNothingSaid => 'Tato zpráva pro toto spojení nic neříká.';
	@override String get templateField => 'Říct mými slovy';
	@override String get templateHelp => 'Nechte prázdné, aby se přehrála nahrávka. Jinak se zpráva řekne slovy, která jste nahráli, doplněnými pro každé spojení podle těchto hodnot:';
	@override String get help => 'Nápověda';
	@override String get helpTitle => 'Říkání zpráv vašimi slovy';
	@override String get helpFullExample => 'Celá zpráva:';
	@override String get helpExample => 'Značka protistanice, její report a vaše nahrávka „QSL?“';
	@override String get playOnRadio => 'Přehrát na rádiu';
	@override String get templateHelpCall => 'Značka protistanice';
	@override String get templateHelpReport => 'Report, který jí dáváte';
	@override String get templateHelpMessage => 'Nahrávka zprávy 2, přehraná tak, jak byla nahrána';
	@override String get voiced => 'Řečeno vašimi slovy';
	@override String willSay({required Object words}) => 'Řekne: ${words}';
	@override String willSayMissing({required Object words}) => 'Zatím nenahráno: ${words}';
	@override String get previewNoOperation => 'Otevřete aktivitu, abyste viděli, co řekne.';
	@override String get wordsDescription => 'Použijte vlastní hlas pro značky, čísla a další.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$cs extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nahrávky slov';
	@override String get callField => 'Slova pro operátora';
	@override String get intro => 'Každé slovo nebo číslo nahrajte třikrát, rychle za sebou, tak jak ho říkáte ve volací značce. Delší fráze se nahrávají jen jednou.';
	@override String get recordAll => 'Nahrát vše';
	@override String get recordAllGuide => 'Každé slovo přečtěte třikrát za sebou a frázi o několika slovech jednou, s nádechem mezi řádky. Po posledním stiskněte Stop.';
	@override String recordingOne({required Object word}) => 'Řekněte „${word} ${word} ${word}“ a pak stiskněte Stop.';
	@override String recordingOnce({required Object words}) => 'Řekněte „${words}“ a pak stiskněte Stop.';
	@override String get recorded => 'Nahráno';
	@override String get notRecorded => 'Nenahráno';
	@override String get addPhrase => 'Přidat frázi';
	@override String get phraseField => 'Fráze tak, jak ji píšete ve zprávě';
	@override String get deletePhrase => 'Smazat frázi';
	@override String get tryField => 'Zkuste říct';
	@override String get pauseLetters => 'Pauza mezi písmeny';
	@override String get pauseWords => 'Pauza mezi slovy';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => 'Rychlost';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => 'Pokročilé nastavení';
	@override String get splitSilent => 'V nahrávce nebylo nic slyšet.';
	@override String get splitNotThreeTakes => 'Nepodařilo se najít tři opakování. Řekněte slovo třikrát za sebou a zkuste to znovu.';
	@override String get splitLineCount => 'V nahrávce se nepodařilo najít všechna slova. Každé přečtěte třikrát, s nádechem mezi slovy.';
	@override String get splitLinesTooClose => 'Slova se nepodařilo rozlišit. Nechte mezi slovy delší nádech.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$cs extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vyhnout se nulovým záznějům na spotech';
	@override String get descriptionOn => 'S připojeným rádiem naladí pár Hz vedle CW spotu, aby všichni, kdo odpovídají, nevolali na stejném tónu.';
	@override String get descriptionOff => 'Ladí přesně na spotovanou frekvenci.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$cs extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Nulový zázněj: Rozsah odskoku';
	@override String get description => 'Jak daleko od spotované frekvence přistát, na kteroukoli stranu. Odskok není nikdy blízko nule — to by byl opět nulový zázněj.';
}

// Path: settings.map.style
class _Translations$settings$map$style$cs extends Translations$settings$map$style$en {
	_Translations$settings$map$style$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Styl mapy';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$cs extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobrazit značky';
	@override String get description => 'Každé spojení je štítek s jeho značkou v barvě pásma';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$cs extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Zobrazit šedou linii';
	@override String get description => 'Stínuje noční stranu Země, soumrak jako přechod';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$cs extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automaticky';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$cs extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sdílet údaje o používání aplikace';
	@override String get descriptionOn => 'Pomáháte nám vylepšovat aplikaci sdílením údajů o používání, konfiguraci, pádech a výkonu';
	@override String get descriptionOff => 'Údaje o používání aplikace zůstávají soukromé.\nTým Ham2K nebude moci detekovat pády ani jiné problémy.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$cs extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sdílet údaje o aktivitách';
	@override String get descriptionOn => 'Některé údaje o aktivitách se sdílejí veřejně a s ostatními uživateli';
	@override String get descriptionOff => 'Údaje o aktivitách zůstávají soukromé';
}

// Path: settings.station.models
class _Translations$settings$station$models$cs extends Translations$settings$station$models$en {
	_Translations$settings$station$models$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - obecné';
	@override String get icomGeneric => 'Icom - obecné';
	@override String get kenwoodGeneric => 'Kenwood - obecné';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - obecné';
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
	@override String get rigctld => 'Rádio ovládané přes rigctld';
	@override String get rigctldNodeName => 'Moje rádio (přes rigctld)';
	@override String get flrig => 'Rádio ovládané přes flrig';
	@override String get flrigNodeName => 'Moje rádio (přes flrig)';
	@override String get hrd => 'Rádio ovládané přes Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Moje rádio (přes HRD)';
	@override String get n3fjp => 'Rádio ovládané přes N3FJP';
	@override String get n3fjpNodeName => 'Moje rádio (přes N3FJP)';
	@override String get commander => 'Rádio ovládané přes DXLab Commander';
	@override String get commanderNodeName => 'Moje rádio (přes Commander)';
	@override String get antenna => 'Anténa';
	@override String get key => 'CW klíč';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Obecné rádio (zástupné)';
	@override String get placeholderRadioNodeName => 'Moje rádio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';
	@override String get gs232a => 'Rozhraní rotátoru Yaesu GS-232A';
	@override String get pstRotator => 'PstRotator (ovládání UDP)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$cs extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get network => 'Síť/WiFi';
	@override String get secureNetwork => 'Zabezpečená síť/WiFi';
	@override String get usbSerial => 'USB sériový';
	@override String get wifi => 'Síť/WiFi';
	@override String get bluetoothSerial => 'Bluetooth sériový';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'Zástupné';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$cs extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipól';
	@override String get vertical => 'Vertikál';
	@override String get yagiBeam => 'Yagi / směrovka';
	@override String get loop => 'Smyčka';
	@override String get longWire => 'Long Wire / EFHW';
	@override String get other => 'Jiná';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$cs extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Ruční klíč';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mechanický poloautomat)';
	@override String get fullyAutomatic => 'Plně automatický klíčovač';
	@override String get singlePaddle => 'Jednopádlový';
	@override String get dualPaddle => 'Dvoupádlový';
	@override String get computerDriven => 'Řízený počítačem';
	@override String get other => 'Jiný';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$cs extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Neznámé';
	@override String get sunny => 'Slunečno';
	@override String get clear => 'Jasno';
	@override String get mainlySunny => 'Převážně slunečno';
	@override String get mainlyClear => 'Převážně jasno';
	@override String get partlyCloudy => 'Polojasno';
	@override String get cloudy => 'Zataženo';
	@override String get foggy => 'Mlha';
	@override String get rimeFog => 'Mrznoucí mlha';
	@override String get lightDrizzle => 'Slabé mrholení';
	@override String get drizzle => 'Mrholení';
	@override String get heavyDrizzle => 'Silné mrholení';
	@override String get lightFreezingDrizzle => 'Slabé mrznoucí mrholení';
	@override String get freezingDrizzle => 'Mrznoucí mrholení';
	@override String get lightRain => 'Slabý déšť';
	@override String get rain => 'Déšť';
	@override String get heavyRain => 'Silný déšť';
	@override String get lightFreezingRain => 'Slabý mrznoucí déšť';
	@override String get freezingRain => 'Mrznoucí déšť';
	@override String get lightSnow => 'Slabé sněžení';
	@override String get snow => 'Sněžení';
	@override String get heavySnow => 'Silné sněžení';
	@override String get snowGrains => 'Sněhová zrna';
	@override String get lightShowers => 'Slabé přeháňky';
	@override String get showers => 'Přeháňky';
	@override String get heavyShowers => 'Silné přeháňky';
	@override String get lightSnowShowers => 'Slabé sněhové přeháňky';
	@override String get snowShowers => 'Sněhové přeháňky';
	@override String get thunderstorm => 'Bouřka';
	@override String get lightThunderstormsWithHail => 'Slabé bouřky s krupobitím';
	@override String get thunderstormWithHail => 'Bouřka s krupobitím';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$cs extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get off => 'Ne';
	@override String get toggle => 'Přepínat';
	@override String get hold => 'Držet';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$cs extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$cs._(TranslationsCs root) : this._root = root, super.internal(root);

	final TranslationsCs _root; // ignore: unused_field

	// Translations
	@override String get off => 'Klávesnice rádio neklíčuje.';
	@override String get toggle => 'Ve fónických módech klávesa PTT rádio zaklíčuje a další stisk ho odklíčuje. Po minutě se odklíčuje samo.';
	@override String get hold => 'Ve fónických módech rádio vysílá, dokud držíte klávesu PTT, nejvýše minutu.';
}

/// The flat map containing all translations for locale <cs>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsCs {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Uložit',
			'common.ok' => 'OK',
			'common.cancel' => 'Zrušit',
			'common.delete' => 'Smazat',
			'common.create' => 'Vytvořit',
			'common.error' => 'Chyba',
			'common.close' => 'Zavřít',
			'common.done' => 'Hotovo',
			'common.callsign' => 'Volací značka',
			'common.clear' => 'Vymazat',
			'common.dismiss' => 'Zavřít',
			'common.copyDetails' => 'Kopírovat podrobnosti',
			'common.expand' => 'Rozbalit',
			'common.collapse' => 'Sbalit',
			'onboarding.welcomeTitle' => 'Vítá vás Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Vítá vás Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Máme několik otázek, které nám pomohou aplikaci přizpůsobit vašim potřebám.',
			'onboarding.skip' => 'Přeskočit',
			'onboarding.kContinue' => 'Pokračovat',
			'onboarding.back' => 'Zpět',
			'onboarding.next' => 'Další',
			'onboarding.done' => 'Hotovo',
			'onboarding.callsignTitle' => 'Jaká je vaše volací značka?',
			'onboarding.callsignBody' => 'Aby pro vás byla tato aplikace užitečná, potřebujete radioamatérskou licenci',
			'onboarding.callsignLabel' => 'Volací značka operátora',
			'onboarding.alreadyHaveAccount' => 'Už máte účet?',
			'onboarding.foundSiblingTitle' => 'Propojit existující účet?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Na tomto zařízení jsme našli ${app}. Propojte tuto aplikaci se stejným účtem a vaše volací značka i logy se přenesou.',
			'onboarding.foundPoloBody' => 'Na tomto zařízení jsme našli starší verzi Ham2K Portable Logger. Propojte tuto aplikaci se stejným účtem a vaše volací značka i logy se přenesou.',
			'onboarding.foundSiblingsBody' => 'Na tomto zařízení jsme našli další aplikace Ham2K. Propojte tuto aplikaci s účtem některé z nich a vaše volací značka i logy se přenesou.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Propojit s ${app}',
			'onboarding.linkWithPolo' => 'Propojit s účtem ve starší verzi',
			'onboarding.setUpFresh' => 'Začít načisto',
			'onboarding.activitiesTitle' => 'Oblíbené aktivity',
			'onboarding.activitiesBody' => 'Zajímá vás některý z těchto populárních aktivačních programů?',
			'onboarding.activitiesFooter' => '(Další možnosti najdete v Nastavení)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'Synchronizace v cloudu',
			'onboarding.syncBody' => 'Ham2K Log Filer uchovává zálohu vašich logů v cloudu a synchronizuje je mezi všemi zařízeními, kde používáte aplikace Ham2K.',
			'onboarding.syncPricing' => 'Je to zdarma! S placeným předplatným to ale bude rychlejší.',
			'onboarding.syncLabel' => 'Zapnout synchronizaci v cloudu',
			'onboarding.syncOffWarning' => 'VAROVÁNÍ: zvyšuje to riziko ztráty dat aktivit, například když se zařízení porouchá nebo ho ztratíte.',
			'onboarding.notNow' => 'Teď ne',
			'onboarding.consentTitle' => 'Data a soukromí',
			'onboarding.consentUsageBody' => 'Abychom mohli aplikaci vylepšovat, rádi bychom sbírali údaje o výkonu, pádech a používání aplikace.',
			'onboarding.consentUsageLabel' => 'Sdílet údaje o používání aplikace',
			'onboarding.consentOperationBody' => 'Některé funkce mohou sdílet údaje o vašich aktivitách s ostatními uživateli. Kdykoli to můžete vypnout.',
			'onboarding.consentOperationLabel' => 'Sdílet údaje o aktivitách',
			'onboarding.finishingSetup' => 'Dokončování nastavení — stahování referenčních dat…',
			'startScreen.credits' => 'od KI2D a přátel',
			'testerOverlay.tape' => 'POZOR: VE VÝSTAVBĚ',
			'testerOverlay.warningTitle' => 'Tato aplikace je rozpracovaná',
			'testerOverlay.warningBody' => 'Většina funkcí má nerovný povrch a všude hrozí zakopnutí. Pravidelně kontrolujte aktualizace.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Co je nového v sestavení ${build}',
			'testerOverlay.thanks' => 'Děkujeme, že riskujete svůj log, abyste nám pomohli tuto aplikaci vylepšit!',
			'extensionsPanel.categoryActivity' => 'Aktivity',
			'extensionsPanel.categoryAward' => 'Diplomy',
			'extensionsPanel.categoryContest' => 'Závody',
			'extensionsPanel.categoryLookup' => 'Vyhledávání značek',
			'extensionsPanel.categorySpots' => 'Zdroje spotů',
			'extensionsPanel.categoryDashboard' => 'Panely přehledu',
			'extensionsPanel.categoryOther' => 'Další rozšíření',
			'extensionsPanel.searchHint' => 'Hledat rozšíření',
			'extensionsPanel.applying' => 'Aktivace změn rozšíření, chvíli to potrvá…',
			'extensionsPanel.noMatches' => 'Žádné rozšíření neodpovídá hledání',
			'extensionsPanel.installFromFile' => 'Instalovat ze souboru…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Verze ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'Snímek obrazovky ${n} z ${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => 'Předchozí snímek',
			'extensionsPanel.nextScreenshot' => 'Další snímek',
			'extensionsPanel.screenshotUnavailable' => 'Snímek není k dispozici',
			'extensionsPanel.canReach' => 'Toto rozšíření se může spojit s',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, přes trvalé spojení',
			'extensionsPanel.canHoldLocalConnection' => 'Zařízeními ve vaší místní síti, přes trvalé spojení',
			'extensionsPanel.canUseLocation' => 'Vaší polohou',
			'extensionsPanel.canReadRadio' => 'Vaším rádiem, pro čtení frekvence a módu',
			'extensionsPanel.canControlRadio' => 'Vaším rádiem, pro jeho ovládání a vysílání — ladění, výkon, CW, hlasové paměti a PTT',
			'extensionsPanel.canCommandRadioRaw' => 'Vaším rádiem, pro odesílání libovolného příkazu v jeho vlastním protokolu — včetně těch, které vysílají nebo mění jeho nastavení',
			'extensionsPanel.canReadCluster' => 'DX clusterem, přihlášené jako vy, pro čtení toho, co posílá',
			'extensionsPanel.canSpotCluster' => 'DX clusterem, přihlášené jako vy, pro odesílání spotů vaším jménem',
			'extensionsPanel.canCommandCluster' => 'DX clusterem, přihlášené jako vy, pro odesílání libovolného příkazu vaším jménem',
			'extensionsPanel.canSetUserAgent' => 'Představovat se serverům vlastním jménem',
			'extensionsPanel.canChangeSettings' => 'Vaším nastavením, aby ho měnilo svými příkazy: libovolné nastavení, režim vývojáře a experimenty',
			'extensionsPanel.noCapabilities' => 'Nepožaduje nic mimo aplikaci.',
			'extensionsPanel.sandboxNote' => 'Rozšíření běží v izolovaném prostředí: bez přístupu k vašim souborům a bez sítě nad rámec zde uvedeného.',
			'extensionsPanel.installAction' => 'Instalovat',
			'extensionsPanel.updateAction' => 'Aktualizovat',
			'extensionsPanel.installFailed' => 'Toto rozšíření se nepodařilo nainstalovat',
			'extensionsPanel.installedBadge' => 'Nainstalováno',
			'extensionsPanel.uninstallAction' => 'Odebrat',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Odebrat ${name}?',
			'extensionsPanel.uninstallBody' => 'Toto rozšíření a jeho nastavení budou odebrány. Vaše logy zůstanou nedotčené.',
			'extensionsPanel.installedMessage' => ({required Object name}) => 'Nainstalováno ${name}',
			'extensionsPanel.installDownloading' => 'Stahování…',
			'extensionsPanel.installWaiting' => 'Čeká na instalaci…',
			'extensionsPanel.installInstalling' => 'Instalace…',
			'extensionsPanel.installAwaitingApproval' => 'Čeká na vaše schválení…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} se už instaluje.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Aktualizováno na ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'Instalace ${name} nebyla dokončena. Možná bude nutné ji zopakovat.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name} se nepodařilo odebrat',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Staženo z ${source}',
			'extensionsPanel.dropHint' => 'Přetáhněte sem rozšíření .h2kext a nainstalujte ho',
			'extensionsPanel.dropOneOnly' => 'Přetahujte vždy jen jedno rozšíření.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} vrátil pro toto rozšíření ${status}.',
			'extensionsPanel.downloadTooLarge' => 'Stažený soubor je příliš velký na to, aby byl rozšířením.',
			'extensionsPanel.downloadNotSecure' => 'Stahování bylo přesměrováno na nezabezpečené místo.',
			'extensionsPanel.catalogSection' => 'Katalog',
			'extensionsPanel.catalogLoading' => 'Načítání katalogu…',
			'extensionsPanel.catalogUnreachable' => 'Katalog je nedostupný',
			'extensionsPanel.builtIn' => 'Vestavěné',
			'extensionsPanel.updateAvailableBadge' => 'Aktualizace k dispozici',
			'extensionsPanel.updatesAvailableTitle' => 'Aktualizace rozšíření',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Pro ${name} je k dispozici aktualizace.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} a ${count} dalších je třeba aktualizovat.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} je třeba aktualizovat.',
			'extensionsPanel.pendingUpdatesSection' => 'Čekající aktualizace',
			'extensionsPanel.updateAllAction' => 'Aktualizovat vše',
			'extensionsPanel.updatesUnderWay' => 'Tyto aktualizace už probíhají.',
			'extensionsPanel.updatesNothingLeft' => 'Vaše rozšíření jsou aktuální.',
			'extensionsPanel.updatesNoticeAction' => 'Více informací',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Aktualizovat ${count} rozšíření?', other: 'Aktualizovat ${count} rozšíření?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Vaše rozšíření jsou připravena',
			'extensionsPanel.upgradeDoneBody' => 'Nyní pocházejí z katalogu rozšíření Ham2K, takže je lze aktualizovat bez čekání na novou verzi aplikace.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Nepřevedeno: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Nespustila se: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Jsou stále nainstalována a označena v Nastavení › Rozšíření — když je tam aktualizujete, vrátí se.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Katalog za ně nemá přímou náhradu, najděte v něm rozšíření, která pokrývají to, co jste používali.',
			'extensionsPanel.retiredQp' => 'QSO Party',
			'extensionsPanel.retiredStateparks' => 'Akce State Parks',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} z vašich rozšíření ještě nedorazilo. Stáhnou se, až bude katalog rozšíření příště dostupný.',
			'extensionsPanel.runtimeDeadBody' => 'Vaše rozšíření se nespustila. Restart aplikace by je měl vrátit.',
			'extensionsPanel.refusedTitle' => 'Některá rozšíření se nespustila',
			'extensionsPanel.upgradeBusyTitle' => 'Nastavení stále probíhá',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Vaše rozšíření neběží',
			'extensionsPanel.restoreTitle' => 'Některá vaše rozšíření chybí',
			'extensionsPanel.restoreBody' => 'Tato rozšíření, která jste nainstalovali, nejsou na tomto zařízení. Můžeme je znovu stáhnout z katalogu rozšíření Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Nainstalováno ze souboru. Nainstalujte je znovu z jejich souborů, nebo je zapomeňte:',
			'extensionsPanel.restoreOtherCatalog' => 'Nainstalováno z jiného katalogu rozšíření, proto tu nejsou k dispozici:',
			'extensionsPanel.restoreForget' => 'Zapomenout',
			'extensionsPanel.restoreInstall' => 'Instalovat',
			'extensionsPanel.restoreLater' => 'Později',
			'extensionsPanel.restoreInstalling' => 'Instalace vašich rozšíření…',
			'extensionsPanel.restoreDoneTitle' => 'Vaše rozšíření jsou zpět',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Znovu nainstalováno: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Některá rozšíření se nepodařilo nainstalovat',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Nepodařilo se nainstalovat: ${names}. Nabídneme je znovu při příštím otevření aplikace.',
			'extensionsPanel.restoreBusyBody' => 'Aplikace stále nastavuje vaše rozšíření. Nabídneme je znovu při příštím otevření aplikace.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Znovu jsme je nainstalovali, ale vaše rozšíření se nespustila. Restart aplikace by je měl vrátit.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => 'Rozšíření ${name} bylo staženo',
			'extensionsPanel.revokedBody' => 'Katalog tuto verzi stáhl, proto byla vypnuta.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => 'Rozšíření ${name} bylo vypnuto',
			'extensionsPanel.forceDisabledBody' => 'Ham2K toto rozšíření prozatím vypnul.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => 'Rozšíření ${name} bylo nahrazeno',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => 'Nahrazuje ho ${replacement}. Přepnout můžete v Rozšířeních.',
			'extensionsPanel.replacedBy' => ({required Object name}) => 'Nahrazeno rozšířením ${name}',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'Nahrazeno rozšířením ${name}, které už máte',
			'extensionsPanel.replaceAction' => 'Nahradit',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => 'Jeho nastavení se přenese do ${replacement}, které už máte. Vaše logy zůstanou nedotčené.',
			'extensionsPanel.downloadHashMismatch' => 'Stažený soubor není rozšíření, které katalog popisuje.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Katalog nemá verzi ${version} rozšíření ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Tento odkaz z katalogu neurčuje verzi rozšíření.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Katalog nemá žádné vydání ${key} v této větvi.',
			'extensionsPanel.installFromLink' => 'Instalovat z odkazu',
			'extensionsPanel.unstableReleaseWarning' => 'Toto je nestabilní vydání, které jeho autor zatím nepovažuje za hotové. Může se chovat chybně a bude dál dostávat nestabilní aktualizace.',
			'extensionsPanel.bleedingReleaseWarning' => 'Toto je experimentální vydání: rozpracovaná verze, která se může rozbít nebo přijít o nastavení. Bude dál dostávat experimentální aktualizace.',
			'extensionsPanel.channelUnstable' => 'Nestabilní',
			'extensionsPanel.channelBleeding' => 'Experimentální',
			'extensionsPanel.followsUnstable' => 'Dostává nestabilní a stabilní vydání',
			'extensionsPanel.followsBleeding' => 'Dostává experimentální, nestabilní a stabilní vydání',
			'extensionsPanel.followStableAction' => 'Sledovat jen stabilní vydání',
			'extensionsPanel.revokedBadge' => 'Staženo',
			'extensionsPanel.forceDisabledBadge' => 'Vypnuto Ham2K',
			'extensionsPanel.refusedBadge' => 'Nenačteno',
			'extensionsPanel.downloadNotHttps' => 'Stahování neprobíhá přes zabezpečené spojení.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} pro toto rozšíření není dostupný.',
			'extensionsPanel.detailsAction' => 'Podrobnosti',
			'extensionsPanel.installedFromFile' => 'Nainstalováno ze souboru',
			'extensionsPanel.detailsWhatItDoes' => 'Poskytuje podporu pro',
			'extensionsPanel.installedPreloaded' => 'Předinstalováno',
			'extensionsPanel.hookAccount' => 'Přihlášení k účtu',
			'extensionsPanel.hookCallNotes' => 'Poznámky ke značkám',
			'extensionsPanel.hookDataFile' => 'Offline data',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Vyhledávání značek',
			'extensionsPanel.hookScoring' => 'Bodování',
			'extensionsPanel.hookSpots' => 'Spoty',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Lovení ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Aktivace ${program}',
			'extensionsPanel.suggestedSection' => 'Doporučené',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => 'Další dostupná (${count})',
			'home.title' => 'Portable Logger',
			'home.newOperation' => 'Nová aktivita',
			'home.stationCallsign' => 'Volací značka stanice',
			'home.titleOptional' => 'Název (nepovinné)',
			'home.emptyList' => 'Zatím žádné aktivity. Vytvořte jednu a začněte logovat.',
			'home.quickLookup' => 'Rychlé vyhledání',
			'home.nav.operations' => 'Aktivity',
			'home.nav.chase' => 'Lovení',
			'home.nav.logs' => 'Logy',
			'home.nav.maps' => 'Mapy',
			'home.nav.settings' => 'Nastavení',
			'home.panels.operations' => 'Seznam aktivit',
			'home.panels.operationsDescription' => 'Vaše aktivity, nejnovější první.',
			'home.panels.version' => 'Aktuální verze',
			'home.panels.versionDescription' => 'Logo Ham2K, název této aplikace a sestavení, které používáte.',
			'home.toggleNav' => 'Zobrazit nebo skrýt popisky navigace',
			'home.logs.title' => 'Logy',
			'home.logs.titleFor' => 'Logy pro',
			'home.logs.emptyCallsigns' => 'Zatím žádná zalogovaná QSO',
			'home.logs.emptyQsos' => ({required Object call}) => 'Žádná QSO pro ${call}',
			'home.logs.mapNoSelection' => 'Vyberte QSO, aby se zobrazilo na mapě',
			'home.logs.searchHint' => 'Hledat značku nebo jméno',
			'home.logs.noSearchMatches' => 'Žádné QSO neodpovídá hledání',
			'home.logs.titleAll' => 'Všechny logy',
			'home.logs.allCallsigns' => 'Všechny značky',
			'home.logs.noOperation' => 'Není součástí aktivity',
			'home.logs.unsavedTitle' => 'Neuložené změny',
			'home.logs.unsavedBody' => 'Toto QSO má neuložené změny.',
			'home.logs.pendingDeleteBody' => 'Toto QSO je označeno ke smazání.',
			'home.logs.editGone' => 'Neuloženo: toto QSO už v tomto logu není.',
			'home.logs.discard' => 'Zahodit',
			'home.logs.sheet.callsigns' => 'Volací značky stanic',
			'home.logs.sheet.groupBy' => 'Seskupit podle',
			'home.logs.sheet.period' => 'Období',
			'home.logs.groupBy.none' => 'Neseskupeno',
			'home.logs.groupBy.date' => 'Datum',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => 'Neznámý kontinent',
			'home.logs.groupBy.unknownEntity' => 'Neznámá entita',
			'home.logs.groupBy.unknownDate' => 'Bez data',
			'home.logs.period.thisMonth' => 'Tento měsíc',
			'home.logs.period.last3Months' => 'Poslední 3 měsíce',
			'home.logs.period.thisYear' => 'Tento rok',
			'home.logs.period.lastYear' => 'Minulý rok',
			'home.logs.period.allTime' => 'Za celou dobu',
			'home.logs.period.custom' => 'Vlastní rozsah',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => '– ${span}',
			'home.logs.periodTitle.custom' => 'Vlastní rozsah',
			'home.logs.columns.date' => 'Datum',
			'home.logs.columns.time' => 'Čas',
			'home.logs.columns.freq' => 'Frekvence',
			'home.logs.columns.mode' => 'Mód',
			'home.logs.columns.call' => 'Značka',
			'home.logs.columns.name' => 'Jméno',
			'home.logs.columns.station' => 'Stanice',
			'home.logs.columns.band' => 'Pásmo',
			'home.logs.columns.sent' => 'Odesl.',
			'home.logs.columns.rcvd' => 'Přij.',
			'home.logs.columns.grid' => 'Lokátor',
			'home.logs.columns.state' => 'Stát',
			'home.logs.columns.country' => 'Země',
			'home.logs.columns.refs' => 'Ref.',
			'home.logs.panels.qsos' => 'Log QSO',
			'home.logs.panels.qsosDescription' => 'QSO vybrané značky napříč všemi aktivitami.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Celkový počet QSO, nebo vyhledání značky vybraného QSO.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'Poloha vybraného QSO.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Značky: ${calls}',
			'home.logs.import.skippedOne' => '1 záznam se nepodařilo přečíst',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} záznamů se nepodařilo přečíst',
			'home.logs.import.readingTitle' => 'Čtení souboru ADIF…',
			'home.logs.import.checkingTitle' => 'Kontrola duplicit…',
			'home.logs.import.importingTitle' => 'Import QSO…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => 'Zkontrolováno ${done} z ${total}',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => 'Importováno ${imported} z ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'loví',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} a ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} a další',
			'chase.station.title' => 'Lovící stanice',
			'chase.station.stationLabel' => 'Stanice: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Bez polohy',
			'chase.periodInline.today' => 'dnes',
			'chase.periodInline.thisWeek' => 'tento týden',
			'chase.periodInline.last14Days' => 'za posledních 14 dní',
			'chase.periodInline.thisMonth' => 'tento měsíc',
			'chase.periodStats.today' => 'Statistiky za dnešek',
			'chase.periodStats.thisWeek' => 'Statistiky za tento týden',
			'chase.periodStats.last14Days' => 'Statistiky za posledních 14 dní',
			'chase.periodStats.thisMonth' => 'Statistiky za tento měsíc',
			'chase.period.today' => 'Dnes',
			'chase.period.thisWeek' => 'Tento týden',
			'chase.period.last14Days' => 'Posledních 14 dní',
			'chase.period.thisMonth' => 'Tento měsíc',
			'chase.goals.title' => 'Cíle lovení',
			'chase.goals.remove' => ({required Object name}) => 'Přestat lovit ${name}',
			'chase.goals.extensionsTitle' => 'Další programy k lovení',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => 'Ovládání logování nad QSO ulovenými v daném období.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'Logovaná značka, nebo statistiky za období.',
			'chase.panels.spots' => 'Spoty',
			'chase.panels.spotsDescription' => 'Stanice spotované v éteru, připravené k lovu.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'QSO z daného období a logovaná stanice.',
			'chase.claims.checking' => 'Kontrola QSO pro lovení',
			'chase.claims.rebuilding' => ({required Object program}) => 'Kontrola logu pro ${program}',
			'chase.claims.progress' => ({required Object done, required Object total}) => '${done} z ${total} QSO',
			'chase.notice.newRef' => ({required Object program}) => 'Nové ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'Pravděpodobně nové ${program}',
			'chase.notice.newBand' => ({required Object program}) => 'Nové pásmo ${program}',
			'chase.notice.newBandGuess' => ({required Object program}) => 'Pravděpodobně nové pásmo ${program}',
			'chase.notice.newMode' => ({required Object program}) => 'Nový mód ${program}',
			'chase.notice.newModeGuess' => ({required Object program}) => 'Pravděpodobně nový mód ${program}',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} nepotvrzeno',
			'chase.notice.programGuess' => ({required Object notice}) => 'Pravděpodobně ${notice}',
			'chase.alerts.title' => 'Upozornění',
			'chase.alerts.newRef' => 'Nová reference',
			'chase.alerts.newBand' => 'Nové pásmo',
			'chase.alerts.newMode' => 'Nový mód',
			'chase.alerts.unconfirmed' => 'Nepotvrzeno',
			'chase.checklists' => 'Postup lovení',
			'chase.imports.importFrom' => ({required Object label}) => 'Importovat ${label}',
			'chase.imports.pickTitle' => ({required Object file}) => 'Importovat ${file} jako',
			'chase.imports.dropHint' => 'Přetáhněte sem soubor a importujte ho do programu k lovení',
			'chase.imports.done' => ({required Object count, required Object program, required Object file}) => 'Importováno ${count} položek ${program} ze souboru ${file}',
			'chase.imports.doneSkipped' => ({required Object count, required Object program, required Object file, required Object skipped}) => 'Importováno ${count} položek ${program} ze souboru ${file}, přeskočeno ${skipped} nečitelných',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file} neobsahuje nic, co by šlo importovat do ${program}',
			'chase.imports.failed' => ({required Object file, required Object program}) => '${file} se pro ${program} nepodařilo přečíst',
			'chase.imports.unreadable' => ({required Object skipped, required Object file, required Object program}) => 'Žádný z ${skipped} záznamů v ${file} se pro ${program} nepodařilo přečíst',
			'chase.imports.noProgram' => ({required Object file}) => 'Žádný program k lovení neimportuje ${file}',
			'dialogs.operationDetails' => 'Podrobnosti aktivity',
			'dialogs.activities' => 'Aktivity',
			'dialogs.stationCallsign' => 'Volací značka stanice',
			'dialogs.advanced' => 'Pokročilé',
			'dialogs.operatingPosition' => 'Pracoviště (více stanic)',
			'dialogs.assistance' => 'Asistence',
			'dialogs.assistanceDescription' => 'Používat spotovací služby a další zdroje informací',
			'dialogs.selfSpotting' => 'Self-spotting',
			'dialogs.selfSpottingDescription' => 'Povolit funkce, které hlásí informace o vaší frekvenci',
			'dialogs.disabledByRules' => ({required Object rules}) => 'Vypnuto kvůli souladu s pravidly ${rules}',
			'dialogs.lookupDespiteAssistance.title' => 'Vyhledat online?',
			'dialogs.lookupDespiteAssistance.body' => 'Asistence je pro tuto aktivitu vypnutá. Vyhledání všech QSO tentokrát jednorázově použije online služby jako QRZ.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'Asistence je pro tuto aktivitu vypnutá kvůli souladu s pravidly ${rules}. Vyhledání všech QSO tentokrát jednorázově použije online služby jako QRZ.',
			'dialogs.lookupDespiteAssistance.action' => 'Vyhledat online',
			'dialogs.notes' => 'Poznámky',
			'dialogs.deleteOperationTitle' => 'Smazat aktivitu',
			'dialogs.purgeTestsTitle' => 'Vyčistit testovací aktivity',
			'dialogs.purgeTestsBody' => 'Tímto trvale smažete tyto testovací aktivity a jejich QSO. Nelze to vrátit zpět.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Navíc ${count} testovací spojení, které nepatří k žádné aktivitě.', other: 'Navíc ${count} testovacích spojení, která nepatří k žádné aktivitě.', ), 
			'dialogs.purgeTestsAction' => 'Vyčistit',
			'dialogs.syncAllTitle' => 'Nahradit log tohoto zařízení?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL zálohuje a vymaže z tohoto zařízení ${qsos} a pak znovu stáhne log účtu ze serveru. Záloha zůstane v databázi tohoto zařízení.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${n} QSO ještě nebylo synchronizováno — server ho nikdy nepřijal a NEVRÁTÍ se.', other: '${n} QSO ještě nebylo synchronizováno — server je nikdy nepřijal a NEVRÁTÍ se.', ), 
			'dialogs.syncAllAction' => 'Vymazat a znovu synchronizovat',
			'dialogs.receivedPurgesTitle' => 'Testovací aktivity odebrané jinde',
			'dialogs.receivedPurgesBody' => 'Tyto aktivity byly smazány jako testovací na jiném zařízení. Odebrat je i zde? Tímto je trvale smažete i s jejich QSO a nelze to vrátit zpět.',
			'dialogs.receivedPurgesAction' => 'Odebrat',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Neplatná volací značka: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Neplatné volací značky: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Dosud vysílal ${previous}. Pro nová spojení bude zaznamenán ${typed}.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Dosud nebyl zaznamenán žádný operátor. Pro nová spojení bude zaznamenán ${typed}.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Tato aktivita už má spojení od ${calls}. ${typed} bude zaznamenán jen pro nová spojení.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Zaznamenat ${typed} jako operátora i u již zalogovaného spojení', other: 'Zaznamenat ${typed} jako operátora i u všech ${count} již zalogovaných spojení', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Při vysílání z více stanic nejsou samostatní operátoři podporováni',
			'dialogs.callChange.contactsUnreadable' => 'Spojení této aktivity nelze přečíst, proto změna značky zde nenabídne jejich aktualizaci',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Již zalogovaná spojení nelze aktualizovat, proto nebyly provedeny žádné změny: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => 'Aktualizováno ${written} z ${planned} spojení — ostatní už v této aktivitě nejsou',
			'operation.deletedReadOnly' => 'Tato aktivita je smazaná. Chcete-li logovat nebo provádět změny, obnovte ji.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTY',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => 'Hodiny',
			'operation.tabs.weather' => 'Počasí',
			'operation.tabs.website' => 'Web',
			'operation.tabs.remoteScreen' => 'Vzdálená obrazovka',
			'operation.tabs.solar' => 'Sluneční aktivita',
			'operation.tabs.radio' => 'Rádio',
			'operation.tabs.rotator' => 'Rotátor',
			'operation.tabs.summaries' => 'Souhrny aktivity',
			'operation.positions.nobodyYet' => 'Tuto aktivitu zatím nesdílí žádná další operátorská pracoviště.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Prac.: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Jiné pracoviště',
			'operation.positions.thisDevice' => 'Naše pracoviště',
			'operation.positions.nameIn' => ' v ',
			'operation.positions.panelTitle' => 'Pracoviště',
			'operation.positions.panelDescription' => 'Co právě loguje každé pracoviště, které sdílí tuto aktivitu.',
			'operation.stationCallsignNone' => 'Bez volací značky stanice',
			'operation.titleNone' => 'Bez názvu',
			'operation.deleteOperation' => 'Smazat aktivitu',
			'operation.loggingControlsStale' => 'Pole aktivačních programů mohou být zastaralá — obnovíte je znovuotevřením aktivity',
			'operation.locationNone' => 'Nenastaveno',
			'operation.generalOperation' => 'Obecná aktivita',
			'operation.titleFor' => ({required Object value}) => 'pro ${value}',
			'operation.titleAt' => ({required Object value}) => 'v ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Nyní ${description}',
			'operation.testOperationSuffix' => 'Testování',
			'operation.menu.showRstFields' => 'Zobrazit pole RST',
			'operation.menu.showStateField' => 'Zobrazit pole Stát',
			'operation.menu.showGridField' => 'Zobrazit pole Lokátor',
			'operation.menu.showDeletedQsos' => 'Zobrazit smazaná QSO',
			'operation.menu.showDeletedOps' => 'Zobrazit smazané aktivity',
			'operation.menu.showQsoNumbers' => 'Zobrazit čísla QSO',
			'operation.menu.lookupAllQsos' => 'Vyhledat všechna QSO',
			'operation.menu.loggingSettingsTitle' => 'Nastavení logování',
			'operation.menu.mapSettingsTitle' => 'Nastavení mapy',
			'operation.menu.actionsSection' => 'Akce',
			'operation.layout.title' => 'Přidat panel',
			'operation.layout.availableSection' => 'Dostupné panely',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Nastavení panelu ${panel}',
			'operation.layout.panelSettingsAction' => 'Nastavení panelu',
			'operation.layout.viewName' => 'Zobrazení aktivity',
			'operation.layout.viewOptions' => 'Možnosti rozložení zobrazení',
			'operation.layout.viewTitleBuiltIn' => 'Toto zobrazení je součástí aplikace, stejně jako jeho název',
			'operation.layout.resetOptions' => 'Obnovit výchozí',
			'operation.layout.removePane' => 'Odebrat',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Obnovit výchozí nastavení panelu ${panel}?',
			'operation.layout.resetPaneConfirmBody' => 'Jeho název, záhlaví a velikost se vrátí na výchozí. Zbytek rozložení zůstane beze změny.',
			'operation.layout.resetViewConfirm' => 'Obnovit výchozí rozložení tohoto zobrazení?',
			'operation.layout.resetViewConfirmBody' => 'Panely se vrátí do výchozího uspořádání a možnosti zobrazení i všech panelů se vrátí na výchozí.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Nastavení rozložení ${panel}',
			'operation.layout.paneTitle' => 'Název',
			'operation.layout.paneShowHeader' => 'Zobrazit záhlaví',
			'operation.layout.paneShowHeaderTabset' => 'Zobrazeno vždy, když panel sdílí skupinu — přes záhlaví se dostanete k ostatním',
			'operation.layout.paneInherit' => 'Stejně jako aplikace',
			'operation.layout.searchHint' => 'Hledat panely',
			'operation.layout.noPanelsMatch' => 'Žádný panel neodpovídá hledání.',
			'operation.layout.nothingToAdd' => 'Toto zobrazení už obsahuje všechny možné panely',
			'operation.layout.addPanel' => ({required Object panel}) => 'Přidat ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Náhled ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Chybí rozšíření "${name}"',
			'operation.layout.missingExtensionEnable' => 'Zapnout',
			'operation.layout.missingExtensionInstall' => 'Instalovat…',
			'operation.layout.missingExtensionWontRun' => 'Tato verze se nespustí. Aktualizujte ji v Nastavení › Rozšíření.',
			'operation.layout.missingExtensionUnavailable' => 'V této aplikaci není k dispozici',
			'operation.layout.missingExtensionNotInCatalog' => 'Není v katalogu',
			'operation.layout.missingExtensionCatalogUnreachable' => 'Katalog je nedostupný. Zkuste to znovu',
			'operation.layout.missingExtensionFailed' => 'Nepovedlo se. Zkuste to znovu',
			'operation.layout.previewUnavailable' => 'Náhled tohoto panelu nelze zobrazit.',
			'operation.layout.nestedPaneTitle' => 'Více',
			'operation.layout.layouts.defaultName' => 'Výchozí',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'Rozložení ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'Rozložení: ${name}',
			'operation.layout.layouts.menuNew' => 'Nové…',
			'operation.layout.layouts.menuExport' => 'Exportovat…',
			'operation.layout.layouts.menuImport' => 'Importovat…',
			'operation.layout.layouts.menuTitle' => 'Rozložení',
			'operation.layout.layouts.newTitle' => 'Nové rozložení',
			'operation.layout.layouts.editTitle' => 'Upravit rozložení',
			'operation.layout.layouts.edit' => 'Upravit',
			'operation.layout.layouts.duplicateCurrent' => 'Duplikovat aktuální rozložení',
			'operation.layout.layouts.startFromDefault' => 'Začít z výchozího rozložení',
			'operation.layout.layouts.nameLabel' => 'Název',
			'operation.layout.layouts.descriptionLabel' => 'Popis',
			'operation.layout.layouts.create' => 'Vytvořit',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => 'Uložit změny v „${name}“?',
			'operation.layout.layouts.leaveEditBody' => 'Toto rozložení má neuložené změny.',
			'operation.layout.layouts.discard' => 'Zahodit',
			'operation.layout.layouts.deleteTitle' => 'Smazat toto rozložení?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'Opravdu chcete smazat rozložení „${name}“?',
			'operation.layout.layouts.exportTitle' => 'Exportovat rozložení',
			'operation.layout.layouts.exportPick' => 'Panely k exportu',
			'operation.layout.layouts.tabSet' => 'Sada záložek',
			'operation.layout.layouts.exportAction' => 'Exportovat',
			'operation.layout.layouts.exported' => ({required Object location}) => 'Rozložení uloženo do ${location}',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'Rozložení se nepodařilo exportovat: ${error}',
			'operation.layout.layouts.importTitle' => 'Importovat rozložení',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => 'Vytvořeno pro zobrazení ${view}: panely, které má jen toto zobrazení, jsou vynechány.',
			'operation.layout.layouts.viewHome' => 'Domů',
			'operation.layout.layouts.viewOperation' => 'Aktivita',
			'operation.layout.layouts.viewLogs' => 'Logy',
			'operation.layout.layouts.viewChase' => 'Lovení',
			'operation.layout.layouts.importAsNew' => 'Jako nové rozložení',
			'operation.layout.layouts.importReplace' => 'Místo tohoto rozložení',
			'operation.layout.layouts.importAdd' => 'Přidáno do tohoto rozložení',
			'operation.layout.layouts.importAddHint' => 'Panely se objeví v novém sloupci vpravo.',
			'operation.layout.layouts.importPick' => 'Panely k importu',
			'operation.layout.layouts.importReplaceSettings' => 'Nahradit nastavení panelů, které už jsou zde nastavené',
			'operation.layout.layouts.importAction' => 'Importovat',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} není rozložení, které tato aplikace umí přečíst: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'text není platný YAML (řádek ${line})',
			'operation.layout.layouts.problemNotLayoutFile' => 'není to soubor rozložení Ham2K',
			'operation.layout.layouts.problemNewerVersion' => 'zapsala ho novější verze aplikace',
			'operation.layout.layouts.problemNoArrangement' => 'neobsahuje žádné uspořádání',
			'operation.layout.layouts.problemMalformed' => 'část z něj neodpovídá formátu rozložení',
			'operation.layout.layouts.problemTooLarge' => 'je příliš velký',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'Soubor se nepodařilo otevřít: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'Rozložení se nepodařilo importovat: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'Rozložení se nepodařilo zkopírovat: ${error}',
			'operation.layout.layouts.importNothing' => 'Nebyl vybrán žádný panel, nic se tedy neimportovalo.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => 'Vynecháno: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => '${panels} ponecháno: uspořádání pro malé obrazovky se bez něj neobejde.',
			'operation.layout.layouts.notOffered' => 'V tomto zobrazení není k dispozici',
			'operation.layout.layouts.alreadyPlaced' => 'Už je v tomto rozložení',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => 'Vyžaduje ${name}',
			'operation.layout.layouts.listRecoveredTitle' => 'Názvy rozložení nelze přečíst',
			'operation.layout.layouts.listRecoveredBody' => 'Seznam rozložení tohoto zobrazení nelze přečíst. Všechna rozložení jsou stále k dispozici, místo názvu mají číslo.',
			'operation.layout.editLayout' => 'Upravit rozložení',
			'operation.layout.saveLayout' => 'Uložit rozložení',
			'operation.layout.revertLayout' => 'Zahodit změny rozložení',
			'operation.layout.done' => 'Hotovo',
			'operation.layout.layoutUnreadableTitle' => 'Rozložení nelze přečíst',
			'operation.layout.layoutUnreadableBody' => 'Vaše uložené rozložení nelze přečíst, proto se zobrazuje výchozí uspořádání. Původní rozložení nebude přepsáno, dokud se nerozhodnete toto ponechat.',
			'operation.layout.layoutUnreadableAction' => 'Použít toto rozložení',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} nelze zobrazit',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: odeslal více než ${max} znaků',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho grafika má více než ${max} prvků',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho grafika je vnořená do více než ${max} úrovní',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => '${panel} nelze zobrazit: jeho grafika není samostatný celek',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho scéna má více než ${max} vrstev',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho scéna má více než ${max} ovládacích prvků',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: část jeho scény má více než ${max} položek',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: řetězec ve scéně je delší než ${max} znaků',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => '${panel} nelze zobrazit: jeho rozložení je vnořené do více než ${max} úrovní',
			'operation.layout.panelRenderRetry' => 'Zkusit znovu',
			'operation.layout.panelActionFailed' => 'Akce panelu selhala. Zkuste to znovu.',
			'operation.layout.panels.loggingDescription' => 'Log a vstupní pole',
			'operation.layout.panels.infoDescription' => 'Co víme o protistanici',
			'operation.layout.panels.spotsDescription' => 'Spoty z clusterů a aktivačních programů',
			'operation.layout.panels.mapDescription' => 'Kde jsou spojení',
			'operation.layout.panels.summariesDescription' => 'Statistiky a bodování aktivity, v sekcích a pořadí podle vašeho výběru',
			'operation.layout.panels.summariesSections' => 'Sekce a pořadí',
			'operation.layout.panels.summariesDays' => 'Každý den',
			'operation.layout.panels.summariesReset' => 'Zobrazit vše',
			'operation.layout.panels.summariesAllHidden' => 'Všechny sekce jsou skryté. Které zobrazit, vyberte v nastavení tohoto panelu.',
			'operation.layout.panels.clockDescription' => 'Ciferník v libovolném časovém pásmu',
			'operation.layout.panels.clockFace' => 'Ciferník',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analogový',
			'operation.layout.panels.clockZone' => 'Časové pásmo',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Toto zařízení',
			'operation.layout.panels.clockShowSeconds' => 'Zobrazit sekundy',
			'operation.layout.panels.weatherDescription' => 'Aktuální podmínky a předpověď na příštích osm hodin v místě provozu',
			'operation.layout.panels.weatherUseOperationLocation' => 'Použít polohu aktivity',
			'operation.layout.panels.weatherLocation' => 'Poloha',
			'operation.layout.panels.weatherLocationDescription' => 'Lokátor (FN31pr) nebo šířka,délka. Ignoruje se, když je zaškrtnuto „Použít polohu aktivity“.',
			'operation.layout.panels.weatherNoLocation' => 'Poloha není nastavena. Zadejte polohu v nastavení panelu, nebo panel umístěte do aktivity, která ji má.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Polohu ${location} nelze přečíst. Použijte lokátor jako FN31pr, nebo 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo je nedostupné — chybí síť? Brzy to zkusíme znovu.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo odpovědělo, ale ničím čitelným. Brzy to zkusíme znovu.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'nárazy ${speed}',
			'operation.layout.panels.panelAgeNow' => 'právě teď',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'před ${count} min', other: 'před ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'před ${count} hod', other: 'před ${count} hod', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Neznámé',
			'operation.layout.panels.weatherConditions.sunny' => 'Slunečno',
			'operation.layout.panels.weatherConditions.clear' => 'Jasno',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Převážně slunečno',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Převážně jasno',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Polojasno',
			'operation.layout.panels.weatherConditions.cloudy' => 'Zataženo',
			'operation.layout.panels.weatherConditions.foggy' => 'Mlha',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Mrznoucí mlha',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Slabé mrholení',
			'operation.layout.panels.weatherConditions.drizzle' => 'Mrholení',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Silné mrholení',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Slabé mrznoucí mrholení',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Mrznoucí mrholení',
			'operation.layout.panels.weatherConditions.lightRain' => 'Slabý déšť',
			'operation.layout.panels.weatherConditions.rain' => 'Déšť',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Silný déšť',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Slabý mrznoucí déšť',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Mrznoucí déšť',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Slabé sněžení',
			'operation.layout.panels.weatherConditions.snow' => 'Sněžení',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Silné sněžení',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Sněhová zrna',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Slabé přeháňky',
			'operation.layout.panels.weatherConditions.showers' => 'Přeháňky',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Silné přeháňky',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Slabé sněhové přeháňky',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Sněhové přeháňky',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Bouřka',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Slabé bouřky s krupobitím',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Bouřka s krupobitím',
			'operation.layout.panels.websiteDescription' => 'Webová stránka dle vašeho výběru v panelu',
			'operation.layout.panels.websiteUrl' => 'Adresa',
			'operation.layout.panels.websiteRefresh' => 'Obnovování',
			'operation.layout.panels.websiteRefreshNever' => 'Nikdy',
			'operation.layout.panels.websiteRefresh1' => 'Každou minutu',
			'operation.layout.panels.websiteRefresh5' => 'Každých 5 minut',
			'operation.layout.panels.websiteRefresh15' => 'Každých 15 minut',
			'operation.layout.panels.websiteTitle' => 'Název panelu',
			'operation.layout.panels.websiteRefreshNow' => 'Obnovit nyní',
			'operation.layout.panels.websiteNoUrl' => 'Zatím bez adresy. Stránku vyberte v nastavení tohoto panelu.',
			'operation.layout.panels.websiteBadUrl' => 'Toto nevypadá jako webová adresa. Musí začínat https://',
			'operation.layout.panels.websiteNotHttps' => 'Zde lze zobrazit pouze https:// adresy.',
			'operation.layout.panels.websiteUnsupported' => 'Na tomto systému nelze webové stránky zobrazit v panelu.',
			'operation.layout.panels.websiteOpenExternally' => 'Otevřít v prohlížeči',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Stránku nelze načíst: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Obrazovka, aplikace nebo okno sdílené jiným z vašich zařízení.',
			'operation.layout.panels.remoteScreenTarget' => 'Obrazovka',
			'operation.layout.panels.remoteScreenChoose' => 'Vyberte obrazovku…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Sdílené obrazovky',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Žádné z vašich zařízení nesdílí obrazovku. Zapněte Sdílet obrazovky a okna v Nastavení → Spárovaná zařízení na zařízení, které chcete vidět.',
			'operation.layout.panels.remoteScreenUnset' => 'Není vybrána žádná obrazovka. V nastavení tohoto panelu vyberte jednu z těch, které sdílejí vaše další zařízení.',
			'operation.layout.panels.remoteScreenConnecting' => 'Připojování…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Toto zařízení teď není připojeno.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Toto zařízení přestalo tuto obrazovku sdílet.',
			'operation.layout.panels.remoteScreenNoListener' => 'Toto zařízení nepřijímá připojení — zkontrolujte jeho firewall.',
			'operation.layout.panels.remoteScreenNoLan' => 'Obrazovky se sdílejí jen přes místní síť, ne přes Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Toto zařízení odmítlo tuto obrazovku sdílet.',
			'operation.layout.panels.remoteScreenSettings' => 'Nastavení panelu',
			'operation.layout.panels.remoteScreenAdjust' => 'Upravit zobrazení',
			'operation.layout.panels.remoteScreenDetail' => 'Detail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standardní',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Vysoký',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximální',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Přiblížit',
			'operation.layout.panels.remoteScreenZoomOut' => 'Oddálit',
			'operation.layout.panels.remoteScreenStopped' => 'Tato obrazovka nebo okno se už nezobrazuje.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Toto zařízení nemohlo obrazovku zachytit — možná potřebuje oprávnění k nahrávání obrazovky.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Toto zařízení neodpovědělo. Možná nemá zapnuté sdílení obrazovky.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Nelze otevřít spojení pro obraz. Zkontrolujte firewall na tomto zařízení.',
			'operation.layout.panels.solarDescription' => 'Sluneční a geomagnetické podmínky se šířením pro jednotlivá pásma',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com je nedostupné — chybí síť? Brzy to zkusíme znovu.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com odpovědělo, ale ne údaji, které bychom mohli použít. Brzy to zkusíme znovu.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Den',
			'operation.layout.panels.solarBandNight' => 'Noc',
			'operation.layout.panels.solarBandGood' => 'Dobré',
			'operation.layout.panels.solarBandFair' => 'Průměrné',
			'operation.layout.panels.solarBandPoor' => 'Špatné',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Zdroje: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Spojení má potíže — vynechávají se snímky.',
			'operation.layout.panels.remoteScreenStalled' => 'Snímky přestaly procházet — spojení může být příliš pomalé.',
			'operation.layout.panels.radioDescription' => 'Přední panel rádia — frekvence, mód a výkon, ovládané přes CAT',
			'operation.layout.panels.radioStyle' => 'Styl',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderní',
			'operation.layout.panels.radioRadio' => 'Rádio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — není určeno žádné rádio',
			'operation.layout.panels.radioNoRadio' => 'Žádné rádio k zobrazení. Vyberte ho v nastavení tohoto panelu, nebo ho přidejte v Konfiguraci stanice.',
			'operation.layout.panels.radioNotConfigured' => 'Toto rádio zatím není nakonfigurováno. Vyberte jeho port nebo adresu v Konfiguraci stanice.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Rádio není připojeno',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Připojit toto rádio',
			'operation.layout.panels.radioDisconnect' => 'Odpojit toto rádio',
			'operation.layout.panels.radioStale' => 'BEZ DAT',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'PSV',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'vysoké PSV',
			'operation.layout.panels.rotatorDescription' => 'Kam míří anténa, na mapě se středem ve stanici. Klepnutím na mapu ji otočíte.',
			'operation.layout.panels.rotatorRotator' => 'Rotátor',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => 'Automaticky — ${name}',
			'operation.layout.panels.rotatorAutoNone' => 'Automaticky — zatím žádný rotátor',
			'operation.layout.panels.rotatorBeamWidth' => 'Šířka svazku',
			'operation.layout.panels.rotatorBeamWidthDescription' => 'Ve stupních, vykreslí se kolem směru. 0 nevykreslí nic.',
			'operation.layout.panels.rotatorLocation' => 'Poloha',
			'operation.layout.panels.rotatorLocationDescription' => 'Lokátor nebo zeměpisná šířka a délka, na které se mapa vystředí. Prázdné použije polohu aktivity.',
			'operation.layout.panels.rotatorTheme' => 'Téma',
			'operation.layout.panels.rotatorThemeColor' => 'Barevné',
			'operation.layout.panels.rotatorThemeGray' => 'Šedé',
			'operation.layout.panels.rotatorThemeMuted' => 'Tlumené',
			'operation.layout.panels.rotatorGrayline' => 'Zobrazit šedou linii',
			'operation.layout.panels.rotatorNoRotator' => 'Žádný rotátor k zobrazení. Vyberte ho v nastavení tohoto panelu, nebo ho přidejte v Konfiguraci stanice.',
			'operation.layout.panels.rotatorNoLocation' => 'Není poloha, na kterou mapu vystředit. Nastavte ji v nastavení tohoto panelu.',
			'operation.layout.panels.rotatorDisconnected' => 'odpojeno',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => 'neodpovídá',
			'operation.layout.panels.rotatorLocationInvalid' => 'Polohu v nastavení tohoto panelu nelze přečíst. Použijte lokátor, nebo zeměpisnou šířku a délku jako 40.7, -74.0.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '${degrees}° el',
			'operation.layout.panels.rotatorNorth' => 'S',
			'operation.layout.panels.rotatorEast' => 'V',
			'operation.layout.panels.rotatorSouth' => 'J',
			'operation.layout.panels.rotatorWest' => 'Z',
			'operation.layout.htmlPanelUnsupported' => 'Tento panel potřebuje webové zobrazení, které tato platforma neposkytuje',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Tento panel potřebuje izolované prostředí, které webová verze nemůže poskytnout',
			'operation.export.title' => 'Exporty aktivity',
			'operation.export.syncedOperation' => 'Aktivita je synchronizována',
			'operation.export.unsyncedOperation' => 'Aktivita má nesynchronizované změny',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} QSO v této aktivitě', other: '${count} QSO v této aktivitě', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Všech ${total} QSO je synchronizováno',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} z ${total} QSO čeká na synchronizaci',
			'operation.export.eventsSynced' => ({required Object total}) => 'Synchronizováno ${total} značek událostí',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} z ${total} značek událostí čeká',
			'operation.export.loading' => 'Načítání možností exportu…',
			'operation.export.noOptions' => 'Nejsou k dispozici žádné formáty exportu (rozšíření se ještě spouštějí?)',
			'operation.export.nothingLogged' => 'Zatím není co exportovat — tato aktivita nemá žádná QSO.',
			'operation.export.share' => 'Sdílet',
			'operation.export.nothingSelected' => 'Nic není vybráno',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Uložit ${count} soubor', other: 'Uložit ${count} souborů', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Sdílet ${count} soubor', other: 'Sdílet ${count} souborů', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Exportovat ${count} soubor', other: 'Exportovat ${count} souborů', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Stáhnout ${count} soubor', other: 'Stáhnout ${count} souborů', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Uložit ${count} sloučený soubor', other: 'Uložit ${count} sloučených souborů', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Sdílet ${count} sloučený soubor', other: 'Sdílet ${count} sloučených souborů', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Exportovat ${count} sloučený soubor', other: 'Exportovat ${count} sloučených souborů', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Stáhnout ${count} sloučený soubor', other: 'Stáhnout ${count} sloučených souborů', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Uložit ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Sdílet ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportovat ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Stáhnout ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Uschovat ${count} soubor', other: 'Uschovat ${count} souborů', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Uschovat ${count} sloučený soubor', other: 'Uschovat ${count} sloučených souborů', ), 
			'operation.export.settingsButton' => 'Nastavení exportu',
			'operation.export.settingsTitle' => 'Nastavení exportu',
			'operation.export.compactFileNames.title' => 'Použít kompaktní názvy souborů',
			'operation.export.compactFileNames.descriptionOn' => 'Krátké názvy pro nahrávací nástroje, např. N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Čitelné názvy, např. 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Zahrnout soukromé údaje',
			'operation.export.includePrivateData.descriptionOn' => 'Jména, adresy, e-maily, lokátory a poznámky jsou zahrnuty',
			'operation.export.includePrivateData.descriptionOff' => 'Jména, adresy, e-maily, lokátory a poznámky jsou vynechány',
			'operation.export.includePrivateData.note' => 'Úplný export ADIF vždy zahrnuje vše',
			'operation.export.resultTitle' => 'Export dokončen',
			'operation.export.resultFailedTitle' => 'Export selhal',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Exportován ${count} soubor do ${path}', other: 'Exportováno ${count} souborů do ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Exportován ${count} soubor: ${path}', other: 'Exportováno ${count} souborů: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Sdílen ${count} soubor', other: 'Sdíleno ${count} souborů', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Stažen ${count} soubor', other: 'Staženo ${count} souborů', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Export selhal: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Nejprve přidejte e-mailovou adresu',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash posílá vaše soubory na e-mailovou adresu vašeho účtu LoFi a stejnou adresou se přihlašujete na stash.ham2k.net. Váš účet zatím nemá potvrzenou adresu — přidejte ji v Nastavení › Synchronizace v cloudu.',
			'operation.export.stash.openSyncSettings' => 'Otevřít synchronizaci v cloudu',
			'operation.export.stash.replaceTitle' => 'Nedávná úschova bude nahrazena',
			'operation.export.stash.replaceBody' => ({required Object name}) => '„${name}“ jste odeslali před méně než 6 hodinami a ještě nebyl stažen. Bezplatné účty mají najednou jen jednu úschovu, takže odeslání nyní ji nahradí.',
			'operation.export.stash.replaceConfirm' => 'Přesto odeslat',
			'operation.export.stash.failedTitle' => 'Nepodařilo se odeslat do Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'Odesláno do Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Tento soubor můžete získat návštěvou **[stash.ham2k.net](https://stash.ham2k.net)** v libovolném prohlížeči.', other: 'Tyto soubory můžete získat návštěvou **[stash.ham2k.net](https://stash.ham2k.net)** v libovolném prohlížeči.', ), 
			'operation.export.stash.mayHaveArrived' => 'Úschovna neodpověděla — soubor možná přesto dorazil. Než ho pošlete znovu, zkontrolujte stash.ham2k.net',
			'operation.export.stash.notSent' => 'neodesláno',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Tento soubor nedorazil:', other: 'Těchto ${count} souborů nedorazilo:', ), 
			'operation.export.stash.emailOffer' => 'Nebo vám pro vaše pohodlí můžeme poslat e-mail s přímým odkazem.',
			'operation.export.stash.emailMe' => 'Poslat mi odkaz e-mailem',
			'operation.export.stash.emailSent' => 'Poslali jsme vám e-mailem odkaz ke stažení.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'E-mail se nepodařilo odeslat: ${error}',
			'operation.export.stash.freeTier' => 'Bezplatné účty mohou mít najednou pouze jednu úschovu. Předplatitelé jich mohou mít, kolik chtějí.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} soubor odeslán do Ham2K File Stash (stash.ham2k.net)', other: '${count} souborů odesláno do Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Vašim filtrům neodpovídají žádné spoty',
			'operation.spots.error' => ({required Object error}) => 'Načtení spotů selhalo: ${error}',
			'operation.spots.unknownBand' => 'Jiné',
			'operation.spots.auto' => 'Automaticky',
			'operation.spots.autoValue' => ({required Object value}) => 'Automaticky (nyní ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Libovolné',
			'operation.spots.allBands' => 'Všechna pásma',
			'operation.spots.allModes' => 'Všechny módy',
			'operation.spots.phoneAndCw' => 'Fónie a CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} spot', other: '${count} spotů', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Zobrazeno ${count} z ${total} spotů',
			'operation.spots.spotsDisabled' => 'Spoty jsou pro tuto aktivitu vypnuté',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minut',
			'operation.spots.callsOfNote' => 'Zajímavé značky',
			'operation.spots.yourSpots' => 'Vaše spoty',
			'operation.spots.allSpots' => 'Všechny spoty',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Asie',
			'operation.spots.continents.eu' => 'Evropa',
			'operation.spots.continents.na' => 'Severní Amerika',
			'operation.spots.continents.oc' => 'Oceánie',
			'operation.spots.continents.sa' => 'Jižní Amerika',
			'operation.spots.continents.an' => 'Antarktida',
			'operation.spots.filters.title' => 'Filtrovat spoty',
			'operation.spots.filters.band' => 'Pásmo',
			'operation.spots.filters.mode' => 'Mód',
			'operation.spots.filters.age' => 'Stáří',
			'operation.spots.filters.sources' => 'Zdroje',
			'operation.spots.filters.continent' => 'Kontinent',
			'operation.spots.filters.sorting' => 'Řazení',
			'operation.spots.filters.sortByTime' => 'Podle času spotu',
			'operation.spots.filters.sortByFrequency' => 'Podle frekvence',
			'operation.spots.filters.sortByWanted' => 'Nejžádanější',
			'operation.spots.filters.groupByBand' => 'Seskupit podle pásma',
			'operation.spots.filters.groupCallsWithNotes' => 'Seskupit značky s poznámkami',
			'operation.spots.filters.alertingOnly' => 'Jen spoty s upozorněním',
			'operation.spots.filters.sourceNoReply' => 'Bez odpovědi',
			'operation.spots.filters.sourceError' => 'Chyba',
			'operation.spots.unavailableTitle' => 'Spoty nejsou k dispozici',
			'operation.spots.unavailableText' => ({required Object sources}) => 'Bez odpovědi od ${sources}.',
			'operation.spots.failedTitle' => 'Chyba zdroje spotů',
			'operation.spots.failedText' => ({required Object sources}) => 'Chyba od ${sources}.',
			'operation.spots.slideLogIt' => 'Zalogovat',
			'operation.spots.slideIgnore' => 'Ignorovat',
			'operation.spots.slideRestore' => 'Obnovit',
			'operation.spots.logConflict.title' => 'Panel logování je zaneprázdněný',
			'operation.spots.logConflict.editingBody' => 'Upravujete zalogované spojení. Zalogovat místo toho tento spot, nebo se vrátit a dokončit úpravu?',
			'operation.spots.logConflict.composingBody' => 'Začali jste zadávat spojení. Zalogovat místo toho tento spot, nebo se vrátit a dokončit, co jste psali?',
			'operation.spots.logConflict.goBack' => 'Vrátit se',
			'operation.spots.logConflict.clearAndLog' => 'Vymazat a zalogovat spot',
			'operation.import.title' => 'Import dat do aktivity',
			'operation.import.importAdifAction' => 'Importovat QSO z ADIF',
			'operation.import.settingsButton' => 'Nastavení naslouchání',
			'operation.import.settingsTitle' => 'Naslouchat jiným aplikacím',
			'operation.import.protocolAddressLabel' => 'Adresa',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Zadejte port mezi 1 a 65535',
			'operation.import.protocolAddressInvalid' => 'Zadejte platnou IP adresu (např. 127.0.0.1 nebo 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Data se přijímají',
			'operation.import.protocolStatusNoData' => 'V poslední době nepřišla žádná data',
			'operation.import.protocolBindError' => ({required Object error}) => 'Naslouchání nelze spustit: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Příchozí QSO nelze uložit, ukládání se opakuje: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Libovolná (broadcast)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → karta Broadcast Data → zaškrtněte "Enable Broadcasts" pro informace o spojeních. Nastavte IP adresu na 127.0.0.1, pokud běží na tomto počítači, nebo na 255.255.255.255 pro vysílání do aktuální místní sítě.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → karta Reporting → sekce UDP Server → zaškrtněte "Accept UDP requests". Nastavte UDP Server na 127.0.0.1, pokud běží na tomto počítači, nebo na multicastovou adresu, např. 239.239.0.2, a stejnou adresu použijte ve výše uvedené konfiguraci této aplikace.',
			'operation.import.listenTitle' => 'Naslouchat QSO z jiných aplikací',
			'operation.import.listenDescriptionOnN1mm' => 'Naslouchá se N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Naslouchá se WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Naslouchá se N1MM+ a WSJT-X',
			'operation.import.listenDescriptionOff' => 'Vypnuto',
			'operation.import.addToOperationTitle' => 'Přidávat do této aktivity',
			'operation.import.addToOperationDescriptionOn' => 'Zachycená QSO se přidávají do této aktivity, jakmile dorazí',
			'operation.import.addToOperationDescriptionOff' => 'Zachycená QSO se drží, dokud toto nezapnete',
			'operation.import.pendingSectionTitle' => 'Zachycená QSO',
			'operation.import.pendingEmpty' => 'Zatím nic nezachyceno',
			'operation.import.stationMismatch' => ({required Object call}) => 'Zalogováno jako ${call}, ne jako stanice této aktivity',
			'operation.import.discardAction' => 'Zahodit',
			'operation.import.gapDialogTitle' => 'Zahrnout dřívější záznamy?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Dříve, před výpadkem dat, bylo zachyceno ještě ${count} QSO. Zahrnout i je?',
			'operation.import.gapDialogRecentOnly' => 'Jen ty nedávné',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Zahrnout všech ${count}',
			'map.outlineIssue.link' => 'Problémy?',
			'map.outlineIssue.title' => 'Nahlásit problém s obrysem',
			'map.outlineIssue.reference' => 'Který obrys',
			'map.outlineIssue.severity' => 'Jak vážné to je?',
			'map.outlineIssue.minor' => 'Drobnost',
			'map.outlineIssue.major' => 'Velký problém',
			'map.outlineIssue.explanation' => 'Co je na něm špatně?',
			'map.outlineIssue.explanationHint' => 'Co obrys zachycuje špatně a kde',
			'map.outlineIssue.send' => 'Odeslat',
			'map.outlineIssue.sending' => 'Odesílání hlášení — děkujeme',
			'map.outlineIssue.copy' => 'Kopírovat hlášení',
			'map.outlineIssue.notSent' => 'Hlášení se nepodařilo odeslat',
			'map.outlineIssue.copied' => 'Hlášení zkopírováno',
			'map.outlineIssue.notCopied' => 'Hlášení se nepodařilo zkopírovat',
			'map.outlinesDisclaimer' => 'Obrysy jsou pouze orientační. Ověřte si vše sami!',
			'map.outlinesCredit' => ({required Object sources}) => 'Obrysy: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Hranice: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Zařízení: ${sources}',
			'map.fullCredits' => 'Úplné zdroje dat',
			'map.fewerCredits' => 'Méně zdrojů',
			'map.emptyState' => 'Zatím žádné polohy QSO.\nZde se zobrazí QSO s lokátorem, státem nebo zemí.',
			'map.unavailable' => 'Mapa teď není k dispozici.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plochá',
			'map.globe' => 'Glóbus',
			'map.zoomIn' => 'Přiblížit',
			'map.zoomOut' => 'Oddálit',
			'map.resetNorth' => 'Otočit severem nahoru',
			'map.postcard.button' => 'Pohlednice aktivity',
			'map.postcard.title' => ({required Object title}) => 'Pohlednice pro ${title}',
			'map.postcard.portrait' => 'Na výšku',
			'map.postcard.landscape' => 'Na šířku',
			'map.postcard.square' => 'Čtverec',
			'map.postcard.save' => 'Uložit…',
			'map.postcard.download' => 'Stáhnout',
			'map.postcard.share' => 'Sdílet',
			'map.postcard.copy' => 'Kopírovat',
			'map.postcard.copied' => 'Zkopírováno do schránky',
			'map.postcard.saved' => ({required Object path}) => 'Uloženo do ${path}',
			'map.postcard.downloaded' => ({required Object name}) => 'Staženo ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => 'Uloženo ${count} obrázků do ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => 'Uloženo ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} už bylo uloženo',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Stahování ${count} obrázků — pokud se prohlížeč zeptá, povolte to',
			'map.postcard.mapLeftOut' => 'Mapa se nenačetla, proto byla vynechána',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — mapa se nenačetla, proto byla vynechána',
			'map.postcard.continued' => ({required Object title}) => '${title} (pokračování)',
			'map.postcard.previousPage' => 'Předchozí strana',
			'map.postcard.nextPage' => 'Další strana',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Strana ${page} z ${count}',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} Q', other: '${count} Q', ), 
			'map.postcard.options' => 'Možnosti pohlednice',
			'map.postcard.bandLegend' => 'Zobrazit legendu pásem',
			'map.postcard.grayline' => 'Zobrazit šedou linii',
			'map.postcard.sectionsAndOrder' => 'Sekce souhrnu a pořadí',
			'map.postcard.sectionDays' => 'Každý den',
			'map.postcard.reset' => 'Obnovit výchozí',
			'map.postcard.failed' => ({required Object error}) => 'Pohlednici nelze vytvořit: ${error}',
			'map.postcard.mapNotReady' => 'Mapa se nedonačetla. Zkontrolujte připojení a zkuste to znovu.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Pohlednici nelze uložit: ${error}',
			'map.postcard.copyFailed' => 'Schránka obrázek nepřijala. Zkuste to znovu.',
			'map.postcard.shareFailed' => 'Pohlednici nelze sdílet. Zkuste to znovu.',
			'map.postcard.fileName' => 'pohlednice',
			'mapsView.title' => 'Mapy',
			'mapsView.searchHint' => 'Hledat parky, vrcholy a další',
			'mapsView.activities' => 'Aktivity',
			'mapsView.layers' => 'Vrstvy',
			'mapsView.baseMap' => 'Podkladová mapa',
			'mapsView.satellite' => 'Satelit (Esri)',
			'mapsView.facilities' => 'Zařízení parků',
			'mapsView.boundaries' => 'Hranice',
			'mapsView.currentLocation' => 'Aktuální poloha',
			'mapsView.noMatches' => ({required Object text}) => 'Výrazu „${text}“ nic neodpovídá',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} reference na ${where}', other: '${count} referencí na ${where}', ), 
			'mapsView.startOperation' => 'Zahájit aktivitu s těmito referencemi',
			'activitiesView.title' => 'Aktivity',
			'activitiesView.activitiesCountZero' => 'Nevybrány žádné aktivity',
			'activitiesView.activitiesCountOne' => '1 aktivita',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} aktivit',
			'activitiesView.empty' => 'Zatím žádné aktivity — přidejte je pomocí Návrhů a hledání níže',
			'activitiesView.removeActivity' => 'Odebrat',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Otevřít ${name}',
			'activitiesView.editActivity' => 'Upravit aktivitu',
			'activitiesView.manageExtensions' => 'Spravovat rozšíření',
			'activitiesView.manage' => 'Spravovat',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Typy aktivit: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Typy aktivit: ${first} a ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Typy aktivit: ${first}, ${second} a ${more} další',
			'activitiesView.reference' => 'Reference',
			'activitiesView.invalidReference' => 'Neplatná',
			'activitiesView.duplicateReference' => 'Už přidáno',
			'activitiesView.searchHint' => 'Hledat podle názvu, reference nebo čehokoli jiného…',
			'activitiesView.noSuggestions' => 'Žádné shody',
			'activitiesView.noSuggestionsHint' => 'Hledejte výše podle názvu nebo čísla reference',
			'activitiesView.noSuggestionsExample' => '(například \'trail\' nebo \'4556\')',
			'activitiesView.allOptions' => 'Typy aktivit',
			'activitiesView.determiningLocation' => 'Zjišťování aktuální polohy…\nČeká se na GPS pro nalezení referencí v okolí',
			'activitiesView.locationUnavailableTitle' => 'Údaje o poloze nejsou k dispozici',
			'activitiesView.locationDeniedTitle' => 'Oprávnění k poloze zamítnuto',
			'activitiesView.locationBlockedTitle' => 'Oprávnění k poloze zablokováno',
			'activitiesView.noNearbyReason' => 'Nelze určit reference v okolí',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Klepněte na ${icon} a zadejte polohu ručně,\nnebo hledejte reference podle názvu',
			'activitiesView.locationGrantAction' => 'Povolit přístup k poloze',
			'activitiesView.locationSettingsAction' => 'Otevřít Nastavení',
			'activitiesView.locationSettingsUnavailable' => 'Povolte přístup k poloze v nastavení systému',
			'activitiesView.locationGrantRefused' => 'Stále bez polohy — systém to znovu odmítl',
			'activitiesView.searchUnavailableTitle' => 'Hledání aktivit není k dispozici',
			'activitiesView.searchUnavailableReason' => 'Některé rozšíření aktivit nedokázalo na hledání odpovědět. Za chvíli to zkuste znovu.',
			'activitiesView.emptySheet' => 'Přidejte je pomocí návrhů a hledání níže',
			'activitiesView.exports' => 'Exporty',
			'activitiesView.exportLogs' => 'Exportovat logy',
			'activitiesView.tools' => 'Nástroje',
			'activitiesView.toolsTitle' => 'Nástroje aktivity',
			'activitiesView.operationDetails' => 'Podrobnosti aktivity',
			'activitiesView.share' => 'Sdílet',
			'activitiesView.archive' => 'Archivovat',
			'activitiesView.deleteOperation' => 'Smazat aktivitu',
			'activitiesView.undeleteOperation' => 'Obnovit aktivitu',
			'activitiesView.alreadySelected' => 'Už vybráno',
			'activitiesView.selected' => 'Vybráno',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} z ${count}',
			'activitiesView.previousPick' => 'Předchozí shoda',
			'activitiesView.nextPick' => 'Další shoda',
			'activitiesView.retiredReference' => 'Vyřazeno',
			'activitiesView.enableExtension' => ({required Object name}) => 'Zapnout ${name}',
			'activitiesView.enableExtensionHint' => 'Toto rozšíření odpovídá vašemu hledání, ale není zapnuté',
			'activitiesView.enableExtensionForRefHint' => 'Toto rozšíření obsluhuje jednu z referencí této aktivity, ale není zapnuté',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} neběží',
			'activitiesView.extensionNotRunningHint' => 'Toto rozšíření bylo vypnuto, více informací najdete v Nastavení rozšíření',
			'activitiesView.installExtension' => ({required Object name}) => 'Instalovat ${name}',
			'activitiesView.installExtensionHint' => 'Toto rozšíření odpovídá vašemu hledání, ale není nainstalováno',
			'activitiesView.onlyCatalogMatches' => 'Žádné shody\nNěkterá rozšíření v katalogu mohou mít výsledky.\nNainstalujte je v Typech aktivit níže.',
			'activitiesView.setupUnavailable' => 'Nastavení této aktivity nelze načíst — zkuste to znovu přes Spravovat',
			'activitiesView.controlsUnavailableTitle' => 'Ovládání aktivity není k dispozici',
			'activitiesView.controlsUnavailableReason' => 'Vaše reference jsou v bezpečí, ale jejich úprava teď není k dispozici.',
			'activitiesView.controlsUnavailableRetry' => 'Zkusit znovu',
			'activitiesView.onlyDisabledMatches' => 'Žádné shody\nNěkterá dostupná rozšíření mohou mít výsledky.\nZapněte je v Typech aktivit níže.',
			'activitiesView.onlyNotRunningMatches' => 'Žádné shody\nNěkterá rozšíření, která mohou mít výsledky, neběží.\nViz Typy aktivit níže.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Hledat',
			'activitiesView.addToOperation' => 'Přidat do aktivity',
			'activitiesView.addToOperationShort' => 'Přidat',
			'activitiesView.mapEmptyState' => 'Žádné výsledky k zobrazení na mapě',
			'activitiesView.mapEmptyStateHint' => 'Přepněte zpět na seznam, nebo hledejte něco jiného',
			'activitiesView.imports' => 'Importy',
			'loggingControls.timeUtc' => 'Čas (UTC)',
			'loggingControls.date' => 'Datum',
			'loggingControls.now' => 'Nyní',
			'loggingControls.manualTimeSettings' => 'Ruční čas',
			'loggingControls.manualTimeIncrement' => 'Přírůstek na QSO',
			'loggingControls.manualTimeIncrementNone' => 'Žádný',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} minuta', other: '${count} min', ), 
			'loggingControls.frequency' => 'Frekvence',
			'loggingControls.mode' => 'Mód',
			'loggingControls.theirCall' => 'Značka protistanice',
			'loggingControls.noteField' => 'Poznámka',
			'loggingControls.todoField' => 'Úkol',
			'loggingControls.sent' => 'Odesl.',
			'loggingControls.rcvd' => 'Přij.',
			'loggingControls.more' => 'Více',
			'loggingControls.revert' => 'Vrátit zpět',
			'loggingControls.undoDelete' => 'Vrátit smazání',
			'loggingControls.restore' => 'Obnovit',
			'loggingControls.wipe' => 'Vymazat',
			'loggingControls.undo' => 'Zpět',
			'loggingControls.pendingDeleteTapWarning' => 'Klepněte na koš ještě jednou a QSO se smaže',
			'loggingControls.pendingDeleteClickWarning' => 'Klikněte na koš ještě jednou a QSO se smaže',
			'loggingControls.deletedQsoWarning' => 'Smazané QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Klepněte na koš ještě jednou a smažete tuto položku (${kind})',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Klikněte na koš ještě jednou a smažete tuto položku (${kind})',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Smazáno: ${kind}',
			'loggingControls.timeControl' => 'Čas',
			'loggingControls.radioControl' => 'Rádio',
			'loggingControls.powerControl' => 'Výkon',
			'loggingControls.notesControl' => 'Poznámky',
			'loggingControls.power' => 'Výkon',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Ovládání logování',
			'loggingControls.spottingControl' => 'Spotování',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot na ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spotnout ${call} na ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Příliš pozdě ke spotnutí ${call}',
			'loggingControls.spotNoFreq' => 'Nejprve nastavte frekvenci ke spotnutí',
			'loggingControls.selfSpotDisabled' => 'Self-spot vypnut',
			'loggingControls.spotComment' => 'Komentář',
			'loggingControls.spottingAutoControl' => 'Automatický respot',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => 'Znovu spotnout každých ${minutes} min',
			'loggingControls.spotAutoNext' => ({required Object time}) => 'Auto za ${time}. Zastavit?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => 'Auto za ${minutes} min',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => 'Auto za ${seconds} s',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => 'Auto za ${seconds}',
			'loggingControls.spotAutoNotStarted' => 'Automatický respot nespuštěn: spot neprošel',
			'loggingControls.spotAutoMoved' => 'Automatický respot nespuštěn: frekvence se během spotování změnila',
			'loggingControls.spotAutoStopped' => 'Automatický respot zastaven',
			'loggingControls.spotAutoLeftFreq' => 'Automatický respot zastaven: frekvence se změnila',
			'loggingControls.spotAutoNoFreq' => 'Automatický respot zastaven: rádio nehlásí žádnou frekvenci',
			'loggingControls.spotBusy' => 'Ještě se odesílá jiný spot',
			'loggingControls.bandOrFreqRequired' => 'Před logováním nastavte frekvenci nebo pásmo',
			'loggingControls.missingBand' => 'Bez pásma',
			'loggingControls.missingMode' => 'Bez módu',
			'loggingControls.saveFailed' => ({required Object error}) => 'Nelze uložit: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => 'Nelze smazat: ${error}',
			'loggingControls.info.noQsos' => 'Zatím žádná QSO… Vzhůru do éteru!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} za ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} od posledního',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h za posledních 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h za posledních 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} k',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) k',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) k',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} daleko',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) daleko',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) daleko',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplicita!',
			'loggingControls.info.noticeNewBand' => 'Nové pásmo',
			'loggingControls.info.noticeNewMode' => 'Nový mód',
			'loggingControls.info.noticeNewDXCC' => 'Nové DXCC',
			'loggingControls.info.noticeNewState' => 'Nový stát',
			'loggingControls.info.noticeNewProvince' => 'Nová provincie',
			'loggingControls.info.noticeNewDay' => 'Nový den',
			'loggingControls.info.noticeNewRef' => 'Nová ref.',
			'loggingControls.info.noticeNewMult' => 'Nový násobič',
			'loggingControls.info.noticeNewZone' => 'Nová zóna',
			'loggingControls.info.noticeInvalidMode' => 'Špatný mód',
			'loggingControls.info.noticeInvalidBand' => 'Špatné pásmo',
			'loggingControls.info.noticeInvalidCategory' => 'Nelze navázat',
			'loggingControls.info.noticeOverTime' => 'Mimo čas',
			'loggingControls.info.noticeWorkedBefore' => 'Už v logu',
			'loggingControls.info.noticeNewPark' => 'Nový park',
			'loggingControls.info.noticeNewSection' => 'Nová sekce',
			'loggingControls.info.noticeBonusStation' => 'Bonusová stanice!',
			'loggingControls.info.noticeMissingExchange' => 'Chybí výměna',
			'loggingControls.info.noticeInvalidExchange' => 'Chybná výměna',
			'loggingControls.info.noticeUnknownEvent' => 'Neznámá událost',
			'loggingControls.info.noticeIncompleteCall' => 'Neúplná značka — nebodováno',
			'loggingControls.info.noticeOurGrid' => 'Nastavte náš lokátor',
			'loggingControls.info.noticeRareCounty' => 'Vzácný okres!',
			'loggingControls.info.noticeOurLocation' => 'Nastavte náš okres',
			'loggingControls.info.noticeShortGrid' => 'Krátký lokátor',
			'formChrome.untitled' => '(bez názvu)',
			'formChrome.showMore' => 'Zobrazit více',
			'formChrome.showAll' => 'Zobrazit vše',
			'formChrome.showFewer' => 'Zobrazit méně',
			'formChrome.defaults' => 'Výchozí',
			'formChrome.search' => 'Hledat',
			'formChrome.clear' => 'Vymazat',
			'formChrome.openPage' => 'Otevřít stránku',
			'formChrome.connected' => 'Připojeno',
			'formChrome.notConnected' => 'Nepřipojeno',
			'formChrome.manage' => 'Spravovat',
			'formChrome.connect' => 'Připojit',
			'formChrome.formTitle' => 'Formulář',
			'formChrome.addItem' => ({required Object label}) => 'Přidat ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Upravit ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Zobrazeno ${shown} z ${total} (vybráno ${selected})',
			'formChrome.validationError' => ({required Object error}) => 'Chyba ověření: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Chyba transformace: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Chyba: ${error}',
			'formChrome.removeItem' => 'Smazat',
			'formChrome.deleteItemTitle' => ({required Object name}) => 'Smazat ${name}?',
			'formChrome.storageUnavailable' => 'Přihlašovací údaje nejsou k dispozici',
			'qsoEditForm.title' => 'Upravit QSO',
			'qsoEditForm.operatorCall' => 'Operátor',
			'qsoEditForm.position' => 'Pracoviště',
			'qsoEditForm.theirName' => 'Jméno',
			'qsoEditForm.theirGrid' => 'Lokátor',
			'qsoEditForm.theirState' => 'Stát',
			'qsoEditForm.band' => 'Pásmo',
			'qsoEditForm.notes' => 'Poznámky',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Info protistanice',
			'qsoEditForm.sectionOur' => 'Naše info',
			'qsoEditForm.sectionNotes' => 'Poznámky',
			'qsoEditForm.theirCity' => 'Město',
			'qsoEditForm.theirCounty' => 'Okres',
			'qsoEditForm.theirEntity' => 'Entita',
			'qsoEditForm.theirCqZone' => 'CQ zóna',
			'qsoEditForm.theirItuZone' => 'ITU zóna',
			'qsoEditForm.theirArrlSection' => 'Sekce ARRL',
			'qsoEditForm.theirLat' => 'Zeměpisná šířka',
			'qsoEditForm.theirLon' => 'Zeměpisná délka',
			'qsoEditForm.theirPower' => 'Výkon protistanice',
			'qsoList.empty' => 'Zatím žádná QSO — navažte nějaké spojení!',
			'qsoList.bandOrModeWarning' => 'Ověřte prosím, že máte správné pásmo a mód',
			'qsoList.today' => 'Dnes',
			'qsoList.yesterday' => 'Včera',
			'qsoList.tomorrow' => 'Zítra',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'Najít v logu (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => 'Najít v logu',
			'qsoList.find.hint' => 'Číslo QSO nebo značka',
			'qsoList.find.noMatches' => 'Žádná shoda',
			'qsoList.find.noOperationQsos' => 'Žádná QSO v této aktivitě',
			'qsoList.find.noPeriodQsos' => 'Žádná QSO v tomto období',
			'qsoList.find.outsideQsosOne' => '1 QSO mimo tuto aktivitu',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '${count} QSO mimo tuto aktivitu',
			'qsoList.find.pastQsosOne' => '1 dřívější QSO',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '${count} dřívějších QSO',
			'loggingPanel.stats' => 'Statistiky aktivity',
			'loggingPanel.scoring' => 'Bodování',
			'loggingPanel.dxccEntities' => 'Entity DXCC',
			'loggingPanel.statesWorked' => 'Státy',
			'loggingPanel.provincesWorked' => 'Provincie',
			'loggingPanel.duplicates' => 'Duplicity',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Zobrazit obrázek',
			'callInfo.imageUnavailable' => 'Fotografie není k dispozici',
			'callInfo.photo' => 'Fotografie',
			'callInfo.notes' => 'Poznámky',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} k',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) k',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) k',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} daleko',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) daleko',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) daleko',
			'callInfo.thisOpCountOne' => '1 QSO v této aktivitě',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSO v této aktivitě',
			'callInfo.otherOpsCountOne' => '1 QSO v jiných aktivitách',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSO v jiných aktivitách',
			'callInfo.andMore' => ({required Object count}) => '… a ${count} další',
			'callInfo.withCall' => ({required Object call}) => 's ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'z ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} za posledních 7 dní',
			'callInfo.history.today' => ({required Object n}) => '${n} dnes',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => 'Nastavení',
			'settings.language' => 'Jazyk',
			'settings.languageSystem' => ({required Object language}) => 'Podle nastavení systému (${language})',
			'settings.theme.title' => 'Téma',
			'settings.theme.system' => 'Podle nastavení systému',
			'settings.theme.light' => 'Světlý',
			'settings.theme.dark' => 'Tmavý',
			'settings.themeDescription.system' => 'Podle nastavení systému',
			'settings.themeDescription.light' => 'Vždy ve světlém režimu',
			'settings.themeDescription.dark' => 'Vždy v tmavém režimu',
			'settings.fontScale' => 'Velikost písma',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Nejmenší--',
			'settings.fontScaleOpts.smallestMinus' => 'Nejmenší-',
			'settings.fontScaleOpts.smallest' => 'Nejmenší',
			'settings.fontScaleOpts.smaller' => 'Menší',
			'settings.fontScaleOpts.normal' => 'Normální',
			'settings.fontScaleOpts.larger' => 'Větší',
			'settings.fontScaleOpts.largest' => 'Největší',
			'settings.fontScaleOpts.largestPlus' => 'Největší+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Největší++',
			'settings.keepDeviceAwake.title' => 'Udržovat zařízení aktivní',
			'settings.keepDeviceAwake.descriptionOn' => 'Zůstává aktivní, když jste v zobrazení logování nebo probíhá synchronizace',
			'settings.keepDeviceAwake.descriptionOff' => 'Usíná jako obvykle',
			'settings.layoutDensity' => 'Hustota rozložení',
			'settings.layoutDensityOpts.auto' => 'Automaticky',
			'settings.layoutDensityOpts.densest' => 'Nejhustší',
			'settings.layoutDensityOpts.dense' => 'Hustá',
			'settings.layoutDensityOpts.normal' => 'Normální',
			'settings.layoutDensityOpts.sparse' => 'Řídká',
			'settings.layoutDensityOpts.sparsest' => 'Nejřidší',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'okno je příliš nízké, používá se ${effective}',
			'settings.layoutDensityAtLimit' => 'na maximum',
			'settings.distanceUnits' => 'Jednotky vzdálenosti',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometry',
			'settings.distanceUnitsOpts.miles' => 'Míle',
			'settings.userInterface' => 'Uživatelské rozhraní',
			'settings.logging.title' => 'Logování',
			'settings.logging.leftieMode.title' => 'Režim pro leváky',
			'settings.logging.leftieMode.descriptionOn' => 'Používá se rozložení pro leváky',
			'settings.logging.leftieMode.descriptionOff' => 'Používá se rozložení pro praváky',
			'settings.logging.countryFlags.title' => 'Vlajky zemí',
			'settings.logging.countryFlags.dx' => 'Zobrazit pouze pro DX spojení',
			'settings.logging.countryFlags.all' => 'Zobrazit vlajky pro všechna spojení',
			'settings.logging.countryFlags.none' => 'Nezobrazovat žádné vlajky',
			'settings.logging.countryFlagsDescription.dx' => 'Vlajky se zobrazují pouze pro DX spojení',
			'settings.logging.countryFlagsDescription.all' => 'Zobrazují se vlajky pro všechna spojení',
			'settings.logging.countryFlagsDescription.none' => 'Nezobrazují se žádné vlajky',
			'settings.logging.suggestDefaultOperator.title' => 'Navrhovat operátora',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Nabízí vaši značku jako operátora, když aktivita probíhá pod jinou značkou stanice',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Operátor zůstává prázdný, dokud ho nevyplníte',
			'settings.logging.showBearing.title' => 'Zobrazit azimut',
			'settings.logging.showBearing.descriptionOn' => 'Zobrazuje se odhadovaný azimut k protistanici',
			'settings.logging.showBearing.descriptionOff' => 'Informace o azimutu se nezobrazují',
			'settings.logging.showReverseBearing.title' => 'Zobrazit také zpětný azimut',
			'settings.logging.showReverseBearing.descriptionOn' => 'Zobrazuje se také azimut od protistanice, jako "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Zobrazuje se pouze azimut k protistanici',
			'settings.logging.switchSentRcvd.title' => 'Přepnout pořadí reportu',
			'settings.logging.switchSentRcvd.sentFirst' => 'Odeslaný první, přijatý druhý',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Přijatý první, odeslaný druhý',
			'settings.logging.jumpAfterRST.title' => 'Přejít na další pole po zadání RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Po zadání RST se přechází dál',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Automaticky se nepřechází',
			'settings.logging.defaultReport.title' => 'Výchozí report — fónie',
			'settings.logging.defaultReport.description' => 'Použije se, když je Odesl. nebo Přij. prázdné u SSB, FM nebo AM',
			'settings.logging.defaultReportCW.title' => 'Výchozí report — CW a data',
			'settings.logging.defaultReportCW.description' => 'Použije se, když je Odesl. nebo Přij. prázdné u CW, RTTY a dalších datových módů',
			'settings.logging.defaultReportFT8.title' => 'Výchozí report — FT8 a FT4',
			'settings.logging.defaultReportFT8.description' => 'Použije se, když je Odesl. nebo Přij. prázdné u módů FT',
			'settings.logging.numbersRow.title' => 'Řádek čísel',
			'settings.logging.numbersRow.description' => 'Při logování zobrazit nad klávesnicí řádek číselných kláves',
			'settings.logging.numbersRowExtra.title' => 'Klávesa lomítka a tečky',
			'settings.logging.numbersRowExtra.description' => 'Přidá kontextovou klávesu: „/“ pro značky, „.“ pro čísla',
			'settings.logging.numbersRowVibrate.title' => 'Vibrovat při stisku klávesy',
			'settings.logging.numbersRowVibrate.description' => 'Hmatová odezva při klepnutí na číselnou klávesu',
			'settings.logging.bands' => 'Preferovaná pásma',
			'settings.logging.modes' => 'Preferované módy',
			'settings.catServer.title' => 'CAT server',
			'settings.catServer.description' => 'Umožní jiným aplikacím (WSJT-X, deníky atd.) ovládat rádio přes Ham2K Logger.',
			'settings.catServer.protocol' => 'Protokol',
			'settings.catServer.protocolOpts.off' => 'Vypnuto',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Otevřený přístup',
			'settings.catServer.openAccessOn' => 'Připojit se může libovolný počítač v místní síti.',
			'settings.catServer.openAccessOff' => 'Připojit se mohou pouze aplikace na tomto počítači.',
			'settings.catServer.allowTransmit' => 'Povolit aplikacím vysílat',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'Aplikace mohou klíčovat PTT rádia, vždy nejvýše ${minutes} minut v kuse.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'Aplikace na libovolném počítači v místní síti mohou klíčovat PTT rádia, vždy nejvýše ${minutes} minut v kuse.',
			'settings.catServer.allowTransmitOff' => 'Aplikace nemohou rádio klíčovat. Použijte VOX nebo jejich vlastní nastavení PTT.',
			'settings.catServer.allowTransmitUnsupported' => 'Rádio hlavního VFO nelze z aplikace Ham2K Logger klíčovat, aplikace přes něj tedy nemohou vysílat.',
			'settings.catServer.off' => 'Vypnuto.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, spouštění…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} na portu ${port}. Připojení klienti: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} na portu ${port}, ale není připojeno žádné rádio hlavního VFO.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} nemůže naslouchat na portu ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} nemůže naslouchat na portu ${port}: používá ho jiný program, často samotný ${protocol}. Zavřete ten program nebo zvolte jiný port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} nemůže naslouchat na portu ${port}: tento počítač to nepovoluje. Zvolte port nad 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} přestal naslouchat na portu ${port}. Zkouší se znovu…',
			'settings.cluster.title' => 'DX cluster',
			'settings.cluster.description' => 'Server, na který rozšíření posílají spoty a ze kterého je čtou, přihlášená jako operátor.',
			'settings.cluster.connect' => 'Připojovat se ke clusteru',
			'settings.cluster.connectOn' => 'Rozšíření se ke clusteru připojí, když ho potřebují',
			'settings.cluster.connectOff' => 'Ke clusteru se nic nepřipojuje',
			'settings.cluster.console' => 'Zobrazit konzoli',
			'settings.cluster.consoleDescription' => 'Co cluster posílá, a místo pro zadávání příkazů',
			'settings.cluster.consoleTitle' => 'Konzole clusteru',
			'settings.cluster.consoleConnect' => 'Připojit',
			'settings.cluster.consoleDisconnect' => 'Odpojit',
			'settings.cluster.consoleCommand' => 'Příkaz',
			'settings.cluster.consoleEmpty' => 'Zatím nic. Připojte se, nebo počkejte, až cluster použije některé rozšíření.',
			'settings.cluster.consoleRetry' => ({required Object command}) => 'Odesílá se znovu: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => 'Neodesláno: ${command} (${reason})',
			'settings.cluster.server' => 'Server clusteru',
			'settings.cluster.selectServer' => 'Vybrat server',
			'settings.cluster.serverOther' => 'Jiný',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'Zatím není zadán žádný server, spoty tedy jdou na ${node}',
			'settings.cluster.customHost' => 'Server',
			'settings.cluster.customPort' => 'Port',
			'settings.cluster.password' => 'Heslo',
			'settings.cluster.passwordDescription' => 'Jen pokud je potřeba',
			'settings.cluster.passwordStored' => ({required Object node}) => 'Heslo pro ${node} je uloženo',
			'settings.cluster.scrollback' => 'Uchovávané řádky',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count} řádků',
			'settings.cluster.connection' => 'Připojení',
			'settings.cluster.statusIdle' => 'Nepřipojeno. Připojí se, když to některé rozšíření potřebuje. Klepnutím otestujete.',
			'settings.cluster.statusConnecting' => ({required Object node}) => 'Připojování k ${node}…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => 'Připojeno k ${node} jako ${call}.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => 'K ${node} se nelze připojit: ${reason}',
			'settings.cluster.statusUnsupported' => 'Ve webové verzi není k dispozici.',
			'settings.cluster.statusOff' => 'Vypnuto. Chcete-li ho používat, zapněte Připojovat se ke clusteru.',
			'settings.cluster.errors.noCall' => 'chybí volací značka operátora pro přihlášení',
			'settings.cluster.errors.connectFailed' => 'uzel je nedostupný',
			'settings.cluster.errors.needsPassword' => 'uzel vyžaduje heslo a žádné není uloženo',
			'settings.cluster.errors.loginFailed' => 'uzel přihlášení nepřijal',
			'settings.cluster.errors.disconnected' => 'uzel ukončil spojení',
			'settings.cluster.errors.timeout' => 'uzel neodpověděl',
			'settings.cluster.errors.off' => 'Připojovat se ke clusteru je vypnuto',
			'settings.spotting.title' => 'Spotování',
			'settings.spotting.respotInterval' => 'Automatický respot každých',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes} min',
			'settings.spotting.autoRespotByDefault' => 'Automatický respot ve výchozím stavu',
			'settings.spotting.autoRespotByDefaultOn' => 'Zapnout automatický respot po každém odeslaném spotu',
			'settings.spotting.autoRespotByDefaultOff' => 'Automatický respot se zapíná jen ručně',
			'settings.spotting.pulseBeforeRespot' => 'Pulzovat před každým automatickým respotem',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => 'Štítek Spotování pulzuje modře ${seconds} sekund před každým respotem',
			'settings.spotting.pulseBeforeRespotOff' => 'Před automatickým respotem se nepulzuje',
			'settings.radio.title' => 'Ovládání CAT',
			'settings.radio.loggingAndCat' => 'Logování a CAT',
			'settings.radio.tuningSection' => 'Ladění',
			'settings.radio.keyerSection' => 'Klíčovač',
			'settings.radio.servicesSection' => 'Služby',
			'settings.radio.stationConfigurationSection' => 'Konfigurace stanice',
			'settings.radio.moreSettings' => 'Další nastavení konfigurace stanice',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Ovládat PTT klávesnicí',
			'settings.radio.pttKey.modes.off' => 'Ne',
			'settings.radio.pttKey.modes.toggle' => 'Přepínat',
			'settings.radio.pttKey.modes.hold' => 'Držet',
			'settings.radio.pttKey.descriptions.off' => 'Klávesnice rádio neklíčuje.',
			'settings.radio.pttKey.descriptions.toggle' => 'Ve fónických módech klávesa PTT rádio zaklíčuje a další stisk ho odklíčuje. Po minutě se odklíčuje samo.',
			'settings.radio.pttKey.descriptions.hold' => 'Ve fónických módech rádio vysílá, dokud držíte klávesu PTT, nejvýše minutu.',
			'settings.radio.pttKey.key' => 'Klávesa PTT',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Vysílání',
			'settings.radio.smartVfoSnap.title' => 'Chytré zaokrouhlení VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Když přestanete otáčet knoflíkem, frekvence se zaokrouhlí na rozumný krok. Pouze hlasové módy.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Zůstává přesně tam, kam jste naladili.',
			'settings.radio.snapDebounce.title' => 'Chytré zaokrouhlení: Prodleva ustálení',
			'settings.radio.snapDebounce.description' => 'Jak dlouho musí knoflík stát, než se frekvence zaokrouhlí. Kratší působí okamžitě, delší nechává prostor pro pomalý pohyb.',
			'settings.radio.snapLongMove.title' => 'Chytré zaokrouhlení: Dlouhý posun',
			'settings.radio.snapLongMove.description' => 'Při posunu alespoň o tolik se frekvence zaokrouhlí na celé kHz, ať jste skončili jakkoli pomalu.',
			'settings.radio.snapMinMove.title' => 'Chytré zaokrouhlení: Nejmenší posun',
			'settings.radio.snapMinMove.description' => 'Při posunu o méně než tolik se frekvence nezaokrouhlí, takže jemné ladění zůstane beze změny.',
			'settings.radio.snapMinSpeed.title' => 'Chytré zaokrouhlení: Nejpomalejší posun',
			'settings.radio.snapMinSpeed.description' => 'Při otáčení knoflíkem pomaleji než tolik se frekvence nezaokrouhlí, pokud nešlo o dlouhý posun.',
			'settings.radio.enterSends.pillOff' => 'ESM vyp.',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter odesílá zprávy',
			'settings.radio.enterSends.off' => 'Vypnuto',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter odesílá zprávy: ${state}. Klepnutím změníte.',
			'settings.radio.keyerSpeed.title' => 'Rychlost klíčovače',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Zprávy CW klíčovače',
			'settings.radio.cwMessages.notSupported' => 'Aktuální rádio nepodporuje klíčování CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Zpráva ${n}',
			'settings.radio.cwMessages.labelField' => 'Popisek',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Popisek F${n}',
			'settings.radio.cwMessages.details' => 'Podrobnosti',
			'settings.radio.cwMessages.empty' => '(prázdné)',
			'settings.radio.cwMessages.sets' => 'Sada zpráv',
			'settings.radio.cwMessages.newSet' => 'Nová sada',
			'settings.radio.cwMessages.renameSet' => 'Přejmenovat sadu',
			'settings.radio.cwMessages.deleteSet' => 'Smazat sadu',
			'settings.radio.cwMessages.newSetName' => 'Název',
			'settings.radio.cwMessages.setDefault' => 'Výchozí',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Zprávy ESM',
			'settings.radio.cwMessages.setSaved' => 'Moje zprávy',
			'settings.radio.cwMessages.repeat' => 'Opakovat zprávu 1',
			'settings.radio.cwMessages.repeatShort' => 'Opakovat M1',
			'settings.radio.cwMessages.cooldown' => 'Prodleva před opakováním',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n} sekund',
			'settings.radio.cwMessages.repeatWait' => 'Opakování',
			'settings.radio.cwMessages.keyboard' => 'Pište a odesílejte',
			'settings.radio.cwMessages.keyboardField' => 'Pište a odesílejte',
			'settings.radio.cwMessages.help' => 'Nápověda',
			'settings.radio.cwMessages.helpTitle' => 'Psaní CW zpráv',
			'settings.radio.cwMessages.helpIntro' => 'Zprávy mohou používat šablony s těmito hodnotami:',
			'settings.radio.cwMessages.helpOpCall' => 'Vaše volací značka',
			'settings.radio.cwMessages.helpQsoCall' => 'Značka protistanice — v zásobníku // značka, která bude zalogována',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Značka protistanice, pokud je platná; prázdné pro částečnou',
			'settings.radio.cwMessages.helpQsoPartial' => 'Částečná značka; prázdné, pokud je zadána úplná platná značka',
			'settings.radio.cwMessages.helpQsoNextCall' => 'V zásobníku // značka, která bude vybrána k zalogování jako další, pokud je platná a úplná',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'V zásobníku // další částečná značka po zalogování aktuálního spojení',
			'settings.radio.cwMessages.helpQsoName' => 'Křestní jméno protistanice, jak bylo zadáno, jinak z vyhledávání',
			'settings.radio.cwMessages.helpQsoState' => 'Stát protistanice, jak byl zadán, jinak z vyhledávání',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Zpráva 1 tak, jak by byla odeslána, uvnitř jiné zprávy. Platí pro zprávy 1 až 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Report, který odesíláte',
			'settings.radio.cwMessages.helpQsoSerial' => 'Vaše pořadové číslo v závodě, kde se odesílá',
			'settings.radio.cwMessages.helpPad' => 'Doplní nulami na daný počet číslic: 7 se odešle jako 007',
			'settings.radio.cwMessages.helpCut' => 'Zkrácená čísla, T za 0 a N za 9: 599 se odešle jako 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Určí číslice ke zkrácení, v uvozovkách — 0 je T, 1 je A, 5 je E, 9 je N',
			'settings.radio.cwMessages.helpFullExample' => 'Úplný příklad:',
			'settings.radio.cwMessages.helpExample' => 'Odešle W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Když je zapnuto Enter odesílá zprávy, klávesa Enter vysílá zprávy podle jejich funkční klávesy, stejně jako N1MM. Sada Zprávy ESM začíná těmito:',
			'settings.radio.cwMessages.helpEsmCq' => 'Při Run zavolá Enter s prázdným polem značky výzvu CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Vaše výměna: po jejich značce při Run, po jejich odpovědi při S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Poděkování po zalogování spojení: qso je zalogované spojení, next to následující',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Při S&P vaše značka pro stanici, které odpovídáte',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Při Run jejich značka před vaší výměnou',
			'settings.radio.cwMessages.helpEsmAgain' => 'Žádá o opakování, když z jejich výměny nebylo nic přijato',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'Doporučené F3 pro zásobníky //: poděkuje, pak zavolá další stanici v zásobníku a odešle vaši výměnu, nebo se zeptá na částečnou značku (TU KR?); když už nic nezbývá, jen TU',
			'settings.radio.keyerControl.label' => 'Klíčovač',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => 'Hlas',
			'settings.radio.voiceMessages.title' => 'Zprávy hlasového klíčovače',
			'settings.radio.voiceMessages.notSupported' => 'Aktuální rádio nepodporuje hlasové zprávy',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Hlasová paměť ${n}',
			'settings.radio.voiceMessages.labelField' => 'Popisek',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Popisek hlasové paměti ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Prázdná',
			'settings.radio.voiceMessages.notMeasured' => 'Neznámá délka',
			'settings.radio.voiceMessages.playButton' => 'Přehrát',
			'settings.radio.voiceMessages.recordButton' => 'Nahrát',
			'settings.radio.voiceMessages.stopButton' => 'Stop',
			'settings.radio.voiceMessages.repeat' => 'Opakovat zprávu 1',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Poznámky k ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Tyto paměti jsou v rádiu zařízení ${device}. Jejich názvy a délky patří tomuto zařízení.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Uloženo v rádiu, kde to vidí i jeho další klienti.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Počkejte na indikátor [REC] na rádiu, pak podržte tlačítko PTT a nahrajte zprávu. Ukončete ji stisknutím tlačítka STOP zde v aplikaci ještě před uvolněním PTT, abyste se vyhnuli nechtěným cvaknutím.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Počkejte, až indikátor [REC] alespoň čtyřikrát blikne, pak podržte tlačítko PTT a nahrajte zprávu. Ukončete ji stisknutím tlačítka STOP zde v aplikaci ještě před uvolněním PTT, abyste se vyhnuli nechtěným cvaknutím.',
			'settings.radio.voiceMessages.pill' => 'Hlas',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Přehrát paměť ${n}',
			'settings.radio.voiceMessages.stop' => 'Stop',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Nahrát paměť ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Zastavit nahrávání',
			'settings.radio.voiceMessages.playing' => 'Přehrávání…',
			'settings.radio.voiceMessages.recording' => 'Nahrávání…',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Nahrává se ${label}',
			'settings.radio.voiceMessages.doubtful' => 'Přehrálo to rádio? Hned hlásilo, že je nečinné.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Paměti musíte nahrát přímo na rádiu.',
			'settings.radio.voiceMessages.sets' => 'Sada zpráv',
			'settings.radio.voiceMessages.soundFilesSet' => 'Zvukové soubory na tomto počítači',
			'settings.radio.voiceMessages.openFileButton' => 'Otevřít soubor',
			'settings.radio.voiceMessages.newSet' => 'Nová sada',
			'settings.radio.voiceMessages.renameSet' => 'Přejmenovat sadu',
			'settings.radio.voiceMessages.deleteSet' => 'Smazat sadu',
			'settings.radio.voiceMessages.newSetName' => 'Název',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => 'Smazat ${name} a její nahrávky? Nelze to vrátit zpět.',
			'settings.radio.voiceMessages.output' => 'Odesílat zvuk do',
			'settings.radio.voiceMessages.input' => 'Nahrávat z',
			'settings.radio.voiceMessages.outputRadio' => 'Odesílat do rádia přes síť',
			'settings.radio.voiceMessages.inputDefault' => 'Výchozí systému',
			'settings.radio.voiceMessages.pickDevice' => 'Vyberte zvukové zařízení',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (nepřipojeno)',
			'settings.radio.voiceMessages.lead' => 'Prodleva po zaklíčování',
			'settings.radio.voiceMessages.tail' => 'Prodleva před odklíčováním',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => 'Poslechnout',
			'settings.radio.voiceMessages.notRecorded' => 'Nenahráno',
			'settings.radio.voiceMessages.unplayable' => 'Tento soubor nelze přehrát',
			'settings.radio.voiceMessages.problemNoOutput' => 'Před přehráním zprávy vyberte zvukové zařízení, které vede do rádia.',
			'settings.radio.voiceMessages.problemOutputMissing' => 'Zvukové zařízení, které vede do rádia, není připojeno.',
			'settings.radio.voiceMessages.problemInputMissing' => 'Nahrávací zařízení není připojeno.',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'Zvukové zařízení se nepodařilo otevřít.',
			'settings.radio.voiceMessages.problemNotRecorded' => 'Tato zpráva zatím nemá nahrávku.',
			'settings.radio.voiceMessages.problemRecordingSilent' => 'Z nahrávacího zařízení nebylo nic slyšet, zpráva proto zůstala beze změny. Zkontrolujte vstup a to, že aplikace smí používat mikrofon.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => 'Rádio teď nebere zvuk z aplikace. Je potřeba síťové připojení k rádiu.',
			'settings.radio.voiceMessages.problemSourceRefused' => 'Rádio nepřepnulo vysílaný zvuk na aplikaci, zpráva se proto zastavila. Nastavte rádio tak, aby vysílalo zvuk z aplikace.',
			'settings.radio.voiceMessages.problemCannotKey' => 'Toto rádio nelze klíčovat přes CAT, počítač do něj tedy nemůže přehrávat zprávy.',
			'settings.radio.voiceMessages.problemUnplayable' => 'Soubor této zprávy není zvukový soubor, který aplikace umí přehrát. Použijte soubor WAV, FLAC nebo MP3, nebo ji nahrajte znovu.',
			'settings.radio.voiceMessages.problemRecordingFailed' => 'Nahrávání bylo předčasně ukončeno, zpráva proto zůstala beze změny. Zkontrolujte, že je nahrávací zařízení stále připojeno a že je na disku místo.',
			'settings.radio.voiceMessages.problemFileFailed' => 'Nahrávku se nepodařilo uložit na místo zprávy, zpráva proto zůstala beze změny.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'Tato zpráva potřebuje slova, která jste nenahráli: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'Šablona této zprávy má problém: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => 'Zprávy namluvené vašimi slovy se přehrávají v aktivitě, kde je spojení, pro které je říct.',
			'settings.radio.voiceMessages.problemNothingSaid' => 'Tato zpráva pro toto spojení nic neříká.',
			'settings.radio.voiceMessages.templateField' => 'Říct mými slovy',
			'settings.radio.voiceMessages.templateHelp' => 'Nechte prázdné, aby se přehrála nahrávka. Jinak se zpráva řekne slovy, která jste nahráli, doplněnými pro každé spojení podle těchto hodnot:',
			'settings.radio.voiceMessages.help' => 'Nápověda',
			'settings.radio.voiceMessages.helpTitle' => 'Říkání zpráv vašimi slovy',
			'settings.radio.voiceMessages.helpFullExample' => 'Celá zpráva:',
			'settings.radio.voiceMessages.helpExample' => 'Značka protistanice, její report a vaše nahrávka „QSL?“',
			'settings.radio.voiceMessages.playOnRadio' => 'Přehrát na rádiu',
			'settings.radio.voiceMessages.templateHelpCall' => 'Značka protistanice',
			'settings.radio.voiceMessages.templateHelpReport' => 'Report, který jí dáváte',
			'settings.radio.voiceMessages.templateHelpMessage' => 'Nahrávka zprávy 2, přehraná tak, jak byla nahrána',
			'settings.radio.voiceMessages.voiced' => 'Řečeno vašimi slovy',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => 'Řekne: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => 'Zatím nenahráno: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => 'Otevřete aktivitu, abyste viděli, co řekne.',
			'settings.radio.voiceMessages.wordsDescription' => 'Použijte vlastní hlas pro značky, čísla a další.',
			'settings.radio.voiceWords.title' => 'Nahrávky slov',
			'settings.radio.voiceWords.callField' => 'Slova pro operátora',
			'settings.radio.voiceWords.intro' => 'Každé slovo nebo číslo nahrajte třikrát, rychle za sebou, tak jak ho říkáte ve volací značce. Delší fráze se nahrávají jen jednou.',
			'settings.radio.voiceWords.recordAll' => 'Nahrát vše',
			'settings.radio.voiceWords.recordAllGuide' => 'Každé slovo přečtěte třikrát za sebou a frázi o několika slovech jednou, s nádechem mezi řádky. Po posledním stiskněte Stop.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => 'Řekněte „${word} ${word} ${word}“ a pak stiskněte Stop.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => 'Řekněte „${words}“ a pak stiskněte Stop.',
			'settings.radio.voiceWords.recorded' => 'Nahráno',
			'settings.radio.voiceWords.notRecorded' => 'Nenahráno',
			'settings.radio.voiceWords.addPhrase' => 'Přidat frázi',
			'settings.radio.voiceWords.phraseField' => 'Fráze tak, jak ji píšete ve zprávě',
			'settings.radio.voiceWords.deletePhrase' => 'Smazat frázi',
			'settings.radio.voiceWords.tryField' => 'Zkuste říct',
			'settings.radio.voiceWords.pauseLetters' => 'Pauza mezi písmeny',
			'settings.radio.voiceWords.pauseWords' => 'Pauza mezi slovy',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => 'Rychlost',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => 'Pokročilé nastavení',
			'settings.radio.voiceWords.splitSilent' => 'V nahrávce nebylo nic slyšet.',
			'settings.radio.voiceWords.splitNotThreeTakes' => 'Nepodařilo se najít tři opakování. Řekněte slovo třikrát za sebou a zkuste to znovu.',
			'settings.radio.voiceWords.splitLineCount' => 'V nahrávce se nepodařilo najít všechna slova. Každé přečtěte třikrát, s nádechem mezi slovy.',
			'settings.radio.voiceWords.splitLinesTooClose' => 'Slova se nepodařilo rozlišit. Nechte mezi slovy delší nádech.',
			'settings.radio.avoidZeroBeat.title' => 'Vyhnout se nulovým záznějům na spotech',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'S připojeným rádiem naladí pár Hz vedle CW spotu, aby všichni, kdo odpovídají, nevolali na stejném tónu.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Ladí přesně na spotovanou frekvenci.',
			'settings.radio.zeroBeatRange.title' => 'Nulový zázněj: Rozsah odskoku',
			'settings.radio.zeroBeatRange.description' => 'Jak daleko od spotované frekvence přistát, na kteroukoli stranu. Odskok není nikdy blízko nule — to by byl opět nulový zázněj.',
			'settings.help.title' => 'Nápověda a zdroje',
			'settings.help.description' => 'Komunita a podpora',
			'settings.help.forums' => 'Ham2K Fóra',
			'settings.help.forumsDescription' => 'Najděte pomoc, dejte zpětnou vazbu, diskutujte o nápadech…',
			'settings.help.chat' => 'Ham2K Chat',
			'settings.help.chatDescription' => 'Discord server pro naši online komunitu',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videa a živé vysílání',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Protože fotografií nikdy není dost…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Sledujte nás pro novinky a aktualizace',
			'settings.help.contact' => 'Kontaktujte nás',
			'settings.help.contactDescription' => 'help@ham2k.com — ale nejprve zkuste Fóra nebo Chat!',
			'settings.exports.title' => 'Exporty',
			'settings.extensionSections.activities' => 'Aktivity',
			'settings.extensionSections.hunting' => 'Lovení',
			'settings.extensionSections.contests' => 'Závody',
			'settings.extensionSections.lookups' => 'Vyhledávání',
			'settings.extensionSections.dashboard' => 'Přehled',
			'settings.map.title' => 'Mapy',
			'settings.map.style.title' => 'Styl mapy',
			'settings.map.showCallsigns.title' => 'Zobrazit značky',
			'settings.map.showCallsigns.description' => 'Každé spojení je štítek s jeho značkou v barvě pásma',
			'settings.map.showGrayline.title' => 'Zobrazit šedou linii',
			'settings.map.showGrayline.description' => 'Stínuje noční stranu Země, soumrak jako přechod',
			'settings.map.styleOpts.automatic' => 'Automaticky',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Soukromí',
			'settings.privacy.shareAppData.title' => 'Sdílet údaje o používání aplikace',
			'settings.privacy.shareAppData.descriptionOn' => 'Pomáháte nám vylepšovat aplikaci sdílením údajů o používání, konfiguraci, pádech a výkonu',
			'settings.privacy.shareAppData.descriptionOff' => 'Údaje o používání aplikace zůstávají soukromé.\nTým Ham2K nebude moci detekovat pády ani jiné problémy.',
			'settings.privacy.shareOpData.title' => 'Sdílet údaje o aktivitách',
			'settings.privacy.shareOpData.descriptionOn' => 'Některé údaje o aktivitách se sdílejí veřejně a s ostatními uživateli',
			'settings.privacy.shareOpData.descriptionOff' => 'Údaje o aktivitách zůstávají soukromé',
			'settings.privacy.privacyPolicy' => 'Zásady ochrany osobních údajů',
			'settings.privacy.termsOfService' => 'Podmínky používání služby',
			'settings.operatorCall' => 'Volací značka operátora',
			'settings.sync.title' => 'Synchronizace v cloudu',
			'settings.sync.moreSettings' => 'Další nastavení synchronizace',
			'settings.sync.enable' => 'Zapnout synchronizaci',
			'settings.sync.deviceKey' => 'Klíč zařízení',
			'settings.peers.title' => 'Spárovaná zařízení',
			'settings.peers.enable' => 'Připojovat se k jiným zařízením',
			'settings.peers.enableDescription' => 'Povolit sdílení aktivit, logování, CAT a GPS s jinými zařízeními v místní síti',
			'settings.peers.bleEnable' => 'Připojit přes Bluetooth',
			'settings.peers.bleDescription' => 'Použít Bluetooth LE k připojení i bez místní sítě',
			'settings.peers.thisDevice' => 'Toto zařízení',
			'settings.peers.deviceName' => 'Název',
			'settings.peers.deviceNameHint' => 'Jak toto zařízení vidí ostatní zařízení',
			'settings.peers.pairedDevices' => 'Propojená zařízení',
			'settings.peers.noPairedDevices' => 'Zatím žádná propojená zařízení. Pro propojení zapněte tuto volbu na jiném zařízení v této síti.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Propojená zařízení nelze načíst: ${error}',
			'settings.peers.nearby' => 'V okolí',
			'settings.peers.connected' => 'Připojeno',
			'settings.peers.viaBluetooth' => 'přes Bluetooth',
			'settings.peers.connecting' => 'Připojování…',
			'settings.peers.syncing' => 'Synchronizace…',
			'settings.peers.waitingForThem' => 'Čeká se na druhé zařízení',
			'settings.peers.notConnected' => 'Nepřipojeno',
			'settings.peers.wantsToPair' => 'chce sdílet tuto aktivitu',
			'settings.peers.allow' => 'Povolit',
			'settings.peers.link' => 'Propojit',
			'settings.peers.reject' => 'Odmítnout',
			'settings.peers.forget' => 'Zapomenout',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Zapomenout ${name}?',
			'settings.peers.forgetBody' => 'Přestane se synchronizovat s tímto zařízením. Později ho můžete znovu povolit a již zalogovaná spojení zůstanou zachována.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Propojit s ${name}',
			'settings.peers.pairBody' => 'Toto zařízení je ve vaší místní síti a chce se připojit.',
			'settings.peers.pairBodyBle' => 'Toto zařízení je v okolí a chce se připojit přes Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID zařízení',
			'settings.peers.pairWarning' => 'Propojujte jen se zařízeními, která znáte. Žádost může poslat jakékoli zařízení v této síti.',
			'settings.peers.pairWarningBle' => 'Propojujte jen se zařízeními, která znáte. Žádost může poslat jakékoli zařízení v okolí.',
			'settings.peers.problem' => ({required Object error}) => 'Místní síť je nedostupná: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Připojeno k ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Ztraceno spojení s ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Spárovaná zařízení: připojeno ${connected} z ${linked}',
			'settings.peers.screenEnable' => 'Sdílet obrazovky a okna',
			'settings.peers.screenDescription' => 'Povolit jiným zařízením zobrazovat obrazovky nebo okna z tohoto počítače',
			'settings.peers.screenSources' => 'Obrazovky a okna',
			'settings.peers.screenRefresh' => 'Obnovit seznam',
			'settings.peers.screenUnsupportedPlatform' => 'Toto zařízení nemůže sdílet svou obrazovku. macOS to umí; každé zařízení ale může zobrazit obrazovku sdílenou jiným.',
			'settings.peers.screenUnsupportedVersion' => 'Sdílení obrazovky vyžaduje macOS 12.3 nebo novější. Toto zařízení stále může zobrazit obrazovku sdílenou jiným.',
			'settings.peers.screenNeedsPermission' => 'macOS potřebuje vaše oprávnění k nahrávání obrazovky, než ji tato aplikace bude moci sdílet.',
			'settings.peers.screenGrantPermission' => 'Požádat o oprávnění',
			'settings.peers.screenRelaunchAfterGranting' => 'Povolte to v Nastavení systému v části Soukromí a zabezpečení → Nahrávání obrazovky, pak tuto aplikaci ukončete a znovu otevřete — macOS aplikaci o změně informuje až při dalším spuštění.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Sdílení obrazovky: ${error}',
			'settings.peers.screenChooseTitle' => 'Vyberte, co sdílet',
			'settings.peers.screenChooseButton' => 'Vybrat, co sdílet…',
			'settings.peers.screenTabScreens' => 'Obrazovky',
			'settings.peers.screenTabApps' => 'Aplikace',
			'settings.peers.screenTabWindows' => 'Okna',
			'settings.peers.screenTabEmpty' => 'Nic takového nebylo nalezeno.',
			'settings.peers.screenSharedSummaryNone' => 'Zatím nic nevybráno.',
			'settings.peers.screenThisDevice' => 'Toto zařízení',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Zobrazeno na ${devices}',
			'settings.peers.screenSharedToNobody' => 'Nikde se nezobrazuje',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Přestat sdílet ${name}',
			'settings.developerMode' => 'Režim vývojáře',
			'settings.syncPanel.configuration' => 'Konfigurace synchronizace',
			'settings.syncPanel.enableTitle' => 'Synchronizovat s Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Zálohuje a synchronizuje váš log mezi zařízeními',
			'settings.syncPanel.disabledDescription' => 'Vypnuto — data zůstávají jen na tomto zařízení',
			'settings.syncPanel.syncing' => 'Synchronizace',
			'settings.syncPanel.account' => 'Účet',
			'settings.syncPanel.refresh' => 'Obnovit',
			'settings.syncPanel.switchAccounts' => 'Přepnout účet',
			'settings.syncPanel.switchAccountsDescription' => 'Propojit toto zařízení s jiným účtem pomocí QR kódu nebo e-mailu',
			'settings.syncPanel.connectionRequests' => 'Žádosti o připojení',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Jedno zařízení čeká na připojení k tomuto účtu', other: '${n} zařízení čeká na připojení k tomuto účtu', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mail účtu',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Potvrzení odesláno na ${email}. Změnu dokončíte otevřením odkazu v e-mailu.',
			'settings.syncPanel.resendConfirmation' => 'Znovu odeslat potvrzovací e-mail',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Čeká se na ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Znovu odesláno na ${email}.',
			'settings.syncPanel.deviceLinked' => 'Toto zařízení je nyní propojeno s tímto účtem.',
			'settings.syncPanel.checking' => 'Kontrola…',
			'settings.syncPanel.notLinked' => 'Zatím nepropojeno',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Nahradit místní data?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${n} aktivita', other: '${n} aktivit', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.syncPanel.counts' => 'Synchronizovaná data',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Toto zařízení: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Čeká na nahrání: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Server: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Toto zařízení: kontrola…',
			'settings.syncPanel.countsServerChecking' => 'Server: kontrola…',
			'settings.syncPanel.countsServerUnavailable' => 'Server: není k dispozici',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Tímto se zálohuje a z tohoto zařízení vymaže ${operations} a ${qsos} a místo nich se stáhnou data účtu. Záloha zůstane v databázi tohoto zařízení.',
			'settings.syncPanel.replace' => 'Nahradit',
			'settings.syncPanel.pendingBannerTitle' => 'Zjištěn nový účet Ham2K Log Filer',
			'settings.syncPanel.pendingBannerBody' => 'Ponechte stávající aktivity a QSO tohoto zařízení a slučte je do účtu, nebo je nahraďte daty účtu (záloha zůstane na tomto zařízení v obou případech).',
			'settings.syncPanel.combine' => 'Sloučit',
			'settings.syncPanel.authIssueTitle' => 'Synchronizace se nemůže připojit',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer toto zařízení opakovaně odmítá. Zkontrolujte volací značku v nastavení synchronizace.',
			'settings.syncPanel.openSettings' => 'Otevřít nastavení synchronizace',
			'settings.accounts.title' => 'Účty, služby a zdroje dat',
			'settings.accounts.none' => 'Žádná aktivní rozšíření s účty',
			'settings.accounts.notConfigured' => 'Nenakonfigurováno',
			'settings.accounts.connected' => 'Připojeno',
			'settings.accounts.cancelLogin' => 'Zrušit přihlášení',
			'settings.accounts.openInBrowser' => 'Otevřít v prohlížeči',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Přihlášeno jako ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Stiskněte Uložit, aby účet zůstal připojený.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Připojeno k ${label}',
			'settings.accounts.connect' => 'Připojit',
			'settings.accounts.disconnect' => 'Odpojit',
			'settings.accounts.connectedAs' => 'Připojeno jako',
			'settings.accounts.test' => 'Otestovat',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Uložení selhalo: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Přihlášení selhalo: ${error}',
			'settings.accounts.lookupFailed' => 'Účty teď nejsou k dispozici — za chvíli to zkuste znovu',
			'settings.accounts.browserLoginTitle' => 'Dokončete přihlášení ve webovém prohlížeči',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Až budete hotovi, prohlížeč se pokusí otevřít odkaz začínající „${prefix}“. Váš počítač pro něj nejspíš nemá nic zaregistrováno, proto tento odkaz zkopírujte (z adresního řádku nebo z chybové stránky, kterou prohlížeč zobrazí) a vložte ho sem.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger nemohl otevřít váš prohlížeč. Zkopírujte níže uvedený přihlašovací odkaz a otevřete ho sami, pak zkopírujte odkaz, na který vás přesměruje (začíná „${prefix}“), a vložte ho sem.',
			'settings.accounts.copyLoginLink' => 'Kopírovat přihlašovací odkaz',
			'settings.accounts.pastedLinkLabel' => 'Vložte odkaz sem',
			'settings.accounts.finishLogin' => 'Dokončit přihlášení',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Toto není přihlašovací odkaz — měl by začínat „${prefix}“.',
			'settings.accounts.pastedLinkWrongLogin' => 'Tento odkaz patří k jinému pokusu o přihlášení. Zavřete tuto stránku a připojte se znovu.',
			'settings.accounts.pastedLinkNoCode' => 'Tento odkaz neobsahuje přihlašovací kód. Nejprve dokončete přihlášení, pak zkopírujte odkaz, na který vás přesměruje.',
			'settings.accounts.pastedLinkMalformed' => 'Odkaz vypadá useknutý. Zkopírujte ho celý a vložte znovu.',
			'settings.accounts.relayLoginWaiting' => 'Čeká se, až dokončíte přihlášení — pak se automaticky pokračuje.',
			'settings.accounts.loginNoResponse' => 'Toto zařízení zatím nedostalo odpověď z přihlášení. Pokud jste už v prohlížeči skončili, zrušte to a zkuste se připojit znovu.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger nemohl automaticky otevřít váš prohlížeč. Přihlašovací stránku otevřete sami tlačítkem níže.',
			'settings.accounts.relayLoginUnavailable' => 'Synchronizační server potřebný k dokončení přihlášení je nedostupný. Zkontrolujte připojení a zkuste to znovu.',
			'settings.accounts.loginIncompleteResponse' => 'Tento pokus o přihlášení se nedokončil správně. Zkuste se prosím připojit znovu.',
			'settings.accounts.noKeyringTitle' => 'Přihlašovací údaje k účtům nelze uložit',
			'settings.accounts.noKeyringText' => 'Ham2K Logger nemůže na tomto počítači najít službu klíčenky, takže přihlašovací údaje k účtům nelze ukládat ani číst — připojení účtu selže, dokud se to nevyřeší. Nainstalujte a spusťte **gnome-keyring**, **KWallet** nebo **KeePassXC**, nebo odemkněte klíčenku, kterou už máte, a restartujte. Logování, exporty a datové soubory to neovlivní; synchronizace logu zůstane po tu dobu vypnutá.',
			'settings.accounts.noKeyringInline' => 'Přihlašovací údaje nelze uložit: klíčenka tohoto počítače je nedostupná. Nainstalujte a spusťte gnome-keyring, KWallet nebo KeePassXC, nebo odemkněte tu, kterou máte.',
			'settings.accounts.noSecureStorageInline' => 'Přihlašovací údaje nelze uložit: zabezpečené úložiště tohoto počítače je nedostupné.',
			'settings.station.title' => 'Konfigurace stanice a ovládání CAT',
			'settings.station.none' => 'Není nakonfigurováno žádné vybavení',
			'settings.station.add' => 'Přidat',
			'settings.station.addTitle' => 'Přidat vybavení',
			'settings.station.searchHint' => 'Hledat vybavení',
			'settings.station.noMatches' => 'Žádné odpovídající vybavení',
			'settings.station.detectedEquipment' => 'Nalezené vybavení',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Nelze naslouchat rádiím: ${error}',
			'settings.station.edit' => 'Upravit vybavení',
			'settings.station.name' => 'Název',
			'settings.station.nameDescription' => 'Jak mu říkáte — „Levé rádio“. Nepovinné.',
			'settings.station.transport' => 'Připojení',
			'settings.station.host' => 'Adresa',
			'settings.station.hostDescription' => 'Název hostitele nebo IP adresa rádia ve vaší síti.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Adresa je povinná',
			'settings.station.portInvalid' => 'Port musí být mezi 1 a 65535',
			'settings.station.connect' => 'Připojit',
			'settings.station.disconnect' => 'Odpojit',
			'settings.station.remove' => 'Odebrat',
			'settings.station.removeTitle' => ({required Object name}) => 'Odebrat ${name}?',
			'settings.station.removeMessage' => 'Odebere se pouze z aplikace. Nastavení vybavení zůstane beze změny.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Nerozpoznaný typ vybavení „${typeKey}“',
			'settings.station.report' => 'Nahlásit',
			'settings.station.reportTitle' => 'Nahlásit toto rádio',
			'settings.station.reportIntro' => 'Napište nám, o jaké rádio skutečně jde a jak to dopadlo. Z vašeho hlášení vznikne karta, kterou čte tým Ham2K, a to, co napíšete o zprovoznění, může pomoci dalšímu operátorovi se stejným rádiem.',
			'settings.station.reportManufacturer' => 'Výrobce',
			'settings.station.reportManufacturerDescription' => 'Kdo ho vyrábí — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Výrobce je povinný',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'Model tak, jak ho uvádí samotné rádio — „IC-7300“, „FT-991A“.',
			'settings.station.reportModelRequired' => 'Model je povinný',
			'settings.station.reportOutcome' => 'Jak to dopadlo?',
			'settings.station.reportOutcomeWorks' => 'Fungovalo dobře',
			'settings.station.reportOutcomeIssues' => 'Fungovalo, s problémy',
			'settings.station.reportOutcomeFails' => 'Vůbec nefungovalo',
			'settings.station.reportOutcomeRequired' => 'Napište nám prosím, jak to dopadlo',
			'settings.station.reportComments' => 'Komentáře',
			'settings.station.reportCommentsPlaceholder' => 'Co fungovalo, co ne, cokoli, co vás překvapilo.',
			'settings.station.reportHints' => 'Rady k řešení potíží',
			'settings.station.reportHintsPlaceholder' => 'Chcete navrhnout rady k řešení potíží pro ostatní uživatele?',
			'settings.station.reportSend' => 'Odeslat hlášení',
			'settings.station.reportSending' => 'Odesílání hlášení…',
			'settings.station.reportSent' => ({required Object ref}) => 'Děkujeme — vaše hlášení bylo zaevidováno jako ${ref}.',
			'settings.station.reportSentNoRef' => 'Děkujeme — vaše hlášení bylo odesláno.',
			'settings.station.reportFailed' => ({required Object error}) => 'Hlášení nebylo odesláno: ${error}',
			'settings.station.troubleshootingNotes' => 'Poznámky k řešení potíží',
			'settings.station.mainVfo' => 'Hlavní VFO',
			'settings.station.useAsMainVfo' => 'Použít jako hlavní VFO',
			'settings.station.serialPort' => 'Sériový port',
			'settings.station.serialPortDescription' => 'Port, na kterém se objevuje CAT rozhraní rádia.',
			'settings.station.serialPortNone' => 'Nebyly nalezeny žádné sériové porty',
			'settings.station.serialPortRequired' => 'Vyberte sériový port',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} z ${total}',
			'settings.station.serialPortSuggested' => 'doporučeno',
			'settings.station.serialPortJustNow' => 'Nedávno připojeno',
			'settings.station.serialPortNoDriver' => 'bez ovladače',
			'settings.station.serialDeviceRequest' => 'Přidat zařízení USB…',
			'settings.station.bleDevice' => 'Zařízení Bluetooth LE',
			'settings.station.bleDeviceDescription' => 'Sériový most, přes který je vaše rádio připojeno, například LiNK500MP v Mode 4 nebo sériový adaptér BLE.',
			'settings.station.bleScan' => 'Vyhledat zařízení Bluetooth LE…',
			'settings.station.bleScanNoneFound' => 'Nebyla nalezena žádná zařízení Bluetooth LE. Zkontrolujte, že je most zapnutý, v dosahu a v režimu Bluetooth LE (Mode 4 na LiNK500MP).',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'Vyhledávání Bluetooth LE se nepodařilo spustit: ${reason}',
			'settings.station.bleOff' => 'Bluetooth je vypnuté.',
			'settings.station.bleDenied' => 'Oprávnění pro Bluetooth nebylo uděleno. Povolte ho v nastavení systému a zkuste to znovu.',
			'settings.station.bleUnsupported' => 'Toto zařízení nemá Bluetooth LE.',
			'settings.station.bleStarting' => 'Bluetooth se ještě spouští. Za chvíli to zkuste znovu.',
			'settings.station.bleConnectFailed' => 'Zařízení Bluetooth LE je nedostupné. Zkontrolujte, že je zapnuté, v dosahu a není připojené k jiné aplikaci.',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'Toto zařízení Bluetooth LE nemá žádnou sériovou službu, kterou aplikace zná. Nahlaste ho prosím i s jeho službami: ${services}',
			'settings.station.baudRate' => 'Rychlost (baud)',
			'settings.station.baudRateDescription' => 'Musí odpovídat menu CAT rádia. Při neshodě rádio vrací nesmysly a žádnou chybu.',
			'settings.station.serialRtsHigh' => 'Držet RTS v úrovni high',
			'settings.station.serialRtsHighDescription' => 'Pouze pro rádio, které před odpovědí čeká na RTS, například Yaesu se zapnutým CAT RTS. U Digirig, SignaLink a většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high spustí vysílání.',
			'settings.station.serialDtrHigh' => 'Držet DTR v úrovni high',
			'settings.station.serialDtrHighDescription' => 'Pouze pro CAT rozhraní napájené z DTR, například některé kabely RS-232 pro FT-817. U mnoha kabelů DTR klíčuje CW nebo PTT a jeho držení v úrovni high spustí vysílání.',
			'settings.station.serialUsbDriver' => 'Ovladač čipu USB',
			'settings.station.serialUsbDriverDescription' => 'Automaticky rozpozná většinu adaptérů. Čip vybírejte jen u adaptéru, u kterého seznam portů hlásí „bez ovladače“ — jeho název najdete na obalu nebo v seznamu zařízení USB.',
			'settings.station.serialUsbDriverAuto' => 'Automaticky',
			'settings.station.civAddress' => 'CI-V adresa rádia',
			'settings.station.civAddressDescription' => 'Hexadecimálně, jak ji ukazuje menu CI-V rádia. IC-705 má z výroby A4.',
			'settings.station.civAddressInvalid' => 'CI-V adresa jsou dvě hexadecimální číslice, 01 až FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Ze kterého slice rádia toto připojení čte a který ladí.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Vyberte jeden ze slice rádia, A až H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} se na tomto rádiu nepoužívá — vyberte jiný slice, nebo ho vytvořte v SmartSDR',
			'settings.station.channelNotInUse' => 'nepoužívá se',
			'settings.station.channelHeldByUnknown' => 'používá ho jiný program',
			'settings.station.flexNoSlices' => 'Toto rádio nenahlásilo žádné slice — zkontrolujte, že běží SmartSDR a že se tento klient smí přihlásit k odběru',
			'settings.station.spectrumUnsupported' => 'Toto rádio přes CAT neposílá spektrum',
			'settings.station.spectrumRequiresBaud' => 'Vyžaduje CAT na 115200 bps',
			'settings.station.spectrumNoRadio' => 'Není připojeno žádné rádio',
			'settings.station.spectrumWaiting' => 'Čeká se na spektrum z rádia…',
			'settings.station.spectrumUnavailable' => 'Zobrazení spektra není k dispozici',
			'settings.station.spectrumNoDaxChannel' => 'Všechny kanály DAX IQ na tomto rádiu se používají',
			'settings.station.spectrumNoPanadapter' => 'Tento slice nemá na rádiu žádný panadaptér',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Rádio odmítlo stream DAX IQ (chyba ${code})',
			'settings.station.spectrumNoUdp' => 'Data spektra z rádia se nedostanou k tomuto zařízení',
			'settings.station.spectrumK4Unavailable' => 'Spektrum K4 přes LAN nelze přijímat. Zkouší se znovu…',
			'settings.station.spectrumK4RemoteUnavailable' => 'Vzdálené spektrum K4 nelze přijímat',
			'settings.station.spectrumScopeRefused' => 'Rádio odmítlo příkazy pro scope',
			'settings.station.spectrumOutOfRange' => 'Scope rádia je nastaven mimo rozsah, který dokáže zobrazit',
			'settings.station.spectrumBandUnsupported' => 'Scope rádia nelze na tomto pásmu zobrazit',
			'settings.station.spectrumSdrNoRadio' => 'Čeká se na frekvenci propojeného rádia…',
			'settings.station.spectrumSdrNotConnected' => 'SDR není připojeno',
			'settings.station.spectrumSdrNoIf' => 'Nastavte mezifrekvenci rádia v nastavení tohoto SDR',
			'settings.station.sdrRadio' => 'Zobrazuje spektrum pro',
			'settings.station.sdrRadioDescription' => 'Zobrazení spektra u tohoto rádia čerpá z tohoto přijímače místo z vlastního scope rádia.',
			'settings.station.sdrRadioMain' => 'Hlavní rádio',
			'settings.station.sdrTuning' => 'Anténní vstup',
			'settings.station.sdrTuningDescription' => 'Odkud přijímač bere signál. Na vlastní anténě se ladí sám podle rádia; na mezifrekvenčním výstupu rádia zůstává na mezifrekvenci.',
			'settings.station.sdrTuningIndependent' => 'Vlastní anténa',
			'settings.station.sdrTuningIfTap' => 'Mezifrekvenční výstup rádia',
			'settings.station.sdrIfHz' => 'Mezifrekvence (Hz)',
			'settings.station.sdrIfHzDescription' => 'Jen pro mezifrekvenční výstup: frekvence, na které na mezifrekvenci leží naladěná frekvence rádia, například 68330000 u FT-817.',
			'settings.station.sdrIfInverted' => 'Mezifrekvence je invertovaná',
			'settings.station.sdrGainDb' => 'Zisk (dB)',
			'settings.station.sdrGainDbDescription' => 'Pro automatický zisk přijímače nechte prázdné.',
			'settings.station.sdrOffsetHz' => 'Posun frekvence (Hz)',
			'settings.station.sdrOffsetHzDescription' => 'Přičte se ke každé frekvenci poslané do přijímače, pro upkonvertor: 125000000 u Ham It Up.',
			'settings.station.sdrPpm' => 'Korekce frekvence (ppm)',
			'settings.station.rtlDirectSampling' => 'Přímé vzorkování',
			'settings.station.rtlDirectSamplingDescription' => 'Pro KV na RTL-SDR V3 bez upkonvertoru. RTL-SDR V4 dosáhne na KV i bez něj.',
			'settings.station.rtlDirectSamplingOff' => 'Vypnuto',
			'settings.station.rtlDirectSamplingI' => 'Větev I',
			'settings.station.rtlDirectSamplingQ' => 'Větev Q',
			'settings.station.rtlTcpNotAServer' => 'Toto není server rtl_tcp',
			'settings.station.rtlTcpNotes' => 'Připojuje se k **serveru rtl_tcp, který si sami spustíte** na počítači, do kterého je dongle zapojený.\n\n- **Spusťte ho** příkazem `rtl_tcp -a 0.0.0.0`, aby se k němu dostaly i ostatní počítače; na stejném počítači stačí samotné `rtl_tcp`.\n- **Port** je 1234, pokud jste ho nespustili s `-p`.\n- **Jeden program najednou:** rtl_tcp obsluhuje jediného klienta. Aplikace se připojí jen tehdy, když je zobrazeno spektrum, a pár sekund po jeho zavření se odpojí.\n- **Na Androidu** stejný server na telefonu spouští aplikace *SDR driver*.',
			'settings.station.rspTcpNotes' => 'Připojuje se k **serveru rsp_tcp, který si sami spustíte** na počítači, do kterého je RSP zapojené a kde je nainstalované API od SDRplay.\n\n- **Spusťte ho** příkazem `rsp_tcp -a 0.0.0.0`.\n- **Port** je 1234, pokud jste ho nespustili s `-p`.\n- **Jeden program najednou:** server přijme jediného klienta. Aplikace se připojí jen tehdy, když je zobrazeno spektrum.',
			'settings.station.n3fjpNoRig' => 'N3FJP nemá nastavené rozhraní rádia, takže se sleduje to, co je zadáno v N3FJP, ne rádio',
			'settings.station.winkeyerKeyPort' => 'Výstup klíčování',
			'settings.station.winkeyerKeyPortDescription' => 'Do kterého ze dvou výstupních konektorů klíčovače je zapojeno vaše rádio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Použít PTT klíčovače',
			'settings.station.winkeyerPttDescription' => 'Klíčovat linku PTT na stejném konektoru, pro zesilovač nebo rádio, které to potřebuje. Pro rádio klíčované přes konektor klíče nechte vypnuté.',
			'settings.station.winkeyerNoAnswer' => 'Na tomto portu neodpověděl žádný WinKeyer',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer během vysílání přestal odpovídat; zpráva byla zahozena',
			'settings.station.icomControlPort' => 'Řídicí port (UDP)',
			'settings.station.icomControlPortDescription' => 'Control Port (UDP) rádia — 50001, pokud nebyl změněn v jeho síťovém nastavení nebo přesměrován na jiný.',
			'settings.station.icomSerialPort' => 'Sériový port (UDP)',
			'settings.station.icomSerialPortDescription' => 'Serial Port (UDP) rádia — 50002, pokud nebyl změněn v jeho síťovém nastavení nebo přesměrován na jiný.',
			'settings.station.icomPortsDiffer' => 'Řídicí a sériový port se musí lišit',
			'settings.station.radioUser' => 'Uživatelské jméno rádia',
			'settings.station.radioPass' => 'Heslo rádia',
			'settings.station.radioLoginDescription' => 'Přihlášení rádia v Network → Remote, ne vaše heslo k WiFi.',
			'settings.station.radioUserRequired' => 'Uživatelské jméno pro vzdálené ovládání rádia je povinné',
			'settings.station.connectFailedBusy' => 'Zařízení se používá',
			'settings.station.connectFailedDenied' => 'Přístup odepřen',
			'settings.station.connectFailedDevice' => 'Zařízení nenalezeno',
			'settings.station.connectFailedUnsupported' => 'Čip tohoto adaptéru USB nerozpoznal žádný ovladač. Pokud víte, o který čip jde, vyberte ho v sekci „Pokročilé nastavení“ pod Ovladač čipu USB.',
			'settings.station.connectFailedLines' => 'RTS/DTR nebylo možné udržet podle nastavení, proto byl port zavřen. Jiný program mohl nechat zapnuté hardwarové řízení toku — odpojte a znovu připojte kabel.',
			'settings.station.connectFailedNetwork' => 'Rádio nelze v síti najít. Zkontrolujte jeho adresu a že je zapnuté a dostupné.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'Port ${port} na tomto zařízení se už používá, a právě na něj přicházejí odpovědi. Zavřete cokoli jiného, co na něm naslouchá — včetně dalšího uzlu PstRotator — nebo port změňte.',
			'settings.station.connectFailedTimeout' => 'Rádio neodpovědělo včas. Zkontrolujte, že je zapnuté a dostupné.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - obecné',
			'settings.station.models.icomGeneric' => 'Icom - obecné',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - obecné',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - obecné',
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
			'settings.station.models.rigctld' => 'Rádio ovládané přes rigctld',
			'settings.station.models.rigctldNodeName' => 'Moje rádio (přes rigctld)',
			'settings.station.models.flrig' => 'Rádio ovládané přes flrig',
			'settings.station.models.flrigNodeName' => 'Moje rádio (přes flrig)',
			'settings.station.models.hrd' => 'Rádio ovládané přes Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Moje rádio (přes HRD)',
			'settings.station.models.n3fjp' => 'Rádio ovládané přes N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Moje rádio (přes N3FJP)',
			'settings.station.models.commander' => 'Rádio ovládané přes DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Moje rádio (přes Commander)',
			'settings.station.models.antenna' => 'Anténa',
			'settings.station.models.key' => 'CW klíč',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Obecné rádio (zástupné)',
			'settings.station.models.placeholderRadioNodeName' => 'Moje rádio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.models.gs232a' => 'Rozhraní rotátoru Yaesu GS-232A',
			'settings.station.models.pstRotator' => 'PstRotator (ovládání UDP)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'Síť/WiFi',
			'settings.station.transports.secureNetwork' => 'Zabezpečená síť/WiFi',
			'settings.station.transports.usbSerial' => 'USB sériový',
			'settings.station.transports.wifi' => 'Síť/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth sériový',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'Zástupné',
			'settings.station.troubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.ft891Troubleshooting' => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **CAT RTS vypnuté na rádiu, nebo zapnuté Držet RTS v úrovni high.** Se zapnutým **CAT RTS** (menu FT-891 **05-08**) rádio mlčí, dokud je RTS v úrovni low — může jednou odpovědět při otevření portu, pak už nic. Výběr vlastního USB portu rádia zapne **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high klíčuje váš vysílač: místo toho vypněte CAT RTS na rádiu.\n- **Rychlost musí odpovídat** CAT RATE rádia (menu **05-06**). Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.yaesuBinaryTroubleshooting' => 'Toto rádio používá starší pětibajtový CAT od Yaesu a když něco nesedí, vůbec neodpovídá. Téměř vždy jde o jedno z:\n\n- **Kabel musí převádět úrovně.** Konektor CAT vzadu není RS-232 ani USB; potřebuje CT-62 nebo ekvivalentní adaptér. Obyčejný audio nebo datový kabel pro CAT fungovat nebude.\n- **Rychlost musí odpovídat** menu CAT RATE rádia (**#14** na FT-817, **#19** na FT-857 nebo FT-897). Při neshodě rádio nic nevrací, a nikdy chybu.\n- **Nikdy nedovolte nic, co by na tomto portu zvedlo RTS nebo DTR.** U většiny kabelů pro tato rádia jsou tyto linky PTT a klíčování. Výjimkou je starší rozhraní napájené z DTR: pro ně zapněte **Držet DTR v úrovni high** v sekci „Pokročilé nastavení“.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTento ovladač byl napsán podle publikované tabulky CAT od Yaesu a s žádným z těchto rádií zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.tenTecTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.tenTecEagleTroubleshooting' => '- **Port USB-B vzadu je linka CAT.** Rádio se hlásí jako sériový port USB; ve Windows potřebuje ovladač USB to UART od Ten-Tec, který se ve Správci zařízení objeví jako „USB to UART (COMx)“.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený, a stejně tak aktualizátor firmwaru od Ten-Tec.\n- **Nastavení šířky filtru z aplikace ho odebere knoflíku BW**, dokud rádio nevypnete a znovu nezapnete. Tak to rádio funguje.\n\nTento ovladač byl napsán podle programátorské referenční příručky Ten-Tec. Pokud funguje jen napůl, stojí za to to nahlásit, i s verzí firmwaru z menu rádia.',
			'settings.station.tenTecOrionTroubleshooting' => '- **Použijte přímý sériový kabel DB-9** do portu SERIAL DATA, ne křížený (null-modem).\n- **Tato položka drží RTS v úrovni high**, protože Orion používá RTS a CTS jako handshake. U rozhraní, které klíčuje PTT z RTS, například Digirig, vypněte Držet RTS v úrovni high v sekci „Pokročilé nastavení“, jinak rádio začne vysílat, jakmile se aplikace připojí.\n- **CW z aplikace vyžaduje zapnutý interní klíčovač rádia.** Když je vypnutý, rádio ignoruje, co aplikace posílá.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTento ovladač byl napsán podle programátorské referenční příručky Ten-Tec a s Orionem zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit, i s verzí firmwaru z menu rádia.',
			'settings.station.tenTecNoCw' => 'Firmware tohoto rádia nepřijímá CW z aplikace. Ten-Tec ho přidal ve firmwaru Orionu 1.366.',
			'settings.station.tenTecKeyerOff' => 'Interní klíčovač rádia je vypnutý, rádio proto ignoruje CW posílané z aplikace. Zapněte klíčovač v menu rádia.',
			'settings.station.guohetecTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.guohetecTroubleshooting' => 'Q900 má dva protokoly CAT a tato položka používá jeho nativní protokol místo napodobeniny FT-817. Vyberte zde **Guohetec Q900**, ne FT-817 — napodobenina podporuje méně příkazů a rádio neříká, který z nich používá.\n\n- **Kabel USB-C je linka CAT** a připojuje i zvukovou kartu. Rychlost na něm nehraje roli; port ignoruje, na co je nastaven.\n- **Nikdy nedovolte nic, co by na tomto portu zvedlo RTS nebo DTR.** U sériového kabelu jsou tyto linky PTT a klíčování.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Rádio druhé generace se chová jinak** než první. Dlouze stiskněte Menu, pak About: HW 2.0 je druhá generace.\n\nTento ovladač byl napsán podle protokolu publikovaného výrobcem a s žádným z těchto rádií zatím nebyl vyzkoušen. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.yaesuTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.yaesuTroubleshooting' => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **CAT RTS musí být na rádiu VYPNUTO.** Když je zapnuté, rádio čeká na linku handshake, kterou aplikace drží v úrovni low. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je tatáž linka PTT, takže její zvednutí by klíčovalo váš vysílač. Na vlastním USB portu rádia je alternativou **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. Kde se toto nastavení nachází, se liší podle modelu (menu **05-08** na FT-891).\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Módy se řídí tabulkou FT-891.** Většina řady Yaesu jí odpovídá, ale rádio, které čísluje módy jinak, u nich zobrazí a nastaví nesprávný mód. Frekvence tím není ovlivněna.',
			'settings.station.ftdx3000Troubleshooting' => '**Menu 037 CAT SELECT musí být USB** pro CAT přes USB port rádia; při nastavení RS232C je CAT na konektoru vzadu.\n\nTato položka byla napsána podle publikované dokumentace CAT a s FTDX3000 zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.yaesuRs232Troubleshooting' => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **Konektor CAT je RS-232.** Potřebuje převodník USB na sériový port a přímý kabel DB-9 — křížený (null-modem) kabel prohodí linky a rádio nic neuslyší.\n- **CAT RTS musí být na rádiu VYPNUTO.** Když je zapnuté, rádio čeká na linku handshake, kterou aplikace drží v úrovni low, pokud není v sekci „Pokročilé nastavení“ zapnuto **Držet RTS v úrovni high**.\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\nTato položka byla napsána podle publikované dokumentace CAT a s žádným z těchto rádií zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.yaesuUsbTroubleshooting' => 'Rádio přijímá příkazy, ale neodpovídá. Téměř vždy jde o jedno z:\n\n- **Použijte první ze dvou USB portů rádia.** CAT je obvykle na prvním (ve Windows port COM **Enhanced**); druhý (**Standard**) slouží pro PTT a klíčování. Výběr ukazuje na první, kdekoli je dokáže rozlišit.\n- **CAT RTS vypnuté na rádiu, nebo zapnuté Držet RTS v úrovni high.** Se zapnutým menu **CAT RTS** rádio mlčí, dokud je RTS v úrovni low — může jednou odpovědět při otevření portu, pak už nic. Výběr vlastního USB portu rádia zapne **Držet RTS v úrovni high** v sekci „Pokročilé nastavení“. U Digirig, SignaLink nebo většiny podomácku vyrobených kabelů je RTS signál PTT a jeho držení v úrovni high klíčuje váš vysílač: místo toho vypněte CAT RTS na rádiu.\n- **Rychlost musí odpovídat** menu CAT RATE rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.',
			'settings.station.k4SerialNotes' => 'Připojte zadní konektor USB-B (PC) na K4. Pro CAT funguje USB-PC1 i USB-PC2; zvolte nepoužívaný port a nastavte na rádiu odpovídající Serial USB-PCn: Baud Rate. HaLo předvyplní 38400; v případě potřeby to změňte. Jiná aplikace musí použít druhý port nebo Ethernet.\n\nToto připojení ovládá rádio a jeho klíčovače; do HaLo neposílá zvuk.',
			'settings.station.k4TcpNotes' => 'Připojte ethernetový konektor K4 do místní sítě. Zadejte jeho název hostitele nebo IP adresu a CAT port 9200. Když je zobrazen panadaptér nebo vodopád, HaLo používá stejného hostitele na pevném portu 9201; změna CAT portu port spektra nemění.\n\nSpektrum ukazuje hlavní přijímač. Jeho ovládání zoomu, referenční úrovně a rychlosti ovlivňuje jen zobrazení v HaLo. Streamování zvuku není podporováno.',
			'settings.station.k4PowerTimeout' => 'Výkon K4 nebyl změněn, protože rádio nepotvrdilo svůj výstupní rozsah. Zkuste to znovu.',
			'settings.station.k4RemoteNotes' => 'Zapněte na K4 vzdálený přístup a zadejte jeho síťové heslo. Main a Sub sdílejí jedno šifrované připojení pro ovládání rádia i spektrum. Výchozí port je 9204; při vzdáleném připojení zadejte svůj přesměrovaný port.\n\nPřehrávání zvuku a streamování mikrofonu nejsou podporovány.',
			'settings.station.k4Receiver' => 'Přijímač',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'Vyberte Main nebo Sub',
			'settings.station.k4ReceiverAlreadyConfigured' => 'Tento přijímač je u tohoto K4 už nakonfigurován',
			'settings.station.k4SubReceiverOff' => 'Sub přijímač K4 je vypnutý',
			'settings.station.k4RemotePasswordRequired' => 'Pro zabezpečené připojení zadejte síťové heslo K4.',
			'settings.station.k4RemoteHandshakeFailed' => 'Rádio K4 nedokázalo navázat zabezpečené připojení. Zkontrolujte jeho síťové heslo a nastavení vzdáleného přístupu.',
			'settings.station.k4RemoteUnreachable' => 'Zabezpečené připojení K4 je nedostupné. Zkontrolujte adresu, port a nastavení vzdáleného přístupu.',
			'settings.station.k4PowerRange' => 'Výkon K4 musí být 0,1–110 W, nebo 0,0001–0,01 W, když je aktivní miliwattový výstup transvertoru.',
			'settings.station.elecraftTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.elecraftTroubleshooting' => 'Rádia Elecraft používají Kenwood CAT a KX2 i KX3 byly takto vyzkoušeny — VFO oběma směry, přepínání módů i CW zero-beat fungují.\n\nPokud rádio neodpovídá, téměř vždy jde o jedno z:\n\n- **Rychlost musí odpovídat** rychlosti nastavené v **RS232** v menu rádia. Z výroby je nastaveno 38400. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n\n**Pokud je frekvence správně, ale mód špatně**, dejte nám vědět. Položky KX2 a KX3 čtou mód z pozice ve stavové odpovědi rádia, kterou jsme určili podle rádií, která jsme viděli, a firmware, který ho dává jinam, odhalí jen hlášení od vás.\n\nK3 zatím nikdo nenahlásil, takže pokud ho používáte, napište, co se stane. K4 má vlastní položku.',
			'settings.station.lab599TroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.lab599Troubleshooting' => 'Řada TX-500 používá Kenwood CAT. Frekvence a mód byly vyzkoušeny přes LiNK500MP; výkon a měřiče jsou napsány podle referenční příručky CAT od Lab599, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\n- **Rychlost musí odpovídat** nastavení CAT rádia, 9600, pokud jste ho nezměnili. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Vyberte na rádiu protokol CAT.** TS-2000 pokrývá frekvenci, mód a výkon. LAB599 navíc aplikaci umožní přepnout rádio do DIG, vidět jeho vysílání v DIG a číst napájecí napětí.\n- **Přes LiNK500MP** podržte knoflík VFO asi tři sekundy, tím předáte ovládání CAT rozhraní.\n- **Nastavte na LiNK500MP režim podle připojení**: Mode 3 pro Bluetooth, Mode 4 pro Bluetooth LE. V jiném režimu ho vyhledávání Bluetooth LE nenajde.\n- **Přes Bluetooth** se LiNK500MP páruje jako dva sériové porty a CAT nese jen jeden. Pokud rádio mlčí, vyberte druhý.',
			'settings.station.lab599TroubleshootingIos' => 'Řada TX-500 používá Kenwood CAT. Frekvence a mód byly vyzkoušeny přes LiNK500MP; výkon a měřiče jsou napsány podle referenční příručky CAT od Lab599, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\n- **Nastavte LiNK500MP do Mode 4**, jeho režimu Bluetooth LE, než ho začnete vyhledávat. V jiném režimu ho iPhone ani iPad nenajde.\n- **Předejte ovládání CAT rozhraní LiNK500MP**: podržte knoflík VFO rádia asi tři sekundy.\n- **Vyberte na rádiu protokol CAT.** TS-2000 pokrývá frekvenci, mód a výkon. LAB599 navíc aplikaci umožní přepnout rádio do DIG, vidět jeho vysílání v DIG a číst napájecí napětí.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Pokud se rádio připojí, ale neukazuje frekvenci',
			'settings.station.kenwoodTroubleshooting' => 'Tento ovladač je ověřen s Kenwood TS-590SG a TS-480, QRP Labs QMX a QCX-mini a Elecraft KX2 a KX3. Zbytek řady je napsán podle publikovaných referencí CAT, proto prosím nahlaste, co se stane, ať to funguje, nebo ne.\n\nPokud rádio neodpovídá, téměř vždy jde o jedno z:\n\n- **Rychlost musí odpovídat** menu CAT rádia. Při neshodě rádio vrací nesmysly nebo nic, a nikdy chybu.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.\n- **Některá rádia potřebují zapnout CAT** v menu, než vůbec začnou odpovídat.\n- **Rádia Kenwood čekají na RTS**: jejich port CAT ho používá jako handshake, proto musí být zapnuto Držet RTS v úrovni high (v sekci „Pokročilé nastavení“). Připojení nastavené dříve, než bylo ve výchozím stavu zapnuté, ho může mít vypnuté. U Digirig nebo jiného kabelu, který klíčuje PTT z RTS, ho vypněte, jinak rádio vysílá.\n\n**Stejný protokol používá několik SDR front-endů**, takže tuto položku stojí za to vyzkoušet i pro ně; rádia Elecraft jsou uvedena zvlášť, pod Elecraft. Pokud je frekvence správně, ale mód je špatně nebo chybí, je to ta jediná část, která se v řadě liší — aplikace ho zjišťuje z rádia a v nouzi se ptá přímo, takže mód se může jen opožďovat.',
			'settings.station.statusConnected' => 'Připojeno',
			'settings.station.statusLost' => 'Odpojeno',
			'settings.station.notConfigured' => 'Nenakonfigurováno',
			'settings.station.currentConfiguration' => 'Aktuální konfigurace',
			'settings.station.currentTransceiver' => 'Aktuální transceiver',
			'settings.station.currentTransceivers' => 'Aktuální transceivery',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => 'Zprávy se řadí do fronty místo přerušování',
			'settings.station.noRadioBSelected' => 'Není vybráno rádio B',
			'settings.station.radioMode' => 'Mód rádia',
			'settings.station.keyerNotSupported' => 'Aktuální rádio nepodporuje',
			'settings.station.catControlPreferences' => 'Předvolby ovládání CAT',
			'settings.station.chooseTransceiver' => 'Vyberte transceiver',
			'settings.station.configurationSection' => 'Konfigurace',
			'settings.station.noTransceiverSelected' => 'Není vybrán žádný transceiver',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Použít ${name} pro hlavní VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, zero: 'Žádné transceivery', one: '${count} transceiver', other: '${count} transceiverů', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} anténa', other: '${count} antén', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} další zařízení', other: '${count} dalších zařízení', ), 
			'settings.station.equipmentInventory' => 'Přehled vybavení',
			'settings.station.equipmentInUse' => 'Ovládání transceiveru',
			'settings.station.noTransceiver' => 'Žádný',
			'settings.station.peerRadioNotAvailable' => 'Není k dispozici',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Na ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} je na jiném zařízení',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Toto rádio je připojeno k ${device}. Jeho připojení a nastavení se konfiguruje na tom zařízení.',
			'settings.station.antennaInUse' => 'Používaná anténa',
			'settings.station.keyInUse' => 'Klíčování CW',
			'settings.station.phoneKeying' => 'Hlasové klíčování',
			'settings.station.phoneKeyingNone' => 'Žádné',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => 'Paměti v ${radio}',
			'settings.station.phoneKeyingComputer' => 'Zvuk v tomto počítači',
			'settings.station.phoneKeyingOff' => 'Hlasové klíčování je vypnuté',
			'settings.station.computerVoiceSettings' => 'Zvuk počítače',
			'settings.station.cwKeyingOptions' => 'Možnosti klíčování CW',
			'settings.station.noneSelected' => 'Žádný',
			'settings.station.moreSettings' => 'Další nastavení',
			'settings.station.icomCivTroubleshootingTitle' => 'Pokud se pro stejné rádio objeví dva sériové porty',
			'settings.station.icomCivTroubleshooting' => 'Několik rádií Icom, mezi nimi IC-705, nabízí najednou **dva** sériové porty USB (Icom je nazývá Port A a Port B), oba výchozí nastavené na CI-V. Tato aplikace ani váš operační systém je kromě toho nedokážou rozlišit: stejné USB vendor/product ID se prostě objeví dvakrát, zde někdy označené příponou `#2`. **Správný je obvykle Port A** — normálně ten, který váš systém nebo prohlížeč uvádí jako první, a kde to aplikace dokáže rozlišit, označí ho jako doporučený. Pokud příkazy odcházejí a rádio nikdy neodpoví, zkuste druhý port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Pokud rádio nikdy neodpoví',
			'settings.station.civAddressTroubleshooting' => '- **CI-V adresa musí odpovídat** menu rádia. Tato položka předvyplní adresu, se kterou se model dodává, ale rádio sdílející sběrnici CI-V je přesně místo, kde se mění. Rámec odeslaný na špatnou adresu je tiše ignorován, což vypadá přesně jako vadný kabel.\n- **Rychlost musí odpovídat** CI-V BAUD RATE rádia (na USB CI-V USB Baud Rate). Nastavte rádio na stejné číslo, jaké je zde, **ne na Auto**. Na Auto se některá rádia, mezi nimi IC-7300, připojí a asi po minutě přestanou odpovídat.\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **CI-V adresa musí odpovídat** menu rádia. Tato položka předvyplní adresu, se kterou se model dodává, ale rádio sdílející sběrnici CI-V je přesně místo, kde se mění. Rámec odeslaný na špatnou adresu je tiše ignorován, což vypadá přesně jako vadný kabel.\n${speed}\n- **Port může držet jiná aplikace**: WSJT-X, fldigi i rigctld ho všechny drží otevřený.',
			'settings.station.icomUsbSpeedFollows' => '- **Žádná rychlost se nenastavuje.** Přes USB toto rádio komunikuje rychlostí, kterou používá počítač, a tato položka vždy používá 115200, rychlost, kterou potřebuje scope.',
			'settings.station.ic7610UsbSpeed' => '- **Nastavte CI-V USB Baud Rate na 115200**, rychlost, kterou tato položka vždy používá, protože ji potřebuje scope — **ne Auto**. Rádio nastavené na jinou rychlost odpoví mlčením.',
			'settings.station.civTransceiveTitle' => 'Pokud aplikace sleduje rádio se zpožděním',
			'settings.station.civTransceive' => 'Pokud aplikaci trvá několik sekund, než ukáže změnu frekvence nebo módu provedenou na rádiu, zapněte na rádiu nastavení **CI-V Transceive** (u většiny současných modelů v SET > Connectors > CI-V). Když je zapnuté, rádio hlásí každou změnu v okamžiku, kdy nastane. Když je vypnuté, aplikace změnu uvidí až při dalším dotazu, každých několik sekund.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** se dodává s adresou `B6`, ne `94` předvyplněnou zde — vyberte místo toho položku IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- **IC-705** nabízí dva sériové porty USB, oba pojmenované po rádiu. CI-V je na **prvním** z nich, na který výběr ukazuje, kdekoli je dokáže rozlišit.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** používá CI-V na **Port A** ze dvou sériových portů USB, které nabízí.',
			'settings.station.x6100PortNote' => '\n- **X6100** používá CI-V na portu **DEV** — druhém ze dvou sériových portů, které nabízí, a na ten výběr ukazuje.',
			'settings.station.rigctldTroubleshootingTitle' => 'Pokud se aplikace nemůže připojit',
			'settings.station.rigctldTroubleshooting' => 'Toto se připojuje k **démonu rigctld, který spouštíte sami**, ne přímo k rádiu — s rádiem komunikuje backend Hamlib, který podporuje stovky modelů.\n\n- **Démon už musí běžet**, např. `rigctld -m 1035 -r /dev/ttyUSB0`. Číslo modelu vašeho rádia zjistíte pomocí `rigctl -l`.\n- **Z jiného počítače** ho spusťte s `-T 0.0.0.0`: ve výchozím stavu rigctld přijímá připojení jen z počítače, na kterém běží.\n- **Port** je 4532, pokud jste démona nespustili s `-t`.\n- Když po připojení chybí frekvence, obvykle to znamená, že se k rádiu nemůže dostat samotný démon. Otestujte to pomocí `rigctl -m 2 f` na počítači s démonem.',
			'settings.station.flrigTroubleshootingTitle' => 'Pokud se aplikace nemůže připojit',
			'settings.station.flrigTroubleshooting' => 'Toto se připojuje k **programu flrig, který spouštíte sami**, ne přímo k rádiu — s rádiem komunikuje flrig, který podporuje většinu značek a modelů.\n\n- **flrig už musí běžet** s nakonfigurovaným a připojeným transceiverem.\n- **Port** je 12345, pokud jste ho nezměnili v konfiguraci flrig (Config → Setup → Server).\n- **Z jiného počítače** se ujistěte, že je server flrig dostupný. Naslouchá na všech rozhraních, ale váš firewall s tím nemusí souhlasit.\n- Když po připojení chybí frekvence, obvykle to znamená, že se k rádiu nemůže dostat samotný flrig. Zkontrolujte, že displej flrig sleduje ladění.',
			'settings.station.hrdTroubleshootingTitle' => 'Pokud se aplikace nemůže připojit',
			'settings.station.hrdTroubleshooting' => 'Toto se připojuje k **Rig Control z Ham Radio Deluxe, běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje HRD.\n\n- **Rig Control už musí běžet** a být připojený k rádiu.\n- **Jeho IP server musí být zapnutý.** Rig Control komunikuje s jinými programy jen přes něj.\n- **Port** je 7809, pokud jste ho nezměnili v nastavení IP serveru.\n- **Z jiného počítače** se ujistěte, že váš firewall spojení propustí.\n\nTato položka byla napsána podle publikovaných popisů protokolu HRD a s HRD zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Pokud se aplikace nemůže připojit',
			'settings.station.n3fjpTroubleshooting' => 'Toto se připojuje k **logovacímu programu N3FJP běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje N3FJP.\n\n- **API programu musí být zapnuté**: Settings → Application Program Interface, zaškrtněte **TCP API Enabled**.\n- **Port** je 1100, pokud jste ho tam nezměnili.\n- **N3FJP musí mít nastavené rozhraní rádia**, aby mohl rádio sledovat nebo ladit. Bez něj hlásí jen to, co je zadáno v jeho vstupním okně.\n- N3FJP hlásí pouze pásmo, mód a frekvenci: žádný výkon, žádný stav vysílání.\n\nTato položka byla napsána podle publikovaného API N3FJP a s N3FJP zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.commanderTroubleshootingTitle' => 'Pokud se aplikace nemůže připojit',
			'settings.station.commanderTroubleshooting' => 'Toto se připojuje k **DXLab Commander, běžícímu na vašem počítači**, ne přímo k rádiu — s rádiem komunikuje Commander.\n\n- **Commander už musí běžet** a být připojený k rádiu.\n- **Jeho síťová služba musí být zapnutá**: tlačítko **Net Serv** v panelu Radio v okně Configuration programu Commander.\n- **Port** je 52002, třetí port bloku začínajícího na **Base Port** v Net Serv (52000, pokud jste ho nezměnili).\n- **Z jiného počítače** se ujistěte, že váš firewall spojení propustí.\n\nTato položka byla napsána podle publikovaných TCP zpráv Commanderu a s Commanderem zatím nebyla vyzkoušena. Pokud funguje jen napůl, stojí za to to nahlásit.',
			'settings.station.ic705TroubleshootingTitle' => 'Pokud rádio nikdy neodpoví',
			'settings.station.ic705Troubleshooting' => 'Rádio má **jedinou** relaci vzdáleného ovládání. Když je přihlášení ignorováno, téměř vždy ji používá něco jiného.\n\n- **Zavřete všechny ostatní klienty.** wfview nebo RS-BA1 připojené ke stejnému rádiu drží tuto jedinou relaci a přihlášení zde je po tu dobu prostě ignorováno.\n- **Zkontrolujte síťové nastavení rádia.** WLAN musí být zapnutá, rádio musí být ve stejné síti a jeho funkce vzdáleného ovládání (Network) musí být povolená.\n- **Porty musí odpovídat** Control Port a Serial Port (UDP) rádia, nebo portům na ně přesměrovaným. Špatný port se setká s mlčením, stejně jako vypnuté rádio.\n- **Vypněte a zapněte WLAN rádia**, pokud zůstává zaseknuté. To spolehlivě uvolní relaci zaseknutou v rádiu.\n\n**Špatné heslo je výslovně odmítnuto**, ne přejito mlčením. Pokud jste se dostali sem, a ne ke zprávě „odmítnuto“, heslo problémem není.',
			'settings.station.icomLanTroubleshooting' => 'Rádio má **jedinou** relaci vzdáleného ovládání. Když je přihlášení ignorováno, téměř vždy ji používá něco jiného.\n\n- **Zavřete všechny ostatní klienty.** wfview, RS-BA1 nebo Remote Utility od Icomu připojené ke stejnému rádiu drží tuto jedinou relaci a přihlášení zde je po tu dobu prostě ignorováno.\n- **Zkontrolujte síťové nastavení rádia.** Jeho port LAN musí být připojen do stejné sítě jako toto zařízení, musí být zapnuté **Network Control** a uživatelské jméno a heslo musí být na rádiu nastaveny jako síťový uživatel.\n- **Porty musí odpovídat** Control Port a Serial Port (UDP) rádia, nebo portům na ně přesměrovaným. Špatný port se setká s mlčením, stejně jako vypnuté rádio.\n- **Pokud se připojí, ale nikdy neodpoví**, CI-V adresa zde musí odpovídat menu CI-V ADDRESS rádia. Tato položka předvyplní adresu, se kterou se model dodává.\n- **Rádio vypněte a zapněte**, pokud zůstává zaseknuté.',
			'settings.station.statusStale' => 'Neodpovídá',
			'settings.station.statusDisconnected' => 'Nepřipojeno',
			'settings.station.statusConnecting' => 'Připojování…',
			'settings.station.statusDisconnecting' => 'Odpojování…',
			'settings.station.statusError' => 'Připojení selhalo',
			'settings.station.currentRadioSettings' => 'Aktuální nastavení rádia',
			'settings.station.notSupportedByThisRadio' => 'Toto rádio nepodporuje',
			'settings.station.cwMessagesButton' => 'Zprávy CW',
			'settings.station.voiceMessagesButton' => 'Hlasové zprávy',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Hlasový klíčovač: ${count} pamětí v rádiu',
			'settings.station.antennaBands' => 'Pásma',
			'settings.station.antennaType' => 'Typ antény',
			'settings.station.antennaTypeRequired' => 'Vyberte typ antény',
			'settings.station.antennaTypes.dipole' => 'Dipól',
			'settings.station.antennaTypes.vertical' => 'Vertikál',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / směrovka',
			'settings.station.antennaTypes.loop' => 'Smyčka',
			'settings.station.antennaTypes.longWire' => 'Long Wire / EFHW',
			'settings.station.antennaTypes.other' => 'Jiná',
			'settings.station.keyType' => 'Typ klíče',
			'settings.station.keyTypeRequired' => 'Vyberte typ klíče',
			'settings.station.keyTypes.straight' => 'Ruční klíč',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mechanický poloautomat)',
			'settings.station.keyTypes.fullyAutomatic' => 'Plně automatický klíčovač',
			'settings.station.keyTypes.singlePaddle' => 'Jednopádlový',
			'settings.station.keyTypes.dualPaddle' => 'Dvoupádlový',
			'settings.station.keyTypes.computerDriven' => 'Řízený počítačem',
			'settings.station.keyTypes.other' => 'Jiný',
			'settings.station.softwareIntermediaries' => 'Softwaroví prostředníci',
			'settings.station.otherBrands' => 'Jiné značky',
			'settings.station.otherEquipment' => 'Další vybavení (antény, klíče atd.)',
			'settings.station.newAntenna' => 'Nová anténa',
			'settings.station.newKey' => 'Nový klíč',
			'settings.station.newKeyer' => 'WinKeyer (K1EL nebo kompatibilní)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'CAT klíčovač v ${radio}',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyOnDevice' => ({required Object device}) => 'Klíč na ${device}',
			'settings.station.trackStationInfo' => 'Zaznamenávat informace o stanici u každého QSO',
			'settings.station.includeStationInfoInAdif' => 'Zahrnout do exportů ADIF',
			'settings.station.whatToTrack' => 'Co zaznamenávat?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Výkon',
			'settings.station.watts' => 'Watty',
			'settings.station.trackFieldAntenna' => 'Anténa',
			'settings.station.trackFieldKey' => 'CW klíč',
			'settings.station.placeholderConnectDelay' => 'Zpoždění připojení (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Jak dlouho trvá simulovaný handshake. Prázdné nebo 0 připojí okamžitě.',
			'settings.station.placeholderDropAfter' => 'Odpojit po (sekundách)',
			'settings.station.placeholderDropAfterDescription' => 'Samo ukončí spojení, aby se otestovalo opětovné připojení. Prázdné nebo 0 nikdy neodpojí.',
			'settings.station.placeholderFailConnect' => 'Vždy selhat při připojení',
			'settings.station.placeholderConnectFailure' => 'Zástupné rádio má nastaveno toto připojení odmítnout',
			'settings.station.placeholderFreq' => 'Frekvence (kHz)',
			'settings.station.placeholderFreqDescription' => 'Kde zástupné rádio začíná. Poté hlásí cokoli, na co ho aplikace naladí.',
			'settings.station.placeholderMode' => 'Mód',
			'settings.station.placeholderModeDescription' => 'Mód, ve kterém zástupné rádio začíná, např. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Výkon (watty)',
			'settings.station.placeholderPurpose' => 'Toto rádio použijte k evidenci, který transceiver používáte, pro účely logování',
			'settings.station.placeholderReplyDelay' => 'Zpoždění odpovědi (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Jak dlouho zástupnému rádiu trvá nahlásit změnu. Prázdné nebo 0 odpoví ihned.',
			'settings.station.cwKeyerField' => 'CAT CW klíčovač',
			'settings.station.cwKeyerFieldDescription' => 'Zda toto rádio klíčuje CW z textu přes CAT. Vypnuto pro rádio, které aplikace nezná.',
			'settings.station.voiceMemories' => 'Hlasové paměti',
			'settings.station.voiceMemoriesDescription' => 'Kolik hlasových pamětí rádio přehrává přes CAT. 0 pro žádné.',
			'settings.station.voiceMemoriesInvalid' => 'Celé číslo, 0 nebo více',
			'settings.station.yaesuMeterCapture' => 'Zachytávat hodnoty měřidel',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Při vysílání čte měřidlo výstupního výkonu rádia a příznak vysokého PSV a zapisuje surové hodnoty do logu. Slouží k sestavení stupnice, kterou Yaesu nepublikuje — hodnoty se nezobrazují jako měřidla.',
			'settings.station.yaesuMeterCaptureDescription' => 'Při vysílání čte měřidla PO, SWR a ALC rádia a zapisuje surové hodnoty do logu. Slouží k sestavení stupnice, kterou Yaesu nepublikuje — hodnoty se nezobrazují jako měřidla.',
			'settings.station.telemetryInterval' => 'Interval čtení měřidel (ms)',
			'settings.station.telemetryIntervalDescription' => 'Jak často číst měřidla rádia během vysílání. Ponechte prázdné pro nejrychlejší, co toto připojení zvládne, až 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Celé číslo milisekund, ${min} až ${max}',
			'settings.station.pollInterval' => 'Interval dotazování v klidu (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Jak často se ptát rádia na frekvenci a mód, když se ani jedno nemění. Ponechte prázdné pro ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Celé číslo milisekund, ${min} až ${max}',
			'settings.station.advancedSettings' => 'Pokročilé nastavení',
			'settings.station.placeholderSwr' => 'Hodnota PSV',
			'settings.station.placeholderSwrDescription' => 'Co toto rádio hlásí na měřidle PSV během vysílání. Nad 1,8 panel varuje.',
			'settings.station.placeholderSwrInvalid' => 'Číslo, 1 nebo více',
			'settings.station.keyerNone' => 'Žádný',
			'settings.station.cwDialect' => 'Dialekt klíčování CW',
			'settings.station.cwDialectDescription' => 'Jakou podobu příkazu KY toto rádio přijímá. Žádný znamená bez klíčování CW přes CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, doplněno na 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY text)',
			'settings.station.voiceDialect' => 'Dialekt hlasového klíčovače',
			'settings.station.voiceDialectDescription' => 'Jak toto rádio přehrává své hlasové paměti přes CAT. Žádný znamená bez hlasových pamětí přes CAT. S dialektem a bez počtu platí výchozí počet dialektu.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, styl TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB a DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (stisky tlačítek)',
			'settings.station.placeholderDiagnostic' => 'Simulováno',
			'settings.station.placeholderWholeNumberInvalid' => 'Musí být celé číslo, 0 nebo více',
			'settings.station.placeholderFreqInvalid' => 'Musí být frekvence v kHz, větší než nula',
			'settings.station.placeholderModeInvalid' => 'Musí být název módu, např. USB, CW, FT8',
			'settings.station.switchLayout' => 'Rozložení',
			'settings.station.switchLayoutDescription' => 'Na kterou stranu přepínače jsou zapojena vaše rádia.',
			'settings.station.switchLayoutRequired' => 'Vyberte, jak je přepínač zapojen',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Přepínač odmítl „${command}“ (chyba ${code})',
			'settings.station.switchBusyTransmitting' => 'Tento port vysílá — anténa nebyla změněna',
			'settings.station.switchNoAntenna' => 'Žádná',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Anténa na portu ${port}',
			'settings.station.switchAntennaForDescription' => 'Která z vašich antén je připojena k tomuto portu přepínače.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => 'Antény: ${antennas}, rádia: ${radios}',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => 'Antény: ${antennas}, 1 rádio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 anténa, rádia: ${radios}',
			'settings.station.switchCommonPort' => 'Společný',
			'settings.station.dcnAddress' => 'Adresa zařízení',
			'settings.station.dcnAddressDescription' => 'Adresa nastavená na DIP přepínačích modulu. Modul koaxiálního relé má z výroby 2.',
			'settings.station.dcnAddressRequired' => 'Musí být adresa zařízení od 1 do 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'řídí se daty o pásmu',
			'settings.station.switchPortTransmittingHint' => 'vysílá — nyní nelze změnit',
			'settings.station.switchCurrentStateHeader' => 'Aktuální stav',
			'settings.station.switchCurrentStateDescription' => 'Na které anténě je právě každý port rádia. Změny se projeví okamžitě.',
			'settings.station.switchWiringHeader' => 'Zapojení',
			'settings.station.switchPortInhibitedHint' => 'vysílání zablokováno',
			'settings.station.rotatorAxes' => 'Osy',
			'settings.station.rotatorAxesDescription' => 'Zda se rotátor otáčí jen v azimutu, nebo i v elevaci (G-5500 a podobné).',
			'settings.station.rotatorAxesAzimuth' => 'Jen azimut',
			'settings.station.rotatorAxesAzimuthElevation' => 'Azimut a elevace',
			'settings.station.rotatorAzimuthOffset' => 'Posun azimutu',
			'settings.station.rotatorAzimuthOffsetDescription' => 'Stupně, které se přičtou k údaji ovladače, když jeho nula není skutečný sever. Otáčení se odpovídajícím způsobem opraví.',
			'settings.station.rotatorElevationOffset' => 'Posun elevace',
			'settings.station.rotatorAzimuthMin' => 'Nejnižší azimut',
			'settings.station.rotatorAzimuthMax' => 'Nejvyšší azimut',
			'settings.station.rotatorAzimuthMaxDescription' => 'Ve vlastních stupních ovladače. Nad 360 pro rotátor s přesahem, který pak volí kratší otočení.',
			'settings.station.rotatorElevationMin' => 'Nejnižší elevace',
			'settings.station.rotatorElevationMax' => 'Nejvyšší elevace',
			'settings.station.rotatorElevationMaxDescription' => 'Ve vlastních stupních ovladače. Nad 90 pro rotátor, který se překlápí.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => 'Celé stupně, ${min} až ${max}',
			'settings.station.rotatorLimitsInvalid' => 'Dolní mez musí být nižší než horní',
			'settings.station.rotatorPollInterval' => 'Interval dotazování (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'Jak často se ptát rotátoru, kam míří. Ponechte prázdné pro ${fallback} ms.',
			'settings.station.rotatorAxesRequired' => 'Vyberte, ve kterých osách se rotátor otáčí',
			'settings.station.rotatorRefused' => 'Ovladač odmítl příkaz. Zkontrolujte, že je nastaven do režimu GS-232.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator odpovídá, až když je na to nastavený, jinak neříká vůbec nic:\n\n- **Zapněte UDP Control** v menu Setup programu PstRotator.\n- **Sjednoťte port**: Communication → UDP Control Port, 12000, pokud nebyl změněn. PstRotator odpovídá na následujícím portu (12001), který musí být na tomto zařízení volný.\n- **Připojte PstRotator k jeho ovladači.** Dokud není připojený, přes UDP neodpovídá nic.\n- **Povolte ho ve firewallu** na PC s PstRotatorem i na tomto zařízení, které naslouchá odpovědím.\n- **Na Macu, iPhonu nebo iPadu** potřebuje Ham2K Logger přístup k místní síti (Nastavení → Soukromí a zabezpečení → Místní síť).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => 'Aktuální stav: ${position}',
			'settings.station.rotatorDisconnected' => 'odpojeno',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '${degrees}° azimut',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '${degrees}° az',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '${degrees}° elevace',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '${degrees}° el',
			'settings.station.rotatorNoReading' => 'Čeká se, až ovladač nahlásí svou polohu…',
			'settings.station.rotatorNotResponding' => 'neodpovídá',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => 'Otáčí se na ${heading}, kam až meze tohoto rotátoru dovolí',
			'settings.station.rotatorTargetAzimuth' => 'Otočit na azimut',
			'settings.station.rotatorTargetAzimuthShort' => 'Otočit na az',
			'settings.station.rotatorTargetElevation' => 'Otočit na elevaci',
			'settings.station.rotatorTargetElevationShort' => 'Otočit na el',
			'settings.station.rotatorAzimuthInvalid' => 'Musí být 0 až 360',
			'settings.station.rotatorElevationInvalid' => 'Musí být 0 až 180',
			'settings.station.rotatorTurn' => 'Otočit',
			'settings.station.rotatorStop' => 'Stop',
			'settings.station.configUnreadable' => 'Uložené nastavení tohoto rádia nelze přečíst. Otevřete jeho nastavení a zadejte je znovu, nebo ho odeberte a přidejte zpět.',
			'settings.station.autoConnectHeld' => 'HaLo přestal odpovídat, když se k tomuto rádiu naposledy připojoval, proto se tentokrát nepřipojil sám. Stiskněte Připojit a zkuste to znovu.',
			'settings.offlineData.title' => 'Offline data',
			'settings.offlineData.noFiles' => 'Žádné datové soubory',
			'settings.offlineData.noFilesDescription' => 'Zapněte rozšíření aktivit nebo vyhledávání, abyste sem mohli stáhnout jejich offline data.',
			'settings.offlineData.refresh' => 'Obnovit',
			'settings.offlineData.refreshing' => 'Obnovování…',
			'settings.offlineData.updateAll' => 'Aktualizovat vše',
			'settings.offlineData.updatingAll' => 'Aktualizace všech datových souborů…',
			'settings.offlineData.neverDownloaded' => 'Nikdy nestaženo',
			'settings.offlineData.updatedJustNow' => 'Aktualizováno právě teď',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Aktualizováno před ${days} d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Aktualizováno před ${days} d ${hours} h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Aktualizováno před ${hours} h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Aktualizováno před ${hours} h ${minutes} min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Aktualizováno před ${minutes} min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Poslední stažení obsahovalo jen ${imported} z ${existing} záznamů a nebylo použito. Obnovením ho přijmete.',
			'settings.offlineData.extensionsSection' => 'Rozšíření',
			'settings.profiles.notSet' => 'Nenastaveno',
			'settings.profiles.personalInfo' => 'Osobní údaje',
			'settings.profiles.personalInfoNote' => 'Mohou být zahrnuty do vygenerovaných logů, pokud je to pro odeslání relevantní',
			'settings.profiles.name' => 'Jméno',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Klub',
			'settings.profiles.arrlSection' => 'Sekce ARRL',
			'settings.profiles.racSection' => 'Sekce RAC',
			'settings.profiles.section' => 'Sekce',
			'settings.search.clear' => 'Vymazat',
			'settings.search.hint' => 'Hledat v předvolbách',
			'settings.developer.developerModeDescription' => 'Zapnout varování pro vývojáře, ladicí logy a nástroje.',
			'settings.developer.experiments' => 'Experimenty',
			'settings.developer.showIdleMetrics' => 'Zobrazit metriky nečinnosti',
			'settings.developer.showIdleMetricsDescription' => 'Zobrazit ve stavovém řádku, jak byl engine rozšíření za poslední sekundu nečinný. Klepnutím zobrazíte průměry za 10 a 60 sekund.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '${percent}% nečinný',
			'settings.developer.idleMetricsAverages' => 'Prům. nečinnost:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}s ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} zapnutý', other: '${count} zapnutých', ), 
			'settings.developer.patchTrack' => 'Větev Code Push',
			'settings.developer.patchTrackDescription' => 'Který okruh aktualizací kódu přes internet toto zařízení sleduje. Odvážnější okruhy dostávají opravy dříve, ale méně otestované. Aktualizace kódu se použijí při příštím restartu.',
			'settings.developer.trackStable' => 'Stabilní',
			'settings.developer.trackUnstable' => 'Nestabilní',
			'settings.developer.trackBleeding' => 'Experimentální',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Kontrola aktualizace kódu ve větvi „${track}“…',
			'settings.developer.patchDownloaded' => 'Aktualizace kódu stažena — restartujte aplikaci, aby se použila.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Ve větvi „${track}“ není žádná nová aktualizace kódu.',
			'settings.developer.noPatchInstalled' => 'Není nainstalována žádná aktualizace kódu — běží binárka vydání.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Běží aktualizace kódu č. ${patch}.',
			'settings.developer.deepLinks' => 'Přímé odkazy',
			'settings.developer.registerUrlSchemes' => 'Registrovat URL schémata',
			'settings.developer.registerUrlSchemesDescription' => 'Nechat odkazy com.ham2k:// otevírat tuto kopii aplikace',
			'settings.developer.registerUrlSchemesDone' => 'Tato kopie nyní otevírá odkazy com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Registrace se nezdařila: ${error}',
			'settings.developer.systemInformation' => 'Informace o systému',
			'settings.developer.appVersion' => 'Verze aplikace',
			'settings.developer.dataFolder' => 'Složka dat',
			'settings.developer.loading' => '(načítání…)',
			'settings.developer.panelLoadFailed' => 'Tento panel nastavení nelze načíst.',
			'settings.developer.extDevServer' => 'Vývojový server rozšíření',
			'settings.developer.extensionSettings' => 'Nastavení rozšíření',
			'settings.developer.extDevServerDescription' => 'Načítat rozšíření z vývojového serveru ve vaší síti místo těch vestavěných v aplikaci a znovu je načíst při každém uložení.',
			'settings.developer.extDevServerAddress' => 'Adresa serveru',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Připojit',
			'settings.developer.extDevServerDisconnect' => 'Odpojit',
			'settings.developer.extDevServerConnecting' => 'Připojování…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Poskytuje ${count} rozšíření: ${keys}', other: 'Poskytuje ${count} rozšíření: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Nepřipojeno',
			'settings.developer.extDevServerReconnect' => 'Znovu připojit při spuštění',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Poslední načtení: ${key} v ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} rozšíření se nedaří sestavit', other: '${count} rozšíření se nedaří sestavit', ), 
			'settings.developer.catalog' => 'Katalog rozšíření',
			'settings.developer.catalogDescription' => 'Číst katalog z jiného serveru — místního při práci na samotném katalogu. Prázdné znamená catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Adresa katalogu',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Větve hledání v katalogu',
			'settings.developer.catalogSearchStable' => 'Pouze stabilní',
			'settings.developer.catalogSearchUnstable' => 'Nestabilní nebo lepší',
			'settings.developer.catalogSearchBleeding' => 'Experimentální nebo lepší',
			'settings.about.notices' => 'Oznámení a zprávy',
			'settings.about.noticesDescription' => 'Oznámení a stavové zprávy',
			'settings.about.releaseNotes' => 'Poznámky k vydání',
			'settings.about.copiedVersion' => 'Podrobnosti o verzi zkopírovány do schránky',
			'settings.panels.settings' => 'Předvolby aplikace',
			'settings.panels.settingsDescription' => 'Nastavte si aplikaci podle sebe',
			'settings.panels.commonSettings' => 'Běžné předvolby',
			'settings.panels.syncDescription' => 'Zálohujte a synchronizujte své logy mezi zařízeními',
			'settings.panels.accountsDescription' => 'Přihlašovací údaje ke službám, offline data a další',
			'settings.panels.extensions' => 'Rozšíření a funkce',
			'settings.panels.extensionsDescription' => 'Aktivity, závody, panely přehledu a další funkce',
			'settings.panels.profilesDescription' => 'Volací značka operátora a profil stanice',
			'settings.panels.stationProfiles' => 'Profily stanice',
			'settings.panels.developerSettings' => 'Nastavení pro vývojáře',
			'settings.panels.developerSettingsDescription' => 'Ladicí a vývojové nástroje',
			'settings.panels.about' => 'O aplikaci',
			'settings.panels.aboutDescription' => 'Verze, autoři a právní informace',
			'settings.panels.unavailableTitle' => 'Některá nastavení nejsou k dispozici',
			'settings.panels.unavailableText' => 'Běhové prostředí rozšíření se nespustilo, proto chybí nastavení poskytovaná rozšířeními.',
			'settings.panels.station' => 'Konfigurace stanice',
			'settings.panels.stationDescription' => 'Ovládání CAT a další možnosti',
			'settings.panels.peers' => 'Spárovaná zařízení',
			'settings.panels.peersDescription' => 'Připojte se k dalším zařízením v okolí',
			'settings.showMoreSettings' => 'Zobrazit další nastavení',
			'settings.gridPrecision' => 'Přesnost lokátoru',
			'settings.gridPrecisionOpts.six' => '6 znaků (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 znaků (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 znaků',
			'settings.gridPrecisionDescription.eight' => '8 znaků',
			'commands.enableSyncFirst' => 'Nejprve zapněte synchronizaci v Nastavení.',
			'commands.fullResyncStarted' => 'Spuštěna úplná resynchronizace — místní data byla nejprve zálohována.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Žádné datové soubory neodpovídají "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Opětovné načtení selhalo: ${error}',
			'commands.reloadingAll' => 'Opětovné načítání všech datových souborů…',
			'commands.reloadingTarget' => ({required Object target}) => 'Opětovné načítání datových souborů ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Neznámý experiment "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} zapnuto',
			'commands.experimentDisabled' => ({required Object name}) => '${name} vypnuto',
			'commands.sentryTestSent' => 'Testovací hlášení chyby odesláno do Sentry',
			'commands.idleMetricsEnabled' => 'Metriky nečinnosti zapnuty ve stavovém řádku',
			'commands.idleMetricsDisabled' => 'Metriky nečinnosti vypnuty',
			'commands.sentryTestLocalOnly' => 'Sentry je v tomto sestavení vypnuté — testovací chyba zaznamenána jen místně',
			'commands.noOperationOpen' => 'Tento příkaz potřebuje otevřenou aktivitu',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Nevím, jak označit \'${kind}\'',
			'commands.goUnavailable' => ({required Object place}) => 'Funkce ${place} není v této aplikaci zapnutá',
			'commands.goUnknown' => ({required Object to}) => 'Nevím, jak přejít na \'${to}\'',
			'commands.goBlocked' => 'Nejprve zavřete otevřený dialog',
			'commands.operationAlreadyStarted' => 'Tato aktivita už má značku začátku',
			'commands.couldNotOpenLocation' => 'Přestávka přidána, ale obrazovku polohy nelze otevřít',
			'commands.noTestOperations' => 'Žádné testovací aktivity k vyčištění',
			'commands.purgeTestsUnavailable' => 'PURGETESTS potřebuje zobrazit potvrzovací dialog, který zde není k dispozici',
			'commands.syncAllUnavailable' => 'SYNCALL potřebuje zobrazit potvrzovací dialog, který zde není k dispozici',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Vyčištěna ${count} testovací aktivita', other: 'Vyčištěno ${count} testovacích aktivit', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => 'Vyčištěno ${purged} z ${total} testovacích aktivit — zbytek selhal; zkuste PURGETESTS znovu',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Vyčištěno ${count} testovací spojení bez aktivity', other: 'Vyčištěno ${count} testovacích spojení bez aktivity', ), 
			'commands.purgeTestsContactsFailed' => 'Testovací aktivity vyčištěny, ale testovací spojení bez aktivity selhala; zkuste PURGETESTS znovu',
			'commands.purgeTestsNothingToDo' => 'Nic nebylo vyčištěno',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => 'Odebráno ${removed} z ${total} testovacích aktivit — zbytek selhal; zkuste Zkontrolovat znovu',
			'commands.receivedPurgesFailed' => 'Tyto testovací aktivity nelze odebrat — zkuste Zkontrolovat znovu',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} testovací aktivita byla odebrána na jiném zařízení', other: '${count} testovacích aktivit bylo odebráno na jiném zařízení', ), 
			'commands.receivedPurgesReview' => 'Zkontrolovat',
			'commands.settingOn' => 'Zapnuto',
			'commands.settingOff' => 'Vypnuto',
			'commands.settingEmpty' => '(prázdné)',
			'commands.settingSecretSet' => '(nastaveno)',
			'commands.settingSecretUnset' => '(nenastaveno)',
			'commands.settingSelectedCount' => ({required Object count}) => 'Vybráno: ${count}',
			'commands.settingExpectsOnOff' => 'zapnuto nebo vypnuto',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'jedno z: ${choices}',
			'commands.settingExpectsNumber' => 'číslo',
			'commands.settingVanished' => ({required Object label}) => '„${label}“ už není k dispozici',
			'commands.noCwKeyer' => 'Žádné připojené rádio neumí klíčovat CW',
			'commands.noKeyer' => 'Žádné připojené rádio neumí klíčovat CW ani přehrávat hlasové paměti',
			'commands.keyerNeedsOperation' => 'Pro použití CW klíčovače otevřete aktivitu',
			'commands.keyerExperimentOff' => 'Klíčování CW je vypnuté — zapněte ho pomocí EXP KEYER',
			'commands.esmExperimentOff' => 'Funkce Enter odesílá zprávy je vypnutá — zapněte ji pomocí EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Vysílání CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Zpráva CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'Zpráva CW F${n} nebyla odeslána: rozšíření nejsou připravena',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => 'Hlasová zpráva M${n}: ${error}',
			'commands.voiceMessageNotRendered' => 'rozšíření nejsou připravena',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => 'Nic neodesláno: rádio ${radio} to neumí klíčovat',
			'commands.so2rNoRadioB' => 'Nic neodesláno: pro klíčování z této sady vyberte rádio B v Konfiguraci stanice',
			'commands.settingNotStored' => ({required Object label}) => '„${label}“ tuto hodnotu nepřijalo',
			'commandDialog.hint' => 'Hledejte značky nebo zadejte příkaz',
			'commandDialog.noResults' => ({required Object text}) => 'Výrazu „${text}“ nic neodpovídá',
			'commandDialog.sectionCommands' => 'Příkazy',
			'commandDialog.sectionGoTo' => 'Přejít na',
			'commandDialog.sectionOperations' => 'Aktivity',
			'commandDialog.goHome' => 'Domů',
			'commandDialog.goSettings' => 'Nastavení',
			'commandDialog.goNewOperation' => 'Nová aktivita',
			'commandDialog.runTyped' => ({required Object text}) => 'Spustit „${text}“',
			'commandDialog.sectionSuggestions' => 'Zkuste',
			'commandDialog.lookingUp' => 'Vyhledávání značky…',
			'commandDialog.blockedByPane' => 'Příkazy nelze používat, když je otevřený panel nebo dialog',
			'keyboardShortcuts.title' => 'Klávesové zkratky',
			'keyboardShortcuts.description' => 'Přizpůsobte si přiřazení kláves',
			'keyboardShortcuts.search' => 'Hledat příkazy a klávesy',
			'keyboardShortcuts.import' => 'Importovat…',
			'keyboardShortcuts.export' => 'Exportovat…',
			'keyboardShortcuts.resetAll' => 'Obnovit vše na výchozí',
			'keyboardShortcuts.resetAllTitle' => 'Obnovit výchozí u všech zkratek?',
			'keyboardShortcuts.resetAllBody' => 'Každý příkaz se vrátí ke svým výchozím klávesám a klávesy přiřazené příkazům zadaným jako text se odeberou.',
			'keyboardShortcuts.reset' => 'Obnovit výchozí',
			'keyboardShortcuts.noKey' => 'Bez klávesy',
			'keyboardShortcuts.changed' => 'Změněno',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys} je přiřazeno také: ${commands}',
			'keyboardShortcuts.groupApp' => 'Aplikace',
			'keyboardShortcuts.groupKeying' => 'Klíčování',
			'keyboardShortcuts.groupLogging' => 'Logování',
			'keyboardShortcuts.groupCommands' => 'Příkazy',
			'keyboardShortcuts.groupFixed' => 'Pevné klávesy',
			'keyboardShortcuts.contextApp' => 'Kdekoli',
			'keyboardShortcuts.contextLogView' => 'Zobrazení Aktivita, Lovení a Logy',
			'keyboardShortcuts.contextOperation' => 'Zobrazení Aktivita, při klíčování rádia přes CAT',
			'keyboardShortcuts.contextLogging' => 'V panelu logování',
			'keyboardShortcuts.addCommand' => 'Přidat příkaz…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => 'Neznámý příkaz: ${command}',
			'keyboardShortcuts.command.commandDialog' => 'Otevřít dialog příkazů',
			'keyboardShortcuts.command.toggleTheme' => 'Přepnout mezi světlým a tmavým režimem',
			'keyboardShortcuts.command.toggleLanguage' => 'Přepnout mezi angličtinou a španělštinou',
			'keyboardShortcuts.command.fontScaleUp' => 'Větší písmo',
			'keyboardShortcuts.command.fontScaleDown' => 'Menší písmo',
			'keyboardShortcuts.command.fontScaleReset' => 'Normální velikost písma',
			'keyboardShortcuts.command.densityLooser' => 'Volnější rozložení',
			'keyboardShortcuts.command.densityDenser' => 'Hustší rozložení',
			'keyboardShortcuts.command.densityAuto' => 'Automatická hustota rozložení',
			'keyboardShortcuts.command.find' => 'Najít v logu',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'Odeslat zprávu ${n}',
			'keyboardShortcuts.command.keyboardMode' => 'Zapnout nebo vypnout režim klávesnice',
			'keyboardShortcuts.command.ptt' => 'PTT (push to talk)',
			'keyboardShortcuts.command.wipe' => 'Vymazat zadávané spojení',
			'keyboardShortcuts.fixed.callsign' => 'Psaní značek',
			'keyboardShortcuts.fixed.escape' => 'Zastavit vysílání, vrátit se o krok, nebo zavřít',
			'keyboardShortcuts.fixed.enter' => 'Zalogovat spojení',
			'keyboardShortcuts.fixed.space' => 'Další pole',
			'keyboardShortcuts.fixed.tab' => 'Další nebo předchozí pole',
			'keyboardShortcuts.fixed.arrows' => 'Pohyb mezi poli, ovládacími prvky a logem',
			'keyboardShortcuts.fixed.walk' => 'Listovat logem, nebo přejít na jeho začátek či konec',
			'keyboardShortcuts.fixed.undo' => 'Vrátit zpět vymazání nebo smazání',
			'keyboardShortcuts.editor.addShortcut' => 'Přidat zkratku',
			'keyboardShortcuts.editor.listening' => 'Stiskněte klávesy zkratky…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc ukončí zadávání',
			'keyboardShortcuts.editor.add' => 'Přidat',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys} patří polím logování nebo dialogu a nelze to změnit.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys} slouží k psaní značek. Přidejte k tomu Cmd, Ctrl nebo Alt.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => 'Systém může ${keys} zachytit dřív, než se dostane k aplikaci.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys} už je jednou z kláves tohoto příkazu.',
			'keyboardShortcuts.editor.takeIt' => ({required Object keys, required Object command}) => 'Vzít ${keys} příkazu „${command}“',
			'keyboardShortcuts.editor.resetDefault' => 'Obnovit výchozí',
			'keyboardShortcuts.editor.remove' => 'Odebrat',
			'keyboardShortcuts.editor.commandLabel' => 'Příkaz',
			'keyboardShortcuts.editor.commandHint' => 'Zadejte libovolný platný příkaz, nebo více příkazů oddělených ";"',
			'keyboardShortcuts.editor.removeCommand' => 'Odebrat příkaz',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => 'Žádný příkaz se nejmenuje „${text}“',
			'keyboardShortcuts.editor.noShortcuts' => 'Zatím bez klávesy',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'Zkratky uloženy do ${location}',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'Zkratky se nepodařilo exportovat: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'Soubor se nepodařilo otevřít: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename} není soubor zkratek, který tato aplikace umí přečíst: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'text není platný YAML (řádek ${line})',
			'keyboardShortcuts.file.problemNotKeysFile' => 'není to soubor klávesových zkratek Ham2K',
			'keyboardShortcuts.file.problemNewerVersion' => 'zapsala ho novější verze aplikace',
			'keyboardShortcuts.file.problemMalformed' => 'část z něj neodpovídá formátu zkratek',
			'keyboardShortcuts.file.problemTooLarge' => 'je příliš velký',
			'keyboardShortcuts.file.importTitle' => 'Importovat zkratky',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => 'Zapsáno na ${platform}.',
			'keyboardShortcuts.file.writtenOnUnknown' => 'Soubor neuvádí, na jaké klávesnici byl zapsán.',
			'keyboardShortcuts.file.translate' => 'Čemu má každá z těchto kláves odpovídat na této klávesnici?',
			'keyboardShortcuts.file.leaveOut' => 'Tyto zkratky vynechat',
			'keyboardShortcuts.file.replace' => 'Nahradit nastavení tohoto zařízení',
			'keyboardShortcuts.file.replaceHint' => 'Každá zkratka, která v souboru není, se vrátí na výchozí.',
			'keyboardShortcuts.file.merge' => 'Přidat k nastavení tohoto zařízení',
			'keyboardShortcuts.file.mergeHint' => 'Zkratky ze souboru nahradí zkratky tohoto zařízení u stejných příkazů, ostatní zůstanou.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'V této verzi neznámé, proto vynechány: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'Nejsou to zkratky, proto vynechány: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'Klávesy, které si aplikace vyhrazuje, proto vynechány: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'Po importu přiřazeny více než jednomu příkazu: ${keys}',
			'keyboardShortcuts.file.importAction' => 'Importovat',
			'keyboardShortcuts.file.imported' => 'Zkratky importovány',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'Platnost tohoto sestavení vypršela',
			'expiredBuild.body' => 'Navštivte prosím ham2k.com a stáhněte si novější verzi.',
			'expiredBuild.visit' => 'Navštívit ham2k.com',
			'expiredBuild.dismiss' => 'Přesto pokračovat',
			'staleness.codePushFloorTitle' => 'Čeká na vás důležitá aktualizace',
			'staleness.codePushFloorBody' => 'Tato verze obsahuje opravu, kterou ještě nemáte.',
			'staleness.restartToApply' => 'Restartujte aplikaci, aby se použila.',
			'staleness.quitAndReopen' => 'Ukončete aplikaci a znovu ji otevřete, aby se použila.',
			'staleness.reopenToApply' => 'Zavřete aplikaci a znovu ji otevřete, aby se použila.',
			'staleness.ignoreForNow' => 'Zatím ignorovat',
			'spotting.noQsoYet' => 'Zatím není zalogováno žádné QSO ke spotnutí.',
			'spotting.setFrequencyFirst' => 'Nejprve nastavte frekvenci.',
			'spotting.nothingToSpot' => 'Nic ke spotování — žádné rozšíření zde spotování nenabízí.',
			'spotting.incompleteCall' => 'Neúplnou značku nelze spotnout — nejprve ji dopište.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => 'Chyba ${source}: ${message}',
			'spotting.unknownError' => 'neznámá chyba',
			'spotting.notSent' => 'Spot nebyl odeslán.',
			'spotting.allSkipped' => 'Spot nebyl odeslán: všechny zdroje spotů ho přeskočily.',
			'spotting.notRefreshedOffline' => 'Bez připojení — spoty nebyly obnoveny',
			'dataFiles.downloading' => 'Stahování…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name} nelze stáhnout',
			'dataFiles.downloadFailedWebHint' => 'Může jít o problém se sítí, nebo hostitel tohoto odkazu nepodporuje přímé stahování z webového prohlížeče. Zkuste desktopovou nebo mobilní aplikaci, nebo jiné umístění souboru.',
			'dataFiles.downloadTimedOut' => 'Server neodpověděl včas. Zkuste to později.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} odpověděl chybou (HTTP ${status}). Zkuste to později.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} nemohl tento soubor poskytnout (HTTP ${status}). Zkontrolujte, zda je jeho adresa stále správná.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM nemá pro ${stem} žádný soubor Call History.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'Stažení souboru Call History z N1MM pro ${stem} se nezdařilo. Zkuste to později.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name} nelze zpracovat',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Stažený soubor obsahoval jen ${imported} z ${existing} záznamů na tomto zařízení, proto byly vynechané záznamy ponechány. Obnovením v Nastavení › Offline data ho přesto přijmete.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Importován ${count} záznam pro ${label}.', other: 'Importováno ${count} záznamů pro ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Importována data pro ${label}.',
			'dataFiles.cleanedUpTitle' => 'Data rozšíření vyčištěna',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Odebrána data ${count} datového souboru z vypnutých rozšíření.', other: 'Odebrána data ${count} datových souborů z vypnutých rozšíření.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} záznamů',
			'dataFiles.definitionUnavailable' => 'Zdroj souboru neposkytl definici — jeho rozšíření se možná právě restartuje nebo je špatně nakonfigurované. Za chvíli to zkuste znovu.',
			'updates.updateAvailable' => 'Aktualizace k dispozici',
			'updates.newVersionAvailable' => ({required Object version}) => 'Je k dispozici nová verze (${version}).',
			'updates.getIt' => 'Stáhnout',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Aktualizace připravena',
			'updates.restartToApply' => 'Aktualizace byla stažena. Restartujte, aby se použila.',
			'updates.appliesNextLaunch' => 'Aktualizace byla stažena. Použije se při příštím otevření aplikace.',
			'updates.restartNow' => 'Restartovat nyní',
			'updates.reloadToUpdate' => 'Je k dispozici novější verze této stránky. Načtěte ji znovu.',
			'updates.reloadNow' => 'Načíst znovu',
			'updates.checkForUpdates' => 'Zkontrolovat aktualizace',
			'updates.checkingForUpdates' => 'Kontrola aktualizací…',
			'updates.upToDate' => 'Aktuální',
			'updates.automaticChecks' => 'Kontrolovat automaticky',
			'updates.automaticChecksDescription' => 'Hledat nové verze na pozadí, od příštího spuštění aplikace',
			'extensionService.runtimeNotReady' => 'Běhové prostředí rozšíření není připraveno.',
			'extensionService.testFailed' => ({required Object error}) => 'Test selhal: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Připojeno jako ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Neplatná konfigurace pole',
			'extensionService.invalidValue' => 'Neplatná hodnota',
			'extensionService.validationError' => ({required Object error}) => 'Chyba ověření: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Akce selhala: ${error}',
			'extensionService.commandFailed' => 'Příkaz se nepodařilo spustit',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name} nemůže měnit nastavení: při instalaci o to nepožádalo',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name} nemůže ovládat rádio: při instalaci o to nepožádalo',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name} to nemůže spustit: je to jeden z vývojářských příkazů samotné aplikace',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => 'Hlášení teď nelze odeslat',
			'extensionService.stashUnavailable' => 'Ham2K File Stash je teď nedostupný',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => 'Bez odpovědi na hledání aktivit: ${names}. Některé výsledky mohou chybět.',
			'extensionService.activitySearchSomeSourcesFailed' => 'Některá rozšíření aktivit na hledání neodpověděla, takže některé výsledky mohou chybět.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} strávilo ve svých časovačích příliš mnoho času. Jsou zastaveny, dokud se rozšíření nerestartují.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Časovače ${name} opakovaně selhávaly. Jsou zastaveny, dokud se rozšíření nerestartují.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} se zaseklo v časovači. Jeho časovače jsou zastaveny, dokud se rozšíření nerestartují.',
			'operationLocationScreen.title' => 'Poloha aktivity',
			'operationLocationScreen.selectedLocation' => 'Vybraná poloha',
			'operationLocationScreen.gridSquare' => 'Lokátor Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Potřebuje 4, 6, 8 nebo 10 znaků, např. FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Navrhované polohy',
			'operationLocationScreen.deviceGps' => 'GPS zařízení',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS z ${device}',
			'operationLocationScreen.locating' => 'Hledání polohy…',
			'operationLocationScreen.gpsUnavailable' => 'Poloha není k dispozici',
			'operationLocationScreen.permissionDenied' => 'Oprávnění k poloze zamítnuto',
			'operationLocationScreen.permissionBlocked' => 'Oprávnění k poloze zablokováno',
			'operationLocationScreen.moreDetails' => 'Další podrobnosti',
			'operationLocationScreen.stateOrProvince' => 'Stát nebo provincie (nepovinné)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Ovládání aktivity není k dispozici',
			'operationLocationScreen.controlsUnavailableReason' => 'Tyto reference jsou stále použitelné; jen se nepodařilo spojit s jejich aktivitami.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Zkusit znovu',
			'operationLocationScreen.county' => 'Okres (nepovinné)',
			'versionLabel.version' => ({required Object version}) => 'Verze ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Oprava ${patch}',
			'versionLabel.build' => ({required Object build}) => 'sestavení ${build}',
			'notices.emptyHistory' => 'Zatím žádná oznámení',
			'notices.webStorageInMemory' => 'Tento prohlížeč nemohl poskytnout trvalé úložiště — log je jen v paměti a po zavření této karty bude ZTRACEN. Použijte aktuální Chrome, Firefox, Safari nebo Edge.',
			'notices.webStorageUnreliable' => 'Tento prohlížeč používá náhradní úložiště, které není bezpečné při více kartách — mějte otevřenou jen jednu kartu a nechte zapnutou synchronizaci.',
			'notices.logFromNewerBuildTitle' => 'Tento log vyžaduje novější verzi',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Váš log byl zapsán novější verzí HaLo (verze úložiště ${storage}; tato rozumí ${understood}), proto ho nelze otevřít a nová spojení nebudou uložena. Nainstalujte znovu novější verzi — nebo, pokud jste chtěli spustit toto sestavení, nasměrujte ho na jinou složku dat. Log je v ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Váš log byl zapsán novější verzí HaLo (verze úložiště ${storage}; tato rozumí ${understood}), proto ho nelze otevřít a nová spojení nebudou uložena. Otevřete tento log raději tou novější verzí.',
			'notices.preferencesRestoredTitle' => 'Nastavení obnoveno ze zálohy',
			'notices.preferencesRestored' => 'Soubor nastavení nelze přečíst, proto HaLo obnovil jeho poslední dobrou kopii. Cokoli jste změnili v předchozí relaci, možná bude nutné nastavit znovu. Nečitelný soubor je uložen vedle, pod názvem shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Nastavení obnoveno na výchozí',
			'notices.preferencesReset' => 'Soubor nastavení nelze přečíst a nebyla k dispozici žádná záloha, proto HaLo začal s výchozím nastavením. Nečitelný soubor je uložen ve složce dat aplikace pod názvem shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} nebylo připojeno automaticky',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo přestal odpovídat, když se naposledy začal připojovat k ${name}, proto ho tentokrát nechal být, aby to neriskoval znovu. Zkontrolujte, že je rádio zapnuté a kabel zapojený, pak u něj v Nastavení stiskněte Připojit.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonymní účet (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (čeká na potvrzení)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (čeká na potvrzení - #${id})',
			'deepLink.needsAnOperation' => 'Nejprve zahajte aktivitu, pak toto spojení pošlete znovu',
			'deepLink.waitingInOperation' => 'Toto spojení čeká v aktivitě za touto obrazovkou',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Toto zařízení nemá aktivitu pro ${refs}, proto byly tyto reference vynechány',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Vaše aktivity nejsou dostupné, proto bylo ${refs} vynecháno — zkuste ten odkaz znovu',
			'confirmDevice.title' => 'Potvrdit zařízení',
			'confirmDevice.codePrompt' => 'Zadejte kód zobrazený na zařízení, které se chce připojit k tomuto účtu.',
			'confirmDevice.code' => 'Kód',
			'confirmDevice.lookUp' => 'Vyhledat',
			'confirmDevice.codeNotFound' => 'Tomuto kódu neodpovídá žádná žádost. Kódy vyprší po 10 minutách — požádejte druhé zařízení o nový.',
			'confirmDevice.linkExpired' => 'Platnost odkazu vypršela. Požádejte druhé zařízení, aby zobrazilo nový QR kód.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Propojit ${device} s tímto účtem?',
			'confirmDevice.unnamedDevice' => 'nepojmenované zařízení',
			'confirmDevice.grantWarning' => 'Bude moci číst a měnit každou aktivitu a každé QSO v tomto účtu.',
			'confirmDevice.needsSyncTitle' => 'Toto zařízení se zatím nesynchronizuje',
			'confirmDevice.needsSyncText' => 'Zapněte synchronizaci Ham2K Log Filer a propojte toto zařízení s účtem, než bude moci přijmout další.',
			'confirmDevice.malformedRequest' => 'Synchronizační server poslal žádost, kterou tato aplikace nedokáže přečíst. Požádejte druhé zařízení, aby to zkusilo znovu.',
			'confirmDevice.linkIt' => 'Propojit zařízení',
			'switchAccounts.noAccountDetails' => 'Zatím žádné údaje o účtu',
			'switchAccounts.currentAccount' => 'Aktuální účet',
			'switchAccounts.otherAccounts' => 'Jiné účty',
			'switchAccounts.linkToAnother' => 'Propojit s jiným účtem',
			'switchAccounts.linkWithSibling' => 'Propojit s jinou aplikací Ham2K',
			'switchAccounts.linkWithPolo' => 'Propojit s účtem ve starší verzi',
			'switchAccounts.linkWithSiblingDescription' => 'Máte nainstalovanou jinou aplikaci Ham2K. Propojte se s účtem, který se používá tam.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Schvalte žádost v ${app} a pak se vraťte sem.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Znovu otevřít ${app}',
			'switchAccounts.siblingNoGrant' => 'Nefungovalo to? Otevřete ji znovu, nebo se vraťte a propojte jiným způsobem.',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app} nelze otevřít.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Odkaz vypršel a je připraven nový — znovu otevřete ${app}.',
			'switchAccounts.tryAgain' => 'Zkusit znovu',
			'switchAccounts.linkWithQr' => 'Propojit pomocí QR kódu',
			'switchAccounts.linkWithQrDescription' => 'Naskenujte ho ze zařízení, které už účet používá',
			'switchAccounts.linkWithEmail' => 'Propojit pomocí e-mailové adresy',
			'switchAccounts.linkWithEmailDescription' => 'Potvrďte kódem nebo odkazem v e-mailu',
			'switchAccounts.enterEmailPrompt' => 'Zadejte e-mailovou adresu účtu, který má toto zařízení používat.',
			'switchAccounts.emailAddress' => 'E-mailová adresa',
			'switchAccounts.linkAccount' => 'Propojit účet',
			'switchAccounts.copiedCode' => 'Kód zkopírován do schránky',
			'switchAccounts.copyCode' => 'Kopírovat kód',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Otevřete aplikaci Ham2K na zařízení, které už je propojeno s ${email}, a zadejte tento kód pro schválení žádosti:',
			'switchAccounts.waitingForConfirmation' => 'Čeká se na potvrzení…',
			'switchAccounts.sendEmailInstead' => 'Místo toho poslat potvrzovací e-mail',
			'switchAccounts.emailSent' => ({required Object email}) => 'Na ${email} byl odeslán e-mail. Otevřete ho a potvrďte žádost o propojení tohoto zařízení.',
			'switchAccounts.resendEmail' => 'Znovu odeslat e-mail',
			'switchAccounts.qrPrompt' => 'Naskenujte tento QR kód ze zařízení, které už je propojeno s požadovaným účtem — například pomocí Ham2K Portable Logger v telefonu.',
			'switchAccounts.serverUnreachable' => 'Synchronizační server je nedostupný. Zkuste to později.',
			'switchAccounts.emailRequired' => 'Zadejte e-mailovou adresu pro propojení.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Pro ${email} nebyl nalezen žádný účet.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Synchronizační server žádost odmítl: ${error}',
			'switchAccounts.noLinkCode' => 'Synchronizační server nevrátil kód pro propojení. Zkuste to později.',
			'switchAccounts.noConfirmationCode' => 'Synchronizační server neposlal potvrzovací kód. Zkuste to později.',
			'switchAccounts.switchNotAccepted' => 'Tento účet přepnutí nepřijal. Zkuste ho místo toho propojit pomocí e-mailové adresy.',
			'switchAccounts.requestFailed' => 'Při komunikaci se synchronizačním serverem se něco pokazilo. Zkuste to později.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} QSO', other: '${count} QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} aktivita', other: '${count} aktivit', ), 
			'qsonImport.title' => 'Importovat aktivitu QSON',
			'qsonImport.description' => 'Vytvořte novou aktivitu ze souboru QSON, jaký exportuje Režim vývojáře zde nebo v PoLo.',
			'qsonImport.dropHint' => 'Přetáhněte sem soubor QSON a importujte ho jako novou aktivitu',
			'qsonImport.importing' => ({required Object filename}) => 'Importování ${filename}…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => '${filename} nelze importovat: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'Soubor k importu nelze otevřít: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename} není text v UTF-8, takže to není soubor QSON',
			'qsonImport.notJson' => ({required Object filename}) => '${filename} není soubor JSON, takže to není soubor QSON',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename} neobsahuje aktivitu QSON',
			'qsonImport.busy' => 'Import už probíhá. Než spustíte další, počkejte, až skončí.',
			'qsonImport.oneFileOnly' => 'Přetahujte vždy jen jeden soubor QSON — každý se otevře jako samostatná aktivita.',
			'adifImport.title' => 'Importovat QSO z ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Čtení ${filename}…',
			'adifImport.dropHint' => 'Přetáhněte sem soubor ADIF k importu',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} QSO v tomto souboru', other: '${formatted} QSO v tomto souboru', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} už je ve vašem logu', other: '${formatted} už je ve vašem logu', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} bude importováno', other: '${formatted} bude importováno', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} nové spojení', other: '${formatted} nových spojení', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} se sloučí s existujícím spojením', other: '${formatted} se sloučí s existujícími spojeními', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} nelze importovat (bez značky)', other: '${formatted} nelze importovat (bez značky)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} je třeba zkontrolovat', other: '${formatted} je třeba zkontrolovat', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Reference nelze obnovit u ${count} spojení', other: 'Reference nelze obnovit u ${formatted} spojení', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Reference ${programs} mohou být neúplné u ${count} spojení', other: 'Reference ${programs} mohou být neúplné u ${formatted} spojení', ), 
			'adifImport.stackingTypesUnknown' => 'Sloučená spojení mohou přijít o referenci — aktivity nedokázaly říct, které typy se kombinují. Abyste tomu předešli, zrušte a zkuste to znovu.',
			'adifImport.nothingToImport' => 'Z tohoto souboru nelze nic importovat',
			'adifImport.confirm' => 'Importovat',
			'adifImport.importing' => ({required Object filename}) => 'Importování ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: 'Importováno ${count} spojení z ${filename}', other: 'Importováno ${formatted} spojení z ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename} nelze importovat: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} nevypadá jako soubor ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Upozornění: tento ADIF obsahuje QSO od ${calls}, ale pokud budete pokračovat, budou importována jako ${station}.',
			'adifImport.stationCallJoin' => ' a ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('cs'))(count, one: '${count} nemá datum a nelze ho importovat', other: '${formatted} nemá datum a nelze je importovat', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Tento soubor zaznamenává aktivaci ${refs}.',
			'adifImport.addActivation' => 'Přidat ji do této aktivity',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Použít se podařilo jen ${written} z ${planned} — log se změnil, zatímco jste se rozhodovali.',
			'adifImport.busy' => 'Import už probíhá. Než spustíte další, počkejte, až skončí.',
			'adifImport.oneFileOnly' => 'Přetahujte vždy jen jeden soubor ADIF — pořadí importu souborů rozhoduje, která data mají přednost.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} má více než ${limit} QSO, což je maximum, které aktivita může importovat najednou.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename} má více než ${limit} QSO. Import ADIF do aktivity je určen k přidání několika QSO, ne k nahrání velkého logu — na to použijte zobrazení Logy. Režim vývojáře vám ho přesto dovolí importovat, pokud jste si jistí.',
			'adifImport.importAnyway' => 'Přesto importovat',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: připojeno',
			'offline.noRoute' => 'Vůbec žádné připojení k síti.',
			'offline.unreachable' => 'Síť funguje, ale žádný server neodpovídá — často to znamená přihlašovací stránku čekající v prohlížeči.',
			'offline.reachable' => 'Všechny služby odpovídají podle očekávání.',
			'offline.whatStops' => 'Vyhledávání, spoty a datové soubory jsou pozastaveny. Logování a synchronizace v okolí ne.',
			'offline.servicesTitle' => 'Služby',
			'offline.noServices' => 'Zatím se neozvala žádná služba.',
			'offline.lastSuccess' => ({required Object when}) => 'Naposledy odpověděla před ${when}',
			'offline.neverSucceeded' => 'Zatím neodpověděla',
			'offline.nextAttempt' => ({required Object when}) => 'Další pokus za ${when}',
			'offline.nextAttemptNow' => 'Další pokus je na řadě',
			'offline.retry' => 'Zkusit nyní',
			'offline.retrying' => 'Zkouší se…',
			'offline.retryReached' => 'Opět online.',
			'offline.retryUnreachable' => 'Stále bez odpovědi.',
			'offline.retryNotAttempted' => 'Teď není co odeslat.',
			'offline.retryThrottled' => 'Právě jsme to zkusili — chvíli počkejte.',
			'offline.retryDisabled' => 'Synchronizace je vypnutá, takže není čím testovat.',
			'offline.syncService' => 'Synchronizace Ham2K LoFi',
			'offline.retryInFlight' => 'Už se zkouší — vydržte.',
			'exportSettings.defaultsDescription' => 'Základní nastavení pro všechny exporty, se samostatnými šablonami názvu souboru a titulku pro aktivity s referencemi a ostatní aktivity. Každý typ exportu může mít své vlastní výchozí hodnoty nebo vlastní nastavení.',
			'exportSettings.referenceActivities' => 'Aktivity s referencemi',
			'exportSettings.otherActivities' => 'Ostatní aktivity',
			'exportSettings.adifFields' => 'Pole ADIF',
			'exportSettings.loadFailed' => 'Nastavení exportu nelze načíst.',
			'exportSettings.retry' => 'Zkusit znovu',
			'exportSettings.compactFileNamesDescriptionOn' => 'Kompaktní názvy souborů, např. N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Popisné názvy souborů, např. 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Do souborů ADIF se zahrnují jména, adresy, e-maily, poznámky a přesné polohy.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Vynechávají se jména, adresy, e-maily a poznámky; polohy jsou omezeny na šestiznakové lokátory.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Zahrnují se informace ze služeb vyhledávání značek.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Vynechávají se informace ze služeb vyhledávání značek; ručně zadané hodnoty zůstávají.',
			'exportSettings.customTemplatesDescriptionOn' => 'Vaše vlastní šablony jsou aktivní a lze je upravit níže.',
			'exportSettings.customTemplatesDescriptionOff' => 'Aktivní jsou výchozí šablony. Vaše vlastní šablony zůstávají uloženy na později.',
			'exportSettings.type' => 'Typ exportu',
			'exportSettings.defaults' => 'Výchozí',
			'exportSettings.includeLookupData' => 'Zahrnout data z vyhledávání',
			'exportSettings.customTemplates' => 'Vlastní šablony',
			'exportSettings.filenameTemplate' => 'Šablona názvu souboru',
			'exportSettings.compactFilenameTemplate' => 'Šablona kompaktního názvu souboru',
			'exportSettings.titleTemplate' => 'Šablona titulku',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO poznámky',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO komentáře',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL zpráva',
			'exportSettings.shared' => 'Nastavení platí pro všechna rozšíření, která používají tento typ exportu.',
			'exportSettings.defaultTemplates' => 'Pro úpravu šablon tohoto typu zapněte Vlastní šablony.',
			'templateEditor.previewLabel' => 'Náhled:',
			'templateEditor.reset' => 'Obnovit výchozí',
			'templateEditor.docs' => 'Dokumentace šablon',
			'templateEditor.preview' => 'Ukázkový náhled',
			'templateEditor.reference' => 'Nápověda k šablonám',
			'templateEditor.attributes' => 'Dostupné atributy',
			'templateEditor.filters' => 'Filtry',
			'templateEditor.flowControl' => 'Řízení toku',
			'templateEditor.unavailable' => 'Náhled není k dispozici, dokud nejsou rozšíření připravena.',
			'templateEditor.empty' => '(prázdný výstup)',
			_ => null,
		};
	}
}
