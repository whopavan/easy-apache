terminalColors () {
	# Colors from - https://gist.github.com/5682077.git
	TC='\e['

	CLR_LINE_START="${TC}1K"
	CLR_LINE_END="${TC}K"
	CLR_LINE="${TC}2K"

	# Hope no terminal is greater than 1k columns
	RESET_LINE="${CLR_LINE}${TC}1000D"

	Bold="${TC}1m"    # Bold text only, keep colors
	Undr="${TC}4m"    # Underline text only, keep colors
	Inv="${TC}7m"     # Inverse: swap background and foreground colors
	Reg="${TC}22;24m" # Regular text only, keep colors
	RegF="${TC}39m"   # Regular foreground coloring
	RegB="${TC}49m"   # Regular background coloring
	Rst="${TC}0m"     # Reset all coloring and style

	# Basic            High Intensity      Background           High Intensity Background
	Black="${TC}30m";  IBlack="${TC}90m";  OnBlack="${TC}40m";  OnIBlack="${TC}100m";
	Red="${TC}31m";    IRed="${TC}91m";    OnRed="${TC}41m";    OnIRed="${TC}101m";
	Green="${TC}32m";  IGreen="${TC}92m";  OnGreen="${TC}42m";  OnIGreen="${TC}102m";
	Yellow="${TC}33m"; IYellow="${TC}93m"; OnYellow="${TC}43m"; OnIYellow="${TC}103m";
	Blue="${TC}34m";   IBlue="${TC}94m";   OnBlue="${TC}44m";   OnIBlue="${TC}104m";
	Purple="${TC}35m"; IPurple="${TC}95m"; OnPurple="${TC}45m"; OnIPurple="${TC}105m";
	Cyan="${TC}36m";   ICyan="${TC}96m";   OnCyan="${TC}46m";   OnICyan="${TC}106m";
	White="${TC}37m";  IWhite="${TC}97m";  OnWhite="${TC}47m";  OnIWhite="${TC}107m";
}

help () {
	echo -e "${Bold}Usage:${Rst}\neasy-apache.sh [options]\n\n${Bold}Options:${Rst}\n-f:\tFull setup, default option if none is provided\n-a:\tAdding new site (includes apache install)\n-s:\tInstall SSL certificate for sites available\n-h:\tHelp (shows available commands)${Rst}"
	echo -e "\n${Bold}Example\n${Rst}easy-apache.sh -f\t#for full installation i.e Apache & SSL certificate\neasy-apache.sh -a\t#for installating Apache server\neasy-apache.sh -s\t#for installating SSL certificate"
}

apacheInstall () {
	echo -e "${Bold}${Green}Installing Apache${Rst}"
	allSitesURL=""
	allSitesCount=-1

	echo -e "Updating Server"
	sudo apt update && sudo apt upgrade -y
	echo -e "Server updated"

	echo -e "Cleaning after upgrade"
	sudo apt autoremove -y && sudo apt autoclean -y

	IP=`curl -s icanhazip.com`
	echo -e "Server Public IP: ${Purple}"${IP}${Rst}

	dpkg -s apache2 &> /dev/null
	if [ $? -eq 1 ]; then
		echo -e "Installing Apache 2"
		sudo apt install apache2 -y
		echo -e ${Purple}Apache `apache2 -v`"${Rst}"
	fi

	while true
	do
		echo -e "${Green}===>${Rst} Setting up new site"
		echo -e "99 to exit"
		read -p "URL (do not add www, eg input - helloworld.com): " siteURL

		if [ $siteURL == 99 ]
		then
			if [ $allSitesCount == -1 ]
			then
				echo "Good byee..."
				exit
			fi
			break
		fi

		if [ -e /etc/apache2/sites-available/$siteURL.conf ]
		then
			echo -e "${Red}$siteURL already exists, do you want to overwrite (Yy/Nn/99 to exit setup)?${Rst}"
			read overwriteSite
			case $overwriteSite in
				[Yy]* ) #allSitesURL used for printing at last
						allSitesCount=`expr $allSitesCount + 1`
						allSitesURL[$allSitesCount]=$siteURL
						addSite $siteURL
						break;;
				[Nn]* ) continue;;
				[99]*  ) break;;
					* ) echo -e "${Red}Invalid input. Skipping $siteURL setup"
						continue;;
			esac
		else
			#allSitesURL used for printing at last
			allSitesCount=`expr $allSitesCount + 1`
			allSitesURL[$allSitesCount]=$siteURL
			addSite $siteURL
			break
		fi
	done

	if [ $allSitesCount == -1 ]
	then
		echo -e "${Red}Exiting easy-apache. No Sites were added${Rst}"
		exit
	fi

	echo -e "Checking UFW"
	if sudo ufw status | grep -q inactive$
	then
		echo -e "${Red}UFW is disabled. You need to enable it to continue...${Rst}"
		
		while true
		do
			read -p "Do you want to enable now (Yy/Nn)? " ufwEnable
			case $ufwEnable in
				[Yy]* ) sudo ufw enable;
						echo -e "UFW enabled. Allowing SSH & Apache ports"
						sudo ufw allow ssh;
						sudo ufw allow Apache;
						break;;
				[Nn]* ) echo -e "${Red}You cannot view the site until you enable ufw and allow SSH & Apache${Rst}"; break;;
					* ) echo -e "Please answer yes(Yy) or no(Nn) ";;
			esac
		done
	else
		echo -e "UFW already enabled"
	fi

	echo -e "Disabling default site (/var/www/html)"
	sudo a2dissite 000-default.conf

	echo -e "Restarting Apache2 to activate new configuration"
	sudo systemctl restart apache2

	#TODO(pavank): try to check if site is available at server ${IP}

	echo -e "${Bold}${Green}Success! Your site(s) have been added successfully"
	echo -e "Point your domains A record to $IP and after DNS propagation everything should be working fine.${Rst}"
	echo -e "Sites added and configured are:"

	temp=-1
	while [ $temp != $allSitesCount ]
	do
		if [ -e /etc/apache2/sites-available/${allSitesURL[$temp]}-le-ssl.conf ]
		then
			temp=`expr $temp + 1`
			echo -e "https://${allSitesURL[$temp]}"
			continue
		fi
		temp=`expr $temp + 1`
		echo -e "http://"${allSitesURL[$temp]}
	done
}

addSite () {
	siteURL=$1

	#used for directory name (which is without domain TLD, example.com site folder would be "example" not "example.com")
	siteNameNoTLD=`echo -e $siteURL | cut -d'.' -f1`

	sudo mkdir -p /var/www/$siteNameNoTLD
	sudo chown -R $USER:$USER /var/www/$siteNameNoTLD
	sudo chmod -R 755 /var/www

	#create temporary index.html page for viewing
	sudo echo -e "<h1>Server setup by <a href='https://github.com/realpvn/easy-apache.git'>easy-apache</a> (https://github.com/realpvn/easy-apache.git) </h1>" > /var/www/$siteNameNoTLD/index.html

	echo -e "Site $siteURL created, configuring"
	read -p "Email (leave blank if not required):" siteEmail
	if [ -z $siteEmail ]; then
		siteEmail=dev@localhost
	fi
	echo -e "<VirtualHost *:80>\n\tServerAdmin $siteEmail\n\tServerName $siteURL\n\tServerAlias www.$siteURL\n\tDocumentRoot /var/www/$siteNameNoTLD\n\tErrorLog \${APACHE_LOG_DIR}/error.log\n\tCustomLog \${APACHE_LOG_DIR}/access.log combined\n</VirtualHost>" | sudo tee /etc/apache2/sites-available/$siteURL.conf

	echo -e "Enabling site configuration"
	sudo a2ensite $siteURL.conf
}

sslInstall () {
	echo -e "${Bold}${Green}Installing SSL${Rst}"
	allSitesURL=""
	allSitesCount=-1

	dpkg -s certbot &> /dev/null
	if [ $? -eq 1 ]; then
		echo -e "Installing Certbot"
		sudo apt install certbot python3-certbot-apache
	fi

	while true
	do
		echo -e "99 to exit"
		read -p "URL (do not add www, eg input - helloworld.com): " siteName

		if [ $siteName == 99 ]
		then
			if [ $allSitesCount == -1 ]
			then
				echo -e "Good byee..."
				exit
			fi
			break
		fi

		if [ ! -e /etc/apache2/sites-available/${siteName}.conf ]
		then
			echo -e "${siteName} does not exist.\n${Purple}Add it using './easy-apache -a'${Rst}"
			continue
		fi

		if [ -e /etc/apache2/sites-available/${siteName}-le-ssl.conf ]
		then
			echo -e "${Bold}${Green}${siteName} already has SSL installed${Rst}"
			continue
		fi

		allSitesCount=`expr $allSitesCount + 1`
		allSitesURL[$allSitesCount]=$siteName
		
		sudo certbot --apache -d www.$siteName -d $siteName
		if [ -e /etc/apache2/sites-available/$siteName-le-ssl.conf ]
		then
			echo -e "${Bold}${Green}SSL Successful for $siteName${Rst}"
			continue
		fi
		echo -e "${Bold}${Red}SSL unsuccessful for $siteName${Rst}, try again"
		exit
	done

	if [ $allSitesCount == -1 ]
	then
		echo -e "${Red}SSL Installation exiting because one of the following were true"
		echo -e "1. You had no sites added (try running 'easy-apache -a' to add site"
		echo -e "2. You already have ssl certificates installed"
		echo -e "Please check & run SSL Installation again${Rst}"
		exit
	fi

	echo -e "Allowing 'Apache Full' in ufw"
	sudo ufw delete allow 'Apache'
	sudo ufw allow 'Apache Full'

	echo -e "SSL added to sites:"
	temp=-1
	while [ $temp != $allSitesCount ]
	do
		if [ -e /etc/apache2/sites-available/${allSitesURL[$temp]}-le-ssl.conf ]
		then
			temp=`expr $temp + 1`
			echo -e "https://${allSitesURL[$temp]}"
			continue
		fi
		temp=`expr $temp + 1`
		echo -e "http://"${allSitesURL[$temp]}
	done
}

apacheSSLInstall () {
	apacheInstall
	echo -e "${Bold}${Green}Apache Installation complete${Rst}"
	echo -e "${Bold}${Green}Proceeding to SSL Installation${Rst}"
	sslInstall
}

terminalColors
while getopts 'fash' flag; do
	case ${flag} in
		f ) apacheSSLInstall; exit;;
		a ) apacheInstall; exit;;
		s ) sslInstall; exit;;
		h ) help; exit;;
		* ) help; exit;;
	esac
done
help