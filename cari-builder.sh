#!/bin/bash

# CARI Builder is a Bash script used to build the CARI wallet (CLI, daemon and GUI)
# for several operating systems using cross compilation on Ubuntu.
# 
# Run the script with the argument "-h" for usage details.

################################################################################
# INIT
################################################################################

export LC_ALL=C.UTF-8

T1=$(date +%s)

declare -A FORMAT=(
	[ok]=$'\033[1;42m'              # Bold; green background
	[err]=$'\033[1;41m'             # Bold; red background
	[def]=$(tput sgr0 2> /dev/null) # Default
)

N=$'\n'

declare -r T1 FORMAT N

################################################################################
# FUNCTIONS
################################################################################

# Copy sample binaries in the default path.
copy_sample_bin() {
	local parent suffix
	
	# ------------------
	
	parent="$TMP_CARI_BUILDER/cari-$MAKE_HOST_HYPHEN-DEBUG"
	suffix=$MAKE_HOST_HYPHEN
	
	if [[ $MAKE_HOST =~ ^"windows" ]]; then
		suffix+=".exe"
	fi
	
	if [[ -n ${WALLET_PATHS[cli]} ]]; then
		sample="$parent/cari-cli-$suffix"
		cp "$sample" "${WALLET_PATHS[cli]}" || err_and_exit "Can't copy the sample binary \"$sample\"."
	fi
	
	if [[ -n ${WALLET_PATHS[daemon]} ]]; then
		sample="$parent/carid-$suffix"
		cp "$sample" "${WALLET_PATHS[daemon]}" || err_and_exit "Can't copy the sample binary \"$sample\"."
	fi
	
	if [[ -n ${WALLET_PATHS[gui]} ]]; then
		if [[ $MAKE_HOST =~ ^"macos" ]]; then
			suffix+=".dmg"
		fi
		
		sample="$parent/cari-qt-$suffix"
		cp "$sample" "${WALLET_PATHS[gui]}" || err_and_exit "Can't copy the sample binary \"$sample\"."
	fi
}

# Display a debug (no error) message on the standard output.
debug_msg() {
	local msg=$1
	
	# ------------------
	
	echo "${N}${FORMAT[ok]}DEBUG: $(get_time_for_debug): ${msg}${FORMAT[def]}${N}"
}

# Display help.
display_help() {
	cat <<- HEREDOC
		CARI Builder is a Bash script used to build the CARI wallet (CLI, daemon and GUI) for several
		operating systems using cross compilation. List of possible arguments:
		
		    -a: Create one archive per wallet category: one for the GUI wallet and one for no-GUI
		        (CLI and daemon) wallets.
		        Default is not to create multiple archives, so all wallets are in the same archive for
		        a specific operating system.
		
		    -c: Compress binaries with UPX.
		        Default is not to compress.
		
		    -d: Run in debug mode for the build process. Wallets won't be built. Sample files will be
		        used instead.
		        Default is not to run in debug mode for the build process.
		
		    -e: Run in debug mode for the snapshot process. Only the first blocks of the blockchain
		        will be retrieved.
		        Default is not to run in debug mode for the snapshot process.
		
		    -h: Display help.
		
		    -j: Set the number of jobs to run simultaneously for the build process.
		        Default is the output of the command "nproc".
		
		    -m: Set the make host, i.e. the target host on which the wallet will run. Possible values:
		    
		            linux_arm32
		            linux_arm64 (or linux_arm)
		            linux_x86_64 (or linux)
		            macos_x86_64 (or macos)
		            windows_x86_64 (or windows)
		    
		        Default is linux_x86_64.
		
		    -n: Release no-GUI wallets (CLI and daemon) for the current make host.
		        Default is to release no-GUI wallets for Linux only.
		
		    -p: Path to the source code. If it doesn't exist, it'll be created and the source code will
		        be pulled. Use "." to specify that the current working folder is already the repository.
		        Default is "tmp-cari-builder/CARI" in the current working folder.
		
		    -r: Run the specified wallet at the end of the build process (valid only for Linux builds).
		        Possible values:
		    
		            cli
		            daemon
		            gui
		            none
		    
		        Default is none.
		
		    -s: Get a snapshot of the CARI blockchain and create a ZIP archive.
		        Default is not to get a snapshot.
		
		    -t: Test the wallet after the build process by running it and checking the output expected.
		        Default is not to test the wallet.
		
		    -u: Uninstall dependencies at the end of the build process.
		        Default is not to uninstall dependencies.
		
		    -v: Set the source code tag to build. It must be either a git tag (ex.: CARIv1.2.0) or the
		        word "latest".
		        Default is latest.
		
		Example:
		
		    $0 -a -m windows -p "/tmp/CARI-windows" -t
	
	HEREDOC
}

# Display a formatted error message on the stderr output, and exit.
# 
# If the message ends with "~%cd%", a specific message will be displayed for the failed "cd" command, using the message as the path to the emplacement.
# 
# A custom exit status can be set with the second argument, otherwise the default value "1" will be used.
# 
# Examples:
# 
#     err_and_exit "Error message to display" 2
#     cd "/path/to/folder" || err_and_exit "/path/to/folder~%cd%"
# 
err_and_exit() {
	local msg=$1
	local exit_status=$2
	
	# ------------------
	
	if [[ $msg =~ "~%cd%"$ ]]; then
		msg="Can't change the working folder to \"${msg::-5}\"."
	fi
	
	if [[ ! $exit_status =~ ^[0-9]+$ ]] || ! (( exit_status >= 0 && exit_status <= 255 )); then
		exit_status=1
	fi
	
	echo "${N}${FORMAT[err]}ERROR: $(get_time_for_debug): ${msg}${FORMAT[def]}${N}" 1>&2
	
	time_elapsed
	
	exit "$exit_status"
}

# Get the current block count returned by the CARI explorer.
get_block_count_explorer() {
	local block_count
	
	# ------------------
	
	block_count=$(curl -f -L "https://cari-explorer.projectmerge.org/api/getblockcount")
	
	if [[ ! $block_count =~ ^[0-9]+$ ]]; then
		block_count=$(curl -f -L "https://explorer.cri.eco/api/getblockcount")
	fi
	
	if [[ ! $block_count =~ ^[0-9]+$ ]]; then
		block_count=0
	fi
	
	echo -n "$block_count"
}

# Get sample binaries to be used in debug mode.
get_sample_bin() {
	local archive url
	
	# ------------------
	
	archive="cari-$MAKE_HOST_HYPHEN-DEBUG.zip"
	url="https://notifs.cri.eco/download/cari-builder/debug-samples/$archive"
	
	if [[ ! -f "$TMP_CARI_BUILDER/$archive" ]]; then
		curl -f -L "$url" -o "$TMP_CARI_BUILDER/$archive"
	fi
	
	if [[ ! -f "$TMP_CARI_BUILDER/$archive" ]]; then
		err_and_exit "Can't download \"$url\"."
	fi
	
	if ! unzip -n "$TMP_CARI_BUILDER/$archive" -d "$TMP_CARI_BUILDER"; then
		err_and_exit "Can't extract \"$TMP_CARI_BUILDER/$archive\"."
	fi
}

# Get the size in MiB for the specified file.
get_size_mib() {
	local file=$1
	
	local size
	
	# ------------------
	
	if [[ -f $file ]]; then
		size=$(LC_NUMERIC=C awk "BEGIN { printf \"%.1f\", $(stat -c %s "$file") / 1024 / 1024 }")
	fi
	
	echo -n "$size"
}

# Return the current timestamp formatted to be displayed in debug messages. If a timestamp is passed in the first argument, it'll be used instead of the current one.
get_time_for_debug() {
	local timestamp=$1
	
	local pattern time_debug
	
	# ------------------
	
	pattern="%Y-%m-%d_%H:%M:%S"
	
	if [[ $timestamp =~ ^[0-9]+$ ]]; then
		time_debug=$(date -d "@$timestamp" "+$pattern")
	else
		time_debug=$(date "+$pattern")
	fi
	
	echo -n "$time_debug"
}

# Display the word "OK" at the end of the process if there were no errors.
ok() {
	local msg
	
	# ------------------
	
	msg+="${FORMAT[ok]}                  ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]}  ██████  ██   ██ ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]} ██    ██ ██  ██  ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]} ██    ██ █████   ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]} ██    ██ ██  ██  ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]}  ██████  ██   ██ ${FORMAT[def]}${N}"
	msg+="${FORMAT[ok]}                  ${FORMAT[def]}${N}"
	
	echo "$msg"
}

# Test if the archive can be extracted.
# 
# If the second argument equals "true", the function will calculate the archive hash.
# 
# If the third argument is specified, it'll be used as the wallet ID.
test_archive() {
	local archive=$1
	local calc_hash=$2
	local wallet_id=$3
	
	local hashes_file
	
	if [[ -z $wallet_id ]]; then
		wallet_id=$WALLET_ID
	fi
	
	# ------------------
	
	if ! unzip -qt "$archive"; then
		err_and_exit "The archive \"$archive\" seems to be corrupted."
	fi
	
	if [[ $calc_hash == true ]]; then
		hashes_file="$TMP_CARI_BUILDER/SHA256SUMS-$wallet_id.txt"
		
		if ! sha256sum "$archive" >> "$hashes_file"; then
			err_and_exit "Can't calculate the hash of \"$archive\" to save it in \"$hashes_file\"."
		fi
		
		debug_msg "The file \"$hashes_file\" was created or updated for the archive \"$archive\"."
	fi
}

# Test wallet binaries.
# 
# The make host must be specified in the first argument.
# 
# The test type must be specified in the second argument. If the test type is "exec", the function will test if binaries are executable, but will not try to run them. It's useful to check if the build process completed corectly because it's supposed to mark binaries as executable at the end of the process. If the test type is "run", the function will try to run binaries (using virtualization if needed) in order to compare the output with the expected result.
# 
# If there's no error, the function will output nothing. If there are errors, it'll return an error message.
test_bin() {
	local make_host=$1
	local test_type=$2
	
	local output path ret
	
	# ------------------
	
	for path in "${WALLET_PATHS[cli]}" "${WALLET_PATHS[daemon]}" "${WALLET_PATHS[gui]}"; do
		if [[ -z $path ]]; then
			continue
		fi
		
		# Test type: exec
		#################
		if [[ $test_type == "exec" ]]; then
			if [[ ! -f $path || ! -x $path ]]; then
				ret+="The binary \"$path\" is not executable.$N"
			fi
		
		# Test type: output
		###################
		elif [[ $test_type == "run" ]]; then
			output=""
			
			# linux_arm32
			if [[ $make_host == "linux_arm32" ]]; then
				# We set "LC_ALL" to prevent the warning "Fontconfig warning: ignoring C.UTF-8: not a valid language tag".
				
				lc_all_qemu_arm=$(locale -a | grep -m 1 en_US.utf8)
				
				if [[ -z $lc_all_qemu_arm ]]; then
					lc_all_qemu_arm=$(locale -a | grep -m 1 ^en_..\.)
				fi
				
				if [[ -z $lc_all_qemu_arm ]]; then
					lc_all_qemu_arm=$(locale -a | grep -m 1 ^.._..\.)
				fi
				
				if [[ $path =~ "qt" ]]; then
					output=$(LC_ALL="$lc_all_qemu_arm" xvfb-run qemu-arm -L /usr/arm-linux-gnueabihf/ "$path" --version 2>&1)
				else
					output=$(LC_ALL="$lc_all_qemu_arm" qemu-arm -L /usr/arm-linux-gnueabihf/ "$path" --version 2>&1)
				fi
			
			# linux_arm64
			elif [[ $make_host == "linux_arm64" ]]; then
				if [[ $path =~ "qt" ]]; then
					output=$(xvfb-run qemu-aarch64 -L /usr/aarch64-linux-gnu/ "$path" --version 2>&1)
				else
					output=$(qemu-aarch64 -L /usr/aarch64-linux-gnu/ "$path" --version 2>&1)
				fi
			
			# linux
			elif [[ $make_host =~ ^"linux" ]]; then
				if [[ $path =~ "qt" ]]; then
					output=$(xvfb-run "$path" --version 2>&1)
				else
					output=$("$path" --version 2>&1)
				fi
			
			# macos
			elif [[ $make_host =~ ^"macos" ]]; then
				if [[ $path =~ "qt" ]]; then
					output="CARI (it doesn't run using \"darling\", so we're disabling the test for now)"
				else
					output=$(darling "$path" --version 2>&1)
				fi
			
			# windows
			elif [[ $make_host =~ ^"windows" ]]; then
				wineboot
				
				if [[ $path =~ "qt" ]]; then
					output=$(timeout 10s wine "$path" 2>&1)
					
					# We assume that if the wallet tries to create a window, it means that the binary
					# must run correctly, because if Wine can't load a binary, it displays an error
					# like this: "err:module:__wine_process_init failed to load".
					# 
					# Unfortunately, there's no command line option with the GUI wallet on Windows to
					# output something on the console. The argument "--version" opens a popup window,
					# unlike the GUI wallet on other operating systems.
					if [[ $output =~ "Application tried to create a window" ]]; then
						output="CARI ($output)"
					fi
				else
					output=$(WINEDEBUG=-all wine "$path" --version 2>&1)
				fi
			fi
			
			output=$(echo -n "$output" | sed ':a;N;$!ba;s/\n/␤/g')
			
			if [[ ! ${output^^} =~ ^("CARI"|"PIVX") ]]; then
				ret+="The binary \"$path\" can't run or doesn't run correctly: \"$output\"$N"
			fi
		fi
	done
	
	echo -n "$ret"
}

# Display the time elapsed since the script was started.
time_elapsed() {
	local t2
	
	local msg s
	
	# ------------------
	
	t2=$(date +%s)
	s=$((t2 - T1))
	
	msg="Script started at $(get_time_for_debug "$T1") and finished at $(get_time_for_debug "$t2"). Time elapsed: $s "
	
	if [[ $s == 1 ]]; then
		msg+="second"
	else
		msg+="seconds"
	fi
	
	debug_msg "$msg"
}

################################################################################
# ENVIRONMENT CHECKS
################################################################################

if ! type -p uname > /dev/null || [[ "$(uname -s)" != "Linux" ]]; then
	err_and_exit "The script must run on Linux."
fi

operating_system=""

if type -p lsb_release > /dev/null; then
	operating_system=$(lsb_release -i | sed -E "s/^Distributor ID:\s+(.+)$/\1/")
	os_version=$(lsb_release -r | sed -E "s/^Release:\s+(.+)$/\1/")
fi

if [[ (-z $operating_system || -z $os_version) && -f /etc/os-release ]]; then
	if [[ -z $operating_system ]]; then
		operating_system=$(sed -En 's/^NAME="([^"]+)"$/\1/p' /etc/os-release)
	fi
	
	if [[ -z $os_version ]]; then
		os_version=$(sed -En 's/^VERSION_ID="([^"]+)"$/\1/p' /etc/os-release)
	fi
fi

if [[ ${operating_system,,} != "ubuntu" ]]; then
	err_and_exit "The script must run on Ubuntu (system detected: $operating_system)."
fi

if [[ ! $os_version =~ ^"20.04" ]]; then
	err_and_exit "The script must run on Ubuntu 20.04 (version detected: $os_version)."
fi

################################################################################
# CONSTANTS, 1 of 2
################################################################################

########################################
# SCRIPT ARGUMENTS
########################################

MULTIPLE_ARCHIVES=false     # -a
COMPRESS_BIN=false          # -c
DEBUG_MODE_BUILD=false      # -d
DEBUG_MODE_SNAPSHOT=false   # -e
NB_JOBS=                    # -j
MAKE_HOST=                  # -m
ENABLE_NO_GUI=false         # -n
PATH_SOURCE_CODE=           # -p
RUN_AFTER_BUILD=            # -r
GET_SNAPSHOT=false          # -s
TEST_AFTER_BUILD=false      # -t
UNINSTALL_AFTER_BUILD=false # -u
CODE_VERSION=               # -v

while getopts ':acdehj:m:np:r:stuv:' opt; do
	case "${opt}" in
		a)
			MULTIPLE_ARCHIVES=true
			;;
		
		c)
			COMPRESS_BIN=true
			;;
		
		d)
			DEBUG_MODE_BUILD=true
			;;
		
		e)
			DEBUG_MODE_SNAPSHOT=true
			;;
		
		h)
			display_help
			
			exit 0
			;;
		
		j)
			NB_JOBS=$OPTARG
			;;
		
		m)
			MAKE_HOST=$OPTARG
			;;
		
		n)
			ENABLE_NO_GUI=true
			;;
		
		p)
			PATH_SOURCE_CODE=$OPTARG
			;;
		
		r)
			RUN_AFTER_BUILD=$OPTARG
			;;
		
		s)
			GET_SNAPSHOT=true
			;;
		
		t)
			TEST_AFTER_BUILD=true
			;;
		
		u)
			UNINSTALL_AFTER_BUILD=true
			;;
		
		v)
			CODE_VERSION=$OPTARG
			;;
		
		*)
			err_and_exit "Invalid arguments. Run the following command for help: $0 -h"
			;;
	esac
done

if [[ ! $NB_JOBS =~ ^[1-9][0-9]*$ ]]; then
	NB_JOBS=$(nproc)
fi

ROOT_FOLDER=$(dirname -- "$(realpath "$0")")
TMP_CARI_BUILDER="$ROOT_FOLDER/tmp-cari-builder"

if ! mkdir -p "$TMP_CARI_BUILDER"; then
	err_and_exit "Can't create the folder \"$TMP_CARI_BUILDER\"."
fi

if [[ -z $PATH_SOURCE_CODE ]]; then
	PATH_SOURCE_CODE="$TMP_CARI_BUILDER/CARI"
elif [[ $PATH_SOURCE_CODE == "." ]]; then
	PATH_SOURCE_CODE=$ROOT_FOLDER
fi

if [[ $MAKE_HOST == "linux_arm" ]]; then
	MAKE_HOST="linux_arm64"
elif [[ $MAKE_HOST == "macos" ]]; then
	MAKE_HOST="macos_x86_64"
elif [[ $MAKE_HOST == "windows" ]]; then
	MAKE_HOST="windows_x86_64"
elif [[ $MAKE_HOST == "linux" || -z $MAKE_HOST ]]; then
	MAKE_HOST="linux_x86_64"
fi

MAKE_HOST_HYPHEN=${MAKE_HOST//_/-}
MAKE_HOST_IS_LINUX=false

if [[ ! $MAKE_HOST =~ ^"linux_arm" && $MAKE_HOST =~ ^"linux" ]]; then
	MAKE_HOST_IS_LINUX=true
fi

if [[ $MAKE_HOST_IS_LINUX == false || ! $RUN_AFTER_BUILD =~ ^("cli"|"daemon"|"gui"|"none")$ ]]; then
	RUN_AFTER_BUILD="none"
fi

if [[ -z $CODE_VERSION ]]; then
	CODE_VERSION="latest"
fi

declare -r MULTIPLE_ARCHIVES COMPRESS_BIN DEBUG_MODE_BUILD DEBUG_MODE_SNAPSHOT NB_JOBS MAKE_HOST ENABLE_NO_GUI \
           PATH_SOURCE_CODE RUN_AFTER_BUILD GET_SNAPSHOT TEST_AFTER_BUILD UNINSTALL_AFTER_BUILD CODE_VERSION
declare -r ROOT_FOLDER TMP_CARI_BUILDER MAKE_HOST_HYPHEN MAKE_HOST_IS_LINUX

if [[ $DEBUG_MODE_BUILD == true ]]; then
	debug_msg "The debug mode is enabled for the build process."
fi

if [[ $DEBUG_MODE_SNAPSHOT == true ]]; then
	debug_msg "The debug mode is enabled for the snapshot process."
fi

########################################
# BUILD CONF
########################################

# Enabled target triplets. Explanation: <https://wiki.osdev.org/Target_Triplet>
# List of possible triplets: <https://github.com/bitcoin/bitcoin/tree/master/depends#usage>
declare -A TARGET_TRIPLETS=(
	[linux_arm32]="arm-linux-gnueabihf"
	[linux_arm64]="aarch64-linux-gnu"
	[linux_x86_64]="x86_64-pc-linux-gnu"
	[macos_x86_64]="x86_64-apple-darwin19.6.0"
	[windows_x86_64]="x86_64-w64-mingw32"
)

# Current target triplet
TARGET_TRIPLET=${TARGET_TRIPLETS[$MAKE_HOST]}

if [[ -z $TARGET_TRIPLET ]]; then
	err_and_exit "The make host \"$MAKE_HOST\" is not supported."
fi

# make config site
MAKE_CONFIG_SITE="$PATH_SOURCE_CODE/depends/$TARGET_TRIPLET/share/config.site"

# Parent URL where to get the wallet source code
PARENT_URL_CODE="https://github.com/Carbon-Reduction-Initiative"

declare -r TARGET_TRIPLETS TARGET_TRIPLET MAKE_CONFIG_SITE PARENT_URL_CODE

debug_msg "The make host for the current build process for the CARI wallet is $MAKE_HOST ($TARGET_TRIPLET)."

########################################
# WALLET PATHS
########################################

declare -A WALLET_PATHS=(
	[cli]=""
	[daemon]=""
	[gui]=""
)

# linux_arm
if [[ $MAKE_HOST =~ ^"linux_arm" ]]; then
	if [[ $ENABLE_NO_GUI == true ]]; then
		WALLET_PATHS[cli]="$PATH_SOURCE_CODE/src/cari-cli"
		WALLET_PATHS[daemon]="$PATH_SOURCE_CODE/src/carid"
	fi
	
	WALLET_PATHS[gui]="$PATH_SOURCE_CODE/src/qt/cari-qt"

# linux
elif [[ $MAKE_HOST =~ ^"linux" ]]; then
	WALLET_PATHS[cli]="$PATH_SOURCE_CODE/src/cari-cli"
	WALLET_PATHS[daemon]="$PATH_SOURCE_CODE/src/carid"
	
	WALLET_PATHS[gui]="$PATH_SOURCE_CODE/src/qt/cari-qt"

# macos
elif [[ $MAKE_HOST =~ ^"macos" ]]; then
	if [[ $ENABLE_NO_GUI == true ]]; then
		WALLET_PATHS[cli]="$PATH_SOURCE_CODE/src/cari-cli"
		WALLET_PATHS[daemon]="$PATH_SOURCE_CODE/src/carid"
	fi
	
	WALLET_PATHS[gui]="$PATH_SOURCE_CODE/src/qt/cari-qt.dmg"

# windows
elif [[ $MAKE_HOST =~ ^"windows" ]]; then
	if [[ $ENABLE_NO_GUI == true ]]; then
		WALLET_PATHS[cli]="$PATH_SOURCE_CODE/src/cari-cli.exe"
		WALLET_PATHS[daemon]="$PATH_SOURCE_CODE/src/carid.exe"
	fi
	
	WALLET_PATHS[gui]="$PATH_SOURCE_CODE/src/qt/cari-qt.exe"
fi

declare -r WALLET_PATHS

msg_wallet_paths=""

for wallet_type in "${!WALLET_PATHS[@]}"; do
	if [[ -n ${WALLET_PATHS[$wallet_type]} ]]; then
		if [[ -n $msg_wallet_paths ]]; then
			msg_wallet_paths+=$N
		fi
		
		msg_wallet_paths+="- ${WALLET_PATHS[$wallet_type]}"
	fi
done

if [[ -n $msg_wallet_paths ]]; then
	debug_msg "Wallet path(s) for the current build process:${N}${msg_wallet_paths}"
fi

################################################################################
# DEPENDENCIES AND BUILD CONFIGURATION, 1 of 2
################################################################################

debug_msg "Installing dependencies..."

dependencies=(automake curl g++ git libtool make pkg-config unzip zip)

if [[ $COMPRESS_BIN == true ]]; then
	dependencies+=(upx-ucl)
fi

if [[ $GET_SNAPSHOT == true ]]; then
	dependencies+=(rsync)
fi

make_1_args=(-j "$NB_JOBS")

configure_args=(--disable-bench --disable-gui-tests --disable-tests --enable-reduce-exports)

make_2_args=(-j "$NB_JOBS")

# Preventing the warning "QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to..."
# when testing binaries at the end of the build process on GitHub.
if [[ $TEST_AFTER_BUILD == true && -z $XDG_RUNTIME_DIR ]]; then
	XDG_RUNTIME_DIR="$TMP_CARI_BUILDER/runtime"
	
	if ! mkdir -p "$XDG_RUNTIME_DIR"; then
		err_and_exit "Can't create \"$XDG_RUNTIME_DIR\"."
	fi
	
	export XDG_RUNTIME_DIR
fi

architectures=()

########################################
# linux_arm32
########################################
if [[ $MAKE_HOST == "linux_arm32" ]]; then
	dependencies+=(g++-arm-linux-gnueabihf)
	
	# Without "--enable-glibc-back-compat", there's an error "librustzcash.a: error adding symbols: file format not recognized".
	configure_args+=(--disable-online-rust --enable-glibc-back-compat --prefix="/usr")
	
	if [[ $TEST_AFTER_BUILD == true ]]; then
		dependencies+=(libc6-armhf-cross libstdc++6-armhf-cross qemu-user qemu-user-static)
		
		# To test the GUI wallet
		
		dependencies+=(libfontconfig1:armhf libx11-6:armhf libx11-xcb1:armhf xvfb)
		
		architectures+=(armhf)
		
		if ! mkdir -p "/etc/apt/sources.list.d"; then
			err_and_exit "Can't create the apt folder."
		fi
		
		armhf_repos="deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports/ focal main$N"
		armhf_repos+="deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports/ focal-updates main$N"
		armhf_repos+="deb [arch=armhf] http://ports.ubuntu.com/ubuntu-ports/ focal-backports main"
		
		echo "$armhf_repos" | sudo tee "/etc/apt/sources.list.d/cari-builder-armhf.list" > /dev/null
	fi

########################################
# linux_arm64
########################################
elif [[ $MAKE_HOST == "linux_arm64" ]]; then
	dependencies+=(g++-aarch64-linux-gnu)
	
	# Without "--disable-online-rust", there's an error "librustzcash.a: error adding symbols: file in wrong format".
	configure_args+=(--disable-online-rust --prefix="/usr")
	
	if [[ $TEST_AFTER_BUILD == true ]]; then
		dependencies+=(libc6-arm64-cross libstdc++6-arm64-cross qemu-user qemu-user-static)
		
		# To test the GUI wallet
		
		dependencies+=(libfontconfig1:arm64 libx11-6:arm64 libx11-xcb1:arm64 xvfb)
		
		architectures+=(arm64)
		
		if ! mkdir -p "/etc/apt/sources.list.d"; then
			err_and_exit "Can't create the apt folder."
		fi
		
		arm64_repos="deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal main$N"
		arm64_repos+="deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal-updates main$N"
		arm64_repos+="deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports/ focal-backports main"
		
		echo "$arm64_repos" | sudo tee "/etc/apt/sources.list.d/cari-builder-arm64.list" > /dev/null
	fi

########################################
# linux
########################################
elif [[ $MAKE_HOST =~ ^"linux" ]]; then
	dependencies+=(python2)
	
	# Without "--disable-online-rust", there's an error "libbitcoin_wallet.a: error adding symbols: file in wrong format".
	configure_args+=(--disable-online-rust --prefix="/usr")
	
	if [[ $TEST_AFTER_BUILD == true ]]; then
		dependencies+=(libfontconfig1 xvfb)
	fi

########################################
# macos
########################################
elif [[ $MAKE_HOST =~ ^"macos" ]]; then
	dependencies+=(libtinfo5 python3-setuptools)
	
	configure_args+=(--prefix="$PATH_SOURCE_CODE/depends/$TARGET_TRIPLET")
	
	if [[ $TEST_AFTER_BUILD == true ]]; then
		dependencies+=(cmake clang bison flex libfuse-dev libudev-dev pkg-config libc6-dev-i386 linux-headers-generic gcc-multilib libcairo2-dev libgl1-mesa-dev libglu1-mesa-dev libtiff5-dev libfreetype6-dev git libelf-dev libxml2-dev libegl1-mesa-dev libfontconfig1-dev libbsd-dev libxrandr-dev libxcursor-dev libgif-dev libavutil-dev libpulse-dev libavformat-dev libavcodec-dev libavresample-dev libdbus-1-dev libxkbfile-dev libssl-dev python2 dkms linux-headers-generic)
	fi

########################################
# windows
########################################
elif [[ $MAKE_HOST =~ ^"windows" ]]; then
	dependencies+=(g++-mingw-w64)
	
	# "--disable-online-rust" is set to prevent the following error: "cp: cannot stat '.../rustzcash.lib': No such file or directory".
	# More details here: <https://github.com/bitcoin/bitcoin/blob/master/doc/build-windows.md#footnotes>
	configure_args+=(--disable-online-rust --prefix="/usr")
	
	if [[ $TEST_AFTER_BUILD == true ]]; then
		dependencies+=(wine)
		
		# Note: if we want to build a 32-bit version, we need to install wine32:
		# 
		# dependencies+=(wine32)
		# 
		# architectures+=(i386)
	fi
fi

########################################
# INSTALL DEPENDENCIES
########################################

# Prevent an error "Unable to fetch some archives" on GitHub.
sudo sed -i 's/azure\.//' /etc/apt/sources.list

sudo apt-get update

for architecture in "${architectures[@]}"; do
	if ! sudo dpkg --add-architecture "$architecture"; then
		err_and_exit "Can't add the architecture \"$architecture\" using dpkg."
	fi
done

sudo apt-get update

if ! sudo apt-get install -y "${dependencies[@]}"; then
	err_and_exit "Can't install dependencies."
fi

################################################################################
# SOURCE CODE
################################################################################

if [[ ! -e $PATH_SOURCE_CODE ]]; then
	debug_msg "Getting code from the repository..."
	
	git clone "$PARENT_URL_CODE/CARI.git" "$PATH_SOURCE_CODE"
fi

cd "$PATH_SOURCE_CODE" || err_and_exit "$PATH_SOURCE_CODE~%cd%"

debug_msg "git checkout master"

if ! git checkout master; then
	err_and_exit "Can't checkout to master."
fi

debug_msg "git pull origin master"

if ! git pull origin master; then
	err_and_exit "Can't pull the source code."
fi

########################################
# CODE VERSION
########################################

if [[ $CODE_VERSION == "latest" ]]; then
	#wallet_version=$(git tag --sort=-committerdate | head -n 1)
	wallet_version=$(curl -L -o "/dev/null" -s -w "%{url_effective}" "$PARENT_URL_CODE/CARI/releases/latest" | sed -E "s#.+/(.+)#\1#")
else
	wallet_version=$CODE_VERSION
fi

if ! git rev-parse "$wallet_version" >/dev/null 2>&1; then
	err_and_exit "The tag \"$wallet_version\" doesn't exist in the wallet repository."
fi

debug_msg "git checkout $wallet_version"

if ! git checkout "$wallet_version"; then
	err_and_exit "Can't checkout to \"$wallet_version\"."
fi

################################################################################
# CONSTANTS, 2 of 2
################################################################################

WALLET_ID="cari-${wallet_version#"CARIv"}"

if [[ $DEBUG_MODE_BUILD == true && ! $wallet_version =~ "-DEBUG"$ ]]; then
	WALLET_ID+="-DEBUG"
fi

WALLET_ID+="-$MAKE_HOST_HYPHEN"

declare -r WALLET_ID

################################################################################
# DEPENDENCIES AND BUILD CONFIGURATION, 2 of 2
################################################################################

########################################
# macos
########################################
if [[ $MAKE_HOST =~ ^"macos" ]]; then
	# SDK
	#####
	
	sdk_folders=("$PATH_SOURCE_CODE/depends/SDKs" "$PATH_SOURCE_CODE/depends/sdk-sources")
	
	if ! mkdir -p "${sdk_folders[@]}"; then
		err_and_exit "Can't create the SDK folders: ${sdk_folders[*]}"
	fi
	
	xcode_archive_name="Xcode-11.3.1-11C505-extracted-SDK-with-libcxx-headers.tar.gz"
	xcode_path="$PATH_SOURCE_CODE/depends/sdk-sources/$xcode_archive_name"
	
	if [[ ! -e $xcode_path ]]; then
		curl -f -L "https://bitcoincore.org/depends-sources/sdks/$xcode_archive_name" -o "$xcode_path"
	fi
	
	if [[ ! -f $xcode_path ]]; then
		err_and_exit "Can't find the SDK \"$xcode_path\"."
	fi
	
	if ! tar -C "$PATH_SOURCE_CODE/depends/SDKs" -xf "$xcode_path"; then
		err_and_exit "Can't extract \"$xcode_path\"."
	fi
	
	# darling
	#########
	if [[ $TEST_AFTER_BUILD == true ]] && ! type -p darling > /dev/null; then
		if [[ ! -e "$TMP_CARI_BUILDER/darling" ]]; then
			git clone --recursive https://github.com/darlinghq/darling.git
		fi
		
		cd "$TMP_CARI_BUILDER/darling" || err_and_exit "$TMP_CARI_BUILDER/darling~%cd%"
		
		git pull
		git submodule init
		git submodule update
		
		mkdir "$TMP_CARI_BUILDER/darling/build"
		cd "$TMP_CARI_BUILDER/darling/build" || err_and_exit "$TMP_CARI_BUILDER/darling/build~%cd%"
		
		# Not a full build, otherwise it would take too much time.
		cmake -DFULL_BUILD=OFF -DTARGET_i386=OFF ..
		
		make -j "$NB_JOBS"
		sudo make install
		
		make -j "$NB_JOBS" lkm
		sudo make lkm_install
		
		if ! type -p darling > /dev/null; then
			err_and_exit "Can't install \"darling\"."
		fi
	fi

########################################
# windows
########################################
elif [[ $MAKE_HOST =~ ^"windows" ]]; then
	# Setting the Mingw32 g++ compiler to the POSIX version, because we must use the POSIX threading model,
	# otherwise the compilation will fail.
	if ! sudo update-alternatives --set x86_64-w64-mingw32-g++ "$(which x86_64-w64-mingw32-g++-posix)"; then
		err_and_exit "Can't update settings for the Mingw32 g++ compiler."
	fi
fi

################################################################################
# BUILD PROCESS
################################################################################

# Step 1 (make, 1 of 2)
#######################

step="Build process (make -j $NB_JOBS, 1 of 2)..."
debug_msg "$step"

cd "$PATH_SOURCE_CODE/depends" || err_and_exit "$PATH_SOURCE_CODE/depends~%cd%"

if [[ $DEBUG_MODE_BUILD == true ]]; then
	debug_msg "Skipping this step because the debug mode is enabled."
elif ! make HOST="$TARGET_TRIPLET" "${make_1_args[@]}"; then
	err_and_exit "$step"
fi

# Step 2 (autogen.sh)
#####################

step="Build process (autogen.sh)..."
debug_msg "$step"

cd "$PATH_SOURCE_CODE" || err_and_exit "$PATH_SOURCE_CODE~%cd%"

if [[ $DEBUG_MODE_BUILD == true ]]; then
	debug_msg "Skipping this step because the debug mode is enabled."
elif ! ./autogen.sh; then
	err_and_exit "$step"
fi

# Step 3 (configure)
####################

step="Build process (configure)..."
debug_msg "$step"

if [[ $DEBUG_MODE_BUILD == true ]]; then
	debug_msg "Skipping this step because the debug mode is enabled."
elif ! CONFIG_SITE="$MAKE_CONFIG_SITE" ./configure "${configure_args[@]}"; then
	err_and_exit "$step"
fi

# Step 4 (make, 2 of 2)
#######################

step="Build process (make -j $NB_JOBS, 2 of 2)..."
debug_msg "$step"

if [[ $DEBUG_MODE_BUILD == true ]]; then
	debug_msg "Skipping this step because the debug mode is enabled. Sample files will be used instead."
	
	get_sample_bin
	copy_sample_bin
elif ! make "${make_2_args[@]}"; then
	err_and_exit "$step"
fi

################################################################################
# COMPRESS THE WALLET
################################################################################

if [[ $COMPRESS_BIN == true ]]; then
	debug_msg "Compressing binaries..."
	
	if ! type -p upx > /dev/null; then
		err_and_exit "To compress binaries, \"upx\" must be installed."
	fi
	
	for wallet_type in "${!WALLET_PATHS[@]}"; do
		if [[ ! -f ${WALLET_PATHS[$wallet_type]} ]]; then
			continue
		fi
		
		# Results for a few arguments (on a server with 3 CPU and 4G RAM) for the
		# GUI wallet on Windows:
		#    Argument  Ratio*  Speed
		#    -----------------------
		#         -1:  69.35%  1.75s
		#         -5:  66.00%  3.27s
		#         -7:  65.36%  7.17s
		#         -8:  65.29%  14.57s
		#         -9:  65.10%  23.88s
		#     --best:  65.90%  892.89s
		#     --lzma:  58.05%  25.06s
		# 
		# *: Ratio size after / size before
		if ! upx --lzma "${WALLET_PATHS[$wallet_type]}"; then
			err_and_exit "Can't compress \"${WALLET_PATHS[$wallet_type]}\"."
		fi
	done
fi

################################################################################
# TEST THE WALLET
################################################################################

debug_msg "Testing wallet binaries..."

# Testing if it's executable
test_output=$(test_bin "$MAKE_HOST" "exec")

if [[ -n $test_output ]]; then
	err_and_exit "$test_output"
fi

# Testing the actual excecution of the wallet
if [[ $TEST_AFTER_BUILD == true ]]; then
	test_output=$(test_bin "$MAKE_HOST" "run")
	
	if [[ -n $test_output ]]; then
		err_and_exit "$test_output"
	fi
fi

debug_msg "Wallet binaries generated during the build process passed all tests."

################################################################################
# ARCHIVES
################################################################################

debug_msg "Creating wallet archives..."

cd "$TMP_CARI_BUILDER" || err_and_exit "$TMP_CARI_BUILDER~%cd%"

archive_name_prefix="$WALLET_ID"
archive_name_suffix=".zip"

if [[ -n ${WALLET_PATHS[cli]} && -n ${WALLET_PATHS[daemon]} && ($MAKE_HOST_IS_LINUX == true || $ENABLE_NO_GUI == true) ]]; then
	archive_name=$archive_name_prefix
	
	if [[ $MULTIPLE_ARCHIVES == true ]]; then
		archive_name+="-no-gui"
	fi
	
	archive_name+=$archive_name_suffix
	
	if [[ -e $archive_name ]]; then
		err_and_exit "The archive \"$archive_name\" already exists."
	fi
	
	if ! zip -9 -j "$archive_name" "${WALLET_PATHS[cli]}" "${WALLET_PATHS[daemon]}"; then
		err_and_exit "Can't create the archive \"$archive_name\"."
	fi
	
	calc_hash=true
	
	if [[ -n ${WALLET_PATHS[gui]} && $MULTIPLE_ARCHIVES == false ]]; then
		calc_hash=false
	fi
	
	test_archive "$archive_name" "$calc_hash"
	
	debug_msg "Archive \"$archive_name\" created (size: $(get_size_mib "$archive_name") MiB)."
fi

if [[ -n ${WALLET_PATHS[gui]} ]]; then
	archive_name=$archive_name_prefix
	
	if [[ $MULTIPLE_ARCHIVES == true ]]; then
		archive_name+="-gui"
	fi
	
	archive_name+=$archive_name_suffix
	
	if [[ $MULTIPLE_ARCHIVES == true && -e $archive_name ]]; then
		err_and_exit "The archive \"$archive_name\" already exists."
	fi
	
	if ! zip -9 -j "$archive_name" "${WALLET_PATHS[gui]}"; then
		err_and_exit "Can't create or update the archive \"$archive_name\"."
	fi
	
	test_archive "$archive_name" true
	
	debug_msg "Archive \"$archive_name\" created or updated (size: $(get_size_mib "$archive_name") MiB)."
fi

################################################################################
# SNAPSHOT
################################################################################

if [[ $GET_SNAPSHOT == true ]]; then
	debug_msg "Getting a snapshot of the CARI blockchain..."
	
	if [[ -z ${WALLET_PATHS[cli]} || -z ${WALLET_PATHS[daemon]} ]]; then
		err_and_exit "Can't get a snapshot of the CARI blockchain because the command line wallet is not supported for the current make host \"$MAKE_HOST\"."
	fi
	
	cari_folder="$TMP_CARI_BUILDER/.cari"
	snapshot_date=$(date -u "+%Y-%m-%d_%H-%M-%S_UTC")
	snapshot_name="cari-snapshot-$snapshot_date"
	snapshot_path="$TMP_CARI_BUILDER/$snapshot_name"
	snapshot_archive_name="$snapshot_name.zip"
	snapshot_archive_path="$TMP_CARI_BUILDER/$snapshot_archive_name"
	
	if ! mkdir -p "$cari_folder"; then
		err_and_exit "Can't create the folder \"$cari_folder\"."
	fi
	
	if ! mkdir -p "$snapshot_path"; then
		err_and_exit "Can't create the folder \"$snapshot_path\"."
	fi
	
	(&>/dev/null "${WALLET_PATHS[daemon]}" -datadir="$cari_folder" &)
	
	if [[ $DEBUG_MODE_SNAPSHOT == true ]]; then
		block_count_explorer=5000
		debug_msg_block_count_suffix=" (in debug mode, getting the full snapshot is disabled)."
	else
		block_count_explorer=$(get_block_count_explorer)
		debug_msg_block_count_suffix="."
	fi
	
	block_count=0
	t1_block_count=$(date +%s)
	nb_err=0
	
	debug_msg "The block count returned by the CARI explorer is ${block_count_explorer}${debug_msg_block_count_suffix}"
	
	while true; do
		sleep 10
		block_count=$("${WALLET_PATHS[cli]}" -conf="$cari_folder/cari.conf" -datadir="$cari_folder" getblockcount)
		block_count_msg=$block_count
		
		if [[ ! $block_count =~ ^[0-9]+$ ]]; then
			nb_err=$((nb_err + 1))
			block_count_msg="?"
			block_count=-1
		fi
		
		if ((nb_err > 3)); then
			err_and_exit "Ending the process because there were too many errors trying to get the local block count (last value retrieved: $block_count)."
		fi
		
		debug_msg "Local block count: $block_count_msg"
		
		t2_block_count=$(date +%s)
		
		if ((t2_block_count - t1_block_count > 3600)); then
			err_and_exit "Getting a copy of the CARI blockchain is too slow. Ending the process."
		fi
		
		if ((block_count >= block_count_explorer)); then
			"${WALLET_PATHS[cli]}" -datadir="$cari_folder" stop
			t1_status=$(date +%s)
			
			while true; do
				sleep 10
				local_status=$("${WALLET_PATHS[cli]}" -datadir="$cari_folder" getmasternodestatus 2>&1)
				t2_status=$(date +%s)
				
				if [[ $local_status =~ "couldn't connect to server" ]]; then
					break
				fi
				
				if ((t2_status - t1_status > 60)); then
					err_and_exit "Stopping the CARI node is too slow. Ending the process."
				fi
			done
			
			break
		fi
	done
	
	if ! rsync -ah --delete-during --progress --stats \
	     "$cari_folder/blocks" "$cari_folder/chainstate" "$cari_folder/peers.dat" "$cari_folder/sporks" "$cari_folder/zerocoin" \
	     "$snapshot_path"; then
		err_and_exit "Can't copy the CARI blockchain in \"$snapshot_path\"."
	fi
	
	cd "$TMP_CARI_BUILDER" || err_and_exit "$TMP_CARI_BUILDER~%cd%"
	
	if ! zip -9 -r "$snapshot_archive_path" "$snapshot_name"; then
		err_and_exit "Can't create the snapshot archive \"$snapshot_archive_path\"."
	fi
	
	test_archive "$snapshot_archive_name" true "cari-snapshot"
fi

################################################################################
# UNINSTALL DEPENDENCIES
################################################################################

if [[ $UNINSTALL_AFTER_BUILD == true ]]; then
	debug_msg "Uninstalling dependencies..."
	
	sudo apt-get remove --purge -y "${dependencies[@]}"
	sudo apt-get autoremove --purge -y
	sudo apt-get autoclean
fi

################################################################################
# RUN THE WALLET
################################################################################

if [[ $RUN_AFTER_BUILD != "none" && -f ${WALLET_PATHS[$RUN_AFTER_BUILD]} && -x ${WALLET_PATHS[$RUN_AFTER_BUILD]} ]]; then
	debug_msg "Running the wallet \"${WALLET_PATHS[$RUN_AFTER_BUILD]}\"..."
	
	"${WALLET_PATHS[$RUN_AFTER_BUILD]}" &
fi

################################################################################
# TIME ELAPSED
################################################################################

time_elapsed
ok
