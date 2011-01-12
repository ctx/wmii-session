#!/bin/dash

 # config           {{{

# places
WI_BOOKMARKS="$HOME/.config/surfraw/bookmarks"
WI_DATAFOLDER="$XDG_DATA_HOME/sessions"

# commands
WI_PDF="zathura"
WI_URL="surf"
WI_TERM="urxvtc"
WI_MENU="wimenu"
WI_MENUVERTICAL="dmenu -l 52 -nb #3f3f3f -nf #dcdccc -sf #3f3f3f -sb #f0dfaf \
	-fn '-xos4-terminus-medium-*-*-*-12-*-*-*-*-*-iso8859-2'"

# surfraw
SR_DIRECT="g"
SR_DEFAULT="google"

#}}} 

# stuff            {{{ 

# winids of tabbed containers
WI_IDFILE="$(wmiir namespace)/idlist"
# surfraw elvis
export WI_ELVIFILE="$(wmiir namespace)/elvilist"

# container names
URLMARK="html"
PDFMARK="pdf"

# }}}

# apply settings   {{{
# 
# if [ $WI_URL="surf" ];then
# 	OPENURLSESSION="wi_open_surf_session"
# 	CLOSEURLSESSION="wi_close_surf"
# 	OPENURL="wi_open_surf"
# fi
# if [ $WI_PDF="zathura" ];then
# 	OPENPDFSESSOIN="wi_open_zathura_session"
# 	CLOSEPDFSESSION="wi_close_zathura"
# 	OPENPDF="wi_open_zathura"
# fi
# 
# }}}

#  taskwarrior      {{{

# a vertical menu of all tasks to select one
wi_taskmenu() {
	task=`task minimal | tail -n +4 | head -n -2 | $WI_MENUVERTICAL -p "$1" | \
		awk '{print $1}'`
	uuid=`task $task | grep UUID | \
		sed 's/UUID//;s/ //g'`
	echo "$task $uuid"
}

#}}}

# wmii             {{{

# switch to new tag
wi_newtag() {
	wmiir xwrite /ctl view "$@"
}

# list current tag
wi_seltag() {
	wmiir cat /tag/sel/ctl | head -n 1
}

# list all tags
wi_listtag() {
	wmiir ls /tag | sed 's/\/$//g;/^sel$/x;/^$/d'
}

# return previous tag
wi_prevtag () {
	tag="$(wi_seltag)"
	prevtag="$(wi_listtag | grep -B 1 -x $tag | grep -vx $tag)"
	if [ ! $prevtag ];then
		prevtag="$(wi_listtag | tail -n 1)"
	fi
	echo $prevtag
}

# return next tag
wi_nexttag () {
	tag=$(wi_seltag)
	nexttag=$(wi_listtag | grep -A 1 -x $tag | grep -vx $tag)
	if [ ! $nexttag ];then
		nexttag="$(wi_listtag | head -n 1)"
	fi
	echo $nexttag
}

# add current path to current tag
wi_add_path() {
	mkdir -p $(wmiir namespace)/$(wi_seltag)
	pwd >> $(wmiir namespace)/$(wi_seltag)/path
}

wi_remove_path() {
	path=$($WI_MENU -p "remove path:" <$(wmiir namespace)/$(wi_seltag)/path)
	if [ -n "$path" ];then
		tmp=$(cat $(wmiir namespace)/$(wi_seltag)/path | grep -v -e "$path")
		echo $tmp > $(wmiir namespace)/$(wi_seltag)/path
	fi
}

wi_terminal_one() {
	if [ -f "$(wmiir namespace)/$(wi_seltag)/path" ];then
		path=$(cat $(wmiir namespace)/$(wi_seltag)/path | awk 'FNR == 1')
		if [ -n "$path" ];then
			urxvtc -cd $path
		else
			urxvtc
		fi
	fi
}

wi_terminal_two() {
	if [ -f "$(wmiir namespace)/$(wi_seltag)/path" ];then
		path=$(cat $(wmiir namespace)/$(wi_seltag)/path | awk 'FNR == 2')
		if [ -n "$path" ];then
			urxvtc -cd $path
		else
			urxvtc
		fi
	fi
}

# }}} 

# vim              {{{

# open a vim session
# arg: session file
wi_open_vim() {
	$WI_TERM -e vim --servername "$(wi_seltag)" \
	-S "$WI_DATAFOLDER/$WI_SESSIONNAME/$@"
}

wi_open_vim_sessions() {

	vimsessions="$(ls $WI_DATAFOLDER/$WI_SESSIONNAME 2>/dev/null| \
		grep vim 2>/dev/null)"
	for vimsession in $vimsessoins 
	do
		wi_open_vim $vimsession
	done
}

# close vimsessions of current tag
wi_close_vim() {
	vimservers=$(vim --serverlist | grep -i "$(wi_seltag)")
	for vimserver in $vimservers
	do
		sessionpath="$WI_DATAFOLDER/$WI_SESSIONNAME/vim$vimserver"
		vim --remote-send \
			'<Esc>:wa<CR>:mks '${sessionpath}'<CR>:wqa<CR>' \
			--servername $vimserver 
	done
}

# }}} 

# tabbed           {{{

# start new tabbed interface
# arg1: name
# arg2: tag
wi_tabbed() {
	echo "$1$2" | tr "\n" " " >> $WI_IDFILE
	tabbed 2>/dev/null | head -n 1 >> $WI_IDFILE
	sed -i "/"${1}${2}"/d" $WI_IDFILE
}

# }}} 

# surf             {{{

# open a new instance of surf in a tabbed interface on the selected tag
# arg: the url to open
wi_open_surf() {
	tag=$(wi_seltag)
	if [ -z "$(grep -e "$URLMARK$tag" "$WI_IDFILE")" ];then
		wi_tabbed $URLMARK $tag &
		sleep 0.1
	fi
	cid=$(grep -e "$URLMARK$tag" "$WI_IDFILE" | cut -d " " -f 2)
	surf -e "$cid" $1 &
}

# open surf session
wi_open_surf_session() {
	if [ -f $WI_DATAFOLDER/$WI_SESSIONNAME/surf ];then
		for url in $(cat $WI_DATAFOLDER/$WI_SESSIONNAME/surf)
		do
			wi_open_surf $url
		done
	fi
}
# close all instances of surf on the selected tag
wi_close_surf() {
	tag=$(wi_seltag)
	ids=$(awk '$1 ~/'$URLMARK$tag'/ {print $2}' $WI_IDFILE)
	for id in $ids
	do
		childs=`xwininfo -children -id $id | \
				tail -n +7 | cut -d " " -f 6`
		for child in $childs
		do
			file=`xprop -id $child | \
				grep "_SURF_URI(STRING)" | \
				sed 's/^.* = //;s/\"//g'`
			xkill -id $child
			if [ "$file" ]; then
				echo "$file" >> \
				"$WI_DATAFOLDER/$WI_SESSIONNAME/surf"
			fi
		done

		xkill -id $id
	done
}

# }}}

# zathura          {{{

# open a new instance of zathura in a tabbed interface on the selected tag
# arg: the pdf file to open
wi_open_zathura() {
	tag=$(wi_seltag)
	if [ -z "$(grep -e "$PDFMARK$tag" "$WI_IDFILE")" ];then
		wi_tabbed $PDFMARK $tag &
		sleep 0.1
	fi
	cid=$(grep -e "$PDFMARK$tag" "$WI_IDFILE" | cut -d " " -f 2)
	zathura -e "$cid" "$@" &
}

# open zathura session
wi_open_zathura_session() {
	if [ -f $WI_DATAFOLDER/$WI_SESSIONNAME/surf ];then
		IFS="
"
		for pdf in $(cat $WI_DATAFOLDER/$WI_SESSIONNAME/zathura)
		do
			wi_open_zathura "$pdf"
		done
		unset IFS
	fi
}

# close all instances of zathura on the selected tag
wi_close_zathura() {
	tag=$(wi_seltag)
	ids=$(awk '$1 ~/'$PDFMARK$1'/ {print $2}' $WI_IDFILE)
	for id in $ids
	do
		childs=`ps -u $USER -o pid -o cmd | grep $id | \
			grep -v grep | sed 's/^[ ]*//g'`
		IFS="
"
		for child in $childs
		do
			file=`echo $child | cut -d " " -f5-`
			pid=`echo $child | cut -d " " -f 1`
			kill $pid
			if [ "$file" ]; then
				echo "$file" >> \
				"$WI_DATAFOLDER/$WI_SESSIONNAME/zathura"
			fi
		done
		unset IFS
		xkill -id $id
	done
}

# }}}

# surfraw          {{{

# update searchmachines and bookmarks
wi_updateelvi() {
	sr -elvi | grep -v "GLOBAL" | grep -v "Activate Surfraw defined" | \
		cut -f 1 >$WI_ELVIFILE
	cat $WI_BOOKMARKS | cut -f 1 | sort >> $WI_ELVIFILE
}

# searchmachines and bookmarks menu
wi_srmenu() {
	search="$($WI_MENU -p "search the web:" <$WI_ELVIFILE)"
	if [ "$search" ]; then
		elvi=`echo $search | cut -d " " -f 1`
		if [ "$SR_DIRECT" = "$elvi" ]; then
			 url=$(echo "$search" | sed -e "s/^"${SR_DIRECT}" //")
		elif [ "`grep -e "$elvi" "$WI_ELVIFILE"`" ]; then
			url=$(sr -p $search)
		else
			url=$(sr -p $SR_DEFAULT $search)
		fi
		wi_open_surf $url
	fi
}

#  }}} 

# open             {{{

# arg: session name
wi_open_session() {
	WI_SESSIONNAME="$1"
	if [ -n "$WI_SESSIONNAME" ];then
		wi_open_vim_sessions
		wi_open_surf_session
		wi_open_zathura_session
		mkdir $(wmiir namespace)/$(wi_seltag)
		if [ -f $WI_DATAFOLDER/$WI_SESSIONNAME/path ];then
			cp $WI_DATAFOLDER/$WI_SESSIONNAME/path $(wmiir namespace)/$(wi_seltag)/path
		fi
		wi_terminal_one
		wi_terminal_two
		#$OPENTXT
	fi
}

wi_open_session_menu() {
	name="$(ls $WI_DATAFOLDER | $WI_MENU -p "open session:")"
	if [ -n "$name" ];then
		wi_newtag $name
		wi_open_session $name
	fi
}


wi_open_task() {
	string="$(wi_taskmenu "open task:")"
	taskid="$(echo $string | cut -d " " -f 1)"
	taskuuid="$(echo $string | cut -d " " -f 2)"
	if [ -n "$taskid" -a -n "$taskuuid" ];then
		wi_newtag "task $taskid"
		wi_open_session $taskuuid
	fi
}

# }}}

# close            {{{

wi_close_session() {
	WI_SESSIONNAME="$1"
	if [ -n "$WI_SESSIONNAME" ];then
		if [ -d "$WI_DATAFOLDER/$WI_SESSIONNAME" ];then
			mv "$WI_DATAFOLDER/$WI_SESSIONNAME" \
			"$WI_DATAFOLDER/$WI_SESSIONNAME$(date +%M%l%j%y)"
		fi
		mkdir $WI_DATAFOLDER/$WI_SESSIONNAME
		wi_close_vim
		wi_close_surf
		wi_close_zathura
		pathfile="$(wmiir namespace)/$wi_seltag)/path"
		if [ -n "$pathfile" ];then
			mv $(wmiir namespace)/$(wi_seltag)/path $WI_DATAFOLDER/$WI_SESSIONNAME/path
		fi
	fi
}

wi_close_session_menu() {
	name="$(ls $WI_DATAFOLDER | $WI_MENU -p "close session:")"
	if [ -n "$name" ];then
		wi_close_session $name
	fi
}

wi_close_task() {
	string="$(wi_taskmenu "close task:")"
	taskuuid="$(echo $string | cut -d " " -f 2)"
	if [ -n "$taskuuid" ];then
		wi_close_session $taskuuid
	fi
}
# }}}

# other            {{{

wi_delete_session() {
	name="$(ls $WI_DATAFOLDER | $WI_MENU -p "delete session:")"
	if [ -n "$name" ];then
		rm -rf $WI_DATAFOLDER/$name
	fi
}

wi_pdfmenu_one() {
	path=$(cat $(wmiir namespace)/$(wi_seltag)/path | awk 'FNR == 1')
	if [ -n "$path" ];then
		file="$(find $path -name "*.pdf" | sort | $WI_MENUVERTICAL)"
		if [ -n "$file" ];then
			wi_open_zathura "$file"
		fi
	fi
}

wi_pdfmenu_two() {
	path=$(cat $(wmiir namespace)/$(wi_seltag)/path | awk 'FNR == 2')
	if [ -n "$path" ];then
		file="$(find $path -name "*.pdf" | sort | $WI_MENUVERTICAL)"
		if [ -n "$file" ];then
			wi_open_zathura "$file"
		fi
	fi
}

# }}}

