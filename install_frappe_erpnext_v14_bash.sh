#!/bin/bash

# ========= USER INPUTS =========
read -p "Enter new MariaDB Database Name: " dbname
read -p "Enter new MariaDB Root Password: " dbrootpwd
read -p "Enter new Frappe Site Name (e.g. mysite.local): " sitename
read -p "Enter new Site Admin Password: " adminpwd

# ========= INSTALL DEPENDENCIES =========
echo "⚙️ Installing system dependencies..."
sudo apt update
sudo apt install -y git curl python3.10 python3.10-dev python3.10-distutils python3-pip python3-setuptools \
    redis-server software-properties-common cron mariadb-server mariadb-client libmysqlclient-dev \
    xvfb libfontconfig wkhtmltopdf nginx supervisor build-essential libssl-dev libffi-dev

# ========= ALIAS python3.10 TO python =========
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1
sudo update-alternatives --set python /usr/bin/python3.10

# ========= NODE.JS & YARN =========
echo "📦 Installing Node.js and Yarn..."
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install -g yarn

# ========= INSTALL BENCH =========
echo "📦 Installing Frappe Bench CLI..."
pip3 install frappe-bench

# ========= CONFIGURE MARIADB ROOT PASSWORD =========
echo "🔐 Setting MariaDB root password..."
sudo service mysql stop
sudo mysqld_safe --skip-grant-tables > /dev/null 2>&1 &

sleep 5

mysql -u root <<MYSQL_SCRIPT
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '${dbrootpwd}';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo pkill -f mysqld_safe
sleep 3
sudo service mysql start

export MYSQL_ROOT_PASSWORD=$dbrootpwd

# ========= CREATE Frappe Bench =========
if [ ! -d "frappe-bench" ]; then
  echo "🚀 Initializing Frappe bench..."
  bench init frappe-bench --frappe-branch version-14 --python python3.10
fi

cd frappe-bench

# ========= GET ERPNext APP =========
echo "📦 Fetching ERPNext app..."
bench get-app erpnext --branch version-14

# ========= CREATE Frappe Site =========
echo "🌐 Creating site: $sitename"
bench new-site $sitename --mariadb-root-password $dbrootpwd --admin-password $adminpwd --db-name $dbname

# ========= INSTALL ERPNext =========
bench --site $sitename install-app erpnext
bench use $sitename

# ========= CREATE DB USER & GRANT PERMISSIONS =========
echo "🔐 Creating database user and granting access..."
mysql -u root -p$dbrootpwd <<MYSQL_SCRIPT
CREATE USER IF NOT EXISTS '${sitename}_user'@'localhost' IDENTIFIED BY '${dbrootpwd}';
GRANT ALL PRIVILEGES ON \`${dbname}\`.* TO '${sitename}_user'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# ========= DONE =========
echo "✅ Setup Complete!"
echo "Site: $sitename"
echo "Database: $dbname"
echo "Admin Password: $adminpwd"
echo "DB User: ${sitename}_user"
echo "DB Password: $dbrootpwd"

# ========= START SERVER =========
echo "🚀 Starting Frappe development server..."
bench start
