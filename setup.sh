set -euo pipefail

sudo -v

bold=$(tput bold)
green=$(tput setaf 2)
orange=$(tput setaf 202)
reset=$(tput sgr0)

while true; do sudo -v; sleep 60; done &
KEEPALIVE=$!
trap 'kill $KEEPALIVE' EXIT

# sudo pacman -Syu --noconfirm

require_arch(){ [[ -f /etc/arch-release ]] || { echo "Arch only"; exit 1; }; }
pkg(){ sudo pacman --noconfirm --needed -S "$@"; }
aur(){ yay -S --noconfirm --needed "$@"; }

pkg git base-devel curl wget openssh zsh

# Only add Chaotic-AUR if the architecture is x86_64 so ARM users can build the packages
if [[ "$(uname -m)" == "x86_64" ]] && ! command -v yay &>/dev/null; then
	# Try installing Chaotic-AUR keyring and mirrorlist
	if ! pacman-key --list-keys 3056513887B78AEB >/dev/null 2>&1 &&
		sudo pacman-key --recv-key 3056513887B78AEB &&
		sudo pacman-key --lsign-key 3056513887B78AEB &&
		sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' &&
		sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'; then

		# Add Chaotic-AUR repo to pacman config
		if ! grep -q "chaotic-aur" /etc/pacman.conf; then
			echo -e '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf >/dev/null
		fi

		# Install yay directly from Chaotic-AUR
		sudo pacman -Sy --needed --noconfirm yay
	else
		echo "Failed to install Chaotic-AUR, so won't include it in pacman config!"
	fi
fi

# Networking
if ! command -v firewalld &>/dev/null; then
	echo "${bold}${orange}=====Beginning Network Setup=====${reset}"
	pkg networkmanager network-manager-applet firewalld
	echo "${bold}${green}=====Core Network Apps Installed=====${reset}"
else
	echo "${bold}${green}=====Skipping Core Network Apps=====${reset}"
fi
if [ ! -f "/etc/NetworkManager/conf.d/priority.conf" ]; then
  	echo "${bold}${orange}=====Configuring Network=====${reset}"
	sudo systemctl enable --now NetworkManager.service
	sudo systemctl enable --now firewalld.service
	CONFIG_DIR="/etc/NetworkManager/conf.d"
	CONFIG_FILE="$CONFIG_DIR/priority.conf"

	# Make sure config dir exists
	sudo mkdir -p "$CONFIG_DIR"

	# Write config file
	sudo tee "/etc/NetworkManager/conf.d/priority.conf" > /dev/null << 'EOF'
[connection-ethernet]
match-device=type:ethernet
connection.autoconnect-priority=10
ipv4.route-metric=10
ipv6.route-metric=10

[connection-wifi]
match-device=type:wifi
connection.autoconnect-priority=0
ipv4.route-metric=20
ipv6.route-metric=20
EOF
echo "${bold}${green}=====Network Configuration Complete=====${reset}"
else
	echo "${bold}${green}=====Skipping network config setup=====${reset}"
fi

# Login
if ! systemctl list-unit-files | grep -q '^sddm.service'; then
	pkg sddm
	sudo systemctl enable sddm.service
else
	echo "${bold}${green}=====Skipping sddm setup=====${reset}"
fi
sudo tee /etc/sddm.conf > /dev/null <<EOF
[Autologin]
User=raito
Session=hyprland.desktop
EOF

# Hyprland
if ! command -v hyprland &>/dev/null; then
	pkg hyprland hyprshot hyprlock hypridle hyprpaper waybar mako wlogout \
		hyprpolkitagent xdg-desktop-portal-hyprland xdg-desktop-portal-wlr xdg-desktop-portal-gtk hyprland-guiutils
	aur walker-bin
else
	echo "${bold}${green}=====Skipping hyprland setup=====${reset}"
fi

# Terminal
if ! command -v ghostty &>/dev/null; then
	pkg oh-my-posh fzf zoxide fd lsd yazi ripgrep bat btop fastfetch tldr less nvim tmux \
	zip unzip ghostty neovim
	aur tmux-plugin-manager zinit rcm
else
	echo "${bold}${green}=====Skipping terminal setup=====${reset}"
fi

# Install chaotic-aur packages using pacman
pkg zen-browser-bin

# Desktop Utils
pkg timeshift wl-clipboard wl-clip-persist brightnessctl playerctl 

# Audio
echo "${bold}${green}=====Starting Audio Setup=====${reset}"

if pacman -Q jack2 &>/dev/null; then
    sudo pacman -Rns --noconfirm jack2
fi
pkg pavucontrol pipewire pipewire-alsa pipewire-jack pipewire-pulse wireplumber

systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service
systemctl --user enable --now wireplumber.service


# Fonts
pkg ttf-jetbrains-mono-nerd ttf-hack-nerd ttf-font-awesome ttf-cascadia-mono-nerd noto-fonts 

# Apps
pkg loupe vlc


# Build packages from aur using yay
aur thorium-browser-avx2-bin

# Setup git ssh keys (bad idea, would not recommend)
if [ ! -f "$HOME/.ssh/raito-gh" ]; then
	wget -P ~/Downloads http://local.get/git-keys.zip
	unzip ~/Downloads/git-keys.zip -d ~/.ssh/

	chmod 700 ~/.ssh
	chmod 600 ~/.ssh/raito-gh
	chmod 644 ~/.ssh/raito-gh.pub
	chmod 600 ~/.ssh/sh-gh
	chmod 644 ~/.ssh/sh-gh.pub
	chmod 600 ~/.ssh/sh-gt
	chmod 644 ~/.ssh/sh-gt.pub
else
	echo "${bold}${green}=====Skipping git-ssh setup=====${reset}"
fi

if [ ! -d "$HOME/.dotfiles" ]; then
	git clone https://github.com/Raito-chan/.dotfiles.git $HOME
	rcup -f
else
	echo "${bold}${green}=====Skipping dotfiles setup=====${reset}"
fi


# Cleanup
#yay -Scc --noconfirm
#yay -Rns $(pacman -Qdtq)
#rm -rf ~/.cache/yay/*

# TODO 
# power
# sleep
# swap/hybernate
# lock
# btrfs, timeshift

