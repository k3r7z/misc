#! /bin/bash -x

readonly HEIGHT=15
readonly WIDTH=125
readonly BACKTITLE="Instalación y configuración de Linux"
readonly SCAN_DIR=/home/usuario/scan
readonly SHARE_DIR=/home/usuario/compartida
readonly DNS='10.1.4.111,10.1.4.112'
readonly PROXY_PORT="3128"
readonly ADMIN_PROXY="10.7.6.6"
readonly SCAI_PROXY="10.10.254.218"
readonly NETWORK_NAME="red"
readonly ADMIN_NETWORK_NAME="admin"
readonly PACKAGES=(
    "x11vnc" # programa para control remoto de entornos linux
    "libreoffice" # suite de herramientas
    "ssh" # protocolo para control remoto de terminales
    "unrar" #para rars
    "unzip" # para zips
    "vlc" # reproductor de audio y videos
    "thunderbird" # correo
    "thunderbird-locale-es" # en castellano
    "myspell-es" # correcion en castellano para libreoffice
    "ubuntu-restricted-extras" # algunas utilidades para ubuntu
    "firefox-locale-es" # traducción de firefox
    "ntp" # Protocolo para la sincronizacion del reloj
    "hplip"
    "hplip-gui" # drivers para impresoras HP
    "vim" # editor de texto
    "neovim" # fork de vim mejorado
    "gimp" # editor de imagenes
    "inkscape" # editor de imagenes vectorial
    "neovim" # el mejor editor
    "wine" # interfaz para windows
    "ocsinventory-agent" # programa para gestión de inventario
    "cifs-utils" # utilidades para el protocolo cifs
    "net-tools" # utilidades de red
    "ethtool" # utilidad para controlar los drivers de red y hardware
    "putty" # cliente de terminal ssh/telnet integrada
    "ubuntu-mate-desktop" # entorno mate
)
declare admin_name="administrador"
declare user="usuario"
declare passwd="usuario"
declare admin_ip
declare user_ip


function print_message(){
  whiptail --title "$1" --backtitle "$BACKTITLE" --msgbox "$2" "$HEIGHT" "$WIDTH"
}


function user_exists(){ 
  local exists
  exists=$(grep "$1" /etc/passwd)
  if [[ -z $exists ]]
  then
    false
  else 
    true
  fi
}


function create_shortcuts(){
  local user_desktop
  if [[ -d "/home/$user/Desktop" ]]
  then
    user_desktop="/home/$user/Desktop"
  else
    user_desktop="/home/$user/Escritorio"
  fi

  sudo cp /usr/share/applications/{atril,vlc,thunderbird,gimp,chrome}.desktop "$user_desktop"
  sudo cp /usr/share/applications/libreoffice-{calc,draw,impress,math,writer}.desktop "$user_desktop"
  sudo chown "$user" "$user_desktop/*.desktop"
  sudo chmod +x "$user_desktop/*.desktop"
}


function print_checklist(){
  print_message "Antes de instalar" """Antes de iniciar con la instalación/configuración:
  - Asignar/reservar una ip en el repo, si la pc aún no la tiene.
  - Conectar la pc a la red de la provincia (no adsl)
  - Asegurate de que la ip para el 6 no esté activa en otra máquina."""
}


function create_user(){
  local title="Creación del usuario"

  while true
  do
    user=$(
      whiptail \
        --title "$title" \
        --backtitle "$BACKTITLE" \
        --inputbox "Ingresar usuario" "$HEIGHT" "$WIDTH" \
        3>&1 1>&2 2>&3)

    passwd=$(whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --inputbox "Ingresar contraseña" "$HEIGHT" "$WIDTH" \
      3>&1 1>&2 2>&3)

    if user_exists "$user"
    then
      print_message "$title" "El usuario ya existe"
      break
    fi

    if whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --yesno "Usuario: $user\nContraseña: $passwd\n\nConfirmar?" \
      "$HEIGHT" "$WIDTH"
    then
      if ! sudo useradd -m "$user"
      then
        print_message "$title" "Ocurrió un error al crear el usuario"
        break
      fi

      if ! echo "$user:$passwd" | sudo chpasswd
      then
        print_message "$title" "Ocurrió un error al intentar setear la contraseña del usuario"
        break
      fi
        print_message "$title" "El usuario fue creado con éxito"
      break
    fi
  done
}


function network_exists(){
	if [[ -f "/etc/NetworkManager/system-connections/${1}.nmconnection" ]]
	then
    true
  else
    false
	fi
}


function reset_fds(){
  exec 0</dev/tty
  exec 1>/dev/tty
  exec 2>/dev/tty
}


function set_proxy(){
	gsettings set org.gnome.system.proxy mode manual
	gsettings set org.gnome.system.proxy.http port "$PROXY_PORT"
	gsettings set org.gnome.system.proxy.https port "$PROXY_PORT"
	gsettings set org.gnome.system.proxy.ftp port "$PROXY_PORT"
	gsettings set org.gnome.system.proxy.http host "$1"
	gsettings set org.gnome.system.proxy.https host "$1"
	gsettings set org.gnome.system.proxy.ftp host "$1"
}


function set_network_up(){
  nmcli connection up "$1"
}


function install_chrome(){
  local title="Instalación de Google Chrome"
  wget -O chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
  sudo dpkg -i chrome.deb
  rm chrome.deb

  if command -v google-chrome 1>/dev/null
  then
    true
  else
    false
  fi
}


function install_anydesk(){
  local title="Instalación de AnyDesk"
  local version="6.4.0-1_amd64"
  reset_fds

  wget https://download.anydesk.com/linux/anydesk_"$version".deb -O anydesk.deb --show-progress

  if ! sudo dpkg -i anydesk.deb
  then
    sudo apt-get --fix-broken install
    sudo dpkg -i anydesk.deb
  fi

  if [[ -e "anydesk.deb" ]]
  then
    rm anydesk.deb
  fi

  if command -v anydesk 1>/dev/null
  then
    true
  else
    false
  fi
}


function check_connectivity(){
  if [[ $(nmcli networking connectivity check) == "full" ]]
  then
    true
  else
    false
  fi
}


function set_admin_network_up(){
  set_proxy "$ADMIN_PROXY"
  set_network_up "$ADMIN_NETWORK_NAME"
}

function set_user_network_up(){
  set_proxy "$SCAI_PROXY"
  set_network_up "$NETWORK_NAME"
  sudo cp ~/.config/dconf/user /home/"$user"/.config/dconf/user
}


function configure_network() {
  local title="Configurar red"
  print_message "$title" "Si la máquina no tiene ninguna IP asignada, ir al repo a reservar una ahora."
  while true
  do
    network=$(whiptail \
      --title "$title" \
      --radiolist "Seleccionar la red a donde va a estar la pc" "$HEIGHT" "$WIDTH" 6 \
      "1" "Ministerio - 10.7.6.0/23" OFF \
      "2" "Secretaría de Ciencia y Tecnología / Secretaría de Transporte: 10.8.50.0/23" OFF \
      "3" "Secretaría de Turismo - 10.10.14.0/24" OFF \
      "4" "Terminal de Santa Fe - 10.7.48.0/24" OFF \
      "5" "Enerfe Puerto Santa Fe - 10.10.20.0/24" OFF \
      "6" "Aeropuerto de Sauce Viejo - 10.8.44.0/24" OFF \
      2>&1 > /dev/tty
    )
declare gateway;
    declare network_mask;
    case "$network" in
      1) 
        network="Ministerio"
        gateway="10.7.6.200"
        network_mask="23";;
      2)
        network="Sec. de Ciencia y Tecnología / Sec. de Transporte"
        gateway="10.8.50.200"
        network_mask="23";;
      3)
        network="Secretaría de Turismo"
        gateway="10.10.14.200"
        network_mask="24";;
      4)
        network="Terminal de Santa Fe"
        gateway="10.7.48.200"
        network_mask="24";;
      5)
        network="Enerfe Puerto de Santa Fe"
        gateway="10.10.20.200"
        network_mask="24";;
      6)
        network="Aeropuerto de Sauce Viejo"
        gateway="10.8.44.200"
        network_mask="24";;
    esac

    admin_ip=$(
      whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --inputbox "Ingresar una IP que tenga acceso al $ADMIN_PROXY para instalar los paquetes" "$HEIGHT" "$WIDTH" \
      3>&2 2>&1 1>&3
    )

    user_ip=$(
      whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --inputbox "Ingresar la IP final del usuario" "$HEIGHT" "$WIDTH" \
      3>&2 2>&1 1>&3
    )

    device=$(
      whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --inputbox "Ingresar el dispositivo de red\n$(nmcli device | grep ethernet)" "$HEIGHT" "$WIDTH" \
      3>&2 2>&1 1>&3
    )

    if whiptail \
      --title "$title" \
      --backtitle "$BACKTITLE" \
      --yesno """
          Red: $network
          Gateway: $gateway
          Mascara de subred: $network_mask
          IP del $ADMIN_PROXY: $admin_ip
          IP final del usuario: $user_ip
          Disposito: $device
          Confirmar?""" "$HEIGHT" "$WIDTH"
        then
      break
    fi
  done

	echo "Acquire::http::proxy \"http://$ADMIN_PROXY:$PROXY_PORT\";
Acquire::https::proxy \"http://$ADMIN_PROXY:$PROXY_PORT\";
Acquire::ftp::proxy \"http://$ADMIN_PROXY:$PROXY_PORT\";" | sudo tee /etc/apt/apt.conf > /dev/null

	if network_exists $ADMIN_NETWORK_NAME
	then
		nmcli connection delete "$ADMIN_NETWORK_NAME"
	fi
	nmcli connection add type ethernet ifname "$device" con-name "$ADMIN_NETWORK_NAME" ip4 "$admin_ip/$network_mask" gw4 "$gateway" ipv4.dns "$DNS"
  nmcli connection modify "$ADMIN_NETWORK_NAME" connection.permissions user:"$admin_name"

	if network_exists $NETWORK_NAME
	then
		nmcli connection delete "$NETWORK_NAME"
	fi
	nmcli connection add type ethernet ifname "$device" con-name "$NETWORK_NAME" ip4 "$user_ip/$network_mask" gw4 "$gateway" ipv4.dns "$DNS"
}


function configure_samba(){
	if [[ ! -d $SCAN_DIR ]]
	then
		sudo mkdir $SCAN_DIR
		sudo chown usuario:usuario $SCAN_DIR
		sudo chmod 777 $SCAN_DIR
		echo "[scan]
		path = $SCAN_DIR
		public = yes
		writable = yes
		browseable = yes
		read only = no
		force directory mode = 0777
		force create mode = 0777" | sudo tee -a /etc/samba/smb.conf > /dev/null
	fi

	if [[ ! -d $SHARE_DIR ]]
	then
		sudo mkdir $SHARE_DIR
		sudo chown usuario:usuario $SHARE_DIR
		sudo chmod 777 $SHARE_DIR
		echo "[compartida]
		path = $SHARE_DIR
		public = yes
		writable = yes
		browseable = yes
		read only = no
		force directory mode = 0777
		force create mode = 0777" | sudo tee -a /etc/samba/smb.conf > /dev/null
	fi

	sudo systemctl reload-or-restart smbd
}


function configure_vnc(){
  echo "[Unit]
Description=x11vnc service
After=display-manager.service network.target syslog.target
[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -forever -display :0 -auth guess -passwd 3e2w1q
ExecStop=/usr/bin/killall x11vnc
Restart=on-failure
[Install]
WantedBy=multi-user.target " | sudo tee /etc/systemd/system/x11vnc.service > /dev/null
	sudo systemctl enable --now x11vnc
}


function configure_cups(){
  sudo systemctl enable cups
  sudo systemctl start cups
  sudo systemctl enable cups-browsed
  sudo systemctl start cups-browsed
}

function configure_services(){
  configure_cups
  configure_vnc
  configure_samba
}


function install_packages(){
  local title="Instalación de paquetes"

  if ! network_exists "$ADMIN_NETWORK_NAME"
  then
    print_message "$title" "Error: Ocurrió un problema al intentar actualizar el repositorio"
    exit 1
  fi

  set_admin_network_up
  reset_fds

	if ! sudo apt update
  then
    print_message "$title" "Error: Ocurrió un problema al intentar actualizar el repositorio"
    exit 1
  fi

  uninstalled_packages=()
  for package in "${PACKAGES[@]}"
  do
    sudo apt-get install -y "$package"
    output=$?
    echo "Codigo de salida: $output"
    if [[ "$output" != 0 ]]
    then
      uninstalled_packages+=("$package")
    fi
  done

  if ! install_chrome
  then
    uninstalled_packages+=("google-chrome")
  fi

  if ! install_anydesk
  then
    uninstalled_packages+=("anydesk")
  fi
	
  if [[ ${#uninstalled_packages[@]} -gt 1 ]]
  then
    print_message "$title" "Los siguientes paquetes no pudieron ser instalados: ${uninstalled_packages[*]}"
  fi

  create_shortcuts
  configure_services
  set_user_network_up
}


function finish_installation(){
  local title="Finalizar instalación"
  set_user_network_up

  if whiptail \
    --title "$title" \
    --backtitle "$BACKTITLE" \
    --yesno "Es necesario reiniciar el sistema para terminar la instalación.\nFinalizar y reiniciar?" "$HEIGHT" "$WIDTH"
  then
    sudo systemctl reboot
  fi
}


function install_optionals_packages(){
  local title="Instalar/actualizar paquetes opcionales"
  local size=$(( ${#options[@]} / 2))

  choice=$(whiptail --clear \
    --backtitle "$BACKTITLE" \
    --title "$title" \
    --checklist "$MENU" \
    "$HEIGHT" "$WIDTH" 2 \
    1 "Google chrome" OFF \
    2 "AnyDesk" OFF \
    3>&1 1>&2 2>&3)

  for option in $choice
  do
    case $option in
      "\"1\"")
        install_chrome;;
      "\"2\"")
        install_anydesk;;
    esac
  done
}


function sequential_mode(){
  configure_network
  install_packages
  create_user
  finish_installation
}


function main_menu(){
  local title="Instalador/configurador"
  local options=(\
    1 "Configurar red"
    2 "Instalar paquetes"
    3 "Crear usuario"
    4 "Terminar instalacion/configuración"
    5 "Salir"
  )
  local size=$(( ${#options[@]} / 2))

  while true;
  do
    CHOICE=$(whiptail --clear \
      --backtitle "$BACKTITLE" \
      --title "$title" \
      --menu "$MENU" \
      "$HEIGHT" "$WIDTH" $size \
      "${options[@]}" \
      2>&1 > /dev/tty)

    case "$CHOICE" in
      1) configure_network;;
      2) install_packages;;
      3) create_user;;
      4) finish_installation;;
      *) exit 0;;
    esac
  done
}


print_checklist

if [[ $# -eq 0 ]]
then
  sequential_mode
else
  while [[ $# -gt 0 ]]
  do
    case $1 in
      "-m" | "--menu")
        main_menu;;
    esac
  done
fi
