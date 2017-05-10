# Installation instructions

# UNDER CONSTRUCTION

## Install ansible on the host

```sh
# su -
# apt install ansible
# echo 'localhost ansible_connection=local' >> /etc/ansible/hosts
# ansible-playbook deploy.yml
```

How to run docker with IP
```sh
# docker run --name=hello hello-world
# docker ps -aqf name=hello
# docker inspect --format '{{ .NetworkSettings.IPAddress }}' `docker ps -aqf name=hello`
```
