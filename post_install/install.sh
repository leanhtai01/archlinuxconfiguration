#!/bin/bash

set -e

current_dir=$(dirname $0)
install_type=core # {core full virtualbox}
desktop_environment=

# ask user for setup desktop environment
display_menu_desktop_environment()
{
    printf "Choose desktop environment:\n"
    printf "1. GNOME\n"
    printf "2. KDE Plasma\n"
    printf "3. i3 (tiling window manager)\n"
    printf "4. None\n"
    printf "Enter your choice: "
}

if [ -z "$desktop_environment" ]
then
    re="[1-4]"

    display_menu_desktop_environment
    read DE_choice

    while [[ ! "$DE_choice" =~ $re ]]
    do
	printf "\nInvalid choice! Please try again!\n"
	display_menu_desktop_environment
	read DE_choice
    done

    # set desktop enviroment will be installed
    case $DE_choice in
	1)
	    desktop_environment=GNOME
	    ;;
	2)
	    desktop_environment=KDEPlasma
	    ;;
	3)
	    desktop_environment=i3
	    ;;
	4)
	    desktop_environment=none
	    ;;
    esac
fi

$current_dir/configure.sh $install_type $desktop_environment
$current_dir/install_packages.sh $install_type $desktop_environment
$current_dir/install_external_packages.sh $install_type $desktop_environment

if [ $install_type = "full" ]
then
    $current_dir/install_optional_external_packages.sh
fi
