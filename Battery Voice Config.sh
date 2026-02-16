#!/bin/bash

#---------------------------------#
#    Battery Voice Configurator   #
#            By Jason             #
#---------------------------------#

# --- Droit root ---
if [ "$(id -u)" -ne 0 ]; then exec sudo -- "$0" "$@"; fi

# --- Variables ---
CURR_TTY="/dev/tty1"
SCRIPT_NAME=$(basename "$0")
BACKTITLE="Battery Voice Configurator - By Jason"

TARGET_SPEAK="/usr/local/bin/speak_bat_life.sh"
PY_FILES=(
    "/usr/local/bin/batt_life_warning.py"
    "/usr/local/bin/batt_life_warning.py.red"
    "/usr/local/bin/batt_life_warning.py.green"
)

# --- Sauvegarde ---
safe_initial_backup() {
    mount -o remount,rw / 2>/dev/null
    if [ -f "$TARGET_SPEAK" ] && [ ! -f "$TARGET_SPEAK.bak" ]; then
        cp "$TARGET_SPEAK" "$TARGET_SPEAK.bak"
    fi
    for f in "${PY_FILES[@]}"; do
        if [ -f "$f" ] && [ ! -f "$f.bak" ]; then
            cp "$f" "$f.bak"
        fi
    done
}

# --- Valeurs réelles du système ---
load_live_values() {
    if [ -f "$TARGET_SPEAK" ]; then
        # Messages sauvegardés
        SEL_MSG_WARN=$(grep "SAVED_MSG_WARN=" "$TARGET_SPEAK" | cut -d'"' -f2)
        SEL_MSG_CRIT=$(grep "SAVED_MSG_CRIT=" "$TARGET_SPEAK" | cut -d'"' -f2)

        if [ -z "$SEL_MSG_WARN" ]; then
            SEL_MSG_WARN=$(grep "SAVED_MSG=" "$TARGET_SPEAK" | cut -d'"' -f2)
            [ -z "$SEL_MSG_WARN" ] && SEL_MSG_WARN="Warning your battery is low"
        fi
        [ -z "$SEL_MSG_CRIT" ] && SEL_MSG_CRIT="Critical battery level! Please charge now"

        # Vitesse prononciation
        local raw_s=$(grep "SAVED_SPEED=" "$TARGET_SPEAK" | cut -d'"' -f2)
        SEL_SPEED="${raw_s:-130}"

        # Préférence de la voix
        local raw_v=$(grep "SAVED_VOICE=" "$TARGET_SPEAK" | cut -d'"' -f2)
        if [[ "$raw_v" == *"+"* ]]; then
            SEL_VOICE=$(echo "$raw_v" | cut -d'+' -f1)
            SEL_GENDER="+"$(echo "$raw_v" | cut -d'+' -f2)
        else
            SEL_VOICE="${raw_v:-en}"; SEL_GENDER="+m3"
        fi
    else
        SEL_MSG_WARN="Warning your battery is low"
        SEL_MSG_CRIT="Critical battery level! Please charge now"
        SEL_SPEED="130"
        SEL_VOICE="en"; SEL_GENDER="+m3"
    fi

    # Seuil d'alerte batterie
    SEL_WARN=""
    SEL_CRIT=""
    for f in "${PY_FILES[@]}"; do
        if [ -f "$f" ]; then
            SEL_WARN=$(grep -oP 'elif.*?<=\s*\K[0-9]+' "$f" | head -1)
            SEL_CRIT=$(grep -oP 'if.*?<=\s*\K[0-9]+' "$f" | head -1)
            [ -n "$SEL_WARN" ] && break
        fi
    done
    SEL_WARN=${SEL_WARN:-20}; SEL_CRIT=${SEL_CRIT:-10}
}

# --- Réglage des pourcentages ---
set_thresholds() {
    local tmp_warn=$(dialog --colors --backtitle "$BACKTITLE" --title "Thresholds" --menu "\nSelect Warning Battery %:" 15 40 12 $(for i in $(seq 0 2 30); do echo "$i $i%"; done) --output-fd 1 2>"$CURR_TTY")
    if [ -n "$tmp_warn" ]; then
        SEL_WARN="$tmp_warn"
        local tmp_crit=$(dialog --colors --backtitle "$BACKTITLE" --title "Thresholds" --menu "\nSelect Critical Battery % :" 15 40 12 $(for i in $(seq 0 2 30); do echo "$i $i%"; done) --output-fd 1 2>"$CURR_TTY")
        [ -n "$tmp_crit" ] && SEL_CRIT="$tmp_crit"
    fi
}

# --- Choix de l'accent ---
set_language() {
    local tmp_lang=$(dialog --colors --backtitle "$BACKTITLE" --title "Language Selection" --menu "\nSelect Voice Accent:" 18 40 10 \
    "fr" "French" "en" "British" "en-us" "American" "pl" "Polish" \
    "ru" "Russian" "es" "Spanish" "de" "German" \
    "it" "Italian" --output-fd 1 2>"$CURR_TTY")
    [ -n "$tmp_lang" ] && SEL_VOICE="$tmp_lang"
}

# --- Choix voix Homme/Femme ---
set_gender() {
    local gen=$(dialog --colors --backtitle "$BACKTITLE" --title "Gender" --menu "\nSelect Voice Gender:" 10 40 2 "F" "Female" "M" "Male" --output-fd 1 2>"$CURR_TTY")
    if [ "$gen" == "F" ]; then 
        SEL_GENDER="+f2"
    elif [ "$gen" == "M" ]; then 
        SEL_GENDER="+m3"
    fi
}

# --- Choix vitesse prononciation ---
set_speed() {
    local tmp_speed=$(dialog --colors --backtitle "$BACKTITLE" --title "Voice Speed" --menu "\nSelect Tempo:" 15 40 6 "80" "Very Slow" "100" "Slow" "120" "Normal Slow" "135" "Default" "160" "Fast" "180" "Very Fast" --output-fd 1 2>"$CURR_TTY")
    [ -n "$tmp_speed" ] && SEL_SPEED="$tmp_speed"
}

# --- Message personnalisé batterie faible ---
set_message_warn() {
    pkill -9 -f gptokeyb || true
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    clear > "$CURR_TTY"
    local tmp_msg=$(osk "Warning Message" "$SEL_MSG_WARN")
    setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz 2>/dev/null
    clear > "$CURR_TTY"
    /opt/inttools/gptokeyb -1 "$SCRIPT_NAME" -c "/opt/inttools/keys.gptk" >/dev/null 2>&1 &
    [ -n "$tmp_msg" ] && SEL_MSG_WARN="$tmp_msg"
}

# --- Message personnalisé batterie critique  ---
set_message_crit() {
    pkill -9 -f gptokeyb || true
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    clear > "$CURR_TTY"
    local tmp_msg=$(osk "Critical Message" "$SEL_MSG_CRIT")
    setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz 2>/dev/null
    clear > "$CURR_TTY"
    /opt/inttools/gptokeyb -1 "$SCRIPT_NAME" -c "/opt/inttools/keys.gptk" >/dev/null 2>&1 &
    [ -n "$tmp_msg" ] && SEL_MSG_CRIT="$tmp_msg"
}

# --- Test voix ---
preview_voice() {
    runuser -u ark -- espeak-ng -v "${SEL_VOICE}${SEL_GENDER}" -s "$SEL_SPEED" "Message warning is"
    runuser -u ark -- espeak-ng -v "${SEL_VOICE}${SEL_GENDER}" -s "$SEL_SPEED" "$SEL_MSG_WARN" 
    sleep 1 
    runuser -u ark -- espeak-ng -v "${SEL_VOICE}${SEL_GENDER}" -s "$SEL_SPEED" "Message critical is"
    runuser -u ark -- espeak-ng -v "${SEL_VOICE}${SEL_GENDER}" -s "$SEL_SPEED" "$SEL_MSG_CRIT"
}

# --- Application des modifs ---
apply_all() {
    mount -o remount,rw / 2>/dev/null
    
    # Génération du script vocal
    cat <<EOF > "$TARGET_SPEAK"
#!/bin/bash
# SAVED_MSG_WARN="${SEL_MSG_WARN}"
# SAVED_MSG_CRIT="${SEL_MSG_CRIT}"
# SAVED_SPEED="${SEL_SPEED}"
# SAVED_VOICE="${SEL_VOICE}${SEL_GENDER}"

TYPE=\$1
LOCK_FILE="/tmp/batt_\${TYPE}_spoken"
if [ -f "\$LOCK_FILE" ]; then exit 0; fi

case "\$TYPE" in
    "critical") MSG="${SEL_MSG_CRIT}" ;;
    *)          MSG="${SEL_MSG_WARN}" ;;
esac

export XDG_RUNTIME_DIR="/run/user/1000"

if runuser -u ark -- bash -c "espeak-ng -v ${SEL_VOICE}${SEL_GENDER} -s ${SEL_SPEED} \"\$MSG\" --stdout | aplay -D default" > /dev/null 2>&1; then
    touch "\$LOCK_FILE"
fi
EOF
    chmod +x "$TARGET_SPEAK"

    # Génération du script Python
    for py_file in "${PY_FILES[@]}"; do
        if [ -f "$py_file" ]; then
            chattr -i "$py_file" 2>/dev/null
            cat <<EOF > "$py_file"
#!/usr/bin/env python3
import os
import time

batt_life = "/sys/class/power_supply/battery/capacity"
pwr_led = "/sys/class/gpio/gpio77/value"

def set_led(state):
    try:
        with open(pwr_led, "w") as f:
            f.write(str(state))
    except:
        pass

def reset_audio_locks():
    for lock in ["/tmp/batt_warning_spoken", "/tmp/batt_critical_spoken"]:
        if os.path.exists(lock):
            try:
                os.remove(lock)
            except:
                pass

while True:
    try:
        with open(batt_life, "r") as f:
            capacity = int(f.read().strip())
        if capacity <= $SEL_CRIT:
            set_led(1)
            os.system("/usr/local/bin/speak_bat_life.sh critical")
            time.sleep(1)
            set_led(0)
            time.sleep(1)
        elif capacity <= $SEL_WARN:
            set_led(1)
            os.system("/usr/local/bin/speak_bat_life.sh warning")
            time.sleep(20)
        else:
            set_led(0)
            reset_audio_locks()
            time.sleep(60)
    except Exception:
        time.sleep(10)
EOF
            chmod +x "$py_file"
        fi
    done
    
    sync
    systemctl restart batt_led 2>/dev/null
    dialog --title "Success" --msgbox "\nAll Settings and Messages saved!" 7 40 2>"$CURR_TTY"
}

# --- Restauration du backup ---
restore_backup() {
    mount -o remount,rw / 2>/dev/null
    if [ -f "$TARGET_SPEAK.bak" ]; then
        cp -f "$TARGET_SPEAK.bak" "$TARGET_SPEAK"
        for py in "${PY_FILES[@]}"; do 
            [ -f "$py.bak" ] && cp -f "$py.bak" "$py"
        done
        systemctl restart batt_led 2>/dev/null
        load_live_values
    
        dialog --backtitle "$BACKTITLE" --title "Backup Success" --infobox "\nOriginal files restored." 5 45 2>"$CURR_TTY"
    sleep 2
    apply_all
    else
       dialog --backtitle "$BACKTITLE" --title "Error" --msgbox "No backup found." 7 25 2>"$CURR_TTY"
    fi
}

# --- Menu Principal ---
MainMenu() {
    while true; do
        [[ "$SEL_GENDER" == "+f2" ]] && G="Female" || G="Male"

        INFO_TEXT="\Z4[ BATTERY STATUS ]\Zn                   \Z4[ VOICE STATUS ]\Zn\n"
        INFO_TEXT="$INFO_TEXT Warning: \Z3$SEL_WARN%\Zn                        Language: \Z5$SEL_VOICE\Zn\n"
        INFO_TEXT="$INFO_TEXT Critical: \Z1$SEL_CRIT%\Zn                        Gender:   \Z5$G\Zn\n"
        INFO_TEXT="$INFO_TEXT                                     Speed:    \Z5$SEL_SPEED\Zn\n"
        INFO_TEXT="$INFO_TEXT W. Msg: $SEL_MSG_WARN\n"
        INFO_TEXT="$INFO_TEXT C. Msg: $SEL_MSG_CRIT"

        CHOICE=$(dialog --colors --backtitle "$BACKTITLE" --title "Main Menu" --cancel-label "Quit" \
            --menu "$INFO_TEXT" 22 65 10 \
            1 "Configure Thresholds (%)" \
            2 "Configure Voice Language" \
            3 "Configure Voice Gender" \
            4 "Configure Voice Speed" \
            5 "Edit Warning Message" \
            6 "Edit Critical Message" \
            7 "Preview Voice" \
            8 "Save & Apply to System" \
            9 "Restore Initial Backup" --output-fd 1 2>"$CURR_TTY")
        
        [ $? -ne 0 ] && ExitMenu

        case $CHOICE in
            1) set_thresholds ;;
            2) set_language ;;
            3) set_gender ;;
            4) set_speed ;;
            5) set_message_warn ;;
            6) set_message_crit ;;
            7) preview_voice ;;
            8) apply_all ;;
            9) restore_backup ;;
        esac
    done
}

# --- Fonction sortie ---
ExitMenu() {
    printf "\033c" > "$CURR_TTY"; printf "\e[?25h" > "$CURR_TTY"
    pkill -f "gptokeyb -1 $SCRIPT_NAME" || true; exit 0
}

# --- Initialisation ---
printf "\033c" > "$CURR_TTY"
export TERM=linux; export XDG_RUNTIME_DIR="/run/user/$(id -u)"
sudo setfont /usr/share/consolefonts/Lat7-Terminus16.psf.gz 2>/dev/null

pkill -9 -f gptokeyb || true
if command -v /opt/inttools/gptokeyb &> /dev/null; then
    [[ -e /dev/uinput ]] && chmod 666 /dev/uinput 2>/dev/null || true
    export SDL_GAMECONTROLLERCONFIG_FILE="/opt/inttools/gamecontrollerdb.txt"
    /opt/inttools/gptokeyb -1 "$SCRIPT_NAME" -c "/opt/inttools/keys.gptk" >/dev/null 2>&1 &
fi

trap ExitMenu EXIT SIGINT SIGTERM

safe_initial_backup
load_live_values
MainMenu