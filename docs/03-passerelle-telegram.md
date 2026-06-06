# 03 · Passerelle Telegram : joindre l'agent depuis son téléphone

Durée réelle constatée : environ 1h, pièges compris. Sans les pièges : 15 minutes.

Jusqu'ici, parler à Hermès exigeait une session SSH. Ce doc lui ouvre une ligne
directe : un bot Telegram, verrouillé pour ne répondre qu'à vous.

## Étape 1 : créer le bot (sur le téléphone)

1. Chercher `BotFather` dans Telegram. Vérifier DEUX choses avant de taper :
   le username exact est `@BotFather` et il porte la coche bleue de
   vérification. Des faux BotFather existent et volent les tokens.
2. `/newbot`, puis un nom d'affichage (libre), puis un username (unique,
   sans accent, doit finir par `bot`).
3. BotFather répond avec le token du bot. Ce token est une clé : quiconque
   le possède peut lire et envoyer les messages du bot. Il ne se colle
   nulle part ailleurs que dans la config du serveur (étape 3).

## Étape 2 : récupérer son user ID Telegram (sans bot tiers)

L'assistant Hermès suggère @userinfobot. C'est un bot tiers : souvent hors
service, et aucune raison de lui faire confiance. L'API officielle fait
pareil sans intermédiaire :

1. Sur le téléphone : ouvrir la conversation avec son propre bot
   (lien `t.me/...` dans le message de BotFather) et lui envoyer `test`.
2. Sur le VPS :

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getUpdates"
```

Le JSON retourné contient `"from":{"id":123456789,...}` : ce nombre est
votre user ID. C'est lui qui servira d'allowlist.

Au passage, `getMe` permet de vérifier à quel bot appartient un token :

```bash
curl -s "https://api.telegram.org/bot<TOKEN>/getMe"
```

## Étape 3 : configurer la passerelle

```bash
docker exec -it hermes hermes setup gateway
```

| Question | Réponse | Pourquoi |
|---|---|---|
| Plateforme | **Telegram** | |
| Bot token | coller le token BotFather | stocké dans `~/.hermes/.env`, jamais dans le shell history |
| Allowed user IDs | **votre ID, et lui seul** | sans allowlist, n'importe qui trouvant le bot peut discuter avec votre agent et dépenser vos crédits API |
| Home channel | **Y** (= votre ID) | la bannette où Hermès dépose ce que vous n'avez pas demandé sur le moment : résultats cron, notifications |
| Restart gateway | **Y** | mais lire le piège n°1 ci-dessous |

## Étape 4 : LE piège : redémarrer le container, pas juste la passerelle

Après le setup, la passerelle redémarre... et les logs affichent quand même :

```
WARNING gateway.run: No user allowlists configured.
WARNING gateway.run: No messaging platforms enabled.
```

La config est bien écrite dans `~/.hermes/.env`, mais le processus passerelle
hérite son environnement du démarrage du **container**. Le restart interne
proposé par l'assistant ne suffit pas :

```bash
docker restart hermes
```

Au redémarrage suivant, les deux warnings disparaissent et le bot répond.

## Étape 5 : golden test cross-canal

Le critère binaire du doc 01, étendu à la passerelle : une info apprise sur
un canal doit ressortir sur l'autre, dans une session neuve.

1. Sur Telegram : demander une info apprise en session terminal
   (ici : la couleur fétiche du doc 01). Restituée.
2. Sur Telegram : confier une info neuve (« j'aime les fraises »).
3. Au terminal, session neuve (`docker exec -it hermes hermes`) :
   demander « quel fruit est-ce que j'aime ? ». **Restituée.**

Conversation Telegram et session terminal sont deux discussions distinctes :
si l'info passe de l'une à l'autre, c'est par la mémoire persistante,
pas par l'historique de conversation. C'est la preuve que la passerelle
et le terminal parlent au même agent, avec le même carnet.

## Bonus : couper le dashboard qui pollue les logs

Avec `HERMES_DASHBOARD=1` mais sans authentification configurée, le
dashboard retente de démarrer en boucle et écrit deux lignes de refus
toutes les quelques secondes. Résultat : un journal illisible, qui a
failli masquer le vrai diagnostic de l'étape 4. Il ne faut PAS suivre la
suggestion `--insecure` du message : on ne désactive pas un garde-fou,
on coupe la fonction qu'on n'utilise pas.

Un container ne se modifie pas à chaud, il se jette et se recrée. Tout
l'état vit dans `~/.hermes` : rien n'est perdu, c'est exactement ce que
le golden test a prouvé.

```bash
docker stop hermes
docker rm hermes
docker run -d --name hermes \
  --restart unless-stopped \
  -p 127.0.0.1:8642:8642 \
  -p 127.0.0.1:9119:9119 \
  -v ~/.hermes:/opt/data \
  --memory 2g --cpus 1.5 \
  nousresearch/hermes-agent:v2026.5.29.2 \
  gateway run
```

C'est désormais la commande de référence de ce guide (le doc 01 a été
mis à jour). Si un jour le dashboard devient utile : le réactiver et y
accéder par tunnel SSH, jamais en bind public.

## Les pièges rencontrés (du temps perdu pour vous en faire gagner)

1. **Le `/start` initial part chez BotFather, pas chez votre bot.** Symptôme :
   `getUpdates` renvoie `{"ok":true,"result":[]}`. Vérifier avec `getMe` à
   quel bot appartient le token, puis écrire dans la conversation dont le
   titre est le nom de VOTRE bot.
2. **Token tronqué au collage.** L'assistant répond `Invalid token format.
   Expected: <numeric_id>:<alphanumeric_hash>`. Recoller, vérifier que rien
   ne manque avant le `:`.
3. **`getMe` relancé au lieu de `getUpdates`** (flèche haut dans le terminal,
   les deux URLs ne diffèrent que par le dernier mot). `getMe` renvoie un
   objet `{...}`, `getUpdates` une liste `[...]` : si le résultat n'a pas de
   crochets, ce n'est pas la bonne commande.
4. **La session SSH coupe (5G) et la commande suivante part sur le PC local.**
   Symptôme sous Windows : `error during connect: ... dockerDesktopLinuxEngine`.
   Réflexe : toujours vérifier le début de ligne avant de taper
   (`root@vps` vs `PS C:\>`).

## Sécurité : l'état des lieux après ce doc

- Token : uniquement dans `~/.hermes/.env` sur le VPS (et chez BotFather)
- Allowlist : un seul user ID, tout le reste est refusé silencieusement
- `getMe` du bot : `can_read_all_group_messages: false` (défaut sain :
  même invité dans un groupe par erreur, il ne lit pas tout)
- Rien d'exposé sur l'IP publique : les passerelles Telegram sont des
  connexions sortantes, le CGNAT côté maison n'est même pas un sujet ici
