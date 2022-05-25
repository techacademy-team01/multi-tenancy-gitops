# CP4I Demo scenario - the GitOps version

This is based on getting a ROKS cluster with GitOps offering in [https://techzone.ibm.com/collection/production-deployment-guides#tab-6](https://techzone.ibm.com/collection/production-deployment-guides#tab-6). This document explains the whole interaction, including the necessary setup.

## Preparation

- GitHub token
- GIT_ORG
- Techzone reservation

Prepare and activate the Techzone reservation with the appropriate GitHub token and GIT_ORG. Share the TechZone reservation and invite user to GIT_ORG.

1. Create a local copy of the ORG.

    ```
    mkdir ${GIT_ORG}
    cd ${GIT_ORG}
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-infra
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-services
    gh repo fork https://github.com/sko-master/multi-tenancy-gitops-apps --org ${GIT_ORG} --clone
    ```

2. As the repo is based on `cloud-native-toolkit` not `sko-master` - you must rebase the main repo and the services repo

    ```
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
    sed -i*.bak '13,15d;17d' 0-bootstrap/bootstrap.yaml
    sed -i*.bak '13,15d;17d' 0-bootstrap/single-cluster/bootstrap.yaml
    rm 0-bootstrap/single-cluster/*bak
    rm 0-bootstrap/*bak
    git add 0-bootstrap/bootstrap.yaml
    git add 0-bootstrap/single-cluster/bootstrap.yaml

    git rebase --continue
    git push origin --force
    ```

3. Prepare the services layer (2nd batch operators), edit `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml`
    Uncomment the lines for:

    ```
    - argocd/operators/ibm-ace-operator.yaml
    - argocd/operators/ibm-apic-operator.yaml
    - argocd/operators/ibm-assetrepository-operator.yaml
    - argocd/operators/ibm-datapower-operator.yaml
    - argocd/operators/ibm-eventstreams-operator.yaml
    - argocd/operators/ibm-mq-operator.yaml
    - argocd/operators/ibm-opsdashboard-operator.yaml
    - argocd/operators/ibm-platform-navigator.yaml
    ```
5. Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `Services` application. **Make sure that all the status are Sync and Healthy before progressing.**

3. Prepare the services layer (APIC and Platform Navigator), edit `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml`
    Uncomment the lines for:

    ```
    - argocd/instances/cp4itracing.yaml
    - argocd/instances/opsdashboard.yaml
    - argocd/instances/ibm-platform-navigator-instance.yaml
    - argocd/instances/apic-demo.yaml
    ```

5. Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `Services` application. **Wait for 1 hour or so for the Platform Navigator and APIC ready**

---

All preparation work is done at this stage - the rest of the work is for the students to do

---

## Student exercises


### Prepare environment

1. The oc command line version 4.6+
2. The git command line
3. Bash shell 
4. access to environment (shared from techzone)
5. Access to git org

### Exploring the environment

1. Clone the repo locally on Student workstation

    ```
    mkdir ${GIT_ORG}
    cd ${GIT_ORG}
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-infra
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-services
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-apps
    ```

2. Check what has been deployed 

    - Infra layer `kustomization.yaml` what namespaces are enabled? openshift console - check namespaces (`tools` `ibm-common-services`)
    - Services layer what instances are enabled - how to check Platform navigator and API Connect

3. Deploy additional instances for App Connect add-ons, Operation Dashboard and Asset Repo:

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml`. Uncomment the lines for:

    ```
    - argocd/instances/es-demo.yaml
    - argocd/instances/ace-infra.yaml
    - argocd/instances/assetrepo.yaml
    ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `Services` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

4. Activate MQ Queue Manager

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

    ```
    - argocd/sko-sample/mqmgr.yaml
    ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `Application` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

5. Activate ACE - MQ application

    - Go to the folder `multi-tenancy-gitops-apps/sko-sample/ace-001` 
    - Run the script to generate the YAML resources:

        ``` bash
        ./ace-config-barauth-github.sh
        ./ace-config-policy-mq.sh
        ```

    - Verify that there are 2 YAML files generated in that path

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

        ```
        - argocd/sko-sample/ace-001.yaml
        ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `Application` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

TBD