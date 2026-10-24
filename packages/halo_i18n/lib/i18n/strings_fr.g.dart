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
class TranslationsFr extends Translations with BaseTranslations<AppLocale, Translations> {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ),
		  super(cardinalResolver: cardinalResolver, ordinalResolver: ordinalResolver) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key) ?? super[key];

	late final TranslationsFr _root = this; // ignore: unused_field

	@override 
	TranslationsFr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFr(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$common$fr common = _Translations$common$fr._(_root);
	@override late final _Translations$onboarding$fr onboarding = _Translations$onboarding$fr._(_root);
	@override late final _Translations$startScreen$fr startScreen = _Translations$startScreen$fr._(_root);
	@override late final _Translations$testerOverlay$fr testerOverlay = _Translations$testerOverlay$fr._(_root);
	@override late final _Translations$extensionsPanel$fr extensionsPanel = _Translations$extensionsPanel$fr._(_root);
	@override late final _Translations$home$fr home = _Translations$home$fr._(_root);
	@override late final _Translations$chase$fr chase = _Translations$chase$fr._(_root);
	@override late final _Translations$dialogs$fr dialogs = _Translations$dialogs$fr._(_root);
	@override late final _Translations$operation$fr operation = _Translations$operation$fr._(_root);
	@override late final _Translations$map$fr map = _Translations$map$fr._(_root);
	@override late final _Translations$mapsView$fr mapsView = _Translations$mapsView$fr._(_root);
	@override late final _Translations$activitiesView$fr activitiesView = _Translations$activitiesView$fr._(_root);
	@override late final _Translations$loggingControls$fr loggingControls = _Translations$loggingControls$fr._(_root);
	@override late final _Translations$formChrome$fr formChrome = _Translations$formChrome$fr._(_root);
	@override late final _Translations$qsoEditForm$fr qsoEditForm = _Translations$qsoEditForm$fr._(_root);
	@override late final _Translations$qsoList$fr qsoList = _Translations$qsoList$fr._(_root);
	@override late final _Translations$loggingPanel$fr loggingPanel = _Translations$loggingPanel$fr._(_root);
	@override late final _Translations$callInfo$fr callInfo = _Translations$callInfo$fr._(_root);
	@override late final _Translations$settings$fr settings = _Translations$settings$fr._(_root);
	@override late final _Translations$commands$fr commands = _Translations$commands$fr._(_root);
	@override late final _Translations$commandDialog$fr commandDialog = _Translations$commandDialog$fr._(_root);
	@override late final _Translations$expiredBuild$fr expiredBuild = _Translations$expiredBuild$fr._(_root);
	@override late final _Translations$staleness$fr staleness = _Translations$staleness$fr._(_root);
	@override late final _Translations$spotting$fr spotting = _Translations$spotting$fr._(_root);
	@override late final _Translations$dataFiles$fr dataFiles = _Translations$dataFiles$fr._(_root);
	@override late final _Translations$updates$fr updates = _Translations$updates$fr._(_root);
	@override late final _Translations$extensionService$fr extensionService = _Translations$extensionService$fr._(_root);
	@override late final _Translations$operationLocationScreen$fr operationLocationScreen = _Translations$operationLocationScreen$fr._(_root);
	@override late final _Translations$versionLabel$fr versionLabel = _Translations$versionLabel$fr._(_root);
	@override late final _Translations$notices$fr notices = _Translations$notices$fr._(_root);
	@override late final _Translations$syncAccount$fr syncAccount = _Translations$syncAccount$fr._(_root);
	@override late final _Translations$deepLink$fr deepLink = _Translations$deepLink$fr._(_root);
	@override late final _Translations$confirmDevice$fr confirmDevice = _Translations$confirmDevice$fr._(_root);
	@override late final _Translations$switchAccounts$fr switchAccounts = _Translations$switchAccounts$fr._(_root);
	@override late final _Translations$adifImport$fr adifImport = _Translations$adifImport$fr._(_root);
	@override late final _Translations$offline$fr offline = _Translations$offline$fr._(_root);
	@override late final _Translations$exportSettings$fr exportSettings = _Translations$exportSettings$fr._(_root);
	@override late final _Translations$templateEditor$fr templateEditor = _Translations$templateEditor$fr._(_root);
}

// Path: common
class _Translations$common$fr extends Translations$common$en {
	_Translations$common$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get save => 'Enregistrer';
	@override String get ok => 'OK';
	@override String get cancel => 'Annuler';
	@override String get delete => 'Supprimer';
	@override String get create => 'Créer';
	@override String get error => 'Erreur';
	@override String get close => 'Fermer';
	@override String get done => 'Terminé';
	@override String get callsign => 'Indicatif';
	@override String get clear => 'Effacer';
	@override String get dismiss => 'Ignorer';
	@override String get expand => 'Développer';
	@override String get collapse => 'Réduire';
}

// Path: onboarding
class _Translations$onboarding$fr extends Translations$onboarding$en {
	_Translations$onboarding$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get welcomeTitle => 'Bienvenue dans Ham2K Portable Logger !';
	@override String get welcomeTitleDesktop => 'Bienvenue dans Ham2K Power Logger !';
	@override String get welcomeBody => 'Quelques questions pour mieux adapter l\'application à vos besoins.';
	@override String get skip => 'Passer';
	@override String get kContinue => 'Continuer';
	@override String get back => 'Retour';
	@override String get next => 'Suivant';
	@override String get done => 'Terminé';
	@override String get callsignTitle => 'Quel est votre indicatif ?';
	@override String get callsignBody => 'Cette application n\'est utile qu\'avec une licence de radioamateur';
	@override String get callsignLabel => 'Indicatif de l\'opérateur';
	@override String get alreadyHaveAccount => 'Vous avez déjà un compte ?';
	@override String get foundSiblingTitle => 'Lier un compte existant ?';
	@override String foundSiblingBody({required Object app}) => '${app} est installé sur cet appareil. Liez cette application au même compte pour récupérer votre indicatif et vos journaux.';
	@override String get foundPoloBody => 'Une ancienne version de Ham2K Portable Logger est installée sur cet appareil. Liez cette application au même compte pour récupérer votre indicatif et vos journaux.';
	@override String get foundSiblingsBody => 'D\'autres applications Ham2K sont installées sur cet appareil. Liez cette application à l\'un de leurs comptes pour récupérer votre indicatif et vos journaux.';
	@override String linkWithApp({required Object app}) => 'Lier avec ${app}';
	@override String get linkWithPolo => 'Lier avec le compte de l\'ancienne version';
	@override String get setUpFresh => 'Repartir de zéro';
	@override String get activitiesTitle => 'Activités favorites';
	@override String get activitiesBody => 'Ces programmes d\'activation populaires vous intéressent-ils ?';
	@override String get activitiesFooter => '(Vous trouverez plus d\'options dans les Paramètres)';
	@override String get activityPota => 'Parks On The Air';
	@override String get activitySota => 'Summits On The Air';
	@override String get activityWwff => 'World Wide Flora & Fauna';
	@override String get consentTitle => 'Données et confidentialité';
	@override String get consentUsageBody => 'Pour nous aider à améliorer l\'application, nous aimerions collecter des données de performance, de plantage et d\'utilisation.';
	@override String get consentUsageLabel => 'Partager les données d\'utilisation de l\'application';
	@override String get consentOperationBody => 'Certaines fonctionnalités peuvent partager vos données d\'opération avec d\'autres utilisateurs. Vous pouvez refuser à tout moment.';
	@override String get consentOperationLabel => 'Partager les données d\'opération';
	@override String get finishingSetup => 'Fin de la configuration — téléchargement des données de référence…';
}

// Path: startScreen
class _Translations$startScreen$fr extends Translations$startScreen$en {
	_Translations$startScreen$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get credits => 'par KI2D et amis';
}

// Path: testerOverlay
class _Translations$testerOverlay$fr extends Translations$testerOverlay$en {
	_Translations$testerOverlay$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get tape => 'ATTENTION : TRAVAUX EN COURS';
	@override String get warningTitle => 'Cette application est en cours de développement';
	@override String get warningBody => 'La plupart des fonctionnalités ont des surfaces inégales et il y a des obstacles partout. Pensez à vérifier régulièrement les mises à jour.';
	@override String whatsNew({required Object build}) => 'Nouveautés de la version ${build}';
	@override String get thanks => 'Merci de mettre votre journal en danger pour nous aider à améliorer cette application !';
}

// Path: extensionsPanel
class _Translations$extensionsPanel$fr extends Translations$extensionsPanel$en {
	_Translations$extensionsPanel$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get categoryActivity => 'Activités';
	@override String get categoryContest => 'Concours';
	@override String get categoryLookup => 'Recherches d\'indicatifs';
	@override String get categorySpots => 'Sources de spots';
	@override String get categoryDashboard => 'Panneaux du tableau de bord';
	@override String get categoryOther => 'Autres extensions';
	@override String get searchHint => 'Rechercher des extensions';
	@override String get applying => 'Activation des modifications d\'extensions, cela peut prendre un moment…';
	@override String get noMatches => 'Aucune extension ne correspond à votre recherche';
	@override String get installFromFile => 'Installer depuis un fichier…';
	@override String installVersion({required Object version}) => 'Version ${version}';
	@override String get canReach => 'Cette extension peut contacter';
	@override String canHoldConnection({required Object host}) => '${host}, via une connexion permanente';
	@override String get canHoldLocalConnection => 'Les appareils de votre réseau local, via une connexion permanente';
	@override String get canUseLocation => 'Votre position';
	@override String get canReadRadio => 'Votre radio, pour lire sa fréquence et son mode';
	@override String get canControlRadio => 'Votre radio, pour la piloter et émettre avec — accord, puissance, CW, mémoires vocales et PTT';
	@override String get canSetUserAgent => 'S\'identifier auprès des serveurs sous son propre nom';
	@override String get noCapabilities => 'Elle ne demande rien en dehors de l\'application.';
	@override String get sandboxNote => 'Les extensions s\'exécutent dans un bac à sable : aucun accès à vos fichiers, et aucun accès réseau au-delà de ce qui est listé ici.';
	@override String get installAction => 'Installer';
	@override String get updateAction => 'Mettre à jour';
	@override String get installFailed => 'Impossible d\'installer cette extension';
	@override String get installedBadge => 'Installée';
	@override String get uninstallAction => 'Retirer';
	@override String uninstallTitle({required Object name}) => 'Retirer ${name} ?';
	@override String get uninstallBody => 'Cette extension et ses paramètres seront retirés. Vos journaux ne seront pas modifiés.';
	@override String installedMessage({required Object name}) => '${name} installée';
	@override String get installDownloading => 'Téléchargement…';
	@override String get installWaiting => 'En attente d\'installation…';
	@override String get installInstalling => 'Installation…';
	@override String get installAwaitingApproval => 'En attente de votre accord…';
	@override String installAlreadyRunning({required Object name}) => '${name} est déjà en cours d\'installation.';
	@override String updatedTo({required Object version}) => 'Mise à jour vers ${version}';
	@override String installIncomplete({required Object name}) => 'L\'installation de ${name} n\'a pas abouti. Il faudra peut-être la réinstaller.';
	@override String uninstallFailed({required Object name}) => 'Impossible de retirer ${name}';
	@override String installedFrom({required Object source}) => 'Téléchargée depuis ${source}';
	@override String get dropHint => 'Déposez une extension .h2kext pour l\'installer';
	@override String get dropOneOnly => 'Déposez une seule extension à la fois.';
	@override String downloadFailed({required Object source, required Object status}) => '${source} a renvoyé ${status} pour cette extension.';
	@override String get downloadTooLarge => 'Ce téléchargement est bien trop volumineux pour être une extension.';
	@override String get downloadNotSecure => 'Ce téléchargement a été redirigé vers une adresse non sécurisée.';
	@override String get catalogSection => 'Catalogue';
	@override String get catalogLoading => 'Chargement du catalogue…';
	@override String get catalogUnreachable => 'Catalogue injoignable';
	@override String get builtIn => 'Intégrée';
	@override String get updateAvailableBadge => 'Mise à jour disponible';
	@override String get updatesAvailableTitle => 'Mises à jour d\'extensions';
	@override String updateAvailableFor({required Object name}) => 'Une mise à jour est disponible pour ${name}.';
	@override String updatesAvailable({required Object names, required Object count}) => '${names} et ${count} autres doivent être mises à jour.';
	@override String updatesAvailableFor({required Object names}) => '${names} doivent être mises à jour.';
	@override String get pendingUpdatesSection => 'Mises à jour en attente';
	@override String get updateAllAction => 'Tout mettre à jour';
	@override String get updatesUnderWay => 'Ces mises à jour sont déjà en cours.';
	@override String get updatesNothingLeft => 'Vos extensions sont à jour.';
	@override String get updatesNoticeAction => 'Plus d\'infos';
	@override String updateAllTitle({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Mettre à jour ${count} extension ?',
		other: 'Mettre à jour ${count} extensions ?',
	);
	@override String get upgradeDoneTitle => 'Vos extensions sont prêtes';
	@override String get upgradeDoneBody => 'Elles proviennent désormais du catalogue d\'extensions Ham2K, et peuvent donc être mises à jour sans attendre une nouvelle version de l\'application.';
	@override String upgradeDoneUnserved({required Object names}) => 'Non migrées : ${names}.';
	@override String upgradeDoneRefused({required Object names}) => 'Refus de démarrer : ${names}.';
	@override String get upgradeDoneRefusedHint => 'Elles sont toujours installées et signalées dans Paramètres › Extensions — les y mettre à jour les rétablira.';
	@override String get upgradeDoneUnservedHint => 'Le catalogue n\'a pas de remplacement direct pour celles-ci : cherchez-y des extensions qui couvrent ce que vous utilisiez.';
	@override String get retiredQp => 'QSO Parties';
	@override String get retiredStateparks => 'Événements State Parks';
	@override String upgradeDoneMissing({required Object count}) => '${count} de vos extensions ne sont pas encore arrivées. Elles seront téléchargées dès que le catalogue d\'extensions sera joignable.';
	@override String get runtimeDeadBody => 'Vos extensions n\'ont pas démarré. Redémarrer l\'application devrait les rétablir.';
	@override String get refusedTitle => 'Certaines extensions n\'ont pas démarré';
	@override String get upgradeBusyTitle => 'Configuration en cours';
	@override String get upgradeRuntimeDeadTitle => 'Vos extensions ne fonctionnent pas';
	@override String get restoreTitle => 'Certaines de vos extensions manquent';
	@override String get restoreBody => 'Ces extensions que vous avez installées ne sont pas sur cet appareil. Nous pouvons les télécharger à nouveau depuis le catalogue d\'extensions Ham2K :';
	@override String get restoreFromFile => 'Installées depuis un fichier. Réinstallez-les depuis leurs fichiers, ou oubliez-les :';
	@override String get restoreOtherCatalog => 'Installées depuis un autre catalogue d\'extensions, elles ne sont donc pas disponibles ici :';
	@override String get restoreForget => 'Oublier';
	@override String get restoreInstall => 'Installer';
	@override String get restoreLater => 'Plus tard';
	@override String get restoreInstalling => 'Installation de vos extensions…';
	@override String get restoreDoneTitle => 'Vos extensions sont de retour';
	@override String restoreDoneBody({required Object names}) => 'Réinstallées : ${names}.';
	@override String get restorePartialTitle => 'Certaines extensions n\'ont pas pu être installées';
	@override String restoreFailed({required Object names}) => 'Installation impossible : ${names}. Nous vous les proposerons à nouveau à la prochaine ouverture de l\'application.';
	@override String get restoreBusyBody => 'L\'application configure encore vos extensions. Nous vous les proposerons à nouveau à la prochaine ouverture de l\'application.';
	@override String get restoreRuntimeDeadBody => 'Nous les avons réinstallées, mais vos extensions n\'ont pas démarré. Redémarrer l\'application devrait les rétablir.';
	@override String revokedTitle({required Object name}) => '${name} a été retirée';
	@override String get revokedBody => 'Le catalogue a retiré cette version, elle a donc été désactivée.';
	@override String get downloadHashMismatch => 'Ce téléchargement n\'est pas l\'extension décrite par le catalogue.';
	@override String catalogVersionUnknown({required Object version, required Object key}) => 'Le catalogue n\'a pas de version ${version} de ${key}.';
	@override String get catalogLinkUnknown => 'Ce lien de catalogue ne désigne aucune version d\'extension.';
	@override String catalogNoRelease({required Object key}) => 'Le catalogue n\'a aucune version de ${key} sur cette piste.';
	@override String get installFromLink => 'Installer depuis un lien';
	@override String get unstableReleaseWarning => 'Ceci est une version instable, que son éditeur ne considère pas comme terminée. Elle peut mal se comporter et continuera de recevoir des mises à jour instables.';
	@override String get bleedingReleaseWarning => 'Ceci est une version à la pointe : un travail en cours qui peut casser ou perdre ses paramètres. Elle continuera de recevoir des mises à jour à la pointe.';
	@override String get channelUnstable => 'Instable';
	@override String get channelBleeding => 'À la pointe';
	@override String get followsUnstable => 'Reçoit les versions instables et stables';
	@override String get followsBleeding => 'Reçoit les versions à la pointe, instables et stables';
	@override String get followStableAction => 'Suivre uniquement les versions stables';
	@override String get revokedBadge => 'Retirée';
	@override String get refusedBadge => 'Non chargée';
	@override String get downloadNotHttps => 'Ce téléchargement n\'utilise pas une connexion sécurisée.';
	@override String downloadUnreachable({required Object source}) => '${source} est injoignable pour cette extension.';
	@override String get detailsAction => 'Détails';
	@override String get installedFromFile => 'Installée depuis un fichier';
	@override String get detailsWhatItDoes => 'Prend en charge';
	@override String get installedPreloaded => 'Préinstallée';
	@override String get hookAccount => 'Connexion au compte';
	@override String get hookCallNotes => 'Notes d\'indicatif';
	@override String get hookDataFile => 'Données hors ligne';
	@override String get hookExport => 'Export';
	@override String get hookLookup => 'Recherches d\'indicatifs';
	@override String get hookScoring => 'Calcul du score';
	@override String get hookSpots => 'Spots';
	@override String hookHunting({required Object program}) => 'Chasse ${program}';
	@override String hookActivating({required Object program}) => 'Activation ${program}';
	@override String moreInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '… et ${count} autre extension',
		other: '… et ${count} autres extensions',
	);
	@override String availableInCategory({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} extension disponible',
		other: '${count} extensions disponibles',
	);
}

// Path: home
class _Translations$home$fr extends Translations$home$en {
	_Translations$home$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Logger portable';
	@override String get newOperation => 'Nouvelle opération';
	@override String get stationCallsign => 'Indicatif de la station';
	@override String get titleOptional => 'Titre (facultatif)';
	@override String get emptyList => 'Aucune opération pour l\'instant. Créez-en une pour commencer à journaliser.';
	@override String get quickLookup => 'Recherche rapide';
	@override late final _Translations$home$nav$fr nav = _Translations$home$nav$fr._(_root);
	@override late final _Translations$home$panels$fr panels = _Translations$home$panels$fr._(_root);
	@override String get toggleNav => 'Afficher ou masquer les libellés de navigation';
	@override late final _Translations$home$logs$fr logs = _Translations$home$logs$fr._(_root);
}

// Path: chase
class _Translations$chase$fr extends Translations$chase$en {
	_Translations$chase$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get operatorPrefix => 'op';
	@override String get chasing => 'chasse';
	@override String goalsTwo({required Object first, required Object second}) => '${first} et ${second}';
	@override String goalsMore({required Object first, required Object second}) => '${first}, ${second} et plus';
	@override late final _Translations$chase$station$fr station = _Translations$chase$station$fr._(_root);
	@override late final _Translations$chase$periodInline$fr periodInline = _Translations$chase$periodInline$fr._(_root);
	@override late final _Translations$chase$periodStats$fr periodStats = _Translations$chase$periodStats$fr._(_root);
	@override late final _Translations$chase$period$fr period = _Translations$chase$period$fr._(_root);
	@override late final _Translations$chase$goals$fr goals = _Translations$chase$goals$fr._(_root);
	@override late final _Translations$chase$panels$fr panels = _Translations$chase$panels$fr._(_root);
}

// Path: dialogs
class _Translations$dialogs$fr extends Translations$dialogs$en {
	_Translations$dialogs$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get operationDetails => 'Détails de l\'opération';
	@override String get activities => 'Activités';
	@override String get stationCallsign => 'Indicatif de la station';
	@override String get multiStationIdentifier => 'Identifiant multi-station (uniquement des chiffres)';
	@override String get notes => 'Notes';
	@override String get deleteOperationTitle => 'Supprimer l\'opération';
	@override String get purgeTestsTitle => 'Purger les opérations de test';
	@override String get purgeTestsBody => 'Cela supprime définitivement ces opérations de test et leurs QSOs. Cette action est irréversible.';
	@override String purgeTestsLooseQsos({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Plus ${count} contact de test qui n\'appartient à aucune opération.',
		other: 'Plus ${count} contacts de test qui n\'appartiennent à aucune opération.',
	);
	@override String get purgeTestsAction => 'Purger';
	@override String get syncAllTitle => 'Remplacer le journal de cet appareil ?';
	@override String syncAllBody({required Object qsos}) => 'SYNCALL sauvegarde puis efface ${qsos} de cet appareil, puis télécharge à nouveau le journal du compte depuis le serveur. La sauvegarde reste dans la base de données de cet appareil.';
	@override String syncAllUnsynced({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${n} QSO n\'a pas encore été synchronisé — le serveur ne l\'a jamais reçu, et il NE reviendra PAS.',
		other: '${n} QSOs n\'ont pas encore été synchronisés — le serveur ne les a jamais reçus, et ils NE reviendront PAS.',
	);
	@override String get syncAllAction => 'Effacer et resynchroniser';
	@override String get receivedPurgesTitle => 'Opérations de test supprimées ailleurs';
	@override String get receivedPurgesBody => 'Celles-ci ont été supprimées comme opérations de test sur un autre appareil. Les supprimer ici aussi ? Cela les supprime définitivement avec leurs QSOs, et c\'est irréversible.';
	@override String get receivedPurgesAction => 'Supprimer';
	@override late final _Translations$dialogs$callChange$fr callChange = _Translations$dialogs$callChange$fr._(_root);
}

// Path: operation
class _Translations$operation$fr extends Translations$operation$en {
	_Translations$operation$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get deletedReadOnly => 'Cette opération est supprimée. Restaurez-la pour saisir des QSOs ou la modifier.';
	@override late final _Translations$operation$tabs$fr tabs = _Translations$operation$tabs$fr._(_root);
	@override late final _Translations$operation$positions$fr positions = _Translations$operation$positions$fr._(_root);
	@override String get stationCallsignNone => 'Aucun indicatif de station';
	@override String get titleNone => 'Sans titre';
	@override String get deleteOperation => 'Supprimer l\'opération';
	@override String get loggingControlsStale => 'Les champs d\'activité ne sont peut-être pas à jour — rouvrez l\'opération pour les actualiser';
	@override String get locationNone => 'Non défini';
	@override String get generalOperation => 'Opération générale';
	@override String titleFor({required Object value}) => 'pour ${value}';
	@override String titleAt({required Object value}) => 'à ${value}';
	@override String segmentNow({required Object description}) => 'Maintenant ${description}';
	@override String get testOperationSuffix => 'Test';
	@override late final _Translations$operation$menu$fr menu = _Translations$operation$menu$fr._(_root);
	@override late final _Translations$operation$layout$fr layout = _Translations$operation$layout$fr._(_root);
	@override late final _Translations$operation$export$fr export = _Translations$operation$export$fr._(_root);
	@override late final _Translations$operation$spots$fr spots = _Translations$operation$spots$fr._(_root);
	@override late final _Translations$operation$import$fr import = _Translations$operation$import$fr._(_root);
}

// Path: map
class _Translations$map$fr extends Translations$map$en {
	_Translations$map$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override late final _Translations$map$outlineIssue$fr outlineIssue = _Translations$map$outlineIssue$fr._(_root);
	@override String get outlinesDisclaimer => 'Les contours sont donnés à titre indicatif. Faites vos propres recherches !';
	@override String outlinesCredit({required Object sources}) => 'Contours : ${sources}';
	@override String boundariesCredit({required Object sources}) => 'Limites : ${sources}';
	@override String facilitiesCredit({required Object sources}) => 'Équipements : ${sources}';
	@override String get fullCredits => 'Crédits complets des données';
	@override String get fewerCredits => 'Moins de crédits';
	@override String get emptyState => 'Aucune position de QSO pour l\'instant.\nLes QSOs avec un locator, un état ou un pays apparaîtront ici.';
	@override String get unavailable => 'La carte n\'est pas disponible pour le moment.';
	@override String qthPopupTitle({required Object grid}) => 'QTH : ${grid}';
	@override String distanceKm({required Object distance}) => '${distance} km';
	@override String distanceMiles({required Object distance}) => '${distance} mi';
	@override String get flat => 'Plane';
	@override String get globe => 'Globe';
	@override String get zoomIn => 'Zoom avant';
	@override String get zoomOut => 'Zoom arrière';
	@override late final _Translations$map$postcard$fr postcard = _Translations$map$postcard$fr._(_root);
}

// Path: mapsView
class _Translations$mapsView$fr extends Translations$mapsView$en {
	_Translations$mapsView$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cartes';
	@override String get searchHint => 'Rechercher des parcs, des sommets et plus';
	@override String get activities => 'Activités';
	@override String get layers => 'Calques';
	@override String get baseMap => 'Fond de carte';
	@override String get satellite => 'Satellite (Esri)';
	@override String get facilities => 'Équipements des parcs';
	@override String get boundaries => 'Limites';
	@override String get currentLocation => 'Position actuelle';
	@override String noMatches({required Object text}) => 'Rien ne correspond à « ${text} »';
	@override String picksAt({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} référence à ${where}',
		other: '${count} références à ${where}',
	);
	@override String get startOperation => 'Commencer une opération avec ces références';
}

// Path: activitiesView
class _Translations$activitiesView$fr extends Translations$activitiesView$en {
	_Translations$activitiesView$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Activités';
	@override String get activitiesCountZero => 'Aucune activité sélectionnée';
	@override String get activitiesCountOne => '1 activité';
	@override String activitiesCountOther({required Object count}) => '${count} activités';
	@override String get empty => 'Aucune activité pour l\'instant — utilisez Suggestions et recherche ci-dessous pour en ajouter une';
	@override String get removeActivity => 'Retirer';
	@override String openReferenceLink({required Object name}) => 'Ouvrir ${name}';
	@override String get editActivity => 'Modifier l\'activité';
	@override String get manageExtensions => 'Gérer les extensions';
	@override String get manage => 'Gérer';
	@override String activitiesTitle1({required Object first}) => 'Types d\'activités : ${first}';
	@override String activitiesTitle2({required Object first, required Object second}) => 'Types d\'activités : ${first} et ${second}';
	@override String activitiesTitleMore({required Object first, required Object second, required Object more}) => 'Types d\'activités : ${first}, ${second} et ${more} de plus';
	@override String get reference => 'Référence';
	@override String get invalidReference => 'Non valide';
	@override String get duplicateReference => 'Déjà ajoutée';
	@override String get searchHint => 'Rechercher par nom, référence ou autre…';
	@override String get noSuggestions => 'Aucun résultat';
	@override String get noSuggestionsHint => 'Recherchez par nom ou numéro de référence ci-dessus';
	@override String get noSuggestionsExample => '(par exemple « sentier » ou « 4556 »)';
	@override String get allOptions => 'Types d\'activités';
	@override String get determiningLocation => 'Détermination de la position actuelle…\nEn attente du GPS pour trouver les références à proximité';
	@override String get locationUnavailableTitle => 'Données de localisation indisponibles';
	@override String get locationDeniedTitle => 'Autorisation de localisation refusée';
	@override String get locationBlockedTitle => 'Autorisation de localisation bloquée';
	@override String get noNearbyReason => 'Impossible de déterminer les références à proximité';
	@override String locationManualHint({required Object icon}) => 'Appuyez sur ${icon} pour saisir votre position manuellement,\nou recherchez simplement des références par nom';
	@override String get locationGrantAction => 'Autoriser l\'accès à la localisation';
	@override String get locationSettingsAction => 'Ouvrir les réglages';
	@override String get locationSettingsUnavailable => 'Autorisez l\'accès à la localisation dans les réglages du système';
	@override String get locationGrantRefused => 'Toujours pas de localisation — le système a de nouveau refusé';
	@override String get searchUnavailableTitle => 'Recherche d\'activités indisponible';
	@override String get searchUnavailableReason => 'Aucune extension d\'activité n\'a pu effectuer la recherche. Réessayez dans un instant.';
	@override String get emptySheet => 'Utilisez les suggestions et la recherche ci-dessous pour en ajouter une';
	@override String get exports => 'Exports';
	@override String get exportLogs => 'Exporter les journaux';
	@override String get tools => 'Outils';
	@override String get toolsTitle => 'Outils de l\'opération';
	@override String get operationDetails => 'Détails de l\'opération';
	@override String get share => 'Partager';
	@override String get archive => 'Archiver';
	@override String get deleteOperation => 'Supprimer l\'opération';
	@override String get undeleteOperation => 'Restaurer l\'opération';
	@override String get alreadySelected => 'Déjà sélectionnée';
	@override String get selected => 'Sélectionnée';
	@override String pickPosition({required Object index, required Object count}) => '${index} sur ${count}';
	@override String get previousPick => 'Résultat précédent';
	@override String get nextPick => 'Résultat suivant';
	@override String get retiredReference => 'Retirée';
	@override String enableExtension({required Object name}) => 'Activer ${name}';
	@override String get enableExtensionHint => 'Cette extension correspond à votre recherche, mais elle n\'est pas activée';
	@override String get enableExtensionForRefHint => 'Cette extension gère l\'une des références de cette opération, mais elle n\'est pas activée';
	@override String extensionNotRunning({required Object name}) => '${name} ne fonctionne pas';
	@override String get extensionNotRunningHint => 'Cette extension a été désactivée, ouvrez les paramètres des extensions pour plus d\'infos';
	@override String installExtension({required Object name}) => 'Installer ${name}';
	@override String get installExtensionHint => 'Cette extension correspond à votre recherche, mais elle n\'est pas installée';
	@override String get onlyCatalogMatches => 'Aucun résultat\nCertaines extensions du catalogue pourraient avoir des résultats.\nInstallez-les dans Types d\'activités ci-dessous.';
	@override String get setupUnavailable => 'Impossible de charger la configuration de cette activité — réessayez depuis Gérer';
	@override String get controlsUnavailableTitle => 'Contrôles d\'activité indisponibles';
	@override String get controlsUnavailableReason => 'Vos références sont intactes, mais leur modification est indisponible pour le moment.';
	@override String get controlsUnavailableRetry => 'Réessayer';
	@override String get onlyDisabledMatches => 'Aucun résultat\nCertaines extensions disponibles pourraient avoir des résultats.\nActivez-les dans Types d\'activités ci-dessous.';
	@override String get onlyNotRunningMatches => 'Aucun résultat\nCertaines extensions qui pourraient avoir des résultats ne fonctionnent pas.\nVoir Types d\'activités ci-dessous.';
	@override String get mapToggle => 'Carte';
	@override String get searchToggle => 'Recherche';
	@override String get addToOperation => 'Ajouter à l\'opération';
	@override String get addToOperationShort => 'Ajouter à l\'op.';
	@override String get mapEmptyState => 'Aucun résultat à afficher sur la carte';
	@override String get mapEmptyStateHint => 'Revenez à la liste, ou lancez une autre recherche';
	@override String get imports => 'Imports';
}

// Path: loggingControls
class _Translations$loggingControls$fr extends Translations$loggingControls$en {
	_Translations$loggingControls$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get timeUtc => 'Heure (UTC)';
	@override String get date => 'Date';
	@override String get now => 'Maintenant';
	@override String get frequency => 'Fréquence';
	@override String get mode => 'Mode';
	@override String get theirCall => 'Leur indicatif';
	@override String get noteField => 'Note';
	@override String get todoField => 'À faire';
	@override String get sent => 'Envoyé';
	@override String get rcvd => 'Reçu';
	@override String get more => 'Plus';
	@override String get revert => 'Rétablir';
	@override String get undoDelete => 'Annuler la suppression';
	@override String get restore => 'Restaurer';
	@override String get wipe => 'Effacer';
	@override String get undo => 'Annuler';
	@override String get pendingDeleteTapWarning => 'Appuyez encore une fois sur la corbeille pour supprimer ce QSO';
	@override String get pendingDeleteClickWarning => 'Cliquez encore une fois sur la corbeille pour supprimer ce QSO';
	@override String get deletedQsoWarning => 'QSO supprimé';
	@override String pendingDeleteEventTapWarning({required Object kind}) => 'Appuyez encore une fois sur la corbeille pour supprimer : ${kind}';
	@override String pendingDeleteEventClickWarning({required Object kind}) => 'Cliquez encore une fois sur la corbeille pour supprimer : ${kind}';
	@override String deletedEventWarning({required Object kind}) => 'Supprimé : ${kind}';
	@override String get timeControl => 'Heure';
	@override String get radioControl => 'Radio';
	@override String get powerControl => 'Puissance';
	@override String get notesControl => 'Notes';
	@override String get power => 'Puissance';
	@override String get powerUnit => 'W';
	@override String get controlSettings => 'Contrôles de saisie';
	@override String get spottingControl => 'Spotting';
	@override String get spottingSelfControl => 'Auto-spotting';
	@override String spotSelfAt({required Object freq}) => 'S\'auto-spotter sur ${freq}';
	@override String spotOtherAt({required Object call, required Object freq}) => 'Spotter ${call} sur ${freq}';
	@override String spotTooLate({required Object call}) => 'Trop tard pour spotter ${call}';
	@override String get spotNoFreq => 'Définissez d\'abord une fréquence à spotter';
	@override String get spotComment => 'Commentaire';
	@override String get bandOrFreqRequired => 'Définissez une fréquence ou une bande avant de saisir';
	@override String get missingBand => 'Pas de bande';
	@override String get missingMode => 'Pas de mode';
	@override String saveFailed({required Object error}) => 'Impossible d\'enregistrer : ${error}';
	@override String deleteFailed({required Object error}) => 'Impossible de supprimer : ${error}';
	@override late final _Translations$loggingControls$info$fr info = _Translations$loggingControls$info$fr._(_root);
}

// Path: formChrome
class _Translations$formChrome$fr extends Translations$formChrome$en {
	_Translations$formChrome$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get untitled => '(sans titre)';
	@override String get showMore => 'Afficher plus';
	@override String get showAll => 'Tout afficher';
	@override String get showFewer => 'Afficher moins';
	@override String get defaults => 'Valeurs par défaut';
	@override String get search => 'Rechercher';
	@override String get clear => 'Effacer';
	@override String get openPage => 'Ouvrir la page';
	@override String get connected => 'Connecté';
	@override String get notConnected => 'Non connecté';
	@override String get manage => 'Gérer';
	@override String get connect => 'Connecter';
	@override String get formTitle => 'Formulaire';
	@override String addItem({required Object label}) => 'Ajouter ${label}';
	@override String editItem({required Object label}) => 'Modifier ${label}';
	@override String multiselectStatus({required Object shown, required Object total, required Object selected}) => 'Affichage de ${shown} sur ${total} (${selected} sélectionnés)';
	@override String validationError({required Object error}) => 'Erreur de validation : ${error}';
	@override String transformationError({required Object error}) => 'Erreur de transformation : ${error}';
	@override String actionError({required Object error}) => 'Erreur : ${error}';
	@override String get removeItem => 'Retirer';
	@override String get storageUnavailable => 'Identifiants indisponibles';
}

// Path: qsoEditForm
class _Translations$qsoEditForm$fr extends Translations$qsoEditForm$en {
	_Translations$qsoEditForm$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Modifier le QSO';
	@override String get operatorCall => 'Opérateur';
	@override String get position => 'Position';
	@override String get theirName => 'Nom';
	@override String get theirGrid => 'Grille';
	@override String get theirState => 'État';
	@override String get band => 'Bande';
	@override String get notes => 'Notes';
	@override String get sectionQso => 'QSO';
	@override String get sectionTheir => 'Leurs infos';
	@override String get sectionOur => 'Nos infos';
	@override String get sectionNotes => 'Notes';
	@override String get theirCity => 'Ville';
	@override String get theirCounty => 'Comté';
	@override String get theirEntity => 'Entité';
	@override String get theirCqZone => 'Zone CQ';
	@override String get theirItuZone => 'Zone ITU';
	@override String get theirArrlSection => 'Section ARRL';
	@override String get theirLat => 'Latitude';
	@override String get theirLon => 'Longitude';
	@override String get theirPower => 'Leur puissance';
}

// Path: qsoList
class _Translations$qsoList$fr extends Translations$qsoList$en {
	_Translations$qsoList$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Pas encore de QSOs — contactez quelqu\'un !';
	@override String get bandOrModeWarning => 'Vérifiez que votre bande et votre mode sont corrects';
	@override String get today => 'Aujourd\'hui';
	@override String get yesterday => 'Hier';
	@override String get tomorrow => 'Demain';
}

// Path: loggingPanel
class _Translations$loggingPanel$fr extends Translations$loggingPanel$en {
	_Translations$loggingPanel$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get stats => 'Statistiques de l\'opération';
	@override String get scoring => 'Score';
	@override String get dxccEntities => 'Entités DXCC';
	@override String get statesWorked => 'États';
	@override String get provincesWorked => 'Provinces';
	@override String get duplicates => 'Doublons';
}

// Path: callInfo
class _Translations$callInfo$fr extends Translations$callInfo$en {
	_Translations$callInfo$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get qrz => 'QRZ';
	@override String get showImage => 'Afficher l\'image';
	@override String get imageUnavailable => 'Photo indisponible';
	@override String get photo => 'Photo';
	@override String get notes => 'Notes';
	@override String distanceTo({required Object distance}) => '${distance} jusqu\'à';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) jusqu\'à';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) jusqu\'à';
	@override String distanceAway({required Object distance}) => '${distance} de distance';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distance';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distance';
	@override String get thisOpCountOne => '1 QSO dans cette opération';
	@override String thisOpCountOther({required Object count}) => '${count} QSOs dans cette opération';
	@override String get otherOpsCountOne => '1 QSO dans d\'autres opérations';
	@override String otherOpsCountOther({required Object count}) => '${count} QSOs dans d\'autres opérations';
	@override String andMore({required Object count}) => '… et ${count} de plus';
	@override String withCall({required Object call}) => 'avec ${call}';
	@override String fromOperation({required Object where}) => 'depuis ${where}';
	@override late final _Translations$callInfo$history$fr history = _Translations$callInfo$history$fr._(_root);
}

// Path: settings
class _Translations$settings$fr extends Translations$settings$en {
	_Translations$settings$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Paramètres';
	@override String get language => 'Langue';
	@override String languageSystem({required Object language}) => 'Suivre les réglages du système (${language})';
	@override late final _Translations$settings$theme$fr theme = _Translations$settings$theme$fr._(_root);
	@override late final _Translations$settings$themeDescription$fr themeDescription = _Translations$settings$themeDescription$fr._(_root);
	@override String get fontScale => 'Échelle de police';
	@override late final _Translations$settings$fontScaleOpts$fr fontScaleOpts = _Translations$settings$fontScaleOpts$fr._(_root);
	@override late final _Translations$settings$keepDeviceAwake$fr keepDeviceAwake = _Translations$settings$keepDeviceAwake$fr._(_root);
	@override String get layoutDensity => 'Densité de l\'affichage';
	@override late final _Translations$settings$layoutDensityOpts$fr layoutDensityOpts = _Translations$settings$layoutDensityOpts$fr._(_root);
	@override String layoutDensityClamped({required Object effective}) => 'la fenêtre est trop petite, utilisation de ${effective}';
	@override String get layoutDensityAtLimit => 'au maximum';
	@override String get distanceUnits => 'Unités de distance';
	@override late final _Translations$settings$distanceUnitsOpts$fr distanceUnitsOpts = _Translations$settings$distanceUnitsOpts$fr._(_root);
	@override String get userInterface => 'Interface utilisateur';
	@override late final _Translations$settings$logging$fr logging = _Translations$settings$logging$fr._(_root);
	@override late final _Translations$settings$catServer$fr catServer = _Translations$settings$catServer$fr._(_root);
	@override late final _Translations$settings$radio$fr radio = _Translations$settings$radio$fr._(_root);
	@override late final _Translations$settings$help$fr help = _Translations$settings$help$fr._(_root);
	@override late final _Translations$settings$exports$fr exports = _Translations$settings$exports$fr._(_root);
	@override late final _Translations$settings$map$fr map = _Translations$settings$map$fr._(_root);
	@override late final _Translations$settings$privacy$fr privacy = _Translations$settings$privacy$fr._(_root);
	@override String get operatorCall => 'Indicatif de l\'opérateur';
	@override late final _Translations$settings$sync$fr sync = _Translations$settings$sync$fr._(_root);
	@override late final _Translations$settings$peers$fr peers = _Translations$settings$peers$fr._(_root);
	@override String get developerMode => 'Mode développeur';
	@override late final _Translations$settings$syncPanel$fr syncPanel = _Translations$settings$syncPanel$fr._(_root);
	@override late final _Translations$settings$accounts$fr accounts = _Translations$settings$accounts$fr._(_root);
	@override late final _Translations$settings$station$fr station = _Translations$settings$station$fr._(_root);
	@override late final _Translations$settings$offlineData$fr offlineData = _Translations$settings$offlineData$fr._(_root);
	@override late final _Translations$settings$profiles$fr profiles = _Translations$settings$profiles$fr._(_root);
	@override late final _Translations$settings$search$fr search = _Translations$settings$search$fr._(_root);
	@override late final _Translations$settings$developer$fr developer = _Translations$settings$developer$fr._(_root);
	@override late final _Translations$settings$about$fr about = _Translations$settings$about$fr._(_root);
	@override late final _Translations$settings$panels$fr panels = _Translations$settings$panels$fr._(_root);
	@override String get showMoreSettings => 'Afficher plus de paramètres';
	@override String get gridPrecision => 'Précision du locator';
	@override late final _Translations$settings$gridPrecisionOpts$fr gridPrecisionOpts = _Translations$settings$gridPrecisionOpts$fr._(_root);
	@override late final _Translations$settings$gridPrecisionDescription$fr gridPrecisionDescription = _Translations$settings$gridPrecisionDescription$fr._(_root);
}

// Path: commands
class _Translations$commands$fr extends Translations$commands$en {
	_Translations$commands$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get enableSyncFirst => 'Activez d\'abord la synchronisation dans les Paramètres.';
	@override String get fullResyncStarted => 'Resynchronisation complète lancée — les données locales ont d\'abord été sauvegardées.';
	@override String noDataFilesMatched({required Object target}) => 'Aucun fichier de données ne correspond à « ${target} ».';
	@override String reloadFailed({required Object error}) => 'Échec du rechargement : ${error}';
	@override String get reloadingAll => 'Rechargement de tous les fichiers de données…';
	@override String reloadingTarget({required Object target}) => 'Rechargement des fichiers de données ${target}…';
	@override String unknownExperiment({required Object token}) => 'Expérience inconnue « ${token} »';
	@override String experimentEnabled({required Object name}) => '${name} activée';
	@override String experimentDisabled({required Object name}) => '${name} désactivée';
	@override String get sentryTestSent => 'Rapport d\'erreur de test envoyé à Sentry';
	@override String get sentryTestLocalOnly => 'Sentry est désactivé dans cette version — erreur de test consignée localement uniquement';
	@override String get noOperationOpen => 'Cette commande nécessite une opération ouverte';
	@override String unknownSegmentKind({required Object kind}) => 'Impossible de marquer « ${kind} »';
	@override String get operationAlreadyStarted => 'Cette opération a déjà un marqueur de début';
	@override String get couldNotOpenLocation => 'Pause ajoutée, mais impossible d\'ouvrir l\'écran d\'emplacement';
	@override String get noTestOperations => 'Aucune opération de test à purger';
	@override String get purgeTestsUnavailable => 'PURGETESTS doit afficher une boîte de confirmation, qui n\'est pas disponible ici';
	@override String get syncAllUnavailable => 'SYNCALL doit afficher une boîte de confirmation, qui n\'est pas disponible ici';
	@override String testOperationsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} opération de test purgée',
		other: '${count} opérations de test purgées',
	);
	@override String purgeTestsSomeFailed({required Object purged, required Object total}) => '${purged} opérations de test purgées sur ${total} — les autres ont échoué ; relancez PURGETESTS';
	@override String testContactsPurged({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} contact de test sans opération purgé',
		other: '${count} contacts de test sans opération purgés',
	);
	@override String get purgeTestsContactsFailed => 'Opérations de test purgées, mais les contacts de test sans opération ont échoué ; relancez PURGETESTS';
	@override String get purgeTestsNothingToDo => 'Rien n\'a été purgé';
	@override String receivedPurgesSomeFailed({required Object removed, required Object total}) => '${removed} opérations de test supprimées sur ${total} — les autres ont échoué ; relancez Examiner';
	@override String get receivedPurgesFailed => 'Impossible de supprimer ces opérations de test — relancez Examiner';
	@override String receivedPurgesPending({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} opération de test a été supprimée sur un autre appareil',
		other: '${count} opérations de test ont été supprimées sur un autre appareil',
	);
	@override String get receivedPurgesReview => 'Examiner';
	@override String get settingOn => 'Activé';
	@override String get settingOff => 'Désactivé';
	@override String get settingEmpty => '(vide)';
	@override String get settingSecretSet => '(défini)';
	@override String get settingSecretUnset => '(non défini)';
	@override String settingSelectedCount({required Object count}) => '${count} sélectionné(s)';
	@override String get settingExpectsOnOff => 'on ou off';
	@override String settingExpectsOneOf({required Object choices}) => 'l\'une des valeurs : ${choices}';
	@override String get settingExpectsNumber => 'un nombre';
	@override String settingVanished({required Object label}) => '« ${label} » n\'est plus disponible';
	@override String get noCwKeyer => 'Aucune radio connectée ne peut manipuler la CW';
	@override String get noKeyer => 'Aucune radio connectée ne peut manipuler la CW ni jouer des mémoires vocales';
	@override String get keyerNeedsOperation => 'Ouvrez une opération pour utiliser le manipulateur CW';
	@override String get keyerExperimentOff => 'La manipulation CW est désactivée — activez-la avec EXP KEYER';
	@override String get esmExperimentOff => 'Entrée envoie les messages est désactivé — activez-le avec EXP ESM';
	@override String cwSending({required Object text}) => 'Envoi CW : ${text}';
	@override String cwMessageError({required Object n, required Object error}) => 'Message CW F${n} : ${error}';
	@override String cwMessageNotRendered({required Object n}) => 'Le message CW F${n} n\'a pas été envoyé : les extensions ne sont pas prêtes';
	@override String settingNotStored({required Object label}) => '« ${label} » n\'a pas accepté cette valeur';
}

// Path: commandDialog
class _Translations$commandDialog$fr extends Translations$commandDialog$en {
	_Translations$commandDialog$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get hint => 'Rechercher un indicatif ou taper une commande';
	@override String noResults({required Object text}) => 'Rien ne correspond à « ${text} »';
	@override String get sectionCommands => 'Commandes';
	@override String get sectionGoTo => 'Aller à';
	@override String get sectionOperations => 'Opérations';
	@override String get goHome => 'Accueil';
	@override String get goSettings => 'Paramètres';
	@override String get goNewOperation => 'Nouvelle opération';
	@override String runTyped({required Object text}) => 'Exécuter « ${text} »';
	@override String get sectionSuggestions => 'Essayez';
	@override String get lookingUp => 'Recherche de l\'indicatif…';
	@override String get blockedByPane => 'Impossible d\'utiliser les commandes quand un panneau ou une boîte de dialogue est ouvert';
}

// Path: expiredBuild
class _Translations$expiredBuild$fr extends Translations$expiredBuild$en {
	_Translations$expiredBuild$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cette version a expiré';
	@override String get body => 'Rendez-vous sur ham2k.com pour obtenir une version plus récente.';
	@override String get visit => 'Aller sur ham2k.com';
	@override String get dismiss => 'Continuer quand même';
}

// Path: staleness
class _Translations$staleness$fr extends Translations$staleness$en {
	_Translations$staleness$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get codePushFloorTitle => 'Une mise à jour importante vous attend';
	@override String get codePushFloorBody => 'Cette version contient un correctif que vous n\'avez pas encore.';
	@override String get restartToApply => 'Redémarrez l\'application pour l\'appliquer.';
	@override String get quitAndReopen => 'Quittez l\'application et rouvrez-la pour l\'appliquer.';
	@override String get reopenToApply => 'Fermez l\'application et rouvrez-la pour l\'appliquer.';
	@override String get ignoreForNow => 'Ignorer pour l\'instant';
}

// Path: spotting
class _Translations$spotting$fr extends Translations$spotting$en {
	_Translations$spotting$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get noQsoYet => 'Aucun QSO saisi à spotter pour l\'instant.';
	@override String get setFrequencyFirst => 'Définissez d\'abord une fréquence.';
	@override String get nothingToSpot => 'Rien à spotter — aucune extension ne propose le spotting ici.';
	@override String spotFailed({required Object source, required Object message}) => 'Échec de ${source} : ${message}';
	@override String get unknownError => 'erreur inconnue';
	@override String get notSent => 'Spot non envoyé.';
	@override String get notRefreshedOffline => 'Pas de connexion — les spots n\'ont pas été actualisés';
}

// Path: dataFiles
class _Translations$dataFiles$fr extends Translations$dataFiles$en {
	_Translations$dataFiles$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get downloading => 'Téléchargement…';
	@override String downloadFailedTitle({required Object name}) => 'Impossible de télécharger ${name}';
	@override String get downloadFailedWebHint => 'Il peut s\'agir d\'un problème réseau, ou l\'hébergeur de ce lien ne permet peut-être pas le téléchargement direct depuis un navigateur web. Essayez l\'application de bureau ou mobile, ou un autre hébergement.';
	@override String get downloadTimedOut => 'Le serveur a mis trop de temps à répondre. Réessayez plus tard.';
	@override String downloadServerError({required Object host, required Object status}) => '${host} a répondu par une erreur (HTTP ${status}). Réessayez plus tard.';
	@override String downloadNotAvailable({required Object host, required Object status}) => '${host} n\'a pas pu fournir ce fichier (HTTP ${status}). Vérifiez que son adresse est toujours correcte.';
	@override String processingFailedTitle({required Object name}) => 'Impossible de traiter ${name}';
	@override String importTooSmall({required Object imported, required Object existing}) => 'Le téléchargement ne contenait que ${imported} des ${existing} enregistrements présents sur cet appareil : ceux qu\'il omettait ont donc été conservés. L\'actualiser dans Paramètres › Données hors ligne l\'accepte quand même.';
	@override String importedRecords({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} enregistrement importé pour ${label}.',
		other: '${count} enregistrements importés pour ${label}.',
	);
	@override String importedData({required Object label}) => 'Données importées pour ${label}.';
	@override String get cleanedUpTitle => 'Données d\'extensions nettoyées';
	@override String removedData({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Données supprimées pour ${count} fichier de données d\'extensions désactivées.',
		other: 'Données supprimées pour ${count} fichiers de données d\'extensions désactivées.',
	);
	@override String recordsProgress({required Object end, required Object total}) => '${end} / ${total} enregistrements';
	@override String get definitionUnavailable => 'La source du fichier n\'a pas fourni de définition — son extension est peut-être en cours de redémarrage ou mal configurée. Réessayez dans un instant.';
}

// Path: updates
class _Translations$updates$fr extends Translations$updates$en {
	_Translations$updates$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get updateAvailable => 'Mise à jour disponible';
	@override String newVersionAvailable({required Object version}) => 'Une nouvelle version (${version}) est disponible.';
	@override String get getIt => 'L\'obtenir';
	@override String get ok => 'OK';
	@override String get updateReady => 'Mise à jour prête';
	@override String get restartToApply => 'Une mise à jour a été téléchargée. Redémarrez pour l\'appliquer.';
	@override String get appliesNextLaunch => 'Une mise à jour a été téléchargée. Elle s\'appliquera à la prochaine ouverture de l\'application.';
	@override String get restartNow => 'Redémarrer maintenant';
	@override String get reloadToUpdate => 'Une version plus récente de cette page est disponible. Rechargez pour l\'obtenir.';
	@override String get reloadNow => 'Recharger maintenant';
	@override String get checkForUpdates => 'Vérifier les mises à jour';
	@override String get checkingForUpdates => 'Recherche de mises à jour…';
	@override String get upToDate => 'À jour';
	@override String get automaticChecks => 'Vérifier automatiquement';
	@override String get automaticChecksDescription => 'Rechercher les nouvelles versions en arrière-plan, à partir du prochain démarrage de l\'application';
}

// Path: extensionService
class _Translations$extensionService$fr extends Translations$extensionService$en {
	_Translations$extensionService$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get runtimeNotReady => 'Le moteur d\'extensions n\'est pas prêt.';
	@override String testFailed({required Object error}) => 'Échec du test : ${error}';
	@override String connectedAs({required Object identity}) => 'Connecté en tant que ${identity}';
	@override String get invalidFieldConfiguration => 'Configuration de champ invalide';
	@override String get invalidValue => 'Valeur invalide';
	@override String validationError({required Object error}) => 'Erreur de validation : ${error}';
	@override String actionFailed({required Object error}) => 'Échec de l\'action : ${error}';
	@override String get commandFailed => 'La commande n\'a pas pu s\'exécuter';
	@override String get reportUnavailable => 'Les signalements ne peuvent pas être envoyés pour le moment';
	@override String get stashUnavailable => 'Ham2K File Stash est injoignable pour le moment';
	@override String timersSuspendedBudget({required Object name}) => '${name} a passé trop de temps dans ses minuteries. Elles sont arrêtées jusqu\'au redémarrage des extensions.';
	@override String timersSuspendedFailures({required Object name}) => 'Les minuteries de ${name} échouaient sans cesse. Elles sont arrêtées jusqu\'au redémarrage des extensions.';
	@override String timersSuspendedInterrupted({required Object name}) => '${name} est resté bloqué dans une minuterie. Ses minuteries sont arrêtées jusqu\'au redémarrage des extensions.';
}

// Path: operationLocationScreen
class _Translations$operationLocationScreen$fr extends Translations$operationLocationScreen$en {
	_Translations$operationLocationScreen$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Emplacement de l\'opération';
	@override String get selectedLocation => 'Emplacement sélectionné';
	@override String get gridSquare => 'Carré Locator Maidenhead';
	@override String get gridInvalid => 'Il faut 4, 6, 8 ou 10 caractères, comme FN31pr';
	@override String get suggestedLocations => 'Emplacements suggérés';
	@override String get deviceGps => 'GPS de l\'appareil';
	@override String peerGps({required Object device}) => 'GPS de ${device}';
	@override String get locating => 'Localisation…';
	@override String get gpsUnavailable => 'Position indisponible';
	@override String get permissionDenied => 'Autorisation de localisation refusée';
	@override String get permissionBlocked => 'Autorisation de localisation bloquée';
	@override String get moreDetails => 'Plus de détails';
	@override String get stateOrProvince => 'État ou province (facultatif)';
	@override String get controlsUnavailableTitle => 'Contrôles d\'activité indisponibles';
	@override String get controlsUnavailableReason => 'Ces références restent utilisables ; leurs activités n\'ont simplement pas pu être jointes.';
	@override String get controlsUnavailableRetry => 'Réessayer';
	@override String get county => 'Comté (facultatif)';
}

// Path: versionLabel
class _Translations$versionLabel$fr extends Translations$versionLabel$en {
	_Translations$versionLabel$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String version({required Object version}) => 'Version ${version}';
	@override String patch({required Object patch}) => 'Correctif ${patch}';
	@override String build({required Object build}) => 'build ${build}';
}

// Path: notices
class _Translations$notices$fr extends Translations$notices$en {
	_Translations$notices$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get emptyHistory => 'Aucune notification pour l\'instant';
	@override String get webStorageInMemory => 'Ce navigateur n\'a pas pu fournir de stockage persistant — le journal n\'existe qu\'en mémoire et sera PERDU à la fermeture de cet onglet. Utilisez une version récente de Chrome, Firefox, Safari ou Edge.';
	@override String get webStorageUnreliable => 'Ce navigateur utilise un stockage de secours qui n\'est pas sûr avec plusieurs onglets — gardez un seul onglet ouvert, et laissez la synchronisation activée.';
	@override String get logFromNewerBuildTitle => 'Ce journal nécessite une version plus récente';
	@override String logFromNewerBuild({required Object storage, required Object understood, required Object location}) => 'Votre journal a été écrit par une version plus récente de HaLo (version de stockage ${storage} ; celle-ci comprend ${understood}) : il ne peut donc pas être ouvert, et les nouveaux contacts ne seront pas enregistrés. Réinstallez la version plus récente — ou, si vous vouliez lancer cette version, faites-la pointer vers un autre dossier de données. Le journal se trouve dans ${location}';
	@override String logFromNewerBuildNoLocation({required Object storage, required Object understood}) => 'Votre journal a été écrit par une version plus récente de HaLo (version de stockage ${storage} ; celle-ci comprend ${understood}) : il ne peut donc pas être ouvert, et les nouveaux contacts ne seront pas enregistrés. Ouvrez plutôt ce journal avec cette version plus récente.';
	@override String get preferencesRestoredTitle => 'Paramètres restaurés depuis une sauvegarde';
	@override String get preferencesRestored => 'Le fichier de paramètres n\'a pas pu être lu : HaLo a donc restauré sa dernière copie valide. Ce que vous avez modifié lors de votre session précédente devra peut-être être refait. Le fichier illisible est conservé à côté, sous le nom shared_preferences.corrupt-….json.';
	@override String get preferencesResetTitle => 'Paramètres réinitialisés';
	@override String get preferencesReset => 'Le fichier de paramètres n\'a pas pu être lu et aucune sauvegarde n\'était disponible : HaLo a donc démarré avec ses valeurs par défaut. Le fichier illisible est conservé dans le dossier de données de l\'application, sous le nom shared_preferences.corrupt-….json.';
	@override String autoConnectHeldTitle({required Object name}) => '${name} n\'a pas été connecté automatiquement';
	@override String autoConnectHeld({required Object name}) => 'HaLo a cessé de répondre la dernière fois qu\'il a commencé à se connecter à ${name} : il n\'y a donc pas touché cette fois, plutôt que de risquer de recommencer. Vérifiez que la radio est allumée et son câble branché, puis appuyez sur Connecter pour celle-ci dans les Paramètres.';
}

// Path: syncAccount
class _Translations$syncAccount$fr extends Translations$syncAccount$en {
	_Translations$syncAccount$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String anonymous({required Object id}) => 'Compte anonyme (#${id})';
	@override String pendingConfirmation({required Object email}) => '${email} (confirmation en attente)';
	@override String pendingConfirmationWithId({required Object email, required Object id}) => '${email} (confirmation en attente - #${id})';
}

// Path: deepLink
class _Translations$deepLink$fr extends Translations$deepLink$en {
	_Translations$deepLink$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get needsAnOperation => 'Commencez d\'abord une opération, puis renvoyez ce contact';
	@override String get waitingInOperation => 'Ce contact attend dans l\'opération derrière cet écran';
	@override String unknownActivities({required Object refs}) => 'Cet appareil n\'a aucune activité pour ${refs} : ces références ont donc été omises';
	@override String activitiesUnavailable({required Object refs}) => 'Impossible de joindre vos activités : ${refs} a donc été omis — réessayez ce lien';
}

// Path: confirmDevice
class _Translations$confirmDevice$fr extends Translations$confirmDevice$en {
	_Translations$confirmDevice$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confirmer un appareil';
	@override String get codePrompt => 'Saisissez le code affiché sur l\'appareil qui veut rejoindre ce compte.';
	@override String get code => 'Code';
	@override String get lookUp => 'Rechercher';
	@override String get codeNotFound => 'Aucune demande ne correspond à ce code. Les codes expirent au bout de 10 minutes — demandez-en un nouveau à l\'autre appareil.';
	@override String get linkExpired => 'Ce lien a expiré. Demandez à l\'autre appareil d\'afficher un nouveau code QR.';
	@override String areYouSure({required Object device}) => 'Lier ${device} à ce compte ?';
	@override String get unnamedDevice => 'un appareil sans nom';
	@override String get grantWarning => 'Il pourra lire et modifier chaque opération et chaque QSO de ce compte.';
	@override String get needsSyncTitle => 'Cet appareil ne se synchronise pas encore';
	@override String get needsSyncText => 'Activez la synchronisation Ham2K Log Filer et liez cet appareil à un compte avant de pouvoir en admettre un autre.';
	@override String get malformedRequest => 'Le serveur de synchronisation a envoyé une demande que cette application ne peut pas lire. Demandez à l\'autre appareil de réessayer.';
	@override String get linkIt => 'Lier l\'appareil';
}

// Path: switchAccounts
class _Translations$switchAccounts$fr extends Translations$switchAccounts$en {
	_Translations$switchAccounts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get noAccountDetails => 'Aucun détail de compte pour l\'instant';
	@override String get currentAccount => 'Compte actuel';
	@override String get otherAccounts => 'Autres comptes';
	@override String get linkToAnother => 'Lier à un autre compte';
	@override String get linkWithSibling => 'Lier avec une autre application Ham2K';
	@override String get linkWithPolo => 'Lier avec le compte de l\'ancienne version';
	@override String get linkWithSiblingDescription => 'Une autre application Ham2K est installée. Liez-vous au compte qu\'elle utilise.';
	@override String siblingPrompt({required Object app}) => 'Approuvez la demande dans ${app}, puis revenez ici.';
	@override String openSiblingAgain({required Object app}) => 'Rouvrir ${app}';
	@override String get siblingNoGrant => 'Ça n\'a pas marché ? Rouvrez-la, ou revenez en arrière et liez autrement.';
	@override String siblingOpenFailed({required Object app}) => 'Impossible d\'ouvrir ${app}.';
	@override String siblingLinkRenewed({required Object app}) => 'Le lien a expiré et un nouveau est prêt — rouvrez ${app}.';
	@override String get tryAgain => 'Réessayer';
	@override String get linkWithQr => 'Lier avec un code QR';
	@override String get linkWithQrDescription => 'Scannez-le depuis un appareil qui utilise déjà le compte';
	@override String get linkWithEmail => 'Lier avec une adresse e-mail';
	@override String get linkWithEmailDescription => 'Confirmez avec un code ou un lien par e-mail';
	@override String get enterEmailPrompt => 'Saisissez l\'adresse e-mail du compte que cet appareil doit utiliser.';
	@override String get emailAddress => 'Adresse e-mail';
	@override String get linkAccount => 'Lier le compte';
	@override String get copiedCode => 'Code copié dans le presse-papiers';
	@override String get copyCode => 'Copier le code';
	@override String codePrompt({required Object email}) => 'Ouvrez l\'application Ham2K sur un appareil déjà lié à ${email} et saisissez ce code pour approuver la demande :';
	@override String get waitingForConfirmation => 'En attente de confirmation…';
	@override String get sendEmailInstead => 'Envoyer plutôt un e-mail de confirmation';
	@override String emailSent({required Object email}) => 'Un e-mail a été envoyé à ${email}. Ouvrez-le et confirmez la demande pour lier cet appareil.';
	@override String get resendEmail => 'Renvoyer l\'e-mail';
	@override String get qrPrompt => 'Scannez ce code QR depuis un appareil déjà lié au compte souhaité — par exemple avec Ham2K Portable Logger sur votre téléphone.';
	@override String get serverUnreachable => 'Impossible de joindre le serveur de synchronisation. Réessayez plus tard.';
	@override String get emailRequired => 'Saisissez une adresse e-mail à lier.';
	@override String noAccountForEmail({required Object email}) => 'Aucun compte trouvé pour ${email}.';
	@override String serverRejected({required Object error}) => 'Le serveur de synchronisation a refusé la demande : ${error}';
	@override String get noLinkCode => 'Le serveur de synchronisation n\'a pas renvoyé de code de liaison. Réessayez plus tard.';
	@override String get noConfirmationCode => 'Le serveur de synchronisation n\'a pas envoyé de code de confirmation. Réessayez plus tard.';
	@override String get switchNotAccepted => 'Ce compte n\'a pas accepté le changement. Essayez plutôt de le lier avec une adresse e-mail.';
	@override String get requestFailed => 'Un problème est survenu en dialoguant avec le serveur de synchronisation. Réessayez plus tard.';
	@override String qsoCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} QSO',
		other: '${count} QSOs',
	);
	@override String operationCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} opération',
		other: '${count} opérations',
	);
}

// Path: adifImport
class _Translations$adifImport$fr extends Translations$adifImport$en {
	_Translations$adifImport$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importer des QSOs depuis ADIF';
	@override String reading({required Object filename}) => 'Lecture de ${filename}…';
	@override String get dropHint => 'Déposez un fichier ADIF à importer';
	@override String totalInFile({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} QSO dans ce fichier',
		other: '${formatted} QSOs dans ce fichier',
	);
	@override String alreadyLogged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} déjà dans votre journal',
		other: '${formatted} déjà dans votre journal',
	);
	@override String willImport({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} sera importé',
		other: '${formatted} seront importés',
	);
	@override String newContacts({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} nouveau contact',
		other: '${formatted} nouveaux contacts',
	);
	@override String merging({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} sera fusionné avec un contact existant',
		other: '${formatted} seront fusionnés avec des contacts existants',
	);
	@override String unusable({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} ne peut pas être importé (pas d\'indicatif)',
		other: '${formatted} ne peuvent pas être importés (pas d\'indicatif)',
	);
	@override String flagged({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} mérite un examen plus attentif',
		other: '${formatted} méritent un examen plus attentif',
	);
	@override String missingRefs({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Les références n\'ont pas pu être récupérées pour ${count} contact',
		other: 'Les références n\'ont pas pu être récupérées pour ${formatted} contacts',
	);
	@override String partialRefs({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Les références ${programs} sont peut-être incomplètes pour ${count} contact',
		other: 'Les références ${programs} sont peut-être incomplètes pour ${formatted} contacts',
	);
	@override String get stackingTypesUnknown => 'Les contacts combinés risquent de perdre une référence — les activités n\'ont pas pu indiquer quels types se cumulent. Annulez et réessayez pour éviter cela.';
	@override String get nothingToImport => 'Rien dans ce fichier ne peut être importé';
	@override String get confirm => 'Importer';
	@override String importing({required Object filename}) => 'Importation de ${filename}…';
	@override String imported({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} contact importé depuis ${filename}',
		other: '${formatted} contacts importés depuis ${filename}',
	);
	@override String failed({required Object filename, required Object error}) => 'Impossible d\'importer ${filename} : ${error}';
	@override String notAdif({required Object filename}) => '${filename} ne ressemble pas à un fichier ADIF';
	@override String stationWarning({required Object calls, required Object station}) => 'Attention : cet ADIF contient des QSOs de ${calls}, mais ils seront importés comme ${station} si vous continuez.';
	@override String get stationCallJoin => ' et ';
	@override String noDate({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} n\'a pas de date et ne peut pas être importé',
		other: '${formatted} n\'ont pas de date et ne peuvent pas être importés',
	);
	@override String activationFound({required Object refs}) => 'Ce fichier contient une activation de ${refs}.';
	@override String get addActivation => 'L\'ajouter à cette opération';
	@override String shortfall({required Object written, required Object planned}) => 'Seuls ${written} sur ${planned} ont pu être appliqués — le journal a changé pendant que vous décidiez.';
	@override String get busy => 'Une importation est déjà en cours. Attendez qu\'elle se termine avant d\'en lancer une autre.';
	@override String get oneFileOnly => 'Déposez un seul fichier ADIF à la fois — l\'ordre d\'importation des fichiers détermine quelles données l\'emportent.';
	@override String tooMany({required Object filename, required Object limit}) => '${filename} contient plus de ${limit} QSOs, le maximum qu\'une opération peut importer à la fois.';
}

// Path: offline
class _Translations$offline$fr extends Translations$offline$en {
	_Translations$offline$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get statusOffline => 'Internet : HORS LIGNE';
	@override String get statusOnline => 'Internet : connecté';
	@override String get noRoute => 'Aucune connexion réseau.';
	@override String get unreachable => 'Le réseau fonctionne, mais aucun serveur ne répond — souvent une page de connexion qui attend dans un navigateur.';
	@override String get reachable => 'Tous les services répondent normalement.';
	@override String get whatStops => 'Les recherches, les spots et les fichiers de données sont en pause. La saisie et la synchronisation à proximité ne le sont pas.';
	@override String get servicesTitle => 'Services';
	@override String get noServices => 'Aucun service ne s\'est encore manifesté.';
	@override String lastSuccess({required Object when}) => 'Dernière réponse il y a ${when}';
	@override String get neverSucceeded => 'N\'a pas encore répondu';
	@override String nextAttempt({required Object when}) => 'Prochaine tentative dans ${when}';
	@override String get nextAttemptNow => 'Prochaine tentative imminente';
	@override String get retry => 'Réessayer maintenant';
	@override String get retrying => 'Tentative…';
	@override String get retryReached => 'De nouveau en ligne.';
	@override String get retryUnreachable => 'Toujours aucune réponse.';
	@override String get retryNotAttempted => 'Rien à envoyer pour le moment.';
	@override String get retryThrottled => 'Tentative à l\'instant — patientez un peu.';
	@override String get retryDisabled => 'La synchronisation est désactivée : il n\'y a donc rien avec quoi tester.';
	@override String get syncService => 'Synchronisation Ham2K LoFi';
	@override String get retryInFlight => 'Tentative déjà en cours — patientez.';
}

// Path: exportSettings
class _Translations$exportSettings$fr extends Translations$exportSettings$en {
	_Translations$exportSettings$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get defaultsDescription => 'Paramètres de base pour tous les exports, avec des modèles de nom de fichier et de titre distincts pour les activités de référence et les autres activités. Chaque type d\'export peut fournir ses propres valeurs par défaut ou des paramètres personnalisés.';
	@override String get referenceActivities => 'Activités de référence';
	@override String get otherActivities => 'Autres activités';
	@override String get adifFields => 'Champs ADIF';
	@override String get loadFailed => 'Les paramètres d\'export n\'ont pas pu être chargés.';
	@override String get retry => 'Réessayer';
	@override String get compactFileNamesDescriptionOn => 'Noms de fichiers compacts, comme N0CALL@US-1234-20260715.adi.';
	@override String get compactFileNamesDescriptionOff => 'Noms de fichiers descriptifs, comme 2026-07-15 N0CALL at US-1234.adi.';
	@override String get includePrivateDataDescriptionOn => 'Inclusion des noms, adresses, e-mails, notes et positions précises dans les fichiers ADIF.';
	@override String get includePrivateDataDescriptionOff => 'Exclusion des noms, adresses, e-mails et notes ; positions limitées à des locators à six caractères.';
	@override String get includeLookupDataDescriptionOn => 'Inclusion des informations provenant des services de recherche d\'indicatifs.';
	@override String get includeLookupDataDescriptionOff => 'Exclusion des informations provenant des services de recherche d\'indicatifs ; les valeurs saisies manuellement sont conservées.';
	@override String get customTemplatesDescriptionOn => 'Vos modèles personnalisés sont actifs et peuvent être modifiés ci-dessous.';
	@override String get customTemplatesDescriptionOff => 'Les modèles par défaut sont actifs. Vos modèles personnalisés sont conservés pour plus tard.';
	@override String get type => 'Type d\'export';
	@override String get defaults => 'Valeurs par défaut';
	@override String get includeLookupData => 'Inclure les données de recherche';
	@override String get customTemplates => 'Modèles personnalisés';
	@override String get filenameTemplate => 'Modèle de nom de fichier';
	@override String get compactFilenameTemplate => 'Modèle de nom de fichier compact';
	@override String get titleTemplate => 'Modèle de titre';
	@override String get adifNotesTemplate => 'Notes QSO ADIF';
	@override String get adifCommentTemplate => 'Commentaires QSO ADIF';
	@override String get adifQslMessageTemplate => 'Message QSL ADIF';
	@override String get shared => 'Les paramètres s\'appliquent à toutes les extensions utilisant ce type d\'export.';
	@override String get defaultTemplates => 'Activez Modèles personnalisés pour modifier les modèles de ce type.';
}

// Path: templateEditor
class _Translations$templateEditor$fr extends Translations$templateEditor$en {
	_Translations$templateEditor$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get previewLabel => 'Aperçu :';
	@override String get reset => 'Réinitialiser';
	@override String get docs => 'Documentation des modèles';
	@override String get preview => 'Aperçu d\'exemple';
	@override String get reference => 'Référence des modèles';
	@override String get attributes => 'Attributs disponibles';
	@override String get filters => 'Filtres';
	@override String get flowControl => 'Contrôle de flux';
	@override String get unavailable => 'L\'aperçu est indisponible tant que les extensions ne sont pas prêtes.';
	@override String get empty => '(sortie vide)';
}

// Path: home.nav
class _Translations$home$nav$fr extends Translations$home$nav$en {
	_Translations$home$nav$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Opérations';
	@override String get chase => 'Chasse';
	@override String get logs => 'Journaux';
	@override String get maps => 'Cartes';
	@override String get settings => 'Paramètres';
}

// Path: home.panels
class _Translations$home$panels$fr extends Translations$home$panels$en {
	_Translations$home$panels$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get operations => 'Liste d\'opérations';
	@override String get operationsDescription => 'Vos opérations, les plus récentes en premier.';
	@override String get version => 'Version actuelle';
	@override String get versionDescription => 'Le logo Ham2K, le nom de cette application et la version que vous utilisez.';
}

// Path: home.logs
class _Translations$home$logs$fr extends Translations$home$logs$en {
	_Translations$home$logs$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Journaux';
	@override String get titleFor => 'Journaux pour';
	@override String get emptyCallsigns => 'Aucun QSO enregistré pour l\'instant';
	@override String emptyQsos({required Object call}) => 'Aucun QSO pour ${call}';
	@override String get mapNoSelection => 'Sélectionnez un QSO pour le voir sur la carte';
	@override String get searchHint => 'Rechercher un indicatif ou un nom';
	@override String get noSearchMatches => 'Aucun QSO ne correspond à votre recherche';
	@override String get titleAll => 'Tous les journaux';
	@override String get allCallsigns => 'Tous les indicatifs';
	@override String get noOperation => 'Hors opération';
	@override String get unsavedTitle => 'Modifications non enregistrées';
	@override String get unsavedBody => 'Ce QSO contient des modifications que vous n\'avez pas enregistrées.';
	@override String get pendingDeleteBody => 'Ce QSO est marqué pour suppression.';
	@override String get editGone => 'Non enregistré : ce QSO ne fait plus partie de ce journal.';
	@override String get discard => 'Abandonner';
	@override late final _Translations$home$logs$columns$fr columns = _Translations$home$logs$columns$fr._(_root);
	@override late final _Translations$home$logs$panels$fr panels = _Translations$home$logs$panels$fr._(_root);
	@override late final _Translations$home$logs$import$fr import = _Translations$home$logs$import$fr._(_root);
}

// Path: chase.station
class _Translations$chase$station$fr extends Translations$chase$station$en {
	_Translations$chase$station$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Station de chasse';
	@override String get stationLabel => 'Station : ';
	@override String get operatorLabel => 'Op : ';
	@override String get noLocation => 'Aucun emplacement';
}

// Path: chase.periodInline
class _Translations$chase$periodInline$fr extends Translations$chase$periodInline$en {
	_Translations$chase$periodInline$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get today => 'aujourd\'hui';
	@override String get thisWeek => 'cette semaine';
	@override String get last14Days => 'ces 14 derniers jours';
	@override String get thisMonth => 'ce mois-ci';
}

// Path: chase.periodStats
class _Translations$chase$periodStats$fr extends Translations$chase$periodStats$en {
	_Translations$chase$periodStats$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Statistiques du jour';
	@override String get thisWeek => 'Statistiques de la semaine';
	@override String get last14Days => 'Statistiques des 14 derniers jours';
	@override String get thisMonth => 'Statistiques du mois';
}

// Path: chase.period
class _Translations$chase$period$fr extends Translations$chase$period$en {
	_Translations$chase$period$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get today => 'Aujourd\'hui';
	@override String get thisWeek => 'Cette semaine';
	@override String get last14Days => '14 derniers jours';
	@override String get thisMonth => 'Ce mois-ci';
}

// Path: chase.goals
class _Translations$chase$goals$fr extends Translations$chase$goals$en {
	_Translations$chase$goals$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Objectifs de chasse';
	@override String remove({required Object name}) => 'Arrêter de chasser ${name}';
	@override String get extensionsTitle => 'Extensions qui incluent la chasse';
}

// Path: chase.panels
class _Translations$chase$panels$fr extends Translations$chase$panels$en {
	_Translations$chase$panels$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get logging => 'QSOs';
	@override String get loggingDescription => 'Les contrôles de saisie au-dessus des QSOs chassés sur la période.';
	@override String get info => 'Infos';
	@override String get infoDescription => 'L\'indicatif en cours de saisie, ou les statistiques de la période.';
	@override String get spots => 'Spots';
	@override String get spotsDescription => 'Les stations spottées en l\'air, prêtes à être chassées.';
	@override String get map => 'Carte';
	@override String get mapDescription => 'Les QSOs de la période et la station en cours de saisie.';
}

// Path: dialogs.callChange
class _Translations$dialogs$callChange$fr extends Translations$dialogs$callChange$en {
	_Translations$dialogs$callChange$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String invalidCallsign({required Object call}) => 'Indicatif invalide : ${call}';
	@override String invalidCallsigns({required Object calls}) => 'Indicatifs invalides : ${calls}';
	@override String operatorSoFar({required Object previous, required Object typed}) => '${previous} a opéré jusqu\'à présent. ${typed} sera enregistré pour les nouveaux contacts.';
	@override String operatorNoneSoFar({required Object typed}) => 'Aucun opérateur enregistré jusqu\'à présent. ${typed} sera enregistré pour les nouveaux contacts.';
	@override String operatorSeveral({required Object calls, required Object typed}) => 'Cette opération contient déjà des contacts par ${calls}. ${typed} ne sera enregistré que pour les nouveaux.';
	@override String operatorRestamp({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Enregistrer aussi ${typed} comme opérateur du contact déjà saisi',
		other: 'Enregistrer aussi ${typed} comme opérateur des ${count} contacts déjà saisis',
	);
	@override String get operatorSeveralStations => 'Avec plusieurs indicatifs de station en l\'air, les opérateurs distincts ne sont pas pris en charge';
	@override String get contactsUnreadable => 'Les contacts de cette opération n\'ont pas pu être lus : changer un indicatif ici ne proposera pas de les mettre à jour';
	@override String restampFailed({required Object error}) => 'Les contacts déjà saisis n\'ont pas pu être mis à jour, aucune modification n\'a donc été faite : ${error}';
	@override String restampShortfall({required Object written, required Object planned}) => '${written} contacts sur ${planned} ont été mis à jour — les autres ne font plus partie de cette opération';
}

// Path: operation.tabs
class _Translations$operation$tabs$fr extends Translations$operation$tabs$en {
	_Translations$operation$tabs$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String qsos({required Object count}) => '${count} QSOs';
	@override String get info => 'INFOS';
	@override String get spots => 'SPOTS';
	@override String get map => 'CARTE';
	@override String get qsosPlain => 'QSOs';
	@override String get clock => 'Horloge';
	@override String get weather => 'Météo';
	@override String get website => 'Site web';
	@override String get remoteScreen => 'Écran distant';
	@override String get solar => 'Solaire';
	@override String get radio => 'Radio';
}

// Path: operation.positions
class _Translations$operation$positions$fr extends Translations$operation$positions$en {
	_Translations$operation$positions$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get nobodyYet => 'Aucune autre position d\'opération ne partage encore cette opération.';
	@override String positionLabel({required Object number}) => 'Pos : ${number}';
	@override String operatorLabel({required Object call}) => 'Op : ${call}';
	@override String get unnamedPosition => 'Une autre position';
	@override String get thisDevice => 'Notre position d\'opération';
	@override String get nameIn => ' à ';
	@override String get panelTitle => 'Positions';
	@override String get panelDescription => 'Ce que chaque position d\'opération partageant cette opération saisit en ce moment.';
}

// Path: operation.menu
class _Translations$operation$menu$fr extends Translations$operation$menu$en {
	_Translations$operation$menu$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get showRstFields => 'Afficher les champs RST';
	@override String get showStateField => 'Afficher le champ État';
	@override String get showGridField => 'Afficher le champ Grille';
	@override String get showDeletedQsos => 'Afficher les QSOs supprimés';
	@override String get showDeletedOps => 'Afficher les opérations supprimées';
	@override String get showQsoNumbers => 'Afficher les numéros de QSO';
	@override String get lookupAllQsos => 'Rechercher tous les QSOs';
	@override String get loggingSettingsTitle => 'Paramètres de saisie';
	@override String get mapSettingsTitle => 'Paramètres de la carte';
	@override String get actionsSection => 'Actions';
}

// Path: operation.layout
class _Translations$operation$layout$fr extends Translations$operation$layout$en {
	_Translations$operation$layout$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ajouter un panneau';
	@override String get availableSection => 'Panneaux disponibles';
	@override String panelSettings({required Object panel}) => 'Paramètres de ${panel}';
	@override String get panelSettingsAction => 'Paramètres du panneau';
	@override String get viewName => 'Vue d\'opération';
	@override String get viewOptions => 'Options de disposition de la vue';
	@override String get viewTitleBuiltIn => 'Cette vue est intégrée à l\'application, tout comme son nom';
	@override String get resetOptions => 'Rétablir les valeurs par défaut';
	@override String get removePane => 'Retirer';
	@override String resetPaneConfirm({required Object panel}) => 'Rétablir ${panel} à ses valeurs par défaut ?';
	@override String get resetPaneConfirmBody => 'Son titre, son en-tête et sa taille reviennent aux valeurs par défaut. Le reste de la disposition ne change pas.';
	@override String get resetViewConfirm => 'Rétablir la disposition par défaut de cette vue ?';
	@override String get resetViewConfirmBody => 'Les panneaux reprennent leur disposition par défaut, et les options de la vue et de chaque panneau reviennent aux valeurs par défaut.';
	@override String paneOptionsTitle({required Object panel}) => 'Paramètres de disposition de ${panel}';
	@override String get paneTitle => 'Titre';
	@override String get paneShowHeader => 'Afficher l\'en-tête';
	@override String get paneShowHeaderTabset => 'Toujours affiché tant que ce volet partage un groupe — l\'en-tête permet d\'accéder aux autres';
	@override String get paneInherit => 'Comme l\'application';
	@override String get searchHint => 'Rechercher des panneaux';
	@override String get noPanelsMatch => 'Aucun panneau ne correspond à votre recherche.';
	@override String get nothingToAdd => 'Cette vue contient déjà tous les panneaux possibles';
	@override String addPanel({required Object panel}) => 'Ajouter ${panel}';
	@override String showPreview({required Object panel}) => 'Aperçu de ${panel}';
	@override String missingExtension({required Object name}) => 'L\'extension « ${name} » est manquante';
	@override String get previewUnavailable => 'L\'aperçu de ce panneau n\'a pas pu être affiché.';
	@override String get nestedPaneTitle => 'Plus';
	@override String get editLayout => 'Modifier la disposition';
	@override String get saveLayout => 'Enregistrer la disposition';
	@override String get revertLayout => 'Abandonner les modifications de disposition';
	@override String get done => 'Terminé';
	@override String get layoutUnreadableTitle => 'Disposition illisible';
	@override String get layoutUnreadableBody => 'Votre disposition enregistrée n\'a pas pu être lue, la disposition par défaut est donc affichée à la place. Elle ne remplacera votre original que si vous choisissez de la conserver.';
	@override String get layoutUnreadableAction => 'Utiliser cette disposition';
	@override String panelRenderFailed({required Object panel}) => '${panel} n\'a pas pu être affiché';
	@override String get panelRenderRetry => 'Réessayer';
	@override String get panelActionFailed => 'L\'action du panneau a échoué. Réessayez.';
	@override late final _Translations$operation$layout$panels$fr panels = _Translations$operation$layout$panels$fr._(_root);
	@override String get htmlPanelUnsupported => 'Ce panneau nécessite une vue web, que cette plateforme ne fournit pas';
	@override String get htmlPanelUnsupportedOnWeb => 'Ce panneau nécessite un bac à sable que la version web ne peut pas fournir';
}

// Path: operation.export
class _Translations$operation$export$fr extends Translations$operation$export$en {
	_Translations$operation$export$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exports de l\'opération';
	@override String get syncedOperation => 'L\'opération est synchronisée';
	@override String get unsyncedOperation => 'L\'opération a des modifications non synchronisées';
	@override String qsosInOperation({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} QSO dans cette opération',
		other: '${count} QSOs dans cette opération',
	);
	@override String qsosSynced({required Object total}) => 'Les ${total} QSOs sont synchronisés';
	@override String qsosPending({required Object pending, required Object total}) => '${pending} QSOs sur ${total} en attente de synchronisation';
	@override String eventsSynced({required Object total}) => '${total} marqueurs d\'événement synchronisés';
	@override String eventsPending({required Object pending, required Object total}) => '${pending} marqueurs d\'événement sur ${total} en attente';
	@override String get loading => 'Chargement des options d\'export…';
	@override String get noOptions => 'Aucun format d\'export disponible (le moteur d\'extensions démarre encore ?)';
	@override String get nothingLogged => 'Rien à exporter pour l\'instant — cette opération n\'a aucun QSO.';
	@override String get share => 'Partager';
	@override String get nothingSelected => 'Aucune sélection';
	@override String saveFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Enregistrer ${count} fichier',
		other: 'Enregistrer ${count} fichiers',
	);
	@override String shareFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Partager ${count} fichier',
		other: 'Partager ${count} fichiers',
	);
	@override String exportFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Exporter ${count} fichier',
		other: 'Exporter ${count} fichiers',
	);
	@override String downloadFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Télécharger ${count} fichier',
		other: 'Télécharger ${count} fichiers',
	);
	@override String saveCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Enregistrer ${count} fichier combiné',
		other: 'Enregistrer ${count} fichiers combinés',
	);
	@override String shareCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Partager ${count} fichier combiné',
		other: 'Partager ${count} fichiers combinés',
	);
	@override String exportCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Exporter ${count} fichier combiné',
		other: 'Exporter ${count} fichiers combinés',
	);
	@override String downloadCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Télécharger ${count} fichier combiné',
		other: 'Télécharger ${count} fichiers combinés',
	);
	@override String saveOne({required Object name}) => 'Enregistrer ${name}';
	@override String shareOne({required Object name}) => 'Partager ${name}';
	@override String exportOne({required Object name}) => 'Exporter ${name}';
	@override String downloadOne({required Object name}) => 'Télécharger ${name}';
	@override String stashFiles({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Stocker ${count} fichier',
		other: 'Stocker ${count} fichiers',
	);
	@override String stashCombined({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Stocker ${count} fichier combiné',
		other: 'Stocker ${count} fichiers combinés',
	);
	@override String get settingsButton => 'Paramètres d\'export';
	@override String get settingsTitle => 'Paramètres d\'export';
	@override late final _Translations$operation$export$compactFileNames$fr compactFileNames = _Translations$operation$export$compactFileNames$fr._(_root);
	@override late final _Translations$operation$export$includePrivateData$fr includePrivateData = _Translations$operation$export$includePrivateData$fr._(_root);
	@override String get resultTitle => 'Export terminé';
	@override String get resultFailedTitle => 'Échec de l\'export';
	@override String saveSuccess({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} fichier exporté vers ${path}',
		other: '${count} fichiers exportés vers ${path}',
	);
	@override String saveSuccessNamed({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} fichier exporté : ${path}',
		other: '${count} fichiers exportés : ${path}',
	);
	@override String shareSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} fichier partagé',
		other: '${count} fichiers partagés',
	);
	@override String downloadSuccess({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} fichier téléchargé',
		other: '${count} fichiers téléchargés',
	);
	@override String exportFailed({required Object error}) => 'Échec de l\'export : ${error}';
	@override late final _Translations$operation$export$stash$fr stash = _Translations$operation$export$stash$fr._(_root);
}

// Path: operation.spots
class _Translations$operation$spots$fr extends Translations$operation$spots$en {
	_Translations$operation$spots$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get empty => 'Aucun spot ne correspond à vos filtres';
	@override String error({required Object error}) => 'Échec du chargement des spots : ${error}';
	@override String get unknownBand => 'Autre';
	@override String get auto => 'Automatique';
	@override String autoValue({required Object value}) => 'Automatique (actuellement ${value})';
	@override String valueAuto({required Object value}) => '${value} (auto)';
	@override String get any => 'Tous';
	@override String get allBands => 'Toutes les bandes';
	@override String get allModes => 'Tous les modes';
	@override String get phoneAndCw => 'Phonie et CW';
	@override String spotsCount({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} spot',
		other: '${count} spots',
	);
	@override String spotsCountFiltered({required Object count, required Object total}) => 'Affichage de ${count} spots sur ${total}';
	@override String ageMinutes({required Object minutes}) => '${minutes} minutes';
	@override String get callsOfNote => 'Indicatifs notables';
	@override String get yourSpots => 'Vos spots';
	@override String get allSpots => 'Tous les spots';
	@override late final _Translations$operation$spots$continents$fr continents = _Translations$operation$spots$continents$fr._(_root);
	@override late final _Translations$operation$spots$filters$fr filters = _Translations$operation$spots$filters$fr._(_root);
	@override String get unavailableTitle => 'Spots indisponibles';
	@override String unavailableText({required Object sources}) => '${sources} n\'a pas répondu.';
	@override String get failedTitle => 'Erreur de source de spots';
	@override String failedText({required Object sources}) => '${sources} a renvoyé une erreur.';
	@override String get slideLogIt => 'Saisir';
	@override String get slideIgnore => 'Ignorer';
	@override String get slideRestore => 'Restaurer';
	@override late final _Translations$operation$spots$logConflict$fr logConflict = _Translations$operation$spots$logConflict$fr._(_root);
}

// Path: operation.import
class _Translations$operation$import$fr extends Translations$operation$import$en {
	_Translations$operation$import$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Importer des données dans l\'opération';
	@override String get importAdifAction => 'Importer des QSOs depuis ADIF';
	@override String get settingsButton => 'Paramètres d\'écoute';
	@override String get settingsTitle => 'Écouter d\'autres applications';
	@override String get protocolAddressLabel => 'Adresse';
	@override String get protocolPortLabel => 'Port';
	@override String get protocolPortInvalid => 'Entrez un port entre 1 et 65535';
	@override String get protocolAddressInvalid => 'Entrez une adresse IP valide (par ex. 127.0.0.1 ou 239.239.0.2)';
	@override String get protocolStatusReceiving => 'Réception de données';
	@override String get protocolStatusNoData => 'Aucune donnée reçue récemment';
	@override String protocolBindError({required Object error}) => 'Impossible de démarrer l\'écoute : ${error}';
	@override String captureFailed({required Object error}) => 'Les QSOs entrants n\'ont pas pu être enregistrés, nouvelle tentative en cours : ${error}';
	@override String get n1mmProtocolName => 'N1MM+ Contact Broadcast';
	@override String get n1mmAddressValue => 'Toutes (diffusion)';
	@override String get wsjtxProtocolName => 'Serveur UDP WSJT-X';
	@override String get helpN1mmSetup => 'Config → Configure Ports, Mode Control… → onglet Broadcast Data → cochez "Enable Broadcasts" pour les infos de contact. Réglez l\'adresse IP sur 127.0.0.1 si N1MM+ tourne sur ce même ordinateur, ou sur 255.255.255.255 pour diffuser sur le réseau local actuel.';
	@override String get helpWsjtxSetup => 'File → Settings → onglet Reporting → section UDP Server → cochez "Accept UDP requests". Réglez UDP Server sur 127.0.0.1 si WSJT-X tourne sur ce même ordinateur, ou sur une adresse multicast comme 239.239.0.2, et utilisez la même adresse dans la configuration ci-dessus dans cette application.';
	@override String get listenTitle => 'Écouter les QSOs d\'autres applications';
	@override String get listenDescriptionOnN1mm => 'Écoute de N1MM+';
	@override String get listenDescriptionOnWsjtx => 'Écoute de WSJT-X';
	@override String get listenDescriptionOnBoth => 'Écoute de N1MM+ et WSJT-X';
	@override String get listenDescriptionOff => 'Désactivé';
	@override String get addToOperationTitle => 'Ajouter à cette opération';
	@override String get addToOperationDescriptionOn => 'Les QSOs capturés sont ajoutés à cette opération dès leur arrivée';
	@override String get addToOperationDescriptionOff => 'Les QSOs capturés sont retenus jusqu\'à ce que vous activiez cette option';
	@override String get pendingSectionTitle => 'QSOs capturés';
	@override String get pendingEmpty => 'Rien de capturé pour l\'instant';
	@override String stationMismatch({required Object call}) => 'Saisi comme ${call}, pas l\'indicatif de station de cette opération';
	@override String get discardAction => 'Abandonner';
	@override String get gapDialogTitle => 'Inclure les captures précédentes ?';
	@override String gapDialogBody({required Object count}) => '${count} QSOs de plus ont été capturés plus tôt, avant une interruption des données. Les inclure aussi ?';
	@override String get gapDialogRecentOnly => 'Seulement les récents';
	@override String gapDialogIncludeAll({required Object count}) => 'Inclure les ${count}';
}

// Path: map.outlineIssue
class _Translations$map$outlineIssue$fr extends Translations$map$outlineIssue$en {
	_Translations$map$outlineIssue$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get link => 'Un problème ?';
	@override String get title => 'Signaler un problème de contour';
	@override String get reference => 'Quel contour';
	@override String get severity => 'Quelle gravité ?';
	@override String get minor => 'Détail mineur';
	@override String get major => 'Problème important';
	@override String get explanation => 'Qu\'est-ce qui ne va pas ?';
	@override String get explanationHint => 'Ce que le contour indique de faux, et où';
	@override String get send => 'Envoyer';
	@override String get sending => 'Envoi de votre signalement — merci';
	@override String get copy => 'Copier le signalement';
	@override String get notSent => 'Impossible d\'envoyer le signalement';
	@override String get copied => 'Signalement copié';
	@override String get notCopied => 'Impossible de copier le signalement';
}

// Path: map.postcard
class _Translations$map$postcard$fr extends Translations$map$postcard$en {
	_Translations$map$postcard$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get button => 'Carte postale de l\'opération';
	@override String title({required Object title}) => 'Carte postale pour ${title}';
	@override String get portrait => 'Portrait';
	@override String get landscape => 'Paysage';
	@override String get square => 'Carré';
	@override String get save => 'Enregistrer…';
	@override String get download => 'Télécharger';
	@override String get share => 'Partager';
	@override String get copy => 'Copier';
	@override String get copied => 'Copié dans le presse-papiers';
	@override String saved({required Object path}) => 'Enregistré dans ${path}';
	@override String downloaded({required Object name}) => '${name} téléchargé';
	@override String savedMany({required Object count, required Object path}) => '${count} images enregistrées dans ${path}';
	@override String savedFiles({required Object names}) => '${names} enregistré(s)';
	@override String savePartial({required Object error, required Object names}) => '${error} — ${names} avait déjà été enregistré';
	@override String downloadedMany({required Object count}) => 'Téléchargement de ${count} images — autorisez-les si le navigateur le demande';
	@override String get mapLeftOut => 'La carte n\'a pas chargé, elle a donc été omise';
	@override String withMapLeftOut({required Object outcome}) => '${outcome} — la carte n\'a pas chargé, elle a donc été omise';
	@override String continued({required Object title}) => '${title} (suite)';
	@override String get previousPage => 'Page précédente';
	@override String get nextPage => 'Page suivante';
	@override String pageOf({required Object page, required Object count}) => 'Page ${page} sur ${count}';
	@override String get sectionDays => 'Chaque jour';
	@override String get reset => 'Réinitialiser';
	@override String failed({required Object error}) => 'Impossible de créer la carte postale : ${error}';
	@override String get mapNotReady => 'La carte n\'a pas fini de charger. Vérifiez la connexion et réessayez.';
	@override String saveFailed({required Object error}) => 'Impossible d\'enregistrer la carte postale : ${error}';
	@override String get copyFailed => 'Le presse-papiers n\'a pas accepté l\'image. Réessayez.';
	@override String get shareFailed => 'Impossible de partager la carte postale. Réessayez.';
	@override String get fileName => 'carte-postale';
}

// Path: loggingControls.info
class _Translations$loggingControls$info$fr extends Translations$loggingControls$info$en {
	_Translations$loggingControls$info$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get noQsos => 'Pas encore de QSOs… Allez faire de la radio !';
	@override String get qsoCountOne => '1 QSO';
	@override String qsoCountOther({required Object count}) => '${count} QSOs';
	@override String qsosInTime({required Object count, required Object time}) => '${count} en ${time}';
	@override String sinceLast({required Object time}) => '${time} depuis le dernier';
	@override String ratePer10({required Object rate}) => '${rate} Q/h pour les 10 derniers';
	@override String ratePer100({required Object rate}) => '${rate} Q/h pour les 100 derniers';
	@override String distanceTo({required Object distance}) => '${distance} jusqu\'à';
	@override String distanceBearingTo({required Object distance, required Object bearing}) => '${distance} (${bearing}°) jusqu\'à';
	@override String distanceBearingsTo({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) jusqu\'à';
	@override String distanceAway({required Object distance}) => '${distance} de distance';
	@override String distanceBearingAway({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distance';
	@override String distanceBearingsAway({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distance';
	@override String noticeFromScorer({required Object scorer, required Object notice}) => '${scorer} : ${notice}';
	@override String get noticeDupe => 'Doublon !';
	@override String get noticeNewBand => 'Nouvelle bande';
	@override String get noticeNewMode => 'Nouveau mode';
	@override String get noticeNewDXCC => 'Nouveau DXCC';
	@override String get noticeNewState => 'Nouvel état';
	@override String get noticeNewProvince => 'Nouvelle province';
	@override String get noticeNewDay => 'Nouveau jour';
	@override String get noticeNewRef => 'Nouvelle réf';
	@override String get noticeNewMult => 'Nouveau mult';
	@override String get noticeNewZone => 'Nouvelle zone';
	@override String get noticeInvalidMode => 'Mauvais mode';
	@override String get noticeInvalidBand => 'Mauvaise bande';
	@override String get noticeInvalidCategory => 'Non contactable';
	@override String get noticeWorkedBefore => 'Déjà contacté';
	@override String get noticeNewPark => 'Nouveau parc';
	@override String get noticeNewSection => 'Nouvelle section';
	@override String get noticeBonusStation => 'Station bonus !';
	@override String get noticeMissingExchange => 'Pas d\'échange';
	@override String get noticeInvalidExchange => 'Échange erroné';
	@override String get noticeUnknownEvent => 'Événement inconnu';
	@override String get noticeOurGrid => 'Définir notre grille';
	@override String get noticeRareCounty => 'Comté rare !';
	@override String get noticeOurLocation => 'Définir notre comté';
	@override String get noticeShortGrid => 'Grille trop courte';
}

// Path: callInfo.history
class _Translations$callInfo$history$fr extends Translations$callInfo$history$en {
	_Translations$callInfo$history$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String last7days({required Object n}) => '${n} dans les 7 derniers jours';
	@override String today({required Object n}) => '${n} aujourd\'hui';
	@override String qsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
}

// Path: settings.theme
class _Translations$settings$theme$fr extends Translations$settings$theme$en {
	_Translations$settings$theme$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Thème';
	@override String get system => 'Suivre les réglages du système';
	@override String get light => 'Clair';
	@override String get dark => 'Sombre';
}

// Path: settings.themeDescription
class _Translations$settings$themeDescription$fr extends Translations$settings$themeDescription$en {
	_Translations$settings$themeDescription$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get system => 'Suit les réglages du système';
	@override String get light => 'Toujours en mode clair';
	@override String get dark => 'Toujours en mode sombre';
}

// Path: settings.fontScaleOpts
class _Translations$settings$fontScaleOpts$fr extends Translations$settings$fontScaleOpts$en {
	_Translations$settings$fontScaleOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get smallestMinusMinus => 'Le plus petit--';
	@override String get smallestMinus => 'Le plus petit-';
	@override String get smallest => 'Le plus petit';
	@override String get smaller => 'Plus petit';
	@override String get normal => 'Normal';
	@override String get larger => 'Plus grand';
	@override String get largest => 'Le plus grand';
	@override String get largestPlus => 'Le plus grand+';
	@override String get largestPlusPlus => 'Le plus grand++';
}

// Path: settings.keepDeviceAwake
class _Translations$settings$keepDeviceAwake$fr extends Translations$settings$keepDeviceAwake$en {
	_Translations$settings$keepDeviceAwake$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Garder l\'appareil allumé';
	@override String get descriptionOn => 'Reste allumé tant que vous êtes sur l\'écran de saisie ou qu\'une synchronisation est en cours';
	@override String get descriptionOff => 'Mise en veille comme d\'habitude';
}

// Path: settings.layoutDensityOpts
class _Translations$settings$layoutDensityOpts$fr extends Translations$settings$layoutDensityOpts$en {
	_Translations$settings$layoutDensityOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get auto => 'Automatique';
	@override String get densest => 'Très dense';
	@override String get dense => 'Dense';
	@override String get normal => 'Normale';
	@override String get sparse => 'Aérée';
	@override String get sparsest => 'Très aérée';
}

// Path: settings.distanceUnitsOpts
class _Translations$settings$distanceUnitsOpts$fr extends Translations$settings$distanceUnitsOpts$en {
	_Translations$settings$distanceUnitsOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get kilometers => 'Kilomètres';
	@override String get miles => 'Miles';
}

// Path: settings.logging
class _Translations$settings$logging$fr extends Translations$settings$logging$en {
	_Translations$settings$logging$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Saisie';
	@override late final _Translations$settings$logging$leftieMode$fr leftieMode = _Translations$settings$logging$leftieMode$fr._(_root);
	@override late final _Translations$settings$logging$countryFlags$fr countryFlags = _Translations$settings$logging$countryFlags$fr._(_root);
	@override late final _Translations$settings$logging$countryFlagsDescription$fr countryFlagsDescription = _Translations$settings$logging$countryFlagsDescription$fr._(_root);
	@override late final _Translations$settings$logging$suggestDefaultOperator$fr suggestDefaultOperator = _Translations$settings$logging$suggestDefaultOperator$fr._(_root);
	@override late final _Translations$settings$logging$showBearing$fr showBearing = _Translations$settings$logging$showBearing$fr._(_root);
	@override late final _Translations$settings$logging$showReverseBearing$fr showReverseBearing = _Translations$settings$logging$showReverseBearing$fr._(_root);
	@override late final _Translations$settings$logging$switchSentRcvd$fr switchSentRcvd = _Translations$settings$logging$switchSentRcvd$fr._(_root);
	@override late final _Translations$settings$logging$jumpAfterRST$fr jumpAfterRST = _Translations$settings$logging$jumpAfterRST$fr._(_root);
	@override late final _Translations$settings$logging$defaultReport$fr defaultReport = _Translations$settings$logging$defaultReport$fr._(_root);
	@override late final _Translations$settings$logging$defaultReportCW$fr defaultReportCW = _Translations$settings$logging$defaultReportCW$fr._(_root);
	@override late final _Translations$settings$logging$defaultReportFT8$fr defaultReportFT8 = _Translations$settings$logging$defaultReportFT8$fr._(_root);
	@override late final _Translations$settings$logging$numbersRow$fr numbersRow = _Translations$settings$logging$numbersRow$fr._(_root);
	@override late final _Translations$settings$logging$numbersRowExtra$fr numbersRowExtra = _Translations$settings$logging$numbersRowExtra$fr._(_root);
	@override late final _Translations$settings$logging$numbersRowVibrate$fr numbersRowVibrate = _Translations$settings$logging$numbersRowVibrate$fr._(_root);
	@override String get bands => 'Bandes préférées';
	@override String get modes => 'Modes préférés';
}

// Path: settings.catServer
class _Translations$settings$catServer$fr extends Translations$settings$catServer$en {
	_Translations$settings$catServer$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Serveur CAT';
	@override String get description => 'Permettre à d\'autres applications (WSJT-X, logiciels de journal, etc.) de piloter la radio via Ham2K Logger.';
	@override String get protocol => 'Protocole';
	@override late final _Translations$settings$catServer$protocolOpts$fr protocolOpts = _Translations$settings$catServer$protocolOpts$fr._(_root);
	@override String get port => 'Port';
	@override String get openAccess => 'Accès ouvert';
	@override String get openAccessOn => 'N\'importe quel ordinateur du réseau local peut se connecter.';
	@override String get openAccessOff => 'Seules les applications de cet ordinateur peuvent se connecter.';
	@override String get off => 'Désactivé.';
	@override String starting({required Object protocol}) => '${protocol}, démarrage…';
	@override String listening({required Object protocol, required Object port, required Object clients}) => '${protocol} sur le port ${port}. Clients connectés : ${clients}.';
	@override String listeningNoRadio({required Object protocol, required Object port}) => '${protocol} sur le port ${port}, mais aucune radio VFO principal n\'est connectée.';
	@override String failed({required Object protocol, required Object port, required Object error}) => '${protocol} ne peut pas écouter sur le port ${port} : ${error}';
	@override String portInUse({required Object protocol, required Object port}) => '${protocol} ne peut pas écouter sur le port ${port} : un autre programme l\'utilise, souvent ${protocol} lui-même. Fermez ce programme ou choisissez un autre port.';
	@override String portDenied({required Object protocol, required Object port}) => '${protocol} ne peut pas écouter sur le port ${port} : cet ordinateur ne l\'autorise pas. Choisissez un port supérieur à 1024.';
	@override String stopped({required Object protocol, required Object port}) => '${protocol} a cessé d\'écouter sur le port ${port}. Nouvelle tentative…';
}

// Path: settings.radio
class _Translations$settings$radio$fr extends Translations$settings$radio$en {
	_Translations$settings$radio$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Contrôle CAT';
	@override String get loggingAndCat => 'Saisie et CAT';
	@override String get tuningSection => 'Accord';
	@override String get keyerSection => 'Manipulateur';
	@override String get servicesSection => 'Services';
	@override String get stationConfigurationSection => 'Configuration de la station';
	@override String get moreSettings => 'Plus de paramètres de configuration de la station';
	@override late final _Translations$settings$radio$units$fr units = _Translations$settings$radio$units$fr._(_root);
	@override late final _Translations$settings$radio$pttKey$fr pttKey = _Translations$settings$radio$pttKey$fr._(_root);
	@override late final _Translations$settings$radio$smartVfoSnap$fr smartVfoSnap = _Translations$settings$radio$smartVfoSnap$fr._(_root);
	@override late final _Translations$settings$radio$snapDebounce$fr snapDebounce = _Translations$settings$radio$snapDebounce$fr._(_root);
	@override late final _Translations$settings$radio$snapLongMove$fr snapLongMove = _Translations$settings$radio$snapLongMove$fr._(_root);
	@override late final _Translations$settings$radio$snapMinMove$fr snapMinMove = _Translations$settings$radio$snapMinMove$fr._(_root);
	@override late final _Translations$settings$radio$snapMinSpeed$fr snapMinSpeed = _Translations$settings$radio$snapMinSpeed$fr._(_root);
	@override late final _Translations$settings$radio$enterSends$fr enterSends = _Translations$settings$radio$enterSends$fr._(_root);
	@override late final _Translations$settings$radio$keyerSpeed$fr keyerSpeed = _Translations$settings$radio$keyerSpeed$fr._(_root);
	@override late final _Translations$settings$radio$cwMessages$fr cwMessages = _Translations$settings$radio$cwMessages$fr._(_root);
	@override late final _Translations$settings$radio$voiceMessages$fr voiceMessages = _Translations$settings$radio$voiceMessages$fr._(_root);
	@override late final _Translations$settings$radio$avoidZeroBeat$fr avoidZeroBeat = _Translations$settings$radio$avoidZeroBeat$fr._(_root);
	@override late final _Translations$settings$radio$zeroBeatRange$fr zeroBeatRange = _Translations$settings$radio$zeroBeatRange$fr._(_root);
}

// Path: settings.help
class _Translations$settings$help$fr extends Translations$settings$help$en {
	_Translations$settings$help$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Aide et ressources';
	@override String get description => 'Communauté et assistance';
	@override String get forums => 'Forums Ham2K';
	@override String get forumsDescription => 'Trouvez de l\'aide, donnez un avis, discutez d\'idées…';
	@override String get chat => 'Chat Ham2K';
	@override String get chatDescription => 'Le serveur Discord de notre communauté en ligne';
	@override String get youtube => 'Ham2K YouTube';
	@override String get youtubeDescription => 'Vidéos et diffusions en direct';
	@override String get instagram => 'Ham2K Instagram';
	@override String get instagramDescription => 'Parce qu\'on ne peut pas avoir trop de photos…';
	@override String get bluesky => 'Ham2K BlueSky';
	@override String get blueskyDescription => 'Suivez-nous pour des nouvelles et des mises à jour';
	@override String get contact => 'Contactez-nous';
	@override String get contactDescription => 'help@ham2k.com — mais essayez d\'abord les forums ou le chat !';
}

// Path: settings.exports
class _Translations$settings$exports$fr extends Translations$settings$exports$en {
	_Translations$settings$exports$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Exports';
}

// Path: settings.map
class _Translations$settings$map$fr extends Translations$settings$map$en {
	_Translations$settings$map$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Cartes';
	@override late final _Translations$settings$map$style$fr style = _Translations$settings$map$style$fr._(_root);
	@override late final _Translations$settings$map$styleOpts$fr styleOpts = _Translations$settings$map$styleOpts$fr._(_root);
}

// Path: settings.privacy
class _Translations$settings$privacy$fr extends Translations$settings$privacy$en {
	_Translations$settings$privacy$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Confidentialité';
	@override late final _Translations$settings$privacy$shareAppData$fr shareAppData = _Translations$settings$privacy$shareAppData$fr._(_root);
	@override late final _Translations$settings$privacy$shareOpData$fr shareOpData = _Translations$settings$privacy$shareOpData$fr._(_root);
	@override String get privacyPolicy => 'Politique de confidentialité';
	@override String get termsOfService => 'Conditions d\'utilisation';
}

// Path: settings.sync
class _Translations$settings$sync$fr extends Translations$settings$sync$en {
	_Translations$settings$sync$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Synchronisation cloud';
	@override String get moreSettings => 'Plus de paramètres de synchronisation';
	@override String get enable => 'Activer la synchronisation';
	@override String get deviceKey => 'Clé de l\'appareil';
}

// Path: settings.peers
class _Translations$settings$peers$fr extends Translations$settings$peers$en {
	_Translations$settings$peers$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Appareils pairs';
	@override String get enable => 'Se connecter à d\'autres appareils';
	@override String get enableDescription => 'Permettre de partager les opérations, la saisie, le CAT et le GPS avec d\'autres appareils sur le réseau local';
	@override String get bleEnable => 'Se connecter en Bluetooth';
	@override String get bleDescription => 'Utiliser le Bluetooth LE pour se connecter même sans réseau local';
	@override String get thisDevice => 'Cet appareil';
	@override String get deviceName => 'Nom';
	@override String get deviceNameHint => 'Comment cet appareil apparaît aux autres appareils';
	@override String get pairedDevices => 'Appareils liés';
	@override String get noPairedDevices => 'Aucun appareil lié pour l\'instant. Activez cette option sur un autre appareil de ce réseau pour les lier.';
	@override String deviceListProblem({required Object error}) => 'Impossible de lire vos appareils liés : ${error}';
	@override String get nearby => 'À proximité';
	@override String get connected => 'Connecté';
	@override String get viaBluetooth => 'via Bluetooth';
	@override String get connecting => 'Connexion…';
	@override String get syncing => 'Synchronisation…';
	@override String get waitingForThem => 'En attente de l\'autre appareil';
	@override String get notConnected => 'Non connecté';
	@override String get wantsToPair => 'veut partager cette opération';
	@override String get allow => 'Autoriser';
	@override String get link => 'Lier';
	@override String get reject => 'Refuser';
	@override String get forget => 'Oublier';
	@override String forgetTitle({required Object name}) => 'Oublier ${name} ?';
	@override String get forgetBody => 'Il cessera de se synchroniser avec cet appareil. Vous pourrez l\'autoriser à nouveau plus tard, et les contacts déjà saisis sont conservés.';
	@override String pairTitle({required Object name}) => 'Lier avec ${name}';
	@override String get pairBody => 'Cet appareil est sur votre réseau local et veut se connecter.';
	@override String get pairBodyBle => 'Cet appareil est à proximité et veut se connecter en Bluetooth LE.';
	@override String get pairIdLabel => 'ID de l\'appareil';
	@override String get pairWarning => 'Ne liez que des appareils que vous reconnaissez. N\'importe quel appareil de ce réseau peut envoyer une demande.';
	@override String get pairWarningBle => 'Ne liez que des appareils que vous reconnaissez. N\'importe quel appareil à proximité peut envoyer une demande.';
	@override String problem({required Object error}) => 'Impossible d\'accéder au réseau local : ${error}';
	@override String bleProblem({required Object error}) => 'Bluetooth : ${error}';
	@override String statusConnected({required Object device}) => 'Connecté à ${device}';
	@override String statusLost({required Object device}) => 'Connexion perdue avec ${device}';
	@override String statusPerma({required Object connected, required Object linked}) => 'Appareils pairs : ${connected} sur ${linked} connectés';
	@override String get screenEnable => 'Partager les écrans et fenêtres';
	@override String get screenDescription => 'Permettre à d\'autres appareils d\'afficher des écrans ou des fenêtres de cet ordinateur';
	@override String get screenSources => 'Écrans et fenêtres';
	@override String get screenRefresh => 'Actualiser la liste';
	@override String get screenUnsupportedPlatform => 'Cet appareil ne peut pas partager son écran. macOS le peut ; tout appareil peut afficher un écran partagé par un autre.';
	@override String get screenUnsupportedVersion => 'Le partage d\'écran nécessite macOS 12.3 ou ultérieur. Cet appareil peut tout de même afficher un écran partagé par un autre.';
	@override String get screenNeedsPermission => 'macOS a besoin de votre autorisation pour enregistrer l\'écran avant que cette application puisse en partager un.';
	@override String get screenGrantPermission => 'Demander l\'autorisation';
	@override String get screenRelaunchAfterGranting => 'Autorisez-la dans Réglages Système, sous Confidentialité et sécurité → Enregistrement de l\'écran, puis quittez et rouvrez cette application — macOS ne signale le changement à une application qu\'à son prochain lancement.';
	@override String screenProblem({required Object error}) => 'Partage d\'écran : ${error}';
	@override String get screenChooseTitle => 'Choisir ce qu\'il faut partager';
	@override String get screenChooseButton => 'Choisir ce qu\'il faut partager…';
	@override String get screenTabScreens => 'Écrans';
	@override String get screenTabApps => 'Applications';
	@override String get screenTabWindows => 'Fenêtres';
	@override String get screenTabEmpty => 'Rien de ce type n\'a été trouvé.';
	@override String get screenSharedSummaryNone => 'Rien de choisi pour l\'instant.';
	@override String get screenThisDevice => 'Cet appareil';
	@override String screenSharedTo({required Object devices}) => 'Affiché sur ${devices}';
	@override String get screenSharedToNobody => 'Non affiché';
	@override String screenStopSharing({required Object name}) => 'Arrêter de partager ${name}';
}

// Path: settings.syncPanel
class _Translations$settings$syncPanel$fr extends Translations$settings$syncPanel$en {
	_Translations$settings$syncPanel$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get configuration => 'Configuration de la synchronisation';
	@override String get enableTitle => 'Synchroniser avec Ham2K Log Filer';
	@override String get enabledDescription => 'Sauvegarde et synchronisation de votre journal entre vos appareils';
	@override String get disabledDescription => 'Désactivé — les données restent uniquement sur cet appareil';
	@override String get syncing => 'Synchronisation';
	@override String get account => 'Compte';
	@override String get refresh => 'Rafraîchir';
	@override String get switchAccounts => 'Changer de compte';
	@override String get switchAccountsDescription => 'Lier cet appareil à un autre compte avec un code QR ou un e-mail';
	@override String get connectionRequests => 'Demandes de connexion';
	@override String connectionRequestsDescription({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Un appareil attend de rejoindre ce compte',
		other: '${n} appareils attendent de rejoindre ce compte',
	);
	@override String get accountEmailTitle => 'E-mail du compte';
	@override String accountEmailSent({required Object email}) => 'Confirmation envoyée à ${email}. Ouvrez le lien reçu pour terminer la modification.';
	@override String get resendConfirmation => 'Renvoyer l\'e-mail de confirmation';
	@override String resendConfirmationDescription({required Object email}) => 'En attente de ${email}';
	@override String accountEmailResent({required Object email}) => 'Renvoyé à ${email}.';
	@override String get deviceLinked => 'Cet appareil est maintenant lié à ce compte.';
	@override String get checking => 'Vérification…';
	@override String get notLinked => 'Pas encore lié';
	@override String linkedAccount({required Object account, required Object id}) => '${account} (#${id})';
	@override String get replaceDialogTitle => 'Remplacer les données locales ?';
	@override String countOperations({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${n} opération',
		other: '${n} opérations',
	);
	@override String countQsos({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${n} QSO',
		other: '${n} QSOs',
	);
	@override String get counts => 'Données synchronisées';
	@override String countsLocal({required Object qsos, required Object operations}) => 'Cet appareil : ${qsos} · ${operations}';
	@override String countsPending({required Object items}) => 'En attente d\'envoi : ${items}';
	@override String countsServer({required Object qsos, required Object operations}) => 'Serveur : ${qsos} · ${operations}';
	@override String get countsLocalChecking => 'Cet appareil : vérification…';
	@override String get countsServerChecking => 'Serveur : vérification…';
	@override String get countsServerUnavailable => 'Serveur : indisponible';
	@override String replaceDialogBody({required Object operations, required Object qsos}) => 'Cela sauvegarde puis efface ${operations} et ${qsos} de cet appareil, puis télécharge à la place les données du compte. La sauvegarde reste dans la base de données de cet appareil.';
	@override String get replace => 'Remplacer';
	@override String get pendingBannerTitle => 'Nouveau compte Ham2K Log Filer détecté';
	@override String get pendingBannerBody => 'Conservez les opérations et QSOs existants de cet appareil et fusionnez-les dans le compte, ou remplacez-les par les données du compte (une sauvegarde reste sur cet appareil dans les deux cas).';
	@override String get combine => 'Fusionner';
	@override String get authIssueTitle => 'La synchronisation ne peut pas se connecter';
	@override String get authIssueText => 'Ham2K Log Filer refuse toujours cet appareil. Vérifiez votre indicatif dans les paramètres de synchronisation.';
	@override String get openSettings => 'Ouvrir les paramètres de synchronisation';
}

// Path: settings.accounts
class _Translations$settings$accounts$fr extends Translations$settings$accounts$en {
	_Translations$settings$accounts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Comptes, services et sources de données';
	@override String get none => 'Aucune extension active avec un compte';
	@override String get notConfigured => 'Non configuré';
	@override String get connected => 'Connecté';
	@override String get cancelLogin => 'Annuler la connexion';
	@override String get openInBrowser => 'Ouvrir dans le navigateur';
	@override String loggedInAs({required Object identity}) => 'Connecté en tant que ${identity}';
	@override String get pressSaveToKeep => 'Appuyez sur Enregistrer pour garder ce compte connecté.';
	@override String connectedTo({required Object label}) => 'Connecté à ${label}';
	@override String get connect => 'Connecter';
	@override String get disconnect => 'Déconnecter';
	@override String get connectedAs => 'Connecté en tant que';
	@override String get test => 'Tester';
	@override String saveFailed({required Object error}) => 'Échec de l\'enregistrement : ${error}';
	@override String loginFailed({required Object error}) => 'Échec de la connexion : ${error}';
	@override String get lookupFailed => 'Les comptes sont indisponibles pour le moment — réessayez dans un instant';
	@override String get browserLoginTitle => 'Terminez la connexion dans votre navigateur web';
	@override String browserLoginSteps({required Object prefix}) => 'Une fois terminé, le navigateur tentera d\'ouvrir un lien commençant par "${prefix}". Votre ordinateur n\'a très probablement rien pour l\'ouvrir : copiez donc ce lien (depuis la barre d\'adresse, ou depuis la page d\'erreur affichée par le navigateur) et collez-le ici.';
	@override String browserLoginNotOpened({required Object prefix}) => 'Ham2K Logger n\'a pas pu ouvrir votre navigateur. Copiez le lien de connexion ci-dessous et ouvrez-le vous-même, puis copiez le lien vers lequel il vous redirige (il commence par "${prefix}") et collez-le ici.';
	@override String get copyLoginLink => 'Copier le lien de connexion';
	@override String get pastedLinkLabel => 'Collez le lien ici';
	@override String get finishLogin => 'Terminer la connexion';
	@override String pastedLinkNotARedirect({required Object prefix}) => 'Ce n\'est pas le lien de connexion — il doit commencer par "${prefix}".';
	@override String get pastedLinkWrongLogin => 'Ce lien appartient à une autre tentative de connexion. Fermez cette page et connectez-vous à nouveau.';
	@override String get pastedLinkNoCode => 'Ce lien ne contient pas de code de connexion. Terminez d\'abord la connexion, puis copiez le lien vers lequel elle vous redirige.';
	@override String get pastedLinkMalformed => 'Ce lien semble tronqué. Copiez-le en entier et collez-le à nouveau.';
	@override String get relayLoginWaiting => 'En attente de la fin de votre connexion — la suite se fera automatiquement.';
	@override String get loginNoResponse => 'Cet appareil n\'a pas encore reçu de réponse de la connexion. Si vous l\'avez déjà terminée dans votre navigateur, annulez et essayez de vous connecter à nouveau.';
	@override String get relayLoginNotOpened => 'Ham2K Logger n\'a pas pu ouvrir votre navigateur automatiquement. Utilisez le bouton ci-dessous pour ouvrir vous-même la page de connexion.';
	@override String get relayLoginUnavailable => 'Impossible de joindre le serveur de synchronisation nécessaire pour terminer cette connexion. Vérifiez votre connexion et réessayez.';
	@override String get loginIncompleteResponse => 'Cette tentative de connexion n\'a pas abouti correctement. Essayez de vous connecter à nouveau.';
	@override String get noKeyringTitle => 'Les identifiants de compte ne peuvent pas être enregistrés';
	@override String get noKeyringText => 'Ham2K Logger ne peut pas joindre de service de trousseau de clés sur cet ordinateur : les identifiants de compte ne peuvent être ni stockés ni lus — la connexion d\'un compte échouera tant que ce n\'est pas réglé. Installez et démarrez **gnome-keyring**, **KWallet** ou **KeePassXC**, ou déverrouillez le trousseau que vous avez déjà, puis redémarrez. La saisie, les exports et les fichiers de données ne sont pas affectés ; la synchronisation du journal reste désactivée en attendant.';
	@override String get noKeyringInline => 'Les identifiants ne peuvent pas être enregistrés : le trousseau de clés de cet ordinateur est injoignable. Installez et démarrez gnome-keyring, KWallet ou KeePassXC, ou déverrouillez celui que vous avez.';
	@override String get noSecureStorageInline => 'Les identifiants ne peuvent pas être enregistrés : le stockage sécurisé de cet ordinateur est injoignable.';
}

// Path: settings.station
class _Translations$settings$station$fr extends Translations$settings$station$en {
	_Translations$settings$station$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Configuration de la station et contrôle CAT';
	@override String get none => 'Aucun équipement configuré';
	@override String get add => 'Ajouter';
	@override String get addTitle => 'Ajouter un équipement';
	@override String get searchHint => 'Rechercher un équipement';
	@override String get noMatches => 'Aucun équipement ne correspond';
	@override String get detectedEquipment => 'Équipements détectés';
	@override String discoveryUnavailable({required Object error}) => 'Impossible d\'écouter les radios : ${error}';
	@override String get edit => 'Modifier l\'équipement';
	@override String get name => 'Nom';
	@override String get nameDescription => 'Comment vous l\'appelez — « Radio de gauche ». Facultatif.';
	@override String get transport => 'Connexion';
	@override String get host => 'Adresse';
	@override String get hostDescription => 'Le nom d\'hôte ou l\'adresse IP de la radio sur votre réseau.';
	@override String get port => 'Port';
	@override String get hostRequired => 'Une adresse est requise';
	@override String get portInvalid => 'Le port doit être compris entre 1 et 65535';
	@override String get connect => 'Connecter';
	@override String get disconnect => 'Déconnecter';
	@override String get remove => 'Retirer';
	@override String removeTitle({required Object name}) => 'Retirer ${name} ?';
	@override String get removeMessage => 'Cela le retire seulement de l\'application. Les réglages de l\'équipement restent inchangés.';
	@override String unknownType({required Object typeKey}) => 'Type d\'équipement non reconnu « ${typeKey} »';
	@override String get report => 'Signaler';
	@override String get reportTitle => 'Signaler cette radio';
	@override String get reportIntro => 'Dites-nous quelle radio c\'est vraiment et comment ça s\'est passé. Votre signalement devient une fiche lue par l\'équipe Ham2K, et ce que vous écrivez pour la faire fonctionner pourra aider le prochain opérateur avec le même poste.';
	@override String get reportManufacturer => 'Fabricant';
	@override String get reportManufacturerDescription => 'Qui la fabrique — Icom, Yaesu, Kenwood, Elecraft…';
	@override String get reportManufacturerRequired => 'Un fabricant est requis';
	@override String get reportModel => 'Modèle';
	@override String get reportModelDescription => 'Le modèle, tel que la radio elle-même le nomme — « IC-7300 », « FT-991A ».';
	@override String get reportModelRequired => 'Un modèle est requis';
	@override String get reportOutcome => 'Comment ça s\'est passé ?';
	@override String get reportOutcomeWorks => 'A bien fonctionné';
	@override String get reportOutcomeIssues => 'A fonctionné, avec des problèmes';
	@override String get reportOutcomeFails => 'N\'a pas fonctionné du tout';
	@override String get reportOutcomeRequired => 'Dites-nous comment ça s\'est passé';
	@override String get reportComments => 'Commentaires';
	@override String get reportCommentsPlaceholder => 'Ce qui a marché, ce qui n\'a pas marché, ce qui vous a surpris.';
	@override String get reportHints => 'Conseils de dépannage';
	@override String get reportHintsPlaceholder => 'Voulez-vous suggérer des conseils de dépannage pour d\'autres utilisateurs ?';
	@override String get reportSend => 'Envoyer le signalement';
	@override String get reportSending => 'Envoi de votre signalement…';
	@override String reportSent({required Object ref}) => 'Merci — votre signalement a été enregistré sous ${ref}.';
	@override String get reportSentNoRef => 'Merci — votre signalement a été envoyé.';
	@override String reportFailed({required Object error}) => 'Le signalement n\'a pas été envoyé : ${error}';
	@override String get troubleshootingNotes => 'Notes de dépannage';
	@override String get mainVfo => 'VFO principal';
	@override String get useAsMainVfo => 'Utiliser comme VFO principal';
	@override String get serialPort => 'Port série';
	@override String get serialPortDescription => 'Le port sur lequel apparaît l\'interface CAT de la radio.';
	@override String get serialPortNone => 'Aucun port série trouvé';
	@override String get serialPortRequired => 'Choisissez un port série';
	@override String serialPortOrdinal({required Object n, required Object total}) => 'port ${n} sur ${total}';
	@override String get serialPortSuggested => 'suggéré';
	@override String get serialPortJustNow => 'Connecté récemment';
	@override String get serialDeviceRequest => 'Ajouter un périphérique USB…';
	@override String get baudRate => 'Vitesse (bauds)';
	@override String get baudRateDescription => 'Doit correspondre au menu CAT de la radio. En cas de différence, la radio renvoie des données incohérentes sans aucune erreur.';
	@override String get serialRtsHigh => 'Maintenir RTS haut';
	@override String get serialRtsHighDescription => 'Uniquement pour une radio qui attend RTS avant de répondre, comme une Yaesu avec CAT RTS activé. Sur un Digirig, un SignaLink et la plupart des câbles faits maison, RTS est le PTT, et le maintenir haut passe en émission.';
	@override String get serialDtrHigh => 'Maintenir DTR haut';
	@override String get serialDtrHighDescription => 'Uniquement pour une interface CAT alimentée par DTR, comme certains câbles RS-232 pour le FT-817. Sur beaucoup de câbles, DTR manipule la CW ou le PTT, et le maintenir haut passe en émission.';
	@override String get civAddress => 'Adresse CI-V de la radio';
	@override String get civAddressDescription => 'En hexadécimal, comme affiché dans le menu CI-V de la radio. L\'IC-705 est livré avec A4.';
	@override String get civAddressInvalid => 'Une adresse CI-V comporte deux chiffres hexadécimaux, de 01 à FF';
	@override String get flexSlice => 'Slice';
	@override String get flexSliceDescription => 'Quelle slice de la radio cette connexion lit et accorde.';
	@override String flexSliceLabel({required Object letter}) => 'Slice ${letter}';
	@override String get flexSliceInvalid => 'Choisissez l\'une des slices de la radio, de A à H';
	@override String flexSliceMissing({required Object letter}) => 'La slice ${letter} n\'est pas utilisée sur cette radio — choisissez une autre slice, ou créez-la dans SmartSDR';
	@override String get channelNotInUse => 'non utilisée';
	@override String get channelHeldByUnknown => 'utilisée par un autre programme';
	@override String get flexNoSlices => 'Cette radio n\'a signalé aucune slice — vérifiez que SmartSDR est lancé et que ce client peut s\'abonner';
	@override String get spectrumUnsupported => 'Cette radio n\'envoie pas de spectre via CAT';
	@override String get spectrumRequiresBaud => 'Nécessite le CAT à 115200 bps';
	@override String get spectrumNoRadio => 'Aucune radio connectée';
	@override String get spectrumWaiting => 'En attente du spectre de la radio…';
	@override String get spectrumUnavailable => 'L\'affichage du spectre n\'est pas disponible';
	@override String get spectrumNoDaxChannel => 'Tous les canaux DAX IQ de cette radio sont utilisés';
	@override String get spectrumNoPanadapter => 'Cette slice n\'a pas de panadapter sur la radio';
	@override String spectrumStreamRefused({required Object code}) => 'La radio a refusé un flux DAX IQ (erreur ${code})';
	@override String get spectrumNoUdp => 'Les données de spectre de la radio ne parviennent pas à cet appareil';
	@override String get spectrumScopeRefused => 'La radio a refusé ses commandes de scope';
	@override String get spectrumOutOfRange => 'Le scope de la radio est réglé hors de la plage qu\'il peut afficher';
	@override String get n3fjpNoRig => 'N3FJP n\'a pas d\'interface radio configurée : ceci suit donc ce qui est tapé dans N3FJP, pas une radio';
	@override String get winkeyerKeyPort => 'Sortie de manipulation';
	@override String get winkeyerKeyPortDescription => 'Laquelle des deux prises de sortie du manipulateur est reliée à votre radio.';
	@override String winkeyerKeyPortLabel({required Object n}) => 'Port ${n}';
	@override String get winkeyerPtt => 'Utiliser le PTT du manipulateur';
	@override String get winkeyerPttDescription => 'Active la ligne PTT sur la même prise, pour un amplificateur ou une radio qui en a besoin. Laissez désactivé pour une radio manipulée par sa prise de manipulateur.';
	@override String get winkeyerNoAnswer => 'Aucun WinKeyer n\'a répondu sur ce port';
	@override String get winkeyerStoppedAnswering => 'Le WinKeyer a cessé de répondre pendant l\'envoi ; le message a été abandonné';
	@override String get radioUser => 'Nom d\'utilisateur de la radio';
	@override String get radioPass => 'Mot de passe de la radio';
	@override String get radioLoginDescription => 'L\'identifiant Réseau → Remote de la radio, pas votre mot de passe WiFi.';
	@override String get radioUserRequired => 'Le nom d\'utilisateur de contrôle à distance de la radio est requis';
	@override String get connectFailedBusy => 'Le périphérique est occupé';
	@override String get connectFailedDenied => 'Accès refusé';
	@override String get connectFailedDevice => 'Périphérique introuvable';
	@override String get connectFailedLines => 'RTS/DTR n\'ont pas pu être maintenus comme réglé, le port a donc été fermé. Un autre programme a peut-être laissé le contrôle de flux matériel activé — débranchez et rebranchez le câble.';
	@override String get connectFailedNetwork => 'Impossible de trouver la radio sur le réseau. Vérifiez son adresse, et qu\'elle est allumée et joignable.';
	@override String get connectFailedTimeout => 'La radio n\'a pas répondu à temps. Vérifiez qu\'elle est allumée et joignable.';
	@override late final _Translations$settings$station$models$fr models = _Translations$settings$station$models$fr._(_root);
	@override late final _Translations$settings$station$transports$fr transports = _Translations$settings$station$transports$fr._(_root);
	@override String get troubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get ft891Troubleshooting => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **CAT RTS doit être sur OFF sur la radio** (menu **05-08** du FT-891). S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse. Sur un Digirig, un SignaLink ou la plupart des câbles faits maison, cette même ligne est le PTT : la lever passerait votre émetteur en émission. Sur le port USB de la radio elle-même, **Maintenir RTS haut** dans Paramètres avancés est l\'alternative.\n- **La vitesse doit correspondre** au CAT RATE de la radio (menu **05-06**). En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.';
	@override String get yaesuBinaryTroubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get yaesuBinaryTroubleshooting => 'Cette radio utilise l\'ancien CAT Yaesu à cinq octets, et elle ne répond pas du tout quand quelque chose cloche. C\'est presque toujours l\'une de ces causes :\n\n- **Le câble doit convertir les niveaux.** La prise CAT à l\'arrière n\'est ni du RS-232 ni de l\'USB ; elle nécessite un CT-62 ou un adaptateur équivalent. Un simple câble audio ou données ne fonctionnera pas pour le CAT.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio (**#14** sur un FT-817, **#19** sur un FT-857 ou FT-897). En cas de différence, la radio ne renvoie rien, et jamais d\'erreur.\n- **Ne laissez jamais rien lever RTS ou DTR sur ce port.** Sur la plupart des câbles pour ces radios, ces lignes sont le PTT et la manipulation. Une ancienne interface alimentée par DTR fait exception : activez **Maintenir DTR haut** dans Paramètres avancés pour celle-ci.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\nCe pilote a été écrit d\'après le tableau CAT publié par Yaesu et n\'a jamais été testé sur l\'une de ces radios. S\'il fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get guohetecTroubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get guohetecTroubleshooting => 'Le Q900 a deux protocoles CAT, et cette entrée utilise son protocole natif plutôt que l\'imitation du FT-817. Choisissez ici **Guohetec Q900**, pas un FT-817 — l\'imitation prend en charge moins de commandes, et la radio n\'indique pas lequel elle utilise.\n\n- **Le câble USB-C est la liaison CAT**, et il connecte aussi la carte son. La vitesse n\'a pas d\'importance sur ce câble ; le port ignore la valeur réglée.\n- **Ne laissez jamais rien lever RTS ou DTR sur ce port.** Sur un câble série, ces lignes sont le PTT et la manipulation.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Une radio de deuxième génération se comporte différemment** de la première. Appui long sur Menu, puis About : HW 2.0 correspond à la deuxième génération.\n\nCe pilote a été écrit d\'après le protocole publié par le fabricant et n\'a jamais été testé sur l\'une de ces radios. S\'il fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get yaesuTroubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get yaesuTroubleshooting => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse. Sur un Digirig, un SignaLink ou la plupart des câbles faits maison, cette même ligne est le PTT : la lever passerait votre émetteur en émission. Sur le port USB de la radio elle-même, **Maintenir RTS haut** dans Paramètres avancés est l\'alternative. L\'emplacement de ce réglage varie selon le modèle (menu **05-08** sur un FT-891).\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Les modes suivent la table du FT-891.** La plupart des Yaesu y correspondent, mais une radio qui numérote ses modes différemment affichera et réglera le mauvais mode pour ceux-là. La fréquence n\'est pas concernée.';
	@override String get yaesuRs232Troubleshooting => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **La prise CAT est en RS-232.** Elle nécessite un adaptateur USB-série et un câble DB-9 droit — un câble null-modem croise les lignes, et la radio ne reçoit rien.\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse, sauf si **Maintenir RTS haut** est activé dans Paramètres avancés.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\nCette entrée a été écrite d\'après la documentation CAT publiée et n\'a jamais été testée sur l\'une de ces radios. Si elle fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get yaesuUsbTroubleshooting => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **Utilisez le premier des deux ports USB de la radio.** Le CAT est normalement sur le premier (le port COM **Enhanced** sous Windows) ; le second (**Standard**) sert au PTT et à la manipulation. Le sélecteur pointe sur le premier chaque fois qu\'il peut distinguer les deux.\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse, sauf si **Maintenir RTS haut** est activé dans Paramètres avancés.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.';
	@override String get k4SerialNotes => 'Branchez la prise USB-B arrière (PC) du K4. USB-PC1 ou USB-PC2 conviennent pour le CAT ; choisissez un port libre et faites correspondre son réglage Serial USB-PCn: Baud Rate sur la radio. HaLo préremplit 38400 ; modifiez-le si nécessaire. Une autre application doit utiliser l\'autre port ou l\'Ethernet.\n\nCette connexion pilote la radio et ses manipulateurs ; elle n\'envoie pas d\'audio à HaLo.';
	@override String get k4TcpNotes => 'Reliez la prise Ethernet du K4 à votre réseau local. Saisissez son nom d\'hôte ou son adresse IP et le port CAT 9200. Il s\'agit du contrôle CAT, pas de la connexion audio distante séparée sur le port 9204.\n\nHaLo pilote la radio et ses manipulateurs sans recevoir d\'audio ni de données de panadapter.';
	@override String get k4PowerTimeout => 'La puissance du K4 n\'a pas été modifiée car la radio n\'a pas confirmé sa plage de sortie. Réessayez.';
	@override String get k4PowerRange => 'La puissance du K4 doit être de 0,1 à 110 W, ou de 0,0001 à 0,01 W quand la sortie milliwatt du transverter est active.';
	@override String get elecraftTroubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get elecraftTroubleshooting => 'Les postes Elecraft parlent le CAT Kenwood, et un KX2 comme un KX3 ont été utilisés ainsi — VFO dans les deux sens, changement de mode et battement nul CW fonctionnent.\n\nSi la radio ne répond pas, c\'est presque toujours l\'une de ces causes :\n\n- **La vitesse doit correspondre** à celle réglée sous **RS232** dans le menu de la radio. Ces radios sont livrées à 38400. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\n**Si la fréquence est correcte mais pas le mode**, dites-le-nous. Les entrées KX2 et KX3 lisent le mode à une position de la réponse d\'état de la radio que nous avons déterminée sur les postes que nous avons vus, et seul un signalement peut nous apprendre qu\'un firmware le place ailleurs.\n\nLe K3 n\'a fait l\'objet d\'aucun retour, alors dites-nous ce qui se passe si vous en utilisez un. Le K4 a sa propre entrée.';
	@override String get kenwoodTroubleshootingTitle => 'Si la radio se connecte mais n\'affiche aucune fréquence';
	@override String get kenwoodTroubleshooting => 'Ce pilote a fait ses preuves sur les TS-590SG et TS-480 de Kenwood, les QMX et QCX-mini de QRP Labs, et les KX2 et KX3 d\'Elecraft. Le reste de la gamme est écrit d\'après les références CAT publiées : signalez-nous ce qui se passe, dans un sens comme dans l\'autre.\n\nSi la radio ne répond pas, c\'est presque toujours l\'une de ces causes :\n\n- **La vitesse doit correspondre** au menu CAT de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Certains postes nécessitent d\'activer le CAT** dans le menu avant de répondre.\n\n**Plusieurs interfaces SDR parlent ce même protocole** : cette entrée vaut donc la peine d\'être essayée pour elles aussi ; les postes Elecraft sont listés séparément, sous Elecraft. Si la fréquence est correcte mais que le mode est faux ou absent, c\'est la seule partie qui varie selon les modèles — l\'application le déduit de la radio et, à défaut, le demande directement, donc le mode peut simplement arriver avec un peu de retard.';
	@override String get statusConnected => 'Connecté';
	@override String get statusLost => 'Déconnecté';
	@override String get notConfigured => 'Non configuré';
	@override String get currentConfiguration => 'Configuration actuelle';
	@override String get currentTransceiver => 'Transceiver actuel';
	@override String get radioMode => 'Mode de la radio';
	@override String get keyerNotSupported => 'Non pris en charge par la radio actuelle';
	@override String get catControlPreferences => 'Préférences du contrôle CAT';
	@override String get chooseTransceiver => 'Choisir le transceiver';
	@override String get configurationSection => 'Configuration';
	@override String get noTransceiverSelected => 'Aucun transceiver sélectionné';
	@override String makeMainVfo({required Object name}) => 'Utiliser ${name} pour le VFO principal';
	@override String sectionTransceivers({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		zero: 'Aucun transceiver',
		one: '${count} transceiver',
		other: '${count} transceivers',
	);
	@override String sectionAntennas({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} antenne',
		other: '${count} antennes',
	);
	@override String sectionOtherEquipment({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} autre équipement',
		other: '${count} autres équipements',
	);
	@override String get equipmentInventory => 'Inventaire des équipements';
	@override String get equipmentInUse => 'Contrôles du transceiver';
	@override String get noTransceiver => 'Aucun';
	@override String get peerRadioNotAvailable => 'Non disponible';
	@override String peerRadioOnDevice({required Object device}) => 'Sur ${device}';
	@override String peerRadioElsewhereTitle({required Object radio}) => '${radio} est sur un autre appareil';
	@override String peerRadioElsewhereMessage({required Object device}) => 'Cette radio est connectée à ${device}. Sa connexion et ses réglages se configurent sur cet appareil.';
	@override String get antennaInUse => 'Antenne utilisée';
	@override String get keyInUse => 'Manipulateur utilisé';
	@override String get noneSelected => 'Aucun';
	@override String get moreSettings => 'Plus de paramètres';
	@override String get icomCivTroubleshootingTitle => 'Si deux ports série apparaissent pour la même radio';
	@override String get icomCivTroubleshooting => 'Plusieurs radios Icom, dont l\'IC-705, présentent **deux** ports série USB à la fois (Icom les appelle Port A et Port B), tous deux réglés en CI-V par défaut. Ni cette application ni votre système ne peuvent les distinguer au-delà de cela : le même identifiant fabricant/produit USB apparaît simplement deux fois, parfois marqué ici d\'un suffixe `#2`. **Le Port A est généralement le bon** — normalement le premier listé par votre système ou votre navigateur, et quand cette application peut distinguer les deux ports, elle le marque comme suggéré. Si les commandes partent et que la radio ne répond jamais, essayez l\'autre port.';
	@override String get civAddressTroubleshootingTitle => 'Si la radio ne répond jamais';
	@override String get civAddressTroubleshooting => '- **L\'adresse CI-V doit correspondre** au menu de la radio. Cette entrée préremplit l\'adresse d\'origine du modèle, mais c\'est justement sur un poste partageant un bus CI-V qu\'elle est modifiée. Une trame envoyée à la mauvaise adresse est ignorée en silence, exactement comme avec un câble défectueux.\n- **La vitesse doit correspondre** au CI-V BAUD RATE de la radio (en USB, CI-V USB Baud Rate). Réglez la radio sur la même valeur que celle affichée ici, **pas sur Auto**. En Auto, certaines radios, dont l\'IC-7300, se connectent puis cessent de répondre au bout d\'une minute environ.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.';
	@override String get ic7300Mk2Note => '\n- L\'**IC-7300 MK2** est livré avec l\'adresse `B6`, et non `94` préremplie ici — choisissez plutôt l\'entrée IC-7300 MK2.';
	@override String get ic705PortNote => '\n- L\'**IC-705** présente deux ports série USB, tous deux nommés d\'après la radio. Le CI-V est sur le **premier**, vers lequel pointe le sélecteur chaque fois qu\'il peut distinguer les deux.';
	@override String get ic7760PortNote => '\n- L\'**IC-7760** utilise le CI-V sur le **Port A** des deux ports série USB qu\'il présente.';
	@override String get x6100PortNote => '\n- Le **X6100** utilise le CI-V sur son port **DEV** — le second des deux ports série qu\'il présente, et celui vers lequel pointe le sélecteur.';
	@override String get rigctldTroubleshootingTitle => 'Si l\'application ne peut pas se connecter';
	@override String get rigctldTroubleshooting => 'Ceci se connecte à un **démon rigctld que vous lancez vous-même**, pas directement à la radio — le backend de Hamlib dialogue avec la radio et prend en charge des centaines de modèles.\n\n- **Le démon doit déjà tourner**, par ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Trouvez le numéro de modèle de votre radio avec `rigctl -l`.\n- **Depuis une autre machine**, lancez-le avec `-T 0.0.0.0` : par défaut, rigctld n\'accepte que les connexions de la machine sur laquelle il tourne.\n- **Le port** est 4532 sauf si vous avez lancé le démon avec `-t`.\n- Une fois connecté, une fréquence absente signifie généralement que le démon lui-même ne joint pas la radio. Testez-le avec `rigctl -m 2 f` sur la machine du démon.';
	@override String get flrigTroubleshootingTitle => 'Si l\'application ne peut pas se connecter';
	@override String get flrigTroubleshooting => 'Ceci se connecte à un **programme flrig que vous lancez vous-même**, pas directement à la radio — flrig dialogue avec la radio et prend en charge la plupart des marques et modèles.\n\n- **flrig doit déjà tourner**, avec son transceiver configuré et connecté.\n- **Le port** est 12345 sauf si vous l\'avez changé dans la configuration de flrig (Config → Setup → Server).\n- **Depuis une autre machine**, assurez-vous que le serveur de flrig est joignable. Il écoute sur toutes les interfaces, mais votre pare-feu n\'est peut-être pas d\'accord.\n- Une fois connecté, une fréquence absente signifie généralement que flrig lui-même ne joint pas la radio. Vérifiez que l\'affichage de flrig suit le bouton de la radio.';
	@override String get hrdTroubleshootingTitle => 'Si l\'application ne peut pas se connecter';
	@override String get hrdTroubleshooting => 'Ceci se connecte au **Rig Control de Ham Radio Deluxe, qui tourne sur votre ordinateur**, pas directement à la radio — HRD dialogue avec la radio.\n\n- **Rig Control doit déjà tourner** et être connecté à la radio.\n- **Son serveur IP doit être activé.** Rig Control ne communique avec d\'autres programmes que par ce biais.\n- **Le port** est 7809 sauf si vous l\'avez changé dans les réglages du serveur IP.\n- **Depuis une autre machine**, assurez-vous que votre pare-feu laisse passer la connexion.\n\nCette entrée a été écrite d\'après les descriptions publiées du protocole de HRD et n\'a jamais été testée avec HRD. Si elle fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get n3fjpTroubleshootingTitle => 'Si l\'application ne peut pas se connecter';
	@override String get n3fjpTroubleshooting => 'Ceci se connecte à **un logiciel de journal N3FJP qui tourne sur votre ordinateur**, pas directement à la radio — N3FJP dialogue avec la radio.\n\n- **L\'API du programme doit être activée** : Settings → Application Program Interface, cochez **TCP API Enabled**.\n- **Le port** est 1100 sauf si vous l\'avez changé à cet endroit.\n- **N3FJP doit avoir une interface radio configurée** pour suivre ou accorder la radio. Sans elle, il ne rapporte que ce qui est tapé dans sa fenêtre de saisie.\n- N3FJP rapporte uniquement la bande, le mode et la fréquence : ni puissance, ni état d\'émission.\n\nCette entrée a été écrite d\'après l\'API publiée de N3FJP et n\'a jamais été testée avec N3FJP. Si elle fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get commanderTroubleshootingTitle => 'Si l\'application ne peut pas se connecter';
	@override String get commanderTroubleshooting => 'Ceci se connecte à **DXLab Commander, qui tourne sur votre ordinateur**, pas directement à la radio — Commander dialogue avec la radio.\n\n- **Commander doit déjà tourner** et être connecté à la radio.\n- **Son service réseau doit être activé** : le bouton **Net Serv** dans le panneau Radio de la fenêtre Configuration de Commander.\n- **Le port** est 52002, le troisième port du bloc commençant au **Base Port** de Net Serv (52000 sauf si vous l\'avez changé).\n- **Depuis une autre machine**, assurez-vous que votre pare-feu laisse passer la connexion.\n\nCette entrée a été écrite d\'après les messages TCP publiés de Commander et n\'a jamais été testée avec Commander. Si elle fonctionne à moitié, cela vaut la peine de le signaler.';
	@override String get ic705TroubleshootingTitle => 'Si la radio ne répond jamais';
	@override String get ic705Troubleshooting => 'La radio n\'a qu\'**une seule** session de contrôle à distance. Quand la connexion est ignorée, c\'est presque toujours qu\'autre chose l\'utilise.\n\n- **Fermez tout autre client.** wfview ou RS-BA1 connecté à la même radio occupe cette unique session, et la connexion d\'ici est simplement ignorée pendant ce temps.\n- **Vérifiez les réglages réseau de la radio.** Le WLAN doit être activé, la radio doit être sur le même réseau, et sa fonction de contrôle à distance (Network) doit être activée.\n- **Éteignez puis rallumez le WLAN de la radio** s\'il reste bloqué. Cela libère de façon fiable une session bloquée sur la radio.\n\nUn **mauvais mot de passe est refusé explicitement**, pas accueilli par le silence. Si vous êtes arrivé ici plutôt qu\'à un message « refusé », le mot de passe n\'est pas en cause.';
	@override String get statusStale => 'Ne répond pas';
	@override String get statusDisconnected => 'Non connecté';
	@override String get statusConnecting => 'Connexion…';
	@override String get statusDisconnecting => 'Déconnexion…';
	@override String get statusError => 'Échec de la connexion';
	@override String get currentRadioSettings => 'Réglages actuels de la radio';
	@override String get notSupportedByThisRadio => 'Non pris en charge par cette radio';
	@override String get keyerRowLabel => 'Manipulateur';
	@override String get cwMessagesButton => 'CW';
	@override String get voiceMessagesButton => 'Phonie';
	@override String voiceKeyerAvailable({required Object count}) => 'Messages vocaux : ${count} mémoires dans la radio';
	@override String get antennaBands => 'Bandes';
	@override String get antennaType => 'Type d\'antenne';
	@override String get antennaTypeRequired => 'Choisissez un type d\'antenne';
	@override late final _Translations$settings$station$antennaTypes$fr antennaTypes = _Translations$settings$station$antennaTypes$fr._(_root);
	@override String get keyType => 'Type de manipulateur';
	@override String get keyTypeRequired => 'Choisissez un type de manipulateur';
	@override late final _Translations$settings$station$keyTypes$fr keyTypes = _Translations$settings$station$keyTypes$fr._(_root);
	@override String get softwareIntermediaries => 'Logiciels intermédiaires';
	@override String get otherBrands => 'Autres marques';
	@override String get otherEquipment => 'Autres équipements (antennes, manipulateurs, etc.)';
	@override String get newAntenna => 'Nouvelle antenne';
	@override String get newKey => 'Nouveau manipulateur';
	@override String get newKeyer => 'WinKeyer (K1EL ou compatible)';
	@override String keyViaRadio({required Object radio}) => 'Manipulateur CAT dans ${radio}';
	@override String keyOnDevice({required Object device}) => 'Manipulateur sur ${device}';
	@override String get cwKeyerArea => 'Zone du manipulateur';
	@override String get trackStationInfo => 'Enregistrer les infos de station pour chaque QSO';
	@override String get includeStationInfoInAdif => 'Inclure dans les exports ADIF';
	@override String get whatToTrack => 'Quoi enregistrer ?';
	@override String get trackFieldRig => 'Transceiver';
	@override String get trackFieldPower => 'Puissance';
	@override String get watts => 'Watts';
	@override String get trackFieldAntenna => 'Antenne';
	@override String get trackFieldKey => 'Manipulateur CW';
	@override String get placeholderConnectDelay => 'Délai de connexion (ms)';
	@override String get placeholderConnectDelayDescription => 'Durée du handshake simulé. Vide ou 0 connecte instantanément.';
	@override String get placeholderDropAfter => 'Couper après (secondes)';
	@override String get placeholderDropAfterDescription => 'Ferme la connexion d\'elle-même, pour tester la reconnexion. Vide ou 0 ne coupe jamais.';
	@override String get placeholderFailConnect => 'Toujours échouer à la connexion';
	@override String get placeholderConnectFailure => 'La radio provisoire a reçu l\'ordre de refuser cette connexion';
	@override String get placeholderFreq => 'Fréquence (kHz)';
	@override String get placeholderFreqDescription => 'Fréquence de départ de la radio provisoire. Elle renvoie ensuite ce sur quoi l\'application l\'accorde.';
	@override String get placeholderMode => 'Mode';
	@override String get placeholderModeDescription => 'Le mode de départ de la radio provisoire, par ex. USB, CW, FT8.';
	@override String get placeholderPower => 'Puissance (watts)';
	@override String get placeholderPurpose => 'Utilisez cette radio pour garder trace du poste que vous utilisez, à des fins de journal';
	@override String get placeholderReplyDelay => 'Délai de réponse (ms)';
	@override String get placeholderReplyDelayDescription => 'Temps que met la radio provisoire à signaler un changement. Vide ou 0 répond immédiatement.';
	@override String get cwKeyerField => 'Manipulateur CW par CAT';
	@override String get cwKeyerFieldDescription => 'Indique si cette radio manipule la CW à partir de texte via CAT. Désactivé pour un poste que l\'application ne connaît pas.';
	@override String get voiceMemories => 'Mémoires vocales';
	@override String get voiceMemoriesDescription => 'Nombre de mémoires vocales que la radio joue via CAT. 0 pour aucune.';
	@override String get voiceMemoriesInvalid => 'Un nombre entier, 0 ou plus';
	@override String get yaesuMeterCapture => 'Capturer les mesures des indicateurs';
	@override String get yaesuBinaryMeterCaptureDescription => 'Lit l\'indicateur de puissance de sortie et le signal de ROS élevé de la radio pendant l\'émission, et écrit les valeurs brutes dans le log. Sert à établir l\'échelle que Yaesu ne publie pas — les valeurs ne sont pas affichées sous forme d\'indicateurs.';
	@override String get yaesuMeterCaptureDescription => 'Lit les indicateurs PO, SWR et ALC de la radio pendant l\'émission, et écrit les valeurs brutes dans le log. Sert à établir l\'échelle que Yaesu ne publie pas — les valeurs ne sont pas affichées sous forme d\'indicateurs.';
	@override String get telemetryInterval => 'Intervalle de lecture des indicateurs (ms)';
	@override String get telemetryIntervalDescription => 'Fréquence de lecture des indicateurs de la radio pendant l\'émission. Laissez vide pour le plus rapide que cette connexion supporte, jusqu\'à 200 ms.';
	@override String telemetryIntervalInvalid({required Object min, required Object max}) => 'Un nombre entier de millisecondes, de ${min} à ${max}';
	@override String get pollInterval => 'Intervalle d\'interrogation au repos (ms)';
	@override String pollIntervalDescription({required Object fallback}) => 'Fréquence à laquelle demander à la radio sa fréquence et son mode quand rien ne change. Laissez vide pour ${fallback} ms.';
	@override String pollIntervalInvalid({required Object min, required Object max}) => 'Un nombre entier de millisecondes, de ${min} à ${max}';
	@override String get advancedSettings => 'Paramètres avancés';
	@override String get placeholderSwr => 'Valeur de ROS';
	@override String get placeholderSwrDescription => 'Ce que cette radio indique sur son ROS-mètre pendant l\'émission. Au-dessus de 1,8 le panneau avertit.';
	@override String get placeholderSwrInvalid => 'Un nombre, 1 ou plus';
	@override String get keyerNone => 'Aucun';
	@override String get cwDialect => 'Dialecte de manipulation CW';
	@override String get cwDialectDescription => 'Quelle forme de la commande KY cette radio accepte. Aucun signifie pas de manipulation CW via CAT.';
	@override String get cwDialectKenwood => 'Kenwood (KY, complété à 24)';
	@override String get cwDialectElecraft => 'Elecraft (texte KY)';
	@override String get voiceDialect => 'Dialecte des messages vocaux';
	@override String get voiceDialectDescription => 'Comment cette radio joue ses mémoires vocales via CAT. Aucun signifie pas de mémoires vocales via CAT. Avec un dialecte et sans nombre, le nombre par défaut du dialecte s\'applique.';
	@override String get voiceDialectPb => 'Kenwood (PB, style TS-590)';
	@override String get voiceDialectK4 => 'Elecraft K4 (PB et DA)';
	@override String get voiceDialectKx => 'Elecraft KX2/KX3 (appuis de touches)';
	@override String get placeholderDiagnostic => 'Simulé';
	@override String get placeholderWholeNumberInvalid => 'Doit être un nombre entier, 0 ou plus';
	@override String get placeholderFreqInvalid => 'Doit être une fréquence en kHz, supérieure à zéro';
	@override String get placeholderModeInvalid => 'Doit être un nom de mode, par ex. USB, CW, FT8';
	@override String get switchLayout => 'Disposition';
	@override String get switchLayoutDescription => 'De quel côté du commutateur vos radios sont branchées.';
	@override String get switchLayoutRequired => 'Choisissez le câblage du commutateur';
	@override String switchCommandRefused({required Object command, required Object code}) => 'Le commutateur a refusé « ${command} » (erreur ${code})';
	@override String get switchBusyTransmitting => 'Ce port est en émission — antenne inchangée';
	@override String get switchNoAntenna => 'Aucune';
	@override String switchAntennaFor({required Object port}) => 'Antenne sur le port ${port}';
	@override String get switchAntennaForDescription => 'Laquelle de vos antennes est reliée à ce port du commutateur.';
	@override String switchLayoutSides({required Object antennas, required Object radios}) => '${antennas} antennes, ${radios} radios';
	@override String switchLayoutSidesOneRadio({required Object antennas}) => '${antennas} antennes, 1 radio';
	@override String switchLayoutSidesOneAntenna({required Object radios}) => '1 antenne, ${radios} radios';
	@override String get switchCommonPort => 'Commun';
	@override String get dcnAddress => 'Adresse du périphérique';
	@override String get dcnAddressDescription => 'L\'adresse réglée sur les interrupteurs DIP du module. Un module relais coaxial sort d\'usine à 2.';
	@override String get dcnAddressRequired => 'Doit être une adresse de périphérique de 1 à 99';
	@override String switchPortLabel({required Object port}) => 'Port ${port}';
	@override String get switchPortAutoHint => 'suit les données de bande';
	@override String get switchPortTransmittingHint => 'en émission — impossible de changer maintenant';
	@override String get switchCurrentStateHeader => 'État actuel';
	@override String get switchCurrentStateDescription => 'Sur quelle antenne se trouve chaque port radio en ce moment. Les changements prennent effet immédiatement.';
	@override String get switchWiringHeader => 'Câblage';
	@override String get switchPortInhibitedHint => 'émission bloquée';
	@override String get configUnreadable => 'Les réglages enregistrés de cette radio n\'ont pas pu être lus. Ouvrez ses paramètres et saisissez-les à nouveau, ou retirez-la et ajoutez-la de nouveau.';
	@override String get autoConnectHeld => 'HaLo a cessé de répondre la dernière fois qu\'il s\'est connecté à cette radio : il ne s\'est donc pas connecté de lui-même cette fois. Appuyez sur Connecter pour réessayer.';
}

// Path: settings.offlineData
class _Translations$settings$offlineData$fr extends Translations$settings$offlineData$en {
	_Translations$settings$offlineData$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Données hors ligne';
	@override String get noFiles => 'Aucun fichier de données';
	@override String get noFilesDescription => 'Activez des extensions d\'activité ou de recherche pour télécharger ici leurs données hors ligne.';
	@override String get refresh => 'Rafraîchir';
	@override String get refreshing => 'Actualisation…';
	@override String get updateAll => 'Tout mettre à jour';
	@override String get updatingAll => 'Mise à jour de tous les fichiers de données…';
	@override String get neverDownloaded => 'Jamais téléchargé';
	@override String get updatedJustNow => 'Mis à jour à l\'instant';
	@override String updatedDaysAgo({required Object days}) => 'Mis à jour il y a ${days} j';
	@override String updatedDaysHoursAgo({required Object days, required Object hours}) => 'Mis à jour il y a ${days} j ${hours} h';
	@override String updatedHoursAgo({required Object hours}) => 'Mis à jour il y a ${hours} h';
	@override String updatedHoursMinutesAgo({required Object hours, required Object minutes}) => 'Mis à jour il y a ${hours} h ${minutes} min';
	@override String updatedMinutesAgo({required Object minutes}) => 'Mis à jour il y a ${minutes} min';
	@override String lastDownloadRefused({required Object imported, required Object existing}) => 'Le dernier téléchargement ne contenait que ${imported} enregistrements sur ${existing} et n\'a pas été utilisé. Rafraîchissez pour l\'accepter.';
	@override String get extensionsSection => 'Extensions';
}

// Path: settings.profiles
class _Translations$settings$profiles$fr extends Translations$settings$profiles$en {
	_Translations$settings$profiles$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get notSet => 'Non défini';
	@override String get personalInfo => 'Infos personnelles';
	@override String get personalInfoNote => 'Ces infos peuvent être incluses dans les journaux générés quand c\'est utile pour les soumissions';
	@override String get name => 'Nom';
	@override String get email => 'E-mail';
	@override String get club => 'Club';
	@override String get arrlSection => 'Section ARRL';
	@override String get racSection => 'Section RAC';
	@override String get section => 'Section';
}

// Path: settings.search
class _Translations$settings$search$fr extends Translations$settings$search$en {
	_Translations$settings$search$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get clear => 'Effacer';
	@override String get hint => 'Rechercher dans les préférences';
}

// Path: settings.developer
class _Translations$settings$developer$fr extends Translations$settings$developer$en {
	_Translations$settings$developer$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get developerModeDescription => 'Active les avertissements développeur, les logs de débogage et les outils.';
	@override String get experiments => 'Expériences';
	@override String experimentsEnabled({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} activée',
		other: '${count} activées',
	);
	@override String get patchTrack => 'Piste des correctifs';
	@override String get patchTrackDescription => 'Quel anneau de correctifs à distance cet appareil suit. Les anneaux plus aventureux reçoivent les corrections plus tôt, moins testées. Les correctifs s\'appliquent au prochain redémarrage.';
	@override String get trackStable => 'Stable';
	@override String get trackUnstable => 'Instable';
	@override String get trackBleeding => 'À la pointe';
	@override String checkingTrack({required Object track}) => 'Recherche d\'un correctif sur « ${track} »…';
	@override String get patchDownloaded => 'Correctif téléchargé — redémarrez l\'application pour l\'appliquer.';
	@override String noNewPatch({required Object track}) => 'Aucun nouveau correctif sur « ${track} ».';
	@override String get noPatchInstalled => 'Aucun correctif installé — exécution du binaire de la version.';
	@override String runningPatch({required Object patch}) => 'Correctif n°${patch} en cours d\'exécution.';
	@override String get deepLinks => 'Liens profonds';
	@override String get registerUrlSchemes => 'Enregistrer les schémas d\'URL';
	@override String get registerUrlSchemesDescription => 'Permettre aux liens com.ham2k:// d\'ouvrir cette copie de l\'application';
	@override String get registerUrlSchemesDone => 'Cette copie ouvre maintenant les liens com.ham2k://';
	@override String registerUrlSchemesFailed({required Object error}) => 'Enregistrement impossible : ${error}';
	@override String get systemInformation => 'Informations sur le système';
	@override String get appVersion => 'Version de l\'application';
	@override String get dataFolder => 'Dossier de données';
	@override String get loading => '(chargement…)';
	@override String get panelLoadFailed => 'Impossible de charger ce panneau de paramètres.';
	@override String get extDevServer => 'Serveur de développement d\'extensions';
	@override String get extensionSettings => 'Paramètres des extensions';
	@override String get extDevServerDescription => 'Charger les extensions depuis un serveur de développement sur votre réseau au lieu de celles intégrées à l\'application, et les recharger à chaque enregistrement.';
	@override String get extDevServerAddress => 'Adresse du serveur';
	@override String get extDevServerHint => '192.168.1.20:8787';
	@override String get extDevServerConnect => 'Connecter';
	@override String get extDevServerDisconnect => 'Déconnecter';
	@override String get extDevServerConnecting => 'Connexion…';
	@override String extDevServerConnected({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} extension servie : ${keys}',
		other: '${count} extensions servies : ${keys}',
	);
	@override String get extDevServerDisconnected => 'Non connecté';
	@override String get extDevServerReconnect => 'Se reconnecter au lancement';
	@override String extDevServerLastReload({required Object key, required Object time}) => 'Dernier rechargement : ${key} à ${time}';
	@override String extDevServerBuildErrors({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} extension en échec de compilation',
		other: '${count} extensions en échec de compilation',
	);
	@override String get catalog => 'Catalogue d\'extensions';
	@override String get catalogDescription => 'Lire le catalogue depuis un autre serveur — un serveur local pour travailler sur le catalogue lui-même. Vide signifie catalog.ham2k.net.';
	@override String get catalogAddress => 'Adresse du catalogue';
	@override String get catalogHint => 'http://localhost:8787';
	@override String get catalogSearchTracks => 'Pistes de recherche du catalogue';
	@override String get catalogSearchStable => 'Stable uniquement';
	@override String get catalogSearchUnstable => 'Instable ou mieux';
	@override String get catalogSearchBleeding => 'À la pointe ou mieux';
}

// Path: settings.about
class _Translations$settings$about$fr extends Translations$settings$about$en {
	_Translations$settings$about$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get notices => 'Notifications et messages';
	@override String get noticesDescription => 'Annonces et messages d\'état';
	@override String get releaseNotes => 'Notes de version';
	@override String get copiedVersion => 'Détails de la version copiés dans le presse-papiers';
}

// Path: settings.panels
class _Translations$settings$panels$fr extends Translations$settings$panels$en {
	_Translations$settings$panels$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get settings => 'Préférences de l\'application';
	@override String get settingsDescription => 'Faites fonctionner l\'application comme vous le souhaitez';
	@override String get commonSettings => 'Préférences courantes';
	@override String get syncDescription => 'Sauvegardez et synchronisez vos journaux entre vos appareils';
	@override String get accountsDescription => 'Identifiants de services, données hors ligne, et plus encore';
	@override String get extensions => 'Extensions et fonctionnalités';
	@override String get extensionsDescription => 'Activités, concours, panneaux du tableau de bord et autres fonctionnalités';
	@override String get profilesDescription => 'Indicatif de l\'opérateur et profil de la station';
	@override String get stationProfiles => 'Profils de station';
	@override String get developerSettings => 'Paramètres développeur';
	@override String get developerSettingsDescription => 'Outils de débogage et de développement';
	@override String get about => 'À propos';
	@override String get aboutDescription => 'Version, crédits et informations légales';
	@override String get unavailableTitle => 'Certains paramètres sont indisponibles';
	@override String get unavailableText => 'Le moteur d\'extensions n\'a pas pu démarrer : les paramètres fournis par les extensions sont donc absents.';
	@override String get station => 'Configuration de la station';
	@override String get stationDescription => 'Contrôle CAT et autres options';
	@override String get peers => 'Appareils pairs';
	@override String get peersDescription => 'Se connecter à d\'autres appareils à proximité';
}

// Path: settings.gridPrecisionOpts
class _Translations$settings$gridPrecisionOpts$fr extends Translations$settings$gridPrecisionOpts$en {
	_Translations$settings$gridPrecisionOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caractères (FN31pr)';
	@override String get eight => '8 caractères (FN31pr55)';
}

// Path: settings.gridPrecisionDescription
class _Translations$settings$gridPrecisionDescription$fr extends Translations$settings$gridPrecisionDescription$en {
	_Translations$settings$gridPrecisionDescription$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get six => '6 caractères';
	@override String get eight => '8 caractères';
}

// Path: home.logs.columns
class _Translations$home$logs$columns$fr extends Translations$home$logs$columns$en {
	_Translations$home$logs$columns$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get date => 'Date';
	@override String get time => 'Heure';
	@override String get freq => 'Fréquence';
	@override String get mode => 'Mode';
	@override String get call => 'Indicatif';
	@override String get name => 'Nom';
	@override String get station => 'Station';
	@override String get band => 'Bande';
	@override String get sent => 'Envoyé';
	@override String get rcvd => 'Reçu';
	@override String get grid => 'Grille';
	@override String get state => 'État';
	@override String get country => 'Pays';
	@override String get refs => 'Réfs';
}

// Path: home.logs.panels
class _Translations$home$logs$panels$fr extends Translations$home$logs$panels$en {
	_Translations$home$logs$panels$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get qsos => 'Journal des QSOs';
	@override String get qsosDescription => 'Les QSOs de l\'indicatif sélectionné, toutes opérations confondues.';
	@override String get info => 'Infos';
	@override String get infoDescription => 'Le nombre total de QSOs, ou la recherche d\'indicatif du QSO sélectionné.';
	@override String get map => 'Carte';
	@override String get mapDescription => 'La position du QSO sélectionné.';
}

// Path: home.logs.import
class _Translations$home$logs$import$fr extends Translations$home$logs$import$en {
	_Translations$home$logs$import$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String callsigns({required Object calls}) => 'Indicatifs : ${calls}';
	@override String get skippedOne => '1 enregistrement n\'a pas pu être lu';
	@override String skippedOther({required Object count}) => '${count} enregistrements n\'ont pas pu être lus';
	@override String get readingTitle => 'Lecture du fichier ADIF…';
	@override String get checkingTitle => 'Recherche des doublons…';
	@override String get importingTitle => 'Importation des QSOs…';
	@override String readingDetail({required Object kb}) => '${kb} Ko';
	@override String checkingDetail({required Object done, required Object total}) => '${done} sur ${total} vérifiés';
	@override String importingDetail({required Object imported, required Object total}) => '${imported} importés sur ${total}';
}

// Path: operation.layout.panels
class _Translations$operation$layout$panels$fr extends Translations$operation$layout$panels$en {
	_Translations$operation$layout$panels$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get loggingDescription => 'Le journal et les champs de saisie';
	@override String get infoDescription => 'Ce que nous savons de la station contactée';
	@override String get spotsDescription => 'Les spots des clusters et des programmes d\'activité';
	@override String get mapDescription => 'L\'emplacement des contacts';
	@override String get clockDescription => 'Une horloge, dans n\'importe quel fuseau horaire';
	@override String get clockFace => 'Cadran';
	@override String get clockFaceLcd => 'LCD';
	@override String get clockFaceAnalog => 'Analogique';
	@override String get clockZone => 'Fuseau horaire';
	@override String get clockZoneUtc => 'UTC';
	@override String get clockZoneDevice => 'Cet appareil';
	@override String get clockShowSeconds => 'Afficher les secondes';
	@override String get weatherDescription => 'Les conditions actuelles et des huit prochaines heures, là où vous opérez';
	@override String get weatherUseOperationLocation => 'Utiliser l\'emplacement de l\'opération';
	@override String get weatherLocation => 'Emplacement';
	@override String get weatherLocationDescription => 'Un carré locator (FN31pr) ou lat,lon. Ignoré tant que « Utiliser l\'emplacement de l\'opération » est coché.';
	@override String get weatherNoLocation => 'Aucun emplacement défini. Donnez un emplacement à ce panneau dans ses paramètres, ou placez-le dans une opération qui en a un.';
	@override String weatherBadLocation({required Object location}) => 'Impossible de lire l\'emplacement ${location}. Utilisez un carré locator comme FN31pr, ou 42.36,-71.06.';
	@override String get weatherUnreachable => 'Open-Meteo est injoignable — pas de réseau ? Nouvel essai sous peu.';
	@override String get weatherUnreadable => 'Open-Meteo a répondu, mais rien de lisible. Nouvel essai sous peu.';
	@override String weatherGusts({required Object speed}) => 'rafales ${speed}';
	@override String get panelAgeNow => 'à l\'instant';
	@override String panelAgeMinutes({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'il y a ${count} min',
		other: 'il y a ${count} min',
	);
	@override String panelAgeHours({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'il y a ${count} h',
		other: 'il y a ${count} h',
	);
	@override late final _Translations$operation$layout$panels$weatherConditions$fr weatherConditions = _Translations$operation$layout$panels$weatherConditions$fr._(_root);
	@override String get websiteDescription => 'Une page web de votre choix, dans un volet';
	@override String get websiteUrl => 'Adresse';
	@override String get websiteRefresh => 'Actualisation';
	@override String get websiteRefreshNever => 'Jamais';
	@override String get websiteRefresh1 => 'Toutes les minutes';
	@override String get websiteRefresh5 => 'Toutes les 5 minutes';
	@override String get websiteRefresh15 => 'Toutes les 15 minutes';
	@override String get websiteTitle => 'Nom du panneau';
	@override String get websiteRefreshNow => 'Rafraîchir maintenant';
	@override String get websiteNoUrl => 'Aucune adresse pour l\'instant. Ouvrez les paramètres de ce panneau pour choisir une page.';
	@override String get websiteBadUrl => 'Cela ne ressemble pas à une adresse web. Elle doit commencer par https://';
	@override String get websiteNotHttps => 'Seules les adresses https:// peuvent être affichées ici.';
	@override String get websiteUnsupported => 'Les pages web ne peuvent pas être affichées dans un panneau sur ce système.';
	@override String get websiteOpenExternally => 'Ouvrir dans le navigateur';
	@override String websiteLoadFailed({required Object reason}) => 'Impossible de charger la page : ${reason}';
	@override String get remoteScreenDescription => 'Un écran, une application ou une fenêtre partagé par un autre de vos appareils.';
	@override String get remoteScreenTarget => 'Écran';
	@override String get remoteScreenChoose => 'Choisir un écran…';
	@override String get remoteScreenPickerTitle => 'Écrans partagés';
	@override String get remoteScreenPickerEmpty => 'Aucun de vos appareils ne partage d\'écran. Activez Partager les écrans et fenêtres dans Paramètres → Appareils pairs, sur l\'appareil que vous voulez voir.';
	@override String get remoteScreenUnset => 'Aucun écran choisi. Ouvrez les paramètres de ce panneau pour en choisir un que vos autres appareils partagent.';
	@override String get remoteScreenConnecting => 'Connexion…';
	@override String get remoteScreenPeerAway => 'Cet appareil n\'est pas connecté pour l\'instant.';
	@override String get remoteScreenNotOffered => 'Cet appareil a cessé de partager cet écran.';
	@override String get remoteScreenNoListener => 'Cet appareil n\'accepte pas les connexions — vérifiez son pare-feu.';
	@override String get remoteScreenNoLan => 'Les écrans ne sont partagés que sur le réseau local, pas en Bluetooth.';
	@override String get remoteScreenRefused => 'Cet appareil a refusé de partager cet écran.';
	@override String get remoteScreenSettings => 'Paramètres du panneau';
	@override String get remoteScreenAdjust => 'Ajuster la vue';
	@override String get remoteScreenDetail => 'Détail';
	@override String get remoteScreenDetailStandard => 'Standard';
	@override String get remoteScreenDetailHigh => 'Élevé';
	@override String get remoteScreenDetailMaximum => 'Maximum';
	@override String get remoteScreenAdjustDone => 'OK';
	@override String get remoteScreenZoomIn => 'Zoom avant';
	@override String get remoteScreenZoomOut => 'Zoom arrière';
	@override String get remoteScreenStopped => 'Cet écran ou cette fenêtre n\'est plus affiché.';
	@override String get remoteScreenCaptureFailed => 'Cet appareil n\'a pas pu capturer cet écran — il lui faut peut-être l\'autorisation d\'enregistrement de l\'écran.';
	@override String get remoteScreenNoAnswer => 'Cet appareil n\'a pas répondu. Le partage d\'écran n\'y est peut-être pas activé.';
	@override String get remoteScreenNoMedia => 'Impossible d\'ouvrir une connexion pour l\'image. Vérifiez le pare-feu de cet appareil.';
	@override String get solarDescription => 'Conditions solaires et géomagnétiques, avec la propagation bande par bande';
	@override String get solarUnreachable => 'hamqsl.com est injoignable — pas de réseau ? Nouvel essai sous peu.';
	@override String get solarUnreadable => 'hamqsl.com a répondu, mais sans relevé exploitable. Nouvel essai sous peu.';
	@override String get solarAIndex => 'A';
	@override String get solarKIndex => 'Kp';
	@override String get solarBandDay => 'Jour';
	@override String get solarBandNight => 'Nuit';
	@override String get solarBandGood => 'Bonne';
	@override String get solarBandFair => 'Moyenne';
	@override String get solarBandPoor => 'Mauvaise';
	@override String solarSources({required Object primary, required Object secondary}) => 'Sources : ${primary}, ${secondary}';
	@override String get remoteScreenDegraded => 'La connexion peine — des images sont sautées.';
	@override String get remoteScreenStalled => 'Les images ne passent plus — cette connexion est peut-être trop lente.';
	@override String get radioDescription => 'La face avant d\'une radio — fréquence, mode et puissance, pilotée par CAT';
	@override String get radioStyle => 'Style';
	@override String get radioStyleLcd => 'LCD';
	@override String get radioStyleModern => 'Moderne';
	@override String get radioRadio => 'Radio';
	@override String radioAutoNamed({required Object name}) => 'VFO A — ${name}';
	@override String get radioAutoNone => 'VFO A — aucune radio désignée';
	@override String get radioNoRadio => 'Aucune radio à afficher. Choisissez-en une dans les paramètres de ce panneau, ou ajoutez-en une dans Configuration de la station.';
	@override String get radioNotConfigured => 'Cette radio n\'est pas encore configurée. Choisissez son port ou son adresse dans Configuration de la station.';
	@override String get radioNoFrequency => '—';
	@override String get radioOff => 'Radio non connectée';
	@override String get radioWatts => 'W';
	@override String get radioConnect => 'Connecter cette radio';
	@override String get radioDisconnect => 'Déconnecter cette radio';
	@override String get radioStale => 'PAS DE DONNÉES';
	@override String get radioTransmitting => 'TX';
	@override String get radioSwr => 'ROS';
	@override String get radioAlc => 'ALC';
	@override String get radioVolts => 'V';
	@override String get radioSwrHigh => 'ROS élevé';
}

// Path: operation.export.compactFileNames
class _Translations$operation$export$compactFileNames$fr extends Translations$operation$export$compactFileNames$en {
	_Translations$operation$export$compactFileNames$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Utiliser des noms de fichiers compacts';
	@override String get descriptionOn => 'Noms courts adaptés aux outils de téléversement, comme N0CALL@US-1234-20260727.adi';
	@override String get descriptionOff => 'Noms lisibles, comme 2026-07-27 N0CALL at US-1234.adi';
}

// Path: operation.export.includePrivateData
class _Translations$operation$export$includePrivateData$fr extends Translations$operation$export$includePrivateData$en {
	_Translations$operation$export$includePrivateData$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Inclure les infos privées';
	@override String get descriptionOn => 'Les noms, adresses, e-mails, locators et notes sont inclus';
	@override String get descriptionOff => 'Les noms, adresses, e-mails, locators et notes sont exclus';
	@override String get note => 'L\'export ADIF complet inclut toujours tout';
}

// Path: operation.export.stash
class _Translations$operation$export$stash$fr extends Translations$operation$export$stash$en {
	_Translations$operation$export$stash$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get needsEmailTitle => 'Ajoutez d\'abord une adresse e-mail';
	@override String get needsEmailBody => 'Ham2K File Stash envoie vos fichiers à l\'adresse e-mail de votre compte LoFi, et vous vous connectez avec elle sur stash.ham2k.net. Votre compte n\'a pas encore d\'adresse confirmée — ajoutez-la dans Paramètres › Synchronisation cloud.';
	@override String get openSyncSettings => 'Ouvrir Synchronisation cloud';
	@override String get replaceTitle => 'Le dépôt récent sera remplacé';
	@override String replaceBody({required Object name}) => 'Vous avez envoyé « ${name} » il y a moins de 6 heures et il n\'a pas encore été téléchargé. Les comptes gratuits ne conservent qu\'un seul dépôt à la fois : l\'envoyer maintenant le remplacera.';
	@override String get replaceConfirm => 'Envoyer quand même';
	@override String get failedTitle => 'Impossible d\'envoyer vers Ham2K File Stash';
	@override String get sentTitle => 'Envoyé vers Ham2K File Stash';
	@override String retrieve({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Vous pouvez récupérer ce fichier en vous rendant sur **[stash.ham2k.net](https://stash.ham2k.net)** depuis n\'importe quel navigateur.',
		other: 'Vous pouvez récupérer ces fichiers en vous rendant sur **[stash.ham2k.net](https://stash.ham2k.net)** depuis n\'importe quel navigateur.',
	);
	@override String get mayHaveArrived => 'Pas de réponse du dépôt — le fichier est peut-être arrivé quand même. Vérifiez stash.ham2k.net avant de renvoyer';
	@override String get notSent => 'non envoyé';
	@override String notArrived({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: 'Ce fichier n\'est pas arrivé :',
		other: 'Ces ${count} fichiers ne sont pas arrivés :',
	);
	@override String get emailOffer => 'Ou, pour plus de commodité, nous pouvons vous envoyer un e-mail avec un lien direct.';
	@override String get emailMe => 'M\'envoyer un lien par e-mail';
	@override String get emailSent => 'Nous vous avons envoyé un lien de téléchargement par e-mail.';
	@override String emailFailed({required Object error}) => 'Impossible d\'envoyer l\'e-mail : ${error}';
	@override String get freeTier => 'Les comptes gratuits ne peuvent conserver qu\'un seul dépôt à la fois. Les abonnés peuvent en conserver autant qu\'ils le souhaitent.';
	@override String sentStatus({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count,
		one: '${count} fichier envoyé vers Ham2K File Stash (stash.ham2k.net)',
		other: '${count} fichiers envoyés vers Ham2K File Stash (stash.ham2k.net)',
	);
}

// Path: operation.spots.continents
class _Translations$operation$spots$continents$fr extends Translations$operation$spots$continents$en {
	_Translations$operation$spots$continents$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get af => 'Afrique';
	@override String get as => 'Asie';
	@override String get eu => 'Europe';
	@override String get na => 'Amérique du Nord';
	@override String get oc => 'Océanie';
	@override String get sa => 'Amérique du Sud';
	@override String get an => 'Antarctique';
}

// Path: operation.spots.filters
class _Translations$operation$spots$filters$fr extends Translations$operation$spots$filters$en {
	_Translations$operation$spots$filters$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Filtrer les spots';
	@override String get band => 'Bande';
	@override String get mode => 'Mode';
	@override String get age => 'Âge';
	@override String get sources => 'Sources';
	@override String get continent => 'Continent';
	@override String get sorting => 'Tri';
	@override String get sortByTime => 'Par heure du spot';
	@override String get sortByFrequency => 'Par fréquence';
	@override String get groupByBand => 'Grouper par bande';
	@override String get groupCallsWithNotes => 'Grouper les indicatifs avec notes';
	@override String get sourceNoReply => 'Pas de réponse';
	@override String get sourceError => 'Erreur';
}

// Path: operation.spots.logConflict
class _Translations$operation$spots$logConflict$fr extends Translations$operation$spots$logConflict$en {
	_Translations$operation$spots$logConflict$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Le panneau de saisie est occupé';
	@override String get editingBody => 'Vous modifiez un contact déjà saisi. Saisir plutôt ce spot, ou revenir terminer la modification ?';
	@override String get composingBody => 'Vous avez commencé à saisir un contact. Saisir plutôt ce spot, ou revenir terminer votre saisie ?';
	@override String get goBack => 'Revenir';
	@override String get clearAndLog => 'Effacer et saisir le spot';
}

// Path: settings.logging.leftieMode
class _Translations$settings$logging$leftieMode$fr extends Translations$settings$logging$leftieMode$en {
	_Translations$settings$logging$leftieMode$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Mode gaucher';
	@override String get descriptionOn => 'Utilisation de la disposition pour gaucher';
	@override String get descriptionOff => 'Utilisation de la disposition pour droitier';
}

// Path: settings.logging.countryFlags
class _Translations$settings$logging$countryFlags$fr extends Translations$settings$logging$countryFlags$en {
	_Translations$settings$logging$countryFlags$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Drapeaux des pays';
	@override String get dx => 'Uniquement pour les contacts DX';
	@override String get all => 'Drapeaux pour tous les contacts';
	@override String get none => 'Aucun drapeau';
}

// Path: settings.logging.countryFlagsDescription
class _Translations$settings$logging$countryFlagsDescription$fr extends Translations$settings$logging$countryFlagsDescription$en {
	_Translations$settings$logging$countryFlagsDescription$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get dx => 'Affichage des drapeaux uniquement pour les contacts DX';
	@override String get all => 'Affichage des drapeaux pour tous les contacts';
	@override String get none => 'Aucun drapeau affiché';
}

// Path: settings.logging.suggestDefaultOperator
class _Translations$settings$logging$suggestDefaultOperator$fr extends Translations$settings$logging$suggestDefaultOperator$en {
	_Translations$settings$logging$suggestDefaultOperator$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Suggérer l\'opérateur';
	@override String get descriptionOn => 'Votre indicatif est proposé comme opérateur quand une opération utilise un autre indicatif de station';
	@override String get descriptionOff => 'L\'opérateur reste vide sauf si vous le renseignez';
}

// Path: settings.logging.showBearing
class _Translations$settings$logging$showBearing$fr extends Translations$settings$logging$showBearing$en {
	_Translations$settings$logging$showBearing$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afficher la direction';
	@override String get descriptionOn => 'Affichage de l\'azimut estimé vers la station';
	@override String get descriptionOff => 'Aucune information d\'azimut affichée';
}

// Path: settings.logging.showReverseBearing
class _Translations$settings$logging$showReverseBearing$fr extends Translations$settings$logging$showReverseBearing$en {
	_Translations$settings$logging$showReverseBearing$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Afficher aussi l\'azimut inverse';
	@override String get descriptionOn => 'Affichage aussi de l\'azimut depuis la station, comme « 45° / 225° »';
	@override String get descriptionOff => 'Affichage uniquement de l\'azimut vers la station';
}

// Path: settings.logging.switchSentRcvd
class _Translations$settings$logging$switchSentRcvd$fr extends Translations$settings$logging$switchSentRcvd$en {
	_Translations$settings$logging$switchSentRcvd$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Changer l\'ordre des rapports de signal';
	@override String get sentFirst => 'Envoyé en premier, Reçu en second';
	@override String get rcvdFirst => 'Reçu en premier, Envoyé en second';
}

// Path: settings.logging.jumpAfterRST
class _Translations$settings$logging$jumpAfterRST$fr extends Translations$settings$logging$jumpAfterRST$en {
	_Translations$settings$logging$jumpAfterRST$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Passer au champ suivant à l\'entrée RST';
	@override String get descriptionOn => 'Passage au champ suivant après la saisie du RST';
	@override String get descriptionOff => 'Pas de passage automatique';
}

// Path: settings.logging.defaultReport
class _Translations$settings$logging$defaultReport$fr extends Translations$settings$logging$defaultReport$en {
	_Translations$settings$logging$defaultReport$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Report par défaut — Phonie';
	@override String get description => 'Utilisé quand Envoyé ou Reçu est laissé vide en SSB, FM ou AM';
}

// Path: settings.logging.defaultReportCW
class _Translations$settings$logging$defaultReportCW$fr extends Translations$settings$logging$defaultReportCW$en {
	_Translations$settings$logging$defaultReportCW$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Report par défaut — CW et numérique';
	@override String get description => 'Utilisé quand Envoyé ou Reçu est laissé vide en CW, RTTY et autres modes numériques';
}

// Path: settings.logging.defaultReportFT8
class _Translations$settings$logging$defaultReportFT8$fr extends Translations$settings$logging$defaultReportFT8$en {
	_Translations$settings$logging$defaultReportFT8$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Report par défaut — FT8 et FT4';
	@override String get description => 'Utilisé quand Envoyé ou Reçu est laissé vide dans les modes FT';
}

// Path: settings.logging.numbersRow
class _Translations$settings$logging$numbersRow$fr extends Translations$settings$logging$numbersRow$en {
	_Translations$settings$logging$numbersRow$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Ligne des chiffres';
	@override String get description => 'Afficher une ligne de touches numériques au-dessus du clavier pendant la saisie';
}

// Path: settings.logging.numbersRowExtra
class _Translations$settings$logging$numbersRowExtra$fr extends Translations$settings$logging$numbersRowExtra$en {
	_Translations$settings$logging$numbersRowExtra$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Touche barre oblique et point';
	@override String get description => 'Ajoute une touche contextuelle : « / » pour les indicatifs, « . » pour les nombres';
}

// Path: settings.logging.numbersRowVibrate
class _Translations$settings$logging$numbersRowVibrate$fr extends Translations$settings$logging$numbersRowVibrate$en {
	_Translations$settings$logging$numbersRowVibrate$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vibrer à l\'appui';
	@override String get description => 'Retour haptique quand vous touchez une touche numérique';
}

// Path: settings.catServer.protocolOpts
class _Translations$settings$catServer$protocolOpts$fr extends Translations$settings$catServer$protocolOpts$en {
	_Translations$settings$catServer$protocolOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get off => 'Désactivé';
	@override String get rigctld => 'Hamlib rigctld';
	@override String get flrig => 'flrig';
	@override String get hrd => 'Ham Radio Deluxe®';
	@override String get n3fjp => 'N3FJP';
}

// Path: settings.radio.units
class _Translations$settings$radio$units$fr extends Translations$settings$radio$units$en {
	_Translations$settings$radio$units$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get ms => 'ms';
	@override String get kHz => 'kHz';
	@override String get kHzPerSecond => 'kHz/s';
	@override String get hz => 'Hz';
}

// Path: settings.radio.pttKey
class _Translations$settings$radio$pttKey$fr extends Translations$settings$radio$pttKey$en {
	_Translations$settings$radio$pttKey$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Contrôler le PTT avec [\']';
	@override String get descriptionOn => 'En modes Phonie, [\'] passe la radio en émission et [\'] à nouveau la repasse en réception. Elle repasse d\'elle-même en réception au bout d\'une minute.';
	@override String get descriptionOff => 'La touche [\'] ne passe pas la radio en émission.';
	@override String get pill => 'TX';
	@override String get transmitting => 'Émission';
}

// Path: settings.radio.smartVfoSnap
class _Translations$settings$radio$smartVfoSnap$fr extends Translations$settings$radio$smartVfoSnap$en {
	_Translations$settings$radio$smartVfoSnap$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arrondi intelligent du VFO';
	@override String get descriptionOn => 'Quand vous arrêtez de tourner le bouton, la fréquence est arrondie à un pas raisonnable. Modes vocaux uniquement.';
	@override String get descriptionOff => 'La fréquence reste exactement là où vous l\'avez accordée.';
}

// Path: settings.radio.snapDebounce
class _Translations$settings$radio$snapDebounce$fr extends Translations$settings$radio$snapDebounce$en {
	_Translations$settings$radio$snapDebounce$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arrondi intelligent : délai de stabilisation';
	@override String get description => 'Durée pendant laquelle le bouton doit rester immobile avant que la fréquence soit arrondie. Plus court paraît immédiat ; plus long laisse le temps d\'un mouvement lent.';
}

// Path: settings.radio.snapLongMove
class _Translations$settings$radio$snapLongMove$fr extends Translations$settings$radio$snapLongMove$en {
	_Translations$settings$radio$snapLongMove$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arrondi intelligent : grand déplacement';
	@override String get description => 'À partir de ce déplacement, la fréquence est arrondie au kHz entier, quelle que soit la lenteur de la fin du mouvement.';
}

// Path: settings.radio.snapMinMove
class _Translations$settings$radio$snapMinMove$fr extends Translations$settings$radio$snapMinMove$en {
	_Translations$settings$radio$snapMinMove$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arrondi intelligent : plus petit déplacement';
	@override String get description => 'En dessous de ce déplacement, la fréquence n\'est pas arrondie, pour ne pas toucher à l\'accord fin.';
}

// Path: settings.radio.snapMinSpeed
class _Translations$settings$radio$snapMinSpeed$fr extends Translations$settings$radio$snapMinSpeed$en {
	_Translations$settings$radio$snapMinSpeed$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Arrondi intelligent : mouvement le plus lent';
	@override String get description => 'Si le bouton tourne plus lentement que cela, la fréquence n\'est pas arrondie, sauf en cas de grand déplacement.';
}

// Path: settings.radio.enterSends
class _Translations$settings$radio$enterSends$fr extends Translations$settings$radio$enterSends$en {
	_Translations$settings$radio$enterSends$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get pillOff => 'ESM désactivé';
	@override String get pillRun => 'ESM Run';
	@override String get pillSp => 'ESM S&P';
	@override String get field => 'Entrée envoie les messages';
	@override String get off => 'Désactivé';
	@override String get run => 'Run';
	@override String get sp => 'S&P';
	@override String semantics({required Object state}) => 'Entrée envoie les messages : ${state}. Appuyez pour changer.';
}

// Path: settings.radio.keyerSpeed
class _Translations$settings$radio$keyerSpeed$fr extends Translations$settings$radio$keyerSpeed$en {
	_Translations$settings$radio$keyerSpeed$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Vitesse du manipulateur';
	@override String get unit => 'WPM';
	@override String pill({required Object wpm}) => '${wpm} wpm';
	@override String get pillUnknown => '– wpm';
}

// Path: settings.radio.cwMessages
class _Translations$settings$radio$cwMessages$fr extends Translations$settings$radio$cwMessages$en {
	_Translations$settings$radio$cwMessages$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Messages CW du manipulateur';
	@override String get notSupported => 'La radio actuelle ne prend pas en charge la manipulation CW';
	@override String key({required Object n}) => 'F${n}';
	@override String messageTitle({required Object n}) => 'Message (${n})';
	@override String get labelField => 'Libellé';
	@override String labelKey({required Object n}) => 'Libellé F${n}';
	@override String get details => 'Détails';
	@override String get empty => '(vide)';
	@override String get sets => 'Jeu de messages';
	@override String get newSet => 'Nouveau jeu';
	@override String get renameSet => 'Renommer le jeu';
	@override String get deleteSet => 'Supprimer le jeu';
	@override String get newSetName => 'Nom';
	@override String get setDefault => 'Par défaut';
	@override String get setPota => 'POTA';
	@override String get setEsm => 'Messages ESM';
	@override String get setSaved => 'Mes messages';
	@override String get repeat => 'Répéter le message n°1';
	@override String get repeatOff => 'Non';
	@override String repeatAfter({required Object n}) => 'Après ${n} secondes';
	@override String get repeatWait => 'Répétition';
	@override String get keyboard => 'Taper pour envoyer';
	@override String get keyboardField => 'Taper pour envoyer';
	@override String get closeArea => 'Fermer la zone du manipulateur';
	@override String get help => 'Aide';
	@override String get helpTitle => 'Rédiger des messages CW';
	@override String get helpIntro => 'Les messages peuvent utiliser des modèles avec les valeurs suivantes :';
	@override String get helpOpCall => 'Votre indicatif';
	@override String get helpQsoCall => 'Leur indicatif — dans une pile //, l\'indicatif qui sera saisi';
	@override String get helpQsoFullCall => 'Leur indicatif, s\'il est valide ; vide pour un indicatif partiel';
	@override String get helpQsoPartial => 'Un indicatif partiel ; vide s\'il y a un indicatif complet valide';
	@override String get helpQsoNextCall => 'Dans une pile //, l\'indicatif qui sera sélectionné pour la prochaine saisie, s\'il est complet et valide';
	@override String get helpQsoNextPartial => 'Dans une pile //, le partiel suivant après la saisie du contact en cours';
	@override String get helpQsoName => 'Leur prénom, tel que saisi ou sinon issu de la recherche';
	@override String get helpQsoState => 'Leur état, tel que saisi ou sinon issu de la recherche';
	@override String get helpKeyerMsg => 'Le message 1 tel qu\'il serait envoyé, à l\'intérieur d\'un autre message. Valable pour les messages 1 à 8';
	@override String get helpQsoRst => 'Le report que vous envoyez';
	@override String get helpQsoSerial => 'Votre numéro de série, dans un concours qui en envoie un';
	@override String get helpPad => 'Complète avec des zéros jusqu\'à ce nombre de chiffres : 7 est envoyé 007';
	@override String get helpCut => 'Chiffres abrégés, T pour 0 et N pour 9 : 599 est envoyé 5NN';
	@override String get helpCutDigits => 'Choisit les chiffres à abréger, entre guillemets — 0 est T, 1 est A, 5 est E, 9 est N';
	@override String get helpFullExample => 'Exemple complet :';
	@override String get helpExample => 'Envoie W1AW 5NN TT7';
	@override String get helpEsmIntro => 'Avec Entrée envoie les messages activé, Entrée envoie les messages selon leur touche de fonction, comme dans N1MM. Le jeu Messages ESM commence par ceux-ci :';
	@override String get helpEsmCq => 'En Run, Entrée avec le champ indicatif vide lance un appel CQ';
	@override String get helpEsmExchange => 'Votre échange : après leur indicatif en Run, après leur réponse en S&P';
	@override String get helpEsmThanks => 'Remerciements, une fois le contact saisi : ses valeurs désignent le contact suivant, pas celui-ci';
	@override String get helpEsmMyCall => 'En S&P, votre indicatif à la station à laquelle vous répondez';
	@override String get helpEsmHisCall => 'En Run, leur indicatif avant votre échange';
	@override String get helpEsmAgain => 'Redemande quand rien de leur échange n\'a été copié';
	@override String get helpEsmStackThanks => 'F3 suggéré pour les piles // : TU part après la saisie du contact, donc il remercie, puis appelle la station suivante de la pile et envoie votre échange, ou redemande un partiel (TU KR?) ; s\'il n\'en reste aucune, juste TU';
}

// Path: settings.radio.voiceMessages
class _Translations$settings$radio$voiceMessages$fr extends Translations$settings$radio$voiceMessages$en {
	_Translations$settings$radio$voiceMessages$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Messages vocaux';
	@override String get notSupported => 'La radio actuelle ne prend pas en charge les messages vocaux';
	@override String get description => 'Utilise les mémoires vocales de la radio';
	@override String key({required Object n}) => 'M${n}';
	@override String messageTitle({required Object n}) => 'Mémoire vocale (${n})';
	@override String get labelField => 'Libellé';
	@override String labelKey({required Object n}) => 'Libellé de la mémoire vocale ${n}';
	@override String durationSeconds({required Object n}) => '${n} s';
	@override String get emptyOnRadio => 'Vide';
	@override String get notMeasured => 'Durée inconnue';
	@override String get playButton => 'Lire';
	@override String get recordButton => 'Enregistrer';
	@override String get stopButton => 'Arrêter';
	@override String get repeat => 'Répéter le message n°1';
	@override String get repeatOff => 'Non';
	@override String repeatAfter({required Object n}) => 'Après ${n} secondes';
	@override String recordHelpTitle({required Object model}) => 'Notes pour ${model} :';
	@override String namedOnDevice({required Object device}) => 'Ces mémoires sont dans la radio de ${device}. Leurs noms et durées appartiennent à cet appareil.';
	@override String get namedOnRadio => 'Enregistré dans la radio, où ses autres clients le voient aussi.';
	@override String get recordHelpYaesuDvs => 'Attendez l\'indicateur [REC] sur la radio, puis maintenez le bouton PTT et enregistrez votre message. Terminez en appuyant sur le bouton ARRÊTER ici dans l\'application avant de relâcher le PTT pour éviter les clics indésirables.';
	@override String get recordHelpFt891 => 'Attendez que l\'indicateur [REC] clignote au moins quatre fois, puis maintenez le bouton PTT et enregistrez votre message. Terminez en appuyant sur le bouton ARRÊTER ici dans l\'application avant de relâcher le PTT pour éviter les clics indésirables.';
	@override String get pill => 'Voix';
	@override String play({required Object n}) => 'Lire la mémoire ${n}';
	@override String get stop => 'Arrêter';
	@override String record({required Object n}) => 'Enregistrer la mémoire ${n}';
	@override String get stopRecording => 'Arrêter l\'enregistrement';
	@override String get playing => 'Lecture…';
	@override String get recording => 'Enregistrement…';
	@override String playingMemory({required Object label}) => 'Lecture de ${label}';
	@override String recordingMemory({required Object label}) => 'Enregistrement de ${label}';
	@override String get doubtful => 'La radio l\'a-t-elle joué ? Elle s\'est déclarée inactive aussitôt.';
	@override String get recordOnRadio => 'Les mémoires doivent être enregistrées sur la radio elle-même.';
}

// Path: settings.radio.avoidZeroBeat
class _Translations$settings$radio$avoidZeroBeat$fr extends Translations$settings$radio$avoidZeroBeat$en {
	_Translations$settings$radio$avoidZeroBeat$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Éviter le battement nul sur les spots';
	@override String get descriptionOn => 'Avec une radio connectée, accord à quelques Hz d\'un spot CW, pour que tous ceux qui répondent n\'appellent pas sur la même note.';
	@override String get descriptionOff => 'Accord exactement sur la fréquence spottée.';
}

// Path: settings.radio.zeroBeatRange
class _Translations$settings$radio$zeroBeatRange$fr extends Translations$settings$radio$zeroBeatRange$en {
	_Translations$settings$radio$zeroBeatRange$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Battement nul : plage d\'évitement';
	@override String get description => 'À quelle distance de la fréquence spottée se placer, de part et d\'autre. Le décalage n\'est jamais proche de zéro — ce serait à nouveau un battement nul.';
}

// Path: settings.map.style
class _Translations$settings$map$style$fr extends Translations$settings$map$style$en {
	_Translations$settings$map$style$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Style de carte';
}

// Path: settings.map.styleOpts
class _Translations$settings$map$styleOpts$fr extends Translations$settings$map$styleOpts$en {
	_Translations$settings$map$styleOpts$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get automatic => 'Automatique';
	@override String get liberty => 'Liberty';
	@override String get bright => 'Bright';
	@override String get positron => 'Positron';
	@override String get voyager => 'Voyager';
	@override String get darkMatter => 'Dark Matter';
}

// Path: settings.privacy.shareAppData
class _Translations$settings$privacy$shareAppData$fr extends Translations$settings$privacy$shareAppData$en {
	_Translations$settings$privacy$shareAppData$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partager les données d\'utilisation de l\'application';
	@override String get descriptionOn => 'Vous nous aidez à améliorer l\'application en partageant des données d\'utilisation, de configuration, de plantage et de performance';
	@override String get descriptionOff => 'Données d\'utilisation de l\'application gardées privées.\nL\'équipe Ham2K ne pourra pas détecter les plantages ni d\'autres problèmes.';
}

// Path: settings.privacy.shareOpData
class _Translations$settings$privacy$shareOpData$fr extends Translations$settings$privacy$shareOpData$en {
	_Translations$settings$privacy$shareOpData$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get title => 'Partager les données d\'opération';
	@override String get descriptionOn => 'Partage public de certaines données d\'opération et avec d\'autres utilisateurs';
	@override String get descriptionOff => 'Données d\'opération gardées privées';
}

// Path: settings.station.models
class _Translations$settings$station$models$fr extends Translations$settings$station$models$en {
	_Translations$settings$station$models$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

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
	@override String get yaesuGeneric => 'Yaesu - Générique';
	@override String get icomGeneric => 'Icom - Générique';
	@override String get kenwoodGeneric => 'Kenwood - Générique';
	@override String get ts590sg => 'Kenwood TS-590SG';
	@override String get ts480 => 'Kenwood TS-480';
	@override String get qmx => 'QRP Labs QMX';
	@override String get fx4cr => 'BG2FX FX-4CR';
	@override String get qcx => 'QRP Labs QCX';
	@override String get elecraftGeneric => 'Elecraft - Générique';
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
	@override String get rigctld => 'Radio pilotée via rigctld';
	@override String get rigctldNodeName => 'Ma radio (via rigctld)';
	@override String get flrig => 'Radio pilotée via flrig';
	@override String get flrigNodeName => 'Ma radio (via flrig)';
	@override String get hrd => 'Radio pilotée via Ham Radio Deluxe®';
	@override String get hrdNodeName => 'Ma radio (via HRD)';
	@override String get n3fjp => 'Radio pilotée via N3FJP';
	@override String get n3fjpNodeName => 'Ma radio (via N3FJP)';
	@override String get commander => 'Radio pilotée via DXLab Commander';
	@override String get commanderNodeName => 'Ma radio (via Commander)';
	@override String get antenna => 'Antenne';
	@override String get key => 'Manipulateur CW';
	@override String get winkeyer => 'WinKeyer';
	@override String get placeholderRadio => 'Radio générique (provisoire)';
	@override String get placeholderRadioNodeName => 'Ma radio';
	@override String get antennaGenius => '4O3A Antenna Genius';
	@override String get sierraCoax => 'Commutateur coaxial Sierra Radio CX-1';
}

// Path: settings.station.transports
class _Translations$settings$station$transports$fr extends Translations$settings$station$transports$en {
	_Translations$settings$station$transports$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get network => 'Réseau/WiFi';
	@override String get usbSerial => 'Série USB';
	@override String get wifi => 'Réseau/WiFi';
	@override String get bluetoothSerial => 'Série Bluetooth';
	@override String get placeholder => 'Provisoire';
}

// Path: settings.station.antennaTypes
class _Translations$settings$station$antennaTypes$fr extends Translations$settings$station$antennaTypes$en {
	_Translations$settings$station$antennaTypes$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get dipole => 'Dipôle';
	@override String get vertical => 'Verticale';
	@override String get yagiBeam => 'Yagi / Beam';
	@override String get loop => 'Boucle';
	@override String get longWire => 'Long fil / EFHW';
	@override String get other => 'Autre';
}

// Path: settings.station.keyTypes
class _Translations$settings$station$keyTypes$fr extends Translations$settings$station$keyTypes$en {
	_Translations$settings$station$keyTypes$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get straight => 'Pioche';
	@override String get sideswiper => 'Sideswiper';
	@override String get bug => 'Bug (semi-automatique mécanique)';
	@override String get fullyAutomatic => 'Manipulateur entièrement automatique';
	@override String get singlePaddle => 'Simple palette';
	@override String get dualPaddle => 'Double palette';
	@override String get computerDriven => 'Piloté par ordinateur';
	@override String get other => 'Autre';
}

// Path: operation.layout.panels.weatherConditions
class _Translations$operation$layout$panels$weatherConditions$fr extends Translations$operation$layout$panels$weatherConditions$en {
	_Translations$operation$layout$panels$weatherConditions$fr._(TranslationsFr root) : this._root = root, super.internal(root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get unknown => 'Inconnu';
	@override String get sunny => 'Ensoleillé';
	@override String get clear => 'Dégagé';
	@override String get mainlySunny => 'Plutôt ensoleillé';
	@override String get mainlyClear => 'Plutôt dégagé';
	@override String get partlyCloudy => 'Partiellement nuageux';
	@override String get cloudy => 'Nuageux';
	@override String get foggy => 'Brouillard';
	@override String get rimeFog => 'Brouillard givrant';
	@override String get lightDrizzle => 'Bruine légère';
	@override String get drizzle => 'Bruine';
	@override String get heavyDrizzle => 'Bruine forte';
	@override String get lightFreezingDrizzle => 'Bruine verglaçante légère';
	@override String get freezingDrizzle => 'Bruine verglaçante';
	@override String get lightRain => 'Pluie légère';
	@override String get rain => 'Pluie';
	@override String get heavyRain => 'Pluie forte';
	@override String get lightFreezingRain => 'Pluie verglaçante légère';
	@override String get freezingRain => 'Pluie verglaçante';
	@override String get lightSnow => 'Neige légère';
	@override String get snow => 'Neige';
	@override String get heavySnow => 'Neige forte';
	@override String get snowGrains => 'Neige en grains';
	@override String get lightShowers => 'Averses légères';
	@override String get showers => 'Averses';
	@override String get heavyShowers => 'Averses fortes';
	@override String get lightSnowShowers => 'Averses de neige légères';
	@override String get snowShowers => 'Averses de neige';
	@override String get thunderstorm => 'Orage';
	@override String get lightThunderstormsWithHail => 'Orages faibles avec grêle';
	@override String get thunderstormWithHail => 'Orage avec grêle';
}

/// The flat map containing all translations for locale <fr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'common.save' => 'Enregistrer',
			'common.ok' => 'OK',
			'common.cancel' => 'Annuler',
			'common.delete' => 'Supprimer',
			'common.create' => 'Créer',
			'common.error' => 'Erreur',
			'common.close' => 'Fermer',
			'common.done' => 'Terminé',
			'common.callsign' => 'Indicatif',
			'common.clear' => 'Effacer',
			'common.dismiss' => 'Ignorer',
			'common.expand' => 'Développer',
			'common.collapse' => 'Réduire',
			'onboarding.welcomeTitle' => 'Bienvenue dans Ham2K Portable Logger !',
			'onboarding.welcomeTitleDesktop' => 'Bienvenue dans Ham2K Power Logger !',
			'onboarding.welcomeBody' => 'Quelques questions pour mieux adapter l\'application à vos besoins.',
			'onboarding.skip' => 'Passer',
			'onboarding.kContinue' => 'Continuer',
			'onboarding.back' => 'Retour',
			'onboarding.next' => 'Suivant',
			'onboarding.done' => 'Terminé',
			'onboarding.callsignTitle' => 'Quel est votre indicatif ?',
			'onboarding.callsignBody' => 'Cette application n\'est utile qu\'avec une licence de radioamateur',
			'onboarding.callsignLabel' => 'Indicatif de l\'opérateur',
			'onboarding.alreadyHaveAccount' => 'Vous avez déjà un compte ?',
			'onboarding.foundSiblingTitle' => 'Lier un compte existant ?',
			'onboarding.foundSiblingBody' => ({required Object app}) => '${app} est installé sur cet appareil. Liez cette application au même compte pour récupérer votre indicatif et vos journaux.',
			'onboarding.foundPoloBody' => 'Une ancienne version de Ham2K Portable Logger est installée sur cet appareil. Liez cette application au même compte pour récupérer votre indicatif et vos journaux.',
			'onboarding.foundSiblingsBody' => 'D\'autres applications Ham2K sont installées sur cet appareil. Liez cette application à l\'un de leurs comptes pour récupérer votre indicatif et vos journaux.',
			'onboarding.linkWithApp' => ({required Object app}) => 'Lier avec ${app}',
			'onboarding.linkWithPolo' => 'Lier avec le compte de l\'ancienne version',
			'onboarding.setUpFresh' => 'Repartir de zéro',
			'onboarding.activitiesTitle' => 'Activités favorites',
			'onboarding.activitiesBody' => 'Ces programmes d\'activation populaires vous intéressent-ils ?',
			'onboarding.activitiesFooter' => '(Vous trouverez plus d\'options dans les Paramètres)',
			'onboarding.activityPota' => 'Parks On The Air',
			'onboarding.activitySota' => 'Summits On The Air',
			'onboarding.activityWwff' => 'World Wide Flora & Fauna',
			'onboarding.consentTitle' => 'Données et confidentialité',
			'onboarding.consentUsageBody' => 'Pour nous aider à améliorer l\'application, nous aimerions collecter des données de performance, de plantage et d\'utilisation.',
			'onboarding.consentUsageLabel' => 'Partager les données d\'utilisation de l\'application',
			'onboarding.consentOperationBody' => 'Certaines fonctionnalités peuvent partager vos données d\'opération avec d\'autres utilisateurs. Vous pouvez refuser à tout moment.',
			'onboarding.consentOperationLabel' => 'Partager les données d\'opération',
			'onboarding.finishingSetup' => 'Fin de la configuration — téléchargement des données de référence…',
			'startScreen.credits' => 'par KI2D et amis',
			'testerOverlay.tape' => 'ATTENTION : TRAVAUX EN COURS',
			'testerOverlay.warningTitle' => 'Cette application est en cours de développement',
			'testerOverlay.warningBody' => 'La plupart des fonctionnalités ont des surfaces inégales et il y a des obstacles partout. Pensez à vérifier régulièrement les mises à jour.',
			'testerOverlay.whatsNew' => ({required Object build}) => 'Nouveautés de la version ${build}',
			'testerOverlay.thanks' => 'Merci de mettre votre journal en danger pour nous aider à améliorer cette application !',
			'extensionsPanel.categoryActivity' => 'Activités',
			'extensionsPanel.categoryContest' => 'Concours',
			'extensionsPanel.categoryLookup' => 'Recherches d\'indicatifs',
			'extensionsPanel.categorySpots' => 'Sources de spots',
			'extensionsPanel.categoryDashboard' => 'Panneaux du tableau de bord',
			'extensionsPanel.categoryOther' => 'Autres extensions',
			'extensionsPanel.searchHint' => 'Rechercher des extensions',
			'extensionsPanel.applying' => 'Activation des modifications d\'extensions, cela peut prendre un moment…',
			'extensionsPanel.noMatches' => 'Aucune extension ne correspond à votre recherche',
			'extensionsPanel.installFromFile' => 'Installer depuis un fichier…',
			'extensionsPanel.installVersion' => ({required Object version}) => 'Version ${version}',
			'extensionsPanel.canReach' => 'Cette extension peut contacter',
			'extensionsPanel.canHoldConnection' => ({required Object host}) => '${host}, via une connexion permanente',
			'extensionsPanel.canHoldLocalConnection' => 'Les appareils de votre réseau local, via une connexion permanente',
			'extensionsPanel.canUseLocation' => 'Votre position',
			'extensionsPanel.canReadRadio' => 'Votre radio, pour lire sa fréquence et son mode',
			'extensionsPanel.canControlRadio' => 'Votre radio, pour la piloter et émettre avec — accord, puissance, CW, mémoires vocales et PTT',
			'extensionsPanel.canSetUserAgent' => 'S\'identifier auprès des serveurs sous son propre nom',
			'extensionsPanel.noCapabilities' => 'Elle ne demande rien en dehors de l\'application.',
			'extensionsPanel.sandboxNote' => 'Les extensions s\'exécutent dans un bac à sable : aucun accès à vos fichiers, et aucun accès réseau au-delà de ce qui est listé ici.',
			'extensionsPanel.installAction' => 'Installer',
			'extensionsPanel.updateAction' => 'Mettre à jour',
			'extensionsPanel.installFailed' => 'Impossible d\'installer cette extension',
			'extensionsPanel.installedBadge' => 'Installée',
			'extensionsPanel.uninstallAction' => 'Retirer',
			'extensionsPanel.uninstallTitle' => ({required Object name}) => 'Retirer ${name} ?',
			'extensionsPanel.uninstallBody' => 'Cette extension et ses paramètres seront retirés. Vos journaux ne seront pas modifiés.',
			'extensionsPanel.installedMessage' => ({required Object name}) => '${name} installée',
			'extensionsPanel.installDownloading' => 'Téléchargement…',
			'extensionsPanel.installWaiting' => 'En attente d\'installation…',
			'extensionsPanel.installInstalling' => 'Installation…',
			'extensionsPanel.installAwaitingApproval' => 'En attente de votre accord…',
			'extensionsPanel.installAlreadyRunning' => ({required Object name}) => '${name} est déjà en cours d\'installation.',
			'extensionsPanel.updatedTo' => ({required Object version}) => 'Mise à jour vers ${version}',
			'extensionsPanel.installIncomplete' => ({required Object name}) => 'L\'installation de ${name} n\'a pas abouti. Il faudra peut-être la réinstaller.',
			'extensionsPanel.uninstallFailed' => ({required Object name}) => 'Impossible de retirer ${name}',
			'extensionsPanel.installedFrom' => ({required Object source}) => 'Téléchargée depuis ${source}',
			'extensionsPanel.dropHint' => 'Déposez une extension .h2kext pour l\'installer',
			'extensionsPanel.dropOneOnly' => 'Déposez une seule extension à la fois.',
			'extensionsPanel.downloadFailed' => ({required Object source, required Object status}) => '${source} a renvoyé ${status} pour cette extension.',
			'extensionsPanel.downloadTooLarge' => 'Ce téléchargement est bien trop volumineux pour être une extension.',
			'extensionsPanel.downloadNotSecure' => 'Ce téléchargement a été redirigé vers une adresse non sécurisée.',
			'extensionsPanel.catalogSection' => 'Catalogue',
			'extensionsPanel.catalogLoading' => 'Chargement du catalogue…',
			'extensionsPanel.catalogUnreachable' => 'Catalogue injoignable',
			'extensionsPanel.builtIn' => 'Intégrée',
			'extensionsPanel.updateAvailableBadge' => 'Mise à jour disponible',
			'extensionsPanel.updatesAvailableTitle' => 'Mises à jour d\'extensions',
			'extensionsPanel.updateAvailableFor' => ({required Object name}) => 'Une mise à jour est disponible pour ${name}.',
			'extensionsPanel.updatesAvailable' => ({required Object names, required Object count}) => '${names} et ${count} autres doivent être mises à jour.',
			'extensionsPanel.updatesAvailableFor' => ({required Object names}) => '${names} doivent être mises à jour.',
			'extensionsPanel.pendingUpdatesSection' => 'Mises à jour en attente',
			'extensionsPanel.updateAllAction' => 'Tout mettre à jour',
			'extensionsPanel.updatesUnderWay' => 'Ces mises à jour sont déjà en cours.',
			'extensionsPanel.updatesNothingLeft' => 'Vos extensions sont à jour.',
			'extensionsPanel.updatesNoticeAction' => 'Plus d\'infos',
			'extensionsPanel.updateAllTitle' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Mettre à jour ${count} extension ?', other: 'Mettre à jour ${count} extensions ?', ), 
			'extensionsPanel.upgradeDoneTitle' => 'Vos extensions sont prêtes',
			'extensionsPanel.upgradeDoneBody' => 'Elles proviennent désormais du catalogue d\'extensions Ham2K, et peuvent donc être mises à jour sans attendre une nouvelle version de l\'application.',
			'extensionsPanel.upgradeDoneUnserved' => ({required Object names}) => 'Non migrées : ${names}.',
			'extensionsPanel.upgradeDoneRefused' => ({required Object names}) => 'Refus de démarrer : ${names}.',
			'extensionsPanel.upgradeDoneRefusedHint' => 'Elles sont toujours installées et signalées dans Paramètres › Extensions — les y mettre à jour les rétablira.',
			'extensionsPanel.upgradeDoneUnservedHint' => 'Le catalogue n\'a pas de remplacement direct pour celles-ci : cherchez-y des extensions qui couvrent ce que vous utilisiez.',
			'extensionsPanel.retiredQp' => 'QSO Parties',
			'extensionsPanel.retiredStateparks' => 'Événements State Parks',
			'extensionsPanel.upgradeDoneMissing' => ({required Object count}) => '${count} de vos extensions ne sont pas encore arrivées. Elles seront téléchargées dès que le catalogue d\'extensions sera joignable.',
			'extensionsPanel.runtimeDeadBody' => 'Vos extensions n\'ont pas démarré. Redémarrer l\'application devrait les rétablir.',
			'extensionsPanel.refusedTitle' => 'Certaines extensions n\'ont pas démarré',
			'extensionsPanel.upgradeBusyTitle' => 'Configuration en cours',
			'extensionsPanel.upgradeRuntimeDeadTitle' => 'Vos extensions ne fonctionnent pas',
			'extensionsPanel.restoreTitle' => 'Certaines de vos extensions manquent',
			'extensionsPanel.restoreBody' => 'Ces extensions que vous avez installées ne sont pas sur cet appareil. Nous pouvons les télécharger à nouveau depuis le catalogue d\'extensions Ham2K :',
			'extensionsPanel.restoreFromFile' => 'Installées depuis un fichier. Réinstallez-les depuis leurs fichiers, ou oubliez-les :',
			'extensionsPanel.restoreOtherCatalog' => 'Installées depuis un autre catalogue d\'extensions, elles ne sont donc pas disponibles ici :',
			'extensionsPanel.restoreForget' => 'Oublier',
			'extensionsPanel.restoreInstall' => 'Installer',
			'extensionsPanel.restoreLater' => 'Plus tard',
			'extensionsPanel.restoreInstalling' => 'Installation de vos extensions…',
			'extensionsPanel.restoreDoneTitle' => 'Vos extensions sont de retour',
			'extensionsPanel.restoreDoneBody' => ({required Object names}) => 'Réinstallées : ${names}.',
			'extensionsPanel.restorePartialTitle' => 'Certaines extensions n\'ont pas pu être installées',
			'extensionsPanel.restoreFailed' => ({required Object names}) => 'Installation impossible : ${names}. Nous vous les proposerons à nouveau à la prochaine ouverture de l\'application.',
			'extensionsPanel.restoreBusyBody' => 'L\'application configure encore vos extensions. Nous vous les proposerons à nouveau à la prochaine ouverture de l\'application.',
			'extensionsPanel.restoreRuntimeDeadBody' => 'Nous les avons réinstallées, mais vos extensions n\'ont pas démarré. Redémarrer l\'application devrait les rétablir.',
			'extensionsPanel.revokedTitle' => ({required Object name}) => '${name} a été retirée',
			'extensionsPanel.revokedBody' => 'Le catalogue a retiré cette version, elle a donc été désactivée.',
			'extensionsPanel.downloadHashMismatch' => 'Ce téléchargement n\'est pas l\'extension décrite par le catalogue.',
			'extensionsPanel.catalogVersionUnknown' => ({required Object version, required Object key}) => 'Le catalogue n\'a pas de version ${version} de ${key}.',
			'extensionsPanel.catalogLinkUnknown' => 'Ce lien de catalogue ne désigne aucune version d\'extension.',
			'extensionsPanel.catalogNoRelease' => ({required Object key}) => 'Le catalogue n\'a aucune version de ${key} sur cette piste.',
			'extensionsPanel.installFromLink' => 'Installer depuis un lien',
			'extensionsPanel.unstableReleaseWarning' => 'Ceci est une version instable, que son éditeur ne considère pas comme terminée. Elle peut mal se comporter et continuera de recevoir des mises à jour instables.',
			'extensionsPanel.bleedingReleaseWarning' => 'Ceci est une version à la pointe : un travail en cours qui peut casser ou perdre ses paramètres. Elle continuera de recevoir des mises à jour à la pointe.',
			'extensionsPanel.channelUnstable' => 'Instable',
			'extensionsPanel.channelBleeding' => 'À la pointe',
			'extensionsPanel.followsUnstable' => 'Reçoit les versions instables et stables',
			'extensionsPanel.followsBleeding' => 'Reçoit les versions à la pointe, instables et stables',
			'extensionsPanel.followStableAction' => 'Suivre uniquement les versions stables',
			'extensionsPanel.revokedBadge' => 'Retirée',
			'extensionsPanel.refusedBadge' => 'Non chargée',
			'extensionsPanel.downloadNotHttps' => 'Ce téléchargement n\'utilise pas une connexion sécurisée.',
			'extensionsPanel.downloadUnreachable' => ({required Object source}) => '${source} est injoignable pour cette extension.',
			'extensionsPanel.detailsAction' => 'Détails',
			'extensionsPanel.installedFromFile' => 'Installée depuis un fichier',
			'extensionsPanel.detailsWhatItDoes' => 'Prend en charge',
			'extensionsPanel.installedPreloaded' => 'Préinstallée',
			'extensionsPanel.hookAccount' => 'Connexion au compte',
			'extensionsPanel.hookCallNotes' => 'Notes d\'indicatif',
			'extensionsPanel.hookDataFile' => 'Données hors ligne',
			'extensionsPanel.hookExport' => 'Export',
			'extensionsPanel.hookLookup' => 'Recherches d\'indicatifs',
			'extensionsPanel.hookScoring' => 'Calcul du score',
			'extensionsPanel.hookSpots' => 'Spots',
			'extensionsPanel.hookHunting' => ({required Object program}) => 'Chasse ${program}',
			'extensionsPanel.hookActivating' => ({required Object program}) => 'Activation ${program}',
			'extensionsPanel.moreInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '… et ${count} autre extension', other: '… et ${count} autres extensions', ), 
			'extensionsPanel.availableInCategory' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} extension disponible', other: '${count} extensions disponibles', ), 
			'home.title' => 'Logger portable',
			'home.newOperation' => 'Nouvelle opération',
			'home.stationCallsign' => 'Indicatif de la station',
			'home.titleOptional' => 'Titre (facultatif)',
			'home.emptyList' => 'Aucune opération pour l\'instant. Créez-en une pour commencer à journaliser.',
			'home.quickLookup' => 'Recherche rapide',
			'home.nav.operations' => 'Opérations',
			'home.nav.chase' => 'Chasse',
			'home.nav.logs' => 'Journaux',
			'home.nav.maps' => 'Cartes',
			'home.nav.settings' => 'Paramètres',
			'home.panels.operations' => 'Liste d\'opérations',
			'home.panels.operationsDescription' => 'Vos opérations, les plus récentes en premier.',
			'home.panels.version' => 'Version actuelle',
			'home.panels.versionDescription' => 'Le logo Ham2K, le nom de cette application et la version que vous utilisez.',
			'home.toggleNav' => 'Afficher ou masquer les libellés de navigation',
			'home.logs.title' => 'Journaux',
			'home.logs.titleFor' => 'Journaux pour',
			'home.logs.emptyCallsigns' => 'Aucun QSO enregistré pour l\'instant',
			'home.logs.emptyQsos' => ({required Object call}) => 'Aucun QSO pour ${call}',
			'home.logs.mapNoSelection' => 'Sélectionnez un QSO pour le voir sur la carte',
			'home.logs.searchHint' => 'Rechercher un indicatif ou un nom',
			'home.logs.noSearchMatches' => 'Aucun QSO ne correspond à votre recherche',
			'home.logs.titleAll' => 'Tous les journaux',
			'home.logs.allCallsigns' => 'Tous les indicatifs',
			'home.logs.noOperation' => 'Hors opération',
			'home.logs.unsavedTitle' => 'Modifications non enregistrées',
			'home.logs.unsavedBody' => 'Ce QSO contient des modifications que vous n\'avez pas enregistrées.',
			'home.logs.pendingDeleteBody' => 'Ce QSO est marqué pour suppression.',
			'home.logs.editGone' => 'Non enregistré : ce QSO ne fait plus partie de ce journal.',
			'home.logs.discard' => 'Abandonner',
			'home.logs.columns.date' => 'Date',
			'home.logs.columns.time' => 'Heure',
			'home.logs.columns.freq' => 'Fréquence',
			'home.logs.columns.mode' => 'Mode',
			'home.logs.columns.call' => 'Indicatif',
			'home.logs.columns.name' => 'Nom',
			'home.logs.columns.station' => 'Station',
			'home.logs.columns.band' => 'Bande',
			'home.logs.columns.sent' => 'Envoyé',
			'home.logs.columns.rcvd' => 'Reçu',
			'home.logs.columns.grid' => 'Grille',
			'home.logs.columns.state' => 'État',
			'home.logs.columns.country' => 'Pays',
			'home.logs.columns.refs' => 'Réfs',
			'home.logs.panels.qsos' => 'Journal des QSOs',
			'home.logs.panels.qsosDescription' => 'Les QSOs de l\'indicatif sélectionné, toutes opérations confondues.',
			'home.logs.panels.info' => 'Infos',
			'home.logs.panels.infoDescription' => 'Le nombre total de QSOs, ou la recherche d\'indicatif du QSO sélectionné.',
			'home.logs.panels.map' => 'Carte',
			'home.logs.panels.mapDescription' => 'La position du QSO sélectionné.',
			'home.logs.import.callsigns' => ({required Object calls}) => 'Indicatifs : ${calls}',
			'home.logs.import.skippedOne' => '1 enregistrement n\'a pas pu être lu',
			'home.logs.import.skippedOther' => ({required Object count}) => '${count} enregistrements n\'ont pas pu être lus',
			'home.logs.import.readingTitle' => 'Lecture du fichier ADIF…',
			'home.logs.import.checkingTitle' => 'Recherche des doublons…',
			'home.logs.import.importingTitle' => 'Importation des QSOs…',
			'home.logs.import.readingDetail' => ({required Object kb}) => '${kb} Ko',
			'home.logs.import.checkingDetail' => ({required Object done, required Object total}) => '${done} sur ${total} vérifiés',
			'home.logs.import.importingDetail' => ({required Object imported, required Object total}) => '${imported} importés sur ${total}',
			'chase.operatorPrefix' => 'op',
			'chase.chasing' => 'chasse',
			'chase.goalsTwo' => ({required Object first, required Object second}) => '${first} et ${second}',
			'chase.goalsMore' => ({required Object first, required Object second}) => '${first}, ${second} et plus',
			'chase.station.title' => 'Station de chasse',
			'chase.station.stationLabel' => 'Station : ',
			'chase.station.operatorLabel' => 'Op : ',
			'chase.station.noLocation' => 'Aucun emplacement',
			'chase.periodInline.today' => 'aujourd\'hui',
			'chase.periodInline.thisWeek' => 'cette semaine',
			'chase.periodInline.last14Days' => 'ces 14 derniers jours',
			'chase.periodInline.thisMonth' => 'ce mois-ci',
			'chase.periodStats.today' => 'Statistiques du jour',
			'chase.periodStats.thisWeek' => 'Statistiques de la semaine',
			'chase.periodStats.last14Days' => 'Statistiques des 14 derniers jours',
			'chase.periodStats.thisMonth' => 'Statistiques du mois',
			'chase.period.today' => 'Aujourd\'hui',
			'chase.period.thisWeek' => 'Cette semaine',
			'chase.period.last14Days' => '14 derniers jours',
			'chase.period.thisMonth' => 'Ce mois-ci',
			'chase.goals.title' => 'Objectifs de chasse',
			'chase.goals.remove' => ({required Object name}) => 'Arrêter de chasser ${name}',
			'chase.goals.extensionsTitle' => 'Extensions qui incluent la chasse',
			'chase.panels.logging' => 'QSOs',
			'chase.panels.loggingDescription' => 'Les contrôles de saisie au-dessus des QSOs chassés sur la période.',
			'chase.panels.info' => 'Infos',
			'chase.panels.infoDescription' => 'L\'indicatif en cours de saisie, ou les statistiques de la période.',
			'chase.panels.spots' => 'Spots',
			'chase.panels.spotsDescription' => 'Les stations spottées en l\'air, prêtes à être chassées.',
			'chase.panels.map' => 'Carte',
			'chase.panels.mapDescription' => 'Les QSOs de la période et la station en cours de saisie.',
			'dialogs.operationDetails' => 'Détails de l\'opération',
			'dialogs.activities' => 'Activités',
			'dialogs.stationCallsign' => 'Indicatif de la station',
			'dialogs.multiStationIdentifier' => 'Identifiant multi-station (uniquement des chiffres)',
			'dialogs.notes' => 'Notes',
			'dialogs.deleteOperationTitle' => 'Supprimer l\'opération',
			'dialogs.purgeTestsTitle' => 'Purger les opérations de test',
			'dialogs.purgeTestsBody' => 'Cela supprime définitivement ces opérations de test et leurs QSOs. Cette action est irréversible.',
			'dialogs.purgeTestsLooseQsos' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Plus ${count} contact de test qui n\'appartient à aucune opération.', other: 'Plus ${count} contacts de test qui n\'appartiennent à aucune opération.', ), 
			'dialogs.purgeTestsAction' => 'Purger',
			'dialogs.syncAllTitle' => 'Remplacer le journal de cet appareil ?',
			'dialogs.syncAllBody' => ({required Object qsos}) => 'SYNCALL sauvegarde puis efface ${qsos} de cet appareil, puis télécharge à nouveau le journal du compte depuis le serveur. La sauvegarde reste dans la base de données de cet appareil.',
			'dialogs.syncAllUnsynced' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${n} QSO n\'a pas encore été synchronisé — le serveur ne l\'a jamais reçu, et il NE reviendra PAS.', other: '${n} QSOs n\'ont pas encore été synchronisés — le serveur ne les a jamais reçus, et ils NE reviendront PAS.', ), 
			'dialogs.syncAllAction' => 'Effacer et resynchroniser',
			'dialogs.receivedPurgesTitle' => 'Opérations de test supprimées ailleurs',
			'dialogs.receivedPurgesBody' => 'Celles-ci ont été supprimées comme opérations de test sur un autre appareil. Les supprimer ici aussi ? Cela les supprime définitivement avec leurs QSOs, et c\'est irréversible.',
			'dialogs.receivedPurgesAction' => 'Supprimer',
			'dialogs.callChange.invalidCallsign' => ({required Object call}) => 'Indicatif invalide : ${call}',
			'dialogs.callChange.invalidCallsigns' => ({required Object calls}) => 'Indicatifs invalides : ${calls}',
			'dialogs.callChange.operatorSoFar' => ({required Object previous, required Object typed}) => '${previous} a opéré jusqu\'à présent. ${typed} sera enregistré pour les nouveaux contacts.',
			'dialogs.callChange.operatorNoneSoFar' => ({required Object typed}) => 'Aucun opérateur enregistré jusqu\'à présent. ${typed} sera enregistré pour les nouveaux contacts.',
			'dialogs.callChange.operatorSeveral' => ({required Object calls, required Object typed}) => 'Cette opération contient déjà des contacts par ${calls}. ${typed} ne sera enregistré que pour les nouveaux.',
			'dialogs.callChange.operatorRestamp' => ({required num count, required Object typed}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Enregistrer aussi ${typed} comme opérateur du contact déjà saisi', other: 'Enregistrer aussi ${typed} comme opérateur des ${count} contacts déjà saisis', ), 
			'dialogs.callChange.operatorSeveralStations' => 'Avec plusieurs indicatifs de station en l\'air, les opérateurs distincts ne sont pas pris en charge',
			'dialogs.callChange.contactsUnreadable' => 'Les contacts de cette opération n\'ont pas pu être lus : changer un indicatif ici ne proposera pas de les mettre à jour',
			'dialogs.callChange.restampFailed' => ({required Object error}) => 'Les contacts déjà saisis n\'ont pas pu être mis à jour, aucune modification n\'a donc été faite : ${error}',
			'dialogs.callChange.restampShortfall' => ({required Object written, required Object planned}) => '${written} contacts sur ${planned} ont été mis à jour — les autres ne font plus partie de cette opération',
			'operation.deletedReadOnly' => 'Cette opération est supprimée. Restaurez-la pour saisir des QSOs ou la modifier.',
			'operation.tabs.qsos' => ({required Object count}) => '${count} QSOs',
			'operation.tabs.info' => 'INFOS',
			'operation.tabs.spots' => 'SPOTS',
			'operation.tabs.map' => 'CARTE',
			'operation.tabs.qsosPlain' => 'QSOs',
			'operation.tabs.clock' => 'Horloge',
			'operation.tabs.weather' => 'Météo',
			'operation.tabs.website' => 'Site web',
			'operation.tabs.remoteScreen' => 'Écran distant',
			'operation.tabs.solar' => 'Solaire',
			'operation.tabs.radio' => 'Radio',
			'operation.positions.nobodyYet' => 'Aucune autre position d\'opération ne partage encore cette opération.',
			'operation.positions.positionLabel' => ({required Object number}) => 'Pos : ${number}',
			'operation.positions.operatorLabel' => ({required Object call}) => 'Op : ${call}',
			'operation.positions.unnamedPosition' => 'Une autre position',
			'operation.positions.thisDevice' => 'Notre position d\'opération',
			'operation.positions.nameIn' => ' à ',
			'operation.positions.panelTitle' => 'Positions',
			'operation.positions.panelDescription' => 'Ce que chaque position d\'opération partageant cette opération saisit en ce moment.',
			'operation.stationCallsignNone' => 'Aucun indicatif de station',
			'operation.titleNone' => 'Sans titre',
			'operation.deleteOperation' => 'Supprimer l\'opération',
			'operation.loggingControlsStale' => 'Les champs d\'activité ne sont peut-être pas à jour — rouvrez l\'opération pour les actualiser',
			'operation.locationNone' => 'Non défini',
			'operation.generalOperation' => 'Opération générale',
			'operation.titleFor' => ({required Object value}) => 'pour ${value}',
			'operation.titleAt' => ({required Object value}) => 'à ${value}',
			'operation.segmentNow' => ({required Object description}) => 'Maintenant ${description}',
			'operation.testOperationSuffix' => 'Test',
			'operation.menu.showRstFields' => 'Afficher les champs RST',
			'operation.menu.showStateField' => 'Afficher le champ État',
			'operation.menu.showGridField' => 'Afficher le champ Grille',
			'operation.menu.showDeletedQsos' => 'Afficher les QSOs supprimés',
			'operation.menu.showDeletedOps' => 'Afficher les opérations supprimées',
			'operation.menu.showQsoNumbers' => 'Afficher les numéros de QSO',
			'operation.menu.lookupAllQsos' => 'Rechercher tous les QSOs',
			'operation.menu.loggingSettingsTitle' => 'Paramètres de saisie',
			'operation.menu.mapSettingsTitle' => 'Paramètres de la carte',
			'operation.menu.actionsSection' => 'Actions',
			'operation.layout.title' => 'Ajouter un panneau',
			'operation.layout.availableSection' => 'Panneaux disponibles',
			'operation.layout.panelSettings' => ({required Object panel}) => 'Paramètres de ${panel}',
			'operation.layout.panelSettingsAction' => 'Paramètres du panneau',
			'operation.layout.viewName' => 'Vue d\'opération',
			'operation.layout.viewOptions' => 'Options de disposition de la vue',
			'operation.layout.viewTitleBuiltIn' => 'Cette vue est intégrée à l\'application, tout comme son nom',
			'operation.layout.resetOptions' => 'Rétablir les valeurs par défaut',
			'operation.layout.removePane' => 'Retirer',
			'operation.layout.resetPaneConfirm' => ({required Object panel}) => 'Rétablir ${panel} à ses valeurs par défaut ?',
			'operation.layout.resetPaneConfirmBody' => 'Son titre, son en-tête et sa taille reviennent aux valeurs par défaut. Le reste de la disposition ne change pas.',
			'operation.layout.resetViewConfirm' => 'Rétablir la disposition par défaut de cette vue ?',
			'operation.layout.resetViewConfirmBody' => 'Les panneaux reprennent leur disposition par défaut, et les options de la vue et de chaque panneau reviennent aux valeurs par défaut.',
			'operation.layout.paneOptionsTitle' => ({required Object panel}) => 'Paramètres de disposition de ${panel}',
			'operation.layout.paneTitle' => 'Titre',
			'operation.layout.paneShowHeader' => 'Afficher l\'en-tête',
			'operation.layout.paneShowHeaderTabset' => 'Toujours affiché tant que ce volet partage un groupe — l\'en-tête permet d\'accéder aux autres',
			'operation.layout.paneInherit' => 'Comme l\'application',
			'operation.layout.searchHint' => 'Rechercher des panneaux',
			'operation.layout.noPanelsMatch' => 'Aucun panneau ne correspond à votre recherche.',
			'operation.layout.nothingToAdd' => 'Cette vue contient déjà tous les panneaux possibles',
			'operation.layout.addPanel' => ({required Object panel}) => 'Ajouter ${panel}',
			'operation.layout.showPreview' => ({required Object panel}) => 'Aperçu de ${panel}',
			'operation.layout.missingExtension' => ({required Object name}) => 'L\'extension « ${name} » est manquante',
			'operation.layout.previewUnavailable' => 'L\'aperçu de ce panneau n\'a pas pu être affiché.',
			'operation.layout.nestedPaneTitle' => 'Plus',
			'operation.layout.editLayout' => 'Modifier la disposition',
			'operation.layout.saveLayout' => 'Enregistrer la disposition',
			'operation.layout.revertLayout' => 'Abandonner les modifications de disposition',
			'operation.layout.done' => 'Terminé',
			'operation.layout.layoutUnreadableTitle' => 'Disposition illisible',
			'operation.layout.layoutUnreadableBody' => 'Votre disposition enregistrée n\'a pas pu être lue, la disposition par défaut est donc affichée à la place. Elle ne remplacera votre original que si vous choisissez de la conserver.',
			'operation.layout.layoutUnreadableAction' => 'Utiliser cette disposition',
			'operation.layout.panelRenderFailed' => ({required Object panel}) => '${panel} n\'a pas pu être affiché',
			'operation.layout.panelRenderRetry' => 'Réessayer',
			'operation.layout.panelActionFailed' => 'L\'action du panneau a échoué. Réessayez.',
			'operation.layout.panels.loggingDescription' => 'Le journal et les champs de saisie',
			'operation.layout.panels.infoDescription' => 'Ce que nous savons de la station contactée',
			'operation.layout.panels.spotsDescription' => 'Les spots des clusters et des programmes d\'activité',
			'operation.layout.panels.mapDescription' => 'L\'emplacement des contacts',
			'operation.layout.panels.clockDescription' => 'Une horloge, dans n\'importe quel fuseau horaire',
			'operation.layout.panels.clockFace' => 'Cadran',
			'operation.layout.panels.clockFaceLcd' => 'LCD',
			'operation.layout.panels.clockFaceAnalog' => 'Analogique',
			'operation.layout.panels.clockZone' => 'Fuseau horaire',
			'operation.layout.panels.clockZoneUtc' => 'UTC',
			'operation.layout.panels.clockZoneDevice' => 'Cet appareil',
			'operation.layout.panels.clockShowSeconds' => 'Afficher les secondes',
			'operation.layout.panels.weatherDescription' => 'Les conditions actuelles et des huit prochaines heures, là où vous opérez',
			'operation.layout.panels.weatherUseOperationLocation' => 'Utiliser l\'emplacement de l\'opération',
			'operation.layout.panels.weatherLocation' => 'Emplacement',
			'operation.layout.panels.weatherLocationDescription' => 'Un carré locator (FN31pr) ou lat,lon. Ignoré tant que « Utiliser l\'emplacement de l\'opération » est coché.',
			'operation.layout.panels.weatherNoLocation' => 'Aucun emplacement défini. Donnez un emplacement à ce panneau dans ses paramètres, ou placez-le dans une opération qui en a un.',
			'operation.layout.panels.weatherBadLocation' => ({required Object location}) => 'Impossible de lire l\'emplacement ${location}. Utilisez un carré locator comme FN31pr, ou 42.36,-71.06.',
			'operation.layout.panels.weatherUnreachable' => 'Open-Meteo est injoignable — pas de réseau ? Nouvel essai sous peu.',
			'operation.layout.panels.weatherUnreadable' => 'Open-Meteo a répondu, mais rien de lisible. Nouvel essai sous peu.',
			'operation.layout.panels.weatherGusts' => ({required Object speed}) => 'rafales ${speed}',
			'operation.layout.panels.panelAgeNow' => 'à l\'instant',
			'operation.layout.panels.panelAgeMinutes' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'il y a ${count} min', other: 'il y a ${count} min', ), 
			'operation.layout.panels.panelAgeHours' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'il y a ${count} h', other: 'il y a ${count} h', ), 
			'operation.layout.panels.weatherConditions.unknown' => 'Inconnu',
			'operation.layout.panels.weatherConditions.sunny' => 'Ensoleillé',
			'operation.layout.panels.weatherConditions.clear' => 'Dégagé',
			'operation.layout.panels.weatherConditions.mainlySunny' => 'Plutôt ensoleillé',
			'operation.layout.panels.weatherConditions.mainlyClear' => 'Plutôt dégagé',
			'operation.layout.panels.weatherConditions.partlyCloudy' => 'Partiellement nuageux',
			'operation.layout.panels.weatherConditions.cloudy' => 'Nuageux',
			'operation.layout.panels.weatherConditions.foggy' => 'Brouillard',
			'operation.layout.panels.weatherConditions.rimeFog' => 'Brouillard givrant',
			'operation.layout.panels.weatherConditions.lightDrizzle' => 'Bruine légère',
			'operation.layout.panels.weatherConditions.drizzle' => 'Bruine',
			'operation.layout.panels.weatherConditions.heavyDrizzle' => 'Bruine forte',
			'operation.layout.panels.weatherConditions.lightFreezingDrizzle' => 'Bruine verglaçante légère',
			'operation.layout.panels.weatherConditions.freezingDrizzle' => 'Bruine verglaçante',
			'operation.layout.panels.weatherConditions.lightRain' => 'Pluie légère',
			'operation.layout.panels.weatherConditions.rain' => 'Pluie',
			'operation.layout.panels.weatherConditions.heavyRain' => 'Pluie forte',
			'operation.layout.panels.weatherConditions.lightFreezingRain' => 'Pluie verglaçante légère',
			'operation.layout.panels.weatherConditions.freezingRain' => 'Pluie verglaçante',
			'operation.layout.panels.weatherConditions.lightSnow' => 'Neige légère',
			'operation.layout.panels.weatherConditions.snow' => 'Neige',
			'operation.layout.panels.weatherConditions.heavySnow' => 'Neige forte',
			'operation.layout.panels.weatherConditions.snowGrains' => 'Neige en grains',
			'operation.layout.panels.weatherConditions.lightShowers' => 'Averses légères',
			'operation.layout.panels.weatherConditions.showers' => 'Averses',
			'operation.layout.panels.weatherConditions.heavyShowers' => 'Averses fortes',
			'operation.layout.panels.weatherConditions.lightSnowShowers' => 'Averses de neige légères',
			'operation.layout.panels.weatherConditions.snowShowers' => 'Averses de neige',
			'operation.layout.panels.weatherConditions.thunderstorm' => 'Orage',
			'operation.layout.panels.weatherConditions.lightThunderstormsWithHail' => 'Orages faibles avec grêle',
			'operation.layout.panels.weatherConditions.thunderstormWithHail' => 'Orage avec grêle',
			'operation.layout.panels.websiteDescription' => 'Une page web de votre choix, dans un volet',
			'operation.layout.panels.websiteUrl' => 'Adresse',
			'operation.layout.panels.websiteRefresh' => 'Actualisation',
			'operation.layout.panels.websiteRefreshNever' => 'Jamais',
			'operation.layout.panels.websiteRefresh1' => 'Toutes les minutes',
			'operation.layout.panels.websiteRefresh5' => 'Toutes les 5 minutes',
			'operation.layout.panels.websiteRefresh15' => 'Toutes les 15 minutes',
			'operation.layout.panels.websiteTitle' => 'Nom du panneau',
			'operation.layout.panels.websiteRefreshNow' => 'Rafraîchir maintenant',
			'operation.layout.panels.websiteNoUrl' => 'Aucune adresse pour l\'instant. Ouvrez les paramètres de ce panneau pour choisir une page.',
			'operation.layout.panels.websiteBadUrl' => 'Cela ne ressemble pas à une adresse web. Elle doit commencer par https://',
			'operation.layout.panels.websiteNotHttps' => 'Seules les adresses https:// peuvent être affichées ici.',
			'operation.layout.panels.websiteUnsupported' => 'Les pages web ne peuvent pas être affichées dans un panneau sur ce système.',
			'operation.layout.panels.websiteOpenExternally' => 'Ouvrir dans le navigateur',
			'operation.layout.panels.websiteLoadFailed' => ({required Object reason}) => 'Impossible de charger la page : ${reason}',
			'operation.layout.panels.remoteScreenDescription' => 'Un écran, une application ou une fenêtre partagé par un autre de vos appareils.',
			'operation.layout.panels.remoteScreenTarget' => 'Écran',
			'operation.layout.panels.remoteScreenChoose' => 'Choisir un écran…',
			'operation.layout.panels.remoteScreenPickerTitle' => 'Écrans partagés',
			'operation.layout.panels.remoteScreenPickerEmpty' => 'Aucun de vos appareils ne partage d\'écran. Activez Partager les écrans et fenêtres dans Paramètres → Appareils pairs, sur l\'appareil que vous voulez voir.',
			'operation.layout.panels.remoteScreenUnset' => 'Aucun écran choisi. Ouvrez les paramètres de ce panneau pour en choisir un que vos autres appareils partagent.',
			'operation.layout.panels.remoteScreenConnecting' => 'Connexion…',
			'operation.layout.panels.remoteScreenPeerAway' => 'Cet appareil n\'est pas connecté pour l\'instant.',
			'operation.layout.panels.remoteScreenNotOffered' => 'Cet appareil a cessé de partager cet écran.',
			'operation.layout.panels.remoteScreenNoListener' => 'Cet appareil n\'accepte pas les connexions — vérifiez son pare-feu.',
			'operation.layout.panels.remoteScreenNoLan' => 'Les écrans ne sont partagés que sur le réseau local, pas en Bluetooth.',
			'operation.layout.panels.remoteScreenRefused' => 'Cet appareil a refusé de partager cet écran.',
			'operation.layout.panels.remoteScreenSettings' => 'Paramètres du panneau',
			'operation.layout.panels.remoteScreenAdjust' => 'Ajuster la vue',
			'operation.layout.panels.remoteScreenDetail' => 'Détail',
			'operation.layout.panels.remoteScreenDetailStandard' => 'Standard',
			'operation.layout.panels.remoteScreenDetailHigh' => 'Élevé',
			'operation.layout.panels.remoteScreenDetailMaximum' => 'Maximum',
			'operation.layout.panels.remoteScreenAdjustDone' => 'OK',
			'operation.layout.panels.remoteScreenZoomIn' => 'Zoom avant',
			'operation.layout.panels.remoteScreenZoomOut' => 'Zoom arrière',
			'operation.layout.panels.remoteScreenStopped' => 'Cet écran ou cette fenêtre n\'est plus affiché.',
			'operation.layout.panels.remoteScreenCaptureFailed' => 'Cet appareil n\'a pas pu capturer cet écran — il lui faut peut-être l\'autorisation d\'enregistrement de l\'écran.',
			'operation.layout.panels.remoteScreenNoAnswer' => 'Cet appareil n\'a pas répondu. Le partage d\'écran n\'y est peut-être pas activé.',
			'operation.layout.panels.remoteScreenNoMedia' => 'Impossible d\'ouvrir une connexion pour l\'image. Vérifiez le pare-feu de cet appareil.',
			'operation.layout.panels.solarDescription' => 'Conditions solaires et géomagnétiques, avec la propagation bande par bande',
			'operation.layout.panels.solarUnreachable' => 'hamqsl.com est injoignable — pas de réseau ? Nouvel essai sous peu.',
			'operation.layout.panels.solarUnreadable' => 'hamqsl.com a répondu, mais sans relevé exploitable. Nouvel essai sous peu.',
			'operation.layout.panels.solarAIndex' => 'A',
			'operation.layout.panels.solarKIndex' => 'Kp',
			'operation.layout.panels.solarBandDay' => 'Jour',
			'operation.layout.panels.solarBandNight' => 'Nuit',
			'operation.layout.panels.solarBandGood' => 'Bonne',
			'operation.layout.panels.solarBandFair' => 'Moyenne',
			'operation.layout.panels.solarBandPoor' => 'Mauvaise',
			'operation.layout.panels.solarSources' => ({required Object primary, required Object secondary}) => 'Sources : ${primary}, ${secondary}',
			'operation.layout.panels.remoteScreenDegraded' => 'La connexion peine — des images sont sautées.',
			'operation.layout.panels.remoteScreenStalled' => 'Les images ne passent plus — cette connexion est peut-être trop lente.',
			'operation.layout.panels.radioDescription' => 'La face avant d\'une radio — fréquence, mode et puissance, pilotée par CAT',
			'operation.layout.panels.radioStyle' => 'Style',
			'operation.layout.panels.radioStyleLcd' => 'LCD',
			'operation.layout.panels.radioStyleModern' => 'Moderne',
			'operation.layout.panels.radioRadio' => 'Radio',
			'operation.layout.panels.radioAutoNamed' => ({required Object name}) => 'VFO A — ${name}',
			'operation.layout.panels.radioAutoNone' => 'VFO A — aucune radio désignée',
			'operation.layout.panels.radioNoRadio' => 'Aucune radio à afficher. Choisissez-en une dans les paramètres de ce panneau, ou ajoutez-en une dans Configuration de la station.',
			'operation.layout.panels.radioNotConfigured' => 'Cette radio n\'est pas encore configurée. Choisissez son port ou son adresse dans Configuration de la station.',
			'operation.layout.panels.radioNoFrequency' => '—',
			'operation.layout.panels.radioOff' => 'Radio non connectée',
			'operation.layout.panels.radioWatts' => 'W',
			'operation.layout.panels.radioConnect' => 'Connecter cette radio',
			'operation.layout.panels.radioDisconnect' => 'Déconnecter cette radio',
			'operation.layout.panels.radioStale' => 'PAS DE DONNÉES',
			'operation.layout.panels.radioTransmitting' => 'TX',
			'operation.layout.panels.radioSwr' => 'ROS',
			'operation.layout.panels.radioAlc' => 'ALC',
			'operation.layout.panels.radioVolts' => 'V',
			'operation.layout.panels.radioSwrHigh' => 'ROS élevé',
			'operation.layout.htmlPanelUnsupported' => 'Ce panneau nécessite une vue web, que cette plateforme ne fournit pas',
			'operation.layout.htmlPanelUnsupportedOnWeb' => 'Ce panneau nécessite un bac à sable que la version web ne peut pas fournir',
			'operation.export.title' => 'Exports de l\'opération',
			'operation.export.syncedOperation' => 'L\'opération est synchronisée',
			'operation.export.unsyncedOperation' => 'L\'opération a des modifications non synchronisées',
			'operation.export.qsosInOperation' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} QSO dans cette opération', other: '${count} QSOs dans cette opération', ), 
			'operation.export.qsosSynced' => ({required Object total}) => 'Les ${total} QSOs sont synchronisés',
			'operation.export.qsosPending' => ({required Object pending, required Object total}) => '${pending} QSOs sur ${total} en attente de synchronisation',
			'operation.export.eventsSynced' => ({required Object total}) => '${total} marqueurs d\'événement synchronisés',
			'operation.export.eventsPending' => ({required Object pending, required Object total}) => '${pending} marqueurs d\'événement sur ${total} en attente',
			'operation.export.loading' => 'Chargement des options d\'export…',
			'operation.export.noOptions' => 'Aucun format d\'export disponible (le moteur d\'extensions démarre encore ?)',
			'operation.export.nothingLogged' => 'Rien à exporter pour l\'instant — cette opération n\'a aucun QSO.',
			'operation.export.share' => 'Partager',
			'operation.export.nothingSelected' => 'Aucune sélection',
			'operation.export.saveFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Enregistrer ${count} fichier', other: 'Enregistrer ${count} fichiers', ), 
			'operation.export.shareFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Partager ${count} fichier', other: 'Partager ${count} fichiers', ), 
			'operation.export.exportFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Exporter ${count} fichier', other: 'Exporter ${count} fichiers', ), 
			'operation.export.downloadFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Télécharger ${count} fichier', other: 'Télécharger ${count} fichiers', ), 
			'operation.export.saveCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Enregistrer ${count} fichier combiné', other: 'Enregistrer ${count} fichiers combinés', ), 
			'operation.export.shareCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Partager ${count} fichier combiné', other: 'Partager ${count} fichiers combinés', ), 
			'operation.export.exportCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Exporter ${count} fichier combiné', other: 'Exporter ${count} fichiers combinés', ), 
			'operation.export.downloadCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Télécharger ${count} fichier combiné', other: 'Télécharger ${count} fichiers combinés', ), 
			_ => null,
		} ?? switch (path) {
			'operation.export.saveOne' => ({required Object name}) => 'Enregistrer ${name}',
			'operation.export.shareOne' => ({required Object name}) => 'Partager ${name}',
			'operation.export.exportOne' => ({required Object name}) => 'Exporter ${name}',
			'operation.export.downloadOne' => ({required Object name}) => 'Télécharger ${name}',
			'operation.export.stashFiles' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Stocker ${count} fichier', other: 'Stocker ${count} fichiers', ), 
			'operation.export.stashCombined' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Stocker ${count} fichier combiné', other: 'Stocker ${count} fichiers combinés', ), 
			'operation.export.settingsButton' => 'Paramètres d\'export',
			'operation.export.settingsTitle' => 'Paramètres d\'export',
			'operation.export.compactFileNames.title' => 'Utiliser des noms de fichiers compacts',
			'operation.export.compactFileNames.descriptionOn' => 'Noms courts adaptés aux outils de téléversement, comme N0CALL@US-1234-20260727.adi',
			'operation.export.compactFileNames.descriptionOff' => 'Noms lisibles, comme 2026-07-27 N0CALL at US-1234.adi',
			'operation.export.includePrivateData.title' => 'Inclure les infos privées',
			'operation.export.includePrivateData.descriptionOn' => 'Les noms, adresses, e-mails, locators et notes sont inclus',
			'operation.export.includePrivateData.descriptionOff' => 'Les noms, adresses, e-mails, locators et notes sont exclus',
			'operation.export.includePrivateData.note' => 'L\'export ADIF complet inclut toujours tout',
			'operation.export.resultTitle' => 'Export terminé',
			'operation.export.resultFailedTitle' => 'Échec de l\'export',
			'operation.export.saveSuccess' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} fichier exporté vers ${path}', other: '${count} fichiers exportés vers ${path}', ), 
			'operation.export.saveSuccessNamed' => ({required num count, required Object path}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} fichier exporté : ${path}', other: '${count} fichiers exportés : ${path}', ), 
			'operation.export.shareSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} fichier partagé', other: '${count} fichiers partagés', ), 
			'operation.export.downloadSuccess' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} fichier téléchargé', other: '${count} fichiers téléchargés', ), 
			'operation.export.exportFailed' => ({required Object error}) => 'Échec de l\'export : ${error}',
			'operation.export.stash.needsEmailTitle' => 'Ajoutez d\'abord une adresse e-mail',
			'operation.export.stash.needsEmailBody' => 'Ham2K File Stash envoie vos fichiers à l\'adresse e-mail de votre compte LoFi, et vous vous connectez avec elle sur stash.ham2k.net. Votre compte n\'a pas encore d\'adresse confirmée — ajoutez-la dans Paramètres › Synchronisation cloud.',
			'operation.export.stash.openSyncSettings' => 'Ouvrir Synchronisation cloud',
			'operation.export.stash.replaceTitle' => 'Le dépôt récent sera remplacé',
			'operation.export.stash.replaceBody' => ({required Object name}) => 'Vous avez envoyé « ${name} » il y a moins de 6 heures et il n\'a pas encore été téléchargé. Les comptes gratuits ne conservent qu\'un seul dépôt à la fois : l\'envoyer maintenant le remplacera.',
			'operation.export.stash.replaceConfirm' => 'Envoyer quand même',
			'operation.export.stash.failedTitle' => 'Impossible d\'envoyer vers Ham2K File Stash',
			'operation.export.stash.sentTitle' => 'Envoyé vers Ham2K File Stash',
			'operation.export.stash.retrieve' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Vous pouvez récupérer ce fichier en vous rendant sur **[stash.ham2k.net](https://stash.ham2k.net)** depuis n\'importe quel navigateur.', other: 'Vous pouvez récupérer ces fichiers en vous rendant sur **[stash.ham2k.net](https://stash.ham2k.net)** depuis n\'importe quel navigateur.', ), 
			'operation.export.stash.mayHaveArrived' => 'Pas de réponse du dépôt — le fichier est peut-être arrivé quand même. Vérifiez stash.ham2k.net avant de renvoyer',
			'operation.export.stash.notSent' => 'non envoyé',
			'operation.export.stash.notArrived' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Ce fichier n\'est pas arrivé :', other: 'Ces ${count} fichiers ne sont pas arrivés :', ), 
			'operation.export.stash.emailOffer' => 'Ou, pour plus de commodité, nous pouvons vous envoyer un e-mail avec un lien direct.',
			'operation.export.stash.emailMe' => 'M\'envoyer un lien par e-mail',
			'operation.export.stash.emailSent' => 'Nous vous avons envoyé un lien de téléchargement par e-mail.',
			'operation.export.stash.emailFailed' => ({required Object error}) => 'Impossible d\'envoyer l\'e-mail : ${error}',
			'operation.export.stash.freeTier' => 'Les comptes gratuits ne peuvent conserver qu\'un seul dépôt à la fois. Les abonnés peuvent en conserver autant qu\'ils le souhaitent.',
			'operation.export.stash.sentStatus' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} fichier envoyé vers Ham2K File Stash (stash.ham2k.net)', other: '${count} fichiers envoyés vers Ham2K File Stash (stash.ham2k.net)', ), 
			'operation.spots.empty' => 'Aucun spot ne correspond à vos filtres',
			'operation.spots.error' => ({required Object error}) => 'Échec du chargement des spots : ${error}',
			'operation.spots.unknownBand' => 'Autre',
			'operation.spots.auto' => 'Automatique',
			'operation.spots.autoValue' => ({required Object value}) => 'Automatique (actuellement ${value})',
			'operation.spots.valueAuto' => ({required Object value}) => '${value} (auto)',
			'operation.spots.any' => 'Tous',
			'operation.spots.allBands' => 'Toutes les bandes',
			'operation.spots.allModes' => 'Tous les modes',
			'operation.spots.phoneAndCw' => 'Phonie et CW',
			'operation.spots.spotsCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} spot', other: '${count} spots', ), 
			'operation.spots.spotsCountFiltered' => ({required Object count, required Object total}) => 'Affichage de ${count} spots sur ${total}',
			'operation.spots.ageMinutes' => ({required Object minutes}) => '${minutes} minutes',
			'operation.spots.callsOfNote' => 'Indicatifs notables',
			'operation.spots.yourSpots' => 'Vos spots',
			'operation.spots.allSpots' => 'Tous les spots',
			'operation.spots.continents.af' => 'Afrique',
			'operation.spots.continents.as' => 'Asie',
			'operation.spots.continents.eu' => 'Europe',
			'operation.spots.continents.na' => 'Amérique du Nord',
			'operation.spots.continents.oc' => 'Océanie',
			'operation.spots.continents.sa' => 'Amérique du Sud',
			'operation.spots.continents.an' => 'Antarctique',
			'operation.spots.filters.title' => 'Filtrer les spots',
			'operation.spots.filters.band' => 'Bande',
			'operation.spots.filters.mode' => 'Mode',
			'operation.spots.filters.age' => 'Âge',
			'operation.spots.filters.sources' => 'Sources',
			'operation.spots.filters.continent' => 'Continent',
			'operation.spots.filters.sorting' => 'Tri',
			'operation.spots.filters.sortByTime' => 'Par heure du spot',
			'operation.spots.filters.sortByFrequency' => 'Par fréquence',
			'operation.spots.filters.groupByBand' => 'Grouper par bande',
			'operation.spots.filters.groupCallsWithNotes' => 'Grouper les indicatifs avec notes',
			'operation.spots.filters.sourceNoReply' => 'Pas de réponse',
			'operation.spots.filters.sourceError' => 'Erreur',
			'operation.spots.unavailableTitle' => 'Spots indisponibles',
			'operation.spots.unavailableText' => ({required Object sources}) => '${sources} n\'a pas répondu.',
			'operation.spots.failedTitle' => 'Erreur de source de spots',
			'operation.spots.failedText' => ({required Object sources}) => '${sources} a renvoyé une erreur.',
			'operation.spots.slideLogIt' => 'Saisir',
			'operation.spots.slideIgnore' => 'Ignorer',
			'operation.spots.slideRestore' => 'Restaurer',
			'operation.spots.logConflict.title' => 'Le panneau de saisie est occupé',
			'operation.spots.logConflict.editingBody' => 'Vous modifiez un contact déjà saisi. Saisir plutôt ce spot, ou revenir terminer la modification ?',
			'operation.spots.logConflict.composingBody' => 'Vous avez commencé à saisir un contact. Saisir plutôt ce spot, ou revenir terminer votre saisie ?',
			'operation.spots.logConflict.goBack' => 'Revenir',
			'operation.spots.logConflict.clearAndLog' => 'Effacer et saisir le spot',
			'operation.import.title' => 'Importer des données dans l\'opération',
			'operation.import.importAdifAction' => 'Importer des QSOs depuis ADIF',
			'operation.import.settingsButton' => 'Paramètres d\'écoute',
			'operation.import.settingsTitle' => 'Écouter d\'autres applications',
			'operation.import.protocolAddressLabel' => 'Adresse',
			'operation.import.protocolPortLabel' => 'Port',
			'operation.import.protocolPortInvalid' => 'Entrez un port entre 1 et 65535',
			'operation.import.protocolAddressInvalid' => 'Entrez une adresse IP valide (par ex. 127.0.0.1 ou 239.239.0.2)',
			'operation.import.protocolStatusReceiving' => 'Réception de données',
			'operation.import.protocolStatusNoData' => 'Aucune donnée reçue récemment',
			'operation.import.protocolBindError' => ({required Object error}) => 'Impossible de démarrer l\'écoute : ${error}',
			'operation.import.captureFailed' => ({required Object error}) => 'Les QSOs entrants n\'ont pas pu être enregistrés, nouvelle tentative en cours : ${error}',
			'operation.import.n1mmProtocolName' => 'N1MM+ Contact Broadcast',
			'operation.import.n1mmAddressValue' => 'Toutes (diffusion)',
			'operation.import.wsjtxProtocolName' => 'Serveur UDP WSJT-X',
			'operation.import.helpN1mmSetup' => 'Config → Configure Ports, Mode Control… → onglet Broadcast Data → cochez "Enable Broadcasts" pour les infos de contact. Réglez l\'adresse IP sur 127.0.0.1 si N1MM+ tourne sur ce même ordinateur, ou sur 255.255.255.255 pour diffuser sur le réseau local actuel.',
			'operation.import.helpWsjtxSetup' => 'File → Settings → onglet Reporting → section UDP Server → cochez "Accept UDP requests". Réglez UDP Server sur 127.0.0.1 si WSJT-X tourne sur ce même ordinateur, ou sur une adresse multicast comme 239.239.0.2, et utilisez la même adresse dans la configuration ci-dessus dans cette application.',
			'operation.import.listenTitle' => 'Écouter les QSOs d\'autres applications',
			'operation.import.listenDescriptionOnN1mm' => 'Écoute de N1MM+',
			'operation.import.listenDescriptionOnWsjtx' => 'Écoute de WSJT-X',
			'operation.import.listenDescriptionOnBoth' => 'Écoute de N1MM+ et WSJT-X',
			'operation.import.listenDescriptionOff' => 'Désactivé',
			'operation.import.addToOperationTitle' => 'Ajouter à cette opération',
			'operation.import.addToOperationDescriptionOn' => 'Les QSOs capturés sont ajoutés à cette opération dès leur arrivée',
			'operation.import.addToOperationDescriptionOff' => 'Les QSOs capturés sont retenus jusqu\'à ce que vous activiez cette option',
			'operation.import.pendingSectionTitle' => 'QSOs capturés',
			'operation.import.pendingEmpty' => 'Rien de capturé pour l\'instant',
			'operation.import.stationMismatch' => ({required Object call}) => 'Saisi comme ${call}, pas l\'indicatif de station de cette opération',
			'operation.import.discardAction' => 'Abandonner',
			'operation.import.gapDialogTitle' => 'Inclure les captures précédentes ?',
			'operation.import.gapDialogBody' => ({required Object count}) => '${count} QSOs de plus ont été capturés plus tôt, avant une interruption des données. Les inclure aussi ?',
			'operation.import.gapDialogRecentOnly' => 'Seulement les récents',
			'operation.import.gapDialogIncludeAll' => ({required Object count}) => 'Inclure les ${count}',
			'map.outlineIssue.link' => 'Un problème ?',
			'map.outlineIssue.title' => 'Signaler un problème de contour',
			'map.outlineIssue.reference' => 'Quel contour',
			'map.outlineIssue.severity' => 'Quelle gravité ?',
			'map.outlineIssue.minor' => 'Détail mineur',
			'map.outlineIssue.major' => 'Problème important',
			'map.outlineIssue.explanation' => 'Qu\'est-ce qui ne va pas ?',
			'map.outlineIssue.explanationHint' => 'Ce que le contour indique de faux, et où',
			'map.outlineIssue.send' => 'Envoyer',
			'map.outlineIssue.sending' => 'Envoi de votre signalement — merci',
			'map.outlineIssue.copy' => 'Copier le signalement',
			'map.outlineIssue.notSent' => 'Impossible d\'envoyer le signalement',
			'map.outlineIssue.copied' => 'Signalement copié',
			'map.outlineIssue.notCopied' => 'Impossible de copier le signalement',
			'map.outlinesDisclaimer' => 'Les contours sont donnés à titre indicatif. Faites vos propres recherches !',
			'map.outlinesCredit' => ({required Object sources}) => 'Contours : ${sources}',
			'map.boundariesCredit' => ({required Object sources}) => 'Limites : ${sources}',
			'map.facilitiesCredit' => ({required Object sources}) => 'Équipements : ${sources}',
			'map.fullCredits' => 'Crédits complets des données',
			'map.fewerCredits' => 'Moins de crédits',
			'map.emptyState' => 'Aucune position de QSO pour l\'instant.\nLes QSOs avec un locator, un état ou un pays apparaîtront ici.',
			'map.unavailable' => 'La carte n\'est pas disponible pour le moment.',
			'map.qthPopupTitle' => ({required Object grid}) => 'QTH : ${grid}',
			'map.distanceKm' => ({required Object distance}) => '${distance} km',
			'map.distanceMiles' => ({required Object distance}) => '${distance} mi',
			'map.flat' => 'Plane',
			'map.globe' => 'Globe',
			'map.zoomIn' => 'Zoom avant',
			'map.zoomOut' => 'Zoom arrière',
			'map.postcard.button' => 'Carte postale de l\'opération',
			'map.postcard.title' => ({required Object title}) => 'Carte postale pour ${title}',
			'map.postcard.portrait' => 'Portrait',
			'map.postcard.landscape' => 'Paysage',
			'map.postcard.square' => 'Carré',
			'map.postcard.save' => 'Enregistrer…',
			'map.postcard.download' => 'Télécharger',
			'map.postcard.share' => 'Partager',
			'map.postcard.copy' => 'Copier',
			'map.postcard.copied' => 'Copié dans le presse-papiers',
			'map.postcard.saved' => ({required Object path}) => 'Enregistré dans ${path}',
			'map.postcard.downloaded' => ({required Object name}) => '${name} téléchargé',
			'map.postcard.savedMany' => ({required Object count, required Object path}) => '${count} images enregistrées dans ${path}',
			'map.postcard.savedFiles' => ({required Object names}) => '${names} enregistré(s)',
			'map.postcard.savePartial' => ({required Object error, required Object names}) => '${error} — ${names} avait déjà été enregistré',
			'map.postcard.downloadedMany' => ({required Object count}) => 'Téléchargement de ${count} images — autorisez-les si le navigateur le demande',
			'map.postcard.mapLeftOut' => 'La carte n\'a pas chargé, elle a donc été omise',
			'map.postcard.withMapLeftOut' => ({required Object outcome}) => '${outcome} — la carte n\'a pas chargé, elle a donc été omise',
			'map.postcard.continued' => ({required Object title}) => '${title} (suite)',
			'map.postcard.previousPage' => 'Page précédente',
			'map.postcard.nextPage' => 'Page suivante',
			'map.postcard.pageOf' => ({required Object page, required Object count}) => 'Page ${page} sur ${count}',
			'map.postcard.sectionDays' => 'Chaque jour',
			'map.postcard.reset' => 'Réinitialiser',
			'map.postcard.failed' => ({required Object error}) => 'Impossible de créer la carte postale : ${error}',
			'map.postcard.mapNotReady' => 'La carte n\'a pas fini de charger. Vérifiez la connexion et réessayez.',
			'map.postcard.saveFailed' => ({required Object error}) => 'Impossible d\'enregistrer la carte postale : ${error}',
			'map.postcard.copyFailed' => 'Le presse-papiers n\'a pas accepté l\'image. Réessayez.',
			'map.postcard.shareFailed' => 'Impossible de partager la carte postale. Réessayez.',
			'map.postcard.fileName' => 'carte-postale',
			'mapsView.title' => 'Cartes',
			'mapsView.searchHint' => 'Rechercher des parcs, des sommets et plus',
			'mapsView.activities' => 'Activités',
			'mapsView.layers' => 'Calques',
			'mapsView.baseMap' => 'Fond de carte',
			'mapsView.satellite' => 'Satellite (Esri)',
			'mapsView.facilities' => 'Équipements des parcs',
			'mapsView.boundaries' => 'Limites',
			'mapsView.currentLocation' => 'Position actuelle',
			'mapsView.noMatches' => ({required Object text}) => 'Rien ne correspond à « ${text} »',
			'mapsView.picksAt' => ({required num count, required Object where}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} référence à ${where}', other: '${count} références à ${where}', ), 
			'mapsView.startOperation' => 'Commencer une opération avec ces références',
			'activitiesView.title' => 'Activités',
			'activitiesView.activitiesCountZero' => 'Aucune activité sélectionnée',
			'activitiesView.activitiesCountOne' => '1 activité',
			'activitiesView.activitiesCountOther' => ({required Object count}) => '${count} activités',
			'activitiesView.empty' => 'Aucune activité pour l\'instant — utilisez Suggestions et recherche ci-dessous pour en ajouter une',
			'activitiesView.removeActivity' => 'Retirer',
			'activitiesView.openReferenceLink' => ({required Object name}) => 'Ouvrir ${name}',
			'activitiesView.editActivity' => 'Modifier l\'activité',
			'activitiesView.manageExtensions' => 'Gérer les extensions',
			'activitiesView.manage' => 'Gérer',
			'activitiesView.activitiesTitle1' => ({required Object first}) => 'Types d\'activités : ${first}',
			'activitiesView.activitiesTitle2' => ({required Object first, required Object second}) => 'Types d\'activités : ${first} et ${second}',
			'activitiesView.activitiesTitleMore' => ({required Object first, required Object second, required Object more}) => 'Types d\'activités : ${first}, ${second} et ${more} de plus',
			'activitiesView.reference' => 'Référence',
			'activitiesView.invalidReference' => 'Non valide',
			'activitiesView.duplicateReference' => 'Déjà ajoutée',
			'activitiesView.searchHint' => 'Rechercher par nom, référence ou autre…',
			'activitiesView.noSuggestions' => 'Aucun résultat',
			'activitiesView.noSuggestionsHint' => 'Recherchez par nom ou numéro de référence ci-dessus',
			'activitiesView.noSuggestionsExample' => '(par exemple « sentier » ou « 4556 »)',
			'activitiesView.allOptions' => 'Types d\'activités',
			'activitiesView.determiningLocation' => 'Détermination de la position actuelle…\nEn attente du GPS pour trouver les références à proximité',
			'activitiesView.locationUnavailableTitle' => 'Données de localisation indisponibles',
			'activitiesView.locationDeniedTitle' => 'Autorisation de localisation refusée',
			'activitiesView.locationBlockedTitle' => 'Autorisation de localisation bloquée',
			'activitiesView.noNearbyReason' => 'Impossible de déterminer les références à proximité',
			'activitiesView.locationManualHint' => ({required Object icon}) => 'Appuyez sur ${icon} pour saisir votre position manuellement,\nou recherchez simplement des références par nom',
			'activitiesView.locationGrantAction' => 'Autoriser l\'accès à la localisation',
			'activitiesView.locationSettingsAction' => 'Ouvrir les réglages',
			'activitiesView.locationSettingsUnavailable' => 'Autorisez l\'accès à la localisation dans les réglages du système',
			'activitiesView.locationGrantRefused' => 'Toujours pas de localisation — le système a de nouveau refusé',
			'activitiesView.searchUnavailableTitle' => 'Recherche d\'activités indisponible',
			'activitiesView.searchUnavailableReason' => 'Aucune extension d\'activité n\'a pu effectuer la recherche. Réessayez dans un instant.',
			'activitiesView.emptySheet' => 'Utilisez les suggestions et la recherche ci-dessous pour en ajouter une',
			'activitiesView.exports' => 'Exports',
			'activitiesView.exportLogs' => 'Exporter les journaux',
			'activitiesView.tools' => 'Outils',
			'activitiesView.toolsTitle' => 'Outils de l\'opération',
			'activitiesView.operationDetails' => 'Détails de l\'opération',
			'activitiesView.share' => 'Partager',
			'activitiesView.archive' => 'Archiver',
			'activitiesView.deleteOperation' => 'Supprimer l\'opération',
			'activitiesView.undeleteOperation' => 'Restaurer l\'opération',
			'activitiesView.alreadySelected' => 'Déjà sélectionnée',
			'activitiesView.selected' => 'Sélectionnée',
			'activitiesView.pickPosition' => ({required Object index, required Object count}) => '${index} sur ${count}',
			'activitiesView.previousPick' => 'Résultat précédent',
			'activitiesView.nextPick' => 'Résultat suivant',
			'activitiesView.retiredReference' => 'Retirée',
			'activitiesView.enableExtension' => ({required Object name}) => 'Activer ${name}',
			'activitiesView.enableExtensionHint' => 'Cette extension correspond à votre recherche, mais elle n\'est pas activée',
			'activitiesView.enableExtensionForRefHint' => 'Cette extension gère l\'une des références de cette opération, mais elle n\'est pas activée',
			'activitiesView.extensionNotRunning' => ({required Object name}) => '${name} ne fonctionne pas',
			'activitiesView.extensionNotRunningHint' => 'Cette extension a été désactivée, ouvrez les paramètres des extensions pour plus d\'infos',
			'activitiesView.installExtension' => ({required Object name}) => 'Installer ${name}',
			'activitiesView.installExtensionHint' => 'Cette extension correspond à votre recherche, mais elle n\'est pas installée',
			'activitiesView.onlyCatalogMatches' => 'Aucun résultat\nCertaines extensions du catalogue pourraient avoir des résultats.\nInstallez-les dans Types d\'activités ci-dessous.',
			'activitiesView.setupUnavailable' => 'Impossible de charger la configuration de cette activité — réessayez depuis Gérer',
			'activitiesView.controlsUnavailableTitle' => 'Contrôles d\'activité indisponibles',
			'activitiesView.controlsUnavailableReason' => 'Vos références sont intactes, mais leur modification est indisponible pour le moment.',
			'activitiesView.controlsUnavailableRetry' => 'Réessayer',
			'activitiesView.onlyDisabledMatches' => 'Aucun résultat\nCertaines extensions disponibles pourraient avoir des résultats.\nActivez-les dans Types d\'activités ci-dessous.',
			'activitiesView.onlyNotRunningMatches' => 'Aucun résultat\nCertaines extensions qui pourraient avoir des résultats ne fonctionnent pas.\nVoir Types d\'activités ci-dessous.',
			'activitiesView.mapToggle' => 'Carte',
			'activitiesView.searchToggle' => 'Recherche',
			'activitiesView.addToOperation' => 'Ajouter à l\'opération',
			'activitiesView.addToOperationShort' => 'Ajouter à l\'op.',
			'activitiesView.mapEmptyState' => 'Aucun résultat à afficher sur la carte',
			'activitiesView.mapEmptyStateHint' => 'Revenez à la liste, ou lancez une autre recherche',
			'activitiesView.imports' => 'Imports',
			'loggingControls.timeUtc' => 'Heure (UTC)',
			'loggingControls.date' => 'Date',
			'loggingControls.now' => 'Maintenant',
			'loggingControls.frequency' => 'Fréquence',
			'loggingControls.mode' => 'Mode',
			'loggingControls.theirCall' => 'Leur indicatif',
			'loggingControls.noteField' => 'Note',
			'loggingControls.todoField' => 'À faire',
			'loggingControls.sent' => 'Envoyé',
			'loggingControls.rcvd' => 'Reçu',
			'loggingControls.more' => 'Plus',
			'loggingControls.revert' => 'Rétablir',
			'loggingControls.undoDelete' => 'Annuler la suppression',
			'loggingControls.restore' => 'Restaurer',
			'loggingControls.wipe' => 'Effacer',
			'loggingControls.undo' => 'Annuler',
			'loggingControls.pendingDeleteTapWarning' => 'Appuyez encore une fois sur la corbeille pour supprimer ce QSO',
			'loggingControls.pendingDeleteClickWarning' => 'Cliquez encore une fois sur la corbeille pour supprimer ce QSO',
			'loggingControls.deletedQsoWarning' => 'QSO supprimé',
			'loggingControls.pendingDeleteEventTapWarning' => ({required Object kind}) => 'Appuyez encore une fois sur la corbeille pour supprimer : ${kind}',
			'loggingControls.pendingDeleteEventClickWarning' => ({required Object kind}) => 'Cliquez encore une fois sur la corbeille pour supprimer : ${kind}',
			'loggingControls.deletedEventWarning' => ({required Object kind}) => 'Supprimé : ${kind}',
			'loggingControls.timeControl' => 'Heure',
			'loggingControls.radioControl' => 'Radio',
			'loggingControls.powerControl' => 'Puissance',
			'loggingControls.notesControl' => 'Notes',
			'loggingControls.power' => 'Puissance',
			'loggingControls.powerUnit' => 'W',
			'loggingControls.controlSettings' => 'Contrôles de saisie',
			'loggingControls.spottingControl' => 'Spotting',
			'loggingControls.spottingSelfControl' => 'Auto-spotting',
			'loggingControls.spotSelfAt' => ({required Object freq}) => 'S\'auto-spotter sur ${freq}',
			'loggingControls.spotOtherAt' => ({required Object call, required Object freq}) => 'Spotter ${call} sur ${freq}',
			'loggingControls.spotTooLate' => ({required Object call}) => 'Trop tard pour spotter ${call}',
			'loggingControls.spotNoFreq' => 'Définissez d\'abord une fréquence à spotter',
			'loggingControls.spotComment' => 'Commentaire',
			'loggingControls.bandOrFreqRequired' => 'Définissez une fréquence ou une bande avant de saisir',
			'loggingControls.missingBand' => 'Pas de bande',
			'loggingControls.missingMode' => 'Pas de mode',
			'loggingControls.saveFailed' => ({required Object error}) => 'Impossible d\'enregistrer : ${error}',
			'loggingControls.deleteFailed' => ({required Object error}) => 'Impossible de supprimer : ${error}',
			'loggingControls.info.noQsos' => 'Pas encore de QSOs… Allez faire de la radio !',
			'loggingControls.info.qsoCountOne' => '1 QSO',
			'loggingControls.info.qsoCountOther' => ({required Object count}) => '${count} QSOs',
			'loggingControls.info.qsosInTime' => ({required Object count, required Object time}) => '${count} en ${time}',
			'loggingControls.info.sinceLast' => ({required Object time}) => '${time} depuis le dernier',
			'loggingControls.info.ratePer10' => ({required Object rate}) => '${rate} Q/h pour les 10 derniers',
			'loggingControls.info.ratePer100' => ({required Object rate}) => '${rate} Q/h pour les 100 derniers',
			'loggingControls.info.distanceTo' => ({required Object distance}) => '${distance} jusqu\'à',
			'loggingControls.info.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) jusqu\'à',
			'loggingControls.info.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) jusqu\'à',
			'loggingControls.info.distanceAway' => ({required Object distance}) => '${distance} de distance',
			'loggingControls.info.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distance',
			'loggingControls.info.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distance',
			'loggingControls.info.noticeFromScorer' => ({required Object scorer, required Object notice}) => '${scorer} : ${notice}',
			'loggingControls.info.noticeDupe' => 'Doublon !',
			'loggingControls.info.noticeNewBand' => 'Nouvelle bande',
			'loggingControls.info.noticeNewMode' => 'Nouveau mode',
			'loggingControls.info.noticeNewDXCC' => 'Nouveau DXCC',
			'loggingControls.info.noticeNewState' => 'Nouvel état',
			'loggingControls.info.noticeNewProvince' => 'Nouvelle province',
			'loggingControls.info.noticeNewDay' => 'Nouveau jour',
			'loggingControls.info.noticeNewRef' => 'Nouvelle réf',
			'loggingControls.info.noticeNewMult' => 'Nouveau mult',
			'loggingControls.info.noticeNewZone' => 'Nouvelle zone',
			'loggingControls.info.noticeInvalidMode' => 'Mauvais mode',
			'loggingControls.info.noticeInvalidBand' => 'Mauvaise bande',
			'loggingControls.info.noticeInvalidCategory' => 'Non contactable',
			'loggingControls.info.noticeWorkedBefore' => 'Déjà contacté',
			'loggingControls.info.noticeNewPark' => 'Nouveau parc',
			'loggingControls.info.noticeNewSection' => 'Nouvelle section',
			'loggingControls.info.noticeBonusStation' => 'Station bonus !',
			'loggingControls.info.noticeMissingExchange' => 'Pas d\'échange',
			'loggingControls.info.noticeInvalidExchange' => 'Échange erroné',
			'loggingControls.info.noticeUnknownEvent' => 'Événement inconnu',
			'loggingControls.info.noticeOurGrid' => 'Définir notre grille',
			'loggingControls.info.noticeRareCounty' => 'Comté rare !',
			'loggingControls.info.noticeOurLocation' => 'Définir notre comté',
			'loggingControls.info.noticeShortGrid' => 'Grille trop courte',
			'formChrome.untitled' => '(sans titre)',
			'formChrome.showMore' => 'Afficher plus',
			'formChrome.showAll' => 'Tout afficher',
			'formChrome.showFewer' => 'Afficher moins',
			'formChrome.defaults' => 'Valeurs par défaut',
			'formChrome.search' => 'Rechercher',
			'formChrome.clear' => 'Effacer',
			'formChrome.openPage' => 'Ouvrir la page',
			'formChrome.connected' => 'Connecté',
			'formChrome.notConnected' => 'Non connecté',
			'formChrome.manage' => 'Gérer',
			'formChrome.connect' => 'Connecter',
			'formChrome.formTitle' => 'Formulaire',
			'formChrome.addItem' => ({required Object label}) => 'Ajouter ${label}',
			'formChrome.editItem' => ({required Object label}) => 'Modifier ${label}',
			'formChrome.multiselectStatus' => ({required Object shown, required Object total, required Object selected}) => 'Affichage de ${shown} sur ${total} (${selected} sélectionnés)',
			'formChrome.validationError' => ({required Object error}) => 'Erreur de validation : ${error}',
			'formChrome.transformationError' => ({required Object error}) => 'Erreur de transformation : ${error}',
			'formChrome.actionError' => ({required Object error}) => 'Erreur : ${error}',
			'formChrome.removeItem' => 'Retirer',
			'formChrome.storageUnavailable' => 'Identifiants indisponibles',
			'qsoEditForm.title' => 'Modifier le QSO',
			'qsoEditForm.operatorCall' => 'Opérateur',
			'qsoEditForm.position' => 'Position',
			'qsoEditForm.theirName' => 'Nom',
			'qsoEditForm.theirGrid' => 'Grille',
			'qsoEditForm.theirState' => 'État',
			'qsoEditForm.band' => 'Bande',
			'qsoEditForm.notes' => 'Notes',
			'qsoEditForm.sectionQso' => 'QSO',
			'qsoEditForm.sectionTheir' => 'Leurs infos',
			'qsoEditForm.sectionOur' => 'Nos infos',
			'qsoEditForm.sectionNotes' => 'Notes',
			'qsoEditForm.theirCity' => 'Ville',
			'qsoEditForm.theirCounty' => 'Comté',
			'qsoEditForm.theirEntity' => 'Entité',
			'qsoEditForm.theirCqZone' => 'Zone CQ',
			'qsoEditForm.theirItuZone' => 'Zone ITU',
			'qsoEditForm.theirArrlSection' => 'Section ARRL',
			'qsoEditForm.theirLat' => 'Latitude',
			'qsoEditForm.theirLon' => 'Longitude',
			'qsoEditForm.theirPower' => 'Leur puissance',
			'qsoList.empty' => 'Pas encore de QSOs — contactez quelqu\'un !',
			'qsoList.bandOrModeWarning' => 'Vérifiez que votre bande et votre mode sont corrects',
			'qsoList.today' => 'Aujourd\'hui',
			'qsoList.yesterday' => 'Hier',
			'qsoList.tomorrow' => 'Demain',
			'loggingPanel.stats' => 'Statistiques de l\'opération',
			'loggingPanel.scoring' => 'Score',
			'loggingPanel.dxccEntities' => 'Entités DXCC',
			'loggingPanel.statesWorked' => 'États',
			'loggingPanel.provincesWorked' => 'Provinces',
			'loggingPanel.duplicates' => 'Doublons',
			'callInfo.qrz' => 'QRZ',
			'callInfo.showImage' => 'Afficher l\'image',
			'callInfo.imageUnavailable' => 'Photo indisponible',
			'callInfo.photo' => 'Photo',
			'callInfo.notes' => 'Notes',
			'callInfo.distanceTo' => ({required Object distance}) => '${distance} jusqu\'à',
			'callInfo.distanceBearingTo' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) jusqu\'à',
			'callInfo.distanceBearingsTo' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) jusqu\'à',
			'callInfo.distanceAway' => ({required Object distance}) => '${distance} de distance',
			'callInfo.distanceBearingAway' => ({required Object distance, required Object bearing}) => '${distance} (${bearing}°) de distance',
			'callInfo.distanceBearingsAway' => ({required Object distance, required Object bearing, required Object reverse}) => '${distance} (${bearing}° / ${reverse}°) de distance',
			'callInfo.thisOpCountOne' => '1 QSO dans cette opération',
			'callInfo.thisOpCountOther' => ({required Object count}) => '${count} QSOs dans cette opération',
			'callInfo.otherOpsCountOne' => '1 QSO dans d\'autres opérations',
			'callInfo.otherOpsCountOther' => ({required Object count}) => '${count} QSOs dans d\'autres opérations',
			'callInfo.andMore' => ({required Object count}) => '… et ${count} de plus',
			'callInfo.withCall' => ({required Object call}) => 'avec ${call}',
			'callInfo.fromOperation' => ({required Object where}) => 'depuis ${where}',
			'callInfo.history.last7days' => ({required Object n}) => '${n} dans les 7 derniers jours',
			'callInfo.history.today' => ({required Object n}) => '${n} aujourd\'hui',
			'callInfo.history.qsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.title' => 'Paramètres',
			'settings.language' => 'Langue',
			'settings.languageSystem' => ({required Object language}) => 'Suivre les réglages du système (${language})',
			'settings.theme.title' => 'Thème',
			'settings.theme.system' => 'Suivre les réglages du système',
			'settings.theme.light' => 'Clair',
			'settings.theme.dark' => 'Sombre',
			'settings.themeDescription.system' => 'Suit les réglages du système',
			'settings.themeDescription.light' => 'Toujours en mode clair',
			'settings.themeDescription.dark' => 'Toujours en mode sombre',
			'settings.fontScale' => 'Échelle de police',
			'settings.fontScaleOpts.smallestMinusMinus' => 'Le plus petit--',
			'settings.fontScaleOpts.smallestMinus' => 'Le plus petit-',
			'settings.fontScaleOpts.smallest' => 'Le plus petit',
			'settings.fontScaleOpts.smaller' => 'Plus petit',
			'settings.fontScaleOpts.normal' => 'Normal',
			'settings.fontScaleOpts.larger' => 'Plus grand',
			'settings.fontScaleOpts.largest' => 'Le plus grand',
			'settings.fontScaleOpts.largestPlus' => 'Le plus grand+',
			'settings.fontScaleOpts.largestPlusPlus' => 'Le plus grand++',
			'settings.keepDeviceAwake.title' => 'Garder l\'appareil allumé',
			'settings.keepDeviceAwake.descriptionOn' => 'Reste allumé tant que vous êtes sur l\'écran de saisie ou qu\'une synchronisation est en cours',
			'settings.keepDeviceAwake.descriptionOff' => 'Mise en veille comme d\'habitude',
			'settings.layoutDensity' => 'Densité de l\'affichage',
			'settings.layoutDensityOpts.auto' => 'Automatique',
			'settings.layoutDensityOpts.densest' => 'Très dense',
			'settings.layoutDensityOpts.dense' => 'Dense',
			'settings.layoutDensityOpts.normal' => 'Normale',
			'settings.layoutDensityOpts.sparse' => 'Aérée',
			'settings.layoutDensityOpts.sparsest' => 'Très aérée',
			'settings.layoutDensityClamped' => ({required Object effective}) => 'la fenêtre est trop petite, utilisation de ${effective}',
			'settings.layoutDensityAtLimit' => 'au maximum',
			'settings.distanceUnits' => 'Unités de distance',
			'settings.distanceUnitsOpts.kilometers' => 'Kilomètres',
			'settings.distanceUnitsOpts.miles' => 'Miles',
			'settings.userInterface' => 'Interface utilisateur',
			'settings.logging.title' => 'Saisie',
			'settings.logging.leftieMode.title' => 'Mode gaucher',
			'settings.logging.leftieMode.descriptionOn' => 'Utilisation de la disposition pour gaucher',
			'settings.logging.leftieMode.descriptionOff' => 'Utilisation de la disposition pour droitier',
			'settings.logging.countryFlags.title' => 'Drapeaux des pays',
			'settings.logging.countryFlags.dx' => 'Uniquement pour les contacts DX',
			'settings.logging.countryFlags.all' => 'Drapeaux pour tous les contacts',
			'settings.logging.countryFlags.none' => 'Aucun drapeau',
			'settings.logging.countryFlagsDescription.dx' => 'Affichage des drapeaux uniquement pour les contacts DX',
			'settings.logging.countryFlagsDescription.all' => 'Affichage des drapeaux pour tous les contacts',
			'settings.logging.countryFlagsDescription.none' => 'Aucun drapeau affiché',
			'settings.logging.suggestDefaultOperator.title' => 'Suggérer l\'opérateur',
			'settings.logging.suggestDefaultOperator.descriptionOn' => 'Votre indicatif est proposé comme opérateur quand une opération utilise un autre indicatif de station',
			'settings.logging.suggestDefaultOperator.descriptionOff' => 'L\'opérateur reste vide sauf si vous le renseignez',
			'settings.logging.showBearing.title' => 'Afficher la direction',
			'settings.logging.showBearing.descriptionOn' => 'Affichage de l\'azimut estimé vers la station',
			'settings.logging.showBearing.descriptionOff' => 'Aucune information d\'azimut affichée',
			'settings.logging.showReverseBearing.title' => 'Afficher aussi l\'azimut inverse',
			'settings.logging.showReverseBearing.descriptionOn' => 'Affichage aussi de l\'azimut depuis la station, comme « 45° / 225° »',
			'settings.logging.showReverseBearing.descriptionOff' => 'Affichage uniquement de l\'azimut vers la station',
			'settings.logging.switchSentRcvd.title' => 'Changer l\'ordre des rapports de signal',
			'settings.logging.switchSentRcvd.sentFirst' => 'Envoyé en premier, Reçu en second',
			'settings.logging.switchSentRcvd.rcvdFirst' => 'Reçu en premier, Envoyé en second',
			'settings.logging.jumpAfterRST.title' => 'Passer au champ suivant à l\'entrée RST',
			'settings.logging.jumpAfterRST.descriptionOn' => 'Passage au champ suivant après la saisie du RST',
			'settings.logging.jumpAfterRST.descriptionOff' => 'Pas de passage automatique',
			'settings.logging.defaultReport.title' => 'Report par défaut — Phonie',
			'settings.logging.defaultReport.description' => 'Utilisé quand Envoyé ou Reçu est laissé vide en SSB, FM ou AM',
			'settings.logging.defaultReportCW.title' => 'Report par défaut — CW et numérique',
			'settings.logging.defaultReportCW.description' => 'Utilisé quand Envoyé ou Reçu est laissé vide en CW, RTTY et autres modes numériques',
			'settings.logging.defaultReportFT8.title' => 'Report par défaut — FT8 et FT4',
			'settings.logging.defaultReportFT8.description' => 'Utilisé quand Envoyé ou Reçu est laissé vide dans les modes FT',
			'settings.logging.numbersRow.title' => 'Ligne des chiffres',
			'settings.logging.numbersRow.description' => 'Afficher une ligne de touches numériques au-dessus du clavier pendant la saisie',
			'settings.logging.numbersRowExtra.title' => 'Touche barre oblique et point',
			'settings.logging.numbersRowExtra.description' => 'Ajoute une touche contextuelle : « / » pour les indicatifs, « . » pour les nombres',
			'settings.logging.numbersRowVibrate.title' => 'Vibrer à l\'appui',
			'settings.logging.numbersRowVibrate.description' => 'Retour haptique quand vous touchez une touche numérique',
			'settings.logging.bands' => 'Bandes préférées',
			'settings.logging.modes' => 'Modes préférés',
			'settings.catServer.title' => 'Serveur CAT',
			'settings.catServer.description' => 'Permettre à d\'autres applications (WSJT-X, logiciels de journal, etc.) de piloter la radio via Ham2K Logger.',
			'settings.catServer.protocol' => 'Protocole',
			'settings.catServer.protocolOpts.off' => 'Désactivé',
			'settings.catServer.protocolOpts.rigctld' => 'Hamlib rigctld',
			'settings.catServer.protocolOpts.flrig' => 'flrig',
			'settings.catServer.protocolOpts.hrd' => 'Ham Radio Deluxe®',
			'settings.catServer.protocolOpts.n3fjp' => 'N3FJP',
			'settings.catServer.port' => 'Port',
			'settings.catServer.openAccess' => 'Accès ouvert',
			'settings.catServer.openAccessOn' => 'N\'importe quel ordinateur du réseau local peut se connecter.',
			'settings.catServer.openAccessOff' => 'Seules les applications de cet ordinateur peuvent se connecter.',
			'settings.catServer.off' => 'Désactivé.',
			'settings.catServer.starting' => ({required Object protocol}) => '${protocol}, démarrage…',
			'settings.catServer.listening' => ({required Object protocol, required Object port, required Object clients}) => '${protocol} sur le port ${port}. Clients connectés : ${clients}.',
			'settings.catServer.listeningNoRadio' => ({required Object protocol, required Object port}) => '${protocol} sur le port ${port}, mais aucune radio VFO principal n\'est connectée.',
			'settings.catServer.failed' => ({required Object protocol, required Object port, required Object error}) => '${protocol} ne peut pas écouter sur le port ${port} : ${error}',
			'settings.catServer.portInUse' => ({required Object protocol, required Object port}) => '${protocol} ne peut pas écouter sur le port ${port} : un autre programme l\'utilise, souvent ${protocol} lui-même. Fermez ce programme ou choisissez un autre port.',
			'settings.catServer.portDenied' => ({required Object protocol, required Object port}) => '${protocol} ne peut pas écouter sur le port ${port} : cet ordinateur ne l\'autorise pas. Choisissez un port supérieur à 1024.',
			'settings.catServer.stopped' => ({required Object protocol, required Object port}) => '${protocol} a cessé d\'écouter sur le port ${port}. Nouvelle tentative…',
			'settings.radio.title' => 'Contrôle CAT',
			_ => null,
		} ?? switch (path) {
			'settings.radio.loggingAndCat' => 'Saisie et CAT',
			'settings.radio.tuningSection' => 'Accord',
			'settings.radio.keyerSection' => 'Manipulateur',
			'settings.radio.servicesSection' => 'Services',
			'settings.radio.stationConfigurationSection' => 'Configuration de la station',
			'settings.radio.moreSettings' => 'Plus de paramètres de configuration de la station',
			'settings.radio.units.ms' => 'ms',
			'settings.radio.units.kHz' => 'kHz',
			'settings.radio.units.kHzPerSecond' => 'kHz/s',
			'settings.radio.units.hz' => 'Hz',
			'settings.radio.pttKey.title' => 'Contrôler le PTT avec [\']',
			'settings.radio.pttKey.descriptionOn' => 'En modes Phonie, [\'] passe la radio en émission et [\'] à nouveau la repasse en réception. Elle repasse d\'elle-même en réception au bout d\'une minute.',
			'settings.radio.pttKey.descriptionOff' => 'La touche [\'] ne passe pas la radio en émission.',
			'settings.radio.pttKey.pill' => 'TX',
			'settings.radio.pttKey.transmitting' => 'Émission',
			'settings.radio.smartVfoSnap.title' => 'Arrondi intelligent du VFO',
			'settings.radio.smartVfoSnap.descriptionOn' => 'Quand vous arrêtez de tourner le bouton, la fréquence est arrondie à un pas raisonnable. Modes vocaux uniquement.',
			'settings.radio.smartVfoSnap.descriptionOff' => 'La fréquence reste exactement là où vous l\'avez accordée.',
			'settings.radio.snapDebounce.title' => 'Arrondi intelligent : délai de stabilisation',
			'settings.radio.snapDebounce.description' => 'Durée pendant laquelle le bouton doit rester immobile avant que la fréquence soit arrondie. Plus court paraît immédiat ; plus long laisse le temps d\'un mouvement lent.',
			'settings.radio.snapLongMove.title' => 'Arrondi intelligent : grand déplacement',
			'settings.radio.snapLongMove.description' => 'À partir de ce déplacement, la fréquence est arrondie au kHz entier, quelle que soit la lenteur de la fin du mouvement.',
			'settings.radio.snapMinMove.title' => 'Arrondi intelligent : plus petit déplacement',
			'settings.radio.snapMinMove.description' => 'En dessous de ce déplacement, la fréquence n\'est pas arrondie, pour ne pas toucher à l\'accord fin.',
			'settings.radio.snapMinSpeed.title' => 'Arrondi intelligent : mouvement le plus lent',
			'settings.radio.snapMinSpeed.description' => 'Si le bouton tourne plus lentement que cela, la fréquence n\'est pas arrondie, sauf en cas de grand déplacement.',
			'settings.radio.enterSends.pillOff' => 'ESM désactivé',
			'settings.radio.enterSends.pillRun' => 'ESM Run',
			'settings.radio.enterSends.pillSp' => 'ESM S&P',
			'settings.radio.enterSends.field' => 'Entrée envoie les messages',
			'settings.radio.enterSends.off' => 'Désactivé',
			'settings.radio.enterSends.run' => 'Run',
			'settings.radio.enterSends.sp' => 'S&P',
			'settings.radio.enterSends.semantics' => ({required Object state}) => 'Entrée envoie les messages : ${state}. Appuyez pour changer.',
			'settings.radio.keyerSpeed.title' => 'Vitesse du manipulateur',
			'settings.radio.keyerSpeed.unit' => 'WPM',
			'settings.radio.keyerSpeed.pill' => ({required Object wpm}) => '${wpm} wpm',
			'settings.radio.keyerSpeed.pillUnknown' => '– wpm',
			'settings.radio.cwMessages.title' => 'Messages CW du manipulateur',
			'settings.radio.cwMessages.notSupported' => 'La radio actuelle ne prend pas en charge la manipulation CW',
			'settings.radio.cwMessages.key' => ({required Object n}) => 'F${n}',
			'settings.radio.cwMessages.messageTitle' => ({required Object n}) => 'Message (${n})',
			'settings.radio.cwMessages.labelField' => 'Libellé',
			'settings.radio.cwMessages.labelKey' => ({required Object n}) => 'Libellé F${n}',
			'settings.radio.cwMessages.details' => 'Détails',
			'settings.radio.cwMessages.empty' => '(vide)',
			'settings.radio.cwMessages.sets' => 'Jeu de messages',
			'settings.radio.cwMessages.newSet' => 'Nouveau jeu',
			'settings.radio.cwMessages.renameSet' => 'Renommer le jeu',
			'settings.radio.cwMessages.deleteSet' => 'Supprimer le jeu',
			'settings.radio.cwMessages.newSetName' => 'Nom',
			'settings.radio.cwMessages.setDefault' => 'Par défaut',
			'settings.radio.cwMessages.setPota' => 'POTA',
			'settings.radio.cwMessages.setEsm' => 'Messages ESM',
			'settings.radio.cwMessages.setSaved' => 'Mes messages',
			'settings.radio.cwMessages.repeat' => 'Répéter le message n°1',
			'settings.radio.cwMessages.repeatOff' => 'Non',
			'settings.radio.cwMessages.repeatAfter' => ({required Object n}) => 'Après ${n} secondes',
			'settings.radio.cwMessages.repeatWait' => 'Répétition',
			'settings.radio.cwMessages.keyboard' => 'Taper pour envoyer',
			'settings.radio.cwMessages.keyboardField' => 'Taper pour envoyer',
			'settings.radio.cwMessages.closeArea' => 'Fermer la zone du manipulateur',
			'settings.radio.cwMessages.help' => 'Aide',
			'settings.radio.cwMessages.helpTitle' => 'Rédiger des messages CW',
			'settings.radio.cwMessages.helpIntro' => 'Les messages peuvent utiliser des modèles avec les valeurs suivantes :',
			'settings.radio.cwMessages.helpOpCall' => 'Votre indicatif',
			'settings.radio.cwMessages.helpQsoCall' => 'Leur indicatif — dans une pile //, l\'indicatif qui sera saisi',
			'settings.radio.cwMessages.helpQsoFullCall' => 'Leur indicatif, s\'il est valide ; vide pour un indicatif partiel',
			'settings.radio.cwMessages.helpQsoPartial' => 'Un indicatif partiel ; vide s\'il y a un indicatif complet valide',
			'settings.radio.cwMessages.helpQsoNextCall' => 'Dans une pile //, l\'indicatif qui sera sélectionné pour la prochaine saisie, s\'il est complet et valide',
			'settings.radio.cwMessages.helpQsoNextPartial' => 'Dans une pile //, le partiel suivant après la saisie du contact en cours',
			'settings.radio.cwMessages.helpQsoName' => 'Leur prénom, tel que saisi ou sinon issu de la recherche',
			'settings.radio.cwMessages.helpQsoState' => 'Leur état, tel que saisi ou sinon issu de la recherche',
			'settings.radio.cwMessages.helpKeyerMsg' => 'Le message 1 tel qu\'il serait envoyé, à l\'intérieur d\'un autre message. Valable pour les messages 1 à 8',
			'settings.radio.cwMessages.helpQsoRst' => 'Le report que vous envoyez',
			'settings.radio.cwMessages.helpQsoSerial' => 'Votre numéro de série, dans un concours qui en envoie un',
			'settings.radio.cwMessages.helpPad' => 'Complète avec des zéros jusqu\'à ce nombre de chiffres : 7 est envoyé 007',
			'settings.radio.cwMessages.helpCut' => 'Chiffres abrégés, T pour 0 et N pour 9 : 599 est envoyé 5NN',
			'settings.radio.cwMessages.helpCutDigits' => 'Choisit les chiffres à abréger, entre guillemets — 0 est T, 1 est A, 5 est E, 9 est N',
			'settings.radio.cwMessages.helpFullExample' => 'Exemple complet :',
			'settings.radio.cwMessages.helpExample' => 'Envoie W1AW 5NN TT7',
			'settings.radio.cwMessages.helpEsmIntro' => 'Avec Entrée envoie les messages activé, Entrée envoie les messages selon leur touche de fonction, comme dans N1MM. Le jeu Messages ESM commence par ceux-ci :',
			'settings.radio.cwMessages.helpEsmCq' => 'En Run, Entrée avec le champ indicatif vide lance un appel CQ',
			'settings.radio.cwMessages.helpEsmExchange' => 'Votre échange : après leur indicatif en Run, après leur réponse en S&P',
			'settings.radio.cwMessages.helpEsmThanks' => 'Remerciements, une fois le contact saisi : ses valeurs désignent le contact suivant, pas celui-ci',
			'settings.radio.cwMessages.helpEsmMyCall' => 'En S&P, votre indicatif à la station à laquelle vous répondez',
			'settings.radio.cwMessages.helpEsmHisCall' => 'En Run, leur indicatif avant votre échange',
			'settings.radio.cwMessages.helpEsmAgain' => 'Redemande quand rien de leur échange n\'a été copié',
			'settings.radio.cwMessages.helpEsmStackThanks' => 'F3 suggéré pour les piles // : TU part après la saisie du contact, donc il remercie, puis appelle la station suivante de la pile et envoie votre échange, ou redemande un partiel (TU KR?) ; s\'il n\'en reste aucune, juste TU',
			'settings.radio.voiceMessages.title' => 'Messages vocaux',
			'settings.radio.voiceMessages.notSupported' => 'La radio actuelle ne prend pas en charge les messages vocaux',
			'settings.radio.voiceMessages.description' => 'Utilise les mémoires vocales de la radio',
			'settings.radio.voiceMessages.key' => ({required Object n}) => 'M${n}',
			'settings.radio.voiceMessages.messageTitle' => ({required Object n}) => 'Mémoire vocale (${n})',
			'settings.radio.voiceMessages.labelField' => 'Libellé',
			'settings.radio.voiceMessages.labelKey' => ({required Object n}) => 'Libellé de la mémoire vocale ${n}',
			'settings.radio.voiceMessages.durationSeconds' => ({required Object n}) => '${n} s',
			'settings.radio.voiceMessages.emptyOnRadio' => 'Vide',
			'settings.radio.voiceMessages.notMeasured' => 'Durée inconnue',
			'settings.radio.voiceMessages.playButton' => 'Lire',
			'settings.radio.voiceMessages.recordButton' => 'Enregistrer',
			'settings.radio.voiceMessages.stopButton' => 'Arrêter',
			'settings.radio.voiceMessages.repeat' => 'Répéter le message n°1',
			'settings.radio.voiceMessages.repeatOff' => 'Non',
			'settings.radio.voiceMessages.repeatAfter' => ({required Object n}) => 'Après ${n} secondes',
			'settings.radio.voiceMessages.recordHelpTitle' => ({required Object model}) => 'Notes pour ${model} :',
			'settings.radio.voiceMessages.namedOnDevice' => ({required Object device}) => 'Ces mémoires sont dans la radio de ${device}. Leurs noms et durées appartiennent à cet appareil.',
			'settings.radio.voiceMessages.namedOnRadio' => 'Enregistré dans la radio, où ses autres clients le voient aussi.',
			'settings.radio.voiceMessages.recordHelpYaesuDvs' => 'Attendez l\'indicateur [REC] sur la radio, puis maintenez le bouton PTT et enregistrez votre message. Terminez en appuyant sur le bouton ARRÊTER ici dans l\'application avant de relâcher le PTT pour éviter les clics indésirables.',
			'settings.radio.voiceMessages.recordHelpFt891' => 'Attendez que l\'indicateur [REC] clignote au moins quatre fois, puis maintenez le bouton PTT et enregistrez votre message. Terminez en appuyant sur le bouton ARRÊTER ici dans l\'application avant de relâcher le PTT pour éviter les clics indésirables.',
			'settings.radio.voiceMessages.pill' => 'Voix',
			'settings.radio.voiceMessages.play' => ({required Object n}) => 'Lire la mémoire ${n}',
			'settings.radio.voiceMessages.stop' => 'Arrêter',
			'settings.radio.voiceMessages.record' => ({required Object n}) => 'Enregistrer la mémoire ${n}',
			'settings.radio.voiceMessages.stopRecording' => 'Arrêter l\'enregistrement',
			'settings.radio.voiceMessages.playing' => 'Lecture…',
			'settings.radio.voiceMessages.recording' => 'Enregistrement…',
			'settings.radio.voiceMessages.playingMemory' => ({required Object label}) => 'Lecture de ${label}',
			'settings.radio.voiceMessages.recordingMemory' => ({required Object label}) => 'Enregistrement de ${label}',
			'settings.radio.voiceMessages.doubtful' => 'La radio l\'a-t-elle joué ? Elle s\'est déclarée inactive aussitôt.',
			'settings.radio.voiceMessages.recordOnRadio' => 'Les mémoires doivent être enregistrées sur la radio elle-même.',
			'settings.radio.avoidZeroBeat.title' => 'Éviter le battement nul sur les spots',
			'settings.radio.avoidZeroBeat.descriptionOn' => 'Avec une radio connectée, accord à quelques Hz d\'un spot CW, pour que tous ceux qui répondent n\'appellent pas sur la même note.',
			'settings.radio.avoidZeroBeat.descriptionOff' => 'Accord exactement sur la fréquence spottée.',
			'settings.radio.zeroBeatRange.title' => 'Battement nul : plage d\'évitement',
			'settings.radio.zeroBeatRange.description' => 'À quelle distance de la fréquence spottée se placer, de part et d\'autre. Le décalage n\'est jamais proche de zéro — ce serait à nouveau un battement nul.',
			'settings.help.title' => 'Aide et ressources',
			'settings.help.description' => 'Communauté et assistance',
			'settings.help.forums' => 'Forums Ham2K',
			'settings.help.forumsDescription' => 'Trouvez de l\'aide, donnez un avis, discutez d\'idées…',
			'settings.help.chat' => 'Chat Ham2K',
			'settings.help.chatDescription' => 'Le serveur Discord de notre communauté en ligne',
			'settings.help.youtube' => 'Ham2K YouTube',
			'settings.help.youtubeDescription' => 'Vidéos et diffusions en direct',
			'settings.help.instagram' => 'Ham2K Instagram',
			'settings.help.instagramDescription' => 'Parce qu\'on ne peut pas avoir trop de photos…',
			'settings.help.bluesky' => 'Ham2K BlueSky',
			'settings.help.blueskyDescription' => 'Suivez-nous pour des nouvelles et des mises à jour',
			'settings.help.contact' => 'Contactez-nous',
			'settings.help.contactDescription' => 'help@ham2k.com — mais essayez d\'abord les forums ou le chat !',
			'settings.exports.title' => 'Exports',
			'settings.map.title' => 'Cartes',
			'settings.map.style.title' => 'Style de carte',
			'settings.map.styleOpts.automatic' => 'Automatique',
			'settings.map.styleOpts.liberty' => 'Liberty',
			'settings.map.styleOpts.bright' => 'Bright',
			'settings.map.styleOpts.positron' => 'Positron',
			'settings.map.styleOpts.voyager' => 'Voyager',
			'settings.map.styleOpts.darkMatter' => 'Dark Matter',
			'settings.privacy.title' => 'Confidentialité',
			'settings.privacy.shareAppData.title' => 'Partager les données d\'utilisation de l\'application',
			'settings.privacy.shareAppData.descriptionOn' => 'Vous nous aidez à améliorer l\'application en partageant des données d\'utilisation, de configuration, de plantage et de performance',
			'settings.privacy.shareAppData.descriptionOff' => 'Données d\'utilisation de l\'application gardées privées.\nL\'équipe Ham2K ne pourra pas détecter les plantages ni d\'autres problèmes.',
			'settings.privacy.shareOpData.title' => 'Partager les données d\'opération',
			'settings.privacy.shareOpData.descriptionOn' => 'Partage public de certaines données d\'opération et avec d\'autres utilisateurs',
			'settings.privacy.shareOpData.descriptionOff' => 'Données d\'opération gardées privées',
			'settings.privacy.privacyPolicy' => 'Politique de confidentialité',
			'settings.privacy.termsOfService' => 'Conditions d\'utilisation',
			'settings.operatorCall' => 'Indicatif de l\'opérateur',
			'settings.sync.title' => 'Synchronisation cloud',
			'settings.sync.moreSettings' => 'Plus de paramètres de synchronisation',
			'settings.sync.enable' => 'Activer la synchronisation',
			'settings.sync.deviceKey' => 'Clé de l\'appareil',
			'settings.peers.title' => 'Appareils pairs',
			'settings.peers.enable' => 'Se connecter à d\'autres appareils',
			'settings.peers.enableDescription' => 'Permettre de partager les opérations, la saisie, le CAT et le GPS avec d\'autres appareils sur le réseau local',
			'settings.peers.bleEnable' => 'Se connecter en Bluetooth',
			'settings.peers.bleDescription' => 'Utiliser le Bluetooth LE pour se connecter même sans réseau local',
			'settings.peers.thisDevice' => 'Cet appareil',
			'settings.peers.deviceName' => 'Nom',
			'settings.peers.deviceNameHint' => 'Comment cet appareil apparaît aux autres appareils',
			'settings.peers.pairedDevices' => 'Appareils liés',
			'settings.peers.noPairedDevices' => 'Aucun appareil lié pour l\'instant. Activez cette option sur un autre appareil de ce réseau pour les lier.',
			'settings.peers.deviceListProblem' => ({required Object error}) => 'Impossible de lire vos appareils liés : ${error}',
			'settings.peers.nearby' => 'À proximité',
			'settings.peers.connected' => 'Connecté',
			'settings.peers.viaBluetooth' => 'via Bluetooth',
			'settings.peers.connecting' => 'Connexion…',
			'settings.peers.syncing' => 'Synchronisation…',
			'settings.peers.waitingForThem' => 'En attente de l\'autre appareil',
			'settings.peers.notConnected' => 'Non connecté',
			'settings.peers.wantsToPair' => 'veut partager cette opération',
			'settings.peers.allow' => 'Autoriser',
			'settings.peers.link' => 'Lier',
			'settings.peers.reject' => 'Refuser',
			'settings.peers.forget' => 'Oublier',
			'settings.peers.forgetTitle' => ({required Object name}) => 'Oublier ${name} ?',
			'settings.peers.forgetBody' => 'Il cessera de se synchroniser avec cet appareil. Vous pourrez l\'autoriser à nouveau plus tard, et les contacts déjà saisis sont conservés.',
			'settings.peers.pairTitle' => ({required Object name}) => 'Lier avec ${name}',
			'settings.peers.pairBody' => 'Cet appareil est sur votre réseau local et veut se connecter.',
			'settings.peers.pairBodyBle' => 'Cet appareil est à proximité et veut se connecter en Bluetooth LE.',
			'settings.peers.pairIdLabel' => 'ID de l\'appareil',
			'settings.peers.pairWarning' => 'Ne liez que des appareils que vous reconnaissez. N\'importe quel appareil de ce réseau peut envoyer une demande.',
			'settings.peers.pairWarningBle' => 'Ne liez que des appareils que vous reconnaissez. N\'importe quel appareil à proximité peut envoyer une demande.',
			'settings.peers.problem' => ({required Object error}) => 'Impossible d\'accéder au réseau local : ${error}',
			'settings.peers.bleProblem' => ({required Object error}) => 'Bluetooth : ${error}',
			'settings.peers.statusConnected' => ({required Object device}) => 'Connecté à ${device}',
			'settings.peers.statusLost' => ({required Object device}) => 'Connexion perdue avec ${device}',
			'settings.peers.statusPerma' => ({required Object connected, required Object linked}) => 'Appareils pairs : ${connected} sur ${linked} connectés',
			'settings.peers.screenEnable' => 'Partager les écrans et fenêtres',
			'settings.peers.screenDescription' => 'Permettre à d\'autres appareils d\'afficher des écrans ou des fenêtres de cet ordinateur',
			'settings.peers.screenSources' => 'Écrans et fenêtres',
			'settings.peers.screenRefresh' => 'Actualiser la liste',
			'settings.peers.screenUnsupportedPlatform' => 'Cet appareil ne peut pas partager son écran. macOS le peut ; tout appareil peut afficher un écran partagé par un autre.',
			'settings.peers.screenUnsupportedVersion' => 'Le partage d\'écran nécessite macOS 12.3 ou ultérieur. Cet appareil peut tout de même afficher un écran partagé par un autre.',
			'settings.peers.screenNeedsPermission' => 'macOS a besoin de votre autorisation pour enregistrer l\'écran avant que cette application puisse en partager un.',
			'settings.peers.screenGrantPermission' => 'Demander l\'autorisation',
			'settings.peers.screenRelaunchAfterGranting' => 'Autorisez-la dans Réglages Système, sous Confidentialité et sécurité → Enregistrement de l\'écran, puis quittez et rouvrez cette application — macOS ne signale le changement à une application qu\'à son prochain lancement.',
			'settings.peers.screenProblem' => ({required Object error}) => 'Partage d\'écran : ${error}',
			'settings.peers.screenChooseTitle' => 'Choisir ce qu\'il faut partager',
			'settings.peers.screenChooseButton' => 'Choisir ce qu\'il faut partager…',
			'settings.peers.screenTabScreens' => 'Écrans',
			'settings.peers.screenTabApps' => 'Applications',
			'settings.peers.screenTabWindows' => 'Fenêtres',
			'settings.peers.screenTabEmpty' => 'Rien de ce type n\'a été trouvé.',
			'settings.peers.screenSharedSummaryNone' => 'Rien de choisi pour l\'instant.',
			'settings.peers.screenThisDevice' => 'Cet appareil',
			'settings.peers.screenSharedTo' => ({required Object devices}) => 'Affiché sur ${devices}',
			'settings.peers.screenSharedToNobody' => 'Non affiché',
			'settings.peers.screenStopSharing' => ({required Object name}) => 'Arrêter de partager ${name}',
			'settings.developerMode' => 'Mode développeur',
			'settings.syncPanel.configuration' => 'Configuration de la synchronisation',
			'settings.syncPanel.enableTitle' => 'Synchroniser avec Ham2K Log Filer',
			'settings.syncPanel.enabledDescription' => 'Sauvegarde et synchronisation de votre journal entre vos appareils',
			'settings.syncPanel.disabledDescription' => 'Désactivé — les données restent uniquement sur cet appareil',
			'settings.syncPanel.syncing' => 'Synchronisation',
			'settings.syncPanel.account' => 'Compte',
			'settings.syncPanel.refresh' => 'Rafraîchir',
			'settings.syncPanel.switchAccounts' => 'Changer de compte',
			'settings.syncPanel.switchAccountsDescription' => 'Lier cet appareil à un autre compte avec un code QR ou un e-mail',
			'settings.syncPanel.connectionRequests' => 'Demandes de connexion',
			'settings.syncPanel.connectionRequestsDescription' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Un appareil attend de rejoindre ce compte', other: '${n} appareils attendent de rejoindre ce compte', ), 
			'settings.syncPanel.accountEmailTitle' => 'E-mail du compte',
			'settings.syncPanel.accountEmailSent' => ({required Object email}) => 'Confirmation envoyée à ${email}. Ouvrez le lien reçu pour terminer la modification.',
			'settings.syncPanel.resendConfirmation' => 'Renvoyer l\'e-mail de confirmation',
			'settings.syncPanel.resendConfirmationDescription' => ({required Object email}) => 'En attente de ${email}',
			'settings.syncPanel.accountEmailResent' => ({required Object email}) => 'Renvoyé à ${email}.',
			'settings.syncPanel.deviceLinked' => 'Cet appareil est maintenant lié à ce compte.',
			'settings.syncPanel.checking' => 'Vérification…',
			'settings.syncPanel.notLinked' => 'Pas encore lié',
			'settings.syncPanel.linkedAccount' => ({required Object account, required Object id}) => '${account} (#${id})',
			'settings.syncPanel.replaceDialogTitle' => 'Remplacer les données locales ?',
			'settings.syncPanel.countOperations' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${n} opération', other: '${n} opérations', ), 
			'settings.syncPanel.countQsos' => ({required num count, required Object n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${n} QSO', other: '${n} QSOs', ), 
			'settings.syncPanel.counts' => 'Données synchronisées',
			'settings.syncPanel.countsLocal' => ({required Object qsos, required Object operations}) => 'Cet appareil : ${qsos} · ${operations}',
			'settings.syncPanel.countsPending' => ({required Object items}) => 'En attente d\'envoi : ${items}',
			'settings.syncPanel.countsServer' => ({required Object qsos, required Object operations}) => 'Serveur : ${qsos} · ${operations}',
			'settings.syncPanel.countsLocalChecking' => 'Cet appareil : vérification…',
			'settings.syncPanel.countsServerChecking' => 'Serveur : vérification…',
			'settings.syncPanel.countsServerUnavailable' => 'Serveur : indisponible',
			'settings.syncPanel.replaceDialogBody' => ({required Object operations, required Object qsos}) => 'Cela sauvegarde puis efface ${operations} et ${qsos} de cet appareil, puis télécharge à la place les données du compte. La sauvegarde reste dans la base de données de cet appareil.',
			'settings.syncPanel.replace' => 'Remplacer',
			'settings.syncPanel.pendingBannerTitle' => 'Nouveau compte Ham2K Log Filer détecté',
			'settings.syncPanel.pendingBannerBody' => 'Conservez les opérations et QSOs existants de cet appareil et fusionnez-les dans le compte, ou remplacez-les par les données du compte (une sauvegarde reste sur cet appareil dans les deux cas).',
			'settings.syncPanel.combine' => 'Fusionner',
			'settings.syncPanel.authIssueTitle' => 'La synchronisation ne peut pas se connecter',
			'settings.syncPanel.authIssueText' => 'Ham2K Log Filer refuse toujours cet appareil. Vérifiez votre indicatif dans les paramètres de synchronisation.',
			'settings.syncPanel.openSettings' => 'Ouvrir les paramètres de synchronisation',
			'settings.accounts.title' => 'Comptes, services et sources de données',
			'settings.accounts.none' => 'Aucune extension active avec un compte',
			'settings.accounts.notConfigured' => 'Non configuré',
			'settings.accounts.connected' => 'Connecté',
			'settings.accounts.cancelLogin' => 'Annuler la connexion',
			'settings.accounts.openInBrowser' => 'Ouvrir dans le navigateur',
			'settings.accounts.loggedInAs' => ({required Object identity}) => 'Connecté en tant que ${identity}',
			'settings.accounts.pressSaveToKeep' => 'Appuyez sur Enregistrer pour garder ce compte connecté.',
			'settings.accounts.connectedTo' => ({required Object label}) => 'Connecté à ${label}',
			'settings.accounts.connect' => 'Connecter',
			'settings.accounts.disconnect' => 'Déconnecter',
			'settings.accounts.connectedAs' => 'Connecté en tant que',
			'settings.accounts.test' => 'Tester',
			'settings.accounts.saveFailed' => ({required Object error}) => 'Échec de l\'enregistrement : ${error}',
			'settings.accounts.loginFailed' => ({required Object error}) => 'Échec de la connexion : ${error}',
			'settings.accounts.lookupFailed' => 'Les comptes sont indisponibles pour le moment — réessayez dans un instant',
			'settings.accounts.browserLoginTitle' => 'Terminez la connexion dans votre navigateur web',
			'settings.accounts.browserLoginSteps' => ({required Object prefix}) => 'Une fois terminé, le navigateur tentera d\'ouvrir un lien commençant par "${prefix}". Votre ordinateur n\'a très probablement rien pour l\'ouvrir : copiez donc ce lien (depuis la barre d\'adresse, ou depuis la page d\'erreur affichée par le navigateur) et collez-le ici.',
			'settings.accounts.browserLoginNotOpened' => ({required Object prefix}) => 'Ham2K Logger n\'a pas pu ouvrir votre navigateur. Copiez le lien de connexion ci-dessous et ouvrez-le vous-même, puis copiez le lien vers lequel il vous redirige (il commence par "${prefix}") et collez-le ici.',
			'settings.accounts.copyLoginLink' => 'Copier le lien de connexion',
			'settings.accounts.pastedLinkLabel' => 'Collez le lien ici',
			'settings.accounts.finishLogin' => 'Terminer la connexion',
			'settings.accounts.pastedLinkNotARedirect' => ({required Object prefix}) => 'Ce n\'est pas le lien de connexion — il doit commencer par "${prefix}".',
			'settings.accounts.pastedLinkWrongLogin' => 'Ce lien appartient à une autre tentative de connexion. Fermez cette page et connectez-vous à nouveau.',
			'settings.accounts.pastedLinkNoCode' => 'Ce lien ne contient pas de code de connexion. Terminez d\'abord la connexion, puis copiez le lien vers lequel elle vous redirige.',
			'settings.accounts.pastedLinkMalformed' => 'Ce lien semble tronqué. Copiez-le en entier et collez-le à nouveau.',
			'settings.accounts.relayLoginWaiting' => 'En attente de la fin de votre connexion — la suite se fera automatiquement.',
			'settings.accounts.loginNoResponse' => 'Cet appareil n\'a pas encore reçu de réponse de la connexion. Si vous l\'avez déjà terminée dans votre navigateur, annulez et essayez de vous connecter à nouveau.',
			'settings.accounts.relayLoginNotOpened' => 'Ham2K Logger n\'a pas pu ouvrir votre navigateur automatiquement. Utilisez le bouton ci-dessous pour ouvrir vous-même la page de connexion.',
			'settings.accounts.relayLoginUnavailable' => 'Impossible de joindre le serveur de synchronisation nécessaire pour terminer cette connexion. Vérifiez votre connexion et réessayez.',
			'settings.accounts.loginIncompleteResponse' => 'Cette tentative de connexion n\'a pas abouti correctement. Essayez de vous connecter à nouveau.',
			'settings.accounts.noKeyringTitle' => 'Les identifiants de compte ne peuvent pas être enregistrés',
			'settings.accounts.noKeyringText' => 'Ham2K Logger ne peut pas joindre de service de trousseau de clés sur cet ordinateur : les identifiants de compte ne peuvent être ni stockés ni lus — la connexion d\'un compte échouera tant que ce n\'est pas réglé. Installez et démarrez **gnome-keyring**, **KWallet** ou **KeePassXC**, ou déverrouillez le trousseau que vous avez déjà, puis redémarrez. La saisie, les exports et les fichiers de données ne sont pas affectés ; la synchronisation du journal reste désactivée en attendant.',
			'settings.accounts.noKeyringInline' => 'Les identifiants ne peuvent pas être enregistrés : le trousseau de clés de cet ordinateur est injoignable. Installez et démarrez gnome-keyring, KWallet ou KeePassXC, ou déverrouillez celui que vous avez.',
			'settings.accounts.noSecureStorageInline' => 'Les identifiants ne peuvent pas être enregistrés : le stockage sécurisé de cet ordinateur est injoignable.',
			'settings.station.title' => 'Configuration de la station et contrôle CAT',
			'settings.station.none' => 'Aucun équipement configuré',
			'settings.station.add' => 'Ajouter',
			'settings.station.addTitle' => 'Ajouter un équipement',
			'settings.station.searchHint' => 'Rechercher un équipement',
			'settings.station.noMatches' => 'Aucun équipement ne correspond',
			'settings.station.detectedEquipment' => 'Équipements détectés',
			'settings.station.discoveryUnavailable' => ({required Object error}) => 'Impossible d\'écouter les radios : ${error}',
			'settings.station.edit' => 'Modifier l\'équipement',
			'settings.station.name' => 'Nom',
			'settings.station.nameDescription' => 'Comment vous l\'appelez — « Radio de gauche ». Facultatif.',
			'settings.station.transport' => 'Connexion',
			'settings.station.host' => 'Adresse',
			'settings.station.hostDescription' => 'Le nom d\'hôte ou l\'adresse IP de la radio sur votre réseau.',
			'settings.station.port' => 'Port',
			'settings.station.hostRequired' => 'Une adresse est requise',
			'settings.station.portInvalid' => 'Le port doit être compris entre 1 et 65535',
			'settings.station.connect' => 'Connecter',
			'settings.station.disconnect' => 'Déconnecter',
			'settings.station.remove' => 'Retirer',
			'settings.station.removeTitle' => ({required Object name}) => 'Retirer ${name} ?',
			'settings.station.removeMessage' => 'Cela le retire seulement de l\'application. Les réglages de l\'équipement restent inchangés.',
			'settings.station.unknownType' => ({required Object typeKey}) => 'Type d\'équipement non reconnu « ${typeKey} »',
			'settings.station.report' => 'Signaler',
			'settings.station.reportTitle' => 'Signaler cette radio',
			'settings.station.reportIntro' => 'Dites-nous quelle radio c\'est vraiment et comment ça s\'est passé. Votre signalement devient une fiche lue par l\'équipe Ham2K, et ce que vous écrivez pour la faire fonctionner pourra aider le prochain opérateur avec le même poste.',
			'settings.station.reportManufacturer' => 'Fabricant',
			'settings.station.reportManufacturerDescription' => 'Qui la fabrique — Icom, Yaesu, Kenwood, Elecraft…',
			'settings.station.reportManufacturerRequired' => 'Un fabricant est requis',
			'settings.station.reportModel' => 'Modèle',
			'settings.station.reportModelDescription' => 'Le modèle, tel que la radio elle-même le nomme — « IC-7300 », « FT-991A ».',
			'settings.station.reportModelRequired' => 'Un modèle est requis',
			'settings.station.reportOutcome' => 'Comment ça s\'est passé ?',
			'settings.station.reportOutcomeWorks' => 'A bien fonctionné',
			'settings.station.reportOutcomeIssues' => 'A fonctionné, avec des problèmes',
			'settings.station.reportOutcomeFails' => 'N\'a pas fonctionné du tout',
			'settings.station.reportOutcomeRequired' => 'Dites-nous comment ça s\'est passé',
			'settings.station.reportComments' => 'Commentaires',
			'settings.station.reportCommentsPlaceholder' => 'Ce qui a marché, ce qui n\'a pas marché, ce qui vous a surpris.',
			'settings.station.reportHints' => 'Conseils de dépannage',
			'settings.station.reportHintsPlaceholder' => 'Voulez-vous suggérer des conseils de dépannage pour d\'autres utilisateurs ?',
			'settings.station.reportSend' => 'Envoyer le signalement',
			'settings.station.reportSending' => 'Envoi de votre signalement…',
			'settings.station.reportSent' => ({required Object ref}) => 'Merci — votre signalement a été enregistré sous ${ref}.',
			'settings.station.reportSentNoRef' => 'Merci — votre signalement a été envoyé.',
			'settings.station.reportFailed' => ({required Object error}) => 'Le signalement n\'a pas été envoyé : ${error}',
			'settings.station.troubleshootingNotes' => 'Notes de dépannage',
			'settings.station.mainVfo' => 'VFO principal',
			'settings.station.useAsMainVfo' => 'Utiliser comme VFO principal',
			'settings.station.serialPort' => 'Port série',
			'settings.station.serialPortDescription' => 'Le port sur lequel apparaît l\'interface CAT de la radio.',
			'settings.station.serialPortNone' => 'Aucun port série trouvé',
			'settings.station.serialPortRequired' => 'Choisissez un port série',
			'settings.station.serialPortOrdinal' => ({required Object n, required Object total}) => 'port ${n} sur ${total}',
			'settings.station.serialPortSuggested' => 'suggéré',
			'settings.station.serialPortJustNow' => 'Connecté récemment',
			'settings.station.serialDeviceRequest' => 'Ajouter un périphérique USB…',
			'settings.station.baudRate' => 'Vitesse (bauds)',
			'settings.station.baudRateDescription' => 'Doit correspondre au menu CAT de la radio. En cas de différence, la radio renvoie des données incohérentes sans aucune erreur.',
			'settings.station.serialRtsHigh' => 'Maintenir RTS haut',
			'settings.station.serialRtsHighDescription' => 'Uniquement pour une radio qui attend RTS avant de répondre, comme une Yaesu avec CAT RTS activé. Sur un Digirig, un SignaLink et la plupart des câbles faits maison, RTS est le PTT, et le maintenir haut passe en émission.',
			'settings.station.serialDtrHigh' => 'Maintenir DTR haut',
			'settings.station.serialDtrHighDescription' => 'Uniquement pour une interface CAT alimentée par DTR, comme certains câbles RS-232 pour le FT-817. Sur beaucoup de câbles, DTR manipule la CW ou le PTT, et le maintenir haut passe en émission.',
			'settings.station.civAddress' => 'Adresse CI-V de la radio',
			'settings.station.civAddressDescription' => 'En hexadécimal, comme affiché dans le menu CI-V de la radio. L\'IC-705 est livré avec A4.',
			'settings.station.civAddressInvalid' => 'Une adresse CI-V comporte deux chiffres hexadécimaux, de 01 à FF',
			'settings.station.flexSlice' => 'Slice',
			'settings.station.flexSliceDescription' => 'Quelle slice de la radio cette connexion lit et accorde.',
			'settings.station.flexSliceLabel' => ({required Object letter}) => 'Slice ${letter}',
			'settings.station.flexSliceInvalid' => 'Choisissez l\'une des slices de la radio, de A à H',
			'settings.station.flexSliceMissing' => ({required Object letter}) => 'La slice ${letter} n\'est pas utilisée sur cette radio — choisissez une autre slice, ou créez-la dans SmartSDR',
			'settings.station.channelNotInUse' => 'non utilisée',
			'settings.station.channelHeldByUnknown' => 'utilisée par un autre programme',
			'settings.station.flexNoSlices' => 'Cette radio n\'a signalé aucune slice — vérifiez que SmartSDR est lancé et que ce client peut s\'abonner',
			'settings.station.spectrumUnsupported' => 'Cette radio n\'envoie pas de spectre via CAT',
			'settings.station.spectrumRequiresBaud' => 'Nécessite le CAT à 115200 bps',
			'settings.station.spectrumNoRadio' => 'Aucune radio connectée',
			'settings.station.spectrumWaiting' => 'En attente du spectre de la radio…',
			'settings.station.spectrumUnavailable' => 'L\'affichage du spectre n\'est pas disponible',
			'settings.station.spectrumNoDaxChannel' => 'Tous les canaux DAX IQ de cette radio sont utilisés',
			'settings.station.spectrumNoPanadapter' => 'Cette slice n\'a pas de panadapter sur la radio',
			'settings.station.spectrumStreamRefused' => ({required Object code}) => 'La radio a refusé un flux DAX IQ (erreur ${code})',
			'settings.station.spectrumNoUdp' => 'Les données de spectre de la radio ne parviennent pas à cet appareil',
			'settings.station.spectrumScopeRefused' => 'La radio a refusé ses commandes de scope',
			'settings.station.spectrumOutOfRange' => 'Le scope de la radio est réglé hors de la plage qu\'il peut afficher',
			'settings.station.n3fjpNoRig' => 'N3FJP n\'a pas d\'interface radio configurée : ceci suit donc ce qui est tapé dans N3FJP, pas une radio',
			'settings.station.winkeyerKeyPort' => 'Sortie de manipulation',
			'settings.station.winkeyerKeyPortDescription' => 'Laquelle des deux prises de sortie du manipulateur est reliée à votre radio.',
			'settings.station.winkeyerKeyPortLabel' => ({required Object n}) => 'Port ${n}',
			'settings.station.winkeyerPtt' => 'Utiliser le PTT du manipulateur',
			'settings.station.winkeyerPttDescription' => 'Active la ligne PTT sur la même prise, pour un amplificateur ou une radio qui en a besoin. Laissez désactivé pour une radio manipulée par sa prise de manipulateur.',
			'settings.station.winkeyerNoAnswer' => 'Aucun WinKeyer n\'a répondu sur ce port',
			'settings.station.winkeyerStoppedAnswering' => 'Le WinKeyer a cessé de répondre pendant l\'envoi ; le message a été abandonné',
			'settings.station.radioUser' => 'Nom d\'utilisateur de la radio',
			'settings.station.radioPass' => 'Mot de passe de la radio',
			'settings.station.radioLoginDescription' => 'L\'identifiant Réseau → Remote de la radio, pas votre mot de passe WiFi.',
			'settings.station.radioUserRequired' => 'Le nom d\'utilisateur de contrôle à distance de la radio est requis',
			'settings.station.connectFailedBusy' => 'Le périphérique est occupé',
			'settings.station.connectFailedDenied' => 'Accès refusé',
			'settings.station.connectFailedDevice' => 'Périphérique introuvable',
			'settings.station.connectFailedLines' => 'RTS/DTR n\'ont pas pu être maintenus comme réglé, le port a donc été fermé. Un autre programme a peut-être laissé le contrôle de flux matériel activé — débranchez et rebranchez le câble.',
			'settings.station.connectFailedNetwork' => 'Impossible de trouver la radio sur le réseau. Vérifiez son adresse, et qu\'elle est allumée et joignable.',
			'settings.station.connectFailedTimeout' => 'La radio n\'a pas répondu à temps. Vérifiez qu\'elle est allumée et joignable.',
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
			'settings.station.models.yaesuGeneric' => 'Yaesu - Générique',
			'settings.station.models.icomGeneric' => 'Icom - Générique',
			'settings.station.models.kenwoodGeneric' => 'Kenwood - Générique',
			'settings.station.models.ts590sg' => 'Kenwood TS-590SG',
			'settings.station.models.ts480' => 'Kenwood TS-480',
			'settings.station.models.qmx' => 'QRP Labs QMX',
			'settings.station.models.fx4cr' => 'BG2FX FX-4CR',
			'settings.station.models.qcx' => 'QRP Labs QCX',
			'settings.station.models.elecraftGeneric' => 'Elecraft - Générique',
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
			'settings.station.models.rigctld' => 'Radio pilotée via rigctld',
			'settings.station.models.rigctldNodeName' => 'Ma radio (via rigctld)',
			'settings.station.models.flrig' => 'Radio pilotée via flrig',
			'settings.station.models.flrigNodeName' => 'Ma radio (via flrig)',
			'settings.station.models.hrd' => 'Radio pilotée via Ham Radio Deluxe®',
			'settings.station.models.hrdNodeName' => 'Ma radio (via HRD)',
			'settings.station.models.n3fjp' => 'Radio pilotée via N3FJP',
			'settings.station.models.n3fjpNodeName' => 'Ma radio (via N3FJP)',
			'settings.station.models.commander' => 'Radio pilotée via DXLab Commander',
			'settings.station.models.commanderNodeName' => 'Ma radio (via Commander)',
			'settings.station.models.antenna' => 'Antenne',
			'settings.station.models.key' => 'Manipulateur CW',
			'settings.station.models.winkeyer' => 'WinKeyer',
			'settings.station.models.placeholderRadio' => 'Radio générique (provisoire)',
			'settings.station.models.placeholderRadioNodeName' => 'Ma radio',
			'settings.station.models.antennaGenius' => '4O3A Antenna Genius',
			'settings.station.models.sierraCoax' => 'Commutateur coaxial Sierra Radio CX-1',
			'settings.station.transports.network' => 'Réseau/WiFi',
			'settings.station.transports.usbSerial' => 'Série USB',
			'settings.station.transports.wifi' => 'Réseau/WiFi',
			'settings.station.transports.bluetoothSerial' => 'Série Bluetooth',
			'settings.station.transports.placeholder' => 'Provisoire',
			'settings.station.troubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.ft891Troubleshooting' => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **CAT RTS doit être sur OFF sur la radio** (menu **05-08** du FT-891). S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse. Sur un Digirig, un SignaLink ou la plupart des câbles faits maison, cette même ligne est le PTT : la lever passerait votre émetteur en émission. Sur le port USB de la radio elle-même, **Maintenir RTS haut** dans Paramètres avancés est l\'alternative.\n- **La vitesse doit correspondre** au CAT RATE de la radio (menu **05-06**). En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.',
			'settings.station.yaesuBinaryTroubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.yaesuBinaryTroubleshooting' => 'Cette radio utilise l\'ancien CAT Yaesu à cinq octets, et elle ne répond pas du tout quand quelque chose cloche. C\'est presque toujours l\'une de ces causes :\n\n- **Le câble doit convertir les niveaux.** La prise CAT à l\'arrière n\'est ni du RS-232 ni de l\'USB ; elle nécessite un CT-62 ou un adaptateur équivalent. Un simple câble audio ou données ne fonctionnera pas pour le CAT.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio (**#14** sur un FT-817, **#19** sur un FT-857 ou FT-897). En cas de différence, la radio ne renvoie rien, et jamais d\'erreur.\n- **Ne laissez jamais rien lever RTS ou DTR sur ce port.** Sur la plupart des câbles pour ces radios, ces lignes sont le PTT et la manipulation. Une ancienne interface alimentée par DTR fait exception : activez **Maintenir DTR haut** dans Paramètres avancés pour celle-ci.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\nCe pilote a été écrit d\'après le tableau CAT publié par Yaesu et n\'a jamais été testé sur l\'une de ces radios. S\'il fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.guohetecTroubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.guohetecTroubleshooting' => 'Le Q900 a deux protocoles CAT, et cette entrée utilise son protocole natif plutôt que l\'imitation du FT-817. Choisissez ici **Guohetec Q900**, pas un FT-817 — l\'imitation prend en charge moins de commandes, et la radio n\'indique pas lequel elle utilise.\n\n- **Le câble USB-C est la liaison CAT**, et il connecte aussi la carte son. La vitesse n\'a pas d\'importance sur ce câble ; le port ignore la valeur réglée.\n- **Ne laissez jamais rien lever RTS ou DTR sur ce port.** Sur un câble série, ces lignes sont le PTT et la manipulation.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Une radio de deuxième génération se comporte différemment** de la première. Appui long sur Menu, puis About : HW 2.0 correspond à la deuxième génération.\n\nCe pilote a été écrit d\'après le protocole publié par le fabricant et n\'a jamais été testé sur l\'une de ces radios. S\'il fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.yaesuTroubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.yaesuTroubleshooting' => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse. Sur un Digirig, un SignaLink ou la plupart des câbles faits maison, cette même ligne est le PTT : la lever passerait votre émetteur en émission. Sur le port USB de la radio elle-même, **Maintenir RTS haut** dans Paramètres avancés est l\'alternative. L\'emplacement de ce réglage varie selon le modèle (menu **05-08** sur un FT-891).\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Les modes suivent la table du FT-891.** La plupart des Yaesu y correspondent, mais une radio qui numérote ses modes différemment affichera et réglera le mauvais mode pour ceux-là. La fréquence n\'est pas concernée.',
			'settings.station.yaesuRs232Troubleshooting' => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **La prise CAT est en RS-232.** Elle nécessite un adaptateur USB-série et un câble DB-9 droit — un câble null-modem croise les lignes, et la radio ne reçoit rien.\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse, sauf si **Maintenir RTS haut** est activé dans Paramètres avancés.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\nCette entrée a été écrite d\'après la documentation CAT publiée et n\'a jamais été testée sur l\'une de ces radios. Si elle fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.yaesuUsbTroubleshooting' => 'La radio reçoit les commandes mais ne répond pas. C\'est presque toujours l\'une de ces causes :\n\n- **Utilisez le premier des deux ports USB de la radio.** Le CAT est normalement sur le premier (le port COM **Enhanced** sous Windows) ; le second (**Standard**) sert au PTT et à la manipulation. Le sélecteur pointe sur le premier chaque fois qu\'il peut distinguer les deux.\n- **CAT RTS doit être sur OFF sur la radio.** S\'il est activé, la radio attend une ligne de handshake que l\'application garde basse, sauf si **Maintenir RTS haut** est activé dans Paramètres avancés.\n- **La vitesse doit correspondre** au menu CAT RATE de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.',
			'settings.station.k4SerialNotes' => 'Branchez la prise USB-B arrière (PC) du K4. USB-PC1 ou USB-PC2 conviennent pour le CAT ; choisissez un port libre et faites correspondre son réglage Serial USB-PCn: Baud Rate sur la radio. HaLo préremplit 38400 ; modifiez-le si nécessaire. Une autre application doit utiliser l\'autre port ou l\'Ethernet.\n\nCette connexion pilote la radio et ses manipulateurs ; elle n\'envoie pas d\'audio à HaLo.',
			'settings.station.k4TcpNotes' => 'Reliez la prise Ethernet du K4 à votre réseau local. Saisissez son nom d\'hôte ou son adresse IP et le port CAT 9200. Il s\'agit du contrôle CAT, pas de la connexion audio distante séparée sur le port 9204.\n\nHaLo pilote la radio et ses manipulateurs sans recevoir d\'audio ni de données de panadapter.',
			'settings.station.k4PowerTimeout' => 'La puissance du K4 n\'a pas été modifiée car la radio n\'a pas confirmé sa plage de sortie. Réessayez.',
			'settings.station.k4PowerRange' => 'La puissance du K4 doit être de 0,1 à 110 W, ou de 0,0001 à 0,01 W quand la sortie milliwatt du transverter est active.',
			'settings.station.elecraftTroubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.elecraftTroubleshooting' => 'Les postes Elecraft parlent le CAT Kenwood, et un KX2 comme un KX3 ont été utilisés ainsi — VFO dans les deux sens, changement de mode et battement nul CW fonctionnent.\n\nSi la radio ne répond pas, c\'est presque toujours l\'une de ces causes :\n\n- **La vitesse doit correspondre** à celle réglée sous **RS232** dans le menu de la radio. Ces radios sont livrées à 38400. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n\n**Si la fréquence est correcte mais pas le mode**, dites-le-nous. Les entrées KX2 et KX3 lisent le mode à une position de la réponse d\'état de la radio que nous avons déterminée sur les postes que nous avons vus, et seul un signalement peut nous apprendre qu\'un firmware le place ailleurs.\n\nLe K3 n\'a fait l\'objet d\'aucun retour, alors dites-nous ce qui se passe si vous en utilisez un. Le K4 a sa propre entrée.',
			'settings.station.kenwoodTroubleshootingTitle' => 'Si la radio se connecte mais n\'affiche aucune fréquence',
			'settings.station.kenwoodTroubleshooting' => 'Ce pilote a fait ses preuves sur les TS-590SG et TS-480 de Kenwood, les QMX et QCX-mini de QRP Labs, et les KX2 et KX3 d\'Elecraft. Le reste de la gamme est écrit d\'après les références CAT publiées : signalez-nous ce qui se passe, dans un sens comme dans l\'autre.\n\nSi la radio ne répond pas, c\'est presque toujours l\'une de ces causes :\n\n- **La vitesse doit correspondre** au menu CAT de la radio. En cas de différence, la radio renvoie des données incohérentes ou rien du tout, et jamais d\'erreur.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.\n- **Certains postes nécessitent d\'activer le CAT** dans le menu avant de répondre.\n\n**Plusieurs interfaces SDR parlent ce même protocole** : cette entrée vaut donc la peine d\'être essayée pour elles aussi ; les postes Elecraft sont listés séparément, sous Elecraft. Si la fréquence est correcte mais que le mode est faux ou absent, c\'est la seule partie qui varie selon les modèles — l\'application le déduit de la radio et, à défaut, le demande directement, donc le mode peut simplement arriver avec un peu de retard.',
			'settings.station.statusConnected' => 'Connecté',
			'settings.station.statusLost' => 'Déconnecté',
			'settings.station.notConfigured' => 'Non configuré',
			'settings.station.currentConfiguration' => 'Configuration actuelle',
			'settings.station.currentTransceiver' => 'Transceiver actuel',
			'settings.station.radioMode' => 'Mode de la radio',
			'settings.station.keyerNotSupported' => 'Non pris en charge par la radio actuelle',
			'settings.station.catControlPreferences' => 'Préférences du contrôle CAT',
			'settings.station.chooseTransceiver' => 'Choisir le transceiver',
			'settings.station.configurationSection' => 'Configuration',
			'settings.station.noTransceiverSelected' => 'Aucun transceiver sélectionné',
			'settings.station.makeMainVfo' => ({required Object name}) => 'Utiliser ${name} pour le VFO principal',
			'settings.station.sectionTransceivers' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, zero: 'Aucun transceiver', one: '${count} transceiver', other: '${count} transceivers', ), 
			'settings.station.sectionAntennas' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} antenne', other: '${count} antennes', ), 
			'settings.station.sectionOtherEquipment' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} autre équipement', other: '${count} autres équipements', ), 
			'settings.station.equipmentInventory' => 'Inventaire des équipements',
			'settings.station.equipmentInUse' => 'Contrôles du transceiver',
			'settings.station.noTransceiver' => 'Aucun',
			'settings.station.peerRadioNotAvailable' => 'Non disponible',
			'settings.station.peerRadioOnDevice' => ({required Object device}) => 'Sur ${device}',
			'settings.station.peerRadioElsewhereTitle' => ({required Object radio}) => '${radio} est sur un autre appareil',
			'settings.station.peerRadioElsewhereMessage' => ({required Object device}) => 'Cette radio est connectée à ${device}. Sa connexion et ses réglages se configurent sur cet appareil.',
			'settings.station.antennaInUse' => 'Antenne utilisée',
			'settings.station.keyInUse' => 'Manipulateur utilisé',
			'settings.station.noneSelected' => 'Aucun',
			'settings.station.moreSettings' => 'Plus de paramètres',
			'settings.station.icomCivTroubleshootingTitle' => 'Si deux ports série apparaissent pour la même radio',
			'settings.station.icomCivTroubleshooting' => 'Plusieurs radios Icom, dont l\'IC-705, présentent **deux** ports série USB à la fois (Icom les appelle Port A et Port B), tous deux réglés en CI-V par défaut. Ni cette application ni votre système ne peuvent les distinguer au-delà de cela : le même identifiant fabricant/produit USB apparaît simplement deux fois, parfois marqué ici d\'un suffixe `#2`. **Le Port A est généralement le bon** — normalement le premier listé par votre système ou votre navigateur, et quand cette application peut distinguer les deux ports, elle le marque comme suggéré. Si les commandes partent et que la radio ne répond jamais, essayez l\'autre port.',
			'settings.station.civAddressTroubleshootingTitle' => 'Si la radio ne répond jamais',
			'settings.station.civAddressTroubleshooting' => '- **L\'adresse CI-V doit correspondre** au menu de la radio. Cette entrée préremplit l\'adresse d\'origine du modèle, mais c\'est justement sur un poste partageant un bus CI-V qu\'elle est modifiée. Une trame envoyée à la mauvaise adresse est ignorée en silence, exactement comme avec un câble défectueux.\n- **La vitesse doit correspondre** au CI-V BAUD RATE de la radio (en USB, CI-V USB Baud Rate). Réglez la radio sur la même valeur que celle affichée ici, **pas sur Auto**. En Auto, certaines radios, dont l\'IC-7300, se connectent puis cessent de répondre au bout d\'une minute environ.\n- **Une autre application occupe peut-être le port** : WSJT-X, fldigi et rigctld le gardent tous ouvert.',
			'settings.station.ic7300Mk2Note' => '\n- L\'**IC-7300 MK2** est livré avec l\'adresse `B6`, et non `94` préremplie ici — choisissez plutôt l\'entrée IC-7300 MK2.',
			'settings.station.ic705PortNote' => '\n- L\'**IC-705** présente deux ports série USB, tous deux nommés d\'après la radio. Le CI-V est sur le **premier**, vers lequel pointe le sélecteur chaque fois qu\'il peut distinguer les deux.',
			'settings.station.ic7760PortNote' => '\n- L\'**IC-7760** utilise le CI-V sur le **Port A** des deux ports série USB qu\'il présente.',
			'settings.station.x6100PortNote' => '\n- Le **X6100** utilise le CI-V sur son port **DEV** — le second des deux ports série qu\'il présente, et celui vers lequel pointe le sélecteur.',
			'settings.station.rigctldTroubleshootingTitle' => 'Si l\'application ne peut pas se connecter',
			'settings.station.rigctldTroubleshooting' => 'Ceci se connecte à un **démon rigctld que vous lancez vous-même**, pas directement à la radio — le backend de Hamlib dialogue avec la radio et prend en charge des centaines de modèles.\n\n- **Le démon doit déjà tourner**, par ex. `rigctld -m 1035 -r /dev/ttyUSB0`. Trouvez le numéro de modèle de votre radio avec `rigctl -l`.\n- **Depuis une autre machine**, lancez-le avec `-T 0.0.0.0` : par défaut, rigctld n\'accepte que les connexions de la machine sur laquelle il tourne.\n- **Le port** est 4532 sauf si vous avez lancé le démon avec `-t`.\n- Une fois connecté, une fréquence absente signifie généralement que le démon lui-même ne joint pas la radio. Testez-le avec `rigctl -m 2 f` sur la machine du démon.',
			'settings.station.flrigTroubleshootingTitle' => 'Si l\'application ne peut pas se connecter',
			'settings.station.flrigTroubleshooting' => 'Ceci se connecte à un **programme flrig que vous lancez vous-même**, pas directement à la radio — flrig dialogue avec la radio et prend en charge la plupart des marques et modèles.\n\n- **flrig doit déjà tourner**, avec son transceiver configuré et connecté.\n- **Le port** est 12345 sauf si vous l\'avez changé dans la configuration de flrig (Config → Setup → Server).\n- **Depuis une autre machine**, assurez-vous que le serveur de flrig est joignable. Il écoute sur toutes les interfaces, mais votre pare-feu n\'est peut-être pas d\'accord.\n- Une fois connecté, une fréquence absente signifie généralement que flrig lui-même ne joint pas la radio. Vérifiez que l\'affichage de flrig suit le bouton de la radio.',
			'settings.station.hrdTroubleshootingTitle' => 'Si l\'application ne peut pas se connecter',
			'settings.station.hrdTroubleshooting' => 'Ceci se connecte au **Rig Control de Ham Radio Deluxe, qui tourne sur votre ordinateur**, pas directement à la radio — HRD dialogue avec la radio.\n\n- **Rig Control doit déjà tourner** et être connecté à la radio.\n- **Son serveur IP doit être activé.** Rig Control ne communique avec d\'autres programmes que par ce biais.\n- **Le port** est 7809 sauf si vous l\'avez changé dans les réglages du serveur IP.\n- **Depuis une autre machine**, assurez-vous que votre pare-feu laisse passer la connexion.\n\nCette entrée a été écrite d\'après les descriptions publiées du protocole de HRD et n\'a jamais été testée avec HRD. Si elle fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.n3fjpTroubleshootingTitle' => 'Si l\'application ne peut pas se connecter',
			'settings.station.n3fjpTroubleshooting' => 'Ceci se connecte à **un logiciel de journal N3FJP qui tourne sur votre ordinateur**, pas directement à la radio — N3FJP dialogue avec la radio.\n\n- **L\'API du programme doit être activée** : Settings → Application Program Interface, cochez **TCP API Enabled**.\n- **Le port** est 1100 sauf si vous l\'avez changé à cet endroit.\n- **N3FJP doit avoir une interface radio configurée** pour suivre ou accorder la radio. Sans elle, il ne rapporte que ce qui est tapé dans sa fenêtre de saisie.\n- N3FJP rapporte uniquement la bande, le mode et la fréquence : ni puissance, ni état d\'émission.\n\nCette entrée a été écrite d\'après l\'API publiée de N3FJP et n\'a jamais été testée avec N3FJP. Si elle fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.commanderTroubleshootingTitle' => 'Si l\'application ne peut pas se connecter',
			_ => null,
		} ?? switch (path) {
			'settings.station.commanderTroubleshooting' => 'Ceci se connecte à **DXLab Commander, qui tourne sur votre ordinateur**, pas directement à la radio — Commander dialogue avec la radio.\n\n- **Commander doit déjà tourner** et être connecté à la radio.\n- **Son service réseau doit être activé** : le bouton **Net Serv** dans le panneau Radio de la fenêtre Configuration de Commander.\n- **Le port** est 52002, le troisième port du bloc commençant au **Base Port** de Net Serv (52000 sauf si vous l\'avez changé).\n- **Depuis une autre machine**, assurez-vous que votre pare-feu laisse passer la connexion.\n\nCette entrée a été écrite d\'après les messages TCP publiés de Commander et n\'a jamais été testée avec Commander. Si elle fonctionne à moitié, cela vaut la peine de le signaler.',
			'settings.station.ic705TroubleshootingTitle' => 'Si la radio ne répond jamais',
			'settings.station.ic705Troubleshooting' => 'La radio n\'a qu\'**une seule** session de contrôle à distance. Quand la connexion est ignorée, c\'est presque toujours qu\'autre chose l\'utilise.\n\n- **Fermez tout autre client.** wfview ou RS-BA1 connecté à la même radio occupe cette unique session, et la connexion d\'ici est simplement ignorée pendant ce temps.\n- **Vérifiez les réglages réseau de la radio.** Le WLAN doit être activé, la radio doit être sur le même réseau, et sa fonction de contrôle à distance (Network) doit être activée.\n- **Éteignez puis rallumez le WLAN de la radio** s\'il reste bloqué. Cela libère de façon fiable une session bloquée sur la radio.\n\nUn **mauvais mot de passe est refusé explicitement**, pas accueilli par le silence. Si vous êtes arrivé ici plutôt qu\'à un message « refusé », le mot de passe n\'est pas en cause.',
			'settings.station.statusStale' => 'Ne répond pas',
			'settings.station.statusDisconnected' => 'Non connecté',
			'settings.station.statusConnecting' => 'Connexion…',
			'settings.station.statusDisconnecting' => 'Déconnexion…',
			'settings.station.statusError' => 'Échec de la connexion',
			'settings.station.currentRadioSettings' => 'Réglages actuels de la radio',
			'settings.station.notSupportedByThisRadio' => 'Non pris en charge par cette radio',
			'settings.station.keyerRowLabel' => 'Manipulateur',
			'settings.station.cwMessagesButton' => 'CW',
			'settings.station.voiceMessagesButton' => 'Phonie',
			'settings.station.voiceKeyerAvailable' => ({required Object count}) => 'Messages vocaux : ${count} mémoires dans la radio',
			'settings.station.antennaBands' => 'Bandes',
			'settings.station.antennaType' => 'Type d\'antenne',
			'settings.station.antennaTypeRequired' => 'Choisissez un type d\'antenne',
			'settings.station.antennaTypes.dipole' => 'Dipôle',
			'settings.station.antennaTypes.vertical' => 'Verticale',
			'settings.station.antennaTypes.yagiBeam' => 'Yagi / Beam',
			'settings.station.antennaTypes.loop' => 'Boucle',
			'settings.station.antennaTypes.longWire' => 'Long fil / EFHW',
			'settings.station.antennaTypes.other' => 'Autre',
			'settings.station.keyType' => 'Type de manipulateur',
			'settings.station.keyTypeRequired' => 'Choisissez un type de manipulateur',
			'settings.station.keyTypes.straight' => 'Pioche',
			'settings.station.keyTypes.sideswiper' => 'Sideswiper',
			'settings.station.keyTypes.bug' => 'Bug (semi-automatique mécanique)',
			'settings.station.keyTypes.fullyAutomatic' => 'Manipulateur entièrement automatique',
			'settings.station.keyTypes.singlePaddle' => 'Simple palette',
			'settings.station.keyTypes.dualPaddle' => 'Double palette',
			'settings.station.keyTypes.computerDriven' => 'Piloté par ordinateur',
			'settings.station.keyTypes.other' => 'Autre',
			'settings.station.softwareIntermediaries' => 'Logiciels intermédiaires',
			'settings.station.otherBrands' => 'Autres marques',
			'settings.station.otherEquipment' => 'Autres équipements (antennes, manipulateurs, etc.)',
			'settings.station.newAntenna' => 'Nouvelle antenne',
			'settings.station.newKey' => 'Nouveau manipulateur',
			'settings.station.newKeyer' => 'WinKeyer (K1EL ou compatible)',
			'settings.station.keyViaRadio' => ({required Object radio}) => 'Manipulateur CAT dans ${radio}',
			'settings.station.keyOnDevice' => ({required Object device}) => 'Manipulateur sur ${device}',
			'settings.station.cwKeyerArea' => 'Zone du manipulateur',
			'settings.station.trackStationInfo' => 'Enregistrer les infos de station pour chaque QSO',
			'settings.station.includeStationInfoInAdif' => 'Inclure dans les exports ADIF',
			'settings.station.whatToTrack' => 'Quoi enregistrer ?',
			'settings.station.trackFieldRig' => 'Transceiver',
			'settings.station.trackFieldPower' => 'Puissance',
			'settings.station.watts' => 'Watts',
			'settings.station.trackFieldAntenna' => 'Antenne',
			'settings.station.trackFieldKey' => 'Manipulateur CW',
			'settings.station.placeholderConnectDelay' => 'Délai de connexion (ms)',
			'settings.station.placeholderConnectDelayDescription' => 'Durée du handshake simulé. Vide ou 0 connecte instantanément.',
			'settings.station.placeholderDropAfter' => 'Couper après (secondes)',
			'settings.station.placeholderDropAfterDescription' => 'Ferme la connexion d\'elle-même, pour tester la reconnexion. Vide ou 0 ne coupe jamais.',
			'settings.station.placeholderFailConnect' => 'Toujours échouer à la connexion',
			'settings.station.placeholderConnectFailure' => 'La radio provisoire a reçu l\'ordre de refuser cette connexion',
			'settings.station.placeholderFreq' => 'Fréquence (kHz)',
			'settings.station.placeholderFreqDescription' => 'Fréquence de départ de la radio provisoire. Elle renvoie ensuite ce sur quoi l\'application l\'accorde.',
			'settings.station.placeholderMode' => 'Mode',
			'settings.station.placeholderModeDescription' => 'Le mode de départ de la radio provisoire, par ex. USB, CW, FT8.',
			'settings.station.placeholderPower' => 'Puissance (watts)',
			'settings.station.placeholderPurpose' => 'Utilisez cette radio pour garder trace du poste que vous utilisez, à des fins de journal',
			'settings.station.placeholderReplyDelay' => 'Délai de réponse (ms)',
			'settings.station.placeholderReplyDelayDescription' => 'Temps que met la radio provisoire à signaler un changement. Vide ou 0 répond immédiatement.',
			'settings.station.cwKeyerField' => 'Manipulateur CW par CAT',
			'settings.station.cwKeyerFieldDescription' => 'Indique si cette radio manipule la CW à partir de texte via CAT. Désactivé pour un poste que l\'application ne connaît pas.',
			'settings.station.voiceMemories' => 'Mémoires vocales',
			'settings.station.voiceMemoriesDescription' => 'Nombre de mémoires vocales que la radio joue via CAT. 0 pour aucune.',
			'settings.station.voiceMemoriesInvalid' => 'Un nombre entier, 0 ou plus',
			'settings.station.yaesuMeterCapture' => 'Capturer les mesures des indicateurs',
			'settings.station.yaesuBinaryMeterCaptureDescription' => 'Lit l\'indicateur de puissance de sortie et le signal de ROS élevé de la radio pendant l\'émission, et écrit les valeurs brutes dans le log. Sert à établir l\'échelle que Yaesu ne publie pas — les valeurs ne sont pas affichées sous forme d\'indicateurs.',
			'settings.station.yaesuMeterCaptureDescription' => 'Lit les indicateurs PO, SWR et ALC de la radio pendant l\'émission, et écrit les valeurs brutes dans le log. Sert à établir l\'échelle que Yaesu ne publie pas — les valeurs ne sont pas affichées sous forme d\'indicateurs.',
			'settings.station.telemetryInterval' => 'Intervalle de lecture des indicateurs (ms)',
			'settings.station.telemetryIntervalDescription' => 'Fréquence de lecture des indicateurs de la radio pendant l\'émission. Laissez vide pour le plus rapide que cette connexion supporte, jusqu\'à 200 ms.',
			'settings.station.telemetryIntervalInvalid' => ({required Object min, required Object max}) => 'Un nombre entier de millisecondes, de ${min} à ${max}',
			'settings.station.pollInterval' => 'Intervalle d\'interrogation au repos (ms)',
			'settings.station.pollIntervalDescription' => ({required Object fallback}) => 'Fréquence à laquelle demander à la radio sa fréquence et son mode quand rien ne change. Laissez vide pour ${fallback} ms.',
			'settings.station.pollIntervalInvalid' => ({required Object min, required Object max}) => 'Un nombre entier de millisecondes, de ${min} à ${max}',
			'settings.station.advancedSettings' => 'Paramètres avancés',
			'settings.station.placeholderSwr' => 'Valeur de ROS',
			'settings.station.placeholderSwrDescription' => 'Ce que cette radio indique sur son ROS-mètre pendant l\'émission. Au-dessus de 1,8 le panneau avertit.',
			'settings.station.placeholderSwrInvalid' => 'Un nombre, 1 ou plus',
			'settings.station.keyerNone' => 'Aucun',
			'settings.station.cwDialect' => 'Dialecte de manipulation CW',
			'settings.station.cwDialectDescription' => 'Quelle forme de la commande KY cette radio accepte. Aucun signifie pas de manipulation CW via CAT.',
			'settings.station.cwDialectKenwood' => 'Kenwood (KY, complété à 24)',
			'settings.station.cwDialectElecraft' => 'Elecraft (texte KY)',
			'settings.station.voiceDialect' => 'Dialecte des messages vocaux',
			'settings.station.voiceDialectDescription' => 'Comment cette radio joue ses mémoires vocales via CAT. Aucun signifie pas de mémoires vocales via CAT. Avec un dialecte et sans nombre, le nombre par défaut du dialecte s\'applique.',
			'settings.station.voiceDialectPb' => 'Kenwood (PB, style TS-590)',
			'settings.station.voiceDialectK4' => 'Elecraft K4 (PB et DA)',
			'settings.station.voiceDialectKx' => 'Elecraft KX2/KX3 (appuis de touches)',
			'settings.station.placeholderDiagnostic' => 'Simulé',
			'settings.station.placeholderWholeNumberInvalid' => 'Doit être un nombre entier, 0 ou plus',
			'settings.station.placeholderFreqInvalid' => 'Doit être une fréquence en kHz, supérieure à zéro',
			'settings.station.placeholderModeInvalid' => 'Doit être un nom de mode, par ex. USB, CW, FT8',
			'settings.station.switchLayout' => 'Disposition',
			'settings.station.switchLayoutDescription' => 'De quel côté du commutateur vos radios sont branchées.',
			'settings.station.switchLayoutRequired' => 'Choisissez le câblage du commutateur',
			'settings.station.switchCommandRefused' => ({required Object command, required Object code}) => 'Le commutateur a refusé « ${command} » (erreur ${code})',
			'settings.station.switchBusyTransmitting' => 'Ce port est en émission — antenne inchangée',
			'settings.station.switchNoAntenna' => 'Aucune',
			'settings.station.switchAntennaFor' => ({required Object port}) => 'Antenne sur le port ${port}',
			'settings.station.switchAntennaForDescription' => 'Laquelle de vos antennes est reliée à ce port du commutateur.',
			'settings.station.switchLayoutSides' => ({required Object antennas, required Object radios}) => '${antennas} antennes, ${radios} radios',
			'settings.station.switchLayoutSidesOneRadio' => ({required Object antennas}) => '${antennas} antennes, 1 radio',
			'settings.station.switchLayoutSidesOneAntenna' => ({required Object radios}) => '1 antenne, ${radios} radios',
			'settings.station.switchCommonPort' => 'Commun',
			'settings.station.dcnAddress' => 'Adresse du périphérique',
			'settings.station.dcnAddressDescription' => 'L\'adresse réglée sur les interrupteurs DIP du module. Un module relais coaxial sort d\'usine à 2.',
			'settings.station.dcnAddressRequired' => 'Doit être une adresse de périphérique de 1 à 99',
			'settings.station.switchPortLabel' => ({required Object port}) => 'Port ${port}',
			'settings.station.switchPortAutoHint' => 'suit les données de bande',
			'settings.station.switchPortTransmittingHint' => 'en émission — impossible de changer maintenant',
			'settings.station.switchCurrentStateHeader' => 'État actuel',
			'settings.station.switchCurrentStateDescription' => 'Sur quelle antenne se trouve chaque port radio en ce moment. Les changements prennent effet immédiatement.',
			'settings.station.switchWiringHeader' => 'Câblage',
			'settings.station.switchPortInhibitedHint' => 'émission bloquée',
			'settings.station.configUnreadable' => 'Les réglages enregistrés de cette radio n\'ont pas pu être lus. Ouvrez ses paramètres et saisissez-les à nouveau, ou retirez-la et ajoutez-la de nouveau.',
			'settings.station.autoConnectHeld' => 'HaLo a cessé de répondre la dernière fois qu\'il s\'est connecté à cette radio : il ne s\'est donc pas connecté de lui-même cette fois. Appuyez sur Connecter pour réessayer.',
			'settings.offlineData.title' => 'Données hors ligne',
			'settings.offlineData.noFiles' => 'Aucun fichier de données',
			'settings.offlineData.noFilesDescription' => 'Activez des extensions d\'activité ou de recherche pour télécharger ici leurs données hors ligne.',
			'settings.offlineData.refresh' => 'Rafraîchir',
			'settings.offlineData.refreshing' => 'Actualisation…',
			'settings.offlineData.updateAll' => 'Tout mettre à jour',
			'settings.offlineData.updatingAll' => 'Mise à jour de tous les fichiers de données…',
			'settings.offlineData.neverDownloaded' => 'Jamais téléchargé',
			'settings.offlineData.updatedJustNow' => 'Mis à jour à l\'instant',
			'settings.offlineData.updatedDaysAgo' => ({required Object days}) => 'Mis à jour il y a ${days} j',
			'settings.offlineData.updatedDaysHoursAgo' => ({required Object days, required Object hours}) => 'Mis à jour il y a ${days} j ${hours} h',
			'settings.offlineData.updatedHoursAgo' => ({required Object hours}) => 'Mis à jour il y a ${hours} h',
			'settings.offlineData.updatedHoursMinutesAgo' => ({required Object hours, required Object minutes}) => 'Mis à jour il y a ${hours} h ${minutes} min',
			'settings.offlineData.updatedMinutesAgo' => ({required Object minutes}) => 'Mis à jour il y a ${minutes} min',
			'settings.offlineData.lastDownloadRefused' => ({required Object imported, required Object existing}) => 'Le dernier téléchargement ne contenait que ${imported} enregistrements sur ${existing} et n\'a pas été utilisé. Rafraîchissez pour l\'accepter.',
			'settings.offlineData.extensionsSection' => 'Extensions',
			'settings.profiles.notSet' => 'Non défini',
			'settings.profiles.personalInfo' => 'Infos personnelles',
			'settings.profiles.personalInfoNote' => 'Ces infos peuvent être incluses dans les journaux générés quand c\'est utile pour les soumissions',
			'settings.profiles.name' => 'Nom',
			'settings.profiles.email' => 'E-mail',
			'settings.profiles.club' => 'Club',
			'settings.profiles.arrlSection' => 'Section ARRL',
			'settings.profiles.racSection' => 'Section RAC',
			'settings.profiles.section' => 'Section',
			'settings.search.clear' => 'Effacer',
			'settings.search.hint' => 'Rechercher dans les préférences',
			'settings.developer.developerModeDescription' => 'Active les avertissements développeur, les logs de débogage et les outils.',
			'settings.developer.experiments' => 'Expériences',
			'settings.developer.experimentsEnabled' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} activée', other: '${count} activées', ), 
			'settings.developer.patchTrack' => 'Piste des correctifs',
			'settings.developer.patchTrackDescription' => 'Quel anneau de correctifs à distance cet appareil suit. Les anneaux plus aventureux reçoivent les corrections plus tôt, moins testées. Les correctifs s\'appliquent au prochain redémarrage.',
			'settings.developer.trackStable' => 'Stable',
			'settings.developer.trackUnstable' => 'Instable',
			'settings.developer.trackBleeding' => 'À la pointe',
			'settings.developer.checkingTrack' => ({required Object track}) => 'Recherche d\'un correctif sur « ${track} »…',
			'settings.developer.patchDownloaded' => 'Correctif téléchargé — redémarrez l\'application pour l\'appliquer.',
			'settings.developer.noNewPatch' => ({required Object track}) => 'Aucun nouveau correctif sur « ${track} ».',
			'settings.developer.noPatchInstalled' => 'Aucun correctif installé — exécution du binaire de la version.',
			'settings.developer.runningPatch' => ({required Object patch}) => 'Correctif n°${patch} en cours d\'exécution.',
			'settings.developer.deepLinks' => 'Liens profonds',
			'settings.developer.registerUrlSchemes' => 'Enregistrer les schémas d\'URL',
			'settings.developer.registerUrlSchemesDescription' => 'Permettre aux liens com.ham2k:// d\'ouvrir cette copie de l\'application',
			'settings.developer.registerUrlSchemesDone' => 'Cette copie ouvre maintenant les liens com.ham2k://',
			'settings.developer.registerUrlSchemesFailed' => ({required Object error}) => 'Enregistrement impossible : ${error}',
			'settings.developer.systemInformation' => 'Informations sur le système',
			'settings.developer.appVersion' => 'Version de l\'application',
			'settings.developer.dataFolder' => 'Dossier de données',
			'settings.developer.loading' => '(chargement…)',
			'settings.developer.panelLoadFailed' => 'Impossible de charger ce panneau de paramètres.',
			'settings.developer.extDevServer' => 'Serveur de développement d\'extensions',
			'settings.developer.extensionSettings' => 'Paramètres des extensions',
			'settings.developer.extDevServerDescription' => 'Charger les extensions depuis un serveur de développement sur votre réseau au lieu de celles intégrées à l\'application, et les recharger à chaque enregistrement.',
			'settings.developer.extDevServerAddress' => 'Adresse du serveur',
			'settings.developer.extDevServerHint' => '192.168.1.20:8787',
			'settings.developer.extDevServerConnect' => 'Connecter',
			'settings.developer.extDevServerDisconnect' => 'Déconnecter',
			'settings.developer.extDevServerConnecting' => 'Connexion…',
			'settings.developer.extDevServerConnected' => ({required num count, required Object keys}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} extension servie : ${keys}', other: '${count} extensions servies : ${keys}', ), 
			'settings.developer.extDevServerDisconnected' => 'Non connecté',
			'settings.developer.extDevServerReconnect' => 'Se reconnecter au lancement',
			'settings.developer.extDevServerLastReload' => ({required Object key, required Object time}) => 'Dernier rechargement : ${key} à ${time}',
			'settings.developer.extDevServerBuildErrors' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} extension en échec de compilation', other: '${count} extensions en échec de compilation', ), 
			'settings.developer.catalog' => 'Catalogue d\'extensions',
			'settings.developer.catalogDescription' => 'Lire le catalogue depuis un autre serveur — un serveur local pour travailler sur le catalogue lui-même. Vide signifie catalog.ham2k.net.',
			'settings.developer.catalogAddress' => 'Adresse du catalogue',
			'settings.developer.catalogHint' => 'http://localhost:8787',
			'settings.developer.catalogSearchTracks' => 'Pistes de recherche du catalogue',
			'settings.developer.catalogSearchStable' => 'Stable uniquement',
			'settings.developer.catalogSearchUnstable' => 'Instable ou mieux',
			'settings.developer.catalogSearchBleeding' => 'À la pointe ou mieux',
			'settings.about.notices' => 'Notifications et messages',
			'settings.about.noticesDescription' => 'Annonces et messages d\'état',
			'settings.about.releaseNotes' => 'Notes de version',
			'settings.about.copiedVersion' => 'Détails de la version copiés dans le presse-papiers',
			'settings.panels.settings' => 'Préférences de l\'application',
			'settings.panels.settingsDescription' => 'Faites fonctionner l\'application comme vous le souhaitez',
			'settings.panels.commonSettings' => 'Préférences courantes',
			'settings.panels.syncDescription' => 'Sauvegardez et synchronisez vos journaux entre vos appareils',
			'settings.panels.accountsDescription' => 'Identifiants de services, données hors ligne, et plus encore',
			'settings.panels.extensions' => 'Extensions et fonctionnalités',
			'settings.panels.extensionsDescription' => 'Activités, concours, panneaux du tableau de bord et autres fonctionnalités',
			'settings.panels.profilesDescription' => 'Indicatif de l\'opérateur et profil de la station',
			'settings.panels.stationProfiles' => 'Profils de station',
			'settings.panels.developerSettings' => 'Paramètres développeur',
			'settings.panels.developerSettingsDescription' => 'Outils de débogage et de développement',
			'settings.panels.about' => 'À propos',
			'settings.panels.aboutDescription' => 'Version, crédits et informations légales',
			'settings.panels.unavailableTitle' => 'Certains paramètres sont indisponibles',
			'settings.panels.unavailableText' => 'Le moteur d\'extensions n\'a pas pu démarrer : les paramètres fournis par les extensions sont donc absents.',
			'settings.panels.station' => 'Configuration de la station',
			'settings.panels.stationDescription' => 'Contrôle CAT et autres options',
			'settings.panels.peers' => 'Appareils pairs',
			'settings.panels.peersDescription' => 'Se connecter à d\'autres appareils à proximité',
			'settings.showMoreSettings' => 'Afficher plus de paramètres',
			'settings.gridPrecision' => 'Précision du locator',
			'settings.gridPrecisionOpts.six' => '6 caractères (FN31pr)',
			'settings.gridPrecisionOpts.eight' => '8 caractères (FN31pr55)',
			'settings.gridPrecisionDescription.six' => '6 caractères',
			'settings.gridPrecisionDescription.eight' => '8 caractères',
			'commands.enableSyncFirst' => 'Activez d\'abord la synchronisation dans les Paramètres.',
			'commands.fullResyncStarted' => 'Resynchronisation complète lancée — les données locales ont d\'abord été sauvegardées.',
			'commands.noDataFilesMatched' => ({required Object target}) => 'Aucun fichier de données ne correspond à « ${target} ».',
			'commands.reloadFailed' => ({required Object error}) => 'Échec du rechargement : ${error}',
			'commands.reloadingAll' => 'Rechargement de tous les fichiers de données…',
			'commands.reloadingTarget' => ({required Object target}) => 'Rechargement des fichiers de données ${target}…',
			'commands.unknownExperiment' => ({required Object token}) => 'Expérience inconnue « ${token} »',
			'commands.experimentEnabled' => ({required Object name}) => '${name} activée',
			'commands.experimentDisabled' => ({required Object name}) => '${name} désactivée',
			'commands.sentryTestSent' => 'Rapport d\'erreur de test envoyé à Sentry',
			'commands.sentryTestLocalOnly' => 'Sentry est désactivé dans cette version — erreur de test consignée localement uniquement',
			'commands.noOperationOpen' => 'Cette commande nécessite une opération ouverte',
			'commands.unknownSegmentKind' => ({required Object kind}) => 'Impossible de marquer « ${kind} »',
			'commands.operationAlreadyStarted' => 'Cette opération a déjà un marqueur de début',
			'commands.couldNotOpenLocation' => 'Pause ajoutée, mais impossible d\'ouvrir l\'écran d\'emplacement',
			'commands.noTestOperations' => 'Aucune opération de test à purger',
			'commands.purgeTestsUnavailable' => 'PURGETESTS doit afficher une boîte de confirmation, qui n\'est pas disponible ici',
			'commands.syncAllUnavailable' => 'SYNCALL doit afficher une boîte de confirmation, qui n\'est pas disponible ici',
			'commands.testOperationsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} opération de test purgée', other: '${count} opérations de test purgées', ), 
			'commands.purgeTestsSomeFailed' => ({required Object purged, required Object total}) => '${purged} opérations de test purgées sur ${total} — les autres ont échoué ; relancez PURGETESTS',
			'commands.testContactsPurged' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} contact de test sans opération purgé', other: '${count} contacts de test sans opération purgés', ), 
			'commands.purgeTestsContactsFailed' => 'Opérations de test purgées, mais les contacts de test sans opération ont échoué ; relancez PURGETESTS',
			'commands.purgeTestsNothingToDo' => 'Rien n\'a été purgé',
			'commands.receivedPurgesSomeFailed' => ({required Object removed, required Object total}) => '${removed} opérations de test supprimées sur ${total} — les autres ont échoué ; relancez Examiner',
			'commands.receivedPurgesFailed' => 'Impossible de supprimer ces opérations de test — relancez Examiner',
			'commands.receivedPurgesPending' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} opération de test a été supprimée sur un autre appareil', other: '${count} opérations de test ont été supprimées sur un autre appareil', ), 
			'commands.receivedPurgesReview' => 'Examiner',
			'commands.settingOn' => 'Activé',
			'commands.settingOff' => 'Désactivé',
			'commands.settingEmpty' => '(vide)',
			'commands.settingSecretSet' => '(défini)',
			'commands.settingSecretUnset' => '(non défini)',
			'commands.settingSelectedCount' => ({required Object count}) => '${count} sélectionné(s)',
			'commands.settingExpectsOnOff' => 'on ou off',
			'commands.settingExpectsOneOf' => ({required Object choices}) => 'l\'une des valeurs : ${choices}',
			'commands.settingExpectsNumber' => 'un nombre',
			'commands.settingVanished' => ({required Object label}) => '« ${label} » n\'est plus disponible',
			'commands.noCwKeyer' => 'Aucune radio connectée ne peut manipuler la CW',
			'commands.noKeyer' => 'Aucune radio connectée ne peut manipuler la CW ni jouer des mémoires vocales',
			'commands.keyerNeedsOperation' => 'Ouvrez une opération pour utiliser le manipulateur CW',
			'commands.keyerExperimentOff' => 'La manipulation CW est désactivée — activez-la avec EXP KEYER',
			'commands.esmExperimentOff' => 'Entrée envoie les messages est désactivé — activez-le avec EXP ESM',
			'commands.cwSending' => ({required Object text}) => 'Envoi CW : ${text}',
			'commands.cwMessageError' => ({required Object n, required Object error}) => 'Message CW F${n} : ${error}',
			'commands.cwMessageNotRendered' => ({required Object n}) => 'Le message CW F${n} n\'a pas été envoyé : les extensions ne sont pas prêtes',
			'commands.settingNotStored' => ({required Object label}) => '« ${label} » n\'a pas accepté cette valeur',
			'commandDialog.hint' => 'Rechercher un indicatif ou taper une commande',
			'commandDialog.noResults' => ({required Object text}) => 'Rien ne correspond à « ${text} »',
			'commandDialog.sectionCommands' => 'Commandes',
			'commandDialog.sectionGoTo' => 'Aller à',
			'commandDialog.sectionOperations' => 'Opérations',
			'commandDialog.goHome' => 'Accueil',
			'commandDialog.goSettings' => 'Paramètres',
			'commandDialog.goNewOperation' => 'Nouvelle opération',
			'commandDialog.runTyped' => ({required Object text}) => 'Exécuter « ${text} »',
			'commandDialog.sectionSuggestions' => 'Essayez',
			'commandDialog.lookingUp' => 'Recherche de l\'indicatif…',
			'commandDialog.blockedByPane' => 'Impossible d\'utiliser les commandes quand un panneau ou une boîte de dialogue est ouvert',
			'expiredBuild.title' => 'Cette version a expiré',
			'expiredBuild.body' => 'Rendez-vous sur ham2k.com pour obtenir une version plus récente.',
			'expiredBuild.visit' => 'Aller sur ham2k.com',
			'expiredBuild.dismiss' => 'Continuer quand même',
			'staleness.codePushFloorTitle' => 'Une mise à jour importante vous attend',
			'staleness.codePushFloorBody' => 'Cette version contient un correctif que vous n\'avez pas encore.',
			'staleness.restartToApply' => 'Redémarrez l\'application pour l\'appliquer.',
			'staleness.quitAndReopen' => 'Quittez l\'application et rouvrez-la pour l\'appliquer.',
			'staleness.reopenToApply' => 'Fermez l\'application et rouvrez-la pour l\'appliquer.',
			'staleness.ignoreForNow' => 'Ignorer pour l\'instant',
			'spotting.noQsoYet' => 'Aucun QSO saisi à spotter pour l\'instant.',
			'spotting.setFrequencyFirst' => 'Définissez d\'abord une fréquence.',
			'spotting.nothingToSpot' => 'Rien à spotter — aucune extension ne propose le spotting ici.',
			'spotting.spotFailed' => ({required Object source, required Object message}) => 'Échec de ${source} : ${message}',
			'spotting.unknownError' => 'erreur inconnue',
			'spotting.notSent' => 'Spot non envoyé.',
			'spotting.notRefreshedOffline' => 'Pas de connexion — les spots n\'ont pas été actualisés',
			'dataFiles.downloading' => 'Téléchargement…',
			'dataFiles.downloadFailedTitle' => ({required Object name}) => 'Impossible de télécharger ${name}',
			'dataFiles.downloadFailedWebHint' => 'Il peut s\'agir d\'un problème réseau, ou l\'hébergeur de ce lien ne permet peut-être pas le téléchargement direct depuis un navigateur web. Essayez l\'application de bureau ou mobile, ou un autre hébergement.',
			'dataFiles.downloadTimedOut' => 'Le serveur a mis trop de temps à répondre. Réessayez plus tard.',
			'dataFiles.downloadServerError' => ({required Object host, required Object status}) => '${host} a répondu par une erreur (HTTP ${status}). Réessayez plus tard.',
			'dataFiles.downloadNotAvailable' => ({required Object host, required Object status}) => '${host} n\'a pas pu fournir ce fichier (HTTP ${status}). Vérifiez que son adresse est toujours correcte.',
			'dataFiles.processingFailedTitle' => ({required Object name}) => 'Impossible de traiter ${name}',
			'dataFiles.importTooSmall' => ({required Object imported, required Object existing}) => 'Le téléchargement ne contenait que ${imported} des ${existing} enregistrements présents sur cet appareil : ceux qu\'il omettait ont donc été conservés. L\'actualiser dans Paramètres › Données hors ligne l\'accepte quand même.',
			'dataFiles.importedRecords' => ({required num count, required Object label}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} enregistrement importé pour ${label}.', other: '${count} enregistrements importés pour ${label}.', ), 
			'dataFiles.importedData' => ({required Object label}) => 'Données importées pour ${label}.',
			'dataFiles.cleanedUpTitle' => 'Données d\'extensions nettoyées',
			'dataFiles.removedData' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Données supprimées pour ${count} fichier de données d\'extensions désactivées.', other: 'Données supprimées pour ${count} fichiers de données d\'extensions désactivées.', ), 
			'dataFiles.recordsProgress' => ({required Object end, required Object total}) => '${end} / ${total} enregistrements',
			'dataFiles.definitionUnavailable' => 'La source du fichier n\'a pas fourni de définition — son extension est peut-être en cours de redémarrage ou mal configurée. Réessayez dans un instant.',
			'updates.updateAvailable' => 'Mise à jour disponible',
			'updates.newVersionAvailable' => ({required Object version}) => 'Une nouvelle version (${version}) est disponible.',
			'updates.getIt' => 'L\'obtenir',
			'updates.ok' => 'OK',
			'updates.updateReady' => 'Mise à jour prête',
			'updates.restartToApply' => 'Une mise à jour a été téléchargée. Redémarrez pour l\'appliquer.',
			'updates.appliesNextLaunch' => 'Une mise à jour a été téléchargée. Elle s\'appliquera à la prochaine ouverture de l\'application.',
			'updates.restartNow' => 'Redémarrer maintenant',
			'updates.reloadToUpdate' => 'Une version plus récente de cette page est disponible. Rechargez pour l\'obtenir.',
			'updates.reloadNow' => 'Recharger maintenant',
			'updates.checkForUpdates' => 'Vérifier les mises à jour',
			'updates.checkingForUpdates' => 'Recherche de mises à jour…',
			'updates.upToDate' => 'À jour',
			'updates.automaticChecks' => 'Vérifier automatiquement',
			'updates.automaticChecksDescription' => 'Rechercher les nouvelles versions en arrière-plan, à partir du prochain démarrage de l\'application',
			'extensionService.runtimeNotReady' => 'Le moteur d\'extensions n\'est pas prêt.',
			'extensionService.testFailed' => ({required Object error}) => 'Échec du test : ${error}',
			'extensionService.connectedAs' => ({required Object identity}) => 'Connecté en tant que ${identity}',
			'extensionService.invalidFieldConfiguration' => 'Configuration de champ invalide',
			'extensionService.invalidValue' => 'Valeur invalide',
			'extensionService.validationError' => ({required Object error}) => 'Erreur de validation : ${error}',
			'extensionService.actionFailed' => ({required Object error}) => 'Échec de l\'action : ${error}',
			'extensionService.commandFailed' => 'La commande n\'a pas pu s\'exécuter',
			'extensionService.reportUnavailable' => 'Les signalements ne peuvent pas être envoyés pour le moment',
			'extensionService.stashUnavailable' => 'Ham2K File Stash est injoignable pour le moment',
			'extensionService.timersSuspendedBudget' => ({required Object name}) => '${name} a passé trop de temps dans ses minuteries. Elles sont arrêtées jusqu\'au redémarrage des extensions.',
			'extensionService.timersSuspendedFailures' => ({required Object name}) => 'Les minuteries de ${name} échouaient sans cesse. Elles sont arrêtées jusqu\'au redémarrage des extensions.',
			'extensionService.timersSuspendedInterrupted' => ({required Object name}) => '${name} est resté bloqué dans une minuterie. Ses minuteries sont arrêtées jusqu\'au redémarrage des extensions.',
			'operationLocationScreen.title' => 'Emplacement de l\'opération',
			'operationLocationScreen.selectedLocation' => 'Emplacement sélectionné',
			'operationLocationScreen.gridSquare' => 'Carré Locator Maidenhead',
			'operationLocationScreen.gridInvalid' => 'Il faut 4, 6, 8 ou 10 caractères, comme FN31pr',
			'operationLocationScreen.suggestedLocations' => 'Emplacements suggérés',
			'operationLocationScreen.deviceGps' => 'GPS de l\'appareil',
			'operationLocationScreen.peerGps' => ({required Object device}) => 'GPS de ${device}',
			'operationLocationScreen.locating' => 'Localisation…',
			'operationLocationScreen.gpsUnavailable' => 'Position indisponible',
			'operationLocationScreen.permissionDenied' => 'Autorisation de localisation refusée',
			'operationLocationScreen.permissionBlocked' => 'Autorisation de localisation bloquée',
			'operationLocationScreen.moreDetails' => 'Plus de détails',
			'operationLocationScreen.stateOrProvince' => 'État ou province (facultatif)',
			'operationLocationScreen.controlsUnavailableTitle' => 'Contrôles d\'activité indisponibles',
			'operationLocationScreen.controlsUnavailableReason' => 'Ces références restent utilisables ; leurs activités n\'ont simplement pas pu être jointes.',
			'operationLocationScreen.controlsUnavailableRetry' => 'Réessayer',
			'operationLocationScreen.county' => 'Comté (facultatif)',
			'versionLabel.version' => ({required Object version}) => 'Version ${version}',
			'versionLabel.patch' => ({required Object patch}) => 'Correctif ${patch}',
			'versionLabel.build' => ({required Object build}) => 'build ${build}',
			'notices.emptyHistory' => 'Aucune notification pour l\'instant',
			'notices.webStorageInMemory' => 'Ce navigateur n\'a pas pu fournir de stockage persistant — le journal n\'existe qu\'en mémoire et sera PERDU à la fermeture de cet onglet. Utilisez une version récente de Chrome, Firefox, Safari ou Edge.',
			'notices.webStorageUnreliable' => 'Ce navigateur utilise un stockage de secours qui n\'est pas sûr avec plusieurs onglets — gardez un seul onglet ouvert, et laissez la synchronisation activée.',
			'notices.logFromNewerBuildTitle' => 'Ce journal nécessite une version plus récente',
			'notices.logFromNewerBuild' => ({required Object storage, required Object understood, required Object location}) => 'Votre journal a été écrit par une version plus récente de HaLo (version de stockage ${storage} ; celle-ci comprend ${understood}) : il ne peut donc pas être ouvert, et les nouveaux contacts ne seront pas enregistrés. Réinstallez la version plus récente — ou, si vous vouliez lancer cette version, faites-la pointer vers un autre dossier de données. Le journal se trouve dans ${location}',
			'notices.logFromNewerBuildNoLocation' => ({required Object storage, required Object understood}) => 'Votre journal a été écrit par une version plus récente de HaLo (version de stockage ${storage} ; celle-ci comprend ${understood}) : il ne peut donc pas être ouvert, et les nouveaux contacts ne seront pas enregistrés. Ouvrez plutôt ce journal avec cette version plus récente.',
			'notices.preferencesRestoredTitle' => 'Paramètres restaurés depuis une sauvegarde',
			'notices.preferencesRestored' => 'Le fichier de paramètres n\'a pas pu être lu : HaLo a donc restauré sa dernière copie valide. Ce que vous avez modifié lors de votre session précédente devra peut-être être refait. Le fichier illisible est conservé à côté, sous le nom shared_preferences.corrupt-….json.',
			'notices.preferencesResetTitle' => 'Paramètres réinitialisés',
			'notices.preferencesReset' => 'Le fichier de paramètres n\'a pas pu être lu et aucune sauvegarde n\'était disponible : HaLo a donc démarré avec ses valeurs par défaut. Le fichier illisible est conservé dans le dossier de données de l\'application, sous le nom shared_preferences.corrupt-….json.',
			'notices.autoConnectHeldTitle' => ({required Object name}) => '${name} n\'a pas été connecté automatiquement',
			'notices.autoConnectHeld' => ({required Object name}) => 'HaLo a cessé de répondre la dernière fois qu\'il a commencé à se connecter à ${name} : il n\'y a donc pas touché cette fois, plutôt que de risquer de recommencer. Vérifiez que la radio est allumée et son câble branché, puis appuyez sur Connecter pour celle-ci dans les Paramètres.',
			'syncAccount.anonymous' => ({required Object id}) => 'Compte anonyme (#${id})',
			'syncAccount.pendingConfirmation' => ({required Object email}) => '${email} (confirmation en attente)',
			'syncAccount.pendingConfirmationWithId' => ({required Object email, required Object id}) => '${email} (confirmation en attente - #${id})',
			'deepLink.needsAnOperation' => 'Commencez d\'abord une opération, puis renvoyez ce contact',
			'deepLink.waitingInOperation' => 'Ce contact attend dans l\'opération derrière cet écran',
			'deepLink.unknownActivities' => ({required Object refs}) => 'Cet appareil n\'a aucune activité pour ${refs} : ces références ont donc été omises',
			'deepLink.activitiesUnavailable' => ({required Object refs}) => 'Impossible de joindre vos activités : ${refs} a donc été omis — réessayez ce lien',
			'confirmDevice.title' => 'Confirmer un appareil',
			'confirmDevice.codePrompt' => 'Saisissez le code affiché sur l\'appareil qui veut rejoindre ce compte.',
			'confirmDevice.code' => 'Code',
			'confirmDevice.lookUp' => 'Rechercher',
			'confirmDevice.codeNotFound' => 'Aucune demande ne correspond à ce code. Les codes expirent au bout de 10 minutes — demandez-en un nouveau à l\'autre appareil.',
			'confirmDevice.linkExpired' => 'Ce lien a expiré. Demandez à l\'autre appareil d\'afficher un nouveau code QR.',
			'confirmDevice.areYouSure' => ({required Object device}) => 'Lier ${device} à ce compte ?',
			'confirmDevice.unnamedDevice' => 'un appareil sans nom',
			'confirmDevice.grantWarning' => 'Il pourra lire et modifier chaque opération et chaque QSO de ce compte.',
			'confirmDevice.needsSyncTitle' => 'Cet appareil ne se synchronise pas encore',
			'confirmDevice.needsSyncText' => 'Activez la synchronisation Ham2K Log Filer et liez cet appareil à un compte avant de pouvoir en admettre un autre.',
			'confirmDevice.malformedRequest' => 'Le serveur de synchronisation a envoyé une demande que cette application ne peut pas lire. Demandez à l\'autre appareil de réessayer.',
			'confirmDevice.linkIt' => 'Lier l\'appareil',
			'switchAccounts.noAccountDetails' => 'Aucun détail de compte pour l\'instant',
			'switchAccounts.currentAccount' => 'Compte actuel',
			'switchAccounts.otherAccounts' => 'Autres comptes',
			'switchAccounts.linkToAnother' => 'Lier à un autre compte',
			'switchAccounts.linkWithSibling' => 'Lier avec une autre application Ham2K',
			'switchAccounts.linkWithPolo' => 'Lier avec le compte de l\'ancienne version',
			'switchAccounts.linkWithSiblingDescription' => 'Une autre application Ham2K est installée. Liez-vous au compte qu\'elle utilise.',
			'switchAccounts.siblingPrompt' => ({required Object app}) => 'Approuvez la demande dans ${app}, puis revenez ici.',
			'switchAccounts.openSiblingAgain' => ({required Object app}) => 'Rouvrir ${app}',
			'switchAccounts.siblingNoGrant' => 'Ça n\'a pas marché ? Rouvrez-la, ou revenez en arrière et liez autrement.',
			'switchAccounts.siblingOpenFailed' => ({required Object app}) => 'Impossible d\'ouvrir ${app}.',
			'switchAccounts.siblingLinkRenewed' => ({required Object app}) => 'Le lien a expiré et un nouveau est prêt — rouvrez ${app}.',
			'switchAccounts.tryAgain' => 'Réessayer',
			'switchAccounts.linkWithQr' => 'Lier avec un code QR',
			'switchAccounts.linkWithQrDescription' => 'Scannez-le depuis un appareil qui utilise déjà le compte',
			'switchAccounts.linkWithEmail' => 'Lier avec une adresse e-mail',
			'switchAccounts.linkWithEmailDescription' => 'Confirmez avec un code ou un lien par e-mail',
			'switchAccounts.enterEmailPrompt' => 'Saisissez l\'adresse e-mail du compte que cet appareil doit utiliser.',
			'switchAccounts.emailAddress' => 'Adresse e-mail',
			'switchAccounts.linkAccount' => 'Lier le compte',
			'switchAccounts.copiedCode' => 'Code copié dans le presse-papiers',
			'switchAccounts.copyCode' => 'Copier le code',
			'switchAccounts.codePrompt' => ({required Object email}) => 'Ouvrez l\'application Ham2K sur un appareil déjà lié à ${email} et saisissez ce code pour approuver la demande :',
			'switchAccounts.waitingForConfirmation' => 'En attente de confirmation…',
			'switchAccounts.sendEmailInstead' => 'Envoyer plutôt un e-mail de confirmation',
			'switchAccounts.emailSent' => ({required Object email}) => 'Un e-mail a été envoyé à ${email}. Ouvrez-le et confirmez la demande pour lier cet appareil.',
			'switchAccounts.resendEmail' => 'Renvoyer l\'e-mail',
			'switchAccounts.qrPrompt' => 'Scannez ce code QR depuis un appareil déjà lié au compte souhaité — par exemple avec Ham2K Portable Logger sur votre téléphone.',
			'switchAccounts.serverUnreachable' => 'Impossible de joindre le serveur de synchronisation. Réessayez plus tard.',
			'switchAccounts.emailRequired' => 'Saisissez une adresse e-mail à lier.',
			'switchAccounts.noAccountForEmail' => ({required Object email}) => 'Aucun compte trouvé pour ${email}.',
			'switchAccounts.serverRejected' => ({required Object error}) => 'Le serveur de synchronisation a refusé la demande : ${error}',
			'switchAccounts.noLinkCode' => 'Le serveur de synchronisation n\'a pas renvoyé de code de liaison. Réessayez plus tard.',
			'switchAccounts.noConfirmationCode' => 'Le serveur de synchronisation n\'a pas envoyé de code de confirmation. Réessayez plus tard.',
			'switchAccounts.switchNotAccepted' => 'Ce compte n\'a pas accepté le changement. Essayez plutôt de le lier avec une adresse e-mail.',
			'switchAccounts.requestFailed' => 'Un problème est survenu en dialoguant avec le serveur de synchronisation. Réessayez plus tard.',
			'switchAccounts.qsoCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} QSO', other: '${count} QSOs', ), 
			'switchAccounts.operationCount' => ({required num count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} opération', other: '${count} opérations', ), 
			'adifImport.title' => 'Importer des QSOs depuis ADIF',
			'adifImport.reading' => ({required Object filename}) => 'Lecture de ${filename}…',
			'adifImport.dropHint' => 'Déposez un fichier ADIF à importer',
			'adifImport.totalInFile' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} QSO dans ce fichier', other: '${formatted} QSOs dans ce fichier', ), 
			'adifImport.alreadyLogged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} déjà dans votre journal', other: '${formatted} déjà dans votre journal', ), 
			'adifImport.willImport' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} sera importé', other: '${formatted} seront importés', ), 
			'adifImport.newContacts' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} nouveau contact', other: '${formatted} nouveaux contacts', ), 
			'adifImport.merging' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} sera fusionné avec un contact existant', other: '${formatted} seront fusionnés avec des contacts existants', ), 
			'adifImport.unusable' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} ne peut pas être importé (pas d\'indicatif)', other: '${formatted} ne peuvent pas être importés (pas d\'indicatif)', ), 
			'adifImport.flagged' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} mérite un examen plus attentif', other: '${formatted} méritent un examen plus attentif', ), 
			'adifImport.missingRefs' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Les références n\'ont pas pu être récupérées pour ${count} contact', other: 'Les références n\'ont pas pu être récupérées pour ${formatted} contacts', ), 
			'adifImport.partialRefs' => ({required num count, required Object programs, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: 'Les références ${programs} sont peut-être incomplètes pour ${count} contact', other: 'Les références ${programs} sont peut-être incomplètes pour ${formatted} contacts', ), 
			'adifImport.stackingTypesUnknown' => 'Les contacts combinés risquent de perdre une référence — les activités n\'ont pas pu indiquer quels types se cumulent. Annulez et réessayez pour éviter cela.',
			'adifImport.nothingToImport' => 'Rien dans ce fichier ne peut être importé',
			'adifImport.confirm' => 'Importer',
			'adifImport.importing' => ({required Object filename}) => 'Importation de ${filename}…',
			'adifImport.imported' => ({required num count, required Object filename, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} contact importé depuis ${filename}', other: '${formatted} contacts importés depuis ${filename}', ), 
			'adifImport.failed' => ({required Object filename, required Object error}) => 'Impossible d\'importer ${filename} : ${error}',
			'adifImport.notAdif' => ({required Object filename}) => '${filename} ne ressemble pas à un fichier ADIF',
			'adifImport.stationWarning' => ({required Object calls, required Object station}) => 'Attention : cet ADIF contient des QSOs de ${calls}, mais ils seront importés comme ${station} si vous continuez.',
			'adifImport.stationCallJoin' => ' et ',
			'adifImport.noDate' => ({required num count, required Object formatted}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('fr'))(count, one: '${count} n\'a pas de date et ne peut pas être importé', other: '${formatted} n\'ont pas de date et ne peuvent pas être importés', ), 
			'adifImport.activationFound' => ({required Object refs}) => 'Ce fichier contient une activation de ${refs}.',
			'adifImport.addActivation' => 'L\'ajouter à cette opération',
			'adifImport.shortfall' => ({required Object written, required Object planned}) => 'Seuls ${written} sur ${planned} ont pu être appliqués — le journal a changé pendant que vous décidiez.',
			'adifImport.busy' => 'Une importation est déjà en cours. Attendez qu\'elle se termine avant d\'en lancer une autre.',
			'adifImport.oneFileOnly' => 'Déposez un seul fichier ADIF à la fois — l\'ordre d\'importation des fichiers détermine quelles données l\'emportent.',
			'adifImport.tooMany' => ({required Object filename, required Object limit}) => '${filename} contient plus de ${limit} QSOs, le maximum qu\'une opération peut importer à la fois.',
			'offline.statusOffline' => 'Internet : HORS LIGNE',
			'offline.statusOnline' => 'Internet : connecté',
			'offline.noRoute' => 'Aucune connexion réseau.',
			'offline.unreachable' => 'Le réseau fonctionne, mais aucun serveur ne répond — souvent une page de connexion qui attend dans un navigateur.',
			'offline.reachable' => 'Tous les services répondent normalement.',
			'offline.whatStops' => 'Les recherches, les spots et les fichiers de données sont en pause. La saisie et la synchronisation à proximité ne le sont pas.',
			'offline.servicesTitle' => 'Services',
			'offline.noServices' => 'Aucun service ne s\'est encore manifesté.',
			'offline.lastSuccess' => ({required Object when}) => 'Dernière réponse il y a ${when}',
			'offline.neverSucceeded' => 'N\'a pas encore répondu',
			'offline.nextAttempt' => ({required Object when}) => 'Prochaine tentative dans ${when}',
			'offline.nextAttemptNow' => 'Prochaine tentative imminente',
			'offline.retry' => 'Réessayer maintenant',
			'offline.retrying' => 'Tentative…',
			'offline.retryReached' => 'De nouveau en ligne.',
			'offline.retryUnreachable' => 'Toujours aucune réponse.',
			'offline.retryNotAttempted' => 'Rien à envoyer pour le moment.',
			'offline.retryThrottled' => 'Tentative à l\'instant — patientez un peu.',
			'offline.retryDisabled' => 'La synchronisation est désactivée : il n\'y a donc rien avec quoi tester.',
			'offline.syncService' => 'Synchronisation Ham2K LoFi',
			'offline.retryInFlight' => 'Tentative déjà en cours — patientez.',
			'exportSettings.defaultsDescription' => 'Paramètres de base pour tous les exports, avec des modèles de nom de fichier et de titre distincts pour les activités de référence et les autres activités. Chaque type d\'export peut fournir ses propres valeurs par défaut ou des paramètres personnalisés.',
			'exportSettings.referenceActivities' => 'Activités de référence',
			'exportSettings.otherActivities' => 'Autres activités',
			'exportSettings.adifFields' => 'Champs ADIF',
			'exportSettings.loadFailed' => 'Les paramètres d\'export n\'ont pas pu être chargés.',
			'exportSettings.retry' => 'Réessayer',
			'exportSettings.compactFileNamesDescriptionOn' => 'Noms de fichiers compacts, comme N0CALL@US-1234-20260715.adi.',
			'exportSettings.compactFileNamesDescriptionOff' => 'Noms de fichiers descriptifs, comme 2026-07-15 N0CALL at US-1234.adi.',
			'exportSettings.includePrivateDataDescriptionOn' => 'Inclusion des noms, adresses, e-mails, notes et positions précises dans les fichiers ADIF.',
			'exportSettings.includePrivateDataDescriptionOff' => 'Exclusion des noms, adresses, e-mails et notes ; positions limitées à des locators à six caractères.',
			'exportSettings.includeLookupDataDescriptionOn' => 'Inclusion des informations provenant des services de recherche d\'indicatifs.',
			'exportSettings.includeLookupDataDescriptionOff' => 'Exclusion des informations provenant des services de recherche d\'indicatifs ; les valeurs saisies manuellement sont conservées.',
			'exportSettings.customTemplatesDescriptionOn' => 'Vos modèles personnalisés sont actifs et peuvent être modifiés ci-dessous.',
			'exportSettings.customTemplatesDescriptionOff' => 'Les modèles par défaut sont actifs. Vos modèles personnalisés sont conservés pour plus tard.',
			'exportSettings.type' => 'Type d\'export',
			'exportSettings.defaults' => 'Valeurs par défaut',
			'exportSettings.includeLookupData' => 'Inclure les données de recherche',
			'exportSettings.customTemplates' => 'Modèles personnalisés',
			'exportSettings.filenameTemplate' => 'Modèle de nom de fichier',
			'exportSettings.compactFilenameTemplate' => 'Modèle de nom de fichier compact',
			'exportSettings.titleTemplate' => 'Modèle de titre',
			'exportSettings.adifNotesTemplate' => 'Notes QSO ADIF',
			'exportSettings.adifCommentTemplate' => 'Commentaires QSO ADIF',
			'exportSettings.adifQslMessageTemplate' => 'Message QSL ADIF',
			'exportSettings.shared' => 'Les paramètres s\'appliquent à toutes les extensions utilisant ce type d\'export.',
			'exportSettings.defaultTemplates' => 'Activez Modèles personnalisés pour modifier les modèles de ce type.',
			'templateEditor.previewLabel' => 'Aperçu :',
			'templateEditor.reset' => 'Réinitialiser',
			'templateEditor.docs' => 'Documentation des modèles',
			'templateEditor.preview' => 'Aperçu d\'exemple',
			'templateEditor.reference' => 'Référence des modèles',
			'templateEditor.attributes' => 'Attributs disponibles',
			'templateEditor.filters' => 'Filtres',
			'templateEditor.flowControl' => 'Contrôle de flux',
			'templateEditor.unavailable' => 'L\'aperçu est indisponible tant que les extensions ne sont pas prêtes.',
			'templateEditor.empty' => '(sortie vide)',
			_ => null,
		};
	}
}
