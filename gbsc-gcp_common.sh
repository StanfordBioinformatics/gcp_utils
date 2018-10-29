#!/usr/bin/env bash

# gbsc-gcp_common.sh - Code common to all gcp-utils scripts.
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

#
# CONSTANTS
#
GBSC_LOGS_BUCKET='gbsc-gcp-lab-gbsc-logs'

PROJECT_PREFIX='gbsc-gcp'
PROJECT_PREFIX_LAB='lab'
PROJECT_PREFIX_PROJ='project'
PROJECT_PREFIX_CLASS='class'

BUCKET_SUFFIX_GROUP='group'
BUCKET_SUFFIX_PUBLIC='public'
BUCKET_SUFFIX_USER='user'
BUCKET_SUFFIX_LOGS='logs'

STORAGE_LOGGING_PREFIX='Storage/AccessLogs'
COMPUTE_LOGGING_PREFIX='Compute/UsageLogs'

LAB_GROUP_PREFIX='scgpm_lab'
PROJ_GROUP_PREFIX='scgpm_prj'
CLASS_GROUP_PREFIX='scgpm_cls'

STORAGE_REGION='us-west1'
STORAGE_CLASS='regional'

DEBUG=''

# Sets:                                                                                                     
#   project_id : -i switch
#   google_group_name : computed
#                                                                                                           
#   pi_tag (if given) : -l switch
#   project_name (if given) : -p switch
#   class_name (if given) : -c switch
#   bucket_name (if given) : -b switch
#
process_arguments() {

        OPTIND=1
        verbose=0
        bucket_args=false
        while getopts "bc:i:l:p:dv" opt; do
            case "$opt" in
               b)
                   bucket_args=true
                   ;;
               c)
                   class_name=$OPTARG
                   ;;
                i)
                    project_id=$OPTARG
                    ;;
                l)
                    pi_tag=$OPTARG
                    ;;
                p)
                    project_name=$OPTARG
                    ;;
                d)
                    DEBUG="echo % "
                    ;;
                v)  
                    verbose=$((verbose+1))
                    ;;
           esac
        done
        #shift "$((OPTIND-1))" # Shift off the options and optional --.

       # Set project_id, if necessary.
        if [ $project_id ] 
        then
                :  # Do nothing.
                
        elif [ $pi_tag ]
        then
                project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_LAB-$pi_tag"
                google_group_name="$LAB_GROUP_PREFIX-$pi_tag-gcp@stanford.edu"

        elif [ $project_name ]
        then
                project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_PROJ-$project_name"
                google_group_name="$PROJ_GROUP_PREFIX-$project_name-gcp@stanford.edu"

	elif [ $class_name ]
	then
	        project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_CLASS-$class_name"
                google_group_name="$CLASS_GROUP_PREFIX-$class_name-gcp@stanford.edu"
        else
                echo "Need one of -l LAB-NAME, -p PROJ-NAME, or -c CLASS-NAME...exiting."
                exit -1
        fi

       # Set google_group_name.
        if [ $pi_tag ]
        then
                google_group_name="$LAB_GROUP_PREFIX-$pi_tag-gcp@stanford.edu"

        elif [ $project_name ]
        then
                google_group_name="$PROJ_GROUP_PREFIX-$project_name-gcp@stanford.edu"

        elif [ $class_name ]
        then
                google_group_name="$CLASS_GROUP_PREFIX-$class_name-gcp@stanford.edu"

        fi
        
        return $((OPTIND-1))

}

# Arguments:
#  1st: project ID
#  2nd: bucket name
create_group_bucket() {

    local project_id=$1
    local group_bucket=$2

    echo "*********************"
    echo "CREATING GROUP BUCKET: $group_bucket"
    echo "*********************"
        
    # Create the group bucket.
    echo "===> Creating the $group_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $project_id gs://$group_bucket
    echo 
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $project_id $group_bucket
    echo
        
    #
    # Set the bucket ACLs.
    #
    #  Write: Lab Members
    echo "===> Setting ACL of Bucket $group_bucket to Write:$google_group_name"
    $DEBUG gsutil acl ch -g $google_group_name:W gs://$group_bucket
    echo
        
    #
    # Set the default object ACL for the bucket.
    #
    # No need: project-default permissions work here.
       
    echo
}

# Arguments:
#  1st: project ID
#  2nd: bucket name
create_public_bucket() {

    local project_id=$1
    local public_bucket=$2
        
    echo "**********************"
    echo "CREATING PUBLIC BUCKET: $public_bucket"
    echo "**********************"
       
    # Create the public bucket.
    echo "===> Creating the $public_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $project_id gs://$public_bucket
    echo
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $project_id $public_bucket
    echo
        
    #
    # Set the bucket ACLs.
    #
    #  Write: Lab Members  Read: Public
    echo "===> Setting ACL of Bucket $public_bucket to Write:$google_group_name Read:AllUsers"
    $DEBUG gsutil acl ch -g $google_group_name:W -g AllUsers:R gs://$public_bucket
    echo
        
    #
    # Set the default object ACL for the bucket.
    #
    #  Write: Lab Members  Read: Public
    echo "===> Setting Default Object ACL of Bucket to Read:AllUsers"
    $DEBUG gsutil defacl ch -g AllUsers:R gs://$public_bucket
    echo
        
    echo
}

# Arguments:
#  1st: project ID
#  2nd: SUnetID for user.
create_user_bucket() {
    
    local project_id=$1
    local sunet_id=$2
    local user_bucket=$3
        
    echo "********************"
    echo "CREATING USER BUCKET: $user_bucket"
    echo "********************"
        
    # Create the public bucket.
    echo "===> Creating the $user_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $project_id gs://$user_bucket
    echo
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $project_id $user_bucket
    echo
        
    #
    # Set the bucket ACLs.
    #
        
    # Remove the project permissions from the bucket.
    echo "===> Removing default project ACLs from $user_bucket"
    $DEBUG gsutil acl set private gs://$user_bucket
        
    #  Write: User
    echo "===> Setting ACL of Bucket $user_bucket to Write:$sunet_id@stanford.edu"
    $DEBUG gsutil acl ch -u $sunet_id@stanford.edu:W gs://$user_bucket
    echo
        
    #
    # Set the default object ACL for the bucket.
    #
        
    # Remove the project permissions from the bucket.
    echo "===> Removing default project ACLs from objects in $user_bucket"
    $DEBUG gsutil defacl set private gs://$user_bucket
       
    #  Owner: User
    echo "===> Setting default ACL of Objects in Bucket $user_bucket to Owner:$sunet_id@stanford.edu"
    $DEBUG gsutil defacl ch -u $sunet_id@stanford.edu:O gs://$user_bucket
    echo
      
    echo
}

# Arguments:
#  1st: project ID
create_logs_bucket() {
    
    local project_id=$1
    local logs_bucket=$2
        
    echo "********************"
    echo "CREATING LOGS BUCKET: $logs_bucket"
    echo "********************"
        
    # Create the public bucket.
    echo "===> Creating the $logs_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_REGION -l $STORAGE_CLASS -p $project_id gs://$logs_bucket
    echo

    # Set logging of access to bucket to GBSC Billing bucket.
    echo "===> Setting logging of $logs_bucket to $GBSC_LOGS_BUCKET"
    set_storage_logging $project_id $logs_bucket
    echo
        
    #
    # Set the bucket ACLs.
    #
        
    # Remove the project permissions from the bucket.
    echo "===> Removing default project ACLs from $logs_bucket"
    $DEBUG gsutil acl set private gs://$logs_bucket
    echo        

    echo
}

# Arguments:
#  1st: Project ID
set_firewall_rules() {

    local project_id=$1

    ###
    # All modifications are to the 'default' network.
    ###

    #
    # Delete the 'default-allow-rdp' firewall rule.
    #
    echo "Deleting the 'default-allow-rdp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $project_id --quiet delete default-allow-rdp
    echo

    #
    # Delete the 'default-allow-ssh' firewall rule.
    #
    echo "Deleting the 'default-allow-ssh' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $project_id --quiet delete default-allow-ssh
    echo
        
    #
    # Delete the 'default-allow-icmp' firewall rule.
    #
    echo "Deleting the 'default-allow-icmp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $project_id --quiet delete default-allow-icmp
    echo

    #
    # Add the 'default-allow-stanford-ssh' firewall rule.
    #
    echo "Adding the 'default-allow-stanford-ssh' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $project_id --quiet create default-allow-stanford-ssh --allow tcp:22 --source-ranges 171.64.0.0/14 --description 'Allow SSH connections from Stanford addresses' 
    echo
        
    #
    # Add the 'default-allow-stanford-icmp' firewall rule.
    #
    echo "Adding the 'default-allow-stanford-icmp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $project_id --quiet create default-allow-stanford-icmp --allow icmp --source-ranges 171.64.0.0/14 --description 'Allow ICMP traffic from Stanford addresses' 
    echo

}

#
# set_compute_logging: Sets up compute engine usage logging on given project.
#
# Arguments:
#  1st: Project ID
#
set_compute_logging() {

    local project_id=$1
        
    echo "==> Setting Compute Engine logging to $GBSC_LOGS_BUCKET for $project_id."
    $DEBUG gcloud compute project-info set-usage-bucket --project $project_id --bucket $GBSC_LOGS_BUCKET --prefix $COMPUTE_LOGGING_PREFIX/$project_id/$project_id
        
}

#
# set_storage_logging: Sets up storage usage logging on given bucket/project.
#
# Arguments:
#  1st: Project ID
#  2nd: Bucket
#
set_storage_logging() {

    local project_id=$1
    local bucket=$2

    echo "==> Setting Storage logging to $GBSC_LOGS_BUCKET for bucket $bucket in $project_id."
    $DEBUG gsutil logging set on -b gs://$GBSC_LOGS_BUCKET -o $STORAGE_LOGGING_PREFIX/$project_id/$bucket/$bucket gs://$bucket

}

#
# set_compute_logging: Sets up compute engine usage logging on given project.
#
# Arguments:
#  1st: Project ID  
#
set_compute_cloud_logging() {

    local project_id=$1

    echo "Setting Compute Engine Cloud logging startup-script-url for $project_id."
    $DEBUG gcloud compute project-info add-metadata --project $project_id --metadata startup-script-url=https://dl.google.com/cloudagents/install-logging-agent.sh

}
