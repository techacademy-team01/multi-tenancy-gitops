#! /usr/bin/env bash

mkdir ${GIT_ORG}
cd ${GIT_ORG}
git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops
git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-infra
git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-services
gh repo fork https://github.com/sko-master/multi-tenancy-gitops-apps --org ${GIT_ORG} --clone

cd multi-tenancy-gitops-services
git remote add sko https://github.com/sko-master/multi-tenancy-gitops-services
git fetch sko master
git rebase sko/master
git push origin --force
cd multi-tenancy-gitops
git remote add sko https://github.com/sko-master/multi-tenancy-gitops
git fetch sko master
git rebase sko/master 
git rm -r 0-bootstrap/others

git rebase --continue
git add 0-bootstrap/single-cluster/2-services/argocd/instances/
sed -i*.bak '13,15d;17d' 0-bootstrap/bootstrap.yaml
sed -i*.bak '13,15d;17d' 0-bootstrap/single-cluster/bootstrap.yaml
rm 0-bootstrap/single-cluster/*bak
rm 0-bootstrap/*bak
git add 0-bootstrap/bootstrap.yaml
git add 0-bootstrap/single-cluster/bootstrap.yaml
git rm -r 0-bootstrap/others

git rebase --continue
git push origin --force

