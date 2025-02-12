#!/bin/bash
#
# Copyright (c) 2018 Samsung Electronics Co., Ltd. All Rights Reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
# NOTE: Supposed that this script would be executed with an artifact path.
#       The artifact path has tests/(test suite) and Product/
#       Reference this PR(https://github.sec.samsung.net/STAR/nnfw/pull/375).

function Usage()
{
    echo "Usage: ./$0 --artifactpath=.    # run all tests"
    echo "Usage: ./$0 --artifactpath=/home/dragon/nnfw --frameworktest --verification --benchmark    # run fw test & verfication and benchmark"
    echo ""
    echo "--artifactpath            - (default={test-driver.sh's path}/../../) it should contain tests/ and Product/"
    echo ""
    echo "Following option is only needed when you want to test benchmark."
    echo "--benchmark_onert_op     - (default=off) run benchmark per operation on onert"
    echo ""
    echo "etc."
    echo "--reportdir               - (default=\$ARTIFACT_PATH/report) directory to save report"
    echo ""
}

TEST_DRIVER_DIR="$( cd "$( dirname "${BASH_SOURCE}" )" && pwd )"
ARTIFACT_PATH="$TEST_DRIVER_DIR/../../"
BENCHMARK_ONERT_OP_ON="false"
REPORT_DIR=""

for i in "$@"
do
    case $i in
        -h|--help|help)
            Usage
            exit 1
            ;;
        --artifactpath=*)
            ARTIFACT_PATH=${i#*=}
            ;;
        --benchmark_onert_op)
            BENCHMARK_ONERT_OP_ON="true"
            ;;
        --reportdir=*)
            REPORT_DIR=${i#*=}
            ;;
        *)
            # Be careful that others params are handled as $ARTIFACT_PATH
            ARTIFACT_PATH="$i"
            ;;
    esac
    shift
done

ARTIFACT_PATH="$(readlink -f $ARTIFACT_PATH)"

if [ -z "$UNIT_TEST_DIR" ]; then
    UNIT_TEST_DIR=$ARTIFACT_PATH/Product/out/unittest
fi

if [ -z "$REPORT_DIR" ]; then
    REPORT_DIR=$ARTIFACT_PATH/report
fi

source $TEST_DRIVER_DIR/common.sh

if [ "$BENCHMARK_ONERT_OP_ON" == "true" ]; then
    DRIVER_BIN=$ARTIFACT_PATH/Product/out/bin/tflite_run

    $TEST_DRIVER_DIR/benchmark_nnapi.sh \
        --test_op \
        --driverbin=$DRIVER_BIN \
        --reportdir=$REPORT_DIR/benchmark_op \
        --modelfilepath=$ARTIFACT_PATH/tests/scripts/models
fi

# Make json file. Actually, this process is only needed on CI. That's why it is in test-driver.sh.
if [ "$BENCHMARK_ONERT_OP_ON" == "true" ]; then
    # functions to fill json with benchmark results
    source $ARTIFACT_PATH/tests/scripts/print_to_json.sh
    if [ "$BENCHMARK_ONERT_OP_ON" == "true" ]; then
        print_to_json $REPORT_DIR/benchmark_op $REPORT_DIR "benchmark_op_result.json"
    else
        print_to_json $REPORT_DIR/benchmark $REPORT_DIR "benchmark_result.json"
    fi
fi
