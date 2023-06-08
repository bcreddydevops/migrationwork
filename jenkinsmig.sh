#!/bin/bash -e

echo " Execute the script in gen6 bastion"
echo " Make sure that the ssh connection is established between gen6 and gen7 bastion"
echo " This script copies the jenkins files from gen6 and gen7 server"

read -p "Enter the gen7 bastion public IP : " gen7ip
read -p "Enter the gen7 jenkins pod name : " jenkinsname
read -p "Enter FULL - Complete jobs migration,  SINGLE - Specific job migration" : pipeline
jenkins6pod=$(kubectl get pods -n ethan --field-selector=status.phase=Running -1 app=jenkins-blueocean | grep -v NAME | cut -d ' ' -f1)
mkdir -p migration/jobs
rm -rf migration/executegen.sh migration/jenkinspodname migration/d_name migration/jobs/*
echo $jenkinsname > ~/migration/jenkinspodname

if [[ "${pipeline}" == "FULL" ]]; then
	echo "Below jenkins Jobs will be migrated from gen6"
	echo "--------------------------------------------"
	kubectl exec $nexus6pod -- ls /var/jenknis_hime/jobs/ | aws '{print $1}'
	echo "COMPLETE" > ~/migration/d_name
	chmod 755 ~/migration/jobs
		
elif [[ "${pipeline}" == "SINGLE" ]];
	echo "The list of Jenkins Jobs available from gen6"
	echo "--------------------------------------------"
	kubectl exec $nexus6pod -- ls /var/jenknis_hime/jobs/ | aws '{print $1}'
	read -p "Select the pipeline to proceed for backup : " directory
	echo "${directory}" > ~/migration/d_name
	mkdir ~/migration/jobs/$directory
	chmod 755 ~/migration/jobs/$directory
fi

#cd $HOME

jobName=$(cat ~/migration/d_name)
if [[ "${jobName}" == "COMPLETE" ]]; then
	### Copying the jenkins file from pod to bastion home path ###
	kubectl cp $jenkins6pod:/var/jenkins_home/jobs/* ~/migration/jobs/*
	###  copying the jenkinsfile from gen6 to gen7 bastion ####
	scp -r ~/migration/jobs/* ubuntu@$gen7ip:/home/ubuntu/migration/jobs/ ---  you can replace a rsync command
else 
	### Copying the jenkins file from pod to bastion home path ###
	kubectl cp $jenkins6pod:/var/jenkins_home/jobs/$jobName ~/migration/jobs/${jobName}
	###  copying the jenkinsfile from gen6 to gen7 bastion ####
	scp -r ~/migration/jobs/${jobName} ubuntu@$gen7ip:/home/ubuntu/migration/jobs/${jobName}
fi	

echo "file transfer successfully"

echo "creating the executegen7.sh file"
cat << EOF >> ~/executegen7.sh
    cd $HOME
	mkdir -p migration/jobs
	jobName=$(cat ~/migration/d_name)
	podName=$(cat ~/jenkinspodname)
	if [[ "${jobName}" == "COMPLETE" ]]; then
		kubectl cp migration/jobs/*	${podName}:/var/jenkins_home/jobs/
	else 
		kubectl cp migration/jobs/$jobName ${podName}:/var/jenkins_home/jobs/
	fi	
EOF

echo "providing the permission for nexusgen7.sh file"
chmod 755 ~/migration/executegen7.sh

scp -r ~/migration/executegen7.sh ubuntu@$gen7ip:/home/ubuntu/migration
ssh -t ubuntu@$gen7ip "sh ~/migration/executegen7.sh"
ssh -t ubuntu@$gen7ip "rm -rf migration/executegen7.sh migration/jobs/*"
echo "The script has been executed successfully"
