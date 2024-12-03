# This function you will find in the rebuild.sh under ~/vesta/func/.

# MAIL domain rebuild
rebuild_mail_domain_conf() {

    get_domain_values 'mail'

    if [[ "$domain" = *[![:ascii:]]* ]]; then
        domain_idn=$(idn -t --quiet -a $domain)
    else
        domain_idn=$domain
    fi

    if [ "$SUSPENDED" = 'yes' ]; then
        SUSPENDED_MAIL=$((SUSPENDED_MAIL +1))
    fi

    # Rebuilding exim config structure
    if [[ "$MAIL_SYSTEM" =~ exim ]]; then
        rm -f /etc/$MAIL_SYSTEM/domains/$domain_idn
        mkdir -p $HOMEDIR/$user/conf/mail/$domain
        ln -s $HOMEDIR/$user/conf/mail/$domain \
            /etc/$MAIL_SYSTEM/domains/$domain_idn
        rm -f $HOMEDIR/$user/conf/mail/$domain/antispam
        rm -f $HOMEDIR/$user/conf/mail/$domain/antivirus
        rm -f $HOMEDIR/$user/conf/mail/$domain/protection
        rm -f $HOMEDIR/$user/conf/mail/$domain/passwd
        rm -f $HOMEDIR/$user/conf/mail/$domain/fwd_only
        #rm -f $HOMEDIR/$user/conf/mail/$domain/aliases
        touch $HOMEDIR/$user/conf/mail/$domain/aliases
        touch $HOMEDIR/$user/conf/mail/$domain/passwd
        touch $HOMEDIR/$user/conf/mail/$domain/fwd_only

        # HS remove lines that do not belong here
        sed -i '/'$domain_idn'\:/!d' $HOMEDIR/$user/conf/mail/$domain/aliases

        # Adding antispam protection
        if [ "$ANTISPAM" = 'yes' ]; then
            touch $HOMEDIR/$user/conf/mail/$domain/antispam
        fi

        # Adding antivirus protection
        if [ "$ANTIVIRUS" = 'yes' ]; then
            touch $HOMEDIR/$user/conf/mail/$domain/antivirus
        fi

        # Adding dkim
        if [ "$DKIM" = 'yes' ]; then
            cp $USER_DATA/mail/$domain.pem \
                $HOMEDIR/$user/conf/mail/$domain/dkim.pem
        fi

        # Removing symbolic link if domain is suspended
        if [ "$SUSPENDED" = 'yes' ]; then
            rm -f /etc/exim/domains/$domain_idn
        fi

        # Adding mail directiry
        if [ ! -e $HOMEDIR/$user/mail/$domain_idn ]; then
            mkdir $HOMEDIR/$user/mail/$domain_idn
        fi

        # Adding catchall email
        dom_aliases=$HOMEDIR/$user/conf/mail/$domain/aliases
        if [ ! -z "$CATCHALL" ]; then
            echo "*@$domain_idn:$CATCHALL" >> $dom_aliases
        fi
    fi

    # Rebuild domain accounts
    accs=0
    dom_diks=0
    if [ -e "$USER_DATA/mail/$domain.conf" ]; then
        accounts=$(search_objects "mail/$domain" 'SUSPENDED' "no" 'ACCOUNT')
    else
        accounts=''
    fi
    for account in $accounts; do
        (( ++accs))
# This line is on the wrong place, it causes incorrect memory calculation for email accounts       dom_diks=$((dom_diks + U_DISK))

        account_sed=`echo $account | sed 's/\./\\\\./g'`
        object=$(grep "ACCOUNT='$account_sed'" $USER_DATA/mail/$domain.conf)
        FWD_ONLY='no'
        eval "$object"
        if [ "$SUSPENDED" = 'yes' ]; then
            MD5='SUSPENDED'
        fi

# Place it here
        dom_diks=$((dom_diks + U_DISK))

        if [[ "$MAIL_SYSTEM" =~ exim ]]; then
            if [ "$QUOTA" = 'unlimited' ]; then
                QUOTA=0
            fi
            str="$account:$MD5:$user:mail::$HOMEDIR/$user:$QUOTA"
            echo $str >> $HOMEDIR/$user/conf/mail/$domain/passwd
            for malias in ${ALIAS//,/ }; do
                # HS Alias fix
                alias_localpart=$(echo $malias | cut -d"@" -f1);
                alias_domain=$(echo $malias | cut -d"@" -f2);

                ascii_domain=$(idn -t --quiet -a $domain_idn);
                ascii_alias=$(idn -t --quiet -a $alias_domain);

                malias_sed=`echo $malias | sed 's/\./\\\\./g'`
                alias_localpart_sed=`echo $alias_localpart | sed 's/\./\\\\./g'`

                # remove line if exists
                sed -i '/^'$malias_sed'\:/d' $HOMEDIR/$user/conf/mail/$alias_domain/aliases
                sed -i '/^'$alias_localpart_sed'@'$ascii_alias'\:/d' $HOMEDIR/$user/conf/mail/$alias_domain/aliases

                # add file and then line
               touch $HOMEDIR/$user/conf/mail/$alias_domain/aliases
               echo "$alias_localpart@$ascii_alias:$account@$ascii_domain" >> $HOMEDIR/$user/conf/mail/$alias_domain/aliases
            done
            if [ ! -z "$FWD" ]; then
                ascii_domain=$(idn -t --quiet -a $domain_idn);
                # delete redirect line
                sed -i '/^'$account@$domain_idn'\:/d' $dom_aliases
                sed -i '/^'$account@$ascii_domain'\:/d' $dom_aliases
                # add redirect line
                echo "$account@$ascii_domain:$FWD" >> $dom_aliases
            fi
            if [ "$FWD_ONLY" = 'yes' ]; then
                echo "$account" >> $HOMEDIR/$user/conf/mail/$domain/fwd_only
            fi
        fi
    done

    # Set permissions and ownership
    if [[ "$MAIL_SYSTEM" =~ exim ]]; then
        chmod 660 $USER_DATA/mail/$domain.*
        chmod 771 $HOMEDIR/$user/conf/mail/$domain
        chmod 660 $HOMEDIR/$user/conf/mail/$domain/*
        chmod 771 /etc/$MAIL_SYSTEM/domains/$domain_idn
        chmod 770 $HOMEDIR/$user/mail/$domain_idn
        chown -R $MAIL_USER:mail $HOMEDIR/$user/conf/mail/$domain
        chown -R dovecot:mail $HOMEDIR/$user/conf/mail/$domain/passwd
        chown $user:mail $HOMEDIR/$user/mail/$domain_idn
    fi

    # Update counters
    update_object_value 'mail' 'DOMAIN' "$domain" '$ACCOUNTS' "$accs"
    update_object_value 'mail' 'DOMAIN' "$domain" '$U_DISK' "$dom_diks"
    U_MAIL_ACCOUNTS=$((U_MAIL_ACCOUNTS + accs))
    U_DISK_MAIL=$((U_DISK_MAIL + dom_diks))
    U_MAIL_DOMAINS=$((U_MAIL_DOMAINS + 1))
}
