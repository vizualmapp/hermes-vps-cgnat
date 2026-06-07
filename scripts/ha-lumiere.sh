#!/bin/sh
# ha-lumiere.sh v2 — pilotage des 2 ampoules TV (RGB) via Home Assistant
# SEUL canal autorise entre l'agent et la maison (garde-fou structurel).
# USAGE : ha-lumiere.sh <on|off|toggle|status> <droit|gauche|deux>
#         ha-lumiere.sh couleur <droit|gauche|deux> <couleur_anglais>
# DEPENDANCES : curl · /opt/data/.env (HA_URL + HA_TOKEN, jeton utilisateur HA non-admin)
# Adapter les entity_id a votre installation.

ENV_FILE=/opt/data/.env
HA_URL=$(grep '^HA_URL=' "$ENV_FILE" | cut -d= -f2)
HA_TOKEN=$(grep '^HA_TOKEN=' "$ENV_FILE" | cut -d= -f2)

ACTION=$1
CIBLE=$2
COULEUR=$3

case "$CIBLE" in
  droit)  ENTITES="light.ampoule_tv_droit" ;;
  gauche) ENTITES="light.ampoule_tv_gauche" ;;
  deux)   ENTITES="light.ampoule_tv_droit light.ampoule_tv_gauche" ;;
  *) echo "Cible refusee. Autorisees : droit | gauche | deux"; exit 1 ;;
esac

case "$ACTION" in
  on)     SERVICE="turn_on";  DATA_EXTRA="" ;;
  off)    SERVICE="turn_off"; DATA_EXTRA="" ;;
  toggle) SERVICE="toggle";   DATA_EXTRA="" ;;
  status) SERVICE="" ;;
  couleur)
    case "$COULEUR" in
      *[!a-z]*|"") echo "Couleur refusee. Un seul mot en anglais minuscule (red, blue, green, white, purple, orange, yellow, pink, cyan...)"; exit 1 ;;
    esac
    SERVICE="turn_on"
    DATA_EXTRA=",\"color_name\":\"$COULEUR\"" ;;
  *) echo "Action refusee. Autorisees : on | off | toggle | status | couleur"; exit 1 ;;
esac

for E in $ENTITES; do
  if [ "$ACTION" = "status" ]; then
    ETAT=$(curl -s -H "Authorization: Bearer $HA_TOKEN" \
      "$HA_URL/api/states/$E" | grep -o '"state":"[^"]*"')
    echo "$E : $ETAT"
  else
    curl -s -X POST \
      -H "Authorization: Bearer $HA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"entity_id\":\"$E\"$DATA_EXTRA}" \
      "$HA_URL/api/services/light/$SERVICE" > /dev/null
    echo "$E : $ACTION $COULEUR envoye"
  fi
done
