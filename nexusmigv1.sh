#!/bin/bash

echo -e " Execute the script in gen6 bastion\nensure ssh connection is established between gen6 and gen7 bastion\nThis script copies the nexus data from gen6 and gen7 server"

nexus3Config="/opt/sonatype/sonatype-work/nexus3"

read -p "Enter the gen7 bastion public IP : " gen7ip
read -p "Enter the gen7 nexus pod name : " nexus7pod

echo "$nexus7pod" > ~/nexus7podname
nexus6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -1 app=nexus | grep -v NAME | cut -d ' ' -f1)

echo "The list of Nexus folders available from gen6"
echo "---------------------------------------------"
kubectl exec $nexus6pod -- ls /opt/sonatype/sonatype-work/nexus3/ | aws '{print $1}'

echo "Creating the nexus_backup folder in nexus gen6"
kubectl exec -it $nexus6pod -- /bin/bash -c "rm -rf /tmp/nexus6_backup && mkdir /tmp/nexus6_backup"
#kubectl exec -it $nexus6pod -- /bin/bash -c "mkdir /tmp/nexus6_backup"

echo "Copying blobs component config into nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r ${nexus3Config}/blobs /tmp/nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r ${nexus3Config}/db/component /tmp/nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r ${nexus3Config}/db/config /tmp/nexus6_backup"

echo "Creating a tar file or nexus6_backup"
kubectl exec -it $nexus6_backup -- /bin/bash -c "tar -cvf /tmp/nexus6_backup.tar /tmp/nexus6_backup"

echo "Display the checksum value of nexus6_backup.tar"
checkSumNexus6Bkp=$(kubectl exec -it $nexus6_backup -- /bin/bash -c "cksum /tmp/nexus6_backup.tar")
echo " Checksum for /tmp/nexus6_backup.tar - ${checkSum}"
export checkSumNexus6Bkp

echo " Copying the nexus6_backup.tar file to gen6 file to gen6 bastion"
kubectl cp $nexus6pod:/tmp/nexus6_backup.tar ~/nexus6_backup.tar/

echo "Copying the nexus6_backup.tar from gen6 to gen7 bastion"
scp -r nexus6_backup.tar/ ubuntu@$gen7ip:/home/ubuntu/

echo "nexus6_backup.tar copied to gen7 bastion successfully"

echo "Creating the nexusgen7.sh file"
cat << EOF >> ~/nexusgen7.sh
    cd $HOME
		set -o pipefail -e
	
		error_exit()
		{
			echo 1>&2 "Error: $1"
			exit 1
		}
		
		validateParamter() {
			[[ -z $1 ]] && error_exit "The string is empty" || echo "String is not empty"
		fi
		
	   echo "Creating the nexus7_backup folder in nexus gen7"
	   nexus3Config="/opt/sonatype/sonatype-work/nexus3"
	   chkSumNexs6Bkp="${checkSumNexus6Bkp}"
	   
	   # Validate the environment variables
	   validateParamter chkSumNexs6Bkp
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf ${nexus3Config}/nexus7_backup && mkdir ${nexus3Config}/nexus7_backup"
	   #kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "mkdir ${nexus3Config}/nexus7_backup"
	   
	   echo "Taking backup of blobs component config into nexus7_backup"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/blobs ${nexus3Config}/nexus7_backup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/db/component ${nexus3Config}/nexus7_backup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/db/config ${nexus3Config}/nexus7_backup"
	   
	   echo "Remove blobs component config in nexus"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf ${nexus3Config}/blobs ${nexus3Config}/db/component ${nexus3Config}/db/config"
	   #kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf ${nexus3Config}/db/component"
	   #kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf ${nexus3Config}/db/config"
	   
	   echo "Installing the tar and hostname"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "yum install tar -y"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "yum install hostname -y"
	   
	   echo "Copy the the nexus6_backup.tar bastion to pod"
	   
	   kubectl cp nexus6_backup.tar/ `cat ~/nexus7podname`:${nexus3Config}/
	   
	   echo "Display the checksum value of nexus6_backup.tar"
	   checkSumNexus6FromBkp=$(kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cksum ${nexus3Config}/nexus6_backup.tar")
	   # Validate the checksum
	   [[ "${checkSumNexus6FromBkp}" == "${chkSumNexs6Bkp}" ]] && echo "Checksum matched" || error_exit "Checksum validation failed"
	   
	   echo "Extracting the tar file"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus ${nexus3Config}/nexus6_backup.tar"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cd ${nexus3Config}/ && tar -xvf nexus6_backup.tar"
	   
	   echo "Providing the permission forbackup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus tmp/nexus6_backup/"
	   
	   echo "copying nexus6_backup dat into blobs component config folders"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/tmp/nexus6_backup/blobs ${nexus3Config}/blobs"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/tmp/nexus6_backup/component ${nexus3Config}/db/component"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r ${nexus3Config}/tmp/nexus6_backup/config ${nexus3Config}/db/config"
	   
	   echo "changing the permission fpr blobs component config folders"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus ${nexus3Config}/blobs/"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus ${nexus3Config}/db/component/"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus ${nexus3Config}/db/config/"
EOF

echo "Providing the permission for nexusgen7.sh file"
chmod +x ~/nexusgen7.sh

scp -r ~/nexusgen7.sh ubuntu@$gen7ip:/home/ubuntu/
ssh -t ubuntu@$gen7ip "sh ~/nexusgen7.sh"
ssh -t ubuntu@$gen7ip "rm -f nexusgen7.sh nexus6_backup.tar"


rm -r nexus6_backup.tar nexus7podname nexusgen7.sh
echo "The script has been executed successfully"
