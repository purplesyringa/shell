START_INVIS="$(echo -ne '\x01')"
END_INVIS="$(echo -ne '\x02')"
ESC="$(echo -ne '\e')"
LF="$(echo -ne '\n')"
BEL="$(echo -ne '\a')"
BOLD="$START_INVIS$ESC[1m$END_INVIS"
RED="$START_INVIS$ESC[31m$END_INVIS"
GREEN="$START_INVIS$ESC[32m$END_INVIS"
YELLOW="$START_INVIS$ESC[33m$END_INVIS"
PURPLE="$START_INVIS$ESC[35m$END_INVIS"
CYAN="$START_INVIS$ESC[36m$END_INVIS"
BLUE="$START_INVIS$ESC[38;2;0;127;240m$END_INVIS"
PINK="$START_INVIS$ESC[38;2;255;100;203m$END_INVIS"
PYYELLOW="$START_INVIS$ESC[38;2;255;212;59m$END_INVIS"
LIGHTGREEN="$START_INVIS$ESC[38;2;100;255;100m$END_INVIS"
LIGHTRED="$START_INVIS$ESC[38;2;255;80;100m$END_INVIS"
GREY="$START_INVIS$ESC[38;2;128;128;128m$END_INVIS"
RESET="$START_INVIS$ESC[0m$END_INVIS"
START_TITLE="$START_INVIS$ESC]0;"
END_TITLE="$BEL$END_INVIS"
CURSOR_SAVE="$START_INVIS$ESC[s"
CURSOR_RESTORE="$START_INVIS$ESC[u"
CURSOR_UP="$START_INVIS$ESC[A"
CURSOR_HOME="$START_INVIS$ESC[G"

if [ "$PS1_MODE" == "text" ]; then
	BRANCH="on"
	NODE_PACKAGE="node:"
	NODE_INFO="node"
	PYTHON_PACKAGE="py:"
	PYTHON_INFO="py"
	EXEC_DURATION="took"
	RETURN_OK="OK"
	RETURN_FAIL="Failed"
	HOST_TEXT="at "
	USER_TEXT="as "
else
	BRANCH=""
	NODE_PACKAGE=""
	NODE_INFO=""
	PYTHON_PACKAGE=""
	PYTHON_INFO=""
	EXEC_DURATION=""
	RETURN_OK="✓"
	RETURN_FAIL="✗"
	HOST_TEXT=""
	USER_TEXT=""
fi

INVALID_HOMES='^(/$|(/bin|/dev|/proc|/usr|/var)[/$])'


replace_home() {
	local answer=$1
	while IFS= read -r line; do
		if [[ $line =~ ([^:]*):([^:]*:){4}([^:]*):([^:]*) ]] || true; then
			local homedir="${BASH_REMATCH[3]}"
			local username="${BASH_REMATCH[1]}"
			local userpath="$BOLD$YELLOW~$username$RESET"
			if [[ ! $homedir =~ $INVALID_HOMES ]]; then
				local path="$1"
				local stripped_path="${path#$homedir}"
				if [[ "$stripped_path" != "$path" ]]; then
					answer="$userpath$stripped_path"
				fi
			fi
		fi
	done < /etc/passwd
	echo $answer
}

upfind() {
	local path="$PWD"
	while [[ "$path" != "/" ]] && [[ ! -e "$path/$1" ]]; do
		local path="$(realpath "$path"/..)"
	done
	if [[ -e "$path/$1" ]]; then
		echo "$path/$1"
	else
		return 1
	fi
}

get_current_time() {
	date +%s%3N
}

before_command_start() {
	async_prompt_pid=$(cat "/tmp/asyncpromptpid$$" 2>/dev/null)
	if [ -n "$async_prompt_pid" ]; then
		kill "$async_prompt_pid"
	fi
	start_time="${start_time:-"$(get_current_time)"}"
	previous_pwd_tmp="${previous_pwd_tmp:-"$PWD"}"
}

update_info() {
	command_duration="$(($(get_current_time) - $start_time))"
	previous_pwd="$previous_pwd_tmp"
	unset start_time
	unset previous_pwd_tmp
}

async_prompt() {
	exec >&2

	local gitroot="$(git rev-parse --show-toplevel 2>/dev/null)"
	if [ -n "$gitroot" ]; then
		local branch=$(git branch | rg "^\* " -r "")
		local gitinfo="$BOLD$PINK[$BRANCH $branch]$RESET "
	else
		local gitinfo=""
	fi

	local package_json="$(upfind "package.json")"
	local node_modules="$(upfind "node_modules")"
	if [ -n "$package_json" ] || [ -n "$node_modules" ]; then
		if [ -n "$package_json" ]; then
			local name="$(jq -r .name "$package_json")"
			local version=" $(jq -r .version "$package_json")"
		else
			local name="unnamed"
			local version=""
		fi
		local pkginfo="$BOLD$YELLOW[$NODE_PACKAGE $name$version]$RESET "
		local nodeinfo="$pkginfo$BOLD$GREEN[$NODE_INFO $(nvm current | sed s/^v//)]$RESET "
	else
		local nodeinfo=""
	fi


	local setup_py="$(upfind "setup.py")"
	local requirements_txt="$(upfind "requirements.txt")"
	if [ -n "$setup_py" ] || [ -n "$requirements_txt" ]; then
		if [ -n "$setup_py" ]; then
			local name="$(rg "name=['\"](.+)['\"]" $setup_py -or '$1' -m 1)"
			local version="$(rg "version=['\"](.+)['\"]" $setup_py -or '$1' -m 1)"
			if [ -n "$version" ]; then
				local version=" $version"
			fi
		else
			local name="unnamed"
			local version=""
		fi
		local pypkginfo="$BOLD$YELLOW[$PYTHON_PACKAGE $name$version]$RESET "

		if [ -f "$VIRTUAL_ENV/pyvenv.cfg" ]; then
			local pyversion="$(rg 'version\s*=\s*' "$VIRTUAL_ENV/pyvenv.cfg" -r '' -m 1)"
		else
			local pyversion="system"
		fi
		local pyinfo="$pkginfo$BOLD$PYYELLOW[$PYTHON_INFO $pyversion]$RESET "
	else
		local pypkginfo=""
		local pyinfo=""
	fi

	local buildinfo=""
	if [ -f CMakeLists.txt ]; then
		local buildinfo="${buildinfo}cmake "
	fi
	if [ -f configure ]; then
		local buildinfo="${buildinfo}./configure "
	fi
	if [ -f Makefile ]; then
		local buildinfo="${buildinfo}make "
	fi
	if [ -f install ]; then
		local buildinfo="${buildinfo}./install "
	fi
	if [ -f jr ]; then
		local buildinfo="${buildinfo}./jr "
	fi
	if compgen -G "*.qbs" > /dev/null; then
		local buildinfo="${buildinfo}qbs "
	fi
	if compgen -G "*.pro" > /dev/null; then
		local buildinfo="${buildinfo}qmake "
	fi
	if [ -n "$buildinfo" ]; then
		local buildinfo="$BOLD$PURPLE[${buildinfo%?}]$RESET "
	fi

	local curdir="$(
		( [[ "$PWD" == "$gitroot" ]] && echo "$PWD/" || echo "$PWD" ) |
		( [ -n "$gitroot" ] && rg "^($gitroot)(.*)" -r "\$1$CYAN\$2$RESET" || cat ) |
		rg "^$HOME" -r "$BOLD$YELLOW~$RESET" --passthru
	)"
	local curdir="$(replace_home $curdir)"

	if [[ $command_duration -gt 1000 ]]; then
		local runtime=" $CYAN($EXEC_DURATION $(($command_duration / 1000))s)$RESET"
	else
		local runtime=""
	fi

	local jobs="$(jobs | wc -l)"
	if [[ "$jobs" == "0" ]]; then
		local jobinfo=""
	else
		if [[ "$jobs" == "1" ]]; then
			local jobinfo="$BOLD$GREEN[1 job]$RESET "
		else
			local jobinfo="$BOLD$GREEN[$jobs jobs]$RESET "
		fi
	fi

	local cur_date="$(LC_TIME=en_US.UTF-8 date +'%a, %Y-%b-%d, %H:%M:%S in %Z')"

	echo -n "$CURSOR_SAVE$CURSOR_UP$CURSOR_HOME"

	if [ -n "$PS1_PREFIX" ]; then
		echo -n "$BOLD$RED$PS1_PREFIX$RESET "
	fi

	echo -n "$BOLD$YELLOW($HOST_TEXT$HOSTNAME)$RESET $BOLD$BLUE[$USER_TEXT$USER]$RESET "
	echo -n "$gitinfo$nodeinfo$pypkginfo$pyinfo$buildinfo$jobinfo$curdir$runtime"
	echo -n "$ESC[$(($COLUMNS - ${#cur_date}))G$GREY$cur_date$RESET"

	echo -n "$CURSOR_RESTORE"

	rm "/tmp/asyncpromptpid$$"
}

get_shell_ps1() {
	local retcode="$?"

	echo -n "$START_TITLE$PWD$END_TITLE"

	if [[ "$retcode" == "0" ]] || [[ "$retcode" == "130" ]]; then
		local retinfo="$LIGHTGREEN$RETURN_OK$RESET "
	else
		local retinfo="$LIGHTRED$RETURN_FAIL$RESET "
	fi

	if [[ "$UID" == "0" ]]; then
		local cursor="$BOLD$RED#$RESET"
	else
		local cursor="$BOLD$GREEN\$$RESET"
	fi

	printf "\n\n$retinfo$cursor "
	async_prompt >/dev/null &
	echo "$!" >"/tmp/asyncpromptpid$$"
}


trap "before_command_start" DEBUG
PROMPT_COMMAND=update_info
PS1='$(get_shell_ps1)'

VIRTUAL_ENV_DISABLE_PROMPT=1
