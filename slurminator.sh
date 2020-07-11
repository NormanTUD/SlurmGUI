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
		echo "name $var" >> $THISSCREENCONFIGFILE
		if [[ ${*: -1:1} -ne $var ]]; then
			echo "split -v" >> $THISSCREENCONFIGFILE
			echo "focus right" >> $THISSCREENCONFIGFILE
		fi
	done
	screen -c $THISSCREENCONFIGFILE
	rm $THISSCREENCONFIGFILE
}

function get_job_name {
	scontrol show job $1 | grep JobName | sed -e 's/.*JobName=//'
}

function kill_multiple_jobs {
	TJOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)' OFF" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
	test=$(eval "whiptail --title 'Which jobs to kill?' --checklist 'Which jobs to choose?' $WIDTHHEIGHT $TJOBS" 3>&1 1>&2 2>&3)
	eval "scancel $test"
}

function tail_multiple_jobs {
	TJOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)' OFF" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
	test=$(eval "whiptail --title 'Which jobs to tail?' --checklist 'Which jobs to choose?' $WIDTHHEIGHT $TJOBS" 3>&1 1>&2 2>&3)
	whiptail --title "Screens" --msgbox "To exit, press <CTRL> <a>, then <\\>" 8 78 3>&1 1>&2 2>&3
	eval "multiple_slurm_tails $test"
}

function single_job_tasks {
	chosenjob=$1
	WHYPENDINGSTRING=""
	if command -v whypending &> /dev/null; then
		WHYPENDINGSTRING="'w)' 'whypending'"
	fi

	SCANCELSTRING=""
	if command -v scancel &> /dev/null; then
		SCANCELSTRING="'k)' 'scancel' 'c)' 'scancel with signal USR1'"
	fi

	TAILSTRING=""
	if command -v tail &> /dev/null; then
		TAILSTRING="'t)' 'tail -f'"
	fi

	jobname=$(get_job_name $chosenjob)
	whattodo=$(eval "whiptail --title 'Slurminator >$jobname< ($chosenjob)' --menu 'What to do with job >$jobname< ($chosenjob)' $WIDTHHEIGHT 's)' 'Show log path' $WHYPENDINGSTRING $TAILSTRING $SCANCELSTRING 'm)' 'go to main menu' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3)
	case $whattodo in
		"s)")
			echo "slurmlogpath $chosenjob"
			slurmlogpath $chosenjob
			;;
		"t)")
			echo "tail -f $(slurmlogpath $chosenjob)"
			tail -f $(slurmlogpath $chosenjob)
			;;
		"w)")
			echo "whypending $chosenjob"
			whypending $chosenjob
			;;
		"k)")
			if (whiptail --title "Really kill >$jobname< ($chosenjob)" --yesno "Are you sure you want to kill >$jobname< ($chosenjob)?" 8 78); then
				echo "scancel $chosenjob"
				scancel $chosenjob && green_text "$chosenjob killed" || red_text "Error killing $chosenjob"
			fi
			;;
		"m)")
			slurminator
			;;
		"c)")
			if (whiptail --title "Really kill >$jobname< ($chosenjob)" --yesno "Are you sure you want to kill >$jobname< ($chosenjob) with USR1?" 8 78); then
				echo "scancel --signal=USR1 --batch $chosenjob"
				scancel --signal=USR1 --batch $chosenjob && green_text "$chosenjob killed" || red_text "Error killing $chosenjob"
			fi
			;;
		"q)")
			green_text "Ok"
			;;
	esac
}

function slurminator {
	WIDTHHEIGHT="$LINES $COLUMNS $(( $LINES - 8 ))"
	FAILED=0
	if ! command -v squeue &> /dev/null; then
		red_text "squeue not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v whiptail &> /dev/null; then
		red_text "whiptail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	SCANCELSTRING=""
	if command -v scancel &> /dev/null; then
		SCANCELSTRING="'k)' 'kill multiple jobs'"
	fi

	TAILSTRING=""
	if command -v tail &> /dev/null; then
		TAILSTRING="'t)' 'tail multiple jobs'"
	fi
	

	if [[ $FAILED == 0 ]]; then
		JOBS=$(for line in $(squeue -u $USER --format "'%A' '%j (%t, %M)'" | sed '1d'); do echo "$line" | tr '\n' ' '; done)
		chosenjob=$(
			eval "whiptail --title 'Slurminator' --menu 'Welcome to Slurminator' $WIDTHHEIGHT $JOBS $SCANCELSTRING $TAILSTRING 'r)' 'reload slurminator' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3
		)

		if [[ $chosenjob == 'q)' ]]; then
			green_text "Ok"
		elif [[ $chosenjob == 'r)' ]]; then
			slurminator
		elif [[ $chosenjob == 't)' ]]; then
			tail_multiple_jobs
		elif [[ $chosenjob == 'k)' ]]; then
			kill_multiple_jobs
		else
			single_job_tasks $chosenjob
		fi
	else
		red_text  "Missing requirements, cannot run Slurminator"
	fi
}
