#!/usr/bin/env bash
#
__version__='2020-07-04'
#
# AUTOR: Bruno Chaves
#
#
#--------------------------------------------------#
# Expansão de variáveis.
# http://shellscriptx.blogspot.com/2016/12/utilizando-expansao-de-variaveis.html
#

CRed="\e[0;31m"
CSRed='\e[1;31m'
CGreen="\e[0;32m"
CYellow="\e[0;33m"
CSYellow="\e[1;33m"
CReset="\e[m"

space_line='-----------------------------------------------'

_msg()
{
	printf "%s\n" "$space_line"
	echo -e " $@"
	printf "%s\n" "$space_line"
}

_yellow()
{
	echo -e "[${CYellow}+${CReset}] $@"
}

_red()
{
	echo -e "[${CRed}!${CReset}] $@"
}

_syellow()
{
	echo -e "${CSYellow}$@${CReset}"
}

_sred()
{
	echo -e "${CSRed}$@${CReset}"
}


_YESNO()
{
	# Será necessário indagar o usuário repetidas vezes durante a execução
	# do programa, em que a resposta deve ser do tipo SIM ou NÃO (s/n)
	# esta função é para automatizar esta indagação.
	#
	#   se teclar "s" -----------------> retornar 0  
	#   se teclar "n" ou nada ---------> retornar 1.
	#
	# $1 = Mensagem a ser exibida para o usuário reponder SIM ou NÃO (s/n).
	
	echo -ne "[>] $@ [${CYellow}s${CReset}/${CRed}n${CReset}]?: "
	read -t 15 -n 1 sn
	echo ' '

	if [[ "${sn,,}" == 's' ]]; then
		return 0
	else
		_red "Abortando"
		return 1
	fi
}

_space_text()
{
	# Use _space_text "text1" "text2"
	if [[ "${#@}" != '2' ]]; then
		_red "Falha: informe apenas 2 argumentos para serem exibidos como string"
		return 1
	fi

	local line='-'
	num="$((45-${#2}))"  
	
	for i in $(seq "$num"); do
		line="${line}-"
	done
	
	echo -e "$1 ${line} $2"
}

if [[ -z "$DISPLAY" ]]; then 
	_red 'Nescessário logar em sessão gráfica para prosseguir, saindo...'
	exit 1 
fi

# root.
if [[ $(id -u) == '0' ]]; then
	_red "NÃO execute com root..."
	exit 1
fi

# Verificar se os sistema e 'base' Debian.
if [[ ! -f '/etc/debian_version' ]]; then
	_red "Seu sistema não é baseado em Debian."
	exit 1
fi

# Nome do sistema debian/ubuntu/linuxmint.
os_id=$(grep '^ID=' /etc/os-release | sed 's/.*=//g')

case "$os_id" in
	debian) ;;
	ubuntu|linuxmint) ;;
	*) _red 'Seu sistema não é suportado por este programa.'; exit 1;;
esac

# Codinome
export os_codename=$(grep '^VERSION_CODENAME' /etc/os-release | sed 's|.*=||g') 
export os_version_id=$(grep 'VERSION_ID=' /etc/os-release | sed 's/.*=//g;s/"//g' | cut -c -2)

case "$os_version_id" in
	10|18|19) ;; # Debian 10/Ubuntu 18.04/LinuxMint/19.X
	*) _red 'Seu sistema não é suportado - suporte apenas para (Debian 10 | Ubuntu 18.04 | LinuxMint 19.X)'; exit 1;;
esac

# Arrays
systemRequeriments=(
	'wget'
	'zenity'
	'gdebi'
	'aptitude'
)

ciscoptRequerimentsDebian=(
	'multiarch-support' 
	'qtmultimedia5-dev' 
	'libqt5script5' 
	'libqt5scripttools5'
	'qtwebengine5-dev'
)

ciscoptRequerimentsUbuntu=(
	 libmng2 
	 libqt4-dbus 
	 libqt4-declarative 
	 libqt4-network 
	 libqt4-script 
	 libqt4-sql 
	 libqt4-xml 
	 libqt4-xmlpatterns 
	 libqtcore4 
	 libqtdbus4 
	 libqtgui4 
	 qdbus 
	 qt-at-spi 
	 qtchooser 
	 qtcore4-l10n
	)

usage()
{
cat << EOF
    Use:
       $(readlink -f "$0") --help|--install|--uninstall|--configure

EOF
}

is_executable()
{
	if [[ -x $(command -v "$1" 2> /dev/null) ]]; then
		return 0
	else
		return 1
	fi
}

# Instalar utilitários de linha de comando.
_install_sys_requeriments()
{
	for X in "${systemRequeriments[@]}"; do
		if is_executable "$X"; then
			_space_text "${CGreen}[+]${CReset}" "$X"
		else
			_space_text "${CRed}[!]${CReset}" "$X"
			_msg "Instalando: $X"
			sudo apt install -y "$X"
		fi
	done
}

# Diretórios de trabalho.
dir_root=$(dirname $(readlink -f "$0"))  # Path do programa no disco.
dir_local=$(pwd)                         # Local onde o terminal está aberto.
dir_temp="/tmp/Space_Packettracer_$USER"
dir_downloads='/tmp/Space_Packettracer_Downloads'
DirUnpack="$dir_temp/unpack"

mkdir -p "$dir_temp" "$dir_downloads" "$DirUnpack"

# Os pacotes .deb abaixo serão instalados no sistema caso necessário.
# URLs
URLlibpng12Debian8="http://ftp.us.debian.org/debian/pool/main/libp/libpng/libpng12-0_1.2.50-2+deb8u3_amd64.deb"
URLlibssl1Debian8="http://security.debian.org/debian-security/pool/updates/main/o/openssl/libssl1.0.0_1.0.1t-1+deb8u12_amd64.deb"

# Arquivos
FileLibpng12Deb8="$dir_downloads"/libpng12-0_deb8_amd64.deb
FileLibssl1Deb8="$dir_downloads"/libssl1.0_deb8_amd64.deb

# Hash
hashLibssl1Deb8='c91f6f016d0b02392cbd2ca4b04ff7404fbe54a7f4ca514dc1c499e3f5da23a2'
hashLibpng12Deb8='fa86f58f9595392dc078abe3b446327089c47b5ed8632c19128a156a1ea68b96'


__download__()
{
	# Baixar os arquivos com wget
	# $1 = URL
	# $1 = Arquivo
	local URL="$1"
	local FILE="$2"

	if [[ -f "$FILE" ]]; then
		_msg "Arquivo encontrado: $FILE"
		return 0
	fi

	_yellow "Baixando: $URL"
	printf "%s" "[>] Destino: $FILE "
	cd "$DIR_DOWNLOADS"
	wget -q "$URL" -O "$FILE"

	if [[ "$?" == '0' ]]; then
		_syellow "OK"
		return 0
	else
		_sred "(__download__) falha"
		return 1
	fi
}

__shasum__()
{
	# Esta função compara a hash de um arquivo local no disco com
	# uma hash informada no parametro "$2" (hash original). 
	#   Ou seja "$1" é o arquivo local e "$2" é uma hash
	# __shasum__ $file $sum

	if [[ ! -f "$1" ]]; then
		_red "(__shasum__) arquivo inválido: $1"
		return 1
	fi

	if [[ -z "$2" ]]; then
		_red "(__shasum__) use: __shasum__ <arquivo> <hash>"
		return 1
	fi

	_yellow "Gerando hash do arquivo: $1"
	local hash_file=$(sha256sum "$1" | cut -d ' ' -f 1)
	
	echo -ne "[>] Comparando valores "
	if [[ "$hash_file" == "$2" ]]; then
		echo -e "${CYellow}OK${CReset}"
		return 0
	else
		_sred 'FALHA'
		rm -rf "$1"
		_red "(__shasum__) o arquivo inseguro foi removido: $1"
		return 1
	fi
}

__rmdir__()
{
	# Função para remover diretórios e arquivos, inclusive os arquivos é diretórios
	# que o usuário não tem permissão de escrita, para isso será usado o "sudo".
	#
	# Use:
	#     __rmdir__ <diretório> ou
	#     __rmdir__ <arquivo>
	[[ -z $1 ]] && return 1

	# Se o arquivo/diretório não for removido por falta de privilegio 'root'
	# A função __sudo__ irá remover o arquivo/diretório.
	while [[ $1 ]]; do
		printf "[>] Removendo: $1 "
		if rm -rf "$1" 2> /dev/null || sudo rm -rf "$1"; then
			_syellow "OK"
		else
			_sred "FALHA"
		fi
		shift
	done
}

#==========================================================#
#================= Descompressão dos arquivos =============#
#==========================================================#
_unpack()
{
	# Obrigatório informar um arquivo no argumento $1.
	if [[ ! -f "$1" ]]; then
		_red "(_unpack) nenhum arquivo informado como argumento"
		return 1
	fi

	# Destino para descompressão.
	if [[ -d "$2" ]]; then 
		DirUnpack="$2"
	elif [[ -d "$DirUnpack" ]]; then
		DirUnpack="$DirUnpack"
	else
		_red "(_unpack): nenhum diretório para descompressão foi informado"
		return 1
	fi 
	
	cd "$DirUnpack"
	path_file="$1"

	# Detectar a extensão do arquivo.
	if [[ "${path_file: -6}" == 'tar.gz' ]]; then    # tar.gz - 6 ultimos caracteres.
		type_file='tar.gz'
	elif [[ "${path_file: -7}" == 'tar.bz2' ]]; then # tar.bz2 - 7 ultimos carcteres.
		type_file='tar.bz2'
	elif [[ "${path_file: -6}" == 'tar.xz' ]]; then  # tar.xz
		type_file='tar.xz'
	elif [[ "${path_file: -4}" == '.zip' ]]; then    # .zip
		type_file='zip'
	elif [[ "${path_file: -4}" == '.deb' ]]; then    # .deb
		type_file='deb'
	else
		_red "(_unpack) arquivo não suportado: $path_file"
		__rmdir__ "$path_file"
		return 1
	fi

	printf "%s\n" "[>] Descomprimindo: $path_file "
	printf "%s" "[>] Destino: $DirUnpack "
	
	# Descomprimir.	
	case "$type_file" in
		'tar.gz') tar -zxvf "$path_file" -C "$DirUnpack" 1> /dev/null 2>&1;;
		'tar.bz2') tar -jxvf "$path_file" -C "$DirUnpack" 1> /dev/null 2>&1;;
		'tar.xz') tar -Jxf "$path_file" -C "$DirUnpack" 1> /dev/null 2>&1;;
		zip) unzip "$path_file" -d "$DirUnpack" 1> /dev/null 2>&1;;
		deb) ar -x "$path_file" 1> /dev/null;;
		*) return 1;;
	esac

	if [[ "$?" == '0' ]]; then
		_syellow "OK"
		return 0
	else
		_sred "FALHA"
		_red "(_unpack) erro: $path_file"
		__rmdir__ "$path_file"
		return 1
	fi
}

_zenity()
{
	case "$1" in
	--question) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--info) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--error) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5";;
	--file-selection) zenity "$1" --title="$2" --file-filter="$3" --file-filter="$4" --file-filter="$5";;
	--list) zenity "$1" --title="$2" --text="$3" --width="$4" --height="$5" --column "$6" $7;; 
	esac
}

_uninstall_packettracer()
{
	[[ -d '/opt/pt' ]] && __rmdir__ '/opt/pt'
	[[ -f '/usr/share/applications/cisco-pt7.desktop' ]] && __rmdir__ '/usr/share/applications/cisco-pt7.desktop'
	[[ -f '/usr/share/applications/cisco-ptsa7.desktop' ]] && __rmdir__ '/usr/share/applications/cisco-ptsa7.desktop'
	[[ -x '/usr/local/bin/packettracer' ]] && __rmdir__ '/usr/local/bin/packettracer'
	_yellow "packettracer desinstalado com sucesso"
}

# Função para configurar libpng12.
_config_libpng()
{
	# Suporte a 32 bits.
	_msg "Adicionando suporte a ARCH i386"
	sudo dpkg --add-architecture i386
	sudo apt update

	__download__ "$URLlibpng12Debian8" "$FileLibpng12Deb8" || return 1
	__shasum__ "$FileLibpng12Deb8" "$hashLibpng12Deb8" || return 1
	
	# Verificar se packettracer foi instalado neste diretório '/opt/pt/bin/'.
	if [[ ! -d "/opt/pt/bin/" ]]; then
		_red "Instale Cisco packettracer em ...... (/opt/pt) Em seguida execute este programa novamente"
		return 1
	fi

	# Usar dpkg para extrair o arquivo e obter 'libpng12.so.0.50.0'.
	cd "$DirUnpack"
	sudo dpkg-deb -x "$FileLibpng12Deb8" "$DirUnpack"
	cd lib/x86_64-linux-gnu
	sudo cp -v -u libpng12.so.0.50.0 '/opt/pt/bin/libpng12.so.0.50.0'
	sudo ln -sf /opt/pt/bin/libpng12.so.0.50.0 '/opt/pt/bin/libpng12.so.0'  
	cd "$DirUnpack" && __rmdir__ $(ls)
}

# Função para instalar dependências em ubuntu bionic.
_install_libs_bionic()
{
	sudo apt install -y libssl1.0.0
	_config_libpng || return 1
}

# Função para instalar dependências em debian buster.
_install_libs_buster()
{
	# libssl1.0
	__download__ "$URLlibssl1Debian8" "$FileLibssl1Deb8" || return 1
	__shasum__ "$FileLibssl1Deb8" "$hashLibssl1Deb8" || return 1

	_msg "Instalando: $FileLibssl1Deb8"
	sudo gdebi "$FileLibssl1Deb8"
	_config_libpng || return 1
}


# Corrigir arquivos em /opt/pt
_config_ptracer_files()
{

	# /opt/pt/tpl.linguist
	if [[ -f '/opt/pt/tpl.linguist' ]]; then 
		sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.linguist
	fi

	# /opt/pt/tpl.packettracer
	if [[ -f '/opt/pt/tpl.packettracer' ]]; then
		sudo sed -i "s|PTDIR=.*|PTDIR=/opt/pt|g" /opt/pt/tpl.packettracer
	fi

	# Arquivo pt7.desktop
	if [[ -f '/opt/pt/bin/Cisco-PacketTracer.desktop' ]]; then
		sudo cp -u '/opt/pt/bin/Cisco-PacketTracer.desktop' '/usr/share/applications/' 
	fi

	# Remover arquivo '.desktop' duplicado.
	if [[ -f '/usr/share/applications/pt7.desktop' ]]; then
		sudo rm '/usr/share/applications/pt7.desktop'
	fi
}

_install_packettracer()
{
	for X in "${ciscoptRequerimentsDebian[@]}"; do
		_msg "Instalando: $X"
		sudo apt install "$X"
	done

	_msg "Instalando: ${ciscoptRequerimentsUbuntu[@]}"
	sudo apt install "${ciscoptRequerimentsUbuntu[@]}"
	
	while true; do

		InstalationPathFile=$(_zenity "--file-selection" "Selecionar arquivo" "*.deb" "*.run" "*.tar.gz")
		FileName=$(basename "$InstalationPathFile")

		if [[ ! -f "$InstalationPathFile" ]]; then
			_red "Arquivo inválido: $InstalationPathFile"
			return 1
			break
		fi

		echo -e "${CYellow}===================================================${CReset}\n"
		_YESNO "Deseja prosseguir com a instalação desse arquivo: $InstalationPathFile" || break
		_msg "Instalando: [$InstalationPathFile] "

		if [[ "${InstalationPathFile: -7}" == '.tar.gz' ]]; then # Pacote .tar.gz
					
			# Descomprimir.
			_unpack "$InstalationPathFile" || return 1
			cd "$DirUnpack"
			chmod +x "$DirUnpack"/install
			sed -i 's|^more .*||g' "$DirUnpack"/install

			./install
			return "$?"
			break

		elif [[ "${InstalationPathFile: -4}" == '.run' ]]; then
			chmod +x "$InstalationPathFile"
			"$InstalationPathFile"
			return "$?" 
			break
		elif [[ "${InstalationPathFile: -4}" == '.deb' ]]; then
			chmod +x "$InstalationPathFile"
			sudo gdebi "$InstalationPathFile"
			return "$?" 
			break
		fi

	done
}

__INSTALL__()
{
	if is_executable packettracer; then
		_msg "Cisco Packettracer já está instalado."
		#return 0
	fi
	
	sudo apt update 
	sleep .05
	clear
	_install_sys_requeriments || return 1
	_install_packettracer || return 1

	if [[ -f /opt/pt/packettracer ]]; then
		# ./PacketTracer7 "$@" > /dev/null 2>&1 
		# /opt/pt/bin/PacketTracer7 "$@" > /dev/null 2>&1
		sudo sed -i 's|\./PacketTracer7 \"\$\@\" > /dev/null 2>\&1|cd /opt/pt/bin; \./PacketTracer7 \"\$\@" > /dev/null 2>\&1|g' /opt/pt/packettracer
	fi
	
	_config_libpng || return 1
	case "$os_id" in
		debian) _install_libs_buster;;
	esac
}

#--------------------------------------------------#
# Run 
#--------------------------------------------------#
main()
{
	_msg "Sistema: $os_id $os_version_id"
	while [[ $1 ]]; do
		case "$1" in
			-i|--install) __INSTALL__;;
			-u|--uninstall) _uninstall_packettracer;;
			-h|--help) usage;;
			*) usage; return 1; break;;
		esac
		shift
	done

	
}

if [[ -z $1 ]]; then
	usage
	exit 
else
	main "$@"
fi

