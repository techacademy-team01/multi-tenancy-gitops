# CP4I Demo scenario - the GitOps version

This is based on getting a ROKS cluster with GitOps offering in [https://techzone.ibm.com/collection/production-deployment-guides#tab-6](https://techzone.ibm.com/collection/production-deployment-guides#tab-6). This document explains the whole interaction, including the necessary setup.

## Preparation

- GitHub token (with `repo` and `admin:repo_hook` permissions)
- Empty GIT_ORG organization (ie no GitOps related repos) 
- Techzone reservation (ROKS cluster with GitOps 3 nodes 16x64)

Prepare and activate the Techzone reservation with the appropriate GitHub token and GIT_ORG. Share the TechZone reservation and invite user to GIT_ORG.

1. Create a local copy of the ORG.

    ```bash
    mkdir ${GIT_ORG}
    cd ${GIT_ORG}
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-infra
    git clone https://github.com/${GIT_ORG}/multi-tenancy-gitops-services
    gh repo fork https://github.com/sko-master/multi-tenancy-gitops-apps --org ${GIT_ORG} --clone
    ```

2. Login using CLI to the cluster and update argoCD privileges by running 

    ```bash
    curl https://raw.githubusercontent.com/sko-master/multi-tenancy-gitops/master/setup/ocp4x/custom-argocd-app-controller-clusterrole.yaml | oc apply -f - 
    ```

2. As the repo is based on `cloud-native-toolkit` not `sko-master` - you must rebase the main repo and the services repo

    ```
    cd multi-tenancy-gitops-services
    git remote add sko https://github.com/sko-master/multi-tenancy-gitops-services
    git fetch sko master
    git rebase sko/master
    git push origin --force
    cd ../multi-tenancy-gitops
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
    git add 0-bootstrap/single-cluster/2-services/argocd/instances
    git add 0-bootstrap/single-cluster/3-apps/argocd/sko-sample
    git rebase --continue
    git push origin --force
    ```

5. Refresh in argoCD web ui the `Infra` and `Services` applications. The `apic-demo` and `ibm-platform-navigator-instance` may take up to 1 hour to complete. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that the opsdashboard application has healthy instances 
    - Check that in apic-demo the OperationDashboardServiceBinding object does not have error messages

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


3. Prepare the services layer (2nd batch operators), edit `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml`
    Uncomment the lines for:

    ```
    - argocd/operators/ibm-ace-operator.yaml
    - argocd/operators/ibm-eventstreams-operator.yaml
    - argocd/operators/ibm-mq-operator.yaml
    ```

5. Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `02-Services` application. **Make sure that all the status are Sync and Healthy before progressing.**

3. Deploy additional instances for App Connect add-ons, Operation Dashboard and Asset Repo:

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/2-services/kustomization.yaml`. Uncomment the lines for:

    ```
    - argocd/instances/es-demo.yaml
    - argocd/instances/ace-infra.yaml
    ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `02-Services` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

4. Activate MQ Queue Manager

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

    ```
    - argocd/sko-sample/mqmgr.yaml
    ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `03-Application` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

7. Deploy Event Stream customization:

    - Go to the folder `multi-tenancy-gitops-apps/sko-sample/eventstream` 

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

        ```
        - argocd/sko-sample/eventstream.yaml
        ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `03-Application` application. 
    
    - Check the output of the job and fix any error that may appear.

9. Work with App Connect Enterprise integration servers:

    - Go to the `multi-tenancy-gitops-apps/sko-sample/ace-00-config`

    - Run the programs: 

        ```bash
        ./06-ace-config-barauth-github.sh
        ./07-ace-config-policy-mq.sh
        SF_USER=<my-sf-user> SF_PWD=<my-sf-pwd> SF_CLIENT_ID=<my-sf-client-id> SF_CLIENT_SECRET=<my-sf-client-secret> SF_LOGIN_URL="https://login.salesforce.com" ./08-ace-config-accounts-sf.sh
        ./10-ace-config-policy-es-scram.sh
        ./11-ace-config-setdbparms-es-scram.sh
        ./12-ace-config-truststore-es.sh
        ./13-ace-config-policy-udp.sh
        ./14-ace-config-policy-email.sh
        MAILTRAP_USER=<user> MAILTRAP_PWD=<pwd> ./15-ace-config-setdbparms-email.sh
        ```

    - Uncomment the content of `multi-tenancy-gitops-apps/sko-sample/ace-00-config/kustomization.yaml`

    - Verify that there are 9 YAML files generated in that path

    - Add, Commit and Push the changes to multi-tenancy-gitops-apps
    
    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

        ```
        - argocd/sko-sample/ace-00-config.yaml
        - argocd/sko-sample/ace-backend.yaml
        - argocd/sko-sample/ace-evnt2mail.yaml
        - argocd/sko-sample/ace-fwdmqevnt.yaml
        - argocd/sko-sample/ace-mqapidflt.yaml
        - argocd/sko-sample/ace-mqapiprem.yaml
        - argocd/sko-sample/ace-sflead.yaml
        ```

    - Add, Commit and Push the changes to multi-tenancy-gitops; then refresh in argoCD console the `03-Application` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that those deployment are successful 

6. Deploy APIC API definition:

    - Go to the folder `multi-tenancy-gitops-apps/sko-sample/apic-cust` 
    - Run the script to generate the APIC mail secret (from `https://mailtrap.io`):

        ``` bash
        MAILTRAP_USER=<user> MAILTRAP_PWD=<pwd> ./apic-user-mail-secret.sh
        ```

    - Verify that there are secret YAML files updated in that path

    - Edit `multi-tenancy-gitops/0-bootstrap/single-cluster/3-apps/kustomization.yaml`. Uncomment the lines for:

        ```
        - argocd/sko-sample/apic-cust.yaml
        ```

    - Add, Commit and Push the changes to multi-tenancy-gitops-apps and multi-tenancy-gitops; then refresh in argoCD console the `Application` application. **Make sure that all the status are Sync and Healthy before progressing.**

    - Check that the apic-setup job is successful (look at the pod's logs)

    - Publish the API connect API, in OpenShift console - go to the **Workloads** > **Pods** and filter by the work `publish`; select the pod and go to the **Terminal** tab.

    - In the Terminal session, run `./apic-publish-api.sh`; while running, open the URL provided in a different browser session and collect the API key to be pasted back to the terminal session.

    - If there are no error - your API is published successfully

8. Use the Platform Navigator to verify the stuff you deployed. (Need to be explained better and more thoroughly)

    - Check the integration instances to be all `Ready`

    - Go to the API (...) > **Run** > **API**

    - Make sure the API is Online and go to the **Explore** tab

    - select **Try It** tab 
    
    - Generate the input data

    - Click **Send**

    - Be sure to get the result 

    - Go to the Tracing (...) > **Operate** > **Integration Trace**

    - Go to **Traces** and select the entry that has all APIC ACE and MQ components

