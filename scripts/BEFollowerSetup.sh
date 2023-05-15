# BE Secondary
export http_proxy="http://wagcorppac-wag1.walgreens.com:8080"
export https_proxy="http://wagcorppac-wag1.walgreens.com:8080"
export NO_PROXY="127.0.0.1,10.0.0.0/8,.walgreens.com"
sudo service ufw stop
sudo service ufw disable 

curl --retry 3 --silent --show-error -o chef-backend-secrets.json "$1/chef-backend-secrets.json$2"

unset http_proxy
unset https_proxy
unset NO_PROXY

apt-get install -y apt-transport-https
wget -qO - https://downloads.chef.io/packages-chef-io-public.key | sudo apt-key add -
echo "deb https://packages.chef.io/stable-apt trusty main" > /etc/apt/sources.list.d/chef-stable.list
apt-get update

# store data on local ssd
apt-get install lvm2 xfsprogs sysstat atop -y
umount -f /mnt
pvcreate -f /dev/sdb1
vgcreate chef-vg /dev/sdb1
lvcreate -n chef-lv -l 80%VG chef-vg
mkfs.xfs /dev/chef-vg/chef-lv
mkdir -p /var/opt/chef-backend
mount /dev/chef-vg/chef-lv /var/opt/chef-backend

# Chef server setup
apt-get install -y chef-backend

# Grab IP address and prepopulate configuration
IPADRESS=`ifconfig eth0 | awk '/inet /{print substr($2,1)}'`
cat > /etc/chef-backend/chef-backend.rb <<EOF
publish_address '${IPADRESS}'
postgresql.log_min_duration_statement = 500
elasticsearch.heap_size = 3500
etcd.heartbeat_interval 1000
etcd.election_timeout 10000
EOF

chef-backend-ctl join-cluster 10.217.17.185 -s chef-backend-secrets.json --accept-license --yes --verbose --quiet

# enable basic data collection
echo 'ENABLED="true"' > /etc/default/sysstat
service sysstat start
