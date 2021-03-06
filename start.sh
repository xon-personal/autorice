#!/bin/bash

# Prepare variables
dotfiles="https://github.com/xon-personal/rice.git"
csv="https://raw.githubusercontent.com/xon-personal/autorice/master/apps.csv"
helper="yay"
repobranch="master"
distro="arch"
grepseq="\"^[PGA]*,\""

installpkg() { pacman --noconfirm --needed -S "$1" &>/dev/null; }

error() { clear; printf "ERROR:\\n%s\\n" "$1"; exit; }

welcomemsg() {
	read -rp "Welcome to installation script. Continue? y/N" -n 1
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		error "Bye"
	fi
}

getuserandpass() {
	name=''
	read -rp "Account name: " name
	while ! echo "$name" | grep "^[a-z_][a-z0-9_-]*$" &> /dev/null; do
		read -rp "Not valid username: " name
	done
	pass1=''; pass2=''
	read -rp "Password:" -s pass1; echo
	read -rp "Retype:" -s pass2; echo
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		echo 'Passwords not match'
		read -rp "Password:" -s pass1; echo
		read -rp "Retype:" -s pass2; echo
	done
}

usercheck() {
	! (id -u "$name" &>/dev/null) ||
	{ read -rp 'Warning! User exists in system. Continue?' -n 1
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		error "Bye"
		exit 1
	fi; }
}

preinstallmsg() {
	read -rp "Start installation? y/N" -n 1
	echo
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		error "Bye"
		exit 1
	fi
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	echo "Adding user \"$name\"..."
	useradd -m -g wheel -s /bin/bash "$name" &> /dev/null ||
	usermod -a -G wheel,input "$name" && mkdir -p /home/"$name" \
						/home/"$name"/vids \
						/home/"$name"/misc \
						/home/"$name"/pics \
						/home/"$name"/music/plists \
						/home/"$name"/dloads/tors \
						/home/"$name"/dloads/browser \
						/home/"$name"/docs \
						/home/"$name"/src \
						/home/"$name"/work && chown -R "$name":wheel /home/"$name"
	repodir="/home/$name/.local/src"; mkdir -p "$repodir"; chown -R "$name":wheel $(dirname "$repodir")
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2
}

refreshkeys() {
	echo "Refreshing Keyring"
	pacman --noconfirm -Sy archlinux-keyring &> /dev/null
}

newperms() {
	sed -i "/#XON/d" /etc/sudoers
	echo "$* #XON" >> /etc/sudoers ;
}

manualinstall() {
	[ -f "/usr/bin/$1" ] || (
	echo "Installing $1"
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$name" tar -xvf "$1".tar.gz &>/dev/null &&
	cd "$1" &&
	sudo -u "$name" makepkg --noconfirm -si &>/dev/null
	cd /tmp || return);
}

maininstall() {
	echo "[$n/$total] $1 | pacman"
	installpkg "$1"
}

gitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	echo "[$n/$total] $progname | git + make"
	sudo -u "$name" git clone --depth 1 "$1" "$dir" &> /dev/null || { cd "$dir" || return ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit
	make &> /dev/null
	make install &> /dev/null
	cd /tmp || return ;
}

aurinstall() {
	echo "[$n/$total] '$1' | AUR"
	echo "$aurinstalled" | grep "^$1$" &> /dev/null && return
	sudo -u "$name" $helper -S --noconfirm "$1" &> /dev/null
}

pipinstall() {
	echo "[$n/$total] '$1' | pip"
	command -v pip || installpkg python-pip &> /dev/null
	yes | pip install "$1"
}

installationloop() {
	curl -Ls "$csv" | sed '/^#/d' | eval grep "$grepseq" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qqm)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep "^\".*\"$" &> /dev/null && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"A") aurinstall "$program" ;;
			"G") gitmakeinstall "$program" ;;
			"P") pipinstall "$program" ;;
			*) maininstall "$program" ;;
		esac
	done < /tmp/progs.csv ;
}

#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#
welcomemsg        || error "User exited."
getuserandpass    || error "User exited."
usercheck         || error "User exited."
preinstallmsg     || error "User exited."
adduserandpass    || error "Error adding username and/or password."
refreshkeys       || error "Error automatically refreshing Arch keyring. Consider doing so manually."

echo "Preparing install."
installpkg curl   || error "Exited on curl"
installpkg base-devel   || error "Exited on base-devel"
installpkg git   || error "Exited on git"
installpkg ntp   || error "Exited on ntp"

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"
# Make yay colorful + eye candy.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
# Use all cores for compilation.
sed -i "s/-j2/-j$(nproc)/;s/^#MAKEFLAGS/MAKEFLAGS/" /etc/makepkg.conf
manualinstall $helper || error "Failed to install AUR helper."
installationloop
echo "Finally, installing \`libxft-bgra\` to enable color emoji in suckless software without crashes."
yes | sudo -u "$name" $helper -S libxft-bgra &> /dev/null
echo "Downloading and installing config files..."
dir=$(mktemp -d)
[ ! -d "/home/$name" ] && mkdir -p "/home/$name"
chown -R "$name":wheel "$dir"
sudo -u "$name" git clone --recurse-submodules -b "$repobranch" "$dotfiles" "$dir" &> /dev/null
sudo -u "$name" cp -rfT "$dir" "/home/$name"
# Additional
sudo -u "$name" mv "/home/$name/.config/wallpapers" "/home/$name/pics/walls"
sudo -u "$name" mv "/home/$name/.config/icons" "/home/$name/pics/icons"
# System beep off
rmmod pcspkr
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;
# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" &> /dev/null
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"
dbus-uuidgen > /var/lib/dbus/machine-id
killall pulseaudio; sudo -u "$name" pulseaudio --start
[ "$distro" = arch ] && newperms "%wheel ALL=(ALL) ALL #XON
%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart,/usr/bin/pacman -Syyu --noconfirm,/usr/bin/loadkeys,/usr/bin/yay,/usr/bin/pacman -Syyuw --noconfirm #XON
Defaults env_editor,editor=/usr/bin/nvim:/usr/bin/vim:/usr/bin/nano:/usr/bin/vi"

echo "Congrats! Installation successfull"
clear
