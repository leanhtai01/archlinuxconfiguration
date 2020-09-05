#!/bin/bash

set -e

mysqlroot_pass1=
mysqlroot_pass2=
parent_dir=$(cd $(dirname $0)/..; pwd)
grandpa_dir=$(cd $parent_dir/..; pwd)

# make place to save original config files (if not exist)
original_config_files_path=$(dirname $0)/original_config_files
if [ ! -d "$original_config_files_path" ]
then
    mkdir $original_config_files_path
fi

# set MySQL root's password
printf "\nSET MYSQL ROOT'S PASSWORD\n"
if [ -z $mysqlroot_pass1 ] || [ -z $mysqlroot_pass2 ] || [ $mysqlroot_pass1 != $mysqlroot_pass2 ]
then
    echo -n "Enter new MySQL root's password: "
    read -s mysqlroot_pass1
    echo -n -e "\nRetype MySQL root's password: "
    read -s mysqlroot_pass2

    while [ -z $mysqlroot_pass1 ] || [ -z $mysqlroot_pass2 ] || [ $mysqlroot_pass1 != $mysqlroot_pass2 ]
    do
	echo -e "\nSorry, passwords do not match. Please try again!"
	echo -n "Enter MySQL root's password: "
	read -s mysqlroot_pass1
	echo -n -e "\nRetype MySQL root's password: "
	read -s mysqlroot_pass2
    done
fi
echo -e "\nMySQL root's password set successfully!"

##################
# install Apache #
##################
pacman -Syu --needed --noconfirm apache
systemctl enable httpd
systemctl start httpd

###################
# install MariaDB #
###################
pacman -Syu --needed --noconfirm mariadb expect
mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
systemctl enable mariadb
systemctl start mariadb
SECURE_MYSQL=$(expect -c "
spawn mysql_secure_installation

expect \"Enter current password for root (enter for none):\"
send \"\r\"

expect \"Switch to unix_socket authentication\"
send \"n\r\"

expect \"Change the root password?\"
send \"y\r\"

expect \"New password:\"
send \"${mysqlroot_pass1}\r\"

expect \"Re-enter new password:\"
send \"${mysqlroot_pass1}\r\"

expect \"Remove anonymous users?\"
send \"y\r\"

expect \"Disallow root login remotely?\"
send \"y\r\"

expect \"Remove test database and access to it?\"
send \"y\r\"

expect \"Reload privilege tables now?\"
send \"y\r\"

expect eof
")

echo "${SECURE_MYSQL}"

###############
# install PHP #
###############
pacman -Syu --needed --noconfirm php php-apache

# set timezone
cp /etc/php/php.ini $original_config_files_path
printf "php.ini: /etc/php/php.ini\n" >> $original_config_files_path/original_path.txt
linum=$(sed -n '/^;date.timezone =$/=' /etc/php/php.ini)
sed -i "${linum}s/^;//" /etc/php/php.ini
sed -i "${linum}s/=/& Asia\/Ho_Chi_Minh/" /etc/php/php.ini

# display errors to debug PHP code
sed -i "/^display_errors = Off$/s/Off/On/" /etc/php/php.ini

# comment line LoadModule mpm_event_module modules/mod_mpm_event.so
cp /etc/httpd/conf/httpd.conf $original_config_files_path
printf "httpd.conf: /etc/httpd/conf/httpd.conf\n" >> $original_config_files_path/original_path.txt
linum=$(sed -n '/^LoadModule mpm_event_module modules\/mod_mpm_event.so$/=' /etc/httpd/conf/httpd.conf)
sed -i "${linum}s/^/#&/" /etc/httpd/conf/httpd.conf

# uncomment line LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
sed -i "/^#LoadModule mpm_prefork_module modules\/mod_mpm_prefork.so$/s/^#//" /etc/httpd/conf/httpd.conf

# place some line at the end of the LoadModule list:
linum=$(sed -n '/^#\?LoadModule /=' /etc/httpd/conf/httpd.conf | tail -1)
# sed -i "${linum}G" /etc/httpd/conf/httpd.conf
# ((linum++))
sed -i "${linum} a LoadModule php7_module modules\/libphp7.so" /etc/httpd/conf/httpd.conf
((linum++))
sed -i "${linum} a AddHandler php7-script .php" /etc/httpd/conf/httpd.conf

# place some line at the end of the Include list
linum=$(sed -n $= /etc/httpd/conf/httpd.conf) # get the last line number
sed -i "${linum} a Include conf\/extra\/php7_module.conf" /etc/httpd/conf/httpd.conf

# restart httpd.service
systemctl restart httpd

######################
# install phpMyAdmin #
######################
pacman -Syu --needed --noconfirm phpmyadmin

# enable some PHP extensions
sed -i "/^;extension=pdo_mysql$/s/^;//" /etc/php/php.ini
sed -i "/^;extension=mysqli$/s/^;//" /etc/php/php.ini
sed -i "/^;extension=bz2$/s/^;//" /etc/php/php.ini
sed -i "/^;extension=zip$/s/^;//" /etc/php/php.ini

# create the Apache configuration file
cp $grandpa_dir/data/phpmyadmin.conf /etc/httpd/conf/extra/phpmyadmin.conf

# include the Apache configuration file in /etc/httpd/conf/httpd.conf
linum=$(sed -n $= /etc/httpd/conf/httpd.conf)
sed -i "${linum} a # phpMyAdmin configuration" /etc/httpd/conf/httpd.conf
((linum++))
sed -i "${linum} a Include conf\/extra\/phpmyadmin.conf" /etc/httpd/conf/httpd.conf

# to allow the usage of the phpMyAdmin setup script
mkdir /usr/share/webapps/phpMyAdmin/config
chown http:http /usr/share/webapps/phpMyAdmin/config
chmod 750 /usr/share/webapps/phpMyAdmin/config

# add blowfish_secret passphrase
cp /usr/share/webapps/phpMyAdmin/config.inc.php $original_config_files_path
printf "config.inc.php: /usr/share/webapps/phpMyAdmin/config.inc.php\n" >> $original_config_files_path/original_path.txt
sed -i "/^\$cfg\['blowfish_secret'\] = '';/s/''/'$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)'/" /usr/share/webapps/phpMyAdmin/config.inc.php

# enabling configuration storage
pmapass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['controluser'\] = 'pma';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['controlpass'\] = 'pmapass';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\$cfg\['Servers'\]\[\$i\]\['controlpass'\] = 'pmapass';/s/pmapass/${pmapass}/" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['pmadb'\] = 'phpmyadmin';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['bookmarktable'\] = 'pma__bookmark';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['relation'\] = 'pma__relation';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_info'\] = 'pma__table_info';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_coords'\] = 'pma__table_coords';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['pdf_pages'\] = 'pma__pdf_pages';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['column_info'\] = 'pma__column_info';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['history'\] = 'pma__history';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['table_uiprefs'\] = 'pma__table_uiprefs';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['tracking'\] = 'pma__tracking';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['userconfig'\] = 'pma__userconfig';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['recent'\] = 'pma__recent';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['favorite'\] = 'pma__favorite';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['users'\] = 'pma__users';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['usergroups'\] = 'pma__usergroups';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['navigationhiding'\] = 'pma__navigationhiding';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['savedsearches'\] = 'pma__savedsearches';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['central_columns'\] = 'pma__central_columns';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['designer_settings'\] = 'pma__designer_settings';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php
sed -i "/\/\/ \$cfg\['Servers'\]\[\$i\]\['export_templates'\] = 'pma__export_templates';/s/\/\/ //" /usr/share/webapps/phpMyAdmin/config.inc.php

# setup database
mysql -u root --password=${mysqlroot_pass1} < /usr/share/webapps/phpMyAdmin/sql/create_tables.sql

# setup database user
cp $grandpa_dir/data/setup_database_user.sql $grandpa_dir/data/setup_database_user.sql.bak
sed -i "s/pmapass/${pmapass}/" $grandpa_dir/data/setup_database_user.sql
mysql -u root --password=${mysqlroot_pass1} < $grandpa_dir/data/setup_database_user.sql
cp $grandpa_dir/data/setup_database_user.sql.bak $grandpa_dir/data/setup_database_user.sql
rm $grandpa_dir/data/setup_database_user.sql.bak

# enabling template caching
linum=$(sed -n "/\$cfg\['SaveDir'\] = '';/=" /usr/share/webapps/phpMyAdmin/config.inc.php)
sed -i "${linum} a \$cfg\['TempDir'\] = '\/tmp\/phpmyadmin';" /usr/share/webapps/phpMyAdmin/config.inc.php

# remove config directory
rm -r /usr/share/webapps/phpMyAdmin/config

# restart httpd.service
systemctl restart httpd
