# 02 · Accès sans mot de passe + raccourci bureau « bouton magique »

Objectif : double-clic sur le bureau → on parle à Hermes. Zéro mot de passe, zéro commande à retenir. Durée : 5 minutes. Environnement décrit : poste Windows (PowerShell), VPS Ubuntu.

## Étape 1 : générer une paire de clés SSH (sur le poste local)

```powershell
ssh-keygen -t ed25519
```

Entrée aux trois questions (emplacement par défaut, pas de phrase de passe : compromis assumé pour un raccourci un-clic ; la clé privée ne quitte jamais le poste).

Résultat dans `C:\Users\<vous>\.ssh\` :
- `id_ed25519` : clé **privée**. Ne se copie nulle part, jamais.
- `id_ed25519.pub` : clé **publique**. C'est elle qu'on distribue.

## Étape 2 : déposer la clé publique sur le VPS

Windows n'a pas `ssh-copy-id`, l'équivalent PowerShell :

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@IP_DU_VPS "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

Dernière saisie du mot de passe root. La clé publique rejoint la liste des accès autorisés du serveur.

## Étape 3 : vérifier

```powershell
ssh root@IP_DU_VPS
```

Connexion directe sans mot de passe = gagné. (Et l'authentification par clé est plus robuste qu'un mot de passe : rien à intercepter, rien à bruteforcer.)

## Étape 4 : le raccourci bureau

Clic droit sur le Bureau → Nouveau → Raccourci → cible :

```
powershell -NoExit -Command "ssh -t root@IP_DU_VPS 'docker exec -it hermes hermes'"
```

Le `-t` force l'allocation d'un terminal interactif à travers SSH (sans lui, l'interface de chat ne s'affiche pas correctement).

Double-clic → le chat Hermes s'ouvre. Pour quitter : `/exit` (ou fermer la fenêtre : l'agent continue de tourner sur le VPS, sa mémoire est déjà écrite : voir doc 01, le golden test le prouve).

## Note pour la suite

Ce raccourci est l'accès « administrateur ». L'accès du quotidien arrive au doc 03 : la passerelle Telegram, qui met l'agent dans la poche, sans PC.
