#!/bin/bash

function slurminator {
    JOBS=$(for line in $(squeue -u $USER --format "'%A'-'%j (%t)'" | egrep -v "JOBID|NAME"); do echo "$line" | sed -e "s/'-'/' '/" | tr '\n' ' '; done)
    chosenjob=$(
        eval "whiptail --title 'Slurminator' --menu 'Test' 16 100 9 $JOBS 'e)' 'Exit program'" 3>&2 2>&1 1>&3
    )

    if [[ $chosenjob == 'e)' ]]; then
        echo "Ok"
    else
        whattodo=$(eval "whiptail --title 'Slurminator $chosenjob' --menu 'Test' 16 100 9 's)' 'Show log path' 'f)' 'ftails' 'c)' 'scancel' 'sc)' 'secure cancel (USR1)' 'e)' 'Exit program'" 3>&2 2>&1 1>&3)
        case $whattodo in
            "s)")
                echo "slurmlogpath $chosenjob"
            ;;
            "f)")
                echo "tail -f $(slurmlogpath $chosenjob)"
                tail -f $(slurmlogpath $chosenjob)
            ;;
            "c)")
                if (whiptail --title "Really kill $chosenjob" --yesno "Are you sure you want to kill $chosenjob?" 8 78); then
                    echo "scancel $chosenjob"
                    scancel $chosenjob
                fi
            ;;
            "sc)")
                if (whiptail --title "Really kill $chosenjob" --yesno "Are you sure you want to kill $chosenjob with USR1?" 8 78); then
                    echo "scancel --signal=USR1 --batch $chosenjob"
                    scancel --signal=USR1 --batch $chosenjob
                fi
            ;;
            "e)")
            ;;
        esac
    fi
}

