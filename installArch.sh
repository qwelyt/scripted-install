#! /bin/bash

# Usage:
#   ./installArch.sh /dev/sda1 myHostName
#
#   /dev/sda1: The mountpoint that should be mounted to /mnt
#   myHostName: What you want the hostname for the machine to be.
#
if [ -z "$1" ]
then
    echo "No mount point specified"
    exit 1
fi
if [ -z "$2" ]
then
    echo "No hostname specified"
    exit 2
fi

achroot() {
    arch-chroot /mnt /bin/bash -c "${1}"
}
timedatectl set-ntp true
mount $1 /mnt
pacstrap /mnt base
genfstab -U /mnt >> /mnt/etc/fstab

achroot "ln -s /usr/share/zoneinfo/Europe/Stockholm /etc/localtime"

achroot "hwclock --systohc"

echo "en_GB.UTF-8 UTF-8" >> /mnt/etc/locale.gen
achroot "locale-gen"

echo "LANG=en_GB.UTF-8" >> /mnt/etc/locale.conf

echo "KEYMAP=dvorak-sv-a1" >> /mnt/etc/vconsole.conf
echo $2 >> /mnt/etc/hostname

achroot "mkinitcpio -p linux"

echo "Change root pass"
achroot "passwd"

read -p '[I]nstall grub or [e]xit: ' bootloader
case $bootloader in
    [eE])
        exit 0
        ;;
    [iI])
        achroot "pacman -S --noconfirm grub"
        read -p 'Install to [/dev/sda]: ' installTo
        if [[ -z "$installTo" ]]
        then
            achroot "grub-install /dev/sda"
        else
            achroot "grub-install $installTo"
        fi
        achroot "grub-mkconfig -o /boot/grub/grub.cfg"
        ;;
    *)
        exit 123
        ;;
esac

echo ""
read -r -p 'Run post-installation setup? [Y/n]' postInstall
case $postInstall in
    [nN])
        exit 0
        ;;
esac

achroot "pacman -S --noconfirm sudo openssh sshfs zsh grml-zsh-config screen vim tar wget openvpn git"
achroot "chsh -s /bin/zsh"

read -r -p 'Create user? [Y/n]' createUser
case $createUser in
    [nN])
        exit 0
        ;;
esac

read -r -p 'Username: ' username
achroot "useradd -m -G wheel -s /bin/zsh $username"
echo "Password for user"
achroot "passwd $username"

read -r -p 'Install X and stuff? [Y/n]: ' installX
case $installX in
    [nN])
        exit 0
        ;;
esac

achroot "pacman -S --noconfirm xorg-server xorg-xinit xorg-setxkbmap awesome rxvt-unicode git"

achroot "lspci | grep -e VGA -e 3D"
read -r -p 'Install [i]ntel, [a]md, or [n]videa driver?' driver
case $driver in
    [iI])
        achroot "pacman -S --noconfirm xf86-video-intel"
        ;;
    [aA])
        achroot "pacman -S --noconfirm xf86-video-ati"
        ;;
    [nN])
        achroot "pacman -S --noconfirm xf86-video-nouveau"
        ;;
    *)
        echo "Nope"
        ;;
esac

cat > /mnt/etc/X11/xorg.conf.d/10-keyboard.conf << EOL
Section "InputClass"
Identifier  "Keyboard Defaults"
MatchIsKeyboard "yes"
Option      "XkbLayout" "se"
#Option      "XkbVariant" "dvorak"
Option      "XkbOptions" "compose:menu"
EndSection
EOL

read -r -p 'Install docker and pull down images?' installDocker
case $installDocker in
    [nN])
        exit 0
        ;;
esac

achroot "pacman -S --noconfirm docker"
mkdir -p /mnt/home/${username}/code/github
mkdir -p /mnt/home/${username}/bin
cd /mnt/home/${username}/code/github \
  && git clone https://github.com/qwelyt/docker-stuff.git \
  && cd docker-stuff/chromium \
  && docker build -t chromium .
  && cd /mnt/home/${username}/bin && ln -s chromium /mnt/home/${username}/code/github/chromium/chromium
