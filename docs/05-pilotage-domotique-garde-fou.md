# 05 · L'agent agit sur la maison : le garde-fou structurel

Durée réelle constatée : environ 45 minutes. C'est l'étape où un agent LLM reçoit le droit d'agir sur le monde physique : c'est donc surtout une étape de SÉCURITÉ.

## Le principe : jamais l'API entière à un agent LLM

Un agent LLM est persuasif, créatif, et manipulable par quiconque lui parle. On ne lui donne donc jamais un jeton d'API domotique : on lui donne un SCRIPT. Le script connaît le jeton, et n'accepte que 5 actions sur 2 ampoules. Tout le reste est refusé **par construction, pas par consigne**. Même si l'agent hallucine, ou que quelqu'un tente de le manipuler via Telegram, le rayon d'action maximal dans la maison reste : deux lampes qui clignotent.

La discipline écrite dans un prompt peut être contournée. La discipline écrite dans un `case` shell, non.

## Étape 1 : un utilisateur Home Assistant dédié, non administrateur

Paramètres → Personnes → Ajouter : utilisateur `hermes`, **Administrateur : NON**. Si le jeton fuite un jour, il ne peut ni modifier la config, ni installer des apps, ni créer d'utilisateurs. Et il se révoque d'un clic sans toucher à votre propre compte.

**Le piège :** l'option « Accès local uniquement » doit rester DÉSACTIVÉE. Contre-intuitif, mais les adresses Tailscale (`100.x`) ne comptent pas comme « réseau local » pour HA : avec cette option, le jeton serait refusé précisément là où on en a besoin.

## Étape 2 : le jeton longue durée

Les jetons HA appartiennent à l'utilisateur qui les crée. Donc : fenêtre de navigation privée → connexion en tant que `hermes` → profil → Sécurité → « Jetons d'accès longue durée » → créer. Le jeton ne s'affiche qu'une fois.

## Étape 3 : stocker le jeton sans laisser de trace

Sur le VPS, pour que le jeton n'apparaisse ni à l'écran ni dans l'historique shell :

```bash
read -s HATOKEN          # coller le jeton, Entrée — rien ne s'affiche, c'est voulu
echo "HA_URL=http://100.x.y.z:8123" >> ~/.hermes/.env
echo "HA_TOKEN=$HATOKEN" >> ~/.hermes/.env
unset HATOKEN
```

Vérification sans afficher les valeurs, puis test du jeton :

```bash
grep -o "^HA_[A-Z_]*" ~/.hermes/.env
curl -s -H "Authorization: Bearer $(grep '^HA_TOKEN=' ~/.hermes/.env | cut -d= -f2)" \
  http://100.x.y.z:8123/api/
```

Attendu : `{"message":"API running."}`. **Piège :** l'API répond 404 sur `/api` sans la barre finale — c'est `/api/`.

## Étape 4 : trouver ses objets, écrire le wrapper

L'inventaire des lumières vues par l'utilisateur `hermes` :

```bash
curl -s -H "Authorization: Bearer $TOKEN" http://100.x.y.z:8123/api/states \
  | grep -o '"entity_id":"light\.[^"]*"'
```

Ici : deux ampoules Zigbee RGB (`light.ampoule_tv_droit`, `light.ampoule_tv_gauche`)… et l'anneau LED de l'assistant vocal, que l'agent ne pilotera PAS — la liste blanche du script ne contient que les deux ampoules.

Le script complet est dans [`scripts/ha-lumiere.sh`](../scripts/ha-lumiere.sh). Il vit dans `~/.hermes/scripts/` sur le VPS (donc visible par l'agent à `/opt/data/scripts/`). Ce qu'il garantit :

- **2 cibles** possibles (`droit`, `gauche`, `deux`) — tout le reste refusé
- **5 actions** possibles (`on`, `off`, `toggle`, `status`, `couleur`) — tout le reste refusé
- la couleur n'accepte qu'**un seul mot en lettres minuscules** (validation `case` POSIX) : aucune injection possible dans la requête JSON
- le jeton est lu par le script dans `.env`, l'agent ne le manipule jamais

## Étape 5 : tester les refus AVANT de brancher l'agent

```bash
docker exec hermes /opt/data/scripts/ha-lumiere.sh status deux        # lit l'état réel
docker exec hermes /opt/data/scripts/ha-lumiere.sh on led_ring        # → Cible refusee
docker exec hermes /opt/data/scripts/ha-lumiere.sh delete deux        # → Action refusee
docker exec hermes /opt/data/scripts/ha-lumiere.sh couleur deux "red; rm -rf /"   # → Couleur refusee
```

Si un de ces tests passe au lieu d'être refusé, on s'arrête et on corrige le script. Le garde-fou se vérifie comme du code, pas comme une promesse.

## Étape 6 : apprendre l'outil à l'agent

Un message Telegram suffit (la mémoire de l'agent fait le reste) : décrire le script, sa syntaxe, et — important — le contexte PHYSIQUE des objets (« gauche = à gauche de la TV du salon »). Un agent qui sait QU'il y a deux ampoules mais pas OÙ elles sont répondra mal aux demandes naturelles. Ajouter aussi la consigne de périmètre : « c'est ton seul moyen d'agir sur la maison, refuse le reste » — elle est cosmétique (le script refuse de toute façon) mais améliore ses réponses.

## Golden test (validé en conditions réelles)

Téléphone en 4G, HORS du réseau de la maison :

1. « Éteins l'ampoule gauche de la tv du salon » → l'agent exécute le script → l'ampoule s'éteint physiquement
2. « Allume les deux ampoules de la tv avec **ma couleur préférée** » → l'agent croise sa mémoire (couleur apprise deux jours plus tôt, dans un autre canal, en session terminal) avec son nouvel outil → **les deux ampoules passent au cyan dans le salon**

Mémoire persistante + outil contraint + tunnel chiffré, déclenchés par une phrase en langage naturel depuis un réseau mobile. C'est la démonstration complète du concept « agent autonome à mémoire » appliqué au monde physique — avec un rayon d'action volontairement limité à deux lampes.

## Relevé des coûts et guide final : doc 06 à venir
