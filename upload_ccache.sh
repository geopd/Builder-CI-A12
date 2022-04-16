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

ccache_upload () {
	sleep 96m
	echo $(date +"%d-%m-%Y %T")
	time tar "-I zstd -1 -T2" -cf $1.tar.zst $1
	rclone copy --drive-chunk-size 256M --stats 1s $1.tar.zst brrbrr:$1/$NAME -P
}

ccache_stats () {
	export CCACHE_DIR=/tmp/ccache
	export CCACHE_EXEC=$(which ccache)
	ccache -s
}

cd /tmp
ccache_upload ccache
ccache_stats
