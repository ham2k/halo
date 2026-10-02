// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Every hook the host calls, spelled once on this side of the bridge. The
// runtime answers a call to a category or method nothing registers with an
// absence, not an error — so a misspelling here would be a feature that
// quietly never runs. Lib code names a hook through this catalog, and a guard
// (app/test/guards/hook_names_test.dart) fails a hook name spelled anywhere
// else.
//
// The extension side's half is extensions/sdk/src/hookCategories.ts; a
// category belongs in both.

/// The hook categories the host names — the ones it calls, and the ones it reads
/// off a manifest. Spelled as the extension side spells them (hookCategories.ts).
abstract final class HookCategories {
  static const account = 'account';
  static const activity = 'activity';
  static const adifFields = 'adifFields';
  static const adifImport = 'adifImport';
  static const callNotes = 'callNotes';
  static const command = 'command';
  static const dataFile = 'dataFile';
  static const export = 'export';
  static const form = 'form';
  static const lookup = 'lookup';
  static const lookupService = 'lookupService';
  static const panel = 'panel';
  static const runtime = 'runtime';
  static const scoring = 'scoring';
  static const settingsPanel = 'settingsPanel';
  static const spots = 'spots';
  static const syncTransport = 'syncTransport';
  static const template = 'template';
}

/// One hook, as the host calls it: a category and one of its methods.
final class HookRef {
  const HookRef(this.category, this.method);

  final String category;
  final String method;

  /// This hook's call in an `invokeHookBatch`.
  ({String category, String? key, String method, Object? args}) withArgs(Object? args, {String? key}) =>
      (category: category, key: key, method: method, args: args);

  @override
  bool operator ==(Object other) => other is HookRef && other.category == category && other.method == method;

  @override
  int get hashCode => Object.hash(category, method);

  @override
  String toString() => '$category.$method';
}

/// The methods every `ref:<type>` handler may implement.
enum RefMethod { validateRef, decorateRef, linkForRef, geojsonUrlForRef, suggestOperationTitle }

/// The catalog.
abstract final class Hooks {
  static const accountGetDefinition = HookRef(HookCategories.account, 'getDefinition');
  static const accountTestCredentials = HookRef(HookCategories.account, 'testCredentials');

  static const activitySuggest = HookRef(HookCategories.activity, 'suggest');
  static const activityLoggingControls = HookRef(HookCategories.activity, 'loggingControls');
  static const activityOperationControls = HookRef(HookCategories.activity, 'operationControls');
  static const activityProcessQsoBeforeSave = HookRef(HookCategories.activity, 'processQsoBeforeSave');

  static const adifFieldsFieldsForOneQso = HookRef(HookCategories.adifFields, 'fieldsForOneQSO');
  static const adifFieldsFieldCombinationsForOneQso = HookRef(HookCategories.adifFields, 'fieldCombinationsForOneQSO');

  static const adifImportRefsForRecords = HookRef(HookCategories.adifImport, 'refsForRecords');

  static const commandCatalog = HookRef(HookCategories.command, 'catalog');
  static const commandInterpret = HookRef(HookCategories.command, 'interpret');

  static const dataFileGetDefinition = HookRef(HookCategories.dataFile, 'getDefinition');
  static const dataFileRawToJsonData = HookRef(HookCategories.dataFile, 'rawToJSONData');
  static const dataFileOnLoadRawData = HookRef(HookCategories.dataFile, 'onLoadRawData');
  static const dataFileOnRemoveRawData = HookRef(HookCategories.dataFile, 'onRemoveRawData');
  static const dataFileMapCsvBatch = HookRef(HookCategories.dataFile, 'mapCsvBatch');
  static const dataFileMapJsonBatch = HookRef(HookCategories.dataFile, 'mapJsonBatch');

  static const exportSuggestExportOptions = HookRef(HookCategories.export, 'suggestExportOptions');
  static const exportGetExportTypes = HookRef(HookCategories.export, 'getExportTypes');
  static const exportGenerateExport = HookRef(HookCategories.export, 'generateExport');

  static const formValidateField = HookRef(HookCategories.form, 'validateField');
  static const formTransformField = HookRef(HookCategories.form, 'transformField');
  static const formOnChangeField = HookRef(HookCategories.form, 'onChangeField');

  static const lookupServiceLookupCallInfo = HookRef(HookCategories.lookupService, 'lookupCallInfo');

  static const panelGetPanels = HookRef(HookCategories.panel, 'getPanels');
  static const panelRender = HookRef(HookCategories.panel, 'render');
  static const panelOnEvent = HookRef(HookCategories.panel, 'onEvent');

  static const runtimeListExtensions = HookRef(HookCategories.runtime, 'listExtensions');
  static const runtimeListHooks = HookRef(HookCategories.runtime, 'listHooks');

  static const scoringScope = HookRef(HookCategories.scoring, 'scope');
  static const scoringScoreQsos = HookRef(HookCategories.scoring, 'scoreQsos');
  static const scoringScoreQso = HookRef(HookCategories.scoring, 'scoreQso');
  static const scoringScoreCandidates = HookRef(HookCategories.scoring, 'scoreCandidates');

  static const settingsPanelGetPanels = HookRef(HookCategories.settingsPanel, 'getPanels');
  static const settingsPanelGetDefinition = HookRef(HookCategories.settingsPanel, 'getDefinition');
  static const settingsPanelValidateField = HookRef(HookCategories.settingsPanel, 'validateField');
  static const settingsPanelTransformField = HookRef(HookCategories.settingsPanel, 'transformField');
  static const settingsPanelOnChangeField = HookRef(HookCategories.settingsPanel, 'onChangeField');

  /// A settings panel's action button: its method is whatever the extension
  /// named on the panel (docs/extensions/settings.md), so it is not a constant.
  static HookRef settingsPanelAction(String method) => HookRef(HookCategories.settingsPanel, method);

  static const spotsFetchSpots = HookRef(HookCategories.spots, 'fetchSpots');
  static const spotsSourceName = HookRef(HookCategories.spots, 'sourceName');
  static const spotsIsSelfSpotEnabled = HookRef(HookCategories.spots, 'isSelfSpotEnabled');
  static const spotsIsOtherSpotEnabled = HookRef(HookCategories.spots, 'isOtherSpotEnabled');
  static const spotsPostSelfSpot = HookRef(HookCategories.spots, 'postSelfSpot');
  static const spotsPostOtherSpot = HookRef(HookCategories.spots, 'postOtherSpot');

  static const syncTransportSync = HookRef(HookCategories.syncTransport, 'sync');
  static const syncTransportGetAccountData = HookRef(HookCategories.syncTransport, 'getAccountData');
  static const syncTransportLinkClient = HookRef(HookCategories.syncTransport, 'linkClient');
  static const syncTransportLinkClientWithEmail = HookRef(HookCategories.syncTransport, 'linkClientWithEmail');
  static const syncTransportSetAccountEmail = HookRef(HookCategories.syncTransport, 'setAccountEmail');
  static const syncTransportResendAccountEmail = HookRef(HookCategories.syncTransport, 'resendAccountEmail');
  static const syncTransportFindLinkRequest = HookRef(HookCategories.syncTransport, 'findLinkRequest');
  static const syncTransportFindLinkRequestByClient = HookRef(HookCategories.syncTransport, 'findLinkRequestByClient');
  static const syncTransportApproveLinkRequest = HookRef(HookCategories.syncTransport, 'approveLinkRequest');
  static const syncTransportEnsureClientRegistered = HookRef(HookCategories.syncTransport, 'ensureClientRegistered');
  static const syncTransportFetchWebhookEvents = HookRef(HookCategories.syncTransport, 'fetchWebhookEvents');
  static const syncTransportSubmitReport = HookRef(HookCategories.syncTransport, 'submitReport');
  static const syncTransportUploadStashFile = HookRef(HookCategories.syncTransport, 'uploadStashFile');
  static const syncTransportListStashFiles = HookRef(HookCategories.syncTransport, 'listStashFiles');
  static const syncTransportEmailStashLink = HookRef(HookCategories.syncTransport, 'emailStashLink');

  static const templateRender = HookRef(HookCategories.template, 'render');
  static const templateRenderMany = HookRef(HookCategories.template, 'renderMany');
  static const templateExportSettings = HookRef(HookCategories.template, 'exportSettings');
  static const templatePrepareExports = HookRef(HookCategories.template, 'prepareExports');

  static const _refPrefix = 'ref:';

  /// [method] on the handler for references of [type] — `ref:<type>`.
  static HookRef ref(String type, RefMethod method) => HookRef('$_refPrefix$type', method.name);

  /// The reference type a `ref:<type>` category (or a manifest's
  /// `ref:<type>/<code>` claim) names — the `<type>` and whatever follows it —
  /// or null for any other category.
  static String? refTypeOf(String category) => category.startsWith(_refPrefix) ? category.substring(_refPrefix.length) : null;
}
