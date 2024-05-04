#!/bin/bash
component=$1
environment=$2
sudo yum install python3.11-devel  python3.11-pip -y
sudo pip3.11 install ansible botocore boto3
ansible-pull -U https://github.com/Mygit-Naresh/roboshop-ansible-roles-tf.git -e component=$component  -e env=$environment super_main.yml