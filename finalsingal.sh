#!/bin/bash
#
##########################################################################################
# Title: jenkinsmigration.sh
# Author: Chinna Reddaiah Bommayyagari
# Date: July 11, 2023
#
# Purpose:
#   This script facilitates the migration of Jenkins Jobs from one cluster to another.
#   It automates the process of cloning the selected job from the source and copying it to the destination server.
#
# Usage:
#   ./jenkinsmigration.sh [options]
#    OR
#   By entering input "3" after executing ./Gen6toGen8migration.sh
#
# Notes:
#   - It is recommended to test the script on a non-production repository before performing the actual migration.
#
###########################################################################################

echo "Execute the script in Gen6 Bastion"
echo "Make sure that the SSH connection is established between gen6 and gen8 bastion"
echo "This script copies the Jenkins file from gen6 to gen8 server"

# Set the necessary environment variables
read -p "Enter the gen6 Bastion public IP: " gen6ip
read -p "Enter the gen8 Bastion public IP: " gen8ip

jenkins8pod=$(ssh ubuntu@$gen8ip "kubectl get pods -n ethan --field-selector=status.phase=Running -l app=jenkins | grep -v NAME | cut -d ' ' -f1")
jenkins6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -l app=jenkins-blueocean | grep -v NAME | cut -d ' ' -f1)

echo "The list of Jenkins jobs available from gen6"
echo "--------------------------------------------"
kubectl exec $jenkins6pod -- ls /var/jenkins_home/jobs/ | awk '{print $1}'
read -p "Enter the job to be taken as a backup: " jenkinsjob

# Copying the job from pod to bastion
kubectl exec -it $jenkins6pod -- /bin/bash -c "cp -r /var/jenkins_home/jobs/$jenkinsjob /tmp"

echo "Creating the tar file of $jenkinsjob"
kubectl exec -it $jenkins6pod -- /bin/bash -c "tar -cvf /tmp/$jenkinsjob.tar /tmp/$jenkinsjob"

echo "Display the checksum value of $jenkinsjob"
jenkins6cksum=$(kubectl exec -it $jenkins6pod -- /bin/bash -c "cksum /tmp/$jenkinsjob.tar" | awk '{print $2}')

echo "Copying the jenkins6cksum value to gen8"
echo $jenkins6cksum > ~/jenkins6cksum
dos2unix ~/jenkins6cksum
chmod 775 ~/jenkins6cksum
scp -r ~/jenkins6cksum ubuntu@$gen8ip:/home/ubuntu/

echo "Copying the tar file from pod to bastion"
kubectl cp $jenkins6pod:/tmp/$jenkinsjob.tar ~/$jenkinsjob.tar/

echo "Checking the checksum values in bastion"
cksum ~/$jenkinsjob.tar | awk '{print $2}' >> ~/jenkins6cksumin

if [ "$(cat ~/jenkins6cksum)" = "$(cat ~/jenkins6cksumin)" ]; then
    echo "The contents of jenkins6cksum and jenkins6cksumin are equal"
else
    echo "Checksum value is not matched, exiting the script"
    exit 1
fi

#### Copying the jenkins file from Gen6 to gen8 bastion ####

scp -r $jenkinsjob.tar/ ubuntu@$gen8ip:/home/ubuntu/

echo "File transfer successful from source to destination"

echo "Dynamically creating the script to execute the destination"

cat << EOF >> ~/executegen8jenkins.sh
#!/bin/bash
file1="$(cat ~/jenkins6cksum)"
file2="$(cat ~/jenkins8cksum)"

echo "Copy the $jenkinsjob.tar bastion to pod"
echo "$jenkinsjob"
kubectl cp $jenkinsjob.tar/ $jenkins8pod:/tmp

echo "Display the checksum value of $jenkinsjob.tar"
kubectl exec -it $jenkins8pod -- /bin/bash -c "cksum /tmp/$jenkinsjob.tar" | cut -d " " -f2 | tr -d \r > ~/jenkins8cksum
dos2unix ~/jenkins8cksum
chmod 775 ~/jenkins8cksum
scp -r ~/jenkins8cksum ubuntu@$gen6ip:/home/ubuntu/

echo "Checking the checksum values to see if they are equal"
if [ "$file1" = "$file2" ]; then
    echo "The contents of jenkins6cksum and jenkins8cksum are equal"

    echo "Extracting the tar file"
    kubectl exec -it $jenkins8pod -- /bin/bash -c "cd /tmp && tar -xvf /tmp/$jenkinsjob.tar"
    echo "Copying $jenkinsjob to jobs folder"
    kubectl exec -it $jenkins8pod -- /bin/bash -c "cp -r /tmp/tmp/$jenkinsjob /var/jenkins_home/jobs/"
else
    echo "Checksum value is not matched, exiting the script"
    exit 1
fi
EOF

chmod 775 ~/executegen8jenkins.sh
scp -r ~/executegen8jenkins.sh ubuntu@$gen8ip:/home/ubuntu/
echo "Validating the script"
ssh -t ubuntu@$gen8ip -- sh ~/executegen8jenkins.sh

echo "The script has been executed successfully"
