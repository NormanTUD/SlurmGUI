#!/bin/bash

function slurmlogpath { scontrol show job $1 | grep StdOut | sed -e 's/^\s*StdOut=//' }

function red_text {
    echo -e "\e[31m$1\e[0m"
}

function green_text {
    echo -e "\e[92m$1\e[0m"
}

function slurminator {
    if command -v squeue &> /dev/null; then
        if command -v whiptail &> /dev/null; then
            JOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)'" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
            chosenjob=$(
                eval "whiptail --title 'Slurminator' --menu 'Test' 16 100 9 $JOBS 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3
            )

            if [[ $chosenjob == 'q)' ]]; then
                green_text "Ok"
            else
                whattodo=$(eval "whiptail --title 'Slurminator $chosenjob' --menu 'Test' 16 100 9 's)' 'Show log path' 'w)' 'whypending' 'f)' 'tail -f' 'c)' 'scancel' 'sc)' 'scancel with signal USR1' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3)
                case $whattodo in
                    "s)")
                        echo "slurmlogpath $chosenjob"
                        slurmlogpath $chosenjob
                    ;;
                    "f)")
                        echo "tail -f $(slurmlogpath $chosenjob)"
                        tail -f $(slurmlogpath $chosenjob)
                    ;;
                    "w)")
                        echo "whypending $chosenjob"
                        whypending $chosenjob
                    ;;
                    "c)")
                        if (whiptail --title "Really kill $chosenjob" --yesno "Are you sure you want to kill $chosenjob?" 8 78); then
                            echo "scancel $chosenjob"
                            scancel $chosenjob && green_text "$chosenjob killed" || red_text "Error killing $chosenjob"
                        fi
                    ;;
                    "sc)")
                        if (whiptail --title "Really kill $chosenjob" --yesno "Are you sure you want to kill $chosenjob with USR1?" 8 78); then
                            echo "scancel --signal=USR1 --batch $chosenjob"
                            scancel --signal=USR1 --batch $chosenjob && green_text "$chosenjob killed" || red_text "Error killing $chosenjob"
                        fi
                    ;;
                    "q)")
			green_text "Ok"
                    ;;
                esac
            fi
        else
            red_text "whiptail not found. Cannot execute slurminator without it"
        fi
    else
        red_text "squeue not found. Cannot execute slurminator without it"
    fi
}
