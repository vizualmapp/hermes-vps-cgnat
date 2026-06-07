# 04 · Tunnel Tailscale : relier le VPS à une maison sans IP publique

Durée réelle constatée : environ 1h. C'était l'étape réputée incertaine du projet : la réponse est non seulement « ça marche », mais « ça marche en direct, sans relais ».

## Le problème

La maison est connectée en 5G avec du CGNAT : l'opérateur fait passer des dizaines d'abonnés derrière la même IP publique. Aucune connexion entrante possible, pas de port à ouvrir, pas de DynDNS qui tienne. Il n'y a littéralement pas de sonnette : le VPS ne peut pas appeler la maison.

## Le principe de la solution

Au lieu qu'un bâtiment sonne chez l'autre, les DEUX percent une porte vers l'extérieur (connexion sortante, ce que le CGNAT autorise sans problème) et les deux portes débouchent sur un couloir privé chiffré (WireGuard). Le serveur de coordination Tailscale met les machines en relation, puis le trafic passe en direct entre elles, chiffré de bout en bout. Chaque machine reçoit une adresse stable en `100.x.y.z`, comme si elles étaient sur le même réseau local.

Rien d'exposé à Internet, ni d'un côté ni de l'autre. Le plan gratuit (100 machines) couvre très largement ce besoin.

## Étape 1 : le compte Tailscale

Sur tailscale.com, connexion via le compte GitHub existant (cohérent avec le reste du projet, pas de nouveau mot de passe). Le tailnet est créé instantanément.

Au passage : si votre navigateur traduit les pages automatiquement, vous verrez « Écaille de queue » (Tailscale traduit littéralement) et « bûches » (Logs). Désactivez la traduction sur les pages techniques, un libellé approximatif finit toujours par coûter du temps.

## Étape 2 : le client sur le VPS

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up
```

Le script officiel ajoute le dépôt apt (mises à jour propres ensuite). `tailscale up` affiche une URL d'authentification à ouvrir dans le navigateur : c'est le « cette machine est à moi ». L'adresse de la machine apparaît ensuite avec `tailscale ip -4`.

## Étape 3 : l'add-on sur Home Assistant OS

Attention au renommage : depuis HA 2026, « Modules complémentaires » s'appelle **« Apps »**. Donc : Paramètres → Apps → Boutique → Tailscale (l'add-on officiel maintenu par Franck Nijhof).

Réglages avant démarrage :
- **Chien de garde (Watchdog) : ACTIVÉ** — redémarrage auto en cas de plantage, c'est un tunnel censé tenir 24/7
- **Mise à jour automatique : DÉSACTIVÉE** — on ne change pas une pièce du tunnel sans le savoir (même philosophie que la version Docker pinnée du doc 01)
- « Lancer au démarrage » : activé par défaut, le tunnel survit aux reboots de la VM

Après démarrage, l'URL d'authentification est dans l'onglet Journal de l'add-on. Même rituel que pour le VPS.

## Étape 4 : désactiver l'expiration des clés, TOUT DE SUITE

Par défaut, les clés des machines expirent au bout de quelques mois : sain pour un laptop, fatal pour des serveurs sans humain devant. Sans cette étape, le tunnel meurt silencieusement un dimanche dans six mois et vous chercherez pourquoi pendant une heure.

Console Tailscale → Machines → menu `...` de chaque machine → **Disable key expiry**. Les machines gardent leur clé tant que VOUS ne les révoquez pas depuis la console.

## Étape 5 : NE PAS approuver les routes de sous-réseau

L'add-on HA propose par défaut de partager tout votre réseau local à travers le tunnel (badges « Sous-réseaux / Nœud de sortie » dans la console, routes `192.168.x.0/22` en attente d'approbation). **Refusez.** Pour ce projet, seul Home Assistant doit être joignable, pas le NAS, pas les caméras, pas le reste du LAN. Moindre privilège, toujours : si un jour l'agent doit parler à une autre machine, vous approuverez cette route-là en connaissance de cause.

## Golden test

Depuis le VPS :

```bash
tailscale ping 100.x.y.z        # l'adresse Tailscale du HA
curl -s -o /dev/null -w "%{http_code}\n" http://100.x.y.z:8123
```

Résultat constaté ici :

```
pong from homeassistant via DERP(par) in 60ms
pong from homeassistant via DERP(par) in 39ms
pong from homeassistant via DERP(par) in 38ms
pong from homeassistant via 78.241.x.x:22293 in 49ms
```

Les trois premiers pongs passent par le relais Tailscale parisien (DERP), puis la traversée NAT réussit et la liaison bascule **en direct** à travers le CGNAT. Le relais ne reste que comme roue de secours. Et le `curl` renvoie `200` : l'interface HA répond au VPS.

Dernier test, le plus important pour la suite : la même commande depuis L'INTÉRIEUR du container de l'agent (c'est lui qui devra parler à HA) :

```bash
docker exec hermes curl -s -o /dev/null -w "%{http_code}\n" http://100.x.y.z:8123
```

`200` aussi : Docker route le trafic du container vers le tunnel sans configuration supplémentaire.

## Ce qu'on a au final

Un agent sur un VPS à Paris qui peut joindre le Home Assistant d'une maison autonome en énergie, connectée en 5G sans IP publique, sur une liaison chiffrée de bout en bout, sans un seul port ouvert nulle part. La suite — le faire AGIR sur la maison sans lui donner les clés — est dans le [doc 05](05-pilotage-domotique-garde-fou.md).
