#!/usr/bin/env bash

# mk_public_bucket.sh - Create Google Cloud public bucket for a new lab/project/class.
#
# ARGUMENTS:
# all: Suffixes of bucket names.
#
# SWITCHES:
#  -i PROJECT-ID : Use PROJECT-ID as project ID.
#  -l LAB-NAME   : Create buckets for lab LAB-NAME.
#  -p PROJ-NAME  : Create buckets for project PROJ-NAME.
#  -c CLASS_NAME : Create buckets for class CLASS-NAME.
#  -d            : Enter debug mode.
#  -v            : Become verbose.
#
# 
# Created by Keith Bettinger on 1/21/15.
#
# Copyright(c) 2015 The Board of Trustees of The Leland Stanford
# Junior University.  All Rights Reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
# 
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
# 
#     * Neither the name of Stanford University nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL STANFORD
# UNIVERSITY BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#


# Get location of this script.
script_dir=`dirname $0`

# Source in code common to all gbsc-gcp scripts.
. $script_dir/gbsc-gcp_common.sh

#
# SCRIPT BODY
#
# Sets:
#   project_id
#   google_group_name
#
#   pi_tag (if given)
#   project_name (if given)
#   class_name (if given)
#
process_arguments $@
shift $?

if [ "$bucket_args" = true ]
then
    for i in "$@"
    do
	create_public_bucket $project_id $i
    done
else
    create_public_bucket $project_id "$project_id-$BUCKET_SUFFIX_PUBLIC"
fi
