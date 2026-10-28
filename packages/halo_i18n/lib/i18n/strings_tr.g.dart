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
class TranslationsTr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsTr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.tr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <tr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsTr _root = this; // ignore: unused_field

	@override 
	TranslationsTr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsTr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$tr common = _Translations$common$tr._(_root);
	@override late final _Translations$onboarding$tr onboarding = _Translations$onboarding$tr._(_root);
	@override late final _Translations$startScreen$tr startScreen = _Translations$startScreen$tr._(_root);
	@override late final _Translations$testerOverlay$tr testerOverlay = _Translations$testerOverlay$tr._(_root);
	@override late final _Translations$extensionsPanel$tr extensionsPanel = _Translations$extensionsPanel$tr._(_root);
	@override late final _Translations$home$tr home = _Translations$home$tr._(_root);
	@override late final _Translations$chase$tr chase = _Translations$chase$tr._(_root);
	@override late final _Translations$dialogs$tr dialogs = _Translations$dialogs$tr._(_root);
	@override late final _Translations$operation$tr operation = _Translations$operation$tr._(_root);
	@override late final _Translations$map$tr map = _Translations$map$tr._(_root);
	@override late final _Translations$mapsView$tr mapsView = _Translations$mapsView$tr._(_root);
	@override late final _Translations$activitiesView$tr activitiesView = _Translations$activitiesView$tr._(_root);
	@override late final _Translations$loggingControls$tr loggingControls = _Translations$loggingControls$tr._(_root);
	@override late final _Translations$formChrome$tr formChrome = _Translations$formChrome$tr._(_root);
	@override late final _Translations$qsoEditForm$tr qsoEditForm = _Translations$qsoEditForm$tr._(_root);
	@override late final _Translations$qsoList$tr qsoList = _Translations$qsoList$tr._(_root);
	@override late final _Translations$loggingPanel$tr loggingPanel = _Translations$loggingPanel$tr._(_root);
	@override late final _Translations$callInfo$tr callInfo = _Translations$callInfo$tr._(_root);
	@override late final _Translations$settings$tr settings = _Translations$settings$tr._(_root);
	@override late final _Translations$commands$tr commands = _Translations$commands$tr._(_root);
	@override late final _Translations$commandDialog$tr commandDialog = _Translations$commandDialog$tr._(_root);
	@override late final _Translations$expiredBuild$tr expiredBuild = _Translations$expiredBuild$tr._(_root);
	@override late final _Translations$staleness$tr staleness = _Translations$staleness$tr._(_root);
	@override late final _Translations$spotting$tr spotting = _Translations$spotting$tr._(_root);
	@override late final _Translations$dataFiles$tr dataFiles = _Translations$dataFiles$tr._(_root);
	@override late final _Translations$updates$tr updates = _Translations$updates$tr._(_root);
	@override late final _Translations$extensionService$tr extensionService = _Translations$extensionService$tr._(_root);
	@override late final _Translations$operationLocationScreen$tr operationLocationScreen = _Translations$operationLocationScreen$tr._(_root);
	@override late final _Translations$versionLabel$tr versionLabel = _Translations$versionLabel$tr._(_root);
	@override late final _Translations$notices$tr notices = _Translations$notices$tr._(_root);
	@override late final _Translations$syncAccount$tr syncAccount = _Translations$syncAccount$tr._(_root);
	@override late final _Translations$deepLink$tr deepLink = _Translations$deepLink$tr._(_root);
	@override late final _Translations$confirmDevice$tr confirmDevice = _Translations$confirmDevice$tr._(_root);
	@override late final _Translations$switchAccounts$tr switchAccounts = _Translations$switchAccounts$tr._(_root);
	@override late final _Translations$adifImport$tr adifImport = _Translations$adifImport$tr._(_root);
	@override late final _Translations$offline$tr offline = _Translations$offline$tr._(_root);
	@override late final _Translations$exportSettings$tr exportSettings = _Translations$exportSettings$tr._(_root);
	@override late final _Translations$templateEditor$tr templateEditor = _Translations$templateEditor$tr._(_root);
}

// Path: common
class _Translations$common$tr extends Translations$common$en {
	_Translations$common$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get save => 'Kaydet';
	@override String get ok => 'Tamam';
	@override String get cancel => 'İptal';
	@override String get delete => 'Sil';
	@override String get create => 'Oluştur';
	@override String get error => 'Hata';
	@override String get close => 'Kapat';
	@override String get done => 'Tamamlandı';
	@override String get callsign => 'Çağrı İşareti';
	@override String get clear => 'Temizle';
	@override String get dismiss => 'Kapat';
	@override String get expand => 'Genişlet';
	@override String get collapse => 'Daralt';
}

// Path: onboarding
class _Translations$onboarding$tr extends Translations$onboarding$en {
	_Translations$onboarding$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Ham2K Portable Logger\'a hoş geldiniz!';
	@override String get welcomeTitleDesktop => 'Ham2K Power Logger\'a hoş geldiniz!';
	@override String get welcomeBody => 'İhtiyaçlarınıza daha iyi uyum sağlamak için birkaç sorumuz var.';
	@override String get skip => 'Atla';
	@override String get kContinue => 'Devam';
	@override String get back => 'Geri';
	@override String get next => 'İleri';
	@override String get done => 'Tamamlandı';
	@override String get callsignTitle => 'Çağrı işaretiniz nedir?';
	@override String get callsignBody => 'Bu uygulamadan yararlanmak için bir Amatör Telsiz Operatörü Lisansına ihtiyacınız var';
	@override String get callsignLabel => 'Operatörün Çağrı İşareti';
	@override String get alreadyHaveAccount => 'Zaten bir hesabınız var mı?';
	@override String get foundSiblingTitle => 'Mevcut bir hesap bağlansın mı?';
	@override String foundSiblingBody({required Object app}) => 'Bu cihazda ${app} bulduk. Bu uygulamayı aynı hesaba bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.';
	@override String get foundPoloBody => 'Bu cihazda Ham2K Portable Logger\'ın eski bir sürümünü bulduk. Bu uygulamayı aynı hesaba bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.';
	@override String get foundSiblingsBody => 'Bu cihazda başka Ham2K uygulamaları bulduk. Bu uygulamayı onların hesaplarından birine bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.';
	@override String linkWithApp({required Object app}) => '${app} ile bağla';
	@override String get linkWithPolo => 'Eski sürümdeki hesapla bağla';
	@override String get setUpFresh => 'Sıfırdan kur';
	@override String get activitiesTitle => 'Favori Aktiviteler';
	@override String get activitiesBody => 'Bu popüler aktivasyon programlarından herhangi biriyle ilgileniyor musunuz?';
	@override String get activitiesFooter => '(Ayarlar\'da daha fazla seçenek bulabilirsiniz)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Veri ve Gizlilik';
	@override String get consentUsageBody => 'Uygulamayı geliştirmemize yardımcı olmak için performans, çökme ve uygulama kullanım verilerini toplamak istiyoruz.';
	@override String get consentUsageLabel => 'Uygulama kullanım verilerini paylaş';
	@override String get consentOperationBody => 'Bazı özellikler operasyon verilerinizin diğer kullanıcılarla paylaşılmasını içerebilir. İstediğiniz zaman vazgeçebilirsiniz.';
	@override String get consentOperationLabel => 'Operasyon Verilerini Paylaş';
	@override String get finishingSetup => 'Kurulum tamamlanıyor — referans verileri indiriliyor…';
}

// Path: startScreen
class _Translations$startScreen$tr extends Translations$startScreen$en {
	_Translations$startScreen$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get credits => 'KI2D ve arkadaşları tarafından';
}

// Path: testerOverlay
class _Translations$testerOverlay$tr extends Translations$testerOverlay$en {
	_Translations$testerOverlay$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get tape => 'DİKKAT: YAPIM AŞAMASINDA';
	@override String get warningTitle => 'Bu uygulama hâlâ geliştiriliyor';
	@override String get warningBody => 'Çoğu özelliğin yüzeyi engebeli ve her yerde takılıp düşme tehlikesi var. Lütfen güncellemeleri düzenli olarak kontrol edin.';
	@override String whatsNew({required Object build}) => '${build} sürümündeki yenilikler';
	@override String get thanks => 'Bu uygulamayı daha iyi hale getirmemize yardımcı olmak için günlüğünüzü riske attığınız için teşekkürler!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$tr extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Aktiviteler';
	@override String get categoryContest => 'Yarışmalar';
	@override String get categoryLookup => 'Çağrı İşareti Sorguları';
	@override String get categorySpots => 'Spot Kaynakları';
	@override String get categoryDashboard => 'Pano Panelleri';
	@override String get categoryOther => 'Diğer Uzantılar';
	@override String get searchHint => 'Uzantılarda ara';
	@override String get applying => 'Uzantı değişiklikleri etkinleştiriliyor, bu biraz zaman alabilir…';
	@override String get noMatches => 'Aramanızla eşleşen uzantı yok';
	@override String get installFromFile => 'Dosyadan yükle…';
	@override String installVersion({required Object version}) => 'Sürüm ${version}';
	@override String get canReach => 'Bu uzantının bağlanabildikleri';
	@override String canHoldConnection({required Object host}) => '${host}, canlı bir bağlantı üzerinden';
	@override String get canHoldLocalConnection => 'Yerel ağınızdaki cihazlar, canlı bir bağlantı üzerinden';
	@override String get canUseLocation => 'Konumunuz';
	@override String get canReadRadio => 'Radyonuz, frekansını ve modunu okumak için';
	@override String get canControlRadio => 'Radyonuz, onu kontrol etmek ve onunla yayın yapmak için — ayar, güç, CW, ses hafızaları ve PTT';
	@override String get canSetUserAgent => 'Sunuculara kendi adıyla tanıtma';
	@override String get noCapabilities => 'Uygulama dışında hiçbir şey istemiyor.';
	@override String get sandboxNote => 'Uzantılar korumalı alanda çalışır: dosyalarınıza erişemez ve burada listelenenler dışında ağa çıkamaz.';
	@override String get installAction => 'Yükle';
	@override String get updateAction => 'Güncelle';
	@override String get installFailed => 'Bu uzantı yüklenemedi';
	@override String get installedBadge => 'Yüklü';
	@override String get uninstallAction => 'Kaldır';
	@override String uninstallTitle({required Object name}) => '${name} kaldırılsın mı?';
	@override String get uninstallBody => 'Bu uzantı ve ayarları kaldırılacak. Günlükleriniz olduğu gibi kalır.';
	@override String installedMessage({required Object name}) => '${name} yüklendi';
	@override String get installDownloading => 'İndiriliyor…';
	@override String get installWaiting => 'Yükleme bekleniyor…';
	@override String get installInstalling => 'Yükleniyor…';
	@override String get installAwaitingApproval => 'Onayınız bekleniyor…';
	@override String installAlreadyRunning({required Object name}) => '${name} zaten yükleniyor.';
	@override String updatedTo({required Object version}) => '${version} sürümüne güncellendi';
	@override String installIncomplete({required Object name}) => '${name} yüklemesi tamamlanmadı. Yeniden yüklenmesi gerekebilir.';
	@override String uninstallFailed({required Object name}) => '${name} kaldırılamadı';
	@override String installedFrom({required Object source}) => '${source} kaynağından indirildi';
	@override String get dropHint => 'Yüklemek için bir .h2kext uzantısı bırakın';
	@override String get dropOneOnly => 'Her seferinde bir uzantı bırakın.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} bu uzantı için ${status} döndürdü.';
	@override String get downloadTooLarge => 'Bu indirme bir uzantı olamayacak kadar büyük.';
	@override String get downloadNotSecure => 'Bu indirme güvenli olmayan bir yere yönlendirildi.';
	@override String get catalogSection => 'Katalog';
	@override String get catalogLoading => 'Katalog yükleniyor…';
	@override String get catalogUnreachable => 'Kataloğa ulaşılamıyor';
	@override String get builtIn => 'Dahili';
	@override String get updateAvailableBadge => 'Güncelleme mevcut';
	@override String get updatesAvailableTitle => 'Uzantı güncellemeleri';
	@override String updateAvailableFor({required Object name}) => '${name} için bir güncelleme mevcut.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} ve ${count} tane daha güncellenmeli.';
	@override String updatesAvailableFor({required Object names}) => '${names} güncellenmeli.';
	@override String get pendingUpdatesSection => 'Bekleyen Güncellemeler';
	@override String get updateAllAction => 'Tümünü güncelle';
	@override String get updatesUnderWay => 'Bu güncellemeler zaten sürüyor.';
	@override String get updatesNothingLeft => 'Uzantılarınız güncel.';
	@override String get updatesNoticeAction => 'Daha fazla bilgi';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} uzantı güncellensin mi?',
		other: '${count} uzantı güncellensin mi?',
	);
	@override String get upgradeDoneTitle => 'Uzantılarınız hazır';
	@override String get upgradeDoneBody => 'Artık Ham2K uzantı kataloğundan geliyorlar, böylece uygulamanın yeni sürümünü beklemeden güncellenebilirler.';
	@override String upgradeDoneUnserved({required Object names}) => 'Yükseltilmedi: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Çalışmadı: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Hâlâ yüklüler ve Ayarlar › Uzantılar bölümünde işaretliler — orada güncellemek onları geri getirir.';
	@override String get upgradeDoneUnservedHint => 'Katalogda bunların doğrudan bir karşılığı yok; kullandıklarınızı kapsayan uzantılar için oraya bakın.';
	@override String get retiredQp => 'QSO Partileri';
	@override String get retiredStateparks => 'Eyalet Parkları Etkinlikleri';
	@override String upgradeDoneMissing({required Object count}) => '${count} uzantınız henüz gelmedi. Uzantı kataloğuna bir sonraki ulaşılabildiğinde indirilecekler.';
	@override String get runtimeDeadBody => 'Uzantılarınız başlamadı. Uygulamayı yeniden başlatmak onları geri getirmeli.';
	@override String get refusedTitle => 'Bazı uzantılar çalışmadı';
	@override String get upgradeBusyTitle => 'Kurulum sürüyor';
	@override String get upgradeRuntimeDeadTitle => 'Uzantılarınız çalışmıyor';
	@override String get restoreTitle => 'Bazı uzantılarınız eksik';
	@override String get restoreBody => 'Yüklediğiniz bu uzantılar bu cihazda yok. Onları Ham2K uzantı kataloğundan yeniden indirebiliriz:';
	@override String get restoreFromFile => 'Bir dosyadan yüklendi. Bunları dosyalarından yeniden yükleyin ya da unutun:';
	@override String get restoreOtherCatalog => 'Farklı bir uzantı kataloğundan yüklendi, bu yüzden burada kullanılamıyor:';
	@override String get restoreForget => 'Unut';
	@override String get restoreInstall => 'Yükle';
	@override String get restoreLater => 'Sonra';
	@override String get restoreInstalling => 'Uzantılarınız yükleniyor…';
	@override String get restoreDoneTitle => 'Uzantılarınız geri geldi';
	@override String restoreDoneBody({required Object names}) => 'Yeniden yüklendi: ${names}.';
	@override String get restorePartialTitle => 'Bazı uzantılar yüklenemedi';
	@override String restoreFailed({required Object names}) => 'Yüklenemedi: ${names}. Uygulamayı bir sonraki açışınızda yeniden önereceğiz.';
	@override String get restoreBusyBody => 'Uygulama uzantılarınızı hâlâ kuruyor. Bunları uygulamayı bir sonraki açışınızda yeniden önereceğiz.';
	@override String get restoreRuntimeDeadBody => 'Onları yeniden yükledik, ancak uzantılarınız başlamadı. Uygulamayı yeniden başlatmak onları geri getirmeli.';
	@override String revokedTitle({required Object name}) => '${name} geri çekildi';
	@override String get revokedBody => 'Katalog bu sürümü geri çekti, bu yüzden devre dışı bırakıldı.';
	@override String get downloadHashMismatch => 'Bu indirme, kataloğun tanımladığı uzantı değil.';
	@override String catalogVersionUnknown({required Object key, required Object version}) => 'Katalogda ${key} için ${version} sürümü yok.';
	@override String get catalogLinkUnknown => 'Bu katalog bağlantısı bir uzantı sürümü belirtmiyor.';
	@override String catalogNoRelease({required Object key}) => 'Katalogda o kanalda ${key} için bir sürüm yok.';
	@override String get installFromLink => 'Bağlantıdan yükle';
	@override String get unstableReleaseWarning => 'Bu, yayıncısının henüz bitmiş saymadığı kararsız bir sürüm. Hatalı davranabilir ve kararsız güncellemeler almaya devam eder.';
	@override String get bleedingReleaseWarning => 'Bu deneysel bir sürüm: bozulabilecek veya ayarlarını kaybedebilecek, geliştirme aşamasındaki bir çalışma. Deneysel güncellemeler almaya devam eder.';
	@override String get channelUnstable => 'Kararsız';
	@override String get channelBleeding => 'Deneysel';
	@override String get followsUnstable => 'Kararsız ve kararlı sürümleri alır';
	@override String get followsBleeding => 'Deneysel, kararsız ve kararlı sürümleri alır';
	@override String get followStableAction => 'Yalnızca kararlı sürümleri takip et';
	@override String get revokedBadge => 'Geri çekildi';
	@override String get refusedBadge => 'Yüklenmedi';
	@override String get downloadNotHttps => 'Bu indirme güvenli bir bağlantı üzerinden yapılmıyor.';
	@override String downloadUnreachable({required Object source}) => 'Bu uzantı için ${source} kaynağına ulaşılamadı.';
	@override String get detailsAction => 'Ayrıntılar';
	@override String get installedFromFile => 'Bir dosyadan yüklendi';
	@override String get detailsWhatItDoes => 'Şunlar için destek sağlar';
	@override String get installedPreloaded => 'Önceden yüklü';
	@override String get hookAccount => 'Hesap girişi';
	@override String get hookCallNotes => 'Çağrı notları';
	@override String get hookDataFile => 'Çevrimdışı veri';
	@override String get hookExport => 'Dışa aktarma';
	@override String get hookLookup => 'Çağrı işareti sorguları';
	@override String get hookScoring => 'Puanlama';
	@override String get hookSpots => 'Spotlar';
	@override String hookHunting({required Object program}) => '${program} avcılığı';
	@override String hookActivating({required Object program}) => '${program} aktivasyonu';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '… ve ${count} uzantı daha',
		other: '… ve ${count} uzantı daha',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} uzantı mevcut',
		other: '${count} uzantı mevcut',
	);
}

// Path: home
class _Translations$home$tr extends Translations$home$en {
	_Translations$home$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Taşınabilir Logger';
	@override String get newOperation => 'Yeni operasyon';
	@override String get stationCallsign => 'İstasyon çağrı işareti';
	@override String get titleOptional => 'Başlık (isteğe bağlı)';
	@override String get emptyList => 'Henüz operasyon yok. Kayda başlamak için bir tane oluşturun.';
	@override String get quickLookup => 'Hızlı Sorgu';
	@override late final _Translations$home$nav$tr nav = _Translations$home$nav$tr._(_root);
	@override late final _Translations$home$panels$tr panels = _Translations$home$panels$tr._(_root);
	@override String get toggleNav => 'Gezinme etiketlerini göster veya gizle';
	@override late final _Translations$home$logs$tr logs = _Translations$home$logs$tr._(_root);
}

// Path: chase
class _Translations$chase$tr extends Translations$chase$en {
	_Translations$chase$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'avlıyor';
	@override String goalsTwo({required Object first, required Object second}) => '${first} ve ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} ve daha fazlası';
	@override late final _Translations$chase$station$tr station = _Translations$chase$station$tr._(_root);
	@override late final _Translations$chase$periodInline$tr periodInline = _Translations$chase$periodInline$tr._(_root);
	@override late final _Translations$chase$periodStats$tr periodStats = _Translations$chase$periodStats$tr._(_root);
	@override late final _Translations$chase$period$tr period = _Translations$chase$period$tr._(_root);
	@override late final _Translations$chase$goals$tr goals = _Translations$chase$goals$tr._(_root);
	@override late final _Translations$chase$panels$tr panels = _Translations$chase$panels$tr._(_root);
}

// Path: dialogs
class _Translations$dialogs$tr extends Translations$dialogs$en {
	_Translations$dialogs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Operasyon ayrıntıları';
	@override String get activities => 'Aktiviteler';
	@override String get stationCallsign => 'İstasyon Çağrı İşareti';
	@override String get notes => 'Notlar';
	@override String get deleteOperationTitle => 'Operasyonu Sil';
	@override String get purgeTestsTitle => 'Test Operasyonlarını Temizle';
	@override String get purgeTestsBody => 'Bu, bu Test Operasyonlarını ve QSO\'larını kalıcı olarak siler. Geri alınamaz.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Ayrıca hiçbir operasyona ait olmayan ${count} test QSO\'su.',
		other: 'Ayrıca hiçbir operasyona ait olmayan ${count} test QSO\'su.',
	);
	@override String get purgeTestsAction => 'Temizle';
	@override String get syncAllTitle => 'Bu cihazın günlüğü değiştirilsin mi?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL bu cihazdaki ${qsos} kaydını yedekleyip temizler, ardından hesabın günlüğünü sunucudan yeniden indirir. Yedek bu cihazın veritabanında kalır.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${n} QSO henüz senkronize edilmedi — sunucu onu hiç almadı ve GERİ GELMEYECEK.',
		other: '${n} QSO henüz senkronize edilmedi — sunucu onları hiç almadı ve GERİ GELMEYECEKLER.',
	);
	@override String get syncAllAction => 'Sil ve Yeniden Senkronize Et';
	@override String get receivedPurgesTitle => 'Başka Yerde Kaldırılan Test Operasyonları';
	@override String get receivedPurgesBody => 'Bunlar başka bir cihazda Test Operasyonu olarak silindi. Burada da kaldırılsın mı? Bu işlem onları ve QSO\'larını kalıcı olarak siler ve geri alınamaz.';
	@override String get receivedPurgesAction => 'Kaldır';
	@override late final _Translations$dialogs$callChange$tr callChange = _Translations$dialogs$callChange$tr._(_root);
}

// Path: operation
class _Translations$operation$tr extends Translations$operation$en {
	_Translations$operation$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Bu operasyon silinmiş. Kayıt yapmak veya değişiklik yapmak için silmeyi geri alın.';
	@override late final _Translations$operation$tabs$tr tabs = _Translations$operation$tabs$tr._(_root);
	@override late final _Translations$operation$positions$tr positions = _Translations$operation$positions$tr._(_root);
	@override String get stationCallsignNone => 'İstasyon çağrı işareti yok';
	@override String get titleNone => 'Başlık yok';
	@override String get deleteOperation => 'Operasyonu sil';
	@override String get loggingControlsStale => 'Aktivite alanları güncel olmayabilir — yenilemek için operasyonu yeniden açın';
	@override String get locationNone => 'Ayarlanmadı';
	@override String get generalOperation => 'Genel Operasyon';
	@override String titleFor({required Object value}) => '${value} için';
	@override String titleAt({required Object value}) => '${value} konumunda';
	@override String segmentNow({required Object description}) => 'Şimdi ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$tr menu = _Translations$operation$menu$tr._(_root);
	@override late final _Translations$operation$layout$tr layout = _Translations$operation$layout$tr._(_root);
	@override late final _Translations$operation$export$tr export = _Translations$operation$export$tr._(_root);
	@override late final _Translations$operation$spots$tr spots = _Translations$operation$spots$tr._(_root);
	@override late final _Translations$operation$import$tr import = _Translations$operation$import$tr._(_root);
}

// Path: map
class _Translations$map$tr extends Translations$map$en {
	_Translations$map$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$tr outlineIssue = _Translations$map$outlineIssue$tr._(_root);
	@override String get outlinesDisclaimer => 'Sınırlar yalnızca referans amaçlıdır. Kendi araştırmanızı yapın!';
	@override String outlinesCredit({required Object sources}) => 'Sınır çizgileri: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'İdari sınırlar: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Tesisler: ${sources}';
	@override String get fullCredits => 'Tüm veri kaynakları';
	@override String get fewerCredits => 'Daha az kaynak';
	@override String get emptyState => 'Henüz QSO konumu yok.\nGrid karesi, eyalet veya ülke bilgisi olan QSO\'lar burada görünür.';
	@override String get unavailable => 'Harita şu anda kullanılamıyor.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mil';
	@override String get flat => 'Düz';
	@override String get globe => 'Küre';
	@override String get zoomIn => 'Yakınlaştır';
	@override String get zoomOut => 'Uzaklaştır';
	@override late final _Translations$map$postcard$tr postcard = _Translations$map$postcard$tr._(_root);
}

// Path: mapsView
class _Translations$mapsView$tr extends Translations$mapsView$en {
	_Translations$mapsView$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haritalar';
	@override String get searchHint => 'Park, zirve ve daha fazlasını ara';
	@override String get activities => 'Aktiviteler';
	@override String get layers => 'Katmanlar';
	@override String get baseMap => 'Temel harita';
	@override String get satellite => 'Uydu (Esri)';
	@override String get facilities => 'Park tesisleri';
	@override String get boundaries => 'İdari sınırlar';
	@override String get currentLocation => 'Mevcut konum';
	@override String noMatches({required Object text}) => '“${text}” ile eşleşen bir şey yok';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${where} konumunda ${count} referans',
		other: '${where} konumunda ${count} referans',
	);
	@override String get startOperation => 'Bu referanslarla bir operasyon başlat';
}

// Path: activitiesView
class _Translations$activitiesView$tr extends Translations$activitiesView$en {
	_Translations$activitiesView$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aktiviteler';
	@override String get activitiesCountZero => 'Seçili Aktivite Yok';
	@override String get activitiesCountOne => '1 Aktivite';
	@override String activitiesCountOther({required Object count}) => '${count} Aktivite';
	@override String get empty => 'Henüz aktivite yok — eklemek için aşağıdaki Öneriler ve Arama\'yı kullanın';
	@override String get removeActivity => 'Kaldır';
	@override String openReferenceLink({required Object name}) => '${name} aç';
	@override String get editActivity => 'Aktiviteyi düzenle';
	@override String get manageExtensions => 'Uzantıları Yönet';
	@override String get manage => 'Yönet';
	@override String activitiesTitle1({required Object first}) => 'Aktivite Türleri: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Aktivite Türleri: ${first} ve ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Aktivite Türleri: ${first}, ${second} ve ${more} tane daha';
	@override String get reference => 'Referans';
	@override String get invalidReference => 'Geçersiz';
	@override String get duplicateReference => 'Zaten eklendi';
	@override String get searchHint => 'İsim, referans veya başka bir şeyle arayın…';
	@override String get noSuggestions => 'Eşleşme yok';
	@override String get noSuggestionsHint => 'Yukarıda referans adı veya numarasıyla arayın';
	@override String get noSuggestionsExample => '(örneğin \'trail\' veya \'4556\')';
	@override String get allOptions => 'Aktivite Türleri';
	@override String get determiningLocation => 'Mevcut konum belirleniyor…\nYakındaki referansları bulmak için GPS konumu bekleniyor';
	@override String get locationUnavailableTitle => 'Konum verisi kullanılamıyor';
	@override String get locationDeniedTitle => 'Konum izni reddedildi';
	@override String get locationBlockedTitle => 'Konum izni engellendi';
	@override String get noNearbyReason => 'Yakındaki referanslar belirlenemiyor';
	@override String locationManualHint({required Object icon}) => 'Konumunuzu elle girmek için ${icon} simgesine dokunun\nveya referansları isimle arayın';
	@override String get locationGrantAction => 'Konum erişimine izin ver';
	@override String get locationSettingsAction => 'Ayarları Aç';
	@override String get locationSettingsUnavailable => 'Sistem ayarlarınızdan konum erişimine izin verin';
	@override String get locationGrantRefused => 'Hâlâ konum yok — sistem yine hayır dedi';
	@override String get searchUnavailableTitle => 'Aktivite araması kullanılamıyor';
	@override String get searchUnavailableReason => 'Hiçbir aktivite uzantısı aramayı çalıştıramadı. Birazdan tekrar deneyin.';
	@override String get emptySheet => 'Eklemek için aşağıdaki öneriler ve aramayı kullanın';
	@override String get exports => 'Dışa Aktarımlar';
	@override String get exportLogs => 'Günlükleri Dışa Aktar';
	@override String get tools => 'Araçlar';
	@override String get toolsTitle => 'Operasyon Araçları';
	@override String get operationDetails => 'Operasyon Ayrıntıları';
	@override String get share => 'Paylaş';
	@override String get archive => 'Arşivle';
	@override String get deleteOperation => 'Operasyonu Sil';
	@override String get undeleteOperation => 'Operasyonu Geri Getir';
	@override String get alreadySelected => 'Zaten seçili';
	@override String get selected => 'Seçili';
	@override String pickPosition({required Object index, required Object count}) => '${index} / ${count}';
	@override String get previousPick => 'Önceki eşleşme';
	@override String get nextPick => 'Sonraki eşleşme';
	@override String get retiredReference => 'Kullanımdan kalktı';
	@override String enableExtension({required Object name}) => '${name} etkinleştir';
	@override String get enableExtensionHint => 'Bu uzantı aramanızla eşleşiyor, ancak şu anda etkin değil';
	@override String get enableExtensionForRefHint => 'Bu uzantı bu operasyonun referanslarından birini işliyor, ancak şu anda etkin değil';
	@override String extensionNotRunning({required Object name}) => '${name} çalışmıyor';
	@override String get extensionNotRunningHint => 'Bu uzantı devre dışı bırakıldı; daha fazla bilgi için Uzantı Ayarları\'nı açın';
	@override String installExtension({required Object name}) => '${name} yükle';
	@override String get installExtensionHint => 'Bu uzantı aramanızla eşleşiyor, ancak yüklü değil';
	@override String get onlyCatalogMatches => 'Eşleşme yok\nKatalogdaki bazı uzantılarda sonuç olabilir.\nOnları aşağıdaki Aktivite Türleri\'nden yükleyin.';
	@override String get setupUnavailable => 'Bu aktivitenin kurulumu yüklenemedi — Yönet\'ten tekrar deneyin';
	@override String get controlsUnavailableTitle => 'Aktivite kontrolleri kullanılamıyor';
	@override String get controlsUnavailableReason => 'Referanslarınız güvende, ancak şu anda düzenlenemiyorlar.';
	@override String get controlsUnavailableRetry => 'Tekrar dene';
	@override String get onlyDisabledMatches => 'Eşleşme yok\nBazı kullanılabilir uzantılarda sonuç olabilir.\nOnları aşağıdaki Aktivite Türleri\'nden etkinleştirin.';
	@override String get onlyNotRunningMatches => 'Eşleşme yok\nSonuç verebilecek bazı uzantılar çalışmıyor.\nAşağıdaki Aktivite Türleri\'ne bakın.';
	@override String get mapToggle => 'Harita';
	@override String get searchToggle => 'Ara';
	@override String get addToOperation => 'Operasyona Ekle';
	@override String get addToOperationShort => 'Op.\'a Ekle';
	@override String get mapEmptyState => 'Haritada gösterilecek sonuç yok';
	@override String get mapEmptyStateHint => 'Listeye geri dönün veya başka bir şey arayın';
	@override String get imports => 'İçe Aktarımlar';
}

// Path: loggingControls
class _Translations$loggingControls$tr extends Translations$loggingControls$en {
	_Translations$loggingControls$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Zaman (UTC)';
	@override String get date => 'Tarih';
	@override String get now => 'Şimdi';
	@override String get frequency => 'Frekans';
	@override String get mode => 'Mod';
	@override String get theirCall => 'Onların çağrısı';
	@override String get noteField => 'Not';
	@override String get todoField => 'Yapılacak';
	@override String get sent => 'Gönd.';
	@override String get rcvd => 'Alın.';
	@override String get more => 'Diğer';
	@override String get revert => 'Geri Al';
	@override String get undoDelete => 'Silmeyi geri al';
	@override String get restore => 'Geri getir';
	@override String get wipe => 'Sil';
	@override String get undo => 'Geri Al';
	@override String get pendingDeleteTapWarning => 'Bu QSO\'yu silmek için çöp kutusuna bir kez daha dokunun';
	@override String get pendingDeleteClickWarning => 'Bu QSO\'yu silmek için çöp kutusuna bir kez daha tıklayın';
	@override String get deletedQsoWarning => 'Silinen QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Bu ${kind} öğesini silmek için çöp kutusuna bir kez daha dokunun';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Bu ${kind} öğesini silmek için çöp kutusuna bir kez daha tıklayın';
	@override String deletedEventWarning({required Object kind}) => 'Silinen ${kind}';
	@override String get timeControl => 'Zaman';
	@override String get radioControl => 'Radyo';
	@override String get powerControl => 'Güç';
	@override String get notesControl => 'Notlar';
	@override String get power => 'Güç';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Kayıt Kontrolleri';
	@override String get spottingControl => 'Spotlama';
	@override String get spottingSelfControl => 'Kendini spotlama';
	@override String spotSelfAt({required Object freq}) => '${freq} üzerinde kendini spotla';
	@override String spotOtherAt({required Object call, required Object freq}) => '${call} istasyonunu ${freq} üzerinde spotla';
	@override String spotTooLate({required Object call}) => '${call} istasyonunu spotlamak için çok geç';
	@override String get spotNoFreq => 'Spotlamak için önce bir frekans ayarlayın';
	@override String get spotComment => 'Yorum';
	@override String get bandOrFreqRequired => 'Kaydetmeden önce bir frekans veya bant ayarlayın';
	@override String get missingBand => 'Bant Yok';
	@override String get missingMode => 'Mod Yok';
	@override String saveFailed({required Object error}) => 'Kaydedilemedi: ${error}';
	@override String deleteFailed({required Object error}) => 'Silinemedi: ${error}';
	@override late final _Translations$loggingControls$info$tr info = _Translations$loggingControls$info$tr._(_root);
}

// Path: formChrome
class _Translations$formChrome$tr extends Translations$formChrome$en {
	_Translations$formChrome$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(başlıksız)';
	@override String get showMore => 'Daha fazla göster';
	@override String get showAll => 'Tümünü göster';
	@override String get showFewer => 'Daha az göster';
	@override String get defaults => 'Varsayılanlar';
	@override String get search => 'Ara';
	@override String get clear => 'Temizle';
	@override String get openPage => 'Sayfayı aç';
	@override String get connected => 'Bağlı';
	@override String get notConnected => 'Bağlı Değil';
	@override String get manage => 'Yönet';
	@override String get connect => 'Bağlan';
	@override String get formTitle => 'Form';
	@override String addItem({required Object label}) => '${label} ekle';
	@override String editItem({required Object label}) => '${label} düzenle';
	@override String multiselectStatus({required Object total, required Object shown, required Object selected}) => '${total} öğeden ${shown} tanesi gösteriliyor (${selected} seçili)';
	@override String validationError({required Object error}) => 'Doğrulama hatası: ${error}';
	@override String transformationError({required Object error}) => 'Dönüştürme hatası: ${error}';
	@override String actionError({required Object error}) => 'Hata: ${error}';
	@override String get removeItem => 'Kaldır';
	@override String get storageUnavailable => 'Girişler kullanılamıyor';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$tr extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSO\'yu Düzenle';
	@override String get operatorCall => 'Operatör';
	@override String get position => 'Pozisyon';
	@override String get theirName => 'İsim';
	@override String get theirGrid => 'Grid';
	@override String get theirState => 'Eyalet';
	@override String get band => 'Bant';
	@override String get notes => 'Notlar';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Onların bilgisi';
	@override String get sectionOur => 'Bizim bilgimiz';
	@override String get sectionNotes => 'Notlar';
	@override String get theirCity => 'Şehir';
	@override String get theirCounty => 'İlçe';
	@override String get theirEntity => 'Varlık';
	@override String get theirCqZone => 'CQ Bölgesi';
	@override String get theirItuZone => 'ITU Bölgesi';
	@override String get theirArrlSection => 'ARRL Bölümü';
	@override String get theirLat => 'Enlem';
	@override String get theirLon => 'Boylam';
	@override String get theirPower => 'Onların gücü';
}

// Path: qsoList
class _Translations$qsoList$tr extends Translations$qsoList$en {
	_Translations$qsoList$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Henüz QSO yok — birini çalışın!';
	@override String get bandOrModeWarning => 'Lütfen bant ve modunuzun doğru olduğundan emin olun';
	@override String get today => 'Bugün';
	@override String get yesterday => 'Dün';
	@override String get tomorrow => 'Yarın';
}

// Path: loggingPanel
class _Translations$loggingPanel$tr extends Translations$loggingPanel$en {
	_Translations$loggingPanel$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Operasyon İstatistikleri';
	@override String get scoring => 'Puanlama';
	@override String get dxccEntities => 'DXCC varlıkları';
	@override String get statesWorked => 'Eyaletler';
	@override String get provincesWorked => 'İller';
	@override String get duplicates => 'Çift Kayıtlar';
}

// Path: callInfo
class _Translations$callInfo$tr extends Translations$callInfo$en {
	_Translations$callInfo$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Görüntüyü Göster';
	@override String get imageUnavailable => 'Fotoğraf kullanılamıyor';
	@override String get photo => 'Fotoğraf';
	@override String get notes => 'Notlar';
	@override String distanceTo({required Object distance}) => '${distance} mesafede:';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) mesafede:';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) mesafede:';
	@override String distanceAway({required Object distance}) => '${distance} uzakta';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) uzakta';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) uzakta';
	@override String get thisOpCountOne => 'Bu operasyonda 1 QSO';
	@override String thisOpCountOther({required Object count}) => 'Bu operasyonda ${count} QSO';
	@override String get otherOpsCountOne => 'Diğer operasyonlarda 1 QSO';
	@override String otherOpsCountOther({required Object count}) => 'Diğer operasyonlarda ${count} QSO';
	@override String andMore({required Object count}) => '… ve ${count} tane daha';
	@override String withCall({required Object call}) => '${call} ile';
	@override String fromOperation({required Object where}) => '${where} kaynaklı';
	@override late final _Translations$callInfo$history$tr history = _Translations$callInfo$history$tr._(_root);
}

// Path: settings
class _Translations$settings$tr extends Translations$settings$en {
	_Translations$settings$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ayarlar';
	@override String get language => 'Dil';
	@override String languageSystem({required Object language}) => 'Sistem ayarlarını izle (${language})';
	@override late final _Translations$settings$theme$tr theme = _Translations$settings$theme$tr._(_root);
	@override late final _Translations$settings$themeDescription$tr themeDescription = _Translations$settings$themeDescription$tr._(_root);
	@override String get fontScale => 'Yazı Tipi Ölçeği';
	@override late final _Translations$settings$fontScaleOpts$tr fontScaleOpts = _Translations$settings$fontScaleOpts$tr._(_root);
	@override late final _Translations$settings$keepDeviceAwake$tr keepDeviceAwake = _Translations$settings$keepDeviceAwake$tr._(_root);
	@override String get layoutDensity => 'Düzen Yoğunluğu';
	@override late final _Translations$settings$layoutDensityOpts$tr layoutDensityOpts = _Translations$settings$layoutDensityOpts$tr._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'pencere çok kısa, ${effective} kullanılıyor';
	@override String get layoutDensityAtLimit => 'sınırda';
	@override String get distanceUnits => 'Mesafe Birimleri';
	@override late final _Translations$settings$distanceUnitsOpts$tr distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$tr._(_root);
	@override String get userInterface => 'Kullanıcı Arayüzü';
	@override late final _Translations$settings$logging$tr logging = _Translations$settings$logging$tr._(_root);
	@override late final _Translations$settings$catServer$tr catServer = _Translations$settings$catServer$tr._(_root);
	@override late final _Translations$settings$radio$tr radio = _Translations$settings$radio$tr._(_root);
	@override late final _Translations$settings$help$tr help = _Translations$settings$help$tr._(_root);
	@override late final _Translations$settings$exports$tr exports = _Translations$settings$exports$tr._(_root);
	@override late final _Translations$settings$map$tr map = _Translations$settings$map$tr._(_root);
	@override late final _Translations$settings$privacy$tr privacy = _Translations$settings$privacy$tr._(_root);
	@override String get operatorCall => 'Operatör Çağrı İşareti';
	@override late final _Translations$settings$sync$tr sync = _Translations$settings$sync$tr._(_root);
	@override late final _Translations$settings$peers$tr peers = _Translations$settings$peers$tr._(_root);
	@override String get developerMode => 'Geliştirici Modu';
	@override late final _Translations$settings$syncPanel$tr syncPanel = _Translations$settings$syncPanel$tr._(_root);
	@override late final _Translations$settings$accounts$tr accounts = _Translations$settings$accounts$tr._(_root);
	@override late final _Translations$settings$station$tr station = _Translations$settings$station$tr._(_root);
	@override late final _Translations$settings$offlineData$tr offlineData = _Translations$settings$offlineData$tr._(_root);
	@override late final _Translations$settings$profiles$tr profiles = _Translations$settings$profiles$tr._(_root);
	@override late final _Translations$settings$search$tr search = _Translations$settings$search$tr._(_root);
	@override late final _Translations$settings$developer$tr developer = _Translations$settings$developer$tr._(_root);
	@override late final _Translations$settings$about$tr about = _Translations$settings$about$tr._(_root);
	@override late final _Translations$settings$panels$tr panels = _Translations$settings$panels$tr._(_root);
	@override String get showMoreSettings => 'Daha fazla ayar göster';
	@override String get gridPrecision => 'Grid Hassasiyeti';
	@override late final _Translations$settings$gridPrecisionOpts$tr gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$tr._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$tr gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$tr._(_root);
}

// Path: commands
class _Translations$commands$tr extends Translations$commands$en {
	_Translations$commands$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Önce Ayarlar\'dan senkronizasyonu etkinleştirin.';
	@override String get fullResyncStarted => 'Tam yeniden senkronizasyon başladı — yerel veriler önce yedeklendi.';
	@override String noDataFilesMatched({required Object target}) => '"${target}" ile eşleşen veri dosyası yok.';
	@override String reloadFailed({required Object error}) => 'Yeniden yükleme başarısız: ${error}';
	@override String get reloadingAll => 'Tüm veri dosyaları yeniden yükleniyor…';
	@override String reloadingTarget({required Object target}) => '${target} veri dosyaları yeniden yükleniyor…';
	@override String unknownExperiment({required Object token}) => 'Bilinmeyen deney "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} etkinleştirildi';
	@override String experimentDisabled({required Object name}) => '${name} devre dışı bırakıldı';
	@override String get sentryTestSent => 'Test hata raporu Sentry\'ye gönderildi';
	@override String get sentryTestLocalOnly => 'Bu sürümde Sentry devre dışı — test hatası yalnızca yerel olarak kaydedildi';
	@override String get noOperationOpen => 'Bu komut açık bir operasyon gerektirir';
	@override String unknownSegmentKind({required Object kind}) => '\'${kind}\' nasıl işaretleneceği bilinmiyor';
	@override String get operationAlreadyStarted => 'Bu operasyonun zaten bir başlangıç işareti var';
	@override String get couldNotOpenLocation => 'Ara eklendi, ancak konum ekranı açılamadı';
	@override String get noTestOperations => 'Temizlenecek Test Operasyonu yok';
	@override String get purgeTestsUnavailable => 'PURGETESTS bir onay penceresi göstermeli, ancak bu burada kullanılamıyor';
	@override String get syncAllUnavailable => 'SYNCALL bir onay penceresi göstermeli, ancak bu burada kullanılamıyor';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} Test Operasyonu temizlendi',
		other: '${count} Test Operasyonu temizlendi',
	);
	@override String purgeTestsSomeFailed({required Object total, required Object purged}) => '${total} Test Operasyonundan ${purged} tanesi temizlendi — geri kalanı başarısız oldu; PURGETESTS\'i tekrar deneyin';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Operasyonu olmayan ${count} test QSO\'su temizlendi',
		other: 'Operasyonu olmayan ${count} test QSO\'su temizlendi',
	);
	@override String get purgeTestsContactsFailed => 'Test Operasyonları temizlendi, ancak operasyonu olmayan test QSO\'ları başarısız oldu; PURGETESTS\'i tekrar deneyin';
	@override String get purgeTestsNothingToDo => 'Hiçbir şey temizlenmedi';
	@override String receivedPurgesSomeFailed({required Object total, required Object removed}) => '${total} Test Operasyonundan ${removed} tanesi kaldırıldı — geri kalanı başarısız oldu; İncele\'yi tekrar deneyin';
	@override String get receivedPurgesFailed => 'Bu Test Operasyonları kaldırılamadı — İncele\'yi tekrar deneyin';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} Test Operasyonu başka bir cihazda kaldırıldı',
		other: '${count} Test Operasyonu başka bir cihazda kaldırıldı',
	);
	@override String get receivedPurgesReview => 'İncele';
	@override String get settingOn => 'Açık';
	@override String get settingOff => 'Kapalı';
	@override String get settingEmpty => '(boş)';
	@override String get settingSecretSet => '(ayarlı)';
	@override String get settingSecretUnset => '(ayarlanmadı)';
	@override String settingSelectedCount({required Object count}) => '${count} seçili';
	@override String get settingExpectsOnOff => 'açık veya kapalı';
	@override String settingExpectsOneOf({required Object choices}) => 'şunlardan biri: ${choices}';
	@override String get settingExpectsNumber => 'bir sayı';
	@override String settingVanished({required Object label}) => '“${label}” artık kullanılamıyor';
	@override String get noCwKeyer => 'Bağlı hiçbir radyo CW gönderemiyor';
	@override String get noKeyer => 'Bağlı hiçbir radyo CW gönderemiyor veya ses hafızası oynatamıyor';
	@override String get keyerNeedsOperation => 'CW keyer\'ı kullanmak için bir operasyon açın';
	@override String get keyerExperimentOff => 'CW manipülasyonu kapalı — EXP KEYER ile açın';
	@override String get esmExperimentOff => 'Enter Mesaj Gönderir kapalı — EXP ESM ile açın';
	@override String cwSending({required Object text}) => 'CW gönderiliyor: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW mesajı F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW mesajı F${n} gönderilmedi: uzantılar hazır değil';
	@override String settingNotStored({required Object label}) => '“${label}” bu değeri kabul etmedi';
}

// Path: commandDialog
class _Translations$commandDialog$tr extends Translations$commandDialog$en {
	_Translations$commandDialog$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Çağrı işareti arayın veya bir komut yazın';
	@override String noResults({required Object text}) => '“${text}” ile eşleşen bir şey yok';
	@override String get sectionCommands => 'Komutlar';
	@override String get sectionGoTo => 'Git';
	@override String get sectionOperations => 'Operasyonlar';
	@override String get goHome => 'Ana Sayfa';
	@override String get goSettings => 'Ayarlar';
	@override String get goNewOperation => 'Yeni operasyon';
	@override String runTyped({required Object text}) => '“${text}” çalıştır';
	@override String get sectionSuggestions => 'Deneyin';
	@override String get lookingUp => 'Çağrı işareti sorgulanıyor…';
	@override String get blockedByPane => 'Bir panel veya pencere açıkken komutlar kullanılamaz';
}

// Path: expiredBuild
class _Translations$expiredBuild$tr extends Translations$expiredBuild$en {
	_Translations$expiredBuild$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bu sürümün süresi doldu';
	@override String get body => 'Lütfen ham2k.com adresini ziyaret edip daha yeni bir sürüm edinin.';
	@override String get visit => 'ham2k.com\'u ziyaret et';
	@override String get dismiss => 'Yine de devam et';
}

// Path: staleness
class _Translations$staleness$tr extends Translations$staleness$en {
	_Translations$staleness$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Önemli bir güncelleme bekliyor';
	@override String get codePushFloorBody => 'Bu sürümde henüz sizde olmayan bir düzeltme var.';
	@override String get restartToApply => 'Uygulamak için uygulamayı yeniden başlatın.';
	@override String get quitAndReopen => 'Uygulamak için uygulamadan çıkıp yeniden açın.';
	@override String get reopenToApply => 'Uygulamak için uygulamayı kapatıp yeniden açın.';
	@override String get ignoreForNow => 'Şimdilik yok say';
}

// Path: spotting
class _Translations$spotting$tr extends Translations$spotting$en {
	_Translations$spotting$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Spotlanacak kaydedilmiş QSO henüz yok.';
	@override String get setFrequencyFirst => 'Önce bir frekans ayarlayın.';
	@override String get nothingToSpot => 'Spotlanacak bir şey yok — burada hiçbir uzantı spotlama sunmuyor.';
	@override String spotFailed({required Object source, required Object message}) => '${source} başarısız: ${message}';
	@override String get unknownError => 'bilinmeyen hata';
	@override String get notSent => 'Spot gönderilmedi.';
	@override String get notRefreshedOffline => 'Bağlantı yok — spotlar yenilenmedi';
}

// Path: dataFiles
class _Translations$dataFiles$tr extends Translations$dataFiles$en {
	_Translations$dataFiles$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'İndiriliyor…';
	@override String downloadFailedTitle({required Object name}) => '${name} indirilemedi';
	@override String get downloadFailedWebHint => 'Bu bir ağ sorunu olabilir veya bu bağlantının sunucusu web tarayıcısından doğrudan indirmeyi desteklemiyor olabilir. Masaüstü veya mobil uygulamayı ya da farklı bir barındırma yerini deneyin.';
	@override String get downloadTimedOut => 'Sunucunun yanıt vermesi çok uzun sürdü. Daha sonra tekrar deneyin.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} bir hatayla yanıt verdi (HTTP ${status}). Daha sonra tekrar deneyin.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} bu dosyayı sağlayamadı (HTTP ${status}). Adresinin hâlâ doğru olduğunu kontrol edin.';
	@override String processingFailedTitle({required Object name}) => '${name} işlenemedi';
	@override String importTooSmall({required Object existing, required Object imported}) => 'İndirmede bu cihazdaki ${existing} kayıttan yalnızca ${imported} tanesi vardı, bu yüzden dışarıda bıraktıkları korundu. Ayarlar › Çevrimdışı Veri bölümünden yenilemek onu yine de kabul eder.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${label} için ${count} kayıt içe aktarıldı.',
		other: '${label} için ${count} kayıt içe aktarıldı.',
	);
	@override String importedData({required Object label}) => '${label} için veriler içe aktarıldı.';
	@override String get cleanedUpTitle => 'Uzantı verileri temizlendi';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Devre dışı uzantılara ait ${count} veri dosyasının verileri kaldırıldı.',
		other: 'Devre dışı uzantılara ait ${count} veri dosyasının verileri kaldırıldı.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} kayıt';
	@override String get definitionUnavailable => 'Dosyanın kaynağı bir tanım sağlamadı — uzantısı yeniden başlıyor veya yanlış yapılandırılmış olabilir. Birazdan tekrar deneyin.';
}

// Path: updates
class _Translations$updates$tr extends Translations$updates$en {
	_Translations$updates$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Güncelleme mevcut';
	@override String newVersionAvailable({required Object version}) => 'Yeni bir sürüm (${version}) mevcut.';
	@override String get getIt => 'Edinin';
	@override String get ok => 'Tamam';
	@override String get updateReady => 'Güncelleme hazır';
	@override String get restartToApply => 'Bir güncelleme indirildi. Uygulamak için yeniden başlatın.';
	@override String get appliesNextLaunch => 'Bir güncelleme indirildi. Uygulamayı bir sonraki açışınızda uygulanacak.';
	@override String get restartNow => 'Şimdi yeniden başlat';
	@override String get reloadToUpdate => 'Bu sayfanın daha yeni bir sürümü mevcut. Almak için yeniden yükleyin.';
	@override String get reloadNow => 'Şimdi yeniden yükle';
	@override String get checkForUpdates => 'Güncellemeleri Kontrol Et';
	@override String get checkingForUpdates => 'Güncellemeler kontrol ediliyor…';
	@override String get upToDate => 'Güncel';
	@override String get automaticChecks => 'Otomatik kontrol et';
	@override String get automaticChecksDescription => 'Uygulamayı bir sonraki başlatışınızdan itibaren arka planda yeni sürümleri ara';
}

// Path: extensionService
class _Translations$extensionService$tr extends Translations$extensionService$en {
	_Translations$extensionService$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Uzantı çalışma ortamı hazır değil.';
	@override String testFailed({required Object error}) => 'Test başarısız: ${error}';
	@override String connectedAs({required Object identity}) => '${identity} olarak bağlı';
	@override String get invalidFieldConfiguration => 'Geçersiz alan yapılandırması';
	@override String get invalidValue => 'Geçersiz değer';
	@override String validationError({required Object error}) => 'Doğrulama hatası: ${error}';
	@override String actionFailed({required Object error}) => 'Eylem başarısız: ${error}';
	@override String get commandFailed => 'Komut çalıştırılamadı';
	@override String get reportUnavailable => 'Raporlar şu anda gönderilemiyor';
	@override String get stashUnavailable => 'Ham2K File Stash\'e şu anda ulaşılamıyor';
	@override String timersSuspendedBudget({required Object name}) => '${name} zamanlayıcılarında çok fazla zaman harcadı. Uzantılar yeniden başlayana kadar durduruldular.';
	@override String timersSuspendedFailures({required Object name}) => '${name} zamanlayıcıları sürekli başarısız oldu. Uzantılar yeniden başlayana kadar durduruldular.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} bir zamanlayıcıda takıldı. Zamanlayıcıları uzantılar yeniden başlayana kadar durduruldu.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$tr extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operasyon Konumu';
	@override String get selectedLocation => 'Seçilen Konum';
	@override String get gridSquare => 'Maidenhead Grid Square Konum Bulucu';
	@override String get gridInvalid => 'FN31pr gibi 4, 6, 8 veya 10 karakter gerekir';
	@override String get suggestedLocations => 'Önerilen Konumlar';
	@override String get deviceGps => 'Cihaz GPS';
	@override String peerGps({required Object device}) => '${device} cihazından GPS';
	@override String get locating => 'Yer tespiti yapılıyor…';
	@override String get gpsUnavailable => 'Konum kullanılamıyor';
	@override String get permissionDenied => 'Konum izni reddedildi';
	@override String get permissionBlocked => 'Konum izni engellendi';
	@override String get moreDetails => 'Diğer Ayrıntılar';
	@override String get stateOrProvince => 'Eyalet veya İl (isteğe bağlı)';
	@override String get controlsUnavailableTitle => 'Aktivite kontrolleri kullanılamıyor';
	@override String get controlsUnavailableReason => 'Bu referanslar hâlâ kullanılabilir; yalnızca aktivitelerine ulaşılamadı.';
	@override String get controlsUnavailableRetry => 'Tekrar dene';
	@override String get county => 'İlçe (isteğe bağlı)';
}

// Path: versionLabel
class _Translations$versionLabel$tr extends Translations$versionLabel$en {
	_Translations$versionLabel$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Sürüm ${version}';
	@override String patch({required Object patch}) => 'Yama ${patch}';
	@override String build({required Object build}) => 'derleme ${build}';
}

// Path: notices
class _Translations$notices$tr extends Translations$notices$en {
	_Translations$notices$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Henüz bildirim yok';
	@override String get webStorageInMemory => 'Bu tarayıcı kalıcı depolama sağlayamadı — günlük yalnızca bellekte duruyor ve bu sekme kapandığında KAYBOLACAK. Güncel bir Chrome, Firefox, Safari veya Edge kullanın.';
	@override String get webStorageUnreliable => 'Bu tarayıcı birden fazla sekmeyle güvenli olmayan yedek bir depolama kullanıyor — tek bir sekme açık tutun ve senkronizasyonu açık bırakın.';
	@override String get logFromNewerBuildTitle => 'Bu günlük daha yeni bir sürüm gerektiriyor';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Günlüğünüz HaLo\'nun daha yeni bir sürümüyle yazılmış (depolama sürümü ${storage}; bu sürüm ${understood} sürümünü anlıyor), bu yüzden açılamıyor ve yeni QSO\'lar kaydedilmeyecek. Daha yeni sürümü yeniden yükleyin — ya da bu sürümü çalıştırmak istediyseniz onu farklı bir veri klasörüne yönlendirin. Günlük şurada: ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Günlüğünüz HaLo\'nun daha yeni bir sürümüyle yazılmış (depolama sürümü ${storage}; bu sürüm ${understood} sürümünü anlıyor), bu yüzden açılamıyor ve yeni QSO\'lar kaydedilmeyecek. Bunun yerine bu günlüğü o daha yeni sürümle açın.';
	@override String get preferencesRestoredTitle => 'Ayarlar bir yedekten geri yüklendi';
	@override String get preferencesRestored => 'Ayarlar dosyası okunamadı, bu yüzden HaLo onun son sağlam kopyasını geri yükledi. Önceki oturumunuzda değiştirdiğiniz şeyleri yeniden ayarlamanız gerekebilir. Okunamayan dosya, shared_preferences.corrupt-….json adıyla yanında saklanıyor.';
	@override String get preferencesResetTitle => 'Ayarlar sıfırlandı';
	@override String get preferencesReset => 'Ayarlar dosyası okunamadı ve geri dönülecek bir yedek yoktu, bu yüzden HaLo varsayılanlarıyla başladı. Okunamayan dosya, uygulamanın veri klasöründe shared_preferences.corrupt-….json adıyla saklanıyor.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} otomatik olarak bağlanmadı';
	@override String autoConnectHeld({required Object name}) => 'HaLo, ${name} cihazına son bağlanmaya başladığında yanıt vermeyi bıraktı, bu yüzden aynı şeyi tekrar riske atmak yerine bu kez ona dokunmadı. Radyonun açık ve kablosunun takılı olduğunu kontrol edin, ardından Ayarlar\'da onun için Bağlan\'a basın.';
}

// Path: syncAccount
class _Translations$syncAccount$tr extends Translations$syncAccount$en {
	_Translations$syncAccount$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Anonim Hesap (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (onay bekleniyor)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (onay bekleniyor - #${id})';
}

// Path: deepLink
class _Translations$deepLink$tr extends Translations$deepLink$en {
	_Translations$deepLink$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Önce bir operasyon başlatın, ardından o QSO\'yu tekrar gönderin';
	@override String get waitingInOperation => 'O QSO, bu ekranın arkasındaki operasyonda bekliyor';
	@override String unknownActivities({required Object refs}) => 'Bu cihazda ${refs} için aktivite yok, bu yüzden bu referanslar dışarıda bırakıldı';
	@override String activitiesUnavailable({required Object refs}) => 'Aktivitelerinize ulaşılamadı, bu yüzden ${refs} dışarıda bırakıldı — o bağlantıyı tekrar deneyin';
}

// Path: confirmDevice
class _Translations$confirmDevice$tr extends Translations$confirmDevice$en {
	_Translations$confirmDevice$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bir Cihazı Onayla';
	@override String get codePrompt => 'Bu hesaba katılmak isteyen cihazda gösterilen kodu girin.';
	@override String get code => 'Kod';
	@override String get lookUp => 'Sorgula';
	@override String get codeNotFound => 'Bu kodla eşleşen istek yok. Kodların süresi 10 dakika sonra dolar — diğer cihazdan yeni bir kod isteyin.';
	@override String get linkExpired => 'Bu bağlantının süresi doldu. Diğer cihazdan yeni bir QR kodu göstermesini isteyin.';
	@override String areYouSure({required Object device}) => '${device} bu hesaba bağlansın mı?';
	@override String get unnamedDevice => 'isimsiz bir cihaz';
	@override String get grantWarning => 'Bu hesaptaki her operasyonu ve QSO\'yu okuyabilecek ve değiştirebilecek.';
	@override String get needsSyncTitle => 'Bu cihaz henüz senkronize olmuyor';
	@override String get needsSyncText => 'Başka bir cihazı kabul edebilmesi için Ham2K Log Filer senkronizasyonunu açın ve bu cihazı bir hesaba bağlayın.';
	@override String get malformedRequest => 'Senkronizasyon sunucusu bu uygulamanın okuyamadığı bir istek gönderdi. Diğer cihazdan tekrar denemesini isteyin.';
	@override String get linkIt => 'Cihazı Bağla';
}

// Path: switchAccounts
class _Translations$switchAccounts$tr extends Translations$switchAccounts$en {
	_Translations$switchAccounts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Henüz hesap ayrıntısı yok';
	@override String get currentAccount => 'Mevcut hesap';
	@override String get otherAccounts => 'Diğer hesaplar';
	@override String get linkToAnother => 'Başka bir hesaba bağla';
	@override String get linkWithSibling => 'Başka bir Ham2K uygulamasıyla bağla';
	@override String get linkWithPolo => 'Eski sürümdeki hesapla bağla';
	@override String get linkWithSiblingDescription => 'Yüklü başka bir Ham2K uygulamanız var. Orada kullanılan hesapla bağlayın.';
	@override String siblingPrompt({required Object app}) => 'İsteği ${app} içinde onaylayın, ardından buraya geri dönün.';
	@override String openSiblingAgain({required Object app}) => '${app} uygulamasını yeniden aç';
	@override String get siblingNoGrant => 'Olmadı mı? Yeniden açın ya da geri dönüp başka bir yolla bağlayın.';
	@override String siblingOpenFailed({required Object app}) => '${app} açılamadı.';
	@override String siblingLinkRenewed({required Object app}) => 'Bağlantının süresi doldu ve yenisi hazır — ${app} uygulamasını yeniden açın.';
	@override String get tryAgain => 'Tekrar dene';
	@override String get linkWithQr => 'QR koduyla bağla';
	@override String get linkWithQrDescription => 'Hesabı zaten kullanan bir cihazdan tarayın';
	@override String get linkWithEmail => 'E-posta adresiyle bağla';
	@override String get linkWithEmailDescription => 'Bir kod veya e-posta bağlantısıyla onaylayın';
	@override String get enterEmailPrompt => 'Bu cihazın kullanmasını istediğiniz hesabın e-posta adresini girin.';
	@override String get emailAddress => 'E-posta adresi';
	@override String get linkAccount => 'Hesabı bağla';
	@override String get copiedCode => 'Kod panoya kopyalandı';
	@override String get copyCode => 'Kodu kopyala';
	@override String codePrompt({required Object email}) => '${email} ile zaten bağlı bir cihazda Ham2K uygulamasını açın ve isteği onaylamak için bu kodu girin:';
	@override String get waitingForConfirmation => 'Onay bekleniyor…';
	@override String get sendEmailInstead => 'Bunun yerine onay e-postası gönder';
	@override String emailSent({required Object email}) => '${email} adresine bir e-posta gönderildi. Bu cihazı bağlamak için e-postayı açıp isteği onaylayın.';
	@override String get resendEmail => 'E-postayı yeniden gönder';
	@override String get qrPrompt => 'Bu QR kodunu, istediğiniz hesaba zaten bağlı bir cihazdan tarayın — örneğin telefonunuzdaki Ham2K Portable Logger ile.';
	@override String get serverUnreachable => 'Senkronizasyon sunucusuna ulaşılamadı. Daha sonra tekrar deneyin.';
	@override String get emailRequired => 'Bağlamak için bir e-posta adresi girin.';
	@override String noAccountForEmail({required Object email}) => '${email} için hesap bulunamadı.';
	@override String serverRejected({required Object error}) => 'Senkronizasyon sunucusu isteği reddetti: ${error}';
	@override String get noLinkCode => 'Senkronizasyon sunucusu bir bağlantı kodu döndürmedi. Daha sonra tekrar deneyin.';
	@override String get noConfirmationCode => 'Senkronizasyon sunucusu bir onay kodu göndermedi. Daha sonra tekrar deneyin.';
	@override String get switchNotAccepted => 'Bu hesap geçişi kabul etmedi. Bunun yerine bir e-posta adresiyle bağlamayı deneyin.';
	@override String get requestFailed => 'Senkronizasyon sunucusuyla iletişimde bir şeyler ters gitti. Daha sonra tekrar deneyin.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} QSO',
		other: '${count} QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} operasyon',
		other: '${count} operasyon',
	);
}

// Path: adifImport
class _Translations$adifImport$tr extends Translations$adifImport$en {
	_Translations$adifImport$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'ADIF\'ten QSO İçe Aktar';
	@override String reading({required Object filename}) => '${filename} okunuyor…';
	@override String get dropHint => 'İçe aktarmak için bir ADIF dosyası bırakın';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Bu dosyada ${count} QSO',
		other: 'Bu dosyada ${formatted} QSO',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesi zaten günlüğünüzde',
		other: '${formatted} tanesi zaten günlüğünüzde',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesi içe aktarılacak',
		other: '${formatted} tanesi içe aktarılacak',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} yeni QSO',
		other: '${formatted} yeni QSO',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesi mevcut bir QSO ile birleşecek',
		other: '${formatted} tanesi mevcut QSO\'larla birleşecek',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesi içe aktarılamaz (çağrı işareti yok)',
		other: '${formatted} tanesi içe aktarılamaz (çağrı işareti yok)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesinin daha yakından incelenmesi gerekiyor',
		other: '${formatted} tanesinin daha yakından incelenmesi gerekiyor',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} QSO için referanslar kurtarılamadı',
		other: '${formatted} QSO için referanslar kurtarılamadı',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} QSO için ${programs} referansları eksik olabilir',
		other: '${formatted} QSO için ${programs} referansları eksik olabilir',
	);
	@override String get stackingTypesUnknown => 'Birleştirilen QSO\'lar bir referansı kaybedebilir — aktiviteler hangi türlerin üst üste eklenebildiğini bildiremedi. Bunu önlemek için iptal edip yeniden deneyin.';
	@override String get nothingToImport => 'Bu dosyada içe aktarılabilecek bir şey yok';
	@override String get confirm => 'İçe Aktar';
	@override String importing({required Object filename}) => '${filename} içe aktarılıyor…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${filename} dosyasından ${count} QSO içe aktarıldı',
		other: '${filename} dosyasından ${formatted} QSO içe aktarıldı',
	);
	@override String failed({required Object filename, required Object error}) => '${filename} içe aktarılamadı: ${error}';
	@override String notAdif({required Object filename}) => '${filename} bir ADIF dosyasına benzemiyor';
	@override String stationWarning({required Object calls, required Object station}) => 'Uyarı: bu ADIF\'te ${calls} çağrılarına ait QSO\'lar var, ancak devam ederseniz ${station} olarak içe aktarılacaklar.';
	@override String get stationCallJoin => ' ve ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} tanesinin tarihi yok ve içe aktarılamaz',
		other: '${formatted} tanesinin tarihi yok ve içe aktarılamaz',
	);
	@override String activationFound({required Object refs}) => 'Bu dosya ${refs} aktivasyonunu kaydediyor.';
	@override String get addActivation => 'Bu operasyona ekle';
	@override String shortfall({required Object planned, required Object written}) => '${planned} kayıttan yalnızca ${written} tanesi uygulanabildi — siz karar verirken günlük değişti.';
	@override String get busy => 'Zaten bir içe aktarma çalışıyor. Başka birini başlatmadan önce bitmesini bekleyin.';
	@override String get oneFileOnly => 'Her seferinde bir ADIF dosyası bırakın — dosyaların içe aktarılma sırası hangi verinin geçerli olacağını belirler.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} dosyasında ${limit} QSO\'dan fazla var; bir operasyon tek seferde en fazla bu kadarını içe aktarabilir.';
}

// Path: offline
class _Translations$offline$tr extends Translations$offline$en {
	_Translations$offline$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'İnternet: ÇEVRİMDIŞI';
	@override String get statusOnline => 'İnternet: bağlı';
	@override String get noRoute => 'Hiç ağ bağlantısı yok.';
	@override String get unreachable => 'Ağ açık, ancak hiçbir sunucu yanıt vermiyor — çoğu zaman bir tarayıcıda bekleyen bir giriş sayfasının işareti.';
	@override String get reachable => 'Tüm hizmetler beklendiği gibi yanıt veriyor.';
	@override String get whatStops => 'Sorgular, spotlar ve veri dosyaları duraklatıldı. Kayıt ve yakındaki cihazlarla senkronizasyon duraklatılmadı.';
	@override String get servicesTitle => 'Hizmetler';
	@override String get noServices => 'Henüz hiçbir hizmet durum bildirmedi.';
	@override String lastSuccess({required Object when}) => 'Son yanıt ${when} önce';
	@override String get neverSucceeded => 'Henüz yanıt vermedi';
	@override String nextAttempt({required Object when}) => 'Sonraki deneme ${when} sonra';
	@override String get nextAttemptNow => 'Sonraki deneme zamanı geldi';
	@override String get retry => 'Şimdi tekrar dene';
	@override String get retrying => 'Deneniyor…';
	@override String get retryReached => 'Yeniden çevrimiçi.';
	@override String get retryUnreachable => 'Hâlâ yanıt yok.';
	@override String get retryNotAttempted => 'Şu anda gönderilecek bir şey yok.';
	@override String get retryThrottled => 'Az önce denendi — biraz bekleyin.';
	@override String get retryDisabled => 'Senkronizasyon kapalı, bu yüzden yoklama yapılacak bir şey yok.';
	@override String get syncService => 'Ham2K LoFi senkronizasyonu';
	@override String get retryInFlight => 'Zaten deneniyor — bekleyin.';
}

// Path: exportSettings
class _Translations$exportSettings$tr extends Translations$exportSettings$en {
	_Translations$exportSettings$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Tüm dışa aktarımlar için temel ayarlar; referans aktiviteleri ve diğer aktiviteler için ayrı dosya adı ve başlık şablonlarıyla. Her dışa aktarma türü kendi varsayılanlarını veya özel ayarlarını sağlayabilir.';
	@override String get referenceActivities => 'Referans Aktiviteleri';
	@override String get otherActivities => 'Diğer Aktiviteler';
	@override String get adifFields => 'ADIF Alanları';
	@override String get loadFailed => 'Dışa aktarma ayarları yüklenemedi.';
	@override String get retry => 'Tekrar dene';
	@override String get compactFileNamesDescriptionOn => 'Kısa dosya adları, örneğin N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Açıklayıcı dosya adları, örneğin 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'ADIF dosyalarına isimler, adresler, e-postalar, notlar ve kesin konumlar dahil ediliyor.';
	@override String get includePrivateDataDescriptionOff => 'İsimler, adresler, e-postalar ve notlar çıkarılıyor; konumlar altı karakterli grid\'lerle sınırlanıyor.';
	@override String get includeLookupDataDescriptionOn => 'Çağrı işareti sorgu hizmetlerinden gelen bilgiler dahil ediliyor.';
	@override String get includeLookupDataDescriptionOff => 'Çağrı işareti sorgu hizmetlerinden gelen bilgiler çıkarılıyor; elle girilen değerler korunuyor.';
	@override String get customTemplatesDescriptionOn => 'Özel şablonlarınız etkin ve aşağıda düzenlenebilir.';
	@override String get customTemplatesDescriptionOff => 'Varsayılan şablonlar etkin. Özel şablonlarınız daha sonrası için saklanıyor.';
	@override String get type => 'Dışa aktarma türü';
	@override String get defaults => 'Varsayılanlar';
	@override String get includeLookupData => 'Sorgu verilerini dahil et';
	@override String get customTemplates => 'Özel şablonlar';
	@override String get filenameTemplate => 'Dosya adı şablonu';
	@override String get compactFilenameTemplate => 'Kısa dosya adı şablonu';
	@override String get titleTemplate => 'Başlık şablonu';
	@override String get adifNotesTemplate => 'ADIF QSO Notları';
	@override String get adifCommentTemplate => 'ADIF QSO Yorumları';
	@override String get adifQslMessageTemplate => 'ADIF QSL Mesajı';
	@override String get shared => 'Ayarlar, bu dışa aktarma türünü kullanan her uzantıya uygulanır.';
	@override String get defaultTemplates => 'Bu türün şablonlarını düzenlemek için Özel şablonlar\'ı açın.';
}

// Path: templateEditor
class _Translations$templateEditor$tr extends Translations$templateEditor$en {
	_Translations$templateEditor$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Önizleme:';
	@override String get reset => 'Sıfırla';
	@override String get docs => 'Şablon Belgeleri';
	@override String get preview => 'Örnek önizleme';
	@override String get reference => 'Şablon referansı';
	@override String get attributes => 'Kullanılabilir Öznitelikler';
	@override String get filters => 'Filtreler';
	@override String get flowControl => 'Akış Kontrolü';
	@override String get unavailable => 'Uzantılar hazır olana kadar önizleme kullanılamaz.';
	@override String get empty => '(boş çıktı)';
}

// Path: home.nav
class _Translations$home$nav$tr extends Translations$home$nav$en {
	_Translations$home$nav$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operasyonlar';
	@override String get chase => 'Avlama';
	@override String get logs => 'Günlükler';
	@override String get maps => 'Haritalar';
	@override String get settings => 'Ayarlar';
}

// Path: home.panels
class _Translations$home$panels$tr extends Translations$home$panels$en {
	_Translations$home$panels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operasyon Listesi';
	@override String get operationsDescription => 'Operasyonlarınız, en yenisi önce.';
	@override String get version => 'Mevcut Sürüm';
	@override String get versionDescription => 'Ham2K logosu, bu uygulamanın adı ve çalıştırdığınız sürüm.';
}

// Path: home.logs
class _Translations$home$logs$tr extends Translations$home$logs$en {
	_Translations$home$logs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Günlükler';
	@override String get titleFor => 'Günlükler:';
	@override String get emptyCallsigns => 'Henüz kaydedilmiş QSO yok';
	@override String emptyQsos({required Object call}) => '${call} için QSO yok';
	@override String get mapNoSelection => 'Haritada görmek için bir QSO seçin';
	@override String get searchHint => 'Çağrı işareti veya isim ara';
	@override String get noSearchMatches => 'Aramanızla eşleşen QSO yok';
	@override String get titleAll => 'Tüm Günlükler';
	@override String get allCallsigns => 'Tüm çağrı işaretleri';
	@override String get noOperation => 'Bir operasyona ait değil';
	@override String get unsavedTitle => 'Kaydedilmemiş değişiklikler';
	@override String get unsavedBody => 'Bu QSO\'da kaydetmediğiniz değişiklikler var.';
	@override String get pendingDeleteBody => 'Bu QSO silinmek üzere işaretlendi.';
	@override String get editGone => 'Kaydedilmedi: o QSO artık bu günlükte değil.';
	@override String get discard => 'Vazgeç';
	@override late final _Translations$home$logs$columns$tr columns = _Translations$home$logs$columns$tr._(_root);
	@override late final _Translations$home$logs$panels$tr panels = _Translations$home$logs$panels$tr._(_root);
	@override late final _Translations$home$logs$import$tr import = _Translations$home$logs$import$tr._(_root);
}

// Path: chase.station
class _Translations$chase$station$tr extends Translations$chase$station$en {
	_Translations$chase$station$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Avcı İstasyon';
	@override String get stationLabel => 'İstasyon: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Konum yok';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$tr extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get today => 'bugün';
	@override String get thisWeek => 'bu hafta';
	@override String get last14Days => 'son 14 günde';
	@override String get thisMonth => 'bu ay';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$tr extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Bugünün istatistikleri';
	@override String get thisWeek => 'Bu haftanın istatistikleri';
	@override String get last14Days => 'Son 14 günün istatistikleri';
	@override String get thisMonth => 'Bu ayın istatistikleri';
}

// Path: chase.period
class _Translations$chase$period$tr extends Translations$chase$period$en {
	_Translations$chase$period$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Bugün';
	@override String get thisWeek => 'Bu Hafta';
	@override String get last14Days => 'Son 14 Gün';
	@override String get thisMonth => 'Bu Ay';
}

// Path: chase.goals
class _Translations$chase$goals$tr extends Translations$chase$goals$en {
	_Translations$chase$goals$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Avlama Hedefleri';
	@override String remove({required Object name}) => '${name} avlamayı bırak';
	@override String get extensionsTitle => 'Avlama içeren uzantılar';
}

// Path: chase.panels
class _Translations$chase$panels$tr extends Translations$chase$panels$en {
	_Translations$chase$panels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO\'lar';
	@override String get loggingDescription => 'Dönem içinde avlanan QSO\'ların üstünde kayıt kontrolleri.';
	@override String get info => 'Bilgi';
	@override String get infoDescription => 'Kaydedilen çağrı işareti veya dönemin istatistikleri.';
	@override String get spots => 'Spotlar';
	@override String get spotsDescription => 'Havada spotlanmış, avlanmaya hazır istasyonlar.';
	@override String get map => 'Harita';
	@override String get mapDescription => 'Dönemin QSO\'ları ve kaydedilen istasyon.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$tr extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Geçersiz çağrı işareti: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Geçersiz çağrı işaretleri: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'Şimdiye kadar ${previous} operatörlük yaptı. Yeni QSO\'lar için ${typed} kaydedilecek.';
	@override String operatorNoneSoFar({required Object typed}) => 'Şimdiye kadar operatör kaydedilmedi. Yeni QSO\'lar için ${typed} kaydedilecek.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Bu operasyonda zaten ${calls} tarafından yapılmış QSO\'lar var. ${typed} yalnızca yenileri için kaydedilecek.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${typed} çağrısını önceden kaydedilmiş QSO\'nun operatörü olarak da kaydet',
		other: '${typed} çağrısını önceden kaydedilmiş ${count} QSO\'nun tümünün operatörü olarak da kaydet',
	);
	@override String get operatorSeveralStations => 'Havada birden fazla istasyon kullanılırken ayrı operatörler desteklenmez';
	@override String get contactsUnreadable => 'Bu operasyonun QSO\'ları okunamadı, bu yüzden burada çağrı işaretini değiştirmek onları güncellemeyi önermeyecek';
	@override String restampFailed({required Object error}) => 'Önceden kaydedilmiş QSO\'lar güncellenemedi, bu yüzden hiçbir değişiklik yapılmadı: ${error}';
	@override String restampShortfall({required Object planned, required Object written}) => '${planned} QSO\'dan ${written} tanesi güncellendi — geri kalanı artık bu operasyonda değil';
}

// Path: operation.tabs
class _Translations$operation$tabs$tr extends Translations$operation$tabs$en {
	_Translations$operation$tabs$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => 'BİLGİ';
	@override String get spots => 'SPOTLAR';
	@override String get map => 'HARİTA';
	@override String get qsosPlain => 'QSO\'lar';
	@override String get clock => 'Saat';
	@override String get weather => 'Hava Durumu';
	@override String get website => 'Web Sitesi';
	@override String get remoteScreen => 'Uzak Ekran';
	@override String get solar => 'Güneş';
	@override String get radio => 'Radyo';
}

// Path: operation.positions
class _Translations$operation$positions$tr extends Translations$operation$positions$en {
	_Translations$operation$positions$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Henüz bu operasyonu paylaşan başka operasyon pozisyonu yok.';
	@override String positionLabel({required Object number}) => 'Poz: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Başka bir pozisyon';
	@override String get thisDevice => 'Bizim operasyon pozisyonumuz';
	@override String get nameIn => ' — ';
	@override String get panelTitle => 'Pozisyonlar';
	@override String get panelDescription => 'Bu operasyonu paylaşan her operasyon pozisyonunun şu anda ne kaydettiği.';
}

// Path: operation.menu
class _Translations$operation$menu$tr extends Translations$operation$menu$en {
	_Translations$operation$menu$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'RST alanlarını göster';
	@override String get showStateField => 'Eyalet alanını göster';
	@override String get showGridField => 'Grid alanını göster';
	@override String get showDeletedQsos => 'Silinen QSO\'ları göster';
	@override String get showDeletedOps => 'Silinen operasyonları göster';
	@override String get showQsoNumbers => 'QSO Numaralarını Göster';
	@override String get lookupAllQsos => 'Tüm QSO\'ları sorgula';
	@override String get loggingSettingsTitle => 'Kayıt Ayarları';
	@override String get mapSettingsTitle => 'Harita Ayarları';
	@override String get actionsSection => 'Eylemler';
}

// Path: operation.layout
class _Translations$operation$layout$tr extends Translations$operation$layout$en {
	_Translations$operation$layout$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Panel Ekle';
	@override String get availableSection => 'Kullanılabilir paneller';
	@override String panelSettings({required Object panel}) => '${panel} ayarları';
	@override String get panelSettingsAction => 'Panel Ayarları';
	@override String get viewName => 'Operasyon Görünümü';
	@override String get viewOptions => 'Görünüm düzeni seçenekleri';
	@override String get viewTitleBuiltIn => 'Bu görünüm uygulamaya yerleşiktir, adı da öyle';
	@override String get resetOptions => 'Varsayılanları Geri Yükle';
	@override String get removePane => 'Kaldır';
	@override String resetPaneConfirm({required Object panel}) => '${panel} varsayılanlarına döndürülsün mü?';
	@override String get resetPaneConfirmBody => 'Başlığı, üst bilgisi ve boyutu varsayılanlara döner. Düzenin geri kalanı olduğu gibi kalır.';
	@override String get resetViewConfirm => 'Bu görünüm varsayılan düzenine döndürülsün mü?';
	@override String get resetViewConfirmBody => 'Paneller varsayılan yerleşimine döner; görünümün ve her panelin seçenekleri de varsayılanlara döner.';
	@override String paneOptionsTitle({required Object panel}) => '${panel} Düzen Ayarları';
	@override String get paneTitle => 'Başlık';
	@override String get paneShowHeader => 'Üst bilgiyi göster';
	@override String get paneShowHeaderTabset => 'Bu bölme bir grubu paylaştığı sürece her zaman gösterilir — diğerlerine üst bilgiden ulaşılır';
	@override String get paneInherit => 'Uygulamayla aynı';
	@override String get searchHint => 'Panellerde ara';
	@override String get noPanelsMatch => 'Aramanızla eşleşen panel yok.';
	@override String get nothingToAdd => 'Bu görünümde zaten tüm olası paneller var';
	@override String addPanel({required Object panel}) => '${panel} ekle';
	@override String showPreview({required Object panel}) => '${panel} önizlemesi';
	@override String missingExtension({required Object name}) => '"${name}" uzantısı eksik';
	@override String get previewUnavailable => 'Bu panelin önizleme görüntüsü gösterilemedi.';
	@override String get nestedPaneTitle => 'Diğer';
	@override String get editLayout => 'Düzeni Düzenle';
	@override String get saveLayout => 'Düzeni Kaydet';
	@override String get revertLayout => 'Düzen değişikliklerini at';
	@override String get done => 'Tamamlandı';
	@override String get layoutUnreadableTitle => 'Düzen okunamadı';
	@override String get layoutUnreadableBody => 'Kayıtlı düzeniniz okunamadı, bu yüzden yerine varsayılan yerleşim gösteriliyor. Siz saklamayı seçene kadar orijinalinizin üzerine kaydedilmez.';
	@override String get layoutUnreadableAction => 'Bu düzeni kullan';
	@override String panelRenderFailed({required Object panel}) => '${panel} görüntülenemedi';
	@override String get panelRenderRetry => 'Tekrar dene';
	@override String get panelActionFailed => 'Bu panel eylemi başarısız oldu. Tekrar deneyin.';
	@override late final _Translations$operation$layout$panels$tr panels = _Translations$operation$layout$panels$tr._(_root);
	@override String get htmlPanelUnsupported => 'Bu panel, bu platformun sağlamadığı bir web görünümü gerektirir';
	@override String get htmlPanelUnsupportedOnWeb => 'Bu panel, web sürümünün sağlayamadığı bir korumalı alan gerektirir';
}

// Path: operation.export
class _Translations$operation$export$tr extends Translations$operation$export$en {
	_Translations$operation$export$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operasyon Dışa Aktarımları';
	@override String get syncedOperation => 'Operasyon senkronize edildi';
	@override String get unsyncedOperation => 'Operasyonda senkronize edilmemiş değişiklikler var';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Bu operasyonda ${count} QSO',
		other: 'Bu operasyonda ${count} QSO',
	);
	@override String qsosSynced({required Object total}) => '${total} QSO\'nun tümü senkronize edildi';
	@override String qsosPending({required Object total, required Object pending}) => '${total} QSO\'dan ${pending} tanesi senkronizasyon bekliyor';
	@override String eventsSynced({required Object total}) => '${total} olay işareti senkronize edildi';
	@override String eventsPending({required Object total, required Object pending}) => '${total} olay işaretinden ${pending} tanesi bekliyor';
	@override String get loading => 'Dışa aktarma seçenekleri yükleniyor…';
	@override String get noOptions => 'Kullanılabilir dışa aktarma biçimi yok (uzantı çalışma ortamı hâlâ başlıyor olabilir mi?)';
	@override String get nothingLogged => 'Henüz dışa aktarılacak bir şey yok — bu operasyonda QSO yok.';
	@override String get share => 'Paylaş';
	@override String get nothingSelected => 'Hiçbir şey seçilmedi';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosyayı kaydet',
		other: '${count} dosyayı kaydet',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosyayı paylaş',
		other: '${count} dosyayı paylaş',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosyayı dışa aktar',
		other: '${count} dosyayı dışa aktar',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosyayı indir',
		other: '${count} dosyayı indir',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Birleştirilmiş ${count} dosyayı kaydet',
		other: 'Birleştirilmiş ${count} dosyayı kaydet',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Birleştirilmiş ${count} dosyayı paylaş',
		other: 'Birleştirilmiş ${count} dosyayı paylaş',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Birleştirilmiş ${count} dosyayı dışa aktar',
		other: 'Birleştirilmiş ${count} dosyayı dışa aktar',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Birleştirilmiş ${count} dosyayı indir',
		other: 'Birleştirilmiş ${count} dosyayı indir',
	);
	@override String saveOne({required Object name}) => '${name} dosyasını kaydet';
	@override String shareOne({required Object name}) => '${name} dosyasını paylaş';
	@override String exportOne({required Object name}) => '${name} dosyasını dışa aktar';
	@override String downloadOne({required Object name}) => '${name} dosyasını indir';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosyayı Stash\'e kaydet',
		other: '${count} dosyayı Stash\'e kaydet',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Birleştirilmiş ${count} dosyayı Stash\'e kaydet',
		other: 'Birleştirilmiş ${count} dosyayı Stash\'e kaydet',
	);
	@override String get settingsButton => 'Dışa aktarma ayarları';
	@override String get settingsTitle => 'Dışa Aktarma Ayarları';
	@override late final _Translations$operation$export$compactFileNames$tr compactFileNames = _Translations$operation$export$compactFileNames$tr._(_root);
	@override late final _Translations$operation$export$includePrivateData$tr includePrivateData = _Translations$operation$export$includePrivateData$tr._(_root);
	@override String get resultTitle => 'Dışa aktarma tamamlandı';
	@override String get resultFailedTitle => 'Dışa aktarma başarısız';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosya ${path} konumuna aktarıldı',
		other: '${count} dosya ${path} konumuna aktarıldı',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosya aktarıldı: ${path}',
		other: '${count} dosya aktarıldı: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosya paylaşıldı',
		other: '${count} dosya paylaşıldı',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosya indirildi',
		other: '${count} dosya indirildi',
	);
	@override String exportFailed({required Object error}) => 'Dışa aktarma başarısız: ${error}';
	@override late final _Translations$operation$export$stash$tr stash = _Translations$operation$export$stash$tr._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$tr extends Translations$operation$spots$en {
	_Translations$operation$spots$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Filtrelerinizle eşleşen spot yok';
	@override String error({required Object error}) => 'Spotlar yüklenemedi: ${error}';
	@override String get unknownBand => 'Diğer';
	@override String get auto => 'Otomatik';
	@override String autoValue({required Object value}) => 'Otomatik (Şu anda ${value})';
	@override String valueAuto({required Object value}) => '${value} (Oto)';
	@override String get any => 'Herhangi';
	@override String get allBands => 'Tüm Bantlar';
	@override String get allModes => 'Tüm Modlar';
	@override String get phoneAndCw => 'Telefon ve CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} spot',
		other: '${count} spot',
	);
	@override String spotsCountFiltered({required Object total, required Object count}) => '${total} spottan ${count} tanesi gösteriliyor';
	@override String ageMinutes({required Object minutes}) => '${minutes} dakika';
	@override String get callsOfNote => 'Notlu Çağrılar';
	@override String get yourSpots => 'Spotlarınız';
	@override String get allSpots => 'Tüm Spotlar';
	@override late final _Translations$operation$spots$continents$tr continents = _Translations$operation$spots$continents$tr._(_root);
	@override late final _Translations$operation$spots$filters$tr filters = _Translations$operation$spots$filters$tr._(_root);
	@override String get unavailableTitle => 'Spotlar kullanılamıyor';
	@override String unavailableText({required Object sources}) => '${sources} yanıt vermedi.';
	@override String get failedTitle => 'Spot kaynağı hatası';
	@override String failedText({required Object sources}) => '${sources} bir hata döndürdü.';
	@override String get slideLogIt => 'Kaydet';
	@override String get slideIgnore => 'Yok say';
	@override String get slideRestore => 'Geri getir';
	@override late final _Translations$operation$spots$logConflict$tr logConflict = _Translations$operation$spots$logConflict$tr._(_root);
}

// Path: operation.import
class _Translations$operation$import$tr extends Translations$operation$import$en {
	_Translations$operation$import$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operasyona Veri İçe Aktar';
	@override String get importAdifAction => 'ADIF\'ten QSO İçe Aktar';
	@override String get settingsButton => 'Dinleme ayarları';
	@override String get settingsTitle => 'Diğer Uygulamaları Dinle';
	@override String get protocolAddressLabel => 'Adres';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => '1 ile 65535 arasında bir port girin';
	@override String get protocolAddressInvalid => 'Geçerli bir IP adresi girin (örn. 127.0.0.1 veya 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Veri alınıyor';
	@override String get protocolStatusNoData => 'Son zamanlarda veri alınmadı';
	@override String protocolBindError({required Object error}) => 'Dinleme başlatılamadı: ${error}';
	@override String captureFailed({required Object error}) => 'Gelen QSO\'lar kaydedilemedi ve yeniden deneniyor: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Herhangi (yayın)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Broadcast Data sekmesi → QSO bilgisi için "Enable Broadcasts" seçeneğini işaretleyin. Aynı bilgisayarda çalışıyorsa IP adresini 127.0.0.1, mevcut yerel ağda yayın yapmak için 255.255.255.255 olarak ayarlayın.';
	@override String get helpWsjtxSetup => 'File → Settings → Reporting sekmesi → UDP Server bölümü → "Accept UDP requests" seçeneğini işaretleyin. Aynı bilgisayarda çalışıyorsa UDP Server\'ı 127.0.0.1 veya 239.239.0.2 gibi bir çoklu yayın adresine ayarlayın ve bu uygulamadaki yukarıdaki yapılandırmada aynı adresi kullanın.';
	@override String get listenTitle => 'Diğer uygulamalardan QSO dinle';
	@override String get listenDescriptionOnN1mm => 'N1MM+ dinleniyor';
	@override String get listenDescriptionOnWsjtx => 'WSJT-X dinleniyor';
	@override String get listenDescriptionOnBoth => 'N1MM+ ve WSJT-X dinleniyor';
	@override String get listenDescriptionOff => 'Kapalı';
	@override String get addToOperationTitle => 'Bu operasyona ekle';
	@override String get addToOperationDescriptionOn => 'Yakalanan QSO\'lar geldikçe bu operasyona eklenir';
	@override String get addToOperationDescriptionOff => 'Yakalanan QSO\'lar siz bunu açana kadar bekletilir';
	@override String get pendingSectionTitle => 'Yakalanan QSO\'lar';
	@override String get pendingEmpty => 'Henüz bir şey yakalanmadı';
	@override String stationMismatch({required Object call}) => '${call} olarak kaydedildi, bu operasyonun istasyonu değil';
	@override String get discardAction => 'At';
	@override String get gapDialogTitle => 'Önceki yakalamalar dahil edilsin mi?';
	@override String gapDialogBody({required Object count}) => 'Verideki bir boşluktan önce ${count} QSO daha yakalandı. Onlar da dahil edilsin mi?';
	@override String get gapDialogRecentOnly => 'Yalnızca son olanlar';
	@override String gapDialogIncludeAll({required Object count}) => '${count} QSO\'nun tümünü dahil et';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$tr extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get link => 'Sorun mu var?';
	@override String get title => 'Sınır çizgisi sorunu bildir';
	@override String get reference => 'Hangi sınır';
	@override String get severity => 'Ne kadar kötü?';
	@override String get minor => 'Küçük bir kusur';
	@override String get major => 'Büyük sorun';
	@override String get explanation => 'Sorun ne?';
	@override String get explanationHint => 'Sınırın neyi yanlış gösterdiği ve nerede';
	@override String get send => 'Gönder';
	@override String get sending => 'Raporunuz gönderiliyor — teşekkürler';
	@override String get copy => 'Raporu kopyala';
	@override String get notSent => 'Rapor gönderilemedi';
	@override String get copied => 'Rapor kopyalandı';
	@override String get notCopied => 'Rapor kopyalanamadı';
}

// Path: map.postcard
class _Translations$map$postcard$tr extends Translations$map$postcard$en {
	_Translations$map$postcard$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get button => 'Operasyon Kartpostalı';
	@override String title({required Object title}) => '${title} için kartpostal';
	@override String get portrait => 'Dikey';
	@override String get landscape => 'Yatay';
	@override String get square => 'Kare';
	@override String get save => 'Kaydet…';
	@override String get download => 'İndir';
	@override String get share => 'Paylaş';
	@override String get copy => 'Kopyala';
	@override String get copied => 'Panoya kopyalandı';
	@override String saved({required Object path}) => '${path} konumuna kaydedildi';
	@override String downloaded({required Object name}) => '${name} indirildi';
	@override String savedMany({required Object count, required Object path}) => '${count} görüntü ${path} konumuna kaydedildi';
	@override String savedFiles({required Object names}) => '${names} kaydedildi';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} zaten kaydedilmişti';
	@override String downloadedMany({required Object count}) => '${count} görüntü indiriliyor — tarayıcı sorarsa izin verin';
	@override String get mapLeftOut => 'Harita yüklenmedi, bu yüzden dışarıda bırakıldı';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — harita yüklenmedi, bu yüzden dışarıda bırakıldı';
	@override String continued({required Object title}) => '${title} (devamı)';
	@override String get previousPage => 'Önceki sayfa';
	@override String get nextPage => 'Sonraki sayfa';
	@override String pageOf({required Object page, required Object count}) => 'Sayfa ${page} / ${count}';
	@override String get sectionDays => 'Her gün';
	@override String get reset => 'Sıfırla';
	@override String failed({required Object error}) => 'Kartpostal oluşturulamadı: ${error}';
	@override String get mapNotReady => 'Harita yüklenmeyi bitirmedi. Bağlantıyı kontrol edip tekrar deneyin.';
	@override String saveFailed({required Object error}) => 'Kartpostal kaydedilemedi: ${error}';
	@override String get copyFailed => 'Pano görüntüyü almadı. Tekrar deneyin.';
	@override String get shareFailed => 'Kartpostal paylaşılamadı. Tekrar deneyin.';
	@override String get fileName => 'kartpostal';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$tr extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Henüz QSO yok... hadi havaya çıkalım!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object time, required Object count}) => '${time} içinde ${count}';
	@override String sinceLast({required Object time}) => 'Sonuncudan beri ${time}';
	@override String ratePer10({required Object rate}) => 'Son 10 için ${rate} Q/s';
	@override String ratePer100({required Object rate}) => 'Son 100 için ${rate} Q/s';
	@override String distanceTo({required Object distance}) => '${distance} mesafede:';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) mesafede:';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) mesafede:';
	@override String distanceAway({required Object distance}) => '${distance} uzakta';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) uzakta';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) uzakta';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Çift!';
	@override String get noticeNewBand => 'Yeni Bant';
	@override String get noticeNewMode => 'Yeni Mod';
	@override String get noticeNewDXCC => 'Yeni DXCC';
	@override String get noticeNewState => 'Yeni Eyalet';
	@override String get noticeNewProvince => 'Yeni İl';
	@override String get noticeNewDay => 'Yeni Gün';
	@override String get noticeNewRef => 'Yeni Ref';
	@override String get noticeNewMult => 'Yeni Mult';
	@override String get noticeNewZone => 'Yeni Bölge';
	@override String get noticeInvalidMode => 'Yanlış Mod';
	@override String get noticeInvalidBand => 'Yanlış Bant';
	@override String get noticeInvalidCategory => 'Çalışılamaz';
	@override String get noticeWorkedBefore => 'Daha Önce Çalışıldı';
	@override String get noticeNewPark => 'Yeni Park';
	@override String get noticeNewSection => 'Yeni Bölüm';
	@override String get noticeBonusStation => 'Bonus İstasyon!';
	@override String get noticeMissingExchange => 'Değişim Yok';
	@override String get noticeInvalidExchange => 'Hatalı Değişim';
	@override String get noticeUnknownEvent => 'Bilinmeyen Etkinlik';
	@override String get noticeOurGrid => 'Grid\'imizi Ayarla';
	@override String get noticeRareCounty => 'Nadir İlçe!';
	@override String get noticeOurLocation => 'İlçemizi Ayarla';
	@override String get noticeShortGrid => 'Grid Çok Kısa';
}

// Path: callInfo.history
class _Translations$callInfo$history$tr extends Translations$callInfo$history$en {
	_Translations$callInfo$history$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => 'Son 7 günde ${n}';
	@override String today({required Object n}) => 'Bugün ${n}';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$tr extends Translations$settings$theme$en {
	_Translations$settings$theme$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tema Modu';
	@override String get system => 'Sistem ayarlarını izle';
	@override String get light => 'Açık';
	@override String get dark => 'Koyu';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$tr extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Sistem ayarları izleniyor';
	@override String get light => 'Her Zaman Açık Mod';
	@override String get dark => 'Her Zaman Koyu Mod';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$tr extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'En Küçük--';
	@override String get smallestMinus => 'En Küçük-';
	@override String get smallest => 'En Küçük';
	@override String get smaller => 'Daha Küçük';
	@override String get normal => 'Normal';
	@override String get larger => 'Daha Büyük';
	@override String get largest => 'En Büyük';
	@override String get largestPlus => 'En Büyük+';
	@override String get largestPlusPlus => 'En Büyük++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$tr extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cihazı Uyanık Tut';
	@override String get descriptionOn => 'Kayıt ekranındayken veya senkronizasyon sürerken uyanık kalınıyor';
	@override String get descriptionOff => 'Her zamanki gibi uykuya geçiliyor';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$tr extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Otomatik';
	@override String get densest => 'En Sık';
	@override String get dense => 'Sık';
	@override String get normal => 'Normal';
	@override String get sparse => 'Seyrek';
	@override String get sparsest => 'En Seyrek';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$tr extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilometre';
	@override String get miles => 'Mil';
}

// Path: settings.logging
class _Translations$settings$logging$tr extends Translations$settings$logging$en {
	_Translations$settings$logging$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kayıt';
	@override late final _Translations$settings$logging$leftieMode$tr leftieMode = _Translations$settings$logging$leftieMode$tr._(_root);
	@override late final _Translations$settings$logging$countryFlags$tr countryFlags = _Translations$settings$logging$countryFlags$tr._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$tr countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$tr._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$tr suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$tr._(_root);
	@override late final _Translations$settings$logging$showBearing$tr showBearing = _Translations$settings$logging$showBearing$tr._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$tr showReverseBearing = _Translations$settings$logging$showReverseBearing$tr._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$tr switchSentRcvd = _Translations$settings$logging$switchSentRcvd$tr._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$tr jumpAfterRST = _Translations$settings$logging$jumpAfterRST$tr._(_root);
	@override late final _Translations$settings$logging$defaultReport$tr defaultReport = _Translations$settings$logging$defaultReport$tr._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$tr defaultReportCW = _Translations$settings$logging$defaultReportCW$tr._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$tr defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$tr._(_root);
	@override late final _Translations$settings$logging$numbersRow$tr numbersRow = _Translations$settings$logging$numbersRow$tr._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$tr numbersRowExtra = _Translations$settings$logging$numbersRowExtra$tr._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$tr numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$tr._(_root);
	@override String get bands => 'Tercih Edilen Bantlar';
	@override String get modes => 'Tercih Edilen Modlar';
}

// Path: settings.catServer
class _Translations$settings$catServer$tr extends Translations$settings$catServer$en {
	_Translations$settings$catServer$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT Sunucusu';
	@override String get description => 'Diğer uygulamaların (WSJT-X, kayıt programları vb.) radyoyu Ham2K Logger üzerinden kontrol etmesine izin ver.';
	@override String get protocol => 'Protokol';
	@override late final _Translations$settings$catServer$protocolOpts$tr protocolOpts = _Translations$settings$catServer$protocolOpts$tr._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Açık erişim';
	@override String get openAccessOn => 'Yerel ağdaki herhangi bir bilgisayar bağlanabilir.';
	@override String get openAccessOff => 'Yalnızca bu bilgisayardaki uygulamalar bağlanabilir.';
	@override String get off => 'Kapalı.';
	@override String starting({required Object protocol}) => '${protocol} başlatılıyor…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol}, ${port} portunda. Bağlı istemciler: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol}, ${port} portunda, ancak bağlı bir Ana VFO radyosu yok.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol}, ${port} portunu dinleyemiyor: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinleyemiyor: başka bir program onu kullanıyor, çoğu zaman ${protocol} programının kendisi. O programı kapatın veya başka bir port seçin.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinleyemiyor: bu bilgisayar buna izin vermiyor. 1024\'ün üzerinde bir port seçin.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinlemeyi bıraktı. Tekrar deneniyor…';
}

// Path: settings.radio
class _Translations$settings$radio$tr extends Translations$settings$radio$en {
	_Translations$settings$radio$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT Kontrolü';
	@override String get loggingAndCat => 'Kayıt ve CAT';
	@override String get tuningSection => 'Ayar';
	@override String get keyerSection => 'Keyer';
	@override String get servicesSection => 'Hizmetler';
	@override String get stationConfigurationSection => 'İstasyon Yapılandırması';
	@override String get moreSettings => 'Diğer istasyon yapılandırma ayarları';
	@override late final _Translations$settings$radio$units$tr units = _Translations$settings$radio$units$tr._(_root);
	@override late final _Translations$settings$radio$pttKey$tr pttKey = _Translations$settings$radio$pttKey$tr._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$tr smartVfoSnap = _Translations$settings$radio$smartVfoSnap$tr._(_root);
	@override late final _Translations$settings$radio$snapDebounce$tr snapDebounce = _Translations$settings$radio$snapDebounce$tr._(_root);
	@override late final _Translations$settings$radio$snapLongMove$tr snapLongMove = _Translations$settings$radio$snapLongMove$tr._(_root);
	@override late final _Translations$settings$radio$snapMinMove$tr snapMinMove = _Translations$settings$radio$snapMinMove$tr._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$tr snapMinSpeed = _Translations$settings$radio$snapMinSpeed$tr._(_root);
	@override late final _Translations$settings$radio$enterSends$tr enterSends = _Translations$settings$radio$enterSends$tr._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$tr keyerSpeed = _Translations$settings$radio$keyerSpeed$tr._(_root);
	@override late final _Translations$settings$radio$cwMessages$tr cwMessages = _Translations$settings$radio$cwMessages$tr._(_root);
	@override late final _Translations$settings$radio$voiceMessages$tr voiceMessages = _Translations$settings$radio$voiceMessages$tr._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$tr avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$tr._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$tr zeroBeatRange = _Translations$settings$radio$zeroBeatRange$tr._(_root);
}

// Path: settings.help
class _Translations$settings$help$tr extends Translations$settings$help$en {
	_Translations$settings$help$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Yardım ve Kaynaklar';
	@override String get description => 'Topluluk ve destek';
	@override String get forums => 'Ham2K Forumları';
	@override String get forumsDescription => 'Yardım bulun, geri bildirim verin, fikirleri tartışın…';
	@override String get chat => 'Ham2K Sohbeti';
	@override String get chatDescription => 'Çevrimiçi topluluğumuz için Discord sunucusu';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Videolar ve canlı yayınlar';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Çünkü fotoğrafın fazlası olmaz…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Haber ve güncellemeler için bizi takip edin';
	@override String get contact => 'İletişim';
	@override String get contactDescription => 'help@ham2k.com — ama önce Forumları veya Sohbeti deneyin!';
}

// Path: settings.exports
class _Translations$settings$exports$tr extends Translations$settings$exports$en {
	_Translations$settings$exports$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dışa Aktarımlar';
}

// Path: settings.map
class _Translations$settings$map$tr extends Translations$settings$map$en {
	_Translations$settings$map$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Haritalar';
	@override late final _Translations$settings$map$style$tr style = _Translations$settings$map$style$tr._(_root);
	@override late final _Translations$settings$map$styleOpts$tr styleOpts = _Translations$settings$map$styleOpts$tr._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$tr extends Translations$settings$privacy$en {
	_Translations$settings$privacy$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Gizlilik';
	@override late final _Translations$settings$privacy$shareAppData$tr shareAppData = _Translations$settings$privacy$shareAppData$tr._(_root);
	@override late final _Translations$settings$privacy$shareOpData$tr shareOpData = _Translations$settings$privacy$shareOpData$tr._(_root);
	@override String get privacyPolicy => 'Gizlilik Politikası';
	@override String get termsOfService => 'Hizmet Şartları';
}

// Path: settings.sync
class _Translations$settings$sync$tr extends Translations$settings$sync$en {
	_Translations$settings$sync$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bulut Senkronizasyonu';
	@override String get moreSettings => 'Diğer senkronizasyon ayarları';
	@override String get enable => 'Senkronizasyonu Etkinleştir';
	@override String get deviceKey => 'Cihaz Anahtarı';
}

// Path: settings.peers
class _Translations$settings$peers$tr extends Translations$settings$peers$en {
	_Translations$settings$peers$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Eş Cihazlar';
	@override String get enable => 'Diğer cihazlara bağlan';
	@override String get enableDescription => 'Yerel ağ üzerinden diğer cihazlarla operasyon, kayıt, CAT ve GPS paylaşımına izin ver';
	@override String get bleEnable => 'Bluetooth ile bağlan';
	@override String get bleDescription => 'Yerel ağ olmasa bile bağlanmak için Bluetooth LE kullan';
	@override String get thisDevice => 'Bu Cihaz';
	@override String get deviceName => 'İsim';
	@override String get deviceNameHint => 'Bu cihazın diğer cihazlarda nasıl göründüğü';
	@override String get pairedDevices => 'Bağlı Cihazlar';
	@override String get noPairedDevices => 'Henüz bağlı cihaz yok. Bağlamak için bunu bu ağdaki başka bir cihazda da açın.';
	@override String deviceListProblem({required Object error}) => 'Bağlı cihazlarınız okunamıyor: ${error}';
	@override String get nearby => 'Yakında';
	@override String get connected => 'Bağlı';
	@override String get viaBluetooth => 'Bluetooth üzerinden';
	@override String get connecting => 'Bağlanıyor…';
	@override String get syncing => 'Senkronize ediliyor…';
	@override String get waitingForThem => 'Diğer cihaz bekleniyor';
	@override String get notConnected => 'Bağlı değil';
	@override String get wantsToPair => 'bu operasyonu paylaşmak istiyor';
	@override String get allow => 'İzin ver';
	@override String get link => 'Bağla';
	@override String get reject => 'Reddet';
	@override String get forget => 'Unut';
	@override String forgetTitle({required Object name}) => '${name} unutulsun mu?';
	@override String get forgetBody => 'Bu cihazla senkronizasyonu durduracak. Daha sonra yeniden izin verebilirsiniz; önceden kaydedilmiş QSO\'lar korunur.';
	@override String pairTitle({required Object name}) => '${name} ile bağla';
	@override String get pairBody => 'Bu cihaz yerel ağınızda ve bağlanmak istiyor.';
	@override String get pairBodyBle => 'Bu cihaz yakında ve Bluetooth LE üzerinden bağlanmak istiyor.';
	@override String get pairIdLabel => 'Cihaz Kimliği';
	@override String get pairWarning => 'Yalnızca tanıdığınız cihazlarla bağlantı kurun. Bu ağdaki herhangi bir cihaz istek gönderebilir.';
	@override String get pairWarningBle => 'Yalnızca tanıdığınız cihazlarla bağlantı kurun. Yakındaki herhangi bir cihaz istek gönderebilir.';
	@override String problem({required Object error}) => 'Yerel ağa ulaşılamıyor: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => '${device} cihazına bağlandı';
	@override String statusLost({required Object device}) => '${device} ile bağlantı kesildi';
	@override String statusPerma({required Object linked, required Object connected}) => 'Eş Cihazlar: ${linked} cihazdan ${connected} tanesi bağlı';
	@override String get screenEnable => 'Ekranları ve pencereleri paylaş';
	@override String get screenDescription => 'Diğer cihazların bu bilgisayardaki ekranları veya pencereleri göstermesine izin ver';
	@override String get screenSources => 'Ekranlar ve Pencereler';
	@override String get screenRefresh => 'Listeyi yenile';
	@override String get screenUnsupportedPlatform => 'Bu cihaz ekranını paylaşamaz. macOS paylaşabilir; her cihaz başka bir cihazın paylaştığı ekranı gösterebilir.';
	@override String get screenUnsupportedVersion => 'Ekran paylaşmak için macOS 12.3 veya üstü gerekir. Bu cihaz yine de başka bir cihazın paylaştığı ekranı gösterebilir.';
	@override String get screenNeedsPermission => 'Bu uygulamanın ekran paylaşabilmesi için macOS\'in ekranı kaydetme izninize ihtiyacı var.';
	@override String get screenGrantPermission => 'İzin iste';
	@override String get screenRelaunchAfterGranting => 'Sistem Ayarları\'nda Gizlilik ve Güvenlik → Ekran Kaydı altında izin verin, ardından bu uygulamadan çıkıp yeniden açın — macOS değişikliği uygulamaya yalnızca bir sonraki açılışta bildirir.';
	@override String screenProblem({required Object error}) => 'Ekran paylaşımı: ${error}';
	@override String get screenChooseTitle => 'Neyin Paylaşılacağını Seçin';
	@override String get screenChooseButton => 'Neyin paylaşılacağını seçin…';
	@override String get screenTabScreens => 'Ekranlar';
	@override String get screenTabApps => 'Uygulamalar';
	@override String get screenTabWindows => 'Pencereler';
	@override String get screenTabEmpty => 'Bu türden bir şey bulunamadı.';
	@override String get screenSharedSummaryNone => 'Henüz bir şey seçilmedi.';
	@override String get screenThisDevice => 'Bu cihaz';
	@override String screenSharedTo({required Object devices}) => '${devices} üzerinde gösteriliyor';
	@override String get screenSharedToNobody => 'Gösterilmiyor';
	@override String screenStopSharing({required Object name}) => '${name} paylaşımını durdur';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$tr extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Senkronizasyon Yapılandırması';
	@override String get enableTitle => 'Ham2K Log Filer ile senkronize et';
	@override String get enabledDescription => 'Günlüğünüz yedekleniyor ve cihazlar arasında senkronize ediliyor';
	@override String get disabledDescription => 'Kapalı — yalnızca bu cihazda kalıyor';
	@override String get syncing => 'Senkronize ediliyor';
	@override String get account => 'Hesap';
	@override String get refresh => 'Yenile';
	@override String get switchAccounts => 'Hesap Değiştir';
	@override String get switchAccountsDescription => 'Bu cihazı QR kodu veya e-posta ile başka bir hesaba bağlayın';
	@override String get connectionRequests => 'Bağlantı İstekleri';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Bir cihaz bu hesaba katılmayı bekliyor',
		other: '${n} cihaz bu hesaba katılmayı bekliyor',
	);
	@override String get accountEmailTitle => 'Hesap e-postası';
	@override String accountEmailSent({required Object email}) => 'Onay ${email} adresine gönderildi. Değişikliği tamamlamak için oradaki bağlantıyı açın.';
	@override String get resendConfirmation => 'Onay E-postasını Yeniden Gönder';
	@override String resendConfirmationDescription({required Object email}) => '${email} bekleniyor';
	@override String accountEmailResent({required Object email}) => '${email} adresine yeniden gönderildi.';
	@override String get deviceLinked => 'O cihaz artık bu hesaba bağlı.';
	@override String get checking => 'Kontrol ediliyor…';
	@override String get notLinked => 'Henüz bağlı değil';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Yerel veriler değiştirilsin mi?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${n} operasyon',
		other: '${n} operasyon',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
	@override String get counts => 'Senkronize Veriler';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Bu cihaz: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Yüklenmeyi bekleyen: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Sunucu: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Bu cihaz: kontrol ediliyor…';
	@override String get countsServerChecking => 'Sunucu: kontrol ediliyor…';
	@override String get countsServerUnavailable => 'Sunucu: kullanılamıyor';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Bu işlem bu cihazdaki ${operations} ve ${qsos} kaydını yedekleyip temizler, ardından yerine hesabın verilerini indirir. Yedek bu cihazın veritabanında kalır.';
	@override String get replace => 'Değiştir';
	@override String get pendingBannerTitle => 'Yeni Ham2K Log Filer hesabı algılandı';
	@override String get pendingBannerBody => 'Bu cihazdaki mevcut operasyonları ve QSO\'ları koruyup hesapla birleştirin ya da hesabın verileriyle değiştirin (her iki durumda da bu cihazda bir yedek kalır).';
	@override String get combine => 'Birleştir';
	@override String get authIssueTitle => 'Senkronizasyon bağlanamıyor';
	@override String get authIssueText => 'Ham2K Log Filer bu cihazı reddetmeye devam ediyor. Senkronizasyon ayarlarında çağrı işaretinizi kontrol edin.';
	@override String get openSettings => 'Senkronizasyon ayarlarını aç';
}

// Path: settings.accounts
class _Translations$settings$accounts$tr extends Translations$settings$accounts$en {
	_Translations$settings$accounts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Hesaplar, Hizmetler ve Veri Kaynakları';
	@override String get none => 'Hesap kullanan etkin uzantı yok';
	@override String get notConfigured => 'Yapılandırılmadı';
	@override String get connected => 'Bağlı';
	@override String get cancelLogin => 'Girişi iptal et';
	@override String get openInBrowser => 'Tarayıcıda Aç';
	@override String loggedInAs({required Object identity}) => '${identity} olarak giriş yapıldı';
	@override String get pressSaveToKeep => 'Bu hesabı bağlı tutmak için Kaydet\'e basın.';
	@override String connectedTo({required Object label}) => '${label} hizmetine bağlı';
	@override String get connect => 'Bağlan';
	@override String get disconnect => 'Bağlantıyı Kes';
	@override String get connectedAs => 'Bağlı hesap:';
	@override String get test => 'Test Et';
	@override String saveFailed({required Object error}) => 'Kaydetme başarısız: ${error}';
	@override String loginFailed({required Object error}) => 'Giriş başarısız: ${error}';
	@override String get lookupFailed => 'Hesaplar şu anda kullanılamıyor — birazdan tekrar deneyin';
	@override String get browserLoginTitle => 'Girişi web tarayıcınızda tamamlayın';
	@override String browserLoginSteps({required Object prefix}) => 'İşiniz bittiğinde tarayıcı "${prefix}" ile başlayan bir bağlantıyı açmaya çalışacak. Masaüstünüzde büyük olasılıkla bunu açacak kayıtlı bir şey yoktur; bu yüzden o bağlantıyı (adres çubuğundan veya tarayıcının gösterdiği hata sayfasından) kopyalayıp buraya yapıştırın.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger tarayıcınızı açamadı. Aşağıdaki giriş bağlantısını kopyalayıp kendiniz açın, ardından sizi yönlendirdiği bağlantıyı ("${prefix}" ile başlar) kopyalayıp buraya yapıştırın.';
	@override String get copyLoginLink => 'Giriş bağlantısını kopyala';
	@override String get pastedLinkLabel => 'Bağlantıyı buraya yapıştırın';
	@override String get finishLogin => 'Girişi Tamamla';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Bu giriş bağlantısı değil — "${prefix}" ile başlamalı.';
	@override String get pastedLinkWrongLogin => 'Bu bağlantı farklı bir giriş denemesine ait. Bu sayfayı kapatıp yeniden bağlanın.';
	@override String get pastedLinkNoCode => 'Bu bağlantıda giriş kodu yok. Önce girişi tamamlayın, ardından sizi yönlendirdiği bağlantıyı kopyalayın.';
	@override String get pastedLinkMalformed => 'Bu bağlantı kesik görünüyor. Tamamını kopyalayıp yeniden yapıştırın.';
	@override String get relayLoginWaiting => 'Girişi tamamlamanız bekleniyor — tamamladığınızda otomatik olarak devam edecek.';
	@override String get loginNoResponse => 'Bu cihaz henüz girişten yanıt almadı. Tarayıcınızda zaten tamamladıysanız iptal edip yeniden bağlanmayı deneyin.';
	@override String get relayLoginNotOpened => 'Ham2K Logger tarayıcınızı otomatik olarak açamadı. Giriş sayfasını kendiniz açmak için aşağıdaki düğmeyi kullanın.';
	@override String get relayLoginUnavailable => 'Bu girişi tamamlamak için gereken senkronizasyon sunucusuna ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.';
	@override String get loginIncompleteResponse => 'Bu giriş denemesi doğru şekilde tamamlanmadı. Lütfen yeniden bağlanmayı deneyin.';
	@override String get noKeyringTitle => 'Hesap girişleri kaydedilemiyor';
	@override String get noKeyringText => 'Ham2K Logger bu bilgisayarda bir anahtarlık hizmetine ulaşamıyor, bu yüzden hesap girişleri saklanamıyor veya okunamıyor — bu çözülene kadar hesap bağlamak başarısız olur. **gnome-keyring**, **KWallet** veya **KeePassXC** yükleyip başlatın ya da mevcut anahtarlığınızın kilidini açın, ardından yeniden başlatın. Kayıt, dışa aktarma ve veri dosyaları etkilenmez; bu durum sürdükçe günlük senkronizasyonu kapalı kalır.';
	@override String get noKeyringInline => 'Girişler kaydedilemiyor: bu bilgisayarın anahtarlığına ulaşılamıyor. gnome-keyring, KWallet veya KeePassXC yükleyip başlatın ya da mevcut olanın kilidini açın.';
	@override String get noSecureStorageInline => 'Girişler kaydedilemiyor: bu bilgisayarın güvenli depolamasına ulaşılamıyor.';
}

// Path: settings.station
class _Translations$settings$station$tr extends Translations$settings$station$en {
	_Translations$settings$station$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'İstasyon Yapılandırması ve CAT Kontrolü';
	@override String get none => 'Yapılandırılmış ekipman yok';
	@override String get add => 'Ekle';
	@override String get addTitle => 'Ekipman ekle';
	@override String get searchHint => 'Ekipman ara';
	@override String get noMatches => 'Eşleşen ekipman yok';
	@override String get detectedEquipment => 'Algılanan Ekipman';
	@override String discoveryUnavailable({required Object error}) => 'Radyolar dinlenemiyor: ${error}';
	@override String get edit => 'Ekipmanı düzenle';
	@override String get name => 'İsim';
	@override String get nameDescription => 'Ona ne dediğiniz — "Sol Radyo". İsteğe bağlı.';
	@override String get transport => 'Bağlantı';
	@override String get host => 'Adres';
	@override String get hostDescription => 'Radyonun ağınızdaki ana makine adı veya IP adresi.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Adres gerekli';
	@override String get portInvalid => 'Port 1 ile 65535 arasında olmalı';
	@override String get connect => 'Bağlan';
	@override String get disconnect => 'Bağlantıyı Kes';
	@override String get remove => 'Kaldır';
	@override String removeTitle({required Object name}) => '${name} kaldırılsın mı?';
	@override String get removeMessage => 'Bu yalnızca onu uygulamadan kaldırır. Ekipmanın ayarları olduğu gibi kalır.';
	@override String unknownType({required Object typeKey}) => 'Tanınmayan ekipman türü "${typeKey}"';
	@override String get report => 'Bildir';
	@override String get reportTitle => 'Bu radyoyu bildir';
	@override String get reportIntro => 'Bu radyonun gerçekte ne olduğunu ve nasıl gittiğini bize anlatın. Raporunuz Ham2K ekibinin okuduğu bir karta dönüşür; onu çalıştırma konusunda yazdıklarınız aynı cihaza sahip bir sonraki operatöre yardımcı olabilir.';
	@override String get reportManufacturer => 'Üretici';
	@override String get reportManufacturerDescription => 'Kim üretiyor — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Üretici gerekli';
	@override String get reportModel => 'Model';
	@override String get reportModelDescription => 'Radyonun kendisinin belirttiği model — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'Model gerekli';
	@override String get reportOutcome => 'Nasıl gitti?';
	@override String get reportOutcomeWorks => 'İyi çalıştı';
	@override String get reportOutcomeIssues => 'Çalıştı, sorunlarla';
	@override String get reportOutcomeFails => 'Hiç çalışmadı';
	@override String get reportOutcomeRequired => 'Lütfen nasıl gittiğini bize söyleyin';
	@override String get reportComments => 'Yorumlar';
	@override String get reportCommentsPlaceholder => 'Ne çalıştı, ne çalışmadı, sizi şaşırtan herhangi bir şey.';
	@override String get reportHints => 'Sorun giderme ipuçları';
	@override String get reportHintsPlaceholder => 'Diğer kullanıcılar için sorun giderme ipuçları önermek ister misiniz?';
	@override String get reportSend => 'Raporu gönder';
	@override String get reportSending => 'Raporunuz gönderiliyor…';
	@override String reportSent({required Object ref}) => 'Teşekkürler — raporunuz ${ref} olarak kaydedildi.';
	@override String get reportSentNoRef => 'Teşekkürler — raporunuz gönderildi.';
	@override String reportFailed({required Object error}) => 'Rapor gönderilmedi: ${error}';
	@override String get troubleshootingNotes => 'Sorun Giderme Notları';
	@override String get mainVfo => 'Ana VFO';
	@override String get useAsMainVfo => 'Ana VFO olarak kullan';
	@override String get serialPort => 'Seri port';
	@override String get serialPortDescription => 'Radyonun CAT arayüzünün göründüğü port.';
	@override String get serialPortNone => 'Seri port bulunamadı';
	@override String get serialPortRequired => 'Bir seri port seçin';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} / ${total}';
	@override String get serialPortSuggested => 'önerilen';
	@override String get serialPortJustNow => 'Yeni bağlandı';
	@override String get serialDeviceRequest => 'USB cihazı ekle…';
	@override String get baudRate => 'Hız (baud)';
	@override String get baudRateDescription => 'Radyonun CAT menüsüyle eşleşmelidir. Eşleşmezse radyo anlamsız veri döndürür ve hata vermez.';
	@override String get serialRtsHigh => 'RTS\'yi yüksek tut';
	@override String get serialRtsHighDescription => 'Yalnızca yanıt vermeden önce RTS bekleyen bir radyo için, örneğin CAT RTS açık bir Yaesu. Digirig, SignaLink ve çoğu ev yapımı kabloda RTS, PTT\'dir ve onu yüksek tutmak yayına geçirir.';
	@override String get serialDtrHigh => 'DTR\'yi yüksek tut';
	@override String get serialDtrHighDescription => 'Yalnızca gücünü DTR\'den alan bir CAT arayüzü için, örneğin FT-817 için bazı RS-232 kabloları. Birçok kabloda DTR, CW veya PTT\'yi tetikler ve onu yüksek tutmak yayına geçirir.';
	@override String get civAddress => 'Radyo CI-V adresi';
	@override String get civAddressDescription => 'Radyonun CI-V menüsünde gösterildiği gibi onaltılık. IC-705 fabrikadan A4 olarak gelir.';
	@override String get civAddressInvalid => 'CI-V adresi iki onaltılık basamaktır, 01 ile FF arası';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Bu bağlantının radyonun hangi slice\'ından okuyup ayar yaptığı.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Radyonun slice\'larından birini seçin, A ile H arası';
	@override String flexSliceMissing({required Object letter}) => 'Slice ${letter} bu radyoda kullanılmıyor — başka bir slice seçin veya SmartSDR\'da oluşturun';
	@override String get channelNotInUse => 'kullanılmıyor';
	@override String get channelHeldByUnknown => 'başka bir program kullanıyor';
	@override String get flexNoSlices => 'Bu radyo hiç slice bildirmedi — SmartSDR\'ın çalıştığını ve bu istemcinin abone olabildiğini kontrol edin';
	@override String get spectrumUnsupported => 'Bu radyo CAT üzerinden spektrum göndermiyor';
	@override String get spectrumRequiresBaud => '115200 bps CAT gerektirir';
	@override String get spectrumNoRadio => 'Bağlı radyo yok';
	@override String get spectrumWaiting => 'Radyonun spektrumu bekleniyor…';
	@override String get spectrumUnavailable => 'Spektrum görüntüsü kullanılamıyor';
	@override String get spectrumNoDaxChannel => 'Bu radyodaki tüm DAX IQ kanalları kullanımda';
	@override String get spectrumNoPanadapter => 'Bu slice\'ın radyoda bir panadapter\'ı yok';
	@override String spectrumStreamRefused({required Object code}) => 'Radyo bir DAX IQ akışını reddetti (hata ${code})';
	@override String get spectrumNoUdp => 'Radyonun spektrum verisi bu cihaza ulaşamıyor';
	@override String get spectrumScopeRefused => 'Radyo skop komutlarını reddetti';
	@override String get spectrumOutOfRange => 'Radyonun skopu gösterebileceği aralığın dışına ayarlanmış';
	@override String get n3fjpNoRig => 'N3FJP\'de radyo arayüzü kurulu değil, bu yüzden bu bir radyoyu değil, N3FJP\'ye yazılanları izler';
	@override String get winkeyerKeyPort => 'Anahtar çıkışı';
	@override String get winkeyerKeyPortDescription => 'Radyonuzun keyer\'ın iki çıkış jakından hangisine takılı olduğu.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Keyer\'ın PTT\'sini kullan';
	@override String get winkeyerPttDescription => 'Bir amplifikatör veya bunu gerektiren bir radyo için aynı jaktaki PTT hattını tetikler. Anahtar jakından tetiklenen bir radyo için kapalı bırakın.';
	@override String get winkeyerNoAnswer => 'Bu portta hiçbir WinKeyer yanıt vermedi';
	@override String get winkeyerStoppedAnswering => 'WinKeyer gönderim sırasında yanıt vermeyi bıraktı; mesaj iptal edildi';
	@override String get radioUser => 'Radyo kullanıcı adı';
	@override String get radioPass => 'Radyo şifresi';
	@override String get radioLoginDescription => 'Radyonun Network → Remote girişi, WiFi şifreniz değil.';
	@override String get radioUserRequired => 'Radyonun uzaktan kontrol kullanıcı adı gerekli';
	@override String get connectFailedBusy => 'Cihaz kullanımda';
	@override String get connectFailedDenied => 'Erişim reddedildi';
	@override String get connectFailedDevice => 'Cihaz bulunamadı';
	@override String get connectFailedLines => 'RTS/DTR ayarlandığı gibi tutulamadı, bu yüzden port kapatıldı. Başka bir program donanım el sıkışmasını açık bırakmış olabilir — kabloyu çıkarıp yeniden takın.';
	@override String get connectFailedNetwork => 'Radyo ağda bulunamıyor. Adresini, açık ve erişilebilir olduğunu kontrol edin.';
	@override String get connectFailedTimeout => 'Radyo zamanında yanıt vermedi. Açık ve erişilebilir olduğunu kontrol edin.';
	@override late final _Translations$settings$station$models$tr models = _Translations$settings$station$models$tr._(_root);
	@override late final _Translations$settings$station$transports$tr transports = _Translations$settings$station$transports$tr._(_root);
	@override String get troubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get ft891Troubleshooting => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT RTS radyoda OFF olmalı** (FT-891 menüsü **05-08**). Açıkken radyo, uygulamanın düşük tuttuğu bir el sıkışma hattını bekler. Digirig, SignaLink veya çoğu ev yapımı kabloda aynı hat PTT\'dir, bu yüzden onu yükseltmek vericinizi yayına geçirir. Radyonun kendi USB portunda alternatif, Gelişmiş Ayarlar altındaki **RTS\'yi yüksek tut** seçeneğidir.\n- **Hız eşleşmeli**: radyonun CAT RATE ayarı (menü **05-06**). Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get yaesuBinaryTroubleshooting => 'Bu radyo Yaesu\'nun eski beş baytlık CAT protokolünü konuşur ve bir şey yanlış olduğunda hiç yanıt vermez. Neredeyse her zaman şunlardan biridir:\n\n- **Kablo seviyeleri dönüştürmelidir.** Arkadaki CAT jakı RS-232 de USB de değildir; CT-62 veya eşdeğer bir adaptör gerekir. Düz bir ses veya veri kablosu CAT için çalışmaz.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü (FT-817\'de **#14**, FT-857 veya FT-897\'de **#19**). Eşleşmezse radyo hiçbir şey döndürmez, asla hata vermez.\n- **Bu portta hiçbir şeyin RTS veya DTR\'yi yükseltmesine izin vermeyin.** Bu radyolar için çoğu kabloda bu hatlar PTT ve manipülasyondur. DTR\'den beslenen eski bir arayüz istisnadır: onun için Gelişmiş Ayarlar altında **DTR\'yi yüksek tut** seçeneğini açın.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\nBu sürücü Yaesu\'nun yayımladığı CAT tablosundan yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get guohetecTroubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get guohetecTroubleshooting => 'Q900\'ün iki CAT protokolü vardır ve bu giriş FT-817 taklidi yerine kendi yerel protokolünü kullanır. Burada FT-817\'yi değil, **Guohetec Q900**\'ü seçin — taklit daha az komut destekler ve radyo hangisini kullandığını söylemez.\n\n- **USB-C kablosu CAT bağlantısıdır** ve ses kartını da bağlar. Bu bağlantıda hız önemli değildir; port ne ayarlanırsa ayarlansın yok sayar.\n- **Bu portta hiçbir şeyin RTS veya DTR\'yi yükseltmesine izin vermeyin.** Seri kabloda bu hatlar PTT ve manipülasyondur.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **İkinci nesil bir radyo birinci nesilden farklı davranır.** Menu\'ye uzun basın, ardından About: HW 2.0 ikinci nesildir.\n\nBu sürücü üreticinin yayımladığı protokolden yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get yaesuTroubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get yaesuTroubleshooting => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, uygulamanın düşük tuttuğu bir el sıkışma hattını bekler. Digirig, SignaLink veya çoğu ev yapımı kabloda aynı hat PTT\'dir, bu yüzden onu yükseltmek vericinizi yayına geçirir. Radyonun kendi USB portunda alternatif, Gelişmiş Ayarlar altındaki **RTS\'yi yüksek tut** seçeneğidir. Bu ayarın yeri modele göre değişir (FT-891\'de menü **05-08**).\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **Modlar FT-891\'in tablosunu izler.** Yaesu serisinin çoğu buna uyar, ancak modlarını farklı numaralandıran bir radyo bu modlar için yanlış olanı gösterir ve ayarlar. Frekans etkilenmez.';
	@override String get yaesuRs232Troubleshooting => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT jakı RS-232\'dir.** USB-seri adaptör ve düz bağlantılı bir DB-9 kablosu gerekir — null-modem kablosu hatları çaprazlar ve radyo hiçbir şey duymaz.\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, Gelişmiş Ayarlar altında **RTS\'yi yüksek tut** açık olmadıkça uygulamanın düşük tuttuğu bir el sıkışma hattını bekler.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\nBu giriş yayımlanmış CAT belgelerinden yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get yaesuUsbTroubleshooting => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **Radyonun iki USB portundan ilkini kullanın.** CAT normalde ilkindedir (Windows\'ta **Enhanced** COM portu); ikincisi (**Standard**) PTT ve manipülasyon içindir. Seçici, ikisini ayırt edebildiği her yerde ilkini gösterir.\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, Gelişmiş Ayarlar altında **RTS\'yi yüksek tut** açık olmadıkça uygulamanın düşük tuttuğu bir el sıkışma hattını bekler.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.';
	@override String get k4SerialNotes => 'K4\'ün arkadaki USB-B (PC) soketini bağlayın. CAT için USB-PC1 veya USB-PC2 çalışır; kullanılmayan bir port seçin ve radyodaki Serial USB-PCn: Baud Rate ayarıyla eşleştirin. HaLo 38400 değerini önceden doldurur; gerekirse değiştirin. Başka bir uygulama diğer portu veya Ethernet\'i kullanmalıdır.\n\nBu bağlantı radyoyu ve keyer\'larını kontrol eder; HaLo\'ya ses göndermez.';
	@override String get k4TcpNotes => 'K4\'ün Ethernet soketini yerel ağınıza bağlayın. Ana makine adını veya IP adresini ve CAT portu 9200\'ü girin. Bu CAT kontrolüdür, 9204 portundaki ayrı uzak ses bağlantısı değildir.\n\nHaLo, ses veya panadapter verisi aktarmadan radyoyu ve keyer\'larını kontrol eder.';
	@override String get k4PowerTimeout => 'Radyo çıkış aralığını onaylamadığı için K4 gücü değiştirilmedi. Tekrar deneyin.';
	@override String get k4PowerRange => 'K4 gücü 0.1–110 W olmalıdır; transverter miliwatt çıkışı etkinken 0.0001–0.01 W.';
	@override String get elecraftTroubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get elecraftTroubleshooting => 'Elecraft cihazları Kenwood CAT konuşur ve hem KX2 hem KX3 bu şekilde çalıştırıldı — her iki yönde VFO, mod değiştirme ve CW sıfır vuruşu çalışıyor.\n\nRadyo yanıt vermiyorsa, neredeyse her zaman şunlardan biridir:\n\n- **Hız eşleşmeli**: radyonun menüsünde **RS232** altında ayarlanan hız. Bu cihazlar 38400 ile gelir. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\n**Frekans doğru ama mod yanlışsa** bize bildirin. KX2 ve KX3 girişleri modu, radyonun durum yanıtında gördüğümüz cihazlardan belirlediğimiz bir konumdan okur; onu başka yere koyan bir yazılım ancak bir raporla bize ulaşır.\n\nK3 için henüz rapor yok, bu yüzden kullanıyorsanız ne olduğunu lütfen söyleyin. K4\'ün kendi girişi vardır.';
	@override String get kenwoodTroubleshootingTitle => 'Radyo bağlanıyor ama frekans göstermiyorsa';
	@override String get kenwoodTroubleshooting => 'Bu sürücü Kenwood TS-590SG ve TS-480, QRP Labs QMX ve QCX-mini ile Elecraft KX2 ve KX3 üzerinde doğrulandı. Serinin geri kalanı yayımlanmış CAT referanslarından yazıldı, bu yüzden her iki durumda da ne olduğunu lütfen bildirin.\n\nRadyo yanıt vermiyorsa, neredeyse her zaman şunlardan biridir:\n\n- **Hız eşleşmeli**: radyonun CAT menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **Bazı cihazlarda CAT** yanıt vermeden önce menüden etkinleştirilmelidir.\n\n**Birçok SDR ön ucu aynı protokolü konuşur**, bu yüzden bu giriş onlar için de denemeye değer; Elecraft cihazları ayrı olarak, Elecraft altında listelenir. Frekans doğru ama mod yanlış veya eksikse, seri boyunca farklılık gösteren tek kısım budur — uygulama modu radyodan çıkarır ve gerekirse doğrudan sorar, bu yüzden mod yalnızca gecikmeli gelebilir.';
	@override String get statusConnected => 'Bağlı';
	@override String get statusLost => 'Bağlantı kesildi';
	@override String get notConfigured => 'Yapılandırılmadı';
	@override String get currentConfiguration => 'Mevcut Yapılandırma';
	@override String get currentTransceiver => 'Mevcut Telsiz';
	@override String get radioMode => 'Radyo Modu';
	@override String get keyerNotSupported => 'Mevcut radyo desteklemiyor';
	@override String get catControlPreferences => 'CAT Kontrol Tercihleri';
	@override String get chooseTransceiver => 'Telsiz seç';
	@override String get configurationSection => 'Yapılandırma';
	@override String get noTransceiverSelected => 'Telsiz seçilmedi';
	@override String makeMainVfo({required Object name}) => 'Ana VFO için ${name} kullan';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		zero: 'Telsiz yok',
		one: '${count} telsiz',
		other: '${count} telsiz',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} anten',
		other: '${count} anten',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} diğer cihaz',
		other: '${count} diğer cihaz',
	);
	@override String get equipmentInventory => 'Ekipman Envanteri';
	@override String get equipmentInUse => 'Telsiz Kontrolleri';
	@override String get noTransceiver => 'Yok';
	@override String get peerRadioNotAvailable => 'Kullanılamıyor';
	@override String peerRadioOnDevice({required Object device}) => '${device} üzerinde';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} başka bir cihazda';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Bu radyo ${device} cihazına bağlı. Bağlantısı ve ayarları o cihazda yapılandırılır.';
	@override String get antennaInUse => 'Kullanılan Anten';
	@override String get keyInUse => 'Kullanılan Anahtar';
	@override String get noneSelected => 'Yok';
	@override String get moreSettings => 'Diğer Ayarlar';
	@override String get icomCivTroubleshootingTitle => 'Aynı radyo için iki seri port görünüyorsa';
	@override String get icomCivTroubleshooting => 'IC-705 dahil birçok Icom radyosu aynı anda **iki** USB seri port sunar (Icom bunlara Port A ve Port B der) ve ikisi de varsayılan olarak CI-V\'ye ayarlıdır. Ne bu uygulama ne de işletim sisteminiz bunları bunun ötesinde ayırt edebilir: aynı USB üretici/ürün kimliği iki kez görünür, burada bazen `#2` ekiyle işaretlenir. **Doğru olan genellikle Port A\'dır** — normalde işletim sisteminizin veya tarayıcınızın listelediği ilk port; bu uygulama iki portu ayırt edebildiğinde onu önerilen olarak işaretler. Komutlar gidiyor ama radyo hiç yanıt vermiyorsa diğer portu deneyin.';
	@override String get civAddressTroubleshootingTitle => 'Radyo hiç yanıt vermiyorsa';
	@override String get civAddressTroubleshooting => '- **CI-V adresi eşleşmeli**: radyonun menüsündekiyle aynı olmalı. Bu giriş, modelin fabrika adresini önceden doldurur, ancak bir CI-V veri yolunu paylaşan bir cihazda tam da bu değiştirilir. Yanlış adrese gönderilen bir çerçeve sessizce yok sayılır; bu da tıpkı ölü bir kablo gibi görünür.\n- **Hız eşleşmeli**: radyonun CI-V BAUD RATE ayarı (USB\'de CI-V USB Baud Rate). Radyoyu burada gösterilen sayıya ayarlayın, **Auto\'ya değil**. Auto\'da IC-7300 dahil bazı radyolar bağlanır ve bir dakika kadar sonra yanıt vermeyi bırakır.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** burada önceden doldurulan `94` yerine `B6` adresiyle gelir — onun yerine IC-7300 MK2 girişini seçin.';
	@override String get ic705PortNote => '\n- **IC-705** her ikisi de radyonun adını taşıyan iki USB seri port sunar. CI-V bunların **ilkindedir**; seçici, ikisini ayırt edebildiği her yerde onu gösterir.';
	@override String get ic7760PortNote => '\n- **IC-7760**, sunduğu iki USB seri porttan **Port A** üzerinde CI-V konuşur.';
	@override String get x6100PortNote => '\n- **X6100**, CI-V\'yi **DEV** portunda konuşur — sunduğu iki seri porttan ikincisi ve seçicinin gösterdiği port.';
	@override String get rigctldTroubleshootingTitle => 'Uygulama bağlanamıyorsa';
	@override String get rigctldTroubleshooting => 'Bu, radyoya doğrudan değil, **kendiniz çalıştırdığınız bir rigctld servisine** bağlanır — Hamlib\'in arka ucu radyoyla konuşur ve yüzlerce modeli destekler.\n\n- **Servis zaten çalışıyor olmalı**, örn. `rigctld -m 1035 -r /dev/ttyUSB0`. Radyonuzun model numarasını `rigctl -l` ile bulun.\n- **Başka bir makineden** bağlanmak için `-T 0.0.0.0` ile başlatın: varsayılan olarak rigctld yalnızca çalıştığı makineden bağlantı kabul eder.\n- Servisi `-t` ile başlatmadıysanız **port** 4532\'dir.\n- Bağlandıktan sonra frekansın görünmemesi genellikle servisin kendisinin radyoya ulaşamadığı anlamına gelir. Servisin makinesinde `rigctl -m 2 f` ile test edin.';
	@override String get flrigTroubleshootingTitle => 'Uygulama bağlanamıyorsa';
	@override String get flrigTroubleshooting => 'Bu, radyoya doğrudan değil, **kendiniz çalıştırdığınız bir flrig programına** bağlanır — flrig radyoyla konuşur ve çoğu marka ve modeli destekler.\n\n- **flrig zaten çalışıyor olmalı**, telsizi yapılandırılmış ve bağlı olarak.\n- flrig yapılandırmasında (Config → Setup → Server) değiştirmediyseniz **port** 12345\'tir.\n- **Başka bir makineden** bağlanıyorsanız flrig sunucusuna erişilebildiğinden emin olun. Tüm arayüzleri dinler, ancak güvenlik duvarınız aynı fikirde olmayabilir.\n- Bağlandıktan sonra frekansın görünmemesi genellikle flrig\'in kendisinin radyoya ulaşamadığı anlamına gelir. flrig ekranının düğmeyi izlediğini kontrol edin.';
	@override String get hrdTroubleshootingTitle => 'Uygulama bağlanamıyorsa';
	@override String get hrdTroubleshooting => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan Ham Radio Deluxe Rig Control\'e** bağlanır — HRD radyoyla konuşur.\n\n- **Rig Control zaten çalışıyor olmalı** ve radyoya bağlı olmalı.\n- **IP sunucusu etkin olmalı.** Rig Control diğer programlarla yalnızca onun üzerinden konuşur.\n- IP sunucusunun ayarlarında değiştirmediyseniz **port** 7809\'dur.\n- **Başka bir makineden** bağlanıyorsanız güvenlik duvarınızın bağlantıya izin verdiğinden emin olun.\n\nBu giriş HRD protokolünün yayımlanmış açıklamalarından yazıldı ve HRD üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get n3fjpTroubleshootingTitle => 'Uygulama bağlanamıyorsa';
	@override String get n3fjpTroubleshooting => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan bir N3FJP kayıt programına** bağlanır — N3FJP radyoyla konuşur.\n\n- **Programın API\'si açık olmalı**: Settings → Application Program Interface, **TCP API Enabled** seçeneğini işaretleyin.\n- Orada değiştirmediyseniz **port** 1100\'dür.\n- Radyoyu izlemek veya ayarlamak için **N3FJP\'de bir radyo arayüzü kurulu olmalı**. Arayüz olmadan yalnızca giriş penceresine yazılanları bildirir.\n- N3FJP yalnızca bant, mod ve frekans bildirir: güç ve yayın durumu yok.\n\nBu giriş N3FJP\'nin yayımlanmış API\'sinden yazıldı ve N3FJP üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get commanderTroubleshootingTitle => 'Uygulama bağlanamıyorsa';
	@override String get commanderTroubleshooting => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan DXLab Commander\'a** bağlanır — Commander radyoyla konuşur.\n\n- **Commander zaten çalışıyor olmalı** ve radyoya bağlı olmalı.\n- **Ağ hizmeti açık olmalı**: Commander\'ın Configuration penceresindeki Radio panelinde **Net Serv** düğmesi.\n- **Port** 52002\'dir; Net Serv\'in **Base Port** değeriyle (değiştirmediyseniz 52000) başlayan bloğun üçüncü portu.\n- **Başka bir makineden** bağlanıyorsanız güvenlik duvarınızın bağlantıya izin verdiğinden emin olun.\n\nBu giriş Commander\'ın yayımlanmış TCP mesajlarından yazıldı ve Commander üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.';
	@override String get ic705TroubleshootingTitle => 'Radyo hiç yanıt vermiyorsa';
	@override String get ic705Troubleshooting => 'Radyonun **tek** bir uzaktan kontrol oturumu vardır. Giriş yok sayıldığında neredeyse her zaman onu başka bir şey kullanıyordur.\n\n- **Diğer istemcileri kapatın.** Aynı radyoya bağlı wfview veya RS-BA1 o tek oturumu tutar ve bu sürece buradaki giriş yok sayılır.\n- **Radyonun ağ ayarlarını kontrol edin.** WLAN açık olmalı, radyo aynı ağda olmalı ve uzaktan kontrol (Network) işlevi etkin olmalı.\n- Takılı kalırsa **radyonun WLAN\'ını kapatıp açın**. Bu, radyoda takılı kalan bir oturumu güvenilir şekilde temizler.\n\n**Yanlış şifre açıkça reddedilir**, sessizlikle karşılanmaz. "Reddedildi" mesajı yerine buraya geldiyseniz sorun şifre değildir.';
	@override String get statusStale => 'Yanıt vermiyor';
	@override String get statusDisconnected => 'Bağlı değil';
	@override String get statusConnecting => 'Bağlanıyor…';
	@override String get statusDisconnecting => 'Bağlantı kesiliyor…';
	@override String get statusError => 'Bağlantı başarısız';
	@override String get currentRadioSettings => 'Mevcut radyo ayarları';
	@override String get notSupportedByThisRadio => 'Bu radyo desteklemiyor';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Telefon';
	@override String voiceKeyerAvailable({required Object count}) => 'Ses keyer\'ı: radyoda ${count} hafıza';
	@override String get antennaBands => 'Bantlar';
	@override String get antennaType => 'Anten türü';
	@override String get antennaTypeRequired => 'Bir anten türü seçin';
	@override late final _Translations$settings$station$antennaTypes$tr antennaTypes = _Translations$settings$station$antennaTypes$tr._(_root);
	@override String get keyType => 'Anahtar türü';
	@override String get keyTypeRequired => 'Bir anahtar türü seçin';
	@override late final _Translations$settings$station$keyTypes$tr keyTypes = _Translations$settings$station$keyTypes$tr._(_root);
	@override String get softwareIntermediaries => 'Aracı Yazılımlar';
	@override String get otherBrands => 'Diğer Markalar';
	@override String get otherEquipment => 'Diğer Ekipman (Antenler, Anahtarlar vb.)';
	@override String get newAntenna => 'Yeni Anten';
	@override String get newKey => 'Yeni Anahtar';
	@override String get newKeyer => 'WinKeyer (K1EL veya uyumlu)';
	@override String keyViaRadio({required Object radio}) => '${radio} içindeki CAT Keyer';
	@override String keyOnDevice({required Object device}) => '${device} üzerindeki anahtar';
	@override String get trackStationInfo => 'Her QSO için İstasyon Bilgisini Kaydet';
	@override String get includeStationInfoInAdif => 'ADIF dışa aktarımlarına dahil et';
	@override String get whatToTrack => 'Neler kaydedilsin?';
	@override String get trackFieldRig => 'Telsiz';
	@override String get trackFieldPower => 'Güç';
	@override String get watts => 'Watt';
	@override String get trackFieldAntenna => 'Anten';
	@override String get trackFieldKey => 'CW Anahtarı';
	@override String get placeholderConnectDelay => 'Bağlantı gecikmesi (ms)';
	@override String get placeholderConnectDelayDescription => 'Simüle edilen el sıkışmanın ne kadar sürdüğü. Boş veya 0 anında bağlanır.';
	@override String get placeholderDropAfter => 'Şu süre sonra kes (saniye)';
	@override String get placeholderDropAfterDescription => 'Yeniden bağlanma yolunu denemek için bağlantıyı kendiliğinden kapatır. Boş veya 0 hiç kesmez.';
	@override String get placeholderFailConnect => 'Bağlantı her zaman başarısız olsun';
	@override String get placeholderConnectFailure => 'Yer tutucu radyoya bu bağlantıyı reddetmesi söylendi';
	@override String get placeholderFreq => 'Frekans (kHz)';
	@override String get placeholderFreqDescription => 'Yer tutucu radyonun başladığı frekans. Ardından uygulama onu nereye ayarlarsa onu bildirir.';
	@override String get placeholderMode => 'Mod';
	@override String get placeholderModeDescription => 'Yer tutucu radyonun başladığı mod, örn. USB, CW, FT8.';
	@override String get placeholderPower => 'Güç (watt)';
	@override String get placeholderPurpose => 'Kayıt amacıyla hangi cihazı kullandığınızı takip etmek için bu radyoyu kullanın';
	@override String get placeholderReplyDelay => 'Yanıt gecikmesi (ms)';
	@override String get placeholderReplyDelayDescription => 'Yer tutucu radyonun bir değişikliği bildirmesinin ne kadar sürdüğü. Boş veya 0 hemen yanıtlar.';
	@override String get cwKeyerField => 'CAT CW keyer';
	@override String get cwKeyerFieldDescription => 'Bu radyonun CAT üzerinden metinden CW gönderip göndermediği. Uygulamanın tanımadığı bir cihaz için kapalı.';
	@override String get voiceMemories => 'Ses hafızaları';
	@override String get voiceMemoriesDescription => 'Radyonun CAT üzerinden kaç ses hafızası oynattığı. Hiç yoksa 0.';
	@override String get voiceMemoriesInvalid => '0 veya daha büyük bir tam sayı';
	@override String get yaesuMeterCapture => 'Ölçer değerlerini yakala';
	@override String get yaesuBinaryMeterCaptureDescription => 'Yayın sırasında radyonun çıkış gücü ölçerini ve yüksek SWR bayrağını okur, ham değerleri günlüğe yazar. Yaesu\'nun yayımlamadığı ölçeği oluşturmak içindir — değerler ölçer olarak gösterilmez.';
	@override String get yaesuMeterCaptureDescription => 'Yayın sırasında radyonun PO, SWR ve ALC ölçerlerini okur, ham değerleri günlüğe yazar. Yaesu\'nun yayımlamadığı ölçeği oluşturmak içindir — değerler ölçer olarak gösterilmez.';
	@override String get telemetryInterval => 'Ölçer okuma aralığı (ms)';
	@override String get telemetryIntervalDescription => 'Radyo yayındayken ölçerlerinin ne sıklıkla okunacağı. Bu bağlantının kaldırabileceği en hızlı değer için boş bırakın, en fazla 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => '${min} ile ${max} arasında tam sayı milisaniye';
	@override String get pollInterval => 'Boşta sorgulama aralığı (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Frekans ve mod değişmezken radyoya ne sıklıkla sorulacağı. ${fallback} ms için boş bırakın.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => '${min} ile ${max} arasında tam sayı milisaniye';
	@override String get advancedSettings => 'Gelişmiş Ayarlar';
	@override String get placeholderSwr => 'SWR değeri';
	@override String get placeholderSwrDescription => 'Bu radyonun yayın sırasında SWR ölçerinde bildirdiği değer. 1.8\'in üzerinde panel uyarır.';
	@override String get placeholderSwrInvalid => '1 veya daha büyük bir sayı';
	@override String get keyerNone => 'Yok';
	@override String get cwDialect => 'CW manipülasyon lehçesi';
	@override String get cwDialectDescription => 'Bu radyonun KY komutunun hangi biçimini aldığı. Yok, CAT üzerinden CW manipülasyonu olmadığı anlamına gelir.';
	@override String get cwDialectKenwood => 'Kenwood (KY, 24\'e tamamlanmış)';
	@override String get cwDialectElecraft => 'Elecraft (KY metni)';
	@override String get voiceDialect => 'Ses keyer lehçesi';
	@override String get voiceDialectDescription => 'Bu radyonun ses hafızalarını CAT üzerinden nasıl oynattığı. Yok, CAT üzerinden ses hafızası olmadığı anlamına gelir. Lehçe seçili ve sayı yoksa lehçenin varsayılan sayısı geçerlidir.';
	@override String get voiceDialectPb => 'Kenwood (PB, TS-590 tarzı)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB ve DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (anahtar dokunuşları)';
	@override String get placeholderDiagnostic => 'Simüle';
	@override String get placeholderWholeNumberInvalid => '0 veya daha büyük bir tam sayı olmalı';
	@override String get placeholderFreqInvalid => 'Sıfırdan büyük, kHz cinsinden bir frekans olmalı';
	@override String get placeholderModeInvalid => 'Bir mod adı olmalı, örn. USB, CW, FT8';
	@override String get switchLayout => 'Düzen';
	@override String get switchLayoutDescription => 'Radyolarınızın anahtarın hangi tarafına takılı olduğu.';
	@override String get switchLayoutRequired => 'Anahtarın nasıl bağlandığını seçin';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Anahtar "${command}" komutunu reddetti (hata ${code})';
	@override String get switchBusyTransmitting => 'Bu port yayında — anten değiştirilmedi';
	@override String get switchNoAntenna => 'Yok';
	@override String switchAntennaFor({required Object port}) => '${port} numaralı porttaki anten';
	@override String get switchAntennaForDescription => 'Antenlerinizden hangisinin anahtardaki bu porta bağlı olduğu.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} Anten, ${radios} Radyo';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} Anten, 1 Radyo';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 Anten, ${radios} Radyo';
	@override String get switchCommonPort => 'Ortak';
	@override String get dcnAddress => 'Cihaz adresi';
	@override String get dcnAddressDescription => 'Modülün DIP anahtarlarında ayarlanan adres. Koaksiyel röle modülü fabrikadan 2 olarak çıkar.';
	@override String get dcnAddressRequired => '1 ile 99 arasında bir cihaz adresi olmalı';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'bant verisini izler';
	@override String get switchPortTransmittingHint => 'yayında — şu anda değiştirilemez';
	@override String get switchCurrentStateHeader => 'Mevcut Durum';
	@override String get switchCurrentStateDescription => 'Her radyo portunun şu anda hangi antende olduğu. Değişiklikler hemen geçerli olur.';
	@override String get switchWiringHeader => 'Kablolama';
	@override String get switchPortInhibitedHint => 'yayın engellendi';
	@override String get configUnreadable => 'Bu radyonun kayıtlı ayarları okunamadı. Ayarlarını açıp yeniden girin ya da kaldırıp tekrar ekleyin.';
	@override String get autoConnectHeld => 'HaLo bu radyoya son bağlandığında yanıt vermeyi bıraktı, bu yüzden bu kez kendiliğinden bağlanmadı. Tekrar denemek için Bağlan\'a basın.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$tr extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Çevrimdışı Veri';
	@override String get noFiles => 'Veri dosyası yok';
	@override String get noFilesDescription => 'Çevrimdışı verilerini buraya indirmek için aktivite veya sorgu uzantılarını etkinleştirin.';
	@override String get refresh => 'Yenile';
	@override String get refreshing => 'Yenileniyor…';
	@override String get updateAll => 'Tümünü Güncelle';
	@override String get updatingAll => 'Tüm veri dosyaları güncelleniyor…';
	@override String get neverDownloaded => 'Hiç indirilmedi';
	@override String get updatedJustNow => 'Az önce güncellendi';
	@override String updatedDaysAgo({required Object days}) => '${days}g önce güncellendi';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '${days}g ${hours}s önce güncellendi';
	@override String updatedHoursAgo({required Object hours}) => '${hours}s önce güncellendi';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '${hours}s ${minutes}d önce güncellendi';
	@override String updatedMinutesAgo({required Object minutes}) => '${minutes}d önce güncellendi';
	@override String lastDownloadRefused({required Object existing, required Object imported}) => 'Son indirmede ${existing} kayıttan yalnızca ${imported} tanesi vardı ve kullanılmadı. Kabul etmek için yenileyin.';
	@override String get extensionsSection => 'Uzantılar';
}

// Path: settings.profiles
class _Translations$settings$profiles$tr extends Translations$settings$profiles$en {
	_Translations$settings$profiles$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Ayarlanmadı';
	@override String get personalInfo => 'Kişisel Bilgiler';
	@override String get personalInfoNote => 'Bu bilgiler, gönderimler için gerektiğinde oluşturulan günlüklere eklenebilir';
	@override String get name => 'İsim';
	@override String get email => 'E-posta';
	@override String get club => 'Kulüp';
	@override String get arrlSection => 'ARRL Bölümü';
	@override String get racSection => 'RAC Bölümü';
	@override String get section => 'Bölüm';
}

// Path: settings.search
class _Translations$settings$search$tr extends Translations$settings$search$en {
	_Translations$settings$search$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Temizle';
	@override String get hint => 'Tercihlerde ara';
}

// Path: settings.developer
class _Translations$settings$developer$tr extends Translations$settings$developer$en {
	_Translations$settings$developer$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Geliştirici uyarılarını, hata ayıklama günlüklerini ve araçlarını etkinleştir.';
	@override String get experiments => 'Deneyler';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} etkin',
		other: '${count} etkin',
	);
	@override String get patchTrack => 'Kod Yaması Kanalı';
	@override String get patchTrackDescription => 'Bu cihazın izlediği kablosuz kod yaması halkası. Daha cesur halkalar düzeltmeleri daha erken ama daha az test edilmiş olarak alır. Kod yamaları bir sonraki yeniden başlatmada uygulanır.';
	@override String get trackStable => 'Kararlı';
	@override String get trackUnstable => 'Kararsız';
	@override String get trackBleeding => 'Deneysel';
	@override String checkingTrack({required Object track}) => '"${track}" kanalında kod yaması kontrol ediliyor…';
	@override String get patchDownloaded => 'Kod yaması indirildi — uygulamak için uygulamayı yeniden başlatın.';
	@override String noNewPatch({required Object track}) => '"${track}" kanalında yeni kod yaması yok.';
	@override String get noPatchInstalled => 'Yüklü kod yaması yok — sürüm ikili dosyası çalışıyor.';
	@override String runningPatch({required Object patch}) => '#${patch} numaralı kod yaması çalışıyor.';
	@override String get deepLinks => 'Derin bağlantılar';
	@override String get registerUrlSchemes => 'URL şemalarını kaydet';
	@override String get registerUrlSchemesDescription => 'com.ham2k:// bağlantılarının uygulamanın bu kopyasını açmasına izin ver';
	@override String get registerUrlSchemesDone => 'Bu kopya artık com.ham2k:// bağlantılarını açıyor';
	@override String registerUrlSchemesFailed({required Object error}) => 'Kaydedilemedi: ${error}';
	@override String get systemInformation => 'Sistem Bilgisi';
	@override String get appVersion => 'Uygulama Sürümü';
	@override String get dataFolder => 'Veri Klasörü';
	@override String get loading => '(yükleniyor…)';
	@override String get panelLoadFailed => 'Bu ayar paneli yüklenemedi.';
	@override String get extDevServer => 'Uzantı Geliştirme Sunucusu';
	@override String get extensionSettings => 'Uzantı Ayarları';
	@override String get extDevServerDescription => 'Uzantıları uygulamaya yerleşik olanlar yerine ağınızdaki bir geliştirme sunucusundan yükleyin ve kaydettikçe yeniden yükleyin.';
	@override String get extDevServerAddress => 'Sunucu adresi';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Bağlan';
	@override String get extDevServerDisconnect => 'Bağlantıyı Kes';
	@override String get extDevServerConnecting => 'Bağlanıyor…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} uzantı sunuluyor: ${keys}',
		other: '${count} uzantı sunuluyor: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Bağlı değil';
	@override String get extDevServerReconnect => 'Açılışta yeniden bağlan';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Son yeniden yükleme: ${key}, ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} uzantı derlenemiyor',
		other: '${count} uzantı derlenemiyor',
	);
	@override String get catalog => 'Uzantı Kataloğu';
	@override String get catalogDescription => 'Kataloğu başka bir sunucudan okuyun — katalog üzerinde çalışırken yerel bir sunucudan. Boş bırakılırsa catalog.ham2k.net kullanılır.';
	@override String get catalogAddress => 'Katalog adresi';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Katalog Arama Kanalları';
	@override String get catalogSearchStable => 'Yalnızca Kararlı';
	@override String get catalogSearchUnstable => 'Kararsız veya daha iyisi';
	@override String get catalogSearchBleeding => 'Deneysel veya daha iyisi';
}

// Path: settings.about
class _Translations$settings$about$tr extends Translations$settings$about$en {
	_Translations$settings$about$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Bildirimler ve Mesajlar';
	@override String get noticesDescription => 'Duyurular ve durum mesajları';
	@override String get releaseNotes => 'Sürüm Notları';
	@override String get copiedVersion => 'Sürüm ayrıntıları panoya kopyalandı';
}

// Path: settings.panels
class _Translations$settings$panels$tr extends Translations$settings$panels$en {
	_Translations$settings$panels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Uygulama Tercihleri';
	@override String get settingsDescription => 'Uygulamayı istediğiniz gibi çalıştırın';
	@override String get commonSettings => 'Genel Tercihler';
	@override String get syncDescription => 'Günlüklerinizi yedekleyin ve cihazlar arasında senkronize edin';
	@override String get accountsDescription => 'Hizmet kimlik bilgileri, çevrimdışı veri ve daha fazlası';
	@override String get extensions => 'Uzantılar ve Özellikler';
	@override String get extensionsDescription => 'Aktiviteler, Yarışmalar, Pano Panelleri ve daha fazla özellik';
	@override String get profilesDescription => 'Operatör çağrı işareti ve istasyon profili';
	@override String get stationProfiles => 'İstasyon Profilleri';
	@override String get developerSettings => 'Geliştirici Ayarları';
	@override String get developerSettingsDescription => 'Hata ayıklama ve geliştirme araçları';
	@override String get about => 'Hakkında';
	@override String get aboutDescription => 'Sürüm, katkıda bulunanlar ve yasal bilgiler';
	@override String get unavailableTitle => 'Bazı ayarlar kullanılamıyor';
	@override String get unavailableText => 'Uzantı çalışma ortamı başlatılamadı, bu yüzden uzantıların eklediği ayarlar eksik.';
	@override String get station => 'İstasyon Yapılandırması';
	@override String get stationDescription => 'CAT kontrolü ve diğer seçenekler';
	@override String get peers => 'Eş Cihazlar';
	@override String get peersDescription => 'Yakındaki diğer cihazlara bağlanın';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$tr extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 hane (FN31pr)';
	@override String get eight => '8 hane (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$tr extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 hane';
	@override String get eight => '8 hane';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$tr extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get date => 'Tarih';
	@override String get time => 'Zaman';
	@override String get freq => 'Frekans';
	@override String get mode => 'Mod';
	@override String get call => 'Çağrı';
	@override String get name => 'İsim';
	@override String get station => 'İstasyon';
	@override String get band => 'Bant';
	@override String get sent => 'Gönd.';
	@override String get rcvd => 'Alın.';
	@override String get grid => 'Grid';
	@override String get state => 'Eyalet';
	@override String get country => 'Ülke';
	@override String get refs => 'Ref.';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$tr extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO Günlüğü';
	@override String get qsosDescription => 'Seçilen çağrı işaretinin tüm operasyonlardaki QSO\'ları.';
	@override String get info => 'Bilgi';
	@override String get infoDescription => 'Toplam QSO sayısı veya seçilen QSO\'nun çağrı işareti sorgusu.';
	@override String get map => 'Harita';
	@override String get mapDescription => 'Seçilen QSO\'nun konumu.';
}

// Path: home.logs.import
class _Translations$home$logs$import$tr extends Translations$home$logs$import$en {
	_Translations$home$logs$import$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Çağrı işaretleri: ${calls}';
	@override String get skippedOne => '1 kayıt okunamadı';
	@override String skippedOther({required Object count}) => '${count} kayıt okunamadı';
	@override String get readingTitle => 'ADIF dosyası okunuyor…';
	@override String get checkingTitle => 'Çift kayıtlar kontrol ediliyor…';
	@override String get importingTitle => 'QSO\'lar içe aktarılıyor…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} / ${total} kontrol edildi';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} / ${total} içe aktarıldı';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$tr extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Günlük ve giriş alanları';
	@override String get infoDescription => 'Çalışılan istasyon hakkında bildiklerimiz';
	@override String get spotsDescription => 'Kümelerden ve aktivite programlarından spotlar';
	@override String get mapDescription => 'QSO\'ların nerede olduğu';
	@override String get clockDescription => 'Herhangi bir saat diliminde bir saat';
	@override String get clockFace => 'Görünüm';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analog';
	@override String get clockZone => 'Saat Dilimi';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Bu cihaz';
	@override String get clockShowSeconds => 'Saniyeleri göster';
	@override String get weatherDescription => 'Operasyon yaptığınız yerde şimdiki ve önümüzdeki sekiz saatin koşulları';
	@override String get weatherUseOperationLocation => 'Operasyonun konumunu kullan';
	@override String get weatherLocation => 'Konum';
	@override String get weatherLocationDescription => 'Bir grid karesi (FN31pr) veya enlem,boylam. \'Operasyonun konumunu kullan\' işaretliyken yok sayılır.';
	@override String get weatherNoLocation => 'Konum ayarlanmadı. Bu panele ayarlarından bir konum verin veya onu konumu olan bir operasyonun içine yerleştirin.';
	@override String weatherBadLocation({required Object location}) => '${location} konumu okunamadı. FN31pr gibi bir grid karesi veya 42.36,-71.06 kullanın.';
	@override String get weatherUnreachable => 'Open-Meteo\'ya ulaşılamadı — ağ yok mu? Birazdan tekrar denenecek.';
	@override String get weatherUnreadable => 'Open-Meteo yanıt verdi, ancak okunabilir bir şeyle değil. Birazdan tekrar denenecek.';
	@override String weatherGusts({required Object speed}) => 'rüzgâr ${speed}';
	@override String get panelAgeNow => 'az önce';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dk önce',
		other: '${count} dk önce',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} sa önce',
		other: '${count} sa önce',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$tr weatherConditions = _Translations$operation$layout$panels$weatherConditions$tr._(_root);
	@override String get websiteDescription => 'Seçtiğiniz bir web sayfası, bir bölmede';
	@override String get websiteUrl => 'Adres';
	@override String get websiteRefresh => 'Yenile';
	@override String get websiteRefreshNever => 'Asla';
	@override String get websiteRefresh1 => 'Her dakika';
	@override String get websiteRefresh5 => 'Her 5 dakikada';
	@override String get websiteRefresh15 => 'Her 15 dakikada';
	@override String get websiteTitle => 'Panel Adı';
	@override String get websiteRefreshNow => 'Şimdi Yenile';
	@override String get websiteNoUrl => 'Henüz adres yok. Bir sayfa seçmek için bu panelin ayarlarını açın.';
	@override String get websiteBadUrl => 'Bu bir web adresine benzemiyor. https:// ile başlaması gerekir';
	@override String get websiteNotHttps => 'Burada yalnızca https:// adresleri gösterilebilir.';
	@override String get websiteUnsupported => 'Bu sistemde web sayfaları bir panelde gösterilemez.';
	@override String get websiteOpenExternally => 'Tarayıcıda Aç';
	@override String websiteLoadFailed({required Object reason}) => 'Sayfa yüklenemedi: ${reason}';
	@override String get remoteScreenDescription => 'Diğer cihazlarınızdan birinin paylaştığı bir ekran, uygulama veya pencere.';
	@override String get remoteScreenTarget => 'Ekran';
	@override String get remoteScreenChoose => 'Bir ekran seçin…';
	@override String get remoteScreenPickerTitle => 'Paylaşılan Ekranlar';
	@override String get remoteScreenPickerEmpty => 'Cihazlarınızın hiçbiri ekran paylaşmıyor. Görmek istediğiniz cihazda Ayarlar → Eş Cihazlar altında Ekranları ve pencereleri paylaş seçeneğini açın.';
	@override String get remoteScreenUnset => 'Ekran seçilmedi. Diğer cihazlarınızın paylaştığı bir ekranı seçmek için bu panelin ayarlarını açın.';
	@override String get remoteScreenConnecting => 'Bağlanıyor…';
	@override String get remoteScreenPeerAway => 'Bu cihaz şu anda bağlı değil.';
	@override String get remoteScreenNotOffered => 'Bu cihaz bu ekranı paylaşmayı durdurdu.';
	@override String get remoteScreenNoListener => 'Bu cihaz bağlantı kabul edemiyor — güvenlik duvarını kontrol edin.';
	@override String get remoteScreenNoLan => 'Ekranlar Bluetooth üzerinden değil, yalnızca yerel ağ üzerinden paylaşılır.';
	@override String get remoteScreenRefused => 'Bu cihaz bu ekranı paylaşmadı.';
	@override String get remoteScreenSettings => 'Panel ayarları';
	@override String get remoteScreenAdjust => 'Görünümü Ayarla';
	@override String get remoteScreenDetail => 'Ayrıntı';
	@override String get remoteScreenDetailStandard => 'Standart';
	@override String get remoteScreenDetailHigh => 'Yüksek';
	@override String get remoteScreenDetailMaximum => 'En yüksek';
	@override String get remoteScreenAdjustDone => 'Tamam';
	@override String get remoteScreenZoomIn => 'Yakınlaştır';
	@override String get remoteScreenZoomOut => 'Uzaklaştır';
	@override String get remoteScreenStopped => 'Bu ekran veya pencere artık gösterilmiyor.';
	@override String get remoteScreenCaptureFailed => 'Bu cihaz o ekranı yakalayamadı — Ekran Kaydı izni gerekebilir.';
	@override String get remoteScreenNoAnswer => 'Bu cihaz yanıt vermedi. Ekran paylaşımı açık olmayabilir.';
	@override String get remoteScreenNoMedia => 'Görüntü için bağlantı açılamadı. Bu cihazdaki güvenlik duvarını kontrol edin.';
	@override String get solarDescription => 'Güneş ve jeomanyetik koşullar, bant bant yayılım ile';
	@override String get solarUnreachable => 'hamqsl.com\'a ulaşılamadı — ağ yok mu? Birazdan tekrar denenecek.';
	@override String get solarUnreadable => 'hamqsl.com yanıt verdi, ancak kullanabileceğimiz bir veriyle değil. Birazdan tekrar denenecek.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Gündüz';
	@override String get solarBandNight => 'Gece';
	@override String get solarBandGood => 'İyi';
	@override String get solarBandFair => 'Orta';
	@override String get solarBandPoor => 'Zayıf';
	@override String solarSources({required Object primary, required Object secondary}) => 'Kaynaklar: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'Bağlantı zorlanıyor — kareler atlanıyor.';
	@override String get remoteScreenStalled => 'Kareler ulaşmıyor — bu bağlantı çok yavaş olabilir.';
	@override String get radioDescription => 'Bir radyonun ön paneli — CAT kontrolüyle frekans, mod ve güç';
	@override String get radioStyle => 'Stil';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Modern';
	@override String get radioRadio => 'Radyo';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — atanmış radyo yok';
	@override String get radioNoRadio => 'Gösterilecek radyo yok. Bu panelin ayarlarından birini seçin veya İstasyon Yapılandırması altında bir tane ekleyin.';
	@override String get radioNotConfigured => 'Bu radyo henüz yapılandırılmadı. Portunu veya adresini İstasyon Yapılandırması altında seçin.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radyo bağlı değil';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Bu radyoyu bağla';
	@override String get radioDisconnect => 'Bu radyonun bağlantısını kes';
	@override String get radioStale => 'VERİ YOK';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'yüksek SWR';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$tr extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kısa dosya adları kullan';
	@override String get descriptionOn => 'Yükleyiciler için kısa adlar, örneğin N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Okunabilir adlar, örneğin 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$tr extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Özel bilgileri dahil et';
	@override String get descriptionOn => 'İsimler, adresler, e-postalar, grid kareleri ve notlar dahil edilir';
	@override String get descriptionOff => 'İsimler, adresler, e-postalar, grid kareleri ve notlar dışarıda bırakılır';
	@override String get note => 'Tam ADIF Dışa Aktarımı her zaman her şeyi içerir';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$tr extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Önce bir e-posta adresi ekleyin';
	@override String get needsEmailBody => 'Ham2K File Stash dosyalarınızı LoFi hesabınızdaki e-posta adresine gönderir ve stash.ham2k.net adresinde bu adresle giriş yaparsınız. Hesabınızda henüz onaylanmış bir adres yok — Ayarlar › Bulut Senkronizasyonu bölümünden ekleyin.';
	@override String get openSyncSettings => 'Bulut Senkronizasyonunu Aç';
	@override String get replaceTitle => 'Son stash değiştirilecek';
	@override String replaceBody({required Object name}) => '“${name}” öğesini 6 saatten kısa bir süre önce gönderdiniz ve henüz indirilmedi. Ücretsiz hesaplar aynı anda bir stash tutar, bu yüzden şimdi göndermek onun yerini alır.';
	@override String get replaceConfirm => 'Yine de Gönder';
	@override String get failedTitle => 'Ham2K File Stash\'e gönderilemedi';
	@override String get sentTitle => 'Ham2K File Stash\'e gönderildi';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Herhangi bir tarayıcıdan **[stash.ham2k.net](https://stash.ham2k.net)** adresini ziyaret ederek bu dosyayı alabilirsiniz.',
		other: 'Herhangi bir tarayıcıdan **[stash.ham2k.net](https://stash.ham2k.net)** adresini ziyaret ederek bu dosyaları alabilirsiniz.',
	);
	@override String get mayHaveArrived => 'Stash\'ten yanıt yok — dosya yine de ulaşmış olabilir. Tekrar göndermeden önce stash.ham2k.net adresini kontrol edin';
	@override String get notSent => 'gönderilmedi';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: 'Bu dosya ulaşmadı:',
		other: 'Bu ${count} dosya ulaşmadı:',
	);
	@override String get emailOffer => 'Ya da kolaylık olması için size doğrudan bağlantı içeren bir e-posta gönderebiliriz.';
	@override String get emailMe => 'Bana Bağlantıyı E-postayla Gönder';
	@override String get emailSent => 'Size indirme bağlantısını e-postayla gönderdik.';
	@override String emailFailed({required Object error}) => 'E-posta gönderilemedi: ${error}';
	@override String get freeTier => 'Ücretsiz hesaplar aynı anda yalnızca bir stash tutabilir. Aboneler istedikleri kadar tutabilir.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count,
		one: '${count} dosya Ham2K File Stash\'e gönderildi (stash.ham2k.net)',
		other: '${count} dosya Ham2K File Stash\'e gönderildi (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$tr extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrika';
	@override String get as => 'Asya';
	@override String get eu => 'Avrupa';
	@override String get na => 'Kuzey Amerika';
	@override String get oc => 'Okyanusya';
	@override String get sa => 'Güney Amerika';
	@override String get an => 'Antarktika';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$tr extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotları Filtrele';
	@override String get band => 'Bant';
	@override String get mode => 'Mod';
	@override String get age => 'Yaş';
	@override String get sources => 'Kaynaklar';
	@override String get continent => 'Kıta';
	@override String get sorting => 'Sıralama';
	@override String get sortByTime => 'Spot Zamanına Göre';
	@override String get sortByFrequency => 'Frekansa Göre';
	@override String get groupByBand => 'Banda Göre Grupla';
	@override String get groupCallsWithNotes => 'Notlu Çağrıları Grupla';
	@override String get sourceNoReply => 'Yanıt yok';
	@override String get sourceError => 'Hata';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$tr extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Kayıt paneli meşgul';
	@override String get editingBody => 'Kaydedilmiş bir QSO\'yu düzenliyorsunuz. Bunun yerine bu spotu mu kaydedelim, yoksa geri dönüp düzenlemeyi mi bitireceksiniz?';
	@override String get composingBody => 'Bir QSO girmeye başladınız. Bunun yerine bu spotu mu kaydedelim, yoksa geri dönüp yazdığınızı mı bitireceksiniz?';
	@override String get goBack => 'Geri dön';
	@override String get clearAndLog => 'Temizle ve spotu kaydet';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$tr extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sol El Modu';
	@override String get descriptionOn => 'Solak kullanıcılar için düzen kullanılıyor';
	@override String get descriptionOff => 'Sağ elini kullananlar için düzen kullanılıyor';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$tr extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ülke Bayrakları';
	@override String get dx => 'Yalnızca DX QSO\'ları için göster';
	@override String get all => 'Tüm QSO\'lar için bayrak göster';
	@override String get none => 'Hiç bayrak gösterme';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$tr extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Yalnızca DX QSO\'ları için bayraklar gösteriliyor';
	@override String get all => 'Tüm QSO\'lar için bayraklar gösteriliyor';
	@override String get none => 'Hiçbir bayrak gösterilmiyor';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$tr extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operatör Öner';
	@override String get descriptionOn => 'Operasyon farklı bir istasyon çağrı işaretiyle yapıldığında çağrı işaretiniz operatör olarak öneriliyor';
	@override String get descriptionOff => 'Siz doldurmadıkça operatör boş bırakılıyor';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$tr extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Yönü Göster';
	@override String get descriptionOn => 'İstasyona tahmini yön gösteriliyor';
	@override String get descriptionOff => 'Yön bilgisi gösterilmiyor';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$tr extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ters yönü de göster';
	@override String get descriptionOn => 'İstasyondan yön de "45° / 225°" şeklinde gösteriliyor';
	@override String get descriptionOff => 'Yalnızca istasyona yön gösteriliyor';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$tr extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sinyal rapor sırasını değiştir';
	@override String get sentFirst => 'Önce Gönd., sonra Alın.';
	@override String get rcvdFirst => 'Önce Alın., sonra Gönd.';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$tr extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'RST girişinde bir sonraki alana geç';
	@override String get descriptionOn => 'RST girildikten sonra sonraki alana geçiliyor';
	@override String get descriptionOff => 'Otomatik geçiş yapılmıyor';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$tr extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Varsayılan rapor — Telefon';
	@override String get description => 'SSB, FM veya AM\'de Gönd. veya Alın. boş bırakıldığında kullanılır';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$tr extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Varsayılan rapor — CW ve veri';
	@override String get description => 'CW, RTTY ve diğer veri modlarında Gönd. veya Alın. boş bırakıldığında kullanılır';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$tr extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Varsayılan rapor — FT8 ve FT4';
	@override String get description => 'FT modlarında Gönd. veya Alın. boş bırakıldığında kullanılır';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$tr extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sayı Satırı';
	@override String get description => 'Kayıt yaparken klavyenin üstünde bir sayı tuşları satırı göster';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$tr extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Eğik çizgi ve nokta tuşu';
	@override String get description => 'Bağlama göre bir tuş ekler: çağrı işaretleri için “/”, sayılar için “.”';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$tr extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tuşa basınca titreşim';
	@override String get description => 'Bir sayı tuşuna dokunduğunuzda dokunsal geri bildirim';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$tr extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get off => 'Devre Dışı';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$tr extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$tr extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'PTT\'yi [\'] ile kontrol et';
	@override String get descriptionOn => 'Telefon modlarında [\'] radyoyu yayına geçirir, tekrar [\'] yayını keser. Bir dakika sonra kendiliğinden yayını keser.';
	@override String get descriptionOff => '[\'] tuşu radyoyu yayına geçirmez.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Yayında';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$tr extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Akıllı VFO Yuvarlama';
	@override String get descriptionOn => 'Düğmeyi çevirmeyi bıraktığınızda frekans makul bir adıma yuvarlanıyor. Yalnızca ses modlarında.';
	@override String get descriptionOff => 'Tam olarak ayarladığınız yerde kalınıyor.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$tr extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Akıllı Yuvarlama: Bekleme süresi';
	@override String get description => 'Frekans yuvarlanmadan önce düğmenin ne kadar süre durması gerektiği. Kısa olursa anında hissedilir; uzun olursa yavaş bir harekete yer bırakır.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$tr extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Akıllı Yuvarlama: Uzun hareket';
	@override String get description => 'En az bu kadar hareket ederseniz, ne kadar yavaş bitirirseniz bitirin frekans tam bir kHz\'e yuvarlanır.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$tr extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Akıllı Yuvarlama: En küçük hareket';
	@override String get description => 'Bundan daha az hareket ederseniz frekans yuvarlanmaz, böylece hassas ayar olduğu gibi kalır.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$tr extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Akıllı Yuvarlama: En yavaş hareket';
	@override String get description => 'Düğmeyi bundan daha yavaş çevirirseniz, uzun bir hareket olmadıkça frekans yuvarlanmaz.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$tr extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Kapalı';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter mesaj gönderir';
	@override String get off => 'Kapalı';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter Mesaj Gönderir: ${state}. Değiştirmek için dokunun.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$tr extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Keyer hızı';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$tr extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW Keyer Mesajları';
	@override String get notSupported => 'Mevcut radyo CW manipülasyonunu desteklemiyor';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Mesaj (${n})';
	@override String get labelField => 'Etiket';
	@override String labelKey({required Object n}) => 'F${n} etiketi';
	@override String get details => 'Ayrıntılar';
	@override String get empty => '(boş)';
	@override String get sets => 'Mesaj Seti';
	@override String get newSet => 'Yeni Set';
	@override String get renameSet => 'Seti Yeniden Adlandır';
	@override String get deleteSet => 'Seti Sil';
	@override String get newSetName => 'İsim';
	@override String get setDefault => 'Varsayılan';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM Mesajları';
	@override String get setSaved => 'Mesajlarım';
	@override String get repeat => '1 Numaralı Mesajı Tekrarla';
	@override String get repeatWait => 'Tekrarlanıyor';
	@override String get keyboard => 'Göndermek için yazın';
	@override String get keyboardField => 'Göndermek için yazın';
	@override String get help => 'Yardım';
	@override String get helpTitle => 'CW Mesajları Yazma';
	@override String get helpIntro => 'Mesajlar aşağıdaki değerlerle şablonlar kullanabilir:';
	@override String get helpOpCall => 'Çağrı işaretiniz';
	@override String get helpQsoCall => 'Onların çağrı işareti — bir // yığınında, kaydedilecek çağrı';
	@override String get helpQsoFullCall => 'Geçerli bir çağrı varsa onların çağrı işareti; kısmi çağrıda boş';
	@override String get helpQsoPartial => 'Kısmi bir çağrı; tam geçerli bir çağrı varsa boş';
	@override String get helpQsoNextCall => 'Bir // yığınında, geçerli tam bir çağrı varsa sıradaki kayıt için seçilecek çağrı';
	@override String get helpQsoNextPartial => 'Bir // yığınında, mevcut QSO kaydedildikten sonraki kısmi çağrı';
	@override String get helpQsoName => 'Onların adı, yazıldığı gibi veya sorgudan';
	@override String get helpQsoState => 'Onların eyaleti, yazıldığı gibi veya sorgudan';
	@override String get helpKeyerMsg => 'Başka bir mesajın içinde, gönderileceği haliyle 1. mesaj. 1 ile 8 arasındaki mesajlar için geçerlidir';
	@override String get helpQsoRst => 'Gönderdiğiniz rapor';
	@override String get helpQsoSerial => 'Seri numarası gönderilen bir yarışmada seri numaranız';
	@override String get helpPad => 'O kadar haneye sıfırla tamamlar: 7, 007 olarak gönderilir';
	@override String get helpCut => 'Kısaltılmış rakamlar, 0 için T ve 9 için N: 599, 5NN olarak gönderilir';
	@override String get helpCutDigits => 'Kısaltılacak rakamları tırnak içinde seçer — 0 T, 1 A, 5 E, 9 N olur';
	@override String get helpFullExample => 'Tam örnek:';
	@override String get helpExample => 'W1AW 5NN TT7 gönderir';
	@override String get helpEsmIntro => 'Enter Mesaj Gönderir açıkken Enter, N1MM\'de olduğu gibi mesajları fonksiyon tuşlarına göre gönderir. ESM Mesajları seti şunlarla başlar:';
	@override String get helpEsmCq => 'Run\'da, çağrı alanı boşken Enter CQ çağırır';
	@override String get helpEsmExchange => 'Değişiminiz: run\'da onların çağrısından sonra, S&P\'de onlar karşılık verdikten sonra';
	@override String get helpEsmThanks => 'Teşekkür, QSO kaydedildikten sonra: yer tutucuları bu QSO\'yu değil, sonrakini belirtir';
	@override String get helpEsmMyCall => 'S&P\'de, karşılık verdiğiniz istasyona çağrınız';
	@override String get helpEsmHisCall => 'Run\'da, değişiminizden önce onların çağrısı';
	@override String get helpEsmAgain => 'Değişimlerinden hiçbir şey alınamadığında tekrar sorar';
	@override String get helpEsmStackThanks => '// yığınları için önerilen F3: TU, QSO kaydedildikten sonra gider; böylece teşekkür eder, ardından yığındaki sonraki istasyonu çağırıp değişiminizi gönderir ya da kısmi bir çağrıyı geri sorar (TU KR?); yığında kimse kalmadıysa yalnızca TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$tr extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Telefon Keyer Mesajları';
	@override String get notSupported => 'Mevcut radyo Telefon mesajlarını desteklemiyor';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Ses hafızası (${n})';
	@override String get labelField => 'Etiket';
	@override String labelKey({required Object n}) => 'Ses hafızası ${n} etiketi';
	@override String durationSeconds({required Object n}) => '${n} sn';
	@override String get emptyOnRadio => 'Boş';
	@override String get notMeasured => 'Uzunluk bilinmiyor';
	@override String get playButton => 'Oynat';
	@override String get recordButton => 'Kaydet';
	@override String get stopButton => 'Durdur';
	@override String get repeat => '1 Numaralı Mesajı Tekrarla';
	@override String recordHelpTitle({required Object model}) => '${model} Notları:';
	@override String namedOnDevice({required Object device}) => 'Bu hafızalar ${device} cihazının radyosunda. İsimleri ve uzunlukları o cihaza aittir.';
	@override String get namedOnRadio => 'Radyoda kayıtlı; radyonun diğer istemcileri de görür.';
	@override String get recordHelpYaesuDvs => 'Radyoda [REC] göstergesini bekleyin, ardından PTT düğmesini basılı tutup mesajınızı kaydedin. İstenmeyen tıklamaları önlemek için PTT\'yi bırakmadan önce uygulamadaki STOP düğmesine basarak bitirin.';
	@override String get recordHelpFt891 => '[REC] göstergesinin en az dört kez yanıp sönmesini bekleyin, ardından PTT düğmesini basılı tutup mesajınızı kaydedin. İstenmeyen tıklamaları önlemek için PTT\'yi bırakmadan önce uygulamadaki STOP düğmesine basarak bitirin.';
	@override String get pill => 'Ses';
	@override String play({required Object n}) => '${n} numaralı hafızayı oynat';
	@override String get stop => 'Durdur';
	@override String record({required Object n}) => '${n} numaralı hafızayı kaydet';
	@override String get stopRecording => 'Kaydı durdur';
	@override String get playing => 'Oynatılıyor…';
	@override String get recording => 'Kaydediliyor…';
	@override String playingMemory({required Object label}) => '${label} oynatılıyor';
	@override String recordingMemory({required Object label}) => '${label} kaydediliyor';
	@override String get doubtful => 'Radyo bunu oynattı mı? Hemen boşta olduğunu bildirdi.';
	@override String get recordOnRadio => 'Hafızaları radyonun kendisinde kaydetmeniz gerekir.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$tr extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Spotlarda Sıfır Vuruştan Kaçın';
	@override String get descriptionOn => 'Bir radyo bağlıyken, CW spotunun birkaç Hz yanına ayarlanıyor; böylece ona cevap veren herkes aynı notadan çağırmaz.';
	@override String get descriptionOff => 'Tam olarak spotlanan frekansa ayarlanıyor.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$tr extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sıfır Vuruş: Kaçınma aralığı';
	@override String get description => 'Spotlanan frekansın her iki yanında ne kadar uzağa ayarlanacağı. Kayma asla sıfıra yakın olmaz — bu yine sıfır vuruş olurdu.';
}

// Path: settings.map.style
class _Translations$settings$map$style$tr extends Translations$settings$map$style$en {
	_Translations$settings$map$style$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Harita Stili';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$tr extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Otomatik';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$tr extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Uygulama kullanım verilerini paylaş';
	@override String get descriptionOn => 'Kullanım, yapılandırma, çökme ve performans verilerini paylaşarak uygulamayı geliştirmemize yardımcı oluyorsunuz';
	@override String get descriptionOff => 'Uygulama kullanım verileri gizli tutuluyor.\nHam2K ekibi çökmeleri veya diğer sorunları tespit edemeyecek.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$tr extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Operasyon verilerini paylaş';
	@override String get descriptionOn => 'Bazı operasyon verileri herkese açık olarak ve diğer kullanıcılarla paylaşılıyor';
	@override String get descriptionOff => 'Operasyon verileri gizli tutuluyor';
}

// Path: settings.station.models
class _Translations$settings$station$models$tr extends Translations$settings$station$models$en {
	_Translations$settings$station$models$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Genel';
	@override String get icomGeneric => 'Icom - Genel';
	@override String get kenwoodGeneric => 'Kenwood - Genel';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Genel';
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
	@override String get rigctld => 'rigctld ile kontrol edilen radyo';
	@override String get rigctldNodeName => 'Radyom (rigctld ile)';
	@override String get flrig => 'flrig ile kontrol edilen radyo';
	@override String get flrigNodeName => 'Radyom (flrig ile)';
	@override String get hrd => 'Ham Radio Deluxe® ile kontrol edilen radyo';
	@override String get hrdNodeName => 'Radyom (HRD ile)';
	@override String get n3fjp => 'N3FJP ile kontrol edilen radyo';
	@override String get n3fjpNodeName => 'Radyom (N3FJP ile)';
	@override String get commander => 'DXLab Commander ile kontrol edilen radyo';
	@override String get commanderNodeName => 'Radyom (Commander ile)';
	@override String get antenna => 'Anten';
	@override String get key => 'CW Anahtarı';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Genel Radyo (Yer Tutucu)';
	@override String get placeholderRadioNodeName => 'Radyom';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Koaksiyel Anahtar';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$tr extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get network => 'Ağ/WiFi';
	@override String get usbSerial => 'USB Seri';
	@override String get wifi => 'Ağ/WiFi';
	@override String get bluetoothSerial => 'Bluetooth Seri';
	@override String get placeholder => 'Yer Tutucu';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$tr extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipol';
	@override String get vertical => 'Dikey';
	@override String get yagiBeam => 'Yagi / Beam';
	@override String get loop => 'Loop';
	@override String get longWire => 'Uzun Tel / EFHW';
	@override String get other => 'Diğer';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$tr extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Düz Anahtar';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (mekanik yarı otomatik)';
	@override String get fullyAutomatic => 'Tam otomatik keyer';
	@override String get singlePaddle => 'Tek Kollu Paddle';
	@override String get dualPaddle => 'Çift Kollu Paddle';
	@override String get computerDriven => 'Bilgisayar Kontrollü';
	@override String get other => 'Diğer';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$tr extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$tr._(TranslationsTr root) : this._root = root, super.internal(root);

	final TranslationsTr _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Bilinmiyor';
	@override String get sunny => 'Güneşli';
	@override String get clear => 'Açık';
	@override String get mainlySunny => 'Çoğunlukla Güneşli';
	@override String get mainlyClear => 'Çoğunlukla Açık';
	@override String get partlyCloudy => 'Parçalı Bulutlu';
	@override String get cloudy => 'Bulutlu';
	@override String get foggy => 'Sisli';
	@override String get rimeFog => 'Kırağılı Sis';
	@override String get lightDrizzle => 'Hafif Çisenti';
	@override String get drizzle => 'Çisenti';
	@override String get heavyDrizzle => 'Yoğun Çisenti';
	@override String get lightFreezingDrizzle => 'Hafif Donan Çisenti';
	@override String get freezingDrizzle => 'Donan Çisenti';
	@override String get lightRain => 'Hafif Yağmur';
	@override String get rain => 'Yağmur';
	@override String get heavyRain => 'Şiddetli Yağmur';
	@override String get lightFreezingRain => 'Hafif Donan Yağmur';
	@override String get freezingRain => 'Donan Yağmur';
	@override String get lightSnow => 'Hafif Kar';
	@override String get snow => 'Kar';
	@override String get heavySnow => 'Yoğun Kar';
	@override String get snowGrains => 'Kar Taneleri';
	@override String get lightShowers => 'Hafif Sağanak';
	@override String get showers => 'Sağanak';
	@override String get heavyShowers => 'Şiddetli Sağanak';
	@override String get lightSnowShowers => 'Hafif Kar Sağanağı';
	@override String get snowShowers => 'Kar Sağanağı';
	@override String get thunderstorm => 'Gök Gürültülü Fırtına';
	@override String get lightThunderstormsWithHail => 'Hafif Dolulu Fırtına';
	@override String get thunderstormWithHail => 'Dolulu Fırtına';
}

/// The flat map containing all translations for locale <tr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsTr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Kaydet',
			'common.ok' => 'Tamam',
			'common.cancel' => 'İptal',
			'common.delete' => 'Sil',
			'common.create' => 'Oluştur',
			'common.error' => 'Hata',
			'common.close' => 'Kapat',
			'common.done' => 'Tamamlandı',
			'common.callsign' => 'Çağrı İşareti',
			'common.clear' => 'Temizle',
			'common.dismiss' => 'Kapat',
			'common.expand' => 'Genişlet',
			'common.collapse' => 'Daralt',
			'onboarding.welcomeTitle' => 'Ham2K Portable Logger\'a hoş geldiniz!',
			'onboarding.welcomeTitleDesktop' => 'Ham2K Power Logger\'a hoş geldiniz!',
			'onboarding.welcomeBody' => 'İhtiyaçlarınıza daha iyi uyum sağlamak için birkaç sorumuz var.',
			'onboarding.skip' => 'Atla',
			'onboarding.kContinue' => 'Devam',
			'onboarding.back' => 'Geri',
			'onboarding.next' => 'İleri',
			'onboarding.done' => 'Tamamlandı',
			'onboarding.callsignTitle' => 'Çağrı işaretiniz nedir?',
			'onboarding.callsignBody' => 'Bu uygulamadan yararlanmak için bir Amatör Telsiz Operatörü Lisansına ihtiyacınız var',
			'onboarding.callsignLabel' => 'Operatörün Çağrı İşareti',
			'onboarding.alreadyHaveAccount' => 'Zaten bir hesabınız var mı?',
			'onboarding.foundSiblingTitle' => 'Mevcut bir hesap bağlansın mı?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Bu cihazda ${app} bulduk. Bu uygulamayı aynı hesaba bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.',
			'onboarding.foundPoloBody' => 'Bu cihazda Ham2K Portable Logger\'ın eski bir sürümünü bulduk. Bu uygulamayı aynı hesaba bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.',
			'onboarding.foundSiblingsBody' => 'Bu cihazda başka Ham2K uygulamaları bulduk. Bu uygulamayı onların hesaplarından birine bağlayın; çağrı işaretiniz ve günlükleriniz buraya gelir.',
			'onboarding.linkWithApp' => ({required Object app}) => '${app} ile bağla',
			'onboarding.linkWithPolo' => 'Eski sürümdeki hesapla bağla',
			'onboarding.setUpFresh' => 'Sıfırdan kur',
			'onboarding.activitiesTitle' => 'Favori Aktiviteler',
			'onboarding.activitiesBody' => 'Bu popüler aktivasyon programlarından herhangi biriyle ilgileniyor musunuz?',
			'onboarding.activitiesFooter' => '(Ayarlar\'da daha fazla seçenek bulabilirsiniz)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Veri ve Gizlilik',
			'onboarding.consentUsageBody' => 'Uygulamayı geliştirmemize yardımcı olmak için performans, çökme ve uygulama kullanım verilerini toplamak istiyoruz.',
			'onboarding.consentUsageLabel' => 'Uygulama kullanım verilerini paylaş',
			'onboarding.consentOperationBody' => 'Bazı özellikler operasyon verilerinizin diğer kullanıcılarla paylaşılmasını içerebilir. İstediğiniz zaman vazgeçebilirsiniz.',
			'onboarding.consentOperationLabel' => 'Operasyon Verilerini Paylaş',
			'onboarding.finishingSetup' => 'Kurulum tamamlanıyor — referans verileri indiriliyor…',
			'startScreen.credits' => 'KI2D ve arkadaşları tarafından',
			'testerOverlay.tape' => 'DİKKAT: YAPIM AŞAMASINDA',
			'testerOverlay.warningTitle' => 'Bu uygulama hâlâ geliştiriliyor',
			'testerOverlay.warningBody' => 'Çoğu özelliğin yüzeyi engebeli ve her yerde takılıp düşme tehlikesi var. Lütfen güncellemeleri düzenli olarak kontrol edin.',
			'testerOverlay.whatsNew' => ({required Object build}) => '${build} sürümündeki yenilikler',
			'testerOverlay.thanks' => 'Bu uygulamayı daha iyi hale getirmemize yardımcı olmak için günlüğünüzü riske attığınız için teşekkürler!',
			'extensionsPanel.categoryActivity' => 'Aktiviteler',
			'extensionsPanel.categoryContest' => 'Yarışmalar',
			'extensionsPanel.categoryLookup' => 'Çağrı İşareti Sorguları',
			'extensionsPanel.categorySpots' => 'Spot Kaynakları',
			'extensionsPanel.categoryDashboard' => 'Pano Panelleri',
			'extensionsPanel.categoryOther' => 'Diğer Uzantılar',
			'extensionsPanel.searchHint' => 'Uzantılarda ara',
			'extensionsPanel.applying' => 'Uzantı değişiklikleri etkinleştiriliyor, bu biraz zaman alabilir…',
			'extensionsPanel.noMatches' => 'Aramanızla eşleşen uzantı yok',
			'extensionsPanel.installFromFile' => 'Dosyadan yükle…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Sürüm ${version}',
			'extensionsPanel.canReach' => 'Bu uzantının bağlanabildikleri',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, canlı bir bağlantı üzerinden',
			'extensionsPanel.canHoldLocalConnection' => 'Yerel ağınızdaki cihazlar, canlı bir bağlantı üzerinden',
			'extensionsPanel.canUseLocation' => 'Konumunuz',
			'extensionsPanel.canReadRadio' => 'Radyonuz, frekansını ve modunu okumak için',
			'extensionsPanel.canControlRadio' => 'Radyonuz, onu kontrol etmek ve onunla yayın yapmak için — ayar, güç, CW, ses hafızaları ve PTT',
			'extensionsPanel.canSetUserAgent' => 'Sunuculara kendi adıyla tanıtma',
			'extensionsPanel.noCapabilities' => 'Uygulama dışında hiçbir şey istemiyor.',
			'extensionsPanel.sandboxNote' => 'Uzantılar korumalı alanda çalışır: dosyalarınıza erişemez ve burada listelenenler dışında ağa çıkamaz.',
			'extensionsPanel.installAction' => 'Yükle',
			'extensionsPanel.updateAction' => 'Güncelle',
			'extensionsPanel.installFailed' => 'Bu uzantı yüklenemedi',
			'extensionsPanel.installedBadge' => 'Yüklü',
			'extensionsPanel.uninstallAction' => 'Kaldır',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '${name} kaldırılsın mı?',
			'extensionsPanel.uninstallBody' => 'Bu uzantı ve ayarları kaldırılacak. Günlükleriniz olduğu gibi kalır.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} yüklendi',
			'extensionsPanel.installDownloading' => 'İndiriliyor…',
			'extensionsPanel.installWaiting' => 'Yükleme bekleniyor…',
			'extensionsPanel.installInstalling' => 'Yükleniyor…',
			'extensionsPanel.installAwaitingApproval' => 'Onayınız bekleniyor…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} zaten yükleniyor.',
			'extensionsPanel.updatedTo' => ({required Object version}) => '${version} sürümüne güncellendi',
			'extensionsPanel.installIncomplete' => ({required Object name}) => '${name} yüklemesi tamamlanmadı. Yeniden yüklenmesi gerekebilir.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name} kaldırılamadı',
			'extensionsPanel.installedFrom' => ({required Object source}) => '${source} kaynağından indirildi',
			'extensionsPanel.dropHint' => 'Yüklemek için bir .h2kext uzantısı bırakın',
			'extensionsPanel.dropOneOnly' => 'Her seferinde bir uzantı bırakın.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} bu uzantı için ${status} döndürdü.',
			'extensionsPanel.downloadTooLarge' => 'Bu indirme bir uzantı olamayacak kadar büyük.',
			'extensionsPanel.downloadNotSecure' => 'Bu indirme güvenli olmayan bir yere yönlendirildi.',
			'extensionsPanel.catalogSection' => 'Katalog',
			'extensionsPanel.catalogLoading' => 'Katalog yükleniyor…',
			'extensionsPanel.catalogUnreachable' => 'Kataloğa ulaşılamıyor',
			'extensionsPanel.builtIn' => 'Dahili',
			'extensionsPanel.updateAvailableBadge' => 'Güncelleme mevcut',
			'extensionsPanel.updatesAvailableTitle' => 'Uzantı güncellemeleri',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => '${name} için bir güncelleme mevcut.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} ve ${count} tane daha güncellenmeli.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} güncellenmeli.',
			'extensionsPanel.pendingUpdatesSection' => 'Bekleyen Güncellemeler',
			'extensionsPanel.updateAllAction' => 'Tümünü güncelle',
			'extensionsPanel.updatesUnderWay' => 'Bu güncellemeler zaten sürüyor.',
			'extensionsPanel.updatesNothingLeft' => 'Uzantılarınız güncel.',
			'extensionsPanel.updatesNoticeAction' => 'Daha fazla bilgi',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} uzantı güncellensin mi?', other: '${count} uzantı güncellensin mi?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Uzantılarınız hazır',
			'extensionsPanel.upgradeDoneBody' => 'Artık Ham2K uzantı kataloğundan geliyorlar, böylece uygulamanın yeni sürümünü beklemeden güncellenebilirler.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Yükseltilmedi: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Çalışmadı: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Hâlâ yüklüler ve Ayarlar › Uzantılar bölümünde işaretliler — orada güncellemek onları geri getirir.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Katalogda bunların doğrudan bir karşılığı yok; kullandıklarınızı kapsayan uzantılar için oraya bakın.',
			'extensionsPanel.retiredQp' => 'QSO Partileri',
			'extensionsPanel.retiredStateparks' => 'Eyalet Parkları Etkinlikleri',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} uzantınız henüz gelmedi. Uzantı kataloğuna bir sonraki ulaşılabildiğinde indirilecekler.',
			'extensionsPanel.runtimeDeadBody' => 'Uzantılarınız başlamadı. Uygulamayı yeniden başlatmak onları geri getirmeli.',
			'extensionsPanel.refusedTitle' => 'Bazı uzantılar çalışmadı',
			'extensionsPanel.upgradeBusyTitle' => 'Kurulum sürüyor',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Uzantılarınız çalışmıyor',
			'extensionsPanel.restoreTitle' => 'Bazı uzantılarınız eksik',
			'extensionsPanel.restoreBody' => 'Yüklediğiniz bu uzantılar bu cihazda yok. Onları Ham2K uzantı kataloğundan yeniden indirebiliriz:',
			'extensionsPanel.restoreFromFile' => 'Bir dosyadan yüklendi. Bunları dosyalarından yeniden yükleyin ya da unutun:',
			'extensionsPanel.restoreOtherCatalog' => 'Farklı bir uzantı kataloğundan yüklendi, bu yüzden burada kullanılamıyor:',
			'extensionsPanel.restoreForget' => 'Unut',
			'extensionsPanel.restoreInstall' => 'Yükle',
			'extensionsPanel.restoreLater' => 'Sonra',
			'extensionsPanel.restoreInstalling' => 'Uzantılarınız yükleniyor…',
			'extensionsPanel.restoreDoneTitle' => 'Uzantılarınız geri geldi',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Yeniden yüklendi: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Bazı uzantılar yüklenemedi',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Yüklenemedi: ${names}. Uygulamayı bir sonraki açışınızda yeniden önereceğiz.',
			'extensionsPanel.restoreBusyBody' => 'Uygulama uzantılarınızı hâlâ kuruyor. Bunları uygulamayı bir sonraki açışınızda yeniden önereceğiz.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Onları yeniden yükledik, ancak uzantılarınız başlamadı. Uygulamayı yeniden başlatmak onları geri getirmeli.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} geri çekildi',
			'extensionsPanel.revokedBody' => 'Katalog bu sürümü geri çekti, bu yüzden devre dışı bırakıldı.',
			'extensionsPanel.downloadHashMismatch' => 'Bu indirme, kataloğun tanımladığı uzantı değil.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object key, required Object version}) => 'Katalogda ${key} için ${version} sürümü yok.',
			'extensionsPanel.catalogLinkUnknown' => 'Bu katalog bağlantısı bir uzantı sürümü belirtmiyor.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Katalogda o kanalda ${key} için bir sürüm yok.',
			'extensionsPanel.installFromLink' => 'Bağlantıdan yükle',
			'extensionsPanel.unstableReleaseWarning' => 'Bu, yayıncısının henüz bitmiş saymadığı kararsız bir sürüm. Hatalı davranabilir ve kararsız güncellemeler almaya devam eder.',
			'extensionsPanel.bleedingReleaseWarning' => 'Bu deneysel bir sürüm: bozulabilecek veya ayarlarını kaybedebilecek, geliştirme aşamasındaki bir çalışma. Deneysel güncellemeler almaya devam eder.',
			'extensionsPanel.channelUnstable' => 'Kararsız',
			'extensionsPanel.channelBleeding' => 'Deneysel',
			'extensionsPanel.followsUnstable' => 'Kararsız ve kararlı sürümleri alır',
			'extensionsPanel.followsBleeding' => 'Deneysel, kararsız ve kararlı sürümleri alır',
			'extensionsPanel.followStableAction' => 'Yalnızca kararlı sürümleri takip et',
			'extensionsPanel.revokedBadge' => 'Geri çekildi',
			'extensionsPanel.refusedBadge' => 'Yüklenmedi',
			'extensionsPanel.downloadNotHttps' => 'Bu indirme güvenli bir bağlantı üzerinden yapılmıyor.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'Bu uzantı için ${source} kaynağına ulaşılamadı.',
			'extensionsPanel.detailsAction' => 'Ayrıntılar',
			'extensionsPanel.installedFromFile' => 'Bir dosyadan yüklendi',
			'extensionsPanel.detailsWhatItDoes' => 'Şunlar için destek sağlar',
			'extensionsPanel.installedPreloaded' => 'Önceden yüklü',
			'extensionsPanel.hookAccount' => 'Hesap girişi',
			'extensionsPanel.hookCallNotes' => 'Çağrı notları',
			'extensionsPanel.hookDataFile' => 'Çevrimdışı veri',
			'extensionsPanel.hookExport' => 'Dışa aktarma',
			'extensionsPanel.hookLookup' => 'Çağrı işareti sorguları',
			'extensionsPanel.hookScoring' => 'Puanlama',
			'extensionsPanel.hookSpots' => 'Spotlar',
			'extensionsPanel.hookHunting' => ({required Object program}) => '${program} avcılığı',
			'extensionsPanel.hookActivating' => ({required Object program}) => '${program} aktivasyonu',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '… ve ${count} uzantı daha', other: '… ve ${count} uzantı daha', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} uzantı mevcut', other: '${count} uzantı mevcut', ), 
			'home.title' => 'Taşınabilir Logger',
			'home.newOperation' => 'Yeni operasyon',
			'home.stationCallsign' => 'İstasyon çağrı işareti',
			'home.titleOptional' => 'Başlık (isteğe bağlı)',
			'home.emptyList' => 'Henüz operasyon yok. Kayda başlamak için bir tane oluşturun.',
			'home.quickLookup' => 'Hızlı Sorgu',
			'home.nav.operations' => 'Operasyonlar',
			'home.nav.chase' => 'Avlama',
			'home.nav.logs' => 'Günlükler',
			'home.nav.maps' => 'Haritalar',
			'home.nav.settings' => 'Ayarlar',
			'home.panels.operations' => 'Operasyon Listesi',
			'home.panels.operationsDescription' => 'Operasyonlarınız, en yenisi önce.',
			'home.panels.version' => 'Mevcut Sürüm',
			'home.panels.versionDescription' => 'Ham2K logosu, bu uygulamanın adı ve çalıştırdığınız sürüm.',
			'home.toggleNav' => 'Gezinme etiketlerini göster veya gizle',
			'home.logs.title' => 'Günlükler',
			'home.logs.titleFor' => 'Günlükler:',
			'home.logs.emptyCallsigns' => 'Henüz kaydedilmiş QSO yok',
			'home.logs.emptyQsos' => ({required Object call}) => '${call} için QSO yok',
			'home.logs.mapNoSelection' => 'Haritada görmek için bir QSO seçin',
			'home.logs.searchHint' => 'Çağrı işareti veya isim ara',
			'home.logs.noSearchMatches' => 'Aramanızla eşleşen QSO yok',
			'home.logs.titleAll' => 'Tüm Günlükler',
			'home.logs.allCallsigns' => 'Tüm çağrı işaretleri',
			'home.logs.noOperation' => 'Bir operasyona ait değil',
			'home.logs.unsavedTitle' => 'Kaydedilmemiş değişiklikler',
			'home.logs.unsavedBody' => 'Bu QSO\'da kaydetmediğiniz değişiklikler var.',
			'home.logs.pendingDeleteBody' => 'Bu QSO silinmek üzere işaretlendi.',
			'home.logs.editGone' => 'Kaydedilmedi: o QSO artık bu günlükte değil.',
			'home.logs.discard' => 'Vazgeç',
			'home.logs.columns.date' => 'Tarih',
			'home.logs.columns.time' => 'Zaman',
			'home.logs.columns.freq' => 'Frekans',
			'home.logs.columns.mode' => 'Mod',
			'home.logs.columns.call' => 'Çağrı',
			'home.logs.columns.name' => 'İsim',
			'home.logs.columns.station' => 'İstasyon',
			'home.logs.columns.band' => 'Bant',
			'home.logs.columns.sent' => 'Gönd.',
			'home.logs.columns.rcvd' => 'Alın.',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'Eyalet',
			'home.logs.columns.country' => 'Ülke',
			'home.logs.columns.refs' => 'Ref.',
			'home.logs.panels.qsos' => 'QSO Günlüğü',
			'home.logs.panels.qsosDescription' => 'Seçilen çağrı işaretinin tüm operasyonlardaki QSO\'ları.',
			'home.logs.panels.info' => 'Bilgi',
			'home.logs.panels.infoDescription' => 'Toplam QSO sayısı veya seçilen QSO\'nun çağrı işareti sorgusu.',
			'home.logs.panels.map' => 'Harita',
			'home.logs.panels.mapDescription' => 'Seçilen QSO\'nun konumu.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Çağrı işaretleri: ${calls}',
			'home.logs.import.skippedOne' => '1 kayıt okunamadı',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} kayıt okunamadı',
			'home.logs.import.readingTitle' => 'ADIF dosyası okunuyor…',
			'home.logs.import.checkingTitle' => 'Çift kayıtlar kontrol ediliyor…',
			'home.logs.import.importingTitle' => 'QSO\'lar içe aktarılıyor…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} / ${total} kontrol edildi',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} / ${total} içe aktarıldı',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'avlıyor',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} ve ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} ve daha fazlası',
			'chase.station.title' => 'Avcı İstasyon',
			'chase.station.stationLabel' => 'İstasyon: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Konum yok',
			'chase.periodInline.today' => 'bugün',
			'chase.periodInline.thisWeek' => 'bu hafta',
			'chase.periodInline.last14Days' => 'son 14 günde',
			'chase.periodInline.thisMonth' => 'bu ay',
			'chase.periodStats.today' => 'Bugünün istatistikleri',
			'chase.periodStats.thisWeek' => 'Bu haftanın istatistikleri',
			'chase.periodStats.last14Days' => 'Son 14 günün istatistikleri',
			'chase.periodStats.thisMonth' => 'Bu ayın istatistikleri',
			'chase.period.today' => 'Bugün',
			'chase.period.thisWeek' => 'Bu Hafta',
			'chase.period.last14Days' => 'Son 14 Gün',
			'chase.period.thisMonth' => 'Bu Ay',
			'chase.goals.title' => 'Avlama Hedefleri',
			'chase.goals.remove' => ({required Object name}) => '${name} avlamayı bırak',
			'chase.goals.extensionsTitle' => 'Avlama içeren uzantılar',
			'chase.panels.logging' => 'QSO\'lar',
			'chase.panels.loggingDescription' => 'Dönem içinde avlanan QSO\'ların üstünde kayıt kontrolleri.',
			'chase.panels.info' => 'Bilgi',
			'chase.panels.infoDescription' => 'Kaydedilen çağrı işareti veya dönemin istatistikleri.',
			'chase.panels.spots' => 'Spotlar',
			'chase.panels.spotsDescription' => 'Havada spotlanmış, avlanmaya hazır istasyonlar.',
			'chase.panels.map' => 'Harita',
			'chase.panels.mapDescription' => 'Dönemin QSO\'ları ve kaydedilen istasyon.',
			'dialogs.operationDetails' => 'Operasyon ayrıntıları',
			'dialogs.activities' => 'Aktiviteler',
			'dialogs.stationCallsign' => 'İstasyon Çağrı İşareti',
			'dialogs.notes' => 'Notlar',
			'dialogs.deleteOperationTitle' => 'Operasyonu Sil',
			'dialogs.purgeTestsTitle' => 'Test Operasyonlarını Temizle',
			'dialogs.purgeTestsBody' => 'Bu, bu Test Operasyonlarını ve QSO\'larını kalıcı olarak siler. Geri alınamaz.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Ayrıca hiçbir operasyona ait olmayan ${count} test QSO\'su.', other: 'Ayrıca hiçbir operasyona ait olmayan ${count} test QSO\'su.', ), 
			'dialogs.purgeTestsAction' => 'Temizle',
			'dialogs.syncAllTitle' => 'Bu cihazın günlüğü değiştirilsin mi?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL bu cihazdaki ${qsos} kaydını yedekleyip temizler, ardından hesabın günlüğünü sunucudan yeniden indirir. Yedek bu cihazın veritabanında kalır.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${n} QSO henüz senkronize edilmedi — sunucu onu hiç almadı ve GERİ GELMEYECEK.', other: '${n} QSO henüz senkronize edilmedi — sunucu onları hiç almadı ve GERİ GELMEYECEKLER.', ), 
			'dialogs.syncAllAction' => 'Sil ve Yeniden Senkronize Et',
			'dialogs.receivedPurgesTitle' => 'Başka Yerde Kaldırılan Test Operasyonları',
			'dialogs.receivedPurgesBody' => 'Bunlar başka bir cihazda Test Operasyonu olarak silindi. Burada da kaldırılsın mı? Bu işlem onları ve QSO\'larını kalıcı olarak siler ve geri alınamaz.',
			'dialogs.receivedPurgesAction' => 'Kaldır',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Geçersiz çağrı işareti: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Geçersiz çağrı işaretleri: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'Şimdiye kadar ${previous} operatörlük yaptı. Yeni QSO\'lar için ${typed} kaydedilecek.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Şimdiye kadar operatör kaydedilmedi. Yeni QSO\'lar için ${typed} kaydedilecek.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Bu operasyonda zaten ${calls} tarafından yapılmış QSO\'lar var. ${typed} yalnızca yenileri için kaydedilecek.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${typed} çağrısını önceden kaydedilmiş QSO\'nun operatörü olarak da kaydet', other: '${typed} çağrısını önceden kaydedilmiş ${count} QSO\'nun tümünün operatörü olarak da kaydet', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Havada birden fazla istasyon kullanılırken ayrı operatörler desteklenmez',
			'dialogs.callChange.contactsUnreadable' => 'Bu operasyonun QSO\'ları okunamadı, bu yüzden burada çağrı işaretini değiştirmek onları güncellemeyi önermeyecek',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Önceden kaydedilmiş QSO\'lar güncellenemedi, bu yüzden hiçbir değişiklik yapılmadı: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object planned, required Object written}) => '${planned} QSO\'dan ${written} tanesi güncellendi — geri kalanı artık bu operasyonda değil',
			'operation.deletedReadOnly' => 'Bu operasyon silinmiş. Kayıt yapmak veya değişiklik yapmak için silmeyi geri alın.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => 'BİLGİ',
			'operation.tabs.spots' => 'SPOTLAR',
			'operation.tabs.map' => 'HARİTA',
			'operation.tabs.qsosPlain' => 'QSO\'lar',
			'operation.tabs.clock' => 'Saat',
			'operation.tabs.weather' => 'Hava Durumu',
			'operation.tabs.website' => 'Web Sitesi',
			'operation.tabs.remoteScreen' => 'Uzak Ekran',
			'operation.tabs.solar' => 'Güneş',
			'operation.tabs.radio' => 'Radyo',
			'operation.positions.nobodyYet' => 'Henüz bu operasyonu paylaşan başka operasyon pozisyonu yok.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Poz: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Başka bir pozisyon',
			'operation.positions.thisDevice' => 'Bizim operasyon pozisyonumuz',
			'operation.positions.nameIn' => ' — ',
			'operation.positions.panelTitle' => 'Pozisyonlar',
			'operation.positions.panelDescription' => 'Bu operasyonu paylaşan her operasyon pozisyonunun şu anda ne kaydettiği.',
			'operation.stationCallsignNone' => 'İstasyon çağrı işareti yok',
			'operation.titleNone' => 'Başlık yok',
			'operation.deleteOperation' => 'Operasyonu sil',
			'operation.loggingControlsStale' => 'Aktivite alanları güncel olmayabilir — yenilemek için operasyonu yeniden açın',
			'operation.locationNone' => 'Ayarlanmadı',
			'operation.generalOperation' => 'Genel Operasyon',
			'operation.titleFor' => ({required Object value}) => '${value} için',
			'operation.titleAt' => ({required Object value}) => '${value} konumunda',
			'operation.segmentNow' => ({required Object description}) => 'Şimdi ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'RST alanlarını göster',
			'operation.menu.showStateField' => 'Eyalet alanını göster',
			'operation.menu.showGridField' => 'Grid alanını göster',
			'operation.menu.showDeletedQsos' => 'Silinen QSO\'ları göster',
			'operation.menu.showDeletedOps' => 'Silinen operasyonları göster',
			'operation.menu.showQsoNumbers' => 'QSO Numaralarını Göster',
			'operation.menu.lookupAllQsos' => 'Tüm QSO\'ları sorgula',
			'operation.menu.loggingSettingsTitle' => 'Kayıt Ayarları',
			'operation.menu.mapSettingsTitle' => 'Harita Ayarları',
			'operation.menu.actionsSection' => 'Eylemler',
			'operation.layout.title' => 'Panel Ekle',
			'operation.layout.availableSection' => 'Kullanılabilir paneller',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} ayarları',
			'operation.layout.panelSettingsAction' => 'Panel Ayarları',
			'operation.layout.viewName' => 'Operasyon Görünümü',
			'operation.layout.viewOptions' => 'Görünüm düzeni seçenekleri',
			'operation.layout.viewTitleBuiltIn' => 'Bu görünüm uygulamaya yerleşiktir, adı da öyle',
			'operation.layout.resetOptions' => 'Varsayılanları Geri Yükle',
			'operation.layout.removePane' => 'Kaldır',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '${panel} varsayılanlarına döndürülsün mü?',
			'operation.layout.resetPaneConfirmBody' => 'Başlığı, üst bilgisi ve boyutu varsayılanlara döner. Düzenin geri kalanı olduğu gibi kalır.',
			'operation.layout.resetViewConfirm' => 'Bu görünüm varsayılan düzenine döndürülsün mü?',
			'operation.layout.resetViewConfirmBody' => 'Paneller varsayılan yerleşimine döner; görünümün ve her panelin seçenekleri de varsayılanlara döner.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} Düzen Ayarları',
			'operation.layout.paneTitle' => 'Başlık',
			'operation.layout.paneShowHeader' => 'Üst bilgiyi göster',
			'operation.layout.paneShowHeaderTabset' => 'Bu bölme bir grubu paylaştığı sürece her zaman gösterilir — diğerlerine üst bilgiden ulaşılır',
			'operation.layout.paneInherit' => 'Uygulamayla aynı',
			'operation.layout.searchHint' => 'Panellerde ara',
			'operation.layout.noPanelsMatch' => 'Aramanızla eşleşen panel yok.',
			'operation.layout.nothingToAdd' => 'Bu görünümde zaten tüm olası paneller var',
			'operation.layout.addPanel' => ({required Object panel}) => '${panel} ekle',
			'operation.layout.showPreview' => ({required Object panel}) => '${panel} önizlemesi',
			'operation.layout.missingExtension' => ({required Object name}) => '"${name}" uzantısı eksik',
			'operation.layout.previewUnavailable' => 'Bu panelin önizleme görüntüsü gösterilemedi.',
			'operation.layout.nestedPaneTitle' => 'Diğer',
			'operation.layout.editLayout' => 'Düzeni Düzenle',
			'operation.layout.saveLayout' => 'Düzeni Kaydet',
			'operation.layout.revertLayout' => 'Düzen değişikliklerini at',
			'operation.layout.done' => 'Tamamlandı',
			'operation.layout.layoutUnreadableTitle' => 'Düzen okunamadı',
			'operation.layout.layoutUnreadableBody' => 'Kayıtlı düzeniniz okunamadı, bu yüzden yerine varsayılan yerleşim gösteriliyor. Siz saklamayı seçene kadar orijinalinizin üzerine kaydedilmez.',
			'operation.layout.layoutUnreadableAction' => 'Bu düzeni kullan',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} görüntülenemedi',
			'operation.layout.panelRenderRetry' => 'Tekrar dene',
			'operation.layout.panelActionFailed' => 'Bu panel eylemi başarısız oldu. Tekrar deneyin.',
			'operation.layout.panels.loggingDescription' => 'Günlük ve giriş alanları',
			'operation.layout.panels.infoDescription' => 'Çalışılan istasyon hakkında bildiklerimiz',
			'operation.layout.panels.spotsDescription' => 'Kümelerden ve aktivite programlarından spotlar',
			'operation.layout.panels.mapDescription' => 'QSO\'ların nerede olduğu',
			'operation.layout.panels.clockDescription' => 'Herhangi bir saat diliminde bir saat',
			'operation.layout.panels.clockFace' => 'Görünüm',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analog',
			'operation.layout.panels.clockZone' => 'Saat Dilimi',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Bu cihaz',
			'operation.layout.panels.clockShowSeconds' => 'Saniyeleri göster',
			'operation.layout.panels.weatherDescription' => 'Operasyon yaptığınız yerde şimdiki ve önümüzdeki sekiz saatin koşulları',
			'operation.layout.panels.weatherUseOperationLocation' => 'Operasyonun konumunu kullan',
			'operation.layout.panels.weatherLocation' => 'Konum',
			'operation.layout.panels.weatherLocationDescription' => 'Bir grid karesi (FN31pr) veya enlem,boylam. \'Operasyonun konumunu kullan\' işaretliyken yok sayılır.',
			'operation.layout.panels.weatherNoLocation' => 'Konum ayarlanmadı. Bu panele ayarlarından bir konum verin veya onu konumu olan bir operasyonun içine yerleştirin.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => '${location} konumu okunamadı. FN31pr gibi bir grid karesi veya 42.36,-71.06 kullanın.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo\'ya ulaşılamadı — ağ yok mu? Birazdan tekrar denenecek.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo yanıt verdi, ancak okunabilir bir şeyle değil. Birazdan tekrar denenecek.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'rüzgâr ${speed}',
			'operation.layout.panels.panelAgeNow' => 'az önce',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dk önce', other: '${count} dk önce', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} sa önce', other: '${count} sa önce', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Bilinmiyor',
			'operation.layout.panels.weatherConditions.sunny' => 'Güneşli',
			'operation.layout.panels.weatherConditions.clear' => 'Açık',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Çoğunlukla Güneşli',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Çoğunlukla Açık',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parçalı Bulutlu',
			'operation.layout.panels.weatherConditions.cloudy' => 'Bulutlu',
			'operation.layout.panels.weatherConditions.foggy' => 'Sisli',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Kırağılı Sis',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Hafif Çisenti',
			'operation.layout.panels.weatherConditions.drizzle' => 'Çisenti',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Yoğun Çisenti',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Hafif Donan Çisenti',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Donan Çisenti',
			'operation.layout.panels.weatherConditions.lightRain' => 'Hafif Yağmur',
			'operation.layout.panels.weatherConditions.rain' => 'Yağmur',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Şiddetli Yağmur',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Hafif Donan Yağmur',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Donan Yağmur',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Hafif Kar',
			'operation.layout.panels.weatherConditions.snow' => 'Kar',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Yoğun Kar',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Kar Taneleri',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Hafif Sağanak',
			'operation.layout.panels.weatherConditions.showers' => 'Sağanak',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Şiddetli Sağanak',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Hafif Kar Sağanağı',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Kar Sağanağı',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Gök Gürültülü Fırtına',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Hafif Dolulu Fırtına',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Dolulu Fırtına',
			'operation.layout.panels.websiteDescription' => 'Seçtiğiniz bir web sayfası, bir bölmede',
			'operation.layout.panels.websiteUrl' => 'Adres',
			'operation.layout.panels.websiteRefresh' => 'Yenile',
			'operation.layout.panels.websiteRefreshNever' => 'Asla',
			'operation.layout.panels.websiteRefresh1' => 'Her dakika',
			'operation.layout.panels.websiteRefresh5' => 'Her 5 dakikada',
			'operation.layout.panels.websiteRefresh15' => 'Her 15 dakikada',
			'operation.layout.panels.websiteTitle' => 'Panel Adı',
			'operation.layout.panels.websiteRefreshNow' => 'Şimdi Yenile',
			'operation.layout.panels.websiteNoUrl' => 'Henüz adres yok. Bir sayfa seçmek için bu panelin ayarlarını açın.',
			'operation.layout.panels.websiteBadUrl' => 'Bu bir web adresine benzemiyor. https:// ile başlaması gerekir',
			'operation.layout.panels.websiteNotHttps' => 'Burada yalnızca https:// adresleri gösterilebilir.',
			'operation.layout.panels.websiteUnsupported' => 'Bu sistemde web sayfaları bir panelde gösterilemez.',
			'operation.layout.panels.websiteOpenExternally' => 'Tarayıcıda Aç',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Sayfa yüklenemedi: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Diğer cihazlarınızdan birinin paylaştığı bir ekran, uygulama veya pencere.',
			'operation.layout.panels.remoteScreenTarget' => 'Ekran',
			'operation.layout.panels.remoteScreenChoose' => 'Bir ekran seçin…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Paylaşılan Ekranlar',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Cihazlarınızın hiçbiri ekran paylaşmıyor. Görmek istediğiniz cihazda Ayarlar → Eş Cihazlar altında Ekranları ve pencereleri paylaş seçeneğini açın.',
			'operation.layout.panels.remoteScreenUnset' => 'Ekran seçilmedi. Diğer cihazlarınızın paylaştığı bir ekranı seçmek için bu panelin ayarlarını açın.',
			'operation.layout.panels.remoteScreenConnecting' => 'Bağlanıyor…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Bu cihaz şu anda bağlı değil.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Bu cihaz bu ekranı paylaşmayı durdurdu.',
			'operation.layout.panels.remoteScreenNoListener' => 'Bu cihaz bağlantı kabul edemiyor — güvenlik duvarını kontrol edin.',
			'operation.layout.panels.remoteScreenNoLan' => 'Ekranlar Bluetooth üzerinden değil, yalnızca yerel ağ üzerinden paylaşılır.',
			'operation.layout.panels.remoteScreenRefused' => 'Bu cihaz bu ekranı paylaşmadı.',
			'operation.layout.panels.remoteScreenSettings' => 'Panel ayarları',
			'operation.layout.panels.remoteScreenAdjust' => 'Görünümü Ayarla',
			'operation.layout.panels.remoteScreenDetail' => 'Ayrıntı',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standart',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Yüksek',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'En yüksek',
			'operation.layout.panels.remoteScreenAdjustDone' => 'Tamam',
			'operation.layout.panels.remoteScreenZoomIn' => 'Yakınlaştır',
			'operation.layout.panels.remoteScreenZoomOut' => 'Uzaklaştır',
			'operation.layout.panels.remoteScreenStopped' => 'Bu ekran veya pencere artık gösterilmiyor.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Bu cihaz o ekranı yakalayamadı — Ekran Kaydı izni gerekebilir.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Bu cihaz yanıt vermedi. Ekran paylaşımı açık olmayabilir.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Görüntü için bağlantı açılamadı. Bu cihazdaki güvenlik duvarını kontrol edin.',
			'operation.layout.panels.solarDescription' => 'Güneş ve jeomanyetik koşullar, bant bant yayılım ile',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com\'a ulaşılamadı — ağ yok mu? Birazdan tekrar denenecek.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com yanıt verdi, ancak kullanabileceğimiz bir veriyle değil. Birazdan tekrar denenecek.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Gündüz',
			'operation.layout.panels.solarBandNight' => 'Gece',
			'operation.layout.panels.solarBandGood' => 'İyi',
			'operation.layout.panels.solarBandFair' => 'Orta',
			'operation.layout.panels.solarBandPoor' => 'Zayıf',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Kaynaklar: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'Bağlantı zorlanıyor — kareler atlanıyor.',
			'operation.layout.panels.remoteScreenStalled' => 'Kareler ulaşmıyor — bu bağlantı çok yavaş olabilir.',
			'operation.layout.panels.radioDescription' => 'Bir radyonun ön paneli — CAT kontrolüyle frekans, mod ve güç',
			'operation.layout.panels.radioStyle' => 'Stil',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Modern',
			'operation.layout.panels.radioRadio' => 'Radyo',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — atanmış radyo yok',
			'operation.layout.panels.radioNoRadio' => 'Gösterilecek radyo yok. Bu panelin ayarlarından birini seçin veya İstasyon Yapılandırması altında bir tane ekleyin.',
			'operation.layout.panels.radioNotConfigured' => 'Bu radyo henüz yapılandırılmadı. Portunu veya adresini İstasyon Yapılandırması altında seçin.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radyo bağlı değil',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Bu radyoyu bağla',
			'operation.layout.panels.radioDisconnect' => 'Bu radyonun bağlantısını kes',
			'operation.layout.panels.radioStale' => 'VERİ YOK',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'yüksek SWR',
			'operation.layout.htmlPanelUnsupported' => 'Bu panel, bu platformun sağlamadığı bir web görünümü gerektirir',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Bu panel, web sürümünün sağlayamadığı bir korumalı alan gerektirir',
			'operation.export.title' => 'Operasyon Dışa Aktarımları',
			'operation.export.syncedOperation' => 'Operasyon senkronize edildi',
			'operation.export.unsyncedOperation' => 'Operasyonda senkronize edilmemiş değişiklikler var',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Bu operasyonda ${count} QSO', other: 'Bu operasyonda ${count} QSO', ), 
			'operation.export.qsosSynced' => ({required Object total}) => '${total} QSO\'nun tümü senkronize edildi',
			'operation.export.qsosPending' => ({required Object total, required Object pending}) => '${total} QSO\'dan ${pending} tanesi senkronizasyon bekliyor',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} olay işareti senkronize edildi',
			'operation.export.eventsPending' => ({required Object total, required Object pending}) => '${total} olay işaretinden ${pending} tanesi bekliyor',
			'operation.export.loading' => 'Dışa aktarma seçenekleri yükleniyor…',
			'operation.export.noOptions' => 'Kullanılabilir dışa aktarma biçimi yok (uzantı çalışma ortamı hâlâ başlıyor olabilir mi?)',
			'operation.export.nothingLogged' => 'Henüz dışa aktarılacak bir şey yok — bu operasyonda QSO yok.',
			'operation.export.share' => 'Paylaş',
			'operation.export.nothingSelected' => 'Hiçbir şey seçilmedi',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosyayı kaydet', other: '${count} dosyayı kaydet', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosyayı paylaş', other: '${count} dosyayı paylaş', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosyayı dışa aktar', other: '${count} dosyayı dışa aktar', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosyayı indir', other: '${count} dosyayı indir', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Birleştirilmiş ${count} dosyayı kaydet', other: 'Birleştirilmiş ${count} dosyayı kaydet', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Birleştirilmiş ${count} dosyayı paylaş', other: 'Birleştirilmiş ${count} dosyayı paylaş', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Birleştirilmiş ${count} dosyayı dışa aktar', other: 'Birleştirilmiş ${count} dosyayı dışa aktar', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Birleştirilmiş ${count} dosyayı indir', other: 'Birleştirilmiş ${count} dosyayı indir', ), 
			'operation.export.saveOne' => ({required Object name}) => '${name} dosyasını kaydet',
			_ => null,
		} ?? switch (path) {
			'operation.export.shareOne' => ({required Object name}) => '${name} dosyasını paylaş',
			'operation.export.exportOne' => ({required Object name}) => '${name} dosyasını dışa aktar',
			'operation.export.downloadOne' => ({required Object name}) => '${name} dosyasını indir',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosyayı Stash\'e kaydet', other: '${count} dosyayı Stash\'e kaydet', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Birleştirilmiş ${count} dosyayı Stash\'e kaydet', other: 'Birleştirilmiş ${count} dosyayı Stash\'e kaydet', ), 
			'operation.export.settingsButton' => 'Dışa aktarma ayarları',
			'operation.export.settingsTitle' => 'Dışa Aktarma Ayarları',
			'operation.export.compactFileNames.title' => 'Kısa dosya adları kullan',
			'operation.export.compactFileNames.descriptionOn' => 'Yükleyiciler için kısa adlar, örneğin N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Okunabilir adlar, örneğin 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Özel bilgileri dahil et',
			'operation.export.includePrivateData.descriptionOn' => 'İsimler, adresler, e-postalar, grid kareleri ve notlar dahil edilir',
			'operation.export.includePrivateData.descriptionOff' => 'İsimler, adresler, e-postalar, grid kareleri ve notlar dışarıda bırakılır',
			'operation.export.includePrivateData.note' => 'Tam ADIF Dışa Aktarımı her zaman her şeyi içerir',
			'operation.export.resultTitle' => 'Dışa aktarma tamamlandı',
			'operation.export.resultFailedTitle' => 'Dışa aktarma başarısız',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosya ${path} konumuna aktarıldı', other: '${count} dosya ${path} konumuna aktarıldı', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosya aktarıldı: ${path}', other: '${count} dosya aktarıldı: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosya paylaşıldı', other: '${count} dosya paylaşıldı', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosya indirildi', other: '${count} dosya indirildi', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Dışa aktarma başarısız: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Önce bir e-posta adresi ekleyin',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash dosyalarınızı LoFi hesabınızdaki e-posta adresine gönderir ve stash.ham2k.net adresinde bu adresle giriş yaparsınız. Hesabınızda henüz onaylanmış bir adres yok — Ayarlar › Bulut Senkronizasyonu bölümünden ekleyin.',
			'operation.export.stash.openSyncSettings' => 'Bulut Senkronizasyonunu Aç',
			'operation.export.stash.replaceTitle' => 'Son stash değiştirilecek',
			'operation.export.stash.replaceBody' => ({required Object name}) => '“${name}” öğesini 6 saatten kısa bir süre önce gönderdiniz ve henüz indirilmedi. Ücretsiz hesaplar aynı anda bir stash tutar, bu yüzden şimdi göndermek onun yerini alır.',
			'operation.export.stash.replaceConfirm' => 'Yine de Gönder',
			'operation.export.stash.failedTitle' => 'Ham2K File Stash\'e gönderilemedi',
			'operation.export.stash.sentTitle' => 'Ham2K File Stash\'e gönderildi',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Herhangi bir tarayıcıdan **[stash.ham2k.net](https://stash.ham2k.net)** adresini ziyaret ederek bu dosyayı alabilirsiniz.', other: 'Herhangi bir tarayıcıdan **[stash.ham2k.net](https://stash.ham2k.net)** adresini ziyaret ederek bu dosyaları alabilirsiniz.', ), 
			'operation.export.stash.mayHaveArrived' => 'Stash\'ten yanıt yok — dosya yine de ulaşmış olabilir. Tekrar göndermeden önce stash.ham2k.net adresini kontrol edin',
			'operation.export.stash.notSent' => 'gönderilmedi',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Bu dosya ulaşmadı:', other: 'Bu ${count} dosya ulaşmadı:', ), 
			'operation.export.stash.emailOffer' => 'Ya da kolaylık olması için size doğrudan bağlantı içeren bir e-posta gönderebiliriz.',
			'operation.export.stash.emailMe' => 'Bana Bağlantıyı E-postayla Gönder',
			'operation.export.stash.emailSent' => 'Size indirme bağlantısını e-postayla gönderdik.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'E-posta gönderilemedi: ${error}',
			'operation.export.stash.freeTier' => 'Ücretsiz hesaplar aynı anda yalnızca bir stash tutabilir. Aboneler istedikleri kadar tutabilir.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} dosya Ham2K File Stash\'e gönderildi (stash.ham2k.net)', other: '${count} dosya Ham2K File Stash\'e gönderildi (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Filtrelerinizle eşleşen spot yok',
			'operation.spots.error' => ({required Object error}) => 'Spotlar yüklenemedi: ${error}',
			'operation.spots.unknownBand' => 'Diğer',
			'operation.spots.auto' => 'Otomatik',
			'operation.spots.autoValue' => ({required Object value}) => 'Otomatik (Şu anda ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Oto)',
			'operation.spots.any' => 'Herhangi',
			'operation.spots.allBands' => 'Tüm Bantlar',
			'operation.spots.allModes' => 'Tüm Modlar',
			'operation.spots.phoneAndCw' => 'Telefon ve CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} spot', other: '${count} spot', ), 
			'operation.spots.spotsCountFiltered' => ({required Object total, required Object count}) => '${total} spottan ${count} tanesi gösteriliyor',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} dakika',
			'operation.spots.callsOfNote' => 'Notlu Çağrılar',
			'operation.spots.yourSpots' => 'Spotlarınız',
			'operation.spots.allSpots' => 'Tüm Spotlar',
			'operation.spots.continents.af' => 'Afrika',
			'operation.spots.continents.as' => 'Asya',
			'operation.spots.continents.eu' => 'Avrupa',
			'operation.spots.continents.na' => 'Kuzey Amerika',
			'operation.spots.continents.oc' => 'Okyanusya',
			'operation.spots.continents.sa' => 'Güney Amerika',
			'operation.spots.continents.an' => 'Antarktika',
			'operation.spots.filters.title' => 'Spotları Filtrele',
			'operation.spots.filters.band' => 'Bant',
			'operation.spots.filters.mode' => 'Mod',
			'operation.spots.filters.age' => 'Yaş',
			'operation.spots.filters.sources' => 'Kaynaklar',
			'operation.spots.filters.continent' => 'Kıta',
			'operation.spots.filters.sorting' => 'Sıralama',
			'operation.spots.filters.sortByTime' => 'Spot Zamanına Göre',
			'operation.spots.filters.sortByFrequency' => 'Frekansa Göre',
			'operation.spots.filters.groupByBand' => 'Banda Göre Grupla',
			'operation.spots.filters.groupCallsWithNotes' => 'Notlu Çağrıları Grupla',
			'operation.spots.filters.sourceNoReply' => 'Yanıt yok',
			'operation.spots.filters.sourceError' => 'Hata',
			'operation.spots.unavailableTitle' => 'Spotlar kullanılamıyor',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} yanıt vermedi.',
			'operation.spots.failedTitle' => 'Spot kaynağı hatası',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} bir hata döndürdü.',
			'operation.spots.slideLogIt' => 'Kaydet',
			'operation.spots.slideIgnore' => 'Yok say',
			'operation.spots.slideRestore' => 'Geri getir',
			'operation.spots.logConflict.title' => 'Kayıt paneli meşgul',
			'operation.spots.logConflict.editingBody' => 'Kaydedilmiş bir QSO\'yu düzenliyorsunuz. Bunun yerine bu spotu mu kaydedelim, yoksa geri dönüp düzenlemeyi mi bitireceksiniz?',
			'operation.spots.logConflict.composingBody' => 'Bir QSO girmeye başladınız. Bunun yerine bu spotu mu kaydedelim, yoksa geri dönüp yazdığınızı mı bitireceksiniz?',
			'operation.spots.logConflict.goBack' => 'Geri dön',
			'operation.spots.logConflict.clearAndLog' => 'Temizle ve spotu kaydet',
			'operation.import.title' => 'Operasyona Veri İçe Aktar',
			'operation.import.importAdifAction' => 'ADIF\'ten QSO İçe Aktar',
			'operation.import.settingsButton' => 'Dinleme ayarları',
			'operation.import.settingsTitle' => 'Diğer Uygulamaları Dinle',
			'operation.import.protocolAddressLabel' => 'Adres',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => '1 ile 65535 arasında bir port girin',
			'operation.import.protocolAddressInvalid' => 'Geçerli bir IP adresi girin (örn. 127.0.0.1 veya 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Veri alınıyor',
			'operation.import.protocolStatusNoData' => 'Son zamanlarda veri alınmadı',
			'operation.import.protocolBindError' => ({required Object error}) => 'Dinleme başlatılamadı: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Gelen QSO\'lar kaydedilemedi ve yeniden deneniyor: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Herhangi (yayın)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Broadcast Data sekmesi → QSO bilgisi için "Enable Broadcasts" seçeneğini işaretleyin. Aynı bilgisayarda çalışıyorsa IP adresini 127.0.0.1, mevcut yerel ağda yayın yapmak için 255.255.255.255 olarak ayarlayın.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reporting sekmesi → UDP Server bölümü → "Accept UDP requests" seçeneğini işaretleyin. Aynı bilgisayarda çalışıyorsa UDP Server\'ı 127.0.0.1 veya 239.239.0.2 gibi bir çoklu yayın adresine ayarlayın ve bu uygulamadaki yukarıdaki yapılandırmada aynı adresi kullanın.',
			'operation.import.listenTitle' => 'Diğer uygulamalardan QSO dinle',
			'operation.import.listenDescriptionOnN1mm' => 'N1MM+ dinleniyor',
			'operation.import.listenDescriptionOnWsjtx' => 'WSJT-X dinleniyor',
			'operation.import.listenDescriptionOnBoth' => 'N1MM+ ve WSJT-X dinleniyor',
			'operation.import.listenDescriptionOff' => 'Kapalı',
			'operation.import.addToOperationTitle' => 'Bu operasyona ekle',
			'operation.import.addToOperationDescriptionOn' => 'Yakalanan QSO\'lar geldikçe bu operasyona eklenir',
			'operation.import.addToOperationDescriptionOff' => 'Yakalanan QSO\'lar siz bunu açana kadar bekletilir',
			'operation.import.pendingSectionTitle' => 'Yakalanan QSO\'lar',
			'operation.import.pendingEmpty' => 'Henüz bir şey yakalanmadı',
			'operation.import.stationMismatch' => ({required Object call}) => '${call} olarak kaydedildi, bu operasyonun istasyonu değil',
			'operation.import.discardAction' => 'At',
			'operation.import.gapDialogTitle' => 'Önceki yakalamalar dahil edilsin mi?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Verideki bir boşluktan önce ${count} QSO daha yakalandı. Onlar da dahil edilsin mi?',
			'operation.import.gapDialogRecentOnly' => 'Yalnızca son olanlar',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => '${count} QSO\'nun tümünü dahil et',
			'map.outlineIssue.link' => 'Sorun mu var?',
			'map.outlineIssue.title' => 'Sınır çizgisi sorunu bildir',
			'map.outlineIssue.reference' => 'Hangi sınır',
			'map.outlineIssue.severity' => 'Ne kadar kötü?',
			'map.outlineIssue.minor' => 'Küçük bir kusur',
			'map.outlineIssue.major' => 'Büyük sorun',
			'map.outlineIssue.explanation' => 'Sorun ne?',
			'map.outlineIssue.explanationHint' => 'Sınırın neyi yanlış gösterdiği ve nerede',
			'map.outlineIssue.send' => 'Gönder',
			'map.outlineIssue.sending' => 'Raporunuz gönderiliyor — teşekkürler',
			'map.outlineIssue.copy' => 'Raporu kopyala',
			'map.outlineIssue.notSent' => 'Rapor gönderilemedi',
			'map.outlineIssue.copied' => 'Rapor kopyalandı',
			'map.outlineIssue.notCopied' => 'Rapor kopyalanamadı',
			'map.outlinesDisclaimer' => 'Sınırlar yalnızca referans amaçlıdır. Kendi araştırmanızı yapın!',
			'map.outlinesCredit' => ({required Object sources}) => 'Sınır çizgileri: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'İdari sınırlar: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Tesisler: ${sources}',
			'map.fullCredits' => 'Tüm veri kaynakları',
			'map.fewerCredits' => 'Daha az kaynak',
			'map.emptyState' => 'Henüz QSO konumu yok.\nGrid karesi, eyalet veya ülke bilgisi olan QSO\'lar burada görünür.',
			'map.unavailable' => 'Harita şu anda kullanılamıyor.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mil',
			'map.flat' => 'Düz',
			'map.globe' => 'Küre',
			'map.zoomIn' => 'Yakınlaştır',
			'map.zoomOut' => 'Uzaklaştır',
			'map.postcard.button' => 'Operasyon Kartpostalı',
			'map.postcard.title' => ({required Object title}) => '${title} için kartpostal',
			'map.postcard.portrait' => 'Dikey',
			'map.postcard.landscape' => 'Yatay',
			'map.postcard.square' => 'Kare',
			'map.postcard.save' => 'Kaydet…',
			'map.postcard.download' => 'İndir',
			'map.postcard.share' => 'Paylaş',
			'map.postcard.copy' => 'Kopyala',
			'map.postcard.copied' => 'Panoya kopyalandı',
			'map.postcard.saved' => ({required Object path}) => '${path} konumuna kaydedildi',
			'map.postcard.downloaded' => ({required Object name}) => '${name} indirildi',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} görüntü ${path} konumuna kaydedildi',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} kaydedildi',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} zaten kaydedilmişti',
			'map.postcard.downloadedMany' => ({required Object count}) => '${count} görüntü indiriliyor — tarayıcı sorarsa izin verin',
			'map.postcard.mapLeftOut' => 'Harita yüklenmedi, bu yüzden dışarıda bırakıldı',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — harita yüklenmedi, bu yüzden dışarıda bırakıldı',
			'map.postcard.continued' => ({required Object title}) => '${title} (devamı)',
			'map.postcard.previousPage' => 'Önceki sayfa',
			'map.postcard.nextPage' => 'Sonraki sayfa',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Sayfa ${page} / ${count}',
			'map.postcard.sectionDays' => 'Her gün',
			'map.postcard.reset' => 'Sıfırla',
			'map.postcard.failed' => ({required Object error}) => 'Kartpostal oluşturulamadı: ${error}',
			'map.postcard.mapNotReady' => 'Harita yüklenmeyi bitirmedi. Bağlantıyı kontrol edip tekrar deneyin.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Kartpostal kaydedilemedi: ${error}',
			'map.postcard.copyFailed' => 'Pano görüntüyü almadı. Tekrar deneyin.',
			'map.postcard.shareFailed' => 'Kartpostal paylaşılamadı. Tekrar deneyin.',
			'map.postcard.fileName' => 'kartpostal',
			'mapsView.title' => 'Haritalar',
			'mapsView.searchHint' => 'Park, zirve ve daha fazlasını ara',
			'mapsView.activities' => 'Aktiviteler',
			'mapsView.layers' => 'Katmanlar',
			'mapsView.baseMap' => 'Temel harita',
			'mapsView.satellite' => 'Uydu (Esri)',
			'mapsView.facilities' => 'Park tesisleri',
			'mapsView.boundaries' => 'İdari sınırlar',
			'mapsView.currentLocation' => 'Mevcut konum',
			'mapsView.noMatches' => ({required Object text}) => '“${text}” ile eşleşen bir şey yok',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${where} konumunda ${count} referans', other: '${where} konumunda ${count} referans', ), 
			'mapsView.startOperation' => 'Bu referanslarla bir operasyon başlat',
			'activitiesView.title' => 'Aktiviteler',
			'activitiesView.activitiesCountZero' => 'Seçili Aktivite Yok',
			'activitiesView.activitiesCountOne' => '1 Aktivite',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Aktivite',
			'activitiesView.empty' => 'Henüz aktivite yok — eklemek için aşağıdaki Öneriler ve Arama\'yı kullanın',
			'activitiesView.removeActivity' => 'Kaldır',
			'activitiesView.openReferenceLink' => ({required Object name}) => '${name} aç',
			'activitiesView.editActivity' => 'Aktiviteyi düzenle',
			'activitiesView.manageExtensions' => 'Uzantıları Yönet',
			'activitiesView.manage' => 'Yönet',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Aktivite Türleri: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Aktivite Türleri: ${first} ve ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Aktivite Türleri: ${first}, ${second} ve ${more} tane daha',
			'activitiesView.reference' => 'Referans',
			'activitiesView.invalidReference' => 'Geçersiz',
			'activitiesView.duplicateReference' => 'Zaten eklendi',
			'activitiesView.searchHint' => 'İsim, referans veya başka bir şeyle arayın…',
			'activitiesView.noSuggestions' => 'Eşleşme yok',
			'activitiesView.noSuggestionsHint' => 'Yukarıda referans adı veya numarasıyla arayın',
			'activitiesView.noSuggestionsExample' => '(örneğin \'trail\' veya \'4556\')',
			'activitiesView.allOptions' => 'Aktivite Türleri',
			'activitiesView.determiningLocation' => 'Mevcut konum belirleniyor…\nYakındaki referansları bulmak için GPS konumu bekleniyor',
			'activitiesView.locationUnavailableTitle' => 'Konum verisi kullanılamıyor',
			'activitiesView.locationDeniedTitle' => 'Konum izni reddedildi',
			'activitiesView.locationBlockedTitle' => 'Konum izni engellendi',
			'activitiesView.noNearbyReason' => 'Yakındaki referanslar belirlenemiyor',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Konumunuzu elle girmek için ${icon} simgesine dokunun\nveya referansları isimle arayın',
			'activitiesView.locationGrantAction' => 'Konum erişimine izin ver',
			'activitiesView.locationSettingsAction' => 'Ayarları Aç',
			'activitiesView.locationSettingsUnavailable' => 'Sistem ayarlarınızdan konum erişimine izin verin',
			'activitiesView.locationGrantRefused' => 'Hâlâ konum yok — sistem yine hayır dedi',
			'activitiesView.searchUnavailableTitle' => 'Aktivite araması kullanılamıyor',
			'activitiesView.searchUnavailableReason' => 'Hiçbir aktivite uzantısı aramayı çalıştıramadı. Birazdan tekrar deneyin.',
			'activitiesView.emptySheet' => 'Eklemek için aşağıdaki öneriler ve aramayı kullanın',
			'activitiesView.exports' => 'Dışa Aktarımlar',
			'activitiesView.exportLogs' => 'Günlükleri Dışa Aktar',
			'activitiesView.tools' => 'Araçlar',
			'activitiesView.toolsTitle' => 'Operasyon Araçları',
			'activitiesView.operationDetails' => 'Operasyon Ayrıntıları',
			'activitiesView.share' => 'Paylaş',
			'activitiesView.archive' => 'Arşivle',
			'activitiesView.deleteOperation' => 'Operasyonu Sil',
			'activitiesView.undeleteOperation' => 'Operasyonu Geri Getir',
			'activitiesView.alreadySelected' => 'Zaten seçili',
			'activitiesView.selected' => 'Seçili',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} / ${count}',
			'activitiesView.previousPick' => 'Önceki eşleşme',
			'activitiesView.nextPick' => 'Sonraki eşleşme',
			'activitiesView.retiredReference' => 'Kullanımdan kalktı',
			'activitiesView.enableExtension' => ({required Object name}) => '${name} etkinleştir',
			'activitiesView.enableExtensionHint' => 'Bu uzantı aramanızla eşleşiyor, ancak şu anda etkin değil',
			'activitiesView.enableExtensionForRefHint' => 'Bu uzantı bu operasyonun referanslarından birini işliyor, ancak şu anda etkin değil',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} çalışmıyor',
			'activitiesView.extensionNotRunningHint' => 'Bu uzantı devre dışı bırakıldı; daha fazla bilgi için Uzantı Ayarları\'nı açın',
			'activitiesView.installExtension' => ({required Object name}) => '${name} yükle',
			'activitiesView.installExtensionHint' => 'Bu uzantı aramanızla eşleşiyor, ancak yüklü değil',
			'activitiesView.onlyCatalogMatches' => 'Eşleşme yok\nKatalogdaki bazı uzantılarda sonuç olabilir.\nOnları aşağıdaki Aktivite Türleri\'nden yükleyin.',
			'activitiesView.setupUnavailable' => 'Bu aktivitenin kurulumu yüklenemedi — Yönet\'ten tekrar deneyin',
			'activitiesView.controlsUnavailableTitle' => 'Aktivite kontrolleri kullanılamıyor',
			'activitiesView.controlsUnavailableReason' => 'Referanslarınız güvende, ancak şu anda düzenlenemiyorlar.',
			'activitiesView.controlsUnavailableRetry' => 'Tekrar dene',
			'activitiesView.onlyDisabledMatches' => 'Eşleşme yok\nBazı kullanılabilir uzantılarda sonuç olabilir.\nOnları aşağıdaki Aktivite Türleri\'nden etkinleştirin.',
			'activitiesView.onlyNotRunningMatches' => 'Eşleşme yok\nSonuç verebilecek bazı uzantılar çalışmıyor.\nAşağıdaki Aktivite Türleri\'ne bakın.',
			'activitiesView.mapToggle' => 'Harita',
			'activitiesView.searchToggle' => 'Ara',
			'activitiesView.addToOperation' => 'Operasyona Ekle',
			'activitiesView.addToOperationShort' => 'Op.\'a Ekle',
			'activitiesView.mapEmptyState' => 'Haritada gösterilecek sonuç yok',
			'activitiesView.mapEmptyStateHint' => 'Listeye geri dönün veya başka bir şey arayın',
			'activitiesView.imports' => 'İçe Aktarımlar',
			'loggingControls.timeUtc' => 'Zaman (UTC)',
			'loggingControls.date' => 'Tarih',
			'loggingControls.now' => 'Şimdi',
			'loggingControls.frequency' => 'Frekans',
			'loggingControls.mode' => 'Mod',
			'loggingControls.theirCall' => 'Onların çağrısı',
			'loggingControls.noteField' => 'Not',
			'loggingControls.todoField' => 'Yapılacak',
			'loggingControls.sent' => 'Gönd.',
			'loggingControls.rcvd' => 'Alın.',
			'loggingControls.more' => 'Diğer',
			'loggingControls.revert' => 'Geri Al',
			'loggingControls.undoDelete' => 'Silmeyi geri al',
			'loggingControls.restore' => 'Geri getir',
			'loggingControls.wipe' => 'Sil',
			'loggingControls.undo' => 'Geri Al',
			'loggingControls.pendingDeleteTapWarning' => 'Bu QSO\'yu silmek için çöp kutusuna bir kez daha dokunun',
			'loggingControls.pendingDeleteClickWarning' => 'Bu QSO\'yu silmek için çöp kutusuna bir kez daha tıklayın',
			'loggingControls.deletedQsoWarning' => 'Silinen QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Bu ${kind} öğesini silmek için çöp kutusuna bir kez daha dokunun',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Bu ${kind} öğesini silmek için çöp kutusuna bir kez daha tıklayın',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Silinen ${kind}',
			'loggingControls.timeControl' => 'Zaman',
			'loggingControls.radioControl' => 'Radyo',
			'loggingControls.powerControl' => 'Güç',
			'loggingControls.notesControl' => 'Notlar',
			'loggingControls.power' => 'Güç',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Kayıt Kontrolleri',
			'loggingControls.spottingControl' => 'Spotlama',
			'loggingControls.spottingSelfControl' => 'Kendini spotlama',
			'loggingControls.spotSelfAt' => ({required Object freq}) => '${freq} üzerinde kendini spotla',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => '${call} istasyonunu ${freq} üzerinde spotla',
			'loggingControls.spotTooLate' => ({required Object call}) => '${call} istasyonunu spotlamak için çok geç',
			'loggingControls.spotNoFreq' => 'Spotlamak için önce bir frekans ayarlayın',
			'loggingControls.spotComment' => 'Yorum',
			'loggingControls.bandOrFreqRequired' => 'Kaydetmeden önce bir frekans veya bant ayarlayın',
			'loggingControls.missingBand' => 'Bant Yok',
			'loggingControls.missingMode' => 'Mod Yok',
			'loggingControls.saveFailed' => ({required Object error}) => 'Kaydedilemedi: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Silinemedi: ${error}',
			'loggingControls.info.noQsos' => 'Henüz QSO yok... hadi havaya çıkalım!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object time, required Object count}) => '${time} içinde ${count}',
			'loggingControls.info.sinceLast' => ({required Object time}) => 'Sonuncudan beri ${time}',
			'loggingControls.info.ratePer10' => ({required Object rate}) => 'Son 10 için ${rate} Q/s',
			'loggingControls.info.ratePer100' => ({required Object rate}) => 'Son 100 için ${rate} Q/s',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} mesafede:',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) mesafede:',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) mesafede:',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} uzakta',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) uzakta',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) uzakta',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Çift!',
			'loggingControls.info.noticeNewBand' => 'Yeni Bant',
			'loggingControls.info.noticeNewMode' => 'Yeni Mod',
			'loggingControls.info.noticeNewDXCC' => 'Yeni DXCC',
			'loggingControls.info.noticeNewState' => 'Yeni Eyalet',
			'loggingControls.info.noticeNewProvince' => 'Yeni İl',
			'loggingControls.info.noticeNewDay' => 'Yeni Gün',
			'loggingControls.info.noticeNewRef' => 'Yeni Ref',
			'loggingControls.info.noticeNewMult' => 'Yeni Mult',
			'loggingControls.info.noticeNewZone' => 'Yeni Bölge',
			'loggingControls.info.noticeInvalidMode' => 'Yanlış Mod',
			'loggingControls.info.noticeInvalidBand' => 'Yanlış Bant',
			'loggingControls.info.noticeInvalidCategory' => 'Çalışılamaz',
			'loggingControls.info.noticeWorkedBefore' => 'Daha Önce Çalışıldı',
			'loggingControls.info.noticeNewPark' => 'Yeni Park',
			'loggingControls.info.noticeNewSection' => 'Yeni Bölüm',
			'loggingControls.info.noticeBonusStation' => 'Bonus İstasyon!',
			'loggingControls.info.noticeMissingExchange' => 'Değişim Yok',
			'loggingControls.info.noticeInvalidExchange' => 'Hatalı Değişim',
			'loggingControls.info.noticeUnknownEvent' => 'Bilinmeyen Etkinlik',
			'loggingControls.info.noticeOurGrid' => 'Grid\'imizi Ayarla',
			'loggingControls.info.noticeRareCounty' => 'Nadir İlçe!',
			'loggingControls.info.noticeOurLocation' => 'İlçemizi Ayarla',
			'loggingControls.info.noticeShortGrid' => 'Grid Çok Kısa',
			'formChrome.untitled' => '(başlıksız)',
			'formChrome.showMore' => 'Daha fazla göster',
			'formChrome.showAll' => 'Tümünü göster',
			'formChrome.showFewer' => 'Daha az göster',
			'formChrome.defaults' => 'Varsayılanlar',
			'formChrome.search' => 'Ara',
			'formChrome.clear' => 'Temizle',
			'formChrome.openPage' => 'Sayfayı aç',
			'formChrome.connected' => 'Bağlı',
			'formChrome.notConnected' => 'Bağlı Değil',
			'formChrome.manage' => 'Yönet',
			'formChrome.connect' => 'Bağlan',
			'formChrome.formTitle' => 'Form',
			'formChrome.addItem' => ({required Object label}) => '${label} ekle',
			'formChrome.editItem' => ({required Object label}) => '${label} düzenle',
			'formChrome.multiselectStatus' => ({required Object total, required Object shown, required Object selected}) => '${total} öğeden ${shown} tanesi gösteriliyor (${selected} seçili)',
			'formChrome.validationError' => ({required Object error}) => 'Doğrulama hatası: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Dönüştürme hatası: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Hata: ${error}',
			'formChrome.removeItem' => 'Kaldır',
			'formChrome.storageUnavailable' => 'Girişler kullanılamıyor',
			'qsoEditForm.title' => 'QSO\'yu Düzenle',
			'qsoEditForm.operatorCall' => 'Operatör',
			'qsoEditForm.position' => 'Pozisyon',
			'qsoEditForm.theirName' => 'İsim',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Eyalet',
			'qsoEditForm.band' => 'Bant',
			'qsoEditForm.notes' => 'Notlar',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Onların bilgisi',
			'qsoEditForm.sectionOur' => 'Bizim bilgimiz',
			'qsoEditForm.sectionNotes' => 'Notlar',
			'qsoEditForm.theirCity' => 'Şehir',
			'qsoEditForm.theirCounty' => 'İlçe',
			'qsoEditForm.theirEntity' => 'Varlık',
			'qsoEditForm.theirCqZone' => 'CQ Bölgesi',
			'qsoEditForm.theirItuZone' => 'ITU Bölgesi',
			'qsoEditForm.theirArrlSection' => 'ARRL Bölümü',
			'qsoEditForm.theirLat' => 'Enlem',
			'qsoEditForm.theirLon' => 'Boylam',
			'qsoEditForm.theirPower' => 'Onların gücü',
			'qsoList.empty' => 'Henüz QSO yok — birini çalışın!',
			'qsoList.bandOrModeWarning' => 'Lütfen bant ve modunuzun doğru olduğundan emin olun',
			'qsoList.today' => 'Bugün',
			'qsoList.yesterday' => 'Dün',
			'qsoList.tomorrow' => 'Yarın',
			'loggingPanel.stats' => 'Operasyon İstatistikleri',
			'loggingPanel.scoring' => 'Puanlama',
			'loggingPanel.dxccEntities' => 'DXCC varlıkları',
			'loggingPanel.statesWorked' => 'Eyaletler',
			'loggingPanel.provincesWorked' => 'İller',
			'loggingPanel.duplicates' => 'Çift Kayıtlar',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Görüntüyü Göster',
			'callInfo.imageUnavailable' => 'Fotoğraf kullanılamıyor',
			'callInfo.photo' => 'Fotoğraf',
			'callInfo.notes' => 'Notlar',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} mesafede:',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) mesafede:',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) mesafede:',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} uzakta',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) uzakta',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) uzakta',
			'callInfo.thisOpCountOne' => 'Bu operasyonda 1 QSO',
			'callInfo.thisOpCountOther' => ({required Object count}) => 'Bu operasyonda ${count} QSO',
			'callInfo.otherOpsCountOne' => 'Diğer operasyonlarda 1 QSO',
			'callInfo.otherOpsCountOther' => ({required Object count}) => 'Diğer operasyonlarda ${count} QSO',
			'callInfo.andMore' => ({required Object count}) => '… ve ${count} tane daha',
			'callInfo.withCall' => ({required Object call}) => '${call} ile',
			'callInfo.fromOperation' => ({required Object where}) => '${where} kaynaklı',
			'callInfo.history.last7days' => ({required Object n}) => 'Son 7 günde ${n}',
			'callInfo.history.today' => ({required Object n}) => 'Bugün ${n}',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => 'Ayarlar',
			'settings.language' => 'Dil',
			'settings.languageSystem' => ({required Object language}) => 'Sistem ayarlarını izle (${language})',
			'settings.theme.title' => 'Tema Modu',
			'settings.theme.system' => 'Sistem ayarlarını izle',
			'settings.theme.light' => 'Açık',
			'settings.theme.dark' => 'Koyu',
			'settings.themeDescription.system' => 'Sistem ayarları izleniyor',
			'settings.themeDescription.light' => 'Her Zaman Açık Mod',
			'settings.themeDescription.dark' => 'Her Zaman Koyu Mod',
			'settings.fontScale' => 'Yazı Tipi Ölçeği',
			'settings.fontScaleOpts.smallestMinusMinus' => 'En Küçük--',
			'settings.fontScaleOpts.smallestMinus' => 'En Küçük-',
			'settings.fontScaleOpts.smallest' => 'En Küçük',
			'settings.fontScaleOpts.smaller' => 'Daha Küçük',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Daha Büyük',
			'settings.fontScaleOpts.largest' => 'En Büyük',
			'settings.fontScaleOpts.largestPlus' => 'En Büyük+',
			'settings.fontScaleOpts.largestPlusPlus' => 'En Büyük++',
			'settings.keepDeviceAwake.title' => 'Cihazı Uyanık Tut',
			'settings.keepDeviceAwake.descriptionOn' => 'Kayıt ekranındayken veya senkronizasyon sürerken uyanık kalınıyor',
			'settings.keepDeviceAwake.descriptionOff' => 'Her zamanki gibi uykuya geçiliyor',
			'settings.layoutDensity' => 'Düzen Yoğunluğu',
			'settings.layoutDensityOpts.auto' => 'Otomatik',
			'settings.layoutDensityOpts.densest' => 'En Sık',
			'settings.layoutDensityOpts.dense' => 'Sık',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Seyrek',
			'settings.layoutDensityOpts.sparsest' => 'En Seyrek',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'pencere çok kısa, ${effective} kullanılıyor',
			'settings.layoutDensityAtLimit' => 'sınırda',
			'settings.distanceUnits' => 'Mesafe Birimleri',
			'settings.distanceUnitsOpts.kilometers' => 'Kilometre',
			'settings.distanceUnitsOpts.miles' => 'Mil',
			'settings.userInterface' => 'Kullanıcı Arayüzü',
			'settings.logging.title' => 'Kayıt',
			'settings.logging.leftieMode.title' => 'Sol El Modu',
			'settings.logging.leftieMode.descriptionOn' => 'Solak kullanıcılar için düzen kullanılıyor',
			'settings.logging.leftieMode.descriptionOff' => 'Sağ elini kullananlar için düzen kullanılıyor',
			'settings.logging.countryFlags.title' => 'Ülke Bayrakları',
			'settings.logging.countryFlags.dx' => 'Yalnızca DX QSO\'ları için göster',
			'settings.logging.countryFlags.all' => 'Tüm QSO\'lar için bayrak göster',
			'settings.logging.countryFlags.none' => 'Hiç bayrak gösterme',
			'settings.logging.countryFlagsDescription.dx' => 'Yalnızca DX QSO\'ları için bayraklar gösteriliyor',
			'settings.logging.countryFlagsDescription.all' => 'Tüm QSO\'lar için bayraklar gösteriliyor',
			'settings.logging.countryFlagsDescription.none' => 'Hiçbir bayrak gösterilmiyor',
			'settings.logging.suggestDefaultOperator.title' => 'Operatör Öner',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Operasyon farklı bir istasyon çağrı işaretiyle yapıldığında çağrı işaretiniz operatör olarak öneriliyor',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Siz doldurmadıkça operatör boş bırakılıyor',
			'settings.logging.showBearing.title' => 'Yönü Göster',
			'settings.logging.showBearing.descriptionOn' => 'İstasyona tahmini yön gösteriliyor',
			'settings.logging.showBearing.descriptionOff' => 'Yön bilgisi gösterilmiyor',
			'settings.logging.showReverseBearing.title' => 'Ters yönü de göster',
			'settings.logging.showReverseBearing.descriptionOn' => 'İstasyondan yön de "45° / 225°" şeklinde gösteriliyor',
			'settings.logging.showReverseBearing.descriptionOff' => 'Yalnızca istasyona yön gösteriliyor',
			'settings.logging.switchSentRcvd.title' => 'Sinyal rapor sırasını değiştir',
			'settings.logging.switchSentRcvd.sentFirst' => 'Önce Gönd., sonra Alın.',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Önce Alın., sonra Gönd.',
			'settings.logging.jumpAfterRST.title' => 'RST girişinde bir sonraki alana geç',
			'settings.logging.jumpAfterRST.descriptionOn' => 'RST girildikten sonra sonraki alana geçiliyor',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Otomatik geçiş yapılmıyor',
			'settings.logging.defaultReport.title' => 'Varsayılan rapor — Telefon',
			'settings.logging.defaultReport.description' => 'SSB, FM veya AM\'de Gönd. veya Alın. boş bırakıldığında kullanılır',
			'settings.logging.defaultReportCW.title' => 'Varsayılan rapor — CW ve veri',
			'settings.logging.defaultReportCW.description' => 'CW, RTTY ve diğer veri modlarında Gönd. veya Alın. boş bırakıldığında kullanılır',
			'settings.logging.defaultReportFT8.title' => 'Varsayılan rapor — FT8 ve FT4',
			'settings.logging.defaultReportFT8.description' => 'FT modlarında Gönd. veya Alın. boş bırakıldığında kullanılır',
			'settings.logging.numbersRow.title' => 'Sayı Satırı',
			'settings.logging.numbersRow.description' => 'Kayıt yaparken klavyenin üstünde bir sayı tuşları satırı göster',
			'settings.logging.numbersRowExtra.title' => 'Eğik çizgi ve nokta tuşu',
			'settings.logging.numbersRowExtra.description' => 'Bağlama göre bir tuş ekler: çağrı işaretleri için “/”, sayılar için “.”',
			'settings.logging.numbersRowVibrate.title' => 'Tuşa basınca titreşim',
			'settings.logging.numbersRowVibrate.description' => 'Bir sayı tuşuna dokunduğunuzda dokunsal geri bildirim',
			'settings.logging.bands' => 'Tercih Edilen Bantlar',
			'settings.logging.modes' => 'Tercih Edilen Modlar',
			'settings.catServer.title' => 'CAT Sunucusu',
			'settings.catServer.description' => 'Diğer uygulamaların (WSJT-X, kayıt programları vb.) radyoyu Ham2K Logger üzerinden kontrol etmesine izin ver.',
			'settings.catServer.protocol' => 'Protokol',
			'settings.catServer.protocolOpts.off' => 'Devre Dışı',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Açık erişim',
			'settings.catServer.openAccessOn' => 'Yerel ağdaki herhangi bir bilgisayar bağlanabilir.',
			'settings.catServer.openAccessOff' => 'Yalnızca bu bilgisayardaki uygulamalar bağlanabilir.',
			'settings.catServer.off' => 'Kapalı.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol} başlatılıyor…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol}, ${port} portunda. Bağlı istemciler: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol}, ${port} portunda, ancak bağlı bir Ana VFO radyosu yok.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol}, ${port} portunu dinleyemiyor: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinleyemiyor: başka bir program onu kullanıyor, çoğu zaman ${protocol} programının kendisi. O programı kapatın veya başka bir port seçin.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinleyemiyor: bu bilgisayar buna izin vermiyor. 1024\'ün üzerinde bir port seçin.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol}, ${port} portunu dinlemeyi bıraktı. Tekrar deneniyor…',
			'settings.radio.title' => 'CAT Kontrolü',
			'settings.radio.loggingAndCat' => 'Kayıt ve CAT',
			_ => null,
		} ?? switch (path) {
			'settings.radio.tuningSection' => 'Ayar',
			'settings.radio.keyerSection' => 'Keyer',
			'settings.radio.servicesSection' => 'Hizmetler',
			'settings.radio.stationConfigurationSection' => 'İstasyon Yapılandırması',
			'settings.radio.moreSettings' => 'Diğer istasyon yapılandırma ayarları',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'PTT\'yi [\'] ile kontrol et',
			'settings.radio.pttKey.descriptionOn' => 'Telefon modlarında [\'] radyoyu yayına geçirir, tekrar [\'] yayını keser. Bir dakika sonra kendiliğinden yayını keser.',
			'settings.radio.pttKey.descriptionOff' => '[\'] tuşu radyoyu yayına geçirmez.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Yayında',
			'settings.radio.smartVfoSnap.title' => 'Akıllı VFO Yuvarlama',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Düğmeyi çevirmeyi bıraktığınızda frekans makul bir adıma yuvarlanıyor. Yalnızca ses modlarında.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Tam olarak ayarladığınız yerde kalınıyor.',
			'settings.radio.snapDebounce.title' => 'Akıllı Yuvarlama: Bekleme süresi',
			'settings.radio.snapDebounce.description' => 'Frekans yuvarlanmadan önce düğmenin ne kadar süre durması gerektiği. Kısa olursa anında hissedilir; uzun olursa yavaş bir harekete yer bırakır.',
			'settings.radio.snapLongMove.title' => 'Akıllı Yuvarlama: Uzun hareket',
			'settings.radio.snapLongMove.description' => 'En az bu kadar hareket ederseniz, ne kadar yavaş bitirirseniz bitirin frekans tam bir kHz\'e yuvarlanır.',
			'settings.radio.snapMinMove.title' => 'Akıllı Yuvarlama: En küçük hareket',
			'settings.radio.snapMinMove.description' => 'Bundan daha az hareket ederseniz frekans yuvarlanmaz, böylece hassas ayar olduğu gibi kalır.',
			'settings.radio.snapMinSpeed.title' => 'Akıllı Yuvarlama: En yavaş hareket',
			'settings.radio.snapMinSpeed.description' => 'Düğmeyi bundan daha yavaş çevirirseniz, uzun bir hareket olmadıkça frekans yuvarlanmaz.',
			'settings.radio.enterSends.pillOff' => 'ESM Kapalı',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter mesaj gönderir',
			'settings.radio.enterSends.off' => 'Kapalı',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter Mesaj Gönderir: ${state}. Değiştirmek için dokunun.',
			'settings.radio.keyerSpeed.title' => 'Keyer hızı',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW Keyer Mesajları',
			'settings.radio.cwMessages.notSupported' => 'Mevcut radyo CW manipülasyonunu desteklemiyor',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Mesaj (${n})',
			'settings.radio.cwMessages.labelField' => 'Etiket',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n} etiketi',
			'settings.radio.cwMessages.details' => 'Ayrıntılar',
			'settings.radio.cwMessages.empty' => '(boş)',
			'settings.radio.cwMessages.sets' => 'Mesaj Seti',
			'settings.radio.cwMessages.newSet' => 'Yeni Set',
			'settings.radio.cwMessages.renameSet' => 'Seti Yeniden Adlandır',
			'settings.radio.cwMessages.deleteSet' => 'Seti Sil',
			'settings.radio.cwMessages.newSetName' => 'İsim',
			'settings.radio.cwMessages.setDefault' => 'Varsayılan',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM Mesajları',
			'settings.radio.cwMessages.setSaved' => 'Mesajlarım',
			'settings.radio.cwMessages.repeat' => '1 Numaralı Mesajı Tekrarla',
			'settings.radio.cwMessages.repeatWait' => 'Tekrarlanıyor',
			'settings.radio.cwMessages.keyboard' => 'Göndermek için yazın',
			'settings.radio.cwMessages.keyboardField' => 'Göndermek için yazın',
			'settings.radio.cwMessages.help' => 'Yardım',
			'settings.radio.cwMessages.helpTitle' => 'CW Mesajları Yazma',
			'settings.radio.cwMessages.helpIntro' => 'Mesajlar aşağıdaki değerlerle şablonlar kullanabilir:',
			'settings.radio.cwMessages.helpOpCall' => 'Çağrı işaretiniz',
			'settings.radio.cwMessages.helpQsoCall' => 'Onların çağrı işareti — bir // yığınında, kaydedilecek çağrı',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Geçerli bir çağrı varsa onların çağrı işareti; kısmi çağrıda boş',
			'settings.radio.cwMessages.helpQsoPartial' => 'Kısmi bir çağrı; tam geçerli bir çağrı varsa boş',
			'settings.radio.cwMessages.helpQsoNextCall' => 'Bir // yığınında, geçerli tam bir çağrı varsa sıradaki kayıt için seçilecek çağrı',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'Bir // yığınında, mevcut QSO kaydedildikten sonraki kısmi çağrı',
			'settings.radio.cwMessages.helpQsoName' => 'Onların adı, yazıldığı gibi veya sorgudan',
			'settings.radio.cwMessages.helpQsoState' => 'Onların eyaleti, yazıldığı gibi veya sorgudan',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Başka bir mesajın içinde, gönderileceği haliyle 1. mesaj. 1 ile 8 arasındaki mesajlar için geçerlidir',
			'settings.radio.cwMessages.helpQsoRst' => 'Gönderdiğiniz rapor',
			'settings.radio.cwMessages.helpQsoSerial' => 'Seri numarası gönderilen bir yarışmada seri numaranız',
			'settings.radio.cwMessages.helpPad' => 'O kadar haneye sıfırla tamamlar: 7, 007 olarak gönderilir',
			'settings.radio.cwMessages.helpCut' => 'Kısaltılmış rakamlar, 0 için T ve 9 için N: 599, 5NN olarak gönderilir',
			'settings.radio.cwMessages.helpCutDigits' => 'Kısaltılacak rakamları tırnak içinde seçer — 0 T, 1 A, 5 E, 9 N olur',
			'settings.radio.cwMessages.helpFullExample' => 'Tam örnek:',
			'settings.radio.cwMessages.helpExample' => 'W1AW 5NN TT7 gönderir',
			'settings.radio.cwMessages.helpEsmIntro' => 'Enter Mesaj Gönderir açıkken Enter, N1MM\'de olduğu gibi mesajları fonksiyon tuşlarına göre gönderir. ESM Mesajları seti şunlarla başlar:',
			'settings.radio.cwMessages.helpEsmCq' => 'Run\'da, çağrı alanı boşken Enter CQ çağırır',
			'settings.radio.cwMessages.helpEsmExchange' => 'Değişiminiz: run\'da onların çağrısından sonra, S&P\'de onlar karşılık verdikten sonra',
			'settings.radio.cwMessages.helpEsmThanks' => 'Teşekkür, QSO kaydedildikten sonra: yer tutucuları bu QSO\'yu değil, sonrakini belirtir',
			'settings.radio.cwMessages.helpEsmMyCall' => 'S&P\'de, karşılık verdiğiniz istasyona çağrınız',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Run\'da, değişiminizden önce onların çağrısı',
			'settings.radio.cwMessages.helpEsmAgain' => 'Değişimlerinden hiçbir şey alınamadığında tekrar sorar',
			'settings.radio.cwMessages.helpEsmStackThanks' => '// yığınları için önerilen F3: TU, QSO kaydedildikten sonra gider; böylece teşekkür eder, ardından yığındaki sonraki istasyonu çağırıp değişiminizi gönderir ya da kısmi bir çağrıyı geri sorar (TU KR?); yığında kimse kalmadıysa yalnızca TU',
			'settings.radio.voiceMessages.title' => 'Telefon Keyer Mesajları',
			'settings.radio.voiceMessages.notSupported' => 'Mevcut radyo Telefon mesajlarını desteklemiyor',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Ses hafızası (${n})',
			'settings.radio.voiceMessages.labelField' => 'Etiket',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Ses hafızası ${n} etiketi',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} sn',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Boş',
			'settings.radio.voiceMessages.notMeasured' => 'Uzunluk bilinmiyor',
			'settings.radio.voiceMessages.playButton' => 'Oynat',
			'settings.radio.voiceMessages.recordButton' => 'Kaydet',
			'settings.radio.voiceMessages.stopButton' => 'Durdur',
			'settings.radio.voiceMessages.repeat' => '1 Numaralı Mesajı Tekrarla',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} Notları:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Bu hafızalar ${device} cihazının radyosunda. İsimleri ve uzunlukları o cihaza aittir.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Radyoda kayıtlı; radyonun diğer istemcileri de görür.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Radyoda [REC] göstergesini bekleyin, ardından PTT düğmesini basılı tutup mesajınızı kaydedin. İstenmeyen tıklamaları önlemek için PTT\'yi bırakmadan önce uygulamadaki STOP düğmesine basarak bitirin.',
			'settings.radio.voiceMessages.recordHelpFt891' => '[REC] göstergesinin en az dört kez yanıp sönmesini bekleyin, ardından PTT düğmesini basılı tutup mesajınızı kaydedin. İstenmeyen tıklamaları önlemek için PTT\'yi bırakmadan önce uygulamadaki STOP düğmesine basarak bitirin.',
			'settings.radio.voiceMessages.pill' => 'Ses',
			'settings.radio.voiceMessages.play' => ({required Object n}) => '${n} numaralı hafızayı oynat',
			'settings.radio.voiceMessages.stop' => 'Durdur',
			'settings.radio.voiceMessages.record' => ({required Object n}) => '${n} numaralı hafızayı kaydet',
			'settings.radio.voiceMessages.stopRecording' => 'Kaydı durdur',
			'settings.radio.voiceMessages.playing' => 'Oynatılıyor…',
			'settings.radio.voiceMessages.recording' => 'Kaydediliyor…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '${label} oynatılıyor',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '${label} kaydediliyor',
			'settings.radio.voiceMessages.doubtful' => 'Radyo bunu oynattı mı? Hemen boşta olduğunu bildirdi.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Hafızaları radyonun kendisinde kaydetmeniz gerekir.',
			'settings.radio.avoidZeroBeat.title' => 'Spotlarda Sıfır Vuruştan Kaçın',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Bir radyo bağlıyken, CW spotunun birkaç Hz yanına ayarlanıyor; böylece ona cevap veren herkes aynı notadan çağırmaz.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Tam olarak spotlanan frekansa ayarlanıyor.',
			'settings.radio.zeroBeatRange.title' => 'Sıfır Vuruş: Kaçınma aralığı',
			'settings.radio.zeroBeatRange.description' => 'Spotlanan frekansın her iki yanında ne kadar uzağa ayarlanacağı. Kayma asla sıfıra yakın olmaz — bu yine sıfır vuruş olurdu.',
			'settings.help.title' => 'Yardım ve Kaynaklar',
			'settings.help.description' => 'Topluluk ve destek',
			'settings.help.forums' => 'Ham2K Forumları',
			'settings.help.forumsDescription' => 'Yardım bulun, geri bildirim verin, fikirleri tartışın…',
			'settings.help.chat' => 'Ham2K Sohbeti',
			'settings.help.chatDescription' => 'Çevrimiçi topluluğumuz için Discord sunucusu',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Videolar ve canlı yayınlar',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Çünkü fotoğrafın fazlası olmaz…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Haber ve güncellemeler için bizi takip edin',
			'settings.help.contact' => 'İletişim',
			'settings.help.contactDescription' => 'help@ham2k.com — ama önce Forumları veya Sohbeti deneyin!',
			'settings.exports.title' => 'Dışa Aktarımlar',
			'settings.map.title' => 'Haritalar',
			'settings.map.style.title' => 'Harita Stili',
			'settings.map.styleOpts.automatic' => 'Otomatik',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Gizlilik',
			'settings.privacy.shareAppData.title' => 'Uygulama kullanım verilerini paylaş',
			'settings.privacy.shareAppData.descriptionOn' => 'Kullanım, yapılandırma, çökme ve performans verilerini paylaşarak uygulamayı geliştirmemize yardımcı oluyorsunuz',
			'settings.privacy.shareAppData.descriptionOff' => 'Uygulama kullanım verileri gizli tutuluyor.\nHam2K ekibi çökmeleri veya diğer sorunları tespit edemeyecek.',
			'settings.privacy.shareOpData.title' => 'Operasyon verilerini paylaş',
			'settings.privacy.shareOpData.descriptionOn' => 'Bazı operasyon verileri herkese açık olarak ve diğer kullanıcılarla paylaşılıyor',
			'settings.privacy.shareOpData.descriptionOff' => 'Operasyon verileri gizli tutuluyor',
			'settings.privacy.privacyPolicy' => 'Gizlilik Politikası',
			'settings.privacy.termsOfService' => 'Hizmet Şartları',
			'settings.operatorCall' => 'Operatör Çağrı İşareti',
			'settings.sync.title' => 'Bulut Senkronizasyonu',
			'settings.sync.moreSettings' => 'Diğer senkronizasyon ayarları',
			'settings.sync.enable' => 'Senkronizasyonu Etkinleştir',
			'settings.sync.deviceKey' => 'Cihaz Anahtarı',
			'settings.peers.title' => 'Eş Cihazlar',
			'settings.peers.enable' => 'Diğer cihazlara bağlan',
			'settings.peers.enableDescription' => 'Yerel ağ üzerinden diğer cihazlarla operasyon, kayıt, CAT ve GPS paylaşımına izin ver',
			'settings.peers.bleEnable' => 'Bluetooth ile bağlan',
			'settings.peers.bleDescription' => 'Yerel ağ olmasa bile bağlanmak için Bluetooth LE kullan',
			'settings.peers.thisDevice' => 'Bu Cihaz',
			'settings.peers.deviceName' => 'İsim',
			'settings.peers.deviceNameHint' => 'Bu cihazın diğer cihazlarda nasıl göründüğü',
			'settings.peers.pairedDevices' => 'Bağlı Cihazlar',
			'settings.peers.noPairedDevices' => 'Henüz bağlı cihaz yok. Bağlamak için bunu bu ağdaki başka bir cihazda da açın.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Bağlı cihazlarınız okunamıyor: ${error}',
			'settings.peers.nearby' => 'Yakında',
			'settings.peers.connected' => 'Bağlı',
			'settings.peers.viaBluetooth' => 'Bluetooth üzerinden',
			'settings.peers.connecting' => 'Bağlanıyor…',
			'settings.peers.syncing' => 'Senkronize ediliyor…',
			'settings.peers.waitingForThem' => 'Diğer cihaz bekleniyor',
			'settings.peers.notConnected' => 'Bağlı değil',
			'settings.peers.wantsToPair' => 'bu operasyonu paylaşmak istiyor',
			'settings.peers.allow' => 'İzin ver',
			'settings.peers.link' => 'Bağla',
			'settings.peers.reject' => 'Reddet',
			'settings.peers.forget' => 'Unut',
			'settings.peers.forgetTitle' => ({required Object name}) => '${name} unutulsun mu?',
			'settings.peers.forgetBody' => 'Bu cihazla senkronizasyonu durduracak. Daha sonra yeniden izin verebilirsiniz; önceden kaydedilmiş QSO\'lar korunur.',
			'settings.peers.pairTitle' => ({required Object name}) => '${name} ile bağla',
			'settings.peers.pairBody' => 'Bu cihaz yerel ağınızda ve bağlanmak istiyor.',
			'settings.peers.pairBodyBle' => 'Bu cihaz yakında ve Bluetooth LE üzerinden bağlanmak istiyor.',
			'settings.peers.pairIdLabel' => 'Cihaz Kimliği',
			'settings.peers.pairWarning' => 'Yalnızca tanıdığınız cihazlarla bağlantı kurun. Bu ağdaki herhangi bir cihaz istek gönderebilir.',
			'settings.peers.pairWarningBle' => 'Yalnızca tanıdığınız cihazlarla bağlantı kurun. Yakındaki herhangi bir cihaz istek gönderebilir.',
			'settings.peers.problem' => ({required Object error}) => 'Yerel ağa ulaşılamıyor: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => '${device} cihazına bağlandı',
			'settings.peers.statusLost' => ({required Object device}) => '${device} ile bağlantı kesildi',
			'settings.peers.statusPerma' => ({required Object linked, required Object connected}) => 'Eş Cihazlar: ${linked} cihazdan ${connected} tanesi bağlı',
			'settings.peers.screenEnable' => 'Ekranları ve pencereleri paylaş',
			'settings.peers.screenDescription' => 'Diğer cihazların bu bilgisayardaki ekranları veya pencereleri göstermesine izin ver',
			'settings.peers.screenSources' => 'Ekranlar ve Pencereler',
			'settings.peers.screenRefresh' => 'Listeyi yenile',
			'settings.peers.screenUnsupportedPlatform' => 'Bu cihaz ekranını paylaşamaz. macOS paylaşabilir; her cihaz başka bir cihazın paylaştığı ekranı gösterebilir.',
			'settings.peers.screenUnsupportedVersion' => 'Ekran paylaşmak için macOS 12.3 veya üstü gerekir. Bu cihaz yine de başka bir cihazın paylaştığı ekranı gösterebilir.',
			'settings.peers.screenNeedsPermission' => 'Bu uygulamanın ekran paylaşabilmesi için macOS\'in ekranı kaydetme izninize ihtiyacı var.',
			'settings.peers.screenGrantPermission' => 'İzin iste',
			'settings.peers.screenRelaunchAfterGranting' => 'Sistem Ayarları\'nda Gizlilik ve Güvenlik → Ekran Kaydı altında izin verin, ardından bu uygulamadan çıkıp yeniden açın — macOS değişikliği uygulamaya yalnızca bir sonraki açılışta bildirir.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Ekran paylaşımı: ${error}',
			'settings.peers.screenChooseTitle' => 'Neyin Paylaşılacağını Seçin',
			'settings.peers.screenChooseButton' => 'Neyin paylaşılacağını seçin…',
			'settings.peers.screenTabScreens' => 'Ekranlar',
			'settings.peers.screenTabApps' => 'Uygulamalar',
			'settings.peers.screenTabWindows' => 'Pencereler',
			'settings.peers.screenTabEmpty' => 'Bu türden bir şey bulunamadı.',
			'settings.peers.screenSharedSummaryNone' => 'Henüz bir şey seçilmedi.',
			'settings.peers.screenThisDevice' => 'Bu cihaz',
			'settings.peers.screenSharedTo' => ({required Object devices}) => '${devices} üzerinde gösteriliyor',
			'settings.peers.screenSharedToNobody' => 'Gösterilmiyor',
			'settings.peers.screenStopSharing' => ({required Object name}) => '${name} paylaşımını durdur',
			'settings.developerMode' => 'Geliştirici Modu',
			'settings.syncPanel.configuration' => 'Senkronizasyon Yapılandırması',
			'settings.syncPanel.enableTitle' => 'Ham2K Log Filer ile senkronize et',
			'settings.syncPanel.enabledDescription' => 'Günlüğünüz yedekleniyor ve cihazlar arasında senkronize ediliyor',
			'settings.syncPanel.disabledDescription' => 'Kapalı — yalnızca bu cihazda kalıyor',
			'settings.syncPanel.syncing' => 'Senkronize ediliyor',
			'settings.syncPanel.account' => 'Hesap',
			'settings.syncPanel.refresh' => 'Yenile',
			'settings.syncPanel.switchAccounts' => 'Hesap Değiştir',
			'settings.syncPanel.switchAccountsDescription' => 'Bu cihazı QR kodu veya e-posta ile başka bir hesaba bağlayın',
			'settings.syncPanel.connectionRequests' => 'Bağlantı İstekleri',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Bir cihaz bu hesaba katılmayı bekliyor', other: '${n} cihaz bu hesaba katılmayı bekliyor', ), 
			'settings.syncPanel.accountEmailTitle' => 'Hesap e-postası',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Onay ${email} adresine gönderildi. Değişikliği tamamlamak için oradaki bağlantıyı açın.',
			'settings.syncPanel.resendConfirmation' => 'Onay E-postasını Yeniden Gönder',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => '${email} bekleniyor',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => '${email} adresine yeniden gönderildi.',
			'settings.syncPanel.deviceLinked' => 'O cihaz artık bu hesaba bağlı.',
			'settings.syncPanel.checking' => 'Kontrol ediliyor…',
			'settings.syncPanel.notLinked' => 'Henüz bağlı değil',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Yerel veriler değiştirilsin mi?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${n} operasyon', other: '${n} operasyon', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.syncPanel.counts' => 'Senkronize Veriler',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Bu cihaz: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Yüklenmeyi bekleyen: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Sunucu: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Bu cihaz: kontrol ediliyor…',
			'settings.syncPanel.countsServerChecking' => 'Sunucu: kontrol ediliyor…',
			'settings.syncPanel.countsServerUnavailable' => 'Sunucu: kullanılamıyor',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Bu işlem bu cihazdaki ${operations} ve ${qsos} kaydını yedekleyip temizler, ardından yerine hesabın verilerini indirir. Yedek bu cihazın veritabanında kalır.',
			'settings.syncPanel.replace' => 'Değiştir',
			'settings.syncPanel.pendingBannerTitle' => 'Yeni Ham2K Log Filer hesabı algılandı',
			'settings.syncPanel.pendingBannerBody' => 'Bu cihazdaki mevcut operasyonları ve QSO\'ları koruyup hesapla birleştirin ya da hesabın verileriyle değiştirin (her iki durumda da bu cihazda bir yedek kalır).',
			'settings.syncPanel.combine' => 'Birleştir',
			'settings.syncPanel.authIssueTitle' => 'Senkronizasyon bağlanamıyor',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer bu cihazı reddetmeye devam ediyor. Senkronizasyon ayarlarında çağrı işaretinizi kontrol edin.',
			'settings.syncPanel.openSettings' => 'Senkronizasyon ayarlarını aç',
			'settings.accounts.title' => 'Hesaplar, Hizmetler ve Veri Kaynakları',
			'settings.accounts.none' => 'Hesap kullanan etkin uzantı yok',
			'settings.accounts.notConfigured' => 'Yapılandırılmadı',
			'settings.accounts.connected' => 'Bağlı',
			'settings.accounts.cancelLogin' => 'Girişi iptal et',
			'settings.accounts.openInBrowser' => 'Tarayıcıda Aç',
			'settings.accounts.loggedInAs' => ({required Object identity}) => '${identity} olarak giriş yapıldı',
			'settings.accounts.pressSaveToKeep' => 'Bu hesabı bağlı tutmak için Kaydet\'e basın.',
			'settings.accounts.connectedTo' => ({required Object label}) => '${label} hizmetine bağlı',
			'settings.accounts.connect' => 'Bağlan',
			'settings.accounts.disconnect' => 'Bağlantıyı Kes',
			'settings.accounts.connectedAs' => 'Bağlı hesap:',
			'settings.accounts.test' => 'Test Et',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Kaydetme başarısız: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Giriş başarısız: ${error}',
			'settings.accounts.lookupFailed' => 'Hesaplar şu anda kullanılamıyor — birazdan tekrar deneyin',
			'settings.accounts.browserLoginTitle' => 'Girişi web tarayıcınızda tamamlayın',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'İşiniz bittiğinde tarayıcı "${prefix}" ile başlayan bir bağlantıyı açmaya çalışacak. Masaüstünüzde büyük olasılıkla bunu açacak kayıtlı bir şey yoktur; bu yüzden o bağlantıyı (adres çubuğundan veya tarayıcının gösterdiği hata sayfasından) kopyalayıp buraya yapıştırın.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger tarayıcınızı açamadı. Aşağıdaki giriş bağlantısını kopyalayıp kendiniz açın, ardından sizi yönlendirdiği bağlantıyı ("${prefix}" ile başlar) kopyalayıp buraya yapıştırın.',
			'settings.accounts.copyLoginLink' => 'Giriş bağlantısını kopyala',
			'settings.accounts.pastedLinkLabel' => 'Bağlantıyı buraya yapıştırın',
			'settings.accounts.finishLogin' => 'Girişi Tamamla',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Bu giriş bağlantısı değil — "${prefix}" ile başlamalı.',
			'settings.accounts.pastedLinkWrongLogin' => 'Bu bağlantı farklı bir giriş denemesine ait. Bu sayfayı kapatıp yeniden bağlanın.',
			'settings.accounts.pastedLinkNoCode' => 'Bu bağlantıda giriş kodu yok. Önce girişi tamamlayın, ardından sizi yönlendirdiği bağlantıyı kopyalayın.',
			'settings.accounts.pastedLinkMalformed' => 'Bu bağlantı kesik görünüyor. Tamamını kopyalayıp yeniden yapıştırın.',
			'settings.accounts.relayLoginWaiting' => 'Girişi tamamlamanız bekleniyor — tamamladığınızda otomatik olarak devam edecek.',
			'settings.accounts.loginNoResponse' => 'Bu cihaz henüz girişten yanıt almadı. Tarayıcınızda zaten tamamladıysanız iptal edip yeniden bağlanmayı deneyin.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger tarayıcınızı otomatik olarak açamadı. Giriş sayfasını kendiniz açmak için aşağıdaki düğmeyi kullanın.',
			'settings.accounts.relayLoginUnavailable' => 'Bu girişi tamamlamak için gereken senkronizasyon sunucusuna ulaşılamadı. Bağlantınızı kontrol edip tekrar deneyin.',
			'settings.accounts.loginIncompleteResponse' => 'Bu giriş denemesi doğru şekilde tamamlanmadı. Lütfen yeniden bağlanmayı deneyin.',
			'settings.accounts.noKeyringTitle' => 'Hesap girişleri kaydedilemiyor',
			'settings.accounts.noKeyringText' => 'Ham2K Logger bu bilgisayarda bir anahtarlık hizmetine ulaşamıyor, bu yüzden hesap girişleri saklanamıyor veya okunamıyor — bu çözülene kadar hesap bağlamak başarısız olur. **gnome-keyring**, **KWallet** veya **KeePassXC** yükleyip başlatın ya da mevcut anahtarlığınızın kilidini açın, ardından yeniden başlatın. Kayıt, dışa aktarma ve veri dosyaları etkilenmez; bu durum sürdükçe günlük senkronizasyonu kapalı kalır.',
			'settings.accounts.noKeyringInline' => 'Girişler kaydedilemiyor: bu bilgisayarın anahtarlığına ulaşılamıyor. gnome-keyring, KWallet veya KeePassXC yükleyip başlatın ya da mevcut olanın kilidini açın.',
			'settings.accounts.noSecureStorageInline' => 'Girişler kaydedilemiyor: bu bilgisayarın güvenli depolamasına ulaşılamıyor.',
			'settings.station.title' => 'İstasyon Yapılandırması ve CAT Kontrolü',
			'settings.station.none' => 'Yapılandırılmış ekipman yok',
			'settings.station.add' => 'Ekle',
			'settings.station.addTitle' => 'Ekipman ekle',
			'settings.station.searchHint' => 'Ekipman ara',
			'settings.station.noMatches' => 'Eşleşen ekipman yok',
			'settings.station.detectedEquipment' => 'Algılanan Ekipman',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Radyolar dinlenemiyor: ${error}',
			'settings.station.edit' => 'Ekipmanı düzenle',
			'settings.station.name' => 'İsim',
			'settings.station.nameDescription' => 'Ona ne dediğiniz — "Sol Radyo". İsteğe bağlı.',
			'settings.station.transport' => 'Bağlantı',
			'settings.station.host' => 'Adres',
			'settings.station.hostDescription' => 'Radyonun ağınızdaki ana makine adı veya IP adresi.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Adres gerekli',
			'settings.station.portInvalid' => 'Port 1 ile 65535 arasında olmalı',
			'settings.station.connect' => 'Bağlan',
			'settings.station.disconnect' => 'Bağlantıyı Kes',
			'settings.station.remove' => 'Kaldır',
			'settings.station.removeTitle' => ({required Object name}) => '${name} kaldırılsın mı?',
			'settings.station.removeMessage' => 'Bu yalnızca onu uygulamadan kaldırır. Ekipmanın ayarları olduğu gibi kalır.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tanınmayan ekipman türü "${typeKey}"',
			'settings.station.report' => 'Bildir',
			'settings.station.reportTitle' => 'Bu radyoyu bildir',
			'settings.station.reportIntro' => 'Bu radyonun gerçekte ne olduğunu ve nasıl gittiğini bize anlatın. Raporunuz Ham2K ekibinin okuduğu bir karta dönüşür; onu çalıştırma konusunda yazdıklarınız aynı cihaza sahip bir sonraki operatöre yardımcı olabilir.',
			'settings.station.reportManufacturer' => 'Üretici',
			'settings.station.reportManufacturerDescription' => 'Kim üretiyor — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Üretici gerekli',
			'settings.station.reportModel' => 'Model',
			'settings.station.reportModelDescription' => 'Radyonun kendisinin belirttiği model — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'Model gerekli',
			'settings.station.reportOutcome' => 'Nasıl gitti?',
			'settings.station.reportOutcomeWorks' => 'İyi çalıştı',
			'settings.station.reportOutcomeIssues' => 'Çalıştı, sorunlarla',
			'settings.station.reportOutcomeFails' => 'Hiç çalışmadı',
			'settings.station.reportOutcomeRequired' => 'Lütfen nasıl gittiğini bize söyleyin',
			'settings.station.reportComments' => 'Yorumlar',
			'settings.station.reportCommentsPlaceholder' => 'Ne çalıştı, ne çalışmadı, sizi şaşırtan herhangi bir şey.',
			'settings.station.reportHints' => 'Sorun giderme ipuçları',
			'settings.station.reportHintsPlaceholder' => 'Diğer kullanıcılar için sorun giderme ipuçları önermek ister misiniz?',
			'settings.station.reportSend' => 'Raporu gönder',
			'settings.station.reportSending' => 'Raporunuz gönderiliyor…',
			'settings.station.reportSent' => ({required Object ref}) => 'Teşekkürler — raporunuz ${ref} olarak kaydedildi.',
			'settings.station.reportSentNoRef' => 'Teşekkürler — raporunuz gönderildi.',
			'settings.station.reportFailed' => ({required Object error}) => 'Rapor gönderilmedi: ${error}',
			'settings.station.troubleshootingNotes' => 'Sorun Giderme Notları',
			'settings.station.mainVfo' => 'Ana VFO',
			'settings.station.useAsMainVfo' => 'Ana VFO olarak kullan',
			'settings.station.serialPort' => 'Seri port',
			'settings.station.serialPortDescription' => 'Radyonun CAT arayüzünün göründüğü port.',
			'settings.station.serialPortNone' => 'Seri port bulunamadı',
			'settings.station.serialPortRequired' => 'Bir seri port seçin',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} / ${total}',
			'settings.station.serialPortSuggested' => 'önerilen',
			'settings.station.serialPortJustNow' => 'Yeni bağlandı',
			'settings.station.serialDeviceRequest' => 'USB cihazı ekle…',
			'settings.station.baudRate' => 'Hız (baud)',
			'settings.station.baudRateDescription' => 'Radyonun CAT menüsüyle eşleşmelidir. Eşleşmezse radyo anlamsız veri döndürür ve hata vermez.',
			'settings.station.serialRtsHigh' => 'RTS\'yi yüksek tut',
			'settings.station.serialRtsHighDescription' => 'Yalnızca yanıt vermeden önce RTS bekleyen bir radyo için, örneğin CAT RTS açık bir Yaesu. Digirig, SignaLink ve çoğu ev yapımı kabloda RTS, PTT\'dir ve onu yüksek tutmak yayına geçirir.',
			'settings.station.serialDtrHigh' => 'DTR\'yi yüksek tut',
			'settings.station.serialDtrHighDescription' => 'Yalnızca gücünü DTR\'den alan bir CAT arayüzü için, örneğin FT-817 için bazı RS-232 kabloları. Birçok kabloda DTR, CW veya PTT\'yi tetikler ve onu yüksek tutmak yayına geçirir.',
			'settings.station.civAddress' => 'Radyo CI-V adresi',
			'settings.station.civAddressDescription' => 'Radyonun CI-V menüsünde gösterildiği gibi onaltılık. IC-705 fabrikadan A4 olarak gelir.',
			'settings.station.civAddressInvalid' => 'CI-V adresi iki onaltılık basamaktır, 01 ile FF arası',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Bu bağlantının radyonun hangi slice\'ından okuyup ayar yaptığı.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Radyonun slice\'larından birini seçin, A ile H arası',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'Slice ${letter} bu radyoda kullanılmıyor — başka bir slice seçin veya SmartSDR\'da oluşturun',
			'settings.station.channelNotInUse' => 'kullanılmıyor',
			'settings.station.channelHeldByUnknown' => 'başka bir program kullanıyor',
			'settings.station.flexNoSlices' => 'Bu radyo hiç slice bildirmedi — SmartSDR\'ın çalıştığını ve bu istemcinin abone olabildiğini kontrol edin',
			'settings.station.spectrumUnsupported' => 'Bu radyo CAT üzerinden spektrum göndermiyor',
			'settings.station.spectrumRequiresBaud' => '115200 bps CAT gerektirir',
			'settings.station.spectrumNoRadio' => 'Bağlı radyo yok',
			'settings.station.spectrumWaiting' => 'Radyonun spektrumu bekleniyor…',
			'settings.station.spectrumUnavailable' => 'Spektrum görüntüsü kullanılamıyor',
			'settings.station.spectrumNoDaxChannel' => 'Bu radyodaki tüm DAX IQ kanalları kullanımda',
			'settings.station.spectrumNoPanadapter' => 'Bu slice\'ın radyoda bir panadapter\'ı yok',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'Radyo bir DAX IQ akışını reddetti (hata ${code})',
			'settings.station.spectrumNoUdp' => 'Radyonun spektrum verisi bu cihaza ulaşamıyor',
			'settings.station.spectrumScopeRefused' => 'Radyo skop komutlarını reddetti',
			'settings.station.spectrumOutOfRange' => 'Radyonun skopu gösterebileceği aralığın dışına ayarlanmış',
			'settings.station.n3fjpNoRig' => 'N3FJP\'de radyo arayüzü kurulu değil, bu yüzden bu bir radyoyu değil, N3FJP\'ye yazılanları izler',
			'settings.station.winkeyerKeyPort' => 'Anahtar çıkışı',
			'settings.station.winkeyerKeyPortDescription' => 'Radyonuzun keyer\'ın iki çıkış jakından hangisine takılı olduğu.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Keyer\'ın PTT\'sini kullan',
			'settings.station.winkeyerPttDescription' => 'Bir amplifikatör veya bunu gerektiren bir radyo için aynı jaktaki PTT hattını tetikler. Anahtar jakından tetiklenen bir radyo için kapalı bırakın.',
			'settings.station.winkeyerNoAnswer' => 'Bu portta hiçbir WinKeyer yanıt vermedi',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer gönderim sırasında yanıt vermeyi bıraktı; mesaj iptal edildi',
			'settings.station.radioUser' => 'Radyo kullanıcı adı',
			'settings.station.radioPass' => 'Radyo şifresi',
			'settings.station.radioLoginDescription' => 'Radyonun Network → Remote girişi, WiFi şifreniz değil.',
			'settings.station.radioUserRequired' => 'Radyonun uzaktan kontrol kullanıcı adı gerekli',
			'settings.station.connectFailedBusy' => 'Cihaz kullanımda',
			'settings.station.connectFailedDenied' => 'Erişim reddedildi',
			'settings.station.connectFailedDevice' => 'Cihaz bulunamadı',
			'settings.station.connectFailedLines' => 'RTS/DTR ayarlandığı gibi tutulamadı, bu yüzden port kapatıldı. Başka bir program donanım el sıkışmasını açık bırakmış olabilir — kabloyu çıkarıp yeniden takın.',
			'settings.station.connectFailedNetwork' => 'Radyo ağda bulunamıyor. Adresini, açık ve erişilebilir olduğunu kontrol edin.',
			'settings.station.connectFailedTimeout' => 'Radyo zamanında yanıt vermedi. Açık ve erişilebilir olduğunu kontrol edin.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Genel',
			'settings.station.models.icomGeneric' => 'Icom - Genel',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Genel',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Genel',
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
			'settings.station.models.rigctld' => 'rigctld ile kontrol edilen radyo',
			'settings.station.models.rigctldNodeName' => 'Radyom (rigctld ile)',
			'settings.station.models.flrig' => 'flrig ile kontrol edilen radyo',
			'settings.station.models.flrigNodeName' => 'Radyom (flrig ile)',
			'settings.station.models.hrd' => 'Ham Radio Deluxe® ile kontrol edilen radyo',
			'settings.station.models.hrdNodeName' => 'Radyom (HRD ile)',
			'settings.station.models.n3fjp' => 'N3FJP ile kontrol edilen radyo',
			'settings.station.models.n3fjpNodeName' => 'Radyom (N3FJP ile)',
			'settings.station.models.commander' => 'DXLab Commander ile kontrol edilen radyo',
			'settings.station.models.commanderNodeName' => 'Radyom (Commander ile)',
			'settings.station.models.antenna' => 'Anten',
			'settings.station.models.key' => 'CW Anahtarı',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Genel Radyo (Yer Tutucu)',
			'settings.station.models.placeholderRadioNodeName' => 'Radyom',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Koaksiyel Anahtar',
			'settings.station.transports.network' => 'Ağ/WiFi',
			'settings.station.transports.usbSerial' => 'USB Seri',
			'settings.station.transports.wifi' => 'Ağ/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth Seri',
			'settings.station.transports.placeholder' => 'Yer Tutucu',
			'settings.station.troubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.ft891Troubleshooting' => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT RTS radyoda OFF olmalı** (FT-891 menüsü **05-08**). Açıkken radyo, uygulamanın düşük tuttuğu bir el sıkışma hattını bekler. Digirig, SignaLink veya çoğu ev yapımı kabloda aynı hat PTT\'dir, bu yüzden onu yükseltmek vericinizi yayına geçirir. Radyonun kendi USB portunda alternatif, Gelişmiş Ayarlar altındaki **RTS\'yi yüksek tut** seçeneğidir.\n- **Hız eşleşmeli**: radyonun CAT RATE ayarı (menü **05-06**). Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.yaesuBinaryTroubleshooting' => 'Bu radyo Yaesu\'nun eski beş baytlık CAT protokolünü konuşur ve bir şey yanlış olduğunda hiç yanıt vermez. Neredeyse her zaman şunlardan biridir:\n\n- **Kablo seviyeleri dönüştürmelidir.** Arkadaki CAT jakı RS-232 de USB de değildir; CT-62 veya eşdeğer bir adaptör gerekir. Düz bir ses veya veri kablosu CAT için çalışmaz.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü (FT-817\'de **#14**, FT-857 veya FT-897\'de **#19**). Eşleşmezse radyo hiçbir şey döndürmez, asla hata vermez.\n- **Bu portta hiçbir şeyin RTS veya DTR\'yi yükseltmesine izin vermeyin.** Bu radyolar için çoğu kabloda bu hatlar PTT ve manipülasyondur. DTR\'den beslenen eski bir arayüz istisnadır: onun için Gelişmiş Ayarlar altında **DTR\'yi yüksek tut** seçeneğini açın.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\nBu sürücü Yaesu\'nun yayımladığı CAT tablosundan yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.guohetecTroubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.guohetecTroubleshooting' => 'Q900\'ün iki CAT protokolü vardır ve bu giriş FT-817 taklidi yerine kendi yerel protokolünü kullanır. Burada FT-817\'yi değil, **Guohetec Q900**\'ü seçin — taklit daha az komut destekler ve radyo hangisini kullandığını söylemez.\n\n- **USB-C kablosu CAT bağlantısıdır** ve ses kartını da bağlar. Bu bağlantıda hız önemli değildir; port ne ayarlanırsa ayarlansın yok sayar.\n- **Bu portta hiçbir şeyin RTS veya DTR\'yi yükseltmesine izin vermeyin.** Seri kabloda bu hatlar PTT ve manipülasyondur.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **İkinci nesil bir radyo birinci nesilden farklı davranır.** Menu\'ye uzun basın, ardından About: HW 2.0 ikinci nesildir.\n\nBu sürücü üreticinin yayımladığı protokolden yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.yaesuTroubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.yaesuTroubleshooting' => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, uygulamanın düşük tuttuğu bir el sıkışma hattını bekler. Digirig, SignaLink veya çoğu ev yapımı kabloda aynı hat PTT\'dir, bu yüzden onu yükseltmek vericinizi yayına geçirir. Radyonun kendi USB portunda alternatif, Gelişmiş Ayarlar altındaki **RTS\'yi yüksek tut** seçeneğidir. Bu ayarın yeri modele göre değişir (FT-891\'de menü **05-08**).\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **Modlar FT-891\'in tablosunu izler.** Yaesu serisinin çoğu buna uyar, ancak modlarını farklı numaralandıran bir radyo bu modlar için yanlış olanı gösterir ve ayarlar. Frekans etkilenmez.',
			'settings.station.yaesuRs232Troubleshooting' => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **CAT jakı RS-232\'dir.** USB-seri adaptör ve düz bağlantılı bir DB-9 kablosu gerekir — null-modem kablosu hatları çaprazlar ve radyo hiçbir şey duymaz.\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, Gelişmiş Ayarlar altında **RTS\'yi yüksek tut** açık olmadıkça uygulamanın düşük tuttuğu bir el sıkışma hattını bekler.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\nBu giriş yayımlanmış CAT belgelerinden yazıldı ve bu radyolardan birinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.yaesuUsbTroubleshooting' => 'Radyo komutları alıyor ama yanıt vermiyor. Neredeyse her zaman şunlardan biridir:\n\n- **Radyonun iki USB portundan ilkini kullanın.** CAT normalde ilkindedir (Windows\'ta **Enhanced** COM portu); ikincisi (**Standard**) PTT ve manipülasyon içindir. Seçici, ikisini ayırt edebildiği her yerde ilkini gösterir.\n- **CAT RTS radyoda OFF olmalı.** Açıkken radyo, Gelişmiş Ayarlar altında **RTS\'yi yüksek tut** açık olmadıkça uygulamanın düşük tuttuğu bir el sıkışma hattını bekler.\n- **Hız eşleşmeli**: radyonun CAT RATE menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.',
			'settings.station.k4SerialNotes' => 'K4\'ün arkadaki USB-B (PC) soketini bağlayın. CAT için USB-PC1 veya USB-PC2 çalışır; kullanılmayan bir port seçin ve radyodaki Serial USB-PCn: Baud Rate ayarıyla eşleştirin. HaLo 38400 değerini önceden doldurur; gerekirse değiştirin. Başka bir uygulama diğer portu veya Ethernet\'i kullanmalıdır.\n\nBu bağlantı radyoyu ve keyer\'larını kontrol eder; HaLo\'ya ses göndermez.',
			'settings.station.k4TcpNotes' => 'K4\'ün Ethernet soketini yerel ağınıza bağlayın. Ana makine adını veya IP adresini ve CAT portu 9200\'ü girin. Bu CAT kontrolüdür, 9204 portundaki ayrı uzak ses bağlantısı değildir.\n\nHaLo, ses veya panadapter verisi aktarmadan radyoyu ve keyer\'larını kontrol eder.',
			'settings.station.k4PowerTimeout' => 'Radyo çıkış aralığını onaylamadığı için K4 gücü değiştirilmedi. Tekrar deneyin.',
			'settings.station.k4PowerRange' => 'K4 gücü 0.1–110 W olmalıdır; transverter miliwatt çıkışı etkinken 0.0001–0.01 W.',
			'settings.station.elecraftTroubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.elecraftTroubleshooting' => 'Elecraft cihazları Kenwood CAT konuşur ve hem KX2 hem KX3 bu şekilde çalıştırıldı — her iki yönde VFO, mod değiştirme ve CW sıfır vuruşu çalışıyor.\n\nRadyo yanıt vermiyorsa, neredeyse her zaman şunlardan biridir:\n\n- **Hız eşleşmeli**: radyonun menüsünde **RS232** altında ayarlanan hız. Bu cihazlar 38400 ile gelir. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n\n**Frekans doğru ama mod yanlışsa** bize bildirin. KX2 ve KX3 girişleri modu, radyonun durum yanıtında gördüğümüz cihazlardan belirlediğimiz bir konumdan okur; onu başka yere koyan bir yazılım ancak bir raporla bize ulaşır.\n\nK3 için henüz rapor yok, bu yüzden kullanıyorsanız ne olduğunu lütfen söyleyin. K4\'ün kendi girişi vardır.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Radyo bağlanıyor ama frekans göstermiyorsa',
			'settings.station.kenwoodTroubleshooting' => 'Bu sürücü Kenwood TS-590SG ve TS-480, QRP Labs QMX ve QCX-mini ile Elecraft KX2 ve KX3 üzerinde doğrulandı. Serinin geri kalanı yayımlanmış CAT referanslarından yazıldı, bu yüzden her iki durumda da ne olduğunu lütfen bildirin.\n\nRadyo yanıt vermiyorsa, neredeyse her zaman şunlardan biridir:\n\n- **Hız eşleşmeli**: radyonun CAT menüsü. Eşleşmezse radyo anlamsız veri döndürür ya da hiçbir şey döndürmez, asla hata vermez.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.\n- **Bazı cihazlarda CAT** yanıt vermeden önce menüden etkinleştirilmelidir.\n\n**Birçok SDR ön ucu aynı protokolü konuşur**, bu yüzden bu giriş onlar için de denemeye değer; Elecraft cihazları ayrı olarak, Elecraft altında listelenir. Frekans doğru ama mod yanlış veya eksikse, seri boyunca farklılık gösteren tek kısım budur — uygulama modu radyodan çıkarır ve gerekirse doğrudan sorar, bu yüzden mod yalnızca gecikmeli gelebilir.',
			'settings.station.statusConnected' => 'Bağlı',
			'settings.station.statusLost' => 'Bağlantı kesildi',
			'settings.station.notConfigured' => 'Yapılandırılmadı',
			'settings.station.currentConfiguration' => 'Mevcut Yapılandırma',
			'settings.station.currentTransceiver' => 'Mevcut Telsiz',
			'settings.station.radioMode' => 'Radyo Modu',
			'settings.station.keyerNotSupported' => 'Mevcut radyo desteklemiyor',
			'settings.station.catControlPreferences' => 'CAT Kontrol Tercihleri',
			'settings.station.chooseTransceiver' => 'Telsiz seç',
			'settings.station.configurationSection' => 'Yapılandırma',
			'settings.station.noTransceiverSelected' => 'Telsiz seçilmedi',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Ana VFO için ${name} kullan',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, zero: 'Telsiz yok', one: '${count} telsiz', other: '${count} telsiz', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} anten', other: '${count} anten', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} diğer cihaz', other: '${count} diğer cihaz', ), 
			'settings.station.equipmentInventory' => 'Ekipman Envanteri',
			'settings.station.equipmentInUse' => 'Telsiz Kontrolleri',
			'settings.station.noTransceiver' => 'Yok',
			'settings.station.peerRadioNotAvailable' => 'Kullanılamıyor',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => '${device} üzerinde',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} başka bir cihazda',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Bu radyo ${device} cihazına bağlı. Bağlantısı ve ayarları o cihazda yapılandırılır.',
			'settings.station.antennaInUse' => 'Kullanılan Anten',
			'settings.station.keyInUse' => 'Kullanılan Anahtar',
			'settings.station.noneSelected' => 'Yok',
			'settings.station.moreSettings' => 'Diğer Ayarlar',
			'settings.station.icomCivTroubleshootingTitle' => 'Aynı radyo için iki seri port görünüyorsa',
			'settings.station.icomCivTroubleshooting' => 'IC-705 dahil birçok Icom radyosu aynı anda **iki** USB seri port sunar (Icom bunlara Port A ve Port B der) ve ikisi de varsayılan olarak CI-V\'ye ayarlıdır. Ne bu uygulama ne de işletim sisteminiz bunları bunun ötesinde ayırt edebilir: aynı USB üretici/ürün kimliği iki kez görünür, burada bazen `#2` ekiyle işaretlenir. **Doğru olan genellikle Port A\'dır** — normalde işletim sisteminizin veya tarayıcınızın listelediği ilk port; bu uygulama iki portu ayırt edebildiğinde onu önerilen olarak işaretler. Komutlar gidiyor ama radyo hiç yanıt vermiyorsa diğer portu deneyin.',
			'settings.station.civAddressTroubleshootingTitle' => 'Radyo hiç yanıt vermiyorsa',
			'settings.station.civAddressTroubleshooting' => '- **CI-V adresi eşleşmeli**: radyonun menüsündekiyle aynı olmalı. Bu giriş, modelin fabrika adresini önceden doldurur, ancak bir CI-V veri yolunu paylaşan bir cihazda tam da bu değiştirilir. Yanlış adrese gönderilen bir çerçeve sessizce yok sayılır; bu da tıpkı ölü bir kablo gibi görünür.\n- **Hız eşleşmeli**: radyonun CI-V BAUD RATE ayarı (USB\'de CI-V USB Baud Rate). Radyoyu burada gösterilen sayıya ayarlayın, **Auto\'ya değil**. Auto\'da IC-7300 dahil bazı radyolar bağlanır ve bir dakika kadar sonra yanıt vermeyi bırakır.\n- **Portu başka bir uygulama tutuyor olabilir**: WSJT-X, fldigi ve rigctld onu açık tutar.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** burada önceden doldurulan `94` yerine `B6` adresiyle gelir — onun yerine IC-7300 MK2 girişini seçin.',
			'settings.station.ic705PortNote' => '\n- **IC-705** her ikisi de radyonun adını taşıyan iki USB seri port sunar. CI-V bunların **ilkindedir**; seçici, ikisini ayırt edebildiği her yerde onu gösterir.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760**, sunduğu iki USB seri porttan **Port A** üzerinde CI-V konuşur.',
			'settings.station.x6100PortNote' => '\n- **X6100**, CI-V\'yi **DEV** portunda konuşur — sunduğu iki seri porttan ikincisi ve seçicinin gösterdiği port.',
			'settings.station.rigctldTroubleshootingTitle' => 'Uygulama bağlanamıyorsa',
			'settings.station.rigctldTroubleshooting' => 'Bu, radyoya doğrudan değil, **kendiniz çalıştırdığınız bir rigctld servisine** bağlanır — Hamlib\'in arka ucu radyoyla konuşur ve yüzlerce modeli destekler.\n\n- **Servis zaten çalışıyor olmalı**, örn. `rigctld -m 1035 -r /dev/ttyUSB0`. Radyonuzun model numarasını `rigctl -l` ile bulun.\n- **Başka bir makineden** bağlanmak için `-T 0.0.0.0` ile başlatın: varsayılan olarak rigctld yalnızca çalıştığı makineden bağlantı kabul eder.\n- Servisi `-t` ile başlatmadıysanız **port** 4532\'dir.\n- Bağlandıktan sonra frekansın görünmemesi genellikle servisin kendisinin radyoya ulaşamadığı anlamına gelir. Servisin makinesinde `rigctl -m 2 f` ile test edin.',
			'settings.station.flrigTroubleshootingTitle' => 'Uygulama bağlanamıyorsa',
			'settings.station.flrigTroubleshooting' => 'Bu, radyoya doğrudan değil, **kendiniz çalıştırdığınız bir flrig programına** bağlanır — flrig radyoyla konuşur ve çoğu marka ve modeli destekler.\n\n- **flrig zaten çalışıyor olmalı**, telsizi yapılandırılmış ve bağlı olarak.\n- flrig yapılandırmasında (Config → Setup → Server) değiştirmediyseniz **port** 12345\'tir.\n- **Başka bir makineden** bağlanıyorsanız flrig sunucusuna erişilebildiğinden emin olun. Tüm arayüzleri dinler, ancak güvenlik duvarınız aynı fikirde olmayabilir.\n- Bağlandıktan sonra frekansın görünmemesi genellikle flrig\'in kendisinin radyoya ulaşamadığı anlamına gelir. flrig ekranının düğmeyi izlediğini kontrol edin.',
			'settings.station.hrdTroubleshootingTitle' => 'Uygulama bağlanamıyorsa',
			'settings.station.hrdTroubleshooting' => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan Ham Radio Deluxe Rig Control\'e** bağlanır — HRD radyoyla konuşur.\n\n- **Rig Control zaten çalışıyor olmalı** ve radyoya bağlı olmalı.\n- **IP sunucusu etkin olmalı.** Rig Control diğer programlarla yalnızca onun üzerinden konuşur.\n- IP sunucusunun ayarlarında değiştirmediyseniz **port** 7809\'dur.\n- **Başka bir makineden** bağlanıyorsanız güvenlik duvarınızın bağlantıya izin verdiğinden emin olun.\n\nBu giriş HRD protokolünün yayımlanmış açıklamalarından yazıldı ve HRD üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Uygulama bağlanamıyorsa',
			'settings.station.n3fjpTroubleshooting' => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan bir N3FJP kayıt programına** bağlanır — N3FJP radyoyla konuşur.\n\n- **Programın API\'si açık olmalı**: Settings → Application Program Interface, **TCP API Enabled** seçeneğini işaretleyin.\n- Orada değiştirmediyseniz **port** 1100\'dür.\n- Radyoyu izlemek veya ayarlamak için **N3FJP\'de bir radyo arayüzü kurulu olmalı**. Arayüz olmadan yalnızca giriş penceresine yazılanları bildirir.\n- N3FJP yalnızca bant, mod ve frekans bildirir: güç ve yayın durumu yok.\n\nBu giriş N3FJP\'nin yayımlanmış API\'sinden yazıldı ve N3FJP üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.commanderTroubleshootingTitle' => 'Uygulama bağlanamıyorsa',
			'settings.station.commanderTroubleshooting' => 'Bu, radyoya doğrudan değil, **bilgisayarınızda çalışan DXLab Commander\'a** bağlanır — Commander radyoyla konuşur.\n\n- **Commander zaten çalışıyor olmalı** ve radyoya bağlı olmalı.\n- **Ağ hizmeti açık olmalı**: Commander\'ın Configuration penceresindeki Radio panelinde **Net Serv** düğmesi.\n- **Port** 52002\'dir; Net Serv\'in **Base Port** değeriyle (değiştirmediyseniz 52000) başlayan bloğun üçüncü portu.\n- **Başka bir makineden** bağlanıyorsanız güvenlik duvarınızın bağlantıya izin verdiğinden emin olun.\n\nBu giriş Commander\'ın yayımlanmış TCP mesajlarından yazıldı ve Commander üzerinde çalıştırılmadı. Yarı yarıya çalışıyorsa bunu bildirmeye değer.',
			'settings.station.ic705TroubleshootingTitle' => 'Radyo hiç yanıt vermiyorsa',
			'settings.station.ic705Troubleshooting' => 'Radyonun **tek** bir uzaktan kontrol oturumu vardır. Giriş yok sayıldığında neredeyse her zaman onu başka bir şey kullanıyordur.\n\n- **Diğer istemcileri kapatın.** Aynı radyoya bağlı wfview veya RS-BA1 o tek oturumu tutar ve bu sürece buradaki giriş yok sayılır.\n- **Radyonun ağ ayarlarını kontrol edin.** WLAN açık olmalı, radyo aynı ağda olmalı ve uzaktan kontrol (Network) işlevi etkin olmalı.\n- Takılı kalırsa **radyonun WLAN\'ını kapatıp açın**. Bu, radyoda takılı kalan bir oturumu güvenilir şekilde temizler.\n\n**Yanlış şifre açıkça reddedilir**, sessizlikle karşılanmaz. "Reddedildi" mesajı yerine buraya geldiyseniz sorun şifre değildir.',
			'settings.station.statusStale' => 'Yanıt vermiyor',
			'settings.station.statusDisconnected' => 'Bağlı değil',
			'settings.station.statusConnecting' => 'Bağlanıyor…',
			'settings.station.statusDisconnecting' => 'Bağlantı kesiliyor…',
			_ => null,
		} ?? switch (path) {
			'settings.station.statusError' => 'Bağlantı başarısız',
			'settings.station.currentRadioSettings' => 'Mevcut radyo ayarları',
			'settings.station.notSupportedByThisRadio' => 'Bu radyo desteklemiyor',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Telefon',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Ses keyer\'ı: radyoda ${count} hafıza',
			'settings.station.antennaBands' => 'Bantlar',
			'settings.station.antennaType' => 'Anten türü',
			'settings.station.antennaTypeRequired' => 'Bir anten türü seçin',
			'settings.station.antennaTypes.dipole' => 'Dipol',
			'settings.station.antennaTypes.vertical' => 'Dikey',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Uzun Tel / EFHW',
			'settings.station.antennaTypes.other' => 'Diğer',
			'settings.station.keyType' => 'Anahtar türü',
			'settings.station.keyTypeRequired' => 'Bir anahtar türü seçin',
			'settings.station.keyTypes.straight' => 'Düz Anahtar',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (mekanik yarı otomatik)',
			'settings.station.keyTypes.fullyAutomatic' => 'Tam otomatik keyer',
			'settings.station.keyTypes.singlePaddle' => 'Tek Kollu Paddle',
			'settings.station.keyTypes.dualPaddle' => 'Çift Kollu Paddle',
			'settings.station.keyTypes.computerDriven' => 'Bilgisayar Kontrollü',
			'settings.station.keyTypes.other' => 'Diğer',
			'settings.station.softwareIntermediaries' => 'Aracı Yazılımlar',
			'settings.station.otherBrands' => 'Diğer Markalar',
			'settings.station.otherEquipment' => 'Diğer Ekipman (Antenler, Anahtarlar vb.)',
			'settings.station.newAntenna' => 'Yeni Anten',
			'settings.station.newKey' => 'Yeni Anahtar',
			'settings.station.newKeyer' => 'WinKeyer (K1EL veya uyumlu)',
			'settings.station.keyViaRadio' => ({required Object radio}) => '${radio} içindeki CAT Keyer',
			'settings.station.keyOnDevice' => ({required Object device}) => '${device} üzerindeki anahtar',
			'settings.station.trackStationInfo' => 'Her QSO için İstasyon Bilgisini Kaydet',
			'settings.station.includeStationInfoInAdif' => 'ADIF dışa aktarımlarına dahil et',
			'settings.station.whatToTrack' => 'Neler kaydedilsin?',
			'settings.station.trackFieldRig' => 'Telsiz',
			'settings.station.trackFieldPower' => 'Güç',
			'settings.station.watts' => 'Watt',
			'settings.station.trackFieldAntenna' => 'Anten',
			'settings.station.trackFieldKey' => 'CW Anahtarı',
			'settings.station.placeholderConnectDelay' => 'Bağlantı gecikmesi (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Simüle edilen el sıkışmanın ne kadar sürdüğü. Boş veya 0 anında bağlanır.',
			'settings.station.placeholderDropAfter' => 'Şu süre sonra kes (saniye)',
			'settings.station.placeholderDropAfterDescription' => 'Yeniden bağlanma yolunu denemek için bağlantıyı kendiliğinden kapatır. Boş veya 0 hiç kesmez.',
			'settings.station.placeholderFailConnect' => 'Bağlantı her zaman başarısız olsun',
			'settings.station.placeholderConnectFailure' => 'Yer tutucu radyoya bu bağlantıyı reddetmesi söylendi',
			'settings.station.placeholderFreq' => 'Frekans (kHz)',
			'settings.station.placeholderFreqDescription' => 'Yer tutucu radyonun başladığı frekans. Ardından uygulama onu nereye ayarlarsa onu bildirir.',
			'settings.station.placeholderMode' => 'Mod',
			'settings.station.placeholderModeDescription' => 'Yer tutucu radyonun başladığı mod, örn. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Güç (watt)',
			'settings.station.placeholderPurpose' => 'Kayıt amacıyla hangi cihazı kullandığınızı takip etmek için bu radyoyu kullanın',
			'settings.station.placeholderReplyDelay' => 'Yanıt gecikmesi (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Yer tutucu radyonun bir değişikliği bildirmesinin ne kadar sürdüğü. Boş veya 0 hemen yanıtlar.',
			'settings.station.cwKeyerField' => 'CAT CW keyer',
			'settings.station.cwKeyerFieldDescription' => 'Bu radyonun CAT üzerinden metinden CW gönderip göndermediği. Uygulamanın tanımadığı bir cihaz için kapalı.',
			'settings.station.voiceMemories' => 'Ses hafızaları',
			'settings.station.voiceMemoriesDescription' => 'Radyonun CAT üzerinden kaç ses hafızası oynattığı. Hiç yoksa 0.',
			'settings.station.voiceMemoriesInvalid' => '0 veya daha büyük bir tam sayı',
			'settings.station.yaesuMeterCapture' => 'Ölçer değerlerini yakala',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Yayın sırasında radyonun çıkış gücü ölçerini ve yüksek SWR bayrağını okur, ham değerleri günlüğe yazar. Yaesu\'nun yayımlamadığı ölçeği oluşturmak içindir — değerler ölçer olarak gösterilmez.',
			'settings.station.yaesuMeterCaptureDescription' => 'Yayın sırasında radyonun PO, SWR ve ALC ölçerlerini okur, ham değerleri günlüğe yazar. Yaesu\'nun yayımlamadığı ölçeği oluşturmak içindir — değerler ölçer olarak gösterilmez.',
			'settings.station.telemetryInterval' => 'Ölçer okuma aralığı (ms)',
			'settings.station.telemetryIntervalDescription' => 'Radyo yayındayken ölçerlerinin ne sıklıkla okunacağı. Bu bağlantının kaldırabileceği en hızlı değer için boş bırakın, en fazla 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => '${min} ile ${max} arasında tam sayı milisaniye',
			'settings.station.pollInterval' => 'Boşta sorgulama aralığı (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Frekans ve mod değişmezken radyoya ne sıklıkla sorulacağı. ${fallback} ms için boş bırakın.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => '${min} ile ${max} arasında tam sayı milisaniye',
			'settings.station.advancedSettings' => 'Gelişmiş Ayarlar',
			'settings.station.placeholderSwr' => 'SWR değeri',
			'settings.station.placeholderSwrDescription' => 'Bu radyonun yayın sırasında SWR ölçerinde bildirdiği değer. 1.8\'in üzerinde panel uyarır.',
			'settings.station.placeholderSwrInvalid' => '1 veya daha büyük bir sayı',
			'settings.station.keyerNone' => 'Yok',
			'settings.station.cwDialect' => 'CW manipülasyon lehçesi',
			'settings.station.cwDialectDescription' => 'Bu radyonun KY komutunun hangi biçimini aldığı. Yok, CAT üzerinden CW manipülasyonu olmadığı anlamına gelir.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, 24\'e tamamlanmış)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY metni)',
			'settings.station.voiceDialect' => 'Ses keyer lehçesi',
			'settings.station.voiceDialectDescription' => 'Bu radyonun ses hafızalarını CAT üzerinden nasıl oynattığı. Yok, CAT üzerinden ses hafızası olmadığı anlamına gelir. Lehçe seçili ve sayı yoksa lehçenin varsayılan sayısı geçerlidir.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, TS-590 tarzı)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB ve DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (anahtar dokunuşları)',
			'settings.station.placeholderDiagnostic' => 'Simüle',
			'settings.station.placeholderWholeNumberInvalid' => '0 veya daha büyük bir tam sayı olmalı',
			'settings.station.placeholderFreqInvalid' => 'Sıfırdan büyük, kHz cinsinden bir frekans olmalı',
			'settings.station.placeholderModeInvalid' => 'Bir mod adı olmalı, örn. USB, CW, FT8',
			'settings.station.switchLayout' => 'Düzen',
			'settings.station.switchLayoutDescription' => 'Radyolarınızın anahtarın hangi tarafına takılı olduğu.',
			'settings.station.switchLayoutRequired' => 'Anahtarın nasıl bağlandığını seçin',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Anahtar "${command}" komutunu reddetti (hata ${code})',
			'settings.station.switchBusyTransmitting' => 'Bu port yayında — anten değiştirilmedi',
			'settings.station.switchNoAntenna' => 'Yok',
			'settings.station.switchAntennaFor' => ({required Object port}) => '${port} numaralı porttaki anten',
			'settings.station.switchAntennaForDescription' => 'Antenlerinizden hangisinin anahtardaki bu porta bağlı olduğu.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} Anten, ${radios} Radyo',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} Anten, 1 Radyo',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 Anten, ${radios} Radyo',
			'settings.station.switchCommonPort' => 'Ortak',
			'settings.station.dcnAddress' => 'Cihaz adresi',
			'settings.station.dcnAddressDescription' => 'Modülün DIP anahtarlarında ayarlanan adres. Koaksiyel röle modülü fabrikadan 2 olarak çıkar.',
			'settings.station.dcnAddressRequired' => '1 ile 99 arasında bir cihaz adresi olmalı',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'bant verisini izler',
			'settings.station.switchPortTransmittingHint' => 'yayında — şu anda değiştirilemez',
			'settings.station.switchCurrentStateHeader' => 'Mevcut Durum',
			'settings.station.switchCurrentStateDescription' => 'Her radyo portunun şu anda hangi antende olduğu. Değişiklikler hemen geçerli olur.',
			'settings.station.switchWiringHeader' => 'Kablolama',
			'settings.station.switchPortInhibitedHint' => 'yayın engellendi',
			'settings.station.configUnreadable' => 'Bu radyonun kayıtlı ayarları okunamadı. Ayarlarını açıp yeniden girin ya da kaldırıp tekrar ekleyin.',
			'settings.station.autoConnectHeld' => 'HaLo bu radyoya son bağlandığında yanıt vermeyi bıraktı, bu yüzden bu kez kendiliğinden bağlanmadı. Tekrar denemek için Bağlan\'a basın.',
			'settings.offlineData.title' => 'Çevrimdışı Veri',
			'settings.offlineData.noFiles' => 'Veri dosyası yok',
			'settings.offlineData.noFilesDescription' => 'Çevrimdışı verilerini buraya indirmek için aktivite veya sorgu uzantılarını etkinleştirin.',
			'settings.offlineData.refresh' => 'Yenile',
			'settings.offlineData.refreshing' => 'Yenileniyor…',
			'settings.offlineData.updateAll' => 'Tümünü Güncelle',
			'settings.offlineData.updatingAll' => 'Tüm veri dosyaları güncelleniyor…',
			'settings.offlineData.neverDownloaded' => 'Hiç indirilmedi',
			'settings.offlineData.updatedJustNow' => 'Az önce güncellendi',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '${days}g önce güncellendi',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '${days}g ${hours}s önce güncellendi',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '${hours}s önce güncellendi',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '${hours}s ${minutes}d önce güncellendi',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '${minutes}d önce güncellendi',
			'settings.offlineData.lastDownloadRefused' => ({required Object existing, required Object imported}) => 'Son indirmede ${existing} kayıttan yalnızca ${imported} tanesi vardı ve kullanılmadı. Kabul etmek için yenileyin.',
			'settings.offlineData.extensionsSection' => 'Uzantılar',
			'settings.profiles.notSet' => 'Ayarlanmadı',
			'settings.profiles.personalInfo' => 'Kişisel Bilgiler',
			'settings.profiles.personalInfoNote' => 'Bu bilgiler, gönderimler için gerektiğinde oluşturulan günlüklere eklenebilir',
			'settings.profiles.name' => 'İsim',
			'settings.profiles.email' => 'E-posta',
			'settings.profiles.club' => 'Kulüp',
			'settings.profiles.arrlSection' => 'ARRL Bölümü',
			'settings.profiles.racSection' => 'RAC Bölümü',
			'settings.profiles.section' => 'Bölüm',
			'settings.search.clear' => 'Temizle',
			'settings.search.hint' => 'Tercihlerde ara',
			'settings.developer.developerModeDescription' => 'Geliştirici uyarılarını, hata ayıklama günlüklerini ve araçlarını etkinleştir.',
			'settings.developer.experiments' => 'Deneyler',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} etkin', other: '${count} etkin', ), 
			'settings.developer.patchTrack' => 'Kod Yaması Kanalı',
			'settings.developer.patchTrackDescription' => 'Bu cihazın izlediği kablosuz kod yaması halkası. Daha cesur halkalar düzeltmeleri daha erken ama daha az test edilmiş olarak alır. Kod yamaları bir sonraki yeniden başlatmada uygulanır.',
			'settings.developer.trackStable' => 'Kararlı',
			'settings.developer.trackUnstable' => 'Kararsız',
			'settings.developer.trackBleeding' => 'Deneysel',
			'settings.developer.checkingTrack' => ({required Object track}) => '"${track}" kanalında kod yaması kontrol ediliyor…',
			'settings.developer.patchDownloaded' => 'Kod yaması indirildi — uygulamak için uygulamayı yeniden başlatın.',
			'settings.developer.noNewPatch' => ({required Object track}) => '"${track}" kanalında yeni kod yaması yok.',
			'settings.developer.noPatchInstalled' => 'Yüklü kod yaması yok — sürüm ikili dosyası çalışıyor.',
			'settings.developer.runningPatch' => ({required Object patch}) => '#${patch} numaralı kod yaması çalışıyor.',
			'settings.developer.deepLinks' => 'Derin bağlantılar',
			'settings.developer.registerUrlSchemes' => 'URL şemalarını kaydet',
			'settings.developer.registerUrlSchemesDescription' => 'com.ham2k:// bağlantılarının uygulamanın bu kopyasını açmasına izin ver',
			'settings.developer.registerUrlSchemesDone' => 'Bu kopya artık com.ham2k:// bağlantılarını açıyor',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Kaydedilemedi: ${error}',
			'settings.developer.systemInformation' => 'Sistem Bilgisi',
			'settings.developer.appVersion' => 'Uygulama Sürümü',
			'settings.developer.dataFolder' => 'Veri Klasörü',
			'settings.developer.loading' => '(yükleniyor…)',
			'settings.developer.panelLoadFailed' => 'Bu ayar paneli yüklenemedi.',
			'settings.developer.extDevServer' => 'Uzantı Geliştirme Sunucusu',
			'settings.developer.extensionSettings' => 'Uzantı Ayarları',
			'settings.developer.extDevServerDescription' => 'Uzantıları uygulamaya yerleşik olanlar yerine ağınızdaki bir geliştirme sunucusundan yükleyin ve kaydettikçe yeniden yükleyin.',
			'settings.developer.extDevServerAddress' => 'Sunucu adresi',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Bağlan',
			'settings.developer.extDevServerDisconnect' => 'Bağlantıyı Kes',
			'settings.developer.extDevServerConnecting' => 'Bağlanıyor…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} uzantı sunuluyor: ${keys}', other: '${count} uzantı sunuluyor: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Bağlı değil',
			'settings.developer.extDevServerReconnect' => 'Açılışta yeniden bağlan',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Son yeniden yükleme: ${key}, ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} uzantı derlenemiyor', other: '${count} uzantı derlenemiyor', ), 
			'settings.developer.catalog' => 'Uzantı Kataloğu',
			'settings.developer.catalogDescription' => 'Kataloğu başka bir sunucudan okuyun — katalog üzerinde çalışırken yerel bir sunucudan. Boş bırakılırsa catalog.ham2k.net kullanılır.',
			'settings.developer.catalogAddress' => 'Katalog adresi',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Katalog Arama Kanalları',
			'settings.developer.catalogSearchStable' => 'Yalnızca Kararlı',
			'settings.developer.catalogSearchUnstable' => 'Kararsız veya daha iyisi',
			'settings.developer.catalogSearchBleeding' => 'Deneysel veya daha iyisi',
			'settings.about.notices' => 'Bildirimler ve Mesajlar',
			'settings.about.noticesDescription' => 'Duyurular ve durum mesajları',
			'settings.about.releaseNotes' => 'Sürüm Notları',
			'settings.about.copiedVersion' => 'Sürüm ayrıntıları panoya kopyalandı',
			'settings.panels.settings' => 'Uygulama Tercihleri',
			'settings.panels.settingsDescription' => 'Uygulamayı istediğiniz gibi çalıştırın',
			'settings.panels.commonSettings' => 'Genel Tercihler',
			'settings.panels.syncDescription' => 'Günlüklerinizi yedekleyin ve cihazlar arasında senkronize edin',
			'settings.panels.accountsDescription' => 'Hizmet kimlik bilgileri, çevrimdışı veri ve daha fazlası',
			'settings.panels.extensions' => 'Uzantılar ve Özellikler',
			'settings.panels.extensionsDescription' => 'Aktiviteler, Yarışmalar, Pano Panelleri ve daha fazla özellik',
			'settings.panels.profilesDescription' => 'Operatör çağrı işareti ve istasyon profili',
			'settings.panels.stationProfiles' => 'İstasyon Profilleri',
			'settings.panels.developerSettings' => 'Geliştirici Ayarları',
			'settings.panels.developerSettingsDescription' => 'Hata ayıklama ve geliştirme araçları',
			'settings.panels.about' => 'Hakkında',
			'settings.panels.aboutDescription' => 'Sürüm, katkıda bulunanlar ve yasal bilgiler',
			'settings.panels.unavailableTitle' => 'Bazı ayarlar kullanılamıyor',
			'settings.panels.unavailableText' => 'Uzantı çalışma ortamı başlatılamadı, bu yüzden uzantıların eklediği ayarlar eksik.',
			'settings.panels.station' => 'İstasyon Yapılandırması',
			'settings.panels.stationDescription' => 'CAT kontrolü ve diğer seçenekler',
			'settings.panels.peers' => 'Eş Cihazlar',
			'settings.panels.peersDescription' => 'Yakındaki diğer cihazlara bağlanın',
			'settings.showMoreSettings' => 'Daha fazla ayar göster',
			'settings.gridPrecision' => 'Grid Hassasiyeti',
			'settings.gridPrecisionOpts.six' => '6 hane (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 hane (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 hane',
			'settings.gridPrecisionDescription.eight' => '8 hane',
			'commands.enableSyncFirst' => 'Önce Ayarlar\'dan senkronizasyonu etkinleştirin.',
			'commands.fullResyncStarted' => 'Tam yeniden senkronizasyon başladı — yerel veriler önce yedeklendi.',
			'commands.noDataFilesMatched' => ({required Object target}) => '"${target}" ile eşleşen veri dosyası yok.',
			'commands.reloadFailed' => ({required Object error}) => 'Yeniden yükleme başarısız: ${error}',
			'commands.reloadingAll' => 'Tüm veri dosyaları yeniden yükleniyor…',
			'commands.reloadingTarget' => ({required Object target}) => '${target} veri dosyaları yeniden yükleniyor…',
			'commands.unknownExperiment' => ({required Object token}) => 'Bilinmeyen deney "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} etkinleştirildi',
			'commands.experimentDisabled' => ({required Object name}) => '${name} devre dışı bırakıldı',
			'commands.sentryTestSent' => 'Test hata raporu Sentry\'ye gönderildi',
			'commands.sentryTestLocalOnly' => 'Bu sürümde Sentry devre dışı — test hatası yalnızca yerel olarak kaydedildi',
			'commands.noOperationOpen' => 'Bu komut açık bir operasyon gerektirir',
			'commands.unknownSegmentKind' => ({required Object kind}) => '\'${kind}\' nasıl işaretleneceği bilinmiyor',
			'commands.operationAlreadyStarted' => 'Bu operasyonun zaten bir başlangıç işareti var',
			'commands.couldNotOpenLocation' => 'Ara eklendi, ancak konum ekranı açılamadı',
			'commands.noTestOperations' => 'Temizlenecek Test Operasyonu yok',
			'commands.purgeTestsUnavailable' => 'PURGETESTS bir onay penceresi göstermeli, ancak bu burada kullanılamıyor',
			'commands.syncAllUnavailable' => 'SYNCALL bir onay penceresi göstermeli, ancak bu burada kullanılamıyor',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} Test Operasyonu temizlendi', other: '${count} Test Operasyonu temizlendi', ), 
			'commands.purgeTestsSomeFailed' => ({required Object total, required Object purged}) => '${total} Test Operasyonundan ${purged} tanesi temizlendi — geri kalanı başarısız oldu; PURGETESTS\'i tekrar deneyin',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Operasyonu olmayan ${count} test QSO\'su temizlendi', other: 'Operasyonu olmayan ${count} test QSO\'su temizlendi', ), 
			'commands.purgeTestsContactsFailed' => 'Test Operasyonları temizlendi, ancak operasyonu olmayan test QSO\'ları başarısız oldu; PURGETESTS\'i tekrar deneyin',
			'commands.purgeTestsNothingToDo' => 'Hiçbir şey temizlenmedi',
			'commands.receivedPurgesSomeFailed' => ({required Object total, required Object removed}) => '${total} Test Operasyonundan ${removed} tanesi kaldırıldı — geri kalanı başarısız oldu; İncele\'yi tekrar deneyin',
			'commands.receivedPurgesFailed' => 'Bu Test Operasyonları kaldırılamadı — İncele\'yi tekrar deneyin',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} Test Operasyonu başka bir cihazda kaldırıldı', other: '${count} Test Operasyonu başka bir cihazda kaldırıldı', ), 
			'commands.receivedPurgesReview' => 'İncele',
			'commands.settingOn' => 'Açık',
			'commands.settingOff' => 'Kapalı',
			'commands.settingEmpty' => '(boş)',
			'commands.settingSecretSet' => '(ayarlı)',
			'commands.settingSecretUnset' => '(ayarlanmadı)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} seçili',
			'commands.settingExpectsOnOff' => 'açık veya kapalı',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'şunlardan biri: ${choices}',
			'commands.settingExpectsNumber' => 'bir sayı',
			'commands.settingVanished' => ({required Object label}) => '“${label}” artık kullanılamıyor',
			'commands.noCwKeyer' => 'Bağlı hiçbir radyo CW gönderemiyor',
			'commands.noKeyer' => 'Bağlı hiçbir radyo CW gönderemiyor veya ses hafızası oynatamıyor',
			'commands.keyerNeedsOperation' => 'CW keyer\'ı kullanmak için bir operasyon açın',
			'commands.keyerExperimentOff' => 'CW manipülasyonu kapalı — EXP KEYER ile açın',
			'commands.esmExperimentOff' => 'Enter Mesaj Gönderir kapalı — EXP ESM ile açın',
			'commands.cwSending' => ({required Object text}) => 'CW gönderiliyor: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW mesajı F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW mesajı F${n} gönderilmedi: uzantılar hazır değil',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” bu değeri kabul etmedi',
			'commandDialog.hint' => 'Çağrı işareti arayın veya bir komut yazın',
			'commandDialog.noResults' => ({required Object text}) => '“${text}” ile eşleşen bir şey yok',
			'commandDialog.sectionCommands' => 'Komutlar',
			'commandDialog.sectionGoTo' => 'Git',
			'commandDialog.sectionOperations' => 'Operasyonlar',
			'commandDialog.goHome' => 'Ana Sayfa',
			'commandDialog.goSettings' => 'Ayarlar',
			'commandDialog.goNewOperation' => 'Yeni operasyon',
			'commandDialog.runTyped' => ({required Object text}) => '“${text}” çalıştır',
			'commandDialog.sectionSuggestions' => 'Deneyin',
			'commandDialog.lookingUp' => 'Çağrı işareti sorgulanıyor…',
			'commandDialog.blockedByPane' => 'Bir panel veya pencere açıkken komutlar kullanılamaz',
			'expiredBuild.title' => 'Bu sürümün süresi doldu',
			'expiredBuild.body' => 'Lütfen ham2k.com adresini ziyaret edip daha yeni bir sürüm edinin.',
			'expiredBuild.visit' => 'ham2k.com\'u ziyaret et',
			'expiredBuild.dismiss' => 'Yine de devam et',
			'staleness.codePushFloorTitle' => 'Önemli bir güncelleme bekliyor',
			'staleness.codePushFloorBody' => 'Bu sürümde henüz sizde olmayan bir düzeltme var.',
			'staleness.restartToApply' => 'Uygulamak için uygulamayı yeniden başlatın.',
			'staleness.quitAndReopen' => 'Uygulamak için uygulamadan çıkıp yeniden açın.',
			'staleness.reopenToApply' => 'Uygulamak için uygulamayı kapatıp yeniden açın.',
			'staleness.ignoreForNow' => 'Şimdilik yok say',
			'spotting.noQsoYet' => 'Spotlanacak kaydedilmiş QSO henüz yok.',
			'spotting.setFrequencyFirst' => 'Önce bir frekans ayarlayın.',
			'spotting.nothingToSpot' => 'Spotlanacak bir şey yok — burada hiçbir uzantı spotlama sunmuyor.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} başarısız: ${message}',
			'spotting.unknownError' => 'bilinmeyen hata',
			'spotting.notSent' => 'Spot gönderilmedi.',
			'spotting.notRefreshedOffline' => 'Bağlantı yok — spotlar yenilenmedi',
			'dataFiles.downloading' => 'İndiriliyor…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name} indirilemedi',
			'dataFiles.downloadFailedWebHint' => 'Bu bir ağ sorunu olabilir veya bu bağlantının sunucusu web tarayıcısından doğrudan indirmeyi desteklemiyor olabilir. Masaüstü veya mobil uygulamayı ya da farklı bir barındırma yerini deneyin.',
			'dataFiles.downloadTimedOut' => 'Sunucunun yanıt vermesi çok uzun sürdü. Daha sonra tekrar deneyin.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} bir hatayla yanıt verdi (HTTP ${status}). Daha sonra tekrar deneyin.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} bu dosyayı sağlayamadı (HTTP ${status}). Adresinin hâlâ doğru olduğunu kontrol edin.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name} işlenemedi',
			'dataFiles.importTooSmall' => ({required Object existing, required Object imported}) => 'İndirmede bu cihazdaki ${existing} kayıttan yalnızca ${imported} tanesi vardı, bu yüzden dışarıda bıraktıkları korundu. Ayarlar › Çevrimdışı Veri bölümünden yenilemek onu yine de kabul eder.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${label} için ${count} kayıt içe aktarıldı.', other: '${label} için ${count} kayıt içe aktarıldı.', ), 
			'dataFiles.importedData' => ({required Object label}) => '${label} için veriler içe aktarıldı.',
			'dataFiles.cleanedUpTitle' => 'Uzantı verileri temizlendi',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Devre dışı uzantılara ait ${count} veri dosyasının verileri kaldırıldı.', other: 'Devre dışı uzantılara ait ${count} veri dosyasının verileri kaldırıldı.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} kayıt',
			'dataFiles.definitionUnavailable' => 'Dosyanın kaynağı bir tanım sağlamadı — uzantısı yeniden başlıyor veya yanlış yapılandırılmış olabilir. Birazdan tekrar deneyin.',
			'updates.updateAvailable' => 'Güncelleme mevcut',
			'updates.newVersionAvailable' => ({required Object version}) => 'Yeni bir sürüm (${version}) mevcut.',
			'updates.getIt' => 'Edinin',
			'updates.ok' => 'Tamam',
			'updates.updateReady' => 'Güncelleme hazır',
			'updates.restartToApply' => 'Bir güncelleme indirildi. Uygulamak için yeniden başlatın.',
			'updates.appliesNextLaunch' => 'Bir güncelleme indirildi. Uygulamayı bir sonraki açışınızda uygulanacak.',
			'updates.restartNow' => 'Şimdi yeniden başlat',
			'updates.reloadToUpdate' => 'Bu sayfanın daha yeni bir sürümü mevcut. Almak için yeniden yükleyin.',
			'updates.reloadNow' => 'Şimdi yeniden yükle',
			'updates.checkForUpdates' => 'Güncellemeleri Kontrol Et',
			'updates.checkingForUpdates' => 'Güncellemeler kontrol ediliyor…',
			'updates.upToDate' => 'Güncel',
			'updates.automaticChecks' => 'Otomatik kontrol et',
			'updates.automaticChecksDescription' => 'Uygulamayı bir sonraki başlatışınızdan itibaren arka planda yeni sürümleri ara',
			'extensionService.runtimeNotReady' => 'Uzantı çalışma ortamı hazır değil.',
			'extensionService.testFailed' => ({required Object error}) => 'Test başarısız: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => '${identity} olarak bağlı',
			'extensionService.invalidFieldConfiguration' => 'Geçersiz alan yapılandırması',
			'extensionService.invalidValue' => 'Geçersiz değer',
			'extensionService.validationError' => ({required Object error}) => 'Doğrulama hatası: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Eylem başarısız: ${error}',
			'extensionService.commandFailed' => 'Komut çalıştırılamadı',
			'extensionService.reportUnavailable' => 'Raporlar şu anda gönderilemiyor',
			'extensionService.stashUnavailable' => 'Ham2K File Stash\'e şu anda ulaşılamıyor',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} zamanlayıcılarında çok fazla zaman harcadı. Uzantılar yeniden başlayana kadar durduruldular.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name} zamanlayıcıları sürekli başarısız oldu. Uzantılar yeniden başlayana kadar durduruldular.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} bir zamanlayıcıda takıldı. Zamanlayıcıları uzantılar yeniden başlayana kadar durduruldu.',
			'operationLocationScreen.title' => 'Operasyon Konumu',
			'operationLocationScreen.selectedLocation' => 'Seçilen Konum',
			'operationLocationScreen.gridSquare' => 'Maidenhead Grid Square Konum Bulucu',
			'operationLocationScreen.gridInvalid' => 'FN31pr gibi 4, 6, 8 veya 10 karakter gerekir',
			'operationLocationScreen.suggestedLocations' => 'Önerilen Konumlar',
			'operationLocationScreen.deviceGps' => 'Cihaz GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => '${device} cihazından GPS',
			'operationLocationScreen.locating' => 'Yer tespiti yapılıyor…',
			'operationLocationScreen.gpsUnavailable' => 'Konum kullanılamıyor',
			'operationLocationScreen.permissionDenied' => 'Konum izni reddedildi',
			'operationLocationScreen.permissionBlocked' => 'Konum izni engellendi',
			'operationLocationScreen.moreDetails' => 'Diğer Ayrıntılar',
			'operationLocationScreen.stateOrProvince' => 'Eyalet veya İl (isteğe bağlı)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Aktivite kontrolleri kullanılamıyor',
			'operationLocationScreen.controlsUnavailableReason' => 'Bu referanslar hâlâ kullanılabilir; yalnızca aktivitelerine ulaşılamadı.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Tekrar dene',
			'operationLocationScreen.county' => 'İlçe (isteğe bağlı)',
			'versionLabel.version' => ({required Object version}) => 'Sürüm ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Yama ${patch}',
			'versionLabel.build' => ({required Object build}) => 'derleme ${build}',
			'notices.emptyHistory' => 'Henüz bildirim yok',
			'notices.webStorageInMemory' => 'Bu tarayıcı kalıcı depolama sağlayamadı — günlük yalnızca bellekte duruyor ve bu sekme kapandığında KAYBOLACAK. Güncel bir Chrome, Firefox, Safari veya Edge kullanın.',
			'notices.webStorageUnreliable' => 'Bu tarayıcı birden fazla sekmeyle güvenli olmayan yedek bir depolama kullanıyor — tek bir sekme açık tutun ve senkronizasyonu açık bırakın.',
			'notices.logFromNewerBuildTitle' => 'Bu günlük daha yeni bir sürüm gerektiriyor',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Günlüğünüz HaLo\'nun daha yeni bir sürümüyle yazılmış (depolama sürümü ${storage}; bu sürüm ${understood} sürümünü anlıyor), bu yüzden açılamıyor ve yeni QSO\'lar kaydedilmeyecek. Daha yeni sürümü yeniden yükleyin — ya da bu sürümü çalıştırmak istediyseniz onu farklı bir veri klasörüne yönlendirin. Günlük şurada: ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Günlüğünüz HaLo\'nun daha yeni bir sürümüyle yazılmış (depolama sürümü ${storage}; bu sürüm ${understood} sürümünü anlıyor), bu yüzden açılamıyor ve yeni QSO\'lar kaydedilmeyecek. Bunun yerine bu günlüğü o daha yeni sürümle açın.',
			'notices.preferencesRestoredTitle' => 'Ayarlar bir yedekten geri yüklendi',
			'notices.preferencesRestored' => 'Ayarlar dosyası okunamadı, bu yüzden HaLo onun son sağlam kopyasını geri yükledi. Önceki oturumunuzda değiştirdiğiniz şeyleri yeniden ayarlamanız gerekebilir. Okunamayan dosya, shared_preferences.corrupt-….json adıyla yanında saklanıyor.',
			'notices.preferencesResetTitle' => 'Ayarlar sıfırlandı',
			'notices.preferencesReset' => 'Ayarlar dosyası okunamadı ve geri dönülecek bir yedek yoktu, bu yüzden HaLo varsayılanlarıyla başladı. Okunamayan dosya, uygulamanın veri klasöründe shared_preferences.corrupt-….json adıyla saklanıyor.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} otomatik olarak bağlanmadı',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo, ${name} cihazına son bağlanmaya başladığında yanıt vermeyi bıraktı, bu yüzden aynı şeyi tekrar riske atmak yerine bu kez ona dokunmadı. Radyonun açık ve kablosunun takılı olduğunu kontrol edin, ardından Ayarlar\'da onun için Bağlan\'a basın.',
			'syncAccount.anonymous' => ({required Object id}) => 'Anonim Hesap (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (onay bekleniyor)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (onay bekleniyor - #${id})',
			'deepLink.needsAnOperation' => 'Önce bir operasyon başlatın, ardından o QSO\'yu tekrar gönderin',
			'deepLink.waitingInOperation' => 'O QSO, bu ekranın arkasındaki operasyonda bekliyor',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Bu cihazda ${refs} için aktivite yok, bu yüzden bu referanslar dışarıda bırakıldı',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Aktivitelerinize ulaşılamadı, bu yüzden ${refs} dışarıda bırakıldı — o bağlantıyı tekrar deneyin',
			'confirmDevice.title' => 'Bir Cihazı Onayla',
			'confirmDevice.codePrompt' => 'Bu hesaba katılmak isteyen cihazda gösterilen kodu girin.',
			'confirmDevice.code' => 'Kod',
			'confirmDevice.lookUp' => 'Sorgula',
			'confirmDevice.codeNotFound' => 'Bu kodla eşleşen istek yok. Kodların süresi 10 dakika sonra dolar — diğer cihazdan yeni bir kod isteyin.',
			'confirmDevice.linkExpired' => 'Bu bağlantının süresi doldu. Diğer cihazdan yeni bir QR kodu göstermesini isteyin.',
			'confirmDevice.areYouSure' => ({required Object device}) => '${device} bu hesaba bağlansın mı?',
			'confirmDevice.unnamedDevice' => 'isimsiz bir cihaz',
			'confirmDevice.grantWarning' => 'Bu hesaptaki her operasyonu ve QSO\'yu okuyabilecek ve değiştirebilecek.',
			'confirmDevice.needsSyncTitle' => 'Bu cihaz henüz senkronize olmuyor',
			'confirmDevice.needsSyncText' => 'Başka bir cihazı kabul edebilmesi için Ham2K Log Filer senkronizasyonunu açın ve bu cihazı bir hesaba bağlayın.',
			'confirmDevice.malformedRequest' => 'Senkronizasyon sunucusu bu uygulamanın okuyamadığı bir istek gönderdi. Diğer cihazdan tekrar denemesini isteyin.',
			'confirmDevice.linkIt' => 'Cihazı Bağla',
			'switchAccounts.noAccountDetails' => 'Henüz hesap ayrıntısı yok',
			'switchAccounts.currentAccount' => 'Mevcut hesap',
			'switchAccounts.otherAccounts' => 'Diğer hesaplar',
			'switchAccounts.linkToAnother' => 'Başka bir hesaba bağla',
			'switchAccounts.linkWithSibling' => 'Başka bir Ham2K uygulamasıyla bağla',
			'switchAccounts.linkWithPolo' => 'Eski sürümdeki hesapla bağla',
			'switchAccounts.linkWithSiblingDescription' => 'Yüklü başka bir Ham2K uygulamanız var. Orada kullanılan hesapla bağlayın.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'İsteği ${app} içinde onaylayın, ardından buraya geri dönün.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '${app} uygulamasını yeniden aç',
			'switchAccounts.siblingNoGrant' => 'Olmadı mı? Yeniden açın ya da geri dönüp başka bir yolla bağlayın.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app} açılamadı.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Bağlantının süresi doldu ve yenisi hazır — ${app} uygulamasını yeniden açın.',
			'switchAccounts.tryAgain' => 'Tekrar dene',
			'switchAccounts.linkWithQr' => 'QR koduyla bağla',
			'switchAccounts.linkWithQrDescription' => 'Hesabı zaten kullanan bir cihazdan tarayın',
			'switchAccounts.linkWithEmail' => 'E-posta adresiyle bağla',
			'switchAccounts.linkWithEmailDescription' => 'Bir kod veya e-posta bağlantısıyla onaylayın',
			'switchAccounts.enterEmailPrompt' => 'Bu cihazın kullanmasını istediğiniz hesabın e-posta adresini girin.',
			'switchAccounts.emailAddress' => 'E-posta adresi',
			'switchAccounts.linkAccount' => 'Hesabı bağla',
			'switchAccounts.copiedCode' => 'Kod panoya kopyalandı',
			'switchAccounts.copyCode' => 'Kodu kopyala',
			'switchAccounts.codePrompt' => ({required Object email}) => '${email} ile zaten bağlı bir cihazda Ham2K uygulamasını açın ve isteği onaylamak için bu kodu girin:',
			'switchAccounts.waitingForConfirmation' => 'Onay bekleniyor…',
			'switchAccounts.sendEmailInstead' => 'Bunun yerine onay e-postası gönder',
			'switchAccounts.emailSent' => ({required Object email}) => '${email} adresine bir e-posta gönderildi. Bu cihazı bağlamak için e-postayı açıp isteği onaylayın.',
			'switchAccounts.resendEmail' => 'E-postayı yeniden gönder',
			'switchAccounts.qrPrompt' => 'Bu QR kodunu, istediğiniz hesaba zaten bağlı bir cihazdan tarayın — örneğin telefonunuzdaki Ham2K Portable Logger ile.',
			'switchAccounts.serverUnreachable' => 'Senkronizasyon sunucusuna ulaşılamadı. Daha sonra tekrar deneyin.',
			'switchAccounts.emailRequired' => 'Bağlamak için bir e-posta adresi girin.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => '${email} için hesap bulunamadı.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Senkronizasyon sunucusu isteği reddetti: ${error}',
			'switchAccounts.noLinkCode' => 'Senkronizasyon sunucusu bir bağlantı kodu döndürmedi. Daha sonra tekrar deneyin.',
			'switchAccounts.noConfirmationCode' => 'Senkronizasyon sunucusu bir onay kodu göndermedi. Daha sonra tekrar deneyin.',
			'switchAccounts.switchNotAccepted' => 'Bu hesap geçişi kabul etmedi. Bunun yerine bir e-posta adresiyle bağlamayı deneyin.',
			'switchAccounts.requestFailed' => 'Senkronizasyon sunucusuyla iletişimde bir şeyler ters gitti. Daha sonra tekrar deneyin.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} QSO', other: '${count} QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} operasyon', other: '${count} operasyon', ), 
			'adifImport.title' => 'ADIF\'ten QSO İçe Aktar',
			'adifImport.reading' => ({required Object filename}) => '${filename} okunuyor…',
			'adifImport.dropHint' => 'İçe aktarmak için bir ADIF dosyası bırakın',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: 'Bu dosyada ${count} QSO', other: 'Bu dosyada ${formatted} QSO', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesi zaten günlüğünüzde', other: '${formatted} tanesi zaten günlüğünüzde', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesi içe aktarılacak', other: '${formatted} tanesi içe aktarılacak', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} yeni QSO', other: '${formatted} yeni QSO', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesi mevcut bir QSO ile birleşecek', other: '${formatted} tanesi mevcut QSO\'larla birleşecek', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesi içe aktarılamaz (çağrı işareti yok)', other: '${formatted} tanesi içe aktarılamaz (çağrı işareti yok)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesinin daha yakından incelenmesi gerekiyor', other: '${formatted} tanesinin daha yakından incelenmesi gerekiyor', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} QSO için referanslar kurtarılamadı', other: '${formatted} QSO için referanslar kurtarılamadı', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} QSO için ${programs} referansları eksik olabilir', other: '${formatted} QSO için ${programs} referansları eksik olabilir', ), 
			'adifImport.stackingTypesUnknown' => 'Birleştirilen QSO\'lar bir referansı kaybedebilir — aktiviteler hangi türlerin üst üste eklenebildiğini bildiremedi. Bunu önlemek için iptal edip yeniden deneyin.',
			'adifImport.nothingToImport' => 'Bu dosyada içe aktarılabilecek bir şey yok',
			'adifImport.confirm' => 'İçe Aktar',
			'adifImport.importing' => ({required Object filename}) => '${filename} içe aktarılıyor…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${filename} dosyasından ${count} QSO içe aktarıldı', other: '${filename} dosyasından ${formatted} QSO içe aktarıldı', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename} içe aktarılamadı: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} bir ADIF dosyasına benzemiyor',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Uyarı: bu ADIF\'te ${calls} çağrılarına ait QSO\'lar var, ancak devam ederseniz ${station} olarak içe aktarılacaklar.',
			'adifImport.stationCallJoin' => ' ve ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('tr'))(count, one: '${count} tanesinin tarihi yok ve içe aktarılamaz', other: '${formatted} tanesinin tarihi yok ve içe aktarılamaz', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Bu dosya ${refs} aktivasyonunu kaydediyor.',
			'adifImport.addActivation' => 'Bu operasyona ekle',
			'adifImport.shortfall' => ({required Object planned, required Object written}) => '${planned} kayıttan yalnızca ${written} tanesi uygulanabildi — siz karar verirken günlük değişti.',
			'adifImport.busy' => 'Zaten bir içe aktarma çalışıyor. Başka birini başlatmadan önce bitmesini bekleyin.',
			'adifImport.oneFileOnly' => 'Her seferinde bir ADIF dosyası bırakın — dosyaların içe aktarılma sırası hangi verinin geçerli olacağını belirler.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} dosyasında ${limit} QSO\'dan fazla var; bir operasyon tek seferde en fazla bu kadarını içe aktarabilir.',
			'offline.statusOffline' => 'İnternet: ÇEVRİMDIŞI',
			'offline.statusOnline' => 'İnternet: bağlı',
			'offline.noRoute' => 'Hiç ağ bağlantısı yok.',
			'offline.unreachable' => 'Ağ açık, ancak hiçbir sunucu yanıt vermiyor — çoğu zaman bir tarayıcıda bekleyen bir giriş sayfasının işareti.',
			'offline.reachable' => 'Tüm hizmetler beklendiği gibi yanıt veriyor.',
			'offline.whatStops' => 'Sorgular, spotlar ve veri dosyaları duraklatıldı. Kayıt ve yakındaki cihazlarla senkronizasyon duraklatılmadı.',
			'offline.servicesTitle' => 'Hizmetler',
			'offline.noServices' => 'Henüz hiçbir hizmet durum bildirmedi.',
			'offline.lastSuccess' => ({required Object when}) => 'Son yanıt ${when} önce',
			'offline.neverSucceeded' => 'Henüz yanıt vermedi',
			'offline.nextAttempt' => ({required Object when}) => 'Sonraki deneme ${when} sonra',
			'offline.nextAttemptNow' => 'Sonraki deneme zamanı geldi',
			'offline.retry' => 'Şimdi tekrar dene',
			'offline.retrying' => 'Deneniyor…',
			'offline.retryReached' => 'Yeniden çevrimiçi.',
			'offline.retryUnreachable' => 'Hâlâ yanıt yok.',
			'offline.retryNotAttempted' => 'Şu anda gönderilecek bir şey yok.',
			'offline.retryThrottled' => 'Az önce denendi — biraz bekleyin.',
			'offline.retryDisabled' => 'Senkronizasyon kapalı, bu yüzden yoklama yapılacak bir şey yok.',
			'offline.syncService' => 'Ham2K LoFi senkronizasyonu',
			'offline.retryInFlight' => 'Zaten deneniyor — bekleyin.',
			'exportSettings.defaultsDescription' => 'Tüm dışa aktarımlar için temel ayarlar; referans aktiviteleri ve diğer aktiviteler için ayrı dosya adı ve başlık şablonlarıyla. Her dışa aktarma türü kendi varsayılanlarını veya özel ayarlarını sağlayabilir.',
			'exportSettings.referenceActivities' => 'Referans Aktiviteleri',
			'exportSettings.otherActivities' => 'Diğer Aktiviteler',
			'exportSettings.adifFields' => 'ADIF Alanları',
			'exportSettings.loadFailed' => 'Dışa aktarma ayarları yüklenemedi.',
			'exportSettings.retry' => 'Tekrar dene',
			'exportSettings.compactFileNamesDescriptionOn' => 'Kısa dosya adları, örneğin N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Açıklayıcı dosya adları, örneğin 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'ADIF dosyalarına isimler, adresler, e-postalar, notlar ve kesin konumlar dahil ediliyor.',
			'exportSettings.includePrivateDataDescriptionOff' => 'İsimler, adresler, e-postalar ve notlar çıkarılıyor; konumlar altı karakterli grid\'lerle sınırlanıyor.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Çağrı işareti sorgu hizmetlerinden gelen bilgiler dahil ediliyor.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Çağrı işareti sorgu hizmetlerinden gelen bilgiler çıkarılıyor; elle girilen değerler korunuyor.',
			'exportSettings.customTemplatesDescriptionOn' => 'Özel şablonlarınız etkin ve aşağıda düzenlenebilir.',
			'exportSettings.customTemplatesDescriptionOff' => 'Varsayılan şablonlar etkin. Özel şablonlarınız daha sonrası için saklanıyor.',
			'exportSettings.type' => 'Dışa aktarma türü',
			'exportSettings.defaults' => 'Varsayılanlar',
			'exportSettings.includeLookupData' => 'Sorgu verilerini dahil et',
			'exportSettings.customTemplates' => 'Özel şablonlar',
			'exportSettings.filenameTemplate' => 'Dosya adı şablonu',
			'exportSettings.compactFilenameTemplate' => 'Kısa dosya adı şablonu',
			'exportSettings.titleTemplate' => 'Başlık şablonu',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO Notları',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO Yorumları',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL Mesajı',
			'exportSettings.shared' => 'Ayarlar, bu dışa aktarma türünü kullanan her uzantıya uygulanır.',
			'exportSettings.defaultTemplates' => 'Bu türün şablonlarını düzenlemek için Özel şablonlar\'ı açın.',
			'templateEditor.previewLabel' => 'Önizleme:',
			'templateEditor.reset' => 'Sıfırla',
			'templateEditor.docs' => 'Şablon Belgeleri',
			'templateEditor.preview' => 'Örnek önizleme',
			'templateEditor.reference' => 'Şablon referansı',
			'templateEditor.attributes' => 'Kullanılabilir Öznitelikler',
			'templateEditor.filters' => 'Filtreler',
			'templateEditor.flowControl' => 'Akış Kontrolü',
			'templateEditor.unavailable' => 'Uzantılar hazır olana kadar önizleme kullanılamaz.',
			'templateEditor.empty' => '(boş çıktı)',
			_ => null,
		};
	}
}
