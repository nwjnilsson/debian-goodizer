#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

BLACK=$(tput setaf 0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
LIME_YELLOW=$(tput setaf 190)
POWDER_BLUE=$(tput setaf 153)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
BRIGHT=$(tput bold)
NORMAL=$(tput sgr0)
BLINK=$(tput blink)
REVERSE=$(tput smso)
UNDERLINE=$(tput smul)

function get_version() {
	echo $(grep "$1" "$SCRIPT_DIR/version.info" | sed 's/\(.*\):\(.*\)/\2/')
}

function check_run_command_as_root() {
  [[ "${EUID:-${UID}}" == "0" ]] || return
  echo "Don't run this as root!"
  exit 1
}

# Stuff that I usually want
function install() {
	check_run_command_as_root

	echo -e "${BLUE}---INSTALLING PACKAGES---${NORMAL}"
	sudo apt-get install -y \
		git \
		cmake \
		curl \
		build-essential \
		ripgrep \
		python3 \
		python3-pip \
		python3-setuptools \
		python3-wheel \
		ninja-build \
		meson \
		pkg-config \
		libspdlog-dev \
		libglfw3-dev \
		libglm-dev \
		libvulkan-dev \
		libjpeg62-turbo-dev \
		libpng-dev


	# Install neovim and deps if not present
	if ! command -v nvim &> /dev/null; then
		echo -e "${BLUE}---INSTALLING NEOVIM ETC---${NORMAL}"
		# Prerequisites
		sudo apt-get install \
			lua$(get_version "lua") \
			lua$(get_version "lua")-dev

		# Luarocks is a requirement at the time of writing this
		LUAROCKS="luarocks-$(get_version LuaRocks)"
		URL="https://luarocks.org/releases/$LUAROCKS.tar.gz"
		wget_output=$(wget -q "$URL" -O "$LUAROCKS.tar.gz")
		if [ $? -ne 0 ]; then
			failed+=("LuaRocks")
		else
			tar zxpf "$LUAROCKS.tar.gz"
			cd $LUAROCKS
			./configure && make && sudo make install
			sudo luarocks install luasocket
			cd ..
		fi

		# Download neovim
		URL="https://github.com/neovim/neovim/releases/latest/download/nvim.appimage"
		wget_output=$(wget -q "$URL" -O $APP_IMAGES/neovim.appimage)
		if [ $? -ne 0 ]; then
			failed+=("Neovim")
		else
			chmod u+x $APP_IMAGES/neovim.appimage
			sudo ln -s $APP_IMAGES/neovim.appimage /usr/bin/nvim
			# Download neovim config
			git clone https://github.com/nwjnilsson/neovim/ $HOME/.config/nvim/
		fi


		# Lualine plugin requires patched font
		FONT="$(get_version NerdFonts)"
		URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$FONT.tar.xz"
		wget_output=$(wget -q "$URL")
		if [ $? -ne 0 ]; then
			failed+=("Nerdfonts font ($FONT)")
		else
			mkdir CodeNewRoman
			tar -xf CodeNewRoman.tar.xz -C CodeNewRoman
			sudo mv CodeNewRoman /usr/local/share/fonts/
		fi

		if ! command -v brew &> /dev/null; then
			echo -e "${BLUE}---INSTALLING HOMEBREW---${NORMAL}"
			/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> $HOME/.zshrc
			eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" 
		fi

		# Language servers for neovim
		brew install lua-language-server
		brew install yaml-language-server
		brew install python-lsp-server
	fi

	# Install oh-my-zsh (assume that oh-my-zsh is installed if zsh is)
	if ! command -v zsh &> /dev/null; then
		echo -e "${BLUE}---INSTALLING ZSH---${NORMAL}"
		sudo apt-get install zsh -y
		echo -e "${BLUE}---RUNNING OH-MY-ZSH INSTALL SCRIPT---${NORMAL}"
		echo -e "${RED}---Remember to 'exit' after oh-my-zsh is installed to finish installation---${NORMAL}"
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
		git clone --depth 1 https://github.com/unixorn/fzf-zsh-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/fzf-zsh-plugin
		git clone https://github.com/agkozak/zsh-z ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-z
		# Set plugins
		sed -i 's/plugins=(\(.*\))/plugins=( \1 zsh-z fzf-zsh-plugin )/' $HOME/.zshrc
	fi

	if ! command -v conda &> /dev/null; then
		echo -e "${BLUE}---INSTALLING MINICONDA---${NORMAL}"
		mkdir -p $HOME/miniconda3
		URL="https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh"
		wget_output=$(wget -q $URL -O $HOME/miniconda3/miniconda.sh)
		if [ $? -ne 0 ]; then
			failed+=("Miniconda")
		else
			bash $HOME/miniconda3/miniconda.sh -b -u -p $HOME/miniconda3
			CONDA_INSTALLED="true"
			rm $HOME/miniconda3/miniconda.sh
		fi
	fi

}

TMP="tmp_files"
APP_IMAGES="$HOME/AppImages"
CODE="$HOME/code"

if ! [ -d $CODE ]; then mkdir -p $CODE; fi
if ! [ -d $APP_IMAGES ]; then mkdir -p $APP_IMAGES; fi
if ! [ -d $TMP ]; then mkdir -p $TMP; fi

cd $TMP # put downloads etc in this directory

failed=() # To keep track of download errors

install

# Cleanup
echo "Cleaning up..."
cd ..
rm $TMP -rf

if [ ${#failed[@]} -eq 0 ]; then
    echo "Seems like things went well."
else
	echo -e "\n${UNDERLINE}Failed to install the following things:${NORMAL}"
	printf '%s\n' "${RED}${failed[@]}${NORMAL}"
	echo "Install them manually or try updating the versions in version.conf"
fi

if [ -n "$CONDA_INSTALLED" ]; then
	echo "Conda has been installed, remember to run ~/miniconda3/bin/conda init zsh"
fi
