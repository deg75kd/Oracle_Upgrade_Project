#!/bin/bash

function one_fnc {
	echo -e "\nYou selected option 1"
}

function two_fnc {
	echo "You selected option 2"
}

while :
do
    echo -e "\tWhere would you like to start/continue this script?"
    echo -e "\t---------------------------------------------"
    echo -e "\t1) Beginning"
    echo -e "\t2) Create the CDB"
    echo -e "\t3) Install Oracle Components"
	echo -e "\t4) Turn on Archive Log Mode"
	echo -e "\t5) Create the PDB"
	echo -e "\tq) Quit"
    echo
    echo -e "\tEnter your selection: r\b\c"
    read selection
    if [[ -z "$selection" ]]
        then selection=r
    fi

    case $selection in
        1)  one_fnc
	    exit
            ;;
        2)  two_fnc
	    exit
            ;;
	3)  echo "You selected 3"
	    exit
	    ;;
	4)  echo "You selected 4"
	    exit
	    ;;
	5)  ;&  #  Fall through example.
        6)  echo "You selected option 5 or 6"
	    exit
            ;;
      q|Q)  echo "You have chosen to quit"
            exit
            ;;
        *)  echo -e "\n Invalid selection"
            sleep 1
            ;;
    esac
done

