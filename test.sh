#!/bin/bash
# while true; do
#     read -p "Local IP Address: " LOCAL_IP
#     read -p "You've entered local ip: $LOCAL_IP, proceed? (y/n): " YN
#     case $YN in
#         y ) break;;
#         n ) continue;;
#         * ) echo "Please enter y/n, default treats as n (retry)!";;
#     esac
# done

while true; do
    read -p "Enter kubeadm init config file path: " INIT_CFG
    read -p "You've entered file path: $INIT_CFG, proceed? (y/n): " YN
    case $YN in
        y ) 
            if test -f "$INIT_CFG"; then
                break
            else
                echo "File does not exist, please retry"
                continue
            fi
            ;;
        n ) continue;;
        * ) echo "Please enter y/n, default treats as n (retry)!";;
    esac
done