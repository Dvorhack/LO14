#!/bin/bash
function sortie {
    echo "ERROR: $1"
    exit 0
}
function shell {
    # Copie de l'archive en local pour ne pas avoir à se connecter au server à chaque changement
    arch=$(mktemp -d)/$1
    scp -P $PORT $VUSER@$IP:$VPATH/$1 $arch >/dev/null|| return 0
    pwd='\'
    pwd_server="\/"

    while true; do
        # Récupération de la commande utilisateur
        echo -n "vsh> "
        read -r cmd args

        case $cmd in
        "quit"|"exit")
            return 0
        ;;
        "pwd") # Affiche le chemin courant dans l'archive
            echo $pwd
        ;;
        "ls") # Affiche les fichiers et dosiers du chemin courant
            case $args in
            "-l") # si -l est spécifié, on affiche en liste
                sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  '{
                                                            if($2 ~ /^[d]/){print $1"\\"}
                                                            else if($2 ~ /x/){print $1"*"}
                                                            else if(length($3) != 0){print $1}}'
            ;;
            *) # pour tout autre argument, on affiche en ligne
                sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  ' BEGIN {list=""}{
                                                            if($2 ~ /^[d]/){list=list $1"\\ "}
                                                            else if($2 ~ /x/){list=list $1"* "}
                                                            else if(length($3) != 0){list=list $1" "}}
                                                            END{print list}'
            ;;
            esac
        ;;
        "cd") # Permet de changer de repertoire courant
            # Vérification de l'entrée utilisateur
            [ -z "$args" ] && { echo "Vous n'avez pas renseigné de dossier"; continue; }

            # Traitement particulier pour \ et ..
            [ "$args" = "\\" ] && { pwd='\';pwd_server="\/"; continue; }
            [ "$args" = ".." ] && { pwd="\\"$(echo $pwd | sed 's/\\/ /g' | awk '{$NF="";sub(/[ \t]+$/,"")}1')"\\"; [ "$pwd" = "\\\\" ] && pwd="\\" ; pwd_server=$(echo $pwd | sed 's/\\/\\\//g'); continue; }
            
            # Vérification si le dossier existe dans le dossier courant
            chemin=$(sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  '{if($2 ~ /^[d]/){print $1}}' | grep -w $args)
            [ -z "$chemin" ] && { echo "Ce dossier n'existe pas"; continue; }
            pwd=$pwd$chemin"\\"
            pwd_server=$(echo "$pwd" | sed 's/\\/\\\//g')

        ;;
        "cat")
            debut=$(sed -n '1p' $arch|awk -F: '{print $2}')
            # Récupération du fichier et affichage de son contenu
            sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  "BEGIN{trouve=0}{
                if(length(\$3) != 0 && \$2 ~ /^[^d]/){
                    if(\$1==\"$args\"){
                        trouve=1
                        if(\$3==0){print \"Le fichier est vide\"}
                        else{
                            body=\"$debut\"
                            debut=body+\$4-1
                            system(\"sed -n '\"debut\",\"debut+\$5-1\"p' $arch\")}
                    }
                }}
                END{if(trouve==0){print \"Le fichier n'existe pas\"}}"
            
        ;;
        "rm")
            body=$(sed -n '1p' $arch|awk -F: '{print $2}')

            # Récupération du fichier s'il existe
            fichier=$(cat -n $arch |sed -n "/Directory $pwd_server$/,/@/p" | sed -n "/$args/p")
            fichier=(${fichier// / })
            # S'il n'existe pas ou est un dossier, on part
            [ -z "${fichier[1]}" ] && { echo "Le fichier n'existe pas"; continue; }
            [[ "${fichier[4]}" == "d*" ]] && { echo "${fichier[1]} est un dossier"; continue; }

            
            
            # Vérification si le fichier est vide
            if [ -z "${fichier[4]}" ];then
                # S'il est vide, on supprime juste sa ligne dans le header
                sed -i.bak "${fichier[0]}d" $arch
            else
                # S'il n'est pas vide, on supprime sa ligne dans le header et son contenu dans le body
                sed -i.bak "${fichier[0]}d;"$((body+fichier[4]-1))","$((body+fichier[4]+fichier[5]-2))"d" $arch
                # Décalage de tous les fichiers situés après ce lui à supprimer
                tmp=mktemp
                awk "{if(NR>${fichier[0]} && length(\$4) !=0) {\$4-=${fichier[5]}};print \$0}" $arch > $tmp && mv $tmp $arch
            fi

            # Mise à jour de la première ligne (offset header, offset body)
            nligne=$(sed -n '1p' $arch|awk -F: '{print $2}')
            nligne=$((nligne-1))
            sed -i -e "1s/.*/3:$nligne/" $arch

            # Mise à jour de l'archive sur le serveur
            scp -P $PORT $arch $VUSER@$IP:$VPATH
        ;;
        "touch")
            body=$(sed -n '1p' $arch|awk -F: '{print $2}')

            # Ajout du fichier dans l'archive
            nligne=$(cat -n $arch |sed -n "/Directory $pwd_server$/p"|awk "{print \$1}")
            nligne=$((nligne+1))
            tmp=mktemp
            awk "{if(NR==$nligne) {print \"$args -rw-r--r-- 0\"};print \$0}" $arch > $tmp && mv $tmp $arch

            # Mise à jour de la première ligne (offset header, offset body)
            nligne=$(sed -n '1p' $arch|awk -F: '{print $2}')
            nligne=$((nligne+1))
            sed -i -e "1s/.*/3:$nligne/" $arch

            # Mise à jour de l'archive sur le serveur
            scp -P $PORT $arch $VUSER@$IP:$VPATH
        ;;
        "mkdir")
            body=$(sed -n '1p' $arch|awk -F: '{print $2}')

            # Ajout du fichier dans l'archive
            nligne=$(cat -n $arch |sed -n "/Directory $pwd_server$/p"|awk "{print \$1}")
            nligne=$((nligne+1))
            tmp=mktemp
            awk "{if(NR==$nligne) {print \"$args drwxr-xr-x 96\"}
                else if(NR==$((body-1))) {
                    print(\"Directory $pwd_server$args/\"); 
                    print(\"@\")}
                print \$0}" $arch > $tmp && mv $tmp $arch

            # Mise à jour de la première ligne (offset header, offset body)
            nligne=$(sed -n '1p' $arch|awk -F: '{print $2}')
            nligne=$((nligne+3))
            sed -i -e "1s/.*/3:$nligne/" $arch

            # Mise à jour de l'archive sur le serveur
            scp -P $PORT $arch $VUSER@$IP:$VPATH
        ;;
        "debug")
            cat -n $arch
        ;;
        
        
        *)
            echo "Cette commande n'existe pas"
        ;;
        esac
        
    done
}

# Fonction appelée si l'utilisateur n'a pas renseigné les paramètres du serveur
function usage {
    echo "Il semblerait que vous n'ayez pas renseigné la configuration du serveur"
    echo "Lancez $0 -h pour en savoir plus"
}

# Fonction qui ajoute la clé RSA au serveur
function set_sshkey {

    if [ ! -f ~/.ssh/id_rsa.pub ]; then 
    echo "Création d'une clé d'authentification.."
    ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N '';fi
    ssh-copy-id -i ~/.ssh/id_rsa.pub -p $PORT $VUSER@$IP  
    echo "Vous pouvez maintenant vous connecter sans utiliser le mot de passe"

}

# Fonction qui vérifie si les paramètres du serveur ont été renseignés
function check_env {
    if [[ -z "${VSH_IP}" ]]; then
        usage $0
        exit 0
    else
        IP="${VSH_IP}"
    fi
    
    if [[ -z "${VSH_PORT}" ]]; then
        usage $0
        exit 0
    else
        PORT="${VSH_PORT}"
    fi
    
    if [[ -z "${VSH_PATH}" ]]; then
        usage $0
        exit 0
    else
        VPATH="${VSH_PATH}"
    fi

    if [[ -z "${VSH_USER}" ]]; then
        usage $0
        exit 0
    else
        VUSER="${VSH_USER}"
    fi
}

IP=""
PORT=0
VPATH=""
VUSER=""

case $1 in
    
    "-list")
        check_env $0

        # Récupération de la liste d'archives
        liste=$(ssh $VUSER@$IP -p $PORT "ls")

        # Vérification si elle est vide
        [ -z "$liste" ] && { echo "Il n'y a aucune archive sur le serveur"; exit 0; }
        echo "Voici les archives présentes sur le serveur:"
        echo $liste
         
    ;;
    
    "-create")
        check_env $0

        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <Nom Archive>";fi
        if [ -z "$(ls -A .)" ]; then
            echo "Le dossier courant est vide"
            exit 0
        fi
        exists=$(ssh $VUSER@$IP -p $PORT "ls $2 2>/dev/null")
        [ ! -z "$exists" ] && { echo "Une archive avec ce nom existe déjà"; exit 0; }
        arch=$(mktemp -d)/$2

        ls -lR $(pwd) |sed '/^$/d;/^total/d' |awk "
            BEGIN{
                print \"3:3\"
                print
                chemin=ENVIRON[\"PWD\"] \"/\" \$0;
                print(\"Directory \"chemin);
                nbligne=1
            }
            {
                # Préprocessing de la ligne
                if(\$1 ~ /^\//){ # Changement de répertoire
                    chemin=substr(\$1, 1, length(\$1)-1)
                    chemin=chemin \"/\"
                }else if(\$1 ~ /^[^d]/){ # Traitement du fichier
                    system(\"cat \"chemin \$9 \" >> $arch.body\")
                    \$10=nbligne;
                    \"wc -l < \" chemin \$9 \"| sed 's/ //g'\"|getline \$11;
                    nbligne+=\$11
                    if(\$11==0){\$11=\"\";\$10=\"\"}
                }
                
                # Affichage de la ligne
                if(length(\$9) != 0){    # Fichier/Dossier dans le répertoire
                    print \$9,\$1,\$5,\$10,\$11
                }else{                  # Changement de répertoire
                    print \"@\";print \"Directory \"chemin
                }
            }
            END{
                print \"@\"
                print \"\"
            }" > $arch
        nligne=$(wc -l < $arch | sed 's/ //g')
        nligne=$(($nligne+1))
        sed -i -e "1s/.*/3:$nligne/" $arch
        sed -i -e "s/$(echo $PWD | sed 's#/#\\/#g'  )//" $arch
        cat $arch.body >> $arch
        #find . -type f -exec cat {} \; >> $arch
        #cat -n $arch
        #cat $arch.body
        scp -P $PORT $arch $VUSER@$IP:$VPATH > /dev/null
        rm $arch
        echo "Votre archive $2 a bien été créée"
    ;;
    
    "-browse")
        check_env $0
        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <nom archive>";fi
        shell $2
    ;;

    "-key")
        check_env $0
        set_sshkey
        
        ;;
    "-extract")
        check_env $0
        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <nom archive>";fi
        arch=$(mktemp -d)/$2
        scp -P $PORT $VUSER@$IP:$VPATH/$2 $arch >/dev/null|| exit 0
        #cat $arch
        awk "
        BEGIN{
            pwd=ENVIRON[\"PWD\"] \$0;
        }
        {
            if(NR==1){body=substr(\$0,3)}
            else if(NR==body) exit
            else if(\$1==\"Directory\"){
                system(\"mkdir \"substr(\$2,2)\" 2>/dev/null\")
                chemin=pwd\$2
            }
            else if(length(\$1) != 0 && \$3==0 ){system(\"touch \"chemin \$1)}
            else if(length(\$1) != 0 && \$2 ~ /^[-]/ ){
                debut=body+\$4-1
                system(\"sed -n '\"debut\",\"debut+\$5-1\"p' $arch > \"chemin \$1)
            }
            
        }
        " $arch
        ssh $VUSER@$IP -p $PORT "rm $2"
        echo "L'archive $2 a bien été déployée dans le dossier courant"
    ;;

    "-h")
        echo """
 _  _  ____  _  _    ____  ____  ____  _  _  ____  ____ 
/ )( \/ ___)/ )( \  / ___)(  __)(  _ \/ )( \(  __)(  _ \\
\ \/ /\___ \) __ (  \___ \ ) _)  )   /\ \/ / ) _)  )   /
 \__/ (____/\_)(_/  (____/(____)(__\_) \__/ (____)(__\_)
        
Bienvenue dans la commande vsh, gestionnaire d'archive
Pour commencer, vous devez indiquer l'IP, le PORT, le nom d'utilisateur et le répertoire du serveur d'archive en tant que variable globale, voici les commandes associés:
export VSH_IP=<IP>
export VSH_PORT=<PORT>
export VSH_PATH=<répertoire>
export VSH_USER=<nom d'utilisateur>

Les commandes disponibles sont les suivantes:
    -list: pour lister les archives présentes sur le serveur
    -create archive: pour créer une archive du répertoire courant
    -extract archive: pour récupérer les fichiers de l'archive indiquée
    -browse: vous permet de voir et modifier les dossiers et fichiers présents dans une archive
    -key:  pour créer une paire de clé SSH et et ne plus avoir à renseigner le mot de passe à chaque connection sur le serveur

"""
    ;;
    
    *)
        echo "Commande non supportée"
        echo "Lancez $0 -h pour en savoir plus"
    ;;
esac
