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

case $1 in
    
    "-list")
        if [ $# -ne 3 ];then sortie "Usage: $0 -list <ip> <port>";fi
        #echo "TODO: list $2 $3"
        ssh test@$2 -p $3 "ls -l"
         
    ;;
    
    "-create")
        if [ $# -ne 4 ];then sortie "Usage: $0 -list <ip> <port> <nom archive>";fi
        if [ ! -f $4 ];then sortie "Le fichier n'existe pas";fi
        #echo "TODO: create"
        scp -P $3 $4 test@$2:/home/ubuntu/
    ;;
    
    "-browse")
        shell
    ;;
    
    "-extract")
        if [ $# -ne 4 ];then sortie "Usage: $0 -list <ip> <port> <nom archive>";fi
        echo "TODO: extract"
        scp -P $3 test@$2:/home/ubuntu/$4 ./
    ;;

    "-cmd")
        if [ $# -ne 4 ];then sortie "Usage: $0 -list <ip> <port> <commande>";fi
        echo "TODO: cmd"
        ssh test@$2 -p $3 "$4"
    ;;
    
    *)
        echo "Commande non supportée"
    ;;
esac
