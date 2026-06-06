# Hermes Agent sur VPS, relié à une maison sans IP publique

Guide terrain pour déployer [Hermes Agent](https://github.com/NousResearch/hermes-agent) (Nous Research) sur un VPS, puis le relier à un Home Assistant situé derrière une connexion **sans IP publique** (5G, Starlink, fibre CGNAT).

Tout ce qui est documenté ici a été réellement exécuté, dans l'ordre, avec les erreurs rencontrées et leurs solutions. Pas de tutoriel théorique.

## Le contexte

- Hermes tourne sur un VPS (ici Hostinger KVM 2, Ubuntu 24.04, Docker), à côté d'un n8n déjà en production
- La maison est 100% autonome en énergie, connectée en 5G : pas d'IP publique, aucune connexion entrante possible
- Objectif final : un agent joignable 24/7 par Telegram, qui pilote la domotique Home Assistant de la maison à travers ce mur réseau

## Avancement

| Étape | Statut | Doc |
|---|---|---|
| Déploiement Hermes sur VPS (Docker, version pinnée) | ✅ fait | [docs/01-deploiement-vps.md](docs/01-deploiement-vps.md) |
| Golden test mémoire (info restituée dans une session neuve) | ✅ validé | [docs/01-deploiement-vps.md](docs/01-deploiement-vps.md) |
| Accès SSH par clé + raccourci bureau | ✅ fait | [docs/02-acces-ssh-raccourci.md](docs/02-acces-ssh-raccourci.md) |
| Passerelle Telegram (bot + allowlist + golden test cross-canal) | ✅ fait | [docs/03-passerelle-telegram.md](docs/03-passerelle-telegram.md) |
| Tunnel VPS ↔ Home Assistant à travers le CGNAT | 🔜 | docs/04 à venir |
| Pilotage domotique + relevé des coûts API | 🔜 | docs/05 à venir |

## Les choix de configuration (et pourquoi)

1. **Version pinnée, jamais `latest`** : le projet sort plusieurs releases par semaine. Un tag flottant sur un service qui tourne en continu, c'est la roulette russe à chaque redémarrage.
2. **Ports liés à `127.0.0.1`** : le template officiel expose la gateway (8642) et le dashboard (9119) sur l'IP publique du VPS. Si votre pare-feu est vide, tout Internet y a accès. Liés à localhost, rien n'est exposé, et les passerelles type Telegram fonctionnent quand même (connexions sortantes).
3. **OpenRouter comme provider** : une seule clé, 100+ modèles. Permet de comparer qualité et coût (Claude Sonnet vs Haiku vs DeepSeek vs modèles gratuits) sur le même agent, sans rien réinstaller. Indispensable en perspective de déploiements chez des clients qui ne veulent pas être enfermés chez un fournisseur.

## Prérequis

- Un VPS Linux avec Docker (1 Go de RAM libre suffit pour commencer, 2 Go confortable)
- Une clé API LLM (OpenRouter, Anthropic, OpenAI… au choix)
- Un vrai client SSH (pas le terminal web de votre hébergeur, voir les pièges dans le doc 01)

## Auteur

Bastien Le Bret · [VizualMapp](https://vizualmapp.fr) · informaticien et vidéaste mapping.
Guide produit en marge du workshop « Hermès : déployer son propre agent autonome à mémoire » du Labo IA (juin 2026).

## Licence

MIT : faites-en ce que vous voulez, une citation fait toujours plaisir.
