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

# Check ccache hit rate for 99-100%.
# Trigger retry if hit rate is below 99%.
retry_event () {
	sleep 110m
	export CCACHE_DIR=/tmp/ccache
	export CCACHE_EXEC=$(which ccache)
	hit_rate=$(ccache -s | awk '/hit rate/ {print $4}' | cut -d'.' -f1)
	if [ $hit_rate -lt 99 ]; then
		git clone https://${TOKEN}@github.com/geopd/Builder-CI-A12 cirrus && cd $_
		git commit --allow-empty -m "Retry: Ccache loop $(date -u +"%D %T%P %Z")"
		git push -q
	else
		echo "Ccache is fully configured"
	fi
}

cd /tmp/rom
retry_event
