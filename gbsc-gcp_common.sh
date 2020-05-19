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
PROJECT_PREFIX_PROJ='prj'
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
        while getopts "bc:i:l:p:g:dv" opt; do
            case "$opt" in
               b)
                   bucket_args=true
                   ;;
               c)
                   class_name=$OPTARG
                   ;;
               i)
                   gcp_project_id=$OPTARG
                   ;;
               l)
                   pi_tag=$OPTARG
                   ;;
               p)
                   project_name=$OPTARG
                   ;;
               g)
                   google_group_name=$OPTARG
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

       # Set gcp_project_id and google_group-name, if necessary.
        if [ $gcp_project_id ] 
        then
                :  # Do nothing.
                
        elif [ $pi_tag ]
        then
                gcp_project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_LAB-$pi_tag"
                gcp_project_name="GBSC Lab - $pi_tag"
		[[ "$google_group_name" == "" ]] && google_group_name="$LAB_GROUP_PREFIX-$pi_tag-gcp@stanford.edu"

        elif [ $project_name ]
        then
	        project_name_lower=`echo $project_name | tr '[:upper:]' '[:lower:]'`
                gcp_project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_PROJ-$project_name_lower"
                gcp_project_name="GBSC Project - $project_name"
		[[ "$google_group_name" == "" ]] && google_group_name="$PROJ_GROUP_PREFIX-$project_name_lower-gcp@stanford.edu"

	elif [ $class_name ]
	then
	        class_name_lower=`echo $class_name | tr '[:upper:]' '[:lower:]'`
	        gcp_project_id="$PROJECT_PREFIX-$PROJECT_PREFIX_CLASS-$class_name_lower"
		gcp_project_name="GBSC Class - $class_name"
                [[ "$google_group_name" == "" ]] && google_group_name="$CLASS_GROUP_PREFIX-$class_name-gcp@stanford.edu"
        else
                echo "Need one of -l LAB-NAME, -p PROJ-NAME, or -c CLASS-NAME...exiting."
                exit -1
        fi
        
        return $((OPTIND-1))

}

export GCP_GBSC_FOLDER_ID=375758629844
export GCP_ORGANIZATION_ID=302681460499

# Arguments:
#  1st: project ID
#  2nd: project Name
create_project() {

    local id=$1
    local name=$2
    local billing_account=$3

    # Create the project
    echo "Creating project $id named $name"
    $DEBUG gcloud projects create $id --folder=$GCP_GBSC_FOLDER_ID "--name=$name"
    $DEBUG gcloud projects list --filter="project_id=$id"

    # Adding billing account.
    echo "Adding billing account $billing_account"
    $DEBUG gcloud beta billing projects link $id --billing-account $billing_account
}

# Arguments:                                                                          
#  1st: project ID
add_apis() {

    local gcp_project_id=$1

    ###
    # Add the Compute Engine API
    ###
    echo "Adding the Compute Engine API to $gcp_project_id"
    $DEBUG gcloud services enable compute.googleapis.com --project=$gcp_project_id

    # Set the firewall rules for Compute Engine
    echo "  Setting the firewall rules"
    set_firewall_rules $gcp_project_id

    # Set the Compute Engine Usage Log export.
    echo "  Set the Compute Engine Usage Log export"
    set_compute_logging $gcp_project_id

    # Set up Cloud Logging via fluentid
    echo "  Set up Cloud Logging via fluentid"
    set_compute_cloud_logging $gcp_project_id

    echo 

    ###
    # Add the Genomics API
    ###
    echo "Adding the Genomics API to $gcp_project_id"
    $DEBUG gcloud services enable genomics.googleapis.com --project=$gcp_project_id

    echo
}

# Arguments:
#  1st: project ID
#  2nd: bucket name (optional)
create_group_bucket() {

    local gcp_project_id=$1
    local group_bucket=$2

    if [ "T$group_bucket" == "T" ]
	then
	group_bucket="$gcp_project_id""_""$BUCKET_SUFFIX_GROUP"
    fi

    echo "*********************"
    echo "CREATING GROUP BUCKET: $group_bucket"
    echo "*********************"
        
    # Create the group bucket.
    echo "===> Creating the $group_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $gcp_project_id gs://$group_bucket
    echo 
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $gcp_project_id $group_bucket
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
#  2nd: bucket name (optional)
create_public_bucket() {

    local gcp_project_id=$1
    local public_bucket=$2

    if [ "T$public_bucket" == "T" ]
	then
	public_bucket="$gcp_project_id""_""$BUCKET_SUFFIX_PUBLIC"
    fi

    echo "**********************"
    echo "CREATING PUBLIC BUCKET: $public_bucket"
    echo "**********************"
       
    # Create the public bucket.
    echo "===> Creating the $public_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $gcp_project_id gs://$public_bucket
    echo
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $gcp_project_id $public_bucket
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
    
    local gcp_project_id=$1
    local sunet_id=$2

    local user_bucket="$gcp_project_id""_""$BUCKET_SUFFIX_USER-$sunet_id"
        
    echo "********************"
    echo "CREATING USER BUCKET: $user_bucket"
    echo "********************"
        
    # Create the public bucket.
    echo "===> Creating the $user_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $gcp_project_id gs://$user_bucket
    echo
        
    # Set logging of access to bucket to GBSC Billing bucket.
    set_storage_logging $gcp_project_id $user_bucket
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
    
    local gcp_project_id=$1

    local logs_bucket="$gcp_project_id""_""$BUCKET_SUFFIX_LOGS"
        
    echo "********************"
    echo "CREATING LOGS BUCKET: $logs_bucket"
    echo "********************"
        
    # Create the public bucket.
    echo "===> Creating the $logs_bucket bucket in $STORAGE_REGION region with $STORAGE_CLASS class"
    $DEBUG gsutil mb -c $STORAGE_CLASS -l $STORAGE_REGION -p $gcp_project_id gs://$logs_bucket
    echo

    # Set logging of access to bucket to GBSC Billing bucket.
    echo "===> Setting logging of $logs_bucket to $GBSC_LOGS_BUCKET"
    set_storage_logging $gcp_project_id $logs_bucket
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

    local gcp_project_id=$1

    ###
    # All modifications are to the 'default' network.
    ###

    #
    # Delete the 'default-allow-rdp' firewall rule.
    #
    echo "      Deleting the 'default-allow-rdp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $gcp_project_id --quiet delete default-allow-rdp
    echo

    #
    # Delete the 'default-allow-ssh' firewall rule.
    #
    echo "      Deleting the 'default-allow-ssh' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $gcp_project_id --quiet delete default-allow-ssh
    echo
        
    #
    # Delete the 'default-allow-icmp' firewall rule.
    #
    echo "      Deleting the 'default-allow-icmp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $gcp_project_id --quiet delete default-allow-icmp
    echo

    #
    # Add the 'default-allow-stanford-ssh' firewall rule.
    #
    echo "      Adding the 'default-allow-stanford-ssh' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $gcp_project_id --quiet create default-allow-stanford-ssh --allow tcp:22 --source-ranges 171.64.0.0/14 --description 'Allow SSH connections from Stanford addresses' 
    echo
        
    #
    # Add the 'default-allow-stanford-icmp' firewall rule.
    #
    echo "      Adding the 'default-allow-stanford-icmp' firewall rule."
    $DEBUG gcloud compute firewall-rules --project $gcp_project_id --quiet create default-allow-stanford-icmp --allow icmp --source-ranges 171.64.0.0/14 --description 'Allow ICMP traffic from Stanford addresses' 
    echo

}

#
# set_compute_logging: Sets up compute engine usage logging on given project.
#
# Arguments:
#  1st: Project ID
#
set_compute_logging() {

    local gcp_project_id=$1
        
    echo "==> Setting Compute Engine logging to $GBSC_LOGS_BUCKET for $gcp_project_id."
    $DEBUG gcloud compute project-info set-usage-bucket --project $gcp_project_id --bucket=gs://$GBSC_LOGS_BUCKET --prefix=$COMPUTE_LOGGING_PREFIX/$gcp_project_id/$gcp_project_id
        
}

#
# set_storage_logging: Sets up storage usage logging on given bucket/project.
#
# Arguments:
#  1st: Project ID
#  2nd: Bucket
#
set_storage_logging() {

    local gcp_project_id=$1
    local bucket=$2

    echo "==> Setting Storage logging to $GBSC_LOGS_BUCKET for bucket $bucket in $gcp_project_id."
    $DEBUG gsutil logging set on -b gs://$GBSC_LOGS_BUCKET -o $STORAGE_LOGGING_PREFIX/$gcp_project_id/$bucket/$bucket gs://$bucket

}

#
# set_compute_logging: Sets up compute engine usage logging on given project.
#
# Arguments:
#  1st: Project ID  
#
set_compute_cloud_logging() {

    local gcp_project_id=$1

    echo "Setting Compute Engine Cloud logging startup-script-url for $gcp_project_id."
    $DEBUG gcloud compute project-info add-metadata --project $gcp_project_id --metadata startup-script-url=https://dl.google.com/cloudagents/install-logging-agent.sh

}
