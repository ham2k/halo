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
class TranslationsJa extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsJa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsJa _root = this; // ignore: unused_field

	@override 
	TranslationsJa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsJa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ja common = _Translations$common$ja._(_root);
	@override late final _Translations$onboarding$ja onboarding = _Translations$onboarding$ja._(_root);
	@override late final _Translations$startScreen$ja startScreen = _Translations$startScreen$ja._(_root);
	@override late final _Translations$testerOverlay$ja testerOverlay = _Translations$testerOverlay$ja._(_root);
	@override late final _Translations$extensionsPanel$ja extensionsPanel = _Translations$extensionsPanel$ja._(_root);
	@override late final _Translations$home$ja home = _Translations$home$ja._(_root);
	@override late final _Translations$chase$ja chase = _Translations$chase$ja._(_root);
	@override late final _Translations$dialogs$ja dialogs = _Translations$dialogs$ja._(_root);
	@override late final _Translations$operation$ja operation = _Translations$operation$ja._(_root);
	@override late final _Translations$map$ja map = _Translations$map$ja._(_root);
	@override late final _Translations$mapsView$ja mapsView = _Translations$mapsView$ja._(_root);
	@override late final _Translations$activitiesView$ja activitiesView = _Translations$activitiesView$ja._(_root);
	@override late final _Translations$loggingControls$ja loggingControls = _Translations$loggingControls$ja._(_root);
	@override late final _Translations$formChrome$ja formChrome = _Translations$formChrome$ja._(_root);
	@override late final _Translations$qsoEditForm$ja qsoEditForm = _Translations$qsoEditForm$ja._(_root);
	@override late final _Translations$qsoList$ja qsoList = _Translations$qsoList$ja._(_root);
	@override late final _Translations$loggingPanel$ja loggingPanel = _Translations$loggingPanel$ja._(_root);
	@override late final _Translations$callInfo$ja callInfo = _Translations$callInfo$ja._(_root);
	@override late final _Translations$settings$ja settings = _Translations$settings$ja._(_root);
	@override late final _Translations$commands$ja commands = _Translations$commands$ja._(_root);
	@override late final _Translations$commandDialog$ja commandDialog = _Translations$commandDialog$ja._(_root);
	@override late final _Translations$keyboardShortcuts$ja keyboardShortcuts = _Translations$keyboardShortcuts$ja._(_root);
	@override late final _Translations$expiredBuild$ja expiredBuild = _Translations$expiredBuild$ja._(_root);
	@override late final _Translations$staleness$ja staleness = _Translations$staleness$ja._(_root);
	@override late final _Translations$spotting$ja spotting = _Translations$spotting$ja._(_root);
	@override late final _Translations$dataFiles$ja dataFiles = _Translations$dataFiles$ja._(_root);
	@override late final _Translations$updates$ja updates = _Translations$updates$ja._(_root);
	@override late final _Translations$extensionService$ja extensionService = _Translations$extensionService$ja._(_root);
	@override late final _Translations$operationLocationScreen$ja operationLocationScreen = _Translations$operationLocationScreen$ja._(_root);
	@override late final _Translations$versionLabel$ja versionLabel = _Translations$versionLabel$ja._(_root);
	@override late final _Translations$notices$ja notices = _Translations$notices$ja._(_root);
	@override late final _Translations$syncAccount$ja syncAccount = _Translations$syncAccount$ja._(_root);
	@override late final _Translations$deepLink$ja deepLink = _Translations$deepLink$ja._(_root);
	@override late final _Translations$confirmDevice$ja confirmDevice = _Translations$confirmDevice$ja._(_root);
	@override late final _Translations$switchAccounts$ja switchAccounts = _Translations$switchAccounts$ja._(_root);
	@override late final _Translations$qsonImport$ja qsonImport = _Translations$qsonImport$ja._(_root);
	@override late final _Translations$adifImport$ja adifImport = _Translations$adifImport$ja._(_root);
	@override late final _Translations$offline$ja offline = _Translations$offline$ja._(_root);
	@override late final _Translations$exportSettings$ja exportSettings = _Translations$exportSettings$ja._(_root);
	@override late final _Translations$templateEditor$ja templateEditor = _Translations$templateEditor$ja._(_root);
}

// Path: common
class _Translations$common$ja extends Translations$common$en {
	_Translations$common$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get save => '保存';
	@override String get ok => 'OK';
	@override String get cancel => 'キャンセル';
	@override String get delete => '削除';
	@override String get create => '作成';
	@override String get error => 'エラー';
	@override String get close => '閉じる';
	@override String get done => '完了';
	@override String get callsign => 'コールサイン';
	@override String get clear => 'クリア';
	@override String get dismiss => '閉じる';
	@override String get copyDetails => '詳細をコピー';
	@override String get expand => '展開';
	@override String get collapse => '折りたたむ';
}

// Path: onboarding
class _Translations$onboarding$ja extends Translations$onboarding$en {
	_Translations$onboarding$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Ham2K Portable Loggerへようこそ！';
	@override String get welcomeTitleDesktop => 'Ham2K Power Loggerへようこそ！';
	@override String get welcomeBody => 'ご利用に合わせて設定するため、いくつか質問させてください。';
	@override String get skip => 'スキップ';
	@override String get kContinue => '続行';
	@override String get back => '戻る';
	@override String get next => '次へ';
	@override String get done => '完了';
	@override String get callsignTitle => 'あなたのコールサインは？';
	@override String get callsignBody => 'このアプリを活用するには、アマチュア無線技士の免許が必要です';
	@override String get callsignLabel => 'オペレーターのコールサイン';
	@override String get alreadyHaveAccount => 'すでにアカウントをお持ちですか？';
	@override String get foundSiblingTitle => '既存のアカウントにリンクしますか？';
	@override String foundSiblingBody({required Object app}) => 'このデバイスで${app}が見つかりました。このアプリを同じアカウントにリンクすると、コールサインとログが引き継がれます。';
	@override String get foundPoloBody => 'このデバイスで旧バージョンのHam2K Portable Loggerが見つかりました。このアプリを同じアカウントにリンクすると、コールサインとログが引き継がれます。';
	@override String get foundSiblingsBody => 'このデバイスで他のHam2Kアプリが見つかりました。このアプリをいずれかのアカウントにリンクすると、コールサインとログが引き継がれます。';
	@override String linkWithApp({required Object app}) => '${app}とリンク';
	@override String get linkWithPolo => '旧バージョンのアカウントとリンク';
	@override String get setUpFresh => '新規にセットアップ';
	@override String get activitiesTitle => 'お気に入りのアクティビティ';
	@override String get activitiesBody => 'これらの人気のアクティベーションプログラムに興味はありますか？';
	@override String get activitiesFooter => '（設定にもっとオプションがあります）';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => 'クラウド同期';
	@override String get syncBody => 'Ham2K Log Filerはログのバックアップをクラウドに保存し、Ham2Kアプリを使っているすべてのデバイス間で同期します。';
	@override String get syncPricing => '無料です！有料サブスクリプションにすると、さらに高速になります。';
	@override String get syncLabel => 'クラウド同期を有効にする';
	@override String get syncOffWarning => '警告：デバイスの故障や紛失などでオペレーションデータを失う可能性が高くなります。';
	@override String get notNow => '今はしない';
	@override String get consentTitle => 'データとプライバシー';
	@override String get consentUsageBody => 'アプリの改善に役立てるため、パフォーマンス、クラッシュ、アプリ使用状況のデータを収集させてください。';
	@override String get consentUsageLabel => 'アプリ使用データを共有';
	@override String get consentOperationBody => '一部の機能では、オペレーションデータを他のユーザーと共有する場合があります。いつでもオプトアウトできます。';
	@override String get consentOperationLabel => 'オペレーションデータを共有';
	@override String get finishingSetup => 'セットアップを完了しています — 参照データをダウンロード中…';
}

// Path: startScreen
class _Translations$startScreen$ja extends Translations$startScreen$en {
	_Translations$startScreen$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get credits => 'KI2Dと仲間たちによる';
}

// Path: testerOverlay
class _Translations$testerOverlay$ja extends Translations$testerOverlay$en {
	_Translations$testerOverlay$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get tape => '注意：工事中';
	@override String get warningTitle => 'このアプリは開発中です';
	@override String get warningBody => 'ほとんどの機能はまだ路面が凸凹で、あちこちに段差があります。定期的にアップデートを確認してください。';
	@override String whatsNew({required Object build}) => 'ビルド${build}の新機能';
	@override String get thanks => 'このアプリの改善のために、ご自身のログを危険にさらしてくださりありがとうございます！';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$ja extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'アクティビティ';
	@override String get categoryAward => 'アワード';
	@override String get categoryContest => 'コンテスト';
	@override String get categoryLookup => 'コールサイン検索';
	@override String get categorySpots => 'スポットソース';
	@override String get categoryDashboard => 'ダッシュボードパネル';
	@override String get categoryOther => 'その他の拡張機能';
	@override String get searchHint => '拡張機能を検索';
	@override String get applying => '拡張機能の変更を適用しています。しばらくお待ちください…';
	@override String get noMatches => '検索に一致する拡張機能はありません';
	@override String get installFromFile => 'ファイルからインストール…';
	@override String installVersion({required Object version}) => 'バージョン ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => 'スクリーンショット ${n}/${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => '前のスクリーンショット';
	@override String get nextScreenshot => '次のスクリーンショット';
	@override String get screenshotUnavailable => 'スクリーンショットを表示できません';
	@override String get canReach => 'この拡張機能がアクセスできるもの';
	@override String canHoldConnection({required Object host}) => '${host}（常時接続）';
	@override String get canHoldLocalConnection => 'ローカルネットワーク上のデバイス（常時接続）';
	@override String get canUseLocation => 'あなたの位置情報';
	@override String get canReadRadio => '無線機（周波数とモードの読み取り）';
	@override String get canControlRadio => '無線機（制御と送信：チューニング、出力、CW、ボイスメモリー、PTT）';
	@override String get canCommandRadioRaw => '無線機（固有プロトコルでの任意のコマンド送信。送信や設定変更を行うものも含む）';
	@override String get canReadCluster => 'DXクラスター（あなたとしてログインし、受信内容の読み取り）';
	@override String get canSpotCluster => 'DXクラスター（あなたとしてログインし、あなたの名前でのスポット投稿）';
	@override String get canCommandCluster => 'DXクラスター（あなたとしてログインし、あなたの名前での任意のコマンド送信）';
	@override String get canSetUserAgent => 'サーバーに対して独自の名前を名乗る';
	@override String get canChangeSettings => '設定（コマンドによる変更：あらゆる設定、開発者モード、実験）';
	@override String get noCapabilities => 'アプリ外へのアクセスは一切要求しません。';
	@override String get sandboxNote => '拡張機能はサンドボックス内で動作します。ファイルにはアクセスできず、ここに記載されたもの以外のネットワークにも接続できません。';
	@override String get installAction => 'インストール';
	@override String get updateAction => 'アップデート';
	@override String get installFailed => 'その拡張機能をインストールできませんでした';
	@override String get installedBadge => 'インストール済み';
	@override String get uninstallAction => '削除';
	@override String uninstallTitle({required Object name}) => '${name}を削除しますか？';
	@override String get uninstallBody => 'この拡張機能とその設定が削除されます。ログはそのまま残ります。';
	@override String installedMessage({required Object name}) => '${name}をインストールしました';
	@override String get installDownloading => 'ダウンロード中…';
	@override String get installWaiting => 'インストール待機中…';
	@override String get installInstalling => 'インストール中…';
	@override String get installAwaitingApproval => '承認を待っています…';
	@override String installAlreadyRunning({required Object name}) => '${name}はすでにインストール中です。';
	@override String updatedTo({required Object version}) => '${version}にアップデートしました';
	@override String installIncomplete({required Object name}) => '${name}のインストールが完了しませんでした。再インストールが必要な場合があります。';
	@override String uninstallFailed({required Object name}) => '${name}を削除できませんでした';
	@override String installedFrom({required Object source}) => '${source}からダウンロード';
	@override String get dropHint => '.h2kext拡張機能をドロップしてインストール';
	@override String get dropOneOnly => '拡張機能は1つずつドロップしてください。';
	@override String downloadFailed({required Object source, required Object status}) => 'その拡張機能について${source}が${status}を返しました。';
	@override String get downloadTooLarge => 'そのダウンロードは拡張機能としては大きすぎます。';
	@override String get downloadNotSecure => 'ダウンロードが安全でない場所にリダイレクトされました。';
	@override String get catalogSection => 'カタログ';
	@override String get catalogLoading => 'カタログを読み込み中…';
	@override String get catalogUnreachable => 'カタログに接続できません';
	@override String get builtIn => '内蔵';
	@override String get updateAvailableBadge => 'アップデートあり';
	@override String get updatesAvailableTitle => '拡張機能のアップデート';
	@override String updateAvailableFor({required Object name}) => '${name}のアップデートがあります。';
	@override String updatesAvailable({required Object names, required Object count}) => '${names}と他${count}件のアップデートが必要です。';
	@override String updatesAvailableFor({required Object names}) => '${names}のアップデートが必要です。';
	@override String get pendingUpdatesSection => '保留中のアップデート';
	@override String get updateAllAction => 'すべてアップデート';
	@override String get updatesUnderWay => 'それらのアップデートはすでに進行中です。';
	@override String get updatesNothingLeft => '拡張機能はすべて最新です。';
	@override String get updatesNoticeAction => '詳細';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の拡張機能をアップデートしますか？',
		other: '${count}件の拡張機能をアップデートしますか？',
	);
	@override String get upgradeDoneTitle => '拡張機能の準備ができました';
	@override String get upgradeDoneBody => '拡張機能はHam2K拡張機能カタログから提供されるようになったため、アプリの新バージョンを待たずにアップデートできます。';
	@override String upgradeDoneUnserved({required Object names}) => 'アップグレードされなかったもの：${names}。';
	@override String upgradeDoneRefused({required Object names}) => '動作しなかったもの：${names}。';
	@override String get upgradeDoneRefusedHint => 'これらはインストールされたままで、設定 › 拡張機能に印が付いています。そこでアップデートすると復活します。';
	@override String get upgradeDoneUnservedHint => 'カタログにはこれらの直接の後継がありません。使っていた機能をカバーする拡張機能をカタログで探してください。';
	@override String get retiredQp => 'QSOパーティー';
	@override String get retiredStateparks => '州立公園イベント';
	@override String upgradeDoneMissing({required Object count}) => '${count}件の拡張機能がまだ届いていません。次に拡張機能カタログに接続できたときにダウンロードされます。';
	@override String get runtimeDeadBody => '拡張機能が起動しませんでした。アプリを再起動すると復活するはずです。';
	@override String get refusedTitle => '一部の拡張機能が動作しませんでした';
	@override String get upgradeBusyTitle => 'まだセットアップ中です';
	@override String get upgradeRuntimeDeadTitle => '拡張機能が動作していません';
	@override String get restoreTitle => '一部の拡張機能が見つかりません';
	@override String get restoreBody => 'インストールしたこれらの拡張機能がこのデバイスにありません。Ham2K拡張機能カタログから再ダウンロードできます：';
	@override String get restoreFromFile => 'ファイルからインストールしたもの。ファイルから再インストールするか、登録を解除してください：';
	@override String get restoreOtherCatalog => '別の拡張機能カタログからインストールしたため、ここでは利用できません：';
	@override String get restoreForget => '登録解除';
	@override String get restoreInstall => 'インストール';
	@override String get restoreLater => '後で';
	@override String get restoreInstalling => '拡張機能をインストール中…';
	@override String get restoreDoneTitle => '拡張機能が戻りました';
	@override String restoreDoneBody({required Object names}) => '再インストールしました：${names}。';
	@override String get restorePartialTitle => '一部の拡張機能をインストールできませんでした';
	@override String restoreFailed({required Object names}) => 'インストールできませんでした：${names}。次回アプリを開いたときに再度提案します。';
	@override String get restoreBusyBody => 'アプリは拡張機能をセットアップ中です。次回アプリを開いたときに再度提案します。';
	@override String get restoreRuntimeDeadBody => '再インストールしましたが、拡張機能が起動しませんでした。アプリを再起動すると復活するはずです。';
	@override String revokedTitle({required Object name}) => '${name}は取り下げられました';
	@override String get revokedBody => 'カタログがこのバージョンを取り下げたため、無効化されました。';
	@override String forceDisabledTitle({required Object name}) => '${name}は無効化されました';
	@override String get forceDisabledBody => 'Ham2Kがこの拡張機能を当面のあいだ無効化しました。';
	@override String replacedTitle({required Object name}) => '${name}は置き換えられました';
	@override String replacedBody({required Object replacement}) => '代わりに${replacement}が提供されています。拡張機能画面で切り替えられます。';
	@override String replacedBy({required Object name}) => '${name}に置き換えられました';
	@override String replacedByInstalled({required Object name}) => 'すでにお持ちの${name}に置き換えられました';
	@override String get replaceAction => '置き換える';
	@override String replaceInstalledBody({required Object replacement}) => '設定はすでにお持ちの${replacement}に引き継がれます。ログはそのまま残ります。';
	@override String get downloadHashMismatch => 'ダウンロードした内容がカタログに記載された拡張機能と一致しません。';
	@override String catalogVersionUnknown({required Object key, required Object version}) => 'カタログに${key}のバージョン${version}はありません。';
	@override String get catalogLinkUnknown => 'そのカタログリンクは拡張機能のバージョンを示していません。';
	@override String catalogNoRelease({required Object key}) => 'カタログにはそのトラックの${key}のリリースがありません。';
	@override String get installFromLink => 'リンクからインストール';
	@override String get unstableReleaseWarning => 'これは不安定版リリースで、公開者がまだ完成としていないものです。誤動作する可能性があり、今後も不安定版のアップデートを受け取ります。';
	@override String get bleedingReleaseWarning => 'これはブリーディングエッジ版リリースです。開発途中のため、壊れたり設定が失われたりする可能性があります。今後もブリーディングエッジ版のアップデートを受け取ります。';
	@override String get channelUnstable => '不安定版';
	@override String get channelBleeding => 'ブリーディング';
	@override String get followsUnstable => '不安定版と安定版のリリースを受け取ります';
	@override String get followsBleeding => 'ブリーディングエッジ版、不安定版、安定版のリリースを受け取ります';
	@override String get followStableAction => '安定版リリースのみ受け取る';
	@override String get revokedBadge => '取り下げ済み';
	@override String get forceDisabledBadge => 'Ham2Kにより無効化';
	@override String get refusedBadge => '読み込み失敗';
	@override String get downloadNotHttps => 'そのダウンロードは安全な接続ではありません。';
	@override String downloadUnreachable({required Object source}) => 'その拡張機能について${source}に接続できませんでした。';
	@override String get detailsAction => '詳細';
	@override String get installedFromFile => 'ファイルからインストール済み';
	@override String get detailsWhatItDoes => '提供する機能';
	@override String get installedPreloaded => 'プリインストール済み';
	@override String get hookAccount => 'アカウントのログイン';
	@override String get hookCallNotes => 'コールサインノート';
	@override String get hookDataFile => 'オフラインデータ';
	@override String get hookExport => 'エクスポート';
	@override String get hookLookup => 'コールサイン検索';
	@override String get hookScoring => 'スコア';
	@override String get hookSpots => 'スポット';
	@override String hookHunting({required Object program}) => '${program}のハンティング';
	@override String hookActivating({required Object program}) => '${program}のアクティベーション';
	@override String get suggestedSection => 'おすすめ';
	@override String moreAvailableSection({required Object count}) => '他にも${count}件';
}

// Path: home
class _Translations$home$ja extends Translations$home$en {
	_Translations$home$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ポータブルロガー';
	@override String get newOperation => '新しいオペレーション';
	@override String get stationCallsign => 'ステーションコールサイン';
	@override String get titleOptional => 'タイトル（任意）';
	@override String get emptyList => 'オペレーションはまだありません。作成してロギングを始めましょう。';
	@override String get quickLookup => 'クイック検索';
	@override late final _Translations$home$nav$ja nav = _Translations$home$nav$ja._(_root);
	@override late final _Translations$home$panels$ja panels = _Translations$home$panels$ja._(_root);
	@override String get toggleNav => 'ナビゲーションラベルの表示/非表示';
	@override late final _Translations$home$logs$ja logs = _Translations$home$logs$ja._(_root);
}

// Path: chase
class _Translations$chase$ja extends Translations$chase$en {
	_Translations$chase$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'チェイス中';
	@override String goalsTwo({required Object first, required Object second}) => '${first}と${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}、${second}など';
	@override late final _Translations$chase$station$ja station = _Translations$chase$station$ja._(_root);
	@override late final _Translations$chase$periodInline$ja periodInline = _Translations$chase$periodInline$ja._(_root);
	@override late final _Translations$chase$periodStats$ja periodStats = _Translations$chase$periodStats$ja._(_root);
	@override late final _Translations$chase$period$ja period = _Translations$chase$period$ja._(_root);
	@override late final _Translations$chase$goals$ja goals = _Translations$chase$goals$ja._(_root);
	@override late final _Translations$chase$panels$ja panels = _Translations$chase$panels$ja._(_root);
	@override late final _Translations$chase$claims$ja claims = _Translations$chase$claims$ja._(_root);
	@override late final _Translations$chase$notice$ja notice = _Translations$chase$notice$ja._(_root);
	@override late final _Translations$chase$alerts$ja alerts = _Translations$chase$alerts$ja._(_root);
	@override String get checklists => 'チェイスの進捗';
	@override late final _Translations$chase$imports$ja imports = _Translations$chase$imports$ja._(_root);
}

// Path: dialogs
class _Translations$dialogs$ja extends Translations$dialogs$en {
	_Translations$dialogs$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'オペレーション詳細';
	@override String get activities => 'アクティビティ';
	@override String get stationCallsign => 'ステーションコールサイン';
	@override String get advanced => '詳細設定';
	@override String get operatingPosition => '運用ポジション（マルチステーション）';
	@override String get assistance => 'アシスタンス';
	@override String get assistanceDescription => 'スポットサービスなどの情報源を利用する';
	@override String get selfSpotting => 'セルフスポッティング';
	@override String get selfSpottingDescription => '自局の周波数情報を報告する機能を許可する';
	@override String disabledByRules({required Object rules}) => '${rules}のルールに従うため無効';
	@override late final _Translations$dialogs$lookupDespiteAssistance$ja lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$ja._(_root);
	@override String get notes => 'メモ';
	@override String get deleteOperationTitle => 'オペレーションを削除';
	@override String get purgeTestsTitle => 'テストオペレーションを完全削除';
	@override String get purgeTestsBody => 'これらのテストオペレーションとそのQSOを完全に削除します。元に戻せません。';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'さらに、どのオペレーションにも属さないテストコンタクト${count}件。',
		other: 'さらに、どのオペレーションにも属さないテストコンタクト${count}件。',
	);
	@override String get purgeTestsAction => '完全削除';
	@override String get syncAllTitle => 'このデバイスのログを置き換えますか？';
	@override String syncAllBody({required Object qsos}) => 'SYNCALLはこのデバイスの${qsos}をバックアップしてから消去し、アカウントのログをサーバーから再ダウンロードします。バックアップはこのデバイスのデータベースに残ります。';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${n}件のQSOはまだ同期されていません。サーバーには届いていないため、復元されません。',
		other: '${n}件のQSOはまだ同期されていません。サーバーには届いていないため、復元されません。',
	);
	@override String get syncAllAction => '消去して再同期';
	@override String get receivedPurgesTitle => '他のデバイスで削除されたテストオペレーション';
	@override String get receivedPurgesBody => 'これらは別のデバイスでテストオペレーションとして削除されました。ここでも削除しますか？これらとそのQSOは完全に削除され、元に戻せません。';
	@override String get receivedPurgesAction => '削除';
	@override late final _Translations$dialogs$callChange$ja callChange = _Translations$dialogs$callChange$ja._(_root);
}

// Path: operation
class _Translations$operation$ja extends Translations$operation$en {
	_Translations$operation$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'このオペレーションは削除されています。ロギングや変更を行うには復元してください。';
	@override late final _Translations$operation$tabs$ja tabs = _Translations$operation$tabs$ja._(_root);
	@override late final _Translations$operation$positions$ja positions = _Translations$operation$positions$ja._(_root);
	@override String get stationCallsignNone => 'ステーションコールサインなし';
	@override String get titleNone => 'タイトルなし';
	@override String get deleteOperation => 'オペレーションを削除';
	@override String get loggingControlsStale => 'アクティビティのフィールドが古い可能性があります。オペレーションを開き直して更新してください';
	@override String get locationNone => '未設定';
	@override String get generalOperation => 'ジェネラルオペレーション';
	@override String titleFor({required Object value}) => '${value}向け';
	@override String titleAt({required Object value}) => '${value}にて';
	@override String segmentNow({required Object description}) => '現在 ${description}';
	@override String get testOperationSuffix => 'テスト';
	@override late final _Translations$operation$menu$ja menu = _Translations$operation$menu$ja._(_root);
	@override late final _Translations$operation$layout$ja layout = _Translations$operation$layout$ja._(_root);
	@override late final _Translations$operation$export$ja export = _Translations$operation$export$ja._(_root);
	@override late final _Translations$operation$spots$ja spots = _Translations$operation$spots$ja._(_root);
	@override late final _Translations$operation$import$ja import = _Translations$operation$import$ja._(_root);
}

// Path: map
class _Translations$map$ja extends Translations$map$en {
	_Translations$map$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$ja outlineIssue = _Translations$map$outlineIssue$ja._(_root);
	@override String get outlinesDisclaimer => '境界線は参考用です。ご自身でも確認してください！';
	@override String outlinesCredit({required Object sources}) => '境界線: ${sources}';
	@override String boundariesCredit({required Object sources}) => '行政境界: ${sources}';
	@override String facilitiesCredit({required Object sources}) => '施設: ${sources}';
	@override String get fullCredits => 'データの全クレジット';
	@override String get fewerCredits => 'クレジットを減らす';
	@override String get emptyState => 'QSOの位置はまだありません。\nグリッドスクエア、州、国のあるQSOがここに表示されます。';
	@override String get unavailable => '現在、地図を利用できません。';
	@override String qthPopupTitle({required Object grid}) => 'QTH：${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => '平面';
	@override String get globe => '地球儀';
	@override String get zoomIn => '拡大';
	@override String get zoomOut => '縮小';
	@override String get resetNorth => '北を上にリセット';
	@override late final _Translations$map$postcard$ja postcard = _Translations$map$postcard$ja._(_root);
}

// Path: mapsView
class _Translations$mapsView$ja extends Translations$mapsView$en {
	_Translations$mapsView$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '地図';
	@override String get searchHint => '公園、山頂などを検索';
	@override String get activities => 'アクティビティ';
	@override String get layers => 'レイヤー';
	@override String get baseMap => 'ベースマップ';
	@override String get satellite => '衛星写真（Esri）';
	@override String get facilities => '公園の施設';
	@override String get boundaries => '行政境界';
	@override String get currentLocation => '現在地';
	@override String noMatches({required Object text}) => '「${text}」に一致するものはありません';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${where}のリファレンス${count}件',
		other: '${where}のリファレンス${count}件',
	);
	@override String get startOperation => 'これらのリファレンスでオペレーションを開始';
}

// Path: activitiesView
class _Translations$activitiesView$ja extends Translations$activitiesView$en {
	_Translations$activitiesView$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'アクティビティ';
	@override String get activitiesCountZero => 'アクティビティが選択されていません';
	@override String get activitiesCountOne => '1件のアクティビティ';
	@override String activitiesCountOther({required Object count}) => '${count}件のアクティビティ';
	@override String get empty => 'アクティビティはまだありません。下の候補と検索から追加してください';
	@override String get removeActivity => '削除';
	@override String openReferenceLink({required Object name}) => '${name}を開く';
	@override String get editActivity => 'アクティビティを編集';
	@override String get manageExtensions => '拡張機能を管理';
	@override String get manage => '管理';
	@override String activitiesTitle1({required Object first}) => 'アクティビティの種類：${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'アクティビティの種類：${first}と${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'アクティビティの種類：${first}、${second}、他${more}件';
	@override String get reference => 'リファレンス';
	@override String get invalidReference => '無効';
	@override String get duplicateReference => '追加済み';
	@override String get searchHint => '名前、リファレンスなどで検索…';
	@override String get noSuggestions => '一致なし';
	@override String get noSuggestionsHint => '上でリファレンスの名前または番号を検索してください';
	@override String get noSuggestionsExample => '（例：「trail」や「4556」）';
	@override String get allOptions => 'アクティビティの種類';
	@override String get determiningLocation => '現在地を特定しています…\n近くのリファレンスを探すためにGPSの測位を待っています';
	@override String get locationUnavailableTitle => '位置情報を利用できません';
	@override String get locationDeniedTitle => '位置情報の許可が拒否されました';
	@override String get locationBlockedTitle => '位置情報の許可がブロックされています';
	@override String get noNearbyReason => '近くのリファレンスを特定できません';
	@override String locationManualHint({required Object icon}) => '${icon}をタップして手動で位置を入力するか、\n名前でリファレンスを検索してください';
	@override String get locationGrantAction => '位置情報へのアクセスを許可';
	@override String get locationSettingsAction => '設定を開く';
	@override String get locationSettingsUnavailable => 'システム設定で位置情報へのアクセスを許可してください';
	@override String get locationGrantRefused => '位置情報がまだありません。システムに再び拒否されました';
	@override String get searchUnavailableTitle => 'アクティビティ検索を利用できません';
	@override String get searchUnavailableReason => 'アクティビティ拡張機能が検索に応答できませんでした。しばらくしてから再試行してください。';
	@override String get emptySheet => '下の候補と検索から追加してください';
	@override String get exports => 'エクスポート';
	@override String get exportLogs => 'ログをエクスポート';
	@override String get tools => 'ツール';
	@override String get toolsTitle => 'オペレーションツール';
	@override String get operationDetails => 'オペレーション詳細';
	@override String get share => '共有';
	@override String get archive => 'アーカイブ';
	@override String get deleteOperation => 'オペレーションを削除';
	@override String get undeleteOperation => 'オペレーションを復元';
	@override String get alreadySelected => '選択済み';
	@override String get selected => '選択中';
	@override String pickPosition({required Object index, required Object count}) => '${index} / ${count}';
	@override String get previousPick => '前の候補';
	@override String get nextPick => '次の候補';
	@override String get retiredReference => '廃止';
	@override String enableExtension({required Object name}) => '${name}を有効化';
	@override String get enableExtensionHint => 'この拡張機能は検索に一致しますが、現在有効になっていません';
	@override String get enableExtensionForRefHint => 'この拡張機能はこのオペレーションのリファレンスの1つを扱いますが、現在有効になっていません';
	@override String extensionNotRunning({required Object name}) => '${name}は動作していません';
	@override String get extensionNotRunningHint => 'この拡張機能は無効化されています。詳細は拡張機能の設定を開いてください';
	@override String installExtension({required Object name}) => '${name}をインストール';
	@override String get installExtensionHint => 'この拡張機能は検索に一致しますが、インストールされていません';
	@override String get onlyCatalogMatches => '一致なし\nカタログの一部の拡張機能に結果があるかもしれません。\n下のアクティビティの種類からインストールしてください。';
	@override String get setupUnavailable => 'このアクティビティの設定を読み込めませんでした。管理から再試行してください';
	@override String get controlsUnavailableTitle => 'アクティビティの操作を利用できません';
	@override String get controlsUnavailableReason => 'リファレンスは安全ですが、現在編集できません。';
	@override String get controlsUnavailableRetry => '再試行';
	@override String get onlyDisabledMatches => '一致なし\n利用可能な一部の拡張機能に結果があるかもしれません。\n下のアクティビティの種類で有効にしてください。';
	@override String get onlyNotRunningMatches => '一致なし\n結果があるかもしれない一部の拡張機能が動作していません。\n下のアクティビティの種類を確認してください。';
	@override String get mapToggle => '地図';
	@override String get searchToggle => '検索';
	@override String get addToOperation => 'オペレーションに追加';
	@override String get addToOperationShort => '追加';
	@override String get mapEmptyState => '地図に表示する結果がありません';
	@override String get mapEmptyStateHint => 'リストに戻るか、別のものを検索してください';
	@override String get imports => 'インポート';
}

// Path: loggingControls
class _Translations$loggingControls$ja extends Translations$loggingControls$en {
	_Translations$loggingControls$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => '時刻（UTC）';
	@override String get date => '日付';
	@override String get now => '現在';
	@override String get manualTimeSettings => '手動時刻';
	@override String get manualTimeIncrement => 'QSOごとの増分';
	@override String get manualTimeIncrementNone => 'なし';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}分',
		other: '${count}分',
	);
	@override String get frequency => '周波数';
	@override String get mode => 'モード';
	@override String get theirCall => '相手のコール';
	@override String get noteField => 'メモ';
	@override String get todoField => 'To-Do';
	@override String get sent => '送信';
	@override String get rcvd => '受信';
	@override String get more => 'その他';
	@override String get revert => '元に戻す';
	@override String get undoDelete => '削除を取り消す';
	@override String get restore => '復元';
	@override String get wipe => '消去';
	@override String get undo => '元に戻す';
	@override String get pendingDeleteTapWarning => 'もう一度ゴミ箱をタップするとこのQSOを削除します';
	@override String get pendingDeleteClickWarning => 'もう一度ゴミ箱をクリックするとこのQSOを削除します';
	@override String get deletedQsoWarning => '削除されたQSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'もう一度ゴミ箱をタップするとこの${kind}を削除します';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'もう一度ゴミ箱をクリックするとこの${kind}を削除します';
	@override String deletedEventWarning({required Object kind}) => '削除された${kind}';
	@override String get timeControl => '時刻';
	@override String get radioControl => '無線機';
	@override String get powerControl => 'パワー';
	@override String get notesControl => 'メモ';
	@override String get power => 'パワー';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'ロギング操作';
	@override String get spottingControl => 'スポッティング';
	@override String get spottingSelfControl => 'セルフスポッティング';
	@override String spotSelfAt({required Object freq}) => '${freq}でセルフスポット';
	@override String spotOtherAt({required Object call, required Object freq}) => '${call}を${freq}でスポット';
	@override String spotTooLate({required Object call}) => '${call}のスポットには遅すぎます';
	@override String get spotNoFreq => '最初に周波数を設定してください';
	@override String get selfSpotDisabled => 'セルフスポット無効';
	@override String get spotComment => 'コメント';
	@override String get spottingAutoControl => '自動再スポット';
	@override String spotAutoEvery({required Object minutes}) => '${minutes}分ごとに再スポット';
	@override String spotAutoNext({required Object time}) => '${time}後に自動。停止しますか？';
	@override String spotAutoInMinutes({required Object minutes}) => '${minutes}分後に自動';
	@override String spotAutoInSeconds({required Object seconds}) => '${seconds}秒後に自動';
	@override String spotAutoInCount({required Object seconds}) => '${seconds}後に自動';
	@override String get spotAutoNotStarted => '自動再スポットを開始できませんでした：スポットが送信されませんでした';
	@override String get spotAutoMoved => '自動再スポットを開始できませんでした：スポット中に周波数が変わりました';
	@override String get spotAutoStopped => '自動再スポットを停止しました';
	@override String get spotAutoLeftFreq => '自動再スポットを停止しました：周波数が変わりました';
	@override String get spotAutoNoFreq => '自動再スポットを停止しました：無線機から周波数が得られません';
	@override String get spotBusy => '別のスポットをまだ送信中です';
	@override String get bandOrFreqRequired => '記録する前に周波数またはバンドを設定してください';
	@override String get missingBand => 'バンドなし';
	@override String get missingMode => 'モードなし';
	@override String saveFailed({required Object error}) => '保存できませんでした：${error}';
	@override String deleteFailed({required Object error}) => '削除できませんでした：${error}';
	@override late final _Translations$loggingControls$info$ja info = _Translations$loggingControls$info$ja._(_root);
}

// Path: formChrome
class _Translations$formChrome$ja extends Translations$formChrome$en {
	_Translations$formChrome$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get untitled => '（無題）';
	@override String get showMore => 'さらに表示';
	@override String get showAll => 'すべて表示';
	@override String get showFewer => '表示を減らす';
	@override String get defaults => 'デフォルト';
	@override String get search => '検索';
	@override String get clear => 'クリア';
	@override String get openPage => 'ページを開く';
	@override String get connected => '接続済み';
	@override String get notConnected => '未接続';
	@override String get manage => '管理';
	@override String get connect => '接続';
	@override String get formTitle => 'フォーム';
	@override String addItem({required Object label}) => '${label}を追加';
	@override String editItem({required Object label}) => '${label}を編集';
	@override String multiselectStatus({required Object total, required Object shown, required Object selected}) => '${total}件中${shown}件を表示（${selected}件選択中）';
	@override String validationError({required Object error}) => '検証エラー：${error}';
	@override String transformationError({required Object error}) => '変換エラー：${error}';
	@override String actionError({required Object error}) => 'エラー：${error}';
	@override String get removeItem => '削除';
	@override String deleteItemTitle({required Object name}) => '${name}を削除しますか？';
	@override String get storageUnavailable => 'ログイン情報を利用できません';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$ja extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSOを編集';
	@override String get operatorCall => 'オペレーター';
	@override String get position => 'ポジション';
	@override String get theirName => '名前';
	@override String get theirGrid => 'グリッド';
	@override String get theirState => '州';
	@override String get band => 'バンド';
	@override String get notes => 'メモ';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => '相手の情報';
	@override String get sectionOur => '自局の情報';
	@override String get sectionNotes => 'メモ';
	@override String get theirCity => '都市';
	@override String get theirCounty => '郡';
	@override String get theirEntity => 'エンティティ';
	@override String get theirCqZone => 'CQゾーン';
	@override String get theirItuZone => 'ITUゾーン';
	@override String get theirArrlSection => 'ARRLセクション';
	@override String get theirLat => '緯度';
	@override String get theirLon => '経度';
	@override String get theirPower => '相手のパワー';
}

// Path: qsoList
class _Translations$qsoList$ja extends Translations$qsoList$en {
	_Translations$qsoList$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get empty => 'まだQSOがありません。誰かと交信しましょう！';
	@override String get bandOrModeWarning => 'バンドとモードが正しいか確認してください';
	@override String get today => '今日';
	@override String get yesterday => '昨日';
	@override String get tomorrow => '明日';
	@override late final _Translations$qsoList$find$ja find = _Translations$qsoList$find$ja._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$ja extends Translations$loggingPanel$en {
	_Translations$loggingPanel$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get stats => 'オペレーションの統計';
	@override String get scoring => 'スコア';
	@override String get dxccEntities => 'DXCCエンティティ';
	@override String get statesWorked => '州';
	@override String get provincesWorked => '州/県';
	@override String get duplicates => '重複';
}

// Path: callInfo
class _Translations$callInfo$ja extends Translations$callInfo$en {
	_Translations$callInfo$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => '画像を表示';
	@override String get imageUnavailable => '写真を利用できません';
	@override String get photo => '写真';
	@override String get notes => 'メモ';
	@override String distanceTo({required Object distance}) => '${distance} →';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance}（${bearing}°）→';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）→';
	@override String distanceAway({required Object distance}) => '${distance} 離れた所';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance}（${bearing}°）離れた所';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）離れた所';
	@override String get thisOpCountOne => 'このオペレーションでのQSO：1件';
	@override String thisOpCountOther({required Object count}) => 'このオペレーションでのQSO：${count}件';
	@override String get otherOpsCountOne => '他のオペレーションでのQSO：1件';
	@override String otherOpsCountOther({required Object count}) => '他のオペレーションでのQSO：${count}件';
	@override String andMore({required Object count}) => '…さらに${count}件';
	@override String withCall({required Object call}) => '${call}と共に';
	@override String fromOperation({required Object where}) => '${where}から';
	@override late final _Translations$callInfo$history$ja history = _Translations$callInfo$history$ja._(_root);
}

// Path: settings
class _Translations$settings$ja extends Translations$settings$en {
	_Translations$settings$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '設定';
	@override String get language => '言語';
	@override String languageSystem({required Object language}) => 'システム設定に従う（${language}）';
	@override late final _Translations$settings$theme$ja theme = _Translations$settings$theme$ja._(_root);
	@override late final _Translations$settings$themeDescription$ja themeDescription = _Translations$settings$themeDescription$ja._(_root);
	@override String get fontScale => 'フォントサイズ';
	@override late final _Translations$settings$fontScaleOpts$ja fontScaleOpts = _Translations$settings$fontScaleOpts$ja._(_root);
	@override late final _Translations$settings$keepDeviceAwake$ja keepDeviceAwake = _Translations$settings$keepDeviceAwake$ja._(_root);
	@override String get layoutDensity => 'レイアウト密度';
	@override late final _Translations$settings$layoutDensityOpts$ja layoutDensityOpts = _Translations$settings$layoutDensityOpts$ja._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'ウィンドウの高さが足りないため、${effective}を使用中';
	@override String get layoutDensityAtLimit => 'これ以上は変更できません';
	@override String get distanceUnits => '距離の単位';
	@override late final _Translations$settings$distanceUnitsOpts$ja distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$ja._(_root);
	@override String get userInterface => 'ユーザーインターフェース';
	@override late final _Translations$settings$logging$ja logging = _Translations$settings$logging$ja._(_root);
	@override late final _Translations$settings$catServer$ja catServer = _Translations$settings$catServer$ja._(_root);
	@override late final _Translations$settings$cluster$ja cluster = _Translations$settings$cluster$ja._(_root);
	@override late final _Translations$settings$spotting$ja spotting = _Translations$settings$spotting$ja._(_root);
	@override late final _Translations$settings$radio$ja radio = _Translations$settings$radio$ja._(_root);
	@override late final _Translations$settings$help$ja help = _Translations$settings$help$ja._(_root);
	@override late final _Translations$settings$exports$ja exports = _Translations$settings$exports$ja._(_root);
	@override late final _Translations$settings$extensionSections$ja extensionSections = _Translations$settings$extensionSections$ja._(_root);
	@override late final _Translations$settings$map$ja map = _Translations$settings$map$ja._(_root);
	@override late final _Translations$settings$privacy$ja privacy = _Translations$settings$privacy$ja._(_root);
	@override String get operatorCall => 'オペレーターのコールサイン';
	@override late final _Translations$settings$sync$ja sync = _Translations$settings$sync$ja._(_root);
	@override late final _Translations$settings$peers$ja peers = _Translations$settings$peers$ja._(_root);
	@override String get developerMode => '開発者モード';
	@override late final _Translations$settings$syncPanel$ja syncPanel = _Translations$settings$syncPanel$ja._(_root);
	@override late final _Translations$settings$accounts$ja accounts = _Translations$settings$accounts$ja._(_root);
	@override late final _Translations$settings$station$ja station = _Translations$settings$station$ja._(_root);
	@override late final _Translations$settings$offlineData$ja offlineData = _Translations$settings$offlineData$ja._(_root);
	@override late final _Translations$settings$profiles$ja profiles = _Translations$settings$profiles$ja._(_root);
	@override late final _Translations$settings$search$ja search = _Translations$settings$search$ja._(_root);
	@override late final _Translations$settings$developer$ja developer = _Translations$settings$developer$ja._(_root);
	@override late final _Translations$settings$about$ja about = _Translations$settings$about$ja._(_root);
	@override late final _Translations$settings$panels$ja panels = _Translations$settings$panels$ja._(_root);
	@override String get showMoreSettings => 'その他の設定を表示';
	@override String get gridPrecision => 'グリッドの精度';
	@override late final _Translations$settings$gridPrecisionOpts$ja gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$ja._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$ja gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$ja._(_root);
}

// Path: commands
class _Translations$commands$ja extends Translations$commands$en {
	_Translations$commands$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => '先に設定で同期を有効にしてください。';
	@override String get fullResyncStarted => '完全な再同期を開始しました。ローカルデータは事前にバックアップされています。';
	@override String noDataFilesMatched({required Object target}) => '「${target}」に一致するデータファイルはありません。';
	@override String reloadFailed({required Object error}) => '再読み込みに失敗しました：${error}';
	@override String get reloadingAll => 'すべてのデータファイルを再読み込み中…';
	@override String reloadingTarget({required Object target}) => '${target}のデータファイルを再読み込み中…';
	@override String unknownExperiment({required Object token}) => '不明な実験「${token}」';
	@override String experimentEnabled({required Object name}) => '${name}を有効化しました';
	@override String experimentDisabled({required Object name}) => '${name}を無効化しました';
	@override String get sentryTestSent => 'テストのエラーレポートをSentryに送信しました';
	@override String get idleMetricsEnabled => 'ステータスバーのアイドル指標を有効にしました';
	@override String get idleMetricsDisabled => 'アイドル指標を無効にしました';
	@override String get sentryTestLocalOnly => 'このビルドではSentryが無効です。テストエラーはローカルにのみ記録されました';
	@override String get noOperationOpen => 'このコマンドにはオペレーションを開いている必要があります';
	@override String unknownSegmentKind({required Object kind}) => '「${kind}」の記録方法が分かりません';
	@override String goUnavailable({required Object place}) => '${place}はこのアプリでは有効になっていません';
	@override String goUnknown({required Object to}) => '「${to}」への移動方法が分かりません';
	@override String get goBlocked => '先に開いているダイアログを閉じてください';
	@override String get operationAlreadyStarted => 'このオペレーションにはすでに開始マーカーがあります';
	@override String get couldNotOpenLocation => '休憩を追加しましたが、場所の画面を開けませんでした';
	@override String get noTestOperations => '完全削除するテストオペレーションはありません';
	@override String get purgeTestsUnavailable => 'PURGETESTSには確認ダイアログの表示が必要ですが、ここでは利用できません';
	@override String get syncAllUnavailable => 'SYNCALLには確認ダイアログの表示が必要ですが、ここでは利用できません';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のテストオペレーションを完全削除しました',
		other: '${count}件のテストオペレーションを完全削除しました',
	);
	@override String purgeTestsSomeFailed({required Object total, required Object purged}) => '${total}件中${purged}件のテストオペレーションを完全削除しました。残りは失敗しました。もう一度PURGETESTSを試してください';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'オペレーションに属さないテストコンタクト${count}件を完全削除しました',
		other: 'オペレーションに属さないテストコンタクト${count}件を完全削除しました',
	);
	@override String get purgeTestsContactsFailed => 'テストオペレーションは完全削除しましたが、オペレーションに属さないテストコンタクトの削除に失敗しました。もう一度PURGETESTSを試してください';
	@override String get purgeTestsNothingToDo => '何も削除されませんでした';
	@override String receivedPurgesSomeFailed({required Object total, required Object removed}) => '${total}件中${removed}件のテストオペレーションを削除しました。残りは失敗しました。もう一度確認から試してください';
	@override String get receivedPurgesFailed => 'それらのテストオペレーションを削除できませんでした。もう一度確認から試してください';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のテストオペレーションが別のデバイスで削除されました',
		other: '${count}件のテストオペレーションが別のデバイスで削除されました',
	);
	@override String get receivedPurgesReview => '確認';
	@override String get settingOn => 'オン';
	@override String get settingOff => 'オフ';
	@override String get settingEmpty => '（空）';
	@override String get settingSecretSet => '（設定済み）';
	@override String get settingSecretUnset => '（未設定）';
	@override String settingSelectedCount({required Object count}) => '${count}件選択中';
	@override String get settingExpectsOnOff => 'onまたはoff';
	@override String settingExpectsOneOf({required Object choices}) => '次のいずれか：${choices}';
	@override String get settingExpectsNumber => '数値';
	@override String settingVanished({required Object label}) => '「${label}」はもう利用できません';
	@override String get noCwKeyer => 'CWをキーイングできる無線機が接続されていません';
	@override String get noKeyer => 'CWのキーイングやボイスメモリーの再生ができる無線機が接続されていません';
	@override String get keyerNeedsOperation => 'CWキーヤーを使うにはオペレーションを開いてください';
	@override String get keyerExperimentOff => 'CWキーイングはオフです。EXP KEYERでオンにしてください';
	@override String get esmExperimentOff => 'Enterでメッセージ送信はオフです。EXP ESMでオンにしてください';
	@override String cwSending({required Object text}) => 'CW送信中：${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CWメッセージF${n}：${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CWメッセージF${n}は送信されませんでした：拡張機能の準備ができていません';
	@override String voiceMessageError({required Object n, required Object error}) => '電話メッセージM${n}：${error}';
	@override String get voiceMessageNotRendered => '拡張機能の準備ができていません';
	@override String so2rRadioCannotKey({required Object radio}) => '送信されませんでした：Radio ${radio}ではそれをキーイングできません';
	@override String get so2rNoRadioB => '送信されませんでした：このセットからキーイングするには、ステーション構成でRadio Bを選んでください';
	@override String settingNotStored({required Object label}) => '「${label}」はその値を受け付けませんでした';
}

// Path: commandDialog
class _Translations$commandDialog$ja extends Translations$commandDialog$en {
	_Translations$commandDialog$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get hint => 'コールサインを検索、またはコマンドを入力';
	@override String noResults({required Object text}) => '「${text}」に一致するものはありません';
	@override String get sectionCommands => 'コマンド';
	@override String get sectionGoTo => '移動';
	@override String get sectionOperations => 'オペレーション';
	@override String get goHome => 'ホーム';
	@override String get goSettings => '設定';
	@override String get goNewOperation => '新しいオペレーション';
	@override String runTyped({required Object text}) => '「${text}」を実行';
	@override String get sectionSuggestions => '候補';
	@override String get lookingUp => 'コールサインを検索中…';
	@override String get blockedByPane => 'パネルやダイアログが開いている間はコマンドを使用できません';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$ja extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'キーボードショートカット';
	@override String get description => 'キー割り当てをカスタマイズ';
	@override String get search => 'コマンドとキーを検索';
	@override String get import => 'インポート…';
	@override String get export => 'エクスポート…';
	@override String get resetAll => 'すべてリセット';
	@override String get resetAllTitle => 'すべてのショートカットをリセットしますか？';
	@override String get resetAllBody => 'すべてのコマンドがデフォルトのキーに戻り、入力コマンドに割り当てたキーは削除されます。';
	@override String get reset => 'リセット';
	@override String get noKey => 'キーなし';
	@override String get changed => '変更済み';
	@override String conflict({required Object keys, required Object commands}) => '${keys}は${commands}にも割り当てられています';
	@override String get groupApp => 'アプリ';
	@override String get groupKeying => 'キーイング';
	@override String get groupLogging => 'ロギング';
	@override String get groupCommands => 'コマンド';
	@override String get groupFixed => '固定キー';
	@override String get contextApp => 'どこでも';
	@override String get contextLogView => 'オペレーション、チェイス、ログの各ビュー';
	@override String get contextOperation => 'オペレーションビュー（CAT無線機のキーイング）';
	@override String get contextLogging => 'ロギングパネル内';
	@override String get addCommand => 'コマンドを追加…';
	@override String unknownCommand({required Object command}) => '不明なコマンド：${command}';
	@override late final _Translations$keyboardShortcuts$command$ja command = _Translations$keyboardShortcuts$command$ja._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$ja fixed = _Translations$keyboardShortcuts$fixed$ja._(_root);
	@override late final _Translations$keyboardShortcuts$editor$ja editor = _Translations$keyboardShortcuts$editor$ja._(_root);
	@override late final _Translations$keyboardShortcuts$file$ja file = _Translations$keyboardShortcuts$file$ja._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$ja modifier = _Translations$keyboardShortcuts$modifier$ja._(_root);
	@override late final _Translations$keyboardShortcuts$platform$ja platform = _Translations$keyboardShortcuts$platform$ja._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$ja extends Translations$expiredBuild$en {
	_Translations$expiredBuild$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'このビルドは期限切れです';
	@override String get body => 'ham2k.comにアクセスして新しいバージョンを入手してください。';
	@override String get visit => 'ham2k.comを開く';
	@override String get dismiss => 'それでも続行';
}

// Path: staleness
class _Translations$staleness$ja extends Translations$staleness$en {
	_Translations$staleness$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => '重要なアップデートが待機中です';
	@override String get codePushFloorBody => 'このバージョンには、まだ適用されていない修正があります。';
	@override String get restartToApply => '適用するにはアプリを再起動してください。';
	@override String get quitAndReopen => '適用するにはアプリを終了して開き直してください。';
	@override String get reopenToApply => '適用するにはアプリを閉じて開き直してください。';
	@override String get ignoreForNow => '今は無視';
}

// Path: spotting
class _Translations$spotting$ja extends Translations$spotting$en {
	_Translations$spotting$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'スポットするQSOがまだ記録されていません。';
	@override String get setFrequencyFirst => '先に周波数を設定してください。';
	@override String get nothingToSpot => 'スポットできません。ここでスポッティングを提供する拡張機能がありません。';
	@override String get incompleteCall => '不完全なコールはスポットできません。先にコールサインを完成させてください。';
	@override String spotFailed({required Object source, required Object message}) => '${source}が失敗しました：${message}';
	@override String get unknownError => '不明なエラー';
	@override String get notSent => 'スポットは送信されませんでした。';
	@override String get allSkipped => 'スポットは送信されませんでした：すべてのスポットソースがスキップしました。';
	@override String get notRefreshedOffline => '接続がないため、スポットは更新されませんでした';
}

// Path: dataFiles
class _Translations$dataFiles$ja extends Translations$dataFiles$en {
	_Translations$dataFiles$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'ダウンロード中…';
	@override String downloadFailedTitle({required Object name}) => '${name}をダウンロードできませんでした';
	@override String get downloadFailedWebHint => 'ネットワークの問題か、このリンクのホストがWebブラウザからの直接ダウンロードに対応していない可能性があります。デスクトップ版やモバイル版のアプリ、または別のホスティング先を試してください。';
	@override String get downloadTimedOut => 'サーバーの応答に時間がかかりすぎました。後で再試行してください。';
	@override String downloadServerError({required Object host, required Object status}) => '${host}がエラーを返しました（HTTP ${status}）。後で再試行してください。';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host}はこのファイルを提供できませんでした（HTTP ${status}）。アドレスがまだ正しいか確認してください。';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MMには${stem}のコールヒストリーファイルがありません。';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'N1MMの${stem}のコールヒストリーをダウンロードできませんでした。後で再試行してください。';
	@override String processingFailedTitle({required Object name}) => '${name}を処理できませんでした';
	@override String importTooSmall({required Object existing, required Object imported}) => 'ダウンロードには、このデバイスにある${existing}件中${imported}件のレコードしかなかったため、含まれていなかったレコードは保持しました。設定 › オフラインデータで更新すると、それでも受け入れます。';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${label}のレコードを${count}件インポートしました。',
		other: '${label}のレコードを${count}件インポートしました。',
	);
	@override String importedData({required Object label}) => '${label}のデータをインポートしました。';
	@override String get cleanedUpTitle => '拡張機能のデータを整理しました';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '無効化された拡張機能のデータファイル${count}件分のデータを削除しました。',
		other: '無効化された拡張機能のデータファイル${count}件分のデータを削除しました。',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total}件';
	@override String get definitionUnavailable => 'ファイルのソースが定義を提供しませんでした。拡張機能が再起動中か、設定に誤りがある可能性があります。しばらくしてから再試行してください。';
}

// Path: updates
class _Translations$updates$ja extends Translations$updates$en {
	_Translations$updates$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'アップデートがあります';
	@override String newVersionAvailable({required Object version}) => '新しいバージョン（${version}）が利用可能です。';
	@override String get getIt => '入手';
	@override String get ok => 'OK';
	@override String get updateReady => 'アップデートの準備完了';
	@override String get restartToApply => 'アップデートをダウンロードしました。適用するには再起動してください。';
	@override String get appliesNextLaunch => 'アップデートをダウンロードしました。次回アプリを開いたときに適用されます。';
	@override String get restartNow => '今すぐ再起動';
	@override String get reloadToUpdate => 'このページの新しいバージョンがあります。再読み込みして入手してください。';
	@override String get reloadNow => '今すぐ再読み込み';
	@override String get checkForUpdates => 'アップデートを確認';
	@override String get checkingForUpdates => 'アップデートを確認中…';
	@override String get upToDate => '最新です';
	@override String get automaticChecks => '自動的に確認';
	@override String get automaticChecksDescription => '次回アプリを起動したときから、バックグラウンドで新しいバージョンを確認します';
}

// Path: extensionService
class _Translations$extensionService$ja extends Translations$extensionService$en {
	_Translations$extensionService$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => '拡張機能ランタイムの準備ができていません。';
	@override String testFailed({required Object error}) => 'テストに失敗しました：${error}';
	@override String connectedAs({required Object identity}) => '${identity}として接続済み';
	@override String get invalidFieldConfiguration => 'フィールドの設定が無効です';
	@override String get invalidValue => '無効な値';
	@override String validationError({required Object error}) => '検証エラー：${error}';
	@override String actionFailed({required Object error}) => '操作に失敗しました：${error}';
	@override String get commandFailed => 'コマンドを実行できませんでした';
	@override String commandMayNotChangeSettings({required Object name}) => '${name}は設定を変更できません：インストール時に許可を求めていません';
	@override String commandMayNotControlRadio({required Object name}) => '${name}は無線機を制御できません：インストール時に許可を求めていません';
	@override String commandDeveloperOnly({required Object name}) => '${name}はそれを実行できません：アプリ自身の開発者コマンドです';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => '現在、報告を送信できません';
	@override String get stashUnavailable => '現在、Ham2K File Stashに接続できません';
	@override String activitySearchSourcesFailed({required Object names}) => '${names}がアクティビティ検索に応答しなかったため、一部の結果が欠けている可能性があります。';
	@override String get activitySearchSomeSourcesFailed => '一部のアクティビティ拡張機能が検索に応答しなかったため、一部の結果が欠けている可能性があります。';
	@override String timersSuspendedBudget({required Object name}) => '${name}がタイマーで時間を使いすぎました。拡張機能が再起動するまでタイマーは停止されます。';
	@override String timersSuspendedFailures({required Object name}) => '${name}のタイマーが失敗し続けました。拡張機能が再起動するまでタイマーは停止されます。';
	@override String timersSuspendedInterrupted({required Object name}) => '${name}がタイマー内で停止しました。拡張機能が再起動するまでタイマーは停止されます。';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$ja extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オペレーション場所';
	@override String get selectedLocation => '選択された場所';
	@override String get gridSquare => 'メイデンヘッド・グリッドスクエアロケーター';
	@override String get gridInvalid => 'FN31prのように、4、6、8、10文字で入力してください';
	@override String get suggestedLocations => '提案された場所';
	@override String get deviceGps => 'デバイスGPS';
	@override String peerGps({required Object device}) => '${device}のGPS';
	@override String get locating => '測位中…';
	@override String get gpsUnavailable => '位置情報を利用できません';
	@override String get permissionDenied => '位置情報の許可が拒否されました';
	@override String get permissionBlocked => '位置情報の許可がブロックされています';
	@override String get moreDetails => '詳細';
	@override String get stateOrProvince => '州または都道府県（任意）';
	@override String get controlsUnavailableTitle => 'アクティビティの操作を利用できません';
	@override String get controlsUnavailableReason => 'これらのリファレンスは引き続き使用できます。アクティビティに接続できなかっただけです。';
	@override String get controlsUnavailableRetry => '再試行';
	@override String get county => '郡（任意）';
}

// Path: versionLabel
class _Translations$versionLabel$ja extends Translations$versionLabel$en {
	_Translations$versionLabel$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'バージョン ${version}';
	@override String patch({required Object patch}) => 'パッチ ${patch}';
	@override String build({required Object build}) => 'ビルド ${build}';
}

// Path: notices
class _Translations$notices$ja extends Translations$notices$en {
	_Translations$notices$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'お知らせはまだありません';
	@override String get webStorageInMemory => 'このブラウザは永続ストレージを提供できませんでした。ログはメモリー上にのみ存在し、このタブを閉じると失われます。最新のChrome、Firefox、Safari、Edgeを使用してください。';
	@override String get webStorageUnreliable => 'このブラウザは複数タブでは安全でない代替ストレージを使用しています。タブは1つだけ開き、同期をオンにしたままにしてください。';
	@override String get logFromNewerBuildTitle => 'このログには新しいバージョンが必要です';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'ログは新しいバージョンのHaLoで書き込まれているため（ストレージバージョン${storage}、このバージョンが扱えるのは${understood}）、開くことができず、新しいコンタクトも保存されません。新しいバージョンを再インストールするか、このビルドを実行するつもりだった場合は別のデータフォルダーを指定してください。ログの場所：${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'ログは新しいバージョンのHaLoで書き込まれているため（ストレージバージョン${storage}、このバージョンが扱えるのは${understood}）、開くことができず、新しいコンタクトも保存されません。代わりにその新しいバージョンでこのログを開いてください。';
	@override String get preferencesRestoredTitle => '設定をバックアップから復元しました';
	@override String get preferencesRestored => '設定ファイルを読み取れなかったため、HaLoは最後の正常なコピーを復元しました。前回のセッションで変更した内容は、再設定が必要な場合があります。読み取れなかったファイルは shared_preferences.corrupt-….json という名前で同じ場所に保管されています。';
	@override String get preferencesResetTitle => '設定をリセットしました';
	@override String get preferencesReset => '設定ファイルを読み取れず、代わりに使えるバックアップもなかったため、HaLoはデフォルト設定で起動しました。読み取れなかったファイルは shared_preferences.corrupt-….json という名前でアプリのデータフォルダーに保管されています。';
	@override String autoConnectHeldTitle({required Object name}) => '${name}は自動接続されませんでした';
	@override String autoConnectHeld({required Object name}) => '前回${name}への接続を開始したときにHaLoが応答しなくなったため、再発を避けて今回は接続しませんでした。無線機の電源が入っていてケーブルが接続されていることを確認してから、設定でその無線機の接続を押してください。';
}

// Path: syncAccount
class _Translations$syncAccount$ja extends Translations$syncAccount$en {
	_Translations$syncAccount$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => '匿名アカウント (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email}（確認待ち）';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email}（確認待ち - #${id}）';
}

// Path: deepLink
class _Translations$deepLink$ja extends Translations$deepLink$en {
	_Translations$deepLink$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => '先にオペレーションを開始してから、そのコンタクトをもう一度送信してください';
	@override String get waitingInOperation => 'そのコンタクトはこの画面の後ろのオペレーションで待機しています';
	@override String unknownActivities({required Object refs}) => 'このデバイスには${refs}のアクティビティがないため、それらのリファレンスは省略されました';
	@override String activitiesUnavailable({required Object refs}) => 'アクティビティに接続できなかったため、${refs}は省略されました。もう一度そのリンクを試してください';
}

// Path: confirmDevice
class _Translations$confirmDevice$ja extends Translations$confirmDevice$en {
	_Translations$confirmDevice$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'デバイスを確認';
	@override String get codePrompt => 'このアカウントへの参加を求めているデバイスに表示されたコードを入力してください。';
	@override String get code => 'コード';
	@override String get lookUp => '検索';
	@override String get codeNotFound => 'そのコードに一致するリクエストはありません。コードは10分で期限切れになります。相手のデバイスで新しいコードを表示してもらってください。';
	@override String get linkExpired => 'そのリンクは期限切れです。相手のデバイスで新しいQRコードを表示してもらってください。';
	@override String areYouSure({required Object device}) => '${device}をこのアカウントにリンクしますか？';
	@override String get unnamedDevice => '名前のないデバイス';
	@override String get grantWarning => 'このアカウントのすべてのオペレーションとQSOを読み取り、変更できるようになります。';
	@override String get needsSyncTitle => 'このデバイスはまだ同期していません';
	@override String get needsSyncText => '別のデバイスを参加させるには、Ham2K Log Filerの同期をオンにして、このデバイスをアカウントにリンクしてください。';
	@override String get malformedRequest => '同期サーバーから、このアプリが読み取れないリクエストが送られてきました。相手のデバイスで再試行してもらってください。';
	@override String get linkIt => 'デバイスをリンク';
}

// Path: switchAccounts
class _Translations$switchAccounts$ja extends Translations$switchAccounts$en {
	_Translations$switchAccounts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'アカウントの詳細はまだありません';
	@override String get currentAccount => '現在のアカウント';
	@override String get otherAccounts => 'その他のアカウント';
	@override String get linkToAnother => '別のアカウントにリンク';
	@override String get linkWithSibling => '他のHam2Kアプリとリンク';
	@override String get linkWithPolo => '旧バージョンのアカウントとリンク';
	@override String get linkWithSiblingDescription => '別のHam2Kアプリがインストールされています。そこで使用中のアカウントとリンクします。';
	@override String siblingPrompt({required Object app}) => '${app}でリクエストを承認してから、ここに戻ってください。';
	@override String openSiblingAgain({required Object app}) => '${app}をもう一度開く';
	@override String get siblingNoGrant => 'うまくいきませんでしたか？もう一度開くか、戻って別の方法でリンクしてください。';
	@override String siblingOpenFailed({required Object app}) => '${app}を開けませんでした。';
	@override String siblingLinkRenewed({required Object app}) => 'リンクの期限が切れたため、新しいリンクを用意しました。${app}をもう一度開いてください。';
	@override String get tryAgain => '再試行';
	@override String get linkWithQr => 'QRコードでリンク';
	@override String get linkWithQrDescription => 'そのアカウントを使用中のデバイスからスキャン';
	@override String get linkWithEmail => 'メールアドレスでリンク';
	@override String get linkWithEmailDescription => 'コードまたはメールのリンクで確認';
	@override String get enterEmailPrompt => 'このデバイスで使用するアカウントのメールアドレスを入力してください。';
	@override String get emailAddress => 'メールアドレス';
	@override String get linkAccount => 'アカウントをリンク';
	@override String get copiedCode => 'コードをクリップボードにコピーしました';
	@override String get copyCode => 'コードをコピー';
	@override String codePrompt({required Object email}) => '${email}ですでにリンクされているデバイスでHam2Kアプリを開き、このコードを入力してリクエストを承認してください：';
	@override String get waitingForConfirmation => '確認を待っています…';
	@override String get sendEmailInstead => '代わりに確認メールを送信';
	@override String emailSent({required Object email}) => '${email}にメールを送信しました。メールを開いてリクエストを確認し、このデバイスをリンクしてください。';
	@override String get resendEmail => 'メールを再送信';
	@override String get qrPrompt => '使用したいアカウントにすでにリンクされているデバイス（例：スマートフォンのHam2K Portable Logger）から、このQRコードをスキャンしてください。';
	@override String get serverUnreachable => '同期サーバーに接続できませんでした。後で再試行してください。';
	@override String get emailRequired => 'リンクするメールアドレスを入力してください。';
	@override String noAccountForEmail({required Object email}) => '${email}のアカウントが見つかりません。';
	@override String serverRejected({required Object error}) => '同期サーバーがリクエストを拒否しました：${error}';
	@override String get noLinkCode => '同期サーバーがリンクコードを返しませんでした。後で再試行してください。';
	@override String get noConfirmationCode => '同期サーバーが確認コードを送信しませんでした。後で再試行してください。';
	@override String get switchNotAccepted => 'そのアカウントは切り替えを受け付けませんでした。代わりにメールアドレスでリンクしてみてください。';
	@override String get requestFailed => '同期サーバーとの通信で問題が発生しました。後で再試行してください。';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のQSO',
		other: '${count}件のQSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のオペレーション',
		other: '${count}件のオペレーション',
	);
}

// Path: qsonImport
class _Translations$qsonImport$ja extends Translations$qsonImport$en {
	_Translations$qsonImport$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSONオペレーションをインポート';
	@override String get description => '開発者モードでここやPoLoから書き出したQSONファイルから、新しいオペレーションを作成します。';
	@override String get dropHint => 'QSONファイルをドロップして新しいオペレーションとしてインポート';
	@override String importing({required Object filename}) => '${filename}をインポート中…';
	@override String failed({required Object filename, required Object error}) => '${filename}をインポートできませんでした：${error}';
	@override String pickerFailed({required Object error}) => 'インポートするファイルを開けませんでした：${error}';
	@override String notUtf8({required Object filename}) => '${filename}はUTF-8テキストではないため、QSONファイルではありません';
	@override String notJson({required Object filename}) => '${filename}はJSONファイルではないため、QSONファイルではありません';
	@override String notOperation({required Object filename}) => '${filename}にはQSONオペレーションが含まれていません';
	@override String get busy => 'すでにインポートを実行中です。完了してから次のインポートを開始してください。';
	@override String get oneFileOnly => 'QSONファイルは1つずつドロップしてください。それぞれが別のオペレーションとして開きます。';
}

// Path: adifImport
class _Translations$adifImport$ja extends Translations$adifImport$en {
	_Translations$adifImport$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ADIFからQSOをインポート';
	@override String reading({required Object filename}) => '${filename}を読み込み中…';
	@override String get dropHint => 'ADIFファイルをドロップしてインポート';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'このファイルのQSO：${count}件',
		other: 'このファイルのQSO：${formatted}件',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件はすでにログにあります',
		other: '${formatted}件はすでにログにあります',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件をインポートします',
		other: '${formatted}件をインポートします',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の新しいコンタクト',
		other: '${formatted}件の新しいコンタクト',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件は既存のコンタクトと統合されます',
		other: '${formatted}件は既存のコンタクトと統合されます',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件はインポートできません（コールサインなし）',
		other: '${formatted}件はインポートできません（コールサインなし）',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件は確認が必要です',
		other: '${formatted}件は確認が必要です',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のコンタクトのリファレンスを復元できませんでした',
		other: '${formatted}件のコンタクトのリファレンスを復元できませんでした',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のコンタクトの${programs}リファレンスが不完全な可能性があります',
		other: '${formatted}件のコンタクトの${programs}リファレンスが不完全な可能性があります',
	);
	@override String get stackingTypesUnknown => '統合されたコンタクトでリファレンスが失われる可能性があります。どの種類が重ねられるかをアクティビティが示せませんでした。これを避けるには、キャンセルして再試行してください。';
	@override String get nothingToImport => 'このファイルにはインポートできるものがありません';
	@override String get confirm => 'インポート';
	@override String importing({required Object filename}) => '${filename}をインポート中…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${filename}から${count}件のコンタクトをインポートしました',
		other: '${filename}から${formatted}件のコンタクトをインポートしました',
	);
	@override String failed({required Object filename, required Object error}) => '${filename}をインポートできませんでした：${error}';
	@override String notAdif({required Object filename}) => '${filename}はADIFファイルではないようです';
	@override String stationWarning({required Object calls, required Object station}) => '警告：このADIFには${calls}のQSOが含まれていますが、続行すると${station}としてインポートされます。';
	@override String get stationCallJoin => 'と';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件は日付がないためインポートできません',
		other: '${formatted}件は日付がないためインポートできません',
	);
	@override String activationFound({required Object refs}) => 'このファイルには${refs}のアクティベーションが記録されています。';
	@override String get addActivation => 'このオペレーションに追加';
	@override String shortfall({required Object planned, required Object written}) => '${planned}件中${written}件しか適用できませんでした。判断している間にログが変更されました。';
	@override String get busy => 'すでにインポートを実行中です。完了してから次のインポートを開始してください。';
	@override String get oneFileOnly => 'ADIFファイルは1つずつドロップしてください。インポートの順序によって、どのデータが優先されるかが決まります。';
	@override String tooMany({required Object filename, required Object limit}) => '${filename}のQSOは${limit}件を超えています。これは1つのオペレーションで一度にインポートできる上限です。';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename}のQSOは${limit}件を超えています。オペレーションへのADIFインポートは少数のQSOを追加するためのもので、大きなログを取り込むためのものではありません。それにはログビューを使ってください。確信がある場合は、開発者モードでそのままインポートできます。';
	@override String get importAnyway => 'それでもインポート';
}

// Path: offline
class _Translations$offline$ja extends Translations$offline$en {
	_Translations$offline$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'インターネット：オフライン';
	@override String get statusOnline => 'インターネット：接続済み';
	@override String get noRoute => 'ネットワーク接続がまったくありません。';
	@override String get unreachable => 'ネットワークは接続されていますが、どのサーバーも応答していません。多くの場合、ブラウザでログインページが待機しています。';
	@override String get reachable => 'すべてのサービスが正常に応答しています。';
	@override String get whatStops => '検索、スポット、データファイルは一時停止中です。ロギングと近くのデバイスとの同期は停止していません。';
	@override String get servicesTitle => 'サービス';
	@override String get noServices => 'まだ報告したサービスはありません。';
	@override String lastSuccess({required Object when}) => '${when}前に最終応答';
	@override String get neverSucceeded => 'まだ応答していません';
	@override String nextAttempt({required Object when}) => '${when}後に次の試行';
	@override String get nextAttemptNow => '次の試行の時刻です';
	@override String get retry => '今すぐ再試行';
	@override String get retrying => '試行中…';
	@override String get retryReached => 'オンラインに復帰しました。';
	@override String get retryUnreachable => 'まだ応答がありません。';
	@override String get retryNotAttempted => '現在送信するものはありません。';
	@override String get retryThrottled => '試行したばかりです。少し待ってください。';
	@override String get retryDisabled => '同期がオフのため、確認に使えるものがありません。';
	@override String get syncService => 'Ham2K LoFi 同期';
	@override String get retryInFlight => 'すでに試行中です。お待ちください。';
}

// Path: exportSettings
class _Translations$exportSettings$ja extends Translations$exportSettings$en {
	_Translations$exportSettings$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'すべてのエクスポートの基本設定です。リファレンス付きアクティビティとその他のアクティビティで、ファイル名とタイトルのテンプレートを別々に設定できます。エクスポート種別ごとに、独自のデフォルトまたはカスタム設定を提供できます。';
	@override String get referenceActivities => 'リファレンス付きアクティビティ';
	@override String get otherActivities => 'その他のアクティビティ';
	@override String get adifFields => 'ADIFフィールド';
	@override String get loadFailed => 'エクスポート設定を読み込めませんでした。';
	@override String get retry => '再試行';
	@override String get compactFileNamesDescriptionOn => 'コンパクトなファイル名（例：N0CALL@US-1234-20260715.adi）。';
	@override String get compactFileNamesDescriptionOff => '説明的なファイル名（例：2026-07-15 N0CALL at US-1234.adi）。';
	@override String get includePrivateDataDescriptionOn => 'ADIFファイルに名前、住所、メール、メモ、正確な位置を含めています。';
	@override String get includePrivateDataDescriptionOff => '名前、住所、メール、メモを除外し、位置を6文字のグリッドに制限しています。';
	@override String get includeLookupDataDescriptionOn => 'コールサイン検索サービスからの情報を含めています。';
	@override String get includeLookupDataDescriptionOff => 'コールサイン検索サービスからの情報を除外し、手動で入力した値は保持しています。';
	@override String get customTemplatesDescriptionOn => 'カスタムテンプレートが有効で、下で編集できます。';
	@override String get customTemplatesDescriptionOff => 'デフォルトテンプレートが有効です。カスタムテンプレートは後で使えるよう保持されています。';
	@override String get type => 'エクスポート種別';
	@override String get defaults => 'デフォルト';
	@override String get includeLookupData => '検索データを含める';
	@override String get customTemplates => 'カスタムテンプレート';
	@override String get filenameTemplate => 'ファイル名テンプレート';
	@override String get compactFilenameTemplate => 'コンパクトファイル名テンプレート';
	@override String get titleTemplate => 'タイトルテンプレート';
	@override String get adifNotesTemplate => 'ADIF QSOノート';
	@override String get adifCommentTemplate => 'ADIF QSOコメント';
	@override String get adifQslMessageTemplate => 'ADIF QSLメッセージ';
	@override String get shared => 'この設定は、このエクスポート種別を使用するすべての拡張機能に適用されます。';
	@override String get defaultTemplates => 'この種別のテンプレートを編集するには、カスタムテンプレートをオンにしてください。';
}

// Path: templateEditor
class _Translations$templateEditor$ja extends Translations$templateEditor$en {
	_Translations$templateEditor$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'プレビュー：';
	@override String get reset => 'リセット';
	@override String get docs => 'テンプレートのドキュメント';
	@override String get preview => 'サンプルプレビュー';
	@override String get reference => 'テンプレートリファレンス';
	@override String get attributes => '使用可能な属性';
	@override String get filters => 'フィルター';
	@override String get flowControl => 'フロー制御';
	@override String get unavailable => '拡張機能の準備ができるまでプレビューは利用できません。';
	@override String get empty => '（出力なし）';
}

// Path: home.nav
class _Translations$home$nav$ja extends Translations$home$nav$en {
	_Translations$home$nav$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get operations => 'オペレーション';
	@override String get chase => 'チェイス';
	@override String get logs => 'ログ';
	@override String get maps => '地図';
	@override String get settings => '設定';
}

// Path: home.panels
class _Translations$home$panels$ja extends Translations$home$panels$en {
	_Translations$home$panels$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get operations => 'オペレーションリスト';
	@override String get operationsDescription => 'あなたのオペレーション（新しい順）。';
	@override String get version => '現在のバージョン';
	@override String get versionDescription => 'Ham2Kのロゴ、アプリ名、実行中のビルド。';
}

// Path: home.logs
class _Translations$home$logs$ja extends Translations$home$logs$en {
	_Translations$home$logs$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ログ';
	@override String get titleFor => 'ログ：';
	@override String get emptyCallsigns => 'まだQSOがありません';
	@override String emptyQsos({required Object call}) => '${call}のQSOはありません';
	@override String get mapNoSelection => 'QSOを選択すると地図に表示されます';
	@override String get searchHint => 'コールサインまたは名前で検索';
	@override String get noSearchMatches => '検索に一致するQSOはありません';
	@override String get titleAll => 'すべてのログ';
	@override String get allCallsigns => 'すべてのコールサイン';
	@override String get noOperation => 'オペレーションに属していません';
	@override String get unsavedTitle => '未保存の変更';
	@override String get unsavedBody => 'このQSOには保存されていない変更があります。';
	@override String get pendingDeleteBody => 'このQSOは削除予定です。';
	@override String get editGone => '保存されませんでした：そのQSOはもうこのログにありません。';
	@override String get discard => '破棄';
	@override late final _Translations$home$logs$sheet$ja sheet = _Translations$home$logs$sheet$ja._(_root);
	@override late final _Translations$home$logs$groupBy$ja groupBy = _Translations$home$logs$groupBy$ja._(_root);
	@override late final _Translations$home$logs$period$ja period = _Translations$home$logs$period$ja._(_root);
	@override late final _Translations$home$logs$periodTitle$ja periodTitle = _Translations$home$logs$periodTitle$ja._(_root);
	@override late final _Translations$home$logs$columns$ja columns = _Translations$home$logs$columns$ja._(_root);
	@override late final _Translations$home$logs$panels$ja panels = _Translations$home$logs$panels$ja._(_root);
	@override late final _Translations$home$logs$import$ja import = _Translations$home$logs$import$ja._(_root);
}

// Path: chase.station
class _Translations$chase$station$ja extends Translations$chase$station$en {
	_Translations$chase$station$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'チェイス局';
	@override String get stationLabel => '局：';
	@override String get operatorLabel => 'Op：';
	@override String get noLocation => '位置なし';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$ja extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get today => '今日';
	@override String get thisWeek => '今週';
	@override String get last14Days => '過去14日間';
	@override String get thisMonth => '今月';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$ja extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get today => '今日の統計';
	@override String get thisWeek => '今週の統計';
	@override String get last14Days => '過去14日間の統計';
	@override String get thisMonth => '今月の統計';
}

// Path: chase.period
class _Translations$chase$period$ja extends Translations$chase$period$en {
	_Translations$chase$period$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get today => '今日';
	@override String get thisWeek => '今週';
	@override String get last14Days => '過去14日間';
	@override String get thisMonth => '今月';
}

// Path: chase.goals
class _Translations$chase$goals$ja extends Translations$chase$goals$en {
	_Translations$chase$goals$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'チェイス目標';
	@override String remove({required Object name}) => '${name}のチェイスをやめる';
	@override String get extensionsTitle => 'その他のチェイスプログラム';
}

// Path: chase.panels
class _Translations$chase$panels$ja extends Translations$chase$panels$en {
	_Translations$chase$panels$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => '期間内にチェイスしたQSOの上にあるロギング操作。';
	@override String get info => '情報';
	@override String get infoDescription => 'ロギング中のコールサイン、または期間の統計。';
	@override String get spots => 'スポット';
	@override String get spotsDescription => 'オンエア中にスポットされた、チェイスできる局。';
	@override String get map => '地図';
	@override String get mapDescription => '期間内のQSOとロギング中の局。';
}

// Path: chase.claims
class _Translations$chase$claims$ja extends Translations$chase$claims$en {
	_Translations$chase$claims$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get checking => 'チェイス対象のQSOを確認中';
	@override String rebuilding({required Object program}) => '${program}のログを確認中';
	@override String progress({required Object total, required Object done}) => '${total}件中${done}件のQSO';
}

// Path: chase.notice
class _Translations$chase$notice$ja extends Translations$chase$notice$en {
	_Translations$chase$notice$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => '新しい${program}';
	@override String newRefGuess({required Object program}) => 'おそらく新しい${program}';
	@override String newBand({required Object program}) => '新しい${program}バンド';
	@override String newBandGuess({required Object program}) => 'おそらく新しい${program}バンド';
	@override String newMode({required Object program}) => '新しい${program}モード';
	@override String newModeGuess({required Object program}) => 'おそらく新しい${program}モード';
	@override String unconfirmed({required Object program}) => '${program}未確認';
	@override String programGuess({required Object notice}) => 'おそらく${notice}';
}

// Path: chase.alerts
class _Translations$chase$alerts$ja extends Translations$chase$alerts$en {
	_Translations$chase$alerts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'アラート';
	@override String get newRef => '新しいリファレンス';
	@override String get newBand => '新しいバンド';
	@override String get newMode => '新しいモード';
	@override String get unconfirmed => '未確認';
}

// Path: chase.imports
class _Translations$chase$imports$ja extends Translations$chase$imports$en {
	_Translations$chase$imports$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => '${label}をインポート';
	@override String pickTitle({required Object file}) => '${file}のインポート先';
	@override String get dropHint => 'ファイルをドロップしてチェイスプログラムにインポート';
	@override String done({required Object file, required Object program, required Object count}) => '${file}から${program}のエントリー${count}件をインポートしました';
	@override String doneSkipped({required Object file, required Object program, required Object count, required Object skipped}) => '${file}から${program}のエントリー${count}件をインポートしました。読み取れなかった${skipped}件はスキップしました';
	@override String nothing({required Object file, required Object program}) => '${file}には${program}がインポートできるものがありません';
	@override String failed({required Object program, required Object file}) => '${program}は${file}を読み取れませんでした';
	@override String unreadable({required Object program, required Object file, required Object skipped}) => '${program}は${file}の${skipped}件のレコードをどれも読み取れませんでした';
	@override String noProgram({required Object file}) => '${file}をインポートできるチェイスプログラムはありません';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$ja extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オンラインで検索しますか？';
	@override String get body => 'このオペレーションではアシスタンスが無効です。すべてのQSOを検索すると、今回に限りQRZなどのオンラインサービスを使用します。';
	@override String bodyRules({required Object rules}) => 'このオペレーションでは${rules}のルールに従うためアシスタンスが無効です。すべてのQSOを検索すると、今回に限りQRZなどのオンラインサービスを使用します。';
	@override String get action => 'オンラインで検索';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$ja extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => '無効なコールサイン：${call}';
	@override String invalidCallsigns({required Object calls}) => '無効なコールサイン：${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => 'これまでは${previous}が運用しました。新しいコンタクトには${typed}が記録されます。';
	@override String operatorNoneSoFar({required Object typed}) => 'これまでオペレーターは記録されていません。新しいコンタクトには${typed}が記録されます。';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'このオペレーションにはすでに${calls}によるコンタクトがあります。${typed}は新しいコンタクトにのみ記録されます。';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '記録済みのコンタクトのオペレーターにも${typed}を記録する',
		other: '記録済みの${count}件すべてのコンタクトのオペレーターにも${typed}を記録する',
	);
	@override String get operatorSeveralStations => '複数のステーションコールサインで運用する場合、オペレーターを個別に設定できません';
	@override String get contactsUnreadable => 'このオペレーションのコンタクトを読み取れなかったため、ここでコールサインを変更しても更新は提案されません';
	@override String restampFailed({required Object error}) => '記録済みのコンタクトを更新できなかったため、変更は行われませんでした：${error}';
	@override String restampShortfall({required Object planned, required Object written}) => '${planned}件中${written}件のコンタクトを更新しました。残りはもうこのオペレーションにありません';
}

// Path: operation.tabs
class _Translations$operation$tabs$ja extends Translations$operation$tabs$en {
	_Translations$operation$tabs$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => '情報';
	@override String get spots => 'スポット';
	@override String get map => '地図';
	@override String get qsosPlain => 'QSO';
	@override String get clock => '時計';
	@override String get weather => '天気';
	@override String get website => 'Webサイト';
	@override String get remoteScreen => 'リモート画面';
	@override String get solar => '太陽活動';
	@override String get radio => '無線機';
	@override String get rotator => 'ローテーター';
	@override String get summaries => 'オペレーション概要';
}

// Path: operation.positions
class _Translations$operation$positions$ja extends Translations$operation$positions$en {
	_Translations$operation$positions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'このオペレーションを共有している他の運用ポジションはまだありません。';
	@override String positionLabel({required Object number}) => 'ポジション：${number}';
	@override String operatorLabel({required Object call}) => 'Op：${call}';
	@override String get unnamedPosition => '別のポジション';
	@override String get thisDevice => '自分の運用ポジション';
	@override String get nameIn => '：';
	@override String get panelTitle => 'ポジション';
	@override String get panelDescription => 'このオペレーションを共有している各運用ポジションが現在ロギング中の内容。';
}

// Path: operation.menu
class _Translations$operation$menu$ja extends Translations$operation$menu$en {
	_Translations$operation$menu$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'RSTフィールドを表示';
	@override String get showStateField => '州フィールドを表示';
	@override String get showGridField => 'グリッドフィールドを表示';
	@override String get showDeletedQsos => '削除したQSOを表示';
	@override String get showDeletedOps => '削除したオペレーションを表示';
	@override String get showQsoNumbers => 'QSO番号を表示';
	@override String get lookupAllQsos => 'すべてのQSOを検索';
	@override String get loggingSettingsTitle => 'ロギング設定';
	@override String get mapSettingsTitle => '地図設定';
	@override String get actionsSection => 'アクション';
}

// Path: operation.layout
class _Translations$operation$layout$ja extends Translations$operation$layout$en {
	_Translations$operation$layout$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'パネルを追加';
	@override String get availableSection => '利用可能なパネル';
	@override String panelSettings({required Object panel}) => '${panel}の設定';
	@override String get panelSettingsAction => 'パネル設定';
	@override String get viewName => 'オペレーションビュー';
	@override String get viewOptions => 'ビューのレイアウトオプション';
	@override String get viewTitleBuiltIn => 'このビューはアプリに組み込まれており、名前も固定です';
	@override String get resetOptions => 'デフォルトに戻す';
	@override String get removePane => '削除';
	@override String resetPaneConfirm({required Object panel}) => '${panel}をデフォルトに戻しますか？';
	@override String get resetPaneConfirmBody => 'タイトル、ヘッダー、サイズがデフォルトに戻ります。レイアウトの他の部分はそのままです。';
	@override String get resetViewConfirm => 'このビューをデフォルトのレイアウトに戻しますか？';
	@override String get resetViewConfirmBody => 'パネルはデフォルトの配置に戻り、ビューと各パネルのオプションもデフォルトに戻ります。';
	@override String paneOptionsTitle({required Object panel}) => '${panel}のレイアウト設定';
	@override String get paneTitle => 'タイトル';
	@override String get paneShowHeader => 'ヘッダーを表示';
	@override String get paneShowHeaderTabset => 'このペインがグループを共有している間は常に表示されます。ヘッダーから他のペインに切り替えるためです';
	@override String get paneInherit => 'アプリと同じ';
	@override String get searchHint => 'パネルを検索';
	@override String get noPanelsMatch => '検索に一致するパネルはありません。';
	@override String get nothingToAdd => 'このビューにはすでにすべてのパネルがあります';
	@override String addPanel({required Object panel}) => '${panel}を追加';
	@override String showPreview({required Object panel}) => '${panel}をプレビュー';
	@override String missingExtension({required Object name}) => '拡張機能「${name}」が見つかりません';
	@override String get missingExtensionEnable => '有効にする';
	@override String get missingExtensionInstall => 'インストール…';
	@override String get missingExtensionWontRun => 'このバージョンは動作しません。設定 › 拡張機能でアップデートしてください。';
	@override String get missingExtensionUnavailable => 'このアプリでは利用できません';
	@override String get missingExtensionNotInCatalog => 'カタログにありません';
	@override String get missingExtensionCatalogUnreachable => 'カタログに接続できませんでした。再試行';
	@override String get missingExtensionFailed => 'うまくいきませんでした。再試行';
	@override String get previewUnavailable => 'このパネルのプレビュー画像を表示できませんでした。';
	@override String get nestedPaneTitle => 'その他';
	@override late final _Translations$operation$layout$layouts$ja layouts = _Translations$operation$layout$layouts$ja._(_root);
	@override String get editLayout => 'レイアウトを編集';
	@override String get saveLayout => 'レイアウトを保存';
	@override String get revertLayout => 'レイアウトの変更を破棄';
	@override String get done => '完了';
	@override String get layoutUnreadableTitle => 'レイアウトを読み込めませんでした';
	@override String get layoutUnreadableBody => '保存したレイアウトを読み込めなかったため、デフォルトの配置を表示しています。保持を選ぶまで元のレイアウトは上書きされません。';
	@override String get layoutUnreadableAction => 'このレイアウトを使用';
	@override String panelRenderFailed({required Object panel}) => '${panel}を表示できませんでした';
	@override String panelOverCharacters({required Object panel, required Object max}) => '${panel}を表示できませんでした：${max}文字を超える内容が送られました';
	@override String panelOverElements({required Object panel, required Object max}) => '${panel}を表示できませんでした：アートワークの要素が${max}個を超えています';
	@override String panelOverDepth({required Object panel, required Object max}) => '${panel}を表示できませんでした：アートワークのネストが${max}階層を超えています';
	@override String panelNotArtwork({required Object panel}) => '${panel}を表示できませんでした：アートワークが自己完結していません';
	@override String panelOverLayers({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンのレイヤーが${max}個を超えています';
	@override String panelOverControls({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンのコントロールが${max}個を超えています';
	@override String panelOverItems({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンの一部のエントリーが${max}個を超えています';
	@override String panelOverStringLength({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンの文字列が${max}文字を超えています';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => '${panel}を表示できませんでした：レイアウトのネストが${max}階層を超えています';
	@override String get panelRenderRetry => '再試行';
	@override String get panelActionFailed => 'パネルの操作に失敗しました。再試行してください。';
	@override late final _Translations$operation$layout$panels$ja panels = _Translations$operation$layout$panels$ja._(_root);
	@override String get htmlPanelUnsupported => 'このパネルにはWebビューが必要ですが、このプラットフォームでは提供されていません';
	@override String get htmlPanelUnsupportedOnWeb => 'このパネルにはWeb版では提供できないサンドボックスが必要です';
}

// Path: operation.export
class _Translations$operation$export$ja extends Translations$operation$export$en {
	_Translations$operation$export$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オペレーションのエクスポート';
	@override String get syncedOperation => 'オペレーションは同期済みです';
	@override String get unsyncedOperation => 'オペレーションに未同期の変更があります';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'このオペレーションのQSO：${count}件',
		other: 'このオペレーションのQSO：${count}件',
	);
	@override String qsosSynced({required Object total}) => '${total}件のQSOすべてが同期済み';
	@override String qsosPending({required Object total, required Object pending}) => '${total}件中${pending}件のQSOが同期待ち';
	@override String eventsSynced({required Object total}) => '${total}件のイベントマーカーが同期済み';
	@override String eventsPending({required Object total, required Object pending}) => '${total}件中${pending}件のイベントマーカーが保留中';
	@override String get loading => 'エクスポートオプションを読み込み中…';
	@override String get noOptions => '利用できるエクスポート形式がありません（拡張機能ランタイムがまだ起動中？）';
	@override String get nothingLogged => 'エクスポートするものはまだありません。このオペレーションにはQSOがありません。';
	@override String get share => '共有';
	@override String get nothingSelected => '何も選択されていません';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルを保存',
		other: '${count}件のファイルを保存',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルを共有',
		other: '${count}件のファイルを共有',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをエクスポート',
		other: '${count}件のファイルをエクスポート',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをダウンロード',
		other: '${count}件のファイルをダウンロード',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の結合ファイルを保存',
		other: '${count}件の結合ファイルを保存',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の結合ファイルを共有',
		other: '${count}件の結合ファイルを共有',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の結合ファイルをエクスポート',
		other: '${count}件の結合ファイルをエクスポート',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の結合ファイルをダウンロード',
		other: '${count}件の結合ファイルをダウンロード',
	);
	@override String saveOne({required Object name}) => '${name}を保存';
	@override String shareOne({required Object name}) => '${name}を共有';
	@override String exportOne({required Object name}) => '${name}をエクスポート';
	@override String downloadOne({required Object name}) => '${name}をダウンロード';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをスタッシュ',
		other: '${count}件のファイルをスタッシュ',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の結合ファイルをスタッシュ',
		other: '${count}件の結合ファイルをスタッシュ',
	);
	@override String get settingsButton => 'エクスポート設定';
	@override String get settingsTitle => 'エクスポート設定';
	@override late final _Translations$operation$export$compactFileNames$ja compactFileNames = _Translations$operation$export$compactFileNames$ja._(_root);
	@override late final _Translations$operation$export$includePrivateData$ja includePrivateData = _Translations$operation$export$includePrivateData$ja._(_root);
	@override String get resultTitle => 'エクスポート完了';
	@override String get resultFailedTitle => 'エクスポート失敗';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルを${path}にエクスポートしました',
		other: '${count}件のファイルを${path}にエクスポートしました',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをエクスポートしました：${path}',
		other: '${count}件のファイルをエクスポートしました：${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルを共有しました',
		other: '${count}件のファイルを共有しました',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをダウンロードしました',
		other: '${count}件のファイルをダウンロードしました',
	);
	@override String exportFailed({required Object error}) => 'エクスポート失敗：${error}';
	@override late final _Translations$operation$export$stash$ja stash = _Translations$operation$export$stash$ja._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$ja extends Translations$operation$spots$en {
	_Translations$operation$spots$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get empty => 'フィルターに一致するスポットはありません';
	@override String error({required Object error}) => 'スポットの読み込みに失敗しました：${error}';
	@override String get unknownBand => 'その他';
	@override String get auto => '自動';
	@override String autoValue({required Object value}) => '自動（現在${value}）';
	@override String valueAuto({required Object value}) => '${value}（自動）';
	@override String get any => 'すべて';
	@override String get allBands => 'すべてのバンド';
	@override String get allModes => 'すべてのモード';
	@override String get phoneAndCw => '電話とCW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}スポット',
		other: '${count}スポット',
	);
	@override String spotsCountFiltered({required Object total, required Object count}) => '${total}件中${count}件のスポットを表示';
	@override String get spotsDisabled => 'このオペレーションではスポットが無効です';
	@override String ageMinutes({required Object minutes}) => '${minutes}分';
	@override String get callsOfNote => '注目のコール';
	@override String get yourSpots => 'あなたのスポット';
	@override String get allSpots => 'すべてのスポット';
	@override late final _Translations$operation$spots$continents$ja continents = _Translations$operation$spots$continents$ja._(_root);
	@override late final _Translations$operation$spots$filters$ja filters = _Translations$operation$spots$filters$ja._(_root);
	@override String get unavailableTitle => 'スポットを利用できません';
	@override String unavailableText({required Object sources}) => '${sources}が応答しませんでした。';
	@override String get failedTitle => 'スポットソースのエラー';
	@override String failedText({required Object sources}) => '${sources}がエラーを返しました。';
	@override String get slideLogIt => 'ログに記録';
	@override String get slideIgnore => '無視';
	@override String get slideRestore => '元に戻す';
	@override late final _Translations$operation$spots$logConflict$ja logConflict = _Translations$operation$spots$logConflict$ja._(_root);
}

// Path: operation.import
class _Translations$operation$import$ja extends Translations$operation$import$en {
	_Translations$operation$import$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オペレーションにデータをインポート';
	@override String get importAdifAction => 'ADIFからQSOをインポート';
	@override String get settingsButton => '受信設定';
	@override String get settingsTitle => '他のアプリから受信';
	@override String get protocolAddressLabel => 'アドレス';
	@override String get protocolPortLabel => 'ポート';
	@override String get protocolPortInvalid => '1から65535までのポートを入力してください';
	@override String get protocolAddressInvalid => '有効なIPアドレスを入力してください（例：127.0.0.1または239.239.0.2）';
	@override String get protocolStatusReceiving => 'データ受信中';
	@override String get protocolStatusNoData => '最近データを受信していません';
	@override String protocolBindError({required Object error}) => '受信を開始できませんでした：${error}';
	@override String captureFailed({required Object error}) => '受信したQSOを保存できなかったため、再試行しています：${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'すべて（ブロードキャスト）';
	@override String get wsjtxProtocolName => 'WSJT-X UDPサーバー';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Broadcast Data タブ → コンタクト情報の「Enable Broadcasts」にチェック。同じコンピューターで実行している場合はIPアドレスを127.0.0.1に、現在のローカルネットワークにブロードキャストする場合は255.255.255.255に設定します。';
	@override String get helpWsjtxSetup => 'File → Settings → Reporting タブ → UDP Server セクション → 「Accept UDP requests」にチェック。同じコンピューターで実行している場合はUDP Serverを127.0.0.1に、または239.239.0.2のようなマルチキャストアドレスに設定し、このアプリの上記の設定でも同じアドレスを使用します。';
	@override String get listenTitle => '他のアプリからQSOを受信';
	@override String get listenDescriptionOnN1mm => 'N1MM+から受信中';
	@override String get listenDescriptionOnWsjtx => 'WSJT-Xから受信中';
	@override String get listenDescriptionOnBoth => 'N1MM+とWSJT-Xから受信中';
	@override String get listenDescriptionOff => 'オフ';
	@override String get addToOperationTitle => 'このオペレーションに追加';
	@override String get addToOperationDescriptionOn => '受信したQSOは届き次第このオペレーションに追加されます';
	@override String get addToOperationDescriptionOff => '受信したQSOはこれをオンにするまで保留されます';
	@override String get pendingSectionTitle => '受信したQSO';
	@override String get pendingEmpty => 'まだ何も受信していません';
	@override String stationMismatch({required Object call}) => '${call}として記録されています（このオペレーションの局ではありません）';
	@override String get discardAction => '破棄';
	@override String get gapDialogTitle => '以前に受信したものも含めますか？';
	@override String gapDialogBody({required Object count}) => 'データの途切れより前に、さらに${count}件のQSOを受信しています。それらも含めますか？';
	@override String get gapDialogRecentOnly => '最近のものだけ';
	@override String gapDialogIncludeAll({required Object count}) => '${count}件すべてを含める';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$ja extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get link => '問題がありますか？';
	@override String get title => '境界線の問題を報告';
	@override String get reference => '対象の境界線';
	@override String get severity => 'どの程度の問題ですか？';
	@override String get minor => '軽微';
	@override String get major => '重大';
	@override String get explanation => '何が問題ですか？';
	@override String get explanationHint => '境界線のどこが、どう間違っているか';
	@override String get send => '送信';
	@override String get sending => '報告を送信しています。ありがとうございます';
	@override String get copy => '報告をコピー';
	@override String get notSent => '報告を送信できませんでした';
	@override String get copied => '報告をコピーしました';
	@override String get notCopied => '報告をコピーできませんでした';
}

// Path: map.postcard
class _Translations$map$postcard$ja extends Translations$map$postcard$en {
	_Translations$map$postcard$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get button => 'オペレーションのポストカード';
	@override String title({required Object title}) => '${title}のポストカード';
	@override String get portrait => '縦';
	@override String get landscape => '横';
	@override String get square => '正方形';
	@override String get save => '保存…';
	@override String get download => 'ダウンロード';
	@override String get share => '共有';
	@override String get copy => 'コピー';
	@override String get copied => 'クリップボードにコピーしました';
	@override String saved({required Object path}) => '${path}に保存しました';
	@override String downloaded({required Object name}) => '${name}をダウンロードしました';
	@override String savedMany({required Object count, required Object path}) => '${count}枚の画像を${path}に保存しました';
	@override String savedFiles({required Object names}) => '${names}を保存しました';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names}は保存済みでした';
	@override String downloadedMany({required Object count}) => '${count}枚の画像をダウンロード中です。ブラウザに確認されたら許可してください';
	@override String get mapLeftOut => '地図が読み込まれなかったため、省略しました';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — 地図が読み込まれなかったため、省略しました';
	@override String continued({required Object title}) => '${title}（続き）';
	@override String get previousPage => '前のページ';
	@override String get nextPage => '次のページ';
	@override String pageOf({required Object page, required Object count}) => '${page} / ${count}ページ';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count} Q',
		other: '${count} Q',
	);
	@override String get options => 'ポストカードのオプション';
	@override String get bandLegend => 'バンドの凡例を表示';
	@override String get grayline => 'グレイラインを表示';
	@override String get sectionsAndOrder => '概要のセクションと順序';
	@override String get sectionDays => '日ごと';
	@override String get reset => 'リセット';
	@override String failed({required Object error}) => 'ポストカードを作成できませんでした：${error}';
	@override String get mapNotReady => '地図の読み込みが完了しませんでした。接続を確認して再試行してください。';
	@override String saveFailed({required Object error}) => 'ポストカードを保存できませんでした：${error}';
	@override String get copyFailed => 'クリップボードに画像をコピーできませんでした。再試行してください。';
	@override String get shareFailed => 'ポストカードを共有できませんでした。再試行してください。';
	@override String get fileName => 'postcard';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$ja extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'まだQSOがありません... オンエアしましょう！';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object time, required Object count}) => '${time}で${count}';
	@override String sinceLast({required Object time}) => '最後から${time}';
	@override String ratePer10({required Object rate}) => '最後の10件で${rate} Q/h';
	@override String ratePer100({required Object rate}) => '最後の100件で${rate} Q/h';
	@override String distanceTo({required Object distance}) => '${distance} →';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance}（${bearing}°）→';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）→';
	@override String distanceAway({required Object distance}) => '${distance} 離れた所';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance}（${bearing}°）離れた所';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）離れた所';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}：${notice}';
	@override String get noticeDupe => '重複！';
	@override String get noticeNewBand => '新しいバンド';
	@override String get noticeNewMode => '新しいモード';
	@override String get noticeNewDXCC => '新しいDXCC';
	@override String get noticeNewState => '新しい州';
	@override String get noticeNewProvince => '新しい州/県';
	@override String get noticeNewDay => '新しい日';
	@override String get noticeNewRef => '新しいリファレンス';
	@override String get noticeNewMult => '新しいマルチ';
	@override String get noticeNewZone => '新しいゾーン';
	@override String get noticeInvalidMode => 'モード違い';
	@override String get noticeInvalidBand => 'バンド違い';
	@override String get noticeInvalidCategory => '交信対象外';
	@override String get noticeOverTime => '時間外';
	@override String get noticeWorkedBefore => '交信済み';
	@override String get noticeNewPark => '新しい公園';
	@override String get noticeNewSection => '新しいセクション';
	@override String get noticeBonusStation => 'ボーナス局！';
	@override String get noticeMissingExchange => '交換なし';
	@override String get noticeInvalidExchange => '交換が不正';
	@override String get noticeUnknownEvent => '不明なイベント';
	@override String get noticeIncompleteCall => 'コール不完全 — スコア対象外';
	@override String get noticeOurGrid => '自局グリッドを設定';
	@override String get noticeRareCounty => 'レアな郡！';
	@override String get noticeOurLocation => '自局の郡を設定';
	@override String get noticeShortGrid => 'グリッドが短すぎます';
}

// Path: qsoList.find
class _Translations$qsoList$find$ja extends Translations$qsoList$find$en {
	_Translations$qsoList$find$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => 'ログ内を検索（${shortcut}）';
	@override String get menuItemNoShortcut => 'ログ内を検索';
	@override String get hint => 'QSO番号またはコールサイン';
	@override String get noMatches => '一致なし';
	@override String get noOperationQsos => 'このオペレーションにQSOはありません';
	@override String get noPeriodQsos => 'この期間にQSOはありません';
	@override String get outsideQsosOne => 'このオペレーション外のQSO：1件';
	@override String outsideQsosOther({required Object count}) => 'このオペレーション外のQSO：${count}件';
	@override String get pastQsosOne => '過去のQSO：1件';
	@override String pastQsosOther({required Object count}) => '過去のQSO：${count}件';
}

// Path: callInfo.history
class _Translations$callInfo$history$ja extends Translations$callInfo$history$en {
	_Translations$callInfo$history$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '過去7日間：${n}件';
	@override String today({required Object n}) => '今日：${n}件';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$ja extends Translations$settings$theme$en {
	_Translations$settings$theme$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'テーマモード';
	@override String get system => 'システム設定に従う';
	@override String get light => 'ライト';
	@override String get dark => 'ダーク';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$ja extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get system => 'システム設定に従っています';
	@override String get light => '常にライトモード';
	@override String get dark => '常にダークモード';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$ja extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => '最小--';
	@override String get smallestMinus => '最小-';
	@override String get smallest => '最小';
	@override String get smaller => '小さい';
	@override String get normal => '標準';
	@override String get larger => '大きい';
	@override String get largest => '最大';
	@override String get largestPlus => '最大+';
	@override String get largestPlusPlus => '最大++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$ja extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '端末のスリープを無効化';
	@override String get descriptionOn => 'ロギング画面の表示中または同期中はスリープしません';
	@override String get descriptionOff => '通常どおりスリープします';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$ja extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get auto => '自動';
	@override String get densest => '最高密度';
	@override String get dense => '高密度';
	@override String get normal => '標準';
	@override String get sparse => '低密度';
	@override String get sparsest => '最低密度';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$ja extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'キロメートル';
	@override String get miles => 'マイル';
}

// Path: settings.logging
class _Translations$settings$logging$ja extends Translations$settings$logging$en {
	_Translations$settings$logging$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ロギング';
	@override late final _Translations$settings$logging$leftieMode$ja leftieMode = _Translations$settings$logging$leftieMode$ja._(_root);
	@override late final _Translations$settings$logging$countryFlags$ja countryFlags = _Translations$settings$logging$countryFlags$ja._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$ja countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$ja._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$ja suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$ja._(_root);
	@override late final _Translations$settings$logging$showBearing$ja showBearing = _Translations$settings$logging$showBearing$ja._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$ja showReverseBearing = _Translations$settings$logging$showReverseBearing$ja._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$ja switchSentRcvd = _Translations$settings$logging$switchSentRcvd$ja._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$ja jumpAfterRST = _Translations$settings$logging$jumpAfterRST$ja._(_root);
	@override late final _Translations$settings$logging$defaultReport$ja defaultReport = _Translations$settings$logging$defaultReport$ja._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$ja defaultReportCW = _Translations$settings$logging$defaultReportCW$ja._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$ja defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$ja._(_root);
	@override late final _Translations$settings$logging$numbersRow$ja numbersRow = _Translations$settings$logging$numbersRow$ja._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$ja numbersRowExtra = _Translations$settings$logging$numbersRowExtra$ja._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$ja numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$ja._(_root);
	@override String get bands => '優先バンド';
	@override String get modes => '優先モード';
}

// Path: settings.catServer
class _Translations$settings$catServer$ja extends Translations$settings$catServer$en {
	_Translations$settings$catServer$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'CATサーバー';
	@override String get description => '他のアプリ（WSJT-X、ロガーなど）がHam2K Logger経由で無線機を制御できるようにします。';
	@override String get protocol => 'プロトコル';
	@override late final _Translations$settings$catServer$protocolOpts$ja protocolOpts = _Translations$settings$catServer$protocolOpts$ja._(_root);
	@override String get port => 'ポート';
	@override String get openAccess => 'オープンアクセス';
	@override String get openAccessOn => 'ローカルネットワーク上のどのコンピューターからも接続できます。';
	@override String get openAccessOff => 'このコンピューター上のアプリのみ接続できます。';
	@override String get allowTransmit => 'アプリからの送信を許可';
	@override String allowTransmitOn({required Object minutes}) => 'アプリは無線機のPTTを、一度に最大${minutes}分までキーイングできます。';
	@override String allowTransmitOnNetwork({required Object minutes}) => 'ローカルネットワーク上のどのコンピューターのアプリも、無線機のPTTを一度に最大${minutes}分までキーイングできます。';
	@override String get allowTransmitOff => 'アプリは無線機をキーイングできません。VOXか、アプリ独自のPTT設定を使ってください。';
	@override String get allowTransmitUnsupported => 'メインVFOの無線機はHam2K Loggerからキーイングできないため、アプリはこの無線機で送信できません。';
	@override String get off => 'オフ。';
	@override String starting({required Object protocol}) => '${protocol}、起動中…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol}：ポート${port}で待ち受け中。接続中のクライアント：${clients}。';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol}：ポート${port}で待ち受け中ですが、メインVFOの無線機が接続されていません。';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol}はポート${port}で待ち受けできません：${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol}はポート${port}で待ち受けできません：別のプログラム（多くの場合${protocol}自体）が使用中です。そのプログラムを閉じるか、別のポートを選んでください。';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol}はポート${port}で待ち受けできません：このコンピューターが許可していません。1024より大きいポートを選んでください。';
	@override String stopped({required Object protocol, required Object port}) => '${protocol}はポート${port}での待ち受けを停止しました。再試行中…';
}

// Path: settings.cluster
class _Translations$settings$cluster$ja extends Translations$settings$cluster$en {
	_Translations$settings$cluster$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'DXクラスター';
	@override String get description => '拡張機能がオペレーターとしてログインし、スポットの投稿と読み取りを行うサーバー。';
	@override String get connect => 'クラスターに接続';
	@override String get connectOn => '拡張機能は必要なときにクラスターに接続します';
	@override String get connectOff => '何もクラスターに接続しません';
	@override String get console => 'コンソールを表示';
	@override String get consoleDescription => 'クラスターからの受信内容と、コマンドを入力する場所';
	@override String get consoleTitle => 'クラスターコンソール';
	@override String get consoleConnect => '接続';
	@override String get consoleDisconnect => '切断';
	@override String get consoleCommand => 'コマンド';
	@override String get consoleEmpty => 'まだ何もありません。接続するか、拡張機能がクラスターを使うのを待ってください。';
	@override String consoleRetry({required Object command}) => '再送信中：${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => '未送信：${command}（${reason}）';
	@override String get server => 'クラスターサーバー';
	@override String get selectServer => 'サーバーを選択';
	@override String get serverOther => 'その他';
	@override String serverOtherIncomplete({required Object node}) => 'ホストが未入力のため、スポットは${node}に送られます';
	@override String get customHost => 'サーバー';
	@override String get customPort => 'ポート';
	@override String get password => 'パスワード';
	@override String get passwordDescription => '必要な場合のみ';
	@override String passwordStored({required Object node}) => '${node}のパスワードを保存済み';
	@override String get scrollback => '保持する行数';
	@override String scrollbackOpt({required Object count}) => '${count}行';
	@override String get connection => '接続';
	@override String get statusIdle => '未接続。拡張機能が必要とすると接続します。タップしてテスト。';
	@override String statusConnecting({required Object node}) => '${node}に接続中…';
	@override String statusConnected({required Object node, required Object call}) => '${node}に${call}として接続済み。';
	@override String statusFailed({required Object node, required Object reason}) => '${node}に接続できませんでした：${reason}';
	@override String get statusUnsupported => 'Web版では利用できません。';
	@override String get statusOff => 'オフ。使用するには「クラスターに接続」をオンにしてください。';
	@override late final _Translations$settings$cluster$errors$ja errors = _Translations$settings$cluster$errors$ja._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$ja extends Translations$settings$spotting$en {
	_Translations$settings$spotting$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スポッティング';
	@override String get respotInterval => '自動再スポットの間隔';
	@override String minutes({required Object minutes}) => '${minutes}分';
	@override String get autoRespotByDefault => 'デフォルトで自動再スポット';
	@override String get autoRespotByDefaultOn => 'スポットを投稿したら自動再スポットを有効にします';
	@override String get autoRespotByDefaultOff => '自動再スポットの有効化には手動の操作が必要です';
	@override String get pulseBeforeRespot => '自動再スポット前に点滅';
	@override String pulseBeforeRespotOn({required Object seconds}) => '各再スポットの${seconds}秒前からスポッティングチップが青く点滅します';
	@override String get pulseBeforeRespotOff => '自動再スポット前に点滅しません';
}

// Path: settings.radio
class _Translations$settings$radio$ja extends Translations$settings$radio$en {
	_Translations$settings$radio$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT制御';
	@override String get loggingAndCat => 'ロギングとCAT';
	@override String get tuningSection => 'チューニング';
	@override String get keyerSection => 'キーヤー';
	@override String get servicesSection => 'サービス';
	@override String get stationConfigurationSection => 'ステーション構成';
	@override String get moreSettings => 'その他のステーション構成設定';
	@override late final _Translations$settings$radio$units$ja units = _Translations$settings$radio$units$ja._(_root);
	@override late final _Translations$settings$radio$pttKey$ja pttKey = _Translations$settings$radio$pttKey$ja._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$ja smartVfoSnap = _Translations$settings$radio$smartVfoSnap$ja._(_root);
	@override late final _Translations$settings$radio$snapDebounce$ja snapDebounce = _Translations$settings$radio$snapDebounce$ja._(_root);
	@override late final _Translations$settings$radio$snapLongMove$ja snapLongMove = _Translations$settings$radio$snapLongMove$ja._(_root);
	@override late final _Translations$settings$radio$snapMinMove$ja snapMinMove = _Translations$settings$radio$snapMinMove$ja._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$ja snapMinSpeed = _Translations$settings$radio$snapMinSpeed$ja._(_root);
	@override late final _Translations$settings$radio$enterSends$ja enterSends = _Translations$settings$radio$enterSends$ja._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$ja keyerSpeed = _Translations$settings$radio$keyerSpeed$ja._(_root);
	@override late final _Translations$settings$radio$cwMessages$ja cwMessages = _Translations$settings$radio$cwMessages$ja._(_root);
	@override late final _Translations$settings$radio$keyerControl$ja keyerControl = _Translations$settings$radio$keyerControl$ja._(_root);
	@override late final _Translations$settings$radio$voiceMessages$ja voiceMessages = _Translations$settings$radio$voiceMessages$ja._(_root);
	@override late final _Translations$settings$radio$voiceWords$ja voiceWords = _Translations$settings$radio$voiceWords$ja._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$ja avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$ja._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$ja zeroBeatRange = _Translations$settings$radio$zeroBeatRange$ja._(_root);
}

// Path: settings.help
class _Translations$settings$help$ja extends Translations$settings$help$en {
	_Translations$settings$help$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ヘルプとリソース';
	@override String get description => 'コミュニティとサポート';
	@override String get forums => 'Ham2K フォーラム';
	@override String get forumsDescription => 'ヘルプを探す、フィードバックを送る、アイデアを語り合う…';
	@override String get chat => 'Ham2K チャット';
	@override String get chatDescription => 'オンラインコミュニティのDiscordサーバー';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'ビデオとライブストリーム';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => '写真は多すぎて困ることはないので…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => '新着・更新情報についてフォローする';
	@override String get contact => 'お問い合わせ';
	@override String get contactDescription => 'help@ham2k.com（まずはフォーラムやチャットをお試しください！）';
}

// Path: settings.exports
class _Translations$settings$exports$ja extends Translations$settings$exports$en {
	_Translations$settings$exports$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'エクスポート';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$ja extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get activities => 'アクティビティ';
	@override String get hunting => 'ハンティング';
	@override String get contests => 'コンテスト';
	@override String get lookups => '検索';
	@override String get dashboard => 'ダッシュボード';
}

// Path: settings.map
class _Translations$settings$map$ja extends Translations$settings$map$en {
	_Translations$settings$map$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '地図';
	@override late final _Translations$settings$map$style$ja style = _Translations$settings$map$style$ja._(_root);
	@override late final _Translations$settings$map$showCallsigns$ja showCallsigns = _Translations$settings$map$showCallsigns$ja._(_root);
	@override late final _Translations$settings$map$showGrayline$ja showGrayline = _Translations$settings$map$showGrayline$ja._(_root);
	@override late final _Translations$settings$map$styleOpts$ja styleOpts = _Translations$settings$map$styleOpts$ja._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$ja extends Translations$settings$privacy$en {
	_Translations$settings$privacy$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'プライバシー';
	@override late final _Translations$settings$privacy$shareAppData$ja shareAppData = _Translations$settings$privacy$shareAppData$ja._(_root);
	@override late final _Translations$settings$privacy$shareOpData$ja shareOpData = _Translations$settings$privacy$shareOpData$ja._(_root);
	@override String get privacyPolicy => 'プライバシーポリシー';
	@override String get termsOfService => '利用規約';
}

// Path: settings.sync
class _Translations$settings$sync$ja extends Translations$settings$sync$en {
	_Translations$settings$sync$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'クラウド同期';
	@override String get moreSettings => 'その他の同期設定';
	@override String get enable => '同期を有効化';
	@override String get deviceKey => 'デバイスキー';
}

// Path: settings.peers
class _Translations$settings$peers$ja extends Translations$settings$peers$en {
	_Translations$settings$peers$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ピアデバイス';
	@override String get enable => '他のデバイスに接続';
	@override String get enableDescription => 'ローカルネットワーク経由で、他のデバイスとオペレーション、ロギング、CAT、GPSを共有できるようにします';
	@override String get bleEnable => 'Bluetoothで接続';
	@override String get bleDescription => 'ローカルネットワークがなくてもBluetooth LEで接続します';
	@override String get thisDevice => 'このデバイス';
	@override String get deviceName => '名前';
	@override String get deviceNameHint => '他のデバイスからこのデバイスがどう見えるか';
	@override String get pairedDevices => 'リンク済みデバイス';
	@override String get noPairedDevices => 'リンク済みのデバイスはまだありません。リンクするには、同じネットワーク上の別のデバイスでこれをオンにしてください。';
	@override String deviceListProblem({required Object error}) => 'リンク済みデバイスを読み取れません：${error}';
	@override String get nearby => '近くのデバイス';
	@override String get connected => '接続済み';
	@override String get viaBluetooth => 'Bluetooth経由';
	@override String get connecting => '接続中…';
	@override String get syncing => '同期中…';
	@override String get waitingForThem => '相手のデバイスを待っています';
	@override String get notConnected => '未接続';
	@override String get wantsToPair => 'がこのオペレーションの共有を求めています';
	@override String get allow => '許可';
	@override String get link => 'リンク';
	@override String get reject => '拒否';
	@override String get forget => '登録解除';
	@override String forgetTitle({required Object name}) => '${name}の登録を解除しますか？';
	@override String get forgetBody => 'このデバイスとの同期を停止します。後で再び許可でき、記録済みのコンタクトは保持されます。';
	@override String pairTitle({required Object name}) => '${name}とリンク';
	@override String get pairBody => 'このデバイスはローカルネットワーク上にあり、接続を求めています。';
	@override String get pairBodyBle => 'このデバイスは近くにあり、Bluetooth LEでの接続を求めています。';
	@override String get pairIdLabel => 'デバイスID';
	@override String get pairWarning => '見覚えのあるデバイスとのみリンクしてください。このネットワーク上のどのデバイスもリクエストを送信できます。';
	@override String get pairWarningBle => '見覚えのあるデバイスとのみリンクしてください。近くのどのデバイスもリクエストを送信できます。';
	@override String problem({required Object error}) => 'ローカルネットワークに接続できません：${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth：${error}';
	@override String statusConnected({required Object device}) => '${device}に接続しました';
	@override String statusLost({required Object device}) => '${device}との接続が切れました';
	@override String statusPerma({required Object linked, required Object connected}) => 'ピアデバイス：${linked}台中${connected}台が接続中';
	@override String get screenEnable => '画面とウィンドウを共有';
	@override String get screenDescription => '他のデバイスがこのコンピューターの画面やウィンドウを表示できるようにします';
	@override String get screenSources => '画面とウィンドウ';
	@override String get screenRefresh => 'リストを更新';
	@override String get screenUnsupportedPlatform => 'このデバイスは画面を共有できません。macOSでは共有でき、どのデバイスでも他のデバイスが共有した画面を表示できます。';
	@override String get screenUnsupportedVersion => '画面の共有にはmacOS 12.3以降が必要です。このデバイスでも他のデバイスが共有した画面は表示できます。';
	@override String get screenNeedsPermission => 'このアプリが画面を共有するには、macOSで画面収録の許可が必要です。';
	@override String get screenGrantPermission => '許可をリクエスト';
	@override String get screenRelaunchAfterGranting => 'システム設定の「プライバシーとセキュリティ」→「画面収録」で許可してから、このアプリを終了して開き直してください。macOSは次回起動時にのみ変更をアプリに伝えます。';
	@override String screenProblem({required Object error}) => '画面共有：${error}';
	@override String get screenChooseTitle => '共有するものを選択';
	@override String get screenChooseButton => '共有するものを選択…';
	@override String get screenTabScreens => '画面';
	@override String get screenTabApps => 'アプリ';
	@override String get screenTabWindows => 'ウィンドウ';
	@override String get screenTabEmpty => 'この種類のものは見つかりませんでした。';
	@override String get screenSharedSummaryNone => 'まだ何も選択されていません。';
	@override String get screenThisDevice => 'このデバイス';
	@override String screenSharedTo({required Object devices}) => '${devices}に表示中';
	@override String get screenSharedToNobody => '表示されていません';
	@override String screenStopSharing({required Object name}) => '${name}の共有を停止';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$ja extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get configuration => '同期の構成';
	@override String get enableTitle => 'Ham2K Log Filerと同期';
	@override String get enabledDescription => 'ログをバックアップし、デバイス間で同期しています';
	@override String get disabledDescription => 'オフ：このデバイスのみに保存';
	@override String get syncing => '同期中';
	@override String get account => 'アカウント';
	@override String get refresh => '更新';
	@override String get switchAccounts => 'アカウントを切り替え';
	@override String get switchAccountsDescription => 'QRコードまたはメールで、このデバイスを別のアカウントにリンク';
	@override String get connectionRequests => '接続リクエスト';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '1台のデバイスがこのアカウントへの参加を待っています',
		other: '${n}台のデバイスがこのアカウントへの参加を待っています',
	);
	@override String get accountEmailTitle => 'アカウントのメール';
	@override String accountEmailSent({required Object email}) => '${email}に確認メールを送信しました。メール内のリンクを開いて変更を完了してください。';
	@override String get resendConfirmation => '確認メールを再送信';
	@override String resendConfirmationDescription({required Object email}) => '${email}の確認待ち';
	@override String accountEmailResent({required Object email}) => '${email}に再送信しました。';
	@override String get deviceLinked => 'そのデバイスはこのアカウントにリンクされました。';
	@override String get checking => '確認中…';
	@override String get notLinked => 'まだリンクされていません';
	@override String linkedAccount({required Object account, required Object id}) => '${account}（#${id}）';
	@override String get replaceDialogTitle => 'ローカルデータを置き換えますか？';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${n}件のオペレーション',
		other: '${n}件のオペレーション',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${n}件のQSO',
		other: '${n}件のQSO',
	);
	@override String get counts => '同期データ';
	@override String countsLocal({required Object qsos, required Object operations}) => 'このデバイス：${qsos}・${operations}';
	@override String countsPending({required Object items}) => 'アップロード待ち：${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'サーバー：${qsos}・${operations}';
	@override String get countsLocalChecking => 'このデバイス：確認中…';
	@override String get countsServerChecking => 'サーバー：確認中…';
	@override String get countsServerUnavailable => 'サーバー：利用不可';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'このデバイスの${operations}と${qsos}をバックアップしてから消去し、代わりにアカウントのデータをダウンロードします。バックアップはこのデバイスのデータベースに残ります。';
	@override String get replace => '置き換え';
	@override String get pendingBannerTitle => '新しいHam2K Log Filerアカウントを検出しました';
	@override String get pendingBannerBody => 'このデバイスの既存のオペレーションとQSOを保持してアカウントに結合するか、アカウントのデータで置き換えてください（どちらの場合もバックアップはこのデバイスに残ります）。';
	@override String get combine => '結合';
	@override String get authIssueTitle => '同期で接続できません';
	@override String get authIssueText => 'Ham2K Log Filerがこのデバイスを拒否し続けています。同期設定でコールサインを確認してください。';
	@override String get openSettings => '同期設定を開く';
}

// Path: settings.accounts
class _Translations$settings$accounts$ja extends Translations$settings$accounts$en {
	_Translations$settings$accounts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'アカウント、サービス、データソース';
	@override String get none => 'アカウントを持つ有効な拡張機能はありません';
	@override String get notConfigured => '未設定';
	@override String get connected => '接続済み';
	@override String get cancelLogin => 'ログインをキャンセル';
	@override String get openInBrowser => 'ブラウザで開く';
	@override String loggedInAs({required Object identity}) => '${identity}としてログイン中';
	@override String get pressSaveToKeep => 'このアカウントの接続を維持するには保存を押してください。';
	@override String connectedTo({required Object label}) => '${label}に接続済み';
	@override String get connect => '接続';
	@override String get disconnect => '切断';
	@override String get connectedAs => '接続中のアカウント';
	@override String get test => 'テスト';
	@override String saveFailed({required Object error}) => '保存に失敗しました：${error}';
	@override String loginFailed({required Object error}) => 'ログインに失敗しました：${error}';
	@override String get lookupFailed => '現在アカウントを利用できません。しばらくしてから再試行してください';
	@override String get browserLoginTitle => 'Webブラウザでログインを完了してください';
	@override String browserLoginSteps({required Object prefix}) => '完了すると、ブラウザは「${prefix}」で始まるリンクを開こうとします。デスクトップにはそれを開くアプリが登録されていない可能性が高いため、そのリンク（アドレスバー、またはブラウザが表示するエラーページから）をコピーしてここに貼り付けてください。';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Loggerはブラウザを開けませんでした。下のログインリンクをコピーして自分で開き、その後移動先のリンク（「${prefix}」で始まる）をコピーしてここに貼り付けてください。';
	@override String get copyLoginLink => 'ログインリンクをコピー';
	@override String get pastedLinkLabel => 'ここにリンクを貼り付け';
	@override String get finishLogin => 'ログインを完了';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'これはログインリンクではありません。「${prefix}」で始まる必要があります。';
	@override String get pastedLinkWrongLogin => 'そのリンクは別のログイン試行のものです。このページを閉じて、もう一度接続してください。';
	@override String get pastedLinkNoCode => 'そのリンクにはログインコードがありません。まずログインを完了してから、移動先のリンクをコピーしてください。';
	@override String get pastedLinkMalformed => 'そのリンクは途中で切れているようです。全体をコピーして、もう一度貼り付けてください。';
	@override String get relayLoginWaiting => 'ログインの完了を待っています。完了すると自動的に続行します。';
	@override String get loginNoResponse => 'このデバイスはまだログインの結果を受け取っていません。ブラウザですでに完了した場合は、キャンセルしてもう一度接続してください。';
	@override String get relayLoginNotOpened => 'Ham2K Loggerはブラウザを自動的に開けませんでした。下のボタンでログインページを自分で開いてください。';
	@override String get relayLoginUnavailable => 'このログインの完了に必要な同期サーバーに接続できませんでした。接続を確認して再試行してください。';
	@override String get loginIncompleteResponse => 'そのログイン試行は正しく完了しませんでした。もう一度接続してください。';
	@override String get noKeyringTitle => 'アカウントのログイン情報を保存できません';
	@override String get noKeyringText => 'Ham2K Loggerはこのコンピューターのキーリングサービスに接続できないため、アカウントのログイン情報を保存も読み取りもできません。これが解決するまで、アカウントの接続は失敗します。**gnome-keyring**、**KWallet**、または**KeePassXC**をインストールして起動するか、既存のキーリングのロックを解除してから再起動してください。ロギング、エクスポート、データファイルには影響しません。この状態の間、ログの同期はオフのままです。';
	@override String get noKeyringInline => 'ログイン情報を保存できません：このコンピューターのキーリングに接続できません。gnome-keyring、KWallet、KeePassXCのいずれかをインストールして起動するか、既存のキーリングのロックを解除してください。';
	@override String get noSecureStorageInline => 'ログイン情報を保存できません：このコンピューターのセキュアストレージに接続できません。';
}

// Path: settings.station
class _Translations$settings$station$ja extends Translations$settings$station$en {
	_Translations$settings$station$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ステーション構成とCAT制御';
	@override String get none => '機器が設定されていません';
	@override String get add => '追加';
	@override String get addTitle => '機器を追加';
	@override String get searchHint => '機器を検索';
	@override String get noMatches => '一致する機器はありません';
	@override String get detectedEquipment => '検出された機器';
	@override String discoveryUnavailable({required Object error}) => '無線機を探索できません：${error}';
	@override String get edit => '機器を編集';
	@override String get name => '名前';
	@override String get nameDescription => '呼び名（例：「左の無線機」）。任意。';
	@override String get transport => '接続';
	@override String get host => 'アドレス';
	@override String get hostDescription => 'ネットワーク上の無線機のホスト名またはIPアドレス。';
	@override String get port => 'ポート';
	@override String get hostRequired => 'アドレスは必須です';
	@override String get portInvalid => 'ポートは1から65535の範囲で指定してください';
	@override String get connect => '接続';
	@override String get disconnect => '切断';
	@override String get remove => '削除';
	@override String removeTitle({required Object name}) => '${name}を削除しますか？';
	@override String get removeMessage => 'アプリから削除するだけです。機器の設定はそのまま残ります。';
	@override String unknownType({required Object typeKey}) => '認識できない機器の種類「${typeKey}」';
	@override String get report => '報告';
	@override String get reportTitle => 'この無線機について報告';
	@override String get reportIntro => 'この無線機の実際の機種と、動作状況を教えてください。報告はHam2Kチームが読むカードになり、動作させるまでの記述は同じリグを使う次のオペレーターの役に立つかもしれません。';
	@override String get reportManufacturer => 'メーカー';
	@override String get reportManufacturerDescription => '製造元（Icom、Yaesu、Kenwood、Elecraft…）';
	@override String get reportManufacturerRequired => 'メーカーは必須です';
	@override String get reportModel => '機種';
	@override String get reportModelDescription => '無線機自体が表示する機種名（「IC-7300」、「FT-991A」）。';
	@override String get reportModelRequired => '機種は必須です';
	@override String get reportOutcome => '結果はどうでしたか？';
	@override String get reportOutcomeWorks => '問題なく動作';
	@override String get reportOutcomeIssues => '動作したが問題あり';
	@override String get reportOutcomeFails => 'まったく動作しない';
	@override String get reportOutcomeRequired => '結果を教えてください';
	@override String get reportComments => 'コメント';
	@override String get reportCommentsPlaceholder => '動作したこと、しなかったこと、意外だったこと。';
	@override String get reportHints => 'トラブルシューティングのヒント';
	@override String get reportHintsPlaceholder => '他のユーザー向けのトラブルシューティングのヒントがあれば教えてください。';
	@override String get reportSend => '報告を送信';
	@override String get reportSending => '報告を送信中…';
	@override String reportSent({required Object ref}) => 'ありがとうございます。報告は${ref}として登録されました。';
	@override String get reportSentNoRef => 'ありがとうございます。報告を送信しました。';
	@override String reportFailed({required Object error}) => '報告は送信されませんでした：${error}';
	@override String get troubleshootingNotes => 'トラブルシューティングの注意事項';
	@override String get mainVfo => 'メインVFO';
	@override String get useAsMainVfo => 'メインVFOとして使用';
	@override String get serialPort => 'シリアルポート';
	@override String get serialPortDescription => '無線機のCATインターフェースが現れるポート。';
	@override String get serialPortNone => 'シリアルポートが見つかりません';
	@override String get serialPortRequired => 'シリアルポートを選択してください';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'ポート ${n} / ${total}';
	@override String get serialPortSuggested => '推奨';
	@override String get serialPortJustNow => '最近接続';
	@override String get serialPortNoDriver => 'ドライバーなし';
	@override String get serialDeviceRequest => 'USBデバイスを追加…';
	@override String get bleDevice => 'Bluetooth LEデバイス';
	@override String get bleDeviceDescription => '無線機を接続しているシリアルブリッジ。Mode 4のLiNK500MPやBLEシリアルアダプターなど。';
	@override String get bleScan => 'Bluetooth LEデバイスをスキャン…';
	@override String get bleScanNoneFound => 'Bluetooth LEデバイスが見つかりません。ブリッジの電源が入っていて、近くにあり、Bluetooth LEモード（LiNK500MPではMode 4）になっているか確認してください。';
	@override String bleScanFailed({required Object reason}) => 'Bluetooth LEのスキャンを実行できませんでした：${reason}';
	@override String get bleOff => 'Bluetoothがオフになっています。';
	@override String get bleDenied => 'Bluetoothの許可が得られていません。システム設定で許可してから、もう一度お試しください。';
	@override String get bleUnsupported => 'このデバイスにはBluetooth LEがありません。';
	@override String get bleStarting => 'Bluetoothはまだ起動中です。しばらくしてからお試しください。';
	@override String get bleConnectFailed => 'Bluetooth LEデバイスに接続できません。電源が入っていて、近くにあり、他のアプリに接続されていないか確認してください。';
	@override String bleNoSerialService({required Object services}) => 'このBluetooth LEデバイスには、アプリが認識できるシリアルサービスがありません。サービス情報を添えて報告してください：${services}';
	@override String get baudRate => '速度（ボー）';
	@override String get baudRateDescription => '無線機のCATメニューと一致させてください。一致しないと、無線機は無意味なデータを返し、エラーは出ません。';
	@override String get serialRtsHigh => 'RTSをHIGHに保持';
	@override String get serialRtsHighDescription => 'CAT RTSをオンにしたYaesuなど、応答前にRTSを待つ無線機専用です。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTであり、HIGHに保持すると送信します。';
	@override String get serialDtrHigh => 'DTRをHIGHに保持';
	@override String get serialDtrHighDescription => 'FT-817用の一部のRS-232ケーブルなど、DTRから電源を取るCATインターフェース専用です。多くのケーブルではDTRがCWキーイングまたはPTTであり、HIGHに保持すると送信します。';
	@override String get serialUsbDriver => 'USBチップのドライバー';
	@override String get serialUsbDriverDescription => '自動ではほとんどのアダプターを認識します。ポート一覧で「ドライバーなし」と表示されるものについてのみチップを選んでください。チップ名はパッケージやUSBデバイス一覧に記載されています。';
	@override String get serialUsbDriverAuto => '自動';
	@override String get civAddress => '無線機のCI-Vアドレス';
	@override String get civAddressDescription => '無線機のCI-Vメニューに表示される16進数。IC-705の出荷時設定はA4です。';
	@override String get civAddressInvalid => 'CI-Vアドレスは01からFFまでの2桁の16進数です';
	@override String get flexSlice => 'スライス';
	@override String get flexSliceDescription => 'この接続が読み取り、チューニングする無線機のスライス。';
	@override String flexSliceLabel({required Object letter}) => 'スライス${letter}';
	@override String get flexSliceInvalid => '無線機のスライスをAからHの中から選んでください';
	@override String flexSliceMissing({required Object letter}) => 'スライス${letter}はこの無線機で使用されていません。別のスライスを選ぶか、SmartSDRで作成してください';
	@override String get channelNotInUse => '未使用';
	@override String get channelHeldByUnknown => '別のプログラムが使用中';
	@override String get flexNoSlices => 'この無線機はスライスを報告していません。SmartSDRが動作していて、このクライアントがサブスクライブできることを確認してください';
	@override String get spectrumUnsupported => 'この無線機はCATでスペクトラムを送信しません';
	@override String get spectrumRequiresBaud => '115200 bpsのCATが必要です';
	@override String get spectrumNoRadio => '無線機が接続されていません';
	@override String get spectrumWaiting => '無線機のスペクトラムを待っています…';
	@override String get spectrumUnavailable => 'スペクトラム表示は利用できません';
	@override String get spectrumNoDaxChannel => 'この無線機のDAX IQチャンネルはすべて使用中です';
	@override String get spectrumNoPanadapter => 'このスライスには無線機上のパンアダプターがありません';
	@override String spectrumStreamRefused({required Object code}) => '無線機がDAX IQストリームを拒否しました（エラー ${code}）';
	@override String get spectrumNoUdp => '無線機のスペクトラムデータがこのデバイスに届きません';
	@override String get spectrumK4Unavailable => 'K4のLANスペクトラムを受信できません。再試行中…';
	@override String get spectrumK4RemoteUnavailable => 'K4のリモートスペクトラムを受信できません';
	@override String get spectrumScopeRefused => '無線機がスコープのコマンドを拒否しました';
	@override String get spectrumOutOfRange => '無線機のスコープが表示可能な範囲外に設定されています';
	@override String get spectrumBandUnsupported => 'このバンドでは無線機のスコープを表示できません';
	@override String get spectrumSdrNoRadio => 'リンクした無線機の周波数を待っています…';
	@override String get spectrumSdrNotConnected => 'SDRが接続されていません';
	@override String get spectrumSdrNoIf => 'このSDRの設定で無線機のIF周波数を設定してください';
	@override String get sdrRadio => 'スペクトラムの表示対象';
	@override String get sdrRadioDescription => 'この無線機のスペクトラム表示は、無線機自身のスコープの代わりにこの受信機から描画されます。';
	@override String get sdrRadioMain => 'メインの無線機';
	@override String get sdrTuning => 'アンテナ入力';
	@override String get sdrTuningDescription => '受信機の信号の入力元。独自のアンテナなら無線機に追従して自ら同調し、無線機のIF出力ならIFに留まります。';
	@override String get sdrTuningIndependent => '独自のアンテナ';
	@override String get sdrTuningIfTap => '無線機のIF出力';
	@override String get sdrIfHz => 'IF周波数（Hz）';
	@override String get sdrIfHzDescription => 'IF出力の場合のみ：無線機のダイヤル周波数がIF上で位置する周波数。FT-817なら68330000など。';
	@override String get sdrIfInverted => 'IFが反転している';
	@override String get sdrGainDb => 'ゲイン（dB）';
	@override String get sdrGainDbDescription => '空欄なら受信機の自動ゲインを使います。';
	@override String get sdrOffsetHz => '周波数オフセット（Hz）';
	@override String get sdrOffsetHzDescription => 'アップコンバーター用に、受信機へ送るすべての周波数に加算されます：Ham It Upなら125000000。';
	@override String get sdrPpm => '周波数補正（ppm）';
	@override String get rtlDirectSampling => 'ダイレクトサンプリング';
	@override String get rtlDirectSamplingDescription => 'アップコンバーターなしのRTL-SDR V3でHFを受信する場合用。RTL-SDR V4はこれなしでHFに対応します。';
	@override String get rtlDirectSamplingOff => 'オフ';
	@override String get rtlDirectSamplingI => 'Iブランチ';
	@override String get rtlDirectSamplingQ => 'Qブランチ';
	@override String get rtlTcpNotAServer => 'これはrtl_tcpサーバーではありません';
	@override String get rtlTcpNotes => 'ドングルを接続したコンピューター上で**自分で起動したrtl_tcpサーバー**に接続します。\n\n- **起動**は、他のマシンから接続できるよう `rtl_tcp -a 0.0.0.0` で行います。同じマシン上なら `rtl_tcp` だけで十分です。\n- **ポート**は、`-p` を指定して起動していなければ1234です。\n- **同時に使えるのは1つのプログラムだけ：** rtl_tcpは1つのクライアントにしか対応しません。アプリはスペクトラム表示を出している間だけ接続し、閉じてから数秒後に切断します。\n- **Androidでは**、*SDR driver* アプリがスマートフォン上で同じサーバーを実行します。';
	@override String get rspTcpNotes => 'RSPを接続したコンピューター上で、SDRplayのAPIをインストールして**自分で起動したrsp_tcpサーバー**に接続します。\n\n- **起動**は `rsp_tcp -a 0.0.0.0` で行います。\n- **ポート**は、`-p` を指定して起動していなければ1234です。\n- **同時に使えるのは1つのプログラムだけ：** サーバーは1つのクライアントしか受け付けません。アプリはスペクトラム表示を出している間だけ接続します。';
	@override String get n3fjpNoRig => 'N3FJPに無線機インターフェースが設定されていないため、無線機ではなくN3FJPに入力された内容に従います';
	@override String get winkeyerKeyPort => 'キー出力';
	@override String get winkeyerKeyPortDescription => 'キーヤーの2つの出力ジャックのうち、無線機を接続している方。';
	@override String winkeyerKeyPortLabel({required Object n}) => 'ポート${n}';
	@override String get winkeyerPtt => 'キーヤーのPTTを使用';
	@override String get winkeyerPttDescription => 'アンプや、PTTが必要な無線機のために、同じジャックのPTTラインをキーイングします。キージャックでキーイングする無線機ではオフのままにしてください。';
	@override String get winkeyerNoAnswer => 'このポートでWinKeyerが応答しませんでした';
	@override String get winkeyerStoppedAnswering => '送信中にWinKeyerが応答しなくなったため、メッセージは破棄されました';
	@override String get icomControlPort => 'コントロールポート（UDP）';
	@override String get icomControlPortDescription => '無線機のControl Port（UDP）。ネットワーク設定で変更するか、別のポートに転送していなければ50001です。';
	@override String get icomSerialPort => 'シリアルポート（UDP）';
	@override String get icomSerialPortDescription => '無線機のSerial Port（UDP）。ネットワーク設定で変更するか、別のポートに転送していなければ50002です。';
	@override String get icomPortsDiffer => 'コントロールポートとシリアルポートは異なる値にしてください';
	@override String get radioUser => '無線機のユーザー名';
	@override String get radioPass => '無線機のパスワード';
	@override String get radioLoginDescription => 'WiFiのパスワードではなく、無線機の Network → Remote のログイン情報です。';
	@override String get radioUserRequired => '無線機のリモート制御用ユーザー名は必須です';
	@override String get connectFailedBusy => 'デバイスは使用中です';
	@override String get connectFailedDenied => 'アクセスが拒否されました';
	@override String get connectFailedDevice => 'デバイスが見つかりません';
	@override String get connectFailedUnsupported => 'このUSBアダプターのチップを認識できるドライバーがありません。チップが分かる場合は、詳細設定の「USBチップのドライバー」で選んでください。';
	@override String get connectFailedLines => 'RTS/DTRを設定どおりに保持できなかったため、ポートを閉じました。別のプログラムがハードウェアハンドシェイクをオンのままにした可能性があります。ケーブルを抜き差ししてください。';
	@override String get connectFailedNetwork => 'ネットワーク上で無線機が見つかりません。アドレスと、電源が入っていて接続可能かを確認してください。';
	@override String connectFailedReplyPort({required Object port}) => 'このデバイスのポート${port}はすでに使用中ですが、応答はそこに届きます。そのポートで待ち受けている他のもの（別のPstRotatorノードを含む）を閉じるか、ポートを変更してください。';
	@override String get connectFailedTimeout => '無線機が時間内に応答しませんでした。電源が入っていて接続可能かを確認してください。';
	@override late final _Translations$settings$station$models$ja models = _Translations$settings$station$models$ja._(_root);
	@override late final _Translations$settings$station$transports$ja transports = _Translations$settings$station$transports$ja._(_root);
	@override String get troubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get ft891Troubleshooting => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機側でCAT RTSをOFFにするか、RTSをHIGHに保持をオンにしてください。** **CAT RTS** がオン（FT-891メニュー **05-08**）だと、無線機はRTSがLOWの間は沈黙します。ポートを開いた直後に一度だけ応答し、その後は何も返さないことがあります。無線機本体のUSBポートを選ぶと、詳細設定の **RTSをHIGHに保持** が自動的にオンになります。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTなので、HIGHに保持すると送信してしまいます。その場合は代わりに無線機側でCAT RTSをOFFにしてください。\n- **速度を一致させてください**：無線機のCAT RATE（メニュー **05-06**）と同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。';
	@override String get yaesuBinaryTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get yaesuBinaryTroubleshooting => 'この無線機はYaesuの旧式の5バイトCATを使用し、何か問題があるとまったく応答しません。ほとんどの場合、次のいずれかが原因です：\n\n- **ケーブルでレベル変換が必要です。** 背面のCATジャックはRS-232でもUSBでもなく、CT-62または同等のアダプターが必要です。普通のオーディオケーブルやデータケーブルではCATは動作しません。\n- **速度を一致させてください**：無線機のCAT RATEメニュー（FT-817では **#14**、FT-857やFT-897では **#19**）と同じにします。一致しないと、無線機は何も返さず、エラーも出ません。\n- **このポートでRTSやDTRを決してHIGHにしないでください。** これらの無線機用のほとんどのケーブルでは、それらのラインがPTTとキーイングです。DTRから電源を取る古いインターフェースは例外で、その場合は詳細設定の **DTRをHIGHに保持** をオンにしてください。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのドライバーはYaesuが公開しているCAT仕様表をもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get tenTecTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get tenTecEagleTroubleshooting => '- **背面のUSB-BポートがCATリンクです。** 無線機はUSBシリアルポートとして表示されます。WindowsではTen-TecのUSB to UARTドライバーが必要で、デバイスマネージャーには「USB to UART (COMx)」として表示されます。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにし、Ten-Tecのファームウェアアップデーターも同様です。\n- **アプリからフィルター幅を設定すると、無線機の電源を入れ直すまでBWツマミが効かなくなります。** これは無線機の仕様です。\n\nこのドライバーはTen-Tecのプログラマーズリファレンスガイドをもとに作成されています。一部しか動作しない場合は、無線機のメニューに表示されるファームウェアバージョンを添えてぜひ報告してください。';
	@override String get tenTecOrionTroubleshooting => '- **SERIAL DATAポートにはストレートのDB-9シリアルケーブルを使ってください。** ヌルモデムケーブルは使えません。\n- **このエントリーはRTSをHIGHに保持します。** OrionはRTSとCTSをハンドシェイクに使うためです。DigirigなどRTSでPTTをキーイングするインターフェースでは、詳細設定の「RTSをHIGHに保持」をオフにしてください。そうしないと、アプリが接続した瞬間に無線機が送信します。\n- **アプリからのCWには、無線機の内蔵キーヤーをオンにする必要があります。** オフだと、無線機はアプリからの送信を無視します。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのドライバーはTen-Tecのプログラマーズリファレンスガイドをもとに作成されており、Orionの実機ではテストされていません。一部しか動作しない場合は、無線機のメニューに表示されるファームウェアバージョンを添えてぜひ報告してください。';
	@override String get tenTecNoCw => 'この無線機のファームウェアはアプリからのCWを受け付けません。Ten-TecはOrionファームウェア1.366で対応を追加しました。';
	@override String get tenTecKeyerOff => '無線機の内蔵キーヤーがオフのため、アプリから送るCWは無視されます。無線機のメニューでキーヤーをオンにしてください。';
	@override String get guohetecTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get guohetecTroubleshooting => 'Q900には2つのCATプロトコルがあり、このエントリーはFT-817の模倣ではなく独自プロトコルを使用します。ここではFT-817ではなく **Guohetec Q900** を選んでください。模倣プロトコルは対応コマンドが少なく、無線機はどちらを使っているかを示しません。\n\n- **USB-CケーブルがCATリンクです**。サウンドカードも同じケーブルで接続されます。このポートでは速度は関係なく、設定値は無視されます。\n- **このポートでRTSやDTRを決してHIGHにしないでください。** シリアルケーブルではそれらのラインがPTTとキーイングです。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **第2世代の無線機は第1世代と動作が異なります**。Menuを長押しして About を開き、HW 2.0なら第2世代です。\n\nこのドライバーはメーカーが公開しているプロトコルをもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get yaesuTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get yaesuTroubleshooting => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機側でCAT RTSをOFFにする必要があります。** オンのままだと、無線機はアプリがLOWに保つハンドシェイクラインを待ち続けます。Digirig、SignaLink、ほとんどの自作ケーブルではその同じラインがPTTなので、HIGHにすると送信してしまいます。無線機本体のUSBポートを使う場合は、詳細設定の **RTSをHIGHに保持** が代替手段です。この設定の場所は機種によって異なります（FT-891ではメニュー **05-08**）。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **モードはFT-891の対応表に従います。** Yaesuのほとんどの機種はこれと一致しますが、モードの番号付けが異なる無線機では、該当するモードが誤って表示・設定されます。周波数には影響しません。';
	@override String get ftdx3000Troubleshooting => '**無線機のUSBポートでCATを使うには、メニュー037 CAT SELECTをUSBにしてください。** RS232Cに設定すると、CATは背面のジャックになります。\n\nこのエントリーは公開されているCATドキュメントをもとに作成されており、FTDX3000の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get yaesuRs232Troubleshooting => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **CATジャックはRS-232です。** USB-シリアル変換アダプターとストレートのDB-9ケーブルが必要です。クロス（ヌルモデム）ケーブルではラインが入れ替わり、無線機には何も届きません。\n- **無線機側でCAT RTSをOFFにする必要があります。** オンのままだと、詳細設定の **RTSをHIGHに保持** がオンでない限り、無線機はアプリがLOWに保つハンドシェイクラインを待ち続けます。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのエントリーは公開されているCATドキュメントをもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get yaesuUsbTroubleshooting => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機の2つのUSBポートのうち1つ目を使用してください。** CATは通常1つ目（Windowsでは **Enhanced** COMポート）にあり、2つ目（**Standard**）はPTTとキーイング用です。ポート選択では、2つを区別できる場合は1つ目を指します。\n- **無線機側でCAT RTSをOFFにするか、RTSをHIGHに保持をオンにしてください。** 無線機の **CAT RTS** メニューがオンだと、RTSがLOWの間は沈黙します。ポートを開いた直後に一度だけ応答し、その後は何も返さないことがあります。無線機本体のUSBポートを選ぶと、詳細設定の **RTSをHIGHに保持** が自動的にオンになります。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTなので、HIGHに保持すると送信してしまいます。その場合は代わりに無線機側でCAT RTSをOFFにしてください。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。';
	@override String get k4SerialNotes => 'K4背面のUSB-B（PC）ソケットに接続してください。CATにはUSB-PC1とUSB-PC2のどちらも使えます。未使用のポートを選び、無線機のSerial USB-PCn: Baud Rate設定と一致させてください。HaLoは38400を初期値として入力します。必要に応じて変更してください。他のアプリケーションはもう一方のポートかEthernetを使う必要があります。\n\nこの接続は無線機とそのキーヤーを制御しますが、HaLoに音声は送りません。';
	@override String get k4TcpNotes => 'K4のEthernetソケットをローカルネットワークに接続してください。ホスト名またはIPアドレスと、CATポート9200を入力します。パンアダプターやウォーターフォールの表示中、HaLoは同じホストの固定ポート9201を使います。CATポートを変更してもスペクトラムのポートは変わりません。\n\nスペクトラムはメイン受信機を表示します。そのズーム、リファレンス調整、速度の操作はHaLoの表示にのみ影響します。音声ストリーミングには対応していません。';
	@override String get k4PowerTimeout => '無線機が出力範囲を確認しなかったため、K4の出力は変更されませんでした。再試行してください。';
	@override String get k4RemoteNotes => 'K4でリモートアクセスを有効にし、そのネットワークパスワードを入力してください。MainとSubは、無線機制御とスペクトラムのために1つの暗号化接続を共有します。デフォルトのポートは9204です。リモートから接続する場合は転送先のポートを入力してください。\n\n音声の再生とマイクのストリーミングには対応していません。';
	@override String get k4Receiver => '受信機';
	@override String get k4ReceiverMain => 'Main';
	@override String get k4ReceiverSub => 'Sub';
	@override String get k4ReceiverInvalid => 'MainまたはSubを選んでください';
	@override String get k4ReceiverAlreadyConfigured => 'その受信機はこのK4ですでに設定済みです';
	@override String get k4SubReceiverOff => 'K4のサブ受信機がオフです';
	@override String get k4RemotePasswordRequired => '安全に接続するにはK4のネットワークパスワードを入力してください。';
	@override String get k4RemoteHandshakeFailed => 'K4とのセキュアな接続を確立できませんでした。ネットワークパスワードとリモートアクセスの設定を確認してください。';
	@override String get k4RemoteUnreachable => 'K4のセキュア接続に到達できませんでした。アドレス、ポート、リモートアクセスの設定を確認してください。';
	@override String get k4PowerRange => 'K4の出力は0.1〜110 W、トランスバーターのミリワット出力が有効な場合は0.0001〜0.01 Wの範囲で指定してください。';
	@override String get elecraftTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get elecraftTroubleshooting => 'ElecraftのリグはKenwood CATを使用し、KX2とKX3の両方でこの方法による動作が確認されています。VFOの双方向制御、モード切替、CWのゼロビートすべてが動作します。\n\n無線機が応答しない場合、ほとんどの場合は次のいずれかが原因です：\n\n- **速度を一致させてください**：無線機のメニューの **RS232** で設定したレートと同じにします。出荷時は38400です。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\n**周波数は正しいのにモードが違う場合**は、お知らせください。KX2とKX3のエントリーは、無線機のステータス応答内の特定の位置からモードを読み取っており、その位置はこれまでに確認したリグをもとに固定しています。別の位置に置くファームウェアについては、報告がなければ私たちには分かりません。\n\nK3についてはまだどちらの報告もないため、使用している場合は結果をお知らせください。K4には専用のエントリーがあります。';
	@override String get lab599TroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get lab599Troubleshooting => 'TX-500シリーズはKenwood CATを使用します。周波数とモードはLiNK500MP経由で動作確認済みです。出力とメーターはLab599のCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n- **速度を一致させてください**：無線機のCAT設定と同じにします。変更していなければ9600です。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **無線機側でCATプロトコルを選んでください。** TS-2000は周波数、モード、出力に対応します。LAB599ではさらに、アプリから無線機をDIGに切り替え、DIGでの送信を確認し、電源電圧を読み取れます。\n- **LiNK500MP経由の場合**、VFOツマミを3秒ほど長押しして、CAT制御をインターフェースに渡してください。\n- **接続に合わせてLiNK500MPのモードを設定してください**：BluetoothならMode 3、Bluetooth LEならMode 4です。それ以外のモードではBluetooth LEスキャンで見つかりません。\n- **Bluetooth経由**では、LiNK500MPは2つのシリアルポートとしてペアリングされ、CATを扱うのは片方だけです。無線機が沈黙したままなら、もう一方を選んでください。';
	@override String get lab599TroubleshootingIos => 'TX-500シリーズはKenwood CATを使用します。周波数とモードはLiNK500MP経由で動作確認済みです。出力とメーターはLab599のCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n- **スキャンの前にLiNK500MPをMode 4にしてください**。これがBluetooth LEモードです。それ以外のモードではiPhoneやiPadから見つけられません。\n- **CAT制御をLiNK500MPに渡してください**：無線機のVFOツマミを3秒ほど長押しします。\n- **無線機側でCATプロトコルを選んでください。** TS-2000は周波数、モード、出力に対応します。LAB599ではさらに、アプリから無線機をDIGに切り替え、DIGでの送信を確認し、電源電圧を読み取れます。';
	@override String get kenwoodTroubleshootingTitle => '無線機に接続できても周波数が表示されない場合';
	@override String get kenwoodTroubleshooting => 'このドライバーは、KenwoodのTS-590SGとTS-480、QRP LabsのQMXとQCX-mini、ElecraftのKX2とKX3で動作が確認されています。その他の機種は公開されているCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n無線機が応答しない場合、ほとんどの場合は次のいずれかが原因です：\n\n- **速度を一致させてください**：無線機のCATメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **一部のリグはメニューでCATを有効にする必要があります**。有効にしないとまったく応答しません。\n- **Kenwoodの無線機はRTSを待ちます**：CATポートがRTSをハンドシェイクに使うため、詳細設定の「RTSをHIGHに保持」をオンにする必要があります。これがデフォルトでオンになる前に設定した接続では、オフのままかもしれません。DigirigなどRTSでPTTをキーイングするケーブルではオフにしてください。そうしないと無線機が送信します。\n\n**いくつかのSDRフロントエンドも同じプロトコルを使用している**ため、それらでもこのエントリーを試す価値があります。ElecraftのリグはElecraftの下に別途掲載しています。周波数は正しいのにモードが違う、または表示されない場合、それが機種ごとに異なる唯一の部分です。アプリは無線機からモードを判別し、できなければ直接問い合わせるため、モードの表示が単に遅れているだけかもしれません。';
	@override String get statusConnected => '接続済み';
	@override String get statusLost => '切断';
	@override String get notConfigured => '未設定';
	@override String get currentConfiguration => '現在の構成';
	@override String get currentTransceiver => '現在のトランシーバー';
	@override String get currentTransceivers => '現在のトランシーバー';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}：${name}';
	@override String get so2rQueueMessages => 'メッセージを割り込ませずにキューに入れる';
	@override String get noRadioBSelected => 'Radio Bが選択されていません';
	@override String get radioMode => '無線機のモード';
	@override String get keyerNotSupported => '現在の無線機では未対応';
	@override String get catControlPreferences => 'CAT制御の設定';
	@override String get chooseTransceiver => 'トランシーバーを選択';
	@override String get configurationSection => '構成';
	@override String get noTransceiverSelected => 'トランシーバーが選択されていません';
	@override String makeMainVfo({required Object name}) => 'メインVFOに${name}を使用';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		zero: 'トランシーバーなし',
		one: 'トランシーバー${count}台',
		other: 'トランシーバー${count}台',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'アンテナ${count}本',
		other: 'アンテナ${count}本',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'その他の機器${count}台',
		other: 'その他の機器${count}台',
	);
	@override String get equipmentInventory => '機器一覧';
	@override String get equipmentInUse => 'トランシーバーの操作';
	@override String get noTransceiver => 'なし';
	@override String get peerRadioNotAvailable => '利用不可';
	@override String peerRadioOnDevice({required Object device}) => '${device}上';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio}は別のデバイス上にあります';
	@override String peerRadioElsewhereMessage({required Object device}) => 'この無線機は${device}に接続されています。接続と設定はそのデバイスで構成します。';
	@override String get antennaInUse => '使用中のアンテナ';
	@override String get keyInUse => 'CWキーイング';
	@override String get phoneKeying => '電話キーイング';
	@override String get phoneKeyingNone => 'なし';
	@override String phoneKeyingRadio({required Object radio}) => '${radio}のメモリー';
	@override String get phoneKeyingComputer => 'このコンピューターの音声';
	@override String get phoneKeyingOff => '電話キーイングはオフです';
	@override String get computerVoiceSettings => 'コンピューターの音声';
	@override String get cwKeyingOptions => 'CWキーイングのオプション';
	@override String get noneSelected => 'なし';
	@override String get moreSettings => 'その他の設定';
	@override String get icomCivTroubleshootingTitle => '同じ無線機に2つのシリアルポートが表示される場合';
	@override String get icomCivTroubleshooting => 'IC-705を含む一部のIcom無線機は、**2つ**のUSBシリアルポート（IcomではPort AとPort Bと呼びます）を同時に提供し、どちらもデフォルトでCI-Vに設定されています。このアプリもOSもそれ以上は区別できず、同じUSBベンダー/プロダクトIDが2回表示されるだけです（ここでは `#2` という接尾辞が付くこともあります）。**通常はPort Aが正解です**。たいていOSやブラウザが最初に表示するもので、このアプリが2つのポートを区別できる場合は推奨として表示します。コマンドを送っても無線機が応答しない場合は、もう一方のポートを試してください。';
	@override String get civAddressTroubleshootingTitle => '無線機がまったく応答しない場合';
	@override String get civAddressTroubleshooting => '- **CI-Vアドレスを一致させてください**：無線機のメニューと同じにします。このエントリーには機種の出荷時アドレスが入力されていますが、CI-Vバスを共有するリグではまさにそれが変更されます。間違ったアドレスに送られたフレームは黙って無視されるため、ケーブルの故障とまったく同じように見えます。\n- **速度を一致させてください**：無線機のCI-V BAUD RATE（USBの場合はCI-V USB Baud Rate）と同じにします。無線機をここに表示されているのと同じ数値に設定し、**Autoにはしないでください**。Autoでは、IC-7300などの一部の無線機は接続後1分ほどで応答しなくなります。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **CI-Vアドレスを一致させてください**：無線機のメニューと同じにします。このエントリーには機種の出荷時アドレスが入力されていますが、CI-Vバスを共有するリグではまさにそれが変更されます。間違ったアドレスに送られたフレームは黙って無視されるため、ケーブルの故障とまったく同じように見えます。\n${speed}\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。';
	@override String get icomUsbSpeedFollows => '- **設定する速度はありません。** USB経由では、この無線機はコンピューターが使う速度で通信します。このエントリーは常に、スコープに必要な速度である115200を使います。';
	@override String get ic7610UsbSpeed => '- **CI-V USB Baud Rateを115200にしてください**。スコープに必要なため、このエントリーは常にこの速度を使います。**Autoにはしないでください**。他の速度に設定された無線機は何も返しません。';
	@override String get civTransceiveTitle => 'アプリが無線機の操作に追従するのが遅い場合';
	@override String get civTransceive => '無線機で変更した周波数やモードがアプリに表示されるまで数秒かかる場合は、無線機の **CI-V Transceive** 設定をオンにしてください（最近の機種ではSET > Connectors > CI-Vにあります）。オンにすると、無線機は変更があった瞬間にそれを報告します。オフだと、アプリは数秒ごとの次回の問い合わせまで変更に気づきません。';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2** の出荷時アドレスは、ここに入力されている `94` ではなく `B6` です。代わりにIC-7300 MK2のエントリーを選んでください。';
	@override String get ic705PortNote => '\n- **IC-705** は、どちらも無線機の名前が付いた2つのUSBシリアルポートを提供します。CI-Vはそのうち **1つ目** にあり、ポート選択では2つを区別できる場合はそちらを指します。';
	@override String get ic7760PortNote => '\n- **IC-7760** は、提供する2つのUSBシリアルポートのうち **Port A** でCI-Vを使用します。';
	@override String get x6100PortNote => '\n- **X6100** は **DEV** ポートでCI-Vを使用します。提供する2つのシリアルポートのうち2つ目で、ポート選択はこちらを指します。';
	@override String get rigctldTroubleshootingTitle => 'アプリが接続できない場合';
	@override String get rigctldTroubleshooting => 'これは無線機に直接ではなく、**ご自身で実行するrigctldデーモン**に接続します。Hamlibのバックエンドが無線機と通信し、数百の機種に対応しています。\n\n- **デーモンがすでに実行中である必要があります**。例：`rigctld -m 1035 -r /dev/ttyUSB0`。無線機の機種番号は `rigctl -l` で確認できます。\n- **別のマシンから接続する場合**は、`-T 0.0.0.0` を付けて起動してください。デフォルトでは、rigctldは実行中のマシンからの接続のみを受け付けます。\n- **ポート** は、デーモンを `-t` で起動していない限り4532です。\n- 接続後に周波数が表示されない場合、通常はデーモン自体が無線機に接続できていません。デーモンのマシンで `rigctl -m 2 f` を実行してテストしてください。';
	@override String get flrigTroubleshootingTitle => 'アプリが接続できない場合';
	@override String get flrigTroubleshooting => 'これは無線機に直接ではなく、**ご自身で実行するflrigプログラム**に接続します。flrigが無線機と通信し、ほとんどのメーカーと機種に対応しています。\n\n- **flrigがすでに実行中である必要があります**。トランシーバーが設定され、接続されている状態にしてください。\n- **ポート** は、flrigの設定（Config → Setup → Server）で変更していない限り12345です。\n- **別のマシンから接続する場合**は、flrigのサーバーに接続できることを確認してください。flrigはすべてのインターフェースで待ち受けますが、ファイアウォールが許可しない場合があります。\n- 接続後に周波数が表示されない場合、通常はflrig自体が無線機に接続できていません。flrigの表示がダイヤルに追従しているか確認してください。';
	@override String get hrdTroubleshootingTitle => 'アプリが接続できない場合';
	@override String get hrdTroubleshooting => 'これは無線機に直接ではなく、**コンピューター上で実行中のHam Radio DeluxeのRig Control**に接続します。HRDが無線機と通信します。\n\n- **Rig Controlがすでに実行中で**、無線機に接続されている必要があります。\n- **IPサーバーを有効にする必要があります。** Rig Controlは他のプログラムとはそれを通じてのみ通信します。\n- **ポート** は、IPサーバーの設定で変更していない限り7809です。\n- **別のマシンから接続する場合**は、ファイアウォールが接続を許可していることを確認してください。\n\nこのエントリーは公開されているHRDのプロトコル説明をもとに作成されており、HRDの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get n3fjpTroubleshootingTitle => 'アプリが接続できない場合';
	@override String get n3fjpTroubleshooting => 'これは無線機に直接ではなく、**コンピューター上で実行中のN3FJPロギングプログラム**に接続します。N3FJPが無線機と通信します。\n\n- **プログラムのAPIをオンにする必要があります**：Settings → Application Program Interface で **TCP API Enabled** にチェックします。\n- **ポート** は、そこで変更していない限り1100です。\n- 無線機に追従またはチューニングするには、**N3FJPに無線機インターフェースが設定されている必要があります**。設定がない場合、入力ウィンドウに入力された内容のみを報告します。\n- N3FJPが報告するのはバンド、モード、周波数のみで、出力や送信状態は報告しません。\n\nこのエントリーは公開されているN3FJPのAPIをもとに作成されており、N3FJPの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get commanderTroubleshootingTitle => 'アプリが接続できない場合';
	@override String get commanderTroubleshooting => 'これは無線機に直接ではなく、**コンピューター上で実行中のDXLab Commander**に接続します。Commanderが無線機と通信します。\n\n- **Commanderがすでに実行中で**、無線機に接続されている必要があります。\n- **ネットワークサービスをオンにする必要があります**：CommanderのConfigurationウィンドウのRadioパネルにある **Net Serv** ボタンです。\n- **ポート** は52002で、Net Servの **Base Port**（変更していなければ52000）から始まるブロックの3番目のポートです。\n- **別のマシンから接続する場合**は、ファイアウォールが接続を許可していることを確認してください。\n\nこのエントリーは公開されているCommanderのTCPメッセージをもとに作成されており、Commanderの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。';
	@override String get ic705TroubleshootingTitle => '無線機がまったく応答しない場合';
	@override String get ic705Troubleshooting => 'この無線機のリモート制御セッションは **1つだけ** です。ログインが無視される場合、ほぼ確実に他の何かがそれを使用しています。\n\n- **他のクライアントを閉じてください。** 同じ無線機に接続したwfviewやRS-BA1がそのセッションを保持していると、ここでのログインは単に無視されます。\n- **無線機のネットワーク設定を確認してください。** WLANがオンで、無線機が同じネットワーク上にあり、リモート制御（Network）機能が有効になっている必要があります。\n- **ポートを一致させてください**：無線機のControl PortとSerial Port（UDP）、またはそこへ転送されているポートと同じにします。ポートが間違っていると、電源の切れた無線機と同じく無応答になります。\n- 固まったままの場合は、**無線機のWLANをオフにしてからオンにしてください**。無線機上で固まったセッションを確実に解除できます。\n\n**パスワードが間違っている場合は明示的に拒否され**、無応答にはなりません。「拒否」のメッセージではなくこの画面に来た場合、パスワードは問題ではありません。';
	@override String get icomLanTroubleshooting => 'この無線機のリモート制御セッションは **1つだけ** です。ログインが無視される場合、ほぼ確実に他の何かがそれを使用しています。\n\n- **他のクライアントを閉じてください。** 同じ無線機に接続したwfview、RS-BA1、IcomのRemote Utilityがそのセッションを保持していると、ここでのログインは単に無視されます。\n- **無線機のネットワーク設定を確認してください。** LANポートがこのデバイスと同じネットワークに接続され、**Network Control** がオンで、ユーザー名とパスワードが無線機上のネットワークユーザーとして設定されている必要があります。\n- **ポートを一致させてください**：無線機のControl PortとSerial Port（UDP）、またはそこへ転送されているポートと同じにします。ポートが間違っていると、電源の切れた無線機と同じく無応答になります。\n- **接続しても応答がない場合**は、ここのCI-Vアドレスを無線機のCI-V ADDRESSメニューと一致させてください。このエントリーには機種の出荷時アドレスが入力されています。\n- 固まったままの場合は、**無線機の電源を入れ直してください**。';
	@override String get statusStale => '応答なし';
	@override String get statusDisconnected => '未接続';
	@override String get statusConnecting => '接続中…';
	@override String get statusDisconnecting => '切断中…';
	@override String get statusError => '接続に失敗しました';
	@override String get currentRadioSettings => '現在の無線機の設定';
	@override String get notSupportedByThisRadio => 'この無線機では未対応';
	@override String get cwMessagesButton => 'CWメッセージ';
	@override String get voiceMessagesButton => '電話メッセージ';
	@override String voiceKeyerAvailable({required Object count}) => 'ボイスキーヤー：無線機内のメモリー${count}件';
	@override String get antennaBands => 'バンド';
	@override String get antennaType => 'アンテナの種類';
	@override String get antennaTypeRequired => 'アンテナの種類を選択してください';
	@override late final _Translations$settings$station$antennaTypes$ja antennaTypes = _Translations$settings$station$antennaTypes$ja._(_root);
	@override String get keyType => 'キーの種類';
	@override String get keyTypeRequired => 'キーの種類を選択してください';
	@override late final _Translations$settings$station$keyTypes$ja keyTypes = _Translations$settings$station$keyTypes$ja._(_root);
	@override String get softwareIntermediaries => '中継ソフトウェア';
	@override String get otherBrands => 'その他のブランド';
	@override String get otherEquipment => 'その他の機器（アンテナ、キーなど）';
	@override String get newAntenna => '新しいアンテナ';
	@override String get newKey => '新しいキー';
	@override String get newKeyer => 'WinKeyer（K1ELまたは互換機）';
	@override String keyViaRadio({required Object radio}) => '${radio}のCATキーヤー';
	@override String keyOnDevice({required Object device}) => '${device}のキー';
	@override String get trackStationInfo => 'QSOごとにステーション情報を記録';
	@override String get includeStationInfoInAdif => 'ADIFエクスポートに含める';
	@override String get whatToTrack => '記録する項目';
	@override String get trackFieldRig => 'トランシーバー';
	@override String get trackFieldPower => 'パワー';
	@override String get watts => 'ワット';
	@override String get trackFieldAntenna => 'アンテナ';
	@override String get trackFieldKey => 'CWキー';
	@override String get placeholderConnectDelay => '接続遅延（ms）';
	@override String get placeholderConnectDelayDescription => 'シミュレートしたハンドシェイクにかかる時間。空欄または0で即座に接続します。';
	@override String get placeholderDropAfter => '切断までの時間（秒）';
	@override String get placeholderDropAfterDescription => '再接続の処理を試すため、接続を自動的に閉じます。空欄または0で切断しません。';
	@override String get placeholderFailConnect => '常に接続に失敗する';
	@override String get placeholderConnectFailure => 'プレースホルダー無線機はこの接続を拒否するよう設定されています';
	@override String get placeholderFreq => '周波数（kHz）';
	@override String get placeholderFreqDescription => 'プレースホルダー無線機の初期周波数。その後はアプリがチューニングした値を報告します。';
	@override String get placeholderMode => 'モード';
	@override String get placeholderModeDescription => 'プレースホルダー無線機の初期モード（例：USB、CW、FT8）。';
	@override String get placeholderPower => 'パワー（ワット）';
	@override String get placeholderPurpose => 'ロギングのために、使用中のリグを記録するための無線機です';
	@override String get placeholderReplyDelay => '応答遅延（ms）';
	@override String get placeholderReplyDelayDescription => 'プレースホルダー無線機が変更を報告するまでの時間。空欄または0で即座に応答します。';
	@override String get cwKeyerField => 'CAT CWキーヤー';
	@override String get cwKeyerFieldDescription => 'この無線機がCAT経由のテキストでCWをキーイングするかどうか。アプリが認識していないリグではオフ。';
	@override String get voiceMemories => 'ボイスメモリー';
	@override String get voiceMemoriesDescription => '無線機がCAT経由で再生するボイスメモリーの数。ない場合は0。';
	@override String get voiceMemoriesInvalid => '0以上の整数';
	@override String get yaesuMeterCapture => 'メーターの値を記録';
	@override String get yaesuBinaryMeterCaptureDescription => '送信中に無線機の出力メーターと高SWRフラグを読み取り、生の値をログに出力します。Yaesuが公開していない目盛りを作成するためのもので、値はメーターとして表示されません。';
	@override String get yaesuMeterCaptureDescription => '送信中に無線機のPO、SWR、ALCメーターを読み取り、生の値をログに出力します。Yaesuが公開していない目盛りを作成するためのもので、値はメーターとして表示されません。';
	@override String get telemetryInterval => 'メーター読み取り間隔（ms）';
	@override String get telemetryIntervalDescription => '送信中に無線機のメーターを読み取る頻度。空欄にすると、この接続で可能な最速（最大200 ms）になります。';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => '${min}〜${max}のミリ秒単位の整数';
	@override String get pollInterval => 'アイドル時のポーリング間隔（ms）';
	@override String pollIntervalDescription({required Object fallback}) => '周波数とモードが変化していない間に、無線機に問い合わせる頻度。空欄の場合は${fallback} msです。';
	@override String pollIntervalInvalid({required Object min, required Object max}) => '${min}〜${max}のミリ秒単位の整数';
	@override String get advancedSettings => '詳細設定';
	@override String get placeholderSwr => 'SWRの値';
	@override String get placeholderSwrDescription => '送信中にこの無線機がSWRメーターで報告する値。1.8を超えるとパネルが警告します。';
	@override String get placeholderSwrInvalid => '1以上の数値';
	@override String get keyerNone => 'なし';
	@override String get cwDialect => 'CWキーイングの方式';
	@override String get cwDialectDescription => 'この無線機が受け付けるKYコマンドの形式。なしの場合、CAT経由のCWキーイングは行いません。';
	@override String get cwDialectKenwood => 'Kenwood（KY、24文字にパディング）';
	@override String get cwDialectElecraft => 'Elecraft（KYテキスト）';
	@override String get voiceDialect => 'ボイスキーヤーの方式';
	@override String get voiceDialectDescription => 'この無線機がCAT経由でボイスメモリーを再生する方式。なしの場合、CAT経由のボイスメモリーは使用しません。方式を選んで数を指定しない場合は、その方式のデフォルトの数が適用されます。';
	@override String get voiceDialectPb => 'Kenwood（PB、TS-590方式）';
	@override String get voiceDialectK4 => 'Elecraft K4（PBとDA）';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3（スイッチタップ）';
	@override String get placeholderDiagnostic => 'シミュレーション';
	@override String get placeholderWholeNumberInvalid => '0以上の整数を入力してください';
	@override String get placeholderFreqInvalid => '0より大きいkHz単位の周波数を入力してください';
	@override String get placeholderModeInvalid => 'モード名を入力してください（例：USB、CW、FT8）';
	@override String get switchLayout => 'レイアウト';
	@override String get switchLayoutDescription => '無線機をスイッチのどちら側に接続しているか。';
	@override String get switchLayoutRequired => 'スイッチの配線を選択してください';
	@override String switchCommandRefused({required Object command, required Object code}) => 'スイッチが「${command}」を拒否しました（エラー ${code}）';
	@override String get switchBusyTransmitting => 'そのポートは送信中です。アンテナは変更されませんでした';
	@override String get switchNoAntenna => 'なし';
	@override String switchAntennaFor({required Object port}) => 'ポート${port}のアンテナ';
	@override String get switchAntennaForDescription => 'スイッチのこのポートに接続されているアンテナ。';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => 'アンテナ${antennas}本、無線機${radios}台';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => 'アンテナ${antennas}本、無線機1台';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => 'アンテナ1本、無線機${radios}台';
	@override String get switchCommonPort => '共通';
	@override String get dcnAddress => 'デバイスアドレス';
	@override String get dcnAddressDescription => 'モジュールのDIPスイッチで設定したアドレス。同軸リレーモジュールの出荷時設定は2です。';
	@override String get dcnAddressRequired => '1〜99のデバイスアドレスを入力してください';
	@override String switchPortLabel({required Object port}) => 'ポート${port}';
	@override String get switchPortAutoHint => 'バンドデータに追従';
	@override String get switchPortTransmittingHint => '送信中：今は変更できません';
	@override String get switchCurrentStateHeader => '現在の状態';
	@override String get switchCurrentStateDescription => '各無線機ポートが現在どのアンテナに接続されているか。変更は即座に反映されます。';
	@override String get switchWiringHeader => '配線';
	@override String get switchPortInhibitedHint => '送信禁止';
	@override String get rotatorAxes => '軸';
	@override String get rotatorAxesDescription => 'ローテーターが方位のみ回るか、仰角も回るか（G-5500など）。';
	@override String get rotatorAxesAzimuth => '方位のみ';
	@override String get rotatorAxesAzimuthElevation => '方位と仰角';
	@override String get rotatorAzimuthOffset => '方位オフセット';
	@override String get rotatorAzimuthOffsetDescription => 'コントローラーのゼロが真北でない場合に、読み取り値に加える角度（度）。回転もこれに合わせて補正されます。';
	@override String get rotatorElevationOffset => '仰角オフセット';
	@override String get rotatorAzimuthMin => '方位の下限';
	@override String get rotatorAzimuthMax => '方位の上限';
	@override String get rotatorAzimuthMaxDescription => 'コントローラー自身の角度で指定します。オーバーラップのあるローテーターでは360より大きくすると、短い方の回転を選びます。';
	@override String get rotatorElevationMin => '仰角の下限';
	@override String get rotatorElevationMax => '仰角の上限';
	@override String get rotatorElevationMaxDescription => 'コントローラー自身の角度で指定します。反転できるローテーターでは90より大きくします。';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => '${min}〜${max}の整数（度）';
	@override String get rotatorLimitsInvalid => '下限は上限より小さくしてください';
	@override String get rotatorPollInterval => 'ポーリング間隔（ms）';
	@override String rotatorPollIntervalDescription({required Object fallback}) => 'ローテーターの向きを問い合わせる頻度。空欄の場合は${fallback} msです。';
	@override String get rotatorAxesRequired => 'ローテーターが回る軸を選んでください';
	@override String get rotatorRefused => 'コントローラーがコマンドを拒否しました。GS-232モードに設定されているか確認してください。';
	@override String get pstRotatorTroubleshooting => 'PstRotatorは設定が済んでいるときだけ応答し、それ以外はまったく何も返しません：\n\n- **UDP Controlをオンにしてください**：PstRotatorのSetupメニューにあります。\n- **ポートを一致させてください**：Communication → UDP Control Port、変更していなければ12000です。PstRotatorは次のポート（12001）で応答するため、このデバイスでそのポートが空いている必要があります。\n- **PstRotatorをコントローラーに接続してください。** 接続されるまで、UDPでは何も応答しません。\n- **ファイアウォールで許可してください**：PstRotatorを実行しているPCと、応答を待ち受けるこのデバイスの両方で。\n- **Mac、iPhone、iPadでは**、Ham2K Loggerにローカルネットワークへのアクセスが必要です（設定 → プライバシーとセキュリティ → ローカルネットワーク）。';
	@override String rotatorCurrentStateHeader({required Object position}) => '現在の状態：${position}';
	@override String get rotatorDisconnected => '未接続';
	@override String rotatorAzimuthReading({required Object degrees}) => '方位${degrees}°';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => '方位${degrees}°';
	@override String rotatorElevationReading({required Object degrees}) => '仰角${degrees}°';
	@override String rotatorElevationReadingShort({required Object degrees}) => '仰角${degrees}°';
	@override String get rotatorNoReading => 'コントローラーが位置を報告するのを待っています…';
	@override String get rotatorNotResponding => '応答なし';
	@override String rotatorHeldAtLimit({required Object heading}) => '${heading}へ、このローテーターの制限内で可能な限り回転中';
	@override String get rotatorTargetAzimuth => '方位へ回転';
	@override String get rotatorTargetAzimuthShort => '方位へ';
	@override String get rotatorTargetElevation => '仰角へ回転';
	@override String get rotatorTargetElevationShort => '仰角へ';
	@override String get rotatorAzimuthInvalid => '0〜360で指定してください';
	@override String get rotatorElevationInvalid => '0〜180で指定してください';
	@override String get rotatorTurn => '回転';
	@override String get rotatorStop => '停止';
	@override String get configUnreadable => 'この無線機の保存済み設定を読み取れませんでした。設定を開いて再入力するか、削除して追加し直してください。';
	@override String get autoConnectHeld => '前回この無線機に接続したときにHaLoが応答しなくなったため、今回は自動的に接続しませんでした。再試行するには接続を押してください。';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$ja extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オフラインデータ';
	@override String get noFiles => 'データファイルなし';
	@override String get noFilesDescription => 'アクティビティや検索の拡張機能を有効にすると、ここでオフラインデータをダウンロードできます。';
	@override String get refresh => '更新';
	@override String get refreshing => '更新中…';
	@override String get updateAll => 'すべて更新';
	@override String get updatingAll => 'すべてのデータファイルを更新中…';
	@override String get neverDownloaded => '未ダウンロード';
	@override String get updatedJustNow => 'たった今更新';
	@override String updatedDaysAgo({required Object days}) => '${days}日前に更新';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '${days}日${hours}時間前に更新';
	@override String updatedHoursAgo({required Object hours}) => '${hours}時間前に更新';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '${hours}時間${minutes}分前に更新';
	@override String updatedMinutesAgo({required Object minutes}) => '${minutes}分前に更新';
	@override String lastDownloadRefused({required Object existing, required Object imported}) => '前回のダウンロードは${existing}件中${imported}件のレコードしかなかったため、使用しませんでした。受け入れるには更新してください。';
	@override String get extensionsSection => '拡張機能';
}

// Path: settings.profiles
class _Translations$settings$profiles$ja extends Translations$settings$profiles$en {
	_Translations$settings$profiles$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get notSet => '未設定';
	@override String get personalInfo => '個人情報';
	@override String get personalInfoNote => '提出に必要な場合、生成されるログに含まれることがあります';
	@override String get name => '名前';
	@override String get email => 'メール';
	@override String get club => 'クラブ';
	@override String get arrlSection => 'ARRLセクション';
	@override String get racSection => 'RACセクション';
	@override String get section => 'セクション';
}

// Path: settings.search
class _Translations$settings$search$ja extends Translations$settings$search$en {
	_Translations$settings$search$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get clear => 'クリア';
	@override String get hint => '設定を検索';
}

// Path: settings.developer
class _Translations$settings$developer$ja extends Translations$settings$developer$en {
	_Translations$settings$developer$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => '開発者向けの警告、デバッグログ、ツールを有効にします。';
	@override String get experiments => '実験';
	@override String get showIdleMetrics => 'アイドル指標を表示';
	@override String get showIdleMetricsDescription => '拡張機能エンジンが直近1秒間にどれだけアイドルだったかをステータスバーに表示します。タップすると10秒と60秒の平均が見られます。';
	@override String idleMetricsReadout({required Object percent}) => 'アイドル${percent}%';
	@override String get idleMetricsAverages => 'アイドル平均：';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}秒 ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件有効',
		other: '${count}件有効',
	);
	@override String get patchTrack => 'コードプッシュのトラック';
	@override String get patchTrackDescription => 'このデバイスが従うOTAコードプッシュのリング。冒険的なリングほど修正を早く受け取りますが、テストは少なくなります。コードプッシュは次回の再起動時に適用されます。';
	@override String get trackStable => '安定版';
	@override String get trackUnstable => '不安定版';
	@override String get trackBleeding => 'ブリーディング';
	@override String checkingTrack({required Object track}) => '「${track}」のコードプッシュを確認中…';
	@override String get patchDownloaded => 'コードプッシュをダウンロードしました。適用するにはアプリを再起動してください。';
	@override String noNewPatch({required Object track}) => '「${track}」に新しいコードプッシュはありません。';
	@override String get noPatchInstalled => 'コードプッシュはインストールされていません。リリースバイナリを実行中です。';
	@override String runningPatch({required Object patch}) => 'コードプッシュ#${patch}を実行中。';
	@override String get deepLinks => 'ディープリンク';
	@override String get registerUrlSchemes => 'URLスキームを登録';
	@override String get registerUrlSchemesDescription => 'com.ham2k:// のリンクをこのアプリで開けるようにします';
	@override String get registerUrlSchemesDone => 'このアプリで com.ham2k:// のリンクを開けるようになりました';
	@override String registerUrlSchemesFailed({required Object error}) => '登録できませんでした：${error}';
	@override String get systemInformation => 'システム情報';
	@override String get appVersion => 'アプリのバージョン';
	@override String get dataFolder => 'データフォルダー';
	@override String get loading => '（読み込み中…）';
	@override String get panelLoadFailed => 'この設定パネルを読み込めませんでした。';
	@override String get extDevServer => '拡張機能開発サーバー';
	@override String get extensionSettings => '拡張機能の設定';
	@override String get extDevServerDescription => 'アプリに組み込まれた拡張機能の代わりに、ネットワーク上の開発サーバーから拡張機能を読み込み、保存するたびに再読み込みします。';
	@override String get extDevServerAddress => 'サーバーアドレス';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => '接続';
	@override String get extDevServerDisconnect => '切断';
	@override String get extDevServerConnecting => '接続中…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の拡張機能を提供中：${keys}',
		other: '${count}件の拡張機能を提供中：${keys}',
	);
	@override String get extDevServerDisconnected => '未接続';
	@override String get extDevServerReconnect => '起動時に再接続';
	@override String extDevServerLastReload({required Object key, required Object time}) => '最終再読み込み：${key}（${time}）';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件の拡張機能のビルドに失敗',
		other: '${count}件の拡張機能のビルドに失敗',
	);
	@override String get catalog => '拡張機能カタログ';
	@override String get catalogDescription => '別のサーバー（カタログ自体の開発中はローカルサーバー）からカタログを読み込みます。空欄の場合はcatalog.ham2k.netです。';
	@override String get catalogAddress => 'カタログのアドレス';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'カタログ検索のトラック';
	@override String get catalogSearchStable => '安定版のみ';
	@override String get catalogSearchUnstable => '不安定版以上';
	@override String get catalogSearchBleeding => 'ブリーディング以上';
}

// Path: settings.about
class _Translations$settings$about$ja extends Translations$settings$about$en {
	_Translations$settings$about$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get notices => 'お知らせとメッセージ';
	@override String get noticesDescription => '告知とステータスメッセージ';
	@override String get releaseNotes => 'リリースノート';
	@override String get copiedVersion => 'バージョン情報をクリップボードにコピーしました';
}

// Path: settings.panels
class _Translations$settings$panels$ja extends Translations$settings$panels$en {
	_Translations$settings$panels$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get settings => 'アプリの設定';
	@override String get settingsDescription => 'アプリを自分好みに設定';
	@override String get commonSettings => '共通の設定';
	@override String get syncDescription => 'ログをバックアップし、デバイス間で同期';
	@override String get accountsDescription => 'サービスの認証情報、オフラインデータなど';
	@override String get extensions => '拡張機能とアプリ機能';
	@override String get extensionsDescription => 'アクティビティ、コンテスト、ダッシュボードパネルなどの機能';
	@override String get profilesDescription => 'オペレーターのコールサインとステーションプロファイル';
	@override String get stationProfiles => 'ステーションプロファイル';
	@override String get developerSettings => '開発者設定';
	@override String get developerSettingsDescription => 'デバッグと開発用ツール';
	@override String get about => 'アプリについて';
	@override String get aboutDescription => 'バージョン、クレジット、法的情報';
	@override String get unavailableTitle => '一部の設定を利用できません';
	@override String get unavailableText => '拡張機能ランタイムの起動に失敗したため、拡張機能が提供する設定がありません。';
	@override String get station => 'ステーション構成';
	@override String get stationDescription => 'CAT制御とその他のオプション';
	@override String get peers => 'ピアデバイス';
	@override String get peersDescription => '近くの他のデバイスに接続';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$ja extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get six => '6桁（FN31pr）';
	@override String get eight => '8桁（FN31pr55）';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$ja extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get six => '6桁';
	@override String get eight => '8桁';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$ja extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => 'コマンドダイアログを開く';
	@override String get toggleTheme => 'ライトとダークを切り替える';
	@override String get toggleLanguage => '英語とスペイン語を切り替える';
	@override String get fontScaleUp => '文字を大きく';
	@override String get fontScaleDown => '文字を小さく';
	@override String get fontScaleReset => '標準の文字サイズ';
	@override String get densityLooser => 'ゆったりしたレイアウト';
	@override String get densityDenser => '密なレイアウト';
	@override String get densityAuto => 'レイアウト密度を自動に';
	@override String get find => 'ログ内を検索';
	@override String keyerMessage({required Object n}) => 'メッセージ${n}を送信';
	@override String get keyboardMode => 'キーボードモードのオン/オフ';
	@override String get ptt => 'PTT（プッシュトゥトーク）';
	@override String get wipe => '入力中のコンタクトをクリア';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$ja extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get callsign => 'コールサインの入力';
	@override String get escape => '送信の停止、1段階戻る、または閉じる';
	@override String get enter => 'コンタクトを記録';
	@override String get space => '次のフィールド';
	@override String get tab => '次または前のフィールド';
	@override String get arrows => 'フィールド、コントロール、ログの間を移動';
	@override String get walk => 'ログをページ送り、または先頭/末尾へ';
	@override String get undo => '消去や削除を取り消す';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$ja extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => 'ショートカットを追加';
	@override String get listening => 'ショートカットのキーを押してください…';
	@override String get listeningHint => 'Escで中止';
	@override String get add => '追加';
	@override String refusedFixed({required Object keys}) => '${keys}はロギングフィールドまたはダイアログのキーのため、変更できません。';
	@override String refusedCallsign({required Object keys}) => '${keys}はコールサインの入力に使います。Cmd、Ctrl、Altのいずれかと組み合わせてください。';
	@override String reserved({required Object keys}) => '${keys}はアプリに届く前にシステムが使う可能性があります。';
	@override String already({required Object keys}) => '${keys}はすでにこのコマンドのキーの1つです。';
	@override String takeIt({required Object command, required Object keys}) => '「${command}」から${keys}を取る';
	@override String get resetDefault => 'デフォルトに戻す';
	@override String get remove => '削除';
	@override String get commandLabel => 'コマンド';
	@override String get commandHint => '有効なコマンド、または「;」で区切った複数のコマンドを入力';
	@override String get removeCommand => 'コマンドを削除';
	@override String commandUnknown({required Object text}) => '「${text}」というコマンドはありません';
	@override String get noShortcuts => 'キーはまだありません';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$ja extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => 'ショートカットを${location}に保存しました';
	@override String exportFailed({required Object error}) => 'ショートカットをエクスポートできませんでした：${error}';
	@override String importPickerFailed({required Object error}) => 'ファイルを開けませんでした：${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename}はこのアプリで読めるショートカットファイルではありません：${problem}';
	@override String problemNotYaml({required Object line}) => 'テキストが有効なYAMLではありません（${line}行目）';
	@override String get problemNotKeysFile => 'Ham2Kのキーボードショートカットファイルではありません';
	@override String get problemNewerVersion => '新しいバージョンのアプリで書き出されたものです';
	@override String get problemMalformed => '一部がショートカット形式に従っていません';
	@override String get problemTooLarge => '大きすぎます';
	@override String get importTitle => 'ショートカットをインポート';
	@override String writtenOn({required Object platform}) => '${platform}で書き出されました。';
	@override String get writtenOnUnknown => 'このファイルには、どのキーボードで書き出されたかの記載がありません。';
	@override String get translate => 'これらの各キーは、このキーボードでは何にしますか？';
	@override String get leaveOut => 'それらのショートカットを除外';
	@override String get replace => 'このデバイスの設定と置き換え';
	@override String get replaceHint => 'ファイルにないショートカットはすべてデフォルトに戻ります。';
	@override String get merge => 'このデバイスの設定に追加';
	@override String get mergeHint => '同じコマンドについてはファイルのショートカットがこのデバイスのものを置き換え、それ以外は残ります。';
	@override String unknown({required Object commands}) => 'このバージョンでは不明なため除外：${commands}';
	@override String unreadableChords({required Object chords}) => 'ショートカットではないため除外：${chords}';
	@override String refusedChords({required Object chords}) => 'アプリが予約しているキーのため除外：${chords}';
	@override String conflicts({required Object keys}) => 'インポート後に複数のコマンドに割り当てられています：${keys}';
	@override String get importAction => 'インポート';
	@override String get imported => 'ショートカットをインポートしました';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$ja extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$ja extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$ja extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get callsigns => 'ステーションコールサイン';
	@override String get groupBy => 'グループ化';
	@override String get period => '期間';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$ja extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get none => 'グループ化なし';
	@override String get date => '日付';
	@override String get dx => 'DX';
	@override String get unknownContinent => '不明な大陸';
	@override String get unknownEntity => '不明なエンティティ';
	@override String get unknownDate => '日付なし';
}

// Path: home.logs.period
class _Translations$home$logs$period$ja extends Translations$home$logs$period$en {
	_Translations$home$logs$period$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => '今月';
	@override String get last3Months => '過去3か月';
	@override String get thisYear => '今年';
	@override String get lastYear => '昨年';
	@override String get allTime => '全期間';
	@override String get custom => 'カスタム範囲';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$ja extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => '（${span}）';
	@override String get custom => 'カスタム範囲';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$ja extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get date => '日付';
	@override String get time => '時刻';
	@override String get freq => '周波数';
	@override String get mode => 'モード';
	@override String get call => 'コール';
	@override String get name => '名前';
	@override String get station => '局';
	@override String get band => 'バンド';
	@override String get sent => '送信';
	@override String get rcvd => '受信';
	@override String get grid => 'グリッド';
	@override String get state => '州';
	@override String get country => '国';
	@override String get refs => 'リファレンス';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$ja extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSOログ';
	@override String get qsosDescription => '選択したコールサインの全オペレーションにわたるQSO。';
	@override String get info => '情報';
	@override String get infoDescription => 'QSOの総数、または選択したQSOのコールサイン検索結果。';
	@override String get map => '地図';
	@override String get mapDescription => '選択したQSOの位置。';
}

// Path: home.logs.import
class _Translations$home$logs$import$ja extends Translations$home$logs$import$en {
	_Translations$home$logs$import$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'コールサイン：${calls}';
	@override String get skippedOne => '1件のレコードを読み取れませんでした';
	@override String skippedOther({required Object count}) => '${count}件のレコードを読み取れませんでした';
	@override String get readingTitle => 'ADIFファイルを読み込み中…';
	@override String get checkingTitle => '重複を確認中…';
	@override String get importingTitle => 'QSOをインポート中…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object total, required Object done}) => '${total}件中${done}件を確認済み';
	@override String importingDetail({required Object total, required Object imported}) => '${total}件中${imported}件をインポート済み';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$ja extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get defaultName => 'デフォルト';
	@override String untitledName({required Object number}) => 'レイアウト${number}';
	@override String switcherLabel({required Object name}) => 'レイアウト：${name}';
	@override String get menuNew => '新規…';
	@override String get menuExport => 'エクスポート…';
	@override String get menuImport => 'インポート…';
	@override String get menuTitle => 'レイアウト';
	@override String get newTitle => '新しいレイアウト';
	@override String get editTitle => 'レイアウトを編集';
	@override String get edit => '編集';
	@override String get duplicateCurrent => '現在のレイアウトを複製';
	@override String get startFromDefault => 'デフォルトのレイアウトから始める';
	@override String get nameLabel => '名前';
	@override String get descriptionLabel => '説明';
	@override String get create => '作成';
	@override String leaveEditTitle({required Object name}) => '「${name}」の変更を保存しますか？';
	@override String get leaveEditBody => 'このレイアウトには保存されていない変更があります。';
	@override String get discard => '破棄';
	@override String get deleteTitle => 'このレイアウトを削除しますか？';
	@override String deleteBody({required Object name}) => 'レイアウト「${name}」を本当に削除しますか？';
	@override String get exportTitle => 'レイアウトをエクスポート';
	@override String get exportPick => 'エクスポートするパネル';
	@override String get tabSet => 'タブセット';
	@override String get exportAction => 'エクスポート';
	@override String exported({required Object location}) => 'レイアウトを${location}に保存しました';
	@override String exportFailed({required Object error}) => 'レイアウトをエクスポートできませんでした：${error}';
	@override String get importTitle => 'レイアウトをインポート';
	@override String importFromOtherView({required Object view}) => '${view}ビュー用に作られたものです。そのビューにしかないパネルは除外されます。';
	@override String get viewHome => 'ホーム';
	@override String get viewOperation => 'オペレーション';
	@override String get viewLogs => 'ログ';
	@override String get viewChase => 'チェイス';
	@override String get importAsNew => '新しいレイアウトとして';
	@override String get importReplace => 'このレイアウトと置き換え';
	@override String get importAdd => 'このレイアウトに追加';
	@override String get importAddHint => 'パネルは右側の新しい列に追加されます。';
	@override String get importPick => 'インポートするパネル';
	@override String get importReplaceSettings => 'ここで設定済みのパネルの設定を置き換える';
	@override String get importAction => 'インポート';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename}はこのアプリで読めるレイアウトではありません：${problem}';
	@override String problemNotYaml({required Object line}) => 'テキストが有効なYAMLではありません（${line}行目）';
	@override String get problemNotLayoutFile => 'Ham2Kのレイアウトファイルではありません';
	@override String get problemNewerVersion => '新しいバージョンのアプリで書き出されたものです';
	@override String get problemNoArrangement => '配置が含まれていません';
	@override String get problemMalformed => '一部がレイアウト形式に従っていません';
	@override String get problemTooLarge => '大きすぎます';
	@override String importPickerFailed({required Object error}) => 'ファイルを開けませんでした：${error}';
	@override String importFailed({required Object error}) => 'レイアウトをインポートできませんでした：${error}';
	@override String duplicateFailed({required Object error}) => 'レイアウトをコピーできませんでした：${error}';
	@override String get importNothing => 'パネルが選択されていないため、何もインポートされませんでした。';
	@override String importSkipped({required Object panels}) => '除外：${panels}';
	@override String importKeptPinned({required Object panels}) => '${panels}は残しました：小画面の配置に欠かせないためです。';
	@override String get notOffered => 'このビューでは利用できません';
	@override String get alreadyPlaced => 'すでにこのレイアウトにあります';
	@override String needsExtension({required Object name}) => '${name}が必要';
	@override String get listRecoveredTitle => 'レイアウト名を読み込めませんでした';
	@override String get listRecoveredBody => 'このビューのレイアウト一覧を読み込めませんでした。レイアウト自体はすべて残っており、名前の代わりに番号が付いています。';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$ja extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'ログと入力フィールド';
	@override String get infoDescription => '交信中の局について分かっている情報';
	@override String get spotsDescription => 'クラスターとアクティビティプログラムからのスポット';
	@override String get mapDescription => 'コンタクトの位置';
	@override String get summariesDescription => 'オペレーションの統計とスコアを、選んだセクションと順序で表示';
	@override String get summariesSections => 'セクションと順序';
	@override String get summariesDays => '日ごと';
	@override String get summariesReset => 'すべて表示';
	@override String get summariesAllHidden => 'すべてのセクションが非表示です。このパネルの設定で表示するものを選んでください。';
	@override String get clockDescription => '任意のタイムゾーンの時計';
	@override String get clockFace => '文字盤';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'アナログ';
	@override String get clockZone => 'タイムゾーン';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'このデバイス';
	@override String get clockShowSeconds => '秒を表示';
	@override String get weatherDescription => '運用地の現在と今後8時間の天気';
	@override String get weatherUseOperationLocation => 'オペレーションの場所を使用';
	@override String get weatherLocation => '場所';
	@override String get weatherLocationDescription => 'グリッドスクエア（FN31pr）または緯度,経度。「オペレーションの場所を使用」がオンの間は無視されます。';
	@override String get weatherNoLocation => '場所が設定されていません。このパネルの設定で場所を指定するか、場所が設定されたオペレーション内に配置してください。';
	@override String weatherBadLocation({required Object location}) => '場所${location}を読み取れませんでした。FN31prのようなグリッドスクエア、または42.36,-71.06の形式で入力してください。';
	@override String get weatherUnreachable => 'Open-Meteoに接続できませんでした。ネットワークがない可能性があります。まもなく再試行します。';
	@override String get weatherUnreadable => 'Open-Meteoは応答しましたが、読み取れる内容ではありませんでした。まもなく再試行します。';
	@override String weatherGusts({required Object speed}) => '突風 ${speed}';
	@override String get panelAgeNow => 'たった今';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}分前',
		other: '${count}分前',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}時間前',
		other: '${count}時間前',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$ja weatherConditions = _Translations$operation$layout$panels$weatherConditions$ja._(_root);
	@override String get websiteDescription => '任意のWebページをペインに表示';
	@override String get websiteUrl => 'アドレス';
	@override String get websiteRefresh => '更新';
	@override String get websiteRefreshNever => 'しない';
	@override String get websiteRefresh1 => '1分ごと';
	@override String get websiteRefresh5 => '5分ごと';
	@override String get websiteRefresh15 => '15分ごと';
	@override String get websiteTitle => 'パネル名';
	@override String get websiteRefreshNow => '今すぐ更新';
	@override String get websiteNoUrl => 'アドレスがまだありません。このパネルの設定を開いてページを選んでください。';
	@override String get websiteBadUrl => 'Webアドレスではないようです。https:// で始まる必要があります';
	@override String get websiteNotHttps => 'ここに表示できるのはhttps:// のアドレスのみです。';
	@override String get websiteUnsupported => 'このシステムではパネルにWebページを表示できません。';
	@override String get websiteOpenExternally => 'ブラウザで開く';
	@override String websiteLoadFailed({required Object reason}) => 'ページを読み込めませんでした：${reason}';
	@override String get remoteScreenDescription => '他のデバイスが共有している画面、アプリ、ウィンドウ。';
	@override String get remoteScreenTarget => '画面';
	@override String get remoteScreenChoose => '画面を選択…';
	@override String get remoteScreenPickerTitle => '共有画面';
	@override String get remoteScreenPickerEmpty => '画面を共有しているデバイスはありません。表示したいデバイスで、設定 → ピアデバイスの「画面とウィンドウを共有」をオンにしてください。';
	@override String get remoteScreenUnset => '画面が選択されていません。このパネルの設定を開き、他のデバイスが共有している画面を選んでください。';
	@override String get remoteScreenConnecting => '接続中…';
	@override String get remoteScreenPeerAway => 'そのデバイスは現在接続されていません。';
	@override String get remoteScreenNotOffered => 'そのデバイスはこの画面の共有を停止しました。';
	@override String get remoteScreenNoListener => 'そのデバイスは接続を受け付けられません。ファイアウォールを確認してください。';
	@override String get remoteScreenNoLan => '画面はローカルネットワーク経由でのみ共有され、Bluetoothでは共有されません。';
	@override String get remoteScreenRefused => 'そのデバイスはこの画面の共有を拒否しました。';
	@override String get remoteScreenSettings => 'パネル設定';
	@override String get remoteScreenAdjust => '表示を調整';
	@override String get remoteScreenDetail => '詳細度';
	@override String get remoteScreenDetailStandard => '標準';
	@override String get remoteScreenDetailHigh => '高';
	@override String get remoteScreenDetailMaximum => '最大';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => '拡大';
	@override String get remoteScreenZoomOut => '縮小';
	@override String get remoteScreenStopped => 'その画面またはウィンドウはもう表示されていません。';
	@override String get remoteScreenCaptureFailed => 'そのデバイスは画面をキャプチャできませんでした。画面収録の許可が必要な場合があります。';
	@override String get remoteScreenNoAnswer => 'そのデバイスは応答しませんでした。画面共有がオンになっていない可能性があります。';
	@override String get remoteScreenNoMedia => '映像用の接続を開けませんでした。このデバイスのファイアウォールを確認してください。';
	@override String get solarDescription => '太陽と地磁気の状況、バンドごとの伝搬';
	@override String get solarUnreachable => 'hamqsl.comに接続できませんでした。ネットワークがない可能性があります。まもなく再試行します。';
	@override String get solarUnreadable => 'hamqsl.comは応答しましたが、使用できるデータではありませんでした。まもなく再試行します。';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => '昼';
	@override String get solarBandNight => '夜';
	@override String get solarBandGood => '良好';
	@override String get solarBandFair => '普通';
	@override String get solarBandPoor => '不良';
	@override String solarSources({required Object primary, required Object secondary}) => '出典：${primary}、${secondary}';
	@override String get remoteScreenDegraded => '接続が不安定です。フレームをスキップしています。';
	@override String get remoteScreenStalled => 'フレームが届かなくなりました。この接続は遅すぎる可能性があります。';
	@override String get radioDescription => '無線機のフロントパネル（周波数、モード、出力をCATで制御）';
	@override String get radioStyle => 'スタイル';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'モダン';
	@override String get radioRadio => '無線機';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — 無線機が指定されていません';
	@override String get radioNoRadio => '表示する無線機がありません。このパネルの設定で選ぶか、ステーション構成で追加してください。';
	@override String get radioNotConfigured => 'この無線機はまだ設定されていません。ステーション構成でポートまたはアドレスを選んでください。';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => '無線機が接続されていません';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'この無線機を接続';
	@override String get radioDisconnect => 'この無線機を切断';
	@override String get radioStale => 'データなし';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR高';
	@override String get rotatorDescription => 'アンテナの向きを、局を中心にした地図上に表示します。地図をタップすると回転します。';
	@override String get rotatorRotator => 'ローテーター';
	@override String rotatorAutoNamed({required Object name}) => '自動 — ${name}';
	@override String get rotatorAutoNone => '自動 — ローテーターはまだありません';
	@override String get rotatorBeamWidth => 'ビーム幅';
	@override String get rotatorBeamWidthDescription => '方位の周りに描く角度（度）。0なら描画しません。';
	@override String get rotatorLocation => '場所';
	@override String get rotatorLocationDescription => '地図の中心にするグリッドスクエアまたは緯度経度。空欄ならオペレーションの場所を使います。';
	@override String get rotatorTheme => 'テーマ';
	@override String get rotatorThemeColor => 'カラー';
	@override String get rotatorThemeGray => 'グレー';
	@override String get rotatorThemeMuted => '淡色';
	@override String get rotatorGrayline => 'グレイラインを表示';
	@override String get rotatorNoRotator => '表示するローテーターがありません。このパネルの設定で選ぶか、ステーション構成で追加してください。';
	@override String get rotatorNoLocation => '地図の中心にする場所がありません。このパネルの設定で指定してください。';
	@override String get rotatorDisconnected => '未接続';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => '応答なし';
	@override String get rotatorLocationInvalid => 'このパネルの設定の場所を読み取れません。グリッドスクエアか、40.7, -74.0 のような緯度経度を使ってください。';
	@override String rotatorElevation({required Object degrees}) => '仰角${degrees}°';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'W';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$ja extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'コンパクトファイル名を使用';
	@override String get descriptionOn => 'アップロード用の短い名前（例：N0CALL@US-1234-20260727.adi）';
	@override String get descriptionOff => '読みやすい名前（例：2026-07-27 N0CALL at US-1234.adi）';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$ja extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '個人情報を含める';
	@override String get descriptionOn => '名前、住所、メール、グリッドスクエア、メモを含めます';
	@override String get descriptionOff => '名前、住所、メール、グリッドスクエア、メモを除外します';
	@override String get note => 'Full ADIF Exportには常にすべてが含まれます';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$ja extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => '先にメールアドレスを追加してください';
	@override String get needsEmailBody => 'Ham2K File StashはLoFiアカウントのメールアドレスにファイルを送信し、stash.ham2k.netへのログインにもそのアドレスを使います。あなたのアカウントにはまだ確認済みのメールアドレスがありません。設定 › クラウド同期で追加してください。';
	@override String get openSyncSettings => 'クラウド同期を開く';
	@override String get replaceTitle => '最近のスタッシュが置き換えられます';
	@override String replaceBody({required Object name}) => '6時間以内に「${name}」を送信しましたが、まだダウンロードされていません。無料アカウントで保持できるスタッシュは一度に1つだけのため、今送信すると置き換えられます。';
	@override String get replaceConfirm => 'それでも送信';
	@override String get failedTitle => 'Ham2K File Stashに送信できませんでした';
	@override String get sentTitle => 'Ham2K File Stashに送信しました';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'このファイルは、任意のブラウザで **[stash.ham2k.net](https://stash.ham2k.net)** にアクセスして取得できます。',
		other: 'これらのファイルは、任意のブラウザで **[stash.ham2k.net](https://stash.ham2k.net)** にアクセスして取得できます。',
	);
	@override String get mayHaveArrived => 'スタッシュから応答がありません。ファイルは届いている可能性があります。再送信する前にstash.ham2k.netを確認してください';
	@override String get notSent => '未送信';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: 'このファイルは届きませんでした：',
		other: 'これら${count}件のファイルは届きませんでした：',
	);
	@override String get emailOffer => 'また、ご希望であれば、直接リンクを記載したメールをお送りできます。';
	@override String get emailMe => 'リンクをメールで送信';
	@override String get emailSent => 'ダウンロードリンクをメールでお送りしました。';
	@override String emailFailed({required Object error}) => 'メールを送信できませんでした：${error}';
	@override String get freeTier => '無料アカウントでは一度に保持できるスタッシュは1つだけです。サブスクライバーは必要な数だけ保持できます。';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count,
		one: '${count}件のファイルをHam2K File Stash（stash.ham2k.net）に送信しました',
		other: '${count}件のファイルをHam2K File Stash（stash.ham2k.net）に送信しました',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$ja extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get af => 'アフリカ';
	@override String get as => 'アジア';
	@override String get eu => 'ヨーロッパ';
	@override String get na => '北アメリカ';
	@override String get oc => 'オセアニア';
	@override String get sa => '南アメリカ';
	@override String get an => '南極';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$ja extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スポットを絞り込む';
	@override String get band => 'バンド';
	@override String get mode => 'モード';
	@override String get age => '経過時間';
	@override String get sources => 'ソース';
	@override String get continent => '大陸';
	@override String get sorting => '並び替え';
	@override String get sortByTime => 'スポット時間順';
	@override String get sortByFrequency => '周波数順';
	@override String get sortByWanted => 'モストウォンテッド順';
	@override String get groupByBand => 'バンドでグループ化';
	@override String get groupCallsWithNotes => 'ノート付きコールをグループ化';
	@override String get alertingOnly => 'アラート付きのスポットのみ';
	@override String get sourceNoReply => '応答なし';
	@override String get sourceError => 'エラー';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$ja extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ロギングパネルは使用中です';
	@override String get editingBody => '記録済みのコンタクトを編集中です。代わりにこのスポットを記録しますか？それとも戻って編集を完了しますか？';
	@override String get composingBody => 'コンタクトの入力を始めています。代わりにこのスポットを記録しますか？それとも戻って入力を完了しますか？';
	@override String get goBack => '戻る';
	@override String get clearAndLog => 'クリアしてスポットを記録';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$ja extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '左利きモード';
	@override String get descriptionOn => '左利き用レイアウトを使用しています';
	@override String get descriptionOff => '右利き用レイアウトを使用しています';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$ja extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '国旗';
	@override String get dx => 'DXコンタクトのみ表示';
	@override String get all => 'すべてのコンタクトに国旗を表示';
	@override String get none => '国旗を表示しない';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$ja extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get dx => 'DXコンタクトのみに国旗を表示しています';
	@override String get all => 'すべてのコンタクトに国旗を表示しています';
	@override String get none => '国旗を表示していません';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$ja extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オペレーターを提案';
	@override String get descriptionOn => '別のステーションコールサインで運用するオペレーションでは、あなたのコールサインをオペレーターとして提案します';
	@override String get descriptionOff => '入力しない限りオペレーターは空欄のままです';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$ja extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '方位を表示';
	@override String get descriptionOn => '局への推定方位を表示しています';
	@override String get descriptionOff => '方位情報を表示していません';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$ja extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '逆方位も表示';
	@override String get descriptionOn => '局からの方位も「45° / 225°」のように表示しています';
	@override String get descriptionOff => '局への方位のみを表示しています';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$ja extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'シグナルレポートの順序を切り替える';
	@override String get sentFirst => '送信が先、受信が後';
	@override String get rcvdFirst => '受信が先、送信が後';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$ja extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'RST入力時に次のフィールドにジャンプ';
	@override String get descriptionOn => 'RST入力後に次のフィールドへジャンプします';
	@override String get descriptionOff => '自動的にジャンプしません';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$ja extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'デフォルトレポート — 電話';
	@override String get description => 'SSB、FM、AMで送信または受信が空欄の場合に使用';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$ja extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'デフォルトレポート — CWとデータ';
	@override String get description => 'CW、RTTY、その他のデータモードで送信または受信が空欄の場合に使用';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$ja extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'デフォルトレポート — FT8とFT4';
	@override String get description => 'FTモードで送信または受信が空欄の場合に使用';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$ja extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '数字行';
	@override String get description => 'ロギング中、キーボードの上に数字キーの行を表示';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$ja extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スラッシュとピリオドキー';
	@override String get description => '状況に応じたキーを追加：コールサインには「/」、数値には「.」';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$ja extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'キー押下時に振動';
	@override String get description => '数字キーをタップしたときの触覚フィードバック';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$ja extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get off => '無効';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$ja extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get noCall => 'ログインに使うオペレーターのコールサインがありません';
	@override String get connectFailed => 'ノードに到達できませんでした';
	@override String get needsPassword => 'ノードがパスワードを求めていますが、保存されていません';
	@override String get loginFailed => 'ノードがログインを受け付けませんでした';
	@override String get disconnected => 'ノードが接続を閉じました';
	@override String get timeout => 'ノードが応答しませんでした';
	@override String get off => '「クラスターに接続」がオフです';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$ja extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$ja extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'キーボードでPTTを操作';
	@override late final _Translations$settings$radio$pttKey$modes$ja modes = _Translations$settings$radio$pttKey$modes$ja._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$ja descriptions = _Translations$settings$radio$pttKey$descriptions$ja._(_root);
	@override String get key => 'PTTキー';
	@override String get pill => 'TX';
	@override String get transmitting => '送信中';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$ja extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スマートVFOスナップ';
	@override String get descriptionOn => 'ダイヤルを止めた後、周波数を適切なステップに丸めます。音声モードのみ。';
	@override String get descriptionOff => 'チューニングした周波数をそのまま保ちます。';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$ja extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スマートスナップ：待機時間';
	@override String get description => '周波数を丸めるまでにダイヤルが止まっている必要がある時間。短いと即座に、長いとゆっくりした操作にも余裕ができます。';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$ja extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スマートスナップ：大きな移動';
	@override String get description => 'この量以上動かすと、最後がどれだけゆっくりでも周波数をkHz単位に丸めます。';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$ja extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スマートスナップ：最小の移動';
	@override String get description => 'これより小さい移動では周波数を丸めないため、微調整はそのまま保たれます。';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$ja extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スマートスナップ：最も遅い移動';
	@override String get description => 'これより遅くダイヤルを回すと、大きな移動でない限り周波数を丸めません。';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$ja extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM オフ';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enterでメッセージ送信';
	@override String get off => 'オフ';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enterでメッセージ送信：${state}。タップして変更。';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$ja extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'キーヤー速度';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$ja extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'CWキーヤーメッセージ';
	@override String get notSupported => '現在の無線機はCWキーイングに対応していません';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'メッセージ${n}';
	@override String get labelField => 'ラベル';
	@override String labelKey({required Object n}) => 'F${n}のラベル';
	@override String get details => '詳細';
	@override String get empty => '（空）';
	@override String get sets => 'メッセージセット';
	@override String get newSet => '新しいセット';
	@override String get renameSet => 'セット名を変更';
	@override String get deleteSet => 'セットを削除';
	@override String get newSetName => '名前';
	@override String get setDefault => 'デフォルト';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESMメッセージ';
	@override String get setSaved => 'マイメッセージ';
	@override String get repeat => 'メッセージ1を繰り返す';
	@override String get repeatShort => 'M1を繰り返す';
	@override String get cooldown => '繰り返しまでの待ち時間';
	@override String cooldownSeconds({required Object n}) => '${n}秒';
	@override String get repeatWait => '繰り返し中';
	@override String get keyboard => '入力して送信';
	@override String get keyboardField => '入力して送信';
	@override String get help => 'ヘルプ';
	@override String get helpTitle => 'CWメッセージの書き方';
	@override String get helpIntro => 'メッセージでは次の値をテンプレートとして使えます：';
	@override String get helpOpCall => 'あなたのコールサイン';
	@override String get helpQsoCall => '相手のコールサイン（//スタックでは記録されるコール）';
	@override String get helpQsoFullCall => '有効なコールがあれば相手のコールサイン。部分入力の場合は空';
	@override String get helpQsoPartial => '部分的なコール。完全な有効コールがある場合は空';
	@override String get helpQsoNextCall => '//スタックで、次に記録対象として選ばれるコール（完全な有効コールがある場合）';
	@override String get helpQsoNextPartial => '//スタックで、現在のコンタクトを記録した後の次の部分コール';
	@override String get helpQsoName => '相手の名前（入力値、なければ検索結果から）';
	@override String get helpQsoState => '相手の州（入力値、なければ検索結果から）';
	@override String get helpKeyerMsg => '別のメッセージ内で、送信される形のメッセージ1。メッセージ1〜8で有効';
	@override String get helpQsoRst => '送信するレポート';
	@override String get helpQsoSerial => 'シリアル番号を送るコンテストでの、あなたのシリアル番号';
	@override String get helpPad => '指定した桁数までゼロで埋めます：7は007として送信';
	@override String get helpCut => 'カットナンバー、0はT、9はN：599は5NNとして送信';
	@override String get helpCutDigits => 'カットする数字を引用符で指定します。0はT、1はA、5はE、9はN';
	@override String get helpFullExample => '完全な例：';
	@override String get helpExample => 'W1AW 5NN TT7を送信';
	@override String get helpEsmIntro => 'Enterでメッセージ送信がオンの場合、N1MMと同様に、Enterで対応するファンクションキーのメッセージを送信します。ESMメッセージセットの初期内容は次のとおりです：';
	@override String get helpEsmCq => 'Run時、コール欄が空の状態でEnterを押すとCQを出します';
	@override String get helpEsmExchange => 'あなたの交換：Run時は相手のコールの後、S&P時は相手が応答した後';
	@override String get helpEsmThanks => 'コンタクトの記録後のお礼。qsoは記録されたコンタクト、nextは次のコンタクトを指します';
	@override String get helpEsmMyCall => 'S&P時、応答する局へのあなたのコール';
	@override String get helpEsmHisCall => 'Run時、交換の前に送る相手のコール';
	@override String get helpEsmAgain => '相手の交換がまったく取れなかったときに再度尋ねます';
	@override String get helpEsmStackThanks => '//スタック用の推奨F3：お礼の後、スタックの次の局を呼んで交換を送るか、部分コールを聞き返します（TU KR?）。残りがなければTUのみ';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$ja extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get label => 'キーヤー';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => '音声';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$ja extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '電話キーヤーメッセージ';
	@override String get notSupported => '現在の無線機は電話メッセージに対応していません';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'ボイスメモリー${n}';
	@override String get labelField => 'ラベル';
	@override String labelKey({required Object n}) => 'ボイスメモリー${n}のラベル';
	@override String durationSeconds({required Object n}) => '${n}秒';
	@override String get emptyOnRadio => '空';
	@override String get notMeasured => '長さ不明';
	@override String get playButton => '再生';
	@override String get recordButton => '録音';
	@override String get stopButton => '停止';
	@override String get repeat => 'メッセージ1を繰り返す';
	@override String recordHelpTitle({required Object model}) => '${model}の注意事項：';
	@override String namedOnDevice({required Object device}) => 'これらのメモリーは${device}の無線機にあります。名前と長さはそのデバイスのものです。';
	@override String get namedOnRadio => '無線機に保存され、他のクライアントからも見えます。';
	@override String get recordHelpYaesuDvs => '無線機に[REC]表示が出るのを待ってから、PTTボタンを押したままメッセージを録音します。不要なクリック音を避けるため、PTTを離す前にアプリのSTOPボタンを押して録音を終了してください。';
	@override String get recordHelpFt891 => '[REC]表示が4回以上点滅するのを待ってから、PTTボタンを押したままメッセージを録音します。不要なクリック音を避けるため、PTTを離す前にアプリのSTOPボタンを押して録音を終了してください。';
	@override String get pill => '音声';
	@override String play({required Object n}) => 'メモリー${n}を再生';
	@override String get stop => '停止';
	@override String record({required Object n}) => 'メモリー${n}を録音';
	@override String get stopRecording => '録音を停止';
	@override String get playing => '再生中…';
	@override String get recording => '録音中…';
	@override String playingMemory({required Object label}) => '${label}を再生中';
	@override String recordingMemory({required Object label}) => '${label}を録音中';
	@override String get doubtful => '無線機は再生しましたか？すぐにアイドル状態と報告しました。';
	@override String get recordOnRadio => 'メモリーは無線機本体で録音する必要があります。';
	@override String get sets => 'メッセージセット';
	@override String get soundFilesSet => 'このコンピューター上のサウンドファイル';
	@override String get openFileButton => 'ファイルを開く';
	@override String get newSet => '新しいセット';
	@override String get renameSet => 'セット名を変更';
	@override String get deleteSet => 'セットを削除';
	@override String get newSetName => '名前';
	@override String deleteSetConfirm({required Object name}) => '${name}とその録音を削除しますか？元に戻せません。';
	@override String get output => '音声の出力先';
	@override String get input => '録音元';
	@override String get outputRadio => 'ネットワーク経由で無線機に送る';
	@override String get inputDefault => 'システムのデフォルト';
	@override String get pickDevice => 'サウンドデバイスを選択';
	@override String deviceMissing({required Object name}) => '${name}（未接続）';
	@override String get lead => 'キーイング後の遅延';
	@override String get tail => 'キーイング解除前の遅延';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => '試聴';
	@override String get notRecorded => '未録音';
	@override String get unplayable => 'このファイルは再生できません';
	@override String get problemNoOutput => 'メッセージを再生する前に、無線機に音声を送るサウンドデバイスを選んでください。';
	@override String get problemOutputMissing => '無線機に音声を送るサウンドデバイスが接続されていません。';
	@override String get problemInputMissing => '録音デバイスが接続されていません。';
	@override String get problemDeviceFailed => 'サウンドデバイスを開けませんでした。';
	@override String get problemNotRecorded => 'そのメッセージはまだ録音されていません。';
	@override String get problemRecordingSilent => '録音デバイスから何も聞こえなかったため、メッセージはそのままにしました。入力と、アプリにマイクの使用が許可されているかを確認してください。';
	@override String get problemRadioAudioUnavailable => '無線機は現在アプリからの音声を受け取っていません。無線機へのネットワーク接続が必要です。';
	@override String get problemSourceRefused => '無線機が送信音声をアプリに切り替えなかったため、メッセージを停止しました。アプリの音声を送信するよう無線機を設定してください。';
	@override String get problemCannotKey => 'この無線機はCATでキーイングできないため、コンピューターからメッセージを流せません。';
	@override String get problemUnplayable => 'そのメッセージのファイルは、アプリで再生できるサウンドファイルではありません。WAV、FLAC、MP3ファイルを使うか、録音し直してください。';
	@override String get problemRecordingFailed => '録音が途中で切れたため、メッセージはそのままにしました。録音デバイスがまだ接続されているか、ディスクに空きがあるかを確認してください。';
	@override String get problemFileFailed => '録音をメッセージの場所に保存できなかったため、メッセージはそのままにしました。';
	@override String problemWordsMissing({required Object words}) => 'そのメッセージには未録音の単語が必要です：${words}。';
	@override String problemTemplateFailed({required Object error}) => 'そのメッセージのテンプレートに問題があります：${error}';
	@override String get problemNoOperation => '自分の声で言うメッセージは、対象のコンタクトがあるオペレーション内で再生します。';
	@override String get problemNothingSaid => 'そのメッセージはこのコンタクトに対して何も言いません。';
	@override String get templateField => '自分の声で言う';
	@override String get templateHelp => '空欄なら録音をそのまま再生します。入力すると、録音した単語をコンタクトごとに当てはめてメッセージを言います。使える値：';
	@override String get help => 'ヘルプ';
	@override String get helpTitle => '自分の声でメッセージを言う';
	@override String get helpFullExample => 'メッセージ全体の例：';
	@override String get helpExample => '相手のコール、相手へのレポート、そして「QSL?」の録音';
	@override String get playOnRadio => '無線機で再生';
	@override String get templateHelpCall => '相手のコール';
	@override String get templateHelpReport => '相手に送るレポート';
	@override String get templateHelpMessage => 'メッセージ2の録音を、録音のまま再生';
	@override String get voiced => '自分の声で読み上げ';
	@override String willSay({required Object words}) => '読み上げ：${words}';
	@override String willSayMissing({required Object words}) => '未録音：${words}';
	@override String get previewNoOperation => '何を言うかを確認するにはオペレーションを開いてください。';
	@override String get wordsDescription => 'コールや数字などに自分の声を使います。';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$ja extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '単語の録音';
	@override String get callField => 'オペレーター別の単語';
	@override String get intro => '各単語や数字を、コールサインを言うときのように続けて素早く3回録音します。長いフレーズは1回だけ録音します。';
	@override String get recordAll => 'すべて録音';
	@override String get recordAllGuide => '各単語は続けて3回、複数の単語からなるフレーズは1回読み上げ、行の間で息継ぎをしてください。最後まで読んだら停止を押してください。';
	@override String recordingOne({required Object word}) => '「${word} ${word} ${word}」と言ってから、停止を押してください。';
	@override String recordingOnce({required Object words}) => '「${words}」と言ってから、停止を押してください。';
	@override String get recorded => '録音済み';
	@override String get notRecorded => '未録音';
	@override String get addPhrase => 'フレーズを追加';
	@override String get phraseField => 'フレーズ（メッセージに書くとおりに）';
	@override String get deletePhrase => 'フレーズを削除';
	@override String get tryField => '試しに読み上げ';
	@override String get pauseLetters => '文字間の間隔';
	@override String get pauseWords => '単語間の間隔';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => '速度';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => '詳細設定';
	@override String get splitSilent => '録音に何も聞こえませんでした。';
	@override String get splitNotThreeTakes => '3回分を見つけられませんでした。単語を続けて3回言ってから、もう一度試してください。';
	@override String get splitLineCount => '読み上げの中にすべての単語を見つけられませんでした。各単語を3回ずつ、単語の間で息継ぎをして読んでください。';
	@override String get splitLinesTooClose => '単語を区別できませんでした。単語の間にもっと長く息継ぎを入れてください。';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$ja extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'スポットでのゼロビートを避ける';
	@override String get descriptionOn => '無線機が接続されている場合、CWスポットから数Hzずらしてチューニングし、応答する全員が同じ音で呼ばないようにします。';
	@override String get descriptionOff => 'スポットされた周波数ちょうどにチューニングします。';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$ja extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'ゼロビート：回避範囲';
	@override String get description => 'スポット周波数からどれだけ離れた位置に合わせるか（上下どちらか）。オフセットがゼロ付近になることはありません。それでは再びゼロビートになるためです。';
}

// Path: settings.map.style
class _Translations$settings$map$style$ja extends Translations$settings$map$style$en {
	_Translations$settings$map$style$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '地図スタイル';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$ja extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'コールサインを表示';
	@override String get description => '各コンタクトを、バンドの色のコールサイン付きピルで表示します';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$ja extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'グレイラインを表示';
	@override String get description => '地球の夜側を暗くし、薄明をグラデーションで表示します';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$ja extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get automatic => '自動';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$ja extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'アプリ使用データを共有';
	@override String get descriptionOn => '使用状況、設定、クラッシュ、パフォーマンスのデータを共有して、アプリの改善に協力しています';
	@override String get descriptionOff => 'アプリの使用データを非公開にしています。\nHam2Kチームはクラッシュやその他の問題を検出できません。';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$ja extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'オペレーションデータを共有';
	@override String get descriptionOn => '一部のオペレーションデータを公開し、他のユーザーと共有しています';
	@override String get descriptionOff => 'オペレーションデータをプライベートに保っています';
}

// Path: settings.station.models
class _Translations$settings$station$models$ja extends Translations$settings$station$models$en {
	_Translations$settings$station$models$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - 汎用';
	@override String get icomGeneric => 'Icom - 汎用';
	@override String get kenwoodGeneric => 'Kenwood - 汎用';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - 汎用';
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
	@override String get rigctld => 'rigctld経由で制御する無線機';
	@override String get rigctldNodeName => 'マイ無線機（rigctld経由）';
	@override String get flrig => 'flrig経由で制御する無線機';
	@override String get flrigNodeName => 'マイ無線機（flrig経由）';
	@override String get hrd => 'Ham Radio Deluxe®経由で制御する無線機';
	@override String get hrdNodeName => 'マイ無線機（HRD経由）';
	@override String get n3fjp => 'N3FJP経由で制御する無線機';
	@override String get n3fjpNodeName => 'マイ無線機（N3FJP経由）';
	@override String get commander => 'DXLab Commander経由で制御する無線機';
	@override String get commanderNodeName => 'マイ無線機（Commander経由）';
	@override String get antenna => 'アンテナ';
	@override String get key => 'CWキー';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => '汎用無線機（プレースホルダー）';
	@override String get placeholderRadioNodeName => 'マイ無線機';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 Coax Switch';
	@override String get gs232a => 'Yaesu GS-232A ローテーターインターフェース';
	@override String get pstRotator => 'PstRotator（UDP制御）';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$ja extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get network => 'ネットワーク/WiFi';
	@override String get secureNetwork => 'セキュアネットワーク/WiFi';
	@override String get usbSerial => 'USBシリアル';
	@override String get wifi => 'ネットワーク/WiFi';
	@override String get bluetoothSerial => 'Bluetoothシリアル';
	@override String get bleSerial => 'Bluetooth LE';
	@override String get placeholder => 'プレースホルダー';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$ja extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'ダイポール';
	@override String get vertical => 'バーチカル';
	@override String get yagiBeam => '八木 / ビーム';
	@override String get loop => 'ループ';
	@override String get longWire => 'ロングワイヤー / EFHW';
	@override String get other => 'その他';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$ja extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get straight => '縦振れ電鍵';
	@override String get sideswiper => '横振れ電鍵（サイドスワイパー）';
	@override String get bug => 'バグキー（機械式半自動）';
	@override String get fullyAutomatic => '全自動キーヤー';
	@override String get singlePaddle => 'シングルパドル';
	@override String get dualPaddle => 'デュアルパドル';
	@override String get computerDriven => 'コンピューター制御';
	@override String get other => 'その他';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$ja extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get unknown => '不明';
	@override String get sunny => '晴れ';
	@override String get clear => '快晴';
	@override String get mainlySunny => 'おおむね晴れ';
	@override String get mainlyClear => 'おおむね快晴';
	@override String get partlyCloudy => '晴れ時々曇り';
	@override String get cloudy => '曇り';
	@override String get foggy => '霧';
	@override String get rimeFog => '着氷性の霧';
	@override String get lightDrizzle => '弱い霧雨';
	@override String get drizzle => '霧雨';
	@override String get heavyDrizzle => '強い霧雨';
	@override String get lightFreezingDrizzle => '弱い着氷性の霧雨';
	@override String get freezingDrizzle => '着氷性の霧雨';
	@override String get lightRain => '弱い雨';
	@override String get rain => '雨';
	@override String get heavyRain => '強い雨';
	@override String get lightFreezingRain => '弱い着氷性の雨';
	@override String get freezingRain => '着氷性の雨';
	@override String get lightSnow => '弱い雪';
	@override String get snow => '雪';
	@override String get heavySnow => '大雪';
	@override String get snowGrains => '霧雪';
	@override String get lightShowers => '弱いにわか雨';
	@override String get showers => 'にわか雨';
	@override String get heavyShowers => '強いにわか雨';
	@override String get lightSnowShowers => '弱いにわか雪';
	@override String get snowShowers => 'にわか雪';
	@override String get thunderstorm => '雷雨';
	@override String get lightThunderstormsWithHail => 'ひょうを伴う弱い雷雨';
	@override String get thunderstormWithHail => 'ひょうを伴う雷雨';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$ja extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get off => 'いいえ';
	@override String get toggle => 'トグル';
	@override String get hold => 'ホールド';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$ja extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$ja._(TranslationsJa root) : this._root = root, super.internal(root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get off => 'キーボードでは無線機をキーイングしません。';
	@override String get toggle => '電話モードでは、PTTキーで無線機をキーイングし、もう一度押すと解除します。1分経つと自動的に解除されます。';
	@override String get hold => '電話モードでは、PTTキーを押している間、最大1分まで無線機が送信します。';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsJa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => '保存',
			'common.ok' => 'OK',
			'common.cancel' => 'キャンセル',
			'common.delete' => '削除',
			'common.create' => '作成',
			'common.error' => 'エラー',
			'common.close' => '閉じる',
			'common.done' => '完了',
			'common.callsign' => 'コールサイン',
			'common.clear' => 'クリア',
			'common.dismiss' => '閉じる',
			'common.copyDetails' => '詳細をコピー',
			'common.expand' => '展開',
			'common.collapse' => '折りたたむ',
			'onboarding.welcomeTitle' => 'Ham2K Portable Loggerへようこそ！',
			'onboarding.welcomeTitleDesktop' => 'Ham2K Power Loggerへようこそ！',
			'onboarding.welcomeBody' => 'ご利用に合わせて設定するため、いくつか質問させてください。',
			'onboarding.skip' => 'スキップ',
			'onboarding.kContinue' => '続行',
			'onboarding.back' => '戻る',
			'onboarding.next' => '次へ',
			'onboarding.done' => '完了',
			'onboarding.callsignTitle' => 'あなたのコールサインは？',
			'onboarding.callsignBody' => 'このアプリを活用するには、アマチュア無線技士の免許が必要です',
			'onboarding.callsignLabel' => 'オペレーターのコールサイン',
			'onboarding.alreadyHaveAccount' => 'すでにアカウントをお持ちですか？',
			'onboarding.foundSiblingTitle' => '既存のアカウントにリンクしますか？',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'このデバイスで${app}が見つかりました。このアプリを同じアカウントにリンクすると、コールサインとログが引き継がれます。',
			'onboarding.foundPoloBody' => 'このデバイスで旧バージョンのHam2K Portable Loggerが見つかりました。このアプリを同じアカウントにリンクすると、コールサインとログが引き継がれます。',
			'onboarding.foundSiblingsBody' => 'このデバイスで他のHam2Kアプリが見つかりました。このアプリをいずれかのアカウントにリンクすると、コールサインとログが引き継がれます。',
			'onboarding.linkWithApp' => ({required Object app}) => '${app}とリンク',
			'onboarding.linkWithPolo' => '旧バージョンのアカウントとリンク',
			'onboarding.setUpFresh' => '新規にセットアップ',
			'onboarding.activitiesTitle' => 'お気に入りのアクティビティ',
			'onboarding.activitiesBody' => 'これらの人気のアクティベーションプログラムに興味はありますか？',
			'onboarding.activitiesFooter' => '（設定にもっとオプションがあります）',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => 'クラウド同期',
			'onboarding.syncBody' => 'Ham2K Log Filerはログのバックアップをクラウドに保存し、Ham2Kアプリを使っているすべてのデバイス間で同期します。',
			'onboarding.syncPricing' => '無料です！有料サブスクリプションにすると、さらに高速になります。',
			'onboarding.syncLabel' => 'クラウド同期を有効にする',
			'onboarding.syncOffWarning' => '警告：デバイスの故障や紛失などでオペレーションデータを失う可能性が高くなります。',
			'onboarding.notNow' => '今はしない',
			'onboarding.consentTitle' => 'データとプライバシー',
			'onboarding.consentUsageBody' => 'アプリの改善に役立てるため、パフォーマンス、クラッシュ、アプリ使用状況のデータを収集させてください。',
			'onboarding.consentUsageLabel' => 'アプリ使用データを共有',
			'onboarding.consentOperationBody' => '一部の機能では、オペレーションデータを他のユーザーと共有する場合があります。いつでもオプトアウトできます。',
			'onboarding.consentOperationLabel' => 'オペレーションデータを共有',
			'onboarding.finishingSetup' => 'セットアップを完了しています — 参照データをダウンロード中…',
			'startScreen.credits' => 'KI2Dと仲間たちによる',
			'testerOverlay.tape' => '注意：工事中',
			'testerOverlay.warningTitle' => 'このアプリは開発中です',
			'testerOverlay.warningBody' => 'ほとんどの機能はまだ路面が凸凹で、あちこちに段差があります。定期的にアップデートを確認してください。',
			'testerOverlay.whatsNew' => ({required Object build}) => 'ビルド${build}の新機能',
			'testerOverlay.thanks' => 'このアプリの改善のために、ご自身のログを危険にさらしてくださりありがとうございます！',
			'extensionsPanel.categoryActivity' => 'アクティビティ',
			'extensionsPanel.categoryAward' => 'アワード',
			'extensionsPanel.categoryContest' => 'コンテスト',
			'extensionsPanel.categoryLookup' => 'コールサイン検索',
			'extensionsPanel.categorySpots' => 'スポットソース',
			'extensionsPanel.categoryDashboard' => 'ダッシュボードパネル',
			'extensionsPanel.categoryOther' => 'その他の拡張機能',
			'extensionsPanel.searchHint' => '拡張機能を検索',
			'extensionsPanel.applying' => '拡張機能の変更を適用しています。しばらくお待ちください…',
			'extensionsPanel.noMatches' => '検索に一致する拡張機能はありません',
			'extensionsPanel.installFromFile' => 'ファイルからインストール…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'バージョン ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => 'スクリーンショット ${n}/${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => '前のスクリーンショット',
			'extensionsPanel.nextScreenshot' => '次のスクリーンショット',
			'extensionsPanel.screenshotUnavailable' => 'スクリーンショットを表示できません',
			'extensionsPanel.canReach' => 'この拡張機能がアクセスできるもの',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}（常時接続）',
			'extensionsPanel.canHoldLocalConnection' => 'ローカルネットワーク上のデバイス（常時接続）',
			'extensionsPanel.canUseLocation' => 'あなたの位置情報',
			'extensionsPanel.canReadRadio' => '無線機（周波数とモードの読み取り）',
			'extensionsPanel.canControlRadio' => '無線機（制御と送信：チューニング、出力、CW、ボイスメモリー、PTT）',
			'extensionsPanel.canCommandRadioRaw' => '無線機（固有プロトコルでの任意のコマンド送信。送信や設定変更を行うものも含む）',
			'extensionsPanel.canReadCluster' => 'DXクラスター（あなたとしてログインし、受信内容の読み取り）',
			'extensionsPanel.canSpotCluster' => 'DXクラスター（あなたとしてログインし、あなたの名前でのスポット投稿）',
			'extensionsPanel.canCommandCluster' => 'DXクラスター（あなたとしてログインし、あなたの名前での任意のコマンド送信）',
			'extensionsPanel.canSetUserAgent' => 'サーバーに対して独自の名前を名乗る',
			'extensionsPanel.canChangeSettings' => '設定（コマンドによる変更：あらゆる設定、開発者モード、実験）',
			'extensionsPanel.noCapabilities' => 'アプリ外へのアクセスは一切要求しません。',
			'extensionsPanel.sandboxNote' => '拡張機能はサンドボックス内で動作します。ファイルにはアクセスできず、ここに記載されたもの以外のネットワークにも接続できません。',
			'extensionsPanel.installAction' => 'インストール',
			'extensionsPanel.updateAction' => 'アップデート',
			'extensionsPanel.installFailed' => 'その拡張機能をインストールできませんでした',
			'extensionsPanel.installedBadge' => 'インストール済み',
			'extensionsPanel.uninstallAction' => '削除',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '${name}を削除しますか？',
			'extensionsPanel.uninstallBody' => 'この拡張機能とその設定が削除されます。ログはそのまま残ります。',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name}をインストールしました',
			'extensionsPanel.installDownloading' => 'ダウンロード中…',
			'extensionsPanel.installWaiting' => 'インストール待機中…',
			'extensionsPanel.installInstalling' => 'インストール中…',
			'extensionsPanel.installAwaitingApproval' => '承認を待っています…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name}はすでにインストール中です。',
			'extensionsPanel.updatedTo' => ({required Object version}) => '${version}にアップデートしました',
			'extensionsPanel.installIncomplete' => ({required Object name}) => '${name}のインストールが完了しませんでした。再インストールが必要な場合があります。',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name}を削除できませんでした',
			'extensionsPanel.installedFrom' => ({required Object source}) => '${source}からダウンロード',
			'extensionsPanel.dropHint' => '.h2kext拡張機能をドロップしてインストール',
			'extensionsPanel.dropOneOnly' => '拡張機能は1つずつドロップしてください。',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => 'その拡張機能について${source}が${status}を返しました。',
			'extensionsPanel.downloadTooLarge' => 'そのダウンロードは拡張機能としては大きすぎます。',
			'extensionsPanel.downloadNotSecure' => 'ダウンロードが安全でない場所にリダイレクトされました。',
			'extensionsPanel.catalogSection' => 'カタログ',
			'extensionsPanel.catalogLoading' => 'カタログを読み込み中…',
			'extensionsPanel.catalogUnreachable' => 'カタログに接続できません',
			'extensionsPanel.builtIn' => '内蔵',
			'extensionsPanel.updateAvailableBadge' => 'アップデートあり',
			'extensionsPanel.updatesAvailableTitle' => '拡張機能のアップデート',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => '${name}のアップデートがあります。',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names}と他${count}件のアップデートが必要です。',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names}のアップデートが必要です。',
			'extensionsPanel.pendingUpdatesSection' => '保留中のアップデート',
			'extensionsPanel.updateAllAction' => 'すべてアップデート',
			'extensionsPanel.updatesUnderWay' => 'それらのアップデートはすでに進行中です。',
			'extensionsPanel.updatesNothingLeft' => '拡張機能はすべて最新です。',
			'extensionsPanel.updatesNoticeAction' => '詳細',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の拡張機能をアップデートしますか？', other: '${count}件の拡張機能をアップデートしますか？', ), 
			'extensionsPanel.upgradeDoneTitle' => '拡張機能の準備ができました',
			'extensionsPanel.upgradeDoneBody' => '拡張機能はHam2K拡張機能カタログから提供されるようになったため、アプリの新バージョンを待たずにアップデートできます。',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'アップグレードされなかったもの：${names}。',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => '動作しなかったもの：${names}。',
			'extensionsPanel.upgradeDoneRefusedHint' => 'これらはインストールされたままで、設定 › 拡張機能に印が付いています。そこでアップデートすると復活します。',
			'extensionsPanel.upgradeDoneUnservedHint' => 'カタログにはこれらの直接の後継がありません。使っていた機能をカバーする拡張機能をカタログで探してください。',
			'extensionsPanel.retiredQp' => 'QSOパーティー',
			'extensionsPanel.retiredStateparks' => '州立公園イベント',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count}件の拡張機能がまだ届いていません。次に拡張機能カタログに接続できたときにダウンロードされます。',
			'extensionsPanel.runtimeDeadBody' => '拡張機能が起動しませんでした。アプリを再起動すると復活するはずです。',
			'extensionsPanel.refusedTitle' => '一部の拡張機能が動作しませんでした',
			'extensionsPanel.upgradeBusyTitle' => 'まだセットアップ中です',
			'extensionsPanel.upgradeRuntimeDeadTitle' => '拡張機能が動作していません',
			'extensionsPanel.restoreTitle' => '一部の拡張機能が見つかりません',
			'extensionsPanel.restoreBody' => 'インストールしたこれらの拡張機能がこのデバイスにありません。Ham2K拡張機能カタログから再ダウンロードできます：',
			'extensionsPanel.restoreFromFile' => 'ファイルからインストールしたもの。ファイルから再インストールするか、登録を解除してください：',
			'extensionsPanel.restoreOtherCatalog' => '別の拡張機能カタログからインストールしたため、ここでは利用できません：',
			'extensionsPanel.restoreForget' => '登録解除',
			'extensionsPanel.restoreInstall' => 'インストール',
			'extensionsPanel.restoreLater' => '後で',
			'extensionsPanel.restoreInstalling' => '拡張機能をインストール中…',
			'extensionsPanel.restoreDoneTitle' => '拡張機能が戻りました',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => '再インストールしました：${names}。',
			'extensionsPanel.restorePartialTitle' => '一部の拡張機能をインストールできませんでした',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'インストールできませんでした：${names}。次回アプリを開いたときに再度提案します。',
			'extensionsPanel.restoreBusyBody' => 'アプリは拡張機能をセットアップ中です。次回アプリを開いたときに再度提案します。',
			'extensionsPanel.restoreRuntimeDeadBody' => '再インストールしましたが、拡張機能が起動しませんでした。アプリを再起動すると復活するはずです。',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name}は取り下げられました',
			'extensionsPanel.revokedBody' => 'カタログがこのバージョンを取り下げたため、無効化されました。',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => '${name}は無効化されました',
			'extensionsPanel.forceDisabledBody' => 'Ham2Kがこの拡張機能を当面のあいだ無効化しました。',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name}は置き換えられました',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => '代わりに${replacement}が提供されています。拡張機能画面で切り替えられます。',
			'extensionsPanel.replacedBy' => ({required Object name}) => '${name}に置き換えられました',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => 'すでにお持ちの${name}に置き換えられました',
			'extensionsPanel.replaceAction' => '置き換える',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => '設定はすでにお持ちの${replacement}に引き継がれます。ログはそのまま残ります。',
			'extensionsPanel.downloadHashMismatch' => 'ダウンロードした内容がカタログに記載された拡張機能と一致しません。',
			'extensionsPanel.catalogVersionUnknown' => ({required Object key, required Object version}) => 'カタログに${key}のバージョン${version}はありません。',
			'extensionsPanel.catalogLinkUnknown' => 'そのカタログリンクは拡張機能のバージョンを示していません。',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'カタログにはそのトラックの${key}のリリースがありません。',
			'extensionsPanel.installFromLink' => 'リンクからインストール',
			'extensionsPanel.unstableReleaseWarning' => 'これは不安定版リリースで、公開者がまだ完成としていないものです。誤動作する可能性があり、今後も不安定版のアップデートを受け取ります。',
			'extensionsPanel.bleedingReleaseWarning' => 'これはブリーディングエッジ版リリースです。開発途中のため、壊れたり設定が失われたりする可能性があります。今後もブリーディングエッジ版のアップデートを受け取ります。',
			'extensionsPanel.channelUnstable' => '不安定版',
			'extensionsPanel.channelBleeding' => 'ブリーディング',
			'extensionsPanel.followsUnstable' => '不安定版と安定版のリリースを受け取ります',
			'extensionsPanel.followsBleeding' => 'ブリーディングエッジ版、不安定版、安定版のリリースを受け取ります',
			'extensionsPanel.followStableAction' => '安定版リリースのみ受け取る',
			'extensionsPanel.revokedBadge' => '取り下げ済み',
			'extensionsPanel.forceDisabledBadge' => 'Ham2Kにより無効化',
			'extensionsPanel.refusedBadge' => '読み込み失敗',
			'extensionsPanel.downloadNotHttps' => 'そのダウンロードは安全な接続ではありません。',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'その拡張機能について${source}に接続できませんでした。',
			'extensionsPanel.detailsAction' => '詳細',
			'extensionsPanel.installedFromFile' => 'ファイルからインストール済み',
			'extensionsPanel.detailsWhatItDoes' => '提供する機能',
			'extensionsPanel.installedPreloaded' => 'プリインストール済み',
			'extensionsPanel.hookAccount' => 'アカウントのログイン',
			'extensionsPanel.hookCallNotes' => 'コールサインノート',
			'extensionsPanel.hookDataFile' => 'オフラインデータ',
			'extensionsPanel.hookExport' => 'エクスポート',
			'extensionsPanel.hookLookup' => 'コールサイン検索',
			'extensionsPanel.hookScoring' => 'スコア',
			'extensionsPanel.hookSpots' => 'スポット',
			'extensionsPanel.hookHunting' => ({required Object program}) => '${program}のハンティング',
			'extensionsPanel.hookActivating' => ({required Object program}) => '${program}のアクティベーション',
			'extensionsPanel.suggestedSection' => 'おすすめ',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => '他にも${count}件',
			'home.title' => 'ポータブルロガー',
			'home.newOperation' => '新しいオペレーション',
			'home.stationCallsign' => 'ステーションコールサイン',
			'home.titleOptional' => 'タイトル（任意）',
			'home.emptyList' => 'オペレーションはまだありません。作成してロギングを始めましょう。',
			'home.quickLookup' => 'クイック検索',
			'home.nav.operations' => 'オペレーション',
			'home.nav.chase' => 'チェイス',
			'home.nav.logs' => 'ログ',
			'home.nav.maps' => '地図',
			'home.nav.settings' => '設定',
			'home.panels.operations' => 'オペレーションリスト',
			'home.panels.operationsDescription' => 'あなたのオペレーション（新しい順）。',
			'home.panels.version' => '現在のバージョン',
			'home.panels.versionDescription' => 'Ham2Kのロゴ、アプリ名、実行中のビルド。',
			'home.toggleNav' => 'ナビゲーションラベルの表示/非表示',
			'home.logs.title' => 'ログ',
			'home.logs.titleFor' => 'ログ：',
			'home.logs.emptyCallsigns' => 'まだQSOがありません',
			'home.logs.emptyQsos' => ({required Object call}) => '${call}のQSOはありません',
			'home.logs.mapNoSelection' => 'QSOを選択すると地図に表示されます',
			'home.logs.searchHint' => 'コールサインまたは名前で検索',
			'home.logs.noSearchMatches' => '検索に一致するQSOはありません',
			'home.logs.titleAll' => 'すべてのログ',
			'home.logs.allCallsigns' => 'すべてのコールサイン',
			'home.logs.noOperation' => 'オペレーションに属していません',
			'home.logs.unsavedTitle' => '未保存の変更',
			'home.logs.unsavedBody' => 'このQSOには保存されていない変更があります。',
			'home.logs.pendingDeleteBody' => 'このQSOは削除予定です。',
			'home.logs.editGone' => '保存されませんでした：そのQSOはもうこのログにありません。',
			'home.logs.discard' => '破棄',
			'home.logs.sheet.callsigns' => 'ステーションコールサイン',
			'home.logs.sheet.groupBy' => 'グループ化',
			'home.logs.sheet.period' => '期間',
			'home.logs.groupBy.none' => 'グループ化なし',
			'home.logs.groupBy.date' => '日付',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => '不明な大陸',
			'home.logs.groupBy.unknownEntity' => '不明なエンティティ',
			'home.logs.groupBy.unknownDate' => '日付なし',
			'home.logs.period.thisMonth' => '今月',
			'home.logs.period.last3Months' => '過去3か月',
			'home.logs.period.thisYear' => '今年',
			'home.logs.period.lastYear' => '昨年',
			'home.logs.period.allTime' => '全期間',
			'home.logs.period.custom' => 'カスタム範囲',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => '（${span}）',
			'home.logs.periodTitle.custom' => 'カスタム範囲',
			'home.logs.columns.date' => '日付',
			'home.logs.columns.time' => '時刻',
			'home.logs.columns.freq' => '周波数',
			'home.logs.columns.mode' => 'モード',
			'home.logs.columns.call' => 'コール',
			'home.logs.columns.name' => '名前',
			'home.logs.columns.station' => '局',
			'home.logs.columns.band' => 'バンド',
			'home.logs.columns.sent' => '送信',
			'home.logs.columns.rcvd' => '受信',
			'home.logs.columns.grid' => 'グリッド',
			'home.logs.columns.state' => '州',
			'home.logs.columns.country' => '国',
			'home.logs.columns.refs' => 'リファレンス',
			'home.logs.panels.qsos' => 'QSOログ',
			'home.logs.panels.qsosDescription' => '選択したコールサインの全オペレーションにわたるQSO。',
			'home.logs.panels.info' => '情報',
			'home.logs.panels.infoDescription' => 'QSOの総数、または選択したQSOのコールサイン検索結果。',
			'home.logs.panels.map' => '地図',
			'home.logs.panels.mapDescription' => '選択したQSOの位置。',
			'home.logs.import.callsigns' => ({required Object calls}) => 'コールサイン：${calls}',
			'home.logs.import.skippedOne' => '1件のレコードを読み取れませんでした',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count}件のレコードを読み取れませんでした',
			'home.logs.import.readingTitle' => 'ADIFファイルを読み込み中…',
			'home.logs.import.checkingTitle' => '重複を確認中…',
			'home.logs.import.importingTitle' => 'QSOをインポート中…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object total, required Object done}) => '${total}件中${done}件を確認済み',
			'home.logs.import.importingDetail' => ({required Object total, required Object imported}) => '${total}件中${imported}件をインポート済み',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'チェイス中',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first}と${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}、${second}など',
			'chase.station.title' => 'チェイス局',
			'chase.station.stationLabel' => '局：',
			'chase.station.operatorLabel' => 'Op：',
			'chase.station.noLocation' => '位置なし',
			'chase.periodInline.today' => '今日',
			'chase.periodInline.thisWeek' => '今週',
			'chase.periodInline.last14Days' => '過去14日間',
			'chase.periodInline.thisMonth' => '今月',
			'chase.periodStats.today' => '今日の統計',
			'chase.periodStats.thisWeek' => '今週の統計',
			'chase.periodStats.last14Days' => '過去14日間の統計',
			'chase.periodStats.thisMonth' => '今月の統計',
			'chase.period.today' => '今日',
			'chase.period.thisWeek' => '今週',
			'chase.period.last14Days' => '過去14日間',
			'chase.period.thisMonth' => '今月',
			'chase.goals.title' => 'チェイス目標',
			'chase.goals.remove' => ({required Object name}) => '${name}のチェイスをやめる',
			'chase.goals.extensionsTitle' => 'その他のチェイスプログラム',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => '期間内にチェイスしたQSOの上にあるロギング操作。',
			'chase.panels.info' => '情報',
			'chase.panels.infoDescription' => 'ロギング中のコールサイン、または期間の統計。',
			'chase.panels.spots' => 'スポット',
			'chase.panels.spotsDescription' => 'オンエア中にスポットされた、チェイスできる局。',
			'chase.panels.map' => '地図',
			'chase.panels.mapDescription' => '期間内のQSOとロギング中の局。',
			'chase.claims.checking' => 'チェイス対象のQSOを確認中',
			'chase.claims.rebuilding' => ({required Object program}) => '${program}のログを確認中',
			'chase.claims.progress' => ({required Object total, required Object done}) => '${total}件中${done}件のQSO',
			'chase.notice.newRef' => ({required Object program}) => '新しい${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => 'おそらく新しい${program}',
			'chase.notice.newBand' => ({required Object program}) => '新しい${program}バンド',
			'chase.notice.newBandGuess' => ({required Object program}) => 'おそらく新しい${program}バンド',
			'chase.notice.newMode' => ({required Object program}) => '新しい${program}モード',
			'chase.notice.newModeGuess' => ({required Object program}) => 'おそらく新しい${program}モード',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program}未確認',
			'chase.notice.programGuess' => ({required Object notice}) => 'おそらく${notice}',
			'chase.alerts.title' => 'アラート',
			'chase.alerts.newRef' => '新しいリファレンス',
			'chase.alerts.newBand' => '新しいバンド',
			'chase.alerts.newMode' => '新しいモード',
			'chase.alerts.unconfirmed' => '未確認',
			'chase.checklists' => 'チェイスの進捗',
			'chase.imports.importFrom' => ({required Object label}) => '${label}をインポート',
			'chase.imports.pickTitle' => ({required Object file}) => '${file}のインポート先',
			'chase.imports.dropHint' => 'ファイルをドロップしてチェイスプログラムにインポート',
			'chase.imports.done' => ({required Object file, required Object program, required Object count}) => '${file}から${program}のエントリー${count}件をインポートしました',
			'chase.imports.doneSkipped' => ({required Object file, required Object program, required Object count, required Object skipped}) => '${file}から${program}のエントリー${count}件をインポートしました。読み取れなかった${skipped}件はスキップしました',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file}には${program}がインポートできるものがありません',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program}は${file}を読み取れませんでした',
			'chase.imports.unreadable' => ({required Object program, required Object file, required Object skipped}) => '${program}は${file}の${skipped}件のレコードをどれも読み取れませんでした',
			'chase.imports.noProgram' => ({required Object file}) => '${file}をインポートできるチェイスプログラムはありません',
			'dialogs.operationDetails' => 'オペレーション詳細',
			'dialogs.activities' => 'アクティビティ',
			'dialogs.stationCallsign' => 'ステーションコールサイン',
			'dialogs.advanced' => '詳細設定',
			'dialogs.operatingPosition' => '運用ポジション（マルチステーション）',
			'dialogs.assistance' => 'アシスタンス',
			'dialogs.assistanceDescription' => 'スポットサービスなどの情報源を利用する',
			'dialogs.selfSpotting' => 'セルフスポッティング',
			'dialogs.selfSpottingDescription' => '自局の周波数情報を報告する機能を許可する',
			'dialogs.disabledByRules' => ({required Object rules}) => '${rules}のルールに従うため無効',
			'dialogs.lookupDespiteAssistance.title' => 'オンラインで検索しますか？',
			'dialogs.lookupDespiteAssistance.body' => 'このオペレーションではアシスタンスが無効です。すべてのQSOを検索すると、今回に限りQRZなどのオンラインサービスを使用します。',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => 'このオペレーションでは${rules}のルールに従うためアシスタンスが無効です。すべてのQSOを検索すると、今回に限りQRZなどのオンラインサービスを使用します。',
			'dialogs.lookupDespiteAssistance.action' => 'オンラインで検索',
			'dialogs.notes' => 'メモ',
			'dialogs.deleteOperationTitle' => 'オペレーションを削除',
			'dialogs.purgeTestsTitle' => 'テストオペレーションを完全削除',
			'dialogs.purgeTestsBody' => 'これらのテストオペレーションとそのQSOを完全に削除します。元に戻せません。',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'さらに、どのオペレーションにも属さないテストコンタクト${count}件。', other: 'さらに、どのオペレーションにも属さないテストコンタクト${count}件。', ), 
			'dialogs.purgeTestsAction' => '完全削除',
			'dialogs.syncAllTitle' => 'このデバイスのログを置き換えますか？',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALLはこのデバイスの${qsos}をバックアップしてから消去し、アカウントのログをサーバーから再ダウンロードします。バックアップはこのデバイスのデータベースに残ります。',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${n}件のQSOはまだ同期されていません。サーバーには届いていないため、復元されません。', other: '${n}件のQSOはまだ同期されていません。サーバーには届いていないため、復元されません。', ), 
			'dialogs.syncAllAction' => '消去して再同期',
			'dialogs.receivedPurgesTitle' => '他のデバイスで削除されたテストオペレーション',
			'dialogs.receivedPurgesBody' => 'これらは別のデバイスでテストオペレーションとして削除されました。ここでも削除しますか？これらとそのQSOは完全に削除され、元に戻せません。',
			'dialogs.receivedPurgesAction' => '削除',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => '無効なコールサイン：${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => '無効なコールサイン：${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => 'これまでは${previous}が運用しました。新しいコンタクトには${typed}が記録されます。',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'これまでオペレーターは記録されていません。新しいコンタクトには${typed}が記録されます。',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'このオペレーションにはすでに${calls}によるコンタクトがあります。${typed}は新しいコンタクトにのみ記録されます。',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '記録済みのコンタクトのオペレーターにも${typed}を記録する', other: '記録済みの${count}件すべてのコンタクトのオペレーターにも${typed}を記録する', ), 
			'dialogs.callChange.operatorSeveralStations' => '複数のステーションコールサインで運用する場合、オペレーターを個別に設定できません',
			'dialogs.callChange.contactsUnreadable' => 'このオペレーションのコンタクトを読み取れなかったため、ここでコールサインを変更しても更新は提案されません',
			'dialogs.callChange.restampFailed' => ({required Object error}) => '記録済みのコンタクトを更新できなかったため、変更は行われませんでした：${error}',
			'dialogs.callChange.restampShortfall' => ({required Object planned, required Object written}) => '${planned}件中${written}件のコンタクトを更新しました。残りはもうこのオペレーションにありません',
			'operation.deletedReadOnly' => 'このオペレーションは削除されています。ロギングや変更を行うには復元してください。',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => '情報',
			'operation.tabs.spots' => 'スポット',
			'operation.tabs.map' => '地図',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => '時計',
			'operation.tabs.weather' => '天気',
			'operation.tabs.website' => 'Webサイト',
			'operation.tabs.remoteScreen' => 'リモート画面',
			'operation.tabs.solar' => '太陽活動',
			'operation.tabs.radio' => '無線機',
			'operation.tabs.rotator' => 'ローテーター',
			'operation.tabs.summaries' => 'オペレーション概要',
			'operation.positions.nobodyYet' => 'このオペレーションを共有している他の運用ポジションはまだありません。',
			'operation.positions.positionLabel' => ({required Object number}) => 'ポジション：${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op：${call}',
			'operation.positions.unnamedPosition' => '別のポジション',
			'operation.positions.thisDevice' => '自分の運用ポジション',
			'operation.positions.nameIn' => '：',
			'operation.positions.panelTitle' => 'ポジション',
			'operation.positions.panelDescription' => 'このオペレーションを共有している各運用ポジションが現在ロギング中の内容。',
			'operation.stationCallsignNone' => 'ステーションコールサインなし',
			'operation.titleNone' => 'タイトルなし',
			'operation.deleteOperation' => 'オペレーションを削除',
			'operation.loggingControlsStale' => 'アクティビティのフィールドが古い可能性があります。オペレーションを開き直して更新してください',
			'operation.locationNone' => '未設定',
			'operation.generalOperation' => 'ジェネラルオペレーション',
			'operation.titleFor' => ({required Object value}) => '${value}向け',
			'operation.titleAt' => ({required Object value}) => '${value}にて',
			'operation.segmentNow' => ({required Object description}) => '現在 ${description}',
			'operation.testOperationSuffix' => 'テスト',
			'operation.menu.showRstFields' => 'RSTフィールドを表示',
			'operation.menu.showStateField' => '州フィールドを表示',
			'operation.menu.showGridField' => 'グリッドフィールドを表示',
			'operation.menu.showDeletedQsos' => '削除したQSOを表示',
			'operation.menu.showDeletedOps' => '削除したオペレーションを表示',
			'operation.menu.showQsoNumbers' => 'QSO番号を表示',
			'operation.menu.lookupAllQsos' => 'すべてのQSOを検索',
			'operation.menu.loggingSettingsTitle' => 'ロギング設定',
			'operation.menu.mapSettingsTitle' => '地図設定',
			'operation.menu.actionsSection' => 'アクション',
			'operation.layout.title' => 'パネルを追加',
			'operation.layout.availableSection' => '利用可能なパネル',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel}の設定',
			'operation.layout.panelSettingsAction' => 'パネル設定',
			'operation.layout.viewName' => 'オペレーションビュー',
			'operation.layout.viewOptions' => 'ビューのレイアウトオプション',
			'operation.layout.viewTitleBuiltIn' => 'このビューはアプリに組み込まれており、名前も固定です',
			'operation.layout.resetOptions' => 'デフォルトに戻す',
			'operation.layout.removePane' => '削除',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '${panel}をデフォルトに戻しますか？',
			'operation.layout.resetPaneConfirmBody' => 'タイトル、ヘッダー、サイズがデフォルトに戻ります。レイアウトの他の部分はそのままです。',
			'operation.layout.resetViewConfirm' => 'このビューをデフォルトのレイアウトに戻しますか？',
			'operation.layout.resetViewConfirmBody' => 'パネルはデフォルトの配置に戻り、ビューと各パネルのオプションもデフォルトに戻ります。',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel}のレイアウト設定',
			'operation.layout.paneTitle' => 'タイトル',
			'operation.layout.paneShowHeader' => 'ヘッダーを表示',
			'operation.layout.paneShowHeaderTabset' => 'このペインがグループを共有している間は常に表示されます。ヘッダーから他のペインに切り替えるためです',
			'operation.layout.paneInherit' => 'アプリと同じ',
			'operation.layout.searchHint' => 'パネルを検索',
			'operation.layout.noPanelsMatch' => '検索に一致するパネルはありません。',
			'operation.layout.nothingToAdd' => 'このビューにはすでにすべてのパネルがあります',
			'operation.layout.addPanel' => ({required Object panel}) => '${panel}を追加',
			'operation.layout.showPreview' => ({required Object panel}) => '${panel}をプレビュー',
			'operation.layout.missingExtension' => ({required Object name}) => '拡張機能「${name}」が見つかりません',
			'operation.layout.missingExtensionEnable' => '有効にする',
			'operation.layout.missingExtensionInstall' => 'インストール…',
			'operation.layout.missingExtensionWontRun' => 'このバージョンは動作しません。設定 › 拡張機能でアップデートしてください。',
			'operation.layout.missingExtensionUnavailable' => 'このアプリでは利用できません',
			'operation.layout.missingExtensionNotInCatalog' => 'カタログにありません',
			'operation.layout.missingExtensionCatalogUnreachable' => 'カタログに接続できませんでした。再試行',
			'operation.layout.missingExtensionFailed' => 'うまくいきませんでした。再試行',
			'operation.layout.previewUnavailable' => 'このパネルのプレビュー画像を表示できませんでした。',
			'operation.layout.nestedPaneTitle' => 'その他',
			'operation.layout.layouts.defaultName' => 'デフォルト',
			'operation.layout.layouts.untitledName' => ({required Object number}) => 'レイアウト${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => 'レイアウト：${name}',
			'operation.layout.layouts.menuNew' => '新規…',
			'operation.layout.layouts.menuExport' => 'エクスポート…',
			'operation.layout.layouts.menuImport' => 'インポート…',
			'operation.layout.layouts.menuTitle' => 'レイアウト',
			'operation.layout.layouts.newTitle' => '新しいレイアウト',
			'operation.layout.layouts.editTitle' => 'レイアウトを編集',
			'operation.layout.layouts.edit' => '編集',
			'operation.layout.layouts.duplicateCurrent' => '現在のレイアウトを複製',
			'operation.layout.layouts.startFromDefault' => 'デフォルトのレイアウトから始める',
			'operation.layout.layouts.nameLabel' => '名前',
			'operation.layout.layouts.descriptionLabel' => '説明',
			'operation.layout.layouts.create' => '作成',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => '「${name}」の変更を保存しますか？',
			'operation.layout.layouts.leaveEditBody' => 'このレイアウトには保存されていない変更があります。',
			'operation.layout.layouts.discard' => '破棄',
			'operation.layout.layouts.deleteTitle' => 'このレイアウトを削除しますか？',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => 'レイアウト「${name}」を本当に削除しますか？',
			'operation.layout.layouts.exportTitle' => 'レイアウトをエクスポート',
			'operation.layout.layouts.exportPick' => 'エクスポートするパネル',
			'operation.layout.layouts.tabSet' => 'タブセット',
			'operation.layout.layouts.exportAction' => 'エクスポート',
			'operation.layout.layouts.exported' => ({required Object location}) => 'レイアウトを${location}に保存しました',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => 'レイアウトをエクスポートできませんでした：${error}',
			'operation.layout.layouts.importTitle' => 'レイアウトをインポート',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => '${view}ビュー用に作られたものです。そのビューにしかないパネルは除外されます。',
			'operation.layout.layouts.viewHome' => 'ホーム',
			'operation.layout.layouts.viewOperation' => 'オペレーション',
			'operation.layout.layouts.viewLogs' => 'ログ',
			'operation.layout.layouts.viewChase' => 'チェイス',
			'operation.layout.layouts.importAsNew' => '新しいレイアウトとして',
			'operation.layout.layouts.importReplace' => 'このレイアウトと置き換え',
			'operation.layout.layouts.importAdd' => 'このレイアウトに追加',
			'operation.layout.layouts.importAddHint' => 'パネルは右側の新しい列に追加されます。',
			'operation.layout.layouts.importPick' => 'インポートするパネル',
			'operation.layout.layouts.importReplaceSettings' => 'ここで設定済みのパネルの設定を置き換える',
			'operation.layout.layouts.importAction' => 'インポート',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename}はこのアプリで読めるレイアウトではありません：${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => 'テキストが有効なYAMLではありません（${line}行目）',
			'operation.layout.layouts.problemNotLayoutFile' => 'Ham2Kのレイアウトファイルではありません',
			'operation.layout.layouts.problemNewerVersion' => '新しいバージョンのアプリで書き出されたものです',
			'operation.layout.layouts.problemNoArrangement' => '配置が含まれていません',
			'operation.layout.layouts.problemMalformed' => '一部がレイアウト形式に従っていません',
			'operation.layout.layouts.problemTooLarge' => '大きすぎます',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => 'ファイルを開けませんでした：${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => 'レイアウトをインポートできませんでした：${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => 'レイアウトをコピーできませんでした：${error}',
			'operation.layout.layouts.importNothing' => 'パネルが選択されていないため、何もインポートされませんでした。',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => '除外：${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => '${panels}は残しました：小画面の配置に欠かせないためです。',
			'operation.layout.layouts.notOffered' => 'このビューでは利用できません',
			'operation.layout.layouts.alreadyPlaced' => 'すでにこのレイアウトにあります',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => '${name}が必要',
			'operation.layout.layouts.listRecoveredTitle' => 'レイアウト名を読み込めませんでした',
			'operation.layout.layouts.listRecoveredBody' => 'このビューのレイアウト一覧を読み込めませんでした。レイアウト自体はすべて残っており、名前の代わりに番号が付いています。',
			'operation.layout.editLayout' => 'レイアウトを編集',
			'operation.layout.saveLayout' => 'レイアウトを保存',
			'operation.layout.revertLayout' => 'レイアウトの変更を破棄',
			'operation.layout.done' => '完了',
			'operation.layout.layoutUnreadableTitle' => 'レイアウトを読み込めませんでした',
			'operation.layout.layoutUnreadableBody' => '保存したレイアウトを読み込めなかったため、デフォルトの配置を表示しています。保持を選ぶまで元のレイアウトは上書きされません。',
			'operation.layout.layoutUnreadableAction' => 'このレイアウトを使用',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel}を表示できませんでした',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：${max}文字を超える内容が送られました',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：アートワークの要素が${max}個を超えています',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：アートワークのネストが${max}階層を超えています',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => '${panel}を表示できませんでした：アートワークが自己完結していません',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンのレイヤーが${max}個を超えています',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンのコントロールが${max}個を超えています',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンの一部のエントリーが${max}個を超えています',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：シーンの文字列が${max}文字を超えています',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => '${panel}を表示できませんでした：レイアウトのネストが${max}階層を超えています',
			'operation.layout.panelRenderRetry' => '再試行',
			'operation.layout.panelActionFailed' => 'パネルの操作に失敗しました。再試行してください。',
			'operation.layout.panels.loggingDescription' => 'ログと入力フィールド',
			'operation.layout.panels.infoDescription' => '交信中の局について分かっている情報',
			'operation.layout.panels.spotsDescription' => 'クラスターとアクティビティプログラムからのスポット',
			'operation.layout.panels.mapDescription' => 'コンタクトの位置',
			'operation.layout.panels.summariesDescription' => 'オペレーションの統計とスコアを、選んだセクションと順序で表示',
			'operation.layout.panels.summariesSections' => 'セクションと順序',
			'operation.layout.panels.summariesDays' => '日ごと',
			'operation.layout.panels.summariesReset' => 'すべて表示',
			'operation.layout.panels.summariesAllHidden' => 'すべてのセクションが非表示です。このパネルの設定で表示するものを選んでください。',
			'operation.layout.panels.clockDescription' => '任意のタイムゾーンの時計',
			'operation.layout.panels.clockFace' => '文字盤',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'アナログ',
			'operation.layout.panels.clockZone' => 'タイムゾーン',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'このデバイス',
			'operation.layout.panels.clockShowSeconds' => '秒を表示',
			'operation.layout.panels.weatherDescription' => '運用地の現在と今後8時間の天気',
			'operation.layout.panels.weatherUseOperationLocation' => 'オペレーションの場所を使用',
			'operation.layout.panels.weatherLocation' => '場所',
			'operation.layout.panels.weatherLocationDescription' => 'グリッドスクエア（FN31pr）または緯度,経度。「オペレーションの場所を使用」がオンの間は無視されます。',
			'operation.layout.panels.weatherNoLocation' => '場所が設定されていません。このパネルの設定で場所を指定するか、場所が設定されたオペレーション内に配置してください。',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => '場所${location}を読み取れませんでした。FN31prのようなグリッドスクエア、または42.36,-71.06の形式で入力してください。',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteoに接続できませんでした。ネットワークがない可能性があります。まもなく再試行します。',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteoは応答しましたが、読み取れる内容ではありませんでした。まもなく再試行します。',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => '突風 ${speed}',
			'operation.layout.panels.panelAgeNow' => 'たった今',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}分前', other: '${count}分前', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}時間前', other: '${count}時間前', ), 
			'operation.layout.panels.weatherConditions.unknown' => '不明',
			'operation.layout.panels.weatherConditions.sunny' => '晴れ',
			'operation.layout.panels.weatherConditions.clear' => '快晴',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'おおむね晴れ',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'おおむね快晴',
			'operation.layout.panels.weatherConditions.partlyCloudy' => '晴れ時々曇り',
			'operation.layout.panels.weatherConditions.cloudy' => '曇り',
			'operation.layout.panels.weatherConditions.foggy' => '霧',
			'operation.layout.panels.weatherConditions.rimeFog' => '着氷性の霧',
			'operation.layout.panels.weatherConditions.lightDrizzle' => '弱い霧雨',
			'operation.layout.panels.weatherConditions.drizzle' => '霧雨',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => '強い霧雨',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => '弱い着氷性の霧雨',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => '着氷性の霧雨',
			'operation.layout.panels.weatherConditions.lightRain' => '弱い雨',
			'operation.layout.panels.weatherConditions.rain' => '雨',
			'operation.layout.panels.weatherConditions.heavyRain' => '強い雨',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => '弱い着氷性の雨',
			'operation.layout.panels.weatherConditions.freezingRain' => '着氷性の雨',
			'operation.layout.panels.weatherConditions.lightSnow' => '弱い雪',
			'operation.layout.panels.weatherConditions.snow' => '雪',
			'operation.layout.panels.weatherConditions.heavySnow' => '大雪',
			'operation.layout.panels.weatherConditions.snowGrains' => '霧雪',
			'operation.layout.panels.weatherConditions.lightShowers' => '弱いにわか雨',
			'operation.layout.panels.weatherConditions.showers' => 'にわか雨',
			'operation.layout.panels.weatherConditions.heavyShowers' => '強いにわか雨',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => '弱いにわか雪',
			'operation.layout.panels.weatherConditions.snowShowers' => 'にわか雪',
			'operation.layout.panels.weatherConditions.thunderstorm' => '雷雨',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'ひょうを伴う弱い雷雨',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'ひょうを伴う雷雨',
			'operation.layout.panels.websiteDescription' => '任意のWebページをペインに表示',
			'operation.layout.panels.websiteUrl' => 'アドレス',
			'operation.layout.panels.websiteRefresh' => '更新',
			'operation.layout.panels.websiteRefreshNever' => 'しない',
			'operation.layout.panels.websiteRefresh1' => '1分ごと',
			'operation.layout.panels.websiteRefresh5' => '5分ごと',
			'operation.layout.panels.websiteRefresh15' => '15分ごと',
			'operation.layout.panels.websiteTitle' => 'パネル名',
			'operation.layout.panels.websiteRefreshNow' => '今すぐ更新',
			'operation.layout.panels.websiteNoUrl' => 'アドレスがまだありません。このパネルの設定を開いてページを選んでください。',
			'operation.layout.panels.websiteBadUrl' => 'Webアドレスではないようです。https:// で始まる必要があります',
			'operation.layout.panels.websiteNotHttps' => 'ここに表示できるのはhttps:// のアドレスのみです。',
			'operation.layout.panels.websiteUnsupported' => 'このシステムではパネルにWebページを表示できません。',
			'operation.layout.panels.websiteOpenExternally' => 'ブラウザで開く',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'ページを読み込めませんでした：${reason}',
			'operation.layout.panels.remoteScreenDescription' => '他のデバイスが共有している画面、アプリ、ウィンドウ。',
			'operation.layout.panels.remoteScreenTarget' => '画面',
			'operation.layout.panels.remoteScreenChoose' => '画面を選択…',
			'operation.layout.panels.remoteScreenPickerTitle' => '共有画面',
			'operation.layout.panels.remoteScreenPickerEmpty' => '画面を共有しているデバイスはありません。表示したいデバイスで、設定 → ピアデバイスの「画面とウィンドウを共有」をオンにしてください。',
			'operation.layout.panels.remoteScreenUnset' => '画面が選択されていません。このパネルの設定を開き、他のデバイスが共有している画面を選んでください。',
			'operation.layout.panels.remoteScreenConnecting' => '接続中…',
			'operation.layout.panels.remoteScreenPeerAway' => 'そのデバイスは現在接続されていません。',
			'operation.layout.panels.remoteScreenNotOffered' => 'そのデバイスはこの画面の共有を停止しました。',
			'operation.layout.panels.remoteScreenNoListener' => 'そのデバイスは接続を受け付けられません。ファイアウォールを確認してください。',
			'operation.layout.panels.remoteScreenNoLan' => '画面はローカルネットワーク経由でのみ共有され、Bluetoothでは共有されません。',
			'operation.layout.panels.remoteScreenRefused' => 'そのデバイスはこの画面の共有を拒否しました。',
			'operation.layout.panels.remoteScreenSettings' => 'パネル設定',
			'operation.layout.panels.remoteScreenAdjust' => '表示を調整',
			'operation.layout.panels.remoteScreenDetail' => '詳細度',
			'operation.layout.panels.remoteScreenDetailStandard' => '標準',
			'operation.layout.panels.remoteScreenDetailHigh' => '高',
			'operation.layout.panels.remoteScreenDetailMaximum' => '最大',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => '拡大',
			'operation.layout.panels.remoteScreenZoomOut' => '縮小',
			'operation.layout.panels.remoteScreenStopped' => 'その画面またはウィンドウはもう表示されていません。',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'そのデバイスは画面をキャプチャできませんでした。画面収録の許可が必要な場合があります。',
			'operation.layout.panels.remoteScreenNoAnswer' => 'そのデバイスは応答しませんでした。画面共有がオンになっていない可能性があります。',
			'operation.layout.panels.remoteScreenNoMedia' => '映像用の接続を開けませんでした。このデバイスのファイアウォールを確認してください。',
			'operation.layout.panels.solarDescription' => '太陽と地磁気の状況、バンドごとの伝搬',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.comに接続できませんでした。ネットワークがない可能性があります。まもなく再試行します。',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.comは応答しましたが、使用できるデータではありませんでした。まもなく再試行します。',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => '昼',
			'operation.layout.panels.solarBandNight' => '夜',
			'operation.layout.panels.solarBandGood' => '良好',
			'operation.layout.panels.solarBandFair' => '普通',
			'operation.layout.panels.solarBandPoor' => '不良',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => '出典：${primary}、${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => '接続が不安定です。フレームをスキップしています。',
			'operation.layout.panels.remoteScreenStalled' => 'フレームが届かなくなりました。この接続は遅すぎる可能性があります。',
			'operation.layout.panels.radioDescription' => '無線機のフロントパネル（周波数、モード、出力をCATで制御）',
			'operation.layout.panels.radioStyle' => 'スタイル',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'モダン',
			'operation.layout.panels.radioRadio' => '無線機',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — 無線機が指定されていません',
			'operation.layout.panels.radioNoRadio' => '表示する無線機がありません。このパネルの設定で選ぶか、ステーション構成で追加してください。',
			'operation.layout.panels.radioNotConfigured' => 'この無線機はまだ設定されていません。ステーション構成でポートまたはアドレスを選んでください。',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => '無線機が接続されていません',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'この無線機を接続',
			'operation.layout.panels.radioDisconnect' => 'この無線機を切断',
			'operation.layout.panels.radioStale' => 'データなし',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR高',
			'operation.layout.panels.rotatorDescription' => 'アンテナの向きを、局を中心にした地図上に表示します。地図をタップすると回転します。',
			'operation.layout.panels.rotatorRotator' => 'ローテーター',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => '自動 — ${name}',
			'operation.layout.panels.rotatorAutoNone' => '自動 — ローテーターはまだありません',
			'operation.layout.panels.rotatorBeamWidth' => 'ビーム幅',
			'operation.layout.panels.rotatorBeamWidthDescription' => '方位の周りに描く角度（度）。0なら描画しません。',
			'operation.layout.panels.rotatorLocation' => '場所',
			'operation.layout.panels.rotatorLocationDescription' => '地図の中心にするグリッドスクエアまたは緯度経度。空欄ならオペレーションの場所を使います。',
			'operation.layout.panels.rotatorTheme' => 'テーマ',
			'operation.layout.panels.rotatorThemeColor' => 'カラー',
			'operation.layout.panels.rotatorThemeGray' => 'グレー',
			'operation.layout.panels.rotatorThemeMuted' => '淡色',
			'operation.layout.panels.rotatorGrayline' => 'グレイラインを表示',
			'operation.layout.panels.rotatorNoRotator' => '表示するローテーターがありません。このパネルの設定で選ぶか、ステーション構成で追加してください。',
			'operation.layout.panels.rotatorNoLocation' => '地図の中心にする場所がありません。このパネルの設定で指定してください。',
			'operation.layout.panels.rotatorDisconnected' => '未接続',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => '応答なし',
			'operation.layout.panels.rotatorLocationInvalid' => 'このパネルの設定の場所を読み取れません。グリッドスクエアか、40.7, -74.0 のような緯度経度を使ってください。',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => '仰角${degrees}°',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'W',
			'operation.layout.htmlPanelUnsupported' => 'このパネルにはWebビューが必要ですが、このプラットフォームでは提供されていません',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'このパネルにはWeb版では提供できないサンドボックスが必要です',
			'operation.export.title' => 'オペレーションのエクスポート',
			'operation.export.syncedOperation' => 'オペレーションは同期済みです',
			'operation.export.unsyncedOperation' => 'オペレーションに未同期の変更があります',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'このオペレーションのQSO：${count}件', other: 'このオペレーションのQSO：${count}件', ), 
			'operation.export.qsosSynced' => ({required Object total}) => '${total}件のQSOすべてが同期済み',
			'operation.export.qsosPending' => ({required Object total, required Object pending}) => '${total}件中${pending}件のQSOが同期待ち',
			'operation.export.eventsSynced' => ({required Object total}) => '${total}件のイベントマーカーが同期済み',
			'operation.export.eventsPending' => ({required Object total, required Object pending}) => '${total}件中${pending}件のイベントマーカーが保留中',
			'operation.export.loading' => 'エクスポートオプションを読み込み中…',
			'operation.export.noOptions' => '利用できるエクスポート形式がありません（拡張機能ランタイムがまだ起動中？）',
			'operation.export.nothingLogged' => 'エクスポートするものはまだありません。このオペレーションにはQSOがありません。',
			'operation.export.share' => '共有',
			'operation.export.nothingSelected' => '何も選択されていません',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルを保存', other: '${count}件のファイルを保存', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルを共有', other: '${count}件のファイルを共有', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをエクスポート', other: '${count}件のファイルをエクスポート', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをダウンロード', other: '${count}件のファイルをダウンロード', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の結合ファイルを保存', other: '${count}件の結合ファイルを保存', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の結合ファイルを共有', other: '${count}件の結合ファイルを共有', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の結合ファイルをエクスポート', other: '${count}件の結合ファイルをエクスポート', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の結合ファイルをダウンロード', other: '${count}件の結合ファイルをダウンロード', ), 
			'operation.export.saveOne' => ({required Object name}) => '${name}を保存',
			'operation.export.shareOne' => ({required Object name}) => '${name}を共有',
			'operation.export.exportOne' => ({required Object name}) => '${name}をエクスポート',
			'operation.export.downloadOne' => ({required Object name}) => '${name}をダウンロード',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをスタッシュ', other: '${count}件のファイルをスタッシュ', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の結合ファイルをスタッシュ', other: '${count}件の結合ファイルをスタッシュ', ), 
			'operation.export.settingsButton' => 'エクスポート設定',
			'operation.export.settingsTitle' => 'エクスポート設定',
			'operation.export.compactFileNames.title' => 'コンパクトファイル名を使用',
			'operation.export.compactFileNames.descriptionOn' => 'アップロード用の短い名前（例：N0CALL@US-1234-20260727.adi）',
			'operation.export.compactFileNames.descriptionOff' => '読みやすい名前（例：2026-07-27 N0CALL at US-1234.adi）',
			'operation.export.includePrivateData.title' => '個人情報を含める',
			'operation.export.includePrivateData.descriptionOn' => '名前、住所、メール、グリッドスクエア、メモを含めます',
			'operation.export.includePrivateData.descriptionOff' => '名前、住所、メール、グリッドスクエア、メモを除外します',
			'operation.export.includePrivateData.note' => 'Full ADIF Exportには常にすべてが含まれます',
			'operation.export.resultTitle' => 'エクスポート完了',
			'operation.export.resultFailedTitle' => 'エクスポート失敗',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルを${path}にエクスポートしました', other: '${count}件のファイルを${path}にエクスポートしました', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをエクスポートしました：${path}', other: '${count}件のファイルをエクスポートしました：${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルを共有しました', other: '${count}件のファイルを共有しました', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをダウンロードしました', other: '${count}件のファイルをダウンロードしました', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'エクスポート失敗：${error}',
			'operation.export.stash.needsEmailTitle' => '先にメールアドレスを追加してください',
			'operation.export.stash.needsEmailBody' => 'Ham2K File StashはLoFiアカウントのメールアドレスにファイルを送信し、stash.ham2k.netへのログインにもそのアドレスを使います。あなたのアカウントにはまだ確認済みのメールアドレスがありません。設定 › クラウド同期で追加してください。',
			'operation.export.stash.openSyncSettings' => 'クラウド同期を開く',
			'operation.export.stash.replaceTitle' => '最近のスタッシュが置き換えられます',
			'operation.export.stash.replaceBody' => ({required Object name}) => '6時間以内に「${name}」を送信しましたが、まだダウンロードされていません。無料アカウントで保持できるスタッシュは一度に1つだけのため、今送信すると置き換えられます。',
			'operation.export.stash.replaceConfirm' => 'それでも送信',
			'operation.export.stash.failedTitle' => 'Ham2K File Stashに送信できませんでした',
			'operation.export.stash.sentTitle' => 'Ham2K File Stashに送信しました',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'このファイルは、任意のブラウザで **[stash.ham2k.net](https://stash.ham2k.net)** にアクセスして取得できます。', other: 'これらのファイルは、任意のブラウザで **[stash.ham2k.net](https://stash.ham2k.net)** にアクセスして取得できます。', ), 
			'operation.export.stash.mayHaveArrived' => 'スタッシュから応答がありません。ファイルは届いている可能性があります。再送信する前にstash.ham2k.netを確認してください',
			'operation.export.stash.notSent' => '未送信',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'このファイルは届きませんでした：', other: 'これら${count}件のファイルは届きませんでした：', ), 
			'operation.export.stash.emailOffer' => 'また、ご希望であれば、直接リンクを記載したメールをお送りできます。',
			'operation.export.stash.emailMe' => 'リンクをメールで送信',
			'operation.export.stash.emailSent' => 'ダウンロードリンクをメールでお送りしました。',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'メールを送信できませんでした：${error}',
			'operation.export.stash.freeTier' => '無料アカウントでは一度に保持できるスタッシュは1つだけです。サブスクライバーは必要な数だけ保持できます。',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のファイルをHam2K File Stash（stash.ham2k.net）に送信しました', other: '${count}件のファイルをHam2K File Stash（stash.ham2k.net）に送信しました', ), 
			'operation.spots.empty' => 'フィルターに一致するスポットはありません',
			'operation.spots.error' => ({required Object error}) => 'スポットの読み込みに失敗しました：${error}',
			'operation.spots.unknownBand' => 'その他',
			'operation.spots.auto' => '自動',
			'operation.spots.autoValue' => ({required Object value}) => '自動（現在${value}）',
			'operation.spots.valueAuto' => ({required Object value}) => '${value}（自動）',
			'operation.spots.any' => 'すべて',
			'operation.spots.allBands' => 'すべてのバンド',
			'operation.spots.allModes' => 'すべてのモード',
			'operation.spots.phoneAndCw' => '電話とCW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}スポット', other: '${count}スポット', ), 
			'operation.spots.spotsCountFiltered' => ({required Object total, required Object count}) => '${total}件中${count}件のスポットを表示',
			'operation.spots.spotsDisabled' => 'このオペレーションではスポットが無効です',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes}分',
			'operation.spots.callsOfNote' => '注目のコール',
			'operation.spots.yourSpots' => 'あなたのスポット',
			'operation.spots.allSpots' => 'すべてのスポット',
			'operation.spots.continents.af' => 'アフリカ',
			'operation.spots.continents.as' => 'アジア',
			'operation.spots.continents.eu' => 'ヨーロッパ',
			'operation.spots.continents.na' => '北アメリカ',
			'operation.spots.continents.oc' => 'オセアニア',
			'operation.spots.continents.sa' => '南アメリカ',
			'operation.spots.continents.an' => '南極',
			'operation.spots.filters.title' => 'スポットを絞り込む',
			'operation.spots.filters.band' => 'バンド',
			'operation.spots.filters.mode' => 'モード',
			'operation.spots.filters.age' => '経過時間',
			'operation.spots.filters.sources' => 'ソース',
			'operation.spots.filters.continent' => '大陸',
			'operation.spots.filters.sorting' => '並び替え',
			'operation.spots.filters.sortByTime' => 'スポット時間順',
			'operation.spots.filters.sortByFrequency' => '周波数順',
			'operation.spots.filters.sortByWanted' => 'モストウォンテッド順',
			'operation.spots.filters.groupByBand' => 'バンドでグループ化',
			'operation.spots.filters.groupCallsWithNotes' => 'ノート付きコールをグループ化',
			'operation.spots.filters.alertingOnly' => 'アラート付きのスポットのみ',
			'operation.spots.filters.sourceNoReply' => '応答なし',
			'operation.spots.filters.sourceError' => 'エラー',
			'operation.spots.unavailableTitle' => 'スポットを利用できません',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources}が応答しませんでした。',
			'operation.spots.failedTitle' => 'スポットソースのエラー',
			'operation.spots.failedText' => ({required Object sources}) => '${sources}がエラーを返しました。',
			'operation.spots.slideLogIt' => 'ログに記録',
			'operation.spots.slideIgnore' => '無視',
			'operation.spots.slideRestore' => '元に戻す',
			'operation.spots.logConflict.title' => 'ロギングパネルは使用中です',
			'operation.spots.logConflict.editingBody' => '記録済みのコンタクトを編集中です。代わりにこのスポットを記録しますか？それとも戻って編集を完了しますか？',
			'operation.spots.logConflict.composingBody' => 'コンタクトの入力を始めています。代わりにこのスポットを記録しますか？それとも戻って入力を完了しますか？',
			'operation.spots.logConflict.goBack' => '戻る',
			'operation.spots.logConflict.clearAndLog' => 'クリアしてスポットを記録',
			'operation.import.title' => 'オペレーションにデータをインポート',
			'operation.import.importAdifAction' => 'ADIFからQSOをインポート',
			'operation.import.settingsButton' => '受信設定',
			'operation.import.settingsTitle' => '他のアプリから受信',
			'operation.import.protocolAddressLabel' => 'アドレス',
			'operation.import.protocolPortLabel' => 'ポート',
			'operation.import.protocolPortInvalid' => '1から65535までのポートを入力してください',
			'operation.import.protocolAddressInvalid' => '有効なIPアドレスを入力してください（例：127.0.0.1または239.239.0.2）',
			'operation.import.protocolStatusReceiving' => 'データ受信中',
			'operation.import.protocolStatusNoData' => '最近データを受信していません',
			'operation.import.protocolBindError' => ({required Object error}) => '受信を開始できませんでした：${error}',
			'operation.import.captureFailed' => ({required Object error}) => '受信したQSOを保存できなかったため、再試行しています：${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'すべて（ブロードキャスト）',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDPサーバー',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Broadcast Data タブ → コンタクト情報の「Enable Broadcasts」にチェック。同じコンピューターで実行している場合はIPアドレスを127.0.0.1に、現在のローカルネットワークにブロードキャストする場合は255.255.255.255に設定します。',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reporting タブ → UDP Server セクション → 「Accept UDP requests」にチェック。同じコンピューターで実行している場合はUDP Serverを127.0.0.1に、または239.239.0.2のようなマルチキャストアドレスに設定し、このアプリの上記の設定でも同じアドレスを使用します。',
			'operation.import.listenTitle' => '他のアプリからQSOを受信',
			'operation.import.listenDescriptionOnN1mm' => 'N1MM+から受信中',
			'operation.import.listenDescriptionOnWsjtx' => 'WSJT-Xから受信中',
			'operation.import.listenDescriptionOnBoth' => 'N1MM+とWSJT-Xから受信中',
			'operation.import.listenDescriptionOff' => 'オフ',
			'operation.import.addToOperationTitle' => 'このオペレーションに追加',
			'operation.import.addToOperationDescriptionOn' => '受信したQSOは届き次第このオペレーションに追加されます',
			'operation.import.addToOperationDescriptionOff' => '受信したQSOはこれをオンにするまで保留されます',
			'operation.import.pendingSectionTitle' => '受信したQSO',
			'operation.import.pendingEmpty' => 'まだ何も受信していません',
			'operation.import.stationMismatch' => ({required Object call}) => '${call}として記録されています（このオペレーションの局ではありません）',
			'operation.import.discardAction' => '破棄',
			'operation.import.gapDialogTitle' => '以前に受信したものも含めますか？',
			'operation.import.gapDialogBody' => ({required Object count}) => 'データの途切れより前に、さらに${count}件のQSOを受信しています。それらも含めますか？',
			'operation.import.gapDialogRecentOnly' => '最近のものだけ',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => '${count}件すべてを含める',
			'map.outlineIssue.link' => '問題がありますか？',
			'map.outlineIssue.title' => '境界線の問題を報告',
			'map.outlineIssue.reference' => '対象の境界線',
			'map.outlineIssue.severity' => 'どの程度の問題ですか？',
			'map.outlineIssue.minor' => '軽微',
			'map.outlineIssue.major' => '重大',
			'map.outlineIssue.explanation' => '何が問題ですか？',
			'map.outlineIssue.explanationHint' => '境界線のどこが、どう間違っているか',
			'map.outlineIssue.send' => '送信',
			'map.outlineIssue.sending' => '報告を送信しています。ありがとうございます',
			'map.outlineIssue.copy' => '報告をコピー',
			'map.outlineIssue.notSent' => '報告を送信できませんでした',
			'map.outlineIssue.copied' => '報告をコピーしました',
			'map.outlineIssue.notCopied' => '報告をコピーできませんでした',
			'map.outlinesDisclaimer' => '境界線は参考用です。ご自身でも確認してください！',
			'map.outlinesCredit' => ({required Object sources}) => '境界線: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => '行政境界: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => '施設: ${sources}',
			'map.fullCredits' => 'データの全クレジット',
			'map.fewerCredits' => 'クレジットを減らす',
			'map.emptyState' => 'QSOの位置はまだありません。\nグリッドスクエア、州、国のあるQSOがここに表示されます。',
			'map.unavailable' => '現在、地図を利用できません。',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH：${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => '平面',
			'map.globe' => '地球儀',
			'map.zoomIn' => '拡大',
			'map.zoomOut' => '縮小',
			'map.resetNorth' => '北を上にリセット',
			'map.postcard.button' => 'オペレーションのポストカード',
			'map.postcard.title' => ({required Object title}) => '${title}のポストカード',
			'map.postcard.portrait' => '縦',
			'map.postcard.landscape' => '横',
			'map.postcard.square' => '正方形',
			'map.postcard.save' => '保存…',
			'map.postcard.download' => 'ダウンロード',
			'map.postcard.share' => '共有',
			'map.postcard.copy' => 'コピー',
			'map.postcard.copied' => 'クリップボードにコピーしました',
			'map.postcard.saved' => ({required Object path}) => '${path}に保存しました',
			'map.postcard.downloaded' => ({required Object name}) => '${name}をダウンロードしました',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count}枚の画像を${path}に保存しました',
			'map.postcard.savedFiles' => ({required Object names}) => '${names}を保存しました',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names}は保存済みでした',
			'map.postcard.downloadedMany' => ({required Object count}) => '${count}枚の画像をダウンロード中です。ブラウザに確認されたら許可してください',
			'map.postcard.mapLeftOut' => '地図が読み込まれなかったため、省略しました',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — 地図が読み込まれなかったため、省略しました',
			'map.postcard.continued' => ({required Object title}) => '${title}（続き）',
			'map.postcard.previousPage' => '前のページ',
			'map.postcard.nextPage' => '次のページ',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => '${page} / ${count}ページ',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count} Q', other: '${count} Q', ), 
			'map.postcard.options' => 'ポストカードのオプション',
			'map.postcard.bandLegend' => 'バンドの凡例を表示',
			'map.postcard.grayline' => 'グレイラインを表示',
			'map.postcard.sectionsAndOrder' => '概要のセクションと順序',
			'map.postcard.sectionDays' => '日ごと',
			'map.postcard.reset' => 'リセット',
			'map.postcard.failed' => ({required Object error}) => 'ポストカードを作成できませんでした：${error}',
			'map.postcard.mapNotReady' => '地図の読み込みが完了しませんでした。接続を確認して再試行してください。',
			'map.postcard.saveFailed' => ({required Object error}) => 'ポストカードを保存できませんでした：${error}',
			'map.postcard.copyFailed' => 'クリップボードに画像をコピーできませんでした。再試行してください。',
			'map.postcard.shareFailed' => 'ポストカードを共有できませんでした。再試行してください。',
			'map.postcard.fileName' => 'postcard',
			'mapsView.title' => '地図',
			'mapsView.searchHint' => '公園、山頂などを検索',
			'mapsView.activities' => 'アクティビティ',
			'mapsView.layers' => 'レイヤー',
			'mapsView.baseMap' => 'ベースマップ',
			'mapsView.satellite' => '衛星写真（Esri）',
			'mapsView.facilities' => '公園の施設',
			'mapsView.boundaries' => '行政境界',
			'mapsView.currentLocation' => '現在地',
			'mapsView.noMatches' => ({required Object text}) => '「${text}」に一致するものはありません',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${where}のリファレンス${count}件', other: '${where}のリファレンス${count}件', ), 
			'mapsView.startOperation' => 'これらのリファレンスでオペレーションを開始',
			'activitiesView.title' => 'アクティビティ',
			'activitiesView.activitiesCountZero' => 'アクティビティが選択されていません',
			'activitiesView.activitiesCountOne' => '1件のアクティビティ',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count}件のアクティビティ',
			'activitiesView.empty' => 'アクティビティはまだありません。下の候補と検索から追加してください',
			'activitiesView.removeActivity' => '削除',
			'activitiesView.openReferenceLink' => ({required Object name}) => '${name}を開く',
			'activitiesView.editActivity' => 'アクティビティを編集',
			'activitiesView.manageExtensions' => '拡張機能を管理',
			'activitiesView.manage' => '管理',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'アクティビティの種類：${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'アクティビティの種類：${first}と${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'アクティビティの種類：${first}、${second}、他${more}件',
			'activitiesView.reference' => 'リファレンス',
			'activitiesView.invalidReference' => '無効',
			'activitiesView.duplicateReference' => '追加済み',
			'activitiesView.searchHint' => '名前、リファレンスなどで検索…',
			'activitiesView.noSuggestions' => '一致なし',
			'activitiesView.noSuggestionsHint' => '上でリファレンスの名前または番号を検索してください',
			'activitiesView.noSuggestionsExample' => '（例：「trail」や「4556」）',
			'activitiesView.allOptions' => 'アクティビティの種類',
			'activitiesView.determiningLocation' => '現在地を特定しています…\n近くのリファレンスを探すためにGPSの測位を待っています',
			'activitiesView.locationUnavailableTitle' => '位置情報を利用できません',
			'activitiesView.locationDeniedTitle' => '位置情報の許可が拒否されました',
			'activitiesView.locationBlockedTitle' => '位置情報の許可がブロックされています',
			'activitiesView.noNearbyReason' => '近くのリファレンスを特定できません',
			'activitiesView.locationManualHint' => ({required Object icon}) => '${icon}をタップして手動で位置を入力するか、\n名前でリファレンスを検索してください',
			'activitiesView.locationGrantAction' => '位置情報へのアクセスを許可',
			'activitiesView.locationSettingsAction' => '設定を開く',
			'activitiesView.locationSettingsUnavailable' => 'システム設定で位置情報へのアクセスを許可してください',
			'activitiesView.locationGrantRefused' => '位置情報がまだありません。システムに再び拒否されました',
			'activitiesView.searchUnavailableTitle' => 'アクティビティ検索を利用できません',
			'activitiesView.searchUnavailableReason' => 'アクティビティ拡張機能が検索に応答できませんでした。しばらくしてから再試行してください。',
			'activitiesView.emptySheet' => '下の候補と検索から追加してください',
			'activitiesView.exports' => 'エクスポート',
			'activitiesView.exportLogs' => 'ログをエクスポート',
			'activitiesView.tools' => 'ツール',
			'activitiesView.toolsTitle' => 'オペレーションツール',
			'activitiesView.operationDetails' => 'オペレーション詳細',
			'activitiesView.share' => '共有',
			'activitiesView.archive' => 'アーカイブ',
			'activitiesView.deleteOperation' => 'オペレーションを削除',
			'activitiesView.undeleteOperation' => 'オペレーションを復元',
			'activitiesView.alreadySelected' => '選択済み',
			'activitiesView.selected' => '選択中',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} / ${count}',
			'activitiesView.previousPick' => '前の候補',
			'activitiesView.nextPick' => '次の候補',
			'activitiesView.retiredReference' => '廃止',
			'activitiesView.enableExtension' => ({required Object name}) => '${name}を有効化',
			'activitiesView.enableExtensionHint' => 'この拡張機能は検索に一致しますが、現在有効になっていません',
			'activitiesView.enableExtensionForRefHint' => 'この拡張機能はこのオペレーションのリファレンスの1つを扱いますが、現在有効になっていません',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name}は動作していません',
			'activitiesView.extensionNotRunningHint' => 'この拡張機能は無効化されています。詳細は拡張機能の設定を開いてください',
			'activitiesView.installExtension' => ({required Object name}) => '${name}をインストール',
			'activitiesView.installExtensionHint' => 'この拡張機能は検索に一致しますが、インストールされていません',
			'activitiesView.onlyCatalogMatches' => '一致なし\nカタログの一部の拡張機能に結果があるかもしれません。\n下のアクティビティの種類からインストールしてください。',
			'activitiesView.setupUnavailable' => 'このアクティビティの設定を読み込めませんでした。管理から再試行してください',
			'activitiesView.controlsUnavailableTitle' => 'アクティビティの操作を利用できません',
			'activitiesView.controlsUnavailableReason' => 'リファレンスは安全ですが、現在編集できません。',
			'activitiesView.controlsUnavailableRetry' => '再試行',
			'activitiesView.onlyDisabledMatches' => '一致なし\n利用可能な一部の拡張機能に結果があるかもしれません。\n下のアクティビティの種類で有効にしてください。',
			'activitiesView.onlyNotRunningMatches' => '一致なし\n結果があるかもしれない一部の拡張機能が動作していません。\n下のアクティビティの種類を確認してください。',
			'activitiesView.mapToggle' => '地図',
			'activitiesView.searchToggle' => '検索',
			'activitiesView.addToOperation' => 'オペレーションに追加',
			'activitiesView.addToOperationShort' => '追加',
			'activitiesView.mapEmptyState' => '地図に表示する結果がありません',
			'activitiesView.mapEmptyStateHint' => 'リストに戻るか、別のものを検索してください',
			'activitiesView.imports' => 'インポート',
			'loggingControls.timeUtc' => '時刻（UTC）',
			'loggingControls.date' => '日付',
			'loggingControls.now' => '現在',
			'loggingControls.manualTimeSettings' => '手動時刻',
			'loggingControls.manualTimeIncrement' => 'QSOごとの増分',
			'loggingControls.manualTimeIncrementNone' => 'なし',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}分', other: '${count}分', ), 
			'loggingControls.frequency' => '周波数',
			'loggingControls.mode' => 'モード',
			'loggingControls.theirCall' => '相手のコール',
			'loggingControls.noteField' => 'メモ',
			'loggingControls.todoField' => 'To-Do',
			'loggingControls.sent' => '送信',
			'loggingControls.rcvd' => '受信',
			'loggingControls.more' => 'その他',
			'loggingControls.revert' => '元に戻す',
			'loggingControls.undoDelete' => '削除を取り消す',
			'loggingControls.restore' => '復元',
			'loggingControls.wipe' => '消去',
			'loggingControls.undo' => '元に戻す',
			'loggingControls.pendingDeleteTapWarning' => 'もう一度ゴミ箱をタップするとこのQSOを削除します',
			'loggingControls.pendingDeleteClickWarning' => 'もう一度ゴミ箱をクリックするとこのQSOを削除します',
			'loggingControls.deletedQsoWarning' => '削除されたQSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'もう一度ゴミ箱をタップするとこの${kind}を削除します',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'もう一度ゴミ箱をクリックするとこの${kind}を削除します',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '削除された${kind}',
			'loggingControls.timeControl' => '時刻',
			'loggingControls.radioControl' => '無線機',
			'loggingControls.powerControl' => 'パワー',
			'loggingControls.notesControl' => 'メモ',
			'loggingControls.power' => 'パワー',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'ロギング操作',
			'loggingControls.spottingControl' => 'スポッティング',
			'loggingControls.spottingSelfControl' => 'セルフスポッティング',
			'loggingControls.spotSelfAt' => ({required Object freq}) => '${freq}でセルフスポット',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => '${call}を${freq}でスポット',
			'loggingControls.spotTooLate' => ({required Object call}) => '${call}のスポットには遅すぎます',
			'loggingControls.spotNoFreq' => '最初に周波数を設定してください',
			'loggingControls.selfSpotDisabled' => 'セルフスポット無効',
			'loggingControls.spotComment' => 'コメント',
			'loggingControls.spottingAutoControl' => '自動再スポット',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => '${minutes}分ごとに再スポット',
			'loggingControls.spotAutoNext' => ({required Object time}) => '${time}後に自動。停止しますか？',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => '${minutes}分後に自動',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => '${seconds}秒後に自動',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => '${seconds}後に自動',
			'loggingControls.spotAutoNotStarted' => '自動再スポットを開始できませんでした：スポットが送信されませんでした',
			'loggingControls.spotAutoMoved' => '自動再スポットを開始できませんでした：スポット中に周波数が変わりました',
			'loggingControls.spotAutoStopped' => '自動再スポットを停止しました',
			'loggingControls.spotAutoLeftFreq' => '自動再スポットを停止しました：周波数が変わりました',
			'loggingControls.spotAutoNoFreq' => '自動再スポットを停止しました：無線機から周波数が得られません',
			'loggingControls.spotBusy' => '別のスポットをまだ送信中です',
			'loggingControls.bandOrFreqRequired' => '記録する前に周波数またはバンドを設定してください',
			'loggingControls.missingBand' => 'バンドなし',
			'loggingControls.missingMode' => 'モードなし',
			'loggingControls.saveFailed' => ({required Object error}) => '保存できませんでした：${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => '削除できませんでした：${error}',
			'loggingControls.info.noQsos' => 'まだQSOがありません... オンエアしましょう！',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object time, required Object count}) => '${time}で${count}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '最後から${time}',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '最後の10件で${rate} Q/h',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '最後の100件で${rate} Q/h',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} →',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance}（${bearing}°）→',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）→',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} 離れた所',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance}（${bearing}°）離れた所',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）離れた所',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}：${notice}',
			'loggingControls.info.noticeDupe' => '重複！',
			'loggingControls.info.noticeNewBand' => '新しいバンド',
			'loggingControls.info.noticeNewMode' => '新しいモード',
			'loggingControls.info.noticeNewDXCC' => '新しいDXCC',
			'loggingControls.info.noticeNewState' => '新しい州',
			'loggingControls.info.noticeNewProvince' => '新しい州/県',
			'loggingControls.info.noticeNewDay' => '新しい日',
			'loggingControls.info.noticeNewRef' => '新しいリファレンス',
			'loggingControls.info.noticeNewMult' => '新しいマルチ',
			'loggingControls.info.noticeNewZone' => '新しいゾーン',
			'loggingControls.info.noticeInvalidMode' => 'モード違い',
			'loggingControls.info.noticeInvalidBand' => 'バンド違い',
			'loggingControls.info.noticeInvalidCategory' => '交信対象外',
			'loggingControls.info.noticeOverTime' => '時間外',
			'loggingControls.info.noticeWorkedBefore' => '交信済み',
			'loggingControls.info.noticeNewPark' => '新しい公園',
			'loggingControls.info.noticeNewSection' => '新しいセクション',
			'loggingControls.info.noticeBonusStation' => 'ボーナス局！',
			'loggingControls.info.noticeMissingExchange' => '交換なし',
			'loggingControls.info.noticeInvalidExchange' => '交換が不正',
			'loggingControls.info.noticeUnknownEvent' => '不明なイベント',
			'loggingControls.info.noticeIncompleteCall' => 'コール不完全 — スコア対象外',
			'loggingControls.info.noticeOurGrid' => '自局グリッドを設定',
			'loggingControls.info.noticeRareCounty' => 'レアな郡！',
			'loggingControls.info.noticeOurLocation' => '自局の郡を設定',
			'loggingControls.info.noticeShortGrid' => 'グリッドが短すぎます',
			'formChrome.untitled' => '（無題）',
			'formChrome.showMore' => 'さらに表示',
			'formChrome.showAll' => 'すべて表示',
			'formChrome.showFewer' => '表示を減らす',
			'formChrome.defaults' => 'デフォルト',
			'formChrome.search' => '検索',
			'formChrome.clear' => 'クリア',
			'formChrome.openPage' => 'ページを開く',
			'formChrome.connected' => '接続済み',
			'formChrome.notConnected' => '未接続',
			'formChrome.manage' => '管理',
			'formChrome.connect' => '接続',
			'formChrome.formTitle' => 'フォーム',
			'formChrome.addItem' => ({required Object label}) => '${label}を追加',
			'formChrome.editItem' => ({required Object label}) => '${label}を編集',
			'formChrome.multiselectStatus' => ({required Object total, required Object shown, required Object selected}) => '${total}件中${shown}件を表示（${selected}件選択中）',
			'formChrome.validationError' => ({required Object error}) => '検証エラー：${error}',
			'formChrome.transformationError' => ({required Object error}) => '変換エラー：${error}',
			'formChrome.actionError' => ({required Object error}) => 'エラー：${error}',
			'formChrome.removeItem' => '削除',
			'formChrome.deleteItemTitle' => ({required Object name}) => '${name}を削除しますか？',
			'formChrome.storageUnavailable' => 'ログイン情報を利用できません',
			'qsoEditForm.title' => 'QSOを編集',
			'qsoEditForm.operatorCall' => 'オペレーター',
			'qsoEditForm.position' => 'ポジション',
			'qsoEditForm.theirName' => '名前',
			'qsoEditForm.theirGrid' => 'グリッド',
			'qsoEditForm.theirState' => '州',
			'qsoEditForm.band' => 'バンド',
			'qsoEditForm.notes' => 'メモ',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => '相手の情報',
			'qsoEditForm.sectionOur' => '自局の情報',
			'qsoEditForm.sectionNotes' => 'メモ',
			'qsoEditForm.theirCity' => '都市',
			'qsoEditForm.theirCounty' => '郡',
			'qsoEditForm.theirEntity' => 'エンティティ',
			'qsoEditForm.theirCqZone' => 'CQゾーン',
			'qsoEditForm.theirItuZone' => 'ITUゾーン',
			'qsoEditForm.theirArrlSection' => 'ARRLセクション',
			'qsoEditForm.theirLat' => '緯度',
			'qsoEditForm.theirLon' => '経度',
			'qsoEditForm.theirPower' => '相手のパワー',
			'qsoList.empty' => 'まだQSOがありません。誰かと交信しましょう！',
			'qsoList.bandOrModeWarning' => 'バンドとモードが正しいか確認してください',
			'qsoList.today' => '今日',
			'qsoList.yesterday' => '昨日',
			'qsoList.tomorrow' => '明日',
			'qsoList.find.menuItem' => ({required Object shortcut}) => 'ログ内を検索（${shortcut}）',
			'qsoList.find.menuItemNoShortcut' => 'ログ内を検索',
			'qsoList.find.hint' => 'QSO番号またはコールサイン',
			'qsoList.find.noMatches' => '一致なし',
			'qsoList.find.noOperationQsos' => 'このオペレーションにQSOはありません',
			'qsoList.find.noPeriodQsos' => 'この期間にQSOはありません',
			'qsoList.find.outsideQsosOne' => 'このオペレーション外のQSO：1件',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => 'このオペレーション外のQSO：${count}件',
			'qsoList.find.pastQsosOne' => '過去のQSO：1件',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '過去のQSO：${count}件',
			'loggingPanel.stats' => 'オペレーションの統計',
			'loggingPanel.scoring' => 'スコア',
			'loggingPanel.dxccEntities' => 'DXCCエンティティ',
			'loggingPanel.statesWorked' => '州',
			'loggingPanel.provincesWorked' => '州/県',
			'loggingPanel.duplicates' => '重複',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => '画像を表示',
			'callInfo.imageUnavailable' => '写真を利用できません',
			'callInfo.photo' => '写真',
			'callInfo.notes' => 'メモ',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} →',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance}（${bearing}°）→',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）→',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} 離れた所',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance}（${bearing}°）離れた所',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance}（${bearing}° / ${reverse}°）離れた所',
			'callInfo.thisOpCountOne' => 'このオペレーションでのQSO：1件',
			'callInfo.thisOpCountOther' => ({required Object count}) => 'このオペレーションでのQSO：${count}件',
			'callInfo.otherOpsCountOne' => '他のオペレーションでのQSO：1件',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '他のオペレーションでのQSO：${count}件',
			'callInfo.andMore' => ({required Object count}) => '…さらに${count}件',
			'callInfo.withCall' => ({required Object call}) => '${call}と共に',
			'callInfo.fromOperation' => ({required Object where}) => '${where}から',
			'callInfo.history.last7days' => ({required Object n}) => '過去7日間：${n}件',
			'callInfo.history.today' => ({required Object n}) => '今日：${n}件',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => '設定',
			'settings.language' => '言語',
			'settings.languageSystem' => ({required Object language}) => 'システム設定に従う（${language}）',
			'settings.theme.title' => 'テーマモード',
			'settings.theme.system' => 'システム設定に従う',
			'settings.theme.light' => 'ライト',
			'settings.theme.dark' => 'ダーク',
			'settings.themeDescription.system' => 'システム設定に従っています',
			'settings.themeDescription.light' => '常にライトモード',
			'settings.themeDescription.dark' => '常にダークモード',
			'settings.fontScale' => 'フォントサイズ',
			'settings.fontScaleOpts.smallestMinusMinus' => '最小--',
			'settings.fontScaleOpts.smallestMinus' => '最小-',
			'settings.fontScaleOpts.smallest' => '最小',
			'settings.fontScaleOpts.smaller' => '小さい',
			'settings.fontScaleOpts.normal' => '標準',
			'settings.fontScaleOpts.larger' => '大きい',
			'settings.fontScaleOpts.largest' => '最大',
			'settings.fontScaleOpts.largestPlus' => '最大+',
			'settings.fontScaleOpts.largestPlusPlus' => '最大++',
			'settings.keepDeviceAwake.title' => '端末のスリープを無効化',
			'settings.keepDeviceAwake.descriptionOn' => 'ロギング画面の表示中または同期中はスリープしません',
			'settings.keepDeviceAwake.descriptionOff' => '通常どおりスリープします',
			'settings.layoutDensity' => 'レイアウト密度',
			'settings.layoutDensityOpts.auto' => '自動',
			'settings.layoutDensityOpts.densest' => '最高密度',
			'settings.layoutDensityOpts.dense' => '高密度',
			'settings.layoutDensityOpts.normal' => '標準',
			'settings.layoutDensityOpts.sparse' => '低密度',
			'settings.layoutDensityOpts.sparsest' => '最低密度',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'ウィンドウの高さが足りないため、${effective}を使用中',
			'settings.layoutDensityAtLimit' => 'これ以上は変更できません',
			'settings.distanceUnits' => '距離の単位',
			'settings.distanceUnitsOpts.kilometers' => 'キロメートル',
			'settings.distanceUnitsOpts.miles' => 'マイル',
			'settings.userInterface' => 'ユーザーインターフェース',
			'settings.logging.title' => 'ロギング',
			'settings.logging.leftieMode.title' => '左利きモード',
			'settings.logging.leftieMode.descriptionOn' => '左利き用レイアウトを使用しています',
			'settings.logging.leftieMode.descriptionOff' => '右利き用レイアウトを使用しています',
			'settings.logging.countryFlags.title' => '国旗',
			'settings.logging.countryFlags.dx' => 'DXコンタクトのみ表示',
			'settings.logging.countryFlags.all' => 'すべてのコンタクトに国旗を表示',
			'settings.logging.countryFlags.none' => '国旗を表示しない',
			'settings.logging.countryFlagsDescription.dx' => 'DXコンタクトのみに国旗を表示しています',
			'settings.logging.countryFlagsDescription.all' => 'すべてのコンタクトに国旗を表示しています',
			'settings.logging.countryFlagsDescription.none' => '国旗を表示していません',
			'settings.logging.suggestDefaultOperator.title' => 'オペレーターを提案',
			'settings.logging.suggestDefaultOperator.descriptionOn' => '別のステーションコールサインで運用するオペレーションでは、あなたのコールサインをオペレーターとして提案します',
			'settings.logging.suggestDefaultOperator.descriptionOff' => '入力しない限りオペレーターは空欄のままです',
			'settings.logging.showBearing.title' => '方位を表示',
			'settings.logging.showBearing.descriptionOn' => '局への推定方位を表示しています',
			'settings.logging.showBearing.descriptionOff' => '方位情報を表示していません',
			'settings.logging.showReverseBearing.title' => '逆方位も表示',
			'settings.logging.showReverseBearing.descriptionOn' => '局からの方位も「45° / 225°」のように表示しています',
			'settings.logging.showReverseBearing.descriptionOff' => '局への方位のみを表示しています',
			'settings.logging.switchSentRcvd.title' => 'シグナルレポートの順序を切り替える',
			'settings.logging.switchSentRcvd.sentFirst' => '送信が先、受信が後',
			'settings.logging.switchSentRcvd.rcvdFirst' => '受信が先、送信が後',
			'settings.logging.jumpAfterRST.title' => 'RST入力時に次のフィールドにジャンプ',
			'settings.logging.jumpAfterRST.descriptionOn' => 'RST入力後に次のフィールドへジャンプします',
			'settings.logging.jumpAfterRST.descriptionOff' => '自動的にジャンプしません',
			'settings.logging.defaultReport.title' => 'デフォルトレポート — 電話',
			'settings.logging.defaultReport.description' => 'SSB、FM、AMで送信または受信が空欄の場合に使用',
			'settings.logging.defaultReportCW.title' => 'デフォルトレポート — CWとデータ',
			'settings.logging.defaultReportCW.description' => 'CW、RTTY、その他のデータモードで送信または受信が空欄の場合に使用',
			'settings.logging.defaultReportFT8.title' => 'デフォルトレポート — FT8とFT4',
			'settings.logging.defaultReportFT8.description' => 'FTモードで送信または受信が空欄の場合に使用',
			'settings.logging.numbersRow.title' => '数字行',
			'settings.logging.numbersRow.description' => 'ロギング中、キーボードの上に数字キーの行を表示',
			'settings.logging.numbersRowExtra.title' => 'スラッシュとピリオドキー',
			'settings.logging.numbersRowExtra.description' => '状況に応じたキーを追加：コールサインには「/」、数値には「.」',
			'settings.logging.numbersRowVibrate.title' => 'キー押下時に振動',
			'settings.logging.numbersRowVibrate.description' => '数字キーをタップしたときの触覚フィードバック',
			'settings.logging.bands' => '優先バンド',
			'settings.logging.modes' => '優先モード',
			'settings.catServer.title' => 'CATサーバー',
			'settings.catServer.description' => '他のアプリ（WSJT-X、ロガーなど）がHam2K Logger経由で無線機を制御できるようにします。',
			'settings.catServer.protocol' => 'プロトコル',
			'settings.catServer.protocolOpts.off' => '無効',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'ポート',
			'settings.catServer.openAccess' => 'オープンアクセス',
			'settings.catServer.openAccessOn' => 'ローカルネットワーク上のどのコンピューターからも接続できます。',
			'settings.catServer.openAccessOff' => 'このコンピューター上のアプリのみ接続できます。',
			'settings.catServer.allowTransmit' => 'アプリからの送信を許可',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => 'アプリは無線機のPTTを、一度に最大${minutes}分までキーイングできます。',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => 'ローカルネットワーク上のどのコンピューターのアプリも、無線機のPTTを一度に最大${minutes}分までキーイングできます。',
			'settings.catServer.allowTransmitOff' => 'アプリは無線機をキーイングできません。VOXか、アプリ独自のPTT設定を使ってください。',
			'settings.catServer.allowTransmitUnsupported' => 'メインVFOの無線機はHam2K Loggerからキーイングできないため、アプリはこの無線機で送信できません。',
			'settings.catServer.off' => 'オフ。',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}、起動中…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol}：ポート${port}で待ち受け中。接続中のクライアント：${clients}。',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol}：ポート${port}で待ち受け中ですが、メインVFOの無線機が接続されていません。',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol}はポート${port}で待ち受けできません：${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol}はポート${port}で待ち受けできません：別のプログラム（多くの場合${protocol}自体）が使用中です。そのプログラムを閉じるか、別のポートを選んでください。',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol}はポート${port}で待ち受けできません：このコンピューターが許可していません。1024より大きいポートを選んでください。',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol}はポート${port}での待ち受けを停止しました。再試行中…',
			'settings.cluster.title' => 'DXクラスター',
			'settings.cluster.description' => '拡張機能がオペレーターとしてログインし、スポットの投稿と読み取りを行うサーバー。',
			'settings.cluster.connect' => 'クラスターに接続',
			'settings.cluster.connectOn' => '拡張機能は必要なときにクラスターに接続します',
			'settings.cluster.connectOff' => '何もクラスターに接続しません',
			'settings.cluster.console' => 'コンソールを表示',
			'settings.cluster.consoleDescription' => 'クラスターからの受信内容と、コマンドを入力する場所',
			'settings.cluster.consoleTitle' => 'クラスターコンソール',
			'settings.cluster.consoleConnect' => '接続',
			'settings.cluster.consoleDisconnect' => '切断',
			'settings.cluster.consoleCommand' => 'コマンド',
			'settings.cluster.consoleEmpty' => 'まだ何もありません。接続するか、拡張機能がクラスターを使うのを待ってください。',
			'settings.cluster.consoleRetry' => ({required Object command}) => '再送信中：${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => '未送信：${command}（${reason}）',
			'settings.cluster.server' => 'クラスターサーバー',
			'settings.cluster.selectServer' => 'サーバーを選択',
			'settings.cluster.serverOther' => 'その他',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => 'ホストが未入力のため、スポットは${node}に送られます',
			'settings.cluster.customHost' => 'サーバー',
			'settings.cluster.customPort' => 'ポート',
			'settings.cluster.password' => 'パスワード',
			'settings.cluster.passwordDescription' => '必要な場合のみ',
			'settings.cluster.passwordStored' => ({required Object node}) => '${node}のパスワードを保存済み',
			'settings.cluster.scrollback' => '保持する行数',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count}行',
			'settings.cluster.connection' => '接続',
			'settings.cluster.statusIdle' => '未接続。拡張機能が必要とすると接続します。タップしてテスト。',
			'settings.cluster.statusConnecting' => ({required Object node}) => '${node}に接続中…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => '${node}に${call}として接続済み。',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => '${node}に接続できませんでした：${reason}',
			'settings.cluster.statusUnsupported' => 'Web版では利用できません。',
			'settings.cluster.statusOff' => 'オフ。使用するには「クラスターに接続」をオンにしてください。',
			'settings.cluster.errors.noCall' => 'ログインに使うオペレーターのコールサインがありません',
			'settings.cluster.errors.connectFailed' => 'ノードに到達できませんでした',
			'settings.cluster.errors.needsPassword' => 'ノードがパスワードを求めていますが、保存されていません',
			'settings.cluster.errors.loginFailed' => 'ノードがログインを受け付けませんでした',
			'settings.cluster.errors.disconnected' => 'ノードが接続を閉じました',
			'settings.cluster.errors.timeout' => 'ノードが応答しませんでした',
			'settings.cluster.errors.off' => '「クラスターに接続」がオフです',
			'settings.spotting.title' => 'スポッティング',
			'settings.spotting.respotInterval' => '自動再スポットの間隔',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes}分',
			'settings.spotting.autoRespotByDefault' => 'デフォルトで自動再スポット',
			'settings.spotting.autoRespotByDefaultOn' => 'スポットを投稿したら自動再スポットを有効にします',
			'settings.spotting.autoRespotByDefaultOff' => '自動再スポットの有効化には手動の操作が必要です',
			'settings.spotting.pulseBeforeRespot' => '自動再スポット前に点滅',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => '各再スポットの${seconds}秒前からスポッティングチップが青く点滅します',
			'settings.spotting.pulseBeforeRespotOff' => '自動再スポット前に点滅しません',
			'settings.radio.title' => 'CAT制御',
			'settings.radio.loggingAndCat' => 'ロギングとCAT',
			'settings.radio.tuningSection' => 'チューニング',
			'settings.radio.keyerSection' => 'キーヤー',
			'settings.radio.servicesSection' => 'サービス',
			'settings.radio.stationConfigurationSection' => 'ステーション構成',
			'settings.radio.moreSettings' => 'その他のステーション構成設定',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'キーボードでPTTを操作',
			'settings.radio.pttKey.modes.off' => 'いいえ',
			'settings.radio.pttKey.modes.toggle' => 'トグル',
			'settings.radio.pttKey.modes.hold' => 'ホールド',
			'settings.radio.pttKey.descriptions.off' => 'キーボードでは無線機をキーイングしません。',
			'settings.radio.pttKey.descriptions.toggle' => '電話モードでは、PTTキーで無線機をキーイングし、もう一度押すと解除します。1分経つと自動的に解除されます。',
			'settings.radio.pttKey.descriptions.hold' => '電話モードでは、PTTキーを押している間、最大1分まで無線機が送信します。',
			'settings.radio.pttKey.key' => 'PTTキー',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => '送信中',
			'settings.radio.smartVfoSnap.title' => 'スマートVFOスナップ',
			'settings.radio.smartVfoSnap.descriptionOn' => 'ダイヤルを止めた後、周波数を適切なステップに丸めます。音声モードのみ。',
			'settings.radio.smartVfoSnap.descriptionOff' => 'チューニングした周波数をそのまま保ちます。',
			'settings.radio.snapDebounce.title' => 'スマートスナップ：待機時間',
			'settings.radio.snapDebounce.description' => '周波数を丸めるまでにダイヤルが止まっている必要がある時間。短いと即座に、長いとゆっくりした操作にも余裕ができます。',
			'settings.radio.snapLongMove.title' => 'スマートスナップ：大きな移動',
			'settings.radio.snapLongMove.description' => 'この量以上動かすと、最後がどれだけゆっくりでも周波数をkHz単位に丸めます。',
			'settings.radio.snapMinMove.title' => 'スマートスナップ：最小の移動',
			'settings.radio.snapMinMove.description' => 'これより小さい移動では周波数を丸めないため、微調整はそのまま保たれます。',
			'settings.radio.snapMinSpeed.title' => 'スマートスナップ：最も遅い移動',
			'settings.radio.snapMinSpeed.description' => 'これより遅くダイヤルを回すと、大きな移動でない限り周波数を丸めません。',
			'settings.radio.enterSends.pillOff' => 'ESM オフ',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enterでメッセージ送信',
			'settings.radio.enterSends.off' => 'オフ',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enterでメッセージ送信：${state}。タップして変更。',
			'settings.radio.keyerSpeed.title' => 'キーヤー速度',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CWキーヤーメッセージ',
			'settings.radio.cwMessages.notSupported' => '現在の無線機はCWキーイングに対応していません',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'メッセージ${n}',
			'settings.radio.cwMessages.labelField' => 'ラベル',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n}のラベル',
			'settings.radio.cwMessages.details' => '詳細',
			'settings.radio.cwMessages.empty' => '（空）',
			'settings.radio.cwMessages.sets' => 'メッセージセット',
			'settings.radio.cwMessages.newSet' => '新しいセット',
			'settings.radio.cwMessages.renameSet' => 'セット名を変更',
			'settings.radio.cwMessages.deleteSet' => 'セットを削除',
			'settings.radio.cwMessages.newSetName' => '名前',
			'settings.radio.cwMessages.setDefault' => 'デフォルト',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESMメッセージ',
			'settings.radio.cwMessages.setSaved' => 'マイメッセージ',
			'settings.radio.cwMessages.repeat' => 'メッセージ1を繰り返す',
			'settings.radio.cwMessages.repeatShort' => 'M1を繰り返す',
			'settings.radio.cwMessages.cooldown' => '繰り返しまでの待ち時間',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n}秒',
			'settings.radio.cwMessages.repeatWait' => '繰り返し中',
			'settings.radio.cwMessages.keyboard' => '入力して送信',
			'settings.radio.cwMessages.keyboardField' => '入力して送信',
			'settings.radio.cwMessages.help' => 'ヘルプ',
			'settings.radio.cwMessages.helpTitle' => 'CWメッセージの書き方',
			'settings.radio.cwMessages.helpIntro' => 'メッセージでは次の値をテンプレートとして使えます：',
			'settings.radio.cwMessages.helpOpCall' => 'あなたのコールサイン',
			'settings.radio.cwMessages.helpQsoCall' => '相手のコールサイン（//スタックでは記録されるコール）',
			'settings.radio.cwMessages.helpQsoFullCall' => '有効なコールがあれば相手のコールサイン。部分入力の場合は空',
			'settings.radio.cwMessages.helpQsoPartial' => '部分的なコール。完全な有効コールがある場合は空',
			'settings.radio.cwMessages.helpQsoNextCall' => '//スタックで、次に記録対象として選ばれるコール（完全な有効コールがある場合）',
			'settings.radio.cwMessages.helpQsoNextPartial' => '//スタックで、現在のコンタクトを記録した後の次の部分コール',
			'settings.radio.cwMessages.helpQsoName' => '相手の名前（入力値、なければ検索結果から）',
			'settings.radio.cwMessages.helpQsoState' => '相手の州（入力値、なければ検索結果から）',
			'settings.radio.cwMessages.helpKeyerMsg' => '別のメッセージ内で、送信される形のメッセージ1。メッセージ1〜8で有効',
			'settings.radio.cwMessages.helpQsoRst' => '送信するレポート',
			'settings.radio.cwMessages.helpQsoSerial' => 'シリアル番号を送るコンテストでの、あなたのシリアル番号',
			'settings.radio.cwMessages.helpPad' => '指定した桁数までゼロで埋めます：7は007として送信',
			'settings.radio.cwMessages.helpCut' => 'カットナンバー、0はT、9はN：599は5NNとして送信',
			'settings.radio.cwMessages.helpCutDigits' => 'カットする数字を引用符で指定します。0はT、1はA、5はE、9はN',
			'settings.radio.cwMessages.helpFullExample' => '完全な例：',
			'settings.radio.cwMessages.helpExample' => 'W1AW 5NN TT7を送信',
			'settings.radio.cwMessages.helpEsmIntro' => 'Enterでメッセージ送信がオンの場合、N1MMと同様に、Enterで対応するファンクションキーのメッセージを送信します。ESMメッセージセットの初期内容は次のとおりです：',
			'settings.radio.cwMessages.helpEsmCq' => 'Run時、コール欄が空の状態でEnterを押すとCQを出します',
			'settings.radio.cwMessages.helpEsmExchange' => 'あなたの交換：Run時は相手のコールの後、S&P時は相手が応答した後',
			'settings.radio.cwMessages.helpEsmThanks' => 'コンタクトの記録後のお礼。qsoは記録されたコンタクト、nextは次のコンタクトを指します',
			'settings.radio.cwMessages.helpEsmMyCall' => 'S&P時、応答する局へのあなたのコール',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Run時、交換の前に送る相手のコール',
			'settings.radio.cwMessages.helpEsmAgain' => '相手の交換がまったく取れなかったときに再度尋ねます',
			'settings.radio.cwMessages.helpEsmStackThanks' => '//スタック用の推奨F3：お礼の後、スタックの次の局を呼んで交換を送るか、部分コールを聞き返します（TU KR?）。残りがなければTUのみ',
			'settings.radio.keyerControl.label' => 'キーヤー',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => '音声',
			'settings.radio.voiceMessages.title' => '電話キーヤーメッセージ',
			'settings.radio.voiceMessages.notSupported' => '現在の無線機は電話メッセージに対応していません',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'ボイスメモリー${n}',
			'settings.radio.voiceMessages.labelField' => 'ラベル',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'ボイスメモリー${n}のラベル',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n}秒',
			'settings.radio.voiceMessages.emptyOnRadio' => '空',
			'settings.radio.voiceMessages.notMeasured' => '長さ不明',
			'settings.radio.voiceMessages.playButton' => '再生',
			'settings.radio.voiceMessages.recordButton' => '録音',
			'settings.radio.voiceMessages.stopButton' => '停止',
			'settings.radio.voiceMessages.repeat' => 'メッセージ1を繰り返す',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model}の注意事項：',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'これらのメモリーは${device}の無線機にあります。名前と長さはそのデバイスのものです。',
			'settings.radio.voiceMessages.namedOnRadio' => '無線機に保存され、他のクライアントからも見えます。',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => '無線機に[REC]表示が出るのを待ってから、PTTボタンを押したままメッセージを録音します。不要なクリック音を避けるため、PTTを離す前にアプリのSTOPボタンを押して録音を終了してください。',
			'settings.radio.voiceMessages.recordHelpFt891' => '[REC]表示が4回以上点滅するのを待ってから、PTTボタンを押したままメッセージを録音します。不要なクリック音を避けるため、PTTを離す前にアプリのSTOPボタンを押して録音を終了してください。',
			'settings.radio.voiceMessages.pill' => '音声',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'メモリー${n}を再生',
			'settings.radio.voiceMessages.stop' => '停止',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'メモリー${n}を録音',
			'settings.radio.voiceMessages.stopRecording' => '録音を停止',
			'settings.radio.voiceMessages.playing' => '再生中…',
			'settings.radio.voiceMessages.recording' => '録音中…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => '${label}を再生中',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '${label}を録音中',
			'settings.radio.voiceMessages.doubtful' => '無線機は再生しましたか？すぐにアイドル状態と報告しました。',
			'settings.radio.voiceMessages.recordOnRadio' => 'メモリーは無線機本体で録音する必要があります。',
			'settings.radio.voiceMessages.sets' => 'メッセージセット',
			'settings.radio.voiceMessages.soundFilesSet' => 'このコンピューター上のサウンドファイル',
			'settings.radio.voiceMessages.openFileButton' => 'ファイルを開く',
			'settings.radio.voiceMessages.newSet' => '新しいセット',
			'settings.radio.voiceMessages.renameSet' => 'セット名を変更',
			'settings.radio.voiceMessages.deleteSet' => 'セットを削除',
			'settings.radio.voiceMessages.newSetName' => '名前',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => '${name}とその録音を削除しますか？元に戻せません。',
			'settings.radio.voiceMessages.output' => '音声の出力先',
			'settings.radio.voiceMessages.input' => '録音元',
			'settings.radio.voiceMessages.outputRadio' => 'ネットワーク経由で無線機に送る',
			'settings.radio.voiceMessages.inputDefault' => 'システムのデフォルト',
			'settings.radio.voiceMessages.pickDevice' => 'サウンドデバイスを選択',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name}（未接続）',
			'settings.radio.voiceMessages.lead' => 'キーイング後の遅延',
			'settings.radio.voiceMessages.tail' => 'キーイング解除前の遅延',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => '試聴',
			'settings.radio.voiceMessages.notRecorded' => '未録音',
			'settings.radio.voiceMessages.unplayable' => 'このファイルは再生できません',
			'settings.radio.voiceMessages.problemNoOutput' => 'メッセージを再生する前に、無線機に音声を送るサウンドデバイスを選んでください。',
			'settings.radio.voiceMessages.problemOutputMissing' => '無線機に音声を送るサウンドデバイスが接続されていません。',
			'settings.radio.voiceMessages.problemInputMissing' => '録音デバイスが接続されていません。',
			'settings.radio.voiceMessages.problemDeviceFailed' => 'サウンドデバイスを開けませんでした。',
			'settings.radio.voiceMessages.problemNotRecorded' => 'そのメッセージはまだ録音されていません。',
			'settings.radio.voiceMessages.problemRecordingSilent' => '録音デバイスから何も聞こえなかったため、メッセージはそのままにしました。入力と、アプリにマイクの使用が許可されているかを確認してください。',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => '無線機は現在アプリからの音声を受け取っていません。無線機へのネットワーク接続が必要です。',
			'settings.radio.voiceMessages.problemSourceRefused' => '無線機が送信音声をアプリに切り替えなかったため、メッセージを停止しました。アプリの音声を送信するよう無線機を設定してください。',
			'settings.radio.voiceMessages.problemCannotKey' => 'この無線機はCATでキーイングできないため、コンピューターからメッセージを流せません。',
			'settings.radio.voiceMessages.problemUnplayable' => 'そのメッセージのファイルは、アプリで再生できるサウンドファイルではありません。WAV、FLAC、MP3ファイルを使うか、録音し直してください。',
			'settings.radio.voiceMessages.problemRecordingFailed' => '録音が途中で切れたため、メッセージはそのままにしました。録音デバイスがまだ接続されているか、ディスクに空きがあるかを確認してください。',
			'settings.radio.voiceMessages.problemFileFailed' => '録音をメッセージの場所に保存できなかったため、メッセージはそのままにしました。',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => 'そのメッセージには未録音の単語が必要です：${words}。',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => 'そのメッセージのテンプレートに問題があります：${error}',
			'settings.radio.voiceMessages.problemNoOperation' => '自分の声で言うメッセージは、対象のコンタクトがあるオペレーション内で再生します。',
			'settings.radio.voiceMessages.problemNothingSaid' => 'そのメッセージはこのコンタクトに対して何も言いません。',
			'settings.radio.voiceMessages.templateField' => '自分の声で言う',
			'settings.radio.voiceMessages.templateHelp' => '空欄なら録音をそのまま再生します。入力すると、録音した単語をコンタクトごとに当てはめてメッセージを言います。使える値：',
			'settings.radio.voiceMessages.help' => 'ヘルプ',
			'settings.radio.voiceMessages.helpTitle' => '自分の声でメッセージを言う',
			'settings.radio.voiceMessages.helpFullExample' => 'メッセージ全体の例：',
			'settings.radio.voiceMessages.helpExample' => '相手のコール、相手へのレポート、そして「QSL?」の録音',
			'settings.radio.voiceMessages.playOnRadio' => '無線機で再生',
			'settings.radio.voiceMessages.templateHelpCall' => '相手のコール',
			'settings.radio.voiceMessages.templateHelpReport' => '相手に送るレポート',
			'settings.radio.voiceMessages.templateHelpMessage' => 'メッセージ2の録音を、録音のまま再生',
			'settings.radio.voiceMessages.voiced' => '自分の声で読み上げ',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => '読み上げ：${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => '未録音：${words}',
			'settings.radio.voiceMessages.previewNoOperation' => '何を言うかを確認するにはオペレーションを開いてください。',
			'settings.radio.voiceMessages.wordsDescription' => 'コールや数字などに自分の声を使います。',
			'settings.radio.voiceWords.title' => '単語の録音',
			'settings.radio.voiceWords.callField' => 'オペレーター別の単語',
			'settings.radio.voiceWords.intro' => '各単語や数字を、コールサインを言うときのように続けて素早く3回録音します。長いフレーズは1回だけ録音します。',
			'settings.radio.voiceWords.recordAll' => 'すべて録音',
			'settings.radio.voiceWords.recordAllGuide' => '各単語は続けて3回、複数の単語からなるフレーズは1回読み上げ、行の間で息継ぎをしてください。最後まで読んだら停止を押してください。',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => '「${word} ${word} ${word}」と言ってから、停止を押してください。',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => '「${words}」と言ってから、停止を押してください。',
			'settings.radio.voiceWords.recorded' => '録音済み',
			'settings.radio.voiceWords.notRecorded' => '未録音',
			'settings.radio.voiceWords.addPhrase' => 'フレーズを追加',
			'settings.radio.voiceWords.phraseField' => 'フレーズ（メッセージに書くとおりに）',
			'settings.radio.voiceWords.deletePhrase' => 'フレーズを削除',
			'settings.radio.voiceWords.tryField' => '試しに読み上げ',
			'settings.radio.voiceWords.pauseLetters' => '文字間の間隔',
			'settings.radio.voiceWords.pauseWords' => '単語間の間隔',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => '速度',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => '詳細設定',
			'settings.radio.voiceWords.splitSilent' => '録音に何も聞こえませんでした。',
			'settings.radio.voiceWords.splitNotThreeTakes' => '3回分を見つけられませんでした。単語を続けて3回言ってから、もう一度試してください。',
			'settings.radio.voiceWords.splitLineCount' => '読み上げの中にすべての単語を見つけられませんでした。各単語を3回ずつ、単語の間で息継ぎをして読んでください。',
			'settings.radio.voiceWords.splitLinesTooClose' => '単語を区別できませんでした。単語の間にもっと長く息継ぎを入れてください。',
			'settings.radio.avoidZeroBeat.title' => 'スポットでのゼロビートを避ける',
			'settings.radio.avoidZeroBeat.descriptionOn' => '無線機が接続されている場合、CWスポットから数Hzずらしてチューニングし、応答する全員が同じ音で呼ばないようにします。',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'スポットされた周波数ちょうどにチューニングします。',
			'settings.radio.zeroBeatRange.title' => 'ゼロビート：回避範囲',
			'settings.radio.zeroBeatRange.description' => 'スポット周波数からどれだけ離れた位置に合わせるか（上下どちらか）。オフセットがゼロ付近になることはありません。それでは再びゼロビートになるためです。',
			'settings.help.title' => 'ヘルプとリソース',
			'settings.help.description' => 'コミュニティとサポート',
			'settings.help.forums' => 'Ham2K フォーラム',
			'settings.help.forumsDescription' => 'ヘルプを探す、フィードバックを送る、アイデアを語り合う…',
			'settings.help.chat' => 'Ham2K チャット',
			'settings.help.chatDescription' => 'オンラインコミュニティのDiscordサーバー',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'ビデオとライブストリーム',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => '写真は多すぎて困ることはないので…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => '新着・更新情報についてフォローする',
			'settings.help.contact' => 'お問い合わせ',
			'settings.help.contactDescription' => 'help@ham2k.com（まずはフォーラムやチャットをお試しください！）',
			'settings.exports.title' => 'エクスポート',
			'settings.extensionSections.activities' => 'アクティビティ',
			'settings.extensionSections.hunting' => 'ハンティング',
			'settings.extensionSections.contests' => 'コンテスト',
			'settings.extensionSections.lookups' => '検索',
			'settings.extensionSections.dashboard' => 'ダッシュボード',
			'settings.map.title' => '地図',
			'settings.map.style.title' => '地図スタイル',
			'settings.map.showCallsigns.title' => 'コールサインを表示',
			'settings.map.showCallsigns.description' => '各コンタクトを、バンドの色のコールサイン付きピルで表示します',
			'settings.map.showGrayline.title' => 'グレイラインを表示',
			'settings.map.showGrayline.description' => '地球の夜側を暗くし、薄明をグラデーションで表示します',
			'settings.map.styleOpts.automatic' => '自動',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'プライバシー',
			'settings.privacy.shareAppData.title' => 'アプリ使用データを共有',
			'settings.privacy.shareAppData.descriptionOn' => '使用状況、設定、クラッシュ、パフォーマンスのデータを共有して、アプリの改善に協力しています',
			'settings.privacy.shareAppData.descriptionOff' => 'アプリの使用データを非公開にしています。\nHam2Kチームはクラッシュやその他の問題を検出できません。',
			'settings.privacy.shareOpData.title' => 'オペレーションデータを共有',
			'settings.privacy.shareOpData.descriptionOn' => '一部のオペレーションデータを公開し、他のユーザーと共有しています',
			'settings.privacy.shareOpData.descriptionOff' => 'オペレーションデータをプライベートに保っています',
			'settings.privacy.privacyPolicy' => 'プライバシーポリシー',
			'settings.privacy.termsOfService' => '利用規約',
			'settings.operatorCall' => 'オペレーターのコールサイン',
			'settings.sync.title' => 'クラウド同期',
			'settings.sync.moreSettings' => 'その他の同期設定',
			'settings.sync.enable' => '同期を有効化',
			'settings.sync.deviceKey' => 'デバイスキー',
			'settings.peers.title' => 'ピアデバイス',
			'settings.peers.enable' => '他のデバイスに接続',
			'settings.peers.enableDescription' => 'ローカルネットワーク経由で、他のデバイスとオペレーション、ロギング、CAT、GPSを共有できるようにします',
			'settings.peers.bleEnable' => 'Bluetoothで接続',
			'settings.peers.bleDescription' => 'ローカルネットワークがなくてもBluetooth LEで接続します',
			'settings.peers.thisDevice' => 'このデバイス',
			'settings.peers.deviceName' => '名前',
			'settings.peers.deviceNameHint' => '他のデバイスからこのデバイスがどう見えるか',
			'settings.peers.pairedDevices' => 'リンク済みデバイス',
			'settings.peers.noPairedDevices' => 'リンク済みのデバイスはまだありません。リンクするには、同じネットワーク上の別のデバイスでこれをオンにしてください。',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'リンク済みデバイスを読み取れません：${error}',
			'settings.peers.nearby' => '近くのデバイス',
			'settings.peers.connected' => '接続済み',
			'settings.peers.viaBluetooth' => 'Bluetooth経由',
			'settings.peers.connecting' => '接続中…',
			'settings.peers.syncing' => '同期中…',
			'settings.peers.waitingForThem' => '相手のデバイスを待っています',
			'settings.peers.notConnected' => '未接続',
			'settings.peers.wantsToPair' => 'がこのオペレーションの共有を求めています',
			'settings.peers.allow' => '許可',
			'settings.peers.link' => 'リンク',
			'settings.peers.reject' => '拒否',
			'settings.peers.forget' => '登録解除',
			'settings.peers.forgetTitle' => ({required Object name}) => '${name}の登録を解除しますか？',
			'settings.peers.forgetBody' => 'このデバイスとの同期を停止します。後で再び許可でき、記録済みのコンタクトは保持されます。',
			'settings.peers.pairTitle' => ({required Object name}) => '${name}とリンク',
			'settings.peers.pairBody' => 'このデバイスはローカルネットワーク上にあり、接続を求めています。',
			'settings.peers.pairBodyBle' => 'このデバイスは近くにあり、Bluetooth LEでの接続を求めています。',
			'settings.peers.pairIdLabel' => 'デバイスID',
			'settings.peers.pairWarning' => '見覚えのあるデバイスとのみリンクしてください。このネットワーク上のどのデバイスもリクエストを送信できます。',
			'settings.peers.pairWarningBle' => '見覚えのあるデバイスとのみリンクしてください。近くのどのデバイスもリクエストを送信できます。',
			'settings.peers.problem' => ({required Object error}) => 'ローカルネットワークに接続できません：${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth：${error}',
			'settings.peers.statusConnected' => ({required Object device}) => '${device}に接続しました',
			'settings.peers.statusLost' => ({required Object device}) => '${device}との接続が切れました',
			'settings.peers.statusPerma' => ({required Object linked, required Object connected}) => 'ピアデバイス：${linked}台中${connected}台が接続中',
			'settings.peers.screenEnable' => '画面とウィンドウを共有',
			'settings.peers.screenDescription' => '他のデバイスがこのコンピューターの画面やウィンドウを表示できるようにします',
			'settings.peers.screenSources' => '画面とウィンドウ',
			'settings.peers.screenRefresh' => 'リストを更新',
			'settings.peers.screenUnsupportedPlatform' => 'このデバイスは画面を共有できません。macOSでは共有でき、どのデバイスでも他のデバイスが共有した画面を表示できます。',
			'settings.peers.screenUnsupportedVersion' => '画面の共有にはmacOS 12.3以降が必要です。このデバイスでも他のデバイスが共有した画面は表示できます。',
			'settings.peers.screenNeedsPermission' => 'このアプリが画面を共有するには、macOSで画面収録の許可が必要です。',
			'settings.peers.screenGrantPermission' => '許可をリクエスト',
			'settings.peers.screenRelaunchAfterGranting' => 'システム設定の「プライバシーとセキュリティ」→「画面収録」で許可してから、このアプリを終了して開き直してください。macOSは次回起動時にのみ変更をアプリに伝えます。',
			'settings.peers.screenProblem' => ({required Object error}) => '画面共有：${error}',
			'settings.peers.screenChooseTitle' => '共有するものを選択',
			'settings.peers.screenChooseButton' => '共有するものを選択…',
			'settings.peers.screenTabScreens' => '画面',
			'settings.peers.screenTabApps' => 'アプリ',
			'settings.peers.screenTabWindows' => 'ウィンドウ',
			'settings.peers.screenTabEmpty' => 'この種類のものは見つかりませんでした。',
			'settings.peers.screenSharedSummaryNone' => 'まだ何も選択されていません。',
			'settings.peers.screenThisDevice' => 'このデバイス',
			'settings.peers.screenSharedTo' => ({required Object devices}) => '${devices}に表示中',
			'settings.peers.screenSharedToNobody' => '表示されていません',
			'settings.peers.screenStopSharing' => ({required Object name}) => '${name}の共有を停止',
			'settings.developerMode' => '開発者モード',
			'settings.syncPanel.configuration' => '同期の構成',
			'settings.syncPanel.enableTitle' => 'Ham2K Log Filerと同期',
			'settings.syncPanel.enabledDescription' => 'ログをバックアップし、デバイス間で同期しています',
			'settings.syncPanel.disabledDescription' => 'オフ：このデバイスのみに保存',
			'settings.syncPanel.syncing' => '同期中',
			'settings.syncPanel.account' => 'アカウント',
			'settings.syncPanel.refresh' => '更新',
			'settings.syncPanel.switchAccounts' => 'アカウントを切り替え',
			'settings.syncPanel.switchAccountsDescription' => 'QRコードまたはメールで、このデバイスを別のアカウントにリンク',
			'settings.syncPanel.connectionRequests' => '接続リクエスト',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '1台のデバイスがこのアカウントへの参加を待っています', other: '${n}台のデバイスがこのアカウントへの参加を待っています', ), 
			'settings.syncPanel.accountEmailTitle' => 'アカウントのメール',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => '${email}に確認メールを送信しました。メール内のリンクを開いて変更を完了してください。',
			'settings.syncPanel.resendConfirmation' => '確認メールを再送信',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => '${email}の確認待ち',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => '${email}に再送信しました。',
			'settings.syncPanel.deviceLinked' => 'そのデバイスはこのアカウントにリンクされました。',
			'settings.syncPanel.checking' => '確認中…',
			'settings.syncPanel.notLinked' => 'まだリンクされていません',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account}（#${id}）',
			'settings.syncPanel.replaceDialogTitle' => 'ローカルデータを置き換えますか？',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${n}件のオペレーション', other: '${n}件のオペレーション', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${n}件のQSO', other: '${n}件のQSO', ), 
			'settings.syncPanel.counts' => '同期データ',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'このデバイス：${qsos}・${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'アップロード待ち：${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'サーバー：${qsos}・${operations}',
			'settings.syncPanel.countsLocalChecking' => 'このデバイス：確認中…',
			'settings.syncPanel.countsServerChecking' => 'サーバー：確認中…',
			'settings.syncPanel.countsServerUnavailable' => 'サーバー：利用不可',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'このデバイスの${operations}と${qsos}をバックアップしてから消去し、代わりにアカウントのデータをダウンロードします。バックアップはこのデバイスのデータベースに残ります。',
			'settings.syncPanel.replace' => '置き換え',
			'settings.syncPanel.pendingBannerTitle' => '新しいHam2K Log Filerアカウントを検出しました',
			'settings.syncPanel.pendingBannerBody' => 'このデバイスの既存のオペレーションとQSOを保持してアカウントに結合するか、アカウントのデータで置き換えてください（どちらの場合もバックアップはこのデバイスに残ります）。',
			'settings.syncPanel.combine' => '結合',
			'settings.syncPanel.authIssueTitle' => '同期で接続できません',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filerがこのデバイスを拒否し続けています。同期設定でコールサインを確認してください。',
			'settings.syncPanel.openSettings' => '同期設定を開く',
			'settings.accounts.title' => 'アカウント、サービス、データソース',
			'settings.accounts.none' => 'アカウントを持つ有効な拡張機能はありません',
			'settings.accounts.notConfigured' => '未設定',
			'settings.accounts.connected' => '接続済み',
			'settings.accounts.cancelLogin' => 'ログインをキャンセル',
			'settings.accounts.openInBrowser' => 'ブラウザで開く',
			'settings.accounts.loggedInAs' => ({required Object identity}) => '${identity}としてログイン中',
			'settings.accounts.pressSaveToKeep' => 'このアカウントの接続を維持するには保存を押してください。',
			'settings.accounts.connectedTo' => ({required Object label}) => '${label}に接続済み',
			'settings.accounts.connect' => '接続',
			'settings.accounts.disconnect' => '切断',
			'settings.accounts.connectedAs' => '接続中のアカウント',
			'settings.accounts.test' => 'テスト',
			'settings.accounts.saveFailed' => ({required Object error}) => '保存に失敗しました：${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'ログインに失敗しました：${error}',
			'settings.accounts.lookupFailed' => '現在アカウントを利用できません。しばらくしてから再試行してください',
			'settings.accounts.browserLoginTitle' => 'Webブラウザでログインを完了してください',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => '完了すると、ブラウザは「${prefix}」で始まるリンクを開こうとします。デスクトップにはそれを開くアプリが登録されていない可能性が高いため、そのリンク（アドレスバー、またはブラウザが表示するエラーページから）をコピーしてここに貼り付けてください。',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Loggerはブラウザを開けませんでした。下のログインリンクをコピーして自分で開き、その後移動先のリンク（「${prefix}」で始まる）をコピーしてここに貼り付けてください。',
			'settings.accounts.copyLoginLink' => 'ログインリンクをコピー',
			'settings.accounts.pastedLinkLabel' => 'ここにリンクを貼り付け',
			'settings.accounts.finishLogin' => 'ログインを完了',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'これはログインリンクではありません。「${prefix}」で始まる必要があります。',
			'settings.accounts.pastedLinkWrongLogin' => 'そのリンクは別のログイン試行のものです。このページを閉じて、もう一度接続してください。',
			'settings.accounts.pastedLinkNoCode' => 'そのリンクにはログインコードがありません。まずログインを完了してから、移動先のリンクをコピーしてください。',
			'settings.accounts.pastedLinkMalformed' => 'そのリンクは途中で切れているようです。全体をコピーして、もう一度貼り付けてください。',
			'settings.accounts.relayLoginWaiting' => 'ログインの完了を待っています。完了すると自動的に続行します。',
			'settings.accounts.loginNoResponse' => 'このデバイスはまだログインの結果を受け取っていません。ブラウザですでに完了した場合は、キャンセルしてもう一度接続してください。',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Loggerはブラウザを自動的に開けませんでした。下のボタンでログインページを自分で開いてください。',
			'settings.accounts.relayLoginUnavailable' => 'このログインの完了に必要な同期サーバーに接続できませんでした。接続を確認して再試行してください。',
			'settings.accounts.loginIncompleteResponse' => 'そのログイン試行は正しく完了しませんでした。もう一度接続してください。',
			'settings.accounts.noKeyringTitle' => 'アカウントのログイン情報を保存できません',
			'settings.accounts.noKeyringText' => 'Ham2K Loggerはこのコンピューターのキーリングサービスに接続できないため、アカウントのログイン情報を保存も読み取りもできません。これが解決するまで、アカウントの接続は失敗します。**gnome-keyring**、**KWallet**、または**KeePassXC**をインストールして起動するか、既存のキーリングのロックを解除してから再起動してください。ロギング、エクスポート、データファイルには影響しません。この状態の間、ログの同期はオフのままです。',
			'settings.accounts.noKeyringInline' => 'ログイン情報を保存できません：このコンピューターのキーリングに接続できません。gnome-keyring、KWallet、KeePassXCのいずれかをインストールして起動するか、既存のキーリングのロックを解除してください。',
			'settings.accounts.noSecureStorageInline' => 'ログイン情報を保存できません：このコンピューターのセキュアストレージに接続できません。',
			'settings.station.title' => 'ステーション構成とCAT制御',
			'settings.station.none' => '機器が設定されていません',
			'settings.station.add' => '追加',
			'settings.station.addTitle' => '機器を追加',
			'settings.station.searchHint' => '機器を検索',
			'settings.station.noMatches' => '一致する機器はありません',
			'settings.station.detectedEquipment' => '検出された機器',
			'settings.station.discoveryUnavailable' => ({required Object error}) => '無線機を探索できません：${error}',
			'settings.station.edit' => '機器を編集',
			'settings.station.name' => '名前',
			'settings.station.nameDescription' => '呼び名（例：「左の無線機」）。任意。',
			'settings.station.transport' => '接続',
			'settings.station.host' => 'アドレス',
			'settings.station.hostDescription' => 'ネットワーク上の無線機のホスト名またはIPアドレス。',
			'settings.station.port' => 'ポート',
			'settings.station.hostRequired' => 'アドレスは必須です',
			'settings.station.portInvalid' => 'ポートは1から65535の範囲で指定してください',
			'settings.station.connect' => '接続',
			'settings.station.disconnect' => '切断',
			'settings.station.remove' => '削除',
			'settings.station.removeTitle' => ({required Object name}) => '${name}を削除しますか？',
			'settings.station.removeMessage' => 'アプリから削除するだけです。機器の設定はそのまま残ります。',
			'settings.station.unknownType' => ({required Object typeKey}) => '認識できない機器の種類「${typeKey}」',
			'settings.station.report' => '報告',
			'settings.station.reportTitle' => 'この無線機について報告',
			'settings.station.reportIntro' => 'この無線機の実際の機種と、動作状況を教えてください。報告はHam2Kチームが読むカードになり、動作させるまでの記述は同じリグを使う次のオペレーターの役に立つかもしれません。',
			'settings.station.reportManufacturer' => 'メーカー',
			'settings.station.reportManufacturerDescription' => '製造元（Icom、Yaesu、Kenwood、Elecraft…）',
			'settings.station.reportManufacturerRequired' => 'メーカーは必須です',
			'settings.station.reportModel' => '機種',
			'settings.station.reportModelDescription' => '無線機自体が表示する機種名（「IC-7300」、「FT-991A」）。',
			'settings.station.reportModelRequired' => '機種は必須です',
			'settings.station.reportOutcome' => '結果はどうでしたか？',
			'settings.station.reportOutcomeWorks' => '問題なく動作',
			'settings.station.reportOutcomeIssues' => '動作したが問題あり',
			'settings.station.reportOutcomeFails' => 'まったく動作しない',
			'settings.station.reportOutcomeRequired' => '結果を教えてください',
			'settings.station.reportComments' => 'コメント',
			'settings.station.reportCommentsPlaceholder' => '動作したこと、しなかったこと、意外だったこと。',
			'settings.station.reportHints' => 'トラブルシューティングのヒント',
			'settings.station.reportHintsPlaceholder' => '他のユーザー向けのトラブルシューティングのヒントがあれば教えてください。',
			'settings.station.reportSend' => '報告を送信',
			'settings.station.reportSending' => '報告を送信中…',
			'settings.station.reportSent' => ({required Object ref}) => 'ありがとうございます。報告は${ref}として登録されました。',
			'settings.station.reportSentNoRef' => 'ありがとうございます。報告を送信しました。',
			'settings.station.reportFailed' => ({required Object error}) => '報告は送信されませんでした：${error}',
			'settings.station.troubleshootingNotes' => 'トラブルシューティングの注意事項',
			'settings.station.mainVfo' => 'メインVFO',
			'settings.station.useAsMainVfo' => 'メインVFOとして使用',
			'settings.station.serialPort' => 'シリアルポート',
			'settings.station.serialPortDescription' => '無線機のCATインターフェースが現れるポート。',
			'settings.station.serialPortNone' => 'シリアルポートが見つかりません',
			'settings.station.serialPortRequired' => 'シリアルポートを選択してください',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'ポート ${n} / ${total}',
			'settings.station.serialPortSuggested' => '推奨',
			'settings.station.serialPortJustNow' => '最近接続',
			'settings.station.serialPortNoDriver' => 'ドライバーなし',
			'settings.station.serialDeviceRequest' => 'USBデバイスを追加…',
			'settings.station.bleDevice' => 'Bluetooth LEデバイス',
			'settings.station.bleDeviceDescription' => '無線機を接続しているシリアルブリッジ。Mode 4のLiNK500MPやBLEシリアルアダプターなど。',
			'settings.station.bleScan' => 'Bluetooth LEデバイスをスキャン…',
			'settings.station.bleScanNoneFound' => 'Bluetooth LEデバイスが見つかりません。ブリッジの電源が入っていて、近くにあり、Bluetooth LEモード（LiNK500MPではMode 4）になっているか確認してください。',
			'settings.station.bleScanFailed' => ({required Object reason}) => 'Bluetooth LEのスキャンを実行できませんでした：${reason}',
			'settings.station.bleOff' => 'Bluetoothがオフになっています。',
			'settings.station.bleDenied' => 'Bluetoothの許可が得られていません。システム設定で許可してから、もう一度お試しください。',
			'settings.station.bleUnsupported' => 'このデバイスにはBluetooth LEがありません。',
			'settings.station.bleStarting' => 'Bluetoothはまだ起動中です。しばらくしてからお試しください。',
			'settings.station.bleConnectFailed' => 'Bluetooth LEデバイスに接続できません。電源が入っていて、近くにあり、他のアプリに接続されていないか確認してください。',
			'settings.station.bleNoSerialService' => ({required Object services}) => 'このBluetooth LEデバイスには、アプリが認識できるシリアルサービスがありません。サービス情報を添えて報告してください：${services}',
			'settings.station.baudRate' => '速度（ボー）',
			'settings.station.baudRateDescription' => '無線機のCATメニューと一致させてください。一致しないと、無線機は無意味なデータを返し、エラーは出ません。',
			'settings.station.serialRtsHigh' => 'RTSをHIGHに保持',
			'settings.station.serialRtsHighDescription' => 'CAT RTSをオンにしたYaesuなど、応答前にRTSを待つ無線機専用です。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTであり、HIGHに保持すると送信します。',
			'settings.station.serialDtrHigh' => 'DTRをHIGHに保持',
			'settings.station.serialDtrHighDescription' => 'FT-817用の一部のRS-232ケーブルなど、DTRから電源を取るCATインターフェース専用です。多くのケーブルではDTRがCWキーイングまたはPTTであり、HIGHに保持すると送信します。',
			'settings.station.serialUsbDriver' => 'USBチップのドライバー',
			'settings.station.serialUsbDriverDescription' => '自動ではほとんどのアダプターを認識します。ポート一覧で「ドライバーなし」と表示されるものについてのみチップを選んでください。チップ名はパッケージやUSBデバイス一覧に記載されています。',
			'settings.station.serialUsbDriverAuto' => '自動',
			'settings.station.civAddress' => '無線機のCI-Vアドレス',
			'settings.station.civAddressDescription' => '無線機のCI-Vメニューに表示される16進数。IC-705の出荷時設定はA4です。',
			'settings.station.civAddressInvalid' => 'CI-Vアドレスは01からFFまでの2桁の16進数です',
			'settings.station.flexSlice' => 'スライス',
			'settings.station.flexSliceDescription' => 'この接続が読み取り、チューニングする無線機のスライス。',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'スライス${letter}',
			'settings.station.flexSliceInvalid' => '無線機のスライスをAからHの中から選んでください',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'スライス${letter}はこの無線機で使用されていません。別のスライスを選ぶか、SmartSDRで作成してください',
			'settings.station.channelNotInUse' => '未使用',
			'settings.station.channelHeldByUnknown' => '別のプログラムが使用中',
			'settings.station.flexNoSlices' => 'この無線機はスライスを報告していません。SmartSDRが動作していて、このクライアントがサブスクライブできることを確認してください',
			'settings.station.spectrumUnsupported' => 'この無線機はCATでスペクトラムを送信しません',
			'settings.station.spectrumRequiresBaud' => '115200 bpsのCATが必要です',
			'settings.station.spectrumNoRadio' => '無線機が接続されていません',
			'settings.station.spectrumWaiting' => '無線機のスペクトラムを待っています…',
			'settings.station.spectrumUnavailable' => 'スペクトラム表示は利用できません',
			'settings.station.spectrumNoDaxChannel' => 'この無線機のDAX IQチャンネルはすべて使用中です',
			'settings.station.spectrumNoPanadapter' => 'このスライスには無線機上のパンアダプターがありません',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => '無線機がDAX IQストリームを拒否しました（エラー ${code}）',
			'settings.station.spectrumNoUdp' => '無線機のスペクトラムデータがこのデバイスに届きません',
			'settings.station.spectrumK4Unavailable' => 'K4のLANスペクトラムを受信できません。再試行中…',
			'settings.station.spectrumK4RemoteUnavailable' => 'K4のリモートスペクトラムを受信できません',
			'settings.station.spectrumScopeRefused' => '無線機がスコープのコマンドを拒否しました',
			'settings.station.spectrumOutOfRange' => '無線機のスコープが表示可能な範囲外に設定されています',
			'settings.station.spectrumBandUnsupported' => 'このバンドでは無線機のスコープを表示できません',
			'settings.station.spectrumSdrNoRadio' => 'リンクした無線機の周波数を待っています…',
			'settings.station.spectrumSdrNotConnected' => 'SDRが接続されていません',
			'settings.station.spectrumSdrNoIf' => 'このSDRの設定で無線機のIF周波数を設定してください',
			'settings.station.sdrRadio' => 'スペクトラムの表示対象',
			'settings.station.sdrRadioDescription' => 'この無線機のスペクトラム表示は、無線機自身のスコープの代わりにこの受信機から描画されます。',
			'settings.station.sdrRadioMain' => 'メインの無線機',
			'settings.station.sdrTuning' => 'アンテナ入力',
			'settings.station.sdrTuningDescription' => '受信機の信号の入力元。独自のアンテナなら無線機に追従して自ら同調し、無線機のIF出力ならIFに留まります。',
			'settings.station.sdrTuningIndependent' => '独自のアンテナ',
			'settings.station.sdrTuningIfTap' => '無線機のIF出力',
			'settings.station.sdrIfHz' => 'IF周波数（Hz）',
			'settings.station.sdrIfHzDescription' => 'IF出力の場合のみ：無線機のダイヤル周波数がIF上で位置する周波数。FT-817なら68330000など。',
			'settings.station.sdrIfInverted' => 'IFが反転している',
			'settings.station.sdrGainDb' => 'ゲイン（dB）',
			'settings.station.sdrGainDbDescription' => '空欄なら受信機の自動ゲインを使います。',
			'settings.station.sdrOffsetHz' => '周波数オフセット（Hz）',
			'settings.station.sdrOffsetHzDescription' => 'アップコンバーター用に、受信機へ送るすべての周波数に加算されます：Ham It Upなら125000000。',
			'settings.station.sdrPpm' => '周波数補正（ppm）',
			'settings.station.rtlDirectSampling' => 'ダイレクトサンプリング',
			'settings.station.rtlDirectSamplingDescription' => 'アップコンバーターなしのRTL-SDR V3でHFを受信する場合用。RTL-SDR V4はこれなしでHFに対応します。',
			'settings.station.rtlDirectSamplingOff' => 'オフ',
			'settings.station.rtlDirectSamplingI' => 'Iブランチ',
			'settings.station.rtlDirectSamplingQ' => 'Qブランチ',
			'settings.station.rtlTcpNotAServer' => 'これはrtl_tcpサーバーではありません',
			'settings.station.rtlTcpNotes' => 'ドングルを接続したコンピューター上で**自分で起動したrtl_tcpサーバー**に接続します。\n\n- **起動**は、他のマシンから接続できるよう `rtl_tcp -a 0.0.0.0` で行います。同じマシン上なら `rtl_tcp` だけで十分です。\n- **ポート**は、`-p` を指定して起動していなければ1234です。\n- **同時に使えるのは1つのプログラムだけ：** rtl_tcpは1つのクライアントにしか対応しません。アプリはスペクトラム表示を出している間だけ接続し、閉じてから数秒後に切断します。\n- **Androidでは**、*SDR driver* アプリがスマートフォン上で同じサーバーを実行します。',
			'settings.station.rspTcpNotes' => 'RSPを接続したコンピューター上で、SDRplayのAPIをインストールして**自分で起動したrsp_tcpサーバー**に接続します。\n\n- **起動**は `rsp_tcp -a 0.0.0.0` で行います。\n- **ポート**は、`-p` を指定して起動していなければ1234です。\n- **同時に使えるのは1つのプログラムだけ：** サーバーは1つのクライアントしか受け付けません。アプリはスペクトラム表示を出している間だけ接続します。',
			'settings.station.n3fjpNoRig' => 'N3FJPに無線機インターフェースが設定されていないため、無線機ではなくN3FJPに入力された内容に従います',
			'settings.station.winkeyerKeyPort' => 'キー出力',
			'settings.station.winkeyerKeyPortDescription' => 'キーヤーの2つの出力ジャックのうち、無線機を接続している方。',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'ポート${n}',
			'settings.station.winkeyerPtt' => 'キーヤーのPTTを使用',
			'settings.station.winkeyerPttDescription' => 'アンプや、PTTが必要な無線機のために、同じジャックのPTTラインをキーイングします。キージャックでキーイングする無線機ではオフのままにしてください。',
			'settings.station.winkeyerNoAnswer' => 'このポートでWinKeyerが応答しませんでした',
			'settings.station.winkeyerStoppedAnswering' => '送信中にWinKeyerが応答しなくなったため、メッセージは破棄されました',
			'settings.station.icomControlPort' => 'コントロールポート（UDP）',
			'settings.station.icomControlPortDescription' => '無線機のControl Port（UDP）。ネットワーク設定で変更するか、別のポートに転送していなければ50001です。',
			'settings.station.icomSerialPort' => 'シリアルポート（UDP）',
			'settings.station.icomSerialPortDescription' => '無線機のSerial Port（UDP）。ネットワーク設定で変更するか、別のポートに転送していなければ50002です。',
			'settings.station.icomPortsDiffer' => 'コントロールポートとシリアルポートは異なる値にしてください',
			'settings.station.radioUser' => '無線機のユーザー名',
			'settings.station.radioPass' => '無線機のパスワード',
			'settings.station.radioLoginDescription' => 'WiFiのパスワードではなく、無線機の Network → Remote のログイン情報です。',
			'settings.station.radioUserRequired' => '無線機のリモート制御用ユーザー名は必須です',
			'settings.station.connectFailedBusy' => 'デバイスは使用中です',
			'settings.station.connectFailedDenied' => 'アクセスが拒否されました',
			'settings.station.connectFailedDevice' => 'デバイスが見つかりません',
			'settings.station.connectFailedUnsupported' => 'このUSBアダプターのチップを認識できるドライバーがありません。チップが分かる場合は、詳細設定の「USBチップのドライバー」で選んでください。',
			'settings.station.connectFailedLines' => 'RTS/DTRを設定どおりに保持できなかったため、ポートを閉じました。別のプログラムがハードウェアハンドシェイクをオンのままにした可能性があります。ケーブルを抜き差ししてください。',
			'settings.station.connectFailedNetwork' => 'ネットワーク上で無線機が見つかりません。アドレスと、電源が入っていて接続可能かを確認してください。',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => 'このデバイスのポート${port}はすでに使用中ですが、応答はそこに届きます。そのポートで待ち受けている他のもの（別のPstRotatorノードを含む）を閉じるか、ポートを変更してください。',
			'settings.station.connectFailedTimeout' => '無線機が時間内に応答しませんでした。電源が入っていて接続可能かを確認してください。',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - 汎用',
			'settings.station.models.icomGeneric' => 'Icom - 汎用',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - 汎用',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - 汎用',
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
			'settings.station.models.rigctld' => 'rigctld経由で制御する無線機',
			'settings.station.models.rigctldNodeName' => 'マイ無線機（rigctld経由）',
			'settings.station.models.flrig' => 'flrig経由で制御する無線機',
			'settings.station.models.flrigNodeName' => 'マイ無線機（flrig経由）',
			'settings.station.models.hrd' => 'Ham Radio Deluxe®経由で制御する無線機',
			'settings.station.models.hrdNodeName' => 'マイ無線機（HRD経由）',
			'settings.station.models.n3fjp' => 'N3FJP経由で制御する無線機',
			'settings.station.models.n3fjpNodeName' => 'マイ無線機（N3FJP経由）',
			'settings.station.models.commander' => 'DXLab Commander経由で制御する無線機',
			'settings.station.models.commanderNodeName' => 'マイ無線機（Commander経由）',
			'settings.station.models.antenna' => 'アンテナ',
			'settings.station.models.key' => 'CWキー',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => '汎用無線機（プレースホルダー）',
			'settings.station.models.placeholderRadioNodeName' => 'マイ無線機',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 Coax Switch',
			'settings.station.models.gs232a' => 'Yaesu GS-232A ローテーターインターフェース',
			'settings.station.models.pstRotator' => 'PstRotator（UDP制御）',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => 'ネットワーク/WiFi',
			'settings.station.transports.secureNetwork' => 'セキュアネットワーク/WiFi',
			'settings.station.transports.usbSerial' => 'USBシリアル',
			'settings.station.transports.wifi' => 'ネットワーク/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetoothシリアル',
			'settings.station.transports.bleSerial' => 'Bluetooth LE',
			'settings.station.transports.placeholder' => 'プレースホルダー',
			'settings.station.troubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.ft891Troubleshooting' => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機側でCAT RTSをOFFにするか、RTSをHIGHに保持をオンにしてください。** **CAT RTS** がオン（FT-891メニュー **05-08**）だと、無線機はRTSがLOWの間は沈黙します。ポートを開いた直後に一度だけ応答し、その後は何も返さないことがあります。無線機本体のUSBポートを選ぶと、詳細設定の **RTSをHIGHに保持** が自動的にオンになります。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTなので、HIGHに保持すると送信してしまいます。その場合は代わりに無線機側でCAT RTSをOFFにしてください。\n- **速度を一致させてください**：無線機のCAT RATE（メニュー **05-06**）と同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。',
			'settings.station.yaesuBinaryTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.yaesuBinaryTroubleshooting' => 'この無線機はYaesuの旧式の5バイトCATを使用し、何か問題があるとまったく応答しません。ほとんどの場合、次のいずれかが原因です：\n\n- **ケーブルでレベル変換が必要です。** 背面のCATジャックはRS-232でもUSBでもなく、CT-62または同等のアダプターが必要です。普通のオーディオケーブルやデータケーブルではCATは動作しません。\n- **速度を一致させてください**：無線機のCAT RATEメニュー（FT-817では **#14**、FT-857やFT-897では **#19**）と同じにします。一致しないと、無線機は何も返さず、エラーも出ません。\n- **このポートでRTSやDTRを決してHIGHにしないでください。** これらの無線機用のほとんどのケーブルでは、それらのラインがPTTとキーイングです。DTRから電源を取る古いインターフェースは例外で、その場合は詳細設定の **DTRをHIGHに保持** をオンにしてください。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのドライバーはYaesuが公開しているCAT仕様表をもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.tenTecTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.tenTecEagleTroubleshooting' => '- **背面のUSB-BポートがCATリンクです。** 無線機はUSBシリアルポートとして表示されます。WindowsではTen-TecのUSB to UARTドライバーが必要で、デバイスマネージャーには「USB to UART (COMx)」として表示されます。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにし、Ten-Tecのファームウェアアップデーターも同様です。\n- **アプリからフィルター幅を設定すると、無線機の電源を入れ直すまでBWツマミが効かなくなります。** これは無線機の仕様です。\n\nこのドライバーはTen-Tecのプログラマーズリファレンスガイドをもとに作成されています。一部しか動作しない場合は、無線機のメニューに表示されるファームウェアバージョンを添えてぜひ報告してください。',
			'settings.station.tenTecOrionTroubleshooting' => '- **SERIAL DATAポートにはストレートのDB-9シリアルケーブルを使ってください。** ヌルモデムケーブルは使えません。\n- **このエントリーはRTSをHIGHに保持します。** OrionはRTSとCTSをハンドシェイクに使うためです。DigirigなどRTSでPTTをキーイングするインターフェースでは、詳細設定の「RTSをHIGHに保持」をオフにしてください。そうしないと、アプリが接続した瞬間に無線機が送信します。\n- **アプリからのCWには、無線機の内蔵キーヤーをオンにする必要があります。** オフだと、無線機はアプリからの送信を無視します。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのドライバーはTen-Tecのプログラマーズリファレンスガイドをもとに作成されており、Orionの実機ではテストされていません。一部しか動作しない場合は、無線機のメニューに表示されるファームウェアバージョンを添えてぜひ報告してください。',
			'settings.station.tenTecNoCw' => 'この無線機のファームウェアはアプリからのCWを受け付けません。Ten-TecはOrionファームウェア1.366で対応を追加しました。',
			'settings.station.tenTecKeyerOff' => '無線機の内蔵キーヤーがオフのため、アプリから送るCWは無視されます。無線機のメニューでキーヤーをオンにしてください。',
			'settings.station.guohetecTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.guohetecTroubleshooting' => 'Q900には2つのCATプロトコルがあり、このエントリーはFT-817の模倣ではなく独自プロトコルを使用します。ここではFT-817ではなく **Guohetec Q900** を選んでください。模倣プロトコルは対応コマンドが少なく、無線機はどちらを使っているかを示しません。\n\n- **USB-CケーブルがCATリンクです**。サウンドカードも同じケーブルで接続されます。このポートでは速度は関係なく、設定値は無視されます。\n- **このポートでRTSやDTRを決してHIGHにしないでください。** シリアルケーブルではそれらのラインがPTTとキーイングです。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **第2世代の無線機は第1世代と動作が異なります**。Menuを長押しして About を開き、HW 2.0なら第2世代です。\n\nこのドライバーはメーカーが公開しているプロトコルをもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.yaesuTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.yaesuTroubleshooting' => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機側でCAT RTSをOFFにする必要があります。** オンのままだと、無線機はアプリがLOWに保つハンドシェイクラインを待ち続けます。Digirig、SignaLink、ほとんどの自作ケーブルではその同じラインがPTTなので、HIGHにすると送信してしまいます。無線機本体のUSBポートを使う場合は、詳細設定の **RTSをHIGHに保持** が代替手段です。この設定の場所は機種によって異なります（FT-891ではメニュー **05-08**）。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **モードはFT-891の対応表に従います。** Yaesuのほとんどの機種はこれと一致しますが、モードの番号付けが異なる無線機では、該当するモードが誤って表示・設定されます。周波数には影響しません。',
			'settings.station.ftdx3000Troubleshooting' => '**無線機のUSBポートでCATを使うには、メニュー037 CAT SELECTをUSBにしてください。** RS232Cに設定すると、CATは背面のジャックになります。\n\nこのエントリーは公開されているCATドキュメントをもとに作成されており、FTDX3000の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.yaesuRs232Troubleshooting' => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **CATジャックはRS-232です。** USB-シリアル変換アダプターとストレートのDB-9ケーブルが必要です。クロス（ヌルモデム）ケーブルではラインが入れ替わり、無線機には何も届きません。\n- **無線機側でCAT RTSをOFFにする必要があります。** オンのままだと、詳細設定の **RTSをHIGHに保持** がオンでない限り、無線機はアプリがLOWに保つハンドシェイクラインを待ち続けます。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\nこのエントリーは公開されているCATドキュメントをもとに作成されており、これらの無線機の実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.yaesuUsbTroubleshooting' => '無線機はコマンドを受信していますが、応答していません。ほとんどの場合、次のいずれかが原因です：\n\n- **無線機の2つのUSBポートのうち1つ目を使用してください。** CATは通常1つ目（Windowsでは **Enhanced** COMポート）にあり、2つ目（**Standard**）はPTTとキーイング用です。ポート選択では、2つを区別できる場合は1つ目を指します。\n- **無線機側でCAT RTSをOFFにするか、RTSをHIGHに保持をオンにしてください。** 無線機の **CAT RTS** メニューがオンだと、RTSがLOWの間は沈黙します。ポートを開いた直後に一度だけ応答し、その後は何も返さないことがあります。無線機本体のUSBポートを選ぶと、詳細設定の **RTSをHIGHに保持** が自動的にオンになります。Digirig、SignaLink、ほとんどの自作ケーブルではRTSがPTTなので、HIGHに保持すると送信してしまいます。その場合は代わりに無線機側でCAT RTSをOFFにしてください。\n- **速度を一致させてください**：無線機のCAT RATEメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。',
			'settings.station.k4SerialNotes' => 'K4背面のUSB-B（PC）ソケットに接続してください。CATにはUSB-PC1とUSB-PC2のどちらも使えます。未使用のポートを選び、無線機のSerial USB-PCn: Baud Rate設定と一致させてください。HaLoは38400を初期値として入力します。必要に応じて変更してください。他のアプリケーションはもう一方のポートかEthernetを使う必要があります。\n\nこの接続は無線機とそのキーヤーを制御しますが、HaLoに音声は送りません。',
			'settings.station.k4TcpNotes' => 'K4のEthernetソケットをローカルネットワークに接続してください。ホスト名またはIPアドレスと、CATポート9200を入力します。パンアダプターやウォーターフォールの表示中、HaLoは同じホストの固定ポート9201を使います。CATポートを変更してもスペクトラムのポートは変わりません。\n\nスペクトラムはメイン受信機を表示します。そのズーム、リファレンス調整、速度の操作はHaLoの表示にのみ影響します。音声ストリーミングには対応していません。',
			'settings.station.k4PowerTimeout' => '無線機が出力範囲を確認しなかったため、K4の出力は変更されませんでした。再試行してください。',
			'settings.station.k4RemoteNotes' => 'K4でリモートアクセスを有効にし、そのネットワークパスワードを入力してください。MainとSubは、無線機制御とスペクトラムのために1つの暗号化接続を共有します。デフォルトのポートは9204です。リモートから接続する場合は転送先のポートを入力してください。\n\n音声の再生とマイクのストリーミングには対応していません。',
			'settings.station.k4Receiver' => '受信機',
			'settings.station.k4ReceiverMain' => 'Main',
			'settings.station.k4ReceiverSub' => 'Sub',
			'settings.station.k4ReceiverInvalid' => 'MainまたはSubを選んでください',
			'settings.station.k4ReceiverAlreadyConfigured' => 'その受信機はこのK4ですでに設定済みです',
			'settings.station.k4SubReceiverOff' => 'K4のサブ受信機がオフです',
			'settings.station.k4RemotePasswordRequired' => '安全に接続するにはK4のネットワークパスワードを入力してください。',
			'settings.station.k4RemoteHandshakeFailed' => 'K4とのセキュアな接続を確立できませんでした。ネットワークパスワードとリモートアクセスの設定を確認してください。',
			'settings.station.k4RemoteUnreachable' => 'K4のセキュア接続に到達できませんでした。アドレス、ポート、リモートアクセスの設定を確認してください。',
			'settings.station.k4PowerRange' => 'K4の出力は0.1〜110 W、トランスバーターのミリワット出力が有効な場合は0.0001〜0.01 Wの範囲で指定してください。',
			'settings.station.elecraftTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.elecraftTroubleshooting' => 'ElecraftのリグはKenwood CATを使用し、KX2とKX3の両方でこの方法による動作が確認されています。VFOの双方向制御、モード切替、CWのゼロビートすべてが動作します。\n\n無線機が応答しない場合、ほとんどの場合は次のいずれかが原因です：\n\n- **速度を一致させてください**：無線機のメニューの **RS232** で設定したレートと同じにします。出荷時は38400です。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n\n**周波数は正しいのにモードが違う場合**は、お知らせください。KX2とKX3のエントリーは、無線機のステータス応答内の特定の位置からモードを読み取っており、その位置はこれまでに確認したリグをもとに固定しています。別の位置に置くファームウェアについては、報告がなければ私たちには分かりません。\n\nK3についてはまだどちらの報告もないため、使用している場合は結果をお知らせください。K4には専用のエントリーがあります。',
			'settings.station.lab599TroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.lab599Troubleshooting' => 'TX-500シリーズはKenwood CATを使用します。周波数とモードはLiNK500MP経由で動作確認済みです。出力とメーターはLab599のCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n- **速度を一致させてください**：無線機のCAT設定と同じにします。変更していなければ9600です。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **無線機側でCATプロトコルを選んでください。** TS-2000は周波数、モード、出力に対応します。LAB599ではさらに、アプリから無線機をDIGに切り替え、DIGでの送信を確認し、電源電圧を読み取れます。\n- **LiNK500MP経由の場合**、VFOツマミを3秒ほど長押しして、CAT制御をインターフェースに渡してください。\n- **接続に合わせてLiNK500MPのモードを設定してください**：BluetoothならMode 3、Bluetooth LEならMode 4です。それ以外のモードではBluetooth LEスキャンで見つかりません。\n- **Bluetooth経由**では、LiNK500MPは2つのシリアルポートとしてペアリングされ、CATを扱うのは片方だけです。無線機が沈黙したままなら、もう一方を選んでください。',
			'settings.station.lab599TroubleshootingIos' => 'TX-500シリーズはKenwood CATを使用します。周波数とモードはLiNK500MP経由で動作確認済みです。出力とメーターはLab599のCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n- **スキャンの前にLiNK500MPをMode 4にしてください**。これがBluetooth LEモードです。それ以外のモードではiPhoneやiPadから見つけられません。\n- **CAT制御をLiNK500MPに渡してください**：無線機のVFOツマミを3秒ほど長押しします。\n- **無線機側でCATプロトコルを選んでください。** TS-2000は周波数、モード、出力に対応します。LAB599ではさらに、アプリから無線機をDIGに切り替え、DIGでの送信を確認し、電源電圧を読み取れます。',
			'settings.station.kenwoodTroubleshootingTitle' => '無線機に接続できても周波数が表示されない場合',
			'settings.station.kenwoodTroubleshooting' => 'このドライバーは、KenwoodのTS-590SGとTS-480、QRP LabsのQMXとQCX-mini、ElecraftのKX2とKX3で動作が確認されています。その他の機種は公開されているCATリファレンスをもとに作成しているため、結果にかかわらずお知らせください。\n\n無線機が応答しない場合、ほとんどの場合は次のいずれかが原因です：\n\n- **速度を一致させてください**：無線機のCATメニューと同じにします。一致しないと、無線機は無意味なデータを返すか何も返さず、エラーは出ません。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。\n- **一部のリグはメニューでCATを有効にする必要があります**。有効にしないとまったく応答しません。\n- **Kenwoodの無線機はRTSを待ちます**：CATポートがRTSをハンドシェイクに使うため、詳細設定の「RTSをHIGHに保持」をオンにする必要があります。これがデフォルトでオンになる前に設定した接続では、オフのままかもしれません。DigirigなどRTSでPTTをキーイングするケーブルではオフにしてください。そうしないと無線機が送信します。\n\n**いくつかのSDRフロントエンドも同じプロトコルを使用している**ため、それらでもこのエントリーを試す価値があります。ElecraftのリグはElecraftの下に別途掲載しています。周波数は正しいのにモードが違う、または表示されない場合、それが機種ごとに異なる唯一の部分です。アプリは無線機からモードを判別し、できなければ直接問い合わせるため、モードの表示が単に遅れているだけかもしれません。',
			'settings.station.statusConnected' => '接続済み',
			'settings.station.statusLost' => '切断',
			'settings.station.notConfigured' => '未設定',
			'settings.station.currentConfiguration' => '現在の構成',
			'settings.station.currentTransceiver' => '現在のトランシーバー',
			'settings.station.currentTransceivers' => '現在のトランシーバー',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}：${name}',
			'settings.station.so2rQueueMessages' => 'メッセージを割り込ませずにキューに入れる',
			'settings.station.noRadioBSelected' => 'Radio Bが選択されていません',
			'settings.station.radioMode' => '無線機のモード',
			'settings.station.keyerNotSupported' => '現在の無線機では未対応',
			'settings.station.catControlPreferences' => 'CAT制御の設定',
			'settings.station.chooseTransceiver' => 'トランシーバーを選択',
			'settings.station.configurationSection' => '構成',
			'settings.station.noTransceiverSelected' => 'トランシーバーが選択されていません',
			'settings.station.makeMainVfo' => ({required Object name}) => 'メインVFOに${name}を使用',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, zero: 'トランシーバーなし', one: 'トランシーバー${count}台', other: 'トランシーバー${count}台', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'アンテナ${count}本', other: 'アンテナ${count}本', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'その他の機器${count}台', other: 'その他の機器${count}台', ), 
			'settings.station.equipmentInventory' => '機器一覧',
			'settings.station.equipmentInUse' => 'トランシーバーの操作',
			'settings.station.noTransceiver' => 'なし',
			'settings.station.peerRadioNotAvailable' => '利用不可',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => '${device}上',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio}は別のデバイス上にあります',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'この無線機は${device}に接続されています。接続と設定はそのデバイスで構成します。',
			'settings.station.antennaInUse' => '使用中のアンテナ',
			'settings.station.keyInUse' => 'CWキーイング',
			'settings.station.phoneKeying' => '電話キーイング',
			'settings.station.phoneKeyingNone' => 'なし',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => '${radio}のメモリー',
			'settings.station.phoneKeyingComputer' => 'このコンピューターの音声',
			'settings.station.phoneKeyingOff' => '電話キーイングはオフです',
			'settings.station.computerVoiceSettings' => 'コンピューターの音声',
			'settings.station.cwKeyingOptions' => 'CWキーイングのオプション',
			'settings.station.noneSelected' => 'なし',
			'settings.station.moreSettings' => 'その他の設定',
			'settings.station.icomCivTroubleshootingTitle' => '同じ無線機に2つのシリアルポートが表示される場合',
			'settings.station.icomCivTroubleshooting' => 'IC-705を含む一部のIcom無線機は、**2つ**のUSBシリアルポート（IcomではPort AとPort Bと呼びます）を同時に提供し、どちらもデフォルトでCI-Vに設定されています。このアプリもOSもそれ以上は区別できず、同じUSBベンダー/プロダクトIDが2回表示されるだけです（ここでは `#2` という接尾辞が付くこともあります）。**通常はPort Aが正解です**。たいていOSやブラウザが最初に表示するもので、このアプリが2つのポートを区別できる場合は推奨として表示します。コマンドを送っても無線機が応答しない場合は、もう一方のポートを試してください。',
			'settings.station.civAddressTroubleshootingTitle' => '無線機がまったく応答しない場合',
			'settings.station.civAddressTroubleshooting' => '- **CI-Vアドレスを一致させてください**：無線機のメニューと同じにします。このエントリーには機種の出荷時アドレスが入力されていますが、CI-Vバスを共有するリグではまさにそれが変更されます。間違ったアドレスに送られたフレームは黙って無視されるため、ケーブルの故障とまったく同じように見えます。\n- **速度を一致させてください**：無線機のCI-V BAUD RATE（USBの場合はCI-V USB Baud Rate）と同じにします。無線機をここに表示されているのと同じ数値に設定し、**Autoにはしないでください**。Autoでは、IC-7300などの一部の無線機は接続後1分ほどで応答しなくなります。\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **CI-Vアドレスを一致させてください**：無線機のメニューと同じにします。このエントリーには機種の出荷時アドレスが入力されていますが、CI-Vバスを共有するリグではまさにそれが変更されます。間違ったアドレスに送られたフレームは黙って無視されるため、ケーブルの故障とまったく同じように見えます。\n${speed}\n- **別のアプリがポートを使用中の可能性があります**：WSJT-X、fldigi、rigctldはいずれもポートを開いたままにします。',
			'settings.station.icomUsbSpeedFollows' => '- **設定する速度はありません。** USB経由では、この無線機はコンピューターが使う速度で通信します。このエントリーは常に、スコープに必要な速度である115200を使います。',
			'settings.station.ic7610UsbSpeed' => '- **CI-V USB Baud Rateを115200にしてください**。スコープに必要なため、このエントリーは常にこの速度を使います。**Autoにはしないでください**。他の速度に設定された無線機は何も返しません。',
			'settings.station.civTransceiveTitle' => 'アプリが無線機の操作に追従するのが遅い場合',
			'settings.station.civTransceive' => '無線機で変更した周波数やモードがアプリに表示されるまで数秒かかる場合は、無線機の **CI-V Transceive** 設定をオンにしてください（最近の機種ではSET > Connectors > CI-Vにあります）。オンにすると、無線機は変更があった瞬間にそれを報告します。オフだと、アプリは数秒ごとの次回の問い合わせまで変更に気づきません。',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2** の出荷時アドレスは、ここに入力されている `94` ではなく `B6` です。代わりにIC-7300 MK2のエントリーを選んでください。',
			'settings.station.ic705PortNote' => '\n- **IC-705** は、どちらも無線機の名前が付いた2つのUSBシリアルポートを提供します。CI-Vはそのうち **1つ目** にあり、ポート選択では2つを区別できる場合はそちらを指します。',
			'settings.station.ic7760PortNote' => '\n- **IC-7760** は、提供する2つのUSBシリアルポートのうち **Port A** でCI-Vを使用します。',
			'settings.station.x6100PortNote' => '\n- **X6100** は **DEV** ポートでCI-Vを使用します。提供する2つのシリアルポートのうち2つ目で、ポート選択はこちらを指します。',
			'settings.station.rigctldTroubleshootingTitle' => 'アプリが接続できない場合',
			'settings.station.rigctldTroubleshooting' => 'これは無線機に直接ではなく、**ご自身で実行するrigctldデーモン**に接続します。Hamlibのバックエンドが無線機と通信し、数百の機種に対応しています。\n\n- **デーモンがすでに実行中である必要があります**。例：`rigctld -m 1035 -r /dev/ttyUSB0`。無線機の機種番号は `rigctl -l` で確認できます。\n- **別のマシンから接続する場合**は、`-T 0.0.0.0` を付けて起動してください。デフォルトでは、rigctldは実行中のマシンからの接続のみを受け付けます。\n- **ポート** は、デーモンを `-t` で起動していない限り4532です。\n- 接続後に周波数が表示されない場合、通常はデーモン自体が無線機に接続できていません。デーモンのマシンで `rigctl -m 2 f` を実行してテストしてください。',
			'settings.station.flrigTroubleshootingTitle' => 'アプリが接続できない場合',
			'settings.station.flrigTroubleshooting' => 'これは無線機に直接ではなく、**ご自身で実行するflrigプログラム**に接続します。flrigが無線機と通信し、ほとんどのメーカーと機種に対応しています。\n\n- **flrigがすでに実行中である必要があります**。トランシーバーが設定され、接続されている状態にしてください。\n- **ポート** は、flrigの設定（Config → Setup → Server）で変更していない限り12345です。\n- **別のマシンから接続する場合**は、flrigのサーバーに接続できることを確認してください。flrigはすべてのインターフェースで待ち受けますが、ファイアウォールが許可しない場合があります。\n- 接続後に周波数が表示されない場合、通常はflrig自体が無線機に接続できていません。flrigの表示がダイヤルに追従しているか確認してください。',
			'settings.station.hrdTroubleshootingTitle' => 'アプリが接続できない場合',
			'settings.station.hrdTroubleshooting' => 'これは無線機に直接ではなく、**コンピューター上で実行中のHam Radio DeluxeのRig Control**に接続します。HRDが無線機と通信します。\n\n- **Rig Controlがすでに実行中で**、無線機に接続されている必要があります。\n- **IPサーバーを有効にする必要があります。** Rig Controlは他のプログラムとはそれを通じてのみ通信します。\n- **ポート** は、IPサーバーの設定で変更していない限り7809です。\n- **別のマシンから接続する場合**は、ファイアウォールが接続を許可していることを確認してください。\n\nこのエントリーは公開されているHRDのプロトコル説明をもとに作成されており、HRDの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.n3fjpTroubleshootingTitle' => 'アプリが接続できない場合',
			'settings.station.n3fjpTroubleshooting' => 'これは無線機に直接ではなく、**コンピューター上で実行中のN3FJPロギングプログラム**に接続します。N3FJPが無線機と通信します。\n\n- **プログラムのAPIをオンにする必要があります**：Settings → Application Program Interface で **TCP API Enabled** にチェックします。\n- **ポート** は、そこで変更していない限り1100です。\n- 無線機に追従またはチューニングするには、**N3FJPに無線機インターフェースが設定されている必要があります**。設定がない場合、入力ウィンドウに入力された内容のみを報告します。\n- N3FJPが報告するのはバンド、モード、周波数のみで、出力や送信状態は報告しません。\n\nこのエントリーは公開されているN3FJPのAPIをもとに作成されており、N3FJPの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.commanderTroubleshootingTitle' => 'アプリが接続できない場合',
			'settings.station.commanderTroubleshooting' => 'これは無線機に直接ではなく、**コンピューター上で実行中のDXLab Commander**に接続します。Commanderが無線機と通信します。\n\n- **Commanderがすでに実行中で**、無線機に接続されている必要があります。\n- **ネットワークサービスをオンにする必要があります**：CommanderのConfigurationウィンドウのRadioパネルにある **Net Serv** ボタンです。\n- **ポート** は52002で、Net Servの **Base Port**（変更していなければ52000）から始まるブロックの3番目のポートです。\n- **別のマシンから接続する場合**は、ファイアウォールが接続を許可していることを確認してください。\n\nこのエントリーは公開されているCommanderのTCPメッセージをもとに作成されており、Commanderの実機ではテストされていません。一部しか動作しない場合は、ぜひ報告してください。',
			'settings.station.ic705TroubleshootingTitle' => '無線機がまったく応答しない場合',
			'settings.station.ic705Troubleshooting' => 'この無線機のリモート制御セッションは **1つだけ** です。ログインが無視される場合、ほぼ確実に他の何かがそれを使用しています。\n\n- **他のクライアントを閉じてください。** 同じ無線機に接続したwfviewやRS-BA1がそのセッションを保持していると、ここでのログインは単に無視されます。\n- **無線機のネットワーク設定を確認してください。** WLANがオンで、無線機が同じネットワーク上にあり、リモート制御（Network）機能が有効になっている必要があります。\n- **ポートを一致させてください**：無線機のControl PortとSerial Port（UDP）、またはそこへ転送されているポートと同じにします。ポートが間違っていると、電源の切れた無線機と同じく無応答になります。\n- 固まったままの場合は、**無線機のWLANをオフにしてからオンにしてください**。無線機上で固まったセッションを確実に解除できます。\n\n**パスワードが間違っている場合は明示的に拒否され**、無応答にはなりません。「拒否」のメッセージではなくこの画面に来た場合、パスワードは問題ではありません。',
			'settings.station.icomLanTroubleshooting' => 'この無線機のリモート制御セッションは **1つだけ** です。ログインが無視される場合、ほぼ確実に他の何かがそれを使用しています。\n\n- **他のクライアントを閉じてください。** 同じ無線機に接続したwfview、RS-BA1、IcomのRemote Utilityがそのセッションを保持していると、ここでのログインは単に無視されます。\n- **無線機のネットワーク設定を確認してください。** LANポートがこのデバイスと同じネットワークに接続され、**Network Control** がオンで、ユーザー名とパスワードが無線機上のネットワークユーザーとして設定されている必要があります。\n- **ポートを一致させてください**：無線機のControl PortとSerial Port（UDP）、またはそこへ転送されているポートと同じにします。ポートが間違っていると、電源の切れた無線機と同じく無応答になります。\n- **接続しても応答がない場合**は、ここのCI-Vアドレスを無線機のCI-V ADDRESSメニューと一致させてください。このエントリーには機種の出荷時アドレスが入力されています。\n- 固まったままの場合は、**無線機の電源を入れ直してください**。',
			'settings.station.statusStale' => '応答なし',
			'settings.station.statusDisconnected' => '未接続',
			'settings.station.statusConnecting' => '接続中…',
			'settings.station.statusDisconnecting' => '切断中…',
			'settings.station.statusError' => '接続に失敗しました',
			'settings.station.currentRadioSettings' => '現在の無線機の設定',
			'settings.station.notSupportedByThisRadio' => 'この無線機では未対応',
			'settings.station.cwMessagesButton' => 'CWメッセージ',
			'settings.station.voiceMessagesButton' => '電話メッセージ',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'ボイスキーヤー：無線機内のメモリー${count}件',
			'settings.station.antennaBands' => 'バンド',
			'settings.station.antennaType' => 'アンテナの種類',
			'settings.station.antennaTypeRequired' => 'アンテナの種類を選択してください',
			'settings.station.antennaTypes.dipole' => 'ダイポール',
			'settings.station.antennaTypes.vertical' => 'バーチカル',
			'settings.station.antennaTypes.yagiBeam' => '八木 / ビーム',
			'settings.station.antennaTypes.loop' => 'ループ',
			'settings.station.antennaTypes.longWire' => 'ロングワイヤー / EFHW',
			'settings.station.antennaTypes.other' => 'その他',
			'settings.station.keyType' => 'キーの種類',
			'settings.station.keyTypeRequired' => 'キーの種類を選択してください',
			'settings.station.keyTypes.straight' => '縦振れ電鍵',
			'settings.station.keyTypes.sideswiper' => '横振れ電鍵（サイドスワイパー）',
			'settings.station.keyTypes.bug' => 'バグキー（機械式半自動）',
			'settings.station.keyTypes.fullyAutomatic' => '全自動キーヤー',
			'settings.station.keyTypes.singlePaddle' => 'シングルパドル',
			'settings.station.keyTypes.dualPaddle' => 'デュアルパドル',
			'settings.station.keyTypes.computerDriven' => 'コンピューター制御',
			'settings.station.keyTypes.other' => 'その他',
			'settings.station.softwareIntermediaries' => '中継ソフトウェア',
			'settings.station.otherBrands' => 'その他のブランド',
			'settings.station.otherEquipment' => 'その他の機器（アンテナ、キーなど）',
			'settings.station.newAntenna' => '新しいアンテナ',
			'settings.station.newKey' => '新しいキー',
			'settings.station.newKeyer' => 'WinKeyer（K1ELまたは互換機）',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyViaRadio' => ({required Object radio}) => '${radio}のCATキーヤー',
			'settings.station.keyOnDevice' => ({required Object device}) => '${device}のキー',
			'settings.station.trackStationInfo' => 'QSOごとにステーション情報を記録',
			'settings.station.includeStationInfoInAdif' => 'ADIFエクスポートに含める',
			'settings.station.whatToTrack' => '記録する項目',
			'settings.station.trackFieldRig' => 'トランシーバー',
			'settings.station.trackFieldPower' => 'パワー',
			'settings.station.watts' => 'ワット',
			'settings.station.trackFieldAntenna' => 'アンテナ',
			'settings.station.trackFieldKey' => 'CWキー',
			'settings.station.placeholderConnectDelay' => '接続遅延（ms）',
			'settings.station.placeholderConnectDelayDescription' => 'シミュレートしたハンドシェイクにかかる時間。空欄または0で即座に接続します。',
			'settings.station.placeholderDropAfter' => '切断までの時間（秒）',
			'settings.station.placeholderDropAfterDescription' => '再接続の処理を試すため、接続を自動的に閉じます。空欄または0で切断しません。',
			'settings.station.placeholderFailConnect' => '常に接続に失敗する',
			'settings.station.placeholderConnectFailure' => 'プレースホルダー無線機はこの接続を拒否するよう設定されています',
			'settings.station.placeholderFreq' => '周波数（kHz）',
			'settings.station.placeholderFreqDescription' => 'プレースホルダー無線機の初期周波数。その後はアプリがチューニングした値を報告します。',
			'settings.station.placeholderMode' => 'モード',
			'settings.station.placeholderModeDescription' => 'プレースホルダー無線機の初期モード（例：USB、CW、FT8）。',
			'settings.station.placeholderPower' => 'パワー（ワット）',
			'settings.station.placeholderPurpose' => 'ロギングのために、使用中のリグを記録するための無線機です',
			'settings.station.placeholderReplyDelay' => '応答遅延（ms）',
			'settings.station.placeholderReplyDelayDescription' => 'プレースホルダー無線機が変更を報告するまでの時間。空欄または0で即座に応答します。',
			'settings.station.cwKeyerField' => 'CAT CWキーヤー',
			'settings.station.cwKeyerFieldDescription' => 'この無線機がCAT経由のテキストでCWをキーイングするかどうか。アプリが認識していないリグではオフ。',
			'settings.station.voiceMemories' => 'ボイスメモリー',
			'settings.station.voiceMemoriesDescription' => '無線機がCAT経由で再生するボイスメモリーの数。ない場合は0。',
			'settings.station.voiceMemoriesInvalid' => '0以上の整数',
			'settings.station.yaesuMeterCapture' => 'メーターの値を記録',
			'settings.station.yaesuBinaryMeterCaptureDescription' => '送信中に無線機の出力メーターと高SWRフラグを読み取り、生の値をログに出力します。Yaesuが公開していない目盛りを作成するためのもので、値はメーターとして表示されません。',
			'settings.station.yaesuMeterCaptureDescription' => '送信中に無線機のPO、SWR、ALCメーターを読み取り、生の値をログに出力します。Yaesuが公開していない目盛りを作成するためのもので、値はメーターとして表示されません。',
			'settings.station.telemetryInterval' => 'メーター読み取り間隔（ms）',
			'settings.station.telemetryIntervalDescription' => '送信中に無線機のメーターを読み取る頻度。空欄にすると、この接続で可能な最速（最大200 ms）になります。',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => '${min}〜${max}のミリ秒単位の整数',
			'settings.station.pollInterval' => 'アイドル時のポーリング間隔（ms）',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => '周波数とモードが変化していない間に、無線機に問い合わせる頻度。空欄の場合は${fallback} msです。',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => '${min}〜${max}のミリ秒単位の整数',
			'settings.station.advancedSettings' => '詳細設定',
			'settings.station.placeholderSwr' => 'SWRの値',
			'settings.station.placeholderSwrDescription' => '送信中にこの無線機がSWRメーターで報告する値。1.8を超えるとパネルが警告します。',
			'settings.station.placeholderSwrInvalid' => '1以上の数値',
			'settings.station.keyerNone' => 'なし',
			'settings.station.cwDialect' => 'CWキーイングの方式',
			'settings.station.cwDialectDescription' => 'この無線機が受け付けるKYコマンドの形式。なしの場合、CAT経由のCWキーイングは行いません。',
			'settings.station.cwDialectKenwood' => 'Kenwood（KY、24文字にパディング）',
			'settings.station.cwDialectElecraft' => 'Elecraft（KYテキスト）',
			'settings.station.voiceDialect' => 'ボイスキーヤーの方式',
			'settings.station.voiceDialectDescription' => 'この無線機がCAT経由でボイスメモリーを再生する方式。なしの場合、CAT経由のボイスメモリーは使用しません。方式を選んで数を指定しない場合は、その方式のデフォルトの数が適用されます。',
			'settings.station.voiceDialectPb' => 'Kenwood（PB、TS-590方式）',
			'settings.station.voiceDialectK4' => 'Elecraft K4（PBとDA）',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3（スイッチタップ）',
			'settings.station.placeholderDiagnostic' => 'シミュレーション',
			'settings.station.placeholderWholeNumberInvalid' => '0以上の整数を入力してください',
			'settings.station.placeholderFreqInvalid' => '0より大きいkHz単位の周波数を入力してください',
			'settings.station.placeholderModeInvalid' => 'モード名を入力してください（例：USB、CW、FT8）',
			'settings.station.switchLayout' => 'レイアウト',
			'settings.station.switchLayoutDescription' => '無線機をスイッチのどちら側に接続しているか。',
			'settings.station.switchLayoutRequired' => 'スイッチの配線を選択してください',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'スイッチが「${command}」を拒否しました（エラー ${code}）',
			'settings.station.switchBusyTransmitting' => 'そのポートは送信中です。アンテナは変更されませんでした',
			'settings.station.switchNoAntenna' => 'なし',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'ポート${port}のアンテナ',
			'settings.station.switchAntennaForDescription' => 'スイッチのこのポートに接続されているアンテナ。',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => 'アンテナ${antennas}本、無線機${radios}台',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => 'アンテナ${antennas}本、無線機1台',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => 'アンテナ1本、無線機${radios}台',
			'settings.station.switchCommonPort' => '共通',
			'settings.station.dcnAddress' => 'デバイスアドレス',
			'settings.station.dcnAddressDescription' => 'モジュールのDIPスイッチで設定したアドレス。同軸リレーモジュールの出荷時設定は2です。',
			'settings.station.dcnAddressRequired' => '1〜99のデバイスアドレスを入力してください',
			'settings.station.switchPortLabel' => ({required Object port}) => 'ポート${port}',
			'settings.station.switchPortAutoHint' => 'バンドデータに追従',
			'settings.station.switchPortTransmittingHint' => '送信中：今は変更できません',
			'settings.station.switchCurrentStateHeader' => '現在の状態',
			'settings.station.switchCurrentStateDescription' => '各無線機ポートが現在どのアンテナに接続されているか。変更は即座に反映されます。',
			'settings.station.switchWiringHeader' => '配線',
			'settings.station.switchPortInhibitedHint' => '送信禁止',
			'settings.station.rotatorAxes' => '軸',
			'settings.station.rotatorAxesDescription' => 'ローテーターが方位のみ回るか、仰角も回るか（G-5500など）。',
			'settings.station.rotatorAxesAzimuth' => '方位のみ',
			'settings.station.rotatorAxesAzimuthElevation' => '方位と仰角',
			'settings.station.rotatorAzimuthOffset' => '方位オフセット',
			'settings.station.rotatorAzimuthOffsetDescription' => 'コントローラーのゼロが真北でない場合に、読み取り値に加える角度（度）。回転もこれに合わせて補正されます。',
			'settings.station.rotatorElevationOffset' => '仰角オフセット',
			'settings.station.rotatorAzimuthMin' => '方位の下限',
			'settings.station.rotatorAzimuthMax' => '方位の上限',
			'settings.station.rotatorAzimuthMaxDescription' => 'コントローラー自身の角度で指定します。オーバーラップのあるローテーターでは360より大きくすると、短い方の回転を選びます。',
			'settings.station.rotatorElevationMin' => '仰角の下限',
			'settings.station.rotatorElevationMax' => '仰角の上限',
			'settings.station.rotatorElevationMaxDescription' => 'コントローラー自身の角度で指定します。反転できるローテーターでは90より大きくします。',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => '${min}〜${max}の整数（度）',
			'settings.station.rotatorLimitsInvalid' => '下限は上限より小さくしてください',
			'settings.station.rotatorPollInterval' => 'ポーリング間隔（ms）',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => 'ローテーターの向きを問い合わせる頻度。空欄の場合は${fallback} msです。',
			'settings.station.rotatorAxesRequired' => 'ローテーターが回る軸を選んでください',
			'settings.station.rotatorRefused' => 'コントローラーがコマンドを拒否しました。GS-232モードに設定されているか確認してください。',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotatorは設定が済んでいるときだけ応答し、それ以外はまったく何も返しません：\n\n- **UDP Controlをオンにしてください**：PstRotatorのSetupメニューにあります。\n- **ポートを一致させてください**：Communication → UDP Control Port、変更していなければ12000です。PstRotatorは次のポート（12001）で応答するため、このデバイスでそのポートが空いている必要があります。\n- **PstRotatorをコントローラーに接続してください。** 接続されるまで、UDPでは何も応答しません。\n- **ファイアウォールで許可してください**：PstRotatorを実行しているPCと、応答を待ち受けるこのデバイスの両方で。\n- **Mac、iPhone、iPadでは**、Ham2K Loggerにローカルネットワークへのアクセスが必要です（設定 → プライバシーとセキュリティ → ローカルネットワーク）。',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => '現在の状態：${position}',
			'settings.station.rotatorDisconnected' => '未接続',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '方位${degrees}°',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => '方位${degrees}°',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '仰角${degrees}°',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => '仰角${degrees}°',
			'settings.station.rotatorNoReading' => 'コントローラーが位置を報告するのを待っています…',
			'settings.station.rotatorNotResponding' => '応答なし',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => '${heading}へ、このローテーターの制限内で可能な限り回転中',
			'settings.station.rotatorTargetAzimuth' => '方位へ回転',
			'settings.station.rotatorTargetAzimuthShort' => '方位へ',
			'settings.station.rotatorTargetElevation' => '仰角へ回転',
			'settings.station.rotatorTargetElevationShort' => '仰角へ',
			'settings.station.rotatorAzimuthInvalid' => '0〜360で指定してください',
			'settings.station.rotatorElevationInvalid' => '0〜180で指定してください',
			'settings.station.rotatorTurn' => '回転',
			'settings.station.rotatorStop' => '停止',
			'settings.station.configUnreadable' => 'この無線機の保存済み設定を読み取れませんでした。設定を開いて再入力するか、削除して追加し直してください。',
			'settings.station.autoConnectHeld' => '前回この無線機に接続したときにHaLoが応答しなくなったため、今回は自動的に接続しませんでした。再試行するには接続を押してください。',
			'settings.offlineData.title' => 'オフラインデータ',
			'settings.offlineData.noFiles' => 'データファイルなし',
			'settings.offlineData.noFilesDescription' => 'アクティビティや検索の拡張機能を有効にすると、ここでオフラインデータをダウンロードできます。',
			'settings.offlineData.refresh' => '更新',
			'settings.offlineData.refreshing' => '更新中…',
			'settings.offlineData.updateAll' => 'すべて更新',
			'settings.offlineData.updatingAll' => 'すべてのデータファイルを更新中…',
			'settings.offlineData.neverDownloaded' => '未ダウンロード',
			'settings.offlineData.updatedJustNow' => 'たった今更新',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '${days}日前に更新',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '${days}日${hours}時間前に更新',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '${hours}時間前に更新',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '${hours}時間${minutes}分前に更新',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '${minutes}分前に更新',
			'settings.offlineData.lastDownloadRefused' => ({required Object existing, required Object imported}) => '前回のダウンロードは${existing}件中${imported}件のレコードしかなかったため、使用しませんでした。受け入れるには更新してください。',
			'settings.offlineData.extensionsSection' => '拡張機能',
			'settings.profiles.notSet' => '未設定',
			'settings.profiles.personalInfo' => '個人情報',
			'settings.profiles.personalInfoNote' => '提出に必要な場合、生成されるログに含まれることがあります',
			'settings.profiles.name' => '名前',
			'settings.profiles.email' => 'メール',
			'settings.profiles.club' => 'クラブ',
			'settings.profiles.arrlSection' => 'ARRLセクション',
			'settings.profiles.racSection' => 'RACセクション',
			'settings.profiles.section' => 'セクション',
			'settings.search.clear' => 'クリア',
			'settings.search.hint' => '設定を検索',
			'settings.developer.developerModeDescription' => '開発者向けの警告、デバッグログ、ツールを有効にします。',
			'settings.developer.experiments' => '実験',
			'settings.developer.showIdleMetrics' => 'アイドル指標を表示',
			'settings.developer.showIdleMetricsDescription' => '拡張機能エンジンが直近1秒間にどれだけアイドルだったかをステータスバーに表示します。タップすると10秒と60秒の平均が見られます。',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => 'アイドル${percent}%',
			'settings.developer.idleMetricsAverages' => 'アイドル平均：',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}秒 ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件有効', other: '${count}件有効', ), 
			'settings.developer.patchTrack' => 'コードプッシュのトラック',
			'settings.developer.patchTrackDescription' => 'このデバイスが従うOTAコードプッシュのリング。冒険的なリングほど修正を早く受け取りますが、テストは少なくなります。コードプッシュは次回の再起動時に適用されます。',
			'settings.developer.trackStable' => '安定版',
			'settings.developer.trackUnstable' => '不安定版',
			'settings.developer.trackBleeding' => 'ブリーディング',
			'settings.developer.checkingTrack' => ({required Object track}) => '「${track}」のコードプッシュを確認中…',
			'settings.developer.patchDownloaded' => 'コードプッシュをダウンロードしました。適用するにはアプリを再起動してください。',
			'settings.developer.noNewPatch' => ({required Object track}) => '「${track}」に新しいコードプッシュはありません。',
			'settings.developer.noPatchInstalled' => 'コードプッシュはインストールされていません。リリースバイナリを実行中です。',
			'settings.developer.runningPatch' => ({required Object patch}) => 'コードプッシュ#${patch}を実行中。',
			'settings.developer.deepLinks' => 'ディープリンク',
			'settings.developer.registerUrlSchemes' => 'URLスキームを登録',
			'settings.developer.registerUrlSchemesDescription' => 'com.ham2k:// のリンクをこのアプリで開けるようにします',
			'settings.developer.registerUrlSchemesDone' => 'このアプリで com.ham2k:// のリンクを開けるようになりました',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => '登録できませんでした：${error}',
			'settings.developer.systemInformation' => 'システム情報',
			'settings.developer.appVersion' => 'アプリのバージョン',
			'settings.developer.dataFolder' => 'データフォルダー',
			'settings.developer.loading' => '（読み込み中…）',
			'settings.developer.panelLoadFailed' => 'この設定パネルを読み込めませんでした。',
			'settings.developer.extDevServer' => '拡張機能開発サーバー',
			'settings.developer.extensionSettings' => '拡張機能の設定',
			'settings.developer.extDevServerDescription' => 'アプリに組み込まれた拡張機能の代わりに、ネットワーク上の開発サーバーから拡張機能を読み込み、保存するたびに再読み込みします。',
			'settings.developer.extDevServerAddress' => 'サーバーアドレス',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => '接続',
			'settings.developer.extDevServerDisconnect' => '切断',
			'settings.developer.extDevServerConnecting' => '接続中…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の拡張機能を提供中：${keys}', other: '${count}件の拡張機能を提供中：${keys}', ), 
			'settings.developer.extDevServerDisconnected' => '未接続',
			'settings.developer.extDevServerReconnect' => '起動時に再接続',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => '最終再読み込み：${key}（${time}）',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の拡張機能のビルドに失敗', other: '${count}件の拡張機能のビルドに失敗', ), 
			'settings.developer.catalog' => '拡張機能カタログ',
			'settings.developer.catalogDescription' => '別のサーバー（カタログ自体の開発中はローカルサーバー）からカタログを読み込みます。空欄の場合はcatalog.ham2k.netです。',
			'settings.developer.catalogAddress' => 'カタログのアドレス',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'カタログ検索のトラック',
			'settings.developer.catalogSearchStable' => '安定版のみ',
			'settings.developer.catalogSearchUnstable' => '不安定版以上',
			'settings.developer.catalogSearchBleeding' => 'ブリーディング以上',
			'settings.about.notices' => 'お知らせとメッセージ',
			'settings.about.noticesDescription' => '告知とステータスメッセージ',
			'settings.about.releaseNotes' => 'リリースノート',
			'settings.about.copiedVersion' => 'バージョン情報をクリップボードにコピーしました',
			'settings.panels.settings' => 'アプリの設定',
			'settings.panels.settingsDescription' => 'アプリを自分好みに設定',
			'settings.panels.commonSettings' => '共通の設定',
			'settings.panels.syncDescription' => 'ログをバックアップし、デバイス間で同期',
			'settings.panels.accountsDescription' => 'サービスの認証情報、オフラインデータなど',
			'settings.panels.extensions' => '拡張機能とアプリ機能',
			'settings.panels.extensionsDescription' => 'アクティビティ、コンテスト、ダッシュボードパネルなどの機能',
			'settings.panels.profilesDescription' => 'オペレーターのコールサインとステーションプロファイル',
			'settings.panels.stationProfiles' => 'ステーションプロファイル',
			'settings.panels.developerSettings' => '開発者設定',
			'settings.panels.developerSettingsDescription' => 'デバッグと開発用ツール',
			'settings.panels.about' => 'アプリについて',
			'settings.panels.aboutDescription' => 'バージョン、クレジット、法的情報',
			'settings.panels.unavailableTitle' => '一部の設定を利用できません',
			'settings.panels.unavailableText' => '拡張機能ランタイムの起動に失敗したため、拡張機能が提供する設定がありません。',
			'settings.panels.station' => 'ステーション構成',
			'settings.panels.stationDescription' => 'CAT制御とその他のオプション',
			'settings.panels.peers' => 'ピアデバイス',
			'settings.panels.peersDescription' => '近くの他のデバイスに接続',
			'settings.showMoreSettings' => 'その他の設定を表示',
			'settings.gridPrecision' => 'グリッドの精度',
			'settings.gridPrecisionOpts.six' => '6桁（FN31pr）',
			'settings.gridPrecisionOpts.eight' => '8桁（FN31pr55）',
			'settings.gridPrecisionDescription.six' => '6桁',
			'settings.gridPrecisionDescription.eight' => '8桁',
			'commands.enableSyncFirst' => '先に設定で同期を有効にしてください。',
			'commands.fullResyncStarted' => '完全な再同期を開始しました。ローカルデータは事前にバックアップされています。',
			'commands.noDataFilesMatched' => ({required Object target}) => '「${target}」に一致するデータファイルはありません。',
			'commands.reloadFailed' => ({required Object error}) => '再読み込みに失敗しました：${error}',
			'commands.reloadingAll' => 'すべてのデータファイルを再読み込み中…',
			'commands.reloadingTarget' => ({required Object target}) => '${target}のデータファイルを再読み込み中…',
			'commands.unknownExperiment' => ({required Object token}) => '不明な実験「${token}」',
			'commands.experimentEnabled' => ({required Object name}) => '${name}を有効化しました',
			'commands.experimentDisabled' => ({required Object name}) => '${name}を無効化しました',
			'commands.sentryTestSent' => 'テストのエラーレポートをSentryに送信しました',
			'commands.idleMetricsEnabled' => 'ステータスバーのアイドル指標を有効にしました',
			'commands.idleMetricsDisabled' => 'アイドル指標を無効にしました',
			'commands.sentryTestLocalOnly' => 'このビルドではSentryが無効です。テストエラーはローカルにのみ記録されました',
			'commands.noOperationOpen' => 'このコマンドにはオペレーションを開いている必要があります',
			'commands.unknownSegmentKind' => ({required Object kind}) => '「${kind}」の記録方法が分かりません',
			'commands.goUnavailable' => ({required Object place}) => '${place}はこのアプリでは有効になっていません',
			'commands.goUnknown' => ({required Object to}) => '「${to}」への移動方法が分かりません',
			'commands.goBlocked' => '先に開いているダイアログを閉じてください',
			'commands.operationAlreadyStarted' => 'このオペレーションにはすでに開始マーカーがあります',
			'commands.couldNotOpenLocation' => '休憩を追加しましたが、場所の画面を開けませんでした',
			'commands.noTestOperations' => '完全削除するテストオペレーションはありません',
			'commands.purgeTestsUnavailable' => 'PURGETESTSには確認ダイアログの表示が必要ですが、ここでは利用できません',
			'commands.syncAllUnavailable' => 'SYNCALLには確認ダイアログの表示が必要ですが、ここでは利用できません',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のテストオペレーションを完全削除しました', other: '${count}件のテストオペレーションを完全削除しました', ), 
			'commands.purgeTestsSomeFailed' => ({required Object total, required Object purged}) => '${total}件中${purged}件のテストオペレーションを完全削除しました。残りは失敗しました。もう一度PURGETESTSを試してください',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'オペレーションに属さないテストコンタクト${count}件を完全削除しました', other: 'オペレーションに属さないテストコンタクト${count}件を完全削除しました', ), 
			'commands.purgeTestsContactsFailed' => 'テストオペレーションは完全削除しましたが、オペレーションに属さないテストコンタクトの削除に失敗しました。もう一度PURGETESTSを試してください',
			'commands.purgeTestsNothingToDo' => '何も削除されませんでした',
			'commands.receivedPurgesSomeFailed' => ({required Object total, required Object removed}) => '${total}件中${removed}件のテストオペレーションを削除しました。残りは失敗しました。もう一度確認から試してください',
			'commands.receivedPurgesFailed' => 'それらのテストオペレーションを削除できませんでした。もう一度確認から試してください',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のテストオペレーションが別のデバイスで削除されました', other: '${count}件のテストオペレーションが別のデバイスで削除されました', ), 
			'commands.receivedPurgesReview' => '確認',
			'commands.settingOn' => 'オン',
			'commands.settingOff' => 'オフ',
			'commands.settingEmpty' => '（空）',
			'commands.settingSecretSet' => '（設定済み）',
			'commands.settingSecretUnset' => '（未設定）',
			'commands.settingSelectedCount' => ({required Object count}) => '${count}件選択中',
			'commands.settingExpectsOnOff' => 'onまたはoff',
			'commands.settingExpectsOneOf' => ({required Object choices}) => '次のいずれか：${choices}',
			'commands.settingExpectsNumber' => '数値',
			'commands.settingVanished' => ({required Object label}) => '「${label}」はもう利用できません',
			'commands.noCwKeyer' => 'CWをキーイングできる無線機が接続されていません',
			'commands.noKeyer' => 'CWのキーイングやボイスメモリーの再生ができる無線機が接続されていません',
			'commands.keyerNeedsOperation' => 'CWキーヤーを使うにはオペレーションを開いてください',
			'commands.keyerExperimentOff' => 'CWキーイングはオフです。EXP KEYERでオンにしてください',
			'commands.esmExperimentOff' => 'Enterでメッセージ送信はオフです。EXP ESMでオンにしてください',
			'commands.cwSending' => ({required Object text}) => 'CW送信中：${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CWメッセージF${n}：${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CWメッセージF${n}は送信されませんでした：拡張機能の準備ができていません',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => '電話メッセージM${n}：${error}',
			'commands.voiceMessageNotRendered' => '拡張機能の準備ができていません',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => '送信されませんでした：Radio ${radio}ではそれをキーイングできません',
			'commands.so2rNoRadioB' => '送信されませんでした：このセットからキーイングするには、ステーション構成でRadio Bを選んでください',
			'commands.settingNotStored' => ({required Object label}) => '「${label}」はその値を受け付けませんでした',
			'commandDialog.hint' => 'コールサインを検索、またはコマンドを入力',
			'commandDialog.noResults' => ({required Object text}) => '「${text}」に一致するものはありません',
			'commandDialog.sectionCommands' => 'コマンド',
			'commandDialog.sectionGoTo' => '移動',
			'commandDialog.sectionOperations' => 'オペレーション',
			'commandDialog.goHome' => 'ホーム',
			'commandDialog.goSettings' => '設定',
			'commandDialog.goNewOperation' => '新しいオペレーション',
			'commandDialog.runTyped' => ({required Object text}) => '「${text}」を実行',
			'commandDialog.sectionSuggestions' => '候補',
			'commandDialog.lookingUp' => 'コールサインを検索中…',
			'commandDialog.blockedByPane' => 'パネルやダイアログが開いている間はコマンドを使用できません',
			'keyboardShortcuts.title' => 'キーボードショートカット',
			'keyboardShortcuts.description' => 'キー割り当てをカスタマイズ',
			'keyboardShortcuts.search' => 'コマンドとキーを検索',
			'keyboardShortcuts.import' => 'インポート…',
			'keyboardShortcuts.export' => 'エクスポート…',
			'keyboardShortcuts.resetAll' => 'すべてリセット',
			'keyboardShortcuts.resetAllTitle' => 'すべてのショートカットをリセットしますか？',
			'keyboardShortcuts.resetAllBody' => 'すべてのコマンドがデフォルトのキーに戻り、入力コマンドに割り当てたキーは削除されます。',
			'keyboardShortcuts.reset' => 'リセット',
			'keyboardShortcuts.noKey' => 'キーなし',
			'keyboardShortcuts.changed' => '変更済み',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys}は${commands}にも割り当てられています',
			'keyboardShortcuts.groupApp' => 'アプリ',
			'keyboardShortcuts.groupKeying' => 'キーイング',
			'keyboardShortcuts.groupLogging' => 'ロギング',
			'keyboardShortcuts.groupCommands' => 'コマンド',
			'keyboardShortcuts.groupFixed' => '固定キー',
			'keyboardShortcuts.contextApp' => 'どこでも',
			'keyboardShortcuts.contextLogView' => 'オペレーション、チェイス、ログの各ビュー',
			'keyboardShortcuts.contextOperation' => 'オペレーションビュー（CAT無線機のキーイング）',
			'keyboardShortcuts.contextLogging' => 'ロギングパネル内',
			'keyboardShortcuts.addCommand' => 'コマンドを追加…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => '不明なコマンド：${command}',
			'keyboardShortcuts.command.commandDialog' => 'コマンドダイアログを開く',
			'keyboardShortcuts.command.toggleTheme' => 'ライトとダークを切り替える',
			'keyboardShortcuts.command.toggleLanguage' => '英語とスペイン語を切り替える',
			'keyboardShortcuts.command.fontScaleUp' => '文字を大きく',
			'keyboardShortcuts.command.fontScaleDown' => '文字を小さく',
			'keyboardShortcuts.command.fontScaleReset' => '標準の文字サイズ',
			'keyboardShortcuts.command.densityLooser' => 'ゆったりしたレイアウト',
			'keyboardShortcuts.command.densityDenser' => '密なレイアウト',
			'keyboardShortcuts.command.densityAuto' => 'レイアウト密度を自動に',
			'keyboardShortcuts.command.find' => 'ログ内を検索',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => 'メッセージ${n}を送信',
			'keyboardShortcuts.command.keyboardMode' => 'キーボードモードのオン/オフ',
			'keyboardShortcuts.command.ptt' => 'PTT（プッシュトゥトーク）',
			'keyboardShortcuts.command.wipe' => '入力中のコンタクトをクリア',
			'keyboardShortcuts.fixed.callsign' => 'コールサインの入力',
			'keyboardShortcuts.fixed.escape' => '送信の停止、1段階戻る、または閉じる',
			'keyboardShortcuts.fixed.enter' => 'コンタクトを記録',
			'keyboardShortcuts.fixed.space' => '次のフィールド',
			'keyboardShortcuts.fixed.tab' => '次または前のフィールド',
			'keyboardShortcuts.fixed.arrows' => 'フィールド、コントロール、ログの間を移動',
			'keyboardShortcuts.fixed.walk' => 'ログをページ送り、または先頭/末尾へ',
			'keyboardShortcuts.fixed.undo' => '消去や削除を取り消す',
			'keyboardShortcuts.editor.addShortcut' => 'ショートカットを追加',
			'keyboardShortcuts.editor.listening' => 'ショートカットのキーを押してください…',
			'keyboardShortcuts.editor.listeningHint' => 'Escで中止',
			'keyboardShortcuts.editor.add' => '追加',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys}はロギングフィールドまたはダイアログのキーのため、変更できません。',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys}はコールサインの入力に使います。Cmd、Ctrl、Altのいずれかと組み合わせてください。',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => '${keys}はアプリに届く前にシステムが使う可能性があります。',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys}はすでにこのコマンドのキーの1つです。',
			'keyboardShortcuts.editor.takeIt' => ({required Object command, required Object keys}) => '「${command}」から${keys}を取る',
			'keyboardShortcuts.editor.resetDefault' => 'デフォルトに戻す',
			'keyboardShortcuts.editor.remove' => '削除',
			'keyboardShortcuts.editor.commandLabel' => 'コマンド',
			'keyboardShortcuts.editor.commandHint' => '有効なコマンド、または「;」で区切った複数のコマンドを入力',
			'keyboardShortcuts.editor.removeCommand' => 'コマンドを削除',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => '「${text}」というコマンドはありません',
			'keyboardShortcuts.editor.noShortcuts' => 'キーはまだありません',
			'keyboardShortcuts.file.exported' => ({required Object location}) => 'ショートカットを${location}に保存しました',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => 'ショートカットをエクスポートできませんでした：${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => 'ファイルを開けませんでした：${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename}はこのアプリで読めるショートカットファイルではありません：${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => 'テキストが有効なYAMLではありません（${line}行目）',
			'keyboardShortcuts.file.problemNotKeysFile' => 'Ham2Kのキーボードショートカットファイルではありません',
			'keyboardShortcuts.file.problemNewerVersion' => '新しいバージョンのアプリで書き出されたものです',
			'keyboardShortcuts.file.problemMalformed' => '一部がショートカット形式に従っていません',
			'keyboardShortcuts.file.problemTooLarge' => '大きすぎます',
			'keyboardShortcuts.file.importTitle' => 'ショートカットをインポート',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => '${platform}で書き出されました。',
			'keyboardShortcuts.file.writtenOnUnknown' => 'このファイルには、どのキーボードで書き出されたかの記載がありません。',
			'keyboardShortcuts.file.translate' => 'これらの各キーは、このキーボードでは何にしますか？',
			'keyboardShortcuts.file.leaveOut' => 'それらのショートカットを除外',
			'keyboardShortcuts.file.replace' => 'このデバイスの設定と置き換え',
			'keyboardShortcuts.file.replaceHint' => 'ファイルにないショートカットはすべてデフォルトに戻ります。',
			'keyboardShortcuts.file.merge' => 'このデバイスの設定に追加',
			'keyboardShortcuts.file.mergeHint' => '同じコマンドについてはファイルのショートカットがこのデバイスのものを置き換え、それ以外は残ります。',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => 'このバージョンでは不明なため除外：${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => 'ショートカットではないため除外：${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => 'アプリが予約しているキーのため除外：${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => 'インポート後に複数のコマンドに割り当てられています：${keys}',
			'keyboardShortcuts.file.importAction' => 'インポート',
			'keyboardShortcuts.file.imported' => 'ショートカットをインポートしました',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => 'このビルドは期限切れです',
			'expiredBuild.body' => 'ham2k.comにアクセスして新しいバージョンを入手してください。',
			'expiredBuild.visit' => 'ham2k.comを開く',
			'expiredBuild.dismiss' => 'それでも続行',
			'staleness.codePushFloorTitle' => '重要なアップデートが待機中です',
			'staleness.codePushFloorBody' => 'このバージョンには、まだ適用されていない修正があります。',
			'staleness.restartToApply' => '適用するにはアプリを再起動してください。',
			'staleness.quitAndReopen' => '適用するにはアプリを終了して開き直してください。',
			'staleness.reopenToApply' => '適用するにはアプリを閉じて開き直してください。',
			'staleness.ignoreForNow' => '今は無視',
			'spotting.noQsoYet' => 'スポットするQSOがまだ記録されていません。',
			'spotting.setFrequencyFirst' => '先に周波数を設定してください。',
			'spotting.nothingToSpot' => 'スポットできません。ここでスポッティングを提供する拡張機能がありません。',
			'spotting.incompleteCall' => '不完全なコールはスポットできません。先にコールサインを完成させてください。',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source}が失敗しました：${message}',
			'spotting.unknownError' => '不明なエラー',
			'spotting.notSent' => 'スポットは送信されませんでした。',
			'spotting.allSkipped' => 'スポットは送信されませんでした：すべてのスポットソースがスキップしました。',
			'spotting.notRefreshedOffline' => '接続がないため、スポットは更新されませんでした',
			'dataFiles.downloading' => 'ダウンロード中…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name}をダウンロードできませんでした',
			'dataFiles.downloadFailedWebHint' => 'ネットワークの問題か、このリンクのホストがWebブラウザからの直接ダウンロードに対応していない可能性があります。デスクトップ版やモバイル版のアプリ、または別のホスティング先を試してください。',
			'dataFiles.downloadTimedOut' => 'サーバーの応答に時間がかかりすぎました。後で再試行してください。',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host}がエラーを返しました（HTTP ${status}）。後で再試行してください。',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host}はこのファイルを提供できませんでした（HTTP ${status}）。アドレスがまだ正しいか確認してください。',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MMには${stem}のコールヒストリーファイルがありません。',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'N1MMの${stem}のコールヒストリーをダウンロードできませんでした。後で再試行してください。',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name}を処理できませんでした',
			'dataFiles.importTooSmall' => ({required Object existing, required Object imported}) => 'ダウンロードには、このデバイスにある${existing}件中${imported}件のレコードしかなかったため、含まれていなかったレコードは保持しました。設定 › オフラインデータで更新すると、それでも受け入れます。',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${label}のレコードを${count}件インポートしました。', other: '${label}のレコードを${count}件インポートしました。', ), 
			'dataFiles.importedData' => ({required Object label}) => '${label}のデータをインポートしました。',
			'dataFiles.cleanedUpTitle' => '拡張機能のデータを整理しました',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '無効化された拡張機能のデータファイル${count}件分のデータを削除しました。', other: '無効化された拡張機能のデータファイル${count}件分のデータを削除しました。', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total}件',
			'dataFiles.definitionUnavailable' => 'ファイルのソースが定義を提供しませんでした。拡張機能が再起動中か、設定に誤りがある可能性があります。しばらくしてから再試行してください。',
			'updates.updateAvailable' => 'アップデートがあります',
			'updates.newVersionAvailable' => ({required Object version}) => '新しいバージョン（${version}）が利用可能です。',
			'updates.getIt' => '入手',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'アップデートの準備完了',
			'updates.restartToApply' => 'アップデートをダウンロードしました。適用するには再起動してください。',
			'updates.appliesNextLaunch' => 'アップデートをダウンロードしました。次回アプリを開いたときに適用されます。',
			'updates.restartNow' => '今すぐ再起動',
			'updates.reloadToUpdate' => 'このページの新しいバージョンがあります。再読み込みして入手してください。',
			'updates.reloadNow' => '今すぐ再読み込み',
			'updates.checkForUpdates' => 'アップデートを確認',
			'updates.checkingForUpdates' => 'アップデートを確認中…',
			'updates.upToDate' => '最新です',
			'updates.automaticChecks' => '自動的に確認',
			'updates.automaticChecksDescription' => '次回アプリを起動したときから、バックグラウンドで新しいバージョンを確認します',
			'extensionService.runtimeNotReady' => '拡張機能ランタイムの準備ができていません。',
			'extensionService.testFailed' => ({required Object error}) => 'テストに失敗しました：${error}',
			'extensionService.connectedAs' => ({required Object identity}) => '${identity}として接続済み',
			'extensionService.invalidFieldConfiguration' => 'フィールドの設定が無効です',
			'extensionService.invalidValue' => '無効な値',
			'extensionService.validationError' => ({required Object error}) => '検証エラー：${error}',
			'extensionService.actionFailed' => ({required Object error}) => '操作に失敗しました：${error}',
			'extensionService.commandFailed' => 'コマンドを実行できませんでした',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name}は設定を変更できません：インストール時に許可を求めていません',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name}は無線機を制御できません：インストール時に許可を求めていません',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name}はそれを実行できません：アプリ自身の開発者コマンドです',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => '現在、報告を送信できません',
			'extensionService.stashUnavailable' => '現在、Ham2K File Stashに接続できません',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => '${names}がアクティビティ検索に応答しなかったため、一部の結果が欠けている可能性があります。',
			'extensionService.activitySearchSomeSourcesFailed' => '一部のアクティビティ拡張機能が検索に応答しなかったため、一部の結果が欠けている可能性があります。',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name}がタイマーで時間を使いすぎました。拡張機能が再起動するまでタイマーは停止されます。',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name}のタイマーが失敗し続けました。拡張機能が再起動するまでタイマーは停止されます。',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name}がタイマー内で停止しました。拡張機能が再起動するまでタイマーは停止されます。',
			'operationLocationScreen.title' => 'オペレーション場所',
			'operationLocationScreen.selectedLocation' => '選択された場所',
			'operationLocationScreen.gridSquare' => 'メイデンヘッド・グリッドスクエアロケーター',
			'operationLocationScreen.gridInvalid' => 'FN31prのように、4、6、8、10文字で入力してください',
			'operationLocationScreen.suggestedLocations' => '提案された場所',
			'operationLocationScreen.deviceGps' => 'デバイスGPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => '${device}のGPS',
			'operationLocationScreen.locating' => '測位中…',
			'operationLocationScreen.gpsUnavailable' => '位置情報を利用できません',
			'operationLocationScreen.permissionDenied' => '位置情報の許可が拒否されました',
			'operationLocationScreen.permissionBlocked' => '位置情報の許可がブロックされています',
			'operationLocationScreen.moreDetails' => '詳細',
			'operationLocationScreen.stateOrProvince' => '州または都道府県（任意）',
			'operationLocationScreen.controlsUnavailableTitle' => 'アクティビティの操作を利用できません',
			'operationLocationScreen.controlsUnavailableReason' => 'これらのリファレンスは引き続き使用できます。アクティビティに接続できなかっただけです。',
			'operationLocationScreen.controlsUnavailableRetry' => '再試行',
			'operationLocationScreen.county' => '郡（任意）',
			'versionLabel.version' => ({required Object version}) => 'バージョン ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'パッチ ${patch}',
			'versionLabel.build' => ({required Object build}) => 'ビルド ${build}',
			'notices.emptyHistory' => 'お知らせはまだありません',
			'notices.webStorageInMemory' => 'このブラウザは永続ストレージを提供できませんでした。ログはメモリー上にのみ存在し、このタブを閉じると失われます。最新のChrome、Firefox、Safari、Edgeを使用してください。',
			'notices.webStorageUnreliable' => 'このブラウザは複数タブでは安全でない代替ストレージを使用しています。タブは1つだけ開き、同期をオンにしたままにしてください。',
			'notices.logFromNewerBuildTitle' => 'このログには新しいバージョンが必要です',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'ログは新しいバージョンのHaLoで書き込まれているため（ストレージバージョン${storage}、このバージョンが扱えるのは${understood}）、開くことができず、新しいコンタクトも保存されません。新しいバージョンを再インストールするか、このビルドを実行するつもりだった場合は別のデータフォルダーを指定してください。ログの場所：${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'ログは新しいバージョンのHaLoで書き込まれているため（ストレージバージョン${storage}、このバージョンが扱えるのは${understood}）、開くことができず、新しいコンタクトも保存されません。代わりにその新しいバージョンでこのログを開いてください。',
			'notices.preferencesRestoredTitle' => '設定をバックアップから復元しました',
			'notices.preferencesRestored' => '設定ファイルを読み取れなかったため、HaLoは最後の正常なコピーを復元しました。前回のセッションで変更した内容は、再設定が必要な場合があります。読み取れなかったファイルは shared_preferences.corrupt-….json という名前で同じ場所に保管されています。',
			'notices.preferencesResetTitle' => '設定をリセットしました',
			'notices.preferencesReset' => '設定ファイルを読み取れず、代わりに使えるバックアップもなかったため、HaLoはデフォルト設定で起動しました。読み取れなかったファイルは shared_preferences.corrupt-….json という名前でアプリのデータフォルダーに保管されています。',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name}は自動接続されませんでした',
			'notices.autoConnectHeld' => ({required Object name}) => '前回${name}への接続を開始したときにHaLoが応答しなくなったため、再発を避けて今回は接続しませんでした。無線機の電源が入っていてケーブルが接続されていることを確認してから、設定でその無線機の接続を押してください。',
			'syncAccount.anonymous' => ({required Object id}) => '匿名アカウント (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email}（確認待ち）',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email}（確認待ち - #${id}）',
			'deepLink.needsAnOperation' => '先にオペレーションを開始してから、そのコンタクトをもう一度送信してください',
			'deepLink.waitingInOperation' => 'そのコンタクトはこの画面の後ろのオペレーションで待機しています',
			'deepLink.unknownActivities' => ({required Object refs}) => 'このデバイスには${refs}のアクティビティがないため、それらのリファレンスは省略されました',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'アクティビティに接続できなかったため、${refs}は省略されました。もう一度そのリンクを試してください',
			'confirmDevice.title' => 'デバイスを確認',
			'confirmDevice.codePrompt' => 'このアカウントへの参加を求めているデバイスに表示されたコードを入力してください。',
			'confirmDevice.code' => 'コード',
			'confirmDevice.lookUp' => '検索',
			'confirmDevice.codeNotFound' => 'そのコードに一致するリクエストはありません。コードは10分で期限切れになります。相手のデバイスで新しいコードを表示してもらってください。',
			'confirmDevice.linkExpired' => 'そのリンクは期限切れです。相手のデバイスで新しいQRコードを表示してもらってください。',
			'confirmDevice.areYouSure' => ({required Object device}) => '${device}をこのアカウントにリンクしますか？',
			'confirmDevice.unnamedDevice' => '名前のないデバイス',
			'confirmDevice.grantWarning' => 'このアカウントのすべてのオペレーションとQSOを読み取り、変更できるようになります。',
			'confirmDevice.needsSyncTitle' => 'このデバイスはまだ同期していません',
			'confirmDevice.needsSyncText' => '別のデバイスを参加させるには、Ham2K Log Filerの同期をオンにして、このデバイスをアカウントにリンクしてください。',
			'confirmDevice.malformedRequest' => '同期サーバーから、このアプリが読み取れないリクエストが送られてきました。相手のデバイスで再試行してもらってください。',
			'confirmDevice.linkIt' => 'デバイスをリンク',
			'switchAccounts.noAccountDetails' => 'アカウントの詳細はまだありません',
			'switchAccounts.currentAccount' => '現在のアカウント',
			'switchAccounts.otherAccounts' => 'その他のアカウント',
			'switchAccounts.linkToAnother' => '別のアカウントにリンク',
			'switchAccounts.linkWithSibling' => '他のHam2Kアプリとリンク',
			'switchAccounts.linkWithPolo' => '旧バージョンのアカウントとリンク',
			'switchAccounts.linkWithSiblingDescription' => '別のHam2Kアプリがインストールされています。そこで使用中のアカウントとリンクします。',
			'switchAccounts.siblingPrompt' => ({required Object app}) => '${app}でリクエストを承認してから、ここに戻ってください。',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '${app}をもう一度開く',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingNoGrant' => 'うまくいきませんでしたか？もう一度開くか、戻って別の方法でリンクしてください。',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app}を開けませんでした。',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'リンクの期限が切れたため、新しいリンクを用意しました。${app}をもう一度開いてください。',
			'switchAccounts.tryAgain' => '再試行',
			'switchAccounts.linkWithQr' => 'QRコードでリンク',
			'switchAccounts.linkWithQrDescription' => 'そのアカウントを使用中のデバイスからスキャン',
			'switchAccounts.linkWithEmail' => 'メールアドレスでリンク',
			'switchAccounts.linkWithEmailDescription' => 'コードまたはメールのリンクで確認',
			'switchAccounts.enterEmailPrompt' => 'このデバイスで使用するアカウントのメールアドレスを入力してください。',
			'switchAccounts.emailAddress' => 'メールアドレス',
			'switchAccounts.linkAccount' => 'アカウントをリンク',
			'switchAccounts.copiedCode' => 'コードをクリップボードにコピーしました',
			'switchAccounts.copyCode' => 'コードをコピー',
			'switchAccounts.codePrompt' => ({required Object email}) => '${email}ですでにリンクされているデバイスでHam2Kアプリを開き、このコードを入力してリクエストを承認してください：',
			'switchAccounts.waitingForConfirmation' => '確認を待っています…',
			'switchAccounts.sendEmailInstead' => '代わりに確認メールを送信',
			'switchAccounts.emailSent' => ({required Object email}) => '${email}にメールを送信しました。メールを開いてリクエストを確認し、このデバイスをリンクしてください。',
			'switchAccounts.resendEmail' => 'メールを再送信',
			'switchAccounts.qrPrompt' => '使用したいアカウントにすでにリンクされているデバイス（例：スマートフォンのHam2K Portable Logger）から、このQRコードをスキャンしてください。',
			'switchAccounts.serverUnreachable' => '同期サーバーに接続できませんでした。後で再試行してください。',
			'switchAccounts.emailRequired' => 'リンクするメールアドレスを入力してください。',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => '${email}のアカウントが見つかりません。',
			'switchAccounts.serverRejected' => ({required Object error}) => '同期サーバーがリクエストを拒否しました：${error}',
			'switchAccounts.noLinkCode' => '同期サーバーがリンクコードを返しませんでした。後で再試行してください。',
			'switchAccounts.noConfirmationCode' => '同期サーバーが確認コードを送信しませんでした。後で再試行してください。',
			'switchAccounts.switchNotAccepted' => 'そのアカウントは切り替えを受け付けませんでした。代わりにメールアドレスでリンクしてみてください。',
			'switchAccounts.requestFailed' => '同期サーバーとの通信で問題が発生しました。後で再試行してください。',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のQSO', other: '${count}件のQSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のオペレーション', other: '${count}件のオペレーション', ), 
			'qsonImport.title' => 'QSONオペレーションをインポート',
			'qsonImport.description' => '開発者モードでここやPoLoから書き出したQSONファイルから、新しいオペレーションを作成します。',
			'qsonImport.dropHint' => 'QSONファイルをドロップして新しいオペレーションとしてインポート',
			'qsonImport.importing' => ({required Object filename}) => '${filename}をインポート中…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => '${filename}をインポートできませんでした：${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => 'インポートするファイルを開けませんでした：${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename}はUTF-8テキストではないため、QSONファイルではありません',
			'qsonImport.notJson' => ({required Object filename}) => '${filename}はJSONファイルではないため、QSONファイルではありません',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename}にはQSONオペレーションが含まれていません',
			'qsonImport.busy' => 'すでにインポートを実行中です。完了してから次のインポートを開始してください。',
			'qsonImport.oneFileOnly' => 'QSONファイルは1つずつドロップしてください。それぞれが別のオペレーションとして開きます。',
			'adifImport.title' => 'ADIFからQSOをインポート',
			'adifImport.reading' => ({required Object filename}) => '${filename}を読み込み中…',
			'adifImport.dropHint' => 'ADIFファイルをドロップしてインポート',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: 'このファイルのQSO：${count}件', other: 'このファイルのQSO：${formatted}件', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件はすでにログにあります', other: '${formatted}件はすでにログにあります', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件をインポートします', other: '${formatted}件をインポートします', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件の新しいコンタクト', other: '${formatted}件の新しいコンタクト', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件は既存のコンタクトと統合されます', other: '${formatted}件は既存のコンタクトと統合されます', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件はインポートできません（コールサインなし）', other: '${formatted}件はインポートできません（コールサインなし）', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件は確認が必要です', other: '${formatted}件は確認が必要です', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のコンタクトのリファレンスを復元できませんでした', other: '${formatted}件のコンタクトのリファレンスを復元できませんでした', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件のコンタクトの${programs}リファレンスが不完全な可能性があります', other: '${formatted}件のコンタクトの${programs}リファレンスが不完全な可能性があります', ), 
			'adifImport.stackingTypesUnknown' => '統合されたコンタクトでリファレンスが失われる可能性があります。どの種類が重ねられるかをアクティビティが示せませんでした。これを避けるには、キャンセルして再試行してください。',
			'adifImport.nothingToImport' => 'このファイルにはインポートできるものがありません',
			'adifImport.confirm' => 'インポート',
			'adifImport.importing' => ({required Object filename}) => '${filename}をインポート中…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${filename}から${count}件のコンタクトをインポートしました', other: '${filename}から${formatted}件のコンタクトをインポートしました', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename}をインポートできませんでした：${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename}はADIFファイルではないようです',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => '警告：このADIFには${calls}のQSOが含まれていますが、続行すると${station}としてインポートされます。',
			'adifImport.stationCallJoin' => 'と',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(count, one: '${count}件は日付がないためインポートできません', other: '${formatted}件は日付がないためインポートできません', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'このファイルには${refs}のアクティベーションが記録されています。',
			'adifImport.addActivation' => 'このオペレーションに追加',
			'adifImport.shortfall' => ({required Object planned, required Object written}) => '${planned}件中${written}件しか適用できませんでした。判断している間にログが変更されました。',
			'adifImport.busy' => 'すでにインポートを実行中です。完了してから次のインポートを開始してください。',
			'adifImport.oneFileOnly' => 'ADIFファイルは1つずつドロップしてください。インポートの順序によって、どのデータが優先されるかが決まります。',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename}のQSOは${limit}件を超えています。これは1つのオペレーションで一度にインポートできる上限です。',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename}のQSOは${limit}件を超えています。オペレーションへのADIFインポートは少数のQSOを追加するためのもので、大きなログを取り込むためのものではありません。それにはログビューを使ってください。確信がある場合は、開発者モードでそのままインポートできます。',
			'adifImport.importAnyway' => 'それでもインポート',
			'offline.statusOffline' => 'インターネット：オフライン',
			'offline.statusOnline' => 'インターネット：接続済み',
			'offline.noRoute' => 'ネットワーク接続がまったくありません。',
			'offline.unreachable' => 'ネットワークは接続されていますが、どのサーバーも応答していません。多くの場合、ブラウザでログインページが待機しています。',
			'offline.reachable' => 'すべてのサービスが正常に応答しています。',
			'offline.whatStops' => '検索、スポット、データファイルは一時停止中です。ロギングと近くのデバイスとの同期は停止していません。',
			'offline.servicesTitle' => 'サービス',
			'offline.noServices' => 'まだ報告したサービスはありません。',
			'offline.lastSuccess' => ({required Object when}) => '${when}前に最終応答',
			'offline.neverSucceeded' => 'まだ応答していません',
			'offline.nextAttempt' => ({required Object when}) => '${when}後に次の試行',
			'offline.nextAttemptNow' => '次の試行の時刻です',
			'offline.retry' => '今すぐ再試行',
			'offline.retrying' => '試行中…',
			'offline.retryReached' => 'オンラインに復帰しました。',
			'offline.retryUnreachable' => 'まだ応答がありません。',
			'offline.retryNotAttempted' => '現在送信するものはありません。',
			'offline.retryThrottled' => '試行したばかりです。少し待ってください。',
			'offline.retryDisabled' => '同期がオフのため、確認に使えるものがありません。',
			'offline.syncService' => 'Ham2K LoFi 同期',
			'offline.retryInFlight' => 'すでに試行中です。お待ちください。',
			'exportSettings.defaultsDescription' => 'すべてのエクスポートの基本設定です。リファレンス付きアクティビティとその他のアクティビティで、ファイル名とタイトルのテンプレートを別々に設定できます。エクスポート種別ごとに、独自のデフォルトまたはカスタム設定を提供できます。',
			'exportSettings.referenceActivities' => 'リファレンス付きアクティビティ',
			'exportSettings.otherActivities' => 'その他のアクティビティ',
			'exportSettings.adifFields' => 'ADIFフィールド',
			'exportSettings.loadFailed' => 'エクスポート設定を読み込めませんでした。',
			'exportSettings.retry' => '再試行',
			'exportSettings.compactFileNamesDescriptionOn' => 'コンパクトなファイル名（例：N0CALL@US-1234-20260715.adi）。',
			'exportSettings.compactFileNamesDescriptionOff' => '説明的なファイル名（例：2026-07-15 N0CALL at US-1234.adi）。',
			'exportSettings.includePrivateDataDescriptionOn' => 'ADIFファイルに名前、住所、メール、メモ、正確な位置を含めています。',
			'exportSettings.includePrivateDataDescriptionOff' => '名前、住所、メール、メモを除外し、位置を6文字のグリッドに制限しています。',
			'exportSettings.includeLookupDataDescriptionOn' => 'コールサイン検索サービスからの情報を含めています。',
			'exportSettings.includeLookupDataDescriptionOff' => 'コールサイン検索サービスからの情報を除外し、手動で入力した値は保持しています。',
			'exportSettings.customTemplatesDescriptionOn' => 'カスタムテンプレートが有効で、下で編集できます。',
			'exportSettings.customTemplatesDescriptionOff' => 'デフォルトテンプレートが有効です。カスタムテンプレートは後で使えるよう保持されています。',
			'exportSettings.type' => 'エクスポート種別',
			'exportSettings.defaults' => 'デフォルト',
			'exportSettings.includeLookupData' => '検索データを含める',
			'exportSettings.customTemplates' => 'カスタムテンプレート',
			'exportSettings.filenameTemplate' => 'ファイル名テンプレート',
			'exportSettings.compactFilenameTemplate' => 'コンパクトファイル名テンプレート',
			'exportSettings.titleTemplate' => 'タイトルテンプレート',
			'exportSettings.adifNotesTemplate' => 'ADIF QSOノート',
			'exportSettings.adifCommentTemplate' => 'ADIF QSOコメント',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSLメッセージ',
			'exportSettings.shared' => 'この設定は、このエクスポート種別を使用するすべての拡張機能に適用されます。',
			'exportSettings.defaultTemplates' => 'この種別のテンプレートを編集するには、カスタムテンプレートをオンにしてください。',
			'templateEditor.previewLabel' => 'プレビュー：',
			'templateEditor.reset' => 'リセット',
			'templateEditor.docs' => 'テンプレートのドキュメント',
			'templateEditor.preview' => 'サンプルプレビュー',
			'templateEditor.reference' => 'テンプレートリファレンス',
			'templateEditor.attributes' => '使用可能な属性',
			'templateEditor.filters' => 'フィルター',
			'templateEditor.flowControl' => 'フロー制御',
			'templateEditor.unavailable' => '拡張機能の準備ができるまでプレビューは利用できません。',
			'templateEditor.empty' => '（出力なし）',
			_ => null,
		};
	}
}
