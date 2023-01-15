#!/bin/bash

# windows ps
# certutil -hashfile C:\Users\mcd\Desktop\mcd_op6x_r12.zip sha1

# clear terminal window
clear

##### Name ####################################################

# Name
DEVICE="op6x"
KERNEL_NAME="mcd_${DEVICE}"
#BUILDDATE="$(date +"%d-%m-%Y")"
VER="r19"

DEFCONFIG="mcd_defconfig"
#DEFCONFIG="enchilada_defconfig"

KERNEL_ZIP_NAME="${KERNEL_NAME}_${VER}"
CHANGELOG_NAME="changelog_op6x_${VER}"
LOCALVERSIONSTRING="-mcd"

export KBUILD_BUILD_USER="mcd"
export KBUILD_BUILD_HOST="vmbox"

# Env
export ARCH="arm64"

# Threads
THREAD="-j$(grep -c ^processor /proc/cpuinfo)"

##### PATHS ####################################################

AROOT="${PWD}"
KERNEL_DIR="${AROOT}"
KERNEL_OUTPUT="${KERNEL_DIR}/out"
KERNEL_FILE="Image.gz-dtb"
KERNEL_FILE_DIR="${KERNEL_OUTPUT}/arch/${ARCH}/boot"
TOOLCHAIN_DIR="${AROOT}/toolchains"
AK3_DIR="${AROOT}/AnyKernel3"

# check if AK3 dir supports both kernel types
if [ -d "${AK3_DIR}/kernels" ]; then
	TWOKERNELZIP=true
else
	TWOKERNELZIP=false
fi

##### Toolchain ################################################

#CLANG_PATH="${TOOLCHAIN_DIR}/mcd-clang" # Custom
#CLANG_PATH="${TOOLCHAIN_DIR}/linux-x86/clang-r416183b1" # AOSP android-12.0.0_r1
#CLANG_PATH="${TOOLCHAIN_DIR}/linux-x86/clang-r450784d"	# AOSP android-13.0.0_r1
CLANG_PATH="${TOOLCHAIN_DIR}/clang-r416183b" # android-13.0.0_r0.20, v12.0.5

# Clang paths
CLANG_BIN="${CLANG_PATH}/bin"

# GCC paths
gcc_arm64="${TOOLCHAIN_DIR}/aarch64-linux-android-4.9/bin"
gcc_arm32="${TOOLCHAIN_DIR}/arm-linux-androideabi-4.9/bin"

# Binutils prefixes
gcc_prefix64="aarch64-linux-android-"
gcc_prefix32="arm-linux-androidkernel-"

###### KERNEL NAMING #####################################

cd "${KERNEL_DIR}" || exit

CURRENTBRANCH="$(git rev-parse --abbrev-ref HEAD)"

case "$CURRENTBRANCH" in
	mcd-CUSTOM* )
		# release custom
		ISRELEASE=true
		ISCUSTOM=true
		if [ $TWOKERNELZIP = false ]; then
			KERNEL_ZIP_NAME="${KERNEL_ZIP_NAME}-custom"
		fi
		LOCALVERSIONSTRING="_${VER}-custom"
		;;
	mcd-OOS* )
		# release oos
		ISRELEASE=true
		ISCUSTOM=false
		if [ $TWOKERNELZIP = false ]; then
			KERNEL_ZIP_NAME="${KERNEL_ZIP_NAME}-oos"
		fi
		LOCALVERSIONSTRING="_${VER}-oos"
		;;
	*oos* )
		# test oos
		ISRELEASE=false
		ISCUSTOM=false
		KERNEL_ZIP_NAME="${CURRENTBRANCH}"
		LOCALVERSIONSTRING="_${CURRENTBRANCH}"
		CHANGELOG_NAME="changelog_${CURRENTBRANCH}"
		;;
	* )
		# test custom
		ISRELEASE=false
		ISCUSTOM=true
		KERNEL_ZIP_NAME="${CURRENTBRANCH}"
		LOCALVERSIONSTRING="_${CURRENTBRANCH}"
		CHANGELOG_NAME="changelog_${CURRENTBRANCH}"
		;;
esac

# set final filename
CHANGELOG_FILE="${AROOT}/${CHANGELOG_NAME}.txt"

export LOCALVERSION="${LOCALVERSIONSTRING}"

cd "${AROOT}" || exit

#################################################################

# Bash Color
RST='\033[0m' 		# reset
BLD="\033[1m"		# bold
RED='\033[01;31m'	# red
GRN='\033[01;32m'	# green
YLW="\033[01;33m"	# yeelow
CYN='\033[01;36m'	# cyan

# Alias for echo to handle escape codes like colors
function echo() {
    command echo -e "$@"
}

# Prints a formatted header to point out what is being done to the user
function header() {
    echo "${GRN}"
    echo " ====$(for _ in $(seq ${#1}); do echo "=\c"; done)===="
    echo " ==  ${1}  =="
    echo " ====$(for _ in $(seq ${#1}); do echo "=\c"; done)===="
    echo "${RST}"
}

# Prints an error in bold red
function die() {
    echo
    echo " ${RED}${1}${RST}"
    echo
    exit 1
}

# Prints a statement in bold GRN
function success() {
	echo
    echo " ${GRN}${1}${RST}"
}

# Prints a warning in bold yellow
function warn() {
    echo "${YLW}${1}${RST}"
}

# Get the version of Clang in an user-friendly form
function get_clang_version() {
	"$1" --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//'
}

# Get the version of Linker in an user-friendly form
function get_ld_version() {
	"$1" --version | head -n 1 | perl -pe 's/\((?:http|git).*?\)//gs' | sed 's/(compatible with [^)]*)//' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//'
}

# Get the Linker name in an user-friendly form
function get_ld_name() {
	"$1" --version | cut -d' ' -f1
}

# Get the version of GCC in an user-friendly form
function get_gcc_version() {
	"$1" --version | head -n 1 | cut -d'(' -f2 | tr -d ')' | sed -e 's/[[:space:]]*$//'
}

# Show differences between the committed defconfig and current config
function dc() {
	diff "${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}" "${KERNEL_OUTPUT}/.config"
}

# open .config from /out
function openconfig() {
	subl "${KERNEL_OUTPUT}/.config"
}

# open defconfig from kerneltree
function opendefconfig() {
	subl "${KERNEL_DIR}/arch/${ARCH}/configs/${DEFCONFIG}"
}

# check linker
function checklinker() {
	readelf --string-dump .comment "${KERNEL_OUTPUT}/vmlinux"
}

# Clean up working dirs
function clean_all() {
	# remove kernel images
	if [[ $(find "${AK3_DIR}" -type f -name "${KERNEL_FILE}") ]]; then
		warn " Found kernel images:"
		find "${AK3_DIR}" -type f -name "${KERNEL_FILE}"

		echo
		while read -r -p " Remove images? [y / n] : " removeimages
		do
		case "$removeimages" in
			y|yes )
				# find and delete kernel image
				find "${AK3_DIR}" -type f -name "${KERNEL_FILE}" -delete
				warn " Deleted kernel image(s)."
				echo
				sleep 1
				break
				;;
			n|no )
				warn " Keep kernel image(s)."
				echo
				sleep 1
				break
				;;
			*)
				echo -e "${RED}"
				echo " Invalid input, try again!"
				echo -e "${RST}"
				;;
		esac
		done
	fi

	cd "${KERNEL_DIR}" || exit
	make "${THREAD}" mrproper
	cd "${AROOT}" || exit	
}

function kmake-wrapper(){
	cd "${KERNEL_DIR}" || exit

	warn "Wrapper"
	echo

	# delete previous kernel image - if present
	if [ -f "${KERNEL_FILE_DIR}/${KERNEL_FILE}" ]; then
		rm "${KERNEL_FILE_DIR}/${KERNEL_FILE}"
	fi

	# generate defconfig
	make -s O="${KERNEL_OUTPUT}" "${DEFCONFIG}"

	PATH="${CLANG_BIN}:${gcc_arm64}:${gcc_arm32}:${PATH}" \
	LD_LIBRARY_PATH="${CLANG_PATH}/lib64:${LD_LIBRARY_PATH}" \
	make "${THREAD}" \
		O="${KERNEL_OUTPUT}" \
		ARCH="${ARCH}" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="${gcc_prefix64}" \
		CROSS_COMPILE_ARM32="${gcc_prefix32}" \
		CROSS_COMPILE_COMPAT="${gcc_prefix32}" \
		HOSTCC="clang" \
		HOSTCXX="clang++" \
		CC=clang \
		AR="llvm-ar" \
		NM="llvm-nm" \
		STRIP="llvm-strip" \
		OBJCOPY="llvm-objcopy" \
		OBJDUMP="llvm-objdump" \
		KBUILD_COMPILER_STRING="$(get_clang_version "${CLANG_BIN}"/clang)" \
		2>&1 | tee ../kernel_log.txt

	cd "${AROOT}" || exit
}

function kmake-wrapper-llvm(){
	cd "${KERNEL_DIR}" || exit

	warn " Info: LLVM Wrapper"
	echo

	# delete previous kernel image - if present
	if [ -f "${KERNEL_FILE_DIR}/${KERNEL_FILE}" ]; then
		rm "${KERNEL_FILE_DIR}/${KERNEL_FILE}"
	fi

	# generate defconfig
	make -s O="${KERNEL_OUTPUT}" "${DEFCONFIG}"

	PATH="${CLANG_BIN}:${gcc_arm64}:${gcc_arm32}:${PATH}" \
	LD_LIBRARY_PATH="${CLANG_PATH}/lib64:${LD_LIBRARY_PATH}" \
	make "${THREAD}" \
		O="${KERNEL_OUTPUT}" \
		ARCH="${ARCH}" \
		CLANG_TRIPLE="aarch64-linux-gnu-" \
		CROSS_COMPILE="${gcc_prefix64}" \
		CROSS_COMPILE_ARM32="${gcc_prefix32}" \
		CROSS_COMPILE_COMPAT="${gcc_prefix32}" \
		LLVM=1 \
		LLVM_IAS=1 \
		KBUILD_COMPILER_STRING="$(get_clang_version "${CLANG_BIN}"/clang)" \
		2>&1 | tee ../kernel_log.txt

	cd "${AROOT}" || exit
}

# Zip kernel
function make_zip() {
	# check if kernel image is present, else abort
	if [[ ! $(find "${KERNEL_FILE_DIR}" -type f -name "${KERNEL_FILE}") ]]; then
		warn " No kernel image available!"
		die " Aborting..."
	fi

	# check if ak3 dir supports both kernel types
	if [ $TWOKERNELZIP = true ]; then
		warn " Installer: Two kernel image support!"
		echo
		if [ $ISCUSTOM = true ]; then
			echo " Copy ${RED}custom${RST} kernel image..."
			echo
			cp -v "${KERNEL_FILE_DIR}/${KERNEL_FILE}" "${AK3_DIR}/kernels/custom"
			echo
			sleep 1
		else
			echo " Copy ${RED}OxygenOS${RST} kernel image..."
			echo
			cp -v "${KERNEL_FILE_DIR}/${KERNEL_FILE}" "${AK3_DIR}/kernels/oos"
			echo
			sleep 1
		fi
		# change filename, if both kernel images exists, remove nameing
		if [[ -f "${AK3_DIR}/kernels/oos/${KERNEL_FILE}" ]]; then
			if [[ -f "${AK3_DIR}/kernels/custom/${KERNEL_FILE}" ]]; then
				KERNEL_ZIP_NAME=${KERNEL_ZIP_NAME//-custom/}
				KERNEL_ZIP_NAME=${KERNEL_ZIP_NAME//-oos/}
			fi
		fi
	else

	warn " Installer: Stock image support!"
	echo
	echo " Copy ${RED}OxygenOS${RST} kernel image..."
	cp "${KERNEL_FILE_DIR}/${KERNEL_FILE}" "${AK3_DIR}/${KERNEL_FILE}"
	fi
	
	# zip
	cd "${AK3_DIR}" || exit
	zip -q -r "${KERNEL_ZIP_NAME}".zip ./* -x .git README.md LICENSE ./*placeholder
	mv ./*.zip "${AROOT}"
	cd "${AROOT}" || exit
}

# Gernerate changelog
function changelog() {
	if [ -f "${CHANGELOG_FILE}" ]; then
		rm -f "${CHANGELOG_FILE}"
	fi

	cd "${KERNEL_DIR}" || exit

	LATEST_TAG=$(git describe --abbrev=0 --tags)
	PREVIOUS_TAG=$(git describe --abbrev=0 --tags "$(git rev-list --tags --skip=1  --max-count=1)")

	touch "${CHANGELOG_FILE}"
	{
    echo "## changelog ${LATEST_TAG}";
    echo "";
    git log --pretty=tformat:"%h  %s  [%an]" "${LATEST_TAG}...${PREVIOUS_TAG}";
	} >> "${CHANGELOG_FILE}"

	cd "${AROOT}" || exit
}

# Gernerate sh1sum's
function gen_sha1sum() {
	sha1sum ./*.zip
	#sha1sum "$KERNEL_ZIP_NAME.zip"
}

####### Terminal Window #############################################

function MENU() {
	echo
	echo "${GRN} == Project info ==${RST}"
	echo " - Branch: '${YLW}${CURRENTBRANCH}${RST}'"
	[ $ISCUSTOM = true ] && build="${YLW}Custom ROM${RST}" || build="${YLW}OxygenOS${RST}"
	[ $ISRELEASE = true ] && echo " - Release '${build}' | Version: '${YLW}${VER}${RST}'" || echo " - ${RED}Test${RST} ${build} build"
	[ $TWOKERNELZIP = true ] && echo " - Two kernel image ZIP"
	header "Main Menu"
	echo " [c]  Clean up working dir's"
	echo " [b]  Build kernel"
	echo " [z]  Zip Kernel"
	echo
	echo " [d]  Diff generated .config against defconfig"
	echo " [o]  Open generated .config from /out folder"
	echo " [od] Open defconfig from kerneltree"
	echo " [cl] Check used linker"
	echo
	echo " [gl] Generate changelog"
	echo " [gh] Generate sha1sum's"
	echo
	echo "${BLD} [e]  Exit script${RST}"
	echo
}

while MENU && read -r -p " Input: " userchoice
do
case "$userchoice" in
    i|info)
    	clear
    	header "Information" "${CYN}"
		information
		sleep 1.5
		;;
    c|clean)
    	clear
		header "Clean up"
		clean_all
		sleep 1
		success "Done."
		sleep 1
		;;
    b|build)
    	clear
    	header "Build kernel"
		echo " Active compiler: '${YLW}$(get_clang_version "${CLANG_BIN}"/clang)${RST}'"
		echo

		DATE_START="$(date +"%s")"

		# make command
		kmake-wrapper-llvm

		DATE_END="$(date +"%s")"

		# if kernel image does not exist, exit
		if [ ! -f "${KERNEL_FILE_DIR}/${KERNEL_FILE}" ]; then
			die " Compiling was NOT successful! Aborting."
		fi

		DIFF="$(("${DATE_END}" - "${DATE_START}"))"
		success "Completed in: "$(("${DIFF}" / 60))" minute(s) and "$(("${DIFF}" % 60))" seconds."
		sleep 1
		;;
    z|zip)
    	clear
		header "Zip Kernel"
		make_zip
		warn " Filename: ${KERNEL_ZIP_NAME}.zip"
		success "Done."
		sleep 1
		;;
    gl|log)
    	clear
    	header "Generate changelog"
		changelog
		echo " Filename: ${CHANGELOG_FILE}"
		success "Done."
		sleep 1
		;;
    gh|sha1sum)
    	clear
    	header "Generate sha1-sum"
		gen_sha1sum
		success "Done."
		sleep 1
		;;
    d|diff)
    	clear
    	header "Show diff"
		dc
		success "Done."
		sleep 1
		;;
	o|openconfig)
		clear
    	header "Opening .config file..."
    	sleep 1
    	openconfig
		sleep 1
		;;
	od|opendefconfig)
		clear
    	header "Opening defconfig..."
    	sleep 1
    	opendefconfig
		sleep 1
		;;
	cl|linker)
		clear
    	header "Check Linker"
    	sleep 1
		checklinker
		sleep 1
		;;
    e|exit)
		echo
    	warn " Exiting script..."
    	echo
		break
        ;;
    *)
		echo -e "${RED}"
		echo "     Invalid input, try again!"
		echo -e "${RST}"
		;;
    esac
done

#################################################################
