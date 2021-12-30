#!/bin/bash
function sortie {
    echo "ERROR: $1"
    exit 0
}
function shell {
    while true; do
        echo -n "vsh> "
        read cmd args
        if [ "$cmd" == "quit" ];then return 0;fi
        ssh test@localhost -p 2222 "$cmd $args"
        echo ""
    done
}

function usage {
    echo "Il semblerait que les paramètres du serveur ne sont pas renseignés"
    echo "Lancez $0 -h pour en savoir plus"
}

function set_sshkey {

    if [ ! -f ~/.ssh/id_rsa ]; then 
    echo "Création d'une clé d'authentification.."
    ssh-keygen -q -t rsa -f ~/.ssh/id_rsa -N '';fi
    ssh-copy-id -i ~/.ssh/id_rsa test@localhost -p 2222 >/dev/null 2>/dev/null
    echo "Vous pouvez maintenant vous connecter sans utiliser le mot de passe"

}

function check_env {
    source ./creds.sh
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
        ssh $VUSER@$IP -p $PORT "ls -l"
         
    ;;
    
    "-create")
        check_env $0

        if [ $# -lt 3 ];then sortie "Usage: $0 $1 <Nom Archive> <fichier 1> [<fichier 2> <fichier 3> ...]";fi
        for var in "${@:3}"
        do
            echo "$var"
            if [ ! -f $var ];then sortie "Le fichier $var n'existe pas";fi
        done
        
        tar -cvzf $2.tar.gz ${@:3}
        scp -P $PORT $2.tar.gz $VUSER@$IP:$VPATH
        rm $2.tar.gz
    ;;
    
    "-browse")
        check_env $0
        set_sshkey >/dev/null 2>/dev/null
        shell
    ;;

    "-key")

        set_sshkey;
        
        ;;
    "-extract")
        check_env $0
        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <nom archive>";fi
        scp -P $PORT $VUSER@$IP:/home/ubuntu/$2 ./ && tar xvf $2 && rm $2 && ssh $VUSER@$IP -p $PORT "rm $2"

    ;;

    "-creds")
        if [ $# -ne 5 ];then sortie "Usage: $0 $1 <ip> <port> </path/to/vsh_dirrectory> <ssh user>";fi
        echo "export VSH_IP=\"$2\"" > creds.sh
        echo "export VSH_PORT=\"$3\"" >> creds.sh
        echo "export VSH_PATH=\"$4\"" >> creds.sh
        echo "export VSH_USER=\"$5\"" >> creds.sh
        check_env $0
        echo "Voici les paramètres renseignés IP=$IP PORT=$PORT PATH=$VPATH USER=$VUSER"
    ;;

    "-h")
        echo """
 _  _  ____  _  _    ____  ____  ____  _  _  ____  ____ 
/ )( \/ ___)/ )( \  / ___)(  __)(  _ \/ )( \(  __)(  _ \\
\ \/ /\___ \) __ (  \___ \ ) _)  )   /\ \/ / ) _)  )   /
 \__/ (____/\_)(_/  (____/(____)(__\_) \__/ (____)(__\_)
        
Bienvenue dans la commande vsh, gestionnaire d'archive
Pour commencer, vous devez indiquer l'IP, le PORT et le répertoire du serveur d'archive
avec la commande: $0 -creds <IP> <PORT> </path/to/directory> <ssh user>

Les commandes disponibles sont les suivantes:
    -list: pour lister les archives présentes sur le serveur dans le repertoire indiqué
    -create fichier1 [fichier2 fichier3 ...]: pour créer une archive avec les fichiers indiqués
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
