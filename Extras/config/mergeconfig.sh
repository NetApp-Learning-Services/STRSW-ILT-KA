#!/bin/bash 
sudo sed -i 's/\<kubernetes\>/kubernetes2/g' config2
konfig=$(KUBECONFIG=config1:config2 kubectl config view --flatten)
echo "$konfig" > ~/.kube/config
#echo "$konfig" > config