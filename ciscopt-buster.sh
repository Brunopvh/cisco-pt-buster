#!/usr/bin/env bash
#
# AUTOR: Bruno Chaves
# Versão: 2.2
# Ultima modificação: 2019-09-17 
# 
# Repositório:
# https://github.com/Brunopvh/cisco-pt-buster
# https://github.com/Brunopvh/cisco-pt-buster.git
# 
# Execução:
#
# wget https://raw.githubusercontent.com/Brunopvh/cisco-pt-buster/master/ciscopt-buster.sh -O - ciscopt-buster.sh 
# 
# 
# 

clear

# Cores
amarelo="\e[1;33m"
Amarelo="\e[1;33;5m"
vermelho="\e[1;31m"
Vermelho="\e[1;31;5m"
verde="\e[1;32m"
Verde="\e[1;32;5m"
fecha="\e[m"

esp="------------------------------------------"

#----------------------[ DETECTAR SISTEMA E CODNOME ]----------------------#
export codinome_sistema=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's|.*=||g')
export nome_sistema=$(grep '^ID=' /etc/os-release | sed 's|.*=||g')

if [[ "$codinome_sistema" != "buster" ]] && [[ "$codinome_sistema" != "bionic" ]]; then

	# Se for linuxmint tina, tratar como ubuntu bionic.
    if [[ $nome_sistema == 'linuxmint' ]] && [[ $codinome_sistema == 'tina' ]]; then
        export nome_sistema="ubuntu"
        export codinome_sistema="bionic"

    else

	    printf "${vermelho}Este programa e incompativel com seu sistema ${fecha}\n"
	    exit 1
    fi
fi

#------------------ Detectar se usuário e root ---------#
if [[ $USER == root ]] || [[ $UID == 0 ]]; then 
	echo -e "${vermelho}Usuário não pode ser o [root] $fecha"
	exit 1
fi


# Diretórios
DIR_APPS_LINUX="${HOME}"/"${codinome_sistema}"
dir_packettracer_tmp="$DIR_APPS_LINUX"/tmp
dir_libs="$DIR_APPS_LINUX"/lib-png

# Links
ftp_us="http://ftp.us.debian.org/debian/pool/main"
security="http://security.debian.org/debian-security"

link_libpng12_deb8_amd64="${ftp_us}/libp/libpng/libpng12-0_1.2.50-2+deb8u3_amd64.deb"
link_libssl1_deb8_amd64="${security}/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u11_amd64.deb"

arq_libssl1_deb8_amd64="${DIR_APPS_LINUX}"/libssl1.0_deb8_amd64.deb
arq_libpng12_deb8_amd64="${DIR_APPS_LINUX}"/libpng12-0_deb8_amd64.deb

mkdir -p "$DIR_APPS_LINUX" "$dir_packettracer_tmp" "$dir_libs"

# export local_trab=$(dirname $0) 
export readonly local_trab=$(dirname $(readlink -f "$0")) # Path do programa no sistema.

[[ ! -w "$local_trab" ]] && {
	echo -e "Você não tem permissão de escrita em: $local_trab"
	exit
}


#------------ Função para exibir mensagens ---------------#
function msgs() {
	echo -e "$1" "$2 ${fecha}"
}


# Função para verificar ou instalar os programas necessários.
function _apps_exist() 
{
	# $1 = programa a verificar ou instalar.
	local msg="Necessário instalar : "
	local msg_falha="Falha ao tentar instalar : "
	
	[[ -x $(which $1) ]] || { 
		echo -e "${amarelo}$msg $1 ${fecha}"
		sudo apt install -y $1
			[[ $? == 0 ]] || { echo -e "${vermelho}$msg_falha $1 ${fecha}"; exit 1; } 
	}
}

_apps_exist 'zenity' # Zenity

_apps_exist 'gdebi' # Gdebi

_apps_exist 'wget' # Wget

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

#-------------------[ Instalar cisco packettracer pacote .run/.tar.gz ]-----------#
function _inst_ciscopkt() 
{

echo 'Iniciando instalação...'

while true; do

	arq_instalacao=$(msgs_zenity "--file-selection" "Selecionar arquivo" "*.tar.gz" "*.run")
	nome_arq=$(echo $arq_instalacao | sed 's|.*/||g')

	[[ -z "$arq_instalacao" ]] && exit 1

	# Arquivo termina com .tar.gz ou .run ?
	[[ $(echo "$arq_instalacao" | egrep "(.tar.gz$|.run$)") ]] || { msgs "$vermelho" "Arquivo inválido"; exit 1; }

	prosseguir=$(msgs_zenity "--list" "Usar este arquivo ?" "Continuar" "650" "250" "$nome_arq" "Sim Não")
	
	# Descompactar e instalar.
	if [[ "$prosseguir" == "Sim" ]] && [[ $(echo "$nome_arq" | egrep ".tar.gz$" ) ]]; then
		echo -e "Instalando: $arq_instalacao"		

		# Limpar o diretório onde o arquivo será extraido.
		sudo rm -rf "${dir_packettracer_tmp}"/* 1> /dev/null 2>&1 

		echo "Descompactando"
		[[ $(tar xvzf "$arq_instalacao" -C "$dir_packettracer_tmp") ]] || { 
			msgs "$vermelho" "Falha ao tentar descompactar" ; exit 1; 
		}

		chmod +x "$dir_packettracer_tmp"/install
		sed -i 's|^more .*||g' "$dir_packettracer_tmp"/install

		cd "$dir_packettracer_tmp" && ./install
		(_corrigir_arquivos)

		break

	elif [[ "$prosseguir" == "Sim" ]] && [[ $(echo "$nome_arq" | egrep ".run$" ) ]]; then

		echo 'Instalando .run'
		chmod +x "$arq_instalacao"
		"$arq_instalacao"
		(_corrigir_arquivos)

		break

	elif [[ "$prosseguir" == "Não" ]]; then
		echo 'Não...'
		exit 1
		break 

	else

		echo 'Repetindo...'
		continue
	fi

done
} # Fim _inst_ciscopkt

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

		sudo rm -rf "$dir_libs" 1> /dev/null 2>&1
 
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
	sudo rm -rf "$dir_libs" 1> /dev/null 2>&1

}



#--------------------[ Função para corrigir arquivos ]----------------#
function _corrigir_arquivos()
{

 # /opt/pt/tpl.linguist
[[ -f '/opt/pt/tpl.linguist' ]] && { sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.linguist; }

# /opt/pt/tpl.packettracer
[[ -f '/opt/pt/tpl.packettracer' ]] && { sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.packettracer; }

# Arquivo pt7.desktop
[[ -f '/opt/pt/bin/Cisco-PacketTracer.desktop' ]] && {
	sudo cp -u '/opt/pt/bin/Cisco-PacketTracer.desktop' '/usr/share/applications/' 
	[[ -f '/usr/share/applications/pt7.desktop' ]] && sudo rm '/usr/share/applications/pt7.desktop'
}
 
} # Fim de corrigir arquivos




#----------------------------- Execução --------------------#
function cisco_packettracer() 
{

# Instalar dependências antes de instalar o programa.
echo 'Instalando: gdebi aptitude multiarch-support qtmultimedia5-dev libqt5script5 libqt5scripttools5'
echo ' '

# Suporte a 32 bits disponível ?.
[[ $(dpkg --print-foreign-architectures | grep i386) == "i386" ]] || { sudo dpkg --add-architecture i386; }
sudo apt update
sudo apt install --yes gdebi aptitude multiarch-support qtmultimedia5-dev libqt5script5 libqt5scripttools5


# Executar a função de instalação se packettracer não estiver nas condições abaixo.
if [[ ! -x $(which packettracer) ]] || [[ ! -x /opt/pt/bin/PacketTracer7 ]]; then

	instalar_agora=$(msgs_zenity "--list" "Instalar Cisco Packettracer" "Selecione" "650" "250" "Instalação" "Instalar Sair")

	if [[ "$instalar_agora" == "Instalar" ]]; then
		(_inst_ciscopkt) # Debian/Ubuntu.
	else
		exit 0
	fi

fi


# Checar se local de instalação é '/opt/pt/bin'
[[ -x /opt/pt/bin/PacketTracer7 ]] || { echo 'Cisco-PacketTracer não instalado em: [/opt/pt] saindo...'; exit 1; }

(_corrigir_arquivos)

	case "$codinome_sistema" in
		buster) (_inst_libs_buster);; # Debian.
		bionic) (_inst_libs_bionic);; # Ubuntu.
	esac

msgs_zenity "--info" "Reiniciar" "Reinicie seu computador para aplicar alterações" "550" "150"

}

sudo -K #-------------------> Inicio
(cisco_packettracer) #------> Meio # Tudo e feito apartir desta função
sudo -K #-------------------> Fim

