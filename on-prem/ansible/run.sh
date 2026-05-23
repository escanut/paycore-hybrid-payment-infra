#!/bin/bash

ansible-playbook -i inventory.ini configure.yml
ansible-playbook -i inventory.ini deploy_app.yml
    