#!/bin/bash
#
##########################################################################################
# Title: jenkinsmigrationfull.sh
# Author: Chinna Reddaiah Bommayyagari
# Date: July 12, 2023
#
# Purpose:
#   This script facilitates the migration of nexus artifacts from one cluster to another.
#   It automates the process of cloning the artifacts from the source and copying them to the destination server.
#
# Usage:
#   ./jenkinsmigrationfull.sh [options]
#    OR
#   By entering input "4" after executing ./Gen6toGen8migration.sh
#
# Notes:
#   - It is recommended to test the script on a non-production repository before performing the actual migration.
#
###########################################################################################

echo "Execute the script in Gen6 Bastion"
echo "Make sure that the SSH connection is established between gen6 and gen8 bastion"
echo "This script copies the Jenkins jobs from gen6 to gen8 server"

read -p "Enter the gen6 Bastion public IP: " gen6ip
read -p "Enter the gen8 Bastion public IP: " gen8ip

jenkins8pod=$(ssh ubuntu@$gen8ip "kubectl get pods -n ethan --field-selector=status.phase=Running -l app=jenkins | grep -v NAME | cut -d ' ' -f1")
jenkins6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -l app=jenkins-blueocean | grep -v NAME | cut -d ' ' -f1)

jenkinsjobs=/var/jenkins_home

echo "The list of Jenkins folders available from gen6"
echo "--------------------------------------------"
kubectl exec $jenkins6pod -- ls /var/jenkins_home/jobs/ | awk '{print $1}'

echo "Creating the jenkins6_backup folder in Jenkins gen6"
kubectl exec -it $jenkins6pod -- /bin/bash -c "mkdir /tmp/jenkins6_backup"

echo "Copying the Jenkins jobs into jenkins6_backup"
kubectl exec -it $jenkins6pod -- /bin/bash -c "cp -r $jenkinsjobs/jobs /tmp/jenkins6_backup"

echo "Create a tar file of jenkins6_backup"
kubectl exec -it $jenkins6pod -- /bin/bash -c "tar -cvf /tmp/jenkins6_backup.tar /tmp/jenkins6_backup"

echo "Display the checksum value of jenkins6_backup.tar"
jenkins6cksum=$(kubectl exec -it $jenkins6pod -- /bin/bash -c "cksum /tmp/jenkins6_backup.tar" | awk '{print $2}')
echo $jenkins6cksum > ~/jenkins6cksum
dos2unix ~/jenkins6cksum
chmod 775 ~/jenkins6cksum
scp -r ~/jenkins6cksum ubuntu@$gen8ip:/home/ubuntu/

#echo "Splitting the tar into multiple files"
kubectl exec -it $jenkins6pod -- /bin/bash -c "split -b 1G /tmp/jenkins6_backup.tar /tmp/output_prefix"

echo "Copying the output_prefix files into bastion"
files=$(kubectl exec -it $jenkins6pod -- /bin/bash -c "cd /tmp && ls output_prefix*")
for file in $files
do
  clean_file=$(echo "$file" | tr -d '\r')  # Remove any special characters or whitespace from the file name
  kubectl cp $jenkins6pod:/tmp/$clean_file ~/$clean_file/
done

echo "Generating the tar file with output prefix files"
cat output_prefix* > jenkins6_backup.tar

echo "Checking the checksum values in bastion"
cksum jenkins6_backup.tar | awk '{print $2}' >> ~/jenkins6cksumin

if [ "$(cat ~/jenkins6cksum)" = "$(cat ~/jenkins6cksumin)" ]; then
  echo "The contents of jenkins6cksum and jenkins6cksumin are equal"
else
  echo "Checksum value is not matched. Exiting the script"
  exit 1
fi

echo "Copying the jenkins6_backup.tar from Gen6 to Gen8 bastion"
scp -r jenkins6_backup.tar/ ubuntu@$gen8ip:/home/ubuntu/
echo "File transfer successful from source to destination"

echo "Dynamically creating the script to execute the destination"

cat << EOF >> ~/jenkinsgen8.sh
#!/bin/bash
jenkinsjobs=/var/jenkins_home
file1="$(cat ~/jenkins6cksum)"
file2="$(cat ~/jenkins8cksum)"

echo "Copy the jenkins6_backup.tar bastion to pod"
kubectl cp jenkins6_backup.tar/ $jenkins8pod:/tmp

echo "Display the checksum value of jenkins6_backup.tar"
kubectl exec -it $jenkins8pod -- /bin/bash -c "cksum /tmp/jenkins6_backup.tar" | cut -d " " -f2 | tr -d \r > ~/jenkins8cksum
echo $jenkins8cksum >> ~/jenkins8cksum
dos2unix ~/jenkins8cksum
chmod 775 ~/jenkins8cksum
scp -r ~/jenkins8cksum ubuntu@$gen6ip:/home/ubuntu/

echo "Checking both files having the same data or not"
if [ "$file1" = "$file2" ]; then
  echo "The contents of jenkins6cksum and jenkins8cksum are equal"

  echo "Creating the jenkins8_backup folder in Jenkins gen8"
  kubectl exec -it $jenkins8pod -- /bin/bash -c "mkdir $jenkinsjobs/jenkins8_backup"

  echo "Taking a backup of blobs component config into jenkins8_backup"
  kubectl exec -it $jenkins8pod -- /bin/bash -c "cp -r $jenkinsjobs/jobs/* $jenkinsjobs/jenkins8_backup/"

  echo "Extracting the tar file"
  kubectl exec -it $jenkins8pod -- /bin/bash -c "cd /tmp && tar -xvf jenkins6_backup.tar"

  echo "Copying jenkins6_backup jobs into the destination jobs"
  kubectl exec -it $jenkins8pod -- /bin/bash -c "cp -nr /tmp/tmp/jenkins6_backup/jobs/* $jenkinsjobs/jobs/"
else
  echo "Checksum value is not matched. Exiting the script"
  exit 1
fi
EOF

echo "Providing permission for jenkinsgen8.sh file"
chmod 775 ~/jenkinsgen8.sh

scp -r ~/jenkinsgen8.sh ubuntu@$gen8ip:/home/ubuntu/
echo "Validating the script"
ssh -t ubuntu@$gen8ip "sh ~/jenkinsgen8.sh"

echo "The script has been executed successfully"
