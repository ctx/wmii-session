#!/bin/dash

# config           {{{

# places session
WI_DATAFOLDER="$XDG_DATA_HOME/session"
WI_PROJECTFOLDER="$WI_DATAFOLDER/project"
WI_BACKUPFOLDER="$WI_DATAFOLDER/backup"
WI_TASKFOLDER="$WI_DATAFOLDER/task"
WI_TEMPFOLDER="$(wmiir namespace)"

# List of used applications with session support.
# This is the name of two functions whitch must exist:
# wi_$APP_open_session 
# wi_$APP_close_sessions
WI_APPLICATIONS='vim chromium'

# List of applications embedded in tabbed.
WI_URL='vimprobable2 browser'
WI_PDF='zathura viewer'


# places browser
WI_BOOKMARKS="$HOME/.config/surfraw/bookmarks"
WI_ELVIFILE="$WI_TEMPFOLDER/elvilist"

# surfraw go to url shortcut
SR_DIRECT="g"
# surfraw default searchengine
SR_DEFAULT="google"

# menu commands
WI_MENU="wimenu"
WI_MENUVERTICAL="dmenu -l 10" 

WMII_TERM="urxvtc"
# used to close terminals on close session
WI_TERMNAME="urxvt:URxvt"

#}}} 

# language         {{{
ERROR_NO_SUCH_SESSION="Error: No saved session with name "
ERROR_NO_NAME_SPECIFIED="Error: No name specified."
ERROR_NO_SUCH_TASK="Error: Cannot find task "
ERROR_NO_SUCH_FILE="Error: Cannot find file "
ERROR_MISSING_URI_SUPPORT="Error: This application has no ATOM calld _URI(STRING): "
# }}}

# taskwarrior      {{{

wi_task_uuid() {
	task info $1 | awk '/UUID/{print $2}'
}


wi_task_cli_open() {
	task="$1"
	if ! [ -n "$1" ];then
                echo $ERROR_NO_NAME_SPECIFIED 1>&2
                return 1
        fi
        wi_task_open $task
}

wi_task_cli_close() {
	task="$1"
	if ! [ -n "$1" ];then
                echo $ERROR_NO_NAME_SPECIFIED 1>&2
                echo Open Sessions
                task active
                return 1
        fi
        wi_task_close $task
}

wi_task_menu() {
	task minimal | tail -n +4 | head -n -2 | \
		$WI_MENUVERTICAL -p "$1" | cut -f1 -d\ 
}

wi_task_menu_open() {
	wi_task_open $(wi_task_menu)
}

wi_task_menu_close() {
	wi_task_close $(wi_task_menu)
}

#}}}

# wmii             {{{

# switch to new tag
wi_newtag() {
	wmiir xwrite /ctl view "$@"
}

# list current tag
wi_seltag() {
	wmiir cat /tag/sel/ctl | sed '1q'
}

# kill all terminals an go to tag one
wi_finish_closing() {
	tag="$(wi_seltag)"
	terms=$(wmiir cat /tag/sel/index | grep $WI_TERMNAME | cut -f2 -d\ )
	wmiir xwrite /ctl view 1

	rm -rf "$WI_TEMPFOLDER/$tag"

	for term in $terms;do
		wmiir xwrite /client/$term/ctl kill
	done
}

# }}} 

# vim              {{{

# open a vim session
# arg1: session file (the file/the folder)
# arg2: temporary session dir (place for temporary data)
wi_vim_open_session() {
	session="$1"
	dir="$2"
	$WMII_TERM -e vim --servername "$(wi_seltag)" \
	-S "$session"
}

# close vim session
# arg1: temporary session dir (src)
# arg2: place to store the session (dest)
wi_vim_close_session() {
	src="$1"
	dest="$2"
	vimservers=$(vim --serverlist | grep -i "$(wi_seltag)")
	for vimserver in $vimservers
	do
		sessionfile="$dest/vim-$vimserver"
		vim --remote-send \
			'<Esc>:wa<CR>:mks '${sessionfile}'<CR>:wqa<CR>' \
			--servername $vimserver 
	done
}

# }}} 

# chromium         {{{

# open a chromium session
# arg1: session file (the file/the folder)
# arg2: temporary session dir (place for temporary data)
wi_chromium_open_session() {
	session="$1"
	dir="$2/chromium"
	cp -R $session $dir
	chromium --user-data-dir="$dir" &
	echo $! > "$dir/pid"
}

# close chromium session
# arg1: temporary session dir (src)
# arg2: place to store the session (dest)
wi_chromium_close_session() {
	source="$1/chromium"
	destination="$2"
	kill $(cat $source/pid)
	sleep 1
	mv $source $destination
}

# }}}

# tabbed           {{{

# start new tabbed interface
# arg1: name
# arg2: cmd
# arg3: tag
wi_tabbed() {
	name="$1"
	cmd="$2"
	tag="$3"
	dir="$WI_TEMPFOLDER/$tag"
	file="tabbed-$cmd-$name"
	if ! [ -d $dir ]; then
		mkdir $dir
	fi
	tabbed 2>/dev/null | sed '1q' > $dir/$file
	rm $dir/$file
	return 0
}

# open tab in existing tabbed
# arg1: cmd
# arg2: name
# arg3: path to file/url
wi_tabbed_open_tab() {
	cmd="$1"
	name="$2"
	url="$3"
	tag="$(wi_seltag)"
	idfile="$WI_TEMPFOLDER/$tag/tabbed-$cmd-$name"
	if ! [ -f "$idfile" ];then
		wi_tabbed "$name" "$cmd" "$tag" &
		sleep 0.2
	fi
	cid="$(cat $idfile)"
	${cmd} -e "$cid" "$url" 2>/dev/null &
	return 0
}

# arg1: name
# arg2: cmd
wi_tabbed_open_session() {
	cmd="$1"
	name="$2"
	file="$WI_PROJECTFOLDER/$WI_SESSIONNAME/tabbed-$cmd-$name"
	if ! [ -f $file ];then
                echo $ERROR_NO_SUCH_FILE $file
                return 1
        fi
        while read url;do
                wi_tabbed_open_tab "$cmd" "$name" "$url"
        done < "$file"
}

#arg1: idfile
wi_tabbed_close_session() {
	file="$1"
	id="$(cat $file)"
	filename="$(basename $1)"

	childs="$(xwininfo -children -id $id | \
		tail -n +7 | cut -d " " -f 6)"
	for child in $childs; do
		uri="$(xprop -id $child | grep "_URI(STRING)" | \
			sed 's/^.* = //
			     s/\"//g')"
		xkill -id $child
		if [ -n "$uri" ]; then
			echo "$uri" >> \
				"$WI_PROJECTFOLDER/$WI_SESSIONNAME/$filename"
		else
			 echo $ERROR_MISSING_URI_SUPPORT $filename 1>&2
		fi
	done
	xkill -id $id
}

# }}} 

# surfraw          {{{

# update searchmachines and bookmarks
wi_update_elvi() {
	sr -elvi | grep -v -e "GLOBAL" -e "LOCAL" -e "Activate Surfraw defined" | \
		cut -f 1 >$WI_ELVIFILE
	cut -f 1 $WI_BOOKMARKS | sort >> $WI_ELVIFILE
}

# searchmachines and bookmarks menu
wi_surfraw_menu() {
	search="$($WI_MENU -p "search the web:" <$WI_ELVIFILE)"
	if ! [ "$search" ]; then
                return 1
        fi
        elvi=${search%% *}
        if [ "$SR_DIRECT" = "$elvi" ]; then
                url="${search#* }"
	elif [ "$(grep -x -e "$elvi" "$WI_ELVIFILE")" ]; then
                url="$(sr -p $search)"
        else
                url="$(sr -p $SR_DEFAULT $search)"
        fi
        wi_tabbed_open_tab $WI_URL "$url"
}

#  }}} 

# open             {{{

# arg: session name
wi_session_open() {
	WI_SESSIONNAME="$1"
	if ! [ -n "$WI_SESSIONNAME" ];then
                echo $ERROR_NO_NAME_SPECIFIED 1>&2
                wi_projects_show
                return 1
        fi
        
        tag="$2"
        if ! [ -n "$tag" ]; then
                tag="$WI_SESSIONNAME"
        fi

        src="$WI_PROJECTFOLDER/$WI_SESSIONNAME"
        if ! [ -d $src ];then
                echo $ERROR_NO_SUCH_SESSION $1. 1>&2
                return 1
        fi

        wi_newtag $tag

        dest="$WI_TEMPFOLDER/$tag"
        mkdir -p $dest
        for f in $(ls -1 $src);do
                case $f in
                        path|history)
                                cp "$src/$f" "$dest/$f"
                                ;;
                        tabbed*)
                                wi_tabbed_open_session \
                                        $(echo ${f#*-} | tr "-" " ")
                                ;;
                        *)
                                cmd="${f%-*}"
                                wi_${cmd}_open_session "$src/$f" "$dest"
                                ;;
                esac
        done

        wi_terminal_one
        wi_terminal_two
}

wi_session_open_menu() {
	name="$(ls $WI_PROJECTFOLDER | $WI_MENU -p "open session:")"
	if ! [ -n "$name" ];then
                return 1
        fi
        wi_session_open $name
}


wi_task_open() {
	task="$1"
	taskuuid="$(wi_task_uuid $task)"
	if ! [ -n "$task" -a -n "$taskuuid" ];then
                echo $ERROR_NO_SUCH_TASK $1. 1>&2
                return 1
        fi

        task $task start

        if [ -d $WI_TASKFOLDER/$taskuuid ];then
                cp -R $WI_TASKFOLDER/$taskuuid $WI_PROJECTFOLDER
        else
                project=$(task $task | grep Project | sed 's/^.* //g')
                mainproject=$(echo $project | sed 's/\..*$//g')
                while [ ".$project" != "." ];do
                        if [ -d $WI_PROJECTFOLDER/$project ]; then
                                cp -R $WI_PROJECTFOLDER/$project $WI_PROJECTFOLDER/$taskuuid
                                break
                        fi
                        if [ "$project" != "$mainproject" ];then
                                project=$(echo $project | sed 's/\.[^.]*$//g')
                        else
                                project=""
                        fi
                done

        fi
        if [ -d $WI_PROJECTFOLDER/$taskuuid ];then
                wi_session_open $taskuuid "task$task"
                sleep 2
                rm -r $WI_PROJECTFOLDER/$taskuuid
        else 
                wi_newtag "task$task"
        fi
}

# }}}

# close            {{{

wi_session_save() {
	WI_SESSIONNAME="$1"
	tag=$(wi_seltag)
	
	if ! [ -n "$WI_SESSIONNAME" ];then
                echo $ERROR_NO_NAME_SPECIFIED 1>&2
                return 1
        fi

        src="$WI_TEMPFOLDER/$tag"
        dest="$WI_PROJECTFOLDER/$WI_SESSIONNAME"

        # backup resent session folder
        if [ -d "$dest" ];then
                mv "$dest" "$WI_BACKUPFOLDER/$WI_SESSIONNAME$(date +-%N-%m-%d-%y)"
        fi
        mkdir $dest

        # save sessions
        for cmd in $WI_APPLICATIONS;do
                wi_${cmd}_close_session "$src" "$dest"
        done

        # backup files
        for f in $(ls -1 $src);do
                case $f in 
                        path|history)
                                mv $src/$f $dest/$f
                                ;;
                        tabbed*)
                                wi_tabbed_close_session $src/$f
                                ;;
                        *)
                                echo error unhandled case
				return 1
				;;
                esac
        done

	return 0
}

wi_session_close() {
	
	if wi_session_save "$@";then
                wi_finish_closing
        fi
}
        


wi_session_close_menu() {
	name="$(ls $WI_PROJECTFOLDER | $WI_MENU -p "close session:")"
	if [ -n "$name" ];then
		wi_session_close $name
	fi
}

wi_task_close() {
	task="$1"
        taskuuid="$(wi_task_uuid $task)" 
        if ! [ -n "$taskuuid" ];then
                echo $ERROR_NO_SUCH_TASK $1. 1>&2
                return 1
        fi

        wi_session_save $taskuuid

        if [ -d $WI_TASKFOLDER/$taskuuid ];then
                mv $WI_TASKFOLDER/$taskuuid \
                        $WI_BACKUPFOLDER/$taskuuid-$(date +-%N-%m-%d-%y)
        fi

        mv $WI_PROJECTFOLDER/$taskuuid $WI_TASKFOLDER/$taskuuid
        task $task +session
        task $task stop
        wi_finish_closing
}

# }}}

# path             {{{

# add current path to current tag
wi_add_path() {
	mkdir -p $WI_TEMPFOLDER/$(wi_seltag)
	pwd >> $WI_TEMPFOLDER/$(wi_seltag)/path
}

# menu to select the path to remove
wi_remove_path() {
	path=$($WI_MENU -p "remove path:" <$WI_TEMPFOLDER/$(wi_seltag)/path)
	if [ -n "$path" ];then
		sed -i "\|^${path}$|d" $WI_TEMPFOLDER/$(wi_seltag)/path
	fi
}

wi_terminal_one() {
	if ! [ -f "$WI_TEMPFOLDER/$(wi_seltag)/path" ];then
                # nothing to do
                return 0
        fi
        path=$(cat $WI_TEMPFOLDER/$(wi_seltag)/path | awk 'FNR == 1')
        if [ -n "$path" ];then
                ${WMII_TERM} -cd "$path"
        fi
}

wi_terminal_two() {
	if [ -f "$WI_TEMPFOLDER/$(wi_seltag)/path" ];then
		path=$(cat $WI_TEMPFOLDER/$(wi_seltag)/path | awk 'FNR == 2')
		if [ -n "$path" ];then
			${WMII_TERM} -cd "$path"
		fi
	fi
}

# }}}

# other            {{{

wi_session_create_helpertag() {
	tag=$(wi_seltag)
	newtag="${tag}-I"
	wi_newtag "$newtag"
	ln -s $WI_TEMPFOLDER/$tag "$WI_TEMPFOLDER/$newtag"
}

wi_session_show() {
	folder="$WI_TEMPFOLDER/$(wi_seltag)"
	for f in $(ls -1 $folder); do
		echo "$f"
		tail "$folder/$f"
		echo 
	done
}

wi_projects_show() {
	ls -1 $WI_PROJECTFOLDER
}

wi_make_directories() {
	( ! [ -d $WI_DATAFOLDER ]    && mkdir $WI_DATAFOLDER ) && \
	( ! [ -d $WI_PROJECTFOLDER ] && mkdir $WI_PROJECTFOLDER ) && \
	( ! [ -d $WI_BACKUPFOLDER ]  && mkdir $WI_BACKUPFOLDER ) && \
	( ! [ -d $WI_TASKFOLDER ]    && mkdir $WI_TASKFOLDER ) && \
	( ! [ -d $WI_TEMPFOLDER ]    && mkdir $WI_TEMPFOLDER )
}

# }}}

# create the directories if the don't exist
wi_make_directories


