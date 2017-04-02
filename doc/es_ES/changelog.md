Changelog
=========

3.0
===

-   Supresión del modo esclavo

-   Posibilidad de activar un escenario sobre un cambio de una variable

-   Les mises à jour de variables déclenchent maintenant la mise à jour des commandes d’un équipement virtuel (il faut la dernière version du plugin)

-   Posibilidad de tener un icono en los comandos de tipo Info

-   Posibilidad sobre los comandos de mostrar el nombre y el icono

-   Adición de una acción *alerta* sobre los escenarios

-   Adición de una acción "popup" en escenarios

-   Los widgets de comandos ahora pueden tener un método de actualización que evita las llamadas AJAX a Jeedom

-   Los widgets de los escenarios ahora se actualizan sin llamadas ajax sobre el widget

-   El resumen general y las partes ahora se actualizan sin llamadas de ajax Botón derecho del ratón en un elemento de un resumen domótico te lleva a una vista detallada del mismo

-   Ahora puedes poner en el Resumen los comandos de tipo texto

-   Cambio de bootstraps slider en slider (corregido el error del doble evento de los sliders)

-   Salvado automático de vistas cuando se haga clic sobre el botón "ver resultado"

-   Posibilidad de tener los documentos localmente

-   Los desarrolladores de terceros pueden añadir su propio sistema de gestión de ticket

-   Revisión de la configuración de derechos de usuario (todo está en la página de administración de usuario)

-   Actualizadas las librerias : jquery (en 3.0) , jquery mobile, hightstock y table sorter, font-awesome

-   Grandes mejoras en diseño:

    -   Todas las acciones son ahora accesibles desde un clic derecho

    -   Posibilidad de añadir un solo comando

    -   Posibilidad de añadir una imagen o una secuencia de vídeo

    -   Posibilidad de añadir zonas (localización clickable):

        -   Zona de tipo macro: lanza una serie de acciones cuando hagas clic en el

        -   Zona de tipo binario: lanza una serie de acciones haciendo click sobre el, en función del estado de un comando

        -   Zona de tipo widget : muestra un widget hacido clic o pasando sobre la zona

    -   Optimización general del código general

    -   Posibilidad de abrir una cuadrícula y seleccione su tamaño (10 x 10, 15 x 15 o 30 x 30)

-   Posibilidad de activar una magnetización de los widgets sobre la cuadrícula

    -   Posibilidad de activar una magnetización de widgets entre ellos

    -   Certains types de widgets peuvent maintenant être dupliqués

    -   Posibilidad de bloquear un elemento

-   Ahora los plugins pueden utilizar una clave api propia

-   Añadidas interacciones automáticas, Jeedom va a intentar entender la frase, para llevar a cabo la acción y responder

-   Añadida gestión de demonios en versión móvil

-   Añadida gestión de crons en versión móvil

-   Añadir cierta información de salud en versión móvil

-   Agregado sobre la página de batería los módulos en alerta

-   Objetos sin widget automáticamente se ocultan en el Dashboard

-   Añadido un botón en la configuración avanzada de dispositivos/comando para ver los eventos de él o ella

-   Un disparador de un escenario ahora puede tener condiciones

-   Un double clic sur la ligne d’une commande (sur la page de configuration) ouvre maintenant la configuration avancée de celle-ci

-   Possibilité d’interdire certaines valeurs pour une commande (dans la configuration avancée de celle-ci)

-   Añadidos campos de configuración en la parte posterior del estado automático (ej a 0 después de 4 minutos) en la configuración avanzada de un comando

-   Añadida una función valueDate en escenarios (consulte la documentación de los escenarios)

-   Posibilidad sobre escenarios de cambiar el valor de un comando con la acción "evento"

-   Ajout d’un champs commentaire sur la configuration avancée d’un équipement

-   Ajout d’un système d’alerte sur les commandes avec 2 niveaux : alerte et danger. La configuration se trouve dans la configuration avancée des commandes (de type info seulement bien sûr). Vous pouvez voir les modules en alerte sur la page Analyse → Equipement. Vous pouvez configurer les actions sur alerte sur la page de configuration générale de Jeedom

-   Ajout d’une zone "tableau" sur les vues qui permet d’afficher une ou plusieurs colonnes par case. Les cases supportent aussi le code html

-   Jeedom peut maintenant tourner sans les droits root (expérimental). Attention car sans les droits root vous devrez manuellement lancer les scripts pour les dépendances des plugins

-   Optimisation du calcul des expressions (calcul des tags uniquement si présents dans l’expression)

-   Ajout dans l’API de fonction pour avoir accès au résumé (global et d’objet)

-   Possibilité de restreindre l’accès de chaque clef api en fonction de l’IP

-   Possibilité sur l’historique de faire des regroupements par année

-   Le timeout sur la commande wait peut maintenant être un calcul

-   Correction d’un bug s’il y a des " dans les paramètres d’une action

-   Passage au sha512 pour le hash des mots de passe (le sha1 étant compromis)

-   Correction d’un bug dans la gestion du cache qui le faisait grossir indéfiniment

-   Correction de l’accès à la doc des plugins tiers si ceux-ci n’ont pas de doc en local

-   Les interactions peuvent prendre en compte la notion de contexte (en fonction de la demande précédente et celle d’avant)

-   Possibilité de ponderer les mots en fonction de leur taille pour l’analyse de la compréhension

-   Les plugins peuvent maintenant ajouter des interactions

-   Les interactions peuvent maintenant renvoyer des fichiers en plus de la réponse

-   Possibilité de voir sur la page de configuration des plugins les fonctionalités de celui-ci (interact, cron…) et de la désactiver unitairement

-   Les interactions automatiques peuvent renvoyer les valeurs des résumés

-   Possibilité de définir des synomymes pour les objets, équipements, commandes et résumés qui seront utilisés dans les réponses contextuelle et résumés

-   Jeedom sait gérer plusieurs interactions liées (contextuellement) en une. Elles doivent être séparées par un mot clef (par défaut et). Exemple : "Combien fait-il dans la chambre et dans le salon ?" ou "Allume la lumière de la cuisine et de la chambre."

-   Le statut des scénarios sur la page d'édition est maintenant mis à jour dynamiquement

-   Possibilité d’exporter une vue en PDF, PNG, SVG ou JPEG avec la commande "report" dans un scénario

-   Possibilité d’exporter un design en PDF, PNG, SVG ou JPEG avec la commande "report" dans un scénario

-   Possibilité d’exporter un panel d’un plugin en PDF, PNG, SVG ou JPEG avec la commande "report" dans un scénario

-   Ajout d’une page de gestion de rapport (pour les retélécharger ou les supprimer)

-   Correction d’un bug sur la date de dernière remontée d'événement pour certains plugins (alarme)

-   Correction d’un bug d’affichage avec chrome 55

-   Optimisation du backup (sur un rpi2 le temps est divisé par 2)

-   Optimisation de la restoration

-   Optimisation du processus de mise à jour

-   Uniformisation du tmp jeedom, maintenant tout est dans /tmp/jeedom

-   Possibilité d’avoir un graph des differentes liaison d’un scénario, équipement, objet, commande ou variable

-   Possibilité de regler la profondeur des graphique de lien en fonction de l’objet d’origine

-   Possibilité d’avoir les logs des scénarios en temps réel (ralenti l’execution des scénarios)

-   Possibilité de passer des tags lors du lancement d’un scénario

-   Optimisation du chargement des scenarios et page utilisant des actions avec option

-   Amélioration de la gestion de la répétition des valeurs des commandes

-   Correction de bugs

-   Optimisation de la vérification des mises à jour

2.4
===

-   Optimisation générale

    -   Regroupement de requêtes SQL

    -   Suppression de requêtes inutiles

    -   Passage en cache du pid, état et dernier lancement des scénarios

    -   Passage en cache du pid, état et dernier lancement des crons

    -   Dans 99% des cas plus de requête d'écriture sur la base en fonctionnement nominal (donc hors configuration de Jeedom, modifications, installation, mise à jour…)

-   Suppression du fail2ban (car facilement contournable en envoyant une fausse adresse ip), cela permet d’accélérer Jeedom

-   Ajout dans les interactions d’une option sans catégorie pour que l’on puisse générer des interactions sur des équipements sans catégorie

-   Ajout dans les scénarios d’un bouton de choix d'équipement sur les commandes de type slider

-   Mise à jour de bootstrap en 2.3.7

-   Ajout de la notion de résumé domotique (permet de connaitre d’un seul coup le nombre de lumières à ON, les porte ouvertes, les volets, les fenêtres, la puissance, les détections de mouvement…). Tout cela se configure sur la page de gestion des objets

-   Ajout de pre et post commande sur une commande. Permet de déclencher tout le temps une action avant ou après une autre action. Peut aussi permettre de synchroniser des équipements pour, par exemple, que 2 lumières s’allument toujours ensemble avec la même intensité.

-   Optimisation des listenner

-   Ajout de modal pour afficher les informations brutes (attribut de l’objet en base) d’un équipement ou d’une commande

-   Possibilité de copier l’historique d’une commande sur une autre commande

-   Possibilité de remplacer une commande par une autre dans tout Jeedom (même si la commande à remplacer n’existe plus)

2.3
===

-   Correction des filtres sur le market

-   Correction des checkbox sur la page d'édition des vues (sur une zone graphique)

-   Correction des checkbox historiser, visible et inverser dans le tableau des commandes

-   Correction d’un soucis sur la traduction des javascripts

-   Ajout d’une catégorie de plugin : objet communiquant

-   Ajout de GENERIC\_TYPE

-   Suppression des filtres nouveau et top sur le parcours des plugins du market

-   Renommage de la catégorie par defaut sur le parcours des plugins du market en "Top et nouveauté"

-   Correction des filtres gratuit et payant sur le parcours des plugins du market

-   Correction d’un bug qui pouvait amener à une duplication des courbes sur la page d’historique

-   Correction d’un bug sur la valeur de timeout des scénarios

-   correction d’un bug sur l’affichage des widgets dans les vues qui prenait la version dashboard

-   Correction d’un bug sur les designs qui pouvait utiliser la configuration des widgets du dashboard au lieu des designs

-   Correction de bugs de la sauvegarde/restauration si le nom du jeedom contient des caractères spéciaux

-   Optimisation de l’organisation de la liste des generic type

-   Amélioration de l’affichage de la configuration avancée des équipements

-   Correction de l’interface d’accès au backup depuis

-   Sauvegarde de la configuration lors du test du market

-   Préparation à la suppression des bootstrapswtich dans les plugins

-   Correction d’un bug sur le type de widget demandé pour les designs (dashboard au lieu de dplan)

-   correction de bug sur le gestionnaire d’événements

-   passage en aléatoire du backup la nuit (entre 2h10 et 3h59) pour éviter les soucis de surcharge du market

-   Correction du market de widget

-   Correction d’un bug sur l’accès au market (timeout)

-   Correction d’un bug sur l’ouverture des tickets

-   Correction d’un bug de page blanche lors de la mise à jour si le /tmp est trop petit (attention la correction prend effet à l’update n+1)

-   Ajout d’un tag jeedom\_name dans les scénarios (donne le nom du jeedom)

-   Correction de bugs

-   Déplacement de tous les fichiers temporaire dans /tmp

-   Amélioration de l’envoi des plugins (dos2unix automatique sur les fichiers \*.sh)

-   Refonte de la page de log

-   Ajout d’un thème darksobre pour mobile

-   Possibilité pour les developpeurs d’ajouter des options de configuration des widget sur les widgets spécifique (type sonos, koubachi et autre)

-   Optimisation des logs (merci @kwizer15)

-   Possibilité de choisir le format des logs

-   Optimisation diverse du code (merci @kwizer15)

-   Passage en module de la connexion avec le market (permettra d’avoir un jeedom sans aucun lien au market)

-   Ajout d’un "repo" (module de connexion type la connexion avec le market) fichier (permet d’envoi un zip contenant le plugin)

-   Ajout d’un "repo" github (permet d’utiliser github comme source de plugin, avec systeme de gestion de mise à jour)

-   Ajout d’un "repo" URL (permet d’utiliser URL comme source de plugin)

-   Ajout d’un "repo" Samba (utilisable pour pousser des backups sur un serveur samba et récupérer des plugins)

-   Ajout d’un "repo" FTP (utilisable pour pousser des backups sur un serveur FTP et récupérer des plugins)

-   Ajout pour certain "repo" de la possibilité de recuperer le core de jeedom

-   Ajout de tests automatique du code (merci @kwizer15)

-   Possibilité d’afficher/masquer les panels des plugins sur mobile et ou desktop (attention maintenant par défaut les panels sont masqués)

-   Possibilité de désactiver les mises à jour d’un plugin (ainsi que la vérification)

-   Possibilité de forcé la verification des mises à jour d’un plugin

-   Légère refonte du centre de mise à jour

-   Possibilité de désactiver la vérification automatique des mises à jour

-   Correction d’un bug qui remettait toute les données à 0 suite à un redémarrage

-   Possibilité de configurer le niveau de log d’un plugin directement sur la page de configuration de celui-ci

-   Possibilité de consulter les logs d’un plugin directement sur la page de configuration de celui-ci

-   Suppression du démarrage en debug des démons, maintenant le niveau de logs du démon est le même que celui du plugin

-   Nettoyage de lib tierce

-   Suppression de responsive voice (fonction dit dans les scénarios qui marchait de moins en moins bien)

-   Correction de plusieurs faille de sécurité

-   Ajout d’un mode synchrone sur les scénarios (anciennement mode rapide)

-   Possibilité de rentrer manuellement la position des widgets en % sur les design

-   Refonte de la page de configuration des plugins

-   Possibilité de configurer la transparence des widgets

-   Ajout de l’action jeedom\_poweroff dans les scénarios pour arrêter jeedom

-   Retour de l’action scenario\_return pour faire un retour à une intéraction (ou autre) à partir d’un scénario

-   Passage en long polling pour la mise à jour de l’interface en temps réel

-   Correction d’un bug lors de refresh multiple de widget

-   Optimisation de la mise à jour des widgets commandes et équipements

-   Ajout d’un tag begin\_backup, end\_backup, begin\_update, end\_update, begin\_restore, end\_restore dans les scénarios

2.2
===

-   Correction de bugs

-   Simplification de l’accès aux configurations des plugins à partir de la page santé

-   Ajout d’une icône indiquant si le démon est démarré en debug ou non

-   Ajout d’une page de configuration globale des historiques (accessible à partir de la page historique)

-   Correction de bugs pour docker

-   Possibilité d’autoriser un utilisateur à se connecter uniquement à partir d’un poste sur le réseau local

-   Refonte de la configuration des widgets (attention il faudra sûrement reprendre la configuration de certains widgets)

-   Renforcement de la gestion des erreurs sur les widgets

-   Possibilité de réordonner les vues

-   Refonte de la gestion des thèmes

2.1
===

-   Refonte du système de cache de Jeedom (utilisation de doctrine cache). Cela permet par exemple de connecter Jeedom à un serveur redis ou memcached. Par défaut Jeedom utilise un système de fichiers (et non plus la BDD MySQL ce qui permet de la décharger un peu), celui-ci se trouve dans /tmp il est donc conseillé si vous avez plus de 512 Mo de RAM de monter le /tmp en tmpfs (en RAM pour plus de rapidité et une diminution de l’usure de la carte SD, je recommande une taille de 64mo). Attention lors du redémarrage de Jeedom le cache est vidé il faut donc attendre pour avoir la remontée de toutes les infos

-   Refonte du système de log (utilisation de monolog) qui permet une intégration à des systèmes de logs (type syslog(d))

-   Optimisation du chargement du dashboard

-   Correction de nombreux warning

-   Possibilité lors d’un appel api à un scénario de passer des tags dans l’url

-   Support d’apache

-   Optimisation pour docker avec support officiel de docker

-   Optimisation pour les synology

-   Support + optimisation pour php7

-   Refonte des menus Jeedom

-   Suppression de toute la partie gestion réseau : wifi, ip fixe… (reviendra sûrement sous forme de plugin). ATTENTION ce n’est pas le mode maître/esclave de jeedom qui est supprimé

-   Suppression de l’indication de batterie sur les widgets

-   Ajout d’une page qui résume le statut de tous les équipements sur batterie

-   Refonte du DNS Jeedom, utilisation d’openvpn (et donc du plugin openvpn)

-   Mise à jour de toutes les libs

-   Interaction : ajout d’un système d’analyse syntaxique (permet de supprimer les interactions avec de grosses erreurs de syntaxe type « le chambre »)

-   Suppression de la mise à jour de l’interface par nodejs (passage en pulling toutes les secondes sur la liste des événements)

-   Possibilité pour les applications tierces de demander par l’api les événements

-   Refonte du système « d’action sur valeur » avec possibilité de faire plusieurs actions et aussi l’ajout de toutes les actions possibles dans les scénarios (attention il faudra peut-être toutes les reconfigurer suite à la mise à jour)

-   Possibilité de désactiver un bloc dans un scénario

-   Ajout pour les développeurs d’un système d’aide tooltips. Il faut sur un label mettre la classe « help » et mettre un attribut data-help avec le message d’aide souhaité. Cela permet à Jeedom d’ajouter automatiquement à la fin de votre label une icône « ? » et au survol d’afficher le texte d’aide

-   Changement du processus de mise à jour du core, on ne demande plus l’archive au Market mais directement à Github maintenant

-   Ajout d’un système centralisé d’installation des dépendances sur les plugins

-   Refonte de la page de gestion des plugins

-   Ajout des adresses mac des différentes interfaces

-   Ajout de la connexion en double authentification

-   Suppression de la connexion par hash (pour des raisons de sécurité)

-   Ajout d’un système d’administration OS

-   Ajout de widgets standards Jeedom

-   Ajout d’un système en beta pour trouver l’IP de Jeedom sur le réseau (il faut connecter Jeedom sur le réseau, puis aller sur le market et cliquer sur « Mes Jeedoms » dans votre profil)

-   Ajout sur la page des scénarios d’un testeur d’expression

-   Revue du système de partage de scénario

2.0
===

-   Refonte du système de cache de Jeedom (utilisation de doctrine cache). Cela permet par exemple de connecter Jeedom à un serveur redis ou memcached. Par défaut Jeedom utilise un système de fichiers (et non plus la BDD MySQL ce qui permet de la décharger un peu), celui-ci se trouve dans /tmp il est donc conseillé si vous avez plus de 512 Mo de RAM de monter le /tmp en tmpfs (en RAM pour plus de rapidité et une diminution de l’usure de la carte SD, je recommande une taille de 64mo). Attention lors du redémarrage de Jeedom le cache est vidé il faut donc attendre pour avoir la remontée de toutes les infos

-   Refonte du système de log (utilisation de monolog) qui permet une intégration à des systèmes de logs (type syslog(d))

-   Optimisation du chargement du dashboard

-   Correction de nombreux warning

-   Possibilité lors d’un appel api à un scénario de passer des tags dans l’url

-   Support d’apache

-   Optimisation pour docker avec support officiel de docker

-   Optimisation pour les synology

-   Support + optimisation pour php7

-   Refonte des menus Jeedom

-   Suppression de toute la partie gestion réseau : wifi, ip fixe… (reviendra sûrement sous forme de plugin). ATTENTION ce n’est pas le mode maître/esclave de jeedom qui est supprimé

-   Suppression de l’indication de batterie sur les widgets

-   Ajout d’une page qui résume le statut de tous les équipements sur batterie

-   Refonte du DNS Jeedom, utilisation d’openvpn (et donc du plugin openvpn)

-   Mise à jour de toutes les libs

-   Interaction : ajout d’un système d’analyse syntaxique (permet de supprimer les interactions avec de grosses erreurs de syntaxe type « le chambre »)

-   Suppression de la mise à jour de l’interface par nodejs (passage en pulling toutes les secondes sur la liste des événements)

-   Possibilité pour les applications tierces de demander par l’api les événements

-   Refonte du système « d’action sur valeur » avec possibilité de faire plusieurs actions et aussi l’ajout de toutes les actions possibles dans les scénarios (attention il faudra peut-être toutes les reconfigurer suite à la mise à jour)

-   Possibilité de désactiver un bloc dans un scénario

-   Ajout pour les développeurs d’un système d’aide tooltips. Il faut sur un label mettre la classe « help » et mettre un attribut data-help avec le message d’aide souhaité. Cela permet à Jeedom d’ajouter automatiquement à la fin de votre label une icône « ? » et au survol d’afficher le texte d’aide

-   Changement du processus de mise à jour du core, on ne demande plus l’archive au Market mais directement à Github maintenant

-   Ajout d’un système centralisé d’installation des dépendances sur les plugins

-   Refonte de la page de gestion des plugins

-   Ajout des adresses mac des différentes interfaces

-   Ajout de la connexion en double authentification

-   Suppression de la connexion par hash (pour des raisons de sécurité)

-   Ajout d’un système d’administration OS

-   Ajout de widgets standards Jeedom

-   Ajout d’un système en beta pour trouver l’IP de Jeedom sur le réseau (il faut connecter Jeedom sur le réseau, puis aller sur le market et cliquer sur « Mes Jeedoms » dans votre profil)

-   Ajout sur la page des scénarios d’un testeur d’expression

-   Revue du système de partage de scénario

