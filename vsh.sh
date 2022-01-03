#!/bin/bash
function sortie {
    echo "ERROR: $1"
    exit 0
}
function shell {
    arch=$(mktemp -d)/$1
    scp -P $PORT $VUSER@$IP:$VPATH/$1 $arch >/dev/null|| return 0
    pwd='\'
    pwd_server="\/"
    while true; do
        echo -n "vsh> "
        read -r cmd args
        case $cmd in
        "quit"|"quit")
            return 0
        ;;
        "pwd")
            echo $pwd
        ;;
        "ls")
            case $args in
            "-l")
                sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  '{
                                                            if($2 ~ /^[d]/){print $1"\\"}
                                                            else if($2 ~ /x/){print $1"*"}
                                                            else if(length($3) != 0){print $1}}'
            ;;
            *)
                sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  ' BEGIN {list=""}{
                                                            if($2 ~ /^[d]/){list=list $1"\\ "}
                                                            else if($2 ~ /x/){list=list $1"* "}
                                                            else if(length($3) != 0){list=list $1" "}}
                                                            END{print list}'
            ;;
            esac
        ;;
        "cd")
            [ -z "$args" ] && continue
            [ "$args" = "\\" ] && { pwd='\';pwd_server="\/"; continue; }
            [ "$args" = ".." ] && { pwd=$(echo $pwd | sed 's/\\/ /g' | awk '{$NF="";sub(/[ \t]+$/,"")}1')"\\";pwd_server=$(echo $pwd | sed 's/\\/\\\//g'); continue; }
            
            chemin=$(sed -n "/^Directory $pwd_server$/,/@/p" $arch | awk  '{if($2 ~ /^[d]/){print $1}}' | grep -w $args)
            [ -z "$chemin" ] && { echo "Ce dossier n'existe pas"; continue; }
            pwd=$pwd$chemin"\\"
            pwd_server=$(echo "$pwd" | sed 's/\\/\\\//g')

        ;;
        
        
        *)
            echo "Cette commande n'existe pas"
        ;;
        esac
        
    done
}

function usage {
    echo "Il semblerait que vous n'ayez pas renseigné la configuration du serveur"
    echo "Lancez $0 -h pour en savoir plus"
}

function set_sshkey {

    if [ ! -f ~/.ssh/id_rsa.pub ]; then 
    echo "Création d'une clé d'authentification.."
    ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N '';fi
    ssh-copy-id -i ~/.ssh/id_rsa.pub -p $PORT $VUSER@$IP  
    echo "Vous pouvez maintenant vous connecter sans utiliser le mot de passe"

}

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
        ssh $VUSER@$IP -p $PORT "ls"
         
    ;;
    
    "-create")
        check_env $0

        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <Nom Archive>";fi

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
        scp -P $PORT $arch $VUSER@$IP:$VPATH
        rm $arch
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
                system(\"mkdir \"substr(\$2,2))
                chemin=pwd\$2
            }
            else if(length(\$1) != 0 && \$3==0 ){system(\"touch \"chemin \$1)}
            else if(length(\$1) != 0 && \$2 ~ /^[-]/ ){
                debut=body+\$4-1
                system(\"sed -n '\"debut\",\"debut+\$5-1\"p' $arch > \"chemin \$1)
            }
            
        }
        " $arch

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
    -browse: pour entrer dans un mode interractif
    -key:  pour créer une paire de clé SSH et et ne plus avoir à renseigner le mot de passe à chaque connection sur le serveur

"""
    ;;
    
    *)
        echo "Commande non supportée"
        echo "Lancez $0 -h pour en savoir plus"
    ;;
esac
