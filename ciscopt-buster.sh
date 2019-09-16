#!/usr/bin/env bash
#
# tar xvzf PacketTracer7.2.1forLinux64bit.tar.gz -C PacketTracer/
#
# Versão: 1.8
# Ultima modificação: 2019-09-16 
#
# tar xvzf Cisco-PT-711-x64.tar
#
# Você precisa adicionar a arquitetura i386, tornando o sistema multiarch
# sudo dpkg --add-architecture i386; sudo apt-get update
# 
# sudo apt install qtmultimedia5-dev libqt5script5 libqt5scripttools5

clear

#----------------------[ Variaveis ]----------------------------------#

amarelo="\e[1;33m"
Amarelo="\e[1;33;5m"
vermelho="\e[1;31m"
Vermelho="\e[1;31;5m"
verde="\e[1;32m"
Verde="\e[1;32;5m"
fecha="\e[m"

esp="------------------------------------------"

# Detectar sistema.
codinome_sistema=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's|.*=||g')
nome_sistema=$(grep '^ID=' /etc/os-release | sed 's|.*=||g')

[[ $codinome_sistema == buster ]] || { echo -e "${vermelho}Seu sistema não e Debian buster $fecha"; exit 1; }

if [[ $USER == root ]] || [[ $UID == 0 ]]; then 
	echo -e "${vermelho}Usuário não pode ser o [root] $fecha"
	exit 1
fi


# Links
ftp_us="http://ftp.us.debian.org/debian/pool/main"
security="http://security.debian.org/debian-security"

link_libpng12_deb8_amd64="${ftp_us}/libp/libpng/libpng12-0_1.2.50-2+deb8u3_amd64.deb"
link_libpng12_deb8_i386="${ftp_us}/libp/libpng/libpng12-0_1.2.50-2+deb8u3_i386.deb"
link_libssl1_deb8_amd64="${security}/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u11_amd64.deb"
link_libssl1_deb8_i386="${security}/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u11_i386.deb"

hash_ciscopkt72="fa334416ec1868a4ce2a487fec5e45d1e330fbb61d6961f33cb2a18ecabae7db"

# export local_trab=$(dirname $0) 
export readonly local_trab=$(dirname $(readlink -f "$0")) # Path do programa no sistema.

# Diretórios
DIR_APPS_LINUX="${HOME}"/"${codinome_sistema}"
DIR_INTERNET="${DIR_APPS_LINUX}/Internet"
dir_tmp_pt="${DIR_INTERNET}/cisco-pt72-amd64"
dir_libs="${HOME}/.local/tmp/libs"

arq_libssl1_deb8_amd64="${DIR_INTERNET}"/libssl1.0_deb8_amd64.deb
arq_libssl1_deb8_i386="${DIR_INTERNET}"/libssl1.0_deb8_i386.deb
arq_libpng12_deb8_amd64="${DIR_INTERNET}"/libpng12-0_deb8_amd64.deb

mkdir -p "$DIR_APPS_LINUX" "$DIR_INTERNET" "$dir_tmp_pt" "$dir_libs"

[[ ! -w "$local_trab" ]] && {
	echo -e "Você não tem permissão de escrita em: $local_trab"
	exit
}

# Zenity
[[ -x $(which zenity) ]] || {
	echo 'Nescessário instalar zenity'
	sudo apt install zenity -y
	[[ $? == 0 ]] || { echo 'Falha: zenity'; exit 1; }
}

# Gdebi
[[ -x $(which gdebi) ]] || { 
	echo echo 'Nescessário instalar Gdebi'
	sudo apt install --yes gdebi
	[[ $? == 0 ]] || { echo 'Falha: gdebi'; exit 1; }
}

# Wget
[[ -x $(which wget) ]] || {
	echo 'Nescessário instalar wget'
	sudo apt install -y wget
	[[ $? == 0 ]] || { echo 'Falha: wget'; exit 1; }
}


#-------------------------[ Função para exibir mensagens com zenity ]----------#
function msgs_zenity()
{

# (Sim Não) --question --title="Abrir" --text="Abrir ePSxe agora ?" 
#
# (Senha) --password --title="[sudo: $USER]"
#
# (Arquivo) --file-selection --title="Selecione o arquivo .bin" --file-filter="*.bin" 
#
#(Erro) --error --title="Falha na autênticação" --text="Senha incorrenta"
#
# (Lista) --list --text "Selecione uma configuração" --radiolist --column "Marcar" --column "Configurar" FALSE Bios TRUE Sair
#
# (Info) --info --title="Reiniciar" --text="Reinicie seu computador para aplicar alterações"
#
# Resolução [--width="550" height="200", --width="300" height="150" ]

case "$1" in
--question) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
--info) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
--error) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
--file-selection) zenity "$1" --title="$2" --file-filter="$3" --file-filter="$4";;
--list) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5" --column "$6" $7;; 
esac

}

function _sis_admin()
{
	
# Autênticação [sudo].
while true; do
	clear
	sudo -K
	senha=$(zenity --password --title="[sudo: $USER]")
	echo $senha | sudo -S ls / 1> /dev/null 2>&1 # Verificar se a senha foi validada.
	
	[[ $? == 0 ]] || { msgs_zenity "--error" "Falha" "Senha incorrenta" "310" "200"; continue; }
	break 
done
}

#---------------------------[ Instalar cisco pt ]-----------#
function _inst_ciscopkt() 
{

clear
echo 'Iniciando instalação...'

arq_instalacao=$(msgs_zenity "--file-selection" "Selecionar arquivo" "*.tar.gz" "*.tar.gz")

nome_arq=$(echo $arq_instalacao | sed 's|.*/||g')

prosseguir=$(msgs_zenity "--list" "Usar este arquivo ?" "Continuar" "650" "250" "$nome_arq" "Sim Não")
	
	# Descompactar e instalar packettracer.
	if [[ "$prosseguir" == "Sim" ]]; then
	
	# Soma sha256sum.
	if [[ $(sha256sum "$arq_instalacao" | cut -d ' ' -f 1) != "$hash_ciscopkt72" ]]; then
	msgs_zenity "--error" "Arquivo inválido" "Erro: Selecione cisco packettracer versão 7.2 x64" "450" "100"
	fi
	
	[[ -d "$dir_tmp_pt" ]] && sudo rm -rf "$dir_tmp_pt"
	mkdir -p "$dir_tmp_pt"
	tar xvzf "$arq_instalacao" -C "$dir_tmp_pt"
	chmod +x "$dir_tmp_pt/install"
	cd "$dir_tmp_pt/" && ./install
	fi	
}

#---------------------[ Função para instalar libs debian buster ]----------#
function _inst_libs_buster() {
		
	# libssl1.0.0 deb8 amd64
	[[ $(aptitude show libssl1.0.0 | grep '^Estado' | cut -d ' ' -f 2) == 'instalado' ]] || {
		echo 'Instalando libssl1.0.0 amd64'
		wget "$link_libssl1_deb8_amd64" -O "$arq_libssl1_deb8_amd64"
		sudo gdebi-gtk "$arq_libssl1_deb8_amd64"
	}	
		
	# libpng12 deb8 amd64
	[[ -f '/opt/pt/bin/libpng12.so.0.50.0' ]] || {
		echo 'Configurando libpng12'
		wget "$link_libpng12_deb8_amd64" -O "$arq_libpng12_deb8_amd64"
		sudo rm -rf "$dir_libs"/* 1> /dev/null 2>&1
		sudo dpkg-deb -x "$arq_libpng12_deb8_amd64" "$dir_libs"
		sudo cp -vu "${dir_libs}"/lib/x86_64-linux-gnu/libpng12.so.0.50.0 /opt/pt/bin/libpng12.so.0.50.0
		sudo ln -sf /opt/pt/bin/libpng12.so.0.50.0 /opt/pt/bin/libpng12.so.0 
	}
		
}


#---------------------[ Função para instalar libs em ubuntu bionic ]----------#
function _inst_libs_bionic()
{

	wget "$link_libpng12_deb8_amd64" -O "$arq_libpng12_deb8_amd64"
	sudo apt install libssl1.0.0 -y
	
	sudo rm -rf "$dir_libs"/* 1> /dev/null 2>&1
	sudo dpkg-deb -x "$arq_libpng12_deb8_amd64" "$dir_libs"
	sudo cp -vu "${dir_libs}"/lib/x86_64-linux-gnu/libpng12.so.0.50.0 /opt/pt/bin/libpng12.so.0.50.0
	sudo ln -sf /opt/pt/bin/libpng12.so.0.50.0 /opt/pt/bin/libpng12.so.0  
}



#--------------------[ Função para corrigir arquivos ]----------------#
function _corrigir_arquivos()
{

sudo sh -c 'sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.linguist' # /opt/pt/tpl.linguist

sudo sh -c 'sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.packettracer' # /opt/pt/tpl.packettracer

[[ -f /usr/share/applications/pt7.desktop ]] && sudo rm /usr/share/applications/pt7.desktop # Arquivo .desktop
sudo cp -u /opt/pt/bin/Cisco-PacketTracer.desktop /usr/share/applications/ 

} # Fim de corrigir arquivos


# Executar a função de instalação se packettracer não estiver nas condições abaixo.
if [[ ! -x $(which packettracer) ]] || [[ ! -x /opt/pt/bin/PacketTracer7 ]]; then

# Executar a função (msgs_zenity) para mostrar a mensagem abaixo.
instalar_agora=$(msgs_zenity "--list" "Instalar" "Selecione" "650" "250" "Instalação" "Instalar Sair")

	if [[ "$instalar_agora" == "Instalar" ]]; then
		(_inst_ciscopkt) && (_corrigir_arquivos) # Debian/Ubuntu.
	else
		exit 0
	fi

fi

# Checar se local de instalação é '/opt/pt/bin'
[[ -x /opt/pt/bin/PacketTracer7 ]] || { echo 'Cisco-PacketTracer não instalado em: [/opt/pt] saindo...'; exit 1; }

# Instalar dependências via repositório.
clear

# Autênticação [sudo].
(_sis_admin)

# Suporte a 32 bits disponível ?.
[[ $(dpkg --print-foreign-architectures | grep i386) == "i386" ]] || { sudo dpkg --add-architecture i386; }
sudo apt update
sudo apt install --yes gdebi aptitude multiarch-support qtmultimedia5-dev libqt5script5 libqt5scripttools5

	case "$codinome_sistema" in
	buster) (_inst_libs_buster);; # Debian.
	bionic) (_inst_libs_bionic);; # Ubuntu.
	esac

msgs_zenity "--info" "Reiniciar" "Reinicie seu computador para aplicar alterações" "550" "150"

[[ -d "$dir_tmp_pt" ]] && sudo rm -rf "$dir_tmp_pt"

sudo -K
