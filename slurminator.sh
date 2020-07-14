#!/bin/bash

echoerr() {
	echo "$@" 1>&2
}

function red_text {
	echoerr -e "\e[31m$1\e[0m"
}

function green_text {
	echoerr -e "\e[92m$1\e[0m"
}

function debug_code {
	echoerr -e "\e[93m$1\e[0m"
}

function slurmlogpath {
	if command -v scontrol &> /dev/null; then
		if command -v grep &> /dev/null; then
			if command -v sed &> /dev/null; then
				debug_code "scontrol show job $1 | grep StdOut | sed -e 's/^\\s*StdOut=//'"
				scontrol show job $1 | grep StdOut | sed -e 's/^\s*StdOut=//'
			else
				red_text "sed not found"
			fi
		else
			red_text "grep not found"
		fi
	else
		red_text "scontrol not found"
	fi
}

function get_job_name {
	if command -v screen &> /dev/null; then
		scontrol show job $1 | grep JobName | sed -e 's/.*JobName=//'
	else
		red_text "Program scontrol does not exist, cannot run it"
	fi
}

function multiple_slurm_tails {
	if command -v screen &> /dev/null; then
		if command -v uuidgen &> /dev/null; then
			THISSCREENCONFIGFILE=/tmp/$(uuidgen).conf
			for slurmid in "$@"; do
				logfile=$(slurmlogpath $slurmid)
				if [[ -e $logfile ]]; then
					echo "screen tail -f $logfile" >> $THISSCREENCONFIGFILE
					echo "name $(get_job_name $slurmid)" >> $THISSCREENCONFIGFILE
					if [[ ${*: -1:1} -ne $slurmid ]]; then
						echo "split -v" >> $THISSCREENCONFIGFILE
						echo "focus right" >> $THISSCREENCONFIGFILE
					fi
				fi
			done
			if [[ -e $THISSCREENCONFIGFILE ]]; then
				debug_code "Screen file:"
				cat $THISSCREENCONFIGFILE
				debug_code "Screen file end"
				screen -c $THISSCREENCONFIGFILE
				rm $THISSCREENCONFIGFILE
			else
				red_text "$THISSCREENCONFIGFILE not found"
			fi
		else
			red_text "Command uuidgen not found, cannot execute multiple tails"
		fi
	else
		red_text "Command screen not found, cannot execute multiple tails"
	fi
}

function kill_multiple_jobs {
	FAILED=0
	if ! command -v squeue &> /dev/null; then
		red_text "squeue not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v scancel &> /dev/null; then
		red_text "scancel not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v whiptail &> /dev/null; then
		red_text "whiptail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if [[ $FAILED == 0 ]]; then
		TJOBS=$(get_squeue_from_format_string "'%A' '%j (%t, %M)' OFF")
		chosenjobs=$(eval "whiptail --title 'Which jobs to kill?' --checklist 'Which jobs to choose?' $WIDTHHEIGHT $TJOBS" 3>&1 1>&2 2>&3)
		if [[ -z $chosenjobs ]]; then
			green_text "No jobs chosen to kill"
		else
			if (whiptail --title "Really kill multiple jobs ($chosenjobs)?" --yesno "Are you sure you want to kill multiple jobs ($chosenjobs)?" 8 78); then
				debug_code "scancel $chosenjobs"
				eval "scancel $chosenjobs"
				return 0
			fi
		fi
	fi
	return 1
}

function tail_multiple_jobs {
	FAILED=0
	AUTOON=OFF

	if [[ $1 == 'ON' ]]; then
		AUTOON=ON
	fi

	if ! command -v squeue &> /dev/null; then
		red_text "squeue not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v tail &> /dev/null; then
		red_text "tail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v whiptail &> /dev/null; then
		red_text "whiptail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v screen &> /dev/null; then
		red_text "screen not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if [[ $FAILED == 0 ]]; then
		TJOBS=$(get_squeue_from_format_string "'%A' '%j (%t, %M)' $AUTOON")
		chosenjobs=$(eval "whiptail --title 'Which jobs to tail?' --checklist 'Which jobs to choose for tail?' $WIDTHHEIGHT $TJOBS" 3>&1 1>&2 2>&3)
		if [[ -z $chosenjobs ]]; then
			green_text "No jobs chosen to tail"
		else
			whiptail --title "Tail for multiple jobs with screen" --msgbox "To exit, press <CTRL> <a>, then <\\>" 8 78 3>&1 1>&2 2>&3
			eval "multiple_slurm_tails $chosenjobs"
		fi
	fi
}

function single_job_tasks {
	chosenjob=$1

	if ! command -v scontrol &> /dev/null; then
		red_text "scontrol not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v tail &> /dev/null; then
		red_text "tail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

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
	else
		red_text "Tail does not seem to be installed, not showing 'tail -f' option"
	fi

	jobname=$(get_job_name $chosenjob)
	whiptailoptions="'s)' 'Show log path' $WHYPENDINGSTRING $TAILSTRING $SCANCELSTRING 'm)' 'go to main menu' 'q)' 'quit slurminator'"
	whattodo=$(eval "whiptail --title 'Slurminator >$jobname< ($chosenjob)' --menu 'What to do with job $jobname ($chosenjob)' $WIDTHHEIGHT $whiptailoptions" 3>&2 2>&1 1>&3)
	case $whattodo in
		"s)")
			debug_code "slurmlogpath $chosenjob"
			slurmlogpath $chosenjob
			;;
		"t)")
			chosenjobpath=$(slurmlogpath $chosenjob)
			debug_code "tail -f $chosenjobpath"
			tail -f $chosenjobpath
			;;
		"w)")
			debug_code "whypending $chosenjob"
			whypending $chosenjob
			;;
		"k)")
			if (whiptail --title "Really kill >$jobname< ($chosenjob)?" --yesno "Are you sure you want to kill >$jobname< ($chosenjob)?" 8 78); then
				debug_code "scancel $chosenjob"
				scancel $chosenjob && green_text "$jobname ($chosenjob) killed" || red_text "Error killing $jobname ($chosenjob)"
				return 0
			fi
			;;
		"m)")
			slurminator
			;;
		"c)")
			if (whiptail --title "Really kill with USR1 >$jobname< ($chosenjob)?" --yesno "Are you sure you want to kill >$jobname< ($chosenjob) with USR1?" 8 78); then
				debug_code "scancel --signal=USR1 --batch $chosenjob"
				scancel --signal=USR1 --batch $chosenjob && green_text "$chosenjob killed" || red_text "Error killing $chosenjob"
			fi
			;;
		"q)")
			green_text "Ok, exiting"
			return 0
			;;
	esac
	return 1
}

function get_squeue_from_format_string {
	if ! command -v squeue &> /dev/null; then
		red_text "squeue not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if [[ $FAILED == 0 ]]; then
		for line in $(squeue -u $USER --format $1 | sed '1d'); do 
			echo "$line" | tr '\n' ' '; 
		done
	fi
}

function show_accounting_data {
	FAILED=0
	if ! command -v sreport &> /dev/null; then
		red_text "sreport not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v whiptail &> /dev/null; then
		red_text "whiptail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if [[ $FAILED == 0 ]]; then
		whiptailoptions="'t)' 'Show accounting data as tree' 'o)' 'Show top user accounting' 'm)' 'Show top user accounting for this month'"
		WIDTHHEIGHT="$LINES $COLUMNS $(( $LINES - 18 ))"
		whattodo=$(eval "whiptail --title 'Accounting data' --menu 'Show accounting information' $WIDTHHEIGHT $whiptailoptions" 3>&2 2>&1 1>&3)
		NUMBEROFLINES=$(( $LINES - 5 ))
		case $whattodo in
			"t)")
				debug_code "sreport cluster AccountUtilizationByUser tree"
				sreport cluster AccountUtilizationByUser tree
				;;
			"o)")
				debug_code "sreport user top start=0101 end=0201 TopCount=$NUMBEROFLINES -t hourper --tres=cpu,gpu"
				sreport user top start=0101 end=0201 TopCount=$NUMBEROFLINES -t hourper --tres=cpu,gpu
				;;
			"m)")
				debug_code "sreport user top start=0101 end=0201 TopCount=$NUMBEROFLINES -t hourper --tres=cpu,gpu Start=`date -d "last month" +%D` End=`date -d "this month" +%D`"
				sreport user top start=0101 end=0201 TopCount=$NUMBEROFLINES -t hourper --tres=cpu,gpu Start=`date -d "last month" +%D` End=`date -d "this month" +%D`
				;;
		esac
	else
		red_text "Missing requirements, cannot run show_accounting_data"
	fi
}

function slurminator {
	FAILED=0
	if ! command -v squeue &> /dev/null; then
		red_text "squeue not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v whiptail &> /dev/null; then
		red_text "whiptail not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	if ! command -v scontrol &> /dev/null; then
		red_text "scontrol not found. Cannot execute slurminator without it"
		FAILED=1
	fi

	SCANCELSTRING=""
	if command -v scancel &> /dev/null; then
		SCANCELSTRING="'k)' 'kill multiple jobs'"
	fi

	ACCOUNTINGSTRING=""
	if command -v sreport &> /dev/null; then
		ACCOUNTINGSTRING="'a)' 'Show accounting data'"
	fi

	TAILSTRING=""
	if command -v tail &> /dev/null; then
		if command -v screen &> /dev/null; then
			TAILSTRING="'t)' 'tail multiple jobs' 'e)' 'tail multiple jobs (all enabled by default)'"
		else
			red_text "Screen could not be found, not showing 'tail multiple jobs' option"
		fi
	else
		red_text "Tail does not seem to be installed, not showing 'tail multiple jobs'"
	fi
	

	if [[ $FAILED == 0 ]]; then
		WIDTHHEIGHT="$LINES $COLUMNS $(( $LINES - 8 ))"
		JOBS=$(get_squeue_from_format_string "'%A' '%j (%t, %M)'")
		chosenjob=$(
			eval "whiptail --title 'Slurminator' --menu 'Welcome to Slurminator' $WIDTHHEIGHT $JOBS $SCANCELSTRING $TAILSTRING $ACCOUNTINGSTRING 'r)' 'reload slurminator' 'q)' 'quit slurminator'" 3>&2 2>&1 1>&3
		)

		if [[ $chosenjob == 'q)' ]]; then
			green_text "Ok, exiting"
		elif [[ $chosenjob == 'r)' ]]; then
			slurminator
		elif [[ $chosenjob == 't)' ]]; then
			tail_multiple_jobs
		elif [[ $chosenjob == 'e)' ]]; then
			tail_multiple_jobs ON
		elif [[ $chosenjob == 'k)' ]]; then
			kill_multiple_jobs || slurminator
		elif [[ $chosenjob == 'a)' ]]; then
			show_accounting_data
		else
			{ single_job_tasks $chosenjob } || { single_job_tasks $chosenjobs }
		fi
	else
		red_text  "Missing requirements, cannot run Slurminator"
	fi
}
