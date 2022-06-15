#!/bin/bash

#
# Copyright (C) 2022 GeoPD <geoemmanuelpd2001@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# User
GIT_USER="GeoPD"

# Email
GIT_EMAIL="geoemmanuelpd2001@gmail.com"

# Local manifest
LOCAL_MANIFEST=https://${TOKEN}@github.com/geopd/local_manifests

# ROM Manifest and Branch
rom() {
	case "${NAME}" in
		"AOSPA-12") MANIFEST=https://github.com/AOSPA/manifest.git BRANCH=sapphire
		;;
		"AEX-12") MANIFEST=https://github.com/AospExtended/manifest.git BRANCH=12.1.x
		;;
		"Crdroid-12") MANIFEST=https://github.com/crdroidandroid/android.git BRANCH=12.1
		;;
		"dot12.1") MANIFEST=https://github.com/DotOS/manifest.git BRANCH=dot12.1
		;;
		"Evox-12") MANIFEST=https://github.com/Evolution-X/manifest.git BRANCH=snow
		;;
		*) echo "Setup Rom manifest and branch name in case function"
 		exit 1
 		;;
	esac
}

# Build package and build type
build_package() {
	case "${NAME}" in
		"AOSPA-12") PACKAGE=otapackage BUILD_TYPE=userdebug
		;;
		"AEX-12") PACKAGE=aex BUILD_TYPE=user
		;;
		"Crdroid-12") PACKAGE=bacon BUILD_TYPE=user
		;;
		"dot12.1") PACKAGE=bacon BUILD_TYPE=user
		;;
		"Evox-12") PACKAGE=evolution BUILD_TYPE=user
		;;
		*) echo "Build commands need to be added!"
		exit 1
		;;
	esac
}

# Export tree paths
tree_path() {
	# Device,vendor & kernel Tree paths
	DEVICE_TREE=device/xiaomi/sakura
	VENDOR_TREE=vendor/xiaomi
	KERNEL_TREE=kernel/xiaomi/msm8953
}

# Build post-gen variables (optional)
lazy_build_post_var() {
	LAZY_BUILD_POST=false
	INCLUDE_GAPPS=false
	ANDROID_VERSION="Android 12L"
	RELEASE_TYPE="Stable"
	DEV=GeoPD
	TG_LINK=https://t.me/mysto_o
	GRP_LIN="mystohub"
	DEVICE2=daisa #Since I do unified builds for daisy&sakura
}

# Clone needed misc scripts and ssh priv keys (optional)
clone_file() {
	rclone copy brrbrr:scripts/setup_script.sh /tmp/rom
	rclone copy brrbrr:ssh/ssh_ci /tmp/rom
}

# Setup build dir
build_dir() {
	mkdir -p /tmp/rom
	cd /tmp/rom
}

# Git configuration values
git_setup() {
	git config --global user.name $GIT_USER
	git config --global user.email $GIT_EMAIL

	# Establish Git cookies
	echo "${GIT_COOKIES}" > ~/git_cookies.sh
	bash ~/git_cookies.sh
}

# SSH configuration using priv key
ssh_authenticate() {
	sudo chmod 0600 /tmp/rom/ssh_ci
	sudo mkdir ~/.ssh && sudo chmod 0700 ~/.ssh
	eval `ssh-agent -s` && ssh-add /tmp/rom/ssh_ci
	ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts
}

# Repo sync and additional configurations
build_configuration() {
	repo init --depth=1 --no-repo-verify -u $MANIFEST  -b $BRANCH -g default,-mips,-darwin,-notdefault
	git clone $LOCAL_MANIFEST -b $NAME .repo/local_manifests
	repo sync -c --no-clone-bundle --no-tags --optimized-fetch --prune --force-sync -j13
	if [ $GIT_USER = GeoPD ]; then
		source setup_script.sh &> /dev/null
	fi

}

# Setup Gapps package on release post generation
build_gapps() {
	if [ $INCLUDE_GAPPS = true ]; then
		rm -rf ${post[0]}
		export WITH_GAPPS=true
		build_command
		compiled_zip
		build_upload
		telegram_post
	fi
}

# Build commands for rom
build_command() {
	source build/envsetup.sh
	ccache_configuration
	tree_path
	lunch $(basename -s .mk $(find $DEVICE_TREE -maxdepth 1 -name "*$T_DEVICE*.mk"))-${BUILD_TYPE}
	m ${PACKAGE} -j 20
}

# Export time, time format for telegram messages
time_sec() {
	export $1=$(date +"%s")
}

time_diff() {
	export $1=$(($3 - $2))
}

# Branch name & Head commit sha for ease of tracking
commit_sha() {
	for repo in ${DEVICE_TREE} ${VENDOR_TREE} ${KERNEL_TREE}
	do
		printf "[$(echo $repo | cut -d'/' -f1 )/$(git -C ./$repo/.git rev-parse --short=10 HEAD)]"
	done
}

# Setup ccache
ccache_configuration() {
	export CCACHE_DIR=/tmp/ccache
	export CCACHE_EXEC=$(which ccache)
	export USE_CCACHE=1
	cat > ${CCACHE_DIR}/ccache.conf <<EOF
depend_mode = true
file_clone = true
limit_multiple = 0.9
max_size = 0
compression = false
hash_dir = false
EOF
	ccache -z
}

# Setup TG message and build posts
telegram_message() {
	curl -s -X POST "https://api.telegram.org/bot${BOTTOKEN}/sendMessage" -d chat_id="${CHATID}" \
	-d "parse_mode=Markdown" \
	-d text="$1"
}

telegram_build() {
	curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot${BOTTOKEN}/sendDocument" \
	-F chat_id="${CHATID}" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

telegram_build_post() {
	curl -s -F "photo=@$1" "https://api.telegram.org/bot${BOTTOKEN}/sendPhoto" \
	-F chat_id="${CHATID}" \
	-F "disable_web_page_preview=true" \
	-F "parse_mode=Markdown" \
	-F caption="$2"
}

# Send Telegram posts for sync finished, build finished and error logs
telegram_post_sync() {
	telegram_message "
	*🌟 $NAME Build Triggered 🌟*
	*Date:* \`$(date +"%d-%m-%Y %T")\`
	*✅ Sync finished after $((SDIFF / 60)) minute(s) and $((SDIFF % 60)) seconds*"  &> /dev/null
}

telegram_post_build() {
	telegram_message "
	*✅ Build finished after $(($BDIFF / 3600)) hour(s) and $(($BDIFF % 3600 / 60)) minute(s) and $(($BDIFF % 60)) seconds*

	*ROM:* \`${post[1]}\`
	*MD5 Checksum:* \`${post[3]}\`
	*Download Link:* [Vanilla](${DWD1}) | [Gapps](${DWD2})
	*Size:* \`${post[2]}\` | \`${post[6]}\`

	*Commit SHA:* \`$(commit_sha)\`

	*Date:*  \`$(date +"%d-%m-%Y %T")\`" &> /dev/null
}

telegram_post_error() {
	telegram_build ${ERROR_LOG} "
	*❌ Build failed to compile after $(($BDIFF / 3600)) hour(s) and $(($BDIFF % 3600 / 60)) minute(s) and $(($BDIFF % 60)) seconds*
	_Date:  $(date +"%d-%m-%Y %T")_" &> /dev/null
}

# Sorting final zip ( commonized considering ota zips, .md5sum etc with similiar names  in diff roms)
post=()
compiled_zip() {
	OUT=$(pwd)/out/target/product/${T_DEVICE}
	ZIP=$(find ${OUT}/ -maxdepth 1 -name "*${T_DEVICE}*.zip" | perl -e 'print sort { length($b) <=> length($a) } <>' | head -n 1)
	ZIPNAME=$(basename ${ZIP})
	ZIPSIZE=$(du -sh ${ZIP} |  awk '{print $1}')
	MD5CHECK=$(md5sum ${ZIP} | cut -d' ' -f1)
	echo "${ZIP}"
	post+=("${ZIP}") && post+=("${ZIPNAME}") && post+=("${ZIPSIZE}") && post+=("${MD5CHECK}")
}

# Generate changelog of past 7 days
generate_changelog() {
	CHANGELOG=$(pwd)/changelog_gen.txt
	touch ${CHANGELOG}
	echo "Generated Date: $(date)" >> ${CHANGELOG}

	for i in $(seq 7);
	do
		after_date=`date --date="$i days ago" +%F`
		until_date=`date --date="$(expr ${i} - 1) days ago" +%F`
		echo "====================" >> ${CHANGELOG}
		echo "     $until_date    " >> ${CHANGELOG}
		echo "====================" >> ${CHANGELOG}
		while read path; do
			git_log=`git --git-dir ./${path}/.git log --after=$after_date --until=$until_date --format=tformat:"%s [%an]"`
			if [[ ! -z "${git_log}" ]]; then
			echo "* ${path}" >> ${CHANGELOG}
			echo "${git_log}" >> ${CHANGELOG}
			echo "" >> ${CHANGELOG}
			fi
		done < ./.repo/project.list
	done
}

# Telegraph post
telegraph_post() {
	curl -X POST \
		-H 'Content-Type: application/json' \
		-d '{
			"access_token": "'${TGP_TOKEN}'",
			"title": "'$3'",
			"author_name":"geopd",
			"content": [{"tag":"'$1'","children":["'"$(cat $2)"'"]}],
			"return_content":"true"
		}' \
		https://api.telegra.ph/createPage | cut -d'"' -f12
}

# Generate telegraph post of changelog
changelog_post() {
	generate_changelog
	sed -i "s/\"/'/g" ${CHANGELOG}
	telegraph_post p ${CHANGELOG} Source-Changelogs
}

# Generate telegraph post including zipname and MD5
zip_details() {
    ZIPDETAILS=$(pwd)/zipdetails.txt
    touch ${ZIPDETAILS}
    printf "ROM Name: %s\n\n" "${post[1]} (VANILLA)" "${post[5]} (GAPPS)" >> ${ZIPDETAILS}
    printf "MD5 Checksum: %s\n\n" "${post[3]} (VANILLA)" "${post[7]} (GAPPS)" >> ${ZIPDETAILS}
    telegraph_post b ${ZIPDETAILS} ROM-Info
}

# Aah yes! Generate a build post that's similiar to normal official posts
# Now no more pain of making posts; just forward and Enjoy.
lazy_build_post() {
	rclone copy brrbrr:images/ $(pwd)
	if [ -f $(pwd)/${NAME}* ]; then
		POST_IMAGE=$(pwd)/${NAME}*
	else
		POST_IMAGE=$(pwd)/mystohub*
	fi
	T_NAME=$(echo ${NAME,,}| cut -d'-' -f1)

	telegram_build_post ${POST_IMAGE} "
	*#${T_NAME} #ROM #$(echo ${ANDROID_VERSION,,} | tr -d ' ') #${T_DEVICE,,} #${DEVICE2,,}
	$(echo ${post[1]^^}| cut -d'-' -f1) | ${ANDROID_VERSION^}
	Updated:* \`$(date +"%d-%B-%Y")\`
	*By:* [${DEV}](${TG_LINK})

	*▪️ Downloads:* [Vanilla](${DWD1}) *(${post[2]})* | [Gapps](${DWD2}) *(${post[6]})*
	*▪️ Changelogs:* [Source Changelogs]($(echo $(changelog_post) | tr -d '\\'))
	*▪️ ROM Info:* [MD5 Checksum]($(echo $(zip_details) | tr -d '\\'))
	*▪️ Support:* [Device](https://t.me/${GRP_LIN})

	*Notes:*
	• ${ANDROID_VERSION} ${RELEASE_TYPE} Release.

	*Build Info:*
	• *✅ Build finished after $(($BDIFF / 3600)) hrs : $(($BDIFF % 3600 / 60)) mins : $(($BDIFF % 60)) secs*
	• *Commit SHA:* \`$(commit_sha)\`

	*Date:*  \`$(date +"%d-%m-%Y %T")\`" &> /dev/null
}

# Upload rom zip to tdrive/gdrive
build_upload() {
	if [ -f ${OUT}/${post[1]} ]; then
		rclone copy ${post[0]} brrbrr:rom -P
		DWD1=${TDRIVE}${post[1]}
	elif [ -f ${OUT}/${post[5]} ]; then
		rclone copy ${post[4]} brrbrr:rom -P
		DWD2=${TDRIVE}${post[5]}
	fi
}

# Post Build finished with Time,duration,md5,size&Tdrive link OR post build_error&trimmed build.log in TG
telegram_post() {
	if [[ -f ${OUT}/${post[1]} || -f ${OUT}/${post[5]} ]]; then
		if [[ $GIT_USER = GeoPD && $LAZY_BUILD_POST = true ]]; then
			lazy_build_post
		else
			telegram_post_build
		fi
	else
		echo "CHECK BUILD LOG" >> $(pwd)/out/build_error
		ERROR_LOG=$(pwd)/out/build_error
		telegram_post_error
	fi
}


# Compile moments! Yay!
compile_moments() {
	build_dir
	git_setup
	if [ $GIT_USER = GeoPD ]; then
		clone_file
		lazy_build_post_var
	fi
	ssh_authenticate
	time_sec SYNC_START
	rom
	build_configuration
	time_sec SYNC_END
	time_diff SDIFF SYNC_START SYNC_END
	telegram_post_sync
	time_sec BUILD_START
	build_package
	build_command
	time_sec BUILD_END
	time_diff BDIFF BUILD_START BUILD_END
	compiled_zip
	build_upload
	if [ ! $INCLUDE_GAPPS = true ]; then
		telegram_post
	fi
	build_gapps
	ccache -s
}

compile_moments
