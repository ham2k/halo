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
class TranslationsPt extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsPt({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.pt,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <pt>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsPt _root = this; // ignore: unused_field

	@override 
	TranslationsPt $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsPt(meta: meta ?? this.$meta);

	// Translations
	@override late final Translations$common$pt common = Translations$common$pt.internal(_root);
	@override late final Translations$onboarding$pt onboarding = Translations$onboarding$pt.internal(_root);
	@override late final Translations$startScreen$pt startScreen = Translations$startScreen$pt.internal(_root);
	@override late final Translations$testerOverlay$pt testerOverlay = Translations$testerOverlay$pt.internal(_root);
	@override late final Translations$extensionsPanel$pt extensionsPanel = Translations$extensionsPanel$pt.internal(_root);
	@override late final Translations$home$pt home = Translations$home$pt.internal(_root);
	@override late final Translations$chase$pt chase = Translations$chase$pt.internal(_root);
	@override late final Translations$dialogs$pt dialogs = Translations$dialogs$pt.internal(_root);
	@override late final Translations$operation$pt operation = Translations$operation$pt.internal(_root);
	@override late final Translations$map$pt map = Translations$map$pt.internal(_root);
	@override late final Translations$mapsView$pt mapsView = Translations$mapsView$pt.internal(_root);
	@override late final Translations$activitiesView$pt activitiesView = Translations$activitiesView$pt.internal(_root);
	@override late final Translations$loggingControls$pt loggingControls = Translations$loggingControls$pt.internal(_root);
	@override late final Translations$formChrome$pt formChrome = Translations$formChrome$pt.internal(_root);
	@override late final Translations$qsoEditForm$pt qsoEditForm = Translations$qsoEditForm$pt.internal(_root);
	@override late final Translations$qsoList$pt qsoList = Translations$qsoList$pt.internal(_root);
	@override late final Translations$loggingPanel$pt loggingPanel = Translations$loggingPanel$pt.internal(_root);
	@override late final Translations$callInfo$pt callInfo = Translations$callInfo$pt.internal(_root);
	@override late final Translations$settings$pt settings = Translations$settings$pt.internal(_root);
	@override late final Translations$commands$pt commands = Translations$commands$pt.internal(_root);
	@override late final Translations$commandDialog$pt commandDialog = Translations$commandDialog$pt.internal(_root);
	@override late final Translations$expiredBuild$pt expiredBuild = Translations$expiredBuild$pt.internal(_root);
	@override late final Translations$staleness$pt staleness = Translations$staleness$pt.internal(_root);
	@override late final Translations$spotting$pt spotting = Translations$spotting$pt.internal(_root);
	@override late final Translations$dataFiles$pt dataFiles = Translations$dataFiles$pt.internal(_root);
	@override late final Translations$updates$pt updates = Translations$updates$pt.internal(_root);
	@override late final Translations$extensionService$pt extensionService = Translations$extensionService$pt.internal(_root);
	@override late final Translations$operationLocationScreen$pt operationLocationScreen = Translations$operationLocationScreen$pt.internal(_root);
	@override late final Translations$versionLabel$pt versionLabel = Translations$versionLabel$pt.internal(_root);
	@override late final Translations$notices$pt notices = Translations$notices$pt.internal(_root);
	@override late final Translations$syncAccount$pt syncAccount = Translations$syncAccount$pt.internal(_root);
	@override late final Translations$deepLink$pt deepLink = Translations$deepLink$pt.internal(_root);
	@override late final Translations$confirmDevice$pt confirmDevice = Translations$confirmDevice$pt.internal(_root);
	@override late final Translations$switchAccounts$pt switchAccounts = Translations$switchAccounts$pt.internal(_root);
	@override late final Translations$adifImport$pt adifImport = Translations$adifImport$pt.internal(_root);
	@override late final Translations$offline$pt offline = Translations$offline$pt.internal(_root);
	@override late final Translations$exportSettings$pt exportSettings = Translations$exportSettings$pt.internal(_root);
	@override late final Translations$templateEditor$pt templateEditor = Translations$templateEditor$pt.internal(_root);
}

// Path: common
class Translations$common$pt extends Translations$common$en {
	Translations$common$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get save => 'Guardar';
	@override String get ok => 'OK';
	@override String get cancel => 'Cancelar';
	@override String get delete => 'Eliminar';
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
class Translations$onboarding$pt extends Translations$onboarding$en {
	Translations$onboarding$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Bem-vindo ao Ham2K Portable Logger!';
	@override String get welcomeTitleDesktop => 'Bem-vindo ao Ham2K Power Logger!';
	@override String get welcomeBody => 'Temos algumas perguntas para nos ajudar a adaptar a app às suas necessidades.';
	@override String get skip => 'Saltar';
	@override String get kContinue => 'Continuar';
	@override String get back => 'Voltar';
	@override String get next => 'Seguinte';
	@override String get done => 'Concluído';
	@override String get callsignTitle => 'Qual é o seu indicativo?';
	@override String get callsignBody => 'Precisa de uma licença de radioamador para que esta app lhe seja útil';
	@override String get callsignLabel => 'Indicativo do Operador';
	@override String get alreadyHaveAccount => 'Já tem uma conta?';
	@override String get foundSiblingTitle => 'Vincular uma conta existente?';
	@override String foundSiblingBody({required Object app}) => 'Encontrámos ${app} neste dispositivo. Vincule esta app à mesma conta e o seu indicativo e registos passam para cá.';
	@override String get foundPoloBody => 'Encontrámos uma versão anterior do Ham2K Portable Logger neste dispositivo. Vincule esta app à mesma conta e o seu indicativo e registos passam para cá.';
	@override String get foundSiblingsBody => 'Encontrámos outras apps Ham2K neste dispositivo. Vincule esta app a uma das suas contas e o seu indicativo e registos passam para cá.';
	@override String linkWithApp({required Object app}) => 'Vincular com ${app}';
	@override String get linkWithPolo => 'Vincular com a conta da versão anterior';
	@override String get setUpFresh => 'Configurar de raiz';
	@override String get activitiesTitle => 'Atividades Favoritas';
	@override String get activitiesBody => 'Tem interesse em algum destes programas de ativação populares?';
	@override String get activitiesFooter => '(Encontra mais opções nas Configurações)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Dados e Privacidade';
	@override String get consentUsageBody => 'Para nos ajudar a melhorar a app, gostaríamos de recolher dados de desempenho, falhas e utilização da app.';
	@override String get consentUsageLabel => 'Partilhar dados de uso da app';
	@override String get consentOperationBody => 'Algumas funcionalidades podem envolver partilhar os seus dados de operação com outros utilizadores. Pode desativar a qualquer momento.';
	@override String get consentOperationLabel => 'Partilhar Dados de Operação';
	@override String get finishingSetup => 'A concluir a configuração — a descarregar dados de referência…';
}

// Path: startScreen
class Translations$startScreen$pt extends Translations$startScreen$en {
	Translations$startScreen$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get credits => 'por KI2D e amigos';
}

// Path: testerOverlay
class Translations$testerOverlay$pt extends Translations$testerOverlay$en {
	Translations$testerOverlay$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get tape => 'CUIDADO: EM CONSTRUÇÃO';
	@override String get warningTitle => 'Esta app está em desenvolvimento';
	@override String get warningBody => 'A maioria das funcionalidades tem piso irregular e há obstáculos por todo o lado. Procure atualizações com regularidade.';
	@override String whatsNew({required Object build}) => 'Novidades na build ${build}';
	@override String get thanks => 'Obrigado por arriscar o seu registo para nos ajudar a melhorar esta app!';
}

// Path: extensionsPanel
class Translations$extensionsPanel$pt extends Translations$extensionsPanel$en {
	Translations$extensionsPanel$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Atividades';
	@override String get categoryContest => 'Concursos';
	@override String get categoryLookup => 'Pesquisas de Indicativo';
	@override String get categorySpots => 'Fontes de Spot';
	@override String get categoryDashboard => 'Painéis';
	@override String get categoryOther => 'Outras Extensões';
	@override String get searchHint => 'Procurar extensões';
	@override String get applying => 'A ativar as alterações às extensões, isto pode demorar um pouco…';
	@override String get noMatches => 'Nenhuma extensão corresponde à pesquisa';
	@override String get installFromFile => 'Instalar a partir de ficheiro…';
	@override String installVersion({required Object version}) => 'Versão ${version}';
	@override String get canReach => 'Esta extensão pode contactar';
	@override String canHoldConnection({required Object host}) => '${host}, através de uma ligação ativa';
	@override String get canHoldLocalConnection => 'Dispositivos na sua rede local, através de uma ligação ativa';
	@override String get canUseLocation => 'A sua localização';
	@override String get canReadRadio => 'O seu rádio, para ler a frequência e o modo';
	@override String get canControlRadio => 'O seu rádio, para o controlar e transmitir com ele — sintonia, potência, CW, memórias de voz e PTT';
	@override String get canSetUserAgent => 'Identificar-se perante os servidores com o seu próprio nome';
	@override String get noCapabilities => 'Não pede nada fora da app.';
	@override String get sandboxNote => 'As extensões correm isoladas: sem acesso aos seus ficheiros e sem rede além do que está aqui indicado.';
	@override String get installAction => 'Instalar';
	@override String get updateAction => 'Atualizar';
	@override String get installFailed => 'Não foi possível instalar essa extensão';
	@override String get installedBadge => 'Instalada';
	@override String get uninstallAction => 'Remover';
	@override String uninstallTitle({required Object name}) => 'Remover ${name}?';
	@override String get uninstallBody => 'Esta extensão e as suas configurações serão removidas. Os seus registos ficam intactos.';
	@override String installedMessage({required Object name}) => '${name} instalada';
	@override String get installDownloading => 'A descarregar…';
	@override String get installWaiting => 'A aguardar instalação…';
	@override String get installInstalling => 'A instalar…';
	@override String get installAwaitingApproval => 'A aguardar a sua aprovação…';
	@override String installAlreadyRunning({required Object name}) => '${name} já está a ser instalada.';
	@override String updatedTo({required Object version}) => 'Atualizada para ${version}';
	@override String installIncomplete({required Object name}) => 'A instalação de ${name} não terminou. Pode ser preciso instalá-la novamente.';
	@override String uninstallFailed({required Object name}) => 'Não foi possível remover ${name}';
	@override String installedFrom({required Object source}) => 'Descarregada de ${source}';
	@override String get dropHint => 'Largue aqui uma extensão .h2kext para a instalar';
	@override String get dropOneOnly => 'Largue uma extensão de cada vez.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} respondeu ${status} para essa extensão.';
	@override String get downloadTooLarge => 'Esse ficheiro é demasiado grande para ser uma extensão.';
	@override String get downloadNotSecure => 'Esse download foi redirecionado para um local inseguro.';
	@override String get catalogSection => 'Catálogo';
	@override String get catalogLoading => 'A carregar o catálogo…';
	@override String get catalogUnreachable => 'Catálogo inacessível';
	@override String get builtIn => 'Integrada';
	@override String get updateAvailableBadge => 'Atualização disponível';
	@override String get updatesAvailableTitle => 'Atualizações de extensões';
	@override String updateAvailableFor({required Object name}) => 'Há uma atualização disponível para ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} e mais ${count} precisam de ser atualizadas.';
	@override String updatesAvailableFor({required Object names}) => '${names} precisam de ser atualizadas.';
	@override String get pendingUpdatesSection => 'Atualizações Pendentes';
	@override String get updateAllAction => 'Atualizar todas';
	@override String get updatesUnderWay => 'Essas atualizações já estão em curso.';
	@override String get updatesNothingLeft => 'As suas extensões estão atualizadas.';
	@override String get updatesNoticeAction => 'Mais informações';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Atualizar ${count} extensão?',
		other: 'Atualizar ${count} extensões?',
	);
	@override String get upgradeDoneTitle => 'As suas extensões estão prontas';
	@override String get upgradeDoneBody => 'Passam a vir do catálogo de extensões do Ham2K, por isso podem ser atualizadas sem esperar por uma nova versão da app.';
	@override String upgradeDoneUnserved({required Object names}) => 'Não atualizadas: ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Não arrancaram: ${names}.';
	@override String get upgradeDoneRefusedHint => 'Continuam instaladas e assinaladas em Configurações › Extensões — atualizá-las aí volta a ativá-las.';
	@override String get upgradeDoneUnservedHint => 'O catálogo não tem substituto direto para estas, por isso procure lá extensões que cubram o que usava.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Eventos de Parques Estaduais';
	@override String upgradeDoneMissing({required Object count}) => '${count} das suas extensões ainda não chegaram. Serão descarregadas na próxima vez que o catálogo de extensões estiver acessível.';
	@override String get runtimeDeadBody => 'As suas extensões não arrancaram. Reiniciar a app deve trazê-las de volta.';
	@override String get refusedTitle => 'Algumas extensões não arrancaram';
	@override String get upgradeBusyTitle => 'Ainda a configurar';
	@override String get upgradeRuntimeDeadTitle => 'As suas extensões não estão a correr';
	@override String get restoreTitle => 'Faltam algumas das suas extensões';
	@override String get restoreBody => 'Estas extensões que instalou não estão neste dispositivo. Podemos descarregá-las novamente do catálogo de extensões do Ham2K:';
	@override String get restoreFromFile => 'Instaladas a partir de ficheiro. Instale-as novamente a partir dos ficheiros, ou esqueça-as:';
	@override String get restoreOtherCatalog => 'Instaladas a partir de outro catálogo de extensões, por isso não estão disponíveis aqui:';
	@override String get restoreForget => 'Esquecer';
	@override String get restoreInstall => 'Instalar';
	@override String get restoreLater => 'Mais tarde';
	@override String get restoreInstalling => 'A instalar as suas extensões…';
	@override String get restoreDoneTitle => 'As suas extensões estão de volta';
	@override String restoreDoneBody({required Object names}) => 'Reinstaladas: ${names}.';
	@override String get restorePartialTitle => 'Não foi possível instalar algumas extensões';
	@override String restoreFailed({required Object names}) => 'Não foi possível instalar: ${names}. Voltaremos a oferecê-las na próxima vez que abrir a app.';
	@override String get restoreBusyBody => 'A app ainda está a configurar as suas extensões. Voltaremos a oferecê-las na próxima vez que abrir a app.';
	@override String get restoreRuntimeDeadBody => 'Reinstalámo-las, mas as suas extensões não arrancaram. Reiniciar a app deve trazê-las de volta.';
	@override String revokedTitle({required Object name}) => '${name} foi retirada';
	@override String get revokedBody => 'O catálogo retirou esta versão, por isso foi desativada.';
	@override String get downloadHashMismatch => 'Esse download não é a extensão que o catálogo descreveu.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'O catálogo não tem a versão ${version} de ${key}.';
	@override String get catalogLinkUnknown => 'Essa ligação do catálogo não indica uma versão de extensão.';
	@override String catalogNoRelease({required Object key}) => 'O catálogo não tem nenhuma versão de ${key} nesse canal.';
	@override String get installFromLink => 'Instalar a partir de ligação';
	@override String get unstableReleaseWarning => 'Esta é uma versão instável, que o seu autor não deu como concluída. Pode comportar-se mal e continuará a receber atualizações instáveis.';
	@override String get bleedingReleaseWarning => 'Esta é uma versão de vanguarda: trabalho em curso que pode falhar ou perder as suas configurações. Continuará a receber atualizações de vanguarda.';
	@override String get channelUnstable => 'Instável';
	@override String get channelBleeding => 'Vanguarda';
	@override String get followsUnstable => 'Recebe versões instáveis e estáveis';
	@override String get followsBleeding => 'Recebe versões de vanguarda, instáveis e estáveis';
	@override String get followStableAction => 'Seguir apenas versões estáveis';
	@override String get revokedBadge => 'Revogada';
	@override String get refusedBadge => 'Não carregou';
	@override String get downloadNotHttps => 'Esse download não usa uma ligação segura.';
	@override String downloadUnreachable({required Object source}) => 'Não foi possível contactar ${source} para essa extensão.';
	@override String get detailsAction => 'Detalhes';
	@override String get installedFromFile => 'Instalada a partir de ficheiro';
	@override String get detailsWhatItDoes => 'Fornece suporte para';
	@override String get installedPreloaded => 'Pré-instalada';
	@override String get hookAccount => 'Início de sessão na conta';
	@override String get hookCallNotes => 'Notas de indicativos';
	@override String get hookDataFile => 'Dados offline';
	@override String get hookExport => 'Exportação';
	@override String get hookLookup => 'Pesquisas de indicativo';
	@override String get hookScoring => 'Pontuação';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => 'Caça de ${program}';
	@override String hookActivating({required Object program}) => 'Ativação de ${program}';
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
class Translations$home$pt extends Translations$home$en {
	Translations$home$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logger Portátil';
	@override String get newOperation => 'Nova operação';
	@override String get stationCallsign => 'Indicativo da estação';
	@override String get titleOptional => 'Título (opcional)';
	@override String get emptyList => 'Ainda não há operações. Crie uma para começar a registar.';
	@override String get quickLookup => 'Consulta Rápida';
	@override late final Translations$home$nav$pt nav = Translations$home$nav$pt.internal(_root);
	@override late final Translations$home$panels$pt panels = Translations$home$panels$pt.internal(_root);
	@override String get toggleNav => 'Mostrar ou ocultar as etiquetas de navegação';
	@override late final Translations$home$logs$pt logs = Translations$home$logs$pt.internal(_root);
}

// Path: chase
class Translations$chase$pt extends Translations$chase$en {
	Translations$chase$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'a caçar';
	@override String goalsTwo({required Object first, required Object second}) => '${first} e ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} e mais';
	@override late final Translations$chase$station$pt station = Translations$chase$station$pt.internal(_root);
	@override late final Translations$chase$periodInline$pt periodInline = Translations$chase$periodInline$pt.internal(_root);
	@override late final Translations$chase$periodStats$pt periodStats = Translations$chase$periodStats$pt.internal(_root);
	@override late final Translations$chase$period$pt period = Translations$chase$period$pt.internal(_root);
	@override late final Translations$chase$goals$pt goals = Translations$chase$goals$pt.internal(_root);
	@override late final Translations$chase$panels$pt panels = Translations$chase$panels$pt.internal(_root);
}

// Path: dialogs
class Translations$dialogs$pt extends Translations$dialogs$en {
	Translations$dialogs$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Detalhes da operação';
	@override String get activities => 'Atividades';
	@override String get stationCallsign => 'Indicativo da Estação';
	@override String get multiStationIdentifier => 'Identificador multiestação (apenas números)';
	@override String get notes => 'Notas';
	@override String get deleteOperationTitle => 'Eliminar Operação';
	@override String get purgeTestsTitle => 'Purgar Operações de Teste';
	@override String get purgeTestsBody => 'Isto elimina permanentemente estas Operações de Teste e os seus QSOs. Não pode ser desfeito.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Mais ${count} contacto de teste que não pertence a nenhuma operação.',
		other: 'Mais ${count} contactos de teste que não pertencem a nenhuma operação.',
	);
	@override String get purgeTestsAction => 'Purgar';
	@override String get syncAllTitle => 'Substituir o registo deste dispositivo?';
	@override String syncAllBody({required Object qsos}) => 'O SYNCALL faz uma cópia de segurança e apaga ${qsos} deste dispositivo, e depois descarrega novamente o registo da conta a partir do servidor. A cópia de segurança fica na base de dados deste dispositivo.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO ainda não foi sincronizado — o servidor nunca o recebeu, e NÃO voltará.',
		other: '${n} QSOs ainda não foram sincronizados — o servidor nunca os recebeu, e NÃO voltarão.',
	);
	@override String get syncAllAction => 'Apagar e Ressincronizar';
	@override String get receivedPurgesTitle => 'Operações de Teste Removidas Noutro Local';
	@override String get receivedPurgesBody => 'Estas foram eliminadas como Operações de Teste noutro dispositivo. Removê-las também aqui? Isto elimina-as permanentemente, assim como os seus QSOs, e não pode ser desfeito.';
	@override String get receivedPurgesAction => 'Remover';
	@override late final Translations$dialogs$callChange$pt callChange = Translations$dialogs$callChange$pt.internal(_root);
}

// Path: operation
class Translations$operation$pt extends Translations$operation$en {
	Translations$operation$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Esta operação está eliminada. Recupere-a para registar ou fazer alterações.';
	@override late final Translations$operation$tabs$pt tabs = Translations$operation$tabs$pt.internal(_root);
	@override late final Translations$operation$positions$pt positions = Translations$operation$positions$pt.internal(_root);
	@override String get stationCallsignNone => 'Sem indicativo da estação';
	@override String get titleNone => 'Sem título';
	@override String get deleteOperation => 'Eliminar operação';
	@override String get loggingControlsStale => 'Os campos da atividade podem estar desatualizados — reabra a operação para os atualizar';
	@override String get locationNone => 'Não definida';
	@override String get generalOperation => 'Operação Geral';
	@override String titleFor({required Object value}) => 'para ${value}';
	@override String titleAt({required Object value}) => 'em ${value}';
	@override String segmentNow({required Object description}) => 'Agora ${description}';
	@override String get testOperationSuffix => 'Teste';
	@override late final Translations$operation$menu$pt menu = Translations$operation$menu$pt.internal(_root);
	@override late final Translations$operation$layout$pt layout = Translations$operation$layout$pt.internal(_root);
	@override late final Translations$operation$export$pt export = Translations$operation$export$pt.internal(_root);
	@override late final Translations$operation$spots$pt spots = Translations$operation$spots$pt.internal(_root);
	@override late final Translations$operation$import$pt import = Translations$operation$import$pt.internal(_root);
}

// Path: map
class Translations$map$pt extends Translations$map$en {
	Translations$map$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override late final Translations$map$outlineIssue$pt outlineIssue = Translations$map$outlineIssue$pt.internal(_root);
	@override String get outlinesDisclaimer => 'Os contornos são apenas para referência. Faça a sua própria pesquisa!';
	@override String outlinesCredit({required Object sources}) => 'Contornos: ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Limites: ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Instalações: ${sources}';
	@override String get fullCredits => 'Créditos completos dos dados';
	@override String get fewerCredits => 'Menos créditos';
	@override String get emptyState => 'Ainda não há localizações de QSOs.\nOs QSOs com grid, estado ou país aparecem aqui.';
	@override String get unavailable => 'O mapa não está disponível neste momento.';
	@override String qthPopupTitle({required Object grid}) => 'QTH: ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plano';
	@override String get globe => 'Globo';
	@override String get zoomIn => 'Aproximar';
	@override String get zoomOut => 'Afastar';
	@override late final Translations$map$postcard$pt postcard = Translations$map$postcard$pt.internal(_root);
}

// Path: mapsView
class Translations$mapsView$pt extends Translations$mapsView$en {
	Translations$mapsView$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override String get searchHint => 'Procurar parques, cumes e mais';
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
class Translations$activitiesView$pt extends Translations$activitiesView$en {
	Translations$activitiesView$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Atividades';
	@override String get activitiesCountZero => 'Nenhuma Atividade Selecionada';
	@override String get activitiesCountOne => '1 Atividade';
	@override String activitiesCountOther({required Object count}) => '${count} Atividades';
	@override String get empty => 'Ainda sem atividades — use Sugestões e Pesquisa abaixo para adicionar uma';
	@override String get removeActivity => 'Remover';
	@override String openReferenceLink({required Object name}) => 'Abrir ${name}';
	@override String get editActivity => 'Editar atividade';
	@override String get manageExtensions => 'Gerir Extensões';
	@override String get manage => 'Gerir';
	@override String activitiesTitle1({required Object first}) => 'Tipos de Atividade: ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Tipos de Atividade: ${first} e ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Tipos de Atividade: ${first}, ${second} e mais ${more}';
	@override String get reference => 'Referência';
	@override String get invalidReference => 'Inválida';
	@override String get duplicateReference => 'Já adicionada';
	@override String get searchHint => 'Procurar por nome, referência ou qualquer outra coisa…';
	@override String get noSuggestions => 'Sem resultados';
	@override String get noSuggestionsHint => 'Procure acima pelo nome ou número da referência';
	@override String get noSuggestionsExample => '(por exemplo \'trilho\' ou \'4556\')';
	@override String get allOptions => 'Tipos de Atividade';
	@override String get determiningLocation => 'A determinar a localização atual…\nA aguardar o GPS para encontrar referências próximas';
	@override String get locationUnavailableTitle => 'Dados de localização indisponíveis';
	@override String get locationDeniedTitle => 'Permissão de localização negada';
	@override String get locationBlockedTitle => 'Permissão de localização bloqueada';
	@override String get noNearbyReason => 'Não é possível determinar referências próximas';
	@override String locationManualHint({required Object icon}) => 'Toque em ${icon} para introduzir a localização manualmente,\nou simplesmente procure referências pelo nome';
	@override String get locationGrantAction => 'Permitir acesso à localização';
	@override String get locationSettingsAction => 'Abrir Configurações';
	@override String get locationSettingsUnavailable => 'Permita o acesso à localização nas configurações do sistema';
	@override String get locationGrantRefused => 'Continua sem localização — o sistema voltou a recusar';
	@override String get searchUnavailableTitle => 'Pesquisa de atividades indisponível';
	@override String get searchUnavailableReason => 'Nenhuma extensão de atividade conseguiu fazer a pesquisa. Tente novamente daqui a pouco.';
	@override String get emptySheet => 'Use as sugestões e a pesquisa abaixo para adicionar uma';
	@override String get exports => 'Exportações';
	@override String get exportLogs => 'Exportar Registos';
	@override String get tools => 'Ferramentas';
	@override String get toolsTitle => 'Ferramentas da Operação';
	@override String get operationDetails => 'Detalhes da Operação';
	@override String get share => 'Partilhar';
	@override String get archive => 'Arquivar';
	@override String get deleteOperation => 'Eliminar Operação';
	@override String get undeleteOperation => 'Recuperar Operação Eliminada';
	@override String get alreadySelected => 'Já selecionada';
	@override String get selected => 'Selecionada';
	@override String pickPosition({required Object index, required Object count}) => '${index} de ${count}';
	@override String get previousPick => 'Resultado anterior';
	@override String get nextPick => 'Resultado seguinte';
	@override String get retiredReference => 'Retirada';
	@override String enableExtension({required Object name}) => 'Ativar ${name}';
	@override String get enableExtensionHint => 'Esta extensão corresponde à sua pesquisa, mas não está ativada';
	@override String get enableExtensionForRefHint => 'Esta extensão trata uma das referências desta operação, mas não está ativada';
	@override String extensionNotRunning({required Object name}) => '${name} não está a correr';
	@override String get extensionNotRunningHint => 'Esta extensão foi desativada; abra as Configurações de Extensões para mais informações';
	@override String installExtension({required Object name}) => 'Instalar ${name}';
	@override String get installExtensionHint => 'Esta extensão corresponde à sua pesquisa, mas não está instalada';
	@override String get onlyCatalogMatches => 'Sem resultados\nAlgumas extensões do catálogo podem ter resultados.\nInstale-as em Tipos de Atividade abaixo.';
	@override String get setupUnavailable => 'Não foi possível carregar a configuração desta atividade — tente novamente a partir de Gerir';
	@override String get controlsUnavailableTitle => 'Controlos da atividade indisponíveis';
	@override String get controlsUnavailableReason => 'As suas referências estão seguras, mas não é possível editá-las neste momento.';
	@override String get controlsUnavailableRetry => 'Tentar novamente';
	@override String get onlyDisabledMatches => 'Sem resultados\nAlgumas extensões disponíveis podem ter resultados.\nAtive-as em Tipos de Atividade abaixo.';
	@override String get onlyNotRunningMatches => 'Sem resultados\nAlgumas extensões que podem ter resultados não estão a correr.\nVeja Tipos de Atividade abaixo.';
	@override String get mapToggle => 'Mapa';
	@override String get searchToggle => 'Pesquisa';
	@override String get addToOperation => 'Adicionar à Operação';
	@override String get addToOperationShort => 'Adicionar à Op.';
	@override String get mapEmptyState => 'Sem resultados para mostrar no mapa';
	@override String get mapEmptyStateHint => 'Volte à lista, ou procure outra coisa';
	@override String get imports => 'Importações';
}

// Path: loggingControls
class Translations$loggingControls$pt extends Translations$loggingControls$en {
	Translations$loggingControls$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Hora (UTC)';
	@override String get date => 'Data';
	@override String get now => 'Agora';
	@override String get frequency => 'Frequência';
	@override String get mode => 'Modo';
	@override String get theirCall => 'Indicativo';
	@override String get noteField => 'Nota';
	@override String get todoField => 'Tarefa';
	@override String get sent => 'Enviado';
	@override String get rcvd => 'Recebido';
	@override String get more => 'Mais';
	@override String get revert => 'Reverter';
	@override String get undoDelete => 'Anular eliminação';
	@override String get restore => 'Repor';
	@override String get wipe => 'Apagar';
	@override String get undo => 'Desfazer';
	@override String get pendingDeleteTapWarning => 'Toque no caixote do lixo mais uma vez para eliminar este QSO';
	@override String get pendingDeleteClickWarning => 'Clique no caixote do lixo mais uma vez para eliminar este QSO';
	@override String get deletedQsoWarning => 'QSO Eliminado';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Toque no caixote do lixo mais uma vez para eliminar este ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Clique no caixote do lixo mais uma vez para eliminar este ${kind}';
	@override String deletedEventWarning({required Object kind}) => '${kind} eliminado';
	@override String get timeControl => 'Hora';
	@override String get radioControl => 'Rádio';
	@override String get powerControl => 'Potência';
	@override String get notesControl => 'Notas';
	@override String get power => 'Potência';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Controlos de Registo';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Self-spotting';
	@override String spotSelfAt({required Object freq}) => 'Self-spot em ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spot de ${call} em ${freq}';
	@override String spotTooLate({required Object call}) => 'Tarde demais para fazer spot de ${call}';
	@override String get spotNoFreq => 'Defina primeiro uma frequência para o spot';
	@override String get spotComment => 'Comentário';
	@override String get bandOrFreqRequired => 'Defina uma frequência ou banda antes de registar';
	@override String get missingBand => 'Sem Banda';
	@override String get missingMode => 'Sem Modo';
	@override String saveFailed({required Object error}) => 'Não foi possível guardar: ${error}';
	@override String deleteFailed({required Object error}) => 'Não foi possível eliminar: ${error}';
	@override late final Translations$loggingControls$info$pt info = Translations$loggingControls$info$pt.internal(_root);
}

// Path: formChrome
class Translations$formChrome$pt extends Translations$formChrome$en {
	Translations$formChrome$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(sem título)';
	@override String get showMore => 'Mostrar mais';
	@override String get showAll => 'Mostrar tudo';
	@override String get showFewer => 'Mostrar menos';
	@override String get defaults => 'Predefinições';
	@override String get search => 'Procurar';
	@override String get clear => 'Limpar';
	@override String get openPage => 'Abrir página';
	@override String get connected => 'Ligado';
	@override String get notConnected => 'Não Ligado';
	@override String get manage => 'Gerir';
	@override String get connect => 'Ligar';
	@override String get formTitle => 'Formulário';
	@override String addItem({required Object label}) => 'Adicionar ${label}';
	@override String editItem({required Object label}) => 'Editar ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'A mostrar ${shown} de ${total} (${selected} selecionados)';
	@override String validationError({required Object error}) => 'Erro de validação: ${error}';
	@override String transformationError({required Object error}) => 'Erro de transformação: ${error}';
	@override String actionError({required Object error}) => 'Erro: ${error}';
	@override String get removeItem => 'Remover';
	@override String get storageUnavailable => 'Credenciais indisponíveis';
}

// Path: qsoEditForm
class Translations$qsoEditForm$pt extends Translations$qsoEditForm$en {
	Translations$qsoEditForm$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

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
	@override String get sectionTheir => 'Informações Deles';
	@override String get sectionOur => 'As Nossas Informações';
	@override String get sectionNotes => 'Notas';
	@override String get theirCity => 'Cidade';
	@override String get theirCounty => 'Município';
	@override String get theirEntity => 'Entidade';
	@override String get theirCqZone => 'Zona CQ';
	@override String get theirItuZone => 'Zona ITU';
	@override String get theirArrlSection => 'Secção ARRL';
	@override String get theirLat => 'Latitude';
	@override String get theirLon => 'Longitude';
	@override String get theirPower => 'Potência deles';
}

// Path: qsoList
class Translations$qsoList$pt extends Translations$qsoList$en {
	Translations$qsoList$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Ainda nenhum QSO — contacte alguém!';
	@override String get bandOrModeWarning => 'Confirme que a banda e o modo estão corretos';
	@override String get today => 'Hoje';
	@override String get yesterday => 'Ontem';
	@override String get tomorrow => 'Amanhã';
}

// Path: loggingPanel
class Translations$loggingPanel$pt extends Translations$loggingPanel$en {
	Translations$loggingPanel$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Estatísticas da Operação';
	@override String get scoring => 'Pontuação';
	@override String get dxccEntities => 'Entidades DXCC';
	@override String get statesWorked => 'Estados';
	@override String get provincesWorked => 'Províncias';
	@override String get duplicates => 'Duplicados';
}

// Path: callInfo
class Translations$callInfo$pt extends Translations$callInfo$en {
	Translations$callInfo$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Mostrar Imagem';
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
	@override String get otherOpsCountOne => '1 QSO noutras operações';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs noutras operações';
	@override String andMore({required Object count}) => '… e mais ${count}';
	@override String withCall({required Object call}) => 'com ${call}';
	@override String fromOperation({required Object where}) => 'de ${where}';
	@override late final Translations$callInfo$history$pt history = Translations$callInfo$history$pt.internal(_root);
}

// Path: settings
class Translations$settings$pt extends Translations$settings$en {
	Translations$settings$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configurações';
	@override String get language => 'Idioma';
	@override String languageSystem({required Object language}) => 'Seguir as configurações do sistema (${language})';
	@override late final Translations$settings$theme$pt theme = Translations$settings$theme$pt.internal(_root);
	@override late final Translations$settings$themeDescription$pt themeDescription = Translations$settings$themeDescription$pt.internal(_root);
	@override String get fontScale => 'Escala da Fonte';
	@override late final Translations$settings$fontScaleOpts$pt fontScaleOpts = Translations$settings$fontScaleOpts$pt.internal(_root);
	@override late final Translations$settings$keepDeviceAwake$pt keepDeviceAwake = Translations$settings$keepDeviceAwake$pt.internal(_root);
	@override String get layoutDensity => 'Densidade da Disposição';
	@override late final Translations$settings$layoutDensityOpts$pt layoutDensityOpts = Translations$settings$layoutDensityOpts$pt.internal(_root);
	@override String layoutDensityClamped({required Object effective}) => 'a janela é demasiado baixa, a usar ${effective}';
	@override String get layoutDensityAtLimit => 'no limite';
	@override String get distanceUnits => 'Unidades de Distância';
	@override late final Translations$settings$distanceUnitsOpts$pt distanceUnitsOpts = Translations$settings$distanceUnitsOpts$pt.internal(_root);
	@override String get userInterface => 'Interface';
	@override late final Translations$settings$logging$pt logging = Translations$settings$logging$pt.internal(_root);
	@override late final Translations$settings$catServer$pt catServer = Translations$settings$catServer$pt.internal(_root);
	@override late final Translations$settings$radio$pt radio = Translations$settings$radio$pt.internal(_root);
	@override late final Translations$settings$help$pt help = Translations$settings$help$pt.internal(_root);
	@override late final Translations$settings$exports$pt exports = Translations$settings$exports$pt.internal(_root);
	@override late final Translations$settings$map$pt map = Translations$settings$map$pt.internal(_root);
	@override late final Translations$settings$privacy$pt privacy = Translations$settings$privacy$pt.internal(_root);
	@override String get operatorCall => 'Indicativo do Operador';
	@override late final Translations$settings$sync$pt sync = Translations$settings$sync$pt.internal(_root);
	@override late final Translations$settings$peers$pt peers = Translations$settings$peers$pt.internal(_root);
	@override String get developerMode => 'Modo de Desenvolvedor';
	@override late final Translations$settings$syncPanel$pt syncPanel = Translations$settings$syncPanel$pt.internal(_root);
	@override late final Translations$settings$accounts$pt accounts = Translations$settings$accounts$pt.internal(_root);
	@override late final Translations$settings$station$pt station = Translations$settings$station$pt.internal(_root);
	@override late final Translations$settings$offlineData$pt offlineData = Translations$settings$offlineData$pt.internal(_root);
	@override late final Translations$settings$profiles$pt profiles = Translations$settings$profiles$pt.internal(_root);
	@override late final Translations$settings$search$pt search = Translations$settings$search$pt.internal(_root);
	@override late final Translations$settings$developer$pt developer = Translations$settings$developer$pt.internal(_root);
	@override late final Translations$settings$about$pt about = Translations$settings$about$pt.internal(_root);
	@override late final Translations$settings$panels$pt panels = Translations$settings$panels$pt.internal(_root);
	@override String get showMoreSettings => 'Mostrar mais configurações';
	@override String get gridPrecision => 'Precisão do Grid';
	@override late final Translations$settings$gridPrecisionOpts$pt gridPrecisionOpts = Translations$settings$gridPrecisionOpts$pt.internal(_root);
	@override late final Translations$settings$gridPrecisionDescription$pt gridPrecisionDescription = Translations$settings$gridPrecisionDescription$pt.internal(_root);
}

// Path: commands
class Translations$commands$pt extends Translations$commands$en {
	Translations$commands$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Ative primeiro a sincronização nas Configurações.';
	@override String get fullResyncStarted => 'Ressincronização completa iniciada — os dados locais foram primeiro salvaguardados.';
	@override String noDataFilesMatched({required Object target}) => 'Nenhum ficheiro de dados corresponde a "${target}".';
	@override String reloadFailed({required Object error}) => 'O recarregamento falhou: ${error}';
	@override String get reloadingAll => 'A recarregar todos os ficheiros de dados…';
	@override String reloadingTarget({required Object target}) => 'A recarregar os ficheiros de dados de ${target}…';
	@override String unknownExperiment({required Object token}) => 'Experiência desconhecida "${token}"';
	@override String experimentEnabled({required Object name}) => '${name} ativada';
	@override String experimentDisabled({required Object name}) => '${name} desativada';
	@override String get sentryTestSent => 'Relatório de erro de teste enviado para o Sentry';
	@override String get sentryTestLocalOnly => 'O Sentry está desativado nesta build — erro de teste registado apenas localmente';
	@override String get noOperationOpen => 'Esse comando precisa de uma operação aberta';
	@override String unknownSegmentKind({required Object kind}) => 'Não é possível marcar um \'${kind}\'';
	@override String get operationAlreadyStarted => 'Esta operação já tem um marcador de início';
	@override String get couldNotOpenLocation => 'A pausa foi adicionada, mas não foi possível abrir o ecrã de localização';
	@override String get noTestOperations => 'Nenhuma Operação de Teste para purgar';
	@override String get purgeTestsUnavailable => 'O PURGETESTS precisa de mostrar um diálogo de confirmação, que não está disponível aqui';
	@override String get syncAllUnavailable => 'O SYNCALL precisa de mostrar um diálogo de confirmação, que não está disponível aqui';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} Operação de Teste purgada',
		other: '${count} Operações de Teste purgadas',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '${purged} de ${total} Operações de Teste purgadas — as restantes falharam; tente PURGETESTS novamente';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contacto de teste sem operação purgado',
		other: '${count} contactos de teste sem operação purgados',
	);
	@override String get purgeTestsContactsFailed => 'As Operações de Teste foram purgadas, mas os contactos de teste sem operação falharam; tente PURGETESTS novamente';
	@override String get purgeTestsNothingToDo => 'Nada foi purgado';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '${removed} de ${total} Operações de Teste removidas — as restantes falharam; tente Rever novamente';
	@override String get receivedPurgesFailed => 'Não foi possível remover essas Operações de Teste — tente Rever novamente';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} Operação de Teste foi removida noutro dispositivo',
		other: '${count} Operações de Teste foram removidas noutro dispositivo',
	);
	@override String get receivedPurgesReview => 'Rever';
	@override String get settingOn => 'Ligado';
	@override String get settingOff => 'Desligado';
	@override String get settingEmpty => '(vazio)';
	@override String get settingSecretSet => '(definido)';
	@override String get settingSecretUnset => '(não definido)';
	@override String settingSelectedCount({required Object count}) => '${count} selecionados';
	@override String get settingExpectsOnOff => 'ligado ou desligado';
	@override String settingExpectsOneOf({required Object choices}) => 'um de: ${choices}';
	@override String get settingExpectsNumber => 'um número';
	@override String settingVanished({required Object label}) => '“${label}” já não está disponível';
	@override String get noCwKeyer => 'Nenhum rádio ligado consegue manipular CW';
	@override String get noKeyer => 'Nenhum rádio ligado consegue manipular CW nem reproduzir memórias de voz';
	@override String get keyerNeedsOperation => 'Abra uma operação para usar o manipulador CW';
	@override String get keyerExperimentOff => 'A manipulação CW está desligada — ligue-a com EXP KEYER';
	@override String get esmExperimentOff => 'Enter Envia Mensagens está desligado — ligue-o com EXP ESM';
	@override String cwSending({required Object text}) => 'A enviar CW: ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Mensagem CW F${n}: ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'A mensagem CW F${n} não foi enviada: as extensões não estão prontas';
	@override String settingNotStored({required Object label}) => '“${label}” não aceitou esse valor';
}

// Path: commandDialog
class Translations$commandDialog$pt extends Translations$commandDialog$en {
	Translations$commandDialog$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Procure indicativos ou escreva um comando';
	@override String noResults({required Object text}) => 'Nada corresponde a “${text}”';
	@override String get sectionCommands => 'Comandos';
	@override String get sectionGoTo => 'Ir para';
	@override String get sectionOperations => 'Operações';
	@override String get goHome => 'Início';
	@override String get goSettings => 'Configurações';
	@override String get goNewOperation => 'Nova operação';
	@override String runTyped({required Object text}) => 'Executar “${text}”';
	@override String get sectionSuggestions => 'Experimente';
	@override String get lookingUp => 'A pesquisar indicativo…';
	@override String get blockedByPane => 'Não é possível usar comandos com um painel ou diálogo aberto';
}

// Path: expiredBuild
class Translations$expiredBuild$pt extends Translations$expiredBuild$en {
	Translations$expiredBuild$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Esta build expirou';
	@override String get body => 'Visite ham2k.com e obtenha uma versão mais recente.';
	@override String get visit => 'Visitar ham2k.com';
	@override String get dismiss => 'Continuar mesmo assim';
}

// Path: staleness
class Translations$staleness$pt extends Translations$staleness$en {
	Translations$staleness$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Uma atualização importante está à espera';
	@override String get codePushFloorBody => 'Esta versão tem uma correção que ainda não tem.';
	@override String get restartToApply => 'Reinicie a app para a aplicar.';
	@override String get quitAndReopen => 'Saia da app e abra-a novamente para a aplicar.';
	@override String get reopenToApply => 'Feche a app e abra-a novamente para a aplicar.';
	@override String get ignoreForNow => 'Ignorar por agora';
}

// Path: spotting
class Translations$spotting$pt extends Translations$spotting$en {
	Translations$spotting$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Ainda não há QSO registado para fazer spot.';
	@override String get setFrequencyFirst => 'Defina primeiro uma frequência.';
	@override String get nothingToSpot => 'Nada para fazer spot — nenhuma extensão oferece spotting aqui.';
	@override String spotFailed({required Object source, required Object message}) => '${source} falhou: ${message}';
	@override String get unknownError => 'erro desconhecido';
	@override String get notSent => 'Spot não enviado.';
	@override String get notRefreshedOffline => 'Sem ligação — os spots não foram atualizados';
}

// Path: dataFiles
class Translations$dataFiles$pt extends Translations$dataFiles$en {
	Translations$dataFiles$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'A descarregar…';
	@override String downloadFailedTitle({required Object name}) => 'Não foi possível descarregar ${name}';
	@override String get downloadFailedWebHint => 'Pode ser um problema de rede, ou o servidor desta ligação pode não permitir downloads diretos a partir de um navegador. Experimente a app de computador ou móvel, ou outro local de alojamento.';
	@override String get downloadTimedOut => 'O servidor demorou demasiado a responder. Tente novamente mais tarde.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} respondeu com um erro (HTTP ${status}). Tente novamente mais tarde.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} não conseguiu fornecer este ficheiro (HTTP ${status}). Verifique se o endereço ainda está certo.';
	@override String processingFailedTitle({required Object name}) => 'Não foi possível processar ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'O download tinha apenas ${imported} dos ${existing} registos deste dispositivo, por isso os que ficaram de fora foram mantidos. Atualizá-lo em Configurações › Dados Offline aceita-o mesmo assim.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} registo importado para ${label}.',
		other: '${count} registos importados para ${label}.',
	);
	@override String importedData({required Object label}) => 'Dados importados para ${label}.';
	@override String get cleanedUpTitle => 'Dados de extensões limpos';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Removidos os dados de ${count} ficheiro de dados de extensões desativadas.',
		other: 'Removidos os dados de ${count} ficheiros de dados de extensões desativadas.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} registos';
	@override String get definitionUnavailable => 'A origem do ficheiro não forneceu uma definição — a extensão pode estar a reiniciar ou mal configurada. Tente novamente daqui a pouco.';
}

// Path: updates
class Translations$updates$pt extends Translations$updates$en {
	Translations$updates$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Atualização disponível';
	@override String newVersionAvailable({required Object version}) => 'Está disponível uma nova versão (${version}).';
	@override String get getIt => 'Obter';
	@override String get ok => 'OK';
	@override String get updateReady => 'Atualização pronta';
	@override String get restartToApply => 'Foi descarregada uma atualização. Reinicie para a aplicar.';
	@override String get appliesNextLaunch => 'Foi descarregada uma atualização. Será aplicada da próxima vez que abrir a app.';
	@override String get restartNow => 'Reiniciar agora';
	@override String get reloadToUpdate => 'Está disponível uma versão mais recente desta página. Recarregue para a obter.';
	@override String get reloadNow => 'Recarregar agora';
	@override String get checkForUpdates => 'Procurar Atualizações';
	@override String get checkingForUpdates => 'A verificar atualizações…';
	@override String get upToDate => 'Atualizado';
	@override String get automaticChecks => 'Verificar automaticamente';
	@override String get automaticChecksDescription => 'Procurar novas versões em segundo plano, a partir da próxima vez que iniciar a app';
}

// Path: extensionService
class Translations$extensionService$pt extends Translations$extensionService$en {
	Translations$extensionService$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'As extensões ainda não estão prontas.';
	@override String testFailed({required Object error}) => 'O teste falhou: ${error}';
	@override String connectedAs({required Object identity}) => 'Ligado como ${identity}';
	@override String get invalidFieldConfiguration => 'Configuração de campo inválida';
	@override String get invalidValue => 'Valor inválido';
	@override String validationError({required Object error}) => 'Erro de validação: ${error}';
	@override String actionFailed({required Object error}) => 'A ação falhou: ${error}';
	@override String get commandFailed => 'Não foi possível executar o comando';
	@override String get reportUnavailable => 'Não é possível enviar relatórios neste momento';
	@override String get stashUnavailable => 'O Arquivo de Ficheiros do Ham2K está inacessível neste momento';
	@override String timersSuspendedBudget({required Object name}) => '${name} gastou demasiado tempo nos seus temporizadores. Ficam parados até as extensões reiniciarem.';
	@override String timersSuspendedFailures({required Object name}) => 'Os temporizadores de ${name} continuaram a falhar. Ficam parados até as extensões reiniciarem.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} ficou bloqueado num temporizador. Os seus temporizadores ficam parados até as extensões reiniciarem.';
}

// Path: operationLocationScreen
class Translations$operationLocationScreen$pt extends Translations$operationLocationScreen$en {
	Translations$operationLocationScreen$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Localização da Operação';
	@override String get selectedLocation => 'Localização Selecionada';
	@override String get gridSquare => 'Localizador Maidenhead (Grid)';
	@override String get gridInvalid => 'Precisa de 4, 6, 8 ou 10 caracteres, como FN31pr';
	@override String get suggestedLocations => 'Localizações Sugeridas';
	@override String get deviceGps => 'GPS do Dispositivo';
	@override String peerGps({required Object device}) => 'GPS de ${device}';
	@override String get locating => 'A localizar…';
	@override String get gpsUnavailable => 'Localização indisponível';
	@override String get permissionDenied => 'Permissão de localização negada';
	@override String get permissionBlocked => 'Permissão de localização bloqueada';
	@override String get moreDetails => 'Mais Detalhes';
	@override String get stateOrProvince => 'Estado ou Província (opcional)';
	@override String get controlsUnavailableTitle => 'Controlos da atividade indisponíveis';
	@override String get controlsUnavailableReason => 'Estas referências continuam utilizáveis; só não foi possível contactar as suas atividades.';
	@override String get controlsUnavailableRetry => 'Tentar novamente';
	@override String get county => 'Município (opcional)';
}

// Path: versionLabel
class Translations$versionLabel$pt extends Translations$versionLabel$en {
	Translations$versionLabel$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Versão ${version}';
	@override String patch({required Object patch}) => 'Patch ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class Translations$notices$pt extends Translations$notices$en {
	Translations$notices$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Ainda sem avisos';
	@override String get webStorageInMemory => 'Este navegador não conseguiu fornecer armazenamento persistente — o registo fica apenas em memória e será PERDIDO quando este separador for fechado. Use uma versão atual do Chrome, Firefox, Safari ou Edge.';
	@override String get webStorageUnreliable => 'Este navegador está a usar um armazenamento alternativo que não é seguro com vários separadores — mantenha apenas um separador aberto, e mantenha a sincronização ligada.';
	@override String get logFromNewerBuildTitle => 'Este registo precisa de uma versão mais recente';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'O seu registo foi escrito por uma versão mais recente do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), por isso não pode ser aberto, e os novos contactos não serão guardados. Instale novamente a versão mais recente — ou, se pretendia correr esta build, aponte-a para outra pasta de dados. O registo está em ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'O seu registo foi escrito por uma versão mais recente do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), por isso não pode ser aberto, e os novos contactos não serão guardados. Abra antes este registo com essa versão mais recente.';
	@override String get preferencesRestoredTitle => 'Configurações repostas a partir de uma cópia de segurança';
	@override String get preferencesRestored => 'Não foi possível ler o ficheiro de configurações, por isso o HaLo repôs a última cópia válida. O que alterou na sessão anterior pode ter de ser definido novamente. O ficheiro ilegível fica guardado ao lado, com o nome shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Configurações repostas';
	@override String get preferencesReset => 'Não foi possível ler o ficheiro de configurações e não havia cópia de segurança a que recorrer, por isso o HaLo arrancou com as predefinições. O ficheiro ilegível fica guardado na pasta de dados da app, com o nome shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} não foi ligado automaticamente';
	@override String autoConnectHeld({required Object name}) => 'O HaLo deixou de responder da última vez que começou a ligar-se a ${name}, por isso desta vez não lhe tocou, para não arriscar que voltasse a acontecer. Verifique se o rádio está ligado e o cabo está ligado, e depois prima Ligar nesse rádio nas Configurações.';
}

// Path: syncAccount
class Translations$syncAccount$pt extends Translations$syncAccount$en {
	Translations$syncAccount$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Conta Anónima (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (confirmação pendente)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (confirmação pendente - #${id})';
}

// Path: deepLink
class Translations$deepLink$pt extends Translations$deepLink$en {
	Translations$deepLink$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Inicie primeiro uma operação, e depois envie esse contacto novamente';
	@override String get waitingInOperation => 'Esse contacto está à espera na operação por trás deste ecrã';
	@override String unknownActivities({required Object refs}) => 'Este dispositivo não tem nenhuma atividade para ${refs}, por isso essas referências ficaram de fora';
	@override String activitiesUnavailable({required Object refs}) => 'Não foi possível contactar as suas atividades, por isso ${refs} ficou de fora — tente essa ligação novamente';
}

// Path: confirmDevice
class Translations$confirmDevice$pt extends Translations$confirmDevice$en {
	Translations$confirmDevice$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirmar um Dispositivo';
	@override String get codePrompt => 'Introduza o código mostrado no dispositivo que se quer juntar a esta conta.';
	@override String get code => 'Código';
	@override String get lookUp => 'Procurar';
	@override String get codeNotFound => 'Nenhum pedido corresponde a esse código. Os códigos expiram ao fim de 10 minutos — peça um novo ao outro dispositivo.';
	@override String get linkExpired => 'Essa ligação expirou. Peça ao outro dispositivo que mostre um novo código QR.';
	@override String areYouSure({required Object device}) => 'Vincular ${device} a esta conta?';
	@override String get unnamedDevice => 'um dispositivo sem nome';
	@override String get grantWarning => 'Poderá ler e alterar todas as operações e QSOs desta conta.';
	@override String get needsSyncTitle => 'Este dispositivo ainda não sincroniza';
	@override String get needsSyncText => 'Ative a sincronização Ham2K Log Filer e vincule este dispositivo a uma conta antes de poder admitir outro.';
	@override String get malformedRequest => 'O servidor de sincronização enviou um pedido que esta app não conseguiu ler. Peça ao outro dispositivo que tente novamente.';
	@override String get linkIt => 'Vincular Dispositivo';
}

// Path: switchAccounts
class Translations$switchAccounts$pt extends Translations$switchAccounts$en {
	Translations$switchAccounts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Ainda sem detalhes da conta';
	@override String get currentAccount => 'Conta atual';
	@override String get otherAccounts => 'Outras contas';
	@override String get linkToAnother => 'Vincular a outra conta';
	@override String get linkWithSibling => 'Vincular com outra App Ham2K';
	@override String get linkWithPolo => 'Vincular com a conta da versão anterior';
	@override String get linkWithSiblingDescription => 'Tem outra app Ham2K instalada. Vincule com a conta usada nela.';
	@override String siblingPrompt({required Object app}) => 'Aprove o pedido em ${app}, e depois volte aqui.';
	@override String openSiblingAgain({required Object app}) => 'Abrir ${app} novamente';
	@override String get siblingNoGrant => 'Não funcionou? Abra-a novamente, ou volte atrás e vincule de outra forma.';
	@override String siblingOpenFailed({required Object app}) => 'Não foi possível abrir ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'A ligação expirou e está pronta uma nova — abra ${app} novamente.';
	@override String get tryAgain => 'Tentar novamente';
	@override String get linkWithQr => 'Vincular com um código QR';
	@override String get linkWithQrDescription => 'Leia-o a partir de um dispositivo que já usa a conta';
	@override String get linkWithEmail => 'Vincular com um endereço de e-mail';
	@override String get linkWithEmailDescription => 'Confirme com um código ou uma ligação por e-mail';
	@override String get enterEmailPrompt => 'Introduza o endereço de e-mail da conta que quer que este dispositivo use.';
	@override String get emailAddress => 'Endereço de e-mail';
	@override String get linkAccount => 'Vincular conta';
	@override String get copiedCode => 'Código copiado para a área de transferência';
	@override String get copyCode => 'Copiar código';
	@override String codePrompt({required Object email}) => 'Abra a app Ham2K num dispositivo já vinculado a ${email} e introduza este código para aprovar o pedido:';
	@override String get waitingForConfirmation => 'A aguardar confirmação…';
	@override String get sendEmailInstead => 'Enviar antes um e-mail de confirmação';
	@override String emailSent({required Object email}) => 'Foi enviado um e-mail para ${email}. Abra-o e confirme o pedido para vincular este dispositivo.';
	@override String get resendEmail => 'Reenviar e-mail';
	@override String get qrPrompt => 'Leia este código QR a partir de um dispositivo já vinculado à conta que quer — por exemplo com o Ham2K Portable Logger no seu telemóvel.';
	@override String get serverUnreachable => 'Não foi possível contactar o servidor de sincronização. Tente novamente mais tarde.';
	@override String get emailRequired => 'Introduza um endereço de e-mail para vincular.';
	@override String noAccountForEmail({required Object email}) => 'Nenhuma conta encontrada para ${email}.';
	@override String serverRejected({required Object error}) => 'O servidor de sincronização rejeitou o pedido: ${error}';
	@override String get noLinkCode => 'O servidor de sincronização não devolveu um código de ligação. Tente novamente mais tarde.';
	@override String get noConfirmationCode => 'O servidor de sincronização não enviou um código de confirmação. Tente novamente mais tarde.';
	@override String get switchNotAccepted => 'Essa conta não aceitou a mudança. Tente antes vinculá-la com um endereço de e-mail.';
	@override String get requestFailed => 'Algo correu mal na comunicação com o servidor de sincronização. Tente novamente mais tarde.';
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
class Translations$adifImport$pt extends Translations$adifImport$en {
	Translations$adifImport$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar QSOs de ADIF';
	@override String reading({required Object filename}) => 'A ler ${filename}…';
	@override String get dropHint => 'Largue um ficheiro ADIF para importar';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} QSO neste ficheiro',
		other: '${formatted} QSOs neste ficheiro',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} já no seu registo',
		other: '${formatted} já no seu registo',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} será importado',
		other: '${formatted} serão importados',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contacto novo',
		other: '${formatted} contactos novos',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} será intercalado com um contacto existente',
		other: '${formatted} serão intercalados com contactos existentes',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} não pode ser importado (sem indicativo)',
		other: '${formatted} não podem ser importados (sem indicativo)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} precisa de uma análise mais atenta',
		other: '${formatted} precisam de uma análise mais atenta',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Não foi possível recuperar as referências de ${count} contacto',
		other: 'Não foi possível recuperar as referências de ${formatted} contactos',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'As referências ${programs} podem estar incompletas em ${count} contacto',
		other: 'As referências ${programs} podem estar incompletas em ${formatted} contactos',
	);
	@override String get stackingTypesUnknown => 'Os contactos combinados podem perder uma referência — as atividades não conseguiram indicar que tipos se acumulam. Cancele e tente novamente para evitar isto.';
	@override String get nothingToImport => 'Nada neste ficheiro pode ser importado';
	@override String get confirm => 'Importar';
	@override String importing({required Object filename}) => 'A importar ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} contacto importado de ${filename}',
		other: '${formatted} contactos importados de ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Não foi possível importar ${filename}: ${error}';
	@override String notAdif({required Object filename}) => '${filename} não parece ser um ficheiro ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Aviso: este ADIF tem QSOs de ${calls}, mas serão importados como ${station} se continuar.';
	@override String get stationCallJoin => ' e ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} não tem data e não pode ser importado',
		other: '${formatted} não têm data e não podem ser importados',
	);
	@override String activationFound({required Object refs}) => 'Este ficheiro regista uma ativação de ${refs}.';
	@override String get addActivation => 'Adicioná-la a esta operação';
	@override String shortfall({required Object written, required Object planned}) => 'Só foi possível aplicar ${written} de ${planned} — o registo mudou enquanto decidia.';
	@override String get busy => 'Já está a decorrer uma importação. Aguarde que termine antes de iniciar outra.';
	@override String get oneFileOnly => 'Largue um ficheiro ADIF de cada vez — a ordem em que os ficheiros são importados decide que dados prevalecem.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} tem mais de ${limit} QSOs, o máximo que uma operação pode importar de uma vez.';
}

// Path: offline
class Translations$offline$pt extends Translations$offline$en {
	Translations$offline$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet: OFFLINE';
	@override String get statusOnline => 'Internet: ligada';
	@override String get noRoute => 'Sem qualquer ligação de rede.';
	@override String get unreachable => 'A rede está ativa, mas nenhum servidor responde — muitas vezes sinal de uma página de início de sessão à espera num navegador.';
	@override String get reachable => 'Todos os serviços estão a responder como esperado.';
	@override String get whatStops => 'As pesquisas, os spots e os ficheiros de dados estão em pausa. O registo e a sincronização próxima não.';
	@override String get servicesTitle => 'Serviços';
	@override String get noServices => 'Nenhum serviço reportou ainda.';
	@override String lastSuccess({required Object when}) => 'Respondeu pela última vez há ${when}';
	@override String get neverSucceeded => 'Ainda não respondeu';
	@override String nextAttempt({required Object when}) => 'Próxima tentativa daqui a ${when}';
	@override String get nextAttemptNow => 'Próxima tentativa agora';
	@override String get retry => 'Tentar agora';
	@override String get retrying => 'A tentar…';
	@override String get retryReached => 'Novamente online.';
	@override String get retryUnreachable => 'Continua sem resposta.';
	@override String get retryNotAttempted => 'Nada para enviar neste momento.';
	@override String get retryThrottled => 'Acabou de tentar — aguarde um momento.';
	@override String get retryDisabled => 'A sincronização está desligada, por isso não há nada com que testar.';
	@override String get syncService => 'Sincronização Ham2K LoFi';
	@override String get retryInFlight => 'Já está a tentar — aguarde.';
}

// Path: exportSettings
class Translations$exportSettings$pt extends Translations$exportSettings$en {
	Translations$exportSettings$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Configurações base para todas as exportações, com modelos de nome de ficheiro e de título separados para atividades de referência e outras atividades. Cada tipo de exportação pode ter as suas próprias predefinições ou configurações personalizadas.';
	@override String get referenceActivities => 'Atividades de Referência';
	@override String get otherActivities => 'Outras Atividades';
	@override String get adifFields => 'Campos ADIF';
	@override String get loadFailed => 'Não foi possível carregar as configurações de exportação.';
	@override String get retry => 'Tentar novamente';
	@override String get compactFileNamesDescriptionOn => 'Nomes de ficheiro compactos, como N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Nomes de ficheiro descritivos, como 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'A incluir nomes, moradas, e-mails, notas e localizações precisas nos ficheiros ADIF.';
	@override String get includePrivateDataDescriptionOff => 'A omitir nomes, moradas, e-mails e notas; a limitar as localizações a grids de seis caracteres.';
	@override String get includeLookupDataDescriptionOn => 'A incluir informação de serviços de pesquisa de indicativos.';
	@override String get includeLookupDataDescriptionOff => 'A omitir informação de serviços de pesquisa de indicativos; a manter os valores introduzidos manualmente.';
	@override String get customTemplatesDescriptionOn => 'Os seus modelos personalizados estão ativos e podem ser editados abaixo.';
	@override String get customTemplatesDescriptionOff => 'Os modelos predefinidos estão ativos. Os seus modelos personalizados ficam guardados para mais tarde.';
	@override String get type => 'Tipo de exportação';
	@override String get defaults => 'Predefinições';
	@override String get includeLookupData => 'Incluir dados de pesquisa';
	@override String get customTemplates => 'Modelos personalizados';
	@override String get filenameTemplate => 'Modelo de nome de ficheiro';
	@override String get compactFilenameTemplate => 'Modelo de nome de ficheiro compacto';
	@override String get titleTemplate => 'Modelo de título';
	@override String get adifNotesTemplate => 'Notas de QSO ADIF';
	@override String get adifCommentTemplate => 'Comentários de QSO ADIF';
	@override String get adifQslMessageTemplate => 'Mensagem de QSL ADIF';
	@override String get shared => 'As configurações aplicam-se a todas as extensões que usam este tipo de exportação.';
	@override String get defaultTemplates => 'Ative Modelos personalizados para editar os modelos deste tipo.';
}

// Path: templateEditor
class Translations$templateEditor$pt extends Translations$templateEditor$en {
	Translations$templateEditor$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Pré-visualização:';
	@override String get reset => 'Repor';
	@override String get docs => 'Documentação de Modelos';
	@override String get preview => 'Pré-visualização de exemplo';
	@override String get reference => 'Referência de modelos';
	@override String get attributes => 'Atributos Disponíveis';
	@override String get filters => 'Filtros';
	@override String get flowControl => 'Controlo de Fluxo';
	@override String get unavailable => 'A pré-visualização fica indisponível até as extensões estarem prontas.';
	@override String get empty => '(resultado vazio)';
}

// Path: home.nav
class Translations$home$nav$pt extends Translations$home$nav$en {
	Translations$home$nav$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Operações';
	@override String get chase => 'Caça';
	@override String get logs => 'Registos';
	@override String get maps => 'Mapas';
	@override String get settings => 'Configurações';
}

// Path: home.panels
class Translations$home$panels$pt extends Translations$home$panels$en {
	Translations$home$panels$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Lista de Operações';
	@override String get operationsDescription => 'As suas operações, as mais recentes primeiro.';
	@override String get version => 'Versão Atual';
	@override String get versionDescription => 'A marca Ham2K, o nome desta app e a build que está a usar.';
}

// Path: home.logs
class Translations$home$logs$pt extends Translations$home$logs$en {
	Translations$home$logs$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registos';
	@override String get titleFor => 'Registos de';
	@override String get emptyCallsigns => 'Ainda não há QSOs registados';
	@override String emptyQsos({required Object call}) => 'Nenhum QSO para ${call}';
	@override String get mapNoSelection => 'Selecione um QSO para o ver no mapa';
	@override String get searchHint => 'Procurar indicativo ou nome';
	@override String get noSearchMatches => 'Nenhum QSO corresponde à pesquisa';
	@override String get titleAll => 'Todos os Registos';
	@override String get allCallsigns => 'Todos os indicativos';
	@override String get noOperation => 'Não pertence a nenhuma operação';
	@override String get unsavedTitle => 'Alterações não guardadas';
	@override String get unsavedBody => 'Este QSO tem alterações que não guardou.';
	@override String get pendingDeleteBody => 'Este QSO está marcado para eliminação.';
	@override String get editGone => 'Não guardado: esse QSO já não está neste registo.';
	@override String get discard => 'Descartar';
	@override late final Translations$home$logs$columns$pt columns = Translations$home$logs$columns$pt.internal(_root);
	@override late final Translations$home$logs$panels$pt panels = Translations$home$logs$panels$pt.internal(_root);
	@override late final Translations$home$logs$import$pt import = Translations$home$logs$import$pt.internal(_root);
}

// Path: chase.station
class Translations$chase$station$pt extends Translations$chase$station$en {
	Translations$chase$station$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estação de Caça';
	@override String get stationLabel => 'Estação: ';
	@override String get operatorLabel => 'Op: ';
	@override String get noLocation => 'Sem localização';
}

// Path: chase.periodInline
class Translations$chase$periodInline$pt extends Translations$chase$periodInline$en {
	Translations$chase$periodInline$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get today => 'hoje';
	@override String get thisWeek => 'esta semana';
	@override String get last14Days => 'nos últimos 14 dias';
	@override String get thisMonth => 'este mês';
}

// Path: chase.periodStats
class Translations$chase$periodStats$pt extends Translations$chase$periodStats$en {
	Translations$chase$periodStats$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get today => 'Estatísticas de hoje';
	@override String get thisWeek => 'Estatísticas desta semana';
	@override String get last14Days => 'Estatísticas dos últimos 14 dias';
	@override String get thisMonth => 'Estatísticas deste mês';
}

// Path: chase.period
class Translations$chase$period$pt extends Translations$chase$period$en {
	Translations$chase$period$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get today => 'Hoje';
	@override String get thisWeek => 'Esta Semana';
	@override String get last14Days => 'Últimos 14 Dias';
	@override String get thisMonth => 'Este Mês';
}

// Path: chase.goals
class Translations$chase$goals$pt extends Translations$chase$goals$en {
	Translations$chase$goals$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Objetivos de Caça';
	@override String remove({required Object name}) => 'Deixar de caçar ${name}';
	@override String get extensionsTitle => 'Extensões que incluem caça';
}

// Path: chase.panels
class Translations$chase$panels$pt extends Translations$chase$panels$en {
	Translations$chase$panels$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Controlos de registo por cima dos QSOs caçados no período.';
	@override String get info => 'Info';
	@override String get infoDescription => 'O indicativo a ser registado, ou as estatísticas do período.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Estações anunciadas no ar, prontas a caçar.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'Os QSOs do período e a estação a ser registada.';
}

// Path: dialogs.callChange
class Translations$dialogs$callChange$pt extends Translations$dialogs$callChange$en {
	Translations$dialogs$callChange$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicativo inválido: ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicativos inválidos: ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} operou até agora. ${typed} será registado nos novos contactos.';
	@override String operatorNoneSoFar({required Object typed}) => 'Nenhum operador registado até agora. ${typed} será registado nos novos contactos.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Esta operação já tem contactos de ${calls}. ${typed} só será registado nos novos.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Registar também ${typed} como operador do contacto já registado',
		other: 'Registar também ${typed} como operador de todos os ${count} contactos já registados',
	);
	@override String get operatorSeveralStations => 'Ao usar várias estações no ar, não há suporte para operadores separados';
	@override String get contactsUnreadable => 'Não foi possível ler os contactos desta operação, por isso alterar aqui um indicativo não oferecerá a sua atualização';
	@override String restampFailed({required Object error}) => 'Não foi possível atualizar os contactos já registados, por isso nada foi alterado: ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} de ${planned} contactos foram atualizados — os restantes já não estão nesta operação';
}

// Path: operation.tabs
class Translations$operation$tabs$pt extends Translations$operation$tabs$en {
	Translations$operation$tabs$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFO';
	@override String get spots => 'SPOTS';
	@override String get map => 'MAPA';
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Relógio';
	@override String get weather => 'Meteorologia';
	@override String get website => 'Site';
	@override String get remoteScreen => 'Ecrã Remoto';
	@override String get solar => 'Solar';
	@override String get radio => 'Rádio';
}

// Path: operation.positions
class Translations$operation$positions$pt extends Translations$operation$positions$en {
	Translations$operation$positions$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Ainda não há outras posições de operação a partilhar esta operação.';
	@override String positionLabel({required Object number}) => 'Pos: ${number}';
	@override String operatorLabel({required Object call}) => 'Op: ${call}';
	@override String get unnamedPosition => 'Outra posição';
	@override String get thisDevice => 'A nossa posição de operação';
	@override String get nameIn => ' em ';
	@override String get panelTitle => 'Posições';
	@override String get panelDescription => 'O que cada posição de operação que partilha esta operação está a registar neste momento.';
}

// Path: operation.menu
class Translations$operation$menu$pt extends Translations$operation$menu$en {
	Translations$operation$menu$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Mostrar campos RST';
	@override String get showStateField => 'Mostrar campo de Estado';
	@override String get showGridField => 'Mostrar campo de Grid';
	@override String get showDeletedQsos => 'Mostrar QSOs eliminados';
	@override String get showDeletedOps => 'Mostrar operações eliminadas';
	@override String get showQsoNumbers => 'Mostrar Números de QSO';
	@override String get lookupAllQsos => 'Pesquisar todos os QSOs';
	@override String get loggingSettingsTitle => 'Configurações de Registo';
	@override String get mapSettingsTitle => 'Configurações do Mapa';
	@override String get actionsSection => 'Ações';
}

// Path: operation.layout
class Translations$operation$layout$pt extends Translations$operation$layout$en {
	Translations$operation$layout$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Adicionar um Painel';
	@override String get availableSection => 'Painéis disponíveis';
	@override String panelSettings({required Object panel}) => 'Configurações de ${panel}';
	@override String get panelSettingsAction => 'Configurações do Painel';
	@override String get viewName => 'Vista da Operação';
	@override String get viewOptions => 'Opções de disposição da vista';
	@override String get viewTitleBuiltIn => 'Esta vista está integrada na app, tal como o seu nome';
	@override String get resetOptions => 'Repor Predefinições';
	@override String get removePane => 'Remover';
	@override String resetPaneConfirm({required Object panel}) => 'Repor ${panel} nas predefinições?';
	@override String get resetPaneConfirmBody => 'O título, o cabeçalho e o tamanho voltam às predefinições. O resto da disposição fica como está.';
	@override String get resetViewConfirm => 'Repor a disposição predefinida desta vista?';
	@override String get resetViewConfirmBody => 'Os painéis voltam à disposição predefinida, e as opções da vista e de cada painel voltam às predefinições.';
	@override String paneOptionsTitle({required Object panel}) => 'Configurações de Disposição de ${panel}';
	@override String get paneTitle => 'Título';
	@override String get paneShowHeader => 'Mostrar cabeçalho';
	@override String get paneShowHeaderTabset => 'Sempre visível enquanto este painel partilha um grupo — é pelo cabeçalho que se chega aos outros';
	@override String get paneInherit => 'Igual à app';
	@override String get searchHint => 'Procurar painéis';
	@override String get noPanelsMatch => 'Nenhum painel corresponde à pesquisa.';
	@override String get nothingToAdd => 'Esta vista já tem todos os painéis possíveis';
	@override String addPanel({required Object panel}) => 'Adicionar ${panel}';
	@override String showPreview({required Object panel}) => 'Pré-visualizar ${panel}';
	@override String missingExtension({required Object name}) => 'Falta a extensão "${name}"';
	@override String get previewUnavailable => 'Não foi possível mostrar a imagem de pré-visualização deste painel.';
	@override String get nestedPaneTitle => 'Mais';
	@override String get editLayout => 'Editar Disposição';
	@override String get saveLayout => 'Guardar Disposição';
	@override String get revertLayout => 'Descartar alterações à disposição';
	@override String get done => 'Concluído';
	@override String get layoutUnreadableTitle => 'Não foi possível ler a disposição';
	@override String get layoutUnreadableBody => 'Não foi possível ler a disposição guardada, por isso está a ser mostrada a disposição predefinida. A original só será substituída se escolher manter esta.';
	@override String get layoutUnreadableAction => 'Usar esta disposição';
	@override String panelRenderFailed({required Object panel}) => 'Não foi possível mostrar ${panel}';
	@override String get panelRenderRetry => 'Tentar novamente';
	@override String get panelActionFailed => 'A ação desse painel falhou. Tente novamente.';
	@override late final Translations$operation$layout$panels$pt panels = Translations$operation$layout$panels$pt.internal(_root);
	@override String get htmlPanelUnsupported => 'Este painel precisa de uma vista web, que esta plataforma não fornece';
	@override String get htmlPanelUnsupportedOnWeb => 'Este painel precisa de um ambiente isolado que a versão web não pode fornecer';
}

// Path: operation.export
class Translations$operation$export$pt extends Translations$operation$export$en {
	Translations$operation$export$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportações da Operação';
	@override String get syncedOperation => 'A operação está sincronizada';
	@override String get unsyncedOperation => 'A operação tem alterações não sincronizadas';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} QSO nesta operação',
		other: '${count} QSOs nesta operação',
	);
	@override String qsosSynced({required Object total}) => 'Todos os ${total} QSOs estão sincronizados';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} de ${total} QSOs por sincronizar';
	@override String eventsSynced({required Object total}) => '${total} marcadores de evento sincronizados';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendentes';
	@override String get loading => 'A carregar opções de exportação…';
	@override String get noOptions => 'Nenhum formato de exportação disponível (as extensões ainda estão a arrancar?)';
	@override String get nothingLogged => 'Ainda nada para exportar — esta operação não tem QSOs.';
	@override String get share => 'Partilhar';
	@override String get nothingSelected => 'Nada selecionado';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Guardar ${count} ficheiro',
		other: 'Guardar ${count} ficheiros',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Partilhar ${count} ficheiro',
		other: 'Partilhar ${count} ficheiros',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Exportar ${count} ficheiro',
		other: 'Exportar ${count} ficheiros',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Descarregar ${count} ficheiro',
		other: 'Descarregar ${count} ficheiros',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Guardar ${count} ficheiro combinado',
		other: 'Guardar ${count} ficheiros combinados',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Partilhar ${count} ficheiro combinado',
		other: 'Partilhar ${count} ficheiros combinados',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Exportar ${count} ficheiro combinado',
		other: 'Exportar ${count} ficheiros combinados',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Descarregar ${count} ficheiro combinado',
		other: 'Descarregar ${count} ficheiros combinados',
	);
	@override String saveOne({required Object name}) => 'Guardar ${name}';
	@override String shareOne({required Object name}) => 'Partilhar ${name}';
	@override String exportOne({required Object name}) => 'Exportar ${name}';
	@override String downloadOne({required Object name}) => 'Descarregar ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Arquivar ${count} ficheiro',
		other: 'Arquivar ${count} ficheiros',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Arquivar ${count} ficheiro combinado',
		other: 'Arquivar ${count} ficheiros combinados',
	);
	@override String get settingsButton => 'Configurações de exportação';
	@override String get settingsTitle => 'Configurações de Exportação';
	@override late final Translations$operation$export$compactFileNames$pt compactFileNames = Translations$operation$export$compactFileNames$pt.internal(_root);
	@override late final Translations$operation$export$includePrivateData$pt includePrivateData = Translations$operation$export$includePrivateData$pt.internal(_root);
	@override String get resultTitle => 'Exportação concluída';
	@override String get resultFailedTitle => 'A exportação falhou';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ficheiro exportado para ${path}',
		other: '${count} ficheiros exportados para ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ficheiro exportado: ${path}',
		other: '${count} ficheiros exportados: ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ficheiro partilhado',
		other: '${count} ficheiros partilhados',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ficheiro descarregado',
		other: '${count} ficheiros descarregados',
	);
	@override String exportFailed({required Object error}) => 'A exportação falhou: ${error}';
	@override late final Translations$operation$export$stash$pt stash = Translations$operation$export$stash$pt.internal(_root);
}

// Path: operation.spots
class Translations$operation$spots$pt extends Translations$operation$spots$en {
	Translations$operation$spots$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Nenhum spot corresponde aos filtros';
	@override String error({required Object error}) => 'Falha ao carregar spots: ${error}';
	@override String get unknownBand => 'Outra';
	@override String get auto => 'Automático';
	@override String autoValue({required Object value}) => 'Automático (Atualmente ${value})';
	@override String valueAuto({required Object value}) => '${value} (Auto)';
	@override String get any => 'Qualquer';
	@override String get allBands => 'Todas as Bandas';
	@override String get allModes => 'Todos os Modos';
	@override String get phoneAndCw => 'Telefone e CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'A mostrar ${count} de ${total} spots';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutos';
	@override String get callsOfNote => 'Indicativos Notáveis';
	@override String get yourSpots => 'Os Seus Spots';
	@override String get allSpots => 'Todos os Spots';
	@override late final Translations$operation$spots$continents$pt continents = Translations$operation$spots$continents$pt.internal(_root);
	@override late final Translations$operation$spots$filters$pt filters = Translations$operation$spots$filters$pt.internal(_root);
	@override String get unavailableTitle => 'Spots indisponíveis';
	@override String unavailableText({required Object sources}) => '${sources} não respondeu.';
	@override String get failedTitle => 'Erro na fonte de spots';
	@override String failedText({required Object sources}) => '${sources} devolveu um erro.';
	@override String get slideLogIt => 'Registar';
	@override String get slideIgnore => 'Ignorar';
	@override String get slideRestore => 'Repor';
	@override late final Translations$operation$spots$logConflict$pt logConflict = Translations$operation$spots$logConflict$pt.internal(_root);
}

// Path: operation.import
class Translations$operation$import$pt extends Translations$operation$import$en {
	Translations$operation$import$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importar Dados para a Operação';
	@override String get importAdifAction => 'Importar QSOs de ADIF';
	@override String get settingsButton => 'Configurações de escuta';
	@override String get settingsTitle => 'Escutar Outras Apps';
	@override String get protocolAddressLabel => 'Endereço';
	@override String get protocolPortLabel => 'Porta';
	@override String get protocolPortInvalid => 'Introduza uma porta entre 1 e 65535';
	@override String get protocolAddressInvalid => 'Introduza um endereço IP válido (ex. 127.0.0.1 ou 239.239.0.2)';
	@override String get protocolStatusReceiving => 'A receber dados';
	@override String get protocolStatusNoData => 'Nenhuns dados recebidos recentemente';
	@override String protocolBindError({required Object error}) => 'Não foi possível começar a escutar: ${error}';
	@override String captureFailed({required Object error}) => 'Não foi possível guardar os QSOs recebidos; a tentar novamente: ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Qualquer (broadcast)';
	@override String get wsjtxProtocolName => 'Servidor UDP do WSJT-X';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → separador Broadcast Data → assinale "Enable Broadcasts" para a informação de contactos. Defina o endereço IP como 127.0.0.1 se estiver a correr neste mesmo computador, ou 255.255.255.255 para difundir na rede local atual.';
	@override String get helpWsjtxSetup => 'File → Settings → separador Reporting → secção UDP Server → assinale "Accept UDP requests". Defina o UDP Server como 127.0.0.1 se estiver a correr neste mesmo computador, ou um endereço multicast como 239.239.0.2, e use o mesmo endereço na configuração acima nesta app.';
	@override String get listenTitle => 'Escutar QSOs de outras apps';
	@override String get listenDescriptionOnN1mm => 'A escutar o N1MM+';
	@override String get listenDescriptionOnWsjtx => 'A escutar o WSJT-X';
	@override String get listenDescriptionOnBoth => 'A escutar o N1MM+ e o WSJT-X';
	@override String get listenDescriptionOff => 'Desligado';
	@override String get addToOperationTitle => 'Adicionar a esta operação';
	@override String get addToOperationDescriptionOn => 'Os QSOs capturados são adicionados a esta operação à medida que chegam';
	@override String get addToOperationDescriptionOff => 'Os QSOs capturados ficam retidos até ativar esta opção';
	@override String get pendingSectionTitle => 'QSOs Capturados';
	@override String get pendingEmpty => 'Ainda nada capturado';
	@override String stationMismatch({required Object call}) => 'Registado como ${call}, não a estação desta operação';
	@override String get discardAction => 'Descartar';
	@override String get gapDialogTitle => 'Incluir capturas anteriores?';
	@override String gapDialogBody({required Object count}) => 'Foram capturados mais ${count} QSOs antes, antes de uma falha nos dados. Incluí-los também?';
	@override String get gapDialogRecentOnly => 'Só os recentes';
	@override String gapDialogIncludeAll({required Object count}) => 'Incluir todos os ${count}';
}

// Path: map.outlineIssue
class Translations$map$outlineIssue$pt extends Translations$map$outlineIssue$en {
	Translations$map$outlineIssue$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get link => 'Problemas?';
	@override String get title => 'Reportar um problema num contorno';
	@override String get reference => 'Que contorno';
	@override String get severity => 'Quão grave é?';
	@override String get minor => 'Pormenor';
	@override String get major => 'Grave';
	@override String get explanation => 'O que está errado?';
	@override String get explanationHint => 'O que o contorno tem de errado, e onde';
	@override String get send => 'Enviar';
	@override String get sending => 'A enviar o seu relatório — obrigado';
	@override String get copy => 'Copiar relatório';
	@override String get notSent => 'Não foi possível enviar o relatório';
	@override String get copied => 'Relatório copiado';
	@override String get notCopied => 'Não foi possível copiar o relatório';
}

// Path: map.postcard
class Translations$map$postcard$pt extends Translations$map$postcard$en {
	Translations$map$postcard$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get button => 'Postal da Operação';
	@override String title({required Object title}) => 'Postal de ${title}';
	@override String get portrait => 'Vertical';
	@override String get landscape => 'Horizontal';
	@override String get square => 'Quadrado';
	@override String get save => 'Guardar…';
	@override String get download => 'Descarregar';
	@override String get share => 'Partilhar';
	@override String get copy => 'Copiar';
	@override String get copied => 'Copiado para a área de transferência';
	@override String saved({required Object path}) => 'Guardado em ${path}';
	@override String downloaded({required Object name}) => '${name} descarregado';
	@override String savedMany({required Object count, required Object path}) => '${count} imagens guardadas em ${path}';
	@override String savedFiles({required Object names}) => '${names} guardado';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} já tinha sido guardado';
	@override String downloadedMany({required Object count}) => 'A descarregar ${count} imagens — autorize-as se o navegador pedir';
	@override String get mapLeftOut => 'O mapa não carregou, por isso ficou de fora';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — o mapa não carregou, por isso ficou de fora';
	@override String continued({required Object title}) => '${title} (continuação)';
	@override String get previousPage => 'Página anterior';
	@override String get nextPage => 'Página seguinte';
	@override String pageOf({required Object page, required Object count}) => 'Página ${page} de ${count}';
	@override String get sectionDays => 'Cada dia';
	@override String get reset => 'Repor';
	@override String failed({required Object error}) => 'Não foi possível criar o postal: ${error}';
	@override String get mapNotReady => 'O mapa não terminou de carregar. Verifique a ligação e tente novamente.';
	@override String saveFailed({required Object error}) => 'Não foi possível guardar o postal: ${error}';
	@override String get copyFailed => 'A área de transferência não aceitou a imagem. Tente novamente.';
	@override String get shareFailed => 'Não foi possível partilhar o postal. Tente novamente.';
	@override String get fileName => 'postal';
}

// Path: loggingControls.info
class Translations$loggingControls$info$pt extends Translations$loggingControls$info$en {
	Translations$loggingControls$info$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Ainda nenhum QSO… vamos para o ar!';
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
	@override String get noticeNewBand => 'Nova Banda';
	@override String get noticeNewMode => 'Novo Modo';
	@override String get noticeNewDXCC => 'Novo DXCC';
	@override String get noticeNewState => 'Novo Estado';
	@override String get noticeNewProvince => 'Nova Província';
	@override String get noticeNewDay => 'Novo Dia';
	@override String get noticeNewRef => 'Nova Ref';
	@override String get noticeNewMult => 'Novo Mult';
	@override String get noticeNewZone => 'Nova Zona';
	@override String get noticeInvalidMode => 'Modo Errado';
	@override String get noticeInvalidBand => 'Banda Errada';
	@override String get noticeInvalidCategory => 'Não Contactável';
	@override String get noticeWorkedBefore => 'Já Contactado';
	@override String get noticeNewPark => 'Novo Parque';
	@override String get noticeNewSection => 'Nova Secção';
	@override String get noticeBonusStation => 'Estação Bónus!';
	@override String get noticeMissingExchange => 'Sem Câmbio';
	@override String get noticeInvalidExchange => 'Câmbio Inválido';
	@override String get noticeUnknownEvent => 'Evento Desconhecido';
	@override String get noticeOurGrid => 'Definir o Nosso Grid';
	@override String get noticeRareCounty => 'Município Raro!';
	@override String get noticeOurLocation => 'Definir o Nosso Município';
	@override String get noticeShortGrid => 'Grid Demasiado Curto';
}

// Path: callInfo.history
class Translations$callInfo$history$pt extends Translations$callInfo$history$en {
	Translations$callInfo$history$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} nos últimos 7 dias';
	@override String today({required Object n}) => '${n} hoje';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class Translations$settings$theme$pt extends Translations$settings$theme$en {
	Translations$settings$theme$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo do Tema';
	@override String get system => 'Seguir as configurações do sistema';
	@override String get light => 'Claro';
	@override String get dark => 'Escuro';
}

// Path: settings.themeDescription
class Translations$settings$themeDescription$pt extends Translations$settings$themeDescription$en {
	Translations$settings$themeDescription$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get system => 'A seguir as configurações do sistema';
	@override String get light => 'Sempre no Modo Claro';
	@override String get dark => 'Sempre no Modo Escuro';
}

// Path: settings.fontScaleOpts
class Translations$settings$fontScaleOpts$pt extends Translations$settings$fontScaleOpts$en {
	Translations$settings$fontScaleOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

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
class Translations$settings$keepDeviceAwake$pt extends Translations$settings$keepDeviceAwake$en {
	Translations$settings$keepDeviceAwake$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Manter o Dispositivo Acordado';
	@override String get descriptionOn => 'A manter-se acordado na vista de registo ou durante uma sincronização';
	@override String get descriptionOff => 'A suspender como habitualmente';
}

// Path: settings.layoutDensityOpts
class Translations$settings$layoutDensityOpts$pt extends Translations$settings$layoutDensityOpts$en {
	Translations$settings$layoutDensityOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automática';
	@override String get densest => 'Muito densa';
	@override String get dense => 'Densa';
	@override String get normal => 'Normal';
	@override String get sparse => 'Espaçada';
	@override String get sparsest => 'Muito espaçada';
}

// Path: settings.distanceUnitsOpts
class Translations$settings$distanceUnitsOpts$pt extends Translations$settings$distanceUnitsOpts$en {
	Translations$settings$distanceUnitsOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Quilómetros';
	@override String get miles => 'Milhas';
}

// Path: settings.logging
class Translations$settings$logging$pt extends Translations$settings$logging$en {
	Translations$settings$logging$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Registo';
	@override late final Translations$settings$logging$leftieMode$pt leftieMode = Translations$settings$logging$leftieMode$pt.internal(_root);
	@override late final Translations$settings$logging$countryFlags$pt countryFlags = Translations$settings$logging$countryFlags$pt.internal(_root);
	@override late final Translations$settings$logging$countryFlagsDescription$pt countryFlagsDescription = Translations$settings$logging$countryFlagsDescription$pt.internal(_root);
	@override late final Translations$settings$logging$suggestDefaultOperator$pt suggestDefaultOperator = Translations$settings$logging$suggestDefaultOperator$pt.internal(_root);
	@override late final Translations$settings$logging$showBearing$pt showBearing = Translations$settings$logging$showBearing$pt.internal(_root);
	@override late final Translations$settings$logging$showReverseBearing$pt showReverseBearing = Translations$settings$logging$showReverseBearing$pt.internal(_root);
	@override late final Translations$settings$logging$switchSentRcvd$pt switchSentRcvd = Translations$settings$logging$switchSentRcvd$pt.internal(_root);
	@override late final Translations$settings$logging$jumpAfterRST$pt jumpAfterRST = Translations$settings$logging$jumpAfterRST$pt.internal(_root);
	@override late final Translations$settings$logging$defaultReport$pt defaultReport = Translations$settings$logging$defaultReport$pt.internal(_root);
	@override late final Translations$settings$logging$defaultReportCW$pt defaultReportCW = Translations$settings$logging$defaultReportCW$pt.internal(_root);
	@override late final Translations$settings$logging$defaultReportFT8$pt defaultReportFT8 = Translations$settings$logging$defaultReportFT8$pt.internal(_root);
	@override late final Translations$settings$logging$numbersRow$pt numbersRow = Translations$settings$logging$numbersRow$pt.internal(_root);
	@override late final Translations$settings$logging$numbersRowExtra$pt numbersRowExtra = Translations$settings$logging$numbersRowExtra$pt.internal(_root);
	@override late final Translations$settings$logging$numbersRowVibrate$pt numbersRowVibrate = Translations$settings$logging$numbersRowVibrate$pt.internal(_root);
	@override String get bands => 'Bandas Preferidas';
	@override String get modes => 'Modos Preferidos';
}

// Path: settings.catServer
class Translations$settings$catServer$pt extends Translations$settings$catServer$en {
	Translations$settings$catServer$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Servidor CAT';
	@override String get description => 'Permitir que outras apps (WSJT-X, programas de registo, etc.) controlem o rádio através do Ham2K Logger.';
	@override String get protocol => 'Protocolo';
	@override late final Translations$settings$catServer$protocolOpts$pt protocolOpts = Translations$settings$catServer$protocolOpts$pt.internal(_root);
	@override String get port => 'Porta';
	@override String get openAccess => 'Acesso aberto';
	@override String get openAccessOn => 'Qualquer computador na rede local pode ligar-se.';
	@override String get openAccessOff => 'Só as apps neste computador se podem ligar.';
	@override String get off => 'Desligado.';
	@override String starting({required Object protocol}) => '${protocol}, a iniciar…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} na porta ${port}. Clientes ligados: ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} na porta ${port}, mas nenhum rádio de VFO Principal está ligado.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} não consegue escutar na porta ${port}: ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: outro programa está a usá-la, muitas vezes o próprio ${protocol}. Feche esse programa ou escolha outra porta.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: este computador não o permite. Escolha uma porta acima de 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} deixou de escutar na porta ${port}. A tentar novamente…';
}

// Path: settings.radio
class Translations$settings$radio$pt extends Translations$settings$radio$en {
	Translations$settings$radio$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlo CAT';
	@override String get loggingAndCat => 'Registo e CAT';
	@override String get tuningSection => 'Sintonia';
	@override String get keyerSection => 'Manipulador';
	@override String get servicesSection => 'Serviços';
	@override String get stationConfigurationSection => 'Configuração da Estação';
	@override String get moreSettings => 'Mais configurações da estação';
	@override late final Translations$settings$radio$units$pt units = Translations$settings$radio$units$pt.internal(_root);
	@override late final Translations$settings$radio$pttKey$pt pttKey = Translations$settings$radio$pttKey$pt.internal(_root);
	@override late final Translations$settings$radio$smartVfoSnap$pt smartVfoSnap = Translations$settings$radio$smartVfoSnap$pt.internal(_root);
	@override late final Translations$settings$radio$snapDebounce$pt snapDebounce = Translations$settings$radio$snapDebounce$pt.internal(_root);
	@override late final Translations$settings$radio$snapLongMove$pt snapLongMove = Translations$settings$radio$snapLongMove$pt.internal(_root);
	@override late final Translations$settings$radio$snapMinMove$pt snapMinMove = Translations$settings$radio$snapMinMove$pt.internal(_root);
	@override late final Translations$settings$radio$snapMinSpeed$pt snapMinSpeed = Translations$settings$radio$snapMinSpeed$pt.internal(_root);
	@override late final Translations$settings$radio$enterSends$pt enterSends = Translations$settings$radio$enterSends$pt.internal(_root);
	@override late final Translations$settings$radio$keyerSpeed$pt keyerSpeed = Translations$settings$radio$keyerSpeed$pt.internal(_root);
	@override late final Translations$settings$radio$cwMessages$pt cwMessages = Translations$settings$radio$cwMessages$pt.internal(_root);
	@override late final Translations$settings$radio$voiceMessages$pt voiceMessages = Translations$settings$radio$voiceMessages$pt.internal(_root);
	@override late final Translations$settings$radio$avoidZeroBeat$pt avoidZeroBeat = Translations$settings$radio$avoidZeroBeat$pt.internal(_root);
	@override late final Translations$settings$radio$zeroBeatRange$pt zeroBeatRange = Translations$settings$radio$zeroBeatRange$pt.internal(_root);
}

// Path: settings.help
class Translations$settings$help$pt extends Translations$settings$help$en {
	Translations$settings$help$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajuda e Recursos';
	@override String get description => 'Comunidade e apoio';
	@override String get forums => 'Fóruns do Ham2K';
	@override String get forumsDescription => 'Encontre ajuda, dê feedback, discuta ideias…';
	@override String get chat => 'Chat do Ham2K';
	@override String get chatDescription => 'O servidor Discord da nossa comunidade online';
	@override String get youtube => 'YouTube do Ham2K';
	@override String get youtubeDescription => 'Vídeos e transmissões ao vivo';
	@override String get instagram => 'Instagram do Ham2K';
	@override String get instagramDescription => 'Porque nunca há fotos a mais…';
	@override String get bluesky => 'BlueSky do Ham2K';
	@override String get blueskyDescription => 'Siga-nos para notícias e atualizações';
	@override String get contact => 'Contacte-nos';
	@override String get contactDescription => 'help@ham2k.com — mas experimente primeiro os Fóruns ou o Chat!';
}

// Path: settings.exports
class Translations$settings$exports$pt extends Translations$settings$exports$en {
	Translations$settings$exports$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exportações';
}

// Path: settings.map
class Translations$settings$map$pt extends Translations$settings$map$en {
	Translations$settings$map$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mapas';
	@override late final Translations$settings$map$style$pt style = Translations$settings$map$style$pt.internal(_root);
	@override late final Translations$settings$map$styleOpts$pt styleOpts = Translations$settings$map$styleOpts$pt.internal(_root);
}

// Path: settings.privacy
class Translations$settings$privacy$pt extends Translations$settings$privacy$en {
	Translations$settings$privacy$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Privacidade';
	@override late final Translations$settings$privacy$shareAppData$pt shareAppData = Translations$settings$privacy$shareAppData$pt.internal(_root);
	@override late final Translations$settings$privacy$shareOpData$pt shareOpData = Translations$settings$privacy$shareOpData$pt.internal(_root);
	@override String get privacyPolicy => 'Política de Privacidade';
	@override String get termsOfService => 'Termos de Serviço';
}

// Path: settings.sync
class Translations$settings$sync$pt extends Translations$settings$sync$en {
	Translations$settings$sync$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sincronização na Nuvem';
	@override String get moreSettings => 'Mais configurações de sincronização';
	@override String get enable => 'Ativar Sincronização';
	@override String get deviceKey => 'Chave do Dispositivo';
}

// Path: settings.peers
class Translations$settings$peers$pt extends Translations$settings$peers$en {
	Translations$settings$peers$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dispositivos Pares';
	@override String get enable => 'Ligar a outros dispositivos';
	@override String get enableDescription => 'Permitir partilhar operações, registo, CAT e GPS com outros dispositivos na rede local';
	@override String get bleEnable => 'Ligar por Bluetooth';
	@override String get bleDescription => 'Usar Bluetooth LE para ligar mesmo sem rede local';
	@override String get thisDevice => 'Este Dispositivo';
	@override String get deviceName => 'Nome';
	@override String get deviceNameHint => 'Como este dispositivo é visto pelos outros dispositivos';
	@override String get pairedDevices => 'Dispositivos Vinculados';
	@override String get noPairedDevices => 'Ainda não há dispositivos vinculados. Ative esta opção noutro dispositivo desta rede para os vincular.';
	@override String deviceListProblem({required Object error}) => 'Não é possível ler os dispositivos vinculados: ${error}';
	@override String get nearby => 'Nas proximidades';
	@override String get connected => 'Ligado';
	@override String get viaBluetooth => 'por Bluetooth';
	@override String get connecting => 'A ligar…';
	@override String get syncing => 'A sincronizar…';
	@override String get waitingForThem => 'A aguardar o outro dispositivo';
	@override String get notConnected => 'Não ligado';
	@override String get wantsToPair => 'quer partilhar esta operação';
	@override String get allow => 'Permitir';
	@override String get link => 'Vincular';
	@override String get reject => 'Rejeitar';
	@override String get forget => 'Esquecer';
	@override String forgetTitle({required Object name}) => 'Esquecer ${name}?';
	@override String get forgetBody => 'Deixará de sincronizar com este dispositivo. Pode voltar a permiti-lo mais tarde, e os contactos já registados são mantidos.';
	@override String pairTitle({required Object name}) => 'Vincular com ${name}';
	@override String get pairBody => 'Este dispositivo está na sua rede local e quer ligar-se.';
	@override String get pairBodyBle => 'Este dispositivo está próximo e quer ligar-se por Bluetooth LE.';
	@override String get pairIdLabel => 'ID do Dispositivo';
	@override String get pairWarning => 'Vincule apenas dispositivos que reconheça. Qualquer dispositivo nesta rede pode enviar um pedido.';
	@override String get pairWarningBle => 'Vincule apenas dispositivos que reconheça. Qualquer dispositivo próximo pode enviar um pedido.';
	@override String problem({required Object error}) => 'Não é possível aceder à rede local: ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth: ${error}';
	@override String statusConnected({required Object device}) => 'Ligado a ${device}';
	@override String statusLost({required Object device}) => 'Ligação a ${device} perdida';
	@override String statusPerma({required Object connected, required Object linked}) => 'Dispositivos Pares: ${connected} de ${linked} ligados';
	@override String get screenEnable => 'Partilhar ecrãs e janelas';
	@override String get screenDescription => 'Permitir que outros dispositivos mostrem ecrãs ou janelas deste computador';
	@override String get screenSources => 'Ecrãs e Janelas';
	@override String get screenRefresh => 'Atualizar a lista';
	@override String get screenUnsupportedPlatform => 'Este dispositivo não pode partilhar o ecrã. O macOS pode; qualquer dispositivo pode mostrar um ecrã partilhado por outro.';
	@override String get screenUnsupportedVersion => 'Partilhar um ecrã requer o macOS 12.3 ou posterior. Este dispositivo pode na mesma mostrar um ecrã partilhado por outro.';
	@override String get screenNeedsPermission => 'O macOS precisa da sua permissão para gravar o ecrã antes de esta app poder partilhar um.';
	@override String get screenGrantPermission => 'Pedir permissão';
	@override String get screenRelaunchAfterGranting => 'Permita-o nas Definições do Sistema em Privacidade e Segurança → Gravação de Ecrã, depois saia e volte a abrir esta app — o macOS só informa uma app da alteração no arranque seguinte.';
	@override String screenProblem({required Object error}) => 'Partilha de ecrã: ${error}';
	@override String get screenChooseTitle => 'Escolher o Que Partilhar';
	@override String get screenChooseButton => 'Escolher o que partilhar…';
	@override String get screenTabScreens => 'Ecrãs';
	@override String get screenTabApps => 'Apps';
	@override String get screenTabWindows => 'Janelas';
	@override String get screenTabEmpty => 'Não foi encontrado nada deste tipo.';
	@override String get screenSharedSummaryNone => 'Ainda nada escolhido.';
	@override String get screenThisDevice => 'Este dispositivo';
	@override String screenSharedTo({required Object devices}) => 'Mostrado em ${devices}';
	@override String get screenSharedToNobody => 'Não está a ser mostrado';
	@override String screenStopSharing({required Object name}) => 'Deixar de partilhar ${name}';
}

// Path: settings.syncPanel
class Translations$settings$syncPanel$pt extends Translations$settings$syncPanel$en {
	Translations$settings$syncPanel$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuração da Sincronização';
	@override String get enableTitle => 'Sincronizar com o Ham2K Log Filer';
	@override String get enabledDescription => 'A fazer cópia de segurança e a sincronizar o seu registo entre dispositivos';
	@override String get disabledDescription => 'Desligado — fica apenas neste dispositivo';
	@override String get syncing => 'A sincronizar';
	@override String get account => 'Conta';
	@override String get refresh => 'Atualizar';
	@override String get switchAccounts => 'Mudar de Conta';
	@override String get switchAccountsDescription => 'Vincular este dispositivo a outra conta com um código QR ou e-mail';
	@override String get connectionRequests => 'Pedidos de Ligação';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Um dispositivo está à espera de se juntar a esta conta',
		other: '${n} dispositivos estão à espera de se juntar a esta conta',
	);
	@override String get accountEmailTitle => 'E-mail da conta';
	@override String accountEmailSent({required Object email}) => 'Confirmação enviada para ${email}. Abra a ligação lá para concluir a alteração.';
	@override String get resendConfirmation => 'Reenviar E-mail de Confirmação';
	@override String resendConfirmationDescription({required Object email}) => 'A aguardar ${email}';
	@override String accountEmailResent({required Object email}) => 'Enviado novamente para ${email}.';
	@override String get deviceLinked => 'Esse dispositivo está agora vinculado a esta conta.';
	@override String get checking => 'A verificar…';
	@override String get notLinked => 'Ainda não vinculado';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Substituir os dados locais?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} operação',
		other: '${n} operações',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Dados Sincronizados';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'A aguardar envio: ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Este dispositivo: a verificar…';
	@override String get countsServerChecking => 'Servidor: a verificar…';
	@override String get countsServerUnavailable => 'Servidor: indisponível';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Isto faz uma cópia de segurança e apaga ${operations} e ${qsos} deste dispositivo, e depois descarrega os dados da conta no seu lugar. A cópia de segurança fica na base de dados deste dispositivo.';
	@override String get replace => 'Substituir';
	@override String get pendingBannerTitle => 'Detetada nova conta Ham2K Log Filer';
	@override String get pendingBannerBody => 'Mantenha as operações e QSOs existentes neste dispositivo e intercale-os na conta, ou substitua-os pelos dados da conta (em ambos os casos fica uma cópia de segurança neste dispositivo).';
	@override String get combine => 'Intercalar';
	@override String get authIssueTitle => 'A sincronização não consegue ligar';
	@override String get authIssueText => 'O Ham2K Log Filer continua a rejeitar este dispositivo. Verifique o seu indicativo nas configurações de Sincronização.';
	@override String get openSettings => 'Abrir configurações de Sincronização';
}

// Path: settings.accounts
class Translations$settings$accounts$pt extends Translations$settings$accounts$en {
	Translations$settings$accounts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Contas, Serviços e Fontes de Dados';
	@override String get none => 'Nenhuma extensão ativa com contas';
	@override String get notConfigured => 'Não configurado';
	@override String get connected => 'Ligado';
	@override String get cancelLogin => 'Cancelar início de sessão';
	@override String get openInBrowser => 'Abrir no Navegador';
	@override String loggedInAs({required Object identity}) => 'Sessão iniciada como ${identity}';
	@override String get pressSaveToKeep => 'Prima Guardar para manter esta conta ligada.';
	@override String connectedTo({required Object label}) => 'Ligado a ${label}';
	@override String get connect => 'Ligar';
	@override String get disconnect => 'Desligar';
	@override String get connectedAs => 'Ligado como';
	@override String get test => 'Testar';
	@override String saveFailed({required Object error}) => 'Falha ao guardar: ${error}';
	@override String loginFailed({required Object error}) => 'Falha no início de sessão: ${error}';
	@override String get lookupFailed => 'As contas estão indisponíveis neste momento — tente novamente daqui a pouco';
	@override String get browserLoginTitle => 'Conclua o início de sessão no navegador';
	@override String browserLoginSteps({required Object prefix}) => 'Quando terminar, o navegador vai tentar abrir uma ligação que começa por "${prefix}". O mais provável é o seu computador não ter nada registado para a abrir, por isso copie essa ligação (da barra de endereço, ou da página de erro que o navegador mostrar) e cole-a aqui.';
	@override String browserLoginNotOpened({required Object prefix}) => 'O Ham2K Logger não conseguiu abrir o navegador. Copie a ligação de início de sessão abaixo e abra-a manualmente, depois copie a ligação para onde for reencaminhado (começa por "${prefix}") e cole-a aqui.';
	@override String get copyLoginLink => 'Copiar ligação de início de sessão';
	@override String get pastedLinkLabel => 'Cole a ligação aqui';
	@override String get finishLogin => 'Concluir Início de Sessão';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Essa não é a ligação de início de sessão — deve começar por "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Essa ligação pertence a outra tentativa de início de sessão. Feche esta página e ligue novamente.';
	@override String get pastedLinkNoCode => 'Essa ligação não tem código de início de sessão. Conclua primeiro o início de sessão, depois copie a ligação para onde for reencaminhado.';
	@override String get pastedLinkMalformed => 'Essa ligação parece cortada. Copie-a por inteiro e cole-a novamente.';
	@override String get relayLoginWaiting => 'A aguardar que conclua o início de sessão — continuará automaticamente quando o fizer.';
	@override String get loginNoResponse => 'Este dispositivo ainda não recebeu resposta do início de sessão. Se já concluiu no navegador, cancele e tente ligar novamente.';
	@override String get relayLoginNotOpened => 'O Ham2K Logger não conseguiu abrir o navegador automaticamente. Use o botão abaixo para abrir a página de início de sessão.';
	@override String get relayLoginUnavailable => 'Não foi possível contactar o servidor de sincronização necessário para concluir este início de sessão. Verifique a ligação e tente novamente.';
	@override String get loginIncompleteResponse => 'Essa tentativa de início de sessão não foi concluída corretamente. Tente ligar novamente.';
	@override String get noKeyringTitle => 'Não é possível guardar as credenciais das contas';
	@override String get noKeyringText => 'O Ham2K Logger não consegue aceder a um serviço de porta-chaves neste computador, por isso as credenciais das contas não podem ser guardadas nem lidas — ligar uma conta falhará até isto ser resolvido. Instale e inicie o **gnome-keyring**, o **KWallet** ou o **KeePassXC**, ou desbloqueie o porta-chaves que já tem, e reinicie. O registo, as exportações e os ficheiros de dados não são afetados; a sincronização do registo fica desligada enquanto isto durar.';
	@override String get noKeyringInline => 'Não é possível guardar credenciais: o porta-chaves deste computador está inacessível. Instale e inicie o gnome-keyring, o KWallet ou o KeePassXC, ou desbloqueie o que tem.';
	@override String get noSecureStorageInline => 'Não é possível guardar credenciais: o armazenamento seguro deste computador está inacessível.';
}

// Path: settings.station
class Translations$settings$station$pt extends Translations$settings$station$en {
	Translations$settings$station$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuração da Estação e Controlo CAT';
	@override String get none => 'Nenhum equipamento configurado';
	@override String get add => 'Adicionar';
	@override String get addTitle => 'Adicionar equipamento';
	@override String get searchHint => 'Procurar equipamento';
	@override String get noMatches => 'Nenhum equipamento corresponde';
	@override String get detectedEquipment => 'Equipamento Detetado';
	@override String discoveryUnavailable({required Object error}) => 'Não é possível escutar rádios: ${error}';
	@override String get edit => 'Editar equipamento';
	@override String get name => 'Nome';
	@override String get nameDescription => 'Como lhe chama — "Rádio da Esquerda". Opcional.';
	@override String get transport => 'Ligação';
	@override String get host => 'Endereço';
	@override String get hostDescription => 'O nome de anfitrião ou endereço IP do rádio na sua rede.';
	@override String get port => 'Porta';
	@override String get hostRequired => 'É necessário um endereço';
	@override String get portInvalid => 'A porta tem de estar entre 1 e 65535';
	@override String get connect => 'Ligar';
	@override String get disconnect => 'Desligar';
	@override String get remove => 'Remover';
	@override String removeTitle({required Object name}) => 'Remover ${name}?';
	@override String get removeMessage => 'Isto só o remove da app. As configurações do equipamento ficam como estão.';
	@override String unknownType({required Object typeKey}) => 'Tipo de equipamento não reconhecido "${typeKey}"';
	@override String get report => 'Reportar';
	@override String get reportTitle => 'Reportar este rádio';
	@override String get reportIntro => 'Diga-nos que rádio é realmente este e como correu. O seu relatório torna-se um cartão que a equipa Ham2K lê, e o que escrever sobre como o pôs a funcionar pode vir a ajudar o próximo operador com o mesmo equipamento.';
	@override String get reportManufacturer => 'Fabricante';
	@override String get reportManufacturerDescription => 'Quem o fabrica — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'É necessário um fabricante';
	@override String get reportModel => 'Modelo';
	@override String get reportModelDescription => 'O modelo, tal como o próprio rádio lhe chama — "IC-7300", "FT-991A".';
	@override String get reportModelRequired => 'É necessário um modelo';
	@override String get reportOutcome => 'Como correu?';
	@override String get reportOutcomeWorks => 'Funcionou bem';
	@override String get reportOutcomeIssues => 'Funcionou, com problemas';
	@override String get reportOutcomeFails => 'Não funcionou de todo';
	@override String get reportOutcomeRequired => 'Diga-nos como correu';
	@override String get reportComments => 'Comentários';
	@override String get reportCommentsPlaceholder => 'O que funcionou, o que não funcionou, o que o surpreendeu.';
	@override String get reportHints => 'Dicas de resolução de problemas';
	@override String get reportHintsPlaceholder => 'Quer sugerir algumas dicas de resolução de problemas a outros utilizadores?';
	@override String get reportSend => 'Enviar relatório';
	@override String get reportSending => 'A enviar o seu relatório…';
	@override String reportSent({required Object ref}) => 'Obrigado — o seu relatório foi registado como ${ref}.';
	@override String get reportSentNoRef => 'Obrigado — o seu relatório foi enviado.';
	@override String reportFailed({required Object error}) => 'O relatório não foi enviado: ${error}';
	@override String get troubleshootingNotes => 'Notas de Resolução de Problemas';
	@override String get mainVfo => 'VFO Principal';
	@override String get useAsMainVfo => 'Usar como VFO Principal';
	@override String get serialPort => 'Porta série';
	@override String get serialPortDescription => 'A porta onde aparece a interface CAT do rádio.';
	@override String get serialPortNone => 'Nenhuma porta série encontrada';
	@override String get serialPortRequired => 'Escolha uma porta série';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'porta ${n} de ${total}';
	@override String get serialPortSuggested => 'sugerida';
	@override String get serialPortJustNow => 'Ligada recentemente';
	@override String get serialDeviceRequest => 'Adicionar um dispositivo USB…';
	@override String get baudRate => 'Velocidade (baud)';
	@override String get baudRateDescription => 'Tem de corresponder ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo e nenhum erro.';
	@override String get serialRtsHigh => 'Manter RTS alto';
	@override String get serialRtsHighDescription => 'Só para um rádio que espera pelo RTS antes de responder, como um Yaesu com CAT RTS ligado. Num Digirig, SignaLink e na maioria dos cabos caseiros o RTS é o PTT, e mantê-lo alto põe o rádio a transmitir.';
	@override String get serialDtrHigh => 'Manter DTR alto';
	@override String get serialDtrHighDescription => 'Só para uma interface CAT alimentada pelo DTR, como alguns cabos RS-232 para o FT-817. Em muitos cabos o DTR manipula o CW ou o PTT, e mantê-lo alto põe o rádio a transmitir.';
	@override String get civAddress => 'Endereço CI-V do rádio';
	@override String get civAddressDescription => 'Em hexadecimal, tal como aparece no menu CI-V do rádio. O IC-705 vem de fábrica com A4.';
	@override String get civAddressInvalid => 'Um endereço CI-V tem dois dígitos hexadecimais, de 01 a FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Qual das slices do rádio esta ligação lê e sintoniza.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Escolha uma das slices do rádio, de A a H';
	@override String flexSliceMissing({required Object letter}) => 'A slice ${letter} não está em uso neste rádio — escolha outra slice, ou crie-a no SmartSDR';
	@override String get channelNotInUse => 'não está em uso';
	@override String get channelHeldByUnknown => 'em uso por outro programa';
	@override String get flexNoSlices => 'Este rádio não reportou nenhuma slice — verifique se o SmartSDR está a correr e se este cliente pode subscrever';
	@override String get spectrumUnsupported => 'Este rádio não envia espectro por CAT';
	@override String get spectrumRequiresBaud => 'Requer CAT a 115200 bps';
	@override String get spectrumNoRadio => 'Nenhum rádio ligado';
	@override String get spectrumWaiting => 'A aguardar o espectro do rádio…';
	@override String get spectrumUnavailable => 'A visualização do espectro não está disponível';
	@override String get spectrumNoDaxChannel => 'Todos os canais DAX IQ deste rádio estão em uso';
	@override String get spectrumNoPanadapter => 'Esta slice não tem panadapter no rádio';
	@override String spectrumStreamRefused({required Object code}) => 'O rádio recusou um fluxo DAX IQ (erro ${code})';
	@override String get spectrumNoUdp => 'Os dados de espectro do rádio não chegam a este dispositivo';
	@override String get spectrumScopeRefused => 'O rádio recusou os comandos do scope';
	@override String get spectrumOutOfRange => 'O scope do rádio está definido fora do intervalo que consegue mostrar';
	@override String get n3fjpNoRig => 'O N3FJP não tem nenhuma interface de rádio configurada, por isso isto segue o que é escrito no N3FJP, não um rádio';
	@override String get winkeyerKeyPort => 'Saída de manipulação';
	@override String get winkeyerKeyPortDescription => 'Em qual das duas tomadas de saída do manipulador está ligado o seu rádio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Porta ${n}';
	@override String get winkeyerPtt => 'Usar o PTT do manipulador';
	@override String get winkeyerPttDescription => 'Aciona a linha de PTT na mesma tomada, para um amplificador ou um rádio que precise dela. Deixe desligado para um rádio manipulado pela tomada da chave.';
	@override String get winkeyerNoAnswer => 'Nenhum WinKeyer respondeu nesta porta';
	@override String get winkeyerStoppedAnswering => 'O WinKeyer deixou de responder durante o envio; a mensagem foi descartada';
	@override String get radioUser => 'Nome de utilizador do rádio';
	@override String get radioPass => 'Palavra-passe do rádio';
	@override String get radioLoginDescription => 'O login Network → Remote do rádio, não a palavra-passe do WiFi.';
	@override String get radioUserRequired => 'É necessário o nome de utilizador de controlo remoto do rádio';
	@override String get connectFailedBusy => 'O dispositivo está em uso';
	@override String get connectFailedDenied => 'Acesso negado';
	@override String get connectFailedDevice => 'Dispositivo não encontrado';
	@override String get connectFailedLines => 'Não foi possível manter o RTS/DTR como definido, por isso a porta foi fechada. Outro programa pode ter deixado o controlo de fluxo por hardware ligado — desligue e volte a ligar o cabo.';
	@override String get connectFailedNetwork => 'Não é possível encontrar o rádio na rede. Verifique o endereço e se está ligado e acessível.';
	@override String get connectFailedTimeout => 'O rádio não respondeu a tempo. Verifique se está ligado e acessível.';
	@override late final Translations$settings$station$models$pt models = Translations$settings$station$models$pt.internal(_root);
	@override late final Translations$settings$station$transports$pt transports = Translations$settings$station$transports$pt.internal(_root);
	@override String get troubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get ft891Troubleshooting => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **O CAT RTS tem de estar OFF no rádio** (menu **05-08** do FT-891). Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo. Num Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, por isso subi-la poria o emissor a transmitir. Na porta USB do próprio rádio, a alternativa é **Manter RTS alto** em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao CAT RATE do rádio (menu **05-06**). Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get yaesuBinaryTroubleshooting => 'Este rádio usa o CAT antigo de cinco bytes da Yaesu, e não responde de todo quando algo está errado. Quase sempre é uma destas causas:\n\n- **O cabo tem de converter níveis.** A tomada CAT na traseira não é RS-232 nem USB; precisa de um CT-62 ou de um adaptador equivalente. Um cabo simples de áudio ou de dados não funciona para CAT.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio (**#14** num FT-817, **#19** num FT-857 ou FT-897). Se não corresponder, o rádio não devolve nada, e nunca um erro.\n- **Nunca deixe nada subir o RTS ou o DTR nesta porta.** Na maioria dos cabos para estes rádios essas linhas são o PTT e a manipulação. Uma interface antiga alimentada pelo DTR é a exceção: para essa, ative **Manter DTR alto** em Configurações Avançadas.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\nEste controlador foi escrito a partir da tabela CAT publicada pela Yaesu e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena reportar.';
	@override String get guohetecTroubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get guohetecTroubleshooting => 'O Q900 tem dois protocolos CAT, e esta entrada usa o nativo em vez da imitação do FT-817. Escolha aqui **Guohetec Q900**, não um FT-817 — a imitação suporta menos comandos, e o rádio não diz qual está a usar.\n\n- **O cabo USB-C é a ligação CAT**, e também liga a placa de som. A velocidade não importa nele; a porta ignora o valor definido.\n- **Nunca deixe nada subir o RTS ou o DTR nesta porta.** Num cabo série essas linhas são o PTT e a manipulação.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Um rádio de segunda geração comporta-se de forma diferente** de um de primeira. Prima longamente Menu, depois About: HW 2.0 é a segunda geração.\n\nEste controlador foi escrito a partir do protocolo publicado pelo fabricante e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena reportar.';
	@override String get yaesuTroubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get yaesuTroubleshooting => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo. Num Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, por isso subi-la poria o emissor a transmitir. Na porta USB do próprio rádio, a alternativa é **Manter RTS alto** em Configurações Avançadas. O local dessa configuração varia com o modelo (menu **05-08** num FT-891).\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Os modos seguem a tabela do FT-891.** A maior parte da gama Yaesu corresponde-lhe, mas um rádio que numere os modos de outra forma vai mostrar e definir o modo errado nesses casos. A frequência não é afetada.';
	@override String get yaesuRs232Troubleshooting => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **A tomada CAT é RS-232.** Precisa de um adaptador USB-série e de um cabo DB-9 direto — um cabo null-modem troca as linhas, e o rádio nunca recebe nada.\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo, a menos que **Manter RTS alto** esteja ativo em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\nEsta entrada foi escrita a partir de documentação CAT publicada e ainda não foi testada com um destes rádios. Se funcionar só em parte, vale a pena reportar.';
	@override String get yaesuUsbTroubleshooting => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **Use a primeira das duas portas USB do rádio.** O CAT está normalmente na primeira (a porta COM **Enhanced** no Windows); a segunda (**Standard**) é para PTT e manipulação. O seletor aponta para a primeira sempre que consegue distinguir as duas.\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo, a menos que **Manter RTS alto** esteja ativo em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.';
	@override String get k4SerialNotes => 'Ligue a tomada USB-B (PC) traseira do K4. Tanto USB-PC1 como USB-PC2 servem para CAT; escolha uma porta livre e faça corresponder a configuração Serial USB-PCn: Baud Rate no rádio. O HaLo preenche 38400; altere se necessário. Outra aplicação tem de usar a outra porta ou a Ethernet.\n\nEsta ligação controla o rádio e os seus manipuladores; não envia áudio para o HaLo.';
	@override String get k4TcpNotes => 'Ligue a tomada Ethernet do K4 à sua rede local. Introduza o nome de anfitrião ou o endereço IP e a porta CAT 9200. Isto é controlo CAT, não a ligação de áudio remoto separada na porta 9204.\n\nO HaLo controla o rádio e os seus manipuladores sem transmitir áudio nem dados do panadapter.';
	@override String get k4PowerTimeout => 'A potência do K4 não foi alterada porque o rádio não confirmou a sua gama de saída. Tente novamente.';
	@override String get k4PowerRange => 'A potência do K4 tem de estar entre 0,1–110 W, ou 0,0001–0,01 W quando a saída de miliwatts do transverter está ativa.';
	@override String get elecraftTroubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get elecraftTroubleshooting => 'Os rádios Elecraft falam CAT Kenwood, e um KX2 e um KX3 já foram usados desta forma — VFO nos dois sentidos, mudança de modo e batimento zero em CW, tudo a funcionar.\n\nSe o rádio não responder, quase sempre é uma destas causas:\n\n- **A velocidade tem de corresponder** à definida em **RS232** no menu do rádio. Estes rádios vêm de fábrica com 38400. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\n**Se a frequência estiver certa mas o modo errado**, diga-nos. As entradas do KX2 e KX3 leem o modo numa posição da resposta de estado do rádio que fixámos a partir dos rádios que vimos, e um firmware que o coloque noutro sítio só chega até nós através de um relatório.\n\nO K3 ainda não foi reportado em nenhum sentido, por isso diga-nos o que acontece se usar um. O K4 tem a sua própria entrada.';
	@override String get kenwoodTroubleshootingTitle => 'Se o rádio liga mas não mostra a frequência';
	@override String get kenwoodTroubleshooting => 'Este controlador está comprovado com os TS-590SG e TS-480 da Kenwood, os QMX e QCX-mini da QRP Labs, e os KX2 e KX3 da Elecraft. O resto da gama foi escrito a partir de referências CAT publicadas, por isso reporte o que acontecer, corra bem ou mal.\n\nSe o rádio não responder, quase sempre é uma destas causas:\n\n- **A velocidade tem de corresponder** ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Alguns rádios precisam de ter o CAT ativado** no menu antes de responderem.\n\n**Vários front-ends SDR falam este mesmo protocolo**, por isso vale a pena experimentar esta entrada também com eles; os rádios Elecraft estão listados à parte, em Elecraft. Se a frequência estiver certa mas o modo estiver errado ou em falta, essa é a única parte que difere ao longo da gama — a app deduz o modo a partir do rádio e, se não conseguir, pergunta-lhe diretamente, por isso o modo pode simplesmente chegar com atraso.';
	@override String get statusConnected => 'Ligado';
	@override String get statusLost => 'Desligado';
	@override String get notConfigured => 'Não configurado';
	@override String get currentConfiguration => 'Configuração Atual';
	@override String get currentTransceiver => 'Transcetor Atual';
	@override String get radioMode => 'Modo do Rádio';
	@override String get keyerNotSupported => 'Não suportado pelo rádio atual';
	@override String get catControlPreferences => 'Preferências do Controlo CAT';
	@override String get chooseTransceiver => 'Escolher transcetor';
	@override String get configurationSection => 'Configuração';
	@override String get noTransceiverSelected => 'Nenhum transcetor selecionado';
	@override String makeMainVfo({required Object name}) => 'Usar ${name} como VFO Principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		zero: 'Nenhum transcetor',
		one: '${count} transcetor',
		other: '${count} transcetores',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} antena',
		other: '${count} antenas',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} outro dispositivo',
		other: '${count} outros dispositivos',
	);
	@override String get equipmentInventory => 'Inventário de Equipamento';
	@override String get equipmentInUse => 'Controlos do Transcetor';
	@override String get noTransceiver => 'Nenhum';
	@override String get peerRadioNotAvailable => 'Indisponível';
	@override String peerRadioOnDevice({required Object device}) => 'Em ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} está noutro dispositivo';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Este rádio está ligado a ${device}. A ligação e as configurações são feitas nesse dispositivo.';
	@override String get antennaInUse => 'Antena em Uso';
	@override String get keyInUse => 'Chave em Uso';
	@override String get noneSelected => 'Nenhuma';
	@override String get moreSettings => 'Mais Configurações';
	@override String get icomCivTroubleshootingTitle => 'Se aparecerem duas portas série para o mesmo rádio';
	@override String get icomCivTroubleshooting => 'Vários rádios Icom, entre eles o IC-705, apresentam **duas** portas série USB ao mesmo tempo (a Icom chama-lhes Port A e Port B), ambas definidas para CI-V por omissão. Nem esta app nem o seu sistema operativo as conseguem distinguir além disso: o mesmo ID de fabricante/produto USB aparece simplesmente duas vezes, por vezes marcado aqui com o sufixo `#2`. **A Port A é normalmente a certa** — em geral a primeira que o sistema operativo ou o navegador lista, e quando esta app consegue distinguir as duas portas marca essa como sugerida. Se os comandos saem e o rádio nunca responde, experimente a outra porta.';
	@override String get civAddressTroubleshootingTitle => 'Se o rádio nunca responder';
	@override String get civAddressTroubleshooting => '- **O endereço CI-V tem de corresponder** ao menu do rádio. Esta entrada preenche o endereço de fábrica do modelo, mas um rádio que partilha um barramento CI-V é exatamente onde ele é alterado. Uma trama enviada para o endereço errado é ignorada em silêncio, o que parece exatamente um cabo avariado.\n- **A velocidade tem de corresponder** ao CI-V BAUD RATE do rádio (em USB, CI-V USB Baud Rate). Defina no rádio o mesmo número mostrado aqui, **não Auto**. Em Auto alguns rádios, entre eles o IC-7300, ligam e deixam de responder ao fim de um minuto ou assim.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.';
	@override String get ic7300Mk2Note => '\n- O **IC-7300 MK2** vem de fábrica com o endereço `B6`, não o `94` aqui preenchido — escolha antes a entrada IC-7300 MK2.';
	@override String get ic705PortNote => '\n- O **IC-705** apresenta duas portas série USB, ambas com o nome do rádio. O CI-V está na **primeira**, para a qual o seletor aponta sempre que consegue distinguir as duas.';
	@override String get ic7760PortNote => '\n- O **IC-7760** fala CI-V na **Port A** das duas portas série USB que apresenta.';
	@override String get x6100PortNote => '\n- O **X6100** fala CI-V na sua porta **DEV** — a segunda das duas portas série que apresenta, e aquela para a qual o seletor aponta.';
	@override String get rigctldTroubleshootingTitle => 'Se a app não conseguir ligar';
	@override String get rigctldTroubleshooting => 'Isto liga a um **daemon rigctld que executa por sua conta**, não diretamente ao rádio — o backend do Hamlib fala com o rádio e suporta centenas de modelos.\n\n- **O daemon já tem de estar a correr**, por ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Encontre o número de modelo do seu rádio com `rigctl -l`.\n- **A partir de outra máquina**, inicie-o com `-T 0.0.0.0`: por omissão o rigctld só aceita ligações da máquina onde corre.\n- **A porta** é 4532, a menos que tenha iniciado o daemon com `-t`.\n- Depois de ligado, a falta de frequência normalmente significa que o próprio daemon não consegue chegar ao rádio. Teste-o com `rigctl -m 2 f` na máquina do daemon.';
	@override String get flrigTroubleshootingTitle => 'Se a app não conseguir ligar';
	@override String get flrigTroubleshooting => 'Isto liga a um **programa flrig que executa por sua conta**, não diretamente ao rádio — o flrig fala com o rádio e suporta a maioria das marcas e modelos.\n\n- **O flrig já tem de estar a correr**, com o transcetor configurado e ligado.\n- **A porta** é 12345, a menos que a tenha alterado na configuração do flrig (Config → Setup → Server).\n- **A partir de outra máquina**, garanta que o servidor do flrig está acessível. Escuta em todas as interfaces, mas a sua firewall pode não concordar.\n- Depois de ligado, a falta de frequência normalmente significa que o próprio flrig não consegue chegar ao rádio. Verifique se o mostrador do flrig acompanha o botão de sintonia.';
	@override String get hrdTroubleshootingTitle => 'Se a app não conseguir ligar';
	@override String get hrdTroubleshooting => 'Isto liga ao **Rig Control do Ham Radio Deluxe, a correr no seu computador**, não diretamente ao rádio — é o HRD que fala com o rádio.\n\n- **O Rig Control já tem de estar a correr** e ligado ao rádio.\n- **O servidor IP dele tem de estar ativado.** O Rig Control só comunica com outros programas através dele.\n- **A porta** é 7809, a menos que a tenha alterado nas configurações do servidor IP.\n- **A partir de outra máquina**, garanta que a firewall deixa passar a ligação.\n\nEsta entrada foi escrita a partir de descrições publicadas do protocolo do HRD e ainda não foi testada com o HRD. Se funcionar só em parte, vale a pena reportar.';
	@override String get n3fjpTroubleshootingTitle => 'Se a app não conseguir ligar';
	@override String get n3fjpTroubleshooting => 'Isto liga a **um programa de registo N3FJP a correr no seu computador**, não diretamente ao rádio — é o N3FJP que fala com o rádio.\n\n- **A API do programa tem de estar ligada**: Settings → Application Program Interface, assinale **TCP API Enabled**.\n- **A porta** é 1100, a menos que a tenha alterado aí.\n- **O N3FJP tem de ter uma interface de rádio configurada** para seguir ou sintonizar o rádio. Sem ela, só reporta o que é escrito na sua janela de entrada.\n- O N3FJP só reporta banda, modo e frequência: nem potência, nem estado de transmissão.\n\nEsta entrada foi escrita a partir da API publicada do N3FJP e ainda não foi testada com o N3FJP. Se funcionar só em parte, vale a pena reportar.';
	@override String get commanderTroubleshootingTitle => 'Se a app não conseguir ligar';
	@override String get commanderTroubleshooting => 'Isto liga ao **DXLab Commander, a correr no seu computador**, não diretamente ao rádio — é o Commander que fala com o rádio.\n\n- **O Commander já tem de estar a correr** e ligado ao rádio.\n- **O serviço de rede dele tem de estar ligado**: o botão **Net Serv** no painel Radio da janela Configuration do Commander.\n- **A porta** é 52002, a terceira porta do bloco que começa na **Base Port** do Net Serv (52000, a menos que a tenha alterado).\n- **A partir de outra máquina**, garanta que a firewall deixa passar a ligação.\n\nEsta entrada foi escrita a partir das mensagens TCP publicadas do Commander e ainda não foi testada com o Commander. Se funcionar só em parte, vale a pena reportar.';
	@override String get ic705TroubleshootingTitle => 'Se o rádio nunca responder';
	@override String get ic705Troubleshooting => 'O rádio tem uma **única** sessão de controlo remoto. Quando o login é ignorado, quase sempre há outra coisa a usá-la.\n\n- **Feche qualquer outro cliente.** Um wfview ou RS-BA1 ligado ao mesmo rádio ocupa essa única sessão, e o login aqui é simplesmente ignorado enquanto isso acontecer.\n- **Verifique as configurações de rede do rádio.** O WLAN tem de estar ligado, o rádio tem de estar na mesma rede, e a função de controlo remoto (Network) tem de estar ativada.\n- **Desligue e volte a ligar o WLAN do rádio** se continuar bloqueado. Isso limpa de forma fiável uma sessão presa no rádio.\n\nUma **palavra-passe errada é recusada explicitamente**, não recebe silêncio. Se chegou aqui em vez de receber uma mensagem de "rejeitado", o problema não é a palavra-passe.';
	@override String get statusStale => 'Não responde';
	@override String get statusDisconnected => 'Não ligado';
	@override String get statusConnecting => 'A ligar…';
	@override String get statusDisconnecting => 'A desligar…';
	@override String get statusError => 'A ligação falhou';
	@override String get currentRadioSettings => 'Configurações atuais do rádio';
	@override String get notSupportedByThisRadio => 'Não suportado por este rádio';
	@override String get keyerRowLabel => 'Manipulador';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Voz';
	@override String voiceKeyerAvailable({required Object count}) => 'Manipulador de voz: ${count} memórias no rádio';
	@override String get antennaBands => 'Bandas';
	@override String get antennaType => 'Tipo de antena';
	@override String get antennaTypeRequired => 'Escolha um tipo de antena';
	@override late final Translations$settings$station$antennaTypes$pt antennaTypes = Translations$settings$station$antennaTypes$pt.internal(_root);
	@override String get keyType => 'Tipo de chave';
	@override String get keyTypeRequired => 'Escolha um tipo de chave';
	@override late final Translations$settings$station$keyTypes$pt keyTypes = Translations$settings$station$keyTypes$pt.internal(_root);
	@override String get softwareIntermediaries => 'Software Intermediário';
	@override String get otherBrands => 'Outras Marcas';
	@override String get otherEquipment => 'Outro Equipamento (Antenas, Chaves, etc.)';
	@override String get newAntenna => 'Nova Antena';
	@override String get newKey => 'Nova Chave';
	@override String get newKeyer => 'WinKeyer (K1EL ou compatível)';
	@override String keyViaRadio({required Object radio}) => 'Manipulador CAT em ${radio}';
	@override String keyOnDevice({required Object device}) => 'Chave em ${device}';
	@override String get cwKeyerArea => 'Área do manipulador';
	@override String get trackStationInfo => 'Guardar Info da Estação em cada QSO';
	@override String get includeStationInfoInAdif => 'Incluir nas exportações ADIF';
	@override String get whatToTrack => 'O que guardar?';
	@override String get trackFieldRig => 'Transcetor';
	@override String get trackFieldPower => 'Potência';
	@override String get watts => 'Watts';
	@override String get trackFieldAntenna => 'Antena';
	@override String get trackFieldKey => 'Chave CW';
	@override String get placeholderConnectDelay => 'Atraso de ligação (ms)';
	@override String get placeholderConnectDelayDescription => 'Quanto tempo demora o handshake simulado. Vazio ou 0 liga instantaneamente.';
	@override String get placeholderDropAfter => 'Cair após (segundos)';
	@override String get placeholderDropAfterDescription => 'Fecha a ligação por si só, para testar o caminho de religação. Vazio ou 0 nunca cai.';
	@override String get placeholderFailConnect => 'Falhar sempre a ligação';
	@override String get placeholderConnectFailure => 'O rádio marcador foi instruído a recusar esta ligação';
	@override String get placeholderFreq => 'Frequência (kHz)';
	@override String get placeholderFreqDescription => 'Onde o rádio marcador começa. Depois reporta o que quer que a app sintonize.';
	@override String get placeholderMode => 'Modo';
	@override String get placeholderModeDescription => 'O modo em que o rádio marcador começa, por ex. USB, CW, FT8.';
	@override String get placeholderPower => 'Potência (watts)';
	@override String get placeholderPurpose => 'Use este rádio para registar que equipamento está a usar, para efeitos de registo';
	@override String get placeholderReplyDelay => 'Atraso de resposta (ms)';
	@override String get placeholderReplyDelayDescription => 'Quanto tempo o rádio marcador demora a reportar uma alteração. Vazio ou 0 responde de imediato.';
	@override String get cwKeyerField => 'Manipulador CW por CAT';
	@override String get cwKeyerFieldDescription => 'Se este rádio manipula CW a partir de texto por CAT. Desligado para um rádio que a app não conhece.';
	@override String get voiceMemories => 'Memórias de voz';
	@override String get voiceMemoriesDescription => 'Quantas memórias de voz o rádio reproduz por CAT. 0 para nenhuma.';
	@override String get voiceMemoriesInvalid => 'Um número inteiro, 0 ou mais';
	@override String get yaesuMeterCapture => 'Capturar leituras dos medidores';
	@override String get yaesuBinaryMeterCaptureDescription => 'Lê o medidor de potência de saída e o indicador de SWR alta do rádio durante a transmissão e escreve os valores brutos no registo. Serve para construir a escala que a Yaesu não publica — os valores não são mostrados como medidores.';
	@override String get yaesuMeterCaptureDescription => 'Lê os medidores PO, SWR e ALC do rádio durante a transmissão e escreve os valores brutos no registo. Serve para construir a escala que a Yaesu não publica — os valores não são mostrados como medidores.';
	@override String get telemetryInterval => 'Intervalo de leitura dos medidores (ms)';
	@override String get telemetryIntervalDescription => 'Com que frequência ler os medidores do rádio durante a transmissão. Deixe vazio para o mais rápido que esta ligação aguenta, até 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}';
	@override String get pollInterval => 'Intervalo de consulta em repouso (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Com que frequência perguntar ao rádio a frequência e o modo enquanto nenhum deles muda. Deixe vazio para ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}';
	@override String get advancedSettings => 'Configurações Avançadas';
	@override String get placeholderSwr => 'Leitura de SWR';
	@override String get placeholderSwrDescription => 'O que este rádio reporta no medidor de SWR durante a transmissão. Acima de 1,8 o painel avisa.';
	@override String get placeholderSwrInvalid => 'Um número, 1 ou mais';
	@override String get keyerNone => 'Nenhum';
	@override String get cwDialect => 'Dialeto de manipulação CW';
	@override String get cwDialectDescription => 'Que forma do comando KY este rádio aceita. Nenhum significa sem manipulação CW por CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, preenchido até 24)';
	@override String get cwDialectElecraft => 'Elecraft (texto KY)';
	@override String get voiceDialect => 'Dialeto do manipulador de voz';
	@override String get voiceDialectDescription => 'Como este rádio reproduz as memórias de voz por CAT. Nenhum significa sem memórias de voz por CAT. Com um dialeto e sem número, aplica-se o número predefinido do dialeto.';
	@override String get voiceDialectPb => 'Kenwood (PB, estilo TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB e DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (toques de botões)';
	@override String get placeholderDiagnostic => 'Simulado';
	@override String get placeholderWholeNumberInvalid => 'Tem de ser um número inteiro, 0 ou mais';
	@override String get placeholderFreqInvalid => 'Tem de ser uma frequência em kHz, maior que zero';
	@override String get placeholderModeInvalid => 'Tem de ser o nome de um modo, por ex. USB, CW, FT8';
	@override String get switchLayout => 'Disposição';
	@override String get switchLayoutDescription => 'Em que lado do comutador estão ligados os seus rádios.';
	@override String get switchLayoutRequired => 'Escolha como o comutador está ligado';
	@override String switchCommandRefused({required Object command, required Object code}) => 'O comutador recusou "${command}" (erro ${code})';
	@override String get switchBusyTransmitting => 'Essa porta está a transmitir — antena não alterada';
	@override String get switchNoAntenna => 'Nenhuma';
	@override String switchAntennaFor({required Object port}) => 'Antena na porta ${port}';
	@override String get switchAntennaForDescription => 'Qual das suas antenas está ligada a esta porta do comutador.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} Antenas, ${radios} Rádios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} Antenas, 1 Rádio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 Antena, ${radios} Rádios';
	@override String get switchCommonPort => 'Comum';
	@override String get dcnAddress => 'Endereço do dispositivo';
	@override String get dcnAddressDescription => 'O endereço definido nos interruptores DIP do módulo. Um módulo de relé coaxial sai de fábrica com 2.';
	@override String get dcnAddressRequired => 'Tem de ser um endereço de dispositivo de 1 a 99';
	@override String switchPortLabel({required Object port}) => 'Porta ${port}';
	@override String get switchPortAutoHint => 'segue os dados de banda';
	@override String get switchPortTransmittingHint => 'a transmitir — não pode ser alterada agora';
	@override String get switchCurrentStateHeader => 'Estado Atual';
	@override String get switchCurrentStateDescription => 'Em que antena está cada porta de rádio neste momento. As alterações têm efeito imediato.';
	@override String get switchWiringHeader => 'Ligações';
	@override String get switchPortInhibitedHint => 'transmissão inibida';
	@override String get configUnreadable => 'Não foi possível ler as configurações guardadas deste rádio. Abra as configurações e introduza-as novamente, ou remova-o e volte a adicioná-lo.';
	@override String get autoConnectHeld => 'O HaLo deixou de responder da última vez que se ligou a este rádio, por isso desta vez não se ligou sozinho. Prima Ligar para tentar novamente.';
}

// Path: settings.offlineData
class Translations$settings$offlineData$pt extends Translations$settings$offlineData$en {
	Translations$settings$offlineData$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Dados Offline';
	@override String get noFiles => 'Nenhum ficheiro de dados';
	@override String get noFilesDescription => 'Ative extensões de atividades ou de pesquisa para descarregar aqui os seus dados offline.';
	@override String get refresh => 'Atualizar';
	@override String get refreshing => 'A atualizar…';
	@override String get updateAll => 'Atualizar Todos';
	@override String get updatingAll => 'A atualizar todos os ficheiros de dados…';
	@override String get neverDownloaded => 'Nunca descarregado';
	@override String get updatedJustNow => 'Atualizado agora mesmo';
	@override String updatedDaysAgo({required Object days}) => 'Atualizado há ${days}d';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Atualizado há ${days}d ${hours}h';
	@override String updatedHoursAgo({required Object hours}) => 'Atualizado há ${hours}h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Atualizado há ${hours}h ${minutes}m';
	@override String updatedMinutesAgo({required Object minutes}) => 'Atualizado há ${minutes}m';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'O último download tinha apenas ${imported} de ${existing} registos e não foi usado. Atualize para o aceitar.';
	@override String get extensionsSection => 'Extensões';
}

// Path: settings.profiles
class Translations$settings$profiles$pt extends Translations$settings$profiles$en {
	Translations$settings$profiles$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Não definido';
	@override String get personalInfo => 'Informações Pessoais';
	@override String get personalInfoNote => 'Pode ser incluído nos registos gerados quando for relevante para submissões';
	@override String get name => 'Nome';
	@override String get email => 'E-mail';
	@override String get club => 'Clube';
	@override String get arrlSection => 'Secção ARRL';
	@override String get racSection => 'Secção RAC';
	@override String get section => 'Secção';
}

// Path: settings.search
class Translations$settings$search$pt extends Translations$settings$search$en {
	Translations$settings$search$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Limpar';
	@override String get hint => 'Procurar preferências';
}

// Path: settings.developer
class Translations$settings$developer$pt extends Translations$settings$developer$en {
	Translations$settings$developer$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Ativar avisos de desenvolvimento, registos de depuração e ferramentas.';
	@override String get experiments => 'Experiências';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ativada',
		other: '${count} ativadas',
	);
	@override String get patchTrack => 'Canal de Code Push';
	@override String get patchTrackDescription => 'Que anel de code push remoto este dispositivo segue. Anéis mais aventureiros recebem correções mais cedo, menos testadas. Os code pushes aplicam-se no próximo arranque.';
	@override String get trackStable => 'Estável';
	@override String get trackUnstable => 'Instável';
	@override String get trackBleeding => 'Vanguarda';
	@override String checkingTrack({required Object track}) => 'A procurar um code push em "${track}"…';
	@override String get patchDownloaded => 'Code push descarregado — reinicie a app para o aplicar.';
	@override String noNewPatch({required Object track}) => 'Nenhum code push novo em "${track}".';
	@override String get noPatchInstalled => 'Nenhum code push instalado — a correr o binário da versão.';
	@override String runningPatch({required Object patch}) => 'A correr o code push #${patch}.';
	@override String get deepLinks => 'Deep links';
	@override String get registerUrlSchemes => 'Registar esquemas de URL';
	@override String get registerUrlSchemesDescription => 'Permitir que ligações com.ham2k:// abram esta cópia da app';
	@override String get registerUrlSchemesDone => 'Esta cópia abre agora ligações com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Não foi possível registar: ${error}';
	@override String get systemInformation => 'Informações do Sistema';
	@override String get appVersion => 'Versão da App';
	@override String get dataFolder => 'Pasta de Dados';
	@override String get loading => '(a carregar…)';
	@override String get panelLoadFailed => 'Não foi possível carregar este painel de configurações.';
	@override String get extDevServer => 'Servidor de Desenvolvimento de Extensões';
	@override String get extensionSettings => 'Configurações de Extensões';
	@override String get extDevServerDescription => 'Carregar extensões de um servidor de desenvolvimento na sua rede em vez das integradas na app, e recarregá-las sempre que guardar.';
	@override String get extDevServerAddress => 'Endereço do servidor';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Ligar';
	@override String get extDevServerDisconnect => 'Desligar';
	@override String get extDevServerConnecting => 'A ligar…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'A servir ${count} extensão: ${keys}',
		other: 'A servir ${count} extensões: ${keys}',
	);
	@override String get extDevServerDisconnected => 'Não ligado';
	@override String get extDevServerReconnect => 'Voltar a ligar no arranque';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Último recarregamento: ${key} às ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} extensão com falha na compilação',
		other: '${count} extensões com falha na compilação',
	);
	@override String get catalog => 'Catálogo de Extensões';
	@override String get catalogDescription => 'Ler o catálogo a partir de outro servidor — um local, enquanto trabalha no próprio catálogo. Vazio significa catalog.ham2k.net.';
	@override String get catalogAddress => 'Endereço do catálogo';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Canais de Pesquisa do Catálogo';
	@override String get catalogSearchStable => 'Só Estável';
	@override String get catalogSearchUnstable => 'Instável ou melhor';
	@override String get catalogSearchBleeding => 'Vanguarda ou melhor';
}

// Path: settings.about
class Translations$settings$about$pt extends Translations$settings$about$en {
	Translations$settings$about$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Avisos e Mensagens';
	@override String get noticesDescription => 'Anúncios e mensagens de estado';
	@override String get releaseNotes => 'Notas de Versão';
	@override String get copiedVersion => 'Detalhes da versão copiados para a área de transferência';
}

// Path: settings.panels
class Translations$settings$panels$pt extends Translations$settings$panels$en {
	Translations$settings$panels$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Preferências da Aplicação';
	@override String get settingsDescription => 'Faça a app funcionar como quer';
	@override String get commonSettings => 'Preferências Comuns';
	@override String get syncDescription => 'Faça cópia de segurança e sincronize os seus registos entre dispositivos';
	@override String get accountsDescription => 'Credenciais de serviços, dados offline e mais';
	@override String get extensions => 'Extensões e Funcionalidades';
	@override String get extensionsDescription => 'Atividades, Concursos, Painéis e mais funcionalidades';
	@override String get profilesDescription => 'Indicativo do operador e perfil da estação';
	@override String get stationProfiles => 'Perfis de Estação';
	@override String get developerSettings => 'Configurações do Desenvolvedor';
	@override String get developerSettingsDescription => 'Ferramentas de depuração e desenvolvimento';
	@override String get about => 'Sobre';
	@override String get aboutDescription => 'Versão, créditos e informação legal';
	@override String get unavailableTitle => 'Algumas configurações estão indisponíveis';
	@override String get unavailableText => 'As extensões não arrancaram, por isso faltam as configurações que elas fornecem.';
	@override String get station => 'Configuração da Estação';
	@override String get stationDescription => 'Controlo CAT e mais opções';
	@override String get peers => 'Dispositivos Pares';
	@override String get peersDescription => 'Ligar a outros dispositivos próximos';
}

// Path: settings.gridPrecisionOpts
class Translations$settings$gridPrecisionOpts$pt extends Translations$settings$gridPrecisionOpts$en {
	Translations$settings$gridPrecisionOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos (FN31pr)';
	@override String get eight => '8 dígitos (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class Translations$settings$gridPrecisionDescription$pt extends Translations$settings$gridPrecisionDescription$en {
	Translations$settings$gridPrecisionDescription$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get six => '6 dígitos';
	@override String get eight => '8 dígitos';
}

// Path: home.logs.columns
class Translations$home$logs$columns$pt extends Translations$home$logs$columns$en {
	Translations$home$logs$columns$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

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
class Translations$home$logs$panels$pt extends Translations$home$logs$panels$en {
	Translations$home$logs$panels$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Registo de QSOs';
	@override String get qsosDescription => 'Os QSOs do indicativo selecionado, em todas as operações.';
	@override String get info => 'Info';
	@override String get infoDescription => 'Total de QSOs, ou a pesquisa do indicativo do QSO selecionado.';
	@override String get map => 'Mapa';
	@override String get mapDescription => 'A localização do QSO selecionado.';
}

// Path: home.logs.import
class Translations$home$logs$import$pt extends Translations$home$logs$import$en {
	Translations$home$logs$import$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicativos: ${calls}';
	@override String get skippedOne => 'Não foi possível ler 1 registo';
	@override String skippedOther({required Object count}) => 'Não foi possível ler ${count} registos';
	@override String get readingTitle => 'A ler o ficheiro ADIF…';
	@override String get checkingTitle => 'A procurar duplicados…';
	@override String get importingTitle => 'A importar QSOs…';
	@override String readingDetail({required Object kb}) => '${kb} Kb';
	@override String checkingDetail({required Object done, required Object total}) => '${done} de ${total} verificados';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importados, de ${total}';
}

// Path: operation.layout.panels
class Translations$operation$layout$panels$pt extends Translations$operation$layout$panels$en {
	Translations$operation$layout$panels$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'O registo e os campos de entrada';
	@override String get infoDescription => 'O que sabemos sobre a estação contactada';
	@override String get spotsDescription => 'Spots dos clusters e dos programas de atividade';
	@override String get mapDescription => 'Onde estão os contactos';
	@override String get clockDescription => 'Um mostrador de relógio, em qualquer fuso horário';
	@override String get clockFace => 'Mostrador';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analógico';
	@override String get clockZone => 'Fuso Horário';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Este dispositivo';
	@override String get clockShowSeconds => 'Mostrar segundos';
	@override String get weatherDescription => 'Condições atuais e para as próximas oito horas, onde está a operar';
	@override String get weatherUseOperationLocation => 'Usar a localização da operação';
	@override String get weatherLocation => 'Localização';
	@override String get weatherLocationDescription => 'Um grid (FN31pr) ou lat,lon. Ignorado enquanto \'Usar a localização da operação\' estiver assinalado.';
	@override String get weatherNoLocation => 'Sem localização definida. Indique uma localização nas configurações deste painel, ou coloque-o numa operação que tenha uma.';
	@override String weatherBadLocation({required Object location}) => 'Não foi possível ler a localização ${location}. Use um grid como FN31pr, ou 42.36,-71.06.';
	@override String get weatherUnreachable => 'Não foi possível contactar o Open-Meteo — sem rede? Nova tentativa em breve.';
	@override String get weatherUnreadable => 'O Open-Meteo respondeu, mas com algo ilegível. Nova tentativa em breve.';
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
	@override late final Translations$operation$layout$panels$weatherConditions$pt weatherConditions = Translations$operation$layout$panels$weatherConditions$pt.internal(_root);
	@override String get websiteDescription => 'Uma página web à sua escolha, num painel';
	@override String get websiteUrl => 'Endereço';
	@override String get websiteRefresh => 'Atualizar';
	@override String get websiteRefreshNever => 'Nunca';
	@override String get websiteRefresh1 => 'A cada minuto';
	@override String get websiteRefresh5 => 'A cada 5 minutos';
	@override String get websiteRefresh15 => 'A cada 15 minutos';
	@override String get websiteTitle => 'Nome do Painel';
	@override String get websiteRefreshNow => 'Atualizar Agora';
	@override String get websiteNoUrl => 'Ainda sem endereço. Abra as configurações deste painel para escolher uma página.';
	@override String get websiteBadUrl => 'Isso não parece um endereço web. Tem de começar por https://';
	@override String get websiteNotHttps => 'Só endereços https:// podem ser mostrados aqui.';
	@override String get websiteUnsupported => 'Não é possível mostrar páginas web num painel neste sistema.';
	@override String get websiteOpenExternally => 'Abrir no Navegador';
	@override String websiteLoadFailed({required Object reason}) => 'Não foi possível carregar a página: ${reason}';
	@override String get remoteScreenDescription => 'Um ecrã, app ou janela partilhado por outro dos seus dispositivos.';
	@override String get remoteScreenTarget => 'Ecrã';
	@override String get remoteScreenChoose => 'Escolher um ecrã…';
	@override String get remoteScreenPickerTitle => 'Ecrãs Partilhados';
	@override String get remoteScreenPickerEmpty => 'Nenhum dos seus dispositivos está a partilhar um ecrã. Ative Partilhar ecrãs e janelas em Configurações → Dispositivos Pares, no dispositivo que quer ver.';
	@override String get remoteScreenUnset => 'Nenhum ecrã escolhido. Abra as configurações deste painel para escolher um que os seus outros dispositivos estejam a partilhar.';
	@override String get remoteScreenConnecting => 'A ligar…';
	@override String get remoteScreenPeerAway => 'Esse dispositivo não está ligado neste momento.';
	@override String get remoteScreenNotOffered => 'Esse dispositivo deixou de partilhar este ecrã.';
	@override String get remoteScreenNoListener => 'Esse dispositivo não aceita ligações — verifique a firewall dele.';
	@override String get remoteScreenNoLan => 'Os ecrãs só são partilhados pela rede local, não por Bluetooth.';
	@override String get remoteScreenRefused => 'Esse dispositivo recusou partilhar este ecrã.';
	@override String get remoteScreenSettings => 'Configurações do painel';
	@override String get remoteScreenAdjust => 'Ajustar Vista';
	@override String get remoteScreenDetail => 'Detalhe';
	@override String get remoteScreenDetailStandard => 'Normal';
	@override String get remoteScreenDetailHigh => 'Alto';
	@override String get remoteScreenDetailMaximum => 'Máximo';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Aproximar';
	@override String get remoteScreenZoomOut => 'Afastar';
	@override String get remoteScreenStopped => 'Esse ecrã ou janela já não está a ser mostrado.';
	@override String get remoteScreenCaptureFailed => 'Esse dispositivo não conseguiu capturar esse ecrã — pode precisar da permissão de Gravação de Ecrã.';
	@override String get remoteScreenNoAnswer => 'Esse dispositivo não respondeu. Pode não ter a partilha de ecrã ativada.';
	@override String get remoteScreenNoMedia => 'Não foi possível abrir uma ligação para a imagem. Verifique a firewall deste dispositivo.';
	@override String get solarDescription => 'Condições solares e geomagnéticas, com propagação banda a banda';
	@override String get solarUnreachable => 'Não foi possível contactar hamqsl.com — sem rede? Nova tentativa em breve.';
	@override String get solarUnreadable => 'hamqsl.com respondeu, mas sem uma leitura utilizável. Nova tentativa em breve.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Dia';
	@override String get solarBandNight => 'Noite';
	@override String get solarBandGood => 'Boa';
	@override String get solarBandFair => 'Razoável';
	@override String get solarBandPoor => 'Fraca';
	@override String solarSources({required Object primary, required Object secondary}) => 'Fontes: ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'A ligação está com dificuldades — a saltar fotogramas.';
	@override String get remoteScreenStalled => 'Os fotogramas deixaram de chegar — esta ligação pode ser demasiado lenta.';
	@override String get radioDescription => 'O painel frontal de um rádio — frequência, modo e potência, sob controlo CAT';
	@override String get radioStyle => 'Estilo';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderno';
	@override String get radioRadio => 'Rádio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — nenhum rádio designado';
	@override String get radioNoRadio => 'Nenhum rádio para mostrar. Escolha um nas configurações deste painel, ou adicione um em Configuração da Estação.';
	@override String get radioNotConfigured => 'Este rádio ainda não está configurado. Escolha a porta ou o endereço em Configuração da Estação.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Rádio não ligado';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Ligar este rádio';
	@override String get radioDisconnect => 'Desligar este rádio';
	@override String get radioStale => 'SEM DADOS';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'SWR';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'SWR alta';
}

// Path: operation.export.compactFileNames
class Translations$operation$export$compactFileNames$pt extends Translations$operation$export$compactFileNames$en {
	Translations$operation$export$compactFileNames$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Usar nomes de ficheiro compactos';
	@override String get descriptionOn => 'Nomes curtos pensados para envio, como N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Nomes legíveis, como 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class Translations$operation$export$includePrivateData$pt extends Translations$operation$export$includePrivateData$en {
	Translations$operation$export$includePrivateData$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Incluir informação privada';
	@override String get descriptionOn => 'Nomes, moradas, e-mails, grids e notas são incluídos';
	@override String get descriptionOff => 'Nomes, moradas, e-mails, grids e notas são omitidos';
	@override String get note => 'A Exportação ADIF Completa inclui sempre tudo';
}

// Path: operation.export.stash
class Translations$operation$export$stash$pt extends Translations$operation$export$stash$en {
	Translations$operation$export$stash$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Adicione primeiro um endereço de e-mail';
	@override String get needsEmailBody => 'O Arquivo de Ficheiros do Ham2K envia os seus ficheiros para o endereço de e-mail da sua conta LoFi, e é com ele que inicia sessão em stash.ham2k.net. A sua conta ainda não tem um confirmado — adicione-o em Configurações › Sincronização na Nuvem.';
	@override String get openSyncSettings => 'Abrir Sincronização na Nuvem';
	@override String get replaceTitle => 'O arquivo recente será substituído';
	@override String replaceBody({required Object name}) => 'Enviou “${name}” há menos de 6 horas e ainda não foi descarregado. As contas gratuitas mantêm um arquivo de cada vez, por isso enviar agora substitui-o.';
	@override String get replaceConfirm => 'Enviar Mesmo Assim';
	@override String get failedTitle => 'Não foi possível enviar para o Arquivo de Ficheiros do Ham2K';
	@override String get sentTitle => 'Enviado para o Arquivo de Ficheiros do Ham2K';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Pode obter este ficheiro em **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.',
		other: 'Pode obter estes ficheiros em **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.',
	);
	@override String get mayHaveArrived => 'O arquivo não respondeu — o ficheiro pode ter chegado na mesma. Verifique stash.ham2k.net antes de enviar novamente';
	@override String get notSent => 'não enviado';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: 'Este ficheiro não chegou:',
		other: 'Estes ${count} ficheiros não chegaram:',
	);
	@override String get emailOffer => 'Ou, para sua conveniência, podemos enviar-lhe um e-mail com uma ligação direta.';
	@override String get emailMe => 'Enviar-me uma Ligação por E-mail';
	@override String get emailSent => 'Enviámos-lhe por e-mail uma ligação para descarregar.';
	@override String emailFailed({required Object error}) => 'Não foi possível enviar o e-mail: ${error}';
	@override String get freeTier => 'As contas gratuitas só podem manter um arquivo de cada vez. Os assinantes podem manter quantos quiserem.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count,
		one: '${count} ficheiro enviado para o Arquivo de Ficheiros do Ham2K (stash.ham2k.net)',
		other: '${count} ficheiros enviados para o Arquivo de Ficheiros do Ham2K (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class Translations$operation$spots$continents$pt extends Translations$operation$spots$continents$en {
	Translations$operation$spots$continents$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get af => 'África';
	@override String get as => 'Ásia';
	@override String get eu => 'Europa';
	@override String get na => 'América do Norte';
	@override String get oc => 'Oceânia';
	@override String get sa => 'América do Sul';
	@override String get an => 'Antártida';
}

// Path: operation.spots.filters
class Translations$operation$spots$filters$pt extends Translations$operation$spots$filters$en {
	Translations$operation$spots$filters$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrar Spots';
	@override String get band => 'Banda';
	@override String get mode => 'Modo';
	@override String get age => 'Idade';
	@override String get sources => 'Fontes';
	@override String get continent => 'Continente';
	@override String get sorting => 'Ordenação';
	@override String get sortByTime => 'Por Hora do Spot';
	@override String get sortByFrequency => 'Por Frequência';
	@override String get groupByBand => 'Agrupar por Banda';
	@override String get groupCallsWithNotes => 'Agrupar Indicativos com Notas';
	@override String get sourceNoReply => 'Sem resposta';
	@override String get sourceError => 'Erro';
}

// Path: operation.spots.logConflict
class Translations$operation$spots$logConflict$pt extends Translations$operation$spots$logConflict$en {
	Translations$operation$spots$logConflict$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'O painel de registo está ocupado';
	@override String get editingBody => 'Está a editar um contacto registado. Registar antes este spot, ou voltar e terminar a edição?';
	@override String get composingBody => 'Começou a introduzir um contacto. Registar antes este spot, ou voltar e terminar o que estava a escrever?';
	@override String get goBack => 'Voltar';
	@override String get clearAndLog => 'Limpar e registar spot';
}

// Path: settings.logging.leftieMode
class Translations$settings$logging$leftieMode$pt extends Translations$settings$logging$leftieMode$en {
	Translations$settings$logging$leftieMode$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modo Canhoto';
	@override String get descriptionOn => 'A usar o esquema para canhotos';
	@override String get descriptionOff => 'A usar o esquema para destros';
}

// Path: settings.logging.countryFlags
class Translations$settings$logging$countryFlags$pt extends Translations$settings$logging$countryFlags$en {
	Translations$settings$logging$countryFlags$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Bandeiras dos Países';
	@override String get dx => 'Mostrar apenas para contactos DX';
	@override String get all => 'Mostrar bandeiras para todos os contactos';
	@override String get none => 'Não mostrar bandeiras';
}

// Path: settings.logging.countryFlagsDescription
class Translations$settings$logging$countryFlagsDescription$pt extends Translations$settings$logging$countryFlagsDescription$en {
	Translations$settings$logging$countryFlagsDescription$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get dx => 'A mostrar bandeiras apenas para contactos DX';
	@override String get all => 'A mostrar bandeiras para todos os contactos';
	@override String get none => 'A não mostrar bandeiras';
}

// Path: settings.logging.suggestDefaultOperator
class Translations$settings$logging$suggestDefaultOperator$pt extends Translations$settings$logging$suggestDefaultOperator$en {
	Translations$settings$logging$suggestDefaultOperator$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Sugerir Operador';
	@override String get descriptionOn => 'A propor o seu indicativo como operador quando uma operação usa um indicativo de estação diferente';
	@override String get descriptionOff => 'A deixar o operador em branco, a menos que o preencha';
}

// Path: settings.logging.showBearing
class Translations$settings$logging$showBearing$pt extends Translations$settings$logging$showBearing$en {
	Translations$settings$logging$showBearing$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar Direção';
	@override String get descriptionOn => 'A mostrar a direção estimada para a estação';
	@override String get descriptionOff => 'A não mostrar informação de direção';
}

// Path: settings.logging.showReverseBearing
class Translations$settings$logging$showReverseBearing$pt extends Translations$settings$logging$showReverseBearing$en {
	Translations$settings$logging$showReverseBearing$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mostrar também direção inversa';
	@override String get descriptionOn => 'A mostrar também a direção a partir da estação, como "45° / 225°"';
	@override String get descriptionOff => 'A mostrar apenas a direção para a estação';
}

// Path: settings.logging.switchSentRcvd
class Translations$settings$logging$switchSentRcvd$pt extends Translations$settings$logging$switchSentRcvd$en {
	Translations$settings$logging$switchSentRcvd$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Trocar a ordem dos relatórios de sinal';
	@override String get sentFirst => 'Enviado primeiro, Recebido em segundo';
	@override String get rcvdFirst => 'Recebido primeiro, Enviado em segundo';
}

// Path: settings.logging.jumpAfterRST
class Translations$settings$logging$jumpAfterRST$pt extends Translations$settings$logging$jumpAfterRST$en {
	Translations$settings$logging$jumpAfterRST$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Saltar para o campo seguinte após o RST';
	@override String get descriptionOn => 'A saltar depois de introduzido o RST';
	@override String get descriptionOff => 'A não saltar automaticamente';
}

// Path: settings.logging.defaultReport
class Translations$settings$logging$defaultReport$pt extends Translations$settings$logging$defaultReport$en {
	Translations$settings$logging$defaultReport$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Relatório predefinido — Telefone';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio em SSB, FM ou AM';
}

// Path: settings.logging.defaultReportCW
class Translations$settings$logging$defaultReportCW$pt extends Translations$settings$logging$defaultReportCW$en {
	Translations$settings$logging$defaultReportCW$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Relatório predefinido — CW e dados';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio em CW, RTTY e outros modos de dados';
}

// Path: settings.logging.defaultReportFT8
class Translations$settings$logging$defaultReportFT8$pt extends Translations$settings$logging$defaultReportFT8$en {
	Translations$settings$logging$defaultReportFT8$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Relatório predefinido — FT8 e FT4';
	@override String get description => 'Usado quando Enviado ou Recebido fica vazio nos modos FT';
}

// Path: settings.logging.numbersRow
class Translations$settings$logging$numbersRow$pt extends Translations$settings$logging$numbersRow$en {
	Translations$settings$logging$numbersRow$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Linha de Números';
	@override String get description => 'Mostrar uma linha de teclas numéricas por cima do teclado durante o registo';
}

// Path: settings.logging.numbersRowExtra
class Translations$settings$logging$numbersRowExtra$pt extends Translations$settings$logging$numbersRowExtra$en {
	Translations$settings$logging$numbersRowExtra$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Tecla de barra e ponto';
	@override String get description => 'Adiciona uma tecla contextual: “/” para indicativos, “.” para números';
}

// Path: settings.logging.numbersRowVibrate
class Translations$settings$logging$numbersRowVibrate$pt extends Translations$settings$logging$numbersRowVibrate$en {
	Translations$settings$logging$numbersRowVibrate$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrar ao premir teclas';
	@override String get description => 'Resposta tátil ao tocar numa tecla numérica';
}

// Path: settings.catServer.protocolOpts
class Translations$settings$catServer$protocolOpts$pt extends Translations$settings$catServer$protocolOpts$en {
	Translations$settings$catServer$protocolOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get off => 'Desativado';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class Translations$settings$radio$units$pt extends Translations$settings$radio$units$en {
	Translations$settings$radio$units$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class Translations$settings$radio$pttKey$pt extends Translations$settings$radio$pttKey$en {
	Translations$settings$radio$pttKey$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Controlar o PTT com [\']';
	@override String get descriptionOn => 'Nos modos de Telefone, [\'] põe o rádio em emissão e [\'] novamente tira-o. Sai de emissão sozinho ao fim de um minuto.';
	@override String get descriptionOff => 'A tecla [\'] não põe o rádio em emissão.';
	@override String get pill => 'TX';
	@override String get transmitting => 'A transmitir';
}

// Path: settings.radio.smartVfoSnap
class Translations$settings$radio$smartVfoSnap$pt extends Translations$settings$radio$smartVfoSnap$en {
	Translations$settings$radio$smartVfoSnap$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arredondamento Inteligente do VFO';
	@override String get descriptionOn => 'Quando para de rodar o botão, arredonda a frequência para um passo sensato. Só nos modos de voz.';
	@override String get descriptionOff => 'Fica exatamente onde sintonizou.';
}

// Path: settings.radio.snapDebounce
class Translations$settings$radio$snapDebounce$pt extends Translations$settings$radio$snapDebounce$en {
	Translations$settings$radio$snapDebounce$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arredondamento: Tempo de espera';
	@override String get description => 'Quanto tempo o botão tem de estar parado antes de a frequência ser arredondada. Mais curto parece imediato; mais longo dá margem a um movimento lento.';
}

// Path: settings.radio.snapLongMove
class Translations$settings$radio$snapLongMove$pt extends Translations$settings$radio$snapLongMove$en {
	Translations$settings$radio$snapLongMove$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arredondamento: Movimento longo';
	@override String get description => 'Mova pelo menos isto e a frequência é arredondada a um kHz inteiro, por mais devagar que tenha terminado.';
}

// Path: settings.radio.snapMinMove
class Translations$settings$radio$snapMinMove$pt extends Translations$settings$radio$snapMinMove$en {
	Translations$settings$radio$snapMinMove$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arredondamento: Movimento mínimo';
	@override String get description => 'Mova menos do que isto e a frequência não é arredondada, para não mexer na sintonia fina.';
}

// Path: settings.radio.snapMinSpeed
class Translations$settings$radio$snapMinSpeed$pt extends Translations$settings$radio$snapMinSpeed$en {
	Translations$settings$radio$snapMinSpeed$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arredondamento: Movimento mais lento';
	@override String get description => 'Rode o botão mais devagar do que isto e a frequência não é arredondada, a menos que tenha sido um movimento longo.';
}

// Path: settings.radio.enterSends
class Translations$settings$radio$enterSends$pt extends Translations$settings$radio$enterSends$en {
	Translations$settings$radio$enterSends$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM Desl.';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Enter envia mensagens';
	@override String get off => 'Desligado';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Enter Envia Mensagens: ${state}. Toque para alterar.';
}

// Path: settings.radio.keyerSpeed
class Translations$settings$radio$keyerSpeed$pt extends Translations$settings$radio$keyerSpeed$en {
	Translations$settings$radio$keyerSpeed$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Velocidade do manipulador';
	@override String get unit => 'PPM';
	@override String pill({required Object wpm}) => '${wpm} ppm';
	@override String get pillUnknown => '– ppm';
}

// Path: settings.radio.cwMessages
class Translations$settings$radio$cwMessages$pt extends Translations$settings$radio$cwMessages$en {
	Translations$settings$radio$cwMessages$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensagens do Manipulador CW';
	@override String get notSupported => 'O rádio atual não suporta manipulação CW';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Mensagem (${n})';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta de F${n}';
	@override String get details => 'Detalhes';
	@override String get empty => '(vazia)';
	@override String get sets => 'Conjunto de Mensagens';
	@override String get newSet => 'Novo Conjunto';
	@override String get renameSet => 'Mudar o Nome do Conjunto';
	@override String get deleteSet => 'Eliminar Conjunto';
	@override String get newSetName => 'Nome';
	@override String get setDefault => 'Predefinido';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Mensagens ESM';
	@override String get setSaved => 'As Minhas Mensagens';
	@override String get repeat => 'Repetir Mensagem #1';
	@override String get repeatOff => 'Não';
	@override String repeatAfter({required Object n}) => 'Após ${n} segundos';
	@override String get repeatWait => 'A repetir';
	@override String get keyboard => 'Escrever para enviar';
	@override String get keyboardField => 'Escrever para enviar';
	@override String get closeArea => 'Fechar a área do manipulador';
	@override String get help => 'Ajuda';
	@override String get helpTitle => 'Escrever Mensagens CW';
	@override String get helpIntro => 'As mensagens podem usar modelos com os seguintes valores:';
	@override String get helpOpCall => 'O seu indicativo';
	@override String get helpQsoCall => 'O indicativo deles — numa pilha //, o indicativo que será registado';
	@override String get helpQsoFullCall => 'O indicativo deles, se houver um indicativo válido; vazio para um parcial';
	@override String get helpQsoPartial => 'Um indicativo parcial; vazio se houver um indicativo completo válido';
	@override String get helpQsoNextCall => 'Numa pilha //, o indicativo que será selecionado para registar a seguir, se houver um indicativo completo válido';
	@override String get helpQsoNextPartial => 'Numa pilha //, o parcial seguinte depois de registar o contacto atual';
	@override String get helpQsoName => 'O nome próprio deles, tal como escrito ou, se não, da pesquisa';
	@override String get helpQsoState => 'O estado deles, tal como escrito ou, se não, da pesquisa';
	@override String get helpKeyerMsg => 'A mensagem 1 tal como seria enviada, dentro de outra mensagem. Válido para as mensagens 1 a 8';
	@override String get helpQsoRst => 'O relatório que está a enviar';
	@override String get helpQsoSerial => 'O seu número de série, num concurso que o envie';
	@override String get helpPad => 'Preenche com zeros até esse número de dígitos: 7 é enviado como 007';
	@override String get helpCut => 'Números abreviados, T para 0 e N para 9: 599 é enviado como 5NN';
	@override String get helpCutDigits => 'Escolhe os dígitos a abreviar, entre aspas — 0 é T, 1 é A, 5 é E, 9 é N';
	@override String get helpFullExample => 'Exemplo completo:';
	@override String get helpExample => 'Envia W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Com Enter Envia Mensagens ligado, o Enter emite as mensagens pela sua tecla de função, como faz o N1MM. O conjunto Mensagens ESM começa com estas:';
	@override String get helpEsmCq => 'Em Run, Enter com o campo do indicativo vazio chama CQ';
	@override String get helpEsmExchange => 'O seu câmbio: depois do indicativo deles em Run, depois de eles responderem em S&P';
	@override String get helpEsmThanks => 'Agradecimento, depois de o contacto ser registado: os seus marcadores referem-se ao próximo contacto, não a este';
	@override String get helpEsmMyCall => 'Em S&P, o seu indicativo para a estação a que está a responder';
	@override String get helpEsmHisCall => 'Em Run, o indicativo deles antes do seu câmbio';
	@override String get helpEsmAgain => 'Pede novamente quando nada do câmbio deles foi copiado';
	@override String get helpEsmStackThanks => 'F3 sugerido para pilhas //: o TU sai depois de o contacto ser registado, por isso agradece, depois chama a próxima estação da pilha e envia o seu câmbio, ou pede de volta um parcial (TU KR?); sem nada na pilha, só TU';
}

// Path: settings.radio.voiceMessages
class Translations$settings$radio$voiceMessages$pt extends Translations$settings$radio$voiceMessages$en {
	Translations$settings$radio$voiceMessages$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mensagens de Voz';
	@override String get notSupported => 'O rádio atual não suporta mensagens de voz';
	@override String get description => 'Usa as memórias de voz do rádio';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Memória de voz (${n})';
	@override String get labelField => 'Etiqueta';
	@override String labelKey({required Object n}) => 'Etiqueta da memória de voz ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Vazia';
	@override String get notMeasured => 'Duração desconhecida';
	@override String get playButton => 'Reproduzir';
	@override String get recordButton => 'Gravar';
	@override String get stopButton => 'Parar';
	@override String get repeat => 'Repetir Mensagem #1';
	@override String get repeatOff => 'Não';
	@override String repeatAfter({required Object n}) => 'Após ${n} segundos';
	@override String recordHelpTitle({required Object model}) => 'Notas sobre o ${model}:';
	@override String namedOnDevice({required Object device}) => 'Estas memórias estão no rádio de ${device}. Os nomes e durações pertencem a esse dispositivo.';
	@override String get namedOnRadio => 'Guardado no rádio, onde os outros clientes também o veem.';
	@override String get recordHelpYaesuDvs => 'Aguarde o indicador [REC] no rádio, depois mantenha premido o botão PTT e grave a mensagem. Termine-a premindo o botão PARAR aqui na app antes de largar o PTT, para evitar cliques indesejados.';
	@override String get recordHelpFt891 => 'Aguarde que o indicador [REC] pisque pelo menos quatro vezes, depois mantenha premido o botão PTT e grave a mensagem. Termine-a premindo o botão PARAR aqui na app antes de largar o PTT, para evitar cliques indesejados.';
	@override String get pill => 'Voz';
	@override String play({required Object n}) => 'Reproduzir memória ${n}';
	@override String get stop => 'Parar';
	@override String record({required Object n}) => 'Gravar memória ${n}';
	@override String get stopRecording => 'Parar gravação';
	@override String get playing => 'A reproduzir…';
	@override String get recording => 'A gravar…';
	@override String playingMemory({required Object label}) => 'A reproduzir ${label}';
	@override String recordingMemory({required Object label}) => 'A gravar ${label}';
	@override String get doubtful => 'O rádio reproduziu-a? Reportou logo que estava inativo.';
	@override String get recordOnRadio => 'Tem de gravar as memórias no próprio rádio.';
}

// Path: settings.radio.avoidZeroBeat
class Translations$settings$radio$avoidZeroBeat$pt extends Translations$settings$radio$avoidZeroBeat$en {
	Translations$settings$radio$avoidZeroBeat$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Evitar Batimento Zero nos Spots';
	@override String get descriptionOn => 'Com um rádio ligado, sintoniza alguns Hz ao lado de um spot de CW, para que nem todos os que lhe respondem chamem na mesma nota.';
	@override String get descriptionOff => 'Sintoniza exatamente a frequência anunciada.';
}

// Path: settings.radio.zeroBeatRange
class Translations$settings$radio$zeroBeatRange$pt extends Translations$settings$radio$zeroBeatRange$en {
	Translations$settings$radio$zeroBeatRange$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Batimento Zero: Margem a evitar';
	@override String get description => 'A que distância da frequência anunciada sintonizar, para qualquer lado. O desvio nunca fica perto de zero — isso voltaria a ser um batimento zero.';
}

// Path: settings.map.style
class Translations$settings$map$style$pt extends Translations$settings$map$style$en {
	Translations$settings$map$style$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Estilo do Mapa';
}

// Path: settings.map.styleOpts
class Translations$settings$map$styleOpts$pt extends Translations$settings$map$styleOpts$en {
	Translations$settings$map$styleOpts$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automático';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class Translations$settings$privacy$shareAppData$pt extends Translations$settings$privacy$shareAppData$en {
	Translations$settings$privacy$shareAppData$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partilhar dados de uso da app';
	@override String get descriptionOn => 'A ajudar-nos a melhorar a app partilhando dados de uso, configuração, falhas e desempenho';
	@override String get descriptionOff => 'A manter privados os dados de uso da app.\nA equipa Ham2K não poderá detetar falhas ou outros problemas.';
}

// Path: settings.privacy.shareOpData
class Translations$settings$privacy$shareOpData$pt extends Translations$settings$privacy$shareOpData$en {
	Translations$settings$privacy$shareOpData$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partilhar dados de operação';
	@override String get descriptionOn => 'A partilhar alguns dados de operação publicamente e com outros utilizadores';
	@override String get descriptionOff => 'A manter os dados de operação privados';
}

// Path: settings.station.models
class Translations$settings$station$models$pt extends Translations$settings$station$models$en {
	Translations$settings$station$models$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

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
	@override String get rigctldNodeName => 'O Meu Rádio (via rigctld)';
	@override String get flrig => 'Rádio controlado via flrig';
	@override String get flrigNodeName => 'O Meu Rádio (via flrig)';
	@override String get hrd => 'Rádio controlado via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'O Meu Rádio (via HRD)';
	@override String get n3fjp => 'Rádio controlado via N3FJP';
	@override String get n3fjpNodeName => 'O Meu Rádio (via N3FJP)';
	@override String get commander => 'Rádio controlado via DXLab Commander';
	@override String get commanderNodeName => 'O Meu Rádio (via Commander)';
	@override String get antenna => 'Antena';
	@override String get key => 'Chave CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Rádio Genérico (Marcador)';
	@override String get placeholderRadioNodeName => 'O Meu Rádio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Comutador Coaxial Sierra Radio CX-1';
}

// Path: settings.station.transports
class Translations$settings$station$transports$pt extends Translations$settings$station$transports$en {
	Translations$settings$station$transports$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get network => 'Rede/WiFi';
	@override String get usbSerial => 'USB Série';
	@override String get wifi => 'Rede/WiFi';
	@override String get bluetoothSerial => 'Bluetooth Série';
	@override String get placeholder => 'Marcador';
}

// Path: settings.station.antennaTypes
class Translations$settings$station$antennaTypes$pt extends Translations$settings$station$antennaTypes$en {
	Translations$settings$station$antennaTypes$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipolo';
	@override String get vertical => 'Vertical';
	@override String get yagiBeam => 'Yagi / Direcional';
	@override String get loop => 'Loop';
	@override String get longWire => 'Fio Longo / EFHW';
	@override String get other => 'Outra';
}

// Path: settings.station.keyTypes
class Translations$settings$station$keyTypes$pt extends Translations$settings$station$keyTypes$en {
	Translations$settings$station$keyTypes$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Chave Vertical';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semiautomática mecânica)';
	@override String get fullyAutomatic => 'Manipulador totalmente automático';
	@override String get singlePaddle => 'Paddle Simples';
	@override String get dualPaddle => 'Paddle Duplo';
	@override String get computerDriven => 'Controlada por Computador';
	@override String get other => 'Outra';
}

// Path: operation.layout.panels.weatherConditions
class Translations$operation$layout$panels$weatherConditions$pt extends Translations$operation$layout$panels$weatherConditions$en {
	Translations$operation$layout$panels$weatherConditions$pt.internal(TranslationsPt root) : this._root = root, super.internal(root);

	final TranslationsPt _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Desconhecido';
	@override String get sunny => 'Sol';
	@override String get clear => 'Céu limpo';
	@override String get mainlySunny => 'Predominantemente Sol';
	@override String get mainlyClear => 'Predominantemente Limpo';
	@override String get partlyCloudy => 'Parcialmente Nublado';
	@override String get cloudy => 'Nublado';
	@override String get foggy => 'Nevoeiro';
	@override String get rimeFog => 'Nevoeiro com Geada';
	@override String get lightDrizzle => 'Chuvisco Fraco';
	@override String get drizzle => 'Chuvisco';
	@override String get heavyDrizzle => 'Chuvisco Forte';
	@override String get lightFreezingDrizzle => 'Chuvisco Gelado Fraco';
	@override String get freezingDrizzle => 'Chuvisco Gelado';
	@override String get lightRain => 'Chuva Fraca';
	@override String get rain => 'Chuva';
	@override String get heavyRain => 'Chuva Forte';
	@override String get lightFreezingRain => 'Chuva Gelada Fraca';
	@override String get freezingRain => 'Chuva Gelada';
	@override String get lightSnow => 'Neve Fraca';
	@override String get snow => 'Neve';
	@override String get heavySnow => 'Neve Forte';
	@override String get snowGrains => 'Grãos de Neve';
	@override String get lightShowers => 'Aguaceiros Fracos';
	@override String get showers => 'Aguaceiros';
	@override String get heavyShowers => 'Aguaceiros Fortes';
	@override String get lightSnowShowers => 'Aguaceiros de Neve Fracos';
	@override String get snowShowers => 'Aguaceiros de Neve';
	@override String get thunderstorm => 'Trovoada';
	@override String get lightThunderstormsWithHail => 'Trovoada Fraca com Granizo';
	@override String get thunderstormWithHail => 'Trovoada com Granizo';
}

/// The flat map containing all translations for locale <pt>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsPt {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Guardar',
			'common.ok' => 'OK',
			'common.cancel' => 'Cancelar',
			'common.delete' => 'Eliminar',
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
			'onboarding.welcomeBody' => 'Temos algumas perguntas para nos ajudar a adaptar a app às suas necessidades.',
			'onboarding.skip' => 'Saltar',
			'onboarding.kContinue' => 'Continuar',
			'onboarding.back' => 'Voltar',
			'onboarding.next' => 'Seguinte',
			'onboarding.done' => 'Concluído',
			'onboarding.callsignTitle' => 'Qual é o seu indicativo?',
			'onboarding.callsignBody' => 'Precisa de uma licença de radioamador para que esta app lhe seja útil',
			'onboarding.callsignLabel' => 'Indicativo do Operador',
			'onboarding.alreadyHaveAccount' => 'Já tem uma conta?',
			'onboarding.foundSiblingTitle' => 'Vincular uma conta existente?',
			'onboarding.foundSiblingBody' => ({required Object app}) => 'Encontrámos ${app} neste dispositivo. Vincule esta app à mesma conta e o seu indicativo e registos passam para cá.',
			'onboarding.foundPoloBody' => 'Encontrámos uma versão anterior do Ham2K Portable Logger neste dispositivo. Vincule esta app à mesma conta e o seu indicativo e registos passam para cá.',
			'onboarding.foundSiblingsBody' => 'Encontrámos outras apps Ham2K neste dispositivo. Vincule esta app a uma das suas contas e o seu indicativo e registos passam para cá.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Vincular com ${app}',
			'onboarding.linkWithPolo' => 'Vincular com a conta da versão anterior',
			'onboarding.setUpFresh' => 'Configurar de raiz',
			'onboarding.activitiesTitle' => 'Atividades Favoritas',
			'onboarding.activitiesBody' => 'Tem interesse em algum destes programas de ativação populares?',
			'onboarding.activitiesFooter' => '(Encontra mais opções nas Configurações)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Dados e Privacidade',
			'onboarding.consentUsageBody' => 'Para nos ajudar a melhorar a app, gostaríamos de recolher dados de desempenho, falhas e utilização da app.',
			'onboarding.consentUsageLabel' => 'Partilhar dados de uso da app',
			'onboarding.consentOperationBody' => 'Algumas funcionalidades podem envolver partilhar os seus dados de operação com outros utilizadores. Pode desativar a qualquer momento.',
			'onboarding.consentOperationLabel' => 'Partilhar Dados de Operação',
			'onboarding.finishingSetup' => 'A concluir a configuração — a descarregar dados de referência…',
			'startScreen.credits' => 'por KI2D e amigos',
			'testerOverlay.tape' => 'CUIDADO: EM CONSTRUÇÃO',
			'testerOverlay.warningTitle' => 'Esta app está em desenvolvimento',
			'testerOverlay.warningBody' => 'A maioria das funcionalidades tem piso irregular e há obstáculos por todo o lado. Procure atualizações com regularidade.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Novidades na build ${build}',
			'testerOverlay.thanks' => 'Obrigado por arriscar o seu registo para nos ajudar a melhorar esta app!',
			'extensionsPanel.categoryActivity' => 'Atividades',
			'extensionsPanel.categoryContest' => 'Concursos',
			'extensionsPanel.categoryLookup' => 'Pesquisas de Indicativo',
			'extensionsPanel.categorySpots' => 'Fontes de Spot',
			'extensionsPanel.categoryDashboard' => 'Painéis',
			'extensionsPanel.categoryOther' => 'Outras Extensões',
			'extensionsPanel.searchHint' => 'Procurar extensões',
			'extensionsPanel.applying' => 'A ativar as alterações às extensões, isto pode demorar um pouco…',
			'extensionsPanel.noMatches' => 'Nenhuma extensão corresponde à pesquisa',
			'extensionsPanel.installFromFile' => 'Instalar a partir de ficheiro…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Versão ${version}',
			'extensionsPanel.canReach' => 'Esta extensão pode contactar',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, através de uma ligação ativa',
			'extensionsPanel.canHoldLocalConnection' => 'Dispositivos na sua rede local, através de uma ligação ativa',
			'extensionsPanel.canUseLocation' => 'A sua localização',
			'extensionsPanel.canReadRadio' => 'O seu rádio, para ler a frequência e o modo',
			'extensionsPanel.canControlRadio' => 'O seu rádio, para o controlar e transmitir com ele — sintonia, potência, CW, memórias de voz e PTT',
			'extensionsPanel.canSetUserAgent' => 'Identificar-se perante os servidores com o seu próprio nome',
			'extensionsPanel.noCapabilities' => 'Não pede nada fora da app.',
			'extensionsPanel.sandboxNote' => 'As extensões correm isoladas: sem acesso aos seus ficheiros e sem rede além do que está aqui indicado.',
			'extensionsPanel.installAction' => 'Instalar',
			'extensionsPanel.updateAction' => 'Atualizar',
			'extensionsPanel.installFailed' => 'Não foi possível instalar essa extensão',
			'extensionsPanel.installedBadge' => 'Instalada',
			'extensionsPanel.uninstallAction' => 'Remover',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Remover ${name}?',
			'extensionsPanel.uninstallBody' => 'Esta extensão e as suas configurações serão removidas. Os seus registos ficam intactos.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} instalada',
			'extensionsPanel.installDownloading' => 'A descarregar…',
			'extensionsPanel.installWaiting' => 'A aguardar instalação…',
			'extensionsPanel.installInstalling' => 'A instalar…',
			'extensionsPanel.installAwaitingApproval' => 'A aguardar a sua aprovação…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} já está a ser instalada.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Atualizada para ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'A instalação de ${name} não terminou. Pode ser preciso instalá-la novamente.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Não foi possível remover ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Descarregada de ${source}',
			'extensionsPanel.dropHint' => 'Largue aqui uma extensão .h2kext para a instalar',
			'extensionsPanel.dropOneOnly' => 'Largue uma extensão de cada vez.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} respondeu ${status} para essa extensão.',
			'extensionsPanel.downloadTooLarge' => 'Esse ficheiro é demasiado grande para ser uma extensão.',
			'extensionsPanel.downloadNotSecure' => 'Esse download foi redirecionado para um local inseguro.',
			'extensionsPanel.catalogSection' => 'Catálogo',
			'extensionsPanel.catalogLoading' => 'A carregar o catálogo…',
			'extensionsPanel.catalogUnreachable' => 'Catálogo inacessível',
			'extensionsPanel.builtIn' => 'Integrada',
			'extensionsPanel.updateAvailableBadge' => 'Atualização disponível',
			'extensionsPanel.updatesAvailableTitle' => 'Atualizações de extensões',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Há uma atualização disponível para ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} e mais ${count} precisam de ser atualizadas.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} precisam de ser atualizadas.',
			'extensionsPanel.pendingUpdatesSection' => 'Atualizações Pendentes',
			'extensionsPanel.updateAllAction' => 'Atualizar todas',
			'extensionsPanel.updatesUnderWay' => 'Essas atualizações já estão em curso.',
			'extensionsPanel.updatesNothingLeft' => 'As suas extensões estão atualizadas.',
			'extensionsPanel.updatesNoticeAction' => 'Mais informações',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Atualizar ${count} extensão?', other: 'Atualizar ${count} extensões?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'As suas extensões estão prontas',
			'extensionsPanel.upgradeDoneBody' => 'Passam a vir do catálogo de extensões do Ham2K, por isso podem ser atualizadas sem esperar por uma nova versão da app.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Não atualizadas: ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Não arrancaram: ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Continuam instaladas e assinaladas em Configurações › Extensões — atualizá-las aí volta a ativá-las.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'O catálogo não tem substituto direto para estas, por isso procure lá extensões que cubram o que usava.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Eventos de Parques Estaduais',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} das suas extensões ainda não chegaram. Serão descarregadas na próxima vez que o catálogo de extensões estiver acessível.',
			'extensionsPanel.runtimeDeadBody' => 'As suas extensões não arrancaram. Reiniciar a app deve trazê-las de volta.',
			'extensionsPanel.refusedTitle' => 'Algumas extensões não arrancaram',
			'extensionsPanel.upgradeBusyTitle' => 'Ainda a configurar',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'As suas extensões não estão a correr',
			'extensionsPanel.restoreTitle' => 'Faltam algumas das suas extensões',
			'extensionsPanel.restoreBody' => 'Estas extensões que instalou não estão neste dispositivo. Podemos descarregá-las novamente do catálogo de extensões do Ham2K:',
			'extensionsPanel.restoreFromFile' => 'Instaladas a partir de ficheiro. Instale-as novamente a partir dos ficheiros, ou esqueça-as:',
			'extensionsPanel.restoreOtherCatalog' => 'Instaladas a partir de outro catálogo de extensões, por isso não estão disponíveis aqui:',
			'extensionsPanel.restoreForget' => 'Esquecer',
			'extensionsPanel.restoreInstall' => 'Instalar',
			'extensionsPanel.restoreLater' => 'Mais tarde',
			'extensionsPanel.restoreInstalling' => 'A instalar as suas extensões…',
			'extensionsPanel.restoreDoneTitle' => 'As suas extensões estão de volta',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Reinstaladas: ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Não foi possível instalar algumas extensões',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Não foi possível instalar: ${names}. Voltaremos a oferecê-las na próxima vez que abrir a app.',
			'extensionsPanel.restoreBusyBody' => 'A app ainda está a configurar as suas extensões. Voltaremos a oferecê-las na próxima vez que abrir a app.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Reinstalámo-las, mas as suas extensões não arrancaram. Reiniciar a app deve trazê-las de volta.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} foi retirada',
			'extensionsPanel.revokedBody' => 'O catálogo retirou esta versão, por isso foi desativada.',
			'extensionsPanel.downloadHashMismatch' => 'Esse download não é a extensão que o catálogo descreveu.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'O catálogo não tem a versão ${version} de ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Essa ligação do catálogo não indica uma versão de extensão.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'O catálogo não tem nenhuma versão de ${key} nesse canal.',
			'extensionsPanel.installFromLink' => 'Instalar a partir de ligação',
			'extensionsPanel.unstableReleaseWarning' => 'Esta é uma versão instável, que o seu autor não deu como concluída. Pode comportar-se mal e continuará a receber atualizações instáveis.',
			'extensionsPanel.bleedingReleaseWarning' => 'Esta é uma versão de vanguarda: trabalho em curso que pode falhar ou perder as suas configurações. Continuará a receber atualizações de vanguarda.',
			'extensionsPanel.channelUnstable' => 'Instável',
			'extensionsPanel.channelBleeding' => 'Vanguarda',
			'extensionsPanel.followsUnstable' => 'Recebe versões instáveis e estáveis',
			'extensionsPanel.followsBleeding' => 'Recebe versões de vanguarda, instáveis e estáveis',
			'extensionsPanel.followStableAction' => 'Seguir apenas versões estáveis',
			'extensionsPanel.revokedBadge' => 'Revogada',
			'extensionsPanel.refusedBadge' => 'Não carregou',
			'extensionsPanel.downloadNotHttps' => 'Esse download não usa uma ligação segura.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => 'Não foi possível contactar ${source} para essa extensão.',
			'extensionsPanel.detailsAction' => 'Detalhes',
			'extensionsPanel.installedFromFile' => 'Instalada a partir de ficheiro',
			'extensionsPanel.detailsWhatItDoes' => 'Fornece suporte para',
			'extensionsPanel.installedPreloaded' => 'Pré-instalada',
			'extensionsPanel.hookAccount' => 'Início de sessão na conta',
			'extensionsPanel.hookCallNotes' => 'Notas de indicativos',
			'extensionsPanel.hookDataFile' => 'Dados offline',
			'extensionsPanel.hookExport' => 'Exportação',
			'extensionsPanel.hookLookup' => 'Pesquisas de indicativo',
			'extensionsPanel.hookScoring' => 'Pontuação',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Caça de ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Ativação de ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '… e mais ${count} extensão', other: '… e mais ${count} extensões', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} extensão disponível', other: '${count} extensões disponíveis', ), 
			'home.title' => 'Logger Portátil',
			'home.newOperation' => 'Nova operação',
			'home.stationCallsign' => 'Indicativo da estação',
			'home.titleOptional' => 'Título (opcional)',
			'home.emptyList' => 'Ainda não há operações. Crie uma para começar a registar.',
			'home.quickLookup' => 'Consulta Rápida',
			'home.nav.operations' => 'Operações',
			'home.nav.chase' => 'Caça',
			'home.nav.logs' => 'Registos',
			'home.nav.maps' => 'Mapas',
			'home.nav.settings' => 'Configurações',
			'home.panels.operations' => 'Lista de Operações',
			'home.panels.operationsDescription' => 'As suas operações, as mais recentes primeiro.',
			'home.panels.version' => 'Versão Atual',
			'home.panels.versionDescription' => 'A marca Ham2K, o nome desta app e a build que está a usar.',
			'home.toggleNav' => 'Mostrar ou ocultar as etiquetas de navegação',
			'home.logs.title' => 'Registos',
			'home.logs.titleFor' => 'Registos de',
			'home.logs.emptyCallsigns' => 'Ainda não há QSOs registados',
			'home.logs.emptyQsos' => ({required Object call}) => 'Nenhum QSO para ${call}',
			'home.logs.mapNoSelection' => 'Selecione um QSO para o ver no mapa',
			'home.logs.searchHint' => 'Procurar indicativo ou nome',
			'home.logs.noSearchMatches' => 'Nenhum QSO corresponde à pesquisa',
			'home.logs.titleAll' => 'Todos os Registos',
			'home.logs.allCallsigns' => 'Todos os indicativos',
			'home.logs.noOperation' => 'Não pertence a nenhuma operação',
			'home.logs.unsavedTitle' => 'Alterações não guardadas',
			'home.logs.unsavedBody' => 'Este QSO tem alterações que não guardou.',
			'home.logs.pendingDeleteBody' => 'Este QSO está marcado para eliminação.',
			'home.logs.editGone' => 'Não guardado: esse QSO já não está neste registo.',
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
			'home.logs.panels.qsos' => 'Registo de QSOs',
			'home.logs.panels.qsosDescription' => 'Os QSOs do indicativo selecionado, em todas as operações.',
			'home.logs.panels.info' => 'Info',
			'home.logs.panels.infoDescription' => 'Total de QSOs, ou a pesquisa do indicativo do QSO selecionado.',
			'home.logs.panels.map' => 'Mapa',
			'home.logs.panels.mapDescription' => 'A localização do QSO selecionado.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicativos: ${calls}',
			'home.logs.import.skippedOne' => 'Não foi possível ler 1 registo',
			'home.logs.import.skippedOther' => ({required Object count}) => 'Não foi possível ler ${count} registos',
			'home.logs.import.readingTitle' => 'A ler o ficheiro ADIF…',
			'home.logs.import.checkingTitle' => 'A procurar duplicados…',
			'home.logs.import.importingTitle' => 'A importar QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Kb',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} de ${total} verificados',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importados, de ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'a caçar',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} e ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} e mais',
			'chase.station.title' => 'Estação de Caça',
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
			'chase.period.thisWeek' => 'Esta Semana',
			'chase.period.last14Days' => 'Últimos 14 Dias',
			'chase.period.thisMonth' => 'Este Mês',
			'chase.goals.title' => 'Objetivos de Caça',
			'chase.goals.remove' => ({required Object name}) => 'Deixar de caçar ${name}',
			'chase.goals.extensionsTitle' => 'Extensões que incluem caça',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Controlos de registo por cima dos QSOs caçados no período.',
			'chase.panels.info' => 'Info',
			'chase.panels.infoDescription' => 'O indicativo a ser registado, ou as estatísticas do período.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Estações anunciadas no ar, prontas a caçar.',
			'chase.panels.map' => 'Mapa',
			'chase.panels.mapDescription' => 'Os QSOs do período e a estação a ser registada.',
			'dialogs.operationDetails' => 'Detalhes da operação',
			'dialogs.activities' => 'Atividades',
			'dialogs.stationCallsign' => 'Indicativo da Estação',
			'dialogs.multiStationIdentifier' => 'Identificador multiestação (apenas números)',
			'dialogs.notes' => 'Notas',
			'dialogs.deleteOperationTitle' => 'Eliminar Operação',
			'dialogs.purgeTestsTitle' => 'Purgar Operações de Teste',
			'dialogs.purgeTestsBody' => 'Isto elimina permanentemente estas Operações de Teste e os seus QSOs. Não pode ser desfeito.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Mais ${count} contacto de teste que não pertence a nenhuma operação.', other: 'Mais ${count} contactos de teste que não pertencem a nenhuma operação.', ), 
			'dialogs.purgeTestsAction' => 'Purgar',
			'dialogs.syncAllTitle' => 'Substituir o registo deste dispositivo?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'O SYNCALL faz uma cópia de segurança e apaga ${qsos} deste dispositivo, e depois descarrega novamente o registo da conta a partir do servidor. A cópia de segurança fica na base de dados deste dispositivo.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO ainda não foi sincronizado — o servidor nunca o recebeu, e NÃO voltará.', other: '${n} QSOs ainda não foram sincronizados — o servidor nunca os recebeu, e NÃO voltarão.', ), 
			'dialogs.syncAllAction' => 'Apagar e Ressincronizar',
			'dialogs.receivedPurgesTitle' => 'Operações de Teste Removidas Noutro Local',
			'dialogs.receivedPurgesBody' => 'Estas foram eliminadas como Operações de Teste noutro dispositivo. Removê-las também aqui? Isto elimina-as permanentemente, assim como os seus QSOs, e não pode ser desfeito.',
			'dialogs.receivedPurgesAction' => 'Remover',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicativo inválido: ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicativos inválidos: ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} operou até agora. ${typed} será registado nos novos contactos.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Nenhum operador registado até agora. ${typed} será registado nos novos contactos.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Esta operação já tem contactos de ${calls}. ${typed} só será registado nos novos.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Registar também ${typed} como operador do contacto já registado', other: 'Registar também ${typed} como operador de todos os ${count} contactos já registados', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Ao usar várias estações no ar, não há suporte para operadores separados',
			'dialogs.callChange.contactsUnreadable' => 'Não foi possível ler os contactos desta operação, por isso alterar aqui um indicativo não oferecerá a sua atualização',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Não foi possível atualizar os contactos já registados, por isso nada foi alterado: ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} de ${planned} contactos foram atualizados — os restantes já não estão nesta operação',
			'operation.deletedReadOnly' => 'Esta operação está eliminada. Recupere-a para registar ou fazer alterações.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFO',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'MAPA',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Relógio',
			'operation.tabs.weather' => 'Meteorologia',
			'operation.tabs.website' => 'Site',
			'operation.tabs.remoteScreen' => 'Ecrã Remoto',
			'operation.tabs.solar' => 'Solar',
			'operation.tabs.radio' => 'Rádio',
			'operation.positions.nobodyYet' => 'Ainda não há outras posições de operação a partilhar esta operação.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos: ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op: ${call}',
			'operation.positions.unnamedPosition' => 'Outra posição',
			'operation.positions.thisDevice' => 'A nossa posição de operação',
			'operation.positions.nameIn' => ' em ',
			'operation.positions.panelTitle' => 'Posições',
			'operation.positions.panelDescription' => 'O que cada posição de operação que partilha esta operação está a registar neste momento.',
			'operation.stationCallsignNone' => 'Sem indicativo da estação',
			'operation.titleNone' => 'Sem título',
			'operation.deleteOperation' => 'Eliminar operação',
			'operation.loggingControlsStale' => 'Os campos da atividade podem estar desatualizados — reabra a operação para os atualizar',
			'operation.locationNone' => 'Não definida',
			'operation.generalOperation' => 'Operação Geral',
			'operation.titleFor' => ({required Object value}) => 'para ${value}',
			'operation.titleAt' => ({required Object value}) => 'em ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Agora ${description}',
			'operation.testOperationSuffix' => 'Teste',
			'operation.menu.showRstFields' => 'Mostrar campos RST',
			'operation.menu.showStateField' => 'Mostrar campo de Estado',
			'operation.menu.showGridField' => 'Mostrar campo de Grid',
			'operation.menu.showDeletedQsos' => 'Mostrar QSOs eliminados',
			'operation.menu.showDeletedOps' => 'Mostrar operações eliminadas',
			'operation.menu.showQsoNumbers' => 'Mostrar Números de QSO',
			'operation.menu.lookupAllQsos' => 'Pesquisar todos os QSOs',
			'operation.menu.loggingSettingsTitle' => 'Configurações de Registo',
			'operation.menu.mapSettingsTitle' => 'Configurações do Mapa',
			'operation.menu.actionsSection' => 'Ações',
			'operation.layout.title' => 'Adicionar um Painel',
			'operation.layout.availableSection' => 'Painéis disponíveis',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Configurações de ${panel}',
			'operation.layout.panelSettingsAction' => 'Configurações do Painel',
			'operation.layout.viewName' => 'Vista da Operação',
			'operation.layout.viewOptions' => 'Opções de disposição da vista',
			'operation.layout.viewTitleBuiltIn' => 'Esta vista está integrada na app, tal como o seu nome',
			'operation.layout.resetOptions' => 'Repor Predefinições',
			'operation.layout.removePane' => 'Remover',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Repor ${panel} nas predefinições?',
			'operation.layout.resetPaneConfirmBody' => 'O título, o cabeçalho e o tamanho voltam às predefinições. O resto da disposição fica como está.',
			'operation.layout.resetViewConfirm' => 'Repor a disposição predefinida desta vista?',
			'operation.layout.resetViewConfirmBody' => 'Os painéis voltam à disposição predefinida, e as opções da vista e de cada painel voltam às predefinições.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Configurações de Disposição de ${panel}',
			'operation.layout.paneTitle' => 'Título',
			'operation.layout.paneShowHeader' => 'Mostrar cabeçalho',
			'operation.layout.paneShowHeaderTabset' => 'Sempre visível enquanto este painel partilha um grupo — é pelo cabeçalho que se chega aos outros',
			'operation.layout.paneInherit' => 'Igual à app',
			'operation.layout.searchHint' => 'Procurar painéis',
			'operation.layout.noPanelsMatch' => 'Nenhum painel corresponde à pesquisa.',
			'operation.layout.nothingToAdd' => 'Esta vista já tem todos os painéis possíveis',
			'operation.layout.addPanel' => ({required Object panel}) => 'Adicionar ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Pré-visualizar ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'Falta a extensão "${name}"',
			'operation.layout.previewUnavailable' => 'Não foi possível mostrar a imagem de pré-visualização deste painel.',
			'operation.layout.nestedPaneTitle' => 'Mais',
			'operation.layout.editLayout' => 'Editar Disposição',
			'operation.layout.saveLayout' => 'Guardar Disposição',
			'operation.layout.revertLayout' => 'Descartar alterações à disposição',
			'operation.layout.done' => 'Concluído',
			'operation.layout.layoutUnreadableTitle' => 'Não foi possível ler a disposição',
			'operation.layout.layoutUnreadableBody' => 'Não foi possível ler a disposição guardada, por isso está a ser mostrada a disposição predefinida. A original só será substituída se escolher manter esta.',
			'operation.layout.layoutUnreadableAction' => 'Usar esta disposição',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => 'Não foi possível mostrar ${panel}',
			'operation.layout.panelRenderRetry' => 'Tentar novamente',
			'operation.layout.panelActionFailed' => 'A ação desse painel falhou. Tente novamente.',
			'operation.layout.panels.loggingDescription' => 'O registo e os campos de entrada',
			'operation.layout.panels.infoDescription' => 'O que sabemos sobre a estação contactada',
			'operation.layout.panels.spotsDescription' => 'Spots dos clusters e dos programas de atividade',
			'operation.layout.panels.mapDescription' => 'Onde estão os contactos',
			'operation.layout.panels.clockDescription' => 'Um mostrador de relógio, em qualquer fuso horário',
			'operation.layout.panels.clockFace' => 'Mostrador',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analógico',
			'operation.layout.panels.clockZone' => 'Fuso Horário',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Este dispositivo',
			'operation.layout.panels.clockShowSeconds' => 'Mostrar segundos',
			'operation.layout.panels.weatherDescription' => 'Condições atuais e para as próximas oito horas, onde está a operar',
			'operation.layout.panels.weatherUseOperationLocation' => 'Usar a localização da operação',
			'operation.layout.panels.weatherLocation' => 'Localização',
			'operation.layout.panels.weatherLocationDescription' => 'Um grid (FN31pr) ou lat,lon. Ignorado enquanto \'Usar a localização da operação\' estiver assinalado.',
			'operation.layout.panels.weatherNoLocation' => 'Sem localização definida. Indique uma localização nas configurações deste painel, ou coloque-o numa operação que tenha uma.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Não foi possível ler a localização ${location}. Use um grid como FN31pr, ou 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Não foi possível contactar o Open-Meteo — sem rede? Nova tentativa em breve.',
			'operation.layout.panels.weatherUnreadable' => 'O Open-Meteo respondeu, mas com algo ilegível. Nova tentativa em breve.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'rajadas ${speed}',
			'operation.layout.panels.panelAgeNow' => 'agora mesmo',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'há ${count} min', other: 'há ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'há ${count} h', other: 'há ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Desconhecido',
			'operation.layout.panels.weatherConditions.sunny' => 'Sol',
			'operation.layout.panels.weatherConditions.clear' => 'Céu limpo',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Predominantemente Sol',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Predominantemente Limpo',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Parcialmente Nublado',
			'operation.layout.panels.weatherConditions.cloudy' => 'Nublado',
			'operation.layout.panels.weatherConditions.foggy' => 'Nevoeiro',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Nevoeiro com Geada',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Chuvisco Fraco',
			'operation.layout.panels.weatherConditions.drizzle' => 'Chuvisco',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Chuvisco Forte',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Chuvisco Gelado Fraco',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Chuvisco Gelado',
			'operation.layout.panels.weatherConditions.lightRain' => 'Chuva Fraca',
			'operation.layout.panels.weatherConditions.rain' => 'Chuva',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Chuva Forte',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Chuva Gelada Fraca',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Chuva Gelada',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Neve Fraca',
			'operation.layout.panels.weatherConditions.snow' => 'Neve',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Neve Forte',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Grãos de Neve',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Aguaceiros Fracos',
			'operation.layout.panels.weatherConditions.showers' => 'Aguaceiros',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Aguaceiros Fortes',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Aguaceiros de Neve Fracos',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Aguaceiros de Neve',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Trovoada',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Trovoada Fraca com Granizo',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Trovoada com Granizo',
			'operation.layout.panels.websiteDescription' => 'Uma página web à sua escolha, num painel',
			'operation.layout.panels.websiteUrl' => 'Endereço',
			'operation.layout.panels.websiteRefresh' => 'Atualizar',
			'operation.layout.panels.websiteRefreshNever' => 'Nunca',
			'operation.layout.panels.websiteRefresh1' => 'A cada minuto',
			'operation.layout.panels.websiteRefresh5' => 'A cada 5 minutos',
			'operation.layout.panels.websiteRefresh15' => 'A cada 15 minutos',
			'operation.layout.panels.websiteTitle' => 'Nome do Painel',
			'operation.layout.panels.websiteRefreshNow' => 'Atualizar Agora',
			'operation.layout.panels.websiteNoUrl' => 'Ainda sem endereço. Abra as configurações deste painel para escolher uma página.',
			'operation.layout.panels.websiteBadUrl' => 'Isso não parece um endereço web. Tem de começar por https://',
			'operation.layout.panels.websiteNotHttps' => 'Só endereços https:// podem ser mostrados aqui.',
			'operation.layout.panels.websiteUnsupported' => 'Não é possível mostrar páginas web num painel neste sistema.',
			'operation.layout.panels.websiteOpenExternally' => 'Abrir no Navegador',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Não foi possível carregar a página: ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Um ecrã, app ou janela partilhado por outro dos seus dispositivos.',
			'operation.layout.panels.remoteScreenTarget' => 'Ecrã',
			'operation.layout.panels.remoteScreenChoose' => 'Escolher um ecrã…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Ecrãs Partilhados',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Nenhum dos seus dispositivos está a partilhar um ecrã. Ative Partilhar ecrãs e janelas em Configurações → Dispositivos Pares, no dispositivo que quer ver.',
			'operation.layout.panels.remoteScreenUnset' => 'Nenhum ecrã escolhido. Abra as configurações deste painel para escolher um que os seus outros dispositivos estejam a partilhar.',
			'operation.layout.panels.remoteScreenConnecting' => 'A ligar…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Esse dispositivo não está ligado neste momento.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Esse dispositivo deixou de partilhar este ecrã.',
			'operation.layout.panels.remoteScreenNoListener' => 'Esse dispositivo não aceita ligações — verifique a firewall dele.',
			'operation.layout.panels.remoteScreenNoLan' => 'Os ecrãs só são partilhados pela rede local, não por Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Esse dispositivo recusou partilhar este ecrã.',
			'operation.layout.panels.remoteScreenSettings' => 'Configurações do painel',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajustar Vista',
			'operation.layout.panels.remoteScreenDetail' => 'Detalhe',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Normal',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Alto',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Máximo',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Aproximar',
			'operation.layout.panels.remoteScreenZoomOut' => 'Afastar',
			'operation.layout.panels.remoteScreenStopped' => 'Esse ecrã ou janela já não está a ser mostrado.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Esse dispositivo não conseguiu capturar esse ecrã — pode precisar da permissão de Gravação de Ecrã.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Esse dispositivo não respondeu. Pode não ter a partilha de ecrã ativada.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Não foi possível abrir uma ligação para a imagem. Verifique a firewall deste dispositivo.',
			'operation.layout.panels.solarDescription' => 'Condições solares e geomagnéticas, com propagação banda a banda',
			'operation.layout.panels.solarUnreachable' => 'Não foi possível contactar hamqsl.com — sem rede? Nova tentativa em breve.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com respondeu, mas sem uma leitura utilizável. Nova tentativa em breve.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Dia',
			'operation.layout.panels.solarBandNight' => 'Noite',
			'operation.layout.panels.solarBandGood' => 'Boa',
			'operation.layout.panels.solarBandFair' => 'Razoável',
			'operation.layout.panels.solarBandPoor' => 'Fraca',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Fontes: ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'A ligação está com dificuldades — a saltar fotogramas.',
			'operation.layout.panels.remoteScreenStalled' => 'Os fotogramas deixaram de chegar — esta ligação pode ser demasiado lenta.',
			'operation.layout.panels.radioDescription' => 'O painel frontal de um rádio — frequência, modo e potência, sob controlo CAT',
			'operation.layout.panels.radioStyle' => 'Estilo',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderno',
			'operation.layout.panels.radioRadio' => 'Rádio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — nenhum rádio designado',
			'operation.layout.panels.radioNoRadio' => 'Nenhum rádio para mostrar. Escolha um nas configurações deste painel, ou adicione um em Configuração da Estação.',
			'operation.layout.panels.radioNotConfigured' => 'Este rádio ainda não está configurado. Escolha a porta ou o endereço em Configuração da Estação.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Rádio não ligado',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Ligar este rádio',
			'operation.layout.panels.radioDisconnect' => 'Desligar este rádio',
			'operation.layout.panels.radioStale' => 'SEM DADOS',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'SWR',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'SWR alta',
			'operation.layout.htmlPanelUnsupported' => 'Este painel precisa de uma vista web, que esta plataforma não fornece',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Este painel precisa de um ambiente isolado que a versão web não pode fornecer',
			'operation.export.title' => 'Exportações da Operação',
			'operation.export.syncedOperation' => 'A operação está sincronizada',
			'operation.export.unsyncedOperation' => 'A operação tem alterações não sincronizadas',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO nesta operação', other: '${count} QSOs nesta operação', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Todos os ${total} QSOs estão sincronizados',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} de ${total} QSOs por sincronizar',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marcadores de evento sincronizados',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} de ${total} marcadores de evento pendentes',
			'operation.export.loading' => 'A carregar opções de exportação…',
			'operation.export.noOptions' => 'Nenhum formato de exportação disponível (as extensões ainda estão a arrancar?)',
			'operation.export.nothingLogged' => 'Ainda nada para exportar — esta operação não tem QSOs.',
			'operation.export.share' => 'Partilhar',
			'operation.export.nothingSelected' => 'Nada selecionado',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Guardar ${count} ficheiro', other: 'Guardar ${count} ficheiros', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Partilhar ${count} ficheiro', other: 'Partilhar ${count} ficheiros', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Exportar ${count} ficheiro', other: 'Exportar ${count} ficheiros', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Descarregar ${count} ficheiro', other: 'Descarregar ${count} ficheiros', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Guardar ${count} ficheiro combinado', other: 'Guardar ${count} ficheiros combinados', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Partilhar ${count} ficheiro combinado', other: 'Partilhar ${count} ficheiros combinados', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Exportar ${count} ficheiro combinado', other: 'Exportar ${count} ficheiros combinados', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Descarregar ${count} ficheiro combinado', other: 'Descarregar ${count} ficheiros combinados', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => 'Guardar ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Partilhar ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exportar ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Descarregar ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Arquivar ${count} ficheiro', other: 'Arquivar ${count} ficheiros', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Arquivar ${count} ficheiro combinado', other: 'Arquivar ${count} ficheiros combinados', ), 
			'operation.export.settingsButton' => 'Configurações de exportação',
			'operation.export.settingsTitle' => 'Configurações de Exportação',
			'operation.export.compactFileNames.title' => 'Usar nomes de ficheiro compactos',
			'operation.export.compactFileNames.descriptionOn' => 'Nomes curtos pensados para envio, como N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Nomes legíveis, como 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Incluir informação privada',
			'operation.export.includePrivateData.descriptionOn' => 'Nomes, moradas, e-mails, grids e notas são incluídos',
			'operation.export.includePrivateData.descriptionOff' => 'Nomes, moradas, e-mails, grids e notas são omitidos',
			'operation.export.includePrivateData.note' => 'A Exportação ADIF Completa inclui sempre tudo',
			'operation.export.resultTitle' => 'Exportação concluída',
			'operation.export.resultFailedTitle' => 'A exportação falhou',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ficheiro exportado para ${path}', other: '${count} ficheiros exportados para ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ficheiro exportado: ${path}', other: '${count} ficheiros exportados: ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ficheiro partilhado', other: '${count} ficheiros partilhados', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ficheiro descarregado', other: '${count} ficheiros descarregados', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'A exportação falhou: ${error}',
			'operation.export.stash.needsEmailTitle' => 'Adicione primeiro um endereço de e-mail',
			'operation.export.stash.needsEmailBody' => 'O Arquivo de Ficheiros do Ham2K envia os seus ficheiros para o endereço de e-mail da sua conta LoFi, e é com ele que inicia sessão em stash.ham2k.net. A sua conta ainda não tem um confirmado — adicione-o em Configurações › Sincronização na Nuvem.',
			'operation.export.stash.openSyncSettings' => 'Abrir Sincronização na Nuvem',
			'operation.export.stash.replaceTitle' => 'O arquivo recente será substituído',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Enviou “${name}” há menos de 6 horas e ainda não foi descarregado. As contas gratuitas mantêm um arquivo de cada vez, por isso enviar agora substitui-o.',
			'operation.export.stash.replaceConfirm' => 'Enviar Mesmo Assim',
			'operation.export.stash.failedTitle' => 'Não foi possível enviar para o Arquivo de Ficheiros do Ham2K',
			'operation.export.stash.sentTitle' => 'Enviado para o Arquivo de Ficheiros do Ham2K',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Pode obter este ficheiro em **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.', other: 'Pode obter estes ficheiros em **[stash.ham2k.net](https://stash.ham2k.net)** em qualquer navegador.', ), 
			'operation.export.stash.mayHaveArrived' => 'O arquivo não respondeu — o ficheiro pode ter chegado na mesma. Verifique stash.ham2k.net antes de enviar novamente',
			'operation.export.stash.notSent' => 'não enviado',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Este ficheiro não chegou:', other: 'Estes ${count} ficheiros não chegaram:', ), 
			'operation.export.stash.emailOffer' => 'Ou, para sua conveniência, podemos enviar-lhe um e-mail com uma ligação direta.',
			'operation.export.stash.emailMe' => 'Enviar-me uma Ligação por E-mail',
			'operation.export.stash.emailSent' => 'Enviámos-lhe por e-mail uma ligação para descarregar.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Não foi possível enviar o e-mail: ${error}',
			'operation.export.stash.freeTier' => 'As contas gratuitas só podem manter um arquivo de cada vez. Os assinantes podem manter quantos quiserem.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ficheiro enviado para o Arquivo de Ficheiros do Ham2K (stash.ham2k.net)', other: '${count} ficheiros enviados para o Arquivo de Ficheiros do Ham2K (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Nenhum spot corresponde aos filtros',
			'operation.spots.error' => ({required Object error}) => 'Falha ao carregar spots: ${error}',
			'operation.spots.unknownBand' => 'Outra',
			'operation.spots.auto' => 'Automático',
			'operation.spots.autoValue' => ({required Object value}) => 'Automático (Atualmente ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (Auto)',
			'operation.spots.any' => 'Qualquer',
			'operation.spots.allBands' => 'Todas as Bandas',
			'operation.spots.allModes' => 'Todos os Modos',
			'operation.spots.phoneAndCw' => 'Telefone e CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'A mostrar ${count} de ${total} spots',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutos',
			'operation.spots.callsOfNote' => 'Indicativos Notáveis',
			'operation.spots.yourSpots' => 'Os Seus Spots',
			'operation.spots.allSpots' => 'Todos os Spots',
			'operation.spots.continents.af' => 'África',
			'operation.spots.continents.as' => 'Ásia',
			'operation.spots.continents.eu' => 'Europa',
			'operation.spots.continents.na' => 'América do Norte',
			'operation.spots.continents.oc' => 'Oceânia',
			'operation.spots.continents.sa' => 'América do Sul',
			'operation.spots.continents.an' => 'Antártida',
			'operation.spots.filters.title' => 'Filtrar Spots',
			'operation.spots.filters.band' => 'Banda',
			'operation.spots.filters.mode' => 'Modo',
			'operation.spots.filters.age' => 'Idade',
			'operation.spots.filters.sources' => 'Fontes',
			'operation.spots.filters.continent' => 'Continente',
			'operation.spots.filters.sorting' => 'Ordenação',
			'operation.spots.filters.sortByTime' => 'Por Hora do Spot',
			'operation.spots.filters.sortByFrequency' => 'Por Frequência',
			'operation.spots.filters.groupByBand' => 'Agrupar por Banda',
			'operation.spots.filters.groupCallsWithNotes' => 'Agrupar Indicativos com Notas',
			'operation.spots.filters.sourceNoReply' => 'Sem resposta',
			'operation.spots.filters.sourceError' => 'Erro',
			'operation.spots.unavailableTitle' => 'Spots indisponíveis',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} não respondeu.',
			'operation.spots.failedTitle' => 'Erro na fonte de spots',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} devolveu um erro.',
			'operation.spots.slideLogIt' => 'Registar',
			'operation.spots.slideIgnore' => 'Ignorar',
			'operation.spots.slideRestore' => 'Repor',
			'operation.spots.logConflict.title' => 'O painel de registo está ocupado',
			'operation.spots.logConflict.editingBody' => 'Está a editar um contacto registado. Registar antes este spot, ou voltar e terminar a edição?',
			'operation.spots.logConflict.composingBody' => 'Começou a introduzir um contacto. Registar antes este spot, ou voltar e terminar o que estava a escrever?',
			'operation.spots.logConflict.goBack' => 'Voltar',
			'operation.spots.logConflict.clearAndLog' => 'Limpar e registar spot',
			'operation.import.title' => 'Importar Dados para a Operação',
			'operation.import.importAdifAction' => 'Importar QSOs de ADIF',
			'operation.import.settingsButton' => 'Configurações de escuta',
			'operation.import.settingsTitle' => 'Escutar Outras Apps',
			'operation.import.protocolAddressLabel' => 'Endereço',
			'operation.import.protocolPortLabel' => 'Porta',
			'operation.import.protocolPortInvalid' => 'Introduza uma porta entre 1 e 65535',
			'operation.import.protocolAddressInvalid' => 'Introduza um endereço IP válido (ex. 127.0.0.1 ou 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'A receber dados',
			'operation.import.protocolStatusNoData' => 'Nenhuns dados recebidos recentemente',
			'operation.import.protocolBindError' => ({required Object error}) => 'Não foi possível começar a escutar: ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Não foi possível guardar os QSOs recebidos; a tentar novamente: ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Qualquer (broadcast)',
			'operation.import.wsjtxProtocolName' => 'Servidor UDP do WSJT-X',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → separador Broadcast Data → assinale "Enable Broadcasts" para a informação de contactos. Defina o endereço IP como 127.0.0.1 se estiver a correr neste mesmo computador, ou 255.255.255.255 para difundir na rede local atual.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → separador Reporting → secção UDP Server → assinale "Accept UDP requests". Defina o UDP Server como 127.0.0.1 se estiver a correr neste mesmo computador, ou um endereço multicast como 239.239.0.2, e use o mesmo endereço na configuração acima nesta app.',
			'operation.import.listenTitle' => 'Escutar QSOs de outras apps',
			'operation.import.listenDescriptionOnN1mm' => 'A escutar o N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'A escutar o WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'A escutar o N1MM+ e o WSJT-X',
			'operation.import.listenDescriptionOff' => 'Desligado',
			'operation.import.addToOperationTitle' => 'Adicionar a esta operação',
			'operation.import.addToOperationDescriptionOn' => 'Os QSOs capturados são adicionados a esta operação à medida que chegam',
			'operation.import.addToOperationDescriptionOff' => 'Os QSOs capturados ficam retidos até ativar esta opção',
			'operation.import.pendingSectionTitle' => 'QSOs Capturados',
			'operation.import.pendingEmpty' => 'Ainda nada capturado',
			'operation.import.stationMismatch' => ({required Object call}) => 'Registado como ${call}, não a estação desta operação',
			'operation.import.discardAction' => 'Descartar',
			'operation.import.gapDialogTitle' => 'Incluir capturas anteriores?',
			'operation.import.gapDialogBody' => ({required Object count}) => 'Foram capturados mais ${count} QSOs antes, antes de uma falha nos dados. Incluí-los também?',
			'operation.import.gapDialogRecentOnly' => 'Só os recentes',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Incluir todos os ${count}',
			'map.outlineIssue.link' => 'Problemas?',
			'map.outlineIssue.title' => 'Reportar um problema num contorno',
			'map.outlineIssue.reference' => 'Que contorno',
			'map.outlineIssue.severity' => 'Quão grave é?',
			'map.outlineIssue.minor' => 'Pormenor',
			'map.outlineIssue.major' => 'Grave',
			'map.outlineIssue.explanation' => 'O que está errado?',
			'map.outlineIssue.explanationHint' => 'O que o contorno tem de errado, e onde',
			'map.outlineIssue.send' => 'Enviar',
			'map.outlineIssue.sending' => 'A enviar o seu relatório — obrigado',
			'map.outlineIssue.copy' => 'Copiar relatório',
			'map.outlineIssue.notSent' => 'Não foi possível enviar o relatório',
			'map.outlineIssue.copied' => 'Relatório copiado',
			'map.outlineIssue.notCopied' => 'Não foi possível copiar o relatório',
			'map.outlinesDisclaimer' => 'Os contornos são apenas para referência. Faça a sua própria pesquisa!',
			'map.outlinesCredit' => ({required Object sources}) => 'Contornos: ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Limites: ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Instalações: ${sources}',
			'map.fullCredits' => 'Créditos completos dos dados',
			'map.fewerCredits' => 'Menos créditos',
			'map.emptyState' => 'Ainda não há localizações de QSOs.\nOs QSOs com grid, estado ou país aparecem aqui.',
			'map.unavailable' => 'O mapa não está disponível neste momento.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH: ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plano',
			'map.globe' => 'Globo',
			'map.zoomIn' => 'Aproximar',
			'map.zoomOut' => 'Afastar',
			'map.postcard.button' => 'Postal da Operação',
			'map.postcard.title' => ({required Object title}) => 'Postal de ${title}',
			'map.postcard.portrait' => 'Vertical',
			'map.postcard.landscape' => 'Horizontal',
			'map.postcard.square' => 'Quadrado',
			'map.postcard.save' => 'Guardar…',
			'map.postcard.download' => 'Descarregar',
			'map.postcard.share' => 'Partilhar',
			'map.postcard.copy' => 'Copiar',
			'map.postcard.copied' => 'Copiado para a área de transferência',
			'map.postcard.saved' => ({required Object path}) => 'Guardado em ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} descarregado',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} imagens guardadas em ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} guardado',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} já tinha sido guardado',
			'map.postcard.downloadedMany' => ({required Object count}) => 'A descarregar ${count} imagens — autorize-as se o navegador pedir',
			'map.postcard.mapLeftOut' => 'O mapa não carregou, por isso ficou de fora',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — o mapa não carregou, por isso ficou de fora',
			'map.postcard.continued' => ({required Object title}) => '${title} (continuação)',
			'map.postcard.previousPage' => 'Página anterior',
			'map.postcard.nextPage' => 'Página seguinte',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Página ${page} de ${count}',
			'map.postcard.sectionDays' => 'Cada dia',
			'map.postcard.reset' => 'Repor',
			'map.postcard.failed' => ({required Object error}) => 'Não foi possível criar o postal: ${error}',
			'map.postcard.mapNotReady' => 'O mapa não terminou de carregar. Verifique a ligação e tente novamente.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Não foi possível guardar o postal: ${error}',
			'map.postcard.copyFailed' => 'A área de transferência não aceitou a imagem. Tente novamente.',
			'map.postcard.shareFailed' => 'Não foi possível partilhar o postal. Tente novamente.',
			'map.postcard.fileName' => 'postal',
			'mapsView.title' => 'Mapas',
			'mapsView.searchHint' => 'Procurar parques, cumes e mais',
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
			'activitiesView.activitiesCountZero' => 'Nenhuma Atividade Selecionada',
			'activitiesView.activitiesCountOne' => '1 Atividade',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} Atividades',
			'activitiesView.empty' => 'Ainda sem atividades — use Sugestões e Pesquisa abaixo para adicionar uma',
			'activitiesView.removeActivity' => 'Remover',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Abrir ${name}',
			'activitiesView.editActivity' => 'Editar atividade',
			'activitiesView.manageExtensions' => 'Gerir Extensões',
			'activitiesView.manage' => 'Gerir',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Tipos de Atividade: ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Tipos de Atividade: ${first} e ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Tipos de Atividade: ${first}, ${second} e mais ${more}',
			'activitiesView.reference' => 'Referência',
			'activitiesView.invalidReference' => 'Inválida',
			'activitiesView.duplicateReference' => 'Já adicionada',
			'activitiesView.searchHint' => 'Procurar por nome, referência ou qualquer outra coisa…',
			'activitiesView.noSuggestions' => 'Sem resultados',
			'activitiesView.noSuggestionsHint' => 'Procure acima pelo nome ou número da referência',
			'activitiesView.noSuggestionsExample' => '(por exemplo \'trilho\' ou \'4556\')',
			'activitiesView.allOptions' => 'Tipos de Atividade',
			'activitiesView.determiningLocation' => 'A determinar a localização atual…\nA aguardar o GPS para encontrar referências próximas',
			'activitiesView.locationUnavailableTitle' => 'Dados de localização indisponíveis',
			'activitiesView.locationDeniedTitle' => 'Permissão de localização negada',
			'activitiesView.locationBlockedTitle' => 'Permissão de localização bloqueada',
			'activitiesView.noNearbyReason' => 'Não é possível determinar referências próximas',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Toque em ${icon} para introduzir a localização manualmente,\nou simplesmente procure referências pelo nome',
			'activitiesView.locationGrantAction' => 'Permitir acesso à localização',
			'activitiesView.locationSettingsAction' => 'Abrir Configurações',
			'activitiesView.locationSettingsUnavailable' => 'Permita o acesso à localização nas configurações do sistema',
			'activitiesView.locationGrantRefused' => 'Continua sem localização — o sistema voltou a recusar',
			'activitiesView.searchUnavailableTitle' => 'Pesquisa de atividades indisponível',
			'activitiesView.searchUnavailableReason' => 'Nenhuma extensão de atividade conseguiu fazer a pesquisa. Tente novamente daqui a pouco.',
			'activitiesView.emptySheet' => 'Use as sugestões e a pesquisa abaixo para adicionar uma',
			'activitiesView.exports' => 'Exportações',
			'activitiesView.exportLogs' => 'Exportar Registos',
			'activitiesView.tools' => 'Ferramentas',
			'activitiesView.toolsTitle' => 'Ferramentas da Operação',
			'activitiesView.operationDetails' => 'Detalhes da Operação',
			'activitiesView.share' => 'Partilhar',
			'activitiesView.archive' => 'Arquivar',
			'activitiesView.deleteOperation' => 'Eliminar Operação',
			'activitiesView.undeleteOperation' => 'Recuperar Operação Eliminada',
			'activitiesView.alreadySelected' => 'Já selecionada',
			'activitiesView.selected' => 'Selecionada',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} de ${count}',
			'activitiesView.previousPick' => 'Resultado anterior',
			'activitiesView.nextPick' => 'Resultado seguinte',
			'activitiesView.retiredReference' => 'Retirada',
			'activitiesView.enableExtension' => ({required Object name}) => 'Ativar ${name}',
			'activitiesView.enableExtensionHint' => 'Esta extensão corresponde à sua pesquisa, mas não está ativada',
			'activitiesView.enableExtensionForRefHint' => 'Esta extensão trata uma das referências desta operação, mas não está ativada',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} não está a correr',
			'activitiesView.extensionNotRunningHint' => 'Esta extensão foi desativada; abra as Configurações de Extensões para mais informações',
			'activitiesView.installExtension' => ({required Object name}) => 'Instalar ${name}',
			'activitiesView.installExtensionHint' => 'Esta extensão corresponde à sua pesquisa, mas não está instalada',
			'activitiesView.onlyCatalogMatches' => 'Sem resultados\nAlgumas extensões do catálogo podem ter resultados.\nInstale-as em Tipos de Atividade abaixo.',
			'activitiesView.setupUnavailable' => 'Não foi possível carregar a configuração desta atividade — tente novamente a partir de Gerir',
			'activitiesView.controlsUnavailableTitle' => 'Controlos da atividade indisponíveis',
			'activitiesView.controlsUnavailableReason' => 'As suas referências estão seguras, mas não é possível editá-las neste momento.',
			'activitiesView.controlsUnavailableRetry' => 'Tentar novamente',
			'activitiesView.onlyDisabledMatches' => 'Sem resultados\nAlgumas extensões disponíveis podem ter resultados.\nAtive-as em Tipos de Atividade abaixo.',
			'activitiesView.onlyNotRunningMatches' => 'Sem resultados\nAlgumas extensões que podem ter resultados não estão a correr.\nVeja Tipos de Atividade abaixo.',
			'activitiesView.mapToggle' => 'Mapa',
			'activitiesView.searchToggle' => 'Pesquisa',
			'activitiesView.addToOperation' => 'Adicionar à Operação',
			'activitiesView.addToOperationShort' => 'Adicionar à Op.',
			'activitiesView.mapEmptyState' => 'Sem resultados para mostrar no mapa',
			'activitiesView.mapEmptyStateHint' => 'Volte à lista, ou procure outra coisa',
			'activitiesView.imports' => 'Importações',
			'loggingControls.timeUtc' => 'Hora (UTC)',
			'loggingControls.date' => 'Data',
			'loggingControls.now' => 'Agora',
			'loggingControls.frequency' => 'Frequência',
			'loggingControls.mode' => 'Modo',
			'loggingControls.theirCall' => 'Indicativo',
			'loggingControls.noteField' => 'Nota',
			'loggingControls.todoField' => 'Tarefa',
			'loggingControls.sent' => 'Enviado',
			'loggingControls.rcvd' => 'Recebido',
			'loggingControls.more' => 'Mais',
			'loggingControls.revert' => 'Reverter',
			'loggingControls.undoDelete' => 'Anular eliminação',
			'loggingControls.restore' => 'Repor',
			'loggingControls.wipe' => 'Apagar',
			'loggingControls.undo' => 'Desfazer',
			'loggingControls.pendingDeleteTapWarning' => 'Toque no caixote do lixo mais uma vez para eliminar este QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Clique no caixote do lixo mais uma vez para eliminar este QSO',
			'loggingControls.deletedQsoWarning' => 'QSO Eliminado',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Toque no caixote do lixo mais uma vez para eliminar este ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Clique no caixote do lixo mais uma vez para eliminar este ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => '${kind} eliminado',
			'loggingControls.timeControl' => 'Hora',
			'loggingControls.radioControl' => 'Rádio',
			'loggingControls.powerControl' => 'Potência',
			'loggingControls.notesControl' => 'Notas',
			'loggingControls.power' => 'Potência',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Controlos de Registo',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Self-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'Self-spot em ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spot de ${call} em ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Tarde demais para fazer spot de ${call}',
			'loggingControls.spotNoFreq' => 'Defina primeiro uma frequência para o spot',
			'loggingControls.spotComment' => 'Comentário',
			'loggingControls.bandOrFreqRequired' => 'Defina uma frequência ou banda antes de registar',
			'loggingControls.missingBand' => 'Sem Banda',
			'loggingControls.missingMode' => 'Sem Modo',
			'loggingControls.saveFailed' => ({required Object error}) => 'Não foi possível guardar: ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Não foi possível eliminar: ${error}',
			'loggingControls.info.noQsos' => 'Ainda nenhum QSO… vamos para o ar!',
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
			'loggingControls.info.noticeNewBand' => 'Nova Banda',
			'loggingControls.info.noticeNewMode' => 'Novo Modo',
			'loggingControls.info.noticeNewDXCC' => 'Novo DXCC',
			'loggingControls.info.noticeNewState' => 'Novo Estado',
			'loggingControls.info.noticeNewProvince' => 'Nova Província',
			'loggingControls.info.noticeNewDay' => 'Novo Dia',
			'loggingControls.info.noticeNewRef' => 'Nova Ref',
			'loggingControls.info.noticeNewMult' => 'Novo Mult',
			'loggingControls.info.noticeNewZone' => 'Nova Zona',
			'loggingControls.info.noticeInvalidMode' => 'Modo Errado',
			'loggingControls.info.noticeInvalidBand' => 'Banda Errada',
			'loggingControls.info.noticeInvalidCategory' => 'Não Contactável',
			'loggingControls.info.noticeWorkedBefore' => 'Já Contactado',
			'loggingControls.info.noticeNewPark' => 'Novo Parque',
			'loggingControls.info.noticeNewSection' => 'Nova Secção',
			'loggingControls.info.noticeBonusStation' => 'Estação Bónus!',
			'loggingControls.info.noticeMissingExchange' => 'Sem Câmbio',
			'loggingControls.info.noticeInvalidExchange' => 'Câmbio Inválido',
			'loggingControls.info.noticeUnknownEvent' => 'Evento Desconhecido',
			'loggingControls.info.noticeOurGrid' => 'Definir o Nosso Grid',
			'loggingControls.info.noticeRareCounty' => 'Município Raro!',
			'loggingControls.info.noticeOurLocation' => 'Definir o Nosso Município',
			'loggingControls.info.noticeShortGrid' => 'Grid Demasiado Curto',
			'formChrome.untitled' => '(sem título)',
			'formChrome.showMore' => 'Mostrar mais',
			'formChrome.showAll' => 'Mostrar tudo',
			'formChrome.showFewer' => 'Mostrar menos',
			'formChrome.defaults' => 'Predefinições',
			'formChrome.search' => 'Procurar',
			'formChrome.clear' => 'Limpar',
			'formChrome.openPage' => 'Abrir página',
			'formChrome.connected' => 'Ligado',
			'formChrome.notConnected' => 'Não Ligado',
			'formChrome.manage' => 'Gerir',
			'formChrome.connect' => 'Ligar',
			'formChrome.formTitle' => 'Formulário',
			'formChrome.addItem' => ({required Object label}) => 'Adicionar ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Editar ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'A mostrar ${shown} de ${total} (${selected} selecionados)',
			'formChrome.validationError' => ({required Object error}) => 'Erro de validação: ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Erro de transformação: ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Erro: ${error}',
			'formChrome.removeItem' => 'Remover',
			'formChrome.storageUnavailable' => 'Credenciais indisponíveis',
			'qsoEditForm.title' => 'Editar QSO',
			'qsoEditForm.operatorCall' => 'Operador',
			'qsoEditForm.position' => 'Posição',
			'qsoEditForm.theirName' => 'Nome',
			'qsoEditForm.theirGrid' => 'Grid',
			'qsoEditForm.theirState' => 'Estado',
			'qsoEditForm.band' => 'Banda',
			'qsoEditForm.notes' => 'Notas',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Informações Deles',
			'qsoEditForm.sectionOur' => 'As Nossas Informações',
			'qsoEditForm.sectionNotes' => 'Notas',
			'qsoEditForm.theirCity' => 'Cidade',
			'qsoEditForm.theirCounty' => 'Município',
			'qsoEditForm.theirEntity' => 'Entidade',
			'qsoEditForm.theirCqZone' => 'Zona CQ',
			'qsoEditForm.theirItuZone' => 'Zona ITU',
			'qsoEditForm.theirArrlSection' => 'Secção ARRL',
			'qsoEditForm.theirLat' => 'Latitude',
			'qsoEditForm.theirLon' => 'Longitude',
			'qsoEditForm.theirPower' => 'Potência deles',
			'qsoList.empty' => 'Ainda nenhum QSO — contacte alguém!',
			'qsoList.bandOrModeWarning' => 'Confirme que a banda e o modo estão corretos',
			'qsoList.today' => 'Hoje',
			'qsoList.yesterday' => 'Ontem',
			'qsoList.tomorrow' => 'Amanhã',
			'loggingPanel.stats' => 'Estatísticas da Operação',
			'loggingPanel.scoring' => 'Pontuação',
			'loggingPanel.dxccEntities' => 'Entidades DXCC',
			'loggingPanel.statesWorked' => 'Estados',
			'loggingPanel.provincesWorked' => 'Províncias',
			'loggingPanel.duplicates' => 'Duplicados',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Mostrar Imagem',
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
			'callInfo.otherOpsCountOne' => '1 QSO noutras operações',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs noutras operações',
			'callInfo.andMore' => ({required Object count}) => '… e mais ${count}',
			'callInfo.withCall' => ({required Object call}) => 'com ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'de ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} nos últimos 7 dias',
			'callInfo.history.today' => ({required Object n}) => '${n} hoje',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Configurações',
			'settings.language' => 'Idioma',
			'settings.languageSystem' => ({required Object language}) => 'Seguir as configurações do sistema (${language})',
			'settings.theme.title' => 'Modo do Tema',
			'settings.theme.system' => 'Seguir as configurações do sistema',
			'settings.theme.light' => 'Claro',
			'settings.theme.dark' => 'Escuro',
			'settings.themeDescription.system' => 'A seguir as configurações do sistema',
			'settings.themeDescription.light' => 'Sempre no Modo Claro',
			'settings.themeDescription.dark' => 'Sempre no Modo Escuro',
			'settings.fontScale' => 'Escala da Fonte',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Mínimo--',
			'settings.fontScaleOpts.smallestMinus' => 'Mínimo-',
			'settings.fontScaleOpts.smallest' => 'Mínimo',
			'settings.fontScaleOpts.smaller' => 'Menor',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Maior',
			'settings.fontScaleOpts.largest' => 'Máximo',
			'settings.fontScaleOpts.largestPlus' => 'Máximo+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Máximo++',
			'settings.keepDeviceAwake.title' => 'Manter o Dispositivo Acordado',
			'settings.keepDeviceAwake.descriptionOn' => 'A manter-se acordado na vista de registo ou durante uma sincronização',
			'settings.keepDeviceAwake.descriptionOff' => 'A suspender como habitualmente',
			'settings.layoutDensity' => 'Densidade da Disposição',
			'settings.layoutDensityOpts.auto' => 'Automática',
			'settings.layoutDensityOpts.densest' => 'Muito densa',
			'settings.layoutDensityOpts.dense' => 'Densa',
			'settings.layoutDensityOpts.normal' => 'Normal',
			'settings.layoutDensityOpts.sparse' => 'Espaçada',
			'settings.layoutDensityOpts.sparsest' => 'Muito espaçada',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'a janela é demasiado baixa, a usar ${effective}',
			'settings.layoutDensityAtLimit' => 'no limite',
			'settings.distanceUnits' => 'Unidades de Distância',
			'settings.distanceUnitsOpts.kilometers' => 'Quilómetros',
			'settings.distanceUnitsOpts.miles' => 'Milhas',
			'settings.userInterface' => 'Interface',
			'settings.logging.title' => 'Registo',
			'settings.logging.leftieMode.title' => 'Modo Canhoto',
			'settings.logging.leftieMode.descriptionOn' => 'A usar o esquema para canhotos',
			'settings.logging.leftieMode.descriptionOff' => 'A usar o esquema para destros',
			'settings.logging.countryFlags.title' => 'Bandeiras dos Países',
			'settings.logging.countryFlags.dx' => 'Mostrar apenas para contactos DX',
			'settings.logging.countryFlags.all' => 'Mostrar bandeiras para todos os contactos',
			'settings.logging.countryFlags.none' => 'Não mostrar bandeiras',
			'settings.logging.countryFlagsDescription.dx' => 'A mostrar bandeiras apenas para contactos DX',
			'settings.logging.countryFlagsDescription.all' => 'A mostrar bandeiras para todos os contactos',
			'settings.logging.countryFlagsDescription.none' => 'A não mostrar bandeiras',
			'settings.logging.suggestDefaultOperator.title' => 'Sugerir Operador',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'A propor o seu indicativo como operador quando uma operação usa um indicativo de estação diferente',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'A deixar o operador em branco, a menos que o preencha',
			'settings.logging.showBearing.title' => 'Mostrar Direção',
			'settings.logging.showBearing.descriptionOn' => 'A mostrar a direção estimada para a estação',
			'settings.logging.showBearing.descriptionOff' => 'A não mostrar informação de direção',
			'settings.logging.showReverseBearing.title' => 'Mostrar também direção inversa',
			'settings.logging.showReverseBearing.descriptionOn' => 'A mostrar também a direção a partir da estação, como "45° / 225°"',
			'settings.logging.showReverseBearing.descriptionOff' => 'A mostrar apenas a direção para a estação',
			'settings.logging.switchSentRcvd.title' => 'Trocar a ordem dos relatórios de sinal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Enviado primeiro, Recebido em segundo',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Recebido primeiro, Enviado em segundo',
			'settings.logging.jumpAfterRST.title' => 'Saltar para o campo seguinte após o RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'A saltar depois de introduzido o RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'A não saltar automaticamente',
			'settings.logging.defaultReport.title' => 'Relatório predefinido — Telefone',
			'settings.logging.defaultReport.description' => 'Usado quando Enviado ou Recebido fica vazio em SSB, FM ou AM',
			'settings.logging.defaultReportCW.title' => 'Relatório predefinido — CW e dados',
			'settings.logging.defaultReportCW.description' => 'Usado quando Enviado ou Recebido fica vazio em CW, RTTY e outros modos de dados',
			'settings.logging.defaultReportFT8.title' => 'Relatório predefinido — FT8 e FT4',
			'settings.logging.defaultReportFT8.description' => 'Usado quando Enviado ou Recebido fica vazio nos modos FT',
			'settings.logging.numbersRow.title' => 'Linha de Números',
			'settings.logging.numbersRow.description' => 'Mostrar uma linha de teclas numéricas por cima do teclado durante o registo',
			'settings.logging.numbersRowExtra.title' => 'Tecla de barra e ponto',
			'settings.logging.numbersRowExtra.description' => 'Adiciona uma tecla contextual: “/” para indicativos, “.” para números',
			'settings.logging.numbersRowVibrate.title' => 'Vibrar ao premir teclas',
			'settings.logging.numbersRowVibrate.description' => 'Resposta tátil ao tocar numa tecla numérica',
			'settings.logging.bands' => 'Bandas Preferidas',
			'settings.logging.modes' => 'Modos Preferidos',
			'settings.catServer.title' => 'Servidor CAT',
			'settings.catServer.description' => 'Permitir que outras apps (WSJT-X, programas de registo, etc.) controlem o rádio através do Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocolo',
			'settings.catServer.protocolOpts.off' => 'Desativado',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Porta',
			'settings.catServer.openAccess' => 'Acesso aberto',
			'settings.catServer.openAccessOn' => 'Qualquer computador na rede local pode ligar-se.',
			'settings.catServer.openAccessOff' => 'Só as apps neste computador se podem ligar.',
			'settings.catServer.off' => 'Desligado.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, a iniciar…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} na porta ${port}. Clientes ligados: ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} na porta ${port}, mas nenhum rádio de VFO Principal está ligado.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} não consegue escutar na porta ${port}: ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: outro programa está a usá-la, muitas vezes o próprio ${protocol}. Feche esse programa ou escolha outra porta.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} não consegue escutar na porta ${port}: este computador não o permite. Escolha uma porta acima de 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} deixou de escutar na porta ${port}. A tentar novamente…',
			'settings.radio.title' => 'Controlo CAT',
			_ => null,
		} ?? switch (path) {
			'settings.radio.loggingAndCat' => 'Registo e CAT',
			'settings.radio.tuningSection' => 'Sintonia',
			'settings.radio.keyerSection' => 'Manipulador',
			'settings.radio.servicesSection' => 'Serviços',
			'settings.radio.stationConfigurationSection' => 'Configuração da Estação',
			'settings.radio.moreSettings' => 'Mais configurações da estação',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Controlar o PTT com [\']',
			'settings.radio.pttKey.descriptionOn' => 'Nos modos de Telefone, [\'] põe o rádio em emissão e [\'] novamente tira-o. Sai de emissão sozinho ao fim de um minuto.',
			'settings.radio.pttKey.descriptionOff' => 'A tecla [\'] não põe o rádio em emissão.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'A transmitir',
			'settings.radio.smartVfoSnap.title' => 'Arredondamento Inteligente do VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Quando para de rodar o botão, arredonda a frequência para um passo sensato. Só nos modos de voz.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'Fica exatamente onde sintonizou.',
			'settings.radio.snapDebounce.title' => 'Arredondamento: Tempo de espera',
			'settings.radio.snapDebounce.description' => 'Quanto tempo o botão tem de estar parado antes de a frequência ser arredondada. Mais curto parece imediato; mais longo dá margem a um movimento lento.',
			'settings.radio.snapLongMove.title' => 'Arredondamento: Movimento longo',
			'settings.radio.snapLongMove.description' => 'Mova pelo menos isto e a frequência é arredondada a um kHz inteiro, por mais devagar que tenha terminado.',
			'settings.radio.snapMinMove.title' => 'Arredondamento: Movimento mínimo',
			'settings.radio.snapMinMove.description' => 'Mova menos do que isto e a frequência não é arredondada, para não mexer na sintonia fina.',
			'settings.radio.snapMinSpeed.title' => 'Arredondamento: Movimento mais lento',
			'settings.radio.snapMinSpeed.description' => 'Rode o botão mais devagar do que isto e a frequência não é arredondada, a menos que tenha sido um movimento longo.',
			'settings.radio.enterSends.pillOff' => 'ESM Desl.',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Enter envia mensagens',
			'settings.radio.enterSends.off' => 'Desligado',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Enter Envia Mensagens: ${state}. Toque para alterar.',
			'settings.radio.keyerSpeed.title' => 'Velocidade do manipulador',
			'settings.radio.keyerSpeed.unit' => 'PPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} ppm',
			'settings.radio.keyerSpeed.pillUnknown' => '– ppm',
			'settings.radio.cwMessages.title' => 'Mensagens do Manipulador CW',
			'settings.radio.cwMessages.notSupported' => 'O rádio atual não suporta manipulação CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Mensagem (${n})',
			'settings.radio.cwMessages.labelField' => 'Etiqueta',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Etiqueta de F${n}',
			'settings.radio.cwMessages.details' => 'Detalhes',
			'settings.radio.cwMessages.empty' => '(vazia)',
			'settings.radio.cwMessages.sets' => 'Conjunto de Mensagens',
			'settings.radio.cwMessages.newSet' => 'Novo Conjunto',
			'settings.radio.cwMessages.renameSet' => 'Mudar o Nome do Conjunto',
			'settings.radio.cwMessages.deleteSet' => 'Eliminar Conjunto',
			'settings.radio.cwMessages.newSetName' => 'Nome',
			'settings.radio.cwMessages.setDefault' => 'Predefinido',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Mensagens ESM',
			'settings.radio.cwMessages.setSaved' => 'As Minhas Mensagens',
			'settings.radio.cwMessages.repeat' => 'Repetir Mensagem #1',
			'settings.radio.cwMessages.repeatOff' => 'Não',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Após ${n} segundos',
			'settings.radio.cwMessages.repeatWait' => 'A repetir',
			'settings.radio.cwMessages.keyboard' => 'Escrever para enviar',
			'settings.radio.cwMessages.keyboardField' => 'Escrever para enviar',
			'settings.radio.cwMessages.closeArea' => 'Fechar a área do manipulador',
			'settings.radio.cwMessages.help' => 'Ajuda',
			'settings.radio.cwMessages.helpTitle' => 'Escrever Mensagens CW',
			'settings.radio.cwMessages.helpIntro' => 'As mensagens podem usar modelos com os seguintes valores:',
			'settings.radio.cwMessages.helpOpCall' => 'O seu indicativo',
			'settings.radio.cwMessages.helpQsoCall' => 'O indicativo deles — numa pilha //, o indicativo que será registado',
			'settings.radio.cwMessages.helpQsoFullCall' => 'O indicativo deles, se houver um indicativo válido; vazio para um parcial',
			'settings.radio.cwMessages.helpQsoPartial' => 'Um indicativo parcial; vazio se houver um indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextCall' => 'Numa pilha //, o indicativo que será selecionado para registar a seguir, se houver um indicativo completo válido',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'Numa pilha //, o parcial seguinte depois de registar o contacto atual',
			'settings.radio.cwMessages.helpQsoName' => 'O nome próprio deles, tal como escrito ou, se não, da pesquisa',
			'settings.radio.cwMessages.helpQsoState' => 'O estado deles, tal como escrito ou, se não, da pesquisa',
			'settings.radio.cwMessages.helpKeyerMsg' => 'A mensagem 1 tal como seria enviada, dentro de outra mensagem. Válido para as mensagens 1 a 8',
			'settings.radio.cwMessages.helpQsoRst' => 'O relatório que está a enviar',
			'settings.radio.cwMessages.helpQsoSerial' => 'O seu número de série, num concurso que o envie',
			'settings.radio.cwMessages.helpPad' => 'Preenche com zeros até esse número de dígitos: 7 é enviado como 007',
			'settings.radio.cwMessages.helpCut' => 'Números abreviados, T para 0 e N para 9: 599 é enviado como 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Escolhe os dígitos a abreviar, entre aspas — 0 é T, 1 é A, 5 é E, 9 é N',
			'settings.radio.cwMessages.helpFullExample' => 'Exemplo completo:',
			'settings.radio.cwMessages.helpExample' => 'Envia W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Com Enter Envia Mensagens ligado, o Enter emite as mensagens pela sua tecla de função, como faz o N1MM. O conjunto Mensagens ESM começa com estas:',
			'settings.radio.cwMessages.helpEsmCq' => 'Em Run, Enter com o campo do indicativo vazio chama CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'O seu câmbio: depois do indicativo deles em Run, depois de eles responderem em S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Agradecimento, depois de o contacto ser registado: os seus marcadores referem-se ao próximo contacto, não a este',
			'settings.radio.cwMessages.helpEsmMyCall' => 'Em S&P, o seu indicativo para a estação a que está a responder',
			'settings.radio.cwMessages.helpEsmHisCall' => 'Em Run, o indicativo deles antes do seu câmbio',
			'settings.radio.cwMessages.helpEsmAgain' => 'Pede novamente quando nada do câmbio deles foi copiado',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 sugerido para pilhas //: o TU sai depois de o contacto ser registado, por isso agradece, depois chama a próxima estação da pilha e envia o seu câmbio, ou pede de volta um parcial (TU KR?); sem nada na pilha, só TU',
			'settings.radio.voiceMessages.title' => 'Mensagens de Voz',
			'settings.radio.voiceMessages.notSupported' => 'O rádio atual não suporta mensagens de voz',
			'settings.radio.voiceMessages.description' => 'Usa as memórias de voz do rádio',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Memória de voz (${n})',
			'settings.radio.voiceMessages.labelField' => 'Etiqueta',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Etiqueta da memória de voz ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Vazia',
			'settings.radio.voiceMessages.notMeasured' => 'Duração desconhecida',
			'settings.radio.voiceMessages.playButton' => 'Reproduzir',
			'settings.radio.voiceMessages.recordButton' => 'Gravar',
			'settings.radio.voiceMessages.stopButton' => 'Parar',
			'settings.radio.voiceMessages.repeat' => 'Repetir Mensagem #1',
			'settings.radio.voiceMessages.repeatOff' => 'Não',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Após ${n} segundos',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Notas sobre o ${model}:',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Estas memórias estão no rádio de ${device}. Os nomes e durações pertencem a esse dispositivo.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Guardado no rádio, onde os outros clientes também o veem.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Aguarde o indicador [REC] no rádio, depois mantenha premido o botão PTT e grave a mensagem. Termine-a premindo o botão PARAR aqui na app antes de largar o PTT, para evitar cliques indesejados.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Aguarde que o indicador [REC] pisque pelo menos quatro vezes, depois mantenha premido o botão PTT e grave a mensagem. Termine-a premindo o botão PARAR aqui na app antes de largar o PTT, para evitar cliques indesejados.',
			'settings.radio.voiceMessages.pill' => 'Voz',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Reproduzir memória ${n}',
			'settings.radio.voiceMessages.stop' => 'Parar',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Gravar memória ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Parar gravação',
			'settings.radio.voiceMessages.playing' => 'A reproduzir…',
			'settings.radio.voiceMessages.recording' => 'A gravar…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'A reproduzir ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'A gravar ${label}',
			'settings.radio.voiceMessages.doubtful' => 'O rádio reproduziu-a? Reportou logo que estava inativo.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Tem de gravar as memórias no próprio rádio.',
			'settings.radio.avoidZeroBeat.title' => 'Evitar Batimento Zero nos Spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Com um rádio ligado, sintoniza alguns Hz ao lado de um spot de CW, para que nem todos os que lhe respondem chamem na mesma nota.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Sintoniza exatamente a frequência anunciada.',
			'settings.radio.zeroBeatRange.title' => 'Batimento Zero: Margem a evitar',
			'settings.radio.zeroBeatRange.description' => 'A que distância da frequência anunciada sintonizar, para qualquer lado. O desvio nunca fica perto de zero — isso voltaria a ser um batimento zero.',
			'settings.help.title' => 'Ajuda e Recursos',
			'settings.help.description' => 'Comunidade e apoio',
			'settings.help.forums' => 'Fóruns do Ham2K',
			'settings.help.forumsDescription' => 'Encontre ajuda, dê feedback, discuta ideias…',
			'settings.help.chat' => 'Chat do Ham2K',
			'settings.help.chatDescription' => 'O servidor Discord da nossa comunidade online',
			'settings.help.youtube' => 'YouTube do Ham2K',
			'settings.help.youtubeDescription' => 'Vídeos e transmissões ao vivo',
			'settings.help.instagram' => 'Instagram do Ham2K',
			'settings.help.instagramDescription' => 'Porque nunca há fotos a mais…',
			'settings.help.bluesky' => 'BlueSky do Ham2K',
			'settings.help.blueskyDescription' => 'Siga-nos para notícias e atualizações',
			'settings.help.contact' => 'Contacte-nos',
			'settings.help.contactDescription' => 'help@ham2k.com — mas experimente primeiro os Fóruns ou o Chat!',
			'settings.exports.title' => 'Exportações',
			'settings.map.title' => 'Mapas',
			'settings.map.style.title' => 'Estilo do Mapa',
			'settings.map.styleOpts.automatic' => 'Automático',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Privacidade',
			'settings.privacy.shareAppData.title' => 'Partilhar dados de uso da app',
			'settings.privacy.shareAppData.descriptionOn' => 'A ajudar-nos a melhorar a app partilhando dados de uso, configuração, falhas e desempenho',
			'settings.privacy.shareAppData.descriptionOff' => 'A manter privados os dados de uso da app.\nA equipa Ham2K não poderá detetar falhas ou outros problemas.',
			'settings.privacy.shareOpData.title' => 'Partilhar dados de operação',
			'settings.privacy.shareOpData.descriptionOn' => 'A partilhar alguns dados de operação publicamente e com outros utilizadores',
			'settings.privacy.shareOpData.descriptionOff' => 'A manter os dados de operação privados',
			'settings.privacy.privacyPolicy' => 'Política de Privacidade',
			'settings.privacy.termsOfService' => 'Termos de Serviço',
			'settings.operatorCall' => 'Indicativo do Operador',
			'settings.sync.title' => 'Sincronização na Nuvem',
			'settings.sync.moreSettings' => 'Mais configurações de sincronização',
			'settings.sync.enable' => 'Ativar Sincronização',
			'settings.sync.deviceKey' => 'Chave do Dispositivo',
			'settings.peers.title' => 'Dispositivos Pares',
			'settings.peers.enable' => 'Ligar a outros dispositivos',
			'settings.peers.enableDescription' => 'Permitir partilhar operações, registo, CAT e GPS com outros dispositivos na rede local',
			'settings.peers.bleEnable' => 'Ligar por Bluetooth',
			'settings.peers.bleDescription' => 'Usar Bluetooth LE para ligar mesmo sem rede local',
			'settings.peers.thisDevice' => 'Este Dispositivo',
			'settings.peers.deviceName' => 'Nome',
			'settings.peers.deviceNameHint' => 'Como este dispositivo é visto pelos outros dispositivos',
			'settings.peers.pairedDevices' => 'Dispositivos Vinculados',
			'settings.peers.noPairedDevices' => 'Ainda não há dispositivos vinculados. Ative esta opção noutro dispositivo desta rede para os vincular.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Não é possível ler os dispositivos vinculados: ${error}',
			'settings.peers.nearby' => 'Nas proximidades',
			'settings.peers.connected' => 'Ligado',
			'settings.peers.viaBluetooth' => 'por Bluetooth',
			'settings.peers.connecting' => 'A ligar…',
			'settings.peers.syncing' => 'A sincronizar…',
			'settings.peers.waitingForThem' => 'A aguardar o outro dispositivo',
			'settings.peers.notConnected' => 'Não ligado',
			'settings.peers.wantsToPair' => 'quer partilhar esta operação',
			'settings.peers.allow' => 'Permitir',
			'settings.peers.link' => 'Vincular',
			'settings.peers.reject' => 'Rejeitar',
			'settings.peers.forget' => 'Esquecer',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Esquecer ${name}?',
			'settings.peers.forgetBody' => 'Deixará de sincronizar com este dispositivo. Pode voltar a permiti-lo mais tarde, e os contactos já registados são mantidos.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Vincular com ${name}',
			'settings.peers.pairBody' => 'Este dispositivo está na sua rede local e quer ligar-se.',
			'settings.peers.pairBodyBle' => 'Este dispositivo está próximo e quer ligar-se por Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID do Dispositivo',
			'settings.peers.pairWarning' => 'Vincule apenas dispositivos que reconheça. Qualquer dispositivo nesta rede pode enviar um pedido.',
			'settings.peers.pairWarningBle' => 'Vincule apenas dispositivos que reconheça. Qualquer dispositivo próximo pode enviar um pedido.',
			'settings.peers.problem' => ({required Object error}) => 'Não é possível aceder à rede local: ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth: ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Ligado a ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Ligação a ${device} perdida',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Dispositivos Pares: ${connected} de ${linked} ligados',
			'settings.peers.screenEnable' => 'Partilhar ecrãs e janelas',
			'settings.peers.screenDescription' => 'Permitir que outros dispositivos mostrem ecrãs ou janelas deste computador',
			'settings.peers.screenSources' => 'Ecrãs e Janelas',
			'settings.peers.screenRefresh' => 'Atualizar a lista',
			'settings.peers.screenUnsupportedPlatform' => 'Este dispositivo não pode partilhar o ecrã. O macOS pode; qualquer dispositivo pode mostrar um ecrã partilhado por outro.',
			'settings.peers.screenUnsupportedVersion' => 'Partilhar um ecrã requer o macOS 12.3 ou posterior. Este dispositivo pode na mesma mostrar um ecrã partilhado por outro.',
			'settings.peers.screenNeedsPermission' => 'O macOS precisa da sua permissão para gravar o ecrã antes de esta app poder partilhar um.',
			'settings.peers.screenGrantPermission' => 'Pedir permissão',
			'settings.peers.screenRelaunchAfterGranting' => 'Permita-o nas Definições do Sistema em Privacidade e Segurança → Gravação de Ecrã, depois saia e volte a abrir esta app — o macOS só informa uma app da alteração no arranque seguinte.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Partilha de ecrã: ${error}',
			'settings.peers.screenChooseTitle' => 'Escolher o Que Partilhar',
			'settings.peers.screenChooseButton' => 'Escolher o que partilhar…',
			'settings.peers.screenTabScreens' => 'Ecrãs',
			'settings.peers.screenTabApps' => 'Apps',
			'settings.peers.screenTabWindows' => 'Janelas',
			'settings.peers.screenTabEmpty' => 'Não foi encontrado nada deste tipo.',
			'settings.peers.screenSharedSummaryNone' => 'Ainda nada escolhido.',
			'settings.peers.screenThisDevice' => 'Este dispositivo',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Mostrado em ${devices}',
			'settings.peers.screenSharedToNobody' => 'Não está a ser mostrado',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Deixar de partilhar ${name}',
			'settings.developerMode' => 'Modo de Desenvolvedor',
			'settings.syncPanel.configuration' => 'Configuração da Sincronização',
			'settings.syncPanel.enableTitle' => 'Sincronizar com o Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'A fazer cópia de segurança e a sincronizar o seu registo entre dispositivos',
			'settings.syncPanel.disabledDescription' => 'Desligado — fica apenas neste dispositivo',
			'settings.syncPanel.syncing' => 'A sincronizar',
			'settings.syncPanel.account' => 'Conta',
			'settings.syncPanel.refresh' => 'Atualizar',
			'settings.syncPanel.switchAccounts' => 'Mudar de Conta',
			'settings.syncPanel.switchAccountsDescription' => 'Vincular este dispositivo a outra conta com um código QR ou e-mail',
			'settings.syncPanel.connectionRequests' => 'Pedidos de Ligação',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Um dispositivo está à espera de se juntar a esta conta', other: '${n} dispositivos estão à espera de se juntar a esta conta', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mail da conta',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmação enviada para ${email}. Abra a ligação lá para concluir a alteração.',
			'settings.syncPanel.resendConfirmation' => 'Reenviar E-mail de Confirmação',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'A aguardar ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Enviado novamente para ${email}.',
			'settings.syncPanel.deviceLinked' => 'Esse dispositivo está agora vinculado a esta conta.',
			'settings.syncPanel.checking' => 'A verificar…',
			'settings.syncPanel.notLinked' => 'Ainda não vinculado',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Substituir os dados locais?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} operação', other: '${n} operações', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Dados Sincronizados',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Este dispositivo: ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'A aguardar envio: ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Servidor: ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Este dispositivo: a verificar…',
			'settings.syncPanel.countsServerChecking' => 'Servidor: a verificar…',
			'settings.syncPanel.countsServerUnavailable' => 'Servidor: indisponível',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Isto faz uma cópia de segurança e apaga ${operations} e ${qsos} deste dispositivo, e depois descarrega os dados da conta no seu lugar. A cópia de segurança fica na base de dados deste dispositivo.',
			'settings.syncPanel.replace' => 'Substituir',
			'settings.syncPanel.pendingBannerTitle' => 'Detetada nova conta Ham2K Log Filer',
			'settings.syncPanel.pendingBannerBody' => 'Mantenha as operações e QSOs existentes neste dispositivo e intercale-os na conta, ou substitua-os pelos dados da conta (em ambos os casos fica uma cópia de segurança neste dispositivo).',
			'settings.syncPanel.combine' => 'Intercalar',
			'settings.syncPanel.authIssueTitle' => 'A sincronização não consegue ligar',
			'settings.syncPanel.authIssueText' => 'O Ham2K Log Filer continua a rejeitar este dispositivo. Verifique o seu indicativo nas configurações de Sincronização.',
			'settings.syncPanel.openSettings' => 'Abrir configurações de Sincronização',
			'settings.accounts.title' => 'Contas, Serviços e Fontes de Dados',
			'settings.accounts.none' => 'Nenhuma extensão ativa com contas',
			'settings.accounts.notConfigured' => 'Não configurado',
			'settings.accounts.connected' => 'Ligado',
			'settings.accounts.cancelLogin' => 'Cancelar início de sessão',
			'settings.accounts.openInBrowser' => 'Abrir no Navegador',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Sessão iniciada como ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Prima Guardar para manter esta conta ligada.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Ligado a ${label}',
			'settings.accounts.connect' => 'Ligar',
			'settings.accounts.disconnect' => 'Desligar',
			'settings.accounts.connectedAs' => 'Ligado como',
			'settings.accounts.test' => 'Testar',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Falha ao guardar: ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Falha no início de sessão: ${error}',
			'settings.accounts.lookupFailed' => 'As contas estão indisponíveis neste momento — tente novamente daqui a pouco',
			'settings.accounts.browserLoginTitle' => 'Conclua o início de sessão no navegador',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Quando terminar, o navegador vai tentar abrir uma ligação que começa por "${prefix}". O mais provável é o seu computador não ter nada registado para a abrir, por isso copie essa ligação (da barra de endereço, ou da página de erro que o navegador mostrar) e cole-a aqui.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'O Ham2K Logger não conseguiu abrir o navegador. Copie a ligação de início de sessão abaixo e abra-a manualmente, depois copie a ligação para onde for reencaminhado (começa por "${prefix}") e cole-a aqui.',
			'settings.accounts.copyLoginLink' => 'Copiar ligação de início de sessão',
			'settings.accounts.pastedLinkLabel' => 'Cole a ligação aqui',
			'settings.accounts.finishLogin' => 'Concluir Início de Sessão',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Essa não é a ligação de início de sessão — deve começar por "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Essa ligação pertence a outra tentativa de início de sessão. Feche esta página e ligue novamente.',
			'settings.accounts.pastedLinkNoCode' => 'Essa ligação não tem código de início de sessão. Conclua primeiro o início de sessão, depois copie a ligação para onde for reencaminhado.',
			'settings.accounts.pastedLinkMalformed' => 'Essa ligação parece cortada. Copie-a por inteiro e cole-a novamente.',
			'settings.accounts.relayLoginWaiting' => 'A aguardar que conclua o início de sessão — continuará automaticamente quando o fizer.',
			'settings.accounts.loginNoResponse' => 'Este dispositivo ainda não recebeu resposta do início de sessão. Se já concluiu no navegador, cancele e tente ligar novamente.',
			'settings.accounts.relayLoginNotOpened' => 'O Ham2K Logger não conseguiu abrir o navegador automaticamente. Use o botão abaixo para abrir a página de início de sessão.',
			'settings.accounts.relayLoginUnavailable' => 'Não foi possível contactar o servidor de sincronização necessário para concluir este início de sessão. Verifique a ligação e tente novamente.',
			'settings.accounts.loginIncompleteResponse' => 'Essa tentativa de início de sessão não foi concluída corretamente. Tente ligar novamente.',
			'settings.accounts.noKeyringTitle' => 'Não é possível guardar as credenciais das contas',
			'settings.accounts.noKeyringText' => 'O Ham2K Logger não consegue aceder a um serviço de porta-chaves neste computador, por isso as credenciais das contas não podem ser guardadas nem lidas — ligar uma conta falhará até isto ser resolvido. Instale e inicie o **gnome-keyring**, o **KWallet** ou o **KeePassXC**, ou desbloqueie o porta-chaves que já tem, e reinicie. O registo, as exportações e os ficheiros de dados não são afetados; a sincronização do registo fica desligada enquanto isto durar.',
			'settings.accounts.noKeyringInline' => 'Não é possível guardar credenciais: o porta-chaves deste computador está inacessível. Instale e inicie o gnome-keyring, o KWallet ou o KeePassXC, ou desbloqueie o que tem.',
			'settings.accounts.noSecureStorageInline' => 'Não é possível guardar credenciais: o armazenamento seguro deste computador está inacessível.',
			'settings.station.title' => 'Configuração da Estação e Controlo CAT',
			'settings.station.none' => 'Nenhum equipamento configurado',
			'settings.station.add' => 'Adicionar',
			'settings.station.addTitle' => 'Adicionar equipamento',
			'settings.station.searchHint' => 'Procurar equipamento',
			'settings.station.noMatches' => 'Nenhum equipamento corresponde',
			'settings.station.detectedEquipment' => 'Equipamento Detetado',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Não é possível escutar rádios: ${error}',
			'settings.station.edit' => 'Editar equipamento',
			'settings.station.name' => 'Nome',
			'settings.station.nameDescription' => 'Como lhe chama — "Rádio da Esquerda". Opcional.',
			'settings.station.transport' => 'Ligação',
			'settings.station.host' => 'Endereço',
			'settings.station.hostDescription' => 'O nome de anfitrião ou endereço IP do rádio na sua rede.',
			'settings.station.port' => 'Porta',
			'settings.station.hostRequired' => 'É necessário um endereço',
			'settings.station.portInvalid' => 'A porta tem de estar entre 1 e 65535',
			'settings.station.connect' => 'Ligar',
			'settings.station.disconnect' => 'Desligar',
			'settings.station.remove' => 'Remover',
			'settings.station.removeTitle' => ({required Object name}) => 'Remover ${name}?',
			'settings.station.removeMessage' => 'Isto só o remove da app. As configurações do equipamento ficam como estão.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Tipo de equipamento não reconhecido "${typeKey}"',
			'settings.station.report' => 'Reportar',
			'settings.station.reportTitle' => 'Reportar este rádio',
			'settings.station.reportIntro' => 'Diga-nos que rádio é realmente este e como correu. O seu relatório torna-se um cartão que a equipa Ham2K lê, e o que escrever sobre como o pôs a funcionar pode vir a ajudar o próximo operador com o mesmo equipamento.',
			'settings.station.reportManufacturer' => 'Fabricante',
			'settings.station.reportManufacturerDescription' => 'Quem o fabrica — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'É necessário um fabricante',
			'settings.station.reportModel' => 'Modelo',
			'settings.station.reportModelDescription' => 'O modelo, tal como o próprio rádio lhe chama — "IC-7300", "FT-991A".',
			'settings.station.reportModelRequired' => 'É necessário um modelo',
			'settings.station.reportOutcome' => 'Como correu?',
			'settings.station.reportOutcomeWorks' => 'Funcionou bem',
			'settings.station.reportOutcomeIssues' => 'Funcionou, com problemas',
			'settings.station.reportOutcomeFails' => 'Não funcionou de todo',
			'settings.station.reportOutcomeRequired' => 'Diga-nos como correu',
			'settings.station.reportComments' => 'Comentários',
			'settings.station.reportCommentsPlaceholder' => 'O que funcionou, o que não funcionou, o que o surpreendeu.',
			'settings.station.reportHints' => 'Dicas de resolução de problemas',
			'settings.station.reportHintsPlaceholder' => 'Quer sugerir algumas dicas de resolução de problemas a outros utilizadores?',
			'settings.station.reportSend' => 'Enviar relatório',
			'settings.station.reportSending' => 'A enviar o seu relatório…',
			'settings.station.reportSent' => ({required Object ref}) => 'Obrigado — o seu relatório foi registado como ${ref}.',
			'settings.station.reportSentNoRef' => 'Obrigado — o seu relatório foi enviado.',
			'settings.station.reportFailed' => ({required Object error}) => 'O relatório não foi enviado: ${error}',
			'settings.station.troubleshootingNotes' => 'Notas de Resolução de Problemas',
			'settings.station.mainVfo' => 'VFO Principal',
			'settings.station.useAsMainVfo' => 'Usar como VFO Principal',
			'settings.station.serialPort' => 'Porta série',
			'settings.station.serialPortDescription' => 'A porta onde aparece a interface CAT do rádio.',
			'settings.station.serialPortNone' => 'Nenhuma porta série encontrada',
			'settings.station.serialPortRequired' => 'Escolha uma porta série',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'porta ${n} de ${total}',
			'settings.station.serialPortSuggested' => 'sugerida',
			'settings.station.serialPortJustNow' => 'Ligada recentemente',
			'settings.station.serialDeviceRequest' => 'Adicionar um dispositivo USB…',
			'settings.station.baudRate' => 'Velocidade (baud)',
			'settings.station.baudRateDescription' => 'Tem de corresponder ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo e nenhum erro.',
			'settings.station.serialRtsHigh' => 'Manter RTS alto',
			'settings.station.serialRtsHighDescription' => 'Só para um rádio que espera pelo RTS antes de responder, como um Yaesu com CAT RTS ligado. Num Digirig, SignaLink e na maioria dos cabos caseiros o RTS é o PTT, e mantê-lo alto põe o rádio a transmitir.',
			'settings.station.serialDtrHigh' => 'Manter DTR alto',
			'settings.station.serialDtrHighDescription' => 'Só para uma interface CAT alimentada pelo DTR, como alguns cabos RS-232 para o FT-817. Em muitos cabos o DTR manipula o CW ou o PTT, e mantê-lo alto põe o rádio a transmitir.',
			'settings.station.civAddress' => 'Endereço CI-V do rádio',
			'settings.station.civAddressDescription' => 'Em hexadecimal, tal como aparece no menu CI-V do rádio. O IC-705 vem de fábrica com A4.',
			'settings.station.civAddressInvalid' => 'Um endereço CI-V tem dois dígitos hexadecimais, de 01 a FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Qual das slices do rádio esta ligação lê e sintoniza.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Escolha uma das slices do rádio, de A a H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'A slice ${letter} não está em uso neste rádio — escolha outra slice, ou crie-a no SmartSDR',
			'settings.station.channelNotInUse' => 'não está em uso',
			'settings.station.channelHeldByUnknown' => 'em uso por outro programa',
			'settings.station.flexNoSlices' => 'Este rádio não reportou nenhuma slice — verifique se o SmartSDR está a correr e se este cliente pode subscrever',
			'settings.station.spectrumUnsupported' => 'Este rádio não envia espectro por CAT',
			'settings.station.spectrumRequiresBaud' => 'Requer CAT a 115200 bps',
			'settings.station.spectrumNoRadio' => 'Nenhum rádio ligado',
			'settings.station.spectrumWaiting' => 'A aguardar o espectro do rádio…',
			'settings.station.spectrumUnavailable' => 'A visualização do espectro não está disponível',
			'settings.station.spectrumNoDaxChannel' => 'Todos os canais DAX IQ deste rádio estão em uso',
			'settings.station.spectrumNoPanadapter' => 'Esta slice não tem panadapter no rádio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'O rádio recusou um fluxo DAX IQ (erro ${code})',
			'settings.station.spectrumNoUdp' => 'Os dados de espectro do rádio não chegam a este dispositivo',
			'settings.station.spectrumScopeRefused' => 'O rádio recusou os comandos do scope',
			'settings.station.spectrumOutOfRange' => 'O scope do rádio está definido fora do intervalo que consegue mostrar',
			'settings.station.n3fjpNoRig' => 'O N3FJP não tem nenhuma interface de rádio configurada, por isso isto segue o que é escrito no N3FJP, não um rádio',
			'settings.station.winkeyerKeyPort' => 'Saída de manipulação',
			'settings.station.winkeyerKeyPortDescription' => 'Em qual das duas tomadas de saída do manipulador está ligado o seu rádio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Porta ${n}',
			'settings.station.winkeyerPtt' => 'Usar o PTT do manipulador',
			'settings.station.winkeyerPttDescription' => 'Aciona a linha de PTT na mesma tomada, para um amplificador ou um rádio que precise dela. Deixe desligado para um rádio manipulado pela tomada da chave.',
			'settings.station.winkeyerNoAnswer' => 'Nenhum WinKeyer respondeu nesta porta',
			'settings.station.winkeyerStoppedAnswering' => 'O WinKeyer deixou de responder durante o envio; a mensagem foi descartada',
			'settings.station.radioUser' => 'Nome de utilizador do rádio',
			'settings.station.radioPass' => 'Palavra-passe do rádio',
			'settings.station.radioLoginDescription' => 'O login Network → Remote do rádio, não a palavra-passe do WiFi.',
			'settings.station.radioUserRequired' => 'É necessário o nome de utilizador de controlo remoto do rádio',
			'settings.station.connectFailedBusy' => 'O dispositivo está em uso',
			'settings.station.connectFailedDenied' => 'Acesso negado',
			'settings.station.connectFailedDevice' => 'Dispositivo não encontrado',
			'settings.station.connectFailedLines' => 'Não foi possível manter o RTS/DTR como definido, por isso a porta foi fechada. Outro programa pode ter deixado o controlo de fluxo por hardware ligado — desligue e volte a ligar o cabo.',
			'settings.station.connectFailedNetwork' => 'Não é possível encontrar o rádio na rede. Verifique o endereço e se está ligado e acessível.',
			'settings.station.connectFailedTimeout' => 'O rádio não respondeu a tempo. Verifique se está ligado e acessível.',
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
			'settings.station.models.rigctldNodeName' => 'O Meu Rádio (via rigctld)',
			'settings.station.models.flrig' => 'Rádio controlado via flrig',
			'settings.station.models.flrigNodeName' => 'O Meu Rádio (via flrig)',
			'settings.station.models.hrd' => 'Rádio controlado via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'O Meu Rádio (via HRD)',
			'settings.station.models.n3fjp' => 'Rádio controlado via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'O Meu Rádio (via N3FJP)',
			'settings.station.models.commander' => 'Rádio controlado via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'O Meu Rádio (via Commander)',
			'settings.station.models.antenna' => 'Antena',
			'settings.station.models.key' => 'Chave CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Rádio Genérico (Marcador)',
			'settings.station.models.placeholderRadioNodeName' => 'O Meu Rádio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Comutador Coaxial Sierra Radio CX-1',
			'settings.station.transports.network' => 'Rede/WiFi',
			'settings.station.transports.usbSerial' => 'USB Série',
			'settings.station.transports.wifi' => 'Rede/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Bluetooth Série',
			'settings.station.transports.placeholder' => 'Marcador',
			'settings.station.troubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.ft891Troubleshooting' => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **O CAT RTS tem de estar OFF no rádio** (menu **05-08** do FT-891). Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo. Num Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, por isso subi-la poria o emissor a transmitir. Na porta USB do próprio rádio, a alternativa é **Manter RTS alto** em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao CAT RATE do rádio (menu **05-06**). Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.yaesuBinaryTroubleshooting' => 'Este rádio usa o CAT antigo de cinco bytes da Yaesu, e não responde de todo quando algo está errado. Quase sempre é uma destas causas:\n\n- **O cabo tem de converter níveis.** A tomada CAT na traseira não é RS-232 nem USB; precisa de um CT-62 ou de um adaptador equivalente. Um cabo simples de áudio ou de dados não funciona para CAT.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio (**#14** num FT-817, **#19** num FT-857 ou FT-897). Se não corresponder, o rádio não devolve nada, e nunca um erro.\n- **Nunca deixe nada subir o RTS ou o DTR nesta porta.** Na maioria dos cabos para estes rádios essas linhas são o PTT e a manipulação. Uma interface antiga alimentada pelo DTR é a exceção: para essa, ative **Manter DTR alto** em Configurações Avançadas.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\nEste controlador foi escrito a partir da tabela CAT publicada pela Yaesu e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.guohetecTroubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.guohetecTroubleshooting' => 'O Q900 tem dois protocolos CAT, e esta entrada usa o nativo em vez da imitação do FT-817. Escolha aqui **Guohetec Q900**, não um FT-817 — a imitação suporta menos comandos, e o rádio não diz qual está a usar.\n\n- **O cabo USB-C é a ligação CAT**, e também liga a placa de som. A velocidade não importa nele; a porta ignora o valor definido.\n- **Nunca deixe nada subir o RTS ou o DTR nesta porta.** Num cabo série essas linhas são o PTT e a manipulação.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Um rádio de segunda geração comporta-se de forma diferente** de um de primeira. Prima longamente Menu, depois About: HW 2.0 é a segunda geração.\n\nEste controlador foi escrito a partir do protocolo publicado pelo fabricante e ainda não foi testado com um destes rádios. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.yaesuTroubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.yaesuTroubleshooting' => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo. Num Digirig, SignaLink ou na maioria dos cabos caseiros essa mesma linha é o PTT, por isso subi-la poria o emissor a transmitir. Na porta USB do próprio rádio, a alternativa é **Manter RTS alto** em Configurações Avançadas. O local dessa configuração varia com o modelo (menu **05-08** num FT-891).\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Os modos seguem a tabela do FT-891.** A maior parte da gama Yaesu corresponde-lhe, mas um rádio que numere os modos de outra forma vai mostrar e definir o modo errado nesses casos. A frequência não é afetada.',
			'settings.station.yaesuRs232Troubleshooting' => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **A tomada CAT é RS-232.** Precisa de um adaptador USB-série e de um cabo DB-9 direto — um cabo null-modem troca as linhas, e o rádio nunca recebe nada.\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo, a menos que **Manter RTS alto** esteja ativo em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\nEsta entrada foi escrita a partir de documentação CAT publicada e ainda não foi testada com um destes rádios. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.yaesuUsbTroubleshooting' => 'O rádio está a receber comandos mas não responde. Quase sempre é uma destas causas:\n\n- **Use a primeira das duas portas USB do rádio.** O CAT está normalmente na primeira (a porta COM **Enhanced** no Windows); a segunda (**Standard**) é para PTT e manipulação. O seletor aponta para a primeira sempre que consegue distinguir as duas.\n- **O CAT RTS tem de estar OFF no rádio.** Ligado, o rádio espera por uma linha de handshake que a app mantém em baixo, a menos que **Manter RTS alto** esteja ativo em Configurações Avançadas.\n- **A velocidade tem de corresponder** ao menu CAT RATE do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.',
			'settings.station.k4SerialNotes' => 'Ligue a tomada USB-B (PC) traseira do K4. Tanto USB-PC1 como USB-PC2 servem para CAT; escolha uma porta livre e faça corresponder a configuração Serial USB-PCn: Baud Rate no rádio. O HaLo preenche 38400; altere se necessário. Outra aplicação tem de usar a outra porta ou a Ethernet.\n\nEsta ligação controla o rádio e os seus manipuladores; não envia áudio para o HaLo.',
			'settings.station.k4TcpNotes' => 'Ligue a tomada Ethernet do K4 à sua rede local. Introduza o nome de anfitrião ou o endereço IP e a porta CAT 9200. Isto é controlo CAT, não a ligação de áudio remoto separada na porta 9204.\n\nO HaLo controla o rádio e os seus manipuladores sem transmitir áudio nem dados do panadapter.',
			'settings.station.k4PowerTimeout' => 'A potência do K4 não foi alterada porque o rádio não confirmou a sua gama de saída. Tente novamente.',
			'settings.station.k4PowerRange' => 'A potência do K4 tem de estar entre 0,1–110 W, ou 0,0001–0,01 W quando a saída de miliwatts do transverter está ativa.',
			'settings.station.elecraftTroubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.elecraftTroubleshooting' => 'Os rádios Elecraft falam CAT Kenwood, e um KX2 e um KX3 já foram usados desta forma — VFO nos dois sentidos, mudança de modo e batimento zero em CW, tudo a funcionar.\n\nSe o rádio não responder, quase sempre é uma destas causas:\n\n- **A velocidade tem de corresponder** à definida em **RS232** no menu do rádio. Estes rádios vêm de fábrica com 38400. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n\n**Se a frequência estiver certa mas o modo errado**, diga-nos. As entradas do KX2 e KX3 leem o modo numa posição da resposta de estado do rádio que fixámos a partir dos rádios que vimos, e um firmware que o coloque noutro sítio só chega até nós através de um relatório.\n\nO K3 ainda não foi reportado em nenhum sentido, por isso diga-nos o que acontece se usar um. O K4 tem a sua própria entrada.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Se o rádio liga mas não mostra a frequência',
			'settings.station.kenwoodTroubleshooting' => 'Este controlador está comprovado com os TS-590SG e TS-480 da Kenwood, os QMX e QCX-mini da QRP Labs, e os KX2 e KX3 da Elecraft. O resto da gama foi escrito a partir de referências CAT publicadas, por isso reporte o que acontecer, corra bem ou mal.\n\nSe o rádio não responder, quase sempre é uma destas causas:\n\n- **A velocidade tem de corresponder** ao menu CAT do rádio. Se não corresponder, o rádio devolve lixo ou nada, e nunca um erro.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.\n- **Alguns rádios precisam de ter o CAT ativado** no menu antes de responderem.\n\n**Vários front-ends SDR falam este mesmo protocolo**, por isso vale a pena experimentar esta entrada também com eles; os rádios Elecraft estão listados à parte, em Elecraft. Se a frequência estiver certa mas o modo estiver errado ou em falta, essa é a única parte que difere ao longo da gama — a app deduz o modo a partir do rádio e, se não conseguir, pergunta-lhe diretamente, por isso o modo pode simplesmente chegar com atraso.',
			'settings.station.statusConnected' => 'Ligado',
			'settings.station.statusLost' => 'Desligado',
			'settings.station.notConfigured' => 'Não configurado',
			'settings.station.currentConfiguration' => 'Configuração Atual',
			'settings.station.currentTransceiver' => 'Transcetor Atual',
			'settings.station.radioMode' => 'Modo do Rádio',
			'settings.station.keyerNotSupported' => 'Não suportado pelo rádio atual',
			'settings.station.catControlPreferences' => 'Preferências do Controlo CAT',
			'settings.station.chooseTransceiver' => 'Escolher transcetor',
			'settings.station.configurationSection' => 'Configuração',
			'settings.station.noTransceiverSelected' => 'Nenhum transcetor selecionado',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Usar ${name} como VFO Principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, zero: 'Nenhum transcetor', one: '${count} transcetor', other: '${count} transcetores', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} antena', other: '${count} antenas', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} outro dispositivo', other: '${count} outros dispositivos', ), 
			'settings.station.equipmentInventory' => 'Inventário de Equipamento',
			'settings.station.equipmentInUse' => 'Controlos do Transcetor',
			'settings.station.noTransceiver' => 'Nenhum',
			'settings.station.peerRadioNotAvailable' => 'Indisponível',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Em ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} está noutro dispositivo',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Este rádio está ligado a ${device}. A ligação e as configurações são feitas nesse dispositivo.',
			'settings.station.antennaInUse' => 'Antena em Uso',
			'settings.station.keyInUse' => 'Chave em Uso',
			'settings.station.noneSelected' => 'Nenhuma',
			'settings.station.moreSettings' => 'Mais Configurações',
			'settings.station.icomCivTroubleshootingTitle' => 'Se aparecerem duas portas série para o mesmo rádio',
			'settings.station.icomCivTroubleshooting' => 'Vários rádios Icom, entre eles o IC-705, apresentam **duas** portas série USB ao mesmo tempo (a Icom chama-lhes Port A e Port B), ambas definidas para CI-V por omissão. Nem esta app nem o seu sistema operativo as conseguem distinguir além disso: o mesmo ID de fabricante/produto USB aparece simplesmente duas vezes, por vezes marcado aqui com o sufixo `#2`. **A Port A é normalmente a certa** — em geral a primeira que o sistema operativo ou o navegador lista, e quando esta app consegue distinguir as duas portas marca essa como sugerida. Se os comandos saem e o rádio nunca responde, experimente a outra porta.',
			'settings.station.civAddressTroubleshootingTitle' => 'Se o rádio nunca responder',
			'settings.station.civAddressTroubleshooting' => '- **O endereço CI-V tem de corresponder** ao menu do rádio. Esta entrada preenche o endereço de fábrica do modelo, mas um rádio que partilha um barramento CI-V é exatamente onde ele é alterado. Uma trama enviada para o endereço errado é ignorada em silêncio, o que parece exatamente um cabo avariado.\n- **A velocidade tem de corresponder** ao CI-V BAUD RATE do rádio (em USB, CI-V USB Baud Rate). Defina no rádio o mesmo número mostrado aqui, **não Auto**. Em Auto alguns rádios, entre eles o IC-7300, ligam e deixam de responder ao fim de um minuto ou assim.\n- **Outra app pode estar a ocupar a porta**: o WSJT-X, o fldigi e o rigctld mantêm-na todos aberta.',
			'settings.station.ic7300Mk2Note' => '\n- O **IC-7300 MK2** vem de fábrica com o endereço `B6`, não o `94` aqui preenchido — escolha antes a entrada IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- O **IC-705** apresenta duas portas série USB, ambas com o nome do rádio. O CI-V está na **primeira**, para a qual o seletor aponta sempre que consegue distinguir as duas.',
			'settings.station.ic7760PortNote' => '\n- O **IC-7760** fala CI-V na **Port A** das duas portas série USB que apresenta.',
			'settings.station.x6100PortNote' => '\n- O **X6100** fala CI-V na sua porta **DEV** — a segunda das duas portas série que apresenta, e aquela para a qual o seletor aponta.',
			'settings.station.rigctldTroubleshootingTitle' => 'Se a app não conseguir ligar',
			'settings.station.rigctldTroubleshooting' => 'Isto liga a um **daemon rigctld que executa por sua conta**, não diretamente ao rádio — o backend do Hamlib fala com o rádio e suporta centenas de modelos.\n\n- **O daemon já tem de estar a correr**, por ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Encontre o número de modelo do seu rádio com `rigctl -l`.\n- **A partir de outra máquina**, inicie-o com `-T 0.0.0.0`: por omissão o rigctld só aceita ligações da máquina onde corre.\n- **A porta** é 4532, a menos que tenha iniciado o daemon com `-t`.\n- Depois de ligado, a falta de frequência normalmente significa que o próprio daemon não consegue chegar ao rádio. Teste-o com `rigctl -m 2 f` na máquina do daemon.',
			'settings.station.flrigTroubleshootingTitle' => 'Se a app não conseguir ligar',
			'settings.station.flrigTroubleshooting' => 'Isto liga a um **programa flrig que executa por sua conta**, não diretamente ao rádio — o flrig fala com o rádio e suporta a maioria das marcas e modelos.\n\n- **O flrig já tem de estar a correr**, com o transcetor configurado e ligado.\n- **A porta** é 12345, a menos que a tenha alterado na configuração do flrig (Config → Setup → Server).\n- **A partir de outra máquina**, garanta que o servidor do flrig está acessível. Escuta em todas as interfaces, mas a sua firewall pode não concordar.\n- Depois de ligado, a falta de frequência normalmente significa que o próprio flrig não consegue chegar ao rádio. Verifique se o mostrador do flrig acompanha o botão de sintonia.',
			'settings.station.hrdTroubleshootingTitle' => 'Se a app não conseguir ligar',
			'settings.station.hrdTroubleshooting' => 'Isto liga ao **Rig Control do Ham Radio Deluxe, a correr no seu computador**, não diretamente ao rádio — é o HRD que fala com o rádio.\n\n- **O Rig Control já tem de estar a correr** e ligado ao rádio.\n- **O servidor IP dele tem de estar ativado.** O Rig Control só comunica com outros programas através dele.\n- **A porta** é 7809, a menos que a tenha alterado nas configurações do servidor IP.\n- **A partir de outra máquina**, garanta que a firewall deixa passar a ligação.\n\nEsta entrada foi escrita a partir de descrições publicadas do protocolo do HRD e ainda não foi testada com o HRD. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Se a app não conseguir ligar',
			'settings.station.n3fjpTroubleshooting' => 'Isto liga a **um programa de registo N3FJP a correr no seu computador**, não diretamente ao rádio — é o N3FJP que fala com o rádio.\n\n- **A API do programa tem de estar ligada**: Settings → Application Program Interface, assinale **TCP API Enabled**.\n- **A porta** é 1100, a menos que a tenha alterado aí.\n- **O N3FJP tem de ter uma interface de rádio configurada** para seguir ou sintonizar o rádio. Sem ela, só reporta o que é escrito na sua janela de entrada.\n- O N3FJP só reporta banda, modo e frequência: nem potência, nem estado de transmissão.\n\nEsta entrada foi escrita a partir da API publicada do N3FJP e ainda não foi testada com o N3FJP. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.commanderTroubleshootingTitle' => 'Se a app não conseguir ligar',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshooting' => 'Isto liga ao **DXLab Commander, a correr no seu computador**, não diretamente ao rádio — é o Commander que fala com o rádio.\n\n- **O Commander já tem de estar a correr** e ligado ao rádio.\n- **O serviço de rede dele tem de estar ligado**: o botão **Net Serv** no painel Radio da janela Configuration do Commander.\n- **A porta** é 52002, a terceira porta do bloco que começa na **Base Port** do Net Serv (52000, a menos que a tenha alterado).\n- **A partir de outra máquina**, garanta que a firewall deixa passar a ligação.\n\nEsta entrada foi escrita a partir das mensagens TCP publicadas do Commander e ainda não foi testada com o Commander. Se funcionar só em parte, vale a pena reportar.',
			'settings.station.ic705TroubleshootingTitle' => 'Se o rádio nunca responder',
			'settings.station.ic705Troubleshooting' => 'O rádio tem uma **única** sessão de controlo remoto. Quando o login é ignorado, quase sempre há outra coisa a usá-la.\n\n- **Feche qualquer outro cliente.** Um wfview ou RS-BA1 ligado ao mesmo rádio ocupa essa única sessão, e o login aqui é simplesmente ignorado enquanto isso acontecer.\n- **Verifique as configurações de rede do rádio.** O WLAN tem de estar ligado, o rádio tem de estar na mesma rede, e a função de controlo remoto (Network) tem de estar ativada.\n- **Desligue e volte a ligar o WLAN do rádio** se continuar bloqueado. Isso limpa de forma fiável uma sessão presa no rádio.\n\nUma **palavra-passe errada é recusada explicitamente**, não recebe silêncio. Se chegou aqui em vez de receber uma mensagem de "rejeitado", o problema não é a palavra-passe.',
			'settings.station.statusStale' => 'Não responde',
			'settings.station.statusDisconnected' => 'Não ligado',
			'settings.station.statusConnecting' => 'A ligar…',
			'settings.station.statusDisconnecting' => 'A desligar…',
			'settings.station.statusError' => 'A ligação falhou',
			'settings.station.currentRadioSettings' => 'Configurações atuais do rádio',
			'settings.station.notSupportedByThisRadio' => 'Não suportado por este rádio',
			'settings.station.keyerRowLabel' => 'Manipulador',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Voz',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Manipulador de voz: ${count} memórias no rádio',
			'settings.station.antennaBands' => 'Bandas',
			'settings.station.antennaType' => 'Tipo de antena',
			'settings.station.antennaTypeRequired' => 'Escolha um tipo de antena',
			'settings.station.antennaTypes.dipole' => 'Dipolo',
			'settings.station.antennaTypes.vertical' => 'Vertical',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Direcional',
			'settings.station.antennaTypes.loop' => 'Loop',
			'settings.station.antennaTypes.longWire' => 'Fio Longo / EFHW',
			'settings.station.antennaTypes.other' => 'Outra',
			'settings.station.keyType' => 'Tipo de chave',
			'settings.station.keyTypeRequired' => 'Escolha um tipo de chave',
			'settings.station.keyTypes.straight' => 'Chave Vertical',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semiautomática mecânica)',
			'settings.station.keyTypes.fullyAutomatic' => 'Manipulador totalmente automático',
			'settings.station.keyTypes.singlePaddle' => 'Paddle Simples',
			'settings.station.keyTypes.dualPaddle' => 'Paddle Duplo',
			'settings.station.keyTypes.computerDriven' => 'Controlada por Computador',
			'settings.station.keyTypes.other' => 'Outra',
			'settings.station.softwareIntermediaries' => 'Software Intermediário',
			'settings.station.otherBrands' => 'Outras Marcas',
			'settings.station.otherEquipment' => 'Outro Equipamento (Antenas, Chaves, etc.)',
			'settings.station.newAntenna' => 'Nova Antena',
			'settings.station.newKey' => 'Nova Chave',
			'settings.station.newKeyer' => 'WinKeyer (K1EL ou compatível)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Manipulador CAT em ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Chave em ${device}',
			'settings.station.cwKeyerArea' => 'Área do manipulador',
			'settings.station.trackStationInfo' => 'Guardar Info da Estação em cada QSO',
			'settings.station.includeStationInfoInAdif' => 'Incluir nas exportações ADIF',
			'settings.station.whatToTrack' => 'O que guardar?',
			'settings.station.trackFieldRig' => 'Transcetor',
			'settings.station.trackFieldPower' => 'Potência',
			'settings.station.watts' => 'Watts',
			'settings.station.trackFieldAntenna' => 'Antena',
			'settings.station.trackFieldKey' => 'Chave CW',
			'settings.station.placeholderConnectDelay' => 'Atraso de ligação (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Quanto tempo demora o handshake simulado. Vazio ou 0 liga instantaneamente.',
			'settings.station.placeholderDropAfter' => 'Cair após (segundos)',
			'settings.station.placeholderDropAfterDescription' => 'Fecha a ligação por si só, para testar o caminho de religação. Vazio ou 0 nunca cai.',
			'settings.station.placeholderFailConnect' => 'Falhar sempre a ligação',
			'settings.station.placeholderConnectFailure' => 'O rádio marcador foi instruído a recusar esta ligação',
			'settings.station.placeholderFreq' => 'Frequência (kHz)',
			'settings.station.placeholderFreqDescription' => 'Onde o rádio marcador começa. Depois reporta o que quer que a app sintonize.',
			'settings.station.placeholderMode' => 'Modo',
			'settings.station.placeholderModeDescription' => 'O modo em que o rádio marcador começa, por ex. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Potência (watts)',
			'settings.station.placeholderPurpose' => 'Use este rádio para registar que equipamento está a usar, para efeitos de registo',
			'settings.station.placeholderReplyDelay' => 'Atraso de resposta (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Quanto tempo o rádio marcador demora a reportar uma alteração. Vazio ou 0 responde de imediato.',
			'settings.station.cwKeyerField' => 'Manipulador CW por CAT',
			'settings.station.cwKeyerFieldDescription' => 'Se este rádio manipula CW a partir de texto por CAT. Desligado para um rádio que a app não conhece.',
			'settings.station.voiceMemories' => 'Memórias de voz',
			'settings.station.voiceMemoriesDescription' => 'Quantas memórias de voz o rádio reproduz por CAT. 0 para nenhuma.',
			'settings.station.voiceMemoriesInvalid' => 'Um número inteiro, 0 ou mais',
			'settings.station.yaesuMeterCapture' => 'Capturar leituras dos medidores',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Lê o medidor de potência de saída e o indicador de SWR alta do rádio durante a transmissão e escreve os valores brutos no registo. Serve para construir a escala que a Yaesu não publica — os valores não são mostrados como medidores.',
			'settings.station.yaesuMeterCaptureDescription' => 'Lê os medidores PO, SWR e ALC do rádio durante a transmissão e escreve os valores brutos no registo. Serve para construir a escala que a Yaesu não publica — os valores não são mostrados como medidores.',
			'settings.station.telemetryInterval' => 'Intervalo de leitura dos medidores (ms)',
			'settings.station.telemetryIntervalDescription' => 'Com que frequência ler os medidores do rádio durante a transmissão. Deixe vazio para o mais rápido que esta ligação aguenta, até 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}',
			'settings.station.pollInterval' => 'Intervalo de consulta em repouso (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Com que frequência perguntar ao rádio a frequência e o modo enquanto nenhum deles muda. Deixe vazio para ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Um número inteiro de milissegundos, de ${min} a ${max}',
			'settings.station.advancedSettings' => 'Configurações Avançadas',
			'settings.station.placeholderSwr' => 'Leitura de SWR',
			'settings.station.placeholderSwrDescription' => 'O que este rádio reporta no medidor de SWR durante a transmissão. Acima de 1,8 o painel avisa.',
			'settings.station.placeholderSwrInvalid' => 'Um número, 1 ou mais',
			'settings.station.keyerNone' => 'Nenhum',
			'settings.station.cwDialect' => 'Dialeto de manipulação CW',
			'settings.station.cwDialectDescription' => 'Que forma do comando KY este rádio aceita. Nenhum significa sem manipulação CW por CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, preenchido até 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (texto KY)',
			'settings.station.voiceDialect' => 'Dialeto do manipulador de voz',
			'settings.station.voiceDialectDescription' => 'Como este rádio reproduz as memórias de voz por CAT. Nenhum significa sem memórias de voz por CAT. Com um dialeto e sem número, aplica-se o número predefinido do dialeto.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, estilo TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB e DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (toques de botões)',
			'settings.station.placeholderDiagnostic' => 'Simulado',
			'settings.station.placeholderWholeNumberInvalid' => 'Tem de ser um número inteiro, 0 ou mais',
			'settings.station.placeholderFreqInvalid' => 'Tem de ser uma frequência em kHz, maior que zero',
			'settings.station.placeholderModeInvalid' => 'Tem de ser o nome de um modo, por ex. USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposição',
			'settings.station.switchLayoutDescription' => 'Em que lado do comutador estão ligados os seus rádios.',
			'settings.station.switchLayoutRequired' => 'Escolha como o comutador está ligado',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'O comutador recusou "${command}" (erro ${code})',
			'settings.station.switchBusyTransmitting' => 'Essa porta está a transmitir — antena não alterada',
			'settings.station.switchNoAntenna' => 'Nenhuma',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antena na porta ${port}',
			'settings.station.switchAntennaForDescription' => 'Qual das suas antenas está ligada a esta porta do comutador.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} Antenas, ${radios} Rádios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} Antenas, 1 Rádio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 Antena, ${radios} Rádios',
			'settings.station.switchCommonPort' => 'Comum',
			'settings.station.dcnAddress' => 'Endereço do dispositivo',
			'settings.station.dcnAddressDescription' => 'O endereço definido nos interruptores DIP do módulo. Um módulo de relé coaxial sai de fábrica com 2.',
			'settings.station.dcnAddressRequired' => 'Tem de ser um endereço de dispositivo de 1 a 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Porta ${port}',
			'settings.station.switchPortAutoHint' => 'segue os dados de banda',
			'settings.station.switchPortTransmittingHint' => 'a transmitir — não pode ser alterada agora',
			'settings.station.switchCurrentStateHeader' => 'Estado Atual',
			'settings.station.switchCurrentStateDescription' => 'Em que antena está cada porta de rádio neste momento. As alterações têm efeito imediato.',
			'settings.station.switchWiringHeader' => 'Ligações',
			'settings.station.switchPortInhibitedHint' => 'transmissão inibida',
			'settings.station.configUnreadable' => 'Não foi possível ler as configurações guardadas deste rádio. Abra as configurações e introduza-as novamente, ou remova-o e volte a adicioná-lo.',
			'settings.station.autoConnectHeld' => 'O HaLo deixou de responder da última vez que se ligou a este rádio, por isso desta vez não se ligou sozinho. Prima Ligar para tentar novamente.',
			'settings.offlineData.title' => 'Dados Offline',
			'settings.offlineData.noFiles' => 'Nenhum ficheiro de dados',
			'settings.offlineData.noFilesDescription' => 'Ative extensões de atividades ou de pesquisa para descarregar aqui os seus dados offline.',
			'settings.offlineData.refresh' => 'Atualizar',
			'settings.offlineData.refreshing' => 'A atualizar…',
			'settings.offlineData.updateAll' => 'Atualizar Todos',
			'settings.offlineData.updatingAll' => 'A atualizar todos os ficheiros de dados…',
			'settings.offlineData.neverDownloaded' => 'Nunca descarregado',
			'settings.offlineData.updatedJustNow' => 'Atualizado agora mesmo',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Atualizado há ${days}d',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Atualizado há ${days}d ${hours}h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Atualizado há ${hours}h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Atualizado há ${hours}h ${minutes}m',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Atualizado há ${minutes}m',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'O último download tinha apenas ${imported} de ${existing} registos e não foi usado. Atualize para o aceitar.',
			'settings.offlineData.extensionsSection' => 'Extensões',
			'settings.profiles.notSet' => 'Não definido',
			'settings.profiles.personalInfo' => 'Informações Pessoais',
			'settings.profiles.personalInfoNote' => 'Pode ser incluído nos registos gerados quando for relevante para submissões',
			'settings.profiles.name' => 'Nome',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Clube',
			'settings.profiles.arrlSection' => 'Secção ARRL',
			'settings.profiles.racSection' => 'Secção RAC',
			'settings.profiles.section' => 'Secção',
			'settings.search.clear' => 'Limpar',
			'settings.search.hint' => 'Procurar preferências',
			'settings.developer.developerModeDescription' => 'Ativar avisos de desenvolvimento, registos de depuração e ferramentas.',
			'settings.developer.experiments' => 'Experiências',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} ativada', other: '${count} ativadas', ), 
			'settings.developer.patchTrack' => 'Canal de Code Push',
			'settings.developer.patchTrackDescription' => 'Que anel de code push remoto este dispositivo segue. Anéis mais aventureiros recebem correções mais cedo, menos testadas. Os code pushes aplicam-se no próximo arranque.',
			'settings.developer.trackStable' => 'Estável',
			'settings.developer.trackUnstable' => 'Instável',
			'settings.developer.trackBleeding' => 'Vanguarda',
			'settings.developer.checkingTrack' => ({required Object track}) => 'A procurar um code push em "${track}"…',
			'settings.developer.patchDownloaded' => 'Code push descarregado — reinicie a app para o aplicar.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Nenhum code push novo em "${track}".',
			'settings.developer.noPatchInstalled' => 'Nenhum code push instalado — a correr o binário da versão.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'A correr o code push #${patch}.',
			'settings.developer.deepLinks' => 'Deep links',
			'settings.developer.registerUrlSchemes' => 'Registar esquemas de URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permitir que ligações com.ham2k:// abram esta cópia da app',
			'settings.developer.registerUrlSchemesDone' => 'Esta cópia abre agora ligações com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Não foi possível registar: ${error}',
			'settings.developer.systemInformation' => 'Informações do Sistema',
			'settings.developer.appVersion' => 'Versão da App',
			'settings.developer.dataFolder' => 'Pasta de Dados',
			'settings.developer.loading' => '(a carregar…)',
			'settings.developer.panelLoadFailed' => 'Não foi possível carregar este painel de configurações.',
			'settings.developer.extDevServer' => 'Servidor de Desenvolvimento de Extensões',
			'settings.developer.extensionSettings' => 'Configurações de Extensões',
			'settings.developer.extDevServerDescription' => 'Carregar extensões de um servidor de desenvolvimento na sua rede em vez das integradas na app, e recarregá-las sempre que guardar.',
			'settings.developer.extDevServerAddress' => 'Endereço do servidor',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Ligar',
			'settings.developer.extDevServerDisconnect' => 'Desligar',
			'settings.developer.extDevServerConnecting' => 'A ligar…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'A servir ${count} extensão: ${keys}', other: 'A servir ${count} extensões: ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Não ligado',
			'settings.developer.extDevServerReconnect' => 'Voltar a ligar no arranque',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Último recarregamento: ${key} às ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} extensão com falha na compilação', other: '${count} extensões com falha na compilação', ), 
			'settings.developer.catalog' => 'Catálogo de Extensões',
			'settings.developer.catalogDescription' => 'Ler o catálogo a partir de outro servidor — um local, enquanto trabalha no próprio catálogo. Vazio significa catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Endereço do catálogo',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Canais de Pesquisa do Catálogo',
			'settings.developer.catalogSearchStable' => 'Só Estável',
			'settings.developer.catalogSearchUnstable' => 'Instável ou melhor',
			'settings.developer.catalogSearchBleeding' => 'Vanguarda ou melhor',
			'settings.about.notices' => 'Avisos e Mensagens',
			'settings.about.noticesDescription' => 'Anúncios e mensagens de estado',
			'settings.about.releaseNotes' => 'Notas de Versão',
			'settings.about.copiedVersion' => 'Detalhes da versão copiados para a área de transferência',
			'settings.panels.settings' => 'Preferências da Aplicação',
			'settings.panels.settingsDescription' => 'Faça a app funcionar como quer',
			'settings.panels.commonSettings' => 'Preferências Comuns',
			'settings.panels.syncDescription' => 'Faça cópia de segurança e sincronize os seus registos entre dispositivos',
			'settings.panels.accountsDescription' => 'Credenciais de serviços, dados offline e mais',
			'settings.panels.extensions' => 'Extensões e Funcionalidades',
			'settings.panels.extensionsDescription' => 'Atividades, Concursos, Painéis e mais funcionalidades',
			'settings.panels.profilesDescription' => 'Indicativo do operador e perfil da estação',
			'settings.panels.stationProfiles' => 'Perfis de Estação',
			'settings.panels.developerSettings' => 'Configurações do Desenvolvedor',
			'settings.panels.developerSettingsDescription' => 'Ferramentas de depuração e desenvolvimento',
			'settings.panels.about' => 'Sobre',
			'settings.panels.aboutDescription' => 'Versão, créditos e informação legal',
			'settings.panels.unavailableTitle' => 'Algumas configurações estão indisponíveis',
			'settings.panels.unavailableText' => 'As extensões não arrancaram, por isso faltam as configurações que elas fornecem.',
			'settings.panels.station' => 'Configuração da Estação',
			'settings.panels.stationDescription' => 'Controlo CAT e mais opções',
			'settings.panels.peers' => 'Dispositivos Pares',
			'settings.panels.peersDescription' => 'Ligar a outros dispositivos próximos',
			'settings.showMoreSettings' => 'Mostrar mais configurações',
			'settings.gridPrecision' => 'Precisão do Grid',
			'settings.gridPrecisionOpts.six' => '6 dígitos (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 dígitos (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 dígitos',
			'settings.gridPrecisionDescription.eight' => '8 dígitos',
			'commands.enableSyncFirst' => 'Ative primeiro a sincronização nas Configurações.',
			'commands.fullResyncStarted' => 'Ressincronização completa iniciada — os dados locais foram primeiro salvaguardados.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Nenhum ficheiro de dados corresponde a "${target}".',
			'commands.reloadFailed' => ({required Object error}) => 'O recarregamento falhou: ${error}',
			'commands.reloadingAll' => 'A recarregar todos os ficheiros de dados…',
			'commands.reloadingTarget' => ({required Object target}) => 'A recarregar os ficheiros de dados de ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Experiência desconhecida "${token}"',
			'commands.experimentEnabled' => ({required Object name}) => '${name} ativada',
			'commands.experimentDisabled' => ({required Object name}) => '${name} desativada',
			'commands.sentryTestSent' => 'Relatório de erro de teste enviado para o Sentry',
			'commands.sentryTestLocalOnly' => 'O Sentry está desativado nesta build — erro de teste registado apenas localmente',
			'commands.noOperationOpen' => 'Esse comando precisa de uma operação aberta',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Não é possível marcar um \'${kind}\'',
			'commands.operationAlreadyStarted' => 'Esta operação já tem um marcador de início',
			'commands.couldNotOpenLocation' => 'A pausa foi adicionada, mas não foi possível abrir o ecrã de localização',
			'commands.noTestOperations' => 'Nenhuma Operação de Teste para purgar',
			'commands.purgeTestsUnavailable' => 'O PURGETESTS precisa de mostrar um diálogo de confirmação, que não está disponível aqui',
			'commands.syncAllUnavailable' => 'O SYNCALL precisa de mostrar um diálogo de confirmação, que não está disponível aqui',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} Operação de Teste purgada', other: '${count} Operações de Teste purgadas', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '${purged} de ${total} Operações de Teste purgadas — as restantes falharam; tente PURGETESTS novamente',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contacto de teste sem operação purgado', other: '${count} contactos de teste sem operação purgados', ), 
			'commands.purgeTestsContactsFailed' => 'As Operações de Teste foram purgadas, mas os contactos de teste sem operação falharam; tente PURGETESTS novamente',
			'commands.purgeTestsNothingToDo' => 'Nada foi purgado',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '${removed} de ${total} Operações de Teste removidas — as restantes falharam; tente Rever novamente',
			'commands.receivedPurgesFailed' => 'Não foi possível remover essas Operações de Teste — tente Rever novamente',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} Operação de Teste foi removida noutro dispositivo', other: '${count} Operações de Teste foram removidas noutro dispositivo', ), 
			'commands.receivedPurgesReview' => 'Rever',
			'commands.settingOn' => 'Ligado',
			'commands.settingOff' => 'Desligado',
			'commands.settingEmpty' => '(vazio)',
			'commands.settingSecretSet' => '(definido)',
			'commands.settingSecretUnset' => '(não definido)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} selecionados',
			'commands.settingExpectsOnOff' => 'ligado ou desligado',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'um de: ${choices}',
			'commands.settingExpectsNumber' => 'um número',
			'commands.settingVanished' => ({required Object label}) => '“${label}” já não está disponível',
			'commands.noCwKeyer' => 'Nenhum rádio ligado consegue manipular CW',
			'commands.noKeyer' => 'Nenhum rádio ligado consegue manipular CW nem reproduzir memórias de voz',
			'commands.keyerNeedsOperation' => 'Abra uma operação para usar o manipulador CW',
			'commands.keyerExperimentOff' => 'A manipulação CW está desligada — ligue-a com EXP KEYER',
			'commands.esmExperimentOff' => 'Enter Envia Mensagens está desligado — ligue-o com EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'A enviar CW: ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Mensagem CW F${n}: ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'A mensagem CW F${n} não foi enviada: as extensões não estão prontas',
			'commands.settingNotStored' => ({required Object label}) => '“${label}” não aceitou esse valor',
			'commandDialog.hint' => 'Procure indicativos ou escreva um comando',
			'commandDialog.noResults' => ({required Object text}) => 'Nada corresponde a “${text}”',
			'commandDialog.sectionCommands' => 'Comandos',
			'commandDialog.sectionGoTo' => 'Ir para',
			'commandDialog.sectionOperations' => 'Operações',
			'commandDialog.goHome' => 'Início',
			'commandDialog.goSettings' => 'Configurações',
			'commandDialog.goNewOperation' => 'Nova operação',
			'commandDialog.runTyped' => ({required Object text}) => 'Executar “${text}”',
			'commandDialog.sectionSuggestions' => 'Experimente',
			'commandDialog.lookingUp' => 'A pesquisar indicativo…',
			'commandDialog.blockedByPane' => 'Não é possível usar comandos com um painel ou diálogo aberto',
			'expiredBuild.title' => 'Esta build expirou',
			'expiredBuild.body' => 'Visite ham2k.com e obtenha uma versão mais recente.',
			'expiredBuild.visit' => 'Visitar ham2k.com',
			'expiredBuild.dismiss' => 'Continuar mesmo assim',
			'staleness.codePushFloorTitle' => 'Uma atualização importante está à espera',
			'staleness.codePushFloorBody' => 'Esta versão tem uma correção que ainda não tem.',
			'staleness.restartToApply' => 'Reinicie a app para a aplicar.',
			'staleness.quitAndReopen' => 'Saia da app e abra-a novamente para a aplicar.',
			'staleness.reopenToApply' => 'Feche a app e abra-a novamente para a aplicar.',
			'staleness.ignoreForNow' => 'Ignorar por agora',
			'spotting.noQsoYet' => 'Ainda não há QSO registado para fazer spot.',
			'spotting.setFrequencyFirst' => 'Defina primeiro uma frequência.',
			'spotting.nothingToSpot' => 'Nada para fazer spot — nenhuma extensão oferece spotting aqui.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => '${source} falhou: ${message}',
			'spotting.unknownError' => 'erro desconhecido',
			'spotting.notSent' => 'Spot não enviado.',
			'spotting.notRefreshedOffline' => 'Sem ligação — os spots não foram atualizados',
			'dataFiles.downloading' => 'A descarregar…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Não foi possível descarregar ${name}',
			'dataFiles.downloadFailedWebHint' => 'Pode ser um problema de rede, ou o servidor desta ligação pode não permitir downloads diretos a partir de um navegador. Experimente a app de computador ou móvel, ou outro local de alojamento.',
			'dataFiles.downloadTimedOut' => 'O servidor demorou demasiado a responder. Tente novamente mais tarde.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} respondeu com um erro (HTTP ${status}). Tente novamente mais tarde.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} não conseguiu fornecer este ficheiro (HTTP ${status}). Verifique se o endereço ainda está certo.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Não foi possível processar ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'O download tinha apenas ${imported} dos ${existing} registos deste dispositivo, por isso os que ficaram de fora foram mantidos. Atualizá-lo em Configurações › Dados Offline aceita-o mesmo assim.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} registo importado para ${label}.', other: '${count} registos importados para ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Dados importados para ${label}.',
			'dataFiles.cleanedUpTitle' => 'Dados de extensões limpos',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Removidos os dados de ${count} ficheiro de dados de extensões desativadas.', other: 'Removidos os dados de ${count} ficheiros de dados de extensões desativadas.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} registos',
			'dataFiles.definitionUnavailable' => 'A origem do ficheiro não forneceu uma definição — a extensão pode estar a reiniciar ou mal configurada. Tente novamente daqui a pouco.',
			'updates.updateAvailable' => 'Atualização disponível',
			'updates.newVersionAvailable' => ({required Object version}) => 'Está disponível uma nova versão (${version}).',
			'updates.getIt' => 'Obter',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Atualização pronta',
			'updates.restartToApply' => 'Foi descarregada uma atualização. Reinicie para a aplicar.',
			'updates.appliesNextLaunch' => 'Foi descarregada uma atualização. Será aplicada da próxima vez que abrir a app.',
			'updates.restartNow' => 'Reiniciar agora',
			'updates.reloadToUpdate' => 'Está disponível uma versão mais recente desta página. Recarregue para a obter.',
			'updates.reloadNow' => 'Recarregar agora',
			'updates.checkForUpdates' => 'Procurar Atualizações',
			'updates.checkingForUpdates' => 'A verificar atualizações…',
			'updates.upToDate' => 'Atualizado',
			'updates.automaticChecks' => 'Verificar automaticamente',
			'updates.automaticChecksDescription' => 'Procurar novas versões em segundo plano, a partir da próxima vez que iniciar a app',
			'extensionService.runtimeNotReady' => 'As extensões ainda não estão prontas.',
			'extensionService.testFailed' => ({required Object error}) => 'O teste falhou: ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Ligado como ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuração de campo inválida',
			'extensionService.invalidValue' => 'Valor inválido',
			'extensionService.validationError' => ({required Object error}) => 'Erro de validação: ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'A ação falhou: ${error}',
			'extensionService.commandFailed' => 'Não foi possível executar o comando',
			'extensionService.reportUnavailable' => 'Não é possível enviar relatórios neste momento',
			'extensionService.stashUnavailable' => 'O Arquivo de Ficheiros do Ham2K está inacessível neste momento',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} gastou demasiado tempo nos seus temporizadores. Ficam parados até as extensões reiniciarem.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Os temporizadores de ${name} continuaram a falhar. Ficam parados até as extensões reiniciarem.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} ficou bloqueado num temporizador. Os seus temporizadores ficam parados até as extensões reiniciarem.',
			'operationLocationScreen.title' => 'Localização da Operação',
			'operationLocationScreen.selectedLocation' => 'Localização Selecionada',
			'operationLocationScreen.gridSquare' => 'Localizador Maidenhead (Grid)',
			'operationLocationScreen.gridInvalid' => 'Precisa de 4, 6, 8 ou 10 caracteres, como FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Localizações Sugeridas',
			'operationLocationScreen.deviceGps' => 'GPS do Dispositivo',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de ${device}',
			'operationLocationScreen.locating' => 'A localizar…',
			'operationLocationScreen.gpsUnavailable' => 'Localização indisponível',
			'operationLocationScreen.permissionDenied' => 'Permissão de localização negada',
			'operationLocationScreen.permissionBlocked' => 'Permissão de localização bloqueada',
			'operationLocationScreen.moreDetails' => 'Mais Detalhes',
			'operationLocationScreen.stateOrProvince' => 'Estado ou Província (opcional)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Controlos da atividade indisponíveis',
			'operationLocationScreen.controlsUnavailableReason' => 'Estas referências continuam utilizáveis; só não foi possível contactar as suas atividades.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Tentar novamente',
			'operationLocationScreen.county' => 'Município (opcional)',
			'versionLabel.version' => ({required Object version}) => 'Versão ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Patch ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Ainda sem avisos',
			'notices.webStorageInMemory' => 'Este navegador não conseguiu fornecer armazenamento persistente — o registo fica apenas em memória e será PERDIDO quando este separador for fechado. Use uma versão atual do Chrome, Firefox, Safari ou Edge.',
			'notices.webStorageUnreliable' => 'Este navegador está a usar um armazenamento alternativo que não é seguro com vários separadores — mantenha apenas um separador aberto, e mantenha a sincronização ligada.',
			'notices.logFromNewerBuildTitle' => 'Este registo precisa de uma versão mais recente',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'O seu registo foi escrito por uma versão mais recente do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), por isso não pode ser aberto, e os novos contactos não serão guardados. Instale novamente a versão mais recente — ou, se pretendia correr esta build, aponte-a para outra pasta de dados. O registo está em ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'O seu registo foi escrito por uma versão mais recente do HaLo (versão de armazenamento ${storage}; esta entende ${understood}), por isso não pode ser aberto, e os novos contactos não serão guardados. Abra antes este registo com essa versão mais recente.',
			'notices.preferencesRestoredTitle' => 'Configurações repostas a partir de uma cópia de segurança',
			'notices.preferencesRestored' => 'Não foi possível ler o ficheiro de configurações, por isso o HaLo repôs a última cópia válida. O que alterou na sessão anterior pode ter de ser definido novamente. O ficheiro ilegível fica guardado ao lado, com o nome shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Configurações repostas',
			'notices.preferencesReset' => 'Não foi possível ler o ficheiro de configurações e não havia cópia de segurança a que recorrer, por isso o HaLo arrancou com as predefinições. O ficheiro ilegível fica guardado na pasta de dados da app, com o nome shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} não foi ligado automaticamente',
			'notices.autoConnectHeld' => ({required Object name}) => 'O HaLo deixou de responder da última vez que começou a ligar-se a ${name}, por isso desta vez não lhe tocou, para não arriscar que voltasse a acontecer. Verifique se o rádio está ligado e o cabo está ligado, e depois prima Ligar nesse rádio nas Configurações.',
			'syncAccount.anonymous' => ({required Object id}) => 'Conta Anónima (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (confirmação pendente)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (confirmação pendente - #${id})',
			'deepLink.needsAnOperation' => 'Inicie primeiro uma operação, e depois envie esse contacto novamente',
			'deepLink.waitingInOperation' => 'Esse contacto está à espera na operação por trás deste ecrã',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Este dispositivo não tem nenhuma atividade para ${refs}, por isso essas referências ficaram de fora',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Não foi possível contactar as suas atividades, por isso ${refs} ficou de fora — tente essa ligação novamente',
			'confirmDevice.title' => 'Confirmar um Dispositivo',
			'confirmDevice.codePrompt' => 'Introduza o código mostrado no dispositivo que se quer juntar a esta conta.',
			'confirmDevice.code' => 'Código',
			'confirmDevice.lookUp' => 'Procurar',
			'confirmDevice.codeNotFound' => 'Nenhum pedido corresponde a esse código. Os códigos expiram ao fim de 10 minutos — peça um novo ao outro dispositivo.',
			'confirmDevice.linkExpired' => 'Essa ligação expirou. Peça ao outro dispositivo que mostre um novo código QR.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Vincular ${device} a esta conta?',
			'confirmDevice.unnamedDevice' => 'um dispositivo sem nome',
			'confirmDevice.grantWarning' => 'Poderá ler e alterar todas as operações e QSOs desta conta.',
			'confirmDevice.needsSyncTitle' => 'Este dispositivo ainda não sincroniza',
			'confirmDevice.needsSyncText' => 'Ative a sincronização Ham2K Log Filer e vincule este dispositivo a uma conta antes de poder admitir outro.',
			'confirmDevice.malformedRequest' => 'O servidor de sincronização enviou um pedido que esta app não conseguiu ler. Peça ao outro dispositivo que tente novamente.',
			'confirmDevice.linkIt' => 'Vincular Dispositivo',
			'switchAccounts.noAccountDetails' => 'Ainda sem detalhes da conta',
			'switchAccounts.currentAccount' => 'Conta atual',
			'switchAccounts.otherAccounts' => 'Outras contas',
			'switchAccounts.linkToAnother' => 'Vincular a outra conta',
			'switchAccounts.linkWithSibling' => 'Vincular com outra App Ham2K',
			'switchAccounts.linkWithPolo' => 'Vincular com a conta da versão anterior',
			'switchAccounts.linkWithSiblingDescription' => 'Tem outra app Ham2K instalada. Vincule com a conta usada nela.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Aprove o pedido em ${app}, e depois volte aqui.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Abrir ${app} novamente',
			'switchAccounts.siblingNoGrant' => 'Não funcionou? Abra-a novamente, ou volte atrás e vincule de outra forma.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Não foi possível abrir ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'A ligação expirou e está pronta uma nova — abra ${app} novamente.',
			'switchAccounts.tryAgain' => 'Tentar novamente',
			'switchAccounts.linkWithQr' => 'Vincular com um código QR',
			'switchAccounts.linkWithQrDescription' => 'Leia-o a partir de um dispositivo que já usa a conta',
			'switchAccounts.linkWithEmail' => 'Vincular com um endereço de e-mail',
			'switchAccounts.linkWithEmailDescription' => 'Confirme com um código ou uma ligação por e-mail',
			'switchAccounts.enterEmailPrompt' => 'Introduza o endereço de e-mail da conta que quer que este dispositivo use.',
			'switchAccounts.emailAddress' => 'Endereço de e-mail',
			'switchAccounts.linkAccount' => 'Vincular conta',
			'switchAccounts.copiedCode' => 'Código copiado para a área de transferência',
			'switchAccounts.copyCode' => 'Copiar código',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Abra a app Ham2K num dispositivo já vinculado a ${email} e introduza este código para aprovar o pedido:',
			'switchAccounts.waitingForConfirmation' => 'A aguardar confirmação…',
			'switchAccounts.sendEmailInstead' => 'Enviar antes um e-mail de confirmação',
			'switchAccounts.emailSent' => ({required Object email}) => 'Foi enviado um e-mail para ${email}. Abra-o e confirme o pedido para vincular este dispositivo.',
			'switchAccounts.resendEmail' => 'Reenviar e-mail',
			'switchAccounts.qrPrompt' => 'Leia este código QR a partir de um dispositivo já vinculado à conta que quer — por exemplo com o Ham2K Portable Logger no seu telemóvel.',
			'switchAccounts.serverUnreachable' => 'Não foi possível contactar o servidor de sincronização. Tente novamente mais tarde.',
			'switchAccounts.emailRequired' => 'Introduza um endereço de e-mail para vincular.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Nenhuma conta encontrada para ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'O servidor de sincronização rejeitou o pedido: ${error}',
			'switchAccounts.noLinkCode' => 'O servidor de sincronização não devolveu um código de ligação. Tente novamente mais tarde.',
			'switchAccounts.noConfirmationCode' => 'O servidor de sincronização não enviou um código de confirmação. Tente novamente mais tarde.',
			'switchAccounts.switchNotAccepted' => 'Essa conta não aceitou a mudança. Tente antes vinculá-la com um endereço de e-mail.',
			'switchAccounts.requestFailed' => 'Algo correu mal na comunicação com o servidor de sincronização. Tente novamente mais tarde.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} operação', other: '${count} operações', ), 
			'adifImport.title' => 'Importar QSOs de ADIF',
			'adifImport.reading' => ({required Object filename}) => 'A ler ${filename}…',
			'adifImport.dropHint' => 'Largue um ficheiro ADIF para importar',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} QSO neste ficheiro', other: '${formatted} QSOs neste ficheiro', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} já no seu registo', other: '${formatted} já no seu registo', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} será importado', other: '${formatted} serão importados', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contacto novo', other: '${formatted} contactos novos', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} será intercalado com um contacto existente', other: '${formatted} serão intercalados com contactos existentes', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} não pode ser importado (sem indicativo)', other: '${formatted} não podem ser importados (sem indicativo)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} precisa de uma análise mais atenta', other: '${formatted} precisam de uma análise mais atenta', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'Não foi possível recuperar as referências de ${count} contacto', other: 'Não foi possível recuperar as referências de ${formatted} contactos', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: 'As referências ${programs} podem estar incompletas em ${count} contacto', other: 'As referências ${programs} podem estar incompletas em ${formatted} contactos', ), 
			'adifImport.stackingTypesUnknown' => 'Os contactos combinados podem perder uma referência — as atividades não conseguiram indicar que tipos se acumulam. Cancele e tente novamente para evitar isto.',
			'adifImport.nothingToImport' => 'Nada neste ficheiro pode ser importado',
			'adifImport.confirm' => 'Importar',
			'adifImport.importing' => ({required Object filename}) => 'A importar ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} contacto importado de ${filename}', other: '${formatted} contactos importados de ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Não foi possível importar ${filename}: ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} não parece ser um ficheiro ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Aviso: este ADIF tem QSOs de ${calls}, mas serão importados como ${station} se continuar.',
			'adifImport.stationCallJoin' => ' e ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('pt'))(count, one: '${count} não tem data e não pode ser importado', other: '${formatted} não têm data e não podem ser importados', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Este ficheiro regista uma ativação de ${refs}.',
			'adifImport.addActivation' => 'Adicioná-la a esta operação',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Só foi possível aplicar ${written} de ${planned} — o registo mudou enquanto decidia.',
			'adifImport.busy' => 'Já está a decorrer uma importação. Aguarde que termine antes de iniciar outra.',
			'adifImport.oneFileOnly' => 'Largue um ficheiro ADIF de cada vez — a ordem em que os ficheiros são importados decide que dados prevalecem.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} tem mais de ${limit} QSOs, o máximo que uma operação pode importar de uma vez.',
			'offline.statusOffline' => 'Internet: OFFLINE',
			'offline.statusOnline' => 'Internet: ligada',
			'offline.noRoute' => 'Sem qualquer ligação de rede.',
			'offline.unreachable' => 'A rede está ativa, mas nenhum servidor responde — muitas vezes sinal de uma página de início de sessão à espera num navegador.',
			'offline.reachable' => 'Todos os serviços estão a responder como esperado.',
			'offline.whatStops' => 'As pesquisas, os spots e os ficheiros de dados estão em pausa. O registo e a sincronização próxima não.',
			'offline.servicesTitle' => 'Serviços',
			'offline.noServices' => 'Nenhum serviço reportou ainda.',
			'offline.lastSuccess' => ({required Object when}) => 'Respondeu pela última vez há ${when}',
			'offline.neverSucceeded' => 'Ainda não respondeu',
			'offline.nextAttempt' => ({required Object when}) => 'Próxima tentativa daqui a ${when}',
			'offline.nextAttemptNow' => 'Próxima tentativa agora',
			'offline.retry' => 'Tentar agora',
			'offline.retrying' => 'A tentar…',
			'offline.retryReached' => 'Novamente online.',
			'offline.retryUnreachable' => 'Continua sem resposta.',
			'offline.retryNotAttempted' => 'Nada para enviar neste momento.',
			'offline.retryThrottled' => 'Acabou de tentar — aguarde um momento.',
			'offline.retryDisabled' => 'A sincronização está desligada, por isso não há nada com que testar.',
			'offline.syncService' => 'Sincronização Ham2K LoFi',
			'offline.retryInFlight' => 'Já está a tentar — aguarde.',
			'exportSettings.defaultsDescription' => 'Configurações base para todas as exportações, com modelos de nome de ficheiro e de título separados para atividades de referência e outras atividades. Cada tipo de exportação pode ter as suas próprias predefinições ou configurações personalizadas.',
			'exportSettings.referenceActivities' => 'Atividades de Referência',
			'exportSettings.otherActivities' => 'Outras Atividades',
			'exportSettings.adifFields' => 'Campos ADIF',
			'exportSettings.loadFailed' => 'Não foi possível carregar as configurações de exportação.',
			'exportSettings.retry' => 'Tentar novamente',
			'exportSettings.compactFileNamesDescriptionOn' => 'Nomes de ficheiro compactos, como N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Nomes de ficheiro descritivos, como 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'A incluir nomes, moradas, e-mails, notas e localizações precisas nos ficheiros ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'A omitir nomes, moradas, e-mails e notas; a limitar as localizações a grids de seis caracteres.',
			'exportSettings.includeLookupDataDescriptionOn' => 'A incluir informação de serviços de pesquisa de indicativos.',
			'exportSettings.includeLookupDataDescriptionOff' => 'A omitir informação de serviços de pesquisa de indicativos; a manter os valores introduzidos manualmente.',
			'exportSettings.customTemplatesDescriptionOn' => 'Os seus modelos personalizados estão ativos e podem ser editados abaixo.',
			'exportSettings.customTemplatesDescriptionOff' => 'Os modelos predefinidos estão ativos. Os seus modelos personalizados ficam guardados para mais tarde.',
			'exportSettings.type' => 'Tipo de exportação',
			'exportSettings.defaults' => 'Predefinições',
			'exportSettings.includeLookupData' => 'Incluir dados de pesquisa',
			'exportSettings.customTemplates' => 'Modelos personalizados',
			'exportSettings.filenameTemplate' => 'Modelo de nome de ficheiro',
			'exportSettings.compactFilenameTemplate' => 'Modelo de nome de ficheiro compacto',
			'exportSettings.titleTemplate' => 'Modelo de título',
			'exportSettings.adifNotesTemplate' => 'Notas de QSO ADIF',
			'exportSettings.adifCommentTemplate' => 'Comentários de QSO ADIF',
			'exportSettings.adifQslMessageTemplate' => 'Mensagem de QSL ADIF',
			'exportSettings.shared' => 'As configurações aplicam-se a todas as extensões que usam este tipo de exportação.',
			'exportSettings.defaultTemplates' => 'Ative Modelos personalizados para editar os modelos deste tipo.',
			'templateEditor.previewLabel' => 'Pré-visualização:',
			'templateEditor.reset' => 'Repor',
			'templateEditor.docs' => 'Documentação de Modelos',
			'templateEditor.preview' => 'Pré-visualização de exemplo',
			'templateEditor.reference' => 'Referência de modelos',
			'templateEditor.attributes' => 'Atributos Disponíveis',
			'templateEditor.filters' => 'Filtros',
			'templateEditor.flowControl' => 'Controlo de Fluxo',
			'templateEditor.unavailable' => 'A pré-visualização fica indisponível até as extensões estarem prontas.',
			'templateEditor.empty' => '(resultado vazio)',
			_ => null,
		};
	}
}
