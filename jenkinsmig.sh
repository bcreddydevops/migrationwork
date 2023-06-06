#!/bin/bash

echo " Execute the script in gen6 bastion"
echo "make sure that the ssh connection is established between gen6 and gen7 bastion"
echo "this script copies the jenkins files from gen6 and gen7 server"

read -p "Enter the gen7 bastion public IP : " gen7ip
read -p "Enter the gen7 jenkins pod name : " jenkinsname
jenkins6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -1 app=jenkins-blueocean | grep -v NAME | cut -d ' ' -f1)
echo "The list of Jenkins Jobs available from gen6"
echo "--------------------------------------------"
kubectl exec $nexus6pod -- ls /var/jenknis_hime/jobs/ | aws '{print $1}'

read -p "Enter the to be taken as backup : " directory

rm -rf jenkinspodname d_name executegen.sh $directory

echo $directory > ~/d_name
echo $jenkinsname > ~/jenkinspodname

### Copying the jenkins file from pod to bastion home path ###

cd $HOME
rm -rf $directory
mkdir $directory
chmod 755 $directory

kubectl cp $jenkins6pod:/var/jenkins_home/jobs/$directory ~/$directory/

###  copying the jenkinsfile from gen6 to gen7 bastion ####

scp -r $directory/ ubuntu@$gen7ip:/home/ubuntu/

echo "file transfer successfully"

echo "creating the executegen7.sh file"
cat << EOF >> ~/executegen7.sh
    cd $HOME
	directory=`cat ~/d_name`
	kubectl cp $directory/ 	`cat ~/jenkinspodname`:/var/jenkins_home/jobs/

EOF

echo "providing the permission for nexusgen7.sh file"
chmod 755 ~/executegen7.sh

scp -r ~/executegen7.sh ubuntu@$gen7ip:/home/ubuntu/
ssh -t ubuntu@$gen7ip "sh ~/executegen7.sh"
ssh -t ubuntu@$gen7ip "rm -f executegen7.sh $directory"
rm -r d_name executegen7.sh jenkinspodname
echo "The script has been executed successfully"




