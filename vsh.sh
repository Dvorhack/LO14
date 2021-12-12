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
        if [ $# -lt 2 ];then sortie "Usage: $0 $1 <fichier 1> [<fichier 2> <fichier 3> ...]";fi
        if [ ! -f $2 ];then sortie "Le fichier n'existe pas";fi
        echo "TODO: create for mutiple file"
        scp -P $PORT $2 $VUSER@$IP:/home/ubuntu/
    ;;
    
    "-browse")
        check_env $0
        shell
    ;;
    
    "-extract")
        check_env $0
        if [ $# -ne 2 ];then sortie "Usage: $0 $1 <nom archive>";fi
        echo "TODO: extract the archive"
        scp -P $PORT $VUSER@$IP:/home/ubuntu/$2 ./
    ;;

    "-creds")
        if [ $# -ne 5 ];then sortie "Usage: $0 $1 <ip> <port> </path/to/vsh_dirrectory> <USER>";fi
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
avec la commande: $0 -creds <IP> <PORT> </path/to/directory>

Les commandes disponibles sont les suivantes:
    -ls: pour lister les archives présentes sur le serveur dans le repertoire indiqué
    -create fichier1 [fichier2 fichier3 ...]: pour créer une archive avec les fichiers indiqués
    -extract archive: pour récupérer les fichiers de l'archive indiquée
    -browse: pour entrer dans un mode interractif

Pour éviter d'avoir à renseigner le mot de passe ssh à chaque fois, il faut vous créer une paire de clé ssh et la déposer sur le serveur
"""
    ;;
    
    *)
        echo "Commande non supportée"
        echo "Lancez $0 -h pour en savoir plus"
    ;;
esac
