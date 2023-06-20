START_INVIS="\x01"
END_INVIS="\x02"
BOLD="$START_INVIS\x1b[1m$END_INVIS"
RED="$START_INVIS\x1b[31m$END_INVIS"
GREEN="$START_INVIS\x1b[32m$END_INVIS"
YELLOW="$START_INVIS\x1b[33m$END_INVIS"
PURPLE="$START_INVIS\x1b[35m$END_INVIS"
CYAN="$START_INVIS\x1b[36m$END_INVIS"
BLUE="$START_INVIS\x1b[38;2;0;127;240m$END_INVIS"
PINK="$START_INVIS\x1b[38;2;255;100;203m$END_INVIS"
PYYELLOW="$START_INVIS\x1b[38;2;255;212;59m$END_INVIS"
LIGHTGREEN="$START_INVIS\x1b[38;2;100;255;100m$END_INVIS"
LIGHTRED="$START_INVIS\x1b[38;2;255;80;100m$END_INVIS"
GREY="$START_INVIS\x1b[38;2;128;128;128m$END_INVIS"
RESET="$START_INVIS\x1b[0m$END_INVIS"
START_TITLE="$START_INVIS\x1b]0;"
END_TITLE="\a$END_INVIS"
CURSOR_SAVE="$START_INVIS\x1b[s"
CURSOR_RESTORE="$START_INVIS\x1b[u"
CURSOR_UP="$START_INVIS\x1b[A"
CURSOR_HOME="$START_INVIS\x1b[G"

if [ "$PS1_MODE" == "text" ]; then
	BRANCH="on"
	NODE_PACKAGE="(node)"
	NODE_INFO="using node"
	PYTHON_PACKAGE="(python)"
	PYTHON_INFO="using python"
	EXEC_DURATION="took "
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
	EXEC_DURATION=""
	RETURN_OK="✓"
	RETURN_FAIL="✗"
	HOST_TEXT=""
	USER_TEXT=""
fi

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
		local branch=$(git branch | grep "^* " | sed "s/^* //")
		local gitinfo="$(printf $BOLD$PINK)[$BRANCH $branch]$(printf $RESET) "
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
		local pkginfo="$(printf $BOLD$YELLOW)[$NODE_PACKAGE $name$version]$(printf $RESET) "
		local nodeinfo="$pkginfo$(printf $BOLD$GREEN)[$NODE_INFO $(nvm current | sed s/^v//)]$(printf $RESET) "
	else
		local nodeinfo=""
	fi


	local setup_py="$(upfind "setup.py")"
	local requirements_txt="$(upfind "requirements.txt")"
	if [ -n "$setup_py" ] || [ -n "$requirements_txt" ]; then
		if [ -n "$setup_py" ]; then
			local name="$(grep "^\s*name\s*=\s*\"[^\"]*\"" "$setup_py" | sed -E "s/^\s*name\s*=\s*\"([^\"]*)\".*/\1/" | head -1)"
			local version="$(grep "^\s*version\s*=\s*\"[^\"]*\"" "$setup_py" | sed -E "s/^\s*version\s*=\s*\"([^\"]*)\".*/\1/" | head -1)"
			if [ -n "$version" ]; then
				local version=" $version"
			fi
		else
			local name="unnamed"
			local version=""
		fi
		local pypkginfo="$(printf $BOLD$YELLOW)[$PYTHON_PACKAGE $name$version]$(printf $RESET) "

		if [ -f "$VIRTUAL_ENV/venv/pyvenv.cfg" ]; then
			local pyversion="$(grep "^version\s*=\s*" "$VIRTUAL_ENV/venv/pyvenv.cfg" | head -1 | sed s/^version\\s*=\\s*//)"
		else
			local pyversion="system"
		fi
		local pyinfo="$pkginfo$(printf $BOLD$PYYELLOW)[$PYTHON_INFO $pyversion]$(printf $RESET) "
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
	if [ -n "$buildinfo" ]; then
		local buildinfo="$(printf $BOLD$PURPLE)[${buildinfo%?}]$(printf $RESET) "
	fi

	local curdir="$(
		( [[ "$PWD" == "$gitroot" ]] && echo "$PWD/" || echo "$PWD" ) |
		( [ -n "$gitroot" ] && sed -E "s|^($gitroot)(.*)|\1$CYAN\2$RESET|" || cat ) |
		sed -E "s|^$HOME|$BOLD$YELLOW~$RESET|" |
		sed -E "s|^/home/([^/]*)|$BOLD$YELLOW~\\1$RESET|"
	)"

	if [[ $command_duration -gt 1000 ]]; then
		local runtime=" $(printf $CYAN)($EXEC_DURATION$(($command_duration / 1000))s)$(printf $RESET)"
	else
		local runtime=""
	fi

	local jobs="$(jobs | wc -l)"
	if [[ "$jobs" == "0" ]]; then
		local jobinfo=""
	else
		if [[ "$jobs" == "1" ]]; then
			local jobinfo="$(printf $BOLD$GREEN)[1 job]$(printf $RESET) "
		else
			local jobinfo="$(printf $BOLD$GREEN)[$jobs jobs]$(printf $RESET) "
		fi
	fi

	local cur_date="$(LC_TIME=en_US.UTF-8 date +'%a, %Y-%b-%d, %H:%M:%S in %Z')"

	printf "$CURSOR_SAVE$CURSOR_UP$CURSOR_HOME"

	if [ -n "$PS1_PREFIX" ]; then
		printf "$BOLD$RED%s$RESET " "$PS1_PREFIX"
	fi

	printf "$BOLD$YELLOW(%s)$RESET " "$HOST_TEXT$HOSTNAME"
	printf "$BOLD$BLUE[%s]$RESET " "$USER_TEXT$USER"
	printf "%s" "$gitinfo$nodeinfo$pypkginfo$pyinfo$buildinfo$jobinfo$curdir$runtime"
	printf "\x1b[$(($COLUMNS - ${#cur_date}))G$GREY$cur_date$RESET"

	printf "$CURSOR_RESTORE"

	rm "/tmp/asyncpromptpid$$"
}

get_shell_ps1() {
	local retcode="$?"

	printf "$START_TITLE%s$END_TITLE" "$PWD"

	if [[ "$retcode" == "0" ]] || [[ "$retcode" == "130" ]]; then
		local retinfo="$(printf $LIGHTGREEN)$RETURN_OK$(printf $RESET) "
	else
		local retinfo="$(printf $LIGHTRED)$RETURN_FAIL$(printf $RESET) "
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
