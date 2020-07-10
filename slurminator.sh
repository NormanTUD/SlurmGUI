#!/bin/bash

function slurmlogpath { scontrol show job $1 | grep StdOut | sed -e 's/^\s*StdOut=//' }

function red_text {
    echo -e "\e[31m$1\e[0m"
}

function green_text {
    echo -e "\e[92m$1\e[0m"
}

function multiple_slurm_tails {
	THISSCREENCONFIGFILE=/tmp/$(uuidgen).conf
	for var in "$@"; do
		echo "screen tail -f $(slurmlogpath $var)" >> $THISSCREENCONFIGFILE
		if [[ ${*: -1:1} -ne $var ]]; then
			echo "split -v
focus right" >> $THISSCREENCONFIGFILE
		fi
	done
	screen -c $THISSCREENCONFIGFILE
	rm $THISSCREENCONFIGFILE
}

function slurminator {
    if command -v squeue &> /dev/null; then
        if command -v whiptail &> /dev/null; then
            JOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)'" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
            chosenjob=$(
		    eval "whiptail --title 'Slurminator' --menu 'Test' 16 100 9 $JOBS 'k)' 'kill multiple jobs' 't)' 'tail multiple jobs' 'r)' 'reload slurminator' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3
            )

            if [[ $chosenjob == 'q)' ]]; then
                green_text "Ok"
            else
		if [[ $chosenjob == 'r)' ]]; then
			slurminator
		elif [[ $chosenjob == 't)' ]]; then
			TJOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)' OFF" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
			echo "whiptail --title 'Which jobs to tail?' --checklist 'Which jobs to choose?' 20 78 10 $TJOBS"
			test=$(eval "whiptail --title 'Which jobs?' --checklist 'Which jobs to choose?' 20 78 4 $TJOBS" 3>&1 1>&2 2>&3)
			whiptail --title "Screens" --msgbox "To exit, press <CTRL> <a>, then <\\>" 8 78
			eval "multiple_slurm_tails $test"
		elif [[ $chosenjob == 'k)' ]]; then
			TJOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)' OFF" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
			test=$(eval "whiptail --title 'Which jobs to kill?' --checklist 'Which jobs to choose?' 20 78 10 $TJOBS" 3>&1 1>&2 2>&3)
			eval "scancel $test"
		else
			whattodo=$(eval "whiptail --title 'Slurminator $chosenjob' --menu 'Test' 16 100 9 's)' 'Show log path' 'w)' 'whypending' 'f)' 'tail -f' 'c)' 'scancel' 'sc)' 'scancel with signal USR1' 'm)' 'go to main menu' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3)
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
			    "m)")
				slurminator
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
            fi
        else
            red_text "whiptail not found. Cannot execute slurminator without it"
        fi
    else
        red_text "squeue not found. Cannot execute slurminator without it"
    fi
}
