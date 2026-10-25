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
import 'strings_pt.g.dart';

// Path: <root>
class TranslationsPtBr extends TranslationsPt with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsPtBr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ptBr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt-BR>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsPtBr _root = this; // ignore: unused_field

	@override 
	TranslationsPtBr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsPtBr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$pt_BR common = _Translations$common$pt_BR._(_root);
	@override late final _Translations$onboarding$pt_BR onboarding = _Translations$onboarding$pt_BR._(_root);
	@override late final _Translations$startScreen$pt_BR startScreen = _Translations$startScreen$pt_BR._(_root);
	@override late final _Translations$testerOverlay$pt_BR testerOverlay = _Translations$testerOverlay$pt_BR._(_root);
	@override late final _Translations$extensionsPanel$pt_BR extensionsPanel = _Translations$extensionsPanel$pt_BR._(_root);
	@override late final _Translations$home$pt_BR home = _Translations$home$pt_BR._(_root);
	@override late final _Translations$chase$pt_BR chase = _Translations$chase$pt_BR._(_root);
	@override late final _Translations$dialogs$pt_BR dialogs = _Translations$dialogs$pt_BR._(_root);
	@override late final _Translations$operation$pt_BR operation = _Translations$operation$pt_BR._(_root);
	@override late final _Translations$map$pt_BR map = _Translations$map$pt_BR._(_root);
	@override late final _Translations$mapsView$pt_BR mapsView = _Translations$mapsView$pt_BR._(_root);
	@override late final _Translations$activitiesView$pt_BR activitiesView = _Translations$activitiesView$pt_BR._(_root);
	@override late final _Translations$loggingControls$pt_BR loggingControls = _Translations$loggingControls$pt_BR._(_root);
	@override late final _Translations$formChrome$pt_BR formChrome = _Translations$formChrome$pt_BR._(_root);
	@override late final _Translations$qsoEditForm$pt_BR qsoEditForm = _Translations$qsoEditForm$pt_BR._(_root);
	@override late final _Translations$qsoList$pt_BR qsoList = _Translations$qsoList$pt_BR._(_root);
	@override late final _Translations$loggingPanel$pt_BR loggingPanel = _Translations$loggingPanel$pt_BR._(_root);
	@override late final _Translations$callInfo$pt_BR callInfo = _Translations$callInfo$pt_BR._(_root);
	@override late final _Translations$settings$pt_BR settings = _Translations$settings$pt_BR._(_root);
	@override late final _Translations$commands$pt_BR commands = _Translations$commands$pt_BR._(_root);
	@override late final _Translations$commandDialog$pt_BR commandDialog = _Translations$commandDialog$pt_BR._(_root);
	@override late final _Translations$expiredBuild$pt_BR expiredBuild = _Translations$expiredBuild$pt_BR._(_root);
	@override late final _Translations$staleness$pt_BR staleness = _Translations$staleness$pt_BR._(_root);
	@override late final _Translations$spotting$pt_BR spotting = _Translations$spotting$pt_BR._(_root);
	@override late final _Translations$dataFiles$pt_BR dataFiles = _Translations$dataFiles$pt_BR._(_root);
	@override late final _Translations$updates$pt_BR updates = _Translations$updates$pt_BR._(_root);
	@override late final _Translations$extensionService$pt_BR extensionService = _Translations$extensionService$pt_BR._(_root);
	@override late final _Translations$operationLocationScreen$pt_BR operationLocationScreen = _Translations$operationLocationScreen$pt_BR._(_root);
	@override late final _Translations$versionLabel$pt_BR versionLabel = _Translations$versionLabel$pt_BR._(_root);
	@override late final _Translations$notices$pt_BR notices = _Translations$notices$pt_BR._(_root);
	@override late final _Translations$syncAccount$pt_BR syncAccount = _Translations$syncAccount$pt_BR._(_root);
	@override late final _Translations$deepLink$pt_BR deepLink = _Translations$deepLink$pt_BR._(_root);
	@override late final _Translations$confirmDevice$pt_BR confirmDevice = _Translations$confirmDevice$pt_BR._(_root);
	@override late final _Translations$switchAccounts$pt_BR switchAccounts = _Translations$switchAccounts$pt_BR._(_root);
	@override late final _Translations$adifImport$pt_BR adifImport = _Translations$adifImport$pt_BR._(_root);
	@override late final _Translations$offline$pt_BR offline = _Translations$offline$pt_BR._(_root);
	@override late final _Translations$exportSettings$pt_BR exportSettings = _Translations$exportSettings$pt_BR._(_root);
	@override late final _Translations$templateEditor$pt_BR templateEditor = _Translations$templateEditor$pt_BR._(_root);
}

// Path: common
class _Translations$common$pt_BR extends Translations$common$pt {
	_Translations$common$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get save => 'Salvar';
	@override String get ok => 'OK';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Excluir';
	@override String get create => 'Criar';
	@override String get error => 'Erro';
	@override String get close => 'Fechar';
	@override String get done => 'Concluído';
	@override String get callsign => 'Indicativo';
	@override String get clear => 'Limpar';
	@override String get dismiss => 'Dispensar';
	@override String get expand => 'Expandir';
	@override String get collapse => 'Recolher';
}

// Path: onboarding
class _Translations$onboarding$pt_BR extends Translations$onboarding$pt {
	_Translations$onboarding$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Bem-vindo ao Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Bem-vindo ao Ham2K Power Logger!';
	@override String get welcomeBody => 'Temos algumas perguntas para atender melhor às suas necessidades.';
	@override String get skip => 'Pular';
	@override String get kContinue => 'Continuar';
	@override String get back => 'Voltar';
	@override String get next => 'Avançar';
	@override String get done => 'Concluído';
	@override String get callsignTitle => 'Qual é o seu indicativo?';
	@override String get callsignBody => 'Você precisa de uma licença de radioamador para que este app seja útil';
	@override String get callsignLabel => 'Indicativo do operador';
	@override String get alreadyHaveAccount => 'Já tem uma conta?';
	@override String get foundSiblingTitle => 'Vincular uma conta existente?';
	@override String foundSiblingBody({required Object app}) => 'Encontramos o ${app} neste dispositivo. Vincule este app à mesma conta e seu indicativo e seus logs serão trazidos.';
	@override String get foundPoloBody => 'Encontramos uma versão antiga do Ham2K Portable Logger neste dispositivo. Vincule este app à mesma conta e seu indicativo e seus logs serão trazidos.';
	@override String get foundSiblingsBody => 'Encontramos outros apps Ham2K neste dispositivo. Vincule este app à conta de um deles e seu indicativo e seus logs serão trazidos.';
	@override String linkWithApp({required Object app}) => 'Vincular com ${app}';
	@override String get linkWithPolo => 'Vincular com a conta da versão antiga';
	@override String get setUpFresh => 'Começar do zero';
	@override String get activitiesTitle => 'Atividades favoritas';
	@override String get activitiesBody => 'Você tem interesse em algum destes programas de ativação populares?';
	@override String get activitiesFooter => '(Você encontra mais opções nas Configurações)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Dados e privacidade';
	@override String get consentUsageBody => 'Para nos ajudar a melhorar o app, gostaríamos de coletar dados de desempenho, falhas e uso do app.';
	@override String get consentUsageLabel => 'Compartilhar dados de uso do app';
	@override String get consentOperationBody => 'Alguns recursos podem envolver o compartilhamento dos seus dados de operação com outros usuários. Você pode desativar isso a qualquer momento.';
	@override String get consentOperationLabel => 'Compartilhar dados de operação';
	@override String get finishingSetup => 'Concluindo a configuração — baixando dados de referência…';
}

// Path: startScreen
class _Translations$startScreen$pt_BR extends Translations$startScreen$pt {
	_Translations$startScreen$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get credits => 'por KI2D e amigos';
}

// Path: testerOverlay
class _Translations$testerOverlay$pt_BR extends Translations$testerOverlay$pt {
	_Translations$testerOverlay$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get tape => 'CUIDADO: EM CONSTRUÇÃO';
	@override String get warningTitle => 'Este app é um trabalho em andamento';
	@override String get warningBody => 'A maioria dos recursos tem superfícies irregulares e há risco de tropeço por toda parte. Verifique se há atualizações regularmente.';
	@override String whatsNew({required Object build}) => 'Novidades da build ${build}';
	@override String get thanks => 'Obrigado por arriscar seu log para nos ajudar a melhorar este app!';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$pt_BR extends Translations$extensionsPanel$pt {
	_Translations$extensionsPanel$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Atividades';
	@override String get categoryContest => 'Concursos';
	@override String get categoryLookup => 'Consultas de indicativo';
	@override String get categorySpots => 'Origens de spots';
	@override String get categoryDashboard => 'Painéis';
	@override String get categoryOther => 'Outras extensões';
	@override String get searchHint => 'Buscar extensões';
	@override String get applying => 'Ativando alterações de extensões, isso pode levar alguns instantes…';
	@override String get noMatches => 'Nenhuma extensão corresponde à sua busca';
	@override String get installFromFile => 'Instalar de arquivo…';
	@override String installVersion({required Object version}) => 'Versão ${version}';
	@override String get canReach => 'Esta extensão pode contatar';
	@override String canHoldConnection({required Object host}) => '${host}, por uma conexão ativa';
	@override String get canHoldLocalConnection => 'Dispositivos na sua rede local, por uma conexão ativa';
	@override String get canUseLocation => 'Sua localização';
	@override String get canReadRadio => 'Seu rádio, para ler a frequência e o modo';
	@override String get canControlRadio => 'Seu rádio, para controlá-lo e transmitir com ele — sintonia, potência, CW, memórias de voz e PTT';
	@override String get canSetUserAgent => 'Identificar-se aos servidores com o próprio nome';
	@override String get noCapabilities => 'Não pede nada fora do app.';
	@override String get sandboxNote => 'As extensões rodam isoladas: sem acesso aos seus arquivos e sem rede além do que está listado aqui.';
	@override String get installAction => 'Instalar';
	@override String get updateAction => 'Atualizar';
	@override String get installFailed => 'Não foi possível instalar essa extensão';
	@override String get installedBadge => 'Instalada';
	@override String get uninstallAction => 'Remover';
	@override String uninstallTitle({required Object name}) => 'Remover ${name}?';
	@override String get uninstallBody => 'Esta extensão e suas configurações serão removidas. Seus logs não serão alterados.';
	@override String installedMessage({required Object name}) => '${name} instalada';
	@override String get installDownloading => 'Baixando…';
	@override String get installWaiting => 'Aguardando para instalar…';
	@override String get installInstalling => 'Instalando…';
	@override String get installAwaitingApproval => 'Aguardando sua aprovação…';
	@override String installAlreadyRunning({required Object name}) => '${name} já está sendo instalada.';
	@override String updatedTo({required Object version}) => 'Atualizada para ${version}';
	@override String installIncomplete({required Object name}) => 'A instalação de ${name} não terminou. Talvez seja preciso instalá-la novamente.';
	@override String uninstallFailed({required Object name}) => 'Não foi possível remover ${name}';
	@override String installedFrom({required Object source}) => 'Baixada de ${source}';
	@override String get dropHint => 'Solte uma extensão .h2kext para instalá-la';
	@override String get dropOneOnly => 'Solte uma extensão por vez.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} retornou ${status} para essa extensão.';
	@override String get downloadTooLarge => 'Esse download é grande demais para ser uma extensão.';
	@override String get downloadNotSecure => 'Esse download foi redirecionado para um local inseguro.';
	@override String get catalogSection => 'Catálogo';
	@override String get catalogLoading => 'Carregando o catálogo…';
	@override String get catalogUnreachable => 'Catálogo inacessível';
	@override String get builtIn => 'Integrada';
	@override String get updateAvailableBadge => 'Atualização disponível';
	@override String get updatesAvailableTitle => 'Atualizações de extensões';
	@override String updateAvailableFor({required Object name}) => 'Há uma atualização disponível para ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} e mais ${count} precisam ser atualizadas.';
	@override String updatesAvailableFor({required Object names}) => '${names} precisam ser atualizadas.';
	@override String get pendingUpdatesSection => 'Atualizações pendentes';
	@override String get updateAllAction => 'Atualizar todas';
	@override String get updatesUnderWay => 'Essas atualizações já estão em andamento.';
	@override String get updatesNothingLeft => 'Suas extensões estão atualizadas.';
	@override String get updatesNoticeAction => 'Mais informações';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Atualizar ${count} extensão?',
		other: 'Atualizar ${count} extensões?',
	);
	@override String get upgradeDoneTitle => 'Suas extensões estão prontas';
	@override String get upgradeDoneBody => 'Agora elas vêm do catálogo de extensões do Ham2K, então podem ser atualizadas sem esperar por uma nova versão do app.';
	@override String upgradeDoneUnserved({required Object names}) => 'Não atualizadas: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Não puderam rodar: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Elas continuam instaladas e marcadas em Configurações › Extensões — atualizá-las lá as trará de volta.';
	@override String get upgradeDoneUnservedHint => 'O catálogo não tem substituto direto para estas, então procure lá extensões que cubram o que você usava.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Eventos de parques estaduais';
	@override String upgradeDoneMissing({required Object count}) => '${count} das suas extensões ainda não chegaram. Elas serão baixadas na próxima vez que o catálogo de extensões estiver acessível.';
	@override String get runtimeDeadBody => 'Suas extensões não iniciaram. Reiniciar o app deve trazê-las de volta.';
	@override String get refusedTitle => 'Algumas extensões não puderam rodar';
	@override String get upgradeBusyTitle => 'Ainda configurando';
	@override String get upgradeRuntimeDeadTitle => 'Suas extensões não estão rodando';
	@override String get restoreTitle => 'Algumas das suas extensões estão faltando';
	@override String get restoreBody => 'Estas extensões que você instalou não estão neste dispositivo. Podemos baixá-las novamente do catálogo de extensões do Ham2K:';
	@override String get restoreFromFile => 'Instaladas de um arquivo. Instale-as novamente a partir dos arquivos ou esqueça-as:';
	@override String get restoreOtherCatalog => 'Instaladas de outro catálogo de extensões, por isso não estão disponíveis aqui:';
	@override String get restoreForget => 'Esquecer';
	@override String get restoreInstall => 'Instalar';
	@override String get restoreLater => 'Mais tarde';
	@override String get restoreInstalling => 'Instalando suas extensões…';
	@override String get restoreDoneTitle => 'Suas extensões estão de volta';
	@override String restoreDoneBody({required Object names}) => 'Instaladas novamente: ${names}.';
	@override String get restorePartialTitle => 'Algumas extensões não puderam ser instaladas';
	@override String restoreFailed({required Object names}) => 'Não foi possível instalar: ${names}. Vamos oferecê-las novamente na próxima vez que você abrir o app.';
	@override String get restoreBusyBody => 'O app ainda está configurando suas extensões. Vamos oferecê-las novamente na próxima vez que você abrir o app.';
	@override String get restoreRuntimeDeadBody => 'Nós as instalamos novamente, mas suas extensões não iniciaram. Reiniciar o app deve trazê-las de volta.';
	@override String revokedTitle({required Object name}) => '${name} foi retirada';
	@override String get revokedBody => 'O catálogo retirou esta versão, por isso ela foi desativada.';
	@override String get downloadHashMismatch => 'Esse download não é a extensão que o catálogo descreveu.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'O catálogo não tem a versão ${version} de ${key}.';
	@override String get catalogLinkUnknown => 'Esse link do catálogo não indica uma versão de extensão.';
	@override String catalogNoRelease({required Object key}) => 'O catálogo não tem uma versão de ${key} nesse canal.';
	@override String get installFromLink => 'Instalar de link';
	@override String get unstableReleaseWarning => 'Esta é uma versão instável, que o autor ainda não considera concluída. Ela pode se comportar mal e continuará recebendo atualizações instáveis.';
	@override String get bleedingReleaseWarning => 'Esta é uma versão experimental: trabalho em andamento que pode quebrar ou perder suas configurações. Ela continuará recebendo atualizações experimentais.';
	@override String get channelUnstable => 'Instável';
	@override String get channelBleeding => 'Experimental';
	@override String get followsUnstable => 'Recebe versões instáveis e estáveis';
	@override String get followsBleeding => 'Recebe versões experimentais, instáveis e estáveis';
	@override String get followStableAction => 'Seguir apenas versões estáveis';
	@override String get revokedBadge => 'Revogada';
	@override String get refusedBadge => 'Não carregou';
	@override String get downloadNotHttps => 'Esse download não usa uma conexão segura.';
	@override String downloadUnreachable({required Object source}) => 'Não foi possível acessar ${source} para essa extensão.';
	@override String get detailsAction => 'Detalhes';
	@override String get installedFromFile => 'Instalada de um arquivo';
	@override String get detailsWhatItDoes => 'Oferece suporte para';
	@override String get installedPreloaded => 'Pré-instalada';
	@override String get hookAccount => 'Login de conta';
	@override String get hookCallNotes => 'Notas de indicativo';
	@override String get hookDataFile => 'Dados offline';
	@override String get hookExport => 'Exportação';
	@override String get hookLookup => 'Consultas de indicativo';
	@override String get hookScoring => 'Pontuação';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => 'Caçando ${program}';
	@override String hookActivating({required Object program}) => 'Ativando ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '… e mais ${count} extensão',
		other: '… e mais ${count} extensões',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} extensão disponível',
		other: '${count} extensões disponíveis',
	);
}

// Path: home
class _Translations$home$pt_BR extends Translations$home$pt {
	_Translations$home$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logger Portátil';
	@override String get newOperation => 'Nova operação';
	@override String get stationCallsign => 'Indicativo da estação';
	@override String get titleOptional => 'Título (opcional)';
	@override String get emptyList => 'Ainda não há operações. Crie uma para começar a registrar.';
	@override String get quickLookup => 'Consulta rápida';
	@override late final _Translations$home$nav$pt_BR nav = _Translations$home$nav$pt_BR._(_root);
	@override late final _Translations$home$panels$pt_BR panels = _Translations$home$panels$pt_BR._(_root);
	@override String get toggleNav => 'Mostrar ou ocultar os rótulos de navegação';
	@override late final _Translations$home$logs$pt_BR logs = _Translations$home$logs$pt_BR._(_root);
}

// Path: chase
class _Translations$chase$pt_BR extends Translations$chase$pt {
	_Translations$chase$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'caçando';
	@override String goalsTwo({required Object first, required Object second}) => '${first} e ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} e mais';
	@override late final _Translations$chase$station$pt_BR station = _Translations$chase$station$pt_BR._(_root);
	@override late final _Translations$chase$periodInline$pt_BR periodInline = _Translations$chase$periodInline$pt_BR._(_root);
	@override late final _Translations$chase$periodStats$pt_BR periodStats = _Translations$chase$periodStats$pt_BR._(_root);
	@override late final _Translations$chase$period$pt_BR period = _Translations$chase$period$pt_BR._(_root);
	@override late final _Translations$chase$goals$pt_BR goals = _Translations$chase$goals$pt_BR._(_root);
	@override late final _Translations$chase$panels$pt_BR panels = _Translations$chase$panels$pt_BR._(_root);
}

// Path: dialogs
class _Translations$dialogs$pt_BR extends Translations$dialogs$pt {
	_Translations$dialogs$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Detalhes da operação';
	@override String get activities => 'Atividades';
	@override String get stationCallsign => 'Indicativo da estação';
	@override String get notes => 'Notas';
	@override String get deleteOperationTitle => 'Excluir operação';
	@override String get purgeTestsTitle => 'Eliminar operações de teste';
	@override String get purgeTestsBody => 'Isso exclui permanentemente estas operações de teste e seus QSOs. Não pode ser desfeito.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Mais ${count} contato de teste que não pertence a nenhuma operação.',
		other: 'Mais ${count} contatos de teste que não pertencem a nenhuma operação.',
	);
	@override String get purgeTestsAction => 'Eliminar';
	@override String get syncAllTitle => 'Substituir o log deste dispositivo?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL faz backup e remove ${qsos} deste dispositivo e depois baixa novamente o log da conta do servidor. O backup fica no banco de dados deste dispositivo.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO ainda não foi sincronizado — o servidor nunca o recebeu e ele NÃO voltará.',
		other: '${n} QSOs ainda não foram sincronizados — o servidor nunca os recebeu e eles NÃO voltarão.',
	);
	@override String get syncAllAction => 'Apagar e ressincronizar';
	@override String get receivedPurgesTitle => 'Operações de teste removidas em outro lugar';
	@override String get receivedPurgesBody => 'Estas foram excluídas como operações de teste em outro dispositivo. Removê-las aqui também? Isso as exclui permanentemente, junto com seus QSOs, e não pode ser desfeito.';
	@override String get receivedPurgesAction => 'Remover';
	@override late final _Translations$dialogs$callChange$pt_BR callChange = _Translations$dialogs$callChange$pt_BR._(_root);
}

// Path: operation
class _Translations$operation$pt_BR extends Translations$operation$pt {
	_Translations$operation$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Esta operação foi excluída. Restaure-a para registrar ou fazer alterações.';
	@override late final _Translations$operation$tabs$pt_BR tabs = _Translations$operation$tabs$pt_BR._(_root);
	@override late final _Translations$operation$positions$pt_BR positions = _Translations$operation$positions$pt_BR._(_root);
	@override String get stationCallsignNone => 'Sem indicativo da estação';
	@override String get titleNone => 'Sem título';
	@override String get deleteOperation => 'Excluir operação';
	@override String get loggingControlsStale => 'Os campos de atividade podem estar desatualizados — reabra a operação para atualizá-los';
	@override String get locationNone => 'Não definida';
	@override String get generalOperation => 'Operação geral';
	@override String titleFor({required Object value}) => 'para ${value}';
	@override String titleAt({required Object value}) => 'em ${value}';
	@override String segmentNow({required Object description}) => 'Agora ${description}';
	@override String get testOperationSuffix => 'Teste';
	@override late final _Translations$operation$menu$pt_BR menu = _Translations$operation$menu$pt_BR._(_root);
	@override late final _Translations$operation$layout$pt_BR layout = _Translations$operation$layout$pt_BR._(_root);
	@override late final _Translations$operation$export$pt_BR export = _Translations$operation$export$pt_BR._(_root);
	@override late final _Translations$operation$spots$pt_BR spots = _Translations$operation$spots$pt_BR._(_root);
	@override late final _Translations$operation$import$pt_BR import = _Translations$operation$import$pt_BR._(_root);
}

// Path: map
class _Translations$map$pt_BR extends Translations$map$pt {
	_Translations$map$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$pt_BR outlineIssue = _Translations$map$outlineIssue$pt_BR._(_root);
	@override String get outlinesDisclaimer => 'Os contornos são apenas para referência. Faça sua própria pesquisa!';
	@override String outlinesCredit({required Object sources}) => 'Contornos: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Limites: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Instalações: ${sources}';
	@override String get fullCredits => 'Créditos completos dos dados';
	@override String get fewerCredits => 'Menos créditos';
	@override String get emptyState => 'Ainda não há localizações de QSOs.\nQSOs com grid square, estado ou país aparecerão aqui.';
	@override String get unavailable => 'O mapa não está disponível agora.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plano';
	@override String get globe => 'Globo';
	@override String get zoomIn => 'Aproximar';
	@override String get zoomOut => 'Afastar';
	@override late final _Translations$map$postcard$pt_BR postcard = _Translations$map$postcard$pt_BR._(_root);
}

// Path: mapsView
class _Translations$mapsView$pt_BR extends Translations$mapsView$pt {
	_Translations$mapsView$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override String get searchHint => 'Buscar parques, cumes e mais';
	@override String get activities => 'Atividades';
	@override String get layers => 'Camadas';
	@override String get baseMap => 'Mapa base';
	@override String get satellite => 'Satélite (Esri)';
	@override String get facilities => 'Instalações dos parques';
	@override String get boundaries => 'Limites';
	@override String get currentLocation => 'Localização atual';
	@override String noMatches({required Object text}) => 'Nada corresponde a “${text}”';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} referência em ${where}',
		other: '${count} referências em ${where}',
	);
	@override String get startOperation => 'Iniciar uma operação com estas referências';
}

// Path: activitiesView
class _Translations$activitiesView$pt_BR extends Translations$activitiesView$pt {
	_Translations$activitiesView$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Atividades';
	@override String get activitiesCountZero => 'Nenhuma atividade selecionada';
	@override String get activitiesCountOne => '1 atividade';
	@override String activitiesCountOther({required Object count}) => '${count} atividades';
	@override String get empty => 'Nenhuma atividade ainda — use Sugestões e busca abaixo para adicionar uma';
	@override String get removeActivity => 'Remover';
	@override String openReferenceLink({required Object name}) => 'Abrir ${name}';
	@override String get editActivity => 'Editar atividade';
	@override String get manageExtensions => 'Gerenciar extensões';
	@override String get manage => 'Gerenciar';
	@override String activitiesTitle1({required Object first}) => 'Tipos de atividade: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipos de atividade: ${first} e ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipos de atividade: ${first}, ${second} e mais ${more}';
	@override String get reference => 'Referência';
	@override String get invalidReference => 'Inválida';
	@override String get duplicateReference => 'Já adicionada';
	@override String get searchHint => 'Buscar por nome, referência ou qualquer outra coisa…';
	@override String get noSuggestions => 'Nenhum resultado';
	@override String get noSuggestionsHint => 'Busque pelo nome ou número da referência acima';
	@override String get noSuggestionsExample => '(por exemplo \'trilha\' ou \'4556\')';
	@override String get allOptions => 'Tipos de atividade';
	@override String get determiningLocation => 'Determinando a localização atual…\nAguardando o GPS para encontrar referências próximas';
	@override String get locationUnavailableTitle => 'Dados de localização indisponíveis';
	@override String get locationDeniedTitle => 'Permissão de localização negada';
	@override String get locationBlockedTitle => 'Permissão de localização bloqueada';
	@override String get noNearbyReason => 'Não é possível determinar referências próximas';
	@override String locationManualHint({required Object icon}) => 'Toque em ${icon} para inserir sua localização manualmente,\nou simplesmente busque referências pelo nome';
	@override String get locationGrantAction => 'Permitir acesso à localização';
	@override String get locationSettingsAction => 'Abrir configurações';
	@override String get locationSettingsUnavailable => 'Permita o acesso à localização nas configurações do sistema';
	@override String get locationGrantRefused => 'Ainda sem localização — o sistema negou novamente';
	@override String get searchUnavailableTitle => 'Busca de atividades indisponível';
	@override String get searchUnavailableReason => 'Nenhuma extensão de atividade conseguiu executar a busca. Tente novamente em instantes.';
	@override String get emptySheet => 'Use sugestões e busca abaixo para adicionar uma';
	@override String get exports => 'Exportações';
	@override String get exportLogs => 'Exportar logs';
	@override String get tools => 'Ferramentas';
	@override String get toolsTitle => 'Ferramentas da operação';
	@override String get operationDetails => 'Detalhes da operação';
	@override String get share => 'Compartilhar';
	@override String get archive => 'Arquivar';
	@override String get deleteOperation => 'Excluir operação';
	@override String get undeleteOperation => 'Restaurar operação';
	@override String get alreadySelected => 'Já selecionada';
	@override String get selected => 'Selecionada';
	@override String pickPosition({required Object index, required Object count}) => '${index} de ${count}';
	@override String get previousPick => 'Resultado anterior';
	@override String get nextPick => 'Próximo resultado';
	@override String get retiredReference => 'Desativada';
	@override String enableExtension({required Object name}) => 'Habilitar ${name}';
	@override String get enableExtensionHint => 'Esta extensão corresponde à sua busca, mas não está habilitada';
	@override String get enableExtensionForRefHint => 'Esta extensão trata uma das referências desta operação, mas não está habilitada';
	@override String extensionNotRunning({required Object name}) => '${name} não está rodando';
	@override String get extensionNotRunningHint => 'Esta extensão foi desativada; abra as Configurações de extensões para mais informações';
	@override String installExtension({required Object name}) => 'Instalar ${name}';
	@override String get installExtensionHint => 'Esta extensão corresponde à sua busca, mas não está instalada';
	@override String get onlyCatalogMatches => 'Nenhum resultado\nAlgumas extensões do catálogo podem ter resultados.\nInstale-as em Tipos de atividade abaixo.';
	@override String get setupUnavailable => 'Não foi possível carregar a configuração desta atividade — tente novamente em Gerenciar';
	@override String get controlsUnavailableTitle => 'Controles da atividade indisponíveis';
	@override String get controlsUnavailableReason => 'Suas referências estão seguras, mas não é possível editá-las agora.';
	@override String get controlsUnavailableRetry => 'Tentar novamente';
	@override String get onlyDisabledMatches => 'Nenhum resultado\nAlgumas extensões disponíveis podem ter resultados.\nHabilite-as em Tipos de atividade abaixo.';
	@override String get onlyNotRunningMatches => 'Nenhum resultado\nAlgumas extensões que podem ter resultados não estão rodando.\nVeja Tipos de atividade abaixo.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Busca';
	@override String get addToOperation => 'Adicionar à operação';
	@override String get addToOperationShort => 'Adicionar';
	@override String get mapEmptyState => 'Nenhum resultado para mostrar no mapa';
	@override String get mapEmptyStateHint => 'Volte para a lista ou busque outra coisa';
	@override String get imports => 'Importações';
}

// Path: loggingControls
class _Translations$loggingControls$pt_BR extends Translations$loggingControls$pt {
	_Translations$loggingControls$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Data';
	@override String get now => 'Agora';
	@override String get frequency => 'Frequência';
	@override String get mode => 'Modo';
	@override String get theirCall => 'Indicativo deles';
	@override String get noteField => 'Nota';
	@override String get todoField => 'Tarefa';
	@override String get sent => 'Enviado';
	@override String get rcvd => 'Recebido';
	@override String get more => 'Mais';
	@override String get revert => 'Reverter';
	@override String get undoDelete => 'Desfazer exclusão';
	@override String get restore => 'Restaurar';
	@override String get wipe => 'Apagar';
	@override String get undo => 'Desfazer';
	@override String get pendingDeleteTapWarning => 'Toque na lixeira mais uma vez para excluir este QSO';
	@override String get pendingDeleteClickWarning => 'Clique na lixeira mais uma vez para excluir este QSO';
	@override String get deletedQsoWarning => 'QSO excluído';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Toque na lixeira mais uma vez para excluir: ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Clique na lixeira mais uma vez para excluir: ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'Excluído: ${kind}';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Rádio';
	@override String get powerControl => 'Potência';
	@override String get notesControl => 'Notas';
	@override String get power => 'Potência';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controles de registro';
	@override String get spottingControl => 'Spots';
	@override String get spottingSelfControl => 'Auto-spot';
	@override String spotSelfAt({required Object freq}) => 'Auto-spot em ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot de ${call} em ${freq}';
	@override String spotTooLate({required Object call}) => 'Tarde demais para dar spot em ${call}';
	@override String get spotNoFreq => 'Primeiro defina uma frequência para o spot';
	@override String get spotComment => 'Comentário';
	@override String get bandOrFreqRequired => 'Defina uma frequência ou banda antes de registrar';
	@override String get missingBand => 'Sem banda';
	@override String get missingMode => 'Sem modo';
	@override String saveFailed({required Object error}) => 'Não foi possível salvar: ${error}';
	@override String deleteFailed({required Object error}) => 'Não foi possível excluir: ${error}';
	@override late final _Translations$loggingControls$info$pt_BR info = _Translations$loggingControls$info$pt_BR._(_root);
}

// Path: formChrome
class _Translations$formChrome$pt_BR extends Translations$formChrome$pt {
	_Translations$formChrome$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(sem título)';
	@override String get showMore => 'Mostrar mais';
	@override String get showAll => 'Mostrar tudo';
	@override String get showFewer => 'Mostrar menos';
	@override String get defaults => 'Padrões';
	@override String get search => 'Buscar';
	@override String get clear => 'Limpar';
	@override String get openPage => 'Abrir página';
	@override String get connected => 'Conectado';
	@override String get notConnected => 'Não conectado';
	@override String get manage => 'Gerenciar';
	@override String get connect => 'Conectar';
	@override String get formTitle => 'Formulário';
	@override String addItem({required Object label}) => 'Adicionar ${label}';
	@override String editItem({required Object label}) => 'Editar ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} selecionados)';
	@override String validationError({required Object error}) => 'Erro de validação: ${error}';
	@override String transformationError({required Object error}) => 'Erro de transformação: ${error}';
	@override String actionError({required Object error}) => 'Erro: ${error}';
	@override String get removeItem => 'Remover';
	@override String get storageUnavailable => 'Logins indisponíveis';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$pt_BR extends Translations$qsoEditForm$pt {
	_Translations$qsoEditForm$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Editar QSO';
	@override String get operatorCall => 'Operador';
	@override String get position => 'Posição';
	@override String get theirName => 'Nome';
	@override String get theirGrid => 'Grid';
	@override String get theirState => 'Estado';
	@override String get band => 'Banda';
	@override String get notes => 'Notas';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Informações deles';
	@override String get sectionOur => 'Nossas informações';
	@override String get sectionNotes => 'Notas';
	@override String get theirCity => 'Cidade';
	@override String get theirCounty => 'Condado';
	@override String get theirEntity => 'Entidade';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Seção ARRL';
	@override String get theirLat => 'Latitude';
	@override String get theirLon => 'Longitude';
	@override String get theirPower => 'Potência deles';
}

// Path: qsoList
class _Translations$qsoList$pt_BR extends Translations$qsoList$pt {
	_Translations$qsoList$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nenhum QSO ainda — chame alguém!';
	@override String get bandOrModeWarning => 'Verifique se a banda e o modo estão corretos';
	@override String get today => 'Hoje';
	@override String get yesterday => 'Ontem';
	@override String get tomorrow => 'Amanhã';
}

// Path: loggingPanel
class _Translations$loggingPanel$pt_BR extends Translations$loggingPanel$pt {
	_Translations$loggingPanel$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Estatísticas da operação';
	@override String get scoring => 'Pontuação';
	@override String get dxccEntities => 'Entidades DXCC';
	@override String get statesWorked => 'Estados';
	@override String get provincesWorked => 'Províncias';
	@override String get duplicates => 'Duplicados';
}

// Path: callInfo
class _Translations$callInfo$pt_BR extends Translations$callInfo$pt {
	_Translations$callInfo$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostrar imagem';
	@override String get imageUnavailable => 'Foto indisponível';
	@override String get photo => 'Foto';
	@override String get notes => 'Notas';
	@override String distanceTo({required Object distance}) => '${distance} até';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) até';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) até';
	@override String distanceAway({required Object distance}) => '${distance} de distância';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distância';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distância';
	@override String get thisOpCountOne => '1 QSO nesta operação';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs nesta operação';
	@override String get otherOpsCountOne => '1 QSO em outras operações';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs em outras operações';
	@override String andMore({required Object count}) => '… e mais ${count}';
	@override String withCall({required Object call}) => 'com ${call}';
	@override String fromOperation({required Object where}) => 'de ${where}';
	@override late final _Translations$callInfo$history$pt_BR history = _Translations$callInfo$history$pt_BR._(_root);
}

// Path: settings
class _Translations$settings$pt_BR extends Translations$settings$pt {
	_Translations$settings$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurações';
	@override String get language => 'Idioma';
	@override String languageSystem({required Object language}) => 'Seguir as configurações do sistema (${language})';
	@override late final _Translations$settings$theme$pt_BR theme = _Translations$settings$theme$pt_BR._(_root);
	@override late final _Translations$settings$themeDescription$pt_BR themeDescription = _Translations$settings$themeDescription$pt_BR._(_root);
	@override String get fontScale => 'Escala da fonte';
	@override late final _Translations$settings$fontScaleOpts$pt_BR fontScaleOpts = _Translations$settings$fontScaleOpts$pt_BR._(_root);
	@override late final _Translations$settings$keepDeviceAwake$pt_BR keepDeviceAwake = _Translations$settings$keepDeviceAwake$pt_BR._(_root);
	@override String get layoutDensity => 'Densidade do layout';
	@override late final _Translations$settings$layoutDensityOpts$pt_BR layoutDensityOpts = _Translations$settings$layoutDensityOpts$pt_BR._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'a janela é baixa demais, usando ${effective}';
	@override String get layoutDensityAtLimit => 'no limite';
	@override String get distanceUnits => 'Unidades de distância';
	@override late final _Translations$settings$distanceUnitsOpts$pt_BR distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$pt_BR._(_root);
	@override String get userInterface => 'Interface do usuário';
	@override late final _Translations$settings$logging$pt_BR logging = _Translations$settings$logging$pt_BR._(_root);
	@override late final _Translations$settings$catServer$pt_BR catServer = _Translations$settings$catServer$pt_BR._(_root);
	@override late final _Translations$settings$radio$pt_BR radio = _Translations$settings$radio$pt_BR._(_root);
	@override late final _Translations$settings$help$pt_BR help = _Translations$settings$help$pt_BR._(_root);
	@override late final _Translations$settings$exports$pt_BR exports = _Translations$settings$exports$pt_BR._(_root);
	@override late final _Translations$settings$map$pt_BR map = _Translations$settings$map$pt_BR._(_root);
	@override late final _Translations$settings$privacy$pt_BR privacy = _Translations$settings$privacy$pt_BR._(_root);
	@override String get operatorCall => 'Indicativo do operador';
	@override late final _Translations$settings$sync$pt_BR sync = _Translations$settings$sync$pt_BR._(_root);
	@override late final _Translations$settings$peers$pt_BR peers = _Translations$settings$peers$pt_BR._(_root);
	@override String get developerMode => 'Modo desenvolvedor';
	@override late final _Translations$settings$syncPanel$pt_BR syncPanel = _Translations$settings$syncPanel$pt_BR._(_root);
	@override late final _Translations$settings$accounts$pt_BR accounts = _Translations$settings$accounts$pt_BR._(_root);
	@override late final _Translations$settings$station$pt_BR station = _Translations$settings$station$pt_BR._(_root);
	@override late final _Translations$settings$offlineData$pt_BR offlineData = _Translations$settings$offlineData$pt_BR._(_root);
	@override late final _Translations$settings$profiles$pt_BR profiles = _Translations$settings$profiles$pt_BR._(_root);
	@override late final _Translations$settings$search$pt_BR search = _Translations$settings$search$pt_BR._(_root);
	@override late final _Translations$settings$developer$pt_BR developer = _Translations$settings$developer$pt_BR._(_root);
	@override late final _Translations$settings$about$pt_BR about = _Translations$settings$about$pt_BR._(_root);
	@override late final _Translations$settings$panels$pt_BR panels = _Translations$settings$panels$pt_BR._(_root);
	@override String get showMoreSettings => 'Mostrar mais configurações';
	@override String get gridPrecision => 'Precisão do grid';
	@override late final _Translations$settings$gridPrecisionOpts$pt_BR gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$pt_BR._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$pt_BR gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$pt_BR._(_root);
}

// Path: commands
class _Translations$commands$pt_BR extends Translations$commands$pt {
	_Translations$commands$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Habilite a sincronização nas Configurações primeiro.';
	@override String get fullResyncStarted => 'Ressincronização completa iniciada — os dados locais foram salvos em backup antes.';
	@override String noDataFilesMatched({required Object target}) => 'Nenhum arquivo de dados corresponde a "${target}".';
	@override String reloadFailed({required Object error}) => 'Falha ao recarregar: ${error}';
	@override String get reloadingAll => 'Recarregando todos os arquivos de dados…';
	@override String reloadingTarget({required Object target}) => 'Recarregando arquivos de dados de ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experimento desconhecido "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} habilitado';
	@override String experimentDisabled({required Object name}) => '${name} desabilitado';
	@override String get sentryTestSent => 'Relatório de erro de teste enviado ao Sentry';
	@override String get sentryTestLocalOnly => 'O Sentry está desativado nesta build — erro de teste registrado apenas localmente';
	@override String get noOperationOpen => 'Esse comando precisa de uma operação aberta';
	@override String unknownSegmentKind({required Object kind}) => 'Não sei como marcar \'${kind}\'';
	@override String get operationAlreadyStarted => 'Esta operação já tem um marcador de início';
	@override String get couldNotOpenLocation => 'O intervalo foi adicionado, mas não foi possível abrir a tela de localização';
	@override String get noTestOperations => 'Nenhuma operação de teste para eliminar';
	@override String get purgeTestsUnavailable => 'PURGETESTS precisa mostrar uma caixa de confirmação, que não está disponível aqui';
	@override String get syncAllUnavailable => 'SYNCALL precisa mostrar uma caixa de confirmação, que não está disponível aqui';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} operação de teste eliminada',
		other: '${count} operações de teste eliminadas',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '${purged} de ${total} operações de teste eliminadas — as demais falharam; tente PURGETESTS novamente';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contato de teste sem operação eliminado',
		other: '${count} contatos de teste sem operação eliminados',
	);
	@override String get purgeTestsContactsFailed => 'As operações de teste foram eliminadas, mas os contatos de teste sem operação falharam; tente PURGETESTS novamente';
	@override String get purgeTestsNothingToDo => 'Nada foi eliminado';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '${removed} de ${total} operações de teste removidas — as demais falharam; tente Revisar novamente';
	@override String get receivedPurgesFailed => 'Não foi possível remover essas operações de teste — tente Revisar novamente';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} operação de teste foi removida em outro dispositivo',
		other: '${count} operações de teste foram removidas em outro dispositivo',
	);
	@override String get receivedPurgesReview => 'Revisar';
	@override String get settingOn => 'Ligado';
	@override String get settingOff => 'Desligado';
	@override String get settingEmpty => '(vazio)';
	@override String get settingSecretSet => '(definido)';
	@override String get settingSecretUnset => '(não definido)';
	@override String settingSelectedCount({required Object count}) => '${count} selecionados';
	@override String get settingExpectsOnOff => 'on ou off';
	@override String settingExpectsOneOf({required Object choices}) => 'um de: ${choices}';
	@override String get settingExpectsNumber => 'um número';
	@override String settingVanished({required Object label}) => '“${label}” não está mais disponível';
	@override String get noCwKeyer => 'Nenhum rádio conectado pode manipular CW';
	@override String get noKeyer => 'Nenhum rádio conectado pode manipular CW ou reproduzir memórias de voz';
	@override String get keyerNeedsOperation => 'Abra uma operação para usar o manipulador de CW';
	@override String get keyerExperimentOff => 'A manipulação de CW está desligada — ative-a com EXP KEYER';
	@override String get esmExperimentOff => 'Enter envia mensagens está desligado — ative com EXP ESM';
	@override String cwSending({required Object text}) => 'Enviando CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Mensagem de CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'A mensagem de CW F${n} não foi enviada: as extensões não estão prontas';
	@override String settingNotStored({required Object label}) => '“${label}” não aceitou esse valor';
}

// Path: commandDialog
class _Translations$commandDialog$pt_BR extends Translations$commandDialog$pt {
	_Translations$commandDialog$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Busque indicativos ou digite um comando';
	@override String noResults({required Object text}) => 'Nada corresponde a “${text}”';
	@override String get sectionCommands => 'Comandos';
	@override String get sectionGoTo => 'Ir para';
	@override String get sectionOperations => 'Operações';
	@override String get goHome => 'Início';
	@override String get goSettings => 'Configurações';
	@override String get goNewOperation => 'Nova operação';
	@override String runTyped({required Object text}) => 'Executar “${text}”';
	@override String get sectionSuggestions => 'Experimente';
	@override String get lookingUp => 'Consultando indicativo…';
	@override String get blockedByPane => 'Não é possível usar comandos enquanto um painel ou diálogo está aberto';
}

// Path: expiredBuild
class _Translations$expiredBuild$pt_BR extends Translations$expiredBuild$pt {
	_Translations$expiredBuild$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta build expirou';
	@override String get body => 'Visite ham2k.com e obtenha uma versão mais recente.';
	@override String get visit => 'Visitar ham2k.com';
	@override String get dismiss => 'Continuar mesmo assim';
}

// Path: staleness
class _Translations$staleness$pt_BR extends Translations$staleness$pt {
	_Translations$staleness$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Uma atualização importante está aguardando';
	@override String get codePushFloorBody => 'Esta versão tem uma correção que você ainda não tem.';
	@override String get restartToApply => 'Reinicie o app para aplicá-la.';
	@override String get quitAndReopen => 'Saia do app e abra-o novamente para aplicá-la.';
	@override String get reopenToApply => 'Feche o app e abra-o novamente para aplicá-la.';
	@override String get ignoreForNow => 'Ignorar por enquanto';
}

// Path: spotting
class _Translations$spotting$pt_BR extends Translations$spotting$pt {
	_Translations$spotting$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Nenhum QSO registrado ainda para dar spot.';
	@override String get setFrequencyFirst => 'Defina uma frequência primeiro.';
	@override String get nothingToSpot => 'Nada para dar spot — nenhuma extensão oferece spots aqui.';
	@override String spotFailed({required Object source, required Object message}) => '${source} falhou: ${message}';
	@override String get unknownError => 'erro desconhecido';
	@override String get notSent => 'Spot não enviado.';
	@override String get notRefreshedOffline => 'Sem conexão — os spots não foram atualizados';
}

// Path: dataFiles
class _Translations$dataFiles$pt_BR extends Translations$dataFiles$pt {
	_Translations$dataFiles$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Baixando…';
	@override String downloadFailedTitle({required Object name}) => 'Não foi possível baixar ${name}';
	@override String get downloadFailedWebHint => 'Pode ser um problema de rede, ou o servidor deste link pode não permitir downloads diretos de um navegador. Experimente o app para desktop ou celular, ou outro local de hospedagem.';
	@override String get downloadTimedOut => 'O servidor demorou demais para responder. Tente novamente mais tarde.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} respondeu com um erro (HTTP ${status}). Tente novamente mais tarde.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} não conseguiu fornecer este arquivo (HTTP ${status}). Verifique se o endereço ainda está correto.';
	@override String processingFailedTitle({required Object name}) => 'Não foi possível processar ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'O download tinha apenas ${imported} dos ${existing} registros deste dispositivo, então os que ficaram de fora foram mantidos. Atualizá-lo em Configurações › Dados offline o aceita mesmo assim.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} registro importado para ${label}.',
		other: '${count} registros importados para ${label}.',
	);
	@override String importedData({required Object label}) => 'Dados importados para ${label}.';
	@override String get cleanedUpTitle => 'Dados de extensões limpos';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Dados removidos de ${count} arquivo de dados de extensões desabilitadas.',
		other: 'Dados removidos de ${count} arquivos de dados de extensões desabilitadas.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} registros';
	@override String get definitionUnavailable => 'A origem do arquivo não forneceu uma definição — a extensão pode estar reiniciando ou mal configurada. Tente novamente em instantes.';
}

// Path: updates
class _Translations$updates$pt_BR extends Translations$updates$pt {
	_Translations$updates$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Atualização disponível';
	@override String newVersionAvailable({required Object version}) => 'Uma nova versão (${version}) está disponível.';
	@override String get getIt => 'Obter';
	@override String get ok => 'OK';
	@override String get updateReady => 'Atualização pronta';
	@override String get restartToApply => 'Uma atualização foi baixada. Reinicie para aplicá-la.';
	@override String get appliesNextLaunch => 'Uma atualização foi baixada. Ela será aplicada na próxima vez que você abrir o app.';
	@override String get restartNow => 'Reiniciar agora';
	@override String get reloadToUpdate => 'Uma versão mais nova desta página está disponível. Recarregue para obtê-la.';
	@override String get reloadNow => 'Recarregar agora';
	@override String get checkForUpdates => 'Verificar atualizações';
	@override String get checkingForUpdates => 'Verificando atualizações…';
	@override String get upToDate => 'Atualizado';
	@override String get automaticChecks => 'Verificar automaticamente';
	@override String get automaticChecksDescription => 'Procura novas versões em segundo plano, a partir da próxima vez que você iniciar o app';
}

// Path: extensionService
class _Translations$extensionService$pt_BR extends Translations$extensionService$pt {
	_Translations$extensionService$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'O ambiente de extensões não está pronto.';
	@override String testFailed({required Object error}) => 'O teste falhou: ${error}';
	@override String connectedAs({required Object identity}) => 'Conectado como ${identity}';
	@override String get invalidFieldConfiguration => 'Configuração de campo inválida';
	@override String get invalidValue => 'Valor inválido';
	@override String validationError({required Object error}) => 'Erro de validação: ${error}';
	@override String actionFailed({required Object error}) => 'A ação falhou: ${error}';
	@override String get commandFailed => 'O comando não pôde ser executado';
	@override String get reportUnavailable => 'Não é possível enviar relatos agora';
	@override String get stashUnavailable => 'O armazenamento de arquivos do Ham2K está inacessível agora';
	@override String timersSuspendedBudget({required Object name}) => '${name} gastou tempo demais nos seus timers. Eles estão parados até as extensões reiniciarem.';
	@override String timersSuspendedFailures({required Object name}) => 'Os timers de ${name} continuaram falhando. Eles estão parados até as extensões reiniciarem.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} travou em um timer. Os timers dela estão parados até as extensões reiniciarem.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$pt_BR extends Translations$operationLocationScreen$pt {
	_Translations$operationLocationScreen$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Local da operação';
	@override String get selectedLocation => 'Local selecionado';
	@override String get gridSquare => 'Grid Square';
	@override String get gridInvalid => 'Precisa ter 4, 6, 8 ou 10 caracteres, como FN31pr';
	@override String get suggestedLocations => 'Locais sugeridos';
	@override String get deviceGps => 'GPS do dispositivo';
	@override String peerGps({required Object device}) => 'GPS de ${device}';
	@override String get locating => 'Localizando…';
	@override String get gpsUnavailable => 'Localização indisponível';
	@override String get permissionDenied => 'Permissão de localização negada';
	@override String get permissionBlocked => 'Permissão de localização bloqueada';
	@override String get moreDetails => 'Mais detalhes';
	@override String get stateOrProvince => 'Estado ou província (opcional)';
	@override String get controlsUnavailableTitle => 'Controles da atividade indisponíveis';
	@override String get controlsUnavailableReason => 'Estas referências continuam utilizáveis; apenas não foi possível acessar as atividades delas.';
	@override String get controlsUnavailableRetry => 'Tentar novamente';
	@override String get county => 'Condado (opcional)';
}

// Path: versionLabel
class _Translations$versionLabel$pt_BR extends Translations$versionLabel$pt {
	_Translations$versionLabel$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versão ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$pt_BR extends Translations$notices$pt {
	_Translations$notices$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Nenhum aviso ainda';
	@override String get webStorageInMemory => 'Este navegador não conseguiu fornecer armazenamento persistente — o log fica apenas na memória e será PERDIDO quando esta aba for fechada. Use uma versão atual do Chrome, Firefox, Safari ou Edge.';
	@override String get webStorageUnreliable => 'Este navegador está usando um armazenamento alternativo que não é seguro com várias abas — mantenha uma única aba aberta e deixe a sincronização ligada.';
	@override String get logFromNewerBuildTitle => 'Este log precisa de uma versão mais nova';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Seu log foi gravado por uma versão mais nova do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), então não pode ser aberto, e novos contatos não serão salvos. Instale a versão mais nova novamente — ou, se você pretendia rodar esta build, aponte-a para outra pasta de dados. O log está em ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Seu log foi gravado por uma versão mais nova do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), então não pode ser aberto, e novos contatos não serão salvos. Abra este log com essa versão mais nova.';
	@override String get preferencesRestoredTitle => 'Configurações restauradas de um backup';
	@override String get preferencesRestored => 'Não foi possível ler o arquivo de configurações, então o HaLo restaurou a última cópia boa dele. O que você alterou na sessão anterior pode precisar ser definido novamente. O arquivo ilegível é mantido ao lado, com o nome shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Configurações redefinidas';
	@override String get preferencesReset => 'Não foi possível ler o arquivo de configurações e não havia backup para recorrer, então o HaLo começou com os padrões. O arquivo ilegível é mantido na pasta de dados do app, com o nome shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} não foi conectado automaticamente';
	@override String autoConnectHeld({required Object name}) => 'O HaLo parou de responder na última vez que começou a se conectar a ${name}, então desta vez não tentou, para não arriscar que aconteça de novo. Verifique se o rádio está ligado e o cabo conectado, depois pressione Conectar nele nas Configurações.';
}

// Path: syncAccount
class _Translations$syncAccount$pt_BR extends Translations$syncAccount$pt {
	_Translations$syncAccount$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Conta anônima (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (confirmação pendente)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (confirmação pendente - #${id})';
}

// Path: deepLink
class _Translations$deepLink$pt_BR extends Translations$deepLink$pt {
	_Translations$deepLink$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Inicie uma operação primeiro e depois envie esse contato novamente';
	@override String get waitingInOperation => 'Esse contato está aguardando na operação por trás desta tela';
	@override String unknownActivities({required Object refs}) => 'Este dispositivo não tem atividade para ${refs}, então essas referências ficaram de fora';
	@override String activitiesUnavailable({required Object refs}) => 'Não foi possível acessar suas atividades, então ${refs} ficou de fora — tente o link novamente';
}

// Path: confirmDevice
class _Translations$confirmDevice$pt_BR extends Translations$confirmDevice$pt {
	_Translations$confirmDevice$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirmar um dispositivo';
	@override String get codePrompt => 'Insira o código mostrado no dispositivo que quer entrar nesta conta.';
	@override String get code => 'Código';
	@override String get lookUp => 'Consultar';
	@override String get codeNotFound => 'Nenhuma solicitação corresponde a esse código. Os códigos expiram após 10 minutos — peça um novo ao outro dispositivo.';
	@override String get linkExpired => 'Esse link expirou. Peça ao outro dispositivo para mostrar um novo código QR.';
	@override String areYouSure({required Object device}) => 'Vincular ${device} a esta conta?';
	@override String get unnamedDevice => 'um dispositivo sem nome';
	@override String get grantWarning => 'Ele poderá ler e alterar todas as operações e QSOs desta conta.';
	@override String get needsSyncTitle => 'Este dispositivo ainda não sincroniza';
	@override String get needsSyncText => 'Ative a sincronização do Ham2K Log Filer e vincule este dispositivo a uma conta antes que ele possa admitir outro.';
	@override String get malformedRequest => 'O servidor de sincronização enviou uma solicitação que este app não conseguiu ler. Peça ao outro dispositivo para tentar novamente.';
	@override String get linkIt => 'Vincular dispositivo';
}

// Path: switchAccounts
class _Translations$switchAccounts$pt_BR extends Translations$switchAccounts$pt {
	_Translations$switchAccounts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Nenhum detalhe da conta ainda';
	@override String get currentAccount => 'Conta atual';
	@override String get otherAccounts => 'Outras contas';
	@override String get linkToAnother => 'Vincular a outra conta';
	@override String get linkWithSibling => 'Vincular com outro app Ham2K';
	@override String get linkWithPolo => 'Vincular com a conta da versão antiga';
	@override String get linkWithSiblingDescription => 'Você tem outro app Ham2K instalado. Vincule com a conta usada nele.';
	@override String siblingPrompt({required Object app}) => 'Aprove a solicitação no ${app} e depois volte aqui.';
	@override String openSiblingAgain({required Object app}) => 'Abrir ${app} novamente';
	@override String get siblingNoGrant => 'Não funcionou? Abra-o novamente ou volte e vincule de outra forma.';
	@override String siblingOpenFailed({required Object app}) => 'Não foi possível abrir ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'O link expirou e um novo está pronto — abra ${app} novamente.';
	@override String get tryAgain => 'Tentar novamente';
	@override String get linkWithQr => 'Vincular com um código QR';
	@override String get linkWithQrDescription => 'Escaneie-o de um dispositivo que já usa a conta';
	@override String get linkWithEmail => 'Vincular com um endereço de e-mail';
	@override String get linkWithEmailDescription => 'Confirme com um código ou um link por e-mail';
	@override String get enterEmailPrompt => 'Insira o endereço de e-mail da conta que você quer que este dispositivo use.';
	@override String get emailAddress => 'Endereço de e-mail';
	@override String get linkAccount => 'Vincular conta';
	@override String get copiedCode => 'Código copiado para a área de transferência';
	@override String get copyCode => 'Copiar código';
	@override String codePrompt({required Object email}) => 'Abra o app Ham2K em um dispositivo já vinculado a ${email} e insira este código para aprovar a solicitação:';
	@override String get waitingForConfirmation => 'Aguardando confirmação…';
	@override String get sendEmailInstead => 'Enviar um e-mail de confirmação';
	@override String emailSent({required Object email}) => 'Um e-mail foi enviado para ${email}. Abra-o e confirme a solicitação para vincular este dispositivo.';
	@override String get resendEmail => 'Reenviar e-mail';
	@override String get qrPrompt => 'Escaneie este código QR de um dispositivo já vinculado à conta que você quer — por exemplo, com o Ham2K Portable Logger no seu celular.';
	@override String get serverUnreachable => 'Não foi possível acessar o servidor de sincronização. Tente novamente mais tarde.';
	@override String get emailRequired => 'Insira um endereço de e-mail para vincular.';
	@override String noAccountForEmail({required Object email}) => 'Nenhuma conta encontrada para ${email}.';
	@override String serverRejected({required Object error}) => 'O servidor de sincronização rejeitou a solicitação: ${error}';
	@override String get noLinkCode => 'O servidor de sincronização não retornou um código de vínculo. Tente novamente mais tarde.';
	@override String get noConfirmationCode => 'O servidor de sincronização não enviou um código de confirmação. Tente novamente mais tarde.';
	@override String get switchNotAccepted => 'Essa conta não aceitou a troca. Tente vinculá-la com um endereço de e-mail.';
	@override String get requestFailed => 'Algo deu errado na comunicação com o servidor de sincronização. Tente novamente mais tarde.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} operação',
		other: '${count} operações',
	);
}

// Path: adifImport
class _Translations$adifImport$pt_BR extends Translations$adifImport$pt {
	_Translations$adifImport$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar QSOs de ADIF';
	@override String reading({required Object filename}) => 'Lendo ${filename}…';
	@override String get dropHint => 'Solte um arquivo ADIF para importar';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} QSO neste arquivo',
		other: '${formatted} QSOs neste arquivo',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} já está no seu log',
		other: '${formatted} já estão no seu log',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} será importado',
		other: '${formatted} serão importados',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contato novo',
		other: '${formatted} contatos novos',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} será mesclado com um contato existente',
		other: '${formatted} serão mesclados com contatos existentes',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} não pode ser importado (sem indicativo)',
		other: '${formatted} não podem ser importados (sem indicativo)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} precisa de uma análise mais detalhada',
		other: '${formatted} precisam de uma análise mais detalhada',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Não foi possível recuperar as referências de ${count} contato',
		other: 'Não foi possível recuperar as referências de ${formatted} contatos',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'As referências de ${programs} podem estar incompletas para ${count} contato',
		other: 'As referências de ${programs} podem estar incompletas para ${formatted} contatos',
	);
	@override String get stackingTypesUnknown => 'Contatos combinados podem perder uma referência — as atividades não informaram quais tipos se acumulam. Cancele e tente novamente para evitar isso.';
	@override String get nothingToImport => 'Nada neste arquivo pode ser importado';
	@override String get confirm => 'Importar';
	@override String importing({required Object filename}) => 'Importando ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contato importado de ${filename}',
		other: '${formatted} contatos importados de ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Não foi possível importar ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} não parece ser um arquivo ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Aviso: este ADIF tem QSOs de ${calls}, mas eles serão importados como ${station} se você continuar.';
	@override String get stationCallJoin => ' e ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} não tem data e não pode ser importado',
		other: '${formatted} não têm data e não podem ser importados',
	);
	@override String activationFound({required Object refs}) => 'Este arquivo registra uma ativação de ${refs}.';
	@override String get addActivation => 'Adicioná-la a esta operação';
	@override String shortfall({required Object written, required Object planned}) => 'Apenas ${written} de ${planned} puderam ser aplicados — o log mudou enquanto você decidia.';
	@override String get busy => 'Uma importação já está em andamento. Aguarde terminar antes de iniciar outra.';
	@override String get oneFileOnly => 'Solte um arquivo ADIF por vez — a ordem de importação dos arquivos decide quais dados prevalecem.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} tem mais de ${limit} QSOs, o máximo que uma operação pode importar de uma vez.';
}

// Path: offline
class _Translations$offline$pt_BR extends Translations$offline$pt {
	_Translations$offline$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: conectada';
	@override String get noRoute => 'Nenhuma conexão de rede.';
	@override String get unreachable => 'A rede está ativa, mas nenhum servidor responde — muitas vezes sinal de uma página de login esperando em um navegador.';
	@override String get reachable => 'Todos os serviços respondendo normalmente.';
	@override String get whatStops => 'Consultas, spots e arquivos de dados estão pausados. O registro e a sincronização com dispositivos próximos, não.';
	@override String get servicesTitle => 'Serviços';
	@override String get noServices => 'Nenhum serviço se manifestou ainda.';
	@override String lastSuccess({required Object when}) => 'Respondeu pela última vez há ${when}';
	@override String get neverSucceeded => 'Ainda não respondeu';
	@override String nextAttempt({required Object when}) => 'Próxima tentativa em ${when}';
	@override String get nextAttemptNow => 'Próxima tentativa pendente';
	@override String get retry => 'Tentar agora';
	@override String get retrying => 'Tentando…';
	@override String get retryReached => 'Online novamente.';
	@override String get retryUnreachable => 'Ainda sem resposta.';
	@override String get retryNotAttempted => 'Nada para enviar agora.';
	@override String get retryThrottled => 'Acabou de tentar — aguarde um momento.';
	@override String get retryDisabled => 'A sincronização está desligada, então não há com o que testar.';
	@override String get syncService => 'Sincronização Ham2K LoFi';
	@override String get retryInFlight => 'Já está tentando — aguarde.';
}

// Path: exportSettings
class _Translations$exportSettings$pt_BR extends Translations$exportSettings$pt {
	_Translations$exportSettings$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Configurações base para todas as exportações, com modelos separados de nome de arquivo e título para atividades de referência e outras atividades. Cada tipo de exportação pode fornecer seus próprios padrões ou configurações personalizadas.';
	@override String get referenceActivities => 'Atividades de referência';
	@override String get otherActivities => 'Outras atividades';
	@override String get adifFields => 'Campos ADIF';
	@override String get loadFailed => 'Não foi possível carregar as configurações de exportação.';
	@override String get retry => 'Tentar novamente';
	@override String get compactFileNamesDescriptionOn => 'Nomes de arquivo compactos, como N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Nomes de arquivo descritivos, como 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Incluindo nomes, endereços, e-mails, notas e localizações precisas nos arquivos ADIF.';
	@override String get includePrivateDataDescriptionOff => 'Omitindo nomes, endereços, e-mails e notas; limitando localizações a grids de seis caracteres.';
	@override String get includeLookupDataDescriptionOn => 'Incluindo informações de serviços de consulta de indicativos.';
	@override String get includeLookupDataDescriptionOff => 'Omitindo informações de serviços de consulta de indicativos; mantendo os valores inseridos manualmente.';
	@override String get customTemplatesDescriptionOn => 'Seus modelos personalizados estão ativos e podem ser editados abaixo.';
	@override String get customTemplatesDescriptionOff => 'Os modelos padrão estão ativos. Seus modelos personalizados ficam guardados para depois.';
	@override String get type => 'Tipo de exportação';
	@override String get defaults => 'Padrões';
	@override String get includeLookupData => 'Incluir dados de consulta';
	@override String get customTemplates => 'Modelos personalizados';
	@override String get filenameTemplate => 'Modelo de nome de arquivo';
	@override String get compactFilenameTemplate => 'Modelo de nome de arquivo compacto';
	@override String get titleTemplate => 'Modelo de título';
	@override String get adifNotesTemplate => 'Notas QSO ADIF';
	@override String get adifCommentTemplate => 'Comentários QSO ADIF';
	@override String get adifQslMessageTemplate => 'Mensagem QSL ADIF';
	@override String get shared => 'As configurações valem para todas as extensões que usam este tipo de exportação.';
	@override String get defaultTemplates => 'Ative Modelos personalizados para editar os modelos deste tipo.';
}

// Path: templateEditor
class _Translations$templateEditor$pt_BR extends Translations$templateEditor$pt {
	_Translations$templateEditor$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Pré-visualização:';
	@override String get reset => 'Redefinir';
	@override String get docs => 'Documentação de modelos';
	@override String get preview => 'Pré-visualização de exemplo';
	@override String get reference => 'Referência de modelos';
	@override String get attributes => 'Atributos disponíveis';
	@override String get filters => 'Filtros';
	@override String get flowControl => 'Controle de fluxo';
	@override String get unavailable => 'A pré-visualização fica indisponível até as extensões estarem prontas.';
	@override String get empty => '(saída vazia)';
}

// Path: home.nav
class _Translations$home$nav$pt_BR extends Translations$home$nav$pt {
	_Translations$home$nav$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operações';
	@override String get chase => 'Caça';
	@override String get logs => 'Logs';
	@override String get maps => 'Mapas';
	@override String get settings => 'Configurações';
}

// Path: home.panels
class _Translations$home$panels$pt_BR extends Translations$home$panels$pt {
	_Translations$home$panels$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Lista de operações';
	@override String get operationsDescription => 'Suas operações, as mais recentes primeiro.';
	@override String get version => 'Versão atual';
	@override String get versionDescription => 'A marca Ham2K, o nome deste app e qual build você está usando.';
}

// Path: home.logs
class _Translations$home$logs$pt_BR extends Translations$home$logs$pt {
	_Translations$home$logs$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logs';
	@override String get titleFor => 'Logs de';
	@override String get emptyCallsigns => 'Nenhum QSO registrado ainda';
	@override String emptyQsos({required Object call}) => 'Nenhum QSO de ${call}';
	@override String get mapNoSelection => 'Selecione um QSO para vê-lo no mapa';
	@override String get searchHint => 'Buscar indicativo ou nome';
	@override String get noSearchMatches => 'Nenhum QSO corresponde à sua busca';
	@override String get titleAll => 'Todos os logs';
	@override String get allCallsigns => 'Todos os indicativos';
	@override String get noOperation => 'Fora de uma operação';
	@override String get unsavedTitle => 'Alterações não salvas';
	@override String get unsavedBody => 'Este QSO tem alterações que você não salvou.';
	@override String get pendingDeleteBody => 'Este QSO está marcado para exclusão.';
	@override String get editGone => 'Não salvo: esse QSO não está mais neste log.';
	@override String get discard => 'Descartar';
	@override late final _Translations$home$logs$columns$pt_BR columns = _Translations$home$logs$columns$pt_BR._(_root);
	@override late final _Translations$home$logs$panels$pt_BR panels = _Translations$home$logs$panels$pt_BR._(_root);
	@override late final _Translations$home$logs$import$pt_BR import = _Translations$home$logs$import$pt_BR._(_root);
}

// Path: chase.station
class _Translations$chase$station$pt_BR extends Translations$chase$station$pt {
	_Translations$chase$station$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estação de caça';
	@override String get stationLabel => 'Estação: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Sem localização';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$pt_BR extends Translations$chase$periodInline$pt {
	_Translations$chase$periodInline$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get today => 'hoje';
	@override String get thisWeek => 'esta semana';
	@override String get last14Days => 'nos últimos 14 dias';
	@override String get thisMonth => 'este mês';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$pt_BR extends Translations$chase$periodStats$pt {
	_Translations$chase$periodStats$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Estatísticas de hoje';
	@override String get thisWeek => 'Estatísticas desta semana';
	@override String get last14Days => 'Estatísticas dos últimos 14 dias';
	@override String get thisMonth => 'Estatísticas deste mês';
}

// Path: chase.period
class _Translations$chase$period$pt_BR extends Translations$chase$period$pt {
	_Translations$chase$period$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Hoje';
	@override String get thisWeek => 'Esta semana';
	@override String get last14Days => 'Últimos 14 dias';
	@override String get thisMonth => 'Este mês';
}

// Path: chase.goals
class _Translations$chase$goals$pt_BR extends Translations$chase$goals$pt {
	_Translations$chase$goals$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Metas de caça';
	@override String remove({required Object name}) => 'Parar de caçar ${name}';
	@override String get extensionsTitle => 'Extensões que incluem caça';
}

// Path: chase.panels
class _Translations$chase$panels$pt_BR extends Translations$chase$panels$pt {
	_Translations$chase$panels$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Controles de registro acima dos QSOs caçados no período.';
	@override String get info => 'Informações';
	@override String get infoDescription => 'O indicativo sendo registrado ou as estatísticas do período.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Estações com spot no ar, prontas para caçar.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Os QSOs do período e a estação sendo registrada.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$pt_BR extends Translations$dialogs$callChange$pt {
	_Translations$dialogs$callChange$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicativo inválido: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicativos inválidos: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} operou até agora. ${typed} será registrado para novos contatos.';
	@override String operatorNoneSoFar({required Object typed}) => 'Nenhum operador registrado até agora. ${typed} será registrado para novos contatos.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Esta operação já tem contatos de ${calls}. ${typed} só será registrado para os novos.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Registrar também ${typed} como operador do contato já registrado',
		other: 'Registrar também ${typed} como operador de todos os ${count} contatos já registrados',
	);
	@override String get operatorSeveralStations => 'Ao usar várias estações no ar, não há suporte para operadores separados';
	@override String get contactsUnreadable => 'Não foi possível ler os contatos desta operação, então alterar um indicativo aqui não oferecerá atualizá-los';
	@override String restampFailed({required Object error}) => 'Não foi possível atualizar os contatos já registrados, então nenhuma alteração foi feita: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} de ${planned} contatos foram atualizados — o restante não está mais nesta operação';
}

// Path: operation.tabs
class _Translations$operation$tabs$pt_BR extends Translations$operation$tabs$pt {
	_Translations$operation$tabs$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'MAPA';
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Relógio';
	@override String get weather => 'Clima';
	@override String get website => 'Site';
	@override String get remoteScreen => 'Tela remota';
	@override String get solar => 'Solar';
	@override String get radio => 'Rádio';
}

// Path: operation.positions
class _Translations$operation$positions$pt_BR extends Translations$operation$positions$pt {
	_Translations$operation$positions$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Nenhuma outra posição de operação está compartilhando esta operação ainda.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Outra posição';
	@override String get thisDevice => 'Nossa posição de operação';
	@override String get nameIn => ' em ';
	@override String get panelTitle => 'Posições';
	@override String get panelDescription => 'O que cada posição de operação que compartilha esta operação está registrando agora.';
}

// Path: operation.menu
class _Translations$operation$menu$pt_BR extends Translations$operation$menu$pt {
	_Translations$operation$menu$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostrar campos RST';
	@override String get showStateField => 'Mostrar campo de estado';
	@override String get showGridField => 'Mostrar campo de grid';
	@override String get showDeletedQsos => 'Mostrar QSOs excluídos';
	@override String get showDeletedOps => 'Mostrar operações excluídas';
	@override String get showQsoNumbers => 'Mostrar números dos QSOs';
	@override String get lookupAllQsos => 'Consultar todos os QSOs';
	@override String get loggingSettingsTitle => 'Configurações de registro';
	@override String get mapSettingsTitle => 'Configurações do mapa';
	@override String get actionsSection => 'Ações';
}

// Path: operation.layout
class _Translations$operation$layout$pt_BR extends Translations$operation$layout$pt {
	_Translations$operation$layout$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Adicionar um painel';
	@override String get availableSection => 'Painéis disponíveis';
	@override String panelSettings({required Object panel}) => 'Configurações de ${panel}';
	@override String get panelSettingsAction => 'Configurações do painel';
	@override String get viewName => 'Visualização da operação';
	@override String get viewOptions => 'Opções de layout da visualização';
	@override String get viewTitleBuiltIn => 'Esta visualização é integrada ao app, assim como o nome dela';
	@override String get resetOptions => 'Restaurar padrões';
	@override String get removePane => 'Remover';
	@override String resetPaneConfirm({required Object panel}) => 'Restaurar ${panel} aos padrões?';
	@override String get resetPaneConfirmBody => 'O título, o cabeçalho e o tamanho voltam aos padrões. O resto do layout fica como está.';
	@override String get resetViewConfirm => 'Restaurar esta visualização ao layout padrão?';
	@override String get resetViewConfirmBody => 'Os painéis voltam à disposição padrão, e as opções da visualização e de cada painel voltam aos padrões.';
	@override String paneOptionsTitle({required Object panel}) => 'Configurações de layout de ${panel}';
	@override String get paneTitle => 'Título';
	@override String get paneShowHeader => 'Mostrar cabeçalho';
	@override String get paneShowHeaderTabset => 'Sempre visível enquanto este painel compartilha um grupo — o cabeçalho é o acesso aos outros';
	@override String get paneInherit => 'Igual ao app';
	@override String get searchHint => 'Buscar painéis';
	@override String get noPanelsMatch => 'Nenhum painel corresponde à sua busca.';
	@override String get nothingToAdd => 'Esta visualização já tem todos os painéis possíveis';
	@override String addPanel({required Object panel}) => 'Adicionar ${panel}';
	@override String showPreview({required Object panel}) => 'Pré-visualizar ${panel}';
	@override String missingExtension({required Object name}) => 'A extensão "${name}" está faltando';
	@override String get previewUnavailable => 'Não foi possível mostrar a imagem de pré-visualização deste painel.';
	@override String get nestedPaneTitle => 'Mais';
	@override String get editLayout => 'Editar layout';
	@override String get saveLayout => 'Salvar layout';
	@override String get revertLayout => 'Descartar alterações do layout';
	@override String get done => 'Concluído';
	@override String get layoutUnreadableTitle => 'Não foi possível ler o layout';
	@override String get layoutUnreadableBody => 'Não foi possível ler seu layout salvo, então a disposição padrão está sendo mostrada. Ela não substituirá o original até você escolher mantê-la.';
	@override String get layoutUnreadableAction => 'Usar este layout';
	@override String panelRenderFailed({required Object panel}) => 'Não foi possível exibir ${panel}';
	@override String get panelRenderRetry => 'Tentar novamente';
	@override String get panelActionFailed => 'A ação do painel falhou. Tente novamente.';
	@override late final _Translations$operation$layout$panels$pt_BR panels = _Translations$operation$layout$panels$pt_BR._(_root);
	@override String get htmlPanelUnsupported => 'Este painel precisa de uma web view, que esta plataforma não oferece';
	@override String get htmlPanelUnsupportedOnWeb => 'Este painel precisa de um sandbox que a versão web não oferece';
}

// Path: operation.export
class _Translations$operation$export$pt_BR extends Translations$operation$export$pt {
	_Translations$operation$export$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportações da operação';
	@override String get syncedOperation => 'A operação está sincronizada';
	@override String get unsyncedOperation => 'A operação tem alterações não sincronizadas';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} QSO nesta operação',
		other: '${count} QSOs nesta operação',
	);
	@override String qsosSynced({required Object total}) => 'Todos os ${total} QSOs estão sincronizados';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} de ${total} QSOs com sincronização pendente';
	@override String eventsSynced({required Object total}) => '${total} marcadores de evento sincronizados';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendentes';
	@override String get loading => 'Carregando opções de exportação…';
	@override String get noOptions => 'Nenhum formato de exportação disponível (as extensões ainda estão iniciando?)';
	@override String get nothingLogged => 'Nada para exportar ainda — esta operação não tem QSOs.';
	@override String get share => 'Compartilhar';
	@override String get nothingSelected => 'Nada selecionado';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Salvar ${count} arquivo',
		other: 'Salvar ${count} arquivos',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Compartilhar ${count} arquivo',
		other: 'Compartilhar ${count} arquivos',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Exportar ${count} arquivo',
		other: 'Exportar ${count} arquivos',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Baixar ${count} arquivo',
		other: 'Baixar ${count} arquivos',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Salvar ${count} arquivo combinado',
		other: 'Salvar ${count} arquivos combinados',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Compartilhar ${count} arquivo combinado',
		other: 'Compartilhar ${count} arquivos combinados',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Exportar ${count} arquivo combinado',
		other: 'Exportar ${count} arquivos combinados',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Baixar ${count} arquivo combinado',
		other: 'Baixar ${count} arquivos combinados',
	);
	@override String saveOne({required Object name}) => 'Salvar ${name}';
	@override String shareOne({required Object name}) => 'Compartilhar ${name}';
	@override String exportOne({required Object name}) => 'Exportar ${name}';
	@override String downloadOne({required Object name}) => 'Baixar ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Armazenar ${count} arquivo',
		other: 'Armazenar ${count} arquivos',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Armazenar ${count} arquivo combinado',
		other: 'Armazenar ${count} arquivos combinados',
	);
	@override String get settingsButton => 'Configurações de exportação';
	@override String get settingsTitle => 'Configurações de exportação';
	@override late final _Translations$operation$export$compactFileNames$pt_BR compactFileNames = _Translations$operation$export$compactFileNames$pt_BR._(_root);
	@override late final _Translations$operation$export$includePrivateData$pt_BR includePrivateData = _Translations$operation$export$includePrivateData$pt_BR._(_root);
	@override String get resultTitle => 'Exportação concluída';
	@override String get resultFailedTitle => 'A exportação falhou';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} arquivo exportado para ${path}',
		other: '${count} arquivos exportados para ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} arquivo exportado: ${path}',
		other: '${count} arquivos exportados: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} arquivo compartilhado',
		other: '${count} arquivos compartilhados',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} arquivo baixado',
		other: '${count} arquivos baixados',
	);
	@override String exportFailed({required Object error}) => 'A exportação falhou: ${error}';
	@override late final _Translations$operation$export$stash$pt_BR stash = _Translations$operation$export$stash$pt_BR._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$pt_BR extends Translations$operation$spots$pt {
	_Translations$operation$spots$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nenhum spot corresponde aos seus filtros';
	@override String error({required Object error}) => 'Falha ao carregar spots: ${error}';
	@override String get unknownBand => 'Outra';
	@override String get auto => 'Automático';
	@override String autoValue({required Object value}) => 'Automático (atual ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Qualquer';
	@override String get allBands => 'Todas as bandas';
	@override String get allModes => 'Todos os modos';
	@override String get phoneAndCw => 'Fonia e CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutos';
	@override String get callsOfNote => 'Indicativos com notas';
	@override String get yourSpots => 'Seus spots';
	@override String get allSpots => 'Todos os spots';
	@override late final _Translations$operation$spots$continents$pt_BR continents = _Translations$operation$spots$continents$pt_BR._(_root);
	@override late final _Translations$operation$spots$filters$pt_BR filters = _Translations$operation$spots$filters$pt_BR._(_root);
	@override String get unavailableTitle => 'Spots indisponíveis';
	@override String unavailableText({required Object sources}) => '${sources} não respondeu.';
	@override String get failedTitle => 'Erro na origem de spots';
	@override String failedText({required Object sources}) => '${sources} retornou um erro.';
	@override String get slideLogIt => 'Registrar';
	@override String get slideIgnore => 'Ignorar';
	@override String get slideRestore => 'Restaurar';
	@override late final _Translations$operation$spots$logConflict$pt_BR logConflict = _Translations$operation$spots$logConflict$pt_BR._(_root);
}

// Path: operation.import
class _Translations$operation$import$pt_BR extends Translations$operation$import$pt {
	_Translations$operation$import$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar dados para a operação';
	@override String get importAdifAction => 'Importar QSOs de ADIF';
	@override String get settingsButton => 'Configurações de escuta';
	@override String get settingsTitle => 'Escutar outros apps';
	@override String get protocolAddressLabel => 'Endereço';
	@override String get protocolPortLabel => 'Porta';
	@override String get protocolPortInvalid => 'Insira uma porta entre 1 e 65535';
	@override String get protocolAddressInvalid => 'Insira um endereço IP válido (ex. 127.0.0.1 ou 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Recebendo dados';
	@override String get protocolStatusNoData => 'Nenhum dado recebido recentemente';
	@override String protocolBindError({required Object error}) => 'Não foi possível começar a escutar: ${error}';
	@override String captureFailed({required Object error}) => 'Não foi possível salvar os QSOs recebidos; tentando novamente: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Qualquer (broadcast)';
	@override String get wsjtxProtocolName => 'Servidor UDP do WSJT-X';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → aba Broadcast Data → marque "Enable Broadcasts" para as informações de contato. Defina o endereço IP como 127.0.0.1 se estiver rodando neste mesmo computador, ou 255.255.255.255 para transmitir na rede local atual.';
	@override String get helpWsjtxSetup => 'File → Settings → aba Reporting → seção UDP Server → marque "Accept UDP requests". Defina UDP Server como 127.0.0.1 se estiver rodando neste mesmo computador, ou um endereço multicast como 239.239.0.2, e use o mesmo endereço na configuração acima neste app.';
	@override String get listenTitle => 'Escutar QSOs de outros apps';
	@override String get listenDescriptionOnN1mm => 'Escutando o N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Escutando o WSJT-X';
	@override String get listenDescriptionOnBoth => 'Escutando o N1MM+ e o WSJT-X';
	@override String get listenDescriptionOff => 'Desligado';
	@override String get addToOperationTitle => 'Adicionar a esta operação';
	@override String get addToOperationDescriptionOn => 'Os QSOs capturados são adicionados a esta operação conforme chegam';
	@override String get addToOperationDescriptionOff => 'Os QSOs capturados ficam retidos até você ativar isto';
	@override String get pendingSectionTitle => 'QSOs capturados';
	@override String get pendingEmpty => 'Nada capturado ainda';
	@override String stationMismatch({required Object call}) => 'Registrado como ${call}, não a estação desta operação';
	@override String get discardAction => 'Descartar';
	@override String get gapDialogTitle => 'Incluir capturas anteriores?';
	@override String gapDialogBody({required Object count}) => 'Mais ${count} QSOs foram capturados antes, antes de uma lacuna nos dados. Incluí-los também?';
	@override String get gapDialogRecentOnly => 'Só os recentes';
	@override String gapDialogIncludeAll({required Object count}) => 'Incluir todos os ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$pt_BR extends Translations$map$outlineIssue$pt {
	_Translations$map$outlineIssue$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problemas?';
	@override String get title => 'Relatar um problema no contorno';
	@override String get reference => 'Qual contorno';
	@override String get severity => 'Qual a gravidade?';
	@override String get minor => 'Detalhe pequeno';
	@override String get major => 'Problema grave';
	@override String get explanation => 'O que está errado?';
	@override String get explanationHint => 'O que o contorno erra, e onde';
	@override String get send => 'Enviar';
	@override String get sending => 'Enviando seu relato — obrigado';
	@override String get copy => 'Copiar relato';
	@override String get notSent => 'Não foi possível enviar o relato';
	@override String get copied => 'Relato copiado';
	@override String get notCopied => 'Não foi possível copiar o relato';
}

// Path: map.postcard
class _Translations$map$postcard$pt_BR extends Translations$map$postcard$pt {
	_Translations$map$postcard$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get button => 'Cartão-postal da operação';
	@override String title({required Object title}) => 'Cartão-postal de ${title}';
	@override String get portrait => 'Retrato';
	@override String get landscape => 'Paisagem';
	@override String get square => 'Quadrado';
	@override String get save => 'Salvar…';
	@override String get download => 'Baixar';
	@override String get share => 'Compartilhar';
	@override String get copy => 'Copiar';
	@override String get copied => 'Copiado para a área de transferência';
	@override String saved({required Object path}) => 'Salvo em ${path}';
	@override String downloaded({required Object name}) => '${name} baixado';
	@override String savedMany({required Object count, required Object path}) => '${count} imagens salvas em ${path}';
	@override String savedFiles({required Object names}) => '${names} salvos';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} já tinham sido salvos';
	@override String downloadedMany({required Object count}) => 'Baixando ${count} imagens — permita se o navegador pedir';
	@override String get mapLeftOut => 'O mapa não carregou, então ficou de fora';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — o mapa não carregou, então ficou de fora';
	@override String continued({required Object title}) => '${title} (continuação)';
	@override String get previousPage => 'Página anterior';
	@override String get nextPage => 'Próxima página';
	@override String pageOf({required Object page, required Object count}) => 'Página ${page} de ${count}';
	@override String get sectionDays => 'Cada dia';
	@override String get reset => 'Redefinir';
	@override String failed({required Object error}) => 'Não foi possível criar o cartão-postal: ${error}';
	@override String get mapNotReady => 'O mapa não terminou de carregar. Verifique a conexão e tente novamente.';
	@override String saveFailed({required Object error}) => 'Não foi possível salvar o cartão-postal: ${error}';
	@override String get copyFailed => 'A área de transferência não aceitou a imagem. Tente novamente.';
	@override String get shareFailed => 'Não foi possível compartilhar o cartão-postal. Tente novamente.';
	@override String get fileName => 'cartao-postal';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$pt_BR extends Translations$loggingControls$info$pt {
	_Translations$loggingControls$info$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Nenhum QSO ainda... vamos para o ar!';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} em ${time}';
	@override String sinceLast({required Object time}) => '${time} desde o último';
	@override String ratePer10({required Object rate}) => '${rate} Q/h nos últimos 10';
	@override String ratePer100({required Object rate}) => '${rate} Q/h nos últimos 100';
	@override String distanceTo({required Object distance}) => '${distance} até';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) até';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) até';
	@override String distanceAway({required Object distance}) => '${distance} de distância';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distância';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distância';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer}: ${notice}';
	@override String get noticeDupe => 'Duplicado!';
	@override String get noticeNewBand => 'Nova banda';
	@override String get noticeNewMode => 'Novo modo';
	@override String get noticeNewDXCC => 'Novo DXCC';
	@override String get noticeNewState => 'Novo estado';
	@override String get noticeNewProvince => 'Nova província';
	@override String get noticeNewDay => 'Novo dia';
	@override String get noticeNewRef => 'Nova ref';
	@override String get noticeNewMult => 'Novo mult';
	@override String get noticeNewZone => 'Nova zona';
	@override String get noticeInvalidMode => 'Modo errado';
	@override String get noticeInvalidBand => 'Banda errada';
	@override String get noticeInvalidCategory => 'Não contatável';
	@override String get noticeWorkedBefore => 'Já contatado';
	@override String get noticeNewPark => 'Novo parque';
	@override String get noticeNewSection => 'Nova seção';
	@override String get noticeBonusStation => 'Estação bônus!';
	@override String get noticeMissingExchange => 'Sem reporte';
	@override String get noticeInvalidExchange => 'Reporte inválido';
	@override String get noticeUnknownEvent => 'Evento desconhecido';
	@override String get noticeOurGrid => 'Defina nosso grid';
	@override String get noticeRareCounty => 'Condado raro!';
	@override String get noticeOurLocation => 'Defina nosso condado';
	@override String get noticeShortGrid => 'Grid muito curto';
}

// Path: callInfo.history
class _Translations$callInfo$history$pt_BR extends Translations$callInfo$history$pt {
	_Translations$callInfo$history$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} nos últimos 7 dias';
	@override String today({required Object n}) => '${n} hoje';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class _Translations$settings$theme$pt_BR extends Translations$settings$theme$pt {
	_Translations$settings$theme$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo do tema';
	@override String get system => 'Seguir as configurações do sistema';
	@override String get light => 'Claro';
	@override String get dark => 'Escuro';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$pt_BR extends Translations$settings$themeDescription$pt {
	_Translations$settings$themeDescription$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Seguindo as configurações do sistema';
	@override String get light => 'Sempre no modo claro';
	@override String get dark => 'Sempre no modo escuro';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$pt_BR extends Translations$settings$fontScaleOpts$pt {
	_Translations$settings$fontScaleOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Mínimo--';
	@override String get smallestMinus => 'Mínimo-';
	@override String get smallest => 'Mínimo';
	@override String get smaller => 'Menor';
	@override String get normal => 'Normal';
	@override String get larger => 'Maior';
	@override String get largest => 'Máximo';
	@override String get largestPlus => 'Máximo+';
	@override String get largestPlusPlus => 'Máximo++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$pt_BR extends Translations$settings$keepDeviceAwake$pt {
	_Translations$settings$keepDeviceAwake$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Manter dispositivo ativo';
	@override String get descriptionOn => 'Mantendo ativo enquanto você está na tela de registro ou uma sincronização está em andamento';
	@override String get descriptionOff => 'Suspendendo normalmente';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$pt_BR extends Translations$settings$layoutDensityOpts$pt {
	_Translations$settings$layoutDensityOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automática';
	@override String get densest => 'Máxima';
	@override String get dense => 'Densa';
	@override String get normal => 'Normal';
	@override String get sparse => 'Espaçada';
	@override String get sparsest => 'Mais espaçada';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$pt_BR extends Translations$settings$distanceUnitsOpts$pt {
	_Translations$settings$distanceUnitsOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Quilômetros';
	@override String get miles => 'Milhas';
}

// Path: settings.logging
class _Translations$settings$logging$pt_BR extends Translations$settings$logging$pt {
	_Translations$settings$logging$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registro';
	@override late final _Translations$settings$logging$leftieMode$pt_BR leftieMode = _Translations$settings$logging$leftieMode$pt_BR._(_root);
	@override late final _Translations$settings$logging$countryFlags$pt_BR countryFlags = _Translations$settings$logging$countryFlags$pt_BR._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$pt_BR countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$pt_BR._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$pt_BR suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$pt_BR._(_root);
	@override late final _Translations$settings$logging$showBearing$pt_BR showBearing = _Translations$settings$logging$showBearing$pt_BR._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$pt_BR showReverseBearing = _Translations$settings$logging$showReverseBearing$pt_BR._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$pt_BR switchSentRcvd = _Translations$settings$logging$switchSentRcvd$pt_BR._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$pt_BR jumpAfterRST = _Translations$settings$logging$jumpAfterRST$pt_BR._(_root);
	@override late final _Translations$settings$logging$defaultReport$pt_BR defaultReport = _Translations$settings$logging$defaultReport$pt_BR._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$pt_BR defaultReportCW = _Translations$settings$logging$defaultReportCW$pt_BR._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$pt_BR defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$pt_BR._(_root);
	@override late final _Translations$settings$logging$numbersRow$pt_BR numbersRow = _Translations$settings$logging$numbersRow$pt_BR._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$pt_BR numbersRowExtra = _Translations$settings$logging$numbersRowExtra$pt_BR._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$pt_BR numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$pt_BR._(_root);
	@override String get bands => 'Bandas preferidas';
	@override String get modes => 'Modos preferidos';
}

// Path: settings.catServer
class _Translations$settings$catServer$pt_BR extends Translations$settings$catServer$pt {
	_Translations$settings$catServer$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor CAT';
	@override String get description => 'Permite que outros apps (WSJT-X, programas de log etc.) controlem o rádio através do Ham2K Logger.';
	@override String get protocol => 'Protocolo';
	@override late final _Translations$settings$catServer$protocolOpts$pt_BR protocolOpts = _Translations$settings$catServer$protocolOpts$pt_BR._(_root);
	@override String get port => 'Porta';
	@override String get openAccess => 'Acesso aberto';
	@override String get openAccessOn => 'Qualquer computador na rede local pode se conectar.';
	@override String get openAccessOff => 'Apenas apps neste computador podem se conectar.';
	@override String get off => 'Desligado.';
	@override String starting({required Object protocol}) => '${protocol}, iniciando…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} na porta ${port}. Clientes conectados: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} na porta ${port}, mas nenhum rádio de VFO principal está conectado.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} não consegue escutar na porta ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: outro programa a está usando, muitas vezes o próprio ${protocol}. Feche esse programa ou escolha outra porta.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: este computador não permite. Escolha uma porta acima de 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} parou de escutar na porta ${port}. Tentando novamente…';
}

// Path: settings.radio
class _Translations$settings$radio$pt_BR extends Translations$settings$radio$pt {
	_Translations$settings$radio$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controle CAT';
	@override String get loggingAndCat => 'Registro e CAT';
	@override String get tuningSection => 'Sintonia';
	@override String get keyerSection => 'Manipulador';
	@override String get servicesSection => 'Serviços';
	@override String get stationConfigurationSection => 'Configuração da estação';
	@override String get moreSettings => 'Mais configurações da estação';
	@override late final _Translations$settings$radio$units$pt_BR units = _Translations$settings$radio$units$pt_BR._(_root);
	@override late final _Translations$settings$radio$pttKey$pt_BR pttKey = _Translations$settings$radio$pttKey$pt_BR._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$pt_BR smartVfoSnap = _Translations$settings$radio$smartVfoSnap$pt_BR._(_root);
	@override late final _Translations$settings$radio$snapDebounce$pt_BR snapDebounce = _Translations$settings$radio$snapDebounce$pt_BR._(_root);
	@override late final _Translations$settings$radio$snapLongMove$pt_BR snapLongMove = _Translations$settings$radio$snapLongMove$pt_BR._(_root);
	@override late final _Translations$settings$radio$snapMinMove$pt_BR snapMinMove = _Translations$settings$radio$snapMinMove$pt_BR._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$pt_BR snapMinSpeed = _Translations$settings$radio$snapMinSpeed$pt_BR._(_root);
	@override late final _Translations$settings$radio$enterSends$pt_BR enterSends = _Translations$settings$radio$enterSends$pt_BR._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$pt_BR keyerSpeed = _Translations$settings$radio$keyerSpeed$pt_BR._(_root);
	@override late final _Translations$settings$radio$cwMessages$pt_BR cwMessages = _Translations$settings$radio$cwMessages$pt_BR._(_root);
	@override late final _Translations$settings$radio$voiceMessages$pt_BR voiceMessages = _Translations$settings$radio$voiceMessages$pt_BR._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$pt_BR avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$pt_BR._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$pt_BR zeroBeatRange = _Translations$settings$radio$zeroBeatRange$pt_BR._(_root);
}

// Path: settings.help
class _Translations$settings$help$pt_BR extends Translations$settings$help$pt {
	_Translations$settings$help$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuda e recursos';
	@override String get description => 'Comunidade e suporte';
	@override String get forums => 'Fóruns Ham2K';
	@override String get forumsDescription => 'Encontre ajuda, dê feedback, discuta ideias…';
	@override String get chat => 'Chat Ham2K';
	@override String get chatDescription => 'O servidor Discord da nossa comunidade online';
	@override String get youtube => 'YouTube Ham2K';
	@override String get youtubeDescription => 'Vídeos e transmissões ao vivo';
	@override String get instagram => 'Instagram Ham2K';
	@override String get instagramDescription => 'Porque você nunca pode ter fotos demais…';
	@override String get bluesky => 'BlueSky Ham2K';
	@override String get blueskyDescription => 'Siga-nos para novidades e atualizações';
	@override String get contact => 'Contate-nos';
	@override String get contactDescription => 'help@ham2k.com — mas tente os Fóruns ou o Chat primeiro!';
}

// Path: settings.exports
class _Translations$settings$exports$pt_BR extends Translations$settings$exports$pt {
	_Translations$settings$exports$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportações';
}

// Path: settings.map
class _Translations$settings$map$pt_BR extends Translations$settings$map$pt {
	_Translations$settings$map$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override late final _Translations$settings$map$style$pt_BR style = _Translations$settings$map$style$pt_BR._(_root);
	@override late final _Translations$settings$map$styleOpts$pt_BR styleOpts = _Translations$settings$map$styleOpts$pt_BR._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$pt_BR extends Translations$settings$privacy$pt {
	_Translations$settings$privacy$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacidade';
	@override late final _Translations$settings$privacy$shareAppData$pt_BR shareAppData = _Translations$settings$privacy$shareAppData$pt_BR._(_root);
	@override late final _Translations$settings$privacy$shareOpData$pt_BR shareOpData = _Translations$settings$privacy$shareOpData$pt_BR._(_root);
	@override String get privacyPolicy => 'Política de privacidade';
	@override String get termsOfService => 'Termos de serviço';
}

// Path: settings.sync
class _Translations$settings$sync$pt_BR extends Translations$settings$sync$pt {
	_Translations$settings$sync$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronização na nuvem';
	@override String get moreSettings => 'Mais configurações de sincronização';
	@override String get enable => 'Habilitar sincronização';
	@override String get deviceKey => 'Chave do dispositivo';
}

// Path: settings.peers
class _Translations$settings$peers$pt_BR extends Translations$settings$peers$pt {
	_Translations$settings$peers$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispositivos pareados';
	@override String get enable => 'Conectar a outros dispositivos';
	@override String get enableDescription => 'Permite compartilhar operações, registro, CAT e GPS com outros dispositivos pela rede local';
	@override String get bleEnable => 'Conectar por Bluetooth';
	@override String get bleDescription => 'Usa Bluetooth LE para conectar mesmo sem rede local';
	@override String get thisDevice => 'Este dispositivo';
	@override String get deviceName => 'Nome';
	@override String get deviceNameHint => 'Como este dispositivo é visto pelos outros dispositivos';
	@override String get pairedDevices => 'Dispositivos vinculados';
	@override String get noPairedDevices => 'Nenhum dispositivo vinculado ainda. Ative isto em outro dispositivo nesta rede para vinculá-los.';
	@override String deviceListProblem({required Object error}) => 'Não foi possível ler seus dispositivos vinculados: ${error}';
	@override String get nearby => 'Próximos';
	@override String get connected => 'Conectado';
	@override String get viaBluetooth => 'via Bluetooth';
	@override String get connecting => 'Conectando…';
	@override String get syncing => 'Sincronizando…';
	@override String get waitingForThem => 'Aguardando o outro dispositivo';
	@override String get notConnected => 'Não conectado';
	@override String get wantsToPair => 'quer compartilhar esta operação';
	@override String get allow => 'Permitir';
	@override String get link => 'Vincular';
	@override String get reject => 'Rejeitar';
	@override String get forget => 'Esquecer';
	@override String forgetTitle({required Object name}) => 'Esquecer ${name}?';
	@override String get forgetBody => 'Ele deixará de sincronizar com este dispositivo. Você pode permiti-lo novamente depois, e os contatos já registrados são mantidos.';
	@override String pairTitle({required Object name}) => 'Vincular com ${name}';
	@override String get pairBody => 'Este dispositivo está na sua rede local e quer se conectar.';
	@override String get pairBodyBle => 'Este dispositivo está por perto e quer se conectar por Bluetooth LE.';
	@override String get pairIdLabel => 'ID do dispositivo';
	@override String get pairWarning => 'Vincule apenas dispositivos que você reconhece. Qualquer dispositivo nesta rede pode enviar uma solicitação.';
	@override String get pairWarningBle => 'Vincule apenas dispositivos que você reconhece. Qualquer dispositivo próximo pode enviar uma solicitação.';
	@override String problem({required Object error}) => 'Não foi possível acessar a rede local: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Conectado a ${device}';
	@override String statusLost({required Object device}) => 'Conexão perdida com ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispositivos pareados: ${connected} de ${linked} conectados';
	@override String get screenEnable => 'Compartilhar telas e janelas';
	@override String get screenDescription => 'Permite que outros dispositivos mostrem telas ou janelas deste computador';
	@override String get screenSources => 'Telas e janelas';
	@override String get screenRefresh => 'Atualizar a lista';
	@override String get screenUnsupportedPlatform => 'Este dispositivo não pode compartilhar a tela. O macOS pode; qualquer dispositivo pode mostrar uma tela compartilhada por outro.';
	@override String get screenUnsupportedVersion => 'Compartilhar uma tela requer macOS 12.3 ou posterior. Este dispositivo ainda pode mostrar uma tela compartilhada por outro.';
	@override String get screenNeedsPermission => 'O macOS precisa da sua permissão para gravar a tela antes que este app possa compartilhar uma.';
	@override String get screenGrantPermission => 'Pedir permissão';
	@override String get screenRelaunchAfterGranting => 'Permita em Ajustes do Sistema, em Privacidade e Segurança → Gravação de Tela, depois feche e reabra este app — o macOS só informa a mudança a um app na próxima vez que ele é aberto.';
	@override String screenProblem({required Object error}) => 'Compartilhamento de tela: ${error}';
	@override String get screenChooseTitle => 'Escolha o que compartilhar';
	@override String get screenChooseButton => 'Escolher o que compartilhar…';
	@override String get screenTabScreens => 'Telas';
	@override String get screenTabApps => 'Apps';
	@override String get screenTabWindows => 'Janelas';
	@override String get screenTabEmpty => 'Nada deste tipo foi encontrado.';
	@override String get screenSharedSummaryNone => 'Nada escolhido ainda.';
	@override String get screenThisDevice => 'Este dispositivo';
	@override String screenSharedTo({required Object devices}) => 'Mostrado em ${devices}';
	@override String get screenSharedToNobody => 'Não está sendo mostrado';
	@override String screenStopSharing({required Object name}) => 'Parar de compartilhar ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$pt_BR extends Translations$settings$syncPanel$pt {
	_Translations$settings$syncPanel$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuração de sincronização';
	@override String get enableTitle => 'Sincronizar com o Ham2K Log Filer';
	@override String get enabledDescription => 'Fazendo backup e sincronizando seu log entre dispositivos';
	@override String get disabledDescription => 'Desligado — fica apenas neste dispositivo';
	@override String get syncing => 'Sincronizando';
	@override String get account => 'Conta';
	@override String get refresh => 'Atualizar';
	@override String get switchAccounts => 'Trocar de conta';
	@override String get switchAccountsDescription => 'Vincule este dispositivo a outra conta com um código QR ou e-mail';
	@override String get connectionRequests => 'Solicitações de conexão';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Um dispositivo está aguardando para entrar nesta conta',
		other: '${n} dispositivos estão aguardando para entrar nesta conta',
	);
	@override String get accountEmailTitle => 'E-mail da conta';
	@override String accountEmailSent({required Object email}) => 'Confirmação enviada para ${email}. Abra o link lá para concluir a alteração.';
	@override String get resendConfirmation => 'Reenviar e-mail de confirmação';
	@override String resendConfirmationDescription({required Object email}) => 'Aguardando ${email}';
	@override String accountEmailResent({required Object email}) => 'Enviado novamente para ${email}.';
	@override String get deviceLinked => 'Esse dispositivo agora está vinculado a esta conta.';
	@override String get checking => 'Verificando…';
	@override String get notLinked => 'Ainda não vinculado';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Substituir dados locais?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} operação',
		other: '${n} operações',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Dados sincronizados';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'Aguardando envio: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Este dispositivo: verificando…';
	@override String get countsServerChecking => 'Servidor: verificando…';
	@override String get countsServerUnavailable => 'Servidor: indisponível';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Isso faz backup e remove ${operations} e ${qsos} deste dispositivo e depois baixa os dados da conta no lugar. O backup fica no banco de dados deste dispositivo.';
	@override String get replace => 'Substituir';
	@override String get pendingBannerTitle => 'Nova conta do Ham2K Log Filer detectada';
	@override String get pendingBannerBody => 'Mantenha as operações e QSOs existentes deste dispositivo e mescle-os na conta, ou substitua-os pelos dados da conta (um backup fica neste dispositivo em ambos os casos).';
	@override String get combine => 'Combinar';
	@override String get authIssueTitle => 'A sincronização não consegue se conectar';
	@override String get authIssueText => 'O Ham2K Log Filer continua rejeitando este dispositivo. Verifique seu indicativo nas configurações de sincronização.';
	@override String get openSettings => 'Abrir configurações de sincronização';
}

// Path: settings.accounts
class _Translations$settings$accounts$pt_BR extends Translations$settings$accounts$pt {
	_Translations$settings$accounts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Contas, serviços e fontes de dados';
	@override String get none => 'Nenhuma extensão ativa com contas';
	@override String get notConfigured => 'Não configurado';
	@override String get connected => 'Conectado';
	@override String get cancelLogin => 'Cancelar login';
	@override String get openInBrowser => 'Abrir no navegador';
	@override String loggedInAs({required Object identity}) => 'Conectado como ${identity}';
	@override String get pressSaveToKeep => 'Pressione Salvar para manter esta conta conectada.';
	@override String connectedTo({required Object label}) => 'Conectado a ${label}';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
	@override String get connectedAs => 'Conectado como';
	@override String get test => 'Testar';
	@override String saveFailed({required Object error}) => 'Falha ao salvar: ${error}';
	@override String loginFailed({required Object error}) => 'Falha no login: ${error}';
	@override String get lookupFailed => 'As contas não estão disponíveis agora — tente novamente em instantes';
	@override String get browserLoginTitle => 'Conclua o login no seu navegador';
	@override String browserLoginSteps({required Object prefix}) => 'Quando terminar, o navegador tentará abrir um link que começa com "${prefix}". Provavelmente nada no seu computador está registrado para abri-lo, então copie esse link (da barra de endereços ou da página de erro que o navegador mostrar) e cole-o aqui.';
	@override String browserLoginNotOpened({required Object prefix}) => 'O Ham2K Logger não conseguiu abrir seu navegador. Copie o link de login abaixo e abra-o você mesmo, depois copie o link para o qual ele te leva (começa com "${prefix}") e cole-o aqui.';
	@override String get copyLoginLink => 'Copiar link de login';
	@override String get pastedLinkLabel => 'Cole o link aqui';
	@override String get finishLogin => 'Concluir login';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Esse não é o link de login — ele deve começar com "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Esse link pertence a outra tentativa de login. Feche esta página e conecte novamente.';
	@override String get pastedLinkNoCode => 'Esse link não tem um código de login. Conclua o login primeiro e depois copie o link para o qual ele te leva.';
	@override String get pastedLinkMalformed => 'Esse link parece cortado. Copie-o inteiro e cole novamente.';
	@override String get relayLoginWaiting => 'Aguardando você concluir o login — isto continuará automaticamente quando você terminar.';
	@override String get loginNoResponse => 'Este dispositivo ainda não recebeu resposta do login. Se você já concluiu no navegador, cancele e tente conectar novamente.';
	@override String get relayLoginNotOpened => 'O Ham2K Logger não conseguiu abrir seu navegador automaticamente. Use o botão abaixo para abrir a página de login você mesmo.';
	@override String get relayLoginUnavailable => 'Não foi possível acessar o servidor de sincronização necessário para concluir este login. Verifique sua conexão e tente novamente.';
	@override String get loginIncompleteResponse => 'Essa tentativa de login não foi concluída corretamente. Tente conectar novamente.';
	@override String get noKeyringTitle => 'Os logins de contas não podem ser salvos';
	@override String get noKeyringText => 'O Ham2K Logger não consegue acessar um serviço de chaveiro neste computador, então os logins de contas não podem ser armazenados nem lidos — conectar uma conta vai falhar até isso ser resolvido. Instale e inicie o **gnome-keyring**, **KWallet** ou **KeePassXC**, ou desbloqueie o chaveiro que você já tem, e depois reinicie. Registro, exportações e arquivos de dados não são afetados; a sincronização do log fica desligada enquanto isso durar.';
	@override String get noKeyringInline => 'Os logins não podem ser salvos: o chaveiro deste computador está inacessível. Instale e inicie o gnome-keyring, KWallet ou KeePassXC, ou desbloqueie o que você tem.';
	@override String get noSecureStorageInline => 'Os logins não podem ser salvos: o armazenamento seguro deste computador está inacessível.';
}

// Path: settings.station
class _Translations$settings$station$pt_BR extends Translations$settings$station$pt {
	_Translations$settings$station$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuração da estação e controle CAT';
	@override String get none => 'Nenhum equipamento configurado';
	@override String get add => 'Adicionar';
	@override String get addTitle => 'Adicionar equipamento';
	@override String get searchHint => 'Buscar equipamento';
	@override String get noMatches => 'Nenhum equipamento corresponde';
	@override String get detectedEquipment => 'Equipamentos detectados';
	@override String discoveryUnavailable({required Object error}) => 'Não é possível escutar rádios: ${error}';
	@override String get edit => 'Editar equipamento';
	@override String get name => 'Nome';
	@override String get nameDescription => 'Como você o chama — "Rádio da esquerda". Opcional.';
	@override String get transport => 'Conexão';
	@override String get host => 'Endereço';
	@override String get hostDescription => 'O nome de host ou endereço IP do rádio na sua rede.';
	@override String get port => 'Porta';
	@override String get hostRequired => 'Um endereço é obrigatório';
	@override String get portInvalid => 'A porta deve estar entre 1 e 65535';
	@override String get connect => 'Conectar';
	@override String get disconnect => 'Desconectar';
	@override String get remove => 'Remover';
	@override String removeTitle({required Object name}) => 'Remover ${name}?';
	@override String get removeMessage => 'Isso apenas o remove do app. As configurações do equipamento continuam como estão.';
	@override String unknownType({required Object typeKey}) => 'Tipo de equipamento não reconhecido "${typeKey}"';
	@override String get report => 'Relatar';
	@override String get reportTitle => 'Relatar este rádio';
	@override String get reportIntro => 'Conte-nos qual rádio é este de fato e como foi. Seu relato vira um cartão que a equipe do Ham2K lê, e o que você escrever sobre como fazê-lo funcionar pode acabar ajudando o próximo operador com o mesmo equipamento.';
	@override String get reportManufacturer => 'Fabricante';
	@override String get reportManufacturerDescription => 'Quem o fabrica — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'O fabricante é obrigatório';
	@override String get reportModel => 'Modelo';
	@override String get reportModelDescription => 'O modelo, como o próprio rádio o chama — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'O modelo é obrigatório';
	@override String get reportOutcome => 'Como foi?';
	@override String get reportOutcomeWorks => 'Funcionou bem';
	@override String get reportOutcomeIssues => 'Funcionou, com problemas';
	@override String get reportOutcomeFails => 'Não funcionou';
	@override String get reportOutcomeRequired => 'Conte-nos como foi';
	@override String get reportComments => 'Comentários';
	@override String get reportCommentsPlaceholder => 'O que funcionou, o que não funcionou, qualquer coisa que te surpreendeu.';
	@override String get reportHints => 'Dicas de solução de problemas';
	@override String get reportHintsPlaceholder => 'Quer sugerir algumas dicas de solução de problemas para outros usuários?';
	@override String get reportSend => 'Enviar relato';
	@override String get reportSending => 'Enviando seu relato…';
	@override String reportSent({required Object ref}) => 'Obrigado — seu relato foi registrado como ${ref}.';
	@override String get reportSentNoRef => 'Obrigado — seu relato foi enviado.';
	@override String reportFailed({required Object error}) => 'O relato não foi enviado: ${error}';
	@override String get troubleshootingNotes => 'Notas de solução de problemas';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Usar como VFO principal';
	@override String get serialPort => 'Porta serial';
	@override String get serialPortDescription => 'A porta em que aparece a interface CAT do rádio.';
	@override String get serialPortNone => 'Nenhuma porta serial encontrada';
	@override String get serialPortRequired => 'Escolha uma porta serial';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'porta ${n} de ${total}';
	@override String get serialPortSuggested => 'sugerida';
	@override String get serialPortJustNow => 'Conectada recentemente';
	@override String get serialDeviceRequest => 'Adicionar um dispositivo USB…';
	@override String get baudRate => 'Velocidade (baud)';
	@override String get baudRateDescription => 'Deve corresponder ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo e nenhum erro.';
	@override String get serialRtsHigh => 'Manter RTS alto';
	@override String get serialRtsHighDescription => 'Apenas para um rádio que espera o RTS antes de responder, como um Yaesu com CAT RTS ativado. Em um Digirig, SignaLink e na maioria dos cabos caseiros, o RTS é o PTT, e mantê-lo alto transmite.';
	@override String get serialDtrHigh => 'Manter DTR alto';
	@override String get serialDtrHighDescription => 'Apenas para uma interface CAT alimentada pelo DTR, como alguns cabos RS-232 para o FT-817. Em muitos cabos o DTR aciona CW ou PTT, e mantê-lo alto transmite.';
	@override String get civAddress => 'Endereço CI-V do rádio';
	@override String get civAddressDescription => 'Hexadecimal, como mostrado no menu CI-V do rádio. O IC-705 vem de fábrica com A4.';
	@override String get civAddressInvalid => 'Um endereço CI-V tem dois dígitos hexadecimais, de 01 a FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Qual slice do rádio esta conexão lê e sintoniza.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Escolha um dos slices do rádio, de A a H';
	@override String flexSliceMissing({required Object letter}) => 'O slice ${letter} não está em uso neste rádio — escolha outro slice ou crie-o no SmartSDR';
	@override String get channelNotInUse => 'não está em uso';
	@override String get channelHeldByUnknown => 'em uso por outro programa';
	@override String get flexNoSlices => 'Este rádio não informou nenhum slice — verifique se o SmartSDR está rodando e se este cliente pode se inscrever';
	@override String get spectrumUnsupported => 'Este rádio não envia espectro via CAT';
	@override String get spectrumRequiresBaud => 'Requer CAT a 115200 bps';
	@override String get spectrumNoRadio => 'Nenhum rádio conectado';
	@override String get spectrumWaiting => 'Aguardando o espectro do rádio…';
	@override String get spectrumUnavailable => 'A exibição do espectro não está disponível';
	@override String get spectrumNoDaxChannel => 'Todos os canais DAX IQ deste rádio estão em uso';
	@override String get spectrumNoPanadapter => 'Este slice não tem panadapter no rádio';
	@override String spectrumStreamRefused({required Object code}) => 'O rádio recusou um stream DAX IQ (erro ${code})';
	@override String get spectrumNoUdp => 'Os dados de espectro do rádio não conseguem chegar a este dispositivo';
	@override String get spectrumScopeRefused => 'O rádio recusou os comandos de scope';
	@override String get spectrumOutOfRange => 'O scope do rádio está ajustado fora da faixa que ele consegue mostrar';
	@override String get n3fjpNoRig => 'O N3FJP não tem interface de rádio configurada, então isto segue o que é digitado no N3FJP, não um rádio';
	@override String get winkeyerKeyPort => 'Saída de manipulação';
	@override String get winkeyerKeyPortDescription => 'Em qual das duas saídas do keyer o seu rádio está conectado.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Porta ${n}';
	@override String get winkeyerPtt => 'Usar o PTT do keyer';
	@override String get winkeyerPttDescription => 'Aciona a linha de PTT na mesma saída, para um amplificador ou um rádio que precise. Deixe desligado para um rádio manipulado pela entrada de chave.';
	@override String get winkeyerNoAnswer => 'Nenhum WinKeyer respondeu nesta porta';
	@override String get winkeyerStoppedAnswering => 'O WinKeyer parou de responder durante o envio; a mensagem foi descartada';
	@override String get radioUser => 'Usuário do rádio';
	@override String get radioPass => 'Senha do rádio';
	@override String get radioLoginDescription => 'O login de Network → Remote do rádio, não a senha do seu WiFi.';
	@override String get radioUserRequired => 'O usuário de controle remoto do rádio é obrigatório';
	@override String get connectFailedBusy => 'O dispositivo está em uso';
	@override String get connectFailedDenied => 'Acesso negado';
	@override String get connectFailedDevice => 'Dispositivo não encontrado';
	@override String get connectFailedLines => 'Não foi possível manter RTS/DTR como definido, então a porta foi fechada. Outro programa pode ter deixado o controle de fluxo por hardware ligado — desconecte e reconecte o cabo.';
	@override String get connectFailedNetwork => 'Não foi possível encontrar o rádio na rede. Verifique o endereço e se ele está ligado e acessível.';
	@override String get connectFailedTimeout => 'O rádio não respondeu a tempo. Verifique se ele está ligado e acessível.';
	@override late final _Translations$settings$station$models$pt_BR models = _Translations$settings$station$models$pt_BR._(_root);
	@override late final _Translations$settings$station$transports$pt_BR transports = _Translations$settings$station$transports$pt_BR._(_root);
	@override String get troubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get ft891Troubleshooting => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **CAT RTS deve estar OFF no rádio** (menu **05-08** do FT-891). Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa. Em um Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, então elevá-la acionaria seu transmissor. Na porta USB do próprio rádio, **Manter RTS alto** nas Configurações avançadas é a alternativa.\n- **A velocidade deve corresponder** ao CAT RATE do rádio (menu **05-06**). Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get yaesuBinaryTroubleshooting => 'Este rádio usa o CAT antigo de cinco bytes da Yaesu e não responde nada quando algo está errado. Quase sempre é um destes:\n\n- **O cabo precisa converter os níveis.** O conector CAT traseiro não é RS-232 nem USB; ele precisa de um CT-62 ou adaptador equivalente. Um cabo simples de áudio ou de dados não funciona para CAT.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio (**#14** no FT-817, **#19** no FT-857 ou FT-897). Se não corresponder, o rádio não devolve nada, e nunca um erro.\n- **Nunca deixe nada elevar RTS ou DTR nesta porta.** Na maioria dos cabos para estes rádios essas linhas são PTT e manipulação. Uma interface antiga alimentada pelo DTR é a exceção: ative **Manter DTR alto** nas Configurações avançadas para ela.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\nEste driver foi escrito a partir da tabela CAT publicada pela Yaesu e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena relatar.';
	@override String get guohetecTroubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get guohetecTroubleshooting => 'O Q900 tem dois protocolos CAT, e esta entrada usa o nativo em vez da imitação do FT-817. Escolha **Guohetec Q900** aqui, não um FT-817 — a imitação suporta menos comandos, e o rádio não diz qual está usando.\n\n- **O cabo USB-C é o link CAT**, e também conecta a placa de som. A velocidade não importa nele; a porta ignora o valor definido.\n- **Nunca deixe nada elevar RTS ou DTR nesta porta.** Em um cabo serial essas linhas são PTT e manipulação.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Um rádio de segunda geração se comporta de forma diferente** de um de primeira. Pressione Menu longamente e depois About: HW 2.0 é a segunda geração.\n\nEste driver foi escrito a partir do protocolo publicado pelo fabricante e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena relatar.';
	@override String get yaesuTroubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get yaesuTroubleshooting => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa. Em um Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, então elevá-la acionaria seu transmissor. Na porta USB do próprio rádio, **Manter RTS alto** nas Configurações avançadas é a alternativa. O local dessa configuração varia conforme o modelo (menu **05-08** no FT-891).\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Os modos seguem a tabela do FT-891.** A maior parte da linha Yaesu corresponde a ela, mas um rádio que numera os modos de outra forma mostrará e definirá o modo errado nesses casos. A frequência não é afetada.';
	@override String get yaesuRs232Troubleshooting => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **O conector CAT é RS-232.** Ele precisa de um adaptador USB-serial e de um cabo DB-9 direto — um cabo null-modem inverte as linhas, e o rádio nunca recebe nada.\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa, a menos que **Manter RTS alto** esteja ativado nas Configurações avançadas.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\nEsta entrada foi escrita a partir da documentação CAT publicada e ainda não foi testada com um destes rádios. Se funcionar só em parte, vale a pena relatar.';
	@override String get yaesuUsbTroubleshooting => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **Use a primeira das duas portas USB do rádio.** O CAT normalmente fica na primeira (a porta COM **Enhanced** no Windows); a segunda (**Standard**) é para PTT e manipulação. O seletor aponta para a primeira sempre que consegue distinguir as duas.\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa, a menos que **Manter RTS alto** esteja ativado nas Configurações avançadas.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.';
	@override String get k4SerialNotes => 'Conecte a entrada traseira USB-B (PC) do K4. Tanto USB-PC1 quanto USB-PC2 servem para CAT; escolha uma porta livre e ajuste a configuração Serial USB-PCn: Baud Rate correspondente no rádio. O HaLo preenche 38400; altere se necessário. Outro aplicativo deve usar a outra porta ou a Ethernet.\n\nEsta conexão controla o rádio e seus keyers; ela não envia áudio para o HaLo.';
	@override String get k4TcpNotes => 'Conecte a entrada Ethernet do K4 à sua rede local. Insira o nome de host ou endereço IP e a porta CAT 9200. Isto é controle CAT, não a conexão separada de áudio remoto na porta 9204.\n\nO HaLo controla o rádio e seus keyers sem transmitir áudio ou dados de panadapter.';
	@override String get k4PowerTimeout => 'A potência do K4 não foi alterada porque o rádio não confirmou sua faixa de saída. Tente novamente.';
	@override String get k4PowerRange => 'A potência do K4 deve ser 0.1–110 W, ou 0.0001–0.01 W quando a saída de miliwatts do transverter estiver ativa.';
	@override String get elecraftTroubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get elecraftTroubleshooting => 'Os rádios Elecraft usam o CAT da Kenwood, e um KX2 e um KX3 já foram testados assim — VFO nos dois sentidos, troca de modo e batimento zero em CW, tudo funcionando.\n\nSe o rádio não responder, quase sempre é um destes:\n\n- **A velocidade deve corresponder** à taxa definida em **RS232** no menu do rádio. Eles vêm de fábrica com 38400. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\n**Se a frequência estiver certa mas o modo errado**, nos avise. As entradas do KX2 e do KX3 leem o modo de uma posição na resposta de status do rádio que fixamos com base nos rádios que vimos, e um firmware que o coloque em outro lugar só chega até nós por um relato.\n\nO K3 ainda não foi relatado, então conte o que acontece se você usar um. O K4 tem sua própria entrada.';
	@override String get kenwoodTroubleshootingTitle => 'Se o rádio conecta mas não mostra frequência';
	@override String get kenwoodTroubleshooting => 'Este driver foi testado com o TS-590SG e o TS-480 da Kenwood, o QMX e o QCX-mini da QRP Labs e o KX2 e o KX3 da Elecraft. O resto da linha foi escrito a partir de referências CAT publicadas, então relate o que acontecer, funcionando ou não.\n\nSe o rádio não responder, quase sempre é um destes:\n\n- **A velocidade deve corresponder** ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Alguns rádios precisam do CAT ativado** no menu antes de responder.\n\n**Vários front-ends SDR usam este mesmo protocolo**, então vale a pena tentar esta entrada para eles também; os rádios Elecraft estão listados à parte, em Elecraft. Se a frequência estiver certa mas o modo errado ou ausente, essa é a única parte que varia na linha — o app a deduz a partir do rádio e, se não conseguir, pergunta diretamente, então o modo pode simplesmente demorar a aparecer.';
	@override String get statusConnected => 'Conectado';
	@override String get statusLost => 'Desconectado';
	@override String get notConfigured => 'Não configurado';
	@override String get currentConfiguration => 'Configuração atual';
	@override String get currentTransceiver => 'Transceptor atual';
	@override String get radioMode => 'Modo do rádio';
	@override String get keyerNotSupported => 'Não suportado pelo rádio atual';
	@override String get catControlPreferences => 'Preferências de controle CAT';
	@override String get chooseTransceiver => 'Escolher transceptor';
	@override String get configurationSection => 'Configuração';
	@override String get noTransceiverSelected => 'Nenhum transceptor selecionado';
	@override String makeMainVfo({required Object name}) => 'Usar ${name} como VFO principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		zero: 'Nenhum transceptor',
		one: '${count} transceptor',
		other: '${count} transceptores',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} antena',
		other: '${count} antenas',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} outro dispositivo',
		other: '${count} outros dispositivos',
	);
	@override String get equipmentInventory => 'Inventário de equipamentos';
	@override String get equipmentInUse => 'Controles do transceptor';
	@override String get noTransceiver => 'Nenhum';
	@override String get peerRadioNotAvailable => 'Indisponível';
	@override String peerRadioOnDevice({required Object device}) => 'Em ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} está em outro dispositivo';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Este rádio está conectado a ${device}. A conexão e as configurações dele são definidas nesse dispositivo.';
	@override String get antennaInUse => 'Antena em uso';
	@override String get keyInUse => 'Chave em uso';
	@override String get noneSelected => 'Nenhuma';
	@override String get moreSettings => 'Mais configurações';
	@override String get icomCivTroubleshootingTitle => 'Se aparecerem duas portas seriais para o mesmo rádio';
	@override String get icomCivTroubleshooting => 'Vários rádios Icom, entre eles o IC-705, apresentam **duas** portas seriais USB ao mesmo tempo (a Icom as chama de Port A e Port B), ambas configuradas como CI-V por padrão. Nem este app nem seu sistema operacional conseguem distingui-las além disso: o mesmo ID de fabricante/produto USB simplesmente aparece duas vezes, às vezes marcado aqui com o sufixo `#2`. **A Port A costuma ser a certa** — normalmente a primeira que seu sistema ou navegador lista, e quando este app consegue distinguir as duas portas, marca essa como sugerida. Se os comandos saem e o rádio nunca responde, tente a outra porta.';
	@override String get civAddressTroubleshootingTitle => 'Se o rádio nunca responde';
	@override String get civAddressTroubleshooting => '- **O endereço CI-V deve corresponder** ao menu do rádio. Esta entrada preenche o endereço de fábrica do modelo, mas um rádio que compartilha um barramento CI-V é exatamente onde ele é alterado. Um quadro enviado ao endereço errado é ignorado em silêncio, o que parece exatamente um cabo com defeito.\n- **A velocidade deve corresponder** ao CI-V BAUD RATE do rádio (no USB, CI-V USB Baud Rate). Ajuste o rádio para o mesmo número mostrado aqui, **não Auto**. Em Auto, alguns rádios, entre eles o IC-7300, conectam e depois param de responder após cerca de um minuto.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.';
	@override String get ic7300Mk2Note => '\n- O **IC-7300 MK2** vem de fábrica com o endereço `B6`, não o `94` preenchido aqui — escolha a entrada IC-7300 MK2.';
	@override String get ic705PortNote => '\n- O **IC-705** apresenta duas portas seriais USB, ambas com o nome do rádio. O CI-V fica na **primeira** delas, para a qual o seletor aponta sempre que consegue distinguir as duas.';
	@override String get ic7760PortNote => '\n- O **IC-7760** usa CI-V na **Port A** das duas portas seriais USB que apresenta.';
	@override String get x6100PortNote => '\n- O **X6100** usa CI-V na porta **DEV** — a segunda das duas portas seriais que apresenta, e a que o seletor indica.';
	@override String get rigctldTroubleshootingTitle => 'Se o app não consegue conectar';
	@override String get rigctldTroubleshooting => 'Isto conecta a um **daemon rigctld que você mesmo roda**, não diretamente ao rádio — o backend do Hamlib conversa com o rádio e suporta centenas de modelos.\n\n- **O daemon já deve estar rodando**, por exemplo `rigctld -m 1035 -r /dev/ttyUSB0`. Encontre o número do modelo do seu rádio com `rigctl -l`.\n- **De outra máquina**, inicie-o com `-T 0.0.0.0`: por padrão o rigctld só aceita conexões da máquina em que roda.\n- **A porta** é 4532, a menos que você tenha iniciado o daemon com `-t`.\n- Depois de conectado, uma frequência ausente geralmente significa que o próprio daemon não consegue acessar o rádio. Teste com `rigctl -m 2 f` na máquina do daemon.';
	@override String get flrigTroubleshootingTitle => 'Se o app não consegue conectar';
	@override String get flrigTroubleshooting => 'Isto conecta a um **programa flrig que você mesmo roda**, não diretamente ao rádio — o flrig conversa com o rádio e suporta a maioria das marcas e modelos.\n\n- **O flrig já deve estar rodando**, com o transceptor configurado e conectado.\n- **A porta** é 12345, a menos que você a tenha alterado na configuração do flrig (Config → Setup → Server).\n- **De outra máquina**, verifique se o servidor do flrig está acessível. Ele escuta em todas as interfaces, mas seu firewall pode discordar.\n- Depois de conectado, uma frequência ausente geralmente significa que o próprio flrig não consegue acessar o rádio. Verifique se o display do flrig acompanha o dial.';
	@override String get hrdTroubleshootingTitle => 'Se o app não consegue conectar';
	@override String get hrdTroubleshooting => 'Isto conecta ao **Rig Control do Ham Radio Deluxe, rodando no seu computador**, não diretamente ao rádio — o HRD conversa com o rádio.\n\n- **O Rig Control já deve estar rodando** e conectado ao rádio.\n- **O servidor IP dele deve estar ativado.** O Rig Control só conversa com outros programas por meio dele.\n- **A porta** é 7809, a menos que você a tenha alterado nas configurações do servidor IP.\n- **De outra máquina**, verifique se seu firewall deixa a conexão passar.\n\nEsta entrada foi escrita a partir de descrições publicadas do protocolo do HRD e ainda não foi testada com o HRD. Se funcionar só em parte, vale a pena relatar.';
	@override String get n3fjpTroubleshootingTitle => 'Se o app não consegue conectar';
	@override String get n3fjpTroubleshooting => 'Isto conecta a **um programa de log N3FJP rodando no seu computador**, não diretamente ao rádio — o N3FJP conversa com o rádio.\n\n- **A API do programa deve estar ativada**: em Settings → Application Program Interface, marque **TCP API Enabled**.\n- **A porta** é 1100, a menos que você a tenha alterado lá.\n- **O N3FJP precisa ter uma interface de rádio configurada** para acompanhar ou sintonizar o rádio. Sem ela, ele informa apenas o que é digitado na janela de entrada.\n- O N3FJP informa apenas banda, modo e frequência: sem potência, sem estado de transmissão.\n\nEsta entrada foi escrita a partir da API publicada do N3FJP e ainda não foi testada com o N3FJP. Se funcionar só em parte, vale a pena relatar.';
	@override String get commanderTroubleshootingTitle => 'Se o app não consegue conectar';
	@override String get commanderTroubleshooting => 'Isto conecta ao **DXLab Commander, rodando no seu computador**, não diretamente ao rádio — o Commander conversa com o rádio.\n\n- **O Commander já deve estar rodando** e conectado ao rádio.\n- **O serviço de rede dele deve estar ativado**: o botão **Net Serv** no painel Radio da janela Configuration do Commander.\n- **A porta** é 52002, a terceira porta do bloco que começa na **Base Port** do Net Serv (52000, a menos que você a tenha alterado).\n- **De outra máquina**, verifique se seu firewall deixa a conexão passar.\n\nEsta entrada foi escrita a partir das mensagens TCP publicadas do Commander e ainda não foi testada com o Commander. Se funcionar só em parte, vale a pena relatar.';
	@override String get ic705TroubleshootingTitle => 'Se o rádio nunca responde';
	@override String get ic705Troubleshooting => 'O rádio tem uma **única** sessão de controle remoto. Quando o login é ignorado, quase sempre outra coisa a está usando.\n\n- **Feche qualquer outro cliente.** O wfview ou o RS-BA1 conectado ao mesmo rádio ocupa essa sessão, e o login aqui é simplesmente ignorado enquanto isso.\n- **Verifique as configurações de rede do rádio.** O WLAN deve estar ligado, o rádio deve estar na mesma rede e a função de controle remoto (Network) deve estar ativada.\n- **Desligue e ligue o WLAN do rádio** se ele continuar travado. Isso sempre libera uma sessão presa no rádio.\n\nUma **senha errada é recusada explicitamente**, não recebida com silêncio. Se você chegou aqui em vez de ver uma mensagem de "rejeitado", o problema não é a senha.';
	@override String get statusStale => 'Sem resposta';
	@override String get statusDisconnected => 'Não conectado';
	@override String get statusConnecting => 'Conectando…';
	@override String get statusDisconnecting => 'Desconectando…';
	@override String get statusError => 'Falha na conexão';
	@override String get currentRadioSettings => 'Configurações atuais do rádio';
	@override String get notSupportedByThisRadio => 'Não suportado por este rádio';
	@override String get keyerRowLabel => 'Manipulador';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Fonia';
	@override String voiceKeyerAvailable({required Object count}) => 'Manipulador de voz: ${count} memórias no rádio';
	@override String get antennaBands => 'Bandas';
	@override String get antennaType => 'Tipo de antena';
	@override String get antennaTypeRequired => 'Escolha um tipo de antena';
	@override late final _Translations$settings$station$antennaTypes$pt_BR antennaTypes = _Translations$settings$station$antennaTypes$pt_BR._(_root);
	@override String get keyType => 'Tipo de chave';
	@override String get keyTypeRequired => 'Escolha um tipo de chave';
	@override late final _Translations$settings$station$keyTypes$pt_BR keyTypes = _Translations$settings$station$keyTypes$pt_BR._(_root);
	@override String get softwareIntermediaries => 'Softwares intermediários';
	@override String get otherBrands => 'Outras marcas';
	@override String get otherEquipment => 'Outros equipamentos (antenas, chaves etc.)';
	@override String get newAntenna => 'Nova antena';
	@override String get newKey => 'Nova chave';
	@override String get newKeyer => 'WinKeyer (K1EL ou compatível)';
	@override String keyViaRadio({required Object radio}) => 'Manipulador CAT em ${radio}';
	@override String keyOnDevice({required Object device}) => 'Chave em ${device}';
	@override String get cwKeyerArea => 'Área do manipulador';
	@override String get trackStationInfo => 'Registrar dados da estação em cada QSO';
	@override String get includeStationInfoInAdif => 'Incluir nas exportações ADIF';
	@override String get whatToTrack => 'O que registrar?';
	@override String get trackFieldRig => 'Transceptor';
	@override String get trackFieldPower => 'Potência';
	@override String get watts => 'Watts';
	@override String get trackFieldAntenna => 'Antena';
	@override String get trackFieldKey => 'Chave de CW';
	@override String get placeholderConnectDelay => 'Atraso de conexão (ms)';
	@override String get placeholderConnectDelayDescription => 'Quanto tempo leva o handshake simulado. Vazio ou 0 conecta na hora.';
	@override String get placeholderDropAfter => 'Cair após (segundos)';
	@override String get placeholderDropAfterDescription => 'Fecha a conexão sozinho, para testar a reconexão. Vazio ou 0 nunca cai.';
	@override String get placeholderFailConnect => 'Sempre falhar ao conectar';
	@override String get placeholderConnectFailure => 'O rádio provisório foi instruído a recusar esta conexão';
	@override String get placeholderFreq => 'Frequência (kHz)';
	@override String get placeholderFreqDescription => 'Onde o rádio provisório começa. Depois ele informa a frequência que o app sintonizar.';
	@override String get placeholderMode => 'Modo';
	@override String get placeholderModeDescription => 'O modo em que o rádio provisório começa, por exemplo USB, CW, FT8.';
	@override String get placeholderPower => 'Potência (watts)';
	@override String get placeholderPurpose => 'Use este rádio para registrar qual equipamento você está usando nos seus logs';
	@override String get placeholderReplyDelay => 'Atraso de resposta (ms)';
	@override String get placeholderReplyDelayDescription => 'Quanto tempo o rádio provisório leva para informar uma alteração. Vazio ou 0 responde na hora.';
	@override String get cwKeyerField => 'Manipulador CW via CAT';
	@override String get cwKeyerFieldDescription => 'Se este rádio manipula CW a partir de texto via CAT. Desligado para um rádio que o app não conhece.';
	@override String get voiceMemories => 'Memórias de voz';
	@override String get voiceMemoriesDescription => 'Quantas memórias de voz o rádio reproduz via CAT. 0 para nenhuma.';
	@override String get voiceMemoriesInvalid => 'Um número inteiro, 0 ou mais';
	@override String get yaesuMeterCapture => 'Capturar leituras dos medidores';
	@override String get yaesuBinaryMeterCaptureDescription => 'Lê o medidor de potência de saída e o indicador de ROE alta do rádio durante a transmissão e grava os valores brutos no log. Serve para montar a escala que a Yaesu não publica — os valores não são mostrados como medidores.';
	@override String get yaesuMeterCaptureDescription => 'Lê os medidores PO, SWR e ALC do rádio durante a transmissão e grava os valores brutos no log. Serve para montar a escala que a Yaesu não publica — os valores não são mostrados como medidores.';
	@override String get telemetryInterval => 'Intervalo de leitura dos medidores (ms)';
	@override String get telemetryIntervalDescription => 'Com que frequência ler os medidores do rádio enquanto ele transmite. Deixe vazio para o mais rápido que esta conexão suporta, até 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}';
	@override String get pollInterval => 'Intervalo de consulta em repouso (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Com que frequência perguntar ao rádio a frequência e o modo enquanto nenhum dos dois muda. Deixe vazio para ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}';
	@override String get advancedSettings => 'Configurações avançadas';
	@override String get placeholderSwr => 'Leitura de ROE';
	@override String get placeholderSwrDescription => 'O que este rádio informa no medidor de ROE durante a transmissão. Acima de 1.8, o painel avisa.';
	@override String get placeholderSwrInvalid => 'Um número, 1 ou mais';
	@override String get keyerNone => 'Nenhum';
	@override String get cwDialect => 'Dialeto de manipulação CW';
	@override String get cwDialectDescription => 'Qual formato do comando KY este rádio aceita. Nenhum significa sem manipulação CW via CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, completado até 24)';
	@override String get cwDialectElecraft => 'Elecraft (texto KY)';
	@override String get voiceDialect => 'Dialeto do manipulador de voz';
	@override String get voiceDialectDescription => 'Como este rádio reproduz suas memórias de voz via CAT. Nenhum significa sem memórias de voz via CAT. Com um dialeto e sem quantidade, vale a quantidade padrão do dialeto.';
	@override String get voiceDialectPb => 'Kenwood (PB, estilo TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB e DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (toques de botão)';
	@override String get placeholderDiagnostic => 'Simulado';
	@override String get placeholderWholeNumberInvalid => 'Deve ser um número inteiro, 0 ou mais';
	@override String get placeholderFreqInvalid => 'Deve ser uma frequência em kHz, maior que zero';
	@override String get placeholderModeInvalid => 'Deve ser um nome de modo, por exemplo USB, CW, FT8';
	@override String get switchLayout => 'Disposição';
	@override String get switchLayoutDescription => 'Em qual lado da chave seus rádios estão conectados.';
	@override String get switchLayoutRequired => 'Escolha como a chave está ligada';
	@override String switchCommandRefused({required Object command, required Object code}) => 'A chave recusou "${command}" (erro ${code})';
	@override String get switchBusyTransmitting => 'Essa porta está transmitindo — antena não alterada';
	@override String get switchNoAntenna => 'Nenhuma';
	@override String switchAntennaFor({required Object port}) => 'Antena na porta ${port}';
	@override String get switchAntennaForDescription => 'Qual das suas antenas está conectada a esta porta da chave.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antenas, ${radios} rádios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antenas, 1 rádio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antena, ${radios} rádios';
	@override String get switchCommonPort => 'Comum';
	@override String get dcnAddress => 'Endereço do dispositivo';
	@override String get dcnAddressDescription => 'O endereço definido nas chaves DIP do módulo. Um módulo de relé coaxial sai de fábrica com 2.';
	@override String get dcnAddressRequired => 'Deve ser um endereço de dispositivo de 1 a 99';
	@override String switchPortLabel({required Object port}) => 'Porta ${port}';
	@override String get switchPortAutoHint => 'segue os dados de banda';
	@override String get switchPortTransmittingHint => 'transmitindo — não pode mudar agora';
	@override String get switchCurrentStateHeader => 'Estado atual';
	@override String get switchCurrentStateDescription => 'Em qual antena cada porta de rádio está agora. As alterações têm efeito imediato.';
	@override String get switchWiringHeader => 'Ligações';
	@override String get switchPortInhibitedHint => 'transmissão inibida';
	@override String get configUnreadable => 'Não foi possível ler as configurações salvas deste rádio. Abra as configurações dele e insira-as novamente, ou remova-o e adicione-o de novo.';
	@override String get autoConnectHeld => 'O HaLo parou de responder na última vez que se conectou a este rádio, então desta vez não se conectou sozinho. Pressione Conectar para tentar novamente.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$pt_BR extends Translations$settings$offlineData$pt {
	_Translations$settings$offlineData$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dados offline';
	@override String get noFiles => 'Nenhum arquivo de dados';
	@override String get noFilesDescription => 'Habilite extensões de atividade ou de consulta para baixar os dados offline delas aqui.';
	@override String get refresh => 'Atualizar';
	@override String get refreshing => 'Atualizando…';
	@override String get updateAll => 'Atualizar todos';
	@override String get updatingAll => 'Atualizando todos os arquivos de dados…';
	@override String get neverDownloaded => 'Nunca baixado';
	@override String get updatedJustNow => 'Atualizado agora mesmo';
	@override String updatedDaysAgo({required Object days}) => 'Atualizado há ${days}d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Atualizado há ${days}d ${hours}h';
	@override String updatedHoursAgo({required Object hours}) => 'Atualizado há ${hours}h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Atualizado há ${hours}h ${minutes}min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Atualizado há ${minutes}min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'O último download tinha apenas ${imported} de ${existing} registros e não foi usado. Atualize para aceitá-lo.';
	@override String get extensionsSection => 'Extensões';
}

// Path: settings.profiles
class _Translations$settings$profiles$pt_BR extends Translations$settings$profiles$pt {
	_Translations$settings$profiles$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Não definido';
	@override String get personalInfo => 'Informações pessoais';
	@override String get personalInfoNote => 'Isto pode ser incluído nos logs gerados quando for relevante para envios';
	@override String get name => 'Nome';
	@override String get email => 'E-mail';
	@override String get club => 'Clube';
	@override String get arrlSection => 'Seção ARRL';
	@override String get racSection => 'Seção RAC';
	@override String get section => 'Seção';
}

// Path: settings.search
class _Translations$settings$search$pt_BR extends Translations$settings$search$pt {
	_Translations$settings$search$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Limpar';
	@override String get hint => 'Buscar preferências';
}

// Path: settings.developer
class _Translations$settings$developer$pt_BR extends Translations$settings$developer$pt {
	_Translations$settings$developer$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Habilita avisos de desenvolvedor, logs de depuração e ferramentas.';
	@override String get experiments => 'Experimentos';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} habilitado',
		other: '${count} habilitados',
	);
	@override String get patchTrack => 'Faixa de patches';
	@override String get patchTrackDescription => 'Qual faixa de patches de código pela internet este dispositivo segue. Faixas mais ousadas recebem correções antes, menos testadas. Os patches são aplicados na próxima reinicialização.';
	@override String get trackStable => 'Estável';
	@override String get trackUnstable => 'Instável';
	@override String get trackBleeding => 'Experimental';
	@override String checkingTrack({required Object track}) => 'Verificando patches em "${track}"…';
	@override String get patchDownloaded => 'Patch baixado — reinicie o app para aplicá-lo.';
	@override String noNewPatch({required Object track}) => 'Nenhum patch novo em "${track}".';
	@override String get noPatchInstalled => 'Nenhum patch instalado — rodando o binário da versão.';
	@override String runningPatch({required Object patch}) => 'Rodando o patch nº ${patch}.';
	@override String get deepLinks => 'Deep links';
	@override String get registerUrlSchemes => 'Registrar esquemas de URL';
	@override String get registerUrlSchemesDescription => 'Permite que links com.ham2k:// abram esta cópia do app';
	@override String get registerUrlSchemesDone => 'Esta cópia agora abre links com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Não foi possível registrar: ${error}';
	@override String get systemInformation => 'Informações do sistema';
	@override String get appVersion => 'Versão do app';
	@override String get dataFolder => 'Pasta de dados';
	@override String get loading => '(carregando…)';
	@override String get panelLoadFailed => 'Não foi possível carregar este painel de configurações.';
	@override String get extDevServer => 'Servidor de desenvolvimento de extensões';
	@override String get extensionSettings => 'Configurações de extensões';
	@override String get extDevServerDescription => 'Carrega extensões de um servidor de desenvolvimento na sua rede em vez das integradas ao app, e as recarrega quando você salva.';
	@override String get extDevServerAddress => 'Endereço do servidor';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Conectar';
	@override String get extDevServerDisconnect => 'Desconectar';
	@override String get extDevServerConnecting => 'Conectando…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Servindo ${count} extensão: ${keys}',
		other: 'Servindo ${count} extensões: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Não conectado';
	@override String get extDevServerReconnect => 'Reconectar ao iniciar';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Última recarga: ${key} às ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} extensão com falha no build',
		other: '${count} extensões com falha no build',
	);
	@override String get catalog => 'Catálogo de extensões';
	@override String get catalogDescription => 'Lê o catálogo de outro servidor — um local, ao trabalhar no próprio catálogo. Vazio significa catalog.ham2k.net.';
	@override String get catalogAddress => 'Endereço do catálogo';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Faixas de busca do catálogo';
	@override String get catalogSearchStable => 'Apenas estável';
	@override String get catalogSearchUnstable => 'Instável ou melhor';
	@override String get catalogSearchBleeding => 'Experimental ou melhor';
}

// Path: settings.about
class _Translations$settings$about$pt_BR extends Translations$settings$about$pt {
	_Translations$settings$about$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Avisos e mensagens';
	@override String get noticesDescription => 'Anúncios e mensagens de status';
	@override String get releaseNotes => 'Notas de versão';
	@override String get copiedVersion => 'Detalhes da versão copiados para a área de transferência';
}

// Path: settings.panels
class _Translations$settings$panels$pt_BR extends Translations$settings$panels$pt {
	_Translations$settings$panels$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Preferências do aplicativo';
	@override String get settingsDescription => 'Faça o app funcionar do seu jeito';
	@override String get commonSettings => 'Preferências comuns';
	@override String get syncDescription => 'Faça backup e sincronize seus logs entre dispositivos';
	@override String get accountsDescription => 'Credenciais de serviços, dados offline e mais';
	@override String get extensions => 'Extensões e funcionalidades';
	@override String get extensionsDescription => 'Atividades, concursos, painéis e mais funcionalidades';
	@override String get profilesDescription => 'Indicativo do operador e perfil da estação';
	@override String get stationProfiles => 'Perfis de estação';
	@override String get developerSettings => 'Configurações de desenvolvedor';
	@override String get developerSettingsDescription => 'Ferramentas de depuração e desenvolvimento';
	@override String get about => 'Sobre';
	@override String get aboutDescription => 'Versão, créditos e informações legais';
	@override String get unavailableTitle => 'Algumas configurações estão indisponíveis';
	@override String get unavailableText => 'O ambiente de extensões não iniciou, então as configurações fornecidas por extensões estão faltando.';
	@override String get station => 'Configuração da estação';
	@override String get stationDescription => 'Controle CAT e mais opções';
	@override String get peers => 'Dispositivos pareados';
	@override String get peersDescription => 'Conecte-se a outros dispositivos próximos';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$pt_BR extends Translations$settings$gridPrecisionOpts$pt {
	_Translations$settings$gridPrecisionOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos (FN31pr)';
	@override String get eight => '8 dígitos (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$pt_BR extends Translations$settings$gridPrecisionDescription$pt {
	_Translations$settings$gridPrecisionDescription$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos';
	@override String get eight => '8 dígitos';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$pt_BR extends Translations$home$logs$columns$pt {
	_Translations$home$logs$columns$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get date => 'Data';
	@override String get time => 'Hora';
	@override String get freq => 'Frequência';
	@override String get mode => 'Modo';
	@override String get call => 'Indicativo';
	@override String get name => 'Nome';
	@override String get station => 'Estação';
	@override String get band => 'Banda';
	@override String get sent => 'Enviado';
	@override String get rcvd => 'Recebido';
	@override String get grid => 'Grid';
	@override String get state => 'Estado';
	@override String get country => 'País';
	@override String get refs => 'Refs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$pt_BR extends Translations$home$logs$panels$pt {
	_Translations$home$logs$panels$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Log de QSOs';
	@override String get qsosDescription => 'Os QSOs do indicativo selecionado, em todas as operações.';
	@override String get info => 'Informações';
	@override String get infoDescription => 'Total de QSOs ou a consulta do indicativo do QSO selecionado.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'A localização do QSO selecionado.';
}

// Path: home.logs.import
class _Translations$home$logs$import$pt_BR extends Translations$home$logs$import$pt {
	_Translations$home$logs$import$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicativos: ${calls}';
	@override String get skippedOne => '1 registro não pôde ser lido';
	@override String skippedOther({required Object count}) => '${count} registros não puderam ser lidos';
	@override String get readingTitle => 'Lendo arquivo ADIF…';
	@override String get checkingTitle => 'Verificando duplicados…';
	@override String get importingTitle => 'Importando QSOs…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} de ${total} verificados';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importados de ${total}';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$pt_BR extends Translations$operation$layout$panels$pt {
	_Translations$operation$layout$panels$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'O log e os campos de entrada';
	@override String get infoDescription => 'O que sabemos sobre a estação contatada';
	@override String get spotsDescription => 'Spots dos clusters e dos programas de atividades';
	@override String get mapDescription => 'Onde estão os contatos';
	@override String get clockDescription => 'Um relógio, em qualquer fuso horário';
	@override String get clockFace => 'Mostrador';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analógico';
	@override String get clockZone => 'Fuso horário';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Este dispositivo';
	@override String get clockShowSeconds => 'Mostrar segundos';
	@override String get weatherDescription => 'Condições agora e nas próximas oito horas, onde você está operando';
	@override String get weatherUseOperationLocation => 'Usar a localização da operação';
	@override String get weatherLocation => 'Localização';
	@override String get weatherLocationDescription => 'Um grid square (FN31pr) ou lat,lon. Ignorado enquanto \'Usar a localização da operação\' estiver marcado.';
	@override String get weatherNoLocation => 'Nenhuma localização definida. Defina uma localização nas configurações deste painel ou coloque-o dentro de uma operação que tenha uma.';
	@override String weatherBadLocation({required Object location}) => 'Não foi possível ler a localização ${location}. Use um grid square como FN31pr ou 42.36,-71.06.';
	@override String get weatherUnreachable => 'Não foi possível acessar o Open-Meteo — sem rede? Tentaremos novamente em breve.';
	@override String get weatherUnreadable => 'O Open-Meteo respondeu, mas com algo ilegível. Tentaremos novamente em breve.';
	@override String weatherGusts({required Object speed}) => 'rajadas ${speed}';
	@override String get panelAgeNow => 'agora mesmo';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'há ${count} min',
		other: 'há ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'há ${count} h',
		other: 'há ${count} h',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$pt_BR weatherConditions = _Translations$operation$layout$panels$weatherConditions$pt_BR._(_root);
	@override String get websiteDescription => 'Uma página web de sua escolha, em um painel';
	@override String get websiteUrl => 'Endereço';
	@override String get websiteRefresh => 'Atualizar';
	@override String get websiteRefreshNever => 'Nunca';
	@override String get websiteRefresh1 => 'A cada minuto';
	@override String get websiteRefresh5 => 'A cada 5 minutos';
	@override String get websiteRefresh15 => 'A cada 15 minutos';
	@override String get websiteTitle => 'Nome do painel';
	@override String get websiteRefreshNow => 'Atualizar agora';
	@override String get websiteNoUrl => 'Nenhum endereço ainda. Abra as configurações deste painel para escolher uma página.';
	@override String get websiteBadUrl => 'Isso não parece um endereço web. Ele precisa começar com https://';
	@override String get websiteNotHttps => 'Apenas endereços https:// podem ser mostrados aqui.';
	@override String get websiteUnsupported => 'Páginas web não podem ser mostradas em um painel neste sistema.';
	@override String get websiteOpenExternally => 'Abrir no navegador';
	@override String websiteLoadFailed({required Object reason}) => 'Não foi possível carregar a página: ${reason}';
	@override String get remoteScreenDescription => 'Uma tela, app ou janela compartilhada por outro dos seus dispositivos.';
	@override String get remoteScreenTarget => 'Tela';
	@override String get remoteScreenChoose => 'Escolher uma tela…';
	@override String get remoteScreenPickerTitle => 'Telas compartilhadas';
	@override String get remoteScreenPickerEmpty => 'Nenhum dos seus dispositivos está compartilhando uma tela. Ative Compartilhar telas e janelas em Configurações → Dispositivos pareados, no dispositivo que você quer ver.';
	@override String get remoteScreenUnset => 'Nenhuma tela escolhida. Abra as configurações deste painel para escolher uma que seus outros dispositivos estejam compartilhando.';
	@override String get remoteScreenConnecting => 'Conectando…';
	@override String get remoteScreenPeerAway => 'Esse dispositivo não está conectado agora.';
	@override String get remoteScreenNotOffered => 'Esse dispositivo parou de compartilhar esta tela.';
	@override String get remoteScreenNoListener => 'Esse dispositivo não aceita conexões — verifique o firewall dele.';
	@override String get remoteScreenNoLan => 'As telas só são compartilhadas pela rede local, não por Bluetooth.';
	@override String get remoteScreenRefused => 'Esse dispositivo não quis compartilhar esta tela.';
	@override String get remoteScreenSettings => 'Configurações do painel';
	@override String get remoteScreenAdjust => 'Ajustar visualização';
	@override String get remoteScreenDetail => 'Detalhe';
	@override String get remoteScreenDetailStandard => 'Padrão';
	@override String get remoteScreenDetailHigh => 'Alto';
	@override String get remoteScreenDetailMaximum => 'Máximo';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Aproximar';
	@override String get remoteScreenZoomOut => 'Afastar';
	@override String get remoteScreenStopped => 'Essa tela ou janela não está mais sendo mostrada.';
	@override String get remoteScreenCaptureFailed => 'Esse dispositivo não conseguiu capturar essa tela — talvez precise da permissão de Gravação de Tela.';
	@override String get remoteScreenNoAnswer => 'Esse dispositivo não respondeu. Talvez o compartilhamento de tela não esteja ativado nele.';
	@override String get remoteScreenNoMedia => 'Não foi possível abrir uma conexão para a imagem. Verifique o firewall deste dispositivo.';
	@override String get solarDescription => 'Condições solares e geomagnéticas, com propagação banda a banda';
	@override String get solarUnreachable => 'Não foi possível acessar hamqsl.com — sem rede? Tentaremos novamente em breve.';
	@override String get solarUnreadable => 'hamqsl.com respondeu, mas sem uma leitura utilizável. Tentaremos novamente em breve.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Dia';
	@override String get solarBandNight => 'Noite';
	@override String get solarBandGood => 'Boa';
	@override String get solarBandFair => 'Regular';
	@override String get solarBandPoor => 'Ruim';
	@override String solarSources({required Object primary, required Object secondary}) => 'Fontes: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'A conexão está com dificuldades — pulando quadros.';
	@override String get remoteScreenStalled => 'Os quadros pararam de chegar — esta conexão pode ser lenta demais.';
	@override String get radioDescription => 'O painel frontal de um rádio — frequência, modo e potência, sob controle CAT';
	@override String get radioStyle => 'Estilo';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderno';
	@override String get radioRadio => 'Rádio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — nenhum rádio designado';
	@override String get radioNoRadio => 'Nenhum rádio para mostrar. Escolha um nas configurações deste painel ou adicione um em Configuração da estação.';
	@override String get radioNotConfigured => 'Este rádio ainda não está configurado. Escolha a porta ou o endereço dele em Configuração da estação.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Rádio não conectado';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Conectar este rádio';
	@override String get radioDisconnect => 'Desconectar este rádio';
	@override String get radioStale => 'SEM DADOS';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'ROE';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'ROE alta';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$pt_BR extends Translations$operation$export$compactFileNames$pt {
	_Translations$operation$export$compactFileNames$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usar nomes de arquivos compactos';
	@override String get descriptionOn => 'Nomes curtos feitos para envio, como N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nomes legíveis, como 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$pt_BR extends Translations$operation$export$includePrivateData$pt {
	_Translations$operation$export$includePrivateData$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Incluir informações privadas';
	@override String get descriptionOn => 'Nomes, endereços, e-mails, grid squares e notas são incluídos';
	@override String get descriptionOff => 'Nomes, endereços, e-mails, grid squares e notas ficam de fora';
	@override String get note => 'A exportação ADIF completa sempre inclui tudo';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$pt_BR extends Translations$operation$export$stash$pt {
	_Translations$operation$export$stash$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Adicione um endereço de e-mail primeiro';
	@override String get needsEmailBody => 'O armazenamento de arquivos do Ham2K envia seus arquivos para o endereço de e-mail da sua conta LoFi, e você entra com ele em stash.ham2k.net. Sua conta ainda não tem um e-mail confirmado — adicione-o em Configurações › Sincronização na nuvem.';
	@override String get openSyncSettings => 'Abrir Sincronização na nuvem';
	@override String get replaceTitle => 'O stash recente será substituído';
	@override String replaceBody({required Object name}) => 'Você enviou “${name}” há menos de 6 horas e ele ainda não foi baixado. Contas gratuitas mantêm um stash por vez, então enviar agora vai substituí-lo.';
	@override String get replaceConfirm => 'Enviar mesmo assim';
	@override String get failedTitle => 'Não foi possível enviar para o armazenamento do Ham2K';
	@override String get sentTitle => 'Enviado para o armazenamento do Ham2K';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Você pode recuperar este arquivo acessando **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.',
		other: 'Você pode recuperar estes arquivos acessando **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.',
	);
	@override String get mayHaveArrived => 'Sem resposta do stash — o arquivo pode ter chegado mesmo assim. Verifique stash.ham2k.net antes de enviar novamente';
	@override String get notSent => 'não enviado';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Este arquivo não chegou:',
		other: 'Estes ${count} arquivos não chegaram:',
	);
	@override String get emailOffer => 'Ou, para sua conveniência, podemos enviar um e-mail com um link direto.';
	@override String get emailMe => 'Enviar o link por e-mail';
	@override String get emailSent => 'Enviamos um link de download para seu e-mail.';
	@override String emailFailed({required Object error}) => 'Não foi possível enviar o e-mail: ${error}';
	@override String get freeTier => 'Contas gratuitas só podem manter um stash por vez. Assinantes podem manter quantos quiserem.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} arquivo enviado para o armazenamento do Ham2K (stash.ham2k.net)',
		other: '${count} arquivos enviados para o armazenamento do Ham2K (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$pt_BR extends Translations$operation$spots$continents$pt {
	_Translations$operation$spots$continents$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get af => 'África';
	@override String get as => 'Ásia';
	@override String get eu => 'Europa';
	@override String get na => 'América do Norte';
	@override String get oc => 'Oceania';
	@override String get sa => 'América do Sul';
	@override String get an => 'Antártida';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$pt_BR extends Translations$operation$spots$filters$pt {
	_Translations$operation$spots$filters$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrar spots';
	@override String get band => 'Banda';
	@override String get mode => 'Modo';
	@override String get age => 'Idade';
	@override String get sources => 'Origens';
	@override String get continent => 'Continente';
	@override String get sorting => 'Ordenação';
	@override String get sortByTime => 'Por hora do spot';
	@override String get sortByFrequency => 'Por frequência';
	@override String get groupByBand => 'Agrupar por banda';
	@override String get groupCallsWithNotes => 'Agrupar indicativos com notas';
	@override String get sourceNoReply => 'Sem resposta';
	@override String get sourceError => 'Erro';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$pt_BR extends Translations$operation$spots$logConflict$pt {
	_Translations$operation$spots$logConflict$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'O painel de registro está ocupado';
	@override String get editingBody => 'Você está editando um contato registrado. Registrar este spot no lugar ou voltar e terminar a edição?';
	@override String get composingBody => 'Você começou a inserir um contato. Registrar este spot no lugar ou voltar e terminar o que estava digitando?';
	@override String get goBack => 'Voltar';
	@override String get clearAndLog => 'Limpar e registrar spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$pt_BR extends Translations$settings$logging$leftieMode$pt {
	_Translations$settings$logging$leftieMode$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo canhoto';
	@override String get descriptionOn => 'Usando o layout para canhotos';
	@override String get descriptionOff => 'Usando o layout para destros';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$pt_BR extends Translations$settings$logging$countryFlags$pt {
	_Translations$settings$logging$countryFlags$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bandeiras de países';
	@override String get dx => 'Mostrar apenas para contatos DX';
	@override String get all => 'Mostrar bandeiras para todos os contatos';
	@override String get none => 'Não mostrar bandeiras';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$pt_BR extends Translations$settings$logging$countryFlagsDescription$pt {
	_Translations$settings$logging$countryFlagsDescription$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Mostrando bandeiras apenas para contatos DX';
	@override String get all => 'Mostrando bandeiras para todos os contatos';
	@override String get none => 'Não mostrando nenhuma bandeira';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$pt_BR extends Translations$settings$logging$suggestDefaultOperator$pt {
	_Translations$settings$logging$suggestDefaultOperator$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sugerir operador';
	@override String get descriptionOn => 'Oferecendo seu indicativo como operador quando uma operação usa um indicativo de estação diferente';
	@override String get descriptionOff => 'Deixando o operador em branco, a menos que você o preencha';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$pt_BR extends Translations$settings$logging$showBearing$pt {
	_Translations$settings$logging$showBearing$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar azimute';
	@override String get descriptionOn => 'Mostrando o azimute estimado para a estação';
	@override String get descriptionOff => 'Não mostrando informações de azimute';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$pt_BR extends Translations$settings$logging$showReverseBearing$pt {
	_Translations$settings$logging$showReverseBearing$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar também azimute reverso';
	@override String get descriptionOn => 'Mostrando também o azimute a partir da estação, como "45° / 225°"';
	@override String get descriptionOff => 'Mostrando apenas o azimute para a estação';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$pt_BR extends Translations$settings$logging$switchSentRcvd$pt {
	_Translations$settings$logging$switchSentRcvd$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inverter ordem do reporte de sinal';
	@override String get sentFirst => 'Enviado primeiro, Recebido depois';
	@override String get rcvdFirst => 'Recebido primeiro, Enviado depois';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$pt_BR extends Translations$settings$logging$jumpAfterRST$pt {
	_Translations$settings$logging$jumpAfterRST$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Pular para o próximo campo ao inserir RST';
	@override String get descriptionOn => 'Avançando depois que o RST é inserido';
	@override String get descriptionOff => 'Não avançando automaticamente';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$pt_BR extends Translations$settings$logging$defaultReport$pt {
	_Translations$settings$logging$defaultReport$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte padrão — Fonia';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio em SSB, FM ou AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$pt_BR extends Translations$settings$logging$defaultReportCW$pt {
	_Translations$settings$logging$defaultReportCW$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte padrão — CW e dados';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio em CW, RTTY e outros modos digitais';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$pt_BR extends Translations$settings$logging$defaultReportFT8$pt {
	_Translations$settings$logging$defaultReportFT8$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Reporte padrão — FT8 e FT4';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio nos modos FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$pt_BR extends Translations$settings$logging$numbersRow$pt {
	_Translations$settings$logging$numbersRow$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Linha de números';
	@override String get description => 'Mostrar uma linha de teclas numéricas acima do teclado durante o registro';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$pt_BR extends Translations$settings$logging$numbersRowExtra$pt {
	_Translations$settings$logging$numbersRowExtra$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tecla de barra e ponto';
	@override String get description => 'Adiciona uma tecla contextual: “/” para indicativos, “.” para números';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$pt_BR extends Translations$settings$logging$numbersRowVibrate$pt {
	_Translations$settings$logging$numbersRowVibrate$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrar ao pressionar teclas';
	@override String get description => 'Resposta tátil ao tocar em uma tecla numérica';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$pt_BR extends Translations$settings$catServer$protocolOpts$pt {
	_Translations$settings$catServer$protocolOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get off => 'Desativado';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$pt_BR extends Translations$settings$radio$units$pt {
	_Translations$settings$radio$units$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$pt_BR extends Translations$settings$radio$pttKey$pt {
	_Translations$settings$radio$pttKey$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlar PTT com [\']';
	@override String get descriptionOn => 'Nos modos de fonia, [\'] aciona o rádio e [\'] de novo o libera. Ele se libera sozinho depois de um minuto.';
	@override String get descriptionOff => 'A tecla [\'] não aciona o rádio.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Transmitindo';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$pt_BR extends Translations$settings$radio$smartVfoSnap$pt {
	_Translations$settings$radio$smartVfoSnap$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente do VFO';
	@override String get descriptionOn => 'Quando você para de girar o dial, a frequência é arredondada para um passo razoável. Apenas modos de voz.';
	@override String get descriptionOff => 'Fica exatamente onde você sintonizou.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$pt_BR extends Translations$settings$radio$snapDebounce$pt {
	_Translations$settings$radio$snapDebounce$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: Tempo de espera';
	@override String get description => 'Quanto tempo o dial precisa ficar parado antes de a frequência ser arredondada. Mais curto parece imediato; mais longo dá espaço para um movimento lento.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$pt_BR extends Translations$settings$radio$snapLongMove$pt {
	_Translations$settings$radio$snapLongMove$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: Movimento longo';
	@override String get description => 'Mova pelo menos isto e a frequência é arredondada para um kHz inteiro, por mais devagar que você tenha terminado.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$pt_BR extends Translations$settings$radio$snapMinMove$pt {
	_Translations$settings$radio$snapMinMove$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: Menor movimento';
	@override String get description => 'Mova menos que isto e a frequência não é arredondada, então a sintonia fina não é alterada.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$pt_BR extends Translations$settings$radio$snapMinSpeed$pt {
	_Translations$settings$radio$snapMinSpeed$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuste inteligente: Movimento mais lento';
	@override String get description => 'Gire o dial mais devagar que isto e a frequência não é arredondada, a menos que tenha sido um movimento longo.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$pt_BR extends Translations$settings$radio$enterSends$pt {
	_Translations$settings$radio$enterSends$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Desl.';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter envia mensagens';
	@override String get off => 'Desligado';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter envia mensagens: ${state}. Toque para alterar.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$pt_BR extends Translations$settings$radio$keyerSpeed$pt {
	_Translations$settings$radio$keyerSpeed$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Velocidade do manipulador';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$pt_BR extends Translations$settings$radio$cwMessages$pt {
	_Translations$settings$radio$cwMessages$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensagens de CW do manipulador';
	@override String get notSupported => 'O rádio atual não suporta manipulação de CW';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Mensagem (${n})';
	@override String get labelField => 'Rótulo';
	@override String labelKey({required Object n}) => 'Rótulo de F${n}';
	@override String get details => 'Detalhes';
	@override String get empty => '(vazia)';
	@override String get sets => 'Conjunto de mensagens';
	@override String get newSet => 'Novo conjunto';
	@override String get renameSet => 'Renomear conjunto';
	@override String get deleteSet => 'Excluir conjunto';
	@override String get newSetName => 'Nome';
	@override String get setDefault => 'Padrão';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Mensagens ESM';
	@override String get setSaved => 'Minhas mensagens';
	@override String get repeat => 'Repetir mensagem nº 1';
	@override String get repeatOff => 'Não';
	@override String repeatAfter({required Object n}) => 'Após ${n} segundos';
	@override String get repeatWait => 'Repetindo';
	@override String get keyboard => 'Digite para enviar';
	@override String get keyboardField => 'Digite para enviar';
	@override String get closeArea => 'Fechar a área do manipulador';
	@override String get help => 'Ajuda';
	@override String get helpTitle => 'Escrevendo mensagens de CW';
	@override String get helpIntro => 'As mensagens podem usar modelos com os seguintes valores:';
	@override String get helpOpCall => 'Seu indicativo';
	@override String get helpQsoCall => 'O indicativo deles — em uma pilha //, o indicativo que será registrado';
	@override String get helpQsoFullCall => 'O indicativo deles, se houver um indicativo válido; vazio para um parcial';
	@override String get helpQsoPartial => 'Um indicativo parcial; vazio se houver um indicativo completo válido';
	@override String get helpQsoNextCall => 'Em uma pilha //, o indicativo que será selecionado para o próximo registro, se houver um indicativo completo válido';
	@override String get helpQsoNextPartial => 'Em uma pilha //, o próximo parcial depois de registrar o contato atual';
	@override String get helpQsoName => 'O primeiro nome deles, como digitado ou, senão, da consulta';
	@override String get helpQsoState => 'O estado deles, como digitado ou, senão, da consulta';
	@override String get helpKeyerMsg => 'A mensagem 1 como seria enviada, dentro de outra mensagem. Válido para as mensagens 1 a 8';
	@override String get helpQsoRst => 'O reporte que você está enviando';
	@override String get helpQsoSerial => 'Seu número de série, em um concurso que envia um';
	@override String get helpPad => 'Completa com zeros até esse número de dígitos: 7 é enviado como 007';
	@override String get helpCut => 'Números abreviados, T para 0 e N para 9: 599 é enviado como 5NN';
	@override String get helpCutDigits => 'Escolhe os dígitos a abreviar, entre aspas — 0 é T, 1 é A, 5 é E, 9 é N';
	@override String get helpFullExample => 'Exemplo completo:';
	@override String get helpExample => 'Envia W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Com Enter envia mensagens ativado, o Enter transmite as mensagens pela tecla de função, como faz o N1MM. O conjunto Mensagens ESM começa com estas:';
	@override String get helpEsmCq => 'Em Run, Enter com o campo de indicativo vazio chama CQ';
	@override String get helpEsmExchange => 'Seu reporte: depois do indicativo deles em Run, depois que eles respondem em S&P';
	@override String get helpEsmThanks => 'Agradecimento, depois que o contato é registrado: seus marcadores se referem ao próximo contato, não a este';
	@override String get helpEsmMyCall => 'Em S&P, seu indicativo para a estação que você está respondendo';
	@override String get helpEsmHisCall => 'Em Run, o indicativo deles antes do seu reporte';
	@override String get helpEsmAgain => 'Pede de novo quando nada do reporte deles foi copiado';
	@override String get helpEsmStackThanks => 'F3 sugerido para pilhas //: o TU sai depois que o contato é registrado, então agradece, chama a próxima estação da pilha e envia seu reporte, ou pede um parcial de volta (TU KR?); sem mais nada, só TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$pt_BR extends Translations$settings$radio$voiceMessages$pt {
	_Translations$settings$radio$voiceMessages$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensagens de fonia do manipulador';
	@override String get notSupported => 'O rádio atual não suporta mensagens de fonia';
	@override String get description => 'Usa as memórias de voz do rádio';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memória de voz (${n})';
	@override String get labelField => 'Rótulo';
	@override String labelKey({required Object n}) => 'Rótulo da memória de voz ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Vazia';
	@override String get notMeasured => 'Duração desconhecida';
	@override String get playButton => 'Reproduzir';
	@override String get recordButton => 'Gravar';
	@override String get stopButton => 'Parar';
	@override String get repeat => 'Repetir mensagem nº 1';
	@override String get repeatOff => 'Não';
	@override String repeatAfter({required Object n}) => 'Após ${n} segundos';
	@override String recordHelpTitle({required Object model}) => 'Notas do ${model}:';
	@override String namedOnDevice({required Object device}) => 'Estas memórias estão no rádio de ${device}. Os nomes e durações pertencem a esse dispositivo.';
	@override String get namedOnRadio => 'Salvo no rádio, onde os outros clientes dele também o veem.';
	@override String get recordHelpYaesuDvs => 'Aguarde o indicador [REC] no rádio, depois segure o botão PTT e grave sua mensagem. Termine pressionando o botão PARAR aqui no app antes de soltar o PTT, para evitar cliques indesejados.';
	@override String get recordHelpFt891 => 'Aguarde o indicador [REC] piscar pelo menos quatro vezes, depois segure o botão PTT e grave sua mensagem. Termine pressionando o botão PARAR aqui no app antes de soltar o PTT, para evitar cliques indesejados.';
	@override String get pill => 'Voz';
	@override String play({required Object n}) => 'Reproduzir memória ${n}';
	@override String get stop => 'Parar';
	@override String record({required Object n}) => 'Gravar memória ${n}';
	@override String get stopRecording => 'Parar gravação';
	@override String get playing => 'Reproduzindo…';
	@override String get recording => 'Gravando…';
	@override String playingMemory({required Object label}) => 'Reproduzindo ${label}';
	@override String recordingMemory({required Object label}) => 'Gravando ${label}';
	@override String get doubtful => 'O rádio reproduziu? Ele informou que estava ocioso logo em seguida.';
	@override String get recordOnRadio => 'Você precisa gravar as memórias no próprio rádio.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$pt_BR extends Translations$settings$radio$avoidZeroBeat$pt {
	_Translations$settings$radio$avoidZeroBeat$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evitar batimento zero em spots';
	@override String get descriptionOn => 'Com um rádio conectado, sintoniza alguns Hz fora de um spot de CW, para que nem todos que respondem chamem na mesma nota.';
	@override String get descriptionOff => 'Sintoniza exatamente na frequência do spot.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$pt_BR extends Translations$settings$radio$zeroBeatRange$pt {
	_Translations$settings$radio$zeroBeatRange$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Batimento zero: Faixa de desvio';
	@override String get description => 'Quão longe da frequência do spot parar, para qualquer lado. O desvio nunca fica perto de zero — isso seria batimento zero de novo.';
}

// Path: settings.map.style
class _Translations$settings$map$style$pt_BR extends Translations$settings$map$style$pt {
	_Translations$settings$map$style$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estilo do mapa';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$pt_BR extends Translations$settings$map$styleOpts$pt {
	_Translations$settings$map$styleOpts$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automático';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$pt_BR extends Translations$settings$privacy$shareAppData$pt {
	_Translations$settings$privacy$shareAppData$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartilhar dados de uso do app';
	@override String get descriptionOn => 'Ajudando a melhorar o app ao compartilhar dados de uso, configuração, falhas e desempenho';
	@override String get descriptionOff => 'Mantendo privados os dados de uso do app.\nA equipe do Ham2K não poderá detectar falhas ou outros problemas.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$pt_BR extends Translations$settings$privacy$shareOpData$pt {
	_Translations$settings$privacy$shareOpData$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Compartilhar dados de operação';
	@override String get descriptionOn => 'Compartilhando alguns dados de operação publicamente e com outros usuários';
	@override String get descriptionOff => 'Mantendo os dados de operação privados';
}

// Path: settings.station.models
class _Translations$settings$station$models$pt_BR extends Translations$settings$station$models$pt {
	_Translations$settings$station$models$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Genérico';
	@override String get icomGeneric => 'Icom - Genérico';
	@override String get kenwoodGeneric => 'Kenwood - Genérico';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Genérico';
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
	@override String get rigctld => 'Rádio controlado via rigctld';
	@override String get rigctldNodeName => 'Meu rádio (via rigctld)';
	@override String get flrig => 'Rádio controlado via flrig';
	@override String get flrigNodeName => 'Meu rádio (via flrig)';
	@override String get hrd => 'Rádio controlado via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Meu rádio (via HRD)';
	@override String get n3fjp => 'Rádio controlado via N3FJP';
	@override String get n3fjpNodeName => 'Meu rádio (via N3FJP)';
	@override String get commander => 'Rádio controlado via DXLab Commander';
	@override String get commanderNodeName => 'Meu rádio (via Commander)';
	@override String get antenna => 'Antena';
	@override String get key => 'Chave de CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Rádio genérico (provisório)';
	@override String get placeholderRadioNodeName => 'Meu rádio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Chave coaxial Sierra Radio CX-1';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$pt_BR extends Translations$settings$station$transports$pt {
	_Translations$settings$station$transports$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get network => 'Rede/WiFi';
	@override String get usbSerial => 'Serial USB';
	@override String get wifi => 'Rede/WiFi';
	@override String get bluetoothSerial => 'Serial Bluetooth';
	@override String get placeholder => 'Provisório';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$pt_BR extends Translations$settings$station$antennaTypes$pt {
	_Translations$settings$station$antennaTypes$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipolo';
	@override String get vertical => 'Vertical';
	@override String get yagiBeam => 'Yagi / Direcional';
	@override String get loop => 'Loop';
	@override String get longWire => 'Fio longo / EFHW';
	@override String get other => 'Outra';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$pt_BR extends Translations$settings$station$keyTypes$pt {
	_Translations$settings$station$keyTypes$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Chave vertical';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semiautomática mecânica)';
	@override String get fullyAutomatic => 'Keyer totalmente automático';
	@override String get singlePaddle => 'Paddle simples';
	@override String get dualPaddle => 'Paddle duplo';
	@override String get computerDriven => 'Controlada por computador';
	@override String get other => 'Outra';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$pt_BR extends Translations$operation$layout$panels$weatherConditions$pt {
	_Translations$operation$layout$panels$weatherConditions$pt_BR._(TranslationsPtBr root) : this._root = root, super.internal(root);

	final TranslationsPtBr _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Desconhecido';
	@override String get sunny => 'Ensolarado';
	@override String get clear => 'Céu limpo';
	@override String get mainlySunny => 'Predominantemente ensolarado';
	@override String get mainlyClear => 'Predominantemente limpo';
	@override String get partlyCloudy => 'Parcialmente nublado';
	@override String get cloudy => 'Nublado';
	@override String get foggy => 'Neblina';
	@override String get rimeFog => 'Neblina com geada';
	@override String get lightDrizzle => 'Garoa fraca';
	@override String get drizzle => 'Garoa';
	@override String get heavyDrizzle => 'Garoa forte';
	@override String get lightFreezingDrizzle => 'Garoa congelante fraca';
	@override String get freezingDrizzle => 'Garoa congelante';
	@override String get lightRain => 'Chuva fraca';
	@override String get rain => 'Chuva';
	@override String get heavyRain => 'Chuva forte';
	@override String get lightFreezingRain => 'Chuva congelante fraca';
	@override String get freezingRain => 'Chuva congelante';
	@override String get lightSnow => 'Neve fraca';
	@override String get snow => 'Neve';
	@override String get heavySnow => 'Neve forte';
	@override String get snowGrains => 'Grãos de neve';
	@override String get lightShowers => 'Pancadas fracas';
	@override String get showers => 'Pancadas de chuva';
	@override String get heavyShowers => 'Pancadas fortes';
	@override String get lightSnowShowers => 'Pancadas de neve fracas';
	@override String get snowShowers => 'Pancadas de neve';
	@override String get thunderstorm => 'Tempestade';
	@override String get lightThunderstormsWithHail => 'Tempestades fracas com granizo';
	@override String get thunderstormWithHail => 'Tempestade com granizo';
}

/// The flat map containing all translations for locale <pt-BR>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsPtBr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Salvar',
			'common.ok' => 'OK',
			'common.cancel' => 'Cancelar',
			'common.delete' => 'Excluir',
			'common.create' => 'Criar',
			'common.error' => 'Erro',
			'common.close' => 'Fechar',
			'common.done' => 'Concluído',
			'common.callsign' => 'Indicativo',
			'common.clear' => 'Limpar',
			'common.dismiss' => 'Dispensar',
			'common.expand' => 'Expandir',
			'common.collapse' => 'Recolher',
			'onboarding.welcomeTitle' => 'Bem-vindo ao Ham2K Portable Logger!',
			'onboarding.welcomeTitleDesktop' => 'Bem-vindo ao Ham2K Power Logger!',
			'onboarding.welcomeBody' => 'Temos algumas perguntas para atender melhor às suas necessidades.',
			'onboarding.skip' => 'Pular',
			'onboarding.kContinue' => 'Continuar',
			'onboarding.back' => 'Voltar',
			'onboarding.next' => 'Avançar',
			'onboarding.done' => 'Concluído',
			'onboarding.callsignTitle' => 'Qual é o seu indicativo?',
			'onboarding.callsignBody' => 'Você precisa de uma licença de radioamador para que este app seja útil',
			'onboarding.callsignLabel' => 'Indicativo do operador',
			'onboarding.alreadyHaveAccount' => 'Já tem uma conta?',
			'onboarding.foundSiblingTitle' => 'Vincular uma conta existente?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Encontramos o ${app} neste dispositivo. Vincule este app à mesma conta e seu indicativo e seus logs serão trazidos.',
			'onboarding.foundPoloBody' => 'Encontramos uma versão antiga do Ham2K Portable Logger neste dispositivo. Vincule este app à mesma conta e seu indicativo e seus logs serão trazidos.',
			'onboarding.foundSiblingsBody' => 'Encontramos outros apps Ham2K neste dispositivo. Vincule este app à conta de um deles e seu indicativo e seus logs serão trazidos.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Vincular com ${app}',
			'onboarding.linkWithPolo' => 'Vincular com a conta da versão antiga',
			'onboarding.setUpFresh' => 'Começar do zero',
			'onboarding.activitiesTitle' => 'Atividades favoritas',
			'onboarding.activitiesBody' => 'Você tem interesse em algum destes programas de ativação populares?',
			'onboarding.activitiesFooter' => '(Você encontra mais opções nas Configurações)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Dados e privacidade',
			'onboarding.consentUsageBody' => 'Para nos ajudar a melhorar o app, gostaríamos de coletar dados de desempenho, falhas e uso do app.',
			'onboarding.consentUsageLabel' => 'Compartilhar dados de uso do app',
			'onboarding.consentOperationBody' => 'Alguns recursos podem envolver o compartilhamento dos seus dados de operação com outros usuários. Você pode desativar isso a qualquer momento.',
			'onboarding.consentOperationLabel' => 'Compartilhar dados de operação',
			'onboarding.finishingSetup' => 'Concluindo a configuração — baixando dados de referência…',
			'startScreen.credits' => 'por KI2D e amigos',
			'testerOverlay.tape' => 'CUIDADO: EM CONSTRUÇÃO',
			'testerOverlay.warningTitle' => 'Este app é um trabalho em andamento',
			'testerOverlay.warningBody' => 'A maioria dos recursos tem superfícies irregulares e há risco de tropeço por toda parte. Verifique se há atualizações regularmente.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novidades da build ${build}',
			'testerOverlay.thanks' => 'Obrigado por arriscar seu log para nos ajudar a melhorar este app!',
			'extensionsPanel.categoryActivity' => 'Atividades',
			'extensionsPanel.categoryContest' => 'Concursos',
			'extensionsPanel.categoryLookup' => 'Consultas de indicativo',
			'extensionsPanel.categorySpots' => 'Origens de spots',
			'extensionsPanel.categoryDashboard' => 'Painéis',
			'extensionsPanel.categoryOther' => 'Outras extensões',
			'extensionsPanel.searchHint' => 'Buscar extensões',
			'extensionsPanel.applying' => 'Ativando alterações de extensões, isso pode levar alguns instantes…',
			'extensionsPanel.noMatches' => 'Nenhuma extensão corresponde à sua busca',
			'extensionsPanel.installFromFile' => 'Instalar de arquivo…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versão ${version}',
			'extensionsPanel.canReach' => 'Esta extensão pode contatar',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, por uma conexão ativa',
			'extensionsPanel.canHoldLocalConnection' => 'Dispositivos na sua rede local, por uma conexão ativa',
			'extensionsPanel.canUseLocation' => 'Sua localização',
			'extensionsPanel.canReadRadio' => 'Seu rádio, para ler a frequência e o modo',
			'extensionsPanel.canControlRadio' => 'Seu rádio, para controlá-lo e transmitir com ele — sintonia, potência, CW, memórias de voz e PTT',
			'extensionsPanel.canSetUserAgent' => 'Identificar-se aos servidores com o próprio nome',
			'extensionsPanel.noCapabilities' => 'Não pede nada fora do app.',
			'extensionsPanel.sandboxNote' => 'As extensões rodam isoladas: sem acesso aos seus arquivos e sem rede além do que está listado aqui.',
			'extensionsPanel.installAction' => 'Instalar',
			'extensionsPanel.updateAction' => 'Atualizar',
			'extensionsPanel.installFailed' => 'Não foi possível instalar essa extensão',
			'extensionsPanel.installedBadge' => 'Instalada',
			'extensionsPanel.uninstallAction' => 'Remover',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Remover ${name}?',
			'extensionsPanel.uninstallBody' => 'Esta extensão e suas configurações serão removidas. Seus logs não serão alterados.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} instalada',
			'extensionsPanel.installDownloading' => 'Baixando…',
			'extensionsPanel.installWaiting' => 'Aguardando para instalar…',
			'extensionsPanel.installInstalling' => 'Instalando…',
			'extensionsPanel.installAwaitingApproval' => 'Aguardando sua aprovação…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} já está sendo instalada.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Atualizada para ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'A instalação de ${name} não terminou. Talvez seja preciso instalá-la novamente.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Não foi possível remover ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Baixada de ${source}',
			'extensionsPanel.dropHint' => 'Solte uma extensão .h2kext para instalá-la',
			'extensionsPanel.dropOneOnly' => 'Solte uma extensão por vez.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} retornou ${status} para essa extensão.',
			'extensionsPanel.downloadTooLarge' => 'Esse download é grande demais para ser uma extensão.',
			'extensionsPanel.downloadNotSecure' => 'Esse download foi redirecionado para um local inseguro.',
			'extensionsPanel.catalogSection' => 'Catálogo',
			'extensionsPanel.catalogLoading' => 'Carregando o catálogo…',
			'extensionsPanel.catalogUnreachable' => 'Catálogo inacessível',
			'extensionsPanel.builtIn' => 'Integrada',
			'extensionsPanel.updateAvailableBadge' => 'Atualização disponível',
			'extensionsPanel.updatesAvailableTitle' => 'Atualizações de extensões',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Há uma atualização disponível para ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} e mais ${count} precisam ser atualizadas.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} precisam ser atualizadas.',
			'extensionsPanel.pendingUpdatesSection' => 'Atualizações pendentes',
			'extensionsPanel.updateAllAction' => 'Atualizar todas',
			'extensionsPanel.updatesUnderWay' => 'Essas atualizações já estão em andamento.',
			'extensionsPanel.updatesNothingLeft' => 'Suas extensões estão atualizadas.',
			'extensionsPanel.updatesNoticeAction' => 'Mais informações',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Atualizar ${count} extensão?', other: 'Atualizar ${count} extensões?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Suas extensões estão prontas',
			'extensionsPanel.upgradeDoneBody' => 'Agora elas vêm do catálogo de extensões do Ham2K, então podem ser atualizadas sem esperar por uma nova versão do app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Não atualizadas: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Não puderam rodar: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Elas continuam instaladas e marcadas em Configurações › Extensões — atualizá-las lá as trará de volta.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'O catálogo não tem substituto direto para estas, então procure lá extensões que cubram o que você usava.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Eventos de parques estaduais',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} das suas extensões ainda não chegaram. Elas serão baixadas na próxima vez que o catálogo de extensões estiver acessível.',
			'extensionsPanel.runtimeDeadBody' => 'Suas extensões não iniciaram. Reiniciar o app deve trazê-las de volta.',
			'extensionsPanel.refusedTitle' => 'Algumas extensões não puderam rodar',
			'extensionsPanel.upgradeBusyTitle' => 'Ainda configurando',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Suas extensões não estão rodando',
			'extensionsPanel.restoreTitle' => 'Algumas das suas extensões estão faltando',
			'extensionsPanel.restoreBody' => 'Estas extensões que você instalou não estão neste dispositivo. Podemos baixá-las novamente do catálogo de extensões do Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Instaladas de um arquivo. Instale-as novamente a partir dos arquivos ou esqueça-as:',
			'extensionsPanel.restoreOtherCatalog' => 'Instaladas de outro catálogo de extensões, por isso não estão disponíveis aqui:',
			'extensionsPanel.restoreForget' => 'Esquecer',
			'extensionsPanel.restoreInstall' => 'Instalar',
			'extensionsPanel.restoreLater' => 'Mais tarde',
			'extensionsPanel.restoreInstalling' => 'Instalando suas extensões…',
			'extensionsPanel.restoreDoneTitle' => 'Suas extensões estão de volta',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Instaladas novamente: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Algumas extensões não puderam ser instaladas',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Não foi possível instalar: ${names}. Vamos oferecê-las novamente na próxima vez que você abrir o app.',
			'extensionsPanel.restoreBusyBody' => 'O app ainda está configurando suas extensões. Vamos oferecê-las novamente na próxima vez que você abrir o app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Nós as instalamos novamente, mas suas extensões não iniciaram. Reiniciar o app deve trazê-las de volta.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} foi retirada',
			'extensionsPanel.revokedBody' => 'O catálogo retirou esta versão, por isso ela foi desativada.',
			'extensionsPanel.downloadHashMismatch' => 'Esse download não é a extensão que o catálogo descreveu.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'O catálogo não tem a versão ${version} de ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Esse link do catálogo não indica uma versão de extensão.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'O catálogo não tem uma versão de ${key} nesse canal.',
			'extensionsPanel.installFromLink' => 'Instalar de link',
			'extensionsPanel.unstableReleaseWarning' => 'Esta é uma versão instável, que o autor ainda não considera concluída. Ela pode se comportar mal e continuará recebendo atualizações instáveis.',
			'extensionsPanel.bleedingReleaseWarning' => 'Esta é uma versão experimental: trabalho em andamento que pode quebrar ou perder suas configurações. Ela continuará recebendo atualizações experimentais.',
			'extensionsPanel.channelUnstable' => 'Instável',
			'extensionsPanel.channelBleeding' => 'Experimental',
			'extensionsPanel.followsUnstable' => 'Recebe versões instáveis e estáveis',
			'extensionsPanel.followsBleeding' => 'Recebe versões experimentais, instáveis e estáveis',
			'extensionsPanel.followStableAction' => 'Seguir apenas versões estáveis',
			'extensionsPanel.revokedBadge' => 'Revogada',
			'extensionsPanel.refusedBadge' => 'Não carregou',
			'extensionsPanel.downloadNotHttps' => 'Esse download não usa uma conexão segura.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'Não foi possível acessar ${source} para essa extensão.',
			'extensionsPanel.detailsAction' => 'Detalhes',
			'extensionsPanel.installedFromFile' => 'Instalada de um arquivo',
			'extensionsPanel.detailsWhatItDoes' => 'Oferece suporte para',
			'extensionsPanel.installedPreloaded' => 'Pré-instalada',
			'extensionsPanel.hookAccount' => 'Login de conta',
			'extensionsPanel.hookCallNotes' => 'Notas de indicativo',
			'extensionsPanel.hookDataFile' => 'Dados offline',
			'extensionsPanel.hookExport' => 'Exportação',
			'extensionsPanel.hookLookup' => 'Consultas de indicativo',
			'extensionsPanel.hookScoring' => 'Pontuação',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Caçando ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Ativando ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '… e mais ${count} extensão', other: '… e mais ${count} extensões', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} extensão disponível', other: '${count} extensões disponíveis', ), 
			'home.title' => 'Logger Portátil',
			'home.newOperation' => 'Nova operação',
			'home.stationCallsign' => 'Indicativo da estação',
			'home.titleOptional' => 'Título (opcional)',
			'home.emptyList' => 'Ainda não há operações. Crie uma para começar a registrar.',
			'home.quickLookup' => 'Consulta rápida',
			'home.nav.operations' => 'Operações',
			'home.nav.chase' => 'Caça',
			'home.nav.logs' => 'Logs',
			'home.nav.maps' => 'Mapas',
			'home.nav.settings' => 'Configurações',
			'home.panels.operations' => 'Lista de operações',
			'home.panels.operationsDescription' => 'Suas operações, as mais recentes primeiro.',
			'home.panels.version' => 'Versão atual',
			'home.panels.versionDescription' => 'A marca Ham2K, o nome deste app e qual build você está usando.',
			'home.toggleNav' => 'Mostrar ou ocultar os rótulos de navegação',
			'home.logs.title' => 'Logs',
			'home.logs.titleFor' => 'Logs de',
			'home.logs.emptyCallsigns' => 'Nenhum QSO registrado ainda',
			'home.logs.emptyQsos' => ({required Object call}) => 'Nenhum QSO de ${call}',
			'home.logs.mapNoSelection' => 'Selecione um QSO para vê-lo no mapa',
			'home.logs.searchHint' => 'Buscar indicativo ou nome',
			'home.logs.noSearchMatches' => 'Nenhum QSO corresponde à sua busca',
			'home.logs.titleAll' => 'Todos os logs',
			'home.logs.allCallsigns' => 'Todos os indicativos',
			'home.logs.noOperation' => 'Fora de uma operação',
			'home.logs.unsavedTitle' => 'Alterações não salvas',
			'home.logs.unsavedBody' => 'Este QSO tem alterações que você não salvou.',
			'home.logs.pendingDeleteBody' => 'Este QSO está marcado para exclusão.',
			'home.logs.editGone' => 'Não salvo: esse QSO não está mais neste log.',
			'home.logs.discard' => 'Descartar',
			'home.logs.columns.date' => 'Data',
			'home.logs.columns.time' => 'Hora',
			'home.logs.columns.freq' => 'Frequência',
			'home.logs.columns.mode' => 'Modo',
			'home.logs.columns.call' => 'Indicativo',
			'home.logs.columns.name' => 'Nome',
			'home.logs.columns.station' => 'Estação',
			'home.logs.columns.band' => 'Banda',
			'home.logs.columns.sent' => 'Enviado',
			'home.logs.columns.rcvd' => 'Recebido',
			'home.logs.columns.grid' => 'Grid',
			'home.logs.columns.state' => 'Estado',
			'home.logs.columns.country' => 'País',
			'home.logs.columns.refs' => 'Refs',
			'home.logs.panels.qsos' => 'Log de QSOs',
			'home.logs.panels.qsosDescription' => 'Os QSOs do indicativo selecionado, em todas as operações.',
			'home.logs.panels.info' => 'Informações',
			'home.logs.panels.infoDescription' => 'Total de QSOs ou a consulta do indicativo do QSO selecionado.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'A localização do QSO selecionado.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicativos: ${calls}',
			'home.logs.import.skippedOne' => '1 registro não pôde ser lido',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} registros não puderam ser lidos',
			'home.logs.import.readingTitle' => 'Lendo arquivo ADIF…',
			'home.logs.import.checkingTitle' => 'Verificando duplicados…',
			'home.logs.import.importingTitle' => 'Importando QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} de ${total} verificados',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importados de ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'caçando',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} e ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} e mais',
			'chase.station.title' => 'Estação de caça',
			'chase.station.stationLabel' => 'Estação: ',
			'chase.station.operatorLabel' => 'Op: ',
			'chase.station.noLocation' => 'Sem localização',
			'chase.periodInline.today' => 'hoje',
			'chase.periodInline.thisWeek' => 'esta semana',
			'chase.periodInline.last14Days' => 'nos últimos 14 dias',
			'chase.periodInline.thisMonth' => 'este mês',
			'chase.periodStats.today' => 'Estatísticas de hoje',
			'chase.periodStats.thisWeek' => 'Estatísticas desta semana',
			'chase.periodStats.last14Days' => 'Estatísticas dos últimos 14 dias',
			'chase.periodStats.thisMonth' => 'Estatísticas deste mês',
			'chase.period.today' => 'Hoje',
			'chase.period.thisWeek' => 'Esta semana',
			'chase.period.last14Days' => 'Últimos 14 dias',
			'chase.period.thisMonth' => 'Este mês',
			'chase.goals.title' => 'Metas de caça',
			'chase.goals.remove' => ({required Object name}) => 'Parar de caçar ${name}',
			'chase.goals.extensionsTitle' => 'Extensões que incluem caça',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Controles de registro acima dos QSOs caçados no período.',
			'chase.panels.info' => 'Informações',
			'chase.panels.infoDescription' => 'O indicativo sendo registrado ou as estatísticas do período.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Estações com spot no ar, prontas para caçar.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'Os QSOs do período e a estação sendo registrada.',
			'dialogs.operationDetails' => 'Detalhes da operação',
			'dialogs.activities' => 'Atividades',
			'dialogs.stationCallsign' => 'Indicativo da estação',
			'dialogs.notes' => 'Notas',
			'dialogs.deleteOperationTitle' => 'Excluir operação',
			'dialogs.purgeTestsTitle' => 'Eliminar operações de teste',
			'dialogs.purgeTestsBody' => 'Isso exclui permanentemente estas operações de teste e seus QSOs. Não pode ser desfeito.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Mais ${count} contato de teste que não pertence a nenhuma operação.', other: 'Mais ${count} contatos de teste que não pertencem a nenhuma operação.', ), 
			'dialogs.purgeTestsAction' => 'Eliminar',
			'dialogs.syncAllTitle' => 'Substituir o log deste dispositivo?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL faz backup e remove ${qsos} deste dispositivo e depois baixa novamente o log da conta do servidor. O backup fica no banco de dados deste dispositivo.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO ainda não foi sincronizado — o servidor nunca o recebeu e ele NÃO voltará.', other: '${n} QSOs ainda não foram sincronizados — o servidor nunca os recebeu e eles NÃO voltarão.', ), 
			'dialogs.syncAllAction' => 'Apagar e ressincronizar',
			'dialogs.receivedPurgesTitle' => 'Operações de teste removidas em outro lugar',
			'dialogs.receivedPurgesBody' => 'Estas foram excluídas como operações de teste em outro dispositivo. Removê-las aqui também? Isso as exclui permanentemente, junto com seus QSOs, e não pode ser desfeito.',
			'dialogs.receivedPurgesAction' => 'Remover',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicativo inválido: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicativos inválidos: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} operou até agora. ${typed} será registrado para novos contatos.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Nenhum operador registrado até agora. ${typed} será registrado para novos contatos.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Esta operação já tem contatos de ${calls}. ${typed} só será registrado para os novos.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Registrar também ${typed} como operador do contato já registrado', other: 'Registrar também ${typed} como operador de todos os ${count} contatos já registrados', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Ao usar várias estações no ar, não há suporte para operadores separados',
			'dialogs.callChange.contactsUnreadable' => 'Não foi possível ler os contatos desta operação, então alterar um indicativo aqui não oferecerá atualizá-los',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Não foi possível atualizar os contatos já registrados, então nenhuma alteração foi feita: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} de ${planned} contatos foram atualizados — o restante não está mais nesta operação',
			'operation.deletedReadOnly' => 'Esta operação foi excluída. Restaure-a para registrar ou fazer alterações.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Relógio',
			'operation.tabs.weather' => 'Clima',
			'operation.tabs.website' => 'Site',
			'operation.tabs.remoteScreen' => 'Tela remota',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Rádio',
			'operation.positions.nobodyYet' => 'Nenhuma outra posição de operação está compartilhando esta operação ainda.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Outra posição',
			'operation.positions.thisDevice' => 'Nossa posição de operação',
			'operation.positions.nameIn' => ' em ',
			'operation.positions.panelTitle' => 'Posições',
			'operation.positions.panelDescription' => 'O que cada posição de operação que compartilha esta operação está registrando agora.',
			'operation.stationCallsignNone' => 'Sem indicativo da estação',
			'operation.titleNone' => 'Sem título',
			'operation.deleteOperation' => 'Excluir operação',
			'operation.loggingControlsStale' => 'Os campos de atividade podem estar desatualizados — reabra a operação para atualizá-los',
			'operation.locationNone' => 'Não definida',
			'operation.generalOperation' => 'Operação geral',
			'operation.titleFor' => ({required Object value}) => 'para ${value}',
			'operation.titleAt' => ({required Object value}) => 'em ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Agora ${description}',
			'operation.testOperationSuffix' => 'Teste',
			'operation.menu.showRstFields' => 'Mostrar campos RST',
			'operation.menu.showStateField' => 'Mostrar campo de estado',
			'operation.menu.showGridField' => 'Mostrar campo de grid',
			'operation.menu.showDeletedQsos' => 'Mostrar QSOs excluídos',
			'operation.menu.showDeletedOps' => 'Mostrar operações excluídas',
			'operation.menu.showQsoNumbers' => 'Mostrar números dos QSOs',
			'operation.menu.lookupAllQsos' => 'Consultar todos os QSOs',
			'operation.menu.loggingSettingsTitle' => 'Configurações de registro',
			'operation.menu.mapSettingsTitle' => 'Configurações do mapa',
			'operation.menu.actionsSection' => 'Ações',
			'operation.layout.title' => 'Adicionar um painel',
			'operation.layout.availableSection' => 'Painéis disponíveis',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Configurações de ${panel}',
			'operation.layout.panelSettingsAction' => 'Configurações do painel',
			'operation.layout.viewName' => 'Visualização da operação',
			'operation.layout.viewOptions' => 'Opções de layout da visualização',
			'operation.layout.viewTitleBuiltIn' => 'Esta visualização é integrada ao app, assim como o nome dela',
			'operation.layout.resetOptions' => 'Restaurar padrões',
			'operation.layout.removePane' => 'Remover',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Restaurar ${panel} aos padrões?',
			'operation.layout.resetPaneConfirmBody' => 'O título, o cabeçalho e o tamanho voltam aos padrões. O resto do layout fica como está.',
			'operation.layout.resetViewConfirm' => 'Restaurar esta visualização ao layout padrão?',
			'operation.layout.resetViewConfirmBody' => 'Os painéis voltam à disposição padrão, e as opções da visualização e de cada painel voltam aos padrões.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Configurações de layout de ${panel}',
			'operation.layout.paneTitle' => 'Título',
			'operation.layout.paneShowHeader' => 'Mostrar cabeçalho',
			'operation.layout.paneShowHeaderTabset' => 'Sempre visível enquanto este painel compartilha um grupo — o cabeçalho é o acesso aos outros',
			'operation.layout.paneInherit' => 'Igual ao app',
			'operation.layout.searchHint' => 'Buscar painéis',
			'operation.layout.noPanelsMatch' => 'Nenhum painel corresponde à sua busca.',
			'operation.layout.nothingToAdd' => 'Esta visualização já tem todos os painéis possíveis',
			'operation.layout.addPanel' => ({required Object panel}) => 'Adicionar ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Pré-visualizar ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'A extensão "${name}" está faltando',
			'operation.layout.previewUnavailable' => 'Não foi possível mostrar a imagem de pré-visualização deste painel.',
			'operation.layout.nestedPaneTitle' => 'Mais',
			'operation.layout.editLayout' => 'Editar layout',
			'operation.layout.saveLayout' => 'Salvar layout',
			'operation.layout.revertLayout' => 'Descartar alterações do layout',
			'operation.layout.done' => 'Concluído',
			'operation.layout.layoutUnreadableTitle' => 'Não foi possível ler o layout',
			'operation.layout.layoutUnreadableBody' => 'Não foi possível ler seu layout salvo, então a disposição padrão está sendo mostrada. Ela não substituirá o original até você escolher mantê-la.',
			'operation.layout.layoutUnreadableAction' => 'Usar este layout',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => 'Não foi possível exibir ${panel}',
			'operation.layout.panelRenderRetry' => 'Tentar novamente',
			'operation.layout.panelActionFailed' => 'A ação do painel falhou. Tente novamente.',
			'operation.layout.panels.loggingDescription' => 'O log e os campos de entrada',
			'operation.layout.panels.infoDescription' => 'O que sabemos sobre a estação contatada',
			'operation.layout.panels.spotsDescription' => 'Spots dos clusters e dos programas de atividades',
			'operation.layout.panels.mapDescription' => 'Onde estão os contatos',
			'operation.layout.panels.clockDescription' => 'Um relógio, em qualquer fuso horário',
			'operation.layout.panels.clockFace' => 'Mostrador',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analógico',
			'operation.layout.panels.clockZone' => 'Fuso horário',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Este dispositivo',
			'operation.layout.panels.clockShowSeconds' => 'Mostrar segundos',
			'operation.layout.panels.weatherDescription' => 'Condições agora e nas próximas oito horas, onde você está operando',
			'operation.layout.panels.weatherUseOperationLocation' => 'Usar a localização da operação',
			'operation.layout.panels.weatherLocation' => 'Localização',
			'operation.layout.panels.weatherLocationDescription' => 'Um grid square (FN31pr) ou lat,lon. Ignorado enquanto \'Usar a localização da operação\' estiver marcado.',
			'operation.layout.panels.weatherNoLocation' => 'Nenhuma localização definida. Defina uma localização nas configurações deste painel ou coloque-o dentro de uma operação que tenha uma.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Não foi possível ler a localização ${location}. Use um grid square como FN31pr ou 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Não foi possível acessar o Open-Meteo — sem rede? Tentaremos novamente em breve.',
			'operation.layout.panels.weatherUnreadable' => 'O Open-Meteo respondeu, mas com algo ilegível. Tentaremos novamente em breve.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'rajadas ${speed}',
			'operation.layout.panels.panelAgeNow' => 'agora mesmo',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'há ${count} min', other: 'há ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'há ${count} h', other: 'há ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Desconhecido',
			'operation.layout.panels.weatherConditions.sunny' => 'Ensolarado',
			'operation.layout.panels.weatherConditions.clear' => 'Céu limpo',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Predominantemente ensolarado',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Predominantemente limpo',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parcialmente nublado',
			'operation.layout.panels.weatherConditions.cloudy' => 'Nublado',
			'operation.layout.panels.weatherConditions.foggy' => 'Neblina',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Neblina com geada',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Garoa fraca',
			'operation.layout.panels.weatherConditions.drizzle' => 'Garoa',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Garoa forte',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Garoa congelante fraca',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Garoa congelante',
			'operation.layout.panels.weatherConditions.lightRain' => 'Chuva fraca',
			'operation.layout.panels.weatherConditions.rain' => 'Chuva',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Chuva forte',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Chuva congelante fraca',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Chuva congelante',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Neve fraca',
			'operation.layout.panels.weatherConditions.snow' => 'Neve',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Neve forte',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Grãos de neve',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Pancadas fracas',
			'operation.layout.panels.weatherConditions.showers' => 'Pancadas de chuva',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Pancadas fortes',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Pancadas de neve fracas',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Pancadas de neve',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Tempestade',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Tempestades fracas com granizo',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Tempestade com granizo',
			'operation.layout.panels.websiteDescription' => 'Uma página web de sua escolha, em um painel',
			'operation.layout.panels.websiteUrl' => 'Endereço',
			'operation.layout.panels.websiteRefresh' => 'Atualizar',
			'operation.layout.panels.websiteRefreshNever' => 'Nunca',
			'operation.layout.panels.websiteRefresh1' => 'A cada minuto',
			'operation.layout.panels.websiteRefresh5' => 'A cada 5 minutos',
			'operation.layout.panels.websiteRefresh15' => 'A cada 15 minutos',
			'operation.layout.panels.websiteTitle' => 'Nome do painel',
			'operation.layout.panels.websiteRefreshNow' => 'Atualizar agora',
			'operation.layout.panels.websiteNoUrl' => 'Nenhum endereço ainda. Abra as configurações deste painel para escolher uma página.',
			'operation.layout.panels.websiteBadUrl' => 'Isso não parece um endereço web. Ele precisa começar com https://',
			'operation.layout.panels.websiteNotHttps' => 'Apenas endereços https:// podem ser mostrados aqui.',
			'operation.layout.panels.websiteUnsupported' => 'Páginas web não podem ser mostradas em um painel neste sistema.',
			'operation.layout.panels.websiteOpenExternally' => 'Abrir no navegador',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Não foi possível carregar a página: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Uma tela, app ou janela compartilhada por outro dos seus dispositivos.',
			'operation.layout.panels.remoteScreenTarget' => 'Tela',
			'operation.layout.panels.remoteScreenChoose' => 'Escolher uma tela…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Telas compartilhadas',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Nenhum dos seus dispositivos está compartilhando uma tela. Ative Compartilhar telas e janelas em Configurações → Dispositivos pareados, no dispositivo que você quer ver.',
			'operation.layout.panels.remoteScreenUnset' => 'Nenhuma tela escolhida. Abra as configurações deste painel para escolher uma que seus outros dispositivos estejam compartilhando.',
			'operation.layout.panels.remoteScreenConnecting' => 'Conectando…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Esse dispositivo não está conectado agora.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Esse dispositivo parou de compartilhar esta tela.',
			'operation.layout.panels.remoteScreenNoListener' => 'Esse dispositivo não aceita conexões — verifique o firewall dele.',
			'operation.layout.panels.remoteScreenNoLan' => 'As telas só são compartilhadas pela rede local, não por Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Esse dispositivo não quis compartilhar esta tela.',
			'operation.layout.panels.remoteScreenSettings' => 'Configurações do painel',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajustar visualização',
			'operation.layout.panels.remoteScreenDetail' => 'Detalhe',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Padrão',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Alto',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Máximo',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Aproximar',
			'operation.layout.panels.remoteScreenZoomOut' => 'Afastar',
			'operation.layout.panels.remoteScreenStopped' => 'Essa tela ou janela não está mais sendo mostrada.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Esse dispositivo não conseguiu capturar essa tela — talvez precise da permissão de Gravação de Tela.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Esse dispositivo não respondeu. Talvez o compartilhamento de tela não esteja ativado nele.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Não foi possível abrir uma conexão para a imagem. Verifique o firewall deste dispositivo.',
			'operation.layout.panels.solarDescription' => 'Condições solares e geomagnéticas, com propagação banda a banda',
			'operation.layout.panels.solarUnreachable' => 'Não foi possível acessar hamqsl.com — sem rede? Tentaremos novamente em breve.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com respondeu, mas sem uma leitura utilizável. Tentaremos novamente em breve.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Dia',
			'operation.layout.panels.solarBandNight' => 'Noite',
			'operation.layout.panels.solarBandGood' => 'Boa',
			'operation.layout.panels.solarBandFair' => 'Regular',
			'operation.layout.panels.solarBandPoor' => 'Ruim',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Fontes: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'A conexão está com dificuldades — pulando quadros.',
			'operation.layout.panels.remoteScreenStalled' => 'Os quadros pararam de chegar — esta conexão pode ser lenta demais.',
			'operation.layout.panels.radioDescription' => 'O painel frontal de um rádio — frequência, modo e potência, sob controle CAT',
			'operation.layout.panels.radioStyle' => 'Estilo',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderno',
			'operation.layout.panels.radioRadio' => 'Rádio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — nenhum rádio designado',
			'operation.layout.panels.radioNoRadio' => 'Nenhum rádio para mostrar. Escolha um nas configurações deste painel ou adicione um em Configuração da estação.',
			'operation.layout.panels.radioNotConfigured' => 'Este rádio ainda não está configurado. Escolha a porta ou o endereço dele em Configuração da estação.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Rádio não conectado',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Conectar este rádio',
			'operation.layout.panels.radioDisconnect' => 'Desconectar este rádio',
			'operation.layout.panels.radioStale' => 'SEM DADOS',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'ROE',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'ROE alta',
			'operation.layout.htmlPanelUnsupported' => 'Este painel precisa de uma web view, que esta plataforma não oferece',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Este painel precisa de um sandbox que a versão web não oferece',
			'operation.export.title' => 'Exportações da operação',
			'operation.export.syncedOperation' => 'A operação está sincronizada',
			'operation.export.unsyncedOperation' => 'A operação tem alterações não sincronizadas',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO nesta operação', other: '${count} QSOs nesta operação', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Todos os ${total} QSOs estão sincronizados',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} de ${total} QSOs com sincronização pendente',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcadores de evento sincronizados',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendentes',
			'operation.export.loading' => 'Carregando opções de exportação…',
			'operation.export.noOptions' => 'Nenhum formato de exportação disponível (as extensões ainda estão iniciando?)',
			'operation.export.nothingLogged' => 'Nada para exportar ainda — esta operação não tem QSOs.',
			'operation.export.share' => 'Compartilhar',
			'operation.export.nothingSelected' => 'Nada selecionado',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Salvar ${count} arquivo', other: 'Salvar ${count} arquivos', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Compartilhar ${count} arquivo', other: 'Compartilhar ${count} arquivos', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Exportar ${count} arquivo', other: 'Exportar ${count} arquivos', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Baixar ${count} arquivo', other: 'Baixar ${count} arquivos', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Salvar ${count} arquivo combinado', other: 'Salvar ${count} arquivos combinados', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Compartilhar ${count} arquivo combinado', other: 'Compartilhar ${count} arquivos combinados', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Exportar ${count} arquivo combinado', other: 'Exportar ${count} arquivos combinados', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Baixar ${count} arquivo combinado', other: 'Baixar ${count} arquivos combinados', ), 
			'operation.export.saveOne' => ({required Object name}) => 'Salvar ${name}',
			_ => null,
		} ?? switch (path) {
			'operation.export.shareOne' => ({required Object name}) => 'Compartilhar ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportar ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Baixar ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Armazenar ${count} arquivo', other: 'Armazenar ${count} arquivos', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Armazenar ${count} arquivo combinado', other: 'Armazenar ${count} arquivos combinados', ), 
			'operation.export.settingsButton' => 'Configurações de exportação',
			'operation.export.settingsTitle' => 'Configurações de exportação',
			'operation.export.compactFileNames.title' => 'Usar nomes de arquivos compactos',
			'operation.export.compactFileNames.descriptionOn' => 'Nomes curtos feitos para envio, como N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nomes legíveis, como 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Incluir informações privadas',
			'operation.export.includePrivateData.descriptionOn' => 'Nomes, endereços, e-mails, grid squares e notas são incluídos',
			'operation.export.includePrivateData.descriptionOff' => 'Nomes, endereços, e-mails, grid squares e notas ficam de fora',
			'operation.export.includePrivateData.note' => 'A exportação ADIF completa sempre inclui tudo',
			'operation.export.resultTitle' => 'Exportação concluída',
			'operation.export.resultFailedTitle' => 'A exportação falhou',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} arquivo exportado para ${path}', other: '${count} arquivos exportados para ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} arquivo exportado: ${path}', other: '${count} arquivos exportados: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} arquivo compartilhado', other: '${count} arquivos compartilhados', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} arquivo baixado', other: '${count} arquivos baixados', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'A exportação falhou: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Adicione um endereço de e-mail primeiro',
			'operation.export.stash.needsEmailBody' => 'O armazenamento de arquivos do Ham2K envia seus arquivos para o endereço de e-mail da sua conta LoFi, e você entra com ele em stash.ham2k.net. Sua conta ainda não tem um e-mail confirmado — adicione-o em Configurações › Sincronização na nuvem.',
			'operation.export.stash.openSyncSettings' => 'Abrir Sincronização na nuvem',
			'operation.export.stash.replaceTitle' => 'O stash recente será substituído',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Você enviou “${name}” há menos de 6 horas e ele ainda não foi baixado. Contas gratuitas mantêm um stash por vez, então enviar agora vai substituí-lo.',
			'operation.export.stash.replaceConfirm' => 'Enviar mesmo assim',
			'operation.export.stash.failedTitle' => 'Não foi possível enviar para o armazenamento do Ham2K',
			'operation.export.stash.sentTitle' => 'Enviado para o armazenamento do Ham2K',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Você pode recuperar este arquivo acessando **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.', other: 'Você pode recuperar estes arquivos acessando **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.', ), 
			'operation.export.stash.mayHaveArrived' => 'Sem resposta do stash — o arquivo pode ter chegado mesmo assim. Verifique stash.ham2k.net antes de enviar novamente',
			'operation.export.stash.notSent' => 'não enviado',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Este arquivo não chegou:', other: 'Estes ${count} arquivos não chegaram:', ), 
			'operation.export.stash.emailOffer' => 'Ou, para sua conveniência, podemos enviar um e-mail com um link direto.',
			'operation.export.stash.emailMe' => 'Enviar o link por e-mail',
			'operation.export.stash.emailSent' => 'Enviamos um link de download para seu e-mail.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Não foi possível enviar o e-mail: ${error}',
			'operation.export.stash.freeTier' => 'Contas gratuitas só podem manter um stash por vez. Assinantes podem manter quantos quiserem.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} arquivo enviado para o armazenamento do Ham2K (stash.ham2k.net)', other: '${count} arquivos enviados para o armazenamento do Ham2K (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Nenhum spot corresponde aos seus filtros',
			'operation.spots.error' => ({required Object error}) => 'Falha ao carregar spots: ${error}',
			'operation.spots.unknownBand' => 'Outra',
			'operation.spots.auto' => 'Automático',
			'operation.spots.autoValue' => ({required Object value}) => 'Automático (atual ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Qualquer',
			'operation.spots.allBands' => 'Todas as bandas',
			'operation.spots.allModes' => 'Todos os modos',
			'operation.spots.phoneAndCw' => 'Fonia e CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Mostrando ${count} de ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutos',
			'operation.spots.callsOfNote' => 'Indicativos com notas',
			'operation.spots.yourSpots' => 'Seus spots',
			'operation.spots.allSpots' => 'Todos os spots',
			'operation.spots.continents.af' => 'África',
			'operation.spots.continents.as' => 'Ásia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'América do Norte',
			'operation.spots.continents.oc' => 'Oceania',
			'operation.spots.continents.sa' => 'América do Sul',
			'operation.spots.continents.an' => 'Antártida',
			'operation.spots.filters.title' => 'Filtrar spots',
			'operation.spots.filters.band' => 'Banda',
			'operation.spots.filters.mode' => 'Modo',
			'operation.spots.filters.age' => 'Idade',
			'operation.spots.filters.sources' => 'Origens',
			'operation.spots.filters.continent' => 'Continente',
			'operation.spots.filters.sorting' => 'Ordenação',
			'operation.spots.filters.sortByTime' => 'Por hora do spot',
			'operation.spots.filters.sortByFrequency' => 'Por frequência',
			'operation.spots.filters.groupByBand' => 'Agrupar por banda',
			'operation.spots.filters.groupCallsWithNotes' => 'Agrupar indicativos com notas',
			'operation.spots.filters.sourceNoReply' => 'Sem resposta',
			'operation.spots.filters.sourceError' => 'Erro',
			'operation.spots.unavailableTitle' => 'Spots indisponíveis',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} não respondeu.',
			'operation.spots.failedTitle' => 'Erro na origem de spots',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} retornou um erro.',
			'operation.spots.slideLogIt' => 'Registrar',
			'operation.spots.slideIgnore' => 'Ignorar',
			'operation.spots.slideRestore' => 'Restaurar',
			'operation.spots.logConflict.title' => 'O painel de registro está ocupado',
			'operation.spots.logConflict.editingBody' => 'Você está editando um contato registrado. Registrar este spot no lugar ou voltar e terminar a edição?',
			'operation.spots.logConflict.composingBody' => 'Você começou a inserir um contato. Registrar este spot no lugar ou voltar e terminar o que estava digitando?',
			'operation.spots.logConflict.goBack' => 'Voltar',
			'operation.spots.logConflict.clearAndLog' => 'Limpar e registrar spot',
			'operation.import.title' => 'Importar dados para a operação',
			'operation.import.importAdifAction' => 'Importar QSOs de ADIF',
			'operation.import.settingsButton' => 'Configurações de escuta',
			'operation.import.settingsTitle' => 'Escutar outros apps',
			'operation.import.protocolAddressLabel' => 'Endereço',
			'operation.import.protocolPortLabel' => 'Porta',
			'operation.import.protocolPortInvalid' => 'Insira uma porta entre 1 e 65535',
			'operation.import.protocolAddressInvalid' => 'Insira um endereço IP válido (ex. 127.0.0.1 ou 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Recebendo dados',
			'operation.import.protocolStatusNoData' => 'Nenhum dado recebido recentemente',
			'operation.import.protocolBindError' => ({required Object error}) => 'Não foi possível começar a escutar: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Não foi possível salvar os QSOs recebidos; tentando novamente: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Qualquer (broadcast)',
			'operation.import.wsjtxProtocolName' => 'Servidor UDP do WSJT-X',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → aba Broadcast Data → marque "Enable Broadcasts" para as informações de contato. Defina o endereço IP como 127.0.0.1 se estiver rodando neste mesmo computador, ou 255.255.255.255 para transmitir na rede local atual.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → aba Reporting → seção UDP Server → marque "Accept UDP requests". Defina UDP Server como 127.0.0.1 se estiver rodando neste mesmo computador, ou um endereço multicast como 239.239.0.2, e use o mesmo endereço na configuração acima neste app.',
			'operation.import.listenTitle' => 'Escutar QSOs de outros apps',
			'operation.import.listenDescriptionOnN1mm' => 'Escutando o N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Escutando o WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Escutando o N1MM+ e o WSJT-X',
			'operation.import.listenDescriptionOff' => 'Desligado',
			'operation.import.addToOperationTitle' => 'Adicionar a esta operação',
			'operation.import.addToOperationDescriptionOn' => 'Os QSOs capturados são adicionados a esta operação conforme chegam',
			'operation.import.addToOperationDescriptionOff' => 'Os QSOs capturados ficam retidos até você ativar isto',
			'operation.import.pendingSectionTitle' => 'QSOs capturados',
			'operation.import.pendingEmpty' => 'Nada capturado ainda',
			'operation.import.stationMismatch' => ({required Object call}) => 'Registrado como ${call}, não a estação desta operação',
			'operation.import.discardAction' => 'Descartar',
			'operation.import.gapDialogTitle' => 'Incluir capturas anteriores?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Mais ${count} QSOs foram capturados antes, antes de uma lacuna nos dados. Incluí-los também?',
			'operation.import.gapDialogRecentOnly' => 'Só os recentes',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Incluir todos os ${count}',
			'map.outlineIssue.link' => 'Problemas?',
			'map.outlineIssue.title' => 'Relatar um problema no contorno',
			'map.outlineIssue.reference' => 'Qual contorno',
			'map.outlineIssue.severity' => 'Qual a gravidade?',
			'map.outlineIssue.minor' => 'Detalhe pequeno',
			'map.outlineIssue.major' => 'Problema grave',
			'map.outlineIssue.explanation' => 'O que está errado?',
			'map.outlineIssue.explanationHint' => 'O que o contorno erra, e onde',
			'map.outlineIssue.send' => 'Enviar',
			'map.outlineIssue.sending' => 'Enviando seu relato — obrigado',
			'map.outlineIssue.copy' => 'Copiar relato',
			'map.outlineIssue.notSent' => 'Não foi possível enviar o relato',
			'map.outlineIssue.copied' => 'Relato copiado',
			'map.outlineIssue.notCopied' => 'Não foi possível copiar o relato',
			'map.outlinesDisclaimer' => 'Os contornos são apenas para referência. Faça sua própria pesquisa!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contornos: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Limites: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Instalações: ${sources}',
			'map.fullCredits' => 'Créditos completos dos dados',
			'map.fewerCredits' => 'Menos créditos',
			'map.emptyState' => 'Ainda não há localizações de QSOs.\nQSOs com grid square, estado ou país aparecerão aqui.',
			'map.unavailable' => 'O mapa não está disponível agora.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plano',
			'map.globe' => 'Globo',
			'map.zoomIn' => 'Aproximar',
			'map.zoomOut' => 'Afastar',
			'map.postcard.button' => 'Cartão-postal da operação',
			'map.postcard.title' => ({required Object title}) => 'Cartão-postal de ${title}',
			'map.postcard.portrait' => 'Retrato',
			'map.postcard.landscape' => 'Paisagem',
			'map.postcard.square' => 'Quadrado',
			'map.postcard.save' => 'Salvar…',
			'map.postcard.download' => 'Baixar',
			'map.postcard.share' => 'Compartilhar',
			'map.postcard.copy' => 'Copiar',
			'map.postcard.copied' => 'Copiado para a área de transferência',
			'map.postcard.saved' => ({required Object path}) => 'Salvo em ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} baixado',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} imagens salvas em ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} salvos',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} já tinham sido salvos',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Baixando ${count} imagens — permita se o navegador pedir',
			'map.postcard.mapLeftOut' => 'O mapa não carregou, então ficou de fora',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — o mapa não carregou, então ficou de fora',
			'map.postcard.continued' => ({required Object title}) => '${title} (continuação)',
			'map.postcard.previousPage' => 'Página anterior',
			'map.postcard.nextPage' => 'Próxima página',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Página ${page} de ${count}',
			'map.postcard.sectionDays' => 'Cada dia',
			'map.postcard.reset' => 'Redefinir',
			'map.postcard.failed' => ({required Object error}) => 'Não foi possível criar o cartão-postal: ${error}',
			'map.postcard.mapNotReady' => 'O mapa não terminou de carregar. Verifique a conexão e tente novamente.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Não foi possível salvar o cartão-postal: ${error}',
			'map.postcard.copyFailed' => 'A área de transferência não aceitou a imagem. Tente novamente.',
			'map.postcard.shareFailed' => 'Não foi possível compartilhar o cartão-postal. Tente novamente.',
			'map.postcard.fileName' => 'cartao-postal',
			'mapsView.title' => 'Mapas',
			'mapsView.searchHint' => 'Buscar parques, cumes e mais',
			'mapsView.activities' => 'Atividades',
			'mapsView.layers' => 'Camadas',
			'mapsView.baseMap' => 'Mapa base',
			'mapsView.satellite' => 'Satélite (Esri)',
			'mapsView.facilities' => 'Instalações dos parques',
			'mapsView.boundaries' => 'Limites',
			'mapsView.currentLocation' => 'Localização atual',
			'mapsView.noMatches' => ({required Object text}) => 'Nada corresponde a “${text}”',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} referência em ${where}', other: '${count} referências em ${where}', ), 
			'mapsView.startOperation' => 'Iniciar uma operação com estas referências',
			'activitiesView.title' => 'Atividades',
			'activitiesView.activitiesCountZero' => 'Nenhuma atividade selecionada',
			'activitiesView.activitiesCountOne' => '1 atividade',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} atividades',
			'activitiesView.empty' => 'Nenhuma atividade ainda — use Sugestões e busca abaixo para adicionar uma',
			'activitiesView.removeActivity' => 'Remover',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Abrir ${name}',
			'activitiesView.editActivity' => 'Editar atividade',
			'activitiesView.manageExtensions' => 'Gerenciar extensões',
			'activitiesView.manage' => 'Gerenciar',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipos de atividade: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipos de atividade: ${first} e ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipos de atividade: ${first}, ${second} e mais ${more}',
			'activitiesView.reference' => 'Referência',
			'activitiesView.invalidReference' => 'Inválida',
			'activitiesView.duplicateReference' => 'Já adicionada',
			'activitiesView.searchHint' => 'Buscar por nome, referência ou qualquer outra coisa…',
			'activitiesView.noSuggestions' => 'Nenhum resultado',
			'activitiesView.noSuggestionsHint' => 'Busque pelo nome ou número da referência acima',
			'activitiesView.noSuggestionsExample' => '(por exemplo \'trilha\' ou \'4556\')',
			'activitiesView.allOptions' => 'Tipos de atividade',
			'activitiesView.determiningLocation' => 'Determinando a localização atual…\nAguardando o GPS para encontrar referências próximas',
			'activitiesView.locationUnavailableTitle' => 'Dados de localização indisponíveis',
			'activitiesView.locationDeniedTitle' => 'Permissão de localização negada',
			'activitiesView.locationBlockedTitle' => 'Permissão de localização bloqueada',
			'activitiesView.noNearbyReason' => 'Não é possível determinar referências próximas',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Toque em ${icon} para inserir sua localização manualmente,\nou simplesmente busque referências pelo nome',
			'activitiesView.locationGrantAction' => 'Permitir acesso à localização',
			'activitiesView.locationSettingsAction' => 'Abrir configurações',
			'activitiesView.locationSettingsUnavailable' => 'Permita o acesso à localização nas configurações do sistema',
			'activitiesView.locationGrantRefused' => 'Ainda sem localização — o sistema negou novamente',
			'activitiesView.searchUnavailableTitle' => 'Busca de atividades indisponível',
			'activitiesView.searchUnavailableReason' => 'Nenhuma extensão de atividade conseguiu executar a busca. Tente novamente em instantes.',
			'activitiesView.emptySheet' => 'Use sugestões e busca abaixo para adicionar uma',
			'activitiesView.exports' => 'Exportações',
			'activitiesView.exportLogs' => 'Exportar logs',
			'activitiesView.tools' => 'Ferramentas',
			'activitiesView.toolsTitle' => 'Ferramentas da operação',
			'activitiesView.operationDetails' => 'Detalhes da operação',
			'activitiesView.share' => 'Compartilhar',
			'activitiesView.archive' => 'Arquivar',
			'activitiesView.deleteOperation' => 'Excluir operação',
			'activitiesView.undeleteOperation' => 'Restaurar operação',
			'activitiesView.alreadySelected' => 'Já selecionada',
			'activitiesView.selected' => 'Selecionada',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} de ${count}',
			'activitiesView.previousPick' => 'Resultado anterior',
			'activitiesView.nextPick' => 'Próximo resultado',
			'activitiesView.retiredReference' => 'Desativada',
			'activitiesView.enableExtension' => ({required Object name}) => 'Habilitar ${name}',
			'activitiesView.enableExtensionHint' => 'Esta extensão corresponde à sua busca, mas não está habilitada',
			'activitiesView.enableExtensionForRefHint' => 'Esta extensão trata uma das referências desta operação, mas não está habilitada',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} não está rodando',
			'activitiesView.extensionNotRunningHint' => 'Esta extensão foi desativada; abra as Configurações de extensões para mais informações',
			'activitiesView.installExtension' => ({required Object name}) => 'Instalar ${name}',
			'activitiesView.installExtensionHint' => 'Esta extensão corresponde à sua busca, mas não está instalada',
			'activitiesView.onlyCatalogMatches' => 'Nenhum resultado\nAlgumas extensões do catálogo podem ter resultados.\nInstale-as em Tipos de atividade abaixo.',
			'activitiesView.setupUnavailable' => 'Não foi possível carregar a configuração desta atividade — tente novamente em Gerenciar',
			'activitiesView.controlsUnavailableTitle' => 'Controles da atividade indisponíveis',
			'activitiesView.controlsUnavailableReason' => 'Suas referências estão seguras, mas não é possível editá-las agora.',
			'activitiesView.controlsUnavailableRetry' => 'Tentar novamente',
			'activitiesView.onlyDisabledMatches' => 'Nenhum resultado\nAlgumas extensões disponíveis podem ter resultados.\nHabilite-as em Tipos de atividade abaixo.',
			'activitiesView.onlyNotRunningMatches' => 'Nenhum resultado\nAlgumas extensões que podem ter resultados não estão rodando.\nVeja Tipos de atividade abaixo.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Busca',
			'activitiesView.addToOperation' => 'Adicionar à operação',
			'activitiesView.addToOperationShort' => 'Adicionar',
			'activitiesView.mapEmptyState' => 'Nenhum resultado para mostrar no mapa',
			'activitiesView.mapEmptyStateHint' => 'Volte para a lista ou busque outra coisa',
			'activitiesView.imports' => 'Importações',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Data',
			'loggingControls.now' => 'Agora',
			'loggingControls.frequency' => 'Frequência',
			'loggingControls.mode' => 'Modo',
			'loggingControls.theirCall' => 'Indicativo deles',
			'loggingControls.noteField' => 'Nota',
			'loggingControls.todoField' => 'Tarefa',
			'loggingControls.sent' => 'Enviado',
			'loggingControls.rcvd' => 'Recebido',
			'loggingControls.more' => 'Mais',
			'loggingControls.revert' => 'Reverter',
			'loggingControls.undoDelete' => 'Desfazer exclusão',
			'loggingControls.restore' => 'Restaurar',
			'loggingControls.wipe' => 'Apagar',
			'loggingControls.undo' => 'Desfazer',
			'loggingControls.pendingDeleteTapWarning' => 'Toque na lixeira mais uma vez para excluir este QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Clique na lixeira mais uma vez para excluir este QSO',
			'loggingControls.deletedQsoWarning' => 'QSO excluído',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Toque na lixeira mais uma vez para excluir: ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Clique na lixeira mais uma vez para excluir: ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Excluído: ${kind}',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Rádio',
			'loggingControls.powerControl' => 'Potência',
			'loggingControls.notesControl' => 'Notas',
			'loggingControls.power' => 'Potência',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controles de registro',
			'loggingControls.spottingControl' => 'Spots',
			'loggingControls.spottingSelfControl' => 'Auto-spot',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Auto-spot em ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot de ${call} em ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Tarde demais para dar spot em ${call}',
			'loggingControls.spotNoFreq' => 'Primeiro defina uma frequência para o spot',
			'loggingControls.spotComment' => 'Comentário',
			'loggingControls.bandOrFreqRequired' => 'Defina uma frequência ou banda antes de registrar',
			'loggingControls.missingBand' => 'Sem banda',
			'loggingControls.missingMode' => 'Sem modo',
			'loggingControls.saveFailed' => ({required Object error}) => 'Não foi possível salvar: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Não foi possível excluir: ${error}',
			'loggingControls.info.noQsos' => 'Nenhum QSO ainda... vamos para o ar!',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} em ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} desde o último',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h nos últimos 10',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h nos últimos 100',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} até',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) até',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) até',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} de distância',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distância',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distância',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer}: ${notice}',
			'loggingControls.info.noticeDupe' => 'Duplicado!',
			'loggingControls.info.noticeNewBand' => 'Nova banda',
			'loggingControls.info.noticeNewMode' => 'Novo modo',
			'loggingControls.info.noticeNewDXCC' => 'Novo DXCC',
			'loggingControls.info.noticeNewState' => 'Novo estado',
			'loggingControls.info.noticeNewProvince' => 'Nova província',
			'loggingControls.info.noticeNewDay' => 'Novo dia',
			'loggingControls.info.noticeNewRef' => 'Nova ref',
			'loggingControls.info.noticeNewMult' => 'Novo mult',
			'loggingControls.info.noticeNewZone' => 'Nova zona',
			'loggingControls.info.noticeInvalidMode' => 'Modo errado',
			'loggingControls.info.noticeInvalidBand' => 'Banda errada',
			'loggingControls.info.noticeInvalidCategory' => 'Não contatável',
			'loggingControls.info.noticeWorkedBefore' => 'Já contatado',
			'loggingControls.info.noticeNewPark' => 'Novo parque',
			'loggingControls.info.noticeNewSection' => 'Nova seção',
			'loggingControls.info.noticeBonusStation' => 'Estação bônus!',
			'loggingControls.info.noticeMissingExchange' => 'Sem reporte',
			'loggingControls.info.noticeInvalidExchange' => 'Reporte inválido',
			'loggingControls.info.noticeUnknownEvent' => 'Evento desconhecido',
			'loggingControls.info.noticeOurGrid' => 'Defina nosso grid',
			'loggingControls.info.noticeRareCounty' => 'Condado raro!',
			'loggingControls.info.noticeOurLocation' => 'Defina nosso condado',
			'loggingControls.info.noticeShortGrid' => 'Grid muito curto',
			'formChrome.untitled' => '(sem título)',
			'formChrome.showMore' => 'Mostrar mais',
			'formChrome.showAll' => 'Mostrar tudo',
			'formChrome.showFewer' => 'Mostrar menos',
			'formChrome.defaults' => 'Padrões',
			'formChrome.search' => 'Buscar',
			'formChrome.clear' => 'Limpar',
			'formChrome.openPage' => 'Abrir página',
			'formChrome.connected' => 'Conectado',
			'formChrome.notConnected' => 'Não conectado',
			'formChrome.manage' => 'Gerenciar',
			'formChrome.connect' => 'Conectar',
			'formChrome.formTitle' => 'Formulário',
			'formChrome.addItem' => ({required Object label}) => 'Adicionar ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Editar ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Mostrando ${shown} de ${total} (${selected} selecionados)',
			'formChrome.validationError' => ({required Object error}) => 'Erro de validação: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Erro de transformação: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Erro: ${error}',
			'formChrome.removeItem' => 'Remover',
			'formChrome.storageUnavailable' => 'Logins indisponíveis',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.operatorCall' => 'Operador',
			'qsoEditForm.position' => 'Posição',
			'qsoEditForm.theirName' => 'Nome',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Estado',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Informações deles',
			'qsoEditForm.sectionOur' => 'Nossas informações',
			'qsoEditForm.sectionNotes' => 'Notas',
			'qsoEditForm.theirCity' => 'Cidade',
			'qsoEditForm.theirCounty' => 'Condado',
			'qsoEditForm.theirEntity' => 'Entidade',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Seção ARRL',
			'qsoEditForm.theirLat' => 'Latitude',
			'qsoEditForm.theirLon' => 'Longitude',
			'qsoEditForm.theirPower' => 'Potência deles',
			'qsoList.empty' => 'Nenhum QSO ainda — chame alguém!',
			'qsoList.bandOrModeWarning' => 'Verifique se a banda e o modo estão corretos',
			'qsoList.today' => 'Hoje',
			'qsoList.yesterday' => 'Ontem',
			'qsoList.tomorrow' => 'Amanhã',
			'loggingPanel.stats' => 'Estatísticas da operação',
			'loggingPanel.scoring' => 'Pontuação',
			'loggingPanel.dxccEntities' => 'Entidades DXCC',
			'loggingPanel.statesWorked' => 'Estados',
			'loggingPanel.provincesWorked' => 'Províncias',
			'loggingPanel.duplicates' => 'Duplicados',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostrar imagem',
			'callInfo.imageUnavailable' => 'Foto indisponível',
			'callInfo.photo' => 'Foto',
			'callInfo.notes' => 'Notas',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} até',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) até',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) até',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} de distância',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distância',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distância',
			'callInfo.thisOpCountOne' => '1 QSO nesta operação',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs nesta operação',
			'callInfo.otherOpsCountOne' => '1 QSO em outras operações',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs em outras operações',
			'callInfo.andMore' => ({required Object count}) => '… e mais ${count}',
			'callInfo.withCall' => ({required Object call}) => 'com ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'de ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} nos últimos 7 dias',
			'callInfo.history.today' => ({required Object n}) => '${n} hoje',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Configurações',
			'settings.language' => 'Idioma',
			'settings.languageSystem' => ({required Object language}) => 'Seguir as configurações do sistema (${language})',
			'settings.theme.title' => 'Modo do tema',
			'settings.theme.system' => 'Seguir as configurações do sistema',
			'settings.theme.light' => 'Claro',
			'settings.theme.dark' => 'Escuro',
			'settings.themeDescription.system' => 'Seguindo as configurações do sistema',
			'settings.themeDescription.light' => 'Sempre no modo claro',
			'settings.themeDescription.dark' => 'Sempre no modo escuro',
			'settings.fontScale' => 'Escala da fonte',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Mínimo--',
			'settings.fontScaleOpts.smallestMinus' => 'Mínimo-',
			'settings.fontScaleOpts.smallest' => 'Mínimo',
			'settings.fontScaleOpts.smaller' => 'Menor',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Maior',
			'settings.fontScaleOpts.largest' => 'Máximo',
			'settings.fontScaleOpts.largestPlus' => 'Máximo+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Máximo++',
			'settings.keepDeviceAwake.title' => 'Manter dispositivo ativo',
			'settings.keepDeviceAwake.descriptionOn' => 'Mantendo ativo enquanto você está na tela de registro ou uma sincronização está em andamento',
			'settings.keepDeviceAwake.descriptionOff' => 'Suspendendo normalmente',
			'settings.layoutDensity' => 'Densidade do layout',
			'settings.layoutDensityOpts.auto' => 'Automática',
			'settings.layoutDensityOpts.densest' => 'Máxima',
			'settings.layoutDensityOpts.dense' => 'Densa',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Espaçada',
			'settings.layoutDensityOpts.sparsest' => 'Mais espaçada',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'a janela é baixa demais, usando ${effective}',
			'settings.layoutDensityAtLimit' => 'no limite',
			'settings.distanceUnits' => 'Unidades de distância',
			'settings.distanceUnitsOpts.kilometers' => 'Quilômetros',
			'settings.distanceUnitsOpts.miles' => 'Milhas',
			'settings.userInterface' => 'Interface do usuário',
			'settings.logging.title' => 'Registro',
			'settings.logging.leftieMode.title' => 'Modo canhoto',
			'settings.logging.leftieMode.descriptionOn' => 'Usando o layout para canhotos',
			'settings.logging.leftieMode.descriptionOff' => 'Usando o layout para destros',
			'settings.logging.countryFlags.title' => 'Bandeiras de países',
			'settings.logging.countryFlags.dx' => 'Mostrar apenas para contatos DX',
			'settings.logging.countryFlags.all' => 'Mostrar bandeiras para todos os contatos',
			'settings.logging.countryFlags.none' => 'Não mostrar bandeiras',
			'settings.logging.countryFlagsDescription.dx' => 'Mostrando bandeiras apenas para contatos DX',
			'settings.logging.countryFlagsDescription.all' => 'Mostrando bandeiras para todos os contatos',
			'settings.logging.countryFlagsDescription.none' => 'Não mostrando nenhuma bandeira',
			'settings.logging.suggestDefaultOperator.title' => 'Sugerir operador',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Oferecendo seu indicativo como operador quando uma operação usa um indicativo de estação diferente',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'Deixando o operador em branco, a menos que você o preencha',
			'settings.logging.showBearing.title' => 'Mostrar azimute',
			'settings.logging.showBearing.descriptionOn' => 'Mostrando o azimute estimado para a estação',
			'settings.logging.showBearing.descriptionOff' => 'Não mostrando informações de azimute',
			'settings.logging.showReverseBearing.title' => 'Mostrar também azimute reverso',
			'settings.logging.showReverseBearing.descriptionOn' => 'Mostrando também o azimute a partir da estação, como "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'Mostrando apenas o azimute para a estação',
			'settings.logging.switchSentRcvd.title' => 'Inverter ordem do reporte de sinal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Enviado primeiro, Recebido depois',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Recebido primeiro, Enviado depois',
			'settings.logging.jumpAfterRST.title' => 'Pular para o próximo campo ao inserir RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Avançando depois que o RST é inserido',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Não avançando automaticamente',
			'settings.logging.defaultReport.title' => 'Reporte padrão — Fonia',
			'settings.logging.defaultReport.description' => 'Usado quando Enviado ou Recebido fica vazio em SSB, FM ou AM',
			'settings.logging.defaultReportCW.title' => 'Reporte padrão — CW e dados',
			'settings.logging.defaultReportCW.description' => 'Usado quando Enviado ou Recebido fica vazio em CW, RTTY e outros modos digitais',
			'settings.logging.defaultReportFT8.title' => 'Reporte padrão — FT8 e FT4',
			'settings.logging.defaultReportFT8.description' => 'Usado quando Enviado ou Recebido fica vazio nos modos FT',
			'settings.logging.numbersRow.title' => 'Linha de números',
			'settings.logging.numbersRow.description' => 'Mostrar uma linha de teclas numéricas acima do teclado durante o registro',
			'settings.logging.numbersRowExtra.title' => 'Tecla de barra e ponto',
			'settings.logging.numbersRowExtra.description' => 'Adiciona uma tecla contextual: “/” para indicativos, “.” para números',
			'settings.logging.numbersRowVibrate.title' => 'Vibrar ao pressionar teclas',
			'settings.logging.numbersRowVibrate.description' => 'Resposta tátil ao tocar em uma tecla numérica',
			'settings.logging.bands' => 'Bandas preferidas',
			'settings.logging.modes' => 'Modos preferidos',
			'settings.catServer.title' => 'Servidor CAT',
			'settings.catServer.description' => 'Permite que outros apps (WSJT-X, programas de log etc.) controlem o rádio através do Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocolo',
			'settings.catServer.protocolOpts.off' => 'Desativado',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Porta',
			'settings.catServer.openAccess' => 'Acesso aberto',
			'settings.catServer.openAccessOn' => 'Qualquer computador na rede local pode se conectar.',
			'settings.catServer.openAccessOff' => 'Apenas apps neste computador podem se conectar.',
			'settings.catServer.off' => 'Desligado.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, iniciando…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} na porta ${port}. Clientes conectados: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} na porta ${port}, mas nenhum rádio de VFO principal está conectado.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} não consegue escutar na porta ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: outro programa a está usando, muitas vezes o próprio ${protocol}. Feche esse programa ou escolha outra porta.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: este computador não permite. Escolha uma porta acima de 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} parou de escutar na porta ${port}. Tentando novamente…',
			'settings.radio.title' => 'Controle CAT',
			'settings.radio.loggingAndCat' => 'Registro e CAT',
			_ => null,
		} ?? switch (path) {
			'settings.radio.tuningSection' => 'Sintonia',
			'settings.radio.keyerSection' => 'Manipulador',
			'settings.radio.servicesSection' => 'Serviços',
			'settings.radio.stationConfigurationSection' => 'Configuração da estação',
			'settings.radio.moreSettings' => 'Mais configurações da estação',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controlar PTT com [\']',
			'settings.radio.pttKey.descriptionOn' => 'Nos modos de fonia, [\'] aciona o rádio e [\'] de novo o libera. Ele se libera sozinho depois de um minuto.',
			'settings.radio.pttKey.descriptionOff' => 'A tecla [\'] não aciona o rádio.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Transmitindo',
			'settings.radio.smartVfoSnap.title' => 'Ajuste inteligente do VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Quando você para de girar o dial, a frequência é arredondada para um passo razoável. Apenas modos de voz.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Fica exatamente onde você sintonizou.',
			'settings.radio.snapDebounce.title' => 'Ajuste inteligente: Tempo de espera',
			'settings.radio.snapDebounce.description' => 'Quanto tempo o dial precisa ficar parado antes de a frequência ser arredondada. Mais curto parece imediato; mais longo dá espaço para um movimento lento.',
			'settings.radio.snapLongMove.title' => 'Ajuste inteligente: Movimento longo',
			'settings.radio.snapLongMove.description' => 'Mova pelo menos isto e a frequência é arredondada para um kHz inteiro, por mais devagar que você tenha terminado.',
			'settings.radio.snapMinMove.title' => 'Ajuste inteligente: Menor movimento',
			'settings.radio.snapMinMove.description' => 'Mova menos que isto e a frequência não é arredondada, então a sintonia fina não é alterada.',
			'settings.radio.snapMinSpeed.title' => 'Ajuste inteligente: Movimento mais lento',
			'settings.radio.snapMinSpeed.description' => 'Gire o dial mais devagar que isto e a frequência não é arredondada, a menos que tenha sido um movimento longo.',
			'settings.radio.enterSends.pillOff' => 'ESM Desl.',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter envia mensagens',
			'settings.radio.enterSends.off' => 'Desligado',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter envia mensagens: ${state}. Toque para alterar.',
			'settings.radio.keyerSpeed.title' => 'Velocidade do manipulador',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Mensagens de CW do manipulador',
			'settings.radio.cwMessages.notSupported' => 'O rádio atual não suporta manipulação de CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Mensagem (${n})',
			'settings.radio.cwMessages.labelField' => 'Rótulo',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Rótulo de F${n}',
			'settings.radio.cwMessages.details' => 'Detalhes',
			'settings.radio.cwMessages.empty' => '(vazia)',
			'settings.radio.cwMessages.sets' => 'Conjunto de mensagens',
			'settings.radio.cwMessages.newSet' => 'Novo conjunto',
			'settings.radio.cwMessages.renameSet' => 'Renomear conjunto',
			'settings.radio.cwMessages.deleteSet' => 'Excluir conjunto',
			'settings.radio.cwMessages.newSetName' => 'Nome',
			'settings.radio.cwMessages.setDefault' => 'Padrão',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Mensagens ESM',
			'settings.radio.cwMessages.setSaved' => 'Minhas mensagens',
			'settings.radio.cwMessages.repeat' => 'Repetir mensagem nº 1',
			'settings.radio.cwMessages.repeatOff' => 'Não',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Após ${n} segundos',
			'settings.radio.cwMessages.repeatWait' => 'Repetindo',
			'settings.radio.cwMessages.keyboard' => 'Digite para enviar',
			'settings.radio.cwMessages.keyboardField' => 'Digite para enviar',
			'settings.radio.cwMessages.closeArea' => 'Fechar a área do manipulador',
			'settings.radio.cwMessages.help' => 'Ajuda',
			'settings.radio.cwMessages.helpTitle' => 'Escrevendo mensagens de CW',
			'settings.radio.cwMessages.helpIntro' => 'As mensagens podem usar modelos com os seguintes valores:',
			'settings.radio.cwMessages.helpOpCall' => 'Seu indicativo',
			'settings.radio.cwMessages.helpQsoCall' => 'O indicativo deles — em uma pilha //, o indicativo que será registrado',
			'settings.radio.cwMessages.helpQsoFullCall' => 'O indicativo deles, se houver um indicativo válido; vazio para um parcial',
			'settings.radio.cwMessages.helpQsoPartial' => 'Um indicativo parcial; vazio se houver um indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextCall' => 'Em uma pilha //, o indicativo que será selecionado para o próximo registro, se houver um indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'Em uma pilha //, o próximo parcial depois de registrar o contato atual',
			'settings.radio.cwMessages.helpQsoName' => 'O primeiro nome deles, como digitado ou, senão, da consulta',
			'settings.radio.cwMessages.helpQsoState' => 'O estado deles, como digitado ou, senão, da consulta',
			'settings.radio.cwMessages.helpKeyerMsg' => 'A mensagem 1 como seria enviada, dentro de outra mensagem. Válido para as mensagens 1 a 8',
			'settings.radio.cwMessages.helpQsoRst' => 'O reporte que você está enviando',
			'settings.radio.cwMessages.helpQsoSerial' => 'Seu número de série, em um concurso que envia um',
			'settings.radio.cwMessages.helpPad' => 'Completa com zeros até esse número de dígitos: 7 é enviado como 007',
			'settings.radio.cwMessages.helpCut' => 'Números abreviados, T para 0 e N para 9: 599 é enviado como 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Escolhe os dígitos a abreviar, entre aspas — 0 é T, 1 é A, 5 é E, 9 é N',
			'settings.radio.cwMessages.helpFullExample' => 'Exemplo completo:',
			'settings.radio.cwMessages.helpExample' => 'Envia W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Com Enter envia mensagens ativado, o Enter transmite as mensagens pela tecla de função, como faz o N1MM. O conjunto Mensagens ESM começa com estas:',
			'settings.radio.cwMessages.helpEsmCq' => 'Em Run, Enter com o campo de indicativo vazio chama CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Seu reporte: depois do indicativo deles em Run, depois que eles respondem em S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Agradecimento, depois que o contato é registrado: seus marcadores se referem ao próximo contato, não a este',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Em S&P, seu indicativo para a estação que você está respondendo',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Em Run, o indicativo deles antes do seu reporte',
			'settings.radio.cwMessages.helpEsmAgain' => 'Pede de novo quando nada do reporte deles foi copiado',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 sugerido para pilhas //: o TU sai depois que o contato é registrado, então agradece, chama a próxima estação da pilha e envia seu reporte, ou pede um parcial de volta (TU KR?); sem mais nada, só TU',
			'settings.radio.voiceMessages.title' => 'Mensagens de fonia do manipulador',
			'settings.radio.voiceMessages.notSupported' => 'O rádio atual não suporta mensagens de fonia',
			'settings.radio.voiceMessages.description' => 'Usa as memórias de voz do rádio',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memória de voz (${n})',
			'settings.radio.voiceMessages.labelField' => 'Rótulo',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Rótulo da memória de voz ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Vazia',
			'settings.radio.voiceMessages.notMeasured' => 'Duração desconhecida',
			'settings.radio.voiceMessages.playButton' => 'Reproduzir',
			'settings.radio.voiceMessages.recordButton' => 'Gravar',
			'settings.radio.voiceMessages.stopButton' => 'Parar',
			'settings.radio.voiceMessages.repeat' => 'Repetir mensagem nº 1',
			'settings.radio.voiceMessages.repeatOff' => 'Não',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Após ${n} segundos',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Notas do ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Estas memórias estão no rádio de ${device}. Os nomes e durações pertencem a esse dispositivo.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Salvo no rádio, onde os outros clientes dele também o veem.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Aguarde o indicador [REC] no rádio, depois segure o botão PTT e grave sua mensagem. Termine pressionando o botão PARAR aqui no app antes de soltar o PTT, para evitar cliques indesejados.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Aguarde o indicador [REC] piscar pelo menos quatro vezes, depois segure o botão PTT e grave sua mensagem. Termine pressionando o botão PARAR aqui no app antes de soltar o PTT, para evitar cliques indesejados.',
			'settings.radio.voiceMessages.pill' => 'Voz',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Reproduzir memória ${n}',
			'settings.radio.voiceMessages.stop' => 'Parar',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Gravar memória ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Parar gravação',
			'settings.radio.voiceMessages.playing' => 'Reproduzindo…',
			'settings.radio.voiceMessages.recording' => 'Gravando…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Reproduzindo ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Gravando ${label}',
			'settings.radio.voiceMessages.doubtful' => 'O rádio reproduziu? Ele informou que estava ocioso logo em seguida.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Você precisa gravar as memórias no próprio rádio.',
			'settings.radio.avoidZeroBeat.title' => 'Evitar batimento zero em spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Com um rádio conectado, sintoniza alguns Hz fora de um spot de CW, para que nem todos que respondem chamem na mesma nota.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Sintoniza exatamente na frequência do spot.',
			'settings.radio.zeroBeatRange.title' => 'Batimento zero: Faixa de desvio',
			'settings.radio.zeroBeatRange.description' => 'Quão longe da frequência do spot parar, para qualquer lado. O desvio nunca fica perto de zero — isso seria batimento zero de novo.',
			'settings.help.title' => 'Ajuda e recursos',
			'settings.help.description' => 'Comunidade e suporte',
			'settings.help.forums' => 'Fóruns Ham2K',
			'settings.help.forumsDescription' => 'Encontre ajuda, dê feedback, discuta ideias…',
			'settings.help.chat' => 'Chat Ham2K',
			'settings.help.chatDescription' => 'O servidor Discord da nossa comunidade online',
			'settings.help.youtube' => 'YouTube Ham2K',
			'settings.help.youtubeDescription' => 'Vídeos e transmissões ao vivo',
			'settings.help.instagram' => 'Instagram Ham2K',
			'settings.help.instagramDescription' => 'Porque você nunca pode ter fotos demais…',
			'settings.help.bluesky' => 'BlueSky Ham2K',
			'settings.help.blueskyDescription' => 'Siga-nos para novidades e atualizações',
			'settings.help.contact' => 'Contate-nos',
			'settings.help.contactDescription' => 'help@ham2k.com — mas tente os Fóruns ou o Chat primeiro!',
			'settings.exports.title' => 'Exportações',
			'settings.map.title' => 'Mapas',
			'settings.map.style.title' => 'Estilo do mapa',
			'settings.map.styleOpts.automatic' => 'Automático',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacidade',
			'settings.privacy.shareAppData.title' => 'Compartilhar dados de uso do app',
			'settings.privacy.shareAppData.descriptionOn' => 'Ajudando a melhorar o app ao compartilhar dados de uso, configuração, falhas e desempenho',
			'settings.privacy.shareAppData.descriptionOff' => 'Mantendo privados os dados de uso do app.\nA equipe do Ham2K não poderá detectar falhas ou outros problemas.',
			'settings.privacy.shareOpData.title' => 'Compartilhar dados de operação',
			'settings.privacy.shareOpData.descriptionOn' => 'Compartilhando alguns dados de operação publicamente e com outros usuários',
			'settings.privacy.shareOpData.descriptionOff' => 'Mantendo os dados de operação privados',
			'settings.privacy.privacyPolicy' => 'Política de privacidade',
			'settings.privacy.termsOfService' => 'Termos de serviço',
			'settings.operatorCall' => 'Indicativo do operador',
			'settings.sync.title' => 'Sincronização na nuvem',
			'settings.sync.moreSettings' => 'Mais configurações de sincronização',
			'settings.sync.enable' => 'Habilitar sincronização',
			'settings.sync.deviceKey' => 'Chave do dispositivo',
			'settings.peers.title' => 'Dispositivos pareados',
			'settings.peers.enable' => 'Conectar a outros dispositivos',
			'settings.peers.enableDescription' => 'Permite compartilhar operações, registro, CAT e GPS com outros dispositivos pela rede local',
			'settings.peers.bleEnable' => 'Conectar por Bluetooth',
			'settings.peers.bleDescription' => 'Usa Bluetooth LE para conectar mesmo sem rede local',
			'settings.peers.thisDevice' => 'Este dispositivo',
			'settings.peers.deviceName' => 'Nome',
			'settings.peers.deviceNameHint' => 'Como este dispositivo é visto pelos outros dispositivos',
			'settings.peers.pairedDevices' => 'Dispositivos vinculados',
			'settings.peers.noPairedDevices' => 'Nenhum dispositivo vinculado ainda. Ative isto em outro dispositivo nesta rede para vinculá-los.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Não foi possível ler seus dispositivos vinculados: ${error}',
			'settings.peers.nearby' => 'Próximos',
			'settings.peers.connected' => 'Conectado',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Conectando…',
			'settings.peers.syncing' => 'Sincronizando…',
			'settings.peers.waitingForThem' => 'Aguardando o outro dispositivo',
			'settings.peers.notConnected' => 'Não conectado',
			'settings.peers.wantsToPair' => 'quer compartilhar esta operação',
			'settings.peers.allow' => 'Permitir',
			'settings.peers.link' => 'Vincular',
			'settings.peers.reject' => 'Rejeitar',
			'settings.peers.forget' => 'Esquecer',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Esquecer ${name}?',
			'settings.peers.forgetBody' => 'Ele deixará de sincronizar com este dispositivo. Você pode permiti-lo novamente depois, e os contatos já registrados são mantidos.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Vincular com ${name}',
			'settings.peers.pairBody' => 'Este dispositivo está na sua rede local e quer se conectar.',
			'settings.peers.pairBodyBle' => 'Este dispositivo está por perto e quer se conectar por Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID do dispositivo',
			'settings.peers.pairWarning' => 'Vincule apenas dispositivos que você reconhece. Qualquer dispositivo nesta rede pode enviar uma solicitação.',
			'settings.peers.pairWarningBle' => 'Vincule apenas dispositivos que você reconhece. Qualquer dispositivo próximo pode enviar uma solicitação.',
			'settings.peers.problem' => ({required Object error}) => 'Não foi possível acessar a rede local: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Conectado a ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Conexão perdida com ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispositivos pareados: ${connected} de ${linked} conectados',
			'settings.peers.screenEnable' => 'Compartilhar telas e janelas',
			'settings.peers.screenDescription' => 'Permite que outros dispositivos mostrem telas ou janelas deste computador',
			'settings.peers.screenSources' => 'Telas e janelas',
			'settings.peers.screenRefresh' => 'Atualizar a lista',
			'settings.peers.screenUnsupportedPlatform' => 'Este dispositivo não pode compartilhar a tela. O macOS pode; qualquer dispositivo pode mostrar uma tela compartilhada por outro.',
			'settings.peers.screenUnsupportedVersion' => 'Compartilhar uma tela requer macOS 12.3 ou posterior. Este dispositivo ainda pode mostrar uma tela compartilhada por outro.',
			'settings.peers.screenNeedsPermission' => 'O macOS precisa da sua permissão para gravar a tela antes que este app possa compartilhar uma.',
			'settings.peers.screenGrantPermission' => 'Pedir permissão',
			'settings.peers.screenRelaunchAfterGranting' => 'Permita em Ajustes do Sistema, em Privacidade e Segurança → Gravação de Tela, depois feche e reabra este app — o macOS só informa a mudança a um app na próxima vez que ele é aberto.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Compartilhamento de tela: ${error}',
			'settings.peers.screenChooseTitle' => 'Escolha o que compartilhar',
			'settings.peers.screenChooseButton' => 'Escolher o que compartilhar…',
			'settings.peers.screenTabScreens' => 'Telas',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Janelas',
			'settings.peers.screenTabEmpty' => 'Nada deste tipo foi encontrado.',
			'settings.peers.screenSharedSummaryNone' => 'Nada escolhido ainda.',
			'settings.peers.screenThisDevice' => 'Este dispositivo',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Mostrado em ${devices}',
			'settings.peers.screenSharedToNobody' => 'Não está sendo mostrado',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Parar de compartilhar ${name}',
			'settings.developerMode' => 'Modo desenvolvedor',
			'settings.syncPanel.configuration' => 'Configuração de sincronização',
			'settings.syncPanel.enableTitle' => 'Sincronizar com o Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Fazendo backup e sincronizando seu log entre dispositivos',
			'settings.syncPanel.disabledDescription' => 'Desligado — fica apenas neste dispositivo',
			'settings.syncPanel.syncing' => 'Sincronizando',
			'settings.syncPanel.account' => 'Conta',
			'settings.syncPanel.refresh' => 'Atualizar',
			'settings.syncPanel.switchAccounts' => 'Trocar de conta',
			'settings.syncPanel.switchAccountsDescription' => 'Vincule este dispositivo a outra conta com um código QR ou e-mail',
			'settings.syncPanel.connectionRequests' => 'Solicitações de conexão',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Um dispositivo está aguardando para entrar nesta conta', other: '${n} dispositivos estão aguardando para entrar nesta conta', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mail da conta',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmação enviada para ${email}. Abra o link lá para concluir a alteração.',
			'settings.syncPanel.resendConfirmation' => 'Reenviar e-mail de confirmação',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'Aguardando ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Enviado novamente para ${email}.',
			'settings.syncPanel.deviceLinked' => 'Esse dispositivo agora está vinculado a esta conta.',
			'settings.syncPanel.checking' => 'Verificando…',
			'settings.syncPanel.notLinked' => 'Ainda não vinculado',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Substituir dados locais?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} operação', other: '${n} operações', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Dados sincronizados',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'Aguardando envio: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Este dispositivo: verificando…',
			'settings.syncPanel.countsServerChecking' => 'Servidor: verificando…',
			'settings.syncPanel.countsServerUnavailable' => 'Servidor: indisponível',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Isso faz backup e remove ${operations} e ${qsos} deste dispositivo e depois baixa os dados da conta no lugar. O backup fica no banco de dados deste dispositivo.',
			'settings.syncPanel.replace' => 'Substituir',
			'settings.syncPanel.pendingBannerTitle' => 'Nova conta do Ham2K Log Filer detectada',
			'settings.syncPanel.pendingBannerBody' => 'Mantenha as operações e QSOs existentes deste dispositivo e mescle-os na conta, ou substitua-os pelos dados da conta (um backup fica neste dispositivo em ambos os casos).',
			'settings.syncPanel.combine' => 'Combinar',
			'settings.syncPanel.authIssueTitle' => 'A sincronização não consegue se conectar',
			'settings.syncPanel.authIssueText' => 'O Ham2K Log Filer continua rejeitando este dispositivo. Verifique seu indicativo nas configurações de sincronização.',
			'settings.syncPanel.openSettings' => 'Abrir configurações de sincronização',
			'settings.accounts.title' => 'Contas, serviços e fontes de dados',
			'settings.accounts.none' => 'Nenhuma extensão ativa com contas',
			'settings.accounts.notConfigured' => 'Não configurado',
			'settings.accounts.connected' => 'Conectado',
			'settings.accounts.cancelLogin' => 'Cancelar login',
			'settings.accounts.openInBrowser' => 'Abrir no navegador',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Conectado como ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Pressione Salvar para manter esta conta conectada.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Conectado a ${label}',
			'settings.accounts.connect' => 'Conectar',
			'settings.accounts.disconnect' => 'Desconectar',
			'settings.accounts.connectedAs' => 'Conectado como',
			'settings.accounts.test' => 'Testar',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Falha ao salvar: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Falha no login: ${error}',
			'settings.accounts.lookupFailed' => 'As contas não estão disponíveis agora — tente novamente em instantes',
			'settings.accounts.browserLoginTitle' => 'Conclua o login no seu navegador',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Quando terminar, o navegador tentará abrir um link que começa com "${prefix}". Provavelmente nada no seu computador está registrado para abri-lo, então copie esse link (da barra de endereços ou da página de erro que o navegador mostrar) e cole-o aqui.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'O Ham2K Logger não conseguiu abrir seu navegador. Copie o link de login abaixo e abra-o você mesmo, depois copie o link para o qual ele te leva (começa com "${prefix}") e cole-o aqui.',
			'settings.accounts.copyLoginLink' => 'Copiar link de login',
			'settings.accounts.pastedLinkLabel' => 'Cole o link aqui',
			'settings.accounts.finishLogin' => 'Concluir login',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Esse não é o link de login — ele deve começar com "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Esse link pertence a outra tentativa de login. Feche esta página e conecte novamente.',
			'settings.accounts.pastedLinkNoCode' => 'Esse link não tem um código de login. Conclua o login primeiro e depois copie o link para o qual ele te leva.',
			'settings.accounts.pastedLinkMalformed' => 'Esse link parece cortado. Copie-o inteiro e cole novamente.',
			'settings.accounts.relayLoginWaiting' => 'Aguardando você concluir o login — isto continuará automaticamente quando você terminar.',
			'settings.accounts.loginNoResponse' => 'Este dispositivo ainda não recebeu resposta do login. Se você já concluiu no navegador, cancele e tente conectar novamente.',
			'settings.accounts.relayLoginNotOpened' => 'O Ham2K Logger não conseguiu abrir seu navegador automaticamente. Use o botão abaixo para abrir a página de login você mesmo.',
			'settings.accounts.relayLoginUnavailable' => 'Não foi possível acessar o servidor de sincronização necessário para concluir este login. Verifique sua conexão e tente novamente.',
			'settings.accounts.loginIncompleteResponse' => 'Essa tentativa de login não foi concluída corretamente. Tente conectar novamente.',
			'settings.accounts.noKeyringTitle' => 'Os logins de contas não podem ser salvos',
			'settings.accounts.noKeyringText' => 'O Ham2K Logger não consegue acessar um serviço de chaveiro neste computador, então os logins de contas não podem ser armazenados nem lidos — conectar uma conta vai falhar até isso ser resolvido. Instale e inicie o **gnome-keyring**, **KWallet** ou **KeePassXC**, ou desbloqueie o chaveiro que você já tem, e depois reinicie. Registro, exportações e arquivos de dados não são afetados; a sincronização do log fica desligada enquanto isso durar.',
			'settings.accounts.noKeyringInline' => 'Os logins não podem ser salvos: o chaveiro deste computador está inacessível. Instale e inicie o gnome-keyring, KWallet ou KeePassXC, ou desbloqueie o que você tem.',
			'settings.accounts.noSecureStorageInline' => 'Os logins não podem ser salvos: o armazenamento seguro deste computador está inacessível.',
			'settings.station.title' => 'Configuração da estação e controle CAT',
			'settings.station.none' => 'Nenhum equipamento configurado',
			'settings.station.add' => 'Adicionar',
			'settings.station.addTitle' => 'Adicionar equipamento',
			'settings.station.searchHint' => 'Buscar equipamento',
			'settings.station.noMatches' => 'Nenhum equipamento corresponde',
			'settings.station.detectedEquipment' => 'Equipamentos detectados',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Não é possível escutar rádios: ${error}',
			'settings.station.edit' => 'Editar equipamento',
			'settings.station.name' => 'Nome',
			'settings.station.nameDescription' => 'Como você o chama — "Rádio da esquerda". Opcional.',
			'settings.station.transport' => 'Conexão',
			'settings.station.host' => 'Endereço',
			'settings.station.hostDescription' => 'O nome de host ou endereço IP do rádio na sua rede.',
			'settings.station.port' => 'Porta',
			'settings.station.hostRequired' => 'Um endereço é obrigatório',
			'settings.station.portInvalid' => 'A porta deve estar entre 1 e 65535',
			'settings.station.connect' => 'Conectar',
			'settings.station.disconnect' => 'Desconectar',
			'settings.station.remove' => 'Remover',
			'settings.station.removeTitle' => ({required Object name}) => 'Remover ${name}?',
			'settings.station.removeMessage' => 'Isso apenas o remove do app. As configurações do equipamento continuam como estão.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipo de equipamento não reconhecido "${typeKey}"',
			'settings.station.report' => 'Relatar',
			'settings.station.reportTitle' => 'Relatar este rádio',
			'settings.station.reportIntro' => 'Conte-nos qual rádio é este de fato e como foi. Seu relato vira um cartão que a equipe do Ham2K lê, e o que você escrever sobre como fazê-lo funcionar pode acabar ajudando o próximo operador com o mesmo equipamento.',
			'settings.station.reportManufacturer' => 'Fabricante',
			'settings.station.reportManufacturerDescription' => 'Quem o fabrica — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'O fabricante é obrigatório',
			'settings.station.reportModel' => 'Modelo',
			'settings.station.reportModelDescription' => 'O modelo, como o próprio rádio o chama — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'O modelo é obrigatório',
			'settings.station.reportOutcome' => 'Como foi?',
			'settings.station.reportOutcomeWorks' => 'Funcionou bem',
			'settings.station.reportOutcomeIssues' => 'Funcionou, com problemas',
			'settings.station.reportOutcomeFails' => 'Não funcionou',
			'settings.station.reportOutcomeRequired' => 'Conte-nos como foi',
			'settings.station.reportComments' => 'Comentários',
			'settings.station.reportCommentsPlaceholder' => 'O que funcionou, o que não funcionou, qualquer coisa que te surpreendeu.',
			'settings.station.reportHints' => 'Dicas de solução de problemas',
			'settings.station.reportHintsPlaceholder' => 'Quer sugerir algumas dicas de solução de problemas para outros usuários?',
			'settings.station.reportSend' => 'Enviar relato',
			'settings.station.reportSending' => 'Enviando seu relato…',
			'settings.station.reportSent' => ({required Object ref}) => 'Obrigado — seu relato foi registrado como ${ref}.',
			'settings.station.reportSentNoRef' => 'Obrigado — seu relato foi enviado.',
			'settings.station.reportFailed' => ({required Object error}) => 'O relato não foi enviado: ${error}',
			'settings.station.troubleshootingNotes' => 'Notas de solução de problemas',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Usar como VFO principal',
			'settings.station.serialPort' => 'Porta serial',
			'settings.station.serialPortDescription' => 'A porta em que aparece a interface CAT do rádio.',
			'settings.station.serialPortNone' => 'Nenhuma porta serial encontrada',
			'settings.station.serialPortRequired' => 'Escolha uma porta serial',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'porta ${n} de ${total}',
			'settings.station.serialPortSuggested' => 'sugerida',
			'settings.station.serialPortJustNow' => 'Conectada recentemente',
			'settings.station.serialDeviceRequest' => 'Adicionar um dispositivo USB…',
			'settings.station.baudRate' => 'Velocidade (baud)',
			'settings.station.baudRateDescription' => 'Deve corresponder ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo e nenhum erro.',
			'settings.station.serialRtsHigh' => 'Manter RTS alto',
			'settings.station.serialRtsHighDescription' => 'Apenas para um rádio que espera o RTS antes de responder, como um Yaesu com CAT RTS ativado. Em um Digirig, SignaLink e na maioria dos cabos caseiros, o RTS é o PTT, e mantê-lo alto transmite.',
			'settings.station.serialDtrHigh' => 'Manter DTR alto',
			'settings.station.serialDtrHighDescription' => 'Apenas para uma interface CAT alimentada pelo DTR, como alguns cabos RS-232 para o FT-817. Em muitos cabos o DTR aciona CW ou PTT, e mantê-lo alto transmite.',
			'settings.station.civAddress' => 'Endereço CI-V do rádio',
			'settings.station.civAddressDescription' => 'Hexadecimal, como mostrado no menu CI-V do rádio. O IC-705 vem de fábrica com A4.',
			'settings.station.civAddressInvalid' => 'Um endereço CI-V tem dois dígitos hexadecimais, de 01 a FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Qual slice do rádio esta conexão lê e sintoniza.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Escolha um dos slices do rádio, de A a H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'O slice ${letter} não está em uso neste rádio — escolha outro slice ou crie-o no SmartSDR',
			'settings.station.channelNotInUse' => 'não está em uso',
			'settings.station.channelHeldByUnknown' => 'em uso por outro programa',
			'settings.station.flexNoSlices' => 'Este rádio não informou nenhum slice — verifique se o SmartSDR está rodando e se este cliente pode se inscrever',
			'settings.station.spectrumUnsupported' => 'Este rádio não envia espectro via CAT',
			'settings.station.spectrumRequiresBaud' => 'Requer CAT a 115200 bps',
			'settings.station.spectrumNoRadio' => 'Nenhum rádio conectado',
			'settings.station.spectrumWaiting' => 'Aguardando o espectro do rádio…',
			'settings.station.spectrumUnavailable' => 'A exibição do espectro não está disponível',
			'settings.station.spectrumNoDaxChannel' => 'Todos os canais DAX IQ deste rádio estão em uso',
			'settings.station.spectrumNoPanadapter' => 'Este slice não tem panadapter no rádio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'O rádio recusou um stream DAX IQ (erro ${code})',
			'settings.station.spectrumNoUdp' => 'Os dados de espectro do rádio não conseguem chegar a este dispositivo',
			'settings.station.spectrumScopeRefused' => 'O rádio recusou os comandos de scope',
			'settings.station.spectrumOutOfRange' => 'O scope do rádio está ajustado fora da faixa que ele consegue mostrar',
			'settings.station.n3fjpNoRig' => 'O N3FJP não tem interface de rádio configurada, então isto segue o que é digitado no N3FJP, não um rádio',
			'settings.station.winkeyerKeyPort' => 'Saída de manipulação',
			'settings.station.winkeyerKeyPortDescription' => 'Em qual das duas saídas do keyer o seu rádio está conectado.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Porta ${n}',
			'settings.station.winkeyerPtt' => 'Usar o PTT do keyer',
			'settings.station.winkeyerPttDescription' => 'Aciona a linha de PTT na mesma saída, para um amplificador ou um rádio que precise. Deixe desligado para um rádio manipulado pela entrada de chave.',
			'settings.station.winkeyerNoAnswer' => 'Nenhum WinKeyer respondeu nesta porta',
			'settings.station.winkeyerStoppedAnswering' => 'O WinKeyer parou de responder durante o envio; a mensagem foi descartada',
			'settings.station.radioUser' => 'Usuário do rádio',
			'settings.station.radioPass' => 'Senha do rádio',
			'settings.station.radioLoginDescription' => 'O login de Network → Remote do rádio, não a senha do seu WiFi.',
			'settings.station.radioUserRequired' => 'O usuário de controle remoto do rádio é obrigatório',
			'settings.station.connectFailedBusy' => 'O dispositivo está em uso',
			'settings.station.connectFailedDenied' => 'Acesso negado',
			'settings.station.connectFailedDevice' => 'Dispositivo não encontrado',
			'settings.station.connectFailedLines' => 'Não foi possível manter RTS/DTR como definido, então a porta foi fechada. Outro programa pode ter deixado o controle de fluxo por hardware ligado — desconecte e reconecte o cabo.',
			'settings.station.connectFailedNetwork' => 'Não foi possível encontrar o rádio na rede. Verifique o endereço e se ele está ligado e acessível.',
			'settings.station.connectFailedTimeout' => 'O rádio não respondeu a tempo. Verifique se ele está ligado e acessível.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Genérico',
			'settings.station.models.icomGeneric' => 'Icom - Genérico',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Genérico',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Genérico',
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
			'settings.station.models.rigctld' => 'Rádio controlado via rigctld',
			'settings.station.models.rigctldNodeName' => 'Meu rádio (via rigctld)',
			'settings.station.models.flrig' => 'Rádio controlado via flrig',
			'settings.station.models.flrigNodeName' => 'Meu rádio (via flrig)',
			'settings.station.models.hrd' => 'Rádio controlado via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Meu rádio (via HRD)',
			'settings.station.models.n3fjp' => 'Rádio controlado via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Meu rádio (via N3FJP)',
			'settings.station.models.commander' => 'Rádio controlado via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Meu rádio (via Commander)',
			'settings.station.models.antenna' => 'Antena',
			'settings.station.models.key' => 'Chave de CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Rádio genérico (provisório)',
			'settings.station.models.placeholderRadioNodeName' => 'Meu rádio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Chave coaxial Sierra Radio CX-1',
			'settings.station.transports.network' => 'Rede/WiFi',
			'settings.station.transports.usbSerial' => 'Serial USB',
			'settings.station.transports.wifi' => 'Rede/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Serial Bluetooth',
			'settings.station.transports.placeholder' => 'Provisório',
			'settings.station.troubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.ft891Troubleshooting' => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **CAT RTS deve estar OFF no rádio** (menu **05-08** do FT-891). Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa. Em um Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, então elevá-la acionaria seu transmissor. Na porta USB do próprio rádio, **Manter RTS alto** nas Configurações avançadas é a alternativa.\n- **A velocidade deve corresponder** ao CAT RATE do rádio (menu **05-06**). Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.yaesuBinaryTroubleshooting' => 'Este rádio usa o CAT antigo de cinco bytes da Yaesu e não responde nada quando algo está errado. Quase sempre é um destes:\n\n- **O cabo precisa converter os níveis.** O conector CAT traseiro não é RS-232 nem USB; ele precisa de um CT-62 ou adaptador equivalente. Um cabo simples de áudio ou de dados não funciona para CAT.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio (**#14** no FT-817, **#19** no FT-857 ou FT-897). Se não corresponder, o rádio não devolve nada, e nunca um erro.\n- **Nunca deixe nada elevar RTS ou DTR nesta porta.** Na maioria dos cabos para estes rádios essas linhas são PTT e manipulação. Uma interface antiga alimentada pelo DTR é a exceção: ative **Manter DTR alto** nas Configurações avançadas para ela.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\nEste driver foi escrito a partir da tabela CAT publicada pela Yaesu e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena relatar.',
			'settings.station.guohetecTroubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.guohetecTroubleshooting' => 'O Q900 tem dois protocolos CAT, e esta entrada usa o nativo em vez da imitação do FT-817. Escolha **Guohetec Q900** aqui, não um FT-817 — a imitação suporta menos comandos, e o rádio não diz qual está usando.\n\n- **O cabo USB-C é o link CAT**, e também conecta a placa de som. A velocidade não importa nele; a porta ignora o valor definido.\n- **Nunca deixe nada elevar RTS ou DTR nesta porta.** Em um cabo serial essas linhas são PTT e manipulação.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Um rádio de segunda geração se comporta de forma diferente** de um de primeira. Pressione Menu longamente e depois About: HW 2.0 é a segunda geração.\n\nEste driver foi escrito a partir do protocolo publicado pelo fabricante e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena relatar.',
			'settings.station.yaesuTroubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.yaesuTroubleshooting' => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa. Em um Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, então elevá-la acionaria seu transmissor. Na porta USB do próprio rádio, **Manter RTS alto** nas Configurações avançadas é a alternativa. O local dessa configuração varia conforme o modelo (menu **05-08** no FT-891).\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Os modos seguem a tabela do FT-891.** A maior parte da linha Yaesu corresponde a ela, mas um rádio que numera os modos de outra forma mostrará e definirá o modo errado nesses casos. A frequência não é afetada.',
			'settings.station.yaesuRs232Troubleshooting' => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **O conector CAT é RS-232.** Ele precisa de um adaptador USB-serial e de um cabo DB-9 direto — um cabo null-modem inverte as linhas, e o rádio nunca recebe nada.\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa, a menos que **Manter RTS alto** esteja ativado nas Configurações avançadas.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\nEsta entrada foi escrita a partir da documentação CAT publicada e ainda não foi testada com um destes rádios. Se funcionar só em parte, vale a pena relatar.',
			'settings.station.yaesuUsbTroubleshooting' => 'O rádio está recebendo comandos, mas não responde. Quase sempre é um destes:\n\n- **Use a primeira das duas portas USB do rádio.** O CAT normalmente fica na primeira (a porta COM **Enhanced** no Windows); a segunda (**Standard**) é para PTT e manipulação. O seletor aponta para a primeira sempre que consegue distinguir as duas.\n- **CAT RTS deve estar OFF no rádio.** Com ele ligado, o rádio espera uma linha de handshake que o app mantém baixa, a menos que **Manter RTS alto** esteja ativado nas Configurações avançadas.\n- **A velocidade deve corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.',
			'settings.station.k4SerialNotes' => 'Conecte a entrada traseira USB-B (PC) do K4. Tanto USB-PC1 quanto USB-PC2 servem para CAT; escolha uma porta livre e ajuste a configuração Serial USB-PCn: Baud Rate correspondente no rádio. O HaLo preenche 38400; altere se necessário. Outro aplicativo deve usar a outra porta ou a Ethernet.\n\nEsta conexão controla o rádio e seus keyers; ela não envia áudio para o HaLo.',
			'settings.station.k4TcpNotes' => 'Conecte a entrada Ethernet do K4 à sua rede local. Insira o nome de host ou endereço IP e a porta CAT 9200. Isto é controle CAT, não a conexão separada de áudio remoto na porta 9204.\n\nO HaLo controla o rádio e seus keyers sem transmitir áudio ou dados de panadapter.',
			'settings.station.k4PowerTimeout' => 'A potência do K4 não foi alterada porque o rádio não confirmou sua faixa de saída. Tente novamente.',
			'settings.station.k4PowerRange' => 'A potência do K4 deve ser 0.1–110 W, ou 0.0001–0.01 W quando a saída de miliwatts do transverter estiver ativa.',
			'settings.station.elecraftTroubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.elecraftTroubleshooting' => 'Os rádios Elecraft usam o CAT da Kenwood, e um KX2 e um KX3 já foram testados assim — VFO nos dois sentidos, troca de modo e batimento zero em CW, tudo funcionando.\n\nSe o rádio não responder, quase sempre é um destes:\n\n- **A velocidade deve corresponder** à taxa definida em **RS232** no menu do rádio. Eles vêm de fábrica com 38400. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n\n**Se a frequência estiver certa mas o modo errado**, nos avise. As entradas do KX2 e do KX3 leem o modo de uma posição na resposta de status do rádio que fixamos com base nos rádios que vimos, e um firmware que o coloque em outro lugar só chega até nós por um relato.\n\nO K3 ainda não foi relatado, então conte o que acontece se você usar um. O K4 tem sua própria entrada.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Se o rádio conecta mas não mostra frequência',
			'settings.station.kenwoodTroubleshooting' => 'Este driver foi testado com o TS-590SG e o TS-480 da Kenwood, o QMX e o QCX-mini da QRP Labs e o KX2 e o KX3 da Elecraft. O resto da linha foi escrito a partir de referências CAT publicadas, então relate o que acontecer, funcionando ou não.\n\nSe o rádio não responder, quase sempre é um destes:\n\n- **A velocidade deve corresponder** ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.\n- **Alguns rádios precisam do CAT ativado** no menu antes de responder.\n\n**Vários front-ends SDR usam este mesmo protocolo**, então vale a pena tentar esta entrada para eles também; os rádios Elecraft estão listados à parte, em Elecraft. Se a frequência estiver certa mas o modo errado ou ausente, essa é a única parte que varia na linha — o app a deduz a partir do rádio e, se não conseguir, pergunta diretamente, então o modo pode simplesmente demorar a aparecer.',
			'settings.station.statusConnected' => 'Conectado',
			'settings.station.statusLost' => 'Desconectado',
			'settings.station.notConfigured' => 'Não configurado',
			'settings.station.currentConfiguration' => 'Configuração atual',
			'settings.station.currentTransceiver' => 'Transceptor atual',
			'settings.station.radioMode' => 'Modo do rádio',
			'settings.station.keyerNotSupported' => 'Não suportado pelo rádio atual',
			'settings.station.catControlPreferences' => 'Preferências de controle CAT',
			'settings.station.chooseTransceiver' => 'Escolher transceptor',
			'settings.station.configurationSection' => 'Configuração',
			'settings.station.noTransceiverSelected' => 'Nenhum transceptor selecionado',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Usar ${name} como VFO principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, zero: 'Nenhum transceptor', one: '${count} transceptor', other: '${count} transceptores', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} antena', other: '${count} antenas', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} outro dispositivo', other: '${count} outros dispositivos', ), 
			'settings.station.equipmentInventory' => 'Inventário de equipamentos',
			'settings.station.equipmentInUse' => 'Controles do transceptor',
			'settings.station.noTransceiver' => 'Nenhum',
			'settings.station.peerRadioNotAvailable' => 'Indisponível',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Em ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} está em outro dispositivo',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Este rádio está conectado a ${device}. A conexão e as configurações dele são definidas nesse dispositivo.',
			'settings.station.antennaInUse' => 'Antena em uso',
			'settings.station.keyInUse' => 'Chave em uso',
			'settings.station.noneSelected' => 'Nenhuma',
			'settings.station.moreSettings' => 'Mais configurações',
			'settings.station.icomCivTroubleshootingTitle' => 'Se aparecerem duas portas seriais para o mesmo rádio',
			'settings.station.icomCivTroubleshooting' => 'Vários rádios Icom, entre eles o IC-705, apresentam **duas** portas seriais USB ao mesmo tempo (a Icom as chama de Port A e Port B), ambas configuradas como CI-V por padrão. Nem este app nem seu sistema operacional conseguem distingui-las além disso: o mesmo ID de fabricante/produto USB simplesmente aparece duas vezes, às vezes marcado aqui com o sufixo `#2`. **A Port A costuma ser a certa** — normalmente a primeira que seu sistema ou navegador lista, e quando este app consegue distinguir as duas portas, marca essa como sugerida. Se os comandos saem e o rádio nunca responde, tente a outra porta.',
			'settings.station.civAddressTroubleshootingTitle' => 'Se o rádio nunca responde',
			'settings.station.civAddressTroubleshooting' => '- **O endereço CI-V deve corresponder** ao menu do rádio. Esta entrada preenche o endereço de fábrica do modelo, mas um rádio que compartilha um barramento CI-V é exatamente onde ele é alterado. Um quadro enviado ao endereço errado é ignorado em silêncio, o que parece exatamente um cabo com defeito.\n- **A velocidade deve corresponder** ao CI-V BAUD RATE do rádio (no USB, CI-V USB Baud Rate). Ajuste o rádio para o mesmo número mostrado aqui, **não Auto**. Em Auto, alguns rádios, entre eles o IC-7300, conectam e depois param de responder após cerca de um minuto.\n- **Outro app pode estar usando a porta**: WSJT-X, fldigi e rigctld a mantêm aberta.',
			'settings.station.ic7300Mk2Note' => '\n- O **IC-7300 MK2** vem de fábrica com o endereço `B6`, não o `94` preenchido aqui — escolha a entrada IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- O **IC-705** apresenta duas portas seriais USB, ambas com o nome do rádio. O CI-V fica na **primeira** delas, para a qual o seletor aponta sempre que consegue distinguir as duas.',
			'settings.station.ic7760PortNote' => '\n- O **IC-7760** usa CI-V na **Port A** das duas portas seriais USB que apresenta.',
			'settings.station.x6100PortNote' => '\n- O **X6100** usa CI-V na porta **DEV** — a segunda das duas portas seriais que apresenta, e a que o seletor indica.',
			'settings.station.rigctldTroubleshootingTitle' => 'Se o app não consegue conectar',
			'settings.station.rigctldTroubleshooting' => 'Isto conecta a um **daemon rigctld que você mesmo roda**, não diretamente ao rádio — o backend do Hamlib conversa com o rádio e suporta centenas de modelos.\n\n- **O daemon já deve estar rodando**, por exemplo `rigctld -m 1035 -r /dev/ttyUSB0`. Encontre o número do modelo do seu rádio com `rigctl -l`.\n- **De outra máquina**, inicie-o com `-T 0.0.0.0`: por padrão o rigctld só aceita conexões da máquina em que roda.\n- **A porta** é 4532, a menos que você tenha iniciado o daemon com `-t`.\n- Depois de conectado, uma frequência ausente geralmente significa que o próprio daemon não consegue acessar o rádio. Teste com `rigctl -m 2 f` na máquina do daemon.',
			'settings.station.flrigTroubleshootingTitle' => 'Se o app não consegue conectar',
			'settings.station.flrigTroubleshooting' => 'Isto conecta a um **programa flrig que você mesmo roda**, não diretamente ao rádio — o flrig conversa com o rádio e suporta a maioria das marcas e modelos.\n\n- **O flrig já deve estar rodando**, com o transceptor configurado e conectado.\n- **A porta** é 12345, a menos que você a tenha alterado na configuração do flrig (Config → Setup → Server).\n- **De outra máquina**, verifique se o servidor do flrig está acessível. Ele escuta em todas as interfaces, mas seu firewall pode discordar.\n- Depois de conectado, uma frequência ausente geralmente significa que o próprio flrig não consegue acessar o rádio. Verifique se o display do flrig acompanha o dial.',
			'settings.station.hrdTroubleshootingTitle' => 'Se o app não consegue conectar',
			'settings.station.hrdTroubleshooting' => 'Isto conecta ao **Rig Control do Ham Radio Deluxe, rodando no seu computador**, não diretamente ao rádio — o HRD conversa com o rádio.\n\n- **O Rig Control já deve estar rodando** e conectado ao rádio.\n- **O servidor IP dele deve estar ativado.** O Rig Control só conversa com outros programas por meio dele.\n- **A porta** é 7809, a menos que você a tenha alterado nas configurações do servidor IP.\n- **De outra máquina**, verifique se seu firewall deixa a conexão passar.\n\nEsta entrada foi escrita a partir de descrições publicadas do protocolo do HRD e ainda não foi testada com o HRD. Se funcionar só em parte, vale a pena relatar.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Se o app não consegue conectar',
			'settings.station.n3fjpTroubleshooting' => 'Isto conecta a **um programa de log N3FJP rodando no seu computador**, não diretamente ao rádio — o N3FJP conversa com o rádio.\n\n- **A API do programa deve estar ativada**: em Settings → Application Program Interface, marque **TCP API Enabled**.\n- **A porta** é 1100, a menos que você a tenha alterado lá.\n- **O N3FJP precisa ter uma interface de rádio configurada** para acompanhar ou sintonizar o rádio. Sem ela, ele informa apenas o que é digitado na janela de entrada.\n- O N3FJP informa apenas banda, modo e frequência: sem potência, sem estado de transmissão.\n\nEsta entrada foi escrita a partir da API publicada do N3FJP e ainda não foi testada com o N3FJP. Se funcionar só em parte, vale a pena relatar.',
			'settings.station.commanderTroubleshootingTitle' => 'Se o app não consegue conectar',
			'settings.station.commanderTroubleshooting' => 'Isto conecta ao **DXLab Commander, rodando no seu computador**, não diretamente ao rádio — o Commander conversa com o rádio.\n\n- **O Commander já deve estar rodando** e conectado ao rádio.\n- **O serviço de rede dele deve estar ativado**: o botão **Net Serv** no painel Radio da janela Configuration do Commander.\n- **A porta** é 52002, a terceira porta do bloco que começa na **Base Port** do Net Serv (52000, a menos que você a tenha alterado).\n- **De outra máquina**, verifique se seu firewall deixa a conexão passar.\n\nEsta entrada foi escrita a partir das mensagens TCP publicadas do Commander e ainda não foi testada com o Commander. Se funcionar só em parte, vale a pena relatar.',
			_ => null,
		} ?? switch (path) {
			'settings.station.ic705TroubleshootingTitle' => 'Se o rádio nunca responde',
			'settings.station.ic705Troubleshooting' => 'O rádio tem uma **única** sessão de controle remoto. Quando o login é ignorado, quase sempre outra coisa a está usando.\n\n- **Feche qualquer outro cliente.** O wfview ou o RS-BA1 conectado ao mesmo rádio ocupa essa sessão, e o login aqui é simplesmente ignorado enquanto isso.\n- **Verifique as configurações de rede do rádio.** O WLAN deve estar ligado, o rádio deve estar na mesma rede e a função de controle remoto (Network) deve estar ativada.\n- **Desligue e ligue o WLAN do rádio** se ele continuar travado. Isso sempre libera uma sessão presa no rádio.\n\nUma **senha errada é recusada explicitamente**, não recebida com silêncio. Se você chegou aqui em vez de ver uma mensagem de "rejeitado", o problema não é a senha.',
			'settings.station.statusStale' => 'Sem resposta',
			'settings.station.statusDisconnected' => 'Não conectado',
			'settings.station.statusConnecting' => 'Conectando…',
			'settings.station.statusDisconnecting' => 'Desconectando…',
			'settings.station.statusError' => 'Falha na conexão',
			'settings.station.currentRadioSettings' => 'Configurações atuais do rádio',
			'settings.station.notSupportedByThisRadio' => 'Não suportado por este rádio',
			'settings.station.keyerRowLabel' => 'Manipulador',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Fonia',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Manipulador de voz: ${count} memórias no rádio',
			'settings.station.antennaBands' => 'Bandas',
			'settings.station.antennaType' => 'Tipo de antena',
			'settings.station.antennaTypeRequired' => 'Escolha um tipo de antena',
			'settings.station.antennaTypes.dipole' => 'Dipolo',
			'settings.station.antennaTypes.vertical' => 'Vertical',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Direcional',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Fio longo / EFHW',
			'settings.station.antennaTypes.other' => 'Outra',
			'settings.station.keyType' => 'Tipo de chave',
			'settings.station.keyTypeRequired' => 'Escolha um tipo de chave',
			'settings.station.keyTypes.straight' => 'Chave vertical',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semiautomática mecânica)',
			'settings.station.keyTypes.fullyAutomatic' => 'Keyer totalmente automático',
			'settings.station.keyTypes.singlePaddle' => 'Paddle simples',
			'settings.station.keyTypes.dualPaddle' => 'Paddle duplo',
			'settings.station.keyTypes.computerDriven' => 'Controlada por computador',
			'settings.station.keyTypes.other' => 'Outra',
			'settings.station.softwareIntermediaries' => 'Softwares intermediários',
			'settings.station.otherBrands' => 'Outras marcas',
			'settings.station.otherEquipment' => 'Outros equipamentos (antenas, chaves etc.)',
			'settings.station.newAntenna' => 'Nova antena',
			'settings.station.newKey' => 'Nova chave',
			'settings.station.newKeyer' => 'WinKeyer (K1EL ou compatível)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Manipulador CAT em ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Chave em ${device}',
			'settings.station.cwKeyerArea' => 'Área do manipulador',
			'settings.station.trackStationInfo' => 'Registrar dados da estação em cada QSO',
			'settings.station.includeStationInfoInAdif' => 'Incluir nas exportações ADIF',
			'settings.station.whatToTrack' => 'O que registrar?',
			'settings.station.trackFieldRig' => 'Transceptor',
			'settings.station.trackFieldPower' => 'Potência',
			'settings.station.watts' => 'Watts',
			'settings.station.trackFieldAntenna' => 'Antena',
			'settings.station.trackFieldKey' => 'Chave de CW',
			'settings.station.placeholderConnectDelay' => 'Atraso de conexão (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Quanto tempo leva o handshake simulado. Vazio ou 0 conecta na hora.',
			'settings.station.placeholderDropAfter' => 'Cair após (segundos)',
			'settings.station.placeholderDropAfterDescription' => 'Fecha a conexão sozinho, para testar a reconexão. Vazio ou 0 nunca cai.',
			'settings.station.placeholderFailConnect' => 'Sempre falhar ao conectar',
			'settings.station.placeholderConnectFailure' => 'O rádio provisório foi instruído a recusar esta conexão',
			'settings.station.placeholderFreq' => 'Frequência (kHz)',
			'settings.station.placeholderFreqDescription' => 'Onde o rádio provisório começa. Depois ele informa a frequência que o app sintonizar.',
			'settings.station.placeholderMode' => 'Modo',
			'settings.station.placeholderModeDescription' => 'O modo em que o rádio provisório começa, por exemplo USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Potência (watts)',
			'settings.station.placeholderPurpose' => 'Use este rádio para registrar qual equipamento você está usando nos seus logs',
			'settings.station.placeholderReplyDelay' => 'Atraso de resposta (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Quanto tempo o rádio provisório leva para informar uma alteração. Vazio ou 0 responde na hora.',
			'settings.station.cwKeyerField' => 'Manipulador CW via CAT',
			'settings.station.cwKeyerFieldDescription' => 'Se este rádio manipula CW a partir de texto via CAT. Desligado para um rádio que o app não conhece.',
			'settings.station.voiceMemories' => 'Memórias de voz',
			'settings.station.voiceMemoriesDescription' => 'Quantas memórias de voz o rádio reproduz via CAT. 0 para nenhuma.',
			'settings.station.voiceMemoriesInvalid' => 'Um número inteiro, 0 ou mais',
			'settings.station.yaesuMeterCapture' => 'Capturar leituras dos medidores',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Lê o medidor de potência de saída e o indicador de ROE alta do rádio durante a transmissão e grava os valores brutos no log. Serve para montar a escala que a Yaesu não publica — os valores não são mostrados como medidores.',
			'settings.station.yaesuMeterCaptureDescription' => 'Lê os medidores PO, SWR e ALC do rádio durante a transmissão e grava os valores brutos no log. Serve para montar a escala que a Yaesu não publica — os valores não são mostrados como medidores.',
			'settings.station.telemetryInterval' => 'Intervalo de leitura dos medidores (ms)',
			'settings.station.telemetryIntervalDescription' => 'Com que frequência ler os medidores do rádio enquanto ele transmite. Deixe vazio para o mais rápido que esta conexão suporta, até 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}',
			'settings.station.pollInterval' => 'Intervalo de consulta em repouso (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Com que frequência perguntar ao rádio a frequência e o modo enquanto nenhum dos dois muda. Deixe vazio para ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}',
			'settings.station.advancedSettings' => 'Configurações avançadas',
			'settings.station.placeholderSwr' => 'Leitura de ROE',
			'settings.station.placeholderSwrDescription' => 'O que este rádio informa no medidor de ROE durante a transmissão. Acima de 1.8, o painel avisa.',
			'settings.station.placeholderSwrInvalid' => 'Um número, 1 ou mais',
			'settings.station.keyerNone' => 'Nenhum',
			'settings.station.cwDialect' => 'Dialeto de manipulação CW',
			'settings.station.cwDialectDescription' => 'Qual formato do comando KY este rádio aceita. Nenhum significa sem manipulação CW via CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, completado até 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (texto KY)',
			'settings.station.voiceDialect' => 'Dialeto do manipulador de voz',
			'settings.station.voiceDialectDescription' => 'Como este rádio reproduz suas memórias de voz via CAT. Nenhum significa sem memórias de voz via CAT. Com um dialeto e sem quantidade, vale a quantidade padrão do dialeto.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, estilo TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB e DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (toques de botão)',
			'settings.station.placeholderDiagnostic' => 'Simulado',
			'settings.station.placeholderWholeNumberInvalid' => 'Deve ser um número inteiro, 0 ou mais',
			'settings.station.placeholderFreqInvalid' => 'Deve ser uma frequência em kHz, maior que zero',
			'settings.station.placeholderModeInvalid' => 'Deve ser um nome de modo, por exemplo USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposição',
			'settings.station.switchLayoutDescription' => 'Em qual lado da chave seus rádios estão conectados.',
			'settings.station.switchLayoutRequired' => 'Escolha como a chave está ligada',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'A chave recusou "${command}" (erro ${code})',
			'settings.station.switchBusyTransmitting' => 'Essa porta está transmitindo — antena não alterada',
			'settings.station.switchNoAntenna' => 'Nenhuma',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antena na porta ${port}',
			'settings.station.switchAntennaForDescription' => 'Qual das suas antenas está conectada a esta porta da chave.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antenas, ${radios} rádios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antenas, 1 rádio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antena, ${radios} rádios',
			'settings.station.switchCommonPort' => 'Comum',
			'settings.station.dcnAddress' => 'Endereço do dispositivo',
			'settings.station.dcnAddressDescription' => 'O endereço definido nas chaves DIP do módulo. Um módulo de relé coaxial sai de fábrica com 2.',
			'settings.station.dcnAddressRequired' => 'Deve ser um endereço de dispositivo de 1 a 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Porta ${port}',
			'settings.station.switchPortAutoHint' => 'segue os dados de banda',
			'settings.station.switchPortTransmittingHint' => 'transmitindo — não pode mudar agora',
			'settings.station.switchCurrentStateHeader' => 'Estado atual',
			'settings.station.switchCurrentStateDescription' => 'Em qual antena cada porta de rádio está agora. As alterações têm efeito imediato.',
			'settings.station.switchWiringHeader' => 'Ligações',
			'settings.station.switchPortInhibitedHint' => 'transmissão inibida',
			'settings.station.configUnreadable' => 'Não foi possível ler as configurações salvas deste rádio. Abra as configurações dele e insira-as novamente, ou remova-o e adicione-o de novo.',
			'settings.station.autoConnectHeld' => 'O HaLo parou de responder na última vez que se conectou a este rádio, então desta vez não se conectou sozinho. Pressione Conectar para tentar novamente.',
			'settings.offlineData.title' => 'Dados offline',
			'settings.offlineData.noFiles' => 'Nenhum arquivo de dados',
			'settings.offlineData.noFilesDescription' => 'Habilite extensões de atividade ou de consulta para baixar os dados offline delas aqui.',
			'settings.offlineData.refresh' => 'Atualizar',
			'settings.offlineData.refreshing' => 'Atualizando…',
			'settings.offlineData.updateAll' => 'Atualizar todos',
			'settings.offlineData.updatingAll' => 'Atualizando todos os arquivos de dados…',
			'settings.offlineData.neverDownloaded' => 'Nunca baixado',
			'settings.offlineData.updatedJustNow' => 'Atualizado agora mesmo',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Atualizado há ${days}d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Atualizado há ${days}d ${hours}h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Atualizado há ${hours}h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Atualizado há ${hours}h ${minutes}min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Atualizado há ${minutes}min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'O último download tinha apenas ${imported} de ${existing} registros e não foi usado. Atualize para aceitá-lo.',
			'settings.offlineData.extensionsSection' => 'Extensões',
			'settings.profiles.notSet' => 'Não definido',
			'settings.profiles.personalInfo' => 'Informações pessoais',
			'settings.profiles.personalInfoNote' => 'Isto pode ser incluído nos logs gerados quando for relevante para envios',
			'settings.profiles.name' => 'Nome',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Clube',
			'settings.profiles.arrlSection' => 'Seção ARRL',
			'settings.profiles.racSection' => 'Seção RAC',
			'settings.profiles.section' => 'Seção',
			'settings.search.clear' => 'Limpar',
			'settings.search.hint' => 'Buscar preferências',
			'settings.developer.developerModeDescription' => 'Habilita avisos de desenvolvedor, logs de depuração e ferramentas.',
			'settings.developer.experiments' => 'Experimentos',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} habilitado', other: '${count} habilitados', ), 
			'settings.developer.patchTrack' => 'Faixa de patches',
			'settings.developer.patchTrackDescription' => 'Qual faixa de patches de código pela internet este dispositivo segue. Faixas mais ousadas recebem correções antes, menos testadas. Os patches são aplicados na próxima reinicialização.',
			'settings.developer.trackStable' => 'Estável',
			'settings.developer.trackUnstable' => 'Instável',
			'settings.developer.trackBleeding' => 'Experimental',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Verificando patches em "${track}"…',
			'settings.developer.patchDownloaded' => 'Patch baixado — reinicie o app para aplicá-lo.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Nenhum patch novo em "${track}".',
			'settings.developer.noPatchInstalled' => 'Nenhum patch instalado — rodando o binário da versão.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Rodando o patch nº ${patch}.',
			'settings.developer.deepLinks' => 'Deep links',
			'settings.developer.registerUrlSchemes' => 'Registrar esquemas de URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permite que links com.ham2k:// abram esta cópia do app',
			'settings.developer.registerUrlSchemesDone' => 'Esta cópia agora abre links com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Não foi possível registrar: ${error}',
			'settings.developer.systemInformation' => 'Informações do sistema',
			'settings.developer.appVersion' => 'Versão do app',
			'settings.developer.dataFolder' => 'Pasta de dados',
			'settings.developer.loading' => '(carregando…)',
			'settings.developer.panelLoadFailed' => 'Não foi possível carregar este painel de configurações.',
			'settings.developer.extDevServer' => 'Servidor de desenvolvimento de extensões',
			'settings.developer.extensionSettings' => 'Configurações de extensões',
			'settings.developer.extDevServerDescription' => 'Carrega extensões de um servidor de desenvolvimento na sua rede em vez das integradas ao app, e as recarrega quando você salva.',
			'settings.developer.extDevServerAddress' => 'Endereço do servidor',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Conectar',
			'settings.developer.extDevServerDisconnect' => 'Desconectar',
			'settings.developer.extDevServerConnecting' => 'Conectando…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Servindo ${count} extensão: ${keys}', other: 'Servindo ${count} extensões: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Não conectado',
			'settings.developer.extDevServerReconnect' => 'Reconectar ao iniciar',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Última recarga: ${key} às ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} extensão com falha no build', other: '${count} extensões com falha no build', ), 
			'settings.developer.catalog' => 'Catálogo de extensões',
			'settings.developer.catalogDescription' => 'Lê o catálogo de outro servidor — um local, ao trabalhar no próprio catálogo. Vazio significa catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Endereço do catálogo',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Faixas de busca do catálogo',
			'settings.developer.catalogSearchStable' => 'Apenas estável',
			'settings.developer.catalogSearchUnstable' => 'Instável ou melhor',
			'settings.developer.catalogSearchBleeding' => 'Experimental ou melhor',
			'settings.about.notices' => 'Avisos e mensagens',
			'settings.about.noticesDescription' => 'Anúncios e mensagens de status',
			'settings.about.releaseNotes' => 'Notas de versão',
			'settings.about.copiedVersion' => 'Detalhes da versão copiados para a área de transferência',
			'settings.panels.settings' => 'Preferências do aplicativo',
			'settings.panels.settingsDescription' => 'Faça o app funcionar do seu jeito',
			'settings.panels.commonSettings' => 'Preferências comuns',
			'settings.panels.syncDescription' => 'Faça backup e sincronize seus logs entre dispositivos',
			'settings.panels.accountsDescription' => 'Credenciais de serviços, dados offline e mais',
			'settings.panels.extensions' => 'Extensões e funcionalidades',
			'settings.panels.extensionsDescription' => 'Atividades, concursos, painéis e mais funcionalidades',
			'settings.panels.profilesDescription' => 'Indicativo do operador e perfil da estação',
			'settings.panels.stationProfiles' => 'Perfis de estação',
			'settings.panels.developerSettings' => 'Configurações de desenvolvedor',
			'settings.panels.developerSettingsDescription' => 'Ferramentas de depuração e desenvolvimento',
			'settings.panels.about' => 'Sobre',
			'settings.panels.aboutDescription' => 'Versão, créditos e informações legais',
			'settings.panels.unavailableTitle' => 'Algumas configurações estão indisponíveis',
			'settings.panels.unavailableText' => 'O ambiente de extensões não iniciou, então as configurações fornecidas por extensões estão faltando.',
			'settings.panels.station' => 'Configuração da estação',
			'settings.panels.stationDescription' => 'Controle CAT e mais opções',
			'settings.panels.peers' => 'Dispositivos pareados',
			'settings.panels.peersDescription' => 'Conecte-se a outros dispositivos próximos',
			'settings.showMoreSettings' => 'Mostrar mais configurações',
			'settings.gridPrecision' => 'Precisão do grid',
			'settings.gridPrecisionOpts.six' => '6 dígitos (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 dígitos (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 dígitos',
			'settings.gridPrecisionDescription.eight' => '8 dígitos',
			'commands.enableSyncFirst' => 'Habilite a sincronização nas Configurações primeiro.',
			'commands.fullResyncStarted' => 'Ressincronização completa iniciada — os dados locais foram salvos em backup antes.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Nenhum arquivo de dados corresponde a "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'Falha ao recarregar: ${error}',
			'commands.reloadingAll' => 'Recarregando todos os arquivos de dados…',
			'commands.reloadingTarget' => ({required Object target}) => 'Recarregando arquivos de dados de ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experimento desconhecido "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} habilitado',
			'commands.experimentDisabled' => ({required Object name}) => '${name} desabilitado',
			'commands.sentryTestSent' => 'Relatório de erro de teste enviado ao Sentry',
			'commands.sentryTestLocalOnly' => 'O Sentry está desativado nesta build — erro de teste registrado apenas localmente',
			'commands.noOperationOpen' => 'Esse comando precisa de uma operação aberta',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Não sei como marcar \'${kind}\'',
			'commands.operationAlreadyStarted' => 'Esta operação já tem um marcador de início',
			'commands.couldNotOpenLocation' => 'O intervalo foi adicionado, mas não foi possível abrir a tela de localização',
			'commands.noTestOperations' => 'Nenhuma operação de teste para eliminar',
			'commands.purgeTestsUnavailable' => 'PURGETESTS precisa mostrar uma caixa de confirmação, que não está disponível aqui',
			'commands.syncAllUnavailable' => 'SYNCALL precisa mostrar uma caixa de confirmação, que não está disponível aqui',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} operação de teste eliminada', other: '${count} operações de teste eliminadas', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '${purged} de ${total} operações de teste eliminadas — as demais falharam; tente PURGETESTS novamente',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contato de teste sem operação eliminado', other: '${count} contatos de teste sem operação eliminados', ), 
			'commands.purgeTestsContactsFailed' => 'As operações de teste foram eliminadas, mas os contatos de teste sem operação falharam; tente PURGETESTS novamente',
			'commands.purgeTestsNothingToDo' => 'Nada foi eliminado',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '${removed} de ${total} operações de teste removidas — as demais falharam; tente Revisar novamente',
			'commands.receivedPurgesFailed' => 'Não foi possível remover essas operações de teste — tente Revisar novamente',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} operação de teste foi removida em outro dispositivo', other: '${count} operações de teste foram removidas em outro dispositivo', ), 
			'commands.receivedPurgesReview' => 'Revisar',
			'commands.settingOn' => 'Ligado',
			'commands.settingOff' => 'Desligado',
			'commands.settingEmpty' => '(vazio)',
			'commands.settingSecretSet' => '(definido)',
			'commands.settingSecretUnset' => '(não definido)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selecionados',
			'commands.settingExpectsOnOff' => 'on ou off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'um de: ${choices}',
			'commands.settingExpectsNumber' => 'um número',
			'commands.settingVanished' => ({required Object label}) => '“${label}” não está mais disponível',
			'commands.noCwKeyer' => 'Nenhum rádio conectado pode manipular CW',
			'commands.noKeyer' => 'Nenhum rádio conectado pode manipular CW ou reproduzir memórias de voz',
			'commands.keyerNeedsOperation' => 'Abra uma operação para usar o manipulador de CW',
			'commands.keyerExperimentOff' => 'A manipulação de CW está desligada — ative-a com EXP KEYER',
			'commands.esmExperimentOff' => 'Enter envia mensagens está desligado — ative com EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Enviando CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Mensagem de CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'A mensagem de CW F${n} não foi enviada: as extensões não estão prontas',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” não aceitou esse valor',
			'commandDialog.hint' => 'Busque indicativos ou digite um comando',
			'commandDialog.noResults' => ({required Object text}) => 'Nada corresponde a “${text}”',
			'commandDialog.sectionCommands' => 'Comandos',
			'commandDialog.sectionGoTo' => 'Ir para',
			'commandDialog.sectionOperations' => 'Operações',
			'commandDialog.goHome' => 'Início',
			'commandDialog.goSettings' => 'Configurações',
			'commandDialog.goNewOperation' => 'Nova operação',
			'commandDialog.runTyped' => ({required Object text}) => 'Executar “${text}”',
			'commandDialog.sectionSuggestions' => 'Experimente',
			'commandDialog.lookingUp' => 'Consultando indicativo…',
			'commandDialog.blockedByPane' => 'Não é possível usar comandos enquanto um painel ou diálogo está aberto',
			'expiredBuild.title' => 'Esta build expirou',
			'expiredBuild.body' => 'Visite ham2k.com e obtenha uma versão mais recente.',
			'expiredBuild.visit' => 'Visitar ham2k.com',
			'expiredBuild.dismiss' => 'Continuar mesmo assim',
			'staleness.codePushFloorTitle' => 'Uma atualização importante está aguardando',
			'staleness.codePushFloorBody' => 'Esta versão tem uma correção que você ainda não tem.',
			'staleness.restartToApply' => 'Reinicie o app para aplicá-la.',
			'staleness.quitAndReopen' => 'Saia do app e abra-o novamente para aplicá-la.',
			'staleness.reopenToApply' => 'Feche o app e abra-o novamente para aplicá-la.',
			'staleness.ignoreForNow' => 'Ignorar por enquanto',
			'spotting.noQsoYet' => 'Nenhum QSO registrado ainda para dar spot.',
			'spotting.setFrequencyFirst' => 'Defina uma frequência primeiro.',
			'spotting.nothingToSpot' => 'Nada para dar spot — nenhuma extensão oferece spots aqui.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} falhou: ${message}',
			'spotting.unknownError' => 'erro desconhecido',
			'spotting.notSent' => 'Spot não enviado.',
			'spotting.notRefreshedOffline' => 'Sem conexão — os spots não foram atualizados',
			'dataFiles.downloading' => 'Baixando…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Não foi possível baixar ${name}',
			'dataFiles.downloadFailedWebHint' => 'Pode ser um problema de rede, ou o servidor deste link pode não permitir downloads diretos de um navegador. Experimente o app para desktop ou celular, ou outro local de hospedagem.',
			'dataFiles.downloadTimedOut' => 'O servidor demorou demais para responder. Tente novamente mais tarde.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} respondeu com um erro (HTTP ${status}). Tente novamente mais tarde.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} não conseguiu fornecer este arquivo (HTTP ${status}). Verifique se o endereço ainda está correto.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Não foi possível processar ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'O download tinha apenas ${imported} dos ${existing} registros deste dispositivo, então os que ficaram de fora foram mantidos. Atualizá-lo em Configurações › Dados offline o aceita mesmo assim.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} registro importado para ${label}.', other: '${count} registros importados para ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Dados importados para ${label}.',
			'dataFiles.cleanedUpTitle' => 'Dados de extensões limpos',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Dados removidos de ${count} arquivo de dados de extensões desabilitadas.', other: 'Dados removidos de ${count} arquivos de dados de extensões desabilitadas.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} registros',
			'dataFiles.definitionUnavailable' => 'A origem do arquivo não forneceu uma definição — a extensão pode estar reiniciando ou mal configurada. Tente novamente em instantes.',
			'updates.updateAvailable' => 'Atualização disponível',
			'updates.newVersionAvailable' => ({required Object version}) => 'Uma nova versão (${version}) está disponível.',
			'updates.getIt' => 'Obter',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Atualização pronta',
			'updates.restartToApply' => 'Uma atualização foi baixada. Reinicie para aplicá-la.',
			'updates.appliesNextLaunch' => 'Uma atualização foi baixada. Ela será aplicada na próxima vez que você abrir o app.',
			'updates.restartNow' => 'Reiniciar agora',
			'updates.reloadToUpdate' => 'Uma versão mais nova desta página está disponível. Recarregue para obtê-la.',
			'updates.reloadNow' => 'Recarregar agora',
			'updates.checkForUpdates' => 'Verificar atualizações',
			'updates.checkingForUpdates' => 'Verificando atualizações…',
			'updates.upToDate' => 'Atualizado',
			'updates.automaticChecks' => 'Verificar automaticamente',
			'updates.automaticChecksDescription' => 'Procura novas versões em segundo plano, a partir da próxima vez que você iniciar o app',
			'extensionService.runtimeNotReady' => 'O ambiente de extensões não está pronto.',
			'extensionService.testFailed' => ({required Object error}) => 'O teste falhou: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Conectado como ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuração de campo inválida',
			'extensionService.invalidValue' => 'Valor inválido',
			'extensionService.validationError' => ({required Object error}) => 'Erro de validação: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'A ação falhou: ${error}',
			'extensionService.commandFailed' => 'O comando não pôde ser executado',
			'extensionService.reportUnavailable' => 'Não é possível enviar relatos agora',
			'extensionService.stashUnavailable' => 'O armazenamento de arquivos do Ham2K está inacessível agora',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} gastou tempo demais nos seus timers. Eles estão parados até as extensões reiniciarem.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Os timers de ${name} continuaram falhando. Eles estão parados até as extensões reiniciarem.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} travou em um timer. Os timers dela estão parados até as extensões reiniciarem.',
			'operationLocationScreen.title' => 'Local da operação',
			'operationLocationScreen.selectedLocation' => 'Local selecionado',
			'operationLocationScreen.gridSquare' => 'Grid Square',
			'operationLocationScreen.gridInvalid' => 'Precisa ter 4, 6, 8 ou 10 caracteres, como FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Locais sugeridos',
			'operationLocationScreen.deviceGps' => 'GPS do dispositivo',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de ${device}',
			'operationLocationScreen.locating' => 'Localizando…',
			'operationLocationScreen.gpsUnavailable' => 'Localização indisponível',
			'operationLocationScreen.permissionDenied' => 'Permissão de localização negada',
			'operationLocationScreen.permissionBlocked' => 'Permissão de localização bloqueada',
			'operationLocationScreen.moreDetails' => 'Mais detalhes',
			'operationLocationScreen.stateOrProvince' => 'Estado ou província (opcional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controles da atividade indisponíveis',
			'operationLocationScreen.controlsUnavailableReason' => 'Estas referências continuam utilizáveis; apenas não foi possível acessar as atividades delas.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Tentar novamente',
			'operationLocationScreen.county' => 'Condado (opcional)',
			'versionLabel.version' => ({required Object version}) => 'Versão ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Nenhum aviso ainda',
			'notices.webStorageInMemory' => 'Este navegador não conseguiu fornecer armazenamento persistente — o log fica apenas na memória e será PERDIDO quando esta aba for fechada. Use uma versão atual do Chrome, Firefox, Safari ou Edge.',
			'notices.webStorageUnreliable' => 'Este navegador está usando um armazenamento alternativo que não é seguro com várias abas — mantenha uma única aba aberta e deixe a sincronização ligada.',
			'notices.logFromNewerBuildTitle' => 'Este log precisa de uma versão mais nova',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Seu log foi gravado por uma versão mais nova do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), então não pode ser aberto, e novos contatos não serão salvos. Instale a versão mais nova novamente — ou, se você pretendia rodar esta build, aponte-a para outra pasta de dados. O log está em ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Seu log foi gravado por uma versão mais nova do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), então não pode ser aberto, e novos contatos não serão salvos. Abra este log com essa versão mais nova.',
			'notices.preferencesRestoredTitle' => 'Configurações restauradas de um backup',
			'notices.preferencesRestored' => 'Não foi possível ler o arquivo de configurações, então o HaLo restaurou a última cópia boa dele. O que você alterou na sessão anterior pode precisar ser definido novamente. O arquivo ilegível é mantido ao lado, com o nome shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Configurações redefinidas',
			'notices.preferencesReset' => 'Não foi possível ler o arquivo de configurações e não havia backup para recorrer, então o HaLo começou com os padrões. O arquivo ilegível é mantido na pasta de dados do app, com o nome shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} não foi conectado automaticamente',
			'notices.autoConnectHeld' => ({required Object name}) => 'O HaLo parou de responder na última vez que começou a se conectar a ${name}, então desta vez não tentou, para não arriscar que aconteça de novo. Verifique se o rádio está ligado e o cabo conectado, depois pressione Conectar nele nas Configurações.',
			'syncAccount.anonymous' => ({required Object id}) => 'Conta anônima (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (confirmação pendente)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (confirmação pendente - #${id})',
			'deepLink.needsAnOperation' => 'Inicie uma operação primeiro e depois envie esse contato novamente',
			'deepLink.waitingInOperation' => 'Esse contato está aguardando na operação por trás desta tela',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Este dispositivo não tem atividade para ${refs}, então essas referências ficaram de fora',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Não foi possível acessar suas atividades, então ${refs} ficou de fora — tente o link novamente',
			'confirmDevice.title' => 'Confirmar um dispositivo',
			'confirmDevice.codePrompt' => 'Insira o código mostrado no dispositivo que quer entrar nesta conta.',
			'confirmDevice.code' => 'Código',
			'confirmDevice.lookUp' => 'Consultar',
			'confirmDevice.codeNotFound' => 'Nenhuma solicitação corresponde a esse código. Os códigos expiram após 10 minutos — peça um novo ao outro dispositivo.',
			'confirmDevice.linkExpired' => 'Esse link expirou. Peça ao outro dispositivo para mostrar um novo código QR.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Vincular ${device} a esta conta?',
			'confirmDevice.unnamedDevice' => 'um dispositivo sem nome',
			'confirmDevice.grantWarning' => 'Ele poderá ler e alterar todas as operações e QSOs desta conta.',
			'confirmDevice.needsSyncTitle' => 'Este dispositivo ainda não sincroniza',
			'confirmDevice.needsSyncText' => 'Ative a sincronização do Ham2K Log Filer e vincule este dispositivo a uma conta antes que ele possa admitir outro.',
			'confirmDevice.malformedRequest' => 'O servidor de sincronização enviou uma solicitação que este app não conseguiu ler. Peça ao outro dispositivo para tentar novamente.',
			'confirmDevice.linkIt' => 'Vincular dispositivo',
			'switchAccounts.noAccountDetails' => 'Nenhum detalhe da conta ainda',
			'switchAccounts.currentAccount' => 'Conta atual',
			'switchAccounts.otherAccounts' => 'Outras contas',
			'switchAccounts.linkToAnother' => 'Vincular a outra conta',
			'switchAccounts.linkWithSibling' => 'Vincular com outro app Ham2K',
			'switchAccounts.linkWithPolo' => 'Vincular com a conta da versão antiga',
			'switchAccounts.linkWithSiblingDescription' => 'Você tem outro app Ham2K instalado. Vincule com a conta usada nele.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Aprove a solicitação no ${app} e depois volte aqui.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Abrir ${app} novamente',
			'switchAccounts.siblingNoGrant' => 'Não funcionou? Abra-o novamente ou volte e vincule de outra forma.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Não foi possível abrir ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'O link expirou e um novo está pronto — abra ${app} novamente.',
			'switchAccounts.tryAgain' => 'Tentar novamente',
			'switchAccounts.linkWithQr' => 'Vincular com um código QR',
			'switchAccounts.linkWithQrDescription' => 'Escaneie-o de um dispositivo que já usa a conta',
			'switchAccounts.linkWithEmail' => 'Vincular com um endereço de e-mail',
			'switchAccounts.linkWithEmailDescription' => 'Confirme com um código ou um link por e-mail',
			'switchAccounts.enterEmailPrompt' => 'Insira o endereço de e-mail da conta que você quer que este dispositivo use.',
			'switchAccounts.emailAddress' => 'Endereço de e-mail',
			'switchAccounts.linkAccount' => 'Vincular conta',
			'switchAccounts.copiedCode' => 'Código copiado para a área de transferência',
			'switchAccounts.copyCode' => 'Copiar código',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Abra o app Ham2K em um dispositivo já vinculado a ${email} e insira este código para aprovar a solicitação:',
			'switchAccounts.waitingForConfirmation' => 'Aguardando confirmação…',
			'switchAccounts.sendEmailInstead' => 'Enviar um e-mail de confirmação',
			'switchAccounts.emailSent' => ({required Object email}) => 'Um e-mail foi enviado para ${email}. Abra-o e confirme a solicitação para vincular este dispositivo.',
			'switchAccounts.resendEmail' => 'Reenviar e-mail',
			'switchAccounts.qrPrompt' => 'Escaneie este código QR de um dispositivo já vinculado à conta que você quer — por exemplo, com o Ham2K Portable Logger no seu celular.',
			'switchAccounts.serverUnreachable' => 'Não foi possível acessar o servidor de sincronização. Tente novamente mais tarde.',
			'switchAccounts.emailRequired' => 'Insira um endereço de e-mail para vincular.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Nenhuma conta encontrada para ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'O servidor de sincronização rejeitou a solicitação: ${error}',
			'switchAccounts.noLinkCode' => 'O servidor de sincronização não retornou um código de vínculo. Tente novamente mais tarde.',
			'switchAccounts.noConfirmationCode' => 'O servidor de sincronização não enviou um código de confirmação. Tente novamente mais tarde.',
			'switchAccounts.switchNotAccepted' => 'Essa conta não aceitou a troca. Tente vinculá-la com um endereço de e-mail.',
			'switchAccounts.requestFailed' => 'Algo deu errado na comunicação com o servidor de sincronização. Tente novamente mais tarde.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} operação', other: '${count} operações', ), 
			'adifImport.title' => 'Importar QSOs de ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Lendo ${filename}…',
			'adifImport.dropHint' => 'Solte um arquivo ADIF para importar',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO neste arquivo', other: '${formatted} QSOs neste arquivo', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} já está no seu log', other: '${formatted} já estão no seu log', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} será importado', other: '${formatted} serão importados', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contato novo', other: '${formatted} contatos novos', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} será mesclado com um contato existente', other: '${formatted} serão mesclados com contatos existentes', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} não pode ser importado (sem indicativo)', other: '${formatted} não podem ser importados (sem indicativo)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} precisa de uma análise mais detalhada', other: '${formatted} precisam de uma análise mais detalhada', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Não foi possível recuperar as referências de ${count} contato', other: 'Não foi possível recuperar as referências de ${formatted} contatos', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'As referências de ${programs} podem estar incompletas para ${count} contato', other: 'As referências de ${programs} podem estar incompletas para ${formatted} contatos', ), 
			'adifImport.stackingTypesUnknown' => 'Contatos combinados podem perder uma referência — as atividades não informaram quais tipos se acumulam. Cancele e tente novamente para evitar isso.',
			'adifImport.nothingToImport' => 'Nada neste arquivo pode ser importado',
			'adifImport.confirm' => 'Importar',
			'adifImport.importing' => ({required Object filename}) => 'Importando ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contato importado de ${filename}', other: '${formatted} contatos importados de ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Não foi possível importar ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} não parece ser um arquivo ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Aviso: este ADIF tem QSOs de ${calls}, mas eles serão importados como ${station} se você continuar.',
			'adifImport.stationCallJoin' => ' e ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} não tem data e não pode ser importado', other: '${formatted} não têm data e não podem ser importados', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Este arquivo registra uma ativação de ${refs}.',
			'adifImport.addActivation' => 'Adicioná-la a esta operação',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Apenas ${written} de ${planned} puderam ser aplicados — o log mudou enquanto você decidia.',
			'adifImport.busy' => 'Uma importação já está em andamento. Aguarde terminar antes de iniciar outra.',
			'adifImport.oneFileOnly' => 'Solte um arquivo ADIF por vez — a ordem de importação dos arquivos decide quais dados prevalecem.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} tem mais de ${limit} QSOs, o máximo que uma operação pode importar de uma vez.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: conectada',
			'offline.noRoute' => 'Nenhuma conexão de rede.',
			'offline.unreachable' => 'A rede está ativa, mas nenhum servidor responde — muitas vezes sinal de uma página de login esperando em um navegador.',
			'offline.reachable' => 'Todos os serviços respondendo normalmente.',
			'offline.whatStops' => 'Consultas, spots e arquivos de dados estão pausados. O registro e a sincronização com dispositivos próximos, não.',
			'offline.servicesTitle' => 'Serviços',
			'offline.noServices' => 'Nenhum serviço se manifestou ainda.',
			'offline.lastSuccess' => ({required Object when}) => 'Respondeu pela última vez há ${when}',
			'offline.neverSucceeded' => 'Ainda não respondeu',
			'offline.nextAttempt' => ({required Object when}) => 'Próxima tentativa em ${when}',
			'offline.nextAttemptNow' => 'Próxima tentativa pendente',
			'offline.retry' => 'Tentar agora',
			'offline.retrying' => 'Tentando…',
			'offline.retryReached' => 'Online novamente.',
			'offline.retryUnreachable' => 'Ainda sem resposta.',
			'offline.retryNotAttempted' => 'Nada para enviar agora.',
			'offline.retryThrottled' => 'Acabou de tentar — aguarde um momento.',
			'offline.retryDisabled' => 'A sincronização está desligada, então não há com o que testar.',
			'offline.syncService' => 'Sincronização Ham2K LoFi',
			'offline.retryInFlight' => 'Já está tentando — aguarde.',
			'exportSettings.defaultsDescription' => 'Configurações base para todas as exportações, com modelos separados de nome de arquivo e título para atividades de referência e outras atividades. Cada tipo de exportação pode fornecer seus próprios padrões ou configurações personalizadas.',
			'exportSettings.referenceActivities' => 'Atividades de referência',
			'exportSettings.otherActivities' => 'Outras atividades',
			'exportSettings.adifFields' => 'Campos ADIF',
			'exportSettings.loadFailed' => 'Não foi possível carregar as configurações de exportação.',
			'exportSettings.retry' => 'Tentar novamente',
			'exportSettings.compactFileNamesDescriptionOn' => 'Nomes de arquivo compactos, como N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Nomes de arquivo descritivos, como 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Incluindo nomes, endereços, e-mails, notas e localizações precisas nos arquivos ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Omitindo nomes, endereços, e-mails e notas; limitando localizações a grids de seis caracteres.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Incluindo informações de serviços de consulta de indicativos.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Omitindo informações de serviços de consulta de indicativos; mantendo os valores inseridos manualmente.',
			'exportSettings.customTemplatesDescriptionOn' => 'Seus modelos personalizados estão ativos e podem ser editados abaixo.',
			'exportSettings.customTemplatesDescriptionOff' => 'Os modelos padrão estão ativos. Seus modelos personalizados ficam guardados para depois.',
			'exportSettings.type' => 'Tipo de exportação',
			'exportSettings.defaults' => 'Padrões',
			'exportSettings.includeLookupData' => 'Incluir dados de consulta',
			'exportSettings.customTemplates' => 'Modelos personalizados',
			'exportSettings.filenameTemplate' => 'Modelo de nome de arquivo',
			'exportSettings.compactFilenameTemplate' => 'Modelo de nome de arquivo compacto',
			'exportSettings.titleTemplate' => 'Modelo de título',
			'exportSettings.adifNotesTemplate' => 'Notas QSO ADIF',
			'exportSettings.adifCommentTemplate' => 'Comentários QSO ADIF',
			'exportSettings.adifQslMessageTemplate' => 'Mensagem QSL ADIF',
			'exportSettings.shared' => 'As configurações valem para todas as extensões que usam este tipo de exportação.',
			'exportSettings.defaultTemplates' => 'Ative Modelos personalizados para editar os modelos deste tipo.',
			'templateEditor.previewLabel' => 'Pré-visualização:',
			'templateEditor.reset' => 'Redefinir',
			'templateEditor.docs' => 'Documentação de modelos',
			'templateEditor.preview' => 'Pré-visualização de exemplo',
			'templateEditor.reference' => 'Referência de modelos',
			'templateEditor.attributes' => 'Atributos disponíveis',
			'templateEditor.filters' => 'Filtros',
			'templateEditor.flowControl' => 'Controle de fluxo',
			'templateEditor.unavailable' => 'A pré-visualização fica indisponível até as extensões estarem prontas.',
			'templateEditor.empty' => '(saída vazia)',
			_ => null,
		};
	}
}
