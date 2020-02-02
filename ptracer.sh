#!/usr/bin/env bash
#
#
#
# AUTOR: Bruno Chaves
# Versão: 1.0
# Ultima modificação: 2020-01-11
#
#--------------------------------------------------#
# Expansão de variáveis.
# http://shellscriptx.blogspot.com/2016/12/utilizando-expansao-de-variaveis.html
#

clear

esp='-------------------------------'



# Mensagens coloridas
function _c()
{
	[ -z $2 ] && { echo -e "\033[1;$1m" ; return 0; }
	echo -e "\033[$2;$1m"
}

#--------------------------------------------------#

function _msg()
{
	echo -e "-> $@"
}

#--------------------------------------------------#

# root.
[[ $(id -u) == '0' ]] || {
	_msg "$(_c 31)Você não é [root] saindo... $(_c)"
	exit 1
}

# Verificar se o kernel e Linux.
[[ $(uname -s) == 'Linux' ]] || {
	_msg "$(_c 31)Sistema não é 'Linux', saindo... $(_c)"
	exit 1
}

# Verificar se os sistema e 'base' Debian.
[[ ! -f '/etc/debian_version' ]] && {
	_msg "$(_c 31)Seu sistema não é baseado em Debian. $(_c)"
	exit 1
}

#--------------------------------------------------#
# Sistema debian/ubuntu/linuxmint.
#--------------------------------------------------#
nome_sistema=$(grep '^ID=' /etc/os-release | sed 's/.*=//g')

	#--------------------------------------------------#
	# Codinome.
	#--------------------------------------------------#
	case "$nome_sistema" in
		debian) codinome_sistema=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's/.*=//g');; # buster
		ubuntu) codinome_sistema=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's/.*=//g');; # bionic
		linuxmint) codinome_sistema=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's/.*=//g');; # tessa/tina/...
		*) _msg "$(_c 31)Seu sistema não é suportado. $(_c)"; exit 1;;
	esac

	#--------------------------------------------------#
	# Versão
	#--------------------------------------------------#
	case "$nome_sistema" in
		debian) versao_sistema=$(grep -m 1 '^VERSION_ID=' /etc/os-release | sed 's/.*=//g;s/\"//g');;
		ubuntu) versao_sistema=$(grep -m 1 '^VERSION_ID=' /etc/os-release | sed 's/.*=//g;s/\"//g');;
		linuxmint) versao_sistema=$(grep -m 1 '^VERSION_ID=' /etc/os-release | sed 's/.*=//g;s/\"//g');;
		*) _msg "$(_c 31)Seu sistema não é suportado. $(_c)"; exit 1;;
	esac

if [[ "$nome_sistema" == 'debian' ]] && [[ "$versao_sistema" == '10' ]]; then # debian 10 buster
	_msg "$(_c 32 2)$nome_sistema $versao_sistema $codinome_sistema $(_c)"

elif [[ "$nome_sistema" == 'ubuntu' ]] && [[ "$versao_sistema" == '18.04' ]]; then # ubuntu 18.04 bionic
	_msg "$(_c 32 2)$nome_sistema $versao_sistema $codinome_sistema $(_c)"

elif [[ "$nome_sistema" == 'linuxmint' ]] && [[ "${versao_sistema::2}" == '19' ]]; then # dois primeiros = 19.
	_msg "$(_c 32 2)$nome_sistema $versao_sistema $codinome_sistema $(_c)"

else
	_msg "$(_c 31)Seu sistema não é suportado. $(_c)"; exit 1 # Não suportado, sair.

fi


#--------------------------------------------------#
# Arrays
#--------------------------------------------------#

array_cli=(
'curl'
'zenity'
'gdebi'
'aptitude'
)

array_pt_utils=(
'multiarch-support' 
'qtmultimedia5-dev' 
'libqt5script5' 
'libqt5scripttools5'
)

#--------------------------------------------------#
# Instalar utilitários de linha de comando.
#--------------------------------------------------#
function _install_utils()
{
	echo "$esp"
	_msg "Instalando: $@"
	echo "$esp"

	if apt install -y "$@"; then
		_msg "OK"; return 0
	else
		_msg "$(_c 31)FALHA: $@ $(_c)"; return 1
	fi
}

#--------------------------------------------------#
# Checar utilitários de linha de comando.
#--------------------------------------------------#
function _cli()
{
	while [[ $1 ]]; do
		if [[ -x $(which "$1" 2> /dev/null) ]]; then
			_msg "OK ... $1"
		else
			_msg "$(_c 31)FALHA ... $1 $(_c)"
			return 1; break
		fi
		shift
	done
}

#--------------------------------------------------#

if ! _cli "${array_cli[@]}"; then
	apt update
	_install_utils "${array_cli[@]}" || exit 1
fi

#--------------------------------------------------#
# Diretórios de trabalho.
#--------------------------------------------------#
dir_root=$(dirname $(readlink -f "$0"))  # Path do programa no disco.
dir_local=$(pwd)                         # Local onde o terminal está aberto.
dir_temp="/tmp/Space_Packettracer_$USER"
dir_downloads='/tmp/Space_Packettracer_Downloads'

mkdir -p "$dir_temp" "$dir_downloads"

#--------------------------------------------------#
# Pacotes .deb que pode ser instalados ou não, será
# virificado a necessidade de instalar ou não estes
# pacotes.
#--------------------------------------------------#
# URLs
ftp_us="http://ftp.us.debian.org/debian/pool/main"
security="http://security.debian.org/debian-security"

url_libpng12_debian8_amd64="${ftp_us}/libp/libpng/libpng12-0_1.2.50-2+deb8u3_amd64.deb"
url_libssl1_debian8_amd64="$security/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u12_amd64.deb"

# Arquivos
arq_libpng12_deb8_amd64="$dir_downloads"/libpng12-0_deb8_amd64.deb
arq_libssl1_deb8_amd64="$dir_downloads"/libssl1.0_deb8_amd64.deb

# Hash
hash_libssl1_deb8_amd64='c91f6f016d0b02392cbd2ca4b04ff7404fbe54a7f4ca514dc1c499e3f5da23a2'
hash_libpng12_deb8_amd64='fa86f58f9595392dc078abe3b446327089c47b5ed8632c19128a156a1ea68b96'

#--------------------------------------------------#

[[ ! -w "$dir_local" ]] && {
	_msg "$(_c 31)Você não tem permissão de escrita (w) em: $dir_local"
	exit 1
}

#--------------------------------------------------#
# Verificar hash sha256sum dos arquivos.
#--------------------------------------------------#

function _checksum()
{
# $1 = arquivo 
# $2 = soma do servidor
path_arq="$1"
sum="$2"

	# Gerar has do arquivo em disco local.
	_msg "Gerando hash do arquivo local: [$path_arq]"
	local_sum=$(sha256sum "$path_arq" | awk '{print $1}')

	# Comparar hash do arquivo local com a hash do servidor.
	_msg "Comparando valores..."
	_msg "[$sum] ... Hash do servidor"
	_msg "[$local_sum] ... Hash no disco"

	if [[ "$sum" == "$local_sum" ]]; then
		_msg "$(_c 32 1)[OK] $(_c)"
		return 0
	else
		_msg "$(_c 31)[FALHA] $(_c)"
		return 1
	fi
}

#==========================================================#
#================= Descompressão dos arquivos =============#
#==========================================================#

function _unpack()
{
# $1 = arquivo a descomprimir.

	local path_arq="$1"

	# Detectar a extensão do arquivo.
	if [[ "${path_arq: -6}" == 'tar.gz' ]]; then # tar.gz - 6 ultimos caracteres.
		type_arq='tar.gz'

	elif [[ "${path_arq: -7}" == 'tar.bz2' ]]; then # tar.bz2
		type_arq='tar.bz2'

	elif [[ "${path_arq: -6}" == 'tar.xz' ]]; then # tar.xz
		type_arq='tar.xz'

	else
		echo "$(_c 31)Arquivo não suportado: [$path_arq] $(_c)"
		return 1

	fi

	# Limpar o destino antes da descompressão.
	cd "$dir_temp" && rm -rf * 2> /dev/null  

		_msg "Descompactando: [$path_arq]"
		_msg "Destino: [$dir_temp]"

	# Descomprimir.
	case "$type_arq" in
		'tar.gz') tar -zxvf "$path_arq" -C "$dir_temp" 1> /dev/null;;
		'tar.bz2') tar -jxvf "$path_arq" -C "$dir_temp" 1> /dev/null;;
		'tar.xz') tar -Jxf "$path_arq" -C "$dir_temp" 1> /dev/null;;
		*) return 1;;
	esac

	return "$?"
}

#--------------------------------------------------#
# Instalação de cisco packettracer.
#--------------------------------------------------#

function _zenity()
{
	case "$1" in
	--question) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--info) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--error) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--file-selection) zenity "$1" --title="$2" --file-filter="$3" --file-filter="$4";;
	--list) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5" --column "$6" $7;; 
	esac
}

function _install_packettracer()
{

	if [[ -x $(command -v packettracer) ]] && [[ -x '/opt/pt/bin/PacketTracer7' ]]; then
		_msg "$(_c 33)C$(_c)isco Packettracer já instalado."
		return 0
	fi

	instalar_agora=$(_zenity "--list" "Instalar Cisco Packettracer" "Selecione" "650" "250" "Instalação" "Instalar Sair")

	if [[ "${instalar_agora,,}" != 'instalar' ]]; then 
		_msg "$(_c 31)Saindo$(_c)"
		_msg "Cisco Packettracer não foi instalado."
		return 1
	fi

	_msg 'Iniciando instalação...'

while true; do

	arq_instalacao=$(_zenity "--file-selection" "Selecionar arquivo" "*.tar.gz" "*.run")
	nome_arq=$(basename "$arq_instalacao")

	[[ ! -f "$arq_instalacao" ]] && { return 1; break; }

	# Arquivo termina com .tar.gz ou .run ?
	if [[ "${arq_instalacao: -7}" == '.tar.gz' ]] || [[ "${arq_instalacao: -4}" == '.run' ]]; then
		prosseguir=$(_zenity "--list" "Usar este arquivo ?" "Continuar" "650" "250" "$nome_arq" "Sim Não")
	else
		_msg "$(_c 31)Arquivo inválido: [$arq_instalacao]"
		return 1
	fi

	# Descompactar e instalar.
	[[ "${prosseguir,,}" == 'sim' ]] || {
		_msg "$(_c 31)Abotando instalação. $(_c)"
		return 1; break
	}

	_msg "$(_c 32 1)Instalando: [$arq_instalacao] $(_c)"

	if [[ "${arq_instalacao: -7}" == '.tar.gz' ]]; then
				
		# Descomprimir.
		_unpack "$arq_instalacao" || {
			_msg "$(_c 31)FALHA na descompressão de: [$arq_instalacao] $(_c)"
			return 1; break
		}
		
		chmod +x "$dir_temp"/install
		sed -i 's|^more .*||g' "$dir_temp"/install

		cd "$dir_temp" && ./install
		return "$?"; break

	elif [[ "${arq_instalacao: -4}" == '.run' ]]; then

		chmod +x "$arq_instalacao"
		"$arq_instalacao"
		return "$?"; break
	fi

done
}

#--------------------------------------------------#
# Download dos arquivos usando a ferramenta curl.
#--------------------------------------------------#
function _Curl()
{
# $1 = url de download
# $2 = nome do arquivo

	_msg "Baixando url: [$1]"
	_msg "Destino: [$2]"
	
	if curl -SL "$1" -o "$2"; then
		return 0
	else
		return 1
	fi
}

#--------------------------------------------------#
# Função para configurar libpng12.
#--------------------------------------------------#

function _config_libpng()
{

	# Suporte a 32 bits disponível ?.
	_msg "$(_c 32 2)Verificando suporte a (arch32) $(_c)"
	[[ $(dpkg --print-foreign-architectures | grep i386) == "i386" ]] || {
		dpkg --add-architecture i386
		apt update
	}

	[[ ! -f "$arq_libpng12_deb8_amd64" ]] && {
		_Curl "$url_libpng12_debian8_amd64" "$arq_libpng12_deb8_amd64" || return 1
	}

	# hash sha256sum.
	if ! _checksum "$arq_libpng12_deb8_amd64" "$hash_libpng12_deb8_amd64"; then
		_msg "Removendo: $arq_libpng12_deb8_amd64"
		rm "$arq_libpng12_deb8_amd64"; return 1
	fi

	# Verificar se packettracer foi instalado neste diretório '/opt/pt/bin/'.
	if [[ ! -d "/opt/pt/bin/" ]]; then
		_msg "$(_c 31 2)Instale Cisco packettracer em ... /opt/pt/bin/ $(_c)"
		_msg "Em seguida execute este programa novamente."
		return 1
	fi

	# Usar dpkg para extrair o arquivo e obter 'libpng12.so.0.50.0'.
	cd "$dir_temp" && rm -rf * 2> /dev/null
	dpkg-deb -x "$arq_libpng12_deb8_amd64" "$dir_temp"
	cp -vu "$dir_temp"/lib/x86_64-linux-gnu/libpng12.so.0.50.0 '/opt/pt/bin/libpng12.so.0.50.0'
	ln -sf /opt/pt/bin/libpng12.so.0.50.0 '/opt/pt/bin/libpng12.so.0'  
	cd "$dir_temp" && rm -rf * 2> /dev/null
}

#--------------------------------------------------#
# Função para instalar dependências em debian buster.
#--------------------------------------------------#

function _install_libs_buster()
{
	_install_utils "${array_pt_utils[@]}" || return 1

	# libssl1.0
	[[ ! -f "$arq_libssl1_deb8_amd64" ]] && {
		_Curl "$url_libssl1_debian8_amd64" "$arq_libssl1_deb8_amd64" || return 1
	}

	# hash sha256sum.
	if ! _checksum "$arq_libssl1_deb8_amd64" "$hash_libssl1_deb8_amd64"; then
		rm "$arq_libssl1_deb8_amd64"; return 1
	fi

		_msg "Instalando: $arq_libssl1_deb8_amd64"
		gdebi-gtk "$arq_libssl1_deb8_amd64"
		_config_libpng || return 1
}

#--------------------------------------------------#
# Função para instalar dependências em ubuntu bionic.
#--------------------------------------------------#

function _install_libs_bionic()
{
	_install_utils "${array_pt_utils[@]}" || return 1
	apt install -y libssl1.0.0 || return 1
	_config_libpng || return 1
}

#--------------------------------------------------#
# Corrigir arquivos em /opt/pt
#--------------------------------------------------#

function _corrigir_arquivos()
{

 # /opt/pt/tpl.linguist
[[ -f '/opt/pt/tpl.linguist' ]] && { sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.linguist; }

# /opt/pt/tpl.packettracer
[[ -f '/opt/pt/tpl.packettracer' ]] && { sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.packettracer; }

# Arquivo pt7.desktop
[[ -f '/opt/pt/bin/Cisco-PacketTracer.desktop' ]] && {
	sudo cp -u '/opt/pt/bin/Cisco-PacketTracer.desktop' '/usr/share/applications/' 
	}
 
[[ -f '/usr/share/applications/pt7.desktop' ]] && sudo rm '/usr/share/applications/pt7.desktop'

} 

#--------------------------------------------------#
_msg "Arquivos baixados serão salvos aqui ... $dir_downloads"
_msg "Arquivos temporarios serão salvos aqui ... $dir_temp"

#--------------------------------------------------#
# Run 
#--------------------------------------------------#

if _install_packettracer; then
	_msg "Cisco Packettracer instalado com sucesso."
else
	_msg "Falha na instalação de Cisco Packettracer."
	exit 1
fi

if [[ "$nome_sistema" == 'debian' ]]; then   

	_install_libs_buster || {
		_msg "Função $(_c 31)_install_libs_buster $(_c)retornou erro."
		exit 1
	}

elif [[ "$nome_sistema" == 'ubuntu' ]] || [[ "$nome_sistema" == 'linuxmint' ]]; then

	_install_libs_bionic || {
		_msg "Função $(_c 31)_install_libs_bionic $(_c)retornou erro."
		exit 1
	}

fi

_corrigir_arquivos || exit 1
exit "$?"
