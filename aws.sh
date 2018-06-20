#!/bin/bash
HOSTS=("aaa.aws.tom.ru bbb.aws.tom.ru ccc.aws.tom.ru")
currentdata=$(date +%Y-%m-%d)
#1 Determine the instance state using its DNS name (need at least 2 verifications: TCP and HTTP)
    for myHost in ${HOSTS[@]}
    do
        nc -z -v -w1 -z $myHost 80  > /dev/null 2>&1;
        data=$?

    if [[ "$data" -eq 1 ]] ; then
        echo -ne  "\x1b[33mHost $myHost is inactive (checked 80 port, is closed)\x1b[0m"
        echo
    elif [[ "$data" -eq 0 ]] ; then
        echo "Host $myHost is active (checked 80 port, is open)"
    fi

    status_code=$(curl --write-out %{http_code} --silent --max-time 2 --output /dev/null $myHost)

    if [[ "$status_code" -eq 200 ]] ; then
        echo "Site availible by status code $status_code (checked HTTP response)"
        echo
    elif [[ "$status_code" -eq 000 ]] ; then
        echo -ne  "\x1b[33mSite $myHost unavalible at $currentdata by status code $status_code \x1b[0m"
        echo
    else
        echo "Site $myHost avalible by status code $status_code (checked HTTP response)"
        echo
    fi

    done

#2 Create an AMI of the stopped EC2 instance and add a descriptive tag based on the EC2 name along with the current date.
    NAME=Konstantin/Vish-c-$currentdata
    echo
    echo Creating an AMI of the instance i-067d60553f788d54c
    echo
    aws ec2 create-image --instance-id i-067d60553f788d54c --name "$NAME" --description "An AMI from Konstantin/Vish-c"

#3 Terminate stopped EC2 after AMI creation.
    echo Terminate stopped EC2 i-067d60553f788d54c
    read -p "Are you sure want to terminate i-067d60553f788d54c? (Y/n) " -n 1 -r
        echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "you say YES"
        echo Terminating
        aws ec2 terminate-instances --instance-ids i-067d60553f788d54c
        echo Terminating is finished
    else
        echo "you say NO"
    fi

#4 Clean up AMIs older than 7 days.
    echo -ne "AMIs older than 7 days, \x1b[31m!!!please check it twise before deleting!!!:\x1b[0m"
    echo
    aws ec2 describe-images --owners 717986625066 --query 'Images[*].[CreationDate,ImageId]' | sort| awk -vDate=$(date -d'now-7 days' +%Y-%m-%dT%H:%M:%S.000Z) ' { if ($1 < Date) print $1, $2}'
    oldAMIs=(`aws ec2 describe-images --owners 717986625066 --query 'Images[*].[CreationDate,ImageId]' | sort| awk -vDate=$(date -d'now-7 days' +%Y-%m-%dT%H:%M:%S.000Z) ' { if ($1 < Date) print $2}'`)

    read -p "Are you sure want to delete selected AMI's? (Y/n) " -n 1 -r
        echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "you say YES"
    for AMIS in ${oldAMIs[@]}
    do
        echo Deleting selected $AMIS
        aws ec2 deregister-image --image-id $AMIS
        echo Deleting is finished
    done
    else
        echo "you say NO"
    fi

#5 Print all instances in fine-grained output, INCLUDING terminated one, with highlighting their current state.
state=(`aws ec2 describe-instances --filters "Name=instance.group-name, Values=KonstantinVish" --query Reservations[].Instances[].[State] | cut -f2`)
name=(`aws ec2 describe-instances --filters "Name=instance.group-name, Values=KonstantinVish" --query Reservations[].Instances[].Tags | cut -f2 | sort`)
publicIP=(`aws ec2 describe-instances --filters "Name=instance.group-name, Values=KonstantinVish" --query Reservations[].Instances[].PublicIpAddress`)

    for((i=0; i < 3; i++))
    do
        if [[ !${state[i]} =~ [running] ]]; then
        echo -ne "\x1b[32mMachine Name:${name[i]} State:${state[i]} PublicIP:${publicIP[i]}\x1b[0m"
        echo
        else
        echo -ne "\x1b[31mMachine Name:${name[i]} State:${state[i]} PublicIP:${publicIP[i]}\x1b[0m"
        echo
        fi
    done
