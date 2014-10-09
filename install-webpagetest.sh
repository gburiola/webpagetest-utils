#!/bin/bash
#title        : install-webpagetest.sh
#description  : This script will install a webpagetest server on a 
#               fresh Amazon Linux VM
#               Currently tested on Amazon Linux AMI 2014.09
#author       : Luis Buriola
#github       : https://github.com/gburiola
#date         : 2014-10-08
#version      : 0.1
#notes        : Detailed installation instructions on 
#               https://sites.google.com/a/webpagetest.org/docs/private-instances
#==============================================================================

echo "Updating packages on new host"
yum -y update

echo "Installing webpagetest required packages"
yum -y install httpd php php-gd php-pdo git ImageMagick libjpeg-turbo libjpeg-turbo-utils php-pecl-apc perl-Image-ExifTool

echo "Adding additional repositories and install ffmpeg"
cat <<EOF > /etc/yum.repos.d/dag.repo
[dag]
name="Dag RPM Repository for Red Hat Enterprise Linux"
baseurl=http://apt.sw.be/redhat/el6/en/x86_64/dag/
gpgcheck=1
gpgkey=http://apt.sw.be/RPM-GPG-KEY.dag.txt
enabled=0
includepkgs=ffmpeg ffmpeg-* faac a52dec x264 opencore-amr lame librtmp schroedinger libva dirac orc
EOF

cat <<EOF > /etc/yum.repos.d/centos6.repo
[centos]
name="CentOS-6 - Base"
baseurl=http://mirror.centos.org/centos/6/os/x86_64/
gpgcheck=1
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-6
enabled=0
priority=1
protect=1
includepkgs=SDL libtheora gsm libdc1394 libdrm liboil mesa-dri-drivers mesa-dri1-drivers mesa-dri-filesystem libraw1394 libpciaccess cppunit
EOF

yum --enablerepo='dag,centos' install -y ffmpeg

echo "Cloning webpagetest git repository"
cd /tmp/
git clone https://github.com/WPO-Foundation/webpagetest
mv /tmp/webpagetest/www /var/www/webpagetest
rm -rf /tmp/webpagetest

echo "Downloading updated agent files"
cd /var/www/webpagetest/work
mkdir update
cd update
wget http://www.webpagetest.org/work/update/update.zip
wget http://www.webpagetest.org/work/update/wptupdate.zip
unzip update.zip update.ini
unzip wptupdate.zip wptupdate.ini
chmod 777 /var/www/webpagetest/work/update/
chown -R apache.apache /var/www/webpagetest/work/update/

echo "Configuring Apache and PHP"
cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.orig
rm -f /etc/httpd/conf.d/welcome.conf

sed -i 's/KeepAlive Off/KeepAlive On/'                            /etc/httpd/conf/httpd.conf
sed -i 's/ServerSignature On/ServerSignature Off/'                /etc/httpd/conf/httpd.conf
sed -i 's/ServerTokens OS/ServerTokens Prod/'                     /etc/httpd/conf/httpd.conf
sed -i 's/Options Indexes FollowSymLinks/Options FollowSymLinks/' /etc/httpd/conf/httpd.conf
sed -i '/LoadModule mod_authnz_ldap/d'                            /etc/httpd/conf/httpd.conf
sed -i '/LoadModule cache/d'                                      /etc/httpd/conf/httpd.conf
sed -i '/LoadModule cern_meta/d'                                  /etc/httpd/conf/httpd.conf
sed -i '/LoadModule cgi/d'                                        /etc/httpd/conf/httpd.conf
sed -i '/LoadModule dav_fs/d'                                     /etc/httpd/conf/httpd.conf
sed -i '/LoadModule dav/d'                                        /etc/httpd/conf/httpd.conf
sed -i '/LoadModule dbd/d'                                        /etc/httpd/conf/httpd.conf
sed -i '/LoadModule disk_cache/d'                                 /etc/httpd/conf/httpd.conf
sed -i '/LoadModule dumpio/d'                                     /etc/httpd/conf/httpd.conf
sed -i '/LoadModule ext_filter/d'                                 /etc/httpd/conf/httpd.conf
sed -i '/LoadModule file_cache/d'                                 /etc/httpd/conf/httpd.conf
sed -i '/LoadModule ident/d'                                      /etc/httpd/conf/httpd.conf
sed -i '/LoadModule ldap/d'                                       /etc/httpd/conf/httpd.conf
sed -i '/LoadModule authnz_ldap/d'                                /etc/httpd/conf/httpd.conf
sed -i '/LoadModule logio/d'                                      /etc/httpd/conf/httpd.conf
sed -i '/LoadModule mime_magic/d'                                 /etc/httpd/conf/httpd.conf
sed -i '/LoadModule proxy/d'                                      /etc/httpd/conf/httpd.conf
sed -i '/LoadModule speling/d'                                    /etc/httpd/conf/httpd.conf
sed -i '/LoadModule substitute/d'                                 /etc/httpd/conf/httpd.conf
sed -i '/LoadModule suexec/d'                                     /etc/httpd/conf/httpd.conf
sed -i '/LoadModule userdir/d'                                    /etc/httpd/conf/httpd.conf
sed -i '/LoadModule usertrack/d'                                  /etc/httpd/conf/httpd.conf

sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 10M/'    /etc/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 10M/'                /etc/php.ini
sed -i 's/memory_limit = 128M/memory_limit = 256M/'               /etc/php.ini

cat <<EOF > /etc/httpd/conf.d/webpagetest.conf
<Directory "/var/www/webpagetest">
        AllowOverride all
        Order allow,deny
        Allow from all
</Directory>
<VirtualHost *:80>
        DocumentRoot /var/www/webpagetest
</VirtualHost>
EOF

chown -R apache.apache /var/www/webpagetest/

KEY="secret_key_placeholder"
echo "Configuring webpagetest ini files"
cp -a /var/www/webpagetest/settings/locations.ini.EC2-sample /var/www/webpagetest/settings/locations.ini
sed -i "s/key=SecretKey/key=${KEY}/g" /var/www/webpagetest/settings/locations.ini

cp -a /var/www/webpagetest/settings/settings.ini.sample /var/www/webpagetest/settings/settings.ini
sed -i "s/;map=1/map=1/g" /var/www/webpagetest/settings/settings.ini
sed -i "s/publishTo=www.webpagetest.org/;publishTo=www.webpagetest.org/g" /var/www/webpagetest/settings/settings.ini


cp -a /var/www/webpagetest/settings/connectivity.ini.sample /var/www/webpagetest/settings/connectivity.ini

echo "Starting Apache"
chkconfig httpd on
/etc/init.d/httpd start

PUBHOSTNAME=$(curl --silent 169.254.169.254/latest/meta-data/public-hostname)
echo "Webpagetest server: http://${PUBHOSTNAME}"
echo "Done"
