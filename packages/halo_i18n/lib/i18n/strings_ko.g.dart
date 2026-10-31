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
class TranslationsKo extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsKo({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ko,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ko>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsKo _root = this; // ignore: unused_field

	@override 
	TranslationsKo $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsKo(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$ko common = _Translations$common$ko._(_root);
	@override late final _Translations$onboarding$ko onboarding = _Translations$onboarding$ko._(_root);
	@override late final _Translations$startScreen$ko startScreen = _Translations$startScreen$ko._(_root);
	@override late final _Translations$testerOverlay$ko testerOverlay = _Translations$testerOverlay$ko._(_root);
	@override late final _Translations$extensionsPanel$ko extensionsPanel = _Translations$extensionsPanel$ko._(_root);
	@override late final _Translations$home$ko home = _Translations$home$ko._(_root);
	@override late final _Translations$chase$ko chase = _Translations$chase$ko._(_root);
	@override late final _Translations$dialogs$ko dialogs = _Translations$dialogs$ko._(_root);
	@override late final _Translations$operation$ko operation = _Translations$operation$ko._(_root);
	@override late final _Translations$map$ko map = _Translations$map$ko._(_root);
	@override late final _Translations$mapsView$ko mapsView = _Translations$mapsView$ko._(_root);
	@override late final _Translations$activitiesView$ko activitiesView = _Translations$activitiesView$ko._(_root);
	@override late final _Translations$loggingControls$ko loggingControls = _Translations$loggingControls$ko._(_root);
	@override late final _Translations$formChrome$ko formChrome = _Translations$formChrome$ko._(_root);
	@override late final _Translations$qsoEditForm$ko qsoEditForm = _Translations$qsoEditForm$ko._(_root);
	@override late final _Translations$qsoList$ko qsoList = _Translations$qsoList$ko._(_root);
	@override late final _Translations$loggingPanel$ko loggingPanel = _Translations$loggingPanel$ko._(_root);
	@override late final _Translations$callInfo$ko callInfo = _Translations$callInfo$ko._(_root);
	@override late final _Translations$settings$ko settings = _Translations$settings$ko._(_root);
	@override late final _Translations$commands$ko commands = _Translations$commands$ko._(_root);
	@override late final _Translations$commandDialog$ko commandDialog = _Translations$commandDialog$ko._(_root);
	@override late final _Translations$keyboardShortcuts$ko keyboardShortcuts = _Translations$keyboardShortcuts$ko._(_root);
	@override late final _Translations$expiredBuild$ko expiredBuild = _Translations$expiredBuild$ko._(_root);
	@override late final _Translations$staleness$ko staleness = _Translations$staleness$ko._(_root);
	@override late final _Translations$spotting$ko spotting = _Translations$spotting$ko._(_root);
	@override late final _Translations$dataFiles$ko dataFiles = _Translations$dataFiles$ko._(_root);
	@override late final _Translations$updates$ko updates = _Translations$updates$ko._(_root);
	@override late final _Translations$extensionService$ko extensionService = _Translations$extensionService$ko._(_root);
	@override late final _Translations$operationLocationScreen$ko operationLocationScreen = _Translations$operationLocationScreen$ko._(_root);
	@override late final _Translations$versionLabel$ko versionLabel = _Translations$versionLabel$ko._(_root);
	@override late final _Translations$notices$ko notices = _Translations$notices$ko._(_root);
	@override late final _Translations$syncAccount$ko syncAccount = _Translations$syncAccount$ko._(_root);
	@override late final _Translations$deepLink$ko deepLink = _Translations$deepLink$ko._(_root);
	@override late final _Translations$confirmDevice$ko confirmDevice = _Translations$confirmDevice$ko._(_root);
	@override late final _Translations$switchAccounts$ko switchAccounts = _Translations$switchAccounts$ko._(_root);
	@override late final _Translations$qsonImport$ko qsonImport = _Translations$qsonImport$ko._(_root);
	@override late final _Translations$adifImport$ko adifImport = _Translations$adifImport$ko._(_root);
	@override late final _Translations$offline$ko offline = _Translations$offline$ko._(_root);
	@override late final _Translations$exportSettings$ko exportSettings = _Translations$exportSettings$ko._(_root);
	@override late final _Translations$templateEditor$ko templateEditor = _Translations$templateEditor$ko._(_root);
}

// Path: common
class _Translations$common$ko extends Translations$common$en {
	_Translations$common$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get save => '저장';
	@override String get ok => '확인';
	@override String get cancel => '취소';
	@override String get delete => '삭제';
	@override String get create => '만들기';
	@override String get error => '오류';
	@override String get close => '닫기';
	@override String get done => '완료';
	@override String get callsign => '콜사인';
	@override String get clear => '지우기';
	@override String get dismiss => '닫기';
	@override String get copyDetails => '상세 정보 복사';
	@override String get expand => '펼치기';
	@override String get collapse => '접기';
}

// Path: onboarding
class _Translations$onboarding$ko extends Translations$onboarding$en {
	_Translations$onboarding$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Ham2K Portable Logger에 오신 것을 환영합니다!';
	@override String get welcomeTitleDesktop => 'Ham2K Power Logger에 오신 것을 환영합니다!';
	@override String get welcomeBody => '사용 목적에 맞게 설정할 수 있도록 몇 가지 질문을 드리겠습니다.';
	@override String get skip => '건너뛰기';
	@override String get kContinue => '계속';
	@override String get back => '뒤로';
	@override String get next => '다음';
	@override String get done => '완료';
	@override String get callsignTitle => '콜사인이 무엇인가요?';
	@override String get callsignBody => '이 앱을 유용하게 사용하려면 아마추어 무선기사 자격이 필요합니다';
	@override String get callsignLabel => '오퍼레이터 콜사인';
	@override String get alreadyHaveAccount => '이미 계정이 있으신가요?';
	@override String get foundSiblingTitle => '기존 계정에 연결할까요?';
	@override String foundSiblingBody({required Object app}) => '이 기기에서 ${app}을(를) 찾았습니다. 이 앱을 같은 계정에 연결하면 콜사인과 로그를 가져옵니다.';
	@override String get foundPoloBody => '이 기기에서 이전 버전의 Ham2K Portable Logger를 찾았습니다. 이 앱을 같은 계정에 연결하면 콜사인과 로그를 가져옵니다.';
	@override String get foundSiblingsBody => '이 기기에서 다른 Ham2K 앱을 찾았습니다. 이 앱을 그중 한 계정에 연결하면 콜사인과 로그를 가져옵니다.';
	@override String linkWithApp({required Object app}) => '${app}과(와) 연결';
	@override String get linkWithPolo => '이전 버전의 계정과 연결';
	@override String get setUpFresh => '새로 설정';
	@override String get activitiesTitle => '즐겨 하는 활동';
	@override String get activitiesBody => '다음 인기 활성화 프로그램 중 관심 있는 것이 있나요?';
	@override String get activitiesFooter => '(설정에서 더 많은 옵션을 찾을 수 있습니다)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get syncTitle => '클라우드 동기화';
	@override String get syncBody => 'Ham2K Log Filer는 로그를 클라우드에 백업하고, Ham2K 앱을 사용하는 모든 기기 간에 동기화합니다.';
	@override String get syncPricing => '무료입니다! 유료 구독을 하면 더 빨라집니다.';
	@override String get syncLabel => '클라우드 동기화 활성화';
	@override String get syncOffWarning => '경고: 기기가 고장 나거나 분실되는 경우 등 운용 데이터를 잃을 가능성이 높아집니다.';
	@override String get notNow => '나중에';
	@override String get consentTitle => '데이터 및 개인정보';
	@override String get consentUsageBody => '앱 개선을 위해 성능, 충돌 및 앱 사용 데이터를 수집하고자 합니다.';
	@override String get consentUsageLabel => '앱 사용 데이터 공유';
	@override String get consentOperationBody => '일부 기능은 운용 데이터를 다른 사용자와 공유할 수 있습니다. 언제든지 거부할 수 있습니다.';
	@override String get consentOperationLabel => '운용 데이터 공유';
	@override String get finishingSetup => '설정 마무리 중 — 레퍼런스 데이터 다운로드 중…';
}

// Path: startScreen
class _Translations$startScreen$ko extends Translations$startScreen$en {
	_Translations$startScreen$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get credits => 'KI2D & 친구들 제작';
}

// Path: testerOverlay
class _Translations$testerOverlay$ko extends Translations$testerOverlay$en {
	_Translations$testerOverlay$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get tape => '주의: 공사 중';
	@override String get warningTitle => '이 앱은 개발 중입니다';
	@override String get warningBody => '대부분의 기능이 아직 울퉁불퉁하고 곳곳에 걸려 넘어질 곳이 있습니다. 업데이트를 자주 확인해 주세요.';
	@override String whatsNew({required Object build}) => '빌드 ${build}의 새로운 기능';
	@override String get thanks => '앱 개선을 위해 로그를 위험에 맡겨 주셔서 감사합니다!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$ko extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => '활동';
	@override String get categoryAward => '어워드';
	@override String get categoryContest => '컨테스트';
	@override String get categoryLookup => '콜사인 조회';
	@override String get categorySpots => '스팟 출처';
	@override String get categoryDashboard => '대시보드 패널';
	@override String get categoryOther => '기타 확장 기능';
	@override String get searchHint => '확장 기능 검색';
	@override String get applying => '확장 기능 변경 사항을 적용 중입니다. 잠시만 기다려 주세요…';
	@override String get noMatches => '검색과 일치하는 확장 기능이 없습니다';
	@override String get installFromFile => '파일에서 설치…';
	@override String installVersion({required Object version}) => '버전 ${version}';
	@override String screenshotLabel({required Object n, required Object count}) => '스크린샷 ${n}/${count}';
	@override String moreScreenshots({required Object count}) => '+${count}';
	@override String get previousScreenshot => '이전 스크린샷';
	@override String get nextScreenshot => '다음 스크린샷';
	@override String get screenshotUnavailable => '스크린샷 없음';
	@override String get canReach => '이 확장 기능이 연결할 수 있는 대상';
	@override String canHoldConnection({required Object host}) => '${host}, 실시간 연결로';
	@override String get canHoldLocalConnection => '로컬 네트워크의 기기, 실시간 연결로';
	@override String get canUseLocation => '내 위치';
	@override String get canReadRadio => '무전기 (주파수와 모드 읽기)';
	@override String get canControlRadio => '무전기 (제어 및 송신 — 튜닝, 출력, CW, 보이스 메모리, PTT)';
	@override String get canCommandRadioRaw => '무전기 (고유 프로토콜로 모든 명령 전송 — 송신하거나 설정을 바꾸는 명령 포함)';
	@override String get canReadCluster => 'DX 클러스터 (내 계정으로 로그인하여 수신 내용 읽기)';
	@override String get canSpotCluster => 'DX 클러스터 (내 계정으로 로그인하여 내 이름으로 스팟 게시)';
	@override String get canCommandCluster => 'DX 클러스터 (내 계정으로 로그인하여 내 이름으로 모든 명령 전송)';
	@override String get canSetUserAgent => '서버에 자체 이름으로 신원을 밝힘';
	@override String get canChangeSettings => '설정 (명령으로 변경 — 모든 설정, 개발자 모드, 실험기능)';
	@override String get noCapabilities => '앱 외부의 어떤 것도 요청하지 않습니다.';
	@override String get sandboxNote => '확장 기능은 샌드박스에서 실행됩니다. 파일에 접근할 수 없으며, 여기 나열된 것 외의 네트워크는 사용할 수 없습니다.';
	@override String get installAction => '설치';
	@override String get updateAction => '업데이트';
	@override String get installFailed => '해당 확장 기능을 설치할 수 없습니다';
	@override String get installedBadge => '설치됨';
	@override String get uninstallAction => '제거';
	@override String uninstallTitle({required Object name}) => '${name}을(를) 제거할까요?';
	@override String get uninstallBody => '이 확장 기능과 설정이 제거됩니다. 로그는 그대로 유지됩니다.';
	@override String installedMessage({required Object name}) => '${name} 설치됨';
	@override String get installDownloading => '다운로드 중…';
	@override String get installWaiting => '설치 대기 중…';
	@override String get installInstalling => '설치 중…';
	@override String get installAwaitingApproval => '승인 대기 중…';
	@override String installAlreadyRunning({required Object name}) => '${name}이(가) 이미 설치 중입니다.';
	@override String updatedTo({required Object version}) => '${version}(으)로 업데이트됨';
	@override String installIncomplete({required Object name}) => '${name} 설치가 완료되지 않았습니다. 다시 설치해야 할 수 있습니다.';
	@override String uninstallFailed({required Object name}) => '${name}을(를) 제거할 수 없습니다';
	@override String installedFrom({required Object source}) => '${source}에서 다운로드됨';
	@override String get dropHint => '.h2kext 확장 파일을 끌어다 놓아 설치하세요';
	@override String get dropOneOnly => '확장 기능은 한 번에 하나씩 끌어다 놓으세요.';
	@override String downloadFailed({required Object source, required Object status}) => '${source}이(가) 해당 확장 기능에 대해 ${status}을(를) 반환했습니다.';
	@override String get downloadTooLarge => '다운로드 크기가 확장 기능이라기엔 너무 큽니다.';
	@override String get downloadNotSecure => '다운로드가 안전하지 않은 곳으로 리디렉션되었습니다.';
	@override String get catalogSection => '카탈로그';
	@override String get catalogLoading => '카탈로그 로딩 중…';
	@override String get catalogUnreachable => '카탈로그에 연결할 수 없음';
	@override String get builtIn => '내장';
	@override String get updateAvailableBadge => '업데이트 가능';
	@override String get updatesAvailableTitle => '확장 기능 업데이트';
	@override String updateAvailableFor({required Object name}) => '${name}의 업데이트가 있습니다.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} 외 ${count}개를 업데이트해야 합니다.';
	@override String updatesAvailableFor({required Object names}) => '${names}을(를) 업데이트해야 합니다.';
	@override String get pendingUpdatesSection => '대기 중인 업데이트';
	@override String get updateAllAction => '모두 업데이트';
	@override String get updatesUnderWay => '해당 업데이트가 이미 진행 중입니다.';
	@override String get updatesNothingLeft => '확장 기능이 최신 상태입니다.';
	@override String get updatesNoticeAction => '자세히';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '확장 기능 ${count}개를 업데이트할까요?',
		other: '확장 기능 ${count}개를 업데이트할까요?',
	);
	@override String get upgradeDoneTitle => '확장 기능이 준비되었습니다';
	@override String get upgradeDoneBody => '이제 Ham2K 확장 기능 카탈로그에서 제공되므로, 앱의 새 버전을 기다리지 않고 업데이트할 수 있습니다.';
	@override String upgradeDoneUnserved({required Object names}) => '업그레이드되지 않음: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => '실행되지 않음: ${names}.';
	@override String get upgradeDoneRefusedHint => '아직 설치되어 있으며 설정 › 확장 기능에 표시되어 있습니다. 그곳에서 업데이트하면 다시 사용할 수 있습니다.';
	@override String get upgradeDoneUnservedHint => '카탈로그에 이들을 직접 대체할 항목이 없으니, 사용하던 기능을 지원하는 확장 기능을 카탈로그에서 찾아보세요.';
	@override String get retiredQp => 'QSO 파티';
	@override String get retiredStateparks => '주립공원 이벤트';
	@override String upgradeDoneMissing({required Object count}) => '확장 기능 중 ${count}개가 아직 도착하지 않았습니다. 다음에 확장 기능 카탈로그에 연결되면 다운로드됩니다.';
	@override String get runtimeDeadBody => '확장 기능이 시작되지 않았습니다. 앱을 다시 시작하면 복구될 것입니다.';
	@override String get refusedTitle => '일부 확장 기능이 실행되지 않았습니다';
	@override String get upgradeBusyTitle => '아직 설정 중';
	@override String get upgradeRuntimeDeadTitle => '확장 기능이 실행되고 있지 않습니다';
	@override String get restoreTitle => '일부 확장 기능이 없습니다';
	@override String get restoreBody => '설치했던 다음 확장 기능이 이 기기에 없습니다. Ham2K 확장 기능 카탈로그에서 다시 다운로드할 수 있습니다:';
	@override String get restoreFromFile => '파일에서 설치됨. 해당 파일에서 다시 설치하거나 목록에서 지우세요:';
	@override String get restoreOtherCatalog => '다른 확장 기능 카탈로그에서 설치되어 여기서는 사용할 수 없습니다:';
	@override String get restoreForget => '지우기';
	@override String get restoreInstall => '설치';
	@override String get restoreLater => '나중에';
	@override String get restoreInstalling => '확장 기능 설치 중…';
	@override String get restoreDoneTitle => '확장 기능이 복구되었습니다';
	@override String restoreDoneBody({required Object names}) => '다시 설치됨: ${names}.';
	@override String get restorePartialTitle => '일부 확장 기능을 설치할 수 없습니다';
	@override String restoreFailed({required Object names}) => '설치할 수 없음: ${names}. 다음에 앱을 열 때 다시 제안합니다.';
	@override String get restoreBusyBody => '앱이 아직 확장 기능을 설정 중입니다. 다음에 앱을 열 때 다시 제안합니다.';
	@override String get restoreRuntimeDeadBody => '다시 설치했지만 확장 기능이 시작되지 않았습니다. 앱을 다시 시작하면 복구될 것입니다.';
	@override String revokedTitle({required Object name}) => '${name}이(가) 철회되었습니다';
	@override String get revokedBody => '카탈로그에서 이 버전을 철회하여 비활성화되었습니다.';
	@override String forceDisabledTitle({required Object name}) => '${name}이(가) 비활성화되었습니다';
	@override String get forceDisabledBody => 'Ham2K에서 이 확장 기능을 당분간 비활성화했습니다.';
	@override String replacedTitle({required Object name}) => '${name}이(가) 대체되었습니다';
	@override String replacedBody({required Object replacement}) => '${replacement}이(가) 그 자리를 대신합니다. 확장 기능에서 전환할 수 있습니다.';
	@override String replacedBy({required Object name}) => '${name}(으)로 대체됨';
	@override String replacedByInstalled({required Object name}) => '이미 설치된 ${name}(으)로 대체됨';
	@override String get replaceAction => '대체';
	@override String replaceInstalledBody({required Object replacement}) => '설정은 이미 설치된 ${replacement}(으)로 옮겨집니다. 로그는 그대로 유지됩니다.';
	@override String get downloadHashMismatch => '다운로드한 파일이 카탈로그에 설명된 확장 기능과 다릅니다.';
	@override String catalogVersionUnknown({required Object key, required Object version}) => '카탈로그에 ${key}의 ${version} 버전이 없습니다.';
	@override String get catalogLinkUnknown => '해당 카탈로그 링크에 확장 기능 버전이 지정되어 있지 않습니다.';
	@override String catalogNoRelease({required Object key}) => '카탈로그에 해당 트랙의 ${key} 릴리스가 없습니다.';
	@override String get installFromLink => '링크에서 설치';
	@override String get unstableReleaseWarning => '불안정 릴리스입니다. 게시자가 완성되었다고 밝히지 않은 버전입니다. 오작동할 수 있으며, 앞으로도 불안정 업데이트를 받게 됩니다.';
	@override String get bleedingReleaseWarning => '최신(bleeding-edge) 릴리스입니다. 개발 중인 버전으로 고장 나거나 설정이 사라질 수 있습니다. 앞으로도 최신 업데이트를 받게 됩니다.';
	@override String get channelUnstable => '불안정';
	@override String get channelBleeding => '최신';
	@override String get followsUnstable => '불안정 및 안정 릴리스를 받음';
	@override String get followsBleeding => '최신, 불안정 및 안정 릴리스를 받음';
	@override String get followStableAction => '안정 릴리스만 받기';
	@override String get revokedBadge => '철회됨';
	@override String get forceDisabledBadge => 'Ham2K에서 비활성화';
	@override String get refusedBadge => '로드되지 않음';
	@override String get downloadNotHttps => '다운로드가 보안 연결을 통하지 않습니다.';
	@override String downloadUnreachable({required Object source}) => '해당 확장 기능을 위해 ${source}에 연결할 수 없습니다.';
	@override String get detailsAction => '상세';
	@override String get installedFromFile => '파일에서 설치됨';
	@override String get detailsWhatItDoes => '지원 기능';
	@override String get installedPreloaded => '사전 설치됨';
	@override String get hookAccount => '계정 로그인';
	@override String get hookCallNotes => '콜사인 노트';
	@override String get hookDataFile => '오프라인 데이터';
	@override String get hookExport => '내보내기';
	@override String get hookLookup => '콜사인 조회';
	@override String get hookScoring => '점수 계산';
	@override String get hookSpots => '스팟';
	@override String hookHunting({required Object program}) => '${program} 추적';
	@override String hookActivating({required Object program}) => '${program} 활성화';
	@override String get suggestedSection => '추천';
	@override String moreAvailableSection({required Object count}) => '그 외 ${count}개';
}

// Path: home
class _Translations$home$ko extends Translations$home$en {
	_Translations$home$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '포터블 로거';
	@override String get newOperation => '새로운 운용';
	@override String get stationCallsign => '무선국 콜사인';
	@override String get titleOptional => '제목 (선택 사항)';
	@override String get emptyList => '아직 운용이 없습니다. 운용을 만들어 로깅을 시작하세요.';
	@override String get quickLookup => '빠른 조회';
	@override late final _Translations$home$nav$ko nav = _Translations$home$nav$ko._(_root);
	@override late final _Translations$home$panels$ko panels = _Translations$home$panels$ko._(_root);
	@override String get toggleNav => '탐색 레이블 표시/숨기기';
	@override late final _Translations$home$logs$ko logs = _Translations$home$logs$ko._(_root);
}

// Path: chase
class _Translations$chase$ko extends Translations$chase$en {
	_Translations$chase$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => '추적 중';
	@override String goalsTwo({required Object first, required Object second}) => '${first} & ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} 외';
	@override late final _Translations$chase$station$ko station = _Translations$chase$station$ko._(_root);
	@override late final _Translations$chase$periodInline$ko periodInline = _Translations$chase$periodInline$ko._(_root);
	@override late final _Translations$chase$periodStats$ko periodStats = _Translations$chase$periodStats$ko._(_root);
	@override late final _Translations$chase$period$ko period = _Translations$chase$period$ko._(_root);
	@override late final _Translations$chase$goals$ko goals = _Translations$chase$goals$ko._(_root);
	@override late final _Translations$chase$panels$ko panels = _Translations$chase$panels$ko._(_root);
	@override late final _Translations$chase$claims$ko claims = _Translations$chase$claims$ko._(_root);
	@override late final _Translations$chase$notice$ko notice = _Translations$chase$notice$ko._(_root);
	@override late final _Translations$chase$alerts$ko alerts = _Translations$chase$alerts$ko._(_root);
	@override String get checklists => '추적 진행 상황';
	@override late final _Translations$chase$imports$ko imports = _Translations$chase$imports$ko._(_root);
}

// Path: dialogs
class _Translations$dialogs$ko extends Translations$dialogs$en {
	_Translations$dialogs$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => '운용 상세';
	@override String get activities => '활동';
	@override String get stationCallsign => '무선국 콜사인';
	@override String get advanced => '고급';
	@override String get operatingPosition => '운용 포지션 (다중 무선국)';
	@override String get assistance => '어시스턴스';
	@override String get assistanceDescription => '스팟 서비스 및 기타 정보 소스 사용';
	@override String get selfSpotting => '자체 스팟';
	@override String get selfSpottingDescription => '내 주파수 정보를 알리는 기능 허용';
	@override String disabledByRules({required Object rules}) => '${rules} 규정 준수를 위해 비활성화됨';
	@override late final _Translations$dialogs$lookupDespiteAssistance$ko lookupDespiteAssistance = _Translations$dialogs$lookupDespiteAssistance$ko._(_root);
	@override String get notes => '메모';
	@override String get deleteOperationTitle => '운용 삭제';
	@override String get purgeTestsTitle => '테스트 운용 영구 삭제';
	@override String get purgeTestsBody => '이 테스트 운용과 해당 QSO를 영구적으로 삭제합니다. 되돌릴 수 없습니다.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '운용에 속하지 않은 테스트 교신 ${count}개도 포함됩니다.',
		other: '운용에 속하지 않은 테스트 교신 ${count}개도 포함됩니다.',
	);
	@override String get purgeTestsAction => '영구 삭제';
	@override String get syncAllTitle => '이 기기의 로그를 대체할까요?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL은 이 기기의 ${qsos}을(를) 백업하고 지운 후, 서버에서 계정의 로그를 다시 다운로드합니다. 백업은 이 기기의 데이터베이스에 남습니다.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: 'QSO ${n}개가 아직 동기화되지 않았습니다. 서버가 받지 못했으므로 복구되지 않습니다.',
		other: 'QSO ${n}개가 아직 동기화되지 않았습니다. 서버가 받지 못했으므로 복구되지 않습니다.',
	);
	@override String get syncAllAction => '삭제 후 다시 동기화';
	@override String get receivedPurgesTitle => '다른 곳에서 삭제된 테스트 운용';
	@override String get receivedPurgesBody => '다른 기기에서 테스트 운용으로 삭제된 항목입니다. 여기서도 제거할까요? 해당 운용과 QSO가 영구적으로 삭제되며 되돌릴 수 없습니다.';
	@override String get receivedPurgesAction => '제거';
	@override late final _Translations$dialogs$callChange$ko callChange = _Translations$dialogs$callChange$ko._(_root);
}

// Path: operation
class _Translations$operation$ko extends Translations$operation$en {
	_Translations$operation$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => '삭제된 운용입니다. 로깅하거나 변경하려면 운용을 복구하세요.';
	@override late final _Translations$operation$tabs$ko tabs = _Translations$operation$tabs$ko._(_root);
	@override late final _Translations$operation$positions$ko positions = _Translations$operation$positions$ko._(_root);
	@override String get stationCallsignNone => '무선국 콜사인 없음';
	@override String get titleNone => '제목 없음';
	@override String get deleteOperation => '운용 삭제';
	@override String get loggingControlsStale => '활동 필드가 최신이 아닐 수 있습니다. 운용을 다시 열어 새로고침하세요';
	@override String get locationNone => '설정되지 않음';
	@override String get generalOperation => '일반 운용';
	@override String titleFor({required Object value}) => '${value}';
	@override String titleAt({required Object value}) => '${value}에서';
	@override String segmentNow({required Object description}) => '현재 ${description}';
	@override String get testOperationSuffix => '테스트';
	@override late final _Translations$operation$menu$ko menu = _Translations$operation$menu$ko._(_root);
	@override late final _Translations$operation$layout$ko layout = _Translations$operation$layout$ko._(_root);
	@override late final _Translations$operation$export$ko export = _Translations$operation$export$ko._(_root);
	@override late final _Translations$operation$spots$ko spots = _Translations$operation$spots$ko._(_root);
	@override late final _Translations$operation$import$ko import = _Translations$operation$import$ko._(_root);
}

// Path: map
class _Translations$map$ko extends Translations$map$en {
	_Translations$map$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$ko outlineIssue = _Translations$map$outlineIssue$ko._(_root);
	@override String get outlinesDisclaimer => '경계선은 참고용입니다. 직접 확인하세요!';
	@override String outlinesCredit({required Object sources}) => '경계선: ${sources}';
	@override String boundariesCredit({required Object sources}) => '행정 경계: ${sources}';
	@override String facilitiesCredit({required Object sources}) => '시설: ${sources}';
	@override String get fullCredits => '전체 데이터 출처';
	@override String get fewerCredits => '출처 줄이기';
	@override String get emptyState => '아직 QSO 위치가 없습니다.\n그리드 스퀘어, 주 또는 국가가 있는 QSO가 여기에 표시됩니다.';
	@override String get unavailable => '지금은 지도를 사용할 수 없습니다.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => '평면';
	@override String get globe => '지구본';
	@override String get zoomIn => '확대';
	@override String get zoomOut => '축소';
	@override String get resetNorth => '북쪽을 위로';
	@override late final _Translations$map$postcard$ko postcard = _Translations$map$postcard$ko._(_root);
}

// Path: mapsView
class _Translations$mapsView$ko extends Translations$mapsView$en {
	_Translations$mapsView$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '지도';
	@override String get searchHint => '공원, 산정상 등 검색';
	@override String get activities => '활동';
	@override String get layers => '레이어';
	@override String get baseMap => '기본 지도';
	@override String get satellite => '위성 (Esri)';
	@override String get facilities => '공원 시설';
	@override String get boundaries => '행정 경계';
	@override String get currentLocation => '현재 위치';
	@override String noMatches({required Object text}) => '“${text}”과(와) 일치하는 항목이 없습니다';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${where}의 레퍼런스 ${count}개',
		other: '${where}의 레퍼런스 ${count}개',
	);
	@override String get startOperation => '이 레퍼런스로 운용 시작';
}

// Path: activitiesView
class _Translations$activitiesView$ko extends Translations$activitiesView$en {
	_Translations$activitiesView$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '활동';
	@override String get activitiesCountZero => '선택된 활동 없음';
	@override String get activitiesCountOne => '활동 1개';
	@override String activitiesCountOther({required Object count}) => '활동 ${count}개';
	@override String get empty => '아직 활동이 없습니다. 아래의 추천 및 검색으로 추가하세요';
	@override String get removeActivity => '제거';
	@override String openReferenceLink({required Object name}) => '${name} 열기';
	@override String get editActivity => '활동 편집';
	@override String get manageExtensions => '확장 기능 관리';
	@override String get manage => '관리';
	@override String activitiesTitle1({required Object first}) => '활동 유형: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => '활동 유형: ${first}, ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => '활동 유형: ${first}, ${second} 외 ${more}개';
	@override String get reference => '레퍼런스';
	@override String get invalidReference => '유효하지 않음';
	@override String get duplicateReference => '이미 추가됨';
	@override String get searchHint => '이름, 레퍼런스 등으로 검색…';
	@override String get noSuggestions => '일치 항목 없음';
	@override String get noSuggestionsHint => '위에서 레퍼런스 이름이나 번호로 검색하세요';
	@override String get noSuggestionsExample => '(예: \'trail\' 또는 \'4556\')';
	@override String get allOptions => '활동 유형';
	@override String get determiningLocation => '현재 위치 확인 중…\n근처 레퍼런스를 찾기 위해 GPS 수신 대기 중';
	@override String get locationUnavailableTitle => '위치 데이터를 사용할 수 없음';
	@override String get locationDeniedTitle => '위치 권한 거부됨';
	@override String get locationBlockedTitle => '위치 권한 차단됨';
	@override String get noNearbyReason => '근처 레퍼런스를 확인할 수 없습니다';
	@override String locationManualHint({required Object icon}) => '${icon}을(를) 탭하여 위치를 직접 입력하거나,\n이름으로 레퍼런스를 검색하세요';
	@override String get locationGrantAction => '위치 접근 허용';
	@override String get locationSettingsAction => '설정 열기';
	@override String get locationSettingsUnavailable => '시스템 설정에서 위치 접근을 허용하세요';
	@override String get locationGrantRefused => '여전히 위치 없음 — 시스템이 다시 거부했습니다';
	@override String get searchUnavailableTitle => '활동 검색을 사용할 수 없음';
	@override String get searchUnavailableReason => '활동 확장 기능이 검색에 응답하지 못했습니다. 잠시 후 다시 시도하세요.';
	@override String get emptySheet => '아래의 추천 및 검색으로 추가하세요';
	@override String get exports => '내보내기';
	@override String get exportLogs => '로그 내보내기';
	@override String get tools => '도구';
	@override String get toolsTitle => '운용 도구';
	@override String get operationDetails => '운용 상세';
	@override String get share => '공유';
	@override String get archive => '아카이브';
	@override String get deleteOperation => '운용 삭제';
	@override String get undeleteOperation => '운용 복구';
	@override String get alreadySelected => '이미 선택됨';
	@override String get selected => '선택됨';
	@override String pickPosition({required Object index, required Object count}) => '${index} / ${count}';
	@override String get previousPick => '이전 일치 항목';
	@override String get nextPick => '다음 일치 항목';
	@override String get retiredReference => '폐지됨';
	@override String enableExtension({required Object name}) => '${name} 활성화';
	@override String get enableExtensionHint => '이 확장 기능이 검색과 일치하지만 현재 활성화되어 있지 않습니다';
	@override String get enableExtensionForRefHint => '이 확장 기능이 이 운용의 레퍼런스 중 하나를 처리하지만 현재 활성화되어 있지 않습니다';
	@override String extensionNotRunning({required Object name}) => '${name}이(가) 실행되고 있지 않습니다';
	@override String get extensionNotRunningHint => '이 확장 기능은 비활성화되었습니다. 자세한 내용은 확장 기능 설정을 여세요';
	@override String installExtension({required Object name}) => '${name} 설치';
	@override String get installExtensionHint => '이 확장 기능이 검색과 일치하지만 설치되어 있지 않습니다';
	@override String get onlyCatalogMatches => '일치 항목 없음\n카탈로그의 일부 확장 기능에 결과가 있을 수 있습니다.\n아래 활동 유형에서 설치하세요.';
	@override String get setupUnavailable => '이 활동의 설정을 불러올 수 없습니다. 관리에서 다시 시도하세요';
	@override String get controlsUnavailableTitle => '활동 컨트롤을 사용할 수 없음';
	@override String get controlsUnavailableReason => '레퍼런스는 안전하지만 지금은 편집할 수 없습니다.';
	@override String get controlsUnavailableRetry => '다시 시도';
	@override String get onlyDisabledMatches => '일치 항목 없음\n사용 가능한 일부 확장 기능에 결과가 있을 수 있습니다.\n아래 활동 유형에서 활성화하세요.';
	@override String get onlyNotRunningMatches => '일치 항목 없음\n결과가 있을 수 있는 일부 확장 기능이 실행되고 있지 않습니다.\n아래 활동 유형을 확인하세요.';
	@override String get mapToggle => '지도';
	@override String get searchToggle => '검색';
	@override String get addToOperation => '운용에 추가';
	@override String get addToOperationShort => '운용에 추가';
	@override String get mapEmptyState => '지도에 표시할 결과가 없습니다';
	@override String get mapEmptyStateHint => '목록으로 돌아가거나 다른 항목을 검색하세요';
	@override String get imports => '가져오기';
}

// Path: loggingControls
class _Translations$loggingControls$ko extends Translations$loggingControls$en {
	_Translations$loggingControls$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => '시간 (UTC)';
	@override String get date => '날짜';
	@override String get now => '현재';
	@override String get manualTimeSettings => '수동 시간';
	@override String get manualTimeIncrement => 'QSO당 증가량';
	@override String get manualTimeIncrementNone => '없음';
	@override String manualTimeIncrementMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}분',
		other: '${count}분',
	);
	@override String get frequency => '주파수';
	@override String get mode => '모드';
	@override String get theirCall => '상대 콜사인';
	@override String get noteField => '메모';
	@override String get todoField => '할 일';
	@override String get sent => '보냄';
	@override String get rcvd => '받음';
	@override String get more => '더보기';
	@override String get revert => '되돌리기';
	@override String get undoDelete => '삭제 취소';
	@override String get restore => '복원';
	@override String get wipe => '지우기';
	@override String get undo => '실행 취소';
	@override String get pendingDeleteTapWarning => '이 QSO를 삭제하려면 휴지통을 한 번 더 탭하세요';
	@override String get pendingDeleteClickWarning => '이 QSO를 삭제하려면 휴지통을 한 번 더 클릭하세요';
	@override String get deletedQsoWarning => '삭제된 QSO';
	@override String pendingDeleteEventTapWarning({required Object kind}) => '이 ${kind}을(를) 삭제하려면 휴지통을 한 번 더 탭하세요';
	@override String pendingDeleteEventClickWarning({required Object kind}) => '이 ${kind}을(를) 삭제하려면 휴지통을 한 번 더 클릭하세요';
	@override String deletedEventWarning({required Object kind}) => '삭제된 ${kind}';
	@override String get timeControl => '시간';
	@override String get radioControl => '무전기';
	@override String get powerControl => '출력';
	@override String get notesControl => '메모';
	@override String get power => '출력';
	@override String get powerUnit => 'W';
	@override String get controlSettings => '로깅 컨트롤';
	@override String get spottingControl => '스팟';
	@override String get spottingSelfControl => '자체 스팟';
	@override String spotSelfAt({required Object freq}) => '${freq}에서 자체 스팟';
	@override String spotOtherAt({required Object call, required Object freq}) => '${call}을(를) ${freq}에서 스팟';
	@override String spotTooLate({required Object call}) => '${call}을(를) 스팟하기에 너무 늦었습니다';
	@override String get spotNoFreq => '스팟하려면 먼저 주파수를 지정하세요';
	@override String get selfSpotDisabled => '자체 스팟 비활성화됨';
	@override String get spotComment => '코멘트';
	@override String get spottingAutoControl => '자동 재스팟';
	@override String spotAutoEvery({required Object minutes}) => '${minutes}분마다 재스팟';
	@override String spotAutoNext({required Object time}) => '${time} 후 자동. 중지할까요?';
	@override String spotAutoInMinutes({required Object minutes}) => '${minutes}분 후 자동';
	@override String spotAutoInSeconds({required Object seconds}) => '${seconds}초 후 자동';
	@override String spotAutoInCount({required Object seconds}) => '${seconds} 후 자동';
	@override String get spotAutoNotStarted => '자동 재스팟 시작 안 됨: 스팟이 전송되지 않았습니다';
	@override String get spotAutoMoved => '자동 재스팟 시작 안 됨: 스팟 중에 주파수가 변경되었습니다';
	@override String get spotAutoStopped => '자동 재스팟 중지됨';
	@override String get spotAutoLeftFreq => '자동 재스팟 중지됨: 주파수가 변경되었습니다';
	@override String get spotAutoNoFreq => '자동 재스팟 중지됨: 무전기가 주파수를 보고하지 않습니다';
	@override String get spotBusy => '다른 스팟을 아직 전송 중입니다';
	@override String get bandOrFreqRequired => '로깅 전에 주파수나 밴드를 지정하세요';
	@override String get missingBand => '밴드 없음';
	@override String get missingMode => '모드 없음';
	@override String saveFailed({required Object error}) => '저장할 수 없습니다: ${error}';
	@override String deleteFailed({required Object error}) => '삭제할 수 없습니다: ${error}';
	@override late final _Translations$loggingControls$info$ko info = _Translations$loggingControls$info$ko._(_root);
}

// Path: formChrome
class _Translations$formChrome$ko extends Translations$formChrome$en {
	_Translations$formChrome$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(제목 없음)';
	@override String get showMore => '더 보기';
	@override String get showAll => '모두 보기';
	@override String get showFewer => '간략히 보기';
	@override String get defaults => '기본값';
	@override String get search => '검색';
	@override String get clear => '지우기';
	@override String get openPage => '페이지 열기';
	@override String get connected => '연결됨';
	@override String get notConnected => '연결 안 됨';
	@override String get manage => '관리';
	@override String get connect => '연결';
	@override String get formTitle => '양식';
	@override String addItem({required Object label}) => '${label} 추가';
	@override String editItem({required Object label}) => '${label} 편집';
	@override String multiselectStatus({required Object total, required Object shown, required Object selected}) => '${total}개 중 ${shown}개 표시 (${selected}개 선택됨)';
	@override String validationError({required Object error}) => '유효성 검사 오류: ${error}';
	@override String transformationError({required Object error}) => '변환 오류: ${error}';
	@override String actionError({required Object error}) => '오류: ${error}';
	@override String get removeItem => '삭제';
	@override String deleteItemTitle({required Object name}) => '${name}을(를) 삭제할까요?';
	@override String get storageUnavailable => '로그인 정보를 사용할 수 없음';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$ko extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSO 수정';
	@override String get operatorCall => '오퍼레이터';
	@override String get position => '포지션';
	@override String get theirName => '이름';
	@override String get theirGrid => '그리드';
	@override String get theirState => '주';
	@override String get band => '밴드';
	@override String get notes => '메모';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => '상대의 정보';
	@override String get sectionOur => '나의 정보';
	@override String get sectionNotes => '메모';
	@override String get theirCity => '도시';
	@override String get theirCounty => '시/군';
	@override String get theirEntity => '엔티티';
	@override String get theirCqZone => 'CQ 존';
	@override String get theirItuZone => 'ITU 존';
	@override String get theirArrlSection => 'ARRL 섹션';
	@override String get theirLat => '위도';
	@override String get theirLon => '경도';
	@override String get theirPower => '상대 출력';
}

// Path: qsoList
class _Translations$qsoList$ko extends Translations$qsoList$en {
	_Translations$qsoList$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get empty => '아직 QSO가 없습니다. 교신을 시작하세요!';
	@override String get bandOrModeWarning => '밴드와 모드가 올바른지 확인하세요';
	@override String get today => '오늘';
	@override String get yesterday => '어제';
	@override String get tomorrow => '내일';
	@override late final _Translations$qsoList$find$ko find = _Translations$qsoList$find$ko._(_root);
}

// Path: loggingPanel
class _Translations$loggingPanel$ko extends Translations$loggingPanel$en {
	_Translations$loggingPanel$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get stats => '운용 통계';
	@override String get scoring => '점수';
	@override String get dxccEntities => 'DXCC 엔티티';
	@override String get statesWorked => '주';
	@override String get provincesWorked => '주/도';
	@override String get duplicates => '중복';
}

// Path: callInfo
class _Translations$callInfo$ko extends Translations$callInfo$en {
	_Translations$callInfo$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => '이미지 표시';
	@override String get imageUnavailable => '사진을 사용할 수 없음';
	@override String get photo => '사진';
	@override String get notes => '메모';
	@override String distanceTo({required Object distance}) => '${distance} →';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) →';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) →';
	@override String distanceAway({required Object distance}) => '${distance} 거리';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) 거리';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) 거리';
	@override String get thisOpCountOne => '이 운용에서 1 QSO';
	@override String thisOpCountOther({required Object count}) => '이 운용에서 ${count} QSO';
	@override String get otherOpsCountOne => '다른 운용에서 1 QSO';
	@override String otherOpsCountOther({required Object count}) => '다른 운용에서 ${count} QSO';
	@override String andMore({required Object count}) => '… + ${count}개';
	@override String withCall({required Object call}) => '${call}와 함께';
	@override String fromOperation({required Object where}) => '${where}에서';
	@override late final _Translations$callInfo$history$ko history = _Translations$callInfo$history$ko._(_root);
}

// Path: settings
class _Translations$settings$ko extends Translations$settings$en {
	_Translations$settings$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '설정';
	@override String get language => '언어';
	@override String languageSystem({required Object language}) => '시스템 설정 따르기 (${language})';
	@override late final _Translations$settings$theme$ko theme = _Translations$settings$theme$ko._(_root);
	@override late final _Translations$settings$themeDescription$ko themeDescription = _Translations$settings$themeDescription$ko._(_root);
	@override String get fontScale => '글꼴 크기';
	@override late final _Translations$settings$fontScaleOpts$ko fontScaleOpts = _Translations$settings$fontScaleOpts$ko._(_root);
	@override late final _Translations$settings$keepDeviceAwake$ko keepDeviceAwake = _Translations$settings$keepDeviceAwake$ko._(_root);
	@override String get layoutDensity => '레이아웃 밀도';
	@override late final _Translations$settings$layoutDensityOpts$ko layoutDensityOpts = _Translations$settings$layoutDensityOpts$ko._(_root);
	@override String layoutDensityClamped({required Object effective}) => '창 높이가 너무 낮아 ${effective} 사용 중';
	@override String get layoutDensityAtLimit => '최대한 적용됨';
	@override String get distanceUnits => '거리 단위';
	@override late final _Translations$settings$distanceUnitsOpts$ko distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$ko._(_root);
	@override String get userInterface => '사용자 인터페이스';
	@override late final _Translations$settings$logging$ko logging = _Translations$settings$logging$ko._(_root);
	@override late final _Translations$settings$catServer$ko catServer = _Translations$settings$catServer$ko._(_root);
	@override late final _Translations$settings$cluster$ko cluster = _Translations$settings$cluster$ko._(_root);
	@override late final _Translations$settings$spotting$ko spotting = _Translations$settings$spotting$ko._(_root);
	@override late final _Translations$settings$radio$ko radio = _Translations$settings$radio$ko._(_root);
	@override late final _Translations$settings$help$ko help = _Translations$settings$help$ko._(_root);
	@override late final _Translations$settings$exports$ko exports = _Translations$settings$exports$ko._(_root);
	@override late final _Translations$settings$extensionSections$ko extensionSections = _Translations$settings$extensionSections$ko._(_root);
	@override late final _Translations$settings$map$ko map = _Translations$settings$map$ko._(_root);
	@override late final _Translations$settings$privacy$ko privacy = _Translations$settings$privacy$ko._(_root);
	@override String get operatorCall => '오퍼레이터 콜사인';
	@override late final _Translations$settings$sync$ko sync = _Translations$settings$sync$ko._(_root);
	@override late final _Translations$settings$peers$ko peers = _Translations$settings$peers$ko._(_root);
	@override String get developerMode => '개발자 모드';
	@override late final _Translations$settings$syncPanel$ko syncPanel = _Translations$settings$syncPanel$ko._(_root);
	@override late final _Translations$settings$accounts$ko accounts = _Translations$settings$accounts$ko._(_root);
	@override late final _Translations$settings$station$ko station = _Translations$settings$station$ko._(_root);
	@override late final _Translations$settings$offlineData$ko offlineData = _Translations$settings$offlineData$ko._(_root);
	@override late final _Translations$settings$profiles$ko profiles = _Translations$settings$profiles$ko._(_root);
	@override late final _Translations$settings$search$ko search = _Translations$settings$search$ko._(_root);
	@override late final _Translations$settings$developer$ko developer = _Translations$settings$developer$ko._(_root);
	@override late final _Translations$settings$about$ko about = _Translations$settings$about$ko._(_root);
	@override late final _Translations$settings$panels$ko panels = _Translations$settings$panels$ko._(_root);
	@override String get showMoreSettings => '추가 설정 표시';
	@override String get gridPrecision => '그리드 정밀도';
	@override late final _Translations$settings$gridPrecisionOpts$ko gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$ko._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$ko gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$ko._(_root);
}

// Path: commands
class _Translations$commands$ko extends Translations$commands$en {
	_Translations$commands$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => '먼저 설정에서 동기화를 활성화하세요.';
	@override String get fullResyncStarted => '전체 재동기화를 시작했습니다. 로컬 데이터는 먼저 백업되었습니다.';
	@override String noDataFilesMatched({required Object target}) => '"${target}"과(와) 일치하는 데이터 파일이 없습니다.';
	@override String reloadFailed({required Object error}) => '다시 불러오기 실패: ${error}';
	@override String get reloadingAll => '모든 데이터 파일 다시 불러오는 중…';
	@override String reloadingTarget({required Object target}) => '${target} 데이터 파일 다시 불러오는 중…';
	@override String unknownExperiment({required Object token}) => '알 수 없는 실험기능 "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} 활성화됨';
	@override String experimentDisabled({required Object name}) => '${name} 비활성화됨';
	@override String get sentryTestSent => '테스트 오류 보고서를 Sentry로 보냈습니다';
	@override String get idleMetricsEnabled => '상태 표시줄의 유휴 지표 활성화됨';
	@override String get idleMetricsDisabled => '유휴 지표 비활성화됨';
	@override String get sentryTestLocalOnly => '이 빌드에서는 Sentry가 비활성화되어 있습니다. 테스트 오류는 로컬에만 기록되었습니다';
	@override String get noOperationOpen => '이 명령은 운용이 열려 있어야 사용할 수 있습니다';
	@override String unknownSegmentKind({required Object kind}) => '\'${kind}\'을(를) 표시하는 방법을 모릅니다';
	@override String goUnavailable({required Object place}) => '${place}은(는) 이 앱에서 켜져 있지 않습니다';
	@override String goUnknown({required Object to}) => '\'${to}\'(으)로 이동하는 방법을 모릅니다';
	@override String get goBlocked => '먼저 열린 대화 상자를 닫으세요';
	@override String get operationAlreadyStarted => '이 운용에는 이미 시작 마커가 있습니다';
	@override String get couldNotOpenLocation => '휴식을 추가했지만 위치 화면을 열 수 없습니다';
	@override String get noTestOperations => '영구 삭제할 테스트 운용이 없습니다';
	@override String get purgeTestsUnavailable => 'PURGETESTS는 확인 대화 상자를 표시해야 하지만 여기서는 사용할 수 없습니다';
	@override String get syncAllUnavailable => 'SYNCALL은 확인 대화 상자를 표시해야 하지만 여기서는 사용할 수 없습니다';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '테스트 운용 ${count}개를 영구 삭제했습니다',
		other: '테스트 운용 ${count}개를 영구 삭제했습니다',
	);
	@override String purgeTestsSomeFailed({required Object total, required Object purged}) => '테스트 운용 ${total}개 중 ${purged}개를 영구 삭제했습니다. 나머지는 실패했으니 PURGETESTS를 다시 시도하세요';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '운용에 속하지 않은 테스트 교신 ${count}개를 영구 삭제했습니다',
		other: '운용에 속하지 않은 테스트 교신 ${count}개를 영구 삭제했습니다',
	);
	@override String get purgeTestsContactsFailed => '테스트 운용은 영구 삭제했지만, 운용에 속하지 않은 테스트 교신은 실패했습니다. PURGETESTS를 다시 시도하세요';
	@override String get purgeTestsNothingToDo => '영구 삭제된 항목이 없습니다';
	@override String receivedPurgesSomeFailed({required Object total, required Object removed}) => '테스트 운용 ${total}개 중 ${removed}개를 제거했습니다. 나머지는 실패했으니 검토를 다시 시도하세요';
	@override String get receivedPurgesFailed => '해당 테스트 운용을 제거할 수 없습니다. 검토를 다시 시도하세요';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '다른 기기에서 테스트 운용 ${count}개가 제거되었습니다',
		other: '다른 기기에서 테스트 운용 ${count}개가 제거되었습니다',
	);
	@override String get receivedPurgesReview => '검토';
	@override String get settingOn => '켜짐';
	@override String get settingOff => '꺼짐';
	@override String get settingEmpty => '(비어 있음)';
	@override String get settingSecretSet => '(설정됨)';
	@override String get settingSecretUnset => '(설정되지 않음)';
	@override String settingSelectedCount({required Object count}) => '${count}개 선택됨';
	@override String get settingExpectsOnOff => 'on 또는 off';
	@override String settingExpectsOneOf({required Object choices}) => '다음 중 하나: ${choices}';
	@override String get settingExpectsNumber => '숫자';
	@override String settingVanished({required Object label}) => '“${label}”을(를) 더 이상 사용할 수 없습니다';
	@override String get noCwKeyer => 'CW를 키잉할 수 있는 연결된 무전기가 없습니다';
	@override String get noKeyer => 'CW를 키잉하거나 보이스 메모리를 재생할 수 있는 연결된 무전기가 없습니다';
	@override String get keyerNeedsOperation => 'CW 키어를 사용하려면 운용을 여세요';
	@override String get keyerExperimentOff => 'CW 키잉이 꺼져 있습니다. EXP KEYER로 켜세요';
	@override String get esmExperimentOff => 'Enter로 메시지 전송이 꺼져 있습니다. EXP ESM으로 켜세요';
	@override String cwSending({required Object text}) => 'CW 전송 중: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'CW 메시지 F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'CW 메시지 F${n}을(를) 보내지 못했습니다: 확장 기능이 준비되지 않았습니다';
	@override String voiceMessageError({required Object n, required Object error}) => '보이스 메시지 M${n}: ${error}';
	@override String get voiceMessageNotRendered => '확장 기능이 준비되지 않았습니다';
	@override String so2rRadioCannotKey({required Object radio}) => '전송되지 않음: 무전기 ${radio}은(는) 해당 메시지를 키잉할 수 없습니다';
	@override String get so2rNoRadioB => '전송되지 않음: 이 메시지 세트로 키잉하려면 무선국 구성에서 무전기 B를 선택하세요';
	@override String settingNotStored({required Object label}) => '“${label}”이(가) 해당 값을 받아들이지 않았습니다';
}

// Path: commandDialog
class _Translations$commandDialog$ko extends Translations$commandDialog$en {
	_Translations$commandDialog$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get hint => '콜사인을 검색하거나 명령을 입력하세요';
	@override String noResults({required Object text}) => '“${text}”과(와) 일치하는 항목이 없습니다';
	@override String get sectionCommands => '명령';
	@override String get sectionGoTo => '이동';
	@override String get sectionOperations => '운용';
	@override String get goHome => '홈';
	@override String get goSettings => '설정';
	@override String get goNewOperation => '새로운 운용';
	@override String runTyped({required Object text}) => '“${text}” 실행';
	@override String get sectionSuggestions => '추천';
	@override String get lookingUp => '콜사인 조회 중…';
	@override String get blockedByPane => '패널이나 대화 상자가 열려 있는 동안에는 명령을 사용할 수 없습니다';
}

// Path: keyboardShortcuts
class _Translations$keyboardShortcuts$ko extends Translations$keyboardShortcuts$en {
	_Translations$keyboardShortcuts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '키보드 단축키';
	@override String get description => '키 매핑 사용자 지정';
	@override String get search => '명령 및 키 검색';
	@override String get import => '가져오기…';
	@override String get export => '내보내기…';
	@override String get resetAll => '모두 초기화';
	@override String get resetAllTitle => '모든 단축키를 초기화할까요?';
	@override String get resetAllBody => '모든 명령이 기본 키로 돌아가고, 직접 입력한 명령에 할당된 키는 제거됩니다.';
	@override String get reset => '초기화';
	@override String get noKey => '키 없음';
	@override String get changed => '변경됨';
	@override String conflict({required Object keys, required Object commands}) => '${keys}은(는) ${commands}에도 할당되어 있습니다';
	@override String get groupApp => '앱';
	@override String get groupKeying => '키잉';
	@override String get groupLogging => '로깅';
	@override String get groupCommands => '명령';
	@override String get groupFixed => '고정 키';
	@override String get contextApp => '어디서나';
	@override String get contextLogView => '운용, 추적 및 로그 화면';
	@override String get contextOperation => '운용 화면, CAT 무전기 키잉 시';
	@override String get contextLogging => '로깅 패널에서';
	@override String get addCommand => '명령 추가…';
	@override String unknownCommand({required Object command}) => '알 수 없는 명령: ${command}';
	@override late final _Translations$keyboardShortcuts$command$ko command = _Translations$keyboardShortcuts$command$ko._(_root);
	@override late final _Translations$keyboardShortcuts$fixed$ko fixed = _Translations$keyboardShortcuts$fixed$ko._(_root);
	@override late final _Translations$keyboardShortcuts$editor$ko editor = _Translations$keyboardShortcuts$editor$ko._(_root);
	@override late final _Translations$keyboardShortcuts$file$ko file = _Translations$keyboardShortcuts$file$ko._(_root);
	@override late final _Translations$keyboardShortcuts$modifier$ko modifier = _Translations$keyboardShortcuts$modifier$ko._(_root);
	@override late final _Translations$keyboardShortcuts$platform$ko platform = _Translations$keyboardShortcuts$platform$ko._(_root);
}

// Path: expiredBuild
class _Translations$expiredBuild$ko extends Translations$expiredBuild$en {
	_Translations$expiredBuild$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '이 빌드는 만료되었습니다';
	@override String get body => 'ham2k.com을 방문하여 최신 버전을 받으세요.';
	@override String get visit => 'ham2k.com 방문';
	@override String get dismiss => '어쨌든 계속';
}

// Path: staleness
class _Translations$staleness$ko extends Translations$staleness$en {
	_Translations$staleness$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => '중요한 업데이트가 기다리고 있습니다';
	@override String get codePushFloorBody => '이 버전에는 아직 적용되지 않은 수정 사항이 있습니다.';
	@override String get restartToApply => '적용하려면 앱을 다시 시작하세요.';
	@override String get quitAndReopen => '적용하려면 앱을 종료하고 다시 여세요.';
	@override String get reopenToApply => '적용하려면 앱을 닫고 다시 여세요.';
	@override String get ignoreForNow => '지금은 무시';
}

// Path: spotting
class _Translations$spotting$ko extends Translations$spotting$en {
	_Translations$spotting$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => '스팟할 QSO가 아직 로깅되지 않았습니다.';
	@override String get setFrequencyFirst => '먼저 주파수를 지정하세요.';
	@override String get nothingToSpot => '스팟할 대상이 없습니다. 여기서 스팟을 제공하는 확장 기능이 없습니다.';
	@override String get incompleteCall => '불완전한 콜사인은 스팟할 수 없습니다. 먼저 콜사인을 완성하세요.';
	@override String spotFailed({required Object source, required Object message}) => '${source} 실패: ${message}';
	@override String get unknownError => '알 수 없는 오류';
	@override String get notSent => '스팟을 보내지 않았습니다.';
	@override String get allSkipped => '스팟을 보내지 않았습니다: 모든 스팟 출처가 건너뛰었습니다.';
	@override String get notRefreshedOffline => '연결 없음 — 스팟을 새로고침하지 않았습니다';
}

// Path: dataFiles
class _Translations$dataFiles$ko extends Translations$dataFiles$en {
	_Translations$dataFiles$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get downloading => '다운로드 중…';
	@override String downloadFailedTitle({required Object name}) => '${name}을(를) 다운로드할 수 없습니다';
	@override String get downloadFailedWebHint => '네트워크 문제이거나, 이 링크의 호스트가 웹 브라우저에서의 직접 다운로드를 지원하지 않을 수 있습니다. 데스크톱 또는 모바일 앱을 사용하거나 다른 호스팅 위치를 사용해 보세요.';
	@override String get downloadTimedOut => '서버 응답 시간이 너무 오래 걸렸습니다. 나중에 다시 시도하세요.';
	@override String downloadServerError({required Object host, required Object status}) => '${host}이(가) 오류로 응답했습니다 (HTTP ${status}). 나중에 다시 시도하세요.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host}이(가) 이 파일을 제공할 수 없습니다 (HTTP ${status}). 주소가 여전히 올바른지 확인하세요.';
	@override String n1mmHistoryNoMatch({required Object stem}) => 'N1MM에 ${stem}의 콜사인 히스토리 파일이 없습니다.';
	@override String n1mmHistoryUnavailable({required Object stem}) => 'N1MM에서 ${stem}의 콜사인 히스토리를 다운로드할 수 없습니다. 나중에 다시 시도하세요.';
	@override String processingFailedTitle({required Object name}) => '${name}을(를) 처리할 수 없습니다';
	@override String importTooSmall({required Object existing, required Object imported}) => '다운로드에 이 기기에 있는 기록 ${existing}개 중 ${imported}개만 있어서, 빠진 기록은 유지했습니다. 설정 › 오프라인 데이터에서 새로고침하면 그래도 받아들입니다.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${label}의 기록 ${count}개를 가져왔습니다.',
		other: '${label}의 기록 ${count}개를 가져왔습니다.',
	);
	@override String importedData({required Object label}) => '${label}의 데이터를 가져왔습니다.';
	@override String get cleanedUpTitle => '확장 기능 데이터 정리됨';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '비활성화된 확장 기능의 데이터 파일 ${count}개에 대한 데이터를 제거했습니다.',
		other: '비활성화된 확장 기능의 데이터 파일 ${count}개에 대한 데이터를 제거했습니다.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '기록 ${end} / ${total}';
	@override String get definitionUnavailable => '파일 출처가 정의를 제공하지 않았습니다. 해당 확장 기능이 재시작 중이거나 잘못 구성되었을 수 있습니다. 잠시 후 다시 시도하세요.';
}

// Path: updates
class _Translations$updates$ko extends Translations$updates$en {
	_Translations$updates$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => '업데이트 가능';
	@override String newVersionAvailable({required Object version}) => '새 버전(${version})을 사용할 수 있습니다.';
	@override String get getIt => '받기';
	@override String get ok => '확인';
	@override String get updateReady => '업데이트 준비됨';
	@override String get restartToApply => '업데이트를 다운로드했습니다. 적용하려면 다시 시작하세요.';
	@override String get appliesNextLaunch => '업데이트를 다운로드했습니다. 다음에 앱을 열 때 적용됩니다.';
	@override String get restartNow => '지금 다시 시작';
	@override String get reloadToUpdate => '이 페이지의 새 버전을 사용할 수 있습니다. 새로고침하여 받으세요.';
	@override String get reloadNow => '지금 새로고침';
	@override String get checkForUpdates => '업데이트 확인';
	@override String get checkingForUpdates => '업데이트 확인 중…';
	@override String get upToDate => '최신 상태';
	@override String get automaticChecks => '자동으로 확인';
	@override String get automaticChecksDescription => '다음에 앱을 시작할 때부터 백그라운드에서 새 버전 확인';
}

// Path: extensionService
class _Translations$extensionService$ko extends Translations$extensionService$en {
	_Translations$extensionService$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => '확장 기능 런타임이 준비되지 않았습니다.';
	@override String testFailed({required Object error}) => '테스트 실패: ${error}';
	@override String connectedAs({required Object identity}) => '${identity}(으)로 연결됨';
	@override String get invalidFieldConfiguration => '잘못된 필드 구성';
	@override String get invalidValue => '잘못된 값';
	@override String validationError({required Object error}) => '유효성 검사 오류: ${error}';
	@override String actionFailed({required Object error}) => '작업 실패: ${error}';
	@override String get commandFailed => '명령을 실행하지 못했습니다';
	@override String commandMayNotChangeSettings({required Object name}) => '${name}은(는) 설정을 변경할 수 없습니다: 설치 시 해당 권한을 요청하지 않았습니다';
	@override String commandMayNotControlRadio({required Object name}) => '${name}은(는) 무전기를 제어할 수 없습니다: 설치 시 해당 권한을 요청하지 않았습니다';
	@override String commandDeveloperOnly({required Object name}) => '${name}은(는) 그 명령을 실행할 수 없습니다: 앱 자체의 개발자 명령입니다';
	@override String commandDescribeBy({required Object describe, required Object extension}) => '${describe} · ${extension}';
	@override String get reportUnavailable => '지금은 보고서를 보낼 수 없습니다';
	@override String get stashUnavailable => '지금은 Ham2K File Stash에 연결할 수 없습니다';
	@override String activitySearchSourcesFailed({required Object names}) => '${names}이(가) 활동 검색에 응답하지 않아 일부 결과가 빠졌을 수 있습니다.';
	@override String get activitySearchSomeSourcesFailed => '일부 활동 확장 기능이 검색에 응답하지 않아 일부 결과가 빠졌을 수 있습니다.';
	@override String timersSuspendedBudget({required Object name}) => '${name}이(가) 타이머에서 너무 많은 시간을 사용했습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.';
	@override String timersSuspendedFailures({required Object name}) => '${name}의 타이머가 계속 실패했습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name}이(가) 타이머에서 멈췄습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$ko extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '운용 위치';
	@override String get selectedLocation => '선택된 위치';
	@override String get gridSquare => '그리드 로케이터';
	@override String get gridInvalid => 'FN31pr처럼 4, 6, 8 또는 10자여야 합니다';
	@override String get suggestedLocations => '추천 위치';
	@override String get deviceGps => '기기 GPS';
	@override String peerGps({required Object device}) => '${device}의 GPS';
	@override String get locating => '위치 찾는 중…';
	@override String get gpsUnavailable => '위치를 사용할 수 없음';
	@override String get permissionDenied => '위치 권한 거부됨';
	@override String get permissionBlocked => '위치 권한 차단됨';
	@override String get moreDetails => '상세 정보';
	@override String get stateOrProvince => '주/도 (선택 사항)';
	@override String get controlsUnavailableTitle => '활동 컨트롤을 사용할 수 없음';
	@override String get controlsUnavailableReason => '이 레퍼런스는 여전히 사용할 수 있으며, 해당 활동에 연결할 수 없을 뿐입니다.';
	@override String get controlsUnavailableRetry => '다시 시도';
	@override String get county => '시/군 (선택 사항)';
}

// Path: versionLabel
class _Translations$versionLabel$ko extends Translations$versionLabel$en {
	_Translations$versionLabel$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => '버전 ${version}';
	@override String patch({required Object patch}) => '패치 ${patch}';
	@override String build({required Object build}) => '빌드 ${build}';
}

// Path: notices
class _Translations$notices$ko extends Translations$notices$en {
	_Translations$notices$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => '아직 공지 없음';
	@override String get webStorageInMemory => '이 브라우저가 영구 저장소를 제공하지 못했습니다. 로그는 메모리에만 있으며 이 탭을 닫으면 사라집니다. 최신 Chrome, Firefox, Safari 또는 Edge를 사용하세요.';
	@override String get webStorageUnreliable => '이 브라우저는 여러 탭에서 안전하지 않은 대체 저장소를 사용 중입니다. 탭을 하나만 열어 두고 동기화를 켜 두세요.';
	@override String get logFromNewerBuildTitle => '이 로그에는 최신 버전이 필요합니다';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => '로그가 더 최신 버전의 HaLo로 작성되어(저장소 버전 ${storage}, 이 버전은 ${understood}까지 지원) 열 수 없으며, 새 교신도 저장되지 않습니다. 최신 버전을 다시 설치하거나, 이 빌드를 실행하려던 것이라면 다른 데이터 폴더를 지정하세요. 로그 위치: ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => '로그가 더 최신 버전의 HaLo로 작성되어(저장소 버전 ${storage}, 이 버전은 ${understood}까지 지원) 열 수 없으며, 새 교신도 저장되지 않습니다. 대신 해당 최신 버전으로 이 로그를 여세요.';
	@override String get preferencesRestoredTitle => '백업에서 설정을 복원했습니다';
	@override String get preferencesRestored => '설정 파일을 읽을 수 없어 HaLo가 마지막으로 정상이었던 사본을 복원했습니다. 이전 세션에서 변경한 내용은 다시 설정해야 할 수 있습니다. 읽을 수 없는 파일은 shared_preferences.corrupt-….json이라는 이름으로 같은 위치에 보관됩니다.';
	@override String get preferencesResetTitle => '설정 초기화됨';
	@override String get preferencesReset => '설정 파일을 읽을 수 없고 복원할 백업도 없어 HaLo가 기본값으로 시작했습니다. 읽을 수 없는 파일은 앱의 데이터 폴더에 shared_preferences.corrupt-….json이라는 이름으로 보관됩니다.';
	@override String autoConnectHeldTitle({required Object name}) => '${name}에 자동으로 연결하지 않았습니다';
	@override String autoConnectHeld({required Object name}) => '지난번 ${name}에 연결을 시작했을 때 HaLo가 응답을 멈췄기 때문에, 같은 일이 반복될 위험을 피하려고 이번에는 연결하지 않았습니다. 무전기 전원이 켜져 있고 케이블이 연결되어 있는지 확인한 후, 설정에서 해당 무전기의 연결을 누르세요.';
}

// Path: syncAccount
class _Translations$syncAccount$ko extends Translations$syncAccount$en {
	_Translations$syncAccount$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => '익명 계정 (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (확인 대기 중)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (확인 대기 중 - #${id})';
}

// Path: deepLink
class _Translations$deepLink$ko extends Translations$deepLink$en {
	_Translations$deepLink$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => '먼저 운용을 시작한 후 해당 교신을 다시 보내세요';
	@override String get waitingInOperation => '해당 교신은 이 화면 뒤의 운용에서 대기 중입니다';
	@override String unknownActivities({required Object refs}) => '이 기기에 ${refs}에 대한 활동이 없어 해당 레퍼런스를 제외했습니다';
	@override String activitiesUnavailable({required Object refs}) => '활동에 연결할 수 없어 ${refs}을(를) 제외했습니다. 링크를 다시 시도하세요';
}

// Path: confirmDevice
class _Translations$confirmDevice$ko extends Translations$confirmDevice$en {
	_Translations$confirmDevice$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '기기 확인';
	@override String get codePrompt => '이 계정에 연결하려는 기기에 표시된 코드를 입력하세요.';
	@override String get code => '코드';
	@override String get lookUp => '조회';
	@override String get codeNotFound => '해당 코드와 일치하는 요청이 없습니다. 코드는 10분 후 만료되니, 다른 기기에서 새 코드를 받으세요.';
	@override String get linkExpired => '링크가 만료되었습니다. 다른 기기에서 새 QR 코드를 표시하세요.';
	@override String areYouSure({required Object device}) => '${device}을(를) 이 계정에 연결할까요?';
	@override String get unnamedDevice => '이름 없는 기기';
	@override String get grantWarning => '이 계정의 모든 운용과 QSO를 읽고 변경할 수 있게 됩니다.';
	@override String get needsSyncTitle => '이 기기는 아직 동기화하지 않습니다';
	@override String get needsSyncText => '다른 기기를 승인하려면 먼저 Ham2K 로그 파일러 동기화를 켜고 이 기기를 계정에 연결하세요.';
	@override String get malformedRequest => '동기화 서버가 이 앱이 읽을 수 없는 요청을 보냈습니다. 다른 기기에서 다시 시도하세요.';
	@override String get linkIt => '기기 연결';
}

// Path: switchAccounts
class _Translations$switchAccounts$ko extends Translations$switchAccounts$en {
	_Translations$switchAccounts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => '아직 계정 정보 없음';
	@override String get currentAccount => '현재 계정';
	@override String get otherAccounts => '다른 계정';
	@override String get linkToAnother => '다른 계정에 연결';
	@override String get linkWithSibling => '다른 Ham2K 앱과 연결';
	@override String get linkWithPolo => '이전 버전의 계정과 연결';
	@override String get linkWithSiblingDescription => '다른 Ham2K 앱이 설치되어 있습니다. 그 앱에서 사용 중인 계정과 연결하세요.';
	@override String siblingPrompt({required Object app}) => '${app}에서 요청을 승인한 후 여기로 돌아오세요.';
	@override String openSiblingAgain({required Object app}) => '${app} 다시 열기';
	@override String get siblingNoGrant => '작동하지 않았나요? 다시 열거나, 돌아가서 다른 방법으로 연결하세요.';
	@override String siblingOpenFailed({required Object app}) => '${app}을(를) 열 수 없습니다.';
	@override String siblingLinkRenewed({required Object app}) => '링크가 만료되어 새 링크가 준비되었습니다. ${app}을(를) 다시 여세요.';
	@override String get tryAgain => '다시 시도';
	@override String get linkWithQr => 'QR 코드로 연결';
	@override String get linkWithQrDescription => '이미 계정을 사용 중인 기기로 스캔하세요';
	@override String get linkWithEmail => '이메일 주소로 연결';
	@override String get linkWithEmailDescription => '코드 또는 이메일 링크로 확인';
	@override String get enterEmailPrompt => '이 기기에서 사용할 계정의 이메일 주소를 입력하세요.';
	@override String get emailAddress => '이메일 주소';
	@override String get linkAccount => '계정 연결';
	@override String get copiedCode => '코드를 클립보드에 복사했습니다';
	@override String get copyCode => '코드 복사';
	@override String codePrompt({required Object email}) => '${email}과(와) 이미 연결된 기기에서 Ham2K 앱을 열고 이 코드를 입력하여 요청을 승인하세요:';
	@override String get waitingForConfirmation => '확인 대기 중…';
	@override String get sendEmailInstead => '대신 확인 이메일 보내기';
	@override String emailSent({required Object email}) => '${email}(으)로 이메일을 보냈습니다. 이메일을 열고 요청을 확인하면 이 기기가 연결됩니다.';
	@override String get resendEmail => '이메일 다시 보내기';
	@override String get qrPrompt => '원하는 계정에 이미 연결된 기기로 이 QR 코드를 스캔하세요. 예를 들어 휴대폰의 Ham2K Portable Logger로 스캔할 수 있습니다.';
	@override String get serverUnreachable => '동기화 서버에 연결할 수 없습니다. 나중에 다시 시도하세요.';
	@override String get emailRequired => '연결할 이메일 주소를 입력하세요.';
	@override String noAccountForEmail({required Object email}) => '${email}에 해당하는 계정이 없습니다.';
	@override String serverRejected({required Object error}) => '동기화 서버가 요청을 거부했습니다: ${error}';
	@override String get noLinkCode => '동기화 서버가 연결 코드를 반환하지 않았습니다. 나중에 다시 시도하세요.';
	@override String get noConfirmationCode => '동기화 서버가 확인 코드를 보내지 않았습니다. 나중에 다시 시도하세요.';
	@override String get switchNotAccepted => '해당 계정이 전환을 받아들이지 않았습니다. 대신 이메일 주소로 연결해 보세요.';
	@override String get requestFailed => '동기화 서버와 통신 중 문제가 발생했습니다. 나중에 다시 시도하세요.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count} QSO',
		other: '${count} QSO',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '운용 ${count}개',
		other: '운용 ${count}개',
	);
}

// Path: qsonImport
class _Translations$qsonImport$ko extends Translations$qsonImport$en {
	_Translations$qsonImport$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'QSON 운용 가져오기';
	@override String get description => '이 앱이나 PoLo의 개발자 모드에서 내보낸 QSON 파일로 새 운용을 만듭니다.';
	@override String get dropHint => 'QSON 파일을 끌어다 놓아 새 운용으로 가져오세요';
	@override String importing({required Object filename}) => '${filename} 가져오는 중…';
	@override String failed({required Object filename, required Object error}) => '${filename}을(를) 가져올 수 없습니다: ${error}';
	@override String pickerFailed({required Object error}) => '가져올 파일을 열 수 없습니다: ${error}';
	@override String notUtf8({required Object filename}) => '${filename}은(는) UTF-8 텍스트가 아니므로 QSON 파일이 아닙니다';
	@override String notJson({required Object filename}) => '${filename}은(는) JSON 파일이 아니므로 QSON 파일이 아닙니다';
	@override String notOperation({required Object filename}) => '${filename}에는 QSON 운용이 들어 있지 않습니다';
	@override String get busy => '이미 가져오기가 진행 중입니다. 완료될 때까지 기다린 후 시작하세요.';
	@override String get oneFileOnly => 'QSON 파일은 한 번에 하나씩 끌어다 놓으세요. 파일마다 별도의 운용으로 열립니다.';
}

// Path: adifImport
class _Translations$adifImport$ko extends Translations$adifImport$en {
	_Translations$adifImport$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'ADIF에서 QSO 가져오기';
	@override String reading({required Object filename}) => '${filename} 읽는 중…';
	@override String get dropHint => '가져올 ADIF 파일을 끌어다 놓으세요';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '이 파일의 QSO ${count}개',
		other: '이 파일의 QSO ${formatted}개',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개는 이미 로그에 있음',
		other: '${formatted}개는 이미 로그에 있음',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개를 가져옵니다',
		other: '${formatted}개를 가져옵니다',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '새 교신 ${count}개',
		other: '새 교신 ${formatted}개',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개는 기존 교신과 병합됩니다',
		other: '${formatted}개는 기존 교신과 병합됩니다',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개는 가져올 수 없습니다 (콜사인 없음)',
		other: '${formatted}개는 가져올 수 없습니다 (콜사인 없음)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개는 자세히 확인해야 합니다',
		other: '${formatted}개는 자세히 확인해야 합니다',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '교신 ${count}개의 레퍼런스를 복구할 수 없습니다',
		other: '교신 ${formatted}개의 레퍼런스를 복구할 수 없습니다',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '교신 ${count}개의 ${programs} 레퍼런스가 불완전할 수 있습니다',
		other: '교신 ${formatted}개의 ${programs} 레퍼런스가 불완전할 수 있습니다',
	);
	@override String get stackingTypesUnknown => '합쳐진 교신에서 레퍼런스가 빠질 수 있습니다. 활동이 어떤 유형을 함께 쓸 수 있는지 알려주지 못했습니다. 이를 피하려면 취소하고 다시 시도하세요.';
	@override String get nothingToImport => '이 파일에서 가져올 수 있는 것이 없습니다';
	@override String get confirm => '가져오기';
	@override String importing({required Object filename}) => '${filename} 가져오는 중…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${filename}에서 교신 ${count}개를 가져왔습니다',
		other: '${filename}에서 교신 ${formatted}개를 가져왔습니다',
	);
	@override String failed({required Object filename, required Object error}) => '${filename}을(를) 가져올 수 없습니다: ${error}';
	@override String notAdif({required Object filename}) => '${filename}은(는) ADIF 파일이 아닌 것 같습니다';
	@override String stationWarning({required Object calls, required Object station}) => '경고: 이 ADIF에는 ${calls}의 QSO가 있지만, 계속하면 ${station}(으)로 가져옵니다.';
	@override String get stationCallJoin => ' 및 ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개는 날짜가 없어 가져올 수 없습니다',
		other: '${formatted}개는 날짜가 없어 가져올 수 없습니다',
	);
	@override String activationFound({required Object refs}) => '이 파일에는 ${refs}의 활성화 기록이 있습니다.';
	@override String get addActivation => '이 운용에 추가';
	@override String shortfall({required Object planned, required Object written}) => '${planned}개 중 ${written}개만 적용할 수 있었습니다. 결정하는 동안 로그가 변경되었습니다.';
	@override String get busy => '이미 가져오기가 진행 중입니다. 완료될 때까지 기다린 후 시작하세요.';
	@override String get oneFileOnly => 'ADIF 파일은 한 번에 하나씩 끌어다 놓으세요. 파일을 가져오는 순서에 따라 어떤 데이터가 우선할지 결정됩니다.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename}에 QSO가 ${limit}개를 넘게 있습니다. 운용 하나에 한 번에 가져올 수 있는 최대치입니다.';
	@override String tooManyDeveloper({required Object filename, required Object limit}) => '${filename}에 QSO가 ${limit}개를 넘게 있습니다. 운용에 ADIF를 가져오는 기능은 QSO 몇 개를 추가하기 위한 것이지 큰 로그를 들여오기 위한 것이 아닙니다. 큰 로그는 로그 화면에서 가져오세요. 확실하다면 개발자 모드에서는 그래도 가져올 수 있습니다.';
	@override String get importAnyway => '어쨌든 가져오기';
}

// Path: offline
class _Translations$offline$ko extends Translations$offline$en {
	_Translations$offline$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => '인터넷: 오프라인';
	@override String get statusOnline => '인터넷: 연결됨';
	@override String get noRoute => '네트워크 연결이 전혀 없습니다.';
	@override String get unreachable => '네트워크는 연결되어 있지만 응답하는 서버가 없습니다. 브라우저에 로그인 페이지가 대기 중인 경우가 많습니다.';
	@override String get reachable => '모든 서비스가 정상적으로 응답하고 있습니다.';
	@override String get whatStops => '조회, 스팟 및 데이터 파일이 일시 중지되었습니다. 로깅과 근처 기기 동기화는 계속됩니다.';
	@override String get servicesTitle => '서비스';
	@override String get noServices => '아직 응답을 보고한 서비스가 없습니다.';
	@override String lastSuccess({required Object when}) => '${when} 전에 마지막으로 응답함';
	@override String get neverSucceeded => '아직 응답하지 않음';
	@override String nextAttempt({required Object when}) => '${when} 후 다시 시도';
	@override String get nextAttemptNow => '곧 다시 시도';
	@override String get retry => '지금 다시 시도';
	@override String get retrying => '시도 중…';
	@override String get retryReached => '다시 온라인 상태입니다.';
	@override String get retryUnreachable => '여전히 응답이 없습니다.';
	@override String get retryNotAttempted => '지금은 보낼 것이 없습니다.';
	@override String get retryThrottled => '방금 시도했습니다. 잠시 기다리세요.';
	@override String get retryDisabled => '동기화가 꺼져 있어 확인할 대상이 없습니다.';
	@override String get syncService => 'Ham2K LoFi 동기화';
	@override String get retryInFlight => '이미 시도 중입니다. 잠시 기다리세요.';
}

// Path: exportSettings
class _Translations$exportSettings$ko extends Translations$exportSettings$en {
	_Translations$exportSettings$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => '모든 내보내기의 기본 설정이며, 레퍼런스 활동과 기타 활동에 대해 별도의 파일 이름 및 제목 템플릿이 있습니다. 내보내기 유형마다 자체 기본값이나 사용자 정의 설정을 제공할 수 있습니다.';
	@override String get referenceActivities => '레퍼런스 활동';
	@override String get otherActivities => '기타 활동';
	@override String get adifFields => 'ADIF 필드';
	@override String get loadFailed => '내보내기 설정을 불러올 수 없습니다.';
	@override String get retry => '다시 시도';
	@override String get compactFileNamesDescriptionOn => '짧은 파일명, 예: N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => '설명적인 파일명, 예: 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'ADIF 파일에 이름, 주소, 이메일, 메모 및 정확한 위치를 포함합니다.';
	@override String get includePrivateDataDescriptionOff => '이름, 주소, 이메일 및 메모를 제외하고, 위치를 6자리 그리드로 제한합니다.';
	@override String get includeLookupDataDescriptionOn => '콜사인 조회 서비스의 정보를 포함합니다.';
	@override String get includeLookupDataDescriptionOff => '콜사인 조회 서비스의 정보를 제외하고, 직접 입력한 값은 유지합니다.';
	@override String get customTemplatesDescriptionOn => '맞춤 템플릿이 활성화되어 있으며 아래에서 편집할 수 있습니다.';
	@override String get customTemplatesDescriptionOff => '기본 템플릿이 활성화되어 있습니다. 맞춤 템플릿은 나중을 위해 보관됩니다.';
	@override String get type => '내보내기 유형';
	@override String get defaults => '기본값';
	@override String get includeLookupData => '조회 데이터 포함';
	@override String get customTemplates => '맞춤 템플릿';
	@override String get filenameTemplate => '파일 이름 템플릿';
	@override String get compactFilenameTemplate => '짧은 파일 이름 템플릿';
	@override String get titleTemplate => '제목 템플릿';
	@override String get adifNotesTemplate => 'ADIF QSO 노트';
	@override String get adifCommentTemplate => 'ADIF QSO 코멘트';
	@override String get adifQslMessageTemplate => 'ADIF QSL 메시지';
	@override String get shared => '이 설정은 이 내보내기 유형을 사용하는 모든 확장 기능에 적용됩니다.';
	@override String get defaultTemplates => '이 유형의 템플릿을 편집하려면 맞춤 템플릿을 켜세요.';
}

// Path: templateEditor
class _Translations$templateEditor$ko extends Translations$templateEditor$en {
	_Translations$templateEditor$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => '미리보기:';
	@override String get reset => '초기화';
	@override String get docs => '템플릿 문서';
	@override String get preview => '샘플 미리보기';
	@override String get reference => '템플릿 참조';
	@override String get attributes => '사용 가능한 속성';
	@override String get filters => '필터';
	@override String get flowControl => '흐름 제어';
	@override String get unavailable => '확장 기능이 준비될 때까지 미리보기를 사용할 수 없습니다.';
	@override String get empty => '(출력 없음)';
}

// Path: home.nav
class _Translations$home$nav$ko extends Translations$home$nav$en {
	_Translations$home$nav$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get operations => '운용';
	@override String get chase => '추적';
	@override String get logs => '로그';
	@override String get maps => '지도';
	@override String get settings => '설정';
}

// Path: home.panels
class _Translations$home$panels$ko extends Translations$home$panels$en {
	_Translations$home$panels$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get operations => '운용 목록';
	@override String get operationsDescription => '최근 운용부터 표시합니다.';
	@override String get version => '현재 버전';
	@override String get versionDescription => 'Ham2K 로고, 앱 이름, 실행 중인 빌드.';
}

// Path: home.logs
class _Translations$home$logs$ko extends Translations$home$logs$en {
	_Translations$home$logs$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '로그';
	@override String get titleFor => '로그:';
	@override String get emptyCallsigns => '아직 로깅된 QSO 없음';
	@override String emptyQsos({required Object call}) => '${call}의 QSO 없음';
	@override String get mapNoSelection => 'QSO를 선택하면 지도에 표시됩니다';
	@override String get searchHint => '콜사인 또는 이름 검색';
	@override String get noSearchMatches => '검색과 일치하는 QSO가 없습니다';
	@override String get titleAll => '모든 로그';
	@override String get allCallsigns => '모든 콜사인';
	@override String get noOperation => '운용에 속하지 않음';
	@override String get unsavedTitle => '저장되지 않은 변경 사항';
	@override String get unsavedBody => '이 QSO에 저장하지 않은 변경 사항이 있습니다.';
	@override String get pendingDeleteBody => '이 QSO는 삭제 예정으로 표시되어 있습니다.';
	@override String get editGone => '저장되지 않음: 해당 QSO가 더 이상 이 로그에 없습니다.';
	@override String get discard => '버리기';
	@override late final _Translations$home$logs$sheet$ko sheet = _Translations$home$logs$sheet$ko._(_root);
	@override late final _Translations$home$logs$groupBy$ko groupBy = _Translations$home$logs$groupBy$ko._(_root);
	@override late final _Translations$home$logs$period$ko period = _Translations$home$logs$period$ko._(_root);
	@override late final _Translations$home$logs$periodTitle$ko periodTitle = _Translations$home$logs$periodTitle$ko._(_root);
	@override late final _Translations$home$logs$columns$ko columns = _Translations$home$logs$columns$ko._(_root);
	@override late final _Translations$home$logs$panels$ko panels = _Translations$home$logs$panels$ko._(_root);
	@override late final _Translations$home$logs$import$ko import = _Translations$home$logs$import$ko._(_root);
}

// Path: chase.station
class _Translations$chase$station$ko extends Translations$chase$station$en {
	_Translations$chase$station$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '추적 중인 무선국';
	@override String get stationLabel => '무선국: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => '위치 없음';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$ko extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get today => '오늘';
	@override String get thisWeek => '이번 주';
	@override String get last14Days => '최근 14일간';
	@override String get thisMonth => '이번 달';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$ko extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get today => '오늘 통계';
	@override String get thisWeek => '이번 주 통계';
	@override String get last14Days => '최근 14일 통계';
	@override String get thisMonth => '이번 달 통계';
}

// Path: chase.period
class _Translations$chase$period$ko extends Translations$chase$period$en {
	_Translations$chase$period$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get today => '오늘';
	@override String get thisWeek => '이번 주';
	@override String get last14Days => '최근 14일';
	@override String get thisMonth => '이번 달';
}

// Path: chase.goals
class _Translations$chase$goals$ko extends Translations$chase$goals$en {
	_Translations$chase$goals$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '추적 목표';
	@override String remove({required Object name}) => '${name} 추적 중지';
	@override String get extensionsTitle => '더 많은 추적 프로그램';
}

// Path: chase.panels
class _Translations$chase$panels$ko extends Translations$chase$panels$en {
	_Translations$chase$panels$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSO';
	@override String get loggingDescription => '기간 내 추적한 QSO 위에 로깅 컨트롤 표시.';
	@override String get info => '정보';
	@override String get infoDescription => '로깅 중인 콜사인 또는 기간 통계.';
	@override String get spots => '스팟';
	@override String get spotsDescription => '스팟에 올라온 무선국, 바로 추적할 수 있습니다.';
	@override String get map => '지도';
	@override String get mapDescription => '기간 내 QSO와 로깅 중인 무선국.';
}

// Path: chase.claims
class _Translations$chase$claims$ko extends Translations$chase$claims$en {
	_Translations$chase$claims$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get checking => '추적용 QSO 확인 중';
	@override String rebuilding({required Object program}) => '${program} 로그 확인 중';
	@override String progress({required Object total, required Object done}) => 'QSO ${total}개 중 ${done}개';
}

// Path: chase.notice
class _Translations$chase$notice$ko extends Translations$chase$notice$en {
	_Translations$chase$notice$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String newRef({required Object program}) => '새로운 ${program}';
	@override String newRefGuess({required Object program}) => '새로운 ${program} (추정)';
	@override String newBand({required Object program}) => '새로운 ${program} 밴드';
	@override String newBandGuess({required Object program}) => '새로운 ${program} 밴드 (추정)';
	@override String newMode({required Object program}) => '새로운 ${program} 모드';
	@override String newModeGuess({required Object program}) => '새로운 ${program} 모드 (추정)';
	@override String unconfirmed({required Object program}) => '${program} 미확인';
	@override String programGuess({required Object notice}) => '${notice} (추정)';
}

// Path: chase.alerts
class _Translations$chase$alerts$ko extends Translations$chase$alerts$en {
	_Translations$chase$alerts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '알림';
	@override String get newRef => '새로운 레퍼런스';
	@override String get newBand => '새로운 밴드';
	@override String get newMode => '새로운 모드';
	@override String get unconfirmed => '미확인';
}

// Path: chase.imports
class _Translations$chase$imports$ko extends Translations$chase$imports$en {
	_Translations$chase$imports$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String importFrom({required Object label}) => '${label} 가져오기';
	@override String pickTitle({required Object file}) => '${file}을(를) 다음으로 가져오기';
	@override String get dropHint => '파일을 끌어다 놓아 추적 프로그램으로 가져오세요';
	@override String done({required Object file, required Object program, required Object count}) => '${file}에서 ${program} 항목 ${count}개를 가져왔습니다';
	@override String doneSkipped({required Object file, required Object program, required Object count, required Object skipped}) => '${file}에서 ${program} 항목 ${count}개를 가져왔고, 읽을 수 없는 ${skipped}개는 건너뛰었습니다';
	@override String nothing({required Object file, required Object program}) => '${file}에는 ${program}이(가) 가져올 수 있는 항목이 없습니다';
	@override String failed({required Object program, required Object file}) => '${program}이(가) ${file}을(를) 읽을 수 없습니다';
	@override String unreadable({required Object program, required Object file, required Object skipped}) => '${program}이(가) ${file}의 기록 ${skipped}개를 하나도 읽을 수 없습니다';
	@override String noProgram({required Object file}) => '${file}을(를) 가져올 수 있는 추적 프로그램이 없습니다';
}

// Path: dialogs.lookupDespiteAssistance
class _Translations$dialogs$lookupDespiteAssistance$ko extends Translations$dialogs$lookupDespiteAssistance$en {
	_Translations$dialogs$lookupDespiteAssistance$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '온라인으로 조회할까요?';
	@override String get body => '이 운용에서는 어시스턴스가 비활성화되어 있습니다. 모든 QSO를 조회하면 이번 한 번만 QRZ 같은 온라인 서비스를 사용합니다.';
	@override String bodyRules({required Object rules}) => '이 운용에서는 ${rules} 규정 준수를 위해 어시스턴스가 비활성화되어 있습니다. 모든 QSO를 조회하면 이번 한 번만 QRZ 같은 온라인 서비스를 사용합니다.';
	@override String get action => '온라인 조회';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$ko extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => '잘못된 콜사인: ${call}';
	@override String invalidCallsigns({required Object calls}) => '잘못된 콜사인: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '지금까지 ${previous}이(가) 운용했습니다. 새 교신에는 ${typed}이(가) 기록됩니다.';
	@override String operatorNoneSoFar({required Object typed}) => '지금까지 기록된 오퍼레이터가 없습니다. 새 교신에는 ${typed}이(가) 기록됩니다.';
	@override String operatorSeveral({required Object calls, required Object typed}) => '이 운용에는 이미 ${calls}의 교신이 있습니다. ${typed}은(는) 새 교신에만 기록됩니다.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '이미 로깅된 교신의 오퍼레이터도 ${typed}(으)로 기록',
		other: '이미 로깅된 교신 ${count}개 모두의 오퍼레이터도 ${typed}(으)로 기록',
	);
	@override String get operatorSeveralStations => '여러 무선국 콜사인을 사용할 때는 별도의 오퍼레이터를 지원하지 않습니다';
	@override String get contactsUnreadable => '이 운용의 교신을 읽을 수 없어, 여기서 콜사인을 변경해도 교신을 업데이트하지 않습니다';
	@override String restampFailed({required Object error}) => '이미 로깅된 교신을 업데이트할 수 없어 변경하지 않았습니다: ${error}';
	@override String restampShortfall({required Object planned, required Object written}) => '교신 ${planned}개 중 ${written}개가 업데이트되었습니다. 나머지는 더 이상 이 운용에 없습니다';
}

// Path: operation.tabs
class _Translations$operation$tabs$ko extends Translations$operation$tabs$en {
	_Translations$operation$tabs$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSO';
	@override String get info => '정보';
	@override String get spots => '스팟';
	@override String get map => '지도';
	@override String get qsosPlain => 'QSO';
	@override String get clock => '시계';
	@override String get weather => '날씨';
	@override String get website => '웹사이트';
	@override String get remoteScreen => '원격 화면';
	@override String get solar => '태양 활동';
	@override String get radio => '무전기';
	@override String get rotator => '로테이터';
	@override String get summaries => '운용 요약';
}

// Path: operation.positions
class _Translations$operation$positions$ko extends Translations$operation$positions$en {
	_Translations$operation$positions$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => '아직 이 운용을 공유하는 다른 운용 포지션이 없습니다.';
	@override String positionLabel({required Object number}) => '포지션: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => '다른 포지션';
	@override String get thisDevice => '내 운용 포지션';
	@override String get nameIn => ' - ';
	@override String get panelTitle => '포지션';
	@override String get panelDescription => '이 운용을 공유하는 모든 운용 포지션에서 지금 로깅 중인 내용.';
}

// Path: operation.menu
class _Translations$operation$menu$ko extends Translations$operation$menu$en {
	_Translations$operation$menu$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'RST 필드 표시';
	@override String get showStateField => '주 필드 표시';
	@override String get showGridField => '그리드 필드 표시';
	@override String get showDeletedQsos => '삭제된 QSO 표시';
	@override String get showDeletedOps => '삭제된 운용 표시';
	@override String get showQsoNumbers => 'QSO 번호 표시';
	@override String get lookupAllQsos => '모든 QSO 조회';
	@override String get loggingSettingsTitle => '로깅 설정';
	@override String get mapSettingsTitle => '지도 설정';
	@override String get actionsSection => '작업';
}

// Path: operation.layout
class _Translations$operation$layout$ko extends Translations$operation$layout$en {
	_Translations$operation$layout$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '패널 추가';
	@override String get availableSection => '사용 가능한 패널';
	@override String panelSettings({required Object panel}) => '${panel} 설정';
	@override String get panelSettingsAction => '패널 설정';
	@override String get viewName => '운용 화면';
	@override String get viewOptions => '화면 레이아웃 옵션';
	@override String get viewTitleBuiltIn => '이 화면은 앱에 내장되어 있으며, 이름도 마찬가지입니다';
	@override String get resetOptions => '기본값 복원';
	@override String get removePane => '제거';
	@override String resetPaneConfirm({required Object panel}) => '${panel}을(를) 기본값으로 복원할까요?';
	@override String get resetPaneConfirmBody => '제목, 헤더 및 크기가 기본값으로 돌아갑니다. 나머지 레이아웃은 그대로 유지됩니다.';
	@override String get resetViewConfirm => '이 화면을 기본 레이아웃으로 복원할까요?';
	@override String get resetViewConfirmBody => '패널이 기본 배치로 돌아가고, 화면 옵션과 모든 패널의 옵션이 기본값으로 돌아갑니다.';
	@override String paneOptionsTitle({required Object panel}) => '${panel} 레이아웃 설정';
	@override String get paneTitle => '제목';
	@override String get paneShowHeader => '헤더 표시';
	@override String get paneShowHeaderTabset => '이 패널이 그룹을 공유하는 동안 항상 표시됩니다. 헤더를 통해 다른 패널로 이동합니다';
	@override String get paneInherit => '앱과 동일';
	@override String get searchHint => '패널 검색';
	@override String get noPanelsMatch => '검색과 일치하는 패널이 없습니다.';
	@override String get nothingToAdd => '이 화면에 이미 가능한 모든 패널이 있습니다';
	@override String addPanel({required Object panel}) => '${panel} 추가';
	@override String showPreview({required Object panel}) => '${panel} 미리보기';
	@override String missingExtension({required Object name}) => '확장 기능 "${name}"이(가) 없습니다';
	@override String get missingExtensionEnable => '활성화';
	@override String get missingExtensionInstall => '설치…';
	@override String get missingExtensionWontRun => '이 버전은 실행되지 않습니다. 설정 › 확장 기능에서 업데이트하세요.';
	@override String get missingExtensionUnavailable => '이 앱에서는 사용할 수 없음';
	@override String get missingExtensionNotInCatalog => '카탈로그에 없음';
	@override String get missingExtensionCatalogUnreachable => '카탈로그에 연결할 수 없습니다. 다시 시도하세요';
	@override String get missingExtensionFailed => '실패했습니다. 다시 시도하세요';
	@override String get previewUnavailable => '이 패널의 미리보기 이미지를 표시할 수 없습니다.';
	@override String get nestedPaneTitle => '더보기';
	@override late final _Translations$operation$layout$layouts$ko layouts = _Translations$operation$layout$layouts$ko._(_root);
	@override String get editLayout => '레이아웃 편집';
	@override String get saveLayout => '레이아웃 저장';
	@override String get revertLayout => '레이아웃 변경 사항 버리기';
	@override String get done => '완료';
	@override String get layoutUnreadableTitle => '레이아웃을 읽을 수 없습니다';
	@override String get layoutUnreadableBody => '저장된 레이아웃을 읽을 수 없어 기본 배치를 대신 표시합니다. 유지하기로 선택하기 전까지 원래 레이아웃을 덮어쓰지 않습니다.';
	@override String get layoutUnreadableAction => '이 레이아웃 사용';
	@override String panelRenderFailed({required Object panel}) => '${panel}을(를) 표시할 수 없습니다';
	@override String panelOverCharacters({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: ${max}자를 초과하는 내용을 보냈습니다';
	@override String panelOverElements({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 아트워크의 요소가 ${max}개를 초과합니다';
	@override String panelOverDepth({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 아트워크의 중첩 깊이가 ${max}단계를 초과합니다';
	@override String panelNotArtwork({required Object panel}) => '${panel}을(를) 표시할 수 없습니다: 아트워크가 자체 완결형이 아닙니다';
	@override String panelOverLayers({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 레이어가 ${max}개를 초과합니다';
	@override String panelOverControls({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 컨트롤이 ${max}개를 초과합니다';
	@override String panelOverItems({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 일부에 항목이 ${max}개를 초과합니다';
	@override String panelOverStringLength({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬 문자열이 ${max}자를 초과합니다';
	@override String panelOverLayoutDepth({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 레이아웃의 중첩 깊이가 ${max}단계를 초과합니다';
	@override String get panelRenderRetry => '다시 시도';
	@override String get panelActionFailed => '패널 작업에 실패했습니다. 다시 시도하세요.';
	@override late final _Translations$operation$layout$panels$ko panels = _Translations$operation$layout$panels$ko._(_root);
	@override String get htmlPanelUnsupported => '이 패널에는 웹 뷰가 필요하지만 이 플랫폼에서는 제공되지 않습니다';
	@override String get htmlPanelUnsupportedOnWeb => '이 패널에는 웹 버전에서 제공할 수 없는 샌드박스가 필요합니다';
}

// Path: operation.export
class _Translations$operation$export$ko extends Translations$operation$export$en {
	_Translations$operation$export$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '운용 내보내기';
	@override String get syncedOperation => '운용이 동기화됨';
	@override String get unsyncedOperation => '운용에 동기화되지 않은 변경 사항이 있음';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '이 운용에서 ${count} QSO',
		other: '이 운용에서 ${count} QSO',
	);
	@override String qsosSynced({required Object total}) => 'QSO ${total}개 모두 동기화됨';
	@override String qsosPending({required Object total, required Object pending}) => 'QSO ${total}개 중 ${pending}개 동기화 대기 중';
	@override String eventsSynced({required Object total}) => '이벤트 마커 ${total}개 동기화됨';
	@override String eventsPending({required Object total, required Object pending}) => '이벤트 마커 ${total}개 중 ${pending}개 대기 중';
	@override String get loading => '내보내기 옵션 로딩 중…';
	@override String get noOptions => '사용 가능한 내보내기 형식이 없습니다 (확장 기능 런타임이 아직 시작 중인가요?)';
	@override String get nothingLogged => '아직 내보낼 것이 없습니다. 이 운용에 QSO가 없습니다.';
	@override String get share => '공유';
	@override String get nothingSelected => '선택된 항목 없음';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개 저장',
		other: '파일 ${count}개 저장',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개 공유',
		other: '파일 ${count}개 공유',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개 내보내기',
		other: '파일 ${count}개 내보내기',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개 다운로드',
		other: '파일 ${count}개 다운로드',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '통합 파일 ${count}개 저장',
		other: '통합 파일 ${count}개 저장',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '통합 파일 ${count}개 공유',
		other: '통합 파일 ${count}개 공유',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '통합 파일 ${count}개 내보내기',
		other: '통합 파일 ${count}개 내보내기',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '통합 파일 ${count}개 다운로드',
		other: '통합 파일 ${count}개 다운로드',
	);
	@override String saveOne({required Object name}) => '${name} 저장';
	@override String shareOne({required Object name}) => '${name} 공유';
	@override String exportOne({required Object name}) => '${name} 내보내기';
	@override String downloadOne({required Object name}) => '${name} 다운로드';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개 보관',
		other: '파일 ${count}개 보관',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '통합 파일 ${count}개 보관',
		other: '통합 파일 ${count}개 보관',
	);
	@override String get settingsButton => '내보내기 설정';
	@override String get settingsTitle => '내보내기 설정';
	@override late final _Translations$operation$export$compactFileNames$ko compactFileNames = _Translations$operation$export$compactFileNames$ko._(_root);
	@override late final _Translations$operation$export$includePrivateData$ko includePrivateData = _Translations$operation$export$includePrivateData$ko._(_root);
	@override String get resultTitle => '내보내기 완료';
	@override String get resultFailedTitle => '내보내기 실패';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개를 ${path}에 내보냈습니다',
		other: '파일 ${count}개를 ${path}에 내보냈습니다',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개를 내보냈습니다: ${path}',
		other: '파일 ${count}개를 내보냈습니다: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개를 공유했습니다',
		other: '파일 ${count}개를 공유했습니다',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '파일 ${count}개를 다운로드했습니다',
		other: '파일 ${count}개를 다운로드했습니다',
	);
	@override String exportFailed({required Object error}) => '내보내기 실패: ${error}';
	@override late final _Translations$operation$export$stash$ko stash = _Translations$operation$export$stash$ko._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$ko extends Translations$operation$spots$en {
	_Translations$operation$spots$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get empty => '필터와 일치하는 스팟이 없습니다';
	@override String error({required Object error}) => '스팟을 불러오지 못했습니다: ${error}';
	@override String get unknownBand => '기타';
	@override String get auto => '자동';
	@override String autoValue({required Object value}) => '자동 (현재 ${value})';
	@override String valueAuto({required Object value}) => '${value} (자동)';
	@override String get any => '전체';
	@override String get allBands => '모든 밴드';
	@override String get allModes => '모든 모드';
	@override String get phoneAndCw => '보이스 및 CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개의 스팟',
		other: '${count}개의 스팟',
	);
	@override String spotsCountFiltered({required Object total, required Object count}) => '스팟 ${total}개 중 ${count}개 표시 중';
	@override String get spotsDisabled => '이 운용에서는 스팟이 비활성화되어 있습니다';
	@override String ageMinutes({required Object minutes}) => '${minutes}분';
	@override String get callsOfNote => '주목할 콜사인';
	@override String get yourSpots => '내 스팟';
	@override String get allSpots => '모든 스팟';
	@override late final _Translations$operation$spots$continents$ko continents = _Translations$operation$spots$continents$ko._(_root);
	@override late final _Translations$operation$spots$filters$ko filters = _Translations$operation$spots$filters$ko._(_root);
	@override String get unavailableTitle => '스팟을 사용할 수 없음';
	@override String unavailableText({required Object sources}) => '${sources}이(가) 응답하지 않았습니다.';
	@override String get failedTitle => '스팟 출처 오류';
	@override String failedText({required Object sources}) => '${sources}이(가) 오류를 반환했습니다.';
	@override String get slideLogIt => '로깅';
	@override String get slideIgnore => '무시';
	@override String get slideRestore => '복원';
	@override late final _Translations$operation$spots$logConflict$ko logConflict = _Translations$operation$spots$logConflict$ko._(_root);
}

// Path: operation.import
class _Translations$operation$import$ko extends Translations$operation$import$en {
	_Translations$operation$import$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '운용에 데이터 가져오기';
	@override String get importAdifAction => 'ADIF에서 QSO 가져오기';
	@override String get settingsButton => '수신 설정';
	@override String get settingsTitle => '다른 앱 수신 대기';
	@override String get protocolAddressLabel => '주소';
	@override String get protocolPortLabel => '포트';
	@override String get protocolPortInvalid => '1에서 65535 사이의 포트를 입력하세요';
	@override String get protocolAddressInvalid => '올바른 IP 주소를 입력하세요 (예: 127.0.0.1 또는 239.239.0.2)';
	@override String get protocolStatusReceiving => '데이터 수신 중';
	@override String get protocolStatusNoData => '최근 수신된 데이터 없음';
	@override String protocolBindError({required Object error}) => '수신 대기를 시작할 수 없습니다: ${error}';
	@override String captureFailed({required Object error}) => '들어온 QSO를 저장할 수 없어 다시 시도 중입니다: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => '전체 (브로드캐스트)';
	@override String get wsjtxProtocolName => 'WSJT-X UDP Server';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → Broadcast Data 탭 → 교신 정보에 대해 "Enable Broadcasts"를 체크하세요. 같은 컴퓨터에서 실행 중이면 IP 주소를 127.0.0.1로, 현재 로컬 네트워크에 브로드캐스트하려면 255.255.255.255로 설정하세요.';
	@override String get helpWsjtxSetup => 'File → Settings → Reporting 탭 → UDP Server 섹션 → "Accept UDP requests"를 체크하세요. 같은 컴퓨터에서 실행 중이면 UDP Server를 127.0.0.1로, 아니면 239.239.0.2 같은 멀티캐스트 주소로 설정하고, 이 앱의 위 설정에도 같은 주소를 사용하세요.';
	@override String get listenTitle => '다른 앱의 QSO 수신 대기';
	@override String get listenDescriptionOnN1mm => 'N1MM+ 수신 대기 중';
	@override String get listenDescriptionOnWsjtx => 'WSJT-X 수신 대기 중';
	@override String get listenDescriptionOnBoth => 'N1MM+ 및 WSJT-X 수신 대기 중';
	@override String get listenDescriptionOff => '꺼짐';
	@override String get addToOperationTitle => '이 운용에 추가';
	@override String get addToOperationDescriptionOn => '수신한 QSO가 도착하는 대로 이 운용에 추가됩니다';
	@override String get addToOperationDescriptionOff => '이 옵션을 켤 때까지 수신한 QSO를 보관합니다';
	@override String get pendingSectionTitle => '수신한 QSO';
	@override String get pendingEmpty => '아직 수신한 항목 없음';
	@override String stationMismatch({required Object call}) => '이 운용의 무선국이 아닌 ${call}(으)로 로깅됨';
	@override String get discardAction => '버리기';
	@override String get gapDialogTitle => '이전에 수신한 항목도 포함할까요?';
	@override String gapDialogBody({required Object count}) => '데이터 공백 이전에 수신한 QSO가 ${count}개 더 있습니다. 함께 포함할까요?';
	@override String get gapDialogRecentOnly => '최근 항목만';
	@override String gapDialogIncludeAll({required Object count}) => '${count}개 모두 포함';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$ko extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get link => '문제가 있나요?';
	@override String get title => '경계선 문제 신고';
	@override String get reference => '해당 경계선';
	@override String get severity => '얼마나 심각한가요?';
	@override String get minor => '사소함';
	@override String get major => '심각함';
	@override String get explanation => '무엇이 잘못되었나요?';
	@override String get explanationHint => '경계선의 어느 부분이 어떻게 잘못되었는지';
	@override String get send => '보내기';
	@override String get sending => '신고를 보내는 중입니다. 감사합니다';
	@override String get copy => '신고 내용 복사';
	@override String get notSent => '신고를 보낼 수 없습니다';
	@override String get copied => '신고 내용이 복사되었습니다';
	@override String get notCopied => '신고 내용을 복사할 수 없습니다';
}

// Path: map.postcard
class _Translations$map$postcard$ko extends Translations$map$postcard$en {
	_Translations$map$postcard$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get button => '운용 엽서';
	@override String title({required Object title}) => '${title} 엽서';
	@override String get portrait => '세로';
	@override String get landscape => '가로';
	@override String get square => '정사각형';
	@override String get save => '저장…';
	@override String get download => '다운로드';
	@override String get share => '공유';
	@override String get copy => '복사';
	@override String get copied => '클립보드에 복사되었습니다';
	@override String saved({required Object path}) => '${path}에 저장되었습니다';
	@override String downloaded({required Object name}) => '${name} 다운로드됨';
	@override String savedMany({required Object count, required Object path}) => '이미지 ${count}개를 ${path}에 저장했습니다';
	@override String savedFiles({required Object names}) => '${names} 저장됨';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names}은(는) 이미 저장되었습니다';
	@override String downloadedMany({required Object count}) => '이미지 ${count}개 다운로드 중 — 브라우저가 물으면 허용하세요';
	@override String get mapLeftOut => '지도가 로드되지 않아 제외되었습니다';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — 지도가 로드되지 않아 제외되었습니다';
	@override String continued({required Object title}) => '${title} (계속)';
	@override String get previousPage => '이전 페이지';
	@override String get nextPage => '다음 페이지';
	@override String pageOf({required Object page, required Object count}) => '${page} / ${count} 페이지';
	@override String bandQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count} Q',
		other: '${count} Q',
	);
	@override String get options => '엽서 옵션';
	@override String get bandLegend => '밴드 범례 표시';
	@override String get grayline => '그레이라인 표시';
	@override String get sectionsAndOrder => '요약 섹션 및 순서';
	@override String get sectionDays => '일별';
	@override String get reset => '초기화';
	@override String failed({required Object error}) => '엽서를 만들 수 없습니다: ${error}';
	@override String get mapNotReady => '지도 로딩이 끝나지 않았습니다. 연결을 확인하고 다시 시도하세요.';
	@override String saveFailed({required Object error}) => '엽서를 저장할 수 없습니다: ${error}';
	@override String get copyFailed => '클립보드에 이미지를 복사하지 못했습니다. 다시 시도하세요.';
	@override String get shareFailed => '엽서를 공유할 수 없습니다. 다시 시도하세요.';
	@override String get fileName => '엽서';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$ko extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get noQsos => '아직 QSO가 없습니다... 운용을 시작하세요!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSO';
	@override String qsosInTime({required Object time, required Object count}) => '${time} 동안 ${count}';
	@override String sinceLast({required Object time}) => '최근 QSO로부터 ${time}';
	@override String ratePer10({required Object rate}) => '최근 10개: ${rate} Q/h';
	@override String ratePer100({required Object rate}) => '최근 100개: ${rate} Q/h';
	@override String distanceTo({required Object distance}) => '${distance} →';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) →';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) →';
	@override String distanceAway({required Object distance}) => '${distance} 거리';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) 거리';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) 거리';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => '중복!';
	@override String get noticeNewBand => '새로운 밴드';
	@override String get noticeNewMode => '새로운 모드';
	@override String get noticeNewDXCC => '새로운 DXCC';
	@override String get noticeNewState => '새로운 주';
	@override String get noticeNewProvince => '새로운 주/도';
	@override String get noticeNewDay => '새로운 날짜';
	@override String get noticeNewRef => '새로운 레퍼런스';
	@override String get noticeNewMult => '새로운 Mult';
	@override String get noticeNewZone => '새로운 존';
	@override String get noticeInvalidMode => '잘못된 모드';
	@override String get noticeInvalidBand => '잘못된 밴드';
	@override String get noticeInvalidCategory => '교신 불가';
	@override String get noticeOverTime => '시간 종료';
	@override String get noticeWorkedBefore => '이전에 교신함';
	@override String get noticeNewPark => '새로운 공원';
	@override String get noticeNewSection => '새로운 섹션';
	@override String get noticeBonusStation => '보너스 무선국!';
	@override String get noticeMissingExchange => '교환 없음';
	@override String get noticeInvalidExchange => '잘못된 교환';
	@override String get noticeUnknownEvent => '알 수 없는 이벤트';
	@override String get noticeIncompleteCall => '불완전한 콜사인 — 점수 미반영';
	@override String get noticeOurGrid => '내 그리드 설정';
	@override String get noticeRareCounty => '희귀 카운티!';
	@override String get noticeOurLocation => '내 카운티 설정';
	@override String get noticeShortGrid => '그리드가 너무 짧음';
}

// Path: qsoList.find
class _Translations$qsoList$find$ko extends Translations$qsoList$find$en {
	_Translations$qsoList$find$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String menuItem({required Object shortcut}) => '로그에서 찾기 (${shortcut})';
	@override String get menuItemNoShortcut => '로그에서 찾기';
	@override String get hint => 'QSO 번호 또는 콜사인';
	@override String get noMatches => '일치 항목 없음';
	@override String get noOperationQsos => '이 운용에 QSO 없음';
	@override String get noPeriodQsos => '이 기간에 QSO 없음';
	@override String get outsideQsosOne => '이 운용 밖의 QSO 1개';
	@override String outsideQsosOther({required Object count}) => '이 운용 밖의 QSO ${count}개';
	@override String get pastQsosOne => '이전 QSO 1개';
	@override String pastQsosOther({required Object count}) => '이전 QSO ${count}개';
}

// Path: callInfo.history
class _Translations$callInfo$history$ko extends Translations$callInfo$history$en {
	_Translations$callInfo$history$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '지난 7일간 ${n}개';
	@override String today({required Object n}) => '오늘 ${n}개';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
}

// Path: settings.theme
class _Translations$settings$theme$ko extends Translations$settings$theme$en {
	_Translations$settings$theme$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '테마 모드';
	@override String get system => '시스템 설정 따르기';
	@override String get light => '라이트';
	@override String get dark => '다크';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$ko extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get system => '시스템 설정을 따름';
	@override String get light => '항상 라이트 모드';
	@override String get dark => '항상 다크 모드';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$ko extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => '아주 작게--';
	@override String get smallestMinus => '아주 작게-';
	@override String get smallest => '아주 작게';
	@override String get smaller => '작게';
	@override String get normal => '표준';
	@override String get larger => '크게';
	@override String get largest => '아주 크게';
	@override String get largestPlus => '아주 크게+';
	@override String get largestPlusPlus => '아주 크게++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$ko extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '기기 화면 켜짐 유지하기';
	@override String get descriptionOn => '로깅 화면에 있거나 동기화 중일 때 화면 켜짐 유지';
	@override String get descriptionOff => '평소처럼 화면 잠금 허용';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$ko extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get auto => '자동';
	@override String get densest => '가장 조밀하게';
	@override String get dense => '조밀하게';
	@override String get normal => '표준';
	@override String get sparse => '여유 있게';
	@override String get sparsest => '가장 여유 있게';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$ko extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get kilometers => '킬로미터';
	@override String get miles => '마일';
}

// Path: settings.logging
class _Translations$settings$logging$ko extends Translations$settings$logging$en {
	_Translations$settings$logging$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '로깅';
	@override late final _Translations$settings$logging$leftieMode$ko leftieMode = _Translations$settings$logging$leftieMode$ko._(_root);
	@override late final _Translations$settings$logging$countryFlags$ko countryFlags = _Translations$settings$logging$countryFlags$ko._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$ko countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$ko._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$ko suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$ko._(_root);
	@override late final _Translations$settings$logging$showBearing$ko showBearing = _Translations$settings$logging$showBearing$ko._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$ko showReverseBearing = _Translations$settings$logging$showReverseBearing$ko._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$ko switchSentRcvd = _Translations$settings$logging$switchSentRcvd$ko._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$ko jumpAfterRST = _Translations$settings$logging$jumpAfterRST$ko._(_root);
	@override late final _Translations$settings$logging$defaultReport$ko defaultReport = _Translations$settings$logging$defaultReport$ko._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$ko defaultReportCW = _Translations$settings$logging$defaultReportCW$ko._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$ko defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$ko._(_root);
	@override late final _Translations$settings$logging$numbersRow$ko numbersRow = _Translations$settings$logging$numbersRow$ko._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$ko numbersRowExtra = _Translations$settings$logging$numbersRowExtra$ko._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$ko numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$ko._(_root);
	@override String get bands => '선호 밴드';
	@override String get modes => '선호 모드';
}

// Path: settings.catServer
class _Translations$settings$catServer$ko extends Translations$settings$catServer$en {
	_Translations$settings$catServer$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT 서버';
	@override String get description => '다른 앱(WSJT-X, 로거 등)이 Ham2K Logger를 통해 무전기를 제어할 수 있도록 허용합니다.';
	@override String get protocol => '프로토콜';
	@override late final _Translations$settings$catServer$protocolOpts$ko protocolOpts = _Translations$settings$catServer$protocolOpts$ko._(_root);
	@override String get port => '포트';
	@override String get openAccess => '외부 접근 허용';
	@override String get openAccessOn => '로컬 네트워크의 모든 컴퓨터가 연결할 수 있습니다.';
	@override String get openAccessOff => '이 컴퓨터의 앱만 연결할 수 있습니다.';
	@override String get allowTransmit => '앱의 송신 허용';
	@override String allowTransmitOn({required Object minutes}) => '앱이 무전기의 PTT를 한 번에 최대 ${minutes}분까지 누를 수 있습니다.';
	@override String allowTransmitOnNetwork({required Object minutes}) => '로컬 네트워크의 모든 컴퓨터에 있는 앱이 무전기의 PTT를 한 번에 최대 ${minutes}분까지 누를 수 있습니다.';
	@override String get allowTransmitOff => '앱이 무전기를 키잉할 수 없습니다. VOX나 앱 자체의 PTT 설정을 사용하세요.';
	@override String get allowTransmitUnsupported => '메인 VFO 무전기는 Ham2K Logger에서 키잉할 수 없으므로, 앱이 이를 통해 송신할 수 없습니다.';
	@override String get off => '꺼짐.';
	@override String starting({required Object protocol}) => '${protocol}, 시작 중…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol}, 포트 ${port}. 연결된 클라이언트: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol}, 포트 ${port}에서 대기 중이지만 메인 VFO 무전기가 연결되어 있지 않습니다.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: 다른 프로그램(주로 ${protocol} 자체)이 사용 중입니다. 해당 프로그램을 닫거나 다른 포트를 선택하세요.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: 이 컴퓨터가 허용하지 않습니다. 1024보다 큰 포트를 선택하세요.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기를 중지했습니다. 다시 시도 중…';
}

// Path: settings.cluster
class _Translations$settings$cluster$ko extends Translations$settings$cluster$en {
	_Translations$settings$cluster$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'DX 클러스터';
	@override String get description => '확장 기능이 오퍼레이터로 로그인하여 스팟을 올리고 읽어 오는 서버입니다.';
	@override String get connect => '클러스터에 연결';
	@override String get connectOn => '확장 기능이 필요할 때 클러스터에 연결합니다';
	@override String get connectOff => '클러스터에 연결하지 않습니다';
	@override String get console => '콘솔 표시';
	@override String get consoleDescription => '클러스터가 보내는 내용과 명령을 입력하는 곳';
	@override String get consoleTitle => '클러스터 콘솔';
	@override String get consoleConnect => '연결';
	@override String get consoleDisconnect => '연결 해제';
	@override String get consoleCommand => '명령';
	@override String get consoleEmpty => '아직 없습니다. 연결하거나, 확장 기능이 클러스터를 사용할 때까지 기다리세요.';
	@override String consoleRetry({required Object command}) => '다시 전송 중: ${command}';
	@override String consoleGaveUp({required Object command, required Object reason}) => '전송되지 않음: ${command} (${reason})';
	@override String get server => '클러스터 서버';
	@override String get selectServer => '서버 선택';
	@override String get serverOther => '기타';
	@override String serverOtherIncomplete({required Object node}) => '아직 호스트를 입력하지 않아 스팟이 ${node}(으)로 갑니다';
	@override String get customHost => '서버';
	@override String get customPort => '포트';
	@override String get password => '비밀번호';
	@override String get passwordDescription => '필요한 경우에만';
	@override String passwordStored({required Object node}) => '${node}의 비밀번호 저장됨';
	@override String get scrollback => '보관 줄 수';
	@override String scrollbackOpt({required Object count}) => '${count}줄';
	@override String get connection => '연결';
	@override String get statusIdle => '연결되지 않음. 확장 기능이 필요할 때 연결합니다. 탭하여 테스트하세요.';
	@override String statusConnecting({required Object node}) => '${node}에 연결 중…';
	@override String statusConnected({required Object node, required Object call}) => '${node}에 ${call}(으)로 연결됨.';
	@override String statusFailed({required Object node, required Object reason}) => '${node}에 연결할 수 없습니다: ${reason}';
	@override String get statusUnsupported => '웹 버전에서는 사용할 수 없습니다.';
	@override String get statusOff => '꺼짐. 사용하려면 클러스터에 연결을 켜세요.';
	@override late final _Translations$settings$cluster$errors$ko errors = _Translations$settings$cluster$errors$ko._(_root);
}

// Path: settings.spotting
class _Translations$settings$spotting$ko extends Translations$settings$spotting$en {
	_Translations$settings$spotting$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스팟';
	@override String get respotInterval => '자동 재스팟 간격';
	@override String minutes({required Object minutes}) => '${minutes}분';
	@override String get autoRespotByDefault => '기본으로 자동 재스팟';
	@override String get autoRespotByDefaultOn => '스팟을 올리면 자동 재스팟을 활성화합니다';
	@override String get autoRespotByDefaultOff => '자동 재스팟은 직접 켜야 합니다';
	@override String get pulseBeforeRespot => '자동 재스팟 전 깜빡임';
	@override String pulseBeforeRespotOn({required Object seconds}) => '재스팟 ${seconds}초 전부터 스팟 칩이 파란색으로 깜빡입니다';
	@override String get pulseBeforeRespotOff => '자동 재스팟 전에 깜빡이지 않습니다';
}

// Path: settings.radio
class _Translations$settings$radio$ko extends Translations$settings$radio$en {
	_Translations$settings$radio$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'CAT 제어';
	@override String get loggingAndCat => '로깅 및 CAT';
	@override String get tuningSection => '튜닝';
	@override String get keyerSection => '키어';
	@override String get servicesSection => '서비스';
	@override String get stationConfigurationSection => '무선국 구성';
	@override String get moreSettings => '추가 무선국 구성 설정';
	@override late final _Translations$settings$radio$units$ko units = _Translations$settings$radio$units$ko._(_root);
	@override late final _Translations$settings$radio$pttKey$ko pttKey = _Translations$settings$radio$pttKey$ko._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$ko smartVfoSnap = _Translations$settings$radio$smartVfoSnap$ko._(_root);
	@override late final _Translations$settings$radio$snapDebounce$ko snapDebounce = _Translations$settings$radio$snapDebounce$ko._(_root);
	@override late final _Translations$settings$radio$snapLongMove$ko snapLongMove = _Translations$settings$radio$snapLongMove$ko._(_root);
	@override late final _Translations$settings$radio$snapMinMove$ko snapMinMove = _Translations$settings$radio$snapMinMove$ko._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$ko snapMinSpeed = _Translations$settings$radio$snapMinSpeed$ko._(_root);
	@override late final _Translations$settings$radio$enterSends$ko enterSends = _Translations$settings$radio$enterSends$ko._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$ko keyerSpeed = _Translations$settings$radio$keyerSpeed$ko._(_root);
	@override late final _Translations$settings$radio$cwMessages$ko cwMessages = _Translations$settings$radio$cwMessages$ko._(_root);
	@override late final _Translations$settings$radio$keyerControl$ko keyerControl = _Translations$settings$radio$keyerControl$ko._(_root);
	@override late final _Translations$settings$radio$voiceMessages$ko voiceMessages = _Translations$settings$radio$voiceMessages$ko._(_root);
	@override late final _Translations$settings$radio$voiceWords$ko voiceWords = _Translations$settings$radio$voiceWords$ko._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$ko avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$ko._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$ko zeroBeatRange = _Translations$settings$radio$zeroBeatRange$ko._(_root);
}

// Path: settings.help
class _Translations$settings$help$ko extends Translations$settings$help$en {
	_Translations$settings$help$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '도움말 및 자료';
	@override String get description => '커뮤니티 및 지원';
	@override String get forums => 'Ham2K 포럼';
	@override String get forumsDescription => '도움받기, 피드백 제공, 아이디어 토론…';
	@override String get chat => 'Ham2K 채팅';
	@override String get chatDescription => '온라인 커뮤니티를 위한 Discord 서버';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => '비디오 & 라이브스트림';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => '사진은 많을수록 좋으니까요…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => '소식 및 업데이트를 위해 팔로우하세요';
	@override String get contact => '연락처';
	@override String get contactDescription => 'help@ham2k.com — 하지만 포럼이나 채팅을 먼저 시도해 보세요!';
}

// Path: settings.exports
class _Translations$settings$exports$ko extends Translations$settings$exports$en {
	_Translations$settings$exports$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '내보내기';
}

// Path: settings.extensionSections
class _Translations$settings$extensionSections$ko extends Translations$settings$extensionSections$en {
	_Translations$settings$extensionSections$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get activities => '활동';
	@override String get hunting => '추적';
	@override String get contests => '컨테스트';
	@override String get lookups => '조회';
	@override String get dashboard => '대시보드';
}

// Path: settings.map
class _Translations$settings$map$ko extends Translations$settings$map$en {
	_Translations$settings$map$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '지도';
	@override late final _Translations$settings$map$style$ko style = _Translations$settings$map$style$ko._(_root);
	@override late final _Translations$settings$map$showCallsigns$ko showCallsigns = _Translations$settings$map$showCallsigns$ko._(_root);
	@override late final _Translations$settings$map$showGrayline$ko showGrayline = _Translations$settings$map$showGrayline$ko._(_root);
	@override late final _Translations$settings$map$styleOpts$ko styleOpts = _Translations$settings$map$styleOpts$ko._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$ko extends Translations$settings$privacy$en {
	_Translations$settings$privacy$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '개인정보';
	@override late final _Translations$settings$privacy$shareAppData$ko shareAppData = _Translations$settings$privacy$shareAppData$ko._(_root);
	@override late final _Translations$settings$privacy$shareOpData$ko shareOpData = _Translations$settings$privacy$shareOpData$ko._(_root);
	@override String get privacyPolicy => '개인정보처리방침';
	@override String get termsOfService => '서비스 약관';
}

// Path: settings.sync
class _Translations$settings$sync$ko extends Translations$settings$sync$en {
	_Translations$settings$sync$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '클라우드 동기화';
	@override String get moreSettings => '추가 동기화 설정';
	@override String get enable => '동기화 활성화';
	@override String get deviceKey => '기기 키';
}

// Path: settings.peers
class _Translations$settings$peers$ko extends Translations$settings$peers$en {
	_Translations$settings$peers$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '피어 기기';
	@override String get enable => '다른 기기와 연결';
	@override String get enableDescription => '로컬 네트워크를 통해 다른 기기와 운용, 로깅, CAT 및 GPS 공유 허용';
	@override String get bleEnable => '블루투스로 연결';
	@override String get bleDescription => '로컬 네트워크가 없어도 블루투스 LE로 연결';
	@override String get thisDevice => '이 기기';
	@override String get deviceName => '이름';
	@override String get deviceNameHint => '다른 기기에 표시되는 이 기기의 이름';
	@override String get pairedDevices => '연결된 기기';
	@override String get noPairedDevices => '아직 연결된 기기가 없습니다. 같은 네트워크의 다른 기기에서도 이 옵션을 켜면 연결됩니다.';
	@override String deviceListProblem({required Object error}) => '연결된 기기를 읽을 수 없습니다: ${error}';
	@override String get nearby => '근처';
	@override String get connected => '연결됨';
	@override String get viaBluetooth => '블루투스 경유';
	@override String get connecting => '연결 중…';
	@override String get syncing => '동기화 중…';
	@override String get waitingForThem => '상대 기기 대기 중';
	@override String get notConnected => '연결 안 됨';
	@override String get wantsToPair => '이 운용을 공유하려고 합니다';
	@override String get allow => '허용';
	@override String get link => '연결';
	@override String get reject => '거부';
	@override String get forget => '지우기';
	@override String forgetTitle({required Object name}) => '${name}을(를) 지울까요?';
	@override String get forgetBody => '이 기기와의 동기화를 중지합니다. 나중에 다시 허용할 수 있으며, 이미 로깅된 교신은 유지됩니다.';
	@override String pairTitle({required Object name}) => '${name}과(와) 연결';
	@override String get pairBody => '이 기기는 로컬 네트워크에 있으며 연결하려고 합니다.';
	@override String get pairBodyBle => '이 기기는 근처에 있으며 블루투스 LE로 연결하려고 합니다.';
	@override String get pairIdLabel => '기기 ID';
	@override String get pairWarning => '알고 있는 기기와만 연결하세요. 이 네트워크의 모든 기기가 요청을 보낼 수 있습니다.';
	@override String get pairWarningBle => '알고 있는 기기와만 연결하세요. 근처의 모든 기기가 요청을 보낼 수 있습니다.';
	@override String problem({required Object error}) => '로컬 네트워크에 연결할 수 없습니다: ${error}';
	@override String bleProblem({required Object error}) => '블루투스: ${error}';
	@override String statusConnected({required Object device}) => '${device}에 연결됨';
	@override String statusLost({required Object device}) => '${device}과(와) 연결 끊김';
	@override String statusPerma({required Object linked, required Object connected}) => '피어 기기: ${linked}개 중 ${connected}개 연결됨';
	@override String get screenEnable => '화면 및 창 공유';
	@override String get screenDescription => '다른 기기가 이 컴퓨터의 화면이나 창을 표시하도록 허용';
	@override String get screenSources => '화면 및 창';
	@override String get screenRefresh => '목록 새로고침';
	@override String get screenUnsupportedPlatform => '이 기기는 화면을 공유할 수 없습니다. macOS는 가능하며, 모든 기기는 다른 기기가 공유한 화면을 표시할 수 있습니다.';
	@override String get screenUnsupportedVersion => '화면 공유에는 macOS 12.3 이상이 필요합니다. 이 기기에서도 다른 기기가 공유한 화면은 표시할 수 있습니다.';
	@override String get screenNeedsPermission => '이 앱이 화면을 공유하려면 macOS의 화면 기록 권한이 필요합니다.';
	@override String get screenGrantPermission => '권한 요청';
	@override String get screenRelaunchAfterGranting => '시스템 설정의 개인정보 보호 및 보안 → 화면 기록에서 허용한 후, 이 앱을 종료하고 다시 여세요. macOS는 앱을 다시 실행해야 변경 사항을 알려줍니다.';
	@override String screenProblem({required Object error}) => '화면 공유: ${error}';
	@override String get screenChooseTitle => '공유할 항목 선택';
	@override String get screenChooseButton => '공유할 항목 선택…';
	@override String get screenTabScreens => '화면';
	@override String get screenTabApps => '앱';
	@override String get screenTabWindows => '창';
	@override String get screenTabEmpty => '이 종류의 항목이 없습니다.';
	@override String get screenSharedSummaryNone => '아직 선택된 항목이 없습니다.';
	@override String get screenThisDevice => '이 기기';
	@override String screenSharedTo({required Object devices}) => '${devices}에 표시 중';
	@override String get screenSharedToNobody => '표시되지 않음';
	@override String screenStopSharing({required Object name}) => '${name} 공유 중지';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$ko extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get configuration => '동기화 구성';
	@override String get enableTitle => 'Ham2K Log Filer와 동기화';
	@override String get enabledDescription => '로그를 백업하고 여러 기기 간에 동기화';
	@override String get disabledDescription => '꺼짐 — 이 기기에만 보관';
	@override String get syncing => '동기화';
	@override String get account => '계정';
	@override String get refresh => '새로고침';
	@override String get switchAccounts => '계정 전환';
	@override String get switchAccountsDescription => 'QR 코드나 이메일로 이 기기를 다른 계정에 연결';
	@override String get connectionRequests => '연결 요청';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '기기가 이 계정에 연결 대기 중',
		other: '기기 ${n}개가 이 계정에 연결 대기 중',
	);
	@override String get accountEmailTitle => '계정 이메일';
	@override String accountEmailSent({required Object email}) => '${email}(으)로 확인 메일을 보냈습니다. 메일의 링크를 열어 변경을 완료하세요.';
	@override String get resendConfirmation => '확인 이메일 다시 보내기';
	@override String resendConfirmationDescription({required Object email}) => '${email} 확인 대기 중';
	@override String accountEmailResent({required Object email}) => '${email}(으)로 다시 보냈습니다.';
	@override String get deviceLinked => '해당 기기가 이제 이 계정에 연결되었습니다.';
	@override String get checking => '확인 중…';
	@override String get notLinked => '아직 연결되지 않음';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => '로컬 데이터를 대체할까요?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '운용 ${n}개',
		other: '운용 ${n}개',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${n} QSO',
		other: '${n} QSO',
	);
	@override String get counts => '동기화된 데이터';
	@override String countsLocal({required Object qsos, required Object operations}) => '이 기기: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => '업로드 대기 중: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => '서버: ${qsos} · ${operations}';
	@override String get countsLocalChecking => '이 기기: 확인 중…';
	@override String get countsServerChecking => '서버: 확인 중…';
	@override String get countsServerUnavailable => '서버: 사용할 수 없음';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => '이 기기의 ${operations}과(와) ${qsos}을(를) 백업하고 지운 후, 대신 계정의 데이터를 다운로드합니다. 백업은 이 기기의 데이터베이스에 남습니다.';
	@override String get replace => '대체';
	@override String get pendingBannerTitle => '새로운 Ham2K Log Filer 계정 감지됨';
	@override String get pendingBannerBody => '이 기기의 기존 운용과 QSO를 유지하여 계정에 병합하거나, 계정의 데이터로 대체하세요 (어느 쪽이든 이 기기에 백업이 남습니다).';
	@override String get combine => '결합';
	@override String get authIssueTitle => '동기화 연결 불가';
	@override String get authIssueText => 'Ham2K Log Filer가 이 기기를 계속 거부합니다. 동기화 설정에서 콜사인을 확인하세요.';
	@override String get openSettings => '동기화 설정 열기';
}

// Path: settings.accounts
class _Translations$settings$accounts$ko extends Translations$settings$accounts$en {
	_Translations$settings$accounts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '계정, 서비스 및 데이터 출처';
	@override String get none => '계정이 있는 활성 확장 기능 없음';
	@override String get notConfigured => '구성되지 않음';
	@override String get connected => '연결됨';
	@override String get cancelLogin => '로그인 취소';
	@override String get openInBrowser => '브라우저에서 열기';
	@override String loggedInAs({required Object identity}) => '${identity}(으)로 로그인됨';
	@override String get pressSaveToKeep => '이 계정의 연결을 유지하려면 저장을 누르세요.';
	@override String connectedTo({required Object label}) => '${label}에 연결됨';
	@override String get connect => '연결';
	@override String get disconnect => '연결 해제';
	@override String get connectedAs => '연결된 계정';
	@override String get test => '테스트';
	@override String saveFailed({required Object error}) => '저장 실패: ${error}';
	@override String loginFailed({required Object error}) => '로그인 실패: ${error}';
	@override String get lookupFailed => '지금은 계정을 사용할 수 없습니다. 잠시 후 다시 시도하세요';
	@override String get browserLoginTitle => '웹 브라우저에서 로그인을 완료하세요';
	@override String browserLoginSteps({required Object prefix}) => '완료하면 브라우저가 "${prefix}"(으)로 시작하는 링크를 열려고 합니다. 데스크톱에 이 링크를 열 프로그램이 등록되어 있지 않을 가능성이 높으므로, 주소 표시줄이나 브라우저의 오류 페이지에서 링크를 복사해 여기에 붙여넣으세요.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger가 브라우저를 열 수 없습니다. 아래 로그인 링크를 복사해 직접 연 다음, 이동되는 링크("${prefix}"(으)로 시작)를 복사해 여기에 붙여넣으세요.';
	@override String get copyLoginLink => '로그인 링크 복사';
	@override String get pastedLinkLabel => '여기에 링크를 붙여넣으세요';
	@override String get finishLogin => '로그인 완료';
	@override String pastedLinkNotARedirect({required Object prefix}) => '로그인 링크가 아닙니다. "${prefix}"(으)로 시작해야 합니다.';
	@override String get pastedLinkWrongLogin => '다른 로그인 시도의 링크입니다. 이 페이지를 닫고 다시 연결하세요.';
	@override String get pastedLinkNoCode => '링크에 로그인 코드가 없습니다. 먼저 로그인을 완료한 후 이동되는 링크를 복사하세요.';
	@override String get pastedLinkMalformed => '링크가 잘린 것 같습니다. 전체를 복사해 다시 붙여넣으세요.';
	@override String get relayLoginWaiting => '로그인 완료를 기다리는 중입니다. 완료하면 자동으로 계속됩니다.';
	@override String get loginNoResponse => '이 기기가 아직 로그인 응답을 받지 못했습니다. 브라우저에서 이미 완료했다면 취소하고 다시 연결해 보세요.';
	@override String get relayLoginNotOpened => 'Ham2K Logger가 브라우저를 자동으로 열 수 없습니다. 아래 버튼으로 로그인 페이지를 직접 여세요.';
	@override String get relayLoginUnavailable => '로그인을 완료하는 데 필요한 동기화 서버에 연결할 수 없습니다. 연결을 확인하고 다시 시도하세요.';
	@override String get loginIncompleteResponse => '로그인 시도가 올바르게 완료되지 않았습니다. 다시 연결해 보세요.';
	@override String get noKeyringTitle => '계정 로그인 정보를 저장할 수 없습니다';
	@override String get noKeyringText => 'Ham2K Logger가 이 컴퓨터의 키링 서비스에 연결할 수 없어 계정 로그인 정보를 저장하거나 읽을 수 없습니다. 이 문제가 해결될 때까지 계정 연결이 실패합니다. **gnome-keyring**, **KWallet** 또는 **KeePassXC**를 설치하고 실행하거나, 기존 키링의 잠금을 해제한 후 다시 시작하세요. 로깅, 내보내기 및 데이터 파일은 영향을 받지 않으며, 그동안 로그 동기화는 꺼져 있습니다.';
	@override String get noKeyringInline => '로그인 정보를 저장할 수 없음: 이 컴퓨터의 키링에 연결할 수 없습니다. gnome-keyring, KWallet 또는 KeePassXC를 설치하고 실행하거나, 기존 키링의 잠금을 해제하세요.';
	@override String get noSecureStorageInline => '로그인 정보를 저장할 수 없음: 이 컴퓨터의 보안 저장소에 연결할 수 없습니다.';
}

// Path: settings.station
class _Translations$settings$station$ko extends Translations$settings$station$en {
	_Translations$settings$station$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '무선국 구성 및 CAT 제어';
	@override String get none => '구성된 장비 없음';
	@override String get add => '추가';
	@override String get addTitle => '장비 추가';
	@override String get searchHint => '장비 검색';
	@override String get noMatches => '일치하는 장비 없음';
	@override String get detectedEquipment => '감지된 장비';
	@override String discoveryUnavailable({required Object error}) => '무전기를 찾을 수 없습니다: ${error}';
	@override String get edit => '장비 편집';
	@override String get name => '이름';
	@override String get nameDescription => '부르는 이름 — "왼쪽 무전기". 선택 사항.';
	@override String get transport => '연결';
	@override String get host => '주소';
	@override String get hostDescription => '네트워크상 무전기의 호스트 이름 또는 IP 주소.';
	@override String get port => '포트';
	@override String get hostRequired => '주소가 필요합니다';
	@override String get portInvalid => '포트는 1에서 65535 사이여야 합니다';
	@override String get connect => '연결';
	@override String get disconnect => '연결 해제';
	@override String get remove => '제거';
	@override String removeTitle({required Object name}) => '${name}을(를) 제거할까요?';
	@override String get removeMessage => '앱에서만 제거됩니다. 장비의 설정은 그대로 유지됩니다.';
	@override String unknownType({required Object typeKey}) => '알 수 없는 장비 유형 "${typeKey}"';
	@override String get report => '제보';
	@override String get reportTitle => '이 무전기 제보';
	@override String get reportIntro => '이 무전기가 실제로 어떤 모델이고 어떻게 작동했는지 알려 주세요. 제보 내용은 Ham2K 팀이 읽는 카드가 되며, 작동시킨 방법에 대해 쓴 내용은 같은 장비를 쓰는 다음 오퍼레이터에게 도움이 될 수 있습니다.';
	@override String get reportManufacturer => '제조사';
	@override String get reportManufacturerDescription => '제조사 — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => '제조사가 필요합니다';
	@override String get reportModel => '모델';
	@override String get reportModelDescription => '무전기에 표시된 모델명 — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => '모델이 필요합니다';
	@override String get reportOutcome => '어떻게 작동했나요?';
	@override String get reportOutcomeWorks => '잘 작동함';
	@override String get reportOutcomeIssues => '작동했지만 문제 있음';
	@override String get reportOutcomeFails => '전혀 작동하지 않음';
	@override String get reportOutcomeRequired => '어떻게 작동했는지 알려 주세요';
	@override String get reportComments => '코멘트';
	@override String get reportCommentsPlaceholder => '작동한 것, 작동하지 않은 것, 예상 밖이었던 것.';
	@override String get reportHints => '문제 해결 팁';
	@override String get reportHintsPlaceholder => '다른 사용자를 위한 문제 해결 팁이 있나요?';
	@override String get reportSend => '제보 보내기';
	@override String get reportSending => '제보를 보내는 중…';
	@override String reportSent({required Object ref}) => '감사합니다. 제보가 ${ref}(으)로 접수되었습니다.';
	@override String get reportSentNoRef => '감사합니다. 제보를 보냈습니다.';
	@override String reportFailed({required Object error}) => '제보를 보내지 못했습니다: ${error}';
	@override String get troubleshootingNotes => '문제 해결 참고 사항';
	@override String get mainVfo => '메인 VFO';
	@override String get useAsMainVfo => '메인 VFO로 사용';
	@override String get serialPort => '시리얼 포트';
	@override String get serialPortDescription => '무전기의 CAT 인터페이스가 나타나는 포트.';
	@override String get serialPortNone => '시리얼 포트를 찾을 수 없음';
	@override String get serialPortRequired => '시리얼 포트를 선택하세요';
	@override String serialPortOrdinal({required Object n, required Object total}) => '포트 ${n} / ${total}';
	@override String get serialPortSuggested => '추천';
	@override String get serialPortJustNow => '최근 연결됨';
	@override String get serialPortNoDriver => '드라이버 없음';
	@override String get serialDeviceRequest => 'USB 장치 추가…';
	@override String get bleDevice => '블루투스 LE 장치';
	@override String get bleDeviceDescription => '무전기가 연결된 시리얼 브리지. 예: Mode 4의 LiNK500MP 또는 BLE 시리얼 어댑터.';
	@override String get bleScan => '블루투스 LE 장치 검색…';
	@override String get bleScanNoneFound => '블루투스 LE 장치를 찾을 수 없습니다. 브리지가 켜져 있고, 근처에 있으며, 블루투스 LE 모드(LiNK500MP는 Mode 4)인지 확인하세요.';
	@override String bleScanFailed({required Object reason}) => '블루투스 LE 검색을 실행할 수 없습니다: ${reason}';
	@override String get bleOff => '블루투스가 꺼져 있습니다.';
	@override String get bleDenied => '블루투스 권한이 허용되지 않았습니다. 시스템 설정에서 허용한 후 다시 시도하세요.';
	@override String get bleUnsupported => '이 기기에는 블루투스 LE가 없습니다.';
	@override String get bleStarting => '블루투스가 아직 시작 중입니다. 잠시 후 다시 시도하세요.';
	@override String get bleConnectFailed => '블루투스 LE 장치에 연결할 수 없습니다. 켜져 있고, 근처에 있으며, 다른 앱에 연결되어 있지 않은지 확인하세요.';
	@override String bleNoSerialService({required Object services}) => '이 블루투스 LE 장치에는 앱이 인식하는 시리얼 서비스가 없습니다. 다음 서비스 목록과 함께 제보해 주세요: ${services}';
	@override String get baudRate => '속도 (baud)';
	@override String get baudRateDescription => '무전기의 CAT 메뉴와 일치해야 합니다. 일치하지 않으면 무전기가 오류 없이 깨진 데이터를 보냅니다.';
	@override String get serialRtsHigh => 'RTS를 high로 유지';
	@override String get serialRtsHighDescription => 'CAT RTS가 켜진 Yaesu처럼 RTS를 기다린 후 응답하는 무전기에만 사용하세요. Digirig, SignaLink 및 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신합니다.';
	@override String get serialDtrHigh => 'DTR을 high로 유지';
	@override String get serialDtrHighDescription => 'FT-817용 일부 RS-232 케이블처럼 DTR에서 전원을 공급받는 CAT 인터페이스에만 사용하세요. 많은 케이블에서 DTR이 CW 키잉이나 PTT이므로, high로 유지하면 송신합니다.';
	@override String get serialUsbDriver => 'USB 칩 드라이버';
	@override String get serialUsbDriverDescription => '자동은 대부분의 어댑터를 인식합니다. 포트 목록에 드라이버 없음으로 표시되는 어댑터에만 칩을 선택하세요. 칩 이름은 포장이나 USB 장치 목록에서 확인할 수 있습니다.';
	@override String get serialUsbDriverAuto => '자동';
	@override String get civAddress => '무전기 CI-V 주소';
	@override String get civAddressDescription => '무전기의 CI-V 메뉴에 표시되는 16진수. IC-705의 출고값은 A4입니다.';
	@override String get civAddressInvalid => 'CI-V 주소는 01부터 FF까지의 16진수 두 자리입니다';
	@override String get flexSlice => '슬라이스';
	@override String get flexSliceDescription => '이 연결이 읽고 튜닝할 무전기의 슬라이스.';
	@override String flexSliceLabel({required Object letter}) => '슬라이스 ${letter}';
	@override String get flexSliceInvalid => '무전기의 슬라이스 A부터 H 중 하나를 선택하세요';
	@override String flexSliceMissing({required Object letter}) => '이 무전기에서 슬라이스 ${letter}을(를) 사용하고 있지 않습니다. 다른 슬라이스를 선택하거나 SmartSDR에서 만드세요';
	@override String get channelNotInUse => '사용 안 함';
	@override String get channelHeldByUnknown => '다른 프로그램이 사용 중';
	@override String get flexNoSlices => '이 무전기가 슬라이스를 보고하지 않았습니다. SmartSDR이 실행 중이고 이 클라이언트가 구독할 수 있는지 확인하세요';
	@override String get spectrumUnsupported => '이 무전기는 CAT으로 스펙트럼을 보내지 않습니다';
	@override String get spectrumRequiresBaud => 'CAT 115200 bps 필요';
	@override String get spectrumNoRadio => '연결된 무전기 없음';
	@override String get spectrumWaiting => '무전기의 스펙트럼 대기 중…';
	@override String get spectrumUnavailable => '스펙트럼 표시를 사용할 수 없습니다';
	@override String get spectrumNoDaxChannel => '이 무전기의 모든 DAX IQ 채널이 사용 중입니다';
	@override String get spectrumNoPanadapter => '이 슬라이스에 무전기의 팬어댑터가 없습니다';
	@override String spectrumStreamRefused({required Object code}) => '무전기가 DAX IQ 스트림을 거부했습니다 (오류 ${code})';
	@override String get spectrumNoUdp => '무전기의 스펙트럼 데이터가 이 기기에 도달할 수 없습니다';
	@override String get spectrumK4Unavailable => 'K4의 LAN 스펙트럼을 수신할 수 없습니다. 다시 시도 중…';
	@override String get spectrumK4RemoteUnavailable => 'K4의 원격 스펙트럼을 수신할 수 없습니다';
	@override String get spectrumScopeRefused => '무전기가 스코프 명령을 거부했습니다';
	@override String get spectrumOutOfRange => '무전기의 스코프가 표시할 수 있는 범위 밖으로 설정되어 있습니다';
	@override String get spectrumBandUnsupported => '이 밴드에서는 무전기의 스코프를 표시할 수 없습니다';
	@override String get spectrumSdrNoRadio => '연결된 무전기의 주파수 대기 중…';
	@override String get spectrumSdrNotConnected => 'SDR이 연결되어 있지 않습니다';
	@override String get spectrumSdrNoIf => '이 SDR의 설정에서 무전기의 IF 주파수를 설정하세요';
	@override String get sdrRadio => '스펙트럼 표시 대상';
	@override String get sdrRadioDescription => '이 무전기의 스펙트럼 표시는 무전기 자체 스코프 대신 이 수신기에서 데이터를 가져옵니다.';
	@override String get sdrRadioMain => '메인 무전기';
	@override String get sdrTuning => '안테나 입력';
	@override String get sdrTuningDescription => '수신기 신호의 출처. 자체 안테나를 쓰면 무전기를 따라 스스로 튜닝하고, 무전기의 IF 출력에서는 IF에 고정됩니다.';
	@override String get sdrTuningIndependent => '자체 안테나';
	@override String get sdrTuningIfTap => '무전기의 IF 출력';
	@override String get sdrIfHz => 'IF 주파수 (Hz)';
	@override String get sdrIfHzDescription => 'IF 출력 전용: 무전기 다이얼 주파수가 IF상에서 위치하는 주파수. 예: FT-817은 68330000.';
	@override String get sdrIfInverted => 'IF 반전';
	@override String get sdrGainDb => '게인 (dB)';
	@override String get sdrGainDbDescription => '비워 두면 수신기의 자동 게인을 사용합니다.';
	@override String get sdrOffsetHz => '주파수 오프셋 (Hz)';
	@override String get sdrOffsetHzDescription => '업컨버터용으로 수신기에 보내는 모든 주파수에 더해지는 값. Ham It Up은 125000000.';
	@override String get sdrPpm => '주파수 보정 (ppm)';
	@override String get rtlDirectSampling => '다이렉트 샘플링';
	@override String get rtlDirectSamplingDescription => '업컨버터 없는 RTL-SDR V3에서 HF를 수신할 때 사용. RTL-SDR V4는 이것 없이도 HF를 수신합니다.';
	@override String get rtlDirectSamplingOff => '꺼짐';
	@override String get rtlDirectSamplingI => 'I 브랜치';
	@override String get rtlDirectSamplingQ => 'Q 브랜치';
	@override String get rtlTcpNotAServer => 'rtl_tcp 서버가 아닙니다';
	@override String get rtlTcpNotes => '동글이 연결된 컴퓨터에서 **직접 실행하는 rtl_tcp 서버**에 연결합니다.\n\n- **시작**은 다른 컴퓨터에서 접근할 수 있도록 `rtl_tcp -a 0.0.0.0`으로 하세요. 같은 컴퓨터에서는 `rtl_tcp`만으로 충분합니다.\n- **포트**는 `-p`로 지정하지 않았다면 1234입니다.\n- **한 번에 한 프로그램만:** rtl_tcp는 클라이언트 하나만 받습니다. 앱은 스펙트럼 표시가 보이는 동안만 연결하고, 닫힌 뒤 몇 초 후에 놓습니다.\n- **Android에서는** *SDR driver* 앱이 휴대폰에서 같은 서버를 실행합니다.';
	@override String get rspTcpNotes => 'RSP가 연결되고 SDRplay API가 설치된 컴퓨터에서 **직접 실행하는 rsp_tcp 서버**에 연결합니다.\n\n- **시작**은 `rsp_tcp -a 0.0.0.0`으로 하세요.\n- **포트**는 `-p`로 지정하지 않았다면 1234입니다.\n- **한 번에 한 프로그램만:** 서버는 클라이언트 하나만 받습니다. 앱은 스펙트럼 표시가 보이는 동안만 연결합니다.';
	@override String get n3fjpNoRig => 'N3FJP에 무전기 인터페이스가 설정되어 있지 않아, 무전기가 아닌 N3FJP에 입력된 값을 따릅니다';
	@override String get winkeyerKeyPort => '키 출력';
	@override String get winkeyerKeyPortDescription => '무전기가 연결된 키어의 출력 잭 (두 개 중 하나).';
	@override String winkeyerKeyPortLabel({required Object n}) => '포트 ${n}';
	@override String get winkeyerPtt => '키어의 PTT 사용';
	@override String get winkeyerPttDescription => '앰프나 이를 필요로 하는 무전기를 위해 같은 잭의 PTT 라인을 키잉합니다. 키 잭으로 키잉되는 무전기는 끄세요.';
	@override String get winkeyerNoAnswer => '이 포트에서 응답한 WinKeyer가 없습니다';
	@override String get winkeyerStoppedAnswering => '전송 중 WinKeyer가 응답을 멈춰 메시지가 취소되었습니다';
	@override String get icomControlPort => '제어 포트 (UDP)';
	@override String get icomControlPortDescription => '무전기의 Control Port (UDP). 네트워크 설정에서 변경하거나 다른 포트로 포워딩하지 않았다면 50001입니다.';
	@override String get icomSerialPort => '시리얼 포트 (UDP)';
	@override String get icomSerialPortDescription => '무전기의 Serial Port (UDP). 네트워크 설정에서 변경하거나 다른 포트로 포워딩하지 않았다면 50002입니다.';
	@override String get icomPortsDiffer => '제어 포트와 시리얼 포트는 서로 달라야 합니다';
	@override String get radioUser => '무전기 사용자 이름';
	@override String get radioPass => '무전기 비밀번호';
	@override String get radioLoginDescription => 'WiFi 비밀번호가 아닌, 무전기의 Network → Remote 로그인 정보.';
	@override String get radioUserRequired => '무전기의 원격 제어 사용자 이름이 필요합니다';
	@override String get connectFailedBusy => '장치가 사용 중입니다';
	@override String get connectFailedDenied => '접근이 거부되었습니다';
	@override String get connectFailedDevice => '장치를 찾을 수 없습니다';
	@override String get connectFailedUnsupported => '이 USB 어댑터의 칩을 인식하는 드라이버가 없습니다. 어떤 칩인지 알고 있다면 고급 설정의 USB 칩 드라이버에서 선택하세요.';
	@override String get connectFailedLines => 'RTS/DTR을 설정대로 유지할 수 없어 포트를 닫았습니다. 다른 프로그램이 하드웨어 핸드셰이킹을 켜 두었을 수 있습니다. 케이블을 뽑았다가 다시 꽂으세요.';
	@override String get connectFailedNetwork => '네트워크에서 무전기를 찾을 수 없습니다. 주소를 확인하고 전원이 켜져 있으며 연결 가능한지 확인하세요.';
	@override String connectFailedReplyPort({required Object port}) => '이 기기의 포트 ${port}이(가) 이미 사용 중이며, 응답이 그 포트로 도착합니다. 다른 PstRotator 노드를 포함해 그 포트에서 수신 대기하는 다른 프로그램을 닫거나 포트를 변경하세요.';
	@override String get connectFailedTimeout => '무전기가 제시간에 응답하지 않았습니다. 전원이 켜져 있고 연결 가능한지 확인하세요.';
	@override late final _Translations$settings$station$models$ko models = _Translations$settings$station$models$ko._(_root);
	@override late final _Translations$settings$station$transports$ko transports = _Translations$settings$station$transports$ko._(_root);
	@override String get troubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get ft891Troubleshooting => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기에서 CAT RTS를 끄거나, RTS를 high로 유지를 켜세요.** **CAT RTS**가 켜져 있으면(FT-891 메뉴 **05-08**) RTS가 low인 동안 무전기는 침묵합니다. 포트가 열릴 때 한 번 응답하고는 아무것도 보내지 않을 수 있습니다. 무전기 자체 USB 포트를 선택하면 고급 설정의 **RTS를 high로 유지**가 켜집니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신기가 키잉됩니다. 이 경우 대신 무전기에서 CAT RTS를 끄세요.\n- **속도가 무전기의 CAT RATE와 일치해야 합니다** (메뉴 **05-06**). 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.';
	@override String get yaesuBinaryTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get yaesuBinaryTroubleshooting => '이 무전기는 Yaesu의 구형 5바이트 CAT을 사용하며, 설정이 맞지 않으면 전혀 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **케이블이 레벨을 변환해야 합니다.** 후면의 CAT 잭은 RS-232도 USB도 아니며, CT-62 또는 동등한 어댑터가 필요합니다. 일반 오디오 또는 데이터 케이블로는 CAT이 작동하지 않습니다.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다** (FT-817은 **#14**, FT-857 또는 FT-897은 **#19**). 일치하지 않으면 무전기가 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **이 포트에서 RTS나 DTR을 절대 올리지 마세요.** 이 무전기용 케이블 대부분에서 이 라인은 PTT와 키잉입니다. 단, DTR에서 전원을 받는 구형 인터페이스는 예외이며, 이 경우 고급 설정의 **DTR을 high로 유지**를 켜세요.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 드라이버는 Yaesu가 공개한 CAT 표를 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get tenTecTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get tenTecEagleTroubleshooting => '- **후면의 USB-B 포트가 CAT 연결입니다.** 무전기는 USB 시리얼 포트로 나타나며, Windows에서는 Ten-Tec의 USB to UART 드라이버가 필요합니다. 장치 관리자에는 "USB to UART (COMx)"로 표시됩니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 두며, Ten-Tec의 펌웨어 업데이터도 마찬가지입니다.\n- **앱에서 필터 폭을 설정하면 무전기를 껐다 켤 때까지 BW 노브로 조절할 수 없게 됩니다.** 무전기가 원래 그렇게 동작합니다.\n\n이 드라이버는 Ten-Tec의 프로그래머 참조 가이드를 바탕으로 작성되었습니다. 부분적으로만 작동한다면 무전기 메뉴의 펌웨어 버전과 함께 제보해 주세요.';
	@override String get tenTecOrionTroubleshooting => '- **SERIAL DATA 포트에는 스트레이트 DB-9 시리얼 케이블을 사용하세요.** 널 모뎀 케이블은 안 됩니다.\n- **이 항목은 RTS를 high로 유지합니다.** Orion이 RTS와 CTS를 핸드셰이크로 사용하기 때문입니다. Digirig처럼 RTS로 PTT를 키잉하는 인터페이스에서는 고급 설정의 RTS를 high로 유지를 끄세요. 그렇지 않으면 앱이 연결되는 즉시 무전기가 송신합니다.\n- **앱에서 CW를 보내려면 무전기의 내장 키어가 켜져 있어야 합니다.** 꺼져 있으면 무전기가 앱이 보내는 내용을 무시합니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 드라이버는 Ten-Tec의 프로그래머 참조 가이드를 바탕으로 작성되었으며 실제 Orion에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 무전기 메뉴의 펌웨어 버전과 함께 제보해 주세요.';
	@override String get tenTecNoCw => '이 무전기의 펌웨어는 앱에서 보내는 CW를 받지 않습니다. Ten-Tec은 Orion 펌웨어 1.366에서 이를 추가했습니다.';
	@override String get tenTecKeyerOff => '무전기의 내장 키어가 꺼져 있어 앱에서 보내는 CW를 무시합니다. 무전기 메뉴에서 키어를 켜세요.';
	@override String get guohetecTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get guohetecTroubleshooting => 'Q900에는 두 가지 CAT 프로토콜이 있으며, 이 항목은 FT-817 모방이 아닌 고유 프로토콜을 사용합니다. 여기서는 FT-817이 아닌 **Guohetec Q900**을 선택하세요. 모방 프로토콜은 지원하는 명령이 더 적고, 무전기는 어느 쪽을 사용 중인지 알려주지 않습니다.\n\n- **USB-C 케이블이 CAT 연결이며**, 사운드 카드도 함께 연결합니다. 이 포트에서는 속도가 중요하지 않으며, 어떤 값으로 설정해도 무시됩니다.\n- **이 포트에서 RTS나 DTR을 절대 올리지 마세요.** 시리얼 케이블에서 이 라인은 PTT와 키잉입니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **2세대 무전기는 1세대와 다르게 동작합니다.** Menu를 길게 누른 후 About을 확인하세요: HW 2.0이 2세대입니다.\n\n이 드라이버는 제조사가 공개한 프로토콜을 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get yaesuTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get yaesuTroubleshooting => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기에서 CAT RTS가 OFF여야 합니다.** 켜져 있으면 무전기는 앱이 low로 유지하는 핸드셰이크 라인을 기다립니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 같은 라인이 PTT이므로, 올리면 송신기가 키잉됩니다. 무전기 자체 USB 포트에서는 고급 설정의 **RTS를 high로 유지**가 대안입니다. 이 설정의 위치는 모델마다 다릅니다 (FT-891은 메뉴 **05-08**).\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **모드는 FT-891의 표를 따릅니다.** 대부분의 Yaesu 모델이 이와 일치하지만, 모드 번호가 다른 무전기에서는 해당 모드가 잘못 표시되거나 설정됩니다. 주파수는 영향을 받지 않습니다.';
	@override String get ftdx3000Troubleshooting => '무전기의 USB 포트로 CAT을 사용하려면 **메뉴 037 CAT SELECT가 USB여야 합니다**. RS232C로 설정하면 CAT은 후면 잭에 있습니다.\n\n이 항목은 공개된 CAT 문서를 바탕으로 작성되었으며 실제 FTDX3000에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get yaesuRs232Troubleshooting => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **CAT 잭은 RS-232입니다.** USB-시리얼 어댑터와 스트레이트 DB-9 케이블이 필요합니다. 널 모뎀 케이블은 라인을 바꾸므로 무전기가 아무것도 받지 못합니다.\n- **무전기에서 CAT RTS가 OFF여야 합니다.** 켜져 있으면 고급 설정의 **RTS를 high로 유지**가 켜져 있지 않은 한, 무전기는 앱이 low로 유지하는 핸드셰이크 라인을 기다립니다.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 항목은 공개된 CAT 문서를 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get yaesuUsbTroubleshooting => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기의 두 USB 포트 중 첫 번째를 사용하세요.** CAT은 보통 첫 번째 포트(Windows에서는 **Enhanced** COM 포트)에 있고, 두 번째(**Standard**)는 PTT와 키잉용입니다. 두 포트를 구분할 수 있으면 선택기가 첫 번째를 가리킵니다.\n- **무전기에서 CAT RTS를 끄거나, RTS를 high로 유지를 켜세요.** 무전기의 **CAT RTS** 메뉴가 켜져 있으면 RTS가 low인 동안 무전기는 침묵합니다. 포트가 열릴 때 한 번 응답하고는 아무것도 보내지 않을 수 있습니다. 무전기 자체 USB 포트를 선택하면 고급 설정의 **RTS를 high로 유지**가 켜집니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신기가 키잉됩니다. 이 경우 대신 무전기에서 CAT RTS를 끄세요.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.';
	@override String get k4SerialNotes => 'K4 후면의 USB-B (PC) 소켓을 연결하세요. CAT에는 USB-PC1 또는 USB-PC2 모두 사용할 수 있습니다. 사용하지 않는 포트를 선택하고 무전기의 Serial USB-PCn: Baud Rate 설정과 맞추세요. HaLo는 38400을 미리 입력하며, 필요하면 변경하세요. 다른 애플리케이션은 나머지 포트나 이더넷을 사용해야 합니다.\n\n이 연결은 무전기와 키어를 제어하며, HaLo로 오디오를 보내지 않습니다.';
	@override String get k4TcpNotes => 'K4의 이더넷 소켓을 로컬 네트워크에 연결하세요. 호스트 이름 또는 IP 주소와 CAT 포트 9200을 입력하세요. 팬어댑터나 워터폴이 표시될 때 HaLo는 같은 호스트의 고정 포트 9201을 사용하며, CAT 포트를 바꿔도 스펙트럼 포트는 바뀌지 않습니다.\n\n스펙트럼은 메인 수신기를 표시합니다. 줌, 기준 조정, 속도 컨트롤은 HaLo의 표시에만 영향을 줍니다. 오디오 스트리밍은 지원되지 않습니다.';
	@override String get k4PowerTimeout => '무전기가 출력 범위를 확인해 주지 않아 K4 출력을 변경하지 않았습니다. 다시 시도하세요.';
	@override String get k4RemoteNotes => 'K4에서 원격 접근을 활성화하고 네트워크 비밀번호를 입력하세요. 메인과 서브는 무전기 제어와 스펙트럼을 위해 하나의 암호화된 연결을 공유합니다. 기본 포트는 9204이며, 원격으로 연결할 때는 포워딩한 포트를 입력하세요.\n\n오디오 재생과 마이크 스트리밍은 지원되지 않습니다.';
	@override String get k4Receiver => '수신기';
	@override String get k4ReceiverMain => '메인';
	@override String get k4ReceiverSub => '서브';
	@override String get k4ReceiverInvalid => '메인 또는 서브를 선택하세요';
	@override String get k4ReceiverAlreadyConfigured => '이 K4에는 해당 수신기가 이미 구성되어 있습니다';
	@override String get k4SubReceiverOff => 'K4 서브 수신기가 꺼져 있습니다';
	@override String get k4RemotePasswordRequired => '안전하게 연결하려면 K4의 네트워크 비밀번호를 입력하세요.';
	@override String get k4RemoteHandshakeFailed => 'K4가 보안 연결을 수립할 수 없습니다. 네트워크 비밀번호와 원격 접근 설정을 확인하세요.';
	@override String get k4RemoteUnreachable => 'K4의 보안 연결에 접속할 수 없습니다. 주소, 포트 및 원격 접근 설정을 확인하세요.';
	@override String get k4PowerRange => 'K4 출력은 0.1–110 W이어야 하며, 트랜스버터 밀리와트 출력이 활성화된 경우 0.0001–0.01 W이어야 합니다.';
	@override String get elecraftTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get elecraftTroubleshooting => 'Elecraft 무전기는 Kenwood CAT을 사용하며, KX2와 KX3 모두 이 방식으로 실행해 보았습니다. 양방향 VFO, 모드 전환, CW 제로비트 모두 작동합니다.\n\n무전기가 응답하지 않으면 거의 항상 다음 중 하나입니다:\n\n- **속도가 일치해야 합니다**: 무전기 메뉴의 **RS232**에 설정된 속도와 같아야 합니다. 출고값은 38400입니다. 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n**주파수는 맞는데 모드가 틀리면** 알려 주세요. KX2와 KX3 항목은 지금까지 본 무전기를 기준으로 고정한 상태 응답 위치에서 모드를 읽으며, 이 위치가 다른 펌웨어는 제보를 통해서만 알 수 있습니다.\n\nK3는 아직 어느 쪽으로도 보고된 적이 없으니, 사용해 보셨다면 결과를 알려 주세요. K4는 별도 항목이 있습니다.';
	@override String get lab599TroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get lab599Troubleshooting => 'TX-500 시리즈는 Kenwood CAT을 사용합니다. 주파수와 모드는 LiNK500MP를 통해 실행해 보았고, 출력과 미터는 Lab599의 CAT 참조 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n- **속도가 무전기의 CAT 설정과 일치해야 합니다.** 변경하지 않았다면 9600입니다. 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **무전기에서 CAT 프로토콜을 선택하세요.** TS-2000은 주파수, 모드, 출력을 지원합니다. LAB599는 추가로 앱이 무전기를 DIG로 전환하고, DIG에서 송신하는 것을 보고, 공급 전압을 읽을 수 있게 합니다.\n- **LiNK500MP를 통해 연결할 때는** VFO 노브를 약 3초간 길게 눌러 CAT 제어를 인터페이스에 넘기세요.\n- **연결 방식에 맞게 LiNK500MP의 모드를 설정하세요**: 블루투스는 Mode 3, 블루투스 LE는 Mode 4. 다른 모드에서는 블루투스 LE 검색에 나타나지 않습니다.\n- **블루투스로 연결하면** LiNK500MP가 시리얼 포트 두 개로 페어링되며 그중 하나만 CAT을 전달합니다. 무전기가 응답하지 않으면 다른 포트를 선택하세요.';
	@override String get lab599TroubleshootingIos => 'TX-500 시리즈는 Kenwood CAT을 사용합니다. 주파수와 모드는 LiNK500MP를 통해 실행해 보았고, 출력과 미터는 Lab599의 CAT 참조 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n- **검색하기 전에 LiNK500MP를 블루투스 LE 모드인 Mode 4로 설정하세요.** 다른 모드에서는 iPhone이나 iPad가 찾을 수 없습니다.\n- **CAT 제어를 LiNK500MP에 넘기세요**: 무전기의 VFO 노브를 약 3초간 길게 누르세요.\n- **무전기에서 CAT 프로토콜을 선택하세요.** TS-2000은 주파수, 모드, 출력을 지원합니다. LAB599는 추가로 앱이 무전기를 DIG로 전환하고, DIG에서 송신하는 것을 보고, 공급 전압을 읽을 수 있게 합니다.';
	@override String get kenwoodTroubleshootingTitle => '무전기가 연결되었지만 주파수가 표시되지 않는 경우';
	@override String get kenwoodTroubleshooting => '이 드라이버는 Kenwood TS-590SG와 TS-480, QRP Labs QMX와 QCX-mini, Elecraft KX2와 KX3에서 검증되었습니다. 나머지 모델은 공개된 CAT 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n무전기가 응답하지 않으면 거의 항상 다음 중 하나입니다:\n\n- **속도가 무전기의 CAT 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **일부 무전기는 메뉴에서 CAT을 활성화해야** 응답합니다.\n- **Kenwood 무전기는 RTS를 기다립니다**: CAT 포트가 RTS를 핸드셰이크로 사용하므로, 고급 설정의 RTS를 high로 유지가 켜져 있어야 합니다. 이 설정이 기본으로 켜지기 전에 만든 연결에서는 꺼져 있을 수 있습니다. Digirig 등 RTS로 PTT를 키잉하는 케이블에서는 끄세요. 그렇지 않으면 무전기가 송신합니다.\n\n**여러 SDR 프런트엔드도 같은 프로토콜을 사용하므로** 이 항목을 시도해 볼 만합니다. Elecraft 무전기는 Elecraft 아래에 별도로 있습니다. 주파수는 맞는데 모드가 틀리거나 없다면, 그것이 모델마다 다른 유일한 부분입니다. 앱이 무전기로부터 알아내고 안 되면 직접 물어보므로, 모드가 단순히 늦게 표시될 수 있습니다.';
	@override String get statusConnected => '연결됨';
	@override String get statusLost => '연결 끊김';
	@override String get notConfigured => '구성되지 않음';
	@override String get currentConfiguration => '현재 구성';
	@override String get currentTransceiver => '현재 트랜시버';
	@override String get currentTransceivers => '현재 트랜시버';
	@override String so2rRadioName({required Object radio, required Object name}) => '${radio}: ${name}';
	@override String get so2rQueueMessages => '메시지를 중단하지 않고 대기열에 넣음';
	@override String get noRadioBSelected => '무전기 B가 선택되지 않음';
	@override String get radioMode => '무전기 모드';
	@override String get keyerNotSupported => '현재 무전기에서 지원하지 않음';
	@override String get catControlPreferences => 'CAT 제어 환경설정';
	@override String get chooseTransceiver => '트랜시버 선택';
	@override String get configurationSection => '구성';
	@override String get noTransceiverSelected => '선택된 트랜시버 없음';
	@override String makeMainVfo({required Object name}) => '${name}을(를) 메인 VFO로 사용';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		zero: '트랜시버 없음',
		one: '트랜시버 ${count}대',
		other: '트랜시버 ${count}대',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '안테나 ${count}개',
		other: '안테나 ${count}개',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '기타 장치 ${count}개',
		other: '기타 장치 ${count}개',
	);
	@override String get equipmentInventory => '장비 목록';
	@override String get equipmentInUse => '트랜시버 제어';
	@override String get noTransceiver => '없음';
	@override String get peerRadioNotAvailable => '사용할 수 없음';
	@override String peerRadioOnDevice({required Object device}) => '${device}에 있음';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio}은(는) 다른 기기에 있습니다';
	@override String peerRadioElsewhereMessage({required Object device}) => '이 무전기는 ${device}에 연결되어 있습니다. 연결과 설정은 해당 기기에서 구성합니다.';
	@override String get antennaInUse => '사용 중인 안테나';
	@override String get keyInUse => 'CW 키잉';
	@override String get phoneKeying => '보이스 키잉';
	@override String get phoneKeyingNone => '없음';
	@override String phoneKeyingRadio({required Object radio}) => '${radio}의 메모리';
	@override String get phoneKeyingComputer => '이 컴퓨터의 오디오';
	@override String get phoneKeyingOff => '보이스 키잉이 꺼져 있습니다';
	@override String get computerVoiceSettings => '컴퓨터 오디오';
	@override String get cwKeyingOptions => 'CW 키잉 옵션';
	@override String get noneSelected => '없음';
	@override String get moreSettings => '추가 설정';
	@override String get icomCivTroubleshootingTitle => '같은 무전기에 시리얼 포트가 두 개 표시되는 경우';
	@override String get icomCivTroubleshooting => 'IC-705를 비롯한 여러 Icom 무전기는 USB 시리얼 포트를 동시에 **두 개** 제공하며(Icom은 Port A와 Port B라고 부름), 둘 다 기본적으로 CI-V로 설정되어 있습니다. 이 앱도 OS도 그 이상으로 둘을 구분할 수 없습니다. 같은 USB 벤더/제품 ID가 두 번 나타나며, 여기서는 `#2` 접미사가 붙기도 합니다. **보통 Port A가 맞습니다.** 일반적으로 OS나 브라우저가 처음 나열하는 포트이며, 이 앱이 두 포트를 구분할 수 있으면 그 포트를 추천으로 표시합니다. 명령을 보냈는데 무전기가 응답하지 않으면 다른 포트를 시도하세요.';
	@override String get civAddressTroubleshootingTitle => '무전기가 전혀 응답하지 않는 경우';
	@override String get civAddressTroubleshooting => '- **CI-V 주소가 무전기의 메뉴와 일치해야 합니다.** 이 항목은 모델의 출고 주소를 미리 입력하지만, CI-V 버스를 공유하는 무전기에서는 바로 이 값이 변경됩니다. 잘못된 주소로 보낸 프레임은 조용히 무시되며, 이는 케이블 불량과 똑같아 보입니다.\n- **속도가 무전기의 CI-V BAUD RATE와 일치해야 합니다** (USB에서는 CI-V USB Baud Rate). 무전기를 여기 표시된 값과 같게 설정하고, **Auto로 두지 마세요**. Auto로 두면 IC-7300 등 일부 무전기는 연결된 후 1분쯤 지나 응답을 멈춥니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.';
	@override String civAddressFixedSpeedTroubleshooting({required Object speed}) => '- **CI-V 주소가 무전기의 메뉴와 일치해야 합니다.** 이 항목은 모델의 출고 주소를 미리 입력하지만, CI-V 버스를 공유하는 무전기에서는 바로 이 값이 변경됩니다. 잘못된 주소로 보낸 프레임은 조용히 무시되며, 이는 케이블 불량과 똑같아 보입니다.\n${speed}\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.';
	@override String get icomUsbSpeedFollows => '- **설정할 속도가 없습니다.** USB에서는 이 무전기가 컴퓨터가 사용하는 속도로 통신하며, 이 항목은 스코프에 필요한 115200을 항상 사용합니다.';
	@override String get ic7610UsbSpeed => '- **CI-V USB Baud Rate를 115200으로 설정하세요.** 스코프에 필요하므로 이 항목이 항상 사용하는 속도이며, **Auto로 두지 마세요**. 다른 속도로 설정된 무전기는 응답하지 않습니다.';
	@override String get civTransceiveTitle => '앱이 무전기를 느리게 따라가는 경우';
	@override String get civTransceive => '무전기에서 주파수나 모드를 바꾼 후 앱에 표시되기까지 몇 초가 걸리면, 무전기의 **CI-V Transceive** 설정을 켜세요 (최신 모델 대부분은 SET > Connectors > CI-V 아래). 켜져 있으면 무전기가 변경 즉시 보고합니다. 꺼져 있으면 앱이 몇 초마다 물어볼 때에야 변경을 알게 됩니다.';
	@override String get ic7300Mk2Note => '\n- **IC-7300 MK2**의 출고 주소는 여기 미리 입력된 `94`가 아닌 `B6`입니다. 대신 IC-7300 MK2 항목을 선택하세요.';
	@override String get ic705PortNote => '\n- **IC-705**는 무전기 이름이 붙은 USB 시리얼 포트를 두 개 제공합니다. CI-V는 그중 **첫 번째**에 있으며, 두 포트를 구분할 수 있으면 선택기가 그 포트를 가리킵니다.';
	@override String get ic7760PortNote => '\n- **IC-7760**은 제공하는 두 USB 시리얼 포트 중 **Port A**에서 CI-V를 사용합니다.';
	@override String get x6100PortNote => '\n- **X6100**은 **DEV** 포트에서 CI-V를 사용합니다. 제공하는 두 시리얼 포트 중 두 번째이며, 선택기가 가리키는 포트입니다.';
	@override String get rigctldTroubleshootingTitle => '앱이 연결할 수 없는 경우';
	@override String get rigctldTroubleshooting => '이 항목은 무전기에 직접 연결하는 것이 아니라 **직접 실행하는 rigctld 데몬**에 연결합니다. Hamlib의 백엔드가 무전기와 통신하며 수백 개의 모델을 지원합니다.\n\n- **데몬이 이미 실행 중이어야 합니다.** 예: `rigctld -m 1035 -r /dev/ttyUSB0`. 무전기의 모델 번호는 `rigctl -l`로 찾으세요.\n- **다른 컴퓨터에서 연결하려면** `-T 0.0.0.0`으로 시작하세요. 기본적으로 rigctld는 실행 중인 컴퓨터의 연결만 받습니다.\n- **포트**는 데몬을 `-t`로 시작하지 않았다면 4532입니다.\n- 연결된 후 주파수가 표시되지 않는다면 보통 데몬 자체가 무전기에 연결하지 못하는 것입니다. 데몬이 실행 중인 컴퓨터에서 `rigctl -m 2 f`로 테스트하세요.';
	@override String get flrigTroubleshootingTitle => '앱이 연결할 수 없는 경우';
	@override String get flrigTroubleshooting => '이 항목은 무전기에 직접 연결하는 것이 아니라 **직접 실행하는 flrig 프로그램**에 연결합니다. flrig가 무전기와 통신하며 대부분의 제조사와 모델을 지원합니다.\n\n- **flrig가 이미 실행 중이어야 하며**, 트랜시버가 구성되고 연결되어 있어야 합니다.\n- **포트**는 flrig 구성(Config → Setup → Server)에서 변경하지 않았다면 12345입니다.\n- **다른 컴퓨터에서 연결하려면** flrig 서버에 연결할 수 있는지 확인하세요. flrig는 모든 인터페이스에서 수신 대기하지만, 방화벽이 막을 수 있습니다.\n- 연결된 후 주파수가 표시되지 않는다면 보통 flrig 자체가 무전기에 연결하지 못하는 것입니다. flrig 화면이 다이얼을 따라가는지 확인하세요.';
	@override String get hrdTroubleshootingTitle => '앱이 연결할 수 없는 경우';
	@override String get hrdTroubleshooting => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 Ham Radio Deluxe의 Rig Control**에 연결합니다. HRD가 무전기와 통신합니다.\n\n- **Rig Control이 이미 실행 중이며** 무전기에 연결되어 있어야 합니다.\n- **IP 서버가 활성화되어 있어야 합니다.** Rig Control은 이를 통해서만 다른 프로그램과 통신합니다.\n- **포트**는 IP 서버 설정에서 변경하지 않았다면 7809입니다.\n- **다른 컴퓨터에서 연결하려면** 방화벽이 연결을 허용하는지 확인하세요.\n\n이 항목은 HRD 프로토콜에 대한 공개 설명을 바탕으로 작성되었으며 실제 HRD에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get n3fjpTroubleshootingTitle => '앱이 연결할 수 없는 경우';
	@override String get n3fjpTroubleshooting => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 N3FJP 로깅 프로그램**에 연결합니다. N3FJP가 무전기와 통신합니다.\n\n- **프로그램의 API가 켜져 있어야 합니다**: Settings → Application Program Interface에서 **TCP API Enabled**를 체크하세요.\n- **포트**는 그곳에서 변경하지 않았다면 1100입니다.\n- 무전기를 따라가거나 튜닝하려면 **N3FJP에 무전기 인터페이스가 설정되어 있어야 합니다.** 없으면 입력 창에 입력된 값만 보고합니다.\n- N3FJP는 밴드, 모드, 주파수만 보고합니다. 출력과 송신 상태는 보고하지 않습니다.\n\n이 항목은 N3FJP가 공개한 API를 바탕으로 작성되었으며 실제 N3FJP에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get commanderTroubleshootingTitle => '앱이 연결할 수 없는 경우';
	@override String get commanderTroubleshooting => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 DXLab Commander**에 연결합니다. Commander가 무전기와 통신합니다.\n\n- **Commander가 이미 실행 중이며** 무전기에 연결되어 있어야 합니다.\n- **네트워크 서비스가 켜져 있어야 합니다**: Commander 구성 창의 Radio 패널에 있는 **Net Serv** 버튼.\n- **포트**는 52002이며, Net Serv의 **Base Port**(변경하지 않았다면 52000)부터 시작하는 블록의 세 번째 포트입니다.\n- **다른 컴퓨터에서 연결하려면** 방화벽이 연결을 허용하는지 확인하세요.\n\n이 항목은 Commander가 공개한 TCP 메시지를 바탕으로 작성되었으며 실제 Commander에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.';
	@override String get ic705TroubleshootingTitle => '무전기가 전혀 응답하지 않는 경우';
	@override String get ic705Troubleshooting => '무전기는 원격 제어 세션을 **하나만** 지원합니다. 로그인이 무시된다면 거의 항상 다른 무언가가 세션을 사용 중입니다.\n\n- **다른 클라이언트를 모두 닫으세요.** 같은 무전기에 연결된 wfview나 RS-BA1이 그 세션을 점유하며, 그동안 여기서의 로그인은 그냥 무시됩니다.\n- **무전기의 네트워크 설정을 확인하세요.** WLAN이 켜져 있고, 무전기가 같은 네트워크에 있으며, 원격 제어(Network) 기능이 활성화되어 있어야 합니다.\n- **포트가 일치해야 합니다.** 무전기의 Control Port와 Serial Port (UDP), 또는 그곳으로 포워딩된 포트와 같아야 합니다. 포트가 틀리면 꺼진 무전기와 똑같이 아무 응답이 없습니다.\n- 계속 멈춰 있다면 **무전기의 WLAN을 껐다 켜세요.** 무전기에 멈춰 있는 세션이 확실히 해제됩니다.\n\n**비밀번호가 틀리면 명시적으로 거부**되며, 응답이 없는 것이 아닙니다. "거부됨" 메시지 대신 이 화면이 나왔다면 비밀번호 문제가 아닙니다.';
	@override String get icomLanTroubleshooting => '무전기는 원격 제어 세션을 **하나만** 지원합니다. 로그인이 무시된다면 거의 항상 다른 무언가가 세션을 사용 중입니다.\n\n- **다른 클라이언트를 모두 닫으세요.** 같은 무전기에 연결된 wfview, RS-BA1 또는 Icom의 Remote Utility가 그 세션을 점유하며, 그동안 여기서의 로그인은 그냥 무시됩니다.\n- **무전기의 네트워크 설정을 확인하세요.** LAN 포트가 이 기기와 같은 네트워크에 연결되어 있고, **Network Control**이 켜져 있으며, 사용자 이름과 비밀번호가 무전기에 네트워크 사용자로 설정되어 있어야 합니다.\n- **포트가 일치해야 합니다.** 무전기의 Control Port와 Serial Port (UDP), 또는 그곳으로 포워딩된 포트와 같아야 합니다. 포트가 틀리면 꺼진 무전기와 똑같이 아무 응답이 없습니다.\n- **연결은 되는데 응답이 없다면**, 여기의 CI-V 주소가 무전기의 CI-V ADDRESS 메뉴와 일치해야 합니다. 이 항목은 모델의 출고 주소를 미리 입력합니다.\n- 계속 멈춰 있다면 **무전기를 껐다 켜세요.**';
	@override String get statusStale => '응답 없음';
	@override String get statusDisconnected => '연결 안 됨';
	@override String get statusConnecting => '연결 중…';
	@override String get statusDisconnecting => '연결 해제 중…';
	@override String get statusError => '연결 실패';
	@override String get currentRadioSettings => '현재 무전기 설정';
	@override String get notSupportedByThisRadio => '이 무전기에서 지원하지 않음';
	@override String get cwMessagesButton => 'CW 메시지';
	@override String get voiceMessagesButton => '보이스 메시지';
	@override String voiceKeyerAvailable({required Object count}) => '보이스 키어: 무전기에 메모리 ${count}개';
	@override String get antennaBands => '밴드';
	@override String get antennaType => '안테나 유형';
	@override String get antennaTypeRequired => '안테나 유형을 선택하세요';
	@override late final _Translations$settings$station$antennaTypes$ko antennaTypes = _Translations$settings$station$antennaTypes$ko._(_root);
	@override String get keyType => '키 유형';
	@override String get keyTypeRequired => '키 유형을 선택하세요';
	@override late final _Translations$settings$station$keyTypes$ko keyTypes = _Translations$settings$station$keyTypes$ko._(_root);
	@override String get softwareIntermediaries => '중계 소프트웨어';
	@override String get otherBrands => '기타 브랜드';
	@override String get otherEquipment => '기타 장비 (안테나, 키 등)';
	@override String get newAntenna => '새 안테나';
	@override String get newKey => '새 키';
	@override String get newKeyer => 'WinKeyer (K1EL 또는 호환)';
	@override String keyViaRadio({required Object radio}) => '${radio}의 CAT 키어';
	@override String keyOnDevice({required Object device}) => '${device}의 키';
	@override String get trackStationInfo => 'QSO마다 무선국 정보 기록';
	@override String get includeStationInfoInAdif => 'ADIF 내보내기에 포함';
	@override String get whatToTrack => '무엇을 기록할까요?';
	@override String get trackFieldRig => '트랜시버';
	@override String get trackFieldPower => '출력';
	@override String get watts => '와트';
	@override String get trackFieldAntenna => '안테나';
	@override String get trackFieldKey => 'CW 키';
	@override String get placeholderConnectDelay => '연결 지연 (ms)';
	@override String get placeholderConnectDelayDescription => '시뮬레이션된 핸드셰이크에 걸리는 시간. 비워 두거나 0이면 즉시 연결됩니다.';
	@override String get placeholderDropAfter => '연결 끊기 (초)';
	@override String get placeholderDropAfterDescription => '재연결 경로를 시험하기 위해 스스로 연결을 끊습니다. 비워 두거나 0이면 끊지 않습니다.';
	@override String get placeholderFailConnect => '항상 연결 실패';
	@override String get placeholderConnectFailure => '임시 무전기가 이 연결을 거부하도록 설정되었습니다';
	@override String get placeholderFreq => '주파수 (kHz)';
	@override String get placeholderFreqDescription => '임시 무전기의 시작 주파수. 이후에는 앱이 튜닝한 값을 그대로 보고합니다.';
	@override String get placeholderMode => '모드';
	@override String get placeholderModeDescription => '임시 무전기의 시작 모드. 예: USB, CW, FT8.';
	@override String get placeholderPower => '출력 (와트)';
	@override String get placeholderPurpose => '로깅을 위해 어떤 장비를 사용 중인지 기록하는 데 이 무전기를 사용하세요';
	@override String get placeholderReplyDelay => '응답 지연 (ms)';
	@override String get placeholderReplyDelayDescription => '임시 무전기가 변경 사항을 보고하는 데 걸리는 시간. 비워 두거나 0이면 즉시 응답합니다.';
	@override String get cwKeyerField => 'CAT CW 키어';
	@override String get cwKeyerFieldDescription => '이 무전기가 CAT으로 텍스트를 받아 CW를 키잉하는지 여부. 앱이 모르는 무전기는 끄세요.';
	@override String get voiceMemories => '보이스 메모리';
	@override String get voiceMemoriesDescription => '무전기가 CAT으로 재생하는 보이스 메모리 수. 없으면 0.';
	@override String get voiceMemoriesInvalid => '0 이상의 정수';
	@override String get yaesuMeterCapture => '미터 값 캡처';
	@override String get yaesuBinaryMeterCaptureDescription => '송신 중 무전기의 출력 미터와 높은 SWR 플래그를 읽어 원시 값을 로그에 기록합니다. Yaesu가 공개하지 않은 눈금을 만들기 위한 것이며, 값은 미터로 표시되지 않습니다.';
	@override String get yaesuMeterCaptureDescription => '송신 중 무전기의 PO, SWR, ALC 미터를 읽어 원시 값을 로그에 기록합니다. Yaesu가 공개하지 않은 눈금을 만들기 위한 것이며, 값은 미터로 표시되지 않습니다.';
	@override String get telemetryInterval => '미터 읽기 간격 (ms)';
	@override String get telemetryIntervalDescription => '송신 중 무전기의 미터를 읽는 간격. 비워 두면 이 연결이 처리할 수 있는 가장 빠른 간격(최대 200 ms)을 사용합니다.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 밀리초';
	@override String get pollInterval => '유휴 폴링 간격 (ms)';
	@override String pollIntervalDescription({required Object fallback}) => '주파수와 모드가 바뀌지 않는 동안 무전기에 이를 묻는 간격. 비워 두면 ${fallback} ms입니다.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 밀리초';
	@override String get advancedSettings => '고급 설정';
	@override String get placeholderSwr => 'SWR 값';
	@override String get placeholderSwrDescription => '송신 중 이 무전기가 SWR 미터에 보고하는 값. 1.8을 넘으면 패널이 경고합니다.';
	@override String get placeholderSwrInvalid => '1 이상의 숫자';
	@override String get keyerNone => '없음';
	@override String get cwDialect => 'CW 키잉 방식';
	@override String get cwDialectDescription => '이 무전기가 받는 KY 명령의 형태. 없음은 CAT을 통한 CW 키잉이 없음을 뜻합니다.';
	@override String get cwDialectKenwood => 'Kenwood (KY, 24자로 채움)';
	@override String get cwDialectElecraft => 'Elecraft (KY 텍스트)';
	@override String get voiceDialect => '보이스 키어 방식';
	@override String get voiceDialectDescription => '이 무전기가 CAT으로 보이스 메모리를 재생하는 방식. 없음은 CAT을 통한 보이스 메모리가 없음을 뜻합니다. 방식을 선택하고 개수를 비워 두면 해당 방식의 기본 개수가 적용됩니다.';
	@override String get voiceDialectPb => 'Kenwood (PB, TS-590 방식)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB 및 DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (스위치 탭)';
	@override String get placeholderDiagnostic => '시뮬레이션';
	@override String get placeholderWholeNumberInvalid => '0 이상의 정수여야 합니다';
	@override String get placeholderFreqInvalid => '0보다 큰 kHz 단위 주파수여야 합니다';
	@override String get placeholderModeInvalid => '모드 이름이어야 합니다. 예: USB, CW, FT8';
	@override String get switchLayout => '레이아웃';
	@override String get switchLayoutDescription => '무전기가 스위치의 어느 쪽에 연결되어 있는지.';
	@override String get switchLayoutRequired => '스위치 배선 방식을 선택하세요';
	@override String switchCommandRefused({required Object command, required Object code}) => '스위치가 "${command}"을(를) 거부했습니다 (오류 ${code})';
	@override String get switchBusyTransmitting => '해당 포트가 송신 중입니다 — 안테나를 변경하지 않았습니다';
	@override String get switchNoAntenna => '없음';
	@override String switchAntennaFor({required Object port}) => '포트 ${port} 안테나';
	@override String get switchAntennaForDescription => '스위치의 이 포트에 연결된 안테나.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '안테나 ${antennas}개, 무전기 ${radios}대';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '안테나 ${antennas}개, 무전기 1대';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '안테나 1개, 무전기 ${radios}대';
	@override String get switchCommonPort => '공통';
	@override String get dcnAddress => '장치 주소';
	@override String get dcnAddressDescription => '모듈의 DIP 스위치에 설정된 주소. 동축 릴레이 모듈의 출고값은 2입니다.';
	@override String get dcnAddressRequired => '1에서 99 사이의 장치 주소여야 합니다';
	@override String switchPortLabel({required Object port}) => '포트 ${port}';
	@override String get switchPortAutoHint => '밴드 데이터를 따름';
	@override String get switchPortTransmittingHint => '송신 중 — 지금은 변경할 수 없음';
	@override String get switchCurrentStateHeader => '현재 상태';
	@override String get switchCurrentStateDescription => '지금 각 무전기 포트가 연결된 안테나. 변경 사항은 즉시 적용됩니다.';
	@override String get switchWiringHeader => '배선';
	@override String get switchPortInhibitedHint => '송신 금지됨';
	@override String get rotatorAxes => '축';
	@override String get rotatorAxesDescription => '로테이터가 방위각만 회전하는지, 앙각도 회전하는지 (G-5500 등).';
	@override String get rotatorAxesAzimuth => '방위각만';
	@override String get rotatorAxesAzimuthElevation => '방위각 및 앙각';
	@override String get rotatorAzimuthOffset => '방위각 오프셋';
	@override String get rotatorAzimuthOffsetDescription => '컨트롤러의 0점이 진북이 아닐 때 읽은 값에 더할 각도. 회전도 이에 맞게 보정됩니다.';
	@override String get rotatorElevationOffset => '앙각 오프셋';
	@override String get rotatorAzimuthMin => '최소 방위각';
	@override String get rotatorAzimuthMax => '최대 방위각';
	@override String get rotatorAzimuthMaxDescription => '컨트롤러 자체의 각도 단위. 오버랩이 있는 로테이터는 360 이상으로 설정하면 더 짧은 쪽으로 회전합니다.';
	@override String get rotatorElevationMin => '최소 앙각';
	@override String get rotatorElevationMax => '최대 앙각';
	@override String get rotatorElevationMaxDescription => '컨트롤러 자체의 각도 단위. 뒤집히는(플립) 로테이터는 90 이상.';
	@override String rotatorDegreesInvalid({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 각도';
	@override String get rotatorLimitsInvalid => '최소 한계는 최대보다 작아야 합니다';
	@override String get rotatorPollInterval => '폴링 간격 (ms)';
	@override String rotatorPollIntervalDescription({required Object fallback}) => '로테이터에 방향을 묻는 간격. 비워 두면 ${fallback} ms입니다.';
	@override String get rotatorAxesRequired => '로테이터가 회전하는 축을 선택하세요';
	@override String get rotatorRefused => '컨트롤러가 명령을 거부했습니다. GS-232 모드로 설정되어 있는지 확인하세요.';
	@override String get pstRotatorTroubleshooting => 'PstRotator는 설정이 되어 있을 때만 응답하며, 그렇지 않으면 전혀 응답하지 않습니다:\n\n- PstRotator의 Setup 메뉴에서 **UDP Control을 켜세요.**\n- **포트를 맞추세요**: Communication → UDP Control Port, 변경하지 않았다면 12000. PstRotator는 그 다음 포트(12001)로 응답하므로, 이 기기에서 그 포트가 비어 있어야 합니다.\n- **PstRotator를 컨트롤러에 연결하세요.** 연결되기 전에는 UDP로 아무 응답도 하지 않습니다.\n- PstRotator를 실행하는 PC와, 응답을 수신하는 이 기기 양쪽에서 **방화벽을 통과하도록 허용하세요.**\n- **Mac, iPhone 또는 iPad에서는** Ham2K Logger에 로컬 네트워크 접근 권한이 필요합니다 (설정 → 개인정보 보호 및 보안 → 로컬 네트워크).';
	@override String rotatorCurrentStateHeader({required Object position}) => '현재 상태: ${position}';
	@override String get rotatorDisconnected => '연결 끊김';
	@override String rotatorAzimuthReading({required Object degrees}) => '방위각 ${degrees}°';
	@override String rotatorAzimuthReadingShort({required Object degrees}) => 'AZ ${degrees}°';
	@override String rotatorElevationReading({required Object degrees}) => '앙각 ${degrees}°';
	@override String rotatorElevationReadingShort({required Object degrees}) => 'EL ${degrees}°';
	@override String get rotatorNoReading => '컨트롤러가 위치를 보고하기를 기다리는 중…';
	@override String get rotatorNotResponding => '응답 없음';
	@override String rotatorHeldAtLimit({required Object heading}) => '이 로테이터의 한계 내에서 ${heading}(으)로 회전 중';
	@override String get rotatorTargetAzimuth => '방위각으로 회전';
	@override String get rotatorTargetAzimuthShort => 'AZ로 회전';
	@override String get rotatorTargetElevation => '앙각으로 회전';
	@override String get rotatorTargetElevationShort => 'EL로 회전';
	@override String get rotatorAzimuthInvalid => '0에서 360 사이여야 합니다';
	@override String get rotatorElevationInvalid => '0에서 180 사이여야 합니다';
	@override String get rotatorTurn => '회전';
	@override String get rotatorStop => '정지';
	@override String get configUnreadable => '이 무전기의 저장된 설정을 읽을 수 없습니다. 설정을 열어 다시 입력하거나, 제거한 후 다시 추가하세요.';
	@override String get autoConnectHeld => '지난번 이 무전기에 연결했을 때 HaLo가 응답을 멈췄기 때문에 이번에는 자동으로 연결하지 않았습니다. 다시 시도하려면 연결을 누르세요.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$ko extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '오프라인 데이터';
	@override String get noFiles => '데이터 파일 없음';
	@override String get noFilesDescription => '활동 또는 조회 확장 기능을 활성화하면 여기서 오프라인 데이터를 다운로드할 수 있습니다.';
	@override String get refresh => '새로고침';
	@override String get refreshing => '새로고침 중…';
	@override String get updateAll => '모두 업데이트';
	@override String get updatingAll => '모든 데이터 파일 업데이트 중…';
	@override String get neverDownloaded => '다운로드한 적 없음';
	@override String get updatedJustNow => '방금 업데이트됨';
	@override String updatedDaysAgo({required Object days}) => '${days}일 전 업데이트됨';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => '${days}일 ${hours}시간 전 업데이트됨';
	@override String updatedHoursAgo({required Object hours}) => '${hours}시간 전 업데이트됨';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => '${hours}시간 ${minutes}분 전 업데이트됨';
	@override String updatedMinutesAgo({required Object minutes}) => '${minutes}분 전 업데이트됨';
	@override String lastDownloadRefused({required Object existing, required Object imported}) => '마지막 다운로드에는 기록이 ${existing}개 중 ${imported}개뿐이어서 사용하지 않았습니다. 받아들이려면 새로고침하세요.';
	@override String get extensionsSection => '확장 기능';
}

// Path: settings.profiles
class _Translations$settings$profiles$ko extends Translations$settings$profiles$en {
	_Translations$settings$profiles$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get notSet => '설정되지 않음';
	@override String get personalInfo => '개인 정보';
	@override String get personalInfoNote => '제출에 필요한 경우 생성된 로그에 포함될 수 있습니다';
	@override String get name => '이름';
	@override String get email => '이메일';
	@override String get club => '클럽';
	@override String get arrlSection => 'ARRL 섹션';
	@override String get racSection => 'RAC 섹션';
	@override String get section => '섹션';
}

// Path: settings.search
class _Translations$settings$search$ko extends Translations$settings$search$en {
	_Translations$settings$search$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get clear => '지우기';
	@override String get hint => '환경설정 검색';
}

// Path: settings.developer
class _Translations$settings$developer$ko extends Translations$settings$developer$en {
	_Translations$settings$developer$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => '개발자 경고, 디버그 로그 및 도구 활성화.';
	@override String get experiments => '실험기능';
	@override String get showIdleMetrics => '유휴 지표 표시';
	@override String get showIdleMetricsDescription => '지난 1초 동안 확장 기능 엔진이 얼마나 유휴 상태였는지 상태 표시줄에 표시합니다. 탭하면 10초 및 60초 평균을 볼 수 있습니다.';
	@override String idleMetricsReadout({required Object percent}) => '유휴 ${percent}%';
	@override String get idleMetricsAverages => '유휴 평균:';
	@override String idleMetricsWindow({required Object seconds, required Object percent}) => '${seconds}초 ${percent}%';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}개 활성화됨',
		other: '${count}개 활성화됨',
	);
	@override String get patchTrack => '코드 푸시 트랙';
	@override String get patchTrackDescription => '이 기기가 따르는 무선(OTA) 코드 푸시 링. 모험적인 링일수록 수정 사항을 더 빨리 받지만 테스트가 덜 되어 있습니다. 코드 푸시는 다음 재시작 시 적용됩니다.';
	@override String get trackStable => '안정';
	@override String get trackUnstable => '불안정';
	@override String get trackBleeding => '최신';
	@override String checkingTrack({required Object track}) => '"${track}"에서 코드 푸시 확인 중…';
	@override String get patchDownloaded => '코드 푸시를 다운로드했습니다. 적용하려면 앱을 다시 시작하세요.';
	@override String noNewPatch({required Object track}) => '"${track}"에 새 코드 푸시가 없습니다.';
	@override String get noPatchInstalled => '설치된 코드 푸시 없음 — 릴리스 바이너리 실행 중.';
	@override String runningPatch({required Object patch}) => '코드 푸시 #${patch} 실행 중.';
	@override String get deepLinks => '딥 링크';
	@override String get registerUrlSchemes => 'URL 스킴 등록';
	@override String get registerUrlSchemesDescription => 'com.ham2k:// 링크가 이 앱을 열도록 허용';
	@override String get registerUrlSchemesDone => '이제 이 앱이 com.ham2k:// 링크를 엽니다';
	@override String registerUrlSchemesFailed({required Object error}) => '등록할 수 없습니다: ${error}';
	@override String get systemInformation => '시스템 정보';
	@override String get appVersion => '앱 버전';
	@override String get dataFolder => '데이터 폴더';
	@override String get loading => '(로딩 중…)';
	@override String get panelLoadFailed => '이 설정 패널을 불러올 수 없습니다.';
	@override String get extDevServer => '확장 기능 개발 서버';
	@override String get extensionSettings => '확장 기능 설정';
	@override String get extDevServerDescription => '앱에 내장된 확장 기능 대신 네트워크의 개발 서버에서 확장 기능을 불러오고, 저장할 때마다 다시 불러옵니다.';
	@override String get extDevServerAddress => '서버 주소';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => '연결';
	@override String get extDevServerDisconnect => '연결 해제';
	@override String get extDevServerConnecting => '연결 중…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '확장 기능 ${count}개 제공 중: ${keys}',
		other: '확장 기능 ${count}개 제공 중: ${keys}',
	);
	@override String get extDevServerDisconnected => '연결 안 됨';
	@override String get extDevServerReconnect => '실행 시 다시 연결';
	@override String extDevServerLastReload({required Object time, required Object key}) => '마지막 다시 불러오기: ${time}에 ${key}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '확장 기능 ${count}개 빌드 실패',
		other: '확장 기능 ${count}개 빌드 실패',
	);
	@override String get catalog => '확장 기능 카탈로그';
	@override String get catalogDescription => '다른 서버에서 카탈로그를 읽습니다. 카탈로그 자체를 작업할 때는 로컬 서버를 사용하세요. 비워 두면 catalog.ham2k.net을 사용합니다.';
	@override String get catalogAddress => '카탈로그 주소';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => '카탈로그 검색 트랙';
	@override String get catalogSearchStable => '안정만';
	@override String get catalogSearchUnstable => '불안정 이상';
	@override String get catalogSearchBleeding => '최신 이상';
}

// Path: settings.about
class _Translations$settings$about$ko extends Translations$settings$about$en {
	_Translations$settings$about$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get notices => '공지 및 메시지';
	@override String get noticesDescription => '공지 사항 및 상태 메시지';
	@override String get releaseNotes => '릴리스 노트';
	@override String get copiedVersion => '버전 정보를 클립보드에 복사했습니다';
}

// Path: settings.panels
class _Translations$settings$panels$ko extends Translations$settings$panels$en {
	_Translations$settings$panels$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get settings => '앱 환경설정';
	@override String get settingsDescription => '원하는 대로 앱 설정하기';
	@override String get commonSettings => '일반 환경설정';
	@override String get syncDescription => '로그를 백업하고 여러 기기 간에 동기화';
	@override String get accountsDescription => '서비스 인증 정보, 오프라인 데이터 등';
	@override String get extensions => '확장 기능 및 앱 기능';
	@override String get extensionsDescription => '활동, 컨테스트, 대시보드 패널 및 기타 기능';
	@override String get profilesDescription => '오퍼레이터 콜사인 및 무선국 프로필';
	@override String get stationProfiles => '무선국 프로필';
	@override String get developerSettings => '개발자 설정';
	@override String get developerSettingsDescription => '디버깅 및 개발 도구';
	@override String get about => '정보';
	@override String get aboutDescription => '버전, 크레딧 및 법적 정보';
	@override String get unavailableTitle => '일부 설정을 사용할 수 없습니다';
	@override String get unavailableText => '확장 기능 런타임이 시작되지 않아 확장 기능이 제공하는 설정이 없습니다.';
	@override String get station => '무선국 구성';
	@override String get stationDescription => 'CAT 제어 및 기타 옵션';
	@override String get peers => '피어 기기';
	@override String get peersDescription => '근처의 다른 기기와 연결';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$ko extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get six => '6자리 (FN31pr)';
	@override String get eight => '8자리 (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$ko extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get six => '6자리';
	@override String get eight => '8자리';
}

// Path: keyboardShortcuts.command
class _Translations$keyboardShortcuts$command$ko extends Translations$keyboardShortcuts$command$en {
	_Translations$keyboardShortcuts$command$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get commandDialog => '명령 대화 상자 열기';
	@override String get toggleTheme => '라이트/다크 전환';
	@override String get toggleLanguage => '영어/스페인어 전환';
	@override String get fontScaleUp => '글자 크게';
	@override String get fontScaleDown => '글자 작게';
	@override String get fontScaleReset => '글자 크기 표준으로';
	@override String get densityLooser => '레이아웃 여유 있게';
	@override String get densityDenser => '레이아웃 조밀하게';
	@override String get densityAuto => '레이아웃 밀도 자동';
	@override String get find => '로그에서 찾기';
	@override String keyerMessage({required Object n}) => '메시지 ${n} 전송';
	@override String get keyboardMode => '키보드 모드 켜기/끄기';
	@override String get ptt => 'PTT (눌러서 송신)';
	@override String get wipe => '입력 중인 교신 지우기';
}

// Path: keyboardShortcuts.fixed
class _Translations$keyboardShortcuts$fixed$ko extends Translations$keyboardShortcuts$fixed$en {
	_Translations$keyboardShortcuts$fixed$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get callsign => '콜사인 입력';
	@override String get escape => '전송 중지, 한 단계 뒤로, 또는 닫기';
	@override String get enter => '교신 로깅';
	@override String get space => '다음 필드';
	@override String get tab => '다음 또는 이전 필드';
	@override String get arrows => '필드, 컨트롤, 로그 사이 이동';
	@override String get walk => '로그 페이지 넘기기 또는 처음/끝으로 이동';
	@override String get undo => '지우기 또는 삭제 되돌리기';
}

// Path: keyboardShortcuts.editor
class _Translations$keyboardShortcuts$editor$ko extends Translations$keyboardShortcuts$editor$en {
	_Translations$keyboardShortcuts$editor$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get addShortcut => '단축키 추가';
	@override String get listening => '단축키로 쓸 키를 누르세요…';
	@override String get listeningHint => 'Esc를 누르면 중단합니다';
	@override String get add => '추가';
	@override String refusedFixed({required Object keys}) => '${keys}은(는) 로깅 필드나 대화 상자에서 쓰이므로 변경할 수 없습니다.';
	@override String refusedCallsign({required Object keys}) => '${keys}은(는) 콜사인을 입력하는 키입니다. Cmd, Ctrl 또는 Alt와 함께 누르세요.';
	@override String reserved({required Object keys}) => '시스템이 ${keys}을(를) 앱보다 먼저 가로챌 수 있습니다.';
	@override String already({required Object keys}) => '${keys}은(는) 이미 이 명령에 할당된 키입니다.';
	@override String takeIt({required Object command, required Object keys}) => '“${command}”에서 ${keys} 가져오기';
	@override String get resetDefault => '기본값으로 초기화';
	@override String get remove => '제거';
	@override String get commandLabel => '명령';
	@override String get commandHint => '유효한 명령을 입력하거나, 여러 명령을 ";"로 구분해 입력하세요';
	@override String get removeCommand => '명령 제거';
	@override String commandUnknown({required Object text}) => '“${text}”을(를) 인식하는 명령이 없습니다';
	@override String get noShortcuts => '아직 키 없음';
}

// Path: keyboardShortcuts.file
class _Translations$keyboardShortcuts$file$ko extends Translations$keyboardShortcuts$file$en {
	_Translations$keyboardShortcuts$file$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String exported({required Object location}) => '단축키를 ${location}에 저장했습니다';
	@override String exportFailed({required Object error}) => '단축키를 내보낼 수 없습니다: ${error}';
	@override String importPickerFailed({required Object error}) => '파일을 열 수 없습니다: ${error}';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename}은(는) 이 앱이 읽을 수 있는 단축키 파일이 아닙니다: ${problem}';
	@override String problemNotYaml({required Object line}) => '올바른 YAML이 아님 (${line}행)';
	@override String get problemNotKeysFile => 'Ham2K 키보드 단축키 파일이 아님';
	@override String get problemNewerVersion => '더 새로운 버전의 앱에서 작성됨';
	@override String get problemMalformed => '일부가 단축키 형식에 맞지 않음';
	@override String get problemTooLarge => '너무 큼';
	@override String get importTitle => '단축키 가져오기';
	@override String writtenOn({required Object platform}) => '${platform}에서 작성됨.';
	@override String get writtenOnUnknown => '이 파일에는 어떤 키보드에서 작성되었는지 적혀 있지 않습니다.';
	@override String get translate => '이 키보드에서는 다음 키를 각각 어떤 키로 할까요?';
	@override String get leaveOut => '해당 단축키 제외';
	@override String get replace => '이 기기의 설정 대체';
	@override String get replaceHint => '파일에 없는 모든 단축키는 기본값으로 돌아갑니다.';
	@override String get merge => '이 기기의 설정에 추가';
	@override String get mergeHint => '같은 명령에 대해서는 파일의 단축키가 이 기기의 단축키를 대체하고, 나머지는 그대로 유지됩니다.';
	@override String unknown({required Object commands}) => '이 버전에 없는 명령이어서 제외됨: ${commands}';
	@override String unreadableChords({required Object chords}) => '단축키가 아니어서 제외됨: ${chords}';
	@override String refusedChords({required Object chords}) => '앱이 직접 쓰는 키여서 제외됨: ${chords}';
	@override String conflicts({required Object keys}) => '가져온 후 둘 이상의 명령에 할당됨: ${keys}';
	@override String get importAction => '가져오기';
	@override String get imported => '단축키를 가져왔습니다';
}

// Path: keyboardShortcuts.modifier
class _Translations$keyboardShortcuts$modifier$ko extends Translations$keyboardShortcuts$modifier$en {
	_Translations$keyboardShortcuts$modifier$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get cmd => '⌘ Command';
	@override String get ctrl => 'Ctrl';
	@override String get meta => 'Windows / Super';
}

// Path: keyboardShortcuts.platform
class _Translations$keyboardShortcuts$platform$ko extends Translations$keyboardShortcuts$platform$en {
	_Translations$keyboardShortcuts$platform$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get macos => 'macOS';
	@override String get ios => 'iPadOS';
	@override String get windows => 'Windows';
	@override String get linux => 'Linux';
	@override String get android => 'Android';
}

// Path: home.logs.sheet
class _Translations$home$logs$sheet$ko extends Translations$home$logs$sheet$en {
	_Translations$home$logs$sheet$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get callsigns => '무선국 콜사인';
	@override String get groupBy => '그룹 기준';
	@override String get period => '기간';
}

// Path: home.logs.groupBy
class _Translations$home$logs$groupBy$ko extends Translations$home$logs$groupBy$en {
	_Translations$home$logs$groupBy$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get none => '그룹 없음';
	@override String get date => '날짜';
	@override String get dx => 'DX';
	@override String get unknownContinent => '알 수 없는 대륙';
	@override String get unknownEntity => '알 수 없는 엔티티';
	@override String get unknownDate => '날짜 없음';
}

// Path: home.logs.period
class _Translations$home$logs$period$ko extends Translations$home$logs$period$en {
	_Translations$home$logs$period$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get thisMonth => '이번 달';
	@override String get last3Months => '최근 3개월';
	@override String get thisYear => '올해';
	@override String get lastYear => '작년';
	@override String get allTime => '전체 기간';
	@override String get custom => '사용자 지정 범위';
}

// Path: home.logs.periodTitle
class _Translations$home$logs$periodTitle$ko extends Translations$home$logs$periodTitle$en {
	_Translations$home$logs$periodTitle$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String inSpan({required Object span}) => '(${span})';
	@override String get custom => '사용자 지정 범위';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$ko extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get date => '날짜';
	@override String get time => '시간';
	@override String get freq => '주파수';
	@override String get mode => '모드';
	@override String get call => '콜사인';
	@override String get name => '이름';
	@override String get station => '무선국';
	@override String get band => '밴드';
	@override String get sent => '보냄';
	@override String get rcvd => '받음';
	@override String get grid => '그리드';
	@override String get state => '주';
	@override String get country => '국가';
	@override String get refs => '레퍼런스';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$ko extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'QSO 로그';
	@override String get qsosDescription => '선택한 콜사인의 모든 운용에 걸친 QSO.';
	@override String get info => '정보';
	@override String get infoDescription => '전체 QSO 수 또는 선택한 QSO의 콜사인 조회 결과.';
	@override String get map => '지도';
	@override String get mapDescription => '선택한 QSO의 위치.';
}

// Path: home.logs.import
class _Translations$home$logs$import$ko extends Translations$home$logs$import$en {
	_Translations$home$logs$import$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => '콜사인: ${calls}';
	@override String get skippedOne => '기록 1개를 읽을 수 없습니다';
	@override String skippedOther({required Object count}) => '기록 ${count}개를 읽을 수 없습니다';
	@override String get readingTitle => 'ADIF 파일 읽는 중…';
	@override String get checkingTitle => '중복 확인 중…';
	@override String get importingTitle => 'QSO 가져오는 중…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object total, required Object done}) => '${total}개 중 ${done}개 확인됨';
	@override String importingDetail({required Object total, required Object imported}) => '${total}개 중 ${imported}개 가져옴';
}

// Path: operation.layout.layouts
class _Translations$operation$layout$layouts$ko extends Translations$operation$layout$layouts$en {
	_Translations$operation$layout$layouts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get defaultName => '기본';
	@override String untitledName({required Object number}) => '레이아웃 ${number}';
	@override String switcherLabel({required Object name}) => '레이아웃: ${name}';
	@override String get menuNew => '새로 만들기…';
	@override String get menuExport => '내보내기…';
	@override String get menuImport => '가져오기…';
	@override String get menuTitle => '레이아웃';
	@override String get newTitle => '새 레이아웃';
	@override String get editTitle => '레이아웃 편집';
	@override String get edit => '편집';
	@override String get duplicateCurrent => '현재 레이아웃 복제';
	@override String get startFromDefault => '기본 레이아웃에서 시작';
	@override String get nameLabel => '이름';
	@override String get descriptionLabel => '설명';
	@override String get create => '만들기';
	@override String leaveEditTitle({required Object name}) => '"${name}"의 변경 사항을 저장할까요?';
	@override String get leaveEditBody => '이 레이아웃에 저장하지 않은 변경 사항이 있습니다.';
	@override String get discard => '버리기';
	@override String get deleteTitle => '이 레이아웃을 삭제할까요?';
	@override String deleteBody({required Object name}) => '"${name}" 레이아웃을 정말 삭제할까요?';
	@override String get exportTitle => '레이아웃 내보내기';
	@override String get exportPick => '내보낼 패널';
	@override String get tabSet => '탭 그룹';
	@override String get exportAction => '내보내기';
	@override String exported({required Object location}) => '레이아웃을 ${location}에 저장했습니다';
	@override String exportFailed({required Object error}) => '레이아웃을 내보낼 수 없습니다: ${error}';
	@override String get importTitle => '레이아웃 가져오기';
	@override String importFromOtherView({required Object view}) => '${view} 화면용 레이아웃입니다. 그 화면에만 있는 패널은 제외됩니다.';
	@override String get viewHome => '홈';
	@override String get viewOperation => '운용';
	@override String get viewLogs => '로그';
	@override String get viewChase => '추적';
	@override String get importAsNew => '새 레이아웃으로';
	@override String get importReplace => '이 레이아웃을 대체';
	@override String get importAdd => '이 레이아웃에 추가';
	@override String get importAddHint => '패널이 오른쪽의 새 열에 추가됩니다.';
	@override String get importPick => '가져올 패널';
	@override String get importReplaceSettings => '여기에 이미 설정된 패널의 설정을 대체';
	@override String get importAction => '가져오기';
	@override String importUnreadable({required Object filename, required Object problem}) => '${filename}은(는) 이 앱이 읽을 수 있는 레이아웃이 아닙니다: ${problem}';
	@override String problemNotYaml({required Object line}) => '텍스트가 올바른 YAML이 아닙니다 (${line}행)';
	@override String get problemNotLayoutFile => 'Ham2K 레이아웃 파일이 아닙니다';
	@override String get problemNewerVersion => '더 새로운 버전의 앱에서 작성되었습니다';
	@override String get problemNoArrangement => '배치 정보가 없습니다';
	@override String get problemMalformed => '일부가 레이아웃 형식에 맞지 않습니다';
	@override String get problemTooLarge => '너무 큽니다';
	@override String importPickerFailed({required Object error}) => '파일을 열 수 없습니다: ${error}';
	@override String importFailed({required Object error}) => '레이아웃을 가져올 수 없습니다: ${error}';
	@override String duplicateFailed({required Object error}) => '레이아웃을 복사할 수 없습니다: ${error}';
	@override String get importNothing => '선택한 패널이 없어 아무것도 가져오지 않았습니다.';
	@override String importSkipped({required Object panels}) => '제외됨: ${panels}';
	@override String importKeptPinned({required Object panels}) => '${panels}은(는) 유지됨: 작은 화면 배치에 꼭 필요합니다.';
	@override String get notOffered => '이 화면에서는 사용할 수 없음';
	@override String get alreadyPlaced => '이미 이 레이아웃에 있음';
	@override String needsExtension({required Object name}) => '${name} 필요';
	@override String get listRecoveredTitle => '레이아웃 이름을 읽을 수 없습니다';
	@override String get listRecoveredBody => '이 화면의 레이아웃 목록을 읽을 수 없습니다. 모든 레이아웃은 그대로 있으며, 이름 대신 번호로 표시됩니다.';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$ko extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => '로그와 입력 필드';
	@override String get infoDescription => '교신 중인 무선국에 대한 정보';
	@override String get spotsDescription => '클러스터와 활동 프로그램의 스팟';
	@override String get mapDescription => '교신 상대의 위치';
	@override String get summariesDescription => '운용 통계와 점수를 원하는 섹션과 순서로 표시';
	@override String get summariesSections => '섹션 및 순서';
	@override String get summariesDays => '일별';
	@override String get summariesReset => '모두 표시';
	@override String get summariesAllHidden => '모든 섹션이 숨겨져 있습니다. 패널 설정에서 표시할 섹션을 선택하세요.';
	@override String get clockDescription => '원하는 시간대의 시계';
	@override String get clockFace => '시계 모양';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => '아날로그';
	@override String get clockZone => '시간대';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => '이 기기';
	@override String get clockShowSeconds => '초 표시';
	@override String get weatherDescription => '운용 위치의 현재 및 향후 8시간 날씨';
	@override String get weatherUseOperationLocation => '운용 위치 사용';
	@override String get weatherLocation => '위치';
	@override String get weatherLocationDescription => '그리드 스퀘어(FN31pr) 또는 위도,경도. \'운용 위치 사용\'이 선택되어 있으면 무시됩니다.';
	@override String get weatherNoLocation => '위치가 설정되지 않았습니다. 패널 설정에서 위치를 지정하거나, 위치가 있는 운용 안에 패널을 배치하세요.';
	@override String weatherBadLocation({required Object location}) => '위치 ${location}을(를) 읽을 수 없습니다. FN31pr 같은 그리드 스퀘어나 42.36,-71.06 형식을 사용하세요.';
	@override String get weatherUnreachable => 'Open-Meteo에 연결할 수 없습니다. 네트워크가 없나요? 잠시 후 다시 시도합니다.';
	@override String get weatherUnreadable => 'Open-Meteo가 응답했지만 읽을 수 있는 내용이 아닙니다. 잠시 후 다시 시도합니다.';
	@override String weatherGusts({required Object speed}) => '돌풍 ${speed}';
	@override String get panelAgeNow => '방금';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}분 전',
		other: '${count}분 전',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '${count}시간 전',
		other: '${count}시간 전',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$ko weatherConditions = _Translations$operation$layout$panels$weatherConditions$ko._(_root);
	@override String get websiteDescription => '원하는 웹 페이지를 패널에 표시';
	@override String get websiteUrl => '주소';
	@override String get websiteRefresh => '새로고침';
	@override String get websiteRefreshNever => '안 함';
	@override String get websiteRefresh1 => '1분마다';
	@override String get websiteRefresh5 => '5분마다';
	@override String get websiteRefresh15 => '15분마다';
	@override String get websiteTitle => '패널 이름';
	@override String get websiteRefreshNow => '지금 새로고침';
	@override String get websiteNoUrl => '아직 주소가 없습니다. 패널 설정을 열어 페이지를 선택하세요.';
	@override String get websiteBadUrl => '웹 주소가 아닌 것 같습니다. https:// 로 시작해야 합니다';
	@override String get websiteNotHttps => '여기에는 https:// 주소만 표시할 수 있습니다.';
	@override String get websiteUnsupported => '이 시스템에서는 패널에 웹 페이지를 표시할 수 없습니다.';
	@override String get websiteOpenExternally => '브라우저에서 열기';
	@override String websiteLoadFailed({required Object reason}) => '페이지를 불러올 수 없습니다: ${reason}';
	@override String get remoteScreenDescription => '다른 기기에서 공유하는 화면, 앱 또는 창.';
	@override String get remoteScreenTarget => '화면';
	@override String get remoteScreenChoose => '화면 선택…';
	@override String get remoteScreenPickerTitle => '공유된 화면';
	@override String get remoteScreenPickerEmpty => '화면을 공유 중인 기기가 없습니다. 보려는 기기에서 설정 → 피어 기기의 화면 및 창 공유를 켜세요.';
	@override String get remoteScreenUnset => '선택된 화면이 없습니다. 패널 설정을 열어 다른 기기가 공유 중인 화면을 선택하세요.';
	@override String get remoteScreenConnecting => '연결 중…';
	@override String get remoteScreenPeerAway => '해당 기기가 지금 연결되어 있지 않습니다.';
	@override String get remoteScreenNotOffered => '해당 기기가 이 화면 공유를 중지했습니다.';
	@override String get remoteScreenNoListener => '해당 기기가 연결을 받을 수 없습니다. 방화벽을 확인하세요.';
	@override String get remoteScreenNoLan => '화면은 블루투스가 아닌 로컬 네트워크로만 공유됩니다.';
	@override String get remoteScreenRefused => '해당 기기가 이 화면 공유를 거부했습니다.';
	@override String get remoteScreenSettings => '패널 설정';
	@override String get remoteScreenAdjust => '화면 조정';
	@override String get remoteScreenDetail => '화질';
	@override String get remoteScreenDetailStandard => '표준';
	@override String get remoteScreenDetailHigh => '높음';
	@override String get remoteScreenDetailMaximum => '최대';
	@override String get remoteScreenAdjustDone => '확인';
	@override String get remoteScreenZoomIn => '확대';
	@override String get remoteScreenZoomOut => '축소';
	@override String get remoteScreenStopped => '해당 화면 또는 창이 더 이상 표시되지 않습니다.';
	@override String get remoteScreenCaptureFailed => '해당 기기가 화면을 캡처할 수 없습니다. 화면 기록 권한이 필요할 수 있습니다.';
	@override String get remoteScreenNoAnswer => '해당 기기가 응답하지 않았습니다. 화면 공유가 켜져 있지 않을 수 있습니다.';
	@override String get remoteScreenNoMedia => '화면 전송용 연결을 열 수 없습니다. 이 기기의 방화벽을 확인하세요.';
	@override String get solarDescription => '태양 및 지자기 상태와 밴드별 전파 상황';
	@override String get solarUnreachable => 'hamqsl.com에 연결할 수 없습니다. 네트워크가 없나요? 잠시 후 다시 시도합니다.';
	@override String get solarUnreadable => 'hamqsl.com이 응답했지만 사용할 수 있는 값이 아닙니다. 잠시 후 다시 시도합니다.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => '주간';
	@override String get solarBandNight => '야간';
	@override String get solarBandGood => '좋음';
	@override String get solarBandFair => '보통';
	@override String get solarBandPoor => '나쁨';
	@override String solarSources({required Object primary, required Object secondary}) => '출처: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => '연결이 불안정합니다. 프레임을 건너뛰는 중입니다.';
	@override String get remoteScreenStalled => '프레임이 전달되지 않습니다. 연결이 너무 느릴 수 있습니다.';
	@override String get radioDescription => 'CAT으로 제어하는 무전기 전면 패널 — 주파수, 모드, 출력';
	@override String get radioStyle => '스타일';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => '모던';
	@override String get radioRadio => '무전기';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — 지정된 무전기 없음';
	@override String get radioNoRadio => '표시할 무전기가 없습니다. 패널 설정에서 선택하거나 무선국 구성에서 추가하세요.';
	@override String get radioNotConfigured => '이 무전기가 아직 구성되지 않았습니다. 무선국 구성에서 포트 또는 주소를 선택하세요.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => '무전기 연결 안 됨';
	@override String get radioWatts => 'W';
	@override String get radioConnect => '이 무전기 연결';
	@override String get radioDisconnect => '이 무전기 연결 해제';
	@override String get radioStale => '데이터 없음';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR 높음';
	@override String get rotatorDescription => '무선국을 중심으로 한 지도에 안테나 방향을 표시합니다. 지도를 탭하면 회전합니다.';
	@override String get rotatorRotator => '로테이터';
	@override String rotatorAutoNamed({required Object name}) => '자동 — ${name}';
	@override String get rotatorAutoNone => '자동 — 아직 로테이터 없음';
	@override String get rotatorBeamWidth => '빔 폭';
	@override String get rotatorBeamWidthDescription => '도 단위로, 방위 주위에 그려집니다. 0이면 그리지 않습니다.';
	@override String get rotatorLocation => '위치';
	@override String get rotatorLocationDescription => '지도의 중심이 될 그리드 스퀘어 또는 위도와 경도. 비워 두면 운용 위치를 사용합니다.';
	@override String get rotatorTheme => '테마';
	@override String get rotatorThemeColor => '컬러';
	@override String get rotatorThemeGray => '회색';
	@override String get rotatorThemeMuted => '차분한 색';
	@override String get rotatorGrayline => '그레이라인 표시';
	@override String get rotatorNoRotator => '표시할 로테이터가 없습니다. 패널 설정에서 선택하거나 무선국 구성에서 추가하세요.';
	@override String get rotatorNoLocation => '지도의 중심으로 삼을 위치가 없습니다. 패널 설정에서 설정하세요.';
	@override String get rotatorDisconnected => '연결 끊김';
	@override String get rotatorNoReading => '—';
	@override String get rotatorNotResponding => '응답 없음';
	@override String get rotatorLocationInvalid => '패널 설정의 위치를 읽을 수 없습니다. 그리드 스퀘어나 40.7, -74.0 같은 위도와 경도를 사용하세요.';
	@override String rotatorElevation({required Object degrees}) => 'EL ${degrees}°';
	@override String get rotatorNorth => 'N';
	@override String get rotatorEast => 'E';
	@override String get rotatorSouth => 'S';
	@override String get rotatorWest => 'W';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$ko extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '짧은 파일명 사용';
	@override String get descriptionOn => '업로드 도구용 짧은 이름, 예: N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => '읽기 쉬운 이름, 예: 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$ko extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '비공개 정보 포함';
	@override String get descriptionOn => '이름, 주소, 이메일, 그리드 스퀘어 및 메모가 포함됩니다';
	@override String get descriptionOff => '이름, 주소, 이메일, 그리드 스퀘어 및 메모가 제외됩니다';
	@override String get note => '전체 ADIF 내보내기에는 항상 모든 정보가 포함됩니다';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$ko extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => '먼저 이메일 주소를 추가하세요';
	@override String get needsEmailBody => 'Ham2K File Stash는 LoFi 계정의 이메일 주소로 파일을 보내며, stash.ham2k.net에서 그 주소로 로그인합니다. 계정에 아직 확인된 이메일이 없습니다. 설정 › 클라우드 동기화에서 추가하세요.';
	@override String get openSyncSettings => '클라우드 동기화 열기';
	@override String get replaceTitle => '최근 보관 항목이 대체됩니다';
	@override String replaceBody({required Object name}) => '“${name}”을(를) 보낸 지 6시간이 지나지 않았고 아직 다운로드되지 않았습니다. 무료 계정은 한 번에 하나만 보관할 수 있으므로, 지금 보내면 기존 파일이 대체됩니다.';
	@override String get replaceConfirm => '어쨌든 보내기';
	@override String get failedTitle => 'Ham2K File Stash로 보낼 수 없습니다';
	@override String get sentTitle => 'Ham2K File Stash로 보냈습니다';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '어떤 브라우저에서든 **[stash.ham2k.net](https://stash.ham2k.net)** 에 접속하면 이 파일을 가져올 수 있습니다.',
		other: '어떤 브라우저에서든 **[stash.ham2k.net](https://stash.ham2k.net)** 에 접속하면 이 파일들을 가져올 수 있습니다.',
	);
	@override String get mayHaveArrived => 'File Stash에서 응답이 없습니다. 파일이 도착했을 수도 있습니다. 다시 보내기 전에 stash.ham2k.net을 확인하세요';
	@override String get notSent => '보내지 않음';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: '이 파일이 도착하지 않았습니다:',
		other: '다음 파일 ${count}개가 도착하지 않았습니다:',
	);
	@override String get emailOffer => '또는 해당 링크를 이메일로 보내 드릴 수 있습니다.';
	@override String get emailMe => '링크를 이메일로 받기';
	@override String get emailSent => '다운로드 링크를 이메일로 보냈습니다.';
	@override String emailFailed({required Object error}) => '이메일을 보낼 수 없습니다: ${error}';
	@override String get freeTier => '무료 계정은 한 번에 하나만 보관할 수 있습니다. 구독자는 원하는 만큼 보관할 수 있습니다.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count,
		one: 'Ham2K File Stash(stash.ham2k.net)로 파일 ${count}개를 보냈습니다',
		other: 'Ham2K File Stash(stash.ham2k.net)로 파일 ${count}개를 보냈습니다',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$ko extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get af => '아프리카';
	@override String get as => '아시아';
	@override String get eu => '유럽';
	@override String get na => '북미';
	@override String get oc => '오세아니아';
	@override String get sa => '남미';
	@override String get an => '남극';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$ko extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스팟 필터';
	@override String get band => '밴드';
	@override String get mode => '모드';
	@override String get age => '경과시간';
	@override String get sources => '출처';
	@override String get continent => '대륙';
	@override String get sorting => '정렬';
	@override String get sortByTime => '스팟 시간 별';
	@override String get sortByFrequency => '주파수 별';
	@override String get sortByWanted => '필요도 순';
	@override String get groupByBand => '밴드별 그룹';
	@override String get groupCallsWithNotes => '메모가 있는 콜사인 우선';
	@override String get alertingOnly => '알림 있는 스팟만';
	@override String get sourceNoReply => '응답 없음';
	@override String get sourceError => '오류';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$ko extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '로깅 패널이 사용 중입니다';
	@override String get editingBody => '로깅된 교신을 수정하고 있습니다. 대신 이 스팟을 로깅할까요, 아니면 돌아가서 수정을 마칠까요?';
	@override String get composingBody => '교신 입력을 시작했습니다. 대신 이 스팟을 로깅할까요, 아니면 돌아가서 입력을 마칠까요?';
	@override String get goBack => '돌아가기';
	@override String get clearAndLog => '지우고 스팟 로깅';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$ko extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '왼손잡이 모드';
	@override String get descriptionOn => '왼손잡이용 레이아웃 사용';
	@override String get descriptionOff => '오른손잡이용 레이아웃 사용';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$ko extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '국가 깃발 표시';
	@override String get dx => 'DX 교신에만 표시';
	@override String get all => '모든 교신에 깃발 표시';
	@override String get none => '깃발 표시하지 않음';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$ko extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get dx => 'DX 교신에만 깃발 표시';
	@override String get all => '모든 교신에 깃발 표시 중';
	@override String get none => '깃발 표시하지 않음';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$ko extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '오퍼레이터 제안';
	@override String get descriptionOn => '운용의 무선국 콜사인이 다를 때 내 콜사인을 오퍼레이터로 제안';
	@override String get descriptionOff => '직접 입력하지 않으면 오퍼레이터를 비워 둠';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$ko extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '방위각 표시';
	@override String get descriptionOn => '무선국까지의 예상 방위각 표시';
	@override String get descriptionOff => '방위각 정보 표시하지 않음';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$ko extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '역방위각도 표시';
	@override String get descriptionOn => '무선국 기준 방위각도 "45° / 225°"처럼 표시';
	@override String get descriptionOff => '무선국까지의 방위각만 표시';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$ko extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '시그널 리포트 순서 변경';
	@override String get sentFirst => '보낸 RST -> 받은 RST';
	@override String get rcvdFirst => '받은 RST -> 보낸 RST';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$ko extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'RST 입력 후 다음 필드로 자동 점프';
	@override String get descriptionOn => 'RST 입력 후 다음 필드로 이동';
	@override String get descriptionOff => '자동으로 이동하지 않음';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$ko extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '기본 리포트 — 보이스';
	@override String get description => 'SSB, FM 또는 AM에서 보냄 또는 받음이 비어 있을 때 사용';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$ko extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '기본 리포트 — CW 및 데이터';
	@override String get description => 'CW, RTTY 및 기타 데이터 모드에서 보냄 또는 받음이 비어 있을 때 사용';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$ko extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '기본 리포트 — FT8 및 FT4';
	@override String get description => 'FT 모드에서 보냄 또는 받음이 비어 있을 때 사용';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$ko extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '숫자 키보드';
	@override String get description => '로깅 중 키보드 위에 숫자 키 행 표시';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$ko extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '슬래시 및 마침표 키';
	@override String get description => '상황에 맞는 키 추가: 콜사인에는 “/”, 숫자에는 “.”';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$ko extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '키 누를 때 진동';
	@override String get description => '숫자 키를 탭할 때 햅틱 피드백';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$ko extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get off => '비활성화됨';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.cluster.errors
class _Translations$settings$cluster$errors$ko extends Translations$settings$cluster$errors$en {
	_Translations$settings$cluster$errors$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get noCall => '로그인할 오퍼레이터 콜사인이 없습니다';
	@override String get connectFailed => '노드에 연결할 수 없습니다';
	@override String get needsPassword => '노드가 비밀번호를 요구하지만 저장된 비밀번호가 없습니다';
	@override String get loginFailed => '노드가 로그인을 받아들이지 않았습니다';
	@override String get disconnected => '노드가 연결을 끊었습니다';
	@override String get timeout => '노드가 응답하지 않았습니다';
	@override String get off => '클러스터에 연결이 꺼져 있습니다';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$ko extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$ko extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '키보드로 PTT 제어';
	@override late final _Translations$settings$radio$pttKey$modes$ko modes = _Translations$settings$radio$pttKey$modes$ko._(_root);
	@override late final _Translations$settings$radio$pttKey$descriptions$ko descriptions = _Translations$settings$radio$pttKey$descriptions$ko._(_root);
	@override String get key => 'PTT 키';
	@override String get pill => 'TX';
	@override String get transmitting => '송신 중';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$ko extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스마트 VFO 스냅';
	@override String get descriptionOn => '다이얼을 멈추면 주파수를 적절한 단위로 반올림합니다. 보이스 모드에만 적용됩니다.';
	@override String get descriptionOff => '튜닝한 주파수를 그대로 유지합니다.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$ko extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스마트 스냅: 안정 지연';
	@override String get description => '주파수를 반올림하기 전에 다이얼이 멈춰 있어야 하는 시간. 짧으면 즉시 반응하고, 길면 천천히 돌릴 여유가 생깁니다.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$ko extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스마트 스냅: 긴 이동';
	@override String get description => '이 이상 이동하면 마지막에 얼마나 천천히 돌렸든 주파수를 kHz 단위로 반올림합니다.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$ko extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스마트 스냅: 최소 이동';
	@override String get description => '이보다 적게 이동하면 주파수를 반올림하지 않으므로 미세 튜닝은 그대로 유지됩니다.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$ko extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스마트 스냅: 최저 속도';
	@override String get description => '다이얼을 이보다 천천히 돌리면 긴 이동이 아닌 한 주파수를 반올림하지 않습니다.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$ko extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM 꺼짐';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter로 메시지 전송';
	@override String get off => '꺼짐';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter로 메시지 전송: ${state}. 탭하여 변경.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$ko extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '키어 속도';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$ko extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => 'CW 키어 메시지';
	@override String get notSupported => '현재 무전기는 CW 키잉을 지원하지 않습니다';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => '메시지 ${n}';
	@override String get labelField => '레이블';
	@override String labelKey({required Object n}) => 'F${n} 레이블';
	@override String get details => '상세';
	@override String get empty => '(비어 있음)';
	@override String get sets => '메시지 세트';
	@override String get newSet => '새 세트';
	@override String get renameSet => '세트 이름 변경';
	@override String get deleteSet => '세트 삭제';
	@override String get newSetName => '이름';
	@override String get setDefault => '기본';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'ESM 메시지';
	@override String get setSaved => '내 메시지';
	@override String get repeat => '메시지 1 반복';
	@override String get repeatShort => 'M1 반복';
	@override String get cooldown => '반복 전 대기 시간';
	@override String cooldownSeconds({required Object n}) => '${n}초';
	@override String get repeatWait => '반복 중';
	@override String get keyboard => '입력하여 전송';
	@override String get keyboardField => '입력하여 전송';
	@override String get help => '도움말';
	@override String get helpTitle => 'CW 메시지 작성';
	@override String get helpIntro => '메시지에 다음 값을 사용하는 템플릿을 쓸 수 있습니다:';
	@override String get helpOpCall => '내 콜사인';
	@override String get helpQsoCall => '상대 콜사인 — // 스택에서는 로깅될 콜사인';
	@override String get helpQsoFullCall => '유효한 콜사인이면 상대 콜사인, 부분 콜사인이면 빈칸';
	@override String get helpQsoPartial => '부분 콜사인, 유효한 전체 콜사인이면 빈칸';
	@override String get helpQsoNextCall => '// 스택에서 다음에 로깅하도록 선택될 콜사인 (유효한 전체 콜사인인 경우)';
	@override String get helpQsoNextPartial => '// 스택에서 현재 교신을 로깅한 후의 다음 부분 콜사인';
	@override String get helpQsoName => '상대의 이름 (입력한 값, 없으면 조회 결과)';
	@override String get helpQsoState => '상대의 주 (입력한 값, 없으면 조회 결과)';
	@override String get helpKeyerMsg => '다른 메시지 안에서 전송될 메시지 1의 내용. 메시지 1~8에서 사용 가능';
	@override String get helpQsoRst => '보내는 리포트';
	@override String get helpQsoSerial => '시리얼 번호를 보내는 컨테스트에서의 내 시리얼 번호';
	@override String get helpPad => '해당 자릿수까지 0으로 채움: 7은 007로 전송';
	@override String get helpCut => '컷 넘버, 0은 T, 9는 N: 599는 5NN으로 전송';
	@override String get helpCutDigits => '컷할 숫자를 따옴표 안에 지정 — 0은 T, 1은 A, 5는 E, 9는 N';
	@override String get helpFullExample => '전체 예시:';
	@override String get helpExample => 'W1AW 5NN TT7 전송';
	@override String get helpEsmIntro => 'Enter로 메시지 전송이 켜져 있으면, N1MM처럼 Enter가 기능 키에 해당하는 메시지를 전송합니다. ESM 메시지 세트는 다음으로 시작합니다:';
	@override String get helpEsmCq => 'Run 중 콜사인 필드가 비어 있을 때 Enter를 누르면 CQ 호출';
	@override String get helpEsmExchange => '내 교환 정보: Run 중에는 상대 콜사인 뒤에, S&P에서는 상대가 응답한 뒤에';
	@override String get helpEsmThanks => '교신이 로깅된 후의 감사 인사: qso는 로깅된 교신, next는 다음 차례의 교신';
	@override String get helpEsmMyCall => 'S&P에서 응답하는 무선국에 보내는 내 콜사인';
	@override String get helpEsmHisCall => 'Run 중 내 교환 정보 앞에 보내는 상대 콜사인';
	@override String get helpEsmAgain => '상대의 교환 정보를 전혀 수신하지 못했을 때 다시 요청';
	@override String get helpEsmStackThanks => '// 스택용 추천 F3: 감사 인사 후 스택의 다음 무선국을 호출하고 교환 정보를 보내거나, 부분 콜사인을 되묻습니다 (TU KR?). 남은 것이 없으면 TU만 보냅니다';
}

// Path: settings.radio.keyerControl
class _Translations$settings$radio$keyerControl$ko extends Translations$settings$radio$keyerControl$en {
	_Translations$settings$radio$keyerControl$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get label => '키어';
	@override String get cw => 'WPM';
	@override String cwSpeed({required Object wpm}) => '${wpm} WPM';
	@override String get voice => '보이스';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$ko extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '보이스 키어 메시지';
	@override String get notSupported => '현재 무전기는 보이스 메시지를 지원하지 않습니다';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => '보이스 메모리 ${n}';
	@override String get labelField => '레이블';
	@override String labelKey({required Object n}) => '보이스 메모리 ${n} 레이블';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => '비어 있음';
	@override String get notMeasured => '길이 알 수 없음';
	@override String get playButton => '재생';
	@override String get recordButton => '녹음';
	@override String get stopButton => '정지';
	@override String get repeat => '메시지 1 반복';
	@override String recordHelpTitle({required Object model}) => '${model} 참고:';
	@override String namedOnDevice({required Object device}) => '이 메모리는 ${device}의 무전기에 있습니다. 이름과 길이는 해당 기기에 속합니다.';
	@override String get namedOnRadio => '무전기에 저장되어 다른 클라이언트에서도 볼 수 있습니다.';
	@override String get recordHelpYaesuDvs => '무전기에 [REC] 표시가 나타날 때까지 기다린 후, PTT 버튼을 누른 채 메시지를 녹음하세요. 원치 않는 클릭음을 피하려면 PTT를 놓기 전에 앱에서 정지 버튼을 눌러 녹음을 끝내세요.';
	@override String get recordHelpFt891 => '[REC] 표시가 최소 네 번 깜빡일 때까지 기다린 후, PTT 버튼을 누른 채 메시지를 녹음하세요. 원치 않는 클릭음을 피하려면 PTT를 놓기 전에 앱에서 정지 버튼을 눌러 녹음을 끝내세요.';
	@override String get pill => '보이스';
	@override String play({required Object n}) => '메모리 ${n} 재생';
	@override String get stop => '정지';
	@override String record({required Object n}) => '메모리 ${n} 녹음';
	@override String get stopRecording => '녹음 정지';
	@override String get playing => '재생 중…';
	@override String get recording => '녹음 중…';
	@override String recordingMemory({required Object label}) => '${label} 녹음 중';
	@override String get doubtful => '무전기가 재생했나요? 무전기가 곧바로 대기 상태라고 보고했습니다.';
	@override String get recordOnRadio => '메모리는 무전기에서 직접 녹음해야 합니다.';
	@override String get sets => '메시지 세트';
	@override String get soundFilesSet => '이 컴퓨터의 사운드 파일';
	@override String get openFileButton => '파일 열기';
	@override String get newSet => '새 세트';
	@override String get renameSet => '세트 이름 변경';
	@override String get deleteSet => '세트 삭제';
	@override String get newSetName => '이름';
	@override String deleteSetConfirm({required Object name}) => '${name}과(와) 그 녹음을 삭제할까요? 되돌릴 수 없습니다.';
	@override String get output => '오디오 출력';
	@override String get input => '녹음 입력';
	@override String get outputRadio => '네트워크로 무전기에 전송';
	@override String get inputDefault => '시스템 기본값';
	@override String get pickDevice => '사운드 장치 선택';
	@override String deviceMissing({required Object name}) => '${name} (연결 안 됨)';
	@override String get lead => '송신 전 지연';
	@override String get tail => '송신 후 지연';
	@override String millis({required Object n}) => '${n} ms';
	@override String get listenButton => '듣기';
	@override String get notRecorded => '녹음되지 않음';
	@override String get unplayable => '이 파일을 재생할 수 없습니다';
	@override String get problemNoOutput => '메시지를 재생하기 전에 무전기로 연결되는 사운드 장치를 선택하세요.';
	@override String get problemOutputMissing => '무전기로 연결되는 사운드 장치가 연결되어 있지 않습니다.';
	@override String get problemInputMissing => '녹음 장치가 연결되어 있지 않습니다.';
	@override String get problemDeviceFailed => '사운드 장치를 열 수 없습니다.';
	@override String get problemNotRecorded => '이 메시지에는 아직 녹음이 없습니다.';
	@override String get problemRecordingSilent => '녹음 장치에서 아무 소리도 들리지 않아 메시지를 그대로 두었습니다. 입력을 확인하고, 앱에 마이크 사용이 허용되어 있는지 확인하세요.';
	@override String get problemRadioAudioUnavailable => '무전기가 지금 앱의 오디오를 받지 않고 있습니다. 무전기와의 네트워크 연결이 필요합니다.';
	@override String get problemSourceRefused => '무전기가 송신 오디오를 앱으로 전환하지 않아 메시지가 중단되었습니다. 무전기가 앱의 오디오를 송신하도록 설정하세요.';
	@override String get problemCannotKey => '이 무전기는 CAT으로 키잉할 수 없어, 컴퓨터가 메시지를 재생해 넣을 수 없습니다.';
	@override String get problemUnplayable => '이 메시지의 파일은 앱이 재생할 수 있는 사운드 파일이 아닙니다. WAV, FLAC 또는 MP3 파일을 사용하거나 다시 녹음하세요.';
	@override String get problemRecordingFailed => '녹음이 중간에 끊겨 메시지를 그대로 두었습니다. 녹음 장치가 여전히 연결되어 있는지, 디스크에 여유 공간이 있는지 확인하세요.';
	@override String get problemFileFailed => '녹음을 메시지 자리에 저장할 수 없어 메시지를 그대로 두었습니다.';
	@override String problemWordsMissing({required Object words}) => '이 메시지에는 아직 녹음하지 않은 단어가 필요합니다: ${words}.';
	@override String problemTemplateFailed({required Object error}) => '이 메시지의 템플릿에 문제가 있습니다: ${error}';
	@override String get problemNoOperation => '내 목소리로 말하는 메시지는 말할 대상 교신이 있는 운용 안에서 재생됩니다.';
	@override String get problemNothingSaid => '이 메시지는 이 교신에 대해 말할 내용이 없습니다.';
	@override String get templateField => '내 목소리로 말하기';
	@override String get templateHelp => '비워 두면 녹음을 재생합니다. 그렇지 않으면 녹음한 단어들로 교신마다 다음 값을 채워 메시지를 말합니다:';
	@override String get help => '도움말';
	@override String get helpTitle => '내 목소리로 메시지 말하기';
	@override String get helpFullExample => '전체 메시지:';
	@override String get helpExample => '상대 콜사인, 상대에게 주는 리포트, 그리고 “QSL?” 녹음';
	@override String get playOnRadio => '무전기에서 재생';
	@override String get templateHelpCall => '상대 콜사인';
	@override String get templateHelpReport => '상대에게 주는 리포트';
	@override String get templateHelpMessage => '메시지 2의 녹음, 녹음된 대로 재생';
	@override String get voiced => '내 목소리로 말함';
	@override String willSay({required Object words}) => '말할 내용: ${words}';
	@override String willSayMissing({required Object words}) => '아직 녹음되지 않음: ${words}';
	@override String get previewNoOperation => '무엇을 말할지 보려면 운용을 여세요.';
	@override String get wordsDescription => '콜사인, 숫자 등을 내 목소리로 말합니다.';
}

// Path: settings.radio.voiceWords
class _Translations$settings$radio$voiceWords$ko extends Translations$settings$radio$voiceWords$en {
	_Translations$settings$radio$voiceWords$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '단어 녹음';
	@override String get callField => '오퍼레이터 단어 녹음';
	@override String get intro => '각 단어나 숫자를 콜사인을 말할 때처럼 빠르게 이어서 세 번 녹음하세요. 긴 구절은 한 번만 녹음합니다.';
	@override String get recordAll => '모두 녹음';
	@override String get recordAllGuide => '각 단어는 이어서 세 번, 여러 단어로 된 구절은 한 번 읽고, 줄 사이에는 숨을 고르세요. 마지막까지 읽은 후 정지를 누르세요.';
	@override String recordingOne({required Object word}) => '“${word} ${word} ${word}”라고 말한 후 정지를 누르세요.';
	@override String recordingOnce({required Object words}) => '“${words}”라고 말한 후 정지를 누르세요.';
	@override String get recorded => '녹음됨';
	@override String get notRecorded => '녹음되지 않음';
	@override String get addPhrase => '구절 추가';
	@override String get phraseField => '메시지에 쓰는 대로의 구절';
	@override String get deletePhrase => '구절 삭제';
	@override String get tryField => '말해 보기';
	@override String get pauseLetters => '글자 사이 간격';
	@override String get pauseWords => '단어 사이 간격';
	@override String pauseValue({required Object ms}) => '${ms} ms';
	@override String get speed => '속도';
	@override String speedValue({required Object speed}) => '${speed}×';
	@override String get advancedSettings => '고급 설정';
	@override String get splitSilent => '녹음에서 아무 소리도 들리지 않았습니다.';
	@override String get splitNotThreeTakes => '세 번의 발음을 찾을 수 없습니다. 단어를 이어서 세 번 말하고 다시 시도하세요.';
	@override String get splitLineCount => '읽은 내용에서 모든 단어를 찾을 수 없습니다. 각 단어를 세 번씩 읽고, 단어 사이에 숨을 고르세요.';
	@override String get splitLinesTooClose => '단어를 구분할 수 없습니다. 단어 사이에 더 길게 숨을 고르세요.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$ko extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '스팟에서 제로비트 피하기';
	@override String get descriptionOn => '무전기가 연결되어 있으면 CW 스팟에서 몇 Hz 떨어지게 튜닝하여, 응답하는 모두가 같은 음으로 호출하지 않게 합니다.';
	@override String get descriptionOff => '스팟된 주파수에 정확히 튜닝합니다.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$ko extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '제로비트: 회피 범위';
	@override String get description => '스팟된 주파수에서 위아래로 얼마나 떨어질지. 오프셋은 0에 가깝지 않습니다 — 그러면 다시 제로비트가 됩니다.';
}

// Path: settings.map.style
class _Translations$settings$map$style$ko extends Translations$settings$map$style$en {
	_Translations$settings$map$style$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '지도 스타일';
}

// Path: settings.map.showCallsigns
class _Translations$settings$map$showCallsigns$ko extends Translations$settings$map$showCallsigns$en {
	_Translations$settings$map$showCallsigns$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '콜사인 표시';
	@override String get description => '각 교신을 밴드 색상의 콜사인 칩으로 표시';
}

// Path: settings.map.showGrayline
class _Translations$settings$map$showGrayline$ko extends Translations$settings$map$showGrayline$en {
	_Translations$settings$map$showGrayline$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '그레이라인 표시';
	@override String get description => '지구의 밤 부분을 어둡게 하고, 박명은 그라데이션으로 표시';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$ko extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get automatic => '자동';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$ko extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '앱 사용 데이터 공유';
	@override String get descriptionOn => '사용량, 구성, 충돌 및 성능 데이터를 공유하여 앱 개선에 도움';
	@override String get descriptionOff => '앱 사용 데이터를 비공개로 유지합니다.\nHam2K 팀은 앱 충돌 또는 기타 문제를 감지할 수 없습니다.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$ko extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get title => '운용 데이터 공유';
	@override String get descriptionOn => '일부 운용 데이터를 공개 및 다른 사용자와 공유';
	@override String get descriptionOff => '운용 데이터 비공개 유지';
}

// Path: settings.station.models
class _Translations$settings$station$models$ko extends Translations$settings$station$models$en {
	_Translations$settings$station$models$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - 범용';
	@override String get icomGeneric => 'Icom - 범용';
	@override String get kenwoodGeneric => 'Kenwood - 범용';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get tx500 => 'Lab599 TX-500';
	@override String get tx500mp => 'Lab599 TX-500MP';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - 범용';
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
	@override String get rigctld => 'rigctld로 제어하는 무전기';
	@override String get rigctldNodeName => '내 무전기 (rigctld 경유)';
	@override String get flrig => 'flrig로 제어하는 무전기';
	@override String get flrigNodeName => '내 무전기 (flrig 경유)';
	@override String get hrd => 'Ham Radio Deluxe®로 제어하는 무전기';
	@override String get hrdNodeName => '내 무전기 (HRD 경유)';
	@override String get n3fjp => 'N3FJP로 제어하는 무전기';
	@override String get n3fjpNodeName => '내 무전기 (N3FJP 경유)';
	@override String get commander => 'DXLab Commander로 제어하는 무전기';
	@override String get commanderNodeName => '내 무전기 (Commander 경유)';
	@override String get antenna => '안테나';
	@override String get key => 'CW 키';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => '범용 무전기 (임시)';
	@override String get placeholderRadioNodeName => '내 무전기';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Sierra Radio CX-1 동축 스위치';
	@override String get gs232a => 'Yaesu GS-232A 로테이터 인터페이스';
	@override String get pstRotator => 'PstRotator (UDP 제어)';
	@override String get rtlSdr => 'RTL-SDR';
	@override String get nesdr => 'Nooelec NESDR';
	@override String get sdrplay => 'SDRplay RSP';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$ko extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get network => '네트워크/WiFi';
	@override String get secureNetwork => '보안 네트워크/WiFi';
	@override String get usbSerial => 'USB 시리얼';
	@override String get wifi => '네트워크/WiFi';
	@override String get bluetoothSerial => '블루투스 시리얼';
	@override String get bleSerial => '블루투스 LE';
	@override String get placeholder => '임시';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$ko extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get dipole => '다이폴';
	@override String get vertical => '버티컬';
	@override String get yagiBeam => '야기 / 빔';
	@override String get loop => '루프';
	@override String get longWire => '롱 와이어 / EFHW';
	@override String get other => '기타';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$ko extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get straight => '스트레이트 키';
	@override String get sideswiper => '사이드스와이퍼';
	@override String get bug => '버그 (기계식 반자동)';
	@override String get fullyAutomatic => '전자동 키어';
	@override String get singlePaddle => '싱글 패들';
	@override String get dualPaddle => '듀얼 패들';
	@override String get computerDriven => '컴퓨터 제어';
	@override String get other => '기타';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$ko extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get unknown => '알 수 없음';
	@override String get sunny => '맑음';
	@override String get clear => '맑음';
	@override String get mainlySunny => '대체로 맑음';
	@override String get mainlyClear => '대체로 맑음';
	@override String get partlyCloudy => '구름 조금';
	@override String get cloudy => '흐림';
	@override String get foggy => '안개';
	@override String get rimeFog => '어는 안개';
	@override String get lightDrizzle => '약한 이슬비';
	@override String get drizzle => '이슬비';
	@override String get heavyDrizzle => '강한 이슬비';
	@override String get lightFreezingDrizzle => '약한 어는 이슬비';
	@override String get freezingDrizzle => '어는 이슬비';
	@override String get lightRain => '약한 비';
	@override String get rain => '비';
	@override String get heavyRain => '강한 비';
	@override String get lightFreezingRain => '약한 어는 비';
	@override String get freezingRain => '어는 비';
	@override String get lightSnow => '약한 눈';
	@override String get snow => '눈';
	@override String get heavySnow => '강한 눈';
	@override String get snowGrains => '싸락눈';
	@override String get lightShowers => '약한 소나기';
	@override String get showers => '소나기';
	@override String get heavyShowers => '강한 소나기';
	@override String get lightSnowShowers => '약한 소낙눈';
	@override String get snowShowers => '소낙눈';
	@override String get thunderstorm => '뇌우';
	@override String get lightThunderstormsWithHail => '우박을 동반한 약한 뇌우';
	@override String get thunderstormWithHail => '우박을 동반한 뇌우';
}

// Path: settings.radio.pttKey.modes
class _Translations$settings$radio$pttKey$modes$ko extends Translations$settings$radio$pttKey$modes$en {
	_Translations$settings$radio$pttKey$modes$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get off => '아니요';
	@override String get toggle => '토글';
	@override String get hold => '누르고 있기';
}

// Path: settings.radio.pttKey.descriptions
class _Translations$settings$radio$pttKey$descriptions$ko extends Translations$settings$radio$pttKey$descriptions$en {
	_Translations$settings$radio$pttKey$descriptions$ko._(TranslationsKo root) : this._root = root, super.internal(root);

	final TranslationsKo _root; // ignore: unused_field

	// Translations
	@override String get off => '키보드로 무전기를 키잉하지 않습니다.';
	@override String get toggle => '보이스 모드에서 PTT 키를 누르면 송신하고, 다시 누르면 송신을 멈춥니다. 1분 후에는 자동으로 멈춥니다.';
	@override String get hold => '보이스 모드에서 PTT 키를 누르고 있는 동안 최대 1분까지 송신합니다.';
}

/// The flat map containing all translations for locale <ko>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsKo {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => '저장',
			'common.ok' => '확인',
			'common.cancel' => '취소',
			'common.delete' => '삭제',
			'common.create' => '만들기',
			'common.error' => '오류',
			'common.close' => '닫기',
			'common.done' => '완료',
			'common.callsign' => '콜사인',
			'common.clear' => '지우기',
			'common.dismiss' => '닫기',
			'common.copyDetails' => '상세 정보 복사',
			'common.expand' => '펼치기',
			'common.collapse' => '접기',
			'onboarding.welcomeTitle' => 'Ham2K Portable Logger에 오신 것을 환영합니다!',
			'onboarding.welcomeTitleDesktop' => 'Ham2K Power Logger에 오신 것을 환영합니다!',
			'onboarding.welcomeBody' => '사용 목적에 맞게 설정할 수 있도록 몇 가지 질문을 드리겠습니다.',
			'onboarding.skip' => '건너뛰기',
			'onboarding.kContinue' => '계속',
			'onboarding.back' => '뒤로',
			'onboarding.next' => '다음',
			'onboarding.done' => '완료',
			'onboarding.callsignTitle' => '콜사인이 무엇인가요?',
			'onboarding.callsignBody' => '이 앱을 유용하게 사용하려면 아마추어 무선기사 자격이 필요합니다',
			'onboarding.callsignLabel' => '오퍼레이터 콜사인',
			'onboarding.alreadyHaveAccount' => '이미 계정이 있으신가요?',
			'onboarding.foundSiblingTitle' => '기존 계정에 연결할까요?',
			'onboarding.foundSiblingBody' => ({required Object app}) => '이 기기에서 ${app}을(를) 찾았습니다. 이 앱을 같은 계정에 연결하면 콜사인과 로그를 가져옵니다.',
			'onboarding.foundPoloBody' => '이 기기에서 이전 버전의 Ham2K Portable Logger를 찾았습니다. 이 앱을 같은 계정에 연결하면 콜사인과 로그를 가져옵니다.',
			'onboarding.foundSiblingsBody' => '이 기기에서 다른 Ham2K 앱을 찾았습니다. 이 앱을 그중 한 계정에 연결하면 콜사인과 로그를 가져옵니다.',
			'onboarding.linkWithApp' => ({required Object app}) => '${app}과(와) 연결',
			'onboarding.linkWithPolo' => '이전 버전의 계정과 연결',
			'onboarding.setUpFresh' => '새로 설정',
			'onboarding.activitiesTitle' => '즐겨 하는 활동',
			'onboarding.activitiesBody' => '다음 인기 활성화 프로그램 중 관심 있는 것이 있나요?',
			'onboarding.activitiesFooter' => '(설정에서 더 많은 옵션을 찾을 수 있습니다)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.syncTitle' => '클라우드 동기화',
			'onboarding.syncBody' => 'Ham2K Log Filer는 로그를 클라우드에 백업하고, Ham2K 앱을 사용하는 모든 기기 간에 동기화합니다.',
			'onboarding.syncPricing' => '무료입니다! 유료 구독을 하면 더 빨라집니다.',
			'onboarding.syncLabel' => '클라우드 동기화 활성화',
			'onboarding.syncOffWarning' => '경고: 기기가 고장 나거나 분실되는 경우 등 운용 데이터를 잃을 가능성이 높아집니다.',
			'onboarding.notNow' => '나중에',
			'onboarding.consentTitle' => '데이터 및 개인정보',
			'onboarding.consentUsageBody' => '앱 개선을 위해 성능, 충돌 및 앱 사용 데이터를 수집하고자 합니다.',
			'onboarding.consentUsageLabel' => '앱 사용 데이터 공유',
			'onboarding.consentOperationBody' => '일부 기능은 운용 데이터를 다른 사용자와 공유할 수 있습니다. 언제든지 거부할 수 있습니다.',
			'onboarding.consentOperationLabel' => '운용 데이터 공유',
			'onboarding.finishingSetup' => '설정 마무리 중 — 레퍼런스 데이터 다운로드 중…',
			'startScreen.credits' => 'KI2D & 친구들 제작',
			'testerOverlay.tape' => '주의: 공사 중',
			'testerOverlay.warningTitle' => '이 앱은 개발 중입니다',
			'testerOverlay.warningBody' => '대부분의 기능이 아직 울퉁불퉁하고 곳곳에 걸려 넘어질 곳이 있습니다. 업데이트를 자주 확인해 주세요.',
			'testerOverlay.whatsNew' => ({required Object build}) => '빌드 ${build}의 새로운 기능',
			'testerOverlay.thanks' => '앱 개선을 위해 로그를 위험에 맡겨 주셔서 감사합니다!',
			'extensionsPanel.categoryActivity' => '활동',
			'extensionsPanel.categoryAward' => '어워드',
			'extensionsPanel.categoryContest' => '컨테스트',
			'extensionsPanel.categoryLookup' => '콜사인 조회',
			'extensionsPanel.categorySpots' => '스팟 출처',
			'extensionsPanel.categoryDashboard' => '대시보드 패널',
			'extensionsPanel.categoryOther' => '기타 확장 기능',
			'extensionsPanel.searchHint' => '확장 기능 검색',
			'extensionsPanel.applying' => '확장 기능 변경 사항을 적용 중입니다. 잠시만 기다려 주세요…',
			'extensionsPanel.noMatches' => '검색과 일치하는 확장 기능이 없습니다',
			'extensionsPanel.installFromFile' => '파일에서 설치…',
			'extensionsPanel.installVersion' => ({required Object version}) => '버전 ${version}',
			'extensionsPanel.screenshotLabel' => ({required Object n, required Object count}) => '스크린샷 ${n}/${count}',
			'extensionsPanel.moreScreenshots' => ({required Object count}) => '+${count}',
			'extensionsPanel.previousScreenshot' => '이전 스크린샷',
			'extensionsPanel.nextScreenshot' => '다음 스크린샷',
			'extensionsPanel.screenshotUnavailable' => '스크린샷 없음',
			'extensionsPanel.canReach' => '이 확장 기능이 연결할 수 있는 대상',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, 실시간 연결로',
			'extensionsPanel.canHoldLocalConnection' => '로컬 네트워크의 기기, 실시간 연결로',
			'extensionsPanel.canUseLocation' => '내 위치',
			'extensionsPanel.canReadRadio' => '무전기 (주파수와 모드 읽기)',
			'extensionsPanel.canControlRadio' => '무전기 (제어 및 송신 — 튜닝, 출력, CW, 보이스 메모리, PTT)',
			'extensionsPanel.canCommandRadioRaw' => '무전기 (고유 프로토콜로 모든 명령 전송 — 송신하거나 설정을 바꾸는 명령 포함)',
			'extensionsPanel.canReadCluster' => 'DX 클러스터 (내 계정으로 로그인하여 수신 내용 읽기)',
			'extensionsPanel.canSpotCluster' => 'DX 클러스터 (내 계정으로 로그인하여 내 이름으로 스팟 게시)',
			'extensionsPanel.canCommandCluster' => 'DX 클러스터 (내 계정으로 로그인하여 내 이름으로 모든 명령 전송)',
			'extensionsPanel.canSetUserAgent' => '서버에 자체 이름으로 신원을 밝힘',
			'extensionsPanel.canChangeSettings' => '설정 (명령으로 변경 — 모든 설정, 개발자 모드, 실험기능)',
			'extensionsPanel.noCapabilities' => '앱 외부의 어떤 것도 요청하지 않습니다.',
			'extensionsPanel.sandboxNote' => '확장 기능은 샌드박스에서 실행됩니다. 파일에 접근할 수 없으며, 여기 나열된 것 외의 네트워크는 사용할 수 없습니다.',
			'extensionsPanel.installAction' => '설치',
			'extensionsPanel.updateAction' => '업데이트',
			'extensionsPanel.installFailed' => '해당 확장 기능을 설치할 수 없습니다',
			'extensionsPanel.installedBadge' => '설치됨',
			'extensionsPanel.uninstallAction' => '제거',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => '${name}을(를) 제거할까요?',
			'extensionsPanel.uninstallBody' => '이 확장 기능과 설정이 제거됩니다. 로그는 그대로 유지됩니다.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} 설치됨',
			'extensionsPanel.installDownloading' => '다운로드 중…',
			'extensionsPanel.installWaiting' => '설치 대기 중…',
			'extensionsPanel.installInstalling' => '설치 중…',
			'extensionsPanel.installAwaitingApproval' => '승인 대기 중…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name}이(가) 이미 설치 중입니다.',
			'extensionsPanel.updatedTo' => ({required Object version}) => '${version}(으)로 업데이트됨',
			'extensionsPanel.installIncomplete' => ({required Object name}) => '${name} 설치가 완료되지 않았습니다. 다시 설치해야 할 수 있습니다.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => '${name}을(를) 제거할 수 없습니다',
			'extensionsPanel.installedFrom' => ({required Object source}) => '${source}에서 다운로드됨',
			'extensionsPanel.dropHint' => '.h2kext 확장 파일을 끌어다 놓아 설치하세요',
			'extensionsPanel.dropOneOnly' => '확장 기능은 한 번에 하나씩 끌어다 놓으세요.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source}이(가) 해당 확장 기능에 대해 ${status}을(를) 반환했습니다.',
			'extensionsPanel.downloadTooLarge' => '다운로드 크기가 확장 기능이라기엔 너무 큽니다.',
			'extensionsPanel.downloadNotSecure' => '다운로드가 안전하지 않은 곳으로 리디렉션되었습니다.',
			'extensionsPanel.catalogSection' => '카탈로그',
			'extensionsPanel.catalogLoading' => '카탈로그 로딩 중…',
			'extensionsPanel.catalogUnreachable' => '카탈로그에 연결할 수 없음',
			'extensionsPanel.builtIn' => '내장',
			'extensionsPanel.updateAvailableBadge' => '업데이트 가능',
			'extensionsPanel.updatesAvailableTitle' => '확장 기능 업데이트',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => '${name}의 업데이트가 있습니다.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} 외 ${count}개를 업데이트해야 합니다.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names}을(를) 업데이트해야 합니다.',
			'extensionsPanel.pendingUpdatesSection' => '대기 중인 업데이트',
			'extensionsPanel.updateAllAction' => '모두 업데이트',
			'extensionsPanel.updatesUnderWay' => '해당 업데이트가 이미 진행 중입니다.',
			'extensionsPanel.updatesNothingLeft' => '확장 기능이 최신 상태입니다.',
			'extensionsPanel.updatesNoticeAction' => '자세히',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '확장 기능 ${count}개를 업데이트할까요?', other: '확장 기능 ${count}개를 업데이트할까요?', ), 
			'extensionsPanel.upgradeDoneTitle' => '확장 기능이 준비되었습니다',
			'extensionsPanel.upgradeDoneBody' => '이제 Ham2K 확장 기능 카탈로그에서 제공되므로, 앱의 새 버전을 기다리지 않고 업데이트할 수 있습니다.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => '업그레이드되지 않음: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => '실행되지 않음: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => '아직 설치되어 있으며 설정 › 확장 기능에 표시되어 있습니다. 그곳에서 업데이트하면 다시 사용할 수 있습니다.',
			'extensionsPanel.upgradeDoneUnservedHint' => '카탈로그에 이들을 직접 대체할 항목이 없으니, 사용하던 기능을 지원하는 확장 기능을 카탈로그에서 찾아보세요.',
			'extensionsPanel.retiredQp' => 'QSO 파티',
			'extensionsPanel.retiredStateparks' => '주립공원 이벤트',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '확장 기능 중 ${count}개가 아직 도착하지 않았습니다. 다음에 확장 기능 카탈로그에 연결되면 다운로드됩니다.',
			'extensionsPanel.runtimeDeadBody' => '확장 기능이 시작되지 않았습니다. 앱을 다시 시작하면 복구될 것입니다.',
			'extensionsPanel.refusedTitle' => '일부 확장 기능이 실행되지 않았습니다',
			'extensionsPanel.upgradeBusyTitle' => '아직 설정 중',
			'extensionsPanel.upgradeRuntimeDeadTitle' => '확장 기능이 실행되고 있지 않습니다',
			'extensionsPanel.restoreTitle' => '일부 확장 기능이 없습니다',
			'extensionsPanel.restoreBody' => '설치했던 다음 확장 기능이 이 기기에 없습니다. Ham2K 확장 기능 카탈로그에서 다시 다운로드할 수 있습니다:',
			'extensionsPanel.restoreFromFile' => '파일에서 설치됨. 해당 파일에서 다시 설치하거나 목록에서 지우세요:',
			'extensionsPanel.restoreOtherCatalog' => '다른 확장 기능 카탈로그에서 설치되어 여기서는 사용할 수 없습니다:',
			'extensionsPanel.restoreForget' => '지우기',
			'extensionsPanel.restoreInstall' => '설치',
			'extensionsPanel.restoreLater' => '나중에',
			'extensionsPanel.restoreInstalling' => '확장 기능 설치 중…',
			'extensionsPanel.restoreDoneTitle' => '확장 기능이 복구되었습니다',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => '다시 설치됨: ${names}.',
			'extensionsPanel.restorePartialTitle' => '일부 확장 기능을 설치할 수 없습니다',
			'extensionsPanel.restoreFailed' => ({required Object names}) => '설치할 수 없음: ${names}. 다음에 앱을 열 때 다시 제안합니다.',
			'extensionsPanel.restoreBusyBody' => '앱이 아직 확장 기능을 설정 중입니다. 다음에 앱을 열 때 다시 제안합니다.',
			'extensionsPanel.restoreRuntimeDeadBody' => '다시 설치했지만 확장 기능이 시작되지 않았습니다. 앱을 다시 시작하면 복구될 것입니다.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name}이(가) 철회되었습니다',
			'extensionsPanel.revokedBody' => '카탈로그에서 이 버전을 철회하여 비활성화되었습니다.',
			'extensionsPanel.forceDisabledTitle' => ({required Object name}) => '${name}이(가) 비활성화되었습니다',
			'extensionsPanel.forceDisabledBody' => 'Ham2K에서 이 확장 기능을 당분간 비활성화했습니다.',
			'extensionsPanel.replacedTitle' => ({required Object name}) => '${name}이(가) 대체되었습니다',
			'extensionsPanel.replacedBody' => ({required Object replacement}) => '${replacement}이(가) 그 자리를 대신합니다. 확장 기능에서 전환할 수 있습니다.',
			'extensionsPanel.replacedBy' => ({required Object name}) => '${name}(으)로 대체됨',
			'extensionsPanel.replacedByInstalled' => ({required Object name}) => '이미 설치된 ${name}(으)로 대체됨',
			'extensionsPanel.replaceAction' => '대체',
			'extensionsPanel.replaceInstalledBody' => ({required Object replacement}) => '설정은 이미 설치된 ${replacement}(으)로 옮겨집니다. 로그는 그대로 유지됩니다.',
			'extensionsPanel.downloadHashMismatch' => '다운로드한 파일이 카탈로그에 설명된 확장 기능과 다릅니다.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object key, required Object version}) => '카탈로그에 ${key}의 ${version} 버전이 없습니다.',
			'extensionsPanel.catalogLinkUnknown' => '해당 카탈로그 링크에 확장 기능 버전이 지정되어 있지 않습니다.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => '카탈로그에 해당 트랙의 ${key} 릴리스가 없습니다.',
			'extensionsPanel.installFromLink' => '링크에서 설치',
			'extensionsPanel.unstableReleaseWarning' => '불안정 릴리스입니다. 게시자가 완성되었다고 밝히지 않은 버전입니다. 오작동할 수 있으며, 앞으로도 불안정 업데이트를 받게 됩니다.',
			'extensionsPanel.bleedingReleaseWarning' => '최신(bleeding-edge) 릴리스입니다. 개발 중인 버전으로 고장 나거나 설정이 사라질 수 있습니다. 앞으로도 최신 업데이트를 받게 됩니다.',
			'extensionsPanel.channelUnstable' => '불안정',
			'extensionsPanel.channelBleeding' => '최신',
			'extensionsPanel.followsUnstable' => '불안정 및 안정 릴리스를 받음',
			'extensionsPanel.followsBleeding' => '최신, 불안정 및 안정 릴리스를 받음',
			'extensionsPanel.followStableAction' => '안정 릴리스만 받기',
			'extensionsPanel.revokedBadge' => '철회됨',
			'extensionsPanel.forceDisabledBadge' => 'Ham2K에서 비활성화',
			'extensionsPanel.refusedBadge' => '로드되지 않음',
			'extensionsPanel.downloadNotHttps' => '다운로드가 보안 연결을 통하지 않습니다.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '해당 확장 기능을 위해 ${source}에 연결할 수 없습니다.',
			'extensionsPanel.detailsAction' => '상세',
			'extensionsPanel.installedFromFile' => '파일에서 설치됨',
			'extensionsPanel.detailsWhatItDoes' => '지원 기능',
			'extensionsPanel.installedPreloaded' => '사전 설치됨',
			'extensionsPanel.hookAccount' => '계정 로그인',
			'extensionsPanel.hookCallNotes' => '콜사인 노트',
			'extensionsPanel.hookDataFile' => '오프라인 데이터',
			'extensionsPanel.hookExport' => '내보내기',
			'extensionsPanel.hookLookup' => '콜사인 조회',
			'extensionsPanel.hookScoring' => '점수 계산',
			'extensionsPanel.hookSpots' => '스팟',
			'extensionsPanel.hookHunting' => ({required Object program}) => '${program} 추적',
			'extensionsPanel.hookActivating' => ({required Object program}) => '${program} 활성화',
			'extensionsPanel.suggestedSection' => '추천',
			'extensionsPanel.moreAvailableSection' => ({required Object count}) => '그 외 ${count}개',
			'home.title' => '포터블 로거',
			'home.newOperation' => '새로운 운용',
			'home.stationCallsign' => '무선국 콜사인',
			'home.titleOptional' => '제목 (선택 사항)',
			'home.emptyList' => '아직 운용이 없습니다. 운용을 만들어 로깅을 시작하세요.',
			'home.quickLookup' => '빠른 조회',
			'home.nav.operations' => '운용',
			'home.nav.chase' => '추적',
			'home.nav.logs' => '로그',
			'home.nav.maps' => '지도',
			'home.nav.settings' => '설정',
			'home.panels.operations' => '운용 목록',
			'home.panels.operationsDescription' => '최근 운용부터 표시합니다.',
			'home.panels.version' => '현재 버전',
			'home.panels.versionDescription' => 'Ham2K 로고, 앱 이름, 실행 중인 빌드.',
			'home.toggleNav' => '탐색 레이블 표시/숨기기',
			'home.logs.title' => '로그',
			'home.logs.titleFor' => '로그:',
			'home.logs.emptyCallsigns' => '아직 로깅된 QSO 없음',
			'home.logs.emptyQsos' => ({required Object call}) => '${call}의 QSO 없음',
			'home.logs.mapNoSelection' => 'QSO를 선택하면 지도에 표시됩니다',
			'home.logs.searchHint' => '콜사인 또는 이름 검색',
			'home.logs.noSearchMatches' => '검색과 일치하는 QSO가 없습니다',
			'home.logs.titleAll' => '모든 로그',
			'home.logs.allCallsigns' => '모든 콜사인',
			'home.logs.noOperation' => '운용에 속하지 않음',
			'home.logs.unsavedTitle' => '저장되지 않은 변경 사항',
			'home.logs.unsavedBody' => '이 QSO에 저장하지 않은 변경 사항이 있습니다.',
			'home.logs.pendingDeleteBody' => '이 QSO는 삭제 예정으로 표시되어 있습니다.',
			'home.logs.editGone' => '저장되지 않음: 해당 QSO가 더 이상 이 로그에 없습니다.',
			'home.logs.discard' => '버리기',
			'home.logs.sheet.callsigns' => '무선국 콜사인',
			'home.logs.sheet.groupBy' => '그룹 기준',
			'home.logs.sheet.period' => '기간',
			'home.logs.groupBy.none' => '그룹 없음',
			'home.logs.groupBy.date' => '날짜',
			'home.logs.groupBy.dx' => 'DX',
			'home.logs.groupBy.unknownContinent' => '알 수 없는 대륙',
			'home.logs.groupBy.unknownEntity' => '알 수 없는 엔티티',
			'home.logs.groupBy.unknownDate' => '날짜 없음',
			'home.logs.period.thisMonth' => '이번 달',
			'home.logs.period.last3Months' => '최근 3개월',
			'home.logs.period.thisYear' => '올해',
			'home.logs.period.lastYear' => '작년',
			'home.logs.period.allTime' => '전체 기간',
			'home.logs.period.custom' => '사용자 지정 범위',
			'home.logs.periodTitle.inSpan' => ({required Object span}) => '(${span})',
			'home.logs.periodTitle.custom' => '사용자 지정 범위',
			'home.logs.columns.date' => '날짜',
			'home.logs.columns.time' => '시간',
			'home.logs.columns.freq' => '주파수',
			'home.logs.columns.mode' => '모드',
			'home.logs.columns.call' => '콜사인',
			'home.logs.columns.name' => '이름',
			'home.logs.columns.station' => '무선국',
			'home.logs.columns.band' => '밴드',
			'home.logs.columns.sent' => '보냄',
			'home.logs.columns.rcvd' => '받음',
			'home.logs.columns.grid' => '그리드',
			'home.logs.columns.state' => '주',
			'home.logs.columns.country' => '국가',
			'home.logs.columns.refs' => '레퍼런스',
			'home.logs.panels.qsos' => 'QSO 로그',
			'home.logs.panels.qsosDescription' => '선택한 콜사인의 모든 운용에 걸친 QSO.',
			'home.logs.panels.info' => '정보',
			'home.logs.panels.infoDescription' => '전체 QSO 수 또는 선택한 QSO의 콜사인 조회 결과.',
			'home.logs.panels.map' => '지도',
			'home.logs.panels.mapDescription' => '선택한 QSO의 위치.',
			'home.logs.import.callsigns' => ({required Object calls}) => '콜사인: ${calls}',
			'home.logs.import.skippedOne' => '기록 1개를 읽을 수 없습니다',
			'home.logs.import.skippedOther' => ({required Object count}) => '기록 ${count}개를 읽을 수 없습니다',
			'home.logs.import.readingTitle' => 'ADIF 파일 읽는 중…',
			'home.logs.import.checkingTitle' => '중복 확인 중…',
			'home.logs.import.importingTitle' => 'QSO 가져오는 중…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object total, required Object done}) => '${total}개 중 ${done}개 확인됨',
			'home.logs.import.importingDetail' => ({required Object total, required Object imported}) => '${total}개 중 ${imported}개 가져옴',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => '추적 중',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} & ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} 외',
			'chase.station.title' => '추적 중인 무선국',
			'chase.station.stationLabel' => '무선국: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => '위치 없음',
			'chase.periodInline.today' => '오늘',
			'chase.periodInline.thisWeek' => '이번 주',
			'chase.periodInline.last14Days' => '최근 14일간',
			'chase.periodInline.thisMonth' => '이번 달',
			'chase.periodStats.today' => '오늘 통계',
			'chase.periodStats.thisWeek' => '이번 주 통계',
			'chase.periodStats.last14Days' => '최근 14일 통계',
			'chase.periodStats.thisMonth' => '이번 달 통계',
			'chase.period.today' => '오늘',
			'chase.period.thisWeek' => '이번 주',
			'chase.period.last14Days' => '최근 14일',
			'chase.period.thisMonth' => '이번 달',
			'chase.goals.title' => '추적 목표',
			'chase.goals.remove' => ({required Object name}) => '${name} 추적 중지',
			'chase.goals.extensionsTitle' => '더 많은 추적 프로그램',
			'chase.panels.logging' => 'QSO',
			'chase.panels.loggingDescription' => '기간 내 추적한 QSO 위에 로깅 컨트롤 표시.',
			'chase.panels.info' => '정보',
			'chase.panels.infoDescription' => '로깅 중인 콜사인 또는 기간 통계.',
			'chase.panels.spots' => '스팟',
			'chase.panels.spotsDescription' => '스팟에 올라온 무선국, 바로 추적할 수 있습니다.',
			'chase.panels.map' => '지도',
			'chase.panels.mapDescription' => '기간 내 QSO와 로깅 중인 무선국.',
			'chase.claims.checking' => '추적용 QSO 확인 중',
			'chase.claims.rebuilding' => ({required Object program}) => '${program} 로그 확인 중',
			'chase.claims.progress' => ({required Object total, required Object done}) => 'QSO ${total}개 중 ${done}개',
			'chase.notice.newRef' => ({required Object program}) => '새로운 ${program}',
			'chase.notice.newRefGuess' => ({required Object program}) => '새로운 ${program} (추정)',
			'chase.notice.newBand' => ({required Object program}) => '새로운 ${program} 밴드',
			'chase.notice.newBandGuess' => ({required Object program}) => '새로운 ${program} 밴드 (추정)',
			'chase.notice.newMode' => ({required Object program}) => '새로운 ${program} 모드',
			'chase.notice.newModeGuess' => ({required Object program}) => '새로운 ${program} 모드 (추정)',
			'chase.notice.unconfirmed' => ({required Object program}) => '${program} 미확인',
			'chase.notice.programGuess' => ({required Object notice}) => '${notice} (추정)',
			'chase.alerts.title' => '알림',
			'chase.alerts.newRef' => '새로운 레퍼런스',
			'chase.alerts.newBand' => '새로운 밴드',
			'chase.alerts.newMode' => '새로운 모드',
			'chase.alerts.unconfirmed' => '미확인',
			'chase.checklists' => '추적 진행 상황',
			'chase.imports.importFrom' => ({required Object label}) => '${label} 가져오기',
			'chase.imports.pickTitle' => ({required Object file}) => '${file}을(를) 다음으로 가져오기',
			'chase.imports.dropHint' => '파일을 끌어다 놓아 추적 프로그램으로 가져오세요',
			'chase.imports.done' => ({required Object file, required Object program, required Object count}) => '${file}에서 ${program} 항목 ${count}개를 가져왔습니다',
			'chase.imports.doneSkipped' => ({required Object file, required Object program, required Object count, required Object skipped}) => '${file}에서 ${program} 항목 ${count}개를 가져왔고, 읽을 수 없는 ${skipped}개는 건너뛰었습니다',
			'chase.imports.nothing' => ({required Object file, required Object program}) => '${file}에는 ${program}이(가) 가져올 수 있는 항목이 없습니다',
			'chase.imports.failed' => ({required Object program, required Object file}) => '${program}이(가) ${file}을(를) 읽을 수 없습니다',
			'chase.imports.unreadable' => ({required Object program, required Object file, required Object skipped}) => '${program}이(가) ${file}의 기록 ${skipped}개를 하나도 읽을 수 없습니다',
			'chase.imports.noProgram' => ({required Object file}) => '${file}을(를) 가져올 수 있는 추적 프로그램이 없습니다',
			'dialogs.operationDetails' => '운용 상세',
			'dialogs.activities' => '활동',
			'dialogs.stationCallsign' => '무선국 콜사인',
			'dialogs.advanced' => '고급',
			'dialogs.operatingPosition' => '운용 포지션 (다중 무선국)',
			'dialogs.assistance' => '어시스턴스',
			'dialogs.assistanceDescription' => '스팟 서비스 및 기타 정보 소스 사용',
			'dialogs.selfSpotting' => '자체 스팟',
			'dialogs.selfSpottingDescription' => '내 주파수 정보를 알리는 기능 허용',
			'dialogs.disabledByRules' => ({required Object rules}) => '${rules} 규정 준수를 위해 비활성화됨',
			'dialogs.lookupDespiteAssistance.title' => '온라인으로 조회할까요?',
			'dialogs.lookupDespiteAssistance.body' => '이 운용에서는 어시스턴스가 비활성화되어 있습니다. 모든 QSO를 조회하면 이번 한 번만 QRZ 같은 온라인 서비스를 사용합니다.',
			'dialogs.lookupDespiteAssistance.bodyRules' => ({required Object rules}) => '이 운용에서는 ${rules} 규정 준수를 위해 어시스턴스가 비활성화되어 있습니다. 모든 QSO를 조회하면 이번 한 번만 QRZ 같은 온라인 서비스를 사용합니다.',
			'dialogs.lookupDespiteAssistance.action' => '온라인 조회',
			'dialogs.notes' => '메모',
			'dialogs.deleteOperationTitle' => '운용 삭제',
			'dialogs.purgeTestsTitle' => '테스트 운용 영구 삭제',
			'dialogs.purgeTestsBody' => '이 테스트 운용과 해당 QSO를 영구적으로 삭제합니다. 되돌릴 수 없습니다.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '운용에 속하지 않은 테스트 교신 ${count}개도 포함됩니다.', other: '운용에 속하지 않은 테스트 교신 ${count}개도 포함됩니다.', ), 
			'dialogs.purgeTestsAction' => '영구 삭제',
			'dialogs.syncAllTitle' => '이 기기의 로그를 대체할까요?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL은 이 기기의 ${qsos}을(를) 백업하고 지운 후, 서버에서 계정의 로그를 다시 다운로드합니다. 백업은 이 기기의 데이터베이스에 남습니다.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: 'QSO ${n}개가 아직 동기화되지 않았습니다. 서버가 받지 못했으므로 복구되지 않습니다.', other: 'QSO ${n}개가 아직 동기화되지 않았습니다. 서버가 받지 못했으므로 복구되지 않습니다.', ), 
			'dialogs.syncAllAction' => '삭제 후 다시 동기화',
			'dialogs.receivedPurgesTitle' => '다른 곳에서 삭제된 테스트 운용',
			'dialogs.receivedPurgesBody' => '다른 기기에서 테스트 운용으로 삭제된 항목입니다. 여기서도 제거할까요? 해당 운용과 QSO가 영구적으로 삭제되며 되돌릴 수 없습니다.',
			'dialogs.receivedPurgesAction' => '제거',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => '잘못된 콜사인: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => '잘못된 콜사인: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '지금까지 ${previous}이(가) 운용했습니다. 새 교신에는 ${typed}이(가) 기록됩니다.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => '지금까지 기록된 오퍼레이터가 없습니다. 새 교신에는 ${typed}이(가) 기록됩니다.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => '이 운용에는 이미 ${calls}의 교신이 있습니다. ${typed}은(는) 새 교신에만 기록됩니다.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '이미 로깅된 교신의 오퍼레이터도 ${typed}(으)로 기록', other: '이미 로깅된 교신 ${count}개 모두의 오퍼레이터도 ${typed}(으)로 기록', ), 
			'dialogs.callChange.operatorSeveralStations' => '여러 무선국 콜사인을 사용할 때는 별도의 오퍼레이터를 지원하지 않습니다',
			'dialogs.callChange.contactsUnreadable' => '이 운용의 교신을 읽을 수 없어, 여기서 콜사인을 변경해도 교신을 업데이트하지 않습니다',
			'dialogs.callChange.restampFailed' => ({required Object error}) => '이미 로깅된 교신을 업데이트할 수 없어 변경하지 않았습니다: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object planned, required Object written}) => '교신 ${planned}개 중 ${written}개가 업데이트되었습니다. 나머지는 더 이상 이 운용에 없습니다',
			'operation.deletedReadOnly' => '삭제된 운용입니다. 로깅하거나 변경하려면 운용을 복구하세요.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSO',
			'operation.tabs.info' => '정보',
			'operation.tabs.spots' => '스팟',
			'operation.tabs.map' => '지도',
			'operation.tabs.qsosPlain' => 'QSO',
			'operation.tabs.clock' => '시계',
			'operation.tabs.weather' => '날씨',
			'operation.tabs.website' => '웹사이트',
			'operation.tabs.remoteScreen' => '원격 화면',
			'operation.tabs.solar' => '태양 활동',
			'operation.tabs.radio' => '무전기',
			'operation.tabs.rotator' => '로테이터',
			'operation.tabs.summaries' => '운용 요약',
			'operation.positions.nobodyYet' => '아직 이 운용을 공유하는 다른 운용 포지션이 없습니다.',
			'operation.positions.positionLabel' => ({required Object number}) => '포지션: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => '다른 포지션',
			'operation.positions.thisDevice' => '내 운용 포지션',
			'operation.positions.nameIn' => ' - ',
			'operation.positions.panelTitle' => '포지션',
			'operation.positions.panelDescription' => '이 운용을 공유하는 모든 운용 포지션에서 지금 로깅 중인 내용.',
			'operation.stationCallsignNone' => '무선국 콜사인 없음',
			'operation.titleNone' => '제목 없음',
			'operation.deleteOperation' => '운용 삭제',
			'operation.loggingControlsStale' => '활동 필드가 최신이 아닐 수 있습니다. 운용을 다시 열어 새로고침하세요',
			'operation.locationNone' => '설정되지 않음',
			'operation.generalOperation' => '일반 운용',
			'operation.titleFor' => ({required Object value}) => '${value}',
			'operation.titleAt' => ({required Object value}) => '${value}에서',
			'operation.segmentNow' => ({required Object description}) => '현재 ${description}',
			'operation.testOperationSuffix' => '테스트',
			'operation.menu.showRstFields' => 'RST 필드 표시',
			'operation.menu.showStateField' => '주 필드 표시',
			'operation.menu.showGridField' => '그리드 필드 표시',
			'operation.menu.showDeletedQsos' => '삭제된 QSO 표시',
			'operation.menu.showDeletedOps' => '삭제된 운용 표시',
			'operation.menu.showQsoNumbers' => 'QSO 번호 표시',
			'operation.menu.lookupAllQsos' => '모든 QSO 조회',
			'operation.menu.loggingSettingsTitle' => '로깅 설정',
			'operation.menu.mapSettingsTitle' => '지도 설정',
			'operation.menu.actionsSection' => '작업',
			'operation.layout.title' => '패널 추가',
			'operation.layout.availableSection' => '사용 가능한 패널',
			'operation.layout.panelSettings' => ({required Object panel}) => '${panel} 설정',
			'operation.layout.panelSettingsAction' => '패널 설정',
			'operation.layout.viewName' => '운용 화면',
			'operation.layout.viewOptions' => '화면 레이아웃 옵션',
			'operation.layout.viewTitleBuiltIn' => '이 화면은 앱에 내장되어 있으며, 이름도 마찬가지입니다',
			'operation.layout.resetOptions' => '기본값 복원',
			'operation.layout.removePane' => '제거',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => '${panel}을(를) 기본값으로 복원할까요?',
			'operation.layout.resetPaneConfirmBody' => '제목, 헤더 및 크기가 기본값으로 돌아갑니다. 나머지 레이아웃은 그대로 유지됩니다.',
			'operation.layout.resetViewConfirm' => '이 화면을 기본 레이아웃으로 복원할까요?',
			'operation.layout.resetViewConfirmBody' => '패널이 기본 배치로 돌아가고, 화면 옵션과 모든 패널의 옵션이 기본값으로 돌아갑니다.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => '${panel} 레이아웃 설정',
			'operation.layout.paneTitle' => '제목',
			'operation.layout.paneShowHeader' => '헤더 표시',
			'operation.layout.paneShowHeaderTabset' => '이 패널이 그룹을 공유하는 동안 항상 표시됩니다. 헤더를 통해 다른 패널로 이동합니다',
			'operation.layout.paneInherit' => '앱과 동일',
			'operation.layout.searchHint' => '패널 검색',
			'operation.layout.noPanelsMatch' => '검색과 일치하는 패널이 없습니다.',
			'operation.layout.nothingToAdd' => '이 화면에 이미 가능한 모든 패널이 있습니다',
			'operation.layout.addPanel' => ({required Object panel}) => '${panel} 추가',
			'operation.layout.showPreview' => ({required Object panel}) => '${panel} 미리보기',
			'operation.layout.missingExtension' => ({required Object name}) => '확장 기능 "${name}"이(가) 없습니다',
			'operation.layout.missingExtensionEnable' => '활성화',
			'operation.layout.missingExtensionInstall' => '설치…',
			'operation.layout.missingExtensionWontRun' => '이 버전은 실행되지 않습니다. 설정 › 확장 기능에서 업데이트하세요.',
			'operation.layout.missingExtensionUnavailable' => '이 앱에서는 사용할 수 없음',
			'operation.layout.missingExtensionNotInCatalog' => '카탈로그에 없음',
			'operation.layout.missingExtensionCatalogUnreachable' => '카탈로그에 연결할 수 없습니다. 다시 시도하세요',
			'operation.layout.missingExtensionFailed' => '실패했습니다. 다시 시도하세요',
			'operation.layout.previewUnavailable' => '이 패널의 미리보기 이미지를 표시할 수 없습니다.',
			'operation.layout.nestedPaneTitle' => '더보기',
			'operation.layout.layouts.defaultName' => '기본',
			'operation.layout.layouts.untitledName' => ({required Object number}) => '레이아웃 ${number}',
			'operation.layout.layouts.switcherLabel' => ({required Object name}) => '레이아웃: ${name}',
			'operation.layout.layouts.menuNew' => '새로 만들기…',
			'operation.layout.layouts.menuExport' => '내보내기…',
			'operation.layout.layouts.menuImport' => '가져오기…',
			'operation.layout.layouts.menuTitle' => '레이아웃',
			'operation.layout.layouts.newTitle' => '새 레이아웃',
			'operation.layout.layouts.editTitle' => '레이아웃 편집',
			'operation.layout.layouts.edit' => '편집',
			'operation.layout.layouts.duplicateCurrent' => '현재 레이아웃 복제',
			'operation.layout.layouts.startFromDefault' => '기본 레이아웃에서 시작',
			'operation.layout.layouts.nameLabel' => '이름',
			'operation.layout.layouts.descriptionLabel' => '설명',
			'operation.layout.layouts.create' => '만들기',
			'operation.layout.layouts.leaveEditTitle' => ({required Object name}) => '"${name}"의 변경 사항을 저장할까요?',
			'operation.layout.layouts.leaveEditBody' => '이 레이아웃에 저장하지 않은 변경 사항이 있습니다.',
			'operation.layout.layouts.discard' => '버리기',
			'operation.layout.layouts.deleteTitle' => '이 레이아웃을 삭제할까요?',
			'operation.layout.layouts.deleteBody' => ({required Object name}) => '"${name}" 레이아웃을 정말 삭제할까요?',
			'operation.layout.layouts.exportTitle' => '레이아웃 내보내기',
			'operation.layout.layouts.exportPick' => '내보낼 패널',
			'operation.layout.layouts.tabSet' => '탭 그룹',
			'operation.layout.layouts.exportAction' => '내보내기',
			'operation.layout.layouts.exported' => ({required Object location}) => '레이아웃을 ${location}에 저장했습니다',
			'operation.layout.layouts.exportFailed' => ({required Object error}) => '레이아웃을 내보낼 수 없습니다: ${error}',
			'operation.layout.layouts.importTitle' => '레이아웃 가져오기',
			'operation.layout.layouts.importFromOtherView' => ({required Object view}) => '${view} 화면용 레이아웃입니다. 그 화면에만 있는 패널은 제외됩니다.',
			'operation.layout.layouts.viewHome' => '홈',
			'operation.layout.layouts.viewOperation' => '운용',
			'operation.layout.layouts.viewLogs' => '로그',
			'operation.layout.layouts.viewChase' => '추적',
			'operation.layout.layouts.importAsNew' => '새 레이아웃으로',
			'operation.layout.layouts.importReplace' => '이 레이아웃을 대체',
			'operation.layout.layouts.importAdd' => '이 레이아웃에 추가',
			'operation.layout.layouts.importAddHint' => '패널이 오른쪽의 새 열에 추가됩니다.',
			'operation.layout.layouts.importPick' => '가져올 패널',
			'operation.layout.layouts.importReplaceSettings' => '여기에 이미 설정된 패널의 설정을 대체',
			'operation.layout.layouts.importAction' => '가져오기',
			'operation.layout.layouts.importUnreadable' => ({required Object filename, required Object problem}) => '${filename}은(는) 이 앱이 읽을 수 있는 레이아웃이 아닙니다: ${problem}',
			'operation.layout.layouts.problemNotYaml' => ({required Object line}) => '텍스트가 올바른 YAML이 아닙니다 (${line}행)',
			'operation.layout.layouts.problemNotLayoutFile' => 'Ham2K 레이아웃 파일이 아닙니다',
			'operation.layout.layouts.problemNewerVersion' => '더 새로운 버전의 앱에서 작성되었습니다',
			'operation.layout.layouts.problemNoArrangement' => '배치 정보가 없습니다',
			'operation.layout.layouts.problemMalformed' => '일부가 레이아웃 형식에 맞지 않습니다',
			'operation.layout.layouts.problemTooLarge' => '너무 큽니다',
			'operation.layout.layouts.importPickerFailed' => ({required Object error}) => '파일을 열 수 없습니다: ${error}',
			'operation.layout.layouts.importFailed' => ({required Object error}) => '레이아웃을 가져올 수 없습니다: ${error}',
			'operation.layout.layouts.duplicateFailed' => ({required Object error}) => '레이아웃을 복사할 수 없습니다: ${error}',
			'operation.layout.layouts.importNothing' => '선택한 패널이 없어 아무것도 가져오지 않았습니다.',
			'operation.layout.layouts.importSkipped' => ({required Object panels}) => '제외됨: ${panels}',
			'operation.layout.layouts.importKeptPinned' => ({required Object panels}) => '${panels}은(는) 유지됨: 작은 화면 배치에 꼭 필요합니다.',
			'operation.layout.layouts.notOffered' => '이 화면에서는 사용할 수 없음',
			'operation.layout.layouts.alreadyPlaced' => '이미 이 레이아웃에 있음',
			'operation.layout.layouts.needsExtension' => ({required Object name}) => '${name} 필요',
			'operation.layout.layouts.listRecoveredTitle' => '레이아웃 이름을 읽을 수 없습니다',
			'operation.layout.layouts.listRecoveredBody' => '이 화면의 레이아웃 목록을 읽을 수 없습니다. 모든 레이아웃은 그대로 있으며, 이름 대신 번호로 표시됩니다.',
			'operation.layout.editLayout' => '레이아웃 편집',
			'operation.layout.saveLayout' => '레이아웃 저장',
			'operation.layout.revertLayout' => '레이아웃 변경 사항 버리기',
			'operation.layout.done' => '완료',
			'operation.layout.layoutUnreadableTitle' => '레이아웃을 읽을 수 없습니다',
			'operation.layout.layoutUnreadableBody' => '저장된 레이아웃을 읽을 수 없어 기본 배치를 대신 표시합니다. 유지하기로 선택하기 전까지 원래 레이아웃을 덮어쓰지 않습니다.',
			'operation.layout.layoutUnreadableAction' => '이 레이아웃 사용',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel}을(를) 표시할 수 없습니다',
			'operation.layout.panelOverCharacters' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: ${max}자를 초과하는 내용을 보냈습니다',
			'operation.layout.panelOverElements' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 아트워크의 요소가 ${max}개를 초과합니다',
			'operation.layout.panelOverDepth' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 아트워크의 중첩 깊이가 ${max}단계를 초과합니다',
			'operation.layout.panelNotArtwork' => ({required Object panel}) => '${panel}을(를) 표시할 수 없습니다: 아트워크가 자체 완결형이 아닙니다',
			'operation.layout.panelOverLayers' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 레이어가 ${max}개를 초과합니다',
			'operation.layout.panelOverControls' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 컨트롤이 ${max}개를 초과합니다',
			'operation.layout.panelOverItems' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬의 일부에 항목이 ${max}개를 초과합니다',
			_ => null,
		} ?? switch (path) {
			'operation.layout.panelOverStringLength' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 씬 문자열이 ${max}자를 초과합니다',
			'operation.layout.panelOverLayoutDepth' => ({required Object panel, required Object max}) => '${panel}을(를) 표시할 수 없습니다: 레이아웃의 중첩 깊이가 ${max}단계를 초과합니다',
			'operation.layout.panelRenderRetry' => '다시 시도',
			'operation.layout.panelActionFailed' => '패널 작업에 실패했습니다. 다시 시도하세요.',
			'operation.layout.panels.loggingDescription' => '로그와 입력 필드',
			'operation.layout.panels.infoDescription' => '교신 중인 무선국에 대한 정보',
			'operation.layout.panels.spotsDescription' => '클러스터와 활동 프로그램의 스팟',
			'operation.layout.panels.mapDescription' => '교신 상대의 위치',
			'operation.layout.panels.summariesDescription' => '운용 통계와 점수를 원하는 섹션과 순서로 표시',
			'operation.layout.panels.summariesSections' => '섹션 및 순서',
			'operation.layout.panels.summariesDays' => '일별',
			'operation.layout.panels.summariesReset' => '모두 표시',
			'operation.layout.panels.summariesAllHidden' => '모든 섹션이 숨겨져 있습니다. 패널 설정에서 표시할 섹션을 선택하세요.',
			'operation.layout.panels.clockDescription' => '원하는 시간대의 시계',
			'operation.layout.panels.clockFace' => '시계 모양',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => '아날로그',
			'operation.layout.panels.clockZone' => '시간대',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => '이 기기',
			'operation.layout.panels.clockShowSeconds' => '초 표시',
			'operation.layout.panels.weatherDescription' => '운용 위치의 현재 및 향후 8시간 날씨',
			'operation.layout.panels.weatherUseOperationLocation' => '운용 위치 사용',
			'operation.layout.panels.weatherLocation' => '위치',
			'operation.layout.panels.weatherLocationDescription' => '그리드 스퀘어(FN31pr) 또는 위도,경도. \'운용 위치 사용\'이 선택되어 있으면 무시됩니다.',
			'operation.layout.panels.weatherNoLocation' => '위치가 설정되지 않았습니다. 패널 설정에서 위치를 지정하거나, 위치가 있는 운용 안에 패널을 배치하세요.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => '위치 ${location}을(를) 읽을 수 없습니다. FN31pr 같은 그리드 스퀘어나 42.36,-71.06 형식을 사용하세요.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo에 연결할 수 없습니다. 네트워크가 없나요? 잠시 후 다시 시도합니다.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo가 응답했지만 읽을 수 있는 내용이 아닙니다. 잠시 후 다시 시도합니다.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => '돌풍 ${speed}',
			'operation.layout.panels.panelAgeNow' => '방금',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}분 전', other: '${count}분 전', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}시간 전', other: '${count}시간 전', ), 
			'operation.layout.panels.weatherConditions.unknown' => '알 수 없음',
			'operation.layout.panels.weatherConditions.sunny' => '맑음',
			'operation.layout.panels.weatherConditions.clear' => '맑음',
			'operation.layout.panels.weatherConditions.mainlySunny' => '대체로 맑음',
			'operation.layout.panels.weatherConditions.mainlyClear' => '대체로 맑음',
			'operation.layout.panels.weatherConditions.partlyCloudy' => '구름 조금',
			'operation.layout.panels.weatherConditions.cloudy' => '흐림',
			'operation.layout.panels.weatherConditions.foggy' => '안개',
			'operation.layout.panels.weatherConditions.rimeFog' => '어는 안개',
			'operation.layout.panels.weatherConditions.lightDrizzle' => '약한 이슬비',
			'operation.layout.panels.weatherConditions.drizzle' => '이슬비',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => '강한 이슬비',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => '약한 어는 이슬비',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => '어는 이슬비',
			'operation.layout.panels.weatherConditions.lightRain' => '약한 비',
			'operation.layout.panels.weatherConditions.rain' => '비',
			'operation.layout.panels.weatherConditions.heavyRain' => '강한 비',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => '약한 어는 비',
			'operation.layout.panels.weatherConditions.freezingRain' => '어는 비',
			'operation.layout.panels.weatherConditions.lightSnow' => '약한 눈',
			'operation.layout.panels.weatherConditions.snow' => '눈',
			'operation.layout.panels.weatherConditions.heavySnow' => '강한 눈',
			'operation.layout.panels.weatherConditions.snowGrains' => '싸락눈',
			'operation.layout.panels.weatherConditions.lightShowers' => '약한 소나기',
			'operation.layout.panels.weatherConditions.showers' => '소나기',
			'operation.layout.panels.weatherConditions.heavyShowers' => '강한 소나기',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => '약한 소낙눈',
			'operation.layout.panels.weatherConditions.snowShowers' => '소낙눈',
			'operation.layout.panels.weatherConditions.thunderstorm' => '뇌우',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => '우박을 동반한 약한 뇌우',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => '우박을 동반한 뇌우',
			'operation.layout.panels.websiteDescription' => '원하는 웹 페이지를 패널에 표시',
			'operation.layout.panels.websiteUrl' => '주소',
			'operation.layout.panels.websiteRefresh' => '새로고침',
			'operation.layout.panels.websiteRefreshNever' => '안 함',
			'operation.layout.panels.websiteRefresh1' => '1분마다',
			'operation.layout.panels.websiteRefresh5' => '5분마다',
			'operation.layout.panels.websiteRefresh15' => '15분마다',
			'operation.layout.panels.websiteTitle' => '패널 이름',
			'operation.layout.panels.websiteRefreshNow' => '지금 새로고침',
			'operation.layout.panels.websiteNoUrl' => '아직 주소가 없습니다. 패널 설정을 열어 페이지를 선택하세요.',
			'operation.layout.panels.websiteBadUrl' => '웹 주소가 아닌 것 같습니다. https:// 로 시작해야 합니다',
			'operation.layout.panels.websiteNotHttps' => '여기에는 https:// 주소만 표시할 수 있습니다.',
			'operation.layout.panels.websiteUnsupported' => '이 시스템에서는 패널에 웹 페이지를 표시할 수 없습니다.',
			'operation.layout.panels.websiteOpenExternally' => '브라우저에서 열기',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => '페이지를 불러올 수 없습니다: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => '다른 기기에서 공유하는 화면, 앱 또는 창.',
			'operation.layout.panels.remoteScreenTarget' => '화면',
			'operation.layout.panels.remoteScreenChoose' => '화면 선택…',
			'operation.layout.panels.remoteScreenPickerTitle' => '공유된 화면',
			'operation.layout.panels.remoteScreenPickerEmpty' => '화면을 공유 중인 기기가 없습니다. 보려는 기기에서 설정 → 피어 기기의 화면 및 창 공유를 켜세요.',
			'operation.layout.panels.remoteScreenUnset' => '선택된 화면이 없습니다. 패널 설정을 열어 다른 기기가 공유 중인 화면을 선택하세요.',
			'operation.layout.panels.remoteScreenConnecting' => '연결 중…',
			'operation.layout.panels.remoteScreenPeerAway' => '해당 기기가 지금 연결되어 있지 않습니다.',
			'operation.layout.panels.remoteScreenNotOffered' => '해당 기기가 이 화면 공유를 중지했습니다.',
			'operation.layout.panels.remoteScreenNoListener' => '해당 기기가 연결을 받을 수 없습니다. 방화벽을 확인하세요.',
			'operation.layout.panels.remoteScreenNoLan' => '화면은 블루투스가 아닌 로컬 네트워크로만 공유됩니다.',
			'operation.layout.panels.remoteScreenRefused' => '해당 기기가 이 화면 공유를 거부했습니다.',
			'operation.layout.panels.remoteScreenSettings' => '패널 설정',
			'operation.layout.panels.remoteScreenAdjust' => '화면 조정',
			'operation.layout.panels.remoteScreenDetail' => '화질',
			'operation.layout.panels.remoteScreenDetailStandard' => '표준',
			'operation.layout.panels.remoteScreenDetailHigh' => '높음',
			'operation.layout.panels.remoteScreenDetailMaximum' => '최대',
			'operation.layout.panels.remoteScreenAdjustDone' => '확인',
			'operation.layout.panels.remoteScreenZoomIn' => '확대',
			'operation.layout.panels.remoteScreenZoomOut' => '축소',
			'operation.layout.panels.remoteScreenStopped' => '해당 화면 또는 창이 더 이상 표시되지 않습니다.',
			'operation.layout.panels.remoteScreenCaptureFailed' => '해당 기기가 화면을 캡처할 수 없습니다. 화면 기록 권한이 필요할 수 있습니다.',
			'operation.layout.panels.remoteScreenNoAnswer' => '해당 기기가 응답하지 않았습니다. 화면 공유가 켜져 있지 않을 수 있습니다.',
			'operation.layout.panels.remoteScreenNoMedia' => '화면 전송용 연결을 열 수 없습니다. 이 기기의 방화벽을 확인하세요.',
			'operation.layout.panels.solarDescription' => '태양 및 지자기 상태와 밴드별 전파 상황',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com에 연결할 수 없습니다. 네트워크가 없나요? 잠시 후 다시 시도합니다.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com이 응답했지만 사용할 수 있는 값이 아닙니다. 잠시 후 다시 시도합니다.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => '주간',
			'operation.layout.panels.solarBandNight' => '야간',
			'operation.layout.panels.solarBandGood' => '좋음',
			'operation.layout.panels.solarBandFair' => '보통',
			'operation.layout.panels.solarBandPoor' => '나쁨',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => '출처: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => '연결이 불안정합니다. 프레임을 건너뛰는 중입니다.',
			'operation.layout.panels.remoteScreenStalled' => '프레임이 전달되지 않습니다. 연결이 너무 느릴 수 있습니다.',
			'operation.layout.panels.radioDescription' => 'CAT으로 제어하는 무전기 전면 패널 — 주파수, 모드, 출력',
			'operation.layout.panels.radioStyle' => '스타일',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => '모던',
			'operation.layout.panels.radioRadio' => '무전기',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — 지정된 무전기 없음',
			'operation.layout.panels.radioNoRadio' => '표시할 무전기가 없습니다. 패널 설정에서 선택하거나 무선국 구성에서 추가하세요.',
			'operation.layout.panels.radioNotConfigured' => '이 무전기가 아직 구성되지 않았습니다. 무선국 구성에서 포트 또는 주소를 선택하세요.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => '무전기 연결 안 됨',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => '이 무전기 연결',
			'operation.layout.panels.radioDisconnect' => '이 무전기 연결 해제',
			'operation.layout.panels.radioStale' => '데이터 없음',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR 높음',
			'operation.layout.panels.rotatorDescription' => '무선국을 중심으로 한 지도에 안테나 방향을 표시합니다. 지도를 탭하면 회전합니다.',
			'operation.layout.panels.rotatorRotator' => '로테이터',
			'operation.layout.panels.rotatorAutoNamed' => ({required Object name}) => '자동 — ${name}',
			'operation.layout.panels.rotatorAutoNone' => '자동 — 아직 로테이터 없음',
			'operation.layout.panels.rotatorBeamWidth' => '빔 폭',
			'operation.layout.panels.rotatorBeamWidthDescription' => '도 단위로, 방위 주위에 그려집니다. 0이면 그리지 않습니다.',
			'operation.layout.panels.rotatorLocation' => '위치',
			'operation.layout.panels.rotatorLocationDescription' => '지도의 중심이 될 그리드 스퀘어 또는 위도와 경도. 비워 두면 운용 위치를 사용합니다.',
			'operation.layout.panels.rotatorTheme' => '테마',
			'operation.layout.panels.rotatorThemeColor' => '컬러',
			'operation.layout.panels.rotatorThemeGray' => '회색',
			'operation.layout.panels.rotatorThemeMuted' => '차분한 색',
			'operation.layout.panels.rotatorGrayline' => '그레이라인 표시',
			'operation.layout.panels.rotatorNoRotator' => '표시할 로테이터가 없습니다. 패널 설정에서 선택하거나 무선국 구성에서 추가하세요.',
			'operation.layout.panels.rotatorNoLocation' => '지도의 중심으로 삼을 위치가 없습니다. 패널 설정에서 설정하세요.',
			'operation.layout.panels.rotatorDisconnected' => '연결 끊김',
			'operation.layout.panels.rotatorNoReading' => '—',
			'operation.layout.panels.rotatorNotResponding' => '응답 없음',
			'operation.layout.panels.rotatorLocationInvalid' => '패널 설정의 위치를 읽을 수 없습니다. 그리드 스퀘어나 40.7, -74.0 같은 위도와 경도를 사용하세요.',
			'operation.layout.panels.rotatorElevation' => ({required Object degrees}) => 'EL ${degrees}°',
			'operation.layout.panels.rotatorNorth' => 'N',
			'operation.layout.panels.rotatorEast' => 'E',
			'operation.layout.panels.rotatorSouth' => 'S',
			'operation.layout.panels.rotatorWest' => 'W',
			'operation.layout.htmlPanelUnsupported' => '이 패널에는 웹 뷰가 필요하지만 이 플랫폼에서는 제공되지 않습니다',
			'operation.layout.htmlPanelUnsupportedOnWeb' => '이 패널에는 웹 버전에서 제공할 수 없는 샌드박스가 필요합니다',
			'operation.export.title' => '운용 내보내기',
			'operation.export.syncedOperation' => '운용이 동기화됨',
			'operation.export.unsyncedOperation' => '운용에 동기화되지 않은 변경 사항이 있음',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '이 운용에서 ${count} QSO', other: '이 운용에서 ${count} QSO', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'QSO ${total}개 모두 동기화됨',
			'operation.export.qsosPending' => ({required Object total, required Object pending}) => 'QSO ${total}개 중 ${pending}개 동기화 대기 중',
			'operation.export.eventsSynced' => ({required Object total}) => '이벤트 마커 ${total}개 동기화됨',
			'operation.export.eventsPending' => ({required Object total, required Object pending}) => '이벤트 마커 ${total}개 중 ${pending}개 대기 중',
			'operation.export.loading' => '내보내기 옵션 로딩 중…',
			'operation.export.noOptions' => '사용 가능한 내보내기 형식이 없습니다 (확장 기능 런타임이 아직 시작 중인가요?)',
			'operation.export.nothingLogged' => '아직 내보낼 것이 없습니다. 이 운용에 QSO가 없습니다.',
			'operation.export.share' => '공유',
			'operation.export.nothingSelected' => '선택된 항목 없음',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개 저장', other: '파일 ${count}개 저장', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개 공유', other: '파일 ${count}개 공유', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개 내보내기', other: '파일 ${count}개 내보내기', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개 다운로드', other: '파일 ${count}개 다운로드', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '통합 파일 ${count}개 저장', other: '통합 파일 ${count}개 저장', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '통합 파일 ${count}개 공유', other: '통합 파일 ${count}개 공유', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '통합 파일 ${count}개 내보내기', other: '통합 파일 ${count}개 내보내기', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '통합 파일 ${count}개 다운로드', other: '통합 파일 ${count}개 다운로드', ), 
			'operation.export.saveOne' => ({required Object name}) => '${name} 저장',
			'operation.export.shareOne' => ({required Object name}) => '${name} 공유',
			'operation.export.exportOne' => ({required Object name}) => '${name} 내보내기',
			'operation.export.downloadOne' => ({required Object name}) => '${name} 다운로드',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개 보관', other: '파일 ${count}개 보관', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '통합 파일 ${count}개 보관', other: '통합 파일 ${count}개 보관', ), 
			'operation.export.settingsButton' => '내보내기 설정',
			'operation.export.settingsTitle' => '내보내기 설정',
			'operation.export.compactFileNames.title' => '짧은 파일명 사용',
			'operation.export.compactFileNames.descriptionOn' => '업로드 도구용 짧은 이름, 예: N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => '읽기 쉬운 이름, 예: 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => '비공개 정보 포함',
			'operation.export.includePrivateData.descriptionOn' => '이름, 주소, 이메일, 그리드 스퀘어 및 메모가 포함됩니다',
			'operation.export.includePrivateData.descriptionOff' => '이름, 주소, 이메일, 그리드 스퀘어 및 메모가 제외됩니다',
			'operation.export.includePrivateData.note' => '전체 ADIF 내보내기에는 항상 모든 정보가 포함됩니다',
			'operation.export.resultTitle' => '내보내기 완료',
			'operation.export.resultFailedTitle' => '내보내기 실패',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개를 ${path}에 내보냈습니다', other: '파일 ${count}개를 ${path}에 내보냈습니다', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개를 내보냈습니다: ${path}', other: '파일 ${count}개를 내보냈습니다: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개를 공유했습니다', other: '파일 ${count}개를 공유했습니다', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '파일 ${count}개를 다운로드했습니다', other: '파일 ${count}개를 다운로드했습니다', ), 
			'operation.export.exportFailed' => ({required Object error}) => '내보내기 실패: ${error}',
			'operation.export.stash.needsEmailTitle' => '먼저 이메일 주소를 추가하세요',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash는 LoFi 계정의 이메일 주소로 파일을 보내며, stash.ham2k.net에서 그 주소로 로그인합니다. 계정에 아직 확인된 이메일이 없습니다. 설정 › 클라우드 동기화에서 추가하세요.',
			'operation.export.stash.openSyncSettings' => '클라우드 동기화 열기',
			'operation.export.stash.replaceTitle' => '최근 보관 항목이 대체됩니다',
			'operation.export.stash.replaceBody' => ({required Object name}) => '“${name}”을(를) 보낸 지 6시간이 지나지 않았고 아직 다운로드되지 않았습니다. 무료 계정은 한 번에 하나만 보관할 수 있으므로, 지금 보내면 기존 파일이 대체됩니다.',
			'operation.export.stash.replaceConfirm' => '어쨌든 보내기',
			'operation.export.stash.failedTitle' => 'Ham2K File Stash로 보낼 수 없습니다',
			'operation.export.stash.sentTitle' => 'Ham2K File Stash로 보냈습니다',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '어떤 브라우저에서든 **[stash.ham2k.net](https://stash.ham2k.net)** 에 접속하면 이 파일을 가져올 수 있습니다.', other: '어떤 브라우저에서든 **[stash.ham2k.net](https://stash.ham2k.net)** 에 접속하면 이 파일들을 가져올 수 있습니다.', ), 
			'operation.export.stash.mayHaveArrived' => 'File Stash에서 응답이 없습니다. 파일이 도착했을 수도 있습니다. 다시 보내기 전에 stash.ham2k.net을 확인하세요',
			'operation.export.stash.notSent' => '보내지 않음',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '이 파일이 도착하지 않았습니다:', other: '다음 파일 ${count}개가 도착하지 않았습니다:', ), 
			'operation.export.stash.emailOffer' => '또는 해당 링크를 이메일로 보내 드릴 수 있습니다.',
			'operation.export.stash.emailMe' => '링크를 이메일로 받기',
			'operation.export.stash.emailSent' => '다운로드 링크를 이메일로 보냈습니다.',
			'operation.export.stash.emailFailed' => ({required Object error}) => '이메일을 보낼 수 없습니다: ${error}',
			'operation.export.stash.freeTier' => '무료 계정은 한 번에 하나만 보관할 수 있습니다. 구독자는 원하는 만큼 보관할 수 있습니다.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: 'Ham2K File Stash(stash.ham2k.net)로 파일 ${count}개를 보냈습니다', other: 'Ham2K File Stash(stash.ham2k.net)로 파일 ${count}개를 보냈습니다', ), 
			'operation.spots.empty' => '필터와 일치하는 스팟이 없습니다',
			'operation.spots.error' => ({required Object error}) => '스팟을 불러오지 못했습니다: ${error}',
			'operation.spots.unknownBand' => '기타',
			'operation.spots.auto' => '자동',
			'operation.spots.autoValue' => ({required Object value}) => '자동 (현재 ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (자동)',
			'operation.spots.any' => '전체',
			'operation.spots.allBands' => '모든 밴드',
			'operation.spots.allModes' => '모든 모드',
			'operation.spots.phoneAndCw' => '보이스 및 CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개의 스팟', other: '${count}개의 스팟', ), 
			'operation.spots.spotsCountFiltered' => ({required Object total, required Object count}) => '스팟 ${total}개 중 ${count}개 표시 중',
			'operation.spots.spotsDisabled' => '이 운용에서는 스팟이 비활성화되어 있습니다',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes}분',
			'operation.spots.callsOfNote' => '주목할 콜사인',
			'operation.spots.yourSpots' => '내 스팟',
			'operation.spots.allSpots' => '모든 스팟',
			'operation.spots.continents.af' => '아프리카',
			'operation.spots.continents.as' => '아시아',
			'operation.spots.continents.eu' => '유럽',
			'operation.spots.continents.na' => '북미',
			'operation.spots.continents.oc' => '오세아니아',
			'operation.spots.continents.sa' => '남미',
			'operation.spots.continents.an' => '남극',
			'operation.spots.filters.title' => '스팟 필터',
			'operation.spots.filters.band' => '밴드',
			'operation.spots.filters.mode' => '모드',
			'operation.spots.filters.age' => '경과시간',
			'operation.spots.filters.sources' => '출처',
			'operation.spots.filters.continent' => '대륙',
			'operation.spots.filters.sorting' => '정렬',
			'operation.spots.filters.sortByTime' => '스팟 시간 별',
			'operation.spots.filters.sortByFrequency' => '주파수 별',
			'operation.spots.filters.sortByWanted' => '필요도 순',
			'operation.spots.filters.groupByBand' => '밴드별 그룹',
			'operation.spots.filters.groupCallsWithNotes' => '메모가 있는 콜사인 우선',
			'operation.spots.filters.alertingOnly' => '알림 있는 스팟만',
			'operation.spots.filters.sourceNoReply' => '응답 없음',
			'operation.spots.filters.sourceError' => '오류',
			'operation.spots.unavailableTitle' => '스팟을 사용할 수 없음',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources}이(가) 응답하지 않았습니다.',
			'operation.spots.failedTitle' => '스팟 출처 오류',
			'operation.spots.failedText' => ({required Object sources}) => '${sources}이(가) 오류를 반환했습니다.',
			'operation.spots.slideLogIt' => '로깅',
			'operation.spots.slideIgnore' => '무시',
			'operation.spots.slideRestore' => '복원',
			'operation.spots.logConflict.title' => '로깅 패널이 사용 중입니다',
			'operation.spots.logConflict.editingBody' => '로깅된 교신을 수정하고 있습니다. 대신 이 스팟을 로깅할까요, 아니면 돌아가서 수정을 마칠까요?',
			'operation.spots.logConflict.composingBody' => '교신 입력을 시작했습니다. 대신 이 스팟을 로깅할까요, 아니면 돌아가서 입력을 마칠까요?',
			'operation.spots.logConflict.goBack' => '돌아가기',
			'operation.spots.logConflict.clearAndLog' => '지우고 스팟 로깅',
			'operation.import.title' => '운용에 데이터 가져오기',
			'operation.import.importAdifAction' => 'ADIF에서 QSO 가져오기',
			'operation.import.settingsButton' => '수신 설정',
			'operation.import.settingsTitle' => '다른 앱 수신 대기',
			'operation.import.protocolAddressLabel' => '주소',
			'operation.import.protocolPortLabel' => '포트',
			'operation.import.protocolPortInvalid' => '1에서 65535 사이의 포트를 입력하세요',
			'operation.import.protocolAddressInvalid' => '올바른 IP 주소를 입력하세요 (예: 127.0.0.1 또는 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => '데이터 수신 중',
			'operation.import.protocolStatusNoData' => '최근 수신된 데이터 없음',
			'operation.import.protocolBindError' => ({required Object error}) => '수신 대기를 시작할 수 없습니다: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => '들어온 QSO를 저장할 수 없어 다시 시도 중입니다: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => '전체 (브로드캐스트)',
			'operation.import.wsjtxProtocolName' => 'WSJT-X UDP Server',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → Broadcast Data 탭 → 교신 정보에 대해 "Enable Broadcasts"를 체크하세요. 같은 컴퓨터에서 실행 중이면 IP 주소를 127.0.0.1로, 현재 로컬 네트워크에 브로드캐스트하려면 255.255.255.255로 설정하세요.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → Reporting 탭 → UDP Server 섹션 → "Accept UDP requests"를 체크하세요. 같은 컴퓨터에서 실행 중이면 UDP Server를 127.0.0.1로, 아니면 239.239.0.2 같은 멀티캐스트 주소로 설정하고, 이 앱의 위 설정에도 같은 주소를 사용하세요.',
			'operation.import.listenTitle' => '다른 앱의 QSO 수신 대기',
			'operation.import.listenDescriptionOnN1mm' => 'N1MM+ 수신 대기 중',
			'operation.import.listenDescriptionOnWsjtx' => 'WSJT-X 수신 대기 중',
			'operation.import.listenDescriptionOnBoth' => 'N1MM+ 및 WSJT-X 수신 대기 중',
			'operation.import.listenDescriptionOff' => '꺼짐',
			'operation.import.addToOperationTitle' => '이 운용에 추가',
			'operation.import.addToOperationDescriptionOn' => '수신한 QSO가 도착하는 대로 이 운용에 추가됩니다',
			'operation.import.addToOperationDescriptionOff' => '이 옵션을 켤 때까지 수신한 QSO를 보관합니다',
			'operation.import.pendingSectionTitle' => '수신한 QSO',
			'operation.import.pendingEmpty' => '아직 수신한 항목 없음',
			'operation.import.stationMismatch' => ({required Object call}) => '이 운용의 무선국이 아닌 ${call}(으)로 로깅됨',
			'operation.import.discardAction' => '버리기',
			'operation.import.gapDialogTitle' => '이전에 수신한 항목도 포함할까요?',
			'operation.import.gapDialogBody' => ({required Object count}) => '데이터 공백 이전에 수신한 QSO가 ${count}개 더 있습니다. 함께 포함할까요?',
			'operation.import.gapDialogRecentOnly' => '최근 항목만',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => '${count}개 모두 포함',
			'map.outlineIssue.link' => '문제가 있나요?',
			'map.outlineIssue.title' => '경계선 문제 신고',
			'map.outlineIssue.reference' => '해당 경계선',
			'map.outlineIssue.severity' => '얼마나 심각한가요?',
			'map.outlineIssue.minor' => '사소함',
			'map.outlineIssue.major' => '심각함',
			'map.outlineIssue.explanation' => '무엇이 잘못되었나요?',
			'map.outlineIssue.explanationHint' => '경계선의 어느 부분이 어떻게 잘못되었는지',
			'map.outlineIssue.send' => '보내기',
			'map.outlineIssue.sending' => '신고를 보내는 중입니다. 감사합니다',
			'map.outlineIssue.copy' => '신고 내용 복사',
			'map.outlineIssue.notSent' => '신고를 보낼 수 없습니다',
			'map.outlineIssue.copied' => '신고 내용이 복사되었습니다',
			'map.outlineIssue.notCopied' => '신고 내용을 복사할 수 없습니다',
			'map.outlinesDisclaimer' => '경계선은 참고용입니다. 직접 확인하세요!',
			'map.outlinesCredit' => ({required Object sources}) => '경계선: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => '행정 경계: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => '시설: ${sources}',
			'map.fullCredits' => '전체 데이터 출처',
			'map.fewerCredits' => '출처 줄이기',
			'map.emptyState' => '아직 QSO 위치가 없습니다.\n그리드 스퀘어, 주 또는 국가가 있는 QSO가 여기에 표시됩니다.',
			'map.unavailable' => '지금은 지도를 사용할 수 없습니다.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => '평면',
			'map.globe' => '지구본',
			'map.zoomIn' => '확대',
			'map.zoomOut' => '축소',
			'map.resetNorth' => '북쪽을 위로',
			'map.postcard.button' => '운용 엽서',
			'map.postcard.title' => ({required Object title}) => '${title} 엽서',
			'map.postcard.portrait' => '세로',
			'map.postcard.landscape' => '가로',
			'map.postcard.square' => '정사각형',
			'map.postcard.save' => '저장…',
			'map.postcard.download' => '다운로드',
			'map.postcard.share' => '공유',
			'map.postcard.copy' => '복사',
			'map.postcard.copied' => '클립보드에 복사되었습니다',
			'map.postcard.saved' => ({required Object path}) => '${path}에 저장되었습니다',
			'map.postcard.downloaded' => ({required Object name}) => '${name} 다운로드됨',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '이미지 ${count}개를 ${path}에 저장했습니다',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} 저장됨',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names}은(는) 이미 저장되었습니다',
			'map.postcard.downloadedMany' => ({required Object count}) => '이미지 ${count}개 다운로드 중 — 브라우저가 물으면 허용하세요',
			'map.postcard.mapLeftOut' => '지도가 로드되지 않아 제외되었습니다',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — 지도가 로드되지 않아 제외되었습니다',
			'map.postcard.continued' => ({required Object title}) => '${title} (계속)',
			'map.postcard.previousPage' => '이전 페이지',
			'map.postcard.nextPage' => '다음 페이지',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => '${page} / ${count} 페이지',
			'map.postcard.bandQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count} Q', other: '${count} Q', ), 
			'map.postcard.options' => '엽서 옵션',
			'map.postcard.bandLegend' => '밴드 범례 표시',
			'map.postcard.grayline' => '그레이라인 표시',
			'map.postcard.sectionsAndOrder' => '요약 섹션 및 순서',
			'map.postcard.sectionDays' => '일별',
			'map.postcard.reset' => '초기화',
			'map.postcard.failed' => ({required Object error}) => '엽서를 만들 수 없습니다: ${error}',
			'map.postcard.mapNotReady' => '지도 로딩이 끝나지 않았습니다. 연결을 확인하고 다시 시도하세요.',
			'map.postcard.saveFailed' => ({required Object error}) => '엽서를 저장할 수 없습니다: ${error}',
			'map.postcard.copyFailed' => '클립보드에 이미지를 복사하지 못했습니다. 다시 시도하세요.',
			'map.postcard.shareFailed' => '엽서를 공유할 수 없습니다. 다시 시도하세요.',
			'map.postcard.fileName' => '엽서',
			'mapsView.title' => '지도',
			'mapsView.searchHint' => '공원, 산정상 등 검색',
			'mapsView.activities' => '활동',
			'mapsView.layers' => '레이어',
			'mapsView.baseMap' => '기본 지도',
			'mapsView.satellite' => '위성 (Esri)',
			'mapsView.facilities' => '공원 시설',
			'mapsView.boundaries' => '행정 경계',
			'mapsView.currentLocation' => '현재 위치',
			'mapsView.noMatches' => ({required Object text}) => '“${text}”과(와) 일치하는 항목이 없습니다',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${where}의 레퍼런스 ${count}개', other: '${where}의 레퍼런스 ${count}개', ), 
			'mapsView.startOperation' => '이 레퍼런스로 운용 시작',
			'activitiesView.title' => '활동',
			'activitiesView.activitiesCountZero' => '선택된 활동 없음',
			'activitiesView.activitiesCountOne' => '활동 1개',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '활동 ${count}개',
			'activitiesView.empty' => '아직 활동이 없습니다. 아래의 추천 및 검색으로 추가하세요',
			'activitiesView.removeActivity' => '제거',
			'activitiesView.openReferenceLink' => ({required Object name}) => '${name} 열기',
			'activitiesView.editActivity' => '활동 편집',
			'activitiesView.manageExtensions' => '확장 기능 관리',
			'activitiesView.manage' => '관리',
			'activitiesView.activitiesTitle1' => ({required Object first}) => '활동 유형: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => '활동 유형: ${first}, ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => '활동 유형: ${first}, ${second} 외 ${more}개',
			'activitiesView.reference' => '레퍼런스',
			'activitiesView.invalidReference' => '유효하지 않음',
			'activitiesView.duplicateReference' => '이미 추가됨',
			'activitiesView.searchHint' => '이름, 레퍼런스 등으로 검색…',
			'activitiesView.noSuggestions' => '일치 항목 없음',
			'activitiesView.noSuggestionsHint' => '위에서 레퍼런스 이름이나 번호로 검색하세요',
			'activitiesView.noSuggestionsExample' => '(예: \'trail\' 또는 \'4556\')',
			'activitiesView.allOptions' => '활동 유형',
			'activitiesView.determiningLocation' => '현재 위치 확인 중…\n근처 레퍼런스를 찾기 위해 GPS 수신 대기 중',
			'activitiesView.locationUnavailableTitle' => '위치 데이터를 사용할 수 없음',
			'activitiesView.locationDeniedTitle' => '위치 권한 거부됨',
			'activitiesView.locationBlockedTitle' => '위치 권한 차단됨',
			'activitiesView.noNearbyReason' => '근처 레퍼런스를 확인할 수 없습니다',
			'activitiesView.locationManualHint' => ({required Object icon}) => '${icon}을(를) 탭하여 위치를 직접 입력하거나,\n이름으로 레퍼런스를 검색하세요',
			'activitiesView.locationGrantAction' => '위치 접근 허용',
			'activitiesView.locationSettingsAction' => '설정 열기',
			'activitiesView.locationSettingsUnavailable' => '시스템 설정에서 위치 접근을 허용하세요',
			'activitiesView.locationGrantRefused' => '여전히 위치 없음 — 시스템이 다시 거부했습니다',
			'activitiesView.searchUnavailableTitle' => '활동 검색을 사용할 수 없음',
			'activitiesView.searchUnavailableReason' => '활동 확장 기능이 검색에 응답하지 못했습니다. 잠시 후 다시 시도하세요.',
			'activitiesView.emptySheet' => '아래의 추천 및 검색으로 추가하세요',
			'activitiesView.exports' => '내보내기',
			'activitiesView.exportLogs' => '로그 내보내기',
			'activitiesView.tools' => '도구',
			'activitiesView.toolsTitle' => '운용 도구',
			'activitiesView.operationDetails' => '운용 상세',
			'activitiesView.share' => '공유',
			'activitiesView.archive' => '아카이브',
			'activitiesView.deleteOperation' => '운용 삭제',
			'activitiesView.undeleteOperation' => '운용 복구',
			'activitiesView.alreadySelected' => '이미 선택됨',
			'activitiesView.selected' => '선택됨',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} / ${count}',
			'activitiesView.previousPick' => '이전 일치 항목',
			'activitiesView.nextPick' => '다음 일치 항목',
			'activitiesView.retiredReference' => '폐지됨',
			'activitiesView.enableExtension' => ({required Object name}) => '${name} 활성화',
			'activitiesView.enableExtensionHint' => '이 확장 기능이 검색과 일치하지만 현재 활성화되어 있지 않습니다',
			'activitiesView.enableExtensionForRefHint' => '이 확장 기능이 이 운용의 레퍼런스 중 하나를 처리하지만 현재 활성화되어 있지 않습니다',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name}이(가) 실행되고 있지 않습니다',
			'activitiesView.extensionNotRunningHint' => '이 확장 기능은 비활성화되었습니다. 자세한 내용은 확장 기능 설정을 여세요',
			'activitiesView.installExtension' => ({required Object name}) => '${name} 설치',
			'activitiesView.installExtensionHint' => '이 확장 기능이 검색과 일치하지만 설치되어 있지 않습니다',
			'activitiesView.onlyCatalogMatches' => '일치 항목 없음\n카탈로그의 일부 확장 기능에 결과가 있을 수 있습니다.\n아래 활동 유형에서 설치하세요.',
			'activitiesView.setupUnavailable' => '이 활동의 설정을 불러올 수 없습니다. 관리에서 다시 시도하세요',
			'activitiesView.controlsUnavailableTitle' => '활동 컨트롤을 사용할 수 없음',
			'activitiesView.controlsUnavailableReason' => '레퍼런스는 안전하지만 지금은 편집할 수 없습니다.',
			'activitiesView.controlsUnavailableRetry' => '다시 시도',
			'activitiesView.onlyDisabledMatches' => '일치 항목 없음\n사용 가능한 일부 확장 기능에 결과가 있을 수 있습니다.\n아래 활동 유형에서 활성화하세요.',
			'activitiesView.onlyNotRunningMatches' => '일치 항목 없음\n결과가 있을 수 있는 일부 확장 기능이 실행되고 있지 않습니다.\n아래 활동 유형을 확인하세요.',
			'activitiesView.mapToggle' => '지도',
			'activitiesView.searchToggle' => '검색',
			'activitiesView.addToOperation' => '운용에 추가',
			'activitiesView.addToOperationShort' => '운용에 추가',
			'activitiesView.mapEmptyState' => '지도에 표시할 결과가 없습니다',
			'activitiesView.mapEmptyStateHint' => '목록으로 돌아가거나 다른 항목을 검색하세요',
			'activitiesView.imports' => '가져오기',
			'loggingControls.timeUtc' => '시간 (UTC)',
			'loggingControls.date' => '날짜',
			'loggingControls.now' => '현재',
			'loggingControls.manualTimeSettings' => '수동 시간',
			'loggingControls.manualTimeIncrement' => 'QSO당 증가량',
			'loggingControls.manualTimeIncrementNone' => '없음',
			'loggingControls.manualTimeIncrementMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}분', other: '${count}분', ), 
			'loggingControls.frequency' => '주파수',
			'loggingControls.mode' => '모드',
			'loggingControls.theirCall' => '상대 콜사인',
			'loggingControls.noteField' => '메모',
			'loggingControls.todoField' => '할 일',
			'loggingControls.sent' => '보냄',
			'loggingControls.rcvd' => '받음',
			'loggingControls.more' => '더보기',
			'loggingControls.revert' => '되돌리기',
			'loggingControls.undoDelete' => '삭제 취소',
			'loggingControls.restore' => '복원',
			'loggingControls.wipe' => '지우기',
			'loggingControls.undo' => '실행 취소',
			'loggingControls.pendingDeleteTapWarning' => '이 QSO를 삭제하려면 휴지통을 한 번 더 탭하세요',
			'loggingControls.pendingDeleteClickWarning' => '이 QSO를 삭제하려면 휴지통을 한 번 더 클릭하세요',
			'loggingControls.deletedQsoWarning' => '삭제된 QSO',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => '이 ${kind}을(를) 삭제하려면 휴지통을 한 번 더 탭하세요',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => '이 ${kind}을(를) 삭제하려면 휴지통을 한 번 더 클릭하세요',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '삭제된 ${kind}',
			'loggingControls.timeControl' => '시간',
			'loggingControls.radioControl' => '무전기',
			'loggingControls.powerControl' => '출력',
			'loggingControls.notesControl' => '메모',
			'loggingControls.power' => '출력',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => '로깅 컨트롤',
			'loggingControls.spottingControl' => '스팟',
			'loggingControls.spottingSelfControl' => '자체 스팟',
			'loggingControls.spotSelfAt' => ({required Object freq}) => '${freq}에서 자체 스팟',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => '${call}을(를) ${freq}에서 스팟',
			'loggingControls.spotTooLate' => ({required Object call}) => '${call}을(를) 스팟하기에 너무 늦었습니다',
			'loggingControls.spotNoFreq' => '스팟하려면 먼저 주파수를 지정하세요',
			'loggingControls.selfSpotDisabled' => '자체 스팟 비활성화됨',
			'loggingControls.spotComment' => '코멘트',
			'loggingControls.spottingAutoControl' => '자동 재스팟',
			'loggingControls.spotAutoEvery' => ({required Object minutes}) => '${minutes}분마다 재스팟',
			'loggingControls.spotAutoNext' => ({required Object time}) => '${time} 후 자동. 중지할까요?',
			'loggingControls.spotAutoInMinutes' => ({required Object minutes}) => '${minutes}분 후 자동',
			'loggingControls.spotAutoInSeconds' => ({required Object seconds}) => '${seconds}초 후 자동',
			'loggingControls.spotAutoInCount' => ({required Object seconds}) => '${seconds} 후 자동',
			'loggingControls.spotAutoNotStarted' => '자동 재스팟 시작 안 됨: 스팟이 전송되지 않았습니다',
			'loggingControls.spotAutoMoved' => '자동 재스팟 시작 안 됨: 스팟 중에 주파수가 변경되었습니다',
			'loggingControls.spotAutoStopped' => '자동 재스팟 중지됨',
			'loggingControls.spotAutoLeftFreq' => '자동 재스팟 중지됨: 주파수가 변경되었습니다',
			'loggingControls.spotAutoNoFreq' => '자동 재스팟 중지됨: 무전기가 주파수를 보고하지 않습니다',
			'loggingControls.spotBusy' => '다른 스팟을 아직 전송 중입니다',
			'loggingControls.bandOrFreqRequired' => '로깅 전에 주파수나 밴드를 지정하세요',
			'loggingControls.missingBand' => '밴드 없음',
			'loggingControls.missingMode' => '모드 없음',
			'loggingControls.saveFailed' => ({required Object error}) => '저장할 수 없습니다: ${error}',
			_ => null,
		} ?? switch (path) {
			'loggingControls.deleteFailed' => ({required Object error}) => '삭제할 수 없습니다: ${error}',
			'loggingControls.info.noQsos' => '아직 QSO가 없습니다... 운용을 시작하세요!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSO',
			'loggingControls.info.qsosInTime' => ({required Object time, required Object count}) => '${time} 동안 ${count}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '최근 QSO로부터 ${time}',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '최근 10개: ${rate} Q/h',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '최근 100개: ${rate} Q/h',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} →',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) →',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) →',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} 거리',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) 거리',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) 거리',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => '중복!',
			'loggingControls.info.noticeNewBand' => '새로운 밴드',
			'loggingControls.info.noticeNewMode' => '새로운 모드',
			'loggingControls.info.noticeNewDXCC' => '새로운 DXCC',
			'loggingControls.info.noticeNewState' => '새로운 주',
			'loggingControls.info.noticeNewProvince' => '새로운 주/도',
			'loggingControls.info.noticeNewDay' => '새로운 날짜',
			'loggingControls.info.noticeNewRef' => '새로운 레퍼런스',
			'loggingControls.info.noticeNewMult' => '새로운 Mult',
			'loggingControls.info.noticeNewZone' => '새로운 존',
			'loggingControls.info.noticeInvalidMode' => '잘못된 모드',
			'loggingControls.info.noticeInvalidBand' => '잘못된 밴드',
			'loggingControls.info.noticeInvalidCategory' => '교신 불가',
			'loggingControls.info.noticeOverTime' => '시간 종료',
			'loggingControls.info.noticeWorkedBefore' => '이전에 교신함',
			'loggingControls.info.noticeNewPark' => '새로운 공원',
			'loggingControls.info.noticeNewSection' => '새로운 섹션',
			'loggingControls.info.noticeBonusStation' => '보너스 무선국!',
			'loggingControls.info.noticeMissingExchange' => '교환 없음',
			'loggingControls.info.noticeInvalidExchange' => '잘못된 교환',
			'loggingControls.info.noticeUnknownEvent' => '알 수 없는 이벤트',
			'loggingControls.info.noticeIncompleteCall' => '불완전한 콜사인 — 점수 미반영',
			'loggingControls.info.noticeOurGrid' => '내 그리드 설정',
			'loggingControls.info.noticeRareCounty' => '희귀 카운티!',
			'loggingControls.info.noticeOurLocation' => '내 카운티 설정',
			'loggingControls.info.noticeShortGrid' => '그리드가 너무 짧음',
			'formChrome.untitled' => '(제목 없음)',
			'formChrome.showMore' => '더 보기',
			'formChrome.showAll' => '모두 보기',
			'formChrome.showFewer' => '간략히 보기',
			'formChrome.defaults' => '기본값',
			'formChrome.search' => '검색',
			'formChrome.clear' => '지우기',
			'formChrome.openPage' => '페이지 열기',
			'formChrome.connected' => '연결됨',
			'formChrome.notConnected' => '연결 안 됨',
			'formChrome.manage' => '관리',
			'formChrome.connect' => '연결',
			'formChrome.formTitle' => '양식',
			'formChrome.addItem' => ({required Object label}) => '${label} 추가',
			'formChrome.editItem' => ({required Object label}) => '${label} 편집',
			'formChrome.multiselectStatus' => ({required Object total, required Object shown, required Object selected}) => '${total}개 중 ${shown}개 표시 (${selected}개 선택됨)',
			'formChrome.validationError' => ({required Object error}) => '유효성 검사 오류: ${error}',
			'formChrome.transformationError' => ({required Object error}) => '변환 오류: ${error}',
			'formChrome.actionError' => ({required Object error}) => '오류: ${error}',
			'formChrome.removeItem' => '삭제',
			'formChrome.deleteItemTitle' => ({required Object name}) => '${name}을(를) 삭제할까요?',
			'formChrome.storageUnavailable' => '로그인 정보를 사용할 수 없음',
			'qsoEditForm.title' => 'QSO 수정',
			'qsoEditForm.operatorCall' => '오퍼레이터',
			'qsoEditForm.position' => '포지션',
			'qsoEditForm.theirName' => '이름',
			'qsoEditForm.theirGrid' => '그리드',
			'qsoEditForm.theirState' => '주',
			'qsoEditForm.band' => '밴드',
			'qsoEditForm.notes' => '메모',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => '상대의 정보',
			'qsoEditForm.sectionOur' => '나의 정보',
			'qsoEditForm.sectionNotes' => '메모',
			'qsoEditForm.theirCity' => '도시',
			'qsoEditForm.theirCounty' => '시/군',
			'qsoEditForm.theirEntity' => '엔티티',
			'qsoEditForm.theirCqZone' => 'CQ 존',
			'qsoEditForm.theirItuZone' => 'ITU 존',
			'qsoEditForm.theirArrlSection' => 'ARRL 섹션',
			'qsoEditForm.theirLat' => '위도',
			'qsoEditForm.theirLon' => '경도',
			'qsoEditForm.theirPower' => '상대 출력',
			'qsoList.empty' => '아직 QSO가 없습니다. 교신을 시작하세요!',
			'qsoList.bandOrModeWarning' => '밴드와 모드가 올바른지 확인하세요',
			'qsoList.today' => '오늘',
			'qsoList.yesterday' => '어제',
			'qsoList.tomorrow' => '내일',
			'qsoList.find.menuItem' => ({required Object shortcut}) => '로그에서 찾기 (${shortcut})',
			'qsoList.find.menuItemNoShortcut' => '로그에서 찾기',
			'qsoList.find.hint' => 'QSO 번호 또는 콜사인',
			'qsoList.find.noMatches' => '일치 항목 없음',
			'qsoList.find.noOperationQsos' => '이 운용에 QSO 없음',
			'qsoList.find.noPeriodQsos' => '이 기간에 QSO 없음',
			'qsoList.find.outsideQsosOne' => '이 운용 밖의 QSO 1개',
			'qsoList.find.outsideQsosOther' => ({required Object count}) => '이 운용 밖의 QSO ${count}개',
			'qsoList.find.pastQsosOne' => '이전 QSO 1개',
			'qsoList.find.pastQsosOther' => ({required Object count}) => '이전 QSO ${count}개',
			'loggingPanel.stats' => '운용 통계',
			'loggingPanel.scoring' => '점수',
			'loggingPanel.dxccEntities' => 'DXCC 엔티티',
			'loggingPanel.statesWorked' => '주',
			'loggingPanel.provincesWorked' => '주/도',
			'loggingPanel.duplicates' => '중복',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => '이미지 표시',
			'callInfo.imageUnavailable' => '사진을 사용할 수 없음',
			'callInfo.photo' => '사진',
			'callInfo.notes' => '메모',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} →',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) →',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) →',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} 거리',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) 거리',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) 거리',
			'callInfo.thisOpCountOne' => '이 운용에서 1 QSO',
			'callInfo.thisOpCountOther' => ({required Object count}) => '이 운용에서 ${count} QSO',
			'callInfo.otherOpsCountOne' => '다른 운용에서 1 QSO',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '다른 운용에서 ${count} QSO',
			'callInfo.andMore' => ({required Object count}) => '… + ${count}개',
			'callInfo.withCall' => ({required Object call}) => '${call}와 함께',
			'callInfo.fromOperation' => ({required Object where}) => '${where}에서',
			'callInfo.history.last7days' => ({required Object n}) => '지난 7일간 ${n}개',
			'callInfo.history.today' => ({required Object n}) => '오늘 ${n}개',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.title' => '설정',
			'settings.language' => '언어',
			'settings.languageSystem' => ({required Object language}) => '시스템 설정 따르기 (${language})',
			'settings.theme.title' => '테마 모드',
			'settings.theme.system' => '시스템 설정 따르기',
			'settings.theme.light' => '라이트',
			'settings.theme.dark' => '다크',
			'settings.themeDescription.system' => '시스템 설정을 따름',
			'settings.themeDescription.light' => '항상 라이트 모드',
			'settings.themeDescription.dark' => '항상 다크 모드',
			'settings.fontScale' => '글꼴 크기',
			'settings.fontScaleOpts.smallestMinusMinus' => '아주 작게--',
			'settings.fontScaleOpts.smallestMinus' => '아주 작게-',
			'settings.fontScaleOpts.smallest' => '아주 작게',
			'settings.fontScaleOpts.smaller' => '작게',
			'settings.fontScaleOpts.normal' => '표준',
			'settings.fontScaleOpts.larger' => '크게',
			'settings.fontScaleOpts.largest' => '아주 크게',
			'settings.fontScaleOpts.largestPlus' => '아주 크게+',
			'settings.fontScaleOpts.largestPlusPlus' => '아주 크게++',
			'settings.keepDeviceAwake.title' => '기기 화면 켜짐 유지하기',
			'settings.keepDeviceAwake.descriptionOn' => '로깅 화면에 있거나 동기화 중일 때 화면 켜짐 유지',
			'settings.keepDeviceAwake.descriptionOff' => '평소처럼 화면 잠금 허용',
			'settings.layoutDensity' => '레이아웃 밀도',
			'settings.layoutDensityOpts.auto' => '자동',
			'settings.layoutDensityOpts.densest' => '가장 조밀하게',
			'settings.layoutDensityOpts.dense' => '조밀하게',
			'settings.layoutDensityOpts.normal' => '표준',
			'settings.layoutDensityOpts.sparse' => '여유 있게',
			'settings.layoutDensityOpts.sparsest' => '가장 여유 있게',
			'settings.layoutDensityClamped' => ({required Object effective}) => '창 높이가 너무 낮아 ${effective} 사용 중',
			'settings.layoutDensityAtLimit' => '최대한 적용됨',
			'settings.distanceUnits' => '거리 단위',
			'settings.distanceUnitsOpts.kilometers' => '킬로미터',
			'settings.distanceUnitsOpts.miles' => '마일',
			'settings.userInterface' => '사용자 인터페이스',
			'settings.logging.title' => '로깅',
			'settings.logging.leftieMode.title' => '왼손잡이 모드',
			'settings.logging.leftieMode.descriptionOn' => '왼손잡이용 레이아웃 사용',
			'settings.logging.leftieMode.descriptionOff' => '오른손잡이용 레이아웃 사용',
			'settings.logging.countryFlags.title' => '국가 깃발 표시',
			'settings.logging.countryFlags.dx' => 'DX 교신에만 표시',
			'settings.logging.countryFlags.all' => '모든 교신에 깃발 표시',
			'settings.logging.countryFlags.none' => '깃발 표시하지 않음',
			'settings.logging.countryFlagsDescription.dx' => 'DX 교신에만 깃발 표시',
			'settings.logging.countryFlagsDescription.all' => '모든 교신에 깃발 표시 중',
			'settings.logging.countryFlagsDescription.none' => '깃발 표시하지 않음',
			'settings.logging.suggestDefaultOperator.title' => '오퍼레이터 제안',
			'settings.logging.suggestDefaultOperator.descriptionOn' => '운용의 무선국 콜사인이 다를 때 내 콜사인을 오퍼레이터로 제안',
			'settings.logging.suggestDefaultOperator.descriptionOff' => '직접 입력하지 않으면 오퍼레이터를 비워 둠',
			'settings.logging.showBearing.title' => '방위각 표시',
			'settings.logging.showBearing.descriptionOn' => '무선국까지의 예상 방위각 표시',
			'settings.logging.showBearing.descriptionOff' => '방위각 정보 표시하지 않음',
			'settings.logging.showReverseBearing.title' => '역방위각도 표시',
			'settings.logging.showReverseBearing.descriptionOn' => '무선국 기준 방위각도 "45° / 225°"처럼 표시',
			'settings.logging.showReverseBearing.descriptionOff' => '무선국까지의 방위각만 표시',
			'settings.logging.switchSentRcvd.title' => '시그널 리포트 순서 변경',
			'settings.logging.switchSentRcvd.sentFirst' => '보낸 RST -> 받은 RST',
			'settings.logging.switchSentRcvd.rcvdFirst' => '받은 RST -> 보낸 RST',
			'settings.logging.jumpAfterRST.title' => 'RST 입력 후 다음 필드로 자동 점프',
			'settings.logging.jumpAfterRST.descriptionOn' => 'RST 입력 후 다음 필드로 이동',
			'settings.logging.jumpAfterRST.descriptionOff' => '자동으로 이동하지 않음',
			'settings.logging.defaultReport.title' => '기본 리포트 — 보이스',
			'settings.logging.defaultReport.description' => 'SSB, FM 또는 AM에서 보냄 또는 받음이 비어 있을 때 사용',
			'settings.logging.defaultReportCW.title' => '기본 리포트 — CW 및 데이터',
			'settings.logging.defaultReportCW.description' => 'CW, RTTY 및 기타 데이터 모드에서 보냄 또는 받음이 비어 있을 때 사용',
			'settings.logging.defaultReportFT8.title' => '기본 리포트 — FT8 및 FT4',
			'settings.logging.defaultReportFT8.description' => 'FT 모드에서 보냄 또는 받음이 비어 있을 때 사용',
			'settings.logging.numbersRow.title' => '숫자 키보드',
			'settings.logging.numbersRow.description' => '로깅 중 키보드 위에 숫자 키 행 표시',
			'settings.logging.numbersRowExtra.title' => '슬래시 및 마침표 키',
			'settings.logging.numbersRowExtra.description' => '상황에 맞는 키 추가: 콜사인에는 “/”, 숫자에는 “.”',
			'settings.logging.numbersRowVibrate.title' => '키 누를 때 진동',
			'settings.logging.numbersRowVibrate.description' => '숫자 키를 탭할 때 햅틱 피드백',
			'settings.logging.bands' => '선호 밴드',
			'settings.logging.modes' => '선호 모드',
			'settings.catServer.title' => 'CAT 서버',
			'settings.catServer.description' => '다른 앱(WSJT-X, 로거 등)이 Ham2K Logger를 통해 무전기를 제어할 수 있도록 허용합니다.',
			'settings.catServer.protocol' => '프로토콜',
			'settings.catServer.protocolOpts.off' => '비활성화됨',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => '포트',
			'settings.catServer.openAccess' => '외부 접근 허용',
			'settings.catServer.openAccessOn' => '로컬 네트워크의 모든 컴퓨터가 연결할 수 있습니다.',
			'settings.catServer.openAccessOff' => '이 컴퓨터의 앱만 연결할 수 있습니다.',
			'settings.catServer.allowTransmit' => '앱의 송신 허용',
			'settings.catServer.allowTransmitOn' => ({required Object minutes}) => '앱이 무전기의 PTT를 한 번에 최대 ${minutes}분까지 누를 수 있습니다.',
			'settings.catServer.allowTransmitOnNetwork' => ({required Object minutes}) => '로컬 네트워크의 모든 컴퓨터에 있는 앱이 무전기의 PTT를 한 번에 최대 ${minutes}분까지 누를 수 있습니다.',
			'settings.catServer.allowTransmitOff' => '앱이 무전기를 키잉할 수 없습니다. VOX나 앱 자체의 PTT 설정을 사용하세요.',
			'settings.catServer.allowTransmitUnsupported' => '메인 VFO 무전기는 Ham2K Logger에서 키잉할 수 없으므로, 앱이 이를 통해 송신할 수 없습니다.',
			'settings.catServer.off' => '꺼짐.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, 시작 중…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol}, 포트 ${port}. 연결된 클라이언트: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol}, 포트 ${port}에서 대기 중이지만 메인 VFO 무전기가 연결되어 있지 않습니다.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: 다른 프로그램(주로 ${protocol} 자체)이 사용 중입니다. 해당 프로그램을 닫거나 다른 포트를 선택하세요.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기할 수 없습니다: 이 컴퓨터가 허용하지 않습니다. 1024보다 큰 포트를 선택하세요.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol}이(가) 포트 ${port}에서 대기를 중지했습니다. 다시 시도 중…',
			'settings.cluster.title' => 'DX 클러스터',
			'settings.cluster.description' => '확장 기능이 오퍼레이터로 로그인하여 스팟을 올리고 읽어 오는 서버입니다.',
			'settings.cluster.connect' => '클러스터에 연결',
			'settings.cluster.connectOn' => '확장 기능이 필요할 때 클러스터에 연결합니다',
			'settings.cluster.connectOff' => '클러스터에 연결하지 않습니다',
			'settings.cluster.console' => '콘솔 표시',
			'settings.cluster.consoleDescription' => '클러스터가 보내는 내용과 명령을 입력하는 곳',
			'settings.cluster.consoleTitle' => '클러스터 콘솔',
			'settings.cluster.consoleConnect' => '연결',
			'settings.cluster.consoleDisconnect' => '연결 해제',
			'settings.cluster.consoleCommand' => '명령',
			'settings.cluster.consoleEmpty' => '아직 없습니다. 연결하거나, 확장 기능이 클러스터를 사용할 때까지 기다리세요.',
			'settings.cluster.consoleRetry' => ({required Object command}) => '다시 전송 중: ${command}',
			'settings.cluster.consoleGaveUp' => ({required Object command, required Object reason}) => '전송되지 않음: ${command} (${reason})',
			'settings.cluster.server' => '클러스터 서버',
			'settings.cluster.selectServer' => '서버 선택',
			'settings.cluster.serverOther' => '기타',
			'settings.cluster.serverOtherIncomplete' => ({required Object node}) => '아직 호스트를 입력하지 않아 스팟이 ${node}(으)로 갑니다',
			'settings.cluster.customHost' => '서버',
			'settings.cluster.customPort' => '포트',
			'settings.cluster.password' => '비밀번호',
			'settings.cluster.passwordDescription' => '필요한 경우에만',
			'settings.cluster.passwordStored' => ({required Object node}) => '${node}의 비밀번호 저장됨',
			'settings.cluster.scrollback' => '보관 줄 수',
			'settings.cluster.scrollbackOpt' => ({required Object count}) => '${count}줄',
			'settings.cluster.connection' => '연결',
			'settings.cluster.statusIdle' => '연결되지 않음. 확장 기능이 필요할 때 연결합니다. 탭하여 테스트하세요.',
			'settings.cluster.statusConnecting' => ({required Object node}) => '${node}에 연결 중…',
			'settings.cluster.statusConnected' => ({required Object node, required Object call}) => '${node}에 ${call}(으)로 연결됨.',
			'settings.cluster.statusFailed' => ({required Object node, required Object reason}) => '${node}에 연결할 수 없습니다: ${reason}',
			'settings.cluster.statusUnsupported' => '웹 버전에서는 사용할 수 없습니다.',
			'settings.cluster.statusOff' => '꺼짐. 사용하려면 클러스터에 연결을 켜세요.',
			'settings.cluster.errors.noCall' => '로그인할 오퍼레이터 콜사인이 없습니다',
			'settings.cluster.errors.connectFailed' => '노드에 연결할 수 없습니다',
			'settings.cluster.errors.needsPassword' => '노드가 비밀번호를 요구하지만 저장된 비밀번호가 없습니다',
			'settings.cluster.errors.loginFailed' => '노드가 로그인을 받아들이지 않았습니다',
			'settings.cluster.errors.disconnected' => '노드가 연결을 끊었습니다',
			'settings.cluster.errors.timeout' => '노드가 응답하지 않았습니다',
			'settings.cluster.errors.off' => '클러스터에 연결이 꺼져 있습니다',
			'settings.spotting.title' => '스팟',
			'settings.spotting.respotInterval' => '자동 재스팟 간격',
			'settings.spotting.minutes' => ({required Object minutes}) => '${minutes}분',
			'settings.spotting.autoRespotByDefault' => '기본으로 자동 재스팟',
			'settings.spotting.autoRespotByDefaultOn' => '스팟을 올리면 자동 재스팟을 활성화합니다',
			'settings.spotting.autoRespotByDefaultOff' => '자동 재스팟은 직접 켜야 합니다',
			'settings.spotting.pulseBeforeRespot' => '자동 재스팟 전 깜빡임',
			'settings.spotting.pulseBeforeRespotOn' => ({required Object seconds}) => '재스팟 ${seconds}초 전부터 스팟 칩이 파란색으로 깜빡입니다',
			'settings.spotting.pulseBeforeRespotOff' => '자동 재스팟 전에 깜빡이지 않습니다',
			'settings.radio.title' => 'CAT 제어',
			'settings.radio.loggingAndCat' => '로깅 및 CAT',
			'settings.radio.tuningSection' => '튜닝',
			'settings.radio.keyerSection' => '키어',
			'settings.radio.servicesSection' => '서비스',
			'settings.radio.stationConfigurationSection' => '무선국 구성',
			'settings.radio.moreSettings' => '추가 무선국 구성 설정',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => '키보드로 PTT 제어',
			'settings.radio.pttKey.modes.off' => '아니요',
			'settings.radio.pttKey.modes.toggle' => '토글',
			'settings.radio.pttKey.modes.hold' => '누르고 있기',
			'settings.radio.pttKey.descriptions.off' => '키보드로 무전기를 키잉하지 않습니다.',
			'settings.radio.pttKey.descriptions.toggle' => '보이스 모드에서 PTT 키를 누르면 송신하고, 다시 누르면 송신을 멈춥니다. 1분 후에는 자동으로 멈춥니다.',
			'settings.radio.pttKey.descriptions.hold' => '보이스 모드에서 PTT 키를 누르고 있는 동안 최대 1분까지 송신합니다.',
			'settings.radio.pttKey.key' => 'PTT 키',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => '송신 중',
			'settings.radio.smartVfoSnap.title' => '스마트 VFO 스냅',
			'settings.radio.smartVfoSnap.descriptionOn' => '다이얼을 멈추면 주파수를 적절한 단위로 반올림합니다. 보이스 모드에만 적용됩니다.',
			'settings.radio.smartVfoSnap.descriptionOff' => '튜닝한 주파수를 그대로 유지합니다.',
			'settings.radio.snapDebounce.title' => '스마트 스냅: 안정 지연',
			'settings.radio.snapDebounce.description' => '주파수를 반올림하기 전에 다이얼이 멈춰 있어야 하는 시간. 짧으면 즉시 반응하고, 길면 천천히 돌릴 여유가 생깁니다.',
			'settings.radio.snapLongMove.title' => '스마트 스냅: 긴 이동',
			'settings.radio.snapLongMove.description' => '이 이상 이동하면 마지막에 얼마나 천천히 돌렸든 주파수를 kHz 단위로 반올림합니다.',
			'settings.radio.snapMinMove.title' => '스마트 스냅: 최소 이동',
			'settings.radio.snapMinMove.description' => '이보다 적게 이동하면 주파수를 반올림하지 않으므로 미세 튜닝은 그대로 유지됩니다.',
			'settings.radio.snapMinSpeed.title' => '스마트 스냅: 최저 속도',
			'settings.radio.snapMinSpeed.description' => '다이얼을 이보다 천천히 돌리면 긴 이동이 아닌 한 주파수를 반올림하지 않습니다.',
			'settings.radio.enterSends.pillOff' => 'ESM 꺼짐',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter로 메시지 전송',
			'settings.radio.enterSends.off' => '꺼짐',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter로 메시지 전송: ${state}. 탭하여 변경.',
			'settings.radio.keyerSpeed.title' => '키어 속도',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'CW 키어 메시지',
			'settings.radio.cwMessages.notSupported' => '현재 무전기는 CW 키잉을 지원하지 않습니다',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => '메시지 ${n}',
			'settings.radio.cwMessages.labelField' => '레이블',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'F${n} 레이블',
			'settings.radio.cwMessages.details' => '상세',
			'settings.radio.cwMessages.empty' => '(비어 있음)',
			'settings.radio.cwMessages.sets' => '메시지 세트',
			'settings.radio.cwMessages.newSet' => '새 세트',
			'settings.radio.cwMessages.renameSet' => '세트 이름 변경',
			'settings.radio.cwMessages.deleteSet' => '세트 삭제',
			'settings.radio.cwMessages.newSetName' => '이름',
			'settings.radio.cwMessages.setDefault' => '기본',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'ESM 메시지',
			'settings.radio.cwMessages.setSaved' => '내 메시지',
			'settings.radio.cwMessages.repeat' => '메시지 1 반복',
			'settings.radio.cwMessages.repeatShort' => 'M1 반복',
			'settings.radio.cwMessages.cooldown' => '반복 전 대기 시간',
			'settings.radio.cwMessages.cooldownSeconds' => ({required Object n}) => '${n}초',
			'settings.radio.cwMessages.repeatWait' => '반복 중',
			'settings.radio.cwMessages.keyboard' => '입력하여 전송',
			'settings.radio.cwMessages.keyboardField' => '입력하여 전송',
			'settings.radio.cwMessages.help' => '도움말',
			'settings.radio.cwMessages.helpTitle' => 'CW 메시지 작성',
			'settings.radio.cwMessages.helpIntro' => '메시지에 다음 값을 사용하는 템플릿을 쓸 수 있습니다:',
			'settings.radio.cwMessages.helpOpCall' => '내 콜사인',
			'settings.radio.cwMessages.helpQsoCall' => '상대 콜사인 — // 스택에서는 로깅될 콜사인',
			'settings.radio.cwMessages.helpQsoFullCall' => '유효한 콜사인이면 상대 콜사인, 부분 콜사인이면 빈칸',
			'settings.radio.cwMessages.helpQsoPartial' => '부분 콜사인, 유효한 전체 콜사인이면 빈칸',
			'settings.radio.cwMessages.helpQsoNextCall' => '// 스택에서 다음에 로깅하도록 선택될 콜사인 (유효한 전체 콜사인인 경우)',
			'settings.radio.cwMessages.helpQsoNextPartial' => '// 스택에서 현재 교신을 로깅한 후의 다음 부분 콜사인',
			'settings.radio.cwMessages.helpQsoName' => '상대의 이름 (입력한 값, 없으면 조회 결과)',
			'settings.radio.cwMessages.helpQsoState' => '상대의 주 (입력한 값, 없으면 조회 결과)',
			'settings.radio.cwMessages.helpKeyerMsg' => '다른 메시지 안에서 전송될 메시지 1의 내용. 메시지 1~8에서 사용 가능',
			'settings.radio.cwMessages.helpQsoRst' => '보내는 리포트',
			'settings.radio.cwMessages.helpQsoSerial' => '시리얼 번호를 보내는 컨테스트에서의 내 시리얼 번호',
			'settings.radio.cwMessages.helpPad' => '해당 자릿수까지 0으로 채움: 7은 007로 전송',
			'settings.radio.cwMessages.helpCut' => '컷 넘버, 0은 T, 9는 N: 599는 5NN으로 전송',
			'settings.radio.cwMessages.helpCutDigits' => '컷할 숫자를 따옴표 안에 지정 — 0은 T, 1은 A, 5는 E, 9는 N',
			'settings.radio.cwMessages.helpFullExample' => '전체 예시:',
			'settings.radio.cwMessages.helpExample' => 'W1AW 5NN TT7 전송',
			'settings.radio.cwMessages.helpEsmIntro' => 'Enter로 메시지 전송이 켜져 있으면, N1MM처럼 Enter가 기능 키에 해당하는 메시지를 전송합니다. ESM 메시지 세트는 다음으로 시작합니다:',
			'settings.radio.cwMessages.helpEsmCq' => 'Run 중 콜사인 필드가 비어 있을 때 Enter를 누르면 CQ 호출',
			'settings.radio.cwMessages.helpEsmExchange' => '내 교환 정보: Run 중에는 상대 콜사인 뒤에, S&P에서는 상대가 응답한 뒤에',
			'settings.radio.cwMessages.helpEsmThanks' => '교신이 로깅된 후의 감사 인사: qso는 로깅된 교신, next는 다음 차례의 교신',
			'settings.radio.cwMessages.helpEsmMyCall' => 'S&P에서 응답하는 무선국에 보내는 내 콜사인',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Run 중 내 교환 정보 앞에 보내는 상대 콜사인',
			'settings.radio.cwMessages.helpEsmAgain' => '상대의 교환 정보를 전혀 수신하지 못했을 때 다시 요청',
			'settings.radio.cwMessages.helpEsmStackThanks' => '// 스택용 추천 F3: 감사 인사 후 스택의 다음 무선국을 호출하고 교환 정보를 보내거나, 부분 콜사인을 되묻습니다 (TU KR?). 남은 것이 없으면 TU만 보냅니다',
			'settings.radio.keyerControl.label' => '키어',
			'settings.radio.keyerControl.cw' => 'WPM',
			'settings.radio.keyerControl.cwSpeed' => ({required Object wpm}) => '${wpm} WPM',
			'settings.radio.keyerControl.voice' => '보이스',
			'settings.radio.voiceMessages.title' => '보이스 키어 메시지',
			'settings.radio.voiceMessages.notSupported' => '현재 무전기는 보이스 메시지를 지원하지 않습니다',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => '보이스 메모리 ${n}',
			'settings.radio.voiceMessages.labelField' => '레이블',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => '보이스 메모리 ${n} 레이블',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => '비어 있음',
			'settings.radio.voiceMessages.notMeasured' => '길이 알 수 없음',
			'settings.radio.voiceMessages.playButton' => '재생',
			'settings.radio.voiceMessages.recordButton' => '녹음',
			'settings.radio.voiceMessages.stopButton' => '정지',
			'settings.radio.voiceMessages.repeat' => '메시지 1 반복',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => '${model} 참고:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => '이 메모리는 ${device}의 무전기에 있습니다. 이름과 길이는 해당 기기에 속합니다.',
			'settings.radio.voiceMessages.namedOnRadio' => '무전기에 저장되어 다른 클라이언트에서도 볼 수 있습니다.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => '무전기에 [REC] 표시가 나타날 때까지 기다린 후, PTT 버튼을 누른 채 메시지를 녹음하세요. 원치 않는 클릭음을 피하려면 PTT를 놓기 전에 앱에서 정지 버튼을 눌러 녹음을 끝내세요.',
			'settings.radio.voiceMessages.recordHelpFt891' => '[REC] 표시가 최소 네 번 깜빡일 때까지 기다린 후, PTT 버튼을 누른 채 메시지를 녹음하세요. 원치 않는 클릭음을 피하려면 PTT를 놓기 전에 앱에서 정지 버튼을 눌러 녹음을 끝내세요.',
			'settings.radio.voiceMessages.pill' => '보이스',
			'settings.radio.voiceMessages.play' => ({required Object n}) => '메모리 ${n} 재생',
			'settings.radio.voiceMessages.stop' => '정지',
			'settings.radio.voiceMessages.record' => ({required Object n}) => '메모리 ${n} 녹음',
			'settings.radio.voiceMessages.stopRecording' => '녹음 정지',
			'settings.radio.voiceMessages.playing' => '재생 중…',
			'settings.radio.voiceMessages.recording' => '녹음 중…',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => '${label} 녹음 중',
			'settings.radio.voiceMessages.doubtful' => '무전기가 재생했나요? 무전기가 곧바로 대기 상태라고 보고했습니다.',
			'settings.radio.voiceMessages.recordOnRadio' => '메모리는 무전기에서 직접 녹음해야 합니다.',
			'settings.radio.voiceMessages.sets' => '메시지 세트',
			'settings.radio.voiceMessages.soundFilesSet' => '이 컴퓨터의 사운드 파일',
			'settings.radio.voiceMessages.openFileButton' => '파일 열기',
			'settings.radio.voiceMessages.newSet' => '새 세트',
			'settings.radio.voiceMessages.renameSet' => '세트 이름 변경',
			'settings.radio.voiceMessages.deleteSet' => '세트 삭제',
			'settings.radio.voiceMessages.newSetName' => '이름',
			'settings.radio.voiceMessages.deleteSetConfirm' => ({required Object name}) => '${name}과(와) 그 녹음을 삭제할까요? 되돌릴 수 없습니다.',
			'settings.radio.voiceMessages.output' => '오디오 출력',
			'settings.radio.voiceMessages.input' => '녹음 입력',
			'settings.radio.voiceMessages.outputRadio' => '네트워크로 무전기에 전송',
			'settings.radio.voiceMessages.inputDefault' => '시스템 기본값',
			'settings.radio.voiceMessages.pickDevice' => '사운드 장치 선택',
			'settings.radio.voiceMessages.deviceMissing' => ({required Object name}) => '${name} (연결 안 됨)',
			'settings.radio.voiceMessages.lead' => '송신 전 지연',
			'settings.radio.voiceMessages.tail' => '송신 후 지연',
			'settings.radio.voiceMessages.millis' => ({required Object n}) => '${n} ms',
			'settings.radio.voiceMessages.listenButton' => '듣기',
			'settings.radio.voiceMessages.notRecorded' => '녹음되지 않음',
			'settings.radio.voiceMessages.unplayable' => '이 파일을 재생할 수 없습니다',
			'settings.radio.voiceMessages.problemNoOutput' => '메시지를 재생하기 전에 무전기로 연결되는 사운드 장치를 선택하세요.',
			'settings.radio.voiceMessages.problemOutputMissing' => '무전기로 연결되는 사운드 장치가 연결되어 있지 않습니다.',
			'settings.radio.voiceMessages.problemInputMissing' => '녹음 장치가 연결되어 있지 않습니다.',
			'settings.radio.voiceMessages.problemDeviceFailed' => '사운드 장치를 열 수 없습니다.',
			'settings.radio.voiceMessages.problemNotRecorded' => '이 메시지에는 아직 녹음이 없습니다.',
			'settings.radio.voiceMessages.problemRecordingSilent' => '녹음 장치에서 아무 소리도 들리지 않아 메시지를 그대로 두었습니다. 입력을 확인하고, 앱에 마이크 사용이 허용되어 있는지 확인하세요.',
			'settings.radio.voiceMessages.problemRadioAudioUnavailable' => '무전기가 지금 앱의 오디오를 받지 않고 있습니다. 무전기와의 네트워크 연결이 필요합니다.',
			'settings.radio.voiceMessages.problemSourceRefused' => '무전기가 송신 오디오를 앱으로 전환하지 않아 메시지가 중단되었습니다. 무전기가 앱의 오디오를 송신하도록 설정하세요.',
			'settings.radio.voiceMessages.problemCannotKey' => '이 무전기는 CAT으로 키잉할 수 없어, 컴퓨터가 메시지를 재생해 넣을 수 없습니다.',
			'settings.radio.voiceMessages.problemUnplayable' => '이 메시지의 파일은 앱이 재생할 수 있는 사운드 파일이 아닙니다. WAV, FLAC 또는 MP3 파일을 사용하거나 다시 녹음하세요.',
			'settings.radio.voiceMessages.problemRecordingFailed' => '녹음이 중간에 끊겨 메시지를 그대로 두었습니다. 녹음 장치가 여전히 연결되어 있는지, 디스크에 여유 공간이 있는지 확인하세요.',
			'settings.radio.voiceMessages.problemFileFailed' => '녹음을 메시지 자리에 저장할 수 없어 메시지를 그대로 두었습니다.',
			'settings.radio.voiceMessages.problemWordsMissing' => ({required Object words}) => '이 메시지에는 아직 녹음하지 않은 단어가 필요합니다: ${words}.',
			'settings.radio.voiceMessages.problemTemplateFailed' => ({required Object error}) => '이 메시지의 템플릿에 문제가 있습니다: ${error}',
			'settings.radio.voiceMessages.problemNoOperation' => '내 목소리로 말하는 메시지는 말할 대상 교신이 있는 운용 안에서 재생됩니다.',
			'settings.radio.voiceMessages.problemNothingSaid' => '이 메시지는 이 교신에 대해 말할 내용이 없습니다.',
			'settings.radio.voiceMessages.templateField' => '내 목소리로 말하기',
			'settings.radio.voiceMessages.templateHelp' => '비워 두면 녹음을 재생합니다. 그렇지 않으면 녹음한 단어들로 교신마다 다음 값을 채워 메시지를 말합니다:',
			'settings.radio.voiceMessages.help' => '도움말',
			'settings.radio.voiceMessages.helpTitle' => '내 목소리로 메시지 말하기',
			'settings.radio.voiceMessages.helpFullExample' => '전체 메시지:',
			'settings.radio.voiceMessages.helpExample' => '상대 콜사인, 상대에게 주는 리포트, 그리고 “QSL?” 녹음',
			'settings.radio.voiceMessages.playOnRadio' => '무전기에서 재생',
			'settings.radio.voiceMessages.templateHelpCall' => '상대 콜사인',
			'settings.radio.voiceMessages.templateHelpReport' => '상대에게 주는 리포트',
			'settings.radio.voiceMessages.templateHelpMessage' => '메시지 2의 녹음, 녹음된 대로 재생',
			'settings.radio.voiceMessages.voiced' => '내 목소리로 말함',
			'settings.radio.voiceMessages.willSay' => ({required Object words}) => '말할 내용: ${words}',
			'settings.radio.voiceMessages.willSayMissing' => ({required Object words}) => '아직 녹음되지 않음: ${words}',
			'settings.radio.voiceMessages.previewNoOperation' => '무엇을 말할지 보려면 운용을 여세요.',
			'settings.radio.voiceMessages.wordsDescription' => '콜사인, 숫자 등을 내 목소리로 말합니다.',
			'settings.radio.voiceWords.title' => '단어 녹음',
			'settings.radio.voiceWords.callField' => '오퍼레이터 단어 녹음',
			'settings.radio.voiceWords.intro' => '각 단어나 숫자를 콜사인을 말할 때처럼 빠르게 이어서 세 번 녹음하세요. 긴 구절은 한 번만 녹음합니다.',
			'settings.radio.voiceWords.recordAll' => '모두 녹음',
			'settings.radio.voiceWords.recordAllGuide' => '각 단어는 이어서 세 번, 여러 단어로 된 구절은 한 번 읽고, 줄 사이에는 숨을 고르세요. 마지막까지 읽은 후 정지를 누르세요.',
			'settings.radio.voiceWords.recordingOne' => ({required Object word}) => '“${word} ${word} ${word}”라고 말한 후 정지를 누르세요.',
			'settings.radio.voiceWords.recordingOnce' => ({required Object words}) => '“${words}”라고 말한 후 정지를 누르세요.',
			'settings.radio.voiceWords.recorded' => '녹음됨',
			'settings.radio.voiceWords.notRecorded' => '녹음되지 않음',
			'settings.radio.voiceWords.addPhrase' => '구절 추가',
			'settings.radio.voiceWords.phraseField' => '메시지에 쓰는 대로의 구절',
			'settings.radio.voiceWords.deletePhrase' => '구절 삭제',
			'settings.radio.voiceWords.tryField' => '말해 보기',
			'settings.radio.voiceWords.pauseLetters' => '글자 사이 간격',
			'settings.radio.voiceWords.pauseWords' => '단어 사이 간격',
			'settings.radio.voiceWords.pauseValue' => ({required Object ms}) => '${ms} ms',
			'settings.radio.voiceWords.speed' => '속도',
			'settings.radio.voiceWords.speedValue' => ({required Object speed}) => '${speed}×',
			'settings.radio.voiceWords.advancedSettings' => '고급 설정',
			'settings.radio.voiceWords.splitSilent' => '녹음에서 아무 소리도 들리지 않았습니다.',
			'settings.radio.voiceWords.splitNotThreeTakes' => '세 번의 발음을 찾을 수 없습니다. 단어를 이어서 세 번 말하고 다시 시도하세요.',
			'settings.radio.voiceWords.splitLineCount' => '읽은 내용에서 모든 단어를 찾을 수 없습니다. 각 단어를 세 번씩 읽고, 단어 사이에 숨을 고르세요.',
			'settings.radio.voiceWords.splitLinesTooClose' => '단어를 구분할 수 없습니다. 단어 사이에 더 길게 숨을 고르세요.',
			'settings.radio.avoidZeroBeat.title' => '스팟에서 제로비트 피하기',
			'settings.radio.avoidZeroBeat.descriptionOn' => '무전기가 연결되어 있으면 CW 스팟에서 몇 Hz 떨어지게 튜닝하여, 응답하는 모두가 같은 음으로 호출하지 않게 합니다.',
			'settings.radio.avoidZeroBeat.descriptionOff' => '스팟된 주파수에 정확히 튜닝합니다.',
			'settings.radio.zeroBeatRange.title' => '제로비트: 회피 범위',
			'settings.radio.zeroBeatRange.description' => '스팟된 주파수에서 위아래로 얼마나 떨어질지. 오프셋은 0에 가깝지 않습니다 — 그러면 다시 제로비트가 됩니다.',
			'settings.help.title' => '도움말 및 자료',
			'settings.help.description' => '커뮤니티 및 지원',
			'settings.help.forums' => 'Ham2K 포럼',
			'settings.help.forumsDescription' => '도움받기, 피드백 제공, 아이디어 토론…',
			'settings.help.chat' => 'Ham2K 채팅',
			'settings.help.chatDescription' => '온라인 커뮤니티를 위한 Discord 서버',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => '비디오 & 라이브스트림',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => '사진은 많을수록 좋으니까요…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => '소식 및 업데이트를 위해 팔로우하세요',
			'settings.help.contact' => '연락처',
			'settings.help.contactDescription' => 'help@ham2k.com — 하지만 포럼이나 채팅을 먼저 시도해 보세요!',
			'settings.exports.title' => '내보내기',
			'settings.extensionSections.activities' => '활동',
			'settings.extensionSections.hunting' => '추적',
			'settings.extensionSections.contests' => '컨테스트',
			'settings.extensionSections.lookups' => '조회',
			'settings.extensionSections.dashboard' => '대시보드',
			'settings.map.title' => '지도',
			'settings.map.style.title' => '지도 스타일',
			'settings.map.showCallsigns.title' => '콜사인 표시',
			'settings.map.showCallsigns.description' => '각 교신을 밴드 색상의 콜사인 칩으로 표시',
			'settings.map.showGrayline.title' => '그레이라인 표시',
			'settings.map.showGrayline.description' => '지구의 밤 부분을 어둡게 하고, 박명은 그라데이션으로 표시',
			'settings.map.styleOpts.automatic' => '자동',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			_ => null,
		} ?? switch (path) {
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => '개인정보',
			'settings.privacy.shareAppData.title' => '앱 사용 데이터 공유',
			'settings.privacy.shareAppData.descriptionOn' => '사용량, 구성, 충돌 및 성능 데이터를 공유하여 앱 개선에 도움',
			'settings.privacy.shareAppData.descriptionOff' => '앱 사용 데이터를 비공개로 유지합니다.\nHam2K 팀은 앱 충돌 또는 기타 문제를 감지할 수 없습니다.',
			'settings.privacy.shareOpData.title' => '운용 데이터 공유',
			'settings.privacy.shareOpData.descriptionOn' => '일부 운용 데이터를 공개 및 다른 사용자와 공유',
			'settings.privacy.shareOpData.descriptionOff' => '운용 데이터 비공개 유지',
			'settings.privacy.privacyPolicy' => '개인정보처리방침',
			'settings.privacy.termsOfService' => '서비스 약관',
			'settings.operatorCall' => '오퍼레이터 콜사인',
			'settings.sync.title' => '클라우드 동기화',
			'settings.sync.moreSettings' => '추가 동기화 설정',
			'settings.sync.enable' => '동기화 활성화',
			'settings.sync.deviceKey' => '기기 키',
			'settings.peers.title' => '피어 기기',
			'settings.peers.enable' => '다른 기기와 연결',
			'settings.peers.enableDescription' => '로컬 네트워크를 통해 다른 기기와 운용, 로깅, CAT 및 GPS 공유 허용',
			'settings.peers.bleEnable' => '블루투스로 연결',
			'settings.peers.bleDescription' => '로컬 네트워크가 없어도 블루투스 LE로 연결',
			'settings.peers.thisDevice' => '이 기기',
			'settings.peers.deviceName' => '이름',
			'settings.peers.deviceNameHint' => '다른 기기에 표시되는 이 기기의 이름',
			'settings.peers.pairedDevices' => '연결된 기기',
			'settings.peers.noPairedDevices' => '아직 연결된 기기가 없습니다. 같은 네트워크의 다른 기기에서도 이 옵션을 켜면 연결됩니다.',
			'settings.peers.deviceListProblem' => ({required Object error}) => '연결된 기기를 읽을 수 없습니다: ${error}',
			'settings.peers.nearby' => '근처',
			'settings.peers.connected' => '연결됨',
			'settings.peers.viaBluetooth' => '블루투스 경유',
			'settings.peers.connecting' => '연결 중…',
			'settings.peers.syncing' => '동기화 중…',
			'settings.peers.waitingForThem' => '상대 기기 대기 중',
			'settings.peers.notConnected' => '연결 안 됨',
			'settings.peers.wantsToPair' => '이 운용을 공유하려고 합니다',
			'settings.peers.allow' => '허용',
			'settings.peers.link' => '연결',
			'settings.peers.reject' => '거부',
			'settings.peers.forget' => '지우기',
			'settings.peers.forgetTitle' => ({required Object name}) => '${name}을(를) 지울까요?',
			'settings.peers.forgetBody' => '이 기기와의 동기화를 중지합니다. 나중에 다시 허용할 수 있으며, 이미 로깅된 교신은 유지됩니다.',
			'settings.peers.pairTitle' => ({required Object name}) => '${name}과(와) 연결',
			'settings.peers.pairBody' => '이 기기는 로컬 네트워크에 있으며 연결하려고 합니다.',
			'settings.peers.pairBodyBle' => '이 기기는 근처에 있으며 블루투스 LE로 연결하려고 합니다.',
			'settings.peers.pairIdLabel' => '기기 ID',
			'settings.peers.pairWarning' => '알고 있는 기기와만 연결하세요. 이 네트워크의 모든 기기가 요청을 보낼 수 있습니다.',
			'settings.peers.pairWarningBle' => '알고 있는 기기와만 연결하세요. 근처의 모든 기기가 요청을 보낼 수 있습니다.',
			'settings.peers.problem' => ({required Object error}) => '로컬 네트워크에 연결할 수 없습니다: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => '블루투스: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => '${device}에 연결됨',
			'settings.peers.statusLost' => ({required Object device}) => '${device}과(와) 연결 끊김',
			'settings.peers.statusPerma' => ({required Object linked, required Object connected}) => '피어 기기: ${linked}개 중 ${connected}개 연결됨',
			'settings.peers.screenEnable' => '화면 및 창 공유',
			'settings.peers.screenDescription' => '다른 기기가 이 컴퓨터의 화면이나 창을 표시하도록 허용',
			'settings.peers.screenSources' => '화면 및 창',
			'settings.peers.screenRefresh' => '목록 새로고침',
			'settings.peers.screenUnsupportedPlatform' => '이 기기는 화면을 공유할 수 없습니다. macOS는 가능하며, 모든 기기는 다른 기기가 공유한 화면을 표시할 수 있습니다.',
			'settings.peers.screenUnsupportedVersion' => '화면 공유에는 macOS 12.3 이상이 필요합니다. 이 기기에서도 다른 기기가 공유한 화면은 표시할 수 있습니다.',
			'settings.peers.screenNeedsPermission' => '이 앱이 화면을 공유하려면 macOS의 화면 기록 권한이 필요합니다.',
			'settings.peers.screenGrantPermission' => '권한 요청',
			'settings.peers.screenRelaunchAfterGranting' => '시스템 설정의 개인정보 보호 및 보안 → 화면 기록에서 허용한 후, 이 앱을 종료하고 다시 여세요. macOS는 앱을 다시 실행해야 변경 사항을 알려줍니다.',
			'settings.peers.screenProblem' => ({required Object error}) => '화면 공유: ${error}',
			'settings.peers.screenChooseTitle' => '공유할 항목 선택',
			'settings.peers.screenChooseButton' => '공유할 항목 선택…',
			'settings.peers.screenTabScreens' => '화면',
			'settings.peers.screenTabApps' => '앱',
			'settings.peers.screenTabWindows' => '창',
			'settings.peers.screenTabEmpty' => '이 종류의 항목이 없습니다.',
			'settings.peers.screenSharedSummaryNone' => '아직 선택된 항목이 없습니다.',
			'settings.peers.screenThisDevice' => '이 기기',
			'settings.peers.screenSharedTo' => ({required Object devices}) => '${devices}에 표시 중',
			'settings.peers.screenSharedToNobody' => '표시되지 않음',
			'settings.peers.screenStopSharing' => ({required Object name}) => '${name} 공유 중지',
			'settings.developerMode' => '개발자 모드',
			'settings.syncPanel.configuration' => '동기화 구성',
			'settings.syncPanel.enableTitle' => 'Ham2K Log Filer와 동기화',
			'settings.syncPanel.enabledDescription' => '로그를 백업하고 여러 기기 간에 동기화',
			'settings.syncPanel.disabledDescription' => '꺼짐 — 이 기기에만 보관',
			'settings.syncPanel.syncing' => '동기화',
			'settings.syncPanel.account' => '계정',
			'settings.syncPanel.refresh' => '새로고침',
			'settings.syncPanel.switchAccounts' => '계정 전환',
			'settings.syncPanel.switchAccountsDescription' => 'QR 코드나 이메일로 이 기기를 다른 계정에 연결',
			'settings.syncPanel.connectionRequests' => '연결 요청',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '기기가 이 계정에 연결 대기 중', other: '기기 ${n}개가 이 계정에 연결 대기 중', ), 
			'settings.syncPanel.accountEmailTitle' => '계정 이메일',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => '${email}(으)로 확인 메일을 보냈습니다. 메일의 링크를 열어 변경을 완료하세요.',
			'settings.syncPanel.resendConfirmation' => '확인 이메일 다시 보내기',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => '${email} 확인 대기 중',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => '${email}(으)로 다시 보냈습니다.',
			'settings.syncPanel.deviceLinked' => '해당 기기가 이제 이 계정에 연결되었습니다.',
			'settings.syncPanel.checking' => '확인 중…',
			'settings.syncPanel.notLinked' => '아직 연결되지 않음',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => '로컬 데이터를 대체할까요?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '운용 ${n}개', other: '운용 ${n}개', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${n} QSO', other: '${n} QSO', ), 
			'settings.syncPanel.counts' => '동기화된 데이터',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => '이 기기: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => '업로드 대기 중: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => '서버: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => '이 기기: 확인 중…',
			'settings.syncPanel.countsServerChecking' => '서버: 확인 중…',
			'settings.syncPanel.countsServerUnavailable' => '서버: 사용할 수 없음',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => '이 기기의 ${operations}과(와) ${qsos}을(를) 백업하고 지운 후, 대신 계정의 데이터를 다운로드합니다. 백업은 이 기기의 데이터베이스에 남습니다.',
			'settings.syncPanel.replace' => '대체',
			'settings.syncPanel.pendingBannerTitle' => '새로운 Ham2K Log Filer 계정 감지됨',
			'settings.syncPanel.pendingBannerBody' => '이 기기의 기존 운용과 QSO를 유지하여 계정에 병합하거나, 계정의 데이터로 대체하세요 (어느 쪽이든 이 기기에 백업이 남습니다).',
			'settings.syncPanel.combine' => '결합',
			'settings.syncPanel.authIssueTitle' => '동기화 연결 불가',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer가 이 기기를 계속 거부합니다. 동기화 설정에서 콜사인을 확인하세요.',
			'settings.syncPanel.openSettings' => '동기화 설정 열기',
			'settings.accounts.title' => '계정, 서비스 및 데이터 출처',
			'settings.accounts.none' => '계정이 있는 활성 확장 기능 없음',
			'settings.accounts.notConfigured' => '구성되지 않음',
			'settings.accounts.connected' => '연결됨',
			'settings.accounts.cancelLogin' => '로그인 취소',
			'settings.accounts.openInBrowser' => '브라우저에서 열기',
			'settings.accounts.loggedInAs' => ({required Object identity}) => '${identity}(으)로 로그인됨',
			'settings.accounts.pressSaveToKeep' => '이 계정의 연결을 유지하려면 저장을 누르세요.',
			'settings.accounts.connectedTo' => ({required Object label}) => '${label}에 연결됨',
			'settings.accounts.connect' => '연결',
			'settings.accounts.disconnect' => '연결 해제',
			'settings.accounts.connectedAs' => '연결된 계정',
			'settings.accounts.test' => '테스트',
			'settings.accounts.saveFailed' => ({required Object error}) => '저장 실패: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => '로그인 실패: ${error}',
			'settings.accounts.lookupFailed' => '지금은 계정을 사용할 수 없습니다. 잠시 후 다시 시도하세요',
			'settings.accounts.browserLoginTitle' => '웹 브라우저에서 로그인을 완료하세요',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => '완료하면 브라우저가 "${prefix}"(으)로 시작하는 링크를 열려고 합니다. 데스크톱에 이 링크를 열 프로그램이 등록되어 있지 않을 가능성이 높으므로, 주소 표시줄이나 브라우저의 오류 페이지에서 링크를 복사해 여기에 붙여넣으세요.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger가 브라우저를 열 수 없습니다. 아래 로그인 링크를 복사해 직접 연 다음, 이동되는 링크("${prefix}"(으)로 시작)를 복사해 여기에 붙여넣으세요.',
			'settings.accounts.copyLoginLink' => '로그인 링크 복사',
			'settings.accounts.pastedLinkLabel' => '여기에 링크를 붙여넣으세요',
			'settings.accounts.finishLogin' => '로그인 완료',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => '로그인 링크가 아닙니다. "${prefix}"(으)로 시작해야 합니다.',
			'settings.accounts.pastedLinkWrongLogin' => '다른 로그인 시도의 링크입니다. 이 페이지를 닫고 다시 연결하세요.',
			'settings.accounts.pastedLinkNoCode' => '링크에 로그인 코드가 없습니다. 먼저 로그인을 완료한 후 이동되는 링크를 복사하세요.',
			'settings.accounts.pastedLinkMalformed' => '링크가 잘린 것 같습니다. 전체를 복사해 다시 붙여넣으세요.',
			'settings.accounts.relayLoginWaiting' => '로그인 완료를 기다리는 중입니다. 완료하면 자동으로 계속됩니다.',
			'settings.accounts.loginNoResponse' => '이 기기가 아직 로그인 응답을 받지 못했습니다. 브라우저에서 이미 완료했다면 취소하고 다시 연결해 보세요.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger가 브라우저를 자동으로 열 수 없습니다. 아래 버튼으로 로그인 페이지를 직접 여세요.',
			'settings.accounts.relayLoginUnavailable' => '로그인을 완료하는 데 필요한 동기화 서버에 연결할 수 없습니다. 연결을 확인하고 다시 시도하세요.',
			'settings.accounts.loginIncompleteResponse' => '로그인 시도가 올바르게 완료되지 않았습니다. 다시 연결해 보세요.',
			'settings.accounts.noKeyringTitle' => '계정 로그인 정보를 저장할 수 없습니다',
			'settings.accounts.noKeyringText' => 'Ham2K Logger가 이 컴퓨터의 키링 서비스에 연결할 수 없어 계정 로그인 정보를 저장하거나 읽을 수 없습니다. 이 문제가 해결될 때까지 계정 연결이 실패합니다. **gnome-keyring**, **KWallet** 또는 **KeePassXC**를 설치하고 실행하거나, 기존 키링의 잠금을 해제한 후 다시 시작하세요. 로깅, 내보내기 및 데이터 파일은 영향을 받지 않으며, 그동안 로그 동기화는 꺼져 있습니다.',
			'settings.accounts.noKeyringInline' => '로그인 정보를 저장할 수 없음: 이 컴퓨터의 키링에 연결할 수 없습니다. gnome-keyring, KWallet 또는 KeePassXC를 설치하고 실행하거나, 기존 키링의 잠금을 해제하세요.',
			'settings.accounts.noSecureStorageInline' => '로그인 정보를 저장할 수 없음: 이 컴퓨터의 보안 저장소에 연결할 수 없습니다.',
			'settings.station.title' => '무선국 구성 및 CAT 제어',
			'settings.station.none' => '구성된 장비 없음',
			'settings.station.add' => '추가',
			'settings.station.addTitle' => '장비 추가',
			'settings.station.searchHint' => '장비 검색',
			'settings.station.noMatches' => '일치하는 장비 없음',
			'settings.station.detectedEquipment' => '감지된 장비',
			'settings.station.discoveryUnavailable' => ({required Object error}) => '무전기를 찾을 수 없습니다: ${error}',
			'settings.station.edit' => '장비 편집',
			'settings.station.name' => '이름',
			'settings.station.nameDescription' => '부르는 이름 — "왼쪽 무전기". 선택 사항.',
			'settings.station.transport' => '연결',
			'settings.station.host' => '주소',
			'settings.station.hostDescription' => '네트워크상 무전기의 호스트 이름 또는 IP 주소.',
			'settings.station.port' => '포트',
			'settings.station.hostRequired' => '주소가 필요합니다',
			'settings.station.portInvalid' => '포트는 1에서 65535 사이여야 합니다',
			'settings.station.connect' => '연결',
			'settings.station.disconnect' => '연결 해제',
			'settings.station.remove' => '제거',
			'settings.station.removeTitle' => ({required Object name}) => '${name}을(를) 제거할까요?',
			'settings.station.removeMessage' => '앱에서만 제거됩니다. 장비의 설정은 그대로 유지됩니다.',
			'settings.station.unknownType' => ({required Object typeKey}) => '알 수 없는 장비 유형 "${typeKey}"',
			'settings.station.report' => '제보',
			'settings.station.reportTitle' => '이 무전기 제보',
			'settings.station.reportIntro' => '이 무전기가 실제로 어떤 모델이고 어떻게 작동했는지 알려 주세요. 제보 내용은 Ham2K 팀이 읽는 카드가 되며, 작동시킨 방법에 대해 쓴 내용은 같은 장비를 쓰는 다음 오퍼레이터에게 도움이 될 수 있습니다.',
			'settings.station.reportManufacturer' => '제조사',
			'settings.station.reportManufacturerDescription' => '제조사 — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => '제조사가 필요합니다',
			'settings.station.reportModel' => '모델',
			'settings.station.reportModelDescription' => '무전기에 표시된 모델명 — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => '모델이 필요합니다',
			'settings.station.reportOutcome' => '어떻게 작동했나요?',
			'settings.station.reportOutcomeWorks' => '잘 작동함',
			'settings.station.reportOutcomeIssues' => '작동했지만 문제 있음',
			'settings.station.reportOutcomeFails' => '전혀 작동하지 않음',
			'settings.station.reportOutcomeRequired' => '어떻게 작동했는지 알려 주세요',
			'settings.station.reportComments' => '코멘트',
			'settings.station.reportCommentsPlaceholder' => '작동한 것, 작동하지 않은 것, 예상 밖이었던 것.',
			'settings.station.reportHints' => '문제 해결 팁',
			'settings.station.reportHintsPlaceholder' => '다른 사용자를 위한 문제 해결 팁이 있나요?',
			'settings.station.reportSend' => '제보 보내기',
			'settings.station.reportSending' => '제보를 보내는 중…',
			'settings.station.reportSent' => ({required Object ref}) => '감사합니다. 제보가 ${ref}(으)로 접수되었습니다.',
			'settings.station.reportSentNoRef' => '감사합니다. 제보를 보냈습니다.',
			'settings.station.reportFailed' => ({required Object error}) => '제보를 보내지 못했습니다: ${error}',
			'settings.station.troubleshootingNotes' => '문제 해결 참고 사항',
			'settings.station.mainVfo' => '메인 VFO',
			'settings.station.useAsMainVfo' => '메인 VFO로 사용',
			'settings.station.serialPort' => '시리얼 포트',
			'settings.station.serialPortDescription' => '무전기의 CAT 인터페이스가 나타나는 포트.',
			'settings.station.serialPortNone' => '시리얼 포트를 찾을 수 없음',
			'settings.station.serialPortRequired' => '시리얼 포트를 선택하세요',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => '포트 ${n} / ${total}',
			'settings.station.serialPortSuggested' => '추천',
			'settings.station.serialPortJustNow' => '최근 연결됨',
			'settings.station.serialPortNoDriver' => '드라이버 없음',
			'settings.station.serialDeviceRequest' => 'USB 장치 추가…',
			'settings.station.bleDevice' => '블루투스 LE 장치',
			'settings.station.bleDeviceDescription' => '무전기가 연결된 시리얼 브리지. 예: Mode 4의 LiNK500MP 또는 BLE 시리얼 어댑터.',
			'settings.station.bleScan' => '블루투스 LE 장치 검색…',
			'settings.station.bleScanNoneFound' => '블루투스 LE 장치를 찾을 수 없습니다. 브리지가 켜져 있고, 근처에 있으며, 블루투스 LE 모드(LiNK500MP는 Mode 4)인지 확인하세요.',
			'settings.station.bleScanFailed' => ({required Object reason}) => '블루투스 LE 검색을 실행할 수 없습니다: ${reason}',
			'settings.station.bleOff' => '블루투스가 꺼져 있습니다.',
			'settings.station.bleDenied' => '블루투스 권한이 허용되지 않았습니다. 시스템 설정에서 허용한 후 다시 시도하세요.',
			'settings.station.bleUnsupported' => '이 기기에는 블루투스 LE가 없습니다.',
			'settings.station.bleStarting' => '블루투스가 아직 시작 중입니다. 잠시 후 다시 시도하세요.',
			'settings.station.bleConnectFailed' => '블루투스 LE 장치에 연결할 수 없습니다. 켜져 있고, 근처에 있으며, 다른 앱에 연결되어 있지 않은지 확인하세요.',
			'settings.station.bleNoSerialService' => ({required Object services}) => '이 블루투스 LE 장치에는 앱이 인식하는 시리얼 서비스가 없습니다. 다음 서비스 목록과 함께 제보해 주세요: ${services}',
			'settings.station.baudRate' => '속도 (baud)',
			'settings.station.baudRateDescription' => '무전기의 CAT 메뉴와 일치해야 합니다. 일치하지 않으면 무전기가 오류 없이 깨진 데이터를 보냅니다.',
			'settings.station.serialRtsHigh' => 'RTS를 high로 유지',
			'settings.station.serialRtsHighDescription' => 'CAT RTS가 켜진 Yaesu처럼 RTS를 기다린 후 응답하는 무전기에만 사용하세요. Digirig, SignaLink 및 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신합니다.',
			'settings.station.serialDtrHigh' => 'DTR을 high로 유지',
			'settings.station.serialDtrHighDescription' => 'FT-817용 일부 RS-232 케이블처럼 DTR에서 전원을 공급받는 CAT 인터페이스에만 사용하세요. 많은 케이블에서 DTR이 CW 키잉이나 PTT이므로, high로 유지하면 송신합니다.',
			'settings.station.serialUsbDriver' => 'USB 칩 드라이버',
			'settings.station.serialUsbDriverDescription' => '자동은 대부분의 어댑터를 인식합니다. 포트 목록에 드라이버 없음으로 표시되는 어댑터에만 칩을 선택하세요. 칩 이름은 포장이나 USB 장치 목록에서 확인할 수 있습니다.',
			'settings.station.serialUsbDriverAuto' => '자동',
			'settings.station.civAddress' => '무전기 CI-V 주소',
			'settings.station.civAddressDescription' => '무전기의 CI-V 메뉴에 표시되는 16진수. IC-705의 출고값은 A4입니다.',
			'settings.station.civAddressInvalid' => 'CI-V 주소는 01부터 FF까지의 16진수 두 자리입니다',
			'settings.station.flexSlice' => '슬라이스',
			'settings.station.flexSliceDescription' => '이 연결이 읽고 튜닝할 무전기의 슬라이스.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => '슬라이스 ${letter}',
			'settings.station.flexSliceInvalid' => '무전기의 슬라이스 A부터 H 중 하나를 선택하세요',
			'settings.station.flexSliceMissing' => ({required Object letter}) => '이 무전기에서 슬라이스 ${letter}을(를) 사용하고 있지 않습니다. 다른 슬라이스를 선택하거나 SmartSDR에서 만드세요',
			'settings.station.channelNotInUse' => '사용 안 함',
			'settings.station.channelHeldByUnknown' => '다른 프로그램이 사용 중',
			'settings.station.flexNoSlices' => '이 무전기가 슬라이스를 보고하지 않았습니다. SmartSDR이 실행 중이고 이 클라이언트가 구독할 수 있는지 확인하세요',
			'settings.station.spectrumUnsupported' => '이 무전기는 CAT으로 스펙트럼을 보내지 않습니다',
			'settings.station.spectrumRequiresBaud' => 'CAT 115200 bps 필요',
			'settings.station.spectrumNoRadio' => '연결된 무전기 없음',
			'settings.station.spectrumWaiting' => '무전기의 스펙트럼 대기 중…',
			'settings.station.spectrumUnavailable' => '스펙트럼 표시를 사용할 수 없습니다',
			'settings.station.spectrumNoDaxChannel' => '이 무전기의 모든 DAX IQ 채널이 사용 중입니다',
			'settings.station.spectrumNoPanadapter' => '이 슬라이스에 무전기의 팬어댑터가 없습니다',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => '무전기가 DAX IQ 스트림을 거부했습니다 (오류 ${code})',
			'settings.station.spectrumNoUdp' => '무전기의 스펙트럼 데이터가 이 기기에 도달할 수 없습니다',
			'settings.station.spectrumK4Unavailable' => 'K4의 LAN 스펙트럼을 수신할 수 없습니다. 다시 시도 중…',
			'settings.station.spectrumK4RemoteUnavailable' => 'K4의 원격 스펙트럼을 수신할 수 없습니다',
			'settings.station.spectrumScopeRefused' => '무전기가 스코프 명령을 거부했습니다',
			'settings.station.spectrumOutOfRange' => '무전기의 스코프가 표시할 수 있는 범위 밖으로 설정되어 있습니다',
			'settings.station.spectrumBandUnsupported' => '이 밴드에서는 무전기의 스코프를 표시할 수 없습니다',
			'settings.station.spectrumSdrNoRadio' => '연결된 무전기의 주파수 대기 중…',
			'settings.station.spectrumSdrNotConnected' => 'SDR이 연결되어 있지 않습니다',
			'settings.station.spectrumSdrNoIf' => '이 SDR의 설정에서 무전기의 IF 주파수를 설정하세요',
			'settings.station.sdrRadio' => '스펙트럼 표시 대상',
			'settings.station.sdrRadioDescription' => '이 무전기의 스펙트럼 표시는 무전기 자체 스코프 대신 이 수신기에서 데이터를 가져옵니다.',
			'settings.station.sdrRadioMain' => '메인 무전기',
			'settings.station.sdrTuning' => '안테나 입력',
			'settings.station.sdrTuningDescription' => '수신기 신호의 출처. 자체 안테나를 쓰면 무전기를 따라 스스로 튜닝하고, 무전기의 IF 출력에서는 IF에 고정됩니다.',
			'settings.station.sdrTuningIndependent' => '자체 안테나',
			'settings.station.sdrTuningIfTap' => '무전기의 IF 출력',
			'settings.station.sdrIfHz' => 'IF 주파수 (Hz)',
			'settings.station.sdrIfHzDescription' => 'IF 출력 전용: 무전기 다이얼 주파수가 IF상에서 위치하는 주파수. 예: FT-817은 68330000.',
			'settings.station.sdrIfInverted' => 'IF 반전',
			'settings.station.sdrGainDb' => '게인 (dB)',
			'settings.station.sdrGainDbDescription' => '비워 두면 수신기의 자동 게인을 사용합니다.',
			'settings.station.sdrOffsetHz' => '주파수 오프셋 (Hz)',
			'settings.station.sdrOffsetHzDescription' => '업컨버터용으로 수신기에 보내는 모든 주파수에 더해지는 값. Ham It Up은 125000000.',
			'settings.station.sdrPpm' => '주파수 보정 (ppm)',
			'settings.station.rtlDirectSampling' => '다이렉트 샘플링',
			'settings.station.rtlDirectSamplingDescription' => '업컨버터 없는 RTL-SDR V3에서 HF를 수신할 때 사용. RTL-SDR V4는 이것 없이도 HF를 수신합니다.',
			'settings.station.rtlDirectSamplingOff' => '꺼짐',
			'settings.station.rtlDirectSamplingI' => 'I 브랜치',
			'settings.station.rtlDirectSamplingQ' => 'Q 브랜치',
			'settings.station.rtlTcpNotAServer' => 'rtl_tcp 서버가 아닙니다',
			'settings.station.rtlTcpNotes' => '동글이 연결된 컴퓨터에서 **직접 실행하는 rtl_tcp 서버**에 연결합니다.\n\n- **시작**은 다른 컴퓨터에서 접근할 수 있도록 `rtl_tcp -a 0.0.0.0`으로 하세요. 같은 컴퓨터에서는 `rtl_tcp`만으로 충분합니다.\n- **포트**는 `-p`로 지정하지 않았다면 1234입니다.\n- **한 번에 한 프로그램만:** rtl_tcp는 클라이언트 하나만 받습니다. 앱은 스펙트럼 표시가 보이는 동안만 연결하고, 닫힌 뒤 몇 초 후에 놓습니다.\n- **Android에서는** *SDR driver* 앱이 휴대폰에서 같은 서버를 실행합니다.',
			'settings.station.rspTcpNotes' => 'RSP가 연결되고 SDRplay API가 설치된 컴퓨터에서 **직접 실행하는 rsp_tcp 서버**에 연결합니다.\n\n- **시작**은 `rsp_tcp -a 0.0.0.0`으로 하세요.\n- **포트**는 `-p`로 지정하지 않았다면 1234입니다.\n- **한 번에 한 프로그램만:** 서버는 클라이언트 하나만 받습니다. 앱은 스펙트럼 표시가 보이는 동안만 연결합니다.',
			'settings.station.n3fjpNoRig' => 'N3FJP에 무전기 인터페이스가 설정되어 있지 않아, 무전기가 아닌 N3FJP에 입력된 값을 따릅니다',
			'settings.station.winkeyerKeyPort' => '키 출력',
			'settings.station.winkeyerKeyPortDescription' => '무전기가 연결된 키어의 출력 잭 (두 개 중 하나).',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => '포트 ${n}',
			'settings.station.winkeyerPtt' => '키어의 PTT 사용',
			'settings.station.winkeyerPttDescription' => '앰프나 이를 필요로 하는 무전기를 위해 같은 잭의 PTT 라인을 키잉합니다. 키 잭으로 키잉되는 무전기는 끄세요.',
			'settings.station.winkeyerNoAnswer' => '이 포트에서 응답한 WinKeyer가 없습니다',
			'settings.station.winkeyerStoppedAnswering' => '전송 중 WinKeyer가 응답을 멈춰 메시지가 취소되었습니다',
			'settings.station.icomControlPort' => '제어 포트 (UDP)',
			'settings.station.icomControlPortDescription' => '무전기의 Control Port (UDP). 네트워크 설정에서 변경하거나 다른 포트로 포워딩하지 않았다면 50001입니다.',
			'settings.station.icomSerialPort' => '시리얼 포트 (UDP)',
			'settings.station.icomSerialPortDescription' => '무전기의 Serial Port (UDP). 네트워크 설정에서 변경하거나 다른 포트로 포워딩하지 않았다면 50002입니다.',
			'settings.station.icomPortsDiffer' => '제어 포트와 시리얼 포트는 서로 달라야 합니다',
			'settings.station.radioUser' => '무전기 사용자 이름',
			'settings.station.radioPass' => '무전기 비밀번호',
			'settings.station.radioLoginDescription' => 'WiFi 비밀번호가 아닌, 무전기의 Network → Remote 로그인 정보.',
			'settings.station.radioUserRequired' => '무전기의 원격 제어 사용자 이름이 필요합니다',
			'settings.station.connectFailedBusy' => '장치가 사용 중입니다',
			'settings.station.connectFailedDenied' => '접근이 거부되었습니다',
			'settings.station.connectFailedDevice' => '장치를 찾을 수 없습니다',
			'settings.station.connectFailedUnsupported' => '이 USB 어댑터의 칩을 인식하는 드라이버가 없습니다. 어떤 칩인지 알고 있다면 고급 설정의 USB 칩 드라이버에서 선택하세요.',
			'settings.station.connectFailedLines' => 'RTS/DTR을 설정대로 유지할 수 없어 포트를 닫았습니다. 다른 프로그램이 하드웨어 핸드셰이킹을 켜 두었을 수 있습니다. 케이블을 뽑았다가 다시 꽂으세요.',
			'settings.station.connectFailedNetwork' => '네트워크에서 무전기를 찾을 수 없습니다. 주소를 확인하고 전원이 켜져 있으며 연결 가능한지 확인하세요.',
			'settings.station.connectFailedReplyPort' => ({required Object port}) => '이 기기의 포트 ${port}이(가) 이미 사용 중이며, 응답이 그 포트로 도착합니다. 다른 PstRotator 노드를 포함해 그 포트에서 수신 대기하는 다른 프로그램을 닫거나 포트를 변경하세요.',
			'settings.station.connectFailedTimeout' => '무전기가 제시간에 응답하지 않았습니다. 전원이 켜져 있고 연결 가능한지 확인하세요.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - 범용',
			'settings.station.models.icomGeneric' => 'Icom - 범용',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - 범용',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.tx500' => 'Lab599 TX-500',
			'settings.station.models.tx500mp' => 'Lab599 TX-500MP',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - 범용',
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
			'settings.station.models.rigctld' => 'rigctld로 제어하는 무전기',
			'settings.station.models.rigctldNodeName' => '내 무전기 (rigctld 경유)',
			'settings.station.models.flrig' => 'flrig로 제어하는 무전기',
			'settings.station.models.flrigNodeName' => '내 무전기 (flrig 경유)',
			'settings.station.models.hrd' => 'Ham Radio Deluxe®로 제어하는 무전기',
			'settings.station.models.hrdNodeName' => '내 무전기 (HRD 경유)',
			'settings.station.models.n3fjp' => 'N3FJP로 제어하는 무전기',
			'settings.station.models.n3fjpNodeName' => '내 무전기 (N3FJP 경유)',
			'settings.station.models.commander' => 'DXLab Commander로 제어하는 무전기',
			'settings.station.models.commanderNodeName' => '내 무전기 (Commander 경유)',
			'settings.station.models.antenna' => '안테나',
			'settings.station.models.key' => 'CW 키',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => '범용 무전기 (임시)',
			'settings.station.models.placeholderRadioNodeName' => '내 무전기',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Sierra Radio CX-1 동축 스위치',
			'settings.station.models.gs232a' => 'Yaesu GS-232A 로테이터 인터페이스',
			'settings.station.models.pstRotator' => 'PstRotator (UDP 제어)',
			'settings.station.models.rtlSdr' => 'RTL-SDR',
			'settings.station.models.nesdr' => 'Nooelec NESDR',
			'settings.station.models.sdrplay' => 'SDRplay RSP',
			'settings.station.transports.network' => '네트워크/WiFi',
			'settings.station.transports.secureNetwork' => '보안 네트워크/WiFi',
			'settings.station.transports.usbSerial' => 'USB 시리얼',
			'settings.station.transports.wifi' => '네트워크/WiFi',
			'settings.station.transports.bluetoothSerial' => '블루투스 시리얼',
			'settings.station.transports.bleSerial' => '블루투스 LE',
			'settings.station.transports.placeholder' => '임시',
			'settings.station.troubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.ft891Troubleshooting' => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기에서 CAT RTS를 끄거나, RTS를 high로 유지를 켜세요.** **CAT RTS**가 켜져 있으면(FT-891 메뉴 **05-08**) RTS가 low인 동안 무전기는 침묵합니다. 포트가 열릴 때 한 번 응답하고는 아무것도 보내지 않을 수 있습니다. 무전기 자체 USB 포트를 선택하면 고급 설정의 **RTS를 high로 유지**가 켜집니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신기가 키잉됩니다. 이 경우 대신 무전기에서 CAT RTS를 끄세요.\n- **속도가 무전기의 CAT RATE와 일치해야 합니다** (메뉴 **05-06**). 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.yaesuBinaryTroubleshooting' => '이 무전기는 Yaesu의 구형 5바이트 CAT을 사용하며, 설정이 맞지 않으면 전혀 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **케이블이 레벨을 변환해야 합니다.** 후면의 CAT 잭은 RS-232도 USB도 아니며, CT-62 또는 동등한 어댑터가 필요합니다. 일반 오디오 또는 데이터 케이블로는 CAT이 작동하지 않습니다.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다** (FT-817은 **#14**, FT-857 또는 FT-897은 **#19**). 일치하지 않으면 무전기가 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **이 포트에서 RTS나 DTR을 절대 올리지 마세요.** 이 무전기용 케이블 대부분에서 이 라인은 PTT와 키잉입니다. 단, DTR에서 전원을 받는 구형 인터페이스는 예외이며, 이 경우 고급 설정의 **DTR을 high로 유지**를 켜세요.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 드라이버는 Yaesu가 공개한 CAT 표를 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.tenTecTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.tenTecEagleTroubleshooting' => '- **후면의 USB-B 포트가 CAT 연결입니다.** 무전기는 USB 시리얼 포트로 나타나며, Windows에서는 Ten-Tec의 USB to UART 드라이버가 필요합니다. 장치 관리자에는 "USB to UART (COMx)"로 표시됩니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 두며, Ten-Tec의 펌웨어 업데이터도 마찬가지입니다.\n- **앱에서 필터 폭을 설정하면 무전기를 껐다 켤 때까지 BW 노브로 조절할 수 없게 됩니다.** 무전기가 원래 그렇게 동작합니다.\n\n이 드라이버는 Ten-Tec의 프로그래머 참조 가이드를 바탕으로 작성되었습니다. 부분적으로만 작동한다면 무전기 메뉴의 펌웨어 버전과 함께 제보해 주세요.',
			'settings.station.tenTecOrionTroubleshooting' => '- **SERIAL DATA 포트에는 스트레이트 DB-9 시리얼 케이블을 사용하세요.** 널 모뎀 케이블은 안 됩니다.\n- **이 항목은 RTS를 high로 유지합니다.** Orion이 RTS와 CTS를 핸드셰이크로 사용하기 때문입니다. Digirig처럼 RTS로 PTT를 키잉하는 인터페이스에서는 고급 설정의 RTS를 high로 유지를 끄세요. 그렇지 않으면 앱이 연결되는 즉시 무전기가 송신합니다.\n- **앱에서 CW를 보내려면 무전기의 내장 키어가 켜져 있어야 합니다.** 꺼져 있으면 무전기가 앱이 보내는 내용을 무시합니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 드라이버는 Ten-Tec의 프로그래머 참조 가이드를 바탕으로 작성되었으며 실제 Orion에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 무전기 메뉴의 펌웨어 버전과 함께 제보해 주세요.',
			'settings.station.tenTecNoCw' => '이 무전기의 펌웨어는 앱에서 보내는 CW를 받지 않습니다. Ten-Tec은 Orion 펌웨어 1.366에서 이를 추가했습니다.',
			'settings.station.tenTecKeyerOff' => '무전기의 내장 키어가 꺼져 있어 앱에서 보내는 CW를 무시합니다. 무전기 메뉴에서 키어를 켜세요.',
			'settings.station.guohetecTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.guohetecTroubleshooting' => 'Q900에는 두 가지 CAT 프로토콜이 있으며, 이 항목은 FT-817 모방이 아닌 고유 프로토콜을 사용합니다. 여기서는 FT-817이 아닌 **Guohetec Q900**을 선택하세요. 모방 프로토콜은 지원하는 명령이 더 적고, 무전기는 어느 쪽을 사용 중인지 알려주지 않습니다.\n\n- **USB-C 케이블이 CAT 연결이며**, 사운드 카드도 함께 연결합니다. 이 포트에서는 속도가 중요하지 않으며, 어떤 값으로 설정해도 무시됩니다.\n- **이 포트에서 RTS나 DTR을 절대 올리지 마세요.** 시리얼 케이블에서 이 라인은 PTT와 키잉입니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **2세대 무전기는 1세대와 다르게 동작합니다.** Menu를 길게 누른 후 About을 확인하세요: HW 2.0이 2세대입니다.\n\n이 드라이버는 제조사가 공개한 프로토콜을 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.yaesuTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.yaesuTroubleshooting' => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기에서 CAT RTS가 OFF여야 합니다.** 켜져 있으면 무전기는 앱이 low로 유지하는 핸드셰이크 라인을 기다립니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 같은 라인이 PTT이므로, 올리면 송신기가 키잉됩니다. 무전기 자체 USB 포트에서는 고급 설정의 **RTS를 high로 유지**가 대안입니다. 이 설정의 위치는 모델마다 다릅니다 (FT-891은 메뉴 **05-08**).\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **모드는 FT-891의 표를 따릅니다.** 대부분의 Yaesu 모델이 이와 일치하지만, 모드 번호가 다른 무전기에서는 해당 모드가 잘못 표시되거나 설정됩니다. 주파수는 영향을 받지 않습니다.',
			'settings.station.ftdx3000Troubleshooting' => '무전기의 USB 포트로 CAT을 사용하려면 **메뉴 037 CAT SELECT가 USB여야 합니다**. RS232C로 설정하면 CAT은 후면 잭에 있습니다.\n\n이 항목은 공개된 CAT 문서를 바탕으로 작성되었으며 실제 FTDX3000에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.yaesuRs232Troubleshooting' => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **CAT 잭은 RS-232입니다.** USB-시리얼 어댑터와 스트레이트 DB-9 케이블이 필요합니다. 널 모뎀 케이블은 라인을 바꾸므로 무전기가 아무것도 받지 못합니다.\n- **무전기에서 CAT RTS가 OFF여야 합니다.** 켜져 있으면 고급 설정의 **RTS를 high로 유지**가 켜져 있지 않은 한, 무전기는 앱이 low로 유지하는 핸드셰이크 라인을 기다립니다.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n이 항목은 공개된 CAT 문서를 바탕으로 작성되었으며 실제 무전기에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.yaesuUsbTroubleshooting' => '무전기가 명령을 받고 있지만 응답하지 않습니다. 거의 항상 다음 중 하나입니다:\n\n- **무전기의 두 USB 포트 중 첫 번째를 사용하세요.** CAT은 보통 첫 번째 포트(Windows에서는 **Enhanced** COM 포트)에 있고, 두 번째(**Standard**)는 PTT와 키잉용입니다. 두 포트를 구분할 수 있으면 선택기가 첫 번째를 가리킵니다.\n- **무전기에서 CAT RTS를 끄거나, RTS를 high로 유지를 켜세요.** 무전기의 **CAT RTS** 메뉴가 켜져 있으면 RTS가 low인 동안 무전기는 침묵합니다. 포트가 열릴 때 한 번 응답하고는 아무것도 보내지 않을 수 있습니다. 무전기 자체 USB 포트를 선택하면 고급 설정의 **RTS를 high로 유지**가 켜집니다. Digirig, SignaLink 또는 대부분의 자작 케이블에서는 RTS가 PTT이므로, high로 유지하면 송신기가 키잉됩니다. 이 경우 대신 무전기에서 CAT RTS를 끄세요.\n- **속도가 무전기의 CAT RATE 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.',
			'settings.station.k4SerialNotes' => 'K4 후면의 USB-B (PC) 소켓을 연결하세요. CAT에는 USB-PC1 또는 USB-PC2 모두 사용할 수 있습니다. 사용하지 않는 포트를 선택하고 무전기의 Serial USB-PCn: Baud Rate 설정과 맞추세요. HaLo는 38400을 미리 입력하며, 필요하면 변경하세요. 다른 애플리케이션은 나머지 포트나 이더넷을 사용해야 합니다.\n\n이 연결은 무전기와 키어를 제어하며, HaLo로 오디오를 보내지 않습니다.',
			'settings.station.k4TcpNotes' => 'K4의 이더넷 소켓을 로컬 네트워크에 연결하세요. 호스트 이름 또는 IP 주소와 CAT 포트 9200을 입력하세요. 팬어댑터나 워터폴이 표시될 때 HaLo는 같은 호스트의 고정 포트 9201을 사용하며, CAT 포트를 바꿔도 스펙트럼 포트는 바뀌지 않습니다.\n\n스펙트럼은 메인 수신기를 표시합니다. 줌, 기준 조정, 속도 컨트롤은 HaLo의 표시에만 영향을 줍니다. 오디오 스트리밍은 지원되지 않습니다.',
			'settings.station.k4PowerTimeout' => '무전기가 출력 범위를 확인해 주지 않아 K4 출력을 변경하지 않았습니다. 다시 시도하세요.',
			'settings.station.k4RemoteNotes' => 'K4에서 원격 접근을 활성화하고 네트워크 비밀번호를 입력하세요. 메인과 서브는 무전기 제어와 스펙트럼을 위해 하나의 암호화된 연결을 공유합니다. 기본 포트는 9204이며, 원격으로 연결할 때는 포워딩한 포트를 입력하세요.\n\n오디오 재생과 마이크 스트리밍은 지원되지 않습니다.',
			'settings.station.k4Receiver' => '수신기',
			'settings.station.k4ReceiverMain' => '메인',
			'settings.station.k4ReceiverSub' => '서브',
			'settings.station.k4ReceiverInvalid' => '메인 또는 서브를 선택하세요',
			'settings.station.k4ReceiverAlreadyConfigured' => '이 K4에는 해당 수신기가 이미 구성되어 있습니다',
			'settings.station.k4SubReceiverOff' => 'K4 서브 수신기가 꺼져 있습니다',
			'settings.station.k4RemotePasswordRequired' => '안전하게 연결하려면 K4의 네트워크 비밀번호를 입력하세요.',
			'settings.station.k4RemoteHandshakeFailed' => 'K4가 보안 연결을 수립할 수 없습니다. 네트워크 비밀번호와 원격 접근 설정을 확인하세요.',
			'settings.station.k4RemoteUnreachable' => 'K4의 보안 연결에 접속할 수 없습니다. 주소, 포트 및 원격 접근 설정을 확인하세요.',
			'settings.station.k4PowerRange' => 'K4 출력은 0.1–110 W이어야 하며, 트랜스버터 밀리와트 출력이 활성화된 경우 0.0001–0.01 W이어야 합니다.',
			'settings.station.elecraftTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.elecraftTroubleshooting' => 'Elecraft 무전기는 Kenwood CAT을 사용하며, KX2와 KX3 모두 이 방식으로 실행해 보았습니다. 양방향 VFO, 모드 전환, CW 제로비트 모두 작동합니다.\n\n무전기가 응답하지 않으면 거의 항상 다음 중 하나입니다:\n\n- **속도가 일치해야 합니다**: 무전기 메뉴의 **RS232**에 설정된 속도와 같아야 합니다. 출고값은 38400입니다. 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n\n**주파수는 맞는데 모드가 틀리면** 알려 주세요. KX2와 KX3 항목은 지금까지 본 무전기를 기준으로 고정한 상태 응답 위치에서 모드를 읽으며, 이 위치가 다른 펌웨어는 제보를 통해서만 알 수 있습니다.\n\nK3는 아직 어느 쪽으로도 보고된 적이 없으니, 사용해 보셨다면 결과를 알려 주세요. K4는 별도 항목이 있습니다.',
			'settings.station.lab599TroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.lab599Troubleshooting' => 'TX-500 시리즈는 Kenwood CAT을 사용합니다. 주파수와 모드는 LiNK500MP를 통해 실행해 보았고, 출력과 미터는 Lab599의 CAT 참조 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n- **속도가 무전기의 CAT 설정과 일치해야 합니다.** 변경하지 않았다면 9600입니다. 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **무전기에서 CAT 프로토콜을 선택하세요.** TS-2000은 주파수, 모드, 출력을 지원합니다. LAB599는 추가로 앱이 무전기를 DIG로 전환하고, DIG에서 송신하는 것을 보고, 공급 전압을 읽을 수 있게 합니다.\n- **LiNK500MP를 통해 연결할 때는** VFO 노브를 약 3초간 길게 눌러 CAT 제어를 인터페이스에 넘기세요.\n- **연결 방식에 맞게 LiNK500MP의 모드를 설정하세요**: 블루투스는 Mode 3, 블루투스 LE는 Mode 4. 다른 모드에서는 블루투스 LE 검색에 나타나지 않습니다.\n- **블루투스로 연결하면** LiNK500MP가 시리얼 포트 두 개로 페어링되며 그중 하나만 CAT을 전달합니다. 무전기가 응답하지 않으면 다른 포트를 선택하세요.',
			'settings.station.lab599TroubleshootingIos' => 'TX-500 시리즈는 Kenwood CAT을 사용합니다. 주파수와 모드는 LiNK500MP를 통해 실행해 보았고, 출력과 미터는 Lab599의 CAT 참조 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n- **검색하기 전에 LiNK500MP를 블루투스 LE 모드인 Mode 4로 설정하세요.** 다른 모드에서는 iPhone이나 iPad가 찾을 수 없습니다.\n- **CAT 제어를 LiNK500MP에 넘기세요**: 무전기의 VFO 노브를 약 3초간 길게 누르세요.\n- **무전기에서 CAT 프로토콜을 선택하세요.** TS-2000은 주파수, 모드, 출력을 지원합니다. LAB599는 추가로 앱이 무전기를 DIG로 전환하고, DIG에서 송신하는 것을 보고, 공급 전압을 읽을 수 있게 합니다.',
			'settings.station.kenwoodTroubleshootingTitle' => '무전기가 연결되었지만 주파수가 표시되지 않는 경우',
			'settings.station.kenwoodTroubleshooting' => '이 드라이버는 Kenwood TS-590SG와 TS-480, QRP Labs QMX와 QCX-mini, Elecraft KX2와 KX3에서 검증되었습니다. 나머지 모델은 공개된 CAT 문서를 바탕으로 작성되었으니, 결과가 어떻든 알려 주세요.\n\n무전기가 응답하지 않으면 거의 항상 다음 중 하나입니다:\n\n- **속도가 무전기의 CAT 메뉴와 일치해야 합니다.** 일치하지 않으면 무전기가 깨진 데이터를 보내거나 아무것도 보내지 않으며, 오류는 절대 표시되지 않습니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.\n- **일부 무전기는 메뉴에서 CAT을 활성화해야** 응답합니다.\n- **Kenwood 무전기는 RTS를 기다립니다**: CAT 포트가 RTS를 핸드셰이크로 사용하므로, 고급 설정의 RTS를 high로 유지가 켜져 있어야 합니다. 이 설정이 기본으로 켜지기 전에 만든 연결에서는 꺼져 있을 수 있습니다. Digirig 등 RTS로 PTT를 키잉하는 케이블에서는 끄세요. 그렇지 않으면 무전기가 송신합니다.\n\n**여러 SDR 프런트엔드도 같은 프로토콜을 사용하므로** 이 항목을 시도해 볼 만합니다. Elecraft 무전기는 Elecraft 아래에 별도로 있습니다. 주파수는 맞는데 모드가 틀리거나 없다면, 그것이 모델마다 다른 유일한 부분입니다. 앱이 무전기로부터 알아내고 안 되면 직접 물어보므로, 모드가 단순히 늦게 표시될 수 있습니다.',
			'settings.station.statusConnected' => '연결됨',
			'settings.station.statusLost' => '연결 끊김',
			'settings.station.notConfigured' => '구성되지 않음',
			'settings.station.currentConfiguration' => '현재 구성',
			'settings.station.currentTransceiver' => '현재 트랜시버',
			'settings.station.currentTransceivers' => '현재 트랜시버',
			'settings.station.so2rRadioName' => ({required Object radio, required Object name}) => '${radio}: ${name}',
			'settings.station.so2rQueueMessages' => '메시지를 중단하지 않고 대기열에 넣음',
			'settings.station.noRadioBSelected' => '무전기 B가 선택되지 않음',
			'settings.station.radioMode' => '무전기 모드',
			'settings.station.keyerNotSupported' => '현재 무전기에서 지원하지 않음',
			'settings.station.catControlPreferences' => 'CAT 제어 환경설정',
			'settings.station.chooseTransceiver' => '트랜시버 선택',
			'settings.station.configurationSection' => '구성',
			'settings.station.noTransceiverSelected' => '선택된 트랜시버 없음',
			'settings.station.makeMainVfo' => ({required Object name}) => '${name}을(를) 메인 VFO로 사용',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, zero: '트랜시버 없음', one: '트랜시버 ${count}대', other: '트랜시버 ${count}대', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '안테나 ${count}개', other: '안테나 ${count}개', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '기타 장치 ${count}개', other: '기타 장치 ${count}개', ), 
			'settings.station.equipmentInventory' => '장비 목록',
			'settings.station.equipmentInUse' => '트랜시버 제어',
			'settings.station.noTransceiver' => '없음',
			'settings.station.peerRadioNotAvailable' => '사용할 수 없음',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => '${device}에 있음',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio}은(는) 다른 기기에 있습니다',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => '이 무전기는 ${device}에 연결되어 있습니다. 연결과 설정은 해당 기기에서 구성합니다.',
			'settings.station.antennaInUse' => '사용 중인 안테나',
			'settings.station.keyInUse' => 'CW 키잉',
			'settings.station.phoneKeying' => '보이스 키잉',
			'settings.station.phoneKeyingNone' => '없음',
			'settings.station.phoneKeyingRadio' => ({required Object radio}) => '${radio}의 메모리',
			'settings.station.phoneKeyingComputer' => '이 컴퓨터의 오디오',
			'settings.station.phoneKeyingOff' => '보이스 키잉이 꺼져 있습니다',
			'settings.station.computerVoiceSettings' => '컴퓨터 오디오',
			'settings.station.cwKeyingOptions' => 'CW 키잉 옵션',
			'settings.station.noneSelected' => '없음',
			'settings.station.moreSettings' => '추가 설정',
			'settings.station.icomCivTroubleshootingTitle' => '같은 무전기에 시리얼 포트가 두 개 표시되는 경우',
			'settings.station.icomCivTroubleshooting' => 'IC-705를 비롯한 여러 Icom 무전기는 USB 시리얼 포트를 동시에 **두 개** 제공하며(Icom은 Port A와 Port B라고 부름), 둘 다 기본적으로 CI-V로 설정되어 있습니다. 이 앱도 OS도 그 이상으로 둘을 구분할 수 없습니다. 같은 USB 벤더/제품 ID가 두 번 나타나며, 여기서는 `#2` 접미사가 붙기도 합니다. **보통 Port A가 맞습니다.** 일반적으로 OS나 브라우저가 처음 나열하는 포트이며, 이 앱이 두 포트를 구분할 수 있으면 그 포트를 추천으로 표시합니다. 명령을 보냈는데 무전기가 응답하지 않으면 다른 포트를 시도하세요.',
			'settings.station.civAddressTroubleshootingTitle' => '무전기가 전혀 응답하지 않는 경우',
			'settings.station.civAddressTroubleshooting' => '- **CI-V 주소가 무전기의 메뉴와 일치해야 합니다.** 이 항목은 모델의 출고 주소를 미리 입력하지만, CI-V 버스를 공유하는 무전기에서는 바로 이 값이 변경됩니다. 잘못된 주소로 보낸 프레임은 조용히 무시되며, 이는 케이블 불량과 똑같아 보입니다.\n- **속도가 무전기의 CI-V BAUD RATE와 일치해야 합니다** (USB에서는 CI-V USB Baud Rate). 무전기를 여기 표시된 값과 같게 설정하고, **Auto로 두지 마세요**. Auto로 두면 IC-7300 등 일부 무전기는 연결된 후 1분쯤 지나 응답을 멈춥니다.\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.',
			'settings.station.civAddressFixedSpeedTroubleshooting' => ({required Object speed}) => '- **CI-V 주소가 무전기의 메뉴와 일치해야 합니다.** 이 항목은 모델의 출고 주소를 미리 입력하지만, CI-V 버스를 공유하는 무전기에서는 바로 이 값이 변경됩니다. 잘못된 주소로 보낸 프레임은 조용히 무시되며, 이는 케이블 불량과 똑같아 보입니다.\n${speed}\n- **다른 앱이 포트를 점유하고 있을 수 있습니다**: WSJT-X, fldigi, rigctld 모두 포트를 열어 둡니다.',
			'settings.station.icomUsbSpeedFollows' => '- **설정할 속도가 없습니다.** USB에서는 이 무전기가 컴퓨터가 사용하는 속도로 통신하며, 이 항목은 스코프에 필요한 115200을 항상 사용합니다.',
			'settings.station.ic7610UsbSpeed' => '- **CI-V USB Baud Rate를 115200으로 설정하세요.** 스코프에 필요하므로 이 항목이 항상 사용하는 속도이며, **Auto로 두지 마세요**. 다른 속도로 설정된 무전기는 응답하지 않습니다.',
			'settings.station.civTransceiveTitle' => '앱이 무전기를 느리게 따라가는 경우',
			'settings.station.civTransceive' => '무전기에서 주파수나 모드를 바꾼 후 앱에 표시되기까지 몇 초가 걸리면, 무전기의 **CI-V Transceive** 설정을 켜세요 (최신 모델 대부분은 SET > Connectors > CI-V 아래). 켜져 있으면 무전기가 변경 즉시 보고합니다. 꺼져 있으면 앱이 몇 초마다 물어볼 때에야 변경을 알게 됩니다.',
			'settings.station.ic7300Mk2Note' => '\n- **IC-7300 MK2**의 출고 주소는 여기 미리 입력된 `94`가 아닌 `B6`입니다. 대신 IC-7300 MK2 항목을 선택하세요.',
			'settings.station.ic705PortNote' => '\n- **IC-705**는 무전기 이름이 붙은 USB 시리얼 포트를 두 개 제공합니다. CI-V는 그중 **첫 번째**에 있으며, 두 포트를 구분할 수 있으면 선택기가 그 포트를 가리킵니다.',
			'settings.station.ic7760PortNote' => '\n- **IC-7760**은 제공하는 두 USB 시리얼 포트 중 **Port A**에서 CI-V를 사용합니다.',
			'settings.station.x6100PortNote' => '\n- **X6100**은 **DEV** 포트에서 CI-V를 사용합니다. 제공하는 두 시리얼 포트 중 두 번째이며, 선택기가 가리키는 포트입니다.',
			'settings.station.rigctldTroubleshootingTitle' => '앱이 연결할 수 없는 경우',
			'settings.station.rigctldTroubleshooting' => '이 항목은 무전기에 직접 연결하는 것이 아니라 **직접 실행하는 rigctld 데몬**에 연결합니다. Hamlib의 백엔드가 무전기와 통신하며 수백 개의 모델을 지원합니다.\n\n- **데몬이 이미 실행 중이어야 합니다.** 예: `rigctld -m 1035 -r /dev/ttyUSB0`. 무전기의 모델 번호는 `rigctl -l`로 찾으세요.\n- **다른 컴퓨터에서 연결하려면** `-T 0.0.0.0`으로 시작하세요. 기본적으로 rigctld는 실행 중인 컴퓨터의 연결만 받습니다.\n- **포트**는 데몬을 `-t`로 시작하지 않았다면 4532입니다.\n- 연결된 후 주파수가 표시되지 않는다면 보통 데몬 자체가 무전기에 연결하지 못하는 것입니다. 데몬이 실행 중인 컴퓨터에서 `rigctl -m 2 f`로 테스트하세요.',
			'settings.station.flrigTroubleshootingTitle' => '앱이 연결할 수 없는 경우',
			'settings.station.flrigTroubleshooting' => '이 항목은 무전기에 직접 연결하는 것이 아니라 **직접 실행하는 flrig 프로그램**에 연결합니다. flrig가 무전기와 통신하며 대부분의 제조사와 모델을 지원합니다.\n\n- **flrig가 이미 실행 중이어야 하며**, 트랜시버가 구성되고 연결되어 있어야 합니다.\n- **포트**는 flrig 구성(Config → Setup → Server)에서 변경하지 않았다면 12345입니다.\n- **다른 컴퓨터에서 연결하려면** flrig 서버에 연결할 수 있는지 확인하세요. flrig는 모든 인터페이스에서 수신 대기하지만, 방화벽이 막을 수 있습니다.\n- 연결된 후 주파수가 표시되지 않는다면 보통 flrig 자체가 무전기에 연결하지 못하는 것입니다. flrig 화면이 다이얼을 따라가는지 확인하세요.',
			'settings.station.hrdTroubleshootingTitle' => '앱이 연결할 수 없는 경우',
			'settings.station.hrdTroubleshooting' => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 Ham Radio Deluxe의 Rig Control**에 연결합니다. HRD가 무전기와 통신합니다.\n\n- **Rig Control이 이미 실행 중이며** 무전기에 연결되어 있어야 합니다.\n- **IP 서버가 활성화되어 있어야 합니다.** Rig Control은 이를 통해서만 다른 프로그램과 통신합니다.\n- **포트**는 IP 서버 설정에서 변경하지 않았다면 7809입니다.\n- **다른 컴퓨터에서 연결하려면** 방화벽이 연결을 허용하는지 확인하세요.\n\n이 항목은 HRD 프로토콜에 대한 공개 설명을 바탕으로 작성되었으며 실제 HRD에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.n3fjpTroubleshootingTitle' => '앱이 연결할 수 없는 경우',
			'settings.station.n3fjpTroubleshooting' => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 N3FJP 로깅 프로그램**에 연결합니다. N3FJP가 무전기와 통신합니다.\n\n- **프로그램의 API가 켜져 있어야 합니다**: Settings → Application Program Interface에서 **TCP API Enabled**를 체크하세요.\n- **포트**는 그곳에서 변경하지 않았다면 1100입니다.\n- 무전기를 따라가거나 튜닝하려면 **N3FJP에 무전기 인터페이스가 설정되어 있어야 합니다.** 없으면 입력 창에 입력된 값만 보고합니다.\n- N3FJP는 밴드, 모드, 주파수만 보고합니다. 출력과 송신 상태는 보고하지 않습니다.\n\n이 항목은 N3FJP가 공개한 API를 바탕으로 작성되었으며 실제 N3FJP에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.commanderTroubleshootingTitle' => '앱이 연결할 수 없는 경우',
			'settings.station.commanderTroubleshooting' => '이 항목은 무전기에 직접 연결하는 것이 아니라 **컴퓨터에서 실행 중인 DXLab Commander**에 연결합니다. Commander가 무전기와 통신합니다.\n\n- **Commander가 이미 실행 중이며** 무전기에 연결되어 있어야 합니다.\n- **네트워크 서비스가 켜져 있어야 합니다**: Commander 구성 창의 Radio 패널에 있는 **Net Serv** 버튼.\n- **포트**는 52002이며, Net Serv의 **Base Port**(변경하지 않았다면 52000)부터 시작하는 블록의 세 번째 포트입니다.\n- **다른 컴퓨터에서 연결하려면** 방화벽이 연결을 허용하는지 확인하세요.\n\n이 항목은 Commander가 공개한 TCP 메시지를 바탕으로 작성되었으며 실제 Commander에서 실행해 본 적이 없습니다. 부분적으로만 작동한다면 제보해 주세요.',
			'settings.station.ic705TroubleshootingTitle' => '무전기가 전혀 응답하지 않는 경우',
			'settings.station.ic705Troubleshooting' => '무전기는 원격 제어 세션을 **하나만** 지원합니다. 로그인이 무시된다면 거의 항상 다른 무언가가 세션을 사용 중입니다.\n\n- **다른 클라이언트를 모두 닫으세요.** 같은 무전기에 연결된 wfview나 RS-BA1이 그 세션을 점유하며, 그동안 여기서의 로그인은 그냥 무시됩니다.\n- **무전기의 네트워크 설정을 확인하세요.** WLAN이 켜져 있고, 무전기가 같은 네트워크에 있으며, 원격 제어(Network) 기능이 활성화되어 있어야 합니다.\n- **포트가 일치해야 합니다.** 무전기의 Control Port와 Serial Port (UDP), 또는 그곳으로 포워딩된 포트와 같아야 합니다. 포트가 틀리면 꺼진 무전기와 똑같이 아무 응답이 없습니다.\n- 계속 멈춰 있다면 **무전기의 WLAN을 껐다 켜세요.** 무전기에 멈춰 있는 세션이 확실히 해제됩니다.\n\n**비밀번호가 틀리면 명시적으로 거부**되며, 응답이 없는 것이 아닙니다. "거부됨" 메시지 대신 이 화면이 나왔다면 비밀번호 문제가 아닙니다.',
			'settings.station.icomLanTroubleshooting' => '무전기는 원격 제어 세션을 **하나만** 지원합니다. 로그인이 무시된다면 거의 항상 다른 무언가가 세션을 사용 중입니다.\n\n- **다른 클라이언트를 모두 닫으세요.** 같은 무전기에 연결된 wfview, RS-BA1 또는 Icom의 Remote Utility가 그 세션을 점유하며, 그동안 여기서의 로그인은 그냥 무시됩니다.\n- **무전기의 네트워크 설정을 확인하세요.** LAN 포트가 이 기기와 같은 네트워크에 연결되어 있고, **Network Control**이 켜져 있으며, 사용자 이름과 비밀번호가 무전기에 네트워크 사용자로 설정되어 있어야 합니다.\n- **포트가 일치해야 합니다.** 무전기의 Control Port와 Serial Port (UDP), 또는 그곳으로 포워딩된 포트와 같아야 합니다. 포트가 틀리면 꺼진 무전기와 똑같이 아무 응답이 없습니다.\n- **연결은 되는데 응답이 없다면**, 여기의 CI-V 주소가 무전기의 CI-V ADDRESS 메뉴와 일치해야 합니다. 이 항목은 모델의 출고 주소를 미리 입력합니다.\n- 계속 멈춰 있다면 **무전기를 껐다 켜세요.**',
			'settings.station.statusStale' => '응답 없음',
			'settings.station.statusDisconnected' => '연결 안 됨',
			'settings.station.statusConnecting' => '연결 중…',
			'settings.station.statusDisconnecting' => '연결 해제 중…',
			'settings.station.statusError' => '연결 실패',
			'settings.station.currentRadioSettings' => '현재 무전기 설정',
			'settings.station.notSupportedByThisRadio' => '이 무전기에서 지원하지 않음',
			'settings.station.cwMessagesButton' => 'CW 메시지',
			'settings.station.voiceMessagesButton' => '보이스 메시지',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => '보이스 키어: 무전기에 메모리 ${count}개',
			'settings.station.antennaBands' => '밴드',
			'settings.station.antennaType' => '안테나 유형',
			'settings.station.antennaTypeRequired' => '안테나 유형을 선택하세요',
			'settings.station.antennaTypes.dipole' => '다이폴',
			'settings.station.antennaTypes.vertical' => '버티컬',
			'settings.station.antennaTypes.yagiBeam' => '야기 / 빔',
			'settings.station.antennaTypes.loop' => '루프',
			'settings.station.antennaTypes.longWire' => '롱 와이어 / EFHW',
			'settings.station.antennaTypes.other' => '기타',
			'settings.station.keyType' => '키 유형',
			'settings.station.keyTypeRequired' => '키 유형을 선택하세요',
			'settings.station.keyTypes.straight' => '스트레이트 키',
			'settings.station.keyTypes.sideswiper' => '사이드스와이퍼',
			'settings.station.keyTypes.bug' => '버그 (기계식 반자동)',
			'settings.station.keyTypes.fullyAutomatic' => '전자동 키어',
			'settings.station.keyTypes.singlePaddle' => '싱글 패들',
			'settings.station.keyTypes.dualPaddle' => '듀얼 패들',
			'settings.station.keyTypes.computerDriven' => '컴퓨터 제어',
			'settings.station.keyTypes.other' => '기타',
			'settings.station.softwareIntermediaries' => '중계 소프트웨어',
			'settings.station.otherBrands' => '기타 브랜드',
			'settings.station.otherEquipment' => '기타 장비 (안테나, 키 등)',
			'settings.station.newAntenna' => '새 안테나',
			'settings.station.newKey' => '새 키',
			'settings.station.newKeyer' => 'WinKeyer (K1EL 또는 호환)',
			'settings.station.keyViaRadio' => ({required Object radio}) => '${radio}의 CAT 키어',
			_ => null,
		} ?? switch (path) {
			'settings.station.keyOnDevice' => ({required Object device}) => '${device}의 키',
			'settings.station.trackStationInfo' => 'QSO마다 무선국 정보 기록',
			'settings.station.includeStationInfoInAdif' => 'ADIF 내보내기에 포함',
			'settings.station.whatToTrack' => '무엇을 기록할까요?',
			'settings.station.trackFieldRig' => '트랜시버',
			'settings.station.trackFieldPower' => '출력',
			'settings.station.watts' => '와트',
			'settings.station.trackFieldAntenna' => '안테나',
			'settings.station.trackFieldKey' => 'CW 키',
			'settings.station.placeholderConnectDelay' => '연결 지연 (ms)',
			'settings.station.placeholderConnectDelayDescription' => '시뮬레이션된 핸드셰이크에 걸리는 시간. 비워 두거나 0이면 즉시 연결됩니다.',
			'settings.station.placeholderDropAfter' => '연결 끊기 (초)',
			'settings.station.placeholderDropAfterDescription' => '재연결 경로를 시험하기 위해 스스로 연결을 끊습니다. 비워 두거나 0이면 끊지 않습니다.',
			'settings.station.placeholderFailConnect' => '항상 연결 실패',
			'settings.station.placeholderConnectFailure' => '임시 무전기가 이 연결을 거부하도록 설정되었습니다',
			'settings.station.placeholderFreq' => '주파수 (kHz)',
			'settings.station.placeholderFreqDescription' => '임시 무전기의 시작 주파수. 이후에는 앱이 튜닝한 값을 그대로 보고합니다.',
			'settings.station.placeholderMode' => '모드',
			'settings.station.placeholderModeDescription' => '임시 무전기의 시작 모드. 예: USB, CW, FT8.',
			'settings.station.placeholderPower' => '출력 (와트)',
			'settings.station.placeholderPurpose' => '로깅을 위해 어떤 장비를 사용 중인지 기록하는 데 이 무전기를 사용하세요',
			'settings.station.placeholderReplyDelay' => '응답 지연 (ms)',
			'settings.station.placeholderReplyDelayDescription' => '임시 무전기가 변경 사항을 보고하는 데 걸리는 시간. 비워 두거나 0이면 즉시 응답합니다.',
			'settings.station.cwKeyerField' => 'CAT CW 키어',
			'settings.station.cwKeyerFieldDescription' => '이 무전기가 CAT으로 텍스트를 받아 CW를 키잉하는지 여부. 앱이 모르는 무전기는 끄세요.',
			'settings.station.voiceMemories' => '보이스 메모리',
			'settings.station.voiceMemoriesDescription' => '무전기가 CAT으로 재생하는 보이스 메모리 수. 없으면 0.',
			'settings.station.voiceMemoriesInvalid' => '0 이상의 정수',
			'settings.station.yaesuMeterCapture' => '미터 값 캡처',
			'settings.station.yaesuBinaryMeterCaptureDescription' => '송신 중 무전기의 출력 미터와 높은 SWR 플래그를 읽어 원시 값을 로그에 기록합니다. Yaesu가 공개하지 않은 눈금을 만들기 위한 것이며, 값은 미터로 표시되지 않습니다.',
			'settings.station.yaesuMeterCaptureDescription' => '송신 중 무전기의 PO, SWR, ALC 미터를 읽어 원시 값을 로그에 기록합니다. Yaesu가 공개하지 않은 눈금을 만들기 위한 것이며, 값은 미터로 표시되지 않습니다.',
			'settings.station.telemetryInterval' => '미터 읽기 간격 (ms)',
			'settings.station.telemetryIntervalDescription' => '송신 중 무전기의 미터를 읽는 간격. 비워 두면 이 연결이 처리할 수 있는 가장 빠른 간격(최대 200 ms)을 사용합니다.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 밀리초',
			'settings.station.pollInterval' => '유휴 폴링 간격 (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => '주파수와 모드가 바뀌지 않는 동안 무전기에 이를 묻는 간격. 비워 두면 ${fallback} ms입니다.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 밀리초',
			'settings.station.advancedSettings' => '고급 설정',
			'settings.station.placeholderSwr' => 'SWR 값',
			'settings.station.placeholderSwrDescription' => '송신 중 이 무전기가 SWR 미터에 보고하는 값. 1.8을 넘으면 패널이 경고합니다.',
			'settings.station.placeholderSwrInvalid' => '1 이상의 숫자',
			'settings.station.keyerNone' => '없음',
			'settings.station.cwDialect' => 'CW 키잉 방식',
			'settings.station.cwDialectDescription' => '이 무전기가 받는 KY 명령의 형태. 없음은 CAT을 통한 CW 키잉이 없음을 뜻합니다.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, 24자로 채움)',
			'settings.station.cwDialectElecraft' => 'Elecraft (KY 텍스트)',
			'settings.station.voiceDialect' => '보이스 키어 방식',
			'settings.station.voiceDialectDescription' => '이 무전기가 CAT으로 보이스 메모리를 재생하는 방식. 없음은 CAT을 통한 보이스 메모리가 없음을 뜻합니다. 방식을 선택하고 개수를 비워 두면 해당 방식의 기본 개수가 적용됩니다.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, TS-590 방식)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB 및 DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (스위치 탭)',
			'settings.station.placeholderDiagnostic' => '시뮬레이션',
			'settings.station.placeholderWholeNumberInvalid' => '0 이상의 정수여야 합니다',
			'settings.station.placeholderFreqInvalid' => '0보다 큰 kHz 단위 주파수여야 합니다',
			'settings.station.placeholderModeInvalid' => '모드 이름이어야 합니다. 예: USB, CW, FT8',
			'settings.station.switchLayout' => '레이아웃',
			'settings.station.switchLayoutDescription' => '무전기가 스위치의 어느 쪽에 연결되어 있는지.',
			'settings.station.switchLayoutRequired' => '스위치 배선 방식을 선택하세요',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => '스위치가 "${command}"을(를) 거부했습니다 (오류 ${code})',
			'settings.station.switchBusyTransmitting' => '해당 포트가 송신 중입니다 — 안테나를 변경하지 않았습니다',
			'settings.station.switchNoAntenna' => '없음',
			'settings.station.switchAntennaFor' => ({required Object port}) => '포트 ${port} 안테나',
			'settings.station.switchAntennaForDescription' => '스위치의 이 포트에 연결된 안테나.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '안테나 ${antennas}개, 무전기 ${radios}대',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '안테나 ${antennas}개, 무전기 1대',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '안테나 1개, 무전기 ${radios}대',
			'settings.station.switchCommonPort' => '공통',
			'settings.station.dcnAddress' => '장치 주소',
			'settings.station.dcnAddressDescription' => '모듈의 DIP 스위치에 설정된 주소. 동축 릴레이 모듈의 출고값은 2입니다.',
			'settings.station.dcnAddressRequired' => '1에서 99 사이의 장치 주소여야 합니다',
			'settings.station.switchPortLabel' => ({required Object port}) => '포트 ${port}',
			'settings.station.switchPortAutoHint' => '밴드 데이터를 따름',
			'settings.station.switchPortTransmittingHint' => '송신 중 — 지금은 변경할 수 없음',
			'settings.station.switchCurrentStateHeader' => '현재 상태',
			'settings.station.switchCurrentStateDescription' => '지금 각 무전기 포트가 연결된 안테나. 변경 사항은 즉시 적용됩니다.',
			'settings.station.switchWiringHeader' => '배선',
			'settings.station.switchPortInhibitedHint' => '송신 금지됨',
			'settings.station.rotatorAxes' => '축',
			'settings.station.rotatorAxesDescription' => '로테이터가 방위각만 회전하는지, 앙각도 회전하는지 (G-5500 등).',
			'settings.station.rotatorAxesAzimuth' => '방위각만',
			'settings.station.rotatorAxesAzimuthElevation' => '방위각 및 앙각',
			'settings.station.rotatorAzimuthOffset' => '방위각 오프셋',
			'settings.station.rotatorAzimuthOffsetDescription' => '컨트롤러의 0점이 진북이 아닐 때 읽은 값에 더할 각도. 회전도 이에 맞게 보정됩니다.',
			'settings.station.rotatorElevationOffset' => '앙각 오프셋',
			'settings.station.rotatorAzimuthMin' => '최소 방위각',
			'settings.station.rotatorAzimuthMax' => '최대 방위각',
			'settings.station.rotatorAzimuthMaxDescription' => '컨트롤러 자체의 각도 단위. 오버랩이 있는 로테이터는 360 이상으로 설정하면 더 짧은 쪽으로 회전합니다.',
			'settings.station.rotatorElevationMin' => '최소 앙각',
			'settings.station.rotatorElevationMax' => '최대 앙각',
			'settings.station.rotatorElevationMaxDescription' => '컨트롤러 자체의 각도 단위. 뒤집히는(플립) 로테이터는 90 이상.',
			'settings.station.rotatorDegreesInvalid' => ({required Object min, required Object max}) => '${min}에서 ${max} 사이의 정수 각도',
			'settings.station.rotatorLimitsInvalid' => '최소 한계는 최대보다 작아야 합니다',
			'settings.station.rotatorPollInterval' => '폴링 간격 (ms)',
			'settings.station.rotatorPollIntervalDescription' => ({required Object fallback}) => '로테이터에 방향을 묻는 간격. 비워 두면 ${fallback} ms입니다.',
			'settings.station.rotatorAxesRequired' => '로테이터가 회전하는 축을 선택하세요',
			'settings.station.rotatorRefused' => '컨트롤러가 명령을 거부했습니다. GS-232 모드로 설정되어 있는지 확인하세요.',
			'settings.station.pstRotatorTroubleshooting' => 'PstRotator는 설정이 되어 있을 때만 응답하며, 그렇지 않으면 전혀 응답하지 않습니다:\n\n- PstRotator의 Setup 메뉴에서 **UDP Control을 켜세요.**\n- **포트를 맞추세요**: Communication → UDP Control Port, 변경하지 않았다면 12000. PstRotator는 그 다음 포트(12001)로 응답하므로, 이 기기에서 그 포트가 비어 있어야 합니다.\n- **PstRotator를 컨트롤러에 연결하세요.** 연결되기 전에는 UDP로 아무 응답도 하지 않습니다.\n- PstRotator를 실행하는 PC와, 응답을 수신하는 이 기기 양쪽에서 **방화벽을 통과하도록 허용하세요.**\n- **Mac, iPhone 또는 iPad에서는** Ham2K Logger에 로컬 네트워크 접근 권한이 필요합니다 (설정 → 개인정보 보호 및 보안 → 로컬 네트워크).',
			'settings.station.rotatorCurrentStateHeader' => ({required Object position}) => '현재 상태: ${position}',
			'settings.station.rotatorDisconnected' => '연결 끊김',
			'settings.station.rotatorAzimuthReading' => ({required Object degrees}) => '방위각 ${degrees}°',
			'settings.station.rotatorAzimuthReadingShort' => ({required Object degrees}) => 'AZ ${degrees}°',
			'settings.station.rotatorElevationReading' => ({required Object degrees}) => '앙각 ${degrees}°',
			'settings.station.rotatorElevationReadingShort' => ({required Object degrees}) => 'EL ${degrees}°',
			'settings.station.rotatorNoReading' => '컨트롤러가 위치를 보고하기를 기다리는 중…',
			'settings.station.rotatorNotResponding' => '응답 없음',
			'settings.station.rotatorHeldAtLimit' => ({required Object heading}) => '이 로테이터의 한계 내에서 ${heading}(으)로 회전 중',
			'settings.station.rotatorTargetAzimuth' => '방위각으로 회전',
			'settings.station.rotatorTargetAzimuthShort' => 'AZ로 회전',
			'settings.station.rotatorTargetElevation' => '앙각으로 회전',
			'settings.station.rotatorTargetElevationShort' => 'EL로 회전',
			'settings.station.rotatorAzimuthInvalid' => '0에서 360 사이여야 합니다',
			'settings.station.rotatorElevationInvalid' => '0에서 180 사이여야 합니다',
			'settings.station.rotatorTurn' => '회전',
			'settings.station.rotatorStop' => '정지',
			'settings.station.configUnreadable' => '이 무전기의 저장된 설정을 읽을 수 없습니다. 설정을 열어 다시 입력하거나, 제거한 후 다시 추가하세요.',
			'settings.station.autoConnectHeld' => '지난번 이 무전기에 연결했을 때 HaLo가 응답을 멈췄기 때문에 이번에는 자동으로 연결하지 않았습니다. 다시 시도하려면 연결을 누르세요.',
			'settings.offlineData.title' => '오프라인 데이터',
			'settings.offlineData.noFiles' => '데이터 파일 없음',
			'settings.offlineData.noFilesDescription' => '활동 또는 조회 확장 기능을 활성화하면 여기서 오프라인 데이터를 다운로드할 수 있습니다.',
			'settings.offlineData.refresh' => '새로고침',
			'settings.offlineData.refreshing' => '새로고침 중…',
			'settings.offlineData.updateAll' => '모두 업데이트',
			'settings.offlineData.updatingAll' => '모든 데이터 파일 업데이트 중…',
			'settings.offlineData.neverDownloaded' => '다운로드한 적 없음',
			'settings.offlineData.updatedJustNow' => '방금 업데이트됨',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => '${days}일 전 업데이트됨',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => '${days}일 ${hours}시간 전 업데이트됨',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => '${hours}시간 전 업데이트됨',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => '${hours}시간 ${minutes}분 전 업데이트됨',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => '${minutes}분 전 업데이트됨',
			'settings.offlineData.lastDownloadRefused' => ({required Object existing, required Object imported}) => '마지막 다운로드에는 기록이 ${existing}개 중 ${imported}개뿐이어서 사용하지 않았습니다. 받아들이려면 새로고침하세요.',
			'settings.offlineData.extensionsSection' => '확장 기능',
			'settings.profiles.notSet' => '설정되지 않음',
			'settings.profiles.personalInfo' => '개인 정보',
			'settings.profiles.personalInfoNote' => '제출에 필요한 경우 생성된 로그에 포함될 수 있습니다',
			'settings.profiles.name' => '이름',
			'settings.profiles.email' => '이메일',
			'settings.profiles.club' => '클럽',
			'settings.profiles.arrlSection' => 'ARRL 섹션',
			'settings.profiles.racSection' => 'RAC 섹션',
			'settings.profiles.section' => '섹션',
			'settings.search.clear' => '지우기',
			'settings.search.hint' => '환경설정 검색',
			'settings.developer.developerModeDescription' => '개발자 경고, 디버그 로그 및 도구 활성화.',
			'settings.developer.experiments' => '실험기능',
			'settings.developer.showIdleMetrics' => '유휴 지표 표시',
			'settings.developer.showIdleMetricsDescription' => '지난 1초 동안 확장 기능 엔진이 얼마나 유휴 상태였는지 상태 표시줄에 표시합니다. 탭하면 10초 및 60초 평균을 볼 수 있습니다.',
			'settings.developer.idleMetricsReadout' => ({required Object percent}) => '유휴 ${percent}%',
			'settings.developer.idleMetricsAverages' => '유휴 평균:',
			'settings.developer.idleMetricsWindow' => ({required Object seconds, required Object percent}) => '${seconds}초 ${percent}%',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개 활성화됨', other: '${count}개 활성화됨', ), 
			'settings.developer.patchTrack' => '코드 푸시 트랙',
			'settings.developer.patchTrackDescription' => '이 기기가 따르는 무선(OTA) 코드 푸시 링. 모험적인 링일수록 수정 사항을 더 빨리 받지만 테스트가 덜 되어 있습니다. 코드 푸시는 다음 재시작 시 적용됩니다.',
			'settings.developer.trackStable' => '안정',
			'settings.developer.trackUnstable' => '불안정',
			'settings.developer.trackBleeding' => '최신',
			'settings.developer.checkingTrack' => ({required Object track}) => '"${track}"에서 코드 푸시 확인 중…',
			'settings.developer.patchDownloaded' => '코드 푸시를 다운로드했습니다. 적용하려면 앱을 다시 시작하세요.',
			'settings.developer.noNewPatch' => ({required Object track}) => '"${track}"에 새 코드 푸시가 없습니다.',
			'settings.developer.noPatchInstalled' => '설치된 코드 푸시 없음 — 릴리스 바이너리 실행 중.',
			'settings.developer.runningPatch' => ({required Object patch}) => '코드 푸시 #${patch} 실행 중.',
			'settings.developer.deepLinks' => '딥 링크',
			'settings.developer.registerUrlSchemes' => 'URL 스킴 등록',
			'settings.developer.registerUrlSchemesDescription' => 'com.ham2k:// 링크가 이 앱을 열도록 허용',
			'settings.developer.registerUrlSchemesDone' => '이제 이 앱이 com.ham2k:// 링크를 엽니다',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => '등록할 수 없습니다: ${error}',
			'settings.developer.systemInformation' => '시스템 정보',
			'settings.developer.appVersion' => '앱 버전',
			'settings.developer.dataFolder' => '데이터 폴더',
			'settings.developer.loading' => '(로딩 중…)',
			'settings.developer.panelLoadFailed' => '이 설정 패널을 불러올 수 없습니다.',
			'settings.developer.extDevServer' => '확장 기능 개발 서버',
			'settings.developer.extensionSettings' => '확장 기능 설정',
			'settings.developer.extDevServerDescription' => '앱에 내장된 확장 기능 대신 네트워크의 개발 서버에서 확장 기능을 불러오고, 저장할 때마다 다시 불러옵니다.',
			'settings.developer.extDevServerAddress' => '서버 주소',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => '연결',
			'settings.developer.extDevServerDisconnect' => '연결 해제',
			'settings.developer.extDevServerConnecting' => '연결 중…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '확장 기능 ${count}개 제공 중: ${keys}', other: '확장 기능 ${count}개 제공 중: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => '연결 안 됨',
			'settings.developer.extDevServerReconnect' => '실행 시 다시 연결',
			'settings.developer.extDevServerLastReload' => ({required Object time, required Object key}) => '마지막 다시 불러오기: ${time}에 ${key}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '확장 기능 ${count}개 빌드 실패', other: '확장 기능 ${count}개 빌드 실패', ), 
			'settings.developer.catalog' => '확장 기능 카탈로그',
			'settings.developer.catalogDescription' => '다른 서버에서 카탈로그를 읽습니다. 카탈로그 자체를 작업할 때는 로컬 서버를 사용하세요. 비워 두면 catalog.ham2k.net을 사용합니다.',
			'settings.developer.catalogAddress' => '카탈로그 주소',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => '카탈로그 검색 트랙',
			'settings.developer.catalogSearchStable' => '안정만',
			'settings.developer.catalogSearchUnstable' => '불안정 이상',
			'settings.developer.catalogSearchBleeding' => '최신 이상',
			'settings.about.notices' => '공지 및 메시지',
			'settings.about.noticesDescription' => '공지 사항 및 상태 메시지',
			'settings.about.releaseNotes' => '릴리스 노트',
			'settings.about.copiedVersion' => '버전 정보를 클립보드에 복사했습니다',
			'settings.panels.settings' => '앱 환경설정',
			'settings.panels.settingsDescription' => '원하는 대로 앱 설정하기',
			'settings.panels.commonSettings' => '일반 환경설정',
			'settings.panels.syncDescription' => '로그를 백업하고 여러 기기 간에 동기화',
			'settings.panels.accountsDescription' => '서비스 인증 정보, 오프라인 데이터 등',
			'settings.panels.extensions' => '확장 기능 및 앱 기능',
			'settings.panels.extensionsDescription' => '활동, 컨테스트, 대시보드 패널 및 기타 기능',
			'settings.panels.profilesDescription' => '오퍼레이터 콜사인 및 무선국 프로필',
			'settings.panels.stationProfiles' => '무선국 프로필',
			'settings.panels.developerSettings' => '개발자 설정',
			'settings.panels.developerSettingsDescription' => '디버깅 및 개발 도구',
			'settings.panels.about' => '정보',
			'settings.panels.aboutDescription' => '버전, 크레딧 및 법적 정보',
			'settings.panels.unavailableTitle' => '일부 설정을 사용할 수 없습니다',
			'settings.panels.unavailableText' => '확장 기능 런타임이 시작되지 않아 확장 기능이 제공하는 설정이 없습니다.',
			'settings.panels.station' => '무선국 구성',
			'settings.panels.stationDescription' => 'CAT 제어 및 기타 옵션',
			'settings.panels.peers' => '피어 기기',
			'settings.panels.peersDescription' => '근처의 다른 기기와 연결',
			'settings.showMoreSettings' => '추가 설정 표시',
			'settings.gridPrecision' => '그리드 정밀도',
			'settings.gridPrecisionOpts.six' => '6자리 (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8자리 (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6자리',
			'settings.gridPrecisionDescription.eight' => '8자리',
			'commands.enableSyncFirst' => '먼저 설정에서 동기화를 활성화하세요.',
			'commands.fullResyncStarted' => '전체 재동기화를 시작했습니다. 로컬 데이터는 먼저 백업되었습니다.',
			'commands.noDataFilesMatched' => ({required Object target}) => '"${target}"과(와) 일치하는 데이터 파일이 없습니다.',
			'commands.reloadFailed' => ({required Object error}) => '다시 불러오기 실패: ${error}',
			'commands.reloadingAll' => '모든 데이터 파일 다시 불러오는 중…',
			'commands.reloadingTarget' => ({required Object target}) => '${target} 데이터 파일 다시 불러오는 중…',
			'commands.unknownExperiment' => ({required Object token}) => '알 수 없는 실험기능 "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} 활성화됨',
			'commands.experimentDisabled' => ({required Object name}) => '${name} 비활성화됨',
			'commands.sentryTestSent' => '테스트 오류 보고서를 Sentry로 보냈습니다',
			'commands.idleMetricsEnabled' => '상태 표시줄의 유휴 지표 활성화됨',
			'commands.idleMetricsDisabled' => '유휴 지표 비활성화됨',
			'commands.sentryTestLocalOnly' => '이 빌드에서는 Sentry가 비활성화되어 있습니다. 테스트 오류는 로컬에만 기록되었습니다',
			'commands.noOperationOpen' => '이 명령은 운용이 열려 있어야 사용할 수 있습니다',
			'commands.unknownSegmentKind' => ({required Object kind}) => '\'${kind}\'을(를) 표시하는 방법을 모릅니다',
			'commands.goUnavailable' => ({required Object place}) => '${place}은(는) 이 앱에서 켜져 있지 않습니다',
			'commands.goUnknown' => ({required Object to}) => '\'${to}\'(으)로 이동하는 방법을 모릅니다',
			'commands.goBlocked' => '먼저 열린 대화 상자를 닫으세요',
			'commands.operationAlreadyStarted' => '이 운용에는 이미 시작 마커가 있습니다',
			'commands.couldNotOpenLocation' => '휴식을 추가했지만 위치 화면을 열 수 없습니다',
			'commands.noTestOperations' => '영구 삭제할 테스트 운용이 없습니다',
			'commands.purgeTestsUnavailable' => 'PURGETESTS는 확인 대화 상자를 표시해야 하지만 여기서는 사용할 수 없습니다',
			'commands.syncAllUnavailable' => 'SYNCALL은 확인 대화 상자를 표시해야 하지만 여기서는 사용할 수 없습니다',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '테스트 운용 ${count}개를 영구 삭제했습니다', other: '테스트 운용 ${count}개를 영구 삭제했습니다', ), 
			'commands.purgeTestsSomeFailed' => ({required Object total, required Object purged}) => '테스트 운용 ${total}개 중 ${purged}개를 영구 삭제했습니다. 나머지는 실패했으니 PURGETESTS를 다시 시도하세요',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '운용에 속하지 않은 테스트 교신 ${count}개를 영구 삭제했습니다', other: '운용에 속하지 않은 테스트 교신 ${count}개를 영구 삭제했습니다', ), 
			'commands.purgeTestsContactsFailed' => '테스트 운용은 영구 삭제했지만, 운용에 속하지 않은 테스트 교신은 실패했습니다. PURGETESTS를 다시 시도하세요',
			'commands.purgeTestsNothingToDo' => '영구 삭제된 항목이 없습니다',
			'commands.receivedPurgesSomeFailed' => ({required Object total, required Object removed}) => '테스트 운용 ${total}개 중 ${removed}개를 제거했습니다. 나머지는 실패했으니 검토를 다시 시도하세요',
			'commands.receivedPurgesFailed' => '해당 테스트 운용을 제거할 수 없습니다. 검토를 다시 시도하세요',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '다른 기기에서 테스트 운용 ${count}개가 제거되었습니다', other: '다른 기기에서 테스트 운용 ${count}개가 제거되었습니다', ), 
			'commands.receivedPurgesReview' => '검토',
			'commands.settingOn' => '켜짐',
			'commands.settingOff' => '꺼짐',
			'commands.settingEmpty' => '(비어 있음)',
			'commands.settingSecretSet' => '(설정됨)',
			'commands.settingSecretUnset' => '(설정되지 않음)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count}개 선택됨',
			'commands.settingExpectsOnOff' => 'on 또는 off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => '다음 중 하나: ${choices}',
			'commands.settingExpectsNumber' => '숫자',
			'commands.settingVanished' => ({required Object label}) => '“${label}”을(를) 더 이상 사용할 수 없습니다',
			'commands.noCwKeyer' => 'CW를 키잉할 수 있는 연결된 무전기가 없습니다',
			'commands.noKeyer' => 'CW를 키잉하거나 보이스 메모리를 재생할 수 있는 연결된 무전기가 없습니다',
			'commands.keyerNeedsOperation' => 'CW 키어를 사용하려면 운용을 여세요',
			'commands.keyerExperimentOff' => 'CW 키잉이 꺼져 있습니다. EXP KEYER로 켜세요',
			'commands.esmExperimentOff' => 'Enter로 메시지 전송이 꺼져 있습니다. EXP ESM으로 켜세요',
			'commands.cwSending' => ({required Object text}) => 'CW 전송 중: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'CW 메시지 F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'CW 메시지 F${n}을(를) 보내지 못했습니다: 확장 기능이 준비되지 않았습니다',
			'commands.voiceMessageError' => ({required Object n, required Object error}) => '보이스 메시지 M${n}: ${error}',
			'commands.voiceMessageNotRendered' => '확장 기능이 준비되지 않았습니다',
			'commands.so2rRadioCannotKey' => ({required Object radio}) => '전송되지 않음: 무전기 ${radio}은(는) 해당 메시지를 키잉할 수 없습니다',
			'commands.so2rNoRadioB' => '전송되지 않음: 이 메시지 세트로 키잉하려면 무선국 구성에서 무전기 B를 선택하세요',
			'commands.settingNotStored' => ({required Object label}) => '“${label}”이(가) 해당 값을 받아들이지 않았습니다',
			'commandDialog.hint' => '콜사인을 검색하거나 명령을 입력하세요',
			'commandDialog.noResults' => ({required Object text}) => '“${text}”과(와) 일치하는 항목이 없습니다',
			'commandDialog.sectionCommands' => '명령',
			'commandDialog.sectionGoTo' => '이동',
			'commandDialog.sectionOperations' => '운용',
			'commandDialog.goHome' => '홈',
			'commandDialog.goSettings' => '설정',
			'commandDialog.goNewOperation' => '새로운 운용',
			'commandDialog.runTyped' => ({required Object text}) => '“${text}” 실행',
			'commandDialog.sectionSuggestions' => '추천',
			'commandDialog.lookingUp' => '콜사인 조회 중…',
			'commandDialog.blockedByPane' => '패널이나 대화 상자가 열려 있는 동안에는 명령을 사용할 수 없습니다',
			'keyboardShortcuts.title' => '키보드 단축키',
			'keyboardShortcuts.description' => '키 매핑 사용자 지정',
			'keyboardShortcuts.search' => '명령 및 키 검색',
			'keyboardShortcuts.import' => '가져오기…',
			'keyboardShortcuts.export' => '내보내기…',
			'keyboardShortcuts.resetAll' => '모두 초기화',
			'keyboardShortcuts.resetAllTitle' => '모든 단축키를 초기화할까요?',
			'keyboardShortcuts.resetAllBody' => '모든 명령이 기본 키로 돌아가고, 직접 입력한 명령에 할당된 키는 제거됩니다.',
			'keyboardShortcuts.reset' => '초기화',
			'keyboardShortcuts.noKey' => '키 없음',
			'keyboardShortcuts.changed' => '변경됨',
			'keyboardShortcuts.conflict' => ({required Object keys, required Object commands}) => '${keys}은(는) ${commands}에도 할당되어 있습니다',
			'keyboardShortcuts.groupApp' => '앱',
			'keyboardShortcuts.groupKeying' => '키잉',
			'keyboardShortcuts.groupLogging' => '로깅',
			'keyboardShortcuts.groupCommands' => '명령',
			'keyboardShortcuts.groupFixed' => '고정 키',
			'keyboardShortcuts.contextApp' => '어디서나',
			'keyboardShortcuts.contextLogView' => '운용, 추적 및 로그 화면',
			'keyboardShortcuts.contextOperation' => '운용 화면, CAT 무전기 키잉 시',
			'keyboardShortcuts.contextLogging' => '로깅 패널에서',
			'keyboardShortcuts.addCommand' => '명령 추가…',
			'keyboardShortcuts.unknownCommand' => ({required Object command}) => '알 수 없는 명령: ${command}',
			'keyboardShortcuts.command.commandDialog' => '명령 대화 상자 열기',
			'keyboardShortcuts.command.toggleTheme' => '라이트/다크 전환',
			'keyboardShortcuts.command.toggleLanguage' => '영어/스페인어 전환',
			'keyboardShortcuts.command.fontScaleUp' => '글자 크게',
			'keyboardShortcuts.command.fontScaleDown' => '글자 작게',
			'keyboardShortcuts.command.fontScaleReset' => '글자 크기 표준으로',
			'keyboardShortcuts.command.densityLooser' => '레이아웃 여유 있게',
			'keyboardShortcuts.command.densityDenser' => '레이아웃 조밀하게',
			'keyboardShortcuts.command.densityAuto' => '레이아웃 밀도 자동',
			'keyboardShortcuts.command.find' => '로그에서 찾기',
			'keyboardShortcuts.command.keyerMessage' => ({required Object n}) => '메시지 ${n} 전송',
			'keyboardShortcuts.command.keyboardMode' => '키보드 모드 켜기/끄기',
			'keyboardShortcuts.command.ptt' => 'PTT (눌러서 송신)',
			'keyboardShortcuts.command.wipe' => '입력 중인 교신 지우기',
			'keyboardShortcuts.fixed.callsign' => '콜사인 입력',
			'keyboardShortcuts.fixed.escape' => '전송 중지, 한 단계 뒤로, 또는 닫기',
			'keyboardShortcuts.fixed.enter' => '교신 로깅',
			'keyboardShortcuts.fixed.space' => '다음 필드',
			'keyboardShortcuts.fixed.tab' => '다음 또는 이전 필드',
			'keyboardShortcuts.fixed.arrows' => '필드, 컨트롤, 로그 사이 이동',
			'keyboardShortcuts.fixed.walk' => '로그 페이지 넘기기 또는 처음/끝으로 이동',
			'keyboardShortcuts.fixed.undo' => '지우기 또는 삭제 되돌리기',
			'keyboardShortcuts.editor.addShortcut' => '단축키 추가',
			'keyboardShortcuts.editor.listening' => '단축키로 쓸 키를 누르세요…',
			'keyboardShortcuts.editor.listeningHint' => 'Esc를 누르면 중단합니다',
			'keyboardShortcuts.editor.add' => '추가',
			'keyboardShortcuts.editor.refusedFixed' => ({required Object keys}) => '${keys}은(는) 로깅 필드나 대화 상자에서 쓰이므로 변경할 수 없습니다.',
			'keyboardShortcuts.editor.refusedCallsign' => ({required Object keys}) => '${keys}은(는) 콜사인을 입력하는 키입니다. Cmd, Ctrl 또는 Alt와 함께 누르세요.',
			'keyboardShortcuts.editor.reserved' => ({required Object keys}) => '시스템이 ${keys}을(를) 앱보다 먼저 가로챌 수 있습니다.',
			'keyboardShortcuts.editor.already' => ({required Object keys}) => '${keys}은(는) 이미 이 명령에 할당된 키입니다.',
			'keyboardShortcuts.editor.takeIt' => ({required Object command, required Object keys}) => '“${command}”에서 ${keys} 가져오기',
			'keyboardShortcuts.editor.resetDefault' => '기본값으로 초기화',
			'keyboardShortcuts.editor.remove' => '제거',
			'keyboardShortcuts.editor.commandLabel' => '명령',
			'keyboardShortcuts.editor.commandHint' => '유효한 명령을 입력하거나, 여러 명령을 ";"로 구분해 입력하세요',
			'keyboardShortcuts.editor.removeCommand' => '명령 제거',
			'keyboardShortcuts.editor.commandUnknown' => ({required Object text}) => '“${text}”을(를) 인식하는 명령이 없습니다',
			'keyboardShortcuts.editor.noShortcuts' => '아직 키 없음',
			'keyboardShortcuts.file.exported' => ({required Object location}) => '단축키를 ${location}에 저장했습니다',
			'keyboardShortcuts.file.exportFailed' => ({required Object error}) => '단축키를 내보낼 수 없습니다: ${error}',
			'keyboardShortcuts.file.importPickerFailed' => ({required Object error}) => '파일을 열 수 없습니다: ${error}',
			'keyboardShortcuts.file.importUnreadable' => ({required Object filename, required Object problem}) => '${filename}은(는) 이 앱이 읽을 수 있는 단축키 파일이 아닙니다: ${problem}',
			'keyboardShortcuts.file.problemNotYaml' => ({required Object line}) => '올바른 YAML이 아님 (${line}행)',
			'keyboardShortcuts.file.problemNotKeysFile' => 'Ham2K 키보드 단축키 파일이 아님',
			'keyboardShortcuts.file.problemNewerVersion' => '더 새로운 버전의 앱에서 작성됨',
			'keyboardShortcuts.file.problemMalformed' => '일부가 단축키 형식에 맞지 않음',
			'keyboardShortcuts.file.problemTooLarge' => '너무 큼',
			'keyboardShortcuts.file.importTitle' => '단축키 가져오기',
			'keyboardShortcuts.file.writtenOn' => ({required Object platform}) => '${platform}에서 작성됨.',
			'keyboardShortcuts.file.writtenOnUnknown' => '이 파일에는 어떤 키보드에서 작성되었는지 적혀 있지 않습니다.',
			'keyboardShortcuts.file.translate' => '이 키보드에서는 다음 키를 각각 어떤 키로 할까요?',
			'keyboardShortcuts.file.leaveOut' => '해당 단축키 제외',
			'keyboardShortcuts.file.replace' => '이 기기의 설정 대체',
			'keyboardShortcuts.file.replaceHint' => '파일에 없는 모든 단축키는 기본값으로 돌아갑니다.',
			'keyboardShortcuts.file.merge' => '이 기기의 설정에 추가',
			'keyboardShortcuts.file.mergeHint' => '같은 명령에 대해서는 파일의 단축키가 이 기기의 단축키를 대체하고, 나머지는 그대로 유지됩니다.',
			'keyboardShortcuts.file.unknown' => ({required Object commands}) => '이 버전에 없는 명령이어서 제외됨: ${commands}',
			'keyboardShortcuts.file.unreadableChords' => ({required Object chords}) => '단축키가 아니어서 제외됨: ${chords}',
			'keyboardShortcuts.file.refusedChords' => ({required Object chords}) => '앱이 직접 쓰는 키여서 제외됨: ${chords}',
			'keyboardShortcuts.file.conflicts' => ({required Object keys}) => '가져온 후 둘 이상의 명령에 할당됨: ${keys}',
			'keyboardShortcuts.file.importAction' => '가져오기',
			'keyboardShortcuts.file.imported' => '단축키를 가져왔습니다',
			'keyboardShortcuts.modifier.cmd' => '⌘ Command',
			'keyboardShortcuts.modifier.ctrl' => 'Ctrl',
			'keyboardShortcuts.modifier.meta' => 'Windows / Super',
			'keyboardShortcuts.platform.macos' => 'macOS',
			'keyboardShortcuts.platform.ios' => 'iPadOS',
			'keyboardShortcuts.platform.windows' => 'Windows',
			'keyboardShortcuts.platform.linux' => 'Linux',
			'keyboardShortcuts.platform.android' => 'Android',
			'expiredBuild.title' => '이 빌드는 만료되었습니다',
			'expiredBuild.body' => 'ham2k.com을 방문하여 최신 버전을 받으세요.',
			'expiredBuild.visit' => 'ham2k.com 방문',
			'expiredBuild.dismiss' => '어쨌든 계속',
			'staleness.codePushFloorTitle' => '중요한 업데이트가 기다리고 있습니다',
			'staleness.codePushFloorBody' => '이 버전에는 아직 적용되지 않은 수정 사항이 있습니다.',
			'staleness.restartToApply' => '적용하려면 앱을 다시 시작하세요.',
			'staleness.quitAndReopen' => '적용하려면 앱을 종료하고 다시 여세요.',
			'staleness.reopenToApply' => '적용하려면 앱을 닫고 다시 여세요.',
			'staleness.ignoreForNow' => '지금은 무시',
			'spotting.noQsoYet' => '스팟할 QSO가 아직 로깅되지 않았습니다.',
			'spotting.setFrequencyFirst' => '먼저 주파수를 지정하세요.',
			'spotting.nothingToSpot' => '스팟할 대상이 없습니다. 여기서 스팟을 제공하는 확장 기능이 없습니다.',
			'spotting.incompleteCall' => '불완전한 콜사인은 스팟할 수 없습니다. 먼저 콜사인을 완성하세요.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} 실패: ${message}',
			'spotting.unknownError' => '알 수 없는 오류',
			'spotting.notSent' => '스팟을 보내지 않았습니다.',
			'spotting.allSkipped' => '스팟을 보내지 않았습니다: 모든 스팟 출처가 건너뛰었습니다.',
			'spotting.notRefreshedOffline' => '연결 없음 — 스팟을 새로고침하지 않았습니다',
			'dataFiles.downloading' => '다운로드 중…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => '${name}을(를) 다운로드할 수 없습니다',
			'dataFiles.downloadFailedWebHint' => '네트워크 문제이거나, 이 링크의 호스트가 웹 브라우저에서의 직접 다운로드를 지원하지 않을 수 있습니다. 데스크톱 또는 모바일 앱을 사용하거나 다른 호스팅 위치를 사용해 보세요.',
			'dataFiles.downloadTimedOut' => '서버 응답 시간이 너무 오래 걸렸습니다. 나중에 다시 시도하세요.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host}이(가) 오류로 응답했습니다 (HTTP ${status}). 나중에 다시 시도하세요.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host}이(가) 이 파일을 제공할 수 없습니다 (HTTP ${status}). 주소가 여전히 올바른지 확인하세요.',
			'dataFiles.n1mmHistoryNoMatch' => ({required Object stem}) => 'N1MM에 ${stem}의 콜사인 히스토리 파일이 없습니다.',
			'dataFiles.n1mmHistoryUnavailable' => ({required Object stem}) => 'N1MM에서 ${stem}의 콜사인 히스토리를 다운로드할 수 없습니다. 나중에 다시 시도하세요.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => '${name}을(를) 처리할 수 없습니다',
			'dataFiles.importTooSmall' => ({required Object existing, required Object imported}) => '다운로드에 이 기기에 있는 기록 ${existing}개 중 ${imported}개만 있어서, 빠진 기록은 유지했습니다. 설정 › 오프라인 데이터에서 새로고침하면 그래도 받아들입니다.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${label}의 기록 ${count}개를 가져왔습니다.', other: '${label}의 기록 ${count}개를 가져왔습니다.', ), 
			'dataFiles.importedData' => ({required Object label}) => '${label}의 데이터를 가져왔습니다.',
			'dataFiles.cleanedUpTitle' => '확장 기능 데이터 정리됨',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '비활성화된 확장 기능의 데이터 파일 ${count}개에 대한 데이터를 제거했습니다.', other: '비활성화된 확장 기능의 데이터 파일 ${count}개에 대한 데이터를 제거했습니다.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '기록 ${end} / ${total}',
			'dataFiles.definitionUnavailable' => '파일 출처가 정의를 제공하지 않았습니다. 해당 확장 기능이 재시작 중이거나 잘못 구성되었을 수 있습니다. 잠시 후 다시 시도하세요.',
			'updates.updateAvailable' => '업데이트 가능',
			'updates.newVersionAvailable' => ({required Object version}) => '새 버전(${version})을 사용할 수 있습니다.',
			'updates.getIt' => '받기',
			'updates.ok' => '확인',
			'updates.updateReady' => '업데이트 준비됨',
			'updates.restartToApply' => '업데이트를 다운로드했습니다. 적용하려면 다시 시작하세요.',
			'updates.appliesNextLaunch' => '업데이트를 다운로드했습니다. 다음에 앱을 열 때 적용됩니다.',
			'updates.restartNow' => '지금 다시 시작',
			'updates.reloadToUpdate' => '이 페이지의 새 버전을 사용할 수 있습니다. 새로고침하여 받으세요.',
			'updates.reloadNow' => '지금 새로고침',
			'updates.checkForUpdates' => '업데이트 확인',
			'updates.checkingForUpdates' => '업데이트 확인 중…',
			'updates.upToDate' => '최신 상태',
			'updates.automaticChecks' => '자동으로 확인',
			'updates.automaticChecksDescription' => '다음에 앱을 시작할 때부터 백그라운드에서 새 버전 확인',
			'extensionService.runtimeNotReady' => '확장 기능 런타임이 준비되지 않았습니다.',
			'extensionService.testFailed' => ({required Object error}) => '테스트 실패: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => '${identity}(으)로 연결됨',
			'extensionService.invalidFieldConfiguration' => '잘못된 필드 구성',
			'extensionService.invalidValue' => '잘못된 값',
			'extensionService.validationError' => ({required Object error}) => '유효성 검사 오류: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => '작업 실패: ${error}',
			'extensionService.commandFailed' => '명령을 실행하지 못했습니다',
			'extensionService.commandMayNotChangeSettings' => ({required Object name}) => '${name}은(는) 설정을 변경할 수 없습니다: 설치 시 해당 권한을 요청하지 않았습니다',
			'extensionService.commandMayNotControlRadio' => ({required Object name}) => '${name}은(는) 무전기를 제어할 수 없습니다: 설치 시 해당 권한을 요청하지 않았습니다',
			'extensionService.commandDeveloperOnly' => ({required Object name}) => '${name}은(는) 그 명령을 실행할 수 없습니다: 앱 자체의 개발자 명령입니다',
			'extensionService.commandDescribeBy' => ({required Object describe, required Object extension}) => '${describe} · ${extension}',
			'extensionService.reportUnavailable' => '지금은 보고서를 보낼 수 없습니다',
			'extensionService.stashUnavailable' => '지금은 Ham2K File Stash에 연결할 수 없습니다',
			'extensionService.activitySearchSourcesFailed' => ({required Object names}) => '${names}이(가) 활동 검색에 응답하지 않아 일부 결과가 빠졌을 수 있습니다.',
			'extensionService.activitySearchSomeSourcesFailed' => '일부 활동 확장 기능이 검색에 응답하지 않아 일부 결과가 빠졌을 수 있습니다.',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name}이(가) 타이머에서 너무 많은 시간을 사용했습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => '${name}의 타이머가 계속 실패했습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name}이(가) 타이머에서 멈췄습니다. 확장 기능이 다시 시작될 때까지 타이머가 중지됩니다.',
			'operationLocationScreen.title' => '운용 위치',
			'operationLocationScreen.selectedLocation' => '선택된 위치',
			'operationLocationScreen.gridSquare' => '그리드 로케이터',
			'operationLocationScreen.gridInvalid' => 'FN31pr처럼 4, 6, 8 또는 10자여야 합니다',
			'operationLocationScreen.suggestedLocations' => '추천 위치',
			'operationLocationScreen.deviceGps' => '기기 GPS',
			'operationLocationScreen.peerGps' => ({required Object device}) => '${device}의 GPS',
			'operationLocationScreen.locating' => '위치 찾는 중…',
			'operationLocationScreen.gpsUnavailable' => '위치를 사용할 수 없음',
			'operationLocationScreen.permissionDenied' => '위치 권한 거부됨',
			'operationLocationScreen.permissionBlocked' => '위치 권한 차단됨',
			'operationLocationScreen.moreDetails' => '상세 정보',
			'operationLocationScreen.stateOrProvince' => '주/도 (선택 사항)',
			'operationLocationScreen.controlsUnavailableTitle' => '활동 컨트롤을 사용할 수 없음',
			'operationLocationScreen.controlsUnavailableReason' => '이 레퍼런스는 여전히 사용할 수 있으며, 해당 활동에 연결할 수 없을 뿐입니다.',
			'operationLocationScreen.controlsUnavailableRetry' => '다시 시도',
			'operationLocationScreen.county' => '시/군 (선택 사항)',
			'versionLabel.version' => ({required Object version}) => '버전 ${version}',
			'versionLabel.patch' => ({required Object patch}) => '패치 ${patch}',
			'versionLabel.build' => ({required Object build}) => '빌드 ${build}',
			'notices.emptyHistory' => '아직 공지 없음',
			'notices.webStorageInMemory' => '이 브라우저가 영구 저장소를 제공하지 못했습니다. 로그는 메모리에만 있으며 이 탭을 닫으면 사라집니다. 최신 Chrome, Firefox, Safari 또는 Edge를 사용하세요.',
			'notices.webStorageUnreliable' => '이 브라우저는 여러 탭에서 안전하지 않은 대체 저장소를 사용 중입니다. 탭을 하나만 열어 두고 동기화를 켜 두세요.',
			'notices.logFromNewerBuildTitle' => '이 로그에는 최신 버전이 필요합니다',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => '로그가 더 최신 버전의 HaLo로 작성되어(저장소 버전 ${storage}, 이 버전은 ${understood}까지 지원) 열 수 없으며, 새 교신도 저장되지 않습니다. 최신 버전을 다시 설치하거나, 이 빌드를 실행하려던 것이라면 다른 데이터 폴더를 지정하세요. 로그 위치: ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => '로그가 더 최신 버전의 HaLo로 작성되어(저장소 버전 ${storage}, 이 버전은 ${understood}까지 지원) 열 수 없으며, 새 교신도 저장되지 않습니다. 대신 해당 최신 버전으로 이 로그를 여세요.',
			'notices.preferencesRestoredTitle' => '백업에서 설정을 복원했습니다',
			'notices.preferencesRestored' => '설정 파일을 읽을 수 없어 HaLo가 마지막으로 정상이었던 사본을 복원했습니다. 이전 세션에서 변경한 내용은 다시 설정해야 할 수 있습니다. 읽을 수 없는 파일은 shared_preferences.corrupt-….json이라는 이름으로 같은 위치에 보관됩니다.',
			'notices.preferencesResetTitle' => '설정 초기화됨',
			'notices.preferencesReset' => '설정 파일을 읽을 수 없고 복원할 백업도 없어 HaLo가 기본값으로 시작했습니다. 읽을 수 없는 파일은 앱의 데이터 폴더에 shared_preferences.corrupt-….json이라는 이름으로 보관됩니다.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name}에 자동으로 연결하지 않았습니다',
			'notices.autoConnectHeld' => ({required Object name}) => '지난번 ${name}에 연결을 시작했을 때 HaLo가 응답을 멈췄기 때문에, 같은 일이 반복될 위험을 피하려고 이번에는 연결하지 않았습니다. 무전기 전원이 켜져 있고 케이블이 연결되어 있는지 확인한 후, 설정에서 해당 무전기의 연결을 누르세요.',
			'syncAccount.anonymous' => ({required Object id}) => '익명 계정 (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (확인 대기 중)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (확인 대기 중 - #${id})',
			'deepLink.needsAnOperation' => '먼저 운용을 시작한 후 해당 교신을 다시 보내세요',
			'deepLink.waitingInOperation' => '해당 교신은 이 화면 뒤의 운용에서 대기 중입니다',
			'deepLink.unknownActivities' => ({required Object refs}) => '이 기기에 ${refs}에 대한 활동이 없어 해당 레퍼런스를 제외했습니다',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => '활동에 연결할 수 없어 ${refs}을(를) 제외했습니다. 링크를 다시 시도하세요',
			'confirmDevice.title' => '기기 확인',
			'confirmDevice.codePrompt' => '이 계정에 연결하려는 기기에 표시된 코드를 입력하세요.',
			'confirmDevice.code' => '코드',
			'confirmDevice.lookUp' => '조회',
			'confirmDevice.codeNotFound' => '해당 코드와 일치하는 요청이 없습니다. 코드는 10분 후 만료되니, 다른 기기에서 새 코드를 받으세요.',
			'confirmDevice.linkExpired' => '링크가 만료되었습니다. 다른 기기에서 새 QR 코드를 표시하세요.',
			'confirmDevice.areYouSure' => ({required Object device}) => '${device}을(를) 이 계정에 연결할까요?',
			'confirmDevice.unnamedDevice' => '이름 없는 기기',
			'confirmDevice.grantWarning' => '이 계정의 모든 운용과 QSO를 읽고 변경할 수 있게 됩니다.',
			'confirmDevice.needsSyncTitle' => '이 기기는 아직 동기화하지 않습니다',
			'confirmDevice.needsSyncText' => '다른 기기를 승인하려면 먼저 Ham2K 로그 파일러 동기화를 켜고 이 기기를 계정에 연결하세요.',
			'confirmDevice.malformedRequest' => '동기화 서버가 이 앱이 읽을 수 없는 요청을 보냈습니다. 다른 기기에서 다시 시도하세요.',
			'confirmDevice.linkIt' => '기기 연결',
			'switchAccounts.noAccountDetails' => '아직 계정 정보 없음',
			'switchAccounts.currentAccount' => '현재 계정',
			'switchAccounts.otherAccounts' => '다른 계정',
			'switchAccounts.linkToAnother' => '다른 계정에 연결',
			'switchAccounts.linkWithSibling' => '다른 Ham2K 앱과 연결',
			'switchAccounts.linkWithPolo' => '이전 버전의 계정과 연결',
			'switchAccounts.linkWithSiblingDescription' => '다른 Ham2K 앱이 설치되어 있습니다. 그 앱에서 사용 중인 계정과 연결하세요.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => '${app}에서 요청을 승인한 후 여기로 돌아오세요.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => '${app} 다시 열기',
			'switchAccounts.siblingNoGrant' => '작동하지 않았나요? 다시 열거나, 돌아가서 다른 방법으로 연결하세요.',
			_ => null,
		} ?? switch (path) {
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => '${app}을(를) 열 수 없습니다.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => '링크가 만료되어 새 링크가 준비되었습니다. ${app}을(를) 다시 여세요.',
			'switchAccounts.tryAgain' => '다시 시도',
			'switchAccounts.linkWithQr' => 'QR 코드로 연결',
			'switchAccounts.linkWithQrDescription' => '이미 계정을 사용 중인 기기로 스캔하세요',
			'switchAccounts.linkWithEmail' => '이메일 주소로 연결',
			'switchAccounts.linkWithEmailDescription' => '코드 또는 이메일 링크로 확인',
			'switchAccounts.enterEmailPrompt' => '이 기기에서 사용할 계정의 이메일 주소를 입력하세요.',
			'switchAccounts.emailAddress' => '이메일 주소',
			'switchAccounts.linkAccount' => '계정 연결',
			'switchAccounts.copiedCode' => '코드를 클립보드에 복사했습니다',
			'switchAccounts.copyCode' => '코드 복사',
			'switchAccounts.codePrompt' => ({required Object email}) => '${email}과(와) 이미 연결된 기기에서 Ham2K 앱을 열고 이 코드를 입력하여 요청을 승인하세요:',
			'switchAccounts.waitingForConfirmation' => '확인 대기 중…',
			'switchAccounts.sendEmailInstead' => '대신 확인 이메일 보내기',
			'switchAccounts.emailSent' => ({required Object email}) => '${email}(으)로 이메일을 보냈습니다. 이메일을 열고 요청을 확인하면 이 기기가 연결됩니다.',
			'switchAccounts.resendEmail' => '이메일 다시 보내기',
			'switchAccounts.qrPrompt' => '원하는 계정에 이미 연결된 기기로 이 QR 코드를 스캔하세요. 예를 들어 휴대폰의 Ham2K Portable Logger로 스캔할 수 있습니다.',
			'switchAccounts.serverUnreachable' => '동기화 서버에 연결할 수 없습니다. 나중에 다시 시도하세요.',
			'switchAccounts.emailRequired' => '연결할 이메일 주소를 입력하세요.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => '${email}에 해당하는 계정이 없습니다.',
			'switchAccounts.serverRejected' => ({required Object error}) => '동기화 서버가 요청을 거부했습니다: ${error}',
			'switchAccounts.noLinkCode' => '동기화 서버가 연결 코드를 반환하지 않았습니다. 나중에 다시 시도하세요.',
			'switchAccounts.noConfirmationCode' => '동기화 서버가 확인 코드를 보내지 않았습니다. 나중에 다시 시도하세요.',
			'switchAccounts.switchNotAccepted' => '해당 계정이 전환을 받아들이지 않았습니다. 대신 이메일 주소로 연결해 보세요.',
			'switchAccounts.requestFailed' => '동기화 서버와 통신 중 문제가 발생했습니다. 나중에 다시 시도하세요.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count} QSO', other: '${count} QSO', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '운용 ${count}개', other: '운용 ${count}개', ), 
			'qsonImport.title' => 'QSON 운용 가져오기',
			'qsonImport.description' => '이 앱이나 PoLo의 개발자 모드에서 내보낸 QSON 파일로 새 운용을 만듭니다.',
			'qsonImport.dropHint' => 'QSON 파일을 끌어다 놓아 새 운용으로 가져오세요',
			'qsonImport.importing' => ({required Object filename}) => '${filename} 가져오는 중…',
			'qsonImport.failed' => ({required Object filename, required Object error}) => '${filename}을(를) 가져올 수 없습니다: ${error}',
			'qsonImport.pickerFailed' => ({required Object error}) => '가져올 파일을 열 수 없습니다: ${error}',
			'qsonImport.notUtf8' => ({required Object filename}) => '${filename}은(는) UTF-8 텍스트가 아니므로 QSON 파일이 아닙니다',
			'qsonImport.notJson' => ({required Object filename}) => '${filename}은(는) JSON 파일이 아니므로 QSON 파일이 아닙니다',
			'qsonImport.notOperation' => ({required Object filename}) => '${filename}에는 QSON 운용이 들어 있지 않습니다',
			'qsonImport.busy' => '이미 가져오기가 진행 중입니다. 완료될 때까지 기다린 후 시작하세요.',
			'qsonImport.oneFileOnly' => 'QSON 파일은 한 번에 하나씩 끌어다 놓으세요. 파일마다 별도의 운용으로 열립니다.',
			'adifImport.title' => 'ADIF에서 QSO 가져오기',
			'adifImport.reading' => ({required Object filename}) => '${filename} 읽는 중…',
			'adifImport.dropHint' => '가져올 ADIF 파일을 끌어다 놓으세요',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '이 파일의 QSO ${count}개', other: '이 파일의 QSO ${formatted}개', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개는 이미 로그에 있음', other: '${formatted}개는 이미 로그에 있음', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개를 가져옵니다', other: '${formatted}개를 가져옵니다', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '새 교신 ${count}개', other: '새 교신 ${formatted}개', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개는 기존 교신과 병합됩니다', other: '${formatted}개는 기존 교신과 병합됩니다', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개는 가져올 수 없습니다 (콜사인 없음)', other: '${formatted}개는 가져올 수 없습니다 (콜사인 없음)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개는 자세히 확인해야 합니다', other: '${formatted}개는 자세히 확인해야 합니다', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '교신 ${count}개의 레퍼런스를 복구할 수 없습니다', other: '교신 ${formatted}개의 레퍼런스를 복구할 수 없습니다', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '교신 ${count}개의 ${programs} 레퍼런스가 불완전할 수 있습니다', other: '교신 ${formatted}개의 ${programs} 레퍼런스가 불완전할 수 있습니다', ), 
			'adifImport.stackingTypesUnknown' => '합쳐진 교신에서 레퍼런스가 빠질 수 있습니다. 활동이 어떤 유형을 함께 쓸 수 있는지 알려주지 못했습니다. 이를 피하려면 취소하고 다시 시도하세요.',
			'adifImport.nothingToImport' => '이 파일에서 가져올 수 있는 것이 없습니다',
			'adifImport.confirm' => '가져오기',
			'adifImport.importing' => ({required Object filename}) => '${filename} 가져오는 중…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${filename}에서 교신 ${count}개를 가져왔습니다', other: '${filename}에서 교신 ${formatted}개를 가져왔습니다', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => '${filename}을(를) 가져올 수 없습니다: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename}은(는) ADIF 파일이 아닌 것 같습니다',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => '경고: 이 ADIF에는 ${calls}의 QSO가 있지만, 계속하면 ${station}(으)로 가져옵니다.',
			'adifImport.stationCallJoin' => ' 및 ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(count, one: '${count}개는 날짜가 없어 가져올 수 없습니다', other: '${formatted}개는 날짜가 없어 가져올 수 없습니다', ), 
			'adifImport.activationFound' => ({required Object refs}) => '이 파일에는 ${refs}의 활성화 기록이 있습니다.',
			'adifImport.addActivation' => '이 운용에 추가',
			'adifImport.shortfall' => ({required Object planned, required Object written}) => '${planned}개 중 ${written}개만 적용할 수 있었습니다. 결정하는 동안 로그가 변경되었습니다.',
			'adifImport.busy' => '이미 가져오기가 진행 중입니다. 완료될 때까지 기다린 후 시작하세요.',
			'adifImport.oneFileOnly' => 'ADIF 파일은 한 번에 하나씩 끌어다 놓으세요. 파일을 가져오는 순서에 따라 어떤 데이터가 우선할지 결정됩니다.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename}에 QSO가 ${limit}개를 넘게 있습니다. 운용 하나에 한 번에 가져올 수 있는 최대치입니다.',
			'adifImport.tooManyDeveloper' => ({required Object filename, required Object limit}) => '${filename}에 QSO가 ${limit}개를 넘게 있습니다. 운용에 ADIF를 가져오는 기능은 QSO 몇 개를 추가하기 위한 것이지 큰 로그를 들여오기 위한 것이 아닙니다. 큰 로그는 로그 화면에서 가져오세요. 확실하다면 개발자 모드에서는 그래도 가져올 수 있습니다.',
			'adifImport.importAnyway' => '어쨌든 가져오기',
			'offline.statusOffline' => '인터넷: 오프라인',
			'offline.statusOnline' => '인터넷: 연결됨',
			'offline.noRoute' => '네트워크 연결이 전혀 없습니다.',
			'offline.unreachable' => '네트워크는 연결되어 있지만 응답하는 서버가 없습니다. 브라우저에 로그인 페이지가 대기 중인 경우가 많습니다.',
			'offline.reachable' => '모든 서비스가 정상적으로 응답하고 있습니다.',
			'offline.whatStops' => '조회, 스팟 및 데이터 파일이 일시 중지되었습니다. 로깅과 근처 기기 동기화는 계속됩니다.',
			'offline.servicesTitle' => '서비스',
			'offline.noServices' => '아직 응답을 보고한 서비스가 없습니다.',
			'offline.lastSuccess' => ({required Object when}) => '${when} 전에 마지막으로 응답함',
			'offline.neverSucceeded' => '아직 응답하지 않음',
			'offline.nextAttempt' => ({required Object when}) => '${when} 후 다시 시도',
			'offline.nextAttemptNow' => '곧 다시 시도',
			'offline.retry' => '지금 다시 시도',
			'offline.retrying' => '시도 중…',
			'offline.retryReached' => '다시 온라인 상태입니다.',
			'offline.retryUnreachable' => '여전히 응답이 없습니다.',
			'offline.retryNotAttempted' => '지금은 보낼 것이 없습니다.',
			'offline.retryThrottled' => '방금 시도했습니다. 잠시 기다리세요.',
			'offline.retryDisabled' => '동기화가 꺼져 있어 확인할 대상이 없습니다.',
			'offline.syncService' => 'Ham2K LoFi 동기화',
			'offline.retryInFlight' => '이미 시도 중입니다. 잠시 기다리세요.',
			'exportSettings.defaultsDescription' => '모든 내보내기의 기본 설정이며, 레퍼런스 활동과 기타 활동에 대해 별도의 파일 이름 및 제목 템플릿이 있습니다. 내보내기 유형마다 자체 기본값이나 사용자 정의 설정을 제공할 수 있습니다.',
			'exportSettings.referenceActivities' => '레퍼런스 활동',
			'exportSettings.otherActivities' => '기타 활동',
			'exportSettings.adifFields' => 'ADIF 필드',
			'exportSettings.loadFailed' => '내보내기 설정을 불러올 수 없습니다.',
			'exportSettings.retry' => '다시 시도',
			'exportSettings.compactFileNamesDescriptionOn' => '짧은 파일명, 예: N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => '설명적인 파일명, 예: 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'ADIF 파일에 이름, 주소, 이메일, 메모 및 정확한 위치를 포함합니다.',
			'exportSettings.includePrivateDataDescriptionOff' => '이름, 주소, 이메일 및 메모를 제외하고, 위치를 6자리 그리드로 제한합니다.',
			'exportSettings.includeLookupDataDescriptionOn' => '콜사인 조회 서비스의 정보를 포함합니다.',
			'exportSettings.includeLookupDataDescriptionOff' => '콜사인 조회 서비스의 정보를 제외하고, 직접 입력한 값은 유지합니다.',
			'exportSettings.customTemplatesDescriptionOn' => '맞춤 템플릿이 활성화되어 있으며 아래에서 편집할 수 있습니다.',
			'exportSettings.customTemplatesDescriptionOff' => '기본 템플릿이 활성화되어 있습니다. 맞춤 템플릿은 나중을 위해 보관됩니다.',
			'exportSettings.type' => '내보내기 유형',
			'exportSettings.defaults' => '기본값',
			'exportSettings.includeLookupData' => '조회 데이터 포함',
			'exportSettings.customTemplates' => '맞춤 템플릿',
			'exportSettings.filenameTemplate' => '파일 이름 템플릿',
			'exportSettings.compactFilenameTemplate' => '짧은 파일 이름 템플릿',
			'exportSettings.titleTemplate' => '제목 템플릿',
			'exportSettings.adifNotesTemplate' => 'ADIF QSO 노트',
			'exportSettings.adifCommentTemplate' => 'ADIF QSO 코멘트',
			'exportSettings.adifQslMessageTemplate' => 'ADIF QSL 메시지',
			'exportSettings.shared' => '이 설정은 이 내보내기 유형을 사용하는 모든 확장 기능에 적용됩니다.',
			'exportSettings.defaultTemplates' => '이 유형의 템플릿을 편집하려면 맞춤 템플릿을 켜세요.',
			'templateEditor.previewLabel' => '미리보기:',
			'templateEditor.reset' => '초기화',
			'templateEditor.docs' => '템플릿 문서',
			'templateEditor.preview' => '샘플 미리보기',
			'templateEditor.reference' => '템플릿 참조',
			'templateEditor.attributes' => '사용 가능한 속성',
			'templateEditor.filters' => '필터',
			'templateEditor.flowControl' => '흐름 제어',
			'templateEditor.unavailable' => '확장 기능이 준비될 때까지 미리보기를 사용할 수 없습니다.',
			'templateEditor.empty' => '(출력 없음)',
			_ => null,
		};
	}
}
