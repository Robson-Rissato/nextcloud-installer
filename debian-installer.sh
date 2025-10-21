#!/bin/bash

INSTALLERVERSION="1.00.01"

if [[ $(whoami) != "root" ]]; then
  echo "You must be root to run this script!"
  exit 1
fi

oldpath=$(pwd)

function compareVersions {
  if [[ -z "$1" || -z "$2" ]]; then
    echo "Failed to compare versions..." >&2
    return 1
  fi
  IFS='.' read -ra versionold <<< "$1"
  IFS='.' read -ra versionnew <<< "$2"
  for ((n=0; n<${#versionnew[@]}; n++)); do
    versionnew[$n]=$((10#${versionnew[$n]}))
  done
  for ((n=0; n<${#versionold[@]}; n++)); do
    versionold[$n]=$((10#${versionold[$n]}))
  done
  while [[ ${#versionold[@]} -lt ${#versionnew[@]} ]]; do versionold+=(0); done
  while [[ ${#versionnew[@]} -lt ${#versionold[@]} ]]; do versionnew+=(0); done
  for ((n=0; n<${#versionnew[@]}; n++)); do
    if (( versionnew[n] > versionold[n] )); then return 0; fi
    if (( versionnew[n] < versionold[n] )); then return 1; fi
  done
  return 1
}

function decho {
  echo "$@"
  echo "$@" >> "$oldpath/installer-errors.log"
}
function doMariaDB {
  echo "UPDATE mysql.global_priv SET priv=json_set(priv, '$.password_last_changed', UNIX_TIMESTAMP(), '$.plugin', 'mysql_native_password', '$.authentication_string', 'invalid', '$.auth_or', json_array(json_object(), json_object('plugin', 'unix_socket'))) WHERE User='root';" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "FLUSH PRIVILEGES;" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "UPDATE mysql.global_priv SET priv=json_set(priv, '$.plugin', 'mysql_native_password', '$.authentication_string', PASSWORD('basic_single_escape \"$DBROOTPASS\"')) WHERE User='root';" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "DELETE FROM mysql.global_priv WHERE User='';" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "DROP DATABASE IF EXISTS test;" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
  echo "FLUSH PRIVILEGES;" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || return 1
}

function doPHP {
  systemctl stop apache2 > /dev/null 2>> "$oldpath/installer-errors.log" && a2dismod php8.4 > /dev/null 2>> "$oldpath/installer-errors.log" && a2dismod mpm_prefork > /dev/null 2>> "$oldpath/installer-errors.log" && a2enmod mpm_event proxy proxy_fcgi setenvif rewrite > /dev/null 2>> "$oldpath/installer-errors.log" && a2enconf php8.4-fpm > /dev/null 2>> "$oldpath/installer-errors.log" && systemctl restart apache2 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "PHP FPM failed to start..."
  echo ";;;;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Resource Limits ;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "max_execution_time = 240" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "memory_limit = 512M" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Data Handling ;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "post_max_size = 512M" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; File Uploads ;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "upload_max_filesize = 2048M" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Module Settings ;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo ";;;;;;;;;;;;;;;;;;;" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "[Date]" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Defines the default timezone used by the date functions" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; https://php.net/date.timezone" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "date.timezone = $PHPTIMEZONE" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "[opcache]" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Determines if Zend OPCache is enabled" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.enable=1" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; The OPcache shared memory storage size." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.memory_consumption=1024" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; The amount of memory for interned strings in Mbytes." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.interned_strings_buffer=128" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; The maximum number of keys (scripts) in the OPcache hash table." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; Only numbers between 200 and 1000000 are allowed." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.max_accelerated_files=50000" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; When disabled, you must reset the OPcache manually or restart the" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; webserver for changes to the filesystem to take effect." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.validate_timestamps=0" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; How often (in seconds) to check file timestamps for changes to the shared" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; memory storage allocation. ("1" means validate once per second, but only" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; once per request. "0" means always validate)" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.revalidate_freq=60" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; If disabled, all PHPDoc comments are dropped from the code to reduce the" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "; size of the optimized code." >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  echo "opcache.save_comments=1" >> /etc/php/8.4/fpm/conf.d/99-nextcloud.ini
  systemctl restart php8.4-fpm.service > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "PHP FPM failed to load custom settings..."
}

function doREPORT {
  TODAY="$(date "+%Y-%m-%d")"
  touch "NEXTCLOUD-REPORT-$TODAY.md"
  echo "# NEXTCLOUD INSTALLATION REPORT" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Install Date:** $(date "+%B %-d, %Y")" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Installer Version:** $INSTALLERVERSION" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Installer Author:** Ze'ev Schurmann" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Installer License:** GPL 3.0 or later" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Installer Website:** https://github.com/Robson-Rissato/nextcloud-installer" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "## Logging onto Nextcloud" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "Open your browser to https://$FQDN" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Admin Username:** $NCADMIN" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Admin Password:** $NCPASS" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "## Setting up Talk App to use coTURN" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "1. Install the Talk App, then go to the Admin Settings and navigate to the section for Talk." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "2. Scroll down the page until you find the settings for the TURN server." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "3. Add a server." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "4. Use both turn: and turns:." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "5. The server URL is $FQDN." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "6. The secret is $TURNPASS." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "7. And set both UDP and TCP." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "8. Now click on the wavey line and it will shortly change to a green tick." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "If your server is behind a NAT Router or Firewall, you need to forward the following ports on your router to your server." >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "- 80, 443 (TCP)" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "- 3478, 3479, 5349, 5350 (TCP & UDP)" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "- 60000 to 61999 (TCP & UDP)" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "## MariaDB/MySQL Information:" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  if [[ $DBHOST == "localhost" ]]; then
    IFS=' ' read -ra temparray <<< $(mysql -V)
    echo "**MariaDB Server Version:** ${temparray[2]}" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**MySQL Root Password:** $DBROOTPASS" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  fi
  echo "**MySQL Server:** $DBHOST" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**MySQL Database Name:** $DBNAME" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**MySQL Database Username:** $DBUSER" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**MySQL Database Password:** $DBPASS" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "## Apache2 Information" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  IFS=' ' read -ra temparray <<< $(apache2 -v)
  IFS='/' read -ra temparray <<< $(echo ${temparray[2]})
  echo "**Apache2 Version:** ${temparray[1]}" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Loaded Apache2 Modules:** $(apache2ctl -M 2>/dev/null | awk '/_module/ {print $1}' | sed 's/_module$//' | sort | paste -sd, - | sed 's/,/, /g')" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Apache2 VHost File (http):** /etc/apache2/sites-available/$NCWWW.conf" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Apache2 VHost File (https):** /etc/apache2/sites-available/$NCWWW-le-ssl.conf" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**NextCloud WebRoot:** /var/www/$NCWWW/" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**NextCloud Files:** /var/$NCFILES/" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "## PHP Information" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**PHP Version:** $(php-fpm8.4 -v | grep "^PHP 8.4")" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo "**Loaded PHP Modules:** $(php-fpm8.4 -m | grep "^[[:alnum:]]\+" | sort | uniq | paste -sd, - | sed 's/,/, /g')" >> "NEXTCLOUD-REPORT-$TODAY.md"
  echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  if [[ $AUTOSWAP == "true" ]]; then
    echo "## AutoSWAP Information" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "AutoSWAP is a free tool licensed under GPL 3.0 or later. It monitors your system for memory usage, and when free system memory drops below a threshold it will create additional SWAP memory using a SWAP file in the root folder. When sufficient memory frees up, it will remove the SWAP file. It can do extra SWAP files if your system gets really hungry for memory. You can learn more at https://git.zaks.web.za/thisiszeev/linux-server-tools/src/branch/main/swap-management" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**Location of AutoSWAP configuration file:** /etc/autoswap/autoswap.conf" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    source /etc/autoswap/autoswap.conf
    echo "**Free system memory threshold:** $threshold_minimum MB" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**SWAP files size:** $swap_file_size MB" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**Number of SWAP files that will permanently exist:** $required_swap_files" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**Minimum amount of harddrive space that must always exist:** $minimum_free_storage MB" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "**How often system memory is checked:** $check_interval seconds" >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo "These settings can be edited in the /etc/autoswap/autoswap.conf file. Run `systemctl restart autoswap.service` to activate the new settings." >> "NEXTCLOUD-REPORT-$TODAY.md"
    echo >> "NEXTCLOUD-REPORT-$TODAY.md"
  fi
  echo
  echo "Your installation report is saved in this folder as NEXTCLOUD-REPORT-$TODAY.md"
  echo "It has all your important passwords and other information. Don't lose it."
}

function doSWAP {
  wget "https://github.com/Robson-Rissato/autoswap/archive/refs/tags/autoswap-v1.00.01.zip" > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to download Auto SWAP..."
  mkdir autoswap
  unzip autoswap-v1.00.01.zip -d ./autoswap
  mkdir /etc/autoswap
  mv ./autoswap/autoswap-autoswap-v1.00.01/autoswap.conf /etc/autoswap/autoswap.conf
  mv ./autoswap/autoswap-autoswap-v1.00.01/autoswap.sh /autoswap.sh
  chmod +x /autoswap.sh
  mv ./autoswap/autoswap-autoswap-v1.00.01/addswap.sh /addswap.sh
  chmod +x /addswap.sh
  mv ./autoswap/autoswap-autoswap-v1.00.01/remswap.sh /remswap.sh
  chmod +x /remswap.sh
  mv ./autoswap/autoswap-autoswap-v1.00.01/README.md /etc/autoswap/README.md
  mv ./autoswap/autoswap-autoswap-v1.00.01/LICENSE /etc/autoswap/LICENSE
  mv ./autoswap/autoswap-autoswap-v1.00.01/autoswap.service /etc/systemd/system/autoswap.service
  rm -R ./autoswap
  rm autoswap-v1.00.01.zip
  systemctl start autoswap.service > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Auto SWAP service failed to start..."
  systemctl enable autoswap.service > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Auto SWAP service could not be enabled..."
}

function doTimezoneAfrica {
  local TZONES=("Africa/Abidjan" "Africa/Accra" "Africa/Addis_Ababa" "Africa/Algiers" "Africa/Asmara" "Africa/Bamako" "Africa/Bangui" "Africa/Banjul" "Africa/Bissau" "Africa/Blantyre" "Africa/Brazzaville" "Africa/Bujumbura" "Africa/Cairo" "Africa/Casablanca" "Africa/Ceuta" "Africa/Conakry" "Africa/Dakar" "Africa/Dar_es_Salaam" "Africa/Djibouti" "Africa/Douala" "Africa/El_Aaiun" "Africa/Freetown" "Africa/Gaborone" "Africa/Harare" "Africa/Johannesburg" "Africa/Juba" "Africa/Kampala" "Africa/Khartoum" "Africa/Kigali" "Africa/Kinshasa" "Africa/Lagos" "Africa/Libreville" "Africa/Lome" "Africa/Luanda" "Africa/Lubumbashi" "Africa/Lusaka" "Africa/Malabo" "Africa/Maputo" "Africa/Maseru" "Africa/Mbabane" "Africa/Mogadishu" "Africa/Monrovia" "Africa/Nairobi" "Africa/Ndjamena" "Africa/Niamey" "Africa/Nouakchott" "Africa/Ouagadougou" "Africa/Porto-Novo" "Africa/Sao_Tome" "Africa/Tripoli" "Africa/Tunis" "Africa/Windhoek")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneAmerica {
  local TZONES=("America/Adak" "America/Anchorage" "America/Anguilla" "America/Antigua" "America/Araguaina" "America/Argentina/Buenos_Aires" "America/Argentina/Catamarca" "America/Argentina/Cordoba" "America/Argentina/Jujuy" "America/Argentina/La_Rioja" "America/Argentina/Mendoza" "America/Argentina/Rio_Gallegos" "America/Argentina/Salta" "America/Argentina/San_Juan" "America/Argentina/San_Luis" "America/Argentina/Tucuman" "America/Argentina/Ushuaia" "America/Aruba" "America/Asuncion" "America/Atikokan" "America/Bahia" "America/Bahia_Banderas" "America/Barbados" "America/Belem" "America/Belize" "America/Blanc-Sablon" "America/Boa_Vista" "America/Bogota" "America/Boise" "America/Cambridge_Bay" "America/Campo_Grande" "America/Cancun" "America/Caracas" "America/Cayenne" "America/Cayman" "America/Chicago" "America/Chihuahua" "America/Ciudad_Juarez" "America/Costa_Rica" "America/Coyhaique" "America/Creston" "America/Cuiaba" "America/Curacao" "America/Danmarkshavn" "America/Dawson" "America/Dawson_Creek" "America/Denver" "America/Detroit" "America/Dominica" "America/Edmonton" "America/Eirunepe" "America/El_Salvador" "America/Fort_Nelson" "America/Fortaleza" "America/Glace_Bay" "America/Goose_Bay" "America/Grand_Turk" "America/Grenada" "America/Guadeloupe" "America/Guatemala" "America/Guayaquil" "America/Guyana" "America/Halifax" "America/Havana" "America/Hermosillo" "America/Indiana/Indianapolis" "America/Indiana/Knox" "America/Indiana/Marengo" "America/Indiana/Petersburg" "America/Indiana/Tell_City" "America/Indiana/Vevay" "America/Indiana/Vincennes" "America/Indiana/Winamac" "America/Inuvik" "America/Iqaluit" "America/Jamaica" "America/Juneau" "America/Kentucky/Louisville" "America/Kentucky/Monticello" "America/Kralendijk" "America/La_Paz" "America/Lima" "America/Los_Angeles" "America/Lower_Princes" "America/Maceio" "America/Managua" "America/Manaus" "America/Marigot" "America/Martinique" "America/Matamoros" "America/Mazatlan" "America/Menominee" "America/Merida" "America/Metlakatla" "America/Mexico_City" "America/Miquelon" "America/Moncton" "America/Monterrey" "America/Montevideo" "America/Montserrat" "America/Nassau" "America/New_York" "America/Nome" "America/Noronha" "America/North_Dakota/Beulah" "America/North_Dakota/Center" "America/North_Dakota/New_Salem" "America/Nuuk" "America/Ojinaga" "America/Panama" "America/Paramaribo" "America/Phoenix" "America/Port-au-Prince" "America/Port_of_Spain" "America/Porto_Velho" "America/Puerto_Rico" "America/Punta_Arenas" "America/Rankin_Inlet" "America/Recife" "America/Regina" "America/Resolute" "America/Rio_Branco" "America/Santarem" "America/Santiago" "America/Santo_Domingo" "America/Sao_Paulo" "America/Scoresbysund" "America/Sitka" "America/St_Barthelemy" "America/St_Johns" "America/St_Kitts" "America/St_Lucia" "America/St_Thomas" "America/St_Vincent" "America/Swift_Current" "America/Tegucigalpa" "America/Thule" "America/Tijuana" "America/Toronto" "America/Tortola" "America/Vancouver" "America/Whitehorse" "America/Winnipeg" "America/Yakutat")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneAntartica {
  local TZONES=("Antarctica/Casey" "Antarctica/Davis" "Antarctica/DumontDUrville" "Antarctica/Macquarie" "Antarctica/Mawson" "Antarctica/McMurdo" "Antarctica/Palmer" "Antarctica/Rothera" "Antarctica/Syowa" "Antarctica/Troll" "Antarctica/Vostok")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneArctic {
  local TZONES=("Arctic/Longyearbyen")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneAsia {
  local TZONES=("Asia/Aden" "Asia/Almaty" "Asia/Amman" "Asia/Anadyr" "Asia/Aqtau" "Asia/Aqtobe" "Asia/Ashgabat" "Asia/Atyrau" "Asia/Baghdad" "Asia/Bahrain" "Asia/Baku" "Asia/Bangkok" "Asia/Barnaul" "Asia/Beirut" "Asia/Bishkek" "Asia/Brunei" "Asia/Chita" "Asia/Colombo" "Asia/Damascus" "Asia/Dhaka" "Asia/Dili" "Asia/Dubai" "Asia/Dushanbe" "Asia/Famagusta" "Asia/Gaza" "Asia/Hebron" "Asia/Ho_Chi_Minh" "Asia/Hong_Kong" "Asia/Hovd" "Asia/Irkutsk" "Asia/Jakarta" "Asia/Jayapura" "Asia/Jerusalem" "Asia/Kabul" "Asia/Kamchatka" "Asia/Karachi" "Asia/Kathmandu" "Asia/Khandyga" "Asia/Kolkata" "Asia/Krasnoyarsk" "Asia/Kuala_Lumpur" "Asia/Kuching" "Asia/Kuwait" "Asia/Macau" "Asia/Magadan" "Asia/Makassar" "Asia/Manila" "Asia/Muscat" "Asia/Nicosia" "Asia/Novokuznetsk" "Asia/Novosibirsk" "Asia/Omsk" "Asia/Oral" "Asia/Phnom_Penh" "Asia/Pontianak" "Asia/Pyongyang" "Asia/Qatar" "Asia/Qostanay" "Asia/Qyzylorda" "Asia/Riyadh" "Asia/Sakhalin" "Asia/Samarkand" "Asia/Seoul" "Asia/Shanghai" "Asia/Singapore" "Asia/Srednekolymsk" "Asia/Taipei" "Asia/Tashkent" "Asia/Tbilisi" "Asia/Tehran" "Asia/Thimphu" "Asia/Tokyo" "Asia/Tomsk" "Asia/Ulaanbaatar" "Asia/Urumqi" "Asia/Ust-Nera" "Asia/Vientiane" "Asia/Vladivostok" "Asia/Yakutsk" "Asia/Yangon" "Asia/Yekaterinburg" "Asia/Yerevan")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneAtlantic {
  local TZONES=("Atlantic/Azores" "Atlantic/Bermuda" "Atlantic/Canary" "Atlantic/Cape_Verde" "Atlantic/Faroe" "Atlantic/Madeira" "Atlantic/Reykjavik" "Atlantic/South_Georgia" "Atlantic/St_Helena" "Atlantic/Stanley")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneAustralia {
  local TZONES=("Australia/Adelaide" "Australia/Brisbane" "Australia/Broken_Hill" "Australia/Darwin" "Australia/Eucla" "Australia/Hobart" "Australia/Lindeman" "Australia/Lord_Howe" "Australia/Melbourne" "Australia/Perth" "Australia/Sydney")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneEurope {
  local TZONES=("Europe/Amsterdam" "Europe/Andorra" "Europe/Astrakhan" "Europe/Athens" "Europe/Belgrade" "Europe/Berlin" "Europe/Bratislava" "Europe/Brussels" "Europe/Bucharest" "Europe/Budapest" "Europe/Busingen" "Europe/Chisinau" "Europe/Copenhagen" "Europe/Dublin" "Europe/Gibraltar" "Europe/Guernsey" "Europe/Helsinki" "Europe/Isle_of_Man" "Europe/Istanbul" "Europe/Jersey" "Europe/Kaliningrad" "Europe/Kirov" "Europe/Kyiv" "Europe/Lisbon" "Europe/Ljubljana" "Europe/London" "Europe/Luxembourg" "Europe/Madrid" "Europe/Malta" "Europe/Mariehamn" "Europe/Minsk" "Europe/Monaco" "Europe/Moscow" "Europe/Oslo" "Europe/Paris" "Europe/Podgorica" "Europe/Prague" "Europe/Riga" "Europe/Rome" "Europe/Samara" "Europe/San_Marino" "Europe/Sarajevo" "Europe/Saratov" "Europe/Simferopol" "Europe/Skopje" "Europe/Sofia" "Europe/Stockholm" "Europe/Tallinn" "Europe/Tirane" "Europe/Ulyanovsk" "Europe/Vaduz" "Europe/Vatican" "Europe/Vienna" "Europe/Vilnius" "Europe/Volgograd" "Europe/Warsaw" "Europe/Zagreb" "Europe/Zurich")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneIndian {
  local TZONES=("Indian/Antananarivo" "Indian/Chagos" "Indian/Christmas" "Indian/Cocos" "Indian/Comoro" "Indian/Kerguelen" "Indian/Mahe" "Indian/Maldives" "Indian/Mauritius" "Indian/Mayotte" "Indian/Reunion")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezonePacific {
  local TZONES=("Pacific/Apia" "Pacific/Auckland" "Pacific/Bougainville" "Pacific/Chatham" "Pacific/Chuuk" "Pacific/Easter" "Pacific/Efate" "Pacific/Fakaofo" "Pacific/Fiji" "Pacific/Funafuti" "Pacific/Galapagos" "Pacific/Gambier" "Pacific/Guadalcanal" "Pacific/Guam" "Pacific/Honolulu" "Pacific/Kanton" "Pacific/Kiritimati" "Pacific/Kosrae" "Pacific/Kwajalein" "Pacific/Majuro" "Pacific/Marquesas" "Pacific/Midway" "Pacific/Nauru" "Pacific/Niue" "Pacific/Norfolk" "Pacific/Noumea" "Pacific/Pago_Pago" "Pacific/Palau" "Pacific/Pitcairn" "Pacific/Pohnpei" "Pacific/Port_Moresby" "Pacific/Rarotonga" "Pacific/Saipan" "Pacific/Tahiti" "Pacific/Tarawa" "Pacific/Tongatapu" "Pacific/Wake" "Pacific/Wallis")

  local page=0
  local options=${#TZONES[@]}
  local pages=$((options/10))

  if [[ $((pages%10)) == 0 ]]; then
    ((pages--))
  fi

  while true; do
    echo "Please select a Timezone:"
    if [[ $page == $pages ]] && [[ $((pages%10)) != 0 ]]; then
      for ((n=0; n<$((pages%10)); n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    else
      for ((n=0; n<10; n++)); do
        echo "  ${n}. ${TZONES[$((n+(page*10)))]}"
      done
    fi
    if [[ $page -lt $pages ]]; then
      echo "  N. Next Page"
    fi
    if [[ $page -gt 0 ]]; then
      echo "  P. Previous Page"
    fi
    echo "Enter the digit beside your Timezone or enter the"
    echo "letters N or P for Next Page or Previous Page if"
    echo "available... Or press ENTER to return to the"
    echo "Regions menu."
    read input
    input="${input:0:1}"
    if [[ ${input} =~ ^[0-9]$ ]]; then
      if [[ -z "${TZONES[$((input+(page*10)))]}" ]]; then
        return 1
      else
        PHPTIMEZONE="${TZONES[$((input+(page*10)))]}"
        return 0
      fi
    elif [[ $page -lt $pages ]] && [[ ${input^^} == "N" ]]; then
      ((page++))
    elif [[ $page -gt 0 ]] && [[ ${input^^} == "P" ]]; then
      ((page--))
    else
      return 1
    fi
  done
}

function doTimezoneRegions {
  result=1
  while [[ $result == 1 ]]; do
    echo "Please select a Region:"
    echo "  0. AFRICA"
    echo "  1. AMERICAS"
    echo "  2. ANTARTICA"
    echo "  3. ARCTIC CIRCLE"
    echo "  4. ASIA"
    echo "  5. ATLANTIC OCEAN"
    echo "  6. AUSTRALIA"
    echo "  7. EUROPE"
    echo "  8. INDIAN OCEAN"
    echo "  9. PACIFIC OCEAN"
    echo "Enter the digit beside the Region for your Timezone..."
    echo "Or press ENTER to quit the install. You can restart"
    echo "later and the Installer will continue from this step."
    read input
    input="${input:0:1}"
    if [[ ${input} == "0" ]]; then
      doTimezoneAfrica
      result=$?
    elif [[ ${input} == "1" ]]; then
      doTimezoneAmerica
      result=$?
    elif [[ ${input} == "2" ]]; then
      doTimezoneAntartica
      result=$?
    elif [[ ${input} == "3" ]]; then
      doTimezoneArctic
      result=$?
    elif [[ ${input} == "4" ]]; then
      doTimezoneAsia
      result=$?
    elif [[ ${input} == "5" ]]; then
      doTimezoneAtlantic
      result=$?
    elif [[ ${input} == "6" ]]; then
      doTimezoneAustralia
      result=$?
    elif [[ ${input} == "7" ]]; then
      doTimezoneEurope
      result=$?
    elif [[ ${input} == "8" ]]; then
      doTimezoneIndian
      result=$?
    elif [[ ${input} == "9" ]]; then
      doTimezonePacific
      result=$?
    else
      exit
    fi
  done
}

function doTURN {
  echo "###############################" >> /etc/turnserver.conf
  echo "# Custom Config for Nextcloud #" >> /etc/turnserver.conf
  echo "###############################" >> /etc/turnserver.conf
  echo "listening-port=3478" >> /etc/turnserver.conf
  echo "tls-listening-port=5349" >> /etc/turnserver.conf
  echo "alt-listening-port=0" >> /etc/turnserver.conf
  echo "alt-tls-listening-port=0" >> /etc/turnserver.conf
  echo "min-port=60000" >> /etc/turnserver.conf
  echo "max-port=61999" >> /etc/turnserver.conf
  echo "fingerprint" >> /etc/turnserver.conf
  echo "use-auth-secret" >> /etc/turnserver.conf
  echo "static-auth-secret=$TURNPASS" >> /etc/turnserver.conf
  echo "realm=$FQDN" >> /etc/turnserver.conf
  echo "total-quota=0" >> /etc/turnserver.conf
  echo "bps-capacity=0" >> /etc/turnserver.conf
  echo "no-multicast-peers" >> /etc/turnserver.conf
  systemctl restart coturn.service > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "coTURN failed to restart with new settings..."
}

function doVHost {
  if [[ -f /etc/apache2/sites-available/${NCWWW}.conf ]]; then
    echo "VHost file already exists..."
    echo -n "Press ENTER to view it or type GO to replace it... "
    read input
    input=${input:0:2}
    if [[ ${input^^} != "GO" ]]; then
      echo "------"
      cat /etc/apache2/sites-available/${NCWWW}.conf
      echo "------"
      echo "Press ENTER to exit and edit the settings.conf file,"
      echo -n "or type GO to replace the above file... "
      read input
      input=${input:0:2}
      if [[ ${input^^} != "GO" ]]; then
        echo "You can edit the settings.conf file and change the"
        echo "value for NCWWW then restart the install. It will"
        echo "continue from this step..."
        exit 0
      fi
    fi
    rm -f /etc/apache2/sites-available/${NCWWW}.conf
  fi
  touch /etc/apache2/sites-available/${NCWWW}.conf
  echo "<VirtualHost *:80>" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	ServerName $FQDN" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	ServerAdmin $EMAIL" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	DocumentRoot /var/www/${NCWWW}/" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	ErrorLog ${APACHE_LOG_DIR}/error.log" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	CustomLog ${APACHE_LOG_DIR}/access.log combined" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	<Directory /var/www/${NCWWW}/>" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "		Require all granted" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "		AllowOverride All" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "		Options FollowSymLinks MultiViews" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "		<IfModule mod_dav.c>" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "			Dav off" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "		</IfModule>" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "	</Directory>" >> /etc/apache2/sites-available/${NCWWW}.conf
  echo "</VirtualHost>" >> /etc/apache2/sites-available/${NCWWW}.conf
  mkdir "/var/${NCFILES}"
  chown -R www-data:www-data "/var/${NCFILES}"
  mkdir "/var/www/${NCWWW}"
  chown -R www-data:www-data "/var/www/${NCWWW}"
  a2ensite ${NCWWW}.conf > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable VHost..."
  a2enmod rewrite > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable the rewrite module..."
  a2enmod headers > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable the headers module..."
  a2enmod env > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable the env module..."
  a2enmod dir > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable the dir module..."
  a2enmod mime > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to enable the mime module..."
  systemctl restart apache2 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to restart..."
  cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.original || failMsg "Failed to backup apache2.conf..."
  linenum=$(cat /etc/apache2/apache2.conf | grep -n '<Directory /var/www/>' | cut -d: -f1)
  until sed -n "${linenum}p" /etc/apache2/apache2.conf | grep "AllowOverride"> /dev/null; do
    ((linenum++))
  done
  sed -i "${linenum}s/\bNone\b/All/" /etc/apache2/apache2.conf
  systemctl restart apache2 > /dev/null 2>> "$oldpath/installer-errors.log"  || failMsg "Failed to restart Apache2..."
}

function downloadUpdate {
  if [[ -z "$SELF_UPDATED" ]]; then
      TMPFILE=$(mktemp)
      echo "Downloading updated script..."
      curl -sSL "https://raw.githubusercontent.com/Robson-Rissato/nextcloud-installer/refs/heads/main/debian-installer.sh" -o "$TMPFILE" || {
          echo "Download failed... Continuing with current version..." >&2
          return
      }
      chmod +x "$TMPFILE"
      echo "Launching updated version..."
      exec env SELF_UPDATED=1 ORIGINALSCRIPT="$(readlink -f "$0")" ORIGINALVERSION="$VERSION" "$TMPFILE" "$@"
  fi
  SCRIPT="$ORIGINALSCRIPT"
  BACKUP="${SCRIPT%.sh}.${ORIGINALVERSION}.sh"
  echo "Creating backup of original script at $BACKUP"
  cp "$SCRIPT" "$BACKUP" || echo "Backup failed..." >&2
  echo "Overwriting $SCRIPT with updated version..."
  cp "$0" "$ORIGINALSCRIPT" || echo "Overwrite failed..." >&2
  echo "Script updated successfully. Continuing execution..."
  sleep 2s
}

function failMsg {
  echo "ERROR: $1" >&2
  echo "ERROR: $1 [showTimer $SECONDS]" >> "$oldpath/installer-errors.log"
  echo $((SECONDS+runtime)) > $oldpath/runtime.temp
  exit 1
}

function genPass {
  if [[ -z $1 ]] || [[ $1 == "" ]]; then
    failMsg "Function passGen requires an integer between 12 and 64"
  fi
  local LAST3CHAR=(- - -)
  local LAST3SET=(9 9 9)
  local LCHARSET=(x y z a b c d e f g h i j k l m n o p q r s t u v w x y z a b c)
  local NCHARSET=(7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2)
  local STRING=""
  local UCHARSET=(X Y Z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z A B C)
  local i
  local n
  local newset
  local safe
  if [[ $1 -ge 8 ]] && [[ $1 -le 64 ]]; then
    for ((n=0; n<$1; n++)); do
      safe=false
      while [[ $safe == false ]]; do
        newset=$((RANDOM%3))
        if [[ $newset != ${LAST3SET[0]} ]] || [[ $newset != ${LAST3SET[1]} ]] || [[ $newset != ${LAST3SET[2]} ]]; then
          LAST3SET[2]=${LAST3SET[1]}
          LAST3SET[1]=${LAST3SET[0]}
          LAST3SET[0]=$newset
          safe=true
        fi
      done
      safe=false
      while [[ $safe == false ]]; do
        if [[ $newset == 2 ]]; then
          i=$(((RANDOM%10)+3))
          if [[ ${NCHARSET[$i]} != ${LAST3CHAR[0]} ]] && [[ ${NCHARSET[$i]} != ${LAST3CHAR[1]} ]] && [[ ${NCHARSET[$i]} != ${LAST3CHAR[2]} ]] && [[ ${NCHARSET[$((i-1))]} != ${LAST3CHAR[0]} ]] && [[ ${NCHARSET[$((i+1))]} != ${LAST3CHAR[0]} ]]; then
            LAST3CHAR[2]=${LAST3CHAR[1]}
            LAST3CHAR[1]=${LAST3CHAR[0]}
            LAST3CHAR[0]=${NCHARSET[$i]}
            STRING="${STRING}${NCHARSET[$i]}"
            safe=true
          fi
        else
          i=$(((RANDOM%26)+3))
          if [[ ${UCHARSET[$i]} != ${LAST3CHAR[0]} ]] && [[ ${UCHARSET[$i]} != ${LAST3CHAR[1]} ]] && [[ ${UCHARSET[$i]} != ${LAST3CHAR[2]} ]] && [[ ${UCHARSET[$((i-1))]} != ${LAST3CHAR[0]} ]] && [[ ${UCHARSET[$((i+1))]} != ${LAST3CHAR[0]} ]] && [[ ${LCHARSET[$i]} != ${LAST3CHAR[0]} ]] && [[ ${LCHARSET[$i]} != ${LAST3CHAR[1]} ]] && [[ ${LCHARSET[$i]} != ${LAST3CHAR[2]} ]] && [[ ${LCHARSET[$((i-1))]} != ${LAST3CHAR[0]} ]] && [[ ${LCHARSET[$((i+1))]} != ${LAST3CHAR[0]} ]]; then
            LAST3CHAR[2]=${LAST3CHAR[1]}
            LAST3CHAR[1]=${LAST3CHAR[0]}
            if [[ $newset == 1 ]]; then
              LAST3CHAR[0]=${LCHARSET[$i]}
              STRING="${STRING}${LCHARSET[$i]}"
            else
              LAST3CHAR[0]=${UCHARSET[$i]}
              STRING="${STRING}${UCHARSET[$i]}"
            fi
            safe=true
          fi
        fi
      done
    done
    echo -n $STRING
  else
    failMsg "Function passGen requires an integer between 12 and 64"
  fi
}

function showTimer {
  printf "%02d:%02d:%02d\n" $((${1}/3600)) $((${1}%3600/60)) $((${1}%60))
}

declare DBHOST
declare DBNAME
declare DBPASS
declare DBROOTPASS
declare DBUSER
declare EMAIL
declare FQDN
declare NCADMIN
declare NCFILES
declare NCPASS
declare NCWWW
declare PHPTIMEZONE
declare TURNPASS

eval $(grep '^PRETTY_NAME=' /etc/os-release)
eval $(grep '^ID=' /etc/os-release)
eval $(grep '^VERSION_ID=' /etc/os-release)
eval $(grep '^NAME=' /etc/os-release)
NAME_AND_VERSION="$NAME $VERSION_ID"

TESTED_ON=("Debian GNU/Linux 13" "Ubuntu 24.04")

TESTED=false

for ((n=0; n<${#TESTED_ON[@]}; n++)); do
  if [[ "${TESTED_ON[$n]}" == "$NAME_AND_VERSION" ]]; then
    TESTED=true
    n=${#TESTED_ON[@]}
  fi
done

if [[ "$TESTED" == false ]]; then
  echo "Your installed distro is $PRETTY_NAME"
  echo
  echo "This installer script has only been tested on:"
  for ((n=0; n<${#TESTED_ON[@]}; n++)); do
    echo "   ${TESTED_ON[$n]}"
  done
  echo "but it should work on any Debian or Ubuntu based distro."
  echo
  echo "Any distro that is not Debian or Ubuntu based may result in"
  echo "a complete failure of the installation process."
  echo
  echo "Press ENTER to continue or CTRL+C to exit..."
  read input
  echo
fi

echo "Welcome to the Nextcloud Installer Script version $INSTALLERVERSION"
echo
echo "This script is FREE software and is licensed under the GPL 3.0 or later license."
echo "If you want to view the license, you can read it by visiting the associated GitHub"
echo "repo at https://github.com/Robson-Rissato/nextcloud-installer"
echo

if [[ ! -f settings.conf ]]; then
  CPUCOUNT=$(cat /proc/cpuinfo | grep "^processor" | wc -l)
  temp=($(cat /proc/meminfo | grep "^MemTotal"))
  temp=${temp[1]}
  SYSTEMRAM=$((temp/1000000))
  echo "Detected CPUs : $CPUCOUNT (Recommended 4 or more)"
  echo " Detected RAM : $SYSTEMRAM GB (Recommended 8 GB or more)"
  echo
  if [[ $CPUCOUNT -lt 4 ]] || [[ $SYSTEMRAM -lt 8 ]]; then
    echo "You do not meet the minimum recommended values for CPUs and RAM."
    echo "You can still install Nextcloud but performance will be poor."
    echo
  fi
  echo "What is the fully qualified domain name for this installation?"
  echo -n "(excluding http:// or https://) "
  read FQDN
  echo "What is the email address you want to use for SSL Certificate notifications"
  echo -n "and the admin user account? "
  read EMAIL
  doTimezoneRegions
  echo "Do you want to install AutoSWAP? This is a background systemd service,"
  echo "that automatically adds SWAP memory when your server is under load, and"
  echo "then automatically removes unneeded SWAP memory when your server is idle."
  echo "Can be useful if your server has some extra busy times with a lot of http"
  echo "hits. Visit:"
  echo "https://github.com/Robson-Rissato/autoswap"
  echo -n "for more info. Press ENTER for Yes or type NO for No. "
  read input
  input=${input:0:1}
  if [[ ${input^^} == "N" ]]; then
    AUTOSWAP="false"
  else
    AUTOSWAP="true"
  fi
  echo "Writing settings.conf file..."
  touch settings.conf
  echo "DBHOST=\"localhost\"" >> settings.conf
  echo "DBNAME=\"nextcloud\"" >> settings.conf
  echo "DBPASS=\"$(genPass 24)\"" >> settings.conf
  echo "DBROOTPASS=\"$(genPass 32)\"" >> settings.conf
  echo "DBUSER=\"nextcloud\"" >> settings.conf
  echo "EMAIL=\"$EMAIL\"" >> settings.conf
  echo "FQDN=\"$FQDN\"" >> settings.conf
  echo "NCADMIN=\"ncadmin\"" >> settings.conf
  echo "NCFILES=\"nextcloudfiles\"" >> settings.conf
  echo "NCPASS=\"$(genPass 24)\"" >> settings.conf
  echo "NCWWW=\"nextcloud\"" >> settings.conf
  echo "TURNPASS=\"$(genPass 64)\"" >> settings.conf
  echo "PHPTIMEZONE=\"$PHPTIMEZONE\"" >> settings.conf
  echo "AUTOSWAP=\"$AUTOSWAP\"" >> settings.conf
else
  echo "File settings.conf already exists..."
  echo
fi

source settings.conf

echo "Going to install with the following settings..."
echo "       Domain Name : https://$FQDN"
echo "     Database Name : $DBNAME"
echo "     Database User : $DBUSER"
echo "     Database Pass : $DBPASS"
echo "     Database Host : $DBHOST"
echo "   MySQL Root Pass : $DBROOTPASS"
echo "    Admin Username : $NCADMIN"
echo "    Admin Password : $NCPASS"
echo "       Admin Email : $EMAIL"
echo " Webroot Directory : /var/www/$NCWWW"
echo "NC Files Directory : /var/$NCFILES"
echo "TURN Server Secret : $TURNPASS"
echo "      PHP Timezone : $PHPTIMEZONE"
echo "  Install AutoSWAP : $AUTOSWAP"
echo
echo "If you want to customize any of the above settings, then"
echo "press CTRL+C to exit, then edit the file settings.conf"
echo "and restart this installer script. Alternatively, press"
echo "ENTER to continue..."
read input

if [[ -f runtime.temp ]]; then
  runtime=$(head -1 runtime.temp)
else
  runtime=0
fi

if [[ ! -f position.temp ]]; then
  echo "1" > position.temp
else
  echo
  echo "This script did not complete the installation in a prior attempt."
  echo "We will pickup from where it left off..."
  echo
  echo "Previous runs account for $(showTimer $runtime) of runtime..."
  echo
fi

echo
echo "Starting the timer!"
SECONDS=0
echo
decho "[Step 1] Updating system... [Current Runtime: $(showTimer $SECONDS)]"
apt-get update > /dev/null 2>> "$oldpath/installer-errors.log" && apt-get -y upgrade > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to update the system..."

p=$(head -1 position.temp)

if [[ $p -lt 2 ]]; then
  decho "[Step $((p+1))] Installing tools needed to complete the installation... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y install wget mc htop curl rsync screen wget sudo unzip jq cron nano gnupg2 lsb-release ca-certificates > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install dependancies..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 3 ]]; then
  if [[ $SELF_UPDATED != 1 ]]; then
    decho "[Step $((p+1))] Checking if there is a newer version of this installer script... [Current Runtime: $(showTimer $SECONDS)]"
    NEWVERSION=$(curl -sSL "https://raw.githubusercontent.com/Robson-Rissato/nextcloud-installer/refs/heads/main/version")
    if [[ ! "$NEWVERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
      echo "Remote version could not be retrieved." >&2
      NEWVERSION="$INSTALLERVERSION"
    fi
  else
    decho "[Step $((p+1))] Already downloaded the latest version of this installer script... [Current Runtime: $(showTimer $SECONDS)]"
    NEWVERSION="$INSTALLERVERSION"
  fi
  if compareVersions "$INSTALLERVERSION" "$NEWVERSION" || [[ $SELF_UPDATED == 1 ]]; then
    downloadUpdate
  fi
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 4 ]]; then
  decho "[Step $((p+1))] Installing Apache2 and Certbot for Let's Encrypt... [Current Runtime: $(showTimer $SECONDS)]"
  if [[ $ID == "ubuntu" ]]; then
    decho "You are running Ubuntu so we must add Sury Apache2 Repo..."
    LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/apache2 || failMsg "Sury Apache2 Repo failed to add to Ubuntu..."
  fi
  apt-get -y install apache2 certbot python3-certbot-apache > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install Apache2 and Certbot..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 5 ]]; then
  decho "[Step $((p+1))] Skipping HTTP and HTTPS... [Current Runtime: $(showTimer $SECONDS)]"
# ::::::::::::
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 6 ]]; then
  decho "[Step $((p+1))] Configuring Apache2 and VHost file... [Current Runtime: $(showTimer $SECONDS)]"
  doVHost || failMsg "Apache2 failed to configure..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 7 ]]; then
  decho "[Step $((p+1))] Skipping FQDN Resolution... [Current Runtime: $(showTimer $SECONDS)]"
  # ::::::::::::
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 8 ]]; then
  decho "[Step $((p+1))] Requesting SSL Certicate from Let's Encrypt... [Current Runtime: $(showTimer $SECONDS)]"
  certbot -n -m $EMAIL --agree-tos --apache -d $FQDN > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Certbot failed to get an SSL Certicate from Let's Encrypt..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 9 ]]; then
  if [[ "$DBHOST" == "localhost" ]]; then
    decho "[Step $((p+1))] Installing MariaDB (MySQL)... [Current Runtime: $(showTimer $SECONDS)]"
    apt-get -y install mariadb-server mariadb-client > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install MariaDB..."
  else
    decho "[Step $((p+1))] Skipping of installing MariaDB (MySQL)... [Current Runtime: $(showTimer $SECONDS)]"
    pausetimer=$SECONDS
    echo "Pausing the timer at $(showTimer $pausetimer)..."
    echo
    echo "You have defined an external (remote) server for MariaDB/MySQL."
    echo "Please ensure that the MariaDB/MySQL remote server at $DBHOST"
    echo "is configured with the following settings:"
    echo "  Remote Server Host : $DBHOST"
    echo "  Database Name      : $DBNAME"
    echo "  Database Username  : $DBUSER"
    echo "  Database Password  : $DBPASS"
    echo "Type GO to continue or press ENTER to stop this installation."
    echo "You can restart it later and it will continue from this step."
    read input
    input=${input:0:2}
    if [[ ${input^^} != "GO" ]]; then
      echo $((runtime+pausetimer)) > runtime.temp
      exit 0
    fi
    echo
    echo "Unpausing the timer..."
    SECONDS=$pausetimer
    echo
  fi
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 10 ]]; then
  if [[ "$DBHOST" == "localhost" ]]; then
    decho "[Step $((p+1))] Securing MariaDB (MySQL)... [Current Runtime: $(showTimer $SECONDS)]"
    doMariaDB || failMsg "Securing MariaDB failed..."
  else
    decho "[Step $((p+1))] Skipping securing of local MySQL... [Current Runtime: $(showTimer $SECONDS)]"
  fi
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 11 ]]; then
  if [[ "$DBHOST" == "localhost" ]]; then
    decho "[Step $((p+1))] Creating MySQL database for Nextcloud... [Current Runtime: $(showTimer $SECONDS)]"
    echo "CREATE DATABASE $DBNAME; CREATE USER $DBUSER@localhost IDENTIFIED BY '$DBPASS'; GRANT ALL PRIVILEGES ON $DBNAME.* TO $DBUSER@localhost; FLUSH PRIVILEGES;" | mysql > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "MariaDB failed to setup database for Nextcloud..."
  else
    decho "[Step $((p+1))] Skipping creation of local MySQL database... [Current Runtime: $(showTimer $SECONDS)]"
  fi
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 12 ]]; then
  decho "[Step $((p+1))] Skipping Sury PHP Repo setup — Debian 13/Ubuntu 24.04 already include latest PHP versions. [Current Runtime: $(showTimer $SECONDS)]"
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 13 ]]; then
  decho "[Step $((p+1))] Installing PHP8.4-FPM and CLI with all recommended extensions... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y install php8.4-{ctype,curl,dom,gd,common,mysql,mbstring,opcache,posix,simplexml,xmlreader,xmlwriter,xmlrpc,xml,cli,zip,bz2,fpm,intl,ldap,smbclient,ftp,bcmath,gmp,exif,apcu,memcached,redis,imagick} libapache2-mod-php8.4 libapache2-mod-fcgid libxml2 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install PHP..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 14 ]]; then
  decho "[Step $((p+1))] Creating custom PHP config specific for Nextcloud... [Current Runtime: $(showTimer $SECONDS)]"
  doPHP || failMsg "Custom PHP config failed..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 15 ]]; then
  decho "[Step $((p+1))] Installing coTURN server for Nextcloud Talk... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y install coturn > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to Install coTURN..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 16 ]]; then
  decho "[Step $((p+1))] Configuring coTURN server for Nextcloud Talk... [Current Runtime: $(showTimer $SECONDS)]"
  doTURN || failMsg "Failed to configure coTURN..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 17 ]]; then
  decho "[Step $((p+1))] Installing Redis and Memcache Server... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y install redis-server memcached > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to Install Redis and Memcache Server..."
  systemctl start redis-server > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to start Redis Server..."
  systemctl enable redis-server > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to enable Redis Server..."
  systemctl start memcached > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to start Memcache Server..."
  systemctl enable memcached > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to enable Memcache Server..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 18 ]]; then
  decho "[Step $((p+1))] Installing SVG support for ImageMagick... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y install librsvg2-bin imagemagick > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install librsvg2-bin..."
  sed -i 's|</policymap>|  <policy domain="coder" rights="none" pattern="SVG" />\n</policymap>|' /etc/ImageMagick-7/policy.xml
  apt-get -y install libmagickcore-7.q16hdri-10-extra > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "apt failed to install libmagickcore extras..."
  systemctl restart apache2 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Apache2 failed to restart..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 19 ]]; then
  if [[ $AUTOSWAP = "true" ]]; then
    decho "[Step $((p+1))] Installing SWAP memory management tool... [Current Runtime: $(showTimer $SECONDS)]"
    doSWAP || failMsg "SWAP memory management tool failed to install..."
  else
    decho "[Step $((p+1))] Not installing SWAP memory management tool... [Current Runtime: $(showTimer $SECONDS)]"
  fi
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 20 ]]; then
  decho "[Step $((p+1))] Downloading and unpacking latest version of Nextcloud... [Current Runtime: $(showTimer $SECONDS)]"
  wget "https://download.nextcloud.com/server/releases/latest.zip" || failMsg "Nextcloud failed to download..."
  mkdir nextcloud
  unzip latest.zip -d ./nextcloud > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to unpack..."
  mv ./nextcloud/nextcloud/* "/var/www/$NCWWW/"
  mv ./nextcloud/nextcloud/.* "/var/www/$NCWWW/"
  chown -R www-data:www-data "/var/www/$NCWWW"
  rm -R ./nextcloud
  rm -R latest.zip
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 21 ]]; then
  decho "[Step $((p+1))] Installing Nextcloud... this could take a while... [Current Runtime: $(showTimer $SECONDS)]"
  oldpath=$(pwd)
  cd "/var/www/$NCWWW"
  sudo -u www-data php occ maintenance:install --database="mysql" --database-host="$DBHOST" --database-name="$DBNAME" --database-user="$DBUSER" --database-pass="$DBPASS" --admin-user="$NCADMIN" --admin-pass="$NCPASS" --data-dir="/var/$NCFILES" > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to install..."
  sudo -u www-data php occ user:enable $NCADMIN > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to enable user $NCADMIN..."
  sudo -u www-data php occ user:setting $NCADMIN settings email $EMAIL > /dev/null 2>> "$oldpath/installer-errors.log" || "Nextcloud failed to set email address $EMAIL for user $NCADMIN..."
  cd config
  if [[ ! -f config.original ]]; then
    cp config.php config.original
  fi
  cd ..
  sudo -u www-data php occ config:system:set trusted_domains 0 --value=$FQDN > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set $FQDN trusted domain..."
  sudo -u www-data php occ config:system:set trusted_domains 1 --value=localhost > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set localhost as trusted domain..."
  sudo -u www-data php occ config:system:set overwrite.cli.url --type=string --value=https://$FQDN > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set overwrite.cli.url..."
  sudo -u www-data php occ config:system:set maintenance_window_start --type=integer --value=1 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set maintenance window..."
  ( crontab -u www-data -l 2>/dev/null; echo '*/5 * * * * php -f /var/www/nextcloud/cron.php' ) | crontab -u www-data - || failMsg "Failed to setup crontab..."
  sudo -u www-data php occ background:cron > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to activate cron for background jobs..."
  sudo -u www-data php occ config:system:set debug --type=boolean --value=false > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set debug to false..."
  sed -i '3a<IfModule mod_headers.c>\nHeader always set Strict-Transport-Security "max-age=15552000; includeSubDomains"\n</IfModule>' /etc/apache2/sites-available/${NCWWW}-le-ssl.conf > /dev/null 2>> "$oldpath/installer-errors.log" && systemctl reload apache2 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Failed to set Strict-Transport-Security in /etc/apache2/sites-available/${NCWWW}-le-ssl.conf..."
  sudo -u www-data php occ config:system:set memcache.local --type=string --value="\OC\Memcache\APCu" > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set local memcache..."
  sudo -u www-data php occ config:system:set memcache.distributed --type=string --value="\OC\Memcache\Redis" > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set distributed memcache..."
  sudo -u www-data php occ config:system:set memcache.locking --type=string --value="\OC\Memcache\Redis" > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set locking memcache..."
  sudo -u www-data php occ config:system:set redis host --type=string --value=localhost > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set Redis host..."
  sudo -u www-data php occ config:system:set redis port --type=integer --value=6379 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set Redis port..."
  sudo -u www-data php occ config:system:set redis timeout --type=float --value=0.0 > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed to set Redis Timeout..."
  echo "Running a full install check and repair..."
  sudo -u www-data php occ maintenance:repair --include-expensive > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "Nextcloud failed configuration of Mimetypes..."

  ##### STILL TO BE ADDED #####
  #sudo -u www-data php occ config:system:set default_phone_region --type=string --value=CC
  #sudo -u www-data php occ config:system:set default_language --type=string --value=lc_CC
  #sudo -u www-data php occ config:system:set default_locale --type=string --value=lc_CC
  #############################
  ### https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2#Officially_assigned_code_elements
  #############################

  echo -e '#!/bin/bash\n\ncd /var/www/nextcloud\nsudo -u www-data php occ $@' > /usr/bin/occ && chmod +x /usr/bin/occ || failMsg "Failed to create /usr/bin/occ..."

  cd "$oldpath"
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 22 ]]; then
  decho "[Step $((p+1))] Removing any redundant packages... [Current Runtime: $(showTimer $SECONDS)]"
  apt-get -y autoremove > /dev/null 2>> "$oldpath/installer-errors.log" || failMsg "APT failed to remove redundant packages..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 23 ]]; then
  decho "[Step $((p+1))] Restarting all affected services just for good measure... [Current Runtime: $(showTimer $SECONDS)]"
  echo -n "Memcached..." && systemctl restart memcached.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "Memcached failed to restart..."
  echo -n "Redis Server..." && systemctl restart redis-server.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "Redis Server failed to restart..."
  echo -n "CoTURN..." && systemctl restart coturn.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "CoTurn failed to restart..."
  echo -n "MariaDB..." && systemctl restart mariadb.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "MariaDB failed to restart..."
  echo -n "PHP-FPM..." && systemctl restart php8.4-fpm.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "PHP-FPM failed to restart..."
  echo -n "Apache2..." && systemctl restart apache2.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "Apache2 failed to restart..."
  echo -n "Cron..." && systemctl restart cron.service > /dev/null 2>> "$oldpath/installer-errors.log" && echo "Success!" || failMsg "Cron failed to restart..."
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 24 ]]; then
  decho "[Step $((p+1))] Configuring Linux timezone... [Current Runtime: $(showTimer $SECONDS)]" 
  if [[ -z "$PHPTIMEZONE" ]]; then
    failMsg "PHPTIMEZONE is not set!"
  fi
  echo -n "Setting system timezone to $PHPTIMEZONE..."
  timedatectl set-timezone "$PHPTIMEZONE" > /dev/null 2>> "$oldpath/installer-errors.log" \
    && echo "Success!" \
    || failMsg "Failed to set system timezone!"
  ((p++))
  echo "$p" > position.temp
fi

if [[ $p -lt 25 ]]; then
  decho "[Step $((p+1))] Writing the Installation Report and cleaning up... [Current Runtime: $(showTimer $SECONDS)]"
  doREPORT
  cp NEXTCLOUD-REPORT*.md /var/${NCFILES}/${NCADMIN}/files/
  occ files:scan --all
  mkdir /etc/nextcloud-installer
  echo "# THIS FILE WAS CREATED BY THE NEXTCLOUD-INSTALLER SCRIPT" > /etc/nextcloud-installer/settings.conf
  echo "# DO NOT EDIT OR DELETE THIS FILE AS IT IS NEED FOR WHEN YOU WANT TO USE A" >> /etc/nextcloud-installer/settings.conf
  echo "# FUTURE VERSION OF THE SCRIPT TO UPDATE THE SYSTEM TO MEET THE DEMANDS OF A" >> /etc/nextcloud-installer/settings.conf
  echo "# FUTURE VERSION OF NEXTCLOUD..." >> /etc/nextcloud-installer/settings.conf
  echo "LASTINSTALLERVERSION=$INSTALLERVERSION" >> /etc/nextcloud-installer/settings.conf
  cat settings.conf >> /etc/nextcloud-installer/settings.conf
  rm -f position.temp
  rm -f settings.conf
  rm -f runtime.temp
  mv "$oldpath/installer-errors.log" /etc/nextcloud-installer/installer-errors.$INSTALLERVERSION.log
  echo
  echo
  echo
  echo "CONGRATULATIONS!!!"
  echo
  echo "Total Runtime was $(showTimer $((runtime+SECONDS)))"
  echo
  echo "You can now point your browser to https://$FQDN and start using Nextcloud..."
  echo
  echo "Username: $NCADMIN"
  echo "Password: $NCPASS"
  echo
  echo "First attempt to login will give a session expired error. Second attempt will be"
  echo "successful. Administration settings page may give an error about the Cron. Wait"
  echo "five minutes, it only runs once every five minutes so give it some time and the"
  echo "error will go away..."
  echo
  echo "A copy of the report has been copied to $NCADMIN's Files app for safe keeping."
  echo
fi
