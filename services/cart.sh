#!/bin/bash
component=$1
env=$2
dnf install ansible -y

REPO_URL=https://github.com/sindhumgithub/ansible-roboshop-roles-tf.git
REPO_DIR=/opt/roboshop/ansible  #This directory is used to clone.
ANSIBLE_DIR=ansible-roboshop-roles-tf #Pull the github repository.

mkdir -p $REPO_DIR #Create a directory with the below path as: /opt/roboshop/ansible
# # If exists then DON'T throw an error.
mkdir -p /var/log/roboshop/
touch /var/log/roboshop/ansible.log
# ansible-pull -U https://github.com/sindhumgithub/ansible-roboshop-roles-tf.git -e component=$component -e env=$env main.yaml

cd $REPO_DIR

# # check if ansible repo is already cloned or not.

if [ -d $ANSIBLE_DIR ]; then
    cd $ANSIBLE_DIR
    git pull
else
    git clone $REPO_URL
    cd $ANSIBLE_DIR
fi

ansible-playbook -e component=$component -e env=$env main.yaml 