#!/bin/bash

echo " Execute the script in gen6 bastion"
echo "make sure that the ssh connection is established between gen6 and gen7 bastion"
echo "this script copies the nexus data from gen6 and gen7 server"

read -p "Enter the gen7 bastion public IP : " gen7ip
read -p "Enter the gen7 nexus pod name : " nexus7pod
echho "$nexus7pod" > ~/nexus7podname
nexus6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -1 app=nexus | grep -v NAME | cut -d ' ' -f1)

echo "The list of Nexus folders available from gen6"
echo "---------------------------------------------"
kubectl exec $nexus6pod -- ls /opt/sonatype/sonatype-work/nexus3/ | aws '{print $1}'

echo "creating the nexus_backup folder in nexus gen6"
kubectl exec -it $nexus6pod -- /bin/bash -c "rm -rf /tmp/nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "mkdir /tmp/nexus6_backup"

echo "copying blobs component config into nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/blobs /tmp/nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/db/component /tmp/nexus6_backup"
kubectl exec -it $nexus6pod -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/db/config /tmp/nexus6_backup"

echo "creating a tar file or nexus6_backup"
kubectl exec -it $nexus6_backup -- /bin/bash -c "tar -cvf /tmp/nexus6_backup.tar /tmp/nexus6_backup"

echo "Display the checksum value of nexus6_backup.tar"
nexus6cksum=$(kubectl exec -it $nexus6_backup -- /bin/bash -c "cksum /tmp/nexus6_backup.tar")

echo "Copying the nexus6_backup.tar file to gen6 file to gen6 bastion"
kubectl cp $nexus6pod:/tmp/nexus6_backup.tar ~/nexus6_backup.tar/

echo "copying the nexus6_backup.tar from gen6 to gen7 bastion"
scp -r nexus6_backup.tar/ ubuntu@$gen7ip:/home/ubuntu/

echo "nexus6_backup.tar copied to gen7 bastion successfully"

echo "creating the nexusgen7.sh file"
cat << EOF >> ~/nexusgen7.sh
    cd $HOME
	   echo "creating the nexus7_backup folder in nexus gen7"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf /opt/sonatype/sonatype-work/nexus3/nexus7_backup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "mkdir /opt/sonatype/sonatype-work/nexus3/nexus7_backup"
	   
	   echo "taking backup of blobs component config into nexus7_backup"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/blobs opt/sonatype/sonatype-work/nexus3/nexus7_backup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/db/component  	opt/sonatype/sonatype-work/nexus3/nexus7_backup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/db/config opt/sonatype/sonatype-work/nexus3/nexus7_backup"
	   
	   echo "remove blobs component config in nexus"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf /opt/sonatype/sonatype-work/nexus3/blobs"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf /opt/sonatype/sonatype-work/nexus3/db/component"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "rm -rf /opt/sonatype/sonatype-work/nexus3/db/config"
	   
	   echo "installing the tar and hostname"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "yum install tar -y"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "yum install hostname -y"
	   
	   echo "copy the the nexus6_backup.tar bastion to pod"
	   
	   kubectl cp nexus6_backup.tar/ `cat ~/nexus7podname`:/opt/sonatype/sonatype-work/nexus3/
	   
	   echo "Display the checksum value of nexus6_backup.tar"
	   nexus7cksum=$(kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cksum /opt/sonatype/sonatype-work/nexus3/nexus6_backup.tar")
	   
	   if [ "nexus6cksum" = "nexus7cksum"]; then
	   
	   echo "extacting the tar file"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus /opt/sonatype/sonatype-work/nexus3/nexus6_backup.tar"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cd /opt/sonatype/sonatype-work/nexus3/ && tar -xvf nexus6_backup.tar"
	   
	   echo "providing the permission forbackup"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus tmp/nexus6_backup/"
	   
	   echo "copying nexus6_backup dat into blobs component config folders"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/tmp/nexus6_backup/blobs /opt/sonatype/sonatype-work/nexus3/blobs"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/tmp/nexus6_backup/component /opt/sonatype/sonatype-work/nexus3/db/component"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "cp -r /opt/sonatype/sonatype-work/nexus3/tmp/nexus6_backup/config /opt/sonatype/sonatype-work/nexus3/db/config"
	   
	   echo "changing the permission fpr blobs component config folders"
	   
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus /opt/sonatype/sonatype-work/nexus3/blobs/"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus /opt/sonatype/sonatype-work/nexus3/db/component/"
	   kubectl exec -it `cat ~/nexus7podname` -- /bin/bash -c "chown -R root:nexus /opt/sonatype/sonatype-work/nexus3/db/config/"

EOF

echo "providing the permission for nexusgen7.sh file"
chmod 755 ~/nexusgen7.sh

scp -r ~/nexusgen7.sh ubuntu@$gen7ip:/home/ubuntu/
ssh -t ubuntu@$gen7ip "sh ~/nexusgen7.sh"
ssh -t ubuntu@$gen7ip "rm -f nexusgen7.sh nexus6_backup.tar"
rm -r nexus6_backup.tar nexus7podname nexusgen7.sh
echo "The script has been executed successfully"

else

echo "cksum value is not matched existing the script"
exit 1

fi





