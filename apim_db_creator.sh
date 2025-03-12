#!/bin/bash

echo "================================================"
echo "   WSO2 APIM 3.2.0 Auto MySQL Script Creator"
echo "              Version: 1.0"
echo "          Applicable for APIM 3.2.0"
echo "================================================"
echo "     "

# Check if MySQL is installed
command -v mysql >/dev/null 2>&1 || { echo >&2 "MySQL is not installed. Aborting."; exit 1; }

# Get MySQL root password
read -s -p "Enter MySQL root password: " mysql_password
echo

# Prompt for database names
read -p "Name your WSO2 APIM apim_db: " db_name_1
read -p "Name your WSO2 APIM shared_db: " db_name_2

# Check if databases already exist
existing_db_1=$(mysql -u root -p$mysql_password -e "SHOW DATABASES LIKE '$db_name_1';" | grep $db_name_1)
existing_db_2=$(mysql -u root -p$mysql_password -e "SHOW DATABASES LIKE '$db_name_2';" | grep $db_name_2)

if [ -n "$existing_db_1" ]; then
    echo "Database $db_name_1 already exists. Aborting."
    exit 1
fi

if [ -n "$existing_db_2" ]; then
    echo "Database $db_name_2 already exists. Aborting."
    exit 1
fi

# Connect to MySQL and execute commands to create databases
mysql -u root -p$mysql_password <<EOF
    CREATE DATABASE $db_name_1;
    GRANT ALL PRIVILEGES ON $db_name_1.* TO 'root'@'localhost';
    CREATE DATABASE $db_name_2;
    GRANT ALL PRIVILEGES ON $db_name_2.* TO 'root'@'localhost';
    FLUSH PRIVILEGES;
    SHOW DATABASES;
EOF

echo "Databases created and privileges granted successfully."

# Run SQL scripts
echo "Running SQL scripts..."
mysql -u root -p$mysql_password $db_name_1 < apim_mysqldb_scripts_3.2.1/apimgt/mysql.sql
mysql -u root -p$mysql_password $db_name_2 < apim_mysqldb_scripts_3.2.1/mysql.sql

echo "SQL scripts executed successfully."

# List tables in databases
echo "Tables in $db_name_1:"
mysql -u root -p$mysql_password -e "USE $db_name_1; SHOW TABLES;"
echo "Tables in $db_name_2:"
mysql -u root -p$mysql_password -e "USE $db_name_2; SHOW TABLES;"

echo "Tables listed successfully."