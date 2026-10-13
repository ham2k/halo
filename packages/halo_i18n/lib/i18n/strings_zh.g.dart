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
class TranslationsZh extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsZh({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.zh,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <zh>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsZh _root = this; // ignore: unused_field

	@override 
	TranslationsZh $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsZh(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$zh common = _Translations$common$zh._(_root);
	@override late final _Translations$onboarding$zh onboarding = _Translations$onboarding$zh._(_root);
	@override late final _Translations$startScreen$zh startScreen = _Translations$startScreen$zh._(_root);
	@override late final _Translations$testerOverlay$zh testerOverlay = _Translations$testerOverlay$zh._(_root);
	@override late final _Translations$extensionsPanel$zh extensionsPanel = _Translations$extensionsPanel$zh._(_root);
	@override late final _Translations$home$zh home = _Translations$home$zh._(_root);
	@override late final _Translations$chase$zh chase = _Translations$chase$zh._(_root);
	@override late final _Translations$dialogs$zh dialogs = _Translations$dialogs$zh._(_root);
	@override late final _Translations$operation$zh operation = _Translations$operation$zh._(_root);
	@override late final _Translations$map$zh map = _Translations$map$zh._(_root);
	@override late final _Translations$mapsView$zh mapsView = _Translations$mapsView$zh._(_root);
	@override late final _Translations$activitiesView$zh activitiesView = _Translations$activitiesView$zh._(_root);
	@override late final _Translations$loggingControls$zh loggingControls = _Translations$loggingControls$zh._(_root);
	@override late final _Translations$formChrome$zh formChrome = _Translations$formChrome$zh._(_root);
	@override late final _Translations$qsoEditForm$zh qsoEditForm = _Translations$qsoEditForm$zh._(_root);
	@override late final _Translations$qsoList$zh qsoList = _Translations$qsoList$zh._(_root);
	@override late final _Translations$loggingPanel$zh loggingPanel = _Translations$loggingPanel$zh._(_root);
	@override late final _Translations$callInfo$zh callInfo = _Translations$callInfo$zh._(_root);
	@override late final _Translations$settings$zh settings = _Translations$settings$zh._(_root);
	@override late final _Translations$commands$zh commands = _Translations$commands$zh._(_root);
	@override late final _Translations$commandDialog$zh commandDialog = _Translations$commandDialog$zh._(_root);
	@override late final _Translations$expiredBuild$zh expiredBuild = _Translations$expiredBuild$zh._(_root);
	@override late final _Translations$staleness$zh staleness = _Translations$staleness$zh._(_root);
	@override late final _Translations$spotting$zh spotting = _Translations$spotting$zh._(_root);
	@override late final _Translations$dataFiles$zh dataFiles = _Translations$dataFiles$zh._(_root);
	@override late final _Translations$updates$zh updates = _Translations$updates$zh._(_root);
	@override late final _Translations$extensionService$zh extensionService = _Translations$extensionService$zh._(_root);
	@override late final _Translations$operationLocationScreen$zh operationLocationScreen = _Translations$operationLocationScreen$zh._(_root);
	@override late final _Translations$versionLabel$zh versionLabel = _Translations$versionLabel$zh._(_root);
	@override late final _Translations$notices$zh notices = _Translations$notices$zh._(_root);
	@override late final _Translations$syncAccount$zh syncAccount = _Translations$syncAccount$zh._(_root);
	@override late final _Translations$deepLink$zh deepLink = _Translations$deepLink$zh._(_root);
	@override late final _Translations$confirmDevice$zh confirmDevice = _Translations$confirmDevice$zh._(_root);
	@override late final _Translations$switchAccounts$zh switchAccounts = _Translations$switchAccounts$zh._(_root);
	@override late final _Translations$adifImport$zh adifImport = _Translations$adifImport$zh._(_root);
	@override late final _Translations$offline$zh offline = _Translations$offline$zh._(_root);
	@override late final _Translations$exportSettings$zh exportSettings = _Translations$exportSettings$zh._(_root);
	@override late final _Translations$templateEditor$zh templateEditor = _Translations$templateEditor$zh._(_root);
}

// Path: common
class _Translations$common$zh extends Translations$common$en {
	_Translations$common$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get save => '保存';
	@override String get ok => '确定';
	@override String get cancel => '取消';
	@override String get delete => '删除';
	@override String get create => '创建';
	@override String get error => '错误';
	@override String get close => '关闭';
	@override String get done => '完成';
	@override String get callsign => '呼号';
	@override String get clear => '清除';
	@override String get dismiss => '忽略';
	@override String get expand => '展开';
	@override String get collapse => '收起';
}

// Path: onboarding
class _Translations$onboarding$zh extends Translations$onboarding$en {
	_Translations$onboarding$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => '欢迎使用 Ham2K Portable Logger！';
	@override String get welcomeTitleDesktop => '欢迎使用 Ham2K Power Logger！';
	@override String get welcomeBody => '请回答几个问题，帮助我们更好地满足您的需求。';
	@override String get skip => '跳过';
	@override String get kContinue => '继续';
	@override String get back => '返回';
	@override String get next => '下一步';
	@override String get done => '完成';
	@override String get callsignTitle => '您的呼号是什么？';
	@override String get callsignBody => '您需要业余无线电操作证书才能用好这个应用';
	@override String get callsignLabel => '操作员呼号';
	@override String get alreadyHaveAccount => '已有账户？';
	@override String get foundSiblingTitle => '链接现有账户？';
	@override String foundSiblingBody({required Object app}) => '我们在此设备上发现了 ${app}。将此应用链接到同一账户，您的呼号和日志就会同步过来。';
	@override String get foundPoloBody => '我们在此设备上发现了旧版 Ham2K Portable Logger。将此应用链接到同一账户，您的呼号和日志就会同步过来。';
	@override String get foundSiblingsBody => '我们在此设备上发现了其他 Ham2K 应用。将此应用链接到其中一个账户，您的呼号和日志就会同步过来。';
	@override String linkWithApp({required Object app}) => '与 ${app} 链接';
	@override String get linkWithPolo => '与旧版中的账户链接';
	@override String get setUpFresh => '全新设置';
	@override String get activitiesTitle => '喜爱的活动';
	@override String get activitiesBody => '您对以下热门激活项目感兴趣吗？';
	@override String get activitiesFooter => '（更多选项请见设置）';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => '数据与隐私';
	@override String get consentUsageBody => '为了帮助我们改进应用，我们希望收集性能、崩溃和应用使用数据。';
	@override String get consentUsageLabel => '分享应用使用数据';
	@override String get consentOperationBody => '某些功能可能会与其他用户共享您的操作数据。您可以随时选择退出。';
	@override String get consentOperationLabel => '共享操作数据';
	@override String get finishingSetup => '正在完成设置——下载参考数据…';
}

// Path: startScreen
class _Translations$startScreen$zh extends Translations$startScreen$en {
	_Translations$startScreen$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get credits => '由 KI2D 和朋友们制作';
}

// Path: testerOverlay
class _Translations$testerOverlay$zh extends Translations$testerOverlay$en {
	_Translations$testerOverlay$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get tape => '注意：施工中';
	@override String get warningTitle => '此应用仍在开发中';
	@override String get warningBody => '大多数功能还坑坑洼洼，到处都有绊脚的地方。请定期检查更新。';
	@override String whatsNew({required Object build}) => '构建 ${build} 的新内容';
	@override String get thanks => '感谢您冒着日志的风险帮助我们改进这个应用！';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$zh extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => '活动';
	@override String get categoryContest => '竞赛';
	@override String get categoryLookup => '呼号查询';
	@override String get categorySpots => '信号来源';
	@override String get categoryDashboard => '仪表板面板';
	@override String get categoryOther => '其他扩展';
	@override String get searchHint => '搜索扩展';
	@override String get applying => '正在应用扩展更改，这可能需要一些时间…';
	@override String get noMatches => '没有与搜索匹配的扩展';
	@override String get installFromFile => '从文件安装…';
	@override String installVersion({required Object version}) => '版本 ${version}';
	@override String get canReach => '此扩展可以连接';
	@override String canHoldConnection({required Object host}) => '${host}，通过持续连接';
	@override String get canHoldLocalConnection => '本地网络上的设备，通过持续连接';
	@override String get canUseLocation => '您的位置';
	@override String get canReadRadio => '您的电台，用于读取其频率和模式';
	@override String get canControlRadio => '您的电台，用于控制和发射——调谐、功率、CW、语音存储和 PTT';
	@override String get canSetUserAgent => '以自己的名称向服务器标识自身';
	@override String get noCapabilities => '它不请求应用之外的任何权限。';
	@override String get sandboxNote => '扩展在沙盒中运行：无法访问您的文件，也只能访问此处列出的网络。';
	@override String get installAction => '安装';
	@override String get updateAction => '更新';
	@override String get installFailed => '无法安装该扩展';
	@override String get installedBadge => '已安装';
	@override String get uninstallAction => '移除';
	@override String uninstallTitle({required Object name}) => '移除 ${name}？';
	@override String get uninstallBody => '此扩展及其设置将被移除。您的日志不受影响。';
	@override String installedMessage({required Object name}) => '已安装 ${name}';
	@override String get installDownloading => '下载中…';
	@override String get installWaiting => '等待安装…';
	@override String get installInstalling => '安装中…';
	@override String get installAwaitingApproval => '等待您的批准…';
	@override String installAlreadyRunning({required Object name}) => '${name} 已在安装中。';
	@override String updatedTo({required Object version}) => '已更新到 ${version}';
	@override String installIncomplete({required Object name}) => '${name} 未完成安装，可能需要重新安装。';
	@override String uninstallFailed({required Object name}) => '无法移除 ${name}';
	@override String installedFrom({required Object source}) => '下载自 ${source}';
	@override String get dropHint => '拖放 .h2kext 扩展文件以安装';
	@override String get dropOneOnly => '一次只能拖放一个扩展。';
	@override String downloadFailed({required Object source, required Object status}) => '${source} 对该扩展返回了 ${status}。';
	@override String get downloadTooLarge => '该下载文件太大，不可能是扩展。';
	@override String get downloadNotSecure => '该下载被重定向到了不安全的位置。';
	@override String get catalogSection => '目录';
	@override String get catalogLoading => '正在加载目录…';
	@override String get catalogUnreachable => '无法访问目录';
	@override String get builtIn => '内置';
	@override String get updateAvailableBadge => '有可用更新';
	@override String get updatesAvailableTitle => '扩展更新';
	@override String updateAvailableFor({required Object name}) => '${name} 有可用更新。';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} 及其他 ${count} 个扩展需要更新。';
	@override String updatesAvailableFor({required Object names}) => '${names} 需要更新。';
	@override String get pendingUpdatesSection => '待更新';
	@override String get updateAllAction => '全部更新';
	@override String get updatesUnderWay => '这些更新已在进行中。';
	@override String get updatesNothingLeft => '您的扩展均为最新版本。';
	@override String get updatesNoticeAction => '更多信息';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '更新 ${count} 个扩展？',
		other: '更新 ${count} 个扩展？',
	);
	@override String get upgradeDoneTitle => '您的扩展已就绪';
	@override String get upgradeDoneBody => '它们现在来自 Ham2K 扩展目录，因此无需等待应用新版本即可更新。';
	@override String upgradeDoneUnserved({required Object names}) => '未升级：${names}。';
	@override String upgradeDoneRefused({required Object names}) => '无法运行：${names}。';
	@override String get upgradeDoneRefusedHint => '它们仍已安装，并在 设置 › 扩展 中有标记——在那里更新即可恢复。';
	@override String get upgradeDoneUnservedHint => '目录中没有它们的直接替代品，请在目录中寻找能覆盖您所用功能的扩展。';
	@override String get retiredQp => 'QSO Party';
	@override String get retiredStateparks => '州立公园活动';
	@override String upgradeDoneMissing({required Object count}) => '您有 ${count} 个扩展尚未下载。下次能访问扩展目录时会自动下载。';
	@override String get runtimeDeadBody => '您的扩展无法启动。重启应用应该可以恢复。';
	@override String get refusedTitle => '部分扩展无法运行';
	@override String get upgradeBusyTitle => '仍在设置中';
	@override String get upgradeRuntimeDeadTitle => '您的扩展未在运行';
	@override String get restoreTitle => '您的部分扩展缺失';
	@override String get restoreBody => '您安装的这些扩展不在此设备上。我们可以从 Ham2K 扩展目录重新下载：';
	@override String get restoreFromFile => '从文件安装。请从文件重新安装，或忘记它们：';
	@override String get restoreOtherCatalog => '从其他扩展目录安装，因此此处无法获取：';
	@override String get restoreForget => '忘记';
	@override String get restoreInstall => '安装';
	@override String get restoreLater => '稍后';
	@override String get restoreInstalling => '正在安装您的扩展…';
	@override String get restoreDoneTitle => '您的扩展已恢复';
	@override String restoreDoneBody({required Object names}) => '已重新安装：${names}。';
	@override String get restorePartialTitle => '部分扩展无法安装';
	@override String restoreFailed({required Object names}) => '无法安装：${names}。下次打开应用时我们会再次提供。';
	@override String get restoreBusyBody => '应用仍在设置您的扩展。下次打开应用时我们会再次提供这些扩展。';
	@override String get restoreRuntimeDeadBody => '我们已重新安装，但您的扩展无法启动。重启应用应该可以恢复。';
	@override String revokedTitle({required Object name}) => '${name} 已被撤回';
	@override String get revokedBody => '目录撤回了此版本，因此已将其禁用。';
	@override String get downloadHashMismatch => '该下载与目录描述的扩展不符。';
	@override String catalogVersionUnknown({required Object key, required Object version}) => '目录中没有 ${key} 的 ${version} 版本。';
	@override String get catalogLinkUnknown => '该目录链接未指明扩展版本。';
	@override String catalogNoRelease({required Object key}) => '目录中没有 ${key} 在该轨道上的发布版本。';
	@override String get installFromLink => '从链接安装';
	@override String get unstableReleaseWarning => '这是不稳定版本，发布者尚未将其定为完成版。它可能运行异常，并将持续接收不稳定版更新。';
	@override String get bleedingReleaseWarning => '这是前沿版本：仍在开发中，可能出错或丢失设置。它将持续接收前沿版更新。';
	@override String get channelUnstable => '不稳定';
	@override String get channelBleeding => '前沿';
	@override String get followsUnstable => '接收不稳定版和稳定版';
	@override String get followsBleeding => '接收前沿版、不稳定版和稳定版';
	@override String get followStableAction => '仅接收稳定版';
	@override String get revokedBadge => '已撤回';
	@override String get refusedBadge => '未加载';
	@override String get downloadNotHttps => '该下载未使用安全连接。';
	@override String downloadUnreachable({required Object source}) => '无法连接 ${source} 获取该扩展。';
	@override String get detailsAction => '详情';
	@override String get installedFromFile => '从文件安装';
	@override String get detailsWhatItDoes => '提供以下支持';
	@override String get installedPreloaded => '预装';
	@override String get hookAccount => '账户登录';
	@override String get hookCallNotes => '呼号备注';
	@override String get hookDataFile => '离线数据';
	@override String get hookExport => '导出';
	@override String get hookLookup => '呼号查询';
	@override String get hookScoring => '计分';
	@override String get hookSpots => '信号';
	@override String hookHunting({required Object program}) => '猎取 ${program}';
	@override String hookActivating({required Object program}) => '激活 ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '…还有 ${count} 个扩展',
		other: '…还有 ${count} 个扩展',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个可用扩展',
		other: '${count} 个可用扩展',
	);
}

// Path: home
class _Translations$home$zh extends Translations$home$en {
	_Translations$home$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'Portable Logger';
	@override String get newOperation => '新操作';
	@override String get stationCallsign => '电台呼号';
	@override String get titleOptional => '标题（可选）';
	@override String get emptyList => '还没有操作。创建一个即可开始记录。';
	@override String get quickLookup => '快速查询';
	@override late final _Translations$home$nav$zh nav = _Translations$home$nav$zh._(_root);
	@override late final _Translations$home$panels$zh panels = _Translations$home$panels$zh._(_root);
	@override String get toggleNav => '显示或隐藏导航标签';
	@override late final _Translations$home$logs$zh logs = _Translations$home$logs$zh._(_root);
}

// Path: chase
class _Translations$chase$zh extends Translations$chase$en {
	_Translations$chase$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => '追逐';
	@override String goalsTwo({required Object first, required Object second}) => '${first} 和 ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}、${second} 等';
	@override late final _Translations$chase$station$zh station = _Translations$chase$station$zh._(_root);
	@override late final _Translations$chase$periodInline$zh periodInline = _Translations$chase$periodInline$zh._(_root);
	@override late final _Translations$chase$periodStats$zh periodStats = _Translations$chase$periodStats$zh._(_root);
	@override late final _Translations$chase$period$zh period = _Translations$chase$period$zh._(_root);
	@override late final _Translations$chase$goals$zh goals = _Translations$chase$goals$zh._(_root);
	@override late final _Translations$chase$panels$zh panels = _Translations$chase$panels$zh._(_root);
}

// Path: dialogs
class _Translations$dialogs$zh extends Translations$dialogs$en {
	_Translations$dialogs$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => '操作详情';
	@override String get activities => '活动';
	@override String get stationCallsign => '电台呼号';
	@override String get multiStationIdentifier => '多站标识符（仅限数字）';
	@override String get notes => '备注';
	@override String get deleteOperationTitle => '删除操作';
	@override String get purgeTestsTitle => '清除测试操作';
	@override String get purgeTestsBody => '这将永久删除这些测试操作及其 QSO，且无法撤销。';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '另有 ${count} 个不属于任何操作的测试通联。',
		other: '另有 ${count} 个不属于任何操作的测试通联。',
	);
	@override String get purgeTestsAction => '清除';
	@override String get syncAllTitle => '替换此设备的日志？';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL 会备份并清除此设备上的 ${qsos}，然后从服务器重新下载该账户的日志。备份保留在此设备的数据库中。';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${n} 个 QSO 尚未同步——服务器从未收到，它将无法恢复。',
		other: '${n} 个 QSO 尚未同步——服务器从未收到，它们将无法恢复。',
	);
	@override String get syncAllAction => '清除并重新同步';
	@override String get receivedPurgesTitle => '已在其他设备上移除的测试操作';
	@override String get receivedPurgesBody => '这些操作已在另一台设备上作为测试操作删除。也在这里移除吗？这将永久删除它们及其 QSO，且无法撤销。';
	@override String get receivedPurgesAction => '移除';
	@override late final _Translations$dialogs$callChange$zh callChange = _Translations$dialogs$callChange$zh._(_root);
}

// Path: operation
class _Translations$operation$zh extends Translations$operation$en {
	_Translations$operation$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => '此操作已删除。取消删除后才能记录或更改。';
	@override late final _Translations$operation$tabs$zh tabs = _Translations$operation$tabs$zh._(_root);
	@override late final _Translations$operation$positions$zh positions = _Translations$operation$positions$zh._(_root);
	@override String get stationCallsignNone => '无电台呼号';
	@override String get titleNone => '无标题';
	@override String get deleteOperation => '删除操作';
	@override String get loggingControlsStale => '活动字段可能已过时——重新打开操作以刷新';
	@override String get locationNone => '未设置';
	@override String get generalOperation => '通用操作';
	@override String titleFor({required Object value}) => '参加 ${value}';
	@override String titleAt({required Object value}) => '在 ${value}';
	@override String segmentNow({required Object description}) => '当前 ${description}';
	@override String get testOperationSuffix => '测试';
	@override late final _Translations$operation$menu$zh menu = _Translations$operation$menu$zh._(_root);
	@override late final _Translations$operation$layout$zh layout = _Translations$operation$layout$zh._(_root);
	@override late final _Translations$operation$export$zh export = _Translations$operation$export$zh._(_root);
	@override late final _Translations$operation$spots$zh spots = _Translations$operation$spots$zh._(_root);
	@override late final _Translations$operation$import$zh import = _Translations$operation$import$zh._(_root);
}

// Path: map
class _Translations$map$zh extends Translations$map$en {
	_Translations$map$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$zh outlineIssue = _Translations$map$outlineIssue$zh._(_root);
	@override String get outlinesDisclaimer => '轮廓仅供参考，请自行核实！';
	@override String outlinesCredit({required Object sources}) => '轮廓：${sources}';
	@override String boundariesCredit({required Object sources}) => '行政边界：${sources}';
	@override String facilitiesCredit({required Object sources}) => '设施：${sources}';
	@override String get fullCredits => '完整数据来源';
	@override String get fewerCredits => '更少来源';
	@override String get emptyState => '还没有 QSO 位置。\n带有网格、州或国家的 QSO 会显示在这里。';
	@override String get unavailable => '地图目前不可用。';
	@override String qthPopupTitle({required Object grid}) => 'QTH：${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => '平面';
	@override String get globe => '地球仪';
	@override String get zoomIn => '放大';
	@override String get zoomOut => '缩小';
	@override late final _Translations$map$postcard$zh postcard = _Translations$map$postcard$zh._(_root);
}

// Path: mapsView
class _Translations$mapsView$zh extends Translations$mapsView$en {
	_Translations$mapsView$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '地图';
	@override String get searchHint => '搜索公园、山峰等';
	@override String get activities => '活动';
	@override String get layers => '图层';
	@override String get baseMap => '底图';
	@override String get satellite => '卫星影像 (Esri)';
	@override String get facilities => '公园设施';
	@override String get boundaries => '行政边界';
	@override String get currentLocation => '当前位置';
	@override String noMatches({required Object text}) => '没有与“${text}”匹配的内容';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${where} 处的 ${count} 个参考',
		other: '${where} 处的 ${count} 个参考',
	);
	@override String get startOperation => '用这些参考开始操作';
}

// Path: activitiesView
class _Translations$activitiesView$zh extends Translations$activitiesView$en {
	_Translations$activitiesView$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '活动';
	@override String get activitiesCountZero => '未选择活动';
	@override String get activitiesCountOne => '1 个活动';
	@override String activitiesCountOther({required Object count}) => '${count} 个活动';
	@override String get empty => '还没有活动——使用下方的建议和搜索来添加';
	@override String get removeActivity => '移除';
	@override String openReferenceLink({required Object name}) => '打开 ${name}';
	@override String get editActivity => '编辑活动';
	@override String get manageExtensions => '管理扩展';
	@override String get manage => '管理';
	@override String activitiesTitle1({required Object first}) => '活动类型：${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => '活动类型：${first} 和 ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => '活动类型：${first}、${second} 及其他 ${more} 个';
	@override String get reference => '参考';
	@override String get invalidReference => '无效';
	@override String get duplicateReference => '已添加';
	@override String get searchHint => '按名称、参考编号或其他内容搜索…';
	@override String get noSuggestions => '无匹配项';
	@override String get noSuggestionsHint => '在上方按参考名称或编号搜索';
	@override String get noSuggestionsExample => '（例如“trail”或“4556”）';
	@override String get allOptions => '活动类型';
	@override String get determiningLocation => '正在确定当前位置…\n等待 GPS 定位以查找附近的参考';
	@override String get locationUnavailableTitle => '位置数据不可用';
	@override String get locationDeniedTitle => '位置权限被拒绝';
	@override String get locationBlockedTitle => '位置权限被阻止';
	@override String get noNearbyReason => '无法确定附近的参考';
	@override String locationManualHint({required Object icon}) => '点按 ${icon} 手动输入位置，\n或直接按名称搜索参考';
	@override String get locationGrantAction => '允许访问位置';
	@override String get locationSettingsAction => '打开设置';
	@override String get locationSettingsUnavailable => '请在系统设置中允许访问位置';
	@override String get locationGrantRefused => '仍无法获取位置——系统再次拒绝';
	@override String get searchUnavailableTitle => '活动搜索不可用';
	@override String get searchUnavailableReason => '没有活动扩展能执行此搜索。请稍后重试。';
	@override String get emptySheet => '使用下方的建议和搜索来添加';
	@override String get exports => '导出';
	@override String get exportLogs => '导出日志';
	@override String get tools => '工具';
	@override String get toolsTitle => '操作工具';
	@override String get operationDetails => '操作详情';
	@override String get share => '分享';
	@override String get archive => '归档';
	@override String get deleteOperation => '删除操作';
	@override String get undeleteOperation => '取消删除操作';
	@override String get alreadySelected => '已选择';
	@override String get selected => '已选';
	@override String pickPosition({required Object index, required Object count}) => '${index} / ${count}';
	@override String get previousPick => '上一个匹配';
	@override String get nextPick => '下一个匹配';
	@override String get retiredReference => '已停用';
	@override String enableExtension({required Object name}) => '启用 ${name}';
	@override String get enableExtensionHint => '此扩展与您的搜索匹配，但当前未启用';
	@override String get enableExtensionForRefHint => '此扩展处理此操作的某个参考，但当前未启用';
	@override String extensionNotRunning({required Object name}) => '${name} 未在运行';
	@override String get extensionNotRunningHint => '此扩展已被禁用，请打开扩展设置了解详情';
	@override String installExtension({required Object name}) => '安装 ${name}';
	@override String get installExtensionHint => '此扩展与您的搜索匹配，但尚未安装';
	@override String get onlyCatalogMatches => '无匹配项\n目录中的某些扩展可能有结果。\n请在下方的活动类型中安装。';
	@override String get setupUnavailable => '无法加载此活动的设置——请从“管理”重试';
	@override String get controlsUnavailableTitle => '活动控件不可用';
	@override String get controlsUnavailableReason => '您的参考是安全的，但目前无法编辑。';
	@override String get controlsUnavailableRetry => '重试';
	@override String get onlyDisabledMatches => '无匹配项\n某些可用扩展可能有结果。\n请在下方的活动类型中启用。';
	@override String get onlyNotRunningMatches => '无匹配项\n某些可能有结果的扩展未在运行。\n请查看下方的活动类型。';
	@override String get mapToggle => '地图';
	@override String get searchToggle => '搜索';
	@override String get addToOperation => '添加到操作';
	@override String get addToOperationShort => '添加';
	@override String get mapEmptyState => '没有可在地图上显示的结果';
	@override String get mapEmptyStateHint => '切换回列表，或搜索其他内容';
	@override String get imports => '导入';
}

// Path: loggingControls
class _Translations$loggingControls$zh extends Translations$loggingControls$en {
	_Translations$loggingControls$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => '时间 (UTC)';
	@override String get date => '日期';
	@override String get now => '现在';
	@override String get frequency => '频率';
	@override String get mode => '模式';
	@override String get theirCall => '对方呼号';
	@override String get noteField => '备注';
	@override String get todoField => '待办';
	@override String get sent => '发送';
	@override String get rcvd => '接收';
	@override String get more => '更多';
	@override String get revert => '恢复';
	@override String get undoDelete => '撤销删除';
	@override String get restore => '还原';
	@override String get wipe => '清空';
	@override String get undo => '撤销';
	@override String get pendingDeleteTapWarning => '再点按一次垃圾桶即可删除此 QSO';
	@override String get pendingDeleteClickWarning => '再点击一次垃圾桶即可删除此 QSO';
	@override String get deletedQsoWarning => '已删除 QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => '再点按一次垃圾桶即可删除此${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => '再点击一次垃圾桶即可删除此${kind}';
	@override String deletedEventWarning({required Object kind}) => '已删除${kind}';
	@override String get timeControl => '时间';
	@override String get radioControl => '电台';
	@override String get powerControl => '功率';
	@override String get notesControl => '备注';
	@override String get power => '功率';
	@override String get powerUnit => 'W';
	@override String get controlSettings => '记录控件';
	@override String get spottingControl => 'Spot';
	@override String get spottingSelfControl => '自我 Spot';
	@override String spotSelfAt({required Object freq}) => '在 ${freq} 自我 Spot';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot ${call} 于 ${freq}';
	@override String spotTooLate({required Object call}) => 'Spot ${call} 为时已晚';
	@override String get spotNoFreq => '请先设置要 Spot 的频率';
	@override String get spotComment => '评论';
	@override String get bandOrFreqRequired => '记录前请设置频率或频段';
	@override String get missingBand => '无频段';
	@override String get missingMode => '无模式';
	@override String saveFailed({required Object error}) => '无法保存：${error}';
	@override String deleteFailed({required Object error}) => '无法删除：${error}';
	@override late final _Translations$loggingControls$info$zh info = _Translations$loggingControls$info$zh._(_root);
}

// Path: formChrome
class _Translations$formChrome$zh extends Translations$formChrome$en {
	_Translations$formChrome$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get untitled => '（无标题）';
	@override String get showMore => '显示更多';
	@override String get showAll => '显示全部';
	@override String get showFewer => '显示更少';
	@override String get defaults => '默认';
	@override String get search => '搜索';
	@override String get clear => '清除';
	@override String get openPage => '打开页面';
	@override String get connected => '已连接';
	@override String get notConnected => '未连接';
	@override String get manage => '管理';
	@override String get connect => '连接';
	@override String get formTitle => '表单';
	@override String addItem({required Object label}) => '添加${label}';
	@override String editItem({required Object label}) => '编辑${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => '显示 ${shown} / ${total}（已选 ${selected} 个）';
	@override String validationError({required Object error}) => '验证错误：${error}';
	@override String transformationError({required Object error}) => '转换错误：${error}';
	@override String actionError({required Object error}) => '错误：${error}';
	@override String get removeItem => '移除';
	@override String get storageUnavailable => '登录信息不可用';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$zh extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '编辑 QSO';
	@override String get operatorCall => '操作员';
	@override String get position => '操作位';
	@override String get theirName => '姓名';
	@override String get theirGrid => '网格';
	@override String get theirState => '州';
	@override String get band => '频段';
	@override String get notes => '备注';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => '对方信息';
	@override String get sectionOur => '我方信息';
	@override String get sectionNotes => '备注';
	@override String get theirCity => '城市';
	@override String get theirCounty => '县';
	@override String get theirEntity => '实体';
	@override String get theirCqZone => 'CQ 区';
	@override String get theirItuZone => 'ITU 区';
	@override String get theirArrlSection => 'ARRL 分部';
	@override String get theirLat => '纬度';
	@override String get theirLon => '经度';
	@override String get theirPower => '对方功率';
}

// Path: qsoList
class _Translations$qsoList$zh extends Translations$qsoList$en {
	_Translations$qsoList$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get empty => '还没有 QSO——去联络吧！';
	@override String get bandOrModeWarning => '请确认您的频段和模式正确';
	@override String get today => '今天';
	@override String get yesterday => '昨天';
	@override String get tomorrow => '明天';
}

// Path: loggingPanel
class _Translations$loggingPanel$zh extends Translations$loggingPanel$en {
	_Translations$loggingPanel$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get stats => '操作统计';
	@override String get scoring => '计分';
	@override String get dxccEntities => 'DXCC 实体';
	@override String get statesWorked => '州';
	@override String get provincesWorked => '省';
	@override String get duplicates => '重复';
}

// Path: callInfo
class _Translations$callInfo$zh extends Translations$callInfo$en {
	_Translations$callInfo$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => '显示图片';
	@override String get imageUnavailable => '照片不可用';
	@override String get photo => '照片';
	@override String get notes => '备注';
	@override String distanceTo({required Object distance}) => '相距 ${distance}，位于';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°），位于';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°），位于';
	@override String distanceAway({required Object distance}) => '相距 ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°）';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°）';
	@override String get thisOpCountOne => '本操作中有 1 个 QSO';
	@override String thisOpCountOther({required Object count}) => '本操作中有 ${count} 个 QSO';
	@override String get otherOpsCountOne => '其他操作中有 1 个 QSO';
	@override String otherOpsCountOther({required Object count}) => '其他操作中有 ${count} 个 QSO';
	@override String andMore({required Object count}) => '…还有 ${count} 条';
	@override String withCall({required Object call}) => '与 ${call}';
	@override String fromOperation({required Object where}) => '来自 ${where}';
	@override late final _Translations$callInfo$history$zh history = _Translations$callInfo$history$zh._(_root);
}

// Path: settings
class _Translations$settings$zh extends Translations$settings$en {
	_Translations$settings$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '设置';
	@override String get language => '语言';
	@override String languageSystem({required Object language}) => '跟随系统设置 (${language})';
	@override late final _Translations$settings$theme$zh theme = _Translations$settings$theme$zh._(_root);
	@override late final _Translations$settings$themeDescription$zh themeDescription = _Translations$settings$themeDescription$zh._(_root);
	@override String get fontScale => '字体缩放';
	@override late final _Translations$settings$fontScaleOpts$zh fontScaleOpts = _Translations$settings$fontScaleOpts$zh._(_root);
	@override late final _Translations$settings$keepDeviceAwake$zh keepDeviceAwake = _Translations$settings$keepDeviceAwake$zh._(_root);
	@override String get layoutDensity => '布局密度';
	@override late final _Translations$settings$layoutDensityOpts$zh layoutDensityOpts = _Translations$settings$layoutDensityOpts$zh._(_root);
	@override String layoutDensityClamped({required Object effective}) => '窗口太矮，正在使用${effective}';
	@override String get layoutDensityAtLimit => '已达极限';
	@override String get distanceUnits => '距离单位';
	@override late final _Translations$settings$distanceUnitsOpts$zh distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$zh._(_root);
	@override String get userInterface => '用户界面';
	@override late final _Translations$settings$logging$zh logging = _Translations$settings$logging$zh._(_root);
	@override late final _Translations$settings$catServer$zh catServer = _Translations$settings$catServer$zh._(_root);
	@override late final _Translations$settings$radio$zh radio = _Translations$settings$radio$zh._(_root);
	@override late final _Translations$settings$help$zh help = _Translations$settings$help$zh._(_root);
	@override late final _Translations$settings$exports$zh exports = _Translations$settings$exports$zh._(_root);
	@override late final _Translations$settings$map$zh map = _Translations$settings$map$zh._(_root);
	@override late final _Translations$settings$privacy$zh privacy = _Translations$settings$privacy$zh._(_root);
	@override String get operatorCall => '操作员呼号';
	@override late final _Translations$settings$sync$zh sync = _Translations$settings$sync$zh._(_root);
	@override late final _Translations$settings$peers$zh peers = _Translations$settings$peers$zh._(_root);
	@override String get developerMode => '开发者模式';
	@override late final _Translations$settings$syncPanel$zh syncPanel = _Translations$settings$syncPanel$zh._(_root);
	@override late final _Translations$settings$accounts$zh accounts = _Translations$settings$accounts$zh._(_root);
	@override late final _Translations$settings$station$zh station = _Translations$settings$station$zh._(_root);
	@override late final _Translations$settings$offlineData$zh offlineData = _Translations$settings$offlineData$zh._(_root);
	@override late final _Translations$settings$profiles$zh profiles = _Translations$settings$profiles$zh._(_root);
	@override late final _Translations$settings$search$zh search = _Translations$settings$search$zh._(_root);
	@override late final _Translations$settings$developer$zh developer = _Translations$settings$developer$zh._(_root);
	@override late final _Translations$settings$about$zh about = _Translations$settings$about$zh._(_root);
	@override late final _Translations$settings$panels$zh panels = _Translations$settings$panels$zh._(_root);
	@override String get showMoreSettings => '显示更多设置';
	@override String get numberFormat => '数字格式';
	@override late final _Translations$settings$numberFormatOpts$zh numberFormatOpts = _Translations$settings$numberFormatOpts$zh._(_root);
	@override late final _Translations$settings$numberFormatDescription$zh numberFormatDescription = _Translations$settings$numberFormatDescription$zh._(_root);
	@override late final _Translations$settings$numberFormatSeparators$zh numberFormatSeparators = _Translations$settings$numberFormatSeparators$zh._(_root);
	@override String get gridPrecision => '网格精度';
	@override late final _Translations$settings$gridPrecisionOpts$zh gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$zh._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$zh gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$zh._(_root);
}

// Path: commands
class _Translations$commands$zh extends Translations$commands$en {
	_Translations$commands$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => '请先在设置中启用同步。';
	@override String get fullResyncStarted => '已开始完全重新同步——本地数据已先行备份。';
	@override String noDataFilesMatched({required Object target}) => '没有与“${target}”匹配的数据文件。';
	@override String reloadFailed({required Object error}) => '重新加载失败：${error}';
	@override String get reloadingAll => '正在重新加载所有数据文件…';
	@override String reloadingTarget({required Object target}) => '正在重新加载 ${target} 数据文件…';
	@override String unknownExperiment({required Object token}) => '未知实验“${token}”';
	@override String experimentEnabled({required Object name}) => '已启用 ${name}';
	@override String experimentDisabled({required Object name}) => '已禁用 ${name}';
	@override String get sentryTestSent => '测试错误报告已发送到 Sentry';
	@override String get sentryTestLocalOnly => '此构建中已禁用 Sentry——测试错误仅在本地记录';
	@override String get noOperationOpen => '该命令需要打开一个操作';
	@override String unknownSegmentKind({required Object kind}) => '不知道如何标记“${kind}”';
	@override String get operationAlreadyStarted => '此操作已有开始标记';
	@override String get couldNotOpenLocation => '已添加休息，但无法打开位置界面';
	@override String get noTestOperations => '没有可清除的测试操作';
	@override String get purgeTestsUnavailable => 'PURGETESTS 需要显示确认对话框，但此处无法显示';
	@override String get syncAllUnavailable => 'SYNCALL 需要显示确认对话框，但此处无法显示';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已清除 ${count} 个测试操作',
		other: '已清除 ${count} 个测试操作',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '已清除 ${purged} / ${total} 个测试操作——其余失败；请再次运行 PURGETESTS';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已清除 ${count} 个不属于任何操作的测试通联',
		other: '已清除 ${count} 个不属于任何操作的测试通联',
	);
	@override String get purgeTestsContactsFailed => '已清除测试操作，但不属于任何操作的测试通联清除失败；请再次运行 PURGETESTS';
	@override String get purgeTestsNothingToDo => '未清除任何内容';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '已移除 ${removed} / ${total} 个测试操作——其余失败；请再次点击“查看”';
	@override String get receivedPurgesFailed => '无法移除这些测试操作——请再次点击“查看”';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个测试操作已在另一台设备上移除',
		other: '${count} 个测试操作已在另一台设备上移除',
	);
	@override String get receivedPurgesReview => '查看';
	@override String get settingOn => '开';
	@override String get settingOff => '关';
	@override String get settingEmpty => '（空）';
	@override String get settingSecretSet => '（已设置）';
	@override String get settingSecretUnset => '（未设置）';
	@override String settingSelectedCount({required Object count}) => '已选 ${count} 个';
	@override String get settingExpectsOnOff => 'on 或 off';
	@override String settingExpectsOneOf({required Object choices}) => '以下之一：${choices}';
	@override String get settingExpectsNumber => '一个数字';
	@override String settingVanished({required Object label}) => '“${label}”已不再可用';
	@override String get noCwKeyer => '没有已连接的电台能键控 CW';
	@override String get noKeyer => '没有已连接的电台能键控 CW 或播放语音存储';
	@override String get keyerNeedsOperation => '请打开一个操作以使用 CW 电键器';
	@override String get keyerExperimentOff => 'CW 键控已关闭——使用 EXP KEYER 开启';
	@override String get esmExperimentOff => '回车发送消息已关闭——使用 EXP ESM 开启';
	@override String cwSending({required Object text}) => '正在发送 CW：${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW 消息 F${n}：${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW 消息 F${n} 未发送：扩展尚未就绪';
	@override String settingNotStored({required Object label}) => '“${label}”不接受该值';
}

// Path: commandDialog
class _Translations$commandDialog$zh extends Translations$commandDialog$en {
	_Translations$commandDialog$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get hint => '搜索呼号或输入命令';
	@override String noResults({required Object text}) => '没有与“${text}”匹配的内容';
	@override String get sectionCommands => '命令';
	@override String get sectionGoTo => '转到';
	@override String get sectionOperations => '操作';
	@override String get goHome => '主页';
	@override String get goSettings => '设置';
	@override String get goNewOperation => '新操作';
	@override String runTyped({required Object text}) => '运行“${text}”';
	@override String get sectionSuggestions => '试试';
	@override String get lookingUp => '正在查询呼号…';
	@override String get blockedByPane => '面板或对话框打开时无法使用命令';
}

// Path: expiredBuild
class _Translations$expiredBuild$zh extends Translations$expiredBuild$en {
	_Translations$expiredBuild$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '此构建已过期';
	@override String get body => '请访问 ham2k.com 获取较新版本。';
	@override String get visit => '访问 ham2k.com';
	@override String get dismiss => '仍然继续';
}

// Path: staleness
class _Translations$staleness$zh extends Translations$staleness$en {
	_Translations$staleness$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => '有一个重要更新等待应用';
	@override String get codePushFloorBody => '此版本包含一项您尚未获得的修复。';
	@override String get restartToApply => '重启应用以应用。';
	@override String get quitAndReopen => '退出应用并重新打开以应用。';
	@override String get reopenToApply => '关闭应用并重新打开以应用。';
	@override String get ignoreForNow => '暂时忽略';
}

// Path: spotting
class _Translations$spotting$zh extends Translations$spotting$en {
	_Translations$spotting$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => '尚未记录可 Spot 的 QSO。';
	@override String get setFrequencyFirst => '请先设置频率。';
	@override String get nothingToSpot => '没有可 Spot 的内容——此处没有扩展提供 Spot 功能。';
	@override String spotFailed({required Object source, required Object message}) => '${source} 失败：${message}';
	@override String get unknownError => '未知错误';
	@override String get notSent => 'Spot 未发送。';
	@override String get notRefreshedOffline => '没有网络连接——信号未刷新';
}

// Path: dataFiles
class _Translations$dataFiles$zh extends Translations$dataFiles$en {
	_Translations$dataFiles$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get downloading => '下载中…';
	@override String downloadFailedTitle({required Object name}) => '无法下载 ${name}';
	@override String get downloadFailedWebHint => '这可能是网络问题，也可能是此链接的主机不支持从网页浏览器直接下载。请尝试桌面或移动应用，或换一个托管位置。';
	@override String get downloadTimedOut => '服务器响应时间过长。请稍后重试。';
	@override String downloadServerError({required Object host, required Object status}) => '${host} 返回了错误（HTTP ${status}）。请稍后重试。';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} 无法提供此文件（HTTP ${status}）。请检查其地址是否仍然正确。';
	@override String processingFailedTitle({required Object name}) => '无法处理 ${name}';
	@override String importTooSmall({required Object existing, required Object imported}) => '下载的数据只有此设备上 ${existing} 条记录中的 ${imported} 条，因此保留了缺少的记录。在 设置 › 离线数据 中刷新即可强制接受。';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已为 ${label} 导入 ${count} 条记录。',
		other: '已为 ${label} 导入 ${count} 条记录。',
	);
	@override String importedData({required Object label}) => '已为 ${label} 导入数据。';
	@override String get cleanedUpTitle => '已清理扩展数据';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已移除已禁用扩展的 ${count} 个数据文件的数据。',
		other: '已移除已禁用扩展的 ${count} 个数据文件的数据。',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} 条记录';
	@override String get definitionUnavailable => '文件来源未提供定义——其扩展可能正在重启或配置有误。请稍后重试。';
}

// Path: updates
class _Translations$updates$zh extends Translations$updates$en {
	_Translations$updates$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => '有可用更新';
	@override String newVersionAvailable({required Object version}) => '有新版本（${version}）可用。';
	@override String get getIt => '获取';
	@override String get ok => '确定';
	@override String get updateReady => '更新已就绪';
	@override String get restartToApply => '更新已下载。重启以应用。';
	@override String get appliesNextLaunch => '更新已下载。将在下次打开应用时生效。';
	@override String get restartNow => '立即重启';
	@override String get reloadToUpdate => '此页面有较新版本可用。重新加载即可获取。';
	@override String get reloadNow => '立即重新加载';
	@override String get checkForUpdates => '检查更新';
	@override String get checkingForUpdates => '检查更新中…';
	@override String get upToDate => '已是最新';
	@override String get automaticChecks => '自动检查';
	@override String get automaticChecksDescription => '从下次启动应用起，在后台查找新版本';
}

// Path: extensionService
class _Translations$extensionService$zh extends Translations$extensionService$en {
	_Translations$extensionService$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => '扩展运行时尚未就绪。';
	@override String testFailed({required Object error}) => '测试失败：${error}';
	@override String connectedAs({required Object identity}) => '已连接为 ${identity}';
	@override String get invalidFieldConfiguration => '字段配置无效';
	@override String get invalidValue => '无效值';
	@override String validationError({required Object error}) => '验证错误：${error}';
	@override String actionFailed({required Object error}) => '操作失败：${error}';
	@override String get commandFailed => '命令运行失败';
	@override String get reportUnavailable => '目前无法发送报告';
	@override String get stashUnavailable => '目前无法访问 Ham2K File Stash';
	@override String timersSuspendedBudget({required Object name}) => '${name} 在计时器中花费了太多时间。在扩展重启之前，其计时器已停止。';
	@override String timersSuspendedFailures({required Object name}) => '${name} 的计时器反复失败。在扩展重启之前，其计时器已停止。';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} 卡在了一个计时器中。在扩展重启之前，其计时器已停止。';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$zh extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '操作位置';
	@override String get selectedLocation => '所选位置';
	@override String get gridSquare => '梅登海德网格位置指示器';
	@override String get gridInvalid => '需要 4、6、8 或 10 个字符，如 FN31pr';
	@override String get suggestedLocations => '建议位置';
	@override String get deviceGps => '设备 GPS';
	@override String peerGps({required Object device}) => '来自 ${device} 的 GPS';
	@override String get locating => '定位中…';
	@override String get gpsUnavailable => '位置不可用';
	@override String get permissionDenied => '位置权限被拒绝';
	@override String get permissionBlocked => '位置权限被阻止';
	@override String get moreDetails => '更多详情';
	@override String get stateOrProvince => '州或省（可选）';
	@override String get controlsUnavailableTitle => '活动控件不可用';
	@override String get controlsUnavailableReason => '这些参考仍可使用；只是无法访问其活动。';
	@override String get controlsUnavailableRetry => '重试';
	@override String get county => '县（可选）';
}

// Path: versionLabel
class _Translations$versionLabel$zh extends Translations$versionLabel$en {
	_Translations$versionLabel$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => '版本 ${version}';
	@override String patch({required Object patch}) => '补丁 ${patch}';
	@override String build({required Object build}) => '构建 ${build}';
}

// Path: notices
class _Translations$notices$zh extends Translations$notices$en {
	_Translations$notices$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => '暂无通知';
	@override String get webStorageInMemory => '此浏览器无法提供持久存储——日志仅保存在内存中，关闭此标签页时将会丢失。请使用最新版的 Chrome、Firefox、Safari 或 Edge。';
	@override String get webStorageUnreliable => '此浏览器正在使用后备存储，在多个标签页下并不安全——请只保持一个标签页打开，并保持同步开启。';
	@override String get logFromNewerBuildTitle => '此日志需要较新的版本';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => '您的日志由较新版本的 HaLo 写入（存储版本 ${storage}；此版本只能识别 ${understood}），因此无法打开，新的通联也不会被保存。请重新安装较新的版本——或者，如果您确实想运行此构建，请将其指向另一个数据文件夹。日志位于 ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => '您的日志由较新版本的 HaLo 写入（存储版本 ${storage}；此版本只能识别 ${understood}），因此无法打开，新的通联也不会被保存。请改用那个较新的版本打开此日志。';
	@override String get preferencesRestoredTitle => '已从备份恢复设置';
	@override String get preferencesRestored => '无法读取设置文件，因此 HaLo 恢复了它最近一份完好的副本。您在上一次会话中更改的内容可能需要重新设置。无法读取的文件保存在旁边，名为 shared_preferences.corrupt-….json。';
	@override String get preferencesResetTitle => '设置已重置';
	@override String get preferencesReset => '无法读取设置文件，且没有可用的备份，因此 HaLo 以默认设置启动。无法读取的文件保存在应用的数据文件夹中，名为 shared_preferences.corrupt-….json。';
	@override String autoConnectHeldTitle({required Object name}) => '未自动连接 ${name}';
	@override String autoConnectHeld({required Object name}) => 'HaLo 上次开始连接 ${name} 时停止了响应，因此这次没有连接它，以免再次出现问题。请检查电台是否已开机、线缆是否已插好，然后在设置中对其按“连接”。';
}

// Path: syncAccount
class _Translations$syncAccount$zh extends Translations$syncAccount$en {
	_Translations$syncAccount$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => '匿名账户 (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email}（待确认）';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email}（待确认 - #${id}）';
}

// Path: deepLink
class _Translations$deepLink$zh extends Translations$deepLink$en {
	_Translations$deepLink$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => '请先开始一个操作，然后重新发送该通联';
	@override String get waitingInOperation => '该通联正在此界面后面的操作中等待';
	@override String unknownActivities({required Object refs}) => '此设备没有对应 ${refs} 的活动，因此未添加这些参考';
	@override String activitiesUnavailable({required Object refs}) => '无法访问您的活动，因此未添加 ${refs}——请重试该链接';
}

// Path: confirmDevice
class _Translations$confirmDevice$zh extends Translations$confirmDevice$en {
	_Translations$confirmDevice$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '确认设备';
	@override String get codePrompt => '输入想要加入此账户的设备上显示的代码。';
	@override String get code => '代码';
	@override String get lookUp => '查找';
	@override String get codeNotFound => '没有与该代码匹配的请求。代码在 10 分钟后过期——请让另一台设备生成新的代码。';
	@override String get linkExpired => '该链接已过期。请让另一台设备显示新的二维码。';
	@override String areYouSure({required Object device}) => '将 ${device} 链接到此账户？';
	@override String get unnamedDevice => '一台未命名的设备';
	@override String get grantWarning => '它将能够读取和更改此账户中的每个操作和 QSO。';
	@override String get needsSyncTitle => '此设备尚未同步';
	@override String get needsSyncText => '请先开启 Ham2K Log Filer 同步并将此设备链接到账户，然后才能接纳其他设备。';
	@override String get malformedRequest => '同步服务器发送了此应用无法读取的请求。请让另一台设备重试。';
	@override String get linkIt => '链接设备';
}

// Path: switchAccounts
class _Translations$switchAccounts$zh extends Translations$switchAccounts$en {
	_Translations$switchAccounts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => '尚无账户详情';
	@override String get currentAccount => '当前账户';
	@override String get otherAccounts => '其他账户';
	@override String get linkToAnother => '链接到其他账户';
	@override String get linkWithSibling => '与其他 Ham2K 应用链接';
	@override String get linkWithPolo => '与旧版中的账户链接';
	@override String get linkWithSiblingDescription => '您安装了另一个 Ham2K 应用。与该应用使用的账户链接。';
	@override String siblingPrompt({required Object app}) => '请在 ${app} 中批准请求，然后返回这里。';
	@override String openSiblingAgain({required Object app}) => '再次打开 ${app}';
	@override String get siblingNoGrant => '没有成功？请再次打开它，或返回并用其他方式链接。';
	@override String siblingOpenFailed({required Object app}) => '无法打开 ${app}。';
	@override String siblingLinkRenewed({required Object app}) => '链接已过期，新的链接已准备好——请再次打开 ${app}。';
	@override String get tryAgain => '重试';
	@override String get linkWithQr => '用二维码链接';
	@override String get linkWithQrDescription => '从已在使用该账户的设备上扫描';
	@override String get linkWithEmail => '用电子邮件地址链接';
	@override String get linkWithEmailDescription => '通过代码或电子邮件链接确认';
	@override String get enterEmailPrompt => '输入您希望此设备使用的账户的电子邮件地址。';
	@override String get emailAddress => '电子邮件地址';
	@override String get linkAccount => '链接账户';
	@override String get copiedCode => '已将代码复制到剪贴板';
	@override String get copyCode => '复制代码';
	@override String codePrompt({required Object email}) => '在已与 ${email} 链接的设备上打开 Ham2K 应用，并输入此代码以批准请求：';
	@override String get waitingForConfirmation => '等待确认…';
	@override String get sendEmailInstead => '改为发送确认邮件';
	@override String emailSent({required Object email}) => '已向 ${email} 发送电子邮件。请打开邮件并确认请求，以链接此设备。';
	@override String get resendEmail => '重新发送邮件';
	@override String get qrPrompt => '从已链接到目标账户的设备上扫描此二维码——例如用您手机上的 Ham2K Portable Logger。';
	@override String get serverUnreachable => '无法连接同步服务器。请稍后重试。';
	@override String get emailRequired => '请输入要链接的电子邮件地址。';
	@override String noAccountForEmail({required Object email}) => '未找到 ${email} 的账户。';
	@override String serverRejected({required Object error}) => '同步服务器拒绝了请求：${error}';
	@override String get noLinkCode => '同步服务器没有返回链接代码。请稍后重试。';
	@override String get noConfirmationCode => '同步服务器没有发送确认代码。请稍后重试。';
	@override String get switchNotAccepted => '该账户不接受切换。请改用电子邮件地址链接。';
	@override String get requestFailed => '与同步服务器通信时出了问题。请稍后重试。';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个 QSO',
		other: '${count} 个 QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个操作',
		other: '${count} 个操作',
	);
}

// Path: adifImport
class _Translations$adifImport$zh extends Translations$adifImport$en {
	_Translations$adifImport$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '从 ADIF 导入 QSO';
	@override String reading({required Object filename}) => '正在读取 ${filename}…';
	@override String get dropHint => '拖放 ADIF 文件以导入';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '此文件中有 ${count} 个 QSO',
		other: '此文件中有 ${formatted} 个 QSO',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个已在您的日志中',
		other: '${formatted} 个已在您的日志中',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '将导入 ${count} 个',
		other: '将导入 ${formatted} 个',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个新通联',
		other: '${formatted} 个新通联',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个将与现有通联合并',
		other: '${formatted} 个将与现有通联合并',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个无法导入（没有呼号）',
		other: '${formatted} 个无法导入（没有呼号）',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个需要仔细检查',
		other: '${formatted} 个需要仔细检查',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个通联的参考无法恢复',
		other: '${formatted} 个通联的参考无法恢复',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个通联的 ${programs} 参考可能不完整',
		other: '${formatted} 个通联的 ${programs} 参考可能不完整',
	);
	@override String get stackingTypesUnknown => '合并的通联可能会丢失一个参考——活动无法说明哪些类型可以叠加。取消并重试可避免此问题。';
	@override String get nothingToImport => '此文件中没有可导入的内容';
	@override String get confirm => '导入';
	@override String importing({required Object filename}) => '正在导入 ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已从 ${filename} 导入 ${count} 个通联',
		other: '已从 ${filename} 导入 ${formatted} 个通联',
	);
	@override String failed({required Object filename, required Object error}) => '无法导入 ${filename}：${error}';
	@override String notAdif({required Object filename}) => '${filename} 看起来不是 ADIF 文件';
	@override String stationWarning({required Object calls, required Object station}) => '警告：此 ADIF 包含来自 ${calls} 的 QSO，但如果继续，它们将作为 ${station} 导入。';
	@override String get stationCallJoin => ' 和 ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个没有日期，无法导入',
		other: '${formatted} 个没有日期，无法导入',
	);
	@override String activationFound({required Object refs}) => '此文件记录了 ${refs} 的一次激活。';
	@override String get addActivation => '将其添加到此操作';
	@override String shortfall({required Object written, required Object planned}) => '只有 ${written} / ${planned} 个得以应用——在您决定期间日志发生了变化。';
	@override String get busy => '已有导入正在进行。请等待其完成后再开始新的导入。';
	@override String get oneFileOnly => '一次只能拖放一个 ADIF 文件——文件的导入顺序决定了哪些数据优先。';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} 中的 QSO 超过 ${limit} 个，这是一个操作一次能导入的上限。';
}

// Path: offline
class _Translations$offline$zh extends Translations$offline$en {
	_Translations$offline$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => '互联网：离线';
	@override String get statusOnline => '互联网：已连接';
	@override String get noRoute => '完全没有网络连接。';
	@override String get unreachable => '网络已连接，但没有服务器响应——通常是浏览器中有登录页面在等待。';
	@override String get reachable => '所有服务均正常响应。';
	@override String get whatStops => '查询、信号和数据文件已暂停。记录和附近设备同步不受影响。';
	@override String get servicesTitle => '服务';
	@override String get noServices => '还没有服务报告状态。';
	@override String lastSuccess({required Object when}) => '上次响应于 ${when} 前';
	@override String get neverSucceeded => '尚未响应';
	@override String nextAttempt({required Object when}) => '${when} 后再次尝试';
	@override String get nextAttemptNow => '即将再次尝试';
	@override String get retry => '立即重试';
	@override String get retrying => '尝试中…';
	@override String get retryReached => '已恢复在线。';
	@override String get retryUnreachable => '仍然没有响应。';
	@override String get retryNotAttempted => '目前没有需要发送的内容。';
	@override String get retryThrottled => '刚刚尝试过——请稍等片刻。';
	@override String get retryDisabled => '同步已关闭，因此没有可用于探测的服务。';
	@override String get syncService => 'Ham2K LoFi 同步';
	@override String get retryInFlight => '正在尝试——请稍候。';
}

// Path: exportSettings
class _Translations$exportSettings$zh extends Translations$exportSettings$en {
	_Translations$exportSettings$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => '所有导出的基本设置，参考活动和其他活动分别使用各自的文件名和标题模板。每种导出类型都可以提供自己的默认设置或自定义设置。';
	@override String get referenceActivities => '参考活动';
	@override String get otherActivities => '其他活动';
	@override String get adifFields => 'ADIF 字段';
	@override String get loadFailed => '无法加载导出设置。';
	@override String get retry => '重试';
	@override String get compactFileNamesDescriptionOn => '简易文件名，如 N0CALL@US-1234-20260715.adi。';
	@override String get compactFileNamesDescriptionOff => '描述性文件名，如 2026-07-15 N0CALL at US-1234.adi。';
	@override String get includePrivateDataDescriptionOn => '在 ADIF 文件中包含姓名、地址、电子邮件、备注和精确位置。';
	@override String get includePrivateDataDescriptionOff => '省略姓名、地址、电子邮件和备注；位置仅精确到 6 位网格。';
	@override String get includeLookupDataDescriptionOn => '包含来自呼号查询服务的信息。';
	@override String get includeLookupDataDescriptionOff => '省略来自呼号查询服务的信息；保留手动输入的值。';
	@override String get customTemplatesDescriptionOn => '您的自定义模板已启用，可在下方编辑。';
	@override String get customTemplatesDescriptionOff => '默认模板已启用。您的自定义模板将保留以备后用。';
	@override String get type => '导出类型';
	@override String get defaults => '默认';
	@override String get includeLookupData => '包含查询数据';
	@override String get customTemplates => '自定义模板';
	@override String get filenameTemplate => '文件名模板';
	@override String get compactFilenameTemplate => '简易文件名模板';
	@override String get titleTemplate => '标题模板';
	@override String get adifNotesTemplate => 'ADIF QSO 备注';
	@override String get adifCommentTemplate => 'ADIF QSO 评论';
	@override String get adifQslMessageTemplate => 'ADIF QSL 消息';
	@override String get shared => '设置适用于使用此导出类型的所有扩展。';
	@override String get defaultTemplates => '开启“自定义模板”即可编辑此类型的模板。';
}

// Path: templateEditor
class _Translations$templateEditor$zh extends Translations$templateEditor$en {
	_Translations$templateEditor$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => '预览：';
	@override String get reset => '重置';
	@override String get docs => '模板文档';
	@override String get preview => '示例预览';
	@override String get reference => '模板参考';
	@override String get attributes => '可用属性';
	@override String get filters => '过滤器';
	@override String get flowControl => '流程控制';
	@override String get unavailable => '扩展就绪之前无法预览。';
	@override String get empty => '（输出为空）';
}

// Path: home.nav
class _Translations$home$nav$zh extends Translations$home$nav$en {
	_Translations$home$nav$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get operations => '操作';
	@override String get chase => '追逐';
	@override String get logs => '日志';
	@override String get maps => '地图';
	@override String get settings => '设置';
}

// Path: home.panels
class _Translations$home$panels$zh extends Translations$home$panels$en {
	_Translations$home$panels$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get operations => '操作列表';
	@override String get operationsDescription => '您的操作，最新的在前。';
	@override String get version => '当前版本';
	@override String get versionDescription => 'Ham2K 标志、本应用名称以及您正在运行的构建。';
}

// Path: home.logs
class _Translations$home$logs$zh extends Translations$home$logs$en {
	_Translations$home$logs$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '日志';
	@override String get titleFor => '日志：';
	@override String get emptyCallsigns => '尚未记录 QSO';
	@override String emptyQsos({required Object call}) => '没有 ${call} 的 QSO';
	@override String get mapNoSelection => '选择一个 QSO 以在地图上查看';
	@override String get searchHint => '搜索呼号或姓名';
	@override String get noSearchMatches => '没有与搜索匹配的 QSO';
	@override String get titleAll => '所有日志';
	@override String get allCallsigns => '所有呼号';
	@override String get noOperation => '不属于任何操作';
	@override String get unsavedTitle => '未保存的更改';
	@override String get unsavedBody => '此 QSO 有未保存的更改。';
	@override String get pendingDeleteBody => '此 QSO 已标记为删除。';
	@override String get editGone => '未保存：该 QSO 已不在此日志中。';
	@override String get discard => '放弃';
	@override late final _Translations$home$logs$columns$zh columns = _Translations$home$logs$columns$zh._(_root);
	@override late final _Translations$home$logs$panels$zh panels = _Translations$home$logs$panels$zh._(_root);
	@override late final _Translations$home$logs$import$zh import = _Translations$home$logs$import$zh._(_root);
}

// Path: chase.station
class _Translations$chase$station$zh extends Translations$chase$station$en {
	_Translations$chase$station$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '追逐电台';
	@override String get stationLabel => '电台：';
	@override String get operatorLabel => '操作员：';
	@override String get noLocation => '无位置';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$zh extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get today => '今天';
	@override String get thisWeek => '本周';
	@override String get last14Days => '过去 14 天';
	@override String get thisMonth => '本月';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$zh extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get today => '今日统计';
	@override String get thisWeek => '本周统计';
	@override String get last14Days => '过去 14 天统计';
	@override String get thisMonth => '本月统计';
}

// Path: chase.period
class _Translations$chase$period$zh extends Translations$chase$period$en {
	_Translations$chase$period$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get today => '今天';
	@override String get thisWeek => '本周';
	@override String get last14Days => '过去 14 天';
	@override String get thisMonth => '本月';
}

// Path: chase.goals
class _Translations$chase$goals$zh extends Translations$chase$goals$en {
	_Translations$chase$goals$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '追逐目标';
	@override String remove({required Object name}) => '停止追逐 ${name}';
	@override String get extensionsTitle => '包含追逐功能的扩展';
}

// Path: chase.panels
class _Translations$chase$panels$zh extends Translations$chase$panels$en {
	_Translations$chase$panels$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => '记录控件，下方是该时段内追逐到的 QSO。';
	@override String get info => '信息';
	@override String get infoDescription => '正在记录的呼号，或该时段的统计。';
	@override String get spots => '信号';
	@override String get spotsDescription => '空中被 Spot 的电台，随时可以追逐。';
	@override String get map => '地图';
	@override String get mapDescription => '该时段的 QSO 以及正在记录的电台。';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$zh extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => '无效的呼号：${call}';
	@override String invalidCallsigns({required Object calls}) => '无效的呼号：${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '目前操作员为 ${previous}。新的通联将记录 ${typed}。';
	@override String operatorNoneSoFar({required Object typed}) => '目前没有记录操作员。新的通联将记录 ${typed}。';
	@override String operatorSeveral({required Object calls, required Object typed}) => '此操作已有 ${calls} 的通联。${typed} 只会记录到新的通联中。';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '同时将 ${typed} 记录为已记录通联的操作员',
		other: '同时将 ${typed} 记录为全部 ${count} 个已记录通联的操作员',
	);
	@override String get operatorSeveralStations => '在空中使用多个电台呼号时，不支持分别设置操作员';
	@override String get contactsUnreadable => '无法读取此操作的通联，因此在此更改呼号时不会提供更新它们的选项';
	@override String restampFailed({required Object error}) => '无法更新已记录的通联，因此未做任何更改：${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '已更新 ${written} / ${planned} 个通联——其余的已不在此操作中';
}

// Path: operation.tabs
class _Translations$operation$tabs$zh extends Translations$operation$tabs$en {
	_Translations$operation$tabs$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} 个 QSO';
	@override String get info => '信息';
	@override String get spots => '信号';
	@override String get map => '地图';
	@override String get qsosPlain => 'QSO';
	@override String get clock => '时钟';
	@override String get weather => '天气';
	@override String get website => '网站';
	@override String get remoteScreen => '远程屏幕';
	@override String get solar => '太阳';
	@override String get radio => '电台';
}

// Path: operation.positions
class _Translations$operation$positions$zh extends Translations$operation$positions$en {
	_Translations$operation$positions$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => '还没有其他操作位共享此操作。';
	@override String positionLabel({required Object number}) => '位：${number}';
	@override String operatorLabel({required Object call}) => '操作员：${call}';
	@override String get unnamedPosition => '另一个操作位';
	@override String get thisDevice => '我们的操作位';
	@override String get nameIn => '，位于 ';
	@override String get panelTitle => '操作位';
	@override String get panelDescription => '共享此操作的每个操作位当前正在记录的内容。';
}

// Path: operation.menu
class _Translations$operation$menu$zh extends Translations$operation$menu$en {
	_Translations$operation$menu$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => '显示 RST 字段';
	@override String get showStateField => '显示州字段';
	@override String get showGridField => '显示网格字段';
	@override String get showDeletedQsos => '显示已删除的 QSO';
	@override String get showDeletedOps => '显示已删除的操作';
	@override String get showQsoNumbers => '显示 QSO 编号';
	@override String get lookupAllQsos => '查询所有 QSO';
	@override String get loggingSettingsTitle => '记录设置';
	@override String get mapSettingsTitle => '地图设置';
	@override String get actionsSection => '操作';
}

// Path: operation.layout
class _Translations$operation$layout$zh extends Translations$operation$layout$en {
	_Translations$operation$layout$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '添加面板';
	@override String get availableSection => '可用面板';
	@override String panelSettings({required Object panel}) => '${panel} 设置';
	@override String get panelSettingsAction => '面板设置';
	@override String get viewName => '操作视图';
	@override String get viewOptions => '视图布局选项';
	@override String get viewTitleBuiltIn => '此视图为应用内置，其名称也是';
	@override String get resetOptions => '恢复默认';
	@override String get removePane => '移除';
	@override String resetPaneConfirm({required Object panel}) => '将 ${panel} 恢复为默认值？';
	@override String get resetPaneConfirmBody => '其标题、标题栏和大小将恢复默认，布局的其余部分保持不变。';
	@override String get resetViewConfirm => '将此视图恢复为默认布局？';
	@override String get resetViewConfirmBody => '面板将恢复默认排列，视图和每个面板的选项也将恢复默认。';
	@override String paneOptionsTitle({required Object panel}) => '${panel} 布局设置';
	@override String get paneTitle => '标题';
	@override String get paneShowHeader => '显示标题栏';
	@override String get paneShowHeaderTabset => '此窗格与其他窗格成组时始终显示——需通过标题栏切换到其他窗格';
	@override String get paneInherit => '与应用相同';
	@override String get searchHint => '搜索面板';
	@override String get noPanelsMatch => '没有与搜索匹配的面板。';
	@override String get nothingToAdd => '此视图已包含所有可用面板';
	@override String addPanel({required Object panel}) => '添加 ${panel}';
	@override String showPreview({required Object panel}) => '预览 ${panel}';
	@override String missingExtension({required Object name}) => '缺少扩展“${name}”';
	@override String get previewUnavailable => '无法显示此面板的预览图。';
	@override String get nestedPaneTitle => '更多';
	@override String get editLayout => '编辑布局';
	@override String get saveLayout => '保存布局';
	@override String get revertLayout => '放弃布局更改';
	@override String get done => '完成';
	@override String get layoutUnreadableTitle => '无法读取布局';
	@override String get layoutUnreadableBody => '无法读取您保存的布局，因此显示默认排列。在您选择保留之前，它不会覆盖您原来的布局。';
	@override String get layoutUnreadableAction => '使用此布局';
	@override String panelRenderFailed({required Object panel}) => '无法显示 ${panel}';
	@override String get panelRenderRetry => '重试';
	@override String get panelActionFailed => '该面板操作失败，请重试。';
	@override late final _Translations$operation$layout$panels$zh panels = _Translations$operation$layout$panels$zh._(_root);
	@override String get htmlPanelUnsupported => '此面板需要网页视图，但此平台不提供';
	@override String get htmlPanelUnsupportedOnWeb => '此面板需要沙盒，但网页版无法提供';
}

// Path: operation.export
class _Translations$operation$export$zh extends Translations$operation$export$en {
	_Translations$operation$export$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '操作导出';
	@override String get syncedOperation => '操作已同步';
	@override String get unsyncedOperation => '操作有未同步的更改';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '本操作中有 ${count} 个 QSO',
		other: '本操作中有 ${count} 个 QSO',
	);
	@override String qsosSynced({required Object total}) => '全部 ${total} 个 QSO 已同步';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} / ${total} 个 QSO 待同步';
	@override String eventsSynced({required Object total}) => '${total} 个事件标记已同步';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} / ${total} 个事件标记待同步';
	@override String get loading => '正在加载导出选项…';
	@override String get noOptions => '没有可用的导出格式（扩展运行时仍在启动？）';
	@override String get nothingLogged => '暂无可导出的内容——此操作没有 QSO。';
	@override String get share => '分享';
	@override String get nothingSelected => '未选择任何内容';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '保存 ${count} 个文件',
		other: '保存 ${count} 个文件',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '分享 ${count} 个文件',
		other: '分享 ${count} 个文件',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '导出 ${count} 个文件',
		other: '导出 ${count} 个文件',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '下载 ${count} 个文件',
		other: '下载 ${count} 个文件',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '保存合并的 ${count} 个文件',
		other: '保存合并的 ${count} 个文件',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '分享合并的 ${count} 个文件',
		other: '分享合并的 ${count} 个文件',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '导出合并的 ${count} 个文件',
		other: '导出合并的 ${count} 个文件',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '下载合并的 ${count} 个文件',
		other: '下载合并的 ${count} 个文件',
	);
	@override String saveOne({required Object name}) => '保存 ${name}';
	@override String shareOne({required Object name}) => '分享 ${name}';
	@override String exportOne({required Object name}) => '导出 ${name}';
	@override String downloadOne({required Object name}) => '下载 ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '暂存 ${count} 个文件',
		other: '暂存 ${count} 个文件',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '暂存合并的 ${count} 个文件',
		other: '暂存合并的 ${count} 个文件',
	);
	@override String get settingsButton => '导出设置';
	@override String get settingsTitle => '导出设置';
	@override late final _Translations$operation$export$compactFileNames$zh compactFileNames = _Translations$operation$export$compactFileNames$zh._(_root);
	@override late final _Translations$operation$export$includePrivateData$zh includePrivateData = _Translations$operation$export$includePrivateData$zh._(_root);
	@override String get resultTitle => '导出完成';
	@override String get resultFailedTitle => '导出失败';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已将 ${count} 个文件导出到 ${path}',
		other: '已将 ${count} 个文件导出到 ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已导出 ${count} 个文件：${path}',
		other: '已导出 ${count} 个文件：${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已分享 ${count} 个文件',
		other: '已分享 ${count} 个文件',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已下载 ${count} 个文件',
		other: '已下载 ${count} 个文件',
	);
	@override String exportFailed({required Object error}) => '导出失败：${error}';
	@override late final _Translations$operation$export$stash$zh stash = _Translations$operation$export$stash$zh._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$zh extends Translations$operation$spots$en {
	_Translations$operation$spots$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get empty => '没有符合筛选条件的信号';
	@override String error({required Object error}) => '加载信号失败：${error}';
	@override String get unknownBand => '其他';
	@override String get auto => '自动';
	@override String autoValue({required Object value}) => '自动（当前 ${value}）';
	@override String valueAuto({required Object value}) => '${value}（自动）';
	@override String get any => '任意';
	@override String get allBands => '所有频段';
	@override String get allModes => '所有模式';
	@override String get phoneAndCw => '话音和 CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个信号',
		other: '${count} 个信号',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => '显示 ${count} / ${total} 个信号';
	@override String ageMinutes({required Object minutes}) => '${minutes} 分钟';
	@override String get callsOfNote => '注意的呼号';
	@override String get yourSpots => '您的信号';
	@override String get allSpots => '所有信号';
	@override late final _Translations$operation$spots$continents$zh continents = _Translations$operation$spots$continents$zh._(_root);
	@override late final _Translations$operation$spots$filters$zh filters = _Translations$operation$spots$filters$zh._(_root);
	@override String get unavailableTitle => '信号不可用';
	@override String unavailableText({required Object sources}) => '${sources} 没有响应。';
	@override String get failedTitle => '信号来源错误';
	@override String failedText({required Object sources}) => '${sources} 返回了错误。';
	@override String get slideLogIt => '记录';
	@override String get slideIgnore => '忽略';
	@override String get slideRestore => '恢复';
	@override late final _Translations$operation$spots$logConflict$zh logConflict = _Translations$operation$spots$logConflict$zh._(_root);
}

// Path: operation.import
class _Translations$operation$import$zh extends Translations$operation$import$en {
	_Translations$operation$import$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '将数据导入操作';
	@override String get importAdifAction => '从 ADIF 导入 QSO';
	@override String get settingsButton => '监听设置';
	@override String get settingsTitle => '监听其他应用';
	@override String get protocolAddressLabel => '地址';
	@override String get protocolPortLabel => '端口';
	@override String get protocolPortInvalid => '请输入 1 到 65535 之间的端口';
	@override String get protocolAddressInvalid => '请输入有效的 IP 地址（如 127.0.0.1 或 239.239.0.2）';
	@override String get protocolStatusReceiving => '正在接收数据';
	@override String get protocolStatusNoData => '最近没有收到数据';
	@override String protocolBindError({required Object error}) => '无法开始监听：${error}';
	@override String captureFailed({required Object error}) => '传入的 QSO 无法保存，正在重试：${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => '任意（广播）';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Broadcast Data 选项卡 → 勾选通联信息的 "Enable Broadcasts"。如在同一台计算机上运行，将 IP 地址设为 127.0.0.1；如要在当前本地网络上广播，设为 255.255.255.255。';
	@override String get helpWsjtxSetup => 'File → Settings → Reporting 选项卡 → UDP Server 部分 → 勾选 "Accept UDP requests"。如在同一台计算机上运行，将 UDP Server 设为 127.0.0.1，或设为组播地址（如 239.239.0.2），并在本应用上方的配置中使用相同地址。';
	@override String get listenTitle => '监听来自其他应用的 QSO';
	@override String get listenDescriptionOnN1mm => '正在监听 N1MM+';
	@override String get listenDescriptionOnWsjtx => '正在监听 WSJT-X';
	@override String get listenDescriptionOnBoth => '正在监听 N1MM+ 和 WSJT-X';
	@override String get listenDescriptionOff => '关闭';
	@override String get addToOperationTitle => '添加到此操作';
	@override String get addToOperationDescriptionOn => '捕获的 QSO 到达时即添加到此操作';
	@override String get addToOperationDescriptionOff => '捕获的 QSO 将保留，直到您开启此项';
	@override String get pendingSectionTitle => '已捕获的 QSO';
	@override String get pendingEmpty => '尚未捕获任何内容';
	@override String stationMismatch({required Object call}) => '记录为 ${call}，而不是此操作的电台';
	@override String get discardAction => '放弃';
	@override String get gapDialogTitle => '包含更早的捕获？';
	@override String gapDialogBody({required Object count}) => '在数据中断之前还捕获了 ${count} 个 QSO。也包含它们吗？';
	@override String get gapDialogRecentOnly => '仅最近的';
	@override String gapDialogIncludeAll({required Object count}) => '全部包含 ${count} 个';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$zh extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get link => '有问题？';
	@override String get title => '报告轮廓问题';
	@override String get reference => '哪个轮廓';
	@override String get severity => '问题有多严重？';
	@override String get minor => '小瑕疵';
	@override String get major => '严重问题';
	@override String get explanation => '有什么问题？';
	@override String get explanationHint => '轮廓哪里有误，在什么位置';
	@override String get send => '发送';
	@override String get sending => '正在发送您的报告——谢谢';
	@override String get copy => '复制报告';
	@override String get notSent => '无法发送报告';
	@override String get copied => '报告已复制';
	@override String get notCopied => '无法复制报告';
}

// Path: map.postcard
class _Translations$map$postcard$zh extends Translations$map$postcard$en {
	_Translations$map$postcard$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get button => '操作明信片';
	@override String title({required Object title}) => '${title} 的明信片';
	@override String get portrait => '纵向';
	@override String get landscape => '横向';
	@override String get square => '方形';
	@override String get save => '保存…';
	@override String get download => '下载';
	@override String get share => '分享';
	@override String get copy => '复制';
	@override String get copied => '已复制到剪贴板';
	@override String saved({required Object path}) => '已保存到 ${path}';
	@override String downloaded({required Object name}) => '已下载 ${name}';
	@override String savedMany({required Object count, required Object path}) => '已将 ${count} 张图片保存到 ${path}';
	@override String savedFiles({required Object names}) => '已保存 ${names}';
	@override String savePartial({required Object error, required Object names}) => '${error}——${names} 已经保存';
	@override String downloadedMany({required Object count}) => '正在下载 ${count} 张图片——如浏览器询问，请允许';
	@override String get mapLeftOut => '地图未加载，因此已省略';
	@override String withMapLeftOut({required Object outcome}) => '${outcome}——地图未加载，因此已省略';
	@override String continued({required Object title}) => '${title}（续）';
	@override String get previousPage => '上一页';
	@override String get nextPage => '下一页';
	@override String pageOf({required Object page, required Object count}) => '第 ${page} / ${count} 页';
	@override String get sectionDays => '每天';
	@override String get reset => '重置';
	@override String failed({required Object error}) => '无法制作明信片：${error}';
	@override String get mapNotReady => '地图未加载完成。请检查网络连接后重试。';
	@override String saveFailed({required Object error}) => '无法保存明信片：${error}';
	@override String get copyFailed => '剪贴板未接收图片，请重试。';
	@override String get shareFailed => '无法分享明信片，请重试。';
	@override String get fileName => 'postcard';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$zh extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get noQsos => '尚未有 QSO… 让我们开始上线吧！';
	@override String get qsoCountOne => '1 个 QSO';
	@override String qsoCountOther({required Object count}) => '${count} 个 QSO';
	@override String qsosInTime({required Object time, required Object count}) => '${time} 内 ${count} 个';
	@override String sinceLast({required Object time}) => '距离上次 ${time}';
	@override String ratePer10({required Object rate}) => '最近 10 个：${rate} Q/h';
	@override String ratePer100({required Object rate}) => '最近 100 个：${rate} Q/h';
	@override String distanceTo({required Object distance}) => '相距 ${distance}，位于';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°），位于';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°），位于';
	@override String distanceAway({required Object distance}) => '相距 ${distance}';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°）';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°）';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}：${notice}';
	@override String get noticeDupe => '重复！';
	@override String get noticeNewBand => '新频段';
	@override String get noticeNewMode => '新模式';
	@override String get noticeNewDXCC => '新 DXCC';
	@override String get noticeNewState => '新州';
	@override String get noticeNewProvince => '新省';
	@override String get noticeNewDay => '新的一天';
	@override String get noticeNewRef => '新参考';
	@override String get noticeNewMult => '新倍数';
	@override String get noticeNewZone => '新分区';
	@override String get noticeInvalidMode => '模式错误';
	@override String get noticeInvalidBand => '频段错误';
	@override String get noticeInvalidCategory => '不可通联';
	@override String get noticeWorkedBefore => '曾通联';
	@override String get noticeNewPark => '新公园';
	@override String get noticeNewSection => '新分部';
	@override String get noticeBonusStation => '奖励电台！';
	@override String get noticeMissingExchange => '无交换';
	@override String get noticeInvalidExchange => '交换错误';
	@override String get noticeUnknownEvent => '未知活动';
	@override String get noticeOurGrid => '设置我方网格';
	@override String get noticeRareCounty => '稀有县！';
	@override String get noticeOurLocation => '设置我方县';
	@override String get noticeShortGrid => '网格太短';
}

// Path: callInfo.history
class _Translations$callInfo$history$zh extends Translations$callInfo$history$en {
	_Translations$callInfo$history$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '过去 7 天内有 ${n} 条';
	@override String today({required Object n}) => '今天有 ${n} 条';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${n} 个 QSO',
		other: '${n} 个 QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$zh extends Translations$settings$theme$en {
	_Translations$settings$theme$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '主题模式';
	@override String get system => '跟随系统设置';
	@override String get light => '明亮';
	@override String get dark => '黑暗';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$zh extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get system => '正在跟随系统设置';
	@override String get light => '保持明亮模式';
	@override String get dark => '保持黑暗模式';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$zh extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => '最小--';
	@override String get smallestMinus => '最小-';
	@override String get smallest => '最小';
	@override String get smaller => '更小';
	@override String get normal => '正常';
	@override String get larger => '更大';
	@override String get largest => '最大';
	@override String get largestPlus => '最大+';
	@override String get largestPlusPlus => '最大++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$zh extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '保持设备唤醒';
	@override String get descriptionOn => '在记录视图中或同步进行时保持唤醒';
	@override String get descriptionOff => '照常休眠';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$zh extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get auto => '自动';
	@override String get densest => '最紧凑';
	@override String get dense => '紧凑';
	@override String get normal => '正常';
	@override String get sparse => '宽松';
	@override String get sparsest => '最宽松';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$zh extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get kilometers => '公里';
	@override String get miles => '英里';
}

// Path: settings.logging
class _Translations$settings$logging$zh extends Translations$settings$logging$en {
	_Translations$settings$logging$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '记录';
	@override late final _Translations$settings$logging$leftieMode$zh leftieMode = _Translations$settings$logging$leftieMode$zh._(_root);
	@override late final _Translations$settings$logging$countryFlags$zh countryFlags = _Translations$settings$logging$countryFlags$zh._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$zh countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$zh._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$zh suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$zh._(_root);
	@override late final _Translations$settings$logging$showBearing$zh showBearing = _Translations$settings$logging$showBearing$zh._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$zh showReverseBearing = _Translations$settings$logging$showReverseBearing$zh._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$zh switchSentRcvd = _Translations$settings$logging$switchSentRcvd$zh._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$zh jumpAfterRST = _Translations$settings$logging$jumpAfterRST$zh._(_root);
	@override late final _Translations$settings$logging$defaultReport$zh defaultReport = _Translations$settings$logging$defaultReport$zh._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$zh defaultReportCW = _Translations$settings$logging$defaultReportCW$zh._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$zh defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$zh._(_root);
	@override late final _Translations$settings$logging$numbersRow$zh numbersRow = _Translations$settings$logging$numbersRow$zh._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$zh numbersRowExtra = _Translations$settings$logging$numbersRowExtra$zh._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$zh numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$zh._(_root);
	@override String get bands => '首选频段';
	@override String get modes => '首选模式';
}

// Path: settings.catServer
class _Translations$settings$catServer$zh extends Translations$settings$catServer$en {
	_Translations$settings$catServer$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT 服务器';
	@override String get description => '允许其他应用（WSJT-X、日志软件等）通过 Ham2K Logger 控制电台。';
	@override String get protocol => '协议';
	@override late final _Translations$settings$catServer$protocolOpts$zh protocolOpts = _Translations$settings$catServer$protocolOpts$zh._(_root);
	@override String get port => '端口';
	@override String get openAccess => '开放访问';
	@override String get openAccessOn => '本地网络上的任何计算机都可以连接。';
	@override String get openAccessOff => '只有本计算机上的应用可以连接。';
	@override String get off => '关闭。';
	@override String starting({required Object protocol}) => '${protocol}，启动中…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} 在端口 ${port} 上。已连接客户端：${clients}。';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} 在端口 ${port} 上，但没有连接主 VFO 电台。';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} 无法在端口 ${port} 上监听：${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} 无法在端口 ${port} 上监听：另一个程序正在使用它，通常是 ${protocol} 本身。请关闭该程序或选择其他端口。';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} 无法在端口 ${port} 上监听：此计算机不允许。请选择 1024 以上的端口。';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} 已停止在端口 ${port} 上监听。正在重试…';
}

// Path: settings.radio
class _Translations$settings$radio$zh extends Translations$settings$radio$en {
	_Translations$settings$radio$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT 控制';
	@override String get loggingAndCat => '记录与 CAT';
	@override String get tuningSection => '调谐';
	@override String get keyerSection => '电键';
	@override String get servicesSection => '服务';
	@override String get stationConfigurationSection => '电台配置';
	@override String get moreSettings => '更多电台配置设置';
	@override late final _Translations$settings$radio$units$zh units = _Translations$settings$radio$units$zh._(_root);
	@override late final _Translations$settings$radio$pttKey$zh pttKey = _Translations$settings$radio$pttKey$zh._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$zh smartVfoSnap = _Translations$settings$radio$smartVfoSnap$zh._(_root);
	@override late final _Translations$settings$radio$snapDebounce$zh snapDebounce = _Translations$settings$radio$snapDebounce$zh._(_root);
	@override late final _Translations$settings$radio$snapLongMove$zh snapLongMove = _Translations$settings$radio$snapLongMove$zh._(_root);
	@override late final _Translations$settings$radio$snapMinMove$zh snapMinMove = _Translations$settings$radio$snapMinMove$zh._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$zh snapMinSpeed = _Translations$settings$radio$snapMinSpeed$zh._(_root);
	@override late final _Translations$settings$radio$enterSends$zh enterSends = _Translations$settings$radio$enterSends$zh._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$zh keyerSpeed = _Translations$settings$radio$keyerSpeed$zh._(_root);
	@override late final _Translations$settings$radio$cwMessages$zh cwMessages = _Translations$settings$radio$cwMessages$zh._(_root);
	@override late final _Translations$settings$radio$voiceMessages$zh voiceMessages = _Translations$settings$radio$voiceMessages$zh._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$zh avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$zh._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$zh zeroBeatRange = _Translations$settings$radio$zeroBeatRange$zh._(_root);
}

// Path: settings.help
class _Translations$settings$help$zh extends Translations$settings$help$en {
	_Translations$settings$help$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '帮助与资源';
	@override String get description => '社区与支持';
	@override String get forums => 'Ham2K 论坛';
	@override String get forumsDescription => '寻找帮助，给予反馈，讨论想法…';
	@override String get chat => 'Ham2K 聊天';
	@override String get chatDescription => '我们的在线社区的 Discord 服务器';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => '视频和直播';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => '因为照片永远不嫌多…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => '关注我们以获取新闻和更新';
	@override String get contact => '联系我们';
	@override String get contactDescription => 'help@ham2k.com——但请先尝试使用论坛或聊天！';
}

// Path: settings.exports
class _Translations$settings$exports$zh extends Translations$settings$exports$en {
	_Translations$settings$exports$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '导出';
}

// Path: settings.map
class _Translations$settings$map$zh extends Translations$settings$map$en {
	_Translations$settings$map$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '地图';
	@override late final _Translations$settings$map$style$zh style = _Translations$settings$map$style$zh._(_root);
	@override late final _Translations$settings$map$styleOpts$zh styleOpts = _Translations$settings$map$styleOpts$zh._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$zh extends Translations$settings$privacy$en {
	_Translations$settings$privacy$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '隐私';
	@override late final _Translations$settings$privacy$shareAppData$zh shareAppData = _Translations$settings$privacy$shareAppData$zh._(_root);
	@override late final _Translations$settings$privacy$shareOpData$zh shareOpData = _Translations$settings$privacy$shareOpData$zh._(_root);
	@override String get privacyPolicy => '隐私政策';
	@override String get termsOfService => '服务条款';
}

// Path: settings.sync
class _Translations$settings$sync$zh extends Translations$settings$sync$en {
	_Translations$settings$sync$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '云同步';
	@override String get moreSettings => '更多同步设置';
	@override String get enable => '启用同步';
	@override String get deviceKey => '设备密钥';
}

// Path: settings.peers
class _Translations$settings$peers$zh extends Translations$settings$peers$en {
	_Translations$settings$peers$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '对等设备';
	@override String get enable => '连接到其他设备';
	@override String get enableDescription => '允许通过本地网络与其他设备共享操作、记录、CAT 和 GPS';
	@override String get bleEnable => '通过蓝牙连接';
	@override String get bleDescription => '即使没有本地网络，也使用低功耗蓝牙连接';
	@override String get thisDevice => '此设备';
	@override String get deviceName => '名称';
	@override String get deviceNameHint => '其他设备看到的此设备名称';
	@override String get pairedDevices => '已链接设备';
	@override String get noPairedDevices => '尚未链接设备。在此网络上的另一台设备上开启此项即可链接。';
	@override String deviceListProblem({required Object error}) => '无法读取已链接设备：${error}';
	@override String get nearby => '附近';
	@override String get connected => '已连接';
	@override String get viaBluetooth => '通过蓝牙';
	@override String get connecting => '连接中…';
	@override String get syncing => '同步中…';
	@override String get waitingForThem => '等待另一台设备';
	@override String get notConnected => '未连接';
	@override String get wantsToPair => '想要共享此操作';
	@override String get allow => '允许';
	@override String get link => '链接';
	@override String get reject => '拒绝';
	@override String get forget => '忘记';
	@override String forgetTitle({required Object name}) => '忘记 ${name}？';
	@override String get forgetBody => '它将停止与此设备同步。您之后可以再次允许，已记录的通联会保留。';
	@override String pairTitle({required Object name}) => '与 ${name} 链接';
	@override String get pairBody => '此设备位于您的本地网络上，想要连接。';
	@override String get pairBodyBle => '此设备就在附近，想要通过低功耗蓝牙连接。';
	@override String get pairIdLabel => '设备 ID';
	@override String get pairWarning => '只与您认识的设备链接。此网络上的任何设备都可以发送请求。';
	@override String get pairWarningBle => '只与您认识的设备链接。附近的任何设备都可以发送请求。';
	@override String problem({required Object error}) => '无法访问本地网络：${error}';
	@override String bleProblem({required Object error}) => '蓝牙：${error}';
	@override String statusConnected({required Object device}) => '已连接到 ${device}';
	@override String statusLost({required Object device}) => '与 ${device} 的连接已断开';
	@override String statusPerma({required Object connected, required Object linked}) => '对等设备：已连接 ${connected} / ${linked}';
	@override String get screenEnable => '共享屏幕和窗口';
	@override String get screenDescription => '允许其他设备显示此计算机的屏幕或窗口';
	@override String get screenSources => '屏幕和窗口';
	@override String get screenRefresh => '刷新列表';
	@override String get screenUnsupportedPlatform => '此设备无法共享屏幕。macOS 可以；所有设备都能显示其他设备共享的屏幕。';
	@override String get screenUnsupportedVersion => '共享屏幕需要 macOS 12.3 或更高版本。此设备仍可显示其他设备共享的屏幕。';
	@override String get screenNeedsPermission => '需要您授予 macOS 屏幕录制权限，此应用才能共享屏幕。';
	@override String get screenGrantPermission => '请求权限';
	@override String get screenRelaunchAfterGranting => '请在 系统设置 → 隐私与安全性 → 屏幕录制 中允许，然后退出并重新打开此应用——macOS 只在应用下次启动时才告知此更改。';
	@override String screenProblem({required Object error}) => '屏幕共享：${error}';
	@override String get screenChooseTitle => '选择要共享的内容';
	@override String get screenChooseButton => '选择要共享的内容…';
	@override String get screenTabScreens => '屏幕';
	@override String get screenTabApps => '应用';
	@override String get screenTabWindows => '窗口';
	@override String get screenTabEmpty => '未找到此类内容。';
	@override String get screenSharedSummaryNone => '尚未选择任何内容。';
	@override String get screenThisDevice => '此设备';
	@override String screenSharedTo({required Object devices}) => '显示于 ${devices}';
	@override String get screenSharedToNobody => '未在显示';
	@override String screenStopSharing({required Object name}) => '停止共享 ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$zh extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get configuration => '同步配置';
	@override String get enableTitle => '与 Ham2K Log Filer 同步';
	@override String get enabledDescription => '正在备份日志并在设备间同步';
	@override String get disabledDescription => '关闭——仅保存在此设备上';
	@override String get syncing => '同步中';
	@override String get account => '账户';
	@override String get refresh => '刷新';
	@override String get switchAccounts => '切换账户';
	@override String get switchAccountsDescription => '通过二维码或电子邮件将此设备链接到另一个账户';
	@override String get connectionRequests => '连接请求';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '有 1 台设备正在等待加入此账户',
		other: '有 ${n} 台设备正在等待加入此账户',
	);
	@override String get accountEmailTitle => '账户电子邮件';
	@override String accountEmailSent({required Object email}) => '确认邮件已发送到 ${email}。请打开其中的链接完成更改。';
	@override String get resendConfirmation => '重新发送确认邮件';
	@override String resendConfirmationDescription({required Object email}) => '等待 ${email} 确认';
	@override String accountEmailResent({required Object email}) => '已再次发送到 ${email}。';
	@override String get deviceLinked => '该设备现已链接到此账户。';
	@override String get checking => '检查中…';
	@override String get notLinked => '尚未链接';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => '替换本地数据？';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${n} 个操作',
		other: '${n} 个操作',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${n} 个 QSO',
		other: '${n} 个 QSO',
	);
	@override String get counts => '已同步数据';
	@override String countsLocal({required Object qsos, required Object operations}) => '此设备：${qsos} · ${operations}';
	@override String countsPending({required Object items}) => '等待上传：${items}';
	@override String countsServer({required Object qsos, required Object operations}) => '服务器：${qsos} · ${operations}';
	@override String get countsLocalChecking => '此设备：检查中…';
	@override String get countsServerChecking => '服务器：检查中…';
	@override String get countsServerUnavailable => '服务器：不可用';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => '这将备份并清除此设备上的 ${operations} 和 ${qsos}，然后改为下载该账户的数据。备份保留在此设备的数据库中。';
	@override String get replace => '替换';
	@override String get pendingBannerTitle => '检测到新的 Ham2K Log Filer 账户';
	@override String get pendingBannerBody => '保留此设备上现有的操作和 QSO 并合并到该账户，或用该账户的数据替换它们（无论哪种方式，此设备上都会保留一份备份）。';
	@override String get combine => '合并';
	@override String get authIssueTitle => '同步无法连接';
	@override String get authIssueText => 'Ham2K Log Filer 一直拒绝此设备。请在同步设置中检查您的呼号。';
	@override String get openSettings => '打开同步设置';
}

// Path: settings.accounts
class _Translations$settings$accounts$zh extends Translations$settings$accounts$en {
	_Translations$settings$accounts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '账户、服务和数据源';
	@override String get none => '没有带账户的活动扩展';
	@override String get notConfigured => '未配置';
	@override String get connected => '已连接';
	@override String get cancelLogin => '取消登录';
	@override String get openInBrowser => '在浏览器中打开';
	@override String loggedInAs({required Object identity}) => '已登录为 ${identity}';
	@override String get pressSaveToKeep => '按“保存”以保持此账户连接。';
	@override String connectedTo({required Object label}) => '已连接到 ${label}';
	@override String get connect => '连接';
	@override String get disconnect => '断开连接';
	@override String get connectedAs => '已连接为';
	@override String get test => '测试';
	@override String saveFailed({required Object error}) => '保存失败：${error}';
	@override String loginFailed({required Object error}) => '登录失败：${error}';
	@override String get lookupFailed => '账户暂时不可用——请稍后重试';
	@override String get browserLoginTitle => '请在网页浏览器中完成登录';
	@override String browserLoginSteps({required Object prefix}) => '完成后，浏览器会尝试打开以“${prefix}”开头的链接。您的桌面很可能没有注册能打开它的程序，因此请复制该链接（从地址栏，或从浏览器显示的错误页面），然后粘贴到这里。';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger 无法打开您的浏览器。请复制下面的登录链接并自行打开，然后复制它跳转到的链接（以“${prefix}”开头）并粘贴到这里。';
	@override String get copyLoginLink => '复制登录链接';
	@override String get pastedLinkLabel => '在此粘贴链接';
	@override String get finishLogin => '完成登录';
	@override String pastedLinkNotARedirect({required Object prefix}) => '这不是登录链接——它应以“${prefix}”开头。';
	@override String get pastedLinkWrongLogin => '该链接属于另一次登录尝试。请关闭此页面并重新连接。';
	@override String get pastedLinkNoCode => '该链接没有登录代码。请先完成登录，再复制它跳转到的链接。';
	@override String get pastedLinkMalformed => '该链接似乎被截断了。请复制完整链接后重新粘贴。';
	@override String get relayLoginWaiting => '等待您完成登录——完成后将自动继续。';
	@override String get loginNoResponse => '此设备尚未收到登录的回应。如果您已在浏览器中完成，请取消并重新连接。';
	@override String get relayLoginNotOpened => 'Ham2K Logger 无法自动打开您的浏览器。请使用下面的按钮自行打开登录页面。';
	@override String get relayLoginUnavailable => '无法连接完成此登录所需的同步服务器。请检查网络连接后重试。';
	@override String get loginIncompleteResponse => '该登录尝试未正确完成。请重新连接。';
	@override String get noKeyringTitle => '无法保存账户登录信息';
	@override String get noKeyringText => 'Ham2K Logger 无法访问此计算机上的密钥环服务，因此无法存储或读取账户登录信息——在解决此问题之前，连接账户将会失败。请安装并启动 **gnome-keyring**、**KWallet** 或 **KeePassXC**，或解锁您现有的密钥环，然后重新启动。记录、导出和数据文件不受影响；在此期间日志同步保持关闭。';
	@override String get noKeyringInline => '无法保存登录信息：无法访问此计算机的密钥环。请安装并启动 gnome-keyring、KWallet 或 KeePassXC，或解锁您现有的密钥环。';
	@override String get noSecureStorageInline => '无法保存登录信息：无法访问此计算机的安全存储。';
}

// Path: settings.station
class _Translations$settings$station$zh extends Translations$settings$station$en {
	_Translations$settings$station$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '电台配置与 CAT 控制';
	@override String get none => '未配置设备';
	@override String get add => '添加';
	@override String get addTitle => '添加设备';
	@override String get searchHint => '搜索设备';
	@override String get noMatches => '没有匹配的设备';
	@override String get detectedEquipment => '检测到的设备';
	@override String discoveryUnavailable({required Object error}) => '无法监听电台：${error}';
	@override String get edit => '编辑设备';
	@override String get name => '名称';
	@override String get nameDescription => '您对它的称呼——如“左边的电台”。可选。';
	@override String get transport => '连接';
	@override String get host => '地址';
	@override String get hostDescription => '电台在您网络上的主机名或 IP 地址。';
	@override String get port => '端口';
	@override String get hostRequired => '必须填写地址';
	@override String get portInvalid => '端口必须在 1 到 65535 之间';
	@override String get connect => '连接';
	@override String get disconnect => '断开连接';
	@override String get remove => '移除';
	@override String removeTitle({required Object name}) => '移除 ${name}？';
	@override String get removeMessage => '这只会将其从应用中移除。设备本身的设置保持不变。';
	@override String unknownType({required Object typeKey}) => '无法识别的设备类型“${typeKey}”';
	@override String get report => '报告';
	@override String get reportTitle => '报告此电台';
	@override String get reportIntro => '告诉我们这台电台的真实型号以及使用情况。您的报告会成为 Ham2K 团队阅读的卡片，您写下的调试经验也可能帮助下一位使用同款电台的操作员。';
	@override String get reportManufacturer => '制造商';
	@override String get reportManufacturerDescription => '谁生产的——Icom、Yaesu、Kenwood、Elecraft…';
	@override String get reportManufacturerRequired => '必须填写制造商';
	@override String get reportModel => '型号';
	@override String get reportModelDescription => '电台自身所示的型号——“IC-7300”、“FT-991A”。';
	@override String get reportModelRequired => '必须填写型号';
	@override String get reportOutcome => '使用情况如何？';
	@override String get reportOutcomeWorks => '工作良好';
	@override String get reportOutcomeIssues => '能工作，但有问题';
	@override String get reportOutcomeFails => '完全无法工作';
	@override String get reportOutcomeRequired => '请告诉我们使用情况';
	@override String get reportComments => '评论';
	@override String get reportCommentsPlaceholder => '哪些可行、哪些不行，以及任何出乎意料的情况。';
	@override String get reportHints => '故障排除提示';
	@override String get reportHintsPlaceholder => '想为其他用户提供一些故障排除提示吗？';
	@override String get reportSend => '发送报告';
	@override String get reportSending => '正在发送您的报告…';
	@override String reportSent({required Object ref}) => '谢谢——您的报告已登记为 ${ref}。';
	@override String get reportSentNoRef => '谢谢——您的报告已发送。';
	@override String reportFailed({required Object error}) => '报告未发送：${error}';
	@override String get troubleshootingNotes => '故障排除说明';
	@override String get mainVfo => '主 VFO';
	@override String get useAsMainVfo => '用作主 VFO';
	@override String get serialPort => '串口';
	@override String get serialPortDescription => '电台 CAT 接口所在的端口。';
	@override String get serialPortNone => '未找到串口';
	@override String get serialPortRequired => '请选择串口';
	@override String serialPortOrdinal({required Object n, required Object total}) => '端口 ${n} / ${total}';
	@override String get serialPortSuggested => '建议';
	@override String get serialPortJustNow => '最近连接';
	@override String get serialDeviceRequest => '添加 USB 设备…';
	@override String get baudRate => '速率（波特）';
	@override String get baudRateDescription => '必须与电台的 CAT 菜单一致。不一致时，电台会返回乱码且不报错。';
	@override String get serialRtsHigh => '保持 RTS 为高';
	@override String get serialRtsHighDescription => '仅适用于响应前等待 RTS 的电台，例如开启了 CAT RTS 的 Yaesu。在 Digirig、SignaLink 和大多数自制线缆上，RTS 就是 PTT，保持为高会导致发射。';
	@override String get serialDtrHigh => '保持 DTR 为高';
	@override String get serialDtrHighDescription => '仅适用于从 DTR 取电的 CAT 接口，例如某些用于 FT-817 的 RS-232 线缆。在许多线缆上 DTR 用于 CW 键控或 PTT，保持为高会导致发射。';
	@override String get civAddress => '电台 CI-V 地址';
	@override String get civAddressDescription => '十六进制，与电台 CI-V 菜单中显示的一致。IC-705 出厂为 A4。';
	@override String get civAddressInvalid => 'CI-V 地址为两位十六进制数，01 到 FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => '此连接读取并调谐电台的哪个 Slice。';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => '请选择电台的某个 Slice，A 到 H';
	@override String flexSliceMissing({required Object letter}) => '此电台未使用 Slice ${letter}——请选择其他 Slice，或在 SmartSDR 中创建';
	@override String get channelNotInUse => '未使用';
	@override String get channelHeldByUnknown => '被其他程序占用';
	@override String get flexNoSlices => '此电台未报告任何 Slice——请检查 SmartSDR 是否正在运行，以及此客户端是否可以订阅';
	@override String get spectrumUnsupported => '此电台不通过 CAT 发送频谱';
	@override String get spectrumRequiresBaud => '需要 CAT 速率为 115200 bps';
	@override String get spectrumNoRadio => '未连接电台';
	@override String get spectrumWaiting => '等待电台的频谱…';
	@override String get spectrumUnavailable => '频谱显示不可用';
	@override String get spectrumNoDaxChannel => '此电台的所有 DAX IQ 通道都已被占用';
	@override String get spectrumNoPanadapter => '此 Slice 在电台上没有全景显示';
	@override String spectrumStreamRefused({required Object code}) => '电台拒绝了 DAX IQ 流（错误 ${code}）';
	@override String get spectrumNoUdp => '电台的频谱数据无法到达此设备';
	@override String get spectrumScopeRefused => '电台拒绝了频谱仪命令';
	@override String get spectrumOutOfRange => '电台的频谱仪设置超出了可显示的范围';
	@override String get n3fjpNoRig => 'N3FJP 未设置电台接口，因此这里跟随的是在 N3FJP 中输入的内容，而不是电台';
	@override String get winkeyerKeyPort => '键控输出';
	@override String get winkeyerKeyPortDescription => '您的电台插在电键器两个输出插孔中的哪一个。';
	@override String winkeyerKeyPortLabel({required Object n}) => '端口 ${n}';
	@override String get winkeyerPtt => '使用电键器的 PTT';
	@override String get winkeyerPttDescription => '在同一插孔上键控 PTT 线，用于需要它的功放或电台。如电台通过其电键插孔键控，请保持关闭。';
	@override String get winkeyerNoAnswer => '此端口上没有 WinKeyer 响应';
	@override String get winkeyerStoppedAnswering => 'WinKeyer 在发送时停止响应；该消息已丢弃';
	@override String get radioUser => '电台用户名';
	@override String get radioPass => '电台密码';
	@override String get radioLoginDescription => '电台的 Network → Remote 登录信息，不是您的 WiFi 密码。';
	@override String get radioUserRequired => '必须填写电台的远程控制用户名';
	@override String get connectFailedBusy => '设备正在使用中';
	@override String get connectFailedDenied => '访问被拒绝';
	@override String get connectFailedDevice => '未找到设备';
	@override String get connectFailedLines => '无法按设置保持 RTS/DTR，因此已关闭端口。可能有其他程序开启了硬件握手——请拔下线缆后重新插入。';
	@override String get connectFailedNetwork => '无法通过网络找到电台。请检查其地址，并确认它已开机且可访问。';
	@override String get connectFailedTimeout => '电台未及时响应。请确认它已开机且可访问。';
	@override late final _Translations$settings$station$models$zh models = _Translations$settings$station$models$zh._(_root);
	@override late final _Translations$settings$station$transports$zh transports = _Translations$settings$station$transports$zh._(_root);
	@override String get troubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get ft891Troubleshooting => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **电台上的 CAT RTS 必须为 OFF**（FT-891 菜单 **05-08**）。开启时，电台会等待一条握手线，而应用将其保持为低。在 Digirig、SignaLink 或大多数自制线缆上，这条线就是 PTT，拉高它会让发射机发射。如使用电台自带的 USB 端口，可改为在高级设置中开启 **保持 RTS 为高**。\n- **速率必须与电台的 CAT RATE 一致**（菜单 **05-06**）。不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。';
	@override String get yaesuBinaryTroubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get yaesuBinaryTroubleshooting => '此电台使用 Yaesu 较早的五字节 CAT 协议，只要有任何问题就完全不响应。几乎总是以下原因之一：\n\n- **线缆必须转换电平。** 背面的 CAT 插孔既不是 RS-232 也不是 USB；需要 CT-62 或同等适配器。普通音频线或数据线无法用于 CAT。\n- **速率必须与电台的 CAT RATE 菜单一致**（FT-817 上为 **#14**，FT-857 或 FT-897 上为 **#19**）。不一致时，电台什么都不返回，而且从不报错。\n- **绝不要让任何程序拉高此端口的 RTS 或 DTR。** 在这些电台的大多数线缆上，这两条线用于 PTT 和键控。例外是由 DTR 供电的老式接口：对于这种接口，请在高级设置中开启 **保持 DTR 为高**。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n此驱动根据 Yaesu 公布的 CAT 表编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。';
	@override String get guohetecTroubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get guohetecTroubleshooting => 'Q900 有两种 CAT 协议，此条目使用其原生协议，而不是模仿 FT-817 的协议。请在此选择 **Guohetec Q900**，而不是 FT-817——模仿协议支持的命令更少，而且电台不会说明它正在使用哪一种。\n\n- **USB-C 线就是 CAT 连接**，它同时也连接声卡。在这条线上速率无关紧要；端口会忽略所设置的任何值。\n- **绝不要让任何程序拉高此端口的 RTS 或 DTR。** 在串口线上，这两条线用于 PTT 和键控。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **第二代电台的行为与第一代不同。** 长按 Menu，然后选择 About：HW 2.0 即为第二代。\n\n此驱动根据制造商公布的协议编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。';
	@override String get yaesuTroubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get yaesuTroubleshooting => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而应用将其保持为低。在 Digirig、SignaLink 或大多数自制线缆上，这条线就是 PTT，拉高它会让发射机发射。如使用电台自带的 USB 端口，可改为在高级设置中开启 **保持 RTS 为高**。该设置的位置因型号而异（FT-891 上为菜单 **05-08**）。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **模式遵循 FT-891 的对照表。** 大多数 Yaesu 电台与之相符，但模式编号不同的电台在这些模式上会显示和设置错误的模式。频率不受影响。';
	@override String get yaesuRs232Troubleshooting => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **CAT 插孔是 RS-232。** 需要 USB 转串口适配器和直通 DB-9 线缆——交叉（null-modem）线会交换信号线，电台将什么都收不到。\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而除非在高级设置中开启 **保持 RTS 为高**，应用会将其保持为低。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n此条目根据公开的 CAT 文档编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。';
	@override String get yaesuUsbTroubleshooting => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **使用电台两个 USB 端口中的第一个。** CAT 通常在第一个端口上（Windows 上为 **Enhanced** COM 端口）；第二个（**Standard**）用于 PTT 和键控。只要能区分两者，端口选择器都会指向第一个。\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而除非在高级设置中开启 **保持 RTS 为高**，应用会将其保持为低。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。';
	@override String get k4SerialNotes => '连接 K4 背面的 USB-B (PC) 插座。USB-PC1 或 USB-PC2 都可用于 CAT；请选择未使用的端口，并使其与电台上的 Serial USB-PCn: Baud Rate 设置一致。HaLo 预填为 38400；如有需要请更改。其他应用必须使用另一个端口或以太网。\n\n此连接控制电台及其电键器；不会向 HaLo 发送音频。';
	@override String get k4TcpNotes => '将 K4 的以太网插座连接到您的本地网络。输入其主机名或 IP 地址，以及 CAT 端口 9200。这是 CAT 控制，不是端口 9204 上单独的远程音频连接。\n\nHaLo 控制电台及其电键器，不传输音频或全景显示数据。';
	@override String get k4PowerTimeout => 'K4 功率未更改，因为电台没有确认其输出范围。请重试。';
	@override String get k4PowerRange => 'K4 功率必须为 0.1–110 W；当变频器毫瓦输出启用时，必须为 0.0001–0.01 W。';
	@override String get elecraftTroubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get elecraftTroubleshooting => 'Elecraft 电台使用 Kenwood CAT 协议，KX2 和 KX3 都已用这种方式实测——VFO 双向同步、模式切换和 CW 零差拍均可正常工作。\n\n如果电台没有响应，几乎总是以下原因之一：\n\n- **速率必须与电台菜单中 **RS232** 下设置的速率一致。** 这些电台出厂为 38400。不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n**如果频率正确但模式错误**，请告诉我们。KX2 和 KX3 条目从电台状态回复中的某个位置读取模式，这个位置是根据我们见过的电台确定的；如果某个固件把它放在别处，只有通过报告我们才能得知。\n\n目前还没有关于 K3 的任何报告，如果您在使用，请告诉我们结果。K4 有单独的条目。';
	@override String get kenwoodTroubleshootingTitle => '如果电台已连接但不显示频率';
	@override String get kenwoodTroubleshooting => '此驱动已在 Kenwood 的 TS-590SG 和 TS-480、QRP Labs 的 QMX 和 QCX-mini，以及 Elecraft 的 KX2 和 KX3 上验证。其余型号根据公开的 CAT 资料编写，因此无论结果如何，都请报告。\n\n如果电台没有响应，几乎总是以下原因之一：\n\n- **速率必须与电台的 CAT 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **某些电台需要先在菜单中启用 CAT**，否则完全不响应。\n\n**一些 SDR 前端也使用相同的协议**，因此对它们也值得尝试此条目；Elecraft 电台单独列在 Elecraft 下。如果频率正确但模式错误或缺失，这正是各型号之间唯一不同的部分——应用会根据电台推断模式，失败时再直接查询，因此模式可能只是稍有延迟。';
	@override String get statusConnected => '已连接';
	@override String get statusLost => '已断开';
	@override String get notConfigured => '未配置';
	@override String get currentConfiguration => '当前配置';
	@override String get currentTransceiver => '当前收发信机';
	@override String get radioMode => '电台模式';
	@override String get keyerNotSupported => '当前电台不支持';
	@override String get catControlPreferences => 'CAT 控制偏好';
	@override String get chooseTransceiver => '选择收发信机';
	@override String get configurationSection => '配置';
	@override String get noTransceiverSelected => '未选择收发信机';
	@override String makeMainVfo({required Object name}) => '将 ${name} 用作主 VFO';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		zero: '没有收发信机',
		one: '${count} 台收发信机',
		other: '${count} 台收发信机',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 副天线',
		other: '${count} 副天线',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 台其他设备',
		other: '${count} 台其他设备',
	);
	@override String get equipmentInventory => '设备清单';
	@override String get equipmentInUse => '收发信机控制';
	@override String get noTransceiver => '无';
	@override String get peerRadioNotAvailable => '不可用';
	@override String peerRadioOnDevice({required Object device}) => '位于 ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} 位于另一台设备上';
	@override String peerRadioElsewhereMessage({required Object device}) => '此电台连接在 ${device} 上。其连接和设置需在该设备上配置。';
	@override String get antennaInUse => '使用中的天线';
	@override String get keyInUse => '使用中的电键';
	@override String get noneSelected => '无';
	@override String get moreSettings => '更多设置';
	@override String get icomCivTroubleshootingTitle => '如果同一台电台出现两个串口';
	@override String get icomCivTroubleshooting => '包括 IC-705 在内的多款 Icom 电台会同时提供**两个** USB 串口（Icom 称为 Port A 和 Port B），默认都设为 CI-V。除此之外，本应用和您的操作系统都无法区分它们：同一个 USB 厂商/产品 ID 只是出现两次，有时在这里会带有 `#2` 后缀。**通常 Port A 才是正确的**——一般是操作系统或浏览器列出的第一个，在本应用能区分两个端口时，会将其标记为建议。如果命令已发出而电台始终没有响应，请改试另一个端口。';
	@override String get civAddressTroubleshootingTitle => '如果电台始终没有响应';
	@override String get civAddressTroubleshooting => '- **CI-V 地址必须与电台菜单一致。** 此条目预填了该型号的出厂地址，但多台电台共用 CI-V 总线时，正是需要更改这个地址的情况。发往错误地址的帧会被静默忽略，看起来就像线缆坏了一样。\n- **速率必须与电台的 CI-V BAUD RATE 一致**（USB 上为 CI-V USB Baud Rate）。请将电台设为与此处显示相同的数值，**不要用 Auto**。设为 Auto 时，包括 IC-7300 在内的一些电台连接后大约一分钟就会停止响应。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** 出厂地址为 `B6`，而不是此处预填的 `94`——请改选 IC-7300 MK2 条目。';
	@override String get ic705PortNote => '\n- **IC-705** 提供两个 USB 串口，都以电台名称命名。CI-V 在其中的**第一个**上，只要能区分两者，端口选择器都会指向它。';
	@override String get ic7760PortNote => '\n- **IC-7760** 在其提供的两个 USB 串口中的 **Port A** 上使用 CI-V。';
	@override String get x6100PortNote => '\n- **X6100** 在其 **DEV** 端口上使用 CI-V——即它提供的两个串口中的第二个，也是端口选择器指向的那个。';
	@override String get rigctldTroubleshootingTitle => '如果应用无法连接';
	@override String get rigctldTroubleshooting => '这会连接到**您自行运行的 rigctld 守护进程**，而不是直接连接电台——由 Hamlib 的后端与电台通信，支持数百种型号。\n\n- **守护进程必须已在运行**，例如 `rigctld -m 1035 -r /dev/ttyUSB0`。使用 `rigctl -l` 查找您电台的型号编号。\n- **从另一台计算机连接时**，请使用 `-T 0.0.0.0` 启动：默认情况下，rigctld 只接受来自其所在计算机的连接。\n- **端口**为 4532，除非您用 `-t` 启动守护进程。\n- 连接后如果没有频率，通常意味着守护进程本身无法访问电台。请在守护进程所在的计算机上用 `rigctl -m 2 f` 测试。';
	@override String get flrigTroubleshootingTitle => '如果应用无法连接';
	@override String get flrigTroubleshooting => '这会连接到**您自行运行的 flrig 程序**，而不是直接连接电台——由 flrig 与电台通信，支持大多数品牌和型号。\n\n- **flrig 必须已在运行**，并已配置和连接其收发信机。\n- **端口**为 12345，除非您在 flrig 的配置中更改过（Config → Setup → Server）。\n- **从另一台计算机连接时**，请确保 flrig 的服务器可以访问。它监听所有网络接口，但您的防火墙可能不允许。\n- 连接后如果没有频率，通常意味着 flrig 本身无法访问电台。请检查 flrig 的显示是否跟随旋钮变化。';
	@override String get hrdTroubleshootingTitle => '如果应用无法连接';
	@override String get hrdTroubleshooting => '这会连接到**在您计算机上运行的 Ham Radio Deluxe 的 Rig Control**，而不是直接连接电台——由 HRD 与电台通信。\n\n- **Rig Control 必须已在运行**并已连接到电台。\n- **必须启用其 IP 服务器。** Rig Control 只通过它与其他程序通信。\n- **端口**为 7809，除非您在 IP 服务器设置中更改过。\n- **从另一台计算机连接时**，请确保防火墙允许该连接。\n\n此条目根据公开的 HRD 协议说明编写，尚未与 HRD 实际运行过。如果它只部分可用，非常值得报告。';
	@override String get n3fjpTroubleshootingTitle => '如果应用无法连接';
	@override String get n3fjpTroubleshooting => '这会连接到**在您计算机上运行的 N3FJP 日志程序**，而不是直接连接电台——由 N3FJP 与电台通信。\n\n- **必须开启该程序的 API**：Settings → Application Program Interface，勾选 **TCP API Enabled**。\n- **端口**为 1100，除非您在那里更改过。\n- **N3FJP 必须设置了电台接口**，才能跟随或调谐电台。没有接口时，它只报告在其输入窗口中键入的内容。\n- N3FJP 只报告频段、模式和频率：不报告功率，也不报告发射状态。\n\n此条目根据 N3FJP 公开的 API 编写，尚未与 N3FJP 实际运行过。如果它只部分可用，非常值得报告。';
	@override String get commanderTroubleshootingTitle => '如果应用无法连接';
	@override String get commanderTroubleshooting => '这会连接到**在您计算机上运行的 DXLab Commander**，而不是直接连接电台——由 Commander 与电台通信。\n\n- **Commander 必须已在运行**并已连接到电台。\n- **必须开启其网络服务**：Commander 配置窗口 Radio 面板中的 **Net Serv** 按钮。\n- **端口**为 52002，即从 Net Serv 的 **Base Port**（默认为 52000，除非您更改过）开始的端口段中的第三个端口。\n- **从另一台计算机连接时**，请确保防火墙允许该连接。\n\n此条目根据 Commander 公开的 TCP 消息编写，尚未与 Commander 实际运行过。如果它只部分可用，非常值得报告。';
	@override String get ic705TroubleshootingTitle => '如果电台始终没有响应';
	@override String get ic705Troubleshooting => '电台只有**一个**远程控制会话。登录被忽略时，几乎总是有其他程序在使用它。\n\n- **关闭任何其他客户端。** 连接到同一电台的 wfview 或 RS-BA1 会占用这个会话，在此期间这里的登录会被直接忽略。\n- **检查电台的网络设置。** 必须开启 WLAN，电台必须在同一网络上，并且必须启用其远程控制（Network）功能。\n- 如果一直卡住，**请将电台的 WLAN 关闭再打开**。这样可以可靠地清除卡在电台上的会话。\n\n**密码错误会被明确拒绝**，而不是没有响应。如果您看到的是这里而不是“被拒绝”的消息，问题就不在密码。';
	@override String get statusStale => '无响应';
	@override String get statusDisconnected => '未连接';
	@override String get statusConnecting => '连接中…';
	@override String get statusDisconnecting => '正在断开…';
	@override String get statusError => '连接失败';
	@override String get currentRadioSettings => '当前电台设置';
	@override String get notSupportedByThisRadio => '此电台不支持';
	@override String get keyerRowLabel => '电键';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => '话音';
	@override String voiceKeyerAvailable({required Object count}) => '语音电键：电台中有 ${count} 个存储';
	@override String get antennaBands => '频段';
	@override String get antennaType => '天线类型';
	@override String get antennaTypeRequired => '请选择天线类型';
	@override late final _Translations$settings$station$antennaTypes$zh antennaTypes = _Translations$settings$station$antennaTypes$zh._(_root);
	@override String get keyType => '电键类型';
	@override String get keyTypeRequired => '请选择电键类型';
	@override late final _Translations$settings$station$keyTypes$zh keyTypes = _Translations$settings$station$keyTypes$zh._(_root);
	@override String get softwareIntermediaries => '中间软件';
	@override String get otherBrands => '其他品牌';
	@override String get otherEquipment => '其他设备（天线、电键等）';
	@override String get newAntenna => '新天线';
	@override String get newKey => '新电键';
	@override String get newKeyer => 'WinKeyer（K1EL 或兼容）';
	@override String keyViaRadio({required Object radio}) => '${radio} 中的 CAT 电键器';
	@override String keyOnDevice({required Object device}) => '${device} 上的电键';
	@override String get cwKeyerArea => '电键区域';
	@override String get trackStationInfo => '为每个 QSO 记录电台信息';
	@override String get includeStationInfoInAdif => '包含在 ADIF 导出中';
	@override String get whatToTrack => '记录哪些内容？';
	@override String get trackFieldRig => '收发信机';
	@override String get trackFieldPower => '功率';
	@override String get watts => '瓦';
	@override String get trackFieldAntenna => '天线';
	@override String get trackFieldKey => 'CW 电键';
	@override String get placeholderConnectDelay => '连接延迟 (ms)';
	@override String get placeholderConnectDelayDescription => '模拟握手所需的时间。留空或 0 表示立即连接。';
	@override String get placeholderDropAfter => '断开时间（秒）';
	@override String get placeholderDropAfterDescription => '自行关闭连接，以测试重连流程。留空或 0 表示从不断开。';
	@override String get placeholderFailConnect => '总是连接失败';
	@override String get placeholderConnectFailure => '占位电台被设置为拒绝此连接';
	@override String get placeholderFreq => '频率 (kHz)';
	@override String get placeholderFreqDescription => '占位电台的起始频率。之后应用调谐到哪里，它就报告哪里。';
	@override String get placeholderMode => '模式';
	@override String get placeholderModeDescription => '占位电台的起始模式，例如 USB、CW、FT8。';
	@override String get placeholderPower => '功率（瓦）';
	@override String get placeholderPurpose => '用此电台记录您在记录时使用的是哪台设备';
	@override String get placeholderReplyDelay => '回复延迟 (ms)';
	@override String get placeholderReplyDelayDescription => '占位电台报告变化所需的时间。留空或 0 表示立即回复。';
	@override String get cwKeyerField => 'CAT CW 电键器';
	@override String get cwKeyerFieldDescription => '此电台是否通过 CAT 将文本键控为 CW。对于应用不认识的电台请关闭。';
	@override String get voiceMemories => '语音存储';
	@override String get voiceMemoriesDescription => '电台可通过 CAT 播放的语音存储数量。0 表示没有。';
	@override String get voiceMemoriesInvalid => '整数，0 或更大';
	@override String get yaesuMeterCapture => '捕获表头读数';
	@override String get yaesuBinaryMeterCaptureDescription => '在发射时读取电台的输出功率表和 SWR 过高标志，并将原始值输出到日志。用于建立 Yaesu 未公布的刻度——这些值不会以表头形式显示。';
	@override String get yaesuMeterCaptureDescription => '在发射时读取电台的 PO、SWR 和 ALC 表头，并将原始值输出到日志。用于建立 Yaesu 未公布的刻度——这些值不会以表头形式显示。';
	@override String get telemetryInterval => '表头读取间隔 (ms)';
	@override String get telemetryIntervalDescription => '电台发射时读取其表头的频率。留空则使用此连接能承受的最快速度，最高 200 ms。';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => '整数毫秒，${min} 到 ${max}';
	@override String get pollInterval => '空闲轮询间隔 (ms)';
	@override String pollIntervalDescription({required Object fallback}) => '在频率和模式都没有变化时，向电台查询频率和模式的频率。留空则为 ${fallback} ms。';
	@override String pollIntervalInvalid({required Object min, required Object max}) => '整数毫秒，${min} 到 ${max}';
	@override String get advancedSettings => '高级设置';
	@override String get placeholderSwr => 'SWR 读数';
	@override String get placeholderSwrDescription => '此电台在发射时 SWR 表上报告的数值。高于 1.8 时面板会警告。';
	@override String get placeholderSwrInvalid => '数字，1 或更大';
	@override String get keyerNone => '无';
	@override String get cwDialect => 'CW 键控方言';
	@override String get cwDialectDescription => '此电台接受哪种格式的 KY 命令。“无”表示不通过 CAT 进行 CW 键控。';
	@override String get cwDialectKenwood => 'Kenwood（KY，补齐到 24）';
	@override String get cwDialectElecraft => 'Elecraft（KY 文本）';
	@override String get voiceDialect => '语音电键方言';
	@override String get voiceDialectDescription => '此电台如何通过 CAT 播放语音存储。“无”表示不通过 CAT 播放语音存储。选择了方言但未设数量时，使用该方言的默认数量。';
	@override String get voiceDialectPb => 'Kenwood（PB，TS-590 风格）';
	@override String get voiceDialectK4 => 'Elecraft K4（PB 和 DA）';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3（开关点按）';
	@override String get placeholderDiagnostic => '模拟';
	@override String get placeholderWholeNumberInvalid => '必须是整数，0 或更大';
	@override String get placeholderFreqInvalid => '必须是以 kHz 为单位且大于零的频率';
	@override String get placeholderModeInvalid => '必须是模式名称，例如 USB、CW、FT8';
	@override String get switchLayout => '布局';
	@override String get switchLayoutDescription => '您的电台插在开关的哪一侧。';
	@override String get switchLayoutRequired => '请选择开关的接线方式';
	@override String switchCommandRefused({required Object command, required Object code}) => '开关拒绝了“${command}”（错误 ${code}）';
	@override String get switchBusyTransmitting => '该端口正在发射——未更换天线';
	@override String get switchNoAntenna => '无';
	@override String switchAntennaFor({required Object port}) => '端口 ${port} 上的天线';
	@override String get switchAntennaForDescription => '您的哪副天线连接到开关的这个端口。';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} 副天线，${radios} 台电台';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} 副天线，1 台电台';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 副天线，${radios} 台电台';
	@override String get switchCommonPort => '公共端';
	@override String get dcnAddress => '设备地址';
	@override String get dcnAddressDescription => '模块 DIP 开关上设置的地址。同轴继电器模块出厂为 2。';
	@override String get dcnAddressRequired => '必须是 1 到 99 之间的设备地址';
	@override String switchPortLabel({required Object port}) => '端口 ${port}';
	@override String get switchPortAutoHint => '跟随频段数据';
	@override String get switchPortTransmittingHint => '正在发射——现在无法更改';
	@override String get switchCurrentStateHeader => '当前状态';
	@override String get switchCurrentStateDescription => '每个电台端口当前连接的天线。更改立即生效。';
	@override String get switchWiringHeader => '接线';
	@override String get switchPortInhibitedHint => '禁止发射';
	@override String get configUnreadable => '无法读取此电台保存的设置。请打开其设置并重新输入，或将其移除后重新添加。';
	@override String get autoConnectHeld => 'HaLo 上次连接此电台时停止了响应，因此这次没有自动连接。请按“连接”重试。';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$zh extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '离线数据';
	@override String get noFiles => '没有数据文件';
	@override String get noFilesDescription => '启用活动或查询扩展后，可在此下载其离线数据。';
	@override String get refresh => '刷新';
	@override String get refreshing => '刷新中…';
	@override String get updateAll => '全部更新';
	@override String get updatingAll => '正在更新所有数据文件…';
	@override String get neverDownloaded => '从未下载';
	@override String get updatedJustNow => '刚刚更新';
	@override String updatedDaysAgo({required Object days}) => '${days} 天前更新';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '${days} 天 ${hours} 小时前更新';
	@override String updatedHoursAgo({required Object hours}) => '${hours} 小时前更新';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '${hours} 小时 ${minutes} 分钟前更新';
	@override String updatedMinutesAgo({required Object minutes}) => '${minutes} 分钟前更新';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => '上次下载只有 ${imported} / ${existing} 条记录，因此未被采用。刷新即可接受它。';
	@override String get extensionsSection => '扩展';
}

// Path: settings.profiles
class _Translations$settings$profiles$zh extends Translations$settings$profiles$en {
	_Translations$settings$profiles$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get notSet => '未设置';
	@override String get personalInfo => '个人信息';
	@override String get personalInfoNote => '在提交需要时，这些信息可能会包含在生成的日志中';
	@override String get name => '姓名';
	@override String get email => '电子邮件';
	@override String get club => '俱乐部';
	@override String get arrlSection => 'ARRL 分部';
	@override String get racSection => 'RAC 分部';
	@override String get section => '分部';
}

// Path: settings.search
class _Translations$settings$search$zh extends Translations$settings$search$en {
	_Translations$settings$search$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get clear => '清除';
	@override String get hint => '搜索偏好设置';
}

// Path: settings.developer
class _Translations$settings$developer$zh extends Translations$settings$developer$en {
	_Translations$settings$developer$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => '启用开发者警告、调试日志和工具。';
	@override String get experiments => '实验';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已启用 ${count} 个',
		other: '已启用 ${count} 个',
	);
	@override String get patchTrack => '代码推送轨道';
	@override String get patchTrackDescription => '此设备跟随哪个空中代码推送轨道。越激进的轨道越早获得修复，但测试越少。代码推送在下次重启时生效。';
	@override String get trackStable => '稳定';
	@override String get trackUnstable => '不稳定';
	@override String get trackBleeding => '前沿';
	@override String checkingTrack({required Object track}) => '正在“${track}”上检查代码推送…';
	@override String get patchDownloaded => '代码推送已下载——重启应用以应用。';
	@override String noNewPatch({required Object track}) => '“${track}”上没有新的代码推送。';
	@override String get noPatchInstalled => '未安装代码推送——正在运行发布版本。';
	@override String runningPatch({required Object patch}) => '正在运行代码推送 #${patch}。';
	@override String get deepLinks => '深层链接';
	@override String get registerUrlSchemes => '注册 URL 协议';
	@override String get registerUrlSchemesDescription => '让 com.ham2k:// 链接打开此应用副本';
	@override String get registerUrlSchemesDone => '此副本现在会打开 com.ham2k:// 链接';
	@override String registerUrlSchemesFailed({required Object error}) => '无法注册：${error}';
	@override String get systemInformation => '系统信息';
	@override String get appVersion => '应用版本';
	@override String get dataFolder => '数据文件夹';
	@override String get loading => '（加载中…）';
	@override String get panelLoadFailed => '无法加载此设置面板。';
	@override String get extDevServer => '扩展开发服务器';
	@override String get extensionSettings => '扩展设置';
	@override String get extDevServerDescription => '从您网络上的开发服务器加载扩展，而不是使用应用内置的扩展，并在您保存时重新加载。';
	@override String get extDevServerAddress => '服务器地址';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => '连接';
	@override String get extDevServerDisconnect => '断开连接';
	@override String get extDevServerConnecting => '连接中…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '正在提供 ${count} 个扩展：${keys}',
		other: '正在提供 ${count} 个扩展：${keys}',
	);
	@override String get extDevServerDisconnected => '未连接';
	@override String get extDevServerReconnect => '启动时重新连接';
	@override String extDevServerLastReload({required Object key, required Object time}) => '上次重新加载：${key}，于 ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 个扩展构建失败',
		other: '${count} 个扩展构建失败',
	);
	@override String get catalog => '扩展目录';
	@override String get catalogDescription => '从其他服务器读取目录——例如在开发目录本身时使用的本地服务器。留空表示 catalog.ham2k.net。';
	@override String get catalogAddress => '目录地址';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => '目录搜索轨道';
	@override String get catalogSearchStable => '仅稳定版';
	@override String get catalogSearchUnstable => '不稳定版及以上';
	@override String get catalogSearchBleeding => '前沿版及以上';
}

// Path: settings.about
class _Translations$settings$about$zh extends Translations$settings$about$en {
	_Translations$settings$about$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get notices => '通知与消息';
	@override String get noticesDescription => '公告和状态消息';
	@override String get releaseNotes => '发布说明';
	@override String get copiedVersion => '已将版本详情复制到剪贴板';
}

// Path: settings.panels
class _Translations$settings$panels$zh extends Translations$settings$panels$en {
	_Translations$settings$panels$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get settings => '应用偏好设置';
	@override String get settingsDescription => '按您的方式使用应用';
	@override String get commonSettings => '常用偏好设置';
	@override String get syncDescription => '备份日志并在设备间同步';
	@override String get accountsDescription => '服务凭证、离线数据等';
	@override String get extensions => '扩展与功能';
	@override String get extensionsDescription => '活动、竞赛、仪表板面板及更多功能';
	@override String get profilesDescription => '操作员呼号和电台配置文件';
	@override String get stationProfiles => '电台配置文件';
	@override String get developerSettings => '开发者设置';
	@override String get developerSettingsDescription => '调试和开发工具';
	@override String get about => '关于';
	@override String get aboutDescription => '版本、鸣谢和法律信息';
	@override String get unavailableTitle => '部分设置不可用';
	@override String get unavailableText => '扩展运行时启动失败，因此缺少由扩展提供的设置。';
	@override String get station => '电台配置';
	@override String get stationDescription => 'CAT 控制及更多选项';
	@override String get peers => '对等设备';
	@override String get peersDescription => '连接附近的其他设备';
}

// Path: settings.numberFormatOpts
class _Translations$settings$numberFormatOpts$zh extends Translations$settings$numberFormatOpts$en {
	_Translations$settings$numberFormatOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get locale => '跟随系统设置';
	@override String get period => '始终使用句点作为小数点';
	@override String get comma => '始终使用逗号作为小数点';
}

// Path: settings.numberFormatDescription
class _Translations$settings$numberFormatDescription$zh extends Translations$settings$numberFormatDescription$en {
	_Translations$settings$numberFormatDescription$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String locale({required Object separator}) => '系统设置（使用${separator}作为小数点）';
	@override String get period => '始终使用句点作为小数点';
	@override String get comma => '始终使用逗号作为小数点';
}

// Path: settings.numberFormatSeparators
class _Translations$settings$numberFormatSeparators$zh extends Translations$settings$numberFormatSeparators$en {
	_Translations$settings$numberFormatSeparators$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get comma => '逗号';
	@override String get period => '句点';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$zh extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get six => '6 位 (FN31pr)';
	@override String get eight => '8 位 (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$zh extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get six => '6 位';
	@override String get eight => '8 位';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$zh extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get date => '日期';
	@override String get time => '时间';
	@override String get freq => '频率';
	@override String get mode => '模式';
	@override String get call => '呼号';
	@override String get name => '姓名';
	@override String get station => '电台';
	@override String get band => '频段';
	@override String get sent => '发送';
	@override String get rcvd => '接收';
	@override String get grid => '网格';
	@override String get state => '州';
	@override String get country => '国家';
	@override String get refs => '参考';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$zh extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO 日志';
	@override String get qsosDescription => '所选呼号在所有操作中的 QSO。';
	@override String get info => '信息';
	@override String get infoDescription => 'QSO 总数，或所选 QSO 的呼号查询结果。';
	@override String get map => '地图';
	@override String get mapDescription => '所选 QSO 的位置。';
}

// Path: home.logs.import
class _Translations$home$logs$import$zh extends Translations$home$logs$import$en {
	_Translations$home$logs$import$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => '呼号：${calls}';
	@override String get skippedOne => '1 条记录无法读取';
	@override String skippedOther({required Object count}) => '${count} 条记录无法读取';
	@override String get readingTitle => '正在读取 ADIF 文件…';
	@override String get checkingTitle => '正在检查重复…';
	@override String get importingTitle => '正在导入 QSO…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '已检查 ${done} / ${total}';
	@override String importingDetail({required Object imported, required Object total}) => '已导入 ${imported} / ${total}';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$zh extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => '日志和输入字段';
	@override String get infoDescription => '关于正在通联电台的信息';
	@override String get spotsDescription => '来自集群和活动项目的信号';
	@override String get mapDescription => '通联对象的位置';
	@override String get clockDescription => '任意时区的时钟';
	@override String get clockFace => '表盘';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => '指针';
	@override String get clockZone => '时区';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => '此设备';
	@override String get clockShowSeconds => '显示秒';
	@override String get weatherDescription => '您操作地点的当前及未来八小时天气';
	@override String get weatherUseOperationLocation => '使用操作的位置';
	@override String get weatherLocation => '位置';
	@override String get weatherLocationDescription => '网格（FN31pr）或纬度,经度。勾选“使用操作的位置”时忽略此项。';
	@override String get weatherNoLocation => '未设置位置。请在此面板的设置中指定位置，或将其放在有位置的操作中。';
	@override String weatherBadLocation({required Object location}) => '无法读取位置 ${location}。请使用 FN31pr 这样的网格，或 42.36,-71.06。';
	@override String get weatherUnreachable => '无法连接 Open-Meteo——没有网络？稍后将重试。';
	@override String get weatherUnreadable => 'Open-Meteo 有响应，但内容无法读取。稍后将重试。';
	@override String weatherGusts({required Object speed}) => '阵风 ${speed}';
	@override String get panelAgeNow => '刚刚';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 分钟前',
		other: '${count} 分钟前',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '${count} 小时前',
		other: '${count} 小时前',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$zh weatherConditions = _Translations$operation$layout$panels$weatherConditions$zh._(_root);
	@override String get websiteDescription => '在窗格中显示您选择的网页';
	@override String get websiteUrl => '地址';
	@override String get websiteRefresh => '刷新';
	@override String get websiteRefreshNever => '从不';
	@override String get websiteRefresh1 => '每分钟';
	@override String get websiteRefresh5 => '每 5 分钟';
	@override String get websiteRefresh15 => '每 15 分钟';
	@override String get websiteTitle => '面板名称';
	@override String get websiteRefreshNow => '立即刷新';
	@override String get websiteNoUrl => '尚无地址。打开此面板的设置以选择页面。';
	@override String get websiteBadUrl => '这看起来不像网址。必须以 https:// 开头';
	@override String get websiteNotHttps => '此处只能显示 https:// 地址。';
	@override String get websiteUnsupported => '此系统无法在面板中显示网页。';
	@override String get websiteOpenExternally => '在浏览器中打开';
	@override String websiteLoadFailed({required Object reason}) => '无法加载页面：${reason}';
	@override String get remoteScreenDescription => '您的另一台设备共享的屏幕、应用或窗口。';
	@override String get remoteScreenTarget => '屏幕';
	@override String get remoteScreenChoose => '选择屏幕…';
	@override String get remoteScreenPickerTitle => '共享的屏幕';
	@override String get remoteScreenPickerEmpty => '您的设备都没有共享屏幕。请在要查看的设备上，于 设置 → 对等设备 中打开“共享屏幕和窗口”。';
	@override String get remoteScreenUnset => '未选择屏幕。打开此面板的设置，选择您其他设备正在共享的屏幕。';
	@override String get remoteScreenConnecting => '连接中…';
	@override String get remoteScreenPeerAway => '该设备当前未连接。';
	@override String get remoteScreenNotOffered => '该设备已停止共享此屏幕。';
	@override String get remoteScreenNoListener => '该设备无法接受连接——请检查其防火墙。';
	@override String get remoteScreenNoLan => '屏幕只能通过本地网络共享，不支持蓝牙。';
	@override String get remoteScreenRefused => '该设备拒绝共享此屏幕。';
	@override String get remoteScreenSettings => '面板设置';
	@override String get remoteScreenAdjust => '调整视图';
	@override String get remoteScreenDetail => '清晰度';
	@override String get remoteScreenDetailStandard => '标准';
	@override String get remoteScreenDetailHigh => '高';
	@override String get remoteScreenDetailMaximum => '最高';
	@override String get remoteScreenAdjustDone => '确定';
	@override String get remoteScreenZoomIn => '放大';
	@override String get remoteScreenZoomOut => '缩小';
	@override String get remoteScreenStopped => '该屏幕或窗口已不再显示。';
	@override String get remoteScreenCaptureFailed => '该设备无法捕获该屏幕——可能需要“屏幕录制”权限。';
	@override String get remoteScreenNoAnswer => '该设备没有响应，可能未开启屏幕共享。';
	@override String get remoteScreenNoMedia => '无法建立画面连接。请检查此设备的防火墙。';
	@override String get solarDescription => '太阳和地磁状况，以及各频段传播情况';
	@override String get solarUnreachable => '无法连接 hamqsl.com——没有网络？稍后将重试。';
	@override String get solarUnreadable => 'hamqsl.com 有响应，但数据无法使用。稍后将重试。';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => '白天';
	@override String get solarBandNight => '夜间';
	@override String get solarBandGood => '良好';
	@override String get solarBandFair => '一般';
	@override String get solarBandPoor => '较差';
	@override String solarSources({required Object primary, required Object secondary}) => '来源：${primary}、${secondary}';
	@override String get remoteScreenDegraded => '连接不稳定——正在跳帧。';
	@override String get remoteScreenStalled => '画面已停止传输——此连接可能太慢。';
	@override String get radioDescription => '电台前面板——在 CAT 控制下显示频率、模式和功率';
	@override String get radioStyle => '样式';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => '现代';
	@override String get radioRadio => '电台';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — 未指定电台';
	@override String get radioNoRadio => '没有可显示的电台。请在此面板的设置中选择，或在“电台配置”中添加。';
	@override String get radioNotConfigured => '此电台尚未配置。请在“电台配置”中选择其端口或地址。';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => '电台未连接';
	@override String get radioWatts => 'W';
	@override String get radioConnect => '连接此电台';
	@override String get radioDisconnect => '断开此电台';
	@override String get radioStale => '无数据';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR 过高';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$zh extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '使用简易文件名';
	@override String get descriptionOn => '为上传工具准备的简短名称，如 N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => '易读的名称，如 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$zh extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '包含私密信息';
	@override String get descriptionOn => '包含姓名、地址、电子邮件、网格和备注';
	@override String get descriptionOff => '不包含姓名、地址、电子邮件、网格和备注';
	@override String get note => '完整 ADIF 导出始终包含全部内容';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$zh extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => '请先添加电子邮件地址';
	@override String get needsEmailBody => 'Ham2K File Stash 会将文件发送到您 LoFi 账户的电子邮件地址，您也用它登录 stash.ham2k.net。您的账户还没有已确认的地址——请在 设置 › 云同步 中添加。';
	@override String get openSyncSettings => '打开云同步';
	@override String get replaceTitle => '最近的暂存将被替换';
	@override String replaceBody({required Object name}) => '您在不到 6 小时前发送了“${name}”，且尚未被下载。免费账户一次只能保留一个暂存，现在发送会替换它。';
	@override String get replaceConfirm => '仍然发送';
	@override String get failedTitle => '无法发送到 Ham2K File Stash';
	@override String get sentTitle => '已发送到 Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '您可以在任何浏览器中访问 **[stash.ham2k.net](https://stash.ham2k.net)** 来取回此文件。',
		other: '您可以在任何浏览器中访问 **[stash.ham2k.net](https://stash.ham2k.net)** 来取回这些文件。',
	);
	@override String get mayHaveArrived => '暂存服务没有响应——文件可能已经送达。再次发送前请先查看 stash.ham2k.net';
	@override String get notSent => '未发送';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '此文件未送达：',
		other: '这 ${count} 个文件未送达：',
	);
	@override String get emailOffer => '或者为了方便，我们可以给您发送一封包含直接链接的电子邮件。';
	@override String get emailMe => '通过电子邮件给我发送链接';
	@override String get emailSent => '我们已通过电子邮件向您发送下载链接。';
	@override String emailFailed({required Object error}) => '无法发送电子邮件：${error}';
	@override String get freeTier => '免费账户一次只能保留一个暂存文件。订阅者可以按需保留任意数量。';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count,
		one: '已发送 ${count} 个文件到 Ham2K File Stash（stash.ham2k.net）',
		other: '已发送 ${count} 个文件到 Ham2K File Stash（stash.ham2k.net）',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$zh extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get af => '非洲';
	@override String get as => '亚洲';
	@override String get eu => '欧洲';
	@override String get na => '北美洲';
	@override String get oc => '大洋洲';
	@override String get sa => '南美洲';
	@override String get an => '南极洲';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$zh extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '筛选信号';
	@override String get band => '频段';
	@override String get mode => '模式';
	@override String get age => '时效';
	@override String get sources => '来源';
	@override String get continent => '洲';
	@override String get sorting => '排序';
	@override String get sortByTime => '按信号时间';
	@override String get sortByFrequency => '按频率';
	@override String get groupByBand => '按频段分组';
	@override String get groupCallsWithNotes => '将有备注的呼号分组';
	@override String get sourceNoReply => '无响应';
	@override String get sourceError => '错误';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$zh extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '记录面板正忙';
	@override String get editingBody => '您正在编辑一条已记录的通联。改为记录此信号，还是返回完成编辑？';
	@override String get composingBody => '您已开始输入一条通联。改为记录此信号，还是返回完成输入？';
	@override String get goBack => '返回';
	@override String get clearAndLog => '清除并记录信号';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$zh extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '左撇子模式';
	@override String get descriptionOn => '使用左手布局';
	@override String get descriptionOff => '使用右手布局';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$zh extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '国家旗帜';
	@override String get dx => '仅为 DX 通联显示';
	@override String get all => '为所有通联显示旗帜';
	@override String get none => '不显示任何旗帜';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$zh extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get dx => '仅为 DX 通联显示旗帜';
	@override String get all => '为所有通联显示旗帜';
	@override String get none => '不显示任何旗帜';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$zh extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '建议操作员';
	@override String get descriptionOn => '当操作使用不同的电台呼号时，将您的呼号作为操作员建议';
	@override String get descriptionOff => '除非您填写，否则操作员留空';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$zh extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '显示方位';
	@override String get descriptionOn => '显示到台站的预计方位';
	@override String get descriptionOff => '不显示方位信息';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$zh extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '同时显示反向方位';
	@override String get descriptionOn => '同时显示从台站出发的方位，如“45° / 225°”';
	@override String get descriptionOff => '仅显示到台站的方位';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$zh extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '切换信号报告顺序';
	@override String get sentFirst => '先发送，后接收';
	@override String get rcvdFirst => '先接收，后发送';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$zh extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '在填入 RST 后跳转下一个字段';
	@override String get descriptionOn => '输入 RST 后跳转';
	@override String get descriptionOff => '不自动跳转';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$zh extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '默认报告——话音';
	@override String get description => '在 SSB、FM 或 AM 下，发送或接收留空时使用';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$zh extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '默认报告——CW 和数据';
	@override String get description => '在 CW、RTTY 及其他数据模式下，发送或接收留空时使用';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$zh extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '默认报告——FT8 和 FT4';
	@override String get description => '在 FT 模式下，发送或接收留空时使用';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$zh extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '数字行';
	@override String get description => '记录时在键盘上方显示一行数字键';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$zh extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '斜杠和句点键';
	@override String get description => '添加一个随上下文变化的键：呼号时为“/”，数字时为“.”';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$zh extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '按键时振动';
	@override String get description => '点按数字键时提供触感反馈';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$zh extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get off => '已禁用';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$zh extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$zh extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '用 [\'] 控制 PTT';
	@override String get descriptionOn => '在话音模式下，按 [\'] 让电台发射，再按一次 [\'] 停止发射。一分钟后会自动停止发射。';
	@override String get descriptionOff => '[\'] 键不会让电台发射。';
	@override String get pill => 'TX';
	@override String get transmitting => '正在发射';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$zh extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '智能 VFO 吸附';
	@override String get descriptionOn => '停止转动旋钮后，将频率取整到合理步进。仅限话音模式。';
	@override String get descriptionOff => '精确保持在您调谐的位置。';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$zh extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '智能吸附：稳定延迟';
	@override String get description => '旋钮需停止多久后才取整频率。越短越即时；越长越能容纳慢速调谐。';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$zh extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '智能吸附：长距离移动';
	@override String get description => '移动至少这么远时，无论最后多慢，频率都会取整到整 kHz。';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$zh extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '智能吸附：最小移动';
	@override String get description => '移动小于此值时频率不会取整，以便保留微调。';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$zh extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '智能吸附：最慢移动';
	@override String get description => '旋钮转得比这更慢时频率不会取整，除非是长距离移动。';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$zh extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM 关';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => '回车发送消息';
	@override String get off => '关闭';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => '回车发送消息：${state}。点按以更改。';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$zh extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '电键速度';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$zh extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW 电键消息';
	@override String get notSupported => '当前电台不支持 CW 键控';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => '消息 (${n})';
	@override String get labelField => '标签';
	@override String labelKey({required Object n}) => 'F${n} 标签';
	@override String get details => '详情';
	@override String get empty => '（空）';
	@override String get sets => '消息组';
	@override String get newSet => '新建消息组';
	@override String get renameSet => '重命名消息组';
	@override String get deleteSet => '删除消息组';
	@override String get newSetName => '名称';
	@override String get setDefault => '默认';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM 消息';
	@override String get setSaved => '我的消息';
	@override String get repeat => '重复消息 #1';
	@override String get repeatOff => '否';
	@override String repeatAfter({required Object n}) => '${n} 秒后';
	@override String get repeatWait => '重复中';
	@override String get keyboard => '键入发送';
	@override String get keyboardField => '键入发送';
	@override String get closeArea => '关闭电键区域';
	@override String get help => '帮助';
	@override String get helpTitle => '编写 CW 消息';
	@override String get helpIntro => '消息可以使用包含以下值的模板：';
	@override String get helpOpCall => '您的呼号';
	@override String get helpQsoCall => '对方呼号——在 // 堆栈中，为将要记录的呼号';
	@override String get helpQsoFullCall => '对方呼号（如为有效呼号）；部分呼号时为空';
	@override String get helpQsoPartial => '部分呼号；如为完整有效呼号则为空';
	@override String get helpQsoNextCall => '在 // 堆栈中，接下来将被选中记录的呼号（如为有效完整呼号）';
	@override String get helpQsoNextPartial => '在 // 堆栈中，记录当前通联后的下一个部分呼号';
	@override String get helpQsoName => '对方的名字，取自输入内容，否则取自查询结果';
	@override String get helpQsoState => '对方的州，取自输入内容，否则取自查询结果';
	@override String get helpKeyerMsg => '消息 1 在另一条消息中按实际发送的内容展开。适用于消息 1 到 8';
	@override String get helpQsoRst => '您发送的报告';
	@override String get helpQsoSerial => '您的序号，用于需要发送序号的竞赛';
	@override String get helpPad => '用零补足到指定位数：7 发送为 007';
	@override String get helpCut => '简缩数字，T 代表 0，N 代表 9：599 发送为 5NN';
	@override String get helpCutDigits => '在引号中选择要简缩的数字——0 为 T，1 为 A，5 为 E，9 为 N';
	@override String get helpFullExample => '完整示例：';
	@override String get helpExample => '发送 W1AW 5NN TT7';
	@override String get helpEsmIntro => '开启“回车发送消息”后，回车会按功能键发送消息，与 N1MM 相同。ESM 消息组默认包含以下内容：';
	@override String get helpEsmCq => 'Run 模式下，呼号字段为空时按回车呼叫 CQ';
	@override String get helpEsmExchange => '您的交换信息：Run 模式下在对方呼号之后发送，S&P 模式下在对方回应后发送';
	@override String get helpEsmThanks => '致谢，在通联记录后发送：其中的占位符指向下一个通联，而不是本次通联';
	@override String get helpEsmMyCall => 'S&P 模式下，向您回应的电台发送您的呼号';
	@override String get helpEsmHisCall => 'Run 模式下，在交换信息前发送对方呼号';
	@override String get helpEsmAgain => '未抄收到对方任何交换信息时请求重发';
	@override String get helpEsmStackThanks => '建议用于 // 堆栈的 F3：TU 在通联记录后发出，因此先致谢，再呼叫堆栈中的下一个电台并发送您的交换信息，或回询部分呼号（TU KR?）；如果没有剩余，则只发 TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$zh extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '话音电键消息';
	@override String get notSupported => '当前电台不支持话音消息';
	@override String get description => '使用电台的语音存储';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => '语音存储 (${n})';
	@override String get labelField => '标签';
	@override String labelKey({required Object n}) => '语音存储 ${n} 标签';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => '空';
	@override String get notMeasured => '长度未知';
	@override String get playButton => '播放';
	@override String get recordButton => '录制';
	@override String get stopButton => '停止';
	@override String get repeat => '重复消息 #1';
	@override String get repeatOff => '否';
	@override String repeatAfter({required Object n}) => '${n} 秒后';
	@override String recordHelpTitle({required Object model}) => '${model} 说明：';
	@override String namedOnDevice({required Object device}) => '这些存储位于 ${device} 的电台中。其名称和长度归该设备所有。';
	@override String get namedOnRadio => '保存在电台中，电台的其他客户端也能看到。';
	@override String get recordHelpYaesuDvs => '等待电台上出现 [REC] 指示，然后按住 PTT 按钮录制您的消息。松开 PTT 之前，先按本应用中的 STOP 按钮结束录制，以避免多余的咔嗒声。';
	@override String get recordHelpFt891 => '等待 [REC] 指示至少闪烁四次，然后按住 PTT 按钮录制您的消息。松开 PTT 之前，先按本应用中的 STOP 按钮结束录制，以避免多余的咔嗒声。';
	@override String get pill => '语音';
	@override String play({required Object n}) => '播放存储 ${n}';
	@override String get stop => '停止';
	@override String record({required Object n}) => '录制存储 ${n}';
	@override String get stopRecording => '停止录制';
	@override String get playing => '播放中…';
	@override String get recording => '录制中…';
	@override String playingMemory({required Object label}) => '正在播放 ${label}';
	@override String recordingMemory({required Object label}) => '正在录制 ${label}';
	@override String get doubtful => '电台播放了吗？它立即报告为空闲。';
	@override String get recordOnRadio => '必须在电台本身上录制存储。';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$zh extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '避免在信号上零差拍';
	@override String get descriptionOn => '连接电台时，调谐到偏离 CW 信号几 Hz 的位置，这样回应它的人不会都在同一音调上呼叫。';
	@override String get descriptionOff => '精确调谐到信号频率。';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$zh extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '零差拍：规避范围';
	@override String get description => '在信号频率两侧偏离多远。偏移永远不会接近零——那又会成为零差拍。';
}

// Path: settings.map.style
class _Translations$settings$map$style$zh extends Translations$settings$map$style$en {
	_Translations$settings$map$style$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '地图样式';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$zh extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get automatic => '自动';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$zh extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '分享应用使用数据';
	@override String get descriptionOn => '共享使用情况、配置、崩溃和性能数据，帮助我们改进应用';
	@override String get descriptionOff => '保持应用使用数据私密。\nHam2K 团队将无法检测崩溃或其他问题。';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$zh extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get title => '共享操作数据';
	@override String get descriptionOn => '公开并与其他用户共享部分操作数据';
	@override String get descriptionOff => '保持操作数据私密';
}

// Path: settings.station.models
class _Translations$settings$station$models$zh extends Translations$settings$station$models$en {
	_Translations$settings$station$models$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - 通用';
	@override String get icomGeneric => 'Icom - 通用';
	@override String get kenwoodGeneric => 'Kenwood - 通用';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - 通用';
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
	@override String get rigctld => '通过 rigctld 控制的电台';
	@override String get rigctldNodeName => '我的电台（通过 rigctld）';
	@override String get flrig => '通过 flrig 控制的电台';
	@override String get flrigNodeName => '我的电台（通过 flrig）';
	@override String get hrd => '通过 Ham Radio Deluxe® 控制的电台';
	@override String get hrdNodeName => '我的电台（通过 HRD）';
	@override String get n3fjp => '通过 N3FJP 控制的电台';
	@override String get n3fjpNodeName => '我的电台（通过 N3FJP）';
	@override String get commander => '通过 DXLab Commander 控制的电台';
	@override String get commanderNodeName => '我的电台（通过 Commander）';
	@override String get antenna => '天线';
	@override String get key => 'CW 电键';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => '通用电台（占位）';
	@override String get placeholderRadioNodeName => '我的电台';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 同轴开关';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$zh extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get network => '网络/WiFi';
	@override String get usbSerial => 'USB 串口';
	@override String get wifi => '网络/WiFi';
	@override String get bluetoothSerial => '蓝牙串口';
	@override String get placeholder => '占位';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$zh extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get dipole => '偶极天线';
	@override String get vertical => '垂直天线';
	@override String get yagiBeam => '八木 / 定向天线';
	@override String get loop => '环形天线';
	@override String get longWire => '长线 / EFHW';
	@override String get other => '其他';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$zh extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get straight => '手键';
	@override String get sideswiper => '侧摆键';
	@override String get bug => '机械半自动键（Bug）';
	@override String get fullyAutomatic => '全自动电键器';
	@override String get singlePaddle => '单桨键';
	@override String get dualPaddle => '双桨键';
	@override String get computerDriven => '计算机驱动';
	@override String get other => '其他';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$zh extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$zh._(TranslationsZh root) : this._root = root, super.internal(root);

	final TranslationsZh _root; // ignore: unused_field

	// Translations
	@override String get unknown => '未知';
	@override String get sunny => '晴';
	@override String get clear => '晴朗';
	@override String get mainlySunny => '大致晴';
	@override String get mainlyClear => '大致晴朗';
	@override String get partlyCloudy => '局部多云';
	@override String get cloudy => '多云';
	@override String get foggy => '雾';
	@override String get rimeFog => '雾凇';
	@override String get lightDrizzle => '小毛毛雨';
	@override String get drizzle => '毛毛雨';
	@override String get heavyDrizzle => '大毛毛雨';
	@override String get lightFreezingDrizzle => '轻度冻毛毛雨';
	@override String get freezingDrizzle => '冻毛毛雨';
	@override String get lightRain => '小雨';
	@override String get rain => '雨';
	@override String get heavyRain => '大雨';
	@override String get lightFreezingRain => '轻度冻雨';
	@override String get freezingRain => '冻雨';
	@override String get lightSnow => '小雪';
	@override String get snow => '雪';
	@override String get heavySnow => '大雪';
	@override String get snowGrains => '米雪';
	@override String get lightShowers => '小阵雨';
	@override String get showers => '阵雨';
	@override String get heavyShowers => '强阵雨';
	@override String get lightSnowShowers => '小阵雪';
	@override String get snowShowers => '阵雪';
	@override String get thunderstorm => '雷暴';
	@override String get lightThunderstormsWithHail => '轻度雷暴伴冰雹';
	@override String get thunderstormWithHail => '雷暴伴冰雹';
}

/// The flat map containing all translations for locale <zh>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsZh {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => '保存',
			'common.ok' => '确定',
			'common.cancel' => '取消',
			'common.delete' => '删除',
			'common.create' => '创建',
			'common.error' => '错误',
			'common.close' => '关闭',
			'common.done' => '完成',
			'common.callsign' => '呼号',
			'common.clear' => '清除',
			'common.dismiss' => '忽略',
			'common.expand' => '展开',
			'common.collapse' => '收起',
			'onboarding.welcomeTitle' => '欢迎使用 Ham2K Portable Logger！',
			'onboarding.welcomeTitleDesktop' => '欢迎使用 Ham2K Power Logger！',
			'onboarding.welcomeBody' => '请回答几个问题，帮助我们更好地满足您的需求。',
			'onboarding.skip' => '跳过',
			'onboarding.kContinue' => '继续',
			'onboarding.back' => '返回',
			'onboarding.next' => '下一步',
			'onboarding.done' => '完成',
			'onboarding.callsignTitle' => '您的呼号是什么？',
			'onboarding.callsignBody' => '您需要业余无线电操作证书才能用好这个应用',
			'onboarding.callsignLabel' => '操作员呼号',
			'onboarding.alreadyHaveAccount' => '已有账户？',
			'onboarding.foundSiblingTitle' => '链接现有账户？',
			'onboarding.foundSiblingBody' => ({required Object app}) => '我们在此设备上发现了 ${app}。将此应用链接到同一账户，您的呼号和日志就会同步过来。',
			'onboarding.foundPoloBody' => '我们在此设备上发现了旧版 Ham2K Portable Logger。将此应用链接到同一账户，您的呼号和日志就会同步过来。',
			'onboarding.foundSiblingsBody' => '我们在此设备上发现了其他 Ham2K 应用。将此应用链接到其中一个账户，您的呼号和日志就会同步过来。',
			'onboarding.linkWithApp' => ({required Object app}) => '与 ${app} 链接',
			'onboarding.linkWithPolo' => '与旧版中的账户链接',
			'onboarding.setUpFresh' => '全新设置',
			'onboarding.activitiesTitle' => '喜爱的活动',
			'onboarding.activitiesBody' => '您对以下热门激活项目感兴趣吗？',
			'onboarding.activitiesFooter' => '（更多选项请见设置）',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => '数据与隐私',
			'onboarding.consentUsageBody' => '为了帮助我们改进应用，我们希望收集性能、崩溃和应用使用数据。',
			'onboarding.consentUsageLabel' => '分享应用使用数据',
			'onboarding.consentOperationBody' => '某些功能可能会与其他用户共享您的操作数据。您可以随时选择退出。',
			'onboarding.consentOperationLabel' => '共享操作数据',
			'onboarding.finishingSetup' => '正在完成设置——下载参考数据…',
			'startScreen.credits' => '由 KI2D 和朋友们制作',
			'testerOverlay.tape' => '注意：施工中',
			'testerOverlay.warningTitle' => '此应用仍在开发中',
			'testerOverlay.warningBody' => '大多数功能还坑坑洼洼，到处都有绊脚的地方。请定期检查更新。',
			'testerOverlay.whatsNew' => ({required Object build}) => '构建 ${build} 的新内容',
			'testerOverlay.thanks' => '感谢您冒着日志的风险帮助我们改进这个应用！',
			'extensionsPanel.categoryActivity' => '活动',
			'extensionsPanel.categoryContest' => '竞赛',
			'extensionsPanel.categoryLookup' => '呼号查询',
			'extensionsPanel.categorySpots' => '信号来源',
			'extensionsPanel.categoryDashboard' => '仪表板面板',
			'extensionsPanel.categoryOther' => '其他扩展',
			'extensionsPanel.searchHint' => '搜索扩展',
			'extensionsPanel.applying' => '正在应用扩展更改，这可能需要一些时间…',
			'extensionsPanel.noMatches' => '没有与搜索匹配的扩展',
			'extensionsPanel.installFromFile' => '从文件安装…',
			'extensionsPanel.installVersion' => ({required Object version}) => '版本 ${version}',
			'extensionsPanel.canReach' => '此扩展可以连接',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}，通过持续连接',
			'extensionsPanel.canHoldLocalConnection' => '本地网络上的设备，通过持续连接',
			'extensionsPanel.canUseLocation' => '您的位置',
			'extensionsPanel.canReadRadio' => '您的电台，用于读取其频率和模式',
			'extensionsPanel.canControlRadio' => '您的电台，用于控制和发射——调谐、功率、CW、语音存储和 PTT',
			'extensionsPanel.canSetUserAgent' => '以自己的名称向服务器标识自身',
			'extensionsPanel.noCapabilities' => '它不请求应用之外的任何权限。',
			'extensionsPanel.sandboxNote' => '扩展在沙盒中运行：无法访问您的文件，也只能访问此处列出的网络。',
			'extensionsPanel.installAction' => '安装',
			'extensionsPanel.updateAction' => '更新',
			'extensionsPanel.installFailed' => '无法安装该扩展',
			'extensionsPanel.installedBadge' => '已安装',
			'extensionsPanel.uninstallAction' => '移除',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '移除 ${name}？',
			'extensionsPanel.uninstallBody' => '此扩展及其设置将被移除。您的日志不受影响。',
			'extensionsPanel.installedMessage' => ({required Object name}) => '已安装 ${name}',
			'extensionsPanel.installDownloading' => '下载中…',
			'extensionsPanel.installWaiting' => '等待安装…',
			'extensionsPanel.installInstalling' => '安装中…',
			'extensionsPanel.installAwaitingApproval' => '等待您的批准…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} 已在安装中。',
			'extensionsPanel.updatedTo' => ({required Object version}) => '已更新到 ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => '${name} 未完成安装，可能需要重新安装。',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '无法移除 ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => '下载自 ${source}',
			'extensionsPanel.dropHint' => '拖放 .h2kext 扩展文件以安装',
			'extensionsPanel.dropOneOnly' => '一次只能拖放一个扩展。',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} 对该扩展返回了 ${status}。',
			'extensionsPanel.downloadTooLarge' => '该下载文件太大，不可能是扩展。',
			'extensionsPanel.downloadNotSecure' => '该下载被重定向到了不安全的位置。',
			'extensionsPanel.catalogSection' => '目录',
			'extensionsPanel.catalogLoading' => '正在加载目录…',
			'extensionsPanel.catalogUnreachable' => '无法访问目录',
			'extensionsPanel.builtIn' => '内置',
			'extensionsPanel.updateAvailableBadge' => '有可用更新',
			'extensionsPanel.updatesAvailableTitle' => '扩展更新',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => '${name} 有可用更新。',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} 及其他 ${count} 个扩展需要更新。',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} 需要更新。',
			'extensionsPanel.pendingUpdatesSection' => '待更新',
			'extensionsPanel.updateAllAction' => '全部更新',
			'extensionsPanel.updatesUnderWay' => '这些更新已在进行中。',
			'extensionsPanel.updatesNothingLeft' => '您的扩展均为最新版本。',
			'extensionsPanel.updatesNoticeAction' => '更多信息',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '更新 ${count} 个扩展？', other: '更新 ${count} 个扩展？', ), 
			'extensionsPanel.upgradeDoneTitle' => '您的扩展已就绪',
			'extensionsPanel.upgradeDoneBody' => '它们现在来自 Ham2K 扩展目录，因此无需等待应用新版本即可更新。',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => '未升级：${names}。',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => '无法运行：${names}。',
			'extensionsPanel.upgradeDoneRefusedHint' => '它们仍已安装，并在 设置 › 扩展 中有标记——在那里更新即可恢复。',
			'extensionsPanel.upgradeDoneUnservedHint' => '目录中没有它们的直接替代品，请在目录中寻找能覆盖您所用功能的扩展。',
			'extensionsPanel.retiredQp' => 'QSO Party',
			'extensionsPanel.retiredStateparks' => '州立公园活动',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '您有 ${count} 个扩展尚未下载。下次能访问扩展目录时会自动下载。',
			'extensionsPanel.runtimeDeadBody' => '您的扩展无法启动。重启应用应该可以恢复。',
			'extensionsPanel.refusedTitle' => '部分扩展无法运行',
			'extensionsPanel.upgradeBusyTitle' => '仍在设置中',
			'extensionsPanel.upgradeRuntimeDeadTitle' => '您的扩展未在运行',
			'extensionsPanel.restoreTitle' => '您的部分扩展缺失',
			'extensionsPanel.restoreBody' => '您安装的这些扩展不在此设备上。我们可以从 Ham2K 扩展目录重新下载：',
			'extensionsPanel.restoreFromFile' => '从文件安装。请从文件重新安装，或忘记它们：',
			'extensionsPanel.restoreOtherCatalog' => '从其他扩展目录安装，因此此处无法获取：',
			'extensionsPanel.restoreForget' => '忘记',
			'extensionsPanel.restoreInstall' => '安装',
			'extensionsPanel.restoreLater' => '稍后',
			'extensionsPanel.restoreInstalling' => '正在安装您的扩展…',
			'extensionsPanel.restoreDoneTitle' => '您的扩展已恢复',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => '已重新安装：${names}。',
			'extensionsPanel.restorePartialTitle' => '部分扩展无法安装',
			'extensionsPanel.restoreFailed' => ({required Object names}) => '无法安装：${names}。下次打开应用时我们会再次提供。',
			'extensionsPanel.restoreBusyBody' => '应用仍在设置您的扩展。下次打开应用时我们会再次提供这些扩展。',
			'extensionsPanel.restoreRuntimeDeadBody' => '我们已重新安装，但您的扩展无法启动。重启应用应该可以恢复。',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} 已被撤回',
			'extensionsPanel.revokedBody' => '目录撤回了此版本，因此已将其禁用。',
			'extensionsPanel.downloadHashMismatch' => '该下载与目录描述的扩展不符。',
			'extensionsPanel.catalogVersionUnknown' => ({required Object key, required Object version}) => '目录中没有 ${key} 的 ${version} 版本。',
			'extensionsPanel.catalogLinkUnknown' => '该目录链接未指明扩展版本。',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => '目录中没有 ${key} 在该轨道上的发布版本。',
			'extensionsPanel.installFromLink' => '从链接安装',
			'extensionsPanel.unstableReleaseWarning' => '这是不稳定版本，发布者尚未将其定为完成版。它可能运行异常，并将持续接收不稳定版更新。',
			'extensionsPanel.bleedingReleaseWarning' => '这是前沿版本：仍在开发中，可能出错或丢失设置。它将持续接收前沿版更新。',
			'extensionsPanel.channelUnstable' => '不稳定',
			'extensionsPanel.channelBleeding' => '前沿',
			'extensionsPanel.followsUnstable' => '接收不稳定版和稳定版',
			'extensionsPanel.followsBleeding' => '接收前沿版、不稳定版和稳定版',
			'extensionsPanel.followStableAction' => '仅接收稳定版',
			'extensionsPanel.revokedBadge' => '已撤回',
			'extensionsPanel.refusedBadge' => '未加载',
			'extensionsPanel.downloadNotHttps' => '该下载未使用安全连接。',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '无法连接 ${source} 获取该扩展。',
			'extensionsPanel.detailsAction' => '详情',
			'extensionsPanel.installedFromFile' => '从文件安装',
			'extensionsPanel.detailsWhatItDoes' => '提供以下支持',
			'extensionsPanel.installedPreloaded' => '预装',
			'extensionsPanel.hookAccount' => '账户登录',
			'extensionsPanel.hookCallNotes' => '呼号备注',
			'extensionsPanel.hookDataFile' => '离线数据',
			'extensionsPanel.hookExport' => '导出',
			'extensionsPanel.hookLookup' => '呼号查询',
			'extensionsPanel.hookScoring' => '计分',
			'extensionsPanel.hookSpots' => '信号',
			'extensionsPanel.hookHunting' => ({required Object program}) => '猎取 ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => '激活 ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '…还有 ${count} 个扩展', other: '…还有 ${count} 个扩展', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个可用扩展', other: '${count} 个可用扩展', ), 
			'home.title' => 'Portable Logger',
			'home.newOperation' => '新操作',
			'home.stationCallsign' => '电台呼号',
			'home.titleOptional' => '标题（可选）',
			'home.emptyList' => '还没有操作。创建一个即可开始记录。',
			'home.quickLookup' => '快速查询',
			'home.nav.operations' => '操作',
			'home.nav.chase' => '追逐',
			'home.nav.logs' => '日志',
			'home.nav.maps' => '地图',
			'home.nav.settings' => '设置',
			'home.panels.operations' => '操作列表',
			'home.panels.operationsDescription' => '您的操作，最新的在前。',
			'home.panels.version' => '当前版本',
			'home.panels.versionDescription' => 'Ham2K 标志、本应用名称以及您正在运行的构建。',
			'home.toggleNav' => '显示或隐藏导航标签',
			'home.logs.title' => '日志',
			'home.logs.titleFor' => '日志：',
			'home.logs.emptyCallsigns' => '尚未记录 QSO',
			'home.logs.emptyQsos' => ({required Object call}) => '没有 ${call} 的 QSO',
			'home.logs.mapNoSelection' => '选择一个 QSO 以在地图上查看',
			'home.logs.searchHint' => '搜索呼号或姓名',
			'home.logs.noSearchMatches' => '没有与搜索匹配的 QSO',
			'home.logs.titleAll' => '所有日志',
			'home.logs.allCallsigns' => '所有呼号',
			'home.logs.noOperation' => '不属于任何操作',
			'home.logs.unsavedTitle' => '未保存的更改',
			'home.logs.unsavedBody' => '此 QSO 有未保存的更改。',
			'home.logs.pendingDeleteBody' => '此 QSO 已标记为删除。',
			'home.logs.editGone' => '未保存：该 QSO 已不在此日志中。',
			'home.logs.discard' => '放弃',
			'home.logs.columns.date' => '日期',
			'home.logs.columns.time' => '时间',
			'home.logs.columns.freq' => '频率',
			'home.logs.columns.mode' => '模式',
			'home.logs.columns.call' => '呼号',
			'home.logs.columns.name' => '姓名',
			'home.logs.columns.station' => '电台',
			'home.logs.columns.band' => '频段',
			'home.logs.columns.sent' => '发送',
			'home.logs.columns.rcvd' => '接收',
			'home.logs.columns.grid' => '网格',
			'home.logs.columns.state' => '州',
			'home.logs.columns.country' => '国家',
			'home.logs.columns.refs' => '参考',
			'home.logs.panels.qsos' => 'QSO 日志',
			'home.logs.panels.qsosDescription' => '所选呼号在所有操作中的 QSO。',
			'home.logs.panels.info' => '信息',
			'home.logs.panels.infoDescription' => 'QSO 总数，或所选 QSO 的呼号查询结果。',
			'home.logs.panels.map' => '地图',
			'home.logs.panels.mapDescription' => '所选 QSO 的位置。',
			'home.logs.import.callsigns' => ({required Object calls}) => '呼号：${calls}',
			'home.logs.import.skippedOne' => '1 条记录无法读取',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} 条记录无法读取',
			'home.logs.import.readingTitle' => '正在读取 ADIF 文件…',
			'home.logs.import.checkingTitle' => '正在检查重复…',
			'home.logs.import.importingTitle' => '正在导入 QSO…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '已检查 ${done} / ${total}',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '已导入 ${imported} / ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => '追逐',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} 和 ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}、${second} 等',
			'chase.station.title' => '追逐电台',
			'chase.station.stationLabel' => '电台：',
			'chase.station.operatorLabel' => '操作员：',
			'chase.station.noLocation' => '无位置',
			'chase.periodInline.today' => '今天',
			'chase.periodInline.thisWeek' => '本周',
			'chase.periodInline.last14Days' => '过去 14 天',
			'chase.periodInline.thisMonth' => '本月',
			'chase.periodStats.today' => '今日统计',
			'chase.periodStats.thisWeek' => '本周统计',
			'chase.periodStats.last14Days' => '过去 14 天统计',
			'chase.periodStats.thisMonth' => '本月统计',
			'chase.period.today' => '今天',
			'chase.period.thisWeek' => '本周',
			'chase.period.last14Days' => '过去 14 天',
			'chase.period.thisMonth' => '本月',
			'chase.goals.title' => '追逐目标',
			'chase.goals.remove' => ({required Object name}) => '停止追逐 ${name}',
			'chase.goals.extensionsTitle' => '包含追逐功能的扩展',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => '记录控件，下方是该时段内追逐到的 QSO。',
			'chase.panels.info' => '信息',
			'chase.panels.infoDescription' => '正在记录的呼号，或该时段的统计。',
			'chase.panels.spots' => '信号',
			'chase.panels.spotsDescription' => '空中被 Spot 的电台，随时可以追逐。',
			'chase.panels.map' => '地图',
			'chase.panels.mapDescription' => '该时段的 QSO 以及正在记录的电台。',
			'dialogs.operationDetails' => '操作详情',
			'dialogs.activities' => '活动',
			'dialogs.stationCallsign' => '电台呼号',
			'dialogs.multiStationIdentifier' => '多站标识符（仅限数字）',
			'dialogs.notes' => '备注',
			'dialogs.deleteOperationTitle' => '删除操作',
			'dialogs.purgeTestsTitle' => '清除测试操作',
			'dialogs.purgeTestsBody' => '这将永久删除这些测试操作及其 QSO，且无法撤销。',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '另有 ${count} 个不属于任何操作的测试通联。', other: '另有 ${count} 个不属于任何操作的测试通联。', ), 
			'dialogs.purgeTestsAction' => '清除',
			'dialogs.syncAllTitle' => '替换此设备的日志？',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL 会备份并清除此设备上的 ${qsos}，然后从服务器重新下载该账户的日志。备份保留在此设备的数据库中。',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${n} 个 QSO 尚未同步——服务器从未收到，它将无法恢复。', other: '${n} 个 QSO 尚未同步——服务器从未收到，它们将无法恢复。', ), 
			'dialogs.syncAllAction' => '清除并重新同步',
			'dialogs.receivedPurgesTitle' => '已在其他设备上移除的测试操作',
			'dialogs.receivedPurgesBody' => '这些操作已在另一台设备上作为测试操作删除。也在这里移除吗？这将永久删除它们及其 QSO，且无法撤销。',
			'dialogs.receivedPurgesAction' => '移除',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => '无效的呼号：${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => '无效的呼号：${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '目前操作员为 ${previous}。新的通联将记录 ${typed}。',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => '目前没有记录操作员。新的通联将记录 ${typed}。',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => '此操作已有 ${calls} 的通联。${typed} 只会记录到新的通联中。',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '同时将 ${typed} 记录为已记录通联的操作员', other: '同时将 ${typed} 记录为全部 ${count} 个已记录通联的操作员', ), 
			'dialogs.callChange.operatorSeveralStations' => '在空中使用多个电台呼号时，不支持分别设置操作员',
			'dialogs.callChange.contactsUnreadable' => '无法读取此操作的通联，因此在此更改呼号时不会提供更新它们的选项',
			'dialogs.callChange.restampFailed' => ({required Object error}) => '无法更新已记录的通联，因此未做任何更改：${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '已更新 ${written} / ${planned} 个通联——其余的已不在此操作中',
			'operation.deletedReadOnly' => '此操作已删除。取消删除后才能记录或更改。',
			'operation.tabs.qsos' => ({required Object count}) => '${count} 个 QSO',
			'operation.tabs.info' => '信息',
			'operation.tabs.spots' => '信号',
			'operation.tabs.map' => '地图',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => '时钟',
			'operation.tabs.weather' => '天气',
			'operation.tabs.website' => '网站',
			'operation.tabs.remoteScreen' => '远程屏幕',
			'operation.tabs.solar' => '太阳',
			'operation.tabs.radio' => '电台',
			'operation.positions.nobodyYet' => '还没有其他操作位共享此操作。',
			'operation.positions.positionLabel' => ({required Object number}) => '位：${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => '操作员：${call}',
			'operation.positions.unnamedPosition' => '另一个操作位',
			'operation.positions.thisDevice' => '我们的操作位',
			'operation.positions.nameIn' => '，位于 ',
			'operation.positions.panelTitle' => '操作位',
			'operation.positions.panelDescription' => '共享此操作的每个操作位当前正在记录的内容。',
			'operation.stationCallsignNone' => '无电台呼号',
			'operation.titleNone' => '无标题',
			'operation.deleteOperation' => '删除操作',
			'operation.loggingControlsStale' => '活动字段可能已过时——重新打开操作以刷新',
			'operation.locationNone' => '未设置',
			'operation.generalOperation' => '通用操作',
			'operation.titleFor' => ({required Object value}) => '参加 ${value}',
			'operation.titleAt' => ({required Object value}) => '在 ${value}',
			'operation.segmentNow' => ({required Object description}) => '当前 ${description}',
			'operation.testOperationSuffix' => '测试',
			'operation.menu.showRstFields' => '显示 RST 字段',
			'operation.menu.showStateField' => '显示州字段',
			'operation.menu.showGridField' => '显示网格字段',
			'operation.menu.showDeletedQsos' => '显示已删除的 QSO',
			'operation.menu.showDeletedOps' => '显示已删除的操作',
			'operation.menu.showQsoNumbers' => '显示 QSO 编号',
			'operation.menu.lookupAllQsos' => '查询所有 QSO',
			'operation.menu.loggingSettingsTitle' => '记录设置',
			'operation.menu.mapSettingsTitle' => '地图设置',
			'operation.menu.actionsSection' => '操作',
			'operation.layout.title' => '添加面板',
			'operation.layout.availableSection' => '可用面板',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} 设置',
			'operation.layout.panelSettingsAction' => '面板设置',
			'operation.layout.viewName' => '操作视图',
			'operation.layout.viewOptions' => '视图布局选项',
			'operation.layout.viewTitleBuiltIn' => '此视图为应用内置，其名称也是',
			'operation.layout.resetOptions' => '恢复默认',
			'operation.layout.removePane' => '移除',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '将 ${panel} 恢复为默认值？',
			'operation.layout.resetPaneConfirmBody' => '其标题、标题栏和大小将恢复默认，布局的其余部分保持不变。',
			'operation.layout.resetViewConfirm' => '将此视图恢复为默认布局？',
			'operation.layout.resetViewConfirmBody' => '面板将恢复默认排列，视图和每个面板的选项也将恢复默认。',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} 布局设置',
			'operation.layout.paneTitle' => '标题',
			'operation.layout.paneShowHeader' => '显示标题栏',
			'operation.layout.paneShowHeaderTabset' => '此窗格与其他窗格成组时始终显示——需通过标题栏切换到其他窗格',
			'operation.layout.paneInherit' => '与应用相同',
			'operation.layout.searchHint' => '搜索面板',
			'operation.layout.noPanelsMatch' => '没有与搜索匹配的面板。',
			'operation.layout.nothingToAdd' => '此视图已包含所有可用面板',
			'operation.layout.addPanel' => ({required Object panel}) => '添加 ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => '预览 ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => '缺少扩展“${name}”',
			'operation.layout.previewUnavailable' => '无法显示此面板的预览图。',
			'operation.layout.nestedPaneTitle' => '更多',
			'operation.layout.editLayout' => '编辑布局',
			'operation.layout.saveLayout' => '保存布局',
			'operation.layout.revertLayout' => '放弃布局更改',
			'operation.layout.done' => '完成',
			'operation.layout.layoutUnreadableTitle' => '无法读取布局',
			'operation.layout.layoutUnreadableBody' => '无法读取您保存的布局，因此显示默认排列。在您选择保留之前，它不会覆盖您原来的布局。',
			'operation.layout.layoutUnreadableAction' => '使用此布局',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '无法显示 ${panel}',
			'operation.layout.panelRenderRetry' => '重试',
			'operation.layout.panelActionFailed' => '该面板操作失败，请重试。',
			'operation.layout.panels.loggingDescription' => '日志和输入字段',
			'operation.layout.panels.infoDescription' => '关于正在通联电台的信息',
			'operation.layout.panels.spotsDescription' => '来自集群和活动项目的信号',
			'operation.layout.panels.mapDescription' => '通联对象的位置',
			'operation.layout.panels.clockDescription' => '任意时区的时钟',
			'operation.layout.panels.clockFace' => '表盘',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => '指针',
			'operation.layout.panels.clockZone' => '时区',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => '此设备',
			'operation.layout.panels.clockShowSeconds' => '显示秒',
			'operation.layout.panels.weatherDescription' => '您操作地点的当前及未来八小时天气',
			'operation.layout.panels.weatherUseOperationLocation' => '使用操作的位置',
			'operation.layout.panels.weatherLocation' => '位置',
			'operation.layout.panels.weatherLocationDescription' => '网格（FN31pr）或纬度,经度。勾选“使用操作的位置”时忽略此项。',
			'operation.layout.panels.weatherNoLocation' => '未设置位置。请在此面板的设置中指定位置，或将其放在有位置的操作中。',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => '无法读取位置 ${location}。请使用 FN31pr 这样的网格，或 42.36,-71.06。',
			'operation.layout.panels.weatherUnreachable' => '无法连接 Open-Meteo——没有网络？稍后将重试。',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo 有响应，但内容无法读取。稍后将重试。',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => '阵风 ${speed}',
			'operation.layout.panels.panelAgeNow' => '刚刚',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 分钟前', other: '${count} 分钟前', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 小时前', other: '${count} 小时前', ), 
			'operation.layout.panels.weatherConditions.unknown' => '未知',
			'operation.layout.panels.weatherConditions.sunny' => '晴',
			'operation.layout.panels.weatherConditions.clear' => '晴朗',
			'operation.layout.panels.weatherConditions.mainlySunny' => '大致晴',
			'operation.layout.panels.weatherConditions.mainlyClear' => '大致晴朗',
			'operation.layout.panels.weatherConditions.partlyCloudy' => '局部多云',
			'operation.layout.panels.weatherConditions.cloudy' => '多云',
			'operation.layout.panels.weatherConditions.foggy' => '雾',
			'operation.layout.panels.weatherConditions.rimeFog' => '雾凇',
			'operation.layout.panels.weatherConditions.lightDrizzle' => '小毛毛雨',
			'operation.layout.panels.weatherConditions.drizzle' => '毛毛雨',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => '大毛毛雨',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => '轻度冻毛毛雨',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => '冻毛毛雨',
			'operation.layout.panels.weatherConditions.lightRain' => '小雨',
			'operation.layout.panels.weatherConditions.rain' => '雨',
			'operation.layout.panels.weatherConditions.heavyRain' => '大雨',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => '轻度冻雨',
			'operation.layout.panels.weatherConditions.freezingRain' => '冻雨',
			'operation.layout.panels.weatherConditions.lightSnow' => '小雪',
			'operation.layout.panels.weatherConditions.snow' => '雪',
			'operation.layout.panels.weatherConditions.heavySnow' => '大雪',
			'operation.layout.panels.weatherConditions.snowGrains' => '米雪',
			'operation.layout.panels.weatherConditions.lightShowers' => '小阵雨',
			'operation.layout.panels.weatherConditions.showers' => '阵雨',
			'operation.layout.panels.weatherConditions.heavyShowers' => '强阵雨',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => '小阵雪',
			'operation.layout.panels.weatherConditions.snowShowers' => '阵雪',
			'operation.layout.panels.weatherConditions.thunderstorm' => '雷暴',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => '轻度雷暴伴冰雹',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => '雷暴伴冰雹',
			'operation.layout.panels.websiteDescription' => '在窗格中显示您选择的网页',
			'operation.layout.panels.websiteUrl' => '地址',
			'operation.layout.panels.websiteRefresh' => '刷新',
			'operation.layout.panels.websiteRefreshNever' => '从不',
			'operation.layout.panels.websiteRefresh1' => '每分钟',
			'operation.layout.panels.websiteRefresh5' => '每 5 分钟',
			'operation.layout.panels.websiteRefresh15' => '每 15 分钟',
			'operation.layout.panels.websiteTitle' => '面板名称',
			'operation.layout.panels.websiteRefreshNow' => '立即刷新',
			'operation.layout.panels.websiteNoUrl' => '尚无地址。打开此面板的设置以选择页面。',
			'operation.layout.panels.websiteBadUrl' => '这看起来不像网址。必须以 https:// 开头',
			'operation.layout.panels.websiteNotHttps' => '此处只能显示 https:// 地址。',
			'operation.layout.panels.websiteUnsupported' => '此系统无法在面板中显示网页。',
			'operation.layout.panels.websiteOpenExternally' => '在浏览器中打开',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => '无法加载页面：${reason}',
			'operation.layout.panels.remoteScreenDescription' => '您的另一台设备共享的屏幕、应用或窗口。',
			'operation.layout.panels.remoteScreenTarget' => '屏幕',
			'operation.layout.panels.remoteScreenChoose' => '选择屏幕…',
			'operation.layout.panels.remoteScreenPickerTitle' => '共享的屏幕',
			'operation.layout.panels.remoteScreenPickerEmpty' => '您的设备都没有共享屏幕。请在要查看的设备上，于 设置 → 对等设备 中打开“共享屏幕和窗口”。',
			'operation.layout.panels.remoteScreenUnset' => '未选择屏幕。打开此面板的设置，选择您其他设备正在共享的屏幕。',
			'operation.layout.panels.remoteScreenConnecting' => '连接中…',
			'operation.layout.panels.remoteScreenPeerAway' => '该设备当前未连接。',
			'operation.layout.panels.remoteScreenNotOffered' => '该设备已停止共享此屏幕。',
			'operation.layout.panels.remoteScreenNoListener' => '该设备无法接受连接——请检查其防火墙。',
			'operation.layout.panels.remoteScreenNoLan' => '屏幕只能通过本地网络共享，不支持蓝牙。',
			'operation.layout.panels.remoteScreenRefused' => '该设备拒绝共享此屏幕。',
			'operation.layout.panels.remoteScreenSettings' => '面板设置',
			'operation.layout.panels.remoteScreenAdjust' => '调整视图',
			'operation.layout.panels.remoteScreenDetail' => '清晰度',
			'operation.layout.panels.remoteScreenDetailStandard' => '标准',
			'operation.layout.panels.remoteScreenDetailHigh' => '高',
			'operation.layout.panels.remoteScreenDetailMaximum' => '最高',
			'operation.layout.panels.remoteScreenAdjustDone' => '确定',
			'operation.layout.panels.remoteScreenZoomIn' => '放大',
			'operation.layout.panels.remoteScreenZoomOut' => '缩小',
			'operation.layout.panels.remoteScreenStopped' => '该屏幕或窗口已不再显示。',
			'operation.layout.panels.remoteScreenCaptureFailed' => '该设备无法捕获该屏幕——可能需要“屏幕录制”权限。',
			'operation.layout.panels.remoteScreenNoAnswer' => '该设备没有响应，可能未开启屏幕共享。',
			'operation.layout.panels.remoteScreenNoMedia' => '无法建立画面连接。请检查此设备的防火墙。',
			'operation.layout.panels.solarDescription' => '太阳和地磁状况，以及各频段传播情况',
			'operation.layout.panels.solarUnreachable' => '无法连接 hamqsl.com——没有网络？稍后将重试。',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com 有响应，但数据无法使用。稍后将重试。',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => '白天',
			'operation.layout.panels.solarBandNight' => '夜间',
			'operation.layout.panels.solarBandGood' => '良好',
			'operation.layout.panels.solarBandFair' => '一般',
			'operation.layout.panels.solarBandPoor' => '较差',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => '来源：${primary}、${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => '连接不稳定——正在跳帧。',
			'operation.layout.panels.remoteScreenStalled' => '画面已停止传输——此连接可能太慢。',
			'operation.layout.panels.radioDescription' => '电台前面板——在 CAT 控制下显示频率、模式和功率',
			'operation.layout.panels.radioStyle' => '样式',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => '现代',
			'operation.layout.panels.radioRadio' => '电台',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — 未指定电台',
			'operation.layout.panels.radioNoRadio' => '没有可显示的电台。请在此面板的设置中选择，或在“电台配置”中添加。',
			'operation.layout.panels.radioNotConfigured' => '此电台尚未配置。请在“电台配置”中选择其端口或地址。',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => '电台未连接',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => '连接此电台',
			'operation.layout.panels.radioDisconnect' => '断开此电台',
			'operation.layout.panels.radioStale' => '无数据',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR 过高',
			'operation.layout.htmlPanelUnsupported' => '此面板需要网页视图，但此平台不提供',
			'operation.layout.htmlPanelUnsupportedOnWeb' => '此面板需要沙盒，但网页版无法提供',
			'operation.export.title' => '操作导出',
			'operation.export.syncedOperation' => '操作已同步',
			'operation.export.unsyncedOperation' => '操作有未同步的更改',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '本操作中有 ${count} 个 QSO', other: '本操作中有 ${count} 个 QSO', ), 
			'operation.export.qsosSynced' => ({required Object total}) => '全部 ${total} 个 QSO 已同步',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} / ${total} 个 QSO 待同步',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} 个事件标记已同步',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} / ${total} 个事件标记待同步',
			'operation.export.loading' => '正在加载导出选项…',
			'operation.export.noOptions' => '没有可用的导出格式（扩展运行时仍在启动？）',
			'operation.export.nothingLogged' => '暂无可导出的内容——此操作没有 QSO。',
			'operation.export.share' => '分享',
			'operation.export.nothingSelected' => '未选择任何内容',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '保存 ${count} 个文件', other: '保存 ${count} 个文件', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '分享 ${count} 个文件', other: '分享 ${count} 个文件', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '导出 ${count} 个文件', other: '导出 ${count} 个文件', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '下载 ${count} 个文件', other: '下载 ${count} 个文件', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '保存合并的 ${count} 个文件', other: '保存合并的 ${count} 个文件', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '分享合并的 ${count} 个文件', other: '分享合并的 ${count} 个文件', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '导出合并的 ${count} 个文件', other: '导出合并的 ${count} 个文件', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '下载合并的 ${count} 个文件', other: '下载合并的 ${count} 个文件', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => '保存 ${name}',
			'operation.export.shareOne' => ({required Object name}) => '分享 ${name}',
			'operation.export.exportOne' => ({required Object name}) => '导出 ${name}',
			'operation.export.downloadOne' => ({required Object name}) => '下载 ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '暂存 ${count} 个文件', other: '暂存 ${count} 个文件', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '暂存合并的 ${count} 个文件', other: '暂存合并的 ${count} 个文件', ), 
			'operation.export.settingsButton' => '导出设置',
			'operation.export.settingsTitle' => '导出设置',
			'operation.export.compactFileNames.title' => '使用简易文件名',
			'operation.export.compactFileNames.descriptionOn' => '为上传工具准备的简短名称，如 N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => '易读的名称，如 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => '包含私密信息',
			'operation.export.includePrivateData.descriptionOn' => '包含姓名、地址、电子邮件、网格和备注',
			'operation.export.includePrivateData.descriptionOff' => '不包含姓名、地址、电子邮件、网格和备注',
			'operation.export.includePrivateData.note' => '完整 ADIF 导出始终包含全部内容',
			'operation.export.resultTitle' => '导出完成',
			'operation.export.resultFailedTitle' => '导出失败',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已将 ${count} 个文件导出到 ${path}', other: '已将 ${count} 个文件导出到 ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已导出 ${count} 个文件：${path}', other: '已导出 ${count} 个文件：${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已分享 ${count} 个文件', other: '已分享 ${count} 个文件', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已下载 ${count} 个文件', other: '已下载 ${count} 个文件', ), 
			'operation.export.exportFailed' => ({required Object error}) => '导出失败：${error}',
			'operation.export.stash.needsEmailTitle' => '请先添加电子邮件地址',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash 会将文件发送到您 LoFi 账户的电子邮件地址，您也用它登录 stash.ham2k.net。您的账户还没有已确认的地址——请在 设置 › 云同步 中添加。',
			'operation.export.stash.openSyncSettings' => '打开云同步',
			'operation.export.stash.replaceTitle' => '最近的暂存将被替换',
			'operation.export.stash.replaceBody' => ({required Object name}) => '您在不到 6 小时前发送了“${name}”，且尚未被下载。免费账户一次只能保留一个暂存，现在发送会替换它。',
			'operation.export.stash.replaceConfirm' => '仍然发送',
			'operation.export.stash.failedTitle' => '无法发送到 Ham2K File Stash',
			'operation.export.stash.sentTitle' => '已发送到 Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '您可以在任何浏览器中访问 **[stash.ham2k.net](https://stash.ham2k.net)** 来取回此文件。', other: '您可以在任何浏览器中访问 **[stash.ham2k.net](https://stash.ham2k.net)** 来取回这些文件。', ), 
			'operation.export.stash.mayHaveArrived' => '暂存服务没有响应——文件可能已经送达。再次发送前请先查看 stash.ham2k.net',
			'operation.export.stash.notSent' => '未发送',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '此文件未送达：', other: '这 ${count} 个文件未送达：', ), 
			'operation.export.stash.emailOffer' => '或者为了方便，我们可以给您发送一封包含直接链接的电子邮件。',
			'operation.export.stash.emailMe' => '通过电子邮件给我发送链接',
			'operation.export.stash.emailSent' => '我们已通过电子邮件向您发送下载链接。',
			'operation.export.stash.emailFailed' => ({required Object error}) => '无法发送电子邮件：${error}',
			'operation.export.stash.freeTier' => '免费账户一次只能保留一个暂存文件。订阅者可以按需保留任意数量。',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已发送 ${count} 个文件到 Ham2K File Stash（stash.ham2k.net）', other: '已发送 ${count} 个文件到 Ham2K File Stash（stash.ham2k.net）', ), 
			'operation.spots.empty' => '没有符合筛选条件的信号',
			'operation.spots.error' => ({required Object error}) => '加载信号失败：${error}',
			'operation.spots.unknownBand' => '其他',
			'operation.spots.auto' => '自动',
			'operation.spots.autoValue' => ({required Object value}) => '自动（当前 ${value}）',
			'operation.spots.valueAuto' => ({required Object value}) => '${value}（自动）',
			'operation.spots.any' => '任意',
			'operation.spots.allBands' => '所有频段',
			'operation.spots.allModes' => '所有模式',
			'operation.spots.phoneAndCw' => '话音和 CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个信号', other: '${count} 个信号', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => '显示 ${count} / ${total} 个信号',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} 分钟',
			'operation.spots.callsOfNote' => '注意的呼号',
			'operation.spots.yourSpots' => '您的信号',
			'operation.spots.allSpots' => '所有信号',
			'operation.spots.continents.af' => '非洲',
			'operation.spots.continents.as' => '亚洲',
			'operation.spots.continents.eu' => '欧洲',
			'operation.spots.continents.na' => '北美洲',
			'operation.spots.continents.oc' => '大洋洲',
			'operation.spots.continents.sa' => '南美洲',
			'operation.spots.continents.an' => '南极洲',
			'operation.spots.filters.title' => '筛选信号',
			'operation.spots.filters.band' => '频段',
			'operation.spots.filters.mode' => '模式',
			'operation.spots.filters.age' => '时效',
			'operation.spots.filters.sources' => '来源',
			'operation.spots.filters.continent' => '洲',
			'operation.spots.filters.sorting' => '排序',
			'operation.spots.filters.sortByTime' => '按信号时间',
			'operation.spots.filters.sortByFrequency' => '按频率',
			'operation.spots.filters.groupByBand' => '按频段分组',
			'operation.spots.filters.groupCallsWithNotes' => '将有备注的呼号分组',
			'operation.spots.filters.sourceNoReply' => '无响应',
			'operation.spots.filters.sourceError' => '错误',
			'operation.spots.unavailableTitle' => '信号不可用',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} 没有响应。',
			'operation.spots.failedTitle' => '信号来源错误',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} 返回了错误。',
			'operation.spots.slideLogIt' => '记录',
			'operation.spots.slideIgnore' => '忽略',
			'operation.spots.slideRestore' => '恢复',
			'operation.spots.logConflict.title' => '记录面板正忙',
			'operation.spots.logConflict.editingBody' => '您正在编辑一条已记录的通联。改为记录此信号，还是返回完成编辑？',
			'operation.spots.logConflict.composingBody' => '您已开始输入一条通联。改为记录此信号，还是返回完成输入？',
			'operation.spots.logConflict.goBack' => '返回',
			'operation.spots.logConflict.clearAndLog' => '清除并记录信号',
			'operation.import.title' => '将数据导入操作',
			'operation.import.importAdifAction' => '从 ADIF 导入 QSO',
			'operation.import.settingsButton' => '监听设置',
			'operation.import.settingsTitle' => '监听其他应用',
			'operation.import.protocolAddressLabel' => '地址',
			'operation.import.protocolPortLabel' => '端口',
			'operation.import.protocolPortInvalid' => '请输入 1 到 65535 之间的端口',
			'operation.import.protocolAddressInvalid' => '请输入有效的 IP 地址（如 127.0.0.1 或 239.239.0.2）',
			'operation.import.protocolStatusReceiving' => '正在接收数据',
			'operation.import.protocolStatusNoData' => '最近没有收到数据',
			'operation.import.protocolBindError' => ({required Object error}) => '无法开始监听：${error}',
			'operation.import.captureFailed' => ({required Object error}) => '传入的 QSO 无法保存，正在重试：${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => '任意（广播）',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Broadcast Data 选项卡 → 勾选通联信息的 "Enable Broadcasts"。如在同一台计算机上运行，将 IP 地址设为 127.0.0.1；如要在当前本地网络上广播，设为 255.255.255.255。',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reporting 选项卡 → UDP Server 部分 → 勾选 "Accept UDP requests"。如在同一台计算机上运行，将 UDP Server 设为 127.0.0.1，或设为组播地址（如 239.239.0.2），并在本应用上方的配置中使用相同地址。',
			'operation.import.listenTitle' => '监听来自其他应用的 QSO',
			'operation.import.listenDescriptionOnN1mm' => '正在监听 N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => '正在监听 WSJT-X',
			'operation.import.listenDescriptionOnBoth' => '正在监听 N1MM+ 和 WSJT-X',
			'operation.import.listenDescriptionOff' => '关闭',
			'operation.import.addToOperationTitle' => '添加到此操作',
			'operation.import.addToOperationDescriptionOn' => '捕获的 QSO 到达时即添加到此操作',
			'operation.import.addToOperationDescriptionOff' => '捕获的 QSO 将保留，直到您开启此项',
			'operation.import.pendingSectionTitle' => '已捕获的 QSO',
			'operation.import.pendingEmpty' => '尚未捕获任何内容',
			'operation.import.stationMismatch' => ({required Object call}) => '记录为 ${call}，而不是此操作的电台',
			'operation.import.discardAction' => '放弃',
			'operation.import.gapDialogTitle' => '包含更早的捕获？',
			'operation.import.gapDialogBody' => ({required Object count}) => '在数据中断之前还捕获了 ${count} 个 QSO。也包含它们吗？',
			'operation.import.gapDialogRecentOnly' => '仅最近的',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => '全部包含 ${count} 个',
			'map.outlineIssue.link' => '有问题？',
			'map.outlineIssue.title' => '报告轮廓问题',
			'map.outlineIssue.reference' => '哪个轮廓',
			'map.outlineIssue.severity' => '问题有多严重？',
			'map.outlineIssue.minor' => '小瑕疵',
			'map.outlineIssue.major' => '严重问题',
			'map.outlineIssue.explanation' => '有什么问题？',
			'map.outlineIssue.explanationHint' => '轮廓哪里有误，在什么位置',
			'map.outlineIssue.send' => '发送',
			'map.outlineIssue.sending' => '正在发送您的报告——谢谢',
			'map.outlineIssue.copy' => '复制报告',
			'map.outlineIssue.notSent' => '无法发送报告',
			'map.outlineIssue.copied' => '报告已复制',
			'map.outlineIssue.notCopied' => '无法复制报告',
			'map.outlinesDisclaimer' => '轮廓仅供参考，请自行核实！',
			'map.outlinesCredit' => ({required Object sources}) => '轮廓：${sources}',
			'map.boundariesCredit' => ({required Object sources}) => '行政边界：${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => '设施：${sources}',
			'map.fullCredits' => '完整数据来源',
			'map.fewerCredits' => '更少来源',
			'map.emptyState' => '还没有 QSO 位置。\n带有网格、州或国家的 QSO 会显示在这里。',
			'map.unavailable' => '地图目前不可用。',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH：${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => '平面',
			'map.globe' => '地球仪',
			'map.zoomIn' => '放大',
			'map.zoomOut' => '缩小',
			'map.postcard.button' => '操作明信片',
			'map.postcard.title' => ({required Object title}) => '${title} 的明信片',
			'map.postcard.portrait' => '纵向',
			'map.postcard.landscape' => '横向',
			'map.postcard.square' => '方形',
			'map.postcard.save' => '保存…',
			'map.postcard.download' => '下载',
			'map.postcard.share' => '分享',
			'map.postcard.copy' => '复制',
			'map.postcard.copied' => '已复制到剪贴板',
			'map.postcard.saved' => ({required Object path}) => '已保存到 ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '已下载 ${name}',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '已将 ${count} 张图片保存到 ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '已保存 ${names}',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error}——${names} 已经保存',
			'map.postcard.downloadedMany' => ({required Object count}) => '正在下载 ${count} 张图片——如浏览器询问，请允许',
			'map.postcard.mapLeftOut' => '地图未加载，因此已省略',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome}——地图未加载，因此已省略',
			'map.postcard.continued' => ({required Object title}) => '${title}（续）',
			'map.postcard.previousPage' => '上一页',
			'map.postcard.nextPage' => '下一页',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => '第 ${page} / ${count} 页',
			'map.postcard.sectionDays' => '每天',
			'map.postcard.reset' => '重置',
			'map.postcard.failed' => ({required Object error}) => '无法制作明信片：${error}',
			'map.postcard.mapNotReady' => '地图未加载完成。请检查网络连接后重试。',
			'map.postcard.saveFailed' => ({required Object error}) => '无法保存明信片：${error}',
			'map.postcard.copyFailed' => '剪贴板未接收图片，请重试。',
			'map.postcard.shareFailed' => '无法分享明信片，请重试。',
			'map.postcard.fileName' => 'postcard',
			'mapsView.title' => '地图',
			'mapsView.searchHint' => '搜索公园、山峰等',
			'mapsView.activities' => '活动',
			'mapsView.layers' => '图层',
			'mapsView.baseMap' => '底图',
			'mapsView.satellite' => '卫星影像 (Esri)',
			'mapsView.facilities' => '公园设施',
			'mapsView.boundaries' => '行政边界',
			'mapsView.currentLocation' => '当前位置',
			'mapsView.noMatches' => ({required Object text}) => '没有与“${text}”匹配的内容',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${where} 处的 ${count} 个参考', other: '${where} 处的 ${count} 个参考', ), 
			'mapsView.startOperation' => '用这些参考开始操作',
			'activitiesView.title' => '活动',
			'activitiesView.activitiesCountZero' => '未选择活动',
			'activitiesView.activitiesCountOne' => '1 个活动',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} 个活动',
			'activitiesView.empty' => '还没有活动——使用下方的建议和搜索来添加',
			'activitiesView.removeActivity' => '移除',
			'activitiesView.openReferenceLink' => ({required Object name}) => '打开 ${name}',
			'activitiesView.editActivity' => '编辑活动',
			'activitiesView.manageExtensions' => '管理扩展',
			'activitiesView.manage' => '管理',
			'activitiesView.activitiesTitle1' => ({required Object first}) => '活动类型：${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => '活动类型：${first} 和 ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => '活动类型：${first}、${second} 及其他 ${more} 个',
			'activitiesView.reference' => '参考',
			'activitiesView.invalidReference' => '无效',
			'activitiesView.duplicateReference' => '已添加',
			'activitiesView.searchHint' => '按名称、参考编号或其他内容搜索…',
			'activitiesView.noSuggestions' => '无匹配项',
			'activitiesView.noSuggestionsHint' => '在上方按参考名称或编号搜索',
			'activitiesView.noSuggestionsExample' => '（例如“trail”或“4556”）',
			'activitiesView.allOptions' => '活动类型',
			'activitiesView.determiningLocation' => '正在确定当前位置…\n等待 GPS 定位以查找附近的参考',
			'activitiesView.locationUnavailableTitle' => '位置数据不可用',
			'activitiesView.locationDeniedTitle' => '位置权限被拒绝',
			'activitiesView.locationBlockedTitle' => '位置权限被阻止',
			'activitiesView.noNearbyReason' => '无法确定附近的参考',
			'activitiesView.locationManualHint' => ({required Object icon}) => '点按 ${icon} 手动输入位置，\n或直接按名称搜索参考',
			'activitiesView.locationGrantAction' => '允许访问位置',
			'activitiesView.locationSettingsAction' => '打开设置',
			'activitiesView.locationSettingsUnavailable' => '请在系统设置中允许访问位置',
			'activitiesView.locationGrantRefused' => '仍无法获取位置——系统再次拒绝',
			'activitiesView.searchUnavailableTitle' => '活动搜索不可用',
			'activitiesView.searchUnavailableReason' => '没有活动扩展能执行此搜索。请稍后重试。',
			'activitiesView.emptySheet' => '使用下方的建议和搜索来添加',
			'activitiesView.exports' => '导出',
			'activitiesView.exportLogs' => '导出日志',
			'activitiesView.tools' => '工具',
			'activitiesView.toolsTitle' => '操作工具',
			'activitiesView.operationDetails' => '操作详情',
			'activitiesView.share' => '分享',
			'activitiesView.archive' => '归档',
			'activitiesView.deleteOperation' => '删除操作',
			'activitiesView.undeleteOperation' => '取消删除操作',
			'activitiesView.alreadySelected' => '已选择',
			'activitiesView.selected' => '已选',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} / ${count}',
			'activitiesView.previousPick' => '上一个匹配',
			'activitiesView.nextPick' => '下一个匹配',
			'activitiesView.retiredReference' => '已停用',
			'activitiesView.enableExtension' => ({required Object name}) => '启用 ${name}',
			'activitiesView.enableExtensionHint' => '此扩展与您的搜索匹配，但当前未启用',
			'activitiesView.enableExtensionForRefHint' => '此扩展处理此操作的某个参考，但当前未启用',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} 未在运行',
			'activitiesView.extensionNotRunningHint' => '此扩展已被禁用，请打开扩展设置了解详情',
			'activitiesView.installExtension' => ({required Object name}) => '安装 ${name}',
			'activitiesView.installExtensionHint' => '此扩展与您的搜索匹配，但尚未安装',
			'activitiesView.onlyCatalogMatches' => '无匹配项\n目录中的某些扩展可能有结果。\n请在下方的活动类型中安装。',
			'activitiesView.setupUnavailable' => '无法加载此活动的设置——请从“管理”重试',
			'activitiesView.controlsUnavailableTitle' => '活动控件不可用',
			'activitiesView.controlsUnavailableReason' => '您的参考是安全的，但目前无法编辑。',
			'activitiesView.controlsUnavailableRetry' => '重试',
			'activitiesView.onlyDisabledMatches' => '无匹配项\n某些可用扩展可能有结果。\n请在下方的活动类型中启用。',
			'activitiesView.onlyNotRunningMatches' => '无匹配项\n某些可能有结果的扩展未在运行。\n请查看下方的活动类型。',
			'activitiesView.mapToggle' => '地图',
			'activitiesView.searchToggle' => '搜索',
			'activitiesView.addToOperation' => '添加到操作',
			'activitiesView.addToOperationShort' => '添加',
			'activitiesView.mapEmptyState' => '没有可在地图上显示的结果',
			'activitiesView.mapEmptyStateHint' => '切换回列表，或搜索其他内容',
			'activitiesView.imports' => '导入',
			'loggingControls.timeUtc' => '时间 (UTC)',
			'loggingControls.date' => '日期',
			'loggingControls.now' => '现在',
			'loggingControls.frequency' => '频率',
			'loggingControls.mode' => '模式',
			'loggingControls.theirCall' => '对方呼号',
			'loggingControls.noteField' => '备注',
			'loggingControls.todoField' => '待办',
			'loggingControls.sent' => '发送',
			'loggingControls.rcvd' => '接收',
			'loggingControls.more' => '更多',
			'loggingControls.revert' => '恢复',
			'loggingControls.undoDelete' => '撤销删除',
			'loggingControls.restore' => '还原',
			'loggingControls.wipe' => '清空',
			'loggingControls.undo' => '撤销',
			'loggingControls.pendingDeleteTapWarning' => '再点按一次垃圾桶即可删除此 QSO',
			'loggingControls.pendingDeleteClickWarning' => '再点击一次垃圾桶即可删除此 QSO',
			'loggingControls.deletedQsoWarning' => '已删除 QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => '再点按一次垃圾桶即可删除此${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => '再点击一次垃圾桶即可删除此${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '已删除${kind}',
			'loggingControls.timeControl' => '时间',
			'loggingControls.radioControl' => '电台',
			'loggingControls.powerControl' => '功率',
			'loggingControls.notesControl' => '备注',
			'loggingControls.power' => '功率',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => '记录控件',
			'loggingControls.spottingControl' => 'Spot',
			'loggingControls.spottingSelfControl' => '自我 Spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => '在 ${freq} 自我 Spot',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot ${call} 于 ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Spot ${call} 为时已晚',
			'loggingControls.spotNoFreq' => '请先设置要 Spot 的频率',
			'loggingControls.spotComment' => '评论',
			'loggingControls.bandOrFreqRequired' => '记录前请设置频率或频段',
			'loggingControls.missingBand' => '无频段',
			'loggingControls.missingMode' => '无模式',
			'loggingControls.saveFailed' => ({required Object error}) => '无法保存：${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => '无法删除：${error}',
			'loggingControls.info.noQsos' => '尚未有 QSO… 让我们开始上线吧！',
			'loggingControls.info.qsoCountOne' => '1 个 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} 个 QSO',
			'loggingControls.info.qsosInTime' => ({required Object time, required Object count}) => '${time} 内 ${count} 个',
			'loggingControls.info.sinceLast' => ({required Object time}) => '距离上次 ${time}',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '最近 10 个：${rate} Q/h',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '最近 100 个：${rate} Q/h',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '相距 ${distance}，位于',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°），位于',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°），位于',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '相距 ${distance}',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°）',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°）',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}：${notice}',
			'loggingControls.info.noticeDupe' => '重复！',
			'loggingControls.info.noticeNewBand' => '新频段',
			'loggingControls.info.noticeNewMode' => '新模式',
			'loggingControls.info.noticeNewDXCC' => '新 DXCC',
			'loggingControls.info.noticeNewState' => '新州',
			'loggingControls.info.noticeNewProvince' => '新省',
			'loggingControls.info.noticeNewDay' => '新的一天',
			'loggingControls.info.noticeNewRef' => '新参考',
			'loggingControls.info.noticeNewMult' => '新倍数',
			'loggingControls.info.noticeNewZone' => '新分区',
			'loggingControls.info.noticeInvalidMode' => '模式错误',
			'loggingControls.info.noticeInvalidBand' => '频段错误',
			'loggingControls.info.noticeInvalidCategory' => '不可通联',
			'loggingControls.info.noticeWorkedBefore' => '曾通联',
			'loggingControls.info.noticeNewPark' => '新公园',
			'loggingControls.info.noticeNewSection' => '新分部',
			'loggingControls.info.noticeBonusStation' => '奖励电台！',
			'loggingControls.info.noticeMissingExchange' => '无交换',
			'loggingControls.info.noticeInvalidExchange' => '交换错误',
			'loggingControls.info.noticeUnknownEvent' => '未知活动',
			'loggingControls.info.noticeOurGrid' => '设置我方网格',
			'loggingControls.info.noticeRareCounty' => '稀有县！',
			'loggingControls.info.noticeOurLocation' => '设置我方县',
			'loggingControls.info.noticeShortGrid' => '网格太短',
			'formChrome.untitled' => '（无标题）',
			'formChrome.showMore' => '显示更多',
			'formChrome.showAll' => '显示全部',
			'formChrome.showFewer' => '显示更少',
			'formChrome.defaults' => '默认',
			'formChrome.search' => '搜索',
			'formChrome.clear' => '清除',
			'formChrome.openPage' => '打开页面',
			'formChrome.connected' => '已连接',
			'formChrome.notConnected' => '未连接',
			'formChrome.manage' => '管理',
			'formChrome.connect' => '连接',
			'formChrome.formTitle' => '表单',
			'formChrome.addItem' => ({required Object label}) => '添加${label}',
			'formChrome.editItem' => ({required Object label}) => '编辑${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => '显示 ${shown} / ${total}（已选 ${selected} 个）',
			'formChrome.validationError' => ({required Object error}) => '验证错误：${error}',
			'formChrome.transformationError' => ({required Object error}) => '转换错误：${error}',
			'formChrome.actionError' => ({required Object error}) => '错误：${error}',
			'formChrome.removeItem' => '移除',
			'formChrome.storageUnavailable' => '登录信息不可用',
			'qsoEditForm.title' => '编辑 QSO',
			'qsoEditForm.operatorCall' => '操作员',
			'qsoEditForm.position' => '操作位',
			'qsoEditForm.theirName' => '姓名',
			'qsoEditForm.theirGrid' => '网格',
			'qsoEditForm.theirState' => '州',
			'qsoEditForm.band' => '频段',
			'qsoEditForm.notes' => '备注',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => '对方信息',
			'qsoEditForm.sectionOur' => '我方信息',
			'qsoEditForm.sectionNotes' => '备注',
			'qsoEditForm.theirCity' => '城市',
			'qsoEditForm.theirCounty' => '县',
			'qsoEditForm.theirEntity' => '实体',
			'qsoEditForm.theirCqZone' => 'CQ 区',
			'qsoEditForm.theirItuZone' => 'ITU 区',
			'qsoEditForm.theirArrlSection' => 'ARRL 分部',
			'qsoEditForm.theirLat' => '纬度',
			'qsoEditForm.theirLon' => '经度',
			'qsoEditForm.theirPower' => '对方功率',
			'qsoList.empty' => '还没有 QSO——去联络吧！',
			'qsoList.bandOrModeWarning' => '请确认您的频段和模式正确',
			'qsoList.today' => '今天',
			'qsoList.yesterday' => '昨天',
			'qsoList.tomorrow' => '明天',
			'loggingPanel.stats' => '操作统计',
			'loggingPanel.scoring' => '计分',
			'loggingPanel.dxccEntities' => 'DXCC 实体',
			'loggingPanel.statesWorked' => '州',
			'loggingPanel.provincesWorked' => '省',
			'loggingPanel.duplicates' => '重复',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => '显示图片',
			'callInfo.imageUnavailable' => '照片不可用',
			'callInfo.photo' => '照片',
			'callInfo.notes' => '备注',
			'callInfo.distanceTo' => ({required Object distance}) => '相距 ${distance}，位于',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°），位于',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°），位于',
			'callInfo.distanceAway' => ({required Object distance}) => '相距 ${distance}',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '相距 ${distance}（${bearing}°）',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '相距 ${distance}（${bearing}° / ${reverse}°）',
			'callInfo.thisOpCountOne' => '本操作中有 1 个 QSO',
			'callInfo.thisOpCountOther' => ({required Object count}) => '本操作中有 ${count} 个 QSO',
			'callInfo.otherOpsCountOne' => '其他操作中有 1 个 QSO',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '其他操作中有 ${count} 个 QSO',
			'callInfo.andMore' => ({required Object count}) => '…还有 ${count} 条',
			'callInfo.withCall' => ({required Object call}) => '与 ${call}',
			'callInfo.fromOperation' => ({required Object where}) => '来自 ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '过去 7 天内有 ${n} 条',
			'callInfo.history.today' => ({required Object n}) => '今天有 ${n} 条',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${n} 个 QSO', other: '${n} 个 QSO', ), 
			'settings.title' => '设置',
			'settings.language' => '语言',
			'settings.languageSystem' => ({required Object language}) => '跟随系统设置 (${language})',
			'settings.theme.title' => '主题模式',
			'settings.theme.system' => '跟随系统设置',
			'settings.theme.light' => '明亮',
			'settings.theme.dark' => '黑暗',
			'settings.themeDescription.system' => '正在跟随系统设置',
			'settings.themeDescription.light' => '保持明亮模式',
			'settings.themeDescription.dark' => '保持黑暗模式',
			'settings.fontScale' => '字体缩放',
			'settings.fontScaleOpts.smallestMinusMinus' => '最小--',
			'settings.fontScaleOpts.smallestMinus' => '最小-',
			'settings.fontScaleOpts.smallest' => '最小',
			'settings.fontScaleOpts.smaller' => '更小',
			'settings.fontScaleOpts.normal' => '正常',
			'settings.fontScaleOpts.larger' => '更大',
			'settings.fontScaleOpts.largest' => '最大',
			'settings.fontScaleOpts.largestPlus' => '最大+',
			'settings.fontScaleOpts.largestPlusPlus' => '最大++',
			'settings.keepDeviceAwake.title' => '保持设备唤醒',
			'settings.keepDeviceAwake.descriptionOn' => '在记录视图中或同步进行时保持唤醒',
			'settings.keepDeviceAwake.descriptionOff' => '照常休眠',
			'settings.layoutDensity' => '布局密度',
			'settings.layoutDensityOpts.auto' => '自动',
			'settings.layoutDensityOpts.densest' => '最紧凑',
			'settings.layoutDensityOpts.dense' => '紧凑',
			'settings.layoutDensityOpts.normal' => '正常',
			'settings.layoutDensityOpts.sparse' => '宽松',
			'settings.layoutDensityOpts.sparsest' => '最宽松',
			'settings.layoutDensityClamped' => ({required Object effective}) => '窗口太矮，正在使用${effective}',
			'settings.layoutDensityAtLimit' => '已达极限',
			'settings.distanceUnits' => '距离单位',
			'settings.distanceUnitsOpts.kilometers' => '公里',
			'settings.distanceUnitsOpts.miles' => '英里',
			'settings.userInterface' => '用户界面',
			'settings.logging.title' => '记录',
			'settings.logging.leftieMode.title' => '左撇子模式',
			'settings.logging.leftieMode.descriptionOn' => '使用左手布局',
			'settings.logging.leftieMode.descriptionOff' => '使用右手布局',
			'settings.logging.countryFlags.title' => '国家旗帜',
			'settings.logging.countryFlags.dx' => '仅为 DX 通联显示',
			'settings.logging.countryFlags.all' => '为所有通联显示旗帜',
			'settings.logging.countryFlags.none' => '不显示任何旗帜',
			'settings.logging.countryFlagsDescription.dx' => '仅为 DX 通联显示旗帜',
			'settings.logging.countryFlagsDescription.all' => '为所有通联显示旗帜',
			'settings.logging.countryFlagsDescription.none' => '不显示任何旗帜',
			'settings.logging.suggestDefaultOperator.title' => '建议操作员',
			'settings.logging.suggestDefaultOperator.descriptionOn' => '当操作使用不同的电台呼号时，将您的呼号作为操作员建议',
			'settings.logging.suggestDefaultOperator.descriptionOff' => '除非您填写，否则操作员留空',
			'settings.logging.showBearing.title' => '显示方位',
			'settings.logging.showBearing.descriptionOn' => '显示到台站的预计方位',
			'settings.logging.showBearing.descriptionOff' => '不显示方位信息',
			'settings.logging.showReverseBearing.title' => '同时显示反向方位',
			'settings.logging.showReverseBearing.descriptionOn' => '同时显示从台站出发的方位，如“45° / 225°”',
			'settings.logging.showReverseBearing.descriptionOff' => '仅显示到台站的方位',
			'settings.logging.switchSentRcvd.title' => '切换信号报告顺序',
			'settings.logging.switchSentRcvd.sentFirst' => '先发送，后接收',
			'settings.logging.switchSentRcvd.rcvdFirst' => '先接收，后发送',
			'settings.logging.jumpAfterRST.title' => '在填入 RST 后跳转下一个字段',
			'settings.logging.jumpAfterRST.descriptionOn' => '输入 RST 后跳转',
			'settings.logging.jumpAfterRST.descriptionOff' => '不自动跳转',
			'settings.logging.defaultReport.title' => '默认报告——话音',
			'settings.logging.defaultReport.description' => '在 SSB、FM 或 AM 下，发送或接收留空时使用',
			'settings.logging.defaultReportCW.title' => '默认报告——CW 和数据',
			'settings.logging.defaultReportCW.description' => '在 CW、RTTY 及其他数据模式下，发送或接收留空时使用',
			'settings.logging.defaultReportFT8.title' => '默认报告——FT8 和 FT4',
			'settings.logging.defaultReportFT8.description' => '在 FT 模式下，发送或接收留空时使用',
			'settings.logging.numbersRow.title' => '数字行',
			'settings.logging.numbersRow.description' => '记录时在键盘上方显示一行数字键',
			'settings.logging.numbersRowExtra.title' => '斜杠和句点键',
			'settings.logging.numbersRowExtra.description' => '添加一个随上下文变化的键：呼号时为“/”，数字时为“.”',
			'settings.logging.numbersRowVibrate.title' => '按键时振动',
			'settings.logging.numbersRowVibrate.description' => '点按数字键时提供触感反馈',
			'settings.logging.bands' => '首选频段',
			'settings.logging.modes' => '首选模式',
			'settings.catServer.title' => 'CAT 服务器',
			'settings.catServer.description' => '允许其他应用（WSJT-X、日志软件等）通过 Ham2K Logger 控制电台。',
			'settings.catServer.protocol' => '协议',
			'settings.catServer.protocolOpts.off' => '已禁用',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => '端口',
			'settings.catServer.openAccess' => '开放访问',
			'settings.catServer.openAccessOn' => '本地网络上的任何计算机都可以连接。',
			'settings.catServer.openAccessOff' => '只有本计算机上的应用可以连接。',
			'settings.catServer.off' => '关闭。',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}，启动中…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} 在端口 ${port} 上。已连接客户端：${clients}。',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} 在端口 ${port} 上，但没有连接主 VFO 电台。',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} 无法在端口 ${port} 上监听：${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} 无法在端口 ${port} 上监听：另一个程序正在使用它，通常是 ${protocol} 本身。请关闭该程序或选择其他端口。',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} 无法在端口 ${port} 上监听：此计算机不允许。请选择 1024 以上的端口。',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} 已停止在端口 ${port} 上监听。正在重试…',
			'settings.radio.title' => 'CAT 控制',
			_ => null,
		} ?? switch (path) {
			'settings.radio.loggingAndCat' => '记录与 CAT',
			'settings.radio.tuningSection' => '调谐',
			'settings.radio.keyerSection' => '电键',
			'settings.radio.servicesSection' => '服务',
			'settings.radio.stationConfigurationSection' => '电台配置',
			'settings.radio.moreSettings' => '更多电台配置设置',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => '用 [\'] 控制 PTT',
			'settings.radio.pttKey.descriptionOn' => '在话音模式下，按 [\'] 让电台发射，再按一次 [\'] 停止发射。一分钟后会自动停止发射。',
			'settings.radio.pttKey.descriptionOff' => '[\'] 键不会让电台发射。',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => '正在发射',
			'settings.radio.smartVfoSnap.title' => '智能 VFO 吸附',
			'settings.radio.smartVfoSnap.descriptionOn' => '停止转动旋钮后，将频率取整到合理步进。仅限话音模式。',
			'settings.radio.smartVfoSnap.descriptionOff' => '精确保持在您调谐的位置。',
			'settings.radio.snapDebounce.title' => '智能吸附：稳定延迟',
			'settings.radio.snapDebounce.description' => '旋钮需停止多久后才取整频率。越短越即时；越长越能容纳慢速调谐。',
			'settings.radio.snapLongMove.title' => '智能吸附：长距离移动',
			'settings.radio.snapLongMove.description' => '移动至少这么远时，无论最后多慢，频率都会取整到整 kHz。',
			'settings.radio.snapMinMove.title' => '智能吸附：最小移动',
			'settings.radio.snapMinMove.description' => '移动小于此值时频率不会取整，以便保留微调。',
			'settings.radio.snapMinSpeed.title' => '智能吸附：最慢移动',
			'settings.radio.snapMinSpeed.description' => '旋钮转得比这更慢时频率不会取整，除非是长距离移动。',
			'settings.radio.enterSends.pillOff' => 'ESM 关',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => '回车发送消息',
			'settings.radio.enterSends.off' => '关闭',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => '回车发送消息：${state}。点按以更改。',
			'settings.radio.keyerSpeed.title' => '电键速度',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW 电键消息',
			'settings.radio.cwMessages.notSupported' => '当前电台不支持 CW 键控',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => '消息 (${n})',
			'settings.radio.cwMessages.labelField' => '标签',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n} 标签',
			'settings.radio.cwMessages.details' => '详情',
			'settings.radio.cwMessages.empty' => '（空）',
			'settings.radio.cwMessages.sets' => '消息组',
			'settings.radio.cwMessages.newSet' => '新建消息组',
			'settings.radio.cwMessages.renameSet' => '重命名消息组',
			'settings.radio.cwMessages.deleteSet' => '删除消息组',
			'settings.radio.cwMessages.newSetName' => '名称',
			'settings.radio.cwMessages.setDefault' => '默认',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM 消息',
			'settings.radio.cwMessages.setSaved' => '我的消息',
			'settings.radio.cwMessages.repeat' => '重复消息 #1',
			'settings.radio.cwMessages.repeatOff' => '否',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => '${n} 秒后',
			'settings.radio.cwMessages.repeatWait' => '重复中',
			'settings.radio.cwMessages.keyboard' => '键入发送',
			'settings.radio.cwMessages.keyboardField' => '键入发送',
			'settings.radio.cwMessages.closeArea' => '关闭电键区域',
			'settings.radio.cwMessages.help' => '帮助',
			'settings.radio.cwMessages.helpTitle' => '编写 CW 消息',
			'settings.radio.cwMessages.helpIntro' => '消息可以使用包含以下值的模板：',
			'settings.radio.cwMessages.helpOpCall' => '您的呼号',
			'settings.radio.cwMessages.helpQsoCall' => '对方呼号——在 // 堆栈中，为将要记录的呼号',
			'settings.radio.cwMessages.helpQsoFullCall' => '对方呼号（如为有效呼号）；部分呼号时为空',
			'settings.radio.cwMessages.helpQsoPartial' => '部分呼号；如为完整有效呼号则为空',
			'settings.radio.cwMessages.helpQsoNextCall' => '在 // 堆栈中，接下来将被选中记录的呼号（如为有效完整呼号）',
			'settings.radio.cwMessages.helpQsoNextPartial' => '在 // 堆栈中，记录当前通联后的下一个部分呼号',
			'settings.radio.cwMessages.helpQsoName' => '对方的名字，取自输入内容，否则取自查询结果',
			'settings.radio.cwMessages.helpQsoState' => '对方的州，取自输入内容，否则取自查询结果',
			'settings.radio.cwMessages.helpKeyerMsg' => '消息 1 在另一条消息中按实际发送的内容展开。适用于消息 1 到 8',
			'settings.radio.cwMessages.helpQsoRst' => '您发送的报告',
			'settings.radio.cwMessages.helpQsoSerial' => '您的序号，用于需要发送序号的竞赛',
			'settings.radio.cwMessages.helpPad' => '用零补足到指定位数：7 发送为 007',
			'settings.radio.cwMessages.helpCut' => '简缩数字，T 代表 0，N 代表 9：599 发送为 5NN',
			'settings.radio.cwMessages.helpCutDigits' => '在引号中选择要简缩的数字——0 为 T，1 为 A，5 为 E，9 为 N',
			'settings.radio.cwMessages.helpFullExample' => '完整示例：',
			'settings.radio.cwMessages.helpExample' => '发送 W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => '开启“回车发送消息”后，回车会按功能键发送消息，与 N1MM 相同。ESM 消息组默认包含以下内容：',
			'settings.radio.cwMessages.helpEsmCq' => 'Run 模式下，呼号字段为空时按回车呼叫 CQ',
			'settings.radio.cwMessages.helpEsmExchange' => '您的交换信息：Run 模式下在对方呼号之后发送，S&P 模式下在对方回应后发送',
			'settings.radio.cwMessages.helpEsmThanks' => '致谢，在通联记录后发送：其中的占位符指向下一个通联，而不是本次通联',
			'settings.radio.cwMessages.helpEsmMyCall' => 'S&P 模式下，向您回应的电台发送您的呼号',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Run 模式下，在交换信息前发送对方呼号',
			'settings.radio.cwMessages.helpEsmAgain' => '未抄收到对方任何交换信息时请求重发',
			'settings.radio.cwMessages.helpEsmStackThanks' => '建议用于 // 堆栈的 F3：TU 在通联记录后发出，因此先致谢，再呼叫堆栈中的下一个电台并发送您的交换信息，或回询部分呼号（TU KR?）；如果没有剩余，则只发 TU',
			'settings.radio.voiceMessages.title' => '话音电键消息',
			'settings.radio.voiceMessages.notSupported' => '当前电台不支持话音消息',
			'settings.radio.voiceMessages.description' => '使用电台的语音存储',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => '语音存储 (${n})',
			'settings.radio.voiceMessages.labelField' => '标签',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => '语音存储 ${n} 标签',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => '空',
			'settings.radio.voiceMessages.notMeasured' => '长度未知',
			'settings.radio.voiceMessages.playButton' => '播放',
			'settings.radio.voiceMessages.recordButton' => '录制',
			'settings.radio.voiceMessages.stopButton' => '停止',
			'settings.radio.voiceMessages.repeat' => '重复消息 #1',
			'settings.radio.voiceMessages.repeatOff' => '否',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => '${n} 秒后',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} 说明：',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => '这些存储位于 ${device} 的电台中。其名称和长度归该设备所有。',
			'settings.radio.voiceMessages.namedOnRadio' => '保存在电台中，电台的其他客户端也能看到。',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => '等待电台上出现 [REC] 指示，然后按住 PTT 按钮录制您的消息。松开 PTT 之前，先按本应用中的 STOP 按钮结束录制，以避免多余的咔嗒声。',
			'settings.radio.voiceMessages.recordHelpFt891' => '等待 [REC] 指示至少闪烁四次，然后按住 PTT 按钮录制您的消息。松开 PTT 之前，先按本应用中的 STOP 按钮结束录制，以避免多余的咔嗒声。',
			'settings.radio.voiceMessages.pill' => '语音',
			'settings.radio.voiceMessages.play' => ({required Object n}) => '播放存储 ${n}',
			'settings.radio.voiceMessages.stop' => '停止',
			'settings.radio.voiceMessages.record' => ({required Object n}) => '录制存储 ${n}',
			'settings.radio.voiceMessages.stopRecording' => '停止录制',
			'settings.radio.voiceMessages.playing' => '播放中…',
			'settings.radio.voiceMessages.recording' => '录制中…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '正在播放 ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '正在录制 ${label}',
			'settings.radio.voiceMessages.doubtful' => '电台播放了吗？它立即报告为空闲。',
			'settings.radio.voiceMessages.recordOnRadio' => '必须在电台本身上录制存储。',
			'settings.radio.avoidZeroBeat.title' => '避免在信号上零差拍',
			'settings.radio.avoidZeroBeat.descriptionOn' => '连接电台时，调谐到偏离 CW 信号几 Hz 的位置，这样回应它的人不会都在同一音调上呼叫。',
			'settings.radio.avoidZeroBeat.descriptionOff' => '精确调谐到信号频率。',
			'settings.radio.zeroBeatRange.title' => '零差拍：规避范围',
			'settings.radio.zeroBeatRange.description' => '在信号频率两侧偏离多远。偏移永远不会接近零——那又会成为零差拍。',
			'settings.help.title' => '帮助与资源',
			'settings.help.description' => '社区与支持',
			'settings.help.forums' => 'Ham2K 论坛',
			'settings.help.forumsDescription' => '寻找帮助，给予反馈，讨论想法…',
			'settings.help.chat' => 'Ham2K 聊天',
			'settings.help.chatDescription' => '我们的在线社区的 Discord 服务器',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => '视频和直播',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => '因为照片永远不嫌多…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => '关注我们以获取新闻和更新',
			'settings.help.contact' => '联系我们',
			'settings.help.contactDescription' => 'help@ham2k.com——但请先尝试使用论坛或聊天！',
			'settings.exports.title' => '导出',
			'settings.map.title' => '地图',
			'settings.map.style.title' => '地图样式',
			'settings.map.styleOpts.automatic' => '自动',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => '隐私',
			'settings.privacy.shareAppData.title' => '分享应用使用数据',
			'settings.privacy.shareAppData.descriptionOn' => '共享使用情况、配置、崩溃和性能数据，帮助我们改进应用',
			'settings.privacy.shareAppData.descriptionOff' => '保持应用使用数据私密。\nHam2K 团队将无法检测崩溃或其他问题。',
			'settings.privacy.shareOpData.title' => '共享操作数据',
			'settings.privacy.shareOpData.descriptionOn' => '公开并与其他用户共享部分操作数据',
			'settings.privacy.shareOpData.descriptionOff' => '保持操作数据私密',
			'settings.privacy.privacyPolicy' => '隐私政策',
			'settings.privacy.termsOfService' => '服务条款',
			'settings.operatorCall' => '操作员呼号',
			'settings.sync.title' => '云同步',
			'settings.sync.moreSettings' => '更多同步设置',
			'settings.sync.enable' => '启用同步',
			'settings.sync.deviceKey' => '设备密钥',
			'settings.peers.title' => '对等设备',
			'settings.peers.enable' => '连接到其他设备',
			'settings.peers.enableDescription' => '允许通过本地网络与其他设备共享操作、记录、CAT 和 GPS',
			'settings.peers.bleEnable' => '通过蓝牙连接',
			'settings.peers.bleDescription' => '即使没有本地网络，也使用低功耗蓝牙连接',
			'settings.peers.thisDevice' => '此设备',
			'settings.peers.deviceName' => '名称',
			'settings.peers.deviceNameHint' => '其他设备看到的此设备名称',
			'settings.peers.pairedDevices' => '已链接设备',
			'settings.peers.noPairedDevices' => '尚未链接设备。在此网络上的另一台设备上开启此项即可链接。',
			'settings.peers.deviceListProblem' => ({required Object error}) => '无法读取已链接设备：${error}',
			'settings.peers.nearby' => '附近',
			'settings.peers.connected' => '已连接',
			'settings.peers.viaBluetooth' => '通过蓝牙',
			'settings.peers.connecting' => '连接中…',
			'settings.peers.syncing' => '同步中…',
			'settings.peers.waitingForThem' => '等待另一台设备',
			'settings.peers.notConnected' => '未连接',
			'settings.peers.wantsToPair' => '想要共享此操作',
			'settings.peers.allow' => '允许',
			'settings.peers.link' => '链接',
			'settings.peers.reject' => '拒绝',
			'settings.peers.forget' => '忘记',
			'settings.peers.forgetTitle' => ({required Object name}) => '忘记 ${name}？',
			'settings.peers.forgetBody' => '它将停止与此设备同步。您之后可以再次允许，已记录的通联会保留。',
			'settings.peers.pairTitle' => ({required Object name}) => '与 ${name} 链接',
			'settings.peers.pairBody' => '此设备位于您的本地网络上，想要连接。',
			'settings.peers.pairBodyBle' => '此设备就在附近，想要通过低功耗蓝牙连接。',
			'settings.peers.pairIdLabel' => '设备 ID',
			'settings.peers.pairWarning' => '只与您认识的设备链接。此网络上的任何设备都可以发送请求。',
			'settings.peers.pairWarningBle' => '只与您认识的设备链接。附近的任何设备都可以发送请求。',
			'settings.peers.problem' => ({required Object error}) => '无法访问本地网络：${error}',
			'settings.peers.bleProblem' => ({required Object error}) => '蓝牙：${error}',
			'settings.peers.statusConnected' => ({required Object device}) => '已连接到 ${device}',
			'settings.peers.statusLost' => ({required Object device}) => '与 ${device} 的连接已断开',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => '对等设备：已连接 ${connected} / ${linked}',
			'settings.peers.screenEnable' => '共享屏幕和窗口',
			'settings.peers.screenDescription' => '允许其他设备显示此计算机的屏幕或窗口',
			'settings.peers.screenSources' => '屏幕和窗口',
			'settings.peers.screenRefresh' => '刷新列表',
			'settings.peers.screenUnsupportedPlatform' => '此设备无法共享屏幕。macOS 可以；所有设备都能显示其他设备共享的屏幕。',
			'settings.peers.screenUnsupportedVersion' => '共享屏幕需要 macOS 12.3 或更高版本。此设备仍可显示其他设备共享的屏幕。',
			'settings.peers.screenNeedsPermission' => '需要您授予 macOS 屏幕录制权限，此应用才能共享屏幕。',
			'settings.peers.screenGrantPermission' => '请求权限',
			'settings.peers.screenRelaunchAfterGranting' => '请在 系统设置 → 隐私与安全性 → 屏幕录制 中允许，然后退出并重新打开此应用——macOS 只在应用下次启动时才告知此更改。',
			'settings.peers.screenProblem' => ({required Object error}) => '屏幕共享：${error}',
			'settings.peers.screenChooseTitle' => '选择要共享的内容',
			'settings.peers.screenChooseButton' => '选择要共享的内容…',
			'settings.peers.screenTabScreens' => '屏幕',
			'settings.peers.screenTabApps' => '应用',
			'settings.peers.screenTabWindows' => '窗口',
			'settings.peers.screenTabEmpty' => '未找到此类内容。',
			'settings.peers.screenSharedSummaryNone' => '尚未选择任何内容。',
			'settings.peers.screenThisDevice' => '此设备',
			'settings.peers.screenSharedTo' => ({required Object devices}) => '显示于 ${devices}',
			'settings.peers.screenSharedToNobody' => '未在显示',
			'settings.peers.screenStopSharing' => ({required Object name}) => '停止共享 ${name}',
			'settings.developerMode' => '开发者模式',
			'settings.syncPanel.configuration' => '同步配置',
			'settings.syncPanel.enableTitle' => '与 Ham2K Log Filer 同步',
			'settings.syncPanel.enabledDescription' => '正在备份日志并在设备间同步',
			'settings.syncPanel.disabledDescription' => '关闭——仅保存在此设备上',
			'settings.syncPanel.syncing' => '同步中',
			'settings.syncPanel.account' => '账户',
			'settings.syncPanel.refresh' => '刷新',
			'settings.syncPanel.switchAccounts' => '切换账户',
			'settings.syncPanel.switchAccountsDescription' => '通过二维码或电子邮件将此设备链接到另一个账户',
			'settings.syncPanel.connectionRequests' => '连接请求',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '有 1 台设备正在等待加入此账户', other: '有 ${n} 台设备正在等待加入此账户', ), 
			'settings.syncPanel.accountEmailTitle' => '账户电子邮件',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => '确认邮件已发送到 ${email}。请打开其中的链接完成更改。',
			'settings.syncPanel.resendConfirmation' => '重新发送确认邮件',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => '等待 ${email} 确认',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => '已再次发送到 ${email}。',
			'settings.syncPanel.deviceLinked' => '该设备现已链接到此账户。',
			'settings.syncPanel.checking' => '检查中…',
			'settings.syncPanel.notLinked' => '尚未链接',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => '替换本地数据？',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${n} 个操作', other: '${n} 个操作', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${n} 个 QSO', other: '${n} 个 QSO', ), 
			'settings.syncPanel.counts' => '已同步数据',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => '此设备：${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => '等待上传：${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => '服务器：${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => '此设备：检查中…',
			'settings.syncPanel.countsServerChecking' => '服务器：检查中…',
			'settings.syncPanel.countsServerUnavailable' => '服务器：不可用',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => '这将备份并清除此设备上的 ${operations} 和 ${qsos}，然后改为下载该账户的数据。备份保留在此设备的数据库中。',
			'settings.syncPanel.replace' => '替换',
			'settings.syncPanel.pendingBannerTitle' => '检测到新的 Ham2K Log Filer 账户',
			'settings.syncPanel.pendingBannerBody' => '保留此设备上现有的操作和 QSO 并合并到该账户，或用该账户的数据替换它们（无论哪种方式，此设备上都会保留一份备份）。',
			'settings.syncPanel.combine' => '合并',
			'settings.syncPanel.authIssueTitle' => '同步无法连接',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer 一直拒绝此设备。请在同步设置中检查您的呼号。',
			'settings.syncPanel.openSettings' => '打开同步设置',
			'settings.accounts.title' => '账户、服务和数据源',
			'settings.accounts.none' => '没有带账户的活动扩展',
			'settings.accounts.notConfigured' => '未配置',
			'settings.accounts.connected' => '已连接',
			'settings.accounts.cancelLogin' => '取消登录',
			'settings.accounts.openInBrowser' => '在浏览器中打开',
			'settings.accounts.loggedInAs' => ({required Object identity}) => '已登录为 ${identity}',
			'settings.accounts.pressSaveToKeep' => '按“保存”以保持此账户连接。',
			'settings.accounts.connectedTo' => ({required Object label}) => '已连接到 ${label}',
			'settings.accounts.connect' => '连接',
			'settings.accounts.disconnect' => '断开连接',
			'settings.accounts.connectedAs' => '已连接为',
			'settings.accounts.test' => '测试',
			'settings.accounts.saveFailed' => ({required Object error}) => '保存失败：${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => '登录失败：${error}',
			'settings.accounts.lookupFailed' => '账户暂时不可用——请稍后重试',
			'settings.accounts.browserLoginTitle' => '请在网页浏览器中完成登录',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => '完成后，浏览器会尝试打开以“${prefix}”开头的链接。您的桌面很可能没有注册能打开它的程序，因此请复制该链接（从地址栏，或从浏览器显示的错误页面），然后粘贴到这里。',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger 无法打开您的浏览器。请复制下面的登录链接并自行打开，然后复制它跳转到的链接（以“${prefix}”开头）并粘贴到这里。',
			'settings.accounts.copyLoginLink' => '复制登录链接',
			'settings.accounts.pastedLinkLabel' => '在此粘贴链接',
			'settings.accounts.finishLogin' => '完成登录',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => '这不是登录链接——它应以“${prefix}”开头。',
			'settings.accounts.pastedLinkWrongLogin' => '该链接属于另一次登录尝试。请关闭此页面并重新连接。',
			'settings.accounts.pastedLinkNoCode' => '该链接没有登录代码。请先完成登录，再复制它跳转到的链接。',
			'settings.accounts.pastedLinkMalformed' => '该链接似乎被截断了。请复制完整链接后重新粘贴。',
			'settings.accounts.relayLoginWaiting' => '等待您完成登录——完成后将自动继续。',
			'settings.accounts.loginNoResponse' => '此设备尚未收到登录的回应。如果您已在浏览器中完成，请取消并重新连接。',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger 无法自动打开您的浏览器。请使用下面的按钮自行打开登录页面。',
			'settings.accounts.relayLoginUnavailable' => '无法连接完成此登录所需的同步服务器。请检查网络连接后重试。',
			'settings.accounts.loginIncompleteResponse' => '该登录尝试未正确完成。请重新连接。',
			'settings.accounts.noKeyringTitle' => '无法保存账户登录信息',
			'settings.accounts.noKeyringText' => 'Ham2K Logger 无法访问此计算机上的密钥环服务，因此无法存储或读取账户登录信息——在解决此问题之前，连接账户将会失败。请安装并启动 **gnome-keyring**、**KWallet** 或 **KeePassXC**，或解锁您现有的密钥环，然后重新启动。记录、导出和数据文件不受影响；在此期间日志同步保持关闭。',
			'settings.accounts.noKeyringInline' => '无法保存登录信息：无法访问此计算机的密钥环。请安装并启动 gnome-keyring、KWallet 或 KeePassXC，或解锁您现有的密钥环。',
			'settings.accounts.noSecureStorageInline' => '无法保存登录信息：无法访问此计算机的安全存储。',
			'settings.station.title' => '电台配置与 CAT 控制',
			'settings.station.none' => '未配置设备',
			'settings.station.add' => '添加',
			'settings.station.addTitle' => '添加设备',
			'settings.station.searchHint' => '搜索设备',
			'settings.station.noMatches' => '没有匹配的设备',
			'settings.station.detectedEquipment' => '检测到的设备',
			'settings.station.discoveryUnavailable' => ({required Object error}) => '无法监听电台：${error}',
			'settings.station.edit' => '编辑设备',
			'settings.station.name' => '名称',
			'settings.station.nameDescription' => '您对它的称呼——如“左边的电台”。可选。',
			'settings.station.transport' => '连接',
			'settings.station.host' => '地址',
			'settings.station.hostDescription' => '电台在您网络上的主机名或 IP 地址。',
			'settings.station.port' => '端口',
			'settings.station.hostRequired' => '必须填写地址',
			'settings.station.portInvalid' => '端口必须在 1 到 65535 之间',
			'settings.station.connect' => '连接',
			'settings.station.disconnect' => '断开连接',
			'settings.station.remove' => '移除',
			'settings.station.removeTitle' => ({required Object name}) => '移除 ${name}？',
			'settings.station.removeMessage' => '这只会将其从应用中移除。设备本身的设置保持不变。',
			'settings.station.unknownType' => ({required Object typeKey}) => '无法识别的设备类型“${typeKey}”',
			'settings.station.report' => '报告',
			'settings.station.reportTitle' => '报告此电台',
			'settings.station.reportIntro' => '告诉我们这台电台的真实型号以及使用情况。您的报告会成为 Ham2K 团队阅读的卡片，您写下的调试经验也可能帮助下一位使用同款电台的操作员。',
			'settings.station.reportManufacturer' => '制造商',
			'settings.station.reportManufacturerDescription' => '谁生产的——Icom、Yaesu、Kenwood、Elecraft…',
			'settings.station.reportManufacturerRequired' => '必须填写制造商',
			'settings.station.reportModel' => '型号',
			'settings.station.reportModelDescription' => '电台自身所示的型号——“IC-7300”、“FT-991A”。',
			'settings.station.reportModelRequired' => '必须填写型号',
			'settings.station.reportOutcome' => '使用情况如何？',
			'settings.station.reportOutcomeWorks' => '工作良好',
			'settings.station.reportOutcomeIssues' => '能工作，但有问题',
			'settings.station.reportOutcomeFails' => '完全无法工作',
			'settings.station.reportOutcomeRequired' => '请告诉我们使用情况',
			'settings.station.reportComments' => '评论',
			'settings.station.reportCommentsPlaceholder' => '哪些可行、哪些不行，以及任何出乎意料的情况。',
			'settings.station.reportHints' => '故障排除提示',
			'settings.station.reportHintsPlaceholder' => '想为其他用户提供一些故障排除提示吗？',
			'settings.station.reportSend' => '发送报告',
			'settings.station.reportSending' => '正在发送您的报告…',
			'settings.station.reportSent' => ({required Object ref}) => '谢谢——您的报告已登记为 ${ref}。',
			'settings.station.reportSentNoRef' => '谢谢——您的报告已发送。',
			'settings.station.reportFailed' => ({required Object error}) => '报告未发送：${error}',
			'settings.station.troubleshootingNotes' => '故障排除说明',
			'settings.station.mainVfo' => '主 VFO',
			'settings.station.useAsMainVfo' => '用作主 VFO',
			'settings.station.serialPort' => '串口',
			'settings.station.serialPortDescription' => '电台 CAT 接口所在的端口。',
			'settings.station.serialPortNone' => '未找到串口',
			'settings.station.serialPortRequired' => '请选择串口',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => '端口 ${n} / ${total}',
			'settings.station.serialPortSuggested' => '建议',
			'settings.station.serialPortJustNow' => '最近连接',
			'settings.station.serialDeviceRequest' => '添加 USB 设备…',
			'settings.station.baudRate' => '速率（波特）',
			'settings.station.baudRateDescription' => '必须与电台的 CAT 菜单一致。不一致时，电台会返回乱码且不报错。',
			'settings.station.serialRtsHigh' => '保持 RTS 为高',
			'settings.station.serialRtsHighDescription' => '仅适用于响应前等待 RTS 的电台，例如开启了 CAT RTS 的 Yaesu。在 Digirig、SignaLink 和大多数自制线缆上，RTS 就是 PTT，保持为高会导致发射。',
			'settings.station.serialDtrHigh' => '保持 DTR 为高',
			'settings.station.serialDtrHighDescription' => '仅适用于从 DTR 取电的 CAT 接口，例如某些用于 FT-817 的 RS-232 线缆。在许多线缆上 DTR 用于 CW 键控或 PTT，保持为高会导致发射。',
			'settings.station.civAddress' => '电台 CI-V 地址',
			'settings.station.civAddressDescription' => '十六进制，与电台 CI-V 菜单中显示的一致。IC-705 出厂为 A4。',
			'settings.station.civAddressInvalid' => 'CI-V 地址为两位十六进制数，01 到 FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => '此连接读取并调谐电台的哪个 Slice。',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => '请选择电台的某个 Slice，A 到 H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => '此电台未使用 Slice ${letter}——请选择其他 Slice，或在 SmartSDR 中创建',
			'settings.station.channelNotInUse' => '未使用',
			'settings.station.channelHeldByUnknown' => '被其他程序占用',
			'settings.station.flexNoSlices' => '此电台未报告任何 Slice——请检查 SmartSDR 是否正在运行，以及此客户端是否可以订阅',
			'settings.station.spectrumUnsupported' => '此电台不通过 CAT 发送频谱',
			'settings.station.spectrumRequiresBaud' => '需要 CAT 速率为 115200 bps',
			'settings.station.spectrumNoRadio' => '未连接电台',
			'settings.station.spectrumWaiting' => '等待电台的频谱…',
			'settings.station.spectrumUnavailable' => '频谱显示不可用',
			'settings.station.spectrumNoDaxChannel' => '此电台的所有 DAX IQ 通道都已被占用',
			'settings.station.spectrumNoPanadapter' => '此 Slice 在电台上没有全景显示',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => '电台拒绝了 DAX IQ 流（错误 ${code}）',
			'settings.station.spectrumNoUdp' => '电台的频谱数据无法到达此设备',
			'settings.station.spectrumScopeRefused' => '电台拒绝了频谱仪命令',
			'settings.station.spectrumOutOfRange' => '电台的频谱仪设置超出了可显示的范围',
			'settings.station.n3fjpNoRig' => 'N3FJP 未设置电台接口，因此这里跟随的是在 N3FJP 中输入的内容，而不是电台',
			'settings.station.winkeyerKeyPort' => '键控输出',
			'settings.station.winkeyerKeyPortDescription' => '您的电台插在电键器两个输出插孔中的哪一个。',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => '端口 ${n}',
			'settings.station.winkeyerPtt' => '使用电键器的 PTT',
			'settings.station.winkeyerPttDescription' => '在同一插孔上键控 PTT 线，用于需要它的功放或电台。如电台通过其电键插孔键控，请保持关闭。',
			'settings.station.winkeyerNoAnswer' => '此端口上没有 WinKeyer 响应',
			'settings.station.winkeyerStoppedAnswering' => 'WinKeyer 在发送时停止响应；该消息已丢弃',
			'settings.station.radioUser' => '电台用户名',
			'settings.station.radioPass' => '电台密码',
			'settings.station.radioLoginDescription' => '电台的 Network → Remote 登录信息，不是您的 WiFi 密码。',
			'settings.station.radioUserRequired' => '必须填写电台的远程控制用户名',
			'settings.station.connectFailedBusy' => '设备正在使用中',
			'settings.station.connectFailedDenied' => '访问被拒绝',
			'settings.station.connectFailedDevice' => '未找到设备',
			'settings.station.connectFailedLines' => '无法按设置保持 RTS/DTR，因此已关闭端口。可能有其他程序开启了硬件握手——请拔下线缆后重新插入。',
			'settings.station.connectFailedNetwork' => '无法通过网络找到电台。请检查其地址，并确认它已开机且可访问。',
			'settings.station.connectFailedTimeout' => '电台未及时响应。请确认它已开机且可访问。',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - 通用',
			'settings.station.models.icomGeneric' => 'Icom - 通用',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - 通用',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - 通用',
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
			'settings.station.models.rigctld' => '通过 rigctld 控制的电台',
			'settings.station.models.rigctldNodeName' => '我的电台（通过 rigctld）',
			'settings.station.models.flrig' => '通过 flrig 控制的电台',
			'settings.station.models.flrigNodeName' => '我的电台（通过 flrig）',
			'settings.station.models.hrd' => '通过 Ham Radio Deluxe® 控制的电台',
			'settings.station.models.hrdNodeName' => '我的电台（通过 HRD）',
			'settings.station.models.n3fjp' => '通过 N3FJP 控制的电台',
			'settings.station.models.n3fjpNodeName' => '我的电台（通过 N3FJP）',
			'settings.station.models.commander' => '通过 DXLab Commander 控制的电台',
			'settings.station.models.commanderNodeName' => '我的电台（通过 Commander）',
			'settings.station.models.antenna' => '天线',
			'settings.station.models.key' => 'CW 电键',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => '通用电台（占位）',
			'settings.station.models.placeholderRadioNodeName' => '我的电台',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 同轴开关',
			'settings.station.transports.network' => '网络/WiFi',
			'settings.station.transports.usbSerial' => 'USB 串口',
			'settings.station.transports.wifi' => '网络/WiFi',
			'settings.station.transports.bluetoothSerial' => '蓝牙串口',
			'settings.station.transports.placeholder' => '占位',
			'settings.station.troubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.ft891Troubleshooting' => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **电台上的 CAT RTS 必须为 OFF**（FT-891 菜单 **05-08**）。开启时，电台会等待一条握手线，而应用将其保持为低。在 Digirig、SignaLink 或大多数自制线缆上，这条线就是 PTT，拉高它会让发射机发射。如使用电台自带的 USB 端口，可改为在高级设置中开启 **保持 RTS 为高**。\n- **速率必须与电台的 CAT RATE 一致**（菜单 **05-06**）。不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。',
			'settings.station.yaesuBinaryTroubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.yaesuBinaryTroubleshooting' => '此电台使用 Yaesu 较早的五字节 CAT 协议，只要有任何问题就完全不响应。几乎总是以下原因之一：\n\n- **线缆必须转换电平。** 背面的 CAT 插孔既不是 RS-232 也不是 USB；需要 CT-62 或同等适配器。普通音频线或数据线无法用于 CAT。\n- **速率必须与电台的 CAT RATE 菜单一致**（FT-817 上为 **#14**，FT-857 或 FT-897 上为 **#19**）。不一致时，电台什么都不返回，而且从不报错。\n- **绝不要让任何程序拉高此端口的 RTS 或 DTR。** 在这些电台的大多数线缆上，这两条线用于 PTT 和键控。例外是由 DTR 供电的老式接口：对于这种接口，请在高级设置中开启 **保持 DTR 为高**。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n此驱动根据 Yaesu 公布的 CAT 表编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.guohetecTroubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.guohetecTroubleshooting' => 'Q900 有两种 CAT 协议，此条目使用其原生协议，而不是模仿 FT-817 的协议。请在此选择 **Guohetec Q900**，而不是 FT-817——模仿协议支持的命令更少，而且电台不会说明它正在使用哪一种。\n\n- **USB-C 线就是 CAT 连接**，它同时也连接声卡。在这条线上速率无关紧要；端口会忽略所设置的任何值。\n- **绝不要让任何程序拉高此端口的 RTS 或 DTR。** 在串口线上，这两条线用于 PTT 和键控。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **第二代电台的行为与第一代不同。** 长按 Menu，然后选择 About：HW 2.0 即为第二代。\n\n此驱动根据制造商公布的协议编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.yaesuTroubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.yaesuTroubleshooting' => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而应用将其保持为低。在 Digirig、SignaLink 或大多数自制线缆上，这条线就是 PTT，拉高它会让发射机发射。如使用电台自带的 USB 端口，可改为在高级设置中开启 **保持 RTS 为高**。该设置的位置因型号而异（FT-891 上为菜单 **05-08**）。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **模式遵循 FT-891 的对照表。** 大多数 Yaesu 电台与之相符，但模式编号不同的电台在这些模式上会显示和设置错误的模式。频率不受影响。',
			'settings.station.yaesuRs232Troubleshooting' => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **CAT 插孔是 RS-232。** 需要 USB 转串口适配器和直通 DB-9 线缆——交叉（null-modem）线会交换信号线，电台将什么都收不到。\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而除非在高级设置中开启 **保持 RTS 为高**，应用会将其保持为低。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n此条目根据公开的 CAT 文档编写，尚未在这些电台上实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.yaesuUsbTroubleshooting' => '电台正在接收命令，但没有响应。几乎总是以下原因之一：\n\n- **使用电台两个 USB 端口中的第一个。** CAT 通常在第一个端口上（Windows 上为 **Enhanced** COM 端口）；第二个（**Standard**）用于 PTT 和键控。只要能区分两者，端口选择器都会指向第一个。\n- **电台上的 CAT RTS 必须为 OFF。** 开启时，电台会等待一条握手线，而除非在高级设置中开启 **保持 RTS 为高**，应用会将其保持为低。\n- **速率必须与电台的 CAT RATE 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。',
			'settings.station.k4SerialNotes' => '连接 K4 背面的 USB-B (PC) 插座。USB-PC1 或 USB-PC2 都可用于 CAT；请选择未使用的端口，并使其与电台上的 Serial USB-PCn: Baud Rate 设置一致。HaLo 预填为 38400；如有需要请更改。其他应用必须使用另一个端口或以太网。\n\n此连接控制电台及其电键器；不会向 HaLo 发送音频。',
			'settings.station.k4TcpNotes' => '将 K4 的以太网插座连接到您的本地网络。输入其主机名或 IP 地址，以及 CAT 端口 9200。这是 CAT 控制，不是端口 9204 上单独的远程音频连接。\n\nHaLo 控制电台及其电键器，不传输音频或全景显示数据。',
			'settings.station.k4PowerTimeout' => 'K4 功率未更改，因为电台没有确认其输出范围。请重试。',
			'settings.station.k4PowerRange' => 'K4 功率必须为 0.1–110 W；当变频器毫瓦输出启用时，必须为 0.0001–0.01 W。',
			'settings.station.elecraftTroubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.elecraftTroubleshooting' => 'Elecraft 电台使用 Kenwood CAT 协议，KX2 和 KX3 都已用这种方式实测——VFO 双向同步、模式切换和 CW 零差拍均可正常工作。\n\n如果电台没有响应，几乎总是以下原因之一：\n\n- **速率必须与电台菜单中 **RS232** 下设置的速率一致。** 这些电台出厂为 38400。不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n\n**如果频率正确但模式错误**，请告诉我们。KX2 和 KX3 条目从电台状态回复中的某个位置读取模式，这个位置是根据我们见过的电台确定的；如果某个固件把它放在别处，只有通过报告我们才能得知。\n\n目前还没有关于 K3 的任何报告，如果您在使用，请告诉我们结果。K4 有单独的条目。',
			'settings.station.kenwoodTroubleshootingTitle' => '如果电台已连接但不显示频率',
			'settings.station.kenwoodTroubleshooting' => '此驱动已在 Kenwood 的 TS-590SG 和 TS-480、QRP Labs 的 QMX 和 QCX-mini，以及 Elecraft 的 KX2 和 KX3 上验证。其余型号根据公开的 CAT 资料编写，因此无论结果如何，都请报告。\n\n如果电台没有响应，几乎总是以下原因之一：\n\n- **速率必须与电台的 CAT 菜单一致。** 不一致时，电台会返回乱码或什么都不返回，而且从不报错。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。\n- **某些电台需要先在菜单中启用 CAT**，否则完全不响应。\n\n**一些 SDR 前端也使用相同的协议**，因此对它们也值得尝试此条目；Elecraft 电台单独列在 Elecraft 下。如果频率正确但模式错误或缺失，这正是各型号之间唯一不同的部分——应用会根据电台推断模式，失败时再直接查询，因此模式可能只是稍有延迟。',
			'settings.station.statusConnected' => '已连接',
			'settings.station.statusLost' => '已断开',
			'settings.station.notConfigured' => '未配置',
			'settings.station.currentConfiguration' => '当前配置',
			'settings.station.currentTransceiver' => '当前收发信机',
			'settings.station.radioMode' => '电台模式',
			'settings.station.keyerNotSupported' => '当前电台不支持',
			'settings.station.catControlPreferences' => 'CAT 控制偏好',
			'settings.station.chooseTransceiver' => '选择收发信机',
			'settings.station.configurationSection' => '配置',
			'settings.station.noTransceiverSelected' => '未选择收发信机',
			'settings.station.makeMainVfo' => ({required Object name}) => '将 ${name} 用作主 VFO',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, zero: '没有收发信机', one: '${count} 台收发信机', other: '${count} 台收发信机', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 副天线', other: '${count} 副天线', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 台其他设备', other: '${count} 台其他设备', ), 
			'settings.station.equipmentInventory' => '设备清单',
			'settings.station.equipmentInUse' => '收发信机控制',
			'settings.station.noTransceiver' => '无',
			'settings.station.peerRadioNotAvailable' => '不可用',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => '位于 ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} 位于另一台设备上',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => '此电台连接在 ${device} 上。其连接和设置需在该设备上配置。',
			'settings.station.antennaInUse' => '使用中的天线',
			'settings.station.keyInUse' => '使用中的电键',
			'settings.station.noneSelected' => '无',
			'settings.station.moreSettings' => '更多设置',
			'settings.station.icomCivTroubleshootingTitle' => '如果同一台电台出现两个串口',
			'settings.station.icomCivTroubleshooting' => '包括 IC-705 在内的多款 Icom 电台会同时提供**两个** USB 串口（Icom 称为 Port A 和 Port B），默认都设为 CI-V。除此之外，本应用和您的操作系统都无法区分它们：同一个 USB 厂商/产品 ID 只是出现两次，有时在这里会带有 `#2` 后缀。**通常 Port A 才是正确的**——一般是操作系统或浏览器列出的第一个，在本应用能区分两个端口时，会将其标记为建议。如果命令已发出而电台始终没有响应，请改试另一个端口。',
			'settings.station.civAddressTroubleshootingTitle' => '如果电台始终没有响应',
			'settings.station.civAddressTroubleshooting' => '- **CI-V 地址必须与电台菜单一致。** 此条目预填了该型号的出厂地址，但多台电台共用 CI-V 总线时，正是需要更改这个地址的情况。发往错误地址的帧会被静默忽略，看起来就像线缆坏了一样。\n- **速率必须与电台的 CI-V BAUD RATE 一致**（USB 上为 CI-V USB Baud Rate）。请将电台设为与此处显示相同的数值，**不要用 Auto**。设为 Auto 时，包括 IC-7300 在内的一些电台连接后大约一分钟就会停止响应。\n- **其他应用可能占用了端口**：WSJT-X、fldigi 和 rigctld 都会保持端口打开。',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** 出厂地址为 `B6`，而不是此处预填的 `94`——请改选 IC-7300 MK2 条目。',
			'settings.station.ic705PortNote' => '\n- **IC-705** 提供两个 USB 串口，都以电台名称命名。CI-V 在其中的**第一个**上，只要能区分两者，端口选择器都会指向它。',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** 在其提供的两个 USB 串口中的 **Port A** 上使用 CI-V。',
			'settings.station.x6100PortNote' => '\n- **X6100** 在其 **DEV** 端口上使用 CI-V——即它提供的两个串口中的第二个，也是端口选择器指向的那个。',
			'settings.station.rigctldTroubleshootingTitle' => '如果应用无法连接',
			'settings.station.rigctldTroubleshooting' => '这会连接到**您自行运行的 rigctld 守护进程**，而不是直接连接电台——由 Hamlib 的后端与电台通信，支持数百种型号。\n\n- **守护进程必须已在运行**，例如 `rigctld -m 1035 -r /dev/ttyUSB0`。使用 `rigctl -l` 查找您电台的型号编号。\n- **从另一台计算机连接时**，请使用 `-T 0.0.0.0` 启动：默认情况下，rigctld 只接受来自其所在计算机的连接。\n- **端口**为 4532，除非您用 `-t` 启动守护进程。\n- 连接后如果没有频率，通常意味着守护进程本身无法访问电台。请在守护进程所在的计算机上用 `rigctl -m 2 f` 测试。',
			'settings.station.flrigTroubleshootingTitle' => '如果应用无法连接',
			'settings.station.flrigTroubleshooting' => '这会连接到**您自行运行的 flrig 程序**，而不是直接连接电台——由 flrig 与电台通信，支持大多数品牌和型号。\n\n- **flrig 必须已在运行**，并已配置和连接其收发信机。\n- **端口**为 12345，除非您在 flrig 的配置中更改过（Config → Setup → Server）。\n- **从另一台计算机连接时**，请确保 flrig 的服务器可以访问。它监听所有网络接口，但您的防火墙可能不允许。\n- 连接后如果没有频率，通常意味着 flrig 本身无法访问电台。请检查 flrig 的显示是否跟随旋钮变化。',
			'settings.station.hrdTroubleshootingTitle' => '如果应用无法连接',
			'settings.station.hrdTroubleshooting' => '这会连接到**在您计算机上运行的 Ham Radio Deluxe 的 Rig Control**，而不是直接连接电台——由 HRD 与电台通信。\n\n- **Rig Control 必须已在运行**并已连接到电台。\n- **必须启用其 IP 服务器。** Rig Control 只通过它与其他程序通信。\n- **端口**为 7809，除非您在 IP 服务器设置中更改过。\n- **从另一台计算机连接时**，请确保防火墙允许该连接。\n\n此条目根据公开的 HRD 协议说明编写，尚未与 HRD 实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.n3fjpTroubleshootingTitle' => '如果应用无法连接',
			'settings.station.n3fjpTroubleshooting' => '这会连接到**在您计算机上运行的 N3FJP 日志程序**，而不是直接连接电台——由 N3FJP 与电台通信。\n\n- **必须开启该程序的 API**：Settings → Application Program Interface，勾选 **TCP API Enabled**。\n- **端口**为 1100，除非您在那里更改过。\n- **N3FJP 必须设置了电台接口**，才能跟随或调谐电台。没有接口时，它只报告在其输入窗口中键入的内容。\n- N3FJP 只报告频段、模式和频率：不报告功率，也不报告发射状态。\n\n此条目根据 N3FJP 公开的 API 编写，尚未与 N3FJP 实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.commanderTroubleshootingTitle' => '如果应用无法连接',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshooting' => '这会连接到**在您计算机上运行的 DXLab Commander**，而不是直接连接电台——由 Commander 与电台通信。\n\n- **Commander 必须已在运行**并已连接到电台。\n- **必须开启其网络服务**：Commander 配置窗口 Radio 面板中的 **Net Serv** 按钮。\n- **端口**为 52002，即从 Net Serv 的 **Base Port**（默认为 52000，除非您更改过）开始的端口段中的第三个端口。\n- **从另一台计算机连接时**，请确保防火墙允许该连接。\n\n此条目根据 Commander 公开的 TCP 消息编写，尚未与 Commander 实际运行过。如果它只部分可用，非常值得报告。',
			'settings.station.ic705TroubleshootingTitle' => '如果电台始终没有响应',
			'settings.station.ic705Troubleshooting' => '电台只有**一个**远程控制会话。登录被忽略时，几乎总是有其他程序在使用它。\n\n- **关闭任何其他客户端。** 连接到同一电台的 wfview 或 RS-BA1 会占用这个会话，在此期间这里的登录会被直接忽略。\n- **检查电台的网络设置。** 必须开启 WLAN，电台必须在同一网络上，并且必须启用其远程控制（Network）功能。\n- 如果一直卡住，**请将电台的 WLAN 关闭再打开**。这样可以可靠地清除卡在电台上的会话。\n\n**密码错误会被明确拒绝**，而不是没有响应。如果您看到的是这里而不是“被拒绝”的消息，问题就不在密码。',
			'settings.station.statusStale' => '无响应',
			'settings.station.statusDisconnected' => '未连接',
			'settings.station.statusConnecting' => '连接中…',
			'settings.station.statusDisconnecting' => '正在断开…',
			'settings.station.statusError' => '连接失败',
			'settings.station.currentRadioSettings' => '当前电台设置',
			'settings.station.notSupportedByThisRadio' => '此电台不支持',
			'settings.station.keyerRowLabel' => '电键',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => '话音',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => '语音电键：电台中有 ${count} 个存储',
			'settings.station.antennaBands' => '频段',
			'settings.station.antennaType' => '天线类型',
			'settings.station.antennaTypeRequired' => '请选择天线类型',
			'settings.station.antennaTypes.dipole' => '偶极天线',
			'settings.station.antennaTypes.vertical' => '垂直天线',
			'settings.station.antennaTypes.yagiBeam' => '八木 / 定向天线',
			'settings.station.antennaTypes.loop' => '环形天线',
			'settings.station.antennaTypes.longWire' => '长线 / EFHW',
			'settings.station.antennaTypes.other' => '其他',
			'settings.station.keyType' => '电键类型',
			'settings.station.keyTypeRequired' => '请选择电键类型',
			'settings.station.keyTypes.straight' => '手键',
			'settings.station.keyTypes.sideswiper' => '侧摆键',
			'settings.station.keyTypes.bug' => '机械半自动键（Bug）',
			'settings.station.keyTypes.fullyAutomatic' => '全自动电键器',
			'settings.station.keyTypes.singlePaddle' => '单桨键',
			'settings.station.keyTypes.dualPaddle' => '双桨键',
			'settings.station.keyTypes.computerDriven' => '计算机驱动',
			'settings.station.keyTypes.other' => '其他',
			'settings.station.softwareIntermediaries' => '中间软件',
			'settings.station.otherBrands' => '其他品牌',
			'settings.station.otherEquipment' => '其他设备（天线、电键等）',
			'settings.station.newAntenna' => '新天线',
			'settings.station.newKey' => '新电键',
			'settings.station.newKeyer' => 'WinKeyer（K1EL 或兼容）',
			'settings.station.keyViaRadio' => ({required Object radio}) => '${radio} 中的 CAT 电键器',
			'settings.station.keyOnDevice' => ({required Object device}) => '${device} 上的电键',
			'settings.station.cwKeyerArea' => '电键区域',
			'settings.station.trackStationInfo' => '为每个 QSO 记录电台信息',
			'settings.station.includeStationInfoInAdif' => '包含在 ADIF 导出中',
			'settings.station.whatToTrack' => '记录哪些内容？',
			'settings.station.trackFieldRig' => '收发信机',
			'settings.station.trackFieldPower' => '功率',
			'settings.station.watts' => '瓦',
			'settings.station.trackFieldAntenna' => '天线',
			'settings.station.trackFieldKey' => 'CW 电键',
			'settings.station.placeholderConnectDelay' => '连接延迟 (ms)',
			'settings.station.placeholderConnectDelayDescription' => '模拟握手所需的时间。留空或 0 表示立即连接。',
			'settings.station.placeholderDropAfter' => '断开时间（秒）',
			'settings.station.placeholderDropAfterDescription' => '自行关闭连接，以测试重连流程。留空或 0 表示从不断开。',
			'settings.station.placeholderFailConnect' => '总是连接失败',
			'settings.station.placeholderConnectFailure' => '占位电台被设置为拒绝此连接',
			'settings.station.placeholderFreq' => '频率 (kHz)',
			'settings.station.placeholderFreqDescription' => '占位电台的起始频率。之后应用调谐到哪里，它就报告哪里。',
			'settings.station.placeholderMode' => '模式',
			'settings.station.placeholderModeDescription' => '占位电台的起始模式，例如 USB、CW、FT8。',
			'settings.station.placeholderPower' => '功率（瓦）',
			'settings.station.placeholderPurpose' => '用此电台记录您在记录时使用的是哪台设备',
			'settings.station.placeholderReplyDelay' => '回复延迟 (ms)',
			'settings.station.placeholderReplyDelayDescription' => '占位电台报告变化所需的时间。留空或 0 表示立即回复。',
			'settings.station.cwKeyerField' => 'CAT CW 电键器',
			'settings.station.cwKeyerFieldDescription' => '此电台是否通过 CAT 将文本键控为 CW。对于应用不认识的电台请关闭。',
			'settings.station.voiceMemories' => '语音存储',
			'settings.station.voiceMemoriesDescription' => '电台可通过 CAT 播放的语音存储数量。0 表示没有。',
			'settings.station.voiceMemoriesInvalid' => '整数，0 或更大',
			'settings.station.yaesuMeterCapture' => '捕获表头读数',
			'settings.station.yaesuBinaryMeterCaptureDescription' => '在发射时读取电台的输出功率表和 SWR 过高标志，并将原始值输出到日志。用于建立 Yaesu 未公布的刻度——这些值不会以表头形式显示。',
			'settings.station.yaesuMeterCaptureDescription' => '在发射时读取电台的 PO、SWR 和 ALC 表头，并将原始值输出到日志。用于建立 Yaesu 未公布的刻度——这些值不会以表头形式显示。',
			'settings.station.telemetryInterval' => '表头读取间隔 (ms)',
			'settings.station.telemetryIntervalDescription' => '电台发射时读取其表头的频率。留空则使用此连接能承受的最快速度，最高 200 ms。',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => '整数毫秒，${min} 到 ${max}',
			'settings.station.pollInterval' => '空闲轮询间隔 (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => '在频率和模式都没有变化时，向电台查询频率和模式的频率。留空则为 ${fallback} ms。',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => '整数毫秒，${min} 到 ${max}',
			'settings.station.advancedSettings' => '高级设置',
			'settings.station.placeholderSwr' => 'SWR 读数',
			'settings.station.placeholderSwrDescription' => '此电台在发射时 SWR 表上报告的数值。高于 1.8 时面板会警告。',
			'settings.station.placeholderSwrInvalid' => '数字，1 或更大',
			'settings.station.keyerNone' => '无',
			'settings.station.cwDialect' => 'CW 键控方言',
			'settings.station.cwDialectDescription' => '此电台接受哪种格式的 KY 命令。“无”表示不通过 CAT 进行 CW 键控。',
			'settings.station.cwDialectKenwood' => 'Kenwood（KY，补齐到 24）',
			'settings.station.cwDialectElecraft' => 'Elecraft（KY 文本）',
			'settings.station.voiceDialect' => '语音电键方言',
			'settings.station.voiceDialectDescription' => '此电台如何通过 CAT 播放语音存储。“无”表示不通过 CAT 播放语音存储。选择了方言但未设数量时，使用该方言的默认数量。',
			'settings.station.voiceDialectPb' => 'Kenwood（PB，TS-590 风格）',
			'settings.station.voiceDialectK4' => 'Elecraft K4（PB 和 DA）',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3（开关点按）',
			'settings.station.placeholderDiagnostic' => '模拟',
			'settings.station.placeholderWholeNumberInvalid' => '必须是整数，0 或更大',
			'settings.station.placeholderFreqInvalid' => '必须是以 kHz 为单位且大于零的频率',
			'settings.station.placeholderModeInvalid' => '必须是模式名称，例如 USB、CW、FT8',
			'settings.station.switchLayout' => '布局',
			'settings.station.switchLayoutDescription' => '您的电台插在开关的哪一侧。',
			'settings.station.switchLayoutRequired' => '请选择开关的接线方式',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => '开关拒绝了“${command}”（错误 ${code}）',
			'settings.station.switchBusyTransmitting' => '该端口正在发射——未更换天线',
			'settings.station.switchNoAntenna' => '无',
			'settings.station.switchAntennaFor' => ({required Object port}) => '端口 ${port} 上的天线',
			'settings.station.switchAntennaForDescription' => '您的哪副天线连接到开关的这个端口。',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} 副天线，${radios} 台电台',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} 副天线，1 台电台',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 副天线，${radios} 台电台',
			'settings.station.switchCommonPort' => '公共端',
			'settings.station.dcnAddress' => '设备地址',
			'settings.station.dcnAddressDescription' => '模块 DIP 开关上设置的地址。同轴继电器模块出厂为 2。',
			'settings.station.dcnAddressRequired' => '必须是 1 到 99 之间的设备地址',
			'settings.station.switchPortLabel' => ({required Object port}) => '端口 ${port}',
			'settings.station.switchPortAutoHint' => '跟随频段数据',
			'settings.station.switchPortTransmittingHint' => '正在发射——现在无法更改',
			'settings.station.switchCurrentStateHeader' => '当前状态',
			'settings.station.switchCurrentStateDescription' => '每个电台端口当前连接的天线。更改立即生效。',
			'settings.station.switchWiringHeader' => '接线',
			'settings.station.switchPortInhibitedHint' => '禁止发射',
			'settings.station.configUnreadable' => '无法读取此电台保存的设置。请打开其设置并重新输入，或将其移除后重新添加。',
			'settings.station.autoConnectHeld' => 'HaLo 上次连接此电台时停止了响应，因此这次没有自动连接。请按“连接”重试。',
			'settings.offlineData.title' => '离线数据',
			'settings.offlineData.noFiles' => '没有数据文件',
			'settings.offlineData.noFilesDescription' => '启用活动或查询扩展后，可在此下载其离线数据。',
			'settings.offlineData.refresh' => '刷新',
			'settings.offlineData.refreshing' => '刷新中…',
			'settings.offlineData.updateAll' => '全部更新',
			'settings.offlineData.updatingAll' => '正在更新所有数据文件…',
			'settings.offlineData.neverDownloaded' => '从未下载',
			'settings.offlineData.updatedJustNow' => '刚刚更新',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '${days} 天前更新',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '${days} 天 ${hours} 小时前更新',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '${hours} 小时前更新',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '${hours} 小时 ${minutes} 分钟前更新',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '${minutes} 分钟前更新',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => '上次下载只有 ${imported} / ${existing} 条记录，因此未被采用。刷新即可接受它。',
			'settings.offlineData.extensionsSection' => '扩展',
			'settings.profiles.notSet' => '未设置',
			'settings.profiles.personalInfo' => '个人信息',
			'settings.profiles.personalInfoNote' => '在提交需要时，这些信息可能会包含在生成的日志中',
			'settings.profiles.name' => '姓名',
			'settings.profiles.email' => '电子邮件',
			'settings.profiles.club' => '俱乐部',
			'settings.profiles.arrlSection' => 'ARRL 分部',
			'settings.profiles.racSection' => 'RAC 分部',
			'settings.profiles.section' => '分部',
			'settings.search.clear' => '清除',
			'settings.search.hint' => '搜索偏好设置',
			'settings.developer.developerModeDescription' => '启用开发者警告、调试日志和工具。',
			'settings.developer.experiments' => '实验',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已启用 ${count} 个', other: '已启用 ${count} 个', ), 
			'settings.developer.patchTrack' => '代码推送轨道',
			'settings.developer.patchTrackDescription' => '此设备跟随哪个空中代码推送轨道。越激进的轨道越早获得修复，但测试越少。代码推送在下次重启时生效。',
			'settings.developer.trackStable' => '稳定',
			'settings.developer.trackUnstable' => '不稳定',
			'settings.developer.trackBleeding' => '前沿',
			'settings.developer.checkingTrack' => ({required Object track}) => '正在“${track}”上检查代码推送…',
			'settings.developer.patchDownloaded' => '代码推送已下载——重启应用以应用。',
			'settings.developer.noNewPatch' => ({required Object track}) => '“${track}”上没有新的代码推送。',
			'settings.developer.noPatchInstalled' => '未安装代码推送——正在运行发布版本。',
			'settings.developer.runningPatch' => ({required Object patch}) => '正在运行代码推送 #${patch}。',
			'settings.developer.deepLinks' => '深层链接',
			'settings.developer.registerUrlSchemes' => '注册 URL 协议',
			'settings.developer.registerUrlSchemesDescription' => '让 com.ham2k:// 链接打开此应用副本',
			'settings.developer.registerUrlSchemesDone' => '此副本现在会打开 com.ham2k:// 链接',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => '无法注册：${error}',
			'settings.developer.systemInformation' => '系统信息',
			'settings.developer.appVersion' => '应用版本',
			'settings.developer.dataFolder' => '数据文件夹',
			'settings.developer.loading' => '（加载中…）',
			'settings.developer.panelLoadFailed' => '无法加载此设置面板。',
			'settings.developer.extDevServer' => '扩展开发服务器',
			'settings.developer.extensionSettings' => '扩展设置',
			'settings.developer.extDevServerDescription' => '从您网络上的开发服务器加载扩展，而不是使用应用内置的扩展，并在您保存时重新加载。',
			'settings.developer.extDevServerAddress' => '服务器地址',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => '连接',
			'settings.developer.extDevServerDisconnect' => '断开连接',
			'settings.developer.extDevServerConnecting' => '连接中…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '正在提供 ${count} 个扩展：${keys}', other: '正在提供 ${count} 个扩展：${keys}', ), 
			'settings.developer.extDevServerDisconnected' => '未连接',
			'settings.developer.extDevServerReconnect' => '启动时重新连接',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => '上次重新加载：${key}，于 ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个扩展构建失败', other: '${count} 个扩展构建失败', ), 
			'settings.developer.catalog' => '扩展目录',
			'settings.developer.catalogDescription' => '从其他服务器读取目录——例如在开发目录本身时使用的本地服务器。留空表示 catalog.ham2k.net。',
			'settings.developer.catalogAddress' => '目录地址',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => '目录搜索轨道',
			'settings.developer.catalogSearchStable' => '仅稳定版',
			'settings.developer.catalogSearchUnstable' => '不稳定版及以上',
			'settings.developer.catalogSearchBleeding' => '前沿版及以上',
			'settings.about.notices' => '通知与消息',
			'settings.about.noticesDescription' => '公告和状态消息',
			'settings.about.releaseNotes' => '发布说明',
			'settings.about.copiedVersion' => '已将版本详情复制到剪贴板',
			'settings.panels.settings' => '应用偏好设置',
			'settings.panels.settingsDescription' => '按您的方式使用应用',
			'settings.panels.commonSettings' => '常用偏好设置',
			'settings.panels.syncDescription' => '备份日志并在设备间同步',
			'settings.panels.accountsDescription' => '服务凭证、离线数据等',
			'settings.panels.extensions' => '扩展与功能',
			'settings.panels.extensionsDescription' => '活动、竞赛、仪表板面板及更多功能',
			'settings.panels.profilesDescription' => '操作员呼号和电台配置文件',
			'settings.panels.stationProfiles' => '电台配置文件',
			'settings.panels.developerSettings' => '开发者设置',
			'settings.panels.developerSettingsDescription' => '调试和开发工具',
			'settings.panels.about' => '关于',
			'settings.panels.aboutDescription' => '版本、鸣谢和法律信息',
			'settings.panels.unavailableTitle' => '部分设置不可用',
			'settings.panels.unavailableText' => '扩展运行时启动失败，因此缺少由扩展提供的设置。',
			'settings.panels.station' => '电台配置',
			'settings.panels.stationDescription' => 'CAT 控制及更多选项',
			'settings.panels.peers' => '对等设备',
			'settings.panels.peersDescription' => '连接附近的其他设备',
			'settings.showMoreSettings' => '显示更多设置',
			'settings.numberFormat' => '数字格式',
			'settings.numberFormatOpts.locale' => '跟随系统设置',
			'settings.numberFormatOpts.period' => '始终使用句点作为小数点',
			'settings.numberFormatOpts.comma' => '始终使用逗号作为小数点',
			'settings.numberFormatDescription.locale' => ({required Object separator}) => '系统设置（使用${separator}作为小数点）',
			'settings.numberFormatDescription.period' => '始终使用句点作为小数点',
			'settings.numberFormatDescription.comma' => '始终使用逗号作为小数点',
			'settings.numberFormatSeparators.comma' => '逗号',
			'settings.numberFormatSeparators.period' => '句点',
			'settings.gridPrecision' => '网格精度',
			'settings.gridPrecisionOpts.six' => '6 位 (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 位 (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 位',
			'settings.gridPrecisionDescription.eight' => '8 位',
			'commands.enableSyncFirst' => '请先在设置中启用同步。',
			'commands.fullResyncStarted' => '已开始完全重新同步——本地数据已先行备份。',
			'commands.noDataFilesMatched' => ({required Object target}) => '没有与“${target}”匹配的数据文件。',
			'commands.reloadFailed' => ({required Object error}) => '重新加载失败：${error}',
			'commands.reloadingAll' => '正在重新加载所有数据文件…',
			'commands.reloadingTarget' => ({required Object target}) => '正在重新加载 ${target} 数据文件…',
			'commands.unknownExperiment' => ({required Object token}) => '未知实验“${token}”',
			'commands.experimentEnabled' => ({required Object name}) => '已启用 ${name}',
			'commands.experimentDisabled' => ({required Object name}) => '已禁用 ${name}',
			'commands.sentryTestSent' => '测试错误报告已发送到 Sentry',
			'commands.sentryTestLocalOnly' => '此构建中已禁用 Sentry——测试错误仅在本地记录',
			'commands.noOperationOpen' => '该命令需要打开一个操作',
			'commands.unknownSegmentKind' => ({required Object kind}) => '不知道如何标记“${kind}”',
			'commands.operationAlreadyStarted' => '此操作已有开始标记',
			'commands.couldNotOpenLocation' => '已添加休息，但无法打开位置界面',
			'commands.noTestOperations' => '没有可清除的测试操作',
			'commands.purgeTestsUnavailable' => 'PURGETESTS 需要显示确认对话框，但此处无法显示',
			'commands.syncAllUnavailable' => 'SYNCALL 需要显示确认对话框，但此处无法显示',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已清除 ${count} 个测试操作', other: '已清除 ${count} 个测试操作', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '已清除 ${purged} / ${total} 个测试操作——其余失败；请再次运行 PURGETESTS',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已清除 ${count} 个不属于任何操作的测试通联', other: '已清除 ${count} 个不属于任何操作的测试通联', ), 
			'commands.purgeTestsContactsFailed' => '已清除测试操作，但不属于任何操作的测试通联清除失败；请再次运行 PURGETESTS',
			'commands.purgeTestsNothingToDo' => '未清除任何内容',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '已移除 ${removed} / ${total} 个测试操作——其余失败；请再次点击“查看”',
			'commands.receivedPurgesFailed' => '无法移除这些测试操作——请再次点击“查看”',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个测试操作已在另一台设备上移除', other: '${count} 个测试操作已在另一台设备上移除', ), 
			'commands.receivedPurgesReview' => '查看',
			'commands.settingOn' => '开',
			'commands.settingOff' => '关',
			'commands.settingEmpty' => '（空）',
			'commands.settingSecretSet' => '（已设置）',
			'commands.settingSecretUnset' => '（未设置）',
			'commands.settingSelectedCount' => ({required Object count}) => '已选 ${count} 个',
			'commands.settingExpectsOnOff' => 'on 或 off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => '以下之一：${choices}',
			'commands.settingExpectsNumber' => '一个数字',
			'commands.settingVanished' => ({required Object label}) => '“${label}”已不再可用',
			'commands.noCwKeyer' => '没有已连接的电台能键控 CW',
			'commands.noKeyer' => '没有已连接的电台能键控 CW 或播放语音存储',
			'commands.keyerNeedsOperation' => '请打开一个操作以使用 CW 电键器',
			'commands.keyerExperimentOff' => 'CW 键控已关闭——使用 EXP KEYER 开启',
			'commands.esmExperimentOff' => '回车发送消息已关闭——使用 EXP ESM 开启',
			'commands.cwSending' => ({required Object text}) => '正在发送 CW：${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW 消息 F${n}：${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW 消息 F${n} 未发送：扩展尚未就绪',
			'commands.settingNotStored' => ({required Object label}) => '“${label}”不接受该值',
			'commandDialog.hint' => '搜索呼号或输入命令',
			'commandDialog.noResults' => ({required Object text}) => '没有与“${text}”匹配的内容',
			'commandDialog.sectionCommands' => '命令',
			'commandDialog.sectionGoTo' => '转到',
			'commandDialog.sectionOperations' => '操作',
			'commandDialog.goHome' => '主页',
			'commandDialog.goSettings' => '设置',
			'commandDialog.goNewOperation' => '新操作',
			'commandDialog.runTyped' => ({required Object text}) => '运行“${text}”',
			'commandDialog.sectionSuggestions' => '试试',
			'commandDialog.lookingUp' => '正在查询呼号…',
			'commandDialog.blockedByPane' => '面板或对话框打开时无法使用命令',
			'expiredBuild.title' => '此构建已过期',
			'expiredBuild.body' => '请访问 ham2k.com 获取较新版本。',
			'expiredBuild.visit' => '访问 ham2k.com',
			'expiredBuild.dismiss' => '仍然继续',
			'staleness.codePushFloorTitle' => '有一个重要更新等待应用',
			'staleness.codePushFloorBody' => '此版本包含一项您尚未获得的修复。',
			'staleness.restartToApply' => '重启应用以应用。',
			'staleness.quitAndReopen' => '退出应用并重新打开以应用。',
			'staleness.reopenToApply' => '关闭应用并重新打开以应用。',
			'staleness.ignoreForNow' => '暂时忽略',
			'spotting.noQsoYet' => '尚未记录可 Spot 的 QSO。',
			'spotting.setFrequencyFirst' => '请先设置频率。',
			'spotting.nothingToSpot' => '没有可 Spot 的内容——此处没有扩展提供 Spot 功能。',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} 失败：${message}',
			'spotting.unknownError' => '未知错误',
			'spotting.notSent' => 'Spot 未发送。',
			'spotting.notRefreshedOffline' => '没有网络连接——信号未刷新',
			'dataFiles.downloading' => '下载中…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '无法下载 ${name}',
			'dataFiles.downloadFailedWebHint' => '这可能是网络问题，也可能是此链接的主机不支持从网页浏览器直接下载。请尝试桌面或移动应用，或换一个托管位置。',
			'dataFiles.downloadTimedOut' => '服务器响应时间过长。请稍后重试。',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} 返回了错误（HTTP ${status}）。请稍后重试。',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} 无法提供此文件（HTTP ${status}）。请检查其地址是否仍然正确。',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '无法处理 ${name}',
			'dataFiles.importTooSmall' => ({required Object existing, required Object imported}) => '下载的数据只有此设备上 ${existing} 条记录中的 ${imported} 条，因此保留了缺少的记录。在 设置 › 离线数据 中刷新即可强制接受。',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已为 ${label} 导入 ${count} 条记录。', other: '已为 ${label} 导入 ${count} 条记录。', ), 
			'dataFiles.importedData' => ({required Object label}) => '已为 ${label} 导入数据。',
			'dataFiles.cleanedUpTitle' => '已清理扩展数据',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已移除已禁用扩展的 ${count} 个数据文件的数据。', other: '已移除已禁用扩展的 ${count} 个数据文件的数据。', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} 条记录',
			'dataFiles.definitionUnavailable' => '文件来源未提供定义——其扩展可能正在重启或配置有误。请稍后重试。',
			'updates.updateAvailable' => '有可用更新',
			'updates.newVersionAvailable' => ({required Object version}) => '有新版本（${version}）可用。',
			'updates.getIt' => '获取',
			'updates.ok' => '确定',
			'updates.updateReady' => '更新已就绪',
			'updates.restartToApply' => '更新已下载。重启以应用。',
			'updates.appliesNextLaunch' => '更新已下载。将在下次打开应用时生效。',
			'updates.restartNow' => '立即重启',
			'updates.reloadToUpdate' => '此页面有较新版本可用。重新加载即可获取。',
			'updates.reloadNow' => '立即重新加载',
			'updates.checkForUpdates' => '检查更新',
			'updates.checkingForUpdates' => '检查更新中…',
			'updates.upToDate' => '已是最新',
			'updates.automaticChecks' => '自动检查',
			'updates.automaticChecksDescription' => '从下次启动应用起，在后台查找新版本',
			'extensionService.runtimeNotReady' => '扩展运行时尚未就绪。',
			'extensionService.testFailed' => ({required Object error}) => '测试失败：${error}',
			'extensionService.connectedAs' => ({required Object identity}) => '已连接为 ${identity}',
			'extensionService.invalidFieldConfiguration' => '字段配置无效',
			'extensionService.invalidValue' => '无效值',
			'extensionService.validationError' => ({required Object error}) => '验证错误：${error}',
			'extensionService.actionFailed' => ({required Object error}) => '操作失败：${error}',
			'extensionService.commandFailed' => '命令运行失败',
			'extensionService.reportUnavailable' => '目前无法发送报告',
			'extensionService.stashUnavailable' => '目前无法访问 Ham2K File Stash',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} 在计时器中花费了太多时间。在扩展重启之前，其计时器已停止。',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name} 的计时器反复失败。在扩展重启之前，其计时器已停止。',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} 卡在了一个计时器中。在扩展重启之前，其计时器已停止。',
			'operationLocationScreen.title' => '操作位置',
			'operationLocationScreen.selectedLocation' => '所选位置',
			'operationLocationScreen.gridSquare' => '梅登海德网格位置指示器',
			'operationLocationScreen.gridInvalid' => '需要 4、6、8 或 10 个字符，如 FN31pr',
			'operationLocationScreen.suggestedLocations' => '建议位置',
			'operationLocationScreen.deviceGps' => '设备 GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => '来自 ${device} 的 GPS',
			'operationLocationScreen.locating' => '定位中…',
			'operationLocationScreen.gpsUnavailable' => '位置不可用',
			'operationLocationScreen.permissionDenied' => '位置权限被拒绝',
			'operationLocationScreen.permissionBlocked' => '位置权限被阻止',
			'operationLocationScreen.moreDetails' => '更多详情',
			'operationLocationScreen.stateOrProvince' => '州或省（可选）',
			'operationLocationScreen.controlsUnavailableTitle' => '活动控件不可用',
			'operationLocationScreen.controlsUnavailableReason' => '这些参考仍可使用；只是无法访问其活动。',
			'operationLocationScreen.controlsUnavailableRetry' => '重试',
			'operationLocationScreen.county' => '县（可选）',
			'versionLabel.version' => ({required Object version}) => '版本 ${version}',
			'versionLabel.patch' => ({required Object patch}) => '补丁 ${patch}',
			'versionLabel.build' => ({required Object build}) => '构建 ${build}',
			'notices.emptyHistory' => '暂无通知',
			'notices.webStorageInMemory' => '此浏览器无法提供持久存储——日志仅保存在内存中，关闭此标签页时将会丢失。请使用最新版的 Chrome、Firefox、Safari 或 Edge。',
			'notices.webStorageUnreliable' => '此浏览器正在使用后备存储，在多个标签页下并不安全——请只保持一个标签页打开，并保持同步开启。',
			'notices.logFromNewerBuildTitle' => '此日志需要较新的版本',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => '您的日志由较新版本的 HaLo 写入（存储版本 ${storage}；此版本只能识别 ${understood}），因此无法打开，新的通联也不会被保存。请重新安装较新的版本——或者，如果您确实想运行此构建，请将其指向另一个数据文件夹。日志位于 ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => '您的日志由较新版本的 HaLo 写入（存储版本 ${storage}；此版本只能识别 ${understood}），因此无法打开，新的通联也不会被保存。请改用那个较新的版本打开此日志。',
			'notices.preferencesRestoredTitle' => '已从备份恢复设置',
			'notices.preferencesRestored' => '无法读取设置文件，因此 HaLo 恢复了它最近一份完好的副本。您在上一次会话中更改的内容可能需要重新设置。无法读取的文件保存在旁边，名为 shared_preferences.corrupt-….json。',
			'notices.preferencesResetTitle' => '设置已重置',
			'notices.preferencesReset' => '无法读取设置文件，且没有可用的备份，因此 HaLo 以默认设置启动。无法读取的文件保存在应用的数据文件夹中，名为 shared_preferences.corrupt-….json。',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '未自动连接 ${name}',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo 上次开始连接 ${name} 时停止了响应，因此这次没有连接它，以免再次出现问题。请检查电台是否已开机、线缆是否已插好，然后在设置中对其按“连接”。',
			'syncAccount.anonymous' => ({required Object id}) => '匿名账户 (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email}（待确认）',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email}（待确认 - #${id}）',
			'deepLink.needsAnOperation' => '请先开始一个操作，然后重新发送该通联',
			'deepLink.waitingInOperation' => '该通联正在此界面后面的操作中等待',
			'deepLink.unknownActivities' => ({required Object refs}) => '此设备没有对应 ${refs} 的活动，因此未添加这些参考',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => '无法访问您的活动，因此未添加 ${refs}——请重试该链接',
			'confirmDevice.title' => '确认设备',
			'confirmDevice.codePrompt' => '输入想要加入此账户的设备上显示的代码。',
			'confirmDevice.code' => '代码',
			'confirmDevice.lookUp' => '查找',
			'confirmDevice.codeNotFound' => '没有与该代码匹配的请求。代码在 10 分钟后过期——请让另一台设备生成新的代码。',
			'confirmDevice.linkExpired' => '该链接已过期。请让另一台设备显示新的二维码。',
			'confirmDevice.areYouSure' => ({required Object device}) => '将 ${device} 链接到此账户？',
			'confirmDevice.unnamedDevice' => '一台未命名的设备',
			'confirmDevice.grantWarning' => '它将能够读取和更改此账户中的每个操作和 QSO。',
			'confirmDevice.needsSyncTitle' => '此设备尚未同步',
			'confirmDevice.needsSyncText' => '请先开启 Ham2K Log Filer 同步并将此设备链接到账户，然后才能接纳其他设备。',
			'confirmDevice.malformedRequest' => '同步服务器发送了此应用无法读取的请求。请让另一台设备重试。',
			'confirmDevice.linkIt' => '链接设备',
			'switchAccounts.noAccountDetails' => '尚无账户详情',
			'switchAccounts.currentAccount' => '当前账户',
			'switchAccounts.otherAccounts' => '其他账户',
			'switchAccounts.linkToAnother' => '链接到其他账户',
			'switchAccounts.linkWithSibling' => '与其他 Ham2K 应用链接',
			'switchAccounts.linkWithPolo' => '与旧版中的账户链接',
			'switchAccounts.linkWithSiblingDescription' => '您安装了另一个 Ham2K 应用。与该应用使用的账户链接。',
			'switchAccounts.siblingPrompt' => ({required Object app}) => '请在 ${app} 中批准请求，然后返回这里。',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '再次打开 ${app}',
			'switchAccounts.siblingNoGrant' => '没有成功？请再次打开它，或返回并用其他方式链接。',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '无法打开 ${app}。',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => '链接已过期，新的链接已准备好——请再次打开 ${app}。',
			'switchAccounts.tryAgain' => '重试',
			'switchAccounts.linkWithQr' => '用二维码链接',
			'switchAccounts.linkWithQrDescription' => '从已在使用该账户的设备上扫描',
			'switchAccounts.linkWithEmail' => '用电子邮件地址链接',
			'switchAccounts.linkWithEmailDescription' => '通过代码或电子邮件链接确认',
			'switchAccounts.enterEmailPrompt' => '输入您希望此设备使用的账户的电子邮件地址。',
			'switchAccounts.emailAddress' => '电子邮件地址',
			'switchAccounts.linkAccount' => '链接账户',
			'switchAccounts.copiedCode' => '已将代码复制到剪贴板',
			'switchAccounts.copyCode' => '复制代码',
			'switchAccounts.codePrompt' => ({required Object email}) => '在已与 ${email} 链接的设备上打开 Ham2K 应用，并输入此代码以批准请求：',
			'switchAccounts.waitingForConfirmation' => '等待确认…',
			'switchAccounts.sendEmailInstead' => '改为发送确认邮件',
			'switchAccounts.emailSent' => ({required Object email}) => '已向 ${email} 发送电子邮件。请打开邮件并确认请求，以链接此设备。',
			'switchAccounts.resendEmail' => '重新发送邮件',
			'switchAccounts.qrPrompt' => '从已链接到目标账户的设备上扫描此二维码——例如用您手机上的 Ham2K Portable Logger。',
			'switchAccounts.serverUnreachable' => '无法连接同步服务器。请稍后重试。',
			'switchAccounts.emailRequired' => '请输入要链接的电子邮件地址。',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => '未找到 ${email} 的账户。',
			'switchAccounts.serverRejected' => ({required Object error}) => '同步服务器拒绝了请求：${error}',
			'switchAccounts.noLinkCode' => '同步服务器没有返回链接代码。请稍后重试。',
			'switchAccounts.noConfirmationCode' => '同步服务器没有发送确认代码。请稍后重试。',
			'switchAccounts.switchNotAccepted' => '该账户不接受切换。请改用电子邮件地址链接。',
			'switchAccounts.requestFailed' => '与同步服务器通信时出了问题。请稍后重试。',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个 QSO', other: '${count} 个 QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个操作', other: '${count} 个操作', ), 
			'adifImport.title' => '从 ADIF 导入 QSO',
			'adifImport.reading' => ({required Object filename}) => '正在读取 ${filename}…',
			'adifImport.dropHint' => '拖放 ADIF 文件以导入',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '此文件中有 ${count} 个 QSO', other: '此文件中有 ${formatted} 个 QSO', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个已在您的日志中', other: '${formatted} 个已在您的日志中', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '将导入 ${count} 个', other: '将导入 ${formatted} 个', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个新通联', other: '${formatted} 个新通联', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个将与现有通联合并', other: '${formatted} 个将与现有通联合并', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个无法导入（没有呼号）', other: '${formatted} 个无法导入（没有呼号）', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个需要仔细检查', other: '${formatted} 个需要仔细检查', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个通联的参考无法恢复', other: '${formatted} 个通联的参考无法恢复', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个通联的 ${programs} 参考可能不完整', other: '${formatted} 个通联的 ${programs} 参考可能不完整', ), 
			'adifImport.stackingTypesUnknown' => '合并的通联可能会丢失一个参考——活动无法说明哪些类型可以叠加。取消并重试可避免此问题。',
			'adifImport.nothingToImport' => '此文件中没有可导入的内容',
			'adifImport.confirm' => '导入',
			'adifImport.importing' => ({required Object filename}) => '正在导入 ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '已从 ${filename} 导入 ${count} 个通联', other: '已从 ${filename} 导入 ${formatted} 个通联', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '无法导入 ${filename}：${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} 看起来不是 ADIF 文件',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => '警告：此 ADIF 包含来自 ${calls} 的 QSO，但如果继续，它们将作为 ${station} 导入。',
			'adifImport.stationCallJoin' => ' 和 ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('zh'))(count, one: '${count} 个没有日期，无法导入', other: '${formatted} 个没有日期，无法导入', ), 
			'adifImport.activationFound' => ({required Object refs}) => '此文件记录了 ${refs} 的一次激活。',
			'adifImport.addActivation' => '将其添加到此操作',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => '只有 ${written} / ${planned} 个得以应用——在您决定期间日志发生了变化。',
			'adifImport.busy' => '已有导入正在进行。请等待其完成后再开始新的导入。',
			'adifImport.oneFileOnly' => '一次只能拖放一个 ADIF 文件——文件的导入顺序决定了哪些数据优先。',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} 中的 QSO 超过 ${limit} 个，这是一个操作一次能导入的上限。',
			'offline.statusOffline' => '互联网：离线',
			'offline.statusOnline' => '互联网：已连接',
			'offline.noRoute' => '完全没有网络连接。',
			'offline.unreachable' => '网络已连接，但没有服务器响应——通常是浏览器中有登录页面在等待。',
			'offline.reachable' => '所有服务均正常响应。',
			'offline.whatStops' => '查询、信号和数据文件已暂停。记录和附近设备同步不受影响。',
			'offline.servicesTitle' => '服务',
			'offline.noServices' => '还没有服务报告状态。',
			'offline.lastSuccess' => ({required Object when}) => '上次响应于 ${when} 前',
			'offline.neverSucceeded' => '尚未响应',
			'offline.nextAttempt' => ({required Object when}) => '${when} 后再次尝试',
			'offline.nextAttemptNow' => '即将再次尝试',
			'offline.retry' => '立即重试',
			'offline.retrying' => '尝试中…',
			'offline.retryReached' => '已恢复在线。',
			'offline.retryUnreachable' => '仍然没有响应。',
			'offline.retryNotAttempted' => '目前没有需要发送的内容。',
			'offline.retryThrottled' => '刚刚尝试过——请稍等片刻。',
			'offline.retryDisabled' => '同步已关闭，因此没有可用于探测的服务。',
			'offline.syncService' => 'Ham2K LoFi 同步',
			'offline.retryInFlight' => '正在尝试——请稍候。',
			'exportSettings.defaultsDescription' => '所有导出的基本设置，参考活动和其他活动分别使用各自的文件名和标题模板。每种导出类型都可以提供自己的默认设置或自定义设置。',
			'exportSettings.referenceActivities' => '参考活动',
			'exportSettings.otherActivities' => '其他活动',
			'exportSettings.adifFields' => 'ADIF 字段',
			'exportSettings.loadFailed' => '无法加载导出设置。',
			'exportSettings.retry' => '重试',
			'exportSettings.compactFileNamesDescriptionOn' => '简易文件名，如 N0CALL@US-1234-20260715.adi。',
			'exportSettings.compactFileNamesDescriptionOff' => '描述性文件名，如 2026-07-15 N0CALL at US-1234.adi。',
			'exportSettings.includePrivateDataDescriptionOn' => '在 ADIF 文件中包含姓名、地址、电子邮件、备注和精确位置。',
			'exportSettings.includePrivateDataDescriptionOff' => '省略姓名、地址、电子邮件和备注；位置仅精确到 6 位网格。',
			'exportSettings.includeLookupDataDescriptionOn' => '包含来自呼号查询服务的信息。',
			'exportSettings.includeLookupDataDescriptionOff' => '省略来自呼号查询服务的信息；保留手动输入的值。',
			'exportSettings.customTemplatesDescriptionOn' => '您的自定义模板已启用，可在下方编辑。',
			'exportSettings.customTemplatesDescriptionOff' => '默认模板已启用。您的自定义模板将保留以备后用。',
			'exportSettings.type' => '导出类型',
			'exportSettings.defaults' => '默认',
			'exportSettings.includeLookupData' => '包含查询数据',
			'exportSettings.customTemplates' => '自定义模板',
			'exportSettings.filenameTemplate' => '文件名模板',
			'exportSettings.compactFilenameTemplate' => '简易文件名模板',
			'exportSettings.titleTemplate' => '标题模板',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO 备注',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO 评论',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL 消息',
			'exportSettings.shared' => '设置适用于使用此导出类型的所有扩展。',
			'exportSettings.defaultTemplates' => '开启“自定义模板”即可编辑此类型的模板。',
			'templateEditor.previewLabel' => '预览：',
			_ => null,
		} ?? switch (path) {
			'templateEditor.reset' => '重置',
			'templateEditor.docs' => '模板文档',
			'templateEditor.preview' => '示例预览',
			'templateEditor.reference' => '模板参考',
			'templateEditor.attributes' => '可用属性',
			'templateEditor.filters' => '过滤器',
			'templateEditor.flowControl' => '流程控制',
			'templateEditor.unavailable' => '扩展就绪之前无法预览。',
			'templateEditor.empty' => '（输出为空）',
			_ => null,
		};
	}
}
