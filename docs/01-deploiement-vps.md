# 01 · Déployer Hermes sur le VPS et valider le golden test

Durée réelle constatée : environ 1h30, pièges compris. Sans les pièges : 30 minutes.

## Prérequis vérifiés

Sur le VPS, vérifier Docker et la RAM disponible :

```bash
docker --version && free -h
```

Ici : Docker 29.2.1, 6,6 Go disponibles sur 8 (un n8n tournait déjà à côté, il n'a jamais été dérangé).

## Étape 1 : l'assistant de configuration

Hermes fournit un assistant interactif qui écrit toute la configuration dans `~/.hermes` (volume unique = tout l'état de l'agent : config, clés, mémoire, sessions, logs).

```bash
mkdir -p ~/.hermes
docker run -it --rm -v ~/.hermes:/opt/data nousresearch/hermes-agent:v2026.5.29.2 setup
```

Choix faits dans l'assistant :

| Question | Réponse | Pourquoi |
|---|---|---|
| Quick ou Full setup | **Quick** | provider + modèle + messagerie, le reste se règle plus tard |
| Provider | **OpenRouter** | 100+ modèles avec une seule clé, comparaisons de coût possibles |
| Modèle par défaut | **anthropic/claude-sonnet-4.6** | fiabilité maximale en tool calling pour la phase de validation. On compare les modèles moins chers APRÈS que tout marche, sinon impossible de savoir si un bug vient de l'agent ou du cerveau |
| Terminal backend | **local** | Hermes tourne déjà dans un container : ses commandes sont isolées par le déploiement lui-même. « Docker » ici = Docker dans Docker, inutile |
| Messagerie | **Skip** | viendra au doc 03 avec `hermes setup gateway` |

## Étape 2 : lancer le service permanent

```bash
docker run -d --name hermes \
  --restart unless-stopped \
  -p 127.0.0.1:8642:8642 \
  -p 127.0.0.1:9119:9119 \
  -v ~/.hermes:/opt/data \
  --memory 2g --cpus 1.5 \
  nousresearch/hermes-agent:v2026.5.29.2 \
  gateway run
```

Note : la première version de ce guide activait `-e HERMES_DASHBOARD=1`. Retiré depuis : le dashboard non authentifié polluait les logs en boucle, voir le bonus du [doc 03](03-passerelle-telegram.md).

Les points qui comptent :

- **`v2026.5.29.2` pinnée** : jamais `latest` sur un service en continu. Le projet sort plusieurs releases par semaine.
- **`127.0.0.1:` devant les ports** : LA différence avec le template officiel. Sans ce préfixe, la gateway API et le dashboard sont accessibles depuis tout Internet si le pare-feu du VPS est vide. Avec, rien n'est exposé : les passerelles de messagerie fonctionnent quand même (connexions sortantes), et le dashboard reste accessible via un tunnel SSH.
- **`--restart unless-stopped`** : redémarrage automatique après reboot du VPS.
- **`--memory 2g --cpus 1.5`** : pour cohabiter poliment avec ce qui tourne déjà (ici n8n).

Vérifier :

```bash
docker ps
```

Attendu : une ligne `hermes ... Up ... 127.0.0.1:8642->8642/tcp, 127.0.0.1:9119->9119/tcp`.

## Étape 3 : le golden test (mémoire entre sessions)

Critère binaire : l'agent restitue une information donnée dans une session précédente, sans qu'on la lui redonne.

```bash
docker exec -it hermes hermes        # session 1
```

Dans le chat : `Bonjour. Je suis Bastien. Ma couleur fétiche est le cyan #38D3D6`

Observation intéressante : la ligne `memory +user: "Name: Bastien. Preferred language: French. Favorite color: cyan #38D3D6."` apparaît immédiatement. L'agent écrit sa mémoire **au fil de l'eau**, pas à la fermeture : une coupure brutale ne perd rien.

```
/exit
```

```bash
docker exec -it hermes hermes        # session 2, neuve (le numéro de session change)
```

Dans le chat : `Quel est mon code couleur fétiche ?`

**Résultat constaté : il répond cyan #38D3D6.** Golden test validé. Cerise involontaire : la connexion 5G a sauté entre les deux sessions (coupure SSH brutale, non simulée), la mémoire a survécu quand même.

## Les pièges rencontrés (du temps perdu pour vous en faire gagner)

1. **Le terminal web de l'hébergeur casse les collages multi-lignes.** Le terminal navigateur Hostinger injecte des caractères parasites (`^[[200~`, bracketed paste) et décale l'indentation : les heredocs (`cat > fichier <<'EOF'`) ne se terminent jamais. Symptôme : le prompt reste bloqué sur `>`. Solution : `Ctrl+C` et passer par un vrai client SSH (PowerShell, Windows Terminal, etc.).
2. **Les longues commandes copiées depuis un chat se font couper.** Une commande d'une seule ligne très longue, copiée depuis une conversation (Claude, ChatGPT, Slack…), peut embarquer des retours à la ligne d'affichage qui deviennent de vrais retours à la ligne au collage. Symptôme : `docker: 'docker run' requires at least 1 argument` puis `--option: command not found`. Solution : exiger des commandes multi-lignes courtes avec continuation `\`.
3. **Mise à jour système en attente** : si le VPS affiche `*** System restart required ***`, prévoir le reboot après l'installation (`--restart unless-stopped` relancera tout proprement).

## Coûts constatés (premiers chiffres)

- Modèle : Claude Sonnet 4.6 via OpenRouter (3 $/M tokens en entrée, 15 $/M en sortie)
- Premiers échanges + écriture mémoire : quelques centimes
- Garde-fou : limite de dépense fixée sur la clé côté OpenRouter
- Relevé complet sur une semaine d'usage : à venir au doc 05
